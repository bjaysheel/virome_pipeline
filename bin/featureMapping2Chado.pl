#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use strict;


use Data::Dumper;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Prism;
use Coati::Logger;
use Pod::Usage;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($username, $password, $database, $server, $debug_level, $help, $log4perl, $man, $outdir, $type1, $type2, $database_type);


my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'database|D=s'        => \$database,
			  'database_type=s'     => \$database_type,
			  'server|S=s'		=> \$server,
			  'log4perl|l=s'        => \$log4perl,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'outdir|o=s'          => \$outdir,
			  'type1|t=s'           => \$type1,
			  'type2|u=s'           => \$type2
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
if (!defined($type1)){
    print STDERR ("type1 was not defined\n");
    $fatalCtr++;
}
if (!defined($type2)){
    print STDERR ("type2 was not defined\n");
    $fatalCtr++;
}
if (!defined($server)){
    print STDERR ("server was not defined\n");
    $fatalCtr++;
}
if (!defined($database_type)){
    print STDERR ("database_type was not defined\n");
    $fatalCtr++;
}

if ($fatalCtr>0){
    &print_usage();
}

#
# initialize the logger
#
$log4perl = "/tmp/featureMapping2.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


if ($type1 eq $type2){
    $logger->logdie("type1 '$type1' and type2 '$type2' must be set to different values");
}



#
# verify and set the output directory
#
$outdir = &verify_and_set_outdir($outdir);

## Set the PRISM env var
&setPrismEnv($server, $database_type);

## Instantiate Prism object
my $prism = new Prism( 
		       user       => $username,
		       password   => $password,
		       db         => $database,
		       use_placeholders => 0
		       );

if (!defined($prism)){
    $logger->logdie("Could not instantiate Prism");
}

my $termname1 = $type1;
my $termname2 = $type2;


if ($type1 !~ /^\d+$/){
    $type1 = $prism->cvterm_id($type1);
}
else{
    $termname1 = $prism->cvterm_name_from_cvterm(cvterm_id=>$type1);
}
if ($type2 !~ /^\d+$/){
    $type2 = $prism->cvterm_id($type2);
}
else{
    $termname2 = $prism->cvterm_name_from_cvterm(cvterm_id=>$type2);
}

$logger->info("type1 '$type1' termname1 '$termname1' type2 '$type2' termname2 '$termname2'");

print "Running the feature mapping script given the following input values:\n".
"database '$database'\n".
"database_type '$database_type'\n".
"server '$server'\n".
"type1 '$termname1' (cvterm_id = '$type1')\n".
"type2 '$termname2' (cvterm_id = '$type2')\n";

my $type1Count = &checkFeatureCountsByType($prism, $type1, $server, $database, $termname1);

my $type2Count = &checkFeatureCountsByType($prism, $type2, $server, $database, $termname2);

my $seqLocCtr = &checkFeaturelocCountsByTypes($prism, $type1, $type2, $server, $database, $termname1, $termname2);

my $notLocalizedCounts = &checkForNoLocalizations($prism, $type1, $type2, $server, $database, $termname1, $termname2);

## Keep track of the number of features that were found to be localized to sequences of type 1
my $featureToType1Counts = {};

## Keep track of the number of features that were found to be localized to sequences of type 2
my $featureToType2Counts = {};

my $featurelocCount = &generateLocalizationRecords($prism, $type1, $type2, $termname1, $termname2);

if ($featurelocCount > 0 ){

    $prism->{_backend}->output_tables("$outdir/");
    
    print "'$featurelocCount' featureloc records were written to a BCP file in directory '$outdir'.\n".
    "Run flatFileToChado.pl to load the BCP file's contents into database '$database' on server '$server'.\n";
}

&reportCounts($featureToType1Counts, 
	      $featureToType2Counts,
	      $termname1,
	      $termname2,
	      $type1,
	      $type2,
	      $database,
	      $server,
	      $type1Count,
	      $type2Count);

