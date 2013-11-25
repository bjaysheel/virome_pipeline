#!/usr/local/bin/perl
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
