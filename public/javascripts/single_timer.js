var athletes = [ ];

var athlete_sel = null;

var timer_start = Date.now();
var effort_start = Date.now();

var num = 1;
var timer_running = false;

var marks = [ ];
var to_sync = [ ];
var lap = [ ];

var mark_number = 1;

var start_lap = 0;
var total_laps = 0;

var effort_mark = 0;

function effort_started( ) {
    return effort_mark >= start_lap;
}

function effort_finished( ) {
    return effort_mark - start_lap >= total_laps;
}

/* Different from the stopwatch timer, this shows an animated effort
 * timer, not a global timer. */
function start_timer() {
    effort_start = Date.now();
    timer_running = true;

    update_time();
}

function stop_timer( ) {
    timer_running = false;
}

function update_time() {
    var current = Date.now();
    var delta = current - effort_start;
    $('#timer-current').text( ms_format( delta,1 ) );
    if( timer_running ) 
	setTimeout(update_time, 100);
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
		'<button name="choose-athlete" value="'+v.id+'" type="text" class="btn-primary athlete-select">Select</button>'+
		'</div>'
	);
    });

    $('.athlete-select').each( function(index) {
	$(this).on( "click", athlete_select );
    });
}

function update_state( ) {
    var mark_btn = $('#start-stop-mark').
	removeClass('btn-warning btn-success btn-error btn-primary');

    if( !athlete_sel ) {
	mark_btn.addClass('btn-warning').
	    text("Not Ready");
    } else if( effort_mark < start_lap - 1 ) {
	/* Idle lap */
	mark_btn.addClass('btn-primary').
	    text('Next');
    } else if( effort_mark < start_lap ) {
	/* Next mark starts */
	mark_btn.addClass('btn-success').
	    text('Go');
    } else if( effort_mark - start_lap == total_laps - 1 ) {
	/* Next mark finishes */
	mark_btn.addClass('btn-success').
	    text('Finish');
    } else if( effort_mark - start_lap >= total_laps ) {
	mark_btn.addClass('btn-warning').
	    text('Done');
	stop_timer( );
    } else {
	/* Normal lap marker */
	mark_btn.addClass('btn-success').
	    text('Lap');
    }
    $('#count-marks').text( mark_number - 1 );
    $('#sync-marks').text( to_sync.length );
    $('#lap-count').text( remaining( effort_mark ) );
}

function mark_lap( ) {
    /* Disable if an athlete is not selected. */
    if( !athlete_sel ) return;

    var current = Date.now();
    var delta = current - timer_start;
    var delta_fmt = ms_format( delta );
    var place_mark = {
	"id": athlete_sel.id,
	"timing_number": mark_number,
	"mark": delta,
	"mark_fmt": delta_fmt,
	"sync":false,
	"timestamp":current
    };

    console.log("mark " + mark_number + " effort " + effort_mark + " finished " + effort_finished() );
    if( !effort_finished() ) {
	/* Don't record a mark if we aren't running. */
	marks[mark_number] = place_mark;
	to_sync.push( place_mark );

	mark_number ++;
	effort_mark ++;
    }
    console.log("* mark " + mark_number + " effort " + effort_mark + " finished " + effort_finished() );

    /* Start the timer if this is the active lap */
    if( effort_mark == start_lap ) {
	start_timer( );
    }
    
    update_state( );
    sync_laps( to_sync );
}

function sync_laps( lap_marks ) {
    if( lap_marks.length > 0 ) {
	$.ajax({
	    type: 'POST',
	    url: baseurl + "/lap_data",
	    data: JSON.stringify({ marks: lap_marks }),
	    contentType: "application/json",
	    success: fix_laps,
	    dataType: "json"
	});
    }
}

function fix_laps( data ) {
    data.forEach( function(v) {
	marks[v.timing_number].sync = true;
    });
    
    to_sync = to_sync.filter( function( value, index, arr ) { !value.sync } );
    update_state();
}


function athlete_select( ) {
    var id = parseInt(this.getAttribute("value"));
    athlete_sel = athletes[id];

    $('#timer-current').text(ms_format(0,1));
    $('#athlete-name').text(athlete_sel.name);
    effort_mark = 0;
    update_state( );

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

    marks = data.marks;
    timer_start = Date.now() - data.last_offset;
    mark_number = data.last_mark + 1;

    update_state();
}
