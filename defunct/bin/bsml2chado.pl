#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#-----------------------------------------------------------------------
# program:   bsml2chado.pl
# author:    Jay Sundaram
# date:      2004/03/18
# 
# purpose:   Parses BSML documents and produces tab delimited .out BCP
#            files for insertion into Chado database
#
#
#-------------------------------------------------------------------------


=head1 NAME

bsml2chado.pl - Parse BSML document and produce tab delimited .out BCP files for insertion into Chado database

=head1 SYNOPSIS

USAGE:  bsml2chado.pl -D database --database_type -P password -U username --server [-a autogen_feat] -b bsmldoc [--checksum_placeholders] [-d debug_level] [--exclude_classes] [--gzip_bcp] [-h] [--id_repository] [-i insert_new] [-l logfile] [-m] [-o outdir] [-p] [-R readonlycache] [-s autogen_seq] [--timestamp] [-u update] [-x xml_schema_type] [-y cache_dir] [-z doctype] [--append_bcp] [--parse-match-sequence-fasta]

=head1 OPTIONS

=over 8

=item B<--username,-U>

Database username

=item B<--password,-P>

Database password

=item B<--database,-D>

Target chado database 

=item B<--database_type>

Relational database management system type e.g. sybase or postgresql

=item B<--server>

Name of server on which the database resides

=item B<--bsmldoc,-b>

Bsml document containing pairwise alignment encodings

=item B<--autogen_feat,-a>

Optional - Default behavior is to auto-generate (-a=1) chado feature.uniquename values for all inbound features.  To turn off behavior specify this command-line option (-a=0).

=item B<--autogen_seq,-s>

Optional - Default behavior is to not (-s=0) auto-generate chado feature.uniquename values for all inbound sequences.  To turn on behavior specify this command-line option (-s=1).

=item B<--insert_new,-i>

Optional - Default behavior is to insert (-i=1) insert newly encountered Sequence objects in the BSML document that are not currently present in the Chado database.  To turn off default insert behavior specify this command-line option (-i=0)

=item B<--id_repository>

Optional - IdGenerator.pm stores files for tracking unique identifier values - some directory e.g. /usr/local/scratch/annotation/CHADO_TEST6/workflow/project_id_repository should be specified.  Default directory is ENV{ID_REPOSITORY}.

=item B<--debug_level,-d>

 Optional: Coati::Logger Log4perl logging level.  Default is 0

=item B<--man,-m>

Display the pod2usage page for this utility

=item B<--outdir,-o>

 Optional: Output directory for the tab delimited .out files.  Default is current directory

=item B<--no-placeholders>

Optional - Do not insert placeholders variables in place of table serial identifiers (default is to insert placeholder variables)

=item B<--timestamp>

Optional - Time stamp e.g.  'Jun  5 2006  6:59PM' to be stored in feature.timeaccessioned (if required), feature.timelastmodified, analysis.timeexecuted
Default behavior is to auto-generate the timestamp.

=item B<--update,-u>

Optional - Default behavior is to not update the database (-u=0).  To turn on update behavior specify this command-line option (-u=1).

=item B<--cache_dir,-y>

Optional - Query caching directory to write cache files (default is ENV{DBCACHE_DIR})

=item B<--readonlycache,-R>

Optional - If data file caching is activated and if this readonlycache is == 1, then the tied MLDBM lookup cache files can only be accessed in read-only mode.  Default (-r=0) means cached lookup can be created and access mode is read-write.

=item B<--doctype,-z>

Optional - If specified, can direct the parser to construct concise lookup - more efficient. One of the following: nucmer, region, promer, pe, blastp, repeat, scaffold, rna, te, coverage

=item B<--help,-h>

Print this help

=item B<--gzip_bcp>

Optional - writes the BCP .out files in compressed format with .out.gz file extension

=item B<--parse-match-sequence-fasta>

Optional - If specified, bsml2chado.pl will parse the Seq-data-import and FASTA file associated with the 'match' Sequence stubs.  Default behaviour is to ignore these Sequence stubs' FASTA data.

=item B<--exclude_classes>

Optional - If specified, bsml2chado.pl will skip all Sequence and Feature objects that have anyone of the listed classes

=back

=head1 DESCRIPTION

bsml2chado.pl - Parse BSML document and produce tab delimited .out BCP files for insertion into Chado database

 Assumptions:
1. The BSML pairwise alignment encoding should validate against the XML schema:.
2. User has appropriate permissions (to execute script, access chado database, write to output directory).
3. Target chado database already contains all reference features (necessary to build feature and organism lookups) Review and execute db2bsml.pl if required.
4. Target chado database contains the necessary controlled vocabulary terms: "match" etc.
5. All software has been properly installed, all required libraries are accessible.

Sample usage:
./bsml2chado.pl -U access -P access -D tryp -b /usr/local/annotation/TRYP/BSML_repository/blastp/lma2_86_assembly.blastp.bsml  -l my.log -o /tmp/outdir


=cut


use strict;
use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Digest::MD5 qw(md5);
use BSML::BsmlReader;
use BSML::BsmlParserSerialSearch;
use BSML::BsmlParserTwig;
use Coati::Logger;
use Config::IniFiles;
use Tie::File;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($username, $password, $bsmldoc, $database, $server, $debug_level, 
    $help, $logfile, $filter_count, $filter, $xml_schema_type, $man, 
    $outdir, $autogen_feat, $autogen_seq, $insert_new, $no_placeholders, 
    $cache_dir, $update, $doctype, $lookup_type, $readonlycache, 
    $append_bcp, $checksum_placeholders, $timestamp, $id_repository, 
    $gzip_bcp, $parse_match_sequence_fasta, $exclude_classes, $database_type,
    $recordCountFile);


my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'bsmldoc|b=s'         => \$bsmldoc,
			  'database|D=s'        => \$database,
			  'server=s'            => \$server,
			  'filter_count|r=s'    => \$filter_count,
			  'filter|t=s'          => \$filter,
			  'logfile|l=s'         => \$logfile,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'xml_schema_type|x=s' => \$xml_schema_type,
			  'outdir|o=s'          => \$outdir,
			  'autogen_feat|a=s'    => \$autogen_feat,
			  'autogen_seq|s=s'     => \$autogen_seq,
			  'insert_new|i=s'      => \$insert_new,
			  'no-placeholders'     => \$no_placeholders,
			  'cache_dir|y=s'       => \$cache_dir,
			  'update|u=s'          => \$update,
			  'doctype|z=s'         => \$doctype,
			  'lookup_type|L=s'     => \$lookup_type,
			  'readonlycache|R=s'   => \$readonlycache,
			  'append_bcp=s'        => \$append_bcp,
			  'checksum_placeholders=s'  => \$checksum_placeholders,
			  'timestamp=s'              => \$timestamp,
			  'id_repository=s'          => \$id_repository,
			  'gzip_bcp=s'                   => \$gzip_bcp,
			  'parse_match_sequence_fasta=s' => \$parse_match_sequence_fasta,
			  'exclude_classes=s'            => \$exclude_classes,
			  'database_type=s'              => \$database_type,
			  'record_count_file=s'             => \$recordCountFile
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

if ($fatalCtr>0){
    &print_usage();
}


$autogen_feat = 1 if (!defined($autogen_feat));
$insert_new   = 1 if (!defined($insert_new));

#
# If these variables are defined, they should be either 0 or 1
#
die ("autogen_feat '$autogen_feat' must be either 0 or 1\n") if (($autogen_feat !~ /^0|1$/) and (defined($autogen_feat)));
die ("autogen_seq '$autogen_seq' must be either 0 or 1\n")   if (($autogen_seq !~ /^0|1$/)  and (defined($autogen_seq)));
die ("insert_new '$insert_new' must be either 0 or 1\n")     if (($insert_new !~ /^0|1$/)   and (defined($insert_new)));


## Default behaviour is to not parse the FASTA files of the match Sequence stubs
$parse_match_sequence_fasta = 0 if (!defined($parse_match_sequence_fasta));


#
# If these variables are == 0, undefine them
#
$autogen_feat = undef if ($autogen_feat == 0);
$autogen_seq  = undef if ($autogen_seq == 0);
$insert_new   = undef if ($insert_new == 0);
$update       = undef if ($update == 0);

#
# Get the Log4perl logger
#
my $logger = &set_logger($logfile, $debug_level);

my $validDatabaseTypes = { 'postgresql' => 1,
                           'sybase' => 1,
                           'mysql' => 1};

my $mysqlDelimiters = { '_row_delimiter' => "\n",
                        '_field_delimiter' => "\t" };

my $postgresqlDelimiters = { '_row_delimiter' => "\n",
			     '_field_delimiter' => "\t" };

my $sybaseDelimiters = { '_row_delimiter' => "\0\n",
			 '_field_delimiter' => "\0\t" };

my $databaseTypeToDelimiterLookup = { 'postgresql' => $postgresqlDelimiters,
                                      'sybase' => $sybaseDelimiters,
                                      'mysql' => $mysqlDelimiters };

my $databaseTypeToBulkVendorLookup = { 'postgresql' => 'BulkPostgres',
				   'sybase' => 'BulkSybase',
				   'mysql' => 'BulkMysql',
				   'oracle' => 'BulkOracle' };

if (defined($database_type)){
    $database_type = 'postgresql' if ($database_type eq 'postgres');
    if (!exists $validDatabaseTypes->{$database_type}){
	$logger->logdie("Unsupported database type '$database_type'");
    }
}
else {
    $database_type = 'sybase';
}

#
# Set the PRISM environmenatal variable
#
&set_prism_env($server, $databaseTypeToBulkVendorLookup->{$database_type});

#
# Set the cache directory properties
#
&set_cache($cache_dir, $readonlycache);

#
# verify and set the output directory
#
$outdir = &verify_and_set_outdir($outdir);

#
# Check permissions of the bsml document
#
$bsmldoc = &is_file_readable($bsmldoc);

$logger->info("Processing bsmldoc '$bsmldoc'");

if (!$recordCountFile){
    my $basename = File::Basename::basename($bsmldoc);
    $recordCountFile = $outdir . '/' . $basename . '_record_count.rpt';
    print STDERR "record count file was not specified and ".
    "therefore was set to '$recordCountFile'\n";
}


