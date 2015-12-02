#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

generateChadoReportPages.pl - Program that retrieves data from chado database and writes output files

=head1 SYNOPSIS

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username (default is access).

=item B<--password,-P>
    
    Database password (default is access).

=item B<--database,-D>
    
    Target chado database.

=item B<--database_type>
    
    Relational database management system type (default is Sybase).

=item B<--server>
    
    The name of the server on which the chado database resides (default is SYBPROD).

=item B<--man,-m>

    Display the pod2usage page for this utility.

=item B<--reportfile>

    The main output file.

=item B<--model_list_file>

    File containing a new-line separated list of model feat_name values (optional).

=item B<--logfile>

    The Log4perl log file (default is /tmp/generateChadoReportPages.pl.log).

=item B<--help,-h>

    Print this help


=back

=head1 DESCRIPTION

    Assumptions:

    1. User has appropriate permissions (to execute script, access chado database, write to output directory).
    2. Target chado database already contains all data.
    3. Target chado database contains the necessary controlled vocabulary terms.
    4. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    perl generateChadoReportPages.pl --database phytax --reportfile /usr/local/scratch/sundaram/report.txt --model_list_file /usr/local/annotation/PHYTAX/model_list.txt


=cut

use strict;
use File::Basename;
use File::Path;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Reports::Summarizer;
use Coati::Logger;

use constant DEFAULT_USERNAME => 'access';
use constant DEFAULT_PASSWORD => 'access';
use constant DEFAULT_SERVER => 'SYBPROD';
use constant DEFAULT_VENDOR => 'Sybase';

$|=1; ## do not buffer output stream

## Parse command line options
my ($username, $password, $outfile, $database, $debug_level, $help,
    $logfile, $man, $reportfile, $server, $model_list_file, $database_type);

my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'reportfile=s'        => \$reportfile,
			  'model_list_file=s'   => \$model_list_file,
			  'database|D=s'        => \$database,
			  'database_type=s'     => \$database_type,
			  'logfile|l=s'         => \$logfile,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  );

&checkCommandLineArguments();

my $logger = &getLogger();

my $summarizer = new Reports::Summarizer(username => $username,
					 password => $password,
					 database => $database,
					 database_type => $database_type,
					 server   => $server,
					 outfile         =>$reportfile,
					 model_list_file => $model_list_file);

if (!defined($summarizer)){
    die "Could not instantiate Reports::Summarizer";
}

$summarizer->generateReport();

my $outfile = $summarizer->getOutfile();
if (!defined($outfile)){
    die "outfile was not defined";
}

print "$0 execution completed\n";
print "The report file '$reportfile'\n";
exit(0);

##-------------------------------------------------------------------
##
##      END OF MAIN  -- SUBROUTINES FOLLOW
##
##-------------------------------------------------------------------

sub checkCommandLineArguments {

    
    if ($man){
	&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
    }
    
    if ($help){
	&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
    }


    my $fatalCtr=0;
    
    if (!defined($database)){
	print STDERR "--database was not specified\n";
	$fatalCtr++;
    }

    if ($fatalCtr> 0 ){
	die "Required command-line arguments were not specified\n";
    }


    if (!defined($username)){
	$username = DEFAULT_USERNAME;
	print STDERR "--username was not specified and ".
	"therefore was set to '$username'\n";
    }

    if (!defined($password)){
	$password = DEFAULT_PASSWORD;
	print STDERR "--password was not specified and ".
	"therefore was set to '$password'\n";
    }

    if (!defined($server)){
	$server = DEFAULT_SERVER;
	print STDERR "--server was not specified and ".
	"therefore was set to '$server'\n";
    }

    if (!defined($database_type)){
	$database_type = DEFAULT_VENDOR;
	print STDERR "--database_type was not specified and ".
	"therefore was set to '$database_type'\n";
    }

    if (!defined($reportfile)){
	$reportfile = '/tmp/' . File::Basename::basename($0) . '.rpt.txt';
	print STDERR "--reportfile was not specified and ".
	"therefore was set to '$reportfile'\n";
    }

    if (!defined($logfile)){
	$logfile = '/tmp/' . File::Basename::basename($0) . '.log';
	print STDERR "--logfile was not specified and ".
	"therefore was set to '$logfile'\n";
    }
}

sub getLogger {

    
    my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				     'LOG_LEVEL'=>$debug_level);
    
    if (!defined($mylogger)){
	die "mylogger was not defined";
    }


    my $logger = Coati::Logger::get_logger(__PACKAGE__);

    if (!defined($logger)){
	die "logger was not defined";
    }


    return $logger;
}
