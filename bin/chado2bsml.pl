#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#---------------------------------------------------------------------------------------
# $Id: chado2bsml.pl 4224 2009-09-30 02:24:54Z daveriley $
#
#---------------------------------------------------------------------------------------
=head1 NAME

chado2bsml - Dumps a database to a BSML document(s)

=head1 SYNOPSIS

USAGE:  chado2bsml [--asmbl] [--bsml_file_name] --database --database_type [--debug] [--fastadir] [-h] [--ignore_go] [--ignore_evcodes] [--ignore_non_go] [--logfile] [-m] [--outdir] --password [--polypeptides_only] --server --username

=head1 OPTIONS

=over 8

=item B<--username>

Database username

=item B<--password>

Database password

=item B<--polypeptides_only>

 Optional: Extract only the assembly and polypeptides (good for input to computational analyses programs)

=item B<--asmbl>

Optional - The identifier for the assembly that should be extracted along with all subfeatures and annotation (default - all available assemblies will be extracted)

=item B<--bsml_file_name>

Optional - The output BSML file name (default is $outdir/${asmbl}.bsml)

=item B<--database>

Chado database name

=item B<--database_type>

Relational database management system type e.g. sybase or postgresql

=item B<--outdir> 

 Optional: Directory to write BSML gene model documents. Default is the current working directory

=item B<--fastadir> 

 Optional: Directory to write multi-FASTA file. Default is the current working directory

=item B<--debug>

 Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--logfile>

 Optional:  Coati::Logger log4perl log file.  Default is /tmp/chado2bsml.pl.log

=item B<--help,-h>

Print this help

=item B<--ignore_go>

 Optional: If specified --ignore_go=1, the software will not attempt to extract any GO and GO evidence data

=item B<--ignore_evcodes>

 Optional: If specified --ignore_evcodes=1, the software will not attempt to extract any evidence code data

=item B<--ignore_non_go>

 Optional: If specified --ignore_non_go=1, the software will not attempt to extract any TIGR_roles etc. data

=back

=head1 DESCRIPTION

chado2bsml retrieves feature data from a chado database and produces gene model BSML documents. (One BSML document is created per assembly in the output directory).

=cut

use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Prism;
use BSML::BsmlBuilder;
use Data::Dumper;
use Coati::Logger;


## Command-line options
my ($debug, $database, $fastadir, $help, $logfile, $man, $outdir, $password, $server, $username, $asmbl, $database_type, $bsmlFilename,
    $ignore_go, $ignore_evcodes, $ignore_non_go, $polypeptides_only);

my $results = GetOptions (
			  'debug=s'    => \$debug,
			  'database=s' => \$database, 
			  'fastadir=s' => \$fastadir,
			  'help|h'     => \$help,
			  'logfile=s'  => \$logfile,
			  'man|m=s'    => \$man,
			  'outdir=s'   => \$outdir, 
			  'password=s' => \$password,
			  'server=s'   => \$server,
			  'username=s' => \$username,
			  'asmbl=s'    => \$asmbl,
			  'database_type=s' => \$database_type,
			  'bsml_file_name=s' => \$bsmlFilename,
			  'ignore_go=s' => \$ignore_go,
			  'ignore_evcodes=s' => \$ignore_evcodes,
			  'ignore_non_go=s' => \$ignore_non_go,
			  'polypeptides_only=s' => \$polypeptides_only
			  );

&print_usage() if ($help);
&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if($man);

my $fatalCtr=0;

if (!$database){
    print STDERR "database was not defined\n";
    $fatalCtr++;
}
if (!$username){
    print STDERR "username was not defined\n";
    $fatalCtr++;
}
if (!$password){
    print STDERR "password was not defined\n";
    $fatalCtr++;
}
if (!$server){
    print STDERR "server was not defined\n";
    $fatalCtr++;
}
if (!$database_type){
    print STDERR "database_type was not defined\n";
    $fatalCtr++;
}

if ($fatalCtr>0){
    &print_usage();
}

#
# initialize the logger
#
if (!defined($logfile)){
    if (defined($bsmlFilename)){
	if (!defined($asmbl)){
	    $logfile = $bsmlFilename . '.chado2bsml.pl.log';
	}
	else {
	    $logfile = "/tmp/chado2bsml.pl.${asmbl}.log";
	}
    }
    elsif (defined($asmbl)){
	$logfile = "/tmp/chado2bsml.pl.${asmbl}.log";
    }
    else {
	$logfile = "/tmp/chado2bsml.pl.log";
    }

    print STDERR "--logfile was not specified and so was set to '$logfile'\n";
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				 'LOG_LEVEL'=>$debug);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

## Set the PRISM env var
&setPrismEnv($server, $database_type);

## Instantiate Prism object (for retrieve data from chado database)
my $prism = new Prism( 
		       user       => $username,
		       password   => $password,
		       db         => $database,
		       );

if (!defined($prism)){
    $logger->logdie("prism was not defined");
}

## Verify and set the output directory for the Bsml gene model documents
$outdir = &verify_and_set_outdir($outdir);

## Verify and set the output directory for the multi-fasta file
if (!defined($fastadir)){
    $fastadir = $outdir;
    if ($logger->is_debug()){
	$logger->debug("fastadir was not specified and so was set to '$fastadir'");
    }
}
else {
    $fastadir = &verify_and_set_outdir($fastadir);
}


## We control the types of computational analyses that are extracted
## by specifying them here
my $qualifiedComputationalAnalysisLookup = {'ber' => 1};
# 'BER'      => 1,
#					     'NCBI_COG' => 1,
#					     'RBS'      => 1,
#					     'PROSITE'  => 1,
#					     'RepeatMasker'  => 1 };
if ($logger->is_debug()){
    $logger->debug("We are only extracting the following types of computational analysis for features localized ".
		   "to our assembly(ies) in database '$database'");
    foreach my $ca (sort keys %{$qualifiedComputationalAnalysisLookup} ){
	$logger->debug("$ca");
    }
}

## We'll store all of the assembly identifiers on this array.
my $asmblUniquenameList = [];

if (!defined($asmbl)){
    if (defined($bsmlFilename)){
	$logger->warn("Since the --asmbl was not specified, all available assemblies are going to be extracted from ".
		      "--database '$database' and written to individual BSML files.  For this reason, the --bsml_file_name ".
		      "you specified is irrelevant and will be redefined automatically.");
	$bsmlFilename = undef;
    }
    $asmblUniquenameList = $prism->assemblyUniquenameList();
}
else {
    push(@{$asmblUniquenameList}, $asmbl);
}


## Number of assemblies that will be processed.
my $asmblCount = scalar(@{$asmblUniquenameList});

if ($logger->is_debug()){
    $logger->debug("Retrieved '$asmblCount' assemblies from database '$database'");
}

## Example prefix is TIGR_Bcl
my $prefix = $prism->createTIGRCrossReferencePrefix($database);

## We will keep track of the types of analyses that are extracted
## and then after all other data have been stored in BSML objects,
## we will create all of the <Analyses> section.
my $analysisLookup = {};

## All of the FASTA sequences will be cached in this lookup.
my $fastaSequenceLookup = {};

foreach my $asmbl (@{$asmblUniquenameList}){

#    if (!defined($bsmlFilename)){
	$bsmlFilename = $outdir . '/'. $asmbl . '.bsml';
#    }

    my $bsmlBuilder = new BSML::BsmlBuilder();

    $bsmlBuilder->{'doc_name'} = $bsmlFilename;
    $bsmlBuilder->{'xrefctr'}++;

    if ($logger->is_debug()){
	$logger->debug("Processing assembly '$asmbl', BSML filename will be '$bsmlFilename'");
    }

    my $organismData = $prism->organismDataByFeatureUniquename($asmbl);

    if (defined($organismData)){

	if ($logger->is_debug()){
	    $logger->debug("organismData:" . Dumper $organismData);
	}
	
	my $organismCrossReferenceData = $prism->organismCrossReferenceDataByUniquename($asmbl);

	if ($logger->is_debug()){
	    $logger->debug("organismCrossReferenceData:" . Dumper $organismCrossReferenceData);
	}
	
	my $genomeId = &writeOrganismToBsml($bsmlBuilder, 
					    $organismData,
					    $organismCrossReferenceData, 
					    $database,
					    $asmbl,
					    $prefix);
	
	
	my $assemblyData = $prism->sequenceDataByUniquename($asmbl);
	
	if (defined($assemblyData)){

	    if ($logger->is_debug()){
		$logger->debug("assemblyData:" . Dumper $assemblyData);
	    }
	    
	    my $assemblyCrossReferenceData = $prism->crossReferenceDataByUniquename($asmbl);
	    
	    if ($logger->is_debug()){
		$logger->debug("assemblyCrossReferenceData:" . Dumper $assemblyCrossReferenceData);
	    }


	    my $assemblySequencePropertiesLookup = $prism->featurePropertiesByUniquename($asmbl);
	    
	    my $assemblySequenceElem = &writeSequenceToBsml($bsmlBuilder,
							    $assemblyData,
							    $genomeId, 
							    $database,
							    $asmbl,
							    undef,
							    $organismData->{'schema_type'},
							    $prefix,
							    $assemblyCrossReferenceData,
							    $assemblySequencePropertiesLookup);
	    

	    if ((defined($polypeptides_only)) && ($polypeptides_only == 1)){
		if ($prism->doesSequenceHaveLocalizedPolypeptideFeatures($asmbl)){
		    &extractPolypeptideDataAndInsertIntoBSML($assemblySequenceElem,
							     $bsmlBuilder,
							     $asmbl,
							     $database,
							     $genomeId,
							     $qualifiedComputationalAnalysisLookup);
		}
		else {
		    $logger->warn("The assembly with identifier '$asmbl' does not have any polypeptides ".
				  "localized to it.");
		}
	    }
	    elsif ($prism->doesSequenceHaveLocalizedSubfeatures($asmbl)){
		&extractSubfeatureDataAndInsertIntoBSML($assemblySequenceElem,
							$bsmlBuilder,
							$asmbl,
							$database,
							$genomeId,
							$qualifiedComputationalAnalysisLookup);

	    }
	    else {
		$logger->warn("Subfeature count was zero, so no subfeatures will be written to the ".
			      "output BSML file '$bsmlFilename' for assembly '$asmbl' database '$database'");
	    }

	    my $analysisCount = keys( %{$analysisLookup} );
	    
	    if ($analysisCount>0){
		
		&writeAnalysesToBsml($prism, 
				     $bsmlBuilder,
				     $analysisLookup,
				     $asmbl,
				     $database);
		
		&writeComputationalAnalysesToBsml($prism,
						  $bsmlBuilder,
						  $analysisLookup,
						  $asmbl,
						  $database);
	    }
	    
	    print "Finished extracting all data for assembly '$asmbl' from database '$database' (server '$server').\nWriting BSML file '$bsmlFilename'.\n";

	    &writeBSMLDocument($bsmlBuilder);
	    
	    &createMultiFASTAFile($fastaSequenceLookup, $fastadir, $database);

	    ## re-initialize some lookups
	    $analysisLookup = {};
	    $fastaSequenceLookup = {};
	    
	    print "Finished writing BSML file '$bsmlFilename' for assembly '$asmbl' from database '$database' (server '$server').\n";
	}
	else  {
	    $logger->logdie("No sequence data was retrieved from database '$database' for assembly '$asmbl'");
	}
    }
    else {
	$logger->logdie("No organism data was retrieved from database '$database' for assembly '$asmbl'");
    }
}


