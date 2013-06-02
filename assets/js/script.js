function test() {
    alert('hi');
}

$(function(){
	
	var timeline = new VMM.Timeline();
	console.log('after VMM.Timeline()');
	timeline.init("data.json");	
});

