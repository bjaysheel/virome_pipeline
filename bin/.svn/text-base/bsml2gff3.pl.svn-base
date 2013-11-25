#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

bsml2gff3.pl - Parse BSML file and create GFF3 file

=head1 SYNOPSIS

USAGE:  bsml2gff3.pl --bsml_file_name [--debug_level] [--gff_file_name] [--gbrowse=1] [--help|h] [--keep_all_features=1] [--logfile] [--man|-m] [--outdir] [--preserve_types=1] --source [--translation_table] 

=head1 OPTIONS

=over 8

=item B<--bsml_file_name>

BSML file to be processed.

=item B<--debug_level>

Optional - Log4perl logging level.  Default is 0.

=item B<--gff_file_name>

Optional - GFF3 file to be written to.  Default is the --outdir/--bsml_file_name.gff3

=item B<--gbrowse>

Optional - Will alter behavior of the writer such that a Note attribute will be added wherever gene_product_name or description attributes are encountered to ensure compatibility with GBrowse

=item B<--help,-h>

Print this help

=item B<--keep_all_features>

Optional - If user specifies --keep_all_features=1, then all Features present in the BSML file will be written to the GFF3 file.  By default,
           only the following feature types will be written to the GFF3 file:
           gene, mRNA, CDS, rRNA, tRNA, snRNA, exon

=item B<--logfile>

Optional - The Log4perl log file.  Default is /tmp/bsml2gff3.pl.log.

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

bsml2gff3.pl - Parse BSML file and create GFF3 file

Assumptions:
1. User has appropriate permissions (to execute script, read the BSML file, write to output directory).
2. All software has been properly installed, all required libraries are accessible.

Sample usage:
./bsml2gff3.pl --bsml_file_name=/usr/local/scratch/sundaram/pva1.assembly.9.0.bsml --logfile=pva1.log --gff_file_name=pva1.gff3 --source=neisseria
./bsml2gff3.pl --bsml_file_name=/usr/local/scratch/sundaram/pva1.assembly.9.0.bsml --outdir=/usr/local/scratch/sundaram --source=neisseria

=head1 AUTHOR

Jay Sundaram
sundaram@tigr.org

=cut


use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use BSML::BsmlReader;
use BSML::BsmlParserSerialSearch;
use BSML::BsmlParserTwig;
use Coati::Logger;
use GFF3::GFF3Builder;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($bsmlFilename, $debugLevel, $help, $logfile, $man, $outdir, $gffFilename, $source,
    $preserveTypes, $keepAllFeatures, $translation_table, $gbrowse);