#
# Instantiate BsmlReader object
#
my $bsml_reader = &retrieve_bsml_reader();

#
# Get the next values if running in append_bcp mode
#
my $next_bcp_values;

if ((defined($checksum_placeholders)) && ($checksum_placeholders == 1)){
    #
    # We don't need the next serial identifier values if using checksum placeholder values
    #
}
else {
    $next_bcp_values = &dir_contains_bcp_files($outdir, $append_bcp);
}

#
# Make sure the specified id_repository exists
#
&check_id_repository($id_repository);

#
# Instantiate Prism object
#
my $prism = &retrieve_prism_object($username, 
				   $password,
				   $database,
				   $no_placeholders,
				   $append_bcp, 
				   $next_bcp_values,
				   $checksum_placeholders, 
				   $gzip_bcp,
				   $databaseTypeToDelimiterLookup->{$database_type}->{'_row_delimiter'},
				   $databaseTypeToDelimiterLookup->{$database_type}->{'_field_delimiter'},
				   );

my $exclude_classes_lookup = &get_classes_lookup($exclude_classes);

#
# Generate Sybase formatted date and time stamp if necessary
#
if (!defined($timestamp)){
    $timestamp = $prism->get_sybase_datetime();
}

#
# Generate the static MLDBM tied lookups
#
&load_lookups($prism, $no_placeholders);


#
# Update mode support
#
&activate_update_mode($prism, $update, $lookup_type);


#
# Non-static lookups
#
my $feature_id_lookup_d = {};


#
# BSML element counters
#
my $bsml_element_counter = {};


my $organism_id;

my $sequence_lookup = {};


my $feature_id_lookup = $prism->master_feature_id_lookup($doctype);


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Serially parse BSML docuemnt
#
# Step 1: Parser 1 (AnalysisCallBack)
#
# Step 2: Parser 2 (GenomeCallBack and SequenceCallBack):
#
# Reads in a immediately processes Genome components.
# Reads in all Sequences and stores in memory.
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
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
print "Parsing now...\n";


#---------------------------------------------------------------------------------
# 2005.04.09
#
# Retrieve/insert the 'not known' organism_id from/into chado.organism
#
# In the past we would store a dummy organism value for all multiple
# alignment features.  This value was 'cog'.
# Rather than insert 'cog' in every field of the organism record, we
# now insert 'not known'.   
#
# We extend the use of this 'not known' organism in the following was:
#
# The corresponding organism.organism_id will be assigned to feature
# records for those sequences designated 'sequence type 1'.  These are
# BSML <Sequence> components which do not contain any <Feature-tables>
# sub-element.
#
# Typically, these type 1 sequences are inserted into the BSML document
# to satisfy the DTD requirement which stipulates that all identified refseqs
# and compseqs in a given BSML document, the sequences which they reference must
# be present in the same document as a <Sequence> or <Feature>.
#
# Note that in the near future we may explore ways of extending the referencing
# of sequences beyond the current document.  That is a refseq and/or compseq
# may reference a <Sequence> in another BSML document.
#
#
#
#----------------------------------------------------------------------------------

#
# Keep a list of all previously processed uniquename
#
my $prevprocessed = [];


## Temporarily declaring $analysis_id and $compute_type
## as a global variables in order to support 
## Prism::store_bsml_multiple_alignment_table()
my ($analysis_id, $compute_type);

## This lookup will be passed by reference to the
## store_bsml_sequence_component() method.  
## The lookup will contain a mapping between
##  //Analysis/@id and analysis_ids (bgzcase 2184)
my $analyses_identifier_lookup = {};


my $bsmlparser = new BSML::BsmlParserSerialSearch(
						  AnalysisCallBack  => sub {

						      my ($analysis_ref) = @_;
						      
						      $bsml_element_counter->{'Analysis'}++;

						      &show_count("\n<Analysis> $bsml_element_counter->{'Analysis'}") if $logger->is_info;


						      my $analysisIdentifier;

						      if (( exists $analysis_ref->{'attr'}->{'id'}) && (defined($analysis_ref->{'attr'}->{'id'})) ){

							  $analysisIdentifier = $analysis_ref->{'attr'}->{'id'};

						      }
						      else {
							  $logger->logdie("analysis identifier was not defined!");
						      }


						      #
						      # Small change to accomodate old method of parsing and passing analysis_id and compute_type from the BSML and passing to Prism::store_bsml_multiple_alignment_table().
						      # That is - $analysis_id and $compute_type are now global.

						      ($analysis_id, $compute_type) = $prism->store_bsml_analysis_component(
															    timestamp       => $timestamp,
															    BsmlAttr        => $analysis_ref->{'BsmlAttr'},
															    bsmldoc         => $bsmldoc
															    );
						      


						      $logger->debug("analysisIdentifier '$analysisIdentifier' analysis_id '$analysis_id' compute_type '$compute_type'") if $logger->is_debug();
						      

						      ## The //Analysis/@id should be associated with the newly
						      ## created analysis_id.  This analysis_id can be later looked
						      ## up in the store_bsml_sequence_component() method during 
						      ## which an analysisfeature record will be store.  This will
						      ## facilitate linking the Sequence feature to the analysis in
						      ## chado (bgz 2184)).
						      #
						      if ((exists $analyses_identifier_lookup->{$analysisIdentifier}) && (defined($analyses_identifier_lookup->{$analysisIdentifier}))){
							  #
							  # This analysis_id has already been stored in the lookup.
							  #
							  $logger->logdie("analysis_id '$analysis_id' was already stored in the analyses_identifier_lookup for analysisIdentifier '$analysisIdentifier'");
						      }
						      else{
							  $analyses_identifier_lookup->{$analysisIdentifier} = { analysis_id => $analysis_id,
														 compute_type => $compute_type };
						      }
						  }
						  );
$bsmlparser->parse($bsmldoc);

my $residue_lookup;
my $all_sequence_lookup;

print "Parsing and processing <Genome> components. Parsing and caching both Type 1 and Type 2 <Sequence> elements.\n";


## Read and process all Genome components.
## Read and buffer all Sequence components.  
## Will ignore nested Feature-tables.

my $genome_id_2_organism_id = {};

## The order of the encountered Sequence elements must be preserved (bgz2118).
my $sequence_order = [];

my $bsmlparser2 = new BSML::BsmlParserSerialSearch(

						   ReadFeatureTables => 0,
						   GenomeCallBack => sub {


						       #-----------------------------------------------------------------------------------
						       # Genome Callback 
						       #
						       #-----------------------------------------------------------------------------------
						       

						       my $genref = shift;

						       $bsml_element_counter->{'Genome'}++;

						       &show_count("\n<Genome> $bsml_element_counter->{'Genome'}") if $logger->is_info;

						       ## Retrieve the genome ID.  If the ID is not available, the loader should halt.
						       my $genome_id;

						       if (( exists $genref->{'attr'}->{'id'} ) && ( defined ( $genref->{'attr'}->{'id'}) )){
							   
							   $genome_id = $genref->{'attr'}->{'id'};
						       }
						       else{
							   $logger->logdie("genome_id was not defined for: " .  Dumper $genref);
						       }



						       #------------------------------------------------------------------------------------------
						       # editor:  sundaram@tigr.org
						       # date:    2005-10-24
						       # comment: I have removed the check performed in this anonymous subroutine
						       #          (which determined whether the particular genus and species was already
						       #          loaded in the chado database during a previous session.   Performing
						       #          the check was restrictive.  By removing the check, the code in 
						       #          Prism::store_bsml_genome_component() is permitted to execute even if
						       #          the genus and species were loaded previously.  
						       #
						       #          This behavior is more desireable since any additional organism cross-reference and/or
						       #          attributes data which may be encoded in the more recently processed BSML document
						       #          should be loaded into the database as well.
						       #
						       #						   
						       $organism_id = $prism->store_bsml_genome_component( BsmlOrganism       => $genref->{'BsmlOrganism'},
													   BsmlCrossReference => $genref->{'BsmlCrossReference'});
						       $logger->logdie("organism_id was not defined") if (!defined($organism_id));
						       #
						       #------------------------------------------------------------------------------------------
						       
						       ## Store the organism_id in the genome_id to organism_id lookup.
						       ## All sequences will now attempt to resolve //Sequence/Link/@ref
						       ## in order to determine correct organism_id assignment (bgz 2053).
						       $genome_id_2_organism_id->{$genome_id} = $organism_id;

						   },
						   SequenceCallBack  => sub {
						       
						       
						       #-----------------------------------------------------------------------------------
						       # Sequence Callback 
						       #
						       #-----------------------------------------------------------------------------------
						       
						       my ($seqref) = shift;

						       ## This SequenceCallBack handler will parse all Sequence elements and 
						       ## cache all references in the all_sequence_lookup.
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

						       $bsml_element_counter->{'Sequence'}++;

						       if ($logger->is_info()){
							   &show_count("\n<Sequence> $bsml_element_counter->{'Sequence'}");
						       }


						       my $sequence        = $seqref->{'attr'};
						       my $attributes      = $seqref->{'BsmlAttr'};
						       my $attribute_lists = $seqref->{'BsmlAttributeList'};
						       my $numbering       = $seqref->{'BsmlNumbering'};
						       my $xref            = $seqref->{'BsmlCrossReference'};
						       my $bsmllink        = $seqref->{'BsmlLink'};

						       my ($is_input_of, $is_analysis_linked) = &is_input_of($bsmllink);

						       my $seqdat;

						       if ($is_analysis_linked) {

							   if (( $is_input_of ) || ($parse_match_sequence_fasta) ){

							       ## Retrieves all nucleotide/aminoacid sequences from <Seq-data> and/or <Seq-data-import>
							       $seqdat = $bsml_reader->subSequence($seqref, -1, 0,0);
							       
							       ## Store the data on the residue_lookup
							       $residue_lookup->{$sequence->{'id'}} = $seqdat;
							   }
						       }
						       else {

							   ## Retrieves all nucleotide/aminoacid sequences from <Seq-data> and/or <Seq-data-import>
							   $seqdat = $bsml_reader->subSequence($seqref, -1, 0,0);
							   
							   ## Store the data on the residue_lookup
							   $residue_lookup->{$sequence->{'id'}} = $seqdat;
						       }

						       ## The order of the encountered Sequence elements must be 
						       ## preserved (bgz 2118).
						       push (@{$sequence_order}, $sequence->{'id'});

						       #
						       # Extract the //Sequence/@topology for insertion into chado.featureprop.value
						       #
						       if ((exists $seqref->{'attr'}->{'topology'}) && (defined($seqref->{'attr'}->{'topology'}))) {

							   push(@{$attributes->{'topology'}}, $seqref->{'attr'}->{'topology'});
							   
							   delete $seqref->{'attr'}->{'topology'};
							   
						       }

						       $all_sequence_lookup->{$sequence->{'id'}} = {
							   sequence        => $sequence,
							   attributes      => $attributes,
							   attribute_lists => $attribute_lists,
							   numbering       => $numbering,
							   xref            => $xref,
							   seqdat          => $seqdat,
							   bsmllink        => $bsmllink
						       };
						   });

