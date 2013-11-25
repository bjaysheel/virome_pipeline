#!/usr/local/bin/perl
=head1 NAME
    
    fasta2bsml.pl
    
=head1 USAGE

    
=head1 OPTIONS

    REQUIRED

    OPTIONAL

=head1 DESCRIPTION

    The program will transform the multi-FASTA file created at the end of Shiliang's coronavirus gene prediction process, into a BSML file.

=head1 INPUT


=head1 OUTPUT

    BSML file containing gene models


=head1  CONTACT

    Jay Sundaram
    sundaram@jcvi.org

=begin comment

  ## legal values for status are active, inactive, hidden, unstable
  status: active

  keywords: coronavirus bsml

=end comment

=cut


use strict;
use Getopt::Long;
use Pod::Usage;
use File::Basename;
use Data::Dumper;
use BSML::BsmlBuilder;
use Ergatis::Logger;
use Ergatis::IdGenerator;
use Prism;

# set up options
my ($infile, $outfile, $logfile, $help, $man, $sequenceId, 
    $genus, $species, $strain, $database, $analysis, $taxon_id,
    $idGeneratorVersion, $programversion, $program, $sequenceClass,
    $sequenceTitle, $sequenceLength, $sequenceMolecule, $debug_level,
    $idRepository, $noSeqDataImports, $server, $database_type, $dbVendor,
    $username, $password);

&GetOptions(
	    'infile=s'      => \$infile,
	    'outfile=s'     => \$outfile,
	    'logfile=s'     => \$logfile,
	    'help|h'        => \$help,
	    'sequenceId=s'  => \$sequenceId,
	    'man|m'         => \$man,
	    'genus=s'       => \$genus,
	    'species=s'     => \$species,
	    'strain=s'      => \$strain,
	    'database=s'    => \$database,
	    'analysis=s'    => \$analysis,
	    'taxon_id=s'    => \$taxon_id,
	    'id-generator-version' => \$idGeneratorVersion,
	    'programversion=s' => \$programversion,
	    'program=s'        => \$program,
	    'sequence-class=s'    => \$sequenceClass,
	    'sequence-title=s'    => \$sequenceTitle,
	    'sequence-length=s'   => \$sequenceLength,
	    'sequence-molecule=s' => \$sequenceMolecule,
	    'debug_level=s'       => \$debug_level,
	    'id-repository=s'     => \$idRepository,
	    'no-seq-data-imports' => \$noSeqDataImports,
	    'server=s' => \$server,
	    'database_type=s' => \$database_type,
	    'username=s' => \$username,
	    'password=s' => \$password
	    );

##  Verify the command-line 
##  arguments and set default values.
&checkCommandLineArguments();

##  Open a filehandle for the logfile.
my $logger = &getLogger($logfile, $debug_level);

##  To keep track of the number of BSML elements created.
my $bsmlElementCtr={};

##  To keep track of the number of Sequence BSML elements created by class.
my $sequenceBsmlByClassCtr={};

##  To keep track of the number of Feature BSML elements created by class.
my $featureBsmlByClassCtr={};

##  Keep track of the number of FASTA records
##  processed (and added to the BSML).
my $fastaRecordCtr=0;

if (! &checkInfile($infile)){
    $logger->logdie("There was a problem with the input file '$infile'.  Please review the log file '$logfile'");
}

##  Instantiate BSML::BsmlBuilder so that we can
##  construct and write the BSML file.
my $bsmlBuilder = new BSML::BsmlBuilder();

($genus, $species) = &verifyGenusAndSpecies($genus, $species, $sequenceId, $server, $dbVendor, $database_type, $username, $password, $database);

my $genomeId = &addBsmlGenomeSectionToBsml($bsmlBuilder, $genus, $species, $strain, $taxon_id);

if (!defined($genomeId)){
    $logger->logdie("genomeId was not defined");
}

if (defined($analysis)){
    ##  If the analysis was specified, then need
    ##  to create the appropriate <Analysis> section.
    &addBsmlAnalysisSectionToBsml($bsmlBuilder, $analysis, $program, $programversion, $infile);
}

##  Instantiate Ergatis::IdGenerator so that we can
##  create typical BSML/chado identifiers.
my $idGenerator = new Ergatis::IdGenerator('id_repository' => $idRepository);

