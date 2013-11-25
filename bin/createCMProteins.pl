#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell


use strict;
use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Coati::Logger;

## Caching should be turned off
$ENV{DBCACHE} = undef;
$ENV{DBCACHE_DIR} = undef;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($username, $password, $database, $server, $debug_level, 
    $help, $logfile, $man, $outdir, $database_type, $iteratorlist);

my $results = GetOptions (
			  'username=s'        => \$username, 
			  'password=s'        => \$password,
			  'database=s'        => \$database,
			  'server=s'   	      => \$server,
			  'logfile|l=s'       => \$logfile,
			  'debug_level|d=s'   => \$debug_level, 
			  'help|h'            => \$help,
			  'man|m'             => \$man,
			  'outdir=s'          => \$outdir,
			  'database_type=s'   => \$database_type,
			  'iteratorlist=s'    => \$iteratorlist
			  );

&checkCommandLineArguments();

my $logger = &getLogger($logfile, $debug_level);

## Use class method to verify the database vendor type
if (! Prism::verifyDatabaseType($database_type)){
    $logger->logdie("Unsupported database type '$database_type'");
}

## Set the PRISM env var
&setPrismEnv($server, $database_type);

## verify and set the output directory
$outdir = &verify_and_set_outdir($outdir);

## Instantiate Prism object
my $prism = new Prism( user     => $username,
		       password => $password,
		       db       => $database
		       );

if (!defined($prism)){
    $logger->logdie("prism was not defined");
}

if (! $prism->existsGeneModels()){
    $logger->warn("No gene models available in database ".
		  "'$database' on server '$server' so $0 ".
		  "cannot generate any cm_protein records ".
		  "at this time");
} else {

    my $cmProteinRecords = $prism->retrieve_proteins();
    
    my $count = scalar(@{$cmProteinRecords});
    
    my $recctr = $prism->storeRecordsInCmProteins($cmProteinRecords);
    
    if ($recctr > 0 ){
	
	print "BCP files will be written to directory '$outdir'\n\n";
	
	$prism->{_backend}->output_tables($outdir);
	
	print "'$recctr' cm_proteins records have been written ".
	"to the cm_proteins BCP file\n";
	
	
	my $msg = "A BCP file containing records to be loaded ".
	"into cm_proteins has been generated.\nMake sure the ".
	"chado-mart table 'cm_proteins' in database '$database' ".
	"(on server '$server') either has no records or else ".
	"truncate the table before attempting to load the BCP ".
	"records.\n";
	
	$logger->warn("$msg");


	if ((defined($iteratorlist)) && ($iteratorlist == 1)){
	    $prism->createChadoMartTableListFile($outdir);
	} else {
	    print "Run flatFileToChado.pl to load the BCP files ".
	"in directory '$outdir' into the target database ".
	"'$database' (on server '$server')\n";
	}
    } else {
	$logger->warn("No records were created for cm_proteins");
    }
}
    

print "\n$0 execution has completed\n";
print "The log file is '$logfile'\n";
exit(0);


##------------------------------------------------------------------------------------------
##
##            END OF MAIN  -- SUBROUTINES FOLLOW
##
##------------------------------------------------------------------------------------------

sub checkCommandLineArguments {

    if ($man){
	&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
    }

    if ($help){
	&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
    }


    my $fatalCtr=0;

    if (!defined($username)){
	print STDERR "--username was not defined\n";
	$fatalCtr++;
    }
    
    if (!defined($password)){
	print STDERR "--password was not defined\n";
	$fatalCtr++;
    }

    if (!defined($database)){
	print STDERR "--database was not defined\n";
	$fatalCtr++;
    }

    if (!defined($server)){
	print STDERR "--server was not defined\n";
	$fatalCtr++;
    }
   
    if ($fatalCtr > 0 ){
	&print_usage();
    }

    if (!defined($database_type)){
	$database_type = 'sybase';
	print STDERR "--database_type was not specified ".
	"and therefore was set to '$database_type'\n";
    }

    if (!$logfile){
	$logfile = '/tmp/' . File::Basename::basename($0) . '.log';
	print STDERR "--logfile was not specified and ".
	"therefore was set to '$logfile'\n";
    }

}

sub getLogger {

    my ($logfile, $debug_level) = @_;
 
    my $mylogger = new Coati::Logger('LOG_FILE' => $logfile,
				     'LOG_LEVEL'=> $debug_level);
    
    if (!defined($mylogger)){
	die "mylogger was not defined";
    }

    my $logger = Coati::Logger::get_logger(__PACKAGE__);
    if (!defined($logger)){
	die "logger was not defined";
    }

    return $logger;
}


sub verify_and_set_outdir {

    my ( $outdir) = @_;

    if ($logger->is_debug()){
	$logger->debug("Verifying and setting output directory");
    }

    #
    # strip trailing forward slashes
    #
    $outdir =~ s/\/+$//;
    
    #
    # set to current directory if not defined
    #
    if (!defined($outdir)){
	if (!defined($ENV{'OUTPUT_DIR'})){
	    $outdir = "." 
	}
	else{
	    $outdir = $ENV{'OUTPUT_DIR'};
	}
    }

    $outdir .= '/';

    #
    # verify whether outdir is in fact a directory
    #
    $logger->logdie("$outdir is not a directory") if (!-d $outdir);

    #
    # verify whether outdir has write permissions
    #
    $logger->logdie("$outdir does not have write permissions") if ((-e $outdir) and (!-w $outdir));


    $logger->debug("outdir is set to:$outdir") if ($logger->is_debug());

    #
    # store the outdir in the environment variable
    #
    $ENV{OUTPUT_DIR} = $outdir;
    
    return $outdir;

}

sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 --database --database_type [--debug_level] [-h] [--logfile] [-m] [--outdir] --password --server --username\n".
    "  --database          = Name of chado database\n".
    "  --database_type     = RDBMS type e.g. sybase or postgresql\n".
    "  ---debug_level      = Optional - Coati::Logger log4perl logging level.  Default is 0\n".
    "  -h|--help           = Optional - Display pod2usage help screen\n".
    "  --logfile           = Optional - Log4perl log file (default: /tmp/chadoToChadoMart.pl.log)\n".
    "  -m|--man            = Optional - Display pod2usage pages for this utility\n".
    "  --outdir            = Optional - output directory for tab delimited BCP files (Default is current working directory)\n".
    "  --password          = Database account password\n".
    "  --program           = Optional - user can specify a comma-separated list of analysis.program values for cluster records\n".
    "  --server            = Name of server on which the database resides\n".
    "  --username          = Database account username\n";
    exit 1;

}

sub setPrismEnv {

    my ($server, $vendor) = @_;

    
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

