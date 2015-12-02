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
    $username, $password, $memberCount, $captureExtraSpeciesParalogs);

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
			  'password=s'          => \$password,
			  'track-out-paralogs=s' => \$captureExtraSpeciesParalogs
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

my $memberCountFailedCounter=0;

my $totalReciprocalBestMatchCounter=0;

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

my $lookup={};

my $organismLookup = $prism->organismLookup();

if ($logger->is_debug()){
    $logger->debug("organism lookup:". Dumper $organismLookup);
}

my $cmBlastLookupByOrganism = $prism->cmBlastByOrganismLookup($cutoff);

if ($logger->is_debug()){
    $logger->debug("cm_blast by organism_id lookup:". Dumper $cmBlastLookupByOrganism);
}

## Keep track of all paralogs found in other
## organisms' protein sets.
my $extraSpeciesParalogLookup={};

foreach my $organism_id ( keys %{$organismLookup} ) {
   
    foreach my $qfeature_id ( keys %{$cmBlastLookupByOrganism->{$organism_id}} ) {
	
	my $orthologByOrganismLookup={};
	
	foreach my $horganism_id ( keys %{$cmBlastLookupByOrganism->{$organism_id}->{$qfeature_id}}) {
	    
	    foreach my $hfeature_id ( @{$cmBlastLookupByOrganism->{$organism_id}->{$qfeature_id}->{$horganism_id}} ) {

		
		if (! exists $orthologByOrganismLookup->{$horganism_id} ){
		    ## Ortholog
		    $lookup->{$organism_id}->{$qfeature_id}->{'o'}->{$hfeature_id}++;
		    ## Indicate that we have now encountered the 
		    ## ortholog for this qfeature_id and all others
		    ## should be treated as paralogs.
		    $orthologByOrganismLookup->{$horganism_id}++;
		}
		else {
		    ## Paralogs in other species.
#		$lookup->{$organism_id}->{$qfeature_id}->{'p'}->{$matchArrayRef->[1]}++;

		    if ($captureOutSpeciesParalogs==1){
			## Keep track of extra-species paralogs by those species' organism_id.
			push(@{$extraSpeciesParalogLookup->{$qfeature_id}->{$horganism_id}}, $hfeature_id);
		    }
		}
	    }
	}
    }
}

## Reciprocal best match lookup
my $rbmLookup={};

my $reciprocalBestMatchCounter=0;

