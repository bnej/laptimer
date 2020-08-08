use strict;
use warnings;

package laptimer;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Exception qw(:all);

use Crypt::SaltedHash;

use Laptimer::Results;
use Laptimer::Event;
use Laptimer::EventType;
use Laptimer::Timing;

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
	    up => [
		{
		    link => "/combined",
		    name => "Combined Results",
		}
	    ],
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
    
    my $events = Laptimer::Event->load_club( $club, "event_active" );
    foreach my $event (@$events) {
	my $id = $event->event_id;
	$event->hilight( 0 );
	if($hilight == $id) {
	    $event->hilight( 1 );
	}
    }

    my $et_sth = database->prepare(
	"select * from event_type"
	) or die database->errstr;
    $et_sth->execute or die database->errstr;
    
    my @et = ( );
    while( my $r = $et_sth->fetchrow_hashref ) {
	push @et, $r;
    }

    template 'list_events', {
	club => $cr,
	cluburl => "/club/$club",
	events => $events,
	error => $error,
	event_types => \@et,
    };
};

post '/club/:club/new_event' => sub {
    my $club = params->{club};
    my $event_type = params->{event_type};

    unless( $event_type ) {
	return redirect "/club/$club?error=missing_field";
    }

    my $et_sth = database->prepare("select * from event_type where event_type_id = ?");
    $et_sth->execute($event_type);
    my $et = $et_sth->fetchrow_hashref;

    my $event_name = $et->{event_type_name};
    my $event_start = $et->{start_lap};
    my $total_laps = $et->{total_laps};

    my $sth = database->prepare(
	"insert into event (club_id, event_name, start_lap, total_laps, event_active, event_type_id, event_date) values (?,?,?,?,true,?,current_date) returning event_id"
	) or die database->errstr;
    
    my $inserted = $sth->execute($club, $event_name, $event_start, $total_laps, $event_type) or die $sth->errstr;
    
    if($inserted) {
	my $r = $sth->fetchrow_hashref;
	my $event_id = $r->{event_id};
	return redirect "/club/$club?hilight=$event_id";
    } else {
	return redirect "/club/$club?error=insert_fail";
    }
};

