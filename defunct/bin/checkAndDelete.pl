#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
=head1 NAME

checkAndDelete.pl - Parses the BCP files and created delete statements based on the primary key values

=head1 SYNOPSIS

USAGE:  checkAndDelete.pl [--analysis_id] [--algorithm] --database --database_type [-d debug_level] [--feature_id] [-h] [--is_obsolete] [--logfile] [-m] [--organism_id] --password --server --username

=head1 OPTIONS

=over 8

=item B<--analysis_id>
    
Optional - The analysis.analysis_id to which all the data is linked

=item B<--algorithm>
    
Optional - The analysis.algorithm to which all the data is linked

=item B<--database>
    
Relational database

=item B<--database_type>
    
Relational database management system type e.g. sybase or postgresql

=item B<--debug_level,-d>
    
Optional - Coati::Logger log4perl logging level (default is 0)

=item B<--feature_id>
    
Optional - The feature.feature_id to which all the data is linked

=item B<--help,-h>

Print this help

=item B<--is_obsolete>
    
Optional - The all data where the feature.is_obsolete=1

=item B<--logfile,-l>
    
Optional - Log4perl log file.  (default is /tmp/checkAndDelete.pl.log)

=item B<--man,-m>

Display pod2usage man page for this utility

=item B<--organism_id>
    
Optional - The organism.organism_id to which all the data is linked

=item B<--password>
    
Password to log onto the database

=item B<--server>
    
Server on which the database resides

=item B<--username>
    
Username to log onto the database

=back

=head1 DESCRIPTION

    checkAndDelete.pl - Converts BCP files from one vendor supported type to another
    e.g.
    1) ./checkAndDelete.pl --analysis_id=1 --database=chado_test --database_type=sybase --server=SYBIL 

=head1 CONTACT
                                                                                                                                                             
    Jay Sundaram
    sundaram@tigr.org

=cut

use Prism;
use Pod::Usage;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Coati::Logger;


## Don't buffer
$|=1;

my ($analysis_id, $algorithm, $database, $database_type, $debug_level, $feature_id, $help, $is_obsolete, $logfile, $man, $organism_id, $password, $server, $username);

my $results = GetOptions (
			  'analysis_id=s'   => \$analysis_id,
			  'algorithm=s'     => \$algorithm,
			  'database=s'      => \$database,
			  'database_type=s' => \$database_type,
			  'debug_level=s'   => \$debug_level,
			  'feature_id=s'    => \$feature_id,
			  'help|h'          => \$help,
			  'is_obsolete=s'   => \$is_obsolete, 
			  'logfile=s'       => \$logfile,
			  'man|m'           => \$man, 
			  'organism_id=s'   => \$organism_id, 
			  'password=s'      => \$password,
			  'server=s'        => \$server,
			  'username=s'      => \$username
			  );

if ($man){
    &pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
}
if ($help){
    &pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
}

my $fatalCtr=0;

if (!$database){
    print STDERR ("database not specified\n");
    $fatalCtr++;
}
if (!$database_type){
    print STDERR ("database_type not specified\n");
    $fatalCtr++;
}
if (!$password){
    print STDERR ("password not specified\n");
    $fatalCtr++;
}
if (!$server){
    print STDERR ("server not specified\n");
    $fatalCtr++;
}
if (!$username){
    print STDERR ("username not specified\n");
    $fatalCtr++;
}

if ($fatalCtr > 0 ){
    &printUsage();
}

