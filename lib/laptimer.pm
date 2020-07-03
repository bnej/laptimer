use strict;
use warnings;

package laptimer;
use Dancer ':syntax';
use Dancer::Plugin::Database;

our $VERSION = '0.1';

get '/' => sub {
    template 'index';
};

post '/club/:club/:event/timing' => sub {
    my $club = params->{club};
    my $event = params->{event};

    my $timing = params->{timing};
    my $sth = database->prepare("insert into time_mark (event_id, timing_number, timing_mark) values (?,?,?)");

    my $r = [ ];
    foreach my $time (@$timing) {
	$sth->execute( $event, $time->{mark_number}, $time->{mark} );
	push @$r, { mark_number => $time->{mark_number},
		    mark => $time->{mark},
		    sync => 1 };
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

true;
