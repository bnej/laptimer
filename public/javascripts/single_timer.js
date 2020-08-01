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

function init( ) {
    $.ajax({
	type: 'GET',
	url: baseurl + "/info",
	success: init_update,
	datatype: "json"
    });
}
