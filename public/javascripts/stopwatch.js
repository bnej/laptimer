var timer_start = Date.now();
var num = 1;
var timer_running = false;

function start_stop( button ) {
    if( timer_running ) {
	stop_timer( button );
    } else {
	start_timer( button );
    }
}

function start_timer( button ) {
    timer_start = Date.now();
    timer_running = true;

    button.addClass('btn-danger');
    button.removeClass('btn-success');
    button.text("Stop");

    update_time();
}

function stop_timer( button ) {
    timer_running = false;

    button.removeClass('btn-danger');
    button.addClass('btn-success');
    button.text("Start");
}

function update_time() {
    var current = Date.now();
    var delta = current - timer_start;
    $('#timer-current').text( ms_format( delta,1 ) );
    if( timer_running ) 
	setTimeout(update_time, 100);
}

var timer_marks = [ ];

function mark() {
    var current = Date.now();
    var delta = current - timer_start;
    var delta_fmt = ms_format( delta );
    timer_marks.push( {
	time: delta,
	time_fmt: delta_fmt,
	sync: false,
    });
    $('#mark-table > tbody').prepend('<tr><th scope="row">'+num+'</th><td>'+delta_fmt+'</tr>');
    num ++;
}
update_time();


function zero_pad( n, width ) {
    var str = n.toString();
    width -= str.length;
    while( width > 0 ) {
	width --;
	str = "0" + str;
    }
    return str;
}

function ms_format( ms, ms_places = 3 ) {
    var p_ms = ms % 1000; // milliseconds
    var p_seconds = Math.floor( ms / 1000 ); // Whole seconds
    var p_minutes = Math.floor( p_seconds / 60 ); // Whole minutes

    if( ms_places == 2 )
	p_ms = Math.floor( p_ms / 10 );
    else if( ms_places == 1 )
	p_ms = Math.floor( p_ms / 100 );

    p_seconds = p_seconds % 60; // Remove minutes

    if( ms_places == 0 ) {
	// Return without ms
	return "" + zero_pad( p_minutes, 2 ) + ":" + zero_pad( p_seconds, 2 );
    } else {
	return "" + zero_pad( p_minutes, 2 ) + ":" + zero_pad( p_seconds, 2 ) + "." + zero_pad(p_ms, ms_places);
    }
}
