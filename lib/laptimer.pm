use strict;
use warnings;

package laptimer;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Exception qw(:all);
use POSIX qw(ceil floor);

our $VERSION = '0.1';

get '/' => sub {
    template 'index';
};

get '/club/:club/:event/timing' => sub {
    my $club = params->{club};
    my $event = params->{event};

    my $sth = database->prepare(
	"select * from time_mark where event_id = ? order by timing_number"
	);
    $sth->execute($event);
    my @r = ( );
    while( my $r = $sth->fetchrow_hashref ) {
	push @r, {
	    mark_number => $r->{timing_number},
	    mark => $r->{timing_mark},
	    sync => 1
	};
    }

    return \@r;
};

sub load_athletes {
    my $club = shift;

    my $sth = database->prepare(
	"select * from athlete where club_id = ?"
	);
    $sth->execute($club);

    my @r = ( );
    while( my $r = $sth->fetchrow_hashref ) {
	push @r, {
	    id => $r->{athlete_id},
	    name => $r->{athlete_name},
	    alias => $r->{athlete_alias} || $r->{athlete_name}
	}
    }
    
    return \@r;
}

get '/club/:club/athletes' => sub {
    my $club = params->{club};

    return load_athletes($club);
};

post '/club/:club/athletes' => sub {
    my $club = params->{club};
    my $name = params->{name};

    my $sth = database->prepare(
	"insert into athlete (club_id, athlete_name) values (?,?)"
	);
    $sth->execute( $club, $name );

    return load_athletes( $club );
};

post '/club/:club/:event/timing' => sub {
    my $club = params->{club};
    my $event = params->{event};

    my $timing = params->{timing};

    my $sth = database->prepare("insert into time_mark (event_id, timing_number, timing_mark) values (?,?,?)");
    my $sth_fetch = database->prepare("select * from time_mark where event_id = ? and timing_number = ?");

    my $r = [ ];
    foreach my $time (@$timing) {
	my $ok =
	    $sth->execute( $event, $time->{mark_number}, $time->{mark} );

	if( $ok ) {
	    push @$r, { mark_number => $time->{mark_number},
			mark => $time->{mark},
			sync => 1 };
	} else {
	    $sth_fetch->execute( $event, $time->{mark_number} )
		or die $sth_fetch->errstr;
	    my $exist = $sth_fetch->fetchrow_hashref;
	    push @$r, { mark_number => $exist->{timing_number},
			mark => $exist->{timing_mark},
			sync => 0 };
	}
    }

    return $r;
};

post '/club/:club/:event/lap_data' => sub {
    my $club = params->{club};
    my $event = params->{event};

    my $laps = params->{laps};

    my $sth = database->prepare("insert into place_mark (event_id, timing_number, athlete_id) values (?,?,?)") or die database->errstr;
    my $a_laps = database->prepare("select * from place_mark join time_mark using (timing_number, event_id) where athlete_id = ? and event_id = ? order by timing_number desc") or die database->errstr;

    my $r = [ ];
    foreach my $lap (@$laps) {
	my $ok =
	    $sth->execute( $event, $lap->{timing_number}, $lap->{id} );
	
	$a_laps->execute( $lap->{id}, $event ) or die $a_laps->errstr;
	my $last = $a_laps->fetchrow_hashref;
	my $previous = $a_laps->fetchrow_hashref;

	my $lr = {
	    id => $lap->{id},
	    sync => $ok,
	    timing_number => $lap->{timing_number}
	};
	$lr->{lap_time} = $lr->{total_time} = $last->{timing_mark};
	if( $previous ) {
	    $lr->{lap_time} = $last->{timing_mark} - $previous->{timing_mark};
	}
	push @$r, $lr;
    }

    return $r;
};

