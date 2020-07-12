use strict;
use warnings;

package laptimer;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Exception qw(:all);

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

get '/club/:club/:event/lap' => sub {
    my $club = params->{club};
    my $event = params->{event};
    
    my $sth = database->prepare(
	"select * from club join event using (club_id) where club_id = ? and event_id = ?"
	);
    $sth->execute($club, $event);
    my $cr = $sth->fetchrow_hashref();
    template 'lap', { event_info => $cr,
		      "baseurl" => "/club/$club/$event" };

};

true;