my $exitMsg = "$0 program execution completed.\n".
"The number of sequences with secondary type '$termname1' (cvterm_id '$type1') found in the database was '$type1Count'\n".
"The number of sequences with secondary type '$termname2' (cvterm_id '$type2') found in the database was '$type2Count'\n".
"The number of '$termname2' sequences found to be localized to '$termname1' sequences before the creation of new featureloc records was '$seqLocCtr'\n";
if ($notLocalizedCounts>0){
    $exitMsg .= "'$notLocalizedCounts' '$termname1' sequences did not have any '$termname2' sequences localized to them.\n";
}
else {
    $exitMsg .="All '$termname1' sequences had some '$termname2' sequence localized to them.\n";
}

$exitMsg .= "Log file is '$log4perl'.\n".

$logger->warn("$exitMsg");
print $exitMsg;
exit(0);

##-----------------------------------------------------------------------------------------------------------------------
##
##                        END OF MAIN  -- SUBROUNTINES FOLLOW
##
##-----------------------------------------------------------------------------------------------------------------------

##-------------------------------------------------------
## verify_and_set_outdir()
##
##-------------------------------------------------------
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

    #
    # verify whether outdir is in fact a directory
    #
    $logger->fatal("$outdir is not a directory") if (!-d $outdir);

    #
    # verify whether outdir has write permissions
    #
    $logger->fatal("$outdir does not have write permissions") if ((-e $outdir) and (!-w $outdir));


    $logger->debug("outdir is set to:$outdir") if ($logger->is_debug());

    #
    # store the outdir in the environment variable
    #
    $ENV{OUTPUT_DIR} = $outdir;
    
    return $outdir;

}#end sub verify_and_set_outdir()


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


##------------------------------------------------------
## print_usage()
##
##------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -U username -P password -D database --database_type [-l log4perl] [-d debug_level] [-m] [-o outdir] -t type1 -u type2\n".
    " -U|--username            = Username\n".
    " -P|--password            = Password\n".
    " -D|--database            = Target chado database\n".
    " --database_type          = Relational database management system i.e. sybase or postgresql\n".
    " -l|--log4perl            = Log4perl log file (default: /tmp/bsmlScaffoldtransform.pl.log)\n".
    " -m|--man                 = Display pod2usage pages for this utility\n".
    " -h|--help                = Display pod2usage help screen.\n".
    " -o|--outdir              = Output directory for featureloc.out (Default is current directory)\n".
    " -d|--debug_level         = Coati::Logger log4perl logging level\n".    
    " -t|--type1               = Sequences with secondary type1 to which sequencess with secondary type2 are localized.  E.g.: type1: supercontig\n".
    " -u|--type2               = Sequences with secondary type2 must be localized to sequences with secondary type1. E.g.: type2: assembly\n";
    exit 1;

}

#-------------------------------------------------------
# checkFeatureCountsByType()
#
#-------------------------------------------------------
sub checkFeatureCountsByType {

    my ($prism, $type, $server, $database, $termname) = @_;

    my $count = $prism->featureCountBySecondaryType($type);

    if (!defined($count)){
	$logger->logdie("count was not defined for server '$server' database '$database' ".
			"type '$type' termname '$termname'");
    }

    if ($count == 0 ){
	$logger->warn("There were no sequences with secondary type '$termname' sequence (cvterm_id '$type') records in database '$database' ".
		      "on server '$server'");
	exit(2);
    }
    else {
	if ($count == 1){
	    print "Counted '$count' record where secondary type is '$termname' (cvterm_id = '$type')\n";
	}
	else {
	    print "Counted '$count' records where secondary type is '$termname' (cvterm_id = '$type')\n";
	}
    }
    
    return $count;
}

