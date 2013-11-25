#!/usr/local/bin/perl
use strict;
use Sybase::Systables::Reporter;

$|=1; ## do not buffer output stream

my $username = 'sundaram';
my $password = 'sundaram7';
my $server = 'SYBPROD';
my $database = 'phytax';
my $outfile = '/tmp/sybase_reporter.txt';

my $reporter = new Sybase::Systables::Reporter(username=>$username,
					       password=>$password,
					       server  =>$server,
					       database=>$database,
					       outfile=>$outfile);

if (!defined($reporter)){
    die "Could not instantiate Sybase::Systables::Reporter";
}

$reporter->generateReport();

print "Here are the indexes for table 'feature'\n";
$reporter->printIndexesByTable('feature');

print "Here are the constraints for table 'feature'\n";
$reporter->printConstraintsByTable('feature');


print "$0 execution completed\n";
print "The output file is '$outfile'\n";
exit(0);

##----------------------------------------------------
##
##    END OF MAIN -- SUBROUTINES FOLLOW
##
##----------------------------------------------------
