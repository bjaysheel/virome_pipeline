#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#--------------------------------------------------------------------------------------
# program name:   getDbStatus.pl
# authors:        Jay Sundaram
# date:           2004-07-21
# 
#
# Purpose:        To retrieve some chado database information to print to screen
#
#---------------------------------------------------------------------------------------
=head1 NAME

legacy2bsml.pl - Retrieve some info from chado database

=head1 SYNOPSIS

USAGE:  getDbStatus.pl -U username -P password -D database [-l log4perl] [-d debug_level] [-h] [-m] [-o outdir]

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

=item B<--log4perl,-l>

Optional - Log4perl log file.  Defaults are:
           If asmbl_list is defined /tmp/legacy2bsml.pl.database_$database.asmbl_id_$asmbl_id.log
           Else /tmp/legacy2bsml.pl.database_$database.pid_$$.log

=item B<--outdir,-o>

Optional - Output directory for bsml document.  Overriden by --bsmldoc option.  Default is current working directory


=back

=head1 DESCRIPTION

getDbStatus.pl - Retrieve some info from chado database

=cut

use strict;


use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Digest::MD5 qw(md5);
use Config::IniFiles;
use Coati::Logger;
use File::Copy;


$| = 1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------
my ($database, $username, $password, $debug_level, $help, $man, $log4perl, $outdir); 

my $results = GetOptions (
			  'username|U=s'       => \$username, 
			  'password|P=s'       => \$password,
			  'database|D=s'       => \$database,
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

&print_usage if(!$username or !$password or !$database);


if (!defined($log4perl)){
    $log4perl = '/tmp/getDbStatus.pl.log';
    print("log file was not defined, therefore was set to '$log4perl'");
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


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
# Retrieve information and print it out 
#
my $ontology = $prism->query_cv_module();
$prism->create_html('Loaded ontologies', $ontology)


my $organisms = $prism->query_organism_module();
$prism->create_html('Loaded organisms', $organisms);


my $features = $prism->query_featuretypes();













my @list = (sort keys %{$assembly});
$asmbl_list = \@list;


my $sequences_hashes;
my $gene_model_hash;
my $accession_hash;
my $rna_hash ;
my $peptide_hash;
my $ribosome_hash;
my $terminator_hash;
my $ident_attributes_hash;
my $tigr_roles_hash;
my $go_roles_hash;
my $orf_attributes_hash;
my $ber_evidence_hash;
my $hmm2_evidence_hash;
my $cog_evidence_hash;
my $prosite_evidence_hash;


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
	$sequences_hashes = &create_euk_sequence_lookup($prism, $asmbl_list, $database);
	$gene_model_hash  = &create_euk_gene_model_lookup($prism, $asmbl_list, $database);

    }
    else{
	$sequences_hashes  = &create_prok_sequence_lookup($prism, $asmbl_list, $database, $ntprok);
	$gene_model_hash   = &create_prok_gene_model_lookup($prism, $asmbl_list, $database, $ntprok);
    }

    

    $accession_hash        = &create_accession_lookup($prism, $asmbl_list, $database, $ntprok);
    $rna_hash              = &create_rna_lookup($prism, $asmbl_list, $database, $ntprok);
    $peptide_hash          = &create_peptide_lookup($prism, $asmbl_list, $database, $ntprok);
    $ribosome_hash         = &create_ribosome_lookup($prism, $asmbl_list, $database, $ntprok);
    $terminator_hash       = &create_terminator_lookup($prism, $asmbl_list, $database, $ntprok);
    $ident_attributes_hash = &create_ident_attributes_lookup($prism, $asmbl_list, $database, $ntprok);
    $tigr_roles_hash       = &create_tigr_roles_lookup($prism, $asmbl_list, $database, $ntprok);
    $go_roles_hash         = &create_go_roles_lookup($prism, $asmbl_list, $database, $ntprok);
    $orf_attributes_hash   = &create_orf_attributes_lookup($prism, $asmbl_list, $database, $ntprok);
    $t2g_lookup            = &create_terminator_to_gene_lookup($prism, $asmbl_list, $database, $ntprok);
    $r2g_lookup            = &create_rbs_to_gene_lookup($prism, $asmbl_list, $database, $ntprok);


}
if ( ($mode == 2) or ($mode == 3) ){


    #
    # Mode 2: Write BSML encodings for all of the following:
    #         Sequence, Gene Model, RNA Features, Other Features, Gene Annotation Attributes. TIGR Roles, GO, ORF Attributes
    #
    # Mode 3: Write BSML encodings ONLY for BER, AUTO-BER and HMM2 evidence
    #

    $ber_evidence_hash      = &create_ber_evidence_lookup($prism, $asmbl_list, $database, $orgdata->{'prefix'}, $ntprok);
    $hmm2_evidence_hash     = &create_hmm2_evidence_lookup($prism, $asmbl_list, $database, $orgdata->{'prefix'}, $ntprok);
    $cog_evidence_hash      = &create_cog_evidence_lookup($prism, $asmbl_list, $database, $orgdata->{'prefix'}, $ntprok);
    $prosite_evidence_hash  = &create_prosite_evidence_lookup($prism, $asmbl_list, $database, $orgdata->{'prefix'}, $ntprok);

}



#
# Global lookups for BSML document linking
#
my $sequence_hash = {};
my $transcript_feature_hash = {};
my $protein_feature_hash = {};
my $seq_data_import_hash = {};
my $seq_data_import_ctr=0;
my $analysis_hash = {};
my $map = {};
my $fastasequences;
my $protein_feat_name_to_locus = {};
my $gene_group_lookup = {};

&load_map();

print "Building BSML document\n";

foreach my $asmbl_id ( sort keys %{$assembly} ){

    
    #--------------------------------------------------------------------------------------------
    #
    # Foreach asmbl - instantiate the Bsml doc Builder class
    #               - initialize and increment the cross-reference counter
    #
    #--------------------------------------------------------------------------------------------
    my $doc = new BSML::BsmlBuilder();
    $doc->{'doc_name'} = $database . '_' .$asmbl_id . '_assembly.bsml';
    $doc->{'xrefctr'}++;
    
    &create_genome_component(
			     $doc,
			     $orgdata
			     );


    if (($mode == 1) or ($mode == 2)) {


	# mode 1: gene model only
	# mode 2: gene model + computational evidence
	# mode 3: computational evidence only 



	my $asmbl_uniquename = $database . "_" . $asmbl_id . "_assembly";
	my $sequence = $assembly->{$asmbl_id}->{'sequence'};
	my $asmlen = length($sequence);


	$logger->debug("Storing assembly '$asmbl_uniquename' sequence in multi-fasta hash") if $logger->is_debug;
	

	my $array = [$asmbl_uniquename, $assembly->{$asmbl_id}->{'sequence'}];
	push ( @{$fastasequences->{$asmbl_id}->{'assembly'}}, $array);
	

	my ($assembly_sequence_elem) = &create_assembly_sequence_component(
									   'asmbl_id'      => $asmbl_id,
									   'uniquename'    => $asmbl_uniquename,
									   'length'        => $asmlen,
									   'topology'      => $assembly->{$asmbl_id}->{'topology'},
									   'doc'           => $doc,
									   'class'         => 'assembly',
									   'fastadir'      => $fastadir,
									   'database'      => $database,
									   'prefix'        => $orgdata->{'prefix'},
									   'name'          => $assembly->{$asmbl_id}->{'name'},
									   'molecule_type' => $assembly->{$asmbl_id}->{'molecule_type'},
									   'euk'           => $euk
									   );
	
	#
	# Store the assembly sequence object reference in the sequence hash
	#
	$sequence_hash->{$asmbl_id} = $assembly_sequence_elem;
	
	#
	# Create <Feature-table> element object
	#
	my $feature_table_elem = $doc->createAndAddFeatureTable($assembly_sequence_elem);
	
	$logger->logdie("Could not create <Feature-table> element object reference") if (!defined($feature_table_elem));
	
	#
	# Store all <Sequence> element objects i.e.:
	# 1) protein
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
				     'sequence_subfeature_hash' => $data_hash
				     );
	}
	
	$logger->debug("seq_data_import_ctr '$seq_data_import_ctr'") if $logger->is_debug;
	
	#
	# Store all Gene Encodings i.e. ORFs as:
	# 1) gene
	# 2) transcript
	# 3) CDS
	# 4) protein
	# 5) exon
	#

	if ((defined($euk)) && ($euk == 1 )){
	    
	    foreach my $data_hash ( @{$gene_model_hash->{$asmbl_id}} ){
		
		&store_euk_gene_model_subfeatures(
						  'datahash'               => $data_hash,
						  'asmbl_id'               => $asmbl_id,
						  'feature_table_elem'     => $feature_table_elem,
						  'doc'                    => $doc,
						  'database'               => $database,
						  'prefix'                 => $orgdata->{'prefix'},
						  'assembly_sequence_elem' => $assembly_sequence_elem,
						  'accession_lookup'       => $accession_hash->{$asmbl_id},
						  'gene_group_lookup'      => $gene_group_lookup
						  );
	    }
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
						   'gene_group_lookup'      => $gene_group_lookup
						   );
	    }
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
				     'peptide_feat_name'      => $feat_name
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
						    'gene_group_lookup' => $gene_group_lookup
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
				       't2g_lookup'         => $t2g_lookup
				       );    
	}

	#
	# Store Gene annotation attributes
	#
	#
	foreach my $transcript (sort keys %{$transcript_feature_hash} ){


	    &store_ident_attributes(
				    'doc'                     => $doc,
				    'uniquename'              => $transcript,
				    'transcript_feature_elem' => $transcript_feature_hash->{$transcript},
				    'attributes'              => $ident_attributes_hash->{$transcript}->{'attribute'},
				    'attribute-list'          => $ident_attributes_hash->{$transcript}->{'attribute-list'}
				    );


	    if (( exists $tigr_roles_hash->{$transcript}) and (defined($tigr_roles_hash->{$transcript}))){

		&store_roles_attributes(
					'transcript_feature_elem' => $transcript_feature_hash->{$transcript},
					'uniquename'              => $transcript,
					'attributelist'           => $tigr_roles_hash->{$transcript}
					);
	    }

	    &store_go_attributes(
				 'transcript_feature_elem' => $transcript_feature_hash->{$transcript},
				 'uniquename'              => $transcript,
				 'attributelist'           => $go_roles_hash->{$transcript}
				 );
	    
	    &store_orf_attribute_data(
				      'transcript_feature_elem' => $transcript_feature_hash->{$transcript},
				      'uniquename'              => $transcript,
				      'attributelist'           => $orf_attributes_hash->{$transcript}->{'attributelist'},
				      'attributes'              => $orf_attributes_hash->{$transcript}->{'attributes'},
				      'doc'                     => $doc
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


	#
	# BER & AUTO-BER
	#
	if (defined($ber_evidence_hash->{$asmbl_id})){

	    &store_ber_evidence_data(
				     doc       => $doc,
				     asmbl_id  => $asmbl_id,
				     data_hash => $ber_evidence_hash->{$asmbl_id},
				     database  => $database,
				     docname   => $doc->{'doc_name'},
				     outdir    => $outdir,
				     prefix    => $orgdata->{'prefix'}
				     );
	}
    


	#
	# HMM2 evidence
	#

	if (defined($hmm2_evidence_hash->{$asmbl_id})){

	    &store_hmm2_evidence_data(
				      doc       => $doc,
				      asmbl_id  => $asmbl_id,
				      data_hash => $hmm2_evidence_hash->{$asmbl_id},
				      database  => $database,
				      docname   => $doc->{'doc_name'},
				      outdir    => $outdir,
				      prefix    => $orgdata->{'prefix'}
				      );
	}


	#
	# COG accession evidence
	#

	if (defined($cog_evidence_hash->{$asmbl_id})){

	    &store_cog_evidence_data(
				     doc       => $doc,
				     asmbl_id  => $asmbl_id,
				     data_hash => $cog_evidence_hash->{$asmbl_id},
				     database  => $database,
				     docname   => $doc->{'doc_name'},
				     outdir    => $outdir,
				     prefix    => $orgdata->{'prefix'}
				     );
	}

	#
	# PROSITE evidence
	#

	if (defined($prosite_evidence_hash->{$asmbl_id})){

	    &store_prosite_evidence_data(
					 doc       => $doc,
					 asmbl_id  => $asmbl_id,
					 data_hash => $prosite_evidence_hash->{$asmbl_id},
					 database  => $database,
					 docname   => $doc->{'doc_name'},
					 outdir    => $outdir,
					 prefix    => $orgdata->{'prefix'}
					 );
	}



    }
    




    &write_out_bsml_doc($outdir, $doc);
    &dtd_validation($outdir, $doc->{'doc_name'}) if (defined($dtd));
    &schema_validation($outdir, $doc->{'doc_name'}) if (defined($schema));
    &create_multifasta($fastasequences, $fastadir, $database);
}



print "All .fsa files were written to '$fastadir'\n".
       "All .bsml files were written to '$outdir'\n".
       "Please verify log4perl log file: $log4perl\n";






