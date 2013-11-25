#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

lineageSpecificAnalysis.pl - Parse BSML file and create GFF3 file

=head1 SYNOPSIS

USAGE:  lineageSpecificAnalysis.pl --cut_off --database [--debug_level] --joc_id [--help|h] [--rbm] [--logfile] [--man|-m] [--outdir]

=head1 OPTIONS

=over 8

=item B<--bsml_file_name>

BSML file to be processed.

=item B<--debug_level>

Optional - Log4perl logging level.  Default is 0.

=item B<--gff_file_name>

Optional - GFF3 file to be written to.  Default is the --outdir/--bsml_file_name.gff3

=item B<--help,-h>

Print this help

=item B<--keep_all_features>

Optional - If user specifies --keep_all_features=1, then all Features present in the BSML file will be written to the GFF3 file.  By default,
           only the following feature types will be written to the GFF3 file:
           gene, mRNA, CDS, rRNA, tRNA, snRNA, exon

=item B<--logfile>

Optional - The Log4perl log file.  Default is /tmp/lineageSpecificAnalysis.pl.log.

=item B<--man,-m>

Display the pod2usage page for this utility

=item B<--outdir>

Optional - Output directory to write the GFF3 file if the --gff_file_name is not specified.  Default is current working current directory.

=item B<--preserve_types>

Optional - If user specifies --preserve_types=1, then the following type transformations will not be applied: assembly -> contig; transcript -> mRNA

=item B<--source>

Value to be stored in column 2 for all GFF records

=item B<--translation_table>

Optional - default value to be written to the output GFF3 file if this script cannot derive a value from the input BSML file.  A value of 'none' will result in this script's execution aborting prematurely if a translation_table value cannot be derived from the input BSML file.

=back

=head1 DESCRIPTION

lineageSpecificAnalysis.pl - Parse BSML file and create GFF3 file

Assumptions:
1. User has appropriate permissions (to execute script, read the BSML file, write to output directory).
2. All software has been properly installed, all required libraries are accessible.

Sample usage:
./lineageSpecificAnalysis.pl --bsml_file_name=/usr/local/scratch/sundaram/pva1.assembly.9.0.bsml --logfile=pva1.log --gff_file_name=pva1.gff3 --source=neisseria
./lineageSpecificAnalysis.pl --bsml_file_name=/usr/local/scratch/sundaram/pva1.assembly.9.0.bsml --outdir=/usr/local/scratch/sundaram --source=neisseria

=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=cut


use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use File::Basename;
use Data::Dumper;
use Coati::Logger;
use Prism;

## Do not buffer output stream
$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($cutoff, $debugLevel, $help, $logfile, $man, $outdir, $database, 
    $jocId, $database_type, $server, $outfile, $organismCount, 
    $username, $password, $memberCount);

my $results = GetOptions (
			  'cutoff=s'            => \$cutoff, 
			  'debug_level=s'       => \$debugLevel,
			  'database=s'          => \$database,
			  'help|h'              => \$help,
			  'logfile=s'           => \$logfile,
			  'man|m'               => \$man,
			  'outdir=s'            => \$outdir,
			  'joc_id=s'            => \$jocId,
			  'database_type=s'     => \$database_type,
			  'server=s'            => \$server,
			  'outfile=s'           => \$outfile,
			  'organism_count=s'    => \$organismCount,
			  'member_count=s'      => \$memberCount,
			  'username=s'          => \$username,
			  'password=s'          => \$password
			  );
&checkCommandLineArguments();

my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile, 'LOG_LEVEL'=>$debugLevel);

## Get the Log4perl logger
my $logger = Coati::Logger::get_logger(__PACKAGE__);

&buildInvocationString();	     

## verify and set the output directory
$outdir = &verify_and_set_outdir($outdir);

## Set the PRISM environmenatal variable
&setPrismEnv($server, $database_type);

## Instantiate Prism object

my $prism = new Prism( user => $username, password => $password, db => $database );
if (!defined($prism)){
    $logger->logdie("prism was not defined");
}

#print STDERR "memberCount '$memberCount'\n";

my $cmBlastLookup = $prism->cmBlastLookup($cutoff);