#-------------------------------------------------------
# checkFeaturelocCountsByTypes()
#
#-------------------------------------------------------
sub checkFeaturelocCountsByTypes {

    my ($prism, $type1, $type2, $server, $database, $termname1, $termname2) = @_;

    my $count = $prism->featurelocCountBySecondaryTypes($type1, $type2);

    if (!defined($count)){
	$logger->logdie("count was not defined for server '$server' database '$database' type1 '$type1' type2 '$type2'");
    }

    if ($count == 0 ){
	$logger->warn("No sequences with secondary type '$termname2' (cvterm_id '$type2') were localized to any ".
		      "sequences with secondary type '$termname1' (cvterm_id '$type1') in database '$database' ".
		      "on server '$server'");
	exit(2);
    }
    else {
	print "Counted '$count' sequences with secondary type '$termname2' (cvterm_id = '$type2') are localized to sequences with ".
	"secondary type '$termname1' (cvterm_id = '$type1').\n";
    }
    
    return $count;
}

#-------------------------------------------------------
# checkForNoLocalizations()
#
#-------------------------------------------------------
sub checkForNoLocalizations {

    my ($prism, $type1, $type2, $server, $database, $termname1, $termname2) = @_;

    my $count = $prism->noLocalizationsByTypes($type1, $type2);

    if (!defined($count)){
	$logger->logdie("count was not defined for server '$server' database '$database' type1 '$type1' type2 '$type2'");
    }

    if ($count == 0 ){
	print "All sequences with secondary type '$termname1' (type_id = '$type1') had some sequence with secondary type '$termname2' ".
	"(type_id = '$type2') localized to them.\n";
    }
    else {
	if ($count == 1){
	    print "One sequence with secondary type '$termname2' (cvterm_id = '$type2') had no sequences with secondary type '$termname1' ".
	    "(cvterm_id = '$type1') localized to it.\n";
	}
	else {
	    print "'$count' sequences with secondary type '$termname2' (cvterm_id = '$type2') had no sequences with secondary type '$termname1' ".
	    "(cvterm_id = '$type1') localized to them.\n";
	}
    }

    return $count;
}


#-------------------------------------------------------
# reportCounts()
#
#-------------------------------------------------------
sub reportCounts {

    my ($lookup1, $lookup2, $term1, $term2, $type1, $type2, $database, $server, $count1, $count2) = @_;

    my $seq1Count = keys(%{$lookup1});
    
    my $summary = "The number of sequences with secondary type '$term1' processed was '$seq1Count'.\n";
    
    if ($logger->is_debug()){

	$summary = "Here is a listing of the feature_id values for sequences with secondary type '$term1' (cvterm_id '$type1') ".
	"along with the number of their features that needed to be localized to sequences with secondary type '$term2' (cvterm_id '$type2'):\n";

	my $seq1FeatureCount=0;
	
	foreach my $seq1 ( keys %{$lookup1}){

	    $summary .= "$seq1\t\t$lookup1->{$seq1}\n";
	    
	    $seq1FeatureCount += $lookup1->{$seq1};
	}

	$summary .= "The number of their features that needed to be localized to sequences with secondary type '$term2' was '$seq1FeatureCount'\n";
    }

    my $seq2Count = keys(%{$lookup2});

    $summary .= "The number of sequences with secondary type '$term2' processed was '$seq2Count'.\n";

    if ($logger->is_debug()){
	
	$summary .= "Here is a listing of the feature_id values for sequences with secondary type '$term2' (cvterm_id '$type2') along with ".
	"the number of their features that needed to be localized to sequences with secondary type '$term1' (cvterm_id '$type1'):\n";
    
	my $seq2FeatureCount=0;

	foreach my $seq2 ( keys %{$lookup2}){

	    $summary .= "$seq2\t\t$lookup2->{$seq2}\n";
	
	    $seq2FeatureCount += $lookup2->{$seq2};
	}
	 
	$summary .= "The number of their features that needed to be localized to sequences with secondary type '$term1' was '$seq2FeatureCount'\n\n";
    }


    $logger->warn("$summary");
    
#     print  "In database '$database' on server '$server' where $termname2 sequences ".
#     "are localized to $termname1 sequences, the following numbers were counted: ".
#     "'$seq1FeatureCount' features were localized to '$seq1Count' $termname1 sequences ".
#     "and '$seq2FeatureCount features were localized to '$seq2Count' $termname2 sequences.\n";
    
    if ($count1 != $seq1Count){
	$logger->warn("The number of sequences with secondary type '$term1' (type_id '$type1') found in the database was '$count1', ".
		      "however the number of such sequences that were processed was '$seq1Count'.");
    }

    if ($count2 != $seq2Count){
	$logger->warn("The number of sequences with secondary type '$term2' (type_id '$type2') found in the database was '$count2', ".
		      "however the number of such sequences that were processed was '$seq2Count'");
    }

#    $logger->warn("$report");
}


