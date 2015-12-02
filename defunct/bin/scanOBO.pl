#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
use Data::Dumper;
 
my $file = $ARGV[0];
open (INFILE, "<$file") or die;

my @contents = <INFILE>;
chomp @contents;

my $hash = {};

foreach my $line (@contents){

    if ($line =~ /^(\S+):/){
	$hash->{$1}++;
    }
}

print Dumper $hash;