if (!defined($bsmlparser2)){
    $logger->logdie("bsmlparser2 was not defined");
}
$bsmlparser2->parse($bsmldoc);


my $processedSequencesLookup = {};

print "Processing all cached Type 2 <Sequence> elements.  Parsing and processing associated <Feature> elements.  Skipping all Type 2 <Sequence> elements with '_seq'.\n";

my $sfg = {};
my $sequence_2_feature = {};

## Need to store the exon features' fmin and complement in order to 
## correctly set feature_relationship.rank values (bgz 2253).
my $exon_coordinates = {};

my $type2_seqSequencesToFeatureLookup = {};

my $polypeptideToOrganismIdLookup = {};

## For storing Feature-group references
my $featureGroupRef;

## organism_id for genus = 'not known' species = 'not known'
my $dummy_organism_id = $prism->dummy_organism();

my $bsmlparser3 = new BSML::BsmlParserSerialSearch( SeqFeatureCallBack => sub {   
    
    #
    # Note that the SeqFeatureCallBack handler will only parse type 2 Sequence 
    # elements (Sequences that do have nested Feature-tables).
    #
    # In this section we first process type 2 Sequence by invoking
    # Prism's store_bsml_sequence_component() and then we process all of the
    # Features associated with that type 2 Sequence by invoking the
    # storeBsmlFeatureComponentInChado().
    #
    # Typical type 2 Sequences include assembly, contig, supercontig as well
    # as polypeptide_seq types.  The polypeptide_seq types are now type 2
    # Sequences because we are localizing the splice_site Features to the
    # corresponding polypeptides.
    #

    my ($listref) = shift;
    

    # Reference to this Type 2 Sequence
    my $seqref  = $listref->[1];

    # Reference to list of all Features associated with this Type 2 Sequence
    my $featref = $listref->[0];

    # This is the primary identifier of the Sequence object
    my $sequence_id = $seqref->returnattr('id');

    if ($sequence_id !~ /_seq$/){
	## only want to process the real Sequence objects like assembly, contig
	## and not Sequences that are Linked to some Feature like CDS, polypeptide
	    
	if ( ! exists $processedSequencesLookup->{$sequence_id}) {
	    
	    ## This Type 2 Sequence has NOT yet been processed

	    ## Seeing the Sequence for the first time, therefore need to retrieve
	    ## all relevant data and process it ASAP.
	    my $sequence        = $all_sequence_lookup->{$sequence_id}->{'sequence'};
	    my $attributes      = $all_sequence_lookup->{$sequence_id}->{'attributes'};
	    my $attribute_lists = $all_sequence_lookup->{$sequence_id}->{'attribute_lists'};
	    my $numbering       = $all_sequence_lookup->{$sequence_id}->{'numbering'};
	    my $xref            = $all_sequence_lookup->{$sequence_id}->{'xref'};
	    my $seqdat          = $all_sequence_lookup->{$sequence_id}->{'seqdat'};
	    my $bsmllink        = $all_sequence_lookup->{$sequence_id}->{'bsmllink'};
	    
	    #
	    # Un-define all the Type 2 Sequences references in this all_sequence_lookup.
	    # We do not want to process these again when we process the Type 1 Sequences.
	    #
	    delete $all_sequence_lookup->{$sequence_id};

	    #
	    # All relevant data retrieved, now time to process
	    #
	    $prism->store_bsml_sequence_component(
						  BsmlAttr          => $attributes,
						  BsmlAttributeList => $attribute_lists,
						  seqdat            => $seqdat,
						  BsmlNumbering     => $numbering,
						  seqobj            => $sequence,
						  timestamp         => $timestamp,
						  feature_id_lookup => $feature_id_lookup,
						  feature_id_lookup_d => $feature_id_lookup_d,
						  autogen           => $autogen_seq,
						  insert_new        => $insert_new,
						  update            => $update,
						  BsmlCrossReference => $xref,
						  prevprocessed     => $prevprocessed,
						  sequence_lookup   => $sequence_lookup,
						  BsmlLink          => $bsmllink,
						  genome_id_2_organism_id => $genome_id_2_organism_id,
						  analyses_identifier_lookup  => $analyses_identifier_lookup,
						  dummy_organism_id => $dummy_organism_id,
						  exclude_classes_lookup => $exclude_classes_lookup
						  );



	    # Remember that this Sequence was processed.
	    $processedSequencesLookup->{$sequence_id}++;
	}
	#
	# Parent Sequence (Type 2 Sequence) was processed, now process the associated subfeatures.
	#
	$bsml_element_counter->{'Feature'}++;
	
	if ($logger->is_info()) {
	    
	    &show_count("\n<Feature> $bsml_element_counter->{'Feature'}");
	}

	## All calls to BsmlReader.pm should be deprecated.
	## Will not call BsmlReader::readFeatures() (bgz 2028).

	$prism->storeBsmlFeatureComponentInChado(
						 sequence_uniquename => $sequence_id,
						 feature             => $featref,
						 timestamp           => $timestamp,
						 feature_id_lookup   => $feature_id_lookup,
						 autogen             => $autogen_feat,
						 insert_new          => $insert_new,
						 update              => $update,
						 prevprocessed       => $prevprocessed,
						 sequence_lookup     => $sequence_lookup,
						 residue_lookup      => $residue_lookup,
						 sequence_2_feature  => $sequence_2_feature,
						 feature_id_lookup_d => $feature_id_lookup_d,
						 analyses_identifier_lookup  => $analyses_identifier_lookup,
						 exon_coordinates            => $exon_coordinates,
						 exclude_classes_lookup => $exclude_classes_lookup,
						 polypeptideToOrganismIdLookup => $polypeptideToOrganismIdLookup
						 );
	
    }
    else {
	## At this point we are only storing Sequences that have a _seq suffix.
	## Since the SeqFeatureCallBack function will only parse Sequences that
	## have some Feature-table, we are therefore only storing Type 2 Sequences
	## in the type2_seqSequencesToFeatureLookup.
	## An example of the type of Sequence being stored here might be a 
	## polypeptide Sequence that contains a Feature-table having
	## splice_site and/or signal_peptide Features.
	push (@{$type2_seqSequencesToFeatureLookup->{$sequence_id}}, $featref);
    }
    
},
						    SequenceCallBack   => sub {
							my $seqref = shift;
							
							if (!exists $sfg->{$seqref->returnattr('id')}){
							    
							    $sfg->{$seqref->returnattr('id')}++;
							    
							    push (@{$featureGroupRef} , @{$seqref->{'BsmlFeatureGroups'}}); 
							    
							}
						    }
						    );



$logger->logdie("bsmlparser3 was not defined") if (!defined($bsmlparser3));
$bsmlparser3->parse($bsmldoc);

##----------------------------------------------------------------------------------------------
## Process all of the Features associated with some Type 2 Sequence having _seq suffix
## These may include splice_site and/or signal peptide Features that are localized to some
## polypeptide Sequence.
##
##-----------------------------------------------------------------------------------------------
foreach my $sequenceId ( sort keys %{$type2_seqSequencesToFeatureLookup}){

    foreach my $featref ( @{$type2_seqSequencesToFeatureLookup->{$sequenceId}}) {
	## Process each Feature that is localized to this Type 2 _seq Sequence!
	
	## trim off the _seq suffix
	$sequenceId =~ s/_seq$//;
	
	$prism->storeBsmlFeatureComponentInChado(
						 sequence_uniquename => $sequenceId,
						 feature             => $featref,
						 organism_id         => $organism_id,
						 timestamp           => $timestamp,
						 feature_id_lookup   => $feature_id_lookup,
						 autogen             => $autogen_feat,
						 insert_new          => $insert_new,
						 update              => $update,
						 prevprocessed       => $prevprocessed,
						 sequence_lookup     => $sequence_lookup,
						 residue_lookup      => $residue_lookup,
						 sequence_2_feature  => $sequence_2_feature,
						 feature_id_lookup_d => $feature_id_lookup_d,
						 analyses_identifier_lookup  => $analyses_identifier_lookup,
						 exclude_classes_lookup => $exclude_classes_lookup,
						 polypeptideToOrganismIdLookup => $polypeptideToOrganismIdLookup
						 );
    }

    ## Un-define all the Type 2 _seq Sequences references in this all_sequence_lookup.
    ## We do not want to process these again when we process the Type 1 Sequences.
    $all_sequence_lookup->{$sequenceId} = undef;
}

##-------------------------------------------------------------------------------------------------------------------
## Now need to process the remaining sequences in all_sequence_lookup.
## These represent the Sequences of type 1 which do not contain any nested Feature-tables.
## Examples are CDS and polypeptide
#-------------------------------------------------------------------------------------------------------------------
print "Processing all remaining cached Type 1 <Sequence> elements.\n";
$logger->info("Processing all remaining Sequence type1 (these do not contain nested Feature-tables)");

