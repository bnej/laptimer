var athletes = [ ];
var a_select = [ ];

var marks = [ ];
var to_sync = [ ];
var lap = [ ];

var mark_number = 1;
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
    var sr = $('#select-riders');
    sr.html(""); /* clear before populating */
    $("#new-rider-form input").val("");
    
    data.forEach( function(v) {
	var athlete = {
	    id: v.id,
	    name: v.name,
	    alias: v.alias,
	};
	athletes[ v.id ] = athlete;
	lap[ v.id ] = 0;

	sr.append(
	    '<div class="input-group mb-1" id="select-athlete-'+v.id+'">'+
		'<div class="input-group-prepend">'+
		'<span class="input-group-text">'+v.name+'</span>'+
		'</div>'+
		'<input name="race-no-'+v.id+'"type="text" class="form-control" placeholder="Race #">'+
		'</div>'
	);
    });
}

function new_athlete( ) {
    var formdata = $('#new-rider-form').serialize();
    if($('#new-rider-name').val() == "") {
	$('#new-rider-form').prepend(
	    '<div class="alert alert-warning alert-dismissable fade show" role="alert">'+
		"<span>You need to fill in a name</span>" +
		'<button type="button" class="close" data-dismiss="alert" aria-label="Close">'+
		'<span aria-hidden="true">&times;</span>'+
		'</button>'+
		'</div>'
	);
	return;
    }
    
    $.ajax({
	type: 'POST',
	url: cluburl + "/athletes",
	data: formdata,
	success: load_athletes_update,
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
		'<span class="badge badge-info lap-time"></span>' +
		'<span class="badge badge-light total-time"></span>' +
		'<span class="badge badge-pill lap-counter badge-success">0</span>'+
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
    to_sync.push( place_mark );
    
    mark_number ++;

    sync_laps( to_sync );
    
    lap[ id ] ++;

    if( lap[ id ] > front_lap ) front_lap = lap[ id ];
    tail_lap = min_lap();

    $("#lap-count-back").text( tail_lap );
    $("#lap-count-front").text( front_lap );
    $("#count-marks").text( mark_number - 1 );

    $(this).detach()
    $(this).children(".lap-counter").text( lap[ id ] );
    $('#rider-list').append($(this));
}

function sync_laps( lap_marks ) {
    $.ajax({
	type: 'POST',
	url: baseurl + "/lap_data",
	data: JSON.stringify({ laps: lap_marks }),
	contentType: "application/json",
	success: fix_laps,
	dataType: "json"
    });
}

function fix_laps( data ) {
    data.forEach( function(v) {
	var elts = $("#rider-"+v.id);
	if( v.sync == 0 ) {
	    // Hope this doesn't happen. Can't really be handled in
	    // the front end
	} else {
	    /* Too much space on a phone 
	    elts.children('.lap-time').text(
		"Lap: " + ms_format( v.lap_time )
	    );
	    elts.children('.total-time').text(
		"Total: " + ms_format( v.total_time )
	    );
	    */
	}
	marks[v.timing_number].sync = true;

	// In case we want to use lap + total to predict next riders,
	// instead of just least-recently-crossed.
	marks[v.timing_number].lap_time = v.lap_time;
	marks[v.timing_number].total_time = v.total_time;
    });
    
    to_sync = to_sync.filter( function( value, index, arr ) { !value.sync } );
}
