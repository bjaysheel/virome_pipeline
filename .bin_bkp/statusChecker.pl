#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

statusChecker.pl - Check the disk usage and user quota for scratch volume

=head1 SYNOPSIS

USAGE:  

=head1 OPTIONS

=over 8

=item B<--append>
    
    Append the status report to the output file if set to 1.

=item B<--dir>
    
    The directory that should be checked.

=item B<--noexec>
    
    Do not execute this program if set to 1.

=item B<--outfile>
    
    Output file to which the status report should be written to.

=item B<--project_path>
    
    Path to the annotation directory e.g.: /usr/local/annotation/PHYTAX/.

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--help,-h>

    Print this help

=back

=head1 DESCRIPTION

   Add some description here.

=head1 AUTHOR

   Jay Sundaram
   sundaram@jcvi.org

=cut

use strict;
use Carp;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use System::StatusChecker;

use constant DEFAULT_SCRATCH => '/usr/local/scratch/';
use constant DEFAULT_APPEND => 1;

$|=1; ## do not buffer output stream

## Parse command line options
my ($dir, $noexec, $outfile, $help, $man, $append, $project_path, $scratch);

my $results = GetOptions (
			  'scratch=s'  => \$scratch, 
			  'dir=s'     => \$dir,
			  'noexec=s'  => \$noexec,
			  'outfile=s' => \$outfile,
			  'append=s'  => \$append,
			  'help|h'    => \$help,
			  'man|m'     => \$man,
			  'project_path=s' => \$project_path
			  );

if (!$noexec){

    &checkCommandLineArguments();

    my $checker = new Annotation::System::StatusChecker(outfile      => $outfile,
							append       => $append,
							project_path => $project_path,
							scratch      => $scratch,
							dir          => $dir);
    if (!defined($checker)){
	die "Could not instantiate Annotation::System::StatusChecker";
    }

    $checker->check();

    print "The output file is '$outfile'\n";

} else {
    print "--noexec=$noexec\n";
}

print "$0 execution completed\n";
exit(0);

##----------------------------------------------------------------
##
##         END OF MAIN -- SUBROUTINES FOLLOW
##
##----------------------------------------------------------------

sub checkCommandLineArguments {

    
    if ($man){
	&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
    }
    
    if ($help){
	&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
    }

    my $fatalCtr=0;
    
    if (!defined($project_path)){
	$fatalCtr++;
	print STDERR "--project_path was not defined\n";
    }

    if (!defined($dir)){
	print STDERR "--dir was not defined\n";
	$fatalCtr++;
    }

    if ($fatalCtr > 0 ){
	die "Required command-line argument was not specified";
    }

    &checkDirectory($project_path);   

    ## Check and set default values


    &checkDirectory($dir);

    if (!defined($append)){
	$append = DEFAULT_APPEND;
	print STDERR "--append was not specified and ".
	"therefore was set to '$append'\n";
    }

    if (!defined($scratch)){
	$scratch = DEFAULT_SCRATCH;
	print STDERR "--scratch was not specified and ".
	"therefore was set to '$scratch'\n";
    }

    if (!defined($outfile)){
	$outfile = '/tmp/' . File::Basename::basename($0) . '.txt';
	print STDERR "--outfile was not specified and ".
	"therefore was set to '$outfile'\n";
    }

}

sub checkDirectory {

    my ($dir) = @_;

    if (!-e $dir){
	confess "directory '$dir' does not exist";
    }

    if (!-d $dir){
	confess "'$dir' is not a directory";
    }

    if (!-r $dir){
	confess "directory '$dir' does not have read permissions";
    }
}