my $results = GetOptions (
			  'bsml_file_name=s'    => \$bsmlFilename, 
			  'debug_level=s'       => \$debugLevel,
			  'gff_file_name=s'     => \$gffFilename,
			  'gbrowse=s'           => \$gbrowse,
			  'help|h'              => \$help,
			  'logfile=s'           => \$logfile,
			  'man|m'               => \$man,
			  'outdir=s'            => \$outdir,
			  'source=s'            => \$source,
			  'preserve_types=s'    => \$preserveTypes,
			  'keep_all_features=s' => \$keepAllFeatures,
			  'translation_table=s' => \$translation_table
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

my $fatalCtr=0;

if (!defined($bsmlFilename)){
    print STDERR ("--bsml_file_name was not specified\n");
    $fatalCtr++;
}

if (!defined($source)){
    print STDERR ("--source was not specified\n");
    $fatalCtr++;
}
 
if ($fatalCtr>0){
    &print_usage();
}

if (!defined($logfile)){
    $logfile = '/tmp/bsml2gff3.pl.log';
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				 'LOG_LEVEL'=>$debugLevel);
## Get the Log4perl logger
my $logger = Coati::Logger::get_logger(__PACKAGE__);

if (defined($translation_table)){
    ## bsml2gff3 workflow component support where some value must be provided
    if (lc($translation_table) eq 'none'){
	$logger->warn("No default translation_table will be provided.  If bsml2gff3.pl cannot derive the ".
		      "value from the input BSML file '$bsmlFilename', then the execution of this script ".
		      "may be aborted prematurely.");
	$translation_table = undef;
    }
    else {
	$logger->warn("The user has specified a default translation_table value '$translation_table'. ".
		      "This value will only be applied if bsml2gff3.pl cannot derive the value from the ".
		      "input BSML file '$bsmlFilename'.");
    }
}
else {
    $logger->warn("No default translation_table will be provided.  If bsml2gff3.pl cannot derive the ".
		  "value from the input BSML file '$bsmlFilename', then the execution of this script ".
		  "may be aborted prematurely.");
}

if (!defined($gffFilename)){
    $gffFilename = &getGFFFilename($outdir, $bsmlFilename);
    $logger->info("Output GFF3 filename was not specified and so was set to '$gffFilename'");
}

my $gff3Builder = new GFF3::GFF3Builder( filename => $gffFilename,
					 source   => $source,
					 gbrowse => $gbrowse );
if (!defined($gff3Builder)){
    $logger->logdie("Could not instantiate GFF3::GFF3Builder for GFF3 file '$gffFilename");
}

## The feature and sequence classes in BSML need to be mapped to different types for GFF3
my $gffTypeMappingLookup = { 'assembly'   => 'contig',
			     'transcript' => 'mRNA' };

if ((defined($preserveTypes)) && ($preserveTypes == 1)) {
    $gffTypeMappingLookup = undef;
}
    
## GFF3 files are only supposed to contain the following feature types
my $gff3QualifiedFeatureTypes = { 'contig' => 1,
				  'gene'   => 1,
				  'CDS'    => 1,
				  'rRNA'   => 1,
				  'tRNA'   => 1,
				  'snRNA'  => 1,
				  'exon'   => 1,
				  'mRNA'   => 1  };


## Keep track of <Organism> data
my $genomeIdToOrganismLookup = {};

## The fastaLookup is a reference to a hash.
## The key is the sequence identifer/ FASTA header.
## The value is the FASTA sequence.
my $fastaLookup = {};

&parseBSMLFile( $bsmlFilename, $gff3Builder );

$gff3Builder->addHeader( 'gff-version', "3" );
$gff3Builder->addHeader( 'feature-ontology', "so.obo" );
$gff3Builder->addHeader( 'attribute-ontology', "gff3_attributes.obo" );

$gff3Builder->writeFile();

print "$0 program execution completed\n";
print "The logfile is '$logfile'\n";
print "GFF3 file has been created: '$gffFilename'\n";
exit(0);

##-------------------------------------------------------------------------------------------------------------------------
##
##                                END OF MAIN  -- SUBROUTINES FOLLOW
##
##-------------------------------------------------------------------------------------------------------------------------


##-------------------------------------------------------------------------
## parseBSMLFile()
##
##-------------------------------------------------------------------------
sub parseBSMLFile {

    my ($bsmlFilename, $gff3Builder) = @_;


    ## Notes.
    ## 1. Any sequence with a  <Sequence> element should have a record written at the head
    ##    of the GFF3 file with corresponding FASTA sequence written to the FASTA (tail section)
    ##    of the GFF3 file.
    ## 2. All feature relationship <Feature-group> will have to to transformed to appropriate
    ##    GFF3 Parent attributes.
    ## 3. The <Organism> and corresponding <Cross-reference> will have to be associated with
    ##    each Sequence GFF3 record.

    my $bsmlReader = new BSML::BsmlReader();
    if (!defined($bsmlReader)){
	$logger->logdie("bsmlReader was not defined while processing BSML file '$bsmlFilename'");
    }
    
    if ($logger->is_debug()){
	$logger->debug("Parsing BSML file '$bsmlFilename'");
    }
    print "Extracting data from BSML file '$bsmlFilename'\n";


    #-------------------------------------------------------------------------------------------------------------------------
    # Serially parse BSML docuemnt
    #
    # Step 1: Parser 1 (AnalysisCallBack)
    #
    # Step 2: Parser 2 (GenomeCallBack and SequenceCallBack):
    ##        Reads in all <Genome> components and caches the <Organism> data.
    ##        Reads in all <Sequence> elements and cachesand stores in memory.
    #
    # Step 3: Parser 3 (SeqFeatureCallBack):
    # 
    # Reads in all Feature elements
    # 1) for the first of the sibling Features, processes the parent Sequence (these are Sequence type2) which was buffered during the first parser.
    # 2) processes the Feature
    #
    #
    # Step 4: Processing Sequence type1 which do not contain nested Feature-tables
    #
    # Step 5: Parser 4 (MultipleAlignmentCallBack and AlignmentCallBack)
    #
    #
    # 2006-06-23
    # Clarification:
    # Sequence type 1: Do not have nested Feature-tables (e.g. CDS_seq)
    # Sequence type 2: Do have nested Feature-tables (e.g. assembly)
    # 
    # As of now, polypeptide_seq Sequences can be of type 2 since we are localizing
    # the splice_site Features to these Sequence types.
    #
    #-----------------------------------------------------------------------------------------------------------------------------------------------

    ## 2007-03-16 Read in all BSML Sequence elements for the purpose of 
    ## extracting the FASTA sequences.

    
    ## Keep track of the order in which <Sequence> elements were encountered.
    my $orderedSequenceList = [];

    ## Cache all <Sequence> data
    my $allSequenceLookup = {};
    
    ## Parse all <Genome> and <Organism> components.
    ## Parse and cache all <Sequence> compxonents.  
    ## Ignore all <Feature-table> components.
    my $bsmlParser = new BSML::BsmlParserSerialSearch( ReadFeatureTables => 0,
						       GenomeCallBack     => sub {
							   
							   my $bsmlGenome = shift;
							   
							   my $genomeId = $bsmlGenome->returnattr('id');
							   
							   if (!defined($genomeId)){
 							       $logger->logdie("The id was not defined for the BSML Genome while parsing BSML file '$bsmlFilename'");
							   }
							   
							   &getOrganismLookup($bsmlGenome, $genomeId, $genomeIdToOrganismLookup);
							   
						       },
						       SequenceCallBack  => sub {
							   
							   my $bsmlSequence = shift;
							   
							   ## This SequenceCallBack handler will parse all Sequence elements and 
							   ## cache all references in the allSequenceLookup.
							   ## These Sequences include:
							   ## 1) Type 1 Sequences ( those that do not have nested Feature-tables)
							   ## 2) Type 2 Sequences ( those that do have nested Feature-tables)
							   ##
							   ## For both types, there are regular Sequences and '_seq' Sequences.
							   ## The latter have identifiers with _seq suffix.
							   ## These Sequences are merely introduced into the BSML document as a 
							   ## means to associate some sort of sequence (amino acid or nucleotide)
							   ## to some Feature (since BSML does not provide a way to store sequences
							   ## in Feature BSML elements).
							   ## The data belonging to '_seq' Sequences are not fully processed and loaded
							   ## into the database.  Generally, this script only extracts the sequence
							   ## from the Seq-data or Seq-data-import and passes it on to the corresponding
							   ## Feature.
							   ## As of 2006-12-20 polypeptide '_seq' Sequences may have nested
							   ## Feature-tables for their signal-peptide Features.  These Sequences are
							   ## by definition: '_seq' Type 2 Sequences.
							   
							   my $id = $bsmlSequence->returnattr('id');
							   if (!defined($id)){
							       $logger->logdie("The id was not defined for BSML Sequence while processing BSML file '$bsmlFilename'");
							   }

							   ## Retrieves all nucleotide/aminoacid sequences from <Seq-data> and/or <Seq-data-import>
							   my $seqData = $bsmlReader->subSequence($bsmlSequence, -1, 0, 0);

							   if (defined($seqData)){

							       my $seqid = $id;
							       ## Trim off the _seq suffix.
							       $seqid =~ s/_seq$//; 
							       
							       $fastaLookup->{$seqid} = $seqData;
							   }
							   
							   push (@{$orderedSequenceList}, $id);

							   $allSequenceLookup->{$id} = $bsmlSequence;

						       });
    
    if (!defined($bsmlParser)){
	$logger->logdie("Could not instantiate BSML::BsmlParserSerialSearch");
    }
    
    print "Parsing <Genome> and <Organism> components.\n".
    "Parsing all <Sequence> elements for the purposes of extracting FASTA sequences.\n".
    "Reference to each BSML <Sequence> will be stored in a lookup for downstream processing.\n";
    
    $bsmlParser->parse($bsmlFilename);

    print "First scan of the BSML file has been completed.\n";


    my $featureToParentSequenceIdLookup = {};
    
    my $type2_seqSequencesToFeatureLookup = {};
    
    ## Cache all of the <Feature-group> data
    my $featureGroupArrayRef = [];

    ## Only store unique Feature-groupings
    my $uniqueFeatureGroupLookup = {};

    ## Keep track of whether the Sequence has already been processed
    my $processedSequencesLookup = {};
        
    print "Parsing all BSML <Sequence> elements that have associated <Feature-table> and <Feature> elements.\n".
    "Will also extract and cache all <Feature-group> data.\n".
    "All BSML <Sequence> elements with '_seq' suffix in the identifier will be cached and processed downstream.\n";

    $bsmlParser = new BSML::BsmlParserSerialSearch( SeqFeatureCallBack => sub {

	## This time parse all <Sequence> components that have nested <Feature-table> sections.

	my ($listref) = shift;

	my $bsmlSequence  = $listref->[1];
	if (!defined($bsmlSequence)){
	    $logger->logdie("bsmlSequence was not defined!");
	}

	## This is the primary identifier of the Sequence object
	my $sequence_id = $bsmlSequence->returnattr('id');
	if (!defined($sequence_id)){
	    $logger->logdie("sequence_id was not defined!");
	}

	my $bsmlFeature  = $listref->[0];
	if (!defined($bsmlFeature)){
	    $logger->logdie("bsmlFeature was not defined!");
	}
	
	## This is the primary identifier of the Feature object
	my $feature_id = $bsmlFeature->returnattr('id');
	if (!defined($feature_id)){
	    $logger->logdie("The id attribute was not defined for the BSML Feature while processing the Sequence with id '$sequence_id'");
	}

	## Store this relationship - important for processing potential subfeatures for this feature.
	$featureToParentSequenceIdLookup->{$feature_id} = $sequence_id;

	if ($sequence_id !~ /_seq$/){
	    ## only want to process the real Sequence objects like assembly, contig
	    ## and not Sequences that are Linked to some Feature like CDS, polypeptide
	    
	    if ( ! exists $processedSequencesLookup->{$sequence_id}) {

		&extractBsmlSequence($sequence_id, $gff3Builder, $allSequenceLookup->{$sequence_id});
		
		## Un-define all the Type 2 Sequences references in this allSequenceLookup.
		## We do not want to process these again when we process the Type 1 Sequences.
		delete $allSequenceLookup->{$sequence_id};

		# Remember that this Sequence was processed.
		$processedSequencesLookup->{$sequence_id}++;
	    }
	    
	    # Reference to list of all Features associated with this Type 2 Sequence
	    &extractBsmlFeatureLocalizedToSequence($feature_id, $bsmlFeature, $gff3Builder, $sequence_id);
	    
	}
	else {
	    ## At this point we are only storing Sequences that have a _seq suffix.
	    ## Since the SeqFeatureCallBack function will only parse Sequences that
	    ## have some Feature-table, we are therefore only storing Type 2 Sequences
	    ## in the type2_seqSequencesToFeatureLookup.
	    ## An example of the type of Sequence being stored here might be a 
	    ## polypeptide Sequence that contains a Feature-table having
	    ## splice_site and/or signal_peptide Features.
	    push (@{$type2_seqSequencesToFeatureLookup->{$sequence_id}}, $bsmlFeature);
	}
    },
						    SequenceCallBack => sub {
							
							my ($bsmlSequence) = shift;
							
							my $sequence_id = $bsmlSequence->returnattr('id');

							if (!defined($sequence_id)){
							    $logger->logdie("sequence_id was not defined!");
							}

							if (! exists $uniqueFeatureGroupLookup->{$sequence_id} ){
							    ## Haven't extracted and stored this Sequence's
							    ## Feature-group section yet.
							    push (@{$featureGroupArrayRef} , @{$bsmlSequence->{'BsmlFeatureGroups'}}); 
							    
							}
							
							## Make sure we don't extract and store this same Sequence's
							## Feature-group section again.
							$uniqueFeatureGroupLookup->{$sequence_id}++;
						    }
						    );


    if (!defined($bsmlParser)){
	$logger->logdie("Could not instantiate BSML::BsmlParserSerialSearch");
    }
    
    $bsmlParser->parse($bsmlFilename);

    print "Finished second scan of the BSML file.\n";


    print "Now processing all of the cached BSML <Sequence> elements that had '_seq' suffix in identifiers.\n";

    foreach my $sequence_id ( sort keys %{$type2_seqSequencesToFeatureLookup}){
	
	## These are the Sequences with '_seq' suffix having nested Feature-tables.
	## Typical examples are polypeptide Sequences that have nested signal_peptide and/or
	## splice_site Features that are localized to these polypeptide Sequences.

	&extractBsmlSequence($sequence_id, $gff3Builder, $allSequenceLookup->{$sequence_id});
		
	if (0) {
	    ## For now, not going to process the features (signal_peptide, splice_sites) that are 
	    ## localized to these sequences.
 
	    foreach my $bsmlFeature ( @{$type2_seqSequencesToFeatureLookup->{$sequence_id}}) {
		## Process each Feature that is localized to this Type 2 _seq Sequence!
		
		## trim off the _seq suffix
		$sequence_id =~ s/_seq$//;
		
		# Reference to list of all Features associated with this Type 2 Sequence
		&extractBsmlFeatureLocalizedToSequence($bsmlFeature->returnattr('id'),
						       $bsmlFeature,
						       $gff3Builder,
						       $sequence_id,
						       $featureToParentSequenceIdLookup);
	    }
	}

	## Remove this Type 2 _seq Sequence so that will not be processed again when we process
	## all of the Sequences that do not have any Feature-tables.
	delete $allSequenceLookup->{$sequence_id};

	# Remember that this Sequence was processed.
	$processedSequencesLookup->{$sequence_id}++;

    }

    ##----------------------------------------------------------------------------------------------
    ## Now need to process the remaining sequences in all_sequence_lookup.
    ## Types of Sequences that will be processed here include:
    ## 1) Sequences without '_seq' suffixes
    ## 2) Sequences with '_seq' suffixes that do not have nested Feature-tables
    ##
    ##----------------------------------------------------------------------------------------------
    print "Processing all cached <Sequence> elements that have '_seq' suffix, but no nested <Feature-table> elements\n".
    "and all cached <Sequence> elements that do not have '_seq' suffix in the identifier.\n";

    $logger->info("Processing all remaining Sequence type1 (these do not contain nested Feature-tables)");

    ## The order of the encountered Sequence elements must be preserved (bgz 2118).
    foreach my $sequence_id ( @{$orderedSequenceList} ){
	
	if ( exists $allSequenceLookup->{$sequence_id} ) {
	    
	    if ( exists $processedSequencesLookup->{$sequence_id} ) {
		## This Sequence was previously processed during this session. This check may be unnecessary.		
		if ($logger->is_debug()){
		    $logger->debug("We've already processed the BSML Sequence element with id '$sequence_id'");
		}
		
		next;
	    }

	    if (0){
		
		if ($sequence_id =~ /_seq$/){
		    ## We've finished processing the Sequence elements with nested Feature-table elements AND
		    ## we've already extracted the FASTA sequences (Seq-data-import) from ALL Sequence elements.
		    ## So if this is a Sequence with id like '_seq', we're just going to skip it.
		    if ($logger->is_debug()){
			$logger->debug("Skipping BSML Sequence with id '$sequence_id'");
		    }
		    
		    next;
		}
	    }
	    
	    &extractBsmlSequence($sequence_id, $gff3Builder, $allSequenceLookup->{$sequence_id});	    

	    if (0){
		## This is no longer necessary at this point.

		## Un-define all the Sequences of type 1
		delete $allSequenceLookup->{$sequence_id};
	    }


	    ## Remember that this Sequence was processed.
	    $processedSequencesLookup->{$sequence_id}++;
	    
	    
	}
    }

    print "Finished parsing BSML file '$bsmlFilename'\n";

    &processFeatureGroups($featureGroupArrayRef, $gff3Builder);

    if ((!defined($keepAllFeatures)) || ($keepAllFeatures == 0 )){
	&removeUnqualifiedFeatures($gff3Builder);
    }
}


##-------------------------------------------------------------
## storeBsmlAttributesAsAttributes()
##
##-------------------------------------------------------------
sub storeBsmlAttributesAsAttributes {

    my ($gff3Record, $bsmlAttributes) = @_;

    my $attributeNameLookup = { 'gene_product_name' => 'description' };

    foreach my $key ( keys %{$bsmlAttributes} ) {
	foreach my $value ( @{$bsmlAttributes->{$key}} ){
	    if (exists $attributeNameLookup->{$key}){
		$gff3Record->addAttribute($attributeNameLookup->{$key}, $value);
	    }
	    else {
		$gff3Record->addAttribute($key, $value);
	    }
	}
    }
}


##-------------------------------------------------------------
## storeBsmlAttributeListAsAttributes()
##
##-------------------------------------------------------------
sub storeBsmlAttributeListAsAttributes {

    my ($gff3Record, $bsmlAttributeLists) = @_;
    
    foreach my $arrays ( @{$bsmlAttributeLists} ) {
	## For now, only extracting the data in the first
	## BSML <Attribute> under each <Attribute-list>.
	my $array = $arrays->[0];

	$gff3Record->addAttribute($array->{'name'}, $array->{'content'});
    }
}

##-------------------------------------------------------------
## storeBsmlCrossReferencesAsAttributes()
##
##-------------------------------------------------------------
sub storeBsmlCrossReferencesAsAttributes {

    my ($gffRecord, $id, $bsmlCrossReferences) = @_;

    foreach my $bsmlCrossReference ( @{$bsmlCrossReferences} ) {

	my $database = $bsmlCrossReference->returnattr('database');
	if (!defined($database)){
	    $logger->logdie("database attribute was not defined for <Cross-reference> for BSML element with id '$id'");
	}

	my $identifier = $bsmlCrossReference->returnattr('identifier');
	if (!defined($identifier)){
	    $logger->logdie("identifier attribute was not defined for <Cross-reference> for BSML element with id '$id'");
	}

	$gffRecord->addAttribute('Dbxref', "$database:$identifier");
    }
}


##-------------------------------------------------------------
## storeOrganismDataAsAttributes()
##
##-------------------------------------------------------------
sub storeOrganismDataAsAttributes {

    my ($gff3Record, $genome_id) = @_;

    if (!defined($gff3Record)){
	$logger->logdie("gff3Record was not defined");
    }

    if (!defined($genome_id)){
	$logger->logdie("genome_id was not defined");
    }

    foreach my $key ( keys %{$genomeIdToOrganismLookup->{$genome_id}} ){
	foreach my $value ( @{$genomeIdToOrganismLookup->{$genome_id}->{$key}} ){
	    $gff3Record->addAttribute($key, $value);
	}
    }
}


##-------------------------------------------------------------
## getOrganismLookup()
##
##-------------------------------------------------------------
sub getOrganismLookup {

    my ($bsmlGenome, $genomeId, $organismLookup) = @_;

    if (! exists $organismLookup->{$genomeId} ){
	
	## Process the Organism
	if ( exists $bsmlGenome->{'BsmlOrganism'} ){

	    my $bsmlOrganism = $bsmlGenome->{'BsmlOrganism'};

	    my $genus = $bsmlOrganism->returnattr('genus');
	    if (!defined($genus)){
		$logger->logdie("genus was not defined for BSML Organism");
	    }

	    my $species = $bsmlOrganism->returnattr('species');
	    if (!defined($species)){
		$logger->logdie("species was not defined for BSML Organism");
	    }

	    push(@{$organismLookup->{$genomeId}->{'organism_name'}},  "$genus $species");

	    ## Process the Organism Attributes
	    if ( exists $bsmlOrganism->{'BsmlAttr'} ){
	      foreach my $key ( keys %{$bsmlOrganism->{'BsmlAttr'}} ){
		foreach my $value ( @{$bsmlOrganism->{'BsmlAttr'}->{$key}} ) {
		  push(@{$organismLookup->{$genomeId}->{$key}}, $value);
		}
	      }
	    }

	}
	else {
	    $logger->logdie("There does not exist any BSML Organism for the BSML Genome with id '$genomeId'");
	}
	
	## Process the Attributes
	if ( exists $bsmlGenome->{'BsmlAttr'} ){
	    foreach my $key ( keys %{$bsmlGenome->{'BsmlAttr'}} ){
		foreach my $value ( @{$bsmlGenome->{'BsmlAttr'}->{$key}} ) {
		    push(@{$organismLookup->{$genomeId}->{$key}}, $value);
		}
	    }
	}
	

	## Process the Cross-reference section
	if ( exists $bsmlGenome->{'BsmlCrossReference'} ){
	    if (scalar(@{$bsmlGenome->{'BsmlCrossReference'}}) > 0) {

		foreach my $bsmlCrossReference  ( @{$bsmlGenome->{'BsmlCrossReference'}} ){
		    my $database = $bsmlCrossReference->returnattr('database');
		    if (!defined($database)){
			$logger->logdie("The database attribute was not defined for BSML ".
					"Cross-reference for Genome with id '$genomeId'");
		    }

		    my $identifier = $bsmlCrossReference->returnattr('identifier');
		    if (!defined($identifier)){
		      $logger->logdie("The identifier attribute was not defined for BSML ".
				      "Cross-reference for Genome with id '$genomeId'");
		    }
		    $identifier =~ s/^\s*//; ## remove leading white space
		    $identifier =~ s/\s*$//; ## remove trailing white space

		    my $identifier_type = $bsmlCrossReference->returnattr('identifier-type');
		    if (!defined($identifier_type)){
		      $logger->logdie("The identifier-type attribute was not defined for BSML ".
				      "Cross-reference for Genome with id '$genomeId' ".
				      "with database '$database' identifier '$identifier'");
		    }

		    if ($identifier_type eq 'taxon_id'){
		      $database = 'taxon';
		    }

		    push(@{$organismLookup->{$genomeId}->{'Dbxref'}}, "$database:$identifier");

		}
	    }
	}


    }
    else  {
	$logger->logdie("Encountered the same Genome with genomeId '$genomeId' already");
    }
}


##-------------------------------------------------------------
## processFeatureGroups()
##
##-------------------------------------------------------------
sub processFeatureGroups {

    my ($featureGroups, $gff3Builder ) = @_;

    ## We process the Feature-groups for two reasons.
    ## 1) All of the polypeptide FASTA sequences must be transferred
    ##    to their corresponding CDS parents.
    ## 2) Most of the features must be assigned a Parent attribute in
    ##    the attribute section of the GFF3 records.  Parentage will be
    ##    based on the feature-groupings cited in the BSML file and
    ##    the following rules of association.
    
    my $childToParentRules = { 'mRNA' => 'gene',
			       'CDS'  => 'mRNA',
			       'cds'  => 'mRNA',
			       'exon' => 'mRNA',
			       'transcript' => 'gene',
			       'CDS'  => 'transcript',
			       'cds'  => 'transcript',
			       'exon' => 'transcript',
			       'signal_peptide' => 'polypeptide',
			       'splice_site' => 'polypeptide',
			   };
    
    foreach my $group ( @{$featureGroups} ) {

	for (my $i=0; $i < scalar(@{$group->{'BsmlFeatureGroupMembers'}}); $i++ ){
		    
	    for (my $j = $i + 1; $j < scalar(@{$group->{'BsmlFeatureGroupMembers'}}); $j++){

		my $type1 = $group->{'BsmlFeatureGroupMembers'}->[$i]->{'feature-type'};
		my $type2 = $group->{'BsmlFeatureGroupMembers'}->[$j]->{'feature-type'};

		my $uniquename1 = $group->{'BsmlFeatureGroupMembers'}->[$i]->{'feature'};
		my $uniquename2 = $group->{'BsmlFeatureGroupMembers'}->[$j]->{'feature'};

		if (($type1 eq 'polypeptide') &&
		    (uc($type2) eq 'CDS')){
		    &transferFastaBetweenRecords($gff3Builder, $uniquename1, $uniquename2);
		}

		if (($type2 eq 'polypeptide') &&
		    (uc($type1) eq 'CDS')){
		    &transferFastaBetweenRecords($gff3Builder, $uniquename2, $uniquename1);
		}

		if (( exists $childToParentRules->{$type1} ) &&
		    ( $childToParentRules->{$type1} eq $type2 )) {
		    ## The first feature is a child feature of the second feature.

		    my $gff3Record = $gff3Builder->getRecordById($uniquename1);
		    if (!defined($gff3Record)){
			$logger->warn("Could not retrieve GFF3Record with id '$uniquename1' so will not be able to add attribute Parent=$uniquename2");
		    }
		    else {
			$gff3Record->addParent($uniquename2);
		    }
		}
		
		if (( exists $childToParentRules->{$type2} ) &&
		    ( $childToParentRules->{$type2} eq $type1 )) {
		    ## The second feature is a child feature of the first feature.

		    my $gff3Record = $gff3Builder->getRecordById($uniquename2);
		    if (!defined($gff3Record)){
			$logger->warn("Could not retrieve GFF3Record with id '$uniquename2' so will not be able to add attribute Parent=$uniquename1");
		    }
		    else {
			$gff3Record->addParent($uniquename1);
		    }
		}

	    }
	}
    }
}

##----------------------------------------------------------------
## transferFastaBetweenRecords()
##
##----------------------------------------------------------------
sub transferFastaBetweenRecords {

    my ($gff3Builder, $uniquename1, $uniquename2) = @_;

    if ($gff3Builder->doesRecordExist($uniquename1)){

	if ($gff3Builder->doesRecordExist($uniquename2)){

	    my $gff3Record = $gff3Builder->getRecordById($uniquename1);

	    if ($gff3Record->hasFasta()){

		my $fastaSequence = $gff3Builder->extractFastaSequenceFromRecord($uniquename1);
		if (!defined($fastaSequence)){
		    
		    if ($gff3Builder->doesRecordExist($uniquename1)){
			$logger->fatal("gffrecord with id '$uniquename1' exists");
		    }
		    my $jay = $uniquename1 . '_seq';
		    if ($gff3Builder->doesRecordExist($jay)){
			$logger->fatal("gffrecord with id '$jay' exists");
		    }
		    $logger->logdie("fastaSequence was not defined for GFF3Record with id '$uniquename1'");
		}
		
		$gff3Builder->addFastaSequenceToRecord($uniquename2, $fastaSequence);
	    }
	    else {
		$logger->warn("GFF3Record with id '$uniquename1' does not have FASTA sequence");
	    }
	}
	else {
	    $logger->logdie("GFF3Record does not exist for record with id '$uniquename2'");
	}
    }
    else {
	$logger->logdie("GFF3Record does not exist for record with id '$uniquename1'");
    }
    
}

##----------------------------------------------------------------
## extractBsmlFeatureLocalizedToSequence()
##
##----------------------------------------------------------------
sub extractBsmlFeatureLocalizedToSequence {

    my ($feature_id, $bsmlFeature, $gff3Builder, $sequence_id, $featureToParentSequenceIdLookup) = @_;

    if (!defined($feature_id)){
	$logger->logdie("id was not defined for Feature while processing the Sequence with id '$sequence_id'");
    }

    if (!defined($bsmlFeature)){
	$logger->logdie("bsmlFeature was not defined while processing Sequence with identifier '$sequence_id'");
    }

    if (!defined($gff3Builder)){
	$logger->logdie("gff3Builder was not defined");
    }

    if (!defined($sequence_id)){
	$logger->logdie("sequence_id was not defined");
    }

    my $class = $bsmlFeature->returnattr('class');
    if (!defined($class)){
	$logger->logdie("class was not defined for Feature with id '$feature_id' ".
			"while processing the Sequence with ide '$sequence_id'");
    }
    ## Check whether the class needs to be mapped to a GFF3 type
    if ( exists $gffTypeMappingLookup->{$class}){
	$class = $gffTypeMappingLookup->{$class};
    }

    my ($start, $stop, $strand) = &getLocalizationForFeature($feature_id, $bsmlFeature);

    if ( $gff3Builder->doesRecordExist($feature_id) ) {
	$logger->logdie("Already created a GFF3::GFF3Record for Feature with id '$feature_id'");
    }
    
    my $gff3Record = $gff3Builder->createAndAddRecord($feature_id, ## id
						      undef,       ## seqid
						      undef,       ## source
						      $class,      ## type
						      $start,      ## start
						      $stop,       ## stop
						      undef,       ## score
						      $strand,     ## strand
						      undef        ## phase
						      );
    if (!defined($gff3Record)){
	$logger->logdie("Could not instantiate GFF3::GFF3Record for Feature with id '$feature_id'");
    }

    $gff3Builder->linkFeatureToSequence($sequence_id, $gff3Record);

    &storeBsmlAttributesAsAttributes($gff3Record, $bsmlFeature->{'BsmlAttr'});
    
    &storeBsmlAttributeListAsAttributes($gff3Record, $bsmlFeature->{'BsmlAttributeList'});
    
    &storeBsmlCrossReferencesAsAttributes($gff3Record, $feature_id, $bsmlFeature->{'BsmlCrossReference'});
}

##----------------------------------------------------------------
## storeFeatureToSequenceLink()
##
##----------------------------------------------------------------
sub storeFeatureToSequenceLink {

    my ($featureId, $bsmlFeature, $featureToSequenceLink) = @_;

    if ( $bsmlFeature->hasBsmlLink() ) {
	
	my $sequenceId = $bsmlFeature->getBsmlLinkHrefByRel('sequence');
	
	if (defined($sequenceId)){
	    $featureToSequenceLink->{$featureId} = $sequenceId;
	}
    }
}

##----------------------------------------------------------------
## getLocalizationForFeature()
##
##----------------------------------------------------------------
sub getLocalizationForFeature {

    my ($featureId, $bsmlFeature, $sequence_id) = @_;

    if (!defined($featureId)){
	$logger->logdie("featureId was not defined");
    }
    if (!defined($bsmlFeature)){
	$logger->logdie("bsmlFeature was not defined");
    }
    
    my $start;
    my $stop;
    my $complement;

    if ( $bsmlFeature->hasSiteLoc() ){

	$start = $bsmlFeature->getFirstSiteLocSitePos();

	$stop = $start;

	$complement = $bsmlFeature->getFirstSiteLocComplement();
    }
    elsif ( $bsmlFeature->hasIntervalLoc() ){

	$start = $bsmlFeature->getFirstIntervalLocStartPos();

	$stop = $bsmlFeature->getFirstIntervalLocEndPos();

	$complement = $bsmlFeature->getFirstIntervalLocComplement();
    }
    else {
	$logger->warn("Found a Feature with identifier '$featureId' with no localization data while processing the Sequence ".
		      "with identifier '$sequence_id'");
    }
    

    my $strand = '+';
    if ($complement == 1){
	$strand = '-';
    }

    # +1 to convert from chado/bsml interbase coordinates to the base coordinates required in GFF3
    # see http://www.sequenceontology.org/gff3.shtml
    return ($start+1, $stop, $strand);


}

##----------------------------------------------------------------
## extractBsmlSequence()
##
##----------------------------------------------------------------
sub extractBsmlSequence {	

    my ($sequence_id, $gff3Builder, $bsmlSequence) = @_;
    
    if (!defined($sequence_id)){
	$logger->logdie("sequence_id was not defined");
    }
    if (!defined($gff3Builder)){
	$logger->logdie("gff3Builder was not defined");
    }
    if (!defined($bsmlSequence)){
	$logger->logdie("bsmlSequence was not defined");
    }

    my $class = $bsmlSequence->returnattr('class');
    if (!defined($class)){
	$logger->logdie("The class attribute was not defined for BSML Sequence with id '$sequence_id'");
    }
    ## Check whether the class needs to be mapped to a GFF3 type
    if ( exists $gffTypeMappingLookup->{$class}){
	$class = $gffTypeMappingLookup->{$class};
    }

    my $length = $bsmlSequence->returnattr('length');
    if (!defined($length)){
	$logger->warn("The length attribute was not defined for BSML Sequence with id '$sequence_id'");
	$length = 0;
    }

    my $topology = $bsmlSequence->returnattr('topology');
    if (!defined($topology)){
	if ($logger->is_debug()){
	    $logger->debug("The topology attribute was not defined for BSML Sequence with id '$sequence_id'");
	}
    }
    else {
	## Store the topology as a BSML Attribute instead of an XML attribute.
	$bsmlSequence->addBsmlAttr('topology', $topology);
    }

    my $genomeId = $bsmlSequence->getBsmlLinkHrefByRel('genome');
    if (!defined($genomeId)){
	$logger->warn("Could not extract genomeId from BSML Link for BSML Sequence with id '$sequence_id'");
    }
    
    ## trim off the _seq suffix
    my $fsequence_id = $sequence_id;
    $fsequence_id =~ s/_seq$//;
    
    my $gff3Record;
    
    ## If a GFF3Record already exists for this object, that means we 
    if ( $gff3Builder->doesRecordExist($fsequence_id)){
	$gff3Record = $gff3Builder->getRecordById($fsequence_id);
	
	## This Sequence with '_seq' suffix has a Feature that was nested in some other
	## Sequence's (e.g. assembly or contig) Feature-table.  The corresponding Feature
	## was processed earlier when the assembly or contig was processed.  A GFF3Record
	## was created for this '_seq' Sequence at that time.
	## Now we are going to extract any additional information that is associated with
	## the '_seq' Sequence and add it to the same GFF3Record.
	if (exists $fastaLookup->{$fsequence_id} ){
	    my $fasta = $fastaLookup->{$fsequence_id};
	    $gff3Builder->addFastaSequenceToRecord($fsequence_id, $fasta);
	}

	&storeBsmlCrossReferencesAsAttributes($gff3Record, $fsequence_id, $bsmlSequence->{'BsmlCrossReference'});

    }
    else {
	## This is a regular Sequence element.

	if ( $gff3Builder->doesRecordExist($sequence_id) ) {
	    ## This Sequence already has a corresponding GFF3Record.
	    $gff3Record = $gff3Builder->getRecordById($sequence_id);
	}
	else {
	    ## This Sequence does not yet have a corresponding GFF3Record.
	    $gff3Record = $gff3Builder->createAndAddRecord( $sequence_id, ## id
							    $sequence_id, ## seqid
							    undef,        ## source
							    $class,       ## type
							    1,            ## start
							    $length,      ## stop
							    undef,        ## score
							    '+',          ## strand
							    undef         ## phase
							    );
	    if (!defined($gff3Record)){
		$logger->logdie("Could not instantiate GFF3::GFF3Record for Sequence with id '$sequence_id'");
	    }
	}

	if (exists $fastaLookup->{$sequence_id} ){
	    my $fasta = $fastaLookup->{$sequence_id};
	    $gff3Builder->addFastaSequenceToRecord($sequence_id, $fasta);
	}

	&storeBsmlCrossReferencesAsAttributes($gff3Record, $sequence_id, $bsmlSequence->{'BsmlCrossReference'});

    }

    &storeBsmlAttributesAsAttributes($gff3Record, $bsmlSequence->{'BsmlAttr'});
    
    &storeBsmlAttributeListAsAttributes($gff3Record, $bsmlSequence->{'BsmlAttributeList'});

    if (($class eq 'contig') || ($class eq 'assembly')){
	if (defined($genomeId)){
	    &storeOrganismDataAsAttributes($gff3Record, $genomeId);

	    if (! $gff3Record->hasTranslationTable()){
		my $id = $gff3Record->getId();
		if (defined($translation_table)){
		    $logger->warn("The translation_table was not defined for the GFF3Record with id '$id' so applying ".
				  "user defined default value '$translation_table'");
		    $gff3Record->addTranslationTable($translation_table);
		}
		else {
		    $logger->warn("The translation_table was not defined for the GFF3Record with id '$id' and the user ".
				  "did not specify a default value.");
		}
	    }
	}
	else {
	    $logger->warn("BsmlSequence:". Dumper $bsmlSequence);
	    $logger->warn("genomeId was not defined for BSML Sequence with id '$sequence_id' and class '$class'");
	}
    }
}

##--------------------------------------------------------
## verifyAndSetOutdir()
##
##--------------------------------------------------------
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

#-------------------------------------------------------------------------
# getGFFFilename()
#
#-------------------------------------------------------------------------
sub getGFFFilename {

    my ($outdir, $bsmlFilename) = @_;
    
    ## Make sure we have a GFF filename to write to before we start parsing large
    ## BSML files.  This includes ensuring that the user or environment specified
    ## output directory is valid.
    $outdir = &verifyAndSetOutdir($outdir);

    my $basename = File::Basename::basename($bsmlFilename);
    
    ## remove trailing .bsml file name extension
    $basename =~ s/\.bsml$//;

    my $filename = $outdir . '/' . $basename . '.gff3';
}

##-------------------------------------------------------------------------
## print_usage()
##
##-------------------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 --bsml_file_name [--debug_level] [--gff_file_name] [--gbrowse=1] [--help|h] [--keep_all_features=1] [--logfile] [--man|m] [--outdir] [--preserve_types=1] --source [--translation_table]\n".
    "  --bsml_file_name     = Name of BSML file to be processed\n".
    "  -d|--debug_level     = Optional - Log4perl logging level (default is 0)\n".
    "  --gff_file_name      = Optional - Name of the output GFF3 file (default is --bsml_file_name.gff3)\n".
    "  --gbrowse            = Optional - Add Note attribute\n".
    "  -h|--help            = Optional - Display pod2usage help screen\n".
    "  --keep_all_features  = Optional - Does not filter out non-qualified feature types\n".
    "  --logfile            = Optional - Log4perl logfile (default is /tmp/bsml2gff3.p.log)\n".
    "  -m|--man             = Optional - Display pod2usage pages for this utility\n".
    "  --outdir             = Optional - If --gff_file_name is not specified, then the output directory for the GFF3 file (default is current working directory)\n".
    "  --preserve_types     = Optional - If --preserve_types, then type transformations will not be applied\n";
    "  --source             = GFF3 column 1 value\n".
    "  --translation_table  = Optional - user can specify a default value that will be applied only if the script cannot derive the value from the input BSML file\n";
    exit (1);

}


