#!/usr/bin/perl

use strict;
use warnings;
use Crypt::SaltedHash;

my $csh = Crypt::SaltedHash->new(algorithm => 'SHA-1');
$csh->add($ARGV[0]);
 
my $salted = $csh->generate;
print "$salted\n";