## The order of the encountered Sequence elements must be preserved (bgz 2118).
foreach my $sequence_identifier ( @{$sequence_order} ){
    
    if ( (exists ($all_sequence_lookup->{$sequence_identifier})) and (defined ($all_sequence_lookup->{$sequence_identifier}) ) ){

	if ((exists $processedSequencesLookup->{$sequence_identifier}) && (defined($processedSequencesLookup->{$sequence_identifier}))){
	    # This Sequence was previously processed during this session.
	    # This check may be unnecessary.
	    next;
	}

	if (exists $sequence_2_feature->{$sequence_identifier}){
	    # This Type 1 Sequence had a Linked Feature which itself
	    # was already processed, therefore do not need to process
	    # this Sequence.
	    next;
	}

	my $sequence        = $all_sequence_lookup->{$sequence_identifier}->{'sequence'};
	my $attributes      = $all_sequence_lookup->{$sequence_identifier}->{'attributes'};
	my $attribute_lists = $all_sequence_lookup->{$sequence_identifier}->{'attribute_lists'};
	my $numbering       = $all_sequence_lookup->{$sequence_identifier}->{'numbering'};
	my $xref            = $all_sequence_lookup->{$sequence_identifier}->{'xref'};
	my $seqdat          = $all_sequence_lookup->{$sequence_identifier}->{'seqdat'};
	my $bsmllink        = $all_sequence_lookup->{$sequence_identifier}->{'bsmllink'};


	# Un-define all the Sequences of type 1
	$all_sequence_lookup->{$sequence_identifier} = undef;

	# Remember that this Sequence was processed.
	$processedSequencesLookup->{$sequence_identifier}++;

	# All relevant data retrieved, now time to process
	$prism->store_bsml_sequence_component(
					      BsmlAttr            => $attributes,
					      BsmlAttributeList   => $attribute_lists,
					      seqdat              => $seqdat,
					      BsmlNumbering       => $numbering,
					      seqobj              => $sequence,
					      dummy_organism_id   => $dummy_organism_id,
					      timestamp           => $timestamp,
					      feature_id_lookup   => $feature_id_lookup,
					      feature_id_lookup_d => $feature_id_lookup_d,
					      autogen             => $autogen_seq,
					      insert_new          => $insert_new,
					      update              => $update,
					      BsmlCrossReference  => $xref,
					      prevprocessed       => $prevprocessed,
					      sequence_lookup     => $sequence_lookup,
					      BsmlLink            => $bsmllink,
					      genome_id_2_organism_id     => $genome_id_2_organism_id,
					      analyses_identifier_lookup  => $analyses_identifier_lookup,
					      exclude_classes_lookup => $exclude_classes_lookup,
					      sequence_lookup        => $sequence_lookup
					      );
	
    }
}



print "Parsing and processing <Seq-pair-alignment> and <Multiple-alignment-table> components.\n";

my $gap_counter;

my $bsmlparser4 = new BSML::BsmlParserSerialSearch(
						   
						   #-----------------------------------------------------------------------------------
						   # MultipleAlignment Callback 
						   #
						   #-----------------------------------------------------------------------------------
						   MultipleAlignmentCallBack => sub {
						       my ($alnref) = @_;
						       
						       $bsml_element_counter->{'Multiple-alignment-table'}++;
						       
						       if ($logger->is_info()) {
							   &show_count("\n<Multiple-alignment-table> $bsml_element_counter->{'Multiple-alignment-table'}");
						       }
						       
						       $prism->storeBsmlMultipleAlignmentTableComponentInChado(
													       BsmlMultipleAlignmentTable => $alnref,
													       timestamp            => $timestamp,
													       feature_id_lookup    => $feature_id_lookup,
													       feature_id_lookup_d  => $feature_id_lookup_d,
													       organism_id          => $dummy_organism_id,
													       update               => $update,
													       analyses_identifier_lookup => $analyses_identifier_lookup,
													       exclude_classes_lookup => $exclude_classes_lookup,
													       );
						   },
						   
						   
						   
						   #-----------------------------------------------------------------------------------
						   # Alignment Callback 
						   #
						   #-----------------------------------------------------------------------------------
						   AlignmentCallBack => sub {
						       
						       my ($alnref) = @_;
						       
						       $bsml_element_counter->{'Seq-pair-alignment'}++;
						       
						       ## The loader will now create and store a consensus alignment in 
						       ## chado.feature and properties in chado.featureprop.  Here we 
						       ## extract the class from the <Seq-pair-alignment> element.  
						       ## If not defined, class is set to 'match_set'.  (bgz 2227)
						       my ($refseq, $compseq, $feature_id, $analysis_id) = &parse_seq_pair_alignment(
																     alnref                      => $alnref,
																     feature_id_lookup_d         => $feature_id_lookup_d,
																     feature_id_lookup           => $feature_id_lookup,
																     analyses_identifier_lookup  => $analyses_identifier_lookup,
																     date                        => $timestamp,
																     sequence_lookup             => $sequence_lookup,
																     unknown_organism_id         => $dummy_organism_id
																     );
						       
						       #
						       # Count and skip GAPs
						       #       
						       if (($refseq eq 'GAP') || ($compseq eq 'GAP')){
							   $gap_counter++;
							   next;
						       }
						       
						       if (( exists $alnref->{'BsmlSeqPairRuns'}) && 
							   (defined($alnref->{'BsmlSeqPairRuns'})) && 
							   (scalar(@{$alnref->{'BsmlSeqPairRuns'}}) > 0 )) {

							   my $hspctr=0;
							   
							   foreach my $seq_pair_run ( @{$alnref->{'BsmlSeqPairRuns'}} ) {
							       
							       $hspctr++;
							
							       $bsml_element_counter->{'Seq-pair-run'}++;
							       
							       if ($logger->is_info()) {
								   &show_count("\n<Seq-pair-alignment> $bsml_element_counter->{'Seq-pair-alignment'} <Seq-pair-run> $bsml_element_counter->{'Seq-pair-run'}");
							       }
							       
							       
							       $prism->store_bsml_seq_pair_run_component( feature_id    => $feature_id,
													  analysis_id   => $analysis_id,
													  refseq        => $refseq,
													  compseq       => $compseq,
													  refend        => $alnref->{'attr'}->{'refend'},
													  reflength     => $alnref->{'attr'}->{'reflength'},
													  refstart      => $alnref->{'attr'}->{'refstart'},
													  #
													  # The following are attributes of the <Seq-pair-run> BSML elements
													  #
													  timestamp         => $timestamp,
													  organism_id       => $dummy_organism_id,
													  bsmldoc           => $bsmldoc,
													  seq_pair_run      => $seq_pair_run,
													  hspctr            => $hspctr,
													  #
													  # Lookups
													  #
													  feature_id_lookup                    => $feature_id_lookup,
													  feature_id_lookup_d                  => $feature_id_lookup_d,
													  sequence_lookup                      => $sequence_lookup,
													  exclude_classes_lookup => $exclude_classes_lookup,
													  );
							       
							   }# foreach my $seq_pair_run
						       }
						       else {
							   $logger->logdie("There were no <Seq-pair-run> elements for <Seq-pair-alignment> refseq '$refseq' compseq '$compseq'");
						       }

						   }
						   );

$logger->logdie("bsmlparser4 was not defined") if (!defined($bsmlparser4));
$bsmlparser4->parse($bsmldoc);

#---------------------------------------------------------------------------------------------
# Process the Feature-groups
#
#---------------------------------------------------------------------------------------------
print "Processing <Feature-group> components.\n";

$prism->store_bsml_feature_groups(
				  feature_groups        => $featureGroupRef,
				  feature_id_lookup     => $feature_id_lookup,
				  feature_id_lookup_d   => $feature_id_lookup_d,
				  exon_coordinates      => $exon_coordinates
				  );


if ($logger->is_debug()) {

    my $alreadyLoadedCount = scalar(@{$prevprocessed});

    if ($alreadyLoadedCount > 0){
    
	my $string;

	foreach my $group (@{$prevprocessed}){
	    $string .= "$group->{'uniquename'}\t$group->{'feature_id'}\n";
	}
	
	if ($alreadyLoadedCount == 1){
	    $logger->debug("BSML file '$bsmldoc' contains one Sequence or Feature ".
			   "for which a feature record already exists in the target chado database '$database'. ".
			   "Here is the uniquename and feature_id for that record:\n$string");
	}
	else {
	    $logger->debug("BSML file '$bsmldoc' contains '$alreadyLoadedCount' Sequences and/or Features ".
			   "for which feature records already exist in the target chado database '$database'. ".
			   "Here is a listing of these Sequences/Features by uniquename and feature_id:\n$string");
	}
    }

    ## Report the counts for each type of BSML element encountered.
    foreach my $bsml_element (sort keys %{$bsml_element_counter} ) {
	
	$logger->debug("Parsed '$bsml_element_counter->{$bsml_element}' <$bsml_element> element(s)");

    }
    
    if ($gap_counter>0){
	$logger->debug("Number of GAPs counted '$gap_counter'");
    }
}



#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Finished parsing the BSML document.  Now need to write to the tab delimited .out files and output in the outdir
#
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$logger->info("Writing tab delimited .out files to directory: $outdir");
$prism->{_backend}->output_tables($outdir);
print "\n";

$prism->reportTableRecordCounts($recordCountFile);

$logger->info("'$0': Finished processing BSML document '$bsmldoc'");
$logger->info("Please review the log file '$logfile'");
print "$0 program execution completed\n";
print "Tab delimited .out files were written to $outdir\n";
print "Run flatFileToChado.pl to load the contents of the tab-delimited files into chado database '$database'\n";
print "The log file is '$logfile'\n";



#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#
#                                  END OF MAIN  -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------------------
# is_file_readable()
#
#-------------------------------------------------------------------
sub is_file_readable {

    my ( $file) = @_;

    $logger->logdie("file was not defined") if (!defined($file));

    if (!-e $file){
	#
	# Check for the gzip compressed version of the file (will always have .gz extension).
	#
	my $filegz = $file . '.gz';

	if (!-e $filegz){
	    $logger->logdie("neither $file nor $filegz not exist");
	}
	else {
	    if (!-r $filegz){
		$logger->logdie("$filegz does not have read permissions");
	    }
	    if (-z $filegz){
		$logger->logdie("$filegz has no content");
	    }
	}
	$file = $filegz;
    }
    else {
	if (!-r $file){
	    $logger->logdie("$file does not have read permissions");
	}
	if (-z $file){
	    $logger->logdie("$file has no content");
	}
    }

    return $file;
    

}#end sub is_file_readable()

#--------------------------------------------------------
# verify_and_set_outdir()
#
#
#--------------------------------------------------------
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

