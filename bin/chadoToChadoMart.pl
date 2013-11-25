#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

chadoToChadoMart.pl - Generate data to be loaded into the chado-mart materialized views

=head1 SYNOPSIS

USAGE:  chadoToChadoMart.pl [--cluster_analysis_id] [--blast_analysis_id] [--batch_size] [--cm_proteins] --database --database_type [--debug_level] [-h] [--iteratorlist] [--logfile] [-m] [--no-clusters] [--outdir] --password [--program] --server --username

=head1 OPTIONS

=over 8

=item B<--cluster_analysis_id>

Optional - User can specify the --cluster_analysis_id option to generate records for the chado-mart tables cm_clusters and cm_cluster_members for the particular cluster analysis 
           of interest.  This can be a comma-separated list.  The user is solely responsible for ensuring that the cm_clusters and 
           cm_cluster_members BCP records generated do not already exist in the target database's chado-mart tables.  Attempting to load the BCP records into the target 
           chado-mart tables could result in loading failures or else failure to restore table constraints.  
           If the --cluster_analysis_id option is not specified, then the --program option must be.
           This program will abort if neither --cm_proteins=1, --cluster_analysis_id nor --program options are specified.           

=item B<--blast_analysis_id>

Required - User can specify the --blast_analysis_id and the cluster alignments will be pulled from that analysis;
        
=item B<--batch_size>

Optional - Is used to control the number of clusters that are processed at a time.  In order to generate statistics for the cm_clusters table, the pairwise alignment 
           data for each cluster is retrieved from the core chado tables and cached in memory.  This data is then processed by the cluster statistics generating
           subroutines.  For some data sets, retrieving and caching all of the data for all of the clusters available would require a prohibitively large amount of 
           memory.   On the other hand, the smaller the batch size, the more calls to the database, the longer the execution time.  In light of this memory-speed
           trade-off, the user is given the ability strike a balance for themselves.  The default batch size is 60.

=item B<--cm_proteins>

Optional - User can specify the --cm_proteins=1 to generate records for chado-mart table cm_proteins.  Default behavior is to not generate records for the table.

=item B<--username>

Database username

=item B<--password>

Database password

=item B<--program>

Optional - The user can specify --program option.  This will result in the generation of cm_clusters and cm_cluster_members records for the analysis that with the particular
           program name. This can be a comma-separated list of programs for the target chado database.  The user is solely responsible for ensuring that the correct analysis 
           is processed.  Considering using the --cluster_analysis_id option instead.  
           This program will abort if neither --cm_proteins=1, --cluster_analysis_id nor --program options are specified.

=item B<--database>

Name of chado database 

=item B<--database_type>

Relational database management system type e.g. sybase or postgresql

=item B<--server>

Name of server on which the database resides

=item B<--debug_level,-d>

Optional - Coati::Logger log4perl logging level.  Default is 0
 
=item B<--man,-m>

Display the pod2usage page for this utility

=item B<--outdir>

Optional - Directory where tab-delimited BCP files will be written.  Default is current directory.

=item B<--help,-h>

Print this help

=item B<--iteratorlist>

Optional - creates a workflow iterator list.

=item B<--no-clusters>

Optional - If specified, the cm_clusters and cm_cluster_members records will not be generated.

=back

=head1 DESCRIPTION

chadoToChadoMart.pl - Generate data to be loaded into the chado-mart materialized views

This program does not support parallel processing.  In order to 
accomodate that feature, we would need to adopt the use of
checksum placeholder values.  In order to use checksum placeholder
values, we would need to identify unique sets of fields to compose 
the uniqueness constraints for each chado-mart table.

Also note that when we run this program, we expect that all records
in all of the chado-mart tables will be truncated prior to loading
the tab-delimited files produced by the execution of this program.

The chado-mart tables' table identifiers (primary keys) are
generated in the Prism.pm module using a simple incrementing
counter starting at zero.


Assumptions:

1. User has appropriate permissions (to execute script, access chado database, write to output directory).
2. Target chado database already contains appropriate features, computational analyses
3. All software has been properly installed, all required libraries are accessible.

Sample usage:

./chadoToChadoMart.pl --username=access --password=access --server=SYBTIGR --database=clostridium --database_type=sybase --outdir=/tmp/ --logfile=/tmp/my.log --cm_proteins=1

./chadoToChadoMart.pl --username=access --password=access --server=SYBTIGR --database=clostridium --database_type=sybase --outdir=/tmp/ --logfile=/tmp/my.log --cm_proteins=1 --program=jaccard

./chadoToChadoMart.pl --username=access --password=access --server=SYBTIGR --database=clostridium --database_type=sybase --outdir=/tmp/ --logfile=/tmp/my.log --program=clustalw 

./chadoToChadoMart.pl --username=access --password=access --server=SYBTIGR --database=clostridium --database_type=sybase --outdir=/tmp/ --logfile=/tmp/my.log --cluster_analysis_id=1,2,3 --batch_size=40

./chadoToChadoMart.pl --username=access --password=access --server=SYBTIGR --database=clostridium --database_type=sybase --outdir=/tmp/ --logfile=/tmp/my.log --cluster_analysis_id=1,2,3 --program=j_ortholog_clusters,jaccard

=head1 AUTHOR

Jay Sundaram

sundaram@tigr.org

=cut


use strict;
use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Coati::Logger;


$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($username, $password, $database, $server, $debug_level, 
    $help, $logfile, $man, $outdir, $database_type, $cluster_analysis_id,
    $program, $cm_proteins, $cmClustersBatchsize, $iteratorlist,
    $no_clusters, $blast_analysis_id,$use_cm_blast);

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
			  'cluster_analysis_id=s' => \$cluster_analysis_id,
              'blast_analysis_id=s' => \$blast_analysis_id,
			  'program=s'         => \$program,
			  'cm_proteins=s'     => \$cm_proteins,			  
			  'batch_size=s'      => \$cmClustersBatchsize,			  
			  'iteratorlist=s'    => \$iteratorlist,
			  'no-clusters=s'     => \$no_clusters,
              'use_cm_blast=s'    => \$use_cm_blast
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);


my $fatalCtr=0;

if (!defined($username)){
    print STDERR ("username was not defined\n");
    $fatalCtr++;
}

if (!defined($password)){
    print STDERR ("password was not defined\n");
    $fatalCtr++;
}

if (!defined($database)){
    print STDERR ("database was not defined\n");
    $fatalCtr++;
}

if (!defined($database_type)){
    print STDERR ("database_type was not defined\n");
    $fatalCtr++;
}

if (!defined($server)){
    print STDERR ("server was not defined\n");
    $fatalCtr++;
}

if (!defined($blast_analysis_id) &&  !$no_clusters){
    print STDERR ("blast_analysis_id was not defined\n");
    $fatalCtr++;
}

if ($fatalCtr > 0 ){
    &print_usage();
}

