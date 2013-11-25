#!/usr/local/bin/perl
##------------------------------------------------------------------------
## $Author: jcrabtree $
## $Date: 2009-09-29 23:24:26 -0400 (Tue, 29 Sep 2009) $
## $Revision: 4225 $
## $HeadURL$
#
#---------------------------------------------------------------------------------------
=head1 NAME

legacy2bsml.pl - Migrates Nt/Prok/Euk legacy databases to BSML documents

=head1 SYNOPSIS

USAGE:  legacy2bsml.pl [-B] -D database [-F fastadir] -P password -U username [-M mode] -a asmbl_id [--alt_database] [-d debug_level] [--rdbms] [--host] [--exclude_genefinders] [-h] [--input_id_mapping_directories]  [--input_id_mapping_file] [--id_repository] [--idgen_identifier_version] [--include_genefinders] [-l log4perl] [-m] [--model_list_file] [--no_die_null_sequences] [--no_id_generator] [--no-misc-features] [--no-repeat-features] [--no-transposon-features] [-o outdir]  [--output_id_mapping_file] [-q sequence_type] --schema_type [--sourcename] [--tu_list_file] [--alt_species] [--repeat-mapping-file]

=head1 OPTIONS

=over 8

=item B<--backup,-B>

If specified, will backup existing output .bsml and .fsa files

=item B<--username,-U>

Database username

=item B<--password,-P>

Database password

=item B<--database,-D>

Source legacy organism database name

=item B<--mode,-M>

1=Write Gene Model to BSML document  (Default)
2=Write Gene Model and Computational Evidence to BSML document
3=Write Computational Evidence to BSML document

=item B<--asmbl_id,-a>

User must specify the appropriate assembly.asmbl_id value

=item B<--fastadir,-F>

Optional  - fasta directory for the organism

=item B<--rdbms>

Optional  - Relational database management system
    currently supports Sybase for euk, prok and nt_prok schemas
                       Mysql for euk, prok
Default: Sybase (if nothing specified)

=item B<--host>
    
Optional  - Server housing the database
Default   - SYBTIGR (if nothing specified)

=item B<--help,-h>

Print this help

=item B<--man,-m>

Display pod2usage man pages for this script

=item B<--sequence_type,-q>

Sequence type of main <Sequence> e.g. SO:contig

=item B<--schema_type>

Valid alternatives: euk, prok, ntprok

=item B<--log4perl,-l>

Optional - Log4perl log file.  Defaults are:
           If asmbl_list is defined /tmp/legacy2bsml.pl.database_$database.asmbl_id_$asmbl_id.log
           Else /tmp/legacy2bsml.pl.database_$database.pid_$$.log

=item B<--outdir,-o>

Optional - Output directory for bsml document.  Default is current working directory

=item B<--schema,-s>

Optional - Performs XML schema validation

=item B<--dtd,-t>

Optional - Performs XML DTD validation

=item B<--exclude-genefinders>

Optional - User can specify which gene finder data types to exclude from the migration.  Default is to migrate all gene finder data.

=item B<--include-genefinders>

Optional - User can specify which gene finder data types to include in the migration.  Default is to migrate all gene finder data.

=item B<--model_list_file>

Optional - User can provide a file containing a list of new-line separated model identifiers.  Only gene models for which these qualified models are a part of, propagated into the BSML file  Default behaviour: all models returned by the standard Prism API query shall be processed.

=item B<--no-misc-features>

Optional - User can specify that no miscellaneous feature types should be extracted from the legacy annotation database.  Default is to migrate all miscellaneous feature types.

=item B<--no-repeat-features>

Optional - User can specify that no repeat feature types should be extracted from the legacy annotation database.  Default is to migrate all repeat feature types.

=item B<--no-transposon-features>

Optional - User can specify that no transposon feature types should be extracted from the legacy annotation database.  Default is to migrate all transposon feature types.

=item B<--tu-list-file>

Optional - User can provide a file containing a list of new-line separated TU identifiers.  Only these TUs will be processed by legacy2bsml.pl.  Default behaviour: all TUs returned by the standard Prism API query shall be processed.

=item B<--alt_database>

Optional - User can specify a database prefix which will override the default legacy annotation database name

=item B<--alt_species>

Optional - User can specify an override value for species

=item B<--no_id_generator>

Optional - Do not call IdGenerator services

=item B<--id_repository>

Optional - IdGenerator compliant directory (must contain valid_id_repository file).  Default is current working directory

=item B<--input_id_mapping_files>

Optional - Comma-separated list of files containing old-identifier to new-identifier mappings.  The default file will be {$outdir}/legacy2bsml.pl.{$database}_{$asmbl_id}_assembly_{$schema_type}.bsml.idmap

=item B<--input_id_mapping_directories>

Optional - Comma-separated list of directories that may contain ID mapping files with file extension .idmap.  Default directories will be is /tmp

=item B<--output_id_mapping_file>

Optional - File to which new ID mappings will be written.  The default file will be {$outdir}/legacy2bsml.pl.{$database}_{$asmbl_id}_assembly_{$schema_type}.bsml.idmap

=item B<--idgen_identifier_version>

Optional - The user can override the default version value appended to the feature and sequence identifiers (default is 0)

=item B<--no_die_null_sequences>

Optional - If specified, will force legacy2bsml.pl to continue execution even if sequences are null for certain feat_types.

=item B<--sourcename>

Optional - User can specify the value to store in the Analysis Attributes for tag name.  Default value is the current working directory.

=back

=head1 DESCRIPTION

legacy2bsml.pl - Migrates Euk legacy datasets to Chado schema

=head1 CONTACT

Jay Sundaram (sundaram@tigr.org)

=cut

use strict;


use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Digest::MD5 qw(md5);
use Config::IniFiles;
use Coati::Logger;
use BSML::BsmlBuilder;
use File::Copy;
use File::Basename;
use Annotation::Features::Repeat::IdMapper;
use Annotation::Gopher::EventMap::FileReader;
use Annotation::SequenceUtil;
use Annotation::Fasta::FastaBuilder;
use Annotation::IdGenerator::Ergatis::Util;
use Annotation::BSML::Builder::EpitopeWriter;
use Annotation::SequenceDeriver;

## Do not buffer output stream
$| = 1;

## GOPHER identifier value length
my $GOPHER_ID_LENGTH = 13;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------
my ($database, $username, $password, $debug_level, $help, $man, $logfile, $asmbl_id, $fastadir,
    $outdir, $features, $mode, $backup, $sequence_type, $exclude_genefinder,
    $include_genefinder, $no_misc_features, $no_repeat_features, $no_transposon_features, $schema_type,
    $alt_species, $alt_database, $tu_list_file, $model_list_file, 
    $noIdGenerator, $idRepository, $inputIdMappingFile, $outputIdMappingFile, $inputIdMappingDirectories, $bsmlDocName,
    $noDieNullAsmFeatureSequence, $idgen_identifier_version,
    $sourcename, $host, $rdbms, $repeatMappingFile,
    $gopherFile); 

my $results = GetOptions (
			  'username|U=s'       => \$username, 
			  'password|P=s'       => \$password,
			  'database|D=s'       => \$database,
			  'asmbl_id|a=s'       => \$asmbl_id,
			  'fastadir|F=s'       => \$fastadir,
			  'debug_level|d=s'    => \$debug_level,
			  'help|h'             => \$help,
			  'man|m'              => \$man,
			  'log4perl|l=s'       => \$logfile,
			  'outdir|o=s'         => \$outdir,
			  'features|f=s'       => \$features,
			  'mode|M=s'           => \$mode,
			  'schema_type=s'      => \$schema_type,
              'host=s'             => \$host,
              'rdbms=s'            => \$rdbms,
			  'backup|B'           => \$backup,
			  'sequence_type|q=s'  => \$sequence_type,
			  'exclude_genefinders=s' => \$exclude_genefinder,
			  'include_genefinders=s' => \$include_genefinder,
			  'no-misc-features=s'    => \$no_misc_features,
			  'no-repeat-features=s'  => \$no_repeat_features,
			  'no-transposon-features=s' => \$no_transposon_features,
			  'alt_database=s'           => \$alt_database,
			  'alt_species=s'            => \$alt_species,
			  'tu_list_file=s'           => \$tu_list_file,
			  'model_list_file=s'        => \$model_list_file,
			  'no_id_generator=s'        => \$noIdGenerator,
			  'id_repository=s'          => \$idRepository,
			  'input_id_mapping_files=s' => \$inputIdMappingFile,
			  'output_id_mapping_file=s' => \$outputIdMappingFile,
			  'input_id_mapping_directories=s'  => \$inputIdMappingDirectories,
			  'bsml_doc_name=s' => \$bsmlDocName,
			  'no_die_null_sequences=s'         => \$noDieNullAsmFeatureSequence,
			  'idgen_identifier_version=s'      => \$idgen_identifier_version,
			  'sourcename=s'      => \$sourcename,
			  'repeat_id_mapping_file=s'      => \$repeatMappingFile,
			  'gopher_id_mapping_file=s'      => \$gopherFile
			  );

##
## Global variables declared here
##
my $logger;
my $validSchemaTypes;
my $validModeTypes;
my $schemaTypeToConf;
my $classMappingLookup;
my $schemaTypeToGeneticCodeLookup;
my $eukSequenceTypes;
my $prokSequenceTypes;
my $ntprokSequenceTypes;
my $noDieNullAsmFeatureSequenceLookup;
my $schemaTypeToSequenceTypes;
my $accessionDatabaseLookup;
my $rnaFeatureTypes;
my $ntprokRnaFeatureTypes;
my $schemaTypeToRnaFeatureTypes;
my $peptideScoreTypeLookup;
my $identXrefTypeLookup;
my $schemaTypeToGoRoleFeatureType;
my $berScoreTypeLookup;
my $hmm2ScoreTypeLookup;
my $prositeScoreTypeLookup;
my $computeScoreTypeLookup;
my $prokSchemaTypeToFeature;
my $prokOrfAttributeAttTypes;
my $legacyAnnoAttTypes;
my $prokCdsOrfAttributeAttTypes;
my $berEvTypeLookup;
my $hmm2EvTypeLookup;
my $cogEvTypeLookup;
my $prositeEvTypeLookup;
my $computeEvTypeLookup;
my $cloneInfoTypes;
my $cloneInfoAnnotationTypes;    
my $cloneInfoDatabaseIdentifierLookup;
my $rbsAnalysisAttributeLookup;
my $termAnalysisAttributeLookup;
my $hmm2AnalysisAttributeLookup;
my $ber2AnalysisAttributeLookup;
my $ncbiCogAnalysisAttributeLookup;
my $prositeAnalysisAttributeLookup;
my $interproAnalysisAttributeLookup;
my $repeatMaskerAnalysisAttributeLookup;
my $analysisAttributeLookup;    
my $computeDatabaseLookup;
my $terminatorAttributeLookup;
my $seqPairRunAttributeTypes;
my $secondaryTypeLookup;
my $featTypeToMoleculeTypeLookup;
my $eukOrfAttTypeLookup;
my $storeSequenceAsSeqData;
my $withEvToEvidenceLookup;


## Declared with global scope- will later store reference
## to Annotation::Features::Repeat::IdMapper object
my $repeatIdMapper;


## Declared with global scope- will later store reference
## to Annotation::Gopher::EventMap::FileReader object
my $gopherReader;

## The Annotation::SequenceUtil will be used to derive the sequences
## and translate proteins on the fly
my $seqUtil;

## Keep the assembly molecule's sequence here for Annotation::SequenceUtil to work on.
my $assemblySequence;


&assignGlobalValues();

&checkCommandLineArguments();

&verify_and_set_genefinder_flags();

$seqUtil = new Annotation::SequenceUtil();

if (!defined($seqUtil)){
    $logger->logdie("Could not instantiate Annotation::SequenceUtil object");
}

##
## Verify the specified output fasta directory
##
$fastadir = &verify_and_set_fastadir($fastadir, $outdir, $bsmlDocName);

if (defined($backup)){
    print STDERR "Warning any existing BSML documents and multi-FASTA ".
    "files will be saved as .bak\n";
}

## Make sure the specified id_repository exists
&check_id_repository($idRepository, $noIdGenerator);


## Instantiate new Prism reader object
my $prism = &retrieve_prism_object($username, $password, $database);


## retrieve sybase time stamp
my $sybase_time = $prism->get_sybase_datetime();


## Retrieve the organism related data from 
## common..genomes and new_project
my $orgdata= &retrieve_organism_data(
				     prism      => $prism,
				     database   => $database,
				     alt_database => $alt_database,
				     schema_type => $schema_type
				     );

## Retrieve secondary type information from
## the $sequence_type
my ($ontology, $seqtype) = &parse_sequence_type($sequence_type);


$prism->loadIdMappingLookup($inputIdMappingDirectories, $inputIdMappingFile);


## Create a lookup of user qualified TU identifers
my $qualified_tu_lookup={};
my $qualified_model_lookup={};

if ((defined($model_list_file)) && ($model_list_file ne 'none')){

    &createQualifiedFeatureLookup($model_list_file, $qualified_model_lookup);

    $tu_list_file = 'none';

} else {

    ## Prism API support
    $model_list_file = undef;
}

if ((defined($tu_list_file)) && ($tu_list_file ne 'none')){

    &createQualifiedFeatureLookup($tu_list_file, $qualified_tu_lookup);
}
else {
    ## Prism API support
    $tu_list_file = undef;
}

## The legacy2bsml.pl script should ensure that 
## //Feature/@id == //Seq-data-import/@identifier 
## for all sequences/features (bug 2044)
my $identifier_feature = {};

my $identifier_seq_data = {};


#
# legacy2bsml.pl only processes one asmbl_id at a time
# This is temporary hack to ensure that code remains compatible.
#
my $asmbl_list = [];

push ( @{$asmbl_list}, $asmbl_id );

foreach my $assembly_id ( sort  @{$asmbl_list} ) {

    #
    # Global lookups for BSML document linking
    #
    my $transcript_feature_hash = {};
    my $polypeptide_feature_hash = {};
    my $seq_data_import_hash = {};
    my $analysis_hash = {};

    my $fastasequences = {};
    my $polypeptide_feat_name_to_locus = {};
    my $gene_group_lookup = {};
    
    
    my $accession_hash = {};

    ## Lookup for storing the mappings of new isoform transcript 
    ## uniquename to the original transcript uniquename (bug 2081)
    my $transcript_mapper = {};

    ## Gene finder data will be retrieved separately from the 
    ## gene model data (bug 2120)
    my $gene_finder_hash = {};

    #
    # Retrieve the assembly related data from assembly, clone_info or stan, and asmbl_data
    #
    my ($assembly) = $prism->all_assembly_records_by_asmbl_id($assembly_id);
    
    my $gb_acc = $assembly->{$assembly_id}->{'gb_acc'};

    my $date_released = $assembly->{$assembly_id}->{'date_released'};


    my $sequences_hashes = {};
    my $gene_model_hash = {};
    my $model_feat_names = {};
    my $signalPeptideLookup = {};
    my $ribosome_hash = {};
    my $terminator_hash = {};
    my $ident_attributes_hash = {};
    my $tigr_roles_hash = {};
    my $go_roles_hash = {};

    my $ber_evidence_hash = {};
    my $hmm2_evidence_hash = {};
    my $cog_evidence_hash = {};
    my $prosite_evidence_hash = {};
    my $interproEvidenceLookup = {};
    my $ident_xref_attr_hash = {};

    my $pmark_lookup = {};

    ## The models' ORF_attributes MW and pI shall be associated with
    ## the corresponding polypeptides in BSML and chado (bug 2141)
    my $euk_polypeptide_orf_attributes_hash = {};

    my $euk_cds_orf_attributes_hash = {};

    ## The ORFs' ORF_attributes: MW, PI, LP, OMP will be associated 
    ## with the polypeptide Feature in BSML and chado.
    ## The ORFs' ORF_attribute: GC will be associated with the CDS
    ## Feature in BSML and chado (bug 2663).
    my $prok_polypeptide_orf_attributes_hash = {};

    my $cds_feature_hash = {};

    my $prok_cds_orf_attributes_hash  = {};

    my $t2g_lookup;   # terminator to gene lookup

    my $r2g_lookup;   # ribosome_binding_site to gene lookup


    my $misc_feature_lookup = {};

    my $repeat_feature_lookup = {};

    my $transposon_feature_lookup = {};

    my $rnaLookup = {};

    my $lipoMembraneProteinLookup = {};

    ## The assembly's worth of epitopes
    my $epiCollection;


    if ( ( $mode == 1 )  or  ( $mode == 2 ) ){

	#
	# Mode 1: Write BSML encodings ONLY for all of the following:
	#         Sequence, Gene Model, RNA Features, Other Features, Gene Annotation Attributes. TIGR Roles, GO, ORF Attributes
	#
	# Mode 2: Write BSML encodings for all of the above + BER, AUTO-BER and HMM2 evidence
	#
	
	if ( $schema_type eq 'euk' ) {
	    #
	    # The section handles particular eukaryotic BSML encoding
	    #

	    if (defined($gopherFile)){

		$gopherReader = new Annotation::Gopher::EventMap::FileReader(filename=>$gopherFile);

		if (!defined($gopherReader)){

		    $logger->logdie("Could not instantiate Annotation::".
				    "Gopher::EventMap::FileReader object ".
				    "for GOPHER file '$gopherFile'");
		}
	    }

	    ($gene_model_hash, $model_feat_names) = &create_euk_gene_model_lookup($prism, $assembly_id, $qualified_tu_lookup,
										  $tu_list_file, $qualified_model_lookup,
										  $model_list_file, $database);

	    $sequences_hashes = &create_euk_sequence_lookup($prism,
							    $assembly_id,
							    $database,
							    $model_feat_names);
	    
	    $ident_xref_attr_hash = &create_ident_xref_attr_lookup($prism, 
								   $assembly_id,
								   $database, 
								   $alt_database);

	    ## The models' ORF_attributes MW and pI shall be associated
	    ## with the corresponding polypeptides in BSML and chado (bug 2141).
	    $euk_polypeptide_orf_attributes_hash = &create_euk_polypeptide_orf_attributes_lookup($prism, $assembly_id, $database, $alt_database);

	    ## The models' ORF_attributes score and score2 where 
	    ## att_type = 'is_partial' shall be associated with the
	    ## corresponding CDS features in BSML and chado (bug 2292).
	    $euk_cds_orf_attributes_hash = &create_euk_cds_orf_attributes_lookup($prism, $assembly_id, $database, $alt_database);

	    #
	    # Retrieve miscellaneous feature types
	    #
	    $misc_feature_lookup = &create_miscellaneous_feature_lookup($database, $asmbl_id, $no_misc_features);

	    #
	    # Retrieve repeat feature types
	    #
	    $repeat_feature_lookup = &create_repeat_feature_lookup($database, $asmbl_id, $no_repeat_features);

	    #
	    # Retrieve transposon feature types
	    #
	    $transposon_feature_lookup = &create_transposon_feature_lookup($database, $asmbl_id, $no_transposon_features);

	}
	else{
	    #
	    # This section handles particular prokaryotic BSML encoding
	    #
	    $sequences_hashes  = &create_prok_sequence_lookup($prism,
							      $assembly_id,
							      $database,
							      $schema_type);

	    $gene_model_hash   = &create_prok_gene_model_lookup($prism, 
								$assembly_id,
								$database, 
								$schema_type,
								$alt_database);


	    ## (bug 2263)
	    $prok_polypeptide_orf_attributes_hash   = &create_prok_polypeptide_orf_attributes_lookup($prism, 
												     $assembly_id,
												     $database,
												     $alt_database,
												     $schema_type);
	    
	    &createLipoMembraneProteinLookup($prism, 
					     $assembly_id,
					     $database, 
					     $alt_database,
					     $lipoMembraneProteinLookup);

	    $prok_cds_orf_attributes_hash   = &create_prok_cds_orf_attributes_lookup($prism, 
										     $assembly_id,
										     $database, 
										     $alt_database,
										     $schema_type);


	    $epiCollection = $prism->getEpitopeFeatureCollection($assembly_id, $database);
	    if (!defined($epiCollection)){
		$logger->warn("Could not retrieve epitope collection ".
				"for asmbl_id '$assembly_id' database ".
				"'$database'");
	    }
	}

	
    $accession_hash = &create_accession_lookup($prism,
                                               $assembly_id,
                                               $database,
                                               $schema_type);


	&createRnaLookup($prism, $assembly_id, $database, $schema_type, $alt_database, $rnaLookup);

	$signalPeptideLookup = &createSignalPeptideLookup($prism, 
							  $assembly_id,
							  $database, 
							  $schema_type);

	$ribosome_hash = &create_ribosome_lookup($prism, 
						 $assembly_id, 
						 $database);

	$terminator_hash = &create_terminator_lookup($prism, 
						     $assembly_id,
						     $database);

	$ident_attributes_hash = &create_ident_attributes_lookup($prism,
								 $assembly_id,
								 $database, 
								 $alt_database,
								 $schema_type);

	$tigr_roles_hash = &create_tigr_roles_lookup($prism,
						     $assembly_id,
						     $database, 
						     $alt_database,
						     $schema_type);

	$go_roles_hash = &create_go_roles_lookup($prism, 
						 $assembly_id, 
						 $database,
						 $schema_type,
						 $alt_database);

	$t2g_lookup = &create_terminator_to_gene_lookup($prism, 
							$assembly_id,
							$database);

	$r2g_lookup = &create_rbs_to_gene_lookup($prism, 
						 $assembly_id,
						 $database);

	$pmark_lookup = &create_pmark_lookup($prism,
					     $assembly_id,
					     $database, 
					     $alt_database);

    }
    if ( ($mode == 2) or ($mode == 3) ){


	## User may specify which gene finder data types to 
	## include/exclude from the migration (bug 2123)
	
	if (($include_genefinder ne 'none') or ($exclude_genefinder ne 'all')) {
	    ## Retrieval of gene finder data will be handled separate
	    ## from the retrieval of standard gene model data
	    
	    ($gene_finder_hash) = &create_gene_finder_lookup($prism,
							     $assembly_id,
							     $exclude_genefinder,
							     $include_genefinder);
	}
	else {
	    if ($include_genefinder eq 'none'){
		$logger->info("User '$username' has specified that none of ".
			      "the gene finder datatypes should be included ".
			      "in the migration");
	    }

	    if ($exclude_genefinder eq 'all'){
		$logger->info("User '$username' has specified that all of the ".
			      "gene finder datatypes should or excluded from ".
			      "the migration");
	    }
	}




	#
	# Mode 2: Write BSML encodings for all of the following:
	#         Sequence, Gene Model, RNA Features, Other Features, Gene Annotation Attributes. TIGR Roles, GO, ORF Attributes
	#
	# Mode 3: Write BSML encodings ONLY for BER, AUTO-BER and HMM2 evidence
	#

	$ber_evidence_hash = &create_ber_evidence_lookup($prism, 
							 $assembly_id,
							 $database,
							 $orgdata->{'prefix'}, 
							 $schema_type);

	if ( $schema_type eq 'euk' ) {
	    $hmm2_evidence_hash = &create_euk_hmm2_evidence_lookup($prism,
								   $assembly_id,
								   $database,
								   $orgdata->{'prefix'});
	}
	else {
	    $hmm2_evidence_hash = &create_hmm2_evidence_lookup($prism,
							       $assembly_id,
							       $database,
							       $orgdata->{'prefix'}, 
							       $schema_type);
	}

	$cog_evidence_hash = &create_cog_evidence_lookup($prism,
							 $assembly_id,
							 $database,
							 $orgdata->{'prefix'}, 
							 $schema_type);

	$prosite_evidence_hash = &create_prosite_evidence_lookup($prism,
								 $assembly_id,
								 $database,
								 $orgdata->{'prefix'}, 
								 $schema_type);

	$interproEvidenceLookup = &createInterproEvidenceLookup($prism,
								$assembly_id,
								$database,
								$orgdata->{'prefix'}, 
								$schema_type);

    }



    #------------------------------------------------------------------------------------------------------------------------------------------------
    #
    #                            ALL LOOKUPS HAVE BEEN CREATED.  Time to output the BSML gene model document.
    #
    #------------------------------------------------------------------------------------------------------------------------------------------------
    print "Building BSML document for asmbl_id '$assembly_id'\n";

    
    #--------------------------------------------------------------------------------------------
    #
    # Foreach asmbl - instantiate the Bsml doc Builder class
    #               - initialize and increment the cross-reference counter
    #
    #--------------------------------------------------------------------------------------------
    my $doc = new BSML::BsmlBuilder();

    $doc->{'doc_name'} = $bsmlDocName;

    ## The polypeptide Feature-table element lookup will be used during the insertion
    ## of signal peptide Features
    my $polypeptideFeatureTableElemLookup = {};

    ## The polypeptide Sequence element lookup will be used during the insertion
    ## of signal peptide Features
    my $polypeptideSequenceElemLookup = {};

    if (defined($alt_database)){
	$database = $alt_database;
    }


    $doc->{'xrefctr'}++;
    
    ## The <Sequence> will now be explicitly linked with
    ## the <Genome>, thus genome id be returned and
    ## propagated throughout the code (bug 2051).
    my $genome_id = &create_genome_component(
					     $doc,
					     $orgdata,
					     $schema_type,
					     $alt_species
					     );

    ## To keep track of which qualified models are being propagated to the BSML file.
    ## Note that it was necessary to track these since TU filtering was enabled.
    ## Legacy computational data associated with some model should not be propagated
    ## to the BSML file if that model is not feat_link'ed to some qualified TU.
    my $lc_qualified_models = {};


    
    # mode 1: gene model only
    # mode 2: gene model + computational evidence
    # mode 3: computational evidence only 
    
    my $asmblUniqString = $database . "_" . $asmbl_id . "_assembly";
    
    $asmblUniqString = &cleanse_uniquename($asmblUniqString);

    my $asmbl_uniquename = $prism->getFeatureUniquenameFromIdGenerator($database, 'assembly', $asmblUniqString, $idgen_identifier_version);
    if (!defined($asmbl_uniquename)){
	$logger->logdie("asmbl_uniquename was not defined for database '$database' class 'assembly' uniqstring '$asmblUniqString' idgen_identifier_version '$idgen_identifier_version'");
    }

    my $asmlen;

    if (! exists $assembly->{$asmbl_id}->{'sequence'}){
	$logger->logdie("sequence does not exist for assembly with ".
			"asmbl_id '$asmbl_id'");
    } else {

	## Save the assembly's sequence here for the Annotation::SequenceUtil to work on later
	$assemblySequence = $assembly->{$asmbl_id}->{'sequence'};

	$seqUtil->loadSequence($assemblySequence);

	$asmlen = length($assemblySequence);
    }

    push ( @{$fastasequences->{$asmbl_id}->{'assembly'}}, [$asmbl_uniquename, $assembly->{$asmbl_id}->{'sequence'}]);
    
    my ($assembly_sequence_elem) = &create_assembly_sequence_component(
								       'asmbl_id'         => $asmbl_id,
								       'uniquename'       => $asmbl_uniquename,
								       'length'           => $asmlen,
								       'topology'         => $assembly->{$asmbl_id}->{'topology'},
								       'doc'              => $doc,
								       'fastadir'         => $fastadir,
								       'database'         => $database,
								       'prefix'           => $orgdata->{'prefix'},
								       'molecule_name'    => $assembly->{$asmbl_id}->{'molecule_name'},
								       'molecule_type'    => $assembly->{$asmbl_id}->{'molecule_type'},
								       'genome_id'        => $genome_id,
								       'seqtype'          => $seqtype,
								       'ontology'         => $ontology,
								       'organism_name'    => $orgdata->{'name'},
								       'gb_acc'           => $assembly->{$asmbl_id}->{'gb_acc'},
								       'schema_type'      => $schema_type,
								       'lookup'           => $assembly->{$asmbl_id}
								       );
    
    ## The legacy2bsml.pl script should ensure that
    ## the //Feature/@id == //Seq-data-import/@identifier 
    ## for all sequences/features (bug 2044).
    $identifier_feature->{$asmbl_uniquename}++;
    
    
    ## The script should not write <Feature-tables> for subfeature-less assemblies (bug 2063).
    
    ## The genefinder models will also require the creation of a <Feature-table> element object.
    ## This code verifies whether such an object should be created (bug 2140).
    
    $seqUtil->verifyCDSAndExonStrands($gene_model_hash, $database);

    my $subfeatures_exist = &do_subfeatures_exist(
						  gene_model_hash => $gene_model_hash,
						  rnaLookup       => $rnaLookup,
						  peptide_hash    => $signalPeptideLookup,
						  ribosome_hash   => $ribosome_hash,
						  terminator_hash => $terminator_hash,
						  gene_finder_hash => $gene_finder_hash,
						  misc_feature_lookup => $misc_feature_lookup,
						  repeat_feature_lookup => $repeat_feature_lookup,
						  transposon_feature_lookup => $transposon_feature_lookup,
						  pmark_lookup => $pmark_lookup,
						  asmbl_id => $asmbl_id
						  );

    my $feature_table_elem;
    
    
    if ( (($schema_type eq 'euk' ) && 
	  ($subfeatures_exist)) || # if processing a euk and there are subfeatures
	 ($schema_type ne 'euk' )) {           # or if not processing a euk
	
	#
	# Create <Feature-table> element object
	#
	$feature_table_elem = $doc->createAndAddFeatureTable($assembly_sequence_elem);
	
	if (!defined($feature_table_elem)){
	    $logger->logdie("Could not create <Feature-table> element object reference");
	}	    
    }

    if (($mode == 1) or ($mode == 2)) {


	my $polypeptide_sequence_element_lookup = {};

	my $feature_group_element_lookup = {};

	my $feature_table_element_lookup = {};

	foreach my $data_hash ( @{$sequences_hashes->{$asmbl_id}} ){
	    
	    ## Create <Sequence> element objects for all of the following features:
	    ## polypeptide, CDS, tRNA, rRNA, sRNA, terminator, ribosome_entry_site

	    &store_sequence_elements(
				     'database'                 => $database,
				     'prefix'                   => $orgdata->{'prefix'},
				     'fastadir'                 => $fastadir,
				     'doc'                      => $doc,
				     'asmbl_id'                 => $asmbl_id,
				     'sequence_subfeature_hash' => $data_hash,
				     'fastasequences'           => $fastasequences,
				     'seq_data_import_hash'     => $seq_data_import_hash,
				     'identifier_seq_data'      => $identifier_seq_data,
				     'genome_id'                => $genome_id,
				     'polypeptide_sequence_element_lookup' => $polypeptide_sequence_element_lookup
				     );
	}
	
	#
	# Store all Gene Encodings i.e. ORFs as:
	# 1) gene
	# 2) transcript
	# 3) CDS
	# 4) polypeptide
	# 5) exon
	#

	if ( $schema_type eq 'euk' ){

	    foreach my $data_hash ( @{$gene_model_hash->{$asmbl_id}} ){
		
		&store_euk_gene_model_subfeatures(
						  'asmbl_id'                => $asmbl_id,
						  'feature_table_elem'      => $feature_table_elem,
						  'doc'                     => $doc,
						  'database'                => $database,
						  'prefix'                  => $orgdata->{'prefix'},
						  'assembly_sequence_elem'  => $assembly_sequence_elem,
						  'accession_lookup'        => $accession_hash->{$asmbl_id},
						  'gene_group_lookup'       => $gene_group_lookup,
						  'transcript_feature_hash' => $transcript_feature_hash,
						  'seq_data_import_hash'    => $seq_data_import_hash,
						  'identifier_feature'      => $identifier_feature,
						  'genome_id'               => $genome_id,
						  'outdir'                  => $outdir,
						  'analysis_hash'           => $analysis_hash,
						  'transcript_mapper'       => $transcript_mapper,
						  'transcripts'             => $data_hash->{'transcripts'},
						  'coding_regions'          => $data_hash->{'coding_regions'},
						  'exons'                   => $data_hash->{'exons'},
						  'polypeptide_feature_hash'  => $polypeptide_feature_hash,
						  'cds_feature_hash'          => $cds_feature_hash,
						  'gb_acc'                    => $gb_acc,
						  'date_released'             => $date_released,
						  'polypeptide_sequence_element_lookup' => $polypeptide_sequence_element_lookup,
						  'feature_table_element_lookup'        => $feature_table_element_lookup,
						  'lc_qualified_models'                 => $lc_qualified_models
						  );
	    }
	    
	    
	    ## The ORF_attributes MW and pI shall be associated 
	    ## with the polypeptide features (bug 2141).
	    &process_polypeptide_orf_attribute_data(
						    polypeptide_feature_hash => $polypeptide_feature_hash,
						    orf_attributes_hash      => $euk_polypeptide_orf_attributes_hash,
						    doc                      => $doc
						    );


	    ## The models' ORF_attributes score and score2 where att_type = 'is_partial' shall
	    ## be associated with the corresponding CDS features in BSML and chado (bug 2292).
	    &process_euk_cds_orf_attribute_data(
						cds_feature_hash    => $cds_feature_hash,
						orf_attributes_hash => $euk_cds_orf_attributes_hash,
						doc                 => $doc
						);


	    ##---------------------------------------------------------------
	    ## Store miscellaneous feature data
	    ##
	    ##---------------------------------------------------------------
	    &store_misc_feature_types($misc_feature_lookup,
				      $asmbl_id,
				      $doc,
				      $no_misc_features,
				      $database,
				      $feature_table_elem);


	    ##---------------------------------------------------------------
	    ## Store repeat feature data
	    ##
	    ##---------------------------------------------------------------
	    &store_repeat_feature_types($repeat_feature_lookup,
					$asmbl_id,
					$doc,
					$no_repeat_features,
					$database,
					$feature_table_elem,
					$analysis_hash,
					$outdir);
	    

	    ##---------------------------------------------------------------
	    ## Store transposon data
	    ##
	    ##---------------------------------------------------------------
	    &store_transposon_feature_types($transposon_feature_lookup,
					    $asmbl_id,
					    $doc,
					    $no_transposon_features,
					    $database,
					    $feature_table_elem);
	    



	}
	else{

	    foreach my $data_hash ( @{$gene_model_hash->{$asmbl_id}} ){
		
		## store_prok_gene_model_subfeatures() will redundantly store the ORF feature
		## as gene, transcript, CDS, exon
		
		&store_prok_gene_model_subfeatures(
						   'orfhash'                => $data_hash,
						   'asmbl_id'               => $asmbl_id,
						   'feature_table_elem'     => $feature_table_elem,
						   'doc'                    => $doc,
						   'database'               => $database,
						   'prefix'                 => $orgdata->{'prefix'},
						   'assembly_sequence_elem' => $assembly_sequence_elem,
						   'accession_lookup'       => $accession_hash->{$asmbl_id},
						   'gene_group_lookup'      => $gene_group_lookup,
						   'transcript_feature_hash' => $transcript_feature_hash,
						   'polypeptide_feat_name_to_locus' => $polypeptide_feat_name_to_locus,
						   'polypeptide_feature_hash'       => $polypeptide_feature_hash,
						   'seq_data_import_hash'       => $seq_data_import_hash,
						   'identifier_feature'         => $identifier_feature,
						   'genome_id'                  => $genome_id,
						   'cds_feature_hash'           => $cds_feature_hash,
						   'schema_type'                     => $schema_type,
						   'polypeptide_sequence_element_lookup' => $polypeptide_sequence_element_lookup
						   );
	    }

	    ## The ORFs' ORF_attributes: MW, PI, LP, OMP will be 
	    ## associated with the polypeptide Features in BSML 
	    ## and chado (bug 2263).
	    &process_polypeptide_orf_attribute_data(
						    polypeptide_feature_hash => $polypeptide_feature_hash,
						    orf_attributes_hash      => $prok_polypeptide_orf_attributes_hash,
						    doc                      => $doc
						    );


	    &processLipoMembraneProteinLookup($polypeptide_feature_hash, $lipoMembraneProteinLookup, $doc, $prism, $database, $asmbl_id);

	    ## The ORFs' ORF_attribute: GC will be associated with the CDS
	    ## Features in BSML and chado (bug 2263).
	    &process_prok_cds_orf_attribute_data(
						 cds_feature_hash     => $cds_feature_hash,
						 orf_attributes_hash  => $prok_cds_orf_attributes_hash,
						 doc                  => $doc
						 );
	}

	&writeRnaDataToBsml($rnaLookup, $asmbl_id, $database, $doc, $orgdata->{'prefix'}, $feature_table_elem, $identifier_feature, $genome_id, $fastadir, $fastasequences, $seq_data_import_hash);

	##---------------------------------------------------------------
	## Store peptide data
	##
	##---------------------------------------------------------------
	&storeSignalPeptideFeatureData($database, 
				       $doc,
				       $asmbl_id,
				       $orgdata->{'prefix'},
				       $signalPeptideLookup,
				       $assembly_sequence_elem,
				       $identifier_feature,
				       $polypeptide_feat_name_to_locus,
				       $polypeptide_sequence_element_lookup,
				       $polypeptideFeatureTableElemLookup
				       );

	##---------------------------------------------------------------
	## Store ribosome data
	##
	##---------------------------------------------------------------
	foreach my $data_hash ( @{$ribosome_hash->{$asmbl_id}} ){

	    &store_ribosomal_binding_site_encodings(
						    'database'            => $database,
						    'doc'                 => $doc,
						    'prefix'              => $orgdata->{'prefix'},
						    'asmbl_id'            => $asmbl_id,
						    'ribo'                => $data_hash,
						    'feature_table_elem'  => $feature_table_elem,
						    'r2g_lookup'          => $r2g_lookup,
						    'gene_group_lookup'   => $gene_group_lookup,
						    'analysis_hash'       => $analysis_hash,
						    'identifier_feature'  => $identifier_feature,
						    'genome_id'           => $genome_id
						    );    
	}

	##---------------------------------------------------------------
	## Store terminator data
	##
	##---------------------------------------------------------------
	foreach my $datahash ( @{$terminator_hash->{$asmbl_id}} ){

	    &store_terminator_features(
				       'database' => $database,
				       'doc'      => $doc,
				       'prefix'   => $orgdata->{'prefix'},
				       'asmbl_id' => $asmbl_id,
				       'term'     => $datahash,
				       'feature_table_elem' => $feature_table_elem,
				       'gene_group_lookup'  => $gene_group_lookup,
				       't2g_lookup'         => $t2g_lookup,
				       'analysis_hash'      => $analysis_hash,
				       'identifier_feature' => $identifier_feature,
				       'genome_id'          => $genome_id
				       );    
	}

	
	##---------------------------------------------------------------
	## Store pmark_spacer data
	##
	##---------------------------------------------------------------
	foreach my $datahash ( @{$pmark_lookup->{$asmbl_id}} ){
	    
	    &store_pmark_features(
				  'database' => $database,
				  'doc'      => $doc,
				  'prefix'   => $orgdata->{'prefix'},
				  'asmbl_id' => $asmbl_id,
				  'pmark'     => $datahash,
				  'feature_table_elem' => $feature_table_elem,
				  'gene_group_lookup'  => $gene_group_lookup,
				  't2g_lookup'         => $t2g_lookup,
				  'analysis_hash'      => $analysis_hash,
				  'identifier_feature' => $identifier_feature,
				  'genome_id'          => $genome_id,
				  'prism'              => $prism
				  );    
	}

	if (defined($epiCollection)){

	    my $epiWriter = new Annotation::BSML::Builder::EpitopeWriter(bsmldoc=>$doc,
									 prism=>$prism,
									 database=>$database,
									 asmbl_id=>$asmbl_id,
									 fastadir=>$fastadir,
									 assemblyBSMLSequence=>$assembly_sequence_elem);

	    if (!defined($epiWriter)){
		$logger->logdie("Could not instantiate Annotation::BSML::Builder::EpitopeWriter");
	    }

	    $epiWriter->addCollection(collection=>$epiCollection,
				      featureTableLookup=>$polypeptideFeatureTableElemLookup,
				      bsmlSequenceLookup=>$polypeptide_sequence_element_lookup);
	}

	##-----------------------------------------------------------------------------------------------------
	## Store Gene annotation attributes
	##
	##-----------------------------------------------------------------------------------------------------

	my $tran_ident_lookup = {};

	foreach my $transcript (sort keys %{$transcript_feature_hash} ){

	    ## e.g. $transcript = 'afu1_100_100.t00001_transcript_iso_1

	    my $old_transcript = $transcript;


	    ##---------------------------------------------------------------
	    ## Store ident_xref data
	    ##
	    ##---------------------------------------------------------------
	    if ($schema_type eq 'euk' ) {

		## Lookup for retrieving the mappings of the new isoform
		## transcript uniquename to the original transcript 
		## uniquename (bug 2081).
		
		if ((exists $transcript_mapper->{$transcript}) && (defined($transcript_mapper->{$transcript}))){

		    ## e.g. $old_transcript = 'afu1_100_100.t00001_transcript'
		    $old_transcript = $transcript_mapper->{$transcript};
		}
		else{
		    $logger->logdie("Could not lookup old transcript for transcript '$transcript'" . Dumper $transcript_mapper);
		}

		&store_ident_attributes(
					'doc'                     => $doc,
					'uniquename'              => $transcript,
					'transcript_feature_elem' => $transcript_feature_hash->{$transcript},
					'attributes'              => $ident_xref_attr_hash->{$old_transcript}->{'attribute'},
					'attribute-list'          => $ident_xref_attr_hash->{$old_transcript}->{'attribute-list'},
					'tran_ident_lookup'       => $tran_ident_lookup,
					'genome_id'               => $genome_id
					);
	    }

	    ##---------------------------------------------------------------
	    ## Store ident data
	    ##
	    ##---------------------------------------------------------------

	    &store_ident_attributes(
				    'doc'                     => $doc,
				    'uniquename'              => $transcript,
				    'transcript_feature_elem' => $transcript_feature_hash->{$transcript},
				    'attributes'              => $ident_attributes_hash->{$old_transcript}->{'attribute'},
				    'attribute-list'          => $ident_attributes_hash->{$old_transcript}->{'attribute-list'},
				    'tran_ident_lookup'       => $tran_ident_lookup,
				    'genome_id'               => $genome_id
				    );

	    ##---------------------------------------------------------------
	    ## Store TIGR roles
	    ##
	    ##---------------------------------------------------------------
	    &store_roles_attributes(
				    'transcript_feature_elem' => $transcript_feature_hash->{$transcript},
				    'uniquename'              => $transcript,
				    'attributelist'           => $tigr_roles_hash->{$old_transcript},
				    'genome_id'               => $genome_id
				    );

	    ##---------------------------------------------------------------
	    ## Store GO roles
	    ##
	    ##---------------------------------------------------------------
	    &store_go_attributes(
				 'transcript_feature_elem' => $transcript_feature_hash->{$transcript},
				 'uniquename'              => $transcript,
				 'attributelist'           => $go_roles_hash->{$old_transcript},
				 'genome_id'               => $genome_id
				 );
	}
    }
    if ( ($mode == 2 ) or  ($mode == 3)) {

	# mode 1: gene model only
	# mode 2: gene model + computational evidence
	# mode 3: computational evidence only 

	## The storing the gene finder data will be handled
	## separately from the storing of the standard gene 
	## model data.
	foreach my $data_hash ( @{$gene_finder_hash->{$asmbl_id}} ){
	    
	    my $some_transcript_mapper = {};
	    my $some_transcript_feature_hash = {};

	    &store_euk_gene_finder_subfeatures(
					       'datahash'                => $data_hash,
					       'asmbl_id'                => $asmbl_id,
					       'feature_table_elem'      => $feature_table_elem,
					       'doc'                     => $doc,
					       'database'                => $database,
					       'prefix'                  => $orgdata->{'prefix'},
					       'assembly_sequence_elem'  => $assembly_sequence_elem,
					       'accession_lookup'        => $accession_hash->{$asmbl_id},
					       'gene_group_lookup'       => $gene_group_lookup,
					       'transcript_feature_hash' => $some_transcript_feature_hash,
					       'seq_data_import_hash'    => $seq_data_import_hash,
					       'identifier_feature'      => $identifier_feature,
					       'genome_id'               => $genome_id,
					       'outdir'                  => $outdir,
					       'analysis_hash'           => $analysis_hash,
					       'transcript_mapper'       => $some_transcript_mapper,
					       'coding_regions'          => $data_hash->{'coding_regions'},
					       'exons'                   => $data_hash->{'exons'}						       
					       );
	}

	#
	# Create compute/evidence BSML document(s)
	#

	## Need to store //Link/@role for each Sequence's analysis.  We define this lookup in order to 
	## ensure that only one BsmlLink element object is created for each BsmlSequence-BsmlAnalysis
	## per BsmlLink role type (bug 2273).
	my $sequence_analysis_link = {};

	##---------------------------------------------------------------
	## Store BER and AUTO-BER data
	##
	##---------------------------------------------------------------
	if ( exists $ber_evidence_hash->{$asmbl_id} ){


	    &store_ber_evidence_data(
				     'doc'        => $doc,
				     'asmbl_id'   => $asmbl_id,
				     'data_hash'  => $ber_evidence_hash->{$asmbl_id},
				     'database'   => $database,
				     'docname'    => $doc->{'doc_name'},
				     'prefix'     => $orgdata->{'prefix'},
				     'genome_id'  => $genome_id,
				     'sequence_analysis_link' => $sequence_analysis_link
				     );
	}
	

	##---------------------------------------------------------------
	## Store HMM2 data
	##
	##---------------------------------------------------------------
	if ( exists $hmm2_evidence_hash->{$asmbl_id} ){

	    my $hmm2RecordCount = (keys %{$hmm2_evidence_hash->{$asmbl_id}});

	    if ($hmm2RecordCount > 0) {

		if ($logger->is_debug()){
		    $logger->is_debug("Will process '$hmm2RecordCount' HMM2 records for asmbl_id '$asmbl_id'");
		}

		if ( $schema_type eq 'euk' ) {

		    &store_euk_hmm2_evidence_data(
						  'doc'           => $doc,
						  'asmbl_id'      => $asmbl_id,
						  'evidence_hash'     => $hmm2_evidence_hash,
						  'database'      => $database,
						  'docname'       => $doc->{'doc_name'},
						  'prefix'        => $orgdata->{'prefix'},
						  'analysis_hash' => $analysis_hash,
						  'genome_id'     => $genome_id,
						  'sequence_analysis_link' => $sequence_analysis_link,
						  'lc_qualified_models'    => $lc_qualified_models
						  );
		}
		else {
		    
		    &store_prok_hmm2_evidence_data(
						   'doc'           => $doc,
						   'asmbl_id'      => $asmbl_id,
						   'data_hash'     => $hmm2_evidence_hash->{$asmbl_id},
						   'database'      => $database,
						   'docname'       => $doc->{'doc_name'},
						   'outdir'        => $outdir,
						   'prefix'        => $orgdata->{'prefix'},
						   'analysis_hash' => $analysis_hash,
						   'genome_id'     => $genome_id,
						   'sequence_analysis_link' => $sequence_analysis_link
						   );
		    
		}
	    }
	    else {
		if ($logger->is_debug()){
		    $logger->debug("There were no HMM2 records to process for database '$database' asmbl_id '$asmbl_id'");
		}
	    }
	}


	##---------------------------------------------------------------
	## Store COG data
	##
	##---------------------------------------------------------------
	if ( exists $cog_evidence_hash->{$asmbl_id} ){

	    &store_cog_evidence_data(
				     'doc'           => $doc,
				     'asmbl_id'      => $asmbl_id,
				     'data_hash'     => $cog_evidence_hash->{$asmbl_id},
				     'database'      => $database,
				     'docname'       => $doc->{'doc_name'},
				     'prefix'        => $orgdata->{'prefix'},
				     'analysis_hash' => $analysis_hash,
				     'genome_id'     => $genome_id,
				     'sequence_analysis_link' => $sequence_analysis_link
				     );
	}

	##---------------------------------------------------------------
	## Store PROSITE data
	##
	##---------------------------------------------------------------
	if ( exists $prosite_evidence_hash->{$asmbl_id} ){

	    &store_prosite_evidence_data(
					 'doc'           => $doc,
					 'asmbl_id'      => $asmbl_id,
					 'data_hash'     => $prosite_evidence_hash->{$asmbl_id},
					 'database'      => $database,
					 'docname'       => $doc->{'doc_name'},
					 'prefix'        => $orgdata->{'prefix'},
					 'analysis_hash' => $analysis_hash,
					 'genome_id'     => $genome_id,
					 'sequence_analysis_link' => $sequence_analysis_link
					 );
	}

	##---------------------------------------------------------------
	## Store Interpro data
	##
	##---------------------------------------------------------------
	if ( exists $interproEvidenceLookup->{$asmbl_id} ){

	    &storeInterproEvidenceData(
				       'doc'           => $doc,
				       'asmbl_id'      => $asmbl_id,
				       'data_hash'     => $interproEvidenceLookup->{$asmbl_id},
				       'database'      => $database,
				       'docname'       => $doc->{'doc_name'},
				       'prefix'        => $orgdata->{'prefix'},
				       'analysis_hash' => $analysis_hash,
				       'genome_id'     => $genome_id,
				       'sequence_analysis_link' => $sequence_analysis_link
				       );
	}



    }
    

    &write_out_bsml_doc($doc);

    if ($schema_type eq 'euk'){
	&create_multifasta($asmbl_id, $fastadir, $database, $assemblySequence);
    } else {
	## This is a temp hack.
	## Will be implemented appropriately in near future.
	&createFASTAFilesForProks($fastasequences, $fastadir, $database);
    }


}

$prism->writeIdMappingFile($outputIdMappingFile);


my $exitMsg = "All FASTA files were written to directory '$fastadir'.\nThe .bsml file was written to '$outdir'.\nThe output ID mapping file is '$outputIdMappingFile'.\nThe log file is '$logfile'.\n";
if (defined($bsmlDocName)){
    $exitMsg = "All FASTA files were written to directory '$fastadir'.\nThe following BSML document was created: '$bsmlDocName'.\nThe ID mapping file is '$outputIdMappingFile'.\nThe log file is '$logfile'.\n";
}

print $exitMsg;
exit(0);



##----------------------------------------------------------
##
##  END OF MAIN -- SUBROUTINES FOLLOW
##
##----------------------------------------------------------

sub checkCommandLineArguments {

    if ($man){
	&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
    }
    if ($help){
	&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
    }

    my $fatalCtr=0;

    if (!$username){
	print STDERR ("username was not defined\n");
	$fatalCtr++;
    }

    if (!$password){
	print STDERR ("password was not defined\n");
	$fatalCtr++;
    }
    if (!$database){
	print STDERR ("database was not defined\n");
	$fatalCtr++;
    }
    if (!$asmbl_id){
	print STDERR ("asmbl_id was not defined\n");
	$fatalCtr++;
    }

    if ($fatalCtr>0){
	&print_usage();
	exit(1);
    }


    &getLogger($logfile, $debug_level, $database, $asmbl_id);


    if ((defined($alt_database)) &&
	($alt_database eq 'none')){
	$alt_database = undef;
    }

    if ((defined($alt_species)) &&
	($alt_species eq 'none')){
	$alt_species = undef;
    }


    ## verify/set the version value to be appended to the identifier generated by IdGenerator
    if (!defined($idgen_identifier_version)){

	$idgen_identifier_version = 0;

    } else {

	if ($idgen_identifier_version != int($idgen_identifier_version)){
	    $logger->logdie("idgen_identifier_version ".
			    "'$idgen_identifier_version' ".
			    "must be a positive integer");
	}
    }

    
    if( $schema_type eq 'ntprok' && $rdbms ne 'Sybase' ) {
	$logger->logdie("schema_type and rdbms combination is ".
			"not supported: $schema_type -> $rdbms");
    }
    
    $outdir = &verify_and_set_outdir($outdir, $bsmlDocName);

    if (!defined($sourcename)){
	$sourcename = $outdir;
	if ($logger->is_debug()){
	    $logger->debug("sourcename was not defined and so was assigned value of outdir '$outdir'");
	}
    }
    
    ## Validate the schema type
    if ( ! exists $validSchemaTypes->{$schema_type} ) {
	$logger->logdie("Invalid schema type '$schema_type'.  Valid ".
			"schema types are:" . Dumper $validSchemaTypes);
    }

    ## Determine whether processing prok/ntprok OR euk organism data
    if (! exists $schemaTypeToConf->{$schema_type}){
	die "schema_type '$schema_type' does not exist ".
	"in the schemaTypeToConf lookup:". Dumper $schemaTypeToConf;
    }

    $ENV{PRISM} = $schemaTypeToConf->{$schema_type};

    ## Set a default mode
    if (!defined($mode)){
	$mode = 1;
    }

    ## Validate the mode type
    if ( ! exists $validModeTypes->{$mode} ){
	$logger->fatal("Invalid mode type '$mode'");
	&print_usage();
    }


    if (!defined($bsmlDocName)){
	$bsmlDocName = $outdir . '/'. $database . '_' .$asmbl_id . '_assembly.'  . $schema_type . '.bsml';
    }

    if (!defined($outputIdMappingFile)){
	$outputIdMappingFile = $bsmlDocName . '.legacy2bsml.pl.idmap';
	$logger->warn("--output_id_mapping_file was not specified.  ".
		      "Setting default '$outputIdMappingFile'");
    }

    if (!defined($inputIdMappingDirectories)){
	$inputIdMappingDirectories = $outdir;
	$logger->warn("--input_id_mapping_directories was not ".
		      "specified.  Setting default ".
		      "'$inputIdMappingDirectories'. ".
		      "All files with extension '.idmap' will ".
		      "be read and their mappings will be loaded ".
		      "into the ID mapping lookup.");
    }


    ## legacy2bsml workflow component support
    ## The model list file takes precedence
    if ((!defined($model_list_file)) || ($model_list_file eq 'none')){

	## When invoked as part of a workflow, the value will be some file or string 'none'.
	## When invoked as standalone script, the parameter is optional.  In the case where
	## it is not defined, we set it to 'none'.
	$model_list_file = 'none';
    }
    else {
	$tu_list_file = 'none';
    }

    if (!defined($tu_list_file)){
	$tu_list_file = 'none';
    }
}

sub assignGlobalValues {
    
    ## Define all lookups here

    ## set defaults for host and rdbms if not already set
    $host = 'SYBTIGR' if( !$host );
    $rdbms = 'Sybase' if( !$rdbms );

    ## These are the only valid schema types
    $validSchemaTypes = { 'prok' => 1,
			  'ntprok' => 1,
			  'euk' => 1 };

    ## These are the only valid mode types
    $validModeTypes = { '1' => 1,   # migrate annotation only
			'2' => 1,   # migrate annotation and computational analysis
			'3' => 1 }; # migrate computational analysis only


    ## The type of legacy database schema will dictate
    ## which Prism API Modules will be depended upon.
    $schemaTypeToConf = { 'euk' => "Euk:$rdbms:$host",
			  'ntprok' => "Prok:$rdbms:$host",
			  'prok' => "Prok:$rdbms:$host" };

    ## The legacy annotation feat_types are mapped
    ## to specific SO types
    $classMappingLookup = { 'NTORF' => 'NTORF',
			    'ORF'   => 'ORF',
			    'tRNA'  => 'tRNA',
			    'snRNA'  => 'snRNA',
			    'sRNA'  => 'snRNA',
			    'rRNA'  => 'rRNA',
			    'ncRNA' => 'ncRNA',
			    'TERM'  => 'terminator',
			    'RBS'   => 'ribosome_entry_site',
			    'NTrRNA'  => 'rRNA',
			    'NTtRNA'  => 'tRNA',
			    'NTmisc_RNA'  => 'ncRNA',
			    'PMARK'  => 'pmark_spacer',
			    'TU'     => 'TU',
			    'model'  => 'model'		     
			};


    ## In order to set the genetic code based on the schema type.
    $schemaTypeToGeneticCodeLookup = { 'euk' => 1,
				       'prok' => 11,
				       'ntprok' => 11 };

    ## These are the euk feat_types which are migrated into BSML
    ## <Sequence> element objects.
    $eukSequenceTypes = { 'TU' => 1,
			  'model' => 1,
			  'TERM' => 1,
			  'RBS' => 1  };


    ## These are the prok feat_types which are migrated into BSML
    ## <Sequence> element objects.
    $prokSequenceTypes = { 'ORF' => 1,
			   'TERM' => 1,
			   'RBS' => 1,
			   'PMARK' => 1};

    ## These are the ntprok feat_types which are migrated into BSML
    ## <Sequence> element objects.
    $ntprokSequenceTypes = { 'NTORF' => 1,
			     'TERM' => 1,
			     'RBS' => 1,
			     'PMARK' => 1 };

    ## It is okay for asm_feature.sequence == null where feat_type are the following:
    $noDieNullAsmFeatureSequenceLookup = { 'PMARK' => 1 };


    $schemaTypeToSequenceTypes = { 'euk' => $eukSequenceTypes,
				   'prok' => $prokSequenceTypes,
				   'ntprok' => $ntprokSequenceTypes };


    $accessionDatabaseLookup = { 'PID' => 'NCBI_gi',
				 'protein_id' => 'Genbank',
				 'SP' => 'Swiss-Prot',
				 'ECOCYC' => 'Ecocyc' };


    $rnaFeatureTypes = { 'tRNA' => 1,
			 'rRNA' => 1,
			 'sRNA' => 1,
			 'ncRNA' => 1 };


    $ntprokRnaFeatureTypes = { 'NTtRNA' => 1,
			       'NTrRNA' => 1,
			       'NTmisc_RNA' => 1 };

    $schemaTypeToRnaFeatureTypes = { 'euk' => $rnaFeatureTypes,
				     'prok' => $rnaFeatureTypes,
				     'ntprok' => $ntprokRnaFeatureTypes };



    $peptideScoreTypeLookup = { 'Y-score' => 'y-score',
				'signal pep prob' => 'signal_probability',
				'cleavage site prob' => 'max_cleavage_site_probability',
				'site' => 'NN_cleavage_site',
				'S-score' => 's-score',
				'C-score' => 'c-score' };



    $identXrefTypeLookup = { 'product name' => 'gene_product_name',
			     'gene name' => 'gene_name',
			     'gene symbol' => 'gene_symbol',
			     'genbank accession' => 'genbank' };


    $schemaTypeToGoRoleFeatureType = { 'euk' => 'TU',
				       'prok' => 'ORF',
				       'ntprok' => 'NTORF' };



    $berScoreTypeLookup = { 'Pvalue' => 'runprob',
			    'score' => 'runscore',
			    'per_id' => 'percent_identity',
			    'per_sim' => 'percent_similarity'};

    

    $hmm2ScoreTypeLookup = { 'e-value' => 'runprob' ,
			     'score' => 'runscore' };


    $prositeScoreTypeLookup = { 'hit' => 'residues' };

    $computeScoreTypeLookup = { 'HMM2' => $hmm2ScoreTypeLookup,
				'PROSITE' => $prositeScoreTypeLookup,
				'BER' => $berScoreTypeLookup };


    $prokSchemaTypeToFeature = {'prok' => 'ORF',
				'ntprok' => 'NTORF' };


    $prokOrfAttributeAttTypes = { 'VIR' => 'VIR',
				  'MW' => 'MW',
				  'PI' => 'pI',
				  'OMP' => 'outer_membrane_protein' };


    $legacyAnnoAttTypes = { 'coords' => 'transmembrane_coords',
			    'regions' => 'transmembrane_regions',
			    'OMP' => 'outer_membrane_protein' };


    $prokCdsOrfAttributeAttTypes = { 'GC' => 'percent_GC' };


    $berEvTypeLookup = { 'BER' => 1,
			 'AUTO-BER' => 1 };

    $hmm2EvTypeLookup = { 'HMM2' => 1 };

    $cogEvTypeLookup = { 'COG accession' => 1 };

    $prositeEvTypeLookup = { 'PROSITE' => 'PROSITE' };

    $computeEvTypeLookup = { 'HMM2' => $hmm2EvTypeLookup,
			     'BER' => $berEvTypeLookup,
			     'COG' => $cogEvTypeLookup,
			     'PROSITE' => $prositeEvTypeLookup};

    $cloneInfoTypes = { 'assembly_status' => 1,
#		       'length' => 1,
			'is_final' => 1,
			'fa_left' => 1,
			'fa_right' => 1,
			'fa_orient' => 1,
			'gb_description' => 1,
			'gb_comment' => 1,
			'gb_date' => 1,
			'comment' => 1,
			'assignby' => 1,
			'date' => 1,
			'gb_date_for_release' => 1,
			'gb_date_released' => 1,
			'gb_authors1' => 1,
			'gb_authors2' => 1,
			'gb_keywords' => 1,
			'sequencing_type' => 1,
			'is_prelim' => 1,
			'is_licensed' => 1,
			'gb_phase' => 1,
			'chromosome' => 1,
			'gb_gi' => 1 };


    $cloneInfoAnnotationTypes = { 'is_orig_annotation' => 'Primary_annotation',
				  'is_tigr_annotation' => 'TIGR_annotation' };

    
    $cloneInfoDatabaseIdentifierLookup = { 'seq_asmbl_id' => 'seq_id',
					   'lib_id' => 'lib_id',
					   'clone_id' => 'clone_id' };



    $rbsAnalysisAttributeLookup = { 'version' => 'RBS_version',
				    'program' => 'RBS',
				    'name' => 'RBS_analysis',
				    'method' => 'RBS',
				    'sourcename' => $sourcename };

    $termAnalysisAttributeLookup = { 'version' => 'TERM_version',
				     'program' => 'TERM',
				     'name' => 'TERM_analysis',
				     'method' => 'TERM',
				     'sourcename' => $sourcename };

    $hmm2AnalysisAttributeLookup = { 'version' => 'HMM2_version',
				     'program' => 'HMM2',
				     'name' => 'HMM2_analysis',
				     'sourcename' => $sourcename };

    $ber2AnalysisAttributeLookup = { 'version' => 'BER_version',
				     'program' => 'BER',
				     'name' => 'BER_analysis',
				     'sourcename' => $sourcename };

    $ncbiCogAnalysisAttributeLookup = { 'version' => 'legacy',
					'program' => 'NCBI_COG',
					'name' => 'NCBI_COG',
					'sourcename' => $sourcename };

    $prositeAnalysisAttributeLookup = { 'version' => 'legacy',
					'program' => 'PROSITE',
					'name' => 'PROSITE',
					'sourcename' => $sourcename };

    $interproAnalysisAttributeLookup = { 'version' => 'legacy',
					 'program' => 'INTERPRO',
					 'name' => 'INTERPRO',
					 'sourcename' => $sourcename };

    $repeatMaskerAnalysisAttributeLookup = { 'version' => 'legacy',
					     'program' => 'RepeatMasker',
					     'method' => 'RepeatMasker',
					     'name' => 'RepeatMasker',
					     'sourcename' => $sourcename };


    $analysisAttributeLookup = { 'RBS' => $rbsAnalysisAttributeLookup,
				 'TERM' => $termAnalysisAttributeLookup,
				 'HMM2' => $hmm2AnalysisAttributeLookup,
				 'NCBI_COG' => $ncbiCogAnalysisAttributeLookup,
				 'PROSITE' => $prositeAnalysisAttributeLookup,
				 'RepeatMasker' => $repeatMaskerAnalysisAttributeLookup,
				 'BER' => $ber2AnalysisAttributeLookup,
				 'INTERPRO' => $interproAnalysisAttributeLookup};
    
    $computeDatabaseLookup = { 'PFAM' => 'Pfam',
			       'PF' => 'Pfam',
			       'COG' => 'COG_Cluster',
			       'PS' => 'PROSITE',
			       'TIGR' => 'TIGR_TIGRFAMS',
			       'TIGRFAM' => 'TIGR_TIGRFAMS'
			   };


    $terminatorAttributeLookup = { 'direction' => 'term_direction',
				   'confidence' => 'term_confidence' };

    $seqPairRunAttributeTypes = { 'refpos' => 1,
				  'runlength' => 1,
				  'refcomplement' => 1,
				  'comppos' => 1,
				  'comprunlength' => 1,
				  'compcomplement' => 1,
				  'runscore' => 1,
				  'runprob' => 1 };

    $secondaryTypeLookup = { 'pseudomolecule' => 'supercontig',
			     'pseudo' => 'supercontig',
			     'plasmid' => 'plasmid',
			     'chromosome' => 'chromosome' };


    $featTypeToMoleculeTypeLookup = { 'assembly' => 'dna',
				      'polypeptide' => 'aa',
				      'CDS' => 'dna',
				      'tRNA' => 'dna',
				      'rRNA' => 'dna',
				      'snRNA' => 'dna',
				      'ncRNA' => 'dna',
				      'TERM' => 'dna',
				      'RBS' => 'dna',
				      'NTrRNA' => 'dna',
				      'NTtRNA' => 'dna',
				      'NTmisc_RNA' => 'dna',
				      'PMARK' => 'dna' };


    $eukOrfAttTypeLookup = { 'SP-HMM' => 'signalP_curated',
			     'targetP' => 'targetP_curated'};


    $storeSequenceAsSeqData = { 'pmark_spacer' => 1 };

    $withEvToEvidenceLookup = { 'SwissProt' => 'GO_REF:0000012',
				'UniProt' => 'GO_REF:0000012',
				'protein_id' => 'GO_REF:0000012',
				'NCBI_gi' => 'GO_REF:0000012',
				'PIR' => 'GO_REF:0000012',
				'TIGR_CMR' => 'GO_REF:0000012',
				'TIGR_TIGRFAMS' =>  'GO_REF:0000011',
				'Pfam' => 'GO_REF:0000011' };

}


#----------------------------------------------------------------------------------------
# create_euk_sequence_lookup()
#
# This lookup will only contain:
# 1) polypeptide
# 2) CDS
# 3) tRNA
# 4) rRNA
# 5) sRNA
# 6) Terminator
# 7) RBS
#
#----------------------------------------------------------------------------------------
sub create_euk_sequence_lookup {

    my ($prism, $asmbl_id, $database, $model_feat_names) = @_;

    my $asmblhash = {};

    my @fullret;
    
    $prism->check_and_set_text_size();

    foreach my $feat_type (keys %{$eukSequenceTypes} ) {

	my $ret;

	if ($feat_type eq 'model'){

	    $ret = $prism->modelSequences($asmbl_id, $database);

	} else {
	    $ret = $prism->sequence_features($asmbl_id, $database, $feat_type);
	}
	
	foreach my $block ( @{$ret} ){
	    
	    $block->[1] = &cleanse_uniquename($block->[1]);

	    ## Get the SO qualified term for this feature/sequence type
	    my $featType;

	    if ( exists $classMappingLookup->{$block->[2]}) {
		$featType = $classMappingLookup->{$block->[2]};
	    }
	    else {
		$logger->logdie("class was does not exist in classMappingLookup for feat_type '$block->[2]'");
	    }

	    my $tmphash = { 'feat_name' => $block->[1],
			    'feat_type' => $featType,
			    'sequence'  => $block->[3],
			    'seqlen'    => length($block->[3]),
			};
	    

	    if ($featType eq 'model'){
		#
		# Since the polypeptide is stored with the model in the legacy database table asm_feature,
		# need to store data twice-  once for the CDS and then for the polypeptide
		#

		## Need to only process qualified models (bug 2045)
		if (  exists $model_feat_names->{$block->[1]} ){
		    
		    $tmphash->{'feat_type'}  = 'CDS';

		    push ( @{$asmblhash->{$asmbl_id}}, $tmphash );		    
		    
		    if ((defined($block->[4])) and ($block->[4] !~ /^\s+$/)) {

			my $polypeptide_feat_name = $block->[1];
			$polypeptide_feat_name =~ s/\.m/\.p/;
			
			my $othertmphash = {
			    'feat_type' => 'polypeptide',
			    'feat_name' => $polypeptide_feat_name,
			    'sequence'  => $block->[4],
			    'seqlen'    => length($block->[4])
			};
			
			push ( @{$asmblhash->{$asmbl_id}}, $othertmphash );
		    }
		}
	    }
	    else{
		#
		# Load the following subfeatures onto the data structure
		# 1) tRNA
		# 2) rRNA
		# 3) sRNA
		# 4) ncRNA
		# 5) TERM
		# 6) RBS
		#
		push ( @{$asmblhash->{$asmbl_id}}, $tmphash );
	    }
	}
    }

    return ($asmblhash);
}

#----------------------------------------------------------------------------------------
# create_prok_sequence_lookup()
#
# This lookup will only contain:
# 1) polypeptide
# 2) CDS
# 3) tRNA
# 4) rRNA
# 5) sRNA
# 6) Terminator
# 7) RBS
#
#----------------------------------------------------------------------------------------
sub create_prok_sequence_lookup {

    my ($prism, $asmbl_id, $database, $schemaType) = @_;

    #
    # This function should call a lower level API function which returns...
    #
    # Data structure description:
    # This function should return a hash.  Each the key to each "bucket" will be the asmbl_id.
    # Each corresponding value will contain an array of hashes.  Each one of these "data_hashes"
    # will have the following structure:
    #
    # $data_hash = {
    #                 'feat_type' => $feat_type,
    #                 'seqlen'    => $seqlen,
    #                 'feat_name  => $feat_name,
    #                 'sequence'  => $sequence
    #              };
    #

    my $asmblhash = {};
    my @fullret;

    #
    # First, retieve all subfeatures for each asmbl_id
    #
   

    #
    # Should we retrieve all asmbl_ids in one
    # transaction and thus minimize the number of database hits? 
    # This necessitates iterating over list of qualified asmbl_ids to build
    # the final returned data structure.
    #
    # Or do we hit the database X times (database connectivity overhead?)
    # and request specific chunks?  This would eliminate the need to
    # iterate over some qualifying list later on...
    #
    # I am opting to poll the Sybase server one time only.
    #
    # There's also the question of whether a single embedded SQL query
    # should retrieve all desired subfeature feat_types, or whether a handful
    # of individual queries should be sent to the database requesting
    # data related to the specific feat_types.
    #
    # Again, I am inclined to poll the server one time.  This would mean that
    # get_sequence_features() would single-handedly retrieve
    # 1) CDS
    # 2) tRNA
    # 3) rRNA
    # 4) sRNA
    # 5) Terminator
    # 6) RBS
    #  sequence related data.  (Note that a separate query will return the polypeptide
    #  sequence data.)
    # But this does not jive with Sam's Coati conformity spec?
    # Also note that there is not Coati API function which supports the retrieval
    # of the desired feat_types.
    #
    # Thus I shall have to poll the database many times in order to request
    # specific feature types.(?)
    #
    # I'll compartmentilize this code.  Retrieval details I'll worry about later.
    # Meanwhile, the data structure I'm returning from this subroutine is fixed..
    #
    #

    my $sequenceTypeLookup = $schemaTypeToSequenceTypes->{$schemaType};

    $prism->check_and_set_text_size();

    foreach my $feat_type (keys %{$sequenceTypeLookup} ) {

	my $ret = $prism->sequence_features($asmbl_id, $database, $feat_type, $schemaType);
	
	foreach my $block ( @{$ret} ){

	    if (!defined($block->[3])){

		## Added 2008-10-22 sundaram
		if ($block->[2] eq 'TERM'){
		    next;
		}

		if (!defined($noDieNullAsmFeatureSequence)){
		    ## Die if the asm_feature.sequence is NULL
		    $logger->logdie("asm_feature.sequence was NULL for ".
				    "feat_name '$block->[1]' asmbl_id ".
				    "'$asmbl_id' database '$database' ".
				    "feat_type '$feat_type'");
		}
		else {
		    $logger->warn("asm_feature.sequence was NULL for ".
				  "feat_name '$block->[1]' asmbl_id ".
				  "'$asmbl_id' database '$database' ".
				  "feat_type '$feat_type'");
		}
	    }

	    my $featName = &cleanse_uniquename($block->[1]);

	    my $featType;

	    if ( exists $classMappingLookup->{$block->[2]}) {
		$featType = $classMappingLookup->{$block->[2]};
	    }
	    else {
		$logger->logdie("class was does not exist in classMappingLookup ".
				"for feat_type '$block->[2]' database '$database' ".
				"asmbl_id '$asmbl_id' feat_name '$featName'");
	    }

	    my $tmphash = { 'feat_name' => $featName,
			    'feat_type' => $featType,
			    'sequence'  => $block->[3],
			    'seqlen'    => length($block->[3]),
			};
	    

	    if (($featType eq 'ORF') || ($featType eq 'NTORF')){

		$tmphash->{'feat_type'}  = 'CDS';

		push ( @{$asmblhash->{$asmbl_id}}, $tmphash );		    
		
		## We need to store the sequence with the transcript also
		## for proks and ntproks.  Unfortunately, this means
		## duplicating the data in the lookup.
		my $transcriptOrfLookup = { 'feat_name' => $featName,
					    'feat_type' => 'transcript',
					    'sequence'  => $block->[3],
					    'seqlen'    => length($block->[3]),
					};


		push ( @{$asmblhash->{$asmbl_id}}, $transcriptOrfLookup );		    


		if ((defined($block->[4])) and ($block->[4] !~ /^\s+$/)) {
		    ## Store data to be used later to create the
		    ## prok and ntprok polypeptide Feature
		    my $othertmphash = { 'feat_type' => 'polypeptide',
					 'feat_name' => $block->[1],
					 'sequence'  => $block->[4],
					 'seqlen'    => length($block->[4])
				     };

		    push ( @{$asmblhash->{$asmbl_id}}, $othertmphash );
		}
	    }
	    else{
		#
		# Load the following subfeatures onto the data structure
		# 1) tRNA
		# 2) rRNA
		# 3) sRNA
		# 4) ncRNA
		# 5) TERM
		# 6) RBS
		#
		push ( @{$asmblhash->{$asmbl_id}}, $tmphash );
	    }
	}
    }

    return ($asmblhash);
    
}

#----------------------------------------------------------------------------------------
# create_prok_gene_model_lookup()
# 
# This lookup will only contain ORF data
#
#----------------------------------------------------------------------------------------
sub create_prok_gene_model_lookup {

    my ($prism, $asmbl_id, $database, $schemaType, $alt_database) = @_;
    
    #
    # Note: replace feat_name with locus if locus is defined.
    #
    # This subroutine should return a hash containing an arrays which contain hashes
    # The hash's key will be the asmbl_id
    # The array of hashes will contain anonymous hashes of the form:
    #
    # $data_hash = {
    #                'feat_name'  => asm_feature.feat_name || ident.locus
    #                'end5'       => compute(end5,end3)
    #                'end3'       => compute(asm_feature.end5, asm_feature.end3)
    #                'complement' => compute(asm_feature.end5, asm_feature.end3)
    #                'locus'      => ident.locus
    #
    my $rethash = {};

    my $ret = $prism->gene_model_data($asmbl_id, $database, $schemaType);
    
    if (defined($alt_database)){
	$database = $alt_database;
    }

    #--------------------------------------------
    #
    # Returned values:
    #
    #
    # 0 => asm_feature.asmbl_id
    # 1 => asm_feature.feat_name
    # 2 => asm_feature.end5
    # 3 => asm_feature.end3
    # 4 => ident.locus
    # 5 => ident.locus OR ident.nt_locus
    #
    #--------------------------------------------


    foreach my $block ( @{$ret} ) {
	
	my ($end5, $end3, $complement) = &coordinates($block->[2], $block->[3]);
	
	$block->[1] = &cleanse_uniquename($block->[1]);

	## If locus or display_locus contain blanks, store undef (bug 2035).
	if (($block->[4] =~ /\s+/) || (lc($block->[4]) eq 'null')){
	    $block->[4] = undef;
	}

	if (($block->[5] =~ /\s+/) || (lc($block->[5]) eq 'null')){
	    $block->[5] = undef;
	}
	
	## If the locus is not defined, then should be set to
	## "database name" + '_' + "asm_feature.feat_name" (bug 2257).
	if (!defined($block->[4])){
	    $block->[4] = $database .'_' . $block->[1];
	}
	
	my $tmphash = { feat_name      => $block->[1],
			end5           => $end5,
			end3           => $end3,
			complement     => $complement,
			locus          => $block->[4],
			display_locus  => $block->[5]
		    };
	
	push( @{$rethash->{$block->[0]}}, $tmphash );
	
    }

    return ($rethash);
}


#----------------------------------------------------------------------------------------
# create_accession_lookup()
# 
# This lookup will only contain ORF data
#
#----------------------------------------------------------------------------------------
sub create_accession_lookup {

    my ($prism, $asmbl_id, $database, $schemaType) = @_;
    
    my $rethash = {};
    
    my $ret = $prism->accession_data($asmbl_id, 
				     $database,
				     $schemaType);
    
    my $nullCtr=0;

    foreach my $block ( @{$ret} ) {
	
	if ((!defined($block->[3])) || (lc($block->[3]) eq 'null') || ($block->[3] eq '')){
	    $logger->warn("Excluding accession record for ".
			  "feat_name '$block->[1]' with ".
			  "database '$block->[2]' because ".
			  "accession.accession_id is not defined");
	    $nullCtr++;
	    next;
	}


	$block->[1] = &cleanse_uniquename($block->[1]);
	
	my $qualifiedDbName;

	if ( exists $accessionDatabaseLookup->{$block->[2]}) {

	    $qualifiedDbName = $accessionDatabaseLookup->{$block->[2]};
	}
	else {
	    $qualifiedDbName = $block->[2];
	}


	#          asmbl_id        feat_name      accession_db    accesion_id  
	$rethash->{$block->[0]}->{$block->[1]}->{$qualifiedDbName} = $block->[3];
	    
    }


    if ($nullCtr > 0 ){
	print "Excluded '$nullCtr' accession records because ".
	"of undefined accession.accession_id values\n";
    }

   return ($rethash);
  
}
 



#--------------------------------------------------------------------------------
# coordinates()
#
#--------------------------------------------------------------------------------
sub coordinates {

    my ($end5, $end3) = @_;

    #
    # //Feature/Interval-loc/@complement = 0 means chado.featureloc.strand = 1  (forward)
    # //Feature/Interval-loc/@complement = 1 means chado.featureloc.strand = -1 (reverse)
    #
    my $complement = 0;

    if ($end5 > $end3){
	
	$complement = 1;
	my $tmp = $end5;
	$end5 = $end3;
	$end3 = $tmp;
    }

    #
    # Convert to space-based coordinate system
    #
    $end5--;

    return ($end5, $end3, $complement);



}

##---------------------------------------------------------------------
## createRnaLookup()
##
##---------------------------------------------------------------------
sub createRnaLookup {

    my ($prism, $asmbl_id, $database, $schemaType, $alt_database, $rnaLookup) = @_;

    if (!defined($alt_database)){
	$alt_database = $database;
    }

    $prism->rnaDataByAsmblId($asmbl_id, $database, $schemaType, $rnaLookup);

    my $trnaScoreLookup = $prism->trnaScoresLookup($asmbl_id, $database, $schemaType);

    if (defined($trnaScoreLookup)){
	foreach my $feat_name (keys %{$trnaScoreLookup}){
	    if (exists $rnaLookup->{$feat_name}){
		push(@{$rnaLookup->{$feat_name}}, $trnaScoreLookup->{$feat_name});
	    }
	}
    }
}


#----------------------------------------------------------------------------------------
# create_trna_score_lookup()
# 
# This function will create a feat_score.score lookup for all tRNA related records
# Legacy tables involved:
#
#----------------------------------------------------------------------------------------
sub create_trna_score_lookup {

    my ($prism, $asmbl_id, $database, $schemaType, $feat_type) = @_;

    #
    # This subroutine should return a hash.
    # The hash's key will be the asm_feature.feat_name where asm_feature.feat_type = 'tRNA'
    # The values will be the corresponding feat_score.score
    #
    # $data_hash = {
    #                'asm_feature.feat_name'  => feat_score.score
    #              }
    #
    #

    my $rethash = {};
    
    my $ret = $prism->trna_scores($asmbl_id, 
				  $database,
				  $schemaType,
				  $feat_type);
        
    foreach my $block ( @{$ret} ) {
	
	$block->[0] = &cleanse_uniquename($block->[0]);
	
	$rethash->{$block->[0]} = $block->[1];
    }

    return ($rethash);
}


#----------------------------------------------------------------------------------------
# create_ribosome_lookup()
# 
# This lookup will only contain ribosomal binding site data
#
#----------------------------------------------------------------------------------------
sub create_ribosome_lookup {

   my ($prism, $asmbl_id, $database) = @_;

   #
   # This subroutine should return a hash containing a arrays each of which contain hashes
   # The primary hash's key will be the asmbl_id
   # The array of hashes will contain anonymous hashes of the form:
   #
   # $data_hash = {
   #                'feat_name'  => asm_feature.feat_name WHERE 
   #                'end5'       => compute(asm_feature.end5, asm_feature.end3)
   #                'end3'       => compute(asm_feature.end5, asm_feature.end3)
   #                'complement' => compute(asm_feature.end5, asm_feature.end3)
   #              }
   #
   #
   #
   #  Whose construction will depend on an auxilliary hash containing
   #  (Could use table flattening or temp table strategy... )
   
   my $rethash = {};
   
   my $ret = $prism->ribosomal_data($asmbl_id, $database);
   
   foreach my $block ( @{$ret} ) {
       
       $block->[1] = &cleanse_uniquename($block->[1]);

       my ($end5, $end3, $complement) = &coordinates($block->[2], $block->[3]);
       
       my $tmphash = { 'feat_name'   =>  $block->[1],
		       'end5'        =>  $end5,
		       'end3'        =>  $end3,
		       'complement'  =>  $complement
		   };
       
       push( @{$rethash->{$block->[0]}}, $tmphash );
   }
   
   return ($rethash);
}

#----------------------------------------------------------------------------------------
# create_terminator_lookup()
# 
# This lookup will only contain terminator binding site data
#
#----------------------------------------------------------------------------------------
sub create_terminator_lookup {

   my ($prism, $asmbl_id, $database) = @_;

   #
   # This subroutine should return a hash containing a arrays each of which contain hashes
   # The primary hash's key will be the asmbl_id
   # The array of hashes will contain anonymous hashes of the form:
   #
   # $data_hash = {
   #                'feat_name'  => asm_feature.feat_name WHERE feat_type = 'TERM'
   #                'end5'       => compute(asm_feature.end5, asm_feature.end3) WHERE feat_type = 'TERM'
   #                'end3'       => compute(asm_feature.end5, asm_feature.end3) WHERE feat_type = 'TERM'
   #                'complement' => compute(asm_feature.end5, asm_feature.end3) WHERE feat_type = 'TERM'
   #                'TERM'       => asm_feature.comment WHERE feat_type = 'TERM'
   #              }
   #
   #
   my $term_direction_hash = &create_term_direction_hash($prism, $asmbl_id, $database);

   my $term_confidence_hash = &create_term_confidence_hash($prism, $asmbl_id, $database);
   
   my $rethash = {};
   
   my $ret = $prism->terminator_data($asmbl_id, $database);
   
   foreach my $block ( @{$ret} ) {
       
       $block->[1] = &cleanse_uniquename($block->[1]);
       
       my ($end5, $end3, $complement) = &coordinates($block->[2], $block->[3]);
       
       my $tmphash = { 'feat_name'   =>  $block->[1],
		       'end5'        =>  $end5,
		       'end3'        =>  $end3,
		       'complement'  =>  $complement,
		       'direction'   =>  $term_direction_hash->{$asmbl_id}->{$block->[1]},
		       'confidence'  =>  $term_confidence_hash->{$asmbl_id}->{$block->[1]},
		   };
       
       
       push( @{$rethash->{$block->[0]}}, $tmphash );
   }

   return ($rethash);
}

#----------------------------------------------------------------------------------------
# create_term_direction_hash()
# 
# 
#----------------------------------------------------------------------------------------
sub create_term_direction_hash {

    my ($prism, $asmbl_id, $db) = @_;
    
    my $rethash = {};
    
    my $ret = $prism->term_direction_data($asmbl_id, $db);
    
    foreach my $block ( @{$ret} ) {
	
	$block->[1] = &cleanse_uniquename($block->[1]);
	
	$logger->logdie("block[0] '$block->[0]' ne asmbl_id '$asmbl_id'") if ($block->[0] ne $asmbl_id);
	    
	#    assembly.asmbl_id   asm_feature.feat_name   feat_score.score
	$rethash->{$asmbl_id}->{$block->[1]} = $block->[2];
    }
    
   return ($rethash);
}

#----------------------------------------------------------------------------------------
# create_term_confidence_hash()
# 
#----------------------------------------------------------------------------------------
sub create_term_confidence_hash {

    my ($prism, $asmbl_id, $db) = @_;
    
    my $rethash = {};
    
    my $ret = $prism->term_confidence_data($asmbl_id, $db);
    
    foreach my $block ( @{$ret} ) {
	
	$block->[1] = &cleanse_uniquename($block->[1]);
	
	$logger->logdie("block[0] '$block->[0]' ne asmbl_id '$asmbl_id'") if ($block->[0] ne $asmbl_id);
	
	#    assembly.asmbl_id   asm_feature.feat_name   feat_score.score
	$rethash->{$asmbl_id}->{$block->[1]} = $block->[2];
	
    }
    
   return ($rethash);
}


#----------------------------------------------------------------------------------------
# create_terminator_to_gene_lookup()
# 
#----------------------------------------------------------------------------------------
sub create_terminator_to_gene_lookup {

   my ($prism, $asmbl_id, $database) = @_;
   
   my $rethash = {};
   
   my $ret = $prism->terminator_to_gene_data($asmbl_id, $database);
   
   foreach my $block ( @{$ret} ) {
       
       $block->[1] = &cleanse_uniquename($block->[1]);
       
       $rethash->{$block->[0]}->{$block->[1]} = $block->[2];
   }

   return ($rethash);
}


#----------------------------------------------------------------------------------------
# create_rbs_to_gene_lookup()
# 
#----------------------------------------------------------------------------------------
sub create_rbs_to_gene_lookup {

   my ($prism, $asmbl_id, $database) = @_;
   
   my $rethash = {};
   
   my $ret = $prism->rbs_to_gene_data($asmbl_id, $database);
   
   foreach my $block ( @{$ret} ) {
       
       $block->[1] = &cleanse_uniquename($block->[1]);
       
       $rethash->{$block->[0]}->{$block->[1]} = $block->[2];
   }
   
   return ($rethash);
}

#----------------------------------------------------------------------------------------
# create_ident_attributes_lookup()    --    Gene annotation attributes
# 
# This lookup will only contain ident attribute data for the ORFs
#
#----------------------------------------------------------------------------------------
sub create_ident_attributes_lookup {

   my ($prism, $asmbl_id, $database, $alt_database, $schemaType) = @_;

   #
   # This subroutine will return a hash containing a hash.
   # The primary hash's key will be the $transcript (feat_name).  The secondary hash
   # will be in the following form:
   # 
   # $data_hash = {
   #                'gene_product_name'    => ident.com_name,
   #                'assignby'             => ident.assignby,
   #                'date'                 => ident.date,
   #                'comment'              => ident.comment,
   #                'nt_comment'           => ident.nt_comment',
   #                'public_comment'           => ident.pub_comment',
   #                'auto_comment          => ident.auto_comment,
   #                'gene_sym'             => ident.gene_sym,
   #                'start_site_editor'    => ident.start_site,
   #                'completed_by'         => ident.complete,
   #                'auto_annotate_toggle' => ident.auto_annotate,
   #                'ec_number'            => ident.ec#
   #
   my $rethash = {};
   
   my $ret = $prism->gene_annotation_ident_attribute_data($asmbl_id, 
							  $database,
							  $schemaType);

   if (defined($alt_database)){
       $database = $alt_database;
   }

   
   my $rulesLookup = { '2' => 'gene_product_name',
		       '3' => 'assignby',
		       '4' => 'date',
		       '5' => 'comment',
		       '6' => 'nt_comment',
		       '7' => 'auto_comment',
		       '8' => 'gene_symbol',
		       '9' => 'start_site_editor',
		       '10' => 'completed_by',
		       '11' => 'auto_annotate_toggle',
		       '13' => 'public_comment',
		       '15' => 'public_comment'
		   };

   foreach my $block ( @{$ret} ) {
       
       $block->[1] = &cleanse_uniquename($block->[1]);

       my $transcript = &get_uniquename($prism,
					$database,
					$asmbl_id,
					$block->[1],
					'transcript');
       
       ## Change the return data structure to accomodate inclusion of 
       ## attribute-list sublist reference.  For all attributes to be
       ## stored in an <Attribute> element and NOT in an <Attribute-list> 
       ## element we will push the attributes onto the 
       ## @{$rethash->{$transcript}->{'attribute'}} array

       foreach my $index ( keys %{$rulesLookup} ) {
	   
	   my $data = $block->[$index];
	   
	   if (defined($data)){

	       $data = &remove_cntrl_chars($data);
	       $data =~ s/\015//g;
	       $data =~ s/\t/\\t/g;
	       $data =~ s/\n/\\n/g;

	       if ($index == 2){
		   if (($data =~ /^\s*$/) || ($data =~ /NULL/)){
		       $logger->warn("Encountered an empty value for the gene_product_name ".
				     "while processing feat_name '$block->[1]' uniquename ".
				     "'$transcript'");
		       next;
		   }
	       }
	       elsif ($index == 5){
		   if (($data =~ /^\s+$/) || ($data =~ /NULL/)){
		       next;
		   }
	       }
	       elsif ($index == 6){
		   if ((length($data) < 1) || ($data =~ /^\s*$/)){
		       next;
		   }
	       }
	       elsif ($index == 8){
		   if ($data =~ /^\s+$/){
		       next;
		   }
	       }
	       elsif (($index == 9) || ($index == 10) || ($index == 11) || ($index == 13)){
		   ## Verify whether start_site_editor is blank/null (bug 2037)
		   if (($data eq '') || ( length($data) < 1 ) || ($data =~ /^\s*$/)) {
		       next;
		   }
	       }
	       
	       ## store the data
	       push ( @{$rethash->{$transcript}->{'attribute'}}, { $rulesLookup->{$index} => $data } );
	   }

	   ## Now adding the ec# to a <Attribute-list>.  This will result in the
	   ## creation of a chado.feature_cvterm record linking the feature to the cvterm.
	   ## This will be the resulting chado table/record relationship:
	   ## WHERE feature.feature_id = feature_cvterm.feature_id
	   ## AND feature_cvterm.cvterm_id = cvterm.cvterm_id
	   ## AND cvterm.dbxref_id = cvterm_dbxref.dbxref_id
	   ## AND dbxref.accession = ec#

	   if ( (defined($block->[12])) && ( length($block->[12]) > 0 ) && ( $block->[12] ne '' ) ) {

	       my @eclist = split(/\s+/,$block->[12]);

	       foreach my $ec (sort @eclist){
		   
		   my $smalllist;
		   
		   push (@ {$smalllist}, { 'EC' => $ec } );
		   
		   push( @{$rethash->{$transcript}->{'attribute-list'}}, $smalllist);
		   
	       }
	   }
       }
   }
   return ($rethash);
}


#----------------------------------------------------------------------------------------
# create_ident_xref_attr_lookup()
#
#----------------------------------------------------------------------------------------
sub create_ident_xref_attr_lookup {

   my ($prism, $asmbl_id, $database, $alt_database) = @_;

   my $rethash = {};

   my $idatabase = $database;

   if (defined($alt_database)){
       $idatabase = $alt_database;
   }

   foreach my $xref_type ('ec number', 'product name', 'gene name', 'gene symbol', 'genbank accession') {

       my $ret = $prism->ident_xref_attr_data($asmbl_id, $database, $xref_type);

       #
       # Returned columns from Prism::EukPrismDB::get_ident_xref_attr_data()
       #
       # 0 => f.asmbl_id
       # 1 => i.feat_name
       # 2 => i.ident_val
       # 3 => i.relrank
       #
       
       foreach my $block ( @{$ret} ) {
	   
	   $block->[1] = &cleanse_uniquename($block->[1]);

	   my $transcript = &get_uniquename($prism,
					    $idatabase,
					    $asmbl_id,
					    $block->[1],
					    'transcript');
	   

	   if ( (defined($block->[2])) && (length($block->[2]) > 0  ) && ($block->[2] ne '') ) {
	       
	       $block->[2] = remove_cntrl_chars($block->[2]);
	       $block->[2] =~ s/\015//g;
	       $block->[2] =~ s/\t/\\t/g;
	       $block->[2] =~ s/\n/\\n/g;
	       
	       
	       if ( exists $identXrefTypeLookup->{$xref_type} ) {
		   push ( @{$rethash->{$transcript}->{'attribute'}}, { $identXrefTypeLookup->{$xref_type} => $block->[2] } );
	       }
	       elsif ( $xref_type eq 'ec number') {

		   my @eclist = split(/\s+/,$block->[2]);
		   
		   foreach my $ec (sort @eclist){
		       
		       my $smalllist;
		       
		       push (@ {$smalllist}, { 'EC' => $ec } );
		       
		       push( @{$rethash->{$transcript}->{'attribute-list'}}, $smalllist);
		       
		   }
	       }		       
	       else{
		   $logger->logdie("Unexpected xref_type '$xref_type'");
	       }

	   }
       }
   }


   return ($rethash);
   
}

#----------------------------------------------------------------------------------------
# create_tigr_roles_lookup()  --  Gene annotation attributes
# 
# This lookup will only contain TIGR Roles data for the ORFs
#
#----------------------------------------------------------------------------------------
sub create_tigr_roles_lookup {

    my ($prism, $asmbl_id, $database, $alt_database, $schemaType) = @_;
    
    #
    # This subroutine will return a hash containing a array of hashes.
    # The primary hash's key will be the $transcript (feat_name).  The arrays will have the
    # following structure:
    # 
    # $array = [
    #              {
    #                 'name'    => 'TIGR_role',
    #                 'content' => role_link.role_id
    #              },
    #              {
    #                 'name'    => 'assignby',
    #                 'content' => role_link.assignby
    #              },
    #              {
    #                 'name'    => 'date',
    #                 'content' => role_link.date
    #              }
    #          ],
    #          [
    #              {
    #                 'name'    => 'TIGR_role',
    #                 'content' => role_link.role_id
    #              }
    #          etc...
    
    my $ret = $prism->gene_annotation_go_attribute_data($asmbl_id, 
							$database,
							$schemaType);

    if (defined($alt_database)){
	$database = $alt_database;
    }

    my $rulesLookup =  { '2' => 'TIGR_role',
			 '3' => 'assignby',
			 '4' => 'date',
			 '5' => 'comment' };

    my $sublist;    
    
    foreach my $block ( @{$ret} ) {
	
	$block->[1] = &cleanse_uniquename($block->[1]);

	
	my $transcript = &get_uniquename($prism,
					 $database,
					 $asmbl_id,
					 $block->[1],
					 'transcript');
	
	my $loadFlag = 0;
	my @smallList;

	foreach my $index (sort keys %{$rulesLookup} ) {
	    
	    my $data = $block->[$index];
	    
	    if (defined($data)){
		
		if ( $index == 5 ){
		    
		    $data = &remove_cntrl_chars($data);
		    
		    $data =~ s/\s+/ /g; # change newline to space
		}
		
		push (@smallList, { $rulesLookup->{$index}  => $data });
		
		$loadFlag++;
	    }
	}

	if ($loadFlag > 0){
	    push ( @{$sublist->{$transcript}}, \@smallList );
	}

    }
    
    return $sublist;
}


#----------------------------------------------------------------------------------------
# create_go_roles_lookup()  --  Gene annotation attributes
# 
# This lookup will only contain GO Roles data for the ORFs
#
#----------------------------------------------------------------------------------------
sub create_go_roles_lookup {

    my ($prism, $asmbl_id, $database, $schemaType, $alt_database) = @_;

    my $feat_type;
    if ( exists $schemaTypeToGoRoleFeatureType->{$schemaType} ) {
	$feat_type = $schemaTypeToGoRoleFeatureType->{$schemaType};
    }
    else {
	$logger->logdie("feat_type did not exist for schema type '$schemaType'");
    }

    my $rethash = {};
   
    my $ret = $prism->gene_annotation_evidence_data($asmbl_id, $database, $feat_type);

    if (defined($alt_database)){
	$database = $alt_database;
    }
    
    foreach my $block ( @{$ret} ) {
	
	my $featName = &cleanse_uniquename($block->[1]);

	my $transcript = &get_uniquename($prism,
					 $database,
					 $asmbl_id,
					 $featName,
					 'transcript');
	
	my $evCode = $block->[6]; ##go_evidence.ev_code
	my $evidence = $block->[7]; ## go_evidence.evidence
	my $goId = $block->[2]; ##go_role_link.go_id
	my $withEv = $block->[8]; ## go_evidence.with_ev
	

	$evCode =~ s/^\s*//; ## remove leading white spaces
	$evCode =~ s/\s*$//; ## remove trailing white spaces


	if ((!defined($evCode)) || (length($evCode) < 1)){
	    $evCode = undef;
	    $logger->warn("GO record rejected because go_evidence.ev_code ".
			  "was not defined for GO ID '$goId' ".
			  "for asm_feature.asmbl_id '$asmbl_id' ".
			  "asm_feature.feat_name '$featName'");
	}

	if ((!defined($evidence)) || (length($evidence) < 1)){

	    $logger->warn("go_evidence.evidence was not defined for ".
			  "go_evidence.ev_code '$evCode' ".
			  "GO ID '$goId' ".
			  "asm_feature.asmbl_id '$asmbl_id' ".
			  "asm_feature.feat_name '$featName'. ".
			  "will attempt to derive value from ".
			  "go_evidence.with_ev '$withEv'");


	    if ((!defined($withEv)) || ( length($withEv) < 1) || ($withEv =~ /^\s*$/)){
		$logger->warn("Neither go_evidence.evidence nor go_evidence.with_ev ".
			      "were defined for go_evidence.ev_code '$evCode' ".
			      "GO ID '$goId' ".
			      "asm_feature.asmbl_id '$asmbl_id' ".
			      "asm_feature.feat_name '$featName'. ".
			      "will attempt to derive value from ".
			      "go_evidence.with_ev '$withEv'");
	    }

	    my @dataArray = split(/:/, $withEv);
	    
 	    if (($dataArray[0] eq 'TIGRFAMS') || ($dataArray[0] eq 'TIGR')) {
		## Some auto-correcting
		$logger->warn("The following go_evidence.with_ev '$withEv' ".
			      "needs to corrected for database '$database' ".
			      "asmbl_id '$asmbl_id' asm_feature.feat_name ".
			      "'$featName' go_evidence.ev_code '$evCode'. ".
			      "The prefix $dataArray[0] should be changed to ".
			      "TIGR_TIGRFAMS in the annotation database. ".
			      "$0 auto-adjusted the output value ".
			      "during the creation of the BSML gene model ".
			      "document.");
		$dataArray[0] = 'TIGR_TIGRFAMS';

	    }

	    if ( exists $withEvToEvidenceLookup->{$dataArray[0]} ) {
		$evidence = $withEvToEvidenceLookup->{$dataArray[0]};
	    }
	    else {
		$logger->warn("Could not derive go_evidence.evidence for ".
			      "go_evidence.with_ev '$withEv' ".
			      "GO ID '$goId' ".
			      "asm_feature.asmbl_id '$asmbl_id' ".
			      "asm_feature.feat_name '$featName' ");
	    }

	    if ( scalar(@dataArray) > 2){
		## Some QC reporting.  Example garbage:
		## PIR:PIR:B27763 - there is an extra "PIR:"
		## TIGR_CMR:OMNI:BMA0413 - the "OMNI:" should not be there 
		$logger->warn("The following go_evidence.with_ev '$withEv' ".
			      "needs to corrected for database '$database' ".
			      "asmbl_id '$asmbl_id' asm_feature.feat_name ".
			      "'$featName' go_evidence.ev_code '$evCode'. ".
			      "The correction should be applied to the ".
			      "annotation database (should only be one set ".
			      "of colons in the prefix).  $0 auto-adjusted ".
			      "so the output is correct.");

		if ( scalar(@dataArray) == 3){
		    my $oldWithEv = $withEv;
		    $withEv = $dataArray[0] . ':' . $dataArray[2];
		    $logger->warn("Auto-corrected with_ev old '$oldWithEv' new '$withEv'");
		}
		else {
		    $logger->warn("Don't know how to auto-correct with_ev '$withEv'");
		}
	    }


	}

	## Store go_evidence and go_role_link data in the BSML only if 
	## go_evidence.ev_code and go_evidence.evidence contain valid data.
	## Otherwise, no data is stored.
	
	if ((defined($goId)) && ($goId !~ /NULL/)){
	    
	    my $tmparray;

	    ## Store go_role_link.go_id in the BSML only if the value is 
	    ## defined and not null.
	    push ( @{$tmparray}, { 'GO' => $goId  });

	    ## All other auxiliary go_role_link data is stored if defined.
	    if (defined($block->[3])){
		push ( @{$tmparray}, { 'assignby'  => $block->[3]  });
	    }
	    
	    if (defined($block->[4])){
		push ( @{$tmparray}, { 'date' => $block->[4] });
	    }
	    
	    if ((defined($block->[5])) and ($block !~ /^\s+$/)){
		push ( @{$tmparray}, { 'qualifier'  => $block->[5] });
	    }


	    if ( defined($evCode) && defined($evidence)){

		if (defined($withEv)){
		    $evidence .= " WITH " . $withEv;
		}
		
		push ( @{$tmparray}, { $evCode => $evidence });
	    }

	    push (@ {$rethash->{$transcript}}, $tmparray );

	}
    }

    return ($rethash);
}


#----------------------------------------------------------------------------------------
# create_prok_polypeptide_orf_attributes_lookup()  --  Gene annotation attributes
# 
# This lookup will only contain orf_attribute data for the ORFs
#
#----------------------------------------------------------------------------------------
sub create_prok_polypeptide_orf_attributes_lookup {

   my ($prism, $asmbl_id, $database, $alt_database, $schemaType) = @_;
   
   #
   # This subroutine will return a hash containing a array of hashes.
   # The primary hash's key will be the $transcript (feat_name).  The arrays will have the
   # following structure:
   # 
   # $h->{$transcript} = {
   #                        'attributes' => [
   #                                           {
   #                                              'name'    => 'MW',
   #                                              'content' => 
   #                                           },
   #                                           {
   #                                              'name'    => 'pI',
   #                                              'content' =>
   #                                           },
   #                                           {
   #                                              'name'    => 'GC',
   #                                              'content' => 
   #                                           }
   #                                        ],
   #                        'attributelist' => [
   #                                             [
   #                                                 
   #                                                { 
   #                                                   'name'    => 'transmembrance_coords',
   #                                                   'content' =>
   #                                                },
   #                                                {
   #                                                   'name'    => 'transmembrance_regions',
   #                                                   'content' =>
   #                                                },
   #                                                {
   #                                                   'name'    => 'lipo_membrane_protein',
   #                                                   'content' => 
   #                                             ],
   #           etc...
   #
   #

   my $rethash = {};

   my $transcripthash = {};

   my $idatabase = $database;

   if (defined($alt_database)){
       $idatabase = $alt_database;
   }
   
   my $lookup = {};

   foreach my $att_type ( keys %{$prokOrfAttributeAttTypes} ) {
       
       my $ret;

       if ($att_type eq 'VIR'){
	   $ret = $prism->virulenceFactors($asmbl_id, 
					   $database,
					   $prokSchemaTypeToFeature->{$schemaType});

       } else {
	   $ret = $prism->gene_orf_attributes($asmbl_id, 
					      $database,
					      $prokSchemaTypeToFeature->{$schemaType},
					      $att_type);
       }

       foreach my $block ( @{$ret} ){

	   $block->[1] = &cleanse_uniquename($block->[1]);

	   my $transcript = &get_uniquename($prism,
					    $idatabase,
					    $asmbl_id,
					    $block->[1],
					    'polypeptide');
	   
	   $transcripthash->{$transcript} = '';


	   if ((defined($block->[3])) && ($block->[3] !~ /^\s+$/)){

	       if (($block->[2] eq 'MW') or ($block->[2] eq 'PI')){

		   ## Add attribute using the qualified attribute name
		   push ( @{$rethash->{$transcript}->{'attributes'}}, {
		       'name'    => $prokOrfAttributeAttTypes->{$block->[2]},
		       'content' => $block->[3]
		   });

	       } elsif ($att_type eq 'VIR'){

		   push ( @{$rethash->{$transcript}->{'attributes'}}, 
			  { name => 'VIR_PMID', content => $block->[3] } );

	       }  else{
		   ## $block->[2] may be LP or OMP at this point
		   $lookup->{$transcript}->{$block->[2]}  = $block->[3];
	       }
	   }
	   else{
	       ## No value was in feat_score.score
	       next;
	   }
       }
   }
   
   foreach my $scoreType qw( regions coords ){
       
       my $ret = $prism->gene_orf_score_data($asmbl_id,
					     $database, 
					     $prokSchemaTypeToFeature->{$schemaType},
					     'GES',
					     $scoreType);

       
       foreach my $block ( @{$ret} ) {
	   
	   my $transcript = &get_uniquename($prism, 
					    $idatabase,
					    $asmbl_id,
					    $block->[1],
					    'polypeptide');
	   
	   $transcripthash->{$transcript} = '';
	   
	   my $data = $block->[3];
	   
	   if (defined($data)){
	       if ($data =~ /^\s*$/){
		   $data = '0';
	       }
	       ## $block->[2] may be coords or regions
	       $lookup->{$transcript}->{$block->[2]} =  $data;
	   }
       }
   }
   
  
   foreach my $transcript (keys %{$transcripthash} ) {

       foreach my $legacyAnnoAttType (keys %{$legacyAnnoAttTypes} ){ 

	   if ( exists $lookup->{$transcript}->{$legacyAnnoAttType} ){
	       
	       push ( @{$rethash->{$transcript}->{'attributes'}}, {
		   'name'    => $legacyAnnoAttTypes->{$legacyAnnoAttType},
		   'content' => $lookup->{$transcript}->{$legacyAnnoAttType}
	       });
	   }
       }

   }
   
   return ($rethash);
}

#-----------------------------------------------------------------
# createLipoMembraneProteinLookup()
#
#-----------------------------------------------------------------
sub createLipoMembraneProteinLookup {

   my ($prism, $asmbl_id, $database, $alt_database, $lipoMembraneProteinLookup) = @_;

   my $idatabase = $database;

   if (defined($alt_database)){
       $idatabase = $alt_database;
   }

   my $lipoMembraneProteins = $prism->lipoMembraneProteins($asmbl_id, $database);

   if (!defined($lipoMembraneProteins)){
       $logger->logdie("lipoMembraneProteins was not defined");
   }

   my $invalidCtr=0;
   my $invalidList=[];
   my $ctr=0;

   foreach my $arrayRef ( @{$lipoMembraneProteins} ){
       
       if ((defined($arrayRef->[1])) && ($arrayRef->[1] !~ /^\s+$/)){
	   
	   $lipoMembraneProteinLookup->{$arrayRef->[0]} = $arrayRef->[1];
	   $ctr++;

       } else {

	   $invalidCtr++;
	   push(@{$invalidList}, $arrayRef->[0]);
       }
   }

   if ($invalidCtr > 0 ){
       $logger->warn("Excluded '$invalidCtr' lipo_membrane_protein values ".
		     "for the following ORFs: ". join(' ', @{$invalidList}));
   }
   
   print "Found '$ctr' good lipo_membrane_protein values\n";

}

#----------------------------------------------------------------------------------------
# create_ber_evidence_lookup()
#
#----------------------------------------------------------------------------------------
sub create_ber_evidence_lookup {

   my ($prism, $asmbl_id, $database, $prefix, $schemaType) = @_;
  
   my $v = {};

   #
   # The mapping of queried/retrieved data to BSML should be:
   # //Seq-pair-alignment/@refseq   = evidence.feat_name
   # //Seq-pair-alignment/@compseq  = evidence.accession
   # //Seq-pair-run/@runprob        = feat_score.score WHERE common..score_type.score_type = 'Pvalue'
   # //Seq-pair-run/@runscore       = feat_score.score WHERE common..score_type.score_type = 'score'
   # //Seq-pair-run/@refpos         = min(evidence.end5, evidence.end3) - 1 WHERE evidence.ev_type = 'BER'
   # //Seq-pair-run/@runlength      = max(evidence.end5, evidence.end3) - min(evidence.end5, evidence.end3) + 1 WHERE evidence.ev_type = 'BER'
   # //Seq-pair-run/@refcomplement  = 1 if (evidence.end5 < evidence.end3)
   # //Seq-pair-run/@refcomplement  = 0 if (evidence.end3 < evidence.end5)
   # //Seq-pair-run/@comppos        = evidence.m_lend
   # //Seq-pair-run/@comprunlength  = evidence.m_rend - evidence.m_lend
   # //Seq-pair-run/@compcomplement = 0
   # //Seq-pair-run/Attribute[@name='auto_annotate_toggle']/@content = 1 if evidence.ev_type = 'BER'

   #
   # //Sequence/@id = evidence.feat_name
   # //Sequence/@class = 'CDS'
   # //Sequence/molecule = 'dna'

   # //Sequence/@id = evidence.accession WHERE ev_type = 'BER'
   # //Sequence/@class = 'protein'
   # //Sequence/@molecule = 'aa'

   my $ber = 'BER';
   my $computeType = 'BER';
   
   foreach my $ev_type ( keys %{$computeEvTypeLookup->{$computeType}} ) {
       
       foreach my $score_type ( keys %{$berScoreTypeLookup} ) {

	   my $ret = $prism->ber_evidence_data($asmbl_id,
					       $database, 
					       $prokSchemaTypeToFeature->{$schemaType},
					       $ev_type,
					       $score_type);
	   
	   foreach my $block ( @{$ret} ){


	       $block->[1] = &cleanse_uniquename($block->[1]);

	       # 0 => asm_feature.asmbl_id
	       # 1 => evidence.feat_name
	       # 2 => evidence.accession
	       # 3 => feat_score.score
	       # 4 => evidence.end5
	       # 5 => evidence.end3
	       # 6 => evidence.m_lend
	       # 7 => evdience.m_rend
	       

	       $block->[2] = &clean_compseq($block->[2]);


	       my $key = $block->[1] . '_' . $block->[2] . '_' . $block->[4] . '_' . $block->[5] . '_' . $block->[6] . '_' . $block->[7];
	       
	       $block->[3] =~ s/\s+/ /g; # change newline to space

	       if ((defined($block->[3])) && ($block->[3] !~ /^\s+$/)){

		   if ( exists $berScoreTypeLookup->{$score_type} ) {
		       $v->{$asmbl_id}->{$ber}->{$block->[1]}->{$block->[2]}->{$key}->{$berScoreTypeLookup->{$score_type}} = $block->[3];
		   }
		   else{
		       $logger->logdie("Unexpected score_type '$score_type'");
		   }
	       }
	       else{
		   #
		   # Have encountered cases where there does not exist any feat_score.score in legacy annotation for the evidence.feat_name and evidence.accession tuple.
		   # In such cases, do nothing.  Do not insert runprob or runscore.  
		   # These BSML Seq-pair-run XML attributes are typed as CDATA #IMPLIED
		   #
	       }
	       
	       my ($refpos, $runlength, $refcomplement) = &compute_orientation($block->[4], $block->[5]); 
	       

	       $v->{$asmbl_id}->{$ber}->{$block->[1]}->{$block->[2]}->{$key}->{'refpos'}        = $refpos;
	       $v->{$asmbl_id}->{$ber}->{$block->[1]}->{$block->[2]}->{$key}->{'runlength'}     = $runlength;
	       $v->{$asmbl_id}->{$ber}->{$block->[1]}->{$block->[2]}->{$key}->{'refcomplement'} = $refcomplement;
	       
	       if ($block->[6] > 0 ){
		   $v->{$asmbl_id}->{$ber}->{$block->[1]}->{$block->[2]}->{$key}->{'comppos'}         = ( $block->[6] - 1 );
	       }
	       else{
		   #
		   # Have encountered cases where legacy annotation have evidence.m_lend value = 0
		   # In such cases, do not subtract 1.
		   #
		   $v->{$asmbl_id}->{$ber}->{$block->[1]}->{$block->[2]}->{$key}->{'comppos'}         = ( $block->[6] );
	       }

	       $v->{$asmbl_id}->{$ber}->{$block->[1]}->{$block->[2]}->{$key}->{'comprunlength'}   = ( $block->[7] - $block->[6] + 1);
	       $v->{$asmbl_id}->{$ber}->{$block->[1]}->{$block->[2]}->{$key}->{'compcomplement'}  = 0;
	       

	       $v->{$asmbl_id}->{$ber}->{$block->[1]}->{$block->[2]}->{$key}->{'date'} = $block->[8];
	       
	       if ($ev_type eq 'AUTO-BER'){
		   $v->{$asmbl_id}->{$ber}->{$block->[1]}->{$block->[2]}->{'auto_annotate_toggle'}  = 1 ;
	       }
	   }
       }
   }


   return $v;
}


#----------------------------------------------------------------------------------------
# create_hmm2_evidence_lookup()
#
#----------------------------------------------------------------------------------------
sub create_hmm2_evidence_lookup {


    my ($prism, $asmbl_id, $databse, $db_prefix, $schemaType) = @_;
    
    my $v = {};

    #
    # The mapping of queried/retrieved data to BSML should be:
    #
    # //Seq-pair-alignment/@refseq  = evidence.feat_name
    # //Seq-pair-alignment/@compseq = evidence.accession
    # //Seq-pair-run/@runprob       = feat_score.score WHERE common..score_type.score_type = 'score'
    # //Seq-pair-run/@runscore      = feat_score.score WHERE common..score_type.score_type = 'e-value'
    # //Seq-pair-run/@refpos        = evidence.rel_end5
    # //Seq-pair-run/@runlength     = evidence.rel_end3 - evidence.rel_end5 + 1
    # //Seq-pair-run/@refcomplement = 0
    # //Seq-pair-run/@comppos       = evidence.m_lend
    # //Seq-pair-run/@comprunlength = evidence.m_rend - evidence.m_lend
    # //Seq-pair-run/@compcomplement = 0

    #
    # //Sequence/@id = evidence.feat_name
    # //Sequence/@class = 'protein'
    # //Sequence/molecule = 'aa'

    # //Sequence/@id = evidence.accession WHERE ev_type = 'BER'
    # //Sequence/@class = 'protein'
    # //Sequence/@molecule = 'aa'

    
    my $computeType = 'HMM2';

    my $localScoreTypeLookup = $computeScoreTypeLookup->{$computeType};

    my $localEvTypeLookup = $computeEvTypeLookup->{$computeType};

    foreach my $evType ( keys %{$localEvTypeLookup} ){
	
	foreach my $scoreType ( keys %{$hmm2ScoreTypeLookup}){
		
	    my $ret = $prism->hmm_evidence_data($asmbl_id, 
						$database, 
						$prokSchemaTypeToFeature->{$schemaType},						    
						$evType,
						$scoreType);
		
	    foreach my $block ( @{$ret} ){

		$block->[1] = &cleanse_uniquename($block->[1]);


		# 0 => asm_feature.asmbl_id
		# 1 => evidence.feat_name
		# 2 => evidence.accession
		# 3 => feat_score.score
		# 4 => evidence.rel_end5
		# 5 => evidence.rel_end3
		# 6 => evidence.m_lend
		# 7 => evidence.m_rend
		
		my $compseq = $block->[2];
		if ($compseq =~ /^\d/){
		    # Found leading digit
		    $block->[2] = '_' . $block->[2];
		}

		my $key = $block->[1] . '_' . $block->[2] . '_' . $block->[4] . '_' . $block->[5] . '_' . $block->[6] . '_' . $block->[7];		       

		$block->[3] =~ s/\s+/ /g; # change newline to space

		if ( exists $localScoreTypeLookup->{$scoreType} ) {

		    $v->{$asmbl_id}->{$evType}->{$block->[1]}->{$block->[2]}->{$key}->{$hmm2ScoreTypeLookup->{$scoreType}} = $block->[3];
		    $v->{$asmbl_id}->{$evType}->{$block->[1]}->{$block->[2]}->{$key}->{'refpos'} = ( $block->[4] - 1 );
		    $v->{$asmbl_id}->{$evType}->{$block->[1]}->{$block->[2]}->{$key}->{'runlength'} = ( $block->[5] - $block->[4] + 1 );
		    $v->{$asmbl_id}->{$evType}->{$block->[1]}->{$block->[2]}->{$key}->{'refcomplement'} = 0;
		    $v->{$asmbl_id}->{$evType}->{$block->[1]}->{$block->[2]}->{$key}->{'comppos'} = ( $block->[6] - 1 );
		    $v->{$asmbl_id}->{$evType}->{$block->[1]}->{$block->[2]}->{$key}->{'comprunlength'} = ( $block->[7] - $block->[6] + 1 );
		    $v->{$asmbl_id}->{$evType}->{$block->[1]}->{$block->[2]}->{$key}->{'compcomplement'} = 0;
		    
		}
		else{
		    $logger->logdie("Unexpected score_type '$scoreType'");
		}
	    }
	}
    }



    return $v;
}# create_hmm2_evidence_lookup 


#----------------------------------------------------------------------------------------
# create_cog_evidence_lookup()
#
#----------------------------------------------------------------------------------------
sub create_cog_evidence_lookup {

   my ($prism, $asmbl_id, $database, $db_prefix, $schemaType) = @_;

   my $v = {};

   #
   # The mapping of queried/retrieved data to BSML should be:
   #
   # //Seq-pair-alignment/@refseq  = evidence.feat_name
   # //Seq-pair-alignment/@compseq = evidence.accession
   # //Seq-pair-run/@runprob       = feat_score.score WHERE common..score_type.score_type = 'score'
   # //Seq-pair-run/@runscore      = feat_score.score WHERE common..score_type.score_type = 'e-value'
   # //Seq-pair-run/@refpos        = evidence.rel_end5
   # //Seq-pair-run/@runlength     = evidence.rel_end3 - evidence.rel_end5 + 1
   # //Seq-pair-run/@refcomplement = 0
   # //Seq-pair-run/@comppos       = evidence.m_lend
   # //Seq-pair-run/@comprunlength = evidence.m_rend - evidence.m_lend
   # //Seq-pair-run/@compcomplement = 0

   #
   # //Sequence/@id = evidence.feat_name
   # //Sequence/@class = 'protein'
   # //Sequence/molecule = 'aa'

   # //Sequence/@id = evidence.accession WHERE ev_type = 'BER'
   # //Sequence/@class = 'protein'
   # //Sequence/@molecule = 'aa'

   my $computeType = 'COG';
   
   my $localEvTypeLookup = $computeEvTypeLookup->{$computeType};

   foreach my $evType ( keys %{$localEvTypeLookup} ) {
       
       my $ret = $prism->cog_evidence_data($asmbl_id, 
					       $database, 
					       $prokSchemaTypeToFeature->{$schemaType},
					       $evType);
	   
       foreach my $block ( @{$ret} ){
	   
	   $block->[1] = &cleanse_uniquename($block->[1]);
	   
	   # 0 => asm_feature.asmbl_id
	   # 1 => evidence.feat_name
	   # 2 => evidence.accession
	   # 3 => evidence.rel_end5
	   # 4 => evidence.rel_end3
	   # 5 => evidence.m_lend
	   # 6 => evidence.m_rend
	   
	   my $compseq = $block->[2];
	   if ($compseq =~ /^\d/){
	       # Found leading digit
	       $block->[2] = '_' . $block->[2];
	   }
	   
	   my $key = $block->[1] . '_' . $block->[2] . '_' . $block->[3] . '_' . $block->[4] . '_' . $block->[5] . '_' . $block->[6];
	   
	   
	   my $tmpLookup = { 'refpos' => ( $block->[3] - 1 ),
			     'runlength' => ( $block->[4] - $block->[3] + 1 ),
			     'refcomplement' => 0,
			     'comppos' => ( $block->[5] - 1 ),
			     'comprunlength' => ( $block->[6] - $block->[5] + 1 ),
			     'compcomplement' => 0 };
	   
	   $v->{$asmbl_id}->{$evType}->{$block->[1]}->{$block->[2]}->{$key} = $tmpLookup;
	   
       }
   }
   
   return $v;
}# create_cog_evidence_lookup 


#----------------------------------------------------------------------------------------
# create_prosite_evidence_lookup()
#
#----------------------------------------------------------------------------------------
sub create_prosite_evidence_lookup {


   my ($prism, $asmbl_id, $database, $db_prefix, $schemaType) = @_;

   my $v = {};

   #
   # The mapping of queried/retrieved data to BSML should be:
   #
   # //Seq-pair-alignment/@refseq  = evidence.feat_name
   # //Seq-pair-alignment/@compseq = evidence.accession
   # //Seq-pair-run/@runprob       = feat_score.score WHERE common..score_type.score_type = 'score'
   # //Seq-pair-run/@runscore      = feat_score.score WHERE common..score_type.score_type = 'e-value'
   # //Seq-pair-run/@refpos        = evidence.rel_end5
   # //Seq-pair-run/@runlength     = evidence.rel_end3 - evidence.rel_end5 + 1
   # //Seq-pair-run/@refcomplement = 0
   # //Seq-pair-run/@comppos       = evidence.m_lend
   # //Seq-pair-run/@comprunlength = evidence.m_rend - evidence.m_lend
   # //Seq-pair-run/@compcomplement = 0

   #
   # //Sequence/@id = evidence.feat_name
   # //Sequence/@class = 'protein'
   # //Sequence/molecule = 'aa'

   # //Sequence/@id = evidence.accession WHERE ev_type = 'BER'
   # //Sequence/@class = 'protein'
   # //Sequence/@molecule = 'aa'

   my $computeType = 'PROSITE';

   my $localEvTypeLookup = $computeEvTypeLookup->{$computeType};

   my $localScoreTypeLookup = $computeScoreTypeLookup->{$computeType};

   my $proExcludeCtr=0;

   foreach my $evType ( keys %{$localEvTypeLookup} ){
       
       foreach my $scoreType ( keys %{$localScoreTypeLookup} ) {
	       
	   my $ret = $prism->prosite_evidence_data($asmbl_id, 
						   $database,
						   $prokSchemaTypeToFeature->{$schemaType},
						   $evType,
						   $scoreType);
	   
	   foreach my $block ( @{$ret} ){
	       
	       $block->[1] = &cleanse_uniquename($block->[1]);
	       
	       # 0 => asm_feature.asmbl_id
	       # 1 => evidence.feat_name
	       # 2 => evidence.accession
	       # 3 => feat_score.score
	       # 4 => evidence.rel_end5
	       # 5 => evidence.rel_end3
	       # 6 => evidence.m_lend
	       # 7 => evidence.m_rend
	       # 8 => evidence.hit

	       if (($block->[6] < 0) || ($block->[7] < 0 )){
		   ## As per Scott Durkin,  a negative value in the
		   ## match coordinates indicates a search was conducted
		   ## but yielded no hit.  While we can accurately represent
		   ## such a scenario in BSML and chado, we will merely 
		   ## exclude such records at this time. 
		   $logger->warn("feat_name '$block->[1]' and accession '$block->[2]' ".
				 "had no hit as indicated by negative value in the ".
				 "match coordinate m_lend '$block->[6]' m_rend ".
				 "'$block->[7]'");
		   $proExcludeCtr++;
		   next;
	       }

	       ## The legacy annotation databases may contain control characters.  These
	       ## control characters should not propagate into the .bsml gene model
	       ## documents (bug 2160).

	       $block->[2] = &remove_cntrl_chars($block->[2]);

	       my $compseq = $block->[2];
	       if ($compseq =~ /^\d/){
		   # Found leading digit
		   $block->[2] = '_' . $block->[2];
	       }

	       my $tmpLookup = { $localScoreTypeLookup->{$scoreType} => $block->[3],
				 'refpos' => ( $block->[4] - 1 ),
				 'runlength' => ( $block->[5] - $block->[4] + 1 ),
				 'refcomplement' => 0,
				 'comppos' => ( $block->[6] - 1 ),
				 'comprunlength' => ( $block->[7] - $block->[6] + 1 ),
				 'compcomplement' => 0,
				 'runprob' => 0,
				 'runscore' => 0 };

	       my $key = $block->[1] . '_' . $block->[2] . '_' . $block->[4] . '_' . $block->[5] . '_' . $block->[6] . '_' . $block->[7];

	       $v->{$asmbl_id}->{$evType}->{$block->[1]}->{$block->[2]}->{$key} = $tmpLookup;

	   }
       }
   }


   print "Excluded '$proExcludeCtr' prosite evidence records\n";
   return $v;
}# create_prosite_evidence_lookup 


#--------------------------------------------------------
# compute_orientation()
#
#--------------------------------------------------------
sub compute_orientation {

    my ($end5, $end3) = @_;

    my ($refpos, $runlength, $refcomplement);


    if ($end5 > $end3){
	
	$refpos = $end3 - 1;
	$runlength = $end5 - $end3 + 1;
	$refcomplement = 0;
    }
    elsif ($end3 > $end5 ){
	
	$refpos = $end5 - 1;
	$runlength = $end3 - $end5 + 1;
	$refcomplement = 1;
	
    }
    elsif ( $end3 == $end5 ){

	if ($end5 != 0){
	    $refpos = $end5 - 1;
	    $runlength = $end3 - $end5 + 1;
	    $refcomplement = 1;
	}
	else{
	    $refpos = $end5;
	    $runlength = $end3 - $end5 + 1;
	    $refcomplement = 1;
	}
    }
    else{
	$logger->logdie("end5 '$end5' end3 '$end3'");
    }


    return ($refpos, $runlength, $refcomplement);

}


#-------------------------------------------------------------------------------------
# retrieve_organism_data()
#
#-------------------------------------------------------------------------------------
sub retrieve_organism_data {


    my %args = @_;
    my $asmbl_list = $args{'asmbl_list'};
    my $prism      = $args{'prism'};
    my $database   = $args{'database'};
    my $alt_database = $args{'alt_database'};
    my $schemaType = $args{'schema_type'};

    #
    # Retrieve the organism data via the Prism API method
    # in (shared/Prism.pm)
    #
    my $orgdata = $prism->organism_data($database, $schemaType);

    my $id_database = $database;

    if (defined($alt_database)){
	$id_database = $alt_database;
    }

    ## Set the genetic code based on the schema type if value was
    ## not extracted from the legacy annotation database.
    if ( ! exists $orgdata->{'genetic_code'} ) {
	$orgdata->{'genetic_code'} = $schemaTypeToGeneticCodeLookup->{$schemaType};
    }
    else {
	if ($orgdata->{'genetic_code'} !~ /^\d+$/){
	    if (($orgdata->{'genetic_code'} eq 'microbial') || 
		($orgdata->{'genetic_code'} eq 'nt-microbial') || 
		($orgdata->{'genetic_code'} eq 'BRC-microbial')){
		$orgdata->{'genetic_code'} = 11;
	    }
	    else {
		$logger->logdie("Unexpected genetic_code value '$orgdata->{'genetic_code'}'");
	    }
	}
    }

    if (! exists $orgdata->{'translation_table'} ) {
	$orgdata->{'translation_table'} = $orgdata->{'genetic_code'};
    }


    ## Set the mitochondrial genetic code
    $orgdata->{'mt_genetic_code'} = 4;

    #
    # Return the constructed data hash
    #
    return $orgdata;


}

#--------------------------------------------------------
# verify_and_set_outdir()
#
#--------------------------------------------------------
sub verify_and_set_outdir {

    my ( $outdir, $bsmlDocName ) = @_;

    if (!defined($outdir)){
	
	if ($logger->is_debug()){
	    $logger->debug("outdir was not defined");
	}

	if (defined($bsmlDocName)){
	    ## derive the outdir from the BSML document name
	    $outdir = dirname($bsmlDocName);
	    if ($logger->is_debug()){
		$logger->debug("outdir was set to dirname of '$bsmlDocName'");
	    }
	}
	elsif (defined($ENV{'OUTPUT_DIR'})){
	    ## set the outdir to the env var OUTPUT_DIR
	    $outdir = $ENV{'OUTPUT_DIR'};
	    if ($logger->is_debug()){
		$logger->debug("outdir was set to the environmental variable OUTPUT_DIR '$ENV{'OUTPUT_DIR'}'");
	    }
	}
	else{
	    ## set the outdir to the current working directory
	    $outdir = ".";
	    if ($logger->is_debug()){
		$logger->debug("outdir was set to the current working directory");
	    }
	}
    }

    ## strip trailing forward slashes
    $outdir =~ s/\/+$//;

    $outdir = $outdir . '/';

    if (!-e $outdir){
	$logger->logdie("directory '$outdir' does not exist");
    }
    if (!-d $outdir){
	$logger->logdie("'$outdir' is not a directory");
    }
    if (!-w $outdir){
	$logger->fatal("directory '$outdir' does not have write permissions");
    }

    #
    # store the outdir in the environment variable
    #
    $ENV{OUTPUT_DIR} = $outdir;
    
    return $outdir;

}


#----------------------------------------------------------------
# retrieve_prism_object()
#
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database) = @_;

    my $prism = new Prism(
			  user              => $username,
			  password          => $password,
			  db                => $database
			  );
    
    $logger->logdie("prism was not defined") if (!defined($prism));
    
    return $prism;


}#end sub retrieve_prism_object()


#-----------------------------------------------------------------
# print_usage()
#
#-----------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 [-B] -D database  [-F fastadir] -P password -U username [-M mode] -a asmbl_id [--alt_database] [-d debug_level] [--exclude_genefinders] [-h] [--input_id_mapping_directories] [--input_id_mapping_files] [--id_repository] [--idgen_identifier_version] [--include_genefinders] [-l log4perl] [-m] [--model_list_file] [--no_die_null_sequences] [--no_id_generator] [--no-misc-features] [--no-repeat-features] [--no-transposon-features] [-o outdir]  [--output_id_mapping_file] [-q sequence_type] --schema_type [--sourcename] [--tu_list_file] [--alt_species]\n".
    " -B|--backup             = Optional - to backup output .bsml and .fsa files\n".
    " -D|--database           = Source database name\n".
    " -P|--password           = login password for database\n".
    " -U|--username           = login username for database\n".
    " -M|--mode               = 1=gene model 2=gene model and computational evidence 3=computational evidence\n".
    " -a|--asmbl_id           = assembly identifier (assembly.asmbl_id)\n".
    " -a|--alt_database       = Optional - override default legacy annotation database name when creating unique identifiers\n".
    " -a|--alt_species        = Optional - override default species value\n".
    " -d|--debug_level        = Optional - Coati::Logger log4perl logging level (Default is WARN)\n".
    " -F|--fastadir           = Optional - output fasta repository (Default is current working directory)\n".
    " -h|--help               = This help message\n".
    " -l|--log4perl           = Optional - Log4perl output filename (Default is /tmp/legacy2bsml.pl.database_\$database.asmbl_id_\$asmbl_id.log)\n".
    " -m|--man                = Display the pod2usage pages for this script\n".
    " --model_list_file       = Optional - User qualified model identifer list (Default is to migrate all models returned by the standard Prism API query)\n".
    " -o|--outdir             = Optional - Output directory for all .bsml files (Default is current working directory)\n".
    " -q|--sequence_type      = Optional - Secondary sequence type of main <Sequence> e.g. SO:contig\n".
    " --schema_type           = TIGR legacy annotation database schema type e.g. euk, prok, or ntprok\n".
    " --sourcename            = Optional - User can specify value to be stored in all Analysis sourcename Attributes (Default is current working directory)\n".
    " --exclude_genefinders   = Optional - Comma-separated list of gene finder datatypes to be excluded from migration (Default is to migrate all gene finder datatypes)\n".
    " --include_genefinders   = Optional - Comma-separated list of gene finder datatypes to be included in the migration (Default is to migrate all gene finder datatypes)\n".
    " --no-misc-features      = Optional - User can specify that no miscellaneous feature types should be extracted from the legacy annotation database (Default is to migrate all miscellaneous feature types)\n".
    " --no-repeat-features     = Optional - User can specify that no repeat feature types should be extracted from the legacy annotation database (Default is to migrate all repeat feature types)\n".
    " --no-transposon-features = Optional - User can specify that no transposon feature types should be extracted from the legacy annotation database (Default is to migrate all transposon feature types)\n".
    " --tu_list_file           = Optional - User qualified TU identifer list (Default is to migrate all TUs returned by the standard Prism API query)\n".
    " --no_id_generator        = Optional - Do not call IdGenerator services\n".
    " --id_repository          = Optional - IdGenerator compliant directory (must contain valid_id_repository file).  Default is current working directory\n".
    " --input_id_mapping_directories  = Optional - comma-separated list of directories containing ID mapping files with file extension .idmap.  Default directory to be scanned is the output directory.\n".
    " --input_id_mapping_files    = Optional - comma-separated list of ID mapping files whose ID mappings should be loaded into the ID mapping lookup\n".
    " --output_id_mapping_file    = Optional - ID mapping file to which all new ID mappings will be written.  Default is the bsml_doc_name.legacy2bsml.idmap\n".
    " --idgen_identifier_version  = Optional - value to be appended to the sequence and feature identifier values (default is 0)\n".
    " --no_die_null_sequences     = Optional - Continue execution even if sequences are null\n";
    exit(1);
}

#-------------------------------------------------------------------------------------------------------------------------------------------------------------
# create_genome_component()
#
# Sample <Genomes> component:
# <Genomes>
#   <Genome>
#      <Cross-reference id="1" database="TIGR_euk:tba1" identifier="t_brucei" identifier-type="current"></Cross-reference>
#      <Organism species="brucei" genus="Trypanosoma"></Organism>
#   </Genome>
# </Genomes>
#
#
#-------------------------------------------------------------------------------------------------------------------------------------------------------------
sub create_genome_component {    
    
    my ($doc, $orgdata, $schemaType, $alt_species) = @_;

    my $genome_elem = $doc->createAndAddGenome();

    if (!defined($genome_elem)){
	$logger->logdie("Could not create <Genome> element object reference for organism '$orgdata->{'name'}'");
    }


    my ($genus, $species, @straint) = split(/\s+/,$orgdata->{'name'});

    my $original_species = $species;

    if (defined($alt_species)){
	$species = $alt_species;
    }

    foreach my $st (@straint){
	$species = $species . ' ' . $st if (defined($st));
    }

    my $identifier = lc(substr($genus,0,1)) . '_' . lc($species);

    my $formatted_legacy_database_name  = 'TIGR_' . ucfirst($database);

    $orgdata->{'prefix'} = $formatted_legacy_database_name;

    my $xref_elem = $doc->createAndAddCrossReference(
						     'parent'          => $genome_elem,
						     'id'              => $doc->{'xrefctr'}++,
						     'database'        => $formatted_legacy_database_name,
						     'identifier'      => $identifier,
						     'identifier-type' => 'legacy_annotation_database'
						     );
    if (!defined($xref_elem)){
	$logger->logdie("Could not create <Cross-reference> element object reference");
    }
    else {
	my $dbsource_attribute_elem = $doc->createAndAddBsmlAttribute( $xref_elem,
								       'source_database',
								       $database );
	
	if (!defined($dbsource_attribute_elem)){
	    $logger->logdie("Could not create <Attribute> for name 'database_source' content '$database'");
	}
	
	my $schema_attribute_elem = $doc->createAndAddBsmlAttribute( $xref_elem,
								     'schema_type',
								     $schemaType );
	
	if (!defined($schema_attribute_elem)){
	    $logger->logdie("Could not create <Attribute> for name 'schema_type' content '$schemaType'");
	}
    }


    if (( exists $orgdata->{'taxon_id'}) && (defined($orgdata->{'taxon_id'}))){


	my $xref_elem = $doc->createAndAddCrossReference(
							 'parent'          => $genome_elem,
							 'id'              => $doc->{'xrefctr'}++,
							 'database'        => 'taxon',
							 'identifier'      => $orgdata->{'taxon_id'},
							 'identifier-type' => 'current'
							 );

	if (!defined($xref_elem)){
	    $logger->logdie("Could not create <Cross-reference> element object reference");
	}
    }





    my $organism_elem = $doc->createAndAddOrganism( 
						    'genome'  => $genome_elem,
						    'genus'   => $genus,  
						    'species' => $species,
						    );
    if (!defined($organism_elem)){
	$logger->logdie("Could not create <Organism> element object reference") if (!defined($organism_elem));
    }
    else{
	
	&store_organism_attribute($doc, $organism_elem, $orgdata, $original_species, $alt_species);
    }

    ## The <Sequence> will now be explicitly linked with the <Genome> (bug 2051)
    if (( exists $genome_elem->{'attr'}->{'id'} ) && ( defined ( $genome_elem->{'attr'}->{'id'} ) )  ){
	return $genome_elem->{'attr'}->{'id'};
    }
    else {
	$logger->logdie("Genome id was not defined!");
    }
}


#-------------------------------------------------------------------------------------------------------------------------------------------------------------
# create_assembly_sequence_component()
#
#
# Create <Sequence> object for the assembly
#
#
#
#  <Sequence class = "assembly" length="20743" molecule="dna" id="tba1_279_assembly">
#      <Seq-data-import format="fasta" id="tba1_279" source="/usr/local/annotation/TRYP/FASTA_repository/tryp.fsa"></Seq-data-import>
#          <Cross-reference id="2" database="TIGR_euk:tba1" identifier="asmbl_id:279" identifier-type="current"></Cross-reference>
#              <Feature-tables>
#
#
#-------------------------------------------------------------------------------------------------------------------------------------------------------------
sub create_assembly_sequence_component {

    my %param = @_;
    my $asmbl_id         = $param{'asmbl_id'};
    my $asmbl_uniquename = $param{'uniquename'};
    my $asmlen           = $param{'length'};
    my $topology         = $param{'topology'};
    my $doc              = $param{'doc'};
    my $fastadir         = $param{'fastadir'};
    my $database         = $param{'database'};
    my $prefix           = $param{'prefix'};
    my $molecule_name    = $param{'molecule_name'};
    my $molecule_type    = $param{'molecule_type'};
    my $genome_id        = $param{'genome_id'};
    my $seqtype          = $param{'seqtype'};
    my $ontology         = $param{'ontology'};
    my $schemaType       = $param{'schema_type'};


    my $class = 'assembly';

    my $assembly_sequence_elem = $doc->createAndAddExtendedSequenceN(
								     'id'       => $asmbl_uniquename, 
								     'title'    => undef,
								     'length'   => $asmlen,
								     'molecule' => 'dna', 
								     'locus'    => undef,
								     'dbsource' => undef,
								     'icAcckey' => undef,
								     'topology' => $topology,
								     'strand'   => undef,
								     'class'    => $class
								     );
    
    $logger->logdie("Could not create a <Sequence> element object reference for assembly '$asmbl_uniquename'") if (!defined($assembly_sequence_elem));    


    ## The <Sequence> will now be explicitly linked with the <Genome> (bug 2051)
    my $link_elem = $doc->createAndAddLink(
					   $assembly_sequence_elem,
					   'genome',        # rel
					   "#$genome_id"    # href
					   );
    
    if (!defined($link_elem)){
	$logger->logdie("Could not create a 'genome' <Link> element object reference for assembly sequence '$asmbl_uniquename' genome_id '$genome_id'");
    }
    


    if (defined($molecule_type)){
	$molecule_type = lc($molecule_type);

	my $attribute_elem = $doc->createAndAddBsmlAttribute(
							     $assembly_sequence_elem,
							     'molecule_type',
							     "$molecule_type"
							     );
	
	$logger->logdie("Could not create <Attribute> for the '$asmbl_uniquename' assembly's molecule_type '$molecule_type'") if (!defined($attribute_elem));
    }



    my $secondary_so_type;

    if (defined($molecule_name)){

	$molecule_name = lc($molecule_name);


	$secondary_so_type = &assign_secondary_type($assembly_sequence_elem,
						    $molecule_name);

	## The organism's name is appended to the molecule name (bug 2258).
	my $molecule_name_organism = $molecule_name . ' ' . $param{'organism_name'};

	if (($schema_type eq 'euk') && (defined($gopherFile)) && (defined($gopherReader))){

	    $molecule_name_organism = &createEukMoleculeName($molecule_name, 
							     $param{'organism_name'});
	}


	my $attribute_elem = $doc->createAndAddBsmlAttribute(
							     $assembly_sequence_elem,
							     'molecule_name',
							     "$molecule_name_organism"
							     );
	
	if (!defined($attribute_elem)){
	    $logger->logdie("Could not create <Attribute> for the ".
			    "'$asmbl_uniquename' assembly's ".
			    "molecule_name '$molecule_name_organism'");
	}
    }
    elsif ($schemaType eq 'euk'){
	
	$logger->info("Since dealing with euk, storing/setting molecule_name = 'assembly'");
	
	&store_attribute_list($assembly_sequence_elem,
			      'SO',
			      'assembly');

    }
    else{
	$logger->logdie("molecule_name was not defined for asmbl_id '$asmbl_id'");
    }
    
    ## The sequence type may be specified on the command-line.  This information will
    ## be stored in an Attribute-list element and then in chado.feature_cvterm (bug 2086).
    if ((defined($seqtype)) && (defined($ontology))){
	
	if (($ontology eq 'SO') && ($secondary_so_type eq $seqtype)){
	    #
	    # Do not insert the secondary type that was specified on the
	    # command-line into the BSML since matches the information
	    # retrieved from asmbl_data.name
	    #
	}
	else {
	    #
	    # The secondary type info specified on the command-line
	    # will be stored in the BSML.
	    #
	    &store_attribute_list($assembly_sequence_elem,
				  $ontology,
				  $seqtype);
	}
    }	    

    #
    # Create a <Seq-data-import> object
    #
    my $source = $fastadir . '/' . $database . '_'. $asmbl_id .  '_assembly.fsa';

    my $seq_data_import_elem = $doc->createAndAddSeqDataImport(
							       $assembly_sequence_elem,   # Sequence element object reference
							       'fasta',                   # format
							       $source,                   # source
							       undef,                     # id
							       $asmbl_uniquename          # identifier
							       );
    
    $logger->logdie("Could not create <Seq-data-import> element object reference for assembly '$asmbl_uniquename'") if (!defined($seq_data_import_elem));




    #
    # Create <Cross-reference> object
    #
    my $xref_elem = $doc->createAndAddCrossReference(
						     'parent'          => $assembly_sequence_elem,
						     'id'              => $doc->{'xrefctr'}++,
						     'database'        => $prefix,
						     'identifier'      => $asmbl_id,
						     'identifier-type' => 'current'
						     );

    $logger->logdie("Could not create <Cross-reference> element object reference for assembly '$asmbl_uniquename'") if (!defined($xref_elem));

    ## All clone_info columns' values should be stored as <Attribute> objects under the assembly's <Sequence> object
    &writeCloneInfoAttributesToBsml($param{'lookup'}, $doc, $assembly_sequence_elem, $asmbl_uniquename);

    foreach my $cloneInfoAnnotationType ( keys %{$cloneInfoAnnotationTypes} ) {

	if ((exists $param{$cloneInfoAnnotationType}) && 
	    (defined($param{$cloneInfoAnnotationType})) &&
	    ($param{$cloneInfoAnnotationType} == 1)) {
	    
	    &store_attribute_list( $assembly_sequence_elem,
				   'ANNFLG',
				   $cloneInfoAnnotationTypes->{$cloneInfoAnnotationType});
	}
    }


    #---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    # comment: Store Cross-reference information when available relating the following clone_info fields:
    #          gb_acc
    #          seq_asmbl_id
    #          lib_id
    #          clone_id
    #
    if ((exists $param{'gb_acc'} ) &&
 	(defined($param{'gb_acc'}))){
	
	my $xref = $doc->createAndAddCrossReference( 'parent'     => $assembly_sequence_elem,
						     'id'         => $doc->{'xrefctr'}++,
						     'database'   => 'Genbank',
						     'identifier' => $param{'gb_acc'},
						     'identifier-type'    => 'current'
						     );
	
	$logger->logdie("Could not create <Cross-reference> element object reference for database 'genbank' identifier '$param{'gb_acc'}' version 'current'") if (!defined($xref));
    }
    

    if ((exists $param{'seq_db'}) && (defined($param{'seq_db'}))) {

	foreach my $cloneInfoDb (keys %{$cloneInfoDatabaseIdentifierLookup} ) {

	    if ((exists $param{$cloneInfoDb} ) && (defined($param{$cloneInfoDb}))) {

		my $xref = $doc->createAndAddCrossReference( 'parent'     => $assembly_sequence_elem,
							     'id'         => $doc->{'xrefctr'}++,
							     'database'   => $param{'seq_db'},
							     'identifier' => $param{$cloneInfoDb},
							     'identifier-type' => $cloneInfoDatabaseIdentifierLookup->{$cloneInfoDb}
							 );
		if (!defined($xref)){
		    $logger->logdie("Could not create <Cross-reference> element object ".
				    "reference for database '$param{'seq_db'}' identifier ".
				    "'$param{$cloneInfoDb}' identifier-type ".
				    "'$cloneInfoDatabaseIdentifierLookup->{$cloneInfoDb}'") 
		}
	    }
	}
    }

    return $assembly_sequence_elem;
}

sub createEukMoleculeName {

    my ($molecule_name, $orgName) = @_;
    
    if ($molecule_name =~ /^(\d{$GOPHER_ID_LENGTH})/){

	my $gopher_id = $1;

	my $accession = $gopherReader->getAccessionByGopherId($gopher_id);

	if (!defined($accession)){

	    $logger->warn("accession was not defined for gopher_id '$gopher_id'");

	    ## Go ahead with the molecule_name value instead.
	    $accession = $molecule_name;
	}

	## Append the genus species strain
	$accession .= ' ' . $orgName;

	return $accession;

    } else {

	$logger->logdie("Could not parse gopher_id/clone_id from the molecule_name ".
			"'$molecule_name'");
    }
}


#-------------------------------------------------------------------------------------------------------------------------------------------
# subfeatures to be stored as <Sequence> elements are:
# 1) polypeptide
# 2) CDS
# 3) tRNA
# 4) sRNA
# 5) rRNA
# 6) Terminator sequence
# 7) RBS sequence
#
#
#-------------------------------------------------------------------------------------------------------------------------------------------
sub store_sequence_elements {

    my %p = @_;


    my $database   = $p{'database'};
    my $prefix     = $p{'prefix'};
    my $fastadir   = $p{'fastadir'};
    my $doc        = $p{'doc'};
    my $sequence_subfeature_hash = $p{'sequence_subfeature_hash'};
    my $asmbl_id      = $p{'asmbl_id'};
    my $fastasequences       = $p{'fastasequences'};
    my $seq_data_import_hash =  $p{'seq_data_import_hash'};
    my $identifier_feature   =  $p{'identifier_feature'};
    my $identifier_seq_data  =  $p{'identifier_seq_data'};
    my $genome_id            =  $p{'genome_id'};
    my $polypeptide_sequence_element_lookup = $p{'polypeptide_sequence_element_lookup'};

    $logger->logdie("database was not defined") if (!defined($database));
    $logger->logdie("prefix was not defined") if (!defined($prefix));
    $logger->logdie("fastadir was not defined") if (!defined($fastadir));
    $logger->logdie("doc was not defined") if (!defined($doc));
    $logger->logdie("sequence_subfeature_hash was not defined") if (!defined($sequence_subfeature_hash));
    $logger->logdie("asmbl_id was not defined") if (!defined($asmbl_id));

    my $class = $sequence_subfeature_hash->{'feat_type'};

    my $seq_id = &get_uniquename($prism,
				 $database,
				 $asmbl_id,
				 $sequence_subfeature_hash->{'feat_name'},
				 $class);

    my $seqfeature_id = $seq_id;

    $seq_id .= '_seq';
    
    my $moleculeType;
    if ( exists $featTypeToMoleculeTypeLookup->{$sequence_subfeature_hash->{'feat_type'}} ) {
	$moleculeType = $featTypeToMoleculeTypeLookup->{$sequence_subfeature_hash->{'feat_type'}};
    }

    #
    # Create <Sequence> element object for the subfeature as a sequence
    #
    my $sequence_elem = $doc->createAndAddSequence(
						   $seq_id,                               # id
						   undef,                                 # title
						   $sequence_subfeature_hash->{'seqlen'}, # length
						   $moleculeType,                         # molecule
						   $class                                 # class
						   );

    if (!defined($sequence_elem)){
	$logger->logdie("Could not create <Sequence> for the sequence '$seq_id'");
    }  

    ## The <Sequence> will now be explicitly linked with the <Genome> (bug 2051)
    my $link_elem = $doc->createAndAddLink(
					   $sequence_elem,
					   'genome',        # rel
					   "#$genome_id"   # href
					   );
    
    if (!defined($link_elem)){
	$logger->logdie("Could not create a 'genome' <Link> element ".
			"object reference for sequence '$seq_id' ".
			"genome_id '$genome_id'");
    }


    my $feat_name = $sequence_subfeature_hash->{'feat_name'};

    ## The polypeptide identifiers should contain the modified model
    ## feat_name i.e. cba1_338_338.p00001_polypeptide and not
    ## cba1_338_338.m00001_polypeptide (bug 2043)
    if ( ( $class eq 'polypeptide' ) && ( $feat_name =~ /\d+\.m\d+/)){

	$feat_name =~ s/\.m/\.p/;
    }

    if ($class eq 'polypeptide'){

	$polypeptide_sequence_element_lookup->{$seqfeature_id} = $sequence_elem;
    }


    if ( exists $sequence_subfeature_hash->{'sequence'} ) {
	## Some sequence exists so let us create either a 
	## <Seq-data-Import> or <Seq-data> BSML element object.

	if (  exists $storeSequenceAsSeqData->{$class}){
	    ## Create some <Seq-data> BSML element object

	    my $seq_data = $doc->createAndAddSeqData($sequence_elem,
						     $sequence_subfeature_hash->{'sequence'});
	    
	    if (!defined($seq_data)){
		$logger->logdie("Could not create <Seq-data> element object");
	    }
	}
	else {
	    ## Create some <Seq-data-import> BSML element object

	    push ( @{$fastasequences->{$asmbl_id}->{$class}}, [$seqfeature_id,  $sequence_subfeature_hash->{'sequence'}]);
   

	    #
	    # Create <Seq-data-import> element object for the subfeature as a sequence
	    #
	    my $source = $fastadir .'/'. $database . '_' . $asmbl_id . '_' . $class .'.fsa';

	    
	    ## The legacy2bsml.pl script should ensure that 
	    ## //Feature/@id == //Seq-data-import/@identifier 
	    ## for all sequences/features (bug 2044)
	    $identifier_seq_data->{$seqfeature_id}++;
	    
	    my $seq_data_import_elem = $doc->createAndAddSeqDataImport(
								       $sequence_elem, # <Sequence> element object reference
								       'fasta',        # format
								       $source,        # source
								       undef,          # id
								       $seqfeature_id  # identifier
								       );
	    if (!defined($seq_data_import_elem)){
		$logger->logdie("seq_data_import_elem was not defined for sequence '$seq_id'");
	    }

	    ## Store the <Seq-data-import> element object reference in the lookup
	    $seq_data_import_hash->{$seq_id} = $seq_data_import_elem;
	}
    }
}




#-----------------------------------------------------------------------------------------
#
# Process each assembly's Gene Model subfeatures:
# 1) gene
# 2) transcript
# 3) CDS
# 4) polypeptide
# 5) exon
#
#-----------------------------------------------------------------------------------------
sub store_prok_gene_model_subfeatures {

    my %param = @_;
    my $orfhash            = $param{'orfhash'};
    my $asmbl_id           = $param{'asmbl_id'};
    my $feature_table_elem = $param{'feature_table_elem'};
    my $doc                = $param{'doc'};
    my $prefix             = $param{'prefix'};
    my $database           = $param{'database'};
    my $assembly_sequence_elem = $param{'assembly_sequence_elem'};
    my $accession_hash     = $param{'accession_lookup'};
    my $gene_group_lookup  = $param{'gene_group_lookup'};
    my $transcript_feature_hash = $param{'transcript_feature_hash'};
    my $polypeptide_feat_name_to_locus = $param{'polypeptide_feat_name_to_locus'};
    my $polypeptide_feature_hash       = $param{'polypeptide_feature_hash'};
    my $seq_data_import_hash       = $param{'seq_data_import_hash'};
    my $identifier_feature         = $param{'identifier_feature'};
    my $cds_feature_hash           = $param{'cds_feature_hash'};
    my $schemaType = $param{'schema_type'};
    my $polypeptide_sequence_element_lookup = $param{'polypeptide_sequence_element_lookup'};


    my $gene_feature_group_elem;


    foreach my $class ('gene', 'transcript', 'CDS', 'exon', 'polypeptide'){


	#
	# Whether locus or feat_name (prepared for us upstream), create uniquename
	#
	my $uniquename = &get_uniquename($prism,
					 $database,
					 $asmbl_id,
					 $orfhash->{'feat_name'},
					 $class);

	if (($class eq 'polypeptide') && (! exists $polypeptide_sequence_element_lookup->{$uniquename})){
	    $logger->fatal("polypeptide with uniquename '$uniquename' for asmbl_id '$asmbl_id' ".
			   "database '$database' feat_name '$orfhash->{'feat_name'}' will ".
			   "not be inserted into the BSML file");
	    ## The next statement was commented out on 2008-11-07
	    ## as per IGS-SOM request (Anu) need the polypeptide
	    ## stub <Feature> elements present.
# 	    next;
	}

	## The legacy2bsml.pl script should ensure that
	## //Feature/@id == //Seq-data-import/@identifier 
	## for all sequences/features (bug 2044).
	$identifier_feature->{$uniquename}++;

	## Uncomment the following section if you still
	## wish the default behavior to be to incorporate 
	## locus into the uniquename if the locus is defined.
	#
	# 	if (defined($orfhash->{'locus'})){
	# 	    $uniquename = $database . '_' .$asmbl_id . '_' . $orfhash->{'locus'} . '_' . $class;
	#   	}


	#
	# The <Feature-group> element will be based on the gene
	#
	if ($class eq 'gene'){

	    $gene_feature_group_elem = $doc->createAndAddFeatureGroup(
								      $assembly_sequence_elem,  # <Sequence> element object reference
								      undef,                    # id
								      "$uniquename"             # groupset
								      );  
	    
	    $logger->logdie("Could not create <Feature-group> element object reference for uniquename '$uniquename'") if (!defined($gene_feature_group_elem));


	    $gene_group_lookup->{$orfhash->{'feat_name'}} = $gene_feature_group_elem;
	}


	#
	# Prep the <Interval-loc> data
	#
	my $fmin       = $orfhash->{'end5'};
	my $fmax       = $orfhash->{'end3'};
	my $complement = $orfhash->{'complement'};


	#
	# Create <Feature> element object
	#
	my $feature_elem = $doc->createAndAddFeatureWithLoc(
							    $feature_table_elem,  # <Feature-table> element object reference
							    "$uniquename",        # id
							    undef,                # title
							    $class,               # class
							    undef,                # comment
							    undef,                # displayAuto
							    $fmin,                # start
							    $fmax,                # stop
							    $complement           # complement
							    );
	if (!defined($feature_elem)){
	    $logger->logdie("Could not create <Feature> element object reference for gene model subfeature '$uniquename'"); 
	}
	
	#
	# Store the <Feature> element object reference for transcripts and polypeptides
	#
	if ($class eq 'transcript'){

	    ## Store reference using the feat_name not the locus
	    $transcript_feature_hash->{$uniquename} = $feature_elem;


	}
	elsif ($class eq 'polypeptide') {

	    ## Store reference using the feat_name not the locus
	    $polypeptide_feat_name_to_locus->{$orfhash->{'feat_name'}} = $uniquename;

	    $polypeptide_feature_hash->{$uniquename} = $feature_elem;
	}
	elsif ($class eq 'CDS'){
	    
	    ## Store the <Feature> element object reference for CDS so
	    ## that we can later associate all model GC ORF_attributes 
	    ## to the CDS features (bug 2263).
	    
	    ## Store reference using the feat_name not the locus
	    $cds_feature_hash->{$uniquename} = $feature_elem;
	}


	if ( $schemaType eq 'ntprok') {
	    if (($class eq 'transcript') || ($class eq 'CDS')) { 
		## Support retrieval of both prok and ntprok data (bug 2156).
	    
		&store_attribute_list( $feature_elem,
				       'ANNFLG',
				       'External_annotation');
	    }
	}

	#
	# Create <Cross-reference> element object for the feat_name
	#
	my $xref_elem = $doc->createAndAddCrossReference(
							 'parent'          => $feature_elem,
							 'id'              => $doc->{'xrefctr'}++,
							 'database'        => $prefix,
							 'identifier'      => $orfhash->{'feat_name'},
							 'identifier-type' => 'feat_name'
							 );
	if (!defined($xref_elem)){
	    $logger->logdie("Could not create <Cross-reference> for the feat_name '$orfhash->{'feat_name'}' as a class of type '$class'");
	}								 
	
	
	
	foreach my $locustype ('locus', 'display_locus'){
	    
	    
	    if (defined($orfhash->{$locustype})){
		
		#
		# Create <Cross-reference> element object for the locus or display_locus or alt_locus
		#
		my $xref_elem = $doc->createAndAddCrossReference(
								 'parent'          => $feature_elem,
								 'id'              => $doc->{'xrefctr'}++,
								 'database'        => $prefix,
								 'identifier'      => $orfhash->{$locustype},
								 'identifier-type' => "$locustype"
								 );
		if (!defined($xref_elem)){
		    $logger->logdie("Could not create <Cross-reference> for the $locustype '$orfhash->{'feat_name'}' as a class of type '$class'");
		}								 
		
	    }
	}


	#
	# Store additional dbxref for genbank_pid, genbank_protein_id, swiss_prot and ecocyc
	#
	if ((exists $accession_hash->{$orfhash->{'feat_name'}}) && (defined($accession_hash->{$orfhash->{'feat_name'}}))){

	    
	    foreach my $key (sort keys %{$accession_hash->{$orfhash->{'feat_name'}}} ){
		
		my $val = $accession_hash->{$orfhash->{'feat_name'}}->{$key};
		
		#
		# Create <Cross-reference> element object
		#
		my $xref_elem = $doc->createAndAddCrossReference(
								 'parent'          => $feature_elem,
								 'id'              => $doc->{'xrefctr'}++,
								 'database'        => $key,
								 'identifier'      => $val
								 );
		if (!defined($xref_elem)){
		    $logger->logdie("Could not create <Cross-reference> for key '$key' val '$val'");
		}								 
	    }
	}


	##-----------------------------------------------------------------------------------------
	## The following section will link the Feature to its corresponding Sequence
	##
	##-----------------------------------------------------------------------------------------
	if (($class eq 'polypeptide') ||
	    ($class eq 'CDS') ||
	    ($class eq 'transcript')){
	    
	    #
	    # Create <Link> to link polypeptide or CDS <Feature> element to the polypeptide_seq or CDS_seq <Sequence> element
	    #
	    my $sequence_key = &get_uniquename($prism,
					       $database,
					       $asmbl_id,
					       $orfhash->{'feat_name'},
					       $class);
	    $sequence_key .= '_seq';
	    
	    if ((exists ($seq_data_import_hash->{$sequence_key})) and (defined($seq_data_import_hash->{$sequence_key}))){

 		my $link_elem = $doc->createAndAddLink( $feature_elem,
							'sequence',       # rel
							"#$sequence_key"  # href
							);
		
 		if (!defined($link_elem)){
 		    $logger->logdie("Could not create a 'sequence' <Link> element object reference for gene model subfeature '$uniquename' and sequence ref '$sequence_key'");
 		}
	    }
	    else{
		
		#
		# Note that it is acceptable for some ORFs to not have an associated polypeptide translation
		#
		if ($class eq 'CDS') {
		    $logger->fatal("seq_data_import_hash:". Dumper $seq_data_import_hash);
		    $logger->logdie("sequence '$sequence_key' does not exist in the seq_data_import_hash ".
				    "for database '$database' asmbl_id '$asmbl_id' feat_name ".
				    "'$orfhash->{'feat_name'}' class '$class'");
		}
	    }
	}

	
	#
	# Create <Feature-group-member> element object for this Gene Model subfeature
	#
	my $feature_group_member_elem = $doc->createAndAddFeatureGroupMember( $gene_feature_group_elem,  # <Feature-group> element object reference
									      $uniquename,          # featref
									      $class,               # feattype
									      undef,                # grouptype
									      undef,                # cdata
									      ); 
	if (!defined($feature_group_member_elem)){
	    $logger->logdie("Could not create <Feature-group-member> element object reference for gene model subfeature '$uniquename'");
	}
    }
}


#-----------------------------------------------------------------------------------------
#
# Process each assembly's Gene Model subfeatures:
# 1) gene
# 2) transcript
# 3) CDS
# 4) polypeptide
# 5) exon
#
#-----------------------------------------------------------------------------------------
sub store_euk_gene_model_subfeatures {

    my %param = @_;

    my $asmbl_id           = $param{'asmbl_id'};
    my $feature_table_elem = $param{'feature_table_elem'};
    my $doc                = $param{'doc'};
    my $prefix             = $param{'prefix'};
    my $database           = $param{'database'};
    my $assembly_sequence_elem     = $param{'assembly_sequence_elem'};
    my $accession_hash             = $param{'accession_lookup'};
    my $gene_group_lookup          = $param{'gene_group_lookup'};
    my $transcript_feature_hash    = $param{'transcript_feature_hash'};
    my $polypeptide_feat_name_to_locus = $param{'polypeptide_feat_name_to_locus'};
    my $seq_data_import_hash       = $param{'seq_data_import_hash'};
    my $identifier_feature         = $param{'identifier_feature'};
    my $outdir                     = $param{'outdir'};
    my $analysis_hash              = $param{'analysis_hash'};
    my $transcript_mapper          = $param{'transcript_mapper'};
    my $transcripts                = $param{'transcripts'};
    my $coding_regions             = $param{'coding_regions'};
    my $exons                      = $param{'exons'};
    my $gb_acc = $param{'gb_acc'};
    my $date_released = $param{'date_released'};
    my $lc_qualified_models = $param{'lc_qualified_models'};

    my $locuslookup = {};
    my $role_id_lookup = {};

    foreach my $tu_feat_name ( keys %{$transcripts} ) {

	## We are now going to feature-group the subfeatures by transcript instead of by gene.
	## This new strategy to accomodate multiple transcripts.
	my $genestored = 0;
	my $transcript_lookup = {};

	if ((exists $coding_regions->{$tu_feat_name}) && (defined($coding_regions->{$tu_feat_name}))){

	    foreach my $model ( @{$coding_regions->{$tu_feat_name}} ){

		## Keeping track of which models were finally propagated to the BSML file.
		$lc_qualified_models->{$model->{'feat_name'}}++;

		## Support for retrieving gene finder data (from phys_ev).  
		## If the model's ev_type is anything other than 'working',
		## then need to store such information in the BSML as a <Link>
		## to some analysis where analysis.program = ev_type (bug 2107).
		my $ev_type;
		if ((exists $model->{'ev_type'}) && (defined($model->{'ev_type'}))){
		    
		    $ev_type = $model->{'ev_type'};

		    if ($ev_type ne 'working'){
			$logger->logdie("ev_type was '$ev_type' however we are no longer processing gene finder data in this section.");
		    }
		}

		## The pub_locus and alt_locus need to be associated with all relevant 
		## gene model subfeatures (i.e. transcripts, genes, CDSs, exons, polypeptides)
		## bug (2085).
		my ($pub_locus, $alt_locus);

		if (( exists $transcripts->{$tu_feat_name}->{'pub_locus'}) && (defined($transcripts->{$tu_feat_name}->{'pub_locus'}))){
		    
		    $pub_locus = $transcripts->{$tu_feat_name}->{'pub_locus'};

		    if (( exists $model->{'pub_locus'}) && (defined($model->{'pub_locus'}))){
			
			my $model_pub_locus  = $model->{'pub_locus'};
			
			if ( $pub_locus ne $model_pub_locus ) {
			    
			    #
			    # pub_locus for the model was defined, however does not match the value assigned to the TU
			    #
			    $logger->error("TU '$tu_feat_name' pub_locus '$pub_locus' does not match model '$model->{'feat_name'}' pub_locus '$model_pub_locus'");
			}
		    }
		    else{
			#
			# Assign the TU's pub_locus to the model
			#
			$model->{'pub_locus'} = $pub_locus;
		    }
		}
		else {
		    &check_pub_locus($tu_feat_name,
				     $asmbl_id,
				     $gb_acc,
				     $date_released);
		}
		

		if (( exists $transcripts->{$tu_feat_name}->{'alt_locus'}) && (defined($transcripts->{$tu_feat_name}->{'alt_locus'}))){
		    
		    $alt_locus = $transcripts->{$tu_feat_name}->{'alt_locus'};
		    
		    if (( exists $model->{'alt_locus'}) && (defined($model->{'alt_locus'}))){
			
			my $model_alt_locus  = $model->{'alt_locus'};
			
			if ( $alt_locus ne $model_alt_locus ) {

			    #
			    # alt_locus for the model was defined, however does not match the value assigned to the TU
			    #
			    $logger->error("TU '$tu_feat_name' alt_locus '$alt_locus' does not match model '$model->{'feat_name'}' alt_locus '$model_alt_locus'");
			}
		    }
		    else{
			#
			# Assign the TU's alt_locus to the model
			#
			$model->{'alt_locus'} = $alt_locus;
		    }
		    
		}

		## Create the uniquename for the particular version of the transcript at this top level 
		## and propagate it down to the the other subfeatures (gene, CDS, polypeptide, exon)
		my $uniquename = &get_uniquename( $prism,
						  $database,
						  $asmbl_id,
						  $tu_feat_name,
						  'transcript');

		my $transcriptUniqString = $uniquename . '_iso_' . $transcript_lookup->{$uniquename}++;

		my $transcript_uniquename = &get_uniquename($prism,
							    $database, 
							    $asmbl_id,
							    $transcriptUniqString,
							    'transcript');
		

		## Lookup for storing the mappings of the new isoform transcript 
		## uniquename to the original transcript uniquename (bug 2081).
		$transcript_mapper->{$transcript_uniquename} = $uniquename;

		
		my ($transcript_feature_group_elem, $w) = &store_euk_subfeature( # store the transcript as a feature
										 'transcript_uniquename'   => $transcript_uniquename,
										 'data'                    => $transcripts->{$tu_feat_name},
										 'class'                   => 'transcript',
										 'assembly_seq'            => $assembly_sequence_elem,
										 'gene_group_lookup'       => $gene_group_lookup,
										 'asmbl_id'                => $asmbl_id,
										 'prefix'                  => $prefix,
										 'doc'                     => $doc,
										 'feature_table_elem'      => $feature_table_elem,
										 'transcript_feature_hash' => $transcript_feature_hash,
										 'polypeptide_feat_name_to_locus' => $polypeptide_feat_name_to_locus,
										 'accession_hash'             => $accession_hash,
										 'seq_data_import_hash'       => $seq_data_import_hash,
										 'identifier_feature'         => $identifier_feature,
										 'ev_type'                    => $ev_type,
										 'outdir'                     => $outdir,
										 'analysis_hash'              => $analysis_hash										 
										);	
		
		$logger->logdie("transcript_feature_group_elem was not defined for transcript '$transcript_uniquename'") if (!defined($transcript_feature_group_elem));
		

		## While multiple transcripts (and other subfeatures associated those transcripts) will be inserted
		## into the BSML gene model document in different feature-groupings, the same gene must be stored
		## in each one of these corresponding groupings.
		##
		## Note that the order of processed subfeatures has changed from gene, transcript, CDS, polypeptide, exons to
		## transcript, gene, CDS, polypeptide, exon in order to facilitate feature-grouping by transcript.
		($transcript_feature_group_elem, $genestored) = &store_euk_subfeature( # store the gene as a feature
										       'data'               => $transcripts->{$tu_feat_name},
										       'class'              => 'gene',
										       'assembly_seq'       => $assembly_sequence_elem,
										       'gene_group_lookup'  => $gene_group_lookup,
										       'asmbl_id'           => $asmbl_id,
										       'prefix'             => $prefix,
										       'doc'                => $doc,
										       'feature_table_elem' => $feature_table_elem,
										       'transcript_feature_group_elem' => $transcript_feature_group_elem,
										       'genestored'         => $genestored,
										       'transcript_uniquename'   => 'UNDEF',
										       'transcript_feature_hash' => $transcript_feature_hash,
										       'polypeptide_feat_name_to_locus' => $polypeptide_feat_name_to_locus,
										       'accession_hash'             => $accession_hash,
										       'seq_data_import_hash'       => $seq_data_import_hash,
										       'identifier_feature'         => $identifier_feature,
										       'ev_type'                    => $ev_type,
										       'outdir'                     => $outdir,
										       'analysis_hash'              => $analysis_hash								       
										      );
		
		
		&store_euk_subfeature( # store the CDS as a feature
				       'data'                    => $model,
				       'class'                   => 'CDS',
				       'assembly_seq'            => $assembly_sequence_elem,
				       'gene_group_lookup'       => $gene_group_lookup,
				       'asmbl_id'                => $asmbl_id,
				       'prefix'                  => $prefix,
				       'doc'                     => $doc,
				       'feature_table_elem'      => $feature_table_elem,
				       'transcript_feature_group_elem' => $transcript_feature_group_elem,
				       'transcript_uniquename'         => 'UNDEF',
				       'transcript_feature_hash'       => $transcript_feature_hash,
				       'polypeptide_feat_name_to_locus'    => $polypeptide_feat_name_to_locus,
				       'accession_hash'                => $accession_hash,
				       'seq_data_import_hash'          => $seq_data_import_hash,
				       'identifier_feature'            => $identifier_feature,
				       'ev_type'                       => $ev_type,
				       'outdir'                        => $outdir,
				       'analysis_hash'                 => $analysis_hash,
				       'cds_feature_hash'              => $param{'cds_feature_hash'}
				       );


		##---------------------------------------------------------------
		## Store the polypeptide as a subfeature
		##
		##---------------------------------------------------------------
		my $polypeptide_feat_name = $model->{'feat_name'};

		$polypeptide_feat_name =~ s/\.m/\.p/;

		&store_euk_subfeature( # store the polypeptide as a feature
				       'feat_name'               => $polypeptide_feat_name,
				       'data'                    => $model,
				       'class'                   => 'polypeptide',
				       'assembly_seq'            => $assembly_sequence_elem,
				       'gene_group_lookup'       => $gene_group_lookup,
				       'asmbl_id'                => $asmbl_id,
				       'prefix'                  => $prefix,
				       'doc'                     => $doc,
				       'feature_table_elem'      => $feature_table_elem,
				       'transcript_feature_group_elem' => $transcript_feature_group_elem,
				       'transcript_uniquename'      => 'UNDEF',
				       'transcript_feature_hash'    => $transcript_feature_hash,
				       'polypeptide_feat_name_to_locus' => $polypeptide_feat_name_to_locus,
				       'accession_hash'             => $accession_hash,
				       'seq_data_import_hash'       => $seq_data_import_hash,
				       'identifier_feature'         => $identifier_feature,
				       'ev_type'                    => $ev_type,
				       'outdir'                     => $outdir,
				       'analysis_hash'              => $analysis_hash,
				       'polypeptide_feature_hash'     => $param{'polypeptide_feature_hash'}
				       );


		
		if ((exists $exons->{$model->{'feat_name'}}) && (defined($exons->{$model->{'feat_name'}}))){

		    ## Here we sort the exons based on the 5' genomic coordinates.
		    ## Note that the end5, end3, complement values are resolved in Prism::exons()
		    ## and Prism::coordinates().
		    ## Prism::EukPrismDB::get_exons() submits exon retrieving query- includes
		    ## an ORDER BY f.end5 clause (bug 2253).

		    foreach my $exon (sort {$a->{'end5'} <=> $b->{'end5'}} @{$exons->{$model->{'feat_name'}}} ) {

			## The pub_locus and alt_locus need to be associated with all relevant 
			## gene model subfeatures (i.e. transcripts, genes, CDSs, exons, polypeptides)
			## (bug 2085).
			if (( exists $exon->{'pub_locus'}) && (defined($exon->{'pub_locus'}))){
				
			    my $exon_pub_locus  = $exon->{'pub_locus'};
				
			    if ( $pub_locus ne $exon_pub_locus ) {
				    
				#
				# pub_locus for the exon was defined, however does not match the value assigned to the TU
				#
				$logger->error("TU '$tu_feat_name' pub_locus '$pub_locus' does not match exon '$exon->{'feat_name'}' pub_locus '$exon_pub_locus'");
			    }
			}
			else{
			    #
			    # Assign the TU's pub_locus to the model
			    #
			    $exon->{'pub_locus'} = $pub_locus;
			}
			
			
			    
			if (( exists $exon->{'alt_locus'}) && (defined($exon->{'alt_locus'}))){
			    
			    my $exon_alt_locus  = $exon->{'alt_locus'};
			    
			    if ( $alt_locus ne $exon_alt_locus ) {

				#
				# alt_locus for the exon was defined, however does not match the value assigned to the TU
				#
				$logger->error("TU '$tu_feat_name' alt_locus '$alt_locus' does not match exon '$exon->{'feat_name'}' alt_locus '$exon_alt_locus'");
			    }
			}
			else{
			    #
			    # Assign the TU's alt_locus to the exon
			    #
			    $exon->{'alt_locus'} = $alt_locus;
			}



			
			
			##---------------------------------------------------------------------
			## Store exon as a subfeature
			##
			##---------------------------------------------------------------------
			&store_euk_subfeature( 'data'                    => $exon,
					       'class'                   => 'exon',
					       'assembly_seq'            => $assembly_sequence_elem,
					       'gene_group_lookup'       => $gene_group_lookup,
					       'asmbl_id'                => $asmbl_id,
					       'prefix'                  => $prefix,
					       'doc'                     => $doc,
					       'feature_table_elem'      => $feature_table_elem,
					       'transcript_feature_group_elem' => $transcript_feature_group_elem,
					       'transcript_uniquename'      => 'UNDEF',				       
					       'transcript_feature_hash'    => $transcript_feature_hash,
					       'polypeptide_feat_name_to_locus' => $polypeptide_feat_name_to_locus,
					       'accession_hash'             => $accession_hash,
					       'seq_data_import_hash'       => $seq_data_import_hash,
					       'identifier_feature'         => $identifier_feature,
					       'ev_type'                    => $ev_type,
					       'outdir'                     => $outdir,
					       'analysis_hash'              => $analysis_hash
					       );
		    }
		}
		else{
		    ## If no exons are associated to this particular model, simply report
		    ## to log file and continue processing (bug 1803).
		    $logger->fatal("No exons associated to the model '$model->{'feat_name'}'");
		}    
	    }			   
	    
	    if (0){
		## disabling this for now  2008-09-12
		## as per Anu- not needed
		&calculate_and_store_splice_sites($coding_regions->{$tu_feat_name}, 
						  $exons,
						  $asmbl_id,
						  $doc, 
						  $prefix, 
						  $database,
						  $tu_feat_name,
						  $param{'polypeptide_sequence_element_lookup'}, 
						  $param{'feature_group_element_lookup'},
						  $param{'feature_table_element_lookup'} );
	    }
	}
	else{
	    ## If no models are associated to this particular TU, simply report
	    ## to log file and continue processing (bug 1803).
	    $logger->fatal("No coding_regions associated to the transcript '$tu_feat_name'");
	}
    }
}


#----------------------------------------------------------------------------------
# store_euk_subfeature()
#
#----------------------------------------------------------------------------------
sub store_euk_subfeature {

    my (%param) =@_;

    my $data                    = $param{'data'};
    my $class                   = $param{'class'};
    my $assembly_sequence_elem  = $param{'assembly_seq'};
    my $gene_group_lookup       = $param{'gene_group_lookup'};
    my $gene_feature_group_elem = $param{'gene_feature_group_elem'};
    my $asmbl_id                = $param{'asmbl_id'};
    my $prefix                  = $param{'prefix'};
    my $doc                     = $param{'doc'};
    my $feature_table_elem      = $param{'feature_table_elem'};
    my $feat_name               = $param{'feat_name'};
    my $transcript_feature_group_elem = $param{'transcript_feature_group_elem'};
    my $genestored              = $param{'genestored'};
    my $uniquename              = $param{'transcript_uniquename'};
    my $transcript_feature_hash = $param{'transcript_feature_hash'};
    my $polypeptide_feat_name_to_locus = $param{'polypeptide_feat_name_to_locus'};
    my $polypeptide_feature_hash       = $param{'polypeptide_feature_hash'};
    my $accession_hash             = $param{'accession_hash'};
    my $seq_data_import_hash       = $param{'seq_data_import_hash'};
    my $identifier_feature         = $param{'identifier_feature'};
    my $ev_type                    = $param{'ev_type'};
    my $outdir                     = $param{'outdir'};
    my $analysis_hash              = $param{'analysis_hash'};
    my $cds_feature_hash           = $param{'cds_feature_hash'};


    if (!defined($feat_name)){
	$feat_name = $data->{'feat_name'};
    }

    if ($uniquename eq 'UNDEF'){

	$uniquename = &get_uniquename($prism,
				      $database,
				      $asmbl_id,
				      $feat_name,
				      $class);
    }

    ## The legacy2bsml.pl script should ensure that 
    ## //Feature/@id == //Seq-data-import/@identifier 
    ## for all sequences/features (bug 2044)
    $identifier_feature->{$uniquename}++;

    if (($class eq 'gene') && ($genestored > 0 )){

	## If processing the same gene a second time, then simply goto to the portion of this 
	## subroutine which inserts the gene as part of the transcript's feature-group

    }
    else {

	if ($class eq 'transcript'){

	    ## We are now feature-grouping by transcript (and no longer by gene) 
	    ## in order to accomodate alternative splicing
	    $transcript_feature_group_elem = $doc->createAndAddFeatureGroup(
									    $assembly_sequence_elem,  # <Sequence> element object reference
									    undef,                    # id
									    "$uniquename"             # groupset
									    );  
	    
	    $logger->logdie("Could not create <Feature-group> element object reference for uniquename '$uniquename'") if (!defined($transcript_feature_group_elem));
	    
	    
	    $gene_group_lookup->{$feat_name} = $transcript_feature_group_elem;
	}


	## Create a <Feature> element object with <Interval-loc> element object for this current feature
	my $feature_elem = $doc->createAndAddFeatureWithLoc(
							    $feature_table_elem,  # <Feature-table> element object reference
							    "$uniquename",        # id
							    undef,                # title
							    $class,               # class
							    undef,                # comment
							    undef,                # displayAuto
							    $data->{'end5'},      # start
							    $data->{'end3'},      # stop
							    $data->{'complement'} # complement
							    );

	if (!defined($feature_elem)){
	    $logger->logdie("Could not create <Feature> element object reference for '$uniquename'"); 
	}

	
	## Store the <Feature> element object reference for transcripts and polypeptides
	if ($class eq 'transcript'){

	    ## Store reference to the transcript's <Feature> element object
	    $transcript_feature_hash->{$uniquename} = $feature_elem;

	    ## Some TUs are categorized as pseudogenes.  This information needs to be
	    ## correctly propagated in the BSML gene model documents and then the
	    ## chado comparative databases.
	    ## Note that the pseudogene attribute is now associated with the transcripts 
	    ## and not the genes (bug 2012).
	    if ($data->{'is_pseudogene'} == 1){
		
		my $arr1;
		push ( @{$arr1}, { name    => 'SO',
				   content => 'pseudogene'});
		
		$feature_elem->addBsmlAttributeList($arr1);
	    }

	    ## Support for storing asm_feature.curated for the TU in the 
	    ## BSML gene model document (bug 2292).
	    if (( exists $data->{'gene_structure_curated'}) && (defined($data->{'gene_structure_curated'})) && ($data->{'gene_structure_curated'} == 1) ){

		my $attribute_elem = $doc->createAndAddBsmlAttribute(
								     $feature_elem,                       # <Feature> element object reference
								     "gene_structure_curated",            # name
								     "$data->{'gene_structure_curated'}"  # content
								     );
		
		$logger->logdie("Could not create <Attribute> element object reference for transcript '$uniquename' gene_structure_curated '$data->{'gene_structure_curated'}") if (!defined($attribute_elem));
	    }
	}


	if ($class eq 'CDS') {

	    ## Support for storing asm_feature.curated for the model 
	    ## in the BSML gene model document (bug 2292).
	    if (( exists $data->{'gene_annotation_curated'}) && (defined($data->{'gene_annotation_curated'})) && ($data->{'gene_annotation_curated'} == 1) ){
		
		my $attribute_elem = $doc->createAndAddBsmlAttribute(
								     $feature_elem,                       # <Feature> element object reference
								     "gene_annotation_curated",           # name
								     "$data->{'gene_annotation_curated'}" # content
								     );
		
		$logger->logdie("Could not create <Attribute> element object reference for CDS '$uniquename' gene_annotation_curated '$data->{'gene_annotation_curated'}") if (!defined($attribute_elem));
	    }

	    ## Populate this lookup so that we can later associate is_partial
	    ## ORF_attributes with the CDS (bug 2292).
	    $cds_feature_hash->{$uniquename} = $feature_elem;
	}


	if ($class eq 'polypeptide') {
	    #
	    # Store reference using the feat_name not the locus
	    #
	    
	    $polypeptide_feat_name_to_locus->{$data->{'feat_name'}} = $uniquename;
	    
	    my $uniquename1 = &get_uniquename( $prism,
					       $database,
					       $asmbl_id,
					       $data->{'feat_name'},
					       $class);

	    $polypeptide_feature_hash->{$uniquename1} = $feature_elem;
	}


	#------------------------------------------------------------------------------------------------
	# Create <Cross-reference> element object for the feat_name
	#
	#------------------------------------------------------------------------------------------------
	my $xref_elem = $doc->createAndAddCrossReference(
							 'parent'          => $feature_elem,
							 'id'              => $doc->{'xrefctr'}++,
							 'database'        => $prefix,
							 'identifier'      => $data->{'feat_name'},
							 'identifier-type' => 'feat_name'
							 );
	if (!defined($xref_elem)){
	    $logger->logdie("Could not create <Cross-reference> for the feat_name '$data->{'feat_name'}' as a class of type '$class'");
	}								 
	
	#------------------------------------------------------------------------------------------------
	# Create <Cross-reference> element objects for some of the data coming from ident table
	#
	#------------------------------------------------------------------------------------------------
	foreach my $locustype ('locus', 'pub_locus', 'alt_locus'){
	    
	    if (defined($data->{$locustype})){
		
		#
		# Create <Cross-reference> element object for the locus or display_locus or alt_locus
		#
		my $xref_elem = $doc->createAndAddCrossReference(
								 'parent'          => $feature_elem,
								 'id'              => $doc->{'xrefctr'}++,
								 'database'        => $prefix,
								 'identifier'      => $data->{$locustype},
								 'identifier-type' => "$locustype"
								 );
		if (!defined($xref_elem)){
		    $logger->logdie("Could not create <Cross-reference> for the $locustype '$data->{'feat_name'}' as a class of type '$class'");
		}								 
		
	    }
	}

	if ($class eq 'gene' ) {
	    #
	    # Store additional dbxref for genbank_pid, genbank_protein_id, swiss_prot and ecocyc
	    #
	    if ((exists $accession_hash->{$data->{'feat_name'}}) && (defined($accession_hash->{$data->{'feat_name'}}))){
		
		foreach my $key (sort keys %{$accession_hash->{$data->{'feat_name'}}} ){
		    
		    my $val = $accession_hash->{$data->{'feat_name'}}->{$key};
		    
		    #
		    # Create <Cross-reference> element object
		    #
		    my $xref_elem = $doc->createAndAddCrossReference(
								     'parent'          => $feature_elem,
								     'id'              => $doc->{'xrefctr'}++,
								     'database'        => $prefix,
								     'identifier'      => $val,
								     'identifier-type' => "$key"
								     );
		    if (!defined($xref_elem)){
			$logger->logdie("Could not create <Cross-reference> for key '$key' val '$val'");
		    }								 
		}
	    }
	}


	if ($class eq 'polypeptide') {

	    my $polypeptide_feat_name = $data->{'feat_name'};

	    $polypeptide_feat_name =~ s/\.m/\.p/;

	    my $sequence_key = &get_uniquename($prism,
					       $database,
					       $asmbl_id,
					       $polypeptide_feat_name,
					       $class);
	    $sequence_key .= '_seq';

	    if ((exists ($seq_data_import_hash->{$sequence_key})) and (defined($seq_data_import_hash->{$sequence_key}))){

		my $link_elem = $doc->createAndAddLink(
						       $feature_elem,
						       'sequence',                              # rel
						       "#$sequence_key"                         # href
						       );
		
		if (!defined($link_elem)){
		    $logger->logdie("Could not create a 'sequence' <Link> element object reference for gene model subfeature '$uniquename' and sequence ref '$sequence_key'");
		}
	    }
	    else {
#		$logger->fatal("sequence key '$sequence_key' did not exist in seq_data_import_hash:". Dumper $seq_data_import_hash);die;
	    }
	}


	if ($class eq 'CDS'){
	    
	    #
	    # Create <Link> to link polypeptide or CDS <Feature> element to the polypeptide_seq or CDS_seq <Sequence> element
	    #
	    my $sequence_key = &get_uniquename($prism,
					       $database,
					       $asmbl_id,
					       $data->{'feat_name'},
					       $class);

	    $sequence_key .= '_seq';

	    if ((exists ($seq_data_import_hash->{$sequence_key})) and (defined($seq_data_import_hash->{$sequence_key}))){
		
		my $link_elem = $doc->createAndAddLink(
						       $feature_elem,
						       'sequence',                              # rel
						       "#$sequence_key"                         # href
						       );
		
		if (!defined($link_elem)){
		    $logger->logdie("Could not create a 'sequence' <Link> element object reference for gene model subfeature '$uniquename' and sequence ref '$sequence_key'");
		}
	    }
	    else{
		
		#
		# Note that it is acceptable for some ORFs to not have an associated polypeptide translation
		#


		## If the CDS/model feature's ev_type is not working, 
		## then does not matter that the sequence does not exist
		if (defined($ev_type)) {
		    
		    if ($ev_type eq 'working'){
			
			$logger->logdie("<Seq-data-import> does not exist for sequence '$sequence_key' ev_type '$ev_type'");
		    }
		}
	    }
	}
    



	if (defined($ev_type)){
	    
	    if ($ev_type ne 'working') {

		&add_analysis_component( 'doc'           => $doc,
					 'sourcename'    => $sourcename,
					 'analysis_hash' => $analysis_hash,
					 'analysis_type' => $ev_type
					 );

		## Support for retrieving gene finder data (from phys_ev).  
		## If the model's ev_type is anything other than 'working', 
		## then need to store such information in the BSML as a
		## <Link> to some analysis where analysis.program = ev_type
		## (bug 2107).
		my $link_elem = $doc->createAndAddLink(
						       $feature_elem,
						       'analysis',       # rel
						       "#$ev_type",      # href
						       'computed_by'     # role 
						       );
		
		if (!defined($link_elem)){
		    $logger->logdie("Could not create an 'analysis' <Link> element object reference for gene model subfeature '$uniquename' and ev_type '$ev_type'");
		}
	    }
	}
    }
	
	
    ## Create <Feature-group-member> element object for this Gene Model subfeature
    ##
    ## We are now feature-grouping the subfeatures by transcripts and NOT by genes.
    ## This facilitates multiple alternative models (alternative splicing).
    my $feature_group_member_elem = $doc->createAndAddFeatureGroupMember(
									 $transcript_feature_group_elem,  # <Feature-group> element object reference
									 $uniquename,          # featref
									 $class,               # feattype
									 undef,                # grouptype
									 undef,                # cdata
									 ); 
    if (!defined($feature_group_member_elem)){
	$logger->logdie("Could not create <Feature-group-member> element object reference for gene model subfeature '$uniquename'");
    }

    $genestored++ if ($class eq 'gene');

    return ($transcript_feature_group_elem, $genestored);
}

#-------------------------------------------------------------------
# writeRnaDataToBsml()
#
#-------------------------------------------------------------------
sub writeRnaDataToBsml {

    my ($rnaLookup, $asmbl_id, $database, $doc, $prefix, $feature_table_elem, $identifier_feature, $genome_id, $fastadir, $fastasequences, $seq_data_import_hash) = @_;

    ## rnaLookup description:
    ## key: f.feat_name
    ## value: array reference with following elements:
    ## 0 => f.end5
    ## 1 => f.end3
    ## 2 => f.feat_type
    ## 3 => i.com_name
    ## 4 => i.gene_sym
    ## 5 => i.pub_comment
    ## 6 => i.locus
    ## 7 => f.sequence
    ## 8 => anti-codon

    foreach my $feat_name (sort keys %{$rnaLookup}){
	my $array = $rnaLookup->{$feat_name};
	my $class;

	if (exists $classMappingLookup->{$array->[2]}){
	    $class = $classMappingLookup->{$array->[2]};
	}
	else {
	    $logger->logdie("feat_type '$array->[2]' does not exist in classMappingLookup");
	}

	my $uniquename = &get_uniquename($prism, $database, $asmbl_id, $feat_name, $class);

	## The legacy2bsml.pl script should ensure that
	## //Feature/@id == //Seq-data-import/@identifier
	## for all sequences/features (bug 2044).
	$identifier_feature->{$uniquename}++;
 
	my ($fmin, $fmax, $complement) = &coordinates($array->[0], $array->[1]);
    
	if (!defined($fmin)){
	    $logger->logdie("fmin was not defined for feat_name '$feat_name' ".
			    "uniquename '$uniquename' asmbl_id '$asmbl_id' ".
			    "database '$database'");
	}
	if (!defined($fmax)){
	    $logger->logdie("fmax was not defined for feat_name '$feat_name' ".
			    "uniquename '$uniquename' asmbl_id '$asmbl_id' ".
			    "database '$database'");
	}
	if (!defined($complement)){
	    $logger->logdie("complement was not defined for feat_name '$feat_name' ".
			    "uniquename '$uniquename' asmbl_id '$asmbl_id' ".
			    "database '$database'");
	}

	## Create <Feature> element object
	my $feature_elem = $doc->createAndAddFeatureWithLoc(
							    $feature_table_elem,  # <Feature-table> element object reference
							    "$uniquename",        # id
							    undef,                # title
							    $class,               # class
							    undef,                # comment
							    undef,                # displayAuto
							    $fmin,                # start
							    $fmax,                # stop
							    $complement           # complement
							    );
	if (!defined($feature_elem)){
	    $logger->logdie("Could not create <Feature> element object reference for RNA type '$class' uniquename '$uniquename'"); 
	}
	
	if (defined($array->[3])){
	    my $attributeElem = $doc->createAndAddBsmlAttribute($feature_elem,      # <Feature> element object reference
								'name', # name
								$array->[3]  # content
								);
	    
	    if (!defined($attributeElem)){
		$logger->logdie("Could not create <Attribute> element object with name 'name' content '$array->[3]' ".
				"for the RNA Feature with uniquename '$uniquename' for database '$database' asmbl_id '$asmbl_id' ");
	    }
	}

	if (defined($array->[4])){
	    my $attributeElem = $doc->createAndAddBsmlAttribute($feature_elem,      # <Feature> element object reference
								'gene_symbol', # name
								$array->[4]  # content
								);
	    
	    if (!defined($attributeElem)){
		$logger->logdie("Could not create <Attribute> element object with name 'gene_symbol' content '$array->[4]' ".
				"for the RNA Feature with uniquename '$uniquename' for database '$database' asmbl_id '$asmbl_id' ");
	    }
	}

	if (defined($array->[5])){
	    my $attributeElem = $doc->createAndAddBsmlAttribute($feature_elem,      # <Feature> element object reference
								'public_comment', # name
								$array->[5]  # content
								);
	    
	    if (!defined($attributeElem)){
		$logger->logdie("Could not create <Attribute> element object with name 'public_comment' content '$array->[5]' ".
				"for the RNA Feature with uniquename '$uniquename' for database '$database' asmbl_id '$asmbl_id' ");
	    }
	}

	if (defined($array->[8])){
	    my $attributeElem = $doc->createAndAddBsmlAttribute($feature_elem,      # <Feature> element object reference
								'tRNA_anti-codon', # name
								$array->[8]  # content
								);
	    
	    if (!defined($attributeElem)){
		$logger->logdie("Could not create <Attribute> element object with name 'public_comment' content '$array->[8]' ".
				"for the RNA Feature with uniquename '$uniquename' for database '$database' asmbl_id '$asmbl_id' ");
	    }
	}


	## Create <Cross-reference> element object for the RNA
	my $xref_elem = $doc->createAndAddCrossReference(
							 'parent'          => $feature_elem,
							 'id'              => $doc->{'xrefctr'}++,
							 'database'        => $prefix,
							 'identifier'      => $feat_name,
							 'identifier-type' => 'feat_name'
							 );
    
	if (!defined($xref_elem)){
	    $logger->logdie("Could not create a <Cross-reference> element object for ".
			    "RNA type '$class' identifier '$feat_name' uniquename ".
			    "'$uniquename' for database '$database' asmbl_id '$asmbl_id'");
	}


	## Storing the ident.locus in <Cross-reference> element if defined, 
	## else storing storing default value. (bgz3384)
	my $rnaidentifier;
	
	if (defined($array->[6])){
	    $rnaidentifier = $array->[6];
	}
	else {
	    ## Create <Cross-reference> element object for the RNA with //Cross-reference/@identifier = uc(legacy database name) . '_' . feat_name
	    $rnaidentifier = uc($database) . '_' . $feat_name;
	}
	
	my $xref_elem2 = $doc->createAndAddCrossReference(
							  'parent'          => $feature_elem,
							  'id'              => $doc->{'xrefctr'}++,
							  'database'        => $prefix,
							  'identifier'      => $rnaidentifier,
							  'identifier-type' => 'locus'
							  );
	if (!defined($xref_elem2)){
	    $logger->logdie("Could not create a <Cross-reference> element object for ".
			    "RNA type '$class' with uniquename '$uniquename' ".
			    "identifier '$rnaidentifier' identifier-type 'locus' ".
			    "for database '$database' asmbl_id '$asmbl_id'");
	}


	if (defined($array->[7])){
	    ## Create <Sequence> for this RNA feature
	    my $uniquename_seq = $uniquename . '_seq';

	    &writeSequenceAndSeqDataImportToBsml($doc, $uniquename_seq, $class, $database, $asmbl_id, $genome_id, $fastadir, $array->[7], $fastasequences, $seq_data_import_hash);


	    ## Create <Link> to link RNA's <Feature> element to the RNA's <Sequence> element	    
	    my $link_elem = $doc->createAndAddLink( $feature_elem,
						    'sequence',        # rel
						    "#$uniquename_seq" # href
						    );
	    if (!defined($link_elem)){
		$logger->logdie("Could not create a 'sequence' <Link> element for <Feature> ".
				"RNA type '$class' uniquename '$uniquename' ".
				"to RNA <Sequence> '$uniquename_seq'");
	    }

	}
	else {
	    $logger->logdie("The asm_feature.sequence was not defined for RNA feat_type '$class' ".
			    "feat_name '$feat_name' uniquename '$uniquename' database '$database' ".
			    "asmbl_id '$asmbl_id'");
	}
    }

}	    

#----------------------------------------------------------------
# writeSequenceAndSeqDataImportToBsml()
#
#----------------------------------------------------------------
sub writeSequenceAndSeqDataImportToBsml {

    my ($doc, $id, $class, $database, $asmbl_id, $genome_id, $fastadir, $sequence, $fastasequences, $seq_data_import_hash) = @_;

    my $moleculeType;

    if (exists $featTypeToMoleculeTypeLookup->{$class}){
	$moleculeType = $featTypeToMoleculeTypeLookup->{$class};
    }
    else {
	$logger->logdie("class '$class' does not exist in lookuip featTypeToMoleculeTypeLookup");
    }

    my $length = length($sequence);

    ## Create <Sequence> element object for the subfeature as a sequence
    my $sequence_elem = $doc->createAndAddSequence( $id,                               # id
						    undef,    # title
						    $length,  # length
						    $moleculeType,                         # molecule
						    $class                                 # class
						    );

    if (!defined($sequence_elem)){
	$logger->logdie("Could not create <Sequence> for the sequence '$id'");
    }  

    ## The <Sequence> will now be explicitly linked with the <Genome> (bug 2051)
    my $link_elem = $doc->createAndAddLink(
					   $sequence_elem,
					   'genome',        # rel
					   "#$genome_id"   # href
					   );
    
    if (!defined($link_elem)){
	$logger->logdie("Could not create a 'genome' <Link> element ".
			"object reference for sequence '$id' ".
			"genome_id '$genome_id'");
    }

    if (  exists $storeSequenceAsSeqData->{$class}){
	## Create some <Seq-data> BSML element object
	
	my $seq_data = $doc->createAndAddSeqData($sequence_elem, $sequence);
	if (!defined($seq_data)){
	    $logger->logdie("Could not create <Seq-data> element object for Sequence ".
			    "with id '$id' for database '$database' asmbl_id '$asmbl_id'");
	}
    }
    else {

	## Store data in the fasta lookup for later writing the FASTA file
	push ( @{$fastasequences->{$asmbl_id}->{$class}}, [$id, $sequence]);
   
	## Create some <Seq-data-import> BSML element object
	my $source = $fastadir .'/'. $database . '_' . $asmbl_id . '_' . $class .'.fsa';

	    
	## The legacy2bsml.pl script should ensure that 
	## //Feature/@id == //Seq-data-import/@identifier 
	## for all sequences/features (bug 2044)
	$identifier_seq_data->{$id}++;
	
	my $seq_data_import_elem = $doc->createAndAddSeqDataImport(
								   $sequence_elem, # <Sequence> element object reference
								   'fasta',        # format
								   $source,        # source
								   undef,          # id
								   $id             # identifier
								   );
	if (!defined($seq_data_import_elem)){
	    $logger->logdie("seq_data_import_elem was not defined for sequence '$id'");
	}

	## Store the <Seq-data-import> element object reference in the lookup
	$seq_data_import_hash->{$id} = $seq_data_import_elem;
    }
}

#--------------------------------------------------------------------------------------------
# Ribosomal binding site encoding
#
#
#
#--------------------------------------------------------------------------------------------
sub store_ribosomal_binding_site_encodings {

    my %p = @_;
    my $database = $p{'database'};
    my $doc      = $p{'doc'};
    my $prefix   = $p{'prefix'};
    my $asmbl_id = $p{'asmbl_id'};
    my $ribo     = $p{'ribo'};
    my $feature_table_elem = $p{'feature_table_elem'};
    my $r2g_lookup = $p{'r2g_lookup'};
    my $gene_group_lookup = $p{'gene_group_lookup'};
    my $analysis_hash     = $p{'analysis_hash'};
    my $identifier_feature = $p{'identifier_feature'};


    my $uniquename = &get_uniquename($prism,
				     $database,
				     $asmbl_id,
				     $ribo->{'feat_name'},
				     'ribosome_entry_site');

    ## The legacy2bsml.pl script should ensure that the //Feature/@id == //Seq-data-import/@identifier 
    ## for all sequences/features (bug 2044).
    $identifier_feature->{$uniquename}++;

    my $feature_elem = $doc->createAndAddFeature(
						 $feature_table_elem,   # <Feature-table> element object reference
						 $uniquename,           # id
						 undef,                 # title
						 'ribosome_entry_site'  # class
						 );

    $logger->logdie("Could not create <Feature> element object reference for ribosome_entry_site '$uniquename'") if (!defined($feature_elem));

    my $xref_elem = $doc->createAndAddCrossReference(
						     'parent'          => $feature_elem,
						     'id'              => $doc->{'xrefctr'}++,
						     'database'        => $prefix,
						     'identifier'      => $ribo->{'feat_name'},
						     'identifier-type' => 'feat_name'
						     );
    
    $logger->logdie("Could not create a <Cross-reference> element object reference for ribosome_entry_site uniquename '$uniquename'") if (!defined($xref_elem));



    my $interval_loc_elem = $doc->createAndAddIntervalLoc(
							  $feature_elem,         # <Feature> element object reference
							  $ribo->{'end5'},       # start
							  $ribo->{'end3'},       # end
							  $ribo->{'complement'}  # complement
							  );

    $logger->logdie("Could not create <Interval-loc> element object reference for ribosome_entry_site '$uniquename'") if (!defined($interval_loc_elem));
    

    my $uniquename_seq = $uniquename . '_seq';

    my $sequence_link_elem = $doc->createAndAddLink(
#						    $seq_data_import_hash->{$uniquename_seq},  # <Seq-data-import> element object reference
						    $feature_elem,
						    'sequence',                                # rel
						    "#$uniquename_seq"                         # href
						    );
    
    $logger->logdie("Could not create a 'sequence' <Link> element for <Feature> ribosome_entry_site uniquename '$uniquename' to ribosome_entry_site <Sequence> '$uniquename_seq'") if (!defined($sequence_link_elem));
    
    my $computeType = 'RBS';

    if (!exists $analysis_hash->{$doc->{'doc_name'}}->{$computeType}){

	&createAnalysisComponent( 'doc'           => $doc,
				  'analysis_hash' => $analysis_hash,
				  'compute_type'  => $computeType );
    }



    ## A <Link> will tie this ribosome_binding_site's <Feature> element to the appropriate
    ## RBS_analysis <Analysis> element
    my $analysis_link_elem = $doc->createAndAddLink( $feature_elem,
						     'analysis',       # rel
						     "#RBS",           # href
						     'computed_by'     # role
						    );
    
    $logger->logdie("Could not create an 'analysis' <Link> for RBS_analysis and ribosome feature '$uniquename'") if (!defined($analysis_link_elem));
    

    #
    # Create <Feature-group-member> element object for this Gene Model subfeature
    #
    if (exists $gene_group_lookup->{$r2g_lookup->{$asmbl_id}->{$ribo->{'feat_name'}}}){

	my $gene_feature_group_elem = $gene_group_lookup->{$r2g_lookup->{$asmbl_id}->{$ribo->{'feat_name'}}};

	my $feature_group_member_elem = $doc->createAndAddFeatureGroupMember(
									     $gene_feature_group_elem,  # <Feature-group> element object reference
									     $uniquename,               # featref
									     'ribosome_entry_site',     # feattype
									     undef,                     # grouptype
									     undef,                     # cdata
									     ); 
	if (!defined($feature_group_member_elem)){
	    $logger->logdie("Could not create <Feature-group-member> element object reference for gene model subfeature '$uniquename'");
	}
    }
    
}




#--------------------------------------------------------------------------
# store_terminator_features()
# reference: tigr_prok_migration page 13
#
#
#
#--------------------------------------------------------------------------
sub store_terminator_features {

    my %param    = @_;
    my $doc      = $param{'doc'};
    my $database = $param{'database'};
    my $prefix   = $param{'prefix'};
    my $term     = $param{'term'};
    my $asmbl_id = $param{'asmbl_id'};
    my $feature_table_elem = $param{'feature_table_elem'};
    my $t2g_lookup = $param{'t2g_lookup'};
    my $gene_group_lookup = $param{'gene_group_lookup'};
    my $analysis_hash     = $param{'analysis_hash'};
    my $identifier_feature = $param{'identifier_feature'};


    my $uniquename = &get_uniquename($prism,
				     $database,
				     $asmbl_id,
				     $term->{'feat_name'},
				     'terminator');
    
    ## The legacy2bsml.pl script should ensure that the //Feature/@id == //Seq-data-import/@identifier 
    ## for all sequences/features (bug 2044).
    $identifier_feature->{$uniquename}++;

    my $feature_elem = $doc->createAndAddFeatureWithLoc(
							$feature_table_elem,     # <Feature-table> element reference
							"$uniquename",           # id
							undef,                   # title
							'terminator',            # class
							undef,                   # comment
							undef,                   # displayAuto
							$term->{'end5'},         # start
							$term->{'end3'},         # end
							$term->{'complement'}    # complement
							);

    $logger->logdie("Could not create <Feature> for terminator '$uniquename'") 	if (!defined($feature_elem));



    my $uniquename_seq = $uniquename . '_seq';

    my $sequence_link_elem = $doc->createAndAddLink(
						    $feature_elem,       # element
						    'sequence',          # rel
						    "#$uniquename_seq"   # href
						    );
    
    $logger->logdie("Could not create a 'sequence' <Link> element for <Feature> terminator uniquename '$uniquename' to terminator <Sequence> '$uniquename_seq'") if (!defined($sequence_link_elem));



    foreach my $termAttrType ( keys %{$terminatorAttributeLookup} ) {
    
	if (defined($term->{$termAttrType})){
	
	    my $attribute_elem = $doc->createAndAddBsmlAttribute(
								 $feature_elem,          # <Feature> element object reference
								 $terminatorAttributeLookup->{$termAttrType},       # name
								 "$term->{$termAttrType}"  # content
								 );
	    if (!defined($attribute_elem)){
		$logger->logdie("Could not create <Attribute> element object reference ".
				"with name '$terminatorAttributeLookup->{$termAttrType}' ".
				"and content '$term->{$termAttrType}' ".
				"for the terminator uniquename '$uniquename'");
	    }
	}    
    }

    my $xref_elem = $doc->createAndAddCrossReference(
						     'parent'          => $feature_elem,
						     'id'              => $doc->{'xrefctr'}++,
						     'database'        => $prefix,
						     'identifier'      => $term->{'feat_name'},
						     'identifier-type' => 'feat_name'
						     );
    
    $logger->logdie("Could not create a <Cross-reference> element object reference for terminator '$uniquename'") if (!defined($xref_elem));

    my $computeType = 'TERM';

    if (!exists $analysis_hash->{$doc->{'doc_name'}}->{$computeType}){

	&createAnalysisComponent( 'doc'           => $doc,
				  'analysis_hash' => $analysis_hash,
				  'compute_type'  => $computeType );
    }

    
    ## Link the Seq-pair-alignment to the particular Analysis (bug 2172).
    my $link_elem = $doc->createAndAddLink( $feature_elem,
					    'analysis',       # rel
					    "#TERM",          # href
					    'computed_by'     # role
					    );
    
    $logger->logdie("Could not create an 'analysis' <Link> for TERM_analysis and terminator feature '$uniquename'") if (!defined($link_elem));

	
    #
    # Create <Feature-group-member> element object for this Gene Model subfeature
    #
    if (exists $gene_group_lookup->{$t2g_lookup->{$asmbl_id}->{$term->{'feat_name'}}}){
	
	my $gene_feature_group_elem = $gene_group_lookup->{$t2g_lookup->{$asmbl_id}->{$term->{'feat_name'}}};
	
	my $feature_group_member_elem = $doc->createAndAddFeatureGroupMember(
									     $gene_feature_group_elem,  # <Feature-group> element object reference
									     $uniquename,               # featref
									     'terminator',              # feattype
									     undef,                     # grouptype
									     undef,                     # cdata
									     ); 
	if (!defined($feature_group_member_elem)){
	    $logger->logdie("Could not create <Feature-group-member> element object reference for gene model subfeature '$uniquename'");
	}
    }
    

}




#----------------------------------------------------------------------------------------
# Gene annotation Attributes -- ident attributes
#
#----------------------------------------------------------------------------------------
sub store_ident_attributes {

    my %p = @_;
    my $doc            = $p{'doc'};
    my $attributes     = $p{'attributes'};
    my $attribute_list = $p{'attribute-list'};
    my $uniquename     = $p{'uniquename'};
    my $transcript_feature_elem = $p{'transcript_feature_elem'};
    my $tran_ident_lookup   = $p{'tran_ident_lookup'};


    if ((defined($attributes)) && (scalar(@{$attributes}) > 0)){
	
	#
	# attributes is now a reference to a list of hashes
	#
	foreach my $hash (sort @{$attributes} ){
	    
	    foreach my $ident_attribute ( sort keys %{$hash} ){
		
		if ($ident_attribute ne 'genbank'){

		    #
		    # Strip trailing whitespaces
		    #
		    my $value = $hash->{$ident_attribute};
		    $value =~ s/\s+$//;
		    
		    my $key = $transcript_feature_elem . '_' . $ident_attribute . '_' . $value;
		    
		    if (! exists $tran_ident_lookup->{$key} ) { 
			
			my $attribute_elem = $doc->createAndAddBsmlAttribute(
									     $transcript_feature_elem,    # elem
									     $ident_attribute,            # key
									     $value                       # value
									     );
			
			$logger->logdie("Could not create <Attribute> element object reference for attribute name '$ident_attribute' value '$hash->{$ident_attribute}' for transcript '$uniquename'") if (!defined($attribute_elem));
			

			$tran_ident_lookup->{$key}++;
		    }
		}
		else {

		    #------------------------------------------------------------------------------------------------
		    # Create <Cross-reference> element object for any of the values coming out of
		    # ident_xref.ident_val
		    #
		    # //Feature/[@class='transcript']/Cross-reference/@database='genbank'
		    # //Feature/[@class='transcript']/Cross-reference/@identifier=ident_xref.ident_val
		    #     where ident_xref.feat_name = asm_feature.feat_name
		    #     and ident_xref.xref_type = 'genbank accession'
		    #
		    #------------------------------------------------------------------------------------------------

		    my $xref_elem = $doc->createAndAddCrossReference(
								     'parent'          => $transcript_feature_elem, # elem
								     'id'              => $doc->{'xrefctr'}++,
								     'database'        => 'genbank',
								     'identifier'      => $hash->{$ident_attribute},
								     'identifier-type' => 'genbank_pid'
								     );
		    if (!defined($xref_elem)){
			$logger->logdie("Could not create <Cross-reference> for the transcript '$uniquename' database 'genbank' identifier '$hash->{$ident_attribute}' identifier-type 'genbank_pid'");
		    }				
		}
	    }
	}	
    }


    if ((defined($attribute_list)) && (scalar(@{$attribute_list}) > 0 )){

	#
	# The ec# will now be stored in an <Attribute-list>
	#
	foreach my $list ( @{$attribute_list} ) {

	    foreach my $hash ( @{$list} ) {
		
		foreach my $key (sort keys %{$hash} ){
		    
		    my $val = $hash->{$key};
		
		    next if ($val eq '');
		    next if ( length($val) < 1);

    
		    my $index = $transcript_feature_elem . '_' . $key . '_' . $val;
		    
		    if (! exists $tran_ident_lookup->{$index} ) { 
			
			my $list2 = [];
			
			push( @{$list2},  { name => $key,
					    content => $val });
			
			
			$tran_ident_lookup->{$index}++;

			$transcript_feature_elem->addBsmlAttributeList($list2);
			
		    }
		}
	    }
	}
    }
}

    
#------------------------------------------------------------------------------------------------------------------------------------------
# Gene annotation Attributes -- TIGR Roles
#
# For each feat_name being processed
# store each role_link.{role_id, assignby, date} value in an <Attribute> BSML element 
# and associate these elements to the transcripts' <Feature> element
#
# <Feature>
#     <Attribute-list>
#          <Attribute name="TIGR_role" content="23"></Attribute>
#          <Attribute name="assignby" content="angiuoli"></Attribute>
#          <Attribute name="date" content="Nov 12, 2004"></Attribute>
#     <Attribute-list>
# </Feature>
#
#
#------------------------------------------------------------------------------------------------------------------------------------------
sub store_roles_attributes {
    
    my %p = @_;

    my $transcript_feature_elem = $p{'transcript_feature_elem'};
    my $uniquename = $p{'uniquename'};
    my $attributelist = $p{'attributelist'};

    my @list;
    my $add=0;


    #
    # Should store:
    # 1) TIGR_role
    # 2) assignby
    # 3) date
    #
    
    foreach my $list ( @{$attributelist}) {
	
	my $list2 = [];
	
	foreach my $hash ( @{$list} ) {

	    foreach my $key (sort keys %{$hash} ){

		my $val = $hash->{$key};
	
		push( @{$list2},  { name => $key,
				    content => $val });

	    }
	}
	$transcript_feature_elem->addBsmlAttributeList($list2);
    }
}

#------------------------------------------------------------------------------------------------------------------------------------------
# Gene annotation Attributes -- GO
#
# For each feat_name being processed
# store each go_role_link.{go_id, assignby, date, qualifier} value in an <Attribute> BSML element 
# and associate these elements to the transcripts' <Feature> element
#
# <Feature>
#     <Attribute-list>
#          <Attribute name="TIGR_role" content="23"></Attribute>
#          <Attribute name="assignby" content="angiuoli"></Attribute>
#          <Attribute name="date" content="Nov 12, 2004"></Attribute>
#     <Attribute-list>
#     <Attribute-list>
#          <Attribute name="GO" content="GO:001232"></Attribute>
#          <Attribute name="assignby" content="angiuoli"></Attribute>
#          <Attribute name="date" content="Nov 12, 2004"></Attribute>
#          <Attribute name="qualifier" content="Nov 12, 2004"></Attribute>
#          <Attribute name="some_evidence_type" content="some_evidence_code WITH some ev_with"></Attribute>
#     <Attribute-list>
# </Feature>
#
#

#------------------------------------------------------------------------------------------------------------------------------------------
sub store_go_attributes {
    
    my %p = @_;

    my $transcript_feature_elem  = $p{'transcript_feature_elem'};
    my $uniquename               = $p{'uniquename'};
    my $attributelist            = $p{'attributelist'};


    my @list;
    my $add=0;

    #
    # Should store <Attribute-list> members:
    # 1) go_id
    # 2) assignby
    # 3) date
    # 4) qualifier
    # 5) ev_code/evidence/with
    #

    foreach my $list ( @{$attributelist} ){

	my $list2 = [];
	
	foreach my $hash ( @{$list} ) {
	    
	    foreach my $key (sort keys %{$hash} ){

		my $val = $hash->{$key};
	
		push( @{$list2},  { name => $key,
				    content => $val });

	    }
	}
	$transcript_feature_elem->addBsmlAttributeList($list2);
    }
}


#-----------------------------------------------------------------------------------------------------------------------------------------------
# Gene annotation Attributes -- ORF_attribute
#
#
# For each feat_name being processed
# store each  value in an <Attribute> BSML element 
# and associate these elements to the transcripts' <Feature> element
#
#
# <Feature>
#     <Attribute-list>
#          <Attribute name="TIGR_role" content="23"></Attribute>
#          <Attribute name="assignby" content="angiuoli"></Attribute>
#          <Attribute name="date" content="Nov 12, 2004"></Attribute>
#     <Attribute-list>
#     <Attribute-list>
#          <Attribute name="GO" content="GO:001232"></Attribute>
#          <Attribute name="assignby" content="angiuoli"></Attribute>
#          <Attribute name="date" content="Nov 12, 2004"></Attribute>
#          <Attribute name="qualifier" content="Nov 12, 2004"></Attribute>
#          <Attribute name="some_evidence_type" content="some_evidence_code WITH some ev_with"></Attribute>
#     <Attribute-list>
#     <Attribute-list>
#          <Attribute name="TIGR_role" content="23"></Attribute>
#          <Attribute name="assignby" content="angiuoli"></Attribute>
#          <Attribute name="date" content="Nov 12, 2004"></Attribute>
#     <Attribute-list>
# </Feature>
#
#
#
#------------------------------------------------------------------------------------------------------------------------------------------
sub store_orf_attribute_data {

    my %p = @_;
 
    my $transcript_feature_elem  = $p{'transcript_feature_elem'};
    my $uniquename               = $p{'uniquename'};
    my $doc                      = $p{'doc'};
    my $attributes               = $p{'attributes'};
    my $attributelist            = $p{'attributelist'};

    #
    # Should store <Attribute> elements:
    #
    # 1) MW
    # 2) pI
    # 3) GC
    #

    foreach my $attribute ( @{$attributes} ){
	

	#
	# Strip trailing whitespaces
	#
	my $value = $attribute->{'content'};
	$value =~ s/\s+$//;
	
	my $attribute_elem = $doc->createAndAddBsmlAttribute(
							     $transcript_feature_elem,   # elem
							     $attribute->{'name'},       # key
							     $value                      # value
							     );
	
	$logger->logdie("Could not create <Attribute> element object reference for orf_attribute '$attribute' value '$attributes->{$attribute}' for transcript '$uniquename'") if (!defined($attribute_elem));
    }	

    my @list;
    my $add=0;



    #
    # Should store <Attribute-list> members:
    # 1) transmembrance_coords
    # 2) transmembrane_regions
    # 3) lipo_membrane_protein
    # 4) outer_membrane_protein
    #

    foreach my $list ( @{$attributelist}) {
	


	#
	# This socks.  I have to unpackage and re-package for BSML API
	#

	my $list2 = [];
	
	foreach my $hash ( @{$list} ) {

	    foreach my $key (sort keys %{$hash} ){

		my $val = $hash->{$key};
	
		push( @{$list2},  { name => $key,
				    content => $val });

	    }
	}
	$transcript_feature_elem->addBsmlAttributeList($list2);
    }
}


#----------------------------------------------------------------------------------------
# Evidence
# BER/AUTO-BER Evidence Encoding
#
#----------------------------------------------------------------------------------------
sub store_ber_evidence_data { 

    my %p = @_;
    my $doc            = $p{'doc'};
    my $asmbl_id       = $p{'asmbl_id'};
    my $data_hash      = $p{'data_hash'};
    my $database       = $p{'database'};
    my $docname        = $p{'docname'};
    my $prefix         = $p{'prefix'};
    my $analysis_hash  = $p{'analysis_hash'};
    my $genome_id      = $p{'genome_id'};
    my $sequence_analysis_link = $p{'sequence_analysis_link'};


    #
    # attributes is now a reference to a list of hashes
    #

    my $computeType = 'BER';
    my $compute_type = $computeType;
    my $class = 'match';
    my $analysis_type = $compute_type . '_analysis';

    #
    #  Create one BER <Analysis> component
    # //Analysis/@id = 'BER_analysis'
    # //Analysis/Attribute/[@name='program']/@content = 'BER'
    # //Analysis/Attribute/[@name='programversion']/@content = 'legacy'
    # //Analysis/Attribute/[@name='algorithm']/@content = 'BER'
    # //Analysis/Attribute/[@name='sourcename']/@content = $docname
    # //Analysis/Attribute/[@name='name']/@content = 'BER_analysis'

    if (!exists $analysis_hash->{$doc->{'doc_name'}}->{$computeType}){
	
	&createAnalysisComponent ( 'doc'           => $doc,
				   'analysis_hash' => $analysis_hash,
				   'compute_type'  => $computeType );
    }


    foreach my $ev_type (sort keys  %{$data_hash} ){

	foreach my $feat_name (sort keys %{$data_hash->{$ev_type}} ){

	    foreach my $accession (sort keys %{$data_hash->{$ev_type}->{$feat_name}} ) { 

		foreach my $key (sort keys %{$data_hash->{$ev_type}->{$feat_name}->{$accession}} ) { 
	    
		    my $tmphash = $data_hash->{$ev_type}->{$feat_name}->{$accession}->{$key};
		    


		    my $refseq = &get_uniquename($prism,
						 $database,
						 $asmbl_id,
						 $feat_name,
						 'CDS');
		    my $compseq = $accession;

		    # determine if the query name and the dbmatch name are a unique pair in the document
		    
		    my $alignment_pair_list = BSML::BsmlDoc::BsmlReturnAlignmentLookup(
										       $refseq,
										       $compseq
										       );
		    my $alignment_pair;
		    if( $alignment_pair_list ){
			$alignment_pair = $alignment_pair_list->[0];
		    }
		    
		    if (!defined($alignment_pair)) {
			
			# no <Seq-pair-alignment> pair matches, add a new alignment pair and sequence run
			
			#check to see if sequences exist in the BsmlDoc, if not add them with basic attributes
			

			my $bsmlSequenceRefSeq =  $doc->returnBsmlSequenceByIDR( $refseq);
			
			if (!defined($bsmlSequenceRefSeq)){
			    
			    $bsmlSequenceRefSeq = &store_computational_sequence_stub( sequence_id => $refseq,
										      moltype     => 'dna',
										      class       => 'CDS',
										      genome_id   => $genome_id,
										      doc         => $doc,
										      identifier  => $feat_name,
										      database    => $prefix
										      );
			}

			## Need to store //Link/@role for each Sequence's analysis (bug 2273).
			&addSequenceAnalysisLink( $doc,
						  $bsmlSequenceRefSeq,
						  $computeType,
						  'input_of',
						  $sequence_analysis_link,
						  $refseq
						  );

			my $bsmlSequenceCompSeq = $doc->returnBsmlSequenceByIDR( $compseq );

			if( !( $bsmlSequenceCompSeq ) ){
			    
			    my $compseq_db;
			    my $compseq_accession;
			    
			    if ($accession =~ /:/){
				($compseq_db, $compseq_accession) = split(/:/, $accession);
			    }
			    else{
				$compseq_db = $accession;
				$compseq_accession = $accession;
			    }
			    
			    $bsmlSequenceCompSeq = &store_computational_sequence_stub( sequence_id => $compseq,
										       moltype     => 'aa',
										       class       => 'polypeptide',
										       doc         => $doc,
										       identifier  => $compseq_accession,
										       database    => $compseq_db,
										       );
			}


			## Need to store //Link/@role for each Sequence's analysis (bug 2273).
			&addSequenceAnalysisLink( $doc,
						   $bsmlSequenceCompSeq,
						   $computeType,
						   'input_of',
						   $sequence_analysis_link,
						   $compseq
						   );



			## Create <Seq-pair-alignment> and add attributes
			$alignment_pair = $doc->returnBsmlSeqPairAlignmentR( $doc->addBsmlSeqPairAlignment() );
			
			if (!defined($alignment_pair)){
			    $logger->logdie("Could not create <Seq-pair-alignment> element object reference");
			}
			else {
			    $alignment_pair->setattr( 'refseq',  $refseq  );
			    $alignment_pair->setattr( 'compseq', $compseq );
			    $alignment_pair->setattr( 'class',   $class   );
			}
			

			## Link the Seq-pair-alignment to the particular Analysis (bug 2172).
			my $link_elem = $doc->createAndAddLink(
							       $alignment_pair,   # <Seq-pair-alignment> element object reference
							       'analysis',        # rel
							       "#$compute_type",  # href
							       'computed_by'      # role
							       );

			$logger->logdie("Could not create an 'analysis' <Link> element object reference for <Seq-pair-alignment>") if (!defined($link_elem));

			
			#
			# Store reference to the <Seq-pair-alignment>
			#
			BSML::BsmlDoc::BsmlSetAlignmentLookup( $refseq, $compseq, $alignment_pair );
			
		    }


		    my $seq_run = &store_seq_pair_run_attributes( $alignment_pair, $tmphash, $doc );


		    ##---------------------------------------------------------------------------------------
		    ## If dealing with BER type evidence, need to store additional attributes.
		    ##
		    ##---------------------------------------------------------------------------------------
		    if ( $ev_type eq 'BER') {

			foreach my $attribute qw(auto_annotate_toggle percent_identity percent_similarity date) {

			    if ( (exists($tmphash->{$attribute})) and (defined($tmphash->{$attribute})) ){

				$seq_run->addBsmlAttr( "$attribute", $tmphash->{$attribute} );

			    }
			}
		    }
		}
	    }
	}
    }
}


#----------------------------------------------------------------------------------------
# store_prok_hmm2_evidence_data()
#
#
#----------------------------------------------------------------------------------------
sub store_prok_hmm2_evidence_data { 

    my %p = @_;
    my $doc            = $p{'doc'};
    my $asmbl_id       = $p{'asmbl_id'};
    my $data_hash      = $p{'data_hash'};
    my $database       = $p{'database'};
    my $docname        = $p{'docname'};
    my $prefix         = $p{'prefix'};
    my $analysis_hash  = $p{'analysis_hash'};
    my $genome_id      = $p{'genome_id'};
    my $sequence_analysis_link = $p{'sequence_analysis_link'};


    #
    # attributes is now a reference to a list of hashes
    #


    my $class = 'match';
    my $rel   = 'rel';
    my $href  = '#HMM2_analysis';

    my $computeType = 'HMM2';

    #
    #  Create one BER <Analysis> component
    # //Analysis/@id = 'HMM2_analysis'
    # //Analysis/Attribute/[@name='program']/@content = 'HMM'
    # //Analysis/Attribute/[@name='programversion']/@content = 'legacy'
    # //Analysis/Attribute/[@name='algorithm']/@content = 'HMM2'
    # //Analysis/Attribute/[@name='sourcename']/@content = $docname
    # //Analysis/Attribute/[@name='name']/@content = 'HMM2_analysis'

    if (!exists $analysis_hash->{$doc->{'doc_name'}}->{$computeType}){

	&createAnalysisComponent( 'doc'           => $doc,
				  'analysis_hash' => $analysis_hash,
				  'compute_type'  => $computeType );
	
	
    }

    foreach my $ev_type (sort keys %{$data_hash} ) {

	foreach my $feat_name (sort keys %{$data_hash->{$ev_type}} ){
	    
	    foreach my $accession (sort keys %{$data_hash->{$ev_type}->{$feat_name}} ){

		foreach my $key (sort keys %{$data_hash->{$ev_type}->{$feat_name}->{$accession}} ){
		    
		    my $tmphash = $data_hash->{$ev_type}->{$feat_name}->{$accession}->{$key};

		    my $refseq = &get_uniquename($prism,
						 $database,
						 $asmbl_id,
						 $feat_name,
						 'polypeptide');

		    my $compseq = $accession;
		    
		    # determine if the query name and the dbmatch name are a unique pair in the document
		    
		    my $alignment_pair_list = BSML::BsmlDoc::BsmlReturnAlignmentLookup(
										       $refseq,
										       $compseq
										       );
		    my $alignment_pair;
		    if( $alignment_pair_list ){
			$alignment_pair = $alignment_pair_list->[0];
		    }

		    if (!defined($alignment_pair)) {

			## No <Seq-pair-alignment> pair matches, add a new alignment pair and sequence run
			
			## Check to see if sequences exist in the BsmlDoc, if not add them with basic attributes
			my $bsmlSequenceRefSeq = $doc->returnBsmlSequenceByIDR( $refseq);

			if( !( $bsmlSequenceRefSeq ) ) {
			    
			    $bsmlSequenceRefSeq = &store_computational_sequence_stub( sequence_id => $refseq,
										      moltype     => 'aa',
										      class       => 'polypeptide',
										      genome_id   => $genome_id,
										      doc         => $doc,
										      identifier  => $feat_name,
										      database    => $prefix
										      );
			}
			
			## Need to store //Link/@role for each Sequence's analysis (bug 2273).
			&addSequenceAnalysisLink( $doc,
						  $bsmlSequenceRefSeq,
						  $computeType,
						  'input_of',
						  $sequence_analysis_link,
						  $refseq
						  );

			my $bsmlSequenceCompSeq = $doc->returnBsmlSequenceByIDR( $compseq );

			if( !( $bsmlSequenceCompSeq )) {

			    #
			    # If the Sequence stub represents an HMM accession that start with PFAM
			    # //Sequence//Cross-reference/@database   = 'PFAM'
			    # //Sequence//Cross-reference/@identifier = evidence.feat_name
			    #
			    # else if the Sequence stub represents an HMM accession that starts with TIGRFAM
			    # //Sequence//Cross-reference/@database   = 'TIGRFAM'
			    # //Sequence//Cross-reference/@identifier = evidence.feat_name
			    # 
			    #

			    ## Set default
			    my $compseq_db = $prefix;
			    
			    ## Check for more accurate/appropriate database
			    foreach my $compDbType ( keys %{$computeDatabaseLookup} ) { 

				if ($compseq =~ /^$compDbType/) {
				    $compseq_db = $computeDatabaseLookup->{$compDbType};
				    last;
				}
				## Note that this specific type of check is no longer being performed
				## if ($compseq =~ /^PS\d+$/){
			    }

			    $bsmlSequenceCompSeq = &store_computational_sequence_stub( sequence_id => $compseq,
										       moltype     => 'aa',
										       class       => 'polypeptide',
										       doc         => $doc,
										       identifier  => $compseq,
										       database    => $compseq_db
										       );
			}

			## Need to store //Link/@role for each Sequence's analysis (bug 2273).
			&addSequenceAnalysisLink( $doc,
						  $bsmlSequenceCompSeq,
						  $computeType,
						  'input_of',
						  $sequence_analysis_link,
						  $compseq
						  );
	

			##--------------------------------------------------------------------------
			## Create <Seq-pair-alignment> and add attributes
			##
			##--------------------------------------------------------------------------
			$alignment_pair = $doc->returnBsmlSeqPairAlignmentR( $doc->addBsmlSeqPairAlignment() );
			
			if (!defined($alignment_pair)){
			    $logger->logdie("Could not create <Seq-pair-alignment> element object reference");
			}
			else {
			    $alignment_pair->setattr( 'refseq',  $refseq  );
			    $alignment_pair->setattr( 'compseq', $compseq );
			    $alignment_pair->setattr( 'class',   $class   );
			}


			## Link the Seq-pair-alignment to the particular Analysis (bug 2172)
			my $link_elem = $doc->createAndAddLink(
							       $alignment_pair,  # <Seq-pair-alignment> element object reference
							       'analysis',       # rel
							       '#HMM2',          # href
							       'computed_by'     # role
							       );

			$logger->logdie("Could not create an 'analysis' <Link> element object reference for <Seq-pair-alignment>") if (!defined($link_elem));

			
			#
			# Store reference to the <Seq-pair-alignment>
			#
			BSML::BsmlDoc::BsmlSetAlignmentLookup( $refseq, $compseq, $alignment_pair );
			
		    }

		    my $seq_run = &store_seq_pair_run_attributes( $alignment_pair, $tmphash, $doc );

		}		
	    }    
	}
    }
}

#----------------------------------------------------------------------------------------
# Evidence
# COG accession Evidence Encoding
#
#----------------------------------------------------------------------------------------
sub store_cog_evidence_data { 

    my %p = @_;
    my $doc            = $p{'doc'};
    my $asmbl_id       = $p{'asmbl_id'};
    my $data_hash      = $p{'data_hash'};
    my $database       = $p{'database'};
    my $docname        = $p{'docname'};
    my $prefix         = $p{'prefix'};
    my $analysis_hash  = $p{'analysis_hash'};
    my $genome_id      = $p{'genome_id'};
    my $sequence_analysis_link = $p{'sequence_analysis_link'};

    my $class = 'match';
    my $href  = '#NCBI_COG';
    my $analysisIdentifier;

    my $computeType = 'NCBI_COG';

    if (!exists $analysis_hash->{$doc->{'doc_name'}}->{$computeType}){
	
	&createAnalysisComponent( 'doc'           => $doc,
				  'analysis_hash' => $analysis_hash,
				  'compute_type'  => $computeType );
    }


    foreach my $ev_type (sort keys %{$data_hash} ) {

	foreach my $feat_name (sort keys %{$data_hash->{$ev_type}} ){
	    
	    foreach my $accession (sort keys %{$data_hash->{$ev_type}->{$feat_name}} ){

		foreach my $key (sort keys %{$data_hash->{$ev_type}->{$feat_name}->{$accession}} ){
		    

		    my $tmphash = $data_hash->{$ev_type}->{$feat_name}->{$accession}->{$key};


		    my $refseq = &get_uniquename($prism,
						 $database,
						 $asmbl_id,
						 $feat_name,
						 'polypeptide');

		    my $compseq = $accession;
		    
		    # determine if the query name and the dbmatch name are a unique pair in the document
		    
		    my $alignment_pair_list = BSML::BsmlDoc::BsmlReturnAlignmentLookup(
										       $refseq,
										       $compseq
										       );
		    my $alignment_pair;
		    if( $alignment_pair_list ){
			$alignment_pair = $alignment_pair_list->[0];
		    }

		    if (!defined($alignment_pair)) {

			## No <Seq-pair-alignment> pair matches, add a new alignment pair and sequence run
			
			## Check to see if sequences exist in the BsmlDoc, if not add them with basic attributes

			my $bsmlSequenceRefSeq = $doc->returnBsmlSequenceByIDR( $refseq);
			
			if( !( $bsmlSequenceRefSeq )) {

			    $bsmlSequenceRefSeq = &store_computational_sequence_stub( sequence_id => $refseq,
										      moltype     => 'aa',
										      class       => 'polypeptide',
										      genome_id   => $genome_id,
										      doc         => $doc,
										      identifier  => $feat_name,
										      database    => $prefix
										      );
			}
		
			## Need to store //Link/@role for each Sequence's analysis (bug 2273).
			&addSequenceAnalysisLink( $doc,
						  $bsmlSequenceRefSeq,
						  $computeType,
						  'input_of',
						  $sequence_analysis_link,
						  $refseq
						  );

			my $bsmlSequenceCompSeq = $doc->returnBsmlSequenceByIDR( $compseq );
	
			if( !( $bsmlSequenceCompSeq )) {
			    
			    #
			    # If the Sequence stub represents an COG accession that start with PFAM
			    # //Sequence//Cross-reference/@database   = 'PFAM'
			    # //Sequence//Cross-reference/@identifier = evidence.feat_name
			    #
			    # else if the Sequence stub represents an COG accession that starts with TIGRFAM
			    # //Sequence//Cross-reference/@database   = 'TIGRFAM'
			    # //Sequence//Cross-reference/@identifier = evidence.feat_name
			    # 
			    #

			    ## Set default
			    my $compseq_db = $prefix;

			    ## Check for more accurate/appropriate database
			    foreach my $compDbType ( keys %{$computeDatabaseLookup} ) { 

				if ($compseq =~ /^$compDbType/) {
				    $compseq_db = $computeDatabaseLookup->{$compDbType};
				    last;
				}
			    }

			    $bsmlSequenceCompSeq = &store_computational_sequence_stub( sequence_id => $compseq,
										       moltype     => 'aa',
										       class       => 'polypeptide',
										       doc         => $doc,
										       identifier  => $compseq,
										       database    => $compseq_db
										       );
 			}

			## Need to store //Link/@role for each Sequence's analysis (bug 2273).
			&addSequenceAnalysisLink( $doc,
						  $bsmlSequenceCompSeq,
						  $computeType,
						  'input_of',
						  $sequence_analysis_link,
						  $compseq
						  );
			


			##--------------------------------------------------------------------------------------
			## Create <Seq-pair-alignment> and store attributes
			##
			##--------------------------------------------------------------------------------------
			$alignment_pair = $doc->returnBsmlSeqPairAlignmentR( $doc->addBsmlSeqPairAlignment() );
			
			if (!defined($alignment_pair)){

			    $logger->logdie("Could not create <Seq-pair-alignment> element object reference");
			}
			else {
			    
			    $alignment_pair->setattr( 'refseq',  $refseq  );
			    $alignment_pair->setattr( 'compseq', $compseq );
			    $alignment_pair->setattr( 'class',   $class   );
			}


			## Link the Seq-pair-alignment to the particular Analysis (bug 2172)
			my $link_elem = $doc->createAndAddLink(
							       $alignment_pair,  # <Seq-pair-alignment> element object reference
							       'analysis',       # rel
							       '#NCBI_COG',      # href
							       'computed_by'     # role
							       );

			$logger->logdie("Could not create an 'analysis' <Link> element object reference for <Seq-pair-alignment>") if (!defined($link_elem));
			#
			#-------------------------------------------------------------------------------------------------------------------------


			#
			# Store reference to the <Seq-pair-alignment>
			#
			BSML::BsmlDoc::BsmlSetAlignmentLookup( $refseq, $compseq, $alignment_pair );
			
		    }

		    my $seq_run = &store_seq_pair_run_attributes( $alignment_pair, $tmphash, $doc );

		}		
		
	    }    
	}
    }
}# sub store_cog_evidence_data

#----------------------------------------------------------------------------------------
# Evidence
# PROSITE Evidence Encoding
#
#----------------------------------------------------------------------------------------
sub store_prosite_evidence_data { 

    my %p = @_;
    my $doc            = $p{'doc'};
    my $asmbl_id       = $p{'asmbl_id'};
    my $data_hash      = $p{'data_hash'};
    my $database       = $p{'database'};
    my $docname        = $p{'docname'};
    my $prefix         = $p{'prefix'};
    my $analysis_hash  = $p{'analysis_hash'};
    my $genome_id      = $p{'genome_id'};
    my $sequence_analysis_link = $p{'sequence_analysis_link'};

    my $class = 'match';
    my $href  = '#PROSITE';

    my $computeType = 'PROSITE';

    if (!exists $analysis_hash->{$doc->{'doc_name'}}->{$computeType}){

	&createAnalysisComponent( 'doc'           => $doc,
				  'analysis_hash' => $analysis_hash,
				  'compute_type'  => $computeType );	
    }

    foreach my $ev_type (sort keys %{$data_hash} ) {

	foreach my $feat_name (sort keys %{$data_hash->{$ev_type}} ){
	    
	    foreach my $accession (sort keys %{$data_hash->{$ev_type}->{$feat_name}} ){

		foreach my $key (sort keys %{$data_hash->{$ev_type}->{$feat_name}->{$accession}} ){
		    
		    my $tmphash = $data_hash->{$ev_type}->{$feat_name}->{$accession}->{$key};

		    my $refseq = &get_uniquename($prism,
						 $database,
						 $asmbl_id,
						 $feat_name,
						 'polypeptide');

		    my $compseq = $accession;
		    
		    # determine if the query name and the dbmatch name are a unique pair in the document
		    
		    my $alignment_pair_list = BSML::BsmlDoc::BsmlReturnAlignmentLookup(
										       $refseq,
										       $compseq
										       );
		    my $alignment_pair;
		    if( $alignment_pair_list ){
			$alignment_pair = $alignment_pair_list->[0];
		    }

		    if (!defined($alignment_pair)) {

			## No <Seq-pair-alignment> pair matches, add a new alignment pair and sequence run
			
			## Check to see if sequences exist in the BsmlDoc, if not add them with basic attributes
			
			my $bsmlSequenceRefSeq = $doc->returnBsmlSequenceByIDR( $refseq);


			if( !( $bsmlSequenceRefSeq)){
			    
			    $bsmlSequenceRefSeq = &store_computational_sequence_stub( sequence_id => $refseq,
										      moltype     => 'aa',
										      class       => 'polypeptide',
										      genome_id   => $genome_id,
										      doc         => $doc,
										      identifier  => $feat_name,
										      database    => $prefix
										      );
			}

			## Need to store //Link/@role for each Sequence's analysis (bug 2273).
			&addSequenceAnalysisLink( $doc,
						  $bsmlSequenceRefSeq,
						  $computeType,
						  'input_of',
						  $sequence_analysis_link,
						  $refseq
						  );



			my $bsmlSequenceCompSeq = $doc->returnBsmlSequenceByIDR( $compseq );

			if( !( $bsmlSequenceCompSeq)) {

			    ## Set default
			    my $compseq_db = $prefix;
			    
			    ## Check for more accurate/appropriate database
			    foreach my $compDbType ( keys %{$computeDatabaseLookup} ) { 

				if ($compseq =~ /^$compDbType/) {
				    $compseq_db = $computeDatabaseLookup->{$compDbType};
				    last;
				}
				## Note that this specific type of check is no longer being performed
				## if ($compseq =~ /^PS\d+$/){
			    }

			    $bsmlSequenceCompSeq = &store_computational_sequence_stub( sequence_id => $compseq,
										       moltype     => 'aa',
										       class       => 'polypeptide',
										       doc         => $doc,
										       identifier  => $compseq,
										       database    => $compseq_db
										       );
			}

			## Need to store //Link/@role for each Sequence's analysis (bug 2273).
			&addSequenceAnalysisLink( $doc,
						  $bsmlSequenceCompSeq,
						  $computeType,
						  'input_of',
						  $sequence_analysis_link,
						  $compseq
						  );

			##--------------------------------------------------------------------------------------
			## Create <Seq-pair-alignment> and store attributes
			##
			##--------------------------------------------------------------------------------------	      
			$alignment_pair = $doc->returnBsmlSeqPairAlignmentR( $doc->addBsmlSeqPairAlignment() );
			
			if (!defined($alignment_pair)){

			    $logger->logdie("Could not create <Seq-pair-alignment> element object reference");
			}
			else {
			    $alignment_pair->setattr( 'refseq',  $refseq  );
			    $alignment_pair->setattr( 'compseq', $compseq );
			    $alignment_pair->setattr( 'class',   $class   );
			}

			## Link the Seq-pair-alignment to the particular Analysis (bug 2172)
			my $link_elem = $doc->createAndAddLink(
							       $alignment_pair,  # <Seq-pair-alignment> element object reference
							       'analysis',       # rel
							       '#PROSITE',       # href
							       'computed_by'     # role
							       );
			
			$logger->logdie("Could not create an 'analysis' <Link> element object reference for <Seq-pair-alignment>") if (!defined($link_elem));


			#
			# Store reference to the <Seq-pair-alignment>
			#
			BSML::BsmlDoc::BsmlSetAlignmentLookup( $refseq, $compseq, $alignment_pair );
			
		    }


		    my $seq_run = &store_seq_pair_run_attributes( $alignment_pair, $tmphash, $doc );

		    
		    if ((exists $tmphash->{'residues'}) && (defined($tmphash->{'residues'}))){
			
			my $attribute_elem = $doc->createAndAddBsmlAttribute(
									     $seq_run,
									     'residues',
									     "$tmphash->{'residues'}"
									     );
			
			$logger->logdie("Could not create <Attribute> for the name 'residues' content '$tmphash->{'residues'}'") if (!defined($attribute_elem));
		    }
		    

		}		
		
	    }    
	}
    }
}





#-------------------------------------------------------------------------------------------------
# Write bsml document to outdir
#
#-------------------------------------------------------------------------------------------------
sub write_out_bsml_doc {

    my ($doc) = @_;

    my $bsmldocument = $doc->{'doc_name'};

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
	
    $doc->write("$bsmldocument");
    	
	
    if(! -e "$bsmldocument"){
	$logger->logdie("File not created '$bsmldocument'");
    }
    else {
	chmod (0777, "$bsmldocument");
    }

}
	
sub create_multifasta {

    my ($asmbl_id, $fastadir, $db, $sequence) = @_;

    my $modelList = $prism->{_backend}->getModels($asmbl_id);
    if (!defined($modelList)){
	$logger->logdie("Could not retrieve model list for asmbl_id '$asmbl_id'");
    }

    my $cdsCollection = $prism->retrieveCDSCollectionByAssemblyIdentifier(id=>$asmbl_id);
    if (!defined($cdsCollection)){
	$logger->logdie("Could not retrieve CDS collection for asmbl_id '$asmbl_id'");
    }

    my $deriver = new Annotation::SequenceDeriver(cds_collection => $cdsCollection,
						  model_collection => $modelList,
						  asmbl_id => $asmbl_id,
						  project  => $db,
						  sequence => \$sequence,
						  prism=>$prism,
						  fastadir => $fastadir);
    if (!defined($deriver)){
	$logger->logdie("Could not instantiate Annotation::SequenceDeriver");
    }

    $deriver->writeFile();
}

sub createFASTAFilesForProks {

    my ($fastasequences, $fastadir, $db) = @_;

    foreach my $asmbl_id (sort keys %{$fastasequences} ){ 

	foreach my $seqtype (sort keys %{$fastasequences->{$asmbl_id}}){
	    
	    my $fastafile = $fastadir . "/" . $db . '_' . $asmbl_id . '_' .  $seqtype . ".fsa";
	    
	    #
	    # If multi-fasta file already exists, let's back it up...
	    #
	    if (-e $fastafile){

		## Default behavior is to NOT backup files (bug 2052)
		if (defined($backup)){

		    my $fastabak = $fastafile . '.bak';
		    copy($fastafile, $fastabak);
		    $logger->info("Copying '$fastafile' to '$fastabak'");
		}
	    }

	    open (FASTA, ">$fastafile") or $logger->logdie("Can't open file $fastafile for writing: $!");


	    foreach my $sequence ( @{$fastasequences->{$asmbl_id}->{$seqtype}} ) {
	
		my $fastaout = &fasta_out($sequence->[0], $sequence->[1]);
		print FASTA $fastaout;
	
	    }

	    close FASTA;
	    chmod 0666, $fastafile;
	}
    }



}

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

sub getFeatNameForCDSId {

    my ($id) = @_;

    if (! exists $prism->{'_old_id_mapping_lookup'}->{$id}){
	$logger->fatal("old_id_mapping_lookup:". Dumper $prism->{_old_id_mapping_lookup});
	$logger->fatal("id_mapping_lookup:" . Dumper $prism->{_id_mapping_lookup});
	$logger->logdie("id '$id' does not exist in the ID mapping lookup!");
    }

    my $oldid = $prism->{'_old_id_mapping_lookup'}->{$id};

    if ($id =~ /polypeptide/){
	$oldid =~ s/\.p/\.m/;
    }

    if ($oldid =~ /^\S+_\d+_(\d+\.\S+)_\S+$/){

	my $feat_name = $1;

	return $feat_name;

    } else {

	$logger->logdie("Unable to parse oldid '$oldid' (was processing new id '$id')");
    }

    return $id;
}


#-------------------------------------------------------- 
# remove_cntrl_chars()
#
#-------------------------------------------------------- 
sub remove_cntrl_chars {

    my ($text) = @_;

    $text =~ tr/\t\n\000-\037\177-\377/\t\n/d; # remove cntrls
    
    return $text;
}



#-------------------------------------------------------- 
# clean_compseq()
#
#-------------------------------------------------------- 
sub clean_compseq {

    my $compseq = shift;

    if ($compseq =~ /^\d/){
	# Found leading digit
	$compseq = '_' . $compseq;
    }

    if ($compseq =~ /[\t\n\000-\037\177-\377]/){
	my ($clean, $garbage) = split(/[\t\n\000-\037\177-\377]/, $compseq);
	$logger->warn("compseq '$compseq' was stripped of garbage '$garbage'");

	$compseq = $clean;
    }

    return $compseq;
}



#---------------------------------------------------------------------------------------
# create_euk_gene_model_lookup()
#
#---------------------------------------------------------------------------------------
sub create_euk_gene_model_lookup {
 
    my ($prism, $asmbl_id, $qualified_tu_lookup, $tu_list_file, $qualified_model_lookup, $model_list_file, $database) = @_;

    # this code corresponds to euk_prism/euktigr2chado.pl::migrate_transcripts()

    my $feat_exon_ctr = {};

    my $gene_model = {};
  
    my $exon2transcript_rank = {};
    
    #-----------------------------------------
    # retrieve transcript/gene related data
    #-----------------------------------------
    my $transcripts = $prism->transcripts($asmbl_id, $qualified_tu_lookup, $tu_list_file);
    if (!defined($transcripts)){
	$logger->warn("No TUs were retrieve from database '$database' asmbl_id '$asmbl_id'");
	return (undef, undef);
    }

    #-------------------------------------------
    # retrieve model (CDS/polypeptide) related data
    #-------------------------------------------
    my($model_lookup) = {};

    my $coding_regions = $prism->coding_regions($asmbl_id, $qualified_model_lookup, $model_list_file);
    $logger->logdie("coding_regions was not defined") if (!defined($coding_regions));

    ## Keep track of all model feat_name values (bug 2045)
    my $model_feat_names = {};

    foreach my $model_feat_name ( keys %{$coding_regions} ) {

	if (defined($coding_regions->{$model_feat_name})){ 

	    if(! exists $model_lookup->{$coding_regions->{$model_feat_name}->{'parent_feat_name'}}){
		$model_lookup->{$coding_regions->{$model_feat_name}->{'parent_feat_name'}} = [];
	    }
	    
	    ## Keep track of all model feat_name values (bug 2045)
	    $model_feat_names->{$model_feat_name}++;
	    
	    my $model_ref = $model_lookup->{$coding_regions->{$model_feat_name}->{'parent_feat_name'}};

	    push @$model_ref, $coding_regions->{$model_feat_name};

	    if(! (ref $coding_regions->{$model_feat_name})){ 
		$logger->logdie("Bad reference $coding_regions->{$model_feat_name}");
	    }
	}
    }

    #--------------------------------------
    # retrieve exon related data
    #--------------------------------------
    my($exon_lookup) = {};
    my $exons = $prism->exons($asmbl_id);
    $logger->logdie("exons was not defined") if (!defined($exons));

    for(my $i=0;$i<$exons->{'count'};$i++){	

	if(! exists $exon_lookup->{$exons->{$i}->{'parent_feat_name'}}){
	    $exon_lookup->{$exons->{$i}->{'parent_feat_name'}} = [];
	}

	my $exon_ref = $exon_lookup->{$exons->{$i}->{'parent_feat_name'}};

	push @$exon_ref, $exons->{$i};
    }


    ##
    ## If a model_list_file was provide, then all TU and exon features
    ## not related to qualified models must be removed from the lookups.
    ##
    if (defined($model_list_file)){
	&remove_unqualified_subfeatures($model_lookup, $transcripts, $exon_lookup,
					$qualified_model_lookup, $model_feat_names);
    }
    if (defined($tu_list_file)){
	&remove_unqualified_subfeatures_based_on_tu($model_lookup, $qualified_tu_lookup, $model_feat_names);
    }



    #
    # There must be a better way to get the number of elements...
    #
    my @pu = keys %{$transcripts};
    my $count = scalar(@pu);
    
    push (@{$gene_model->{$asmbl_id}}, { 'transcripts'    => $transcripts,
					 'coding_regions' => $model_lookup,
					 'exons'          => $exon_lookup,
					 'counts'         => $count
				     });
    




    return ($gene_model, $model_feat_names);
}

#---------------------------------------------------------------------------------------------------
# subroutine: do_subfeatures_exist()
#
# The script should not write <Feature-tables> for subfeature-less assemblies (bug 2063).
#
#----------------------------------------------------------------------------------------------------
sub do_subfeatures_exist {

    my %p = @_;


    $logger->info("Checking subfeature counts");

    my $gene_model_hash = $p{'gene_model_hash'};
    my $rnaLookup       = $p{'rnaLookup'};
    my $peptide_hash    = $p{'peptide_hash'};
    my $ribosome_hash   = $p{'ribosome_hash'};
    my $terminator_hash = $p{'terminator_hash'};
    my $gene_finder_hash = $p{'gene_finder_hash'};
    my $misc_feature_lookup = $p{'misc_feature_lookup'};
    my $repeat_feature_lookup = $p{'repeat_feature_lookup'};
    my $transposon_feature_lookup = $p{'transposon_feature_lookup'};
    my $pmark_lookup = $p{'pmark_lookup'};
    my $asmbl_id = $p{'asmbl_id'};

    my $count = 0;


    ## Determine whether there were any gene model subfeatures by
    ## checking the TU counts
    ##
    {
	foreach my $asmbl_id (keys % { $gene_model_hash } ){
	    
	    my @tukeys = (keys %{$gene_model_hash->{$asmbl_id}->[0]->{'transcripts'}});

	    $count += scalar(@tukeys);
	    
	}
    }

    ## The genefinder models will also require the creation of a <Feature-table> element object.
    ## This code verifies whether such an object should be created (bug 2140).

    foreach my $asmbl_id (sort keys % { $gene_finder_hash } ){

	$count += @{$gene_finder_hash->{$asmbl_id}->[0]->{'coding_regions'}};
    }

    $count += scalar(keys %{$rnaLookup}); 

    $count += scalar(keys %{$peptide_hash}); 

    $count += scalar(keys %{$ribosome_hash}); 

    $count += scalar(keys %{$terminator_hash}); 

    if (( exists $misc_feature_lookup->{$asmbl_id}) && 
	( defined($misc_feature_lookup->{$asmbl_id}))) {
	$count += scalar(@{$misc_feature_lookup->{$asmbl_id}}); 
    }


    if (( exists $repeat_feature_lookup->{$asmbl_id}) && 
	( defined($repeat_feature_lookup->{$asmbl_id}))) {
	$count += scalar(@{$repeat_feature_lookup->{$asmbl_id}}); 
    }

    if (( exists $transposon_feature_lookup->{$asmbl_id}) && 
	( defined($transposon_feature_lookup->{$asmbl_id}))) {
	
	$count += scalar(@{$transposon_feature_lookup->{$asmbl_id}}); 
    }

    $count += scalar(keys %{$pmark_lookup}); 

    return $count;

}



#----------------------------------------------------------------------------------------
# sub:  add_analysis_component()
#
# editor:  sundaram@tigr.org
#
# date:    2005-09-09
#
# comment:
#
#----------------------------------------------------------------------------------------
sub add_analysis_component {

    my %p = @_;
    my $doc            = $p{'doc'};
    my $sourcename     = $p{'sourcename'};
    my $analysis_hash  = $p{'analysis_hash'};
    my $analysis_type  = $p{'analysis_type'};
    my $version        = $p{'version'};
    my $program        = $p{'program'};
    my $name           = $p{'name'};
    my $method         = $p{'method'};


    #
    # Retrieve the document name
    #
    my $docname = $doc->{'doc_name'};

   
    if (!exists $analysis_hash->{$doc->{'doc_name'}}->{$analysis_type}){

	my $analysis_elem = $doc->createAndAddAnalysis(
						       'id' => "$analysis_type"
						       );
	
	if (!defined($analysis_elem)){
	    $logger->logdie("Could not create <Analysis> for analysis_type '$analysis_type'");
	}
	else{ 

	    $program = $analysis_type if (!defined($program));
	    $version = 'legacy' if (!defined($version));
	    $name    = $analysis_type if (!defined($name));



	    #
	    # store reference to the <Analysis> element object in the lookup
	    #
	    $analysis_hash->{$doc->{'doc_name'}}->{$analysis_type} = $analysis_elem;



	    #-----------------------------------------------------------------------------------
	    # Add the //Analysis/@program attribute value
	    #
	    #-----------------------------------------------------------------------------------
	    my $program_attribute = $doc->createAndAddBsmlAttribute(
								    $analysis_elem,
								    'program',
								    $program
								    );
	    if (!defined($program_attribute)) {
		$logger->logdie("Could not create <Attribute> for program '$program'");
	    }
	    
	    #-----------------------------------------------------------------------------------
	    # Add the //Analysis/@programversion attribute value
	    #
	    #-----------------------------------------------------------------------------------
	    my $programversion_attribute = $doc->createAndAddBsmlAttribute(
									   $analysis_elem,
									   'version',
									   $version
									   );
	    if (!defined($programversion_attribute)) {
		$logger->logdie("Could not create <Attribute> for programversion '$version'");
	    }

	    #-----------------------------------------------------------------------------------
	    # Add the //Analysis/@sourcename attribute value
	    #
	    #-----------------------------------------------------------------------------------

	    my $sourcename_attribute = $doc->createAndAddBsmlAttribute(
								       $analysis_elem,
								       'sourcename',
								       $sourcename
								       );
	    if (!defined($sourcename_attribute)) {
		$logger->logdie("Could not create <Attribute> for sourcename '$sourcename'");
	    }


	    #-----------------------------------------------------------------------------------
	    # Add the //Analysis/@name attribute value
	    #
	    #-----------------------------------------------------------------------------------
	    my $name_attribute = $doc->createAndAddBsmlAttribute(
							     $analysis_elem,
							     'name',
							     $name
							     );
	    if (!defined($name_attribute)) {
		$logger->logdie("Could not create <Attribute> for name '$name'");
	    }



	    #-----------------------------------------------------------------------------------
	    # Add the //Analysis/@method attribute value
	    #
	    #-----------------------------------------------------------------------------------
	    my $method_attribute = $doc->createAndAddBsmlAttribute(
							     $analysis_elem,
							     'method',
							     $method
							     );
	    if (!defined($method_attribute)) {
		$logger->logdie("Could not create <Attribute> for method '$method'");
	    }

	}
    }

    return $analysis_type;
}


#---------------------------------------------------------------------------------------
# create_gene_finder_lookup()
#
#---------------------------------------------------------------------------------------
sub create_gene_finder_lookup {
 
    my ($prism, $asmbl_id, $exclude_genefinder, $include_genefinder) = @_;

    my $feat_exon_ctr = {};

    my $gene_finder_lookup = {};


    my ($exclude_genefinder_hash, @include_genefinder_list);
    
    if (defined($exclude_genefinder)){
	$exclude_genefinder =~ s/\s+//g;
	my @tmp_list = split(/,/, $exclude_genefinder);

	#
	# Build the exclusion hash
	#
	foreach my $ex ( @tmp_list ){
	    
	    $exclude_genefinder_hash->{$ex} = $ex;
	}
    }
    
    if (defined($include_genefinder)){
	$include_genefinder =~ s/\s+//g;
	@include_genefinder_list = split(/,/, $include_genefinder);
    }





    #-------------------------------------------
    # retrieve model (CDS/polypeptide) related data
    #-------------------------------------------
    my($model_lookup) = {};
    my $coding_regions = $prism->gene_finder_models($asmbl_id, $exclude_genefinder_hash, \@include_genefinder_list);
    $logger->logdie("coding_regions was not defined") if (!defined($coding_regions));

    
    #--------------------------------------
    # retrieve exon related data
    #--------------------------------------
    my($exon_lookup) = {};
    my $exons = $prism->gene_finder_exons($asmbl_id, $exclude_genefinder_hash, \@include_genefinder_list);
    $logger->logdie("exons was not defined") if (!defined($exons));


    for(my $i=0;$i<$exons->{'count'};$i++){	
	if(! exists $exon_lookup->{$exons->{$i}->{'parent_feat_name'}}){
	    $exon_lookup->{$exons->{$i}->{'parent_feat_name'}} = [];
	}
	my $exon_ref = $exon_lookup->{$exons->{$i}->{'parent_feat_name'}};
	push @$exon_ref, $exons->{$i};
    }

    #
    # There must be a better way to get the number of elements...
    #
    my $count = scalar(@{$coding_regions});

    

    push (@{$gene_finder_lookup->{$asmbl_id}}, { 'coding_regions' => $coding_regions,#model_lookup,
						 'exons'          => $exon_lookup,
						 'counts'         => $count
					     });



    return ($gene_finder_lookup);
}


################################################################################################################
#                                                                                                              #
# subroutine: store_euk_gene_finder_subfeatures()                                                              #
#                                                                                                              #
# editor:     sundaram@tigr.org                                                                                #
#                                                                                                              #
# date:       2005-09-14                                                                                       #
#                                                                                                              #
#                                                                                                              # 
#                                                                                                              # 
#                                                                                                              # 
#                                                                                                              # 
#                                                                                                              # 
#                                                                                                              # 
#                                                                                                              # 
#                                                                                                              # 
#                                                                                                              # 
#                                                                                                              # 
################################################################################################################
sub store_euk_gene_finder_subfeatures {

    my %param = @_;
    my $datahash           = $param{'datahash'};
    my $asmbl_id           = $param{'asmbl_id'};
    my $feature_table_elem = $param{'feature_table_elem'};
    my $doc                = $param{'doc'};
    my $prefix             = $param{'prefix'};
    my $database           = $param{'database'};
    my $assembly_sequence_elem     = $param{'assembly_sequence_elem'};
    my $accession_hash             = $param{'accession_lookup'};
    my $gene_group_lookup          = $param{'gene_group_lookup'};
    my $transcript_feature_hash    = $param{'transcript_feature_hash'};
    my $polypeptide_feat_name_to_locus = $param{'polypeptide_feat_name_to_locus'};
    my $seq_data_import_hash       = $param{'seq_data_import_hash'};
    my $identifier_feature         = $param{'identifier_feature'};
    my $outdir                     = $param{'outdir'};
    my $analysis_hash              = $param{'analysis_hash'};
    my $transcript_mapper          = $param{'transcript_mapper'};
    my $coding_regions             = $param{'coding_regions'};
    my $exons                      = $param{'exons'};


    my $genestored = 0;
    my $transcript_lookup = {};
    my $model_counter = {};


    my $genie = {};


    
    foreach my $model ( @{$coding_regions} ){

	my $feat_name = $model->{'feat_name'};


	## Should only encounter the model one time
	if (!exists $model_counter->{$feat_name}){
	    $model_counter->{$feat_name}++;
	}
	else{
	    $logger->logdie("Encountered model feat_name '$feat_name' $model_counter->{$feat_name} times");
	}


	## Extract the ev_type
	my $ev_type;
	if ((exists $model->{'ev_type'}) && (defined($model->{'ev_type'}))){
	    
	    $ev_type = $model->{'ev_type'};
	    
	}
	else{
	    $logger->logdie("ev_type was not defined for model '$feat_name'");
	}


	## We need to create a placeholder transcript to conform to our gene structure model
	## generate the transcript uniquename using the model's feat_name and the ev_type
	my $transcript_uniquename =  &get_uniquename($prism,
						     $database,
						     $asmbl_id,
						     $feat_name . '_' . $ev_type,
						     'transcript');
	

	my ($transcript_feature_group_elem, $w) = &store_euk_subfeature( # store the transcript as a feature
									 'transcript_uniquename'   => $transcript_uniquename,
									 'data'                    => $model,
									 'class'                   => 'transcript',
									 'assembly_seq'            => $assembly_sequence_elem,
									 'gene_group_lookup'       => $gene_group_lookup,
									 'asmbl_id'                => $asmbl_id,
									 'prefix'                  => $prefix,
									 'doc'                     => $doc,
									 'feature_table_elem'      => $feature_table_elem,
									 'transcript_feature_hash' => $transcript_feature_hash,
									 'polypeptide_feat_name_to_locus' => $polypeptide_feat_name_to_locus,
									 'accession_hash'             => $accession_hash,
									 'seq_data_import_hash'       => $seq_data_import_hash,
									 'identifier_feature'         => $identifier_feature,
									 'ev_type'                    => $ev_type,
									 'outdir'                     => $outdir,
									 'analysis_hash'              => $analysis_hash										 
									 );	
		
	$logger->logdie("transcript_feature_group_elem was not defined for transcript '$transcript_uniquename'") if (!defined($transcript_feature_group_elem));

	## Want to ensure that the gene is only stored once.  The following code creates a value which
	## satisfies the algorithm in store_euk_subfeature() which guarantees that the gene only gets inserted
	## one time (especially in light of alternatively spliced isoforms).
	if (( exists $genie->{$transcript_uniquename}) && (defined($genie->{$transcript_uniquename}))){

	    $genestored = $genie->{$transcript_uniquename};
	    $genie->{$transcript_uniquename}++;

	}
	else {

	    $genie->{$transcript_uniquename} = 0;
	    $genestored = 0;
	    
	}


	($transcript_feature_group_elem, $genestored) = &store_euk_subfeature( # store the gene as a feature
									       'data'               => $model,
									       'class'              => 'gene',
									       'assembly_seq'       => $assembly_sequence_elem,
									       'gene_group_lookup'  => $gene_group_lookup,
									       'asmbl_id'           => $asmbl_id,
									       'prefix'             => $prefix,
									       'doc'                => $doc,
									       'feature_table_elem' => $feature_table_elem,
									       'transcript_feature_group_elem' => $transcript_feature_group_elem,
									       'genestored'         => $genestored,
									       'transcript_uniquename'   => 'UNDEF',
									       'transcript_feature_hash' => $transcript_feature_hash,
									       'polypeptide_feat_name_to_locus' => $polypeptide_feat_name_to_locus,
									       'accession_hash'             => $accession_hash,
									       'seq_data_import_hash'       => $seq_data_import_hash,
									       'identifier_feature'         => $identifier_feature,
									       'ev_type'                    => $ev_type,
									       'outdir'                     => $outdir,
									       'analysis_hash'              => $analysis_hash								       
									       );
	
	
	&store_euk_subfeature( # store the CDS as a feature
			       'data'                    => $model,
			       'class'                   => 'CDS',
			       'assembly_seq'            => $assembly_sequence_elem,
			       'gene_group_lookup'       => $gene_group_lookup,
			       'asmbl_id'                => $asmbl_id,
			       'prefix'                  => $prefix,
			       'doc'                     => $doc,
			       'feature_table_elem'      => $feature_table_elem,
			       'transcript_feature_group_elem' => $transcript_feature_group_elem,
			       'transcript_uniquename'         => 'UNDEF',
			       'transcript_feature_hash'       => $transcript_feature_hash,
			       'polypeptide_feat_name_to_locus'    => $polypeptide_feat_name_to_locus,
			       'accession_hash'                => $accession_hash,
			       'seq_data_import_hash'          => $seq_data_import_hash,
			       'identifier_feature'            => $identifier_feature,
			       'ev_type'                       => $ev_type,
			       'outdir'                        => $outdir,
			       'analysis_hash'                 => $analysis_hash
			       );
	

	my $polypeptide_feat_name = $model->{'feat_name'};
	$polypeptide_feat_name =~ s/\.m/\.p/;
	
	&store_euk_subfeature( # store the polypeptide as a feature
			       'feat_name'               => $polypeptide_feat_name,
			       'data'                    => $model,
			       'class'                   => 'polypeptide',
			       'assembly_seq'            => $assembly_sequence_elem,
			       'gene_group_lookup'       => $gene_group_lookup,
			       'asmbl_id'                => $asmbl_id,
			       'prefix'                  => $prefix,
			       'doc'                     => $doc,
			       'feature_table_elem'      => $feature_table_elem,
			       'transcript_feature_group_elem' => $transcript_feature_group_elem,
			       'transcript_uniquename'      => 'UNDEF',
			       'transcript_feature_hash'    => $transcript_feature_hash,
			       'polypeptide_feat_name_to_locus' => $polypeptide_feat_name_to_locus,
			       'accession_hash'             => $accession_hash,
			       'seq_data_import_hash'       => $seq_data_import_hash,
			       'identifier_feature'         => $identifier_feature,
			       'ev_type'                    => $ev_type,
			       'outdir'                     => $outdir,
			       'analysis_hash'              => $analysis_hash
			       );
	
	
	if ((exists $exons->{$model->{'feat_name'}}) && (defined($exons->{$model->{'feat_name'}}))){
		    
	    foreach my $exon ( @{$exons->{$model->{'feat_name'}}} ) {
		
		
		&store_euk_subfeature( # store the exon as a feature
				       'data'                    => $exon,
				       'class'                   => 'exon',
				       'assembly_seq'            => $assembly_sequence_elem,
				       'gene_group_lookup'       => $gene_group_lookup,
				       'asmbl_id'                => $asmbl_id,
				       'prefix'                  => $prefix,
				       'doc'                     => $doc,
				       'feature_table_elem'      => $feature_table_elem,
				       'transcript_feature_group_elem' => $transcript_feature_group_elem,
				       'transcript_uniquename'      => 'UNDEF',				       
				       'transcript_feature_hash'    => $transcript_feature_hash,
				       'polypeptide_feat_name_to_locus' => $polypeptide_feat_name_to_locus,
				       'accession_hash'             => $accession_hash,
				       'seq_data_import_hash'       => $seq_data_import_hash,
				       'identifier_feature'         => $identifier_feature,
				       'ev_type'                    => $ev_type,
				       'outdir'                     => $outdir,
				       'analysis_hash'              => $analysis_hash
				       );
	    }
	}
	else{
	    $logger->info("No exons associated to the model '$model->{'feat_name'}' for genefinders");
	}    
    }			   
}



#-----------------------------------------------------------------------------------------------------------
# subroutine:  create_euk_polypeptide_orf_attributes_lookup()
# 
#
# input:       prism object reference, array reference (list of asmbl_ids), scalar (database name)
#
# output:      none
#
# return:      hash reference (models and MW, pI ORF_attributes)
#
# comment:     In the legacy annotation databases, the MW and PI ORF_attributes are 
#              associated with the models.
#
#
#------------------------------------------------------------------------------------------------------------
sub create_euk_polypeptide_orf_attributes_lookup {

   my ($prism, $asmbl_id, $database, $alt_database) = @_;

   my $rethash = {};

   my $idatabase = $database;
   if (defined($alt_database)){
       $idatabase = $alt_database;
   }
   
   foreach my $att_type ('MW', 'PI'){
       
       #
       # It is assumed that all ORF_attributes are associated to the model and not the TU.
       #
       my $ret = $prism->gene_orf_attributes($asmbl_id, $database, 'model', $att_type);


       foreach my $block ( @{$ret} ){

	   my $transcript = &get_uniquename($prism,
					    $idatabase,
					    $asmbl_id,
					    $block->[1],
					    'polypeptide');


	   if ((defined($block->[3])) && ($block->[3] !~ /^\s+$/)){

	       if (($block->[2] eq 'MW') or ($block->[2] eq 'PI')){

		   if ($block->[2] eq 'PI'){
		       $block->[2] = 'pI';
		   }
		   

		   push ( @{$rethash->{$transcript}->{'attributes'}}, { name    => $block->[2],
									content => $block->[3]
								    });

	       }
	   }
	   else{
	       #
	       # No value was in feat_score.score
	       #
	       next;
	   }
       }
   }

   return ($rethash);
       
}



#------------------------------------------------------------------------------------------------------------------------------------------
# subroutine:  process_polypeptide_orf_attribute_data()
# 
#
#
# input:       hash reference (polypeptide feature object reference lookup), hash reference (ORF_attributes lookup),
#              BsmlDoc object reference
#
# output:      none
#
# return:      none
#
# comment:     In BSML and chado, the ORF_attributes MW, pI, LP, OMP are associated with the polypeptides.
#
#------------------------------------------------------------------------------------------------------------------------------------------
sub process_polypeptide_orf_attribute_data {

    my %p = @_;
 
    my $polypeptide_feature_hash  = $p{'polypeptide_feature_hash'};
    my $orf_attributes_hash       = $p{'orf_attributes_hash'};
    my $doc                       = $p{'doc'};


    foreach my $polypeptide (sort keys %{$polypeptide_feature_hash} ){
	

	# Given the protein name, convert to the corresponding model name.
	# This is necessary since the MW, pI, LP, OMP ORF_attributes are associated with the 
	# models in the legacy annotation databases.
	#
	if (( exists $polypeptide_feature_hash->{$polypeptide}) && (defined($polypeptide_feature_hash->{$polypeptide})) ) {
	    
	    if (( exists $orf_attributes_hash->{$polypeptide}->{'attributes'}) && (defined($orf_attributes_hash->{$polypeptide}->{'attributes'})) ){

		if ( scalar(@{$orf_attributes_hash->{$polypeptide}->{'attributes'}}) > 0 ) {

		    my $polypeptide_feature_elem = $polypeptide_feature_hash->{$polypeptide};

		    foreach my $attribute ( @{$orf_attributes_hash->{$polypeptide}->{'attributes'}} ){
	

			if (( exists $attribute->{'content'}) && (defined($attribute->{'content'})) ) {

			    my $value = $attribute->{'content'};
			    #
			    # Strip trailing whitespaces
			    #
			    $value =~ s/\s+$//;
	
			    if ($attribute->{name} eq 'VIR_PMID'){

				my $list=[];
				push(@{$list}, { name => 'GO', content=>'GO:0009405'} );
				push(@{$list}, { name => 'ND', content=>"PMID:$attribute->{content}"} );
				$polypeptide_feature_elem->addBsmlAttributeList($list);

			    } else {

				my $attribute_elem = $doc->createAndAddBsmlAttribute(
										     $polypeptide_feature_elem,   # elem
										     $attribute->{'name'},        # key
										     $value                       # value
										     );

				if (!defined($attribute_elem)){
				    $logger->logdie("Could not create <Attribute> element ".
						    "object reference for orf_attribute ".
						    "'$attribute' value '$attribute->{$attribute}' ".
						    "for polypeptide '$polypeptide'");
				}
			    } 
			} else {
			    $logger->logdie("The content for this attribute name ".
					    "'$attribute->{'name'}' polypeptide ".
					    "'$polypeptide' was not defined");
			}
		    }
		}
		else {
		    $logger->warn("Found null array reference for polypeptide '$polypeptide' attributes");
		}
	    }
	    else {
#		$logger->warn("polypeptide '$polypeptide' did not have any ORF_attributes");
	    }
	}
	else {
	    $logger->logdie("Feature object reference was not defined for polypeptide '$polypeptide'");
	}

    }

} #end sub

sub processLipoMembraneProteinLookup {

    my ($polypeptide_feature_hash, $lipoMembraneProteinLookup, $doc, $prism, $database, $asmbl_id) = @_;

    my $missingCtr=0;
    my $missingList=[];
    my $foundCtr=0;
    my $totalCtr=0;

    foreach my $feat_name ( keys %{$lipoMembraneProteinLookup}){

	$totalCtr++;
	
	my $id = &get_uniquename($prism,
				 $database,
				 $asmbl_id,
				 &cleanse_uniquename($feat_name),
				 'polypeptide');
	if (!defined($id)){
	    $logger->logdie("Could not get id for database '$database' ".
			    "asmbl_id '$asmbl_id' feat_name '$feat_name' ".
			    "class 'polypeptide'");
	}

	if (( exists $polypeptide_feature_hash->{$id} ) && 
	    ( defined($polypeptide_feature_hash->{$id} )) ) {
	    
	    my $value = $lipoMembraneProteinLookup->{$id};
	    
	    ## Strip trailing whitespaces
	    $value =~ s/\s+$//;

	    my $attributeBsmlElement = $doc->createAndAddBsmlAttribute( $polypeptide_feature_hash->{$id}, # elem
									'lipo_membrane_protein',    # key
									$value                      # value
									);

	    if (!defined($attributeBsmlElement)){
		$logger->logdie("Could not create <Attribute> element ".
				"object with name 'lipo_membrane_protein' ".
				"content '$value' for polypeptide with ".
				"id '$id'");
	    }

	    $foundCtr++;

	} else {
	    $missingCtr++;
	    push(@{$missingList}, $feat_name);
	    next;
	}
    }

    if ($missingCtr > 0 ){
	$logger->warn("While processing lipo_membrane_protein data, ".
		      "encountered '$missingCtr' polypeptides whose ".
		      "id values did not exist in the polypeptide ".
		      "lookup.  Here are their corresponding feat_name ".
		      "values:" . join(' ', @{$missingList}) . 
		      ".  The lipo_membrane_protein data for these ".
		      "could not be transferred to the BSML.");
    }


    print "Successfully processed '$foundCtr' out of '$totalCtr' ".
    "lipo_membrane_protein records\n";
}

#------------------------------------------------------------------------------------------------------------------------------------------
# subroutine:  process_prok_cds_orf_attribute_data()
# 
#
# input:       hash reference (CDS feature object reference lookup), hash reference (ORF_attributes lookup),
#              BsmlDoc object reference
#
# output:      none
#
# return:      none
#
# comment:     In BSML and chado, the ORF_attribute GC is associated with the CDS features.
#
#------------------------------------------------------------------------------------------------------------------------------------------
sub process_prok_cds_orf_attribute_data {

    my %p = @_;
 
    my $cds_feature_hash      = $p{'cds_feature_hash'};
    my $orf_attributes_hash   = $p{'orf_attributes_hash'};
    my $doc                   = $p{'doc'};


    foreach my $cds (sort keys %{$cds_feature_hash} ){
	
	
	if (( exists $cds_feature_hash->{$cds}) && (defined($cds_feature_hash->{$cds})) ) {
	    

	    my $cds_feature_elem = $cds_feature_hash->{$cds};

	    
	    if (( exists $orf_attributes_hash->{$cds}->{'attributes'}) && (defined($orf_attributes_hash->{$cds}->{'attributes'})) ){


		if ( scalar(@{$orf_attributes_hash->{$cds}->{'attributes'}}) > 0 ) {

		    foreach my $attribute ( @{$orf_attributes_hash->{$cds}->{'attributes'}} ){
	

			if (( exists $attribute->{'content'}) && (defined($attribute->{'content'})) ) {

			    my $value = $attribute->{'content'};
			    #
			    # Strip trailing whitespaces
			    #
			    $value =~ s/\s+$//;
	
			    my $attribute_elem = $doc->createAndAddBsmlAttribute(
										 $cds_feature_elem,     # elem
										 $attribute->{'name'},  # key
										 $value                 # value
										 );

	
			    $logger->logdie("Could not create <Attribute> element object reference for orf_attribute '$attribute' value '$attribute->{$attribute}' for cds '$cds'") if (!defined($attribute_elem));
			}
			else {
			    $logger->logdie("The content for this attribute name '$attribute->{'name'}' cds '$cds' was not defined");
			}
		    }
		}
		else {
		    $logger->warn("Found null array reference for cds '$cds' attributes");
		}
	    }
	    else {
#		$logger->warn("cds '$cds' did not have any ORF_attributes");
	    }
	}
	else {
	    $logger->logdie("Feature object reference was not defined for cds '$cds'");
	}

    }

} #end sub


		



#--------------------------------------------------------------------------------------------------------------
# subroutine:  create_prok_cds_orf_attributes_lookup()
#
#
# input:       Prism object reference, array reference (list of asmbl_ids), scalar (database name)
#              scalar (flag whether prok or ntprok)
#
# output:      none
#
# return:      hash reference (GC ORF_attributes associated to models)
#
# comment:     In BSML and chado we will associate the GC/percent_GC with the CDS features.
#              In the legacy annotation databases, these ORF_attributes are associated with 
#              the models.  Sad, but true.
#
#
#-------------------------------------------------------------------------------------------------------------
sub create_prok_cds_orf_attributes_lookup {

   my ($prism, $asmbl_id, $database, $alt_database, $schemaType) = @_;
   

   my $rethash = {};
   
   my $att_type = 'GC';

   my $ret = $prism->gene_orf_attributes($asmbl_id,
					 $database,
					 $prokSchemaTypeToFeature->{$schemaType},
					 $att_type);

   if (!defined($alt_database)){
       $alt_database = $database;
   }
   

   foreach my $block ( @{$ret} ){
       
       my $cds = &get_uniquename($prism,
				 $alt_database,
				 $asmbl_id,
				 $block->[1],
				 'CDS');


       if ((defined($block->[3])) && ($block->[3] !~ /^\s+$/)){
	   
	   if ( exists $prokCdsOrfAttributeAttTypes->{$block->[2]} ) {
	       
	       push ( @{$rethash->{$cds}->{'attributes'}}, { name    => $prokCdsOrfAttributeAttTypes->{$block->[2]},
							     content => $block->[3] });
	   }
	   else{
	       $logger->logdie("Found unexpected att_type '$block->[2]'");
	   }
       }
       else{
	   #
	   # No value was in feat_score.score
	   #
	   $logger->warn("legacy annotation database '$database' had empty feat_score.score for ORF '$block->[1]'");
	   
	   next;
       }
   }

   return ($rethash);
   
}





#---------------------------------------------------------------------------------------------
# subroutine:  store_seq_pair_run_attributes()
#
#
# input:       BsmlSeqPairAlignment object reference, hash reference (containing all 
#              seq-pair-run attributes).
#
# output:      none
#
# return:      BsmlSeqPairRun object reference
#
#
#---------------------------------------------------------------------------------------------
sub store_seq_pair_run_attributes {

    my ($alignment_pair, $tmphash, $doc) = @_;

    $logger->logdie("alignment_hash was not defined") if (!defined($alignment_pair));
    $logger->logdie("tmphash was not defined")        if (!defined($tmphash));
						   
    #
    # comment: Create a new BsmlSeqPairRun object and add all standard attributes.
    #
    my $seq_run = $alignment_pair->returnBsmlSeqPairRunR( $alignment_pair->addBsmlSeqPairRun() );


    $logger->logdie("seq_run was not defined.  Could not create a BsmlSeqPairRun object.") if (!defined($seq_run));
    
    foreach my $seqPairRunAttr ( keys %{$seqPairRunAttributeTypes} ) {
	
	if (( exists $tmphash->{$seqPairRunAttr} ) && (defined($tmphash->{$seqPairRunAttr})) ) {
	    
	    $seq_run->setattr( "$seqPairRunAttr", $tmphash->{$seqPairRunAttr});
	}
    }



    my $classattr = $doc->createAndAddBsmlAttribute( $seq_run,
						     'class',
						     'match_part' );
    
    if (!defined($classattr)){
	$logger->logdie("Could not create <Attribute> for name 'class' content 'match_part'");
    }


    return $seq_run;


}# end sub store_seq_pair_run_attribute 



#---------------------------------------------------------------------------------------------
# subroutine:  store_computational_sequence_stub()
#
#
# input:       scalar (BsmlSequence id), scalar (molecule type), scalar (sequence class),
#              scalar (BsmlGenome id), BsmlDoc object reference, scalar (feat_name),
#              scalar (database prefix)
#
# output:      none
#
# return:      BsmlSequence object reference
#
#
#---------------------------------------------------------------------------------------------
sub store_computational_sequence_stub {

    my %p = @_;

    my $sequence_id = $p{'sequence_id'};
    my $moltype     = $p{'moltype'};
    my $class       = $p{'class'};
    my $doc         = $p{'doc'};
    my $identifier  = $p{'identifier'};
    my $database    = $p{'database'};
							       

    
    ## Create <Sequence> element object reference for the refseq
    my $sequence_elem = $doc->createAndAddSequence(
						   $sequence_id, # id
						   undef,        # title
						   undef,        # length
						   $moltype,     # molecule
						   $class,       # class
						   );


    $logger->logdie("Could not create <Sequence> for sequence_id '$sequence_id'") if (!defined($sequence_elem));

    

    if (( exists $p{'genome_id'} ) && (defined($p{'genome_id'})) ) {

	my $genome_id = $p{'genome_id'};

	##  The <Sequence> will now be explicitly linked with the <Genome> (bug 2051).
	my $link_elem = $doc->createAndAddLink(
					       $sequence_elem,
					       'genome',           # rel
					       "#$genome_id"       # href
					       );
	
	$logger->logdie("Could not create a 'genome' <Link> element object reference for sequence_id '$sequence_id' genome_id '$genome_id'") if (!defined($link_elem));
	
    }
    
	



    ## Create <Cross-reference> object
    my $xref_elem = $doc->createAndAddCrossReference( parent            => $sequence_elem,
						      id                => $doc->{'xrefctr'}++,
						      database          => $database,
						      identifier        => $identifier,
						      'identifier-type' => 'current'
						      );
	
    $logger->logdie("Could not create <Cross-reference> element object reference for <Sequence> '$sequence_id' database '$database' identifier '$identifier'") if (!defined($xref_elem));


    ## Need to store //Link/@role for each analysis.  For this to happen, must return the BsmlSequence
    ## object reference (bug 2273).
    return $sequence_elem;
    
}
			



sub add_sequence_analysis_link {

    my ($doc, $bsmlSequence, $rel, $analysisIdentifier, $role, $sequence_analysis_link, $refseq) = @_;

    my $href = "#$analysisIdentifier";

    my $index = $analysisIdentifier . '_' . $role . '_' . $refseq;
    
    if (( exists $sequence_analysis_link->{$index}) && (defined($sequence_analysis_link))) {
	#
	# BsmlLink element object already exists for this BsmlSequence and BsmlAnalysis element objects.
	# Do nothing.
	#
    }
    else {
	
	## Need to store //Link/@role for each Sequence's analysis (bug 2273).
	my $bsmlLink = $doc->createAndAddLink( $bsmlSequence,           # element object reference
					       'analysis',              # rel
					       "#$analysisIdentifier",  # href
					       'input_of'               # role
					       );
	
	$logger->logdie("bsmlLink was not defined for rel 'analysis' href '$analysisIdentifier' role 'input_of' refseq '$refseq'") if (!defined($bsmlLink));

	$sequence_analysis_link->{$index} =  $bsmlLink;
    }			
}




#-----------------------------------------------------------------------------------------------------------
# subroutine:  create_euk_cds_orf_attributes_lookup()
# 
#
# comment:     The models' ORF_attributes score and score2 where att_type = 'is_partial' shall be associated with the
#              corresponding CDS features in BSML and chado
#
# input:       prism object reference, array reference (list of asmbl_ids), scalar (database name)
#
# output:      none
#
# return:      hash reference
#
#
#------------------------------------------------------------------------------------------------------------
sub create_euk_cds_orf_attributes_lookup {

    my ($prism, $asmbl_id, $database, $alt_database) = @_;

    my $rethash = {};

    my $idatabase = $database;
    if (defined($alt_database)){
	$idatabase = $alt_database;
    }
    
    foreach my $att_type ('is_partial', 'SP-HMM', 'targetP'){
	
	## It is assumed that all ORF_attributes are associated to the model and not the TU.
	my $ret = $prism->model_orf_attributes_is_partial($asmbl_id,
							  $database, 
							  'model',
							  $att_type);

	#--------------------------------
	# Returned fields:
	#
	# 0 => asm_feature.asmbl_id
	# 1 => asm_feature.feat_name
	# 2 => ORF_attribute.att_type
	# 3 => ORF_attribute.score
	# 4 => ORF_attribute.score2
	# 5 => ORF_attribute.curated
	#
	#--------------------------------
	
	foreach my $block ( @{$ret} ){
	    
	    my $cds = &get_uniquename($prism,
				      $idatabase,
				      $asmbl_id,
				      $block->[1],
				      'CDS');

	    my $attType = $block->[2];
	    
	    if ($attType eq 'is_partial'){
		
		if ((defined($block->[3])) && (length($block->[3]) > 0 )) {
		    
		    push ( @{$rethash->{$cds}->{'attributes'}}, { name    => "five_prime_partial",
								  content => $block->[3]
							      });
		}
		
		if ((defined($block->[4])) && (length($block->[4]) > 0 )) {
		    
		    push ( @{$rethash->{$cds}->{'attributes'}}, { name    => "three_prime_partial",
								  content => $block->[4]
							      });
		}

	    }
	    elsif ( exists $eukOrfAttTypeLookup->{$attType} ) {

		## We store this way instead of block->[2] => block->[3] because
		## in future we will need to be able to store multiple BSML
		## Attributes with the same 'name'
		push ( @{$rethash->{$cds}->{'attributes'}}, { name    =>  $eukOrfAttTypeLookup->{$attType},
							      content =>  $block->[5]
							  });

	    }
	    else {
		$logger->logdie("Unexpected att_type '$attType'");
	    }
	}
    }

    return ($rethash);
}



#------------------------------------------------------------------------------------------------------------------------------------------
# subroutine:  process_euk_cds_orf_attribute_data()
# 
#
# comment:     The models' ORF_attributes score and score2 where att_type = 'is_partial' shall be associated with the
#              corresponding CDS features in BSML and chado
#
#
# input:       hash reference (polypeptide feature object reference lookup), hash reference (ORF_attributes lookup),
#              BsmlDoc object reference
#
# output:      none
#
# return:      none
#
#
#------------------------------------------------------------------------------------------------------------------------------------------
sub process_euk_cds_orf_attribute_data {

    my %p = @_;
 
    my $cds_feature_hash    = $p{'cds_feature_hash'};
    my $orf_attributes_hash = $p{'orf_attributes_hash'};
    my $doc                 = $p{'doc'};


    foreach my $cds (sort keys %{$cds_feature_hash} ){
		
		
		if (( exists $cds_feature_hash->{$cds}) && (defined($cds_feature_hash->{$cds})) ) {
			
			
			my $cds_feature_elem = $cds_feature_hash->{$cds};
			
			
			if (( exists $orf_attributes_hash->{$cds}->{'attributes'}) && (defined($orf_attributes_hash->{$cds}->{'attributes'})) ){


				if ( scalar(@{$orf_attributes_hash->{$cds}->{'attributes'}}) > 0 ) {

					foreach my $attribute ( @{$orf_attributes_hash->{$cds}->{'attributes'}} ){
						

						if (( exists $attribute->{'content'}) && (defined($attribute->{'content'})) ) {

							my $value = $attribute->{'content'};
							#
							# Strip trailing whitespaces
							#
							$value =~ s/\s+$//;
							
							my $attribute_elem = $doc->createAndAddBsmlAttribute(
																				 $cds_feature_elem,      # elem
																				 $attribute->{'name'},  # key
																				 $value                 # value
																				 );
							
							
							$logger->logdie("Could not create <Attribute> element object reference for orf_attribute '$attribute' value '$attribute->{$attribute}' for CDS '$cds'") if (!defined($attribute_elem));
						}
						else {
							$logger->logdie("The content for this attribute name '$attribute->{'name'}' CDS '$cds' was not defined");
						}
					}
				}
				else {
					$logger->warn("Found null array reference for CDS '$cds' attributes");
				}
			}
			else {
#				$logger->warn("CDS '$cds' did not have any ORF_attributes");
			}
		}
		else {
			$logger->logdie("Feature object reference was not defined for CDS '$cds'");
		}

    }

} #end sub



sub cleanse_uniquename {

    my $uniquename = shift;

    # remove all open parentheses
    $uniquename =~ s/\(//g;
    
    # remove all close parentheses
    $uniquename =~ s/\)//g;


    return $uniquename;
}

    

#----------------------------------------------------------------------------------------
# create_euk_hmm2_evidence_lookup()
#
#----------------------------------------------------------------------------------------
sub create_euk_hmm2_evidence_lookup {


   my ($prism, $asmbl_id, $db, $db_prefix) = @_;
  
   my $rethash = {};

   my $v = {};

   my @feat_types = ('model');


   foreach my $ev_type ('HMM2'){
       
       foreach my $feat_type ( @feat_types ){
	   
	   my $ret = $prism->hmm_evidence_data($asmbl_id, $db, $feat_type, $ev_type);
	   
	   foreach my $block ( @{$ret} ){
	       
	       #-------------------------------------------------------
	       #
	       # 0 => asm_feature.asmbl_id
	       # 1 => evidence.feat_name
	       # 2 => evidence.accession
	       # 3 => undef
	       # 4 => evidence.rel_end5
	       # 5 => evidence.rel_end3
	       # 6 => evidence.m_lend
	       # 7 => evidence.m_rend
	       # 8 => evidence.total_score
	       # 9 => evidence.expect_whole
	       # 10 => evidence.curated
	       # 11 => evidence.domain_score
	       # 12 => evidence.expect_domain
	       # 13 => evidence.assignby
	       # 14 => evidence.date
	       #
	       #-------------------------------------------------------

	       # change feat_name from m00001 to p00001
	       $block->[1] =~ s/\.m/\.p/;

	       my $compseq = $block->[2];
	       if ($compseq =~ /^\d/){
		   # Found leading digit
		   $block->[2] = '_' . $block->[2];
	       }
	       
	       my $refpos        = ( $block->[4] - 1 );
	       my $runlength     = ( $block->[5] - $block->[4] + 1 );
	       my $comppos       = ( $block->[6] - 1 );
	       my $comprunlength = ( $block->[7] - $block->[6] + 1 );

	       &strip_surrounding_whitespace(\$block->[13]);
	       
	       $v->{$asmbl_id}->{$block->[1]}->{$block->[2]}->{'alignment'} = { total_score    => $block->[8],
										expect_whole   => $block->[9],
										HMM_curated    => $block->[10],
										assignby       => $block->[13],
										date           => $block->[14]
									    };




	       push( @{$v->{$asmbl_id}->{$block->[1]}->{$block->[2]}->{'domain'}},  { refpos         => $refpos,
										      runlength      => $runlength,
										      refcomplement  => 0,
										      comppos        => $comppos,
										      comprunlength  => $comprunlength,
										      compcomplement => 0,																	  
										      domain_score   => $block->[11],
										      expect_domain  => $block->[12],
										  });
	   }
       }
   }



   return $v;

}# create_euk_hmm2_evidence_lookup 


#----------------------------------------------------------------------------------------
# subroutine: store_euk_hmm2_evidence_data()
# 
#
#----------------------------------------------------------------------------------------
sub store_euk_hmm2_evidence_data { 
    
    my %p = @_;
    my $doc            = $p{'doc'};
    my $asmbl_id       = $p{'asmbl_id'};
    my $evidence_hash  = $p{'evidence_hash'};
    my $database       = $p{'database'};
    my $docname        = $p{'docname'};
    my $prefix         = $p{'prefix'};
    my $analysis_hash  = $p{'analysis_hash'};
    my $genome_id      = $p{'genome_id'};
    my $lc_qualified_models = $p{'lc_qualified_models'};

    my $evidence_type = 'HMM2';

    ## Need to store //Link/@role for each Sequence's analysis.  We define
    ## this lookup in order to ensure that only one BsmlLink element object
    ## is created for each BsmlSequence-BsmlAnalysis per BsmlLink role type
    ## (bug 2273).
    my $sequence_analysis_link = {};
    

    #
    # attributes is now a reference to a list of hashes
    #
    
    my $compute_type = $evidence_type;
    my $class = 'match';
    my $analysis_type = $compute_type . '_analysis';
    
    #
    #  Create one BER <Analysis> component
    # //Analysis/@id = 'BER_analysis'
    # //Analysis/Attribute/[@name='program']/@content = 'BER'
    # //Analysis/Attribute/[@name='programversion']/@content = 'legacy'
    # //Analysis/Attribute/[@name='algorithm']/@content = 'BER'
    # //Analysis/Attribute/[@name='sourcename']/@content = $docname
    # //Analysis/Attribute/[@name='name']/@content = 'BER_analysis'

    my $computeType = 'HMM2';

    ## Keep track of the number of HMM2 records that are inserted into the BSML document object.
    my $hmm2RecordInserted=0;
    
    ## Keep track of the number of unqualified models encountered.
    my $unqualifiedModelCtr=0;
    my $unqualifiedModelLookup={};

    foreach my $asmbl_id (sort keys %{$evidence_hash} ) { 
	
	my $refseqclass = 'polypeptide';

	my $refseqmoltype = 'aa';
	
	my $refseqsuffix = '_' . $refseqclass;

	my $compseqclass = 'polypeptide';
	
	my $compseqmoltype = 'aa';


	foreach my $feat_name (sort keys %{$evidence_hash->{$asmbl_id}} ) {

	    if ( ! exists $lc_qualified_models->{$feat_name}){

		if ($feat_name =~ /\d+\.p\d+/){
		    ## The HMM2 data was associated with the protein feature in the annotation database.
		    ## Need to check whether the corresponding model is one that qualifies for extraction.
		    my $modelFeatName = $feat_name;
		    $modelFeatName =~ s/\.p/\.m/;

		    if ( ! exists $lc_qualified_models->{$modelFeatName}){
			if ($logger->is_debug()){
			    $logger->debug("model '$modelFeatName' protein '$feat_name' does not qualify for extraction");
			    $unqualifiedModelLookup->{$modelFeatName}++;
			}
			$unqualifiedModelCtr++;
			next;
		    }
		}
		else {
		    if ($logger->is_debug()){
			$logger->debug("model/protein '$feat_name' does not qualify for extraction");
			$unqualifiedModelLookup->{$feat_name}++;
		    }
		    $unqualifiedModelCtr++;
		    next;
		}
	    }
	    
	    foreach my $accession (sort keys %{$evidence_hash->{$asmbl_id}->{$feat_name}} ){

		my $refseq = &get_uniquename($prism,
					     $database,
					     $asmbl_id,
					     $feat_name,
					     'polypeptide');

		my $compseq = $accession;
		
		# determine if the query name and the dbmatch name are a unique pair in the document
		
		my $alignment_pair_list = BSML::BsmlDoc::BsmlReturnAlignmentLookup( $refseq, $compseq );

		
		my $alignment_pair;

		if( $alignment_pair_list ){

		    $alignment_pair = $alignment_pair_list->[0];
		}
		
		if (!defined($alignment_pair)) {
		    
		    # no <Seq-pair-alignment> pair matches, add a new alignment pair and sequence run
		    
		    #check to see if sequences exist in the BsmlDoc, if not add them with basic attributes
		    

		    my $bsmlSequenceRefSeq =  $doc->returnBsmlSequenceByIDR( $refseq);
		    
		    if (!defined($bsmlSequenceRefSeq)){
			
			$bsmlSequenceRefSeq = &store_computational_sequence_stub( sequence_id => $refseq,
										  moltype     => $refseqmoltype,
										  class       => $refseqclass,
										  genome_id   => $genome_id,
										  doc         => $doc,
										  identifier  => $feat_name,
										  database    => $prefix
										  );
		    }


		    ## Need to store //Link/@role for each Sequence's analysis (bug 2273).
		    &addSequenceAnalysisLink( $doc,
					      $bsmlSequenceRefSeq,
					      $computeType,
					      'input_of',
					      $sequence_analysis_link,
					      $refseq
					      );


		    my $bsmlSequenceCompSeq = $doc->returnBsmlSequenceByIDR( $compseq );


		    if( !( $bsmlSequenceCompSeq ) ){

			## Set default
			my $compseq_db = $prefix;
			
			## Check for more accurate/appropriate database
			foreach my $compDbType ( keys %{$computeDatabaseLookup} ) { 
			    
			    if ($compseq =~ /^$compDbType/) {
				$compseq_db = $computeDatabaseLookup->{$compDbType};
				last;
			    }
			    ## Note that this specific type of check is no longer being performed
			    ## if ($compseq =~ /^PS\d+$/){
			}
			
			$bsmlSequenceCompSeq = &store_computational_sequence_stub( sequence_id => $compseq,
										   moltype     => $compseqmoltype,
										   class       => $compseqclass,
										   doc         => $doc,
										   identifier  => $compseq,
										   database    => $compseq_db,
										   );
		    }

		    ## Need to store //Link/@role for each Sequence's analysis (bug 2273).
		    &addSequenceAnalysisLink( $doc,
					      $bsmlSequenceCompSeq,
					      $computeType,
					      'input_of',
					      $sequence_analysis_link,
					      $compseq
					      );


		    ##---------------------------------------------------------------------------
		    ## Create <Seq-pair-alignment> and add attributes
		    ##
		    ##---------------------------------------------------------------------------
		    $alignment_pair = $doc->returnBsmlSeqPairAlignmentR( $doc->addBsmlSeqPairAlignment() );
		    
		    if (!defined($alignment_pair)){
			$logger->logdie("Could not create <Seq-pair-alignment> element object reference");
		    }
		    else {
			$alignment_pair->setattr( 'refseq',  $refseq  );
			$alignment_pair->setattr( 'compseq', $compseq );
			$alignment_pair->setattr( 'class',   $class   );
		    }


		    ## We've inserted some HMM2 data to the BSML document object.
		    $hmm2RecordInserted++;

		    ## Link the Seq-pair-alignment to the particular Analysis (bug 2172).
		    my $link_elem = $doc->createAndAddLink(
							   $alignment_pair,   # <Seq-pair-alignment> element object reference
							   'analysis',        # rel
							   "#$compute_type",  # href
							   'computed_by'      # role
							   );

		    if (!defined($link_elem)){
			$logger->logdie("Could not create an 'analysis' <Link> element object reference for <Seq-pair-alignment>");
		    }
		    
		    
		    #
		    # Store reference to the <Seq-pair-alignment>
		    #
		    BSML::BsmlDoc::BsmlSetAlignmentLookup( $refseq, $compseq, $alignment_pair );
		    
		    #
		    # Store additional <Seq-pair-alignment> BSML <Attribute> elements
		    #
		    my $alignment_hash = $evidence_hash->{$asmbl_id}->{$feat_name}->{$accession}->{'alignment'};
		    
		    foreach my $attribute qw(total_score expect_whole HMM_curated date assignby ) {

			if ( (exists($alignment_hash->{$attribute})) and (defined($alignment_hash->{$attribute})) ){
			    
			    $alignment_pair->addBsmlAttr( "$attribute", $alignment_hash->{$attribute} );
			    
			}
		    }
		    
		}

		

		#
		# Store each individual domain's worth of data
		#
		foreach my $data_hash ( @{$evidence_hash->{$asmbl_id}->{$feat_name}->{$accession}->{'domain'}} ){
		    
		    my $seq_run = &store_seq_pair_run_attributes( $alignment_pair, $data_hash, $doc );
		    

		    #
		    # Store additional <Seq-pair-run> BSML <Attribute> elements
		    #
		    foreach my $attribute qw(domain_score expect_domain) {
			
			if ( (exists($data_hash->{$attribute})) and (defined($data_hash->{$attribute})) ){
			    
			    $seq_run->addBsmlAttr( "$attribute", $data_hash->{$attribute} );
			    
			}
		    }
		}



	    }
	}
    }

    if ($hmm2RecordInserted > 0) {
	## Only attempt to create the Analysis section for HMM2 if
	## some HMM2 data was inserted into the BSML document object.

	if (!exists $analysis_hash->{$doc->{'doc_name'}}->{$computeType}){
	    
	    &createAnalysisComponent( doc           => $doc,
				      analysis_hash => $analysis_hash,
				      compute_type  => $computeType )
	}
    }
    else {

	my $loggerWarnMsg = "While some HMM2 data was extracted from the annotation database '$database' ".
	"for asmbl_id '$asmbl_id', no HMM2 data was inserted into the BSML document object. ";

	if ($unqualifiedModelCtr == 1){
	    $loggerWarnMsg .= "Note that one unqualified model was encountered while processing the HMM2 data.";
	}
	elsif ($unqualifiedModelCtr > 1){
	    $loggerWarnMsg .= "Note that '$unqualifiedModelCtr' unqualified models were encountered while processing the HMM2 data.";
	}
	
	$logger->warn($loggerWarnMsg);

	if ($logger->is_debug()){
	    $logger->debug("Here is a listing of all the unqualified model/protein features ".
			   "encountered while processing HMM2 data");
	    foreach my $uq (sort keys %{$unqualifiedModelLookup}){
		$logger->debug("$uq");
	    }
	}
    }
}


sub strip_surrounding_whitespace {
	
	my $var = shift;

	$$var =~ s/^\s*//;
	$$var =~ s/\s*$//;

}

#----------------------------------------------------------
# verify_and_set_genefinder_flags()
#
#----------------------------------------------------------
sub verify_and_set_genefinder_flags {

    my ($exclude_genefinder, $include_genefinder) = @_;

    if (defined($exclude_genefinder)){
	$exclude_genefinder = lc($exclude_genefinder);
    }
    if (defined($include_genefinder)){
	$include_genefinder = lc($include_genefinder);
    }
    
    # User can specify which gene finder data type to include in the migration- we modify our query accordingly.  
    # Defaults are:
    #  --exclude-genefinder=none  (I assume that there aren't any types called 'none')
    #  --include-genefinder=all   (Likewise, I assume that there aren't any types called 'all')


    if ((!defined($include_genefinder)) &&
	(!defined($exclude_genefinder))) {

	$include_genefinder = 'all'; 
	$exclude_genefinder = 'none'; 
    }
    elsif ((!defined($include_genefinder)) &&
	   (defined($exclude_genefinder))){

	if ($exclude_genefinder eq 'all'){
	    $include_genefinder = 'none';
	}
	elsif ($exclude_genefinder eq 'none'){
	    $include_genefinder = 'all';
	}
    }
    elsif ((defined($include_genefinder)) &&
	   (!defined($exclude_genefinder))) {

	if ($include_genefinder eq 'all'){
	    $exclude_genefinder = 'none';
	}
	elsif ($include_genefinder eq 'none'){
	    $exclude_genefinder = 'all';
	}
    }
    elsif ((defined($include_genefinder)) && 
	   (defined($exclude_genefinder)) &&
	   ($include_genefinder eq  $exclude_genefinder)) {

	$logger->logdie("include_genefinder '$include_genefinder' and exclude_genefinder '$exclude_genefinder' have same values");
    }

    return ($exclude_genefinder, $include_genefinder);
}


sub getLogger {

    my ($logfile, $debug_level, $database, $asmbl_id) = @_;

    #
    # initialize the logger
    #
    if (!defined($logfile)){
	
	$logfile = '/tmp/' . File::Basename::basename($0) . '.' .$database . '.' .$asmbl_id . '.log';
	print STDERR "log4perl was not defined, therefore set to '$logfile'\n";
	
    }
    
    my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				     'LOG_LEVEL'=>$debug_level);

    if (!defined($mylogger)){
	die "Could not instantiate Coati::Logger object for logfile ".
	"'$logfile' level '$debug_level'";
    }


    $logger = Coati::Logger::get_logger(__PACKAGE__);
    
    if (!defined($logger)){
	die "Could not retrieve Coati::Logger object for logfile ".
	"'$logfile' level '$debug_level' for package " . __PACKAGE__ ."'";
    }

}


#----------------------------------------------------------
# verify_and_set_fastadir()
#
#----------------------------------------------------------
sub verify_and_set_fastadir {

    my ($fastadir, $outdir, $bsmlDocName) = @_;

    if (!defined($fastadir)) {
	if ($logger->is_debug()){
	    $logger->debug("The fastadir was not defined");
	}

	if (defined($bsmlDocName)){
	    $fastadir = dirname($bsmlDocName);
	    if ($logger->is_debug()){
		$logger->debug("The fastadir was set to the dirname of '$bsmlDocName'");
	    }

	}
	elsif (defined($outdir)){
	    $fastadir = $outdir;
	    if ($logger->is_debug()){
		$logger->debug("The fastadir was set to the outdir '$outdir'");
	    }

	}
	else {
	    $fastadir = ".";
	    if ($logger->is_debug()){
		$logger->debug("The fastadir was set to the current working directory");
	    }
	    
	}
    }

    ## verify the fastadir
    if (defined($fastadir)){
	if (!-e $fastadir){
	    $logger->fatal("fastadir '$fastadir' does not exist");
	    &print_usage();
	}
	if (!-d $fastadir){
	    $logger->fatal("fastadir '$fastadir' is not a directory");
	    &print_usage();
	}
	if (!-w $fastadir){
	    $logger->fatal("fastadir '$fastadir' does not have write permissions");
	    &print_usage();
	}

    }


    return $fastadir;
}



#----------------------------------------------------------
# parse_sequence_type()
#
#----------------------------------------------------------
sub parse_sequence_type {

    my ($sequence_type) = @_;

    ## The secondary sequence type may be specified on the command-line.  
    ## This information will be stored in an Attribute-list element and 
    ## then in chado.feature_cvterm. Need to verify that both 
    ## database:term have been specified (bug 2086).

    my ($ontology, $seqtype);

    if (defined($sequence_type)){
    
	if ($sequence_type ne 'none') {
	
	    ($ontology, $seqtype) = split(/:/, $sequence_type);
	
	    if (!defined($ontology)){
		$logger->logdie("ontology was not defined for sequence_type '$sequence_type'.  Valid sample invocation: legacy2bsml.pl --sequence_type SO:contig");
	    }

	    if (!defined($seqtype)){
		$logger->logdie("seqtype was not defined for sequence_type '$sequence_type'.  Valid sample invocation: legacy2bsml.pl --sequence_type SO:contig");
	    }
	}
    }

    return ($ontology, $seqtype);
}




#----------------------------------------------------------
# store_attribute_list()
#
#----------------------------------------------------------
sub store_attribute_list {

    my ($element, $name, $content) = @_;
    
    my $arr = [];
    
    push ( @{$arr}, { name    => $name,
		      content => $content});
    
    $element->addBsmlAttributeList($arr);
    
}


#----------------------------------------------------------------
# check_pub_locus()
#
#----------------------------------------------------------------
sub check_pub_locus {
    my ($feat_name, $asmbl_id, $gb_acc, $date_released) = @_;
    
    if ((defined($gb_acc)) &&
	(defined($date_released))) {
	$logger->logdie("A gene was submitted to Genbank, however no pub_locus was provided (for TU '$feat_name' asmbl_id '$asmbl_id' gb_acc '$gb_acc' date_released '$date_released').  Please notify the appropriate annotator.");
    }
}

#----------------------------------------------------------------
# create_miscellaneous_feature_lookup()
#
#----------------------------------------------------------------
sub create_miscellaneous_feature_lookup {

    my ($database, $asmbl_id, $no_misc_features) = @_;
    
    my $misc = {};

    if ((defined($no_misc_features)) && ($no_misc_features == 1)) {
	#
	# The user has specified that no miscellaneous feature types should be retrieved
	#
	$logger->info("No miscellaneous feature types shall be retrieved from the database");
    }
    else {

	foreach my $feat_type ('misc_feature', 'region'){

	    my $ret = $prism->miscellaneous_features($database, $asmbl_id, $feat_type);

	    for (my $i=0 ; $i < scalar(@{$ret}); $i++) {
		push ( @{$misc->{$asmbl_id}}, [$ret->[$i][1],  # asm_feature.feat_name
					       $ret->[$i][2],  # asm_feature.end5
					       $ret->[$i][3],  # asm_feature.end3
					       $ret->[$i][4],  # asm_feature.comment
					       ]);
	    }
	    
	}
    }

    return $misc;
}


#----------------------------------------------------------------
# create_repeat_feature_lookup()
#
#----------------------------------------------------------------
sub create_repeat_feature_lookup {

    my ($database, $asmbl_id, $no_repeat_features) = @_;
    
    my $repeat = {};

    if ((defined($no_repeat_features)) && ($no_repeat_features == 1)) {
	#
	# The user has specified that no repeat feature types should be retrieved
	#
	$logger->info("No repeat feature types shall be retrieved from the database");
    }
    else {
	
	my $ret = $prism->repeat_features($database, $asmbl_id, 'repeat');

	my $repeatCtr;

	for ($repeatCtr=0 ; $repeatCtr < scalar(@{$ret}); $repeatCtr++) {

	    push ( @{$repeat->{$asmbl_id}}, [$ret->[$repeatCtr][1],  # asm_feature.feat_name
					     $ret->[$repeatCtr][2],  # asm_feature.end5
					     $ret->[$repeatCtr][3],  # asm_feature.end3
					     $ret->[$repeatCtr][4],  # ORF_attribute.score
					     ]);
	}

	
	if ($repeatCtr > 0 ){

	    if ($repeatMappingFile){

		$repeatIdMapper = new Annotation::Features::Repeat::IdMapper(filename=>$repeatMappingFile);

		if (!defined($repeatIdMapper)){

		    $logger->logdie("Could not instantiate Annotation::".
				    "Features::Repeat::IdMapper with file ".
				    "'$repeatMappingFile'");
		}

	    } else {
		if ($logger->is_debug()){
		    $logger->debug("User did not specify repeat ".
				   "mapping file therefore will not ".
				   "attempt to load repeat mapping ".
				   "lookup");
		}
	    }
	}
    }

    return $repeat;
}


#----------------------------------------------------------------
# create_transposon_feature_lookup()
#
#----------------------------------------------------------------
sub create_transposon_feature_lookup {

    my ($database, $asmbl_id, $no_transposon_features) = @_;
    
    my $transposon = {};

    if ((defined($no_transposon_features)) && ($no_transposon_features == 1)) {
	#
	# The user has specified that no transposon feature types should be retrieved
	#
	$logger->info("No transposon feature types shall be retrieved from the database");
    }
    else {
	my $ret = $prism->transposon_features($database, $asmbl_id, 'TE');

	for (my $i=0 ; $i < scalar(@{$ret}); $i++) {
	    
	    push ( @{$transposon->{$asmbl_id}}, [$ret->[$i][1],  # asm_feature.feat_name
						 $ret->[$i][2],  # asm_feature.end5
						 $ret->[$i][3],  # asm_feature.end3
						 $ret->[$i][4],  # ident.com_name
						 ]);
	}

    }

    return $transposon;
}



#----------------------------------------------------------------------------------
# store_misc_feature_types()
#
#----------------------------------------------------------------------------------
sub store_misc_feature_types {

    my ($misc_feature_lookup, $asmbl_id, $doc, $no_misc_features, $database,
	$feature_table_elem) =@_;

    my $class = 'located_sequence_feature';
    
    if (( exists $misc_feature_lookup->{$asmbl_id}) && 
	( defined($misc_feature_lookup->{$asmbl_id}))) {
	    
	foreach my $sublist ( @{$misc_feature_lookup->{$asmbl_id}} ) {
	    
	    my $feat_name = &cleanse_uniquename(&remove_cntrl_chars($sublist->[0]));
	    
	    my ($end5, $end3, $complement)  = &coordinates($sublist->[1], $sublist->[2]);
	    
	    my $comment = &remove_cntrl_chars($sublist->[3]);
	    
	    my $uniquename = &get_uniquename($prism,
					     $database,
					     $asmbl_id,
					     $feat_name,
					     $class);
	    
	    
	    #
	    # Create <Feature> element object
	    #
	    my $feature_elem = $doc->createAndAddFeatureWithLoc(
								$feature_table_elem,  # <Feature-table> element object reference
								"$uniquename",        # id
								undef,                # title
								$class,               # class
								undef,                # comment
								undef,                # displayAuto
								$end5,                # start
								$end3,                # stop
								$complement           # complement	
								);
	    if (!defined($feature_elem)){
		$logger->logdie("Could not create <Feature> element object reference for gene model subfeature '$uniquename'"); 
	    }
	    else {
		
		my $attribute_elem = $doc->createAndAddBsmlAttribute(
								     $feature_elem,
								     'comment',
								     $comment
								     );
		
		if (!defined($attribute_elem)){
		    $logger->logdie("Could not create <Attribute> for the name 'comment' content '$comment'");
		}
	    }
	}
    }
}


#----------------------------------------------------------------------------------
# store_repeat_feature_types()
#
#----------------------------------------------------------------------------------
sub store_repeat_feature_types {

    my ($repeat_feature_lookup, $asmbl_id, $doc, $no_repeat_features, $database,
	$feature_table_elem, $analysis_hash, $outdir) =@_;

    ## Check whether there are any repeat features associated with 
    ## this particular asmbl_id
    if (( exists $repeat_feature_lookup->{$asmbl_id}) && 
	( defined($repeat_feature_lookup->{$asmbl_id}))) {

	#
	# To ensure that no two repeat features spanning the same
	# region are stored in the BSML document
	#
	my $repeat_lookup = {};
	
	foreach my $sublist ( @{$repeat_feature_lookup->{$asmbl_id}} ) {
	    
	    my $feat_name = &cleanse_uniquename(&remove_cntrl_chars($sublist->[0]));

	    my ($end5, $end3, $complement)  = &coordinates($sublist->[1], $sublist->[2]);

	    if (exists $repeat_lookup->{$end5}->{$end3} ) {
		#
		# May be some feature with different label spanning the same region
		#
		$repeat_lookup->{$end5}->{$end3}++;

		next;
	    }

	    $repeat_lookup->{$end5}->{$end3}++;


	    my $score = &remove_cntrl_chars($sublist->[3]);

	    my $class;

	    my $attribute_name;

	    my $attribute_content = $score;
	    
	    if ($score =~ /[GATC]\Srich/) {

		$class = 'GATC_rich_region';

		$attribute_name = 'comment';
		
	    }
	    elsif ($score =~ /\(([GATC]+)\)n/) {

		$attribute_content = $1;

		$attribute_name = 'repeat_unit';

		$class = 'microsatellite';
	    }
	    elsif ($score) {

		$class = 'repeat_region';

		$attribute_name = 'repeat_family';
	    }
	    
	    
	    my $uniquename = &get_uniquename( $prism,
					      $database,
					      $asmbl_id,
					      $feat_name,
					      $class);

	    #
	    # Create <Feature> element object
	    #
	    my $feature_elem = $doc->createAndAddFeatureWithLoc(
								$feature_table_elem,  # <Feature-table> element object reference
								"$uniquename",        # id
								undef,                # title
								$class,               # class
								undef,                # comment
								undef,                # displayAuto
								$end5,                # start
								$end3,                # stop
								$complement           # complement
								);
	    if (!defined($feature_elem)){
		$logger->logdie("Could not create <Feature> element object reference for gene model subfeature '$uniquename'"); 
	    }
	    else {

		my $attribute_elem = $doc->createAndAddBsmlAttribute(
								     $feature_elem,
								     $attribute_name,
								     $attribute_content
								     );
		
		if (!defined($attribute_elem)){
		    $logger->logdie("Could not create <Attribute> for the name '$attribute_name' content '$attribute_content'");
		}

		if (defined($repeatIdMapper)){

		    ## The user specified a repeat identifier mapping file
		    ## whose contents were stored in the Annotation::Features::Repeat::IdMapper
		    ## object.  At this point, we should attempt to add a BSML <Attribute>
		    ## corresponding with the specified repeat mapped identifier value.

		    my $newId = $repeatIdMapper->getId($score);

		    if (!defined($newId)){
			$logger->warn("There was no new identifier value ".
				      "for old identifier '$score' while ".
				      "processing repeat feature with ".
				      "feat_name '$feat_name' asmbl_id ".
				      "'$asmbl_id'");
			
		    } else {
			my $ae = $doc->createAndAddBsmlAttribute(
								 $feature_elem,
								 'name',
								 $newId
								 );
			
			if (!defined($ae)){
			    $logger->logdie("Could not create <Attribute> for ".
					    "name 'name' content '$newId' for ".
					    "feature with id '$uniquename' ".
					    "feat_name '$feat_name' asmbl_id ".
					    "'$asmbl_id'");
			}
		    }
		} else {
		    if (defined($repeatMappingFile)){
			$logger->logdie("--repeat-mapping-file was specified as ".
					"'$repeatMappingFile' but the Annotation::".
					"Features::Repeat::IdMapper object is not ".
					"defined!  Was processing repeat feature ".
					"with feat_name '$feat_name' asmbl_id ".
					"'$asmbl_id'");
		    }
		}

		if (($class eq 'microsatellite') || ($class eq 'repeat_region')){

		    ## Create a Repeatmasker <Analysis> element object
		    
		    my $computeType = 'RepeatMasker';
		    
		    if (!exists $analysis_hash->{$doc->{'doc_name'}}->{$computeType}){

			&createAnalysisComponent( doc           => $doc,
						  analysis_hash => $analysis_hash,
						  compute_type  => $computeType );
		    }

		    ## Create a <Link> element object to tie the repeat <Feature>
		    ## to some RepeatMasker <Analysis>
		    my $link_elem = $doc->createAndAddLink( $feature_elem,       # element
							    'analysis',          # rel
							    "#$computeType",     # href
							    'computed_by'        # role
							    );
		    
		    if (!defined($link_elem)){
			$logger->logdie("Could not create an 'analysis' <Link> element object for <Feature> '$class' uniquename '$uniquename' and analysis type 'repeatmasker'");
		    }
		}
	    }
	}
    }
}



#----------------------------------------------------------------------------------
# store_transposon_feature_types()
#
#----------------------------------------------------------------------------------
sub store_transposon_feature_types {

    my ($transposon_feature_lookup, $asmbl_id, $doc, $no_transposon_features, $database,
	$feature_table_elem) =@_;

    
    if (( exists $transposon_feature_lookup->{$asmbl_id}) && 
	( defined($transposon_feature_lookup->{$asmbl_id}))) {

	foreach my $sublist ( @{$transposon_feature_lookup->{$asmbl_id}} ) {

	    my $feat_name = &cleanse_uniquename(&remove_cntrl_chars($sublist->[0]));


	    my ($end5, $end3, $complement)  = &coordinates($sublist->[1], $sublist->[2]);

	    my $com_name = &remove_cntrl_chars($sublist->[3]);

	    my $class = 'transposable_element';
	    
	    my $uniquename = &get_uniquename( $prism,
					      $database,
					      $asmbl_id,
					      $feat_name,
					      $class);

	    #
	    # Create <Feature> element object
	    #
	    my $feature_elem = $doc->createAndAddFeatureWithLoc(
								$feature_table_elem,  # <Feature-table> element object reference
								"$uniquename",        # id
								undef,                # title
								$class,               # class
								undef,                # comment
								undef,                # displayAuto
								$end5,                # start
								$end3,                # stop
								$complement           # complement
								);
	    if (!defined($feature_elem)){
		$logger->logdie("Could not create <Feature> element object reference for gene model subfeature '$uniquename'"); 
	    }
	    else {

		my $attribute_elem = $doc->createAndAddBsmlAttribute(
								     $feature_elem,
								     'comment',
								     $com_name
								     );
		
		if (!defined($attribute_elem)){
		    $logger->logdie("Could not create <Attribute> for the name 'comment' content '$com_name'");
		}
	    }
	}
    }

}

#----------------------------------------------------
# assign_secondary_type()
#
#----------------------------------------------------
sub assign_secondary_type {

    my ($assembly_sequence_elem, $molecule_name) = @_;

	
    my $secondaryType;
    
    foreach my $moleculeType ( keys %{$secondaryTypeLookup} ) {
	if ($molecule_name =~ /$moleculeType/){
	    $secondaryType = $secondaryTypeLookup->{$moleculeType};
	    last;
	}
    }

    if (! defined ($secondaryType) ) {
	
	$logger->warn("Unrecognized molecular name was retrieved from asmbl_data.name '$molecule_name'.  Setting default value 'assembly'");
	
	$secondaryType = 'assembly';
	    	    
    }

    &store_attribute_list($assembly_sequence_elem,
			  'SO',
			  $secondaryType);
    

    return $secondaryType;

}


#----------------------------------------------------
# store_organism_attribute()
#
#----------------------------------------------------
sub store_organism_attribute {

    my ($doc, $organism_elem, $orgdata, $species, $alt_species) = @_;

    foreach my $attribute ('abbreviation', 'gram_stain', 'genetic_code', 'mt_genetic_code', 'translation_table'){
	
	if ((exists $orgdata->{$attribute}) && (defined($orgdata->{$attribute}))){

	    my $value = $orgdata->{$attribute};

	    if (defined($alt_species)){
		
		$value =~ s/$species/$alt_species/;
	    }

	    my $attribute_elem = $doc->createAndAddBsmlAttribute( $organism_elem,
								  $attribute,
								  $value );
	    
	    if (!defined($attribute_elem)){
		$logger->logdie("Could not create <Attribute> for the name '$attribute' content '$value'");
	    }
	}
    }
}   


#----------------------------------------------------
# calculate_and_store_splice_sites()
#
#----------------------------------------------------
sub calculate_and_store_splice_sites {


    my ($modelArrayRef, 
	$exons, 
	$asmbl_id,
	$doc,
	$prefix,
	$database,
	$transcript_feat_name,
	$polypeptide_sequence_element_lookup, 
	$feature_group_element_lookup,
	$feature_table_element_lookup) = @_;

    foreach my $model ( @{$modelArrayRef} ) {
	
	my $modelFeatName = $model->{'feat_name'};

	if ($logger->is_debug()){
	    $logger->debug("Processing model with feat_name '$modelFeatName'");
	}

	if (( exists $exons->{$modelFeatName} ) && ( defined($exons->{$modelFeatName} ) )){
	    
	    my @sortedexons =  (sort {$a->{'end5'} <=> $b->{'end5'}} @{$exons->{$modelFeatName}} );
	    
	    #
	    # Retrieve the CDS, exon and polypeptide data from the legacy annotation database.
	    # Load the data into the lookup(s).
	    #
	    
	    # The CDS coordinate counter
	    my $c = $model->{'end5'};
	    
	    if ($logger->is_debug()){
		$logger->debug("CDS coordinate counter c set to '$c'");
	    }

	    # The polypeptide coordinate counter
	    my $p = 0;
	    
	    # The datalength(asm_feature.protein)
	    my $protein_length = length($model->{'protein'});
	    
	    if ($logger->is_debug()){
		$logger->debug("The protein length is '$protein_length'");
	    }

	    my $exonindex = 0;
	    
	    my $exoncount = scalar(@sortedexons) - 1;
	    # Don't need to process the last exon as does not have a 3' splice site!
	    
	    if ($logger->is_debug()){
		$logger->debug("exoncount '$exoncount'");
	    }

	    while (($c <= $model->{'end3'}) && # No splice sites beyond the 3' end of the CDS
		   ( $exonindex < $exoncount )) {
		
		my $exon = $sortedexons[$exonindex];
		
		if ($logger->is_debug()){
		    my $exonFeatName = $exon->{'feat_name'};
		    $logger->debug("Processing exon with feat_name '$exonFeatName' end3 '$exon->{'end3'}'");
		}


		if ($exon->{'end3'} < $model->{'end5'} ){

		    # Move to the next exon
		    $exonindex++;

		    if ($logger->is_debug()){
			$logger->debug("Since the exon's end3 '$exon->{'end3'}' is less than the model's end5 '$model->{'end5'}'- ".
				       "we've encountered a 5-prime UTR exon.  exonindex '$exonindex'. Skipping to the next exon.");
		    }
		    next;
		}


		while ( $c <= $exon->{'end3'}){
		    
		    # We want to walk to the end of the current exon.  
		    # There we'll find a splice site.
		    
		    # Increment the CDS coordinate counter
		    $c++;

		    # Increment the polypeptide coordinate counter
		    # if we've counted three bases (one codon).
		    if ($c % 3 == 0){
			$p++;
		    }
		}
		
		# Create the splice_site <Feature> with <Interval-loc>
		&create_splice_site_feature($doc, 
					    $p, 
					    $model, 
					    $database, 
					    $prefix, 
					    $asmbl_id,
					    $exon->{'complement'},
					    $protein_length,
					    $c,
					    $polypeptide_sequence_element_lookup, 
					    $feature_group_element_lookup,
					    $feature_table_element_lookup);
		
		# Move to the next exon
		$exonindex++;
		if ($logger->is_debug()){
		    $logger->debug("exonindex '$exonindex'");
		}
	    }
	}
	else {
	    if ($logger->is_debug()){
		$logger->debug("There were no exons for model '$modelFeatName' for database '$database' ".
			       "asmbl_id '$asmbl_id'");
	    }
	}
    }
}


#---------------------------------------------------------
# create_splice_site_feature()
#
#---------------------------------------------------------
sub create_splice_site_feature {

    my ($doc, 
	$p,
	$cds, 
	$database, 
	$prefix, 
	$asmbl_id,
	$complement,
	$protein_length,
	$c,
	$polypeptide_sequence_element_lookup,
	$feature_group_element_lookup,
	$feature_table_element_lookup) = @_;

    my $protein_feat_name = $cds->{'feat_name'};

    $protein_feat_name =~ s/\.m/\.p/;

    my $polypeptide_uniquename = &get_uniquename($prism,
						 $database, 
						 $asmbl_id, 
						 $protein_feat_name,
						 'polypeptide');


    if ($logger->is_debug()){
	$logger->debug("protein_feat_name '$protein_feat_name' polypeptide_uniquename '$polypeptide_uniquename'");
    }

    #
    # Need to create a <Feature-table> for each polypeptide <Sequence> in order
    # to create //Feature/Interval-locs for the splice_site <Feature> elements.
    # This means we require reference to the polypeptide <Feature> element's
    # corresponding <Sequence> element.
    #
    if ((exists $polypeptide_sequence_element_lookup->{$polypeptide_uniquename}) &&
	(defined($polypeptide_sequence_element_lookup->{$polypeptide_uniquename}))) {

	# The polypeptide <Sequence> exists in the lookup.
	my $polypeptide_sequence_elem = $polypeptide_sequence_element_lookup->{$polypeptide_uniquename};
	
	# Now need reference to the polypeptide's <Feature-table> element.
	my $polypeptide_feature_table;

	if (( exists $feature_table_element_lookup->{$polypeptide_uniquename}) &&
	    (defined($feature_table_element_lookup->{$polypeptide_uniquename}))) {

	    # The polypeptide's <Feature-table> already exists.
	    $polypeptide_feature_table = $feature_table_element_lookup->{$polypeptide_uniquename};

	}
	else {

	    # The <Feature-table> does not exist for this polypeptide, therefore create one now.
	    $polypeptide_feature_table = $doc->createAndAddFeatureTable($polypeptide_sequence_elem);

	    if (!defined($polypeptide_feature_table)){
		$logger->logdie("Could not create <Feature-table> element object reference");
	    }
	    else {

		# Store reference to the polypeptide's <Feature-table> in the lookup
		$feature_table_element_lookup->{$polypeptide_uniquename} = $polypeptide_feature_table;
	    }
	}
	  
	# We now have reference to the <Feature-table> element for the polypeptide
	
	my $splice_site_feat_name = $protein_feat_name . '_' . $p;

	# Generating uniquename for the splice_site feature
	my $splice_site_uniquename = &get_uniquename($prism,
						     $database, 
						     $asmbl_id,
						     $splice_site_feat_name,
						     'splice_site');

	if ($logger->is_debug()){
	    $logger->debug("splice_site_feat_name '$splice_site_feat_name' splice_site_uniquename '$splice_site_uniquename'");
	}

	my $fmin = $p;
	my $fmax = $p;

	if ($c % 3 != 0){
	    $fmin--;
	}
	
	if ($complement){
	    #
	    # Need the length of the amino acid (polypeptide sequence)
	    # The value for the start/fmin should = length(polypeptide-$p) if dealing with the complement.
	    # Going to store a negative value for now.
	    $fmin = $protein_length - $p;
	    $fmax = $fmin;

	    if ($c % 3 != 0){
		$fmax++;
	    }
	}

	if ($logger->is_debug()){
	    $logger->debug("fmin '$fmin' fmax '$fmax'");
	}


	# Create a <Feature> element for the splice_site feature with <Interval-loc>
	my $splice_site_feature_elem = $doc->createAndAddFeatureWithLoc( $polypeptide_feature_table,  # <Feature-table> element object reference
									 $splice_site_uniquename,     # id
									 undef,                       # title
									 'splice_site',               # class
									 undef,                       # comment
									 undef,                       # displayAuto
									 $fmin,                       # start
									 $fmax,                       # stop
									 0                            # complement
									 );
	if (!defined($splice_site_feature_elem)){
	    $logger->logdie("Could not create <Feature> element for splice_site feature '$splice_site_uniquename'"); 
	}
    }
}


#---------------------------------------------------------
# get_uniquename()
#
#---------------------------------------------------------
sub get_uniquename {

    my ($prism, $database, $asmbl_id, $feat_name, $class) = @_;

    my $uniqstring = $database . '_' .$asmbl_id . '_' . $feat_name . '_' . $class;

    ## Now using IdGenerator
#    my $uniquename = $prism->getFeatureUniquenameFromIdGeneator($database, $class, $uniqstring, $idgen_identifier_version);
    my $uniquename = $prism->getFeatureUniquenameFromIdGenerator($database, $class, $uniqstring, 0);
    
    if (!defined($uniquename)){
	$logger->logdie("uniquename was not defined for database '$database' class '$class' uniqstring '$uniqstring' ".
#			"version '$idgen_identifier_verison'");
			"version '0'");
    }

    return $uniquename;
}

sub createQualifiedFeatureLookup {

    my ($file, $lookup) = @_;

    if (! Annotation::Util2::checkInputFileStatus($file)){
	$logger->logdie("Detected some problem with file '$file'");
    }

    my $contents = Annotation::Util2::getFileContentsArrayRef($file);

    if (!defined($contents)){
	$logger->logdie("Could not retrieve contents for file '$file'");
    }

    my $lineCtr=0;

    foreach my $line (@{$contents}){

	chomp $line;

	$lineCtr++;

	if ($line =~ /^\#/){
	    next;

	}
	if ($line =~ /^\s*$/){
	    next;
	}
			
	$line =~ s/\s+//g; ## get rid of all spaces
	
	if (!exists $lookup->{$line}){

	    $lookup->{$line}++;

	} else {

	    my $times = $qualified_tu_lookup->{$line} + 1;

	    $logger->warn("$line was specified '$times' times");
	}
			
    }

    print "Processed '$lineCtr' lines in file '$file'\n";
}



#----------------------------------------------------------------------------------------
# create_pmark_lookup()
#
#----------------------------------------------------------------------------------------
sub create_pmark_lookup {

    my ($prism, $asmbl_id, $database, $alt_database) = @_;

    my $pmark_lookup = {};

    my $ret = $prism->pmark_data($asmbl_id, $database);

    foreach my $block ( @{$ret} ) {
	
	my $feat_name = &cleanse_uniquename($block->[1]);
	
	my ($end5, $end3, $complement) = &coordinates($block->[2], $block->[3]);

	my $comment = $block->[4];

	$comment =~ s/^\s+//;

	$comment =~ s/\s+$//;

	if ($comment =~ /^\s*$/){
	    $comment = undef;
	}
	
	my $tmphash = { 'feat_name'   =>  $feat_name,
			'end5'        =>  $end5,
			'end3'        =>  $end3,
			'complement'  =>  $complement,
			'comment'     =>  $comment,
			'sequence'    =>  $block->[5]
		    };
	
	
	push( @{$pmark_lookup->{$block->[0]}}, $tmphash );
    }
   
   return ($pmark_lookup);
}


#--------------------------------------------------------------------------
# store_pmark_features()
#
#--------------------------------------------------------------------------
sub store_pmark_features {

    my %param    = @_;
    my $doc      = $param{'doc'};
    my $database = $param{'database'};
    my $prefix   = $param{'prefix'};
    my $pmark    = $param{'pmark'};
    my $asmbl_id = $param{'asmbl_id'};
    my $feature_table_elem = $param{'feature_table_elem'};
    my $prism    = $param{'prism'};

    
    my $class = 'pmark_spacer';

    my $uniquename = &get_uniquename($prism,
				     $database,
				     $asmbl_id,
				     $pmark->{'feat_name'},
				     $class);
    
    #------------------------------------------------------------------------------------------
    # Create <Feature> and <Interval-loc> element objects
    #
    #------------------------------------------------------------------------------------------
    my $feature_elem = $doc->createAndAddFeatureWithLoc(
							$feature_table_elem,     # <Feature-table> element reference
							"$uniquename",           # id
							undef,                   # title
							$class,                  # class
							undef,                   # comment
							undef,                   # displayAuto
							$pmark->{'end5'},         # start
							$pmark->{'end3'},         # end
							$pmark->{'complement'}    # complement
							);

    if (!defined($feature_elem)){
	$logger->logdie("Could not create <Feature> for pmark '$uniquename'");
    }
    else {

	if (( exists $pmark->{'comment'}) && (defined ($pmark->{'comment'})) ) {

	    #------------------------------------------------------------------------------------------
	    # Create <Attribute> element object for the comment
	    #
	    #------------------------------------------------------------------------------------------
	    my $attribute_elem = $doc->createAndAddBsmlAttribute( $feature_elem,
								  'comment',
								  $pmark->{'comment'});
	    
	    if (!defined($attribute_elem)){
		$logger->logdie("Could not create <Attribute> for name 'comment' content '$pmark->{'comment'}'");
	    }
	}


	#------------------------------------------------------------------------------------------
	# Create <Cross-reference> element object for the feat_name
	#
	#------------------------------------------------------------------------------------------
	my $xref_elem = $doc->createAndAddCrossReference( 'parent'          => $feature_elem,
							  'id'              => $doc->{'xrefctr'}++,
							  'database'        => $prefix,
							  'identifier'      => $pmark->{'feat_name'},
							  'identifier-type' => 'feat_name'
							  );
	
	if (!defined($xref_elem)){
	    $logger->logdie("Could not create a <Cross-reference> element object reference for pmark '$uniquename'");
	}
	

	#------------------------------------------------------------------------------------------
	# Create <Link> element object to link this <Feature> to the <Sequence>
	#
	#------------------------------------------------------------------------------------------
	my $uniquename_seq = $uniquename . '_seq';
	
	my $sequence_link_elem = $doc->createAndAddLink( $feature_elem,       # element
							 'sequence',          # rel
							 "#$uniquename_seq"   # href
							 );
	
	if (!defined($sequence_link_elem)){
	    $logger->logdie("Could not create a 'sequence' <Link> element for <Feature> pmark uniquename '$uniquename' to pmark <Sequence> '$uniquename_seq'");
	}
    }	
}



#------------------------------------------------------------------
# remove_unqualified_subfeatures()
#
#------------------------------------------------------------------
sub remove_unqualified_subfeatures {

    my ($model_lookup, $transcripts, $exon_lookup,
	$qualified_model_lookup, $model_feat_names) = @_;

    ##
    ## If the user has specified a model-list-file, then legacy2bsml.pl
    ## should only migrate the TU, model and exon subfeatures that are
    ## related to only the models deemed 'qualified' by that list.
    ## Here we'll purge the unqualified subfeatures from the TU and exon
    ## lookups.
    ##


    ##------------------------------------------------------------------
    ## Remove TU features not related to qualified models
    ##
    ##------------------------------------------------------------------
    foreach my $tu_feat_name ( keys %{$transcripts} ){

	if ( ! exists $model_lookup->{$tu_feat_name} ){

	    delete $transcripts->{$tu_feat_name};
	}
    }

    ##------------------------------------------------------------------
    ## Remove exon features not related to qualified models
    ##
    ##------------------------------------------------------------------
    foreach my $model (keys %{$exon_lookup} ){

	if ( ! exists $qualified_model_lookup->{$model} ){

	    delete $exon_lookup->{$model};
	}
    }

    ##------------------------------------------------------------------
    ## Remove models if not qualified
    ##
    ##------------------------------------------------------------------
    {
	foreach my $model ( keys %{$model_feat_names}){
	    if ( ! exists $qualified_model_lookup->{$model}) { 
		delete $model_feat_names->{$model};
	    }
	}
    }

}


#------------------------------------------------------------------
# remove_unqualified_subfeatures_based_on_tu()
#
#------------------------------------------------------------------
sub remove_unqualified_subfeatures_based_on_tu {

    my ($model_lookup, $qualified_tu_lookup, $model_feat_names) = @_;

    ##
    ## If the user has specified a tu-list-file, then legacy2bsml.pl
    ## should only migrate the TU, model and exon subfeatures that are
    ## related to only those TUs deemed 'qualified'.
    ## Here we'll purge the unqualified subfeatures from the TU, model
    ## and exon lookups.
    ##

    my $disqualified_models = {};

    ##------------------------------------------------------------------
    ## Remove TU features not related to qualified models
    ##
    ##------------------------------------------------------------------
    {
	foreach my $tu (keys %{$model_lookup} ){
	    
	    if (  ! exists $qualified_tu_lookup->{$tu} ){

		foreach my $temphash ( @{$model_lookup->{$tu}} ) {
		    
		    my $model = $temphash->{'feat_name'};
		    
		    $disqualified_models->{$model}++;
		}
		
		## Disqualify this TU's models
		delete $model_lookup->{$tu};
		
	    }
	}
    }
	
    ##
    ## Remove the model from the model_feat_names lookup.  
    ## This will ensure that no CDS and polypeptide Sequence
    ## stubs are created for disqualified models.
    ##
    {
	foreach my $model ( keys %{$model_feat_names} ){

	    if ( exists $disqualified_models->{$model} ) {
		delete $model_feat_names->{$model};
	    }
	}
    }

}


#----------------------------------------------------------------------------------------
#  createAnalysisComponent()
#
#----------------------------------------------------------------------------------------
sub createAnalysisComponent {

    my %p = @_;

    my $doc            = $p{'doc'};
    my $analysis_hash  = $p{'analysis_hash'};
    my $computeType    = $p{'compute_type'};

    my $analysisElem = $doc->createAndAddAnalysis( 'id' => "$computeType"  );
	
    if (!defined($analysisElem)){
	$logger->logdie("Could not create <Analysis> for compute type '$computeType'");
    }

    ## store reference to the <Analysis> element object in the lookup
    $analysis_hash->{$doc->{'doc_name'}}->{$computeType} = $analysisElem;
    
    my $localAnalysisAttributeLookup = $analysisAttributeLookup->{$computeType};

    foreach my $analysisAttr ( keys %{$localAnalysisAttributeLookup} ){ 
	
	my $attrElem = $doc->createAndAddBsmlAttribute( $analysisElem,
							"$analysisAttr",
							"$localAnalysisAttributeLookup->{$analysisAttr}" );
	if (!defined($attrElem)) {
	    $logger->logdie("Could not create <Attribute> with name ".
			    "'$analysisAttr' and content ".
			    "'$localAnalysisAttributeLookup->{$analysisAttr}'");
	}
    }    
}


sub addSequenceAnalysisLink {

    my ($doc, $bsmlSequence, $computeType, $role, $sequence_analysis_link, $refseq) = @_;

    my $href = "#" . $computeType;

    my $index = $computeType . '_' . $role . '_' . $refseq;
    
    if ( ! exists $sequence_analysis_link->{$index} ){

	## BsmlLink element object does not yet exist for these
	## two BsmlSequence and BsmlAnalysis element objects.
	
	## Need to store //Link/@role for each Sequence's analysis (bug 2273).
	my $bsmlLink = $doc->createAndAddLink( $bsmlSequence,   # element object reference
					       'analysis',      # rel
					       $href,           # href
					       $role            # role
					       );
	if (!defined($bsmlLink)){
	    $logger->logdie("bsmlLink was not defined for rel 'analysis' href '$href' ".
			    "role '$role' refseq '$refseq'");
	}

	$sequence_analysis_link->{$index} =  $bsmlLink;
    }			
}


#----------------------------------------------------------------------------------------
# createInterproEvidenceLookup()
#
#----------------------------------------------------------------------------------------
sub createInterproEvidenceLookup {


   my ($prism, $asmbl_id, $database, $db_prefix, $schemaType) = @_;

   my $interproEvidenceLookup = {};
   
   my $ret = $prism->interproEvidenceDataByAsmblId($asmbl_id, 
						   $database,
						   $prokSchemaTypeToFeature->{$schemaType});
   
   foreach my $block ( @{$ret} ){
       
       my $featName = &cleanse_uniquename($block->[0]);
       
       ## 0 => evidence.feat_name
       ## 1 => evidence.accession
       ## 2 => evidence.end5
       ## 3 => evidence.end3

       ## The legacy annotation databases may contain control characters.  These
       ## control characters should not propagate into the .bsml gene model documents.
       
       my $compseq = &remove_cntrl_chars($block->[1]);

       if ($compseq =~ /^\d/){
	   # Found leading digit
	   $compseq = '_' . $compseq;
       }
       
       my $tmpLookup = { 'refpos' => ( $block->[2] - 1 ),
			 'runlength' => abs( $block->[3] - $block->[2] + 1 ),
			 'refcomplement' => 0,
			 'comppos' => ( $block->[2] - 1 ),
			 'comprunlength' => abs( $block->[3] - $block->[2] + 1 ),
			 'compcomplement' => 0 };
       
       my $key = $featName . '_' . $compseq . '_' . $block->[2] . '_' . $block->[3];
       
       $interproEvidenceLookup->{$asmbl_id}->{'interpro'}->{$featName}->{$compseq}->{$key} = $tmpLookup;
       
   }

   return $interproEvidenceLookup;

}


##----------------------------------------------------------------------------------------
## storeInterproEvidenceData()
##
##----------------------------------------------------------------------------------------
sub storeInterproEvidenceData {

    my %p = @_;
    my $doc            = $p{'doc'};
    my $asmbl_id       = $p{'asmbl_id'};
    my $data_hash      = $p{'data_hash'};
    my $database       = $p{'database'};
    my $docname        = $p{'docname'};
    my $prefix         = $p{'prefix'};
    my $analysis_hash  = $p{'analysis_hash'};
    my $genome_id      = $p{'genome_id'};
    my $sequence_analysis_link = $p{'sequence_analysis_link'};

    my $class = 'match';
    my $href  = '#INTERPRO';

    my $computeType = 'INTERPRO';

    if (!exists $analysis_hash->{$doc->{'doc_name'}}->{$computeType}){

	&createAnalysisComponent( 'doc'           => $doc,
				  'analysis_hash' => $analysis_hash,
				  'compute_type'  => $computeType );	
    }

    foreach my $ev_type (sort keys %{$data_hash} ) {

	foreach my $feat_name (sort keys %{$data_hash->{$ev_type}} ){
	    
	    foreach my $accession (sort keys %{$data_hash->{$ev_type}->{$feat_name}} ){

		foreach my $key (sort keys %{$data_hash->{$ev_type}->{$feat_name}->{$accession}} ){
		    
		    my $tmphash = $data_hash->{$ev_type}->{$feat_name}->{$accession}->{$key};

		    my $refseq = &get_uniquename($prism,
						 $database,
						 $asmbl_id,
						 $feat_name,
						 'polypeptide');

		    my $compseq = $accession;
		    
		    # determine if the query name and the dbmatch name are a unique pair in the document
		    
		    my $alignment_pair_list = BSML::BsmlDoc::BsmlReturnAlignmentLookup(
										       $refseq,
										       $compseq
										       );
		    my $alignment_pair;
		    if( $alignment_pair_list ){
			$alignment_pair = $alignment_pair_list->[0];
		    }

		    if (!defined($alignment_pair)) {

			## No <Seq-pair-alignment> pair matches, add a new alignment pair and sequence run
			
			## Check to see if sequences exist in the BsmlDoc, if not add them with basic attributes
			
			my $bsmlSequenceRefSeq = $doc->returnBsmlSequenceByIDR( $refseq);


			if( !( $bsmlSequenceRefSeq)){
			    
			    $bsmlSequenceRefSeq = &store_computational_sequence_stub( sequence_id => $refseq,
										      moltype     => 'aa',
										      class       => 'polypeptide',
										      genome_id   => $genome_id,
										      doc         => $doc,
										      identifier  => $feat_name,
										      database    => $prefix
										      );
			}

			## Need to store //Link/@role for each Sequence's analysis (bug 2273).
			&addSequenceAnalysisLink( $doc,
						  $bsmlSequenceRefSeq,
						  $computeType,
						  'input_of',
						  $sequence_analysis_link,
						  $refseq
						  );



			my $bsmlSequenceCompSeq = $doc->returnBsmlSequenceByIDR( $compseq );

			if( !( $bsmlSequenceCompSeq)) {

			    ## Set default
			    my $compseq_db = $prefix;
			    
			    ## Check for more accurate/appropriate database
			    foreach my $compDbType ( keys %{$computeDatabaseLookup} ) { 

				if ($compseq =~ /^$compDbType/) {
				    $compseq_db = $computeDatabaseLookup->{$compDbType};
				    last;
				}
				## Note that this specific type of check is no longer being performed
				## if ($compseq =~ /^PS\d+$/){
			    }

			    $bsmlSequenceCompSeq = &store_computational_sequence_stub( sequence_id => $compseq,
										       moltype     => 'aa',
										       class       => 'polypeptide',
										       doc         => $doc,
										       identifier  => $compseq,
										       database    => $compseq_db
										       );
			}

			## Need to store //Link/@role for each Sequence's analysis (bug 2273).
			&addSequenceAnalysisLink( $doc,
						  $bsmlSequenceCompSeq,
						  $computeType,
						  'input_of',
						  $sequence_analysis_link,
						  $compseq
						  );

			##--------------------------------------------------------------------------------------
			## Create <Seq-pair-alignment> and store attributes
			##
			##--------------------------------------------------------------------------------------	      
			$alignment_pair = $doc->returnBsmlSeqPairAlignmentR( $doc->addBsmlSeqPairAlignment() );
			
			if (!defined($alignment_pair)){

			    $logger->logdie("Could not create <Seq-pair-alignment> element object reference");
			}
			else {
			    $alignment_pair->setattr( 'refseq',  $refseq  );
			    $alignment_pair->setattr( 'compseq', $compseq );
			    $alignment_pair->setattr( 'class',   $class   );
			}

			## Link the Seq-pair-alignment to the particular Analysis (bug 2172)
			my $link_elem = $doc->createAndAddLink(
							       $alignment_pair,  # <Seq-pair-alignment> element object reference
							       'analysis',       # rel
							       '#INTERPRO',       # href
							       'computed_by'     # role
							       );
			
			$logger->logdie("Could not create an 'analysis' <Link> element object reference for <Seq-pair-alignment>") if (!defined($link_elem));


			#
			# Store reference to the <Seq-pair-alignment>
			#
			BSML::BsmlDoc::BsmlSetAlignmentLookup( $refseq, $compseq, $alignment_pair );
			
		    }


		    my $seq_run = &store_seq_pair_run_attributes( $alignment_pair, $tmphash, $doc );

		}		
	    }    
	}
    }
}


##----------------------------------------------------------------------------------------
## createSignalPeptideLookup()
##
##----------------------------------------------------------------------------------------
sub createSignalPeptideLookup {

    my ($prism, $asmbl_id, $database, $schemaType) = @_;

    #
    # This subroutine should return a hash containing a arrays each of which contain hashes
    # The hash's key will be the asmbl_id
    # The array of hashes will contain anonymous hashes of the form:
    #
    # $data_hash = {
    #                'feat_name'  => asm_feature.feat_name WHERE 
    #                'score'      => feat_score.score WHERE
    #                'site'       => feat_score.score WHERE
    #                'y-score'    => feat_score.score WHERE
    #                's-mean'     => feat_score.score WHERE 
    #                'signal_probability'             => feat_score.score WHERE
    #                'max_cleavage_site_probability'  => feat_score.score WHERE
    #
    #
    #
    #  Whose construction will depend on an auxilliary hash containing
    #  (Could use table flattening or temp table strategy... )
    #
    #
    # if ( $score_type eq 'HMM cleavage site' ){
    #     $tmphash->{'score'} = $score;
    # }    
    # elsif ($score_type eq 'site'){
    #     $tmphash->{'site'} = $score;
    # }
    # elsif ($score_type eq 'cleavage site prob'){
    #     $tmphash->{'max_cleavage_site_prob'};
    # }
    # elsif ( $score_type eq '' ){
    #     $tmphash->{'max_cleavage_site_prob'};
    # }
    #
    #
    #$tmphash->{'end3'} = $score;


    #
    # Retrieve: feat_name, score_type, score
    # from database. Foreach record:
    #     $v->{$asmbl_id}->{$feat_name}->{ $score_type} = $score;
    #
    #
    my $ret = $prism->peptide_data($asmbl_id,
				   $database,
				   $schemaType);


    my $signalPeptideLookup = {};

    foreach my $block ( @{$ret} ) {
	
	my $featName = &cleanse_uniquename($block->[0]);
	
	my $scoreType = $block->[1];

	my $score = $block->[2];

	if (defined($score)){

	    if ($score !~ /^\s+$/){
	
		if ($scoreType eq 'site'){ ## NN_cleavage_site_probability
		    $signalPeptideLookup->{$featName}->[0] = $score;
		}
		elsif ($scoreType eq 'Y-score'){ ## y-score
		    $signalPeptideLookup->{$featName}->[1] = $score;
		}
		elsif ($scoreType eq 'signal pep prob'){ ## signal probability
		    $signalPeptideLookup->{$featName}->[2] = $score;
		}
		elsif ($scoreType eq 'cleavage site prob'){ ## max_cleavage_site_probability
		    $signalPeptideLookup->{$featName}->[3] = $score;
		}
		elsif (lc($scoreType) eq 's-mean'){ ## s-mean
		    $signalPeptideLookup->{$featName}->[4] = $score;
		}
		elsif ($scoreType eq 'C-score'){ ## c-score
		    $signalPeptideLookup->{$featName}->[5] = $score;
		}
		elsif ($scoreType eq 'HMM cleavage site'){ ## HMM_cleavage_site
		    $signalPeptideLookup->{$featName}->[6] = $score;
		}
		elsif ($scoreType eq 'S-score'){ ## s-score
		    $signalPeptideLookup->{$featName}->[7] = $score;
		}
		elsif ($scoreType eq 'D-score'){ ## D-score
		    $signalPeptideLookup->{$featName}->[8] = $score;
		}
		else {
		    $logger->warn("Unexpected score_type '$scoreType' ".
				  "for database '$database' asmbl_id '$asmbl_id' ".
				  "feat_name '$featName'");
		}
	    }
	}
    }
    
    return $signalPeptideLookup;
}


##---------------------------------------------------------------------------------------
## storeSignalPeptideFeatureData()
##
##---------------------------------------------------------------------------------------
sub storeSignalPeptideFeatureData {

    my ($database, $bsmlBuilder, $asmbl_id, $prefix, $signalPeptideLookup,
	$assemblySequenceElem, $identifier_feature, $protein_feat_name_to_locus,
	$polypeptideSequenceElemLookup, $polypeptideFeatureTableElemLookup) = @_;


    ## process each ORF's signal peptide
    foreach my $featName ( keys %{$signalPeptideLookup}){

	## re-construct the unique identifier for the signal peptide's
	## corresponding polypeptide
	my $polypeptideIdentifier = &get_uniquename($prism,
						    $database,
						    $asmbl_id,
						    $featName,
						    'polypeptide');
	
	my $polypeptideSequenceIdentifier = $polypeptideIdentifier . '_seq';

	my $polypeptideSequenceElem;
	
	my $polypeptideFeatureTableElem;

	## create a unique identifier for the signal peptide feature
	my $signalPeptideIdentifier = &get_uniquename($prism,
						      $database,
						      $asmbl_id,
						      $featName,
						      'signal_peptide');

	if (exists $polypeptideFeatureTableElemLookup->{$polypeptideIdentifier}){
	    $polypeptideFeatureTableElem = $polypeptideFeatureTableElemLookup->{$polypeptideIdentifier};
	}
	else {
	    ## The corresponding polypeptide did not have a Feature-table

	    

	    if ( exists $polypeptideSequenceElemLookup->{$polypeptideIdentifier}){
		$polypeptideSequenceElem = $polypeptideSequenceElemLookup->{$polypeptideIdentifier};
		
		## Create a Feature-table for this polypeptide now
		$polypeptideFeatureTableElem = $bsmlBuilder->createAndAddFeatureTable($polypeptideSequenceElem);

		if (!defined($polypeptideFeatureTableElem)){
		    $logger->logdie("Could not create a Feature-table for polypeptide ".
				    "'$polypeptideIdentifier'.  database '$database' asmbl_id '$asmbl_id' ".
				    "feat_name '$featName' signal peptide '$signalPeptideIdentifier'");
		}
		else {
		    ## Store the new polypeptide Feature-table in the lookup
		    $polypeptideFeatureTableElemLookup->{$polypeptideIdentifier} = $polypeptideFeatureTableElem;
		}
	    }	    
	    else {
		## I'm assuming that the polypeptide would have already been processed
		## and stored
		$logger->warn("Error occured while attempting to create a signal_peptide feature ".
			      "for ORF '$featName'  -- polypeptide '$polypeptideIdentifier' polypeptideSequenceIdentifier ".
			      "'$polypeptideSequenceIdentifier' signal peptide '$signalPeptideIdentifier ".
			      "database '$database' asmbl_id '$asmbl_id' ".
			      "feat_name '$featName'.  If $database..asm_feature.protein ".
			      "for this ORF is NULL - you need to verify whether the protein belongs to a ".
			      "frameshifted gene.  If not, you need to find out why the value is NULL and fix it.");
		next;
	    }
	}

	## The legacy2bsml.pl script should ensure that
	## //Feature/@id == //Seq-data-import/@identifier 
	## for all sequences/features (bug 2044).
	$identifier_feature->{$signalPeptideIdentifier}++;
	
	my $fmax = $signalPeptideLookup->{$featName}->[0];
	if (!defined($fmax)){
	    $logger->warn("The feat_score.score with common..score_type.score_type = 'site' was not defined ".
			  "for the signal_peptide related to the ORF with feat_name '$featName' for ".
			  "database '$database' asmbl_id '$asmbl_id'.  Setting value '0'.");
	    $fmax=0;
	}

	## <Feature-table> element object reference could belong to
	## the assembly's <Sequence> (default) or the polypeptide's <Sequence>
	my $signalPeptideFeatureElem = $bsmlBuilder->createAndAddFeatureWithLoc(
										$polypeptideFeatureTableElem,   # <Feature-table> element object reference
										$signalPeptideIdentifier,       # id
										undef,                # title
										'signal_peptide',     # class
										undef, ## comment
										undef, ## displayAuto
										0,     ## start
										$fmax, ## stop
										0      ## complement
										);


	if (!defined($signalPeptideFeatureElem)){
	    $logger->logdie("Could not create <Feature> element for signal peptide ".
			    "'$signalPeptideIdentifier' database '$database' ".
			    "asmbl_id '$asmbl_id' feat_name '$featName' ".
			    "polypeptide '$polypeptideIdentifier'");
	}


	my $crossReferenceElem = $bsmlBuilder->createAndAddCrossReference(
									  'parent'          => $signalPeptideFeatureElem,
									  'id'              => $bsmlBuilder->{'xrefctr'}++,
									  'database'        => $prefix,
									  'identifier'      => $featName,
									  'identifier-type' => 'feat_name'
									  );
	
	if (!defined($crossReferenceElem)){
	    $logger->logdie("Could not create a <Cross-reference> element for signal peptide ".
			    "'$signalPeptideIdentifier' database '$database' asmbl_id ".
			    "'$asmbl_id' feat_name '$featName' polypeptide '$polypeptideIdentifier'");
	}
	    

	## Get all of the attributes for this signal peptide
	my $peptideAttributesArray = $signalPeptideLookup->{$featName};

	&storeSignalPeptideAttributes($signalPeptideFeatureElem,
				      $peptideAttributesArray,
				      $featName,
				      $bsmlBuilder,
				      $signalPeptideIdentifier,
				      $database,
				      $asmbl_id,
				      $polypeptideIdentifier);


    
	## Create a <Feature-group> for this signal peptide
	## This will be nested below the assembly <Sequence>
	my $signalPeptideFeatureGroupElem = $bsmlBuilder->createAndAddFeatureGroup(
										   $assemblySequenceElem,   # <Sequence> element object reference
										   undef,                   # id
										   $signalPeptideIdentifier # groupset
										   );  
	
	if (!defined($signalPeptideFeatureGroupElem)){
	    $logger->logdie("Could not create <Feature-group> element for signal peptide '$signalPeptideIdentifier' ".
			    "database '$database' asmbl_id '$asmbl_id' feat_name '$featName' polypeptide ".
			    "'$polypeptideIdentifier'");
	}

	## Add a <Feature-group-member> for this signal peptide
	my $signalPeptideFeatureGroupMemberElem = $bsmlBuilder->createAndAddFeatureGroupMember(
											       $signalPeptideFeatureGroupElem,  # <Feature-group> element object reference
											       $signalPeptideIdentifier,          # featref
											       'signal_peptide',     # feattype
											       undef,                # grouptype
											       undef,                # cdata
											       ); 
	if (!defined($signalPeptideFeatureGroupMemberElem)){
	    $logger->logdie("Could not create <Feature-group-member> element for signal peptide '$signalPeptideIdentifier' ".
			    "database '$database' asmbl_id '$asmbl_id' feat_name '$featName' polypeptide ".
			    "'$polypeptideIdentifier'");
	}


	## Add the polypeptide to the <Feature-group>
	if ((exists $protein_feat_name_to_locus->{$featName}) && 
	    (defined($protein_feat_name_to_locus->{$featName}))){
	    
	    my $polypeptideFeatureIdentifier = $protein_feat_name_to_locus->{$featName};
	    
	    my $polypeptideFeatureGroupMemberElem = $bsmlBuilder->createAndAddFeatureGroupMember(
												 $signalPeptideFeatureGroupElem,  # <Feature-group> element object reference
												 $polypeptideFeatureIdentifier,   # featref
												 'polypeptide',                   # feattype
												 undef,                           # grouptype
												 undef,                           # cdata
												 ); 
	    if (!defined($polypeptideFeatureGroupMemberElem)){
		$logger->logdie("Could not create <Feature-group-member> for polypeptide '$polypeptideFeatureIdentifier' ".
				"database '$database' asmbl_id '$asmbl_id' feat_name '$featName' signal peptide ".
				"'$signalPeptideIdentifier'");
	    }
	}
	else {
	    $logger->warn("polypeptide Feature identifier does not exist on the protein_feat_name_to_locus lookup ".
			  "for database '$database' asmbl_id '$asmbl_id' feat_name '$featName' ".
			  "signal peptide '$signalPeptideIdentifier' polypeptide Sequence '$polypeptideIdentifier'");
	}
    }
}


##---------------------------------------------------------------------------
## storeSignalPeptideAttributes()
##
##---------------------------------------------------------------------------
sub storeSignalPeptideAttributes {

    my ( $signalPeptideFeatureElem, $peptideAttributesArray, $featName, $bsmlBuilder,
	 $signalPeptideIdentifier, $database, $asmbl_id, $polypeptideIdentifier) = @_;
	    

    if (defined($peptideAttributesArray->[0])){
	
	my $attributeElem = $bsmlBuilder->createAndAddBsmlAttribute(
								    $signalPeptideFeatureElem,      # <Feature> element object reference
								    'NN_cleavage_site_probability', # name
								    $peptideAttributesArray->[0]    # content
								    );
	
	if (!defined($attributeElem)){
	    $logger->logdie("Could not create <Attribute> element for signal peptide '$signalPeptideIdentifier' ".
			    "for attribute 'NN_cleavage_site_probability' value '$peptideAttributesArray->[0] ".
			    "database '$database' asmbl_id '$asmbl_id' feat_name '$featName' polypeptide '$polypeptideIdentifier' ");
	}
    }


    if (defined($peptideAttributesArray->[1])){
	
	my $attributeElem = $bsmlBuilder->createAndAddBsmlAttribute(
								    $signalPeptideFeatureElem,      # <Feature> element object reference
								    'y-score', # name
								    $peptideAttributesArray->[1]    # content
								    );
	
	if (!defined($attributeElem)){
	    $logger->logdie("Could not create <Attribute> element for signal peptide '$signalPeptideIdentifier' ".
			    "for attribute 'y-score' value '$peptideAttributesArray->[1] ".
			    "database '$database' asmbl_id '$asmbl_id' feat_name '$featName' polypeptide '$polypeptideIdentifier' ");
	}
    }


    if (defined($peptideAttributesArray->[2])){
	
	my $attributeElem = $bsmlBuilder->createAndAddBsmlAttribute(
								    $signalPeptideFeatureElem,      # <Feature> element object reference
								    'signal_probability', # name
								    $peptideAttributesArray->[2]    # content
								    );
	
	if (!defined($attributeElem)){
	    $logger->logdie("Could not create <Attribute> element for signal peptide '$signalPeptideIdentifier' ".
			    "for attribute 'signal_probability' value '$peptideAttributesArray->[2] ".
			    "database '$database' asmbl_id '$asmbl_id' feat_name '$featName' polypeptide '$polypeptideIdentifier' ");
	}
    }


    if (defined($peptideAttributesArray->[3])){
	
	my $attributeElem = $bsmlBuilder->createAndAddBsmlAttribute(
								    $signalPeptideFeatureElem,      # <Feature> element object reference
								    'max_cleavage_site_probability', # name
								    $peptideAttributesArray->[3]    # content
								    );
	
	if (!defined($attributeElem)){
	    $logger->logdie("Could not create <Attribute> element for signal peptide '$signalPeptideIdentifier' ".
			    "for attribute 'max_cleavage_site_probability' value '$peptideAttributesArray->[3] ".
			    "database '$database' asmbl_id '$asmbl_id' feat_name '$featName' polypeptide '$polypeptideIdentifier' ");
	}
    }


    if (defined($peptideAttributesArray->[4])){
	
	my $attributeElem = $bsmlBuilder->createAndAddBsmlAttribute(
								    $signalPeptideFeatureElem,      # <Feature> element object reference
								    's-mean', # name
								    $peptideAttributesArray->[4]    # content
								    );
	
	if (!defined($attributeElem)){
	    $logger->logdie("Could not create <Attribute> element for signal peptide '$signalPeptideIdentifier' ".
			    "for attribute 's-mean' value '$peptideAttributesArray->[4] ".
			    "database '$database' asmbl_id '$asmbl_id' feat_name '$featName' polypeptide '$polypeptideIdentifier' ");
	}
    }


    if (defined($peptideAttributesArray->[5])){
	
	my $attributeElem = $bsmlBuilder->createAndAddBsmlAttribute(
								    $signalPeptideFeatureElem,      # <Feature> element object reference
								    'c-score', # name
								    $peptideAttributesArray->[5]    # content
								    );
	
	if (!defined($attributeElem)){
	    $logger->logdie("Could not create <Attribute> element for signal peptide '$signalPeptideIdentifier' ".
			    "for attribute 'c-score' value '$peptideAttributesArray->[5] ".
			    "database '$database' asmbl_id '$asmbl_id' feat_name '$featName' polypeptide '$polypeptideIdentifier' ");
	}
    }

    if (defined($peptideAttributesArray->[6])){
	
	my $attributeElem = $bsmlBuilder->createAndAddBsmlAttribute(
								    $signalPeptideFeatureElem,      # <Feature> element object reference
								    'HMM_cleavage_site', # name
								    $peptideAttributesArray->[6]    # content
								    );
	
	if (!defined($attributeElem)){
	    $logger->logdie("Could not create <Attribute> element for signal peptide '$signalPeptideIdentifier' ".
			    "for attribute 'HMM_cleavage_site' value '$peptideAttributesArray->[6] ".
			    "database '$database' asmbl_id '$asmbl_id' feat_name '$featName' polypeptide '$polypeptideIdentifier' ");
	}
    }
    if (defined($peptideAttributesArray->[7])){
	
	my $attributeElem = $bsmlBuilder->createAndAddBsmlAttribute(
								    $signalPeptideFeatureElem,      # <Feature> element object reference
								    's-score', # name
								    $peptideAttributesArray->[7]    # content
								    );
	
	if (!defined($attributeElem)){
	    $logger->logdie("Could not create <Attribute> element for signal peptide '$signalPeptideIdentifier' ".
			    "for attribute 's-score' value '$peptideAttributesArray->[7] ".
			    "database '$database' asmbl_id '$asmbl_id' feat_name '$featName' polypeptide '$polypeptideIdentifier' ");
	}
    }

    if (defined($peptideAttributesArray->[8])){
	
	my $attributeElem = $bsmlBuilder->createAndAddBsmlAttribute(
								    $signalPeptideFeatureElem,      # <Feature> element object reference
								    'd-score', # name
								    $peptideAttributesArray->[8]    # content
								    );
	
	if (!defined($attributeElem)){
	    $logger->logdie("Could not create <Attribute> element for signal peptide '$signalPeptideIdentifier' ".
			    "for attribute 'd-score' value '$peptideAttributesArray->[8] ".
			    "database '$database' asmbl_id '$asmbl_id' feat_name '$featName' polypeptide '$polypeptideIdentifier' ");
	}
    }

}

#-----------------------------------------------------------------------------------
# check_id_repository()
#
#-----------------------------------------------------------------------------------
sub check_id_repository {

    my ($idRepository, $no_idgenerator) = @_;

    if ((defined($no_idgenerator)) && ($no_idgenerator == 1)){

	$logger->info("User has specified --no_idgenerator=1 so will not use IdGenerator service");

	$ENV{NO_ID_GENERATOR} = 1;
    }


    my $idUtil = new Annotation::IdGenerator::Ergatis::Util(repository=>$idRepository);
    
    if (!defined($idUtil)){

	$logger->logdie("Could not instantiate Annotation::".
			"IdGenerator::Ergatis::Util for ".
			"repository '$idRepository'");
    }

    if ( $idUtil->isRepositoryValid()){

	$logger->info("setting _id_repository to '$idRepository'");
	
	$ENV{ID_REPOSITORY} = $idRepository;
    }
}


##--------------------------------------------------------
## writeCloneInfoAttributesToBsml()
##
##--------------------------------------------------------
sub writeCloneInfoAttributesToBsml {

    my ($lookup, $doc, $assembly_sequence_elem, $asmbl_uniquename) = @_;

    foreach my $cloneinfotype ( keys %{$cloneInfoTypes} ){
	
	if ( ( exists $lookup->{$cloneinfotype}) && (defined ( $lookup->{$cloneinfotype} ) ) ) {

	    my $value  = $lookup->{$cloneinfotype};

	    ## strip leading and trailing white-spaces
	    $value =~ s/^\s+//;
	    $value =~ s/\s+$//;

	    ## Need to skip any attribute whose length is equal to zero else we will end up inserting an <Attribute> with empty content
	    if (length($value) < 1 ){
		$logger->warn("Encountered an attribute of type '$cloneinfotype' that really did not have any content. ".
			      "You should inform the appropriate person, some clean-up in the source legacy annotation ".
			      "database may be required.  Skipping this attribute.");
		next;
	    }
	    
	    my $attribute_elem = $doc->createAndAddBsmlAttribute(
								 $assembly_sequence_elem,
								 $cloneinfotype,
								 $value );
	    
	    if (!defined($attribute_elem)){
		$logger->logdie("Could not create a BSML <Attribute> object with name=\"$cloneinfotype\" content=\"$value\" ".
				"while processing assembly '$asmbl_uniquename'");
	    }
	}
    }
}

