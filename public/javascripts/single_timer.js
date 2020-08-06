var athletes = [ ];
var a_select = [ ];

var marks = [ ];
var to_sync = [ ];
var lap = [ ];

var mark_number = 1;
var front_lap = 0;
var tail_lap = 0;

var start_lap = 0;
var total_laps = 0;

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
		'<button name="choose-athlete" value="'+v.id+'" type="text" class="btn-primary athlete-select">Select</button>'+
		'</div>'
	);
    });

    $('.athlete-select').each( function(index) {
	$(this).on( "click", athlete_select );
    });
}

function athlete_select( ) {
    var id = parseInt(this.getAttribute("value"));
    var athlete = athletes[id];

    $('#timer-current').text(ms_format(0,1));
    $('#athlete-name').text(athlete.name);
    $('#start-stop-mark').
	text('Go').
	removeClass('btn-warning btn-success btn-error btn-primary').
	addClass('btn-success');
    $('#lap-count').text( remaining(0) );
    $('#count-marks').text( 0 );

    return false;
}

function init( ) {
    $.ajax({
	type: 'GET',
	url: baseurl + "/info",
	success: init_update,
	datatype: "json"
    });
}

function init_update( data ) {
    start_lap = data.start_lap;
    total_laps = data.total_laps;
}
