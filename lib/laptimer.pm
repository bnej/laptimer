use strict;
use warnings;

package laptimer;
use Dancer ':syntax';
use Dancer::Plugin::Database;

our $VERSION = '0.1';

get '/' => sub {
    template 'index';
};

get '/club/:club/:event/stopwatch' => sub {
    my $club = params->{club};
    my $event = params->{event};
    
    my $sth = database->prepare(
	"select * from club join event using (club_id) where club_id = ? and event_id = ?"
	);
    $sth->execute($club, $event);
    my $cr = $sth->fetchrow_hashref();
    template 'stopwatch', { event_info => $cr };
};

true;