## Retrieve the number of paralogs for each protein
## based on the wu-blastp analysis.
my $paralogCountLookup = $prism->paralogCountLookup();

## Keep track of the number of JOCs processed
my $jocCounter=0;

my $memberCountFailedCounter=0;

my $totalReciprocalBestMatchCounter=0;



my $proteinLookup = $prism->lineageSpecificAnalysisProteinInfo();

foreach my $memCount (reverse (1..$memberCount) ){

    ## cmClusterLookup is a reference to a Perl hash.
    ## The hash will be keyed on cluster_id.
    ## The value of the hash will be a reference to an array.
    ## The array elements will consist of the following values:
    ## [0] == num_members
    ## [1] == num_organisms

    my $cmClusterMembersLookup = $prism->cmClusterMembersLookup($memCount, $organismCount, $jocId);

    
    ## Keep track of the number of reciprocal best matches encountered
    ## for this particular JOC.
    my $reciprocalBestMatchCounter=0;
    
    ## Keep track of the proteins (i.e. the members of the particular
    ## JOC) which were each other's reciprocal best match. 
    my $reciprocalBestMatchLookup = {};

    ## For each protein member (cm.feature_id) retrieve all cm_blast records where
    ## this protein was the query in the wu-blastp analysis.   The cm_blast records
    ## will be ordered by decreasing cm_blast.p_value.  If the smallest value
    ## corresponds with one of the other cm_cluster_members, then we may have a winner.
    ## The number of reciprocal best matches must equal the number specified by the
    ## $memCount.

    foreach my $clusterId (keys %{$cmClusterMembersLookup}) {

	$jocCounter++;

	my $JOCClusterMemberArrayRef = $cmClusterMembersLookup->{$clusterId};
	
	if ($logger->is_debug()){
	    $logger->debug("JOC members for cluster_id '$clusterId': '@{$JOCClusterMemberArrayRef}'");
	}
	
	my $memberLookup={};

	foreach my $mem (@{$JOCClusterMemberArrayRef}){

	    $memberLookup->{$mem}++;

	    if ($logger->is_debug()){
		$logger->debug("best hits in table cm_blast for member '$mem' in JOC '$clusterId' : " . Dumper $cmBlastLookup->{$mem});
	    }
	}

	if ($logger->is_debug()){
	    $logger->debug("memberLookup:" . Dumper $memberLookup);
	}

	## Make sure we only store the JOC polypeptide
	## member once.
	my $uniqLookup={};
	
	## Keep track of the number of polypeptide members in 
	## this one particular JOC.
	my $JOCMemberCounter=0;

	## This will allow us to only store one ortholog from
	## each organism.
	my $uniqOrganismIdLookup={};

	## Keep track of the number of unique organisms among
	## this polypeptide's orthologs.
	my $uniqOrganismCounter=0;

	foreach my $qfeature_id (@{$JOCClusterMemberArrayRef}){

	    $JOCMemberCounter++;

	    if ( exists $cmBlastLookup->{$qfeature_id} ){
		## A record for this polypeptide exists in the cm_blast table.

		foreach my $matchArrayRef ( @{$cmBlastLookup->{$qfeature_id}} ) {
		
		    my $hfeature_id = $matchArrayRef->[0];

		    if ( exists $memberLookup->{$hfeature_id}){
			## This particular match, is one of the JOC
			## members (related to our qfeature_id).
			
			my $horganism_id = $matchArrayRef->[2];

			if ( exists $uniqOrganismIdLookup->{$horganism_id} ){
			    ## Already encountered some ortholog for this
			    ## organism.
			    next;
			}
			else {
			    $uniqOrganismIdLookup->{$horganism_id}++;
			    $uniqOrganismCounter++;
			}

			if ($logger->is_debug()){
			    $logger->debug("qfeature_id '$qfeature_id' hfeature_id '$hfeature_id' horganism_id '$horganism_id'");
			}

			my $reciprocalBestMatchFound=0;
			my $lowestPvalue=100;

			foreach my $hMatchArrayRef ( @{$cmBlastLookup->{$hfeature_id}} ) {

			    if ($hMatchArrayRef->[1] < $lowestPvalue){
				$lowestPvalue = $hMatchArrayRef->[1];
			    }

			    if ($hMatchArrayRef->[0] == $qfeature_id ){
#				if ( $hMatchArrayRef <= $lowestPvalue ){
				    $reciprocalBestMatchFound=1;
#				}
			    }
			}
			    
			if ($reciprocalBestMatchFound == 1){

#			    die "found";
			    if (! exists $uniqLookup->{$qfeature_id}){
				$reciprocalBestMatchCounter++;
#				my $orthologCount = scalar(@{$cmBlastLookup->{$qfeature_id}});
#				push(@{$reciprocalBestMatchLookup->{$clusterId}->[1]}, [ $qfeature_id, $orthologCount ] );
				push(@{$reciprocalBestMatchLookup->{$clusterId}->[1]}, $qfeature_id );
				$uniqLookup->{$qfeature_id}++;

			    }
			    
			    
			    if (! exists $uniqLookup->{$hfeature_id}){
#				$reciprocalBestMatchCounter++;
#				my $orthologCount = scalar(@{$cmBlastLookup->{$hfeature_id}});
#				push(@{$reciprocalBestMatchLookup->{$clusterId}->[1]}, [ $hfeature_id, $orthologCount ] );
				push(@{$reciprocalBestMatchLookup->{$clusterId}->[1]}, $hfeature_id );
				$uniqLookup->{$hfeature_id}++;
			    }
			    
			}
		    }
		}
	    }
	}

	$reciprocalBestMatchLookup->{$clusterId}->[0] = $JOCMemberCounter;
	$reciprocalBestMatchLookup->{$clusterId}->[2] = $uniqOrganismCounter;
    }
    
    if ($reciprocalBestMatchCounter > 0 ){
	
	if ($outfile){
#	if (0){
#	    $logger->fatal("results:".Dumper $reciprocalBestMatchLookup);
	    &writeOutfile($reciprocalBestMatchLookup, $proteinLookup, $paralogCountLookup, $outfile);
	}
	else {
	    $prism->storeLineageSpecificAnalysis($reciprocalBestMatchLookup, $proteinLookup, $paralogCountLookup);
	}
	
	$totalReciprocalBestMatchCounter += $reciprocalBestMatchCounter;
    }
    last;
}

