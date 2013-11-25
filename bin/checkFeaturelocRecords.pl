#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

checkFeaturelocRecords.pl - Check fmin, fmax and strand values in the featureloc records

=head1 SYNOPSIS

USAGE:  checkFeaturelocRecords.pl --database --database_type [--debug_level] [-h] [--logfile] [-m] --password --server --username

=head1 OPTIONS

=over 8

=item B<--database,-D>

Target chado database 

=item B<--database_type>

Relational database management system type e.g. sybase or postgresql

=item B<--debug_level>

Optional - Coati::Logger Log4perl logging level.  Default is 0

=item B<--help,-h>

Print this help

=item B<--logfile>

Optional - Log4perl log filename

=item B<--man,-m>

Display the pod2usage page for this utility

=item B<--password>

Database password

=item B<--server>

Name of server on which the database resides

=item B<--username>

Database username

=back

=head1 DESCRIPTION

checkFeaturelocRecords.pl - Check fmin, fmax, and strand values in the featureloc records

 Assumptions:
1. Data is loaded in the tables.
2. User has appropriate permissions (to execute script, access chado database, write to output directory).
3. All software has been properly installed, all required libraries are accessible.

Sample usage:

perl checkFeaturelocRecords.pl --username=sundaram --password=sundaram7 --database=chado_test --server=SYBIL --database_type=sybase

=head1 CONTACT

Jay Sundaram
sundaram@jcvi.org

=cut


use strict;
use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Coati::Logger;
use File::Basename;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($database, $database_type, $debug_level, $help, $logfile, $man, $password,
    $server, $username);

my $results = GetOptions (
			  'database=s'        => \$database,
			  'database_type=s'   => \$database_type,
			  'debug_level=s'     => \$debug_level, 
			  'help|h'            => \$help,
			  'logfile=s'         => \$logfile,
			  'man|m'             => \$man,
			  'password=s'        => \$password,			  
			  'server=s'          => \$server,
			  'username=s'        => \$username 
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

my $fatalCtr=0;

if (!defined($database)){
    print STDERR ("database was not defined\n");
    $fatalCtr++;
}
if (!defined($database_type)){
    print STDERR ("database_type was not defined\n");
    $fatalCtr++;
}
if (!defined($password)){
    print STDERR ("password was not defined\n");
    $fatalCtr++;
}
if (!defined($server)){
    print STDERR ("server was not defined\n");
    $fatalCtr++;
}
if (!defined($username)){
    print STDERR ("username was not defined\n");
    $fatalCtr++;
}

if ($fatalCtr>0){
    &print_usage();
}


if (!defined($logfile)){
    
    my $programname = basename($0);

    $logfile = '/tmp/' . $programname . '.log';

    print "logfile was set to '$logfile'\n";
}


## Get the Log4perl logger

my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				 'LOG_LEVEL'=>$debug_level);


my $logger = Coati::Logger::get_logger(__PACKAGE__);

if (! Prism::verifyDatabaseType($database_type)){
    $logger->logdie("Unsupported database type '$database_type'");
}

## Set the PRISM environmenatal variable.
&set_prism_env($server, $database_type);

## Instantiate the Prism object so that can interact with the chado database.
my $prism = new Prism( user => $username, password => $password, db => $database );

if (!defined($prism)){
    $logger->logdie("prism was not defined");
}

my $errorCtr=0;

my $fminFmaxCount = $prism->featurelocFminGreaterThanFmaxCount();

if ($fminFmaxCount>0){
    $errorCtr += $fminFmaxCount;
    $logger->error("Found '$fminFmaxCount' featureloc records where the fmin>fmax");
}

my $badStrandCount = $prism->invalidFeaturelocStrandValueCount();

if ($badStrandCount>0){
    $errorCtr += $badStrandCount;
    $logger->error();
}

if ($errorCtr>0){
    if ($errorCtr == 1){
	$logger->logdie("Found 1 bad featureloc record.  Please review the logfile '$logfile' for details.");
    }
    else {
	$logger->logdie("Found '$errorCtr' bad featureloc records.  Please review the logfile '$logfile' for details.");
    }
}

print "$0 program execution completed\n";
print "The log file is '$logfile'\n";
exit(0);


#----------------------------------------------------------------------------------------------------------------
#
#                 END OF MAIN  -- SUBROUTINES FOLLOW
#
#----------------------------------------------------------------------------------------------------------------


=item print_usage()

B<Description:> Describes proper invocation of this program

B<Parameters:> None

B<Returns:> None

=cut

sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 --database --database_type [--debug_level] [-h] [--logfile] [-m] --password --server --username\n".
    "  --database                = Target chado database\n".
    "  --database_type           = Relational database management system type e.g. sybase or postgresql\n".
    "  --debug_level             = Optional - Coati::Logger Log4perl logging level.  Default is 0\n".
    "  -h|--help                 = Optional - Display pod2usage help screen\n".
    "  --logfile                 = Optional - Log4perl log file (default: /tmp/checkForDuplicatePropertyTuples.pl.log)\n".
    "  -m|--man                  = Optional - Display pod2usage pages for this utility\n".
    "  --password                = Password\n".
    "  --server                  = Name of the server on which the database resides\n".
    "  --username                = Username\n";
    exit(1);
}


=item set_prism_env()

B<Description:> Sets-up the PRISM environment variable

B<Parameters:> server (string), vendor (string)

B<Returns:> None

=cut

sub set_prism_env {

    my ($server, $vendor) = @_;

    if (!defined($server)){
	$logger->logdie("server was not defined");
    }
    if (!defined($vendor)){
	$logger->logdie("vendor was not defined");
    }

    if ($vendor eq 'postgresql'){
	$vendor = 'postgres';
    }

    $vendor = "Bulk" . ucfirst($vendor);
    ## We're overriding the env stored in conf/Prism.conf
    my $prismenv = "Chado:$vendor:$server";

    if ($logger->is_debug()){
	$logger->debug("PRISM was set to '$prismenv'");
    }

    $ENV{PRISM} = $prismenv;
}