## Get the Log4perl logger
if (!defined($logfile)){
    $logfile = "/tmp/chadoToChadoMart.pl.log";
    print "logfile was not specified and so was set to '$logfile'\n";
}
my $mylogger = new Coati::Logger('LOG_FILE' => $logfile,
				 'LOG_LEVEL'=> $debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


## Use class method to verify the database vendor type
if (! Prism::verifyDatabaseType($database_type)){
    $logger->logdie("Unsupported database type '$database_type'");
}

## Caching should be turned off
$ENV{DBCACHE} = undef;
$ENV{DBCACHE_DIR} = undef;

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

if ($logger->is_debug()){
    $logger->debug("prism:". Dumper $prism);
}

##----------------------------------------------------------------------------
## In case you missed this in the description above:
##
## This program does not support parallel processing.  In order to 
## accomodate that feature, we would need to adopt the use of
## checksum placeholder values.  In order to use checksum placeholder
## values, we would need to identify unique sets of fields to compose 
## the uniqueness constraints for each chado-mart table.
##
## Also note that when we run this program, we expect that all records
## in all of the chado-mart tables will be truncated prior to loading
## the tab-delimited files produced by the execution of this program.
##
## The chado-mart tables' table identifiers (primary keys) are
## generated in the Prism.pm module using a simple incrementing
## counter starting at zero.
##
##----------------------------------------------------------------------------

my $recctr=0;

if (defined($cm_proteins)){
    if (! $prism->existsGeneModels()){
	$logger->warn("No gene models available in database ".
		      "'$database' on server '$server' so $0 ".
		      "cannot generate any cm_protein records ".
		      "at this time");
    } else {
	## generate records for cm_proteins only
	$recctr += &generateCmProteinsRecords($prism, $database, $server);
    }
}

if ((defined($no_clusters)) && ($no_clusters == 1)){
    print "The user specified --no-clusters=1, therefore the cm_clusters and ".
		  "cm_cluster_member records will not be generated";
}
else {
    ## generate records for cm_clusters, cm_cluster_members
    $recctr += &generateCmClusterRecords($prism, $database, $server, $cluster_analysis_id, $blast_analysis_id, $program);
}


if ( $recctr > 0 ){
    ## BCP files will be produced.
    
    print "BCP files will be written to directory '$outdir'\n\n";
    $prism->{_backend}->output_tables($outdir);
    
    if (defined($cm_proteins)){
	
	my $msg = "A BCP file containing records to be loaded into cm_proteins has been generated.\n".
	"Make sure the chado-mart table 'cm_proteins' in database '$database' (on server '$server') ".
	"either has no records or else truncate the table before attempting to load the BCP records.\n";
	
	$logger->warn("$msg");
    }

    if ((defined($iteratorlist)) && ($iteratorlist == 1)){
	$prism->createChadoMartTableListFile($outdir);
    }
    else {
	print "Run flatFileToChado.pl to load the BCP files in directory '$outdir' into the target database '$database' (on server '$server')\n";
    }
}
else {
    print "No BCP records were generated.\n";

}


print "\n$0 execution has completed\n";
print "The log file is '$logfile'\n";
exit(0);


##------------------------------------------------------------------------------------------
##
##            END OF MAIN  -- SUBROUTINES FOLLOW
##
##------------------------------------------------------------------------------------------

##--------------------------------------------------------
## generateCmProteinsRecords()
##
##--------------------------------------------------------
sub generateCmProteinsRecords {

    my ($prism, $database, $server) = @_;
    
    my $msg = "User has specified --cm_proteins=1, therefore data will be generated for the cm_proteins table.";
    print "$msg\n";
    $logger->warn("$msg");
    
    my $cmProteinRecords = $prism->retrieve_proteins();
	
    my $recctr = $prism->storeRecordsInCmProteins($cmProteinRecords);

    if ($recctr > 0 ){
	print "'$recctr' cm_proteins records have been written to the cm_proteins BCP file\n";
    }
    else {
	$logger->warn("No records were created for cm_proteins");
    }
    
    return $recctr;
}

##--------------------------------------------------------
## generateCmClusterRecords()
##
##--------------------------------------------------------
sub generateCmClusterRecords {

    my ($prism, $database, $server, $cluster_analysis_id, $blast_analysis_id, $program) = @_;

    my $analysisIdList = &getAnalysisIdList($prism, $cluster_analysis_id, $program);
    
    my $count = scalar(@{$analysisIdList});
    
    my $recctr=0;

    if ($count > 0 ){
	
	## To check for the presence of target chado-mart tables before executing
	## long runnning steps for generating cm_clusters and cm_cluster_members records.
	
	my $cm_clusters_id =  $prism->max_table_id('cm_clusters', 'cm_clusters_id');
	if ($logger->is_debug()){
	    $logger->debug("Will create records for cm_clusters starting at cm_clusters_id '$cm_clusters_id'");
	}
	
	my $cm_cluster_members_id =  $prism->max_table_id('cm_cluster_members', 'cm_cluster_members_id');
	
	if ($logger->is_debug()){
	    $logger->debug("Will create records for cm_cluster_members starting at cm_cluster_members_id '$cm_cluster_members_id'");
	}

	## Keep track of number of cm_clusters records written to the BCP file.
	my $cmClustersCtr=0;

	## Keep track of number of cm_cluster_members records written to the BCP file.
	my $cmClusterMembersCtr=0;


	if ((!defined($cmClustersBatchsize)) || ($cmClustersBatchsize !~ /^\d+$/)){
	    $cmClustersBatchsize = 60;
	    $logger->warn("Setting cm_clusters record retrieval batch size in the client to '$cmClustersBatchsize'");
	}

	foreach my $aid (@{$analysisIdList}){

	    if ($prism->isAnalysisIdValid($aid)){
		print "Processing analysis_id '$aid'\n";

        my $cmClusterRecords;
        if($use_cm_blast) {
            print "Using cm_blast\n";
            $cmClusterRecords = $prism->retrieve_clusters_from_cm_blast($aid);
        }
        else {
            $cmClusterRecords = $prism->retrieve_clusters_by_analysis_id3($aid,$blast_analysis_id);
#                                                    , $cmClustersBatchsize);
        }
		print "Will generate cm_clusters records for analysis_id '$aid'\n";		
		$cmClustersCtr += $prism->storeRecordsInCmClusters($cmClusterRecords);



		my $cmClusterMemberRecords = $prism->retrieve_cluster_members_by_analysis_id($aid);
		print "Will generate cm_cluster_members records for analysis_id '$aid'\n";
		$cmClusterMembersCtr += $prism->storeRecordsInCmClusterMembers($cmClusterMemberRecords);
	    }
	    else {
		$logger->logdie("analysis_id '$aid' is not valid");
	    }
	}	    
	 
	$recctr += $cmClustersCtr;
	$recctr += $cmClusterMembersCtr;

	if ($recctr > 0){

	    if ($cmClustersCtr>0){
		print "'$cmClustersCtr' cm_clusters records will be written to the cm_clusters BCP file.\n";
	    }
	    
	    if ($cmClusterMembersCtr>0){
		print"'$cmClusterMembersCtr' cm_cluster_members records will be written to the cm_cluster_members BCP file.\n";
	    }

	    my $msg;

	    if ($recctr == 1){
		$msg = "The cm_clusters and cm_cluster_members BCP files for analysis with analysis_id '@{$analysisIdList}' will be written to directory '$outdir'.\n".
		"Make sure the chado-mart tables 'cm_clusters' and 'cm_cluster_members' in database '$database' (on server '$server') ".
		"do not already have records for these analysis_id values.\n".
		"If they are already present and you still need to load the records ".
		"that were generated during this session, you will need to delete the appropriate records from cm_clusters and ".
		"cm_cluster_members.\n".
		"That or truncate the two tables.\n".
		"Caution: If you truncate these tables, then the records associated with other analysis_id values will also be lost.\n";
	    }
	    else {
		$msg = "The cm_clusters and cm_cluster_members BCP files for analyses with analysis_id values '@{$analysisIdList}' will be written to directory '$outdir'.\n".
		"Make sure the chado-mart tables 'cm_clusters' and 'cm_cluster_members' in database '$database' (on server '$server') ".
		"do not already have records for these analysis_id values.\n".
		"If they are already present and you still need to load the records ".
		"that were generated during this session, you will need to delete the appropriate records from cm_clusters and ".
		"cm_cluster_members.\n".
		"That or truncate the two tables.\n".
		"Caution: If you truncate these tables, then the records associated with other analysis_id values will also be lost.\n";
	    }
	    print $msg;
	}
	else {
	    my $msg = "No records were written to the BCP files for cm_clusters and cm_cluster_members.";
	    print "$msg\n";
	}
    }
    else {
	$logger->logdie("No analysis_id values to process given analysis_id '$cluster_analysis_id' program '$program'");
    }

    return $recctr;
}

##--------------------------------------------------------
## verify_and_set_outdir()
##
##--------------------------------------------------------
sub verify_and_set_outdir {

    my ( $outdir) = @_;

    $logger->debug("Verifying and setting output directory") if ($logger->is_debug());

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

}#end sub verify_and_set_outdir()


##------------------------------------------------------
## print_usage()
##
##------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 [--cluster_analysis_id] [--batch_size] [--cm_proteins] --database --database_type [--debug_level] [-h] [--logfile] [-m] [--no-clusters] [--outdir] --password [--program] --server --username\n".
    "  --cluster_analysis_id = Optional - User can specify a comma-separated list of analysis.analysis_id values for the particular cluster analysis(ses) of interest\n".
    "  --blast_analysis_id   = Optional - User can specify the analysis_id of the search used to generate the clusters\n".
    "  --batch_size          = Optional - To control the size of data cached in memory during step that generates cm_clusters records.  See --man for details.  (default: 60)\n".
    "  --cm_proteins         = Optional - cm_proteins=1 will result in the creation of cm_proteins records\n".
    "  --database            = Name of chado database\n".
    "  --database_type       = RDBMS type e.g. sybase or postgresql\n".
    "  ---debug_level        = Optional - Coati::Logger log4perl logging level.  Default is 0\n".
    "  -h|--help             = Optional - Display pod2usage help screen\n".
    "  --logfile             = Optional - Log4perl log file (default: /tmp/chadoToChadoMart.pl.log)\n".
    "  -m|--man              = Optional - Display pod2usage pages for this utility\n".
    "  --no-clusters         = Optional - Do not generate records for cm_clusters and cm_cluster_members\n".
    "  --outdir              = Optional - output directory for tab delimited BCP files (Default is current working directory)\n".
    "  --password            = Database account password\n".
    "  --program             = Optional - user can specify a comma-separated list of analysis.program values for cluster records\n".
    "  --server              = Name of server on which the database resides\n".
    "  --username            = Database account username\n";
    exit 1;

}