if ($logger->is_debug()){
    $logger-is_debug("cmBlastLookup:" . Dumper $cmBlastLookup);
}

if ($jocCounter > 0 ){
    print "Processed '$jocCounter' JOCs\n";
}
else {
    $logger->logdie("No JOCs were processed for database '$database' server '$server' ".
		    "joc_id '$jocId'");
}

if ($memberCountFailedCounter > 0 ){
    print STDERR "Please review the logfile '$logfile'\n";
}

if ($totalReciprocalBestMatchCounter > 0 ){

    print "Found '$totalReciprocalBestMatchCounter' reciprocal best matches in database '$database' ".
    "server '$server' JOC analysis_id '$jocId' cutoff '$cutoff'\n";

    if ($outfile){
	print "This lineage specific analysis tab-delimited file was created: '$outfile'\n";
    }
    else {
	$logger->info("Writing tab delimited .out files to directory: $outdir");
        
	$prism->{_backend}->output_tables($outdir);
	
	print "The tab-delimited BCP file '$outdir/cm_lineage.out' was created.\n".
	
	"Run flatFileToChado.pl to load its contents into into table 'cm_lineage' in database '$database' on server '$server'\n";
    }
}
else {
    print "No reciprocal best matches were found in database '$database' server '$server' ".
    "JOC analysis_id '$jocId' cutoff '$cutoff'\n";
}




print "$0 program execution completed\n";
print "The logfile is '$logfile'\n";
exit(0);

##-------------------------------------------------------------------------------------------------------------------------
##
##                                END OF MAIN  -- SUBROUTINES FOLLOW
##
##-------------------------------------------------------------------------------------------------------------------------