print "$0 program execution completed\n";

if ($asmblCount > 1) {
    print "Extracted data for '$asmblCount' assemblies from database '$database'\n";
    print "BSML output was written to directory '$outdir'\n";
}

print "The log file is '$logfile'\n";
exit(0);

##-----------------------------------------------------------------------------------
##
##   END OF MAIN -- SUBROUTINES FOLLOW
##
##-----------------------------------------------------------------------------------

sub extractSubfeatureDataAndInsertIntoBSML {
    
    my ($assemblySequenceElem, $bsmlBuilder, $asmbl, $database, $genomeId, $qualifiedComputationalAnalysisLookup) = @_;

    ## Create a <Feature-table> element object for all subfeatures
    ## that are localized to our assembly <Sequence>.
    my $assemblyFeatureTableElem = $bsmlBuilder->createAndAddFeatureTable($assemblySequenceElem);
    
    if (!defined($assemblyFeatureTableElem)){
	$logger->logdie("Could not create <Feature-table> element object for assembly ".
			"'$asmbl' database '$database'");
    }	    
    ## Retrieve all sub-features that localize to the sequence with uniquename '$asmbl'
    my $subfeatureData = $prism->subfeatureDataByAssembly($asmbl);

    if ($logger->is_debug()){
	$logger->debug("subfeatureData:" . Dumper $subfeatureData);
    }
    
    ## Some subfeatures were localized to our sequence (assembly), so we should go 
    ## ahead and attempt to retrieve any additional information that might be associated
    ## with these subfeatures.
    my $subfeatureCrossReferenceData = $prism->allSubfeatureCrossReferenceDataByAssembly($asmbl);
    
    if ($logger->is_debug()){
	$logger->debug("subfeatureCrossReferenceData:" . Dumper $subfeatureCrossReferenceData);
    }

    my $subfeatureProperties = $prism->allSubfeaturePropertiesDataByAssembly($asmbl);
    
    if ($logger->is_debug()){
	$logger->debug("subfeatureProperties:" . Dumper $subfeatureProperties);
    }

    my $subfeatureGOAssignments;
    my $GOAssignmentAttributes;

    if ((!defined($ignore_go)) || ($ignore_go != 1)){
	
	$subfeatureGOAssignments = $prism->allGOAssignmentsForSubfeaturesByAssembly($asmbl);
    
	if ($logger->is_debug()){
	    $logger->debug("subfeatureGOAssignments:" . Dumper $subfeatureGOAssignments);
	}

	$GOAssignmentAttributes = $prism->allGOAssignmentAttributesForSubfeaturesByAssembly($asmbl);
    
	if ($logger->is_debug()){
	    $logger->debug("GOAssignmentAttributes:" . Dumper $GOAssignmentAttributes );
	}
    }
    else {
	$logger->info("Will not extract GO data");
    }

    my $evidenceCodesLookup;

    if ((!defined($ignore_evcodes)) || ($ignore_evcodes != 1)){

	$evidenceCodesLookup = $prism->evidenceCodesLookup();

	if ($logger->is_debug()){
	    $logger->debug("evidenceCodesLookup:" . Dumper $evidenceCodesLookup );
	}
    }
    else {
	$logger->info("Will not extract evidence code data");
    }

    my $subfeatureNonGOAssignments;
    my $nonGOAssignmentAttributes;

    if ((!defined($ignore_non_go)) || ($ignore_non_go != 1)){

	$subfeatureNonGOAssignments = $prism->allNonGOAssignmentsForSubfeaturesByAssembly($asmbl);
	
	if ($logger->is_debug()){
	    $logger->debug("subfeatureNonGOAssignments:" . Dumper $subfeatureNonGOAssignments);
	}

	$nonGOAssignmentAttributes = $prism->allNonGOAssignmentAttributesForSubfeaturesByAssembly($asmbl);
    
	if ($logger->is_debug()){
	    $logger->debug("nonGOAssignmentAttributes:" . Dumper $nonGOAssignmentAttributes );
	}
    }
    else {
	$logger->info("Will not extract non-GO data i.e. TIGR_roles");
    }


    ## This information will be used to create analysis <Link> elements which will
    ## essentially link the <Feature> elements to their <Analysis> elements.
    my $subfeatureAnalysisLookup = $prism->allSubfeaturesAnalysisByAssembly($asmbl);
    
    if ($logger->is_debug()){
	$logger->debug("subfeatureAnalysisLookup:" . Dumper $subfeatureAnalysisLookup );
    }

    ## Extract data for subfeatures that are localized to the subfeatures that
    ## are localized to the assembly.
    my $sub2 = $prism->allSubfeaturesNotLocalizedToSomeAssembly($asmbl);
    
    if ($logger->is_debug()){
	$logger->debug("sub2:" . Dumper $sub2 );
    }


    my $sub2CrossReference = $prism->allCrossReferenceForSubfeaturesNotLocalizedToSomeAssembly($asmbl);
    
    if ($logger->is_debug()){
	$logger->debug("sub2CrossReference:" . Dumper $sub2CrossReference );
    }

    my $sub2Properties = $prism->allPropertiesForSubfeaturesNotLocalizedToSomeAssembly($asmbl);
    
    if ($logger->is_debug()){
	$logger->debug("sub2Properties:" . Dumper $sub2Properties );
    }
    
    &writeSubfeaturesToBsml($bsmlBuilder,
			    $assemblyFeatureTableElem,
			    $genomeId,
			    $subfeatureData, 
			    $subfeatureCrossReferenceData,
			    $subfeatureProperties,
			    $subfeatureGOAssignments,
			    $GOAssignmentAttributes,
			    $subfeatureNonGOAssignments,
			    $nonGOAssignmentAttributes,
			    $subfeatureAnalysisLookup,
			    $sub2,
			    $sub2CrossReference,
			    $sub2Properties,
			    $database,
			    $asmbl,
			    $asmbl,
			    $qualifiedComputationalAnalysisLookup,
			    $evidenceCodesLookup);	
    
    my $featureRelationships = $prism->featureRelationshipsBySequenceFeatureUniquename($asmbl);
    
    if ($logger->is_debug()){
	$logger->debug("featureRelationships:" . Dumper $featureRelationships );
    }
    
    &writeFeatureRelationshipsToBsml($bsmlBuilder,
				     $featureRelationships,
				     $assemblySequenceElem,
				     $database,
				     $asmbl);
}	


sub extractPolypeptideDataAndInsertIntoBSML {
    
    my ($assemblySequenceElem, $bsmlBuilder, $asmbl, $database, $genomeId, $qualifiedComputationalAnalysisLookup) = @_;

    ## Create a <Feature-table> element object for all subfeatures
    ## that are localized to our assembly <Sequence>.
    my $assemblyFeatureTableElem = $bsmlBuilder->createAndAddFeatureTable($assemblySequenceElem);
    
    if (!defined($assemblyFeatureTableElem)){
	$logger->logdie("Could not create <Feature-table> element object for assembly ".
			"'$asmbl' database '$database'");
    }	    
    ## Retrieve all polypeptide features that localize to the sequence with uniquename '$asmbl'
    my $polypeptideData = $prism->polypeptideDataByAssembly($asmbl);

    if ($logger->is_debug()){
	$logger->debug("polypeptideData:" . Dumper $polypeptideData);
    }
    
    
    &writeSubfeaturesToBsml($bsmlBuilder,
			    $assemblyFeatureTableElem,
			    $genomeId,
			    $polypeptideData, 
			    undef,
			    undef,
			    undef,
			    undef,
			    undef,
			    undef,
			    undef,
			    undef,
			    undef,
			    undef,
			    $database,
			    $asmbl,
			    $asmbl,
			    $qualifiedComputationalAnalysisLookup,
			    undef);	
    
}	