if (!defined($idGenerator)){
    $logger->logdie("idGenerator was not defined");
}

my $sequenceBSMLElem = &addBsmlSequenceSectionToBsml($bsmlBuilder, $genomeId, $sequenceId, $sequenceClass, $sequenceTitle, $sequenceLength, $sequenceMolecule);

if (!defined($sequenceBSMLElem)){
    $logger->logdie("sequenceBSMLElem was not defined");
}

my $featureTableBSMLElem = $bsmlBuilder->createAndAddFeatureTable($sequenceBSMLElem);

if (!defined($featureTableBSMLElem)){
    $logger->logdie("featureTableBSMLElem was not defined");
}

my $fastaLookup = &getFastaLookupFromFile($infile);

foreach my $header (sort keys %{$fastaLookup} ) {

    $fastaRecordCtr++;

    ##  Add gene model objects to the BSML tree.
    &addGeneModelSectionToBsml($bsmlBuilder, $header, $fastaLookup->{$header}, $idGenerator, $database, $idGeneratorVersion, $genomeId, $featureTableBSMLElem, $sequenceBSMLElem, $analysis);
}

if ($logger->is_debug()){
    $logger->debug("Processed '$fastaRecordCtr' FASTA records in file '$infile'");
}

##  Create the BSML output file.
$bsmlBuilder->write($outfile);


&reportCounts();

print "$0 program exection has completed\n";
print "The following BSML file has been created: $outfile\n";
print "The logfile is '$logfile'\n";
exit(0);

##-------------------------------------------------------------------------
##
##               END OF MAIN -- SUBROUTINES FOLLOW
##
##-------------------------------------------------------------------------

sub getLogger {

    my ($logfile, $debug_level) = @_;

    my $mylogger = new Ergatis::Logger('LOG_FILE'=>$logfile,
				       'LOG_LEVEL'=>$debug_level);
    
    return Ergatis::Logger::get_logger(__PACKAGE__);

}

sub checkCommandLineArguments {

    if ($help){
	&pod2usage( {-exitval => 1, -verbose => 2, -output => \*STDOUT} ); 
	exit(1);
    }
    
    my $fatalCtr=0;

    if (!$infile){
	print STDERR "infile was not specified\n";
	$fatalCtr++;
    }
    if (!$outfile){
	print STDERR "outfile was not specified\n";
	$fatalCtr++;
    }

    if (!$sequenceId){
	print STDERR "sequenceId was not specified\n";
	$fatalCtr++;
    }

    if ((!$genus) || (!defined($species))){

	if (!defined($username)){
	    print STDERR "--username must be specified since genus and/or species were not\n";
	    $fatalCtr++;
	}
	if (!defined($password)){
	    print STDERR "--password must be specified since genus and/or species were not\n";
	    $fatalCtr++;
	}
	if (!defined($server)){
	    print STDERR "--server must be specified since genus and/or species were not\n";
	    $fatalCtr++;
	}
	if ((!defined($database_type)) && (!defined($dbVendor))){
	    print STDERR "--database_type and/or --database-vendor must be specified since genus and/or species were not\n";
	    $fatalCtr++;
	}
    }

    if (!$database){
	print STDERR "database was not specified\n";
	$fatalCtr++;
    }

    if (!$idRepository){
	print STDERR "id-repository was not specified\n";
	$fatalCtr++;
    }

    if ($fatalCtr>0){
	die "Required command-line arguments were not specified";
    }

    if (!$sequenceClass){
	$sequenceClass = 'assembly';
	print STDERR "--sequence-class was not specified and therefore was set to '$sequenceClass'\n";
    }

    if (!defined($logfile)){
	$logfile = '/tmp/' . basename($0) . '.log';
	print STDERR "--logfile was not specified and therefore was set to '$logfile'\n";
    }

    if (!defined($noSeqDataImports)){
	$noSeqDataImports = 1;
	print STDERR "--no-seq-data-imports was not specified and therefore was set to '$noSeqDataImports'\n";
    }

}

