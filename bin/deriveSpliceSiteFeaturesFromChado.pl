#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

deriveSpliceSiteFeaturesFromChado.pl - Derive splice site features from CDS and exon features in chado

=head1 SYNOPSIS

USAGE:  deriveSpliceSiteFeaturesFromChado.pl [--abbreviation] [--assembly_id] --database --database_type [--debug_level]  [-h] --id_repository [--logfile] [-m] [--outdir] --password --server --username

=head1 OPTIONS

=over 8

=item B<--abbreviation>

Optional - The organism.abbreviation value.  All assembly sequences that are linked to this organism will have their splice sites derived.

=item B<--assembly_id>

Optional - The assembly feature.uniquename for which all splice site features should be derived.  User can specify --assembly_id=all which will result in splice site derivations
           for all organisms, all assemblies.

=item B<--database>

The chado database from which exon, CDS, polypeptide feature data will be used to derived splice site features.

=item B<--database_type>

The relational database management system type e.g. sybase or postgresql.

=item B<--debug_level>

Optional -  Coati::Logger logging level.  Default is value is 0.

=item B<--help|h>

Optional - Display this information.

=item B<--id_repository>

IdGenerator compliant ID repository (must have valid_id_repository file).

=item B<--logfile>

Optional - Coati::Logger logfile (default is /tmp/deriveSpliceSiteFeaturesFromChado.pl)

=item B<--man|m>

Optional - Display the pod2usage page for this script.

=item B<--outdir,-o>

Optional - The output directory where the tab delimited BCP files will be written.  Default is current directory.

=item B<--password>

The database password.

=item B<--server>

The name of the server on which the database resides.

=item B<--username>

The username account for the database.

=back

=head1 DESCRIPTION

deriveSpliceSiteFeaturesFromChado.pl - Derives splice site features from- and to be loaded into the chado database

Assumptions:
1. User has appropriate permissions (to execute script, access chado database, write to output directory).
2. Target chado database already contains all reference features
3. Target chado database contains the necessary controlled vocabulary terms: "splice_site", "match_part", etc.
4. All software has been properly installed, all required libraries are accessible.

Sample usage:
mkdir idrep
touch idrep/valid_id_repository
perl -I shared -I Prism deriveSpliceSiteFeaturesFromChado.pl --username=sundaram --password=sundaram7 --database=apx3 --server=SYBTIGR --assembly_id=all --outdir=/tmp/ --id_repository=idrep/
perl -I shared -I Prism deriveSpliceSiteFeaturesFromChado.pl --username=sundaram --password=sundaram7 --database=apx3 --server=SYBTIGR --abbreviation=p_falciparum --outdir=/tmp/ --logfile=/tmp/my.log --id_repository=idrep


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

umask 0000;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($username, $password, $database, $server, $logfile, $debug_level, $help, $man, $outdir,
    $exonfile, $cdsfile, $assembly_id, $abbreviation, $database_type, $id_repository, $no_idgenerator,
    $idMappingFile, $idMappingDirectories, $batchsize, $verbose);

