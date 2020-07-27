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
    button.hide();
    $('#mark-time').show();

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
var to_sync = [ ];

function fix_marks( data ) {
    data.forEach( function(v) {
	var elts = $("#row-mark-"+v.mark_number);
	if( v.sync == 0 ) {
	    elts.removeClass("table-warning").addClass("table-info");
	    elts.find(".time-mark").text(ms_format(v.mark));
	} else {
	    elts.removeClass("table-warning").addClass("table-success");
	}
	timer_marks[v.mark_number].sync = true;
    });
    to_sync = to_sync.filter( function( value, index, arr ) { !value.sync } );
}

function mark() {
    var current = Date.now();
    var delta = current - timer_start;
    var delta_fmt = ms_format( delta );
    var mark = {
	mark_number: num,
	mark: delta,
	mark_fmt: delta_fmt,
	timestamp: current,
	sync: false
    };
    timer_marks[ num ] = mark;
    to_sync.push( mark );

    $('#mark-table > tbody').prepend('<tr class="table-warning" id="row-mark-'+num+'"><th class="time-number" scope="row">'+num+'</th><td class="time-mark">'+delta_fmt+'</tr>');

    add_mark( to_sync );
    
    num ++;
}
update_time();

function add_mark( timer_marks ) {
    $.ajax({
	type: 'POST',
	url: baseurl + "/timing",
	data: JSON.stringify({ timing: timer_marks }),
	contentType: "application/json",
	success: fix_marks,
	dataType: "json"
    });
}

function load_marks( ) {
    $.ajax({
	type: 'GET',
	url: baseurl + "/timing",
	success: load_marks_update,
	dataType: "json"
    });
}

function load_marks_update( data ) {
    data.forEach( function(v) {
	num = v.mark_number + 1;
	var mark = {
	    mark_number: v.mark_number,
	    mark: v.mark,
	    mark_fmt: ms_format(v.mark),
	    sync: true,
	};
	timer_marks[ v.mark_number ] = mark;

	$('#mark-table > tbody').prepend('<tr class="table-success" id="row-mark-'+v.mark_number+'"><th class="time-number" scope="row">'+v.mark_number+'</th><td class="time-mark">'+mark.mark_fmt+'</tr>');
    });
}