foreach my $organism_id ( sort keys %{$lookup} ) {
    foreach my $qfeature_id ( keys %{$lookup->{$organism_id}} ) {
	foreach my $hfeature_id ( keys %{$lookup->{$organism_id}->{$qfeature_id}->{'o'}} ){
	    foreach my $organism_id2 (keys %{$lookup}){
		if ( exists $lookup->{$organism_id2}->{$hfeature_id} ){
		    if (exists $lookup->{$organism_id2}->{$hfeature_id}->{'o'}){
			if (exists $lookup->{$organism_id2}->{$hfeature_id}->{'o'}->{$qfeature_id}){
			    ## qfeature_id and hfeature_id are reciprocal best matches
			    push(@{$rbmLookup->{$organism_id}->{$qfeature_id}->[0]}, $hfeature_id);
			    ## Keep count of number of members
			    $rbmLookup->{$organism_id}->{$qfeature_id}->[1]++;

			    ## Found a reciprocal best match!
			    $reciprocalBestMatchCounter++;
			}
		    }
		}
	    }
	}
    }
}

   
if ($reciprocalBestMatchCounter > 0 ){
    
    my $proteinLookup = $prism->lineageSpecificAnalysisProteinInfo();

    if ($logger->is_debug()){
	$logger->debug("protein lookup:". Dumper $proteinLookup);
    }
    
    my $sameSpeciesParalogCountLookup = $prism->sameSpeciesParalogCountLookup();
    
    if ($logger->is_debug()){
	$logger->debug("same species paralog count lookup:". Dumper $sameSpeciesParalogCountLookup);
    }

    if ($outfile){
#	if (0){
#	    $logger->fatal("results:".Dumper $reciprocalBestMatchLookup);
	&writeOutfile($rbmLookup, $extraSpeciesParalogLookup, $organismLookup, $sameSpeciesParalogCountLookup, $proteinLookup, $outfile);

	print "This lineage specific analysis tab-delimited file was created: '$outfile'\n";
    }
    else {
	$prism->storeLineageSpecificAnalysis($rbmLookup, $extraSpeciesParalogLookup, $organismLookup, $sameSpeciesParalogCountLookup, $proteinLookup, $outfile);

	$logger->info("Writing tab delimited .out files to directory: $outdir");
        
	$prism->{_backend}->output_tables($outdir);
	
	print "The tab-delimited BCP file '$outdir/cm_lineage.out' was created.\n".
	
	"Run flatFileToChado.pl to load its contents into into table 'cm_lineage' in database '$database' on server '$server'\n";

    }
}
else {
    print "No reciprocal best matches were found in database '$database' server '$server' cutoff '$cutoff'\n";
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

    if ( (!defined($outfile)) && (!defined($outdir) ) ){
	print STDERR "neither --outfile nor --outdir were specified\n";
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

    if (!defined($captureExtraSpeciesParalogs)){
	$captureExtraSpeciesParalogs = 0;
	print STDERR "--track-out-paralogs was not specified and therefore was set to '$captureExtraSpeciesParalogs'\n";
    }

    if (!defined($server)){
	$server = 'SYBTIGR';
	print STDERR "--server was not specified and therefore was set to '$server'\n";
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

    my ($rbmLookup, $extraSpeciesParalogLookup, $organismLookup, $sameSpeciesParalogCountLookup, $proteinLookup, $outfile) = @_;

    ## Output the pub_locus values for the orthologs and paralogs
    ## instead of the feature.feature_id
    my $usePubLocusForOrthologs = 1;

    ## Example http://www.tigr.org/tigr-scripts/euk_manatee/shared/ORF_infopage.cgi?db=pmfa1&orf=102.m007756

    my $url  = "http://www.tigr.org/tigr-scripts/euk_manatee/shared/ORF_infopage.cgi?db=";
    
    open (OUTFILE, ">$outfile") || $logger->logdie("Could not open outfile '$outfile' in write mode:$!");
    
    print OUTFILE "## Tab-delimited columns are:\n".
    "## qfeature_id\n".
    "## feature.uniquename\n".
    "## asm_feature.feat_name\n".
    "## pub_locus\n".
    "## num_orthologs\n".
    "## orthologs\n".
    "## extra species paralogs\n".
    "## same species paralogs count\n".
    "## gene_product_name\n".
    "## gene length\n".
    "## protein length\n".
    "## num_exons\n".
    "## url\n";
    
    my $dirname = dirname($outfile);

    foreach my $organism_id (sort keys %{$organismLookup} ){
	
	my $organismArrayRef = $organismLookup->{$organism_id};

	my $genus = $organismArrayRef->[0];
	my $species = $organismArrayRef->[1];

	my $genusSpecies = ucfirst($genus) . '_' . ucfirst($species);

	## Remove all white spaces
	$genusSpecies =~ s/\s+//g;

	my $organismOutfile = $dirname . '/' . $genusSpecies . '.dat';

	open (ORGOUTFILE, ">$organismOutfile") || $logger->logdie("Could not open outfile '$organismOutfile' in write mode:$!");

	print OUTFILE "## Orthologs for proteins belonging to organism genus '$genus' species '$species'\n";
	print ORGOUTFILE "## Orthologs for proteins belonging to organism genus '$genus' species '$species'\n";
	print ORGOUTFILE "## Tab-delimited columns are:\n".
	"## qfeature_id\n".
	"## feature.uniquename\n".
	"## asm_feature.feat_name\n".
	"## pub_locus\n".
	"## num_orthologs\n".
	"## orthologs\n".
	"## extra species paralogs\n".
	"## same species paralogs count\n".
	"## gene_product_name\n".
	"## gene length\n".
	"## protein length\n".
	"## num_exons\n".
	"## url\n";

	foreach my $qfeature_id ( sort keys %{$rbmLookup->{$organism_id}} ){
	    
	    my $orthologs;
	    foreach my $ortho ( @{$rbmLookup->{$organism_id}->{$qfeature_id}->[0]} ){
		if ($usePubLocusForOrthologs){
		    if (exists $proteinLookup->{$ortho}){
			my $pubLocus = $proteinLookup->{$ortho}->[2];
			$orthologs .= "$pubLocus,";
		    }
		    else {
			$logger->logdie("ortholog '$ortho' does not exist in proteinLookup");
		    }
		}
		else {
		    $orthologs .= "$ortho,";
		}
	    }

	    ## Remove the trailing comma
	    chop $orthologs;

	    my $num_orthologs = $rbmLookup->{$organism_id}->{$qfeature_id}->[1];
	    
	    if (! exists $proteinLookup->{$qfeature_id} ){
		$logger->logdie("qfeature_id '$qfeature_id' does not exist in proteinLookup");
	    }
	    
	    my $uniquename = $proteinLookup->{$qfeature_id}->[0];
	    
	    my $feat_name = $proteinLookup->{$qfeature_id}->[1];

	    my $pub_locus = $proteinLookup->{$qfeature_id}->[2];

	    my $gene_product_name = $proteinLookup->{$qfeature_id}->[3];

	    my $gene_length = $proteinLookup->{$qfeature_id}->[4];

	    my $protein_length = $proteinLookup->{$qfeature_id}->[5];

	    my $num_exons = $proteinLookup->{$qfeature_id}->[6];
	    
	    my ($sourceDatabase, @hold) = split(/\./, $uniquename);
	    
	    my $url2 = $url . $sourceDatabase . "&orf=" . $feat_name;
	    
	    my $extraSpeciesParalogs;

	    foreach my $horganism_id ( keys %{$extraSpeciesParalogLookup->{$qfeature_id}} ){
		foreach my $para ( @{$extraSpeciesParalogLookup->{$qfeature_id}->{$horganism_id}}){
		    if ($usePubLocusForOrthologs){
			if (exists $proteinLookup->{$para}){
			    my $pubLocus = $proteinLookup->{$para}->[2];
			    $extraSpeciesParalogs .= "$pubLocus,";
			}
		    else {
			$logger->logdie("paralog '$para' does not exist in proteinLookup");
		    }
		    }
		    else {
			$extraSpeciesParalogs .= "$para,";
		    }
		}
	    }
	    chop $extraSpeciesParalogs;
		
	    my $sameSpeciesParalogCount=0;
	    if (exists $sameSpeciesParalogCountLookup->{$qfeature_id}){
		$sameSpeciesParalogCount = $sameSpeciesParalogCountLookup->{$qfeature_id};
	    }

	    print OUTFILE "$qfeature_id\t$uniquename\t$feat_name\t$pub_locus\t$num_orthologs\t$orthologs\t$extraSpeciesParalogs\t$sameSpeciesParalogCount\t$gene_product_name\t$gene_length\t$protein_length\t$num_exons\t$url2\n";

	    print ORGOUTFILE "$qfeature_id\t$uniquename\t$feat_name\t$pub_locus\t$num_orthologs\t$orthologs\t$extraSpeciesParalogs\t$sameSpeciesParalogCount\t$gene_product_name\t$gene_length\t$protein_length\t$num_exons\t$url2\n";


	}
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
