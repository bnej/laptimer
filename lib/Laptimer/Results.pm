use strict;
use warnings;

package Laptimer::Results;

use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Exception qw(:all);
use Laptimer::Util qw(:all);

use DateTime;
use DateTime::Format::Pg;

sub event {
    my ($class, $cr) = @_;

    my $r;
    if( $cr->{event_active} ) {
	$r = $class->load_live( $cr );
    } else {
	$r = $class->load_table( $cr );
    }
    $class->compare_distance( $cr, $r ); # Compare to best
    return $class->add_calculated( $cr, $r );
}

sub event_type_combined {
    my ( $class, $event_type, $athlete_id ) = @_;
    my $r = $class->load_table_combined( $event_type, $athlete_id );
    $class->compare_distance( undef, $r ); # Compare to best
    return $class->add_calculated( undef, $r );
}

sub add_calculated {
    my ($class, $cr, $r) = @_;

    my $best = $r->[0];
    $best->{split} = '';
    for( my $i = 1; $i < @$r; $i ++ ) {
	$r->[$i]{split} = ms_format(
	    ($r->[$i]{total_ms} || 0) -
	    ($best->{total_ms} || 0),3,'+');
    }

    my $lap_length = $cr ? $cr->lap_length : 333.3;
    foreach my $res ( @$r ) {
	my $ms = $res->{total_ms} || 0;
	# The lap length may be on the result record, or we can take it
	# from the event record, or default to 333.3.
	my $track_length = $res->{lap_length} || $lap_length;
	my $laps = $res->{event_laps};

	my $total_length = $track_length * $laps;

	if( $ms > 0 ) {
	    my $km_h = ( $total_length / 1000 ) / ( $ms / (1000 * 60 * 60) );
	    $km_h = sprintf('%0.1f', $km_h);
	    $res->{speed} = $km_h;
	} else {
	    $res->{speed} = "0.0";
	}

	$res->{fault} = 0;
	if( $res->{speed} > 100 ) {
	    $res->{fault} = 1;
	} elsif( ! $ms ) {
	    # Invalid total time.
	    $res->{fault} = 1;
	}
    }
    
    return $r;
}

