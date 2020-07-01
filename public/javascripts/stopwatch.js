function zero_pad( n, width ) {
    var str = n.toString();
    width -= str.length;
    while( width > 0 ) {
	width --;
	str = "0" + str;
    }
    return str;
}

function ms_format( ms ) {
    var p_ms = ms % 1000; // milliseconds
    var p_seconds = Math.floor( ms / 1000 ); // Whole seconds
    var p_minutes = Math.floor( p_seconds / 60 ); // Whole minutes

    p_seconds = p_seconds % 60; // Remove minutes

    return "" + zero_pad( p_minutes, 2 ) + ":" + zero_pad( p_seconds, 2 ) + "." + zero_pad(p_ms, 3);
}