##----------------------------------------------------------------
## writeOrganismToBsml()
##
##----------------------------------------------------------------
sub writeOrganismToBsml {

    my ($bsmlBuilder, $organismData, $organismCrossReferenceData, $database, $asmbl, $prefix) = @_;

## Example output:
##
#     <Genomes>
#       <Genome id="_0">
#         <Organism genus="Plasmodium" species="vivax">
#           <Attribute name="abbreviation" content="p_vivax"></Attribute>
#           <Attribute name="genetic_code" content="1"></Attribute>
#           <Attribute name="mt_genetic_code" content="4"></Attribute>
#         </Organism>
#         <Cross-reference database="TIGR_Pva1" identifier="p_vivax" id="_1" identifier-type="legacy_annotation_database">
#           <Attribute name="schema_type" content="euk"></Attribute>
#           <Attribute name="source_database" content="pva1"></Attribute>
#         </Cross-reference>
#       </Genome>
#     </Genomes>


    my $genus = $organismData->{'genus'};
    my $species = $organismData->{'species'};
    my $strain = $organismData->{'strain'};

    if (!defined($genus)){
	$logger->logdie("genus was not defined");
    }

    if (!defined($species)){
	$logger->logdie("species was not defined");
    }

    ## Create the <Genome> BSML element
    my $genomeElem = $bsmlBuilder->createAndAddGenome();
    
    if (!defined($genomeElem)){
	$logger->logdie("Could not create <Genome> element object for organism with genus '$genus' ".
			"species '$species' database '$database' assembly '$asmbl'");
    }


    ##
    ## Create a <Cross-reference> for this organism
    ##
    my $identifier = lc(substr($genus,0,1)) . '_' . lc($species);
    my $identifier_type = 'chado';

    my $xref_elem = $bsmlBuilder->createAndAddCrossReference(
							     'parent'          => $genomeElem,
							     'id'              => $bsmlBuilder->{'xrefctr'}++,
							     'database'        => $prefix,
							     'identifier'      => $identifier,
							     'identifier-type' => $identifier_type
							     );
    if (!defined($xref_elem)){
	$logger->logdie("Could not create <Cross-reference> element object for organism having genus '$genus' ".
			"species '$species' database '$database' assembly '$asmbl' ".
			"with database '$prefix' identifier '$identifier' identifier-type '$identifier_type'");
    }


    ##
    ## Create a source_database <Attribute> for the <Cross-reference> for this organism
    ##
    my $dbsource_attribute_elem = $bsmlBuilder->createAndAddBsmlAttribute( $xref_elem,
									   'source_database',
									   $database );
    
    if (!defined($dbsource_attribute_elem)){
	$logger->logdie("Could not create <Attribute> for name 'database_source' content '$database' ".
			"for organism with genus '$genus' species '$species' database '$database' ".
			"assembly '$asmbl'");
    }
    
    
    ##
    ## Create a schema_type <Attribute> for <Cross-reference> for this organism
    ##
    my $schemaType = 'chado';
    my $schema_attribute_elem = $bsmlBuilder->createAndAddBsmlAttribute( $xref_elem,
									 'schema_type',
									 $schemaType );
    
    if (!defined($schema_attribute_elem)){
	$logger->logdie("Could not create <Attribute> for name 'schema_type' content '$schemaType' ".
			"for organism with genus '$genus' species '$species' database '$database' ".
			"assembly '$asmbl'");
    }
    
    foreach my $xrefHash ( @{$organismCrossReferenceData}){
	##
	## Create additional  <Cross-reference> for this organism
	##
	my $db = $xrefHash->{'name'};
	my $identifier = $xrefHash->{'accession'};
	my $identifierType = $xrefHash->{'version'};
	
	my $xref_elem = $bsmlBuilder->createAndAddCrossReference(
								 'parent'          => $genomeElem,
								 'id'              => $bsmlBuilder->{'xrefctr'}++,
								 'database'        => $db,
								 'identifier'      => $identifier,
								 'identifier-type' => $identifierType
								 );
	
	if (!defined($xref_elem)){
	    $logger->logdie("Could not create <Cross-reference> element object for database '$database' assembly '$asmbl' ".
			    "with Cross-reference database '$db' identifier '$identifier' identifier-type '$identifierType'");
	}
    }
    
    ##
    ## Create the <Organism> BSML element
    ##
    my $organismElem = $bsmlBuilder->createAndAddOrganism( 
							   'genome'  => $genomeElem,
							   'genus'   => $genus,  
							   'species' => $species,
							   );
    if (!defined($organismElem)){
	$logger->logdie("Could not create <Organism> element object for organism with genus ".
			"'$genus' species '$species' database '$database' assembly '$asmbl'");
    }

    &store_organism_attribute($bsmlBuilder, 
			      $organismElem,
			      $organismData,
			      $genus,
			      $species,
			      $asmbl,
			      $database);

    if (( exists $genomeElem->{'attr'}->{'id'} ) && ( defined ( $genomeElem->{'attr'}->{'id'} ) )  ){
	return $genomeElem->{'attr'}->{'id'};
    }
    else {
	$logger->logdie("Genome id was not defined!");
    }
}

#----------------------------------------------------
# store_organism_attribute()
#
#----------------------------------------------------
sub store_organism_attribute {

    my ($bsmlBuilder, $organismElem, $organismData, $genus, $species, $asmbl, $database) = @_;

    foreach my $attribute ('abbreviation', 'gram_stain', 'genetic_code', 'mt_genetic_code', 'strain', 'comment', 'translation_table'){
	
	if ((exists $organismData->{$attribute}) && (defined($organismData->{$attribute}))){

	    my $value = $organismData->{$attribute};

	    my $attribute_elem = $bsmlBuilder->createAndAddBsmlAttribute( $organismElem,
									  $attribute,
									  $value );
	    
	    if (!defined($attribute_elem)){
		$logger->logdie("Could not create <Attribute> for the name '$attribute' content '$value' ".
				"for organism with genus '$genus' species '$species' database '$database' ".
				"assembly '$asmbl'");
	    }
	}
    }
}   


##------------------------------------------------------------------
## writeSequenceToBsml()
##
##------------------------------------------------------------------
sub writeSequenceToBsml {

    my ($bsmlBuilder, $assemblyData, $genomeId, $database, $asmbl, $organismName, 
	$schema_type, $prefix, $assemblyCrossReferenceData, $assemblySequencePropertiesLookup) = @_;
#     <Sequences>
#       <Sequence length="1735" class="assembly" id="pva1.assembly.223.0" molecule="dna">
#         <Attribute name="molecule_name" content="4473 Plasmodium vivax"></Attribute>
#         <Seq-data-import source="/usr/local/annotation/APX3/output_repository/legacy2bsml/7789_five-organisms/fasta/i1/g1//pva1_1115_assembly.fsa" identifier="pva1.assembly.223.0" format="fasta" id="Bsml0"></Seq-data-import>
#         <Cross-reference database="TIGR_Pva1" identifier="1115" id="_2" identifier-type="current"></Cross-reference>
#         <Cross-reference database="Genbank" identifier="AAKM01000544" id="_3" identifier-type="current"></Cross-reference>
#         <Link rel="genome" href="#_0"></Link>
#         <Attribute-list>
#           <Attribute name="SO" content="assembly"></Attribute>
#         </Attribute-list>
#       </Sequence>
#     </Sequences>


    my $assemblySequenceElem = &createSequence($bsmlBuilder,
					       $asmbl,
					       $assemblyData->{'length'},
					       'assembly',
					       $genomeId,
					       $assemblyData->{'molecule_type'},
					       $assemblyData->{'topology'}
					       );
    
    
    foreach my $array ( @{$assemblySequencePropertiesLookup} ) {
        if (! &addBsmlAttributeToBsml($bsmlBuilder, $assemblySequenceElem, $array->[0], $array->[1])){
	    $logger->logdie("Could not add BSML <Attribute> element object ".
			    "for name '$array->[0]' content '$array->[1]'");
	}
    }



    my $tmpArray = [$asmbl, $assemblyData->{'sequence'}];
    
    push ( @{$fastaSequenceLookup->{$asmbl}->{'assembly'}}, $tmpArray);


    if (exists $assemblyData->{'molecule_name'} ){

	my $sequenceSecondaryType = $prism->deriveSequenceSecondaryType($assemblyData->{'molecule_name'});
	
	&storeBsmlAttributeList($assemblySequenceElem, 'SO', $sequenceSecondaryType);
	
	my $attribute_elem = $bsmlBuilder->createAndAddBsmlAttribute(
								     $assemblySequenceElem,
								     'molecule_name',
								     $assemblyData->{'molecule_name'}
								     );
	
	if (!defined($attribute_elem)){
	    $logger->logdie("Could not create <Attribute> with name 'molecule_name' content '$assemblyData->{'molecule_name'}' ".
			    "while processing assembly with uniquename '$asmbl' from database '$database'");
	}
    }
    else{
	$logger->warn("molecule_name was not defined for assembly '$asmbl' database '$database'");
    }


    foreach my $asmblXref ( @{$assemblyCrossReferenceData}){

	my $version = $asmblXref->{'version'};
	my $accession = $asmblXref->{'accession'};
	my $db = $asmblXref->{'name'};

	my $xrefElem = $bsmlBuilder->createAndAddCrossReference(
								'parent'          => $assemblySequenceElem,
								'id'              => $bsmlBuilder->{'xrefctr'}++,
								'database'        => $db,
								'identifier'      => $accession,
								'identifier-type' => $version
								);
	
	if (!defined($xrefElem)){
	    $logger->logdie("Could not create <Cross-reference> for assembly '$asmbl' ".
			    "database '$db' identifier '$accession' identifier-type '$version''");
	}
    }



    ## Create a <Seq-data-import> object
    my $source = $fastadir . '/' . $asmbl . '.fsa';

    my $seqDataImportElem = $bsmlBuilder->createAndAddSeqDataImport(
								    $assemblySequenceElem,   # Sequence element object reference
								    'fasta',                 # format
								    $source,                 # source
								    undef,                   # id
								    $asmbl                   # identifier
								    );
    
    if (!defined($seqDataImportElem)){
	$logger->logdie("Could not create <Seq-data-import> element object for assembly '$asmbl' ".
			"database '$database'");
    }

    $prism->writeSingleFastaRecordToFastaFile($asmbl,
					      $source,
					      $assemblyData->{'sequence'});

    ## Create <Cross-reference> object
    my $xrefElem = $bsmlBuilder->createAndAddCrossReference(
							    'parent'          => $assemblySequenceElem,
							    'id'              => $bsmlBuilder->{'xrefctr'}++,
							    'database'        => $prefix,
							    'identifier'      => $asmbl,
							    'identifier-type' => 'current'
							    );
    
    if (!defined($xrefElem)){
	$logger->logdie("Could not create <Cross-reference> element object for assembly '$asmbl' ".
			"database '$database' prefix '$prefix'");
    }



    ## The following will be stored as <Attribute> elements under the assembly's <Sequence> element.
    my @cloneInfoTypes = qw(assembly_status
			    is_final
			    fa_left
			    fa_right 
			    fa_orient 
			    gb_description 
			    gb_comment 
			    gb_date 
			    comment 
			    assignby 
			    date 
			    gb_date_for_release 
			    gb_date_released 
			    gb_authors1 
			    gb_authors2 
			    gb_keywords 
			    sequencing_type 
			    is_prelim 
			    is_licensed 
			    gb_phase 
			    chromosome 
			    gb_gi );


    ## All clone_info columns' values should be stored as <Attribute> objects under the assembly's <Sequence> object (bug 2087).
    foreach my $cloneInfoType ( @cloneInfoTypes ){
	
	if ( ( exists $assemblyData->{$cloneInfoType}) && (defined ( $assemblyData->{$cloneInfoType} ) ) ) {
	    
	    my $value  = $assemblyData->{$cloneInfoType};
	    
	    my $attribute_elem = $bsmlBuilder->createAndAddBsmlAttribute(
									 $assemblySequenceElem,
									 $cloneInfoType,
									 $value
									 );
	    if (!defined($attribute_elem)){
		$logger->logdie("Could not create '$cloneInfoType' <Attribute> for assembly '$asmbl' database '$database'");
	    }
	}
    }


    ## The following will be stored as <Attribute-list> elements under the assembly's <Sequence> element.
    my $cloneInfoAnnotationTypes = { 'is_orig_annotation' => 'Primary_annotation',
				     'is_tigr_annotation' => 'TIGR_annotation' };
    
    foreach my $cloneInfoAnnotationType ( keys %{$cloneInfoAnnotationTypes} ) {
	
	if ((exists $assemblyData->{$cloneInfoAnnotationType}) && 
	    (defined($assemblyData->{$cloneInfoAnnotationType})) &&
	    ($assemblyData->{$cloneInfoAnnotationType} == 1)) {
	    
	    &storeBsmlAttributeList( $assemblySequenceElem,
				     'ANNFLG',
				     $cloneInfoAnnotationTypes->{$cloneInfoAnnotationType});
	}
    }


    #---------------------------------------------------------------------------------
    # comment: Store Cross-reference information when available relating the following clone_info fields:
    #          gb_acc
    #          seq_asmbl_id
    #          lib_id
    #          clone_id
    #
    if ((exists $assemblyData->{'gb_acc'} ) &&
 	(defined($assemblyData->{'gb_acc'}))){
	
	my $xref = $bsmlBuilder->createAndAddCrossReference( 'parent'     => $assemblySequenceElem,
							     'id'         => $bsmlBuilder->{'xrefctr'}++,
							     'database'   => 'Genbank',
							     'identifier' => $assemblyData->{'gb_acc'},
							     'identifier-type'    => 'current'
							     );
	
	if (!defined($xref)){
	    $logger->logdie("Could not create <Cross-reference> element object for database 'genbank' identifier '$assemblyData->{'gb_acc'}' ".
			    "version 'current' assembly uniquename '$asmbl'");
	}
    }


    my $cloneInfoDatabaseIdentifierLookup = { 'seq_asmbl_id' => 'seq_id',
					      'lib_id' => 'lib_id',
					      'clone_id' => 'clone_id' };
    
    

    if ((exists $assemblyData->{'seq_db'}) && (defined($assemblyData->{'seq_db'}))) {
	
	foreach my $cloneInfoDb (keys %{$cloneInfoDatabaseIdentifierLookup} ) {

	    if ((exists $assemblyData->{$cloneInfoDb} ) && (defined($assemblyData->{$cloneInfoDb}))) {

		my $xref = $bsmlBuilder->createAndAddCrossReference( 'parent'     => $assemblySequenceElem,
								     'id'         => $bsmlBuilder->{'xrefctr'}++,
								     'database'   => $assemblyData->{'seq_db'},
								     'identifier' => $assemblyData->{$cloneInfoDb},
								     'identifier-type' => $cloneInfoDatabaseIdentifierLookup->{$cloneInfoDb}
								     );
		if (!defined($xref)){
		    $logger->logdie("Could not create <Cross-reference> element object ".
				    "for database '$assemblyData->{'seq_db'}' identifier ".
				    "'$assemblyData->{$cloneInfoDb}' identifier-type ".
				    "'$cloneInfoDatabaseIdentifierLookup->{$cloneInfoDb}' ".
				    "for assembly uniquename '$asmbl'"); 
		}
	    }
	}
    }

    return $assemblySequenceElem;
}

