use strict;
use warnings;

package Laptimer::Util;

use Exporter;
use base qw(Exporter);
our @EXPORT_OK = qw(ms_format);
our %EXPORT_TAGS = (
    all => [qw(ms_format)]
    );
use POSIX qw(ceil floor);

sub ms_format {
    my $ms = shift || 0;
    my $ms_places = shift || 3;
    my $prefix = shift || "";
    
    if( $ms < 0 ) {
	$prefix = '-';
	$ms = abs($ms);
    }

    my $p_ms = $ms % 1000; # milliseconds
    my $p_seconds = floor( $ms / 1000 ); # Whole seconds
    my $p_minutes = floor( $p_seconds / 60 ); # Whole minutes
    $p_seconds = $p_seconds % 60; # remove minutes

    # Truncate milliseconds
    if( $ms_places == 2 ) {
	$p_ms = floor( $p_ms / 10 );
    } elsif( $ms_places == 1 ) {
	$p_ms = floor( $p_ms / 100 );
    }
    
    return sprintf('%s%1d:%02d.%0'.$ms_places.'d',$prefix,$p_minutes,$p_seconds,$p_ms);
}

1;
