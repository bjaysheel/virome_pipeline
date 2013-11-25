#!/usr/local/bin/perl
##----------------------------------------------------------------
## Usage: perl testStatusChecker.pl
## 
## Jay Sundaram
## 2009-06-20
##
##----------------------------------------------------------------
use strict;
use Annotation::System::StatusChecker;

my $projectPath = '/usr/local/annotation/PHYTAX/';
my $outfile = '/tmp/statuschecker.txt';
my $append = 1;
my $dir = '/usr/local/scratch/';

my $checker = new Annotation::System::StatusChecker(outfile      => $outfile,
						    append       => $append,
						    project_path => $projectPath,
						    dir          => $dir);
if (!defined($checker)){
    die "Could not instantiate Annotation::System::StatusChecker";
}

$checker->check();


print "$0 execution completed\n";
print "The output file is '$outfile'\n";
exit(0);

##----------------------------------------------------------------
##
##         END OF MAIN -- SUBROUTINES FOLLOW
##
##----------------------------------------------------------------
