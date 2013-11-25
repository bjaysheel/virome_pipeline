#!/usr/local/bin/perl
use strict;
use Data::Dumper;
use Prism::Cluster::Analyzer;

my $server = 'SYBPROD';
my $database = 'phytax';
my $username = 'access';
my $password = 'access';
my $vendor = 'Sybase';

my $analysis_id = $ARGV[0];
if (!defined($analysis_id)){
    die "Usage: perl $0 analysis_id";
}

my $analyzer = new Prism::Cluster::Analyzer(username => $username,
					    password => $password,
					    server   => $server,
					    database => $database,
					    vendor   => $vendor);
if (!defined($analyzer)){
    die "Could not instantiate Prism::Cluster::Analyzer";
}

if ($analyzer->areDisjoint(analysis_id=>$analysis_id)){
    print "The clusters for analysis_id '$analysis_id' are disjoint ".
    "on database '$database' server '$server'\n";
} else {
    $analyzer->printNonDisjointReport();
}

my $outfile = $analyzer->getOutputFile();
if (!defined($outfile)){
    print Dumper $analyzer;
    die "Could not retrieve outfile";
} 


print "$0 execution completed\n";
print "The output file is '$outfile'\n";
exit(0);

##----------------------------------------------------
##
##         END OF MAIN -- SUBROUTINES FOLLOW
##
##----------------------------------------------------