#------------------------------------------------------------------------------------------------------------------------------------
#
#                END OF MAIN SECTION -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------
# create_euk_sequence_lookup()
#
# This lookup will only contain:
# 1) protein
# 2) CDS
# 3) tRNA
# 4) rRNA
# 5) sRNA
# 6) Terminator
# 7) RBS
#
#----------------------------------------------------------------------------------------
sub create_euk_sequence_lookup {

#    return;

    my ($prism, $asmbllist, $db) = @_;


    my $asmblhash = {};
    my @fullret;


    my @sequences = ('TU', 'model', 'tRNA', 'sRNA', 'rRNA', 'ncRNA', 'TERM', 'RBS');
    
    $prism->check_and_set_text_size();


    foreach my $asmbl_id (sort @{$asmbllist} ){        


	foreach my $feat_type (@sequences){


	    my $ret = $prism->sequence_features($asmbl_id, $db, $feat_type);
	    
	    	    
	    foreach my $block ( @{$ret} ){
		

		$block->[2] = 'snRNA' if ($block->[2] eq 'sRNA');

		my $tmphash = {
		    'feat_name' => $block->[1],
		    'feat_type' => $block->[2],
		    'sequence'  => $block->[3],
		    'seqlen'    => length($block->[3]),
		};
		

		if ($block->[2] eq 'model'){
		    #
		    # Since the protein is stored with the model in the legacy database table asm_feature,
		    # need to store data twice-  once for the CDS and then for the protein
		    #


		    $tmphash->{'feat_type'}  = 'CDS_seq';
		    push ( @{$asmblhash->{$asmbl_id}}, $tmphash );		    
		    
		    if ((defined($block->[4])) and ($block->[4] !~ /^\s+$/)) {
			
			my $othertmphash = {
			    'feat_type' => 'protein_seq',
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
    }

    return ($asmblhash);

 
}

#----------------------------------------------------------------------------------------
# create_prok_sequence_lookup()
#
# This lookup will only contain:
# 1) protein
# 2) CDS
# 3) tRNA
# 4) rRNA
# 5) sRNA
# 6) Terminator
# 7) RBS
#
#----------------------------------------------------------------------------------------
sub create_prok_sequence_lookup {

#    return;

    my ($prism, $asmbllist, $db, $ntprok, $euk) = @_;

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
    #  sequence related data.  (Note that a separate query will return the protein
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


    my @sequences = ('ORF', 'tRNA', 'sRNA', 'rRNA', 'ncRNA', 'TERM', 'RBS');
    if ((defined($ntprok)) and ($ntprok == 1 )){
	@sequences = ('NTORF', 'tRNA', 'sRNA', 'rRNA', 'ncRNA', 'TERM', 'RBS');
    }


    $prism->check_and_set_text_size();


    foreach my $asmbl_id (sort @{$asmbllist} ){        


	foreach my $feat_type (@sequences){


	    my $ret = $prism->sequence_features($asmbl_id, $db, $feat_type);
	    
	    	    
	    foreach my $block ( @{$ret} ){
		

		$block->[2] = 'snRNA' if ($block->[2] eq 'sRNA');

		my $tmphash = {
		    'feat_name' => $block->[1],
		    'feat_type' => $block->[2],
		    'sequence'  => $block->[3],
		    'seqlen'    => length($block->[3]),
		};
		

		if (($block->[2] eq 'ORF') or ($block->[2] eq 'NTORF')){
		    #
		    # Load the details twice.  Once for the CDS and then for the protein
		    #

		    $tmphash->{'feat_type'}  = 'CDS_seq';
		    push ( @{$asmblhash->{$asmbl_id}}, $tmphash );		    
		    
		    if ((defined($block->[4])) and ($block->[4] !~ /^\s+$/)) {
			
			my $othertmphash = {
			    'feat_type' => 'protein_seq',
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
    }
 

    return ($asmblhash);

    
#     #
#     # Build the desired hash-of-arrayes-of-hashes data structure...
#     #
#     foreach my $ret (@fullret) {
	
# 	#
# 	# $ret is a reference to a 2 dimensional array
# 	# 
# 	# $ret->[0][0] = asm_feature.asmbl_id
# 	# $ret->[0][1] = asm_feature.feat_name
# 	# $ret->[0][2] = asm_feature.feat_type
# 	# $ret->[0][3] = asm_feature.sequence
# 	# $ret->[0][4] = asm_feature.protein
# 	#

 
}

#----------------------------------------------------------------------------------------
# create_prok_gene_model_lookup()
# 
# This lookup will only contain ORF data
#
#----------------------------------------------------------------------------------------
sub create_prok_gene_model_lookup {

#    return;
    my ($prism, $asmbllist, $db, $ntprok) = @_;


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


   foreach my $asmbl_id ( @{$asmbllist} ) {

       my $ret = $prism->gene_model_data($asmbl_id, $db, $ntprok);
       

       foreach my $block ( @{$ret} ) {
	   
	   my ($end5, $end3, $complement) = &coordinates($block->[2], $block->[3]);
	   
	   my $tmphash = {
	       'feat_name'      => $block->[1],
	       'end5'           => $end5,
	       'end3'           => $end3,
	       'complement'     => $complement,
	       'locus'          => $block->[4],
	       'display_locus'  => $block->[5]
	   };
	   
	   #
	   # if defined, locus should replace the feat_name 
	   #
	   #$tmphash->{'feat_name'} = $block->[4] if (defined($block->[4]));
	   
	   push( @{$rethash->{$block->[0]}}, $tmphash );
	   
       }
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

    my ($prism, $asmbllist, $db, $ntprok) = @_;
    
    my $rethash = {};
    
    foreach my $asmbl_id ( @{$asmbllist} ) {
	
	my $ret = $prism->accession_data($asmbl_id, $db, $ntprok);
	
	foreach my $block ( @{$ret} ) {
	    
	    $block->[2] = 'genbank_pid'        if ($block->[2] eq 'PID');
	    $block->[2] = 'genbank_protein_id' if ($block->[2] eq 'protein_id');
	    $block->[2] = 'swiss_prot'         if ($block->[2] eq 'SP');
	    $block->[2] = 'ecocyc'             if ($block->[2] eq 'ECOCYC');

	   #          asmbl_id        feat_name      accession_db    accesion_id  
	    $rethash->{$block->[0]}->{$block->[1]}->{$block->[2]} = $block->[3];

       }
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


#----------------------------------------------------------------------------------------
# create_rna_lookup()
# 
# This lookup will only contain:
# 1) rRNA
# 2) tRNA
# 3) sRNA
# 4) ncRNA
#----------------------------------------------------------------------------------------
sub create_rna_lookup {

#    return;

    my ($prism, $asmbllist, $db, $ntprok) = @_;

    #
    # This subroutine should return a hash containing an arrays which contain hashes
    # The hash's key will be the asmbl_id
    # The array of hashes will contain anonymous hashes of the form:
    #
    # $data_hash = {
    #                'feat_name'  => asm_feature.feat_name || ident.locus
    #                'end5'       => compute(end5,end3)
    #                'end3'       => compute(end5,end3)
    #                'feat_type'  => asm_feature.feat_type
    #                'locus'      => ident.locus
    #                'com_name'   => ident.com_name
    #                'anti_codon' => feat_score.score


    my $rethash = {};


    #
    # Retrieve the tRNA ORF_attribute, feat_score and score_type
    # related data
    #
    my $score_hash = &create_trna_score_lookup($prism, $asmbllist, $db);


    foreach my $asmbl_id ( @{$asmbllist} ) {


	foreach my $feat_type ('tRNA', 'rRNA', 'sRNA', 'ncRNA'){


	    my $ret = $prism->rna_data($asmbl_id, $db, $feat_type, $ntprok);

	
	    foreach my $block ( @{$ret} ) {
		
		

		$block->[4] = 'snRNA' if ($block->[4] eq 'sRNA');

		my ($end5, $end3, $complement) = &coordinates($block->[2], $block->[3]);
		
		my $tmphash = {
		    'feat_name'   =>  $block->[1],
		    'end5'        =>  $end5,
		    'end3'        =>  $end3,
		    'complement'  =>  $complement,
		    'feat_type'   =>  $block->[4] .'_feature',
		    'com_name'    =>  $block->[5],
		    'gene_symbol' =>  $block->[6],
		    'public_comment' =>  $block->[7]
		};
	    

		#
		# If the feat_type is 'tRNA' then insert
		# the corresponding feat_score.score (if exists) 
		# into the hash
		#
		
		if ( ($block->[4] eq 'tRNA' ) and ( exists ($score_hash->{$block->[1]}) )){
		    $tmphash->{'anti-codon'} = $score_hash->{$block->[1]};
		}
	     
		push( @{$rethash->{$block->[0]}}, $tmphash );
		 
	     
	    }
	}
    }
    
    return ($rethash);
 	
}


#----------------------------------------------------------------------------------------
# create_trna_score_lookup()
# 
# This function will create a feat_score.score lookup for all tRNA related records
# Legacy tables involved:
#
#----------------------------------------------------------------------------------------
sub create_trna_score_lookup {

    my ($prism, $asmbllist, $db) = @_;

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

    foreach my $asmbl_id ( @{$asmbllist} ) {

	my $ret = $prism->trna_scores($asmbl_id, $db);

	
	foreach my $block ( @{$ret} ) {

	    $rethash->{$block->[0]} = $block->[1];

	}

    }
	
    return ($rethash);
	
}


#----------------------------------------------------------------------------------------
# create_peptide_lookup()
#
# This lookup will only contain peptide data
#
#----------------------------------------------------------------------------------------
sub create_peptide_lookup {

#    return;

    my ($prism, $asmbllist, $db, $ntprok) = @_;

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

    my $rethash = {};

    my $v = {};

    foreach my $asmbl_id ( @{$asmbllist} ) {


    #
    # Retrieve: feat_name, score_type, score
    # from database. Foreach record:
    #     $v->{$asmbl_id}->{$feat_name}->{ $score_type} = $score;
    #
    #

	my $ret = $prism->peptide_data($asmbl_id, $db, $ntprok);

	foreach my $block ( @{$ret} ) {
	 
	    #                  feat_name       score_type     score
	    $v->{$asmbl_id}->{$block->[0]}->{$block->[1]} = $block->[2];

	}
    }
	

    foreach my $asmbl_id (sort keys %{$v}){
	

	foreach my $feat_name ( sort keys %{$v->{$asmbl_id}} ){

	    my $tmphash = {};
#	    $tmphash->{'feat_name'} = $feat_name;

	    foreach my $score_type ( sort keys %{$v->{$asmbl_id}->{$feat_name}} ){
		
		my $finalname;

		#
		# We want to rename some of the attributes...
		#
		if ($score_type eq 'Y-score') {
		    $finalname = 'y-score';
		}
		elsif ($score_type eq 'signal pep prob') {
		    $finalname = 'signal_probability';
		}
		elsif ($score_type eq 'cleavage site prob'){
		    $finalname = 'max_cleavage_site_probability';
		}
		elsif ($score_type eq 'site') {
		    $finalname = 'NN_cleavage_site';
		}
		elsif ($score_type eq 'S-score') {
		    $finalname = 's-score';
		}
		elsif ($score_type eq 'C-score') {
		    $finalname = 'c-score';
		}


		else{
		    $finalname = $score_type;
		}

		#
		# replace all spaces with '_'
		#
		($finalname =~ s/\s+/_/g);


		#
		# Load all of the attributes associated to a particular feat_name
		#
		#$tmphash->{$feat_name}}, finalname} = $v->{$asmbl_id}->{$feat_name}->{$score_type};
		$tmphash->{$finalname} = $v->{$asmbl_id}->{$feat_name}->{$score_type};
	    }

	    $rethash->{$asmbl_id}->{$feat_name} = $tmphash;
#	    push( @{$rethash->{$asmbl_id}}, $tmphash);
	
	}
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

#    return;

   my ($prism, $asmbllist, $db) = @_;



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
   
   foreach my $asmbl_id ( @{$asmbllist} ) {
       
       my $ret = $prism->ribosomal_data($asmbl_id, $db);
       
       foreach my $block ( @{$ret} ) {
	   
	   my ($end5, $end3, $complement) = &coordinates($block->[2], $block->[3]);
	   
	   my $tmphash = {
	       'feat_name'   =>  $block->[1],
	       'end5'        =>  $end5,
	       'end3'        =>  $end3,
	       'complement'  =>  $complement
	   };
	   
	   
	   push( @{$rethash->{$block->[0]}}, $tmphash );
       }
       
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

#    return;

   my ($prism, $asmbllist, $db) = @_;

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



   my $term_direction_hash = &create_term_direction_hash($prism, $asmbllist, $db);
   my $term_confidence_hash = &create_term_confidence_hash($prism, $asmbllist, $db);


   
   my $rethash = {};
   
   foreach my $asmbl_id ( @{$asmbllist} ) {
       
       my $ret = $prism->terminator_data($asmbl_id, $db);
       
       foreach my $block ( @{$ret} ) {
	   
	   my ($end5, $end3, $complement) = &coordinates($block->[2], $block->[3]);
	   
	   my $tmphash = {
	       'feat_name'   =>  $block->[1],
	       'end5'        =>  $end5,
	       'end3'        =>  $end3,
	       'complement'  =>  $complement,
#	       'TERM'        =>  $block->[4]
	       'direction'   =>  $term_direction_hash->{$asmbl_id}->{$block->[1]},
	       'confidence'  =>  $term_confidence_hash->{$asmbl_id}->{$block->[1]},
	   };
	   
	   
	   push( @{$rethash->{$block->[0]}}, $tmphash );
       }
       
   }

   return ($rethash);
 

 
}

#----------------------------------------------------------------------------------------
# create_term_direction_hash()
# 
# 
#----------------------------------------------------------------------------------------
sub create_term_direction_hash {

    my ($prism, $asmbllist, $db) = @_;
    
    
    my $rethash = {};
    
    foreach my $asmbl_id ( @{$asmbllist} ) {
	
	my $ret = $prism->term_direction_data($asmbl_id, $db);
	
	foreach my $block ( @{$ret} ) {
	    
	    $logger->logdie("block[0] '$block->[0]' ne asmbl_id '$asmbl_id'") if ($block->[0] ne $asmbl_id);

	    #    assembly.asmbl_id   asm_feature.feat_name   feat_score.score
	    $rethash->{$asmbl_id}->{$block->[1]} = $block->[2];
	    
	}
	
    }
    
   return ($rethash);
}

#----------------------------------------------------------------------------------------
# create_term_confidence_hash()
# 
#----------------------------------------------------------------------------------------
sub create_term_confidence_hash {

    my ($prism, $asmbllist, $db) = @_;
    
    my $rethash = {};
    
    foreach my $asmbl_id ( @{$asmbllist} ) {
	
	my $ret = $prism->term_confidence_data($asmbl_id, $db);
	
	foreach my $block ( @{$ret} ) {
	    
	    $logger->logdie("block[0] '$block->[0]' ne asmbl_id '$asmbl_id'") if ($block->[0] ne $asmbl_id);

	    #    assembly.asmbl_id   asm_feature.feat_name   feat_score.score
	    $rethash->{$asmbl_id}->{$block->[1]} = $block->[2];
	    
	}
	
    }
    
   return ($rethash);
}


#----------------------------------------------------------------------------------------
# create_terminator_to_gene_lookup()
# 
#----------------------------------------------------------------------------------------
sub create_terminator_to_gene_lookup {

   my ($prism, $asmbllist, $db) = @_;
   
   my $rethash = {};
   
   foreach my $asmbl_id ( @{$asmbllist} ) {
       
       my $ret = $prism->terminator_to_gene_data($asmbl_id, $db);
       
       foreach my $block ( @{$ret} ) {
	   
	   $rethash->{$block->[0]}->{$block->[1]} = $block->[2];
       }
       
   }

   return ($rethash);

}


#----------------------------------------------------------------------------------------
# create_rbs_to_gene_lookup()
# 
#----------------------------------------------------------------------------------------
sub create_rbs_to_gene_lookup {

   my ($prism, $asmbllist, $db) = @_;
   
   my $rethash = {};
   
   foreach my $asmbl_id ( @{$asmbllist} ) {
       
       my $ret = $prism->rbs_to_gene_data($asmbl_id, $db);
       
       foreach my $block ( @{$ret} ) {
	   
	   $rethash->{$block->[0]}->{$block->[1]} = $block->[2];
       }
       
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

#    return;

   my ($prism, $asmbllist, $db, $ntprok) = @_;


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
   
   foreach my $asmbl_id ( @{$asmbllist} ) {
       
       my $ret = $prism->gene_annotation_ident_attribute_data($asmbl_id, $db, $ntprok);
       

       foreach my $block ( @{$ret} ) {
	   

	   my $transcript = $db . '_' . $asmbl_id . '_' . $block->[1] . '_transcript';
	   
	   #
	   # Change the return data structure to accomodate inclusion of attribute-list sublist reference.
	   # For all attributes to be stored in an <Attribute> element and NOT in an <Attribute-list> element
	   # we will push the attributes onto the @{$rethash->{$transcript}->{'attribute'}} array
	   #
	   if (defined($block->[2])){

	       $block->[2] = remove_cntrl_chars($block->[2]);
	       $block->[2] =~ s/\015//g;
	       $block->[2] =~ s/\t/\\t/g;
	       $block->[2] =~ s/\n/\\n/g;
	       push ( @{$rethash->{$transcript}->{'attribute'}}, { 'gene_product_name' => $block->[2] } );
	   }

	   if (defined($block->[3])){
	       push ( @{$rethash->{$transcript}->{'attribute'}}, { 'assignby'  => $block->[3] } );
	   }

	   if (defined($block->[4])){
	       push ( @{$rethash->{$transcript}->{'attribute'}}, { 'date'      => $block->[4] } );
	   }




	   if (((defined($block->[5])) && ($block->[5] !~ /^\s+$/)) && ($block->[5] !~ /NULL/)){
	       #
	       # In some cases, ident.comment contains an empty string value.
	       #

	       $block->[5] = remove_cntrl_chars($block->[5]);
	       $block->[5] =~ s/\015//g;
	       $block->[5] =~ s/\n/\\n/g;

	       push ( @{$rethash->{$transcript}->{'attribute'}}, { 'comment'   => $block->[5] } );
	   }

	   if (defined($block->[6])){

	       $block->[6] = remove_cntrl_chars($block->[6]);
	       $block->[6] =~ s/\015//g;
	       $block->[6] =~ s/\n/\\n/g;

	       push ( @{$rethash->{$transcript}->{'attribute'}}, {'nt_comment' => $block->[6] } );
	   }



	   if (defined($block->[7])){

	       $block->[7] = remove_cntrl_chars($block->[7]);
	       $block->[7] =~ s/\015//g;
	       $block->[7] =~ s/\n/\\n/g;

	       push ( @{$rethash->{$transcript}->{'attribute'}}, {'auto_comment' => $block->[7] } );
	   }


	   #
	   # Changing gene_sym to gene_symbol.  Legacy databases use "gene_sym" whereas the BSML documents and the chado databases will use "gene_symbol"
	   #
	   if ((defined($block->[8])) && ($block->[8] !~ /^\s+$/)){
	       push ( @{$rethash->{$transcript}->{'attribute'}}, {'gene_symbol'   => $block->[8] } );
	   }
       

	   if ((defined($block->[9])) && ($block->[9] ne '')){
#	   if (defined($block->[9])){
	       push ( @{$rethash->{$transcript}->{'attribute'}}, {'start_site_editor' => $block->[9] } );
	   }

	   if ((defined($block->[10])) && ($block->[10] ne '')){
#	   if (defined($block->[10])){
	       push ( @{$rethash->{$transcript}->{'attribute'}}, {'completed_by'      => $block->[10] } );
	   }

	   if ((defined($block->[11])) && ($block->[11] ne '')){
#	   if (defined($block->[11])){
	       push ( @{$rethash->{$transcript}->{'attribute'}}, {'auto_annotate_toggle' => $block->[11] } );
	   }
#


	   if (defined($block->[13])){

	       $block->[13] = remove_cntrl_chars($block->[13]);
	       $block->[13] =~ s/\015//g;
	       $block->[13] =~ s/\n/\\n/g;

	       push ( @{$rethash->{$transcript}->{'attribute'}}, {'public_comment' => $block->[13] } );
	   }



	   #
	   # Now adding the ec# to a <Attribute-list>
	   # This will result in the creation of a chado.feature_cvterm record linking the feature to the cvterm.
	   #
	   # This will be the resulting chado table/record relationship:
	   #
	   # WHERE feature.feature_id = feature_cvterm.feature_id
	   # AND feature_cvterm.cvterm_id = cvterm.cvterm_id
	   # AND cvterm.dbxref_id = cvterm_dbxref.dbxref_id
	   # AND dbxref.accession = ec#
	   #
	   #
	   if (defined($block->[12])){

	       my @eclist = split(/\s+/,$block->[12]);

	       foreach my $ec (sort @eclist){

		   my $smalllist;

		   push (@ {$smalllist}, { 'EC' => $ec } );

		   push( @{$rethash->{$transcript}->{'attribute-list'}}, $smalllist);

	       }
	   }


	   if ((defined($block->[14])) && ($block->[14] == 1)){

	       $block->[14] = remove_cntrl_chars($block->[14]);
	       $block->[14] =~ s/\015//g;
	       $block->[14] =~ s/\n/\\n/g;
	       
	       push ( @{$rethash->{$transcript}->{'attribute-list'}}, ['public_comment' => 'pseudogene' ] );
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

#    return;

    my ($prism, $asmbllist, $db, $ntprok) = @_;
    
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
    #
    #

#    my $rethash = {};
    my $sublist;    

    foreach my $asmbl_id ( @{$asmbllist} ) {
	
	my $ret = $prism->gene_annotation_go_attribute_data($asmbl_id, $db, $ntprok);


	my $load=0;
	
	foreach my $block ( @{$ret} ) {



	    
	    my $transcript = $db . '_' . $asmbl_id . '_' . $block->[1] . '_transcript';
	    
	    my $smallload = 0;
	    my $smalllist;
	    
	    
	    if (defined($block->[2])){
		
		push (@ {$smalllist}, {'TIGR_role'  => $block->[2] });
		$smallload++;
	    }
	    
	    if (defined($block->[3])){
		
		push (@ {$smalllist}, { 'assignby' => $block->[3]  });
		$smallload++;
	    }
	    
	    if (defined($block->[4])){
		
		push (@ {$smalllist}, { 'date'  => $block->[4]  });
		$smallload++;
	    }

	    if (defined($block->[5])){
		
		push (@ {$smalllist}, { 'comment'  => $block->[5]  });
		$smallload++;
	    }


	    if ($smallload > 0 ){
		push ( @{$sublist->{$transcript}}, $smalllist );
		$load++;
	    }

	}

    }

    $logger->fatal("role info" . Dumper $sublist);
    return $sublist;
 
}

#----------------------------------------------------------------------------------------
# create_go_roles_lookup()  --  Gene annotation attributes
# 
# This lookup will only contain GO Roles data for the ORFs
#
#----------------------------------------------------------------------------------------
sub create_go_roles_lookup {

    my ($prism, $asmbllist, $db, $ntprok) = @_;
    
    
    #
    # This subroutine will return a hash containing a array of hashes.
    # The primary hash's key will be the $transcript (feat_name).  The arrays will have the
    # following structure:
    # 

    my @features = ('ORF');
    if ((defined($ntprok)) && ($ntprok == 1)) {
	@features = ('NTORF');
    }

    my $rethash = {};
   
    foreach my $asmbl_id ( @{$asmbllist} ) {

	foreach my $feat_type ( @features ){
	
	    my $ret = $prism->gene_annotation_evidence_data($asmbl_id, $db, $feat_type);
      
	    foreach my $block ( @{$ret} ) {
		
		my $transcript = $db . '_' . $asmbl_id . '_' . $block->[1] . '_transcript';
		
		my $tmparray;
		my $load;


		if ((defined($block->[2])) && ($block->[2] !~ /NULL/)){

		    push ( @{$tmparray}, { 'GO' => $block->[2]  });
		    $load++;


		    if (defined($block->[3])){
			
			push ( @{$tmparray}, { 'assignby'  => $block->[3]  });
			$load++;
		    }

		    if (defined($block->[4])){

			push ( @{$tmparray}, { 'date' => $block->[4] });
			$load++;
		    }

		    if ((defined($block->[5])) and ($block !~ /^\s+$/)){

			push ( @{$tmparray}, { 'qualifier'  => $block->[5] });
			$load++;
		    }

		    if ((defined($block->[6])) and (defined($block->[7]))){
			
			my $content = $block->[7];
			
			if (defined($block->[8])){
			    
			    $content .= " WITH " . $block->[8];

			}
			
			push ( @{$tmparray}, { $block->[6]  => $content });
			$load++;
		    }
		    
		    if ($load>0){
			push (@ {$rethash->{$transcript}}, $tmparray );
		    }
		}		
	    }
       }
       
   }

    return ($rethash);
  
}

#----------------------------------------------------------------------------------------
# create_orf_attributes_lookup()  --  Gene annotation attributes
# 
# This lookup will only contain orf_attribute data for the ORFs
#
#----------------------------------------------------------------------------------------
sub create_orf_attributes_lookup {

   my ($prism, $asmbllist, $db, $ntprok) = @_;
   
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
   my $attholder = {};
   my $transcripthash = {};


   foreach my $asmbl_id ( @{$asmbllist} ) {
       
       foreach my $att_type ('MW', 'PI', 'GC', 'LP', 'OMP'){
	   
	   my $ret;

	   if ((defined($ntprok)) && ($ntprok == 1 )){
	       $ret = $prism->gene_orf_attributes($asmbl_id, $db, 'NTORF', $att_type);
	   }
	   else{
	       $ret = $prism->gene_orf_attributes($asmbl_id, $db, 'ORF', $att_type);
	   }

	   foreach my $block ( @{$ret} ){

	       my $transcript = $db . '_' . $asmbl_id . '_' . $block->[1] . '_transcript';

	       $transcripthash->{$transcript} = '';


#	       if ((defined($block->[3])) && ($block->[3] ne '')){
	       if ((defined($block->[3])) && ($block->[3] !~ /^\s+$/)){

		   if (($block->[2] eq 'MW') or ($block->[2] eq 'GC') or ($block->[2] eq 'PI')){

		       if ($block->[2] eq 'PI'){
			   $block->[2] = 'pI';
		       }

		       if ($block->[2] eq 'GC'){
			   $block->[2] = 'percent_GC';
		       }

		       
		       push ( @{$rethash->{$transcript}->{'attributes'}}, {
			   'name'    => $block->[2],
			   'content' => $block->[3]
		       });
		   }
		   else{
		       $attholder->{$transcript}->{$block->[2]}  = $block->[3];
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
   }


   my $athash;
   push (@{$athash}, {
       'att_type' => 'GES',
       'score_type' => 'coords'
   });

   push (@{$athash}, {
       'att_type' => 'GES',
       'score_type' => 'regions'
   });


   my $coordshash = {};
   my $regionshash = {};


   foreach my $asmbl_id ( @{$asmbllist} ) {
       
       foreach my $h ( @{$athash} ){
 
# 	   my $att_type   = $h->{'att_type'};
# 	   my $score_type = $h->{'score_type'};

# 	   $logger->debug("att_type '$att_type' score_type '$score_type'") if $logger->is_debug;

	   my $ret;

	   if ((defined($ntprok)) && ($ntprok == 1)){
	       $ret = $prism->gene_orf_score_data($asmbl_id, $db, 'NTORF', $h->{'att_type'}, $h->{'score_type'});
	   }
	   else{
	       $ret = $prism->gene_orf_score_data($asmbl_id, $db, 'ORF', $h->{'att_type'}, $h->{'score_type'});
	   }


	   foreach my $block ( @{$ret} ) {
	       
	       my $transcript = $db . '_' . $asmbl_id . '_' . $block->[1] . '_transcript';
	       
	       $transcripthash->{$transcript} = '';
	       
	       
	       if (($block->[2] eq 'coords')){
		   
		   if (defined($block->[3])){

		       $block->[3] = '0' if ($block->[3] =~ /^\s*$/);
		   
		       $coordshash->{$transcript} = $block->[3];
		   }
	       }
	       
	       if (($block->[2] eq 'regions' )){

		   if (defined($block->[3])){

		       $block->[3] = '0' if ($block->[3] =~ /^\s$/);
		   
		       $regionshash->{$transcript} = $block->[3];
		   }
	       }
	   }
       }
   }


   my $list;


  
   foreach my $transcript (sort keys %{$transcripthash} ) {

       my $load=0;
       my $tmparray;
       
       if (( exists $coordshash->{$transcript}) and (defined($coordshash->{$transcript}))){
	   

 	   push ( @{$rethash->{$transcript}->{'attributes'}}, {
	       'name'    => 'transmembrane_coords',
	       'content' => $coordshash->{$transcript}
	   });

       
# 	   push ( @{$tmparray}, { 'transmembrane_coords' => $coordshash->{$transcript} } );
# 	   $load++;
       }
       
       
       if (( exists $regionshash->{$transcript}) and (defined($regionshash->{$transcript}))){
	   

 	   push ( @{$rethash->{$transcript}->{'attributes'}}, {
	       'name'    => 'transmembrane_regions',
	       'content' => $regionshash->{$transcript}
	   });
	   
# 	   push ( @{$tmparray}, { 'transmembrane_regions' => $regionshash->{$transcript} } );
# 	   $load++;
#        }
       
       
       if (( exists $attholder->{$transcript}->{'LP'}) and (defined($attholder->{$transcript}->{'LP'}))){


 	   push ( @{$rethash->{$transcript}->{'attributes'}}, {
	       'name'    => 'lipo_membrane_protein',
	       'content' => $attholder->{$transcript}->{'LP'}
	   });
	   
# 	   push ( @{$tmparray}, { 'lipo_membrane_protein' => $attholder->{$transcript}->{'LP'} });
# 	   $load++;
	   
       }
       
       if (( exists $attholder->{$transcript}->{'OMP'}) and (defined($attholder->{$transcript}->{'OMP'}))){
	   

 	   push ( @{$rethash->{$transcript}->{'attributes'}}, {
	       'name'    => 'outer_membrane_protein',
	       'content' => $attholder->{$transcript}->{'OMP'}
	   });

# 	   push ( @{$tmparray}, { 'outer_membrane_protein' => $attholder->{$transcript}->{'OMP'}  });
# 	   $load++;
	   
       }
       
#        if ( $load > 0 ){
# 	   push (@ {$rethash->{$transcript}->{'attributelist'}}, $tmparray );
#        }
       
       }
   }
#        if ($load>0){
# 	   push (@ {$rethash->{$transcript}->{'attributelist'}}, $list );
#        }   
       
   
   return ($rethash);
       
}





#----------------------------------------------------------------------------------------
# create_ber_evidence_lookup()
#
#----------------------------------------------------------------------------------------
sub create_ber_evidence_lookup {

   my ($prism, $asmbllist, $db, $ntprok) = @_;
  
   my $rethash = {};

   #
   # Ah.  The invaluble v-hash!
   #
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

   my @feat_types = ('ORF');
   if ((defined($ntprok)) && ($ntprok == 1)){
       @feat_types = ('NTORF');
   }

   my $ber = 'BER';

   foreach my $asmbl_id ( @{$asmbllist} ) {
       
       foreach my $ev_type ('BER', 'AUTO-BER'){
	   
	   foreach my $feat_type ( @feat_types ){
	       
	       foreach my $score_type ('Pvalue', 'score', 'per_id', 'per_sim'){

		   my $ret = $prism->ber_evidence_data($asmbl_id, $db, $feat_type, $ev_type, $score_type);
		   
		   foreach my $block ( @{$ret} ){


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
		       
		       if ((defined($block->[3])) && ($block->[3] !~ /^\s+$/)){

			   if ($score_type eq 'Pvalue'){
			       $v->{$asmbl_id}->{$ber}->{$block->[1]}->{$block->[2]}->{$key}->{'runprob'} = $block->[3];
			   }
			   elsif ($score_type eq 'score'){
			       $v->{$asmbl_id}->{$ber}->{$block->[1]}->{$block->[2]}->{$key}->{'runscore'} = $block->[3];
			   }
			   elsif ($score_type eq 'per_id'){
			       $v->{$asmbl_id}->{$ber}->{$block->[1]}->{$block->[2]}->{$key}->{'percent_identity'} = $block->[3];
			   }
			   elsif ($score_type eq 'per_sim'){
			       $v->{$asmbl_id}->{$ber}->{$block->[1]}->{$block->[2]}->{$key}->{'percent_similarity'} = $block->[3];
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
       }
   }

   return $v;
}


#----------------------------------------------------------------------------------------
# create_hmm2_evidence_lookup()
#
#----------------------------------------------------------------------------------------
sub create_hmm2_evidence_lookup {


   my ($prism, $asmbllist, $db, $db_prefix, $ntprok) = @_;
  
   my $rethash = {};

   #
   # Ah.  The invaluble v-hash!
   #
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

   my @feat_types = ('ORF');
   if ((defined($ntprok)) && ($ntprok == 1)){
       @feat_types = ('NTORF');
   }
   

   foreach my $asmbl_id ( @{$asmbllist} ) {
       
       foreach my $ev_type ('HMM2'){
	   
	   foreach my $feat_type ( @feat_types ){
	       
	       foreach my $score_type ('e-value', 'score'){
		   
		   my $ret = $prism->hmm_evidence_data($asmbl_id, $db, $feat_type, $ev_type, $score_type);
		   
		   foreach my $block ( @{$ret} ){


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

		       if ($score_type eq 'e-value'){

			   $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'runprob'} = $block->[3];
		       }
		       elsif ($score_type eq 'score'){

			   $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'runscore'} = $block->[3];
		       }
		       else{
			   $logger->logdie("Unexpected score_type '$score_type'");
		       }
		   		       


		       $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'refpos'} = ( $block->[4] - 1 );

		       $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'runlength'} = ( $block->[5] - $block->[4] + 1 );

		       $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'refcomplement'} = 0;

		       $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'comppos'} = ( $block->[6] - 1 );

		       $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'comprunlength'} = ( $block->[7] - $block->[6] + 1 );

		       $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'compcomplement'} = 0;
		       
		   }
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


   my ($prism, $asmbllist, $db, $db_prefix, $ntprok) = @_;
  
   my $rethash = {};

   #
   # Ah.  The invaluble v-hash!
   #
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

   my @feat_types = ('ORF');
   if ((defined($ntprok)) && ($ntprok == 1)){
       @feat_types = ('NTORF');
   }
   

   foreach my $asmbl_id ( @{$asmbllist} ) {
       
       foreach my $ev_type ('COG accession'){
	   
	   foreach my $feat_type ( @feat_types ){
	       
	       my $ret = $prism->cog_evidence_data($asmbl_id, $db, $feat_type, $ev_type);
		   
	       foreach my $block ( @{$ret} ){
		   
		   
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
		   
		   
		   
		   
		   $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'refpos'} = ( $block->[3] - 1 );
		   
		   $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'runlength'} = ( $block->[4] - $block->[3] + 1 );
		   
		   $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'refcomplement'} = 0;
		   
		   $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'comppos'} = ( $block->[5] - 1 );
		   
		   $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'comprunlength'} = ( $block->[6] - $block->[5] + 1 );
		   
		   $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'compcomplement'} = 0;
		   
	       }
	   }
       }
   }


   return $v;
}# create_cog_evidence_lookup 


#----------------------------------------------------------------------------------------
# create_prosite_evidence_lookup()
#
#----------------------------------------------------------------------------------------
sub create_prosite_evidence_lookup {


   my ($prism, $asmbllist, $db, $db_prefix, $ntprok) = @_;
  
   my $rethash = {};

   #
   # Ah.  The invaluble v-hash!
   #
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

   my @feat_types = ('ORF');
   if ((defined($ntprok)) && ($ntprok == 1)){
       @feat_types = ('NTORF');
   }
   

   foreach my $asmbl_id ( @{$asmbllist} ) {
       
       foreach my $ev_type ('PROSITE'){
	   
	   foreach my $feat_type ( @feat_types ){
	       
	       foreach my $score_type ('hit'){
		   
		   my $ret = $prism->prosite_evidence_data($asmbl_id, $db, $feat_type, $ev_type, $score_type);
		   
		   foreach my $block ( @{$ret} ){


		       # 0 => asm_feature.asmbl_id
		       # 1 => evidence.feat_name
		       # 2 => evidence.accession
		       # 3 => feat_score.score
		       # 4 => evidence.rel_end5
		       # 5 => evidence.rel_end3
		       # 6 => evidence.m_lend
		       # 7 => evidence.m_rend
		       # 8 => evidence.hit

		       my $compseq = $block->[2];
		       if ($compseq =~ /^\d/){
			   # Found leading digit
			   $block->[2] = '_' . $block->[2];
		       }

		       my $key = $block->[1] . '_' . $block->[2] . '_' . $block->[4] . '_' . $block->[5] . '_' . $block->[6] . '_' . $block->[7];		       

		       if ($score_type eq 'hit'){
			   
			   $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'residues'} = $block->[3];
		       }
		       else{
			   $logger->logdie("Unexpected score_type '$score_type'");
		       }
		   		       


		       $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'refpos'} = ( $block->[4] - 1 );

		       $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'runlength'} = ( $block->[5] - $block->[4] + 1 );

		       $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'refcomplement'} = 0;

		       $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'comppos'} = ( $block->[6] - 1 );

		       $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'comprunlength'} = ( $block->[7] - $block->[6] + 1 );

		       $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'compcomplement'} = 0;
		       $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'runprob'} = 0;
		       $v->{$asmbl_id}->{$ev_type}->{$block->[1]}->{$block->[2]}->{$key}->{'runscore'} = 0;

		   }
	       }
	   }
       }
   }

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

# 		   #
# 		   # $block->[1] should contain the feat_name
# 		   #
# 		   my $cds = $db . '_' . $asmbl_id . '_' . $block->[1] . '_CDS';


# 		   my ($end5, $end3, $complement) = &coordinates($block->[], $block=>[]);

# 		   my $runlength = $end3 - $end5 + 1;
# 		   my $comprunlength = $block->[] - $block->[];

# 		   my $auto_annotate_toggle = 0;
# 		   $auto_annotate_toggle = 1 if ($ev_type eq 'BER');
		   
# 		   push ( @{$rethash->{$cds}}, {
# 		       'refseq'               => $cds,
# 		       'compseq'              => $block->[2],
# 		       'method'               => 'BER',
# 		       'runscore'             => $block->[3],
# 		       'runprob'              => $block->[3],
# 		       'score'                => $block->[3],
# 		       'refpos'               => $end5,
# 		       'runlength'            => $runlength,
# 		       'refcomplement'        => $complement,
# 		       'comppos'              => $block->[],
# 		       'comprunlength'        => $comprunlength,
# 		       'compcomplement'       => '0',
# 		       'auto_annotate_toggle' => $auto_annotate_toggle
# 		   });
# 	       }
# 	   }
#        }
#    }




#    my $athash;
#    push (@{$athash}, {
#        'att_type' => 'GES',
#        'score_type' => 'coords'
#    });

#    push (@{$athash}, {
#        'att_type' => 'GES',
#        'score_type' => 'regions'
#    });


#    my $coordshash = {};
#    my $regionshash = {};


#    foreach my $asmbl_id ( @{$asmbllist} ) {
       
#        foreach my $h ( @{$athash} ){
 
# 	   my $att_type   = $h->{'att_type'};
# 	   my $score_type = $h->{'score_type'};

# 	   $logger->debug("att_type '$att_type' score_type '$score_type'") if $logger->is_debug;

# 	   my $ret = $prism->gene_orf_score_data($asmbl_id, $db, 'ORF', $h->{'att_type'}, $h->{'score_type'});
	   
# 	   foreach my $block ( @{$ret} ) {
	       
# 	       my $transcript = $db . '_' . $asmbl_id . '_' . $block->[1] . '_transcript';
	       
# 	       $transcripthash->{$transcript} = '';
	       
	       
# 	       if (($block->[2] eq 'coords')){
		   
# 		   if (defined($block->[3])){

# 		       $block->[3] = '0' if ($block->[3] =~ /^\s*$/);
		   
# 		       $coordshash->{$transcript} = $block->[3];
# 		   }
# 	       }
	       
# 	       if (($block->[2] eq 'regions' )){

# 		   if (defined($block->[3])){

# 		       $block->[3] = '0' if ($block->[3] =~ /^\s$/);
		   
# 		       $regionshash->{$transcript} = $block->[3];
# 		   }
# 	       }
# 	   }
#        }
#    }


#    my $list;


  
#    foreach my $transcript (sort keys %{$transcripthash} ) {

#        my $load=0;
#        my $tmparray;
       
#        if (( exists $coordshash->{$transcript}) and (defined($coordshash->{$transcript}))){
	   

#  	   push ( @{$rethash->{$transcript}->{'attributes'}}, {
# 	       'name'    => 'transmembrane_coords',
# 	       'content' => $coordshash->{$transcript}
# 	   });

       
# 	   push ( @{$tmparray}, { 'transmembrane_coords' => $coordshash->{$transcript} } );
# 	   $load++;
#        }
       
       
#        if (( exists $regionshash->{$transcript}) and (defined($regionshash->{$transcript}))){
	   

#  	   push ( @{$rethash->{$transcript}->{'attributes'}}, {
# 	       'name'    => 'transmembrane_regions',
# 	       'content' => $regionshash->{$transcript}
# 	   });
	   
# 	   push ( @{$tmparray}, { 'transmembrane_regions' => $regionshash->{$transcript} } );
# 	   $load++;
#        }
       
       
#        if (( exists $attholder->{$transcript}->{'LP'}) and (defined($attholder->{$transcript}->{'LP'}))){


#  	   push ( @{$rethash->{$transcript}->{'attributes'}}, {
# 	       'name'    => 'lipo_membrane_protein',
# 	       'content' => $attholder->{$transcript}->{'LP'}
# 	   });
	   
# 	   push ( @{$tmparray}, { 'lipo_membrane_protein' => $attholder->{$transcript}->{'LP'} });
# 	   $load++;
	   
#        }
       
#        if (( exists $attholder->{$transcript}->{'OMP'}) and (defined($attholder->{$transcript}->{'OMP'}))){
	   

#  	   push ( @{$rethash->{$transcript}->{'attributes'}}, {
# 	       'name'    => 'outer_membrane_protein',
# 	       'content' => $attholder->{$transcript}->{'OMP'}
# 	   });

# 	   push ( @{$tmparray}, { 'outer_membrane_protein' => $attholder->{$transcript}->{'OMP'}  });
# 	   $load++;
	   
#        }
       
#        if ( $load > 0 ){
# 	   push (@ {$rethash->{$transcript}->{'attributelist'}}, $tmparray );
#        }
       
#        }
#    }
#        if ($load>0){
# 	   push (@ {$rethash->{$transcript}->{'attributelist'}}, $list );
#        }   
       
   
#    return ($rethash);
       
# }






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


    #
    # Retrieve the organism data via the Prism API method
    # in (shared/Prism.pm)
    #
    my $orgdata = $prism->organism_data($database);


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

    print STDERR "SAMPLE USAGE:  $0 -D database -P password -U username [-M mode] [-a asmbl_list|ALL|NONE] [-f asmbl_file] [-d debug_level] [-F fastadir] [-h] [-l log4perl] [-m] [-n ntprok] [-o outdir]\n".
    " -D|--database           = Source database name\n".
    " -P|--password           = login password for database\n".
    " -U|--username           = login username for database\n".
    " -M|--mode               = 1=gene model 2=gene model and computational evidence 3=computational evidence\n".
    " -a|--asmbl_list         = Optional - comma-separated (no spaces) list of assembly idenitifiers or ALL or NONE (must specify asmbl_file)\n".
    " -f|--asmbl_file         = Optional - input file containing new-line separated list of asmbl_ids\n".
    " -d|--debug_level        = Optional - Coati::Logger log4perl logging level (Default is WARN)\n".
    " -F|--fastadir           = Optional - output fasta repository (Default is current working directory)\n".
    " -h|--help               = This help message\n".
    " -l|--log4perl           = Optional - Log4perl output filename (Default is /tmp/legacy2bsml.pl.database_\$database.asmbl_id_\$asmbl_id.log)\n".
    " -m|--man                = Display the pod2usage pages for this script\n".
    " -n|--ntprok             = Optional - to indicate processing ntprok organism (Default is -n=0 NOT ntprok)\n".
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
    
    my $organism_elem = $doc->createAndAddOrganism( 
						    'genome'  => $genome_elem,
						    'genus'   => $genus,  
						    'species' => $species,
						    );
    if (!defined($organism_elem)){
	$logger->logdie("Could not create <Organism> element object reference") if (!defined($organism_elem));
    }
    else{
	
	#
	# Add attributes!
	#
	if ((exists $orgdata->{'file_moniker'}) && (defined($orgdata->{'file_moniker'}))){

	    my $attribute_elem = $doc->createAndAddBsmlAttribute(
								 $organism_elem,
								 'abbreviation',
								 "$orgdata->{'file_moniker'}"
								 );
	    
	    $logger->logdie("Could not create <Attribute> for the name 'abbreviation' content '$orgdata->{'file_moniker'}'") if (!defined($attribute_elem));
	}

	if ((exists $orgdata->{'gram_stain'}) && (defined($orgdata->{'gram_stain'}))){

	    my $attribute_elem = $doc->createAndAddBsmlAttribute(
								 $organism_elem,
								 'gram_stain',
								 "$orgdata->{'gram_stain'}"
								 );
	    
	    $logger->logdie("Could not create <Attribute> for the name 'gram_stain' content '$orgdata->{'gram_stain'}'") if (!defined($attribute_elem));
	}


	if ((exists $orgdata->{'genetic_code'}) && (defined($orgdata->{'genetic_code'}))){

	    my $attribute_elem = $doc->createAndAddBsmlAttribute(
								 $organism_elem,
								 'genetic_code',
								 "$orgdata->{'genetic_code'}"
								 );
	    
	    $logger->logdie("Could not create <Attribute> for the name 'genetic_code' content '$orgdata->{'genetic_code'}'") if (!defined($attribute_elem));
	}

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
    my $asmbl_id = $param{'asmbl_id'};
    my $asmbl_uniquename = $param{'uniquename'};
    my $asmlen = $param{'length'};
    my $topology = $param{'topology'};
    my $doc = $param{'doc'};
    my $class = $param{'class'};
    my $fastadir = $param{'fastadir'};
    my $database = $param{'database'};
    my $prefix = $param{'prefix'};
    my $molecular_name = $param{'name'};
    my $molecule_type = $param{'molecule_type'};
   
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


    if (defined($molecule_type)){
	$molecule_type = lc($molecule_type);

	my $attribute_elem = $doc->createAndAddBsmlAttribute(
							     $assembly_sequence_elem,
							     'molecule_type',
							     "$molecule_type"
							     );
	
	$logger->logdie("Could not create <Attribute> for the '$asmbl_uniquename' assembly's molecule_type '$molecule_type'") if (!defined($attribute_elem));
    }


    if (defined($molecular_name)){

	$molecular_name = lc($molecular_name);
	
	my $attribute_elem = $doc->createAndAddBsmlAttribute(
							     $assembly_sequence_elem,
							     'molecule_name',
							     "$molecular_name"
							     );
	
	$logger->logdie("Could not create <Attribute> for the '$asmbl_uniquename' assembly's molecular name '$molecular_name'") if (!defined($attribute_elem));

	
	my $arr1;

	if ($molecular_name =~ /pseudomolecule/){
	 
 	    push( @{$arr1}, { name    => 'SO',
			      content => 'supercontig'}
		  );

	    $assembly_sequence_elem->addBsmlAttributeList($arr1);
	}
	elsif ($molecular_name =~ /pseudo/){
	    
	    $logger->warn("molecular_name '$molecular_name' was like pseudo.  Note that $0 shall assign molecular_name = 'supercontig'");

	    push( @{$arr1}, { name    => 'SO',
			      content => 'supercontig'}
		  );
	    
	    $assembly_sequence_elem->addBsmlAttributeList($arr1);
	}
	elsif ($molecular_name =~ /plasmid/){

	    push( @{$arr1}, { name    => 'SO',
			      content => 'plasmid'});

	    $assembly_sequence_elem->addBsmlAttributeList($arr1);
	}
	elsif ($molecular_name =~  /chromosome/){

	    push ( @{$arr1}, { name    => 'SO',
			       content => 'chromosome'});

	    $assembly_sequence_elem->addBsmlAttributeList($arr1);
	}
	else{

	    $logger->warn("Unrecognized molecular name was retrieved from asmbl_data.name '$molecular_name'.  Setting default value 'assembly'");

	    push ( @{$arr1}, { name    => 'SO',
			       content => 'assembly'});

	    $assembly_sequence_elem->addBsmlAttributeList($arr1);
	    
	}
    }
    elsif ($param{'euk'} == 1){
	
	$logger->warn("Since dealing with euk, storing setting molecular_name = 'assembly'");
	
	my $arr1;
	
	push ( @{$arr1}, { name    => 'SO',
			   content => 'assembly'});
	
	$assembly_sequence_elem->addBsmlAttributeList($arr1);
	
    }
    else{
	$logger->logdie("molecular name was not defined for asmbl_id '$asmbl_id'");
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


    $logger->debug("Finished creating all assembly <Sequence> related BSML elements (i.e. <Seq-data-import>, <Cross-reference>, <Attribute>, <Attribute-list>...") if $logger->is_debug;
    
    return $assembly_sequence_elem;
}

#-------------------------------------------------------------------------------------------------------------------------------------------
# subfeatures to be stored as <Sequence> elements are:
# 1) protein
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
    my $map        = $p{'map'};
    my $sequence_subfeature_hash = $p{'sequence_subfeature_hash'};
    my $sequence_hash = $p{'sequence_hash'};
    my $asmbl_id      = $p{'asmbl_id'};


    $logger->logdie("database was not defined") if (!defined($database));
    $logger->logdie("prefix was not defined") if (!defined($prefix));
    $logger->logdie("fastadir was not defined") if (!defined($fastadir));
    $logger->logdie("doc was not defined") if (!defined($doc));
    $logger->logdie("map was not defined") if (!defined($map));
    $logger->logdie("sequence_subfeature_hash was not defined") if (!defined($sequence_subfeature_hash));
    $logger->logdie("asmbl_id was not defined") if (!defined($asmbl_id));


    my $seq_id = $database . '_' . $asmbl_id . '_' . $sequence_subfeature_hash->{'feat_name'} . $map->{$sequence_subfeature_hash->{'feat_type'}}->{'suffix'};

    $logger->debug("Playing with sequence '$seq_id'") if $logger->is_debug;

    
    #
    # Create <Sequence> element object for the subfeature as a sequence
    #
    my $sequence_elem = $doc->createAndAddSequence(
						   $seq_id,                                                       # id
						   undef,                                                         # title
						   $sequence_subfeature_hash->{'seqlen'},                         # length
						   $map->{$sequence_subfeature_hash->{'feat_type'}}->{'moltype'}, # molecule
						   $map->{$sequence_subfeature_hash->{'feat_type'}}->{'class'}    # class
						   );

    if (!defined($sequence_elem)){
	$logger->logdie("Could not create <Sequence> for the sequence '$seq_id'");
    }  

    $logger->debug("Storing subfeature '$seq_id' sequence in multi-fasta hash") if $logger->is_debug;


    my $seqclass = $map->{$sequence_subfeature_hash->{'feat_type'}}->{'class'};

    my $array = [$seq_id, $sequence_subfeature_hash->{'sequence'}];
    push ( @{$fastasequences->{$asmbl_id}->{$seqclass}}, $array);
   


    #
    # Store the sequence element object reference in the sequence hash
    #
    $logger->debug("Storing '$seq_id' on sequence_hash") if $logger->is_debug();
    $sequence_hash->{$seq_id} = $sequence_elem;


    
    #
    # Create <Seq-data-import> element object for the subfeature as a sequence
    #
    my $source = $fastadir .'/'. $database . '_' . $asmbl_id . '_' . $seqclass .'.fsa';
    
    my $seq_data_import_elem = $doc->createAndAddSeqDataImport(
							       $sequence_elem,            # <Sequence> element object reference
							       'fasta',                   # format
							       $source,                   # source
							       undef,                    # id
							       $seq_id                    # identifier
							       );
    if (!defined($seq_data_import_elem)){
	$logger->logdie("seq_data_import_elem was not defined for sequence '$seq_id'");
    }

    #
    # Store the <Seq-data-import> element object reference for downstream linking...
    # <Link>...
    #
    $seq_data_import_hash->{$seq_id} = $seq_data_import_elem;
    
    $logger->debug("Storing <Seq-data-import> element object reference for sequence '$seq_id'") if $logger->is_debug;
    $seq_data_import_ctr++;


    #
    # Create <Cross-reference> element object for the subfeature as a sequence
    #
#     my $xref_elem = $doc->createAndAddCrossReference(
# 						     'parent'          => $sequence_elem,
# #						     'id'              => $doc->{'xrefctr'}++,
# 						     'database'        => $prefix,
# 						     'identifier'      => $sequence_subfeature_hash->{'feat_name'},
# 						     'identifier-type' => 'feat_name'
# 						     );
#     $logger->logdie("Could not create <Cross-reference> for the subfeature-as-a-sequence '$seq_id'") if (!defined($xref_elem));

}




#-----------------------------------------------------------------------------------------
#
# Process each assembly's Gene Model subfeatures:
# 1) gene
# 2) transcript
# 3) CDS
# 4) protein
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

    $logger->debug("Processing assembly '$asmbl_id' feat_name '$orfhash->{'feat_name'}'...") if $logger->is_debug;

   
    my $gene_feature_group_elem;


    foreach my $class ('gene', 'transcript', 'CDS', 'exon', 'protein'){


	#
	# Whether locus or feat_name (prepared for us upstream), create uniquename
	#
	my $uniquename = $database . '_' .$asmbl_id . '_' . $orfhash->{'feat_name'} . '_' . $class;


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
#	my $sequence   = $orfhash->{'sequence'};
#	my $seqlen     = length($sequence);


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
	# Store the <Feature> element object reference for transcripts and proteins
	#
	if ($class eq 'transcript'){
	    #
	    # Store reference using the feat_name not the locus
	    #
	    my $uniquename = $database . '_' .$asmbl_id . '_' . $orfhash->{'feat_name'} . '_' . $class;
	    $transcript_feature_hash->{$uniquename} = $feature_elem;
	}
	if ($class eq 'protein') {
	    #
	    # Store reference using the feat_name not the locus
	    #

	    $protein_feat_name_to_locus->{$orfhash->{'feat_name'}} = $uniquename;
	    
	    my $uniquename1 = $database . '_' .$asmbl_id . '_' . $orfhash->{'feat_name'} . '_' . $class;
	    $protein_feature_hash->{$uniquename1} = $feature_elem;
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
	    
	    
	    if (defined($data->{$locustype})){
		
		$logger->debug("$locustype was defined therefore attempting to insert <Cross-reference> element object for '$uniquename' $locustype '$data->{$locustype}'") if $logger->is_debug;
		
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
								 'database'        => $prefix,
								 'identifier'      => $val,
								 'identifier-type' => "$key"
								 );
		if (!defined($xref_elem)){
		    $logger->logdie("Could not create <Cross-reference> for key '$key' val '$val'");
		}								 
	    }
	}






	if (($class eq 'protein') or ($class eq 'CDS')){

	    #
	    # Create <Link> to link protein or CDS <Feature> element to the protein_seq or CDS_seq <Sequence> element
	    #
	    my $sequence_key = $database . '_' .$asmbl_id . '_' . $orfhash->{'feat_name'} . '_' . $class . '_seq';
	    
	    $logger->debug("Attempting to insert <Link> to <Seq-data-import> for '$sequence_key'") if $logger->is_debug;


	    if ((exists ($seq_data_import_hash->{$sequence_key})) and (defined($seq_data_import_hash->{$sequence_key}))){

#		next if $sequence_key eq 'gba_6615_ORF07042_protein_seq';
#		$logger->fatal("Unable to add <Link> for <Seq-data-import>... skipping for now...");
# 		next;
 		my $link_elem = $doc->createAndAddLink(
# 						       $seq_data_import_hash->{$sequence_key},  # <Seq-data-import> element reference
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
		# Note that it is acceptable for some ORFs to not have an associated protein translation
		#
		if ($class eq 'CDS') {
		    $logger->logdie("<Seq-data-import> does not exist for sequence '$sequence_key'");
		}
	    }
	}

	
	#
	# Create <Feature-group-member> element object for this Gene Model subfeature
	#
	my $feature_group_member_elem = $doc->createAndAddFeatureGroupMember(
									     $gene_feature_group_elem,  # <Feature-group> element object reference
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
# 4) protein
# 5) exon
#
#-----------------------------------------------------------------------------------------
sub store_euk_gene_model_subfeatures {

    my %param = @_;
    my $datahash           = $param{'datahash'};
    my $asmbl_id           = $param{'asmbl_id'};
    my $feature_table_elem = $param{'feature_table_elem'};
    my $doc                = $param{'doc'};
    my $prefix             = $param{'prefix'};
    my $database           = $param{'database'};
    my $assembly_sequence_elem = $param{'assembly_sequence_elem'};
    my $accession_hash     = $param{'accession_lookup'};
    my $gene_group_lookup  = $param{'gene_group_lookup'};

    $logger->debug("Processing assembly '$asmbl_id'") if $logger->is_debug;

   
    my $transcripts    = $datahash->{'transcripts'};
    my $coding_regions = $datahash->{'coding_regions'};
    my $exons          = $datahash->{'exons'};
#    my $count          = $datahash->{'count'};


    my $locuslookup = {};
    my $role_id_lookup = {};


    for (my $i=0; $i < $transcripts->{'count'}; $i++){
	
	
	my $feat_name; 
	my $role_id_array;
	
	if (! exists $transcripts->{$i}->{'feat_name'}){
	    $logger->logdie("feat_name does not exist i = $i");
	}
	else {
	    $feat_name = $transcripts->{$i}->{'feat_name'};
	    $logger->logdie("feat_name was not defined") if (!defined($feat_name));
	    
	    $role_id_array  = $role_id_lookup->{$feat_name}; 
	}
	
		
	my $gene_feature_group_elem = &store_euk_subfeature(
							    'data'               => $transcripts->{$i},
							    'class'              => 'gene',
							    'assembly_seq'       => $assembly_sequence_elem,
							    'gene_group_lookup'  => $gene_group_lookup,
							    'asmbl_id'           => $asmbl_id,
							    'prefix'             => $prefix,
							    'doc'                => $doc,
							    'feature_table_elem' => $feature_table_elem
							    );
	
	&store_euk_subfeature(
			      'data'                    => $transcripts->{$i},
			      'class'                   => 'transcript',
			      'assembly_seq'            => $assembly_sequence_elem,
			      'gene_group_lookup'       => $gene_group_lookup,
			      'asmbl_id'                => $asmbl_id,
			      'gene_feature_group_elem' => $gene_feature_group_elem,
			      'prefix'                  => $prefix,
			      'doc'                     => $doc,
			      'feature_table_elem'      => $feature_table_elem
			      );

	
	if ((exists $coding_regions->{$transcripts->{$i}->{'feat_name'}}) && (defined($coding_regions->{$transcripts->{$i}->{'feat_name'}}))){

	    foreach my $model ( @{$coding_regions->{$transcripts->{$i}->{'feat_name'}}} ){
		
		&store_euk_subfeature(
				      'data'                    => $model,
				      'class'                   => 'CDS',
				      'assembly_seq'            => $assembly_sequence_elem,
				      'gene_group_lookup'       => $gene_group_lookup,
				      'asmbl_id'                => $asmbl_id,
				      'gene_feature_group_elem' => $gene_feature_group_elem,
				      'prefix'                  => $prefix,
				      'doc'                     => $doc,
				      'feature_table_elem'      => $feature_table_elem
				      );


		my $protein_feat_name = $model->{'feat_name'};
		$protein_feat_name =~ s/\.m/\.p/;

		&store_euk_subfeature(
				       'feat_name'               => $protein_feat_name,
				       'data'                    => $model,
				       'class'                   => 'protein',
				       'assembly_seq'            => $assembly_sequence_elem,
				       'gene_group_lookup'       => $gene_group_lookup,
				       'asmbl_id'                => $asmbl_id,
				       'gene_feature_group_elem' => $gene_feature_group_elem,
				       'prefix'                  => $prefix,
				       'doc'                     => $doc,
				       'feature_table_elem'      => $feature_table_elem
				       );
		
		
		if ((exists $exons->{$model->{'feat_name'}}) && (defined($exons->{$model->{'feat_name'}}))){
		    
		    foreach my $exon ( @{$exons->{$model->{'feat_name'}}} ) {
			
			
			&store_euk_subfeature(
					      'data'                    => $exon,
					      'class'                   => 'exon',
					      'assembly_seq'            => $assembly_sequence_elem,
					      'gene_group_lookup'       => $gene_group_lookup,
					      'asmbl_id'                => $asmbl_id,
					      'gene_feature_group_elem' => $gene_feature_group_elem,
					      'prefix'                  => $prefix,
					      'doc'                     => $doc,
					      'feature_table_elem'      => $feature_table_elem				       
					  );
		    }
		}
		else{
		    $logger->fatal("No exons associated to the transcript '$model->{'feat_name'}'");
		}    
	    }			   
	}
	else{
	    $logger->fatal("No coding_regions associated to the transcript '$transcripts->{$i}->{'feat_name'}'");
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


    if (!defined($feat_name)){
	$feat_name = $data->{'feat_name'};
    }

    my $uniquename = $database . '_' . $asmbl_id . '_' . $feat_name . '_' . $class;


    if ($class eq 'gene'){
	
	#
	# The <Feature-group> element will be based on the gene
	#
	$gene_feature_group_elem = $doc->createAndAddFeatureGroup(
								  $assembly_sequence_elem,  # <Sequence> element object reference
								  undef,                    # id
								  "$uniquename"             # groupset
								  );  
	
	$logger->logdie("Could not create <Feature-group> element object reference for uniquename '$uniquename'") if (!defined($gene_feature_group_elem));
	
	    
	    $gene_group_lookup->{$feat_name} = $gene_feature_group_elem;
	        
    }

    my $complement = $data->{'complement'};
    my $fmin       = $data->{'end5'};
    my $fmax       = $data->{'end3'};


    my $feature_elem;

    if ($class eq 'protein'){

	$feature_elem = $doc->createAndAddFeatureWithLoc(
							 $feature_table_elem,      # <Feature-table> element object reference
							 "$uniquename",            # id
							 undef,                    # title
							 $class,                   # class
							 undef,                    # comment
							 undef                     # displayAuto
							 );
	if (!defined($feature_elem)){
	    $logger->logdie("Could not create <Feature> element object reference for '$uniquename'"); 
	}
    }
    else{

 
	#
	# Create <Feature> element object
	#
	$feature_elem = $doc->createAndAddFeatureWithLoc(
							 $feature_table_elem,      # <Feature-table> element object reference
							 "$uniquename",            # id
							 undef,                    # title
							 $class,                   # class
							 undef,                    # comment
							 undef,                    # displayAuto
							 $fmin,                    # start
							 $fmax,                    # stop
							 $complement               # complement
							 );
	if (!defined($feature_elem)){
	    $logger->logdie("Could not create <Feature> element object reference for '$uniquename'"); 
	}
    }
    
    
    #
    # Store the <Feature> element object reference for transcripts and proteins
    #
    if ($class eq 'transcript'){
	#
	# Store reference using the feat_name not the locus
	#
	my $uniquename = $database . '_' .$asmbl_id . '_' . $data->{'feat_name'} . '_' . $class;
	$transcript_feature_hash->{$uniquename} = $feature_elem;
    }


    if ($class eq 'protein') {
	#
	# Store reference using the feat_name not the locus
	#
	
	$protein_feat_name_to_locus->{$data->{'feat_name'}} = $uniquename;
	
	my $uniquename1 = $database . '_' .$asmbl_id . '_' . $data->{'feat_name'} . '_' . $class;
	$protein_feature_hash->{$uniquename1} = $feature_elem;
    }


    #
    # Create <Cross-reference> element object for the feat_name
    #
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
	

    foreach my $locustype ('locus', 'display_locus', 'alt_locus'){
	
	
	if (defined($data->{$locustype})){
	    
	    $logger->debug("$locustype was defined therefore attempting to insert <Cross-reference> element object for '$uniquename' $locustype '$data->{$locustype}'") if $logger->is_debug;
	    
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


    if (($class eq 'protein') or ($class eq 'CDS')){
	
	#
	# Create <Link> to link protein or CDS <Feature> element to the protein_seq or CDS_seq <Sequence> element
	#
	my $sequence_key = $database . '_' .$asmbl_id . '_' . $data->{'feat_name'} . '_' . $class . '_seq';
	
	$logger->debug("Attempting to insert <Link> to <Seq-data-import> for '$sequence_key'") if $logger->is_debug;
	
	
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
	    # Note that it is acceptable for some ORFs to not have an associated protein translation
	    #
	    if ($class eq 'CDS') {

		$logger->logdie("<Seq-data-import> does not exist for sequence '$sequence_key'");
	    }
	}
    }

    
    #
    # Create <Feature-group-member> element object for this Gene Model subfeature
    #
    my $feature_group_member_elem = $doc->createAndAddFeatureGroupMember(
									 $gene_feature_group_elem,  # <Feature-group> element object reference
									 $uniquename,          # featref
									 $class,               # feattype
									 undef,                # grouptype
									 undef,                # cdata
									 ); 
    if (!defined($feature_group_member_elem)){
	$logger->logdie("Could not create <Feature-group-member> element object reference for gene model subfeature '$uniquename'");
    }

    return $gene_feature_group_elem;
}






#--------------------------------------------------------------------------------------------------------------
# Store the following RNA subfeatures as <Feature> elements:
# 1) tRNA
# 2) rRNA
# 3) sRNA
# 4) ncRNA
#--------------------------------------------------------------------------------------------------------------
sub store_rna_subfeatures {

    my %p = @_;

    my $rna      = $p{'rna'};
    my $asmbl_id = $p{'asmbl_id'};
    my $feature_table_elem = $p{'feature_table_elem'};
    my $doc      = $p{'doc'};
    my $database = $p{'database'};
    my $prefix   = $p{'prefix'};
 
 	    
    my $uniquename = $database . '_' . $asmbl_id . '_' . $rna->{'feat_name'} . $map->{$rna->{'feat_type'}}->{'suffix'} ;
    
    my $class = $map->{$rna->{'feat_type'}}->{'class'};
    
    $logger->debug("Processing class '$class' '$uniquename'") if $logger->is_debug;


    #
    # Prep the <Interval-loc> data
    #
    my $fmin       = $rna->{'end5'};
    my $fmax       = $rna->{'end3'};
    my $complement = $rna->{'complement'};
    
    
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
	$logger->logdie("Could not create <Feature> element object reference for rna type '$rna->{'feat_type'}' uniquename '$uniquename'"); 
    }
    
    

    foreach my $lilattr ('com_name', 'gene_symbol', 'public_comment', 'anti-codon'){

	if ((exists $rna->{$lilattr}) && (defined($rna->{$lilattr}))){
	    
	    #
	    # Create <Attribute> element object reference for the RNA's ident.com_name
	    #
	    my $attribute_elem = $doc->createAndAddBsmlAttribute(
								 $feature_elem,      # <Feature> element object reference
								 "$lilattr",         # name
								 "$rna->{$lilattr}"  # content
								 );
	    
	    $logger->logdie("Could not create <Attribute> element object reference for the RNA's '$uniquename' $lilattr '$rna->{$lilattr}'") if (!defined($attribute_elem));
	}
    }


    
    #
    # Create <Cross-reference> element object for the RNA
    #
    my $xref_elem = $doc->createAndAddCrossReference(
						     'parent'          => $feature_elem,
						     'id'              => $doc->{'xrefctr'}++,
						     'database'        => $prefix,
						     'identifier'      => $rna->{'feat_name'},
						     'identifier-type' => 'feat_name'
						     );
    
    $logger->logdie("Could not create a <Cross-reference> element object reference for RNA type '$rna->{'feat_type'}' identifier '$rna->{'feat_name'}' uniquename '$uniquename'") if (!defined($xref_elem));


    #
    # Create <Cross-reference> element object for the RNA with //Cross-reference/@identifier = uc(legacy database name) . '_' . feat_name
    #
    my $rnaidentifier = uc($database) . '_' . $rna->{'feat_name'};
    my $xref_elem2 = $doc->createAndAddCrossReference(
						     'parent'          => $feature_elem,
						     'id'              => $doc->{'xrefctr'}++,
						     'database'        => $prefix,
						     'identifier'      => $rnaidentifier,
						     'identifier-type' => 'database_feat_name'
						     );
    
    $logger->logdie("Could not create a <Cross-reference> element object reference for RNA type '$rna->{'feat_type'}' identifier '$rnaidentifier' uniquename '$uniquename'") if (!defined($xref_elem2));



    #
    # Create <Link> to link RNA's <Feature> element to the RNA's <Sequence> element
    #
    my $seq_feat_type;
    if ($rna->{'feat_type'} =~ /^(.+)_feature$/){
	$seq_feat_type = $1;
    }
#    my $uniquename_seq = $database . '_' . $asmbl_id . '_' . $rna->{'feat_name'} . '_' . $map->{$rna->{'feat_type'}}->{'suffix'} . '_seq';
    my $uniquename_seq = $database . '_' . $asmbl_id . '_' . $rna->{'feat_name'} . $map->{$seq_feat_type}->{'suffix'};
    
    $logger->debug("Attempting to insert <Link> for <Seq-data-import> for rna '$uniquename_seq'") if $logger->is_debug;

    my $link_elem = $doc->createAndAddLink(
#					   $seq_data_import_hash->{$uniquename_seq},  # <Seq-data-import> element object reference
					   $feature_elem,
					   'sequence',                                # rel
					   "#$uniquename_seq"                         # href
					   );
    if (!defined($link_elem)){
	$logger->logdie("Could not create a 'sequence' <Link> element for <Feature> rna type '$rna->{'feat_type'}' uniquename '$uniquename' to rna <Sequence> '$uniquename_seq'");
    }

}	    



#---------------------------------------------------------------------------------------
# Signal peptide encoding
#
#
#---------------------------------------------------------------------------------------
sub store_peptide_encodings {

    my %p        = @_;
    my $database = $p{'database'};
    my $doc      = $p{'doc'};
    my $asmbl_id = $p{'asmbl_id'};
    my $prefix   = $p{'prefix'};
    my $peptide  = $p{'peptide'};
    my $peptide_feat_name = $p{'peptide_feat_name'};
    my $feature_table_elem = $p{'feature_table_elem'};   # Assembly <Sequence> element's <Feature-table> element object reference
    my $assembly_sequence_elem = $p{'assembly_sequence_elem'};
    my $sequence_hash = $p{'sequence_hash'};

    
#    print Dumper $peptide;die;

    my $uniquename = $database . '_' . $asmbl_id . '_' . $peptide_feat_name . '_signal_peptide';
#    my $protein_feature_uniquename = $database . '_' . $asmbl_id . '_' . $peptide_feat_name . '_protein';
    my $protein_sequence_uniquename = $database . '_' . $asmbl_id . '_' . $peptide_feat_name . '_protein_seq';



    $logger->debug("Processing peptide '$uniquename'") if $logger->is_debug;


    my $protein_sequence_elem;


#     if (( exists ($sequence_hash->{$protein_sequence_uniquename})) and (defined($sequence_hash->{$protein_sequence_uniquename})) ){
# 	$protein_sequence_elem = $sequence_hash->{$protein_sequence_uniquename};


# 	#
# 	# Create a new <Feature-table> element to be nested under the protein <Sequence>
# 	#
# 	$feature_table_elem = $doc->createAndAddFeatureTable($protein_sequence_elem);
	
# 	$logger->logdie("Could not create <Feature-table> element object reference") if (!defined($feature_table_elem));
	

#     }
#     else{
# 	#
# 	# There does not exist a protein <Sequence> to which this signal_peptide can be associated.
# 	# Therefore, will simply store this signal_peptide <Feature> as a free-floating feature beneath the assembly <Sequence> element's <Feature-table>
# 	#
# 	$logger->warn("Could not retrieve <Sequence> element object reference for protein '$protein_sequence_uniquename' related to signal_peptide '$uniquename'.  Therefore will store this signal_peptide <Feature> under the assembly <Feature-table> element");

#     }


    #
    # <Feature-table> element object reference could belong to the assembly's <Sequence> (default) or the protein's <Sequence>
    #
    my $feature_elem = $doc->createAndAddFeature(
						 $feature_table_elem,   # <Feature-table> element object reference
						 $uniquename,           # id
						 undef,                 # title
						 'signal_peptide'       # class
						 );


    $logger->logdie("Could not create <Feature> element object reference for peptide_signal '$uniquename'") if (!defined($feature_elem));

    $logger->debug("Inserted <Feature> for peptide '$uniquename'") if $logger->is_debug;

    my $xref_elem = $doc->createAndAddCrossReference(
						     'parent'          => $feature_elem,
						     'id'              => $doc->{'xrefctr'}++,
						     'database'        => $prefix,
						     'identifier'      => $peptide_feat_name,
						     'identifier-type' => 'feat_name'
						     );
    
    $logger->logdie("Could not create a <Cross-reference> element object reference for signal peptide uniquename '$uniquename'") if (!defined($xref_elem));
    $logger->debug("Inserted <Cross-reference> for peptide '$uniquename'") if $logger->is_debug;



    foreach my $attribute_name (sort keys %{$peptide} ) {

	my $attribute_elem = $doc->createAndAddBsmlAttribute(
							     $feature_elem,                 # <Feature> element object reference
							     $attribute_name,               # name
							     $peptide->{$attribute_name}    # content
							     );
	
	$logger->logdie("Could not create <Attribute> element object reference for the peptide signal's attribute name '$attribute_name' content '$peptide->{$attribute_name}'") if (!defined($attribute_elem));
    }

    
    #
    # The <Feature-group> elements for the signal_peptide will always be nested below the assembly <Sequence> element
    #
    my $peptide_feature_group_elem = $doc->createAndAddFeatureGroup(
								    $assembly_sequence_elem,  # <Sequence> element object reference
								    undef,                    # id
								    $uniquename               # groupset
								    );  
    
    if (!defined($peptide_feature_group_elem)){
	$logger->logdie("Could not create <Feature-group> element object reference for uniquename '$uniquename'") 
    }
    else{
	
	my $peptide_feature_group_member_elem = $doc->createAndAddFeatureGroupMember(
										     $peptide_feature_group_elem,  # <Feature-group> element object reference
										     $uniquename,          # featref
										     'signal_peptide',     # feattype
										     undef,                # grouptype
										     undef,                # cdata
										     ); 
	if (!defined($peptide_feature_group_member_elem)){
	    $logger->logdie("Could not create <Feature-group-member> element object reference for signal_peptide '$uniquename'");
	}

	
	my $protein_feature_uniquename = $protein_feat_name_to_locus->{$peptide_feat_name};

	$logger->logdie("protein_feature_uniquename was not defined for signal_peptide feat_name '$peptide_feat_name'") if (!defined($protein_feature_uniquename));

	my $protein_feature_group_member_elem = $doc->createAndAddFeatureGroupMember(
										     $peptide_feature_group_elem,  # <Feature-group> element object reference
										     $protein_feature_uniquename,  # featref
										     'protein',                    # feattype
										     undef,                        # grouptype
										     undef,                        # cdata
										     ); 
	if (!defined($protein_feature_group_member_elem)){
	    $logger->logdie("Could not create <Feature-group-member> element object reference for signal_peptide '$uniquename' object's protein '$protein_feature_uniquename'");
	}
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


    my $uniquename = $database . '_' . $asmbl_id . '_' . $ribo->{'feat_name'} . '_ribosome_entry_site';


    $logger->debug("Processing ribosome '$uniquename'") if $logger->is_debug;


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
    

    my $uniquename_seq = $database . '_' . $asmbl_id . '_' . $ribo->{'feat_name'} . '_ribosome_entry_site_seq';

    $logger->debug("Attempting to insert <Link> for <Seq-data-import> for ribosome '$uniquename_seq'") if $logger->is_debug;

    my $sequence_link_elem = $doc->createAndAddLink(
#						    $seq_data_import_hash->{$uniquename_seq},  # <Seq-data-import> element object reference
						    $feature_elem,
						    'sequence',                                # rel
						    "#$uniquename_seq"                         # href
						    );
    
    $logger->logdie("Could not create a 'sequence' <Link> element for <Feature> ribosome_entry_site uniquename '$uniquename' to ribosome_entry_site <Sequence> '$uniquename_seq'") if (!defined($sequence_link_elem));
    
    
    if (!exists $analysis_hash->{$doc->{'doc_name'}}->{'RBS_analysis'}){

	my $analysis_elem = $doc->createAndAddAnalysis(
						       'id'     => 'RBS_analysis'
						       );

	$logger->logdie("Could not create <Analysis> for RBS_analysis") if (!defined($analysis_elem));

	$analysis_hash->{$doc->{'doc_name'}}->{'RBS_analysis'} = $analysis_elem;


	my $attribute_elem = $doc->createAndAddBsmlAttribute(
							     $analysis_elem,
							     'method',
							     'RBS'
							     );

	$logger->logdie("Could not create <Attribute> for RBS_analysis method 'RBS'") if (!defined($attribute_elem));

	$attribute_elem = $doc->createAndAddBsmlAttribute(
							  $analysis_elem,
							  'version',
							  'RBS_version'
							  );
	
	$logger->logdie("Could not create <Attribute> for RBS_analysis version 'RBS_version'") if (!defined($attribute_elem));

	$attribute_elem = $doc->createAndAddBsmlAttribute(
							  $analysis_elem,
							  'name',
							  'RBS_analysis'
							  );

	$logger->logdie("Could not create <Attribute> for RBS_analysis name 'RBS_name'") if (!defined($attribute_elem));



	my $fulldocname;
	if (defined($outdir)){
	    $fulldocname = $outdir . '/' . $doc->{'doc_name'};
	}
	else{
	    $fulldocname = $doc->{'doc_name'};
	}
	    

	$fulldocname =~ s|//|/|;
	
	my $sourcename_attribute = $doc->createAndAddBsmlAttribute(
								   $analysis_elem,
								   'sourcename',
								   $fulldocname
								   );
	if (!defined($sourcename_attribute)) {
	    $logger->logdie("Could not create <Attribute> for RBS_analysis sourcename for document '$doc->{'doc_name'}'");
	}



    }

    $logger->debug("Attempting to insert <Link> to <Analysis> for RBS '$uniquename'") if $logger->is_debug;

    my $analysis_link_elem = $doc->createAndAddLink(
#						    $analysis_elem,  # <Analysis> element object reference
						    $feature_elem,
						    'analysis',      # rel
#						    "#$uniquename"   # href
						    "#RBS_analysis"
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

    my $uniquename = $database . '_' . $asmbl_id . '_' . $term->{'feat_name'} . '_terminator';
    
    $logger->debug("Processing terminator '$uniquename'") if $logger->is_debug;


#    if (($term->{'end5'} == 0) or ($term->{'end3'} == 0 )){
#	$logger->fatal("uniquename '$uniquename' end5 '$term->{'end5'}' end3 '$term->{'end3'}'");
#    }


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



    my $uniquename_seq = $database . '_' . $asmbl_id . '_' . $term->{'feat_name'} . '_terminator_seq';

    $logger->debug("Attempting to insert <Link> for <Seq-data-import> for ribosome '$uniquename_seq'") if $logger->is_debug;
    
    my $sequence_link_elem = $doc->createAndAddLink(
						    $feature_elem,       # element
						    'sequence',          # rel
						    "#$uniquename_seq"   # href
						    );
    
    $logger->logdie("Could not create a 'sequence' <Link> element for <Feature> terminator uniquename '$uniquename' to terminator <Sequence> '$uniquename_seq'") if (!defined($sequence_link_elem));




    

    if (defined($term->{'direction'})){
	
	my $attribute_elem = $doc->createAndAddBsmlAttribute(
							     $feature_elem,          # <Feature> element object reference
							     'term_direction',       # name
							     "$term->{'direction'}"  # content
							     );
	
	$logger->logdie("Could not create <Attribute> element object reference for the terminator '$uniquename' feature's term_direction 'term->{'direction'}'")  if (!defined($attribute_elem));
    }    


    if (defined($term->{'confidence'})){
	
	my $attribute_elem = $doc->createAndAddBsmlAttribute(
							     $feature_elem,           # <Feature> element object reference
							     'term_confidence',       # name
							     "$term->{'confidence'}"  # content
							     );
	
	$logger->logdie("Could not create <Attribute> element object reference for the terminator '$uniquename' feature's term_confidence 'term->{'confidence'}'")  if (!defined($attribute_elem));
    }    


    my $xref_elem = $doc->createAndAddCrossReference(
						     'parent'          => $feature_elem,
						     'id'              => $doc->{'xrefctr'}++,
						     'database'        => $prefix,
						     'identifier'      => $term->{'feat_name'},
						     'identifier-type' => 'feat_name'
						     );
    
    $logger->logdie("Could not create a <Cross-reference> element object reference for terminator '$uniquename'") if (!defined($xref_elem));


    if (!exists $analysis_hash->{$doc->{'doc_name'}}->{'TERM_analysis'}){

	#
	# Create a single <Analysis> element object reference for all TERM_analysis types
	#
	my $analysis_elem = $doc->createAndAddAnalysis(
						    'id'     => 'TERM_analysis'
						    );

	$logger->logdie("Could not create <Analysis> for TERM_analysis") if (!defined($analysis_elem));
	
	$analysis_hash->{$doc->{'doc_name'}}->{'TERM_analysis'} = $analysis_elem;


	my $attribute_elem = $doc->createAndAddBsmlAttribute(
							$analysis_elem,
							'method',
							'TERM'
							);

	$logger->logdie("Could not create <Attribute> for TERM_analysis method 'TERM'") if (!defined($attribute_elem));

	$attribute_elem = $doc->createAndAddBsmlAttribute(
							  $analysis_elem,
							  'name',
							  'TERM_analysis'
							  );

	$logger->logdie("Could not create <Attribute> for TERM_analysis name 'TERM_name'") if (!defined($attribute_elem));
	
	$attribute_elem = $doc->createAndAddBsmlAttribute(
							  $analysis_elem,
							  'version',
							  'TERM_version'
							  );

	$logger->logdie("Could not create <Attribute> for TERM_analysis version 'TERM_version'") if (!defined($attribute_elem));



	my $fulldocname;
	if (defined($outdir)){
	    $fulldocname = $outdir . '/' . $doc->{'doc_name'};
	}
	else{
	    $fulldocname = $doc->{'doc_name'};
	}
	    

	$fulldocname =~ s|//|/|;
	
	my $sourcename_attribute = $doc->createAndAddBsmlAttribute(
								   $analysis_elem,
								   'sourcename',
								   $fulldocname
								   );
	if (!defined($sourcename_attribute)) {
	    $logger->logdie("Could not create <Attribute> for TERM_analysis sourcename for document '$doc->{'doc_name'}'");
	}







    }


    $logger->debug("Attempting to insert <Link> to <Analysis> for TERM '$uniquename'") if $logger->is_debug;

    my $link_elem = $doc->createAndAddLink(
#					   $analysis_elem,  # <Analysis> element object reference
					   $feature_elem,
					   'analysis',      # rel
#					   "#$uniquename"   # href ?jay what?
					   "#TERM_analysis"
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
#
#----------------------------------------------------------------------------------------
sub store_ident_attributes {

    my %p = @_;
    my $doc            = $p{'doc'};
    my $attributes     = $p{'attributes'};
    my $attribute_list = $p{'attribute-list'};
    my $uniquename     = $p{'uniquename'};
    my $transcript_feature_elem = $p{'transcript_feature_elem'};


    if ((defined($attributes)) && (scalar(@{$attributes}) > 0)){
	
	#
	# attributes is now a reference to a list of hashes
	#
	foreach my $hash (sort @{$attributes} ){
	    
	    foreach my $ident_attribute ( sort keys %{$hash} ){
		
		
		#
		# Strip trailing whitespaces
		#
		my $value = $hash->{$ident_attribute};
		$value =~ s/\s+$//;
		
		my $attribute_elem = $doc->createAndAddBsmlAttribute(
								     $transcript_feature_elem,    # elem
								     $ident_attribute,            # key
								     $value                       # value
								     );
		
		$logger->logdie("Could not create <Attribute> element object reference for attribute name '$ident_attribute' value '$hash->{$ident_attribute}' for transcript '$uniquename'") if (!defined($attribute_elem));
		
	    }
	}
	
    }


    if ((defined($attribute_list)) && (scalar(@{$attribute_list}) > 0 )){

	#
	# The ec# will now be stored in an <Attribute-list>
	#
	$logger->debug("Attempting to add ec# <Attribute-list> for transcript '$uniquename'") if $logger->is_debug;
	
	foreach my $list ( @{$attribute_list} ) {
	    
	    
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
    
    $logger->debug("Attempting to add TIGR Roles <Attribute-list> for transcript '$uniquename'") if $logger->is_debug;


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


    $logger->debug("Attempting to add <Attribute-list> to transcript '$uniquename'") if $logger->is_debug;
    
    foreach my $list ( @{$attributelist} ){
	

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

# 	#
# 	# This socks.  I have to unpackage and re-package for BSML API
# 	#
	
# 	foreach my $hash ( @{$list} ) {
	    
# 	    my ($key, $val) = each ( %{$hash} );
	    
# 	    my $hash2 = { name => $key,
# 			  content => $val };
	    
# 	    my $list2 = [];
# 	    push (@{$list2}, $hash2);
	    
# 	    $transcript_feature_elem->addBsmlAttributeList($list2);
# 	}
#     }
# }





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

    $logger->debug("Attempting to add <Attribute-list> to transcript '$uniquename'") if $logger->is_debug;

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

# 	#
# 	# This socks.  I have to unpackage and re-package for BSML API
# 	#

# 	foreach my $hash ( @{$list} ) {

# 	    my ($key, $val) = each ( %{$hash} );
	
# 	    my $hash2 = { name => $key,
# 			  content => $val };

# 	    my $list2 = [];
# 	    push (@{$list2}, $hash2);
	    
# 	    $transcript_feature_elem->addBsmlAttributeList($list2);
# 	}
#     }
# }


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
    my $outdir         = $p{'outdir'};
    my $prefix         = $p{'prefix'};

    #
    # attributes is now a reference to a list of hashes
    #


    my $class = 'match';
    my $rel   = 'rel';
    my $href  = '#BER_analysis';

    #
    #  Create one BER <Analysis> component
    # //Analysis/@id = 'BER_analysis'
    # //Analysis/Attribute/[@name='program']/@content = 'BER'
    # //Analysis/Attribute/[@name='programversion']/@content = 'legacy'
    # //Analysis/Attribute/[@name='algorithm']/@content = 'BER'
    # //Analysis/Attribute/[@name='sourcename']/@content = $docname
    # //Analysis/Attribute/[@name='name']/@content = 'BER_analysis'
    
    if (!exists $analysis_hash->{$doc->{'doc_name'}}->{'BER_analysis'}){

	my $analysis_elem = $doc->createAndAddAnalysis(
						    'id' => 'BER_analysis'
						    );
	
	if (!defined($analysis_elem)){
	    $logger->logdie("Could not create <Analysis> for 'BER_analysis'");
	}
	else{ 

	    $analysis_hash->{$doc->{'doc_name'}}->{'BER_analysis'} = $analysis_elem;

	    my $program_attribute = $doc->createAndAddBsmlAttribute(
								    $analysis_elem,
								    'program',
								    'BER'
								    );
	    if (!defined($program_attribute)) {
		$logger->logdie("Could not create <Attribute> for BER_analysis program 'BER'");
	    }
	    
	    my $programversion_attribute = $doc->createAndAddBsmlAttribute(
									   $analysis_elem,
									   'version',
									   'legacy'
									   );
	    if (!defined($programversion_attribute)) {
		$logger->logdie("Could not create <Attribute> for BER_analysis programversion 'legacy'");
	    }
	    
	    
	    my $fulldocname;
	    if (defined($outdir)){
		$fulldocname = $outdir . '/' . $docname;
	    }
	    else{
		$fulldocname = $docname;
	    }
	    

	    $fulldocname =~ s|//|/|;

	    my $sourcename_attribute = $doc->createAndAddBsmlAttribute(
								       $analysis_elem,
								       'sourcename',
								       $fulldocname
								       );
	    if (!defined($sourcename_attribute)) {
		$logger->logdie("Could not create <Attribute> for BER_analysis sourcename '$docname'");
	    }


	    my $name_attribute = $doc->createAndAddBsmlAttribute(
								 $analysis_elem,
								 'name',
								 'BER_analysis'
								 );
	    if (!defined($name_attribute)) {
		$logger->logdie("Could not create <Attribute> for BER_analysis name 'BER_analysis'");
	    }
	}
    }


    foreach my $ev_type (sort keys  %{$data_hash} ){

	foreach my $feat_name (sort keys %{$data_hash->{$ev_type}} ){

	    $logger->debug("Writing out all ev_type '$ev_type' evidence for feat_name '$feat_name'") if $logger->is_debug();
	
	    foreach my $accession (sort keys %{$data_hash->{$ev_type}->{$feat_name}} ) { 

		foreach my $key (sort keys %{$data_hash->{$ev_type}->{$feat_name}->{$accession}} ) { 
	    
		    my $tmphash = $data_hash->{$ev_type}->{$feat_name}->{$accession}->{$key};
		    
		    my $compseq_db;
		    my $compseq_accession;

		    if ($accession =~ /:/){
			($compseq_db, $compseq_accession) = split(/:/, $accession);
		    }
		    else{
			$compseq_db = $accession;
			$compseq_accession = $accession;
		    }


		    my $refseq = $database . '_' . $asmbl_id . '_' . $feat_name . '_CDS';
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
			
			my $ref_sequence_elem;
			my $comp_sequence_elem;
			
			if( !( $doc->returnBsmlSequenceByIDR( $refseq)) ){
			    
			    #
			    # Create <Sequence> element object reference for the refseq
			    #
			    $ref_sequence_elem = $doc->createAndAddSequence(
									    $refseq,  # id
									    undef,    # title
									    undef,    # length
									    'dna',    # molecule
									    'CDS',    # class
									    );
			    
			    #
			    # Create <Cross-reference> object
			    #
			    my $xref_elem = $doc->createAndAddCrossReference(
									     'parent'          => $ref_sequence_elem,
									     'id'              => $doc->{'xrefctr'}++,
									     'database'        => $prefix,
									     'identifier'      => $feat_name,
									     'identifier-type' => 'current'
									     );
			    
			    $logger->logdie("Could not create <Cross-reference> element object reference for <Sequence> '$refseq'") if (!defined($xref_elem));
			    

			}
			
			if( !( $doc->returnBsmlSequenceByIDR( $compseq )) ){
			    
			    #
			    # Create <Sequence> element object reference for the compseq
			    #
			    $comp_sequence_elem = $doc->createAndAddSequence(
									     $compseq,  # id
									     undef,     # title
									     undef,     # length
									     'aa',      # molecule
									     'protein'  # class
									     );
			    #
			    # Create <Cross-reference> object
			    #
			    my $xref_elem = $doc->createAndAddCrossReference(
									     'parent'          => $comp_sequence_elem,
									     'id'              => $doc->{'xrefctr'}++,
									     'database'        => $compseq_db,
									     'identifier'      => $compseq_accession,
									     'identifier-type' => 'current'
									     );
			    
			    $logger->logdie("Could not create <Cross-reference> element object reference for <Sequence> '$compseq'") if (!defined($xref_elem));
			    
			    


			}

			#
			# Create <Seq-pair-alignment>
			#	      
			$alignment_pair = $doc->returnBsmlSeqPairAlignmentR( $doc->addBsmlSeqPairAlignment() );
			
			if (!defined($alignment_pair)){

			    $logger->logdie("Could not create <Seq-pair-alignment> element object reference");
			}

			$alignment_pair->setattr( 'refseq',  $refseq  );
			$alignment_pair->setattr( 'compseq', $compseq );
			$alignment_pair->setattr( 'class',   $class   );
			
			my $link_elem = $doc->createAndAddLink(
							       $alignment_pair,  # <Seq-pair-alignment> element object reference
							       'analysis',       # rel
							       '#BER_analysis'   # href
							       );
			if (!defined($link_elem)){
			    $logger->logdie("Could not create an 'analysis' <Link> element object reference for <Seq-pair-alignment>");
			}
			
			#
			# Store reference to the <Seq-pair-alignment>
			#
			BSML::BsmlDoc::BsmlSetAlignmentLookup( $refseq, $compseq, $alignment_pair );
			
		    }

		    #add a new BsmlSeqPairRun to the alignment pair and return
		    my $seq_run = $alignment_pair->returnBsmlSeqPairRunR( $alignment_pair->addBsmlSeqPairRun() );
		    
		    $seq_run->setattr( 'refpos', $tmphash->{'refpos'} );
		    $seq_run->setattr( 'runlength', $tmphash->{'runlength'} );
		    $seq_run->setattr( 'refcomplement', $tmphash->{'refcomplement'});
		    
		    $seq_run->setattr( 'comppos', $tmphash->{'comppos'});
		    $seq_run->setattr( 'comprunlength', $tmphash->{'comprunlength'});
		    $seq_run->setattr( 'compcomplement', $tmphash->{'compcomplement'});
		    
		    $seq_run->setattr( 'runscore', $tmphash->{'runscore'});
		    $seq_run->setattr( 'runprob', $tmphash->{'runprob'});
		    
		    
		    if ( (exists($tmphash->{'auto_annotate_toggle'})) and (defined($tmphash->{'auto_annotate_toggle'}))){
			$seq_run->addBsmlAttr( 'auto_annotate_toggle', "1" );
		    }

		    if ( (exists($tmphash->{'percent_identity'})) and (defined($tmphash->{'percent_identity'}))){
			$seq_run->addBsmlAttr( 'percent_identity', "$tmphash->{'percent_identity'}" );
		    }

		    if ( (exists($tmphash->{'percent_similarity'})) and (defined($tmphash->{'percent_similarity'}))){
			$seq_run->addBsmlAttr( 'percent_similarity', "$tmphash->{'percent_similarity'}");
		    }

		    if ( (exists($tmphash->{'date'})) and (defined($tmphash->{'date'}))){
			$seq_run->addBsmlAttr( 'date', "$tmphash->{'date'}" );
		    }


		}
	    }
	}
    }
}


#----------------------------------------------------------------------------------------
# Evidence
# HMM2 Evidence Encoding
#
#----------------------------------------------------------------------------------------
sub store_hmm2_evidence_data { 

    my %p = @_;
    my $doc            = $p{'doc'};
    my $asmbl_id       = $p{'asmbl_id'};
    my $data_hash      = $p{'data_hash'};
    my $database       = $p{'database'};
    my $docname        = $p{'docname'};
    my $outdir         = $p{'outdir'};
    my $prefix         = $p{'prefix'};

    #
    # attributes is now a reference to a list of hashes
    #


    my $class = 'match';
    my $rel   = 'rel';
    my $href  = '#HMM2_analysis';



    #
    #  Create one BER <Analysis> component
    # //Analysis/@id = 'HMM2_analysis'
    # //Analysis/Attribute/[@name='program']/@content = 'HMM'
    # //Analysis/Attribute/[@name='programversion']/@content = 'legacy'
    # //Analysis/Attribute/[@name='algorithm']/@content = 'HMM2'
    # //Analysis/Attribute/[@name='sourcename']/@content = $docname
    # //Analysis/Attribute/[@name='name']/@content = 'HMM2_analysis'
    
    if (!exists $analysis_hash->{$doc->{'doc_name'}}->{'HMM2_analysis'}){

	my $analysis_elem = $doc->createAndAddAnalysis(
						       'id' => 'HMM2_analysis'
						       );
	
	if (!defined($analysis_elem)){
	    $logger->logdie("Could not create <Analysis> for 'HMM2_analysis'");
	}
	else{ 

	    $analysis_hash->{$doc->{'doc_name'}}->{'HMM2_analysis'} = $analysis_elem;

	    my $program_attribute = $doc->createAndAddBsmlAttribute(
								    $analysis_elem,
								    'program',
								    'HMM2'
								    );
	    if (!defined($program_attribute)) {
		$logger->logdie("Could not create <Attribute> for HMM2_analysis program 'HMM2'");
	    }
	    
	    my $programversion_attribute = $doc->createAndAddBsmlAttribute(
									   $analysis_elem,
									   'version',
									   'legacy'
									   );
	    if (!defined($programversion_attribute)) {
		$logger->logdie("Could not create <Attribute> for HMM2_analysis programversion 'legacy'");
	    }

	    my $fulldocname;
	    
	    if (defined($outdir)){
		$fulldocname = $outdir . '/' . $docname;
	    }
	    else{
		$fulldocname = $docname;
	    }

	    $fulldocname =~ s|//|/|;

	    my $sourcename_attribute = $doc->createAndAddBsmlAttribute(
								       $analysis_elem,
								       'sourcename',
								       $fulldocname
								       );
	    if (!defined($sourcename_attribute)) {
		$logger->logdie("Could not create <Attribute> for HMM2_analysis sourcename '$docname'");
	    }


	my $name_attribute = $doc->createAndAddBsmlAttribute(
							     $analysis_elem,
							     'name',
							     'HMM2_analysis'
							     );
	    if (!defined($name_attribute)) {
		$logger->logdie("Could not create <Attribute> for HMM2_analysis name 'HMM2_analysis'");
	    }
	}
    }


#    print Dumper $data_hash;die;

    foreach my $ev_type (sort keys %{$data_hash} ) {

	foreach my $feat_name (sort keys %{$data_hash->{$ev_type}} ){
	    
	    $logger->debug("Writing out all ev_type '$ev_type' evidence for feat_name '$feat_name'") if $logger->is_debug();

	    foreach my $accession (sort keys %{$data_hash->{$ev_type}->{$feat_name}} ){

		foreach my $key (sort keys %{$data_hash->{$ev_type}->{$feat_name}->{$accession}} ){
		    

		    my $tmphash = $data_hash->{$ev_type}->{$feat_name}->{$accession}->{$key};


		    my $refseq = $database . '_' . $asmbl_id . '_' . $feat_name . '_protein';
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
			
			my $ref_sequence_elem;
			my $comp_sequence_elem;
			
			if( !( $doc->returnBsmlSequenceByIDR( $refseq)) ){
			    
			    #
			    # Create <Sequence> element object reference for the refseq
			    #
			    $ref_sequence_elem = $doc->createAndAddSequence(
									    $refseq,  # id
									    undef,    # title
									    undef,    # length
									    'aa',    # molecule
									    'protein',    # class
									    );

			    if (defined($ref_sequence_elem)){
				#
				# Create <Cross-reference> element object reference for the refseq's <Sequence> element
				#
				my $xref_elem = $doc->createAndAddCrossReference(
										 'parent'          => $ref_sequence_elem,
										 'id'              => $doc->{'xrefctr'}++,
										 'database'        => $prefix,
										 'identifier'      => $feat_name,
										 'identifier-type' => 'current'
										 );
				
				
				$logger->logdie("Could not create <Cross-reference> element object reference") if (!defined($xref_elem));
			    }
			    else{
				$logger->logdie("Could not create <Sequence> element object reference for refseq '$refseq'");
			    }



			}
			
			if( !( $doc->returnBsmlSequenceByIDR( $compseq )) ){
			    
			    #
			    # Create <Sequence> element object reference for the compseq
			    #
			    $comp_sequence_elem = $doc->createAndAddSequence(
									     $compseq,  # id
									     undef,     # title
									     undef,     # length
									     'aa',      # molecule
									     'protein'  # class
									     );

			    if (defined($comp_sequence_elem)){
				
				#
				# Create <Cross-reference> element object reference for the refseq's <Sequence> element
				#

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
				my $compseq_db;

				if ($compseq =~ /^PFAM/){
				    $compseq_db = 'Pfam';
				}
				elsif ($compseq =~ /^PF/){
				    $compseq_db = 'Pfam';
				}
				elsif ($compseq =~ /^TIGRFAM/){
				    $compseq_db = 'TIGR_TIGRFAMS';
				}
				elsif ($compseq =~ /^TIGR/){
				    $compseq_db = 'TIGR_TIGRFAMS';
				}
				else{
				    $compseq_db = $prefix;
				}


				my $xref_elem = $doc->createAndAddCrossReference(
										 'parent'          => $comp_sequence_elem,
										 'id'              => $doc->{'xrefctr'}++,
										 'database'        => $compseq_db,
										 'identifier'      => $compseq,
										 'identifier-type' => 'current'
										 );
				
				
				$logger->logdie("Could not create <Cross-reference> element object reference") if (!defined($xref_elem));
			    }
			    else{
				$logger->logdie("Could not create <Sequence> element object reference for compseq '$compseq'");
			    }

			}

			#
			# Create <Seq-pair-alignment>
			#	      
			$alignment_pair = $doc->returnBsmlSeqPairAlignmentR( $doc->addBsmlSeqPairAlignment() );
			
			if (!defined($alignment_pair)){

			    $logger->logdie("Could not create <Seq-pair-alignment> element object reference");
			}

			$alignment_pair->setattr( 'refseq',  $refseq  );
			$alignment_pair->setattr( 'compseq', $compseq );
			$alignment_pair->setattr( 'class',   $class   );
			
			my $link_elem = $doc->createAndAddLink(
							       $alignment_pair,  # <Seq-pair-alignment> element object reference
							       'analysis',       # rel
							       '#HMM2_analysis'   # href
							       );
			if (!defined($link_elem)){
			    $logger->logdie("Could not create an 'analysis' <Link> element object reference for <Seq-pair-alignment>");
			}
			
			#
			# Store reference to the <Seq-pair-alignment>
			#
			BSML::BsmlDoc::BsmlSetAlignmentLookup( $refseq, $compseq, $alignment_pair );
			
		    }

		    #add a new BsmlSeqPairRun to the alignment pair and return
		    my $seq_run = $alignment_pair->returnBsmlSeqPairRunR( $alignment_pair->addBsmlSeqPairRun() );

		    $seq_run->setattr( 'refpos', $tmphash->{'refpos'} );
		    $seq_run->setattr( 'runlength', $tmphash->{'runlength'} );
		    $seq_run->setattr( 'refcomplement', $tmphash->{'refcomplement'});
		    
		    $seq_run->setattr( 'comppos', $tmphash->{'comppos'});
		    $seq_run->setattr( 'comprunlength', $tmphash->{'comprunlength'});
		    $seq_run->setattr( 'compcomplement', $tmphash->{'compcomplement'});
		    
		    $seq_run->setattr( 'runscore', $tmphash->{'runscore'});
		    $seq_run->setattr( 'runprob', $tmphash->{'runprob'});
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
    my $outdir         = $p{'outdir'};
    my $prefix         = $p{'prefix'};

    #
    # attributes is now a reference to a list of hashes
    #


    my $class = 'match';
    my $href  = '#NCBI_COG';

    
    if (!exists $analysis_hash->{$doc->{'doc_name'}}->{'NCBI_COG'}){

	my $analysis_elem = $doc->createAndAddAnalysis(
						       'id' => 'NCBI_COG'
						       );
	
	if (!defined($analysis_elem)){
	    $logger->logdie("Could not create <Analysis> for 'NCBI_COG'");
	}
	else{ 

	    $analysis_hash->{$doc->{'doc_name'}}->{'NCBI_COG'} = $analysis_elem;

	    my $program_attribute = $doc->createAndAddBsmlAttribute(
								    $analysis_elem,
								    'program',
								    'NCBI_COG'
								    );
	    if (!defined($program_attribute)) {
		$logger->logdie("Could not create <Attribute> for NCBI_COG program 'NCBI_COG'");
	    }
	    
	    my $programversion_attribute = $doc->createAndAddBsmlAttribute(
									   $analysis_elem,
									   'version',
									   'legacy'
									   );
	    if (!defined($programversion_attribute)) {
		$logger->logdie("Could not create <Attribute> for NCBI_COG programversion 'legacy'");
	    }

	    my $fulldocname;
	    
	    if (defined($outdir)){
		$fulldocname = $outdir . '/' . $docname;
	    }
	    else{
		$fulldocname = $docname;
	    }

	    $fulldocname =~ s|//|/|;

	    my $sourcename_attribute = $doc->createAndAddBsmlAttribute(
								       $analysis_elem,
								       'sourcename',
								       $fulldocname
								       );
	    if (!defined($sourcename_attribute)) {
		$logger->logdie("Could not create <Attribute> for NCBI_COG sourcename '$docname'");
	    }


	my $name_attribute = $doc->createAndAddBsmlAttribute(
							     $analysis_elem,
							     'name',
							     'NCBI_COG'
							     );
	    if (!defined($name_attribute)) {
		$logger->logdie("Could not create <Attribute> for NCBI_COG name 'NCBI_COG'");
	    }
	}
    }


#    print Dumper $data_hash;die;

    foreach my $ev_type (sort keys %{$data_hash} ) {

	foreach my $feat_name (sort keys %{$data_hash->{$ev_type}} ){
	    
	    $logger->debug("Writing out all ev_type '$ev_type' evidence for feat_name '$feat_name'") if $logger->is_debug();

	    foreach my $accession (sort keys %{$data_hash->{$ev_type}->{$feat_name}} ){

		foreach my $key (sort keys %{$data_hash->{$ev_type}->{$feat_name}->{$accession}} ){
		    

		    my $tmphash = $data_hash->{$ev_type}->{$feat_name}->{$accession}->{$key};


		    my $refseq = $database . '_' . $asmbl_id . '_' . $feat_name . '_protein';
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
			
			my $ref_sequence_elem;
			my $comp_sequence_elem;
			
			if( !( $doc->returnBsmlSequenceByIDR( $refseq)) ){
			    
			    #
			    # Create <Sequence> element object reference for the refseq
			    #
			    $ref_sequence_elem = $doc->createAndAddSequence(
									    $refseq,  # id
									    undef,    # title
									    undef,    # length
									    'aa',    # molecule
									    'protein',    # class
									    );

			    if (defined($ref_sequence_elem)){
				#
				# Create <Cross-reference> element object reference for the refseq's <Sequence> element
				#
				my $xref_elem = $doc->createAndAddCrossReference(
										 'parent'          => $ref_sequence_elem,
										 'id'              => $doc->{'xrefctr'}++,
										 'database'        => $prefix,
										 'identifier'      => $feat_name,
										 'identifier-type' => 'current'
										 );
				
				
				$logger->logdie("Could not create <Cross-reference> element object reference") if (!defined($xref_elem));
			    }
			    else{
				$logger->logdie("Could not create <Sequence> element object reference for refseq '$refseq'");
			    }



			}
			
			if( !( $doc->returnBsmlSequenceByIDR( $compseq )) ){
			    
			    #
			    # Create <Sequence> element object reference for the compseq
			    #
			    $comp_sequence_elem = $doc->createAndAddSequence(
									     $compseq,  # id
									     undef,     # title
									     undef,     # length
									     'aa',      # molecule
									     'protein'  # class
									     );

			    if (defined($comp_sequence_elem)){
				
				#
				# Create <Cross-reference> element object reference for the refseq's <Sequence> element
				#

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
				my $compseq_db;

				if ($compseq =~ /^PFAM/){
				    $compseq_db = 'Pfam';
				}
				elsif ($compseq =~ /^PF/){
				    $compseq_db = 'Pfam';
				}
				elsif ($compseq =~ /^TIGRFAM/){
				    $compseq_db = 'TIGR_TIGRFAMS';
				}
				elsif ($compseq =~ /^TIGR/){
				    $compseq_db = 'TIGR_TIGRFAMS';
				}
				else{
				    $compseq_db = $prefix;
				}


				my $xref_elem = $doc->createAndAddCrossReference(
										 'parent'          => $comp_sequence_elem,
										 'id'              => $doc->{'xrefctr'}++,
										 'database'        => $compseq_db,
										 'identifier'      => $compseq,
										 'identifier-type' => 'current'
										 );
				
				
				$logger->logdie("Could not create <Cross-reference> element object reference") if (!defined($xref_elem));
			    }
			    else{
				$logger->logdie("Could not create <Sequence> element object reference for compseq '$compseq'");
			    }

			}

			#
			# Create <Seq-pair-alignment>
			#	      
			$alignment_pair = $doc->returnBsmlSeqPairAlignmentR( $doc->addBsmlSeqPairAlignment() );
			
			if (!defined($alignment_pair)){

			    $logger->logdie("Could not create <Seq-pair-alignment> element object reference");
			}

			$alignment_pair->setattr( 'refseq',  $refseq  );
			$alignment_pair->setattr( 'compseq', $compseq );
			$alignment_pair->setattr( 'class',   $class   );
			
			my $link_elem = $doc->createAndAddLink(
							       $alignment_pair,  # <Seq-pair-alignment> element object reference
							       'analysis',       # rel
							       '#NCBI_COG'       # href
							       );
			if (!defined($link_elem)){
			    $logger->logdie("Could not create an 'analysis' <Link> element object reference for <Seq-pair-alignment>");
			}
			
			#
			# Store reference to the <Seq-pair-alignment>
			#
			BSML::BsmlDoc::BsmlSetAlignmentLookup( $refseq, $compseq, $alignment_pair );
			
		    }

		    #add a new BsmlSeqPairRun to the alignment pair and return
		    my $seq_run = $alignment_pair->returnBsmlSeqPairRunR( $alignment_pair->addBsmlSeqPairRun() );

		    $seq_run->setattr( 'refpos', $tmphash->{'refpos'} );
		    $seq_run->setattr( 'runlength', $tmphash->{'runlength'} );
		    $seq_run->setattr( 'refcomplement', $tmphash->{'refcomplement'});
		    
		    $seq_run->setattr( 'comppos', $tmphash->{'comppos'});
		    $seq_run->setattr( 'comprunlength', $tmphash->{'comprunlength'});
		    $seq_run->setattr( 'compcomplement', $tmphash->{'compcomplement'});
		    
		    $seq_run->setattr( 'runscore', $tmphash->{'runscore'});
		    $seq_run->setattr( 'runprob', $tmphash->{'runprob'});
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
    my $outdir         = $p{'outdir'};
    my $prefix         = $p{'prefix'};

    #
    # attributes is now a reference to a list of hashes
    #


    my $class = 'match';
    my $href  = '#PROSITE';

    
    if (!exists $analysis_hash->{$doc->{'doc_name'}}->{'PROSITE'}){

	my $analysis_elem = $doc->createAndAddAnalysis(
						       'id' => 'PROSITE'
						       );
	
	if (!defined($analysis_elem)){
	    $logger->logdie("Could not create <Analysis> for 'PROSITE'");
	}
	else{ 

	    $analysis_hash->{$doc->{'doc_name'}}->{'PROSITE'} = $analysis_elem;

	    my $program_attribute = $doc->createAndAddBsmlAttribute(
								    $analysis_elem,
								    'program',
								    'PROSITE'
								    );
	    if (!defined($program_attribute)) {
		$logger->logdie("Could not create <Attribute> for HMM2_analysis program 'PROSITE'");
	    }
	    
	    my $programversion_attribute = $doc->createAndAddBsmlAttribute(
									   $analysis_elem,
									   'version',
									   'legacy'
									   );
	    if (!defined($programversion_attribute)) {
		$logger->logdie("Could not create <Attribute> for PROSITE programversion 'legacy'");
	    }

	    my $fulldocname;
	    
	    if (defined($outdir)){
		$fulldocname = $outdir . '/' . $docname;
	    }
	    else{
		$fulldocname = $docname;
	    }

	    $fulldocname =~ s|//|/|;

	    my $sourcename_attribute = $doc->createAndAddBsmlAttribute(
								       $analysis_elem,
								       'sourcename',
								       $fulldocname
								       );
	    if (!defined($sourcename_attribute)) {
		$logger->logdie("Could not create <Attribute> for HMM2_analysis sourcename '$docname'");
	    }


	my $name_attribute = $doc->createAndAddBsmlAttribute(
							     $analysis_elem,
							     'name',
							     'PROSITE'
							     );
	    if (!defined($name_attribute)) {
		$logger->logdie("Could not create <Attribute> for PROSITE name 'PROSITE'");
	    }
	}
    }


#    print Dumper $data_hash;die;

    foreach my $ev_type (sort keys %{$data_hash} ) {

	foreach my $feat_name (sort keys %{$data_hash->{$ev_type}} ){
	    
	    $logger->debug("Writing out all ev_type '$ev_type' evidence for feat_name '$feat_name'") if $logger->is_debug();

	    foreach my $accession (sort keys %{$data_hash->{$ev_type}->{$feat_name}} ){

		foreach my $key (sort keys %{$data_hash->{$ev_type}->{$feat_name}->{$accession}} ){
		    

		    my $tmphash = $data_hash->{$ev_type}->{$feat_name}->{$accession}->{$key};


		    my $refseq = $database . '_' . $asmbl_id . '_' . $feat_name . '_protein';
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
			
			my $ref_sequence_elem;
			my $comp_sequence_elem;
			
			if( !( $doc->returnBsmlSequenceByIDR( $refseq)) ){
			    
			    #
			    # Create <Sequence> element object reference for the refseq
			    #
			    $ref_sequence_elem = $doc->createAndAddSequence(
									    $refseq,  # id
									    undef,    # title
									    undef,    # length
									    'aa',    # molecule
									    'protein',    # class
									    );

			    if (defined($ref_sequence_elem)){
				#
				# Create <Cross-reference> element object reference for the refseq's <Sequence> element
				#
				my $xref_elem = $doc->createAndAddCrossReference(
										 'parent'          => $ref_sequence_elem,
										 'id'              => $doc->{'xrefctr'}++,
										 'database'        => $prefix,
										 'identifier'      => $feat_name,
										 'identifier-type' => 'current'
										 );
				
				
				$logger->logdie("Could not create <Cross-reference> element object reference") if (!defined($xref_elem));
			    }
			    else{
				$logger->logdie("Could not create <Sequence> element object reference for refseq '$refseq'");
			    }



			}
			
			if( !( $doc->returnBsmlSequenceByIDR( $compseq )) ){
			    
			    #
			    # Create <Sequence> element object reference for the compseq
			    #
			    $comp_sequence_elem = $doc->createAndAddSequence(
									     $compseq,  # id
									     undef,     # title
									     undef,     # length
									     'aa',      # molecule
									     'protein'  # class
									     );

			    if (defined($comp_sequence_elem)){
				
				#
				# Create <Cross-reference> element object reference for the refseq's <Sequence> element
				#

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
				my $compseq_db;

				if ($compseq =~ /^PFAM/){
				    $compseq_db = 'Pfam';
				}
				elsif ($compseq =~ /^PF/){
				    $compseq_db = 'Pfam';
				}
				elsif ($compseq =~ /^TIGRFAM/){
				    $compseq_db = 'TIGR_TIGRFAMS';
				}
				elsif ($compseq =~ /^TIGR/){
				    $compseq_db = 'TIGR_TIGRFAMS';
				}
				else{
				    $compseq_db = $prefix;
				}


				my $xref_elem = $doc->createAndAddCrossReference(
										 'parent'          => $comp_sequence_elem,
										 'id'              => $doc->{'xrefctr'}++,
										 'database'        => $compseq_db,
										 'identifier'      => $compseq,
										 'identifier-type' => 'current'
										 );
				
				
				$logger->logdie("Could not create <Cross-reference> element object reference") if (!defined($xref_elem));
			    }
			    else{
				$logger->logdie("Could not create <Sequence> element object reference for compseq '$compseq'");
			    }

			}

			#
			# Create <Seq-pair-alignment>
			#	      
			$alignment_pair = $doc->returnBsmlSeqPairAlignmentR( $doc->addBsmlSeqPairAlignment() );
			
			if (!defined($alignment_pair)){

			    $logger->logdie("Could not create <Seq-pair-alignment> element object reference");
			}

			$alignment_pair->setattr( 'refseq',  $refseq  );
			$alignment_pair->setattr( 'compseq', $compseq );
			$alignment_pair->setattr( 'class',   $class   );
			
			my $link_elem = $doc->createAndAddLink(
							       $alignment_pair,  # <Seq-pair-alignment> element object reference
							       'analysis',       # rel
							       '#PROSITE'   # href
							       );
			if (!defined($link_elem)){
			    $logger->logdie("Could not create an 'analysis' <Link> element object reference for <Seq-pair-alignment>");
			}
			
			#
			# Store reference to the <Seq-pair-alignment>
			#
			BSML::BsmlDoc::BsmlSetAlignmentLookup( $refseq, $compseq, $alignment_pair );
			
		    }

		    #add a new BsmlSeqPairRun to the alignment pair and return
		    my $seq_run = $alignment_pair->returnBsmlSeqPairRunR( $alignment_pair->addBsmlSeqPairRun() );

		    $seq_run->setattr( 'refpos', $tmphash->{'refpos'} );
		    $seq_run->setattr( 'runlength', $tmphash->{'runlength'} );
		    $seq_run->setattr( 'refcomplement', $tmphash->{'refcomplement'});
		    
		    $seq_run->setattr( 'comppos', $tmphash->{'comppos'});
		    $seq_run->setattr( 'comprunlength', $tmphash->{'comprunlength'});
		    $seq_run->setattr( 'compcomplement', $tmphash->{'compcomplement'});
		    
		    $seq_run->setattr( 'runscore', $tmphash->{'runscore'});
		    $seq_run->setattr( 'runprob', $tmphash->{'runprob'});

		    
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




#----------------------------------------------------------------------------------------
# load_map()
#
# The map hashref contains necessary rules such as:
# 1) feature/sequence suffix strings
# 2) feature/sequence class names/strings
#
#----------------------------------------------------------------------------------------
sub load_map {

    $map = {
           	'assembly' => {
	              'suffix'  => '_assembly',
		      'class'   => 'assembly',
		      'moltype' => 'dna'
		  },
                  'protein_seq' => {
		      'suffix' => '_protein_seq',
		      'class' => 'protein',
		      'moltype' => 'dna'
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
		  'protein_feature' => {
		      'suffix' => '_protein',
		      'class' => 'protein'
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

}



#-------------------------------------------------------------------------------------------------
# Write bsml document to outdir
#
#-------------------------------------------------------------------------------------------------
sub write_out_bsml_doc {

    my ($outir, $doc) = @_;



    my $bsmldocument = $outdir . '/' . $doc->{'doc_name'};


    #
    # If bsml document exists, copy it to .bak
    #
    if (-e $bsmldocument){
	my $bsmlbak = $bsmldocument . '.bak';
	rename ($bsmldocument, $bsmlbak);

	 chmod (0666, $bsmlbak);
	
	$logger->info("Saving '$bsmldocument' as '$bsmlbak'");
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
	
#------------------------------------------------------------------------------------------------
# DTD validation was requested...
#
#------------------------------------------------------------------------------------------------
sub dtd_validation {
    
    my ($outdir, $name) = @_;
    
    my $dtdvalid = `$ENV{DTDVALID} $outdir/$name --dtd $dtd`;
    if($dtdvalid ne '0'){
	$logger->logdie("DTD validation failed for $outdir/$name");
    }
    elsif($dtdvalid eq '0') {
	$logger->info("DTD validation passed for $outdir/$name");
    }
}

#-------------------------------------------------------------------------------------------------
# XML schema validation was requested...
#
#-------------------------------------------------------------------------------------------------
sub schema_validation {

    my ($outdir, $name) = @_;

    my $schemavalid = `$ENV{SCHEMAVALID} $outdir/$name --schema $schema`;
    if ($schemavalid ne '0'){
	$logger->logdie("XML Schema validation failed for $outdir/$name");
    }
    elsif ($schemavalid eq '0'){
	$logger->info("XML schema validation passed for $outdir/$name");
    }
}
    



#---------------------------------------------------------------
# create_multifasta()
#
#---------------------------------------------------------------
sub create_multifasta {


    $logger->debug("Entered create_multifasta") if $logger->is_debug;

    my ($fastasequences, $fastadir, $db) = @_;

    foreach my $asmbl_id (sort keys %{$fastasequences} ){ 

	foreach my $seqtype (sort keys %{$fastasequences->{$asmbl_id}}){
	    
	    $logger->debug("Writing all sequences to multi-fasta file related to asmbl_id '$asmbl_id' for seqtype '$seqtype'") if $logger->is_debug;

	    my $fastafile = $fastadir . "/" . $db . '_' . $asmbl_id . '_' .  $seqtype . ".fsa";

	    #
	    # If multi-fasta file already exists, let's back it up...
	    #
	    if (-e $fastafile){
		my $fastabak = $fastafile . '.bak';
		copy($fastafile, $fastabak);
		$logger->info("Copying '$fastafile' to '$fastabak'");
	    }


	    open (FASTA, ">$fastafile") or $logger->logdie("Can't open file $fastafile for writing: $!");


	    print "Writing multi-fasta file '$fastafile'\n" if $logger->is_debug;

	    foreach my $sequence ( @{$fastasequences->{$asmbl_id}->{$seqtype}} ) {
	
		$logger->debug("Storing $sequence->[0]") if $logger->is_debug;
		
		my $fastaout = &fasta_out($sequence->[0], $sequence->[1]);
		print FASTA $fastaout;
	
	    }

	    close FASTA;
	    chmod 0666, $fastafile;
	}
    }



}#end sub create_multifasta()


#-------------------------------------------------------------------------
# fasta_out()
#
#-------------------------------------------------------------------------
sub fasta_out {

    #This subroutine takes a sequence name and its sequence and
    #outputs a correctly formatted single fasta entry (including newlines).
    

    $logger->debug("Entered fasta_out") if $logger->is_debug;


    my ($seq_name, $seq) = @_;

    my $fasta=">"."$seq_name"."\n";
    $seq =~ s/\s+//g;
    for(my $i=0; $i < length($seq); $i+=60){
	my $seq_fragment = substr($seq, $i, 60);
	$fasta .= "$seq_fragment"."\n";
    }
    return $fasta;

}



#--------------------------------------------------------
# sub get_asmbl_id_list_from_file()
#
#--------------------------------------------------------
sub get_asmbl_id_list_from_file {


    my $asmbl_file = shift;
    $logger->debug("asmbl_file '$asmbl_file'") if $logger->is_debug();

    if (!defined($asmbl_file)){
	$logger->fatal("asmbl_file was not defined");
	print STDERR "asmbl_file was not defined\n";
	&print_usage();
    }


    #
    # Check permissions on asmbl_file
    #
    if (defined($asmbl_file)){
	if (!-e $asmbl_file){
	    $logger->logdie("asmbl_file '$asmbl_file' does not exist.");
	}
	if (!-r $asmbl_file){
	    $logger->logdie("asmbl_file '$asmbl_file' does not have read permissions.");
	}
    }
    


    my $contents = &get_contents($asmbl_file);
    $logger->logdie("contents were not defined") if (!defined($contents));

    my $comma = ",";
    my $string = join ($comma, @$contents);


    $logger->debug("asmbl_list will be assigned '$string'") if $logger->is_debug();

    return $string;

}#end sub get_asmbl_id_list_from_file()


#--------------------------------------------------------
# get_contents()
#
#--------------------------------------------------------
sub get_contents {

    my $file = shift;

    $logger->debug("file '$file'") if $logger->is_debug();

    $logger->logdie("file was not defined") if (!defined($file));


    $logger->debug("Extracting contents from $file") if $logger->is_debug();

    open (IN_FILE, "<$file") || $logger->logdie("Could not open file: $file for input");
    my @contents = <IN_FILE>;
    chomp @contents;

    return \@contents;


}#end sub get_contents()

#-------------------------------------------------------- 
# remove_cntrl_chars()
#
#-------------------------------------------------------- 
sub remove_cntrl_chars {
    my ($text) = @_;
    $text =~ tr/\t\n\000-\037\177-\377/\t\n/d;
    return ($text);
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
 
    my ($prism, $asmbllist, $db, $ntprok) = @_;

    # this code corresponds to euk_prism/euktigr2chado.pl::migrate_transcripts()

    my $feat_exon_ctr = {};

    my $gene_model = {};


    foreach my $asmbl_id ( sort { $a <=> $b }  @{$asmbllist} ){

	my $exon2transcript_rank = {};
	
	#-----------------------------------------
	# retrieve transcript/gene related data
	#-----------------------------------------
	my $transcripts = $prism->transcripts($asmbl_id);
	$logger->logdie("transcripts was not defined") if (!defined($transcripts));

#	print "transcripts" . Dumper $transcripts;

	#-------------------------------------------
	# retrieve model (CDS/protein) related data
	#-------------------------------------------
	my($model_lookup) = {};
	my $coding_regions = $prism->coding_regions($asmbl_id);
	$logger->logdie("coding_regions was not defined") if (!defined($coding_regions));


#	print "coding_regions" . Dumper $coding_regions;

	for(my $i=0;$i<$coding_regions->{'count'};$i++){
	    if(! exists $model_lookup->{$coding_regions->{$i}->{'parent_feat_name'}}){
		$model_lookup->{$coding_regions->{$i}->{'parent_feat_name'}} = [];
	    }
	    my $model_ref = $model_lookup->{$coding_regions->{$i}->{'parent_feat_name'}};
	    push @$model_ref, $coding_regions->{$i};
	     if(! (ref $coding_regions->{$i})){ 
		 $logger->logdie("Bad reference $coding_regions->{$i}");
	     }
	}

	#--------------------------------------
	# retrieve exon related data
	#--------------------------------------
	my($exon_lookup) = {};
	my $exons = $prism->exons($asmbl_id);
	$logger->logdie("exons was not defined") if (!defined($exons));

#	print "exons" . Dumper $exons;

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
	my @pu = keys %{$transcripts};
	my $count = scalar(@pu);

	

	push (@{$gene_model->{$asmbl_id}}, { 'transcripts'    => $transcripts,
					     'coding_regions' => $model_lookup,
					     'exons'          => $exon_lookup,
					     'counts'         => $count
					 });

    }
    return $gene_model;
}


