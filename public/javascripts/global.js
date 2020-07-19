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
