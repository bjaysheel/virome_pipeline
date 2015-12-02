#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
=head1 NAME

createViewsSQL.pl - Creates DDL statements for creating chado table views

=head1 SYNOPSIS

USAGE:  createViewsSQL.pl [--analysis_id] [--algorithm] --database --database_type [-d debug_level] [--feature_id] [--for_workflow] [-h] [--is_obsolete] [--logfile] [-m] [--organism_id] [--outdir] --password --server --username

=head1 OPTIONS

=over 8

=item B<--analysis_id>
    
Optional - The analysis.analysis_id to which all the analysis is linked to

=item B<--algorithm>
    
Optional - The analysis.algorithm to which all the analysis is linked to

=item B<--database>
    
Relational database

=item B<--database_type>
    
Relational database management system type e.g. sybase or postgresql

=item B<--debug_level,-d>
    
Optional - Coati::Logger log4perl logging level (default is 0)

=item B<--feature_id>
    
Optional - The feature.feature_id to which all the data is linked to

=item B<--for_workflow>
    
Optional - Will create a modified select.sql.list file that will be compatible with database manipulating workflows

=item B<--help,-h>

Print this help

=item B<--is_obsolete>
    
Optional - The all data where the feature.is_obsolete=1

=item B<--logfile,-l>
    
Optional - Log4perl log file.  (default is /tmp/createViewsSQL.pl.log)

=item B<--man,-m>

Display pod2usage man page for this utility

=item B<--organism_id>
    
Optional - The organism.organism_id to which all the data is linked to

=item B<--outdir>
    
Optional - Output directory were the selectcount.sql files will be written (default is current working directory)

=item B<--password>
    
Password to log onto the database

=item B<--server>
    
Server on which the database resides

=item B<--username>
    
Username to log onto the database

=back

=head1 DESCRIPTION

    createViewsSQL.pl - Creates DDL statements for creating chado table views
    e.g.
    1) ./createViewsSQL.pl --analysis_id=1 --database=chado_test --database_type=sybase --server=SYBIL 

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

my ($analysis_id, $algorithm, $database, $database_type, $debug_level, $feature_id, $for_workflow, $help, $is_obsolete, $logfile, $man, $organism_id, $outdir, $password, $server, $username);

