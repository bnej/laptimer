var athletes = [ ];
var mark_number = 1;
var front_lap = 0;
var tail_lap = 0;

function load_athletes( ) {
    $.ajax({
	type: 'GET',
	url: cluburl + "/athletes",
	success: load_athletes_update,
	dataType: "json"
    });
}

function load_athletes_update( data ) {
    data.forEach( function(v) {
	var athlete = {
	    id: v.id,
	    name: v.name,
	    alias: v.alias,
	};
	athletes[ v.id ] = athlete;

	$('#select-riders').append(
	    //'<li class="list-group-item riders" id="row-athlete-'+v.id+'"><div class="form-check"><input class="form-check-input" type="checkbox" name="check-athlete" id="check-athlete-'+v.id+'" value="'+v.id+'"><label class="form-check-label for="check-athlete-'+v.id+'>'+v.name+'</label></div></li>'
	    '<div class="input-group mb-3">'+
		'<div class="input-group-prepend">'+
		'<span class="input-group-text">'+v.name+'</span>'+
		'</div>'+
		'<input type="text" class="form-control" placeholder="Race #">'+
		'</div>'
	);
    });
}

