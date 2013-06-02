
SLEEP_TIME = 5
API_KEY = "SECRET API KEY"
def download(s, start_year)
  
  require 'net/http'
  require 'uri'
  record_counter = s
  url = "http://api.trove.nla.gov.au/result?key=#{API_KEY}&zone=newspaper&q=date:[#{start_year}%20TO%20#{start_year}]&l-title=35&l-category=Article&n=100&sortby=datedesc&s=#{s}&encoding=json"
  begin
    begin
      puts url
      download_articles = Net::HTTP.get(URI.parse(url))
      parsed_json = ActiveSupport::JSON.decode(download_articles)
    rescue => e
      puts "Error found"
      puts e.message
      #puts e.stacktrace
      puts "Retry with record counter #{record_counter}"
      download(record_counter, start_year)
    end
      zone_obj = parsed_json["response"]["zone"][0]
      records_obj = zone_obj["records"]
      articles_obj = records_obj["article"]

      record_counter = records_obj["s"].to_i
      articles_obj.each do |article_obj|
        if Article.find(:first, :conditions => {:article_id => article_obj["id"]}) == nil
          article = Article.new()
          article.article_id = article_obj["id"]
          article.headline = article_obj["heading"]
          #article.article_text = article_obj["articleText"]
          article.category = article_obj["category"]
          article.date = article_obj["date"].to_time.strftime('%Y-%b-%d')
          #article.pdf_link = article_obj["pdf"]
          article.snippet = article_obj["snippet"]
          article.title_id = article_obj["title"]["id"]
          article.trove_url = article_obj["trovePageUrl"]
          article.save();
        end
      end
      next_url = records_obj["next"]
      url = "http://api.trove.nla.gov.au#{next_url}&key=#{API_KEY}"
  end while records_obj["n"].to_i > 0
end




def nlp(start, batch_size)
  require 'action_view'
  include ActionView::Helpers::SanitizeHelper
  #StanfordCoreNLP.jvm_args = ['-Xms1024M', '-Xmx2048M']
  pipeline =  StanfordCoreNLP.load(:tokenize, :ssplit, :pos, :parse)
  counter = start;
  while counter <= batch_size
    article = Article.find(counter)
    counter += 1
    #next if article.article_text.size > 4100
    
    text = strip_tags(article.headline)
    #puts text
    word_histogram = {}
    begin
      text = StanfordCoreNLP::Annotation.new(text)
      pipeline.annotate(text)
      text.get(:sentences).each do |sentence|
        sentence.get(:tokens).each do |token|
          token_value = token.get(:original_text).to_s.downcase
          next if token_value.size < 4
        
          if token.get(:part_of_speech).to_s == 'NNP' || token.get(:part_of_speech).to_s == 'NN'
            if word_histogram[token_value] == nil
              word_histogram[token_value] = 1
            else
              word_histogram[token_value] += 1
            end
          end
        end
      end
      word_histogram = word_histogram.sort_by{ |word, count| count }.reverse
      word_counter = 0
      word_histogram.each do |key, value|
        #if word_counter > 10 then
        #  break
        #end
        puts "#{key} => #{value}"
        histogram = Histogram.new()
        histogram.word = key
        histogram.count = value
        histogram.article_id = article.article_id
        histogram.save()
        #word_counter += 1
      end
    rescue => e
      puts "Error found"
      puts e.message
    end
  end
end

min_date = Date.new(1942, 12, 31)
def trends(min_date, end_date)
  start_date = end_date.advance({:months => -1})
  puts "#{start_date} - #{end_date}"
  
  if end_date > min_date
    word_histogram = {}
    articles = Article.where("date >= ? and date <= ?", start_date, end_date)
    articles.each do |article|
      histograms = Histogram.where("article_id = ?", article.article_id)
      if histograms != nil
        histograms.each do |histogram|
          if word_histogram[histogram.word] == nil
            word_histogram[histogram.word] = histogram.count
          else
            word_histogram[histogram.word] += histogram.count
          end
        end
      end
    end
    word_histogram = word_histogram.sort_by{ |word, count| count }.reverse
    word_histogram.each do |key, value|
      trend = Trend.new()
      trend.word = key
      trend.count = value
      trend.start_date = start_date
      trend.end_date = end_date
      trend.save()
    end
    trends(min_date, start_date)
  end
end

def trend(start_date, end_date)
  word_histogram = {}
  articles = Article.where("date >= ? and date <= ?", start_date, end_date)
  articles.each do |article|
    histograms = Histogram.where("article_id = ?", article.article_id)
    if histograms != nil
      histograms.each do |histogram|
        if word_histogram[histogram.word] == nil
          word_histogram[histogram.word] = histogram.count
        else
          word_histogram[histogram.word] += histogram.count
        end
      end
    end
  end
  word_histogram = word_histogram.sort_by{ |word, count| count }.reverse
  puts word_histogram
end

def findArticle(word, start_date, end_date)
  articles = Article.where("date >= ? and date <= ?", start_date, end_date)
  max_occurrence = -1
  result_histogram = nil
  articles.each do |article|
    histogram = Histogram.where("article_id = ? and word = ?", article.article_id, word)
    if histogram.count > max_occurrence
      max_occurrence = histogram.count
      result_histogram = histogram
    end
  end
  puts result_histogram
end


def findArticle(word, start_date, end_date)
  articles = Article.where("date >= ? and date <= ?", start_date, end_date)
  articles.each do |article|
    if article.headline.downcase.include?(word)
      return article
    end
  end
  puts result_histogram
end


