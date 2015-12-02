#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

legacyparafam2bsml.pl - Migrates Nt/Prok/Euk legacy databases to BSML documents

=head1 SYNOPSIS

USAGE:  legacyparafam2bsml.pl -D database -P password -U username [--alt-database] [--att_type] [-d debug_level] [--chromosome] [--ev_type] [--family_id] [-h]  [--idgen_identifier_version] [--id_mapping_directory] [-l logfile] [-m] [-o outdir] [--schema_type] [--alt-species]

=head1 OPTIONS

=over 8

=item B<--username,-U>

Database username

=item B<--password,-P>

Database password

=item B<--database,-D>

Source legacy organism database name

=item B<--help,-h>

Print this help

=item B<--man,-m>

Display pod2usage man pages for this script

=item B<--schema_type>

Optional - default is prok. Valid alternative: euk

=item B<--logfile,-l>

Optional - Logfile log file.  Defaults are:
           If asmbl_list is defined /tmp/legacyparafam2bsml.pl.database_$database.asmbl_id_$asmbl_id.log
           Else /tmp/legacyparafam2bsml.pl.database_$database.pid_$$.log

=item B<--outdir,-o>

Optional - Output directory for bsml document.  Default is current working directory

=item B<--alt-database>

Optional - User can specify a database prefix which will override the default legacy annotation database name

=item B<--alt-species>

Optional - User can specify an override value for species

=item B<--att_type>

Optional - ORF_attribute att_type.  Default value is 'TEMPFAM2'

=item B<--ev_type>

Optional - evidence type.  Default value is 'para3'

=item B<--chromosome>

Optional - The user can specify a value for clone_info.chromo.  Default will be all chromosomes.

=item B<--family_id>

Optional - Comma-separated list of paralogous family identifier values.  If none is specified, all present in the database are processed.

=item B<--id_mapping_directory>

Optional - Comma-separated list of directories that contains ID mapping files

=item B<--idgen_identifier_version>

Optional - The user can override the default version value appended to the feature and sequence identifiers (default is 0)


=back

=head1 DESCRIPTION

legacyparafam2bsml.pl - Migrates paralogous families and domain data from legacy databases to BSML

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


$| = 1;


#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------
my ($database, $username, $password, $debug_level, $help, $man, $logfile, 
    $outdir, $backup, $schema_type, $alt_species, $alt_database, $family_id,
    $id_mapping_directory, $idgen_identifier_version, $id_repository,
    $output_mapping_file, $ev_type, $att_type, $chromosome); 

my $results = GetOptions (
			  'username|U=s'       => \$username, 
			  'password|P=s'       => \$password,
			  'database|D=s'       => \$database,
			  'debug_level|d=s'    => \$debug_level,
			  'help|h'             => \$help,
			  'man|m'              => \$man,
			  'logfile|l=s'        => \$logfile,
			  'outdir|o=s'         => \$outdir,
			  'schema_type=s'      => \$schema_type,
			  'alt-database=s'     => \$alt_database,
			  'alt-species=s'      => \$alt_species,
			  'family_id=s'        => \$family_id,
			  'ev_type=s'          => \$ev_type,
			  'id_mapping_directory=s' => \$id_mapping_directory,
			  'idgen_identifier_version=s' => \$idgen_identifier_version,
			  'id_repository=s'            => \$id_repository,
			  'output_mapping_file=s' => \$output_mapping_file,
			  'att_type=s'            => \$att_type,
			  'chromosome=s'          => \$chromosome
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

if (!defined($id_repository)){
    print STDERR ("id_repository was not defined\n");
    $fatalCtr++;
}

if ($fatalCtr>0){
    &print_usage();
}

if (defined($family_id)){
    $family_id =~ s/\s*//g;
}

##
## Set the logfile name if not defined
##
if (!defined($logfile)){
    if (defined($family_id)){
	if ($family_id =~ /,/){
	    $logfile = "/tmp/legacyparafam2bsml.pl.log";
	}
	else {
	    $logfile = "/tmp/legacyparafam2bsml.pl." . $family_id . ".log";
	}
    }
    else {
	$logfile = "/tmp/legacyparafam2bsml.pl.log";
    }
}

## instantiate Coati::Logger
my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				 'LOG_LEVEL'=>$debug_level);

my $logger =  Coati::Logger::get_logger(__PACKAGE__);



if ((defined($alt_database)) &&
    ($alt_database eq 'none')){
    $alt_database = undef;
}

if ((defined($alt_species)) &&
    ($alt_species eq 'none')){
    $alt_species = undef;
}


## For the factory method pattern - users can control which classes
## will be instantiated by settting the PRISM environmental variable.
$ENV{PRISM} = "Prok:Sybase:SYBTIGR";

if ((defined($schema_type)) && ( $schema_type eq 'euk' )){
    $ENV{PRISM} = "Euk:Sybase:SYBTIGR";
}

## verify and set the output directory
$outdir = &verify_and_set_outdir($outdir);

## Instantiate new Prism reader object
$logger->debug("Instantiating Prism object") if ($logger->is_debug());

my $prism = new Prism(user => $username,
		      password => $password,
		      db => $database);

## Retrieve the organism related data from common..genomes and new_project
my $orgdata = $prism->organismData($database);

my $idGenerator = Coati::IdGenerator->new('id_repository' => $id_repository);

## To store all retrieved ID mappings from the mapping files in the mapping directories
## and also store all new ID mappings generated by this program
my $idMappingLookup = {};

## To keep track of all new ID mapping generated by this program
my $newIdMappingLookup = {};

&getIdMappingTiedLookup($id_mapping_directory, 
			$database);

#-------------------------------------------------------------------------------------------------------------------
# legacyparafam2bsml.pl will generate one BSML document per paralogous family.
# It will contain Genome, Organism, Sequence stubs, Feature stubs, Multiple-alignment-table (paralogous families),
# Seq-pair-alignment, Seq-pair-run (domain hits/alignments) and Analysis elements.

# 1. If the paralogous family identifier is not specified, retrieve a list of paralogous family identifiers.