my $results = GetOptions (
			  'username=s'       => \$username, 
			  'password=s'       => \$password,
			  'database=s'       => \$database,
			  'server=s'         => \$server,
			  'logfile=s'        => \$logfile,
			  'debug_level=s'    => \$debug_level, 
			  'help|h'           => \$help,
			  'man|m'            => \$man,
			  'outdir=s'         => \$outdir,
			  'exonfile=s'       => \$exonfile,
			  'cdsfile=s'        => \$cdsfile,
			  'assembly_id=s'    => \$assembly_id,
			  'abbreviation=s'   => \$abbreviation,
			  'database_type=s'  => \$database_type,
			  'id_repository=s'  => \$id_repository,
			  'no_idgenerator=s' => \$no_idgenerator,
			  'id_mapping_file=s'=> \$idMappingFile,
			  'id_mapping_in_dirs=s' => \$idMappingDirectories,
			  'batchsize=s'          => \$batchsize,
			  'verbose'              => \$verbose
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
if (!defined($server)){
    print STDERR "server was not defined\n";
    $fatalCtr++;
}
if (!defined($database_type)){
    print STDERR "database_type was not defined\n";
    $fatalCtr++;
}

if ($fatalCtr>0){
    &print_usage();
}

## Get the Logfile logger
if (!defined($logfile)){
    $logfile = "/tmp/deriveSpliceSiteFeaturesFromChado.log";
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				 'LOG_LEVEL'=>$debug_level);


my $logger = Coati::Logger::get_logger(__PACKAGE__);


## Set the PRISM environmenatal variable
&setPrismEnv($server, $database_type);

## verify and set the output directory
$outdir = &verify_and_set_outdir($outdir);

## Make sure the specified id_repository exists
&check_id_repository($id_repository, $no_idgenerator);

#
# Instantiate Prism object
#
my $prism = new Prism(
		      user              => $username,
		      password          => $password,
		      db                => $database,
		      );

if (!defined($prism)){
    $logger->logdie("prism was not defined");
}

if (!defined($idMappingFile)){
    $idMappingFile = '/tmp/deriveSpliceSiteFeaturesFromChado.idmap';
    $logger->warn("User did not specify output ID mapping file so default was set '$idMappingFile'");
}

if (!defined($idMappingDirectories)){
    $idMappingDirectories = '/tmp/';
    $logger->warn("User did not specify directories that might contain input ID mapping ".
		  "files with extension '.idmap' so default was set '/tmp'.");
}


&checkInputParameters($assembly_id, $abbreviation);

my $assemblyFeatureIdList = $prism->assemblyFeatureIdListForSpliceSiteDerivations($assembly_id, $abbreviation);

my $assemblyCount = scalar(@{$assemblyFeatureIdList});

if ($assemblyCount > 0) {

    if (!defined($batchsize)){
	$batchsize = 400;
    }

    if ($assemblyCount > 1){
	print "Will process '$assemblyCount' assemblies in batches of '$batchsize'\n";
    }
    else {
	print "Processing the assembly now\n";
    }

    my $stopCodonLookup = $prism->allPolypeptidesWithStopCodonInResiduesForReverseStrandGenesLookup();

    $prism->loadIdMappingLookup($idMappingDirectories);

    my $sybase_time = $prism->get_sybase_datetime();
    
    if (!defined($sybase_time)){
	$logger->logdie("sybase_time was not defined");
    }
    
    ## Keep track of the number of BCP records created.
    my $recctr = 0;

    my $assemblyBatches = $prism->createInputBatches($batchsize, $assemblyFeatureIdList);

    ## Keep track of the number of batches processed
    my $batchCtr=0;

    ## Keep track of the number of splice site features created for each assembly
    my $assemblySpliceSiteCounter = {};

    foreach my $batch ( @{$assemblyBatches} ){

	$batchCtr++;

	print "Processing batch number '$batchCtr' (assemblies with feature_id from '$batch->[0]' to '$batch->[1]')\n";
    
	## Create exons lookup
	my $cdsToExonLookup = &getCDSToExonLookup($exonfile, $prism, $batch->[0], $batch->[1]);

	my @cdsToExonLookupList = sort(keys %{$cdsToExonLookup});
	my $cdsToExonLookupAssemblyCount = scalar(@cdsToExonLookupList);
	
	## Create CDS lookup
	my $cdslookup = &getCDSLookup($cdsfile, $prism, $batch->[0], $batch->[1]);
	my @cdsLookupList = sort(keys %{$cdslookup});
	my $cdsAssemblyCount = scalar(@cdsLookupList);

	if ($cdsToExonLookupAssemblyCount != $cdsAssemblyCount){
	    $logger->logdie("Number of assemblies for cdsToExonLookup '$cdsToExonLookupAssemblyCount' != number of assemblies for cdslookup '$cdsAssemblyCount'");
	}

	foreach my $assemblyFeatureId ( @cdsLookupList ){
	    
	    if ( exists $cdslookup->{$assemblyFeatureId} ){

		if (exists $cdsToExonLookup->{$assemblyFeatureId}){

		    print "Will derive splice site features for assembly with feature_id '$assemblyFeatureId'\n";

		    my $newRecCtr = $prism->deriveSpliceSiteFeatures($cdsToExonLookup->{$assemblyFeatureId},
								     $sybase_time,
								     $cdslookup->{$assemblyFeatureId},
								     $stopCodonLookup,
								     $assemblyFeatureId,
								     $verbose);

		    ## This total will be the number of records written to the final BCP file for feature
		    $recctr += $newRecCtr;

		    ## Keep track of the number of splice site features created for this assembly
		    $assemblySpliceSiteCounter->{$assemblyFeatureId} = $newRecCtr;
		    
#		    print "Created '$newRecCtr' feature and '$newRecCtr' featureloc records for assembly with feature_id '$assemblyFeatureId'\n";
		}
		else {
		    $logger->warn("feature_id '$assemblyFeatureId' did not exist in the cdsToExonLookup");
		}
	    }
	    else {
		$logger->warn("feature_id '$assemblyFeatureId' did not exist in the cdslookup");
	    }
	}
    }

    if ($recctr > 0 ){
	
	# Output the BCP out files
	$prism->{_backend}->output_tables($outdir);

	$prism->writeIdMappingFile($idMappingFile);

	if ($assemblyCount == 1){
	    print "Finished processing the assembly\n";
	}
	else {
	    print "Finished processing the '$assemblyCount' assemblies\n";
	}

	if ($verbose){
	    foreach my $asid ( keys %{$assemblySpliceSiteCounter} ){
		print "Created '$assemblySpliceSiteCounter->{$asid}' splice site features for assembly '$asid'\n";
	    }
	}


	if ($recctr == 1){
	    print "Created one feature record and one featureloc record\n";
	}
	else {
	    print "Created a total of '$recctr' feature records and '$recctr' featureloc records\n";
	}

	print "Tab-delimited BCP files were written to directory '$outdir'\n";
	print "Run flatFileToChado.pl to load these files' contents into database '$database'\n";
    }
}
else {
    $logger->warn("No assemblies to process");
}

print "$0 program execution has completed\n";
print "Log file is '$logfile'\n";
exit(0);

#-----------------------------------------------------------------------------------------------------
#
#       END OF MAIN  -- SUBROUTINES FOLLOW
#
#-----------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------
# getCDSToExonLookup()
#
#-------------------------------------------------------------------------
sub getCDSToExonLookup {

    my ($file, $prism, $firstAssemblyId, $lastAssemblyId) = @_;

    my $exons = {};

    if (defined($file)){

	open (INFILE, "<$file") or $logger->logdie("Could not open file '$file': $!");
	
	while (my $line = <INFILE>){
	    
	    chomp $line;

	    # 0 cds.uniquename
	    # 1 exon.fmin
	    # 2 exon.fmax
	    # 3 exon.uniquename
	    # 4 exon.strand
	    #
	    
	    my @cols = split(/\s+/, $line);
	    
	    ## Remove the first element (CDS uniquename) and store it in variable cdsid.
	    my $cdsid = shift(@cols);
	    
	    push(@{$exons->{$cdsid}}, \@cols);
	
	}
    }
    
    if (defined($firstAssemblyId)){
	if (defined($lastAssemblyId)){
	    
	    my $ret = $prism->exon_data_for_splice_site_derivation($firstAssemblyId, $lastAssemblyId);

	    my $count = scalar(@{$ret});

	    for (my $i=0; $i<$count; $i++){
	    
		my @array = ($ret->[$i][1], ## featureloc.fmin
			     $ret->[$i][2], ## featureloc.fmax
			     $ret->[$i][3], ## feature.uniquename (exon)
			     $ret->[$i][4]  ## featureloc.strand
			     );
		
		## keyed on assembly feature_id and then CDS feature.uniquename value: array for exon data
		push ( @{$exons->{$ret->[$i][5]}->{$ret->[$i][0]}}, \@array);
	    }
	}
	else {
	    $logger->logdie("last assembly identifier was not defined");
	}
    }
    else {
	$logger->logdie("first assembly identifier was not defined");
    }
    
    return $exons;
}

#--------------------------------------------------------------
# getCDSLookup()
#
#--------------------------------------------------------------
sub getCDSLookup {

    my ($cdsfile, $prism, $firstAssemblyId, $lastAssemblyId ) = @_;

    my $cdslookup;

    if (defined($cdsfile)){
	
	open (INFILE, "<$cdsfile") or $logger->logdie("Could not open file '$cdsfile' for input: $!");

	while (my $line = <INFILE>){
	    
	    chomp $line;
	    
	    my @array = split(/\s+/, $line);

	    push(@{$cdslookup}, \@array);
	}

    }

    if (defined($firstAssemblyId)){
	if (defined($lastAssemblyId)){
	    $cdslookup = $prism->cds_and_polypeptide_data_for_splice_site_derivation($firstAssemblyId, $lastAssemblyId);
	}
	else {
	    $logger->logdie("last assembly identifier was not defined");
	}
    }
    else {
	$logger->logdie("first assembly identifier was not defined");
    }

    return $cdslookup;

}

##------------------------------------------------------
## print_usage()
##
##------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -D database [-S server] -P password -U username [--abbreviation] [--assembly_id] [--cdsfile] [-d debug_level] [--exonfile] [-h] [-l logfile] [-m] [-o outdir]\n".
    "  -D|--database              = Target chado database\n".
    "  -S|--server                = Optional - Sybase server name e.g. SYBIL (Default is SYBTIGR)\n".
    "  -P|--password              = Password\n".
    "  -U|--username              = Username\n".
    "  --abbreviation             = Optional - organism.abbreviation\n".
    "  --assembly_id              = Optional - uniquename identifier of the assembly\n".
    "  --cdsfile                  = Optional - cdsfile (Must be defined if assembly_id is not defined)\n".
    "  -d|--debug_level           = Optional - Coati::Logger logfile logging level.  Default is 0\n".
    "  --exonfile                 = Optional - exonfile (Must be defined if assembly_id is not defined)\n".
    "  -h|--help                  = Optional - Display pod2usage help screen\n".
    "  -l|--logfile              = Optional - Logfile log file (default: /tmp/bsml2chado.pl.log)\n".
    "  -m|--man                   = Optional - Display pod2usage pages for this utility\n".
    "  -o|--outdir                = Optional - output directory for tab delimited BCP files (Default is current working directory)\n";
    exit 1;

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


    $ENV{PRISM} = $prismenv;
}