##--------------------------------------------------------------------------
## generateLocalizationRecords()
##
##--------------------------------------------------------------------------
sub generateLocalizationRecords {
    
    my ($prism, $type1, $type2, $term1, $term2) = @_;

    ## Retrieve data for the localization of sequence type2 records to sequence type1 records.
    my $ret = $prism->localizationsAmongSequencesBySecondaryTypes($type1, $type2);

    ## $ret is a reference to a two dimensional array.
    ## Here is a description of the elements of the inner array:
    ## 0 => feature.feature_id // type2 
    ## 1 => feature.uniquename // type2
    ## 2 => feature.feature_id // type1
    ## 3 => feature.uniquename // type1
    ## 4 => featureloc.fmin    // type1 = srcfeature_id, type2 = feature_id, 
    ## 5 => featureloc.fmax    // type1 = srcfeature_id, type2 = feature_id, 
    ## 6 => featureloc.strand  // type1 = srcfeature_id, type2 = feature_id, 

    if (!defined($ret)){
	$logger->logdie("ret was not defined for type1 '$term1' (type_id '$type1') type2 '$term2' (type_id '$type2')");
    }

    ## Keep count of the number of featureloc records that are created by this program.
    my $featurelocCounter = 0;
    
    my $recctr = scalar(@{$ret});

    if ($recctr > 0 ) {
	## Some number of type 2 sequences are localized to some number of type 1 sequences giving us reason to proceed.

	if ($logger->is_debug()){
	    $logger->debug("Number of sequences with secondary type '$term2' (type_id '$type2') localized to sequences with ".
			   "secondary type '$term1' (type_id '$type1') was '$recctr'");
	}

	## Counter for the number of sequences of type 2 processed.
	my $seq2Ctr;

	print "Processing all records for sequences with secondary types '$term1' and '$term2' now\n";
	
	for ( $seq2Ctr = 0 ; $seq2Ctr < $recctr ; $seq2Ctr++ ) {

	    my $seq2FeatureId   = $ret->[$seq2Ctr][0];
	    my $seq2Uniquename  = $ret->[$seq2Ctr][1];
	    my $seq1FeatureId   = $ret->[$seq2Ctr][2];
	    my $seq1Uniquename  = $ret->[$seq2Ctr][3];
	    my $asm_fmin        = $ret->[$seq2Ctr][4];
	    my $asm_fmax        = $ret->[$seq2Ctr][5];
	    my $asm_strand      = $ret->[$seq2Ctr][6];

	    my $featureToType1Count = &createFeaturelocForType1($prism, $type1, $type2, $seq1FeatureId, $seq2FeatureId, $asm_fmin,
								$asm_fmax, $asm_strand, $term1, $term2, $seq1Uniquename, $seq2Uniquename);
	    $featurelocCounter += $featureToType1Count;

	    my $featureToType2Count = &createFeaturelocForType2($prism,	$type1, $type2, $seq1FeatureId, $seq2FeatureId, $asm_fmin,
								$asm_fmax, $asm_strand, $term1, $term2, $seq1Uniquename, $seq2Uniquename);
	    $featurelocCounter += $featureToType2Count;
	}

	return $featurelocCounter;
    }
    else {
	$logger->warn("No sequences with secondary type '$term2' (type_id '$type2') were localized to any sequences with secondary type '$term1' ".
		      "(type_id '$type1') in database '$database' on server '$server'");
	exit(10);
    }
}

