use strict;
use warnings;

package laptimer;
use Dancer ':syntax';

our $VERSION = '0.1';

get '/' => sub {
    template 'index';
};

get '/club/:club/stopwatch' => sub {
    my $club = params->{club};
    template 'stopwatch', { club => $club };
};

true;
