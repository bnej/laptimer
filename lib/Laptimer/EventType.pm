package Laptimer::EventType;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Exception qw(:all);
use Laptimer::Util qw(:all);

use DateTime;
use DateTime::Format::Pg;

my @keys = qw(
    event_type_id event_type_name start_laps total_laps repeat lap_length
    );

my $sel = "select * from event_type";

sub load_type {
    my $class = shift;
    my $type = shift;
    
    my $sth = database->prepare(
	"$sel where event_type_id = ?;"
	) or die database->errstr;
    $sth->execute( $type ) or die $sth->errstr;

    my $r = $sth->fetchrow_hashref;

    if( $r ) {
	return bless $r, $class;
    } else {
	return undef;
    }
}

sub rider_list {
    my $self = shift;
    my $type_id = $self->event_type_id;
    
    my $sth = database->prepare("select * from athlete where athlete_id in (select athlete_id from result_place join event using (event_id) where event_type_id = ?) order by athlete_name");
    $sth->execute( $type_id );

    my @r = ( );
    while( my $r = $sth->fetchrow_hashref ) {
	push @r, $r;
    }

    return \@r;
}

sub load_all {
    my $class = shift;
    
    my $sth = database->prepare(
	"$sel order by event_type_name"
	) or die database->errstr;
    $sth->execute( ) or die $sth->errstr;

    my @r = ( );
    while( my $r = $sth->fetchrow_hashref ) {
	push @r, bless( $r, $class );
    }

    return \@r;
}

sub event_type_id { return $_[0]->{event_type_id}; }
sub event_type_name { return $_[0]->{event_type_name}; }
sub start_laps { return $_[0]->{start_laps}; }
sub total_laps { return $_[0]->{total_laps}; }
sub laps  { return $_[0]->{total_laps}; }
sub repeat { return $_[0]->{repeat}; }

sub results_url {
    my $self = shift;
    my $event_type_id = $self->event_type_id;
    return "/combined/$event_type_id";
}

sub lap_length { return $_[0]->{lap_length}; }
sub distance {
    my $self = shift;
    return sprintf('%0.0fm', $self->lap_length * $self->laps );
}

1;
