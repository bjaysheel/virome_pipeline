#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
=head1 NAME

ntproklink2bsml.pl - Generates BSML document containing <Feature-group> elements linking ORF and NTORF data

=head1 SYNOPSIS

USAGE:  ntproklink2bsml.pl -U username -P password -D database [-l log4perl] [-a asmbl_id] [-d debug_level] [-h] [-m] [-o outdir]

=head1 OPTIONS

=over 8

=item B<--username,-U>

Database username

=item B<--password,-P>

Database password

=item B<--database,-D>

Source legacy organism database name

=item B<--asmbl_id,-a>

User must specify the appropriate assembly.asmbl_id value

=item B<--help,-h>

Print this help

=item B<--man,-m>

Display pod2usage man pages for this script

=item B<--log4perl,-l>

Optional - Log4perl log file.  Default is /tmp/ntproklink2bsml.pl.log

=item B<--outdir,-o>

Optional - Output directory for bsml document.  Default is current working directory.

=back

=head1 DESCRIPTION

ntproklink2bsml.pl - Generates BSML document containing <Feature-group> elements linking ORF and NTORF data

=head1 CONTACT

Jay Sundaram (sundaram@tigr.org)

=cut

use strict;
use lib "shared";
use lib "Chado";
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

my ($include_genefinder, $exclude_genefinder, $map, $mode, $backup, $dtd, $schema, $seqtype, $ontology);

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------
my ($database, $username, $password, $debug_level, $help, $man, $log4perl, $asmbl_id, $outdir);