#-----------------------------------------------------------------------------
# retrieve_bsml_reader()
#
#-----------------------------------------------------------------------------
sub retrieve_bsml_reader {

    my ($self) = @_;

    $logger->debug("Instantiating BsmlReader object") if ($logger->is_debug());

    my $bsmlreader = new BSML::BsmlReader();
    
    $logger->logdie("bsmlreader was not defined") if (!defined($bsmlreader));
    
    $logger->debug("bsmlreader:" . Dumper($bsmlreader)) if ($logger->is_debug());
    
    return $bsmlreader;

}#end sub retrieve_bsml_reader()


#----------------------------------------------------------------
# retrieve_prism_object()
#
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database, $no_placeholders, $append_bcp, $next_bcp_values, $checksum_placeholders, $gzip_bcp,
	 $row_delimiter, $field_delimiter) = @_;

    #
    # If no_placeholders == 1, then we do not want placeholder variables inserted in place of the table
    # serial identifiers.  This means that we do not want parallel parsing support.
    #
    if (defined($no_placeholders)){
	#
	# By undefining this variable, we turn off placeholder variable insertion in Coati/TableIdManager.pm
	#
	$no_placeholders = undef;
    }
    else{
	$no_placeholders = 1;
    }

    #
    # If checksum_placeholders == 1, then we want md5 checksum values inserted in place of the table
    # serial identifiers.
    #
    #
    if ((defined($checksum_placeholders)) && ($checksum_placeholders == 1)){
	$no_placeholders = undef;
    }

    if (defined($gzip_bcp)){
	if ($gzip_bcp != 1){ # 1 or 0 are the only acceptable values (if it ain't 1 then make it 0)
	    $gzip_bcp = 0;
	}
	$ENV{'GZIP_BCP'} = $gzip_bcp;
    }

    my $prism = new Prism(
			  user              => $username,
			  password          => $password,
			  db                => $database,
			  use_placeholders  => $no_placeholders,
			  append_bcp        => $append_bcp,
			  next_bcp_values   => $next_bcp_values,
			  checksum_placeholders => $checksum_placeholders,
			  gzip_bcp              => $gzip_bcp,
			  row_delimiter => $row_delimiter,
			  field_delimiter => $field_delimiter
			  );


    $logger->logdie("prism was not defined") if (!defined($prism));

    return $prism;

}#end sub retrieve_prism_object()


#------------------------------------------------------
# show_count()
#
#------------------------------------------------------
sub show_count{
    
    $logger->debug("Entered show_count") if $logger->is_debug;

    my $string = shift;
    $logger->logdie("string was not defined") if (!defined($string));

    print "\b"x(100);
    printf "%-100s", $string;

}#end sub show_count()

#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -D database --database_type --server -P password -U username [-a autogen_feat] -b bsmldoc [--checksum_placeholders] [-d debug_level] [--exclude_classes] [--gzip_bcp] [-h] [--id_repository] [-i insert_new] [-l logfile] [-m] [--no-placeholders] [--parse-match-sequence-fasta] [-o outdir] [-R readonlycache] [-s autogen_seq] [--timestamp] [-u update] [-x xml_schema_type] [-y cache_dir] [-z doctype]\n".
    "  -D|--database                = Target chado database\n".
    "  --database_type              = Relational database management system type e.g. sybase or postgresql\n".
    "  --server                     = Name of the server on which the database resides\n".
    "  -P|--password                = Password\n".
    "  -U|--username                = Username\n".
    "  -a|--autogen_feat            = Optional - auto-generate feature.uniquename for inbound <Feature> types.  (Default is ON -a=1.  To turn OFF -a=0)\n".
    "  -b|--bsmldoc                 = Bsml document containing pairwise alignment encodings\n".
    "  -c|--checksum_placeholders   = Optional - TableIdManager will insert md5 checksum values (based on the fields which make up each tables' uniqueness constraint) in place of the tables' serial identifiers\n".
    "  -d|--debug_level             = Optional - Coati::Logger Log4perl logging level.  Default is 0\n".
    "  --exclude_classes            = Optional - Do not process Sequence and Feature objects of any of the types listed (comma-separated list)\n".
    "  --gzip_bcp                   = Optional - writes the BCP .out files in compressed format with .out.gz file extension\n".
    "  -h|--help                    = Optional - Display pod2usage help screen\n".
    "  -i|--insert_new              = Optional - to turn on insertion of  <Sequence> and <Feature> elements not currently present in the database (Default is ON -i=1.  To turn OFF -i=0)\n".
    "  --id_repository              = Optional - directory for IdGenerator.pm control file (Default ENV{ID_REPOSITORY})\n".
    "  -l|--logfile                 = Optional - Log4perl log file (default: /tmp/bsml2chado.pl.log)\n".
    "  -m|--man                     = Optional - Display pod2usage pages for this utility\n".
    "  --no-placeholders            = Optional - Do not insert placeholder variables in place of the tables' serial identifiers, that is- disable parallel parsing support (default is to insert placeholder variables)\n".
    "  -o|--outdir                  = Optional - output directory for tab delimited BCP files (Default is current working directory)\n".
    "  --parse-match-sequence-fasta = Optional - parse the FASTA file specified by Seq-data-import of the match Sequence stub (Default is to not parse)\n".
    "  -R|--readonlycache           = Optional - If data file caching is activated and if this readonlycache is == 1, then the tied MLDBM lookup cache files can only be accessed in read-only mode. (Default is OFF -r=0)\n".
    "  -s|--autogen_seq             = Optional - auto-generate feature.uniquename for inbound <Sequence> types.  (Default is OFF -s=0.  To turn ON -s=1)\n".
    "  --timestamp                  = Optional - e.g. 'Jun  5 2006  6:59PM'  (else auto-generated by default)\n".
    "  -u|--update                  = Optional - If elements already present in database, update flag signifies that portions of records should be updated with new inbound data (Default is OFF -u=0.  To turn ON -u=1)\n".
    "  -x|--xml_schema_type         = Optional - validation against a particular XML schema type\n".
    "  -y|--cache_dir               = Optional - To turn on file-caching and specify directory to write cache files.  (Default no file-caching. If specified directory does not exist, default is environmental variable ENV{DBCACHE_DIR}\n".
    "  -z|--doctype                 = Optional - BSML document type ( nucmer, region, promer, pe, blastp, repeat, scaffold, rna, te, coverage)\n";
    exit 1;

}



#------------------------------------------------------------------
# retrieve_uniquenames()
#
#------------------------------------------------------------------
sub retrieve_uniquenames { 

    $logger->debug("Entered") if $logger->is_debug();

    my ($prism, $type) = @_;

    $logger->logdie("prism was not defined") if (!defined($prism));
    $logger->logdie("lookup was not defined") if (!defined($type));


    print "Building uniquenames list\n";


    my @uniquenames;

    my $ret = $prism->all_seq_uniquenames_by_type($type);

    for (my $i=0; $i < scalar( @{$ret} ) ; $i++ ){
	
	push(@uniquenames, $ret->[$i][0]);
    }


    return \@uniquenames;

}# sub retrieve_uniquenames


#------------------------------------------------------------------
# add_to_analysisfeature_id_lookup()
#
#------------------------------------------------------------------
sub add_to_analysisfeature_id_lookup {

    $logger->debug("Entered") if $logger->is_debug();

    my ($prism, $uniquenames, $lookup, $type) = @_;

    $logger->logdie("prism was not defined") if (!defined($prism));
    $logger->logdie("uniquenames was not defined") if (!defined($uniquenames));
    $logger->logdie("type was not defined") if (!defined($type));

    print "Building analysisfeature_id lookup\n";

    #
    # This next query will retrieve all analysisfeature records for the features of the specified type
    #
    my $ret = $prism->all_analysisfeature_records_by_type($type);
    $logger->logdie("ret was not defined") if (!defined($ret));

    for(my $j=0;$j<scalar(@$ret);$j++){
	
	# 0 analysisfeature.analysisfeature_id
	# 1 analysisfeature.feature_id
	# 2 analysisfeature.analysis_id
	
	my $key = $ret->[$j][1] . '_' . $ret->[$j][2];
	
	$lookup->{$key} = $ret->[$j][0];
	
    }	
    
    foreach my $uniquename ( sort @{$uniquenames} ) {
	#
	# This next query will retrieve all analysisfeature records for features
	# which are localized to the specified $uniquename
	#
	
	my $ret = $prism->all_seq_to_feat_analysisfeature_records($uniquename);
	$logger->logdie("ret was not defined") if (!defined($ret));
	
	for(my $j=0;$j<scalar(@$ret);$j++){
	    
	    # 0 analysisfeature.analysisfeature_id
	    # 1 analysisfeature.feature_id
	    # 2 analysisfeature.analysis_id
	    
	    my $key = $ret->[$j][1] . '_' . $ret->[$j][2];
	    
	    $lookup->{$key} = $ret->[$j][0];
	    
	}	
    }


    return $lookup;

}#end sub add_to_analysisfeature_id_lookup()


#------------------------------------------------------------------
# add_to_featureprop_id_lookup()
#
#------------------------------------------------------------------
sub add_to_featureprop_id_lookup {

    $logger->debug("Entered") if $logger->is_debug();

    my ($prism, $uniquenames, $lookup, $type) = @_;

    $logger->logdie("prism was not defined") if (!defined($prism));
    $logger->logdie("uniquenames was not defined") if (!defined($uniquenames));
    $logger->logdie("type was not defined") if (!defined($type));


    print "Building featureprop_id lookup\n";
    
    #
    # This next query will retrieve all featureprop records for the features of the specified type
    #
    my $ret = $prism->all_featureprop_records_by_type($type);
    $logger->logdie("ret was not defined") if (!defined($ret));

    for (my $j=0; $j <scalar(@$ret) ; $j++ ) {
	
	# 0 featureprop.featureprop_id
	# 1 featureprop.feature_id
	# 2 featureprop.type_id
	# 3 featureprop.value
	# 4 featureprop.rank
	
	my $key = $ret->[$j][1] . '_' . $ret->[$j][2] . '_' . $ret->[$j][3] . '_' . $ret->[$j][4];
	
	$lookup->{$key} = $ret->[$j][0];
	
    }	

    foreach my $uniquename ( sort @{$uniquenames} ) {
	#
	# This next query will retrieve all featureprop records for features
	# which are localized to the specified $uniquename
	#

	my $ret = $prism->all_seq_to_feat_featureprop_records($uniquename);
	$logger->logdie("ret was not defined") if (!defined($ret));

	for (my $j=0; $j <scalar(@$ret) ; $j++ ) {
	    
	    # 0 featureprop.featureprop_id
	    # 1 featureprop.feature_id
	    # 2 featureprop.type_id
	    # 3 featureprop.value
	    # 4 featureprop.rank

	    my $key = $ret->[$j][1] . '_' . $ret->[$j][2] . '_' . $ret->[$j][3] . '_' . $ret->[$j][4];
	    
	    $lookup->{$key} = $ret->[$j][0];
	    
	}	
    }


    return $lookup;

}#end sub add_to_featureprop_id_lookup()


