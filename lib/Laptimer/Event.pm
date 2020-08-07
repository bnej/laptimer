use strict;
use warnings;

package Laptimer::Event;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Exception qw(:all);
use Laptimer::Util qw(:all);

my @keys = qw(
    event_id event_type_id club_id club_name event_name event_type_name
    event_text start_lap total_laps repeat lap_length event_active
    );

my $sel = "select event_id, event_type_id, club_id, club_name, event_name, event_type_name, event_text, coalesce(event.start_lap, event_type.start_lap) as start_lap, coalesce(event.total_laps, event_type.total_laps) as total_laps, repeat, lap_length, event_active from club join event using (club_id) left join event_type using (event_type_id)";
    
sub load_event {
    my $class = shift;
    my $club = shift;
    my $event = shift;
    
    my $sth = database->prepare(
	"$sel where club_id = ? and event_id = ?;"
	) or die database->errstr;
    $sth->execute( $club, $event ) or die $sth->errstr;

    my $r = $sth->fetchrow_hashref;

    if( $r ) {
	return bless $r, $class;
    } else {
	return undef;
    }
}

sub load_club {
    my $class = shift;
    my $club = shift;
    
    my $sth = database->prepare(
	"$sel where club_id = ?"
	) or die database->errstr;
    $sth->execute( $club ) or die $sth->errstr;

    my @r = ( );
    while( my $r = $sth->fetchrow_hashref ) {
	push @r, bless( $r, $class );
    }
    return \@r;
}

sub marks {
    my $self = shift;
    my $event_id = $self->event_id;

    my $sth = database->prepare(
	"select * from time_mark full outer join place_mark ".
	"using (event_id, timing_number) where event_id = ? ".
	"order by timing_number"
	);
    $sth->execute( $event_id );

    my @r;
    while( my $row = $sth->fetchrow_hashref ) {
	push @r, {
	    mark => $row->{timing_mark},
	    timing_number => $row->{timing_number},
	    mark_fmt => ms_format( $row->{timing_mark} ),
	    sync => 1,
	    timestamp => $row->{timestamp},
	};
    }
    return \@r;
}

sub TO_JSON {
    my $self = shift;
    my $r = { };
    foreach my $key ( @keys ) {
	$r->{$key} = $self->$key;
    }
    $r->{marks} = $self->marks;
    $r->{last_mark} = $r->{marks}[-1]{timing_number};
    $r->{last_offset} = $r->{marks}[-1]{mark};
    return $r;
}

sub event_id { return $_[0]->{event_id}; }
sub event_type_id { return $_[0]->{event_type_id}; }
sub club_id { return $_[0]->{club_id}; }
sub club_name { return $_[0]->{club_name}; }
sub event_name { return $_[0]->{event_name}; }
sub event_type_name { return $_[0]->{event_type_name}; }
sub event_text { return $_[0]->{event_text}; }
sub start_lap { return $_[0]->{start_lap}; }
sub total_laps { return $_[0]->{total_laps}; }
sub repeat { return $_[0]->{repeat}; }
sub lap_length { return $_[0]->{lap_length}; };
sub event_active { return $_[0]->{event_active}; };

1;