##------------------------------------------------------
## writeSubfeaturesToBsml()
##
##------------------------------------------------------
sub writeSubfeaturesToBsml {

    my ($bsmlBuilder, $assemblyFeatureTableElem, $genomeId, $subfeatureData, $subfeatureCrossReferenceData, $subfeatureProperties,
	$subfeatureGOAssignments, $GOAssignmentAttributes, $subfeatureNonGOAssignments, $nonGOAssignmentAttributes, 
	$subfeatureAnalysisLookup, $sub2, $sub2CrossReference, $sub2Properties, $database, $asmbl, $parentSequenceUniquename,
	$qualifiedComputationalAnalysisLookup, $evidenceCodesLookup) = @_;

    ##
    ## Example output:
    ##    
    ## <Feature class="transcript" id="bcl.transcript.5385.0">
    ## <Attribute name="assignby" content="sdaugher"></Attribute>
    ## <Attribute name="auto_annotate_toggle" content="0"></Attribute>
    ## <Attribute name="auto_comment" content="IDENT INFO:\ncom_name = sensor histidine kinase HpkA, putative from OMNI|TM1654\ngene_sym = (NULL) from OMNI|TM1654\nrole_id = 129 from OMNI|TM1654\ngo_term = NULL from OMNI|NTL03CP0207\nautoannotate = 0\nBEST HMM INFO:\nacc: PF02518\nname: ATPase, histidine kinase-, DNA gyrase B-, and HSP90-like domain protein\nscore: 143.8\ncutoff: 5.00\niso_type: domain\nhit length: partial\nBEST BER INFO:\ncom_name: sensor histidine kinase HpkA, putative from OMNI|TM1654\ngene_sym: hpkA from OMNI|TM1654\n"></Attribute>
    ## <Attribute name="completed_by" content="sdaugher"></Attribute>
    ## <Attribute name="date" content="Jan 19 2006  2:07PM"></Attribute>
    ## <Attribute name="gene_product_name" content="sensory box histidine kinase"></Attribute>
    ## <Attribute name="start_site_editor" content="sdaugher"></Attribute>
    ## <Interval-loc complement="1" startpos="240449" endpos="242825"></Interval-loc>
    ## <Cross-reference database="TIGR_Bcl" identifier="ORF00002" id="_7" identifier-type="feat_name"></Cross-reference>
    ## <Cross-reference database="TIGR_Bcl" identifier="CPF_0198" id="_8" identifier-type="locus"></Cross-reference>
    ## <Cross-reference database="TIGR_Bcl" identifier="CPF_0198" id="_9" identifier-type="display_locus"></Cross-reference>
    ## <Link rel="sequence" href="#bcl.transcript.5385.0_seq"></Link>
    ## <Attribute-list>
    ##   <Attribute name="EC" content="2.7.3.-"></Attribute>
    ## </Attribute-list>
    ## <Attribute-list>
    ## <Attribute name="TIGR_role" content="264"></Attribute>
    ## <Attribute name="assignby" content="sdaugher"></Attribute>
    ##   <Attribute name="date" content="Oct 19 2005 11:41AM"></Attribute>
    ## </Attribute-list>
    ## <Attribute-list>
    ##   <Attribute name="TIGR_role" content="699"></Attribute>
    ##   <Attribute name="assignby" content="sdaugher"></Attribute>
    ##   <Attribute name="date" content="Oct 19 2005 11:22AM"></Attribute>
    ## </Attribute-list>
    ## <Attribute-list>
    ##   <Attribute name="GO" content="GO:0000155"></Attribute>
    ##   <Attribute name="ISS" content="GO_REF:0000011 WITH Pfam:PF00512"></Attribute>
    ##   <Attribute name="assignby" content="sdaugher"></Attribute>
    ##   <Attribute name="date" content="Oct 19 2005 11:42AM"></Attribute>
    ## </Attribute-list>
    ## <Attribute-list>
    ##   <Attribute name="GO" content="GO:0000160"></Attribute>
    ##   <Attribute name="ISS" content="GO_REF:0000011 WITH Pfam:PF00512"></Attribute>
    ##   <Attribute name="assignby" content="sdaugher"></Attribute>
    ##   <Attribute name="date" content="Oct 19 2005 11:42AM"></Attribute>
    ## </Attribute-list>
    ## <Attribute-list>
    ##   <Attribute name="GO" content="GO:0004871"></Attribute>
    ##   <Attribute name="ISS" content="GO_REF:0000011 WITH TIGR_TIGRFAMS:TIGR00229"></Attribute>
    ##   <Attribute name="assignby" content="sdaugher"></Attribute>
    ##   <Attribute name="date" content="Oct 19 2005 11:42AM"></Attribute>
    ## </Attribute-list>
    ## <Attribute-list>
    ##   <Attribute name="GO" content="GO:0007165"></Attribute>
    ##   <Attribute name="ISS" content="GO_REF:0000011 WITH TIGR_TIGRFAMS:TIGR00229"></Attribute>
    ##   <Attribute name="assignby" content="sdaugher"></Attribute>
    ##   <Attribute name="date" content="Oct 19 2005 11:42AM"></Attribute>
    ## </Attribute-list>



    foreach my $subFeatureArray ( @{$subfeatureData->{$parentSequenceUniquename}} ){
	
	my $uniquename = $subFeatureArray->[0];
	my $seqlen = $subFeatureArray->[1];
	my $residues = $subFeatureArray->[2];
	my $class = $subFeatureArray->[3];
	my $fmin = $subFeatureArray->[4];
	my $fmax = $subFeatureArray->[5];
	my $strand = $subFeatureArray->[6];
	my $is_fmin_partial = $subFeatureArray->[7];
	my $is_fmax_partial = $subFeatureArray->[8];


	if ($logger->is_debug()){
	    $logger->debug("Processing subfeature with uniquename ".
			   "'$uniquename' class '$class' fmin '$fmin' ".
			   "fmax' strand '$strand' is_fmin_partial ".
			   "'$is_fmin_partial' is_fmax_partial ".
			   "'$is_fmax_partial'");
	}

	my $complement=0;

	if ($strand == -1){
	    $complement=1;
	}


	## Create a <Feature> element object
	my $featureElem = $bsmlBuilder->createAndAddFeature(
							    $assemblyFeatureTableElem,  # <Feature-table> element object reference
							    $uniquename,          # id
							    undef,                # title
							    $class,               # class
							    undef,                # comment
							    undef                 # displayAuto
							    );
	
	if (!defined($featureElem)){
	    $logger->logdie("Could not create <Feature> element object for ".
			    "uniquename '$uniquename' class '$class' ".
			    "with parent Sequence '$parentSequenceUniquename' ".
			    "while processing assembly with ".
			    "uniquename '$asmbl' from database '$database'"); 
	}

	if ($fmin == $fmax){
	    ## Create a BSML <Site-loc> element object
	    my $siteLocElem = $bsmlBuilder->createAndAddSiteLoc( $featureElem,
								 $fmin,
								 $complement );
	    if (!defined($siteLocElem)){
		$logger->logdie("Could not create <Site-loc> element object with ".
				"site '$fmin' complement '$complement' for ".
				"uniquename '$uniquename' class '$class' with ".
				"parent Sequence '$parentSequenceUniquename' while ".
				"processing assembly with uniquename '$asmbl' from ".
				"database '$database'");
	    }
	}
	else {

	    my $startopen = &checkIsPartial($is_fmin_partial);

	    my $endopen = &checkIsPartial($is_fmax_partial);

	    ## Create a BSML <Interval-loc> element object
	    my $intervalLocElem = $bsmlBuilder->createAndAddIntervalLoc( $featureElem,
									 $fmin,
									 $fmax,
									 $complement,
									 $startopen,
									 $endopen );
	    if (!defined($intervalLocElem)){
		$logger->logdie("Could not create <Interval-loc> element object ".
				"with fmin '$fmin' fmax '$fmax' complement ".
				"'$complement' startopen '$startopen' endopen ".
				"'$endopen' for uniquename '$uniquename' ".
				"class '$class' with parent Sequence ".
				"'$parentSequenceUniquename' while processing ".
				"assembly with uniquename '$asmbl' from ".
				"database '$database'");
	    }
	}


	
	if (( defined($residues)) || (exists $sub2->{$uniquename})) {
	    
	    my $uniquename_seq = $uniquename . '_seq';

	    my $sequenceElem = &createSequence($bsmlBuilder,
					       $uniquename_seq,
					       $seqlen,
					       $class,
					       $genomeId
					       );
	    
	    if (!defined($sequenceElem)){
		$logger->logdie("Could not create <Sequence> element object for ".
				"feature with uniquename '$uniquename' class ".
				"'$class' with parent Sequence '$parentSequenceUniquename' ".
				"while processing assembly with uniquename '$asmbl' from ".
				"database '$database'");
	    }

	    my $linkElem = $bsmlBuilder->createAndAddLink(
							  $featureElem,
							  'sequence',        # rel
							  "#$uniquename_seq" # href
							  );
	    
	    if (!defined($linkElem)){
		$logger->logdie("Could not create a 'sequence' <Link> element object for the ".
				"feature with uniquename '$uniquename' with parent Sequence ".
				"'$parentSequenceUniquename' while processing ".
				"assembly with uniquename '$asmbl' from database '$database'");
	    }

	    if ( defined($residues)) {
		## Create some <Seq-data-import> BSML element object
		
		my $tmpArray = [$uniquename, $residues];
		
		push ( @{$fastaSequenceLookup->{$asmbl}->{$class}}, $tmpArray);
		
		my $source = $fastadir .'/'. $database . '_' . $asmbl . '_' . $class .'.fsa';
		
		my $seqDataImportElem = $bsmlBuilder->createAndAddSeqDataImport(
										$sequenceElem,  # <Sequence> element object reference
										'fasta',        # format
										$source,        # source
										undef,          # id
										$uniquename     # identifier
										);
		if (!defined($seqDataImportElem)){
		    $logger->logdie("Could not create <Seq-data-import> element object for the ".
				    "sequence linked to the feature with uniquename '$uniquename' ".
				    "parent Sequence '$parentSequenceUniquename' while processing ".
				    "the assembly with uniquename '$asmbl' from ".
				    "database '$database'");
		}
	    }

	    if (exists $sub2->{$uniquename} ){

		## Create a BSML <Feature-table> element object
		my $featureTableElem = $bsmlBuilder->createAndAddFeatureTable($sequenceElem);
		
		if (!defined($featureTableElem)){
		    $logger->logdie("Could not create <Feature-table> element object for sequence with uniquename '$uniquename' ".
				    "parent Sequence '$parentSequenceUniquename' while processing assembly with uniquename ".
				    "'$asmbl' from database '$database'");
		}	    
		
		## This Subfeature-Sequence may have some other subfeatures that localize to it.
		&writeSubfeaturesToBsml($bsmlBuilder,
					$featureTableElem,
					$genomeId,
					$sub2, 
					$sub2CrossReference->{$uniquename},
					$sub2Properties->{$uniquename},
					undef,
					undef,
					undef,
					undef,
					undef,
					undef,
					undef,
					undef,
					$database,
					$asmbl,
					$uniquename);	
	    }
	}
	
	## Store all analysis data in BSML <Link> elements
	foreach my $analysisArray ( @{$subfeatureAnalysisLookup->{$uniquename}} ){

	    ## 0 => analysis.program
	    ## 1 => cvterm.name

	    if (exists $qualifiedComputationalAnalysisLookup->{$analysisArray->[0]} ){
		## Only insert a <Link> for this <Feature> if we are processing this type of analysis.

		my $linkElem = $bsmlBuilder->createAndAddLink(
							      $featureElem,
							      'analysis',             # rel
							      "#$analysisArray->[0]", # href
							      $analysisArray->[1]     # role 
							      );
		
		if (!defined($linkElem)){
		    $logger->logdie("Could not create an 'analysis' <Link> element object for the feature with uniquename ".
				    "'$uniquename' with analysis '$analysisArray->[0]' role '$analysisArray->[1]' ".
				    "parent Sequence '$parentSequenceUniquename' while processing assembly with uniquename ".
				    "'$asmbl' from database '$database'");
		}
		## Keep track of the analysis types because later on we are going to have to
		## insert <Analysis> sections.
		$analysisLookup->{$analysisArray->[0]}++;
	    }
	}

	## Store all featureprop records in BSML <Attribute> elements
	foreach my $featurePropertyArray ( @{$subfeatureProperties->{$uniquename}} ){
	    
	    my $attributeElem = $bsmlBuilder->createAndAddBsmlAttribute( $featureElem,
									 $featurePropertyArray->[0],
									 $featurePropertyArray->[1]);
	    if (!defined($attributeElem)){
		$logger->logdie("Could not create <Attribute> for name '$featurePropertyArray->[0]' content '$featurePropertyArray->[1]' ".
				"for feature with uniquename '$uniquename' parent Sequence '$parentSequenceUniquename' while processing ".
				"assembly with uniquename '$asmbl' from database '$database'");
	    }
	}

	## Store all dbxref records in BSML <Cross-reference> elements
	foreach my $crossReferenceArray ( @{$subfeatureCrossReferenceData->{$uniquename}} ){

	    my $xrefElem = $bsmlBuilder->createAndAddCrossReference(
								    'parent'          => $featureElem,
								    'id'              => $bsmlBuilder->{'xrefctr'}++,
								    'database'        => $crossReferenceArray->[0],
								    'identifier'      => $crossReferenceArray->[1],
								    'identifier-type' => $crossReferenceArray->[2]
								    );
	    if (!defined($xrefElem)){
		$logger->logdie("Could not create <Cross-reference> with database '$crossReferenceArray->[0]' identifier ".
				"'$crossReferenceArray->[1]' identifier-type '$crossReferenceArray->[2]' ".
				"for feature with uniquename '$uniquename' parent Sequence '$parentSequenceUniquename' ".
				"while processing assembly with uniquename '$asmbl' from database '$database'");
	    }
	}

	## Store all GO assignment records in BSML <Attribute-list> sections
	foreach my $GOAssignmentArray ( @{$subfeatureGOAssignments->{$uniquename}} ){
	    
	    my $attributeList = [];

	    push( @{$attributeList},  { name    => 'GO',
					content => $GOAssignmentArray->[0]} );
	    
	    if (exists $GOAssignmentAttributes->{$GOAssignmentArray->[1]} ){
		
		foreach my $GOAssignmentAttributeArray ( @{$GOAssignmentAttributes->{$GOAssignmentArray->[1]}} ) {
		    my $name = $GOAssignmentAttributeArray->[0];
		    if (exists $evidenceCodesLookup->{$GOAssignmentAttributeArray->[0]}){
			$name = $evidenceCodesLookup->{$GOAssignmentAttributeArray->[0]};
		    }
		    
		    push( @{$attributeList},  { name    => $name,
						content => $GOAssignmentAttributeArray->[1]} );
		    
		}
	    }
	    
	    $featureElem->addBsmlAttributeList($attributeList);
	}

	## Store all non-GO assignment records in BSML <Attribute-list> sections
	foreach my $nonGOAssignmentArray ( @{$subfeatureNonGOAssignments->{$uniquename}} ){
	    
	    my $attributeList = [];

	    push( @{$attributeList},  { name    => $nonGOAssignmentArray->[0],
					content => $nonGOAssignmentArray->[1]} );
	    
	    if (exists $nonGOAssignmentAttributes->{$nonGOAssignmentArray->[2]} ){
		
		foreach my $nonGOAssignmentAttributeArray ( @{$nonGOAssignmentAttributes->{$nonGOAssignmentArray->[2]}} ) {
		    
		    push( @{$attributeList},  { name    => $nonGOAssignmentAttributeArray->[0],
						content => $nonGOAssignmentAttributeArray->[1]} );
		    
		}
	    }
	    
	    $featureElem->addBsmlAttributeList($attributeList);
	}
    }	
}

