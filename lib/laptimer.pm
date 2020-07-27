use strict;
use warnings;

package laptimer;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Exception qw(:all);

use Crypt::SaltedHash;

use Laptimer::Results;
use Laptimer::Util qw(:all);

our $VERSION = '0.1';

get '/' => sub {
    my $sth = database->prepare(
	"select * from club order by club_name"
	);
    $sth->execute;

    my @clubs;
    while( my $r = $sth->fetchrow_hashref ) {
	my $club_id = $r->{club_id};
	$r->{url} = "/club/$club_id";
	$r->{results_url} = "/results/$club_id";
	push @clubs, $r;
    }
    
    template 'index', {
        "clubs" => \@clubs,
    };
};

get '/login' => sub {
    template 'login', {
	path => vars->{requested_path},
	failed => params->{failed}
    };
};

post '/login' => sub {
    my $username = params->{username} || '';
    my $password = params->{password} || '';
    
    my $user = database->quick_select(
	'club_user',
	{ username => $username }
	);

    my $csh = Crypt::SaltedHash->new(algorithm => 'SHA-1');
    if($user) {
	if( $csh->validate( $user->{password}, $password ) ) {
	    my $club_id = $user->{club_id};
	    session user => $user;
	    redirect "/club/$club_id";
	} else {
            warning("Login failed - password incorrect for $username");
            redirect '/login?failed=1';
        }
    } else {
	warning("Login failed - unrecognised user $username");
	redirect '/login?failed=1';
    }
};

post '/logout' => sub {
    session user => undef;
    redirect '/';
};

hook 'before_template_render' => sub {
    my $tokens = shift;
    $tokens->{user} = session 'user';
};

hook 'before' => sub {
    if( request->path_info =~ m{^/club/([A-Za-z0-9]+)} ) {
	my $club = $1;

	my $user = session('user');
	if( $user && $user->{club_id} eq $club ) {
	    # All OK
	} else {
	    var requested_path => request->path_info;
	    request->path_info('/login');
	}
    }
};

get '/club/:club' => sub {
    my $club = params->{club};

    my $hilight = params->{hilight} || 0;
    my $error = params->{error} || '';
    
    my $sth = database->prepare(
	"select * from club where club_id = ?"
	);
    $sth->execute( $club );
    my $cr = $sth->fetchrow_hashref;
    $cr->{url} = "/club/$club";
    
    $sth = database->prepare(
	"select * from event where club_id = ? order by event_id"
	) or die database->errstr;
    $sth->execute($club) or die $sth->errstr;
    
    my @r = ( );
    while( my $r = $sth->fetchrow_hashref ) {
	my $id = $r->{event_id};
	$r->{hilight} = 0;
	if($hilight == $id) {
	    $r->{hilight} = 1;
	}
	$r->{url} = "/club/$club/$id";
	push @r, $r;
    }

    template 'list_events', {
	club => $cr,
	cluburl => "/club/$club",
	events => \@r,
	error => $error,
    };
};

post '/club/:club/new_event' => sub {
    my $club = params->{club};
    my $event_name = params->{event_name};
    my $event_start = params->{event_start};
    my $total_laps = params->{total_laps};

    unless( $event_name && $event_start && $total_laps ) {
	return redirect "/club/$club?error=missing_field";
    }

    my $sth = database->prepare(
	"insert into event (club_id, event_name, start_lap, total_laps, event_active) values (?,?,?,?,true) returning event_id"
	) or die database->errstr;
    
    my $inserted = $sth->execute($club, $event_name, $event_start, $total_laps) or die $sth->errstr;
    if($inserted) {
	my $r = $sth->fetchrow_hashref;
	my $event_id = $r->{event_id};
	return redirect "/club/$club?hilight=$event_id";
    } else {
	return redirect "/club/$club?error=insert_fail";
    }
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

get '/club/:club/:event/info' => sub {
    my $club = params->{club};
    my $event = params->{event};

    my $sth = database->prepare(
	"select * from event where club_id = ? and event_id = ?"
	) or die database->errstr;
    $sth->execute( $club, $event );
    my $er = $sth->fetchrow_hashref;

    return $er;
};

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
    template 'stopwatch', { "event_info" => $cr,
			    "cluburl" => "/club/$club",
			    "baseurl" => "/club/$club/$event" };
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

get '/results/:club' => sub {
    my $club = params->{club};
    
    my $sth = database->prepare(
	"select * from club where club_id = ?"
	);
    $sth->execute( $club );
    my $cr = $sth->fetchrow_hashref;
    
    $sth = database->prepare(
	"select * from event where club_id = ? order by event_id"
	) or die database->errstr;
    $sth->execute( $club );

    my @r;
    while( my $r = $sth->fetchrow_hashref ) {
	my $id = $r->{event_id};
	$r->{url} = "/results/$club/$id";
	push @r, $r;
    }
    
    template 'list_results', {
	"club" => $cr,
        "events" => \@r,
    };

};

get '/results/:club/:event' => sub {
    my $club = params->{club};
    my $event = params->{event};

    my $sth_club = database->prepare(
	"select * from club join event using (club_id) where club_id = ? and event_id = ?"
	);
    $sth_club->execute($club, $event);
    my $cr = $sth_club->fetchrow_hashref();

    my $results_table = Laptimer::Results->event( $cr );
    
    template 'results', {
	"event_info" => $cr,
	"baseurl" => "/club/$club/$event",
        "cluburl" => "/club/$club",
        "results" => $results_table,
    };
};

get '/results/:club/:event/:athlete' => sub {
    my $club = params->{club};
    my $event = params->{event};
    my $athlete = params->{athlete};

    my $sth_club = database->prepare(
	"select * from club join event using (club_id) where club_id = ? and event_id = ?"
	);
    $sth_club->execute($club, $event);
    my $cr = $sth_club->fetchrow_hashref();

    my $sth_a = database->prepare(
	'select * from athlete where athlete_id = ?'
	) or die database->errstr;
    $sth_a->execute($athlete);
    my $ar = $sth_a->fetchrow_hashref;

    my $r = Laptimer::Results->laps( $cr, $athlete );
	    
    template 'results_athlete', {
	event_info => $cr,
	athlete => $ar,
	results => $r,
    };
};



true;