##-------------------------------------------------
## createFeaturelocForType1()
##
##-------------------------------------------------
sub createFeaturelocForType1 {
    
    my ($prism, $type1, $type2, $seq1FeatureId, $seq2FeatureId, $asm_fmin,
	$asm_fmax, $asm_strand, $term1, $term2, $seq1Uniquename, $seq2Uniquename) = @_;


    my $ret = $prism->featureToSequenceSecondaryType2($type1, $type2, $seq1FeatureId, $seq2FeatureId, $asm_fmin, $asm_fmax);

    ## ret is a reference to a two dimensional array.  Here is a description of the elements of the inner array.
    ## 0 => feature.feature_id // subfeature
    ## 1 => featureloc.fmin
    ## 2 => featureloc.fmax
    ## 3 => featureloc.strand
    ## 4 => featureloc.phase
    ## 5 => featureloc.residue_info
    ## 6 => featureloc.rank

    if (!defined($ret)){
	$logger->logdie("ret was not defined for type1 '$type1' type2 '$type2' seq1 '$seq1FeatureId' uniquename '$seq1Uniquename' ".
			"seq2 '$seq2FeatureId' uniquename '$seq2Uniquename' fmin '$asm_fmin' fmax '$asm_fmax'");
    }
    
    my $recctr = scalar(@{$ret});

    $featureToType2Counts->{$seq2FeatureId} = $recctr;

    ## Keep count of the number of features that needed to be localized to the type1 sequence
    my $featureCtr = 0;

    if ($recctr > 0 ){
	
	for ( $featureCtr = 0; $featureCtr < $recctr ; $featureCtr++ ){

	    my $fmin         = $ret->[$featureCtr][1];
	    my $fmax         = $ret->[$featureCtr][2];
	    my $strand       = $ret->[$featureCtr][3];
	    
	    ($fmin, $fmax, $strand) = ($fmax, $fmin, -1) if($fmin > $fmax);
	    
	    $strand = 1 if($strand == 0);
	    
	    my $mapped_fmin; # fmin of feature with respect to the parent sequence
	    my $mapped_fmax; # fmax of feature with respect to the parent sequence
	    
	    if( $asm_strand == 1 ){
		$mapped_fmin = $asm_fmin + $fmin; # fmin of child sequence with respect to the parent + fmin of the feature with respect to the child
		$mapped_fmax = $asm_fmin + $fmax; # fmax of child sequence with respect to the parent + fmax of the feature with respect to the child
	    }
	    else{
		$mapped_fmin = $asm_fmax - $fmax;
		$mapped_fmax = $asm_fmax - $fmin;
	    }
	    
	    my $mapped_strand = 0;
	    
	    $mapped_strand =  1   if( $strand ==  1 && $asm_strand ==  1 );
	    $mapped_strand = -1   if( $strand ==  1 && $asm_strand == -1 );
	    $mapped_strand = -1   if( $strand == -1 && $asm_strand ==  1 );
	    $mapped_strand =  1   if( $strand == -1 && $asm_strand == -1 );
	    
	    if( $mapped_strand == 0 ){
		$logger->logdie("mapped_strand == 0 with ".
				"feature_id      '$ret->[$featureCtr][0]' ".
				"srcfeature_id   '$seq1FeatureId' ".
				"fmin            '$mapped_fmin' ".
				"is_fmin_partial '0' ".
				"fmax            '$mapped_fmax' ".
				"is_fmax_partial '0' ".
				"strand          '$mapped_strand' ".
				"phase           '$ret->[$featureCtr][4]' ".
				"residue_info    '$ret->[$featureCtr][5]' ".
				"locgroup        '1' ".
				"rank            '$ret->[$featureCtr][6]' ".
				"while processing seq1 uniquename '$seq1Uniquename' feature_id '$seq1FeatureId' ".
				"seq2 uniquename '$seq2Uniquename' feature_id '$seq2FeatureId' ");
	    }

	    
	    my $featureloc_id = $prism->{_backend}->do_store_new_featureloc(
									    feature_id        => $ret->[$featureCtr][0],
									    srcfeature_id     => $seq1FeatureId,
									    fmin              => $mapped_fmin,
									    is_fmin_partial   => 0,
									    fmax              => $mapped_fmax,
									    is_fmax_partial   => 0,
									    strand            => $mapped_strand,
									    phase             => $ret->[$featureCtr][4],
									    residue_info      => $ret->[$featureCtr][5],
									    locgroup          => 1,
									    rank              => $ret->[$featureCtr][6],
									    );
	    if (!defined($featureloc_id)){
		$logger->logdie("featureloc_id was not defined.  Could not create featureloc BCP record with ".
				"feature_id      '$ret->[$featureCtr][0]' ".
				"srcfeature_id   '$seq1FeatureId' ".
				"fmin            '$mapped_fmin' ".
				"is_fmin_partial '0' ".
				"fmax            '$mapped_fmax' ".
				"is_fmax_partial '0' ".
				"strand          '$mapped_strand' ".
				"phase           '$ret->[$featureCtr][4]' ".
				"residue_info    '$ret->[$featureCtr][5]' ".
				"locgroup        '1' ".
				"rank            '$ret->[$featureCtr][6]' ".
				"while processing seq1 uniquename '$seq1Uniquename' feature_id '$seq1FeatureId' ".
				"seq2 uniquename '$seq2Uniquename' feature_id '$seq2FeatureId' ");
	    }
	}
    }
    else {
	if ($logger->is_debug()){
	    $logger->debug("No features that are localized to type 2 '$term2' (type_id '$type2') sequence with feature_id ".
			   "'$seq2FeatureId' uniquename '$seq2Uniquename' need to be localized to sequence type 1 '$term1' (type_id '$type1') ".
			   "with feature_id '$seq1FeatureId' uniquename '$seq1Uniquename'");
	}
    }

    return $featureCtr;
}