#------------------------------------------------------------------
# add_to_featureloc_id_lookup()
#
#------------------------------------------------------------------
sub add_to_featureloc_id_lookup {

    $logger->debug("Entered") if $logger->is_debug();

    my ($prism, $uniquenames, $lookup, $type) = @_;

    $logger->logdie("prism was not defined") if (!defined($prism));
    $logger->logdie("uniquenames was not defined") if (!defined($uniquenames));
    $logger->logdie("type was not defined") if (!defined($type));


    print "Building featureloc_id lookup\n";

    #
    # This next query will retrieve all featureloc records for the features of the specified type
    #
    my $ret = $prism->all_featureloc_records_by_type($type);
    $logger->logdie("ret was not defined") if (!defined($ret));
    
    for (my $j=0; $j <scalar(@$ret) ; $j++ ) {
	
	# 0 featureloc.featureloc_id
	# 1 featureloc.feature_id
	# 2 featureloc.locgroup
	# 3 featureloc.rank
	
	my $key = $ret->[$j][1] . '_' . $ret->[$j][2] . '_' . $ret->[$j][3];
	
	$lookup->{$key} = $ret->[$j][0];
    }	


    foreach my $uniquename ( sort @{$uniquenames} ) {
	#
	# This next query will retrieve all featureloc records for features
	# which are localized to the specified $uniquename
	#

	my $ret = $prism->all_seq_to_feat_featureloc_records($uniquename);
	$logger->logdie("ret was not defined") if (!defined($ret));

	for (my $j=0; $j <scalar(@$ret) ; $j++ ) {
	    
	    # 0 featureloc.featureloc_id
	    # 1 featureloc.feature_id
	    # 2 featureloc.locgroup
	    # 3 featureloc.rank

	    my $key = $ret->[$j][1] . '_' . $ret->[$j][2] . '_' . $ret->[$j][3];
	    
	    $lookup->{$key} = $ret->[$j][0];
	    
	}	
    }


    return $lookup;

}#end sub add_featureloc_id_lookup()


#------------------------------------------------------------------
# add_to_feature_relationship_id_lookup()
#
#------------------------------------------------------------------
sub add_to_feature_relationship_id_lookup {

    $logger->debug("Entered") if $logger->is_debug();

    my ($prism, $uniquenames, $lookup, $type) = @_;

    $logger->logdie("prism was not defined") if (!defined($prism));
    $logger->logdie("uniquenames was not defined") if (!defined($uniquenames));
    $logger->logdie("type was not defined") if (!defined($type));

    print "Building feature_relationship_id lookup\n";

    #
    # This next query will retrieve all feature_relationship records for the features of the specified type
    #
    my $ret = $prism->all_feature_relationship_records_by_type($type);
    $logger->logdie("ret was not defined") if (!defined($ret));
    
    for (my $j=0; $j <scalar(@$ret) ; $j++ ) {
	
	# 0 feature_relationship.feature_relationship_id
	# 1 feature_relationship.subject_id
	# 2 feature_relationship.object_id
	# 3 feature_relationship.type_id
	
	my $key = $ret->[$j][1] . '_' . $ret->[$j][2] . '_' . $ret->[$j][3];
	
	$lookup->{$key} = $ret->[$j][0];
	
    }	

    foreach my $uniquename ( sort @{$uniquenames} ) {
	#
	# This next query will retrieve all feature_relationship records for features
	# which are localized to the specified $uniquename
	#
	
	my $ret = $prism->all_seq_to_feat_feature_relationship_records($uniquename);
	$logger->logdie("ret was not defined") if (!defined($ret));
	
	for (my $j=0; $j <scalar(@$ret) ; $j++ ) {
	    
	    # 0 feature_relationship.feature_relationship_id
	    # 1 feature_relationship.subject_id
	    # 2 feature_relationship.object_id
	    # 3 feature_relationship.type_id
	    
	    my $key = $ret->[$j][1] . '_' . $ret->[$j][2] . '_' . $ret->[$j][3];
	    
	    $lookup->{$key} = $ret->[$j][0];
	    
	}	
    }
    

    return $lookup;

}#end sub add_feature_relationship_id_lookup()



#------------------------------------------------------------------
# add_to_feature_dbxref_id_lookup()
#
#------------------------------------------------------------------
sub add_to_feature_dbxref_id_lookup {

    $logger->debug("Entered") if $logger->is_debug();

    my ($prism, $uniquenames, $lookup, $type) = @_;

    $logger->logdie("prism was not defined") if (!defined($prism));
    $logger->logdie("uniquenames was not defined") if (!defined($uniquenames));
    $logger->logdie("type was not defined") if (!defined($type));

    
    print "Building feature_dbxref_id lookup\n";

    #
    # This next query will retrieve all feature_dbxref records for the features of the specified type
    #
    my $ret = $prism->all_feature_dbxref_records_by_type($type);
    $logger->logdie("ret was not defined") if (!defined($ret));
    
    for (my $j=0; $j <scalar(@$ret) ; $j++ ) {
	
	# 0 feature_dbxref.feature_dbxref_id
	# 1 feature_dbxref.feature_id
	# 2 feature_dbxref.dbxref_id
	# 3 feature_dbxref.is_current
	
	my $key = $ret->[$j][1] . '_' . $ret->[$j][2] . '_' . $ret->[$j][3];
	
	$lookup->{$key} = $ret->[$j][0];
	
    }	
    

    foreach my $uniquename ( sort @{$uniquenames} ) {

	#
	# This next query will retrieve all feature_dbxref records for features
	# which are localized to the specified $uniquename
	#

	my $ret = $prism->all_seq_to_feat_feature_dbxref_records($uniquename);
	$logger->logdie("ret was not defined") if (!defined($ret));

	for (my $j=0; $j <scalar(@$ret) ; $j++ ) {
	    
	    # 0 feature_dbxref.feature_dbxref_id
	    # 1 feature_dbxref.feature_id
	    # 2 feature_dbxref.dbxref_id
	    # 3 feature_dbxref.is_current
	    
	    my $key = $ret->[$j][1] . '_' . $ret->[$j][2] . '_' . $ret->[$j][3];
	    
	    $lookup->{$key} = $ret->[$j][0];
	    
	}	
    }

    return $lookup;

}#end sub add_feature_dbxref_id_lookup()



#------------------------------------------------------------------
# add_to_feature_cvterm_id_lookup()
#
#------------------------------------------------------------------
sub add_to_feature_cvterm_id_lookup {

    $logger->debug("Entered") if $logger->is_debug();

    my ($prism, $uniquenames, $lookup, $type) = @_;

    $logger->logdie("prism was not defined") if (!defined($prism));
    $logger->logdie("uniquenames was not defined") if (!defined($uniquenames));
    $logger->logdie("type was not defined") if (!defined($type));


    print "Building feature_cvterm_id lookup\n";

    #
    # This next query will retrieve all feature_cvterm records for the features of the specified type
    #
    my $ret = $prism->all_feature_cvterm_records_by_type($type);
    $logger->logdie("ret was not defined") if (!defined($ret));
    
    for (my $j=0; $j <scalar(@$ret) ; $j++ ) {
	
	# 0 feature_cvterm.feature_cvterm_id
	# 1 feature_cvterm.feature_id
	# 2 feature_cvterm.cvterm_id
	# 3 feature_cvterm.pub_id
	
	my $key = $ret->[$j][1] . '_' . $ret->[$j][2] . '_' . $ret->[$j][3];
	
	$lookup->{$key} = $ret->[$j][0];

    }	


    foreach my $uniquename ( sort @{$uniquenames} ) {    
	#
	# This next query will retrieve all feature_cvterm records for features
	# which are localized to the specified $uniquename
	#
	my $ret = $prism->all_seq_to_feat_feature_cvterm_records($uniquename);
	$logger->logdie("ret was not defined") if (!defined($ret));
	
	for (my $j=0; $j <scalar(@$ret) ; $j++ ) {
	    
	    # 0 feature_cvterm.feature_cvterm_id
	    # 1 feature_cvterm.feature_id
	    # 2 feature_cvterm.cvterm_id
	    # 3 feature_cvterm.pub_id
	    
	    my $key = $ret->[$j][1] . '_' . $ret->[$j][2] . '_' . $ret->[$j][3];
	    
	    $lookup->{$key} = $ret->[$j][0];
	    
	}	
    }
    
    return $lookup;

}#end sub add_feature_cvterm_id_lookup()



