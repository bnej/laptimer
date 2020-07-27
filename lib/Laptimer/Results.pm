use strict;
use warnings;

package Laptimer::Results;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Exception qw(:all);
use Laptimer::Util qw(:all);

sub load_results {
    my ($class, $cr) = @_;

    if( $cr->{event_active} ) {
	return $class->load_live( $cr );
    } else {
	return $class->load_table( $cr );
    }
}

sub athlete {
    my ($class, $id) = @_;
    my $sth_a = database->prepare(
	'select * from athlete where athlete_id = ?'
	) or die database->errstr;
    $sth_a->execute( $id );

    return $sth_a->fetchrow_hashref;
}

sub load_live {
    my ($class, $cr) = @_;
    my $club = $cr->{club_id};
    my $event = $cr->{event_id};

    my %athletes = ( );
    my $final_lap_n = $cr->{start_lap} + $cr->{total_laps};
    
    my $sth = database->prepare(
	"select * from place_mark join time_mark using (timing_number, event_id) where event_id = ? order by timing_number asc"
	) or die database->errstr;
    
    $sth->execute( $event );

    while( my $r = $sth->fetchrow_hashref ) {
	my $id = $r->{athlete_id};
	my $time = $r->{timing_mark};
	if( !$athletes{$id} ) {
	    $athletes{$id} = {
		url => "/results/$club/$event/$id",
		laps => [ ],
		fastest => undef,
		total => 0,
		event_laps => 0,
		prior => 0,
		name => undef,
		finished => 0,
		n => 0,
	    };
	}
	next if $athletes{$id}{finished};

	my $lap = $time - $athletes{$id}{prior};
	$athletes{$id}{prior} = $time;
	push @{$athletes{$id}{laps}}, $lap;
	
	if($athletes{$id}{n} >= $cr->{start_lap}) {
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
	$athletes{$id}{n} ++;
    }
    foreach my $id (keys %athletes) {
	$athletes{$id}{name} = $class->athlete($id)->{athlete_name};
    }

    
    my @results_table = sort { $b->{event_laps} <=> $a->{event_laps} || $a->{total} <=> $b->{total} } values %athletes;
    for( my $i = 0; $i < @results_table; $i ++ ) {
	if( $results_table[$i]{finished} ) {
	    $results_table[$i]{place} = $i + 1;
	} else {
	    $results_table[$i]{place} = ($i + 1)."*";
	}
	$results_table[$i]{fastest} = ms_format($results_table[$i]{fastest});
	$results_table[$i]{total} = ms_format($results_table[$i]{total});
    }

    return \@results_table;
}

1;