##-------------------------------------------------
## createFeaturelocForType2()
##
##-------------------------------------------------
sub createFeaturelocForType2 {
    
    my ($prism, $type1, $type2, $seq1FeatureId, $seq2FeatureId, $asm_fmin,
	$asm_fmax, $asm_strand, $term1, $term2, $seq1Uniquename, $seq2Uniquename) = @_;

    my $ret = $prism->featureToSequenceSecondaryType1($type1, $type2, $seq1FeatureId, $seq2FeatureId, $asm_fmin, $asm_fmax);
    
    ## ret is a reference to a two dimensional array.  Here is a description of the elements of the inner array.
    ## 0 => feature.feature_id // subfeature
    ## 1 => featureloc.fmin
    ## 2 => featureloc.fmax
    ## 3 => featureloc.strand
    ## 4 => featureloc.phase
    ## 5 => featureloc.residue_info
    ## 6 => featureloc.rank

    if (!defined($ret)){
	$logger->logdie("ret was not defined for type1 '$type1' type2 '$type2' seq1 '$seq1FeatureId' uniquename '$seq1Uniquename' ".
			"seq2 '$seq2FeatureId' uniquename '$seq2Uniquename' fmin '$asm_fmin' fmax '$asm_fmax'");
    }
    
    my $recctr = scalar(@{$ret});

    $featureToType1Counts->{$seq1FeatureId} = $recctr;

    ## Keep count of the number of features that needed to be localized to the type1 sequence
    my $featureCtr = 0;

    if ($recctr > 0 ){
	
	for ( $featureCtr=0; $featureCtr < $recctr ; $featureCtr++ ){

	    my $fmin         = $ret->[$featureCtr][1];
	    my $fmax         = $ret->[$featureCtr][2];
	    my $strand       = $ret->[$featureCtr][3];
	    
	    ($fmin, $fmax, $strand) = ($fmax, $fmin, -1) if($fmin > $fmax);
	    
	    $strand = 1 if($strand == 0);
	    
	    my $mapped_fmin; # fmin of feature with respect to the child sequence
	    my $mapped_fmax; # fmax of feature with respect to the child sequence
	    
	    if( $asm_strand == 1 ){
		$mapped_fmin = $fmin - $asm_fmin;
		$mapped_fmax = $fmax - $asm_fmin;
	    }
	    else{
		$mapped_fmax = $asm_fmax - $fmin;
		$mapped_fmin = $asm_fmax - $fmax;
	    }
	    
	    my $mapped_strand = 0;
	    
	    $mapped_strand =  1   if( $strand ==  1 && $asm_strand ==  1 );
	    $mapped_strand = -1   if( $strand ==  1 && $asm_strand == -1 );
	    $mapped_strand = -1   if( $strand == -1 && $asm_strand ==  1 );
	    $mapped_strand =  1   if( $strand == -1 && $asm_strand == -1 );
	    
	    if( $mapped_strand == 0 ){
		$logger->logdie("mapped_strand == 0 for ".
				"feature_id      '$ret->[$featureCtr][0]' ".
				"srcfeature_id   '$seq2FeatureId' ".
				"fmin            '$mapped_fmin' ".
				"is_fmin_partial '0' ".
				"fmax            '$mapped_fmax' ".
				"is_fmax_partial '0' ".
				"strand          '$mapped_strand' ".
				"phase           '$ret->[$featureCtr][4]' ".
				"residue_info    '$ret->[$featureCtr][5]' ".
				"locgroup        '1' ".
				"rank            '$ret->[$featureCtr][6]' ".
				"while processing seq1 uniquename '$seq1Uniquename' feature_id '$seq1FeatureId' ".
				"seq2 uniquename '$seq2Uniquename' feature_id '$seq2FeatureId' ");
	    }
	    
	    my $featureloc_id = $prism->{_backend}->do_store_new_featureloc(
									    feature_id        => $ret->[$featureCtr][0],
									    srcfeature_id     => $seq2FeatureId,
									    fmin              => $mapped_fmin,
									    is_fmin_partial   => 0,
									    fmax              => $mapped_fmax,
									    is_fmax_partial   => 0,
									    strand            => $mapped_strand,
									    phase             => $ret->[$featureCtr][4],
									    residue_info      => $ret->[$featureCtr][5],
									    locgroup          => 1,
									    rank              => $ret->[$featureCtr][6],
									    );
	    if (!defined($featureloc_id)){
		$logger->logdie("featureloc_id was not defined.  Could not create featureloc BCP record with ".
				"feature_id      '$ret->[$featureCtr][0]' ".
				"srcfeature_id   '$seq2FeatureId' ".
				"fmin            '$mapped_fmin' ".
				"is_fmin_partial '0' ".
				"fmax            '$mapped_fmax' ".
				"is_fmax_partial '0' ".
				"strand          '$mapped_strand' ".
				"phase           '$ret->[$featureCtr][4]' ".
				"residue_info    '$ret->[$featureCtr][5]' ".
				"locgroup        '1' ".
				"rank            '$ret->[$featureCtr][6]' ".
				"while processing seq1 uniquename '$seq1Uniquename' feature_id '$seq1FeatureId' ".
				"seq2 uniquename '$seq2Uniquename' feature_id '$seq2FeatureId' ");
	    }
	}
    }
    else {
	if ($logger->is_debug()){
	    $logger->debug("No features that are localized to type 2 '$term2' (type_id '$type2') sequence with feature_id ".
			   "'$seq2FeatureId' uniquename '$seq2Uniquename' need to be localized to sequence type 1 '$term1' (type_id '$type1') ".
			   "with feature_id '$seq1FeatureId' uniquename '$seq1Uniquename'");
	}
    }

    return $featureCtr;
}