## Initialize the logger
if (!defined($logfile)){
    $logfile = '/tmp/checkAndDelete.pl.log';
    print STDERR "logfile was set to '$logfile'\n";
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


my $criticalParamCtr=0;
if (defined($analysis_id)){
    $criticalParamCtr++;
}
if (defined($algorithm)){
    $criticalParamCtr++;
}
if (defined($feature_id)){
    $criticalParamCtr++;
}
if (defined($is_obsolete)){
    $criticalParamCtr++;
}
if (defined($organism_id)){
    $criticalParamCtr++;
}

if ($criticalParamCtr == 0 ){
    $logger->logdie("One of the following options must be specified: --analysis_id, --algorithm, --feature_id, --is_obsolete, or --organism_id");
}
if ($criticalParamCtr > 1){
    $logger->fatal("Only one of the following command-line arguments must be specified --analysis_id, --algorithm, --feature_id, --is_obsolete, or --organism_id");
    &printUsage()
}

if (! Prism::verifyDatabaseType($database_type)){
    $logger->logdie("This database_type '$database_type is not supported by Prism");
}

## Set the PRISM env var
&setPrismEnv($server, $database_type);

## Instantiate Prism object
my $prism = new Prism(user => $username, 
		      password => $password, 
		      db => $database );

if (!defined($prism)){
    $logger->logdie("prism was not defined");
}

if (defined($analysis_id)){
    &checkAnalysisId($analysis_id, $prism);
}
elsif (defined($algorithm)){
    &checkAlgorithm($algorithm, $prism);
}
elsif (defined($feature_id)){
    if (! $prism->featureIdExists($feature_id)){
	$logger->logdie("feature_id '$feature_id' does not exist in table 'feature', database '$database' on server '$server'");
    }
}
elsif (defined($is_obsolete)){
    if (! $prism->obsoleteFeaturesExist($is_obsolete)){
	$logger->logdie("There aren't any features with is_obsolete=1 in database '$database' on server '$server'");
    }
}
elsif (defined($organism_id)){
    &checkOrganismId($organism_id, $prism);
}
else {
    $logger->logdie("You're kidding right? Did you expect me to do something?");
}

print "$0 program execution complete\n";
print "Log file is '$logfile'\n";
exit(0);


#---------------------------------------------------------------------------------------
#
#            END MAIN -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------

#--------------------------------------------------------------------
# printUsage()
#
#--------------------------------------------------------------------
sub printUsage {

    print STDERR "SAMPLE USAGE:  $0 --analysis_id --database --database_type [-d debug_level] [-h] [--is_obsolete] [--logfile] [-m] [--organism_id] --password --server --username\n".
    "  --analysis_id    = analysis.analysis_id to which all the analysis is linked to\n".
    "  --algorithm      = analysis.algorithm to which all the analysis is linked to\n".
    "  --database       = Relational database\n".
    "  --database_type  = Relational database management system i.e. sybase or postgresql (necessary to determine the field/record separators)\n".
    "  -d|--debug_level = Optional - Coati::Logger log4perl logging level (default is 0)\n".
    "  --feature_id     = feature.feature_id to which all the analysis is linked to\n".
    "  -h|--help        = Optional - This help message\n".
    "  --is_obsolete    = all data related to feature records with is_obsolete=1\n".
    "  --logfile        = Optional - log4perl log file (default is /tmp/checkAndDelete.pl.log)\n".
    "  -m|--man         = Optional - Display the pod2usage man page for this utility\n".
    "  --organism_id    = organism.organism_id to which all the data are linked\n".
    "  --password       = Password to log onto the database\n".
    "  --server         = The server on which the database resides\n".
    "  --username       = Username to log onto the database\n";
    exit(1);
}

#--------------------------------------------------
# setPrismEnv()
#
#--------------------------------------------------
sub setPrismEnv {

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


    $ENV{PRISM} = $prismenv;
}

#--------------------------------------------------
# checkAnalysisId()
#
#--------------------------------------------------
sub checkAnalysisId {

    my ($analysis_id, $prism) = @_;

    if ($analysis_id !~ /^\d+$/){
	$logger->logdie("analysis_id '$analysis_id' is not a numeric value");
    }

    if (! $prism->analysisIdExists($analysis_id)){
	$logger->logdie("analysis_id '$analysis_id' does not exist in table 'analysis', database '$database' on server '$server'");
    }
    
    my $analysisfeatureCount = $prism->analysisfeatureRecordCountByAnalysisId($analysis_id);
    
    if ($analysisfeatureCount < 1 ){
	
	$logger->warn("There are no analysisfeature records with analysis_id '$analysis_id' in database '$database' on server '$server'");
	
	my $analysispropCount = $prism->analysispropRecordCountByAnalysisId($analysis_id);
	
	if ($analysispropCount > 0 ){
	    $logger->warn("Going to delete all analysisprop records with analysis_id '$analysis_id' and then abort execution");
	    ## Delete the analysisprop records
	    $prism->deleteAnalysispropByAnalysisId($analysis_id);
	}
	else {
	    $logger->warn("Did not find any analysisprop records with analysis_id '$analysis_id' in database '$database' on server '$server'");
	}
	
	$prism->deleteAnalysisByAnalysisId($analysis_id);
	$logger->logdie("analysis and analysisprop records with analysis_id '$analysis_id' have been deleted. ".
		    "Since there are no analysisfeature records with analysis_id '$analysis_id', there is ".
		    "no reason for the remaining steps in the workflow to be executed");
    }
}

#--------------------------------------------------
# checkAlgorithm()
#
#--------------------------------------------------
sub checkAlgorithm {

    my ($algorithm, $prism) = @_;

    if (! $prism->algorithmExists($algorithm)){
	$logger->logdie("algorithm '$algorithm' does not exist in table 'analysis', database '$database' on server '$server'");
    }
    
    my $analysisfeatureCount = $prism->analysisfeatureRecordCountByAlgorithm($algorithm);
    
    if ($analysisfeatureCount < 1 ){
	
	$logger->warn("There are no analysisfeature records linked to analysis records with algorithm '$algorithm' in database '$database' on server '$server'");
	
	my $analysispropCount = $prism->analysispropRecordCountByAlgorithm($algorithm);
	
	if ($analysispropCount > 0 ){
	    $logger->warn("Going to delete all analysisprop records linked to analysis records with algorithm '$algorithm' and then abort execution");
	    ## Delete the analysisprop records
	    $prism->deleteAnalysispropByAlgorithm($algorithm);
	}
	else {
	    $logger->warn("Did not find any analysisprop records linked to analysis records with algorithm '$algorithm' in database '$database' on server '$server'");
	}
	
	$prism->deleteAnalysisByAlgorithm($algorithm);
	$logger->logdie("analysis records with algorithm '$algorithm' and analysisprop records linked to those analysis records have been deleted. ".
		    "Since there are no analysisfeature records linked to those analysis records, there is ".
		    "no reason for the remaining steps in the workflow to be executed");
    }
}

#--------------------------------------------------
# checkOrganismId()
#
#--------------------------------------------------
sub checkOrganismId {

    my ($organism_id, $prism) = @_;

    if ($organism_id !~ /^\d+$/){
	$logger->logdie("organism_id '$organism_id' is not a numeric value");
    }
    
    if (! $prism->organismExists($organism_id)){
	$logger->logdie("organism_id '$organism_id' does not exist in table 'organism', database '$database' on server '$server'");
    }

    my $featureCount = $prism->featureRecordCountByOrganismId($organism_id);
    
    my $execwf=1;

    if ($featureCount < 1 ){

	$execwf=0;

	$logger->warn("There are no feature records linked to organism records with organism_id '$organism_id' in database '$database' on server '$server'");
    
	my $organismpropCount = $prism->organismpropRecordCountByOrganismId($organism_id);
	
	if ($organismpropCount > 0 ){
	    $logger->warn("Going to delete all '$organismpropCount' organismprop records linked to the organism record with organism_id '$organism_id' and then abort execution");
	    ## Delete the organismprop records
	    $prism->deleteOrganismpropByOrganismId($organism_id);
	    $logger->warn("$0 deleted all organismprop records with organism_id '$organism_id'");
	}
	else {
	    $logger->warn("Did not find any organismprop records linked to organism record with organism_id '$organism_id' in database '$database' on server '$server'");
	}


	my $organismDbxrefCount = $prism->organismDbxrefRecordCountByOrganismId($organism_id);
	
	if ($organismDbxrefCount > 0 ){
	    $logger->warn("Going to delete all '$organismDbxrefCount' organism_dbxref records linked to the organism record with organism_id '$organism_id' and then abort execution");
	    ## Delete the organism_dbxref records
	    $prism->deleteOrganismDbxrefByOrganismId($organism_id);
	    $logger->warn("$0 deleted all organism_dbxref records with organism_id '$organism_id'");
	}
	else {
	    $logger->warn("Did not find any organism_dbxref records linked to organism record with organism_id '$organism_id' in database '$database' on server '$server'");
	}
	
	$prism->deleteOrganismByOrganismIdm($organism_id);
	$logger->logdie("Since there are no feature records with organism_id '$organism_id', there is ".
			"no reason for the remaining steps in the workflow to be executed");
    }
}