sub compare_distance {
    my ($class, $cr, $r, $cmp_time) = @_; # Time is the benchmark
					  # time. We are going to
					  # estimate +/- distance
					  # relative to that time.
    
    $cmp_time //= $r->[0]{total_ms}; # Default to first time if not supplied

    my $lap_length = $cr ? $cr->lap_length : 333.3;
    foreach my $res (@$r) {
	my $ms = $res->{total_ms} || 0;
	next if $ms == 0;
	
	my $track_length = $res->{lap_length} || $lap_length;
	my $laps = $res->{event_laps};

	my $total_length = $track_length * $laps;

	my $m_ms = $total_length / $ms;
	my $delta_time = $ms - $cmp_time;
	my $delta_m = sprintf("%0.1f",$m_ms * $delta_time);
	$res->{behind_m} = $delta_m;
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
	"insert into result_place values ( ?, ?, ?, ?, ?, ?, ? )"
	) or die database->errstr;;
    my $ins_rl = database->prepare(
	"insert into result_lap values ( ?, ?, ?, ?, ? )"
	) or die database->errstr;
    my $upd_f = database->prepare(
	"update event set event_active = ? where event_id = ?"
	) or die database->errstr;
    
    foreach my $r ( @$results ) {
	# Do not save results that have been marked fault, they would
	# have to be corrected first.
	next if $r->{fault};

	$ins_rp->execute(
	    $event,
	    $r->{place},
	    $r->{id},
	    $r->{effort},
	    $r->{fastest_ms},
	    $r->{total_ms},
	    $r->{event_laps}
	    ) or die $ins_rp->errstr;
	my $laps = $r->{laps};
	my $i = 0;
	foreach my $l ( @$laps ) {
	    $i++;
	    $ins_rl->execute( $event,
			      $r->{id}, $r->{effort},
			      $i, $l ) or die $ins_rl->errstr;
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

sub load_table_combined {
    my ($class, $event_type, $athlete_id) = @_;

    my $where_athlete = "true";
    my @bind = ( $event_type );
    if( $athlete_id ) {
	$where_athlete = "athlete_id = ?";
	push @bind, $athlete_id;
    }

    my @r;
    my $sth = database->prepare(
	"select * from event_type join event using (event_type_id)".
	" join result_place using (event_id)".
	" join athlete using (athlete_id)".
	" where event_type_id = ?".
	" and $where_athlete".
	" order by event_laps desc, total_time asc"
	) or die database->errstr;
    my $place = 1;

    $sth->execute( @bind ) or die $sth->errstr;

    while( my $r = $sth->fetchrow_hashref ) {
	my $id = $r->{athlete_id};
	my $club = $r->{club_id};
	my $event = $r->{event_id};

	my $date_fmt = DateTime::Format::Pg->parse_date( $r->{event_date} )->format_cldr( 'ccc dd MMM yyyy' );

	push @r, {
	    id => $id,
	    url => "/results/$club/$event/$id",
	    place => $place ++,
	    name => $r->{athlete_name},
	    total_ms => $r->{total_time},
	    total => ms_format( $r->{total_time} ),
	    effort => $r->{effort},
	    fastest_ms => $r->{best_lap},
	    fastest => ms_format( $r->{best_lap} ),
	    event_laps => $r->{event_laps},
	    finished => ($r->{event_laps} >= $r->{total_laps} ? 1 : 0 ),
	    lap_length => $r->{lap_length},
	    date => $date_fmt,
	};
    }
    
    return \@r;
}

sub best_time_combined {
    my ($class, $event_type, $athlete_id) = @_;
    
    my $table = $class->load_table_combined( $event_type );

    my %seen_athlete = ( );
    my $place = 1;
    my @r = ( );
    foreach my $r ( @$table ) {
	next if $seen_athlete{$r->{id}}; # Only take the first seen time.
	$r->{place} = $place ++; # Reset places.
	push @r, $r;
	$seen_athlete{$r->{id}} = 1;
    }

    $class->compare_distance( undef, \@r ); # Compare to best
    return $class->add_calculated( undef, \@r );
}

sub load_table {
    my ($class, $cr) = @_;
    my $club = $cr->{club_id};
    my $event = $cr->{event_id};

    my @r;
    my $sth = database->prepare(
	"select * from result_place join athlete using (athlete_id) where event_id = ? order by place"
	);
    $sth->execute( $event );
    my $i = 0;
    my $total_laps = $cr->{total_laps};
    
    while( my $r = $sth->fetchrow_hashref ) {
	my $id = $r->{athlete_id};
	push @r, {
	    id => $id,
	    url => "/results/$club/$event/$id",
	    place => $r->{place},
	    name => $r->{athlete_name},
	    total_ms => $r->{total_time},
	    total => ms_format( $r->{total_time} ),
	    effort => $r->{effort},
	    fastest_ms => $r->{best_lap},
	    fastest => ms_format( $r->{best_lap} ),
	    event_laps => $r->{event_laps},
	    finished => ($r->{event_laps} >= $total_laps ? 1 : 0 ),
	};
    }
    
    return \@r;
}

sub laps_table {
    my ($class, $cr, $athlete) = @_;
    my $club = $cr->{club_id};
    my $event = $cr->{event_id};

    my @r;
    my $sth = database->prepare(
	"select * from result_lap where event_id = ? and athlete_id = ? order by lap"
	);
    $sth->execute( $event, $athlete );

    my $prior_t = undef;
    my $fastest = undef;
    my $slowest = undef;
    my $total = 0;
    while( my $r = $sth->fetchrow_hashref ) {
	my $lap_t = $r->{lap_time};
	$total += $lap_t;
	my $split = '';
	if( defined $prior_t ) {
	    $split = ms_format( $lap_t - $prior_t, 3, '+' );
	}
	$prior_t = $lap_t;
	
	my $l = {
	    lap_n => $r->{lap},
	    lap_ms => $r->{lap_time},
	    lap => ms_format( $r->{lap_time} ),
	    split => $split,
	    total => ms_format( $total ),
	    fastest => 0, # These get updated at the end
	    slowest => 0, # These get updated at the end
	};
	$fastest = $l unless $fastest;
	$slowest = $l unless $slowest;

	if( $lap_t > $slowest->{lap_ms} ) {
	    $slowest = $l;
	}
	if( $lap_t < $fastest->{lap_ms} ) {
	    $fastest = $l;
	}
	push @r, $l;
    }

    if( $fastest && $slowest ) {
	$fastest->{fastest} = 1;
	$slowest->{slowest} = 1;
    }
    return \@r;
}

sub reset_athlete {
    my ($class, $club, $event, $id, $in) = @_;
    
    my $effort = 1;
    if($in) { $effort = $in->{effort} + 1; }
    
    return {
	id => $id,
	url => "/results/$club/$event/$id",
	laps => [ ],
	fastest => undef,
	total => 0,
	event_laps => 0,
	prior => 0,
	name => undef,
	finished => 0,
	saved => 0,
	n => 0,
	effort => $effort,
    };
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
    my @marks = ( );
    my @finished = ( );

    while( my $r = $sth->fetchrow_hashref ) {
	my $id = $r->{athlete_id};
	my $time = $r->{timing_mark};
	if( !$athletes{$id} ) {
	    $athletes{$id} = $class->reset_athlete( $club, $event, $id );
	}

	# still calculate for marks list
	my $lap = $time - $athletes{$id}{prior};
	$athletes{$id}{prior} = $time;

	# Check if started or finished
	my $started = $athletes{$id}{n} >= $cr->{start_lap};
	my $finished = $athletes{$id}{finished};
	my $active = $started && !$finished;
	
	push @marks, { mark => $r->{timing_number},
		       id => $id, lap => $lap, time => $time,
		       active => $active };
	if($started) {
	    # This condition is for non-repeating events - the athlete
	    # won't get reset so we have to truncate any additional
	    # laps they may have recorded.
	    if( ! $finished ) {
		my $event_laps = ++ $athletes{$id}{event_laps};
		push @{$athletes{$id}{laps}}, $lap;
		$finished = 0;
		if( $event_laps >= $cr->{total_laps} ) {
		    $athletes{$id}{finished} = 1;
		    $finished = 1;
		}
		$athletes{$id}{total} += $lap;
		if(defined $athletes{$id}{fastest}) {
		    $athletes{$id}{fastest} = $lap
			if $lap < $athletes{$id}{fastest};
		} else {
		    $athletes{$id}{fastest} = $lap; # First lap in event
		}
	    }
	    
	    if( $finished ) {

		# For non-repeating events, don't push the result on
		# more than once.
		if( ! $athletes{$id}{saved} ) {
		    push @finished, $athletes{$id};
		    $athletes{$id}{saved} = 1;
		}

		# If "repeat" is not true, any remaining marks are blank.
		if( $cr->repeat ) {
		    $started = 0;
		    $finished = 0;
		    $athletes{$id} = $class->reset_athlete( $club, $event, $id,
							    $athletes{$id});
		    
		    # DO NOT re-count that mark.
		    next;
		}
	    }
	}
	$athletes{$id}{n} ++;
    }

    foreach my $ar ( values %athletes ) {
	# If they are finished, the result is already in, this is to
	# add any DNFs or to show race-in-progress.
	if( $ar->{n} >= $cr->{start_lap} && !$ar->{finished} ) {
	    push @finished, $ar;
	}
    }
    
    foreach my $f (@finished) {
	$f->{name} = $class->athlete($f->{id})->{athlete_name};
	$f->{total_ms} = $f->{total};
    }
    foreach my $id (keys %athletes) {
	$athletes{$id}{name} = $class->athlete($id)->{athlete_name};
    }

    $class->add_calculated( $cr, \@finished );
    
    my @results_table = sort {
	$a->{fault} <=> $b->{fault}                 # Faults to the bottom
	|| $b->{event_laps} <=> $a->{event_laps}    # Then most laps first (DNF)
	|| $a->{total} <=> $b->{total} } @finished; # Then time at that lap
    
    for( my $i = 0; $i < @results_table; $i ++ ) {
	$results_table[$i]{place} = $i + 1;
	$results_table[$i]{fastest_ms} = $results_table[$i]{fastest}; # save
	$results_table[$i]{fastest} = ms_format($results_table[$i]{fastest});
	
	$results_table[$i]{total_ms} = $results_table[$i]{total}; # save
	$results_table[$i]{total} = ms_format($results_table[$i]{total});
    }

    if(wantarray) {
	return (\@results_table, \@marks);
    } else {
	return \@results_table;
    }
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