my $results = GetOptions (
			  'analysis_id=s'   => \$analysis_id,
			  'algorithm=s'     => \$algorithm,
			  'database=s'      => \$database,
			  'database_type=s' => \$database_type,
			  'debug_level=s'   => \$debug_level,
			  'feature_id=s'    => \$feature_id,
			  'for_workflow=s'  => \$for_workflow,
			  'help|h'          => \$help,
			  'is_obsolete=s'   => \$is_obsolete, 
			  'logfile=s'       => \$logfile,
			  'man|m'           => \$man, 
			  'organism_id=s'   => \$organism_id, 
			  'outdir=s'        => \$outdir, 
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
    $logfile = '/tmp/createViewsSQL.pl.log';
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

## Verify and set the output directory
$outdir = &verifyAndSetOutdir($outdir);

my $createdir = $outdir . '/create_views';
my $dropdir = $outdir . '/drop_views';

&createDirectory($createdir);
&createDirectory($dropdir);

if (defined($analysis_id)){
    if ($analysis_id !~ /^\d+$/){
	$logger->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    
    if (! $prism->analysisIdExists($analysis_id)){
	$logger->logdie("analysis_id '$analysis_id' does not exist in table 'analysis', database '$database' on server '$server'");
    }

    $prism->createFilteringViewsSQLForAnalysisId($analysis_id, $createdir, $for_workflow);
    $prism->createDropFilteringViewsSQL($dropdir, $for_workflow);
}
elsif (defined($algorithm)){
    
    if (! $prism->algorithmExists($algorithm)){
	$logger->logdie("No analysis record with algorithm '$algorithm' exists in table 'analysis', database '$database' on server '$server'");
    }
    
    $prism->createFilteringViewsSQLForAlgorithm($algorithm, $createdir, $for_workflow);
    $prism->createDropFilteringViewsSQL($dropdir, $for_workflow);
}
elsif (defined($feature_id)){
    if ($feature_id !~ /^\d+$/){
	$logger->logdie("feature_id '$feature_id' is not a numeric value");
    }
    
    if (! $prism->featureIdExists($feature_id)){
	$logger->logdie("feature_id '$feature_id' does not exist in table 'feature', database '$database' on server '$server'");
    }
    
    $prism->createFilteringViewsSQLForFeatureId($feature_id, $createdir, $for_workflow);
    $prism->createDropFilteringViewsSQL($dropdir, $for_workflow);
}
elsif (defined($is_obsolete)){

    if (! $prism->obsoleteFeaturesExist()){
	$logger->logdie("There aren't any features with is_obsolete = 1 in database '$database' on server '$server'");
    }
    
    $prism->createFilteringViewsSQLForFeatureIsObsolete($createdir, $for_workflow);
    $prism->createDropFilteringViewsSQL($dropdir, $for_workflow);
}
elsif (defined($organism_id)){
    if ($organism_id !~ /^\d+$/){
	$logger->logdie("organism_id '$organism_id' is not a numeric value");
    }
    
    if (! $prism->organismIdExists($organism_id)){
	$logger->logdie("organism_id '$organism_id' does not exist in table 'organism', database '$database' on server '$server'");
    }
    
    $prism->createFilteringViewsSQLForOrganismId($organism_id, $createdir, $for_workflow);
    $prism->createDropFilteringViewsSQL($dropdir, $for_workflow);
}
else {
    $logger->logdie("What did you want me to do?");
}

$prism->createTableListFile($outdir, $for_workflow);
$prism->createChadoMartTableListFile($outdir, $for_workflow);

print "SQL files were written to directory '$outdir'\n";
print "$0 program execution complete\n";
print "Log file is '$logfile'\n";
exit(0);


#---------------------------------------------------------------------------------------
#
#            END MAIN -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------

#--------------------------------------------------------
# verifyAndSetOutdir()
#
#--------------------------------------------------------
sub verifyAndSetOutdir {

    my ( $outdir) = @_;

    ## strip trailing forward slashes
    $outdir =~ s/\/+$//;
    
    # set to current directory if not defined
    if (!defined($outdir)){
	if (!defined($ENV{'OUTPUT_DIR'})){
	    $outdir = "." 
	}
	else{
	    $outdir = $ENV{'OUTPUT_DIR'};
	}
    }

    $outdir .= '/';

    ## verify whether outdir is in fact a directory
    if (!-d $outdir){
	$logger->logdie("$outdir is not a directory");
    }

    ## verify whether outdir has write permissions
    if ((-e $outdir) and (!-w $outdir)){
	$logger->logdie("$outdir does not have write permissions");
    }

    ## store the outdir in the environment variable
    $ENV{OUTPUT_DIR} = $outdir;
    
    return $outdir;

}#end sub verifyAndSetOutdir()


#--------------------------------------------------------------------
# printUsage()
#
#--------------------------------------------------------------------
sub printUsage {

    print STDERR "SAMPLE USAGE:  $0 [--analysis_id] [--algorithm] --database --database_type [-d debug_level] [--feature_id] [--for_workflow] [-h] [--is_obsolete] [--logfile] [-m] [--organism_id] [--outdir] --password --server --username\n".
    "  --analysis_id    = Optional - analysis.analysis_id to which all the analysis is linked to\n".
    "  --algorithm      = Optional - analysis.algorithm to which all the analysis is linked to\n".
    "  --database       = Relational database\n".
    "  --database_type  = Relational database management system i.e. sybase or postgresql (necessary to determine the field/record separators)\n".
    "  -d|--debug_level = Optional - Coati::Logger log4perl logging level (default is 0)\n".
    "  --feature_id     = Optional - feature.feature_id to which all the data is linked to\n".
    "  --for_workflow   = Optional - Will create a modified select.sql.list file that will be compatible with database manipulating workflows\n".
    "  -h|--help        = Optional - This help message\n".
    "  --is_obsolete    = Optional - all data that is link to features with is_obsolete=1\n".
    "  --logfile        = Optional - log4perl log file (default is /tmp/createViewsSQL.pl.log)\n".
    "  -m|--man         = Optional - Display the pod2usage man page for this utility\n".
    "  --organism_id    = Optional - organism.organism_id to which all the data is linked to\n".
    "  --outdir         = Optional - directory to which the select.sql files should be written (default is current working directory)\n".
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
# createDirectory()
#
#--------------------------------------------------
sub createDirectory {
    my $dir = shift;
    if (!-e $dir){
	mkdir($dir)  || $logger->logdie("Could not create directory '$dir'");
    }
}