# 2. Generate lookup1 based on the following records:
# family_id (ORF_attribute.score)
# domain_id (alignment.align_name)
# alignment (alignment.alignment)

# 3. Generate lookup2->{family_id}->{domain_id} based on the following records:
# family_id (ORF_attribute.score)
# domain_id (alignment.align_name)
# f.end5, f.end3, o.score, e.accession, e.feat_name, e.rel_end5, e.rel_end3, m_lend, m_rend 

# 4. Create the <Multiple-alignment-table> objects

# 5. Create the <Seq-pair-alignment> objects


# Notes:
# We need the assembly.asmbl_id since we will need to create <Sequence>, <Feature-tables>
# and <Feature> objects for the assemblies and genes of the paralogous families.


# <Genomes>, <Genome>, <Organism>, <Sequences>, <Sequence>, <Feature-table>
#
#-------------------------------------------------------------------------------------------------------------------

my $paralogous_families;

if (!defined($family_id)){
    $paralogous_families = $prism->paralogous_family_identifiers($ev_type, $att_type, $chromosome);
}
else {
    @{$paralogous_families} = split(/,/, $family_id);
}

my $family_count = scalar(@{$paralogous_families});

if ($family_count > 0){

    foreach my $famid ( sort @{$paralogous_families} ) {

	print "Processing paralogous family '$famid'\n";

	## Retrieve the paralogous family data from the legacy annotation
	## database and store in appropriate lookup.
	my $family_lookup = $prism->paralogous_family_alignment($famid, $ev_type, $att_type, $chromosome);

	my $familyAlignmentCounts = scalar(@{$family_lookup});

	if ($familyAlignmentCounts>0){

	    ## Retrieve the paralogous family domain data from the legacy
	    ## annotation database and store in appropriate lookup.
	    my $domain_lookup = $prism->domain_to_paralogous_family($famid, $ev_type, $att_type, $chromosome);

	    my $domainCounts = keys (%{$domain_lookup});

	    if ($domainCounts>0){
		
		## We are creating one BSML document per paralogous family.
		my $doc = new BSML::BsmlBuilder();
		
		## The BSML document name will be based on the legacy 
		## annotation database name and the paralogous family
		## identifier.
		$doc->{'doc_name'} = $database . '_' . $famid .'.bsml';
		
		## The genome_id will be associated with the assembly
		## <Sequence> elements via their <Link> elements.
		my $genome_id = &create_genome_component($doc, $orgdata, $alt_species);
		
		## Store the major information in the BSML object layer.
		if (&create_paralogous_family_doc($genome_id, $family_lookup, $domain_lookup, $doc, $outdir, $database)){
		
		    ## Output the BSML document to the specified output directory.
		    &write_out_bsml_doc($outdir, $doc);
		}
		else {
		    $logger->warn("None of the models with domain hits were part of the family alignment ".
				  "for family '$famid'");
		}
	    }
	    else {
		$logger->warn("Did not find any domains in database ".
			      "'$database' for family '$family_id'");
	    }
	}
	else {
	    $logger->warn("Did not find any alignments in database ".
			  "'$database' for family '$family_id' ");
	}
    }
}
else {

    $logger->warn("Did not find any paralogous families to process");

    exit(0);
}

&writeNewIdMappingFile($output_mapping_file,
		       $newIdMappingLookup,
		       $outdir);


print "$0 program execution completed\n";
print "Log file is '$logfile'\n";
exit(0);

#------------------------------------------------------------------------------------------------------------------------------------
#
#                END OF MAIN SECTION -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# create_genome_component()
#
#-------------------------------------------------------------------------------
sub create_genome_component {    
    
    my ($doc, $orgdata, $alt_species) = @_;

    my ($genus, $species, @straint) = split(/\s+/,$orgdata->{'name'});

    my $original_species = $species;

    if (defined($alt_species)){
	$species = $alt_species;
    }

    foreach my $st (@straint){
	$species = $species . ' ' . $st if (defined($st));
    }

    my $identifier = lc(substr($genus,0,1)) . '_' . lc($species);

    my $genome_elem = $doc->createAndAddGenome( id => $identifier );

    if (!defined($genome_elem)){
	$logger->logdie("Could not create <Genome> element object reference for organism '$orgdata->{'name'}'");
    }


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


    $identifier =~ s/\s*//g;

    $genome_elem->addattr('id', $identifier);

    return $identifier
}


