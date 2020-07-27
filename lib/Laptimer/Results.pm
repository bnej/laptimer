use strict;
use warnings;

package Laptimer::Results;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Exception qw(:all);
use Laptimer::Util qw(:all);

sub event {
    my ($class, $cr) = @_;

    my $r;
    if( $cr->{event_active} ) {
	$r = $class->load_live( $cr );
    } else {
	$r = $class->load_table( $cr );
    }
    return $class->add_splits($r);
}

sub add_splits {
    my ($class, $r) = @_;

    my $best = $r->[0];
    $best->{split} = '';
    for( my $i = 1; $i < @$r; $i ++ ) {
	$r->[$i]{split} = ms_format($r->[$i]{total_ms} - $best->{total_ms},3,'+');
    }
    return $r;
}
    

sub laps {
    my ($class, $cr, $athlete) = @_;

    if( $cr->{event_active} ) {
	return $class->laps_live( $cr, $athlete );
    } else {
	return $class->laps_table( $cr, $athlete );
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

sub finalise {
    my ( $class, $cr ) = @_;
    my $results = $class->load_live( $cr );
    $class->flush_event( $cr );
    my $event = $cr->{event_id};

    my $ins_rp = database->prepare(
	"insert into result_place values ( ?, ?, ?, ?, ? )"
	) or die database->errstr;;
    my $ins_rl = database->prepare(
	"insert into result_lap values ( ?, ?, ?, ? )"
	) or die database->errstr;
    my $upd_f = database->prepare(
	"update event set event_active = ? where event_id = ?"
	) or die database->errstr;
    
    foreach my $r ( @$results ) {
	$ins_rp->execute(
	    $event,
	    $r->{place},
	    $r->{id},
	    $r->{fastest_ms},
	    $r->{total_ms}
	    );
	my $laps = $r->{laps};
	my $i = 0;
	foreach my $l ( @$laps ) {
	    $i++;
	    $ins_rl->execute( $event, $r->{id}, $i, $l );
	}
    }
    $upd_f->execute( 0, $event ); # Mark completed
}

sub flush_event {
    my ( $class, $cr ) = @_;
    my $del_rp = database->prepare(
	"delete from result_place where event_id = ?"
	) or die database->errstr;

    my $del_rl = database->prepare(
	"delete from result_lap where event_id = ?"
	) or die database->errstr;

    $del_rp->execute( $cr->{event_id} );
    $del_rl->execute( $cr->{event_id} );

    return 1;
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
		id => $id,
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
	
	if($athletes{$id}{n} >= $cr->{start_lap}) {
	    my $event_laps = ++ $athletes{$id}{event_laps};
	    push @{$athletes{$id}{laps}}, $lap;
	    
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
	$results_table[$i]{fastest_ms} = $results_table[$i]{fastest}; # save
	$results_table[$i]{fastest} = ms_format($results_table[$i]{fastest});
	
	$results_table[$i]{total_ms} = $results_table[$i]{total}; # save
	$results_table[$i]{total} = ms_format($results_table[$i]{total});
    }

    return \@results_table;
}

sub laps_live {
    my ($class, $cr, $athlete) = @_;
    my $event = $cr->{event_id};
    
    my $sth = database->prepare(
	"select * from place_mark join time_mark using (timing_number, event_id) where event_id = ?  and athlete_id = ? order by timing_number asc"
	) or die database->errstr;
    $sth->execute( $event, $athlete );


    my @laps = ( );

    # These are the positions, not the times.
    my $fastest = 0;
    my $slowest = 0;
    
    my $total = 0;
    my $event_laps = 0;
    my $prior = 0;
    my $finished = 0;
    my $n = 0;
    while( my $r = $sth->fetchrow_hashref ) {
	my $time = $r->{timing_mark};

	my $lap = $time - $prior;
	$prior = $time;

	if( $n >= $cr->{start_lap} ) {
	    push @laps, $lap;
	    if( $lap > $laps[$slowest] ) {
		$slowest = $event_laps;
	    } elsif( $lap < $laps[$fastest] ) {
		$fastest = $event_laps;
	    }
	    $event_laps ++;
	    if( $event_laps >= $cr->{total_laps} ) {
		$finished = 1;
	    }
	}
	$n ++;
	last if $finished;
    }

    my @r = ( );
    $total = 0;
    for( my $i = 0; $i < @laps; $i ++ ) {
	my $lap = $laps[$i];
	$total += $lap;
	my $split = '';
	if( $i > 0 ) {
	    $split = ms_format($lap - $laps[$i - 1], 3, '+');
	}
	push @r, {
	    lap_n => $i + 1,
	    fastest => ( $i == $fastest ? 1 : 0 ),
	    slowest => ( $i == $slowest ? 1 : 0 ),
	    lap_ms => $lap,
	    lap => ms_format($lap),
	    split => $split,
	    total => ms_format($total),
	};
    }

    return \@r;
}

1;