sub checkInfile {

    my ($infile) = @_;
    if (!defined($infile)){
	print LOGFILE "infile was not defined\n";
	return 0;
    }
    if (!-e $infile){
	print LOGFILE "infile '$infile' does not exist\n";
	return 0;
    }
    if (!-r $infile){
	print LOGFILE "infile '$infile' does not have read permissions\n";
	return 0;
    }
    if (!-f $infile){
	print LOGFILE "infile '$infile' is not a regular file\n";
	return 0;
    }
    if (!-s $infile){
	print LOGFILE "infile '$infile' does not have any content\n";
	return 0;
    }

    return 1;
}


sub getFastaLookupFromFile {

    my ($infile) = @_;

    open(INFILE, "<$infile") || $logger->logdie("Could not open infile '$infile' in read mode:$!");

    my $lookup={};
    my $header;
    my $seq;
    my $first=1;
    my $headerctr=0;

    while (my $line = <INFILE>){
	chomp $line;
	if ($line =~ /^>(.+)/){
	    $header = $1;
	    $headerctr++;
	    if ($first){
		$first=0;
		next;
	    }
	    $seq =~ s/\s+//g;
	    $seq =~ s/\n+//g;
	    $lookup->{$header} = $seq;
	    $header=undef;	
	    $seq=undef;
	}
	else {
	    $seq.=$line;
	}
    }

    if ($logger->is_debug()){
	$logger->debug("FASTA lookup:" . Dumper $lookup);
    }

    $logger->info("Counted '$headerctr' FASTA headers in file '$infile'");

    return $lookup;
}

sub getFastaLookupFromFile_original {

    my ($infile) = @_;

    my $lookup={};

    open(INFILE, "<$infile") || $logger->logdie("Could not open infile '$infile' in read mode:$!");

    my @fileContents = <INFILE>;

    chomp @fileContents;

    my $allContents = join('', @fileContents);

    $allContents =~ s/\n//g;

    my @records = split(/>/, $allContents);

    foreach my $rec (@records ) {
	if ($rec eq ''){
	    next;
	}
	$rec =~ s/\s*$//;
	$lookup->{$rec} = 'ATGTGA';
    }
    print Dumper \@records;die;

    return $lookup;
}
sub addBsmlGenomeSectionToBsml {    
    
    my ($bsmlBuilder, $genus, $species, $strain, $taxon_id) = @_;

    my $genomeBSMLElem = $bsmlBuilder->createAndAddGenome();

    if (!defined($genomeBSMLElem)){
	$logger->logdie("Could not create <Genome> BSML element object for ".
			"with genus '$genus' species '$species' strain '$strain'");
    }

    if ((! exists $genomeBSMLElem->{'attr'}->{'id'} ) && (! defined ( $genomeBSMLElem->{'attr'}->{'id'} ) )  ){
	$logger->logdie("id for the <Genome> BSML element was not defined");
    }

    my $identifier = lc(substr($genus,0,1)) . '_' . lc($species);

    my $formatted_legacy_database_name  = 'JCVI_' . ucfirst($database);

    ## Store the legacy annotation database name as the primary BSML Cross-reference.
    &addBsmlCrossReferenceSectionToBsml($bsmlBuilder, $genomeBSMLElem, $database, $identifier, 'legacy_annotation_database');

    if (defined($taxon_id)){
	## Store the taxon identifier as a BSML Cross-reference
	&addBsmlCrossReferenceSectionToBsml($bsmlBuilder, $genomeBSMLElem, 'taxon', $taxon_id, 'current');
    }

    my $organismBSMLElem = $bsmlBuilder->createAndAddOrganism( 
							       'genome'  => $genomeBSMLElem,
							       'genus'   => $genus,  
							       'species' => $species,
							       );
    if (!defined($organismBSMLElem)){
	$logger->logdie("Could not create <Organism> element object for ".
			"genus '$genus' species '$species'");
    }

    ## All sequence will need to reference the <Genome> BSML id value.
    return $genomeBSMLElem->{'attr'}->{'id'};
}