#----------------------------------------------------
# store_organism_attribute()
#
#----------------------------------------------------
sub store_organism_attribute {

    my ($doc, $organism_elem, $orgdata, $species, $alt_species) = @_;

    foreach my $attribute ('abbreviation', 'gram_stain', 'genetic_code', 'mt_genetic_code'){
	
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


#-------------------------------------------------------------------------------
# create_paralogous_family_doc()
#
#-------------------------------------------------------------------------------
sub create_paralogous_family_doc {
    
    my ($genome_id, $family_lookup, $domain_lookup, $doc, $outdir, $database, $identifier_to_element_lookup) = @_;

    my $identifier_to_element_lookup = {};
    
    my $feature_table_elem_lookup = {};

    my $family_domain_lookup = {};

    my $seq_pair_alignment_lookup = {};
    
    my $analysis_lookup = {};

    my $link_elem_lookup = {};

    my $uniquename_lookup = {};

    my $class = 'CDS';

    ## This is the parent sequence to which the subject/match object localizes.
    my $domain_sequence_stub_elem = &create_sequence_with_feature_tables($doc,                # BsmlDoc object reference
									 undef,               # Genome object reference
									 'not_known',         # Sequence identifier e.g. asmbl_id
									 undef,               # Feature-table object reference
									 'synthetic_sequence' # Sequence class
									 );

    my $someAlignmentAdded=0;

    foreach my $family_array ( @{$family_lookup} ){

	my $family_id = $family_array->[0];

	my $domain_name = $family_array->[1];

	if ( exists $family_domain_lookup->{$family_id}->{$domain_name} ){
	    if ($logger->is_debug()){
		$logger->debug("Already processed paralogous family ID '$family_id' ".
			       "and domain ID '$domain_name' pair");
	    }
	    next;
	}
	else {
	    $family_domain_lookup->{$family_id}->{$domain_name}++;
	}

	my ($deinterlaced_alignments, $msf_type) = &deinterlace_alignments( $family_array->[2] );  # alignment.alignment

	my $daCounts = (keys %{$deinterlaced_alignments});
	if ($logger->is_debug()){
	    $logger->debug("Number of de-interlaced alignments for family '$family_id' domain '$domain_name' is '$daCounts'");
	}

 	my $bsmlSequenceAlignment;
	my $bsmlAlignmentSummary;
	
	my $seqnum=0;

	my $sequences_tag;
	
	my $seqnum_lookup = {};

	my $domkeys = ( keys %{$domain_lookup->{$domain_name}});
	
	if ($logger->is_debug()){
	    $logger->debug("There were '$domkeys' hits for family_id '$family_id' domain name '$domain_name'");
	}

	## keep track of the number of paralogous family alignments
	## were actually inserted into the BSML Multiple-alignment-table
	my $alignmentFeatNameCtr=0;

	foreach my $feat_name ( sort keys %{$domain_lookup->{$domain_name}} ) {

	    foreach my $domain_array ( @{$domain_lookup->{$domain_name}->{$feat_name}}) { 

		my $asmbl_id  = $domain_array->[1];  # asm_feature.asmbl_id

		my $accession = "domain:$domain_array->[0]";  # evidence.accession  (domain_id)

		my $assemblyId = $database . '_' . $asmbl_id . '_assembly';

		my $assembly_identifier = &getIdFromIdGenerator($database,
								$assemblyId,
								'assembly');

		my $asmbl_id_feature_table_elem = &create_sequence_with_feature_tables($doc,                        # BsmlDoc object reference
										       $genome_id,                  # BsmlGenome object identifier
										       $assembly_identifier,        # Sequnece identifier
										       $feature_table_elem_lookup,  # Feature-table object reference
										       'assembly');                 # Sequence class

		
		my $uniquename = &get_uniquename($asmbl_id, 
						 $database, 
						 $feat_name, 
						 $class);

		$uniquename_lookup->{$feat_name} = $uniquename;
		
		## Create the <Feature> element object for the feat_name
		my $feat_name_feature_elem = &create_feature_object($doc,                             # BsmlDoc object reference
								    $class,                           # BsmlFeature class
								    $asmbl_id_feature_table_elem,     # Feature-table object reference
								    $uniquename,                      # Feature identifier
								    $identifier_to_element_lookup);   #
		
		## Create the <Feature> element object for the accession
		my $accession_feature_elem = &create_feature_object($doc,                             # BsmlDoc object reference
								    'located_sequence_feature',       # BsmlFeature class
								    $domain_sequence_stub_elem,       # Feature-table object reference
								    $accession,                       # Feature identifier
								    $identifier_to_element_lookup);   #

		## Create the <Seq-pair-alignment> and <Seq-pair-run> element objects
		&create_paralogous_seq_pair_alignments($doc,                          # BsmlDoc object reference 
						       $family_id,                    #
						       $domain_name,                  # alignment.align_name
						       $feat_name,                    # evidence.feat_name
						       $uniquename,                   # BsmlFeature identifier
						       $accession,                    # evidence.accession
						       $domain_array->[4],            # evidence.rel_end5
						       $domain_array->[5],            # evidence.rel_end3
						       $domain_array->[6],            # evidence.m_lend
						       $domain_array->[7],            # evidence.m_rend
						       $seq_pair_alignment_lookup,    #
						       $analysis_lookup,              #
						       $outdir,                       #
						       $identifier_to_element_lookup, #
						       $link_elem_lookup);            #
		
		

		if ( exists $deinterlaced_alignments->{$feat_name}){
		    if (exists $deinterlaced_alignments->{$feat_name}->{'length'}){
			
			if (!defined($bsmlSequenceAlignment)){
			    ## Create <Multiple-alignment-table> element objects
			    ($bsmlSequenceAlignment, $bsmlAlignmentSummary) = &create_paralogous_family_multiple_alignment($doc,             # BsmlDoc object reference
															   $family_id,       #
															   $domain_name,     # alignment.align_name
															   $msf_type);
			}

			$seqnum++;
			
			$seqnum_lookup->{$uniquename} = $seqnum;
			
			my $length = $deinterlaced_alignments->{$feat_name}->{'length'};
			
			$doc->createAndAddAlignedSequence(
							  'alignmentSummary' => $bsmlAlignmentSummary,
							  'seqnum'           => $seqnum,
							  'length'           => $length,
							  'name'             => "$uniquename:$seqnum"
							  );
			$sequences_tag .= "$seqnum:";

			$alignmentFeatNameCtr++;
		    }
		    else {
			## The length attribute was not defined for this model with
			## this particular feat_name value
			$logger->logdie("model with feat_name '$feat_name' does belong to domain '$domain_name' ".
					"and is part of the MSF alignment for paralogous family '$family_id'  however ".
					"the length attribute is not defined");
		    }
		}
		else {
		    if ($logger->is_debug()){
			$logger->debug("model with feat_name '$feat_name' does belong to domain '$domain_name' ".
				       "however was not part of the MSF alignment for paralogous family '$family_id'");
		    }
		}
	    }
	}

	if ($alignmentFeatNameCtr == 0){
	    $logger->fatal("family data for family '$family_id'". Dumper $family_array->[2]);
	    $logger->fatal("domain data for domain '$domain_name'". Dumper $domain_lookup->{$domain_name});
	    $logger->fatal("No Aligned-sequences were inserted into the Multiple-alignment-table ".
			   "for paralogous family '$family_id' domain '$domain_name'.  This means that there ".
			   "were no pairwise alignments (domains) for this paralogous familiy alignment.");
	}
	else {
	    
	    $bsmlSequenceAlignment->addattr( 'sequences', $sequences_tag );
	    
	    &add_multiple_alignment_sequence($doc, 
					     $bsmlSequenceAlignment,
					     $deinterlaced_alignments,
					     $uniquename_lookup,
					     $seqnum_lookup,
					     $domain_name);

	    $someAlignmentAdded++;
	}
    }

    return $someAlignmentAdded;
    
}


#-------------------------------------------------------------------------------
# create_paralogous_family_multiple_alignment()
#
#-------------------------------------------------------------------------------
sub create_paralogous_family_multiple_alignment {

    my ($doc, $family_id, $domain_name, $msf_type) = @_;


    my $table = $doc->createAndAddMultipleAlignmentTable( 'molecule-type' => $msf_type );

    if (!defined($table)){
	$logger->logdie("Could not create <Multiple-alignment-table> element object for family_id '$family_id' domain_name '$domain_name'");
    }

    $table->addattr('class', 'match');


    my $bsmlAlignmentSummary = $doc->createAndAddAlignmentSummary( 
								   'multipleAlignmentTable' => $table,
								   'seq-type'               => $msf_type,
								   'seq-format'             => 'msf'
								   );

    if (!defined($bsmlAlignmentSummary)){
	$logger->logdie("Could not create <Alignment-summary> element object for family_id '$family_id' domain_name '$domain_name'");
    }
    
    my $bsmlSequenceAlignment = $doc->createAndAddSequenceAlignment( 'multipleAlignmentTable' => $table );

    if (!defined($bsmlSequenceAlignment)){
	$logger->logdie("Could not create <Sequence-alignment> for family_id '$family_id' domain_name '$domain_name'");
    }


    $table->addBsmlLink('analysis', '#'."$domain_name", 'computed_by');


    return ($bsmlSequenceAlignment, $bsmlAlignmentSummary);
}


#-------------------------------------------------------------------------------
# add_multiple_alignment_sequence()
#
#-------------------------------------------------------------------------------
sub add_multiple_alignment_sequence {

    my ($doc, $bsmlSequenceAlignment, $alignments, $uniquename_lookup, $seqnum_lookup, $domain_name) = @_;

    foreach my $feat_name (keys %{$alignments} ) {

	if (exists $uniquename_lookup->{$feat_name}) {

	    my $uniquename = $uniquename_lookup->{$feat_name};

	    if ( exists $seqnum_lookup->{$uniquename} ) {

		my $seqnum = $seqnum_lookup->{$uniquename};
		
		
		if (exists $alignments->{$feat_name}->{'alignment'}){
		    
		    my $alignment = join ("\n", @{ $alignments->{$feat_name}->{'alignment'} });
		    
		    $doc->createAndAddSequenceData(
						   'sequenceAlignment' => $bsmlSequenceAlignment,
						   'seq-name'          => "$uniquename:$seqnum",
						   'seq-data'          => $alignment
						   ); 
		}
		else {
		    $logger->warn("feat_name '$feat_name' had hit against domain '$domain_name', however did not show up in the alignment");
		}
	    }
	    else {
		$logger->warn("seqnum was not defined for uniquename '$uniquename' feat_name '$feat_name' in the seqnum_lookup");
	    }
	}
	else {
	    $logger->warn("uniquename was not defined for feat_name '$feat_name' in the uniquename_lookup");
	}
    }
}

#-------------------------------------------------------------------------------
# deinterlace_alignments()
#
#-------------------------------------------------------------------------------
sub deinterlace_alignments {

    my ($alignment) = @_;

    print "De-interlacing the multiple alignment\n";

    my @lines = split(/\n/, $alignment);
    
    my $msf_type;

    my $MSF_alignments;

    my $doubleSlashEncountered = 0;

    my $MSFFlagEncountered = 0;

    foreach my $line (@lines){

	($MSFFlagEncountered++) if ($line =~ /MSF:/);

	next if ($MSFFlagEncountered == 0);

	($doubleSlashEncountered++) if ( $line =~ /^\/\//);

	if ( $doubleSlashEncountered == 0){
		
	    if (!defined($msf_type)){
		
		## Determine the msf_type
		if( $line =~ /MSF:\s*([\S]+)\s*Type:\s*([\S]+)\s*Check/) {
		    
		    my $msf_length = $1;
		    
		    return undef if ($msf_length == 0);   #abort if align_len = 0
		    
		    $msf_type = ( $2 eq 'N') ? 'nucleotide' : 'protein';

		}
	    }
	    
	    if ($line =~ /Name:\s*([\S]+)\s*[o]{2}\s*Len:\s*([\S]+)\s*Check:\s*([\S]+)\s*Weight:\s*([\S]+)/) {
		my $name    = $1;
		my $ali_len = $2;
		my $check   = $3;
		my $weight  = $4;

		my ($feat_name, $range) = split(/\//, $name);
		
		if ($logger->is_debug()){
		    $logger->debug("feat_name '$feat_name' range '$range' name '$name' length '$ali_len' check '$check' weight '$weight'");
		}

		$MSF_alignments->{$feat_name}->{'length'} = $ali_len;
		$MSF_alignments->{$feat_name}->{'check'}  = $check;
		$MSF_alignments->{$feat_name}->{'weight'} = $weight;
		$MSF_alignments->{$feat_name}->{'range'} = $range;
		$MSF_alignments->{$feat_name}->{'alignment'} = [];
	    }
	}

	if (($line =~ /^([\S]+)/) && ($doubleSlashEncountered == 1 ) && ( $line !~ /^\/\//)){
	    
	    my $name = $1;

	    my ($feat_name, $range) = split(/\//, $name);
	    
	    if( exists($MSF_alignments->{$feat_name})) {
		push( @{ $MSF_alignments->{$feat_name}->{'alignment'} }, $line );
            }
	    else {
		$logger->fatal("feat_name '$feat_name' is not a valid polypeptide name ".
			       "(doubleSlashEncountered '$doubleSlashEncountered' line '$line' ".
			       "alignment '$alignment'");
		die "feat_name '$feat_name' line '$line' doubleSlashEncountered '$doubleSlashEncountered'";
            }
	}
	
    }
    
    if ($logger->is_debug()){
	$logger->debug("MSF_alignments:". Dumper $MSF_alignments);
	$logger->debug("msf_type:". Dumper $msf_type);
    }

    return ($MSF_alignments, $msf_type);
}


#-------------------------------------------------------------------------------
# create_paralogous_domain_seq_pair_alignments()
#
#-------------------------------------------------------------------------------
sub create_paralogous_seq_pair_alignments {
    
    my ($doc, $family_id, $domain_name, $feat_name, $uniquename, $accession, $rel_end5, $rel_end3, $m_lend, $m_rend, $seq_pair_alignment_lookup,
	$analysis_lookup, $outdir, $identifier_to_element_lookup, $link_elem_lookup) = @_;

    my $analysis_id = &create_analysis($doc, $domain_name, $outdir, "paralogous_domain", $analysis_lookup, $family_id);

    my $seq_pair_alignment_elem;

    if (( exists $seq_pair_alignment_lookup->{$feat_name}->{$accession}) &&
	(defined($seq_pair_alignment_lookup->{$feat_name}->{$accession}))) {
	
	$seq_pair_alignment_elem = $seq_pair_alignment_lookup->{$feat_name}->{$accession};
	
    }
    else {

	$seq_pair_alignment_elem = &create_seq_pair_alignment($doc, $analysis_id, $uniquename, $accession, $identifier_to_element_lookup, $link_elem_lookup);

	$seq_pair_alignment_lookup->{$feat_name}->{$accession} = $seq_pair_alignment_elem;

    }

    &create_seq_pair_run($doc, $rel_end5, $rel_end3, $m_lend, $m_rend, $seq_pair_alignment_elem);

}

#-------------------------------------------------------------------------------
# create_sequence_with_feature_tables()
#
#-------------------------------------------------------------------------------
sub create_sequence_with_feature_tables {

    my ($doc, $genome_id, $uniquename, $feature_table_elem_lookup, $class) = @_;

    my $feature_table_elem;

    if ((exists $feature_table_elem_lookup->{$uniquename}) && (defined($feature_table_elem_lookup->{$uniquename}))) {
	$feature_table_elem = $feature_table_elem_lookup->{$uniquename};
    }
    else {

	## Create <Sequence> element stub for the assembly
	my $sequence_elem = $doc->createAndAddExtendedSequenceN(
								'id'       => $uniquename, 
								'title'    => undef,
								'length'   => undef,
								'molecule' => 'dna', 
								'locus'    => undef,
								'dbsource' => undef,
								'icAcckey' => undef,
								'topology' => undef,
								'strand'   => undef,
								'class'    => $class
								);
	if (!defined($sequence_elem)){    
	    $logger->logdie("Could not create a <Sequence> element object for assembly '$uniquename'");
	}

	if (defined($genome_id)){

	    ## Link the assembly's <Sequence> to the <Genome>
	    my $link_elem = $doc->createAndAddLink(
						   $sequence_elem,
						   'genome',        # rel
						   "#$genome_id"    # href
						   );
	    
	    if (!defined($link_elem)){
		$logger->logdie("Could not create a 'genome' <Link> element object reference for assembly <Sequence> '$uniquename' genome_id '$genome_id'");
	    }
	}
	
	## Create <Feature-table> element object
	$feature_table_elem = $doc->createAndAddFeatureTable($sequence_elem);
	
	if (!defined($feature_table_elem)){
	    $logger->logdie("Could not create <Feature-table> element object for assembly <Sequence> '$uniquename'");
	}

	## Store the <Feature-table> element object reference in the lookup.
	$feature_table_elem_lookup->{$uniquename} = $feature_table_elem;
    }

    return $feature_table_elem;
}

#-------------------------------------------------------------------------------
# get_uniquename()
#
#-------------------------------------------------------------------------------
sub get_uniquename {

    my ($asmbl_id, $database, $feat_name, $feat_type) = @_;

    my $uniquename = $database . '_' . $asmbl_id . '_' . $feat_name . '_'. $feat_type;
    
    ## Now using IdGenerator
    $uniquename = &getIdFromIdGenerator($database, $uniquename, $feat_type);

    return $uniquename;    
    
}

#-------------------------------------------------------------------------------
# create_feature_object()
#
#-------------------------------------------------------------------------------
sub create_feature_object {

    my ($doc, $feat_type, $feature_table_elem, $uniquename, $identifier_to_element_lookup) = @_;

    my $feature_elem;

    if (( exists $identifier_to_element_lookup->{$uniquename}) && (defined($identifier_to_element_lookup->{$uniquename}))){
	## Retrieve the <Feature> element object reference for the feat_name
	$feature_elem = $identifier_to_element_lookup->{$uniquename};
    }    
    else {
	## Create <Feature> element object
	$feature_elem = $doc->createAndAddFeature(
						  $feature_table_elem,   # <Feature-table> element object reference
						  $uniquename,           # id
						  undef,                 # title
						  $feat_type             # class
						  );
	

	if (!defined($feature_elem)){
	    $logger->logdie("Could not create <Feature> element object for '$uniquename'");
	}

	## Store the reference on the lookup
	$identifier_to_element_lookup->{$uniquename} = $feature_elem;

    }
    return $feature_elem;
}

#-------------------------------------------------------------------------------
# create_analysis()
#
#-------------------------------------------------------------------------------
sub create_analysis {

    my ($doc, $domain_name, $outdir, $program, $analysis_lookup, $family_id) = @_;

    my $analysis_id;

    if (( exists $analysis_lookup->{$domain_name}) && (defined($analysis_lookup->{$domain_name}))) {

	$analysis_id = $analysis_lookup->{$domain_name};
    }
    else {

	my $analysis_elem = $doc->createAndAddAnalysis( 'id' => $domain_name );
	
	if (!defined($analysis_elem)){
	    $logger->logdie("Could not create <Analysis> for analysis_type 'paralogous_domain_analysis'");
	}
	
	my $programversion  = $program . '_version1';
	my $description = "database:$database;family_id:$family_id;domain_name:$domain_name";
	
	## Create <Attribute> for the program
	my $program_attribute = $doc->createAndAddBsmlAttribute(
								$analysis_elem,
								'program',
								$program
								);
	if (!defined($program_attribute)) {
	    $logger->logdie("Could not create <Attribute> for program '$program'");
	}
	
	## Create <Attribute> for the programversion
	my $programversion_attribute = $doc->createAndAddBsmlAttribute(
								       $analysis_elem,
								       'programversion',
								       $programversion
								       );
	if (!defined($programversion_attribute)) {
	    $logger->logdie("Could not create <Attribute> for programversion '$programversion'");
	}

	## Create <Attribute> for the algorithm
	my $algorithm_attribute = $doc->createAndAddBsmlAttribute(
								  $analysis_elem,
								  'algorithm',
								  $program
								  );
	if (!defined($algorithm_attribute)) {
	    $logger->logdie("Could not create <Attribute> for algorithm '$program'");
	}
	
	## Create <Attribute> for the sourcename
	my $sourcename_attribute = $doc->createAndAddBsmlAttribute(
								   $analysis_elem,
								   'sourcename',
								   $doc->{'doc_name'}
								   );
	if (!defined($sourcename_attribute)) {
	    $logger->logdie("Could not create <Attribute> for sourcename '$doc->{'doc_name'}'");
	}

	## Create <Attribute> for the domain
	my $domain_attribute = $doc->createAndAddBsmlAttribute(
							       $analysis_elem,
							       'domain_name',
							       $domain_name
							       );
	if (!defined($domain_attribute)) {
	    $logger->logdie("Could not create <Attribute> for domain_name '$domain_name'");
	}
	

	## Create <Attribute> for the family
	my $family_attribute = $doc->createAndAddBsmlAttribute(
							       $analysis_elem,
							       'family_id',
							       $family_id
							       );
	if (!defined($family_attribute)) {
	    $logger->logdie("Could not create <Attribute> for family_id '$family_id'");
	}

	## Create <Attribute> for the description
	my $descriptionAttribute = $doc->createAndAddBsmlAttribute(
								   $analysis_elem,
								   'description',
								   $description
								   );
	if (!defined($descriptionAttribute)) {
	    $logger->logdie("Could not create a description <Attribute> with content '$description'");
	}
	




	$analysis_id = $analysis_elem->{'attr'}->{'id'};

	$analysis_lookup->{$domain_name} = $analysis_id;
    }
    
    return $analysis_id;

}

#-------------------------------------------------------------------------------
# create_seq_pair_alignment()
#
#-------------------------------------------------------------------------------
sub create_seq_pair_alignment {

    my ($doc, $analysis_id, $uniquename, $accession, $identifier_to_element_lookup, $link_elem_lookup) = @_;

    ##
    ## Will create:
    ## <Seq-pair-alignment>
    ## <Link> to the <Feature> or <Sequence> stubs
    ## <Link> to the <Analysis>
    ##

    my $href = $analysis_id;

    ##
    ## Create the <Link> between <Feature> or <Sequence> and the <Analysis> element.
    ## for the feat_name/uniquename
    ##
    if ( exists $identifier_to_element_lookup->{$uniquename}){
	
	my $element = $identifier_to_element_lookup->{$uniquename};

	##
	## Create a <Link> element object to link the <Feature> or <Sequence> to the <Analysis>
	##
	my $link_elem = $doc->createAndAddLink(
					       $element,     # <Feature> or <Sequence> element object reference
					       'analysis',   # rel
					       $href,        # href
					       'input_of' # role
					       );
	
	if (!defined($link_elem)){
	    $logger->logdie("Could not create an 'analysis' <Link> element object reference for <Feature> or <Sequence> with id '$uniquename'");
	}

    }
    else {
	$logger->logdie("element object was not defined for refseq '$uniquename'");
    }


    if ( ! exists $link_elem_lookup->{$accession}) {
	
	##
	## Create the <Link> between <Feature> or <Sequence> and the <Analysis> element.
	## for the accession.
	##
	if ( exists $identifier_to_element_lookup->{$accession}){
	    
	    my $element = $identifier_to_element_lookup->{$accession};
	    
	    ##
	    ## Create a <Link> element object to link the <Feature> or <Sequence> to the <Analysis>
	    ##
	    my $link_elem = $doc->createAndAddLink(
						   $element,     # <Feature> or <Sequence> element object reference
						   'analysis',   # rel
						   $href,        # href
						   'input_of' # role
						   );
	    
	    if (!defined($link_elem)){
		$logger->logdie("Could not create an 'analysis' <Link> element object reference for <Feature> or <Sequence> with id '$accession'");
	    }

	    $link_elem_lookup->{$accession} = $link_elem;
	    
	}
	else {
	    $logger->logdie("element object was not defined for compseq '$accession'");
	}
    }


    my $alignment_pair_list = BSML::BsmlDoc::BsmlReturnAlignmentLookup( $uniquename, $accession );

    my $alignment_pair;

    if( $alignment_pair_list ){
	$alignment_pair = $alignment_pair_list->[0];
    }
    else {
	##
	## The <Seq-pair-alignment> element object was not previously instantiated.
	## Create one now.
	##
	$alignment_pair = $doc->returnBsmlSeqPairAlignmentR( $doc->addBsmlSeqPairAlignment() );
			
	if (!defined($alignment_pair)){
	    $logger->logdie("Could not create <Seq-pair-alignment> element object for refseq '$uniquename' compseq '$accession'");
	}
	else {
	    ##
	    ## Add the refseq, compseq and class attributes
	    ##
	    $alignment_pair->setattr( 'refseq',  $uniquename  );
	    $alignment_pair->setattr( 'compseq', $accession );
	    $alignment_pair->setattr( 'class',   'match' );

	    ##
	    ## Create a <Link> element object to link the <Seq-pair-alignment> to the <Analysis>
	    ##
	    my $link_elem = $doc->createAndAddLink(
						   $alignment_pair,   # <Seq-pair-alignment> element object reference
						   'analysis',        # rel
						   $href,             # href
						   'computed_by'      # role
						   );
	    
	    if (!defined($link_elem)){
		$logger->logdie("Could not create an 'analysis' <Link> element object reference for <Seq-pair-alignment>");
	    }
	}
    }

    return $alignment_pair;
}

#-------------------------------------------------------------------------------
# create_seq_pair_run()
#
#-------------------------------------------------------------------------------
sub create_seq_pair_run {

    my ($doc, $rel_end5, $rel_end3, $m_lend, $m_rend, $seq_pair_alignment_elem) = @_;

    my $seq_pair_run_elem = $seq_pair_alignment_elem->returnBsmlSeqPairRunR( $seq_pair_alignment_elem->addBsmlSeqPairRun() );

    if (!defined($seq_pair_run_elem)){
	$logger->logdie("Could not create a <Seq-pair-run> element object");
    }

    my $refcomplement;

    my $compcomplement;

    if ($rel_end5 < $rel_end3){
	$refcomplement=0;
    }
    else {
	$refcomplement=1;
	my $tmp = $rel_end5;
	$rel_end5 = $rel_end3;
	$rel_end3 = $tmp;
    }

    if ($m_lend < $m_rend){
	$compcomplement=0;
    }
    else {
	$compcomplement=1;
	my $tmp = $m_lend;
	$m_lend = $m_rend;
	$m_rend = $tmp;
    }

    my $runlength = abs($rel_end5 - $rel_end3);

    my $comprunlength = abs($m_lend - $m_rend);

    $seq_pair_run_elem->setattr( 'refpos', $rel_end5 );
    $seq_pair_run_elem->setattr( 'runlength', $runlength );
    $seq_pair_run_elem->setattr( 'comppos', $m_lend );
    $seq_pair_run_elem->setattr( 'comprunlength', $comprunlength );
    $seq_pair_run_elem->setattr( 'compcomplement', '0');
    $seq_pair_run_elem->setattr( 'refcomplement', '0' );



    my $classattr = $doc->createAndAddBsmlAttribute( $seq_pair_run_elem,
						     'class',
						     'match_part' );
    
    if (!defined($classattr)){
	$logger->logdie("Could not create <Attribute> for name 'class' content 'match_part'");
    }

}


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


    $outdir = $outdir . '/';

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


#-----------------------------------------------------------------
# print_usage()
#
#-----------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 [-B] -D database -P password -U username [--alt-database] [--att_type] [--chromosome] [-d debug_level] [--ev_type] [--family_id] [-h] [-l logfile] [-m] [-o outdir] [--schema_type] [--alt-species]\n".
    " -B|--backup             = Optional - to backup output .bsml and .fsa files\n".
    " -D|--database           = Source database name\n".
    " -P|--password           = login password for database\n".
    " -U|--username           = login username for database\n".
    " -a|--alt-database       = Optional - override default legacy annotation database name when creating unique identifiers\n".
    " -a|--alt-species        = Optional - override default species value\n".
    " --att_type              = Optional - ORF_attribute.att_type (Default is 'TEMPFAM2')\n".
    " --chromosome            = Optional - User can specify value for clone_info.chromo (Default - all chromosomes are considered)\n".
    " -d|--debug_level        = Optional - Coati::Logger logfile logging level (Default is WARN)\n".
    " --ev_type               = Optional - evidence.ev_type (Default is 'para2')\n".
    " --family_id             = Optional - identifier of particular paralogous family or simple ALL\n".
    " -h|--help               = This help message\n".
    " -l|--logfile            = Optional - Logfile output filename (Default is /tmp/legacyparafam2bsml.pl.database_\$database.asmbl_id_\$asmbl_id.log)\n".
    " -m|--man                = Display the pod2usage pages for this script\n".
    " -o|--outdir             = Optional - Output directory for all .bsml files (Default is current working directory)\n".
    " --schema_type           = TIGR legacy annotation database schema type e.g. euk, prok, or ntprok\n";

    exit (1);
}


#-------------------------------------------------------------------------------------------------
# Write bsml document to outdir
#
#-------------------------------------------------------------------------------------------------
sub write_out_bsml_doc {

    my ($outir, $doc) = @_;

    ## strip trailing forward slash
    $outdir =~ s/\/$//;
    
    my $bsmldocument = $outdir . '/' . $doc->{'doc_name'};


    #
    # If bsml document exists, copy it to .bak
    #
    if (-e $bsmldocument){

	#
	# editor:   sundaram@tigr.org
	# date:     2005-08-18
	# bgzcase:  2052
	# URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2052
	# comment:  Default behavior is to NOT backup files
	#
	if (defined($backup)){
	    my $bsmlbak = $bsmldocument . '.bak';
	    rename ($bsmldocument, $bsmlbak);
	    
	    chmod (0666, $bsmlbak);
	    
	    $logger->info("Saving '$bsmldocument' as '$bsmlbak'");
	}
    }




    print "Writing BSML document '$bsmldocument'\n" if $logger->is_debug;

    $logger->info("Writing BSML document '$bsmldocument'");
	
    $doc->write("$bsmldocument");

    	
	
    if(! -e "$bsmldocument"){
	$logger->error("File not created '$bsmldocument'");
    }

    print "Changing permissions on  BSML document '$bsmldocument'\n" if $logger->is_debug;

    chmod (0777, "$bsmldocument");

    print "Wrote paralogous family BSML document '$bsmldocument'\n";


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

sub cleanse_uniquename {

    my $uniquename = shift;

    # remove all open parentheses
    $uniquename =~ s/\(//g;
    
    # remove all close parentheses
    $uniquename =~ s/\)//g;


    return $uniquename;
}

    

		      
sub strip_surrounding_whitespace {
	
	my $var = shift;

	$$var =~ s/^\s*//;
	$$var =~ s/\s*$//;

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


#----------------------------------------------------
# store_organism_attribute()
#
#----------------------------------------------------
sub store_organism_attribute {

    my ($doc, $organism_elem, $orgdata, $species, $alt_species) = @_;

    foreach my $attribute ('abbreviation', 'gram_stain', 'genetic_code', 'mt_genetic_code'){
	
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

##----------------------------------------------------
## getIdMappingTiedLookup()
##
##----------------------------------------------------
sub getIdMappingTiedLookup {

    my ($id_mapping_directory, $database) = @_;

    ## get rid of all spaces
    $id_mapping_directory =~ s/\s*//g;

    my @idMappingDirectoryList = split(/,/, $id_mapping_directory);

    foreach my $idMappingDirectory ( @idMappingDirectoryList ){

	print "Scanning ID mapping directory '$idMappingDirectory'\n";

	if (defined($idMappingDirectory)){
	    if (!-e $idMappingDirectory){
		$logger->logdie("ID mapping directory '$idMappingDirectory' does not exist");
	    }
	    if (!-r $idMappingDirectory){
		$logger->logdie("ID mapping directory '$idMappingDirectory' does not have read permissions");
	    }
	}
	else {
	    return undef;
	}
	
	opendir(INDIR, "$idMappingDirectory") or $logger->logdie("Could not open ID mapping directory ".
								 "'$idMappingDirectory' in read mode");
	
	my @mappingFileList = grep {$_ ne '.' and $_ ne '..' and $_ =~ /^${database}_\S+\.idmap$/} readdir INDIR;
	
	my $mappingFileCtr=0;
	my $polypeptideIdentifierCtr=0;
	my $cdsIdentifierCtr=0;
	my $assemblyIdentifierCtr=0;

	foreach my $mappingFile (@mappingFileList ){

	    $mappingFileCtr++;

	    my $fullpath = $idMappingDirectory . '/' . $mappingFile;

	    open (INFILE, "<$fullpath") || $logger->logdie("Could not open ID mapping file '$fullpath' in read mode: $!");

	    my $mappingFileLineCtr=0;
	    my $instancePolypeptideIdentifierCtr=0;
	    my $instanceCdsIdentifierCtr=0;
	    my $instanceAssemblyIdentifierCtr=0;

	    while (my $line = <INFILE>){

		chomp $line;

		$mappingFileLineCtr++;

		my ($oldid, $newid) = split(/\t/, $line);

		if ($newid =~ /polypeptide/) {
		    $instancePolypeptideIdentifierCtr++;
		    if (exists $idMappingLookup->{$oldid}){
			if ($idMappingLookup->{$oldid} ne $newid){
			    $logger->logdie("Found conflicting values '$idMappingLookup->{$oldid}' ".
					    "and '$newid' for oldid '$oldid'. ".
					    "Please check the ID mapping files in: $id_mapping_directory");
			}
		    }
		    else {
			$idMappingLookup->{$oldid} = $newid;
		    }

		}
		elsif ( $newid =~ /CDS/) {
		    $instanceCdsIdentifierCtr++;
		    if (exists $idMappingLookup->{$oldid}){
			if ($idMappingLookup->{$oldid} ne $newid){
			    $logger->logdie("Found conflicting values '$idMappingLookup->{$oldid}' ".
					    "and '$newid' for oldid '$oldid'. ".
					    "Please check the ID mapping files in: $id_mapping_directory");
			}
		    }
		    else {
			$idMappingLookup->{$oldid} = $newid;
		    }
		}
		elsif ( $newid =~ /assembly/ ) {
		    $instanceAssemblyIdentifierCtr++;
		    if (exists $idMappingLookup->{$oldid}){
			if ($idMappingLookup->{$oldid} ne $newid){
			    $logger->logdie("Found conflicting values '$idMappingLookup->{$oldid}' ".
					    "and '$newid' for oldid '$oldid'. ".
					    "Please check the ID mapping files in: $id_mapping_directory");
			}
		    }
		    else {
			$idMappingLookup->{$oldid} = $newid;
		    }
		}
	    }

	    $polypeptideIdentifierCtr += $instancePolypeptideIdentifierCtr;
	    $cdsIdentifierCtr += $instanceCdsIdentifierCtr;
	    $assemblyIdentifierCtr += $instanceAssemblyIdentifierCtr;


	    if ($logger->is_debug()){
		$logger->debug("Processed '$mappingFileLineCtr' lines in ID mapping file '$fullpath' ".
			       "and found '$instancePolypeptideIdentifierCtr' polypeptide identifiers, ".
			       "'$instanceCdsIdentifierCtr' CDS identifiers and ".
			       "'$instanceAssemblyIdentifierCtr' assembly identifier(s)");
	    }
	}

	if ($logger->is_debug()){
	    $logger->debug("Processed '$mappingFileCtr' ID mapping files found in directory '$idMappingDirectory' ".
			   "with a total of '$polypeptideIdentifierCtr' polypeptide identifiers, ".
			   "'$cdsIdentifierCtr' CDS identifiers and ".
			   "'$assemblyIdentifierCtr' assembly identifier(s)");
	}


    }

}

##--------------------------------------------------------------
## getIdFromIdGenerator()
##
##--------------------------------------------------------------
sub getIdFromIdGenerator {

    my ($database, $id, $type) = @_;


    if ( exists $idMappingLookup->{$id}) {
	return $idMappingLookup->{$id};
    }
    else {
	my $returnid = $idGenerator->next_id( project => $database,
					      type    => $type,
					      version => $idgen_identifier_version);
	

	$idMappingLookup->{$id} = $returnid;
	
	## store only new ID mappings in this lookup so that
	## we can create an ID mapping file that only contains
	## newly generated mappings
	$newIdMappingLookup->{$id} = $returnid;

	return $returnid;
    }
}

##--------------------------------------------------------------
## writeNewIdMappingFile()
##
##--------------------------------------------------------------
sub writeNewIdMappingFile {

    my ($output_mapping_file, $newIdMappingLookup, $outdir) = @_;


    if (!defined($output_mapping_file)){
	$output_mapping_file = $outdir . '/legacyparafam2bsml.pl.idmap';
	$logger->warn("output_mapping_file was not defined and so was set to '$output_mapping_file'");
    }

    open (OUTFILE,  ">$output_mapping_file") || $logger->logdie("Could not open output ID mapping file '$output_mapping_file: $!");

    print "Writing all ID mappings to '$output_mapping_file'\n";

    foreach my $oldid ( keys %{$newIdMappingLookup}){

	print OUTFILE "$oldid\t$newIdMappingLookup->{$oldid}\n";
    }
}
