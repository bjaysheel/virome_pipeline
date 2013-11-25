#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

checkForDuplicatePropertyTuples.pl - Check for duplicate tuples in the property tables (analysisprop, dbxrefprop, feature_cvtermprop, featureprop, feature_relationshipprop, organismprop, phylonodeprop, pubprop)

=head1 SYNOPSIS

USAGE:  checkForDuplicatePropertyTuples.pl --database --database_type [--debug_level] [-h] [--logfile] [-m] --password --server --table --username

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

=item B<--table>

Name of the property table that should be checked for duplicate tuples

=item B<--username>

Database username

=back

=head1 DESCRIPTION

checkForDuplicatePropertyTuples.pl - Check for duplicate tuples in the property tables (dbxrefprop, organismprop, featureprop, feature_cvtermprop)

 Assumptions:
1. Data is loaded in the tables.
2. User has appropriate permissions (to execute script, access chado database, write to output directory).
3. All software has been properly installed, all required libraries are accessible.

Sample usage:

perl checkForDuplicatePropertyTuples.pl --username=sundaram --password=sundaram7 --database=chado_test --server=SYBIL --database_type=sybase --table=featureprop

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
    $server, $table, $username);

my $results = GetOptions (
			  'database=s'        => \$database,
			  'database_type=s'   => \$database_type,
			  'debug_level=s'     => \$debug_level, 
			  'help|h'            => \$help,
			  'logfile=s'         => \$logfile,
			  'man|m'             => \$man,
			  'password=s'        => \$password,			  
			  'server=s'          => \$server,
			  'table=s'           => \$table,
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
if (!defined($table)){
    print STDERR ("table was not defined\n");
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

my $duplicateCtr=0;

if ($table eq 'analysisprop'){
    my $analysispropCount = $prism->analysispropDuplicateRecordCount();
    if ($analysispropCount > 0 ){
	$duplicateCtr += $analysispropCount;
	$logger->error("Detected '$analysispropCount' duplicate analysisprop records");
    }
}
elsif ($table eq 'dbxrefprop'){
    my $dbxrefpropCount = $prism->dbxrefpropDuplicateRecordCount();
    if ($dbxrefpropCount > 0 ){
	$duplicateCtr += $dbxrefpropCount;
	$logger->error("Detected '$dbxrefpropCount' duplicate dbxrefprop records");
    }
}
elsif ($table eq 'feature_cvtermprop'){
    my $feature_cvtermpropCount = $prism->featureCvtermpropDuplicateRecordCount();
    if ($feature_cvtermpropCount > 0 ){
	$duplicateCtr += $feature_cvtermpropCount;
	$logger->error("Detected '$feature_cvtermpropCount' duplicate feature_cvtermprop records");
    }
}
elsif ($table eq 'featureprop'){
    my $featurepropCount = $prism->featurepropDuplicateRecordCount();
    if ($featurepropCount > 0 ){
	$duplicateCtr += $featurepropCount;
	$logger->error("Detected '$featurepropCount' duplicate featureprop records");
    }
}
elsif ($table eq 'feature_relationshipprop'){
    my $feature_relationshippropCount = $prism->featureRelationshippropDuplicateRecordCount();
    if ($feature_relationshippropCount > 0 ){
	$duplicateCtr += $feature_relationshippropCount;
	$logger->error("Detected '$feature_relationshippropCount' duplicate feature_relationshipprop records");
    }
}
elsif ($table eq 'organismprop'){
    my $organismpropCount = $prism->organismpropDuplicateRecordCount();
    if ($organismpropCount > 0 ){
	$duplicateCtr += $organismpropCount;
	$logger->error("Detected '$organismpropCount' duplicate organismprop records");
    }
}
elsif ($table eq 'phylonodeprop'){
    my $phylonodepropCount = $prism->phylonodepropDuplicateRecordCount();
    if ($phylonodepropCount > 0 ){
	$duplicateCtr += $phylonodepropCount;
	$logger->error("Detected '$phylonodepropCount' duplicate phylonodeprop records");
    }
}
elsif ($table eq 'pubprop'){
    my $pubpropCount = $prism->pubpropDuplicateRecordCount();
    if ($pubpropCount > 0 ){
	$duplicateCtr += $pubpropCcount;
	$logger->error("Detected '$pubpropCount' duplicate pubprop records");
    }
}
else {
    $logger->logdie("Table '$table' is not recognized!");
}


if ($duplicateCtr>0){
    if ($duplicateCtr == 1){
	$logger->logdie("Found 1 duplicate record.  Please review the logfile '$logfile' for details.");
    }
    else {
	$logger->logdie("Found '$duplicateCtr' duplicate records.  Please review the logfile '$logfile' for details.");
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

    print STDERR "SAMPLE USAGE:  $0 --database --database_typed [--debug_level] [-h] [--logfile] [-m] --password --server --table --username\n".
    "  --database                = Target chado database\n".
    "  --database_type           = Relational database management system type e.g. sybase or postgresql\n".
    "  --debug_level             = Optional - Coati::Logger Log4perl logging level.  Default is 0\n".
    "  -h|--help                 = Optional - Display pod2usage help screen\n".
    "  --logfile                 = Optional - Log4perl log file (default: /tmp/checkForDuplicatePropertyTuples.pl.log)\n".
    "  -m|--man                  = Optional - Display pod2usage pages for this utility\n".
    "  --password                = Password\n".
    "  --server                  = Name of the server on which the database resides\n".
    "  --table                   = table which should be checked\n".
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