get '/club/:club/:event/stopwatch' => sub {
    my $club = params->{club};
    my $event = params->{event};
    
    my $sth = database->prepare(
	"select * from club join event using (club_id) where club_id = ? and event_id = ?"
	);
    $sth->execute($club, $event);
    my $cr = $sth->fetchrow_hashref();
    template 'stopwatch', { event_info => $cr,
			    "baseurl" => "/club/$club/$event" };
};

get '/club/:club/:event/results' => sub {
    my $club = params->{club};
    my $event = params->{event};

    my %athletes = ( );
    my $sth_club = database->prepare(
	"select * from club join event using (club_id) where club_id = ? and event_id = ?"
	);
    $sth_club->execute($club, $event);
    my $cr = $sth_club->fetchrow_hashref();
    my $final_lap_n = $cr->{start_lap} + $cr->{total_laps};
    
    my $sth = database->prepare(
	"select * from place_mark join time_mark using (timing_number, event_id) where event_id = ? order by timing_number asc"
	) or die database->errstr;
    my $sth_a = database->prepare(
	'select * from athlete where athlete_id = ?'
	) or die database->errstr;
    $sth->execute( $event );

    while( my $r = $sth->fetchrow_hashref ) {
	my $id = $r->{athlete_id};
	my $time = $r->{timing_mark};
	if( !$athletes{$id} ) {
	    $athletes{$id} = {
		laps => [ ],
		fastest => undef,
		total => 0,
		event_laps => 0,
		prior => 0,
		name => undef,
		finished => 0,
	    };
	}
	next if $athletes{$id}{finished};

	my $lap = $time - $athletes{$id}{prior};
	$athletes{$id}{prior} = $time;
	push @{$athletes{$id}{laps}}, $lap;
	
	my $event_laps = ++ $athletes{$id}{event_laps};
	if( $event_laps >= $cr->{total_laps} ) {
	    $athletes{$id}{finished} = 1;
	}
	$athletes{$id}{total} += $lap;
	if(defined $athletes{$id}{fastest}) {
	    $athletes{$id}{fastest} = $lap if $lap < $athletes{$id}{fastest};
	} else {
	    $athletes{$id}{fastest} = $lap; # First lap in event
	}
    }
    
    foreach my $id (keys %athletes) {
	$sth_a->execute( $id );
	my $r = $sth_a->fetchrow_hashref;

	$athletes{$id}{name} = $r->{athlete_name};
    }
    my @results_table = sort { $b->{finished} <=> $a->{finished} || $a->{total} <=> $b->{total} } values %athletes;
    for( my $i = 0; $i < @results_table; $i ++ ) {
	if( $results_table[$i]{finished} ) {
	    $results_table[$i]{place} = $i + 1;
	} else {
	    $results_table[$i]{place} = "DNF";
	}
	$results_table[$i]{fastest} = ms_format($results_table[$i]{fastest});
	$results_table[$i]{total} = ms_format($results_table[$i]{total});
    }
    
    template 'results', {
	"event_info" => $cr,
	"baseurl" => "/club/$club/$event",
        "cluburl" => "/club/$club",
        "results" => \@results_table,
    };

};

get '/club/:club/:event/lap' => sub {
    my $club = params->{club};
    my $event = params->{event};
    
    my $sth = database->prepare(
	"select * from club join event using (club_id) where club_id = ? and event_id = ?"
	);
    $sth->execute($club, $event);
    my $cr = $sth->fetchrow_hashref();
    template 'lap', {
	"event_info" => $cr,
	"baseurl" => "/club/$club/$event",
	"cluburl" => "/club/$club",
    };
};

sub ms_format {
    my $ms = shift;
    my $ms_places = shift || 3;

    my $p_ms = $ms % 1000; # milliseconds
    my $p_seconds = floor( $ms / 1000 ); # Whole seconds
    my $p_minutes = floor( $p_seconds / 60 ); # Whole minutes
    
    return sprintf('%1d:%02d.%0'.$ms_places.'d',$p_minutes,$p_seconds,$p_ms);
}

true;