##--------------------------------------------------
## setPrismEnv()
##
##--------------------------------------------------
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

    if ($logger->is_debug()){
	$logger->debug("PRISM was set to '$prismenv'");
    }

    $ENV{PRISM} = $prismenv;
}

##--------------------------------------------------
## getAnalysisIdList()
##
##--------------------------------------------------
sub getAnalysisIdList {

    my ($prism, $cluster_analysis_id, $program) = @_;
    
    if ((!defined($cluster_analysis_id)) && (!defined($program))) {

	if ($logger->is_debug()){
	    $logger->debug("Neither --cm_proteins=1, --analysis_id nor --program were specified, ".
			   "will attempt to retrieve analysis_id values for known cluster analyses.");
	}

	$cluster_analysis_id = $prism->clusterAnalysisIdValues();
	
	if (!defined($cluster_analysis_id)){
	    $logger->logdie("Neither --cm_proteins=1, --analysis_id nor --program were specified, ".
			   "and this software could not find any analysis records of type 'clustering' ".
			    "in the database.");
	}
    }

    my @alist;

    if (defined($cluster_analysis_id)){
	@alist = split(/,/, $cluster_analysis_id);
    }

    if (defined($program)){
	my @proglist = split(/,/, $program);
	foreach my $prog ( @proglist ){
  
	    my $ret = $prism->analysisIdForProgram($prog);

	    for ( my $i=0; $i < scalar(@{$ret}); $i++){
		$logger->warn("Adding analysis_id '$ret->[$i][0]' for program '$prog' to list to be processed.");
		push(@alist, $ret->[$i][0]);
	    }
	}
    }

    return \@alist;
}