#-----------------------------------------------------------------------------------
# check_id_repository()
#
#-----------------------------------------------------------------------------------
sub check_id_repository {

    my ($id_repository, $no_idgenerator) = @_;

    if ((defined($no_idgenerator)) && ($no_idgenerator == 1)){
	$logger->info("User has specified --no_idgenerator=1 so will not use IdGenerator service");
	$ENV{NO_ID_GENERATOR} = 1;
    }

    if (defined($id_repository)){
	
	if (-e $id_repository){
	    
	    if (-w $id_repository){
		
		if (-r $id_repository){

		    $logger->info("setting _id_repository to '$id_repository'");
		    $ENV{ID_REPOSITORY} = $id_repository;
		}
		else{
		    $logger->warn("id_repository '$id_repository' does not have read permissions.  Using default ENV{ID_REPOSITORY} '$ENV{ID_REPOSITORY}'");
		}
	    }
	    else{
		$logger->warn("id_repository '$id_repository' does not have write permissions.  Using default ENV{ID_REPOSITORY} '$ENV{ID_REPOSITORY}'");
	    }
	}
	else{
	    $logger->warn("id_repository '$id_repository' does not exist.  Using default ENV{ID_REPOSITORY} '$ENV{ID_REPOSITORY}'");
	}
    }
    else {
	$logger->warn("id_repository '$id_repository' was not defined.  Using default ENV{ID_REPOSITORY} '$ENV{ID_REPOSITORY}'");
    }
}


sub checkInputParameters {
    my ($assembly_id, $abbreviation) = @_;

    if ((!defined($assembly_id)) && (!defined($abbreviation))){ 
	## Neither were defined, so we'll retrieve all qualifying assemblies.
	print "Neither --assembly_id nor --abbreviation were specified therefore will process all qualifying assembly records\n";
	$assembly_id = 'all';
    }
    else{
	if (defined($assembly_id)){
	    if ($assembly_id eq 'all'){
		print "--assembly_id='all' was specified therefore will attempt to process all qualifying assemblies\n";
	    }
	    else {
		if ($assembly_id =~ /,/){
		    print "--assembly_id='$assembly_id' was specified therefore will only attempt to process those assemblies\n";
		}
		else {
		    print "--assembly_id='$assembly_id' was specified therefore will only attempt to process that assembly\n"
		}
	    }
	}
	elsif (defined($abbreviation)){
	    print "--abbreviation='$abbreviation' was specified therefore will only attempt to process all qualifying assemblies related to the organism with that abbreviation\n";
	}	
    }
}