sub consolidateFeatureRelationships {

    my ($array) = @_;

    my $geneLookup={};
    my $transcriptLookup={};
    my $cdsLookup={};

    foreach my $array1 ( @{$array}){
	if ($array1->[1] eq 'transcript'){
	    push(@{$transcriptLookup->{$array1->[0]}}, [$array1->[2], $array1->[3]]);
	}
	elsif ($array1->[1] eq 'CDS'){
	    push(@{$cdsLookup->{$array1->[0]}}, [$array1->[2], $array1->[3] ]);
	}
	elsif ($array1->[1] eq 'gene'){
	    push(@{$geneLookup->{$array1->[0]}}, [$array1->[2], $array1->[3] ]);
	}
	else {
	    $logger->warn("Need to implement support for the case when ".
			    "the parent Feature type is '$array1->[1]'");
	}
    }
    

    ## Transfer all child features from the CDS to the transcript
    foreach my $transcript ( keys %{$transcriptLookup}){
	foreach my $transcriptArray ( @{$transcriptLookup->{$transcript}} ) {
	    if ($transcriptArray->[1] eq 'CDS'){
		if (exists $cdsLookup->{$transcriptArray->[0]}){
		    foreach my $cdsArray ( @{$cdsLookup->{$transcriptArray->[0]}} ){
			push(@{$transcriptLookup->{$transcript}}, $cdsArray);
		    }
		}
	    }
	}	    
    }


    ## Transfer all child features from the transcript to the gene
    foreach my $gene ( keys %{$geneLookup}){
	foreach my $geneArray ( @{$geneLookup->{$gene}} ) {
	    if ($geneArray->[1] eq 'transcript'){
		if (exists $transcriptLookup->{$geneArray->[0]}){
		    foreach my $transcriptArray ( @{$transcriptLookup->{$geneArray->[0]}} ){
			push(@{$geneLookup->{$gene}}, $transcriptArray);
		    }
		}
	    }
	}	    
    }
    
    return $geneLookup;
}