##-------------------------------------------------------------------------
## removeUnqualifiedFeatures()
##
##-------------------------------------------------------------------------
sub removeUnqualifiedFeatures {

    my ($gff3Builder) = @_;

    ## Keep track of the number of records by class that were not
    ## written to the GFF3 because their type was not qualified.
    my $removedByClassLookupCtr = {};

    my $removedCtr=0;

    while ( my $gff3Record = $gff3Builder->nextRecord() ){

	if (!defined($gff3Record)){
	    $logger->logdie("GFF3Record was not defined");
	}
	    
	my $id = $gff3Record->getId();
	if (!defined($id)){
	    $logger->logdie("id was not defined");
	}

	my $class = $gff3Record->getType();
	if (!defined($class)){
	    $logger->logdie("class was not defined for GFF3Record with id '$id'");
	}

	if ( ! exists $gff3QualifiedFeatureTypes->{$class} ){
	    if ($logger->is_debug()){
		$logger->debug("Encountered a non-qualified <Feature> with id '$id' class '$class'. ".
			       "A GFF3 record will not be written to the GFF3 file for this Feature.");
	    }

	    $gff3Builder->removeRecord($id);

	    ## Keep track of the number of records by class that were removed
	    $removedByClassLookupCtr->{$class}++;
	    
	    $removedCtr++;
	}
    }

    if ( $removedCtr > 0 ){

	$logger->warn("A number of features will not be written to the output ".
		      "GFF3 file.  Here a listing of those types rejected ".
		      "along with their count(s):");
	
	foreach my $class ( sort keys %{$removedByClassLookupCtr} ){
	    $logger->warn("$class: $removedByClassLookupCtr->{$class}");
	}
    }

}
