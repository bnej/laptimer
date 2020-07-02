use strict;
use warnings;

package laptimer;
use Dancer ':syntax';
use Dancer::Plugin::Database;

our $VERSION = '0.1';

get '/' => sub {
    template 'index';
};

get '/club/:club/stopwatch' => sub {
    my $club = params->{club};
    my $sth = database->prepare(
	"select * from club where clubid = ?"
	);
    $sth->execute($club);
    my $cr = $sth->fetchrow_hashref();
    template 'stopwatch', { club => $cr->{clubname} };
};

true;
