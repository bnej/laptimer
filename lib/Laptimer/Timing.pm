use strict;
use warnings;

package Laptimer::Timing;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Exception qw(:all);
use Laptimer::Util qw(:all);

sub sync {
    my ($class, $event_id, $marks) = @_;

    my $sm = database->prepare("insert into time_mark (event_id, timing_number, timing_mark, time_ms) values (?,?,?,?)");
    my $sm_fetch = database->prepare("select * from time_mark where event_id = ? and timing_number = ?");

    my $sp = database->prepare("insert into place_mark (event_id, timing_number, athlete_id, place_ms) values (?,?,?,?)") or die database->errstr;
    my $a_laps = database->prepare("select * from place_mark join time_mark using (timing_number, event_id) where athlete_id = ? and event_id = ? order by timing_number desc limit 2") or die database->errstr;

    my @r = ( );
    foreach my $mark (@$marks) {
	my $timing_number = $mark->{timing_number};
	my $timestamp = $mark->{timestamp};
	my $mark_t = $mark->{mark};
	my $athlete_id = $mark->{id};

	my $lr = {
	    timing_number => $timing_number,
	    timestamp => $timestamp,
	    sync => 1,
	};
	if( $mark_t ) {
	    # Sync mark
	    my $ok =
		$sm->execute($event_id, $timing_number, $mark_t, $timestamp);
	    $lr->{mark} = $mark_t;
	    $lr->{sync} = $lr->{sync} && $ok;
	}

	if( $athlete_id ) {
	    # Sync lap
	    my $ok =
		$sp->execute($event_id, $timing_number, $athlete_id, $timestamp);
	    $lr->{id} = $athlete_id;
	    $lr->{sync} = $lr->{sync} && $ok;

	    $a_laps->execute( $lr->{id}, $event_id ) or die $a_laps->errstr;
	    my $last = $a_laps->fetchrow_hashref;
	    my $previous = $a_laps->fetchrow_hashref;
	    
	    $lr->{lap_time} = $lr->{total_time} = $last->{timing_mark};
	    if( $previous ) {
		$lr->{lap_time} = $last->{timing_mark} - $previous->{timing_mark};
	    }
	}

	push @r, $lr;
    }

    return \@r;
}

1;