##------------------------------------------------------
## writeFeatureRelationshipsToBsml()
##
##------------------------------------------------------
sub writeFeatureRelationshipsToBsml {

    my ($bsmlBuilder, $featureRelationships, $assemblySequenceElem, $database, $asmbl) = @_;

    my $lookup = &consolidateFeatureRelationships($featureRelationships);

    ## We'll only allow features to be uniquely grouped.
    my $uniqueFeatures={};

    foreach my $geneId ( keys %{$lookup} ) {

	if (exists $uniqueFeatures->{$geneId}){
	    next;
	}

	## Store this feature in the hash so that will not be repeated.
	$uniqueFeatures->{$geneId}++;

	my $featureGroupElem = $bsmlBuilder->createAndAddFeatureGroup(
								      $assemblySequenceElem,  # <Sequence> element object reference
								      undef,        # id
								      "$geneId"     # groupset
								      );  
	
	if (!defined($featureGroupElem)){
	    $logger->logdie("Could not create <Feature-group> element object for uniquename '$geneId'");
	}
	
	
	## Create <Feature-group-member> element object
	my $featureGroupMemberElem = $bsmlBuilder->createAndAddFeatureGroupMember( $featureGroupElem,  # <Feature-group> element object reference
										   $geneId,    # featref
										   'gene'      # feattype
										   );
	if (!defined($featureGroupMemberElem)){
	    $logger->logdie("Could not create <Feature-group-member> BSML element object for ".
			    "<Feature> with id '$geneId' class 'gene' while processing ".
			    "assembly with uniquename '$asmbl' from database '$database'");
	}

	

	foreach my $subfeatureArray ( @{$lookup->{$geneId}} ){

	    my $subjectUniquename = $subfeatureArray->[0];
	    my $subjectClass = $subfeatureArray->[1];
	    
	    if (exists $uniqueFeatures->{$subjectUniquename}){
		next;
	    }

	    ## Store this feature in the hash so that will not be repeated.
	    $uniqueFeatures->{$subjectUniquename}++;

	    ## Create <Feature-group-member> element object
	    my $featureGroupMemberElem2 = $bsmlBuilder->createAndAddFeatureGroupMember( $featureGroupElem,  # <Feature-group> element object reference
											$subjectUniquename,          # featref
											$subjectClass
											);
	    if (!defined($featureGroupMemberElem2)){
		$logger->logdie("Could not create <Feature-group-member> BSML element object ".
				"for <Feature> with id '$subjectUniquename' class '$subjectClass' ".
				"to be grouped with <Feature> with id '$geneId' while processing ".
				" with uniquename '$asmbl' from database '$database'");
	    }
	}
    }
}


##------------------------------------------------------
## writeAnalysesToBsml()
##
##------------------------------------------------------
sub writeAnalysesToBsml {

    my ($prism, $bsmlBuilder, $analysisLookup, $asmbl, $database) = @_;
    
    my $analysisData = $prism->allAnalysisData();
    
    if ($logger->is_debug()){
	$logger->debug("analysisData:". Dumper $analysisData);
    }
    
    my $analysisProperties = $prism->allAnalysisProperties();
    
    if ($logger->is_debug()){
	$logger->debug("analysisProperties:". Dumper $analysisProperties);
    }

    foreach my $program (sort keys %{$analysisLookup} ){

	if (exists $analysisData->{$program}){
	    
	    my $analysisElem = $bsmlBuilder->createAndAddAnalysis( 'id' => $program );
	    
	    if (!defined($analysisElem)){
		$logger->logdie("Could not create <Analysis> element object for program '$program' ".
				"while processing assembly with uniquename '$asmbl' from database ".
				"'$database'");
	    }

	    my $analysisArray = $analysisData->{$program};

	    #-----------------------------------------------------------------------------------
	    # Add the //Analysis/@program attribute value
	    #
	    #-----------------------------------------------------------------------------------
	    my $programAttributeElem = $bsmlBuilder->createAndAddBsmlAttribute(
									       $analysisElem,
									       'program',
									       $program
									       );
	    if (!defined($programAttributeElem)) {
		$logger->logdie("Could not create <Attribute> element object for name 'program' ".
				"content '$program' while processing assembly with uniquename ".
				"'$asmbl' from database '$database'");
	    }
	    
	    #-----------------------------------------------------------------------------------
	    # Add the //Analysis/@programversion attribute value
	    #
	    #-----------------------------------------------------------------------------------
	    my $programversionAttributeElem = $bsmlBuilder->createAndAddBsmlAttribute(
										      $analysisElem,
										      'version',
										      $analysisArray->[0]
										      );
	    
	    if (!defined($programversionAttributeElem)) {
		$logger->logdie("Could not create <Attribute> element object for name 'programversion' ".
				"content '$analysisArray->[0]' while processing assembly with uniquename ".
				"'$asmbl' from database '$database'");
	    }

	    #-----------------------------------------------------------------------------------
	    # Add the //Analysis/@sourcename attribute value
	    #
	    #-----------------------------------------------------------------------------------
	    my $sourcenameAttributeElem = $bsmlBuilder->createAndAddBsmlAttribute(
										  $analysisElem,
										  'sourcename',
										  $analysisArray->[1]
										  );

	    if (!defined($sourcenameAttributeElem)) {
		$logger->logdie("Could not create <Attribute> element object for name 'sourcename' ".
				"content '$analysisArray->[1]' while processing assembly with uniquename ".
				"'$asmbl' from database '$database'");
	    }

	    #-----------------------------------------------------------------------------------
	    # Add the //Analysis/@description attribute value
	    #
	    #-----------------------------------------------------------------------------------
	    my $descriptionAttributeElem = $bsmlBuilder->createAndAddBsmlAttribute(
										   $analysisElem,
										   'description',
										   $analysisArray->[2]
										   );

	    if (!defined($sourcenameAttributeElem)) {
		$logger->logdie("Could not create <Attribute> element object for name 'sourcename' ".
				"content '$analysisArray->[2]' while processing assembly with uniquename ".
				"'$asmbl' from database '$database'");
	    }

	    my $nameAttributeCreated=0;

	    if (exists $analysisProperties->{$analysisArray->[3]}){

		foreach my $analysisPropertyArray ( @{$analysisProperties->{$analysisArray->[3]}} ){

		    if ($analysisPropertyArray->[0] eq 'name'){
			$nameAttributeCreated++;
		    }

		    my $attributeElem = $bsmlBuilder->createAndAddBsmlAttribute(
										$analysisElem,
										$analysisPropertyArray->[0],
										$analysisPropertyArray->[1]
										);
		    
		    if (!defined($sourcenameAttributeElem)) {
			$logger->logdie("Could not create <Attribute> element object for name '$analysisPropertyArray->[0]' ".
					"content '$analysisPropertyArray->[1]' while processing assembly with uniquename ".
					"'$asmbl' from database '$database'");
		    }
		    
		}
	    }

	    if ($nameAttributeCreated == 0 ){
		#-----------------------------------------------------------------------------------
		# Add the //Analysis/@name attribute value
		#
		#-----------------------------------------------------------------------------------
		my $nameAttributeElem = $bsmlBuilder->createAndAddBsmlAttribute(
										$analysisElem,
										'name',
										$program
										);
		if (!defined($programAttributeElem)) {
		    $logger->logdie("Could not create <Attribute> element object for name 'name' ".
				    "content '$program' while processing assembly with uniquename ".
				    "'$asmbl' from database '$database'");
		}
		
	    }

	}
	else {
	    $logger->warn("program '$program' does not exist in analysis while processing ".
			    "assembly with uniquename '$asmbl' from database '$database'");
	}
    }
}