get '/club/:club/:event/inspect' => sub {
    my $club = params->{club};
    my $event = params->{event};

    my $cr = Laptimer::Event->load_event( $club, $event );

    my ($results, $marks) = Laptimer::Results->load_live( $cr );
    my $j = 0;
    my %a_id = ( );
    foreach my $m (@$marks) {
	my $id = $m->{id};
	if( not defined $a_id{$id} ) {
	    $a_id{$id} = $j;
	    $j++;
	}
    }

    my $n_r = scalar keys %a_id;
    my @header = (0) x $n_r;
    foreach my $k (keys %a_id) {
	my $a = Laptimer::Results->athlete( $k );
	@header[$a_id{$k}] = $a->{athlete_name};
    }
    unshift @header, "#";
    unshift @header, "T";
    
    my @r = ( );
    my @col_sums = (0) x $n_r;
    my @col_counts = (0) x $n_r;
    my @col_means = (0) x $n_r;
    
    foreach my $m (@$marks) {
	my $id = $m->{id};
	my $row = [ ('') x $n_r ];
	my $ix = $a_id{$id};

	if( $m->{active} ) {
	    $col_sums[$ix] += $m->{lap};
	    $col_counts[$ix] ++;
	}
	
	$row->[$ix] = ms_format( $m->{lap},1 );
	unshift @$row, ms_format( $m->{time},1 );
	unshift @$row, $m->{mark};
	push @r, { active => $m->{active}, row => $row };
    }

    for( my $i = 0; $i < scalar @col_means; $i++ ) {
	$col_means[$i] = $col_sums[$i] / $col_counts[$i];
    }

    for( my $i = 0; $i < @r; $i ++ ) {
	my $m = $marks->[$i];
	my $id = $m->{id};
	my $ix = $a_id{$id};

	my $var = $m->{lap} - $col_means[$ix];

	my $var_pc = sprintf("%0.1f", abs($var / $col_means[$ix] * 100));
	$r[$i]{var_pc} = $var_pc;
	$r[$i]{var} = ms_format( $var, 1, '+' );

	next if ! $r[$i]{active};
	
	# Now scan up or down to find if there is another mark closer
	# to their average.
	my $dir = $var > 0 ? -1 : 1; # scan direction.
	my $j = $i;
	my $delta = 0;
	while( abs($delta) < abs($var)) {
	    if( ! $r[$j]{row}[$ix + 2] ) {
		$r[$j]{row}[$ix + 2] =
		    '?'.ms_format( $marks->[$i]{lap} + $delta, 1 );
	    }
	    $j += $dir;
	    last if $j >= scalar(@r);
	    last if $j <= 0;
	    $delta =  $marks->[$j]{time} - $marks->[$i]{time};
	}
	
    }

    template 'inspect_event' => {
	event => $cr,
	cluburl => "/club/$club",
	header => \@header,
	marks => \@r,
    };
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
	    timing_number => $r->{timing_number},
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

    my $cr = Laptimer::Event->load_event( $club, $event );

    return $cr;
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

post '/club/:club/:event/lap_data' => sub {
    my $club = params->{club};
    my $event = params->{event};

    my $laps = params->{marks};

    my $r = Laptimer::Timing->sync( $event, $laps );

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

get '/club/:club/:event/single_timer' => sub {
    my $club = params->{club};
    my $event = params->{event};
    
    my $cr = Laptimer::Event->load_event( $club, $event );
    template 'single_timer', {
	"event_info" => $cr,
	    "cluburl" => "/club/$club",
	    "baseurl" => "/club/$club/$event"
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

get '/club/:club/:event/finalise' => sub {
    my $club = params->{club};
    my $event = params->{event};

    my $sth = database->prepare(
	"select * from club join event using (club_id) where club_id = ? and event_id = ?"
	);
    $sth->execute($club, $event);
    my $cr = $sth->fetchrow_hashref();
    template 'finalise', {
	"event_info" => $cr,
	"baseurl" => "/club/$club/$event",
	"cluburl" => "/club/$club",
    };
};

post '/club/:club/:event/finalise' => sub {
    my $club = params->{club};
    my $event = params->{event};

    my $cr = Laptimer::Event->load_event( $club, $event );
    Laptimer::Results->finalise( $cr );

    redirect "/club/$club";
};

get '/club/:club/:event' => sub {
    my $club = params->{club};
    my $event = params->{event};

    my $cr = Laptimer::Event->load_event( $club, $event );

    template 'event', {
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

    my $events = Laptimer::Event->load_club( $club );

    template 'list_results', {
	"club" => $cr,
        "events" => $events,
    };

};

get '/results/:club/:event' => sub {
    my $club = params->{club};
    my $event = params->{event};

    my $cr = Laptimer::Event->load_event( $club, $event );
    my $results_table = Laptimer::Results->event( $cr );
    
    template 'results', {
	"event_info" => $cr,
	    "baseurl" => "/results/$club/$event",
	    "cluburl" => "/results/$club",
	    "up" => [
		{
		    "link" => "/results/$club",
			"name" => $cr->{club_name},
		},
	    ],
	    "results" => $results_table,
    };
};

get '/results/:club/:event/:athlete' => sub {
    my $club = params->{club};
    my $event = params->{event};
    my $athlete = params->{athlete};

    my $sth_a = database->prepare(
	'select * from athlete where athlete_id = ?'
	) or die database->errstr;
    $sth_a->execute($athlete);
    my $ar = $sth_a->fetchrow_hashref;

    my $cr = Laptimer::Event->load_event( $club, $event );
    my $r = Laptimer::Results->laps( $cr, $athlete );
	    
    template 'results_athlete', {
	event_info => $cr,
	athlete => $ar,
	results => $r,
	up => [
	    {
		link => "/results/$club/$event",
		name => $cr->{event_name},
	    },
	    {
		link => "/results/$club",
		name => $cr->{club_name},
	    },
	    ],
    };
};

get '/combined/:event_type' => sub {
    my $event_type = params->{event_type};

    my $cr = Laptimer::EventType->load_type( $event_type );
    my $results_table = Laptimer::Results->event_type_combined( $event_type );
    template 'results_combined', {
	"type_info" => $cr,
	"baseurl" => "/combined/$event_type",
	"up" => [
	    {
		"link" => "/combined",
		"name" => "Combined",
	    },
	    ],
	"results" => $results_table,
    };
};

get '/combined' => sub {
    my $cr = Laptimer::EventType->load_all( );

    template 'combined', {
	"event_types" => $cr
    };
};

true;
