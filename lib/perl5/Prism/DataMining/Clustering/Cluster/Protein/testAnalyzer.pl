#!/usr/local/bin/perl
use strict;
use Prism::DataMining::Clustering::Cluster::Protein::Analyzer;

$|=1;
my $username = 'sundaram';
my $password = 'sundaram8';
my $server   = 'SYBPROD';
my $database = 'phytax';
my $vendor   = 'Sybase';
my $analysis_id = 2;
my $outfile = '/tmp/stats.txt';
my $minCount = 5;

my $analyzer = new Prism::DataMining::Clustering::Cluster::Protein::Analyzer(username => $username,
									     password => $password,
									     server   => $server,
									     database => $database,
									     vendor   => $vendor,
									     min_count => $minCount);
if (!defined($analyzer)){
    die "Could not instantiate Prism::DataMining::Clustering::Cluster::Protein::Analyzer";
}

$analyzer->generateReport(analysis_id => $analysis_id,
			  outfile => $outfile);


print "$0 execution completed\n";
print "The output file is '$outfile'\n";
exit(0);

##----------------------------------------------------
##
##      END OF MAIN -- SUBROUTINES FOLLOW
##
##----------------------------------------------------