sub addBsmlAnalysisSectionToBsml {

    my ($bsmlBuilder, $analysisName, $program, $programversion, $sourcename) = @_;

    if (!defined($sourcename)){
	$logger->logdie("sourcename was not defined");
    }

    my $analysisBSMLElem = $bsmlBuilder->createAndAddAnalysis( 'id' => $analysisName );
	
    if (!defined($analysisBSMLElem)){
	$logger->logdie("Could not create <Analysis> BSML element object for analysis '$analysisName'");
    }

    if (!defined($program)){
	$program = $analysisName;
	$logger->info("program was set to '$analysisName'");
    }
    if (!defined($programversion)){
	$programversion = '1.0';
	$logger->info("programversion was set to '$programversion'");
    }

    if (! &addBsmlAttributeToBsml($bsmlBuilder, $analysisBSMLElem, 'program', $program)){
	$logger->logdie("Could not add BSML <Attribute> element object ".
			"for name 'program' content '$program'");
    }

    if (! &addBsmlAttributeToBsml($bsmlBuilder, $analysisBSMLElem, 'programversion', $programversion)){
	$logger->logdie("Could not add BSML <Attribute> element object ".
			"for name 'programversion' content '$programversion'");
    }

    if (! &addBsmlAttributeToBsml($bsmlBuilder, $analysisBSMLElem, 'sourcename', $sourcename)){
	$logger->logdie("Could not add BSML <Attribute> element object ".
			"for name 'sourcename' content '$sourcename'");
    }
}

sub addBsmlAttributeToBsml {

    my ($bsmlBuilder, $bsmlElement, $name, $content) = @_;

    my $attributeBSMLElem = $bsmlBuilder->createAndAddBsmlAttribute( $bsmlElement, $name, $content);

    if (!defined($attributeBSMLElem)) {
	$logger->warn("Could not create <Attribute> BSML element for name '$name' content '$content'");
	return 0;
    }
    
    return 1;
}

sub addBsmlSequenceSectionToBsml {

    my ($bsmlBuilder, $genomeId, $sequenceId, $class, $title, $length, $molecule, $sequence) = @_;

    my $bsmlSequenceElem = $bsmlBuilder->createAndAddSequence($sequenceId, $title, $length, $molecule, $class);

    if (!defined($bsmlSequenceElem)){
	$logger->logdie("Could not create <Sequence> BSML element for sequenceId '$sequenceId'");
    }


    if (defined($sequence)){
	if ($noSeqDataImports){
	    my $seqDataBSMLElem = $bsmlBuilder->createAndAddSeqData($bsmlSequenceElem, $sequence);
	    if (!defined($seqDataBSMLElem)){
		$logger->logdie("Could not create <Seq-data> BSML element object for sequence with id '$sequenceId'");
	    }
	}
	else {
	    $logger->logdie("Operation not supported at this time.  Please contact sundaram\@jcvi.org.");
	}
    }


     if (defined($genomeId)){
	my $genomeBSMLLinkElem = $bsmlBuilder->createAndAddLink( $bsmlSequenceElem, 'genome', "#$genomeId" );
					   
	if (!defined($genomeBSMLLinkElem)){
	    $logger->logdie("Could not create a 'genome' <Link> BSML element object ".
			    "for <Sequence> with id '$sequenceId' where genomeId is '$genomeId'");
	}
    }

    return $bsmlSequenceElem;
}