sub checkCommandLineArguments {

    if ($help){
	&pod2usage( {-exitval => 1, -verbose => 2, -output => \*STDOUT} ); 
	exit(1);
    }
    
    my $fatalCtr=0;

    if (!$database){
	print STDERR "--database was not specified\n";
	$fatalCtr++;
    }
    if (!$username){
	print STDERR "--username was not specified\n";
	$fatalCtr++;
    }
    if (!$password){
	print STDERR "--password was not specified\n";
	$fatalCtr++;
    }
    if (!$jocId){
	print STDERR "--joc_id was not specified\n";
	$fatalCtr++;
    }
    if (!$organismCount){
	print STDERR "--organism_count was not specified\n";
	$fatalCtr++;
    }

    if ( (!defined($outfile)) && (!defined($outdir) ) ){
	print STDERR "neither --outfile nor --outdir were specified\n";
	$fatalCtr++;
    }

    if ((defined($memberCount)) && ($memberCount > 1)){
	print STDERR "--member_count must be a value greater than zero\n";
	$fatalCtr++;
    }
    
    if ( $fatalCtr > 0 ){
	die "Required command-line arguments were not specified";
    }
    

    if (!$logfile){
	$logfile = '/tmp/' . basename($0) . '.log';
	print "logfile was set to '$logfile'\n";
    }

    if (!defined($cutoff)){
#	$cutoff = 1e-10;
	$cutoff = 1e-5;
	print STDERR "--cutoff was not specified and therefore was set to '$cutoff'\n";
    }

    if (!defined($database_type)){
	$database_type = 'Sybase';
	print STDERR "--database_type was not specified and therefore was set to '$database_type'\n";
    }

    if (!defined($server)){
	$server = 'SYBTIGR';
	print STDERR "--server was not specified and therefore was set to '$server'\n";
    }

    if (!defined($memberCount)){
	$memberCount = 3;
	print STDERR "--member_count was not specified and therefore was set to '$memberCount'\n";
    }

}

sub buildInvocationString {

    
# #     if (defined($username)){
# # 	$invocation .= " --username=$username";
# #     }
# #     if (defined($password)){
# # 	$invocation .= " --password=$password";
# #     }
# #     if (defined($infile)){
# # 	$invocation .= " --infile=$infile";
# #     }
# #     if (defined($outfile)){
# # 	$invocation .= " --outfile=$outfile";
# #     }
# #     if (defined($insertRefFeatures)){
# # 	$invocation .= " --insert-ref-features";
# #     }
# #     if (defined($insertQryFeatures)){
# # 	$invocation .= " --insert-qry-features";
# #     }
# #     if (defined($mapover)){
# # 	$invocation .= " --map-over";
# #     }
# #     if (defined($maintain)){
# # 	$invocation .= " --maintain";
# #     }
# #     if (defined($featNameModifier)){
# # 	$invocation .= " --feat-name-modifier=$featNameModifier";
# #     }
# #     if (defined($transferLoci)){
# # 	$invocation .= " --transfer-loci";
# #     }
# #     if (defined($logfile)){
# # 	$invocation .= " --logfile=$logfile";
# #     }
# #     if (defined($dbtype)){
# # 	$invocation .= " --dbtype=$dbtype";
# #     }
# #     if (defined($server)){
# # 	$invocation .= " --server=$server";
# #     }
# #     if (defined($password)){
# # 	$invocation .= " --password=$password";
# #     }
# #     if (defined($username)){
# # 	$invocation .= " --username=$username";
# #     }
}

sub verifyAndSetOutdir {

    my ( $outdir) = @_;

    if (defined($outdir)){
	## strip trailing forward slashes
	$outdir =~ s/\/+$//;
	
	if (!-e $outdir){
	    $logger->logdie("outdir '$outdir' does not exist");
	}
	if (!-d $outdir){
	    $logger->logdie("outdir '$outdir' is not a directory");
	}
	if (!-w $outdir){
	    $logger->logdie("outdir '$outdir' does not have write permissions");
	}
    }
    else {
	if (!defined($ENV{'OUTPUT_DIR'})){
	    $outdir = "." 
	}
	else{
	    $outdir = $ENV{'OUTPUT_DIR'};
	}
    }

    ## store the outdir in the environment variable
    $ENV{OUTPUT_DIR} = $outdir;
    
    return $outdir;
}


sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 --bsml_file_name [--debug_level] [--gff_file_name] [--help|h] [--keep_all_features=1] [--logfile] [--man|m] [--outdir] [--preserve_types=1] --source [--translation_table]\n".
    "  --bsml_file_name     = Name of BSML file to be processed\n".
    "  -d|--debug_level     = Optional - Log4perl logging level (default is 0)\n".
    "  --gff_file_name      = Optional - Name of the output GFF3 file (default is --bsml_file_name.gff3)\n".
    "  -h|--help            = Optional - Display pod2usage help screen\n".
    "  --keep_all_features  = Optional - Does not filter out non-qualified feature types\n".
    "  --logfile            = Optional - Log4perl logfile (default is /tmp/lineageSpecificAnalysis.p.log)\n".
    "  -m|--man             = Optional - Display pod2usage pages for this utility\n".
    "  --outdir             = Optional - If --gff_file_name is not specified, then the output directory for the GFF3 file (default is current working directory)\n".
    "  --preserve_types     = Optional - If --preserve_types, then type transformations will not be applied\n";
    "  --source             = GFF3 column 1 value\n".
    "  --translation_table  = Optional - user can specify a default value that will be applied only if the script cannot derive the value from the input BSML file\n";
    exit (1);

}

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


sub writeOutfile {

    my ($lookup, $proteinLookup, $paralogCountLookup, $outfile) = @_;

    ## Example http://www.tigr.org/tigr-scripts/euk_manatee/shared/ORF_infopage.cgi?db=pmfa1&orf=102.m007756

    my $url  = "http://www.tigr.org/tigr-scripts/euk_manatee/shared/ORF_infopage.cgi?db=";

    open (OUTFILE, ">$outfile") || $logger->logdie("Could not open outfile '$outfile' in write mode:$!");

    print OUTFILE "## Tab-delimited columns are:\n".
    "## JOC (cluster_id)\n".
    "## JOC number of members\n".
    "## feat_name\n".
    "## number of orthologs\n".
    "## pub_locus\n".
    "## gene product name\n".
    "## gene length\n".
    "## protein length\n".
    "## number of exons\n".
    "## manatee URL\n".
    "## paralog count\n";


    foreach my $clusterId (sort keys %{$lookup}){

	my $jocCount = $lookup->{$clusterId}->[0];

	my $num_orthologs = $lookup->{$clusterId}->[2];

	foreach my $protein_id ( @{$lookup->{$clusterId}->[1]} ){ 

# 	    my $protein_id = $array->[0];
# 	    my $ortholog_count = $array->[1];

	    if (! exists $proteinLookup->{$protein_id} ){
		$logger->logdie("protein_id '$protein_id' does not exist in proteinLookup");
	    }

	    my $uniquename = shift(@{$proteinLookup->{$protein_id}});

	    my $feat_name = shift(@{$proteinLookup->{$protein_id}});

	    my ($sourceDatabase, @hold) = split(/\./, $uniquename);

	    if (!defined($proteinLookup->{$protein_id}->[0])){
		$proteinLookup->{$protein_id}->[0] = 'NULL';
	    }

	    my $info = join("\t", @{$proteinLookup->{$protein_id}});

	    $info .=  "\t" . $url . $sourceDatabase . "&orf=" . $feat_name;

	    my $paralogCount;

	    if ( exists $paralogCountLookup->{$protein_id}){
		$paralogCount = $paralogCountLookup->{$protein_id};
	    }
	    else {
		$paralogCount = 0;
# 		$logger->fatal("paralogCountLookup:". Dumper $paralogCountLookup);
# 		$logger->logdie("No paralog count for polypeptide with feature_id '$protein_id'");
	    }

#	    print OUTFILE "$clusterId\t$jocCount\t$feat_name\t$ortholog_count\t$organismCount\t$info\n";
	    print OUTFILE "$clusterId\t$jocCount\t$feat_name\t$num_orthologs\t$info\t$paralogCount\n";
	}
#	print OUTFILE "----------------------------------------------\n\n";
    }
}


sub verify_and_set_outdir {

    my ( $outdir) = @_;

    if ($logger->is_debug()){
	$logger->debug("Verifying and setting output directory");
    }

    ## strip trailing forward slashes
    $outdir =~ s/\/+$//;
    
    ## set to current directory if not defined
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

    if ($logger->is_debug()){
	$logger->debug("outdir is set to:$outdir");
    }

    ## store the outdir in the environment variable
    $ENV{OUTPUT_DIR} = $outdir;
    
    return $outdir;

}