my $results = GetOptions (
			  'username|U=s'       => \$username, 
			  'password|P=s'       => \$password,
			  'database|D=s'       => \$database,
			  'asmbl_id|a=s'       => \$asmbl_id,
			  'debug_level|d=s'    => \$debug_level,
			  'help|h'             => \$help,
			  'man|m'              => \$man,
			  'log4perl|l=s'       => \$log4perl,
			  'outdir|o=s'         => \$outdir
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("username was not defined\n")        if (!$username);
print STDERR ("password was not defined\n")        if (!$password);
print STDERR ("database was not defined\n")        if (!$database);
print STDERR ("asmbl_id was not defined\n")        if (!$asmbl_id);

&print_usage if(!$username or !$password or !$database or !$asmbl_id);

#
# Get the logger
#
my $logger = &get_logger($log4perl, $debug_level, $database, $asmbl_id);

#
# verify and set the output directory
#
$outdir = &verify_and_set_outdir($outdir);

#
# Instantiate new Prism reader object
#
my $prism = &retrieve_prism_object($username, $password, $database);


#
# retrieve sybase time stamp
#
my $sybase_time = $prism->get_sybase_datetime();

#
# Retrieve the organism related data from common..genomes and new_project
#
my $orgdata= &retrieve_organism_data(
				     prism      => $prism,
				     database   => $database,
				     );


my $doc = new BSML::BsmlBuilder();
$doc->{'doc_name'} = $database . '_' .$asmbl_id . '_feat_link.bsml';
$doc->{'xrefctr'}++;


my $genome_id = &create_genome_component($doc, $orgdata);

my $assembly = $prism->all_assembly_records_by_asmbl_id($asmbl_id);

my ($assembly_sequence_elem, $feature_table_elem) = &create_assembly_sequence_component($assembly, $doc, $database, $asmbl_id, 'assembly', $genome_id);

my $feat_link_lookup = $prism->orf_ntorf_feat_link($asmbl_id);

&store_orf_ntorf_relationships($doc, $feat_link_lookup, $database, $asmbl_id, $feature_table_elem, $assembly_sequence_elem);

&write_out_bsml_doc($outdir, $doc);


print "All .bsml files were written to '$outdir'\n".
"Please verify log4perl log file: $log4perl\n";


#------------------------------------------------------------------------------------------------------------------------------------
#
#                END OF MAIN SECTION -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------------------------------



#------------------------------------------------
# store_orf_ntorf_relationships()
#
#------------------------------------------------
sub store_orf_ntorf_relationships {

    my ($doc, $feat_link_lookup, $database, $asmbl_id, $feature_table_elem, $assembly_sequence_elem) = @_;

    my $class = 'transcript';

    foreach my $ntorf (sort keys %{$feat_link_lookup} ) {

	my $orf = $feat_link_lookup->{$ntorf};

	my $ntorf_uniquename = $database . "_" . $asmbl_id . "_" . $ntorf . "_$class";


	

	#
	# Create <Feature> element for the NTORF
	#
	my $ntorf_feature_elem = $doc->createAndAddFeature( $feature_table_elem,  # <Feature-table> element object reference
							    $ntorf_uniquename,    # id
							    undef,                # title
							    $class,               # class
							    undef,                # comment
							    undef                 # displayAuto
							    );
	if (!defined($ntorf_feature_elem)){
	    $logger->logdie("Could not create <Feature> element object reference for NTORF uniquename '$ntorf_uniquename'"); 
	}
	



	my $orf_uniquename = $database . "_" . $asmbl_id . "_" . $orf . "_$class";

	#
	# Create <Feature> element for the ORF
	#
	my $ntorf_feature_elem = $doc->createAndAddFeature( $feature_table_elem,  # <Feature-table> element object reference
							    $ntorf_uniquename,    # id
							    undef,                # title
							    $class,               # class
							    undef,                # comment
							    undef                 # displayAuto
							    );
	if (!defined($ntorf_feature_elem)){
	    $logger->logdie("Could not create <Feature> element object reference for NTORF uniquename '$ntorf_uniquename'"); 
	}
	




	#
	# Create <Feature-group> element identified by the NTORF uniquename
	#
	my $feature_group_elem = $doc->createAndAddFeatureGroup(
								$assembly_sequence_elem,  # <Sequence> element object reference
								undef,                    # id
								"$ntorf_uniquename"       # groupset
								);  
	
	if (!defined($feature_group_elem)){
	    $logger->logdie("Could not create <Feature-group> element object reference for NTORF '$ntorf_uniquename'");
	}



	#
	# Create a <Feature-group-member> element for the NTORF
	#
	my $ntorf_feature_group_member_elem = $doc->createAndAddFeatureGroupMember(
									   $feature_group_elem,  # <Feature-group> element object reference
									   $ntorf_uniquename,    # featref
									   'NTORF',               # feattype
									   undef,                # grouptype
									   undef,                # cdata
									   ); 
	if (!defined($ntorf_feature_group_member_elem)){
	    $logger->logdie("Could not create <Feature-group-member> element object reference for NTORF '$ntorf_uniquename'");
	}



	#
	# Create a <Feature-group-member> element for the ORF
	#
	my $orf_feature_group_member_elem = $doc->createAndAddFeatureGroupMember(
										 $feature_group_elem,  # <Feature-group> element object reference
										 $orf_uniquename,      # featref
										 'ORF',               # feattype
										 undef,                # grouptype
										 undef,                # cdata
										 ); 
	if (!defined($orf_feature_group_member_elem)){
	    $logger->logdie("Could not create <Feature-group-member> element object reference for ORF '$orf_uniquename'");
	}
	


    }	



}


sub store_organism_attributes {

    my ($doc, $organism_elem, $orgdata) = @_;

    foreach my $attribute ('abbreviation', 'gram_stain', 'genetic_code', 'mt_genetic_code'){
	
	if ((exists $orgdata->{$attribute}) && (defined($orgdata->{$attribute}))){

	    my $attribute_elem = $doc->createAndAddBsmlAttribute( $organism_elem,
								  $attribute,
								  $orgdata->{$attribute} );
	    
	    if (!defined($attribute_elem)){
		$logger->logdie("Could not create <Attribute> for the name '$attribute' content '$orgdata->{$attribute}'");
	    }
	}
    }
}   



#------------------------------------------------
# create_assembly_sequence_component()
#
#------------------------------------------------
sub create_assembly_sequence_component {

    my ($assembly, $doc, $database, $asmbl_id, $class, $genome_id) = @_;

    #
    # Create the assembly uniquename
    #
    my $asmbl_uniquename = $database . "_" . $asmbl_id . "_assembly";
    
    
    $asmbl_uniquename = &cleanse_uniquename($asmbl_uniquename);
    
    my $sequence = $assembly->{$asmbl_id}->{'sequence'};

    my $asmlen = length($sequence);

    my $topology = $assembly->{$asmbl_id}->{'topology'};


    #
    # Create the assembly <Sequence> element
    #
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


    #
    # Link the assembly the to correct <Genome> component
    #
    my $link_elem = $doc->createAndAddLink(
					   $assembly_sequence_elem,
					   'genome',        # rel
					   "#$genome_id"    # href
					   );
    
    if (!defined($link_elem)){
	$logger->logdie("Could not create a 'genome' <Link> element object reference for assembly sequence '$asmbl_uniquename' genome_id '$genome_id'");
    }
    

    #
    # Create a <Feature-table> element under which the ORF and NTORF features will be stored.
    #
    my $feature_table_elem = $doc->createAndAddFeatureTable($assembly_sequence_elem);
	    
    if (!defined($feature_table_elem)){
	$logger->logdie("Could not create <Feature-table> element object reference");
    }




    return ($assembly_sequence_elem, $feature_table_elem);


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
    my $ntprok     = $args{'ntprok'};
    my $euk        = $args{'euk'};

    
    my $orgtype;
    if ($euk == 1){
	$orgtype = 'euk';
    }

    #
    # Retrieve the organism data via the Prism API method
    # in (shared/Prism.pm)
    #
    my $orgdata = $prism->organism_data($database, $orgtype);


    $logger->debug("organism data hashref:" . Dumper $orgdata) if $logger->is_debug;


    #
    # Determine and assign the correct database prefix
    #
    if ($orgdata->{'type'}  eq 'microbial'){

	$orgdata->{'prefix'} = 'TIGR_prok:' . $database;

    }
    elsif ($orgdata->{'type'}  eq 'nt-microbial'){

	$orgdata->{'prefix'} = 'TIGR_ntprok:' . $database;

    }
    elsif ((defined($ntprok)) && ($ntprok == 1)){

	$orgdata->{'prefix'} = 'TIGR_ntprok:' . $database;

    }
    elsif ((defined($euk)) && ($euk == 1)){

	$orgdata->{'prefix'} = 'TIGR_euk:' . $database;

    }
    else {

	$orgdata->{'prefix'} = 'TIGR_prok:' . $database;
    }
    
    #
    # Return the constructed data hash
    #


    return $orgdata;


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


#----------------------------------------------------------------
# retrieve_prism_object()
#
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database) = @_;

    $logger->debug("Instantiating Prism object") if ($logger->is_debug());
    
    my $prism = new Prism(
			  user              => $username,
			  password          => $password,
			  db                => $database
			  );
    
    $logger->logdie("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    

    return $prism;


}#end sub retrieve_prism_object()


#-----------------------------------------------------------------
# print_usage()
#
#-----------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -D database -P password -U username -a asmbl_id [-d debug_level] [-h] [-l log4perl] [-m] [-o outdir]\n".
    " -D|--database           = Source database name\n".
    " -P|--password           = login password for database\n".
    " -U|--username           = login username for database\n".
    " -a|--asmbl_id           = assembly identifier (assembly.asmbl_id)\n".
    " -d|--debug_level        = Optional - Coati::Logger log4perl logging level (Default is WARN)\n".
    " -h|--help               = This help message\n".
    " -l|--log4perl           = Optional - Log4perl output filename (Default is /tmp/legacy2bsml.pl.database_\$database.asmbl_id_\$asmbl_id.log)\n".
    " -m|--man                = Display the pod2usage pages for this script\n".
    " -o|--outdir             = Optional - Output directory for all .bsml files (Default is current working directory)\n";
    exit 1;

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
    
    my $doc = shift;
    my $orgdata = shift;


    my ($genus, $species, @straint) = split(/\s+/,$orgdata->{'name'});
    

    foreach my $st (@straint){
	$species = $species . ' ' . $st if (defined($st));
    }

    my $identifier = lc(substr($genus,0,1)) . '_' . lc($species);
    
    
    my $genome_elem = $doc->createAndAddGenome();

    $logger->logdie("Could not create <Genome> element object reference") if (!defined($genome_elem));
    
    my $xref_elem = $doc->createAndAddCrossReference(
						     'parent'          => $genome_elem,
						     'id'              => $doc->{'xrefctr'}++,
						     'database'        => $orgdata->{'prefix'},
						     'identifier'      => $identifier,
						     'identifier-type' => 'current'
						     );


    $logger->logdie("Could not create <Cross-reference> element object reference") if (!defined($xref_elem));
    

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
	&store_organism_attributes($doc, $organism_elem, $orgdata);
    }


    #
    # editor:    sundaram@tigr.org
    # date:      2005-08-17
    # bgzcase:   2051
    # URL:       http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2051
    # comment:   The <Sequence> will now be explicitly linked with the <Genome>
    #
    if (( exists $genome_elem->{'attr'}->{'id'} ) && ( defined ( $genome_elem->{'attr'}->{'id'} ) )  ){
	return $genome_elem->{'attr'}->{'id'};
    }
    else {
	$logger->logdie("Genome id was not defined!");
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



    $logger->debug("Processing assembly '$asmbl_id' feat_name '$orfhash->{'feat_name'}'...") if $logger->is_debug;

   
    my $gene_feature_group_elem;


    foreach my $class ('gene', 'transcript', 'CDS', 'exon', 'polypeptide'){


	#
	# Whether locus or feat_name (prepared for us upstream), create uniquename
	#
	my $uniquename = $database . '_' .$asmbl_id . '_' . $orfhash->{'feat_name'} . '_' . $class;


	#---------------------------------------------------------------------------------------------------------------------------------------------
	#
	# editor:   sundaram@tigr.org
	# date:     2005-08-15
	# bgzcase:  2044 
	# URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2044
	# comment:  The legacy2bsml.pl script should ensure that the //Feature/@id == //Seq-data-import/@identifier for all sequences/features
	#    
	$identifier_feature->{$uniquename}++;
	#
	#
	#---------------------------------------------------------------------------------------------------------------------------------------------
	



	#
	# Uncomment the following section if you still wish the default behavior to be to incorporate locus into the uniquename
	# if the locus is defined.
	#


# 	if (defined($orfhash->{'locus'})){
# 	    $uniquename = $database . '_' .$asmbl_id . '_' . $orfhash->{'locus'} . '_' . $class;
# 	}


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
	my $feature_elem = $doc->createAndAddFeature ( $
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
	    #
	    # Store reference using the feat_name not the locus
	    #
	    my $uniquename = $database . '_' .$asmbl_id . '_' . $orfhash->{'feat_name'} . '_' . $class;
	    $transcript_feature_hash->{$uniquename} = $feature_elem;
	}
	if ($class eq 'polypeptide') {
	    #
	    # Store reference using the feat_name not the locus
	    #

	    $polypeptide_feat_name_to_locus->{$orfhash->{'feat_name'}} = $uniquename;
	    
	    my $uniquename1 = $database . '_' .$asmbl_id . '_' . $orfhash->{'feat_name'} . '_' . $class;
	    $polypeptide_feature_hash->{$uniquename1} = $feature_elem;

	    
	    #-------------------------------------------------------------------------------------------------------------------
	    # editor:   sundaram@tigr.org
	    # date:     Thu Nov  3 11:19:40 EST 2005
	    # bgzcase:  2266
	    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2266
	    # comment:  The legacy2bsml.pl migration script should now retrieve the protein secondary
	    #           structure data from asm_feature.sec_struct where feat_type = 'ORF'.
	    #
	    if (( exists $orfhash->{'sec_struct'}) && (defined($orfhash->{'sec_struct'}))) {

		my $attribute_elem = $doc->createAndAddBsmlAttribute(
								     $feature_elem,
								     'sequence_secondary_structure',
								     "$orfhash->{'sec_struct'}"
								     );
		
		$logger->logdie("Could not create <Attribute> for the name 'sequence_secondary_structure' content '$orfhash->{'sec_struct'}'") if (!defined($attribute_elem));
	    }
	    #
	    #-------------------------------------------------------------------------------------------------------------------




	}

	#-------------------------------------------------------------------------------------------------------------
	# editor:   sundaram@tigr.org
	# date:     Wed Nov  2 15:55:25 EST 2005
	# bgzcase:  2263
	# URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2263
	# comment:  Store the <Feature> element object reference for CDS so that we can later associate all
	#           model GC ORF_attributes to the CDS features.
	#
	if ($class eq 'CDS'){
	    #
	    # Store reference using the feat_name not the locus
	    #
	    my $uniquename = $database . '_' .$asmbl_id . '_' . $orfhash->{'feat_name'} . '_' . $class;
	    $cds_feature_hash->{$uniquename} = $feature_elem;
	}
	#
	#-------------------------------------------------------------------------------------------------------------


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
		
		$logger->debug("$locustype was defined therefore attempting to insert <Cross-reference> element object for '$uniquename' $locustype '$orfhash->{$locustype}'") if $logger->is_debug;
		
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






	if (($class eq 'polypeptide') or ($class eq 'CDS')){

	    #
	    # Create <Link> to link polypeptide or CDS <Feature> element to the polypeptide_seq or CDS_seq <Sequence> element
	    #
	    my $sequence_key = $database . '_' .$asmbl_id . '_' . $orfhash->{'feat_name'} . '_' . $class . '_seq';
	    
	    $logger->debug("Attempting to insert <Link> to <Seq-data-import> for '$sequence_key'") if $logger->is_debug;


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
		    $logger->logdie("<Seq-data-import> does not exist for sequence '$sequence_key'");
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







#----------------------------------------------------------------------------------------
# load_map()
#
# The map hashref contains necessary rules such as:
# 1) feature/sequence suffix strings
# 2) feature/sequence class names/strings
#
#----------------------------------------------------------------------------------------
sub load_map {

    my $map = {
	'assembly' => {
	    'suffix'  => '_assembly',
	    'class'   => 'assembly',
	    'moltype' => 'dna'
	},
	    'polypeptide_seq' => {
		'suffix' => '_polypeptide_seq',
		'class' => 'polypeptide',
		'moltype' => 'aa'
	    },
		'CDS_seq' => {
		    'suffix' => '_CDS_seq',
		    'class'  => 'CDS',
		    'moltype' => 'dna'
		},
		    'tRNA' => {
			'suffix' => '_tRNA_seq',
			'class'  => 'tRNA',
			'moltype' => 'dna'
		    },
			'rRNA' => {
			    'suffix' => '_rRNA_seq',
			    'class' => 'rRNA',
			    'moltype' => 'dna'
			},
			    'snRNA' => {
				'suffix' => '_snRNA_seq',
				'class' => 'snRNA',
				'moltype' => 'dna'
			    },
				'ncRNA' => {
				    'suffix' => '_ncRNA_seq',
				    'class' => 'ncRNA',
				    'moltype' => 'dna'
				},
				    'TERM' => {
					'suffix' => '_terminator_seq',
					'class' => 'terminator',
					'moltype' => 'dna'
				    },
					'RBS' => {
					    'suffix' => '_ribosome_entry_site_seq',
					    'class' => 'ribosome_entry_site',
					    'moltype' => 'dna'
					},
					    'gene' => {
						'suffix' => '_gene',
						'class' => 'gene'
					    },
						'transcript' => {
						    'suffix' => '_transcript',
						    'class' => 'transcript'
						},
						    'CDS' => {
							'suffix' => '_CDS',
							'class' => 'CDS'
						    },
							'polypeptide_feature' => {
							    'suffix' => '_polypeptide',
							    'class' => 'polypeptide'
							},
							    'exon' => {
								'suffix' => '_exon',
								'class'  => 'exon'
							    },
								'tRNA_feature' => {
								    'suffix' => '_tRNA',
								    'class'  => 'tRNA'
								},
								    'rRNA_feature' => {
									'suffix' => '_rRNA',
									'class'  => 'rRNA'
								    },
									'snRNA_feature' => {
									    'suffix' => '_snRNA',
									    'class'  => 'snRNA'
									},
									    'ncRNA_feature' => {
										'suffix' => '_ncRNA',
										'class'  => 'ncRNA'
									    },
										'signal_peptide' => {
										    'suffix' => '_signal_peptide',
										    'class'  => 'signal_peptide'
										},
										    'ribosome_entry_site' => {
											'suffix' => '_ribosome_entry_site',
											'class'  => 'ribosome_entry_site'
										    },
											'terminator' => {
											    'suffix' => '_terminator',
											    'class'  => 'terminator'
											}
    };
    
    return $map;
}



#-------------------------------------------------------------------------------------------------
# Write bsml document to outdir
#
#-------------------------------------------------------------------------------------------------
sub write_out_bsml_doc {

    my ($outdir, $doc) = @_;



    my $bsmldocument = $outdir . '/' . $doc->{'doc_name'};


    #
    # If bsml document exists, copy it to .bak
    #
    if (-e $bsmldocument){

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
# get_logger()
#
#----------------------------------------------------------
sub get_logger {

    my ($log4perl, $debug_level, $database, $asmbl_id) = @_;

    #
    # initialize the logger
    #
    if (!defined($log4perl)){
	
	$log4perl = "/tmp/legacy2bsml.pl.$database.$asmbl_id.log";
	print STDERR "log4perl was not defined, therefore set to '$log4perl'\n";
	
    }
    
    my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				     'LOG_LEVEL'=>$debug_level);
    return Coati::Logger::get_logger(__PACKAGE__);
}





sub junk {


    my ($asmbl_id, $fastadir, $outdir, $euk, $prok, $ntprok, $include_genefinders, $exclude_genefinders, $username, $password, $help, $log4perl, $debug_level);
#
# Mapping of sequence and feature types to suffix and class values
#
my $map = &load_map();

#
my $identifier_feature = {};
my $identifier_seq_data = {};


#
# legacy2bsml.pl only processes one asmbl_id at a time
# This is temporary hack to ensure that code remains compatible.
#
my $asmbl_list = [];
push ( @{$asmbl_list}, $asmbl_id );
foreach my $assembly_id ( sort  @{$asmbl_list} ) {

    $logger->debug("Processing assembly_id '$assembly_id'") if $logger->is_debug();
    
    #
    # Global lookups for BSML document linking
    #
    my $sequence_hash = {};
    my $transcript_feature_hash = {};
    my $polypeptide_feature_hash = {};
    my $seq_data_import_hash = {};
    my $seq_data_import_ctr=0;
    my $analysis_hash = {};

    my $fastasequences = {};
    my $polypeptide_feat_name_to_locus = {};
    my $gene_group_lookup = {};
    
    
    my $accession_hash = {};
    
    #
    # editor:  sundaram@tigr.org
    # date:    2005-09-12
    # bgzcase: 2081
    # URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2108
    # comment: Lookup for storing the mappings of new isoform transcript uniquename to the original transcript uniquename
    #
    my $transcript_mapper = {};


    #
    # editor:  sundaram@tigr.org
    # date:    2005-09-12
    # bgzcase: 2120
    # URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2120
    # comment: Gene finder data will be retrieved separately from the gene model data
    #
    my $gene_finder_hash = {};

    #
    # Retrieve the assembly related data from assembly, clone_info or stan, and asmbl_data
    #
    my ($assembly) = $prism->all_assembly_records_by_asmbl_id($assembly_id);


    my $sequences_hashes = {};
    my $gene_model_hash = {};
    my $model_feat_names = {};
    my $rna_hash = {};
    my $peptide_hash = {};
    my $ribosome_hash = {};
    my $terminator_hash = {};
    my $ident_attributes_hash = {};
    my $tigr_roles_hash = {};
    my $go_roles_hash = {};

    my $ber_evidence_hash = {};
    my $hmm2_evidence_hash = {};
    my $cog_evidence_hash = {};
    my $prosite_evidence_hash = {};
    my $ident_xref_attr_hash = {};





    #-----------------------------------------------------------------------------------------------------
    # editor:   sundaram@tigr.org
    # date:     Tue Nov  1 16:37:43 EST 2005
    # bgzcase:  2141
    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2141
    # comment:  The models' ORF_attributes MW and pI shall be associated with the corresponding
    #           polypeptides in BSML and chado
    #    
    my $euk_polypeptide_orf_attributes_hash = {};
    #
    #-----------------------------------------------------------------------------------------------------


    my $euk_cds_orf_attributes_hash = {};

    #-----------------------------------------------------------------------------------------------------
    # editor:   sundaram@tigr.org
    # date:     Wed Nov  2 13:19:26 EST 2005
    # bgzcase:  2263
    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2263
    # comment:  The ORFs' ORF_attributes: MW, PI, LP, OMP will be associated with the polypeptide
    #           Feature in BSML and chado.
    #           The ORFs' ORF_attribute: GC will be associated with the CDS Feature in BSML and chado.
    #
    my $prok_polypeptide_orf_attributes_hash = {};

    my $cds_feature_hash = {};

    my $prok_cds_orf_attributes_hash  = {};

    #
    #-----------------------------------------------------------------------------------------------------

    my $t2g_lookup;   # terminator to gene lookup
    my $r2g_lookup;   # ribosome_binding_site to gene lookup





    if ( ( $mode == 1 )  or  ( $mode == 2 ) ){

	#
	# Mode 1: Write BSML encodings ONLY for all of the following:
	#         Sequence, Gene Model, RNA Features, Other Features, Gene Annotation Attributes. TIGR Roles, GO, ORF Attributes
	#
	# Mode 2: Write BSML encodings for all of the above + BER, AUTO-BER and HMM2 evidence
	#

	
	if ((defined($euk)) && ($euk == 1)){
	    #
	    # The section handles particular eukaryotic BSML encoding
	    #


	    ($gene_model_hash, $model_feat_names) = &create_euk_gene_model_lookup($prism, $assembly_id, $database);


	    #---------------------------------------------------------------------------------------------------------------
	    # editor:  sundaram@tigr.org
	    # date:    2005-09-14
	    # bgzcase:
	    # URL:
	    # comment: Retrieval of gene finder data will be handled separate from the retrieval of standard gene model data
	    #
	    #
	    # editor:   sundaram@tigr.org
	    # date:     2005-09-15
	    # bgzcase:  2123
	    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2123
	    # comment:  User may specify which gene finder data types to include/exclude from the migration
	    #
 
	    print "in $include_genefinder ex $exclude_genefinder\n";

	    if (($include_genefinder ne 'none') or ($exclude_genefinder ne 'all')) {
		($gene_finder_hash) = &create_gene_finder_lookup($prism, $assembly_id, $database, undef, $exclude_genefinder, $include_genefinder);
	    }
	    else {
		$logger->info("User '$username' has specified that none of the gene finder datatypes should be included in the migration") if ($include_genefinder eq 'none');
		$logger->info("User '$username' has specified that all of the gene finder datatypes should or excluded from the migration") if ($exclude_genefinder eq 'all');
	    }
	    #
	    #
	    #---------------------------------------------------------------------------------------------------------------


	    $sequences_hashes     = &create_euk_sequence_lookup($prism, $assembly_id, $database, $model_feat_names);

	    $ident_xref_attr_hash = &create_ident_xref_attr_lookup($prism, $assembly_id, $database);

	    #---------------------------------------------------------------------------------------------------------------------------
	    # editor:   sundaram@tigr.org
	    # date:     Tue Nov  1 16:37:43 EST 2005
	    # bgzcase:  2141
	    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2141
	    # comment:  The models' ORF_attributes MW and pI shall be associated with the corresponding
	    #           polypeptides in BSML and chado
	    #
	    $euk_polypeptide_orf_attributes_hash = &create_euk_polypeptide_orf_attributes_lookup($prism, $assembly_id, $database);
	    #
	    #---------------------------------------------------------------------------------------------------------------------------



	    #---------------------------------------------------------------------------------------------------------------------------
	    # editor:   sundaram@tigr.org
	    # date:     Tue Nov 22 16:10:14 EST 2005
	    # bgzcase:  2292
	    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2292
	    # comment:  The models' ORF_attributes score and score2 where att_type = 'is_partial' shall be associated with the
		#           corresponding CDS features in BSML and chado
	    #
	    $euk_cds_orf_attributes_hash = &create_euk_cds_orf_attributes_lookup($prism, $assembly_id, $database);
	    #
	    #---------------------------------------------------------------------------------------------------------------------------



	}
	else{
	    #
	    # This section handles particular prokaryotic BSML encoding
	    #
	    $sequences_hashes  = &create_prok_sequence_lookup($prism, $assembly_id, $database, $ntprok);

	    $gene_model_hash   = &create_prok_gene_model_lookup($prism, $assembly_id, $database, $ntprok);


	    #---------------------------------------------------------------------------------------------------------------------------
	    # editor:   sundaram@tigr.org
	    # date:     Wed Nov  2 13:19:26 EST 2005
	    # bgzcase:  2263
	    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2263
	    # comment: 
	    $prok_polypeptide_orf_attributes_hash   = &create_prok_polypeptide_orf_attributes_lookup($prism, $assembly_id, $database, $ntprok);

	    $prok_cds_orf_attributes_hash   = &create_prok_cds_orf_attributes_lookup($prism, $assembly_id, $database, $ntprok);
	    #
	    #---------------------------------------------------------------------------------------------------------------------------
	}

	

	$accession_hash        = &create_accession_lookup($prism, $assembly_id, $database, $ntprok);
	$rna_hash              = &create_rna_lookup($prism, $assembly_id, $database, $ntprok);
	$peptide_hash          = &create_peptide_lookup($prism, $assembly_id, $database, $ntprok);
	$ribosome_hash         = &create_ribosome_lookup($prism, $assembly_id, $database, $ntprok);
	$terminator_hash       = &create_terminator_lookup($prism, $assembly_id, $database, $ntprok);
	$ident_attributes_hash = &create_ident_attributes_lookup($prism, $assembly_id, $database, $ntprok);
	$tigr_roles_hash       = &create_tigr_roles_lookup($prism, $assembly_id, $database, $ntprok);
	$go_roles_hash         = &create_go_roles_lookup($prism, $assembly_id, $database, $ntprok, $euk);

	$t2g_lookup            = &create_terminator_to_gene_lookup($prism, $assembly_id, $database, $ntprok);
	$r2g_lookup            = &create_rbs_to_gene_lookup($prism, $assembly_id, $database, $ntprok);


    }
    if ( ($mode == 2) or ($mode == 3) ){


	#
	# Mode 2: Write BSML encodings for all of the following:
	#         Sequence, Gene Model, RNA Features, Other Features, Gene Annotation Attributes. TIGR Roles, GO, ORF Attributes
	#
	# Mode 3: Write BSML encodings ONLY for BER, AUTO-BER and HMM2 evidence
	#

	$ber_evidence_hash      = &create_ber_evidence_lookup($prism, $assembly_id, $database, $orgdata->{'prefix'}, $ntprok);

	if (( defined($euk)) && ($euk == 1)) {
	    $hmm2_evidence_hash = &create_euk_hmm2_evidence_lookup($prism, $assembly_id, $database, $orgdata->{'prefix'});
	}
	else {
	    $hmm2_evidence_hash = &create_hmm2_evidence_lookup($prism, $assembly_id, $database, $orgdata->{'prefix'}, $ntprok);
	}

	$cog_evidence_hash      = &create_cog_evidence_lookup($prism, $assembly_id, $database, $orgdata->{'prefix'}, $ntprok);
	$prosite_evidence_hash  = &create_prosite_evidence_lookup($prism, $assembly_id, $database, $orgdata->{'prefix'}, $ntprok);

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
    $doc->{'doc_name'} = $database . '_' .$asmbl_id . '_assembly.bsml';
    $doc->{'xrefctr'}++;
    
    #
    # editor:    sundaram@tigr.org
    # date:      2005-08-17
    # bgzcase:   2051
    # URL:       http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2051
    # comment:   The <Sequence> will now be explicitly linked with the <Genome>, thus genome id be returned 
    #	     and propagated throughout the code
    #
    my $genome_id = &create_genome_component(
					     $doc,
					     $orgdata
					     );


    if (($mode == 1) or ($mode == 2)) {


	# mode 1: gene model only
	# mode 2: gene model + computational evidence
	# mode 3: computational evidence only 



	my $asmbl_uniquename = $database . "_" . $asmbl_id . "_assembly";


	$asmbl_uniquename = &cleanse_uniquename($asmbl_uniquename);

	my $sequence = $assembly->{$asmbl_id}->{'sequence'};
	my $asmlen = length($sequence);


	$logger->debug("Storing assembly '$asmbl_uniquename' sequence in multi-fasta hash") if $logger->is_debug;
	

	my $array = [$asmbl_uniquename, $assembly->{$asmbl_id}->{'sequence'}];
 	push ( @{$fastasequences->{$asmbl_id}->{'assembly'}}, $array);
	

	my ($assembly_sequence_elem) = &create_assembly_sequence_component(
									   'asmbl_id'         => $asmbl_id,
									   'uniquename'       => $asmbl_uniquename,
									   'length'           => $asmlen,
									   'topology'         => $assembly->{$asmbl_id}->{'topology'},
									   'doc'              => $doc,
									   'class'            => 'assembly',
									   'fastadir'         => $fastadir,
									   'database'         => $database,
									   'prefix'           => $orgdata->{'prefix'},
									   'name'             => $assembly->{$asmbl_id}->{'name'},
									   'molecule_type'    => $assembly->{$asmbl_id}->{'molecule_type'},
									   'euk'              => $euk,
									   'genome_id'        => $genome_id,
									   'seqtype'          => $seqtype,
									   'ontology'         => $ontology,
									   'clone_id'         => $assembly->{$asmbl_id}->{'clone_id'},
									   'orig_annotation'  => $assembly->{$asmbl_id}->{'orig_annotation'},
									   'tigr_annotation'  => $assembly->{$asmbl_id}->{'tigr_annotation'},
									   'status'           => $assembly->{$asmbl_id}->{'status'},
									   'length'           => $assembly->{$asmbl_id}->{'length'},
									   'final_asmbl'      => $assembly->{$asmbl_id}->{'final_asmbl'},
									   'fa_left'          => $assembly->{$asmbl_id}->{'fa_left'},
									   'fa_right'         => $assembly->{$asmbl_id}->{'fa_right'},
									   'fa_orient'        => $assembly->{$asmbl_id}->{'fa_orient'},
									   'gb_desc'          => $assembly->{$asmbl_id}->{'gb_desc'},
									   'gb_comment'       => $assembly->{$asmbl_id}->{'gb_comment'},
									   'gb_date'          => $assembly->{$asmbl_id}->{'gb_date'},
									   'comment'          => $assembly->{$asmbl_id}->{'comment'},
									   'assignby'         => $assembly->{$asmbl_id}->{'assignby'},
									   'date'             => $assembly->{$asmbl_id}->{'date'},
									   'lib_id'           => $assembly->{$asmbl_id}->{'lib_id'},
									   'seq_asmbl_id'     => $assembly->{$asmbl_id}->{'seq_asmbl_id'},
									   'date_for_release' => $assembly->{$asmbl_id}->{'date_for_release'},
									   'date_released'    => $assembly->{$asmbl_id}->{'date_released'},
									   'authors1'         => $assembly->{$asmbl_id}->{'authors1'},
									   'authors2'         => $assembly->{$asmbl_id}->{'authors2'},
									   'seq_db'           => $assembly->{$asmbl_id}->{'seq_db'},
									   'gb_keywords'      => $assembly->{$asmbl_id}->{'gb_keywords'},
									   'sequencing_type'  => $assembly->{$asmbl_id}->{'sequencing_type'},
									   'prelim'           => $assembly->{$asmbl_id}->{'prelim'},
									   'license'          => $assembly->{$asmbl_id}->{'license'},
									   'gb_phase'         => $assembly->{$asmbl_id}->{'gb_phase'},
									   'chromosome'       => $assembly->{$asmbl_id}->{'chromosome'},
									   organism_name      => $orgdata->{'name'}
									   );
	
	#
	# Store the assembly sequence object reference in the sequence hash
	#
	$sequence_hash->{$asmbl_id} = $assembly_sequence_elem;
	


	#
	# editor:   sundaram@tigr.org
	# date:     2005-08-15
	# bgzcase:  2044 
	# URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2044
	# comment:  The legacy2bsml.pl script should ensure that the //Feature/@id == //Seq-data-import/@identifier for all sequences/features
	#
	$identifier_feature->{$asmbl_uniquename}++;
	
	

	#--------------------------------------------------------------------------------------------------------------------------------
	# editor:  sundaram@tigr.org
	# date:    2005-08-19
	# bgzcase: 2063
	# URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2063
	# comment: The script should not write <Feature-tables> for subfeature-less assemblies.
	#
	#
	# editor:  sundaram@tigr.org
	# date:    2005-09-20
	# bgzcase: 2140
	# URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2140
	# comment: The genefinder models will also require the creation of a <Feature-table> element object.
	#          This code verifies whether such an object should be created.
	#

	my $subfeatures_exist = &do_subfeatures_exist(
						      gene_model_hash => $gene_model_hash,
						      rna_hash        => $rna_hash,
						      peptide_hash    => $peptide_hash,
						      ribosome_hash   => $ribosome_hash,
						      terminator_hash => $terminator_hash,
						      gene_finder_hash => $gene_finder_hash
						      );

	#
	#
	#--------------------------------------------------------------------------------------------------------------------------------

	my $feature_table_elem;


	if (($euk == 1 ) && ($subfeatures_exist)) {
	    
	    #
	    # Create <Feature-table> element object
	    #
	    $feature_table_elem = $doc->createAndAddFeatureTable($assembly_sequence_elem);
	    
	    $logger->logdie("Could not create <Feature-table> element object reference") if (!defined($feature_table_elem));
	    
	}
	elsif ($euk != 1) {

	    #
	    # Create <Feature-table> element object
	    #
	    $feature_table_elem = $doc->createAndAddFeatureTable($assembly_sequence_elem);
	    
	    $logger->logdie("Could not create <Feature-table> element object reference") if (!defined($feature_table_elem));
	}



	#
	# Store all <Sequence> element objects i.e.:
	# 1) polypeptide
	# 2) CDS
	# 3) tRNA
	# 4) rRNA
	# 5) sRNA
	# 6) Terminator
	# 7) RBS
	#
	foreach my $data_hash ( @{$sequences_hashes->{$asmbl_id}} ){
	    
	    &store_sequence_elements(
				     'database'                 => $database,
				     'prefix'                   => $orgdata->{'prefix'},
				     'fastadir'                 => $fastadir,
				     'doc'                      => $doc,
				     'map'                      => $map,
				     'asmbl_id'                 => $asmbl_id,
				     'sequence_hash'            => $sequence_hash,
				     'sequence_subfeature_hash' => $data_hash,
				     'fastasequences'           => $fastasequences,
				     'seq_data_import_hash'     => $seq_data_import_hash,
				     'seq_data_import_ctr'      => $seq_data_import_ctr,
				     'identifier_seq_data'      => $identifier_seq_data,
				     'genome_id'                => $genome_id
				     );
	}
	
	$logger->debug("seq_data_import_ctr '$seq_data_import_ctr'") if $logger->is_debug;
	
	#
	# Store all Gene Encodings i.e. ORFs as:
	# 1) gene
	# 2) transcript
	# 3) CDS
	# 4) polypeptide
	# 5) exon
	#

	if ((defined($euk)) && ($euk == 1 )){
	    
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
						  polypeptide_feature_hash  => $polypeptide_feature_hash,
						  cds_feature_hash             => $cds_feature_hash
						  );
	    }
	    

	    #
	    # editor:   sundaram@tigr.org
	    # date:     2005-09-14
	    # bgzcase:
	    # URL:
	    # comment: The storing the gene finder data will be handled separately from the storing of the standard gene model data
	    #
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

	    
	    #-----------------------------------------------------------------------------------------------------------------------------------------------
	    # editor:   sundaram@tigr.org
	    # date:     Tue Nov  1 14:38:56 EST 2005
	    # bgzcase:  2141
	    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2141
	    # comment:  The ORF_attributes MW and pI shall be associated with the polypeptide features
	    #
	    &process_polypeptide_orf_attribute_data(
						    polypeptide_feature_hash => $polypeptide_feature_hash,
						    orf_attributes_hash      => $euk_polypeptide_orf_attributes_hash,
						    doc                      => $doc
						    );
	    #
	    #-----------------------------------------------------------------------------------------------------------------------------------------------


	    #---------------------------------------------------------------------------------------------------------------------------
	    # editor:   sundaram@tigr.org
	    # date:     Tue Nov 22 16:10:14 EST 2005
	    # bgzcase:  2292
	    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2292
	    # comment:  The models' ORF_attributes score and score2 where att_type = 'is_partial' shall be associated with the
	    #           corresponding CDS features in BSML and chado
	    #
	    &process_euk_cds_orf_attribute_data(
						cds_feature_hash    => $cds_feature_hash,
						orf_attributes_hash => $euk_cds_orf_attributes_hash,
						doc                 => $doc
						);
	    #
	    #-----------------------------------------------------------------------------------------------------------------------------------------------


	}
	else{

	    #
	    #  store_prok_gene_model_subfeatures redundantly stores the ORF data as the following features:
	    #  
	    #  1) gene
	    #  2) transcript
	    #  3) CDS
	    #  4) exon
	    #

	    foreach my $data_hash ( @{$gene_model_hash->{$asmbl_id}} ){
		
		
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
						   cds_feature_hash             => $cds_feature_hash
						   );
	    }


	    #------------------------------------------------------------------------------------------------------------------------------------------------
	    # editor:   sundaram@tigr.org
	    # date:     Wed Nov  2 13:19:26 EST 2005
	    # bgzcase:  2263
	    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2263
	    # comment:  The ORFs' ORF_attributes: MW, PI, LP, OMP will be associated with the polypeptide Features in BSML and chado.
	    #
	    &process_polypeptide_orf_attribute_data(
						    polypeptide_feature_hash => $polypeptide_feature_hash,
						    orf_attributes_hash      => $prok_polypeptide_orf_attributes_hash,
						    doc                      => $doc
						    );
	    #
	    #-------------------------------------------------------------------------------------------------------------------------------------------------

	    
	    #------------------------------------------------------------------------------------------------------------------------------------------------
	    # editor:   sundaram@tigr.org
	    # date:     Wed Nov  2 13:19:26 EST 2005
	    # bgzcase:  2263
	    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2263
	    # comment:  The ORFs' ORF_attribute: GC will be associated with the CDS Features in BSML and chado.
	    #
	    &process_prok_cds_orf_attribute_data(
						 cds_feature_hash     => $cds_feature_hash,
						 orf_attributes_hash  => $prok_cds_orf_attributes_hash,
						 doc                  => $doc
						 );
	    #
	    #-------------------------------------------------------------------------------------------------------------------------------------------------






	}


	#
	# Store RNA features
	# 1) rRNA
	# 2) tRNA
	# 3) sRNA
	#
	foreach my $data_hash ( @{$rna_hash->{$asmbl_id}} ){

	    &store_rna_subfeatures(
				   'rna'                => $data_hash,
				   'asmbl_id'           => $asmbl_id,
				   'doc'                => $doc, 
				   'database'           => $database,
				   'prefix'             => $orgdata->{'prefix'},
				   'feature_table_elem' => $feature_table_elem,
				   'identifier_feature' => $identifier_feature,
				   'genome_id'          => $genome_id
				   );
	}

	#
	# Store peptide features
	#
	foreach my $feat_name ( sort keys %{$peptide_hash->{$asmbl_id}} ){

	    &store_peptide_encodings(
				     'database'               => $database,
				     'doc'                    => $doc,
				     'asmbl_id'               => $asmbl_id,
				     'prefix'                 => $orgdata->{'prefix'},
				     'peptide'                => $peptide_hash->{$asmbl_id}->{$feat_name},
				     'feature_table_elem'     => $feature_table_elem,
				     'assembly_sequence_elem' => $assembly_sequence_elem,
				     'sequence_hash'          => $sequence_hash,
				     'peptide_feat_name'      => $feat_name,
				     'identifier_feature'     => $identifier_feature,
				     'genome_id'              => $genome_id,
				     'polypeptide_feat_name_to_locus' => $polypeptide_feat_name_to_locus
				     );
	}
	

	#
	# Store ribosome binding site encodings
	#
	foreach my $data_hash ( @{$ribosome_hash->{$asmbl_id}} ){
	    
	    &store_ribosomal_binding_site_encodings(
						    'database' => $database,
						    'doc'      => $doc,
						    'prefix'   => $orgdata->{'prefix'},
						    'asmbl_id' => $asmbl_id,
						    'ribo'     => $data_hash,
						    'feature_table_elem' => $feature_table_elem,
						    'r2g_lookup' => $r2g_lookup,
						    'gene_group_lookup'   => $gene_group_lookup,
						    'analysis_hash'       => $analysis_hash,
						    'identifier_feature'  => $identifier_feature,
						    'genome_id'           => $genome_id
						    );    
	}

	#
	# Store terminator features
	#
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

	#
	# Store Gene annotation attributes
	#
	#

	my $tran_ident_lookup = {};

	foreach my $transcript (sort keys %{$transcript_feature_hash} ){



	    #
	    # e.g. $transcript = 'afu1_100_100.t00001_transcript_iso_1
	    #

	    my $old_transcript = $transcript;


	    if ($euk == 1 ) {

		
		#
		# editor:  sundaram@tigr.org
		# date:    2005-09-12
		# bgzcase: 2081
		# URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2108
		# comment: Lookup for retrieving the mappings of the new isoform transcript uniquename to the original transcript uniquename
		#
		
		if ((exists $transcript_mapper->{$transcript}) && (defined($transcript_mapper->{$transcript}))){
		    $old_transcript = $transcript_mapper->{$transcript};
		    
		    #
		    # e.g. $old_transcript = 'afu1_100_100.t00001_transcript'
		    #
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
	    

	    &store_ident_attributes(
				    'doc'                     => $doc,
				    'uniquename'              => $transcript,
				    'transcript_feature_elem' => $transcript_feature_hash->{$transcript},
				    'attributes'              => $ident_attributes_hash->{$old_transcript}->{'attribute'},
				    'attribute-list'          => $ident_attributes_hash->{$old_transcript}->{'attribute-list'},
				    'tran_ident_lookup'       => $tran_ident_lookup,
				    'genome_id'               => $genome_id
				    );



	    
	    
	    
	    if (( exists $tigr_roles_hash->{$old_transcript}) and (defined($tigr_roles_hash->{$old_transcript}))){
		
		&store_roles_attributes(
					'transcript_feature_elem' => $transcript_feature_hash->{$transcript},
					'uniquename'              => $transcript,
					'attributelist'           => $tigr_roles_hash->{$old_transcript},
					'genome_id'               => $genome_id
					);
	    }

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

	#
	# Create compute/evidence BSML document(s)
	#


	#---------------------------------------------------------------------------------------------------------------
	# editor:   sundaram@tigr.org
	# date:     Mon Nov  7 13:15:51 EST 2005
	# bgzcase:  2273
	# URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2273
	# comment:  Need to store //Link/@role for each Sequence's analysis.  We define this lookup in order to 
	#           ensure that only one BsmlLink element object is created for each BsmlSequence-BsmlAnalysis
	#           per BsmlLink role type.
	#
	my $sequence_analysis_link = {};

	

	#
	# BER & AUTO-BER
	#
	if (defined($ber_evidence_hash->{$asmbl_id})){

	    &store_ber_evidence_data(
				     'doc'        => $doc,
				     'asmbl_id'   => $asmbl_id,
				     'data_hash'  => $ber_evidence_hash->{$asmbl_id},
				     'database'   => $database,
				     'docname'    => $doc->{'doc_name'},
				     'outdir'     => $outdir,
				     'prefix'     => $orgdata->{'prefix'},
				     'genome_id'  => $genome_id,
				     sequence_analysis_link => $sequence_analysis_link
				     );
	}
	


	#
	# HMM2 evidence
	#
	&store_hmm2_evidence_data(
				  'doc'           => $doc,
				  'asmbl_id'      => $asmbl_id,
				  'evidence_hash'     => $hmm2_evidence_hash,
				  'database'      => $database,
				  'docname'       => $doc->{'doc_name'},
				  'outdir'        => $outdir,
				  'prefix'        => $orgdata->{'prefix'},
				  'analysis_hash' => $analysis_hash,
				  'genome_id'     => $genome_id,
				  'sequence_analysis_link' => $sequence_analysis_link
				  );

	#
	# COG accession evidence
	#

	if (defined($cog_evidence_hash->{$asmbl_id})){

	    &store_cog_evidence_data(
				     'doc'           => $doc,
				     'asmbl_id'      => $asmbl_id,
				     'data_hash'     => $cog_evidence_hash->{$asmbl_id},
				     'database'      => $database,
				     'docname'       => $doc->{'doc_name'},
				     'outdir'        => $outdir,
				     'prefix'        => $orgdata->{'prefix'},
				     'analysis_hash' => $analysis_hash,
				     'genome_id'     => $genome_id,
				     sequence_analysis_link => $sequence_analysis_link
				     );
	}

	#
	# PROSITE evidence
	#

	if (defined($prosite_evidence_hash->{$asmbl_id})){

	    &store_prosite_evidence_data(
					 'doc'           => $doc,
					 'asmbl_id'      => $asmbl_id,
					 'data_hash'     => $prosite_evidence_hash->{$asmbl_id},
					 'database'      => $database,
					 'docname'       => $doc->{'doc_name'},
					 'outdir'        => $outdir,
					 'prefix'        => $orgdata->{'prefix'},
					 'analysis_hash' => $analysis_hash,
					 'genome_id'     => $genome_id,
					 sequence_analysis_link => $sequence_analysis_link
					 );
	}



    }
    

    &check_identifiers($identifier_feature, $identifier_seq_data);

    &write_out_bsml_doc($outdir, $doc);

    &dtd_validation($outdir, $doc->{'doc_name'}) if (defined($dtd));

    &schema_validation($outdir, $doc->{'doc_name'}) if (defined($schema));

    &create_multifasta($fastasequences, $fastadir, $database);


}
    
}