sub addGeneModelSectionToBsml {

    my ($bsmlBuilder, $header, $sequence, $idGenerator, $database, $idGeneratorVersion, $genomeId, $featureTableBSMLElem, $sequenceBSMLElem, $analysis) = @_;

    ## Sample header:
    ## tgev.assembly.1.1.1     4017 Aa     304   12357        replicase

    my ($id, $length, $moleculeType, $fmin, $fmax, @geneNameArray) = split(/\s+/, $header);

    ## Convert to inter-base coordinate system for chado
    $fmin--;

    my $geneName = join(' ', @geneNameArray);
    
    print LOGFILE "id '$id' length '$length' moleculeType '$moleculeType' fmin '$fmin' fmax '$fmax' geneName '$geneName'\n";


    my $featureGroupBSMLElem;

    my $polypeptideId = $idGenerator->next_id( project => $database,
					       type    => 'polypeptide',
					       version => $idGeneratorVersion );
    if (!defined($polypeptideId)){
	$logger->logdie("polypeptideId was not defined for database '$database' type 'polypeptide' version '$idGeneratorVersion'");
    }

    my $polypeptideSeqId = $polypeptideId . '_seq';

    ##  Create the polypeptide related BSML sections
    my $polypeptideSequenceBSMLElem = &addBsmlSequenceSectionToBsml($bsmlBuilder, $genomeId, $polypeptideSeqId, 'polypeptide', undef, $length, $moleculeType, $sequence);

    &addBsmlAttributeToBsml($bsmlBuilder, $polypeptideSequenceBSMLElem, 'FASTA header', $header);

    foreach my $class ('gene', 'transcript', 'CDS', 'exon', 'polypeptide'){

	my $featureId;
	
	if ($class eq 'polypeptide'){
	    $featureId = $polypeptideId;
	}
	else {
	    $featureId = $idGenerator->next_id( project => $database,
						type    => $class,
						version => $idGeneratorVersion );
	    if (!defined($featureId)){
		$logger->logdie("featureId was not defined for database '$database' type '$class' version '$idGeneratorVersion'");
	    }
	}
	
	## Create a <Feature> element object with <Interval-loc> element object for this current feature
	my $featureBSMLElem = $bsmlBuilder->createAndAddFeatureWithLoc(
								       $featureTableBSMLElem,  # <Feature-table> element object reference
								       $featureId,             # id
								       undef,                # title
								       $class,               # class
								       undef,                # comment
								       undef,                # displayAuto
								       $fmin,                # start
								       $fmax,                # stop
								       0                     # complement
								       );

	if (!defined($featureBSMLElem)){
	    $logger->logdie("Could not create <Feature> BSML element object feature ".
			    "class '$class' fmin '$fmin' fmax '$fmax'"); 
	}

	## Store the original identifier as the primary BSML Cross-reference.
	&addBsmlCrossReferenceSectionToBsml($bsmlBuilder, $featureBSMLElem, $database, $id, 'FASTA header');
	
	if ($class eq 'gene'){
	    ##  Create the <Feature-group> BSML element object
	    $featureGroupBSMLElem = $bsmlBuilder->createAndAddFeatureGroup($sequenceBSMLElem, undef, $featureId);

	    if (!defined($featureGroupBSMLElem)){
		$logger->logdie("Could not create <Feature-group> BSML element object for gene ".
				"with id '$featureId' FASTA header id '$id' fmin '$fmin' fmax '$fmax'");
	    }
	}

	if (defined($featureGroupBSMLElem)){
	    ##  Create the <Feature-group-member> BSML element object
	    my $featureGroupMemberBSMLElem = $bsmlBuilder->createAndAddFeatureGroupMember($featureGroupBSMLElem, $featureId, $class);

	    if (!defined($featureGroupMemberBSMLElem)){
		$logger->logdie("Could not create <Feature-group-member> BSML element object ".
				"for feature with id '$featureId' class '$class' ".
				"fmin '$fmin' fmax '$fmax' FASTA header id '$id'");
	    }
	}

	if (defined($analysis)){
	    ##  Need to create <Link> BSML element object to link
	    ##  the <Feature> to the appropriate <Analysis>.
	    if (! &addBsmlLinkSectionToBsml($bsmlBuilder, $featureBSMLElem, 'analysis', $analysis)){
		$logger->logdie("Could not link Feature with id '$featureId' FASTA header id '$id' ".
				"fmin '$fmin' fmax '$fmax' to some <Analysis> with id '$analysis'");
	    }
	}

	if ($class eq 'polypeptide'){
	    ##  Need to add the <Link> BSML element object to link
	    ##  the polypeptide <Feature> to the corresponding <Sequence>.
	    if (! &addBsmlLinkSectionToBsml($bsmlBuilder, $featureBSMLElem, 'sequence', $polypeptideSeqId)){
		$logger->logdie("Could not link Feature with id '$featureId' FASTA header id '$id' ".
				"fmin '$fmin' fmax '$fmax' to corresponding <Sequence> with id '$polypeptideSeqId'");
	    }
	}

	if ($class eq 'transcript'){
	    if (! &addBsmlAttributeToBsml($bsmlBuilder, $featureBSMLElem, 'gene_product_name', $geneName)){
		$logger->logdie("Could not create an <Attribute> for <Feature> with id '$featureId' ".
				"FASTA header id '$id' fmin '$fmin' fmax '$fmax'");
	    }
	}
    }
}


