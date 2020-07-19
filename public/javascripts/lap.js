var athletes = [ ];
var a_select = [ ];

var marks = [ ];
var mark_sync = [ ];
var lap = [ ];

var mark_number = 0;
var front_lap = 0;
var tail_lap = 0;

function min_lap( ) {
    var min_lap = lap[a_select[0].id]; // any is fine to start
    for( var i = 0; i < a_select.length; i++ ) {
	var id = a_select[i].id;
	if( lap[id] < min_lap ) min_lap = lap[id];
    }
    return min_lap;
}

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
	lap[ v.id ] = 0;

	$('#select-riders').append(
	    //'<li class="list-group-item riders" id="row-athlete-'+v.id+'"><div class="form-check"><input class="form-check-input" type="checkbox" name="check-athlete" id="check-athlete-'+v.id+'" value="'+v.id+'"><label class="form-check-label for="check-athlete-'+v.id+'>'+v.name+'</label></div></li>'
	    '<div class="input-group mb-1" id="select-athlete-'+v.id+'">'+
		'<div class="input-group-prepend">'+
		'<span class="input-group-text">'+v.name+'</span>'+
		'</div>'+
		'<input name="race-no-'+v.id+'"type="text" class="form-control" placeholder="Race #">'+
		'</div>'
	);
    });
}

function select_save_athletes( ) {
    var all = $('#select-riders-form').serializeArray();
    var selected = [ ];

    for( var i = 0; i < all.length; i++ ) {
	if( all[i].value != "" ) {
	    var id = parseInt(all[i].name.match('[0-9]+$')[0]);
	    var athlete = athletes[id];

	    selected.push( {
		"id": id,
		"name": athlete.name,
		"alias": athlete.alias,
		"marker": all[i].value
	    } );
	}
    }

    selected.sort( function(a,b) { return a.marker.localeCompare(b.marker) } );

    a_select = selected;

    var rl = $('#rider-list');
    rl.html("");
    for( var i = 0; i < selected.length; i++ ) {
	var a = selected[i];
	rl.append(
	    '<li class="list-group-item rider" id="rider-'+a.id+'"'+
		'data-id="'+a.id+'">'+
		'<span class="badge rider-marker badge-primary">'+
		a.marker+
		'</span>'+
		'<span class="badge badge-light">'+
		a.name+
		'</span>'+
		'<span class="badge lap-time"></span>' +
		'<span class="badge total-time"></span>' +
		'<span class="badge badge-pill lap-counter badge-info">0</span>'+
		'</li>'
	);
	$('#rider-'+a.id).on( "click", athlete_lap );
    }
}

function athlete_lap( ) {
    var id = parseInt(this.getAttribute("data-id"));
    var athlete = athletes[id];
    
    var place_mark = {
	"id": id,
	"timing_number": mark_number,
	"sync":false
    };
    marks[mark_number] = place_mark;
    mark_sync[mark_number] = place_mark;
    lap[ id ] ++;

    if( lap[ id ] > front_lap ) front_lap = lap[ id ];
    tail_lap = min_lap();

    $("#lap-count-back").text( tail_lap );
    $("#lap-count-front").text( front_lap );

    $(this).detach()
    $(this).children(".lap-counter").text( lap[ id ] );
    $('#rider-list').append($(this));
}