##------------------------------------------------------
## writeComputationalAnalysesToBsml()
##
##------------------------------------------------------
sub writeComputationalAnalysesToBsml {

    my ($prism, $bsmlBuilder, $analysisLookup, $asmbl, $database) = @_;


    my $programToMoleculeType = { 'ber' => 'aa',
				  'PROSITE' => 'aa',
				  'HMM2' => 'aa',
				  'INTERPRO' => 'aa',
				  'NCBI_COG' => 'aa',
			      };
    
    my $programToClassType = { 'ber' => 'polypeptide',
			       'PROSITE' => 'polypeptide',
			       'HMM2' => 'polypeptide',
			       'NCBI_COG' => 'polypeptide',
			   };

    my $computationalAnalysisData = $prism->allComputationalAnalysisDataByAssembly($asmbl, $qualifiedComputationalAnalysisLookup);
    
    if ($logger->is_debug()){
	$logger->debug("computationalAnalysisData:". Dumper $computationalAnalysisData);
    }
    
    my $subjectCrossReferenceLookup = $prism->allComputationalAnalysisSubjectsCrossReference($asmbl,$qualifiedComputationalAnalysisLookup);
    
    if ($logger->is_debug()){
	$logger->debug("subjectCrossReferenceLookup:". Dumper $subjectCrossReferenceLookup);
    }

    my $matchPartPropertiesLookup = $prism->allMatchPartPropertiesLookup($asmbl,$qualifiedComputationalAnalysisLookup);
    
    if ($logger->is_debug()){
	$logger->debug("matchPartPropertiesLookup:". Dumper $matchPartPropertiesLookup);
    }

    ## We'll ensure that the <Sequence> for the sequence stub is only ever inserted into the BSML file once.
    my $sequenceStubLookup = {};

    foreach my $program (keys %{$computationalAnalysisData} ){ 
	
	my $moleculeType = $programToMoleculeType->{$program};
	my $subjectClass = $programToClassType->{$program};

	if (exists $analysisLookup->{$program}){
	    ## We've inserted features and their links to this type of computational analysis into the BSML tree
	    ## so we should go ahead and insert the pairwise alignment data.

	    foreach my $queryUniquename (keys %{$computationalAnalysisData->{$program}} ){

		foreach my $subjectUniquename ( keys %{$computationalAnalysisData->{$program}->{$queryUniquename}} ){

		    ## Example BSML encoding for BER analysis:
		    ##
		    ## <Seq-pair-alignment refseq="bcl.CDS.2941.0" compseq="PIR:G97348" class="match">
		    ##   <Seq-pair-run compcomplement="0" runlength="267" refpos="237944" comprunlength="88" refcomplement="1" runscore="19" comppos="0" runprob="2.4e-25">
		    ##      <Attribute name="class" content="match_part"></Attribute>
		    ##      <Attribute name="date" content="Aug  2 2005 11:51AM"></Attribute>
		    ##      <Attribute name="percent_identity" content="61.797752"></Attribute>
		    ##      <Attribute name="percent_similarity" content="85.393257"></Attribute>
		    ##   </Seq-pair-run>
		    ##   <Link rel="analysis" href="#BER" role="computed_by"></Link>
		    ## </Seq-pair-alignment>		    
		    
		    my $seqPairAlignmentElem = &writeSeqPairAlignmentToBsml($bsmlBuilder,
									    $queryUniquename,
									    $subjectUniquename,
									    $asmbl,
									    $database,
									    $program);

		    ## This is what we've got at this point:
		    ##
		    ## <Seq-pair-alignment refseq="bcl.CDS.2941.0" compseq="PIR:G97348" class="match">
		    ##   <Link rel="analysis" href="#BER" role="computed_by"></Link>
		    ## </Seq-pair-alignment>
		    ##

		    if (! exists $sequenceStubLookup->{$subjectUniquename} ) {
			## Insert a <Sequence> stub into the BSML tree for this subject sequence.
			&writeSubjectSequenceStubToBsml($bsmlBuilder,
							$subjectUniquename,
							$queryUniquename,
							$moleculeType,
							$subjectClass,
							$asmbl,
							$database,
							$program,
							$subjectCrossReferenceLookup->{$subjectUniquename}
							);
		    }
		    $sequenceStubLookup->{$subjectUniquename}++;

		    ## Now we need to insert the <Seq-pair-run> elements.
		    &writeSeqPairRunToBsml( $bsmlBuilder,
					    $program,
					    $queryUniquename,
					    $subjectUniquename,
					    $asmbl,
					    $database,
					    $seqPairAlignmentElem,
					    $matchPartPropertiesLookup,
					    $computationalAnalysisData->{$program}->{$queryUniquename}->{$subjectUniquename}
					    );
		}
	    }
	}
    }
}


##----------------------------------------------------
## writeSeqPairRunToBsml()
##
##----------------------------------------------------
sub writeSeqPairRunToBsml {

    my ($bsmlBuilder, $program, $queryUniquename, $subjectUniquename, $asmbl, $database, 
	$seqPairAlignmentElem, $matchPartPropertiesLookup, $compAnalysisArray) = @_;

    ## Example <Seq-pair-run> BSML encoding for BER analysis:
    ##
    ##   <Seq-pair-run compcomplement="0" runlength="267" refpos="237944" comprunlength="88" refcomplement="1" runscore="19" comppos="0" runprob="2.4e-25">
    ##      <Attribute name="class" content="match_part"></Attribute>
    ##      <Attribute name="date" content="Aug  2 2005 11:51AM"></Attribute>
    ##      <Attribute name="percent_identity" content="61.797752"></Attribute>
    ##      <Attribute name="percent_similarity" content="85.393257"></Attribute>
    ##   </Seq-pair-run>
    ##

    foreach my $array ( @{$compAnalysisArray} ) {

	my $seqPairRunElem = $seqPairAlignmentElem->returnBsmlSeqPairRunR( $seqPairAlignmentElem->addBsmlSeqPairRun() );

	if (!defined($seqPairRunElem)){
	    $logger->logdie("Could not create <Seq-pair-run> element object while processing query '$queryUniquename' ".
			    "subject '$subjectUniquename' program '$program' assembly '$asmbl' database '$database'");
	}

	my $refcomplement = ($array->[2] == 1) ? 0 : 1 ;
	my $compcomplement = ($array->[5] == 1) ? 0 : 1 ;
	my $runlength = ($array->[1] = $array->[0] + 1);
	my $comprunlength = ($array->[4] = $array->[3] + 1);
	
 	$seqPairRunElem->setattr( 'compcomplement', $compcomplement );
	$seqPairRunElem->setattr( 'runlength', $runlength );
	$seqPairRunElem->setattr( 'comprunlength', $comprunlength );
	$seqPairRunElem->setattr( 'refcomplement', $refcomplement );
	$seqPairRunElem->setattr( 'refpos', $array->[0] );
	$seqPairRunElem->setattr( 'comppos', $array->[3] );
	$seqPairRunElem->setattr( 'runprob', $array->[6] );
	$seqPairRunElem->setattr( 'runscore', $array->[7] );

	my $classAttributeElem = $bsmlBuilder->createAndAddBsmlAttribute( $seqPairRunElem,
									  'class',
									  'match_part' );
	
	if (!defined($classAttributeElem)){
	    $logger->logdie("Could not create <Attribute> for name 'class' content 'match_part' ".
			    "while processing query '$queryUniquename' subject '$subjectUniquename' ".
			    "program '$program' assembly '$asmbl' database '$database'");
	}

	if (defined($array->[9])){
	    my $percentIdentityAttributeElem = $bsmlBuilder->createAndAddBsmlAttribute( $seqPairRunElem,
											'percent_identity',
											$array->[9] );
	    
	    if (!defined($percentIdentityAttributeElem)){
		$logger->logdie("Could not create <Attribute> for name 'percent_identity' content '$array->[9]' ".
				"while processing query '$queryUniquename' subject '$subjectUniquename' ".
				"program '$program' assembly '$asmbl' database '$database'");
	    }
	}


	if (defined($array->[10])){
	    my $residuesAttributeElem = $bsmlBuilder->createAndAddBsmlAttribute( $seqPairRunElem,
										 'residues',
										 $array->[10] );
	    
	    if (!defined($residuesAttributeElem)){
		$logger->logdie("Could not create <Attribute> for name 'residues' content 'array->[10]' ".
				"while processing query '$queryUniquename' subject '$subjectUniquename' ".
				"program '$program' assembly '$asmbl' database '$database'");
	    }
	}
	
	if ( exists $matchPartPropertiesLookup->{$array->[11]} ) {
	    foreach my $attributeArray ( @{$matchPartPropertiesLookup->{$array->[11]}} ) {
		
		my $attributeElem = $bsmlBuilder->createAndAddBsmlAttribute( $seqPairRunElem,
									     $attributeArray->[0],
									     $attributeArray->[1] );
		
		if (!defined($classAttributeElem)){
		    $logger->logdie("Could not create <Attribute> for name '$attributeArray->[0]' content '$attributeArray->[1]' ".
				    "while processing query '$queryUniquename' subject '$subjectUniquename' ".
				    "program '$program' assembly '$asmbl' database '$database'");
		}
		
	    }
	}
    }
}


##----------------------------------------------------
## writeSeqPairAlignmentToBsml()
##
##----------------------------------------------------
sub writeSeqPairAlignmentToBsml {

    my ($bsmlBuilder, $queryUniquename, $subjectUniquename, $asmbl, $database, $program) = @_;

    # Determine if the query name and the dbmatch name are a unique pair in the document
    my $alignmentPairList = BSML::BsmlDoc::BsmlReturnAlignmentLookup( $queryUniquename, $subjectUniquename );

    my $seqPairAlignmentElem;

    if( $alignmentPairList ){
	$seqPairAlignmentElem = $alignmentPairList->[0];
    }
    else {
	## Create a <Seq-pair-alignment> element object
	$seqPairAlignmentElem = $bsmlBuilder->returnBsmlSeqPairAlignmentR( $bsmlBuilder->addBsmlSeqPairAlignment() );
	
	if (!defined($seqPairAlignmentElem)){
	    $logger->logdie("Could not create <Seq-pair-alignment> element object for query '$queryUniquename' subject '$subjectUniquename' ".
			    "while processing the assembly with uniquename '$asmbl' from database '$database'");
	}
	## Add the essential attributes
	$seqPairAlignmentElem->setattr( 'refseq',  $queryUniquename );
	$seqPairAlignmentElem->setattr( 'compseq', $subjectUniquename );
	$seqPairAlignmentElem->setattr( 'class',   'match'   );
	
	## Store reference to the <Seq-pair-alignment>
	BSML::BsmlDoc::BsmlSetAlignmentLookup( $queryUniquename, $subjectUniquename, $seqPairAlignmentElem );
	
    }
    
    ## Create the <Link> to associate this <Seq-pair-alignment> with the <Analysis> element.
    my $linkElem = $bsmlBuilder->createAndAddLink(
						  $seqPairAlignmentElem,  # <Seq-pair-alignment> element object reference
						  'analysis',         # rel
						  "#$program",        # href
						  'computed_by'      # role
						  );
    
    if (!defined($linkElem)){
	$logger->logdie("Could not create a <Link> element object for rel 'analysis' href '$program' role 'computed_by' ".
			"while processing query '$queryUniquename' subject '$subjectUniquename' program '$program' ".
			"- assembly '$asmbl' database '$database'");
    }
    
    return $seqPairAlignmentElem;
}