sub reportCounts {

    print LOGFILE "Created the following number of Sequence BSML elements by class:\n";
    foreach my $class (sort keys %{$sequenceBsmlByClassCtr}){
	print LOGFILE "class '$class' count '$sequenceBsmlByClassCtr->{$class}'\n";
    }

    print LOGFILE "\n\nCreated the following number of Feature BSML elements by class:\n";
    foreach my $class (sort keys %{$featureBsmlByClassCtr}){
	print LOGFILE "class '$class' count '$featureBsmlByClassCtr->{$class}'\n";
    }

    print LOGFILE "\n\nCreated the following number of BSML elements by type:\n";
    foreach my $type (sort keys %{$bsmlElementCtr}){
	print LOGFILE "type '$type' count '$bsmlElementCtr->{$type}'\n";
    }

}


sub addBsmlCrossReferenceSectionToBsml {

    my ($bsmlBuilder, $bsmlElem, $database, $identifier, $identifierType) = @_;

    my $crossReferenceBSMLElem = $bsmlBuilder->createAndAddCrossReference(
									  'parent'          => $bsmlElem,
									  'id'              => ++$bsmlBuilder->{'xrefctr'},
									  'database'        => $database,
									  'identifier'      => $identifier,
									  'identifier-type' => $identifierType
									  );
    if (!defined($crossReferenceBSMLElem)){
	$logger->warn("Could not create <Cross-reference> BSML element object for ".
		      "database '$database' identifier '$identifier' ".
		      "identifier-type '$identifierType'");
	
	return 0;
    }
    
    return 1;
}


sub addBsmlLinkSectionToBsml {

    my ($bsmlBuilder, $bsmlElem, $type, $id) = @_;


    my $linkBSMLElem = $bsmlBuilder->createAndAddLink( $bsmlElem, $type, "#$id" );
					   
    if (!defined($linkBSMLElem)){
	$logger->warn("Could not create a <Link> BSML element object with type '$type' and id '\#$id'");
	return 0;
    }

    return 1;
}


sub verifyGenusAndSpecies {

    my ($genus, $species, $sequenceId, $server, $dbVendor, $database_type, $username, $password, $database) = @_;

    if ((!defined($genus)) || (!defined($species))){
	
	&setPrismEnv($server, $dbVendor, $database_type);

	my $prism = new Prism( user => $username, password => $password, db => $database );
	
	if (!defined($prism)){
	    $logger->logdie("prism was not defined");
	}

	my ($dgenus, $dspecies) = $prism->genusAndSpeciesByUniquename($sequenceId);
	
	if (defined($genus)){
	    if ($genus ne $dgenus){
		$logger->logdie("User specified genus '$genus' does not match database ".
				"derive genus '$dgenus' for sequence with id '$sequenceId'");
	    }
	}
	else {
	    $genus = $dgenus;
	}

	if (defined($species)){
	    if ($species ne $dspecies){
		$logger->logdie("User specified species '$species' does not match database ".
				"derive species '$dspecies' for sequence with id '$sequenceId'");
	    }
	}
	else {
	    $species = $dspecies;
	}
	
    }

    return ($genus, $species);
}

sub setPrismEnv {

    my ($server, $vendor, $database_type) = @_;

    if (!defined($server)){
	$logger->logdie("server was not defined");
    }
    if (!defined($vendor)){

	$vendor = &getVendor($database_type);

	if (!defined($vendor)){
	    $logger->logdie("vendor was not defined");
	}
    }

    ## We're overriding the env stored in conf/Prism.conf
    my $prismenv = "Chado:$vendor:$server";

    $ENV{PRISM} = $prismenv;
}

sub getVendor {

    my ($database_type) = @_;

    my $databaseTypeToBulkVendorLookup = { 'postgresql' => 'BulkPostgres',
					   'sybase' => 'BulkSybase',
					   'mysql' => 'BulkMysql',
					   'oracle' => 'BulkOracle' };

    if (exists $databaseTypeToBulkVendorLookup->{$database_type}){
	return $databaseTypeToBulkVendorLookup->{$database_type};
    }

    return undef;
}