#------------------------------------------------------------------
# add_to_feature_cvtermprop_id_lookup()
#
#------------------------------------------------------------------
sub add_to_feature_cvtermprop_id_lookup {

    $logger->debug("Entered") if $logger->is_debug();

    my ($prism, $uniquenames, $lookup, $type) = @_;

    $logger->logdie("prism was not defined") if (!defined($prism));
    $logger->logdie("uniquenames was not defined") if (!defined($uniquenames));
    $logger->logdie("type was not defined") if (!defined($type));

    print "Building feature_cvtermprop_id lookup\n";

    #
    # This next query will retrieve all feature_cvtermprop records for the features of the specified type
    #
    my $ret = $prism->all_feature_cvtermprop_records_by_type($type);
    $logger->logdie("ret was not defined") if (!defined($ret));
    
    for (my $j=0; $j <scalar(@$ret) ; $j++ ) {
	
	
	# 0 feature_cvtermprop.feature_cvtermprop_id
	# 1 feature_cvtermprop.feature_cvterm_id
	# 2 feature_cvtermprop.type_id
	# 3 feature_cvtermprop.value
	# 4 feature_cvtermprop.rank
	
	my $key = $ret->[$j][1] . '_' . $ret->[$j][2] . '_' . $ret->[$j][3] . '_' . $ret->[$j][4];
	
	$lookup->{$key} = $ret->[$j][0];
    }	
    
    
    #
    # This next query will retrieve all feature_cvtermprop records for features
    # which are localized to the specified $uniquename
    #
    foreach my $uniquename ( sort @{$uniquenames} ) {

	my $ret = $prism->all_seq_to_feat_feature_cvtermprop_records($uniquename);
	$logger->logdie("ret was not defined") if (!defined($ret));

	for (my $j=0; $j <scalar(@$ret) ; $j++ ) {
	    
	    
	    # 0 feature_cvtermprop.feature_cvtermprop_id
	    # 1 feature_cvtermprop.feature_cvterm_id
	    # 2 feature_cvtermprop.type_id
	    # 3 feature_cvtermprop.value
	    # 4 feature_cvtermprop.rank
	    
	    my $key = $ret->[$j][1] . '_' . $ret->[$j][2] . '_' . $ret->[$j][3] . '_' . $ret->[$j][4];
	    
	    $lookup->{$key} = $ret->[$j][0];
	    
	}	
    }

    return $lookup;

}#end sub add_feature_cvtermprop_id_lookup()



#-------------------------------------------------------------------
# subroutine:  parse_seq_pair_alignment()
#
#-------------------------------------------------------------------
sub parse_seq_pair_alignment {

    my (%param) = @_;

    $logger->debug("Entered parse_seq_pair_alignment") if $logger->is_debug();
    
    my $phash = \%param;
    
    

    my ($alnref)      = $phash->{'alnref'};
    my ($analyses_identifier_lookup) = $phash->{'analyses_identifier_lookup'};

    

    my ($refseq, $compseq, $class, $analysis_id);


    #-----------------------------------------------------------------------------------------------------------------------------
    # comment:  Determine the refseq and the compseq
    #
    if (( exists $alnref->{'attr'}) && (defined($alnref->{'attr'})) ) {


	#----------------------------------------------------------------
	# Retrieve the refseq
	#
	if (( exists $alnref->{'attr'}->{'refseq'}) && (defined($alnref->{'attr'}->{'refseq'})) ){
	    
	    $refseq = $alnref->{'attr'}->{'refseq'};


	    #
	    # Strip the arbitrary enumeration values
	    #  
	    if ($refseq =~ /^\S+:(\S+)$/){
		$refseq=$1;
	    }

	}
	else {
	    $logger->logdie("The refseq was not defined");
	}


	#----------------------------------------------------------------
	# Retrieve the compseq
	#
	if (( exists $alnref->{'attr'}->{'compseq'}) && (defined($alnref->{'attr'}->{'compseq'})) ){
	    
	    $compseq = $alnref->{'attr'}->{'compseq'};
	}
	else {
	    $logger->logdie("The compseq was not defined");
	}

	#----------------------------------------------------------------
	# Retrieve the class
	#
	if (( exists $alnref->{'attr'}->{'class'}) && (defined($alnref->{'attr'}->{'class'})) ){
	    
	    $class = $alnref->{'attr'}->{'class'};
	}
	else {
	    $logger->logdie("class was not defined for the Seq-pair-alignment with refseq '$refseq' compseq '$compseq'");
	}

    }
    else {
	$logger->logdie("attr does not exist for some <Seq-pair-alignment>");
    }





    #-----------------------------------------------------------------------------------------------------------------------------
    # comment: Here we determine whether there are any <Link> elements nested below the <Seq-pair-alignment> and if so, 
    #          retrieve the analysis identifier for each and store in lookup.
    #
    if (( exists $alnref->{'BsmlLink'}) && (defined($alnref->{'BsmlLink'})) && (scalar(@{$alnref->{'BsmlLink'}}) > 0 )) {

	foreach my $linkhash ( sort @{$alnref->{'BsmlLink'}} ) {

	    if ((exists $linkhash->{'rel'}) && (defined($linkhash->{'rel'})) && ($linkhash->{'rel'} eq 'analysis') ) {

		if ((exists $linkhash->{'href'}) && (defined($linkhash->{'href'})) ) {
		    
		    my $analysis_link = $linkhash->{'href'};
		    
		    #
		    # strip the leading pound sign
		    #
		    $analysis_link =~ s/^\#//;

		    #
		    # Retrieve the proper analysis_id
		    #
		    if (( exists $analyses_identifier_lookup->{$analysis_link}->{'analysis_id'}) && (defined($analyses_identifier_lookup->{$analysis_link}->{'analysis_id'})) ){

			$analysis_id = $analyses_identifier_lookup->{$analysis_link}->{'analysis_id'};

		    }
		    else {
			$logger->logdie("Found some analysis '$analysis_link' which did not have an analysis_id in the analyses_identifier_lookup");
		    }
		    

		}
		else {
		    $logger->logdie("href was not defined for rel '$linkhash->{'rel'}'");
		}
	    }
	    else {
		$logger->logdie("rel was not defined for the <Link> element nested below <Seq-pair-alignment> refseq '$refseq' compseq '$compseq'");
	    }
	}
    }
    else {
	$logger->warn("No <Link> element was nested below the <Seq-pair-alignment>  refseq '$refseq' compseq '$compseq'.  Will assume analysis_id.");
    }
    #
    #------------------------------------------------------------------------------------------------------------------------------
    



    #--------------------------------------------------------------
    # comment: spanning coordinates for the alignment feature with
    #          respect to the refseq (query sequence)
    my $ref_fmin = 0;
    my $ref_fmax = 0;


    #--------------------------------------------------------------
    # comment: spanning coordinates for the alignment feature with
    #          respect to the compseq (match sequence)
    my $comp_fmin = 0;
    my $comp_fmax = 0;




    #------------------------------------------------------------------------------------------------------------------------------
    # comment: Here we retrieve each HSP/Seq-pair-run's refpos and runlength.  These values will be used to determine the
    #          span of the alignment feature.
    #
    if (( exists $alnref->{'BsmlSeqPairRuns'} ) && (defined($alnref->{'BsmlSeqPairRuns'}) ) && (scalar(@{$alnref->{'BsmlSeqPairRuns'}}) > 0  ) ) {


	my $hspctr = 0;

	foreach my $seqpairrun ( sort @{$alnref->{'BsmlSeqPairRuns'}} ) {

	    $hspctr++;

	    if (( exists $seqpairrun->{'attr'}) && (defined($seqpairrun->{'attr'}) ) ){
		
		my $refpos;

		#------------------------------------------------------------------------------------------------------------
		# Determine the spanning alignment's minimum coordinate with respect to the query sequence (refseq)
		#
		if (( exists $seqpairrun->{'attr'}->{'refpos'}) && (defined($seqpairrun->{'attr'}->{'refpos'}) )) {

		    $refpos = $seqpairrun->{'attr'}->{'refpos'};

		    ($ref_fmin) = &calculate_alignment_fmin($refpos, $hspctr, $ref_fmin);

		}
		else {
		    $logger->logdie("refpos was not defined for refseq '$refseq' compseq '$compseq' <Seq-pair-run> number '$hspctr'");
		}
		#
		#------------------------------------------------------------------------------------------------------------


		#------------------------------------------------------------------------------------------------------------
		# Determine the spanning alignment's maximum coordinate with respect to the query sequence (refseq)
		#
		if (( exists $seqpairrun->{'attr'}->{'runlength'}) && (defined($seqpairrun->{'attr'}->{'runlength'}) )) {

		    my $runlength = $seqpairrun->{'attr'}->{'runlength'};
		    
		    ($ref_fmax) = &calculate_alignment_fmax($refpos, $runlength, $hspctr, $ref_fmax);

		}
		else {
		    $logger->logdie("runlength was not defined for refseq '$refseq' compseq '$compseq' <Seq-pair-run> number '$hspctr'");
		}
		#
		#------------------------------------------------------------------------------------------------------------



		my $comppos;

		#------------------------------------------------------------------------------------------------------------
		# Determine the spanning alignment's minimum coordinate with respect to the query sequence (refseq)
		#
		if (( exists $seqpairrun->{'attr'}->{'comppos'}) && (defined($seqpairrun->{'attr'}->{'comppos'}) )) {

		    $comppos = $seqpairrun->{'attr'}->{'comppos'};

		    ($comp_fmin) = &calculate_alignment_fmin($comppos, $hspctr, $comp_fmin);

		}
		else {
		    $logger->logdie("comppos was not defined for refseq '$refseq' compseq '$compseq' <Seq-pair-run> number '$hspctr'");
		}
		#
		#------------------------------------------------------------------------------------------------------------


		#------------------------------------------------------------------------------------------------------------
		# Determine the spanning alignment's maximum coordinate with respect to the query sequence (refseq)
		#
		if (( exists $seqpairrun->{'attr'}->{'comprunlength'}) && (defined($seqpairrun->{'attr'}->{'comprunlength'}) )) {

		    my $comprunlength = $seqpairrun->{'attr'}->{'comprunlength'};
		    
		    ($comp_fmax) = &calculate_alignment_fmax($comppos, $comprunlength, $hspctr, $comp_fmax);

		}
		else {
		    $logger->logdie("comprunlength was not defined for refseq '$refseq' compseq '$compseq' <Seq-pair-run> number '$hspctr'");
		}
		#
		#------------------------------------------------------------------------------------------------------------

	    }
	    else {
		$logger->logdie("attr does not exist for refseq '$refseq' compseq '$compseq'");
	    }
	}
    }



    #
    #------------------------------------------------------------------------------------------------------------------------------

    my $feature_id = $prism->store_bsml_seq_pair_alignment_component(
								     refseq                      => $refseq,
								     compseq                     => $compseq,
								     class                       => $class,
								     ref_fmin                    => $ref_fmin,
								     ref_fmax                    => $ref_fmax,
								     comp_fmin                   => $comp_fmin,
								     comp_fmax                   => $comp_fmax,
								     analysis_id                 => $analysis_id,
								     feature_id_lookup           => $phash->{'feature_id_lookup'},
								     feature_id_lookup_d         => $phash->{'feature_id_lookup_d'},
								     date                        => $phash->{'date'},
								     unknown_organism_id         => $phash->{'unknown_organism_id'},
								     sequence_lookup             => $phash->{'sequence_lookup'},
								     attributes                  => $alnref->{'BsmlAttr'},
								     exclude_classes_lookup => $exclude_classes_lookup,								     
								     );

    return ($refseq, $compseq, $feature_id, $analysis_id);


} # sub parse_seq_pair_alignment()