##----------------------------------------------------
## writeSubjectSequenceStubToBsml()
##
##----------------------------------------------------
sub writeSubjectSequenceStubToBsml {

    my ($bsmlBuilder, $subjectUniquename, $queryUniquename, $moleculeType, $subjectClass,
	$asmbl, $database, $program, $subjectCrossReferenceArray) = @_;
    
    ## Create <Sequence> element object reference for the compseq (subject)
    my $subjectSequenceElem = $bsmlBuilder->createAndAddSequence( $subjectUniquename, # id
								  undef,              # title
								  undef,              # length
								  $moleculeType,      # molecule
								  $subjectClass,      # class
								  );

    if (!defined($subjectSequenceElem)){
	$logger->logdie("Could not create <Sequence> for subject '$subjectUniquename' while processing ".
			"program '$program' query '$queryUniquename' assembly '$asmbl' database '$database'");
    }
    
    ## Create the <Link> to associate this <Sequence> stub with the <Analysis> element.
    my $linkElem = $bsmlBuilder->createAndAddLink(
						  $subjectSequenceElem,  # <Seq-pair-alignment> element object reference
						  'analysis',            # rel
						  "#$program",           # href
						  'input_of'             # role
						  );
    
    if (!defined($linkElem)){
	$logger->logdie("Could not create a <Link> element object for rel 'analysis' href '$program' role 'input_of' ".
			"while processing query '$queryUniquename' subject '$subjectUniquename' program '$program' ".
			"- assembly '$asmbl' database '$database'");
    }

    if ($subjectUniquename eq 'PIR:B97000'){
	$logger->fatal(Dumper $subjectCrossReferenceArray);
    }


    foreach my $xrefArray ( @{$subjectCrossReferenceArray} ){
	
	## Create <Cross-reference> object
	my $xrefElem = $bsmlBuilder->createAndAddCrossReference( parent            => $subjectSequenceElem,
								 id                => $bsmlBuilder->{'xrefctr'}++,
								 database          => $xrefArray->[0],
								 identifier        => $xrefArray->[1],
								 'identifier-type' => $xrefArray->[2],
								 );
	
	if (!defined($xrefElem)){
	    $logger->logdie("Could not create <Cross-reference> element object with database '$xrefArray->[0]' ".
			    "identifier '$xrefArray->[1]' identifier-type '$xrefArray->[2] ".
			    "for subject with uniquename '$subjectUniquename' while processing query with uniquename ".
			    "'$queryUniquename' assembly '$asmbl' database '$database'");
	}
    }
}


##----------------------------------------------------
## createSequence()
##
##----------------------------------------------------
sub createSequence {

    my ($bsmlBuilder, $uniquename, $length, $class, $genomeId, $molecule, $topology) = @_;

    if (!defined($molecule)){
	$molecule = 'dna';
    }

    if (!defined($topology)){
	$topology = 'linear';
    }

    my $sequenceElem = $bsmlBuilder->createAndAddExtendedSequenceN(
								   'id'       => $uniquename, 
								   'title'    => undef,
								   'length'   => $length,
								   'molecule' => $molecule,
								   'locus'    => undef,
								   'dbsource' => undef,
								   'icAcckey' => undef,
								   'topology' => $topology,
								   'strand'   => undef,
								   'class'    => $class
								   );
    
    if (!defined($sequenceElem)){
	$logger->logdie("Could not create a <Sequence> element object for sequence with uniquename ".
			"'$uniquename' class '$class' from database '$database'");
    }
    
    ## The <Sequence> will now be explicitly linked with the <Genome>
    my $linkElem = $bsmlBuilder->createAndAddLink(
						  $sequenceElem,
						  'genome',       # rel
						  "#$genomeId"    # href
						  );
    
    if (!defined($linkElem)){
	$logger->logdie("Could not create a 'genome' <Link> element object for sequence ".
			"with uniquename '$uniquename' from database '$database'");
    }
    
    return $sequenceElem;
}


#--------------------------------------------------------
# verify_and_set_outdir()
#
#--------------------------------------------------------
sub verify_and_set_outdir {

    my ($outdir) = @_;

    if (!defined($outdir)){
	$outdir = ".";
    }

    
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
    
    return $outdir;
    
}#end sub verify_and_set_outdir()



#----------------------------------------------------------------
# print_usage()
#
#----------------------------------------------------------------
sub print_usage {

    print STDERR "\nSAMPLE USAGE:  $0 [--asmbl] [--bsml_file_name] --database --database_type [--debug] [--fastadir] [-h] [--ignore_go] [--ignore_evcodes] [--ignore_non_go] [--logfile] [-m] [--outdir] --server --password [--polypeptides_only] --username\n".
    "  --asmbl          = Optional - identifier for assembly that should be extracted (default - all available assemblies will be extracted)\n".
    "  --bsml_file_name = Optional - output BSML filename (default will be based on the --asmbl value(s))\n".
    "  --database       = Target chado database name\n".
    "  --database_type  = Relational database management system e.g. sybase or postgresql\n".
    "  --debug          = Optional - Coati::Logger log4perl logging level.  Default debug level is 0\n".
    "  --fastadir       = Optional - Directory where the multi-FASTA file will be written to. Default is current working directory\n".
    "  -h|--help        = Print this usage help statement\n".
    "  --ignore_go      = Optional - do not extract GO, GO evidence\n".
    "  --ignore_evcodes = Optional - do not extract evidence codes\n".
    "  --ignore_non_go  = Optional - do not extract TIGR_roles etc.\n".
    "  --logfile        = Optional - Coati::Logger Log4perl log file.  Default is /tmp/chado2bsml.pl.log\n".
    "  -m|--man         = Optional - Podusage for this script\n".
    "  --outdir         = Optional - Directory to write the BSML. Default is current working directory\n".
    "  --password       = Database password\n".
    "  --polypeptides_only = Optional - only extract the assembly and polypeptides\n".
    "  --server         = Name of server on which the database resides\n".
    "  --username       = Database username\n";
    exit(1);

}


#-------------------------------------------------------------------------------------------------
# writeBSMLDocument()
#
#-------------------------------------------------------------------------------------------------
sub writeBSMLDocument {

    my ($bsmlBuilder, $backup) = @_;

    my $bsmldocument = $bsmlBuilder->{'doc_name'};

    if (-e $bsmldocument){
	## If bsml document exists, copy it to .bak
	## Default behavior is to NOT backup files (bug 2052)

	if (defined($backup)){
	    my $bsmlbak = $bsmldocument . '.bak';
	    rename ($bsmldocument, $bsmlbak);
	    
	    chmod (0666, $bsmlbak);
	    
	    $logger->info("Saving '$bsmldocument' as '$bsmlbak'");
	}
    }

    $logger->info("Writing BSML document '$bsmldocument'");
    
    $bsmlBuilder->write("$bsmldocument");
    
    
    if(! -e "$bsmldocument"){
	$logger->logdie("File not created '$bsmldocument'");
    }
    else {
	chmod (0777, "$bsmldocument");
    }

}

#---------------------------------------------------------------
# createMultiFASTAFile()
#
#---------------------------------------------------------------
sub createMultiFASTAFile {

    my ($fastaSequenceLookup, $fastadir, $db, $backup) = @_;

    foreach my $asmbl_id (sort keys %{$fastaSequenceLookup} ){ 

	foreach my $class (sort keys %{$fastaSequenceLookup->{$asmbl_id}}){
	    
	    my $fastafile = $fastadir . "/" . $db . '_' . $asmbl_id . '_' .  $class . ".fsa";
	    
	    ## If multi-fasta file already exists, let's back it up...
	    if (-e $fastafile){

		## Default behavior is to NOT backup files (bug 2052)
		if (defined($backup)){

		    my $fastabak = $fastafile . '.bak';
		    copy($fastafile, $fastabak);
		    $logger->info("Copying '$fastafile' to '$fastabak'");
		}
	    }

	    open (FASTA, ">$fastafile") or $logger->logdie("Can't open file $fastafile for writing: $!");

	    foreach my $sequence ( @{$fastaSequenceLookup->{$asmbl_id}->{$class}} ) {
		
		my $fastaout = &fasta_out($sequence->[0], $sequence->[1]);
		print FASTA $fastaout;
		
	    }

	    close FASTA;
	    chmod 0666, $fastafile;
	}
    }
}


#-------------------------------------------------------------------------
# fasta_out()
#
#-------------------------------------------------------------------------
sub fasta_out {

    #This subroutine takes a sequence name and its sequence and
    #outputs a correctly formatted single fasta entry (including newlines).
    
    my ($seq_name, $seq) = @_;

    my $fasta=">"."$seq_name"."\n";
    $seq =~ s/\s+//g;
    for(my $i=0; $i < length($seq); $i+=60){
	my $seq_fragment = substr($seq, $i, 60);
	$fasta .= "$seq_fragment"."\n";
    }
    return $fasta;

}

##----------------------------------------------------------
## storeBsmlAttributeList()
##
##----------------------------------------------------------
sub storeBsmlAttributeList {

    my ($element, $name, $content) = @_;
    
    my $arr = [];
    
    push ( @{$arr}, { name    => $name,
		      content => $content});
    
    $element->addBsmlAttributeList($arr);
    
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

sub addBsmlAttributeToBsml {

    my ($bsmlBuilder, $bsmlElement, $name, $content) = @_;

    my $attributeBSMLElem = $bsmlBuilder->createAndAddBsmlAttribute( $bsmlElement, $name, $content);

    if (!defined($attributeBSMLElem)) {
	$logger->warn("Could not create <Attribute> BSML element for name '$name' content '$content'");
	return 0;
    }
    
    return 1;
}

sub checkIsPartial {

    my ($is_partial) = @_;

    my $open;

    if (defined($is_partial)){

	if ($logger->is_debug()){
	    $logger->debug("is_fmin_partial or is_fmax_partial '$is_partial'");
	}

	if ($is_partial == 0){
	    $open = undef;
	} elsif ($is_partial == 1){
	    $open = $is_partial;
	} else {
	    $logger->logdie("Unacceptable value for is_fmin_partial ".
			    "or is_fmax_partial '$is_partial'");
	}
    }

    return $open;
}		
