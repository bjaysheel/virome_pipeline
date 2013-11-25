#!/usr/local/bin/perl
use strict;
use Prism::DataMining::Clustering::Cluster::Mapper;

my $username = 'sundaram';
my $password = 'sundaram8';
my $database = 'phytax';
my $server   = 'SYBPROD';
my $vendor   = 'Sybase';
my $outfile = '/tmp/' . File::Basename::basename($0) . '.out';

my $mapper = new Prism::DataMining::Clustering::Cluster::Mapper(username => $username,
								password => $password,
								database => $database,
								server   => $server,
								vendor   => $vendor);
if (!defined($mapper)){
    die "Could not instantiate Prism::DataMining::Clustering::Cluster::Mapper";
}

$mapper->reportMapping(analysis_id1 => 2,
		       analysis_id2 => 3,
		       outfile      => $outfile);

print "$0 execution completed\n";
print "Output file is '$outfile'\n";
exit(0);


##-------------------------------------------------------
##
##        END OF MAIN -- SUBROUTINES FOLLOW
##
##-------------------------------------------------------