#-----------------------------------------------------------------
# calculate_alignment_fmin()
#
#-----------------------------------------------------------------
sub calculate_alignment_fmin {

    
    my ($refpos, $hspctr, $fmin) = @_;

    
    if ($hspctr == 1 ){ 
	#
	# Assign the first refpos value to fmin
	#
	$fmin = $refpos;
    }
    else {
	
	if ($refpos <= $fmin ){ 
	    
	    $fmin = $refpos;
	}
    }
    
    return ($fmin);
}



#-------------------------------------------------------
# calculate_alignment_fmax()
#
#-------------------------------------------------------
sub calculate_alignment_fmax {

    my ($refpos, $runlength, $hspctr, $fmax) = @_;


    my $end = $refpos + $runlength;
    
    if ($hspctr == 1){
	#
	# Assign the first end value to fmax
	#
	$fmax = $end;
    }
    else {
	
	if ($end > $fmax ){ 
	    
	    $fmax = $end;
	}
    }

    return ($fmax);
}





#------------------------------------------------------------------------------
# load_lookups()
#
# These lookups are tied to MLDBM files!
# These lookups should be STATIC!
# It is up to each client to load the necessary lookups in similar fashion:
#------------------------------------------------------------------------------
sub load_lookups {

    my ($prism, $no_placeholders) = @_;

    ## The Prism object should store the lookups (bgz 2269).

    $prism->organism_id_lookup();
    $prism->organismprop_id_lookup();
    $prism->organism_dbxref_id_lookup();
    
    $prism->analysis_id_lookup();
    $prism->analysisprop_id_lookup();
    $prism->analysisfeature_id_lookup();
    
    $prism->cv_id_lookup();
    $prism->cvterm_id_lookup();
    $prism->cvterm_id_by_alt_id_lookup();
    $prism->cvtermsynonym_synonym_lookup();
    $prism->db_id_lookup();
    $prism->dbxref_id_lookup();
    $prism->dbxrefprop_id_lookup();

    $prism->featurelocIdLookup();
    $prism->featureloc_id_lookup();
    $prism->featurepropIdLookup();
    $prism->featurepropMaxRankLookup();
    $prism->feature_relationship_id_lookup();
    $prism->feature_dbxref_id_lookup();
    $prism->feature_cvterm_id_lookup();
    $prism->feature_cvtermprop_id_lookup();
    
    $prism->GOIDToCvtermIdLookup();
    $prism->cvterm_id_by_dbxref_accession_lookup();
    $prism->cvterm_id_by_accession_lookup();
    $prism->cvterm_id_by_name_lookup(); 
    $prism->cvterm_id_by_class_lookup();
    
    $prism->cvterm_relationship_type_id_lookup();
    $prism->cvtermpath_type_id_lookup();
    $prism->evidence_codes_lookup();
    $prism->analysis_id_by_wfid_lookup();
    $prism->name_by_analysis_id_lookup();
    $prism->property_types_lookup();
}


#--------------------------------------------------------
# activate_update_mode()
#
#--------------------------------------------------------
sub activate_update_mode {

    my ($prism, $update, $lookup_type) = @_;

    
    if ((defined($update)) and ($update != 0 ) ){
	
	
	die "update functionality not supported";
	
	#
	# We are running in update mode, therefore will need to retrieve all lookups
	#
	
	if (!defined($lookup_type)){
	    $lookup_type = 'assembly';
	    $logger->info("lookup_type was not defined, therefore setting to '$lookup_type'");
	    
	    #
	    # For all table lookups, we are only interested in sequences and features that are related/in-directly related to the sequence/feature of lookup type
	    #
	}
	
	
	$logger->info("Generating all table lookups");
	
	#
	# These are sequence/feature dependent table lookups
	#
	
	my $uniquenames = &retrieve_uniquenames($prism, $lookup_type);
	
#     &add_to_featureprop_id_lookup($prism, $uniquenames, $featureprop_id_lookup, $lookup_type);
#     &add_to_featureloc_id_lookup($prism, $uniquenames, $featureloc_id_lookup, $lookup_type);
#     &add_to_feature_relationship_id_lookup($prism, $uniquenames, $feature_relationship_id_lookup, $lookup_type);
#     &add_to_feature_dbxref_id_lookup($prism, $uniquenames, $feature_dbxref_id_lookup, $lookup_type);
#     &add_to_feature_cvterm_id_lookup($prism, $uniquenames, $feature_cvterm_id_lookup, $lookup_type);
#     &add_to_feature_cvtermprop_id_lookup($prism, $uniquenames, $feature_cvtermprop_id_lookup, $lookup_type);
#     &add_to_analysisfeature_id_lookup($prism, $uniquenames, $analysisfeature_id_lookup, $lookup_type);
	
	
    }
}


#-----------------------------------------------------------------------------------
# dir_contains_bcp_files()
#
#-----------------------------------------------------------------------------------
sub dir_contains_bcp_files {

    my ($outdir, $append_bcp) = @_;
    

    if ((defined($append_bcp)) && ($append_bcp == 1)) {

	opendir(THISDIR, "$outdir") or $logger->logdie("Could not open directory '$outdir'");
	
	my @allfiles = readdir THISDIR;
	
	
	
	my $bcp_next_values = {};
	
	foreach my $file (sort @allfiles){
	    
	    if ($file =~ /(\S+)\.out$/){
		
		my $fullpath = $outdir . "/" . $file;
		
		$bcp_next_values->{$1} = &get_last_identifier($fullpath);
	    }
	}

	return $bcp_next_values;
    }
}



#-----------------------------------------------------------------------------------
# get_last_identifier()
#
#-----------------------------------------------------------------------------------
sub get_last_identifier {

    my $file = shift;

    $/ = "\0\n";
    my @lines;

    tie @lines, 'Tie::File', $file;

    my $lastline =  $lines[-1]; #last line of the file

    my $identifier;

    my $ss = ';;\w;;_\d';
    my $s = "[$ss|\\d]+\0";

    $/ = "\n";

    if ($lastline =~ /^;;\S+;;_(\d+)\0\s+/){
	#
	# Process a line which contains placeholder values in place of serial identifier values
	#

	return $1;
    }
    elsif ($lastline =~ /^(\d+)\0\s+/){
	#
	# Process a line which contains actual integer serial identifier values
	#
	return $1;
    }
    else {
	$logger->logdie("Could not parse line '$lastline'");
    }
}



#-----------------------------------------------------------------------------------
# set_prism_env()
#
#-----------------------------------------------------------------------------------
sub set_prism_env {

    my ($server, $vendor) = @_;

    if (!defined($server)){
	$logger->logdie("server was not defined");
    }
    if (!defined($vendor)){
	$logger->logdie("vendor was not defined");
    }

    ## We're overriding the env stored in conf/Prism.conf
    my $prismenv = "Chado:$vendor:$server";

    $ENV{PRISM} = $prismenv;
}



#-----------------------------------------------------------------------------------
# set_cache()
#
#-----------------------------------------------------------------------------------
sub set_cache {

    my ($cache_dir, $readonlycache) = @_;

    if (defined($cache_dir)){
	
	$ENV{DBCACHE} = "file";
	
	if (-e $cache_dir){
	    if (-w $cache_dir){
		if (-r $cache_dir){
		    $ENV{DBCACHE_DIR} = $cache_dir;
		    $logger->info("setting cache_dir to $ENV{DBCACHE_DIR}");
		}
		else{
		    $logger->warn("cache_dir '$cache_dir' is not writeable.  Using default $ENV{DBCACHE_DIR}");
		}
	    }
	    else{
		$logger->warn("cache_dir '$cache_dir' is not readable.  Using default $ENV{DBCACHE_DIR}");
	    }
	}
	else{
	    $logger->warn("cache_dir '$cache_dir' does not exist.  Using default $ENV{DBCACHE_DIR}");
	}
	
	if ((defined($readonlycache)) && ($readonlycache == 1)){
	    #
	    # User has specified that the tied MLDBM lookup cache files should only be accessed in read mode
	    #
	    $ENV{_CACHE_FILE_ACCESS} = 'O_RDONLY';
	}
    }
}


#-----------------------------------------------------------------------------------
# set_logger()
#
#-----------------------------------------------------------------------------------
sub set_logger {

    my ($logfile, $debug_level) = @_;

    $logfile = "/tmp/bsml2chado.pl.log" if (!defined($logfile));

    my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				     'LOG_LEVEL'=>$debug_level);
    

    my $logger = Coati::Logger::get_logger(__PACKAGE__);
    
    return $logger;
}


#-----------------------------------------------------------------------------------
# check_id_repository()
#
#-----------------------------------------------------------------------------------
sub check_id_repository {

    my ($id_repository) = @_;

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

#------------------------------------------------------------
# is_input_of()
#
#------------------------------------------------------------
sub is_input_of {

    my ($bsmllinks) = @_;

    my $is_input_of=0;
    my $is_analysis_linked=0;

    foreach my $hash ( @{$bsmllinks} ){
	
	if ((exists ($hash->{'rel'})) and (defined($hash->{'rel'}))) {
	    
	    my $rel = $hash->{'rel'};
	    
	    if ($rel eq 'analysis') {
		
		$is_analysis_linked = 1;

		if (( exists $hash->{'role'}) && (defined($hash->{'role'}))) {
				
		    my $role = $hash->{'role'};

		    if ($role eq 'input_of') {

			$is_input_of = 1;
		    }
		}
	    }
	}
    }

    return $is_input_of;

}


#---------------------------------------------------------------
# get_classes_lookup()
#
#---------------------------------------------------------------
sub get_classes_lookup {

    my ($classes) = @_;
    
    my @class_list = split(/,/,$classes);

    my %lookup = map { $_ => 1 } @class_list;

    return \%lookup;
}
