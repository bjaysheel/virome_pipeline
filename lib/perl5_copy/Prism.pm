# $Id: Prism.pm 4226 2009-10-01 17:00:10Z daveriley $
=head1 NAME

Prism.pm - One line summary of purpose of class (or file).

=head1 VERSION

This document refers to version N.NN of Prism.pm, released MMMM, DD, YYYY.

=head1 SYNOPSIS

Short examples of code that illustrate the use of the class (if this file is a class).

=head1 DESCRIPTION

=head2 Overview

An overview of the purpose of the file.

=head2 Constructor and initialization.
 applicable, otherwise delete this and parent head2 line.

=head2 Class and object methods

if applicable, otherwise delete this and parent head2 line.

=over 4

=cut


package Prism;

use strict;
use File::Basename;
use base qw(Coati::Coati);
use Coati::Logger;
use Coati::TableIDManager;
use vars qw($AUTOLOAD);
use Data::Dumper;
use DB_File;
use OBO::OBOBuilder;
use BatchCreator;
use File::Copy;
use Annotation::Features::FeatureCollection;
use EpitopeDBUtil;
use ProteinDBUtil;

use constant TEXTSIZE => 100000000;
use constant CHADO_TABLE_COMMIT_ORDER => "tableinfo,project,db,cv,dbxref,cvterm,dbxrefprop,cvtermprop,pub,synonym,pubprop,pub_relationship,pub_dbxref,pubauthor,organism,organismprop,organism_dbxref,cvtermpath,cvtermsynonym,cvterm_relationship,cvterm_dbxref,feature,featureprop,feature_pub,featureprop_pub,feature_synonym,feature_cvterm,feature_cvterm_dbxref,feature_cvterm_pub,feature_cvtermprop,feature_dbxref,featureloc,feature_relationship,feature_relationship_pub,feature_relationshipprop,feature_relprop_pub,analysis,analysisprop,analysisfeature,phylotree,phylotree_pub,phylonode,phylonode_dbxref,phylonode_pub,phylonode_organism,phylonodeprop,phylonode_relationship,cm_blast,cm_proteins,cm_clusters,cm_cluster_members";

use constant CHADO_CORE_TABLE_COMMIT_ORDER => "tableinfo,project,db,cv,dbxref,cvterm,dbxrefprop,cvtermprop,pub,synonym,pubprop,pub_relationship,pub_dbxref,pubauthor,organism,organismprop,organism_dbxref,cvtermpath,cvtermsynonym,cvterm_relationship,cvterm_dbxref,feature,featureprop,feature_pub,featureprop_pub,feature_synonym,feature_cvterm,feature_cvterm_dbxref,feature_cvterm_pub,feature_cvtermprop,feature_dbxref,featureloc,feature_relationship,feature_relationship_pub,feature_relationshipprop,feature_relprop_pub,analysis,analysisprop,analysisfeature,phylotree,phylotree_pub,phylonode,phylonode_dbxref,phylonode_pub,phylonode_organism,phylonodeprop,phylonode_relationship";

use constant SEQUENCE_MODULE_TABLE_COMMIT_ORDER => "feature,featureprop,feature_pub,featureprop_pub,feature_synonym,feature_cvterm,feature_cvterm_dbxref,feature_cvterm_pub,feature_cvtermprop,feature_dbxref,featureloc,feature_relationship,feature_relationship_pub,feature_relationshipprop,feature_relprop_pub";

use constant ORGANISM_MODULE_TABLE_COMMIT_ORDER => "organism,organismprop,organism_dbxref";

use constant GENERAL_MODULE_TABLE_COMMIT_ORDER => "tableinfo,project,db,dbxref";

use constant PUB_MODULE_TABLE_COMMIT_ORDER => "pub,pubprop,pub_relationship,pub_dbxref,pubauthor";

use constant CONTROLLED_VOCABULARY_MODULE_TABLE_COMMIT_ORDER  => "cv,cvterm,dbxrefprop,cvtermprop,cvtermpath,cvtermsynonym,cvterm_relationship,cvterm_dbxref";

use constant PHYLOGENY_MODULE_TABLE_COMMIT_ORDER => "phylotree,phylotree_pub,phylonode,phylonode_dbxref,phylonode_pub,phylonode_organism,phylonodeprop,phylonode_relationship";

use constant CHADO_MART_TABLE_COMMIT_ORDER => "cm_blast,cm_proteins,cm_clusters,cm_cluster_members";

use constant SYBASE_BATCHSIZE => 3000;

our $supportedDatabaseVendors = { 'sybase' => 1,
                                  'postgresql' => 1,
                                  'mysql' => 1 };

our $databaseToBcpFileExtension = { 'sybase' => 'sybase.bcp',
				                    'postgresql' => 'psql.bcp',
                                    'mysql' => 'mysql.bcp' };

my $CONFIG = "Prism.conf"; 
my $REVISION = q|$REVISION$|;
my $VERSION = q|$NAME$|;

umask 0000;

=item $obj->new(%arg)

B<Description:> 

Retrieves

B<Parameters:> 

%arg - 

B<Returns:> 

Returns

=cut

#----------------------------------------------------------------
# new
#
#----------------------------------------------------------------

sub new {
    my $class = shift;
    
    my $self = $class->SUPER::new(@_);
    $self->{_logger} = Coati::Logger::get_logger(__PACKAGE__."API");
    $self->{_user} = undef;
    $self->{_password} = undef;
    $self->{_db} = undef;

    $self->{_logger}->debug("Init $class") if $self->{_logger}->is_debug;
    $self->_init(@_);

    return $self; 
}


=item $obj->_init(%arg)

B<Description:> Initializes the Coati Modules that Prism
depends upon due to multiple inheritance. In addition, a database handle
is created and set up as an object attribute. A local Prism object is
also created and setup as a _backend object attribute. This is a private
method that should not be called from front-end scripts.

B<Parameters:> %arg, hash received from "new" containing parameters for object attributes.

B<Returns:> None.

B<Returns:> 

Returns

=cut


#----------------------------------------------------------------
# _init
#
#----------------------------------------------------------------
sub _init {
    my $self = shift;
    my %arg = @_;

    foreach my $key (keys %arg) {
	$self->{_logger}->debug("Storing member variable $key as _$key=$arg{$key}") if $self->{_logger}->is_debug;
        $self->{"_$key"} = $arg{$key}
    }


    $self->{_logger}->debug("Object initialized as ",ref($self)) if($self->{_logger}->is_debug);

    my ($schema, $vendor, $server) = Coati::Coati::parse_config("Prism.conf",$ENV{PRISM});


    if (exists $self->{'_use_config'}){
	if($arg{use_config} =~ /^\$/){
	    ($schema, $vendor, $server) = split (':',eval($arg{use_config}));
	}
	else {
	    ($schema, $vendor, $server) = split (':',$arg{use_config});
	}
    }


    $self->{_schema} = $schema;
    $self->{_vendor} = $vendor;
    $self->{_server} = $server;


    if($self->{_no_connect}) {
	#This is useful when only non database features of Prism are needed. eg. accessing config options
	$self->{_logger}->warn("Prism object created without database connection");
	return;
    }
    else{
	if(defined $self->{_schema} && defined $self->{_vendor}){
	    $self->{_logger}->debug("Creating backend for Prism schema: $self->{_schema} vendor: $self->{_vendor}") if($self->{_logger}->is_debug);


	    
	    $self->{_backend} = new Coati::ModulesFactory (package=> "Prism",
							   schema => $self->{_schema}, 
							   vendor => $self->{_vendor});

	    #
	    # if backend is created
	    #
	    if(defined $self->{_backend}){
		$self->{_logger}->debug("Created backend $self->{_backend}") if($self->{_logger}->is_debug);

		#
		# Instantiate table id manager
		#
		if($arg{use_placeholders}){
		    $self->{_logger}->debug("Creating id manager with placeholder support") if($self->{_logger}->is_debug);
		    $self->{_backend}->{_id_manager} = new Coati::TableIDManager('placeholders'=>1,
										 'append_bcp' => $self->{_append_bcp},
										 'next_bcp_values' => $self->{_next_bcp_values});
		}
		elsif($arg{checksum_placeholders}){
		    $self->{_logger}->debug("Creating id manager with checksum support") if($self->{_logger}->is_debug);
		    $self->{_backend}->{_id_manager} = new Coati::TableIDManager('checksum_placeholders'=>1,
										 'append_bcp' => $self->{_append_bcp},
										 'next_bcp_values' => $self->{_next_bcp_values});
		}
		else{
		    $self->{_backend}->{_id_manager} = new Coati::TableIDManager('max_func'=>sub {
			my ($table,$field) = @_; 
			my @idarray = $self->{_backend}->getMaxId($table,$field);
			return $idarray[0][0];
		    },
										 'append_bcp'=>$self->{_append_bcp},
										 'next_bcp_values'=> $self->{_next_bcp_values});
		}
		


		if(defined $self->{_backend}->{_id_manager}){
		    $self->{_logger}->debug("Created id manager $self->{_backend}->{_id_manager}") if($self->{_logger}->is_debug);
		}
		else{
		    $self->{_logger}->logdie("No id manager created for schema: $self->{_schema} vendor: $self->{_vendor}");
		}
	    }
	    else{
		## if backend is NOT created
		$self->{_logger}->logdie("No backend created for schema: $self->{_schema} vendor: $self->{_vendor}");
	    }
	}
	else{
	    $self->{_logger}->warn("Undefined schema:$self->{_schema} or vendor:$self->{_vendor}");
	}

	if(!$self->{_user} || !$self->{_password} || !$self->{_db}){
	    $self->{_logger}->error("Bad user: $self->{_user}, password:$self->{_password}, or db: $self->{_db}");
	}
	else{
	    $self->{_logger}->debug("Setting login user: $self->{_user} password: $self->{_password} server: $self->{_server} default db: $self->{_db}");
	    $self->{_backend}->set_login($self->{_user},$self->{_password},$self->{_server},$self->{_db}) if($self->{_backend});
	}   

    }

    $self->_init_dbcache();

    $self->_init_termusage();

    if($ENV{ID_REPOSITORY}){
	$self->_init_idgenerator($ENV{ID_REPOSITORY});
    }

    if($ENV{NO_ID_GENERATOR}){
	$self->{_no_id_generator} = 1;
    }
    
    $self->{_backend}->{_gzip_bcp} = $self->{_gzip_bcp};

    $self->{_backend}->{_row_delimiter} = $self->{_row_delimiter};

    $self->{_backend}->{_field_delimiter} = $self->{_field_delimiter};
}


=item $obj->AUTOLOAD()

B<Description:> 

Retrieves

B<Parameters:> 

Parameters

B<Returns:> 

Returns

=cut

sub AUTOLOAD {
    # We're not interested in reporting the non-existence of a destructor.
    # This is intended to inform the developer that the method he tried to
    # call is not implemented in the modules. The package variable $AUTOLOAD
    # contains the method that was called, but that did not exist.
    return if $AUTOLOAD =~ m/DESTROY/;
    die "Sorry, but $AUTOLOAD is not defined.\n";
}

=item $obj->DESTROY()

B<Description:> 

Retrieves

B<Parameters:> 

Parameters

B<Returns:> 

Returns

=cut

sub DESTROY {
    my $self = shift;
    #end perf metrics here
}

=item $obj->getProjectDeps()

B<Description:> 

Retrieves

B<Parameters:> 

Parameters

B<Returns:> 

Returns

=cut

sub getProjectDeps{
    my($self) = @_;
    return $self->{_schema}.":".$self->{_vendor}.":".$self->{_server};
}


sub testPrism {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->{_backend}->testProjDB();
}


#----------------------------------------------------------------
# tableRecordCount()
#
#----------------------------------------------------------------
sub tableRecordCount {

    my ($self, $table) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("table was not defined") if (!defined($table));
    
    my @ret = $self->{_backend}->get_table_record_count($table);
    # get_table_record_count() executes the following query:
    # SELECT count(*) FROM $table
    
    $self->{_logger}->logdie("ret[0][0] was not defined") if (!defined($ret[0][0]));

    return ($ret[0][0]);
}


#----------------------------------------------------------------
# coding_regions
#
#----------------------------------------------------------------
sub coding_regions {

    my ($self, $asmbl_id, $qualified_model_lookup, $model_list_file) = @_;

    ## to retrieve coding region data

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    ## Set the max text size for sequence and protein data fields
    $self->{_backend}->do_set_textsize(TEXTSIZE);

    ## Retrieve the model data from the source database
    my @ret = $self->{_backend}->get_coding_regions($asmbl_id);


    ## Ensure that we retrieve and store only unique records
    my $model_lookup = {};

    my $return_models = {};
    
    for (my $i=0; $i<@ret; $i++) {
	
	my $model_feat_name = $ret[$i][0];
	
	if (! exists $model_lookup->{$model_feat_name} ) {

	    my ($end5, $end3, $complement) = &coordinates($ret[$i][2], $ret[$i][3]);

	    my $temphash = { 'feat_name'               => $model_feat_name,
			     'parent_feat_name'        => $ret[$i][1],
			     'end5'                    => $end5,
			     'end3'                    => $end3,
			     'complement'              => $complement,
			     'sequence'                => $ret[$i][4],
			     'protein'                 => $ret[$i][5],
			     'date'                    => $ret[$i][6],
			     'gene_annotation_curated' => $ret[$i][7]
			 };

	    if (defined($model_list_file)){
		## The user specified a model_list_file

		if ( exists $qualified_model_lookup->{$model_feat_name} ) {
		    ## Only qualified models are processed.
		    $return_models->{$model_feat_name} = $temphash;
		}
	    }
	    else {
		## All models are processed
		$return_models->{$model_feat_name} = $temphash;
	    }
	    
	    $model_lookup->{$model_feat_name}++;
	}
	else {
	    my $times = $model_lookup->{$model_feat_name} + 1;
	    
	    $self->{_logger}->warn("model '$model_feat_name' was already stored on model_lookup '$times' times");
	}
    }

    return $return_models;
}
#----------------------------------------------------------------
# organism_data 
#
#----------------------------------------------------------------
sub organism_data { 

    my ($self, $organism_database, $orgtype) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("organism_database was not defined") if (!defined($organism_database));

    # return hash
    my %s;


    #
    # Retrieve data from common..genomes
    #
    my @ret = $self->{_backend}->get_common_genomes_data($organism_database);


    if (!defined($ret[0][0])){
	$self->{_logger}->logdie("common..genomes.file_moniker was not defined for common..genomes.db = '$organism_database'");
    }
    if (!defined($ret[0][1])){
	$self->{_logger}->logdie("common..genomes.name was not defined for common..genomes.db = '$organism_database'");
    }
    if (!defined($ret[0][2])){
	$self->{_logger}->warn("common..genome.type was not defined for common..genomes.db = '$organism_database'");
    }

    $s{'abbreviation'}  = $ret[0][0]; # common..genomes.file_moniker	
    $s{'name'}          = $ret[0][1]; # common..genomes.name
    $s{'type'}          = $ret[0][2]; # common..genomes.type



    my @ret2 = $self->{_backend}->get_new_project_data();


    if (!defined($ret2[0][0])){
	$self->{_logger}->warn("new_project.taxon_id was not defined for database '$organism_database'");
    }
    else {
	$s{'taxon_id'} = $ret2[0][0]; # new_project.taxon_id
    }

    if ($orgtype ne 'euk'){
	if (!defined($ret2[0][1])){
	    $self->{_logger}->warn("new_project.gram_stain was not defined for database '$organism_database'");
	}
	else{
	    $s{'gram_stain'}    = $ret[0][1]; # new_project.gram_stain
	}
	if (!defined($ret2[0][2])){
	    $self->{_logger}->warn("new_project.genetic_code was not defined for database '$organism_database'");
	}
	else {
	    $s{'genetic_code'}  = $ret[0][2]; # new_project.genetic_code
	}
    }


    return (\%s);
}

#----------------------------------------------------------------
# transcripts()
#
#----------------------------------------------------------------
sub transcripts { 

    my ($self, $asmbl_id, $qualified_tu_lookup, $tu_list_file) = @_;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    ## Set the max text size for sequence and protein data fields
    $self->{_backend}->do_set_textsize(TEXTSIZE);

    my $return_transcripts;
    my $i;

    ## Retrieve the TU data from the source database
    my @ret = $self->{_backend}->get_transcripts($asmbl_id);

    ## To ensure that we only retrieve and store unique TUs
    my $transcript_lookup = {};

    my $unqualifiedTuLookup = {};
    my $unqualifiedTuCtr=0;

    ## Iterate and process each retrieved TU
    for ($i=0; $i<@ret; $i++) {
	
	## feat_name
	my $tu_identifier = $ret[$i][0];
	
	## Verify if we've already processed this particular TU
 	if ( !(exists $transcript_lookup->{$tu_identifier})){
	    
	    ## Calculate the coordinates and strand
	    my ($end5, $end3, $complement) = &coordinates($ret[$i][2], $ret[$i][3]);
	    
	    my $temphash = { 'feat_name'              => $tu_identifier,
			     'asmbl_id'               => $ret[$i][1],
			     'end5'                   => $end5,
			     'end3'                   => $end3,
			     'complement'             => $complement,
			     'sequence'               => $ret[$i][4],
			     'locus'                  => $ret[$i][5],
			     'com_name'               => $ret[$i][6],
			     'date'                   => $ret[$i][7],	
			     'is_pseudogene'          => $ret[$i][8],	
			     'alt_locus'              => $ret[$i][9],
			     'pub_locus'              => $ret[$i][10],
			     'gene_structure_curated' => $ret[$i][11]
			 };

	    if (defined($tu_list_file)){
		## The user specified a tu-list-file
		
		if (exists $qualified_tu_lookup->{$tu_identifier}) {
		    ## Only qualified TUs are processed.
		    $return_transcripts->{$tu_identifier} = $temphash;
		}
		else {
		    $unqualifiedTuLookup->{$tu_identifier}++;
		    $unqualifiedTuCtr++;
		}
	    }
	    else {
		## All TUs are processed
		$return_transcripts->{$tu_identifier} = $temphash;
	    }

	    ## To indicate that this TU has already been processed
	    $transcript_lookup->{$tu_identifier}++;
	}
	else {

	    ## Already encountered this particular TU
	    my $times = ++$transcript_lookup->{$tu_identifier};

	    $self->{_logger}->warn("TU '$tu_identifier' was already stored on transcript_lookup '$times' times");
	}
    }

    if (defined($tu_list_file)){
	if ($unqualifiedTuCtr>0){
	    $self->{_logger}->warn("Encountered a number of TUs that were not qualified by the user");
	    
	    foreach my $tu (sort keys %{$unqualifiedTuLookup}){
		$self->{_logger}->warn("$tu");
	    }
	}

	my $missingCtr=0;
	## Now verify that every TU specified by the user was extracted
	foreach my $qualifiedTu ( sort keys %{$qualified_tu_lookup}){
	    if (! exists $return_transcripts->{$qualifiedTu}){
		$missingCtr++;
		$self->{_logger}->error("TU '$qualifiedTu' was not extracted");
	    }
	}

	if ($missingCtr>0){
	    $self->{_logger}->logdie("The software could not extract '$missingCtr' TUs. ".
				     "Please review the log file.");
	}
    }

    return $return_transcripts;
}

#------------------------------------------------------------------
# coordinates()
#
#------------------------------------------------------------------
sub coordinates {

    my ($end5, $end3) = @_;

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

#----------------------------------------------------------------
# exons
#
#----------------------------------------------------------------
sub exons {
    
    my($self, $asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));

    my (@ret, %s, $i);
    @ret = $self->{_backend}->get_exons($asmbl_id);
    # the following query was execute in get_exons{}
    # SELECT f.feat_name,f2.feat_name,f.end5,f.end3, f.date
    # FROM asm_feature f, asm_feature f2, feat_link l, phys_ev p
    # WHERE f.feat_name = l.child_feat
    # AND f2.feat_name = l.parent_feat 
    # AND f2.feat_type = 'model' 
    # AND f.feat_type = 'exon' 
    # AND p.feat_name = f2.feat_name 
    # AND p.ev_type = 'working'
    # AND f.asmbl_id = ?

    for ($i=0; $i<@ret; $i++) {
        

	my ($end5, $end3, $complement) = &coordinates($ret[$i][2], $ret[$i][3]);

	$s{$i}->{'feat_name'}        = $ret[$i][0];
	$s{$i}->{'parent_feat_name'} = $ret[$i][1];
	$s{$i}->{'end5'}             = $end5;
	$s{$i}->{'end3'}             = $end3;
	$s{$i}->{'complement'}       = $complement;
	$s{$i}->{'date'}             = $ret[$i][4];	
    }
    $s{'count'} = $i;

    return (\%s);
}    

#----------------------------------------------------------------
# org_id_to_seq_names
#
#----------------------------------------------------------------
sub org_id_to_seq_names {

    my($self, $org_id, $assembly_cvterm_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("$org_id was not defined")            if (!defined($org_id));
    $self->{_logger}->logdie("assembly_cvterm_id was not defined") if (!defined($assembly_cvterm_id));


    my(@ret, @s, $i);

    @ret = $self->{_backend}->get_org_id_to_seq_names($org_id, $assembly_cvterm_id);
    
    for($i=0; $i<@ret; $i++) {
        $s[$i]->{'seq_id'}   = $ret[$i][0];
        $s[$i]->{'seq_name'} = $ret[$i][1];
        $s[$i]->{'seq_type'} = $ret[$i][2];
	$s[$i]->{'length'}   = $ret[$i][3];	
    }
    return(\@s);
}

#----------------------------------------------------------------
# seq_id_to_CDS
#
#----------------------------------------------------------------
sub seq_id_to_CDS {

    my($self, $seq_id, $assembly_cvterm_id, $cds_cvterm_id, $polypeptide_cvterm_id, $transcript_cvterm_id, $derives_from_cvterm_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;


    $self->{_logger}->logdie("seq_id was not defined") if (!defined($seq_id));

        
    my $ret = $self->{_backend}->get_seq_id_to_CDS(
						   $seq_id,
						   $assembly_cvterm_id,
						   $cds_cvterm_id,
						   $polypeptide_cvterm_id,
						   $transcript_cvterm_id,
						   $derives_from_cvterm_id
						   );

    my @s;

    for (my $i=0; $i< @{$ret}; $i++) {
        $s[$i]->{'gene_id'}       = $ret->[$i][0];
        $s[$i]->{'transcript_id'} = $ret->[$i][1];
        $s[$i]->{'cds_id'}        = $ret->[$i][2];
        $s[$i]->{'prot_id'}       = $ret->[$i][3];
	$s[$i]->{'fmin'}          = $ret->[$i][4];
	$s[$i]->{'fmax'}          = $ret->[$i][5];
	$s[$i]->{'strand'}        = $ret->[$i][6];
	$s[$i]->{'protein'}       = $ret->[$i][7];
    }

    return(\@s);
}

#----------------------------------------------------------------
# seq_id_to_description
#
#----------------------------------------------------------------
sub seq_id_to_description {

    my($self, $seq_id, $assembly_cvterm_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;


    $self->{_logger}->logdie("seq_id was not defined") if (!defined($seq_id));
        
    my $ret = $self->{_backend}->get_seq_id_to_description(
							   $seq_id,
							   $assembly_cvterm_id
							   );
    my @s;

    for (my $i=0; $i < @{$ret}; $i++) {
        $s[$i]->{'seq_id'}   = $ret->[$i][0];
	$s[$i]->{'name'}     = $ret->[$i][1];
	$s[$i]->{'length'}   = $ret->[$i][2];
	$s[$i]->{'sequence'} = $ret->[$i][3];
	$s[$i]->{'topology'} = $ret->[$i][4];
    }
    
    return(\@s);
}


#----------------------------------------------------------------
# seq_id_to_description_2
#
#----------------------------------------------------------------
sub seq_id_to_description_2 {

    my($self, $seq_id, $assembly_cvterm_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;


    $self->{_logger}->logdie("seq_id was not defined")           if (!defined($seq_id));
    $self->{_logger}->warn("assembly_cvterm_id was not defined") if (!defined($assembly_cvterm_id));


    my($ret, @s, $i);
        
    $ret = $self->{_backend}->get_seq_id_to_description_2($seq_id, $assembly_cvterm_id);

    for ($i=0; $i< @{$ret} ; $i++) {
        $s[$i]->{'seq_id'}   = $ret->[$i][0];
	$s[$i]->{'name'}     = $ret->[$i][1];
	$s[$i]->{'length'}   = $ret->[$i][2];
	$s[$i]->{'topology'} = $ret->[$i][3];
    }

    $self->{_logger}->debug("Values returned from ChadoPrismDB::get_seq_id_to_description:\n" . Dumper $ret) if $self->{_logger}->is_debug;

    return(\@s);
}

#----------------------------------------------------------------
# seq_id_to_genes
#
#----------------------------------------------------------------
sub seq_id_to_genes {

    my($self, $seq_id, $assembly_cvterm_id, $gene_cvterm_id, $part_of_cvterm_id, $transcript_cvterm_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("seq_id was not defined") if (!defined($seq_id));
    
    
    my $ret = $self->{_backend}->get_seq_id_to_genes(
						     $seq_id,
						     $assembly_cvterm_id, 
						     $gene_cvterm_id, 
						     $part_of_cvterm_id, 
						     $transcript_cvterm_id
						     );
    
    my @s;

    for (my $i=0  ; $i < @{$ret}  ; $i++) {
	$s[$i]->{'gene_id'}       = $ret->[$i][0];
	$s[$i]->{'transcript_id'} = $ret->[$i][1];
	$s[$i]->{'fmin'}          = $ret->[$i][2];
	$s[$i]->{'fmax'}          = $ret->[$i][3];
	$s[$i]->{'strand'}        = $ret->[$i][4];
    }
    return(\@s);
}

#----------------------------------------------------------------
# seq_id_to_exons
#
#----------------------------------------------------------------
sub seq_id_to_exons {

    my($self, $seq_id, $assembly_cvterm_id, $exon_cvterm_id, $transcript_cvterm_id, $part_of_cvterm_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;


    $self->{_logger}->logdie("seq_id was not defined") if (!defined($seq_id));


        
    my $ret = $self->{_backend}->get_seq_id_to_exons(
						     $seq_id,
						     $assembly_cvterm_id,
						     $exon_cvterm_id,
						     $transcript_cvterm_id,
						     $part_of_cvterm_id
						     );

    my @s;

    for (my $i=0; $i < @{$ret}; $i++) {
	$s[$i]->{'gene_id'}       = $ret->[$i][0];
	$s[$i]->{'transcript_id'} = $ret->[$i][1];
	$s[$i]->{'exon_id'}       = $ret->[$i][2];
	$s[$i]->{'fmin'}          = $ret->[$i][3];
	$s[$i]->{'fmax'}          = $ret->[$i][4];
	$s[$i]->{'strand'}        = $ret->[$i][5];
    }
    
    return(\@s);
}




#----------------------------------------------------------------
# feature_orgseq()
#
# used by: chado_prism/bsmlqa.pl
#
#----------------------------------------------------------------
sub feature_orgseq {

    my($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
        
    return $self->{_backend}->get_feature_orgseq();
}

#----------------------------------------------------------------
# master_feature_id_lookup()
#
#----------------------------------------------------------------
sub master_feature_id_lookup {

    my($self, $doctype) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
        

    my $chromosome = $self->check_cvterm_id_by_class_lookup( class => 'chromosome');

    $self->{_logger}->logdie("cvterm_id was not defined for class 'chromosome'") if (!defined($chromosome));

    return $self->{_backend}->get_master_feature_id_lookup($doctype, $chromosome);

}

#----------------------------------------------------------------
# uniquename_2_feature_id()
#
#----------------------------------------------------------------
sub uniquename_2_feature_id {

    my($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    my($ret, @s, $i);
        
    $ret = $self->{_backend}->get_uniquename_2_feature_id();

    for ($i=0; $i<scalar(@$ret); $i++) {
	$s[$i]->{'feature_id'}  = $ret->[$i][0];
	$s[$i]->{'uniquename'}  = $ret->[$i][1];
    }
    return \@s;
}



#----------------------------------------------------------------
# db_to_seq_names()
#
#----------------------------------------------------------------
sub db_to_seq_names {

    my ($self, $db, $assembly_cvterm_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;


    if (!defined($db)){
	$self->{_logger}->warn("db was not defined");
    }
    if (!defined($assembly_cvterm_id)){
	$self->{_logger}->warn("assembly_cvterm_id was not defined");
    }

    my(@ret, @s, $i);

    @ret = $self->{_backend}->get_db_to_seq_names($db, $assembly_cvterm_id);
    
    for($i=0; $i<@ret; $i++) {
        $s[$i]->{'seq_id'}   = $ret[$i][0];
        $s[$i]->{'seq_name'} = $ret[$i][1];
        $s[$i]->{'seq_type'} = $ret[$i][2];
	$s[$i]->{'length'}   = $ret[$i][3];	
    }
    return(\@s);
}



#----------------------------------------------------------------
# max_table_id
#
#----------------------------------------------------------------
sub max_table_id {

    my ($self, $table, $key) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;


    $self->{_logger}->logdie("table was not defined") if (!defined($table));
    $self->{_logger}->logdie("key was not defined")   if (!defined($key));
    

    my @ret = $self->{_backend}->getMaxId($table, $key);
    # get_max_table_id() executes the following query:
    # SELECT max_id($id) 
    # FROM $table
    
    if (defined($ret[0][0])){
	return 0 if ($ret[0] == 0);
	return ($ret[0][0]);
    }
    else {
	return 0;
    }
}

#----------------------------------------------------------------
# protein_2_contig_localization()
#
#----------------------------------------------------------------
sub protein_2_contig_localization {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

   
    my (@ret, $i);
    @ret = $self->{_backend}->get_protein_2_contig_localization();
    # get_protein_2_contig_localization() executes the following query:
    #
    # SELECT p.feature_id,a.feature_id,fl.fmin,fl.is_fmin_partial,fl.fmax,fl.is_fmax_partial,fl.strand,fl.phase,fl.residue_info,fl.locgroup,fl.rank
    # FROM feature c, feature a, feature p, feature_relationship fp, featureloc fl
    # WHERE fp.subject_id = p.feature_id
    # AND fp.object_id = c.feature_id
    # AND fp.type_id = 24
    # AND c.feature_id = fl.feature_id
    # AND a.feature_id = fl.srcfeature_id
    # AND a.type_id = 5
    # AND p.type_id = 16
    # AND c.type_id = 55


    $self->{_logger}->logdie("Please note that there were no protein records to retrieve from $self->{_db}, and thus no protein localizations will be inserted into the featureloc table") if ($ret[0] == 0);


    my $s = ();
    for($i=0; $i<@ret; $i++) {
        $s->[$i]->{'pfeature_id'}     = $ret[$i][0];
        $s->[$i]->{'afeature_id'}     = $ret[$i][1];
        $s->[$i]->{'fmin'}            = $ret[$i][2];
	$s->[$i]->{'is_fmin_partial'} = $ret[$i][3];	
        $s->[$i]->{'fmax'}            = $ret[$i][4];
        $s->[$i]->{'is_fmax_partial'} = $ret[$i][5];
        $s->[$i]->{'strand'}          = $ret[$i][6];
        $s->[$i]->{'phase'}           = $ret[$i][7];
        $s->[$i]->{'residue_info'}    = $ret[$i][8];
        $s->[$i]->{'locgroup'}        = $ret[$i][9];
        $s->[$i]->{'rank'}            = $ret[$i][10];
    }
    return($s);

}



#----------------------------------------------------------------
# cvterm_id()
#
#----------------------------------------------------------------
sub cvterm_id {

    my($self, $name) = @_;
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($name)){
	$self->{_logger}->logdie("name was not defined");
    }

    my $ret = $self->{_backend}->get_cvterm_id($name);
    if (!defined($ret)){
	$self->{_logger}->logdie("ret was not defined for name '$name'");
    }

    return  $ret;
}

#----------------------------------------------------------------
# source_database_to_organism_rows()
#
#----------------------------------------------------------------
sub source_database_to_organism_rows {

    my($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;



    my $ret = $self->{_backend}->get_source_database_to_organism_rows();
    
    my @s;

    my $val = $ret->[0][0];

    if (length($val) <1){
	return 0;
    }
    if ((defined($ret)) and ($ret->[0][0] ne "0")){ 
	for (my $i=0; $i<scalar(@$ret); $i++) {
       	    $s[$i]->{'genus'}   = $ret->[$i][0];
	    $s[$i]->{'species'} = $ret->[$i][1];
	    $s[$i]->{'name'}    = $ret->[$i][2];
	    $s[$i]->{'abbreviation'}    = $ret->[$i][3];
	}
    }
    return \@s;

}



#----------------------------------------------------------------
# protein_assembly_lookup()
#
#----------------------------------------------------------------
sub protein_assembly_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
   
    my (@ret, $i);
    @ret = $self->{_backend}->get_protein_assembly_lookup();
    
    #
    # get_protein_assembly_lookup() executes the following query:
    #
    # SELECT fl.feature_id, fl.srcfeature_id
    # FROM feature a, feature p, featureloc fl, cvterm cva, cvterm cvp
    # WHERE fl.feature_id = p.feature_id
    # AND p.type_id = cvp.cvterm_id
    # and cvp.name = 'polypeptide'
    # AND fl.srcfeature_id = a.feature_id
    # AND a.type_id = cva.cvterm_id
    # AND cva.name = 'assembly'


    my $s = {};

    if ($ret[0] == 0){
	$self->{_logger}->debug("Please note that there were no polypeptide previously stored polypeptide localization records to retrieve from $self->{_db}"); 
	return $s;
    }

    for($i=0; $i<@ret; $i++) {


        my $pfeature_id = $ret[$i][0];
        my $afeature_id = $ret[$i][1];

	$self->{_logger}->logdie("pfeature_id was not defined") if (!defined($pfeature_id));
	$self->{_logger}->logdie("afeature_id was not defined") if (!defined($afeature_id));

	$s->{$pfeature_id} = $afeature_id;


    }


    return $s;

}



#----------------------------------------------------------------
# assembly_feature_id_lookup()
#
#----------------------------------------------------------------
sub assembly_feature_id_lookup {

    my($self) = @_;
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    my @s;

    my $ret = $self->{_backend}->get_assembly_feature_id_lookup();

    for (my $i=0; $i<scalar(@$ret); $i++) {
	$s[$i]->{'feature_id'}  = $ret->[$i][0];
	$s[$i]->{'uniquename'}  = $ret->[$i][1];
	$s[$i]->{'organism_id'} = $ret->[$i][2];
	$s[$i]->{'chromosome'}  = $ret->[$i][3];
	
    }

    return \@s;
}



#----------------------------------------------------------------
# store_cv_table()
#
#----------------------------------------------------------------
sub store_cv_table {

    my ($self, %parameter) = @_;
    my $phash = \%parameter;

    my $cv = $phash->{'cv'};

    my $defaultNamespace;

    if ((exists $cv->{'default-namespace'}) && (defined($cv->{'default-namespace'}))) {
    
	$defaultNamespace = $cv->{'default-namespace'};
    }
    else {
	$self->{_logger}->logdie("The default-namespace was not defined");
    }

    my $appendmode=0;

    my $cv_id = $self->check_cv_id_lookup( name => $defaultNamespace );

    if (defined($cv_id)){
	#
	# This name was inserted into the chado.cv table during a previous session.
	# Perhaps the user intends to update this ontology.
	#
	$self->{_logger}->warn("Looks like you are attempting to append additional ".
			       "ontology data in the Chado CV Module for ontology ".
			       "cv_id '$cv_id' name '$defaultNamespace'");

	$appendmode = 1;
	
    }
    else {
	my $definition;

	## Generate a cv record for this default-namespace
	$cv_id = $self->{_backend}->do_store_new_cv(
						    name       => $defaultNamespace,
						    definition => $definition
						    );

	if (!defined($cv_id)){
	    $self->{_logger}->logdie("cv_id was not defined.  Could not insert record into ".
				     "chado.cv for name '$defaultNamespace' definition ".
				     "'$definition'");
	}
    }



    my $db_id = $self->check_db_id_lookup( name => $defaultNamespace );

    if (defined($db_id)) {
	#
	# This name was inserted into the chado.db table during a previous session.
	#
	$self->{_logger}->warn("Looks like you are attempting to append additional ontology ".
			       "data in the Chado \"DBxref\" tables for db_id '$db_id' name ".
			       "'$defaultNamespace' cv_id '$cv_id' name '$defaultNamespace'");    
    }
    else {
	## Generate a db record for this default-namespace
	$db_id = $self->{_backend}->do_store_new_db(
						    name        => $defaultNamespace,
						    description => undef,
						    urlprefix   => undef,
						    url         => undef,
						    );
	
	if (!defined($db_id)){
	    $self->{_logger}->logdie("db_id was not defined.  Could not insert record into ".
				     "chado.db for name '$defaultNamespace'");
	}
    }


    return ($cv_id, $db_id, $defaultNamespace, $appendmode);
}


#----------------------------------------------------------------
# store_cv_module()
#
#----------------------------------------------------------------
sub store_cv_module {

    my ($self, %parameter) = @_;
    my $phash = \%parameter;

    my $cv_id      = $phash->{'cv_id'}       if ((exists $phash->{'cv_id'})      and defined($phash->{'cv_id'}));
    my $cv         = $phash->{'cv'}          if ((exists $phash->{'cv'})         and defined($phash->{'cv'}));
    my $db_id      = $phash->{'db_id'}       if ((exists $phash->{'db_id'})      and defined($phash->{'db_id'}));
    my $terms      = $phash->{'terms'}       if ((exists $phash->{'terms'})      and defined($phash->{'terms'}));
    my $term_count = $phash->{'term_count'}  if ((exists $phash->{'term_count'}) and defined($phash->{'term_count'}));
    my $dbname     = $phash->{'dbname'}      if ((exists $phash->{'dbname'})     and defined($phash->{'dbname'}));
    my $typedef    = $phash->{'typedef'}     if ((exists $phash->{'typedef'})    and defined($phash->{'typedef'}));
    my $appendmode = $phash->{'appendmode'}  if ((exists $phash->{'appendmode'}) and defined($phash->{'appendmode'}));
    my $new_typedef_lookup    = $phash->{'new_typedef_lookup'}     if ((exists $phash->{'new_typedef_lookup'})    and defined($phash->{'new_typedef_lookup'}));
    my $cvterm_max_is_obsolete_lookup = $phash->{'cvterm_max_is_obsolete_lookup'}     if ((exists $phash->{'cvterm_max_is_obsolete_lookup'})    and defined($phash->{'cvterm_max_is_obsolete_lookup'}));
    my $ignore_relationships  = $phash->{'ignore_relationships'}     if ((exists $phash->{'ignore_relationships'})    and defined($phash->{'ignore_relationships'}));
    

    my $defmax = 0;

    #
    # Verify whether objects are defined
    #
    if (!defined($cv)){
	$self->{_logger}->logdie("cv was not defined");
    }
    if (!defined($cv_id)){
	$self->{_logger}->logdie("cv_id was not defined");
    }
    if (!defined($db_id)){
	$self->{_logger}->logdie("db_id was not defined");
    }
    if (!defined($terms)){
	$self->{_logger}->logdie("terms was not defined");
    }


    my $comment_cvterm_id = $self->cvterm_id_by_name('comment');

    ## The OBO2Chado.pl loader should create cvterm_relationship records for all of these typedefs.
    ## Here we retrieve all of the typedef's cvterm_ids from the database.
    my $typedef_lookup = {};


    if ($typedef == 1){
	#
	# Means we are processing the relationship.obo type definition file
	#
    }
    else{
	
	#
	# select c.name, cvterm_id from cvterm c, cv where cv.name = 'relationship' and cv.cv_id = c.cv_id and c.is_relationshiptype = 1
	#
	$typedef_lookup = $self->typedef_lookup();

	$self->store_additional_typedef_records($typedef_lookup,
						$cv,
						$new_typedef_lookup,
						$cv_id,
						$db_id);

    }



    #-------------------------------------------------------------------------------------------------------
    # In this section <2> we attempt to store data in
    # 1) chado.cvterm                     <2.1> 
    # 2) chado.dbxref (if required)       <2.2>
    # 3) chado.cvtermsynonym              <2.3>
    # 4) chado.cvterm_dbxref              <2.4>
    #    4.1) chado.dbxref (if required)  <2.4.1>
    #    4.2) chado.db     (if required)  <2.4.2>
    # 5) we also generate cvterm-ontology identifier lookups <2.5>
    #-------------------------------------------------------------------------------------------------------

    #
    # Define cvterm and ontology identifier lookups for cvterm_relationship section <2.5>
    #
    my ($cvterm2id, $id2cvterm) = $self->retrieve_id2cvterm($appendmode);
    my $obsolete  = {};

    #
    # We maintain an obsoleted term name counter since there could be many obsoleted OBO records
    # with the same term name.
    my $name_obsolete_lookup = {};

    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = $term_count;
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter == 0);
 
    printf "\n%-60s   %-12s     0%", qq!Processing Ontology terms:!, "[". " "x$bars . "]";

    #
    # process each ontology term (ot)
    #
    foreach my $ot (sort keys %$terms){

	$row_count++;
	$self->show_progress("Processing Ontology terms $row_count/$term_count",$counter,$row_count,$bars,$total_rows);

	#
	# Extract the 'name' which will be stored in chado.cvterm.name
	#
	my $name;
	if ((exists $terms->{$ot}->{'name'}) and (defined($terms->{$ot}->{'name'})) ){
	    $name = $terms->{$ot}->{'name'};
	}
	else {
	    $self->{_logger}->error("name was not defined for $ot");
	    next;
	}

	#
	# Extract the 'def' which will be stored in chado.cvterm.definition
	#
	my $definition = $self->verify_obsolete_cvterm_definition( $terms,
								   $ot,
								   $obsolete );
	#
	# to determine the largest definition
	#
	if (length($definition) > $defmax){
	    $defmax = length($definition);
	}
    
	my $is_obsolete = 0;
	
	if ((exists $terms->{$ot}->{'is_obsolete'}) and (defined($terms->{$ot}->{'is_obsolete'}))){
	    $is_obsolete = $terms->{$ot}->{'is_obsolete'};
	}
	
	#-----------------------------------------------------------------------------
	# Prepare data for insertion into chado.cvterm <2.1>
	#
	# Retrieve/store cvterm_id for this term
	# table: chado.cvterm.cvterm_id
	#-----------------------------------------------------------------------------
	
	# cvterm.is_obsolete has been changed from BIT to TINYINT datatype
	# This will allow us to store multiple versions of obsoleted terms

	my $cvterm_id;
	
	($cvterm_id, $is_obsolete) = $self->verify_obsolete_term( $cv_id,
								  $name,
								  $cvterm_id,
								  $cvterm_max_is_obsolete_lookup,
								  $appendmode,
								  $is_obsolete,
								  $name_obsolete_lookup);

	if (!defined($cvterm_id)){

	    ## Here we attempt to store records in db and dbxref tables.  
	    my $db_id = $self->prepare_db_record($dbname);

	    my $dbxref_id;
	    
	    if (defined($db_id)){
		
		#--------------------------------------------------------------------------------------------------------------
		# Attempt to retrieve dbxref_id from the database <2.2>
		#
		#
		$dbxref_id = $self->prepare_dbxref_record( $db_id,
							   $ot,
							   $cv->{'format-version'} );
		
		if (!defined($dbxref_id)){
		    $self->{_logger}->logdie("dbxref_id was not defined.  Cannot insert records into CV module for db_id '$db_id' id:/accession '$ot'");
		}
	    }
	    else {
		$self->{_logger}->logdie("db_id was not defined for name '$dbname'");
	    }

	    $cvterm_id = $self->prepare_cvterm_record($cv_id, 
						      $name, 
						      $definition, 
						      $dbxref_id,
						      $is_obsolete, 
						      $typedef);
	    
	    if (!defined($cvterm_id)){
		$self->{_logger}->logdie("cvterm_id was not defined for cv_id '$cv_id' name '$name' definition '$definition' dbxref_id '$dbxref_id' is_obsolete '$is_obsolete' is_relationshiptype '$typedef'");
	    }
	}
 	
	if ($ignore_relationships != 1){
	    if ($typedef != 1){
		#
		# Currently only loading cvterm_relationship records for all ontologies excluding the relationship typedef ontology.
		#
		$self->store_id_cvterm_lookups($cvterm_id, $ot, $cvterm2id, $id2cvterm, $appendmode, $name);
	    }
	}

	#
	# Prepare comment for insertion into chado.cvtermprop
	#
	$self->store_comment_in_cvtermprop($terms, $ot, $cvterm_id, $comment_cvterm_id);

	#
	# Prepare synonym data for insertion into chado.cvtermsynonym <2.3>
	#
	$self->store_synonym_in_cvtermsynonym($terms, $ot, $cvterm_id );

	#
	# Prepare cross reference data for insertion into chado.cvterm_dbxref <2.4>
	#	
	foreach my $xrefType ('xref', 'xref_analog'){
	    $self->storeOBOXrefInChado($cvterm_id, $ot, $terms, $xrefType);
	}

	#
	# Prepare alt_id for insertion into chado.cvterm_dbxref
	#
	$self->store_alt_id($db_id, $cvterm_id, $ot, $terms);


    }#end foreach my $ot (sort keys %$terms)
    
    if ($ignore_relationships != 1){
	if ($typedef != 1){
	    #
	    # Currently only loading cvterm_relationship records for all ontologies excluding the relationship typedef ontology.
	    #
	    $self->store_relationships_in_cvterm_relationship($terms, $cvterm2id, $id2cvterm, $typedef_lookup, $term_count);
	}
    }
    

}#end sub store_cv_module()


#----------------------------------------------------------------
# storeTypedefRecordsInChadoCVModule()
#
#----------------------------------------------------------------
sub storeTypedefRecordsInChadoCVModule {

    my ($self, $headerLookup, $typedefLookup, $cv_id, $db_id,
	$appendMode, $isRelationshipOntology, $loadedTypedefLookup) = @_;

    ## To be implemented:
    ## Support for storing records in:
    ## cvterm_relationship
    ## cvtermprop
    ## cvtermsynonym
    ## cvterm_dbxref


    ## Verify whether objects are defined
    if (!defined($headerLookup)){
	$self->{_logger}->logdie("headerLookup was not defined");
    }
    if (!defined($typedefLookup)){
	$self->{_logger}->logdie("terms was not defined");
    }
    if (!defined($cv_id)){
	$self->{_logger}->logdie("cv_id was not defined");
    }
    if (!defined($db_id)){
	$self->{_logger}->logdie("db_id was not defined");
    }
    if (!defined($appendMode)){
	$self->{_logger}->logdie("appendMode was not defined");
    }
    if (!defined($isRelationshipOntology)){
	$self->{_logger}->logdie("isRelationshipOntology was not defined");
    }
    if (!defined($loadedTypedefLookup)){
	$self->{_logger}->logdie("loadedTypedefLookup was not defined");
    }

    ## The obo2chado.pl should create cvterm_relationship records for all of these typedefs.
    ## Here we retrieve all of the Typedefs' cvterm_id values from the database (bug 2191).

    if ($isRelationshipOntology != 1 ){
	## We are not processing relationship.obo, therefore
	## we need to retrieve the db_id for the relationship
	## ontology which was stored during a previous
	## session.
	$db_id = $self->check_db_id_lookup( name => 'relationship' );
    }

    ## Retrieve the db.db_id and set the dbxref.version for the new inbound typedef terms
    my $version = $headerLookup->{'format-version'};

    foreach my $typedef ( keys %{$typedefLookup} ) {
	
	my $name = $typedefLookup->{$typedef}->{'name'};

	if (! (exists $loadedTypedefLookup->{$name} )) {
	    ## Need to load this typedef into chado 

	    if ($isRelationshipOntology != 1){
		$self->{_logger}->warn("This Typedef '$name' was not previously loaded");
	    }

	    my $dbxref_id = $self->prepare_dbxref_record( $db_id,
							  $typedef,
							  $version );
	    
	    my $definition = $typedefLookup->{$typedef}->{'def'};
	    my $is_obsolete = $typedefLookup->{$typedef}->{'is_obsolete'};
	    
	    if (!defined($is_obsolete)){
		$is_obsolete = 0;
	    }
		
	    my $cvterm_id = $self->{_backend}->do_store_new_cvterm( cv_id        => $cv_id,
								    name         => $name,
								    definition   => $definition,
								    dbxref_id    => $dbxref_id,
								    is_obsolete  => $is_obsolete,
								    is_relationshiptype => 1 );
	    
	    if (!defined($cvterm_id)){
		$self->{_logger}->logdie("Unable to insert record into chado.cvterm.  ".
					 "cvterm_id was not defined for cv_id '$cv_id' ".
					 "name '$name' definition '$definition' dbxref_id ".
					 "'$dbxref_id' is_obsolete '$is_obsolete' ".
					 "is_relationshiptype '1'");
	    }

	    ## Store the cvterm_id for this Typedef in the loadedTypedefLookup
	    $loadedTypedefLookup->{$name}->{'cvterm_id'} = $cvterm_id;
	}
	else {
	    $self->{_logger}->warn("This Typedef '$name' was previously loaded");
	}
    }

}#end sub storeTypedefRecordsInChadoCVModule()


#----------------------------------------------------------------
# storeTermRecordsInChadoCVModule()
#
#----------------------------------------------------------------
sub storeTermRecordsInChadoCVModule {

    my ($self, $headerLookup, $termLookup, $cv_id, $db_id, $defaultNamespace,
	$appendMode, $loadedTypedefLookup, $maxIsObsoleteCvtermLookup, $ignoreRelationships, $respectNamespace ) = @_;

    if (!defined($headerLookup)){
	$self->{_logger}->logdie("headerLookup was not defined");
    }
    if (!defined($termLookup)){
	$self->{_logger}->logdie("termLookup was not defined");
    }
    if (!defined($cv_id)){
	$self->{_logger}->logdie("cv_id was not defined");
    }
    if (!defined($db_id)){
	$self->{_logger}->logdie("db_id was not defined");
    }
    if (!defined($defaultNamespace)){
	$self->{_logger}->logdie("defaultNamespace was not defined");
    }
    if (!defined($appendMode)){
	$self->{_logger}->logdie("appendMode was not defined");
    }
    if (!defined($loadedTypedefLookup)){
	$self->{_logger}->logdie("loadedTypedefLookup was not defined");
    }
    if (!defined($maxIsObsoleteCvtermLookup)){
	$self->{_logger}->logdie("maxIsObsoleteCvtermLookup was not defined");
    }
    if (!defined($ignoreRelationships)){
	$self->{_logger}->logdie("ignoredRelationships was not defined");
    }

    ## In this section <2> we attempt to store data in
    ## 1) chado.cvterm                     <2.1> 
    ## 2) chado.dbxref (if required)       <2.2>
    ## 3) chado.cvtermsynonym              <2.3>
    ## 4) chado.cvterm_dbxref              <2.4>
    ##    4.1) chado.dbxref (if required)  <2.4.1>
    ##    4.2) chado.db     (if required)  <2.4.2>
    ## 5) we also generate cvterm-ontology identifier lookups <2.5>


    ## Define cvterm and ontology identifier lookups for cvterm_relationship section <2.5>
    my ($cvterm2id, $id2cvterm) = $self->retrieve_id2cvterm($appendMode);

    my $obsolete  = {};

    ## We maintain an obsoleted term name counter since there could be many obsoleted OBO records
    ## with the same term name.
    my $obsoleteNameLookup = {};

    ## The number of Term records
    my $termCount = scalar( keys %{$termLookup});

    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $rowCount = 0;
    my $bars = 30;
    my $total_rows = $termCount;
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter == 0);
 
    printf "\n%-60s   %-12s     0%", qq!Processing Ontology terms:!, "[". " "x$bars . "]";


    ## Keep track of longest definition
    my $maxLengthDefinition = 0;

    ## Retrieve the cvterm_id for term 'comment'
    my $commentCvtermId = $self->cvterm_id_by_name('comment');

    ## We are not processing Term records
    my $is_relationshiptype = 0;

    ## Keep record of original default-namespace cv_id and db_id
    my $defaultCvId = $cv_id;
    my $defaultDbId = $db_id;

    #
    # process each ontology term (ot)
    #
    foreach my $termId (sort keys %{$termLookup}){

	$rowCount++;

	$self->show_progress("Processing Ontology terms $rowCount/$termCount",
			     $counter,$rowCount,$bars,$total_rows);

	## Extract the 'name' which will be stored in chado.cvterm.name
	my $name;

	if (exists $termLookup->{$termId}->{'name'}) {
	    $name = $termLookup->{$termId}->{'name'};
	}
	else {
	    $self->{_logger}->logdie("name was not defined for id '$termId'");
	}

	## Extract the 'namespace'
	my $namespace;

	if (($respectNamespace) && (exists $termLookup->{$termId}->{'namespace'})) {
	    
	    $namespace = $termLookup->{$termId}->{'namespace'};
	    
	    if ($namespace ne $defaultNamespace){

		## Retrieve the cv_id associated with the specified namespace
		$cv_id = $self->{_backend}->get_cv_id_by_name($namespace);
		if (! defined ($cv_id)){
		    ## Generate a cv record for this namespace
		    $cv_id = $self->{_backend}->do_store_new_cv( name => $namespace);
		}

		## Retrieve the db_id associated with the specified namespace
		$db_id = $self->{_backend}->get_db_id_by_name($namespace);
		if (! defined ($db_id)){
		    ## Generate a db record for this namespace
		    $db_id = $self->{_backend}->do_store_new_db( name => $namespace);
		}
	    }
	}
	else {
	    ## If the namespace for this Term was not defined,
	    ## then need to assign the default-namespace
	    $namespace = $defaultNamespace;
	}
	
	#
	# Extract the 'def' which will be stored in chado.cvterm.definition
	#
	my $definition = $self->verify_obsolete_cvterm_definition( $termLookup,
								   $termId,
								   $obsolete );

	# Keep track of longest definition
	if (length($definition) > $maxLengthDefinition){
	    $maxLengthDefinition = length($definition);
	}
    
	my $is_obsolete = 0;
	
	if ((exists $termLookup->{$termId}->{'is_obsolete'}) &&
	    (defined($termLookup->{$termId}->{'is_obsolete'}))){
	    $is_obsolete = $termLookup->{$termId}->{'is_obsolete'};
	}
	
	#-----------------------------------------------------------------------------
	# Prepare data for insertion into chado.cvterm <2.1>
	#
	# Retrieve/store cvterm_id for this term
	# table: chado.cvterm.cvterm_id
	#-----------------------------------------------------------------------------
	
	# cvterm.is_obsolete has been changed from BIT to TINYINT datatype
	# This will allow us to store multiple versions of obsoleted terms

	my $cvterm_id;
	
	($cvterm_id, $is_obsolete) = $self->verifyObsoleteTerm( $cv_id,
								$name,
								$maxIsObsoleteCvtermLookup,
								$appendMode,
								$is_obsolete,
								$obsoleteNameLookup);
	
	if (!defined($cvterm_id)){

	    ## The cv and db records would have been already slotted during this session.
	    ## Need to slot dbxref and cvterm records.

	    my $dbxref_id;
	    
	    ## Attempt to retrieve dbxref_id from the database <2.2>
	    $dbxref_id = $self->prepare_dbxref_record( $db_id,
						       $termId,
						       $headerLookup->{'format-version'} );
	    
	    if (!defined($dbxref_id)){
		$self->{_logger}->warn("Could not slot a dbxref record for Term id '$termId ".
				       "with db_id '$db_id'");
	    }

	    $cvterm_id = $self->prepare_cvterm_record($cv_id, 
						      $name, 
						      $definition, 
						      $dbxref_id,
						      $is_obsolete, 
						      $is_relationshiptype);
	    
	    if (!defined($cvterm_id)){
		$self->{_logger}->logdie("cvterm_id was not defined for cv_id '$cv_id' ".
					 "name '$name' definition '$definition' dbxref_id ".
					 "'$dbxref_id' is_obsolete '$is_obsolete' ".
					 "is_relationshiptype '$is_relationshiptype'");
	    }
	}
 	
	if ($ignoreRelationships != 1){
	    if ($is_relationshiptype != 1){
		
		## Currently only loading cvterm_relationship records for all ontologies
		## excluding the relationship typedef ontology.
		$self->store_id_cvterm_lookups($cvterm_id, $termId, $cvterm2id, $id2cvterm,
					       $appendMode, $name);
	    }
	}

	
	## Prepare comment for insertion into chado.cvtermprop
	if (( exists $termLookup->{$termId}->{'comment'}) &&
	    ( defined ($termLookup->{$termId}->{'comment'} ) )) {
	    
	    my $comment = $termLookup->{$termId}->{'comment'};
	    
	    $self->prepare_cvtermprop_record( $cvterm_id,
					      $commentCvtermId,
					      $comment);
	}


	## Prepare synonym data for insertion into chado.cvtermsynonym <2.3>
	$self->store_synonym_in_cvtermsynonym($termLookup, $termId, $cvterm_id );

	## Prepare cross reference data for insertion into chado.cvterm_dbxref <2.4>
	foreach my $xrefType ('xref', 'xref_analog'){
	    $self->storeOBOXrefInChado($cvterm_id, $termId, $termLookup, $xrefType);
	}

	## Prepare alt_id for insertion into chado.cvterm_dbxref
	$self->store_alt_id($db_id, $cvterm_id, $termId, $termLookup);


	## Set the original cv_id and db_id for the default-namespace
	$cv_id = $defaultCvId;
	$db_id = $defaultDbId;

    }#end foreach my $termId (sort keys %$terms)
    
    if ($ignoreRelationships != 1){
	if ($is_relationshiptype != 1){
	    ## Currently only loading cvterm_relationship records for all
	    ## ontologies excluding the relationship typedef ontology.
	    $self->storeRelationshipsInCvtermRelationship( $termLookup, 
							   $cvterm2id,
							   $id2cvterm, 
							   $loadedTypedefLookup,
							   $termCount );
	}
    }
    

}#end sub store_cv_module()



sub store_transitive_closure {

    my ($self, $terms, $id2cvterm_id, $typedef_lookup) = @_;

    my $alreadyprocessed = {};
    
    my $subject2object = $self->subject2object_lookup($terms, $typedef_lookup, $id2cvterm_id);

    foreach my $subject (reverse sort keys %{$terms}){
	
	if (exists $subject2object->{$subject}){

	    foreach my $hash ( @{$subject2object->{$subject}}){

		my $firsttypedef = $hash->{'typedef'};

		$self->{_logger}->warn("subject '$subject' firsttypedef '$firsttypedef'");

		$self->store_transitive_closure_in_cvterm_relationship($subject2object, $subject, $subject, $alreadyprocessed, $id2cvterm_id, $firsttypedef, $typedef_lookup);
	    }
	}
    }
}

sub subject2object_lookup {

    my ($self, $terms, $typedef_lookup, $id2cvterm_id) = @_;

    my $subject2object_lookup = {};

    foreach my $subject (sort keys %$terms){

	foreach my $typedef ( sort keys %{$typedef_lookup} ){
	    
	    foreach my $object (@{$terms->{$subject}->{$typedef}}){

		if (exists ($id2cvterm_id->{$object})){

		    push ( @{$subject2object_lookup->{$subject}},  { 'object' => $object,
								     'typedef' => $typedef });

		}
		else{
		    $self->{_logger}->logdie("$object was not exist in id2cvterm_id");
		}
	    }
 	}
    }

    return $subject2object_lookup;
}

sub store_transitive_closure_in_cvterm_relationship {

    my ($self, $subject2object, $subject, $node, $alreadyprocessed, $id2cvterm_id, $firsttypedef, $typedef_lookup) = @_;

    if (exists $subject2object->{$subject}){

	my $object;

	foreach my $hash ( @{$subject2object->{$subject}}){

	    $object = $hash->{'object'};

	    my $typedef = $hash->{'typedef'};

	    if (!defined($object)){ $self->{_logger}->logdie("object was not defined for subject '$subject'"); }
	    if (!defined($object)){ $self->{_logger}->logdie("typedef was not defined for subject '$subject'"); }

	    if (!exists $alreadyprocessed->{$node}->{$object}){
		
		$alreadyprocessed->{$node}->{$object}++;
	    
		my $subject_id = $id2cvterm_id->{$node};
		my $object_id  = $id2cvterm_id->{$object};
		my $type_id = $typedef_lookup->{$firsttypedef}->{'cvterm_id'};	

		my $cvterm_relationship_id = $self->prepare_cvterm_relationship_record( $subject_id,
											$object_id,
											$type_id );
		
		if (!defined($cvterm_relationship_id)){
		    $self->{_logger}->logdie("cvterm_relationship_id was not defined.  Could not insert record into chado.cvterm_relationship for relationship type '$firsttypedef'  subject $id2cvterm_id->{$subject_id} (subject_id:$subject_id), object $id2cvterm_id->{$object_id} (object_id:$object_id)");
		}
	    }
	}

	$subject = $object;

	$self->store_transitive_closure_in_cvterm_relationship($subject2object, $subject, $node, $alreadyprocessed, $id2cvterm_id, $firsttypedef, $typedef_lookup);
    }
    else {
	return;
    }
}

	
#-------------------------------------------------------------
# store_cvterm_relationships_exclusively()
#
#-------------------------------------------------------------
sub store_cvterm_relationships_exclusively {
    
    my ($self, $cv, $cv_id, $db_id, $terms, $dbname, $typedef, $appendmode, $typedef_lookup) = @_;

    my $relationship_typedef_lookup = $self->relationship_typedef_lookup();

    foreach my $id (keys %{$terms}){

	my $subject_id = $self->check_cvterm_id_by_dbxref_accession_lookup(cv_id => $cv_id, accession=>$id);

	if (defined($subject_id)){

	    foreach my $relationshiptype (keys %{$terms->{$id}}){
		
		if (exists $relationship_typedef_lookup->{$relationshiptype}){

		    my $type_id = $relationship_typedef_lookup->{$relationshiptype};

		    foreach my $object (@{$terms->{$id}->{$relationshiptype}}){

			my $object_id = $self->check_cvterm_id_by_dbxref_accession_lookup(cv_id => $cv_id, accession=>$object);

			if (defined($object_id)){

			    $self->prepare_cvterm_relationship_record($subject_id, $object_id, $type_id);
			}
			else {
			    $self->{_logger}->warn("object_id was not defined for dbxref.accession '$object'. ".
						   "It appears that the term with id '$object' does not exist in the ".
						   "target chado database, therefore a cvterm_relationship record will ".
						   "not be created for this record.");
			}
		    }

		}
		else {
		    $self->{_logger}->warn("cvterm_id was not defined for cvterm.name '$relationshiptype'");
		}
	    }
	}
	else {
	    $self->{_logger}->warn("cvterm_id was not defined for cv.cv_id '$cv_id' dbxref.accession '$id'. ".
				   "It appears that the term with id '$id' does not exist in the ".
				   "target chado database, therefore a cvterm_relationship record will ".
				   "not be created for this record.");
	}
    }
}




#-------------------------------------------------------------
# store_cvterm_relationships()
#
#-------------------------------------------------------------
sub store_cvterm_relationships{
    
    my ($self, $typedef_lookup, $id2cvterm) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;    

    foreach my $typedef (sort keys %{$typedef_lookup}) {
	
	my $relctr = $typedef_lookup->{$typedef}->{'counter'};
	my $type_id = $typedef_lookup->{$typedef}->{'cvterm_id'};	

	#-----------------------------------------------------------------
	# show_progress related data
	#
	#----------------------------------------------------------------
	my $row_count = 0;
	my $bars = 30;
	my $total_rows = $relctr;
	my $counter = int(.01 * $total_rows);
	$counter = 1 if($counter ==0);

	printf ("\n%-60s   %-12s     0%", qq!Storing '$typedef' relationships!, "[". " "x$bars . "]") if ($relctr > 0);
	
	if ((exists $typedef_lookup->{$typedef}->{'terms'}) && (defined($typedef_lookup->{$typedef}->{'terms'}))){
 
	    foreach my $subject_id (sort %{$typedef_lookup->{$typedef}->{'terms'}}){
		
		foreach my $object_id (@{$typedef_lookup->{$typedef}->{'terms'}->{$subject_id}}){
		    
		    $row_count++;

		    $self->show_progress("Storing '$typedef' relationships $row_count/$relctr",$counter,$row_count,$bars,$total_rows);
		    
		    my $cvterm_relationship_id = $self->prepare_cvterm_relationship_record( $subject_id,
											    $object_id,
											    $type_id );
		    
		    if (!defined($cvterm_relationship_id)){
			$self->{_logger}->logdie("cvterm_relationship_id was not defined.  Could not insert record into chado.cvterm_relationship for relationship type '$typedef'  subject $id2cvterm->{$subject_id} (subject_id:$subject_id), object $id2cvterm->{$object_id} (object_id:$object_id)");
		    }
		}
	    }
	}
    }
}

#-------------------------------------------------------------------------------------
# Function: retrieve_id2cvterm()
#
# Helper function for sub store_cv_tables()
#
# Processing: If we are procesing an OBO file in appendmode, then this function
#             will retrieve all dbxref.accession, cvterm.cvterm_id tuples and
#             create two lookups.
# Output: accession-to-cvterm_id hash, cvterm_id-to-accession hash
#
#-------------------------------------------------------------------------------------
sub retrieve_id2cvterm {

    my ($self, $appendmode) = @_;


    my $cvterm_id_2_accession = {};
    my $accession_2_cvterm_id = {};

    if ((defined($appendmode)) && ($appendmode == 1)){

	my $ret = $self->{_backend}->get_cvterm_id_to_accession();

	for (my $i=0; $i < scalar(@{$ret}) ; $i++){


	    #
	    # Build the id2cvterm lookup
	    #
	    if ((!exists $cvterm_id_2_accession->{$ret->[$i][0]}) && (!defined($cvterm_id_2_accession->{$ret->[$i][0]}))){
		$cvterm_id_2_accession->{$ret->[$i][0]} = $ret->[$i][1];
	    }
	    else{
		$self->{_logger}->logdie("Duplicate tuple detected for cvterm.cvterm_id '$ret->[$i][0]' and dbxref.accession '$ret->[$i][1]'");
	    }


	    #
	    # Build the accession_2_cvterm_id lookup
	    #
	    if ((!exists $accession_2_cvterm_id->{$ret->[$i][1]}) && (!defined($accession_2_cvterm_id->{$ret->[$i][1]}))){
		$accession_2_cvterm_id->{$ret->[$i][1]} = $ret->[$i][0];
	    }
	    else{
		$self->{_logger}->logdie("Duplicate tuple detected for cvterm.cvterm_id '$ret->[$i][0]' and dbxref.accession '$ret->[$i][1]'");
	    }
	}
    }



    return ($cvterm_id_2_accession, $accession_2_cvterm_id);
}

#----------------------------------------------------------------
# store_external_annotation_mappings()
#
#----------------------------------------------------------------
sub store_external_annotation_mappings {

    my ($self, %parameter) = @_;
    my $phash = \%parameter;

    $self->{_logger}->debug("Entered do_store_external_annotation_mappings") if $self->{_logger}->is_debug();

    my $map                     = $phash->{'mapping'}                 if (exists $phash->{'mapping'});
    my $map_count               = $phash->{'map_count'}               if (exists $phash->{'map_count'});
    my $version                 = $phash->{'version'}                 if (exists $phash->{'version'});
    my $description             = $phash->{'description'}             if (exists $phash->{'description'});
    my $lookup                  = $phash->{'lookup'}                  if (exists $phash->{'lookup'});
    my $dblookup                = $phash->{'dblookup'}                if (exists $phash->{'dblookup'});
    my $dbxref_id_lookup        = $phash->{'dbxref_id_lookup'}        if (exists $phash->{'dbxref_id_lookup'});
    my $cvterm_dbxref_lookup    = $phash->{'cvterm_dbxref_lookup'}    if (exists $phash->{'cvterm_dbxref_lookup'});
    
    if (!defined($map)){
	$self->{_logger}->logdie("map was not defined for parameter hash:" . Dumper $phash);
    }
    if (!defined($map_count)){
	$self->{_logger}->logdie("map_count was not defined for parameter hash:" . Dumper $phash);
    }
    if (!defined($version)){
	$self->{_logger}->logdie("version was not defined for parameter hash:" . Dumper $phash);
    }
    if (!defined($description)){
	$self->{_logger}->logdie("description was not defined for parameter hash:" . Dumper $phash);
    }
    if (!defined($lookup)){
	$self->{_logger}->logdie("lookup was not defined for parameter hash:" . Dumper $phash);
    }
    if (!defined($dblookup)){
	$self->{_logger}->logdie("dblookup was not defined for parameter hash:" . Dumper $phash);
    }
    if (!defined($dbxref_id_lookup)){
	$self->{_logger}->logdie("dbxref_id_lookup was not defined for parameter hash:" . Dumper $phash);
    }

    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = $map_count;
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);
	
    #
    # Process contents in map
    #
    foreach my $ext (sort keys %$map){


	$row_count++;
	$self->show_progress("Storing external annotation record $row_count/$total_rows",$counter,$row_count,$bars,$total_rows);


	$self->{_logger}->debug("Processing external annotation:" . Dumper($map->{$ext})) if $self->{_logger}->is_debug;


	my ($ext_dbname, $ext_accession, $ext_definition, $ext_fullaccession, $go_dbname, $go_accession, $go_definition, $go_fullaccession) = undef;

	$ext_dbname     = $map->{$ext}->{'ext_dbname'}; 
	$ext_accession  = $map->{$ext}->{'ext_accession'};
	$ext_definition = $map->{$ext}->{'ext_definition'};
	$go_dbname      = $map->{$ext}->{'go_dbname'};
	$go_accession   = $map->{$ext}->{'go_accession'};
	$go_definition  = $map->{$ext}->{'go_definition'};
	
	$go_fullaccession  = $go_dbname . ":" . $go_accession;
	$ext_fullaccession = $ext_dbname . ":" . $ext_accession;

	if (!defined($ext_accession)){
	    $self->{_logger}->logdie("ext_accession was not defined for ext_dbname '$ext_dbname' go_dbname '$go_dbname' go_accession '$go_accession'");
	    next;
	}
	
	#
	# Verify whether the full GO accession is currently stored in the database.
	#
	if (!exists ($lookup->{$go_fullaccession})){
	    $self->{_logger}->logdie("$go_fullaccession does not currently exist in the chado database.  Therefore cannot map $ext_fullaccession to $go_fullaccession.  The GO definition is '$go_definition' and the external definition is '$ext_definition' ext '$ext'". Dumper $map->{$ext});
	    next;
	}
	else{

	    #
	    # prepare data for insertion into chado.cvterm_dbxref
	    #

	    my ($dbxref_id, $cvterm_id, $db_id, $cvterm_dbxref_id) = undef;

	    #
	    # Retrieve the cvterm_id for the go accession
	    #
	    $cvterm_id = $lookup->{$go_fullaccession}->{'cvterm_id'} if (exists ($lookup->{$go_fullaccession}->{'cvterm_id'}));

	    if (!defined($cvterm_id)){
		$self->{_logger}->logdie("cvterm_id was not defined for $go_fullaccession");
		next;
	    }

	    
	    #
	    # Verify whether the full external accession is currently stored in the database
	    #
	    if (!exists $lookup->{$ext_fullaccession}){

		#
		# Determine whether the ext_dbname was previously stored in the database
		#
		$db_id = $dblookup->{$ext_dbname} if (exists $dblookup->{$ext_dbname});

		if (!defined($db_id)){
		    #
		    # ext_dbname is not currently stored in the database
		    #
		    $db_id = $self->{_backend}->do_store_new_db( 'name' => $ext_dbname );

		    if (!defined($db_id)){
			#
			# db_id is not defined, therefore we cannot create a new chado.dbxref record
			#
			$self->{_logger}->logdie("db_id was not defined.  Cannot store dbxref record for external annotation $ext_fullaccession");
		    }
		}

		
		#
		# Determine whether the ext_accession was previously stored in the database
		#
		my $dbxrefstring = $db_id . '_' . $ext_fullaccession . '_' . $version;
		$dbxref_id = $dbxref_id_lookup->{$dbxrefstring} if (exists $dbxref_id_lookup->{$dbxrefstring});
		
		if (!defined($dbxref_id)){
		    #
		    # ext_accession is not currently stored in the database
		    #
		    $dbxref_id = $self->{_backend}->do_store_new_dbxref(
									db_id       => $db_id,
									accession   => $ext_fullaccession,
									version     => $version,
									description => $description
									);	
		    if (!defined($dbxref_id)){
			$self->{_logger}->logdie("dbxref_id was not defined.  Cannot store record in chado.cvterm_dbxref");
		    }
		}

		#
		# Determine whether the cvterm_id and dbxref_id have been previously stored in the database
		#
		my $cvtermdbxrefstring = $cvterm_id . '_' . $dbxref_id;
		$cvterm_dbxref_id = $cvterm_dbxref_lookup->{$cvtermdbxrefstring} if (exists $cvterm_dbxref_lookup->{$cvtermdbxrefstring});

		if (!defined($cvterm_dbxref_id)){
		    
		    $cvterm_dbxref_id = $self->{_backend}->do_store_new_cvterm_dbxref(
										      dbxref_id => $dbxref_id,
										      cvterm_id => $cvterm_id,
										      );
		    if (!defined($cvterm_dbxref_id)){
			$self->{_logger}->logdie("cvterm_dbxref_id was not defined, therefore cannot insert record into chado.cvterm_dbxref for dbxref_id '$dbxref_id' cvterm_id '$cvterm_id'");
		    }
		}
		else{
		    $self->{_logger}->debug("cvterm_dbxref record already exists in database for cvterm_id '$cvterm_id' and dbxref_id '$dbxref_id' ext_accession '$ext_accession' go_accession '$go_accession'") if $self->{_logger}->is_debug;
		}
	    }
	}
    }#end foreach $ext (sort keys %$map){    
}#end sub store_external_annotation_mappings 

#----------------------------------------------------------------
# ontology_lookup()
#
#----------------------------------------------------------------
sub ontology_lookup {

    my($self) = @_;

   $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my($ret, @s, $i);
        
    $ret = $self->{_backend}->get_ontology_lookup();

    for ($i=0; $i<scalar(@$ret); $i++) {
	$s[$i]->{'name'}       = $ret->[$i][0];
	$s[$i]->{'accession'}  = $ret->[$i][1];
	$s[$i]->{'definition'} = $ret->[$i][2];
	$s[$i]->{'db_id'}      = $ret->[$i][3];
	$s[$i]->{'dbxref_id'}  = $ret->[$i][4];
	$s[$i]->{'cvterm_id'}  = $ret->[$i][5];

    }
    return \@s;
}


#----------------------------------------------------------------
# cvterm_dbxref_lookup()
#
#----------------------------------------------------------------
sub cvterm_dbxref_lookup {

    my($self) = @_;

   $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my($ret, @s, $i);
        
    $ret = $self->{_backend}->get_cvterm_dbxref_lookup();

    for ($i=0; $i<scalar(@$ret); $i++) {
	$s[$i]->{'cvterm_id'}        = $ret->[$i][0];
	$s[$i]->{'dbxref_id'}        = $ret->[$i][1];
	$s[$i]->{'cvterm_dbxref_id'} = $ret->[$i][2];
    }
    return \@s;
}

#---------------------------------------------------------
# features_by_assembly_id()
#
#
#---------------------------------------------------------
sub features_by_assembly_id {

    my($self, $feature_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_features_by_assembly_id($feature_id);

}

#----------------------------------------------------------------
# scaffold_2_contig_lookup()
#
#----------------------------------------------------------------
sub scaffold_2_contig_lookup {

    my($self, $uniquename) = @_;

   $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my($ret, @s, $i);
        
    $ret = $self->{_backend}->get_scaffold_2_contig_lookup($uniquename);

    for ($i=0; $i<scalar(@$ret); $i++) {
	$s[$i]->{'s_feature_id'}  = $ret->[$i][0];
	$s[$i]->{'s_uniquename'}  = $ret->[$i][1];
	$s[$i]->{'a_feature_id'}  = $ret->[$i][2];
	$s[$i]->{'a_uniquename'}  = $ret->[$i][3];
	$s[$i]->{'fmin'}          = $ret->[$i][4];
	$s[$i]->{'fmax'}          = $ret->[$i][5];
	$s[$i]->{'strand'}        = $ret->[$i][6];
    }

    return \@s;

}

#----------------------------------------------------------------
# subfeature_lookup()
#
#----------------------------------------------------------------
sub subfeature_lookup {

    my($self,$scaffold_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
       
    my $ret = $self->{_backend}->get_subfeature_lookup($scaffold_id);

    my $lookup = {};

    my $rowcount = scalar(@$ret);
    $self->{_logger}->debug("Row count '$rowcount'") if $self->{_logger}->is_debug;

    for (my $i=0; $i<scalar(@$ret); $i++) {
	my $s_feature_id   = $ret->[$i][0];
	my $a_feature_id   = $ret->[$i][1];
	my $a_uniquename   = $ret->[$i][2];
	my $fmin           = $ret->[$i][3];
	my $fmax           = $ret->[$i][4];
	my $strand         = $ret->[$i][5];
	my $f_uniquename   = $ret->[$i][6];
	my $f_feature_id   = $ret->[$i][7];
	my $phase          = $ret->[$i][8];
	my $residue_info   = $ret->[$i][9];
	my $rank           = $ret->[$i][10];
	my $type_id        = $ret->[$i][11];
	
	my $asm = [
		   $fmin,
		   $fmax,
		   $strand,
		   $f_uniquename,
		   $f_feature_id,
		   $phase,
		   $residue_info,
		   $rank,
		   $type_id,
		   ];

	if (!exists $lookup->{$a_feature_id}->{'name'}){
	    $self->{_logger}->debug("Storing subfeature '$f_uniquename' feature_id '$f_feature_id' localized to contig '$a_uniquename' feature_id '$a_feature_id' localized to scaffold '$s_feature_id' in the lookup") if $self->{_logger}->is_debug;
	    $lookup->{$a_feature_id}->{'name'}     = $a_uniquename;
	    $lookup->{$a_feature_id}->{'id'}       = $a_feature_id;
	    $lookup->{$a_feature_id}->{'scaffold'} = $s_feature_id;
	}
	push(@{$lookup->{$a_feature_id}->{'subfeatures'}}, $asm);
    }


    return $lookup;
}

#----------------------------------------------------------------
# feature_relationship_lookup()
#
#----------------------------------------------------------------
sub feature_relationship_lookup {

    my($self) = @_;
    
   $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    my @s;
        
    my $ret = $self->{_backend}->get_feature_relationship_lookup(@_);

    for (my $i=0; $i<scalar(@$ret); $i++) {
	$s[$i]->{'feature_relationship_id'}    = $ret->[$i][0];
	$s[$i]->{'subject_id'}                 = $ret->[$i][1];
	$s[$i]->{'object_id'}                  = $ret->[$i][2];
	$s[$i]->{'type_id'}                    = $ret->[$i][3];
	$s[$i]->{'c_name'}                     = $ret->[$i][4];
	$s[$i]->{'s_type_id'}                  = $ret->[$i][5];
	$s[$i]->{'sc_name'}                    = $ret->[$i][6];
	$s[$i]->{'o_type_id'}                  = $ret->[$i][7];
	$s[$i]->{'oc_name'}                    = $ret->[$i][8];
    }

    $self->{_logger}->debug("Returning partially built feature_relationship_lookup") if $self->{_logger}->is_debug;

    return \@s;
}

#----------------------------------------------------------------
# cvterm_relationship_lookup()
#
#----------------------------------------------------------------
sub cvterm_relationship_lookup {

    my($self) = @_;

   $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my @s;
        
    my $ret = $self->{_backend}->get_cvterm_relationship_lookup(@_);

    for (my $i=0; $i<scalar(@$ret); $i++) {
	$s[$i]->{'cvterm_relationship_id'}  = $ret->[$i][0];
	$s[$i]->{'subject_id'}              = $ret->[$i][1];
	$s[$i]->{'object_id'}               = $ret->[$i][2];
	$s[$i]->{'type_id'}                 = $ret->[$i][3];
	$s[$i]->{'cs_name'}                 = $ret->[$i][4];
	$s[$i]->{'co_name'}                 = $ret->[$i][5];
	$s[$i]->{'c_name'}                  = $ret->[$i][6];
    }

    $self->{_logger}->debug("Returning partially built cvterm_relationship_lookup") if $self->{_logger}->is_debug;

    return \@s;
}



#-----------------------------------------------------------------
# show_progress()
#
#-----------------------------------------------------------------
sub show_progress{

    my($self, $message, $counter, $row_count, $bars, $total_rows) = @_;
    my($percent);

#    if (($row_count % $counter == 0) or ($row_count == $total_rows)) {
	
	$self->{_logger}->warn("zero detected, row_count:$row_count") if ($row_count == 0);
	$self->{_logger}->warn("zero detected, total_rows:$total_rows") if ($total_rows ==0);

	eval {$percent = int( ($row_count/$total_rows) * 100 );};
	if ($@){
	    $self->logdie("row_count '$row_count' total_rows '$total_rows'");
	}
	
	# $complete is the number of bars to fill in.
	my $complete = int($bars * ($percent/100));
	
	# $complete is the number of bars yet to go.
	my $incomplete = $bars - $complete;
	
	# This will backspace to before the first bracket.
	print "\b"x(92+$bars) if ( $row_count !=1 );
	printf "%-80s   %-12s   ", qq!$message!, "[". "X"x$complete . " "x$incomplete . "]";
	printf "%3d%%", $percent;

#    }
}

#----------------------------------------------------------------
# db_lookup()
#
#----------------------------------------------------------------
sub db_lookup {

    my($self) = @_;

   $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my @s;
        
    my $ret = $self->{_backend}->get_db_lookup();
    
    for (my $i=0; $i<scalar(@$ret); $i++) {
	$s[$i]->{'db_id'}      = $ret->[$i][0];
	$s[$i]->{'name'}       = $ret->[$i][1];
    }
    return \@s;
}


#---------------------------------------------
# get_sybase_datetime()
#
#---------------------------------------------
sub get_sybase_datetime {


# perl localtime   = Tue Apr  1 18:31:09 2003
# sybase getdate() = Apr  2 2003 10:15AM

    my $self = shift;

    $self->{_logger}->debug("Entered get_sybase_datetime") if $self->{_logger}->is_debug();
    
    
    my $datetime = localtime;
    #                  Day of Week                        Month of Year                                       Day of Month  Hour      Mins     Seconds    Year   
    if ($datetime =~ /^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)[\s]+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+([\d]{1,2})\s+([\d]{2}):([\d]{2}):[\d]{2}\s+([\d]{4})$/){
	my $hour = $4;
	my $ampm = "AM";
	if ($4 ge "13"){
	    
	    $hour = $4 - 12;
	    $ampm = "PM";
	}
	$datetime = "$2  $3 $6  $hour:$5$ampm";
    }
    else{
	$self->{_logger}->logdie("Could not parse datetime");
    }

    return $datetime;
    
}#end sub get_sybase_datetime



#-------------------------------------------------------
# database_list_by_type()
#
#-------------------------------------------------------
sub database_list_by_type {

    my ($self) = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my @s;

    my $ret = $self->{_backend}->get_database_list_by_type(@_);
    # get_database_list_by_type executes the following query:
    # SELECT db
    # FROM common..genomes
    # WHERE type LIKE '%type%'

    for (my $i=0; $i<scalar(@$ret); $i++) {
	$s[$i] = $ret->[$i][0];
    }

    return \@s;

}



#----------------------------------------------------------------
# store_bsml_analysis_component()
#
#----------------------------------------------------------------
sub store_bsml_analysis_component {

    my($self, %param) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
        
    my $phash = \%param;
  
    my $timestamp                  = $phash->{'timestamp'}                  if (exists ($phash->{'timestamp'}));
    my $BsmlAttr                   = $phash->{'BsmlAttr'}                   if (exists ($phash->{'BsmlAttr'}));
    my $bsmldoc                    = $phash->{'bsmldoc'}                    if (exists ($phash->{'bsmldoc'}));

    if (!defined($timestamp)){
	$self->{_logger}->logdie("timestamp was not defined");
    }
    if (!defined($BsmlAttr)){
	$self->{_logger}->logdie("BsmlAttr was not defined");
    }
    if (!defined($bsmldoc)){
	$self->{_logger}->logdie("bsmldoc was not defined");
    }
    

    #
    # Extract analysis data from analysis_object
    #
    my $name           = $BsmlAttr->{'name'}->[0];
    my $description    = $BsmlAttr->{'description'}->[0];
    my $program        = $BsmlAttr->{'program'}->[0];
    my $programversion = $BsmlAttr->{'programversion'}->[0];
    my $algorithm      = $BsmlAttr->{'algorithm'}->[0];
    my $sourcename     = $BsmlAttr->{'sourcename'}->[0];
    my $sourceversion  = $BsmlAttr->{'sourceversion'}->[0];
    my $sourceuri      = $BsmlAttr->{'sourceuri'}->[0];
    my $timeexecuted   = $BsmlAttr->{'timeexecuted'}->[0];
    
    #
    #  First undef the attributes which are mapped to chado.analysis
    #
    delete $BsmlAttr->{'name'};
    delete $BsmlAttr->{'description'};
    delete $BsmlAttr->{'program'};
    delete $BsmlAttr->{'programversion'};
    delete $BsmlAttr->{'algorithm'};
    delete $BsmlAttr->{'sourcename'};
    delete $BsmlAttr->{'sourceversion'};
    delete $BsmlAttr->{'sourceuri'};
    delete $BsmlAttr->{'timeexecuted'};
    
    #-------------------------------------------------------------------------------
    # Assignment of chado.analysis.programversion
    #
    #-------------------------------------------------------------------------------
    if (!defined($programversion)){
	
	if ((exists $BsmlAttr->{'version'}) && (defined($BsmlAttr->{'version'}))){

	    $programversion = $BsmlAttr->{'version'}->[0];

	    $self->{_logger}->debug("Retrieved programversion from //Analysis/Attribute/\@version = '$BsmlAttr->{'version'}'") if $self->{_logger}->is_debug();

	    delete $BsmlAttr->{'version'};
	}
	else {
	    $self->{_logger}->logdie("Could not retrieve programversion from //Analysis//Attribute/\@version");
	}
    }


    #-------------------------------------------------------------------------------
    # chado.analysis.algorithm must be assigned
    #
    #-------------------------------------------------------------------------------
    if (!defined($algorithm)){

	$algorithm = $name;

	if (!defined($algorithm)){
	    $self->{_logger}->logdie("algorithm was not defined");
	}
    }

    #-------------------------------------------------------------------------------
    # chado.analysis.program must be assigned
    #
    #-------------------------------------------------------------------------------
    if (!defined($program)){

	$program = $name;

	if (!defined($program)){
	    $self->{_logger}->logdie("program was not defined");
	}
    }

    #------------------------------------------------------------------------------
    # Assignment of chado.analysis.sourcename
    #
    #------------------------------------------------------------------------------
    if (!defined($sourcename)){
	
	#
	# Assign the BSML doc filename to chado.analysis.sourcename
	#
	$sourcename = $bsmldoc;

	$self->{_logger}->debug("sourcename was set to bsmldoc '$bsmldoc'") if ($self->{_logger}->is_debug());
    }

    ## If name is not defined, assign value for program
    if (!defined($name)){
	$name = $program;
    }


    $self->{_logger}->logdie("program was not defined for //Analysis/Attribute/\@name = '$name'") if (!defined($program));

    $self->{_logger}->debug("sourcename $sourcename for wfid '$BsmlAttr->{'wfid'}' sourcename '$sourcename'") if($self->{_logger}->is_debug());


    #-------------------------------------------------------------------------------
    # Assignment of chado.analysis.timeexecuted
    # If timeexecuted is not defined, then attempt to assign the timestamp
    #
    #-------------------------------------------------------------------------------
    if (!defined($timeexecuted)) {
	if (defined($timestamp)){
	    $timeexecuted = $timestamp;
	    $self->{_logger}->debug("Setting chado.analysis.timeexecuted to timestamp '$timestamp'") if $self->{_logger}->is_debug;
	}
	else{
	    $self->{_logger}->logdie("Both timeexecuted and timestamp were not defined");
	}
    }



    if (!defined($name)){
	$self->{_logger}->debug("name was not defined") if $self->{_logger}->is_debug;
    }
    if (!defined($description)){
	$self->{_logger}->debug("description was not defined") if $self->{_logger}->is_debug;
    }
    if (!defined($program)){
	$self->{_logger}->logdie("program was not defined");
    }
    if (!defined($programversion)){
	$self->{_logger}->logdie("programversion was not defined");
    }
    if (!defined($algorithm)){
	$self->{_logger}->warn("algorithm was not defined");
    }
    if (!defined($sourcename)){
	$self->{_logger}->warn("sourcename was not defined");
    }
    if (!defined($sourceversion)){
	$self->{_logger}->debug("sourceversion was not defined") if $self->{_logger}->is_debug;
    }
    if (!defined($sourceuri)){
	$self->{_logger}->debug("sourceuri was not defined") if $self->{_logger}->is_debug;
    }
    if (!defined($timeexecuted)){
	$self->{_logger}->logdie("timeexecute was not defined");
    }

    my $analysis_id;
    my $workflow_id;

    if ((exists $BsmlAttr->{'wfid'}) and (defined($BsmlAttr->{'wfid'}))){
	$workflow_id = $BsmlAttr->{'wfid'}->[0];

	if (!defined($workflow_id)){
	    $self->{_logger}->warn("workflow_id was not defined");
	}
	else{
	    #
	    # If workflow_id has been inserted into analysisprop, then retrieve the associated analysisprop.analysis_id
	    #
	    $analysis_id = $self->check_analysis_id_by_wfid_lookup( value => $workflow_id);

	    $self->{_logger}->warn("Could not retrieve analysis_id for workflow_id '$workflow_id'") if (!defined($analysis_id));
	}
    }
    else{
	$self->{_logger}->warn("wfid was not found among the Analysis attributes");
    }



    #
    # This analysis record was already inserted during a previous session.
    #
    if (defined($analysis_id)){
	$self->{_logger}->debug("analysis_id '$analysis_id' for workflow_id '$workflow_id was inserted during a previous session and was retrieved via Prism::analysis_id_from_analysisprop") if $self->{_logger}->is_debug;
	return ($analysis_id, $algorithm);
    }
    else{
	#
	# analysisprop.analysis_id for workflow_id was not found, therefore need to insert records into chado.analysis and chado.analysisprop
	#	
	$analysis_id = $self->check_analysis_id_lookup(
						       program        => $program,
						       programversion => $programversion,
						       sourcename     => $sourcename
						       );
	if (defined($analysis_id)){
	    
	    $self->{_logger}->debug("Found analysis_id '$analysis_id' for program '$program' programversion '$programversion' sourcename '$sourcename' in analysis_id_lookup") if $self->{_logger}->is_debug();
	    
	    

	    #------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	    # A little QC.  If the record already exists in the database, then the analysis.name of the in-bound record
	    # should match the analysis.name of the already inserted record.
	    #
	    my $analysis_name = $self->check_name_by_analysis_id_lookup( name => $analysis_id );
	    
	    if (defined($analysis_name)) {
		
		$self->{_logger}->logdie("In-bound analysis.name '$name' != loaded analysis.name '$analysis_name' for analysis_id '$analysis_id'") if ($name ne $analysis_name);

	    }
	    #
	    #------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	}
	else{
	    $self->{_logger}->info("Could not find analysis_id for program '$program' programversion '$programversion' sourcename '$sourcename' were not found in the analysis_id_lookup");
	
	    #
	    # Insert record into chado.analysis
	    #
	    $analysis_id = $self->{_backend}->do_store_new_analysis(
								    name           => $name,
								    description    => $description, 
								    program        => $program,
								    programversion => $programversion,
								    algorithm      => $algorithm,
								    sourcename     => $sourcename,
								    sourcevesrion  => $sourceversion,
								    sourceuri      => $sourceuri,
								    timeexecuted   => $timeexecuted
								    );
	    $self->{_logger}->logdie("analysis_id was not defined.  Could not insert record into chado.analysis") if (!defined($analysis_id));

	    
	}
	

    }




    #-----------------------------------------------------------------------------------------------------------------------
    # store all analysis properties in chado.analysisprop
    #
    #
    foreach my $analysis_property (sort keys %{$BsmlAttr} ) {

	if (( exists $BsmlAttr->{$analysis_property}) && (defined($BsmlAttr->{$analysis_property}))) {

	    my $value = $BsmlAttr->{$analysis_property}->[0];

	    my $type_id = $self->check_property_types_lookup( name => $analysis_property );

    
	    if (!defined($type_id)){
		$self->{_logger}->fatal("type_id was not defined for analysis property '$analysis_property'.  Could not store record in chado.analysisprop for analysis_id '$analysis_id' value '$value'");
		next;
	    }
	    else {

		my $analysisprop_id = $self->check_analysisprop_id_lookup(
									  analysis_id => $analysis_id,
									  type_id     => $type_id,
									  value       => $value,
									  status      => 'warn'
									  );
		
		if (!defined($analysisprop_id)){
		    #
		    # Insert record into chado.analysisprop
		    #
		    $analysisprop_id = $self->{_backend}->do_store_new_analysisprop(
										    analysis_id => $analysis_id,
										    type_id     => $type_id,
										    value       => $value,
										    );

		    $self->{_logger}->logdie("analysisprop_id was not defined.  Cannot store record in chado.analysisprop for analysis_id '$analysis_id' type_id '$type_id' value '$value'") if (!defined($analysisprop_id));


		}
	    }
	}
	else {
	    $self->{_logger}->logdie("No value for analysis property '$analysis_property'; analysis_id '$analysis_id'");
	}
    }
    #
    #----------------------------------------------------------------------------------------------------------------------




    return ($analysis_id, $algorithm);

}

#------------------------------------------------------------------------------------------------------------
# store_bsml_seq_pair_run_component()
#
#------------------------------------------------------------------------------------------------------------
sub store_bsml_seq_pair_run_component {

    my ($self, %param) = @_;
    
    $self->{_logger}->debug("Entered store_bsml_seq_pair_run_component") if $self->{_logger}->is_debug();
    
    my $phash = \%param;
    
    my $warn_flag = 0;
    
    #
    # <Seq-pair-alignment> related data
    #
    my $alignment_feature_id  = $phash->{'feature_id'}           if ((exists $phash->{'feature_id'})           and (defined($phash->{'feature_id'})));
    my $analysis_id           = $phash->{'analysis_id'}          if ((exists $phash->{'analysis_id'})          and (defined($phash->{'analysis_id'})));
    my $refseq                = $phash->{'refseq'}               if ((exists $phash->{'refseq'})               and (defined($phash->{'refseq'})));
    my $compseq               = $phash->{'compseq'}              if ((exists $phash->{'compseq'})              and (defined($phash->{'compseq'})));
    my $refend                = $phash->{'refend'}               if ((exists $phash->{'refend'})               and (defined($phash->{'refend'})));
    my $reflength             = $phash->{'reflength'}            if ((exists $phash->{'reflength'})            and (defined($phash->{'reflength'})));
    my $refstart              = $phash->{'refstart'}             if ((exists $phash->{'refstart'})             and (defined($phash->{'refstart'})));
    
    

    $self->{_logger}->logdie("analysis_id was not defined")          if (!defined($analysis_id));
    $self->{_logger}->logdie("refseq was not defined")               if (!defined($refseq));
    $self->{_logger}->logdie("compseq was not defined")              if (!defined($compseq));


    #
    # Auxiliary data
    #
    my $timestamp           = $phash->{'timestamp'}            if ((exists $phash->{'timestamp'})            and (defined($phash->{'timestamp'})));
    my $organism_id_unknown = $phash->{'organism_id'}          if ((exists $phash->{'organism_id'})          and (defined($phash->{'organism_id'})));
    my $hspctr              = $phash->{'hspctr'}               if ((exists $phash->{'hspctr'})               and (defined($phash->{'hspctr'})));
    

    $self->{_logger}->logdie("timestamp was not defined")            if (!defined($timestamp));
    $self->{_logger}->logdie("organism_id_unknown was not defined")  if (!defined($organism_id_unknown));
    $self->{_logger}->logdie("hspctr was not defined")               if (!defined($hspctr));

    
    #
    # <Seq-pair-run> related data
    #
    my $seq_pair_run      = $phash->{'seq_pair_run'}                 if ((exists $phash->{'seq_pair_run'})                 and (defined($phash->{'seq_pair_run'})));
    my $compcomplement    = $seq_pair_run->{'attr'}->{'compcomplement'}        if ((exists $seq_pair_run->{'attr'}->{'compcomplement'})        and (defined($seq_pair_run->{'attr'}->{'compcomplement'})));
    my $comppos           = $seq_pair_run->{'attr'}->{'comppos'}               if ((exists $seq_pair_run->{'attr'}->{'comppos'})               and (defined($seq_pair_run->{'attr'}->{'comppos'})));
    my $comprunlength     = $seq_pair_run->{'attr'}->{'comprunlength'}         if ((exists $seq_pair_run->{'attr'}->{'comprunlength'})         and (defined($seq_pair_run->{'attr'}->{'comprunlength'})));
    my $refcomplement     = $seq_pair_run->{'attr'}->{'refcomplement'}         if ((exists $seq_pair_run->{'attr'}->{'refcomplement'})         and (defined($seq_pair_run->{'attr'}->{'refcomplement'})));
    my $refframe          = $seq_pair_run->{'attr'}->{'refframe'}              if ((exists $seq_pair_run->{'attr'}->{'refframe'})              and (defined($seq_pair_run->{'attr'}->{'refframe'})));
    my $compframe         = $seq_pair_run->{'attr'}->{'compframe'}             if ((exists $seq_pair_run->{'attr'}->{'compframe'})             and (defined($seq_pair_run->{'attr'}->{'compframe'})));
    my $refpos            = $seq_pair_run->{'attr'}->{'refpos'}                if ((exists $seq_pair_run->{'attr'}->{'refpos'})                and (defined($seq_pair_run->{'attr'}->{'refpos'})));
    my $runlength         = $seq_pair_run->{'attr'}->{'runlength'}             if ((exists $seq_pair_run->{'attr'}->{'runlength'})             and (defined($seq_pair_run->{'attr'}->{'runlength'})));
    my $runprob           = $seq_pair_run->{'attr'}->{'runprob'}               if ((exists $seq_pair_run->{'attr'}->{'runprob'})               and (defined($seq_pair_run->{'attr'}->{'runprob'})));
    my $runscore          = $seq_pair_run->{'attr'}->{'runscore'}              if ((exists $seq_pair_run->{'attr'}->{'runscore'})              and (defined($seq_pair_run->{'attr'}->{'runscore'})));



    #
    # Lookups 
    #
    my $feature_id_lookup               = $phash->{'feature_id_lookup'}               if ((exists $phash->{'feature_id_lookup'})              and (defined($phash->{'feature_id_lookup'})));
    my $feature_id_lookup_d             = $phash->{'feature_id_lookup_d'}             if ((exists $phash->{'feature_id_lookup_d'})            and (defined($phash->{'feature_id_lookup_d'})));
    my $sequence_lookup                 = $phash->{'sequence_lookup'}                 if ((exists $phash->{'sequence_lookup'})                and (defined($phash->{'sequence_lookup'})));
    
    $self->{_logger}->logdie("feature_id_lookup was not defined")                   if (!defined($feature_id_lookup));
    $self->{_logger}->logdie("feature_id_lookup_d was not defined")                 if (!defined($feature_id_lookup_d));




    my $alignment;
    if ((exists $seq_pair_run->{'attr'}->{'alignment'}) and (defined($seq_pair_run->{'attr'}->{'alignment'}))){
	$alignment = $seq_pair_run->{'attr'}->{'alignment'};
    }
    
    #
    # Use regex to extract individual reference and query bases
    # Not currently checking the validity of the base characters, nor even that they are 
    # different (since in a multi-species comparison one might reasonably have a SNP in
    # which no base change occurs between two of the species.)
    #

    #
    # Check if alignment is defined.  For non-SNP/indel pairwise documents, the alignment field is currently not populated.  (<Seq-pair-run>'s alignment XML attribute.)
    # In the near future we will likely store the cigar notation in the alignment field.
    # At that time, this code should be modified to properly parse the alignment field based on the compute type.
    # i.e. if (($compute eq 'SNP') or ($compute eq 'insertion') or ($compute eq 'deletion')){
    #            if (defined($alignment)){
    #                ($ref_base, $query_base) = ($alignment =~ /^(\S+)\.\.(\S+)$/);
    #                if (!$ref_base || !$query_base) {
    #                    $self->{_logger}->error("unable to parse alignment '$alignment'");
    #                }
    #            }
    #      }
    #      else{
    #            


    my($ref_base, $comp_base);
    if (defined($alignment)){
	($ref_base, $comp_base) = ($alignment =~ /^(\S+)\.\.(\S+)$/);
	if (!$ref_base || !$comp_base) {
	    $self->{_logger}->logdie("unable to parse alignment '$alignment'");
	}
    }


    my $BsmlAttr;

    if (( exists $seq_pair_run->{'BsmlAttr'}) &&
	(defined($seq_pair_run->{'BsmlAttr'}))){
	$BsmlAttr = $seq_pair_run->{'BsmlAttr'};
    }
    else {
	$self->{_logger}->logdie("BsmlAttr was not defined for refseq '$refseq' compseq '$compseq'". Dumper $seq_pair_run);
    }
	

    my ($normscore, $rawscore, $significance, $pidentity, $residues, $date, $class);

    if ((exists $seq_pair_run->{'attr'}->{'runprob'}) and (defined($seq_pair_run->{'attr'}->{'runprob'}))){

	$significance = $seq_pair_run->{'attr'}->{'runprob'};
    }

    if ((exists $seq_pair_run->{'attr'}->{'runscore'}) and (defined($seq_pair_run->{'attr'}->{'runscore'}))){

	$rawscore = $seq_pair_run->{'attr'}->{'runscore'};
    }


    if (( exists $BsmlAttr->{'percent_identity'}) &&
	(defined($BsmlAttr->{'percent_identity'})) &&
	(scalar(@{$BsmlAttr->{'percent_identity'}}) > 0 ) ) {
	
	$pidentity = $BsmlAttr->{'percent_identity'}->[0];

	#
	# undef to ensure not included in chado.featureprop
	#
	delete $BsmlAttr->{'percent_identity'};
    }
    if ((exists $BsmlAttr->{'normscore'}) &&
	(defined($BsmlAttr->{'normscore'})) &&
	(scalar(@{$BsmlAttr->{'normscore'}}) > 0 ) ) {
	

	$normscore = $BsmlAttr->{'normscore'}->[0];

	#
	# undef to ensure not included in chado.featureprop
	#
	delete $BsmlAttr->{'normscore'};
    }
    if ((exists $BsmlAttr->{'residues'}) &&
	(defined($BsmlAttr->{'residues'})) &&
	(scalar(@{$BsmlAttr->{'residues'}}) > 0 ) ) {

	$residues = $BsmlAttr->{'residues'}->[0];

	#
	# undef to ensure not included in chado.featureprop
	#
	delete $BsmlAttr->{'residues'};
    }
    if ((exists $BsmlAttr->{'class'}) &&
	(defined($BsmlAttr->{'class'})) &&
	(scalar(@{$BsmlAttr->{'class'}}) > 0 ) ) {

	$class = $BsmlAttr->{'class'}->[0];

	#
	# undef to ensure not included in chado.featureprop
	#
	delete $BsmlAttr->{'class'};
    }
    else {
	$self->{_logger}->logdie("class was not defined for this Seq-pair-run");
    }

    if (exists $phash->{'exclude_classes_lookup'}->{$class}){
	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->debug("Excluding the match feature type '$class'");
	}
	return;
    }

    if (!defined($alignment_feature_id)){
	$self->{_logger}->logdie("alignment_feature_id was not defined");
    }

    if ((exists $BsmlAttr->{'date'})  &&
	(defined($BsmlAttr->{'date'})) &&
	(scalar(@{$BsmlAttr->{'date'}}) > 0 ) ) {
	
	$date = $BsmlAttr->{'date'}->[0];

	#
	# undef to ensure not included in chado.featureprop
	#
	delete $BsmlAttr->{'date'};
    }
    else{
	$date = $timestamp;
    }
    
    


    undef $phash->{'seq_ref'};

    
    #-------------------------------------------------------------------------------------------
    # Verify whether critical parameters were defined
    #-------------------------------------------------------------------------------------------
    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if (!defined($compseq)){
	$self->{_logger}->logdie("compseq was not defined");
    }
    if (!defined($refseq)){
	$self->{_logger}->logdie("refseq was not defined");
    }
    if (!defined($comppos)){
	$self->{_logger}->logdie("comppos was not defined");
    }
    if (!defined($refpos)){
	$self->{_logger}->logdie("refpos was not defined");
    }
    if (!defined($feature_id_lookup)){
	$self->{_logger}->logdie("feature_id_lookup was not defined");
    }
    if (!defined($timestamp)){
	$self->{_logger}->logdie("timestamp was not defined");
    }



    #----------------------------------------------------------------------------------------------
    # comment: Prepare data to be inserted into chado.feature table
    #
    my $match_cvterm_id = $self->check_cvterm_id_by_class_lookup( class => $class) ;

    $self->{_logger}->logdie("match_cvterm_id was not defined") if (!defined($match_cvterm_id));


    #-----------------------------------------------------------------------------------------------
    # comment: Retrieve the organism_id of the reference sequence (refseq)
    #
    my $organism_id;

    if ((exists $feature_id_lookup->{$refseq}->[1]) and (defined($feature_id_lookup->{$refseq}->[1]))){
	#
	# Check the static feature_id_lookup
	#
	$organism_id = $feature_id_lookup->{$refseq}->[1];
    }
    elsif ((exists $feature_id_lookup_d->{$refseq}->{'organism_id'}) and (defined($feature_id_lookup_d->{$refseq}->{'organism_id'}))){
	#
	# Check the non-static feature_id_lookup_d
	#
	$organism_id = $feature_id_lookup_d->{$refseq}->{'organism_id'};
    }
    elsif ((exists $feature_id_lookup->{$sequence_lookup->{$refseq}->{'feature_uniquename'}}->[1]) and (defined($feature_id_lookup->{$sequence_lookup->{$refseq}->{'feature_uniquename'}}->[1]))){

	$organism_id = $feature_id_lookup->{$sequence_lookup->{$refseq}->{'feature_uniquename'}}->[1];
    }
    else {
	#
	# Could not find organism_id in any of the lookups, therefore will assign 'not known' organism_id
	#
	$organism_id = $organism_id_unknown;

	$self->{_logger}->debug("Could not retrieve organism_id from the lookups, therefore assigning organism_id '$organism_id_unknown'");
    }

    
    my $uniquename = $self->{_id_generator}->next_id( type    => $class,
						      project => $self->{_db} );
    
    my $feature_id = $self->{_backend}->do_store_new_feature(
							     dbxref_id        => undef,
							     organism_id      => $organism_id,
							     name             => undef,
							     uniquename       => $uniquename,
							     residues         => $residues,
							     seqlen           => undef,
							     md5checksum      => undef,
							     type_id          => $match_cvterm_id,
							     is_analysis      => 1,
							     is_obsolete      => 0,
							     timeaccessioned  => $date,
							     timelastmodified => $timestamp
							     );

    $self->{_logger}->logdie("feature_id was not defined.  Could not store record into chado.feature for organism_id '$organism_id' uniquename '$uniquename' type_id '$match_cvterm_id' refseq '$refseq' compseq '$compseq' HSP number '$hspctr'") if (!defined($feature_id));


    #-----------------------------------------------------------------------------------------------------------------------------------
    # Prepare data to be inserted into chado.featureprop table 
    #
    foreach my $key ( keys %{$BsmlAttr} ) {
	
	if ( scalar ( @{$BsmlAttr->{$key}} ) > 0){

	    foreach my $value ( @{$BsmlAttr->{$key}} ){ 

		if (!defined($value)){
		    $self->{_logger}->logdie("value was not defined for key '$key' for refseq '$refseq' compseq '$compseq'")
		}
		else {
		    my $type_id = $self->check_cvterm_id_by_name_lookup( name => $key );
		    
		    if (defined($type_id)){
			
			$self->prepareFeaturepropRecord($feature_id, $type_id, $value);
		    }
		    else{
			
			$self->{_logger}->logdie("term '$key' was not found in cvterm.  Could not insert record into chado.featureprop for feature_id '$feature_id' uniquename '$uniquename' term '$key' value '$value' refseq '$refseq' compseq '$compseq' HSP number '$hspctr'");
		    }
		}
	    }
	}
    }
    #
    #-----------------------------------------------------------------------------------------------------------------------------------
	
	

    #------------------------------------------------------------------------------------------------------------------------------------
    # Prepare data to be inserted into chado.analysisfeature table 
    #
    my $analysisfeature_id = $self->check_analysisfeature_id_lookup(
								    feature_id  => $feature_id,
								    analysis_id => $analysis_id,
								    status      => 'warn',
								    msg         => "refseq 'refseq' compseq '$compseq' HSP number '$hspctr'"
								    );
    if (!defined($analysisfeature_id)){
	#
	# Store this tuple now!
	#
	my $type_id = $self->check_cvterm_id_by_name_lookup( name => 'computed_by'); # temporary compute_by cvterm_id !

	$analysisfeature_id = $self->{_backend}->do_store_new_analysisfeature(
									      analysis_id  => $analysis_id,
									      feature_id   => $feature_id,
									      normscore    => $normscore,
									      rawscore     => $rawscore,
									      significance => $significance,
									      pidentity    => $pidentity,
									      type_id      => $type_id
									      );
	
	$self->{_logger}->logdie("analysisfeature_id was not defined.  Could not store record in chado.analysisfeature for analysis_id '$analysis_id' feature_id '$feature_id' refseq '$refseq' compseq '$compseq' HSP number '$hspctr'") if (!defined($analysisfeature_id));
    }		
    #
    #------------------------------------------------------------------------------------------------------------------------------------
		




    #----------------------------------------------------------------------------------------------
    # Prepare query/refseq data to be inserted into chado.featureloc table 
    # Represents localization of compute to the query sequence
    #
    #----------------------------------------------------------------------------------------------
    {    
    
    
	
	#-------------------------------------------------------------------------------------------------------------------------------
	# Attempt to retrieve the feature_id for the refseq from the lookups
	#
	my $srcfeature_id;
	
	if ((exists $feature_id_lookup->{$refseq}->[0]) and (defined($feature_id_lookup->{$refseq}->[0]))){
	    #
	    # Check the static feature_id_lookup
	    #
	    $srcfeature_id = $feature_id_lookup->{$refseq}->[0];
	}
	elsif ((exists $feature_id_lookup_d->{$refseq}->{'feature_id'}) and (defined($feature_id_lookup_d->{$refseq}->{'feature_id'}))){
	    #
	    # Check the non-static feature_id_lookup_d
	    #
	    $srcfeature_id = $feature_id_lookup_d->{$refseq}->{'feature_id'};
	}
	elsif ((exists $feature_id_lookup->{$sequence_lookup->{$refseq}->{'feature_uniquename'}}->[0]) and (defined($feature_id_lookup->{$sequence_lookup->{$refseq}->{'feature_uniquename'}}->[0]))){
	    #
	    # Check the static feature_id_lookup using the reference sequence's uniquename
	    #
	    $srcfeature_id = $feature_id_lookup->{$sequence_lookup->{$refseq}->{'feature_uniquename'}}->[0];
	}
	else {	    
	    $self->{_logger}->fatal("static feature_id_lookup" . Dumper $feature_id_lookup . "\ndynamic feature_id_lookup_d" . Dumper $feature_id_lookup_d);
	    $self->{_logger}->logdie("srcfeature_id was not defined for refseq '$refseq' (compseq '$compseq' HSP number '$hspctr'");
	}
	#
	#-------------------------------------------------------------------------------------------------------------------------------
	




	#------------------------------------------------------------------------------------------------------------------------
	# If the runlength was not supplied, attempt to retrieve the refseq's seqlen from lookups
	#

	if (!defined($runlength)){

	    my $seqlen_refseq_parent;

	    if ((exists $feature_id_lookup->{$refseq}->[5]) and (defined($feature_id_lookup->{$refseq}->[5]))){
		#
		# Check the static feature_id_lookup
		#
		$seqlen_refseq_parent = $feature_id_lookup->{$refseq}->[5];
	    }
	    elsif ((exists $feature_id_lookup_d->{$refseq}->{'seqlen'}) and (defined($feature_id_lookup_d->{$refseq}->{'seqlen'}))){
		#
		# Check the non-static feature_id_lookup_d
		#
		$seqlen_refseq_parent = $feature_id_lookup_d->{$refseq}->{'seqlen'};
	    }
	    elsif ((exists $feature_id_lookup->{$sequence_lookup->{$refseq}->{'feature_uniquename'}}->[5]) and (defined($feature_id_lookup->{$sequence_lookup->{$refseq}->{'feature_uniquename'}}->[5]))){
		#
		# Check the static lookup by the refseq's sequence uniquename i.e. _CDS_seq, _protein_seq
		#
		$seqlen_refseq_parent = $feature_id_lookup->{$sequence_lookup->{$refseq}->{'feature_uniquename'}}->[5];
	    }
	    else {
		$self->{_logger}->logdie("Neither runlength was defined nor could the seqlen of the refseq '$refseq' be retrieved. (compseq '$compseq' HSP number '$hspctr'");
	    }

	    $runlength = $seqlen_refseq_parent if (defined($seqlen_refseq_parent));
	}
	#
	#--------------------------------------------------------------------------------------------------------------------------






	#-----------------------------------------------------------------------------------------------
	# comment: The refpos should have been defined in the BSML encoding.
	#          If not, we will simply set default value 0
	#
	if (!defined($refpos)){

	    $refpos = 0;

	    $self->{_logger}->warn("refpos was not defined! Setting default refpos = '$refpos'");

	}
	#
	#-----------------------------------------------------------------------------------------------
	



	#
	# BSML encoding must be inter-base system!
	#
	my $fmin = $refpos;
	
	my $fmax = $refpos + $runlength;
	
	my $strand;


	#
	# This may be deprecated code- need to confer with Sam on whether the refstart and refend should play any part in determining the strandedness of the HSP.
	#
	if (defined($refstart) && defined($refend)){
	    if ($refstart > $refend){
		$self->{_logger}->debug("Swapping fmin and fmax for refseq:$refseq and compseq:$compseq") if $self->{_logger}->is_debug;
		$strand = -1;
		my $tmp = $refend;
		$refend = $refstart;
		$refstart = $tmp;
	    }
	    elsif ($refstart < $refend){
		$strand = 1;
	    }
	}
	
	    
	#-------------------------------------------------------------------------------------------------------------------------------
	# comment: Do HSPs have strandedness?
	#
	if (defined($refcomplement)){

	    if ($refcomplement == 0) {
		#
		# forward strand (if HSPs have strandedness)
		#
		$strand = 1;
	    }
	    elsif ($refcomplement == 1) {
		#
		# reverse strand (if HSPs have strandedness)
		# 
		$strand = -1;
	    }
	    else {
		$self->{_logger}->logdie("Unrecognized refcomplement '$refcomplement' for refseq '$refseq' compseq '$compseq'");
	    }
	}
	else {
	    $self->{_logger}->logdie("refcomplement was not defined for refseq '$refseq' compseq '$compseq'");
	}
	#
	#-------------------------------------------------------------------------------------------------------------------------------

	## Store localization of the <Seq-pair-run>/HSP to the refseq
	$self->prepareFeaturelocRecord($feature_id, $srcfeature_id, 0, 1, $fmin, $fmax, $strand);
    }
    
    
    {    
	
    
	
	#-------------------------------------------------------------------------------------------------------------------------------
	# Attempt to retrieve the feature_id for the compseq from the lookups
	#
	my $srcfeature_compseq_id;
	
	if ((exists $feature_id_lookup->{$compseq}->[0]) and (defined($feature_id_lookup->{$compseq}->[0]))){
	    #
	    # Check the static feature_id_lookup
	    #
	    $srcfeature_compseq_id = $feature_id_lookup->{$compseq}->[0];
	}
	elsif ((exists $feature_id_lookup_d->{$compseq}->{'feature_id'}) and (defined($feature_id_lookup_d->{$compseq}->{'feature_id'}))){
	    #
	    # Check the non-static feature_id_lookup_d
	    #
	    $srcfeature_compseq_id = $feature_id_lookup_d->{$compseq}->{'feature_id'};
	}
	elsif ((exists $feature_id_lookup->{$sequence_lookup->{$compseq}->{'feature_uniquename'}}->[0]) and (defined($feature_id_lookup->{$sequence_lookup->{$compseq}->{'feature_uniquename'}}->[0]))){
	    #
	    # Check the static feature_id_lookup using the reference sequence's uniquename
	    #
	    $srcfeature_compseq_id = $feature_id_lookup->{$sequence_lookup->{$compseq}->{'feature_uniquename'}}->[0];
	}
	else {	    
	    $self->{_logger}->fatal("static feature_id_lookup" . Dumper $feature_id_lookup . "\ndynamic feature_id_lookup_d" . Dumper $feature_id_lookup_d);
	    $self->{_logger}->logdie("feature_id_of_compseqs_source was not defined for compseq '$compseq'");
	}
	#
	#-------------------------------------------------------------------------------------------------------------------------------
	




	#------------------------------------------------------------------------------------------------------------------------
	# If the comprunlength was not supplied, attempt to retrieve the compseq's seqlen from lookups
	#

	if (!defined($comprunlength)){

	    my $seqlen_compseq_parent;

	    if ((exists $feature_id_lookup->{$compseq}->[5]) and (defined($feature_id_lookup->{$compseq}->[5]))){
		#
		# Check the static feature_id_lookup
		#
		$seqlen_compseq_parent = $feature_id_lookup->{$compseq}->[5];
	    }
	    elsif ((exists $feature_id_lookup_d->{$compseq}->{'seqlen'}) and (defined($feature_id_lookup_d->{$compseq}->{'seqlen'}))){
		#
		# Check the non-static feature_id_lookup_d
		#
		$seqlen_compseq_parent = $feature_id_lookup_d->{$compseq}->{'seqlen'};
	    }
	    elsif ((exists $feature_id_lookup->{$sequence_lookup->{$compseq}->{'feature_uniquename'}}->[5]) and (defined($feature_id_lookup->{$sequence_lookup->{$compseq}->{'feature_uniquename'}}->[5]))){
		#
		# Check the static lookup by the compseq's sequence uniquename i.e. _CDS_seq, _protein_seq
		#
		$seqlen_compseq_parent = $feature_id_lookup->{$sequence_lookup->{$compseq}->{'feature_uniquename'}}->[5];
	    }
	    else {
		$self->{_logger}->logdie("Neither comprunlength was defined nor could the seqlen of the compseq '$compseq' be retrieved.");
	    }

	    $comprunlength = $seqlen_compseq_parent if (defined($seqlen_compseq_parent));
	}
	#
	#--------------------------------------------------------------------------------------------------------------------------






	#-----------------------------------------------------------------------------------------------
	# comment: The comppos should have been defined in the BSML encoding.
	#          If not, we will simply set default value 0
	#
	if (!defined($comppos)){

	    $comppos = 0;

	    $self->{_logger}->warn("comppos was not defined! Setting default comppos = '$comppos'");

	}
	#
	#-----------------------------------------------------------------------------------------------
	



	#
	# BSML encoding must be inter-base system!
	#
	my $fmin_compseq_ = $comppos;
	
	my $fmax_compseq = $comppos + $comprunlength;
	
	my $strand_compseq;


	#
	# This may be deprecated code- need to confer with Sam on whether the compstart and compend should play any part in determining the strandedness of the HSP.
	#
# 	if (defined($compstart) && defined($compend)){
# 	    if ($compstart > $compend){
# 		$self->{_logger}->debug("Swapping fmin and fmax for refseq '$refseq' and compseq '$compseq'") if $self->{_logger}->is_debug;
# 		$strand = -1;
# 		my $tmp = $compend;
# 		$compend = $compstart;
# 		$compstart = $tmp;
# 	    }
# 	    elsif ($compstart < $compend){
# 		$strand = 1;
# 	    }
# 	}
	
	    
	#-------------------------------------------------------------------------------------------------------------------------------
	# comment: Do HSPs have strandedness?
	#
	if (defined($compcomplement)){

	    if ($compcomplement == 0) {
		#
		# forward strand (if HSPs have strandedness)
		#
		$strand_compseq = 1;
	    }
	    elsif ($compcomplement == 1) {
		#
		# reverse strand (if HSPs have strandedness)
		# 
		$strand_compseq = -1;
	    }
	    else {
		$self->{_logger}->logdie("Unrecognized compcomplement '$compcomplement' for refseq '$refseq' compseq '$compseq'");
	    }
	}
	else {
	    $self->{_logger}->logdie("compcomplement was not defined for refseq '$refseq' compseq '$compseq'");
	}
	#
	#-------------------------------------------------------------------------------------------------------------------------------

	## Store localization of the <Seq-pair-run>/HSP to the compseq
	$self->prepareFeaturelocRecord($feature_id, $srcfeature_compseq_id, 0, 0, $fmin_compseq_, $fmax_compseq, $strand_compseq);
    }



    {
	#----------------------------------------------------------------------------------------------------------------------------
	# Here we attempt to store a feature_relationship between the HSP and the alignment feature,
	# The alignment feature was created in Prism::store_bsml_seq_pair_alignment_component()
	#
	my $type_id_compseq = $self->check_cvterm_id_by_name_lookup( name => 'part_of' );

	if (defined($type_id_compseq)){
	    
	    my $feature_relationship_id = $self->check_feature_relationship_id_lookup(
										      subject_id => $feature_id,
										      object_id  => $alignment_feature_id,
										      type_id    => $type_id_compseq,
										      rank       => $hspctr,
										      status     => 'warn',
										      msg        => "refseq '$refseq' compseq '$compseq' HSP number '$hspctr'"
										      );
	    if (!defined($feature_relationship_id)){
		#
		# Store this tuple now!
		#
		$feature_relationship_id = $self->{_backend}->do_store_new_feature_relationship(
												subject_id => $feature_id,
												object_id  => $alignment_feature_id,
												type_id    => $type_id_compseq,
												value      => undef,
												rank       => $hspctr
												);
		
		$self->{_logger}->logdie("feature_relationship_id was not defined.  Could not store relationship between the alignment feature feature_id '$alignment_feature_id' and HSP '$hspctr' for refseq '$refseq' compseq '$compseq'") if (!defined($feature_relationship_id));
	    }
	}
	else{
	    $self->{_logger}->logdie("type_id was not defined for term 'part_of' therefore could not store record in table chado.feature_relationship for the alignment feature feature_id '$alignment_feature_id' and HSP '$hspctr' for refseq '$refseq' compseq '$compseq'");
	}
    }



    $self->{_logger}->warn("Warning flag detected phash contents:\n" . Dumper($phash)) if ($warn_flag > 0);


    return ($feature_id_lookup_d);

    
}

##----------------------------------------------------------------------
## storeBsmlMultipleAlignmentTableComponentInChado()
##
##----------------------------------------------------------------------
sub storeBsmlMultipleAlignmentTableComponentInChado {

    my ($self, %param) = @_;

    $self->{_logger}->debug("Entered store_bsml_multiple_alignment_table") if $self->{_logger}->is_debug();
    
    my $bsmlMultipleAlignmentTable;
    if (exists $param{'BsmlMultipleAlignmentTable'}){
	$bsmlMultipleAlignmentTable = $param{'BsmlMultipleAlignmentTable'};
    }
    else {
	$self->{_logger}->logdie("BsmlMultipleAlignmentTable was not defined");
    }

    my $timestamp;
    if (exists $param{'timestamp'}){
	$timestamp = $param{'timestamp'};
    }
    else {
	$self->{_logger}->logdie("timestamp was not defined");
    }

    my $feature_id_lookup;
    if (exists $param{'feature_id_lookup'}){
	$feature_id_lookup = $param{'feature_id_lookup'};
#	$param{'feature_id_lookup'} = undef;
    }
    else {
	$self->{_logger}->logdie("feature_id_lookup was not defined");
    }

    my $feature_id_lookup_d;
    if ( exists $param{'feature_id_lookup_d'} ){
	$feature_id_lookup_d = $param{'feature_id_lookup_d'};
    }

    my $organism_id;
    if ( exists $param{'organism_id'} ){
	$organism_id = $param{'organism_id'};
    }
    else {
	$self->{_logger}->logdie("organism_id was not defined");
    }
	    
    my $counter;
    if ( exists $param{'counter'} ){
	$counter = $param{'counter'};
    }

    my $class = $bsmlMultipleAlignmentTable->returnattr('class');
    if (!defined($class)){
	$self->{_logger}->logdie("class was not defined for this Multiple-alignment-table object");
    }

    if ( exists $param{'exclude_classes_lookup'}->{$class} ){
	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->warn("Will exclude match feature type '$class'");
	}
 	return;
    }

    my $analysis_id;

    if ( exists $bsmlMultipleAlignmentTable->{'BsmlLink'} ){

	if ( ! exists $param{'analyses_identifier_lookup'} ){
	    $self->{_logger}->logdie("analyses_identifier_lookup was not defined");
	}

	$analysis_id = $self->analysisIdFromBsmlLink($bsmlMultipleAlignmentTable->{'BsmlLink'}, $param{'analyses_identifier_lookup'});
	if (!defined($analysis_id)){
	    $self->{_logger}->logdie("analysis_id was not derived from BSML <Link> elements for the <Multiple-alignment-table>");
	}
    }
    else {
	$self->{_logger}->logdie("BSML <Link> does not exist for some <Multiple-alignment-table>! ".
				 "Cannot derive the analysis_id!");
    }

    my $alignmentLookup = [];

    ## We'll simply capture the length from the first <Aligned-sequence>.  The value will be stored in feature.seqlen.

    my ($bsmlAlignedSequenceCtr, $seqlen) = $self->parseBsmlAlignmentSummaries($bsmlMultipleAlignmentTable, $alignmentLookup);

    my $bsmlSequenceDataCtr = $self->parseBsmlSequenceData($bsmlMultipleAlignmentTable, $alignmentLookup);

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("bsmlSequenceDataCtr '$bsmlSequenceDataCtr' bsmlAlignedSequenceCtr '$bsmlAlignedSequenceCtr' alignmentLookup:". Dumper $alignmentLookup);
    }

    if ($bsmlSequenceDataCtr != $bsmlAlignedSequenceCtr){
	$self->{_logger}->logdie("Number of BSML <Sequence-data> element counted '$bsmlSequenceDataCtr' does not match ".
				 "number of <Aligned-sequence> elements counted '$bsmlAlignedSequenceCtr'");
    }

    if (!defined($seqlen)){
	$self->{_logger}->logdie("seqlen was not defined");
    }

    ## Store a record in chado table feature
    my $feature_id = $self->storeBsmlMultipleAlignmentTableInChadoFeature($bsmlMultipleAlignmentTable,
									  $class,
									  $alignmentLookup,
									  $bsmlSequenceDataCtr,
									  $feature_id_lookup,
									  $feature_id_lookup_d,
									  $seqlen,
									  $timestamp,
									  $organism_id
									  );
    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }

    ## Store BSML <Attribute> element contents in the chado table featureprop
    if (( exists $bsmlMultipleAlignmentTable->{'BsmlAttr'}) && (defined($bsmlMultipleAlignmentTable->{'BsmlAttr'}))){
	$self->storeBsmlAttributesInChadoFeatureprop( $bsmlMultipleAlignmentTable->{'BsmlAttr'}, $feature_id );
    }
    ## Insert a record into chado table analysisfeature
    $self->storeBsmlMultipleAlignmentTableInChadoAnalysisfeature( $feature_id, $analysis_id );

    ## Prepare multiple alignment data for insert into chado.featureloc
    $self->storeBsmlMultipleAlignmentTableInChadoFeatureloc($bsmlMultipleAlignmentTable,
							    $feature_id, 
							    $bsmlSequenceDataCtr,
							    $alignmentLookup,
							    $feature_id_lookup,
							    $feature_id_lookup_d,
							    $class );
}

##----------------------------------------------------------------------
## parseBsmlAlignmentSummaries()
##
##----------------------------------------------------------------------
sub parseBsmlAlignmentSummaries {

    my ($self, $bsmlMultipleAlignmentTable, $alignmentLookup) = @_;

    my $bsmlAlignedSequenceCtr = 0;
    my $seqlen;

    if ( exists $bsmlMultipleAlignmentTable->{'BsmlAlignmentSummaries'}){
	
	if ( scalar (@{$bsmlMultipleAlignmentTable->{'BsmlAlignmentSummaries'}}) > 0 ){

	    foreach my $bsmlAlignmentSummary ( @{$bsmlMultipleAlignmentTable->{'BsmlAlignmentSummaries'}} ) {
		
		if ( exists $bsmlAlignmentSummary->{'BsmlAlignedSequences'}){
		    
		    foreach my $bsmlAlignedSequence ( @{$bsmlAlignmentSummary->{'BsmlAlignedSequences'}} ) {
			
			$bsmlAlignedSequenceCtr++;
			
			my $oncomplement = $bsmlAlignedSequence->returnattr('on-complement');
			if (!defined($oncomplement)){
			    if ($self->{_logger}->is_debug()){
				$self->{_logger}->debug("Could not extract XML attribute 'on-complement' for <BsmlAlignedSequence> number '$bsmlAlignedSequenceCtr'");
			    }
			}
			
			my $length = $bsmlAlignedSequence->returnattr('length');
			if (!defined($length)){
			    $self->{_logger}->logdie("Could not extract XML attribute 'length' for <BsmlAlignedSequence> number '$bsmlAlignedSequenceCtr'");
			}
			
			if (!defined($seqlen)){  $seqlen = $length; }
			
			my $seqnum = $bsmlAlignedSequence->returnattr('seqnum');
			if (!defined($seqnum)){
			    $self->{_logger}->logdie("Could not extract XML attribute 'seqnum' for <BsmlAlignedSequence> number '$bsmlAlignedSequenceCtr'");
			}
			
			my $name = $bsmlAlignedSequence->returnattr('name');
			if (!defined($name)){
			    $self->{_logger}->logdie("Could not extract XML attribute 'name' for <BsmlAlignedSequence> number '$bsmlAlignedSequenceCtr'");
			}
			
			my $start = $bsmlAlignedSequence->returnattr('start');
			if (!defined($start)){
			    if ($self->{_logger}->is_debug()){
				$self->{_logger}->debug("Could not extract XML attribute 'start' for <BsmlAlignedSequence> number '$bsmlAlignedSequenceCtr'");
			    }
			}
			
			push ( @{$alignmentLookup}, [$name, $oncomplement, $length, $seqnum, $start]);
		    }
		}
	    }
	}
	else {
	    $self->{_logger}->logdie("There weren't any <Alignment-summary> objects for some <Multiple-alignment-table>!");
	}
    }
    else {
	$self->{_logger}->logdie("BsmlAlignmentSummaries does not exist for some <Multiple-alignment-table>!");
    }

    return ($bsmlAlignedSequenceCtr, $seqlen);
}


##----------------------------------------------------------------------
## parseBsmlSequenceData()
##
##----------------------------------------------------------------------
sub parseBsmlSequenceData {

    my ($self, $bsmlMultipleAlignmentTable, $alignmentLookup) = @_;

    my $bsmlSequenceDataCtr = 0;

    if ( exists $bsmlMultipleAlignmentTable->{'BsmlSequenceAlignments'}){
	
	if ( scalar (@{$bsmlMultipleAlignmentTable->{'BsmlSequenceAlignments'}}) > 0 ){
	    
	    foreach my $bsmlSequenceAlignment ( @{$bsmlMultipleAlignmentTable->{'BsmlSequenceAlignments'}} ) {
		
		if ( exists $bsmlSequenceAlignment->{'BsmlSequenceData'}){
		    
		    foreach my $bsmlSequenceData ( @{$bsmlSequenceAlignment->{'BsmlSequenceData'}} ) {

			$bsmlSequenceDataCtr++;
			
			my $seqname = $bsmlSequenceData->{'attr'}->{'seq-name'};
			if (!defined($seqname)){
			    $self->{_logger}->logdie("seq-name was not defined while processing <Sequence-data> number '$bsmlSequenceDataCtr'");
			}
		
			if ( defined( $alignmentLookup->[$bsmlSequenceDataCtr - 1][0] )){
			    if ($alignmentLookup->[$bsmlSequenceDataCtr - 1][0] ne $seqname ){
				$self->{_logger}->logdie("<Sequence-data> and <Aligned-sequence> elements are not coordinated!");
			    }
			}
			else {
			    $self->{_logger}->logdie("Looks like the <Aligned-sequence> name attribute was not defined. ".
						     "Noticed this while parsing the <Sequence-data> with seq-name '$seqname'.");
			}

			my $seqAlignmentDat = $bsmlSequenceData->{'seqAlignmentDat'};
			if (!defined($seqAlignmentDat)){
			    if ($self->{_logger}->is_debug()){
				$self->{_logger}->debug("Could not extract the alignment from the <Sequence-data> number '$bsmlSequenceDataCtr'");
			    }
			}
			else {
			    $alignmentLookup->[$bsmlSequenceDataCtr - 1][5] = $seqAlignmentDat;
			}
		    }
		}
	    }
	}
	else {
	    $self->{_logger}->logdie("There weren't any <Sequence-alignment> objects for some <Multiple-alignment-table>!");
	}
    }
    else {
	$self->{_logger}->logdie("BsmlSequenceAlignments does not exist for some <Multiple-alignment-table>!");
    }

    return $bsmlSequenceDataCtr;
}

##----------------------------------------------------------------------
## storeBsmlMultipleAlignmentTableInChadoFeatureloc()
##
##----------------------------------------------------------------------
sub storeBsmlMultipleAlignmentTableInChadoFeatureloc {

    my ($self, $bsmlMultipleAlignmentTable, $feature_id, $bsmlSequenceDataCount, $alignmentLookup, $feature_id_lookup, $feature_id_lookup_d, $class ) = @_;

    ## Each multiple alignment member gets single record inserted into chado.featureloc
    
    my $recctr = 0;
    my $missingSrcFeatureIdCtr=0;
    my @missingFeatureIds;

    foreach my $alignment ( @{$alignmentLookup} ){

	## Description of contents of the alignment array:
	## 0 seqref
	## 1 on-complement
	## 2 length
	## 3 seqnum
	## 4 start
	## 5 seqAlignmentDat
	
	$recctr++;

	my ($seq_name, $numm) = split(/:/, $alignment->[0]);
	
	if (!defined($seq_name)){
	    $self->{_logger}->logdie("seq_name was not defined for feature with feature_id '$feature_id' while processing ".
				     "the <Alignment-summary> that contains '$bsmlSequenceDataCount' <Aligned-sequence> ".
				     "BSML elements.");
	}
	
	my $cog_feature_id;
	
	if ((exists $feature_id_lookup->{$seq_name}->[0]) and (defined($feature_id_lookup->{$seq_name}->[0]))){
	    $cog_feature_id = $feature_id_lookup->{$seq_name}->[0];
	}
	elsif ((exists $feature_id_lookup_d->{$seq_name}->{'feature_id'}) && (defined($feature_id_lookup_d->{$seq_name}->{'feature_id'}))){
	    $cog_feature_id = $feature_id_lookup_d->{$seq_name}->{'feature_id'};
	}
	else {
	    $missingSrcFeatureIdCtr++;
	    push(@missingFeatureIds, $seq_name);
	}

	my $fmin;
	my $fmax;
	my $strand;
	my $rank;
	my $residue_info;
	
	
	if (defined ($alignment->[3])){
	    $rank = $alignment->[3];
	}
	else {
	    $self->{_logger}->logdie("The XML attribute rank was not defined for the BSML <Aligned-sequence> number '$recctr'");
	}
	
	if (  ($class eq 'SNP') ||
	      ($class eq 'nucleotide_deletion') ||
	      ($class eq 'nucleotide_insertion') ||
	      ($class eq 'indel')  ){
	    
	    ## we're only storing data in featureloc.residue_info for these feature types
	    ## multiple sequence alignments are being stored in feature.residues
	    
	    if ( defined($alignment->[5])){
		$residue_info = $alignment->[5];
	    }
	}
	
	if (defined($alignment->[4])){
	    $fmin = $alignment->[4];
	}
	else {
	    if ($self->{_logger}->is_debug()){
		$self->{_logger}->debug("Since the XML attribute 'start' does not exist for the BSML <Aligned-sequence> number '$recctr' ".
					"the software cannot derive the fmin.");
	    }
	}
	
	if (defined($alignment->[2])){
	    my $length = $alignment->[2];
	    
	    if (!defined($fmin)){
		if ($self->{_logger}->is_debug()){
		    $self->{_logger}->debug("The <Aligned-sequence> length was defined but the <Aligned-sequence> start was not! ".
					    "Assigning default value fmin = 0.");
		}
		$fmin = 0;
	    }

	    ## calculate the fmax
	    $fmax = $fmin + $length;
	}
	else {
	    $self->{_logger}->logdie("Since the XML attribute 'length' does not exist for the BSML <Aligned-sequence> number '$recctr', ".
				     "the software cannot derive the fmax.");
	}
	
	
	if (defined($alignment->[1])){
	    my $oncomplement = $alignment->[1];
	    if ($oncomplement == 1){
		$strand = -1;
	    }
	    else {
		$strand = 1;
	    }
	}
	
	$self->prepareFeaturelocRecord($feature_id, $cog_feature_id, 0, $rank, $fmin, $fmax, $strand);
	
    }

    if ( $recctr != $bsmlSequenceDataCount ){
	$self->{_logger}->logdie("Parsed '$bsmlSequenceDataCount' BSML <Aligned-sequence> elements but only created '$recctr' featureloc records");
    }

    if ($missingSrcFeatureIdCtr>0){
	$self->{_logger}->warn("The srcfeature_id could not be found in either feature_id lookups for '$missingSrcFeatureIdCtr' features. ".
			       "As a result, NULLs will be inserted into featureloc.srcfeature_id for the match features that localize to ".
			       "these features.  The chado schema does not require a featureloc.srcfeature_id, however, given our usage ".
			       "convention, inserting NULL values is highly unusal.  Have you considered the fact that you may be loading BSML ".
			       "files into the target chado database in the wrong order?   Here are the features whose feature_id values ".
			       "could not be retrieved from the lookups:");
	foreach my $missing ( @missingFeatureIds ){
	    $self->{_logger}->warn("$missing");
	}
    }
	
    return $feature_id_lookup_d;
}

##--------------------------------------------------------------------------
## checkCoordinatesForChado()
##
##--------------------------------------------------------------------------
sub checkCoordinatesForChado {

    my ($self, $fmin, $fmax) = @_;

    ## If one coordinate is defined, then both should be.
    my $retval = 1;

    if (defined($fmin)){
	if (defined($fmax)){
	    if ($fmin > $fmax){
		$self->{_logger}->fatal("fmin '$fmin' > fmax '$fmax'");
		$retval = 0;
	    }
	}
	else {
	    $self->{_logger}->fatal("fmin '$fmin' is defined, fmax is not");
	    $retval = 0;
	}
    }
    else { ## fmin is not defined
	if (defined($fmax)){
	    $self->{_logger}->fatal("fmin is not defined, fmax '$fmax' is");
	    $retval = 0;
	}
    }

    return $retval;
}

##--------------------------------------------------------------------------
## storeBsmlMultipleAlignmentTableInChadoFeature()
##
##--------------------------------------------------------------------------
sub storeBsmlMultipleAlignmentTableInChadoFeature {

    my ($self, $bsmlMultipleAlignmentTable, $class, $alignmentLookup, $bsmlSequenceDataCount, $feature_id_lookup,
	$feature_id_lookup_d, $seqlen, $timestamp, $organism_id) = @_;
    
    my $md5checksum;
    my $residues;

    if (($class eq 'SNP') or ($class eq 'nucleotide_deletion') or ($class eq 'nucleotide_insertion') or ($class eq 'indel')  ){
	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->debug("Since processing class '$class', will not attempt to retrieve the interlaced multiple sequence alignment");
	}
    }
    else{
	$residues = $self->getInterlacedMultipleSequenceAlignment( $alignmentLookup, $bsmlSequenceDataCount );
	if (!defined($residues)){
	    if ($self->{_logger}->is_debug()){
		$self->{_logger}->debug("residues was not defined for class '$class' ".
					"bsmlSequenceDataCount '$bsmlSequenceDataCount' alignmentLookup:\n" . Dumper($alignmentLookup));
	    }
	}
	else{
	    $md5checksum = Digest::MD5::md5_hex($residues);
	}
    }

    ## For paralogous domain BSML documents, the "domain identifier" will be encoded.  
    ## This domain id should be pushed into the feature.uniquename
    ## Other multiple alignment documents, for example paralogous families and COGS- 
    ## will not store a domain identifier, and thus we need to generate a uniquename
    
    my $uniquename = $bsmlMultipleAlignmentTable->returnattr('id');

    if (!defined($uniquename)){	
	$uniquename = $self->{_id_generator}->next_id( type => $class,
						       project => $self->{_db} );
	if (!defined($uniquename)){
	    $self->{_logger}->logdie("Could not retrieve uniquename from IdGenerator for class '$class' project '$self->{_db}' ".
				     "while processing some BSML <Multiple-alignment-table>.");
	}
    }

    if (!defined($organism_id)){
	$organism_id = $self->dummy_organism();
	if (!defined($organism_id)){
	    $self->{_logger}->logdie("organism_id was not defined");
	}
    }
    
    my $match_cvterm_id = $self->check_cvterm_id_by_name_lookup( name => $class );
    if (!defined($match_cvterm_id)){
	$self->{_logger}->logdie("Could not retrieve cvterm_id for '$class' from static cvterm_id_by_name_lookup");
    }

    my $feature_id;

    my $index = $organism_id . '_' . $uniquename . '_' . $match_cvterm_id;

    if ((exists $feature_id_lookup->{$index}->[0]) and (defined($feature_id_lookup->{$index}->[0]))){
	$feature_id = $feature_id_lookup->{$index}->[0];
	
	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->debug("Found feature_id '$feature_id' for organism_id '$organism_id' uniquename ".
				    "'$uniquename' type_id '$match_cvterm_id' in static feature_id_lookup");
	}
    }
    else {
	
	$feature_id = $self->{_backend}->do_store_new_feature(
							      dbxref_id        => undef,
							      organism_id      => $organism_id,
							      name             => $uniquename,
							      uniquename       => $uniquename,
							      residues         => $residues,
							      seqlen           => $seqlen,
							      md5checksum      => $md5checksum,
							      type_id          => $match_cvterm_id,
							      is_analysis      => 1,
							      is_obsolete      => 0,
							      timeaccessioned  => $timestamp,
							      timelastmodified => $timestamp
							      );
	
	if (!defined($feature_id)){
	    $self->{_logger}->logdie("Could not create feature record for some BSML <Multiple-alignment-table>.  Input values were: ".
				     "organism_id '$organism_id' ".
				     "uniquename '$uniquename' ".
				     "residues '$residues' ".
				     "seqlen '$seqlen' ".
				     "md5checksum '$md5checksum' ".
				     "type_id '$match_cvterm_id' ".
				     "is_analysis '1' ".
				     "is_obsolete '0' ".
				     "timeaccessioned '$timestamp' ".
				     "timelastmodified '$timestamp'");
	}
    }

    return $feature_id;
}

##--------------------------------------------------------------------------
## getOrganismIdForReferenceSequence()
##
##--------------------------------------------------------------------------
sub getOrganismIdForReferenceSequence {
    
    my ($self, $refseq, $feature_id_lookup, $feature_id_lookup_d) = @_;
    
    if ( exists $feature_id_lookup->{$refseq}) {
	if (defined($feature_id_lookup->{$refseq}->[1])){
	    ## Check the static feature_id_lookup
	    return $feature_id_lookup->{$refseq}->[1];
	}
    }

    if ( exists $feature_id_lookup_d->{$refseq} ){
	if ( exists $feature_id_lookup_d->{$refseq}->{'organism_id'} ) {
	    ## Check the non-static feature_id_lookup_d
	    return $feature_id_lookup_d->{$refseq}->{'organism_id'};
	}
    }

    $self->{_logger}->warn("Could not retrieve organism_id for reference sequence '$refseq'");
}


##-------------------------------------------------------------
## storeBsmlMultipleAlignmentTableInChadoAnalysisfeature()
##
##-------------------------------------------------------------
sub storeBsmlMultipleAlignmentTableInChadoAnalysisfeature {

    my ($self, $feature_id, $analysis_id) = @_;

    my $analysisfeature_id = $self->check_analysisfeature_id_lookup(
								    feature_id  => $feature_id,
								    analysis_id => $analysis_id,
								    status      => 'warn'
								    );

    if (!defined($analysisfeature_id)) {

	my $type_id = $self->check_cvterm_id_by_name_lookup( name => 'computed_by');
	if (!defined($type_id)){
	    $self->{_logger}->logdie("type_id was not defined");
	}

	$analysisfeature_id = $self->{_backend}->do_store_new_analysisfeature(
									      feature_id   => $feature_id,
									      analysis_id  => $analysis_id,
									      normscore    => undef,
									      rawscore     => undef,
									      significance => undef,
									      pidentity    => undef,
									      type_id      => $type_id
									      );
	
	if (!defined($analysisfeature_id)){
	    $self->{_logger}->logdie("Could not create analysisfeature record for some BSML <Multiple-alignment-table>. ".
				     "The input values were feature_id '$feature_id' analysis_id '$analysis_id'.");
	}
    }
}

##-------------------------------------------------------------
## analysisIdFromBsmlLink()
##
##-------------------------------------------------------------
sub analysisIdFromBsmlLink {

    my ($self, $bsmlLinks, $analysisIdLookup) = @_;

    my $analysis_id;

    ## Proceed only if there exists some BSML Link element object
    if (  scalar( @ { $bsmlLinks } ) > 0 ) {  
	
	my $bsmlLink = $bsmlLinks->[0];
	
	if (($bsmlLink->{'rel'} eq 'analysis') && ($bsmlLink->{'role'} eq 'computed_by')){
		
	    my $analysis_identifier = $bsmlLink->{'href'};

	    $analysis_identifier =~ s/^\#//;
	    
	    if (( exists $analysisIdLookup->{$analysis_identifier}->{'analysis_id'} ) &&
		( defined($analysisIdLookup->{$analysis_identifier}->{'analysis_id'} ))){
		return  $analysisIdLookup->{$analysis_identifier}->{'analysis_id'};
	    }
	    else {
		$self->{_logger}->logdie("Could not retrieve analysis_id from analysisIdLookup for ".
					 "href '$analysis_identifier' rel '$bsmlLink->{'rel'}' ".
					 "role '$bsmlLink->{'role'}'");
	    }
	}
    }
    else {
	$self->{_logger}->warn("No BSML <Link> elements to process");
    }

    return undef;
}

#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# store_bsml_genome_component()
#
#
#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
sub store_bsml_genome_component {

    my ($self, %param) = @_;
    
    $self->{_logger}->debug("Entered store_bsml_genome_component") if $self->{_logger}->is_debug();
    
    my $phash = \%param;


    #-----------------------------------------------------------------------------------------------------------------
    # Excerpt: http://www.bsml.org/i3c/docs/BSML3_1_Reference_Manual.pdf
    #
    # <!ATTLIST Organism
    #   %attrs;
    #   genus      CDATA #IMPLIED
    #   species    CDATA #IMPLIED
    #   strain     CDATA #IMPLIED
    #   taxon-num  CDATA #IMPLIED
    #   taxonomy   CDATA #IMPLIED
    #   url        %url; #IMPLIED>
    #
    #-----------------------------------------------------------------------------------------------------------------

    ## Extract the "genus" from the BSML API retrieved genome object.  Loader shall die if genus is not available.
    my $genus;

    if ((exists $phash->{'BsmlOrganism'}->{'attr'}->{'genus'}) and (defined($phash->{'BsmlOrganism'}->{'attr'}->{'genus'}))){
	$genus = $phash->{'BsmlOrganism'}->{'attr'}->{'genus'};
    }
    else{
	$self->{_logger}->logdie("genus was not defined");
    }

    ## Extract the "species" from the BSML API retrieved genome object.  Loader shall die if species is not available.
    my $species;
    
    if ((exists $phash->{'BsmlOrganism'}->{'attr'}->{'species'}) and (defined($phash->{'BsmlOrganism'}->{'attr'}->{'species'}))){
	$species= $phash->{'BsmlOrganism'}->{'attr'}->{'species'};
    }
    else{
	$self->{_logger}->logdie("species was not defined");
    }

    ## Extract the <Strain> data
    if ((exists $phash->{'BsmlOrganism'}->{'BsmlStrain'}->[0]->{'BsmlAttr'}->{'name'}) &&
	(defined($phash->{'BsmlOrganism'}->{'BsmlStrain'}->[0]->{'BsmlAttr'}->{'name'}))){
	my $strain = $phash->{'BsmlOrganism'}->{'BsmlStrain'}->[0]->{'BsmlAttr'}->{'name'}->[0];

	if (length($strain) > 0 ){
	    $species .= " $strain";
	}
    }

    ## Extract and append genome_instance attribute to species (and subsequently, common name) if one was provided
    if ((exists $phash->{'BsmlOrganism'}->{'attr'}->{'genome_instance'}) and (defined($phash->{'BsmlOrganism'}->{'attr'}->{'genome_instance'}))){
        $species .= ' '.$phash->{'BsmlOrganism'}->{'attr'}->{'genome_instance'};
    }
    else{
        $self->{_logger}->debug("genome_instance was not defined");
    }


    ## Extract the "abbreviation" value from //Genome/Organism/Attribute/[@name="abbreviation"] content = "value"
    my $abbreviation;

    if ((exists $phash->{'BsmlOrganism'}->{'BsmlAttr'}->{'abbreviation'}) && (defined($phash->{'BsmlOrganism'}->{'BsmlAttr'}->{'abbreviation'}))){
	#
	# Extract the abbreviation value from the //Genome/Organism/Attribute[@name="abbreviation"] content="value"
	#
	$abbreviation = $phash->{'BsmlOrganism'}->{'BsmlAttr'}->{'abbreviation'}->[0];

	#
	# Delete the hash key for abbreviation to ensure that the abbreviation is not stored in table chado.organismprop
	#
	delete $phash->{'BsmlOrganism'}->{'BsmlAttr'}->{'abbreviation'};

    }
    #
    #------------------------------------------------------------------------------------------------------------------------


    #------------------------------------------------------------------------------------------------------------------------
    # comment:   Extract the "comment" value from //Genome/Organism/Attribute/[@name="comment"] content = "value"
    #    
    my $comment;

    if ((exists $phash->{'BsmlOrganism'}->{'BsmlAttr'}->{'comment'}) && (defined($phash->{'BsmlOrganism'}->{'BsmlAttr'}->{'comment'}))){

	$comment = $phash->{'BsmlOrganism'}->{'BsmlAttr'}->{'comment'}->[0];

	#
	# Delete the hash key for comment to ensure that the abbreviation is not stored in table chado.organismprop
	#
	delete $phash->{'BsmlOrganism'}->{'BsmlAttr'}->{'comment'};

    }
    #
    #------------------------------------------------------------------------------------------------------------------------


    ## Extract the "common_name" value from //Genome/Organism/Attribute/[@name="common_name"] content = "value"
    my $common_name;

    if ((exists $phash->{'BsmlOrganism'}->{'BsmlAttr'}->{'common_name'}) && (defined($phash->{'BsmlOrganism'}->{'BsmlAttr'}->{'common_name'}))){
	#
	# Extract the common_name value from the //Genome/Organism/Attribute[@name="common_name"] content="value"
	#
	$common_name = $phash->{'BsmlOrganism'}->{'BsmlAttr'}->{'common_name'}->[0];

	#
	# Delete the hash key for abbreviation to ensure that the abbreviation is not stored in table chado.featureprop
	#
	delete $phash->{'BsmlOrganism'}->{'BsmlAttr'}->{'common_name'};

    }
    else {

	## common_name will be the concatenation of genus and species
	$common_name = $genus . ' ' . $species;
    }
    



    #---------------------------------------------------------------------------------------------
    # comment: Attempt to store a record into chado.organism
    #
    my $organism_id = $self->check_organism_id_lookup(
						      genus   => $genus,
						      species => $species,
						      status  => 'warn'
						      );
    if (!defined($organism_id)){
	
	$organism_id = $self->{_backend}->do_store_new_organism(
								abbreviation => $abbreviation,
								genus        => $genus,
								species      => $species,
								common_name  => $common_name,
								comment      => $comment
								);
	
	$self->{_logger}->logdie("organism_id was not defined for abbreviation '$abbreviation' genus '$genus' species '$species' common_name '$common_name' comment '$comment'") if (!defined($organism_id));
    }
    

    #---------------------------------------------------------------------------------------------
    # comment:  Attempt to store records in chado.organismprop
    #
    foreach my $organism_property (sort keys %{$phash->{'BsmlOrganism'}->{'BsmlAttr'}} ) {


	if (( exists $phash->{'BsmlOrganism'}->{'BsmlAttr'}->{$organism_property}) && 
	    (defined($phash->{'BsmlOrganism'}->{'BsmlAttr'}->{$organism_property})) &&
	    (scalar(@{$phash->{'BsmlOrganism'}->{'BsmlAttr'}->{$organism_property}}) > 0 )) {


	    my $value = $phash->{'BsmlOrganism'}->{'BsmlAttr'}->{$organism_property}->[0];
	    
	    #-------------------------------------------------------------------------------
	    # comment: Attempt to retrieve the cvterm_id from cvterm where name = 'term'
	    #
	    my $type_id = $self->check_cvterm_id_by_name_lookup( name => $organism_property );
	    
	    if (defined($type_id)) {
		
		my $rank = 0;
		
		my $organismprop_id;
		
		do {

		    $organismprop_id = $self->check_organismprop_id_lookup(
									   organism_id => $organism_id,
									   type_id     => $type_id,
									   value       => $value,
									   rank        => $rank
									   );

		} while ((defined($organismprop_id)) && (++$rank));
		    

		$organismprop_id = $self->{_backend}->do_store_new_organismprop(
										organism_id => $organism_id,
										type_id     => $type_id,
										value       => $value,
										rank        => $rank
										);
		
		$self->{_logger}->logdie("organismprop_id was not defined for organism_id '$organism_id' type_id '$type_id' value '$value' rank '$rank'") if (!defined($organismprop_id));
	    }
	    else {
		$self->{_logger}->logdie("type_id was not defined for term '$organism_property' therefore could not store value '$value' for genus '$genus' species '$species'");
	    }
	}
    }


    #------------------------------------------------------------------------------------------
    # comment:  Attempt to insert records into db and dbxref.  
    #
    
    if (( exists $phash->{'BsmlCrossReference'}) && (defined($phash->{'BsmlCrossReference'})) && (scalar(@{$phash->{'BsmlCrossReference'}}) > 0 ) ) {
	
	foreach my $xref (@{$phash->{'BsmlCrossReference'}} ) {

	    #
	    # Attempt to store the BsmlCrossReference data in db and dbxref
	    #
	    my $dbxref_id = $self->store_bsml_cross_reference_component( xref => $xref );

	    #-------------------------------------------------------------------------------------------------------------
	    # comment:  Attempt to retrieve the corresponding chado.organism_dbxref_id
	    #
	    my $organism_dbxref_id = $self->check_organism_dbxref_id_lookup(
									    organism_id => $organism_id,
									    dbxref_id   => $dbxref_id
									    );
	    if (!defined($organism_dbxref_id)){
		
		$organism_dbxref_id = $self->{_backend}->do_store_new_organism_dbxref(
										      organism_id => $organism_id,
										      dbxref_id   => $dbxref_id,
										      );
		
		$self->{_logger}->logdie("organism_dbxref_id was not defined.  Could not insert record into chado.organism_dbxref for organism_id '$organism_id' dbxref_id '$dbxref_id'") if (!defined($organism_dbxref_id));
		
	    }
	}
    }

    return ($organism_id);

}#end sub store_bsml_genome_component {





#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# store_bsml_sequence_component()
#
# Note: it is default behavior to NOT insert newly encountered sequences.  to enable insertion, user must specify --insert_new commandline argument for bsml2chado.pl
#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
sub store_bsml_sequence_component {

    my ($self, %param) = @_;
    
    my $phash = \%param;

    my ($seqdat, $seqobj, $timestamp, $feature_id_lookup, 
	$insert_new, $update, $prevprocessed, $feature_id_lookup_d, 
	$feature_cvterm_id_lookup_d, $featureloc_id_lookup_d,
	$feature_relationship_id_lookup_d, $dummy_organism_id);


    if ((exists $phash->{'seqdat'}) and (defined($phash->{'seqdat'}))){
	$seqdat = $phash->{'seqdat'};
    }
    if ((exists $phash->{'seqobj'}) and (defined($phash->{'seqobj'}))){
	$seqobj = $phash->{'seqobj'};
    }            
    if ((exists $phash->{'timestamp'}) and (defined($phash->{'timestamp'}))){
	$timestamp = $phash->{'timestamp'};
    }
    if ((exists $phash->{'feature_id_lookup'}) and (defined($phash->{'feature_id_lookup'}))){
	$feature_id_lookup = $phash->{'feature_id_lookup'};
    } 
    if ((exists $phash->{'feature_id_lookup_d'}) and (defined($phash->{'feature_id_lookup_d'}))){
	$feature_id_lookup_d = $phash->{'feature_id_lookup_d'};
    } 
    if ((exists $phash->{'insert_new'}) and (defined($phash->{'insert_new'}))){
	$insert_new = $phash->{'insert_new'};
    }        
    if ((exists $phash->{'update'}) and (defined($phash->{'update'}))){
	$update = $phash->{'update'};
    }
    if ((exists $phash->{'prevprocessed'}) and (defined($phash->{'prevprocessed'}))){
	$prevprocessed = $phash->{'prevprocessed'};
    }
    if ((exists $phash->{'dummy_organism_id'}) and (defined($phash->{'dummy_organism_id'}))){
	$dummy_organism_id = $phash->{'dummy_organism_id'};
    }


    ##  Retrieve the id/uniquename
    my $uniquename;

    if ((exists $seqobj->{'id'}) and (defined($seqobj->{'id'}))){
	$uniquename = $seqobj->{'id'};
    }
    else{
	$self->{_logger}->logdie("id was not defined for <Sequence>" . Dumper $seqobj);
    }


    #------------------------------------------------------------------------------------------------------
    # Verify whether the id/uniquename currently exists in the target database via the feature lookup
    #
    #------------------------------------------------------------------------------------------------------

    my $feature_id;

    if ((exists $feature_id_lookup->{$uniquename}->[0]) and (defined($feature_id_lookup->{$uniquename}->[0]))){

	## Check the static feature_id_lookup
	$feature_id = $feature_id_lookup->{$uniquename}->[0]; 
    }
    elsif ((exists $feature_id_lookup_d->{$uniquename}->{'feature_id'}) and (defined($feature_id_lookup_d->{$uniquename}->{'feature_id'}))){
	
	## Check the non-static feature_id_lookup_d
	$feature_id = $feature_id_lookup_d->{$uniquename}->{'feature_id'}; 

	push(@{$prevprocessed}, { uniquename => $uniquename,
				  feature_id => $feature_id});
    }

    #------------------------------------------------------------------------------------------------------
    # Retrieve the class and assign the type_id
    #
    #------------------------------------------------------------------------------------------------------

    my $class;
    my $secondary_class;
    my $type_id;

    if ((exists $seqobj->{'class'}) and (defined($seqobj->{'class'}))){

	$class = $seqobj->{'class'};
	
	($class, $secondary_class) = $self->map_class($class);
	
	$type_id = $self->check_cvterm_id_by_class_lookup( class => $class);

	if (!defined($type_id)){
	    $self->{_logger}->logdie("type_id was not defined for class '$class' while processing <Sequence> '$uniquename'");
	}
    }
    else{
	$self->{_logger}->logdie("class was not defined while processing <Sequence> '$uniquename'");
    }	    


    my $feature_name;
    if ( exists $seqobj->{'title'}){
	$feature_name = $seqobj->{'title'};
    }
    else {
	$feature_name = $uniquename;
    }

    if ( exists $phash->{'exclude_classes_lookup'}->{$class} ) {
	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->debug("Excluding sequence with id '$uniquename' and class '$class'");
	}						      
	return;
    }

    
    ##  The seqlen should be retrieved from the //Sequence/@length BSML attribute if defined, otherwise
    ##  calculated from the length of the residues.
    my $md5checksum;
    my $seqlen;
    
    if (( exists $seqobj->{'length'}) && (defined($seqobj->{'length'}))){
        $seqlen = $seqobj->{'length'};
    }

    if (defined($seqdat)){
        $md5checksum = Digest::MD5::md5_hex($seqdat);
        my $sdl = length($seqdat);
        if (!defined($seqlen)){
            $seqlen = $sdl;
        } elsif ($seqlen != $sdl) {
            $self->{_logger}->logdie("Sequence length ($seqlen) and Seq-Data residue length ($sdl) disagree for sequence with id '$uniquename'");
        }
    }
    
    ##  By default the sequence is assumed to NOT be obsolete.  This value will be stored in chado.feature.is_obsolete.
    my $is_obsolete = 0;

    ##  This <Sequence> element may be linked to numerous <Analysis> elements.  This linking is represented by the nesting
    ##  of <Link> elements below the <Sequence> element.
    ##  One analysisfeature record must be stored in the chado database per link between the Sequence and the Analysis.
    ##  In addition, the is_analysis value for this Sequence feature must be set to 1.

    ##  By default, the Sequence feature is assumed to not be computationally derived (is_analysis = 0 ).
    my $is_analysis = 0;

    ##  The analysis_ids with which this Sequence feature is associated to shall be stored in the analyses array.
    ##  This array will be passed by reference to method add_sequence_to_auxiliary_feature_tables().
    my $analyses = [];


    my $organism_id;

    if ((exists $phash->{'BsmlLink'}) && (defined($phash->{'BsmlLink'})) && ( scalar( @{$phash->{'BsmlLink'}}) > 0 ) ) {
	##  BsmlLink is a reference to an array of hashes
	
	##  Note that since the BSML API instantiates the <Feature> element objects with pointers
	##  to empty anonymous arrays and hashes, we need to verify that the lengths
	##  are greater than zero.  If not greater than zero, then there really is 
	##  nothing in the data structure to process.
	
	my $linktypes = {'genome'   => 1,
			 'analysis' => 1 };
	
	if ((exists $phash->{'analyses_identifier_lookup'}) && (defined($phash->{'analyses_identifier_lookup'}))){
	    ## The analyses_identifier_lookup was constructed in bsml2chado.pl.  
	    ## It will contain the //Analysis/@id to analysis_id mapping.		
	    
	    if ((exists $phash->{'genome_id_2_organism_id'}) && (defined($phash->{'genome_id_2_organism_id'}))){ 
	    
		($organism_id, $is_analysis) = $self->process_bsml_links( bsmllinks       => $phash->{'BsmlLink'},
									  analyses        => $analyses,
									  linktypes       => $linktypes, 
									  organism_id     => $organism_id, 
									  is_analysis     => $is_analysis, 
									  genome_lookup   => $phash->{'genome_id_2_organism_id'},
									  identifier      => $uniquename,
									  analysis_lookup => $phash->{'analyses_identifier_lookup'} );
	    }
	    else {
		$self->{_logger}->logdie("genome_id_2_organism_id was not defined");
	    }
	}
	else {
	    $self->{_logger}->logdie("analyses_identifier_lookup was not defined");
	}
    }




    #------------------------------------------------------------------------------------------------------
    # If the organism_id was not passed in
    # then check if present in the lookup.
    #------------------------------------------------------------------------------------------------------
    if (!defined($organism_id)){
	
	if ((exists $feature_id_lookup_d->{$uniquename}->{'organism_id'}) and (defined($feature_id_lookup_d->{$uniquename}->{'organism_id'}))){

	    ## Check the non-static feature_id_lookup_d
	    $organism_id = $feature_id_lookup_d->{$uniquename}->{'organism_id'};
	}
	else {

	    ## Could not retrieve the organism_id from either lookup therefore need to assign 'not known' value
	    $organism_id = $dummy_organism_id;
	}
    }

    my $dbxref_id;
    

    if ( $update ) {

	if ( defined ( $feature_id ) ) {

	    ## Update the feature record only if feature_id was previously defined
	    $self->update_feature_record(
					 feature_id        => $feature_id,
					 name              => $feature_name,
					 uniquename        => $uniquename,
					 residues          => $seqdat,
					 seqlen            => $seqlen,
					 timelastmodified  => $timestamp,					 
					 o_name            => $feature_id_lookup->{$uniquename}->{'name'},
					 o_md5             => $feature_id_lookup->{$uniquename}->{'md5'}
					 );
	
	    ## Update records in the appropriate tables:
	    ## featureprop, featureloc, feature_relationship, feature_dbxref, feature_cvterm
	    # $self->update_sequence_in_auxiliary_feature_tables();
	}
	else {
	    $self->{_logger}->logdie("Which feature record do you expect to update if feature_id is not defined");
	}
    }
    else {
	## not update mode

	if ( !defined( $feature_id )) {
	    
	    ## This <Sequence> was not previously inserted into the chado database
	    
	    if (!defined($insert_new)){
		## User has specified that only newly encountered features should be inserted into the database
		$self->{_logger}->info("New <Sequence> $uniquename will not be inserted into chado.feature");
		return undef;
	    }
	    
	    if (( exists $phash->{'BsmlCrossReference'}) && (defined($phash->{'BsmlCrossReference'})) && (scalar(@{$phash->{'BsmlCrossReference'}}) > 0 )) {
		
		## The first Cross-reference will be linked via feature.dbxref_id as well as via feature_dbxref.dbxref
		$dbxref_id = $self->store_bsml_cross_reference_component( xref => $phash->{'BsmlCrossReference'}->[0] );
	    }
	    
	    ## Attempt to insert this sequence as a feature in chado.feature
	    $feature_id = $self->{_backend}->do_store_new_feature(
								  'feature_id'        => $feature_id,
								  'dbxref_id'         => $dbxref_id,
								  'organism_id'       => $organism_id,
								  'name'              => $feature_name,
								  'uniquename'        => $uniquename,
								  'residues'          => $seqdat,
								  'seqlen'            => $seqlen,
								  'md5checksum'       => $md5checksum,
								  'type_id'           => $type_id,
								  'is_analysis'       => $is_analysis,
								  'is_obsolete'       => $is_obsolete,
								  'timeaccessioned'   => $timestamp,
								  'timelastmodified'  => $timestamp,
								  );
	
	    if (!defined($feature_id)){
		$self->{_logger}->logdie("feature_id was not defined.  Could not insert record into chado.feature for uniquename '$uniquename'");
	    }
	    else{
	    
		## sub-sequences or sub-features need to be able to reference this sequence/feature
		$feature_id_lookup_d->{$uniquename}->{'feature_id'}  = $feature_id;
		$feature_id_lookup_d->{$uniquename}->{'organism_id'} = $organism_id;
		$feature_id_lookup_d->{$uniquename}->{'seqlen'}      = $seqlen;
	    }
	}
	else {
	    $self->{_logger}->warn("feature_id '$feature_id' was defined therefore this Sequence was previously loaded into the target chado database");
	}
    } ## end not update mode

    
    ## This <Sequence> was previously inserted into the chado database
    if (!defined($organism_id)){

	if (defined($uniquename)){

	    if ((exists $feature_id_lookup->{$uniquename}->[1]) && (defined($feature_id_lookup->{$uniquename}->[1]))){
		$organism_id = $feature_id_lookup->{$uniquename}->[1];
	    }
	    else{
		$self->{_logger}->fatal("No idea what organism_id should be for uniquename '$uniquename'");
	    }
	}
	else {
	    $self->{_logger}->fatal("uniquename was not defined for feature_id '$feature_id'");
	}
    }

    if (defined($feature_id)) {
	
	## Add records to the auxiliary feature tables:
	## featureprop, featureloc, feature_relationship, feature_dbxref, feature_cvterm, etc.
	$self->add_sequence_to_auxiliary_feature_tables(
							feature_id          => $feature_id,
							feature_id_lookup   => $feature_id_lookup,
							feature_id_lookup_d => $feature_id_lookup_d,
							uniquename          => $uniquename,
							seqobj              => $seqobj,
							analyses            => $analyses,
							BsmlAttr            => $phash->{'BsmlAttr'},
							BsmlNumbering       => $phash->{'BsmlNumbering'},
							BsmlAttributeList   => $phash->{'BsmlAttributeList'},
							BsmlCrossReference  => $phash->{'BsmlCrossReference'},
							update              => $update
							);
	
	## Store original class for this Sequence in feature_cvterm
	## if class != secondary_class
	if (lc($class) ne lc($secondary_class)){
	    
	    $self->process_feature_cvterm_record($feature_id, $secondary_class, $uniquename);
	}

    }
	

    #---------------------------------------------------------------------------------
    # Store some mission critical data in the sequence_lookup
    #
    #---------------------------------------------------------------------------------
    my $sequence_lookup;

    if ((exists $phash->{'sequence_lookup'}) && ( defined ($phash->{'sequence_lookup'}))){
	$sequence_lookup = $phash->{'sequence_lookup'};
    }
    else {
	$self->{_logger}->logdie("sequence_lookup was not defined");
    }

    if (defined($feature_id)){
	$sequence_lookup->{$seqobj->{'id'}}->{'feature_id'}  = $feature_id;
    }
    else{
	$self->{_logger}->logdie("feature_id was not defined.  //Sequence/\@id = '$seqobj->{'id'}");
    }
    if (defined($organism_id)){
	$sequence_lookup->{$seqobj->{'id'}}->{'organism_id'} = $organism_id;
    }
    else{
	$self->{_logger}->logdie("organism_id was not defined.  //Sequence/\@id = '$seqobj->{'id'}");
    }
    if (defined($dbxref_id)){
	$sequence_lookup->{$seqobj->{'id'}}->{'dbxref_id'} = $dbxref_id;
    }
    if (defined($seqlen)){
	$sequence_lookup->{$seqobj->{'id'}}->{'seqlen'} = $seqlen;
    }
    

}#end sub store_bsml_sequence_component {



#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# storeBsmlFeatureComponentInChado()
#
# Note: -it is default behavior to insert newly encountered features
#
#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
sub storeBsmlFeatureComponentInChado {

    my ($self, %param) = @_;

    my $phash = \%param;

    my ($seqdat, $sequence_uniquename, $feature, $timestamp, 
	$feature_id_lookup, $autogen, $insert_new, $update, 
	$sequence_lookup, $residue_lookup, $sequence_2_feature,
	$feature_id_lookup_d, $polypeptideToOrganismIdLookup);

    if ((exists $phash->{'sequence_uniquename'}) and (defined($phash->{'sequence_uniquename'}))){
	$sequence_uniquename = $phash->{'sequence_uniquename'};
    }
    if ((exists $phash->{'feature'}) and (defined($phash->{'feature'}))){
	$feature = $phash->{'feature'};
    }
    if ((exists $phash->{'timestamp'}) and (defined($phash->{'timestamp'}))){
	$timestamp = $phash->{'timestamp'};
    }
    if ((exists $phash->{'feature_id_lookup'}) and (defined($phash->{'feature_id_lookup'}))){
	$feature_id_lookup = $phash->{'feature_id_lookup'};
    }
    if ((exists $phash->{'autogen'}) and (defined($phash->{'autogen'}))){
	$autogen = $phash->{'autogen'};
    }
    if ((exists $phash->{'insert_new'}) and (defined($phash->{'insert_new'}))){
	$insert_new = $phash->{'insert_new'};
    }
    if ((exists $phash->{'update'}) and (defined($phash->{'update'}))){
	$update = $phash->{'update'};
    }
    if ((exists $phash->{'sequence_lookup'}) and (defined($phash->{'sequence_lookup'}))){
	$sequence_lookup = $phash->{'sequence_lookup'};
    }
    if ((exists $phash->{'residue_lookup'}) and (defined($phash->{'residue_lookup'}))){
	$residue_lookup = $phash->{'residue_lookup'};
    }
    if ((exists $phash->{'feature_id_lookup_d'}) and (defined($phash->{'feature_id_lookup_d'}))){
	$feature_id_lookup_d = $phash->{'feature_id_lookup_d'};
    }
    if ((exists $phash->{'polypeptideToOrganismIdLookup'}) and (defined($phash->{'polypeptideToOrganismIdLookup'}))){
	$polypeptideToOrganismIdLookup = $phash->{'polypeptideToOrganismIdLookup'};
    }

    #-----------------------------------------------------------------------------------------
    # Retrieve id/uniquename for the <Feature>
    #
    #-----------------------------------------------------------------------------------------
    my $feature_uniquename;

    if ((exists $feature->{'attr'}->{'id'}) and (defined($feature->{'attr'}->{'id'}))){
	$feature_uniquename = $feature->{'attr'}->{'id'};
    }
    else{
	$self->{_logger}->logdie("id was not defined for <Feature>");
    }

    #-----------------------------------------------------------------------------------------
    # Retrieve name for the <Feature>
    #
    #-----------------------------------------------------------------------------------------
    my $feature_name;

    if ((exists $feature->{'attr'}->{'title'}) and (defined($feature->{'attr'}->{'title'}))){
	$feature_name = $feature->{'attr'}->{'title'};
    }
    else{
	$feature_name = $feature_uniquename;
    }


     
    #-----------------------------------------------------------------------------------------
    # Retrieve class and assign type_id
    #
    #-----------------------------------------------------------------------------------------    

    my $class;
    my $secondary_class;
    my $feature_type_id;

    if ((exists $feature->{'attr'}->{'class'}) and (defined($feature->{'attr'}->{'class'}))){
	$class = $feature->{'attr'}->{'class'};

	($class, $secondary_class) = $self->map_class($class);

	$feature_type_id = $self->check_cvterm_id_by_class_lookup( class=> $class );

	if (!defined($feature_type_id)){
	    $self->{_logger}->logdie("feature_type_id was not defined for class '$class' while processing <Feature> '$feature_uniquename'");
	}
    }
    else{
	$self->{_logger}->logdie("class was not defined for <Feature> uniquename '$feature_uniquename'");
    }


    if (exists $phash->{'exclude_classes_lookup'}->{$class}){
	## The software will not process this feature type
	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->debug("Excluding feature with id '$feature_uniquename' class '$class'");
	}
	return;
    }

    #
    # Some features have sequences which are associated to them.  In BSML, this is accomplished via the <Feature> bsmllinks attribute.
    # If the bsmllinks attibute is defined and has a length greater than 0, then we need to store the related sequences' identifiers
    # in the fgrouplookup.
    # Later in the store_bsml_feature_group_component() function, we will store the relationship between this <Feature> and its associated
    # <Sequence> in chado.feature_relationship
    #

    #
    # Also, bsmllinks may contain references to any of:
    # Analysis none to many
    # Sequence none to one
    #
    #
    my $sequence_link;

    ## This <Feature> element may be linked to numerous <Analysis> elements.  This linking is represented by the nesting
    ## of <Link> elements below the <Feature> element.
    ## One analysisfeature record must be stored in the chado database per link between the Feature and the Analysis.
    ## In addition, the is_analysis value for this Feature must be set to 1.
    ## By default, the Feature is assumed to NOT be computationally derived (is_analysis = 0 ).
    my $is_analysis = 0;


    #
    # The analysis_ids with which this Feature is associated to shall be stored in the analyses array.
    # This array will be passed by reference to method add_feature_to_auxiliary_feature_tables().
    #
    my $analyses = [];

    #
    # Because the BSML API instantiates the <Feature> element objects with pointers
    # to empty anonymous arrays and hashes, we need to verify that the lengths
    # are greater than zero.  If not greater than zero, then there really is 
    # nothing in the data structure to process.
    #
    
    if ( (exists $feature->{'BsmlLink'}) and (defined($feature->{'BsmlLink'})) and ( scalar(@{$feature->{'BsmlLink'}}) > 0 )  ) {
	
	#
	# <Feature> elements may have nested <Link> elements.
	# These links tell us whether the feature is related to some <Sequence>.  This relation was necessary for the importation of residue sequences.
	# BSML DTD does not allow residues to be part of the <Feature>.  Chado does.  (In Chado all <Sequence> and <Feature> elements are mapped to 
	# chado.feature table.
	# 
	# These links also tell us whether the particular feature is an artifact of some analysis.
	# If an analysis link is detected, a record should be slotted into the chado.analysisfeature table.
	#
	if ((exists $phash->{'analyses_identifier_lookup'}) && (defined($phash->{'analyses_identifier_lookup'}))){

	    ## The analyses_identifier_lookup was constructed in bsml2chado.pl.  
	    ## It will contain the //Analysis/@id to analysis_id mapping.

	    my $linktypes = { 'analysis' => 1,
			      'sequence' => 1 };
	    
	    my $junk;
	    
	    ($junk, $is_analysis, $sequence_link) = $self->process_bsml_links( bsmllinks       => $feature->{'BsmlLink'}, 
									       analyses        => $analyses,
									       linktypes       => $linktypes,
									       is_analysis     => $is_analysis,
									       sequence_link   => $sequence_link,
									       analysis_lookup => $phash->{'analyses_identifier_lookup'}
									       );
	}
	else {
	    $self->{_logger}->logdie("analyses_identifier_lookup was not defined");
	}
	
    }



    #--------------------------------------------------------------------------------------------------
    # Verify whether the <Feature> is currently loaded in the database as original_feature_uniquename
    #
    #--------------------------------------------------------------------------------------------------
    
    my $feature_id;

    if ((exists $feature_id_lookup->{$feature_uniquename}->[0]) && (defined $feature_id_lookup->{$feature_uniquename}->[0])){
	#
	# Check the static feature_id_lookup
	#
	$feature_id = $feature_id_lookup->{$feature_uniquename}->[0]; 
	if (defined($feature_id)){
	    $self->{_logger}->warn("Found feature_id '$feature_id' for original uniquename '$feature_uniquename', thus this record was loaded into the database during a previous session.  Perhaps you intend to update the auxiliary feature tables...");
	}
	else {

	    if ((exists $feature_id_lookup_d->{$feature_uniquename}->{'feature_id'}) && (defined $feature_id_lookup_d->{$feature_uniquename}->{'feature_id'})){
		#
		# Check the non-static feature_id_lookup_d
		#
		$feature_id = $feature_id_lookup_d->{$feature_uniquename}->{'feature_id'}; 
		if (defined($feature_id)){
		    $self->{_logger}->warn("Found feature_id '$feature_id' for uniquename '$feature_uniquename', thus this record was prepared previously during the current session");
		}
	    }
	}
    }
	    

    #---------------------------------------------------------------------------------------------
    # Extract the feature properties: seqlen, md5checksum and residues
    #
    #---------------------------------------------------------------------------------------------
    my $seqlen;
    my $md5checksum;
    my $residues;


    if (( exists $feature->{'attr'}->{'length'}) && (defined($feature->{'attr'}->{'length'}))){
	$seqlen = $feature->{'attr'}->{'length'};
    }

    #
    # This is where we use the <Link> href to retrieve the residues information from the lookup.
    # (Recall that the <Sequence> elements were parsed twice.  First time to process all the
    # pure <Sequence> elements i.e. assemblies, supercontigs; and to build the lookup of residues
    # for sequences that are actually features.
    # The second <Sequence> parse brought us here- parsing the nested <Feature-tables> and <Feature> elements.)
    #
    if (defined($sequence_link)){

       	if ((exists ($residue_lookup->{$sequence_link})) and (defined($residue_lookup->{$sequence_link}))){

	    $residues = $residue_lookup->{$sequence_link};
    
	    $md5checksum = Digest::MD5::md5_hex($residues);
	    $seqlen      = length($residues);

	}
    }

    if (!defined($seqlen)){

	## Attempt to derive the seqlen from the BSML Interval-loc
	if (exists $feature->{'BsmlInterval-Loc'}){

	    ## We'll derive the seqlen from the first BSML Interval-loc
	    my $bsmlIntervalLoc = $feature->{'BsmlInterval-Loc'}->[0];

	    if (defined($bsmlIntervalLoc)){

		if (( exists $bsmlIntervalLoc->{'startpos'}) && 
		    ( exists $bsmlIntervalLoc->{'endpos'})){
		    
		    $seqlen = ($bsmlIntervalLoc->{'endpos'} - $bsmlIntervalLoc->{'startpos'});
		}
		else {
		    $self->{_logger}->logdie("startpos and endpos were not both defined ".
					     "for feature with uniquename '$feature_uniquename'");
		}
	    }
	}
    }


    #-------------------------------------------------------------------------------------------------------------------------
    # Verify whether this <Sequence> has been stored in the chado.feature during a previous session
    # Retrieve the feature_id
    #
    #-------------------------------------------------------------------------------------------------------------------------
    my $sequence_feature_id;

    if ((exists $feature_id_lookup->{$sequence_uniquename}->[0]) and (defined($feature_id_lookup->{$sequence_uniquename}->[0]))){
	#
	# Check the static feature_id_lookup
	#
	$sequence_feature_id = $feature_id_lookup->{$sequence_uniquename}->[0];

    }
    elsif ((exists $feature_id_lookup_d->{$sequence_uniquename}->{'feature_id'}) and (defined($feature_id_lookup_d->{$sequence_uniquename}->{'feature_id'}))){
	#
	# Check the non-static feature_id_lookup_d
	#
	$sequence_feature_id = $feature_id_lookup_d->{$sequence_uniquename}->{'feature_id'};

    }
    else{
	$self->{_logger}->warn("Could not retrieve feature_id for sequence uniquename '$sequence_uniquename' in either lookup while processing Feature uniquename '$feature_uniquename'");
	$self->{_logger}->fatal(Dumper $feature_id_lookup_d);
	die;
    }


    #------------------------------------------------------------------
    # Store a reference to the feature's corresponding sequence_id for 
    # <Seq-pair-run> processing downstream...
    #
    #------------------------------------------------------------------
    $sequence_lookup->{$sequence_uniquename}->{'feature_uniquename'} = $feature_uniquename;


    my $organism_id;

    if ( exists $sequence_lookup->{$sequence_uniquename}){
	if ( exists $sequence_lookup->{$sequence_uniquename}->{'organism_id'}){
	    $organism_id = $sequence_lookup->{$sequence_uniquename}->{'organism_id'};
	}
    }

    if ($class eq 'polypeptide'){
	if (defined($organism_id)){
	    ## If the polypeptide's organism_id is defined, we need to store
	    ## it in the lookup for when we process the splice_site and
	    ## signal_peptide Features
	    $polypeptideToOrganismIdLookup->{$feature_uniquename} = $organism_id;
	}
    }

    if (!defined($organism_id)){
	if ( exists $polypeptideToOrganismIdLookup->{$sequence_uniquename}){
	    $organism_id =  $polypeptideToOrganismIdLookup->{$sequence_uniquename};
	}
    }

    if (!defined($organism_id)){
	$self->{_logger}->fatal("sequence_lookup:" . Dumper $sequence_lookup);
	$self->{_logger}->fatal("polypeptideToOrganismIdLookup:" . Dumper $polypeptideToOrganismIdLookup);
	$self->{_logger}->logdie("organism_id was not defined for sequence '$sequence_uniquename' ".
				 "while processing feature '$feature_uniquename'");
    }
    
    if ($update){
	#---------------------------------------------------------------------
	# Update mode
	#
	#---------------------------------------------------------------------
	if ( defined ($feature_id) ) {

	    #--------------------------------------------------------------------------
	    # Update the feature record
	    #
	    #--------------------------------------------------------------------------
	    $self->update_feature_record(
					 feature_id        => $feature_id,
					 name              => $feature_name,
					 uniquename        => $feature_uniquename,
					 residues          => $seqdat,
					 seqlen            => $seqlen,
					 timelastmodified  => $timestamp,					 
					 o_name            => $feature_id_lookup->{$feature_uniquename}->{'name'},
					 o_md5             => $feature_id_lookup->{$feature_uniquename}->{'md5'}
					 );
	}
	else {
	    $self->{_logger}->logdie("Which feature record do you expect to update if feature_id is not defined?");
	}
    }
    else {
	#--------------------------------------------------------------------------
	# Not update mode
	#
	#--------------------------------------------------------------------------
	if (!defined($feature_id)) {
	    
	    my $dbxref_id;
	    
	    if ( (exists $feature->{'BsmlCrossReference'}) && (defined($feature->{'BsmlCrossReference'}))  && (scalar(@{$feature->{'BsmlCrossReference'}}) > 0)){
		
		$dbxref_id = $self->store_bsml_cross_reference_component( xref => $feature->{'BsmlCrossReference'}->[0] );
	    }

	    #--------------------------------------------------------------------------
	    # Attempt to insert this sequence as a feature in chado.feature
	    #
	    #--------------------------------------------------------------------------
	    
	    $feature_id = $self->{_backend}->do_store_new_feature(
								  feature_id        => $feature_id,
								  dbxref_id         => $dbxref_id,
								  organism_id       => $organism_id,
								  name              => $feature_name,
								  uniquename        => $feature_uniquename,
								  residues          => $residues,
								  seqlen            => $seqlen,
								  md5checksum       => $md5checksum,
								  type_id           => $feature_type_id,
								  is_analysis       => $is_analysis,
								  is_obsolete       => 0,  ## By default the sequence is assumed to NOT be obsolete
								  timeaccessioned   => $timestamp,
								  timelastmodified  => $timestamp
								  );
	    
	    if (!defined($feature_id)){
		$self->{_logger}->logdie("feature_id was not defined.  Could not insert record into chado.feature for uniquename '$feature_uniquename'");
	    }
	    else{
		
		#--------------------------------------------------------------------------
		# sub-sequences or sub-features need to be able to reference this sequence/feature
		#
		#--------------------------------------------------------------------------
		$feature_id_lookup_d->{$feature_uniquename}->{'feature_id'}  = $feature_id;
		$feature_id_lookup_d->{$feature_uniquename}->{'seqlen'}      = $seqlen;
		$feature_id_lookup_d->{$feature_uniquename}->{'organism_id'} = $organism_id;
		
	    }
	}
    }
	 
    if (lc($class) ne lc($secondary_class)){
	##  Store record in feature_cvterm for this <Feature> only if the class != secondary_class
	$self->process_feature_cvterm_record($feature_id,
					     $secondary_class,
					     $feature_uniquename);
    }
    

    if ((defined($analyses)) && (scalar(@{$analyses}) > 0) ){
	## The data available in the BSML <Link> elements with roles 'analysis' nested below the BSML <Feature>
	## elements are stored in the chado table analysisfeature.
	$self->storeBsmlAnalysisLinkInChadoAnalysisfeature($analyses,
							   $feature_id,
							   $feature_uniquename,
							   $feature->{'BsmlAttr'} );
    }

    if (  (exists $feature->{'BsmlCrossReference'}) && (defined($feature->{'BsmlCrossReference'})) && (scalar(@{$feature->{'BsmlCrossReference'}}) > 0 ) ){
	## The data available in the BSML <Cross-reference> elements nested below the BSML <Feature> elements
	## are stored in the chado tables dbxref and feature_dbxref.
	$self->storeBsmlCrossReferencesInDbxrefAndFeatureDbxref(
								$feature->{'BsmlCrossReference'},
								$feature_id,
								$feature_uniquename );
    }

    if ((exists $feature->{'BsmlAttr'}) && (defined($feature->{'BsmlAttr'})) ) {
	## The data available in the BSML <Attribute> elements nested below the BSML <Feature> elements
	## are stored in the chado table featureprop.
	$self->storeBsmlAttributesInChadoFeatureprop(
						     $feature->{'BsmlAttr'},
						     $feature_id,
						     $feature_uniquename );
    }

    if ((exists $feature->{'BsmlAttributeList'}) && (defined($feature->{'BsmlAttributeList'})) && (scalar(@{$feature->{'BsmlAttributeList'}}) > 0 )){
	## Length of array check is necessary because BSML API declares 
	## BSML class attributes as anonymous empty data structures.
	##
	$self->storeBsmlAttributeListsInChadoFeatureCvtermAndFeatureCvtermprop(
									       $feature->{'BsmlAttributeList'}, 
									       $feature_id,
									       $feature_uniquename );
    }

    if ((exists $feature->{'BsmlInterval-Loc'}) and (defined($feature->{'BsmlInterval-Loc'}))){
	## The data available in the BSML <Interval-loc> elements are stored 
	## in the chado table featureloc.
	$self->storeBsmlIntervalLocInChadoFeatureloc(
						     $feature->{'BsmlInterval-Loc'}, 
						     $feature_id, 
						     $feature_uniquename, 
						     $sequence_feature_id, 
						     $class,
						     $phash->{'exon_coordinates'});
    }

    if ((exists $feature->{'BsmlSite-Loc'}) and (defined($feature->{'BsmlSite-Loc'}))){
	## The data available in the BSML <Site-loc> elements 
	## are stored in the chado table featureloc.
	$self->storeBsmlSiteLocInChadoFeatureloc(
						 $feature->{'BsmlSite-Loc'}, 
						 $feature_id, 
						 $feature_uniquename,
						 $sequence_feature_id );
    }


    if (defined($sequence_link)){
	if ((exists $phash->{'sequence_2_feature'})  and (defined($phash->{'sequence_2_feature'}))){
	    ## Cache info regarding this BSML <Link> to some BSML <Sequence>
	    $phash->{'sequence_2_feature'}->{$sequence_link} = $feature_uniquename;
	}
    }
}


#----------------------------------------------------------------
# assembly_and_scaffold_feature_id_lookup()
#
#----------------------------------------------------------------
sub assembly_and_scaffold_feature_id_lookup {

    my($self) = @_;
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    my @s;

    my $ret = $self->{_backend}->get_assembly_and_scaffold_feature_id_lookup();

    for (my $i=0; $i<scalar(@$ret); $i++) {
	$s[$i]->{'feature_id'}  = $ret->[$i][0];
	$s[$i]->{'uniquename'}  = $ret->[$i][1];
	$s[$i]->{'organism_id'} = $ret->[$i][2];
	$s[$i]->{'chromosome'}  = $ret->[$i][3];
	
    }

    return \@s;
}

#------------------------------------------------------------------------------
# get_interlaced_sequence()
#
#------------------------------------------------------------------------------  
sub get_interlaced_sequence {

    my ($self, %parameter) = @_;

    $self->{_logger}->debug("Entered get_interlaced_sequence") if $self->{_logger}->is_debug();


    my $phash = \%parameter;
    my $alignmentLookup;
    my $count;
    my $sequence;

    #-------------------------------------------------------
    # Extract arguments from parameter hash
    #
    #--------------------------------------------------------
    $alignmentLookup = $phash->{'alignmentLookup'}  if (exists $phash->{'alignmentLookup'});
    $count         = $phash->{'seq_data_count'} if (exists $phash->{'seq_data_count'});

    #--------------------------------------------------------
    # Verify whether arguments were defined
    #
    #--------------------------------------------------------
    if (!defined($alignmentLookup)){
	$self->{_logger}->logdie("alignmentLookup was not defined");
    }
    if (!defined($count)){
	$self->{_logger}->logdie("count was not defined");
    }
    
    my $seq;
    my $arr_length;
    my $tmp_array = [];
    for (my $i=0;$i<$count;$i++){

	$seq = $alignmentLookup->{'alignment'};

	my @arr = split(/\n/,$seq);
	my $array_length = @arr;
	$arr_length = @arr;

	for (my $j=0;$j<$arr_length;$j++){
	    $tmp_array->[$i]->[$j] = $arr[$j];
	}
    }

    for (my $j=0;$j<$arr_length;$j++){
	for (my $i=0;$i<$count;$i++){
	    my $val = $tmp_array->[$i]->[$j];
	    $sequence = $sequence . $val . "\n";
	}
	$sequence .= "\n";
	
    }
    
    return $sequence;

}#end sub get_interlaced_sequence()


#------------------------------------------------------------------------------
# getInterlacedMultipleSequenceAlignment()
#
#------------------------------------------------------------------------------  
sub getInterlacedMultipleSequenceAlignment {

    my ($self, $lookup, $count) = @_;

    if (!defined($lookup)){
	$self->{_logger}->logdie("lookup was not defined");
    }
    if (!defined($count)){
	$self->{_logger}->logdie("count was not defined");
    }

    my $sequence;
    my $arr_length;
    my $tmp_array = [];

    my $seqDataCtr=0;

    ## increment the count by one
    $count++;

    foreach my $array ( @{$lookup}){

	$seqDataCtr++;

 	my $seq = $array->[5];

 	my @arr = split(/\n/,$seq);

 	$arr_length = @arr;

 	for (my $j=0;$j<$arr_length;$j++){
 	    $tmp_array->[$seqDataCtr]->[$j] = $arr[$j];
 	}
     }

    for (my $j=0;$j<$arr_length;$j++){
	 for (my $i=0;$i<$count;$i++){
 	    my $val = $tmp_array->[$i]->[$j];
 	    $sequence = $sequence . $val . "\n";
 	}
 	$sequence .= "\n";
	
    }

    return $sequence;
}

#----------------------------------------------------------
# check_constraint()
#
#
#----------------------------------------------------------
sub check_constraint {

    my ($self, $hashref, $constraint_name, $quiet) = @_;


    $self->{_logger}->logdie("hashref was not defined") if (!defined($hashref));
    $self->{_logger}->logdie("constraint_namef was not defined") if (!defined($constraint_name));


    $self->{_logger}->debug("Verifying database constraint: $constraint_name") if $self->{_logger}->is_debug();

    my $error_count =0;

    foreach my $key (sort keys %$hashref){
	
	my $val = $$hashref{$key} if (exists ($hashref->{$key}));
	
	$self->{_logger}->logdie("val was not defined for key '$key'") if (!defined($val));
	
	if ($val > 1){
	    $self->{_logger}->fatal("key '$key' occured '$val' times");
	    $error_count++;
	}
    }
    if ($error_count < 1){
	if (!$quiet){
	    print STDERR ("Database constraint $constraint_name is not violated\n");
	    $self->{_logger}->debug("Database constraint $constraint_name is not violated") if $self->{_logger}->is_debug();
	}
    }
    else{
	$self->{_logger}->fatal("Database constraint $constraint_name is violated");
    }
}


#--------------------------------------------------------
# get_file_contents()
#
#
#--------------------------------------------------------
sub get_file_contents {

    my ($self, $file) = @_;


    $self->{_logger}->debug("Entered get_file_contents") if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("file was not defined") if (!defined($file));

    $self->check_file_status($file);

    open (IN_FILE, "<$file") || $self->{_logger}->logdie("Could not open file: $file for input");
    my @contents = <IN_FILE>;
    chomp @contents;

    close IN_FILE or $self->{_logger}->warn("Could not close file '$file'");


    return \@contents;


}#end sub get_file_contents()


#-------------------------------------------------------------------
# check_file_status()
#
#-------------------------------------------------------------------
sub check_file_status {

    my ($self, $file) = @_;


    $self->{_logger}->logdie("file '$file' was not defined") if (!defined($file));

    $self->{_logger}->logdie("file '$file' does not exist") if (!-e $file);

    $self->{_logger}->logdie("file '$file' does not have read permissions") if (!-r $file);
    

}#end sub check_file_status




#----------------------------------------------------------------
# dummy_organism()
#
#----------------------------------------------------------------
sub dummy_organism {

    my $self = shift;

    my $organism_id = $self->check_organism_id_lookup( genus   => 'not known',
						       species => 'not known' );
    if (!defined($organism_id)){
	$organism_id = $self->{_backend}->do_store_new_organism( abbreviation => 'not known',
								 genus        => 'not known',
								 species      => 'not known',
								 common_name  => 'not known',
								 comment      => 'not known' );


	if (!defined($organism_id)){
	    $self->{_logger}->logdie("Could not insert record into chado.organism for dummy organism");
	}
    }

    return $organism_id;

}


#---------------------------------------------------------
# organismhash()
#
#---------------------------------------------------------
sub organismhash {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;


    my($ret, @s, $i);
    
    $ret = $self->{_backend}->get_organismhash();
    
    for ($i=0; $i<scalar(@$ret); $i++) {
	$s[$i]->{'organism_id'}  = $ret->[$i][0];
	$s[$i]->{'genus'}        = $ret->[$i][1];
	$s[$i]->{'species'}      = $ret->[$i][2];
    }
    return \@s;
}



#----------------------------------------------------------------
# cvterm_name_from_cvterm()
#
#----------------------------------------------------------------
sub cvterm_name_from_cvterm {

    my($self) = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_cvterm_name_from_cvterm(@_);

    $self->{_logger}->logdie("ret was not defined") if (!defined($ret));

    return  $ret;
}


#----------------------------------------------------------------
# sequence_mappings_for_two_types()
#
#----------------------------------------------------------------
sub sequence_mappings_for_two_types {

    my ($self) =  shift;

   $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my($ret, @s, $i);
        
    $ret = $self->{_backend}->get_sequence_mappings_for_two_types(@_);

    for ($i=0; $i<scalar(@$ret); $i++) {
	$s[$i]->{'s_feature_id'}  = $ret->[$i][0];
	$s[$i]->{'s_uniquename'}  = $ret->[$i][1];
	$s[$i]->{'a_feature_id'}  = $ret->[$i][2];
	$s[$i]->{'a_uniquename'}  = $ret->[$i][3];
	$s[$i]->{'a_fmin'}        = $ret->[$i][4];
	$s[$i]->{'a_fmax'}        = $ret->[$i][5];
	$s[$i]->{'a_strand'}      = $ret->[$i][6];
    }

    return \@s;

}


#----------------------------------------------------------------
# features_to_sequence_by_sequence_type1()
#
#----------------------------------------------------------------
sub features_to_sequence_by_sequence_type1 {

    my ($self) =  shift;

   $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my($ret, @s, $i);
        
    $ret = $self->{_backend}->get_features_to_sequence_by_sequence_type1(@_);

    for ($i=0; $i<scalar(@$ret); $i++) {

	$s[$i]->{'parent_feature_id'}  = $ret->[$i][0];
	$s[$i]->{'parent_uniquename'}  = $ret->[$i][1];
	$s[$i]->{'parent_type_id'}     = $ret->[$i][2];
	$s[$i]->{'feature_id'}         = $ret->[$i][3];
	$s[$i]->{'uniquename'}         = $ret->[$i][4];
	$s[$i]->{'fmin'}               = $ret->[$i][5];
	$s[$i]->{'fmax'}               = $ret->[$i][6];
	$s[$i]->{'strand'}             = $ret->[$i][7];
	$s[$i]->{'type_id'}            = $ret->[$i][8];
	
    }

    return \@s;

}


#----------------------------------------------------------------
# features_to_sequence_by_sequence_type2()
#
#----------------------------------------------------------------
sub features_to_sequence_by_sequence_type2 {

    my ($self) =  shift;

   $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my($ret, @s, $i);
        
    $ret = $self->{_backend}->get_features_to_sequence_by_sequence_type2(@_);

    for ($i=0; $i<scalar(@$ret); $i++) {

	$s[$i]->{'parent_feature_id'}  = $ret->[$i][0];
	$s[$i]->{'parent_uniquename'}  = $ret->[$i][1];
	$s[$i]->{'parent_type_id'}     = $ret->[$i][2];
	$s[$i]->{'feature_id'}         = $ret->[$i][3];
	$s[$i]->{'uniquename'}         = $ret->[$i][4];
	$s[$i]->{'fmin'}               = $ret->[$i][5];
	$s[$i]->{'fmax'}               = $ret->[$i][6];
	$s[$i]->{'strand'}             = $ret->[$i][7];
	$s[$i]->{'type_id'}            = $ret->[$i][8];
	
    }

    return \@s;

}

#----------------------------------------------------------------
# exclusive_features_to_parent_sequence()
#
#----------------------------------------------------------------
sub exclusive_features_to_parent_sequence {

    my ($self) =  shift;

   $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my($ret, @s, $i);
        
    $ret = $self->{_backend}->get_exclusive_features_to_parent_sequence(@_);

    for ($i=0; $i<scalar(@$ret); $i++) {

	$s[$i]->{'parent_feature_id'}  = $ret->[$i][0];
	$s[$i]->{'parent_uniquename'}  = $ret->[$i][1];
	$s[$i]->{'parent_type_id'}     = $ret->[$i][2];
	$s[$i]->{'feature_id'}         = $ret->[$i][3];
	$s[$i]->{'uniquename'}         = $ret->[$i][4];
	$s[$i]->{'fmin'}               = $ret->[$i][5];
	$s[$i]->{'fmax'}               = $ret->[$i][6];
	$s[$i]->{'strand'}             = $ret->[$i][7];
	$s[$i]->{'type_id'}            = $ret->[$i][8];
	$s[$i]->{'phase'}              = $ret->[$i][9];
	$s[$i]->{'residue_info'}       = $ret->[$i][10];
	$s[$i]->{'seqlen'}             = $ret->[$i][11];
	$s[$i]->{'rank'}               = $ret->[$i][12];
	
    }

    return \@s;

}

#----------------------------------------------------------------
# exclusive_features_to_child_sequence()
#
#----------------------------------------------------------------
sub exclusive_features_to_child_sequence {

    my ($self) =  shift;

   $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my($ret, @s, $i);
        
    $ret = $self->{_backend}->get_exclusive_features_to_child_sequence(@_);

    for ($i=0; $i<scalar(@$ret); $i++) {

	$s[$i]->{'parent_feature_id'}  = $ret->[$i][0];
	$s[$i]->{'parent_uniquename'}  = $ret->[$i][1];
	$s[$i]->{'parent_type_id'}     = $ret->[$i][2];
	$s[$i]->{'feature_id'}         = $ret->[$i][3];
	$s[$i]->{'uniquename'}         = $ret->[$i][4];
	$s[$i]->{'fmin'}               = $ret->[$i][5];
	$s[$i]->{'fmax'}               = $ret->[$i][6];
	$s[$i]->{'strand'}             = $ret->[$i][7];
	$s[$i]->{'type_id'}            = $ret->[$i][8];
	$s[$i]->{'phase'}              = $ret->[$i][9];
	$s[$i]->{'residue_info'}       = $ret->[$i][10];
	$s[$i]->{'rank'}               = $ret->[$i][11];
	
    }

    return \@s;

}

#----------------------------------------------------------------
# create_view()
#
#----------------------------------------------------------------
sub create_view {

    my ($self) =  shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->doCreateView(@_);

}

#----------------------------------------------------------------
# drop_filters()
#
#----------------------------------------------------------------
sub drop_filters {

    my ($self) =  shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->do_drop_filters(@_);

}

#----------------------------------------------------------------
# execute_sql_instructions_from_file()
#
#----------------------------------------------------------------
sub execute_sql_instructions_from_file {

    my ($self) =  shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->do_execute_sql_instructions_from_file(@_);

}

#----------------------------------------------------------------
# populate_stats_tables()
#
#----------------------------------------------------------------
sub populate_stats_tables {

    my ($self) =  shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->do_populate_stats_tables(@_);

}


#-------------------------------------------------------------------
# add_sequence_to_auxiliary_feature_tables()
#
#-------------------------------------------------------------------
sub add_sequence_to_auxiliary_feature_tables {

    my ($self, %param) = @_;
    
    $self->{_logger}->debug("Entered add_sequence_to_auxiliary_feature_tables") if $self->{_logger}->is_debug();
    
    my $phash = \%param;

    my ($feature_id, $feature_id_lookup, $uniquename, $seqobj, $feature_id_lookup_d);

    if ((exists $phash->{'feature_id'}) and (defined($phash->{'feature_id'}))){
	$feature_id = $phash->{'feature_id'};
    }
    else{
	$self->{_logger}->error("feature_id was not defined");
	return undef;
    }
    if ((exists $phash->{'feature_id_lookup'}) and (defined($phash->{'feature_id_lookup'}))){
	$feature_id_lookup = $phash->{'feature_id_lookup'};
    }
    else{
  	$self->{_logger}->error("feature_id_lookup was not defined");
	return undef;
    }
    if ((exists $phash->{'feature_id_lookup_d'}) and (defined($phash->{'feature_id_lookup_d'}))){
	$feature_id_lookup_d = $phash->{'feature_id_lookup_d'};
    }
    else{
  	$self->{_logger}->error("feature_id_lookup_d was not defined");
	return undef;
    }
    if ((exists $phash->{'uniquename'}) and (defined($phash->{'uniquename'}))){
	$uniquename = $phash->{'uniquename'};
    }
    else{
	$self->{_logger}->error("uniquename was not defined");
	return undef;
    }
    if ((exists $phash->{'seqobj'}) and (defined($phash->{'seqobj'}))){
	$seqobj = $phash->{'seqobj'};
    }

    ## bsml2chado.pl and supporting Prism API should store one record in analysisfeature per each existing <Link> between a <Sequence> and some <Analysis>
    my $analyses;

    if ((exists $phash->{'analyses'}) and (defined($phash->{'analyses'}))){
	$analyses = $phash->{'analyses'};
    }


    if (defined($analyses)){

	if (length(scalar(@{$analyses})) > 0 ){

	    ## //Link/@role shall explicitly direct the assignment of the analysisfeature.type_id

	    foreach my $analysis_hash ( @{$analyses} ){

		if (( exists $analysis_hash->{'id'} ) && (defined($analysis_hash->{'id'}))){

		    my $analysis_id = $analysis_hash->{'id'};

		    if (( exists $analysis_hash->{'role'} ) && (defined($analysis_hash->{'role'}))){

			my $role = $analysis_hash->{'role'};

			my $type_id = $self->check_cvterm_id_by_class_lookup( class => $role );


			#
			# temporary until ontology is updated.
			#
			if (!defined($type_id)){

			    if ($role eq 'compute_by'){
				$type_id = $self->check_cvterm_id_by_name_lookup( name => 'computed_by');
			    }
			    elsif ($role eq 'input_of'){
				$type_id = $self->check_cvterm_id_by_name_lookup( name => 'input_of');
			    }
			    else{
				$self->{_logger}->logdie("Unexpected role 'role'");
			    }
			}


			my $analysisfeature_id = $self->check_analysisfeature_id_lookup(
											feature_id  => $feature_id,
											analysis_id => $analysis_id,
											status      => 'warn'
											);
			if (!defined($analysisfeature_id)) {
		    
			    #
			    # Attempt to store a record in chado.analysisfeature
			    #
			    $analysisfeature_id = $self->{_backend}->do_store_new_analysisfeature(
												  'feature_id'  => $feature_id,
												  'analysis_id' => $analysis_id,
												  'type_id'     => $type_id
												  );
		    
			    $self->{_logger}->logdie("analysisfeature_id was not defined. Could not insert record into chado.analysisfeature for feature_id 'feature_id' analysis_id '$analysis_id'") if (!defined($analysisfeature_id));
			}
		    }
		    else {
			$self->{_logger}->error("role was not defined for feature_id '$feature_id' analysis_id '$analysis_id' uniquename '$uniquename'");
		    }
		}
		else {
		    $self->{_logger}->logdie("analysis_id was not defined for feature_id '$feature_id' uniquename '$uniquename'");
		}
	    }
	}
    }
    #
    #
    #---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    
    if (exists $seqobj->{'molecule'}){
	## Extract the value stored in the BSML Sequence XML-attribute 'molecule'
	## and make arrangments for it to be stored in featureprop with
	## qualified controlled vocabulary term 'molecule_type'.
	push(@{$phash->{'BsmlAttr'}->{'molecule_type'}}, $seqobj->{'molecule'});
    }

    if (exists $seqobj->{'topology'}){
	## Extract the value stored in the BSML Sequence XML-attribute 'topology'
	## and make arrangments for it to be stored in featureprop with
	## qualified controlled vocabulary term 'topology'.
	push(@{$phash->{'BsmlAttr'}->{'topology'}}, $seqobj->{'topology'});
    }

    if (( exists $phash->{'BsmlAttr'}) && (defined($phash->{'BsmlAttr'})) ) {

	#-------------------------------------------------------------------------------------------------------- 
	# insert record into chado.featureprop related to the stored BSML attributes
	#
	#-------------------------------------------------------------------------------------------------------- 

	foreach my $name (sort keys %{$phash->{'BsmlAttr'}} ){
	    
	    
	    #
	    # Compute BSML documents still have
	    #
	    #  <Sequence length="494" title="lma1.51.m00066_polypeptide" molecule="aa" id="lma1.51.m00066_polypeptide">
	    #     <Attribute name="ASSEMBLY" content="lma1_51_assembly"></Attribute>
	    #
	    # bsml2chado.pl should not load the <Attribute> with name="ASSEMBLY"
	    #
	    #
	    if (lc($name) eq 'assembly'){
		$self->{_logger}->warn("We are not loading the <Attribute> contents which refer to some assembly -- such is the case for this record feature_id '$feature_id' uniquename '$uniquename' name '$name'.  Are you still storing reference to an assembly as an <Attribute> to a polypeptide <Sequence> ?");
		next;
	    }
	    
	    if (( exists $phash->{'BsmlAttr'}->{$name}) && 
		( defined($phash->{'BsmlAttr'}->{$name})) && 
		( scalar(@{$phash->{'BsmlAttr'}->{$name}}) > 0 )) {
		
		my $type_id = $self->check_cvterm_id_by_name_lookup( name => $name);

		if (!defined($type_id)){
		    $self->{_logger}->fatal("cvterm.cvterm_id was not defined for cvterm.name = '$name'");
		    next;
		}

		my $content = $phash->{'BsmlAttr'}->{$name}->[0];

		$self->prepareFeaturepropRecord($feature_id, $type_id, $content);
		
	    }
	    else {
		$self->{_logger}->logdie("content was not defined for name '$name'");
	    }
	}
    }





    if ( ( exists $phash->{'BsmlAttributeList'} ) && (defined($phash->{'BsmlAttributeList'}) ) && ( scalar(@{$phash->{'BsmlAttributeList'}}) > 0 ) ){
	$self->storeBsmlAttributeListsInChadoFeatureCvtermAndFeatureCvtermprop($phash->{'BsmlAttributeList'}, $feature_id, $uniquename);
    }


    if (( exists $phash->{'BsmlNumbering'}->{'attr'}) && (defined($phash->{'BsmlNumbering'}->{'attr'})) ) {

	my $numobj = $phash->{'BsmlNumbering'}->{'attr'};

	#
	# This feature needs to be localized and related to other features
	# i.e. need to insert records into chado.featureloc and chado.feature_relationship
	#
	
	$self->{_logger}->debug("feature_id '$feature_id' uniquename '$uniquename'") if $self->{_logger}->is_debug;
	
	my $object_id;

	#
	# Check the static feature_id_lookup
	#
	if ((exists $feature_id_lookup->{$numobj->{'seqref'}}->[0]) && (defined($feature_id_lookup->{$numobj->{'seqref'}}->[0]))){
	    $object_id  = $feature_id_lookup->{$numobj->{'seqref'}}->[0];
	} 
	elsif ((exists $feature_id_lookup_d->{$numobj->{'seqref'}}->{'feature_id'}) && (defined($feature_id_lookup_d->{$numobj->{'seqref'}}->{'feature_id'}))){
	    $object_id = $feature_id_lookup_d->{$numobj->{'seqref'}}->{'feature_id'};
	}
	else {
	    $self->{_logger}->fatal("Could not find a feature_id in either lookup for uniquename '$numobj->{'seqref'}'.  Therefore cannot insert records into chado.{feature_relationship,featureloc}");
	    return undef; 
	}
	
	my $orientation = $numobj->{'ascending'} if ((exists $numobj->{'ascending'}) and (defined($numobj->{'ascending'})));
	my $refnum      = $numobj->{'refnum'}    if ((exists $numobj->{'refnum'})    and (defined($numobj->{'refnum'})));
	my $length      = $seqobj->{'length'}    if ((exists $seqobj->{'length'})    and (defined($seqobj->{'length'})));
	
	#----------------------------------------------------------------------------------------------------------------------------------
	# Insert record into chado.feature_relationship
	# At some point we may need to implement logic for determining feature_relationship.type_id
	# Right now, the only <Sequence> types are Genomic scaffolds and contigs.  Contigs are always 'partof' Genomic scaffolds
	#
	#----------------------------------------------------------------------------------------------------------------------------------

	#
	# Check the static cvterm_id_by_name_lookup
	#
	my $type_id = $self->check_cvterm_id_by_name_lookup( name => 'part_of');
	
	if (defined($type_id)){ 
	
	    my $rank = 0;

	    my $feature_relationship_id;

	    #
	    # feature_relationship supports the insertion of many relationships between two features.
	    # The rank simply needs to be incremented to the correct value.
	    # Problem with this code: 
	    # 1) What assurances does the client have that the specified rank value will be stored? none.
	    # 2) This code will iterate over all relationship records until the max rank is encountered.
	    # 3) umm...
	    #
	    do {
		
		$feature_relationship_id = $self->check_feature_relationship_id_lookup(
										       subject_id => $feature_id,
										       object_id  => $object_id,
										       type_id    => $type_id,
										       rank       => $rank,
										       status     => 'warn'
										       );
	    } while ( (defined($feature_relationship_id)) && ( ++$rank));
	    
	    #
	    # Could not find feature_relationship_id in either lookup
	    # therefore attempt to insert record into chado.feature_relationship
	    # The API maintains a record lookup per table.
	    #
	    $feature_relationship_id = $self->{_backend}->do_store_new_feature_relationship(
											    subject_id => $feature_id,
											    object_id  => $object_id,
											    type_id    => $type_id,
											    rank       => $rank
											    );
	    
	    $self->{_logger}->logdie("feature_relationship_id was not defined.  Could not insert record into chado.feature_relationship for subject '$feature_id' object_id '$object_id' type_id '$type_id' rank '$rank'") if (!defined($feature_relationship_id));

	    
	}
	else {
	    $self->{_logger}->logdie("type_id was not defined for term 'part_of'");
	}

	#----------------------------------------------------------------------------------------------------------------------------------
	# Insert record into chado.featureloc
	#
	#----------------------------------------------------------------------------------------------------------------------------------

	my ($fmin, $fmax, $strand);
	
	if ($orientation == 1){
	    $fmin = $refnum;  $fmax = $refnum + $length; $strand = 1;
	}
	elsif ($orientation == 0){
	    $fmin = $refnum - $length; $fmax = $refnum; $strand = -1;
	}
	
	$self->prepareFeaturelocRecord($feature_id, $object_id, 0, 0, $fmin, $fmax, $strand);
	
    }
    else {
	$self->{_logger}->debug("numobj was not defined, therefore will not add records to tables featureloc, feature_relationship") if $self->{_logger}->is_debug;
    }




    #------------------------------------------------------------------------------------------------------------------
    # Store additional dbxref records
    #
    if (( exists $phash->{'BsmlCrossReference'}) && (defined($phash->{'BsmlCrossReference'})) && (scalar(@{$phash->{'BsmlCrossReference'}}) > 0 ) ) {

	foreach my $xref (@{$phash->{'BsmlCrossReference'}} ) {

	    #
	    # Attempt to store the BsmlCrossReference data in db and dbxref
	    #
	    my $dbxref_id = $self->store_bsml_cross_reference_component( xref => $xref );
	    
	    #
	    # check whether this record was already stored in feature_dbxref
	    #
	    my $is_current = 1;

	    my $feature_dbxref_id = $self->check_feature_dbxref_id_lookup( feature_id => $feature_id,
									   dbxref_id  => $dbxref_id,
									   is_current => $is_current,
									   status     => 'warn'
									   );

	    if (!defined($feature_dbxref_id)){
		#
		# Attempt to store record in feature_dbxref
		#
		$feature_dbxref_id = $self->{_backend}->do_store_new_feature_dbxref( feature_id => $feature_id,
										     dbxref_id  => $dbxref_id,
										     is_current => $is_current
										     );


		$self->{_logger}->logdie("feature_dbxref_id was not defined for feature_id '$feature_id' dbxref_id '$dbxref_id' is_current '$is_current'.") if (!defined($feature_dbxref_id));
	    }
	}
    }
}

##-----------------------------------------------------------------------------
## storeBsmlAnalysisLinkInChadoAnalysisfeature()
##
##-----------------------------------------------------------------------------
sub storeBsmlAnalysisLinkInChadoAnalysisfeature {

    my ($self, $bsmlAnalysisLinks, $feature_id, $uniquename, $featureprops) = @_;

    ## We will only attempt to insert records into analysisfeature if analyses array contains some data
    ## //Link/@role shall explicitly direct the assignment of the analysisfeature.type_id
    foreach my $bsmlAnalysisLink ( @{$bsmlAnalysisLinks} ){

	## Store one record in analysisfeature per each existing <Link> between a <Feature> and some <Analysis>
	my $analysis_id;
	my $role;

	if (( exists $bsmlAnalysisLink->{'id'} ) && (defined($bsmlAnalysisLink->{'id'}))){
	    $analysis_id = $bsmlAnalysisLink->{'id'};
	}
	else {
	    $self->{_logger}->logdie("The id attribute was not defined for the BSML <Link> belonging to the <Feature> with ".
				     "id '$uniquename' feature_id '$feature_id'");
	}
	
	if (( exists $bsmlAnalysisLink->{'role'} ) && (defined($bsmlAnalysisLink->{'role'}))){
	    $role = $bsmlAnalysisLink->{'role'};
	}
	else {
	    $self->{_logger}->logdie("The role attribute was not defined for the BSML <Link> with id attribute '$analysis_id' ".
				     "belonging to the <Feature> with id '$uniquename' feature_id '$feature_id'");
	}

	my $type_id = $self->check_cvterm_id_by_class_lookup( class => $role );

	if (!defined($type_id)){
	    
	    if ($role eq 'computed_by'){
		$type_id = $self->check_cvterm_id_by_name_lookup( name => 'computed_by');
	    }
	    elsif ($role eq 'input_of'){
		$type_id = $self->check_cvterm_id_by_name_lookup( name => 'input_of');
	    }
	    else{
		$self->{_logger}->logdie("Unexpected role '$role'");
	    }
	}
	
	my $analysisfeature_id = $self->check_analysisfeature_id_lookup(feature_id  => $feature_id, analysis_id => $analysis_id);
	if (!defined($analysisfeature_id)){
	
	    my $pidentity;
	    my $rawscore;
	    
	    if ($role eq 'computed_by'){
		## Some of the Feature's Attributes percent_identity and raw_score shall
		## be mapped into chado.analysisfeature.{pidentity and rawscore}.
		
		if ((exists $featureprops->{'percent_identity'}) && ( defined($featureprops->{'percent_identity'}) )){
		    $pidentity = $featureprops->{'percent_identity'}->[0];
		    
		    delete $featureprops->{'percent_identity'};
		}
		if  ((exists $featureprops->{'raw_score'}) && ( defined($featureprops->{'raw_score'}) ) ) {
		    $rawscore = $featureprops->{'raw_score'}->[0];
		    
		    delete $featureprops->{'raw_score'};
		} 
	    }
	    
	    ## Attempt to store a record in chado.analysisfeature
	    $analysisfeature_id = $self->{_backend}->do_store_new_analysisfeature(
										  feature_id  => $feature_id,
										  analysis_id => $analysis_id,
										  type_id     => $type_id,
										  rawscore    => $rawscore,
										  pidentity   => $pidentity
										  );
	
	    if (!defined($analysisfeature_id)){
		$self->{_logger}->logdie("Could not create an analysisfeature record when processing the BSML <Link> element with ".
					 "id '$analysis_id' role '$role' belonging to the <Feature> with id '$uniquename' feature_id ".
					 "'$feature_id'");
	    }
	}
    }
}

##-----------------------------------------------------------------------------
## storeBsmlCrossReferencesInDbxrefAndFeatureDbxref()
##
##-----------------------------------------------------------------------------
sub storeBsmlCrossReferencesInDbxrefAndFeatureDbxref {

    my ($self, $bsmlCrossReferences, $feature_id, $uniquename) = @_;

    foreach my $xref ( @{$bsmlCrossReferences} ) {
	
	my $dbxref_id = $self->store_bsml_cross_reference_component( xref => $xref );

	if (defined($dbxref_id)){
	    
	    my $feature_dbxref_id = $self->check_feature_dbxref_id_lookup(
									  feature_id => $feature_id,
									  dbxref_id  => $dbxref_id,
									  is_current => 1,
									  status     => 'warn'
									  );
	    if (!defined($feature_dbxref_id)){
		$feature_dbxref_id = $self->{_backend}->do_store_new_feature_dbxref(
										    feature_id => $feature_id,
										    dbxref_id  => $dbxref_id,
										    is_current => 1
										    );
		if (!defined($feature_dbxref_id)){
		    $self->{_logger}->logdie("Could not create a feature_dbxref record while processing one of the <Cross-reference> elements belonging ".
					     "to the <Feature> with id '$uniquename'. feature_id '$feature_id' dbxref_id '$dbxref_id' is_current '1'");
		}
	    }
	}
	else {
	    $self->{_logger}->logdie("dbxref_id was not defined while processing the BSML <Cross-reference> element ".
				     "belonging to the <Feature> with id '$uniquename' feature_id '$feature_id'");
	}
    }
}

##-----------------------------------------------------------------------------
## storeBsmlAttributesInChadoFeatureprop()
##
##-----------------------------------------------------------------------------
sub storeBsmlAttributesInChadoFeatureprop {

    my ($self, $bsmlAttributes, $feature_id, $feature_uniquename) = @_;

    foreach my $key (sort keys %{$bsmlAttributes} ){
	
	if (( exists $bsmlAttributes->{$key} ) &&
	    ( defined($bsmlAttributes->{$key} )) &&
	    ( scalar(@{$bsmlAttributes->{$key}}) > 0 )) {
	    
	    my $type_id = $self->check_property_types_lookup( name => $key );
	    
	    if (defined($type_id)){

		foreach my $value ( @{$bsmlAttributes->{$key}} ) {   
		    
		    $value =~ s/^\s+//; ## strip leading white spaces
		    $value =~ s/\s+$//; ## strip trailing white spaces
		    
		    if (!defined($value)){
			$self->{_logger}->warn("content was not defined for name '$key' while ".
					       "processing feature with feature_id '$feature_id' ".
					       "uniquename '$feature_uniquename'. Skipping this ".
					       "BSML <Attribute>");
			next;
		    }

		    if ( $value =~ /^\s*$/){
			$self->{_logger}->warn("content was blank for name '$key' while ".
					       "processing feature with feature_id '$feature_id' ".
					       "uniquename '$feature_uniquename'. Skipping this ".
					       "BSML <Attribute>");
			next;
		    }
		    
	
		    $self->prepareFeaturepropRecord($feature_id, $type_id, $value);
		}
	    }
	    else{		
		$self->{_logger}->error("The type_id was not defined for term '$key'.  The value stored in the content attribute of the ".
					"BSML <Attribute> with name=\"$key\" belonging to the <Feature> with id '$feature_uniquename' feature_id ".
					"'$feature_id'- will not be stored as a record in the featureprop table.");
	    }
	}
    }
}


##-----------------------------------------------------------------------------
## storeBsmlAttributeListsInChadoFeatureCvtermAndFeatureCvtermprop()
##
##-----------------------------------------------------------------------------
sub storeBsmlAttributeListsInChadoFeatureCvtermAndFeatureCvtermprop {

    my ($self, $bsmlAttributeLists, $feature_id, $feature_uniquename) = @_;
    
    #-------------------------------------------------------------------------------------------------------- 
    # insert records into chado.feature_cvterm related to the <Attribute> values nested 
    # under the BSML <Attribute-list> elements
    #
    #-------------------------------------------------------------------------------------------------------- 
    foreach my $list (@{$bsmlAttributeLists}){

	## To keep track of whether the first Attribute in the Attribute-list was processed.
	my $firstAttributeProcessed=0;

	## The first Attribute element's content will determine the record that will be loaded into feature_cvterm.
	## We will keep track of that feature_cvterm record's feature_cvterm_id so that the subsequent
	## Attribute element's contents in the same Attribute-list can be linked to the first Attribute element's content.
	my $feature_cvterm_id;

	foreach my $hash ( @{$list}){
	    
	    ## //Feature/Attribute-list/Attribute/@name
	    my $name;
	    
	    if (exists $hash->{'name'}){
		$name = $hash->{'name'};
	    }
	    else {
		$self->{_logger}->logdie("name does not exist for Attribute while processing Feature with uniquename '$feature_uniquename'");
	    }

	    ## /Feature/Attribute-list/Attribute/@content
	    my $content;
	    
	    if (exists $hash->{'content'}){
		$content = $hash->{'content'};
	    }
	    else {
		$self->{_logger}->logdie("content does not exist for Attribute while processing Feature with uniquename '$feature_uniquename'");
	    }

	    if ($firstAttributeProcessed == 0){
		
		## We're processing the first Attribute in this Attribute-list, so set the flag accordingly.
		$firstAttributeProcessed=1;
		#
		# Operating on the first <Attribute> in the <Attribute-list>
		#
		my $cv_id = $self->check_cv_id_lookup( name => $name );

		$self->{_logger}->logdie("cv.cv_id was not defined for cv.name '$name'") if (!defined($cv_id));
		
		my $cvterm_id;

		if ($name eq 'GO'){
		    $cvterm_id = $self->retrieveCvtermIdForGOID($content);
		    if (!defined($cvterm_id)){
			$self->{_logger}->warn("Could not find cvterm_id for GO ID '$content'.  Will skip this ".
					       "entire Attribute-list section.");
			goto next_attribute_list;
		    }
		    if ($self->{_logger}->is_debug()){
			$self->{_logger}->debug("Retrieved cvterm_id '$cvterm_id' for GO ID '$content'");
		    }
		}
		elsif ($content =~ /:/){

		    #
		    # Dealing with term accession e.g. GO:0004222
		    #
		    $cvterm_id = $self->check_cvterm_id_by_dbxref_accession_lookup(
										   cv_id     => $cv_id,
										   accession => $content
										   );

		    if (!defined($cvterm_id)){

			## Each alt_id is now available via dbxref and cvterm_dbxref

			$cvterm_id = $self->check_cvterm_id_by_alt_id_lookup(  cv_id     => $cv_id,
									       accession => $content );

			
			
			if (!defined($cvterm_id)){
			    $self->{_logger}->warn("Could not retrieve cvterm_id for cvterm.cv_id '$cv_id' dbxref.accession '$content' while processing feature '$feature_uniquename'");
			    goto next_attribute_list;
			}
		    }

		}
		elsif (($name eq 'TIGR_role') || ($name eq 'EC')){
		    # 
		    # Dealing with TIGR_role code. In legacy database a valid code may be: 138.  Meanwhile in the TIGR_roles.obo file:
		    # Also may be dealing with EC.  Processed in similar fashion.
		    # 
		    # [Term]
		    # id: TR:0000138
		    # name: Degradation of polypeptides, peptides, and glycopeptides
		    # is_a: TR:0000804
		    # xref_analog: TIGR_role:138
		    # xref_analog: TIGR_roles_order:21540
		    #
		    # Since:    TIGR_role:138 , we know that:  db.name = 'TIGR_role' AND dbxref.name = '138
		    #
		    # SELECT d.*, c.* 
		    # FROM cv, dbxref d, cvterm c, cvterm_dbxref cd, db
		    # WHERE db.name = 'TIGR_role'
		    # AND db.db_id = d.db_id
		    # AND d.accession = '138' 
		    # AND d.dbxref_id = cd.dbxref_id
		    # AND cd.cvterm_id = c.cvterm_id
		    # AND cv.name = 'TIGR_role'
		    # AND cv.cv_id = c.cv_id
		    #
		    # 
		    # dbxref_id:           8141
		    # db_id:               10
		    # accession:           138
		    # version:              
		    # description:         NULL
		    # cvterm_id:           4053
		    # cv_id:               8
		    # name:                Degradation of polypeptides, peptides, and glycopeptides
		    # definition:          NULL
		    # dbxref_id:           8140
		    # is_obsolete:         0
		    # is_relationshiptype: 0
		    #
		    # (1 row affected)


		    #
		    # OR where dealing with EC:
		    #
		    # SELECT d.*, c.* 
		    # FROM cv, dbxref d, cvterm c, cvterm_dbxref cd, db
		    # WHERE db.name = 'EC'
		    # AND db.db_id = d.db_id
		    # AND d.accession = '4.2.1.70' 
		    # AND d.dbxref_id = cd.dbxref_id
		    # AND cd.cvterm_id = c.cvterm_id
		    # AND cv.name = 'EC'
		    # AND cv.cv_id = c.cv_id
		    #
		    # dbxref_id:           4981
		    # db_id:               3
		    # accession:           4.2.1.70
		    # version:
		    # description:         NULL
		    # cvterm_id:           2488
		    # cv_id:               2
		    # name:                LYASE||CARBON-OXYGEN LYASE, OTHER||HYDRO-LYASE||Pseudouridylate synthase
		    # definition:          NULL
		    # dbxref_id:           4980
		    # is_obsolete:         0
		    # is_relationshiptype: 0

		    $cvterm_id = $self->check_cvterm_id_by_accession_lookup(
									    name      => $name,
									    accession => $content
									    );
		    if (!defined($cvterm_id)){
			#
			# Changed the logdie to a fatal for testing purposes.
			# Please review tigrrole.txt for discussion.
			#
			$self->{_logger}->fatal("cvterm_id was not defined for cv.name '$name' dbxref.accession '$content' ".
						"while processing the first Attribute in some Attribute-list for the feature ".
						"with uniquename '$feature_uniquename'.  The entire Attribute-list will be skipped.");
			goto next_attribute_list;
		    }
		    
		}


		if (!defined($cvterm_id)){

		    #
		    # Dealing with term name
		    #
		    $cvterm_id = $self->lookup_cvterm_id( $cv_id, $content );

		    if (!defined($cvterm_id)){
			$self->{_logger}->logdie("cvterm_id was not defined for cvterm.cv_id '$cv_id' cvterm.name '$content' ".
						 "while processing the first Attribute in some Attribute-list for the feature ".
						 "with uniquename '$feature_uniquename'");
		    }
		}
		

		#
		# Verify whether this feature_cvterm_id has been stored in the database during a previous session
		#
		$feature_cvterm_id = $self->createAndAddFeatureCvterm($feature_id, $cvterm_id);		    
		if (!defined($feature_cvterm_id)){
		    $self->{_logger}->fatal("feature_cvterm_id was not defined. Could not insert record into chado.feature_cvterm for ".
					    "feature_id 'feature_id' cvterm_id '$cvterm_id' pub_id '1' for the feature with ".
					    "uniquename '$feature_uniquename'.  Since this is the first Attribute in the Attribute-list, ".
					    "the entire Attribute-list group will be skipped.");
		    goto next_attribute_list;		    
		}
	    }
	    else{

		#
		# Operating on subsequent <Attribute> elements in the <Attribute-list>
		#
		my $cvterm_id;

		if ($self->{_logger}->is_debug()){
		    $self->{_logger}->debug("Processing subsequent Attribute element with name '$name' content '$content' in ".
					    "some Attribute-list for the feature ".
					    "with uniquename '$feature_uniquename' feature_cvterm '$feature_cvterm_id'");
		}

		my $evidence_code = $self->check_evidence_codes_lookup( name => $name );

		if (defined($evidence_code)) {

		    #
		    # Dealing with piece of Evidence code
		    #
		    my $cv_id = $self->check_cv_id_lookup( name => 'evidence_code' );
		    
		    if (!defined($cv_id)){
			$self->{_logger}->logdie("cv.cv_id was not defined for cv.name 'evidence_code' while processing ".
						 "Attribute with name '$name' content '$content' for the feature with ".
						 "uniquename '$feature_uniquename'");
		    }


		    $cvterm_id = $self->lookup_cvterm_id( $cv_id,$name );
		    
		    if (!defined($cvterm_id)){
			$self->{_logger}->logdie("cvterm.cvterm_id was not defined for cvterm.cv_id '$cv_id' cvterm.name '$name' ".
						 "while processing Attribute with name '$name' content '$content' for the feature ".
						 "with uniquename '$feature_uniquename'");
		    }
		    
		    if ($self->{_logger}->is_debug()){
			$self->{_logger}->debug("Non-primary Attribute in some Attribute-list for the feature with uniquename ".
						"'$feature_uniquename' contains an evidence code for which cvterm_id '$cvterm_id' ".
						"cv_id '$cv_id' name '$name'");
		    }
		    
		} 
		else{
		    #
		    # Should this be by cv_id and name?
		    #
		    $cvterm_id = $self->check_cvterm_id_by_name_lookup( name => $name);
		    
		    if (!defined($cvterm_id)){
			
			## The new evidence_code.obo deprecated my evidence_codes.obo which means that "ISS" is replaced by "inferred from
			## sequence similarity" as an entry in the cvterm table.  According to the new evidence code ontology file "ISS"
			## is an "exact_synonym" of "inferred from sequence similarity".  Therefore, when cvterm lookups fail to yield
			## any result when attempting to construct a feature_cvtermprop record, need to check the new 
			## cvtermsynonym_synonym_lookup.
			$cvterm_id = $self->check_cvtermsynonym_synonym_lookup( synonym => $name );
			
			if (!defined($cvterm_id)){
			    $self->{_logger}->warn("cvterm_id was not defined while processing a non-primary Attribute with name '$name' ".
						     "content '$content' in some Attribute-list for the feature with uniquename ".
						     "'$feature_uniquename'.  The term '$name' could not be retrieved from cvterm nor cvtermsynonym.");
			    last;
			}
		    }
		    
		    if ($self->{_logger}->is_debug()){
			$self->{_logger}->debug("Non-primary Attribute in some Attribute-list for the feature with uniquename ".
						"'$feature_uniquename' does not contain an evidence code for which cvterm_id '$cvterm_id' ".
						"name '$name'");
		    }


		}

		my $rank = 0;
		my $feature_cvtermprop_id;
		
		do {
		    $feature_cvtermprop_id = $self->check_feature_cvtermprop_id_lookup(  feature_cvterm_id => $feature_cvterm_id,
											 type_id           => $cvterm_id,
											 value             => $content,
											 rank              => $rank,
											 status            => 'warn' );
		} while ((defined($feature_cvtermprop_id)) && (++$rank));
		
		#
		# Insert this type_id/value pair into chado.featureprop
		#
		$feature_cvtermprop_id = $self->{_backend}->do_store_new_feature_cvtermprop( feature_cvterm_id => $feature_cvterm_id,
											     type_id           => $cvterm_id,
											     value             => $content,
											     rank              => $rank  );
		
		if (!defined($feature_cvtermprop_id)){
		    $self->{_logger}->logdie("feature_cvtermprop_id was not defined. Could not insert record into chado.feature_cvtermprop ".
					     "for feature_cvterm_id '$feature_cvterm_id' type_id '$cvterm_id' value '$content' rank '$rank' ".
					     "for feature with uniquename '$feature_uniquename'");
		}
	    }
	}
      next_attribute_list:
    }
}
    
##-----------------------------------------------------------------------------
## storeBsmlIntervalLocInChadoFeatureloc()
##
##-----------------------------------------------------------------------------
sub storeBsmlIntervalLocInChadoFeatureloc {

    my ($self, $bsmlIntervalLocs, $feature_id, $feature_uniquename, $sequence_feature_id, $feature_class, $exonCoordinatesLookup) = @_;

    foreach my $location (@{$bsmlIntervalLocs}){

	if (defined($location)){
	    
	    my ($fmin, $fmax, $complement, $strand, $locgroup, $rank) = undef;
	    
	    if ((exists $location->{'endpos'}) and (defined($location->{'endpos'}))){
		$fmax = $location->{'endpos'};
	    }
	    if ((exists $location->{'startpos'}) and (defined($location->{'startpos'}))){
		$fmin = $location->{'startpos'};
	    }   
	    if ((exists $location->{'complement'}) and (defined($location->{'complement'}))){
		$complement = $location->{'complement'};
	    } 
	    if ((exists $location->{'locgroup'}) and (defined($location->{'locgroup'}))){
		$locgroup = $location->{'locgroup'};
	    } 
	    if ((exists $location->{'rank'}) and (defined($location->{'rank'}))){
		$rank = $location->{'rank'};
	    } 
	    
	    if (defined($complement)){
		if ($complement == 0){
		    $strand = 1;
		}
		elsif ($complement == 1){
		    $strand = -1;
		}
		else {
		    $self->{_logger}->logdie("Encountered an unexpected value for the complement attribute in the <BsmlInterval-loc> ".
					     "belonging to the <Feature> with id '$feature_uniquename' feature_id '$feature_id'");
		}
	    }
	    else {
		$self->{_logger}->logdie("The complement attribute was not defined for the <BsmlInterval-loc> ".
					 "belonging to the <Feature> with id '$feature_uniquename' feature_id '$feature_id'");
	    }
	    
	    if ($fmin > $fmax){
		$self->{_logger}->logdie("Encountered a <BsmlInterval-loc> with startpos '$fmin' > endpos '$fmax' (complement ".
					 "'$complement') for <Feature> with id '$feature_uniquename' feature_id '$feature_id'");
	    }
	    
	    if ($feature_class eq 'exon'){
		## Need to store the exon features' fmin and complement in order to later
		## correctly set feature_relationship.rank values.
		$exonCoordinatesLookup->{$feature_uniquename} = { fmin => $fmin, complement => $complement };
	    }

	    $rank = 0     if (!defined($rank));
	    $locgroup = 0 if (!defined($locgroup));

	    my $is_fmin_partial=0;
	    my $is_fmax_partial=0;

	    if ((exists $location->{'startopen'}) and (defined($location->{'startopen'}))){
		$is_fmin_partial = $location->{'startopen'};
	    } 
	    if ((exists $location->{'endopen'}) and (defined($location->{'endopen'}))){
		$is_fmax_partial = $location->{'endopen'};
	    } 
	    
	    $self->prepareFeaturelocRecordN(feature_id => $feature_id, 
					    srcfeature_id => $sequence_feature_id, 
					    locgroup=> 0, 
					    rank => 0,
					    fmin => $fmin,
					    fmax => $fmax,
					    strand => $strand,
					    is_fmin_partial => $is_fmin_partial,
					    is_fmax_partial => $is_fmax_partial);
	}
    }
}

##-----------------------------------------------------------------------------
## storeBsmlSiteLocInChadoFeatureloc()
##
##-----------------------------------------------------------------------------
sub storeBsmlSiteLocInChadoFeatureloc {

    my ($self, $bsmlSiteLocs, $feature_id, $feature_uniquename, $sequence_feature_id) = @_;

    foreach my $siteloc (@{$bsmlSiteLocs}){

	if (defined($siteloc)){
	    
	    my ($fmin, $fmax, $strand);
	    
	    if ((exists $siteloc->{'sitepos'}) and (defined($siteloc->{'sitepos'}))){
		$fmax = $siteloc->{'sitepos'};
		$fmin = $fmax;
	    }
	    else {
		$self->{_logger}->logdie("The sitepos attribute was not defined for the <BsmlSite-loc> for ".
					 "the <Feature> with id '$feature_uniquename' feature_id '$feature_id'");
	    }
	    
	    if ((exists $siteloc->{'complement'}) and (defined($siteloc->{'complement'}))){
		if ( $siteloc->{'complement'} == 0 ) {
		    $strand = 1;
		}
		if ( $siteloc->{'complement'} == 1 ) {
		    $strand = -1;
		}		
	    }   
	    else {
		$self->{_logger}->logdie("The complement attribute was not defined for the <BsmlSite-loc> with ".
					 "sitepos '$siteloc->{'sitepos'}' for the <Feature> with id ".
					 "'$feature_uniquename' feature_id '$feature_id'");
	    }
	    
	    $self->prepareFeaturelocRecord($feature_id, $sequence_feature_id, 0, 0, $fmin, $fmax, $strand);
	}
    }
}

#-----------------------------------------------------------------------------
# update_feature_record()
#
#-----------------------------------------------------------------------------
sub update_feature_record {
    
    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_logger}->fatal("Not fully tested. Returning.");
    return;
    return $self->{_backend}->do_update_feature_record(@_);


}


#----------------------------------------------------------------
# truncated_features
#
#----------------------------------------------------------------
sub truncated_features {

    my ($self, $type_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("type_id was not defined") if (!defined($type_id));

    $self->{_backend}->do_set_textsize(TEXTSIZE);

    #
    # SELECT f.feature_id, f.uniquename, f.residues, db.name 
    # FROM feature f, dbxref d, db
    # WHERE f.dbxref_id = d.dbxref_id
    # AND d.db_id = db.db_id
    # AND f.type_id = $type_id
    #
    my @ret = $self->{_backend}->get_truncated_features($type_id);

    my $len = scalar(@ret);

    my (%s, $i, $j);

    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = scalar(@ret);
    my $counter = int(.01 * $total_rows);
 
    $counter = 1 if ( $counter == 0 );
    print "\n";
    
    for ($i=0; $i < scalar(@ret); $i++){


	$j = $i + 1;

	$self->show_progress("Building lookup for type_id '$type_id' feature types $j/$total_rows",$counter,$j,$bars,$total_rows);       

	$s{$i}->{'feature_id'} = $ret[$i][0];  # feature.feature_id
	$s{$i}->{'uniquename'} = $ret[$i][1];  # feature.uniquename
	$s{$i}->{'residues'}   = $ret[$i][2];  # feature.residues
	$s{$i}->{'dbname'}     = $ret[$i][3];  # db.name
	    
    }

    $s{'count'} = $i;

    return (\%s);
}


#----------------------------------------------------------------
# sequence_info()
#
#----------------------------------------------------------------
sub sequence_info {

    my ($self, $asmbl_id, $orgtype) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_backend}->do_set_textsize(TEXTSIZE);

    my (@ret);


    if (($orgtype eq 'prok') or ($orgtype eq 'ntprok')){
	
	# sub get_prok_sequence_info() executes the following query:
	# SELECT a.sequence
	# FROM assembly a, stan s 
	# WHERE a.asmbl_id = s.asmbl_id 
	# AND s.iscurrent = 1

	@ret = $self->{_backend}->get_prok_sequence_info($asmbl_id);

    }
    elsif ($orgtype eq 'euk'){

	# get_euk_sequence_info() executes the following query:
	# SELECT a.sequence
	# FROM assembly a, clone_info c
	# WHERE a.asmbl_id = c.asmbl_id


	@ret = $self->{_backend}->get_euk_sequence_info($asmbl_id);
    }
    else{
	$self->{_logger}->logdie("orgtype '$orgtype' not recognized");
    }
    

    return $ret[0][0];
}

#----------------------------------------------------------------
# subfeature_sequence_info()
#
#----------------------------------------------------------------
sub subfeature_sequence_info {

    my ($self, $asmbl_id, $orgtype, $type_id, $textsize, $feat_name) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($textsize)){
	$textsize = TEXTSIZE;
    }

    $self->{_backend}->do_set_textsize($textsize);

    my (@ret);


    if (($orgtype eq 'prok') or ($orgtype eq 'ntprok')){
	
	#
	# Same query for retrieve prok/ntprok assemblies
	# since the ORFs are stored as transcript/gene and CDS
	#
	# sub get_prok_sequence_info() executes the following query:
	# SELECT a.sequence
	# FROM assembly a, stan s 
	# WHERE a.asmbl_id = s.asmbl_id 
	# AND s.iscurrent = 1

	@ret = $self->{_backend}->get_prok_sequence_info($asmbl_id);

    }
    elsif ($orgtype eq 'euk'){

	if (($type_id == 54) or ($type_id == 56)){
	    
	    @ret = $self->{_backend}->get_tu_sequence_info($asmbl_id, $feat_name);
	}
	elsif ($type_id == 55){

	    @ret = $self->{_backend}->get_coding_region_sequence_info($asmbl_id, $feat_name);
	}
	else {
	    $self->{_logger}->logdie("type_id '$type_id' not acceptable");
	}
    }
    else{
	$self->{_logger}->logdie("orgtype '$orgtype' not recognized");
    }
    

    return ($ret[0][0], $textsize);
}


#-------------------------------------------------------------------------
# update_feature()
#
#-------------------------------------------------------------------------
sub update_feature {

    my ($self) = shift;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;


    $self->{_logger}->fatal("Not fully tested. Returning.");
    return;

    $self->{_backend}->do_update_feature(@_);

}

#----------------------------------------------------------------
# subfeature_sequence_hash()
#
#----------------------------------------------------------------
sub subfeature_sequence_hash {

    my ($self, $feat_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
	
    my $textsize = TEXTSIZE;
    
    $self->{_backend}->do_set_textsize($textsize);

    my (@ret);

    if ($feat_type eq 'TU'){
	
	@ret = $self->{_backend}->get_tu_sequence_info();
    }
    elsif ($feat_type eq 'model'){
	
	@ret = $self->{_backend}->get_coding_region_sequence_info();
    }
    else {
	$self->{_logger}->logdie("feat_type '$feat_type' not acceptable");
    }

    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = scalar(@ret);
    my $counter = int(.01 * $total_rows);
    $counter = 1 if ( $counter == 0 );
    print "\n";
    
    my ($hash, $i, $j);

    for ($i=0; $i < scalar(@ret); $i++){

	$j=$i+1;

	$self->show_progress("Building $feat_type lookup $j/$total_rows",$counter,$j,$bars,$total_rows);

	$hash->{$ret[$i][0]} = $ret[$i][1];
    }

    $hash->{'count'} = $i;

    return ($hash);
}


#----------------------------------------------------------------
# pub_locus_hash()
#
#----------------------------------------------------------------
sub pub_locus_hash {

    my ($self, $asmbl_id_list_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($s, $i);


    foreach my $asmbl_id ( @{$asmbl_id_list_ref} ){

	$self->{_logger}->debug("Retrieving all pub_locus for asmbl_id '$asmbl_id'") if $self->{_logger}->is_debug;

	#
	# select i.feat_name, i.pub_locus
	# from asm_feature f, clone_info c, ident i
	# where f.asmbl_id = c.asmbl_id
	# and f.feat_name = i.feat_name
	# and f.asmbl_id = ?
	#

	my @ret = $self->{_backend}->get_pub_locus_hash($asmbl_id);
 

	foreach (my $i=0 ; $i < scalar(@ret) ; $i++){


	    my ($asm, $feat_name) = split(/\./, $ret[$i][0]);

	    $self->{_logger}->logdie("asm was not defined for '$ret[$i][0]'") if (!defined($asm));
	    $self->{_logger}->logdie("feat_name was not defined for '$ret[$i][0]'") if (!defined($feat_name));

	    $self->{_logger}->logdie("asm '$asm' != asmbl_id '$asmbl_id'") if ($asm ne $asmbl_id);

	    #
	    # Build hashref: asmbl_id -> feat_name to pub_locus
	    #  
	    $s->{$asmbl_id}->{$feat_name} = $ret[$i][1];

	}
    }

    return $s;
}

#----------------------------------------------------------------
# asmbl_id_feat_name()
#
# returns a hashref: asmbl_id -> feat_name = feature_id
# and listref of unique assembly identifiers
#
#----------------------------------------------------------------
sub asmbl_id_feat_name {

    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    #
    # select f.feature_id, f.name, db.db_id, d.dbxref_id
    # from feature f, cvterm c, dbxref d, db
    # where f.type_id = c.cvterm_id
    # and c.name = 'transcript'
    # and f.dbxref_id = d.dbxref_id
    # and d.db_id = db.db_id
    # and f.uniquename like '$db%'
    #
    my @ret = $self->{_backend}->get_asmbl_id_feat_name($db);

    my $hash = {};
    my $asmblhash = {};

    foreach (my $i=0; $i < scalar(@ret) ; $i++){


	my ($asmbl_id, $feat_name) = split(/\./, $ret[$i][1]);

	$self->{_logger}->logdie("feat_name was not defined for feature.name '$ret[$i][1]'") if (!defined($feat_name));
	$self->{_logger}->logdie("asmbl_id was not defined for feature.name '$ret[$i][1]'") if (!defined($asmbl_id));

	$hash->{$asmbl_id}->{$feat_name}->{'feature_id'}  = $ret[$i][0];
	$hash->{$asmbl_id}->{$feat_name}->{'db_id'}       = $ret[$i][2];
	$asmblhash->{$asmbl_id} = $asmbl_id;

    }


    my @asmblarray = (sort keys %{$asmblhash});

    return ($hash, \@asmblarray);
}


#----------------------------------------------------------------
# store_pub_locus()
#
# inserts records into Chado tables:
# 1) dbxref
# 2) feature_dbxref
#
#----------------------------------------------------------------
sub store_pub_locus {

    my ($self, $asmblfeathash, $plocushash) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;


    foreach my $asmbl_id (sort keys %{$asmblfeathash}){

	foreach my $feat_name (sort keys %{$asmblfeathash->{$asmbl_id}}){

	    my $feature_id = $asmblfeathash->{$asmbl_id}->{$feat_name}->{'feature_id'};
	    my $db_id      = $asmblfeathash->{$asmbl_id}->{$feat_name}->{'db_id'};
	
	    
	    my $publocus   = $plocushash->{$asmbl_id}->{$feat_name};


	    if (defined($publocus)){
		my $dbxref_id = $self->{_backend}->do_store_new_dbxref(
								       db_id       => $db_id,
								       accession   => $publocus,
								       version     => 'pub_locus',
								       description => 'migrated via pubLocus2Chado.pl'
								       );
		if (!defined($dbxref_id)){
		    $self->{_logger}->logdie("dbxref_id was not defined for db_id '$db_id' accession '$publocus' asmbl_id '$asmbl_id' feat_name '$feat_name'");
		}
		else{
		    my $feature_dbxref_id = $self->{_backend}->do_store_new_feature_dbxref(
											   feature_id => $feature_id,
											   dbxref_id  => $dbxref_id,
											   is_current => 'true'
										       );
		    if (!defined($feature_dbxref_id)){
			$self->{_logger}->logdie("feature_dbxref_id was not defined for feature_id '$feature_id' dbxref_id '$dbxref_id' asmbl_id '$asmbl_id' feat_name '$feat_name'");
		    }
		}
	    }
	    else{
		$self->{_logger}->warn("pub_locus was not defined for asmbl_id '$asmbl_id' feat_name '$feat_name' feature_id '$feature_id'");
	    }
	}
    }
}


#----------------------------------------------------------------
# asmbl_id_feat_name_for_update()
#
# returns a hashref: asmbl_id -> feat_name = feature_id
# and listref of unique assembly identifiers
#
#----------------------------------------------------------------
sub asmbl_id_feat_name_for_update {

    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    #
    # select f.feature_id, f.name, db.db_id, d2.dbxref_id
    # from feature f, cvterm c, dbxref d, db, dbxref d2, feature_dbxref fd
    # where f.type_id = c.cvterm_id
    # and c.name = 'transcript'
    # and f.dbxref_id = d.dbxref_id
    # and d.db_id = db.db_id
    # and f.uniquename like '$db%'
    # and fd.feature_id = f.feature_id
    # and fd.dbxref_id = d2.dbxref_id
    #
    my @ret = $self->{_backend}->get_asmbl_id_feat_name_for_update($db);

    my $hash = {};
    my $asmblhash = {};

    foreach (my $i=0; $i < scalar(@ret) ; $i++){

	my ($asmbl_id, $feat_name) = split(/\./, $ret[$i][1]);


	
	$self->{_logger}->logdie("feat_name was not defined for feature.name '$ret[$i][1]'") if (!defined($feat_name));
	$self->{_logger}->logdie("asmbl_id was not defined for feature.name '$ret[$i][1]'") if (!defined($asmbl_id));

	$hash->{$asmbl_id}->{$feat_name}->{'feature_id'}  = $ret[$i][0];
	$hash->{$asmbl_id}->{$feat_name}->{'db_id'}       = $ret[$i][2];
	$hash->{$asmbl_id}->{$feat_name}->{'dbxref_id'}   = $ret[$i][3];
	$asmblhash->{$asmbl_id} = $asmbl_id;

    }


    my @asmblarray = (sort keys %{$asmblhash});

    return ($hash, \@asmblarray);
}




#----------------------------------------------------------------
# update_pub_locus()
#
# updates dbxref records
#
#----------------------------------------------------------------
sub update_pub_locus {

    my ($self, $asmblfeathash, $plocushash) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;


    foreach my $asmbl_id (sort keys %{$asmblfeathash}){

	foreach my $feat_name (sort keys %{$asmblfeathash->{$asmbl_id}}){


	    
	    $self->{_logger}->warn("Updating asmbl_id '$asmbl_id' feat_name '$feat_name'");



	    my $feature_id = $asmblfeathash->{$asmbl_id}->{$feat_name}->{'feature_id'};
	    my $db_id      = $asmblfeathash->{$asmbl_id}->{$feat_name}->{'db_id'};
	    my $dbxref_id  = $asmblfeathash->{$asmbl_id}->{$feat_name}->{'dbxref_id'};
	    
	    my $publocus   = $plocushash->{$asmbl_id}->{$feat_name};


	    if (defined($publocus)){
		$self->{_backend}->do_update_dbxref_record(
							   dbxref_id   => $dbxref_id,
							   db_id       => $db_id,
							   accession   => $publocus,
							   version     => 'pub_locus',
							   description => 'migrated via pubLocus2Chado.pl'
							   );
	    }
	    else{
		$self->{_logger}->warn("pub_locus was not defined for asmbl_id '$asmbl_id' feat_name '$feat_name' feature_id '$feature_id'");
	    }
	}
    }
}


#---------------------------------------------------------
# qualified_ontologies()
#
#---------------------------------------------------------
sub qualified_ontologies {

    my ($self, $onts) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->logdie("onts was not defined") if (!defined($onts));


    $self->{_logger}->debug(Dumper $onts) if $self->{_logger}->is_debug;

    my $hash = {};

    foreach my $name (sort @{$onts}){


	my $cv_id = $self->{_backend}->get_cv_id_from_cv(
							 name       => $name,
							 definition => undef
							 );
	if (!defined($cv_id)){
	    $self->{_logger}->warn("cv_id was not defined for name '$name'");
	}
	else{
	    $hash->{$cv_id} = $name;
	}

    }

    return $hash;
}



#---------------------------------------------------------
# cvterm_relationship_for_closure()
#
#---------------------------------------------------------
sub cvterm_relationship_for_closure {


    my ($self, $cv_id, $ontology) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_logger}->info("cv_id was '$cv_id'") if (defined($cv_id));

    my @ret = $self->{_backend}->get_cvterm_relationship_for_closure($cv_id, $ontology);



    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = scalar(@ret);
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);



    my $hash = {};

    for (my $i=0; $i < $total_rows ; $i++){


	$row_count++;
	$self->show_progress("Building cvterm_relationship hashref $row_count/$total_rows",$counter,$row_count,$bars,$total_rows);


	my $subject = $ret[$i][0];
	my $object  = $ret[$i][1];
	my $type_id = $ret[$i][2];

	if (!defined($subject)){
	    $self->{_logger}->fatal("subject was not defined");
	    next;
	}
	if (!defined($object)){
	    $self->{_logger}->fatal("object was not defined");
	    next;
	}
	if (!defined($type_id)){
	    $self->{_logger}->fatal("type_id was not defined");
	    next;
	}


	if ((exists $hash->{$subject}) and (defined($hash->{$subject}))){
	    $self->{_logger}->fatal("Need to facilitate multiple inheritance");
	    next;
	}
	else{
	    $hash->{$subject}->{'object'}  = $object;
	    $hash->{$subject}->{'type_id'} = $type_id;
	}
    }

    return $hash;



}

#---------------------------------------------------------
# calculate_cvtermpath_closure()
#
#---------------------------------------------------------
sub calculate_cvtermpath_closure {


    my ($self, $hash, $cv_id) = @_;


    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;


    if (!defined($cv_id)){
	$self->{_logger}->logdie("cv_id was not defined");
    }
    if (!defined($hash)){
	$self->{_logger}->logdie("hash was not defined");
    }

    my @counter = keys %{$hash};
    
    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = scalar(@counter);
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);
    print "\n";

    foreach my $subject (sort keys %{$hash}){

	$row_count++;
	$self->show_progress("Storing closure for subject_id '$subject' $row_count/$total_rows",$counter,$row_count,$bars,$total_rows);
	

	my $vip = $subject;

	my $distance = 0;


	while ((exists $hash->{$subject}->{'object'}) and (defined($hash->{$subject}->{'object'}))){


	    $distance++;

	    my $object  = $hash->{$subject}->{'object'};
	    my $type_id = $hash->{$subject}->{'type_id'};
	    

	    my $cvtermpath_id = $self->{_backend}->do_store_new_cvtermpath(
									   type_id      => $type_id,
									   subject_id   => $vip,
									   object_id    => $object,
									   cv_id        => $cv_id,
									   pathdistance => $distance
									   );

	    if (!defined($cvtermpath_id)){
		$self->{_logger}->logdie("cvtermpath_id was not defined for type_id '$type_id' subject_id '$vip' object_id '$object' cv_id '$cv_id' pathdistance '$distance'");
	    }
	    else{
		$subject = $object;
	    }
	}
	
    }
}

#----------------------------------------------------------------
# store_bsml_feature_groups()
#
#----------------------------------------------------------------
sub store_bsml_feature_groups  {

    my($self, %param) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $phash = \%param;

    my $feature_groups       = $phash->{'feature_groups'}       if ((exists $phash->{'feature_groups'})       and (defined($phash->{'feature_groups'})));
    my $feature_id_lookup    = $phash->{'feature_id_lookup'}    if ((exists $phash->{'feature_id_lookup'})    and (defined($phash->{'feature_id_lookup'})));
    my $feature_id_lookup_d  = $phash->{'feature_id_lookup_d'}  if ((exists $phash->{'feature_id_lookup_d'})  and (defined($phash->{'feature_id_lookup_d'})));
    my $exon_coordinates     = $phash->{'exon_coordinates'}     if ((exists $phash->{'exon_coordinates'})     and (defined($phash->{'exon_coordinates'})));
    
    foreach my $feature_group ( @{$feature_groups} ) {   

	my $exon_transcript_flag=0;
	
	my $exons_2_transcript = {};
	
	for (my $i=0; $i < scalar(@{$feature_group->{'BsmlFeatureGroupMembers'}}); $i++ ){
		    
	    for (my $j = $i + 1; $j < scalar(@{$feature_group->{'BsmlFeatureGroupMembers'}}); $j++){

		my $name1 = $feature_group->{'BsmlFeatureGroupMembers'}->[$i]->{'feature-type'};
		my $name2 = $feature_group->{'BsmlFeatureGroupMembers'}->[$j]->{'feature-type'};

		## TermUsage may have reclassified these feature types
		my $tmp;
		($name1, $tmp) = $self->map_class($name1);
		($name2, $tmp) = $self->map_class($name2);

		my $uniquename1 = $feature_group->{'BsmlFeatureGroupMembers'}->[$i]->{'feature'};
		my $uniquename2 = $feature_group->{'BsmlFeatureGroupMembers'}->[$j]->{'feature'};

		my $cvterm_id_1 = $self->check_cvterm_id_by_class_lookup( class => $name1);

		$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = '$name1'") if (!defined($cvterm_id_1));

		my $cvterm_id_2 = $self->check_cvterm_id_by_class_lookup( class => $name2 );

		$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = '$name2'") if (!defined($cvterm_id_2));

		#
		# Check whether feature-grouping rules exist in the chado.cvterm_relationship table
		#
		my $type_id = $self->check_cvterm_relationship_type_id_lookup(
									      subject_id => $cvterm_id_1,
									      object_id  => $cvterm_id_2
									      );

		my $cptype_id = $self->check_cvtermpath_type_id_lookup( $cvterm_id_1, $cvterm_id_2 );
		if (defined($cptype_id)){
		    if ($type_id != $cptype_id){
			$self->{_logger}->warn("term '$name1' cvterm_id '$cvterm_id_1' has cvterm_relationship type ".
					       "'$type_id' and cvtermpath type '$cptype_id' with term '$name2' ".
					       "cvterm_id '$cvterm_id_2'");
		    }
		    ## we'll apply the cvtermpath type_id value instead of the cvterm_relationship one.
		    $type_id = $cptype_id;
		}

		if (defined($type_id)){
		    #
		    # cvterm_id_2 is the object_id
		    #
		    $exon_transcript_flag = $self->relate_feature_members($uniquename2,
									  $uniquename1,
									  $type_id,
									  $feature_id_lookup,
									  $feature_id_lookup_d,
									  $name2,
									  $name1,
									  $exon_transcript_flag,
									  $exon_coordinates,
									  $exons_2_transcript);
		}
		else {
		    $type_id = $self->check_cvterm_relationship_type_id_lookup(
									       subject_id => $cvterm_id_2,
									       object_id  => $cvterm_id_1
									       );
		    my $cptype_id = $self->check_cvtermpath_type_id_lookup( $cvterm_id_2, $cvterm_id_1 );
		    if (defined($cptype_id)){
			if ($type_id != $cptype_id){
			    $self->{_logger}->warn("term '$name2' cvterm_id '$cvterm_id_2' has cvterm_relationship type ".
						   "'$type_id' and cvtermpath type '$cptype_id' with term '$name1' ".
						   "cvterm_id '$cvterm_id_1'");
			}
			## we'll apply the cvtermpath type_id value instead of the cvterm_relationship one.
			$type_id = $cptype_id;
		    }
		    


		    if (defined($type_id)){
			#
			# cvterm_id_1 is the object_id
			#
			$exon_transcript_flag = $self->relate_feature_members($uniquename1,
									      $uniquename2,
									      $type_id,
									      $feature_id_lookup,
									      $feature_id_lookup_d,
									      $name1,
									      $name2,
									      $exon_transcript_flag,
									      $exon_coordinates,
									      $exons_2_transcript);
		    }
		    else{
			if ($self->{_logger}->is_debug()){
			    $self->{_logger}->debug("type_id was not defined, therefore there were no rules for relating cvterm_id '$cvterm_id_1' name '$name1' AND cvterm_id '$cvterm_id_2' name '$name2'");
			}
		    }
		}
	    }
	}
	
	## If this Feature-group contained any transcript and exons, need to process those relationsships now.
	if ($exon_transcript_flag > 0 ){
	    $self->store_exon_transcript_relationships($exons_2_transcript);
	}


    }
}# sub store_bsml_feature_groups()


#-------------------------------------------------------------------------------------------------------------------------
# store_exon_transcript_relationships()
#
# Here we store the exon-transcript relationships 
# and set the feature_relationship.rank correctly.
#
#-------------------------------------------------------------------------------------------------------------------------

sub store_exon_transcript_relationships {

    my ($self, $lookup) = @_;

    foreach my $uniquename (sort keys %{$lookup} ) {

	$self->{_logger}->debug("Processing all exons related to transcript '$uniquename'") if $self->{_logger}->is_debug();

	foreach my $complement (sort keys %{$lookup->{$uniquename}} ) {
	    
	    if ($complement == 1 ){
		#
		# Need to reverse sort based on fmin coordinates.
		#
		my $rank = -1;

		foreach my $hash (reverse sort {$a->{'fmin'} <=> $b->{'fmin'}} @{$lookup->{$uniquename}->{$complement}} ) {

		    $rank++;

		    my $feature_relationship_id = $self->check_feature_relationship_id_lookup(
											      subject_id => $hash->{'subject_id'},
											      object_id  => $hash->{'object_id'},
											      type_id    => $hash->{'type_id'},
											      rank       => $rank
											      );
		    if (!defined($feature_relationship_id)){
			#
			# This exon-transcript relationship did not exist, therefore store record in chado.feature_relationship now.
			#
			$feature_relationship_id = $self->{_backend}->do_store_new_feature_relationship(
													subject_id => $hash->{'subject_id'},
													object_id  => $hash->{'object_id'},
													type_id    => $hash->{'type_id'},
													rank       => $rank
													);
			$self->{_logger}->logdie("feature_relationship_id was not defined for subject_id '$hash->{'subject_id'}' object_id '$hash->{'object_id'}' type_id '$hash->{'type_id'}' rank '$rank'") if (!defined($feature_relationship_id));
		    }
		}
	    }
	    else {
		#
		# Need to forward sort based on fmin coordinates.
		#
		my $rank = -1;
		
		foreach my $hash ( sort {$a->{'fmin'} <=> $b->{'fmin'}} @{$lookup->{$uniquename}->{$complement}} ) {
		    
		    $rank++;
		
		    my $feature_relationship_id = $self->check_feature_relationship_id_lookup(
											      subject_id => $hash->{'subject_id'},
											      object_id  => $hash->{'object_id'},
											      type_id    => $hash->{'type_id'},
											      rank       => $rank
											      );
		    if (!defined($feature_relationship_id)){
			#
			# This exon-transcript relationship did not exist, therefore store record in chado.feature_relationship now.
			#
			$feature_relationship_id = $self->{_backend}->do_store_new_feature_relationship(
													subject_id => $hash->{'subject_id'},
													object_id  => $hash->{'object_id'},
													type_id    => $hash->{'type_id'},
													rank       => $rank
													);
			
			$self->{_logger}->logdie("feature_relationship_id was not defined for subject_id '$hash->{'subject_id'}' object_id '$hash->{'object_id'}' type_id '$hash->{'type_id'}' rank '$rank'") if (!defined($feature_relationship_id));
		    }
		}
	    }
	}
    }
}







#----------------------------------------------------------------
# all_assembly_records()
#
#----------------------------------------------------------------
sub all_assembly_records {

    my ($self, $asmbl_id_list_ref, $idspecified) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    #
    # Verify whether reference to the asmbl_id list was passed in
    #
    $self->{_logger}->logdie("asmbl_id_list_ref was not defined") if (!defined($asmbl_id_list_ref));

    #
    # Set the max text size for text data fields 
    #
    $self->{_backend}->do_set_textsize(TEXTSIZE);

    my $hash = {};
    
    if ($asmbl_id_list_ref eq "ALL"){
	
	my @ret = $self->{_backend}->get_all_assembly_records();
	
	for ( my $i=0; $i < scalar(@ret) ; $i++) {
	    

	                                         # Prism/ProkPrismDB.pm             Prism/EukPrismDB.pm  
	    my $tmphash = {                      # proks/ntproks:                   euks:               
		'sequence'      => $ret[$i][1],  # assembly.sequence                assembly.sequence
		'clone_name'    => $ret[$i][2],  # assembly.com_name                assembly.com_name
		'seq_group'     => $ret[$i][3],  # ''                               clone_info.seq_group
		'chromosome'    => $ret[$i][4],  # ''                               clone_info.chromo
		'gb_accession'  => $ret[$i][5],  # ''                               clone_info.gb_acc
		'is_public'     => $ret[$i][6],  # ''                               clone_info.is_public
		'ed_date'       => $ret[$i][7],  # assembly.ed_date                 clone_info.ed_date
		'topology'      => $ret[$i][8],  # asmbl_data.topology              ''
		'name'          => $ret[$i][9],  # asmbl_data.name                  ''
		'molecule_type' => $ret[$i][10]  # asmbl_data.type                  ''

	    };
	    
	    $hash->{$ret[$i][0]} = $tmphash;
	}
    }
    elsif ($asmbl_id_list_ref ne "ALL"){

	
	#
	# This case, a reference to a list of specified asmbl_ids was defined
	#
	
	foreach my $asmbl_id (@$asmbl_id_list_ref){
	    
	    #
	    # Verify that the asmbl_id was defined
	    #
	    if (!defined($asmbl_id)){
		$self->{_logger}->logdie("asmbl_id was not defined");
	    }
	    #
	    # Verify that the asmbl_id is a digit
	    #
	    if ($asmbl_id !~ /^\d+$/){
		$self->{_logger}->logdie("asmbl_id was not a digit:$asmbl_id");
	    }
	    
	    
	    #
	    # For each asmbl_id in the array execute the query
	    #
	    
	    my @ret = $self->{_backend}->get_all_assembly_records($asmbl_id);
	    
	    for(my $i=0; $i < scalar(@ret) ; $i++){
		
		$self->{_logger}->logdie("asmbl_id '$asmbl_id' does not match '$ret[$i][0]'") if ($asmbl_id ne $ret[$i][0]);
		

		                                     # Prism/ProkPrismDB.pm             Prism/EukPrismDB.pm  
		my $tmphash = {                      # proks/ntproks:                   euks:               
		    'sequence'      => $ret[$i][1],  # assembly.sequence                assembly.sequence
		    'clone_name'    => $ret[$i][2],  # assembly.com_name                assembly.com_name
		    'seq_group'     => $ret[$i][3],  # ''                               clone_info.seq_group
		    'chromosome'    => $ret[$i][4],  # ''                               clone_info.chromo
		    'gb_accession'  => $ret[$i][5],  # ''                               clone_info.gb_acc
		    'is_public'     => $ret[$i][6],  # ''                               clone_info.is_public
		    'ed_date'       => $ret[$i][7],  # assembly.ed_date                 clone_info.ed_date
		    'topology'      => $ret[$i][8],  # asmbl_data.topology              ''
		    'name'          => $ret[$i][9],  # asmbl_data.name                  ''
		    'molecule_type' => $ret[$i][10]  # asmbl_data.type                  ''
		};	    
		

		$hash->{$ret[$i][0]} = $tmphash;
	    }
	}
    }
    
    return ($hash);
}


#----------------------------------------------------------------
# all_assembly_records_by_asmbl_id()
#
# legacy2bsml.pl must only cache data for one assembly at a time
#
#----------------------------------------------------------------
sub all_assembly_records_by_asmbl_id {

    my ($self, $asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    #
    # Verify whether reference to the asmbl_id was passed in
    #
    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));
    
    #
    # Set the max text size for text data fields 
    #
    $self->{_backend}->do_set_textsize(TEXTSIZE);

    my $hash = {};
 
    #
    # Verify that the asmbl_id is a digit
    #
    if ($asmbl_id !~ /^\d+$/){
	$self->{_logger}->logdie("asmbl_id was not a digit:$asmbl_id");
    }
	    
    
    #
    # For each asmbl_id in the array execute the query
    #
    
    my @ret = $self->{_backend}->get_all_assembly_records($asmbl_id);

    # If user incorrectly specified asmbl_id for which there is no sequence
    # then need to report to log4perl log file and then continue to process
    # the next asmbl_id.
    if (scalar(@ret) < 1){
	$self->{_logger}->error("No record retrieve for asmbl_id '$asmbl_id'.  Note that no subfeatures will be migrated for asmbl_id '$asmbl_id'");
	return undef;
    }

    for(my $i=0; $i < scalar(@ret) ; $i++){
	
	$self->{_logger}->logdie("asmbl_id '$asmbl_id' does not match '$ret[$i][0]'") if ($asmbl_id ne $ret[$i][0]);
	
	
	                                           # Prism/ProkPrismDB.p           Prism/EukPrismDB.pm  
	my $tmphash = {                            # proks/ntproks:                euks:               
	    'sequence'            => $ret[$i][1],  # assembly.sequence             assembly.sequence
	    'molecule_name'       => $ret[$i][2],  # asmbl_data.name               clone_info.clone_name
	    'seq_group'           => $ret[$i][3],  # ''                            clone_info.seq_group
	    'chromosome'          => $ret[$i][4],  # ''                            clone_info.chromo
	    'gb_acc'              => $ret[$i][5],  # asmbl_data.acc_num            clone_info.gb_acc
	    'is_public'           => $ret[$i][6],  # ''                            clone_info.is_public
	    'ed_date'             => $ret[$i][7],  # assembly.ed_date              clone_info.ed_date
	    'topology'            => $ret[$i][8],  # asmbl_data.topology           ''
	    'molecule_type'       => $ret[$i][9],  # asmbl_data.type               ''
	    'clone_id'            => $ret[$i][10], #                               clone_info.clone_id
	    'is_orig_annotation'  => $ret[$i][11], #                               clone_info.orig_annotation
	    'is_tigr_annotation'  => $ret[$i][12], #                               clone_info.tigr_annotation
	    'assembly_status'     => $ret[$i][13], #                               clone_info.status
	    'length'              => $ret[$i][14], #                               clone_info.length
	    'fa_left'             => $ret[$i][16], #                               clone_info.fa_left
	    'fa_right'            => $ret[$i][17], #                               clone_info.fa_right
	    'fa_orient'           => $ret[$i][18], #                               clone_info.fa_orient
	    'gb_desc'             => $ret[$i][19], #                               clone_info.gb_desc
	    'gb_comment'          => $ret[$i][20], #                               clone_info.gb_comment
	    'gb_date'             => $ret[$i][21], #                               clone_info.gb_date
	    'comment'             => $ret[$i][22], #                               clone_info.comment
	    'assignby'            => $ret[$i][23], #                               clone_info.assignby
	    'date'                => $ret[$i][24], #                               clone_info.date
	    'lib_id'              => $ret[$i][25], #                               clone_info.lib_id
	    'seq_asmbl_id'        => $ret[$i][26], #                               clone_info.seq_asmbl_id
	    'gb_date_for_release' => $ret[$i][27], #                               clone_info.date_for_release
	    'gb_date_released'    => $ret[$i][28], #                               clone_info.date_released
	    'gb_authors1'         => $ret[$i][29], #                               clone_info.authors1
	    'gb_authors2'         => $ret[$i][30], #                               clone_info.authors2
	    'seq_db'              => $ret[$i][31], #                               clone_info.seq_db
	    'gb_keywords'         => $ret[$i][32], #                               clone_info.gb_keywords
	    'sequencing_type'     => $ret[$i][33], #                               clone_info.sequencing_type
	    'is_prelim'           => $ret[$i][34], #                               clone_info.prelim
	    'is_licensed'         => $ret[$i][35], #                               clone_info.license
	    'gb_phase'            => $ret[$i][36], #                               clone_info.gb_phase
	    'gb_gi'               => $ret[$i][37], #                               clone_info.gb_gi
	};	    

	## The clone_info.final_asmbl information should be transformed into is_final
	## attribute (controlled vocabulary term).  is_final = 1 only if 
	## final_asmbl == 1 else is_final = 0 for all other conditions
	if ( $ret[$i][15] == 1) { 
	    $tmphash->{'is_final'} = 1; # clone_info.final_asmbl
	}
	else{
	    $tmphash->{'is_final'} = 0;
	}

	#
	#
	#--------------------------------------------------------------------------------------


	$hash->{$ret[$i][0]} = $tmphash;
    }
    
    return ($hash);
}


#----------------------------------------------------------------
# all_prok_accession_records()
#
#----------------------------------------------------------------
sub all_prok_accession_records {

    my ($self, $asmbl_list,  $feat_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;


    #
    # Verify whether reference to the asmbl_id list was passed in
    #
    $self->{_logger}->logdie("asmbl_list was not defined") if (!defined($asmbl_list));

    my $hash = {};

    if ($asmbl_list eq "ALL"){

	my @ret = $self->{_backend}->get_all_prok_accession_records(undef, $feat_type);

	for ( my $i=0; $i<@ret; $i++) {

	    push( @{$hash->{$ret[$i][0]}->{$ret[$i][1]}}, {
		'accession_db' => $ret[$i][2],
		'accession_id' => $ret[$i][3]
	    });
	    
	}
    }
    elsif ($asmbl_list ne "ALL"){
	
	#
	# This case, a reference to a list of specified asmbl_ids was defined
	#

	foreach my $asmbl_id (@$asmbl_list){

	    #
	    # Verify that the asmbl_id was defined
	    #
	    if (!defined($asmbl_id)){
		$self->{_logger}->logdie("asmbl_id was not defined");
	    }
	    #
	    # Verify that the asmbl_id is a digit
	    #
	    if ($asmbl_id !~ /^\d+$/){
		$self->{_logger}->logdie("asmbl_id was not a digit:$asmbl_id");
	    }


	    #
	    # For each asmbl_id in the array execute the query
	    #

	    my @ret = $self->{_backend}->get_all_prok_accession_records($asmbl_id, $feat_type);

	    for(my $i=0 ; $i<scalar(@ret) ; $i++){

		$self->{_logger}->logdie("asmbl_id '$asmbl_id' does not match '$ret[$i][0]'") if ($asmbl_id ne $ret[$i][0]);
		push( @{$hash->{$ret[$i][0]}->{$ret[$i][1]}}, {
		    'accession_db' => $ret[$i][2],
		    'accession_id' => $ret[$i][3]
		});

	    }		
	}
    }
    return ($hash);
}




sub check_and_set_text_size {

    my ($self) = @_;
    
    $self->{_backend}->do_set_textsize(TEXTSIZE);
}




sub sequence_features {

    my ($self, $asmbl_id, $db, $feat_type, $schemaType) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_sequence_features($asmbl_id, $db, $feat_type, $schemaType);

}


sub gene_model_data {

    my ($self, $asmbl_id, $db, $schemaType) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_gene_model_data($asmbl_id, $db, $schemaType);

}


sub accession_data {

    my ($self, $asmbl_id, $db, $schemaType) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_accession_data($asmbl_id, $db, $schemaType);

}
 

sub rna_data {

    my ($self, $asmbl_id, $db, $feat_type, $schemaType) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_rna_data($asmbl_id, $db, $feat_type, $schemaType);

}

sub rnaDataByAsmblId {

    my $self = shift;
    my ($asmbl_id, $database, $schema_type, $lookup) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->getRnaDataByAsmblId(@_);

    if (defined($ret)){

	for (my $i=0; $i < scalar(@{$ret}); $i++){
	    
	    my $feat_name = shift(@{$ret->[$i]});
	    
	    # remove all open parentheses
	    $feat_name =~ s/\(//g;
	    
	    # remove all close parentheses
	    $feat_name =~ s/\)//g;
	    
	    if (exists $lookup->{$feat_name}){
		$self->{_logger}->logdie("feat_name '$feat_name' feat_type '$ret->[$i][3]' already ".
					 "exists in the RNA lookup for asmbl_id '$asmbl_id' ".
					 "database '$database'");
	    }
	    else {
		$lookup->{$feat_name} = $ret->[$i];
	    }
	}
    }
}


sub trnaScoresLookup {

    my ($self, $asmbl_id, $db, $schema_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->getTrnaScores($asmbl_id, $db, $schema_type);
 
    if (defined($ret)){

	my $lookup = {};
	my $i=0;
	
	for ($i=0; $i < scalar(@{$ret}) ; $i++){
	    if (exists $lookup->{$ret->[$i][0]}){
		$self->{_logger}->logdie("feat_name '$ret->[$i][0]' already exists in the tRNA score lookup");
	    }
	    else {
		$lookup->{$ret->[$i][0]} = $ret->[$i][1];
	    }
	}
	
	$self->{_logger}->info("Retrieved '$i' tRNA score values for database '$db' asmbl_id '$asmbl_id'");
	
	return $lookup;
    }
    return undef;
}

sub trna_scores {

    my ($self, $asmbl_id, $db, $feat_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_trna_scores($asmbl_id, $db, $feat_type);

}


sub peptide_data {

    my ($self, $asmbl_id, $db, $schemaType) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_peptide_data($asmbl_id, $db, $schemaType);

}



sub ribosomal_data {

    my ($self, $asmbl_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_ribosomal_data($asmbl_id, $db);

}



sub terminator_data {
    
    my ($self, $asmbl_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_terminator_data($asmbl_id, $db);

}

sub term_direction_data {

    my ($self, $asmbl_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_term_direction_data($asmbl_id, $db);

}

sub term_confidence_data {

    my ($self, $asmbl_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_term_confidence_data($asmbl_id, $db);

}
 
sub terminator_to_gene_data {
    
    my ($self, $asmbl_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_terminator_to_gene_data($asmbl_id, $db);

}



sub rbs_to_gene_data {
    
    my ($self, $asmbl_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_rbs_to_gene_data($asmbl_id, $db);

}



sub gene_annotation_ident_attribute_data {

    my ($self, $asmbl_id, $db, $schemaType) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_gene_annotation_ident_attribute_data($asmbl_id, $db, $schemaType);

}

sub ident_xref_attr_data {

    my ($self, $asmbl_id, $db, $xref_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_ident_xref_attr_data($asmbl_id, $db, $xref_type);

}


sub gene_annotation_go_attribute_data {

    my ($self, $asmbl_id, $db, $schemaType) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_gene_annotation_go_attribute_data($asmbl_id, $db, $schemaType);

}



sub gene_annotation_evidence_data {

    my ($self, $asmbl_id, $db, $feat_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_gene_annotation_evidence_data($asmbl_id, $db, $feat_type);

}





sub gene_orf_attributes {

    my ($self, $asmbl_id, $db, $feat_type, $att_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_gene_orf_attributes($asmbl_id, $db, $feat_type, $att_type);

}

sub lipoMembraneProteins {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->getLipoMembraneProteins(@_);

}


sub gene_orf_score_data {

    my ($self, $asmbl_id, $db, $feat_type, $att_type, $score_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_gene_orf_score_data($asmbl_id, $db, $feat_type, $att_type, $score_type);

}

sub tigr_roles_lookup {

    my ($self) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_tigr_roles_lookup(@_);

}


sub ber_evidence_data {

    my ($self, $asmbl_id, $db, $feat_type, $ev_type, $score_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_ber_evidence_data($asmbl_id, $db, $feat_type, $ev_type, $score_type);

}

sub hmm_evidence_data {

    my ($self, $asmbl_id, $db, $feat_type, $ev_type, $score_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_hmm_evidence_data($asmbl_id, $db, $feat_type, $ev_type, $score_type);

}

sub cog_evidence_data {

    my ($self, $asmbl_id, $db, $feat_type, $ev_type, $score_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_cog_evidence_data($asmbl_id, $db, $feat_type, $ev_type, $score_type);

}

sub prosite_evidence_data {

    my ($self, $asmbl_id, $db, $feat_type, $ev_type, $score_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_prosite_evidence_data($asmbl_id, $db, $feat_type, $ev_type, $score_type);

}


#---------------------------------------------------------
# cvterm_id_by_dbxref_accession_lookup()
#
#---------------------------------------------------------
sub cvterm_id_by_dbxref_accession_lookup {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cvterm_id_by_dbxref_accession_lookup'} = $self->{_backend}->get_cvterm_id_by_dbxref_accession_lookup();
    
}


#---------------------------------------------------------
# all_analysisfeature_records_by_type()
#
#---------------------------------------------------------
sub all_analysisfeature_records_by_type {

    my ($self, $type_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_analysisfeature_records_by_type($type_id);
}


#---------------------------------------------------------
# all_featureprop_records_by_type()
#
#---------------------------------------------------------
sub all_featureprop_records_by_type {

    my ($self, $type_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_featureprop_records_by_type($type_id);

}


#---------------------------------------------------------
# all_featureloc_records_by_type()
#
#---------------------------------------------------------
sub all_featureloc_records_by_type {

    my ($self, $type_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_featureloc_records_by_type($type_id);

}


#---------------------------------------------------------
# all_feature_relationship_records_by_type()
#
#---------------------------------------------------------
sub all_feature_relationship_records_by_type {

    my ($self, $type_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_feature_relationship_records_by_type($type_id);
}

#---------------------------------------------------------
# all_feature_cvterm_records_by_type()
#
#---------------------------------------------------------
sub all_feature_cvterm_records_by_type {

    my ($self, $type_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_feature_cvterm_records_by_type($type_id);
}

#---------------------------------------------------------
# all_feature_dbxref_records_by_type()
#
#---------------------------------------------------------
sub all_feature_dbxref_records_by_type {

    my ($self, $type_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_feature_dbxref_records_by_type($type_id);
}



#---------------------------------------------------------
# all_feature_cvtermprop_records_by_type()
#
#---------------------------------------------------------
sub all_feature_cvtermprop_records_by_type {

    my ($self, $type_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_feature_cvtermprop_records_by_type($type_id);
}

#---------------------------------------------------------
# all_seq_to_feat_analysisfeature_records()
#
#---------------------------------------------------------
sub all_seq_to_feat_analysisfeature_records {

    my ($self, $uniquename) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_seq_to_feat_analysisfeature_records($uniquename);
}


#---------------------------------------------------------
# all_seq_to_feat_featureprop_records()
#
#---------------------------------------------------------
sub all_seq_to_feat_featureprop_records {

    my ($self, $uniquename) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_seq_to_feat_featureprop_records($uniquename);

}


#---------------------------------------------------------
# all_seq_to_feat_featureloc_records()
#
#---------------------------------------------------------
sub all_seq_to_feat_featureloc_records {

    my ($self, $uniquename) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_seq_to_feat_featureloc_records($uniquename);

}


#---------------------------------------------------------
# all_seq_to_feat_feature_relationship_records()
#
#---------------------------------------------------------
sub all_seq_to_feat_feature_relationship_records {

    my ($self, $uniquename) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_seq_to_feat_feature_relationship_records($uniquename);
}



#---------------------------------------------------------
# all_seq_to_feat_feature_cvterm_records()
#
#---------------------------------------------------------
sub all_seq_to_feat_feature_cvterm_records {

    my ($self, $uniquename) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_seq_to_feat_feature_cvterm_records($uniquename);
}



#---------------------------------------------------------
# all_seq_to_feat_feature_dbxref_records()
#
#---------------------------------------------------------
sub all_seq_to_feat_feature_dbxref_records {

    my ($self, $uniquename) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_seq_to_feat_feature_dbxref_records($uniquename);
}


#---------------------------------------------------------
# all_seq_to_feat_feature_cvtermprop_records()
#
#---------------------------------------------------------
sub all_seq_to_feat_feature_cvtermprop_records {

    my ($self, $uniquename) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_seq_to_feat_feature_cvtermprop_records($uniquename);
}



#---------------------------------------------------------
# all_seq_uniquenames_by_type()
#
#---------------------------------------------------------
sub all_seq_uniquenames_by_type {

    my ($self, $type_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_seq_uniquenames_by_type($type_id);
}

#---------------------------------------------------------
# cv_id_lookup()
#
#---------------------------------------------------------
sub cv_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cv_id_lookup'} = $self->{_backend}->get_cv_id_lookup();

}

#---------------------------------------------------------
# cvterm_id_lookup()
#
#---------------------------------------------------------
sub cvterm_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'non_obsolete_cvterm_id_lookup'} = $self->{_backend}->get_non_obsolete_cvterm_id_lookup();

    $self->{'obsolete_cvterm_id_lookup'} = $self->{_backend}->get_obsolete_cvterm_id_lookup();
}


#---------------------------------------------------------
# cvtermpath_id_lookup()
#
#---------------------------------------------------------
sub cvtermpath_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cvtermpath_id_lookup'} = $self->{_backend}->get_cvtermpath_id_lookup();
}

#---------------------------------------------------------
# db_id_lookup()
#
#---------------------------------------------------------
sub db_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'db_id_lookup'} = $self->{_backend}->get_db_id_lookup();

}


#---------------------------------------------------------
# dbxref_id_lookup()
#
#---------------------------------------------------------
sub dbxref_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'dbxref_id_lookup'} = $self->{_backend}->get_dbxref_id_lookup();
}

#---------------------------------------------------------
# organism_id_lookup()
#
#---------------------------------------------------------
sub organism_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'organism_id_lookup'} = $self->{_backend}->get_organism_id_lookup();
}

#---------------------------------------------------------
# organismprop_id_lookup()
#
#---------------------------------------------------------
sub organismprop_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'organismprop_id_lookup'} = $self->{_backend}->get_organismprop_id_lookup();
}

#---------------------------------------------------------
# organism_dbxref_id_lookup()
#
#---------------------------------------------------------
sub organism_dbxref_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'organism_dbxref_id_lookup'} = $self->{_backend}->get_organism_dbxref_id_lookup();
}

#---------------------------------------------------------
# get_pub_id_lookup()
#
#---------------------------------------------------------
sub pub_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'pub_id_lookup'} = $self->{_backend}->get_pub_id_lookup();
}

#---------------------------------------------------------
# get_pub_relationship_id_lookup()
#
#---------------------------------------------------------
sub pub_relationship_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'pub_relationship_id_lookup'} = $self->{_backend}->get_pub_relationship_id_lookup();
}


#---------------------------------------------------------
# get_pub_dbxref_id_lookup()
#
#---------------------------------------------------------
sub pub_dbxref_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'pub_dbxref_id_lookup'} = $self->{_backend}->get_pub_dbxref_id_lookup();
}

#---------------------------------------------------------
# get_pubauthor_id_lookup()
#
#---------------------------------------------------------
sub pubauthor_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'pubauthor_id_lookup'} = $self->{_backend}->get_pubauthor_id_lookup();
}

#---------------------------------------------------------
# get_pubprop_id_lookup()
#
#---------------------------------------------------------
sub pubprop_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'pubprop_id_lookup'} = $self->{_backend}->get_pubprop_id_lookup();
}

#---------------------------------------------------------
# cvterm_id_by_accession_lookup()
#
#---------------------------------------------------------
sub cvterm_id_by_accession_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cvterm_id_by_accession_lookup'} = $self->{_backend}->get_cvterm_id_by_accession_lookup();
}

#---------------------------------------------------------
# cvterm_id_by_dbxref_accession_lookup_args()
#
#---------------------------------------------------------
sub cvterm_id_by_dbxref_accession_lookup_args {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_cvterm_id_by_dbxref_accession_lookup_args(@_);
}

#---------------------------------------------------------
# cvterm_id_by_name_lookup()
#
#---------------------------------------------------------
sub cvterm_id_by_name_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cvterm_id_by_name_lookup'} = $self->{_backend}->get_cvterm_id_by_name_lookup();
}


#---------------------------------------------------------
# cvterm_relationship_type_id_lookup()
#
#---------------------------------------------------------
sub cvterm_relationship_type_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cvterm_relationship_type_id_lookup'} = $self->{_backend}->get_cvterm_relationship_type_id_lookup();
}


#---------------------------------------------------------
# analysis_id_lookup()
#
#---------------------------------------------------------
sub analysis_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'analysis_id_lookup'} = $self->{_backend}->get_analysis_id_lookup();

}


#---------------------------------------------------------
# name_by_analysis_id_lookup()
#
#---------------------------------------------------------
sub name_by_analysis_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'name_by_analysis_id_lookup'} = $self->{_backend}->get_name_by_analysis_id_lookup();
}

#---------------------------------------------------------
# analysisprop_id_lookup()
#
#---------------------------------------------------------
sub analysisprop_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'analysisprop_id_lookup'} = $self->{_backend}->get_analysisprop_id_lookup();
}


#---------------------------------------------------------
# property_types_lookup()
#
#---------------------------------------------------------
sub property_types_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'property_types_lookup'} = $self->{_backend}->get_property_types_lookup();
}




#---------------------------------------------------------
# analysis_id_by_wfid_lookup()
#
#---------------------------------------------------------
sub analysis_id_by_wfid_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'analysis_id_by_wfid_lookup'} = $self->{_backend}->get_analysis_id_by_wfid_lookup();

}

#---------------------------------------------------------
# analysis_id_by_name()
#
#---------------------------------------------------------
sub analysis_id_by_name {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'analysis_id_by_name'} = $self->{_backend}->get_analysis_id_by_name();

}


#---------------------------------------------------------
# cvterm_id_by_name()
#
#---------------------------------------------------------
sub cvterm_id_by_name {

    my ($self, $term) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cvterm_id_by_name_lookup'} = $self->{_backend}->get_cvterm_id_by_name($term);

}

#---------------------------------------------------------
# cvterm_id_by_class_lookup()
#
#---------------------------------------------------------
sub cvterm_id_by_class_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cvterm_id_by_class_lookup'} =  $self->{_backend}->get_cvterm_id_by_class_lookup();
}

#---------------------------------------------------------
# all_cvterm_id_by_typedef()
#
#---------------------------------------------------------
sub all_cvterm_id_by_typedef {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_cvterm_id_by_typedef();
}

#---------------------------------------------------------
# retrieve_foreign_keys()
#
#---------------------------------------------------------
sub retrieve_foreign_keys {

    my ($self, $table, $parent, $grepline) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my (@ret, $s, $i);

    foreach my $childkey (sort keys %{$grepline->{$table}->{'keys'}}) {
	
	my $ptable    = $grepline->{$table}->{'keys'}->{$childkey}->[0];
	my $parentkey = $grepline->{$table}->{'keys'}->{$childkey}->[1];

	if ($parent ne $ptable){
	    $self->{_logger}->info("parent '$parent' ptable '$ptable', going to next ptable in grepline hash...");
	    next;
	}

	$self->{_logger}->info("Retrieving all data items from parent table '$parent' in column '$parentkey' for child table '$table' column '$childkey'");

	@ret = $self->{_backend}->get_table_records($ptable, $parentkey);

	# SELECT * FROM $parent

	for ( $i=0; $i<@ret; $i++) {

	    # parent table's column of interest to the child table
	    $s->{$parentkey}->{$ret[$i][0]} = $ret[$i][0];   
		
	}
	    
	#
	# I am willing to return from here since as far as chado schema is concerned, 
	# there is ever only one field in the child table referencing only one field 
	# in the parent table.
	#
	return ($s);
    }
    $self->{_logger}->warn("Could not retrieve any records from parent table '$parent' for child table '$table'");
}


#----------------------------------------------------------------
# seq_id_to_RNA()
#
#----------------------------------------------------------------
sub seq_id_to_RNA {

    my($self, $asmbl_id, $assembly_cvterm_id, $rnas) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));
    $self->{_logger}->logdie("assembly_cvterm_id was not defined") if (!defined($assembly_cvterm_id));
    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($rnas));

    my $rna_lookup = {};

    foreach my $rnatype (sort keys %{$rnas}) {

	my $rna_cvterm_id = $rnas->{$rnatype}->{'cvterm_id'};
	$self->{_logger}->logdie("cvterm_id was not defined for RNA type '$rnatype'") if (!defined($rna_cvterm_id));
        

	my $ret = $self->{_backend}->get_seq_id_to_RNA(
						       $asmbl_id,
						       $assembly_cvterm_id,
						       $rna_cvterm_id,
						       $rnatype
						       );

	# SELECT r.uniquename, fl.fmin, fl.fmax, fl.strand, r.seqlen, fp.value
	# FROM feature r, feature a, featureloc fl, featureprop fp, cvterm c
	# WHERE r.type_id = $rna_cvterm_id
	# AND r.feature_id = fl.feature_id
	# AND fl.srcfeature_id = a.feature_id
	# AND a.type_id = $assembly_cvterm_id
	# AND a.uniquename = $asmbl_id
	# AND r.feature_id = fp.feature_id
	# AND fp.type_id = c.cvterm_id
	# AND c.name = 'name'

# 	SELECT r.uniquename, fl.fmin, fl.fmax, fl.strand, r.seqlen, fp.value, r.feature_id
# 	FROM feature r, feature a, featureloc fl, featureprop fp, cvterm c
# 	WHERE r.type_id = 4871
# 	AND r.feature_id = fl.feature_id
# 	AND fl.srcfeature_id = a.feature_id
# 	AND a.type_id = 4972
# 	AND a.uniquename = 'gba_6615_assembly'
# 	AND r.feature_id = fp.feature_id
# 	AND fp.type_id = c.cvterm_id
# 	AND c.name = 'name'
# 	AND r.uniquename = 'gba_6615_Ba23SJ_rRNA'

	for (my $i=0; $i< @{$ret}; $i++) {

	    push (@{$rna_lookup->{$rnatype}}, {
		'id'     => $ret->[$i][0],
		'fmin'   => $ret->[$i][1],
		'fmax'   => $ret->[$i][2],
		'strand' => $ret->[$i][3],
		'seqlen' => $ret->[$i][4],
		'name'   => $ret->[$i][5],
		
		
	    });
	}
    }

    return($rna_lookup);
}



#----------------------------------------------------------------
# seq_id_to_signal_peptide()
#
#----------------------------------------------------------------
sub seq_id_to_signal_peptide {

    my($self, $asmbl_id, $assembly_cvterm_id, $signal_peptide_cvterm_id, $polypeptide_cvterm_id, $part_of_cvterm_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));
    $self->{_logger}->logdie("assembly_cvterm_id was not defined") if (!defined($assembly_cvterm_id));
    $self->{_logger}->logdie("signal_peptide_cvterm_id was not defined") if (!defined($signal_peptide_cvterm_id));
    $self->{_logger}->logdie("polypeptide_cvterm_id was not defined") if (!defined($polypeptide_cvterm_id));
    $self->{_logger}->logdie("part_of_cvterm_id was not defined") if (!defined($part_of_cvterm_id));

    my $signal_peptide_lookup = {};
        
    my $ret = $self->{_backend}->get_seq_id_to_signal_peptide(
							      $asmbl_id,
							      $assembly_cvterm_id,
							      $signal_peptide_cvterm_id,
							      $polypeptide_cvterm_id,
							      $part_of_cvterm_id
							      );

    # SELECT p.uniquename, s.uniquename, fl.fmin, fl.fmax, fl1.strand
    # FROM feature s, feature p, feature a, featureloc fl, feature_relationship fr
    # WHERE s.type_id = $signal_peptide_cvterm_id
    # AND s.feature_id = fr.subject_id
    # AND fr.object_id = p.feature_id
    # AND p.type_id = $polypeptide_cvterm_id
    # AND p.feature_id = fl.feature_id
    # AND fl.srcfeature_id = a.feature_id
    # AND a.type_id = $assembly_cvterm_id
    # AND a.uniquename = $asmbl_id
    # AND fr.type_id = $part_of_cvterm_id
    
    for (my $i=0; $i< @{$ret}; $i++) {

	$signal_peptide_lookup->{$ret->[$i][0]} = {
	    'signal_peptide' => $ret->[$i][1],
	    'fmin'           => $ret->[$i][2],
	    'fmax'           => $ret->[$i][3],
	    'strand'         => $ret->[$i][4]
	};
    }
    
    return($signal_peptide_lookup);
}


#----------------------------------------------------------------
# seq_id_to_ribosome_entry_site()
#
#----------------------------------------------------------------
sub seq_id_to_ribosome_entry_site {

    my($self, $asmbl_id, $assembly_cvterm_id, $ribosome_cvterm_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));
    $self->{_logger}->logdie("assembly_cvterm_id was not defined") if (!defined($assembly_cvterm_id));
    $self->{_logger}->logdie("ribosome_cvterm_id was not defined") if (!defined($ribosome_cvterm_id));

    my $ribosome_lookup;
        
    my $ret = $self->{_backend}->get_seq_id_to_ribosome_entry_site(
								   $asmbl_id,
								   $assembly_cvterm_id,
								   $ribosome_cvterm_id);

    # SELECT r.uniquename, fl1.fmin, fl1.fmax, fl1.strand
    # FROM feature r, feature a, featureloc fl1
    # WHERE r.type_id = $ribosome_cvterm_id
    # AND r.feature_id = fl1.feature_id
    # AND fl1.srcfeature_id = a.feature_id
    # AND a.type_id = $assembly_cvterm_id
    # AND a.uniquename = $asmbl_id
    #
    
    for (my $i=0; $i< @{$ret}; $i++) {

	my @s;
	$s[0] = $ret->[$i][0];
	$s[1] = $ret->[$i][1];
	$s[2] = $ret->[$i][2];
	$s[3] = $ret->[$i][3];

	push (@{$ribosome_lookup}, \@s);
    }
    
    return($ribosome_lookup);

}


#----------------------------------------------------------------
# seq_id_to_terminator()
#
#----------------------------------------------------------------
sub seq_id_to_terminator {

    my($self, $asmbl_id, $assembly_cvterm_id, $terminator_cvterm_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));
    $self->{_logger}->logdie("assembly_cvterm_id was not defined") if (!defined($assembly_cvterm_id));
    $self->{_logger}->logdie("terminator_cvterm_id was not defined") if (!defined($terminator_cvterm_id));

    my $terminator_lookup = {};
        
    my $ret = $self->{_backend}->get_seq_id_to_terminator(
							  $asmbl_id,
							  $assembly_cvterm_id,
							  $terminator_cvterm_id);
    
    # SELECT t.uniquename, fl1.fmin, fl1.fmax, fl1.strand
    # FROM feature t, feature a, featureloc fl1
    # WHERE t.type_id = $terminator_cvterm_id
    # AND t.feature_id = fl1.feature_id
    # AND fl1.srcfeature_id = a.feature_id
    # AND a.type_id = $assembly_cvterm_id
    # AND a.uniquename = $asmbl_id
    #
    
    for (my $i=0; $i< @{$ret}; $i++) {

	$terminator_lookup->{$ret->[$i][0]} = [
					       $ret->[$i][1],
					       $ret->[$i][2],
					       $ret->[$i][3]
					       ];
    }
    
    return($terminator_lookup);
}



#----------------------------------------------------------------
# organism_2_assembly()
#
#----------------------------------------------------------------
sub organism_2_assembly {

    my($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
        
    
    my $ret = $self->{_backend}->get_organism_2_assembly();
    
    #   select o.genus, o.species, a.uniquename
    #   from organism o, organism_dbxref od, dbxref d, db, feature a, dbxref ad, cvterm c
    #   where o.organism_id = od.organism_id
    #   and od.dbxref_id = d.dbxref_id
    #   and d.db_id = db.db_id
    #   and db.db_id = ad.db_id 
    #   and ad.dbxref_id = a.dbxref_id
    #   and a.type_id = c.cvterm_id
    #   and c.name = 'assembly'


    my $hash = {};

    for (my $i=0; $i< @{$ret}; $i++) {


	my $organism = lc($ret->[$i][0]) . '_' . lc($ret->[$i][1]);

	$organism =~ s/\s+//g;

	$organism =~ s/\.$//;

	push ( @{$hash->{$organism}}, $ret->[$i][2]);
    }
    
    return($hash);

}



#----------------------------------------------------------------
# table_primary_and_tuples()
#
#----------------------------------------------------------------
sub table_primary_and_tuples {

    my($self, $tablename, $pkey, $uckeys) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_table_primary_and_tuples($tablename, $pkey, $uckeys);
    
}


#----------------------------------------------------------------
# store_custom_cvterm_relationships()
#
#----------------------------------------------------------------
sub store_custom_cvterm_relationships {

    my($self, $custom) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    

    $self->{_logger}->logdie("custom was not defined") if (!defined($custom));
    
    
    foreach my $subject (keys %{$custom}) {
	
	foreach my $arr ($custom->{$subject}){
	    
	    my $subject_id = $self->{_backend}->get_cvterm_id_from_so($subject);
	    $self->{_logger}->logdie("cvterm_id was not defined for name '$subject'") if (!defined($subject_id));
	    
	    my $type_id = $self->{_backend}->get_cvterm_id_from_typedef($arr->[0]);
	    $self->{_logger}->logdie("cvterm_id was not defined for name '$arr->[0]' subject '$subject'") if (!defined($type_id));

	    my $object_id = $self->{_backend}->get_cvterm_id_from_so($arr->[1]);
	    $self->{_logger}->logdie("cvterm_id was not defined for name '$arr->[1]' subject '$subject'") if (!defined($object_id));


	    my $cvterm_relationship_id = $self->{_backend}->get_cvterm_relationship_id_from_cvterm_relationship(
												type_id    => $type_id->[0][0],
												subject_id => $subject_id->[0][0],
												object_id  => $object_id->[0][0]
												);

	   
	    if (!defined($cvterm_relationship_id)){
		$cvterm_relationship_id = $self->{_backend}->do_store_new_cvterm_relationship(
											      type_id => $type_id->[0][0],
											      subject_id => $subject_id->[0][0],
											      object_id  => $object_id->[0][0]
											      );
		if (!defined($cvterm_relationship_id)){
		    $self->{_logger}->logdie("Could not insert record into cvterm_relationship for relationship type '$arr->[0]' type_id' $type_id->[0][0]' subject '$subject' subject_id '$subject_id->[0][0]' object '$arr->[1]' object_id '$object_id->[0][0]'");
		}
	    }
	    else{
		$self->{_logger}->info("cvterm_relationship_id '$cvterm_relationship_id' type_id '$type_id->[0][0]' relationship type '$arr->[0]' subject_id '$subject_id->[0][0]' subject '$subject' object_id '$object_id->[0][0]' object '$arr->[1] was already in the target chado database");
	    }
	}
    }
}


#----------------------------------------------------------------
# all_valid_prok_asmbl_ids()
#
#----------------------------------------------------------------
sub all_valid_prok_asmbl_ids {

    my ($self, $organism) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_all_valid_prok_asmbl_ids($organism);
	
}

#----------------------------------------------------------------
# chado_databases()
#
#----------------------------------------------------------------
sub chado_databases {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_chado_databases();
	
}

#----------------------------------------------------------------
# organism_count()
#
#----------------------------------------------------------------
sub organism_count {

    my ($self, $database) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_organism_count($database);
	
}

#----------------------------------------------------------------
# residue_sum()
#
#----------------------------------------------------------------
sub residue_sum {

    my ($self, $database) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_residue_sum($database);
	
}
#----------------------------------------------------------------
# gene_count()
#
#----------------------------------------------------------------
sub gene_count {

    my ($self, $database) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_gene_count($database);
	
}

#----------------------------------------------------------------
# feature_count()
#
#----------------------------------------------------------------
sub feature_count {

    my ($self, $database) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_feature_count($database);
	
}

#----------------------------------------------------------------
# analysisfeature_count()
#
#----------------------------------------------------------------
sub analysisfeature_count {

    my ($self, $database) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_analysisfeature_count($database);
	
}

#----------------------------------------------------------------
# featureloc_count()
#
#----------------------------------------------------------------
sub featureloc_count {

    my ($self, $database) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_featureloc_count($database);
	
}

#----------------------------------------------------------------
# featureprop_count()
#
#----------------------------------------------------------------
sub featureprop_count {

    my ($self, $database) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_featureprop_count($database);
	
}


sub feature_uniquenamelookup{
    my ($self) = @_;

    return $self->{_backend}->get_feature_uniquenamelookup();
}




#----------------------------------------------------------------
# query_cv_module()
#
#----------------------------------------------------------------
sub query_cv_module {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->do_query_cv_module();
    
}


#----------------------------------------------------------------
# query_organism_module()
#
#----------------------------------------------------------------
sub query_organism_module {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->do_query_organism_module();
    
}



#----------------------------------------------------------------
# query_featuretypes()
#
#----------------------------------------------------------------
sub query_featuretypes {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->do_query_organism_module();
    
}



#----------------------------------------------------------------
# computational_data()
#
#----------------------------------------------------------------
sub computational_data {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    

    my $hash = {};

    print "Retrieving computational analysis record counts\n";
    
    my $ref = $self->{_backend}->get_analysis_id_program_sourcename_from_analysis();

    foreach (my $i=0; $i < @{$ref}; $i++ ){

	$hash->{$ref->[$i][2]} = { 'program'     => $ref->[$i][1],
				   'analysis_id' => $ref->[$i][0]
			       };


	my $feature_counts = $self->{_backend}->get_feature_counts_by_analysis_id($ref->[$i][0]);

	$hash->{$ref->[$i][2]}->{'feature'} = $feature_counts->[0][0];


	my $featureloc_counts = $self->{_backend}->get_featureloc_counts_by_analysis_id($ref->[$i][0]);

	$hash->{$ref->[$i][2]}->{'featureloc'} = $featureloc_counts->[0][0];

	my $analysisfeature_counts = $self->{_backend}->get_analysisfeature_counts_by_analysis_id($ref->[$i][0]);

	$hash->{$ref->[$i][2]}->{'analysisfeature'} = $analysisfeature_counts->[0][0];

    }


    return $hash;
    
}


#----------------------------------------------------------------
# gene_finder_models()
#
#----------------------------------------------------------------
sub gene_finder_models {

    my ($self, $asmbl_id, $exclude_genefinder_hash, $include_genefinder_list) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    # to retrieve coding region data


    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));

    #
    # Set the max text size for sequence and protein data fields
    #
    $self->{_backend}->do_set_textsize(TEXTSIZE);

    my $retarray = [];

    foreach my $includetype ( @{$include_genefinder_list} ){

	#
	# Query by specified gene finder datatype (as specified in include_genefinder_list)
	#
	my @ret = $self->{_backend}->get_gene_finder_models($asmbl_id, $includetype);
	
	
	for (my $i=0; $i<@ret; $i++) {
	 
	    if (exists $exclude_genefinder_hash->{$ret[$i][6]} ){
		#
		# This record should be excluded from the migration since the ev_type matches one of the excluded types
		#
		next;
	    }
	    else {
		#
		# This record should NOT be excluded from the migration
		#
		    
		#
		# Adjust the coordinates for compatibility with BSML encoding
		#
		my ($end5, $end3, $complement) = &coordinates($ret[$i][1], $ret[$i][2]);
		
		
		push ( @{$retarray}, { 'feat_name'  => $ret[$i][0],
				       'end5'       => $end5,
				       'end3'       => $end3,
				       'complement' => $complement,
				       'sequence'   => $ret[$i][3],
				       'protein'    => $ret[$i][4],
				       'date'       => $ret[$i][5],
				       'ev_type'    => $ret[$i][6]
				   });
	    }
	}
    }
    
    return $retarray;


}



#----------------------------------------------------------------
# gene_finder_exons()
#
#----------------------------------------------------------------
sub gene_finder_exons {
    
    my($self, $asmbl_id, $exclude_genefinder_hash, $include_genefinder_list) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));

    my (%s);


    my $record_ctr = 0;
    
    foreach my $includetype ( @{$include_genefinder_list} ){

	#
	# Query by specified gene finder datatype (as specified in include_genefinder_list)
	#
	my @ret = $self->{_backend}->get_gene_finder_exons($asmbl_id, $includetype);

	for (my $i=0; $i<@ret; $i++) {

	    if ( exists $exclude_genefinder_hash->{$ret[$i][5]} ) {
		#
		# This record should be excluded from the migration since the ev_type matches one of the exlcuded types
		#
		next;
	    }
	    else {
		#
		# This record should NOT be excluded from the migration
		#

		#
		# Adjust the coordinates for compatibility with BSML encoding
		#
		my ($end5, $end3, $complement) = &coordinates($ret[$i][2], $ret[$i][3]);

		$s{$i}->{'feat_name'}        = $ret[$i][0];
		$s{$i}->{'parent_feat_name'} = $ret[$i][1];
		$s{$i}->{'end5'}             = $end5;
		$s{$i}->{'end3'}             = $end3;
		$s{$i}->{'complement'}       = $complement;
		$s{$i}->{'date'}             = $ret[$i][4];	
		$s{$i}->{'ev_type'}          = $ret[$i][5];	

		$record_ctr++;
	    }
	}
    }
	
    $s{'count'} = $record_ctr;

    return (\%s);
}    




#-----------------------------------------------------------------------------------------
# sysobjects()
#
# Returns a list of all sysobjects where type = 'U'.
#
# This list will be used to generate a list of  
# tables to be dropped from the specified chado 
# database.
#
#-----------------------------------------------------------------------------------------
sub sysobjects {
    
    my($self, $objectType) = @_;

    my $list = {};

    my $ret = $self->{_backend}->get_sysobjects($objectType);

    for (my $i=0; $i < @{$ret}; $i++ ) {

	$list->{$ret->[$i][0]}++;
    }

    return $list;

}


#-----------------------------------------------------------------------------------------
# drop_foreign_key_constraints()
#
# This script will now drop all foreign key constraints prior to
# dropping all tables.
#
#-----------------------------------------------------------------------------------------
sub drop_foreign_key_constraints {
    
    my($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    $self->{_backend}->do_drop_foreign_key_constraints();

}

 
#-----------------------------------------------------------------------------------------
# droptables()
#
# The list of tables will be dropped from the specified
# chado database in the order specified by the commit
# order.
#
#-----------------------------------------------------------------------------------------
sub droptables {
    
    my($self, $list, $commit_order, $database) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;


    $self->{_logger}->logdie("list was not defined") if (!defined($list));
    $self->{_logger}->logdie("commit_order was not defined") if (!defined($commit_order));

    $self->{_backend}->do_droptables($list, $commit_order, $database);

}



#---------------------------------------------------------------
# analysisfeature_id_lookup()
#
#---------------------------------------------------------------
sub analysisfeature_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'analysisfeature_id_lookup'} = $self->{_backend}->get_analysisfeature_id_lookup();
}


#---------------------------------------------------------------
# cvtermsynonym_synonym_lookup()
#
#---------------------------------------------------------------
sub cvtermsynonym_synonym_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cvtermsynonym_synonym_lookup'} = $self->{_backend}->get_cvtermsynonym_synonym_lookup();
}

#---------------------------------------------------------------
# typedef_lookup()
#
# Returns typedef relationship terms to cvterm_id lookup
#
#---------------------------------------------------------------
sub typedef_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;


    my $ret = $self->{_backend}->get_typedef_lookup();


    my $typedef_lookup = {};

    for ( my $i=0; $i < scalar(@{$ret}); $i++ ) {

	$typedef_lookup->{$ret->[$i][0]}->{'cvterm_id'} = $ret->[$i][1];
	
    }


    return $typedef_lookup;
}

#--------------------------------------------------------------------------------------------------------------------------------
# synonym_terms_lookup()
#
# Returns synonym terms to cvterm_id lookup
#
# Synonym terms are 'synonym', 'related_synonym', 'exact_synonym', 'narrow_synonym', 'broad_synonym'.
#
#--------------------------------------------------------------------------------------------------------------------------------
sub synonym_terms_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'synonym_terms_lookup'} = $self->{_backend}->get_synonym_terms_lookup();

}

#--------------------------------------------------------------------------------------------------------------------------------
# cvtermprop_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub cvtermprop_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cvtermprop_id_lookup'} = $self->{_backend}->get_cvtermprop_id_lookup();
}


#--------------------------------------------------------------------------------------------------------------------------------
# dbxrefprop_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub dbxrefprop_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'dbxrefprop_id_lookup'} = $self->{_backend}->get_dbxrefprop_id_lookup();
}



#--------------------------------------------------------------------------------------------------------------------------------
# cvterm_relationship_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub cvterm_relationship_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cvterm_relationship_id_lookup'} = $self->{_backend}->get_cvterm_relationship_id_lookup();
}


#--------------------------------------------------------------------------------------------------------------------------------
# cvterm_dbxref_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub cvterm_dbxref_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cvterm_dbxref_id_lookup'} = $self->{_backend}->get_cvterm_dbxref_id_lookup();
}



#--------------------------------------------------------------------------------------------------------------------------------
# cvtermsynonym_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub cvtermsynonym_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cvtermsynonym_id_lookup'} = $self->{_backend}->get_cvtermsynonym_id_lookup();
}


#--------------------------------------------------------------------------------------------------------------------------------
# feature_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub feature_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'feature_id_lookup'} = $self->{_backend}->get_feature_id_lookup();
}


#--------------------------------------------------------------------------------------------------------------------------------
# featureloc_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub featureloc_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'featureloc_id_lookup'} = $self->{_backend}->get_featureloc_id_lookup();
}

##-----------------------------------------------------
## featurelocIdLookup()
##
##-----------------------------------------------------
sub featurelocIdLookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'featurelocIdLookup'} = $self->{_backend}->getFeaturelocIdLookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# feature_pub_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub feature_pub_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'feature_pub_id_lookup'} = $self->{_backend}->get_feature_pub_id_lookup();
}


#--------------------------------------------------------------------------------------------------------------------------------
# feature_dbxref_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub feature_dbxref_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'feature_dbxref_id_lookup'} = $self->{_backend}->get_feature_dbxref_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# feature_relationship_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub feature_relationship_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'feature_relationship_id_lookup'} = $self->{_backend}->get_feature_relationship_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# feature_relationship_pub_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub feature_relationship_pub_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'feature_relationship_pub_id_lookup'} = $self->{_backend}->get_feature_relationship_pub_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# feature_relationshipprop_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub feature_relationshipprop_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'feature_relationshipprop_id_lookup'} = $self->{_backend}->get_feature_relationshipprop_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# feature_relprop_pub_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub feature_relprop_pub_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'feature_relprop_pub_id_lookup'} =  $self->{_backend}->get_feature_relprop_pub_id_lookup();
}


#------------------------------------------------
# featurepropIdLookup()
#
#------------------------------------------------
sub featurepropIdLookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'featurepropIdLookup'} = $self->{_backend}->getFeaturepropIdLookup();
}

#------------------------------------------------
# featurepropMaxRankLookup()
#
#------------------------------------------------
sub featurepropMaxRankLookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'featurepropMaxRankLookup'} = $self->{_backend}->getFeaturepropMaxRankLookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# featureprop_pub_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub featureprop_pub_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'featureprop_pub_id_lookup'} = $self->{_backend}->get_featureprop_pub_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# feature_cvterm_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub feature_cvterm_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'feature_cvterm_id_lookup'} = $self->{_backend}->get_feature_cvterm_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# feature_cvtermprop_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub feature_cvtermprop_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'feature_cvtermprop_id_lookup'} = $self->{_backend}->get_feature_cvtermprop_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# feature_cvterm_dbxref_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub feature_cvterm_dbxref_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'feature_cvterm_dbxref_id_lookup'} = $self->{_backend}->get_feature_cvterm_dbxref_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# feature_cvterm_pub_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub feature_cvterm_pub_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'feature_cvterm_pub_id_lookup'} = $self->{_backend}->get_feature_cvterm_pub_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# synonym_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub synonym_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'synonym_id_lookup'} = $self->{_backend}->get_synonym_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# feature_synonym_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub feature_synonym_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'feature_synonym_id_lookup'} = $self->{_backend}->get_feature_synonym_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# phylotree_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub phylotree_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'phylotree_id_lookup'} = $self->{_backend}->get_phylotree_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# phylotree_pub_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub phylotree_pub_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'phylotree_pub_id_lookup'} = $self->{_backend}->get_phylotree_pub_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# phylonode_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub phylonode_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'phylonode_id_lookup'} = $self->{_backend}->get_phylonode_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# phylonode_dbxref_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub phylonode_dbxref_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'phylonode_dbxref_id_lookup'} = $self->{_backend}->get_phylonode_dbxref_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# phylonode_pub_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub phylonode_pub_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'phylonode_pub_id_lookup'} = $self->{_backend}->get_phylonode_pub_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# phylonode_organism_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub phylonode_organism_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'phylonode_organism_id_lookup'} = $self->{_backend}->get_phylonode_organism_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# phylonodeprop_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub phylonodeprop_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'phylonodeprop_id_lookup'} = $self->{_backend}->get_phylonodeprop_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# phylonode_relationship_id_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub phylonode_relationship_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'phylonode_relationship_id_lookup'} = $self->{_backend}->get_phylonode_relationship_id_lookup();
}

#--------------------------------------------------------------------------------------------------------------------------------
# evidence_codes_lookup()
#
#--------------------------------------------------------------------------------------------------------------------------------
sub evidence_codes_lookup {

    my($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    $self->{'evidence_codes_lookup'} = $self->{_backend}->get_evidence_codes_lookup();

}

#--------------------------------------------------------------------------------------------
# store_bsml_seq_pair_alignment_component()
#
#--------------------------------------------------------------------------------------------
sub store_bsml_seq_pair_alignment_component {

    my ($self, %param) = @_;

    $self->{_logger}->debug("Entered store_bsml_seq_pair_alignment_component") if $self->{_logger}->is_debug();
    
    my $phash = \%param;
    
    my $warn_flag = 0;
    
    my ($refseq, $compseq, $analysis_id, $class, $ref_fmin, $ref_fmax, $comp_fmin, $comp_fmax, $date, $attributes);


    if ((exists $phash->{'class'}) and (defined($phash->{'class'}))){
	$class = $phash->{'class'};
    }
    else {
	$self->{_logger}->logdie("class was not defined");
    }

    if ((exists $phash->{'refseq'}) and (defined($phash->{'refseq'}))){
	$refseq = $phash->{'refseq'};
    }
    else {
	$self->{_logger}->logdie("refseq was not defined");
    }

    if ((exists $phash->{'compseq'}) and (defined($phash->{'compseq'}))){
	$compseq = $phash->{'compseq'};
    }
    else {
	$self->{_logger}->logdie("compseq was not defined");
    }

    if ( exists $phash->{'exclude_classes_lookup'}->{$class} ){
	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->debug("Excluding Seq-pair-alignment match feature with type '$class' ".
				    "for refseq '$refseq' compseq '$compseq'");
	}
	return;
    }


    if ((exists $phash->{'analysis_id'}) and (defined($phash->{'analysis_id'}))){
	$analysis_id = $phash->{'analysis_id'};
    }
    else {
	$self->{_logger}->logdie("analysis_id was not defined");
    }


    if ((exists $phash->{'ref_fmin'}) and (defined($phash->{'ref_fmin'}))){
	$ref_fmin = $phash->{'ref_fmin'};
    }
    else {
	$self->{_logger}->logdie("ref_fmin was not defined");
    }


    if ((exists $phash->{'ref_fmax'}) and (defined($phash->{'ref_fmax'}))){
	$ref_fmax = $phash->{'ref_fmax'};
    }
    else {
	$self->{_logger}->logdie("ref_fmax was not defined");
    }



    if ((exists $phash->{'comp_fmin'}) and (defined($phash->{'comp_fmin'}))){
	$comp_fmin = $phash->{'comp_fmin'};
    }
    else {
	$self->{_logger}->logdie("comp_fmin was not defined");
    }
    if ((exists $phash->{'comp_fmax'}) and (defined($phash->{'comp_fmax'}))){
	$comp_fmax = $phash->{'comp_fmax'};
    }
    else {
	$self->{_logger}->logdie("comp_fmax was not defined");
    }


    if ((exists $phash->{'attributes'}) and (defined($phash->{'attributes'}))){
	$attributes = $phash->{'attributes'};
    }
    else {
	$self->{_logger}->logdie("attributes was not defined");
    }



    #--------------------------------------------------------------------------------------------
    # feature_id lookups
    #
    my ($feature_id_lookup, $feature_id_lookup_d);

    if ((exists $phash->{'feature_id_lookup'}) and (defined($phash->{'feature_id_lookup'}))){
	$feature_id_lookup = $phash->{'feature_id_lookup'};
    }
    else {
	$self->{_logger}->logdie("feature_id_lookup was not defined");
    }
    if ((exists $phash->{'feature_id_lookup_d'}) and (defined($phash->{'feature_id_lookup_d'}))){
	$feature_id_lookup_d = $phash->{'feature_id_lookup_d'};
    }
    else {
	$self->{_logger}->logdie("feature_id_lookup_d was not defined");
    }

    #--------------------------------------------------------------------------------------------
    # organism_id for genus 'not known' species 'not known'
    #
    my ($organism_id_unknown);

    if ((exists $phash->{'unknown_organism_id'}) and (defined($phash->{'unknown_organism_id'}))){
	$organism_id_unknown = $phash->{'unknown_organism_id'};
    }
    else {
	$self->{_logger}->logdie("unknown_organism_id was not defined");
    }



    #--------------------------------------------------------------------------------------------
    # date
    #
    if ((exists $phash->{'date'}) and (defined($phash->{'date'}))){
	$date = $phash->{'date'};
    }
    else {
	$self->{_logger}->logdie("date was not defined");
    }

    #--------------------------------------------------------------------------------------------
    # sequence lookup
    #
    my $sequence_lookup;

    if ((exists $phash->{'sequence_lookup'}) and (defined($phash->{'sequence_lookup'}))){
	$sequence_lookup = $phash->{'sequence_lookup'};
    }
    else {
	$self->{_logger}->logdie("sequence_lookup was not defined");
    }






    #------------------------------------------------------------------------------------------------------------------------
    # Retrieve the organism_id associate to the reference sequence/feature
    #

    my $organism_id_query;

    if ((exists $feature_id_lookup->{$refseq}->[1]) and (defined($feature_id_lookup->{$refseq}->[1]))){
	#
	# Check the static feature_id_lookup
	#
	$organism_id_query = $feature_id_lookup->{$refseq}->[1];
    }
    elsif ((exists $feature_id_lookup_d->{$refseq}->{'organism_id'}) and (defined($feature_id_lookup_d->{$refseq}->{'organism_id'}))){
	#
	# Check the non-static feature_id_lookup_d
	#
	$organism_id_query = $feature_id_lookup_d->{$refseq}->{'organism_id'};
    }
    elsif ((exists $feature_id_lookup->{$sequence_lookup->{$refseq}->{'feature_uniquename'}}->[1]) and (defined($feature_id_lookup->{$sequence_lookup->{$refseq}->{'feature_uniquename'}}->[1]))){
	#
	# Retrieve the organism_id of the refseq's corresponding sequence
	#
	$organism_id_query = $feature_id_lookup->{$sequence_lookup->{$refseq}->{'feature_uniquename'}}->[1];
    }
    else {
	#
	# Could not find any organism_id in the lookups
	#
	$organism_id_query = $organism_id_unknown;
    }
    #
    #------------------------------------------------------------------------------------------------------------------------


	   


    #------------------------------------------------------------------------------------------------------------------------
    # Retrieve the cvterm_id for the match feature to be stored in chado.feature.type_id
    #
    my $match_cvterm_id = $self->check_cvterm_id_by_class_lookup( class => $class);
    
    $self->{_logger}->logdie("Could not retrieve cvterm_id from cvterm_id_by_name_lookup for name '$class'") if (!defined($match_cvterm_id));
    #
    #------------------------------------------------------------------------------------------------------------------------



    #----------------------------------------------------------------------------------------------
    # Prepare data to be inserted into chado.feature table
    #
    #----------------------------------------------------------------------------------------------
   
    my $uniquename = $self->{_id_generator}->next_id( type    => $class,
						      project => $self->{_db} );
    
    my $feature_id = $self->{_backend}->do_store_new_feature(
							     dbxref_id        => undef,
							     organism_id      => $organism_id_query,
							     name             => undef,
							     uniquename       => $uniquename,
							     residues         => undef,
							     seqlen           => undef,
							     md5checksum      => undef,
							     type_id          => $match_cvterm_id,
							     is_analysis      => 1,
							     is_obsolete      => 0,
							     timeaccessioned  => $date,
							     timelastmodified => $date
							     );


    $self->{_logger}->logdie("feature_id was not defined.  Could create alignment feature record for refseq '$refseq' compseq '$compseq'.") if (!defined($feature_id));

    ## BSML Attributes associated with the Seq-pair-alignment elements need to be loaded into chado.featureprop.
    if (defined($attributes)){
	
	foreach my $key (sort keys %{$attributes} ) {
	    
	    if (( exists $attributes->{$key}) && 
		( defined($attributes->{$key})) &&
		( scalar(@{$attributes->{$key}}) > 0 )) {
		
		my $type_id = $self->check_property_types_lookup( name => $key );
		
		if (defined($type_id)){

		    foreach my $value ( @{$attributes->{$key}}) {

			$self->prepareFeaturepropRecord($feature_id, $type_id, $value);
			
		    }
		}
		else {
		    $self->{_logger}->logdie("type_id was not defined for cvterm.name '$key'");
		}
	    }
	}
    }
    #
    #----------------------------------------------------------------------------------------------------------------------------


    #----------------------------------------------------------------------------------------------
    # Prepare data to be inserted into chado.analysisfeature table 
    #
    #----------------------------------------------------------------------------------------------
    my $analysisfeature_id = $self->check_analysisfeature_id_lookup( feature_id  => $feature_id, analysis_id => $analysis_id );
    if (!defined($analysisfeature_id)){
	#
	# Store the feature_id analysis_id tuple in table chado.analysisfeature now!
	#
	my $type_id = $self->check_cvterm_id_by_name_lookup( name => 'computed_by'); # computed_by
	
	$analysisfeature_id = $self->{_backend}->do_store_new_analysisfeature(
									      analysis_id  => $analysis_id,
									      feature_id   => $feature_id,
									      normscore    => undef,
									      rawscore     => undef,
									      significance => undef,
									      pidentity    => undef,
									      type_id      => $type_id
									      );
	
	$self->{_logger}->fatal("analysisfeature_id was not defined.  Could not create an alignment analysisfeature record for refseq '$refseq' compseq '$compseq' analysis_id '$analysis_id' feature_id '$feature_id'") if (!defined($analysisfeature_id));
	
    }

    {
	#-----------------------------------------------------------------------------------------------------------------------------
	# Prepare to store a record in table chado.featureloc to represent the localization of the
	# alignment feature to the reference sequence (refseq).
	#


	#------------------------------------------------------------------------------------------------------------------------------
	# Retieve the feature_id of the refseq

	my $srcfeature_id;

	if ((exists $feature_id_lookup->{$refseq}->[0]) and (defined($feature_id_lookup->{$refseq}->[0]))){
	    #
	    # Check the static feature_id_lookup
	    #
	    $srcfeature_id = $feature_id_lookup->{$refseq}->[0];
	}
	elsif ((exists $feature_id_lookup_d->{$refseq}->{'feature_id'}) and (defined($feature_id_lookup_d->{$refseq}->{'feature_id'}))){
	    #
	    # Check the non-static feature_id_lookup_d
	    #
	    $srcfeature_id = $feature_id_lookup_d->{$refseq}->{'feature_id'};
	}
	elsif ((exists $feature_id_lookup->{$sequence_lookup->{$refseq}->{'feature_uniquename'}}->[0]) and (defined($feature_id_lookup->{$sequence_lookup->{$refseq}->{'feature_uniquename'}}->[0]))){
	    #
	    # Check the static feature_id_lookup using the reference sequence's uniquename
	    #
	    $srcfeature_id = $feature_id_lookup->{$sequence_lookup->{$refseq}->{'feature_uniquename'}}->[0];
	}
	else {	    
	    #
	    # Could not find the feature_id anywhere!
	    #
	    $self->{_logger}->fatal("static feature_id_lookup" . Dumper $feature_id_lookup . "\ndynamic feature_id_lookup_d" . Dumper $feature_id_lookup_d);
	    $self->{_logger}->logdie("Could not find the feature_id for refseq '$refseq' in any of the lookups");
	}
	#
	#------------------------------------------------------------------------------------------------------------------------------
	
	$self->prepareFeaturelocRecord($feature_id, $srcfeature_id, 0, 1, $ref_fmin, $ref_fmax, 0);
    }
    


    {
	#----------------------------------------------------------------------------------------------
	# Prepare to store a record in table chado.featureloc to represent the localization of the
	# alignment feature to the match sequence (compseq)



	#------------------------------------------------------------------------------------------------------------------------------
	# Retieve the feature_id of the compseq

	my $srcfeature_id;

	if ((exists $feature_id_lookup->{$compseq}->[0]) and (defined($feature_id_lookup->{$compseq}->[0]))){
	    #
	    # Check the static feature_id_lookup
	    #
	    $srcfeature_id = $feature_id_lookup->{$compseq}->[0];
	}
	elsif ((exists $feature_id_lookup_d->{$compseq}->{'feature_id'}) and (defined($feature_id_lookup_d->{$compseq}->{'feature_id'}))){
	    #
	    # Check the non-static feature_id_lookup_d
	    #
	    $srcfeature_id = $feature_id_lookup_d->{$compseq}->{'feature_id'};
	}
	elsif ((exists $feature_id_lookup->{$sequence_lookup->{$compseq}->{'feature_uniquename'}}->[0]) and (defined($feature_id_lookup->{$sequence_lookup->{$compseq}->{'feature_uniquename'}}->[0]))){
	    #
	    # Check the static feature_id_lookup using the reference sequence's uniquename
	    #
	    $srcfeature_id = $feature_id_lookup->{$sequence_lookup->{$compseq}->{'feature_uniquename'}}->[0];
	}
	else {	    
	    #
	    # Could not find the feature_id anywhere!
	    #
	    $self->{_logger}->fatal("static feature_id_lookup" . Dumper $feature_id_lookup . "\ndynamic feature_id_lookup_d" . Dumper $feature_id_lookup_d);
	    $self->{_logger}->logdie("Could not find the feature_id for compseq '$compseq' in any of the lookups");
	}
	#
	#------------------------------------------------------------------------------------------------------------------------------

	$self->prepareFeaturelocRecord($feature_id, $srcfeature_id, 0, 0, $comp_fmin, $comp_fmax, 0);
    }
    


    $self->{_logger}->warn("Warning flag detected phash contents:\n" . Dumper($phash)) if ($warn_flag > 0);


    return ($feature_id);

    
}#end sub store_bsml_seq_pair_alignment_component()






sub check_cv_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_cv_id_lookup") if $self->{_logger}->is_debug();



    #-------------------------------------
    # cv_id_lookup
    #
    my $cv_id_lookup;

    if (( exists $self->{'cv_id_lookup'}) && (defined($self->{'cv_id_lookup'}) )) {

	$cv_id_lookup = $self->{'cv_id_lookup'};
    }
    else {
	$self->{_logger}->logdie("cv_id_lookup was not defined");
    }

    #-------------------------------------
    # name
    #
    my $name;

    if (( exists $param{'name'}) && (defined($param{'name'}))) {
	$name = $param{'name'};
    }
    else {
	$self->{_logger}->logdie("name was not defined");
    }


    #-------------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $cv_id;

    if (( exists $cv_id_lookup->{$name}->[0]) && (defined($cv_id_lookup->{$name}->[0]))){
	#
	# 
	#	
	$cv_id = $cv_id_lookup->{$name}->[0];

	$self->{_logger}->warn("cv_id '$cv_id' was stored in table cv during a previous session for name '$name'") if ($status eq 'warn');
    }

    return $cv_id;

}

sub check_cvterm_relationship_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_cvterm_relationship_id_lookup") if $self->{_logger}->is_debug();

    my $cvterm_relationship_id_lookup;

    if (( exists $self->{'cvterm_relationship_id_lookup'}) && (defined($self->{'cvterm_relationship_id_lookup'}) )) {

	$cvterm_relationship_id_lookup = $self->{'cvterm_relationship_id_lookup'};
    }
    else {
	return;

	$self->{_logger}->logdie("cvterm_relationship_id_lookup was not defined");
    }


    #-------------------------------------
    # type_id
    #
    my $type_id;

    if (( exists $param{'type_id'}) && (defined($param{'type_id'}))) {
	$type_id = $param{'type_id'};
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }

    #-------------------------------------
    # subject_id
    #
    my $subject_id;

    if (( exists $param{'subject_id'}) && (defined($param{'subject_id'}))) {
	$subject_id = $param{'subject_id'};
    }
    else {
	$self->{_logger}->logdie("subject_id was not defined");
    }

    #-------------------------------------
    # object_id
    #
    my $object_id;

    if (( exists $param{'object_id'}) && (defined($param{'object_id'}))) {
	$object_id = $param{'object_id'};
    }
    else {
	$self->{_logger}->logdie("object_id was not defined");
    }

    #------------------------------------
    # status
    #
    
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $cvterm_relationship_id;

    my $index = $type_id . '_' . $subject_id . '_' . $object_id;


    if (( exists $cvterm_relationship_id_lookup->{$index}->[0]) && (defined($cvterm_relationship_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$cvterm_relationship_id = $cvterm_relationship_id_lookup->{$index}->[0];

	$self->{_logger}->warn("cvterm_relationship_id '$cvterm_relationship_id' was stored in table cvterm_relationship during a previous session for type_id '$type_id' subject_id '$subject_id' object_id '$object_id'") if ($status eq 'warn');
    }

    return $cvterm_relationship_id;

}



sub check_cvtermpath_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_cvtermpath_id_lookup") if $self->{_logger}->is_debug();

    my $cvtermpath_id_lookup;

    if (( exists $self->{'cvtermpath_id_lookup'}) && (defined($self->{'cvtermpath_id_lookup'}) )) {

	$cvtermpath_id_lookup = $self->{'cvtermpath_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("cvtermpath_id_lookup was not defined");
    }



    #-------------------------------------
    # subject_id
    #
    my $subject_id;

    if (( exists $param{'subject_id'}) && (defined($param{'subject_id'}))) {
	$subject_id = $param{'subject_id'};
    }
    else {
	$self->{_logger}->logdie("subject_id was not defined");
    }

    #-------------------------------------
    # object_id
    #
    my $object_id;

    if (( exists $param{'object_id'}) && (defined($param{'object_id'}))) {
	$object_id = $param{'object_id'};
    }
    else {
	$self->{_logger}->logdie("object_id was not defined");
    }

    #-------------------------------------
    # type_id
    #
    my $type_id;

    if (( exists $param{'type_id'}) && (defined($param{'type_id'}))) {
	$type_id = $param{'type_id'};
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }

    #-------------------------------------
    # pathdistance
    #
    my $pathdistance;

    if (( exists $param{'pathdistance'}) && (defined($param{'pathdistance'}))) {
	$pathdistance = $param{'pathdistance'};
    }
    else {
	$self->{_logger}->logdie("pathdistance was not defined");
    }


    #------------------------------------
    # status
    #
    
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $cvtermpath_id;

    my $index = $subject_id . '_' . $object_id . '_' . $type_id . '_' . $pathdistance;


    if (( exists $cvtermpath_id_lookup->{$index}->[0]) && (defined($cvtermpath_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$cvtermpath_id = $cvtermpath_id_lookup->{$index}->[0];

	$self->{_logger}->warn("cvtermpath_id '$cvtermpath_id' was stored in table cvtermpath during a previous session for subject_id '$subject_id' object_id '$object_id' type_id '$type_id' pathdistance '$pathdistance'") if ($status eq 'warn');
    }

    return $cvtermpath_id;

}


sub check_cvtermsynonym_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_cvtermsynonym_id_lookup") if $self->{_logger}->is_debug();

    my $cvtermsynonym_id_lookup;

    if (( exists $self->{'cvtermsynonym_id_lookup'}) && (defined($self->{'cvtermsynonym_id_lookup'}) )) {

	$cvtermsynonym_id_lookup = $self->{'cvtermsynonym_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("cvtermsynonym_id_lookup was not defined");
    }



    #-------------------------------------
    # cvterm_id
    #
    my $cvterm_id;

    if (( exists $param{'cvterm_id'}) && (defined($param{'cvterm_id'}))) {
	$cvterm_id = $param{'cvterm_id'};
    }
    else {
	$self->{_logger}->logdie("cvterm_id was not defined");
    }

    #-------------------------------------
    # synonym
    #
    my $synonym;

    if (( exists $param{'synonym'}) && (defined($param{'synonym'}))) {
	$synonym = $param{'synonym'};
    }
    else {
	$self->{_logger}->logdie("synonym was not defined");
    }

    #------------------------------------
    # status
    #
    
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $cvtermsynonym_id;

    my $index = $cvterm_id . '_' . $synonym;


    if (( exists $cvtermsynonym_id_lookup->{$index}->[0]) && (defined($cvtermsynonym_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$cvtermsynonym_id = $cvtermsynonym_id_lookup->{$index}->[0];

	$self->{_logger}->warn("cvtermsynonym_id '$cvtermsynonym_id' was stored in table cvtermsynonym during a previous session for cvterm_id '$cvterm_id' synonym '$synonym'") if ($status eq 'warn');
    }

    return $cvtermsynonym_id;

}


sub check_cvterm_dbxref_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_cvterm_dbxref_id_lookup") if $self->{_logger}->is_debug();

    my $cvterm_dbxref_id_lookup;

    if (( exists $self->{'cvterm_dbxref_id_lookup'}) && (defined($self->{'cvterm_dbxref_id_lookup'}) )) {

	$cvterm_dbxref_id_lookup = $self->{'cvterm_dbxref_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("cvterm_dbxref_id_lookup was not defined");
    }



    #-------------------------------------
    # cvterm_id
    #
    my $cvterm_id;

    if (( exists $param{'cvterm_id'}) && (defined($param{'cvterm_id'}))) {
	$cvterm_id = $param{'cvterm_id'};
    }
    else {
	$self->{_logger}->logdie("cvterm_id was not defined");
    }

    #-------------------------------------
    # dbxref_id
    #
    my $dbxref_id;

    if (( exists $param{'dbxref_id'}) && (defined($param{'dbxref_id'}))) {
	$dbxref_id = $param{'dbxref_id'};
    }
    else {
	$self->{_logger}->logdie("dbxref_id was not defined");
    }

    #------------------------------------
    # status
    #
    
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $cvterm_dbxref_id;

    my $index = $cvterm_id . '_' . $dbxref_id;


    if (( exists $cvterm_dbxref_id_lookup->{$index}->[0]) && (defined($cvterm_dbxref_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$cvterm_dbxref_id = $cvterm_dbxref_id_lookup->{$index}->[0];

	$self->{_logger}->warn("cvterm_dbxref_id '$cvterm_dbxref_id' was stored in table cvterm_dbxref during a previous session for cvterm_id '$cvterm_id' dbxref '$dbxref_id'") if ($status eq 'warn');
    }

    return $cvterm_dbxref_id;

}



sub check_cvtermprop_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_cvtermprop_id_lookup") if $self->{_logger}->is_debug();

    my $cvtermprop_id_lookup;

    if (( exists $self->{'cvtermprop_id_lookup'}) && (defined($self->{'cvtermprop_id_lookup'}) )) {

	$cvtermprop_id_lookup = $self->{'cvtermprop_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("cvtermprop_id_lookup was not defined");
    }



    #-------------------------------------
    # cvterm_id
    #
    my $cvterm_id;

    if (( exists $param{'cvterm_id'}) && (defined($param{'cvterm_id'}))) {
	$cvterm_id = $param{'cvterm_id'};
    }
    else {
	$self->{_logger}->logdie("cvterm_id was not defined");
    }

    #-------------------------------------
    # type_id
    #
    my $type_id;

    if (( exists $param{'type_id'}) && (defined($param{'type_id'}))) {
	$type_id = $param{'type_id'};
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }

    #-------------------------------------
    # rank
    #
    my $rank;

    if (( exists $param{'rank'}) && (defined($param{'rank'}))) {
	$rank = $param{'rank'};
    }
    else {
	$self->{_logger}->logdie("rank was not defined");
    }



    #------------------------------------
    # status
    #
    
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $cvtermprop_id;

    my $index = $cvterm_id . '_' . $type_id . '_' . $rank;


    if (( exists $cvtermprop_id_lookup->{$index}->[0]) && (defined($cvtermprop_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$cvtermprop_id = $cvtermprop_id_lookup->{$index}->[0];

	$self->{_logger}->warn("cvtermprop_id '$cvtermprop_id' was stored in table cvtermprop during a previous session for cvterm_id '$cvterm_id' type_id '$type_id' rank '$rank'") if ($status eq 'warn');
    }

    return $cvtermprop_id;

} # sub check_cvtermprop_id_lookup



sub check_dbxrefprop_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_dbxrefprop_id_lookup") if $self->{_logger}->is_debug();

    my $dbxrefprop_id_lookup;

    if (( exists $self->{'dbxrefprop_id_lookup'}) && (defined($self->{'dbxrefprop_id_lookup'}) )) {

	$dbxrefprop_id_lookup = $self->{'dbxrefprop_id_lookup'};
    }
    else {
	$self->{_logger}->logdie("dbxrefprop_id_lookup was not defined");
    }



    #-------------------------------------
    # dbxref_id
    #
    my $dbxref_id;

    if (( exists $param{'dbxref_id'}) && (defined($param{'dbxref_id'}))) {
	$dbxref_id = $param{'dbxref_id'};
    }
    else {
	$self->{_logger}->logdie("dbxref_id was not defined");
    }

    #-------------------------------------
    # type_id
    #
    my $type_id;

    if (( exists $param{'type_id'}) && (defined($param{'type_id'}))) {
	$type_id = $param{'type_id'};
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }

    #-------------------------------------
    # value
    #
    my $value;

    if (( exists $param{'value'}) && (defined($param{'value'}))) {
	$value = $param{'value'};
    }
    else {
	$self->{_logger}->logdie("value was not defined");
    }

    #-------------------------------------
    # rank
    #
    my $rank;

    if (( exists $param{'rank'}) && (defined($param{'rank'}))) {
	$rank = $param{'rank'};
    }
    else {
	$self->{_logger}->logdie("rank was not defined");
    }

    #------------------------------------
    # status
    #
    
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $dbxrefprop_id;

    my $index = $dbxref_id . '_' . $type_id . '_' . $value . '_' . $rank;


    if ( exists $dbxrefprop_id_lookup->{$index} ){
	if (defined($dbxrefprop_id_lookup->{$index}->[0])){

	    $dbxrefprop_id = $dbxrefprop_id_lookup->{$index}->[0];

	    if ($status eq 'warn'){
		$self->{_logger}->warn("dbxrefprop_id '$dbxrefprop_id' was stored in table dbxrefprop during a previous ".
				       "session for dbxref_id '$dbxref_id' type_id '$type_id' value '$value' rank '$rank'");
	    }
	}
    }

    return $dbxrefprop_id;

}



sub check_pub_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_pub_id_lookup") if $self->{_logger}->is_debug();

    my $pub_id_lookup;

    if (( exists $self->{'pub_id_lookup'}) && (defined($self->{'pub_id_lookup'}) )) {

	$pub_id_lookup = $self->{'pub_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("pub_id_lookup was not defined");
    }



    #-------------------------------------
    # uniquename
    #
    my $uniquename;

    if (( exists $param{'uniquename'}) && (defined($param{'uniquename'}))) {
	$uniquename = $param{'uniquename'};
    }
    else {
	$self->{_logger}->logdie("uniquename was not defined");
    }

    #-------------------------------------
    # type_id
    #
    my $type_id;

    if (( exists $param{'type_id'}) && (defined($param{'type_id'}))) {
	$type_id = $param{'type_id'};
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }


    #------------------------------------
    # status
    #
    
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $pub_id;

    my $index = $uniquename . '_' . $type_id;


    if (( exists $pub_id_lookup->{$index}->[0]) && (defined($pub_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$pub_id = $pub_id_lookup->{$index}->[0];

	$self->{_logger}->warn("pub_id '$pub_id' was stored in table pub during a previous session for uniquename '$uniquename' type_id '$type_id'") if ($status eq 'warn');
    }

    return $pub_id;

} # sub check_pub_id_lookup




sub check_pub_relationship_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_pub_relationship_id_lookup") if $self->{_logger}->is_debug();

    my $pub_relationship_id_lookup;

    if (( exists $self->{'pub_relationship_id_lookup'}) && (defined($self->{'pub_relationship_id_lookup'}) )) {

	$pub_relationship_id_lookup = $self->{'pub_relationship_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("pub_relationship_id_lookup was not defined");
    }



    #-------------------------------------
    # subject_id
    #
    my $subject_id;

    if (( exists $param{'subject_id'}) && (defined($param{'subject_id'}))) {
	$subject_id = $param{'subject_id'};
    }
    else {
	$self->{_logger}->logdie("subject_id was not defined");
    }


    #-------------------------------------
    # object_id
    #
    my $object_id;

    if (( exists $param{'object_id'}) && (defined($param{'object_id'}))) {
	$object_id = $param{'object_id'};
    }
    else {
	$self->{_logger}->logdie("object_id was not defined");
    }

    #-------------------------------------
    # type_id
    #
    my $type_id;

    if (( exists $param{'type_id'}) && (defined($param{'type_id'}))) {
	$type_id = $param{'type_id'};
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }


    #------------------------------------
    # status
    #
    
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $pub_relationship_id;

    my $index = $subject_id . '_' . $object_id . '_' . $type_id;


    if (( exists $pub_relationship_id_lookup->{$index}->[0]) && (defined($pub_relationship_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$pub_relationship_id = $pub_relationship_id_lookup->{$index}->[0];

	$self->{_logger}->warn("pub_relationship_id '$pub_relationship_id' was stored in table pub during a previous session for subject_id '$subject_id' object_id '$object_id' type_id '$type_id'") if ($status eq 'warn');
    }

    return $pub_relationship_id;

} # sub check_pub_relationship_id_lookup




sub check_pub_dbxref_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_pub_dbxref_id_lookup") if $self->{_logger}->is_debug();

    my $pub_dbxref_id_lookup;

    if (( exists $self->{'pub_dbxref_id_lookup'}) && (defined($self->{'pub_dbxref_id_lookup'}) )) {

	$pub_dbxref_id_lookup = $self->{'pub_dbxref_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("pub_dbxref_id_lookup was not defined");
    }



    #-------------------------------------
    # pub_id
    #
    my $pub_id;

    if (( exists $param{'pub_id'}) && (defined($param{'pub_id'}))) {
	$pub_id = $param{'pub_id'};
    }
    else {
	$self->{_logger}->logdie("pub_id was not defined");
    }


    #-------------------------------------
    # dbxref_id
    #
    my $dbxref_id;

    if (( exists $param{'dbxref_id'}) && (defined($param{'dbxref_id'}))) {
	$dbxref_id = $param{'dbxref_id'};
    }
    else {
	$self->{_logger}->logdie("dbxref_id was not defined");
    }



    #------------------------------------
    # status
    #
    
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $pub_dbxref_id;

    my $index = $pub_id . '_' . $dbxref_id;


    if (( exists $pub_dbxref_id_lookup->{$index}->[0]) && (defined($pub_dbxref_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$pub_dbxref_id = $pub_dbxref_id_lookup->{$index}->[0];

	$self->{_logger}->warn("pub_dbxref_id '$pub_dbxref_id' was stored in table pub during a previous session for pub_id '$pub_id' dbxref_id '$dbxref_id'") if ($status eq 'warn');
    }

    return $pub_dbxref_id;

} # sub check_pub_dbxref_id_lookup



sub check_pubauthor_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_pubauthor_id_lookup") if $self->{_logger}->is_debug();

    my $pubauthor_id_lookup;

    if (( exists $self->{'pubauthor_id_lookup'}) && (defined($self->{'pubauthor_id_lookup'}) )) {

	$pubauthor_id_lookup = $self->{'pubauthor_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("pubauthor_id_lookup was not defined");
    }



    #-------------------------------------
    # pub_id
    #
    my $pub_id;

    if (( exists $param{'pub_id'}) && (defined($param{'pub_id'}))) {
	$pub_id = $param{'pub_id'};
    }
    else {
	$self->{_logger}->logdie("pub_id was not defined");
    }


    #-------------------------------------
    # rank
    #
    my $rank;

    if (( exists $param{'rank'}) && (defined($param{'rank'}))) {
	$rank = $param{'rank'};
    }
    else {
	$self->{_logger}->logdie("rank was not defined");
    }



    #------------------------------------
    # status
    #
    
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $pubauthor_id;

    my $index = $pub_id . '_' . $rank;


    if (( exists $pubauthor_id_lookup->{$index}->[0]) && (defined($pubauthor_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$pubauthor_id = $pubauthor_id_lookup->{$index}->[0];

	$self->{_logger}->warn("pubauthor_id '$pubauthor_id' was stored in table pub during a previous session for pub_id '$pub_id' rank '$rank'") if ($status eq 'warn');
    }

    return $pubauthor_id;

} # sub check_pubauthor_id_lookup



sub check_pubprop_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_pubprop_id_lookup") if $self->{_logger}->is_debug();

    my $pubprop_id_lookup;

    if (( exists $self->{'pubprop_id_lookup'}) && (defined($self->{'pubprop_id_lookup'}) )) {

	$pubprop_id_lookup = $self->{'pubprop_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("pubprop_id_lookup was not defined");
    }



    #-------------------------------------
    # pub_id
    #
    my $pub_id;

    if (( exists $param{'pub_id'}) && (defined($param{'pub_id'}))) {
	$pub_id = $param{'pub_id'};
    }
    else {
	$self->{_logger}->logdie("pub_id was not defined");
    }


    #-------------------------------------
    # type_id
    #
    my $type_id;

    if (( exists $param{'type_id'}) && (defined($param{'type_id'}))) {
	$type_id = $param{'type_id'};
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }

    #------------------------------------
    # status
    #
    
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $pubprop_id;

    my $index = $pub_id . '_' . $type_id;


    if (( exists $pubprop_id_lookup->{$index}->[0]) && (defined($pubprop_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$pubprop_id = $pubprop_id_lookup->{$index}->[0];

	$self->{_logger}->warn("pubprop_id '$pubprop_id' was stored in table pub during a previous session for pub_id '$pub_id' type_id '$type_id'") if ($status eq 'warn');
    }

    return $pubprop_id;

} # sub check_pubprop_id_lookup


sub check_db_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_db_id_lookup") if $self->{_logger}->is_debug();


    #-----------------------------------
    # db_id_lookup
    #
    my $db_id_lookup;

    if (( exists $self->{'db_id_lookup'}) && (defined($self->{'db_id_lookup'}) )) {

	$db_id_lookup = $self->{'db_id_lookup'};
    }
    else {
	$self->{_logger}->logdie("db_id_lookup was not defined");
    }

    #-----------------------------------
    # name
    #
    my $name;

    if (( exists $param{'name'}) && (defined($param{'name'}))) {
	$name = $param{'name'};
    }
    else {
	$self->{_logger}->logdie("name was not defined");
    }



    #-----------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $db_id;

    if (( exists $db_id_lookup->{$name}->[0]) && (defined($db_id_lookup->{$name}->[0]))){
	#
	# 
	#	
	$db_id = $db_id_lookup->{$name}->[0];

	$self->{_logger}->warn("db_id '$db_id' was stored in table db during a previous session for name '$name'") if ($status eq 'warn');
    }

    return $db_id;

}


sub check_dbxref_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_dbxref_id_lookup") if $self->{_logger}->is_debug();

    my $dbxref_id_lookup;

    if (( exists $self->{'dbxref_id_lookup'}) && (defined($self->{'dbxref_id_lookup'}) )) {

	$dbxref_id_lookup = $self->{'dbxref_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("dbxref_id_lookup was not defined");
    }


    #---------------------------------
    # db_id
    #
    my $db_id;

    if (( exists $param{'db_id'}) && (defined($param{'db_id'}))) {
	$db_id = $param{'db_id'};
    }
    else {
	$self->{_logger}->logdie("db_id was not defined");
    }

    #---------------------------------
    # accession
    #
    my $accession;

    if (( exists $param{'accession'}) && (defined($param{'accession'}))) {
	$accession = $param{'accession'};
    }
    else {
	$self->{_logger}->logdie("accession was not defined");
    }

    #---------------------------------
    # version
    #
    my $version;

    if (( exists $param{'version'}) && (defined($param{'version'}))) {
	$version = $param{'version'};
    }
    else {
	$self->{_logger}->logdie("version was not defined");
    }



    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $dbxref_id;

    my $index = $db_id . '_' . $accession . '_' . $version;

    if (( exists $dbxref_id_lookup->{$index}->[0]) && (defined($dbxref_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$dbxref_id = $dbxref_id_lookup->{$index}->[0];

	$self->{_logger}->warn("dbxref_id '$dbxref_id' was stored in table dbxref during a previous session for db_id '$db_id' accession '$accession' version '$version'") if ($status eq 'warn');
    }

    return $dbxref_id;

}



sub check_organism_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_organism_id_lookup") if $self->{_logger}->is_debug();



    #---------------------------------
    # organism_id_lookup
    #
    my $organism_id_lookup;

    if (( exists $self->{'organism_id_lookup'}) && (defined($self->{'organism_id_lookup'}) )) {

	$organism_id_lookup = $self->{'organism_id_lookup'};
    }
    else {
	$self->{_logger}->logdie("organism_id_lookup was not defined");
    }



    #---------------------------------
    # genus
    #
    my $genus;

    if (( exists $param{'genus'}) && (defined($param{'genus'}))) {
	$genus = $param{'genus'};
    }
    else {
	$self->{_logger}->logdie("genus was not defined");
    }

    #---------------------------------
    # species
    #
    my $species;

    if (( exists $param{'species'}) && (defined($param{'species'}))) {
	$species = $param{'species'};
    }
    else {
	$self->{_logger}->logdie("species was not defined");
    }


    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $organism_id;

    my $index = $genus . '_' . $species;


    if (( exists $organism_id_lookup->{$index}->[0]) && (defined($organism_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$organism_id = $organism_id_lookup->{$index}->[0];

	$self->{_logger}->warn("organism_id '$organism_id' was stored in table organism during a previous session for genus '$genus' species '$species'") if ($status eq 'warn');
    }

    return $organism_id;

}





sub check_organismprop_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_organismprop_id_lookup") if $self->{_logger}->is_debug();

    my $organismprop_id_lookup;

    if (( exists $self->{'organismprop_id_lookup'}) && (defined($self->{'organismprop_id_lookup'}) )) {

	$organismprop_id_lookup = $self->{'organismprop_id_lookup'};
    }
    else {
	$self->{_logger}->logdie("organismprop_id_lookup was not defined");
    }


    #---------------------------------
    # organism_id
    #
    my $organism_id;

    if (( exists $param{'organism_id'}) && (defined($param{'organism_id'}))) {
	$organism_id = $param{'organism_id'};
    }
    else {
	$self->{_logger}->logdie("organism_id was not defined");
    }

    #---------------------------------
    # type_id
    #
    my $type_id;

    if (( exists $param{'type_id'}) && (defined($param{'type_id'}))) {
	$type_id = $param{'type_id'};
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }

    #---------------------------------
    # value
    #
    my $value;

    if (( exists $param{'value'}) && (defined($param{'value'}))) {
	$value = $param{'value'};
    }
    else {
	$self->{_logger}->logdie("value was not defined");
    }

    #---------------------------------
    # rank
    #
    my $rank;

    if (( exists $param{'rank'}) && (defined($param{'rank'}))) {
	$rank = $param{'rank'};
    }
    else {
	$self->{_logger}->logdie("rank was not defined");
    }



    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $organismprop_id;

    my $index = $organism_id . '_' . $type_id . '_' . $value . '_' . $rank;

    if ( exists $organismprop_id_lookup->{$index}) {
	if (defined($organismprop_id_lookup->{$index}->[0])){

	    $organismprop_id = $organismprop_id_lookup->{$index}->[0];

	    if ($status eq 'warn'){
		$self->{_logger}->warn("organismprop_id '$organismprop_id' was stored in table organism during ".
				       "a previous session for organism_id '$organism_id' type_id '$type_id' ".
				       "value '$value' rank '$rank'");
	    }
	}
    }

    return $organismprop_id;

}


sub check_organism_dbxref_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_organism_dbxref_id_lookup") if $self->{_logger}->is_debug();

    my $organism_dbxref_id_lookup;

    if (( exists $self->{'organism_dbxref_id_lookup'}) && (defined($self->{'organism_dbxref_id_lookup'}) )) {

	$organism_dbxref_id_lookup = $self->{'organism_dbxref_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("organism_dbxref_id_lookup was not defined");
    }


    #---------------------------------
    # organism_id
    #
    my $organism_id;

    if (( exists $param{'organism_id'}) && (defined($param{'organism_id'}))) {
	$organism_id = $param{'organism_id'};
    }
    else {
	$self->{_logger}->logdie("organism_id was not defined");
    }

    #---------------------------------
    # dbxref_id
    #
    my $dbxref_id;

    if (( exists $param{'dbxref_id'}) && (defined($param{'dbxref_id'}))) {
	$dbxref_id = $param{'dbxref_id'};
    }
    else {
	$self->{_logger}->logdie("dbxref_id was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $organism_dbxref_id;

    my $index = $organism_id . '_' . $dbxref_id;

    if (( exists $organism_dbxref_id_lookup->{$index}->[0]) && (defined($organism_dbxref_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$organism_dbxref_id = $organism_dbxref_id_lookup->{$index}->[0];

	$self->{_logger}->warn("organism_dbxref_id '$organism_dbxref_id' was stored in table organism during a previous session for organism_id '$organism_id' dbxref_id '$dbxref_id'") if ($status eq 'warn');
    }

    return $organism_dbxref_id;

} # sub check_organism_dbxref_id_lookup



sub check_feature_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_feature_id_lookup") if $self->{_logger}->is_debug();

    my $feature_id_lookup;

    if (( exists $self->{'feature_id_lookup'}) && (defined($self->{'feature_id_lookup'}) )) {

	$feature_id_lookup = $self->{'feature_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("feature_id_lookup was not defined");
    }


    #---------------------------------
    # organism_id
    #
    my $organism_id;

    if (( exists $param{'organism_id'}) && (defined($param{'organism_id'}))) {
	$organism_id = $param{'organism_id'};
    }
    else {
	$self->{_logger}->logdie("organism_id was not defined");
    }

    #---------------------------------
    # uniquename
    #
    my $uniquename;

    if (( exists $param{'uniquename'}) && (defined($param{'uniquename'}))) {
	$uniquename = $param{'uniquename'};
    }
    else {
	$self->{_logger}->logdie("uniquename was not defined");
    }

    #---------------------------------
    # type_id
    #
    my $type_id;

    if (( exists $param{'type_id'}) && (defined($param{'type_id'}))) {
	$type_id = $param{'type_id'};
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $feature_id;

    my $index = $organism_id . '_' . $uniquename . '_' . $type_id;

    if (( exists $feature_id_lookup->{$index}->[0]) && (defined($feature_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$feature_id = $feature_id_lookup->{$index}->[0];

	$self->{_logger}->warn("feature_id '$feature_id' was stored in table organism during a previous session for organism_id '$organism_id' uniquename '$uniquename' type_id '$type_id'") if ($status eq 'warn');
    }

    return $feature_id;

} # sub check_feature_id_lookup



sub check_featureloc_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_featureloc_id_lookup") if $self->{_logger}->is_debug();

    my $featureloc_id_lookup;

    if (( exists $self->{'featureloc_id_lookup'}) && (defined($self->{'featureloc_id_lookup'}) )) {

	$featureloc_id_lookup = $self->{'featureloc_id_lookup'};
    }
    else {
	$self->{_logger}->logdie("featureloc_id_lookup was not defined");
    }


    #---------------------------------
    # feature_id
    #
    my $feature_id;

    if (( exists $param{'feature_id'}) && (defined($param{'feature_id'}))) {
	$feature_id = $param{'feature_id'};
    }
    else {
	$self->{_logger}->logdie("feature_id was not defined");
    }

    #---------------------------------
    # locgroup
    #
    my $locgroup;

    if (( exists $param{'locgroup'}) && (defined($param{'locgroup'}))) {
	$locgroup = $param{'locgroup'};
    }
    else {
	$self->{_logger}->logdie("locgroup was not defined");
    }

    #---------------------------------
    # rank
    #
    my $rank;

    if (( exists $param{'rank'}) && (defined($param{'rank'}))) {
	$rank = $param{'rank'};
    }
    else {
	$self->{_logger}->logdie("rank was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $featureloc_id;

    my $index = $feature_id . '_' . $locgroup . '_' . $rank;

    if (( exists $featureloc_id_lookup->{$index}->[0]) && (defined($featureloc_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$featureloc_id = $featureloc_id_lookup->{$index}->[0];

	$self->{_logger}->warn("featureloc_id '$featureloc_id' was stored in table organism during a previous session for feature_id '$feature_id' locgroup '$locgroup' rank '$rank'") if ($status eq 'warn');
    }

    return $featureloc_id;

}

sub check_feature_pub_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_feature_pub_id_lookup") if $self->{_logger}->is_debug();

    my $feature_pub_id_lookup;

    if (( exists $self->{'feature_pub_id_lookup'}) && (defined($self->{'feature_pub_id_lookup'}) )) {

	$feature_pub_id_lookup = $self->{'feature_pub_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("feature_pub_id_lookup was not defined");
    }


    #---------------------------------
    # feature_id
    #
    my $feature_id;

    if (( exists $param{'feature_id'}) && (defined($param{'feature_id'}))) {
	$feature_id = $param{'feature_id'};
    }
    else {
	$self->{_logger}->logdie("feature_id was not defined");
    }

    #---------------------------------
    # pub_id
    #
    my $pub_id;

    if (( exists $param{'pub_id'}) && (defined($param{'pub_id'}))) {
	$pub_id = $param{'pub_id'};
    }
    else {
	$self->{_logger}->logdie("pub_id was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $feature_pub_id;

    my $index = $feature_id . '_' . $pub_id;

    if (( exists $feature_pub_id_lookup->{$index}->[0]) && (defined($feature_pub_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$feature_pub_id = $feature_pub_id_lookup->{$index}->[0];

	$self->{_logger}->warn("feature_pub_id '$feature_pub_id' was stored in table organism during a previous session for feature_id '$feature_id' pub_id '$pub_id'") if ($status eq 'warn');
    }

    return $feature_pub_id;

} # sub check_feature_pub_id_lookup




sub check_featureprop_pub_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_featureprop_pub_id_lookup") if $self->{_logger}->is_debug();

    my $featureprop_pub_id_lookup;

    if (( exists $self->{'featureprop_pub_id_lookup'}) && (defined($self->{'featureprop_pub_id_lookup'}) )) {

	$featureprop_pub_id_lookup = $self->{'featureprop_pub_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("featureprop_pub_id_lookup was not defined");
    }


    #---------------------------------
    # featureprop_id
    #
    my $featureprop_id;

    if (( exists $param{'featureprop_id'}) && (defined($param{'featureprop_id'}))) {
	$featureprop_id = $param{'featureprop_id'};
    }
    else {
	$self->{_logger}->logdie("featureprop_id was not defined");
    }

    #---------------------------------
    # pub_id
    #
    my $pub_id;

    if (( exists $param{'pub_id'}) && (defined($param{'pub_id'}))) {
	$pub_id = $param{'pub_id'};
    }
    else {
	$self->{_logger}->logdie("pub_id was not defined");
    }


    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $featureprop_pub_id;

    my $index = $featureprop_id . '_' . $pub_id;

    if (( exists $featureprop_pub_id_lookup->{$index}->[0]) && (defined($featureprop_pub_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$featureprop_pub_id = $featureprop_pub_id_lookup->{$index}->[0];

	$self->{_logger}->warn("featureprop_pub_id '$featureprop_pub_id' was stored in table organism during a previous session for featureprop_id '$featureprop_id' pub_id '$pub_id'") if ($status eq 'warn');
    }

    return $featureprop_pub_id;

} # sub check_featureprop_pub_id_lookup




sub check_feature_dbxref_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_feature_dbxref_id_lookup") if $self->{_logger}->is_debug();

    my $feature_dbxref_id_lookup;

    if (( exists $self->{'feature_dbxref_id_lookup'}) && (defined($self->{'feature_dbxref_id_lookup'}) )) {

	$feature_dbxref_id_lookup = $self->{'feature_dbxref_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("feature_dbxref_id_lookup was not defined");
    }


    #---------------------------------
    # feature_id
    #
    my $feature_id;

    if (( exists $param{'feature_id'}) && (defined($param{'feature_id'}))) {
	$feature_id = $param{'feature_id'};
    }
    else {
	$self->{_logger}->logdie("feature_id was not defined");
    }

    #---------------------------------
    # dbxref_id
    #
    my $dbxref_id;

    if (( exists $param{'dbxref_id'}) && (defined($param{'dbxref_id'}))) {
	$dbxref_id = $param{'dbxref_id'};
    }
    else {
	$self->{_logger}->logdie("dbxref_id was not defined");
    }


    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $feature_dbxref_id;

    my $index = $feature_id . '_' . $dbxref_id;

    if (( exists $feature_dbxref_id_lookup->{$index}->[0]) && (defined($feature_dbxref_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$feature_dbxref_id = $feature_dbxref_id_lookup->{$index}->[0];

	$self->{_logger}->warn("feature_dbxref_id '$feature_dbxref_id' was stored in table organism during a previous session for feature_id '$feature_id' dbxref_id '$dbxref_id'") if ($status eq 'warn');
    }

    return $feature_dbxref_id;

} # sub check_feature_dbxref_id_lookup





sub check_feature_relationship_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_feature_relationship_id_lookup") if $self->{_logger}->is_debug();

    my $feature_relationship_id_lookup;

    if (( exists $self->{'feature_relationship_id_lookup'}) && (defined($self->{'feature_relationship_id_lookup'}) )) {

	$feature_relationship_id_lookup = $self->{'feature_relationship_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("feature_relationship_id_lookup was not defined");
    }


    #---------------------------------
    # subject_id
    #
    my $subject_id;

    if (( exists $param{'subject_id'}) && (defined($param{'subject_id'}))) {
	$subject_id = $param{'subject_id'};
    }
    else {
	$self->{_logger}->logdie("subject_id was not defined");
    }

    #---------------------------------
    # object_id
    #
    my $object_id;

    if (( exists $param{'object_id'}) && (defined($param{'object_id'}))) {
	$object_id = $param{'object_id'};
    }
    else {
	$self->{_logger}->logdie("object_id was not defined");
    }

    #---------------------------------
    # type_id
    #
    my $type_id;

    if (( exists $param{'type_id'}) && (defined($param{'type_id'}))) {
	$type_id = $param{'type_id'};
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }

    #---------------------------------
    # rank
    #
    my $rank;

    if (( exists $param{'rank'}) && (defined($param{'rank'}))) {
	$rank = $param{'rank'};
    }
    else {
	$self->{_logger}->logdie("rank was not defined");
    }


    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $feature_relationship_id;

    my $index = $subject_id . '_' . $object_id . '_' . $type_id . '_' . $rank;

    if (( exists $feature_relationship_id_lookup->{$index}->[0]) && (defined($feature_relationship_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$feature_relationship_id = $feature_relationship_id_lookup->{$index}->[0];

	my $msg = "feature_relationship_id '$feature_relationship_id' was stored in table organism during a previous session for subject_id '$subject_id' object_id '$object_id' type_id '$type_id rank '$rank' " . $param{'msg'};


	$self->{_logger}->warn("$msg") if ($status eq 'warn');
    }

    return $feature_relationship_id;

} # sub check_feature_relationship_id_lookup




sub check_feature_relationship_pub_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_feature_relationship_pub_id_lookup") if $self->{_logger}->is_debug();

    my $feature_relationship_pub_id_lookup;

    if (( exists $self->{'feature_relationship_pub_id_lookup'}) && (defined($self->{'feature_relationship_pub_id_lookup'}) )) {

	$feature_relationship_pub_id_lookup = $self->{'feature_relationship_pub_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("feature_relationship_pub_id_lookup was not defined");
    }


    #---------------------------------
    # feature_relationship_id
    #
    my $feature_relationship_id;

    if (( exists $param{'feature_relationship_id'}) && (defined($param{'feature_relationship_id'}))) {
	$feature_relationship_id = $param{'feature_relationship_id'};
    }
    else {
	$self->{_logger}->logdie("feature_relationship_id was not defined");
    }

    #---------------------------------
    # pub_id
    #
    my $pub_id;

    if (( exists $param{'pub_id'}) && (defined($param{'pub_id'}))) {
	$pub_id = $param{'pub_id'};
    }
    else {
	$self->{_logger}->logdie("pub_id was not defined");
    }



    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $feature_relationship_pub_id;

    my $index = $feature_relationship_id . '_' . $pub_id;

    if (( exists $feature_relationship_pub_id_lookup->{$index}->[0]) && (defined($feature_relationship_pub_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$feature_relationship_pub_id = $feature_relationship_pub_id_lookup->{$index}->[0];

	$self->{_logger}->warn("feature_relationship_pub_id '$feature_relationship_pub_id' was stored in table organism during a previous session for feature_relationship_id '$feature_relationship_id' pub_id '$pub_id'") if ($status eq 'warn');
    }

    return $feature_relationship_pub_id;

} # sub check_feature_relationship_pub_id_lookup




sub check_feature_relationshipprop_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_feature_relationshipprop_id_lookup") if $self->{_logger}->is_debug();

    my $feature_relationshipprop_id_lookup;

    if (( exists $self->{'feature_relationshipprop_id_lookup'}) && (defined($self->{'feature_relationshipprop_id_lookup'}) )) {

	$feature_relationshipprop_id_lookup = $self->{'feature_relationshipprop_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("feature_relationshipprop_id_lookup was not defined");
    }


    #---------------------------------
    # feature_relationship_id
    #
    my $feature_relationship_id;

    if (( exists $param{'feature_relationship_id'}) && (defined($param{'feature_relationship_id'}))) {
	$feature_relationship_id = $param{'feature_relationship_id'};
    }
    else {
	$self->{_logger}->logdie("feature_relationship_id was not defined");
    }

    #---------------------------------
    # type_id
    #
    my $type_id;

    if (( exists $param{'type_id'}) && (defined($param{'type_id'}))) {
	$type_id = $param{'type_id'};
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }

    #---------------------------------
    # rank
    #
    my $rank;

    if (( exists $param{'rank'}) && (defined($param{'rank'}))) {
	$rank = $param{'rank'};
    }
    else {
	$self->{_logger}->logdie("rank was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $feature_relationshipprop_id;

    my $index = $feature_relationship_id . '_' . $type_id . '_' . $rank;

    if (( exists $feature_relationshipprop_id_lookup->{$index}->[0]) && (defined($feature_relationshipprop_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$feature_relationshipprop_id = $feature_relationshipprop_id_lookup->{$index}->[0];

	$self->{_logger}->warn("feature_relationshipprop_id '$feature_relationshipprop_id' was stored in table organism during a previous session for feature_relationship_id '$feature_relationship_id' type_id '$type_id' rank '$rank'") if ($status eq 'warn');
    }

    return $feature_relationshipprop_id;

} # sub check_feature_relationshipprop_id_lookup




sub check_feature_relprop_pub_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_feature_relprop_pub_id_lookup") if $self->{_logger}->is_debug();

    my $feature_relprop_pub_id_lookup;

    if (( exists $self->{'feature_relprop_pub_id_lookup'}) && (defined($self->{'feature_relprop_pub_id_lookup'}) )) {

	$feature_relprop_pub_id_lookup = $self->{'feature_relprop_pub_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("feature_relprop_pub_id_lookup was not defined");
    }


    #---------------------------------
    # feature_relationshipprop_id
    #
    my $feature_relationshipprop_id;

    if (( exists $param{'feature_relationshipprop_id'}) && (defined($param{'feature_relationshipprop_id'}))) {
	$feature_relationshipprop_id = $param{'feature_relationshipprop_id'};
    }
    else {
	$self->{_logger}->logdie("feature_relationshipprop_id was not defined");
    }

    #---------------------------------
    # pub_id
    #
    my $pub_id;

    if (( exists $param{'pub_id'}) && (defined($param{'pub_id'}))) {
	$pub_id = $param{'pub_id'};
    }
    else {
	$self->{_logger}->logdie("pub_id was not defined");
    }


    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $feature_relprop_pub_id;

    my $index = $feature_relationshipprop_id . '_' . $pub_id;

    if (( exists $feature_relprop_pub_id_lookup->{$index}->[0]) && (defined($feature_relprop_pub_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$feature_relprop_pub_id = $feature_relprop_pub_id_lookup->{$index}->[0];

	$self->{_logger}->warn("feature_relprop_pub_id '$feature_relprop_pub_id' was stored in table organism during a previous session for feature_relationshipprop_id '$feature_relationshipprop_id' pub_id '$pub_id'") if ($status eq 'warn');
    }

    return $feature_relprop_pub_id;

} # sub check_feature_relprop_pub_id_lookup




sub check_feature_cvterm_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_feature_cvterm_id_lookup") if $self->{_logger}->is_debug();

    my $feature_cvterm_id_lookup;

    if (( exists $self->{'feature_cvterm_id_lookup'}) && (defined($self->{'feature_cvterm_id_lookup'}) )) {

	$feature_cvterm_id_lookup = $self->{'feature_cvterm_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("feature_cvterm_id_lookup was not defined");
    }


    #---------------------------------
    # feature_id
    #
    my $feature_id;

    if (( exists $param{'feature_id'}) && (defined($param{'feature_id'}))) {
	$feature_id = $param{'feature_id'};
    }
    else {
	$self->{_logger}->logdie("feature_id was not defined");
    }

    #---------------------------------
    # cvterm_id
    #
    my $cvterm_id;

    if (( exists $param{'cvterm_id'}) && (defined($param{'cvterm_id'}))) {
	$cvterm_id = $param{'cvterm_id'};
    }
    else {
	$self->{_logger}->logdie("cvterm_id was not defined");
    }

    #---------------------------------
    # pub_id
    #
    my $pub_id;

    if (( exists $param{'pub_id'}) && (defined($param{'pub_id'}))) {
	$pub_id = $param{'pub_id'};
    }
    else {
	$self->{_logger}->logdie("pub_id was not defined");
    }



    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $feature_cvterm_id;

    my $index = $feature_id . '_' . $cvterm_id . '_' . $pub_id;

    if (( exists $feature_cvterm_id_lookup->{$index}->[0]) && (defined($feature_cvterm_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$feature_cvterm_id = $feature_cvterm_id_lookup->{$index}->[0];

	$self->{_logger}->warn("feature_cvterm_id '$feature_cvterm_id' was stored in table organism during a previous session for feature_id '$feature_id' cvterm_id '$cvterm_id' pub_id '$pub_id'") if ($status eq 'warn');
    }

    return $feature_cvterm_id;

} # sub check_feature_cvterm_id_lookup




sub check_feature_cvtermprop_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_feature_cvtermprop_id_lookup") if $self->{_logger}->is_debug();

    my $feature_cvtermprop_id_lookup;

    if (( exists $self->{'feature_cvtermprop_id_lookup'}) && (defined($self->{'feature_cvtermprop_id_lookup'}) )) {

	$feature_cvtermprop_id_lookup = $self->{'feature_cvtermprop_id_lookup'};
    }
    else {
	$self->{_logger}->logdie("feature_cvtermprop_id_lookup was not defined");
    }


    #---------------------------------
    # feature_cvterm_id
    #
    my $feature_cvterm_id;

    if (( exists $param{'feature_cvterm_id'}) && (defined($param{'feature_cvterm_id'}))) {
	$feature_cvterm_id = $param{'feature_cvterm_id'};
    }
    else {
	$self->{_logger}->logdie("feature_cvterm_id was not defined");
    }

    #---------------------------------
    # type_id
    #
    my $type_id;

    if (( exists $param{'type_id'}) && (defined($param{'type_id'}))) {
	$type_id = $param{'type_id'};
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }

    #---------------------------------
    # rank
    #
    my $rank;

    if (( exists $param{'rank'}) && (defined($param{'rank'}))) {
	$rank = $param{'rank'};
    }
    else {
	$self->{_logger}->logdie("rank was not defined");
    }



    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }

    my $feature_cvtermprop_id;

    my $index = $feature_cvterm_id . '_' . $type_id . '_' . $rank;

    if (( exists $feature_cvtermprop_id_lookup->{$index}->[0]) && (defined($feature_cvtermprop_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$feature_cvtermprop_id = $feature_cvtermprop_id_lookup->{$index}->[0];

	$self->{_logger}->warn("feature_cvtermprop_id '$feature_cvtermprop_id' was stored in table organism during a previous session for feature_cvterm_id '$feature_cvterm_id' type_id '$type_id' rank '$rank'") if ($status eq 'warn');
    }

    return $feature_cvtermprop_id;

} # sub check_feature_cvtermprop_id_lookup




sub check_feature_cvterm_dbxref_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_feature_cvterm_dbxref_id_lookup") if $self->{_logger}->is_debug();

    my $feature_cvterm_dbxref_id_lookup;

    if (( exists $self->{'feature_cvterm_dbxref_id_lookup'}) && (defined($self->{'feature_cvterm_dbxref_id_lookup'}) )) {

	$feature_cvterm_dbxref_id_lookup = $self->{'feature_cvterm_dbxref_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("feature_cvterm_dbxref_id_lookup was not defined");
    }


    #---------------------------------
    # feature_cvterm_id
    #
    my $feature_cvterm_id;

    if (( exists $param{'feature_cvterm_id'}) && (defined($param{'feature_cvterm_id'}))) {
	$feature_cvterm_id = $param{'feature_cvterm_id'};
    }
    else {
	$self->{_logger}->logdie("feature_cvterm_id was not defined");
    }

    #---------------------------------
    # dbxref_id
    #
    my $dbxref_id;

    if (( exists $param{'dbxref_id'}) && (defined($param{'dbxref_id'}))) {
	$dbxref_id = $param{'dbxref_id'};
    }
    else {
	$self->{_logger}->logdie("dbxref_id was not defined");
    }



    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $feature_cvterm_dbxref_id;

    my $index = $feature_cvterm_id . '_' . $dbxref_id;

    if (( exists $feature_cvterm_dbxref_id_lookup->{$index}->[0]) && (defined($feature_cvterm_dbxref_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$feature_cvterm_dbxref_id = $feature_cvterm_dbxref_id_lookup->{$index}->[0];

	$self->{_logger}->warn("feature_cvterm_dbxref_id '$feature_cvterm_dbxref_id' was stored in table organism during a previous session for feature_cvterm_id '$feature_cvterm_id' dbxref_id '$dbxref_id'") if ($status eq 'warn');
    }

    return $feature_cvterm_dbxref_id;

} # sub check_feature_cvterm_dbxref_id_lookup




sub check_feature_cvterm_pub_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_feature_cvterm_pub_id_lookup") if $self->{_logger}->is_debug();

    my $feature_cvterm_pub_id_lookup;

    if (( exists $self->{'feature_cvterm_pub_id_lookup'}) && (defined($self->{'feature_cvterm_pub_id_lookup'}) )) {

	$feature_cvterm_pub_id_lookup = $self->{'feature_cvterm_pub_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("feature_cvterm_pub_id_lookup was not defined");
    }


    #---------------------------------
    # feature_cvterm_id
    #
    my $feature_cvterm_id;

    if (( exists $param{'feature_cvterm_id'}) && (defined($param{'feature_cvterm_id'}))) {
	$feature_cvterm_id = $param{'feature_cvterm_id'};
    }
    else {
	$self->{_logger}->logdie("feature_cvterm_id was not defined");
    }

    #---------------------------------
    # pub_id
    #
    my $pub_id;

    if (( exists $param{'pub_id'}) && (defined($param{'pub_id'}))) {
	$pub_id = $param{'pub_id'};
    }
    else {
	$self->{_logger}->logdie("pub_id was not defined");
    }


    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $feature_cvterm_pub_id;

    my $index = $feature_cvterm_id . '_' . $pub_id;

    if (( exists $feature_cvterm_pub_id_lookup->{$index}->[0]) && (defined($feature_cvterm_pub_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$feature_cvterm_pub_id = $feature_cvterm_pub_id_lookup->{$index}->[0];

	$self->{_logger}->warn("feature_cvterm_pub_id '$feature_cvterm_pub_id' was stored in table organism during a previous session for feature_cvterm_id '$feature_cvterm_id' pub_id '$pub_id'") if ($status eq 'warn');
    }

    return $feature_cvterm_pub_id;

} # sub check_feature_cvterm_pub_id_lookup




sub check_synonym_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_synonym_id_lookup") if $self->{_logger}->is_debug();

    my $synonym_id_lookup;

    if (( exists $self->{'synonym_id_lookup'}) && (defined($self->{'synonym_id_lookup'}) )) {

	$synonym_id_lookup = $self->{'synonym_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("synonym_id_lookup was not defined");
    }


    #---------------------------------
    # name
    #
    my $name;

    if (( exists $param{'name'}) && (defined($param{'name'}))) {
	$name = lc($param{'name'});
    }
    else {
	$self->{_logger}->logdie("name was not defined");
    }

    #---------------------------------
    # type_id
    #
    my $type_id;

    if (( exists $param{'type_id'}) && (defined($param{'type_id'}))) {
	$type_id = $param{'type_id'};
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }



    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $synonym_id;

    my $index = $name . '_' . $type_id;

    if (( exists $synonym_id_lookup->{$index}->[0]) && (defined($synonym_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$synonym_id = $synonym_id_lookup->{$index}->[0];

	$self->{_logger}->warn("synonym_id '$synonym_id' was stored in table organism during a previous session for name '$name' type_id '$type_id'") if ($status eq 'warn');
    }

    return $synonym_id;

} # sub check_synonym_id_lookup




sub check_feature_synonym_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_feature_synonym_id_lookup") if $self->{_logger}->is_debug();

    my $feature_synonym_id_lookup;

    if (( exists $self->{'feature_synonym_id_lookup'}) && (defined($self->{'feature_synonym_id_lookup'}) )) {

	$feature_synonym_id_lookup = $self->{'feature_synonym_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("feature_synonym_id_lookup was not defined");
    }


    #---------------------------------
    # synonym_id
    #
    my $synonym_id;

    if (( exists $param{'synonym_id'}) && (defined($param{'synonym_id'}))) {
	$synonym_id = $param{'synonym_id'};
    }
    else {
	$self->{_logger}->logdie("synonym_id was not defined");
    }

    #---------------------------------
    # feature_id
    #
    my $feature_id;

    if (( exists $param{'feature_id'}) && (defined($param{'feature_id'}))) {
	$feature_id = $param{'feature_id'};
    }
    else {
	$self->{_logger}->logdie("feature_id was not defined");
    }

    #---------------------------------
    # pub_id
    #
    my $pub_id;

    if (( exists $param{'pub_id'}) && (defined($param{'pub_id'}))) {
	$pub_id = $param{'pub_id'};
    }
    else {
	$self->{_logger}->logdie("pub_id was not defined");
    }



    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $feature_synonym_id;

    my $index = $synonym_id . '_' . $feature_id . '_' . $pub_id;

    if (( exists $feature_synonym_id_lookup->{$index}->[0]) && (defined($feature_synonym_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$feature_synonym_id = $feature_synonym_id_lookup->{$index}->[0];

	$self->{_logger}->warn("feature_synonym_id '$feature_synonym_id' was stored in table organism during a previous session for synonym_id '$synonym_id' feature_id '$feature_id' pub_id '$pub_id'") if ($status eq 'warn');
    }

    return $feature_synonym_id;

} # sub check_feature_synonym_id_lookup




sub check_analysis_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_analysis_id_lookup") if $self->{_logger}->is_debug();

    my $analysis_id_lookup;

    if (( exists $self->{'analysis_id_lookup'}) && (defined($self->{'analysis_id_lookup'}) )) {

	$analysis_id_lookup = $self->{'analysis_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("analysis_id_lookup was not defined");
    }


    #---------------------------------
    # program
    #
    my $program;

    if (( exists $param{'program'}) && (defined($param{'program'}))) {
	$program = $param{'program'};
    }
    else {
	$self->{_logger}->logdie("program was not defined");
    }

    #---------------------------------
    # programversion
    #
    my $programversion;

    if (( exists $param{'programversion'}) && (defined($param{'programversion'}))) {
	$programversion = $param{'programversion'};
    }
    else {
	$self->{_logger}->logdie("programversion was not defined");
    }

    #---------------------------------
    # sourcename
    #
    my $sourcename;

    if (( exists $param{'sourcename'}) && (defined($param{'sourcename'}))) {
	$sourcename = $param{'sourcename'};
    }
    else {
	$self->{_logger}->logdie("sourcename was not defined");
    }



    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $analysis_id;

    my $index = $program . '_' . $programversion . '_' . $sourcename;

    if (( exists $analysis_id_lookup->{$index}->[0]) && (defined($analysis_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$analysis_id = $analysis_id_lookup->{$index}->[0];

	$self->{_logger}->warn("analysis_id '$analysis_id' was stored in table organism during a previous session for program '$program' programversion '$programversion' sourcename '$sourcename'") if ($status eq 'warn');
    }

    return $analysis_id;

} # sub check_analysis_id_lookup




sub check_analysisprop_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_analysisprop_id_lookup") if $self->{_logger}->is_debug();

    my $analysisprop_id_lookup;

    if (( exists $self->{'analysisprop_id_lookup'}) && (defined($self->{'analysisprop_id_lookup'}) )) {

	$analysisprop_id_lookup = $self->{'analysisprop_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("analysisprop_id_lookup was not defined");
    }


    #---------------------------------
    # analysis_id
    #
    my $analysis_id;

    if (( exists $param{'analysis_id'}) && (defined($param{'analysis_id'}))) {
	$analysis_id = $param{'analysis_id'};
    }
    else {
	$self->{_logger}->logdie("analysis_id was not defined");
    }

    #---------------------------------
    # type_id
    #
    my $type_id;

    if (( exists $param{'type_id'}) && (defined($param{'type_id'}))) {
	$type_id = $param{'type_id'};
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }


    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $analysisprop_id;

    my $index = $analysis_id . '_' . $type_id;

    if (( exists $analysisprop_id_lookup->{$index}->[0]) && (defined($analysisprop_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$analysisprop_id = $analysisprop_id_lookup->{$index}->[0];

	$self->{_logger}->warn("analysisprop_id '$analysisprop_id' was stored in table organism during a previous session for analysis_id '$analysis_id' type_id '$type_id'") if ($status eq 'warn');
    }

    return $analysisprop_id;

} # sub check_analysisprop_id_lookup




sub check_analysisfeature_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_analysisfeature_id_lookup") if $self->{_logger}->is_debug();

    my $analysisfeature_id_lookup;

    if (( exists $self->{'analysisfeature_id_lookup'}) && (defined($self->{'analysisfeature_id_lookup'}) )) {

	$analysisfeature_id_lookup = $self->{'analysisfeature_id_lookup'};
    }
    else {
	$self->{_logger}->logdie("analysisfeature_id_lookup was not defined");
    }


    #---------------------------------
    # feature_id
    #
    my $feature_id;

    if (( exists $param{'feature_id'}) && (defined($param{'feature_id'}))) {
	$feature_id = $param{'feature_id'};
    }
    else {
	$self->{_logger}->logdie("feature_id was not defined");
    }

    #---------------------------------
    # analysis_id
    #
    my $analysis_id;

    if (( exists $param{'analysis_id'}) && (defined($param{'analysis_id'}))) {
	$analysis_id = $param{'analysis_id'};
    }
    else {
	$self->{_logger}->logdie("analysis_id was not defined");
    }


    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $analysisfeature_id;

    my $index = $feature_id . '_' . $analysis_id;

    if (( exists $analysisfeature_id_lookup->{$index}->[0]) && (defined($analysisfeature_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$analysisfeature_id = $analysisfeature_id_lookup->{$index}->[0];

	my $msg = "analysisfeature_id '$analysisfeature_id' was stored in table analysisfeature during a previous session for feature_id '$feature_id' analysis_id '$analysis_id' " . $param{'msg'};

	$self->{_logger}->warn("$msg") if ($status eq 'warn');
    }

    return $analysisfeature_id;

} # sub check_analysisfeature_id_lookup




sub check_cvterm_relationship_type_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_cvterm_relationship_type_id_lookup") if $self->{_logger}->is_debug();

    my $cvterm_relationship_type_id_lookup;

    if (( exists $self->{'cvterm_relationship_type_id_lookup'}) && (defined($self->{'cvterm_relationship_type_id_lookup'}) )) {

	$cvterm_relationship_type_id_lookup = $self->{'cvterm_relationship_type_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("cvterm_relationship_type_id_lookup was not defined");
    }


    #---------------------------------
    # subject_id
    #
    my $subject_id;

    if (( exists $param{'subject_id'}) && (defined($param{'subject_id'}))) {
	$subject_id = $param{'subject_id'};
    }
    else {
	$self->{_logger}->logdie("subject_id was not defined");
    }

    #---------------------------------
    # object_id
    #
    my $object_id;

    if (( exists $param{'object_id'}) && (defined($param{'object_id'}))) {
	$object_id = $param{'object_id'};
    }
    else {
	$self->{_logger}->logdie("object_id was not defined");
    }


    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $type_id;

    my $index = $subject_id . '_' . $object_id;

    if (( exists $cvterm_relationship_type_id_lookup->{$index}->[0]) && (defined($cvterm_relationship_type_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$type_id = $cvterm_relationship_type_id_lookup->{$index}->[0];

    }

    return $type_id;

} # sub check_cvterm_relationship_type_id_lookup

sub check_evidence_codes_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_evidence_codes_lookup") if $self->{_logger}->is_debug();

    my $evidence_codes_lookup;

    if (( exists $self->{'evidence_codes_lookup'}) && (defined($self->{'evidence_codes_lookup'}) )) {

	$evidence_codes_lookup = $self->{'evidence_codes_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("evidence_codes_lookup was not defined");
    }


    #---------------------------------
    # name
    #
    my $name;

    if (( exists $param{'name'}) && (defined($param{'name'}))) {
	$name = lc($param{'name'});
    }
    else {
	$self->{_logger}->logdie("name was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }

    my $cvterm_id;

    my $index = $name;

    if (( exists $evidence_codes_lookup->{$index}->[0]) && (defined($evidence_codes_lookup->{$index}->[0]))){
	#
	# 
	#	
	$cvterm_id = $evidence_codes_lookup->{$index}->[0];

    }

    return $cvterm_id;

} # sub check_evidence_codes_lookup




sub check_analysis_id_by_wfid_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_analysis_id_by_wfid_lookup") if $self->{_logger}->is_debug();

    my $analysis_id_by_wfid_lookup;

    if (( exists $self->{'analysis_id_by_wfid_lookup'}) && (defined($self->{'analysis_id_by_wfid_lookup'}) )) {

	$analysis_id_by_wfid_lookup = $self->{'analysis_id_by_wfid_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("analysis_id_by_wfid_lookup was not defined");
    }


    #---------------------------------
    # value
    #
    my $value;

    if (( exists $param{'value'}) && (defined($param{'value'}))) {
	$value = $param{'value'};
    }
    else {
	$self->{_logger}->logdie("value was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $analysis_id;

    my $index = $value;

    if (( exists $analysis_id_by_wfid_lookup->{$index}->[0]) && (defined($analysis_id_by_wfid_lookup->{$index}->[0]))){
	#
	# 
	#	
	$analysis_id = $analysis_id_by_wfid_lookup->{$index}->[0];

    }

    return $analysis_id;

} # sub check_analysis_id_by_wfid_lookup


sub check_name_by_analysis_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_name_by_analysis_id_lookup") if $self->{_logger}->is_debug();

    my $name_by_analysis_id_lookup;

    if (( exists $self->{'name_by_analysis_id_lookup'}) && (defined($self->{'name_by_analysis_id_lookup'}) )) {

	$name_by_analysis_id_lookup = $self->{'name_by_analysis_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("name_by_analysis_id_lookup was not defined");
    }


    #---------------------------------
    # name
    #
    my $name;

    if (( exists $param{'name'}) && (defined($param{'name'}))) {
	$name = $param{'name'};
    }
    else {
	$self->{_logger}->logdie("name was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $analysis_id;

    my $index = $name;

    if (( exists $name_by_analysis_id_lookup->{$index}->[0]) && (defined($name_by_analysis_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$analysis_id = $name_by_analysis_id_lookup->{$index}->[0];

    }

    return $analysis_id;

} # sub check_name_by_analysis_id_lookup




sub check_property_types_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_property_types_lookup") if $self->{_logger}->is_debug();

    my $property_types_lookup;

    if (( exists $self->{'property_types_lookup'}) && (defined($self->{'property_types_lookup'}) )) {

	$property_types_lookup = $self->{'property_types_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("property_types_lookup was not defined");
    }


    #---------------------------------
    # name
    #
    my $name;

    if (( exists $param{'name'}) && (defined($param{'name'}))) {
	$name = lc($param{'name'});
    }
    else {
	$self->{_logger}->logdie("name was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $cvterm_id;

    my $index = $name;

    if (( exists $property_types_lookup->{$index}->[0]) && (defined($property_types_lookup->{$index}->[0]))){
	#
	# 
	#	
	$cvterm_id = $property_types_lookup->{$index}->[0];

    }

    return $cvterm_id;

} # sub check_property_types_lookup



sub check_cvterm_id_by_dbxref_accession_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_cvterm_id_by_dbxref_accession_lookup") if $self->{_logger}->is_debug();

    my $cvterm_id_by_dbxref_accession_lookup;

    if (( exists $self->{'cvterm_id_by_dbxref_accession_lookup'}) && (defined($self->{'cvterm_id_by_dbxref_accession_lookup'}) )) {

	$cvterm_id_by_dbxref_accession_lookup = $self->{'cvterm_id_by_dbxref_accession_lookup'};
    }
    else {
	$self->{_logger}->logdie("cvterm_id_by_dbxref_accession_lookup was not defined");
    }


    #---------------------------------
    # cv_id
    #
    my $cv_id;

    if (( exists $param{'cv_id'}) && (defined($param{'cv_id'}))) {
	$cv_id = $param{'cv_id'};
    }
    else {
	$self->{_logger}->logdie("cv_id was not defined");
    }


    #---------------------------------
    # accession
    #
    my $accession;

    if (( exists $param{'accession'}) && (defined($param{'accession'}))) {
	$accession = $param{'accession'};
    }
    else {
	$self->{_logger}->logdie("accession was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $cvterm_id;

    my $index = $cv_id . '_' . $accession;


    if (( exists $cvterm_id_by_dbxref_accession_lookup->{$index}->[0]) && (defined($cvterm_id_by_dbxref_accession_lookup->{$index}->[0]))){
	#
	# 
	#	
	$cvterm_id = $cvterm_id_by_dbxref_accession_lookup->{$index}->[0];

    }

    return $cvterm_id;

} # sub check_cvterm_id_by_dbxref_accession_lookup




sub check_cvterm_id_by_accession_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_cvterm_id_by_accession_lookup") if $self->{_logger}->is_debug();

    my $cvterm_id_by_accession_lookup;

    if (( exists $self->{'cvterm_id_by_accession_lookup'}) && (defined($self->{'cvterm_id_by_accession_lookup'}) )) {

	$cvterm_id_by_accession_lookup = $self->{'cvterm_id_by_accession_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("cvterm_id_by_accession_lookup was not defined");
    }


    #---------------------------------
    # name
    #
    my $name;

    if (( exists $param{'name'}) && (defined($param{'name'}))) {
	$name = $param{'name'};
    }
    else {
	$self->{_logger}->logdie("name was not defined");
    }


    #---------------------------------
    # accession
    #
    my $accession;

    if (( exists $param{'accession'}) && (defined($param{'accession'}))) {
	$accession = $param{'accession'};
    }
    else {
	$self->{_logger}->logdie("accession was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $cvterm_id;

    my $index = $name . '_' . $accession;

    if (( exists $cvterm_id_by_accession_lookup->{$index}->[0]) && (defined($cvterm_id_by_accession_lookup->{$index}->[0]))){
	#
	# 
	#	
	$cvterm_id = $cvterm_id_by_accession_lookup->{$index}->[0];

    }

    return $cvterm_id;

} # sub check_cvterm_id_by_accession_lookup




sub check_cvterm_id_by_name_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_cvterm_id_by_name_lookup") if $self->{_logger}->is_debug();

    my $cvterm_id_by_name_lookup;

    if (( exists $self->{'cvterm_id_by_name_lookup'}) && (defined($self->{'cvterm_id_by_name_lookup'}) )) {

	$cvterm_id_by_name_lookup = $self->{'cvterm_id_by_name_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("cvterm_id_by_name_lookup was not defined");
    }


    #---------------------------------
    # name
    #
    my $name;

    if (( exists $param{'name'}) && (defined($param{'name'}))) {
	$name = lc($param{'name'});
    }
    else {
	$self->{_logger}->logdie("name was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $cvterm_id;

    my $index = $name;

     if (( exists $cvterm_id_by_name_lookup->{$index}->[0]) && (defined($cvterm_id_by_name_lookup->{$index}->[0]))){
	#
	# This term does exist
	#	
	$cvterm_id = $cvterm_id_by_name_lookup->{$index}->[0];

    }
    else {
	#
	# Check if the same term exists in lowercase
	#
	$index = lc($index);

	if (( exists $cvterm_id_by_name_lookup->{$index}->[0]) && (defined($cvterm_id_by_name_lookup->{$index}->[0]))){
	    #
	    # Found the term in lowercase
	    #	
	    $cvterm_id = $cvterm_id_by_name_lookup->{$index}->[0];
	}
    }


    return $cvterm_id;

} # sub check_cvterm_id_by_name_lookup



sub check_cvterm_id_by_class_lookup {

    my ($self, %param) = @_;

    my $cvterm_id_by_class_lookup;

    if (( exists $self->{'cvterm_id_by_class_lookup'}) && (defined($self->{'cvterm_id_by_class_lookup'}) )) {

	$cvterm_id_by_class_lookup = $self->{'cvterm_id_by_class_lookup'};
    }
    else {
	$self->{_logger}->logdie("cvterm_id_by_class_lookup was not defined");
    }

    #---------------------------------
    # class
    #
    my $class;

    if (( exists $param{'class'}) && (defined($param{'class'}))) {
	$class = lc($param{'class'});
    }
    else {
	$self->{_logger}->logdie("class was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $cvterm_id;

    my $index = $class;

    if (( exists $cvterm_id_by_class_lookup->{$index}->[0]) && 
	(defined($cvterm_id_by_class_lookup->{$index}->[0]))){
	#
	# 
	#	
	$cvterm_id = $cvterm_id_by_class_lookup->{$index}->[0];

    }
    else {
	$index = lc($index);

	if (( exists $cvterm_id_by_class_lookup->{$index}->[0]) && 
	    (defined($cvterm_id_by_class_lookup->{$index}->[0]))){
	    
	    $cvterm_id = $cvterm_id_by_class_lookup->{$index}->[0];
	}
    }



    return $cvterm_id;

} # sub check_cvterm_id_by_class_lookup




sub check_cvtermsynonym_synonym_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_cvtermsynonym_synonym_lookup") if $self->{_logger}->is_debug();

    my $cvtermsynonym_synonym_lookup;

    if (( exists $self->{'cvtermsynonym_synonym_lookup'}) && (defined($self->{'cvtermsynonym_synonym_lookup'}) )) {

	$cvtermsynonym_synonym_lookup = $self->{'cvtermsynonym_synonym_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("cvtermsynonym_synonym_lookup was not defined");
    }


    #---------------------------------
    # synonym
    #
    my $synonym;

    if (( exists $param{'synonym'}) && (defined($param{'synonym'}))) {
	$synonym = $param{'synonym'};
    }
    else {
	$self->{_logger}->logdie("synonym was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $cvterm_id;

    my $index = $synonym;

    if (( exists $cvtermsynonym_synonym_lookup->{$index}->[0]) && (defined($cvtermsynonym_synonym_lookup->{$index}->[0]))){

	$cvterm_id = $cvtermsynonym_synonym_lookup->{$index}->[0];
    }
    else {
	## try lowercase
	$index = lc($index);

	if (( exists $cvtermsynonym_synonym_lookup->{$index}->[0]) && (defined($cvtermsynonym_synonym_lookup->{$index}->[0]))){
	    $cvterm_id = $cvtermsynonym_synonym_lookup->{$index}->[0];
	}
    }

    return $cvterm_id;

} # sub check_cvtermsynonym_synonym_lookup



sub check_synonym_terms_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_synonym_terms_lookup") if $self->{_logger}->is_debug();

    my $synonym_terms_lookup;

    if (( exists $self->{'synonym_terms_lookup'}) && (defined($self->{'synonym_terms_lookup'}) )) {

	$synonym_terms_lookup = $self->{'synonym_terms_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("synonym_term_lookup was not defined");
    }


    #---------------------------------
    # name
    #
    my $name;

    if (( exists $param{'name'}) && (defined($param{'name'}))) {
	$name = lc($param{'name'});
    }
    else {
	$self->{_logger}->logdie("name was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $cvterm_id;

    my $index = $name;

    if (( exists $synonym_terms_lookup->{$index}->[0]) && (defined($synonym_terms_lookup->{$index}->[0]))){
	#
	# 
	#	
	$cvterm_id = $synonym_terms_lookup->{$index}->[0];

    }

    return $cvterm_id;

} # sub check_synonym_terms_lookup



 
#---------------------------------------------------------
# cvterm_id_by_alt_id_lookup()
#
#---------------------------------------------------------
sub cvterm_id_by_alt_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cvterm_id_by_alt_id_lookup'} = $self->{_backend}->get_cvterm_id_by_alt_id_lookup();
}


sub check_cvterm_id_by_alt_id_lookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_cvterm_id_by_alt_id_lookup") if $self->{_logger}->is_debug();

    my $cvterm_id_by_alt_id_lookup;

    if (( exists $self->{'cvterm_id_by_alt_id_lookup'}) && (defined($self->{'cvterm_id_by_alt_id_lookup'}) )) {

	$cvterm_id_by_alt_id_lookup = $self->{'cvterm_id_by_alt_id_lookup'};
    }
    else {
	return;
	$self->{_logger}->logdie("cvterm_id_by_alt_id_lookup was not defined");
    }


    #---------------------------------
    # cv_id
    #
    my $cv_id;

    if (( exists $param{'cv_id'}) && (defined($param{'cv_id'}))) {
	$cv_id = $param{'cv_id'};
    }
    else {
	$self->{_logger}->logdie("cv_id was not defined");
    }


    #---------------------------------
    # accession
    #
    my $accession;

    if (( exists $param{'accession'}) && (defined($param{'accession'}))) {
	$accession = $param{'accession'};
    }
    else {
	$self->{_logger}->logdie("accession was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }


    my $cvterm_id;

    my $index = $cv_id . '_' . $accession;

    if (( exists $cvterm_id_by_alt_id_lookup->{$index}->[0]) && (defined($cvterm_id_by_alt_id_lookup->{$index}->[0]))){
	#
	# 
	#	
	$cvterm_id = $cvterm_id_by_alt_id_lookup->{$index}->[0];

    }

    return $cvterm_id;


} # sub check_cvterm_id_by_alt_id_lookup



#-----------------------------------------------------------------------------------------------------
# method: store_bsml_cross_reference_component()
#
# date:   2005-11-16
#
#	

# Excerpt: http://www.bsml.org/i3c/docs/BSML3_1_Reference_Manual.pdf
#
# <!ATTLIST Cross-reference
#   %attrs;
#   id               ID     #IMPLIED
#   context          CDATA  #IMPLIED        namespace for databases/ontologies
#   database         CDATA  #IMPLIED        abbreviation for database
#   identifier       CDATA  #IMPLIED        resource identifier
#   identifier-type  CDATA  #IMPLIED        e.g. accession or GUID
#   title            CDATA  #IMPLIED        displayable title
#   behavior         CDATA  #IMPLIED        specify action
#   href             CDATA  #IMPLIED        specify access
#   role             CDATA  #IMPLIED>       controlled vocabulary for xref types
#
#
# 
#-----------------------------------------------------------------------------------------------------
sub store_bsml_cross_reference_component {


    my ($self, %phash) = @_;

    my $xref = $phash{'xref'}->{'attr'};

    
    my ($database, $identifier, $identifier_type);


    if ((exists $xref->{'database'}) and (defined($xref->{'database'}))){
	$database = $xref->{'database'};
    }
    else{
	$self->{_logger}->logdie("database was not defined");
    }
    if ((exists $xref->{'identifier'}) and (defined($xref->{'identifier'}))){
	$identifier = $xref->{'identifier'};
    }
    else{
	$self->{_logger}->logdie("identifier was not defined");
    }
    if ((exists $xref->{'identifier-type'}) and (defined($xref->{'identifier-type'}))){
	$identifier_type = $xref->{'identifier-type'};
    }
    else{
	$identifier_type = 'current';

#	$self->{_logger}->warn("identifier-type was not defined and therefore was set to '$identifier_type'");
    }

    #----------------------------------------------------------------------------------------------
    # Attempt to retrieve/store record in chado.db
    #

    my $db_id = $self->check_db_id_lookup( name => $database );
    
    if (!defined($db_id)){
	#
	# The API stores a table record lookup
	#
	$db_id = $self->{_backend}->do_store_new_db( name => $database );

	$self->{_logger}->logdie("db_id was not defined for name '$database', continuing to process regardless") if (!defined($db_id));

    }
    

    #----------------------------------------------------------------------------------------------
    # Attempt to retrieve/store record in chado.dbxref
    #

    my $dbxref_id = $self->check_dbxref_id_lookup(
						  db_id      => $db_id,
						  accession  => $identifier,
						  version    => $identifier_type
						  );
    if (!defined($dbxref_id)){
	
	$dbxref_id = $self->{_backend}->do_store_new_dbxref(
							    db_id        => $db_id,
							    accession    => $identifier,  
							    version      => $identifier_type,
							    description  => undef
							    );
	
	$self->{_logger}->logdie("dbxref_id was not defined for db_id '$db_id' accession '$identifier' version '$identifier_type'") if (!defined($dbxref_id));
    }

    my $BsmlAttr = $phash{'xref'}->{'BsmlAttr'};

    foreach my $name (keys %{$BsmlAttr}){

	my $type_id = $self->check_cvterm_id_by_name_lookup( name => $name );

	if (defined($type_id)){
	    
	    my $rank = 0 ;

	    foreach my $content (@{$BsmlAttr->{$name}}){

		my $dbxrefprop_id;

		do {

		    $dbxrefprop_id = $self->check_dbxrefprop_id_lookup( dbxref_id => $dbxref_id,
									type_id   => $type_id,
									value     => $content,
									rank      => $rank );
		} while ((defined($dbxrefprop_id)) && (++$rank));


		$dbxrefprop_id = $self->{_backend}->do_store_new_dbxrefprop( dbxref_id => $dbxref_id,
									     type_id   => $type_id,
									     value     => $content,
									     rank      => $rank );
		if (!defined($dbxrefprop_id)){
		    $self->{_logger}->logdie("dbxrefprop_id was not defined for dbxref_id '$dbxref_id' type_id '$type_id' value '$content' rank '$rank'");
		}
	    }
	}
	else {
	    $self->{_logger}->logdie("type_id was not defined for cvterm.name '$name'");
	}
    }

    return $dbxref_id;
}





#-----------------------------------------------------------------------------------------
# subroutine: chado_database_user_list()
#
# comment:    This script will now drop all foreign key constraints prior to
#             dropping all tables.
#
# input:      scalar (database name)
#
# output:     none
#
# return:     array reference (list of users logged into named chado database)
#
#-----------------------------------------------------------------------------------------
sub chado_database_user_list {
    
    my($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
	

    my $listref = $self->{_backend}->get_chado_database_user_list(@_);

	my $uniquelist = {};

	for (my $i=0 ; $i < scalar(@{$listref}) ; $i++) {

		my $username = $listref->[$i][0] . "\@tigr.org";

		$uniquelist->{$username}++;

	}


	die Dumper $uniquelist;

	return $uniquelist;

}


sub model_orf_attributes_is_partial {

    my ($self, $asmbl_id, $db, $feat_type, $att_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->get_model_orf_attributes_is_partial($asmbl_id, $db, $feat_type, $att_type);

}



#-----------------------------------------------
# orf_ntorf_feat_link()
#
#-----------------------------------------------
sub orf_ntorf_feat_link {

    my ($self, $asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my @ret = $self->{_backend}->get_orf_ntorf_feat_link($asmbl_id);

    my $featlink = {};

    for (my $i; $i < @ret; $i++) {

	$featlink->{$ret[$i][0]} = $ret[$i][1];
    }


    return $featlink;
    
}
    

#-----------------------------------------------
# miscellaneous_features()
#
#-----------------------------------------------
sub miscellaneous_features {

    my ($self, $db, $asmbl_id, $feat_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_miscellaneous_features($db, $asmbl_id, $feat_type);

}

#-----------------------------------------------
# repeat_features()
#
#----------------------------------------------
sub repeat_features {

    my ($self, $db, $asmbl_id, $feat_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_repeat_features($db, $asmbl_id, $feat_type);

}

#-----------------------------------------------
# transposon_features()
#
#-----------------------------------------------
sub transposon_features {

    my ($self, $db, $asmbl_id, $feat_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_transposon_features($db, $asmbl_id, $feat_type);

}


#-----------------------------------------------
# relate_feature_members()
#
#-----------------------------------------------
sub relate_feature_members {

    my ($self, $uniquename1, $uniquename2, $type_id, $feature_id_lookup, $feature_id_lookup_d,
	$name1, $name2, $exon_transcript_flag, $exon_coordinates, $exons_2_transcript) = @_;
    

    my $object_id = $self->get_feature_id_from_lookups($uniquename1,
						       $feature_id_lookup,
						       $feature_id_lookup_d);
    

    ## include-classes and exclude_classes support
    if (!defined($object_id)){
	$self->{_logger}->warn("feature_id was not defined for uniquename '$uniquename1'");
	return;
    }

    my $subject_id = $self->get_feature_id_from_lookups($uniquename2,
							$feature_id_lookup,
							$feature_id_lookup_d);
    
    ## include-classes and exclude_classes support
    if (!defined($subject_id)){
	$self->{_logger}->warn("feature_id was not defined for uniquename '$uniquename2'");
	return;
    }
    
    ## Need to store the exon features' fmin and complement in order 
    ## to later correctly set feature_relationship.rank values.
    if (($name1 eq 'transcript') && ($name2 eq 'exon')) {
	#
	# We are interested in storing feature_relationship.rank values to coordinate the exons ranks with respect to
	# their parent transcript
	#
	$exon_transcript_flag++;

	if (( exists $exon_coordinates->{$uniquename2}) && (defined($exon_coordinates->{$uniquename2})) ) {
	    #
	    # We can only process the exons if the coordinates were stored in the exon_coordinates lookup
	    # during the Prism::store_bsml_feature_component() and Prism::add_feature_to_auxiliary_feature_tables()
	    # methods.
	    #
	    my $complement = $exon_coordinates->{$uniquename2}->{'complement'};

	    push (@{$exons_2_transcript->{$uniquename1}->{$complement}}, { subject_id => $subject_id,
									   object_id  => $object_id,
									   type_id    => $type_id,
									   fmin       => $exon_coordinates->{$uniquename2}->{'fmin'}
								       });
	}
	else{
	    if (( exists $feature_id_lookup->{$uniquename2}) &&
		( exists $feature_id_lookup->{$uniquename1})) {

		if ($self->{_logger}->is_debug()){ 
		    $self->{_logger}->debug("exon '$uniquename2' and transcript '$uniquename1' were previously loaded; will not store exon_coordinates info in exons_2_transcript lookup");

		}
	    }
	    else {
		$self->{_logger}->fatal("exon_coordinates did not exist for exon '$uniquename2' transcript '$uniquename1'.  Will not be able to assign rank to this exon for transcript '$uniquename1'");
	    }
	}
    }
    else {
	#
	# Otherwise we are not dealing with exon-transcript relationships.
	#				
	my $rank = 0;
	
	my $feature_relationship_id = $self->check_feature_relationship_id_lookup(
										  subject_id => $subject_id,
										  object_id  => $object_id,
										  type_id    => $type_id,
										  rank       => $rank
										  );
	if (defined($feature_relationship_id)){
#	    $self->{_logger}->logdie("feature_relationship_id '$feature_relationship_id' was already defined for subject_id '$subject_id' object_id '$object_id' type_id '$type_id' rank '$rank'");
	}
	else{
	    
	    $feature_relationship_id = $self->{_backend}->do_store_new_feature_relationship(
											    object_id  => $object_id,
											    subject_id => $subject_id,
											    type_id    => $type_id,
											    rank       => $rank
											    );
	    
	    $self->{_logger}->logdie("feature_relationship_id was not defined for object_id '$object_id' (uniquename '$uniquename1') subject_id '$subject_id' (uniquename '$uniquename2') type_id '$type_id' rank '$rank'") if (!defined($feature_relationship_id));
	    
	}
    }


    return $exon_transcript_flag;

}# end sub relate_feature_members {


#-----------------------------------------------
# get_feature_id_from_lookups()
#
#-----------------------------------------------
sub get_feature_id_from_lookups {
    
    my ($self, $uniquename, $feature_id_lookup, $feature_id_lookup_d) = @_;

    my $feature_id;

    if ((exists $feature_id_lookup->{$uniquename}->[0]) && 
	(defined($feature_id_lookup->{$uniquename}->[0]))) {

	$feature_id = $feature_id_lookup->{$uniquename}->[0];
    }
    elsif ((exists $feature_id_lookup_d->{$uniquename}->{'feature_id'}) && 
	   (defined($feature_id_lookup_d->{$uniquename}->{'feature_id'}))){

	$feature_id = $feature_id_lookup_d->{$uniquename}->{'feature_id'};
    }


    return $feature_id;

}#end sub get_feature_id_from_lookups {


#-----------------------------------------------
# map_class()
#
#-----------------------------------------------
sub map_class {
    
    my ($self, $class) = @_;

    my $mapped_class;

    if (defined($self->{_termusage}->is_defined($class))){
	$mapped_class = $self->{_termusage}->get_usage($class);
    }
    else {
	$mapped_class = $class;
    }

    return ($mapped_class, $class);

}# sub map_class


#-----------------------------------------------
# process_feature_cvterm_record()
#
#-----------------------------------------------
sub process_feature_cvterm_record {

    my ($self, $feature_id, $class, $uniquename) = @_;
    
    my $cvterm_id = $self->check_cvterm_id_by_class_lookup(class => $class);
	
    if (defined($cvterm_id)){
	
	#
	# Check the static feature_cvterm_id lookup
	#
	my $feature_cvterm_id = $self->check_feature_cvterm_id_lookup(
								      feature_id => $feature_id,
								      cvterm_id  => $cvterm_id,
								      pub_id     => 1
								      );
	if (!defined($feature_cvterm_id)){
	    #
	    # The API maintains a record lookup per table
	    # Insert this type_id/value pair into chado.feature_cvterm
	    #
	    $feature_cvterm_id = $self->{_backend}->do_store_new_feature_cvterm(
										feature_id => $feature_id,
										cvterm_id  => $cvterm_id,
										pub_id     => 1
										);

	    

	    
	    if (!defined($feature_cvterm_id)){
		$self->{_logger}->logdie("feature_cvterm_id was not defined. Could not insert record into chado.feature_cvterm for uniquename '$uniquename'  feature_id 'feature_id' cvterm_id '$cvterm_id' pub_id '1'");
	    }
	}
    }
    else {
	$self->{_logger}->logdie("cvterm_id was not defined for class '$class' (uniquename '$uniquename')");
    }
    
}
	    


#----------------------------------------------------------------
# cvterm_max_is_obsolete_lookup()
#
#----------------------------------------------------------------
sub cvterm_max_is_obsolete_lookup {

    my($self) = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
        
    return $self->{_backend}->get_cvterm_max_is_obsolete_lookup(@_);

}



#----------------------------------------------------------------
# verify_obsolete_term()
#
#----------------------------------------------------------------
sub verify_obsolete_term {

    my ($self, $cv_id, $name, $cvterm_id, $cvterm_max_is_obsolete_lookup, $appendmode, $is_obsolete, $name_obsolete_lookup) = @_;
    
    my $db_is_obsolete;

    ($cvterm_id, $db_is_obsolete) = &check_cvterm_max_is_obsolete_lookup($name, $cvterm_max_is_obsolete_lookup);

    #
    # Need to determine whether the new record's term name is obsolete, or whether the already loaded record term name is obsolete.
    #
    if (defined($cvterm_id)){
	
	if ($db_is_obsolete == 0 ){
	    
	    #
	    # The loaded term is not obsolete
	    #
	    if ($is_obsolete == 0 ){
		
		if ($appendmode == 0 ){
		    
		    #
		    # Conflict.  The loaded term and the new in-bound term are both believed to NOT be obsolete.
		    #
		    $self->{_logger}->logdie("cvterm term name '$name' for new in-bound record has is_obsolete '$is_obsolete' but the same term name already exists in the database cvterm_id '$cvterm_id' with is_obsolete '$db_is_obsolete'.  Cannot have two records loaded in the database where both shared the same cv_id and name, and neither are obsolete.  Skipping to next term...");
		    
		    
		}			
		elsif ($appendmode == 1){
		    
		    #
		    # In some cases, this may not be a conflict.  Could be the case that OBO2Chado.pl is processing an ontology obo file which was previously processed (and the
		    # terms were loaded into the CV Module, however since that time, new terms were added to the obo file.   These new terms should be loaded into the
		    # CV Module, while still obeying the new rules for the is_obsolete field.
		    # The script and API should determine that some terms were previously loaded (and that they are not non-obsolete or obsolete versions of the already loaded terms).
		    #
		    $self->{_logger}->debug("Will attempt to append record for non-obsoleted term") if $self->{_logger}->is_debug();
		    
		    $cvterm_id = $self->{_backend}->get_cvterm_id_from_cvterm(
									      cv_id => $cv_id,
									      name =>  $name
									      );
		}
		else{
		    $self->{_logger}->logdie("Un-recognized value for critical variable appendmode '$appendmode'");
		}
	    }
	    else {
		#
		# The new in-bound record contains a term name which was already loaded.  The loaded version was not obsolete.   The in-bound version is obsolete.
		#
		$is_obsolete = 1;  # at this point $is_obsolete will always be assigned value = 1
	    }
	}
	else{
	    #
	    # The currently loaded term was obsolete.
	    #
	    if ($is_obsolete != 0){
		#
		# New in-bound term is obsolete so assign the next is_obsolete value for this term.
		# We maintain an obsoleted term name counter since there could be many obsoleted OBO records
		# with the same term name.
		
		$name_obsolete_lookup->{$name}++;
		$is_obsolete = $db_is_obsolete + $name_obsolete_lookup->{$name};
	    }
	    else{
		#
		# New in-bound record is NOT obsolete and currently loaded version is obsolete.
		# Do nothing.  Let $is_obsolete continue to = 0
	    }
	}
    }
    
    return ($cvterm_id, $is_obsolete);
}

#----------------------------------------------------------------
# verifyObsoleteTerm()
#
#----------------------------------------------------------------
sub verifyObsoleteTerm {

    my ($self, $cv_id, $name, $cvterm_max_is_obsolete_lookup, $appendmode, $is_obsolete, $name_obsolete_lookup) = @_;

    my ($cvterm_id, $db_is_obsolete) = &check_cvterm_max_is_obsolete_lookup($name, $cvterm_max_is_obsolete_lookup);

    #
    # Need to determine whether the new record's term name is obsolete, or whether the already loaded record term name is obsolete.
    #
    if (defined($cvterm_id)){
	
	if ($db_is_obsolete == 0 ){
	    
	    #
	    # The loaded term is not obsolete
	    #
	    if ($is_obsolete == 0 ){
		
		if ($appendmode == 0 ){
		    
		    #
		    # Conflict.  The loaded term and the new in-bound term are both believed to NOT be obsolete.
		    #
		    $self->{_logger}->logdie("cvterm term name '$name' for new in-bound record has is_obsolete '$is_obsolete' but the same term name already exists in the database cvterm_id '$cvterm_id' with is_obsolete '$db_is_obsolete'.  Cannot have two records loaded in the database where both shared the same cv_id and name, and neither are obsolete.  Skipping to next term...");
		    
		    
		}			
		elsif ($appendmode == 1){
		    
		    #
		    # In some cases, this may not be a conflict.  Could be the case that OBO2Chado.pl is processing an ontology obo file which was previously processed (and the
		    # terms were loaded into the CV Module, however since that time, new terms were added to the obo file.   These new terms should be loaded into the
		    # CV Module, while still obeying the new rules for the is_obsolete field.
		    # The script and API should determine that some terms were previously loaded (and that they are not non-obsolete or obsolete versions of the already loaded terms).
		    #
		    $self->{_logger}->debug("Will attempt to append record for non-obsoleted term") if $self->{_logger}->is_debug();
		    
		    $cvterm_id = $self->{_backend}->get_cvterm_id_from_cvterm(
									      cv_id => $cv_id,
									      name =>  $name
									      );
		}
		else{
		    $self->{_logger}->logdie("Un-recognized value for critical variable appendmode '$appendmode'");
		}
	    }
	    else {
		#
		# The new in-bound record contains a term name which was already loaded.  The loaded version was not obsolete.   The in-bound version is obsolete.
		#
		$is_obsolete = 1;  # at this point $is_obsolete will always be assigned value = 1
	    }
	}
	else{
	    #
	    # The currently loaded term was obsolete.
	    #
	    if ($is_obsolete != 0){
		#
		# New in-bound term is obsolete so assign the next is_obsolete value for this term.
		# We maintain an obsoleted term name counter since there could be many obsoleted OBO records
		# with the same term name.
		
		$name_obsolete_lookup->{$name}++;
		$is_obsolete = $db_is_obsolete + $name_obsolete_lookup->{$name};
	    }
	    else{
		#
		# New in-bound record is NOT obsolete and currently loaded version is obsolete.
		# Do nothing.  Let $is_obsolete continue to = 0
	    }
	}
    }
    
    return ($cvterm_id, $is_obsolete);
}


#----------------------------------------------------------------
# check_cvterm_max_is_obsolete_lookup()
#
#----------------------------------------------------------------
sub check_cvterm_max_is_obsolete_lookup {

    my ($name, $cvterm_max_is_obsolete_lookup) = @_;

    $name = lc($name);

    my $cvterm_id;

    my $is_obsolete;

    if ( exists $cvterm_max_is_obsolete_lookup->{$name}){

	$cvterm_id = $cvterm_max_is_obsolete_lookup->{$name}->[1];

	$is_obsolete = $cvterm_max_is_obsolete_lookup->{$name}->[2];

    }

    return ($cvterm_id, $is_obsolete);
}


#----------------------------------------------------------------
# prepare_cvtermprop_record()
#
#----------------------------------------------------------------
sub prepare_cvtermprop_record {

    my ($self, $cvterm_id, $comment_cvterm_id, $comment) = @_;

    #
    # The usual procedure for a non-naming convention record
    #
    my $rank = 0;
        
    my $cvtermprop_id;
    
    do {
	$cvtermprop_id = $self->check_cvtermprop_id_lookup( cvterm_id => $cvterm_id,
							    type_id   => $comment_cvterm_id,
							    value     => $comment,
							    rank      => $rank );
	
    } while ((defined($cvtermprop_id)) && (++$rank));

    #
    # Attempt to store record into table chado.cvtermprop
    #
    $cvtermprop_id = $self->{_backend}->do_store_new_cvtermprop( cvterm_id => $cvterm_id,
								 type_id   => $comment_cvterm_id,
								 value     => $comment,
								 rank      => $rank );
    
    if (!defined($cvtermprop_id)){
	$self->{_logger}->logdie("cvtermprop_id was not defined for cvterm_id '$cvterm_id' type_id '$comment_cvterm_id' value '$comment' rank '$rank'");
    }
}


#----------------------------------------------------------------
# prepare_db_record()
#
#----------------------------------------------------------------
sub prepare_db_record {

    my ($self, $name) = @_;

    my $db_id = $self->check_db_id_lookup( name => $name );

    if (!defined($db_id)){

	$db_id = $self->{_backend}->do_store_new_db( 'name' => $name );
	    
	if (!defined($db_id)){
	    $self->{_logger}->warn("db_id was not defined.  Could not insert record into chado.db for name '$name'");
	    
	}
    }

    return $db_id;
}


#----------------------------------------------------------------
# prepare_dbxref_record()
#
#----------------------------------------------------------------
sub prepare_dbxref_record {

    my ($self, $db_id, $accession, $version, $description) = @_;

    my $dbxref_id = $self->check_dbxref_id_lookup( db_id       => $db_id,
						   accession   => $accession,
						   version     => $version );
    
    if (!defined($dbxref_id)){
	
	$dbxref_id = $self->{_backend}->do_store_new_dbxref(
							    db_id       => $db_id,
							    accession   => $accession,
							    version     => $version,
							    description => $description
							    );
	if (!defined($dbxref_id)){			
	    $self->{_logger}->warn("Unable to insert record into chado.dbxref. dbxref_id was not defined for db_id '$db_id' accession '$accession' version '$version' description '$description'");
	}
    }
		    
    return $dbxref_id;
}



#----------------------------------------------------------------
# prepare_cvterm_dbxref_record()
#
#----------------------------------------------------------------
sub prepare_cvterm_dbxref_record {

    my ($self, $cvterm_id, $dbxref_id) = @_;

    my $cvterm_dbxref_id = $self->check_cvterm_dbxref_id_lookup( cvterm_id => $cvterm_id,
								 dbxref_id => $dbxref_id );
    if (!defined($cvterm_dbxref_id)){
		    
	$cvterm_dbxref_id = $self->{_backend}->do_store_new_cvterm_dbxref( cvterm_id  => $cvterm_id,
									   dbxref_id  => $dbxref_id );
		    
	if (!defined($cvterm_dbxref_id)){
	    $self->{_logger}->warn("Unable to store record in cvterm_dbxref for cvterm_id '$cvterm_id' dbxref_id '$dbxref_id'");
	}
    }

    return $cvterm_dbxref_id;
}

#----------------------------------------------------------------
# prepare_cvterm_relationship_record()
#
#----------------------------------------------------------------
sub prepare_cvterm_relationship_record {

    my ($self, $subject_id, $object_id, $type_id) = @_;


    my $cvterm_relationship_id = $self->check_cvterm_relationship_id_lookup( type_id    => $type_id,
									     subject_id => $subject_id,
									     object_id  => $object_id );
    if (!defined($cvterm_relationship_id)){
			
	$cvterm_relationship_id = $self->{_backend}->do_store_new_cvterm_relationship( type_id      => $type_id,
										       subject_id   => $subject_id,
										       object_id    => $object_id );
	if (!defined($cvterm_relationship_id)){
	    $self->{_logger}->warn("Could not store record in cvterm_relationship for subject_id '$subject_id' object_id '$object_id' type_id '$type_id'");
	}
    }

    return $cvterm_relationship_id;
}

#----------------------------------------------------------------
# storeOBOXrefInChado()
#
#----------------------------------------------------------------
sub storeOBOXrefInChado {

    my ($self, $cvterm_id, $ot, $terms, $xrefType) = @_;

    #
    # Process each ontology identifier's/name's xref_analog
    #
    foreach my $xref (@{$terms->{$ot}->{$xrefType}}){
	
	#
	# Extract the database name and the accession
	#
	my $xref_db;
	my $accession;
	
	if (($xref =~ /^(\S+):([\S\s]+)\s*$/) and ($xref !~ /http/)){
	    
	    $xref_db   = $1;
	    $accession = $2;

        ## occasionally the obo file will have escaped the colon between
        ## the xref_db and the accession.  This will remove that backslash
        ## if it's present.
        $xref_db =~ s/\\$//;
	    
	    if (!defined($accession)){
		$self->{_logger}->warn("accession were not defined for id:$ot xref:$xref\nSkipping to the next xref");
		next;
	    }
	    
	}
	elsif ($xref =~ /http/){
	    $xref_db = $xref;
	}
	else{
	    $self->{_logger}->logdie("Could not parse xref db from $xref");
	    next;
	}
	
	
	if (!defined($xref_db)){
	    $self->{_logger}->warn("xref_db was not defined for id:$ot xref:$xref");
	    next;
	}
	else{
	    #---------------------------------------------------------------------------------------------------
	    # Retrieve/generate chado.db.db_id <2.4.2>
	    #
	    my $db_id = $self->prepare_db_record($xref_db);
	    
	    if (!defined($db_id)){
		$self->{_logger}->logdie("db_id was not defined.  Could not insert record into chado.db for name '$xref_db'.  Will not be able to store records in tables dbxref, cvterm_dbxref");
	    }
	    
	    #--------------------------------------------------------------------------------------------------------------
	    # Retrieve/generate chado.dbxref.dbxref_id <2.4.1>
	    #
	    my $version = 'current';
	    
	    my $dbxref_id = $self->prepare_dbxref_record( $db_id,
							  $accession,
							  $version );
	    if (!defined($dbxref_id)){
		$self->{_logger}->logdie("dbxref_id was not defined.  Could not insert record into chado.dbxref for db_id '$db_id' accession '$accession' version '$version.  Will not be able to insert record into chado.cvterm_dbxref");
		
	    }
	    
		#------------------------------------------------------------------------------------------------------------------
	    # Prepare record for cvterm_dbxref
	    #
	    my $cvterm_dbxref_id = $self->prepare_cvterm_dbxref_record( $cvterm_id, $dbxref_id);
	    
	    if (!defined($cvterm_dbxref_id)){
		$self->{_logger}->logdie("cvterm_dbxref_id was not defined for cvterm_id '$cvterm_id' dbxref_id '$dbxref_id'");
	    }
	}
    }#end foreach my $xref (sort @{$terms->{$ot}->{'xref_analog'}})
}



#----------------------------------------------------------------
# store_alt_id()
#
#----------------------------------------------------------------
sub store_alt_id {

    my ($self, $db_id, $cvterm_id, $ot, $terms) = @_;

    my $version = 'current';

    foreach my $alt_id (@{$terms->{$ot}->{'alt_id'}}){
	
	my $dbxref_id = $self->prepare_dbxref_record( $db_id, 
						      $alt_id, 
						      $version );

	if (!defined($dbxref_id)){    
	    $self->{_logger}->logdie("dbxref_id was not defined.  Could not store record in chado.dbxref for db_id '$db_id' accession '$alt_id' version '$version'");
	}
	else {

	    my $cvterm_dbxref_id = $self->prepare_cvterm_dbxref_record( $cvterm_id,
									$dbxref_id );

	    if (!defined($cvterm_dbxref_id)){
		$self->{_logger}->logdie("cvterm_dbxref_id was not defined.  Could not store record in chado.cvterm_dbxref for cvterm_id '$cvterm_id' dbxref_id '$dbxref_id'");
	    }
	}
    }
}


#----------------------------------------------------------------
# store_additional_typedef_records()
#
#----------------------------------------------------------------
sub store_additional_typedef_records {

    my ($self, $typedef_lookup, $cv, $new_typedef_lookup, $cv_id) = @_;

    #----------------------------------------------------------------------------------------------------
    # Retrieve the db.db_id and set the dbxref.version for the new inbound typedef terms
    #
    my $version = "Additional typedefs found while processing $cv->{'default-namespace'}";

    my $relationship_db_id = $self->check_db_id_lookup( name => 'relationship' );

    if (defined($relationship_db_id)){
	#
	# Verify whether the new inbound typedef terms already exist in the chado database
	#


	foreach my $typedef_term ( sort keys %{$new_typedef_lookup}) {
	    
	    if (! (exists $typedef_lookup->{$typedef_term} )) {
		
		#--------------------------------------------------------------------------------------------------------------------------------------------------
		# This inbound typedef term needs to be inserted into the chado database.
		# Turns out that some of the ontology obo files contain their own typedef relationship terms.
		# We are going to associate these with the relationship ontology.
		#
		my $cvterm_id = $self->lookup_cvterm_id( $cv_id, $typedef_term );
		
		if (!defined($cvterm_id)){
		    
		    $self->{_logger}->info("New typedef relationship term '$typedef_term' will be inserted into the CV module ");
		    
		    my $relationship_dbxref_id = $self->prepare_dbxref_record( $relationship_db_id,
									       $typedef_term,
									       $version );
		    
		    $cvterm_id = $self->{_backend}->do_store_new_cvterm( cv_id        => $cv_id,
									 name         => $typedef_term,
									 definition   => undef,
									 dbxref_id    => $relationship_dbxref_id,
									 is_obsolete  => 0,
									 is_relationshiptype => 1 );
		    if (!defined($cvterm_id)){
			$self->{_logger}->logdie("Unable to insert record into chado.cvterm.  cvterm_id was not defined for cv_id '$cv_id' name '$typedef_term' dbxref_id '$relationship_dbxref_id' is_obsolete '0' is_relationshiptype '1'");
		    }
		    else {
			#
			# Store the typedef term in the typedef_lookup
			#
			$typedef_lookup->{$typedef_term}->{'cvterm_id'} = $cvterm_id;
		    }
		}
		else {
		    $self->{_logger}->logdie("cvterm_id '$cvterm_id' was defined for cv_id '$cv_id' name '$typedef_term'");
		}
	    }
	}
    }
    else {
	$self->{_logger}->logdie("db_id was not defined for db.name 'relationship'.  The relationship.obo Relationship typedef ontology file must be the first ontology loaded into the chado database's CV Module.  Please contact sundaram\@tigr.org. asap");
    }
}

#----------------------------------------------------------------
# verify_obsolete_cvterm_definition()
#
#----------------------------------------------------------------
sub verify_obsolete_cvterm_definition {
    
    my ($self, $terms, $ot, $obsolete) = @_;

    my $definition;

    if ((exists $terms->{$ot}->{'def'}) and (defined($terms->{$ot}->{'def'}))){

	$definition = $terms->{$ot}->{'def'};

	if ($definition =~ /OBSOLETE/){
	    #
	    # In all cases for so.obo is_obsolete field is defined.
	    # In some cases for go.obo, is_obsolete field is not defined, instead the def field contains an OBSOLETE flag
	    #
	    $obsolete->{$ot}++;

	    $obsolete->{'count'}++;

	    $terms->{$ot}->{'is_obsolete'} = 1;

	}
    }

    return $definition;
}




#----------------------------------------------------------------
# store_comment_in_cvtermprop()
#
#----------------------------------------------------------------
sub store_comment_in_cvtermprop {

    my ($self, $terms, $ot, $cvterm_id, $comment_cvterm_id) = @_;

    if ( (exists($terms->{$ot}->{'comment'})) &&
	 (defined($terms->{$ot}->{'comment'}))){
	
	if (defined($comment_cvterm_id)) {

	    my $comment = $terms->{$ot}->{'comment'};

	    $self->prepare_cvtermprop_record( $cvterm_id,
					      $comment_cvterm_id,
					      $comment);
		
	}
	else {
	    $self->{_logger}->warn("The cvterm 'comment' has not yet been inserted into this chado database, therefore we cannot store comments in the cvtermprop table for this particular ontology");
	}
    }
}



#----------------------------------------------------------------
# store_synonym_in_cvtermsynonym()
#
#----------------------------------------------------------------
sub store_synonym_in_cvtermsynonym {

    my ($self, $terms, $ot, $cvterm_id) = @_;

    ## The synonym terms lookup was retrieved outside of the terms loop.
    ## Synonym terms are 'synonym', 'related_synonym', 'exact_synonym', 'narrow_synonym', 'broad_synonym'

    foreach my $synonym_type ( sort keys %{$self->{'synonym_terms_lookup'}} ) {

	if (exists $terms->{$ot}->{$synonym_type} ){
	    #
	    # Process each ontology identifier's/name's synonym
	    #
	    foreach my $synonym (@{$terms->{$ot}->{$synonym_type}}) {
		
		
		if (( defined($synonym)) &&
		    ( length($synonym) > 0)) {
		    
		    ## Changing the log4perl reporting level from WARN to INFO since cvtermsynonym.type_id is a nullable field.

		    my $type_id = $self->check_synonym_terms_lookup( name => $synonym_type );
		    
		    if (!defined($type_id)){
			$self->{_logger}->info("type_id was not defined for name '$synonym_type' while processing cvterm_id '$cvterm_id' synonym '$synonym'");
		    }
		    
		    my $cvtermsynonym_id = $self->prepare_cvtermsynonym_record($cvterm_id, $synonym, $type_id);
		    
		    if (!defined($cvtermsynonym_id)){
			$self->{_logger}->logdie("cvtermsynonym_id was not defined for cvterm_id '$cvterm_id' synonym '$synonym' type_id '$type_id'");
		    }
		    
		}
		else {
		    $self->{_logger}->warn("Found empty synonym for cvterm_id '$cvterm_id' ot '$ot'");
		}
		
	    }
	}
    }
}

#----------------------------------------------------------------
# prepare_cvtermsynonym_record()
#
#----------------------------------------------------------------
sub prepare_cvtermsynonym_record {

    my ($self,$cvterm_id,$synonym,$type_id) = @_;

    my $cvtermsynonym_id = $self->check_cvtermsynonym_id_lookup( cvterm_id => $cvterm_id,
								 synonym   => $synonym );
    if (!defined($cvtermsynonym_id)){
			
	$cvtermsynonym_id = $self->{_backend}->do_store_new_cvtermsynonym( cvterm_id  => $cvterm_id,
									   synonym    => $synonym,
									   type_id    => $type_id );
			
	if (!defined($cvtermsynonym_id)){
	    $self->{_logger}->warn("cvtermsynonym_id was not defined.  Could not insert record into chado.cvtermsynonym for cvterm_id '$cvterm_id' synonym '$synonym' type_id '$type_id'");
	}
    }

    return $cvtermsynonym_id;
}

 
#----------------------------------------------------------------
# store_id_cvterm_lookups()
#
#----------------------------------------------------------------
sub store_id_cvterm_lookups {

    my ($self, $cvterm_id, $ot, $cvterm2id, $id2cvterm, $appendmode, $name) = @_;
    
    #-----------------------------------------------------------------------------
    # Store cvterm_id and ontology id in two lookups for downstream processing
    # (cvterm_relationship) <2.5>
    #-----------------------------------------------------------------------------
    
    #
    # Store the OBO.id to chado.cvterm_id in lookup
    #
    if (!exists ($id2cvterm->{$ot})){
	$id2cvterm->{$ot} = $cvterm_id;
	}
    else{
	if ((!defined($appendmode)) or ($appendmode == 0)){
	    $self->{_logger}->logdie("accession '$ot to cvterm_id '$cvterm_id' already exists");
	}
    }
    
    #
    # Store the chado.cvterm_id to OBO.id in lookup
    #
    if (!exists ($cvterm2id->{$cvterm_id})){
	$cvterm2id->{$cvterm_id} = $ot;
    }
    else{
	if ((!defined($appendmode)) or ($appendmode == 0)){
	    $self->{_logger}->fatal("cvterm2id lookup:" . Dumper $cvterm2id);
	    $self->{_logger}->logdie("\n'$cvterm_id' (with name '$name') was already stored in the cvterm2id lookup for accession '$ot'");
	}
    }
}



#----------------------------------------------------------------
# store_relationships_in_cvterm_relationship()
#
#----------------------------------------------------------------
sub store_relationships_in_cvterm_relationship {

    my ($self, $terms, $cvterm2id, $id2cvterm, $typedef_lookup, $term_count) = @_;
    
    #-----------------------------------------------------------------------------------------------------------------
    #
    # The following section <3> is divided into three sub-sections all dealing with the processing of data for storing
    # cvterm relationships.
    # Sections:
    # 2) Iterate over all ontology identifiers/terms and generate isa and partof relationship lookups      <3.2>
    # 3) Prepare isa relationship data for insertion into chado.cvterm_relationship                        <3.4>
    # 3) Prepare partof relationship data for insertion into chado.cvterm_relationship                     <3.5>
    #
    #-----------------------------------------------------------------------------------------------------------------

    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = $term_count;
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);
    
    printf "\n%-60s   %-12s     0%", qq!Creating typedef lookups!, "[". " "x$bars . "]";

    foreach my $ont (sort keys %$terms){
	#
	# E.g. $ont = 'SO:0000488
	#
	$self->show_progress("Creating typedef lookups $row_count/$term_count",$counter, ++$row_count,$bars,$total_rows);

	## The OBO2Chado.pl loader should create cvterm_relationship records for all of these typedefs.
	## Here we build the typedef lookups.

	foreach my $typedef_term ( sort keys %{$typedef_lookup} ){
	    
	    foreach my $object (@{$terms->{$ont}->{$typedef_term}}){

		if (exists ($id2cvterm->{$object})){

		    push(@{$typedef_lookup->{$typedef_term}->{'terms'}->{$id2cvterm->{$ont}}}, $id2cvterm->{$object});

		    $typedef_lookup->{$typedef_term}->{'counter'}++;
		}
		else{
		    $self->{_logger}->fatal("$object was not stored in id2cvterm");
		    next;
		}
	    }
 	}
    }

    $self->store_cvterm_relationships( $typedef_lookup, $id2cvterm );
}


#----------------------------------------------------------------
# storeRelationshipsInCvtermRelationship()
#
#----------------------------------------------------------------
sub storeRelationshipsInCvtermRelationship {

    my ($self, $termLookup, $cvterm2id, $id2cvterm, $loadedTypedefLookup, $termCount) = @_;
    
    #-----------------------------------------------------------------------------------------------------------------
    #
    # The following section <3> is divided into three sub-sections all dealing with the processing of data for storing
    # cvterm relationships.
    # Sections:
    # 2) Iterate over all ontology identifiers/terms and generate isa and partof relationship lookups      <3.2>
    # 3) Prepare isa relationship data for insertion into chado.cvterm_relationship                        <3.4>
    # 3) Prepare partof relationship data for insertion into chado.cvterm_relationship                     <3.5>
    #
    #-----------------------------------------------------------------------------------------------------------------

    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = $termCount;
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);
    
    printf "\n%-60s   %-12s     0%", qq!Creating typedef lookups!, "[". " "x$bars . "]";

    foreach my $termId ( keys %$termLookup){
	#
	# E.g. $ont = 'SO:0000488
	#
	$self->show_progress("Creating typedef lookups $row_count/$termCount",$counter, ++$row_count,$bars,$total_rows);

	## The OBO2Chado.pl loader should create cvterm_relationship records for all of these typedefs.
	## Here we build the typedef lookups.

	foreach my $typedef ( sort keys %{$loadedTypedefLookup} ){
	    
	    foreach my $object (@{$termLookup->{$termId}->{$typedef}}){

		if (exists ($id2cvterm->{$object})){

		    push(@{$loadedTypedefLookup->{$typedef}->{'terms'}->{$id2cvterm->{$termId}}}, $id2cvterm->{$object});

		    $loadedTypedefLookup->{$typedef}->{'counter'}++;
		}
		else{
		    $self->{_logger}->fatal("$object was not stored in id2cvterm");
		    next;
		}
	    }
 	}
    }

    $self->store_cvterm_relationships( $loadedTypedefLookup, $id2cvterm );
}


#----------------------------------------------------------------
# prepare_cvterm_record()
#
#----------------------------------------------------------------
sub prepare_cvterm_record {

    my ($self, $cv_id, $name, $definition, $dbxref_id, $is_obsolete, $is_relationshiptype) = @_;
    
    my $cvterm_id = $self->lookup_cvterm_id( $cv_id, $name );
    
    if (!defined($cvterm_id)){
	
	$cvterm_id = $self->{_backend}->do_store_new_cvterm( cv_id  => $cv_id,
							     name   => $name,
							     definition => $definition,
							     dbxref_id  => $dbxref_id,
							     is_obsolete => $is_obsolete,
							     is_relationshiptype => $is_relationshiptype );
	
	if (!defined($cvterm_id)){
	    $self->{_logger}->warn("cvterm_id was not defined.  Could not insert record into chado.cvterm for cv_id '$cv_id' name '$name' definition '$definition' dbxref_id '$dbxref_id' is_obsolete '$is_obsolete' is_relationshiptype '$is_relationshiptype'");
	}
    }

    return $cvterm_id;
}


#----------------------------------------------------------------
# lookup_cvterm_id()
#
#----------------------------------------------------------------
sub lookup_cvterm_id {

    my ($self, $cv_id, $name) = @_;

    #
    # For add_sequence_to_auxiliary_feature_tables() and
    # add_feature_to_auxiliary_feature_tables() where it is the case
    # that we are only attempting to assign a value to featureprop.type_id
    # we need to lookup the correct cvterm.cvterm_id and not attempt to 
    # insert a record into cvterm.
    #
    # Note that prepare_cvterm_record calls this subroutine, but performs
    # the necessary insertion into cvterm itself.
    #
    my $cvterm_id = $self->check_non_obsolete_cvterm_id_lookup( cv_id => $cv_id,
								name  => $name );
    if (!defined($cvterm_id)){
	$cvterm_id = $self->check_obsolete_cvterm_id_lookup( cv_id => $cv_id,
							     name  => $name );
    }

    return $cvterm_id;
}


#----------------------------------------------------------------
# check_non_obsolete_cvterm_id_lookup()
#
#----------------------------------------------------------------
sub check_non_obsolete_cvterm_id_lookup {

    my ($self, %param) = @_;

    my $non_obsolete_cvterm_id_lookup;

    if (( exists $self->{'non_obsolete_cvterm_id_lookup'}) && (defined($self->{'non_obsolete_cvterm_id_lookup'}) )) {

	$non_obsolete_cvterm_id_lookup = $self->{'non_obsolete_cvterm_id_lookup'};
    }
    else {
	$self->{_logger}->fatal("non_obsolete_cvterm_id_lookup was not defined");
	return;
    }

    #-------------------------------------
    # cv_id
    #
    my $cv_id;

    if (( exists $param{'cv_id'}) && (defined($param{'cv_id'}))) {
	$cv_id = $param{'cv_id'};
    }
    else {
	$self->{_logger}->logdie("cv_id was not defined");
    }

    #-------------------------------------
    # name
    #
    my $name;

    if (( exists $param{'name'}) && (defined($param{'name'}))) {
	$name = lc($param{'name'});
    }
    else {
	$self->{_logger}->logdie("name was not defined");
    }

    my $cvterm_id;

    my $index = $cv_id . '_' . $name;

    if (( exists $non_obsolete_cvterm_id_lookup->{$index}->[0]) && (defined($non_obsolete_cvterm_id_lookup->{$index}->[0]))){

	$cvterm_id = $non_obsolete_cvterm_id_lookup->{$index}->[0];
    }
    else {
	$index = lc($index);

	if (( exists $non_obsolete_cvterm_id_lookup->{$index}->[0]) && (defined($non_obsolete_cvterm_id_lookup->{$index}->[0]))){
	    $cvterm_id = $non_obsolete_cvterm_id_lookup->{$index}->[0];
	}
    }

    if ( (defined($cvterm_id)) && ( exists $param{'status'}) && (defined($param{'status'}))) {
	$self->{_logger}->warn("cvterm_id '$cvterm_id' was stored in table cvterm during a previous session for cv_id '$cv_id' name '$name'");
    }
    
    return $cvterm_id;

}

#----------------------------------------------------------------
# check_obsolete_cvterm_id_lookup()
#
#----------------------------------------------------------------
sub check_obsolete_cvterm_id_lookup {

    my ($self, %param) = @_;

    my $obsolete_cvterm_id_lookup;

    if (( exists $self->{'obsolete_cvterm_id_lookup'}) && (defined($self->{'obsolete_cvterm_id_lookup'}) )) {

	$obsolete_cvterm_id_lookup = $self->{'obsolete_cvterm_id_lookup'};
    }
    else {
	$self->{_logger}->fatal("obsolete_cvterm_id_lookup was not defined");
	return;
    }


    #-------------------------------------
    # cv_id
    #
    my $cv_id;

    if (( exists $param{'cv_id'}) && (defined($param{'cv_id'}))) {
	$cv_id = $param{'cv_id'};
    }
    else {
	$self->{_logger}->logdie("cv_id was not defined");
    }

    #-------------------------------------
    # name
    #
    my $name;

    if (( exists $param{'name'}) && (defined($param{'name'}))) {
	$name = lc($param{'name'});
    }
    else {
	$self->{_logger}->logdie("name was not defined");
    }



    my $cvterm_id;

    my $index = $cv_id . '_' . $name;


    if (( exists $obsolete_cvterm_id_lookup->{$index}->[0]) && (defined($obsolete_cvterm_id_lookup->{$index}->[0]))){

	$cvterm_id = $obsolete_cvterm_id_lookup->{$index}->[0];
    }
    else {
	$index = lc($index);

	if (( exists $obsolete_cvterm_id_lookup->{$index}->[0]) && (defined($obsolete_cvterm_id_lookup->{$index}->[0]))){
	    $cvterm_id = $obsolete_cvterm_id_lookup->{$index}->[0];
	}
    }

    if ( (defined($cvterm_id)) && ( exists $param{'status'}) && (defined($param{'status'}))) {
	$self->{_logger}->warn("cvterm_id '$cvterm_id' was stored in table cvterm during a previous session for cv_id '$cv_id' name '$name'");
    }
    
    return $cvterm_id;

}



#---------------------------------------------------------
# cvterm_id_by_accession()
#
#---------------------------------------------------------
sub cvterm_id_by_accession {

    my ($self) = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cvterm_id_by_accession'} = $self->{_backend}->get_cvterm_id_by_accession(@_);

}

#---------------------------------------------------------
# check_cvterm_id_by_accession()
#
#---------------------------------------------------------
sub check_cvterm_id_by_accession {

    my ($self, %param) = @_;

    $self->{_logger}->debug("check_cvterm_id_by_accession") if $self->{_logger}->is_debug();

    my $cvterm_id_by_accession;


    if (( exists $self->{'cvterm_id_by_accession'}) && (defined($self->{'cvterm_id_by_accession'}) )) {

	$cvterm_id_by_accession = $self->{'cvterm_id_by_accession'};

    }
    else {
	$self->{_logger}->logdie("cvterm_id_by_accession was not defined");
    }

    #---------------------------------
    # accession
    #
    my $accession;

    if (( exists $param{'accession'}) && (defined($param{'accession'}))) {
	$accession = $param{'accession'};
    }
    else {
	$self->{_logger}->logdie("accession was not defined");
    }

    #---------------------------------
    # status
    #
    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }

    my $cvterm_id;

    if (( exists $cvterm_id_by_accession->{$accession}->[0]) && (defined($cvterm_id_by_accession->{$accession}->[0]))){
	#
	# 
	#	
	$cvterm_id = $cvterm_id_by_accession->{$accession}->[0];

    }

    return $cvterm_id;

} # sub check_cvterm_id_by_accession




#-------------------------------------------------------------
# relationship_typedef_lookup()
#
#-------------------------------------------------------------
sub relationship_typedef_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_relationship_typedef_lookup();

    my $relationship_typedef_lookup = {};

    for ( my $i=0; $i < scalar(@{$ret}); $i++ ) {

	$relationship_typedef_lookup->{$ret->[$i][0]}  = $ret->[$i][1];
	
    }

    return $relationship_typedef_lookup;
}



#-------------------------------------------------------------
# process_bsml_links()
#
#-------------------------------------------------------------
sub process_bsml_links {

    my ($self, %param) = @_;

    my $bsmllinks = $param{'bsmllinks'};
    my $analyses  = $param{'analyses'};
    my $linktypes = $param{'linktypes'};
    my $organism_id = $param{'organism_id'};
    my $is_analysis = $param{'is_analysis'};
    my $genome_id_2_organism_id = $param{'genome_lookup'};
    my $sequence_link = $param{'sequence_link'};
    my $identifier = $param{'identifier'};
    my $analyses_identifier_lookup = $param{'analysis_lookup'};

    
    foreach my $hash ( @{$bsmllinks} ){
	
	if ((exists ($hash->{'rel'})) and (defined($hash->{'rel'}))) {
	    
	    my $rel = $hash->{'rel'};
	    
	    if (exists $linktypes->{$rel}){
		
		if ((exists ($hash->{'href'})) and (defined($hash->{'href'}))){
		    
		    my $href = $hash->{'href'};
		    
		    $href =~ s/^\#//; # strip away the leading pound symbol
		    
		    
		    if ($rel eq 'genome'){
			#
			# <Sequence> elements may have nested <Link> elements.
			# One of these links may tell us whether which <Genome> the sequence is belongs to.
			#
			if (( exists $genome_id_2_organism_id->{$href} ) && (defined ($genome_id_2_organism_id->{$href}))) { 
			    
			    my $organismref = $genome_id_2_organism_id->{$href};
			
			    if ($organismref ne $organism_id){
				$self->{_logger}->warn("Retrieved organism_id '$organismref' from the genome_id_2_organism_id lookup (and not '$organism_id')");
			    }

			    $organism_id = $organismref;
			}
			else {
			    
			    if (!defined($organism_id)){	    
				$self->{_logger}->logdie("organism_id was not defined for genome_link '$href' sequence id '$identifier'");
			    }
			}
		    }
		    elsif ($rel eq 'sequence'){
			$sequence_link = $href;
		    }
		    elsif ($rel eq 'analysis') {
			#
			# bsml2chado.pl and supporting Prism API should store one record in analysisfeature
			# per each existing <Link> between a <Sequence> and some <Analysis>
			#
			if ((exists $analyses_identifier_lookup->{$href}->{'analysis_id'}) && (defined($analyses_identifier_lookup->{$href}->{'analysis_id'}))){

			    #
			    # The analysis_id will be stored in the analyses array.  This array will be passed 
			    # by reference to the add_sequence_to_auxiliary_feature_tables() where an
			    # analysisfeature record will be inserted for each Analysis linked to this
			    # Sequence feature.
			    #
			    
			    #
			    # //Link/@role shall explicitly direct the assignment of the analysisfeature.type_id
			    #			    
			    if (( exists $hash->{'role'}) && (defined($hash->{'role'}))) {
				
				my $role = $hash->{'role'};

				if ($role eq 'computed_by') {
				    #
				    # Some valid analysis link was found, therefore this Sequence feature was computationally derived.
				    # Thus chado.feature.is_analysis = 1
				    #
				    $is_analysis = 1;
				}

				push(@{$analyses}, { id   => $analyses_identifier_lookup->{$href}->{'analysis_id'},
						     role => $role });
			    }
			    else {
				$self->{_logger}->fatal(Dumper $hash);
				$self->{_logger}->logdie("The //Link/[\@role] was not defined for rel '$rel' href '$href'");
			    }
			}
			else {
			    $self->{_logger}->fatal(Dumper $analyses_identifier_lookup);
			    $self->{_logger}->logdie("Found Analysis Link '$href' however does not correspond to any key in the analyses_identifier_lookup.  This means that the //Sequence/Link/[\@rel='analysis'] href='$href' does not link to any //Analysis/\@id");
			}
		    }
		    else{
			$self->{_logger}->logdie("Un-expected rel '$rel'");
		    }
		}
		else{
		    $self->{_logger}->logdie("//Link/\@href was not defined");
		}
	    }
	    else {
		$self->{_logger}->logdie("Unexceptable rel '$rel'");
	    }
	}
	else{
	    $self->{_logger}->logdie("//Link/\@rel was not defined");
	}
    }

    return ($organism_id, $is_analysis, $sequence_link);

}

#----------------------------------------------------------------
# cds_and_polypeptide_data_for_splice_site_derivation()
#
#----------------------------------------------------------------
sub cds_and_polypeptide_data_for_splice_site_derivation {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->get_cds_and_polypeptide_data_for_splice_site_derivation(@_);

    my $lookup = {};
    my $i;

    for ($i = 0; $i  < scalar(@{$ret}) ; $i++){

	my $assemblyFeatureId = shift(@{$ret->[$i]});
	
	push( @{$lookup->{$assemblyFeatureId}}, $ret->[$i]);
    }

    print "Retrieved '$i' CDS and polypeptide records for splice site derivation\n";

    return $lookup;
}


#----------------------------------------------------------------
# exon_data_for_splice_site_derivation()
#
#----------------------------------------------------------------
sub exon_data_for_splice_site_derivation {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->get_exon_data_for_splice_site_derivation(@_);
}

#----------------------------------------------------------------
# assemblies_with_exons_list()
#
#----------------------------------------------------------------
sub assemblies_with_exons_list {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my @assembly_list;

    my $ret =  $self->{_backend}->get_assemblies_with_exons_list();

    my $count = scalar(@{$ret});

    for (my $i=0; $i< $count; $i++){
	push(@assembly_list, $ret->[$i][0]);
    }

    return \@assembly_list;

}

#----------------------------------------------------------------
# assemblies_by_organism_abbreviation()
#
#----------------------------------------------------------------
sub assemblies_by_organism_abbreviation {

    my ($self, $abbreviation) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my @assembly_list;

    my $ret =  $self->{_backend}->get_assemblies_by_organism_abbreviation($abbreviation);

    my $count = scalar(@{$ret});

    for (my $i=0; $i< $count; $i++){
	push(@assembly_list, $ret->[$i][0]);
    }

    return \@assembly_list;

}



#----------------------------------------------------------------
# domain_to_paralogous_family()
#
#----------------------------------------------------------------
sub domain_to_paralogous_family {

    my ($self, $family_id, $ev_type, $att_type, $chromosome) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $domain_to_paralogous_family = {};

    my $ret = $self->{_backend}->get_domain_to_paralogous_family($family_id, $ev_type, $att_type, $chromosome);

    for (my $i=0;$i<scalar(@{$ret});$i++){

	my $familyId = shift(@{$ret->[$i]});
	
	if ($familyId ne $family_id){
	    $self->{_logger}->logdie("family ID retrieved '$familyId' does not match ".
				     "family ID expected '$family_id'");
	}

	my $domain_id = shift(@{$ret->[$i]});

	my $feat_name = shift(@{$ret->[$i]});

	push ( @{$domain_to_paralogous_family->{$domain_id}->{$feat_name}}, $ret->[$i]);

    }

    return $domain_to_paralogous_family;

}

#----------------------------------------------------------------
# paralogous_family_alignment()
#
#----------------------------------------------------------------
sub paralogous_family_alignment {

    my ($self, $family_id, $ev_type, $att_type, $chromosome) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my @paralogous_family_alignments;

    my $ret = $self->{_backend}->get_paralogous_family_alignment($family_id, $ev_type, $att_type, $chromosome);
    
    for (my $i=0;$i<scalar(@{$ret});$i++){

	push (@paralogous_family_alignments, $ret->[$i]);
    }

    return \@paralogous_family_alignments;

}

#----------------------------------------------------------------
# paralogous_family_identifiers()
#
#----------------------------------------------------------------
sub paralogous_family_identifiers {

    my ($self, $ev_type, $att_type, $chromosome) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my @paralogous_family_identifiers;

    my $ret = $self->{_backend}->get_paralogous_family_identifiers($ev_type, $att_type, $chromosome);
    
    for (my $i = 0 ; $i < scalar(@{$ret}) ; $i++){

	push(@paralogous_family_identifiers, $ret->[$i][0]);
    }

    return \@paralogous_family_identifiers;
    
}

#----------------------------------------------------------------
# pmark_data()
#
#----------------------------------------------------------------
sub pmark_data {

    my ($self, $asmbl_id, $db) = @_;
    
    return $self->{_backend}->get_pmark_data($asmbl_id, $db);

}

#----------------------------------------------------------------
# create_pub_record()
#
#----------------------------------------------------------------
sub create_pub_record {

    my ($self) = @_;
    
    my $miniref     = 'miniref-TBD';
    my $uniquename  = 'uniquename-TBD1';
    my $type_id     = 1;
    my $is_obsolete = 0;

    
    my $pub_id = $self->{_backend}->get_pub_id_from_pub( miniref     => $miniref,
							 uniquename  => $uniquename,
							 type_id     => $type_id,
							 is_obsolete => $is_obsolete );

    if (!defined($pub_id->[0][0])){
	
	$pub_id = $self->{_backend}->do_store_new_pub( miniref     => $miniref,
						       uniquename  => $uniquename,
						       type_id     => $type_id,
						       is_obsolete => $is_obsolete );
	
	if (!defined($pub_id)){
	    $self->{_logger}->logdie("Could not create pub record for miniref '$miniref' uniquename '$uniquename' type_id '$type_id' is_obsolete '$is_obsolete'");
	}
    }

}



#-----------------------------------------------------------------------------------------
# subroutine: dropviews()
#
#-----------------------------------------------------------------------------------------
sub dropviews {
    
    my($self, $list, $commit_order, $database) = @_;

    if (!defined($list)){
	$self->{_logger}->logdie("list was not defined");
    }

    if (!defined($commit_order)){
	$self->{_logger}->logdie("commit_order was not defined");
    }

    $self->{_backend}->do_dropviews($list, $commit_order, $database);

}

#----------------------------------------------------------------
# cdsSequences()
#
#----------------------------------------------------------------
sub cdsSequences {

    my ($self, $contig) = @_;
    
    my $recordsRef = $self->{_backend}->getCdsSequences($contig);
    
    my $cdsSequenceLookup = {};

    for (my $i=0; $i < scalar( @{$recordsRef} ) ; $i++ ){ 

	$cdsSequenceLookup->{$recordsRef->[$i][0]} = $recordsRef->[$i][1];
    }

    return $cdsSequenceLookup;

}

#----------------------------------------------------------------
# featurelocDataByType()
#
#----------------------------------------------------------------
sub featurelocDataByType {

    my ($self, $contig, $featureType) = @_;
    
    my $recordsRef = $self->{_backend}->getFeaturelocDataByType($contig,
								$featureType);

    my $featurelocDataByTypeLookup = {};

    for (my $i=0; $i < scalar(@{$recordsRef}) ; $i++ ) {

	my $tmpHash = {};

	$tmpHash = { 'uniquename' => $recordsRef->[$i][1],
		     'fmin'       => $recordsRef->[$i][2],
		     'fmax'       => $recordsRef->[$i][3],
		     'strand'     => $recordsRef->[$i][4]
		 };

	$featurelocDataByTypeLookup->{$recordsRef->[$i][0]} = $tmpHash;

    }

    return $featurelocDataByTypeLookup;
}

#----------------------------------------------------------------
# objectToSubjectLookup()
#
#----------------------------------------------------------------
sub objectToSubjectLookup {

    my ($self, $contig, $objectType, $subjectType) = @_;
    
    my $recordsRef = $self->{_backend}->getObjectToSubjectLookup($contig,
								 $objectType,
								 $subjectType);
    
    my $objectToSubjectLookup = {};

    for (my $i=0; $i < scalar(@{$recordsRef}) ; $i++){
	push ( @{$objectToSubjectLookup->{$recordsRef->[$i][0]}}, $recordsRef->[$i][1]);
    }

    return $objectToSubjectLookup;
}

#----------------------------------------------------------------
# contigUniquenameToResiduesLookup()
#
#----------------------------------------------------------------
sub contigUniquenameToResiduesLookup {

    my ($self, $contig) = @_;
    
    my $recordsRef = $self->{_backend}->getContigUniquenameToResiduesLookup($contig);

    my $contigUniquenameToResiduesLookup = {};

    for ( my $i=0; $i < scalar(@{$recordsRef}); $i++ ){
	$contigUniquenameToResiduesLookup->{$recordsRef->[$i][0]} = $recordsRef->[$i][1];
    }

    return $contigUniquenameToResiduesLookup;
}


#----------------------------------------------------------------
# contigToSeqlenLookup()
#
#----------------------------------------------------------------
sub contigToSeqlenLookup {

    my ($self, $contig) = @_;
    
    my $recordsRef = $self->{_backend}->getContigToSeqlenLookup();

    my $contigToSeqlenLookup = {};

    for (my $i=0; $i < scalar( @{$recordsRef} ) ; $i++ ){
	
	$contigToSeqlenLookup->{$recordsRef->[$i][0]} = $recordsRef->[$i][1];
    }

    return $contigToSeqlenLookup;
}


#----------------------------------------------------------------
# contigToAttributeLookup()
#
#----------------------------------------------------------------
sub contigToAttributeLookup {

    my ($self, $attributeType) = @_;
    
    my $recordsRef = $self->{_backend}->getContigToAttributeLookup($attributeType);

    my $contigToAttributeLookup = {};

    for (my $i=0; $i < scalar( @{$recordsRef} ) ; $i++ ){
	
  	$contigToAttributeLookup->{$recordsRef->[$i][0]} = $recordsRef->[$i][1];

    }

    return $contigToAttributeLookup;
}


#----------------------------------------------------------------
# contigToOrganismLookup()
#
#----------------------------------------------------------------
sub contigToOrganismLookup {

    my ($self, $contig) = @_;
    
    my $recordsRef = $self->{_backend}->getContigToOrganismLookup();

    my $contigToOrganismLookup = {};

    for ( my $i=0; $i < scalar( @{$recordsRef} ) ; $i++ ){
	
	my $tmpHash = { 'genus' => $recordsRef->[$i][1],
			'species' => $recordsRef->[$i][2]};
	
	$contigToOrganismLookup->{$recordsRef->[$i][0]} = $tmpHash;
    
    }

    return $contigToOrganismLookup;
}


#----------------------------------------------------------------
# organismNameToAttributeLookup()
#
#----------------------------------------------------------------
sub organismNameToAttributeLookup {

    my ($self, $attributeType) = @_;
    
    my $recordsRef = $self->{_backend}->getOrganismNameToAttributeLookup($attributeType);

    my $organismNameToAttributeLookup = {};

    for ( my $i=0; $i < scalar( @{$recordsRef} ) ; $i++ ){
	
	my $organismName = $recordsRef->[$i][0] . ' ' . $recordsRef->[$i][1];
	
	$organismNameToAttributeLookup->{$organismName} = $recordsRef->[$i][2];
    
    }

    return $organismNameToAttributeLookup;
}



#----------------------------------------------------------------
# featureAttributeLookup()
#
#----------------------------------------------------------------
sub featureAttributeLookup {

    my ($self, $contig, $attributeType, $featureType) = @_;
    
    my $recordsRef = $self->{_backend}->getFeatureAttributeLookup($contig,
								  $attributeType,
								  $featureType);
    my $featureAttributeLookup = {};

    for (my $i=0 ; $i < scalar(@{$recordsRef}) ; $i++){

	$featureAttributeLookup->{$recordsRef->[$i][0]} = $recordsRef->[$i][1];
    }

    return $featureAttributeLookup;
}


#----------------------------------------------------------------
# featureCrossReferenceLookup()
#
#----------------------------------------------------------------
sub featureCrossReferenceLookup {

    my ($self, $contig, $featureType) = @_;
    
    my $recordsRef = $self->{_backend}->getFeatureCrossReferenceLookup($contig,
								       $featureType);
    my $featureCrossReferenceLookup = {};

    for (my $i=0 ; $i < scalar(@{$recordsRef}) ; $i++){

	my $tmpHash = { 'name' => $recordsRef->[$i][1],
			'accession' => $recordsRef->[$i][2] };

	$featureCrossReferenceLookup->{$recordsRef->[$i][0]} = $tmpHash;
    }
    
    return $featureCrossReferenceLookup;
}


#----------------------------------------------------------------
# featureLocusLookup()
#
#----------------------------------------------------------------
sub featureLocusLookup {

    my ($self, $contig, $featureType) = @_;
    
    my $recordsRef = $self->{_backend}->getFeatureLocusLookup($contig,
							      $featureType);
    my $featureLocusLookup = {};

    for (my $i=0 ; $i < scalar(@{$recordsRef}) ; $i++){

	$featureLocusLookup->{$recordsRef->[$i][0]} = $recordsRef->[$i][1];
    }

    return $featureLocusLookup;
}

#----------------------------------------------------------------
# geneOntologyLookup()
#
#----------------------------------------------------------------
sub geneOntologyLookup {

    my ($self, $contig, $featureType) = @_;
    
    my $recordsRef = $self->{_backend}->getGeneOntologyLookup($contig,
							      $featureType);
    my $geneOntologyLookup = {};

    for (my $i=0 ; $i < scalar(@{$recordsRef}) ; $i++){

	$geneOntologyLookup->{$recordsRef->[$i][0]} = $recordsRef->[$i][1];
    }

    return $geneOntologyLookup;
}

#----------------------------------------------------------------
# ecNumberLookup()
#
#----------------------------------------------------------------
sub ecNumberLookup {

    my ($self, $contig, $featureType) = @_;
    
    my $recordsRef = $self->{_backend}->getEcNumberLookup($contig,
							  $featureType);
    my $ecNumberLookup = {};

    for (my $i=0 ; $i < scalar(@{$recordsRef}) ; $i++){

	$ecNumberLookup->{$recordsRef->[$i][0]} = $recordsRef->[$i][1];
    }

    return $ecNumberLookup;
}


##--------------------------------------------------------------
## verifyDatabaseType()
##
##--------------------------------------------------------------
sub verifyDatabaseType {

    my ($database_type) = @_;

    my $retVal = (exists $supportedDatabaseVendors->{$database_type}) ? 1: 0;

    return $retVal;
}

##--------------------------------------------------------------
## getBcpFileExtension()
##
##--------------------------------------------------------------
sub getBcpFileExtension {

    my ($database_type) = @_;

    if (exists $databaseToBcpFileExtension->{$database_type}){
	return $databaseToBcpFileExtension->{$database_type};
    }

    return undef;
}

##--------------------------------------------------------------
## chadoTableCommitOrder()
##
##--------------------------------------------------------------
sub chadoTableCommitOrder {

    my ($self) = @_;

    return CHADO_TABLE_COMMIT_ORDER;
}

##--------------------------------------------------------------
## chadoCoreTableCommitOrder()
##
##--------------------------------------------------------------
sub chadoCoreTableCommitOrder {

    my ($self) = @_;

    return CHADO_CORE_TABLE_COMMIT_ORDER;
}

##--------------------------------------------------------------
## chadoMartTableCommitOrder()
##
##--------------------------------------------------------------
sub chadoMartTableCommitOrder {

    my ($self) = @_;

    return CHADO_MART_TABLE_COMMIT_ORDER;
}

##--------------------------------------------------------------
## phylogenyModuleTableCommitOrder()
##
##--------------------------------------------------------------
sub phylogenyModuleTableCommitOrder {

    my ($self) = @_;

    return PHYLOGENY_MODULE_TABLE_COMMIT_ORDER;
}

##--------------------------------------------------------------
## controlledVocabularyModuleTableCommitOrder()
##
##--------------------------------------------------------------
sub controlledVocabularyModuleTableCommitOrder {

    my ($self) = @_;

    return CONTROLLED_VOCABULARY_MODULE_TABLE_COMMIT_ORDER;
}

##--------------------------------------------------------------
## organismModuleTableCommitOrder()
##
##--------------------------------------------------------------
sub organismModuleTableCommitOrder {

    my ($self) = @_;

    return ORGANISM_MODULE_TABLE_COMMIT_ORDER;
}

##--------------------------------------------------------------
## generalModuleTableCommitOrder()
##
##--------------------------------------------------------------
sub generalModuleTableCommitOrder {

    my ($self) = @_;

    return GENERAL_MODULE_TABLE_COMMIT_ORDER;
}

##--------------------------------------------------------------
## sequenceModuleTableCommitOrder()
##
##--------------------------------------------------------------
sub sequenceModuleTableCommitOrder {

    my ($self) = @_;

    return SEQUENCE_MODULE_TABLE_COMMIT_ORDER;
}

##--------------------------------------------------------------
## pubModuleTableCommitOrder()
##
##--------------------------------------------------------------
sub pubModuleTableCommitOrder {

    my ($self) = @_;

    return PUB_MODULE_TABLE_COMMIT_ORDER;
}

##--------------------------------------------------------------
## sybaseBatchSize()
##
##--------------------------------------------------------------
sub sybaseBatchSize {

    my ($self) = @_;

    return SYBASE_BATCHSIZE;
}

##--------------------------------------------------------------
## tableExist()
##
##--------------------------------------------------------------
sub tableExist {

    my ($self, $table) = @_;
    
    return $self->{_backend}->doesTableExist($table);
}

##--------------------------------------------------------------
## tableHaveSpace()
##
##--------------------------------------------------------------
sub tableHaveSpace {

    my ($self) = shift;
    
    return $self->{_backend}->doesTableHaveSpace(@_);
}

##--------------------------------------------------------------
## tableRecordCount()
##
##--------------------------------------------------------------
sub tableRecordCount {

    my ($self, $table) = @_;
    
    return $self->{_backend}->getTableRecordCount($table);
}

##--------------------------------------------------------------
## bulkDumpTable()
##
##--------------------------------------------------------------
sub bulkDumpTable {

    my ($self) = shift;
    
    return $self->{_backend}->doBulkDumpTable(@_);
}

##--------------------------------------------------------------
## bulkLoadTable()
##
##--------------------------------------------------------------
sub bulkLoadTable {

    my ($self) = shift;
    
    return $self->{_backend}->doBulkLoadTable(@_);
}

##--------------------------------------------------------------
## updateStatistics()
##
##--------------------------------------------------------------
sub updateStatistics {

    my ($self) = @_;
    
    return $self->{_backend}->doUpdateStatistics(@_);
}

##--------------------------------------------------------------
## interproEvidenceDataByAsmblId()
##
##--------------------------------------------------------------
sub interproEvidenceDataByAsmblId {

    my ($self, $asmbl_id, $db, $feat_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->getInterproEvidenceDataByAsmblId($asmbl_id, $db, $feat_type);

}

##--------------------------------------------------------------
## subFeatureIdentifierMappings()
##
##--------------------------------------------------------------
sub subFeatureIdentifierMappings {

    my ($self, $prefix, $asmbl_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->getSubFeatureIdentifierMappings($prefix, $asmbl_id);

}

##--------------------------------------------------------------
## subSubFeatureIdentifierMappings()
##
##--------------------------------------------------------------
sub subSubFeatureIdentifierMappings {
 
    my ($self, $prefix, $asmbl_id, $arrayref) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->getSubSubFeatureIdentifierMappings($prefix, $asmbl_id);

    for (my $i=0 ; $i<scalar(@{$ret}) ; $i++){
	push(@{$arrayref}, $ret->[$i]);
    }
}

##--------------------------------------------------------------
## contigIdentifierMappings()
##
##--------------------------------------------------------------
sub contigIdentifierMappings {

    my ($self, $prefix, $asmbl_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    return $self->{_backend}->getContigIdentifierMappings($prefix, $asmbl_id);

}

##--------------------------------------------------------------
## systemObjectsListByType()
##
##--------------------------------------------------------------
sub systemObjectsListByType {

    my ($self, $objectType) = @_;
    
    my $ret = $self->{_backend}->getSystemObjectsListByType($objectType);

    my $array = [];

    for (my $i=0; $i < scalar(@{$ret}); $i++){
	push(@{$array}, $ret->[$i][0]);
    }

    return $array;
}
 
##----------------------------------------------------------------
## retrieve_proteins()
##
## This method will retrieve all of the data from the chado
## tables and generate records to be inserted into the
## chado-mart view called cm_protein
##
##----------------------------------------------------------------
sub retrieve_proteins {

    my ($self) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $transcriptFeatureIdToExonCounts = $self->transcriptFeatureIdToExonCountsLookup();

    my $proteinDetails = $self->{_backend}->getDetailedProteinRecordsForCmProtein();

    print "Pulled ".(scalar(@{$proteinDetails}))." protein records\n";
    if ($self->{_logger}->is_debug()){
	my $proteinCount = scalar(@{$proteinDetails});
	$self->{_logger}->debug("Number of records retrieved from getDetailedProteinRecordsForCmProtein() '$proteinCount'");
    }
    
    my $proteinFeatureIdToCrossReferenceLookup = $self->dbxrefRecordsForCmProteins();
    
    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("proteinFeatureIdToCrossReferenceLookup:" . Dumper $proteinFeatureIdToCrossReferenceLookup);
    }

    ## 0 => protein.feature_id
    ## 1 => protein.uniquename
    ## 2 => cds.feature_id
    ## 3 => gene.feature_id
    ## 4 => transcript.feature_id
    ## 5 => fp.value
    ## 6 => fl.fmin
    ## 7 => fl.fmax
    ## 8 => protein.seqlen
    ## 9 => fl.strand
    ## 10 => fl.srcfeature_id
    ## 11 => protein.organism_id

    my $cmProteinRecords = [];

    ## Want to make sure that we are only processing unique polypeptide records.
    my $proteinFeatureIdLookup = {};

    for (my $i=0; $i < scalar(@{$proteinDetails}); $i++){

        # HACK - providing a value for gene_product_name for genes without one.
        # Since this value is required we need to have something here. This violates
        # the assumption that a query pulling data from cm_proteins will be identical to 
        # a query that pulls the same data from feature/featureprop. However, if this piece of data
        # is not included then genes without gene product names will not be included in cluster queries 
        # for which they are members (since they do not have a cm_proteins record) making the cluster
        # queries out of sync.
        if(($proteinDetails->[$i][5]) eq '') {
            print STDERR "found no gene_product info for $proteinDetails->[$i][1], substituting 'No gene product annotation provided'\n";
            $proteinDetails->[$i][5] = "No gene product annotation provided";
        }
	my $exonCounts;
	if (exists $transcriptFeatureIdToExonCounts->{$proteinDetails->[$i][4]}){
	    $exonCounts = $transcriptFeatureIdToExonCounts->{$proteinDetails->[$i][4]};
	}
	else {
	    $self->{_logger}->logdie("No exon counts for transcript with feature_id ".
				     "'$proteinDetails->[$i][4]'");
	}

	my $accession1;
	my $accession2;
	
	my $proteinFeatureId = $proteinDetails->[$i][0];
	
	if (! exists $proteinFeatureIdLookup->{$proteinFeatureId}){
	    $proteinFeatureIdLookup->{$proteinFeatureId}++;
	}
	else {
 	    $self->{_logger}->warn("Already prepared a cm_proteins record for the polypeptide with feature_id '$proteinFeatureId' ".
				   "having some other gene_product_name value, so we'll skip this one.");
	    next;
	}
	
	if (exists $proteinFeatureIdToCrossReferenceLookup->{$proteinFeatureId} ){
	    
	    $accession1 = !( $proteinFeatureIdToCrossReferenceLookup->{$proteinFeatureId}->[0] eq '' ) 
	    ? $proteinFeatureIdToCrossReferenceLookup->{$proteinFeatureId}->[0] 
	    : $proteinFeatureIdToCrossReferenceLookup->{$proteinFeatureId}->[1];
	    
	    $accession2 =  !( $proteinFeatureIdToCrossReferenceLookup->{$proteinFeatureId}->[1] eq '' )
	    ? $proteinFeatureIdToCrossReferenceLookup->{$proteinFeatureId}->[1] 
	    : $proteinFeatureIdToCrossReferenceLookup->{$proteinFeatureId}->[0];
	    
	}
	
	push ( @{$cmProteinRecords}, [ $proteinFeatureId,
				       $proteinDetails->[$i][1],
				       $proteinDetails->[$i][2],
				       $proteinDetails->[$i][3],
				       $proteinDetails->[$i][4],
				       $exonCounts,
				       $accession1,
				       $accession2,
				       $proteinDetails->[$i][5],
				       $proteinDetails->[$i][6],
				       $proteinDetails->[$i][7],
				       $proteinDetails->[$i][8],
				       $proteinDetails->[$i][9],
				       $proteinDetails->[$i][10],
				       $proteinDetails->[$i][11],
				       ]);
    }
    
    return $cmProteinRecords;
}


##----------------------------------------------------------------
## dbxrefRecordsForCmProteins()
##
##----------------------------------------------------------------
sub dbxrefRecordsForCmProteins {

    my ($self) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret = $self->_uniqueDbxrefRecordsForCmProteins();

    my $proteinLookup = {};
	my $versionPriority = ['display_locus','feat_name','locus','current'];
	
    for (my $i=0; $i < scalar(@{$ret}); $i++){

   $proteinLookup->{$ret->[$i][0]}->{$ret->[$i][1]} = $ret->[$i][2];
    }
	my $finalLookup = {};
	
	# We'll use the versions in versionPriority as the second field in 
	# cm_proteins.accession1 and cm_proteins.accession2. They are used
	# in the priority order listed in versionPriorty (i.e. the best case
	# scenario has display_locus as accession1 and locus as accession2).
	foreach my $prot (keys %$proteinLookup) {
		my $numFound =0;
		for( my $i = 0; $i < @$versionPriority; $i ++) {
			if( $proteinLookup->{$prot}->{$versionPriority->[$i]} ) {
				push(@{$finalLookup->{$prot}},$proteinLookup->{$prot}->{$versionPriority->[$i]});
				if( $numFound ) {
					$i = @$versionPriority;
				}
				else {
					$numFound++;
				}
			}
		}
	}
    return $finalLookup;
}

##----------------------------------------------------------------
## transcriptFeatureIdToExonCountsLookup()
##
##----------------------------------------------------------------
sub transcriptFeatureIdToExonCountsLookup {

    my ($self) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->getTranscriptFeatureIdToExonCounts();
    
    ## 0 => transcript.feature_id
    ## 1 => count(frel.subject_id)

    my $transcriptFeatureIdToExonCountsLookup = {};

    for (my $i=0; $i < scalar(@{$ret}); $i++){

	if (! exists $transcriptFeatureIdToExonCountsLookup->{$ret->[$i][0]}){
	    $transcriptFeatureIdToExonCountsLookup->{$ret->[$i][0]} = $ret->[$i][1];
	}
	else {
	    $self->{_logger}->logdie("Encountered transcript feature_id '$ret->[$i][0]' ".
				     "more than once.  i was '$i'" );
	}
    }
    
    return $transcriptFeatureIdToExonCountsLookup;
}




##----------------------------------------------------------------
## retrieve_clusters_by_analysis_id3()
##
## This method will retrieve all of the data from the chado
## tables and generate records to be inserted into the
## chado-mart view called cm_clusters. It utilizes the
## prepareClusterDataForCalculatingAverages3 which should be
## faster than 2 for large data sets
##
##----------------------------------------------------------------
sub retrieve_clusters_by_analysis_id3 {
    my ($self, $cluster_analysis_id, $align_analysis_id) = @_;

    my $ret = $self->{_backend}->getClusterIdAndMemberCountsByAnalysisId($cluster_analysis_id);
    my $cmClusterRecords;
    
    my $clusterAlignmentData = $self->prepareClusterDataForCalculatingAverages3($cluster_analysis_id, $align_analysis_id);		    
    my $j=-1;
    my $num =0;
    my $lastnum = 0;
    my $total = scalar keys %{$clusterAlignmentData};
    foreach my $cluster_id (sort keys %{$clusterAlignmentData} ) {
        $num++;
        my $per = ($num/$total)*100;
        if(!$lastnum || ($per >= $lastnum+10)) {
            print sprintf("%.2f",$per)."\% complete calculating percentages (prints every 10%) \n";
            $lastnum = $per;
        }
			$j++;

			my $coverage_arr_ref = &getAvgBlastPPctCoverage($clusterAlignmentData->{$cluster_id});
			
			if ($self->{_logger}->is_debug()){
			    $self->{_logger}->debug("coverage_arr_ref for cluster_id '$cluster_id':". Dumper $coverage_arr_ref);
			}
			
			
			my $id_sim_arr_ref = &getAvgBlastPIdSim($clusterAlignmentData->{$cluster_id}); 
			
			if ($self->{_logger}->is_debug()){
			    $self->{_logger}->debug("id_sim_arr_ref for cluster '$cluster_id':". Dumper $id_sim_arr_ref);
			}
			
			
			push (@{$cmClusterRecords}, [ $cluster_id,
						      $cluster_analysis_id,
						      $ret->[$j][1],
						      $ret->[$j][2],
						      $coverage_arr_ref->[0], ## average percent_coverage for the refseq
						      $id_sim_arr_ref->[0]    ## average percent_identity
						      ]);
		    
        }
	return $cmClusterRecords;
}

##----------------------------------------------------------------
## retrieve_clusters_from_cm_blast()
##
## This method will retrieve all of the data from the chado
## tables and generate records to be inserted into the
## chado-mart view called cm_clusters. It utilizes the
## prepareClusterDataForCalculatingAveragesCmBlast()
## method which should be much faster than using the base tables.
##
##----------------------------------------------------------------
sub retrieve_clusters_from_cm_blast {
    my ($self, $cluster_analysis_id) = @_;

    my $ret = $self->{_backend}->getClusterIdAndMemberCountsByAnalysisId($cluster_analysis_id);
    my $cmClusterRecords;
    
    my $clusterAlignmentData = $self->prepareClusterDataForCalculatingAveragesCmBlast($cluster_analysis_id);		    
    my $j=-1;
    foreach my $cluster_id (sort keys %{$clusterAlignmentData} ) {
			
        my $pid_total;
        my $pc_total;
        my $num_hsps = scalar( @{$clusterAlignmentData->{$cluster_id}});
   
        map {
            $pid_total += $_->{'percent_identity'};
            $pc_total += $_->{'percent_coverage'};
        } @{$clusterAlignmentData->{$cluster_id}};
        
        my $avg_pid = $pid_total/$num_hsps;
        my $avg_pc = $pc_total/$num_hsps;
        
        $j++;
        push (@{$cmClusterRecords}, [ $cluster_id,
                                      $cluster_analysis_id,
                                      $ret->[$j][1],
                                      $ret->[$j][2],
                                      $avg_pc, ## average percent_coverage for the refseq
                                      $avg_pid    ## average percent_identity
                                      ]);
		    
        }
	return $cmClusterRecords;
}

##----------------------------------------------------------------
## retrieve_cluster_members_by_analysis_id()
##
## This method will retrieve all of the data from the chado
## tables and generate records to be inserted into the
## chado-mart view called cm_cluster_members
##
##----------------------------------------------------------------
sub retrieve_cluster_members_by_analysis_id {

    my ($self, $analysis_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }

    my $ret = $self->{_backend}->getClusterMembersByAnalysisId($analysis_id);

    my $clusterMemberCount = scalar(@{$ret});

    if ($clusterMemberCount > 0 ){

	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->debug("Retrieved '$clusterMemberCount' cluster members for analysis_id '$analysis_id'");
	}

	my $crossReferenceLookup = $self->crossReferencesForClusterMembersByAnalysisId($analysis_id);
	
	## we'll store the cm_cluster_member
	my $cmClusterMemberRecords = [];
	
	for (my $i=0; $i < scalar(@{$ret}); $i++){
	    
	    my $accession1;
	    my $accession2;
	    
	    if (exists $crossReferenceLookup->{$ret->[$i][1]}){
		($accession1, $accession2) = @{$crossReferenceLookup->{$ret->[$i][1]}};
	    }
	    
	    push (@{$cmClusterMemberRecords}, [ $ret->[$i][0],
						$ret->[$i][1],
						$ret->[$i][2],
						$ret->[$i][3],
						$accession1,
						$accession2
						]);
	}
	
	return $cmClusterMemberRecords;
    }
    else {
	$self->{_logger}->logdie("No cluster members were retrieved from the database for analysis_id '$analysis_id'");
    }
}


##----------------------------------------------------------------
## crossReferencesForClusterMembersByAnalysisId()
##
##
##----------------------------------------------------------------
sub crossReferencesForClusterMembersByAnalysisId {

    my ($self, $analysis_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->getCrossReferencesForClusterMembersByAnalysisId($analysis_id);

    my $lookup = {};

    for (my $i=0; $i < scalar(@{$ret}); $i++){

	push (@{$lookup->{$ret->[$i][0]}}, $ret->[$i][1]);

    }

    return $lookup;
}


##----------------------------------------------------------------
## storeRecordsInCmProteins()
##
##----------------------------------------------------------------
sub storeRecordsInCmProteins {

    my ($self, $records) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $recctr = 0;

    foreach my $rec (@{$records}){

	my $cm_proteins_id = $self->{_backend}->doStoreRecordsInCmProteins(
									   'protein_id'    => $rec->[0],
									   'uniquename'    => $rec->[1],
									   'cds_id'        => $rec->[2],
									   'gene_id'       => $rec->[3],
									   'transcript_id' => $rec->[4],
									   'exon_count'    => $rec->[5],
									   'accession1'    => $rec->[6],
									   'accession2'    => $rec->[7],
									   'gene_product_name' => $rec->[8],
									   'fmin'          => $rec->[9],
									   'fmax'          => $rec->[10],
									   'seqlen'        => $rec->[11],
									   'strand'        => $rec->[12],
									   'srcfeature_id' => $rec->[13],
									   'organism_id'   => $rec->[14]
									   );
	
	if (!defined($cm_proteins_id)){
	    $self->{_logger}->logdie("cm_proteins_id was not defined for protein_id ".
				     "'$rec->[0]'.  Check the log file.");
	}

	$recctr++;
    }

    return $recctr;
}

##----------------------------------------------------------------
## storeRecordsInCmClusters()
##
##----------------------------------------------------------------
sub storeRecordsInCmClusters {

    my ($self, $records) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $recctr=0;

    foreach my $rec (@{$records}){
	
	my $cm_clusters_id = $self->{_backend}->doStoreRecordsInCmClusters(
									   'cluster_id'       => $rec->[0],
									   'analysis_id'      => $rec->[1],
									   'num_members'      => $rec->[2],
									   'num_organisms'    => $rec->[3],
									   'percent_coverage' => $rec->[4],
									   'percent_identity' => $rec->[5]
									   );
	if (!defined($cm_clusters_id)){
	    $self->{_logger}->logdie("cm_clusters_id was not defined for cluster_id '$rec->[0]' analysis_id '$rec->[1]' ".
				     "num_members '$rec->[2]' num_organisms '$rec->[3]' percent_coverage '$rec->[4]' ".
				     "percent_identity '$rec->[5]'");
	}
	
	$recctr++;
    }

    return $recctr;
}

##----------------------------------------------------------------
## storeRecordsInCmClusterMembers()
##
##----------------------------------------------------------------
sub storeRecordsInCmClusterMembers {

    my ($self, $records) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $recctr=0;

    foreach my $rec (@{$records}){

	if (!defined($rec->[5])){
	    $rec->[5] = $rec->[4];
	}

	my $cm_cluster_members_id = $self->{_backend}->doStoreRecordsInCmClusterMembers(
											'cluster_id'  => $rec->[0],
											'feature_id'  => $rec->[1],
											'organism_id' => $rec->[2],
											'uniquename'  => $rec->[3],
											'accession1'  => $rec->[4],
											'accession2'  => $rec->[5]
											);
	if (!defined($cm_cluster_members_id)){
	    $self->{_logger}->logdie("cm_cluster_members_id was not defined for cluster_id '$rec->[0]' feature_id '$rec->[1]' ".
				     "organism_id '$rec->[2]' uniquename '$rec->[3]' accession1 '$rec->[4]' accession2 '$rec->[5]'");
	}

	$recctr++;
    }
    
    return $recctr;
}


##---------------------------------------------------------
## cvtermIdListByCvId()
##
##---------------------------------------------------------
sub cvtermIdListByCvId {

    my ($self, $cv_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($cv_id)){
	$self->{_logger}->logdie("cv_id was not defined");
    }

    my $ret = $self->{_backend}->getCvtermIdListByCvId($cv_id);

    my $list = [];

    for (my $i=0;$i<scalar(@{$ret}); $i++){
	push( @{$list}, $ret->[$i][0]);
    }

    return $list;
}

##---------------------------------------------------------
## cvtermRelationshipLookupsByCvId()
##
##---------------------------------------------------------
sub cvtermRelationshipLookupsByCvId {

    my ($self, $cv_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($cv_id)){
	$self->{_logger}->logdie("cv_id was not defined");
    }

    my $ret = $self->{_backend}->getCvtermRelationshipForClosure($cv_id);

    my $lookup = {};

    for (my $i=0;$i<scalar(@{$ret}); $i++){
	push( @{$lookup->{$ret->[$i][0]}},  [ $ret->[$i][1],
					      $ret->[$i][2] ] );
    }

    return $lookup;
}

##------------------------------------------------
## storeCvtermPathRecords()
##
##------------------------------------------------
sub storeCvtermPathRecords {

    my ($self, $cvtermpathLookup, $cv_id) = @_;

    ## now create the cvtermpath records
    foreach my $subject_id ( keys %{$cvtermpathLookup}){
	foreach my $object_id ( keys %{$cvtermpathLookup->{$subject_id}}){
	
	    my $type_id = $cvtermpathLookup->{$subject_id}->{$object_id}->[0];
	    my $pathdistance = $cvtermpathLookup->{$subject_id}->{$object_id}->[1];
	    
	    my $cvtermpath_id = $self->checkCvtermPathIdCachedLookup( 'type_id' => $type_id,
								      'subject_id' => $subject_id,
								      'object_id' => $object_id,
								      'cv_id' => $cv_id,
								      'pathdistance' => $pathdistance
								      );
	    if (!defined($cvtermpath_id)){
		## only insert records if the cvtermpath record 
		## does not already exist
		$self->{_backend}->do_store_new_cvtermpath( 'type_id' => $type_id,
							    'subject_id' => $subject_id,
							    'object_id' => $object_id,
							    'cv_id' => $cv_id,
							    'pathdistance' => $pathdistance
							    );
	    }
	    else {
		$self->{_logger}->warn("cvtermpath record with type_id '$type_id' ".
				       "subject_id '$subject_id' ".
				       "object_id '$object_id' ".
				       "cv_id '$cv_id' ".
				       "pathdistance '$pathdistance' ".
				       "already exists");
	    }
	}
    }
}


##---------------------------------------------------------
## generateCvtermPathIdCachedLookup()
##
##---------------------------------------------------------
sub generateCvtermPathIdCachedLookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cvtermpath_id_cached_lookup'} = $self->{_backend}->getCvtermPathIdCachedLookup();
}

##---------------------------------------------------------
## checkCvtermPathIdCachedLookup()
##
##---------------------------------------------------------
sub checkCvtermPathIdCachedLookup {

    my ($self, %param) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $cvtermpath_id_cached_lookup;

    if (( exists $self->{'cvtermpath_id_cached_lookup'}) && (defined($self->{'cvtermpath_id_cached_lookup'}) )) {

	$cvtermpath_id_cached_lookup = $self->{'cvtermpath_id_cached_lookup'};
    }
    else {
	$self->{_logger}->logdie("cvtermpath_id cached lookup was not defined");
    }

    my $type_id;
    my $subject_id;
    my $object_id;
    my $cv_id;
    my $pathdistance;


    if (( exists $param{'type_id'}) && (defined($param{'type_id'}))) {
	$type_id = $param{'type_id'};
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }


    if (( exists $param{'subject_id'}) && (defined($param{'subject_id'}))) {
	$subject_id = $param{'subject_id'};
    }
    else {
	$self->{_logger}->logdie("subject_id was not defined");

    }

    if (( exists $param{'object_id'}) && (defined($param{'object_id'}))) {
	$object_id = $param{'object_id'};
    }
    else {
	$self->{_logger}->logdie("object_id was not defined");
    }

    if (( exists $param{'cv_id'}) && (defined($param{'cv_id'}))) {
	$cv_id = $param{'cv_id'};
    }
    else {
	$self->{_logger}->logdie("cv_id was not defined");
    }

    if (( exists $param{'pathdistance'}) && (defined($param{'pathdistance'}))) {
	$pathdistance = $param{'pathdistance'};
    }
    else {
	$self->{_logger}->logdie("pathdistance was not defined");
    }

    my $status;

    if (( exists $param{'status'}) && (defined($param{'status'}))) {
	$status = $param{'status'};
    }

    ## build the key
    my $index = $type_id . '_' . $subject_id . '_' . $object_id . '_' . $cv_id . '_'. $pathdistance;

    if ( exists $cvtermpath_id_cached_lookup->{$index}){
	my $cvtermpath_id = $cvtermpath_id_cached_lookup->{$index}->[0];

	if (defined($cvtermpath_id)){
	    return $cvtermpath_id;
	}
    }

    return undef;
}


##----------------------------------------------------------------
## organismData()
##
##----------------------------------------------------------------
sub organismData {

    my ($self) = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->getOrganismData(@_);

}


##----------------------------------------------------------------
## createTIGRCrossReferencePrefix()
##
##----------------------------------------------------------------
sub createTIGRCrossReferencePrefix {

    my ($self, $database) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($database)){
	$self->{_logger}->logdie("database was not defined");
    }

    my $prefix = 'TIGR_' . ucfirst($database);

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("prefix is '$prefix' for database '$database'");
    }
    
    return $prefix;
}

##----------------------------------------------------------------
## assemblyUniquenameList()
##
##----------------------------------------------------------------
sub assemblyUniquenameList {

    my ($self) = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->getAssemblyUniquenameList();

    ## 0 => feature.uniquename WHERE feature.type_id = cvterm.cvterm_id AND cvterm.name = 'assembly'

    my $asmblList = [];

    for (my $i=0 ; $i < scalar(@{$ret}); $i++){
	push ( @{$asmblList}, $ret->[$i][0]);
    }
    
    return $asmblList;
}


##----------------------------------------------------------------
## organismDataByFeatureUniquename()
##
##----------------------------------------------------------------
sub organismDataByFeatureUniquename {

    my ($self, $asmbl) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->getOrganismDataByFeatureUniquename($asmbl);

    ## 0 => organism.genus WHERE o.organism_id = f.organism_id AND f.uniquename = asmbl
    ## 1 => organism.species WHERE o.organism_id = f.organism_id AND f.uniquename = asmbl
    ## 2 => organismprop.value WHERE organismprop.type_id = cvterm.cvterm_id AND cvterm.name = 'strain'
    ## 3 => organism.abbreviation WHERE o.organism_id = f.organism_id AND f.uniquename = asmbl
    ## 4 => organismprop.value WHERE organismprop.type_id = cvterm.cvterm_id AND cvterm.name = 'genetic_code'
    ## 5 => organismprop.value WHERE organismprop.type_id = cvterm.cvterm_id AND cvterm.name = 'mt_genetic_code'
    ## 6 => organismprop.value WHERE organismprop.type_id = cvterm.cvterm_id AND cvterm.name = 'gram_stain'
    ## 7 => organism.comment WHERE o.organism_id = f.organism_id AND f.uniquename = asmbl
    ## 8 => organismprop.value WHERE organismprop.type_id = cvterm.cvterm_id AND cvterm.name = 'translation_table'

    my $lookup = {};

    $lookup->{'genus'} = $ret->[0][0];
    $lookup->{'species'} = $ret->[0][1];
    $lookup->{'strain'} = $ret->[0][2];
    $lookup->{'abbreviation'} = $ret->[0][3];
    $lookup->{'genetic_code'} = $ret->[0][4];
    $lookup->{'mt_genetic_code'} = $ret->[0][5];
    $lookup->{'gram_stain'} = $ret->[0][6];
    $lookup->{'comment'} = $ret->[0][7];
    $lookup->{'translation_table'} = $ret->[0][8];

    return $lookup;
}

#----------------------------------------------------
# deriveSequenceSecondaryType()
#
#----------------------------------------------------
sub deriveSequenceSecondaryType {

    my ($self, $molecule_name) = @_;

    my $secondaryTypeLookup = { 'pseudomolecule' => 'supercontig',
				'pseudo' => 'supercontig',
				'plasmid' => 'plasmid',
				'chromosome' => 'chromosome' };
    

    my $secondaryType;
    
    foreach my $moleculeType ( keys %{$secondaryTypeLookup} ) {
	if ($molecule_name =~ /$moleculeType/){
	    $secondaryType = $secondaryTypeLookup->{$moleculeType};
	    last;
	}
    }

    if (! defined ($secondaryType) ) {
	
	$self->{_logger}->warn("Molecular name '$molecule_name' was not recognized. ".
			       "Setting default value 'assembly' for sequence secondary type.");
	
	$secondaryType = 'assembly';
	
    }
    
    return $secondaryType;

}



#----------------------------------------------------
# sequenceDataByUniquename()
#
#----------------------------------------------------
sub sequenceDataByUniquename {

    my ($self, $uniquename) = @_;

    ## Set the max text size for sequence and protein data fields
    $self->{_backend}->do_set_textsize(TEXTSIZE);

    my $ret = $self->{_backend}->getSequenceDataByFeatureUniquename($uniquename);

    ## 0 => feature.seqlen
    ## 1 => feature.residues
    ## 2 => featureprop.value WHERE featureprop.type_id = cvterm.cvterm_id AND cvterm.name = 'molecule_name'
    ## 3 => featureprop.value WHERE featureprop.type_id = cvterm.cvterm_id AND cvterm.name = 'molecule_type'
    ## 4 => feature_cvterm.feature_cvterm_id WHERE feature_cvterm.cvterm_id = cvterm.cvterm_id AND cvterm.name = 'Primary_annotation'
    ## 5 => feature_cvterm.feature_cvterm_id WHERE feature_cvterm.cvterm_id = cvterm.cvterm_id AND cvterm.name = 'TIGR_annotation'
    ## 6 => undef
    ## 7 => featureprop.value WHERE featureprop.type_id = cvterm.cvterm_id AND cvterm.name = 'topology'

    my $lookup = {};

    $lookup->{'length'} = $ret->[0][0];
    $lookup->{'sequence'} = $ret->[0][1];

    if (defined($ret->[0][2])){
	$lookup->{'molecule_name'} = $ret->[0][2];
    }

    if (defined($ret->[0][3])){
	$lookup->{'molecule_type'} = $ret->[0][3];
    }

    if (defined($ret->[0][4])){
	## If there is such a feature_cvterm record, then we set the flag = 1
	$lookup->{'Primary_annotation'} = 1;
    }

    if (defined($ret->[0][5])){
	## If there is such a feature_cvterm record, then we set the flag = 1
	$lookup->{'TIGR_annotation'} = 1;
    }

    if (defined($ret->[0][6])){
	$lookup->{'subfeatureCount'} = $ret->[0][6];
    }

    if (defined($ret->[0][6])){
	$lookup->{'topology'} = $ret->[0][7];
    }

    return $lookup;

}

#----------------------------------------------------
# doesSequenceHaveLocalizedSubfeatures()
#
#----------------------------------------------------
sub doesSequenceHaveLocalizedSubfeatures {

    my ($self, $uniquename) = @_;

    my $ret = $self->{_backend}->getSequenceSubfeatureCount($uniquename);
    
    my $retval=0;

    if (defined($ret->[0][0])){

	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->debug("Number of subfeatures localized to sequence with uniquename '$uniquename' ".
				    "is '$ret->[0][0]'");
	}

	if ($ret->[0][0] > 0) {
	    return 1;
	}
    }

    return $retval;

}

#----------------------------------------------------
# doesSequenceHaveLocalizedPolypeptideFeatures()
#
#----------------------------------------------------
sub doesSequenceHaveLocalizedPolypeptideFeatures {

    my ($self, $uniquename) = @_;

    my $ret = $self->{_backend}->getSequencePolypeptideCount($uniquename);
    
    my $retval=0;

    if (defined($ret->[0][0])){

	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->debug("Number of polypeptide features localized to sequence with uniquename '$uniquename' ".
				    "is '$ret->[0][0]'");
	}

	if ($ret->[0][0] > 0) {
	    return 1;
	}
    }

    return $retval;

}

#----------------------------------------------------
# organismCrossReferenceDataByUniquename()
#
#----------------------------------------------------
sub organismCrossReferenceDataByUniquename {

    my ($self, $uniquename) = @_;

    my $ret = $self->{_backend}->getOrganismCrossReferenceDataByFeatureUniquename($uniquename);
    ## 0 => db.name
    ## 1 => dbxref.accession
    ## 2 => dbxref.version
    ## 3 => dbxrefprop.value WHERE dbxrefprop.type_id = cvterm.cvterm_id AND cvterm.name = 'source_database'
    ## 4 => dbxrefprop.value WHERE dbxrefprop.type_id = cvterm.cvterm_id AND cvterm.name = 'schema_type'

    my $lookup = [];
    
    for (my $i=0; $i < scalar(@{$ret}); $i++ ){

	my $hash = {};
	
	$hash->{'name'} = $ret->[$i][0];
	$hash->{'accession'} = $ret->[$i][1];
	$hash->{'version'} = $ret->[$i][2];
	$hash->{'source_database'} = $ret->[$i][3];
	$hash->{'schema_type'} = $ret->[$i][4];

	push(@{$lookup}, $hash);
    }

    return $lookup;

}

#----------------------------------------------------
# subfeatureDataByAssembly()
#
#----------------------------------------------------
sub subfeatureDataByAssembly {

    my ($self, $uniquename) = @_;

    my $ret = $self->{_backend}->getSubfeatureDataByAssemblyFeatureUniquename($uniquename);

    ## 0 => feature.uniquename
    ## 1 => feature.seqlen
    ## 2 => feature.residues
    ## 3 => cvterm.name WHERE cvterm.cvterm_id = feature.type_id
    ## 4 => featureloc.fmin
    ## 5 => featureloc.fmax
    ## 6 => featureloc.strand
    ## 7 => featureloc.is_fmin_partial
    ## 8 => featureloc.is_fmax_partial

    my $lookup = {};
    
    for (my $i=0; $i < scalar(@{$ret}); $i++ ){

	push(@{$lookup->{$uniquename}}, $ret->[$i]);
    }

    return $lookup;

}

#----------------------------------------------------
# polypeptideDataByAssembly()
#
#----------------------------------------------------
sub polypeptideDataByAssembly {

    my ($self, $uniquename) = @_;

    my $ret = $self->{_backend}->getPolypeptideDataByAssemblyFeatureUniquename($uniquename);

    ## 0 => feature.uniquename
    ## 1 => feature.seqlen
    ## 2 => feature.residues
    ## 3 => cvterm.name WHERE cvterm.cvterm_id = feature.type_id
    ## 4 => featureloc.fmin
    ## 5 => featureloc.fmax
    ## 6 => featureloc.strand

    my $lookup = {};
    
    for (my $i=0; $i < scalar(@{$ret}); $i++ ){

	push(@{$lookup->{$uniquename}}, $ret->[$i]);
    }

    return $lookup;

}

#----------------------------------------------------
# allSubfeaturePropertiesDataByAssembly()
#
#----------------------------------------------------
sub allSubfeaturePropertiesDataByAssembly {

    my ($self, $uniquename) = @_;

    my $ret = $self->{_backend}->getAllSubfeaturePropertiesDataByAssemblyFeatureUniquename($uniquename);

    ## 0 => feature.uniquename
    ## 1 => featureprop.value
    ## 2 => cvterm.name WHERE cvterm.cvterm_id = featureprop.type_id

    my $lookup = {};
    
    for (my $i=0; $i < scalar(@{$ret}); $i++ ){

	my $featureUniquename = shift(@{$ret->[$i]});

	push(@{$lookup->{$featureUniquename}}, $ret->[$i]);
    }

    return $lookup;

}

#----------------------------------------------------
# allSubfeatureCrossReferenceDataByAssembly()
#
#----------------------------------------------------
sub allSubfeatureCrossReferenceDataByAssembly {

    my ($self, $uniquename) = @_;

    my $ret = $self->{_backend}->getAllSubfeatureCrossReferenceDataByAssemblyFeatureUniquename($uniquename);

    ## 0 => feature.feature_id
    ## 1 => db.name
    ## 2 => dbxref.accession
    ## 3 => dbxref.version

    my $lookup = {};
    
    for (my $i=0; $i < scalar(@{$ret}); $i++ ){
	
	my $featureUniquename = shift(@{$ret->[$i]});

	push(@{$lookup->{$featureUniquename}}, $ret->[$i]);
    }

    return $lookup;

}
 

#----------------------------------------------------
# allGOAssignmentsForSubfeaturesByAssembly()
#
#----------------------------------------------------
sub allGOAssignmentsForSubfeaturesByAssembly {

    my ($self, $uniquename) = @_;

    my $ret = $self->{_backend}->getAllGOAssignmentsForSubfeaturesByAssemblyFeatureUniquename($uniquename);

    ## 0 => feature.uniquename
    ## 1 => dbxref.accession
    ## 2 => feature_cvterm.feature_cvterm_id

    my $lookup = {};

    if (defined($ret)){

      for (my $i=0; $i < scalar(@{$ret}); $i++ ){
	
	my $feature_id = shift(@{$ret->[$i]});

	push(@{$lookup->{$feature_id}}, $ret->[$i]);
      }
    }

    return $lookup;
}

#----------------------------------------------------
# allGOAssignmentAttributesForSubfeaturesByAssembly()
#
#----------------------------------------------------
sub allGOAssignmentAttributesForSubfeaturesByAssembly {

    my ($self, $uniquename) = @_;

    my $ret = $self->{_backend}->getAllGOAssignmentAttributesForSubfeaturesByAssemblyFeatureUniquename($uniquename);

    ## 0 => feature.uniquename
    ## 1 => dbxref.accession
    ## 2 => feature_cvterm.feature_cvterm_id

    my $lookup = {};

    if (defined($ret)){

      for (my $i=0; $i < scalar(@{$ret}); $i++ ){

	my $feature_id = shift(@{$ret->[$i]});

	push(@{$lookup->{$feature_id}}, $ret->[$i]);
      }
    }

    return $lookup;
}

#----------------------------------------------------
# evidenceCodesLookup()
#
#----------------------------------------------------
sub evidenceCodesLookup {

    my ($self) = @_;

    my $ret = $self->{_backend}->getEvidenceCodesLookup();

    ## 0 => cvterm.name
    ## 1 => cvtermsynonym.synonym

    my $lookup = {};
    
    for (my $i=0; $i < scalar(@{$ret}); $i++ ){
	
	$lookup->{$ret->[$i][0]} = $ret->[$i][1];
    }

    return $lookup;

}


#----------------------------------------------------
# allNonGOAssignmentsForSubfeaturesByAssembly()
#
#----------------------------------------------------
sub allNonGOAssignmentsForSubfeaturesByAssembly {

    my ($self, $uniquename) = @_;

    my $ret = $self->{_backend}->getAllNonGOAssignmentsForSubfeaturesByAssemblyFeatureUniquename($uniquename);

    ## 0 => feature.uniquename
    ## 1 => cv.name
    ## 2 => dbxref.accession
    ## 3 => feature_cvterm.feature_cvterm_id

    my $lookup = {};

    if (defined($ret)){

      for (my $i=0; $i < scalar(@{$ret}); $i++ ){

	my $feature_id = shift(@{$ret->[$i]});

	push(@{$lookup->{$feature_id}}, $ret->[$i]);
      }
    }

    return $lookup;
}

#----------------------------------------------------
# allNonGOAssignmentAttributesForSubfeaturesByAssembly()
#
#----------------------------------------------------
sub allNonGOAssignmentAttributesForSubfeaturesByAssembly {

    my ($self, $uniquename) = @_;

    my $ret = $self->{_backend}->getAllNonGOAssignmentAttributesForSubfeaturesByAssemblyFeatureUniquename($uniquename);

    ## 0 => feature.uniquename
    ## 1 => dbxref.accession
    ## 2 => feature_cvterm.feature_cvterm_id

    my $lookup = {};

    if (defined($ret)){

      for (my $i=0; $i < scalar(@{$ret}); $i++ ){

	my $feature_id = shift(@{$ret->[$i]});

	push(@{$lookup->{$feature_id}}, $ret->[$i]);
      }
    }

    return $lookup;
}

#----------------------------------------------------
# crossReferenceDataByUniquename()
#
#----------------------------------------------------
sub crossReferenceDataByUniquename {

    my ($self, $uniquename) = @_;

    my $ret = $self->{_backend}->getCrossReferenceDataByFeatureUniquename($uniquename);
    ## 0 => db.name
    ## 1 => dbxref.accession
    ## 2 => dbxref.version

    my $lookup = [];
    
    for (my $i=0; $i < scalar(@{$ret}); $i++ ){

	my $hash = {};

	$hash->{'name'} = $ret->[$i][0];
	$hash->{'accession'} = $ret->[$i][1];
	$hash->{'version'} = $ret->[$i][2];
	
	push(@{$lookup}, $hash);
    }


    return $lookup;

}



#----------------------------------------------------
# allSubfeaturesAnalysisByAssembly()
#
#----------------------------------------------------
sub allSubfeaturesAnalysisByAssembly {

    my ($self, $uniquename) = @_;

    my $ret = $self->{_backend}->getAllSubfeaturesAnalysisByAssembly($uniquename);

    my $lookup = {};

    for (my $i=0;  $i < scalar(@{$ret}) ; $i++){
	my $uniquename = shift(@{$ret->[$i]});

	push(@{$lookup->{$uniquename}}, $ret->[$i]);

    }

    return $lookup;
}

#----------------------------------------------------
# featureRelationshipsBySequenceFeatureUniquename()
#
#----------------------------------------------------
sub featureRelationshipsBySequenceFeatureUniquename {

    my ($self, $uniquename) = @_;

    return $self->{_backend}->getAllFeatureRelationshipsBySequenceFeatureUniquename($uniquename);

}

#----------------------------------------------------
# allAnalysisData()
#
#----------------------------------------------------
sub allAnalysisData {

    my ($self) = @_;

    my $ret = $self->{_backend}->getAllAnalysisData();

    ## 0 => program
    ## 1 => programversion
    ## 2 => sourcename
    ## 3 => description
    ## 4 => analysis_id

    my $lookup = {};

    for (my $i=0;  $i < scalar(@{$ret}) ; $i++){

	my $program = $ret->[$i]->[0];

	$lookup->{$program} = $ret->[$i];
    }

    return $lookup;
}

#----------------------------------------------------
# allAnalysisProperties()
#
#----------------------------------------------------
sub allAnalysisProperties {

    my ($self) = @_;

    my $ret = $self->{_backend}->getAllAnalysisProperties();

    ## 0 => analysisprop.analysis_id
    ## 1 => cvterm.name
    ## 2 => analysisprop.value

    my $lookup = {};

    for (my $i=0;  $i < scalar(@{$ret}) ; $i++){
	my $analysis_id = shift(@{$ret->[$i]});

	push(@{$lookup->{$analysis_id}}, $ret->[$i]);

    }

    return $lookup;
}



#----------------------------------------------------
# allSubfeaturesNotLocalizedToSomeAssembly()
#
#----------------------------------------------------
sub allSubfeaturesNotLocalizedToSomeAssembly {

    my ($self, $uniquename) = @_;

    my $ret = $self->{_backend}->getAllSubfeaturesNotLocalizedToSomeAssembly($uniquename);

    ## 0 => feature.uniquename
    ## 1 => feature.seqlen
    ## 2 => feature.residues
    ## 3 => cvterm.name WHERE cvterm.cvterm_id = feature.type_id
    ## 4 => featureloc.fmin
    ## 5 => featureloc.fmax
    ## 6 => featureloc.strand

    my $lookup = {};
    
    for (my $i=0; $i < scalar(@{$ret}); $i++ ){

	my $parentFeatureUniquename = shift(@{$ret->[$i]});

	push(@{$lookup->{$parentFeatureUniquename}}, $ret->[$i]);
    }

    return $lookup;

}

#----------------------------------------------------
# allPropertiesForSubfeaturesNotLocalizedToSomeAssembly()
#
#----------------------------------------------------
sub allPropertiesForSubfeaturesNotLocalizedToSomeAssembly {

    my ($self, $uniquename) = @_;


    my $lookup = {};

    foreach my $parent ('polypeptide'){
	foreach my $child ('signal_peptide', 'splice_site'){

	    my $ret = $self->{_backend}->getAllPropertiesForAllSubfeaturesNotLocalizedToSomeAssembly($uniquename, $parent, $child);
	    
	    ## 0 => feature.feature_id
	    ## 1 => featureprop.value
	    ## 2 => cvterm.name WHERE cvterm.cvterm_id = featureprop.type_id
	    
	    
	    for (my $i=0; $i < scalar(@{$ret}); $i++ ){
		
		
		my $parentFeatureUniquename = shift(@{$ret->[$i]});
		my $childFeatureUniquename = shift(@{$ret->[$i]});
		push(@{$lookup->{$parentFeatureUniquename}->{$childFeatureUniquename}}, $ret->[$i]);
	    }
	}
    }

    return $lookup;

}

#----------------------------------------------------
# allCrossReferenceForSubfeaturesNotLocalizedToSomeAssembly()
#
#----------------------------------------------------
sub allCrossReferenceForSubfeaturesNotLocalizedToSomeAssembly {

    my ($self, $uniquename) = @_;


    my $lookup = {};

    foreach my $parent ('polypeptide'){
	foreach my $child ('signal_peptide', 'splice_site'){
	    
	    my $ret = $self->{_backend}->getAllCrossReferenceForAllSubfeaturesNotLocalizedToSomeAssembly($uniquename, $parent, $child);

	    ## 0 => feature.feature_id
	    ## 1 => db.name
	    ## 2 => dbxref.accession
	    ## 3 => dbxref.version
	    
	    for (my $i=0; $i < scalar(@{$ret}); $i++ ){
		
		my $parentFeatureUniquename = shift(@{$ret->[$i]});
		my $childFeatureUniquename = shift(@{$ret->[$i]});
		push(@{$lookup->{$parentFeatureUniquename}->{$childFeatureUniquename}}, $ret->[$i]);
	    }
	}
    }

    return $lookup;

}
 


#---------------------------------------------------------------
# createMultiFASTAFile()
#
#---------------------------------------------------------------
sub createMultiFASTAFile {

    my ($self, $fastasequences, $fastadir, $db, $backup) = @_;

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
		    $self->{_logger}->info("Copying '$fastafile' to '$fastabak'");
		}
	    }

	    open (FASTA, ">$fastafile") or $self->{_logger}->logdie("Can't open file $fastafile for writing: $!");


	    foreach my $sequence ( @{$fastasequences->{$asmbl_id}->{$seqtype}} ) {
		
		my $fastaout = &fasta_out($sequence->[0], $sequence->[1]);
		print FASTA $fastaout;
		
	    }

	    close FASTA;
	    chmod 0666, $fastafile;
	}
    }



}


#---------------------------------------------------------------
# writeSingleFastaRecordToFastaFile()
#
#---------------------------------------------------------------
sub writeSingleFastaRecordToFastaFile {

    my ($self, $identifier, $fastaFile, $sequence) = @_;

    if (!defined($identifier)){
	$self->{_logger}->logdie("identifer was not defined");
    }

    if (!defined($fastaFile)){
	$self->{_logger}->logdie("fastaFile was was not defined for identifier '$identifier'");
    }

    if (!defined($sequence)){
	$self->{_logger}->logdie("sequence was not defined for identifier '$identifier'");
    }

    if (-e $fastaFile){
	my $bakfile = $fastaFile . '.bak';
	copy($fastaFile,$bakfile);
	$self->{_logger}->warn("Overwriting FASTA file '$fastaFile'.  Backup saved as '$bakfile'.");
    }

    open (FASTAFILE, ">$fastaFile") || $self->{_logger}->logdie("Could not open FASTA file '$fastaFile' in append mode");

    my $fastaout = &fasta_out($identifier, $sequence);

    print FASTAFILE $fastaout;

    close FASTAFILE;
    chmod 0666, $fastaFile;

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
 
##----------------------------------------------------------------
## retrieveCvtermIdForGOID()
##
##----------------------------------------------------------------
sub retrieveCvtermIdForGOID {

    my ($self, $goId) = @_;

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("retrieveCvtermIdForGOID for GO ID '$goId'") 
    }

    my $GOIDToCvtermIdLookup;

    if (( exists $self->{'GOIDToCvtermIdLookup'}) && (defined($self->{'GOIDToCvtermIdLookup'}) )) {

	$GOIDToCvtermIdLookup = $self->{'GOIDToCvtermIdLookup'};

	if (( exists $GOIDToCvtermIdLookup->{$goId}->[0]) && (defined($GOIDToCvtermIdLookup->{$goId}->[0]))){
	    return $GOIDToCvtermIdLookup->{$goId}->[0];
	}
	else {
	    return undef;
	}
    }
    else {
	$self->{_logger}->logdie("GOIDToCvtermIdLookup");
    }
}

##---------------------------------------------------------
## GOIDToCvtermIdLookup()
##
##---------------------------------------------------------
sub GOIDToCvtermIdLookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'GOIDToCvtermIdLookup'} = $self->{_backend}->getGOIDToCvtermIdLookup();
    
}


#----------------------------------------------------
# allComputationalAnalysisDataByAssembly()
#
#----------------------------------------------------
sub allComputationalAnalysisDataByAssembly {

    my ($self, $uniquename, $qualifiedComputationalAnalysisLookup) = @_;

    my $lookup = {};

    foreach my $program ( keys %{$qualifiedComputationalAnalysisLookup} ){

	my $ret = $self->{_backend}->getAllComputationalAnalysisDataByAssemblyAndProgram($uniquename, $program);
	
	## 0 => feature.uniquename // refseq
	## 1 => feature.uniquename // compseq
	## 2 => featureloc.fmin
	## 3 => featureloc.fmax
	## 4 => featureloc.strand
	## 5 => featureloc.fmin
	## 6 => featureloc.fmax
	## 7 => featureloc.strand
	## 8 => analysisfeature.rawscore
	## 9 => analysisfeature.runscore
	## 10 => feature.residues   // match_part
	## 11 => feature.feature_id // match_part feature
	for (my $i=0; $i < scalar(@{$ret}); $i++ ){
	    
	    my $query = shift(@{$ret->[$i]});
	    my $subject = shift(@{$ret->[$i]});
	    
	    push(@{$lookup->{$program}->{$query}->{$subject}}, $ret->[$i]);
	}
    }

    return $lookup;

}

#----------------------------------------------------
# allMatchPartPropertiesLookup()
#
#----------------------------------------------------
sub allMatchPartPropertiesLookup {

    my ($self, $uniquename, $qualifiedComputationalAnalysisLookup) = @_;

    my $lookup = {};
    
    foreach my $program ( keys %{$qualifiedComputationalAnalysisLookup} ) {
	
	my $ret = $self->{_backend}->getAllMatchPartPropertiesByAssemblyAndProgram($uniquename, $program);
	
	## 0 => feature.feature_id
	## 1 => cvterm.name WHERE cvterm.cvterm_id = featureprop.type_id
	## 2 => featureprop.value
	for (my $i=0; $i < scalar(@{$ret}); $i++ ){
	    
	    my $feature_id = shift(@{$ret->[$i]});
	    push(@{$lookup->{$feature_id}}, $ret->[$i]);
	}
    }


    return $lookup;

}

#----------------------------------------------------
# allComputationalAnalysisSubjectsCrossReference()
#
#----------------------------------------------------
sub allComputationalAnalysisSubjectsCrossReference {

    my ($self, $uniquename, $qualifiedComputationalAnalysisLookup) = @_;
    
    my $lookup = {};
    
    foreach my $program ( keys %{$qualifiedComputationalAnalysisLookup} ){
	
	my $ret = $self->{_backend}->getAllComputationalAnalysisSubjectsCrossReferenceByAssemblyAndProgram($uniquename, $program);
	
	## 0 => feature.uniquename
	## 1 => db.name
	## 2 => dbxref.accession
	## 3 => dbxref.version
	
	for (my $i=0; $i < scalar(@{$ret}); $i++ ){
	    
	    my $uniquename = shift(@{$ret->[$i]});
	    
	    push(@{$lookup->{$uniquename}}, $ret->[$i]);
	}
    }

    return $lookup;

}


##----------------------------------------------------
## analysisIdForProgram()
##
##----------------------------------------------------
sub analysisIdForProgram {

    my ($self, $program) = @_;
    
    if (!defined($program)){
	$self->{_logger}->logdie("program was not defined");
    }
	    
    return $self->{_backend}->getAnalysisIdForProgram($program);

}

##----------------------------------------------------
## isAnalysisIdValid()
##
##----------------------------------------------------
sub isAnalysisIdValid {

    my ($self, $analysis_id) = @_;
    
    if (defined($analysis_id)){
	if ($analysis_id =~ /^\d+$/){
	    my $ret = $self->{_backend}->doesAnalysisIdExistInAnalysis($analysis_id);
	    
	    if (defined($ret->[0][0])){
		return 1;
	    }
	}
    }
    return 0;

}


##----------------------------------------------------------------
## prepareClusterDataForCalculatingAverages()
##
##----------------------------------------------------------------
sub prepareClusterDataForCalculatingAverages {

    my ($self, $cluster_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($cluster_id)){
	$self->{_logger}->logdie("cluster_id was not defined");
    }

    ## An array of hash references for each query_id
    my $hsp_ref_array = [];

    my $ret = $self->{_backend}->getPairwiseAlignmentDataForClusterId($cluster_id);
	    
    my $hspCounts = scalar(@{$ret});

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("Retrieved the following pairwise alignment data for cluster with feature_id '$cluster_id':" . Dumper $ret);
	$self->{_logger}->debug("Number of HSPs retrieved for cluster with cluster_id '$cluster_id' was '$hspCounts'");
    }
    
    for (my $i=0; $i < scalar(@{$ret}); $i++){

	my $hash = {  'query_protein_id'   => $ret->[$i][0],
		      'target_protein_id'  => $ret->[$i][1],
		      'significance'       => $ret->[$i][2],
		      'percent_identity'   => $ret->[$i][3],
		      'percent_similarity' => $ret->[$i][4],
		      'query_seqlen'       => $ret->[$i][5],
		      'target_seqlen'      => $ret->[$i][6],
		      'query_fmin'         => $ret->[$i][7],
		      'query_fmax'         => $ret->[$i][8],
		      'query_strand'       => $ret->[$i][9],
		      'target_fmin'        => $ret->[$i][10],
		      'target_fmax'        => $ret->[$i][11],
		      'target_strand'      => $ret->[$i][12]
		  };
	
	push (@{$hsp_ref_array}, $hash);
    }

    return $hsp_ref_array;
}

##----------------------------------------------------------------
## prepareClusterDataForCalculatingAverages2()
##
##----------------------------------------------------------------
sub prepareClusterDataForCalculatingAverages2 {

    my ($self, $clusterIdStart, $clusterIdEnd) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($clusterIdStart)){
	$self->{_logger}->logdie("clusterIdStart was not defined");
    }
    if (!defined($clusterIdEnd)){
	$self->{_logger}->logdie("clusterIdEnd was not defined");
    }

    ## Reference to a hash keyed on cluster_id where values are an arrary of hashes containing input data for calculating the statistics.
    my $hsp_ref_array = {};

    my $ret = $self->{_backend}->getPairwiseAlignmentDataForClusterId2($clusterIdStart, $clusterIdEnd);
    
    my $hspCounts = scalar(@{$ret});
    
    if ($self->{_logger}->is_debug()){
 	$self->{_logger}->debug("Retrieved the following pairwise alignment data for the clusters with feature_id between '$clusterIdStart' and '$clusterIdEnd':" . Dumper $ret);
 	$self->{_logger}->debug("Number of HSPs retrieved for this set was '$hspCounts'");
    }
    
    for (my $i=0; $i < scalar(@{$ret}); $i++){

	my $hash = {  'query_protein_id'   => $ret->[$i][0],
		      'target_protein_id'  => $ret->[$i][1],
		      'significance'       => $ret->[$i][2],
		      'percent_identity'   => $ret->[$i][3],
		      'percent_similarity' => $ret->[$i][4],
		      'query_seqlen'       => $ret->[$i][5],
		      'target_seqlen'      => $ret->[$i][6],
		      'query_fmin'         => $ret->[$i][7],
		      'query_fmax'         => $ret->[$i][8],
		      'query_strand'       => $ret->[$i][9],
		      'target_fmin'        => $ret->[$i][10],
		      'target_fmax'        => $ret->[$i][11],
		      'target_strand'      => $ret->[$i][12]
		  };
	
	push (@{$hsp_ref_array->{$ret->[$i][13]}}, $hash);
    }

    return $hsp_ref_array;
}

##----------------------------------------------------------------
## prepareClusterDataForCalculatingAverages3()
##
## Should be faster than 2 for large data sets.
##----------------------------------------------------------------
sub prepareClusterDataForCalculatingAverages3 {

    my ($self, $cluster_analysis_id, $align_analysis_id) = @_; 
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    ## Reference to a hash keyed on cluster_id where values are an arrary of hashes containing input data for calculating the statistics.
    my $hsp_ref_array = {};
    my $ret = $self->{_backend}->getPairwiseAlignmentDataForClusterId3($cluster_analysis_id, $align_analysis_id);
    
    my $hspCounts = scalar(@{$ret});
    
    if ($self->{_logger}->is_debug()){
 	$self->{_logger}->debug("Number of HSPs retrieved for this set was '$hspCounts'");
    }
    
    for (my $i=0; $i < scalar(@{$ret}); $i++){

	my $hash = {  'query_protein_id'   => $ret->[$i][0],
                  'query_seqlen'       => $ret->[$i][1],
                  'query_fmin'         => $ret->[$i][2],
                  'query_fmax'         => $ret->[$i][3],
                  'query_strand'       => $ret->[$i][4],

                  'target_protein_id'  => $ret->[$i][5],
                  'target_seqlen'      => $ret->[$i][6],
                  'target_fmin'        => $ret->[$i][7],
                  'target_fmax'        => $ret->[$i][8],
                  'target_strand'      => $ret->[$i][9],
                  
                  'percent_identity'   => $ret->[$i][10],
                  'significance'       => $ret->[$i][11],
                  'percent_similarity' => $ret->[$i][12],
                  
		  };
	
	push (@{$hsp_ref_array->{$ret->[$i][13]}}, $hash);
    }

    return $hsp_ref_array;
}

##----------------------------------------------------------------
## prepareClusterDataForCalculatingAveragesCmBlast()
##
## Should be faster than the previous methods but relies on a
## populated cm_blast table.
##----------------------------------------------------------------
sub prepareClusterDataForCalculatingAveragesCmBlast {

    my ($self, $cluster_analysis_id) = @_; 
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    ## Reference to a hash keyed on cluster_id where values are an arrary of hashes containing input data for calculating the statistics.
    my $hsp_ref_array = {};
    my $ret = $self->{_backend}->getPairwiseAlignmentDataForClusterIdCmBlast($cluster_analysis_id);
    my $hspCounts = scalar(@{$ret});
    
    if ($self->{_logger}->is_debug()){
 	$self->{_logger}->debug("Number of HSPs retrieved for this set was '$hspCounts'");
    }
    
    for (my $i=0; $i < scalar(@{$ret}); $i++){

	my $hash = {  'query_protein_id'   => $ret->[$i][0],
                  'target_protein_id'  => $ret->[$i][1],
 
                  'percent_identity'   => $ret->[$i][2],
        #          'significance'       => $ret->[$i][3],
                  'percent_similarity' => $ret->[$i][3],
                  'percent_coverage'   => $ret->[$i][4],                  
                  'significance'            => $ret->[$i][5],
		  };
	
	push (@{$hsp_ref_array->{$ret->[$i][6]}}, $hash);	
    }

    return $hsp_ref_array;
}

##-------------------------------------------------------------
## getAvgBlastPIdSim()
##
##-------------------------------------------------------------
sub getAvgBlastPIdSim {

    my($hsps) = @_;
    my $sim_sum=0;
    my $id_sum=0;
    my $q_len_sum=0;
    my $numHsps = 0;
    
    # Group by query and target id
    my $hspsByQuery = &groupByMulti($hsps, ['query_protein_id', 'target_protein_id']);

    foreach my $queryId (keys %$hspsByQuery) {
        my $hspsByTarget = $hspsByQuery->{$queryId};

        foreach my $subjId (keys %$hspsByTarget) {
            my $shsps = $hspsByTarget->{$subjId};
#            my $querySeqLen = $shsps->[0]->{'query_seqlen'};
#            my $targetSeqLen = $shsps->[0]->{'target_seqlen'};
            
            foreach my $hsp(@{$shsps}) {
                ++$numHsps;
                my $q_seg_len = $hsp->{'query_fmax'} - $hsp->{'query_fmin'};
                $q_len_sum += $q_seg_len;
                $sim_sum += $hsp->{'percent_similarity'} * $q_seg_len;
                $id_sum += $hsp->{'percent_identity'} * $q_seg_len;
            }
        }
    }
    
    if ($numHsps == 0) {
        return undef;
    } else {
        return [($id_sum/$q_len_sum), ($sim_sum/$q_len_sum)];
    }
            
    
}

##------------------------------------------------------------
## getAvgBlastPPctCoverage()
##
##------------------------------------------------------------
## Returns an array reference where 
##     [0] = query percent coverage, 
## and [1] = target percent coverage
sub getAvgBlastPPctCoverage {
    my($hsps) = @_;
    my $qsum=0;
    my $tsum=0;
    my $numHsps=0;

    # Group by query and target id
    my $hspsByQuery = &groupByMulti($hsps, ['query_protein_id', 'target_protein_id']);

    foreach my $queryId (keys %$hspsByQuery) {
        my $hspsByTarget = $hspsByQuery->{$queryId};

        foreach my $subjId (keys %$hspsByTarget) {
            ++$numHsps;
            my $shsps = $hspsByTarget->{$subjId};
            my $querySeqLen = $shsps->[0]->{'query_seqlen'};
            my $targetSeqLen = $shsps->[0]->{'target_seqlen'};

            my @queryIntervals = map { {'fmin' => $_->{'query_fmin'}, 'fmax' => $_->{'query_fmax'}, 'strand' => $_->{'query_strand'}} } @$shsps;
            my @targetIntervals = map { {'fmin' => $_->{'target_fmin'}, 'fmax' => $_->{'target_fmax'}, 'strand' => $_->{'target_strand'}} } @$shsps;

            my $mergedQueryIntervals = &mergeOverlappingIntervals(\@queryIntervals);
            my $mergedTargetIntervals = &mergeOverlappingIntervals(\@targetIntervals);

            my $queryHitLen = 0;
            my $targetHitLen = 0;

            map { $queryHitLen += ($_->{'fmax'} - $_->{'fmin'}); } @$mergedQueryIntervals;
            map { $targetHitLen += ($_->{'fmax'} - $_->{'fmin'}); } @$mergedTargetIntervals;

            $qsum += $queryHitLen / $querySeqLen;
            $tsum += $targetHitLen / $targetSeqLen;
        }
    }

    if ($numHsps == 0) {
        return undef;
    } else {
        return [($qsum/$numHsps*100.0), ($tsum/$numHsps*100.0)];
    }
}


##------------------------------------------------------------
## mergeOverlappingIntervals()
##
##------------------------------------------------------------
# Generate a new set of intervals by merging any that overlap in the original set.
#
sub mergeOverlappingIntervals {
    my($intervals) = @_;

    # result set of intervals
    my $merged = [];

    # sort all intervals by fmin
    my @sorted = sort { $a->{'fmin'} <=> $b->{'fmin'} } @$intervals;
    
    # current interval
    my $current = undef;

    foreach my $i (@sorted) {
        if (!defined($current)) {
            # case 1: no current interval
            $current = $i;
        } else {
            # case 2: compare current interval to interval $i
            if ($i->{'fmin'} > $current->{'fmax'}) {   
                # case 2a: no overlap
                push(@$merged, $current);
                $current = $i;
            } elsif ($i->{'fmax'} > $current->{'fmax'}) {
                # case 2b: overlap, with $i ending to the right of $current
                $current->{'fmax'} = $i->{'fmax'};
            }
        }
    }
    push(@$merged, $current) if (defined($current));

    return $merged;
}


##------------------------------------------------------------
## groupByMulti()
##
##------------------------------------------------------------
sub groupByMulti {
    my($arrayref, $keyFields) = @_;
    my $nKeys = scalar(@$keyFields);
    my $groups = {};

    foreach my $a (@$arrayref) {
        my @keyValues = map { $a->{$_} } @$keyFields;
        my $hash = $groups;

        for (my $i = 0;$i < $nKeys;++$i) {
            my $kv = $keyValues[$i];

            if ($i < ($nKeys-1)) {
                $hash->{$kv} = {} if (!defined($hash->{$kv}));
                $hash = $hash->{$kv};
            } else {
                $hash->{$kv} = [] if (!defined($hash->{$kv}));
                push(@{$hash->{$kv}}, $a);
            }
        }
    }
    return $groups;
}


##----------------------------------------------------
## featureCountByType()
##
##----------------------------------------------------
sub featureCountByType {

    my ($self, $type_id) = @_;
    
    if (defined($type_id)){
	if ($type_id =~ /^\d+$/){
	    my $ret = $self->{_backend}->getFeatureCountByType($type_id);
	    
	    if (defined($ret->[0][0])){
		return $ret->[0][0];
	    }
	    else {
		$self->{_logger}->logdie("ret was not defined for type_id '$type_id'");
	    }
	}
	else {
	    $self->{_logger}->logdie("type_id '$type_id' is not a number");
	}
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }

    return 0;
}

##----------------------------------------------------
## featureCountBySecondaryType()
##
##----------------------------------------------------
sub featureCountBySecondaryType {

    my ($self, $type_id) = @_;
    
    if (defined($type_id)){
	if ($type_id =~ /^\d+$/){
	    my $ret = $self->{_backend}->getFeatureCountBySecondaryType($type_id);
	    
	    if (defined($ret->[0][0])){
		return $ret->[0][0];
	    }
	    else {
		$self->{_logger}->logdie("ret was not defined for type_id '$type_id'");
	    }
	}
	else {
	    $self->{_logger}->logdie("type_id '$type_id' is not a number");
	}
    }
    else {
	$self->{_logger}->logdie("type_id was not defined");
    }

    return 0;
}


##----------------------------------------------------
## featurelocCountByTypes()
##
##----------------------------------------------------
sub featurelocCountByTypes {

    my ($self, $type_id1, $type_id2) = @_;
    
    if (defined($type_id1)){

	if ($type_id1 =~ /^\d+$/){

	    if (defined($type_id2)){

		if ($type_id2 =~ /^\d+$/){

		    my $ret = $self->{_backend}->getFeaturelocCountByTypes($type_id1, $type_id2);
	    
		    if (defined($ret->[0][0])){
			return $ret->[0][0];
		    }
		    else {
			$self->{_logger}->logdie("ret was not defined for type_id1 '$type_id1' type_id2 '$type_id2'");
		    }
		}
		else {
		    $self->{_logger}->logdie("type_id2 is not a number");
		}
	    }
	    else {
		$self->{_logger}->logdie("type_id2 was not defined");
	    }
	}
	else {
	    $self->{_logger}->logdie("type_id1 is not a number");
	}
    }
    else {
	$self->{_logger}->logdie("type_id1 was not defined");
    }

    return 0;

}

##----------------------------------------------------
## featurelocCountBySecondaryTypes()
##
##----------------------------------------------------
sub featurelocCountBySecondaryTypes {

    my ($self, $type_id1, $type_id2) = @_;
    
    if (defined($type_id1)){

	if ($type_id1 =~ /^\d+$/){

	    if (defined($type_id2)){

		if ($type_id2 =~ /^\d+$/){

		    my $ret = $self->{_backend}->getFeaturelocCountBySecondaryTypes($type_id1, $type_id2);
	    
		    if (defined($ret->[0][0])){
			return $ret->[0][0];
		    }
		    else {
			$self->{_logger}->logdie("ret was not defined for type_id1 '$type_id1' type_id2 '$type_id2'");
		    }
		}
		else {
		    $self->{_logger}->logdie("type_id2 is not a number");
		}
	    }
	    else {
		$self->{_logger}->logdie("type_id2 was not defined");
	    }
	}
	else {
	    $self->{_logger}->logdie("type_id1 is not a number");
	}
    }
    else {
	$self->{_logger}->logdie("type_id1 was not defined");
    }

    return 0;

}

##----------------------------------------------------
## noLocalizationsByTypes()
##
##----------------------------------------------------
sub noLocalizationsByTypes {

    my ($self, $type_id1, $type_id2) = @_;
    
    if (defined($type_id1)){

	if ($type_id1 =~ /^\d+$/){

	    if (defined($type_id2)){

		if ($type_id2 =~ /^\d+$/){

		    my $ret = $self->{_backend}->getNoLocalizationsByTypes($type_id1, $type_id2);
	    
		    if (defined($ret->[0][0])){
			return $ret->[0][0];
		    }
		    else {
			$self->{_logger}->logdie("ret was not defined for type_id1 '$type_id1' type_id2 '$type_id2'");
		    }
		}
		else {
		    $self->{_logger}->logdie("type_id2 is not a number");
		}
	    }
	    else {
		$self->{_logger}->logdie("type_id2 was not defined");
	    }
	}
	else {
	    $self->{_logger}->logdie("type_id1 is not a number");
	}
    }
    else {
	$self->{_logger}->logdie("type_id1 was not defined");
    }

    return 0;

}


##----------------------------------------------------------------
## localizationsAmongSequencesBySecondaryTypes()
##
##----------------------------------------------------------------
sub localizationsAmongSequencesBySecondaryTypes {

    my ($self) =  shift;

   $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return  $self->{_backend}->getLocalizationsAmongSequencesBySecondaryTypes(@_);
}


##----------------------------------------------------------------
## featureToSequenceSecondaryType2()
##
##----------------------------------------------------------------
sub featureToSequenceSecondaryType2 {

    my ($self) =  shift;

   $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->getFeatureToSequenceSecondaryType2(@_);
}


##----------------------------------------------------------------
## featureToSequenceSecondaryType1()
##
##----------------------------------------------------------------
sub featureToSequenceSecondaryType1 {

    my ($self) =  shift;

   $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->getFeatureToSequenceSecondaryType1(@_);
}

#--------------------------------------------------------------
# deriveSpliceSiteFeatures()
#
#--------------------------------------------------------------
sub deriveSpliceSiteFeatures {

    my $self = shift;
    my ($exons, $sybase_time, $cdslookup, $stopCodonLookup, $assemblyId, $verbose, $assemblyFeatureId, $createUTRFeatures, $deriveIntronFeatures,
	$spliceSiteLookup, $intronLookup) = @_;
    
    if (!defined($verbose)){
	$verbose = 1;
    }

    my $splice_site_cvterm_id = $self->{_backend}->get_cvterm_id('splice_site');
    if (!defined($splice_site_cvterm_id)){
	$self->{_logger}->logdie("Could not retrieve cvterm_id for cvterm.name = 'splice_site'");
    }

    my $fivePrimeNonCodingExonCvtermId;
    my $threePrimeNonCodingExonCvtermId;
    $createUTRFeatures = 0;

    if ((!defined($createUTRFeatures)) || ($createUTRFeatures == 1)){
	$createUTRFeatures = 1;

	$fivePrimeNonCodingExonCvtermId = $self->{_backend}->getCvtermIdByTermNameByOntology('five_prime_noncoding_exon', 'SO');
	if (!defined($fivePrimeNonCodingExonCvtermId)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term cvterm.name 'five_prime_noncoding_exon' cv.name 'SO'");
	}

	$threePrimeNonCodingExonCvtermId = $self->{_backend}->getCvtermIdByTermNameByOntology('three_prime_noncoding_exon', 'SO');
	if (!defined($threePrimeNonCodingExonCvtermId)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term cvterm.name 'three_prime_noncoding_exon' cv.name 'SO'");
	}
    }

    my $intronCvtermId;
    $deriveIntronFeatures=0;

    if ((!defined($deriveIntronFeatures)) || ($deriveIntronFeatures == 1)){
	$deriveIntronFeatures = 1;

	$intronCvtermId = $self->{_backend}->getCvtermIdByTermNameByOntology('intron', 'SO');
	if (!defined($intronCvtermId)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term cvterm.name 'intron' cv.name 'SO'");
	}
    }

    ## The $cdslookup is a two dimensional array.  Here is a description of the inner array:
    ## 0 cds.uniquename
    ## 1 cds.fmin
    ## 2 cds.fmax
    ## 3 polypeptide.uniquename
    ## 4 polypeptide.seqlen
    ## 5 polypeptide.feature_id
    ## 6 polypeptide.organism_id
    ## 7 cds.strand
    ## 8 polypeptide.strand
    ## 9 polypeptide.fmin
    ## 10 polypeptide.fmax

    ## The $exons is a reference to a hash keyed on the CDS uniquename with value reference to a one dimensional array.
    ## The contents of that array are described here (exon coordinates):
    ## 0 fmin
    ## 1 fmax
    ## 2 exon.feature_id
    ## 3 strand

    ## Keep counts for this assembly
    my $assemblyFivePrimeUTRExonCtr = 0;
    my $assemblyThreePrimeUTRExonCtr = 0;
    my $assemblyUTRExonCtr = 0;
    my $assemblyOneExonCDSCtr = 0;
    my $assemblyExonCtr = 0;
    my $assemblyNewSpliceSitesCount = 0;
    my $assemblyCDSCtr = 0;
    my $featureCvtermCounter=0;
    my $assemblyIntronCounter=0;

    foreach my $cols ( @{$cdslookup} ){

	$assemblyCDSCtr++;

	## Keep counts for this CDS
	my $spliceSiteCtr = 0;
	my $fivePrimeNonCodingExonCtr=0;
	my $threePrimeNonCodingExonCtr=0;
	my $intronCtr=0;

	## Set the pointer == the CDS fmin value
	my $pointer = $cols->[1];

	## Keep count of the number of codons counted
	my $codonCounter = 0;

	## Keep count of the number of exons for this CDS
	my $exonCounter = 0;

	## Previous exon's fmax
	my $previousExonFmax;

	## We'll count the number of nucleotides as we move along each exon/CDS.
	my $ntCtr = 0;

	## Use the CDS uniquename to lookup all of the associated exons.
	## Sort the exons on their fmin values
	foreach my $exon ( sort { $a->[1] <=> $b->[1] } @{$exons->{$cols->[0]}} ){
	    
	    $exonCounter++;

	    if ($cols->[7] != $exon->[3]){
		$self->{_logger}->error("CDS strand '$cols->[7]' != exon strand '$exon->[3]' CDS uniquename '$cols->[0]' ".
					"polypeptide feature_id '$cols->[5]' uniquename '$cols->[3]' polypeptide strand '$cols->[8]' ".
					"polypeptide seqlen '$cols->[4]' exon feature_id '$exon->[2]' exon strand '$exon->[3]'");
	    }

	    ## Derivation of intron features
	    if ($deriveIntronFeatures){
		if ($exonCounter > 1){
		    my $intronKey = $previousExonFmax . '_'. $exon->[0] . '_' . $exon->[3] . '_' . $assemblyFeatureId;
		    if (! exists $intronLookup->{$intronKey}){
			$self->createIntronFeature($previousExonFmax,$exon->[0], $exon->[3], $intronCvtermId, $assemblyFeatureId);
			$intronCtr++;
		    }
		    else {
			$self->{_logger}->info("An intron with fmin '$previousExonFmax' fmax '$exon->[0]' strand '$exon->[3]' ".
					       "srcfeature_id '$assemblyFeatureId' already exists in the database.");
		    }
		}
		## Assign the fmax value of the current exon being processed.
		$previousExonFmax = $exon->[1];
	    }

	    ## 5' non-coding exon
	    if ( $exon->[1] < $cols->[1] ){
		## If the exon's fmax (exon->[1]) is < the CDS' fmin (cols->[1]), then this is a 5' UTR exon
		if ($createUTRFeatures){
		    if (!defined($self->createAndAddFeatureCvterm($exon->[2], $fivePrimeNonCodingExonCvtermId))){
			$self->{_logger}->logdie("Could not create feature_cvterm record for five_prime_noncoding_exon with feature_id '$exon->[2]'");
		    }
		    $featureCvtermCounter++;
		}
		$fivePrimeNonCodingExonCtr++;
		next;
	    }
	    
	    ## 3' non-coding exon
	    if ( $exon->[0] > $cols->[2] ){
		## If the exon's fmin (exon->[0]) is > the CDS' fmax (cols->[2]), then this is a 3' UTR exon
		if ($createUTRFeatures){
		    if (!defined($self->createAndAddFeatureCvterm($exon->[2], $threePrimeNonCodingExonCvtermId))){
			$self->{_logger}->logdie("Could not create feature_cvterm record for three_prime_noncoding_exon with feature_id '$exon->[2]'");
		    }
		    $featureCvtermCounter++;
		}
		$threePrimeNonCodingExonCtr++;
		next;
	    }

	    if ($self->{_logger}->is_debug()){
		$self->{_logger}->debug("CDS uniquename '$cols->[0]' CDS strand '$cols->[7]' CDS fmax '$cols->[2]' polypeptide feature_id '$cols->[5]' ".
					"uniquename '$cols->[3]' polypeptide strand '$cols->[8]' seqlen '$cols->[4]' ".
					"exon feature_id '$exon->[2]' exon strand '$exon->[3]' exon fmax '$exon->[1]'");
	    }
	    
	    if ($pointer < $exon->[0]){
		## Move the pointer from the previous exon's fmax to the current exon's fmin.
		$pointer = $exon->[0];
	    }
	    
	    ## Conditions for entering and remaining in this while loop:
	    while ( ( $pointer != $cols->[2] ) &&  ## pointer is != to the CDS's fmax
		    ( $pointer != $exon->[1] )) {  ## pointer is != to the exon's fmax
		
		## Walk along the CDS until we either encounter the fmax of the CDS or the fmax of the exon, whichever occurs first.
		$pointer++;  
		$ntCtr++;

		if ( $ntCtr > 2 ){
		    ## We traversed the distance of another codon
		    $codonCounter++;
		    $ntCtr = 0;
		}
	    }

	    ## At this point we're either at the CDS's fmax or the current exon's fmax.

	    if ( $codonCounter > $cols->[4] ) { 
		## The number of codons we've counted exceeds the polypeptide's feature.seqlen.
		$self->{_logger}->logdie("Data or logic error - polypeptide fmin '$cols->[9]' polypeptide fmax ".
					 "'$cols->[10]' polypeptide seqlen '$cols->[4]' codon count '$codonCounter' pointer '$pointer'");
	    }
			    
	    if ( ( $pointer > $cols->[9] ) && ( $pointer < $cols->[10] ) ) {
		## We've got a splice site only if the pointer lies within the polypeptide's boundaries.
		## cols->[9]  is the polypeptide.fmin
		## cols->[10] is the polypeptide.fmax
		
		my $fmin;
		my $fmax;
		
		if ($self->{_logger}->is_debug()){
		    $self->{_logger}->debug("pointer '$pointer' codonCounter '$codonCounter' ntCtr '$ntCtr'");
		}

		if ($cols->[7] == -1){ ## CDS strand == -1

		    if (exists $stopCodonLookup->{$cols->[5]}){ 
			## The polypeptide feature_id exist in the stop codon lookup therefore we are
			## dealing with a polypeptide that is related to a reverse-strand gene and the
			## polypeptide has a '*' stop codon in its residues field. 
			## This compensates for the cases where the CDS and polypeptide featurelocs 
			## include the stop codon, whereas the polypeptide sequence and seqlen do not.
			if ($self->{_logger}->is_debug()){
			    $self->{_logger}->debug("This polypeptide belonging to a reverse-strand gene, has stop codon at end of residues.");	
			}

			$fmax = $cols->[4] - $codonCounter + 2;
			$fmin = $fmax - 1;
			
			if ($ntCtr % 3 != 0){
			    $fmin++;
			}
		    }
		    else {
			$fmax = $cols->[4] - $codonCounter + 1;
			$fmin = $fmax - 1;
			
			if ($ntCtr % 3 != 0){
			    $fmin++;
			}
		    }
		}
		else { ## CDS strand and exon strand == 1
		    $fmin = $codonCounter;
		    $fmax = $codonCounter;

		    if ($ntCtr % 3 != 0){
			$fmax++;
		    }
		}

		if ($self->{_logger}->is_debug()){
		    $self->{_logger}->debug("pointer '$pointer' codonCounter '$codonCounter' ntCtr '$ntCtr'");		
		}

		my $spliceSiteKey = $fmin . '_' . $fmax . '_' . $cols->[7] . '_' . $cols->[5];
		if (! exists $spliceSiteLookup->{$spliceSiteKey} ){
		    $spliceSiteCtr += $self->createSpliceSiteRecords($cols, $codonCounter, $splice_site_cvterm_id, $sybase_time, $exon, $fmin, $fmax);
		}
		else {
		    $self->info("A splice site with fmin '$fmin' fmax '$fmax' strand '$cols->[7]' srcfeature_id '$cols->[5]' already exists in the database.");
		}
	    }
	    else {
		if ($self->{_logger}->is_debug()){
		    $self->{_logger}->debug("pointer is not within the polypeptide's boundary");
		}
	    }
	}

	my $utrCtr = $fivePrimeNonCodingExonCtr + $threePrimeNonCodingExonCtr;
	$assemblyFivePrimeUTRExonCtr += $fivePrimeNonCodingExonCtr;
	$assemblyThreePrimeUTRExonCtr += $threePrimeNonCodingExonCtr;
	$assemblyUTRExonCtr += $utrCtr;
	$assemblyNewSpliceSitesCount += $spliceSiteCtr;
	$assemblyExonCtr += $exonCounter;

	if ($exonCounter == 1){
	    $assemblyOneExonCDSCtr++;
	}
	
	if ($verbose){
	    print "For CDS '$cols->[0]' counted '$exonCounter' exons; ";
	    if ($utrCtr > 0 ){
		print "'$utrCtr' UTR-exons (";
		if ( $fivePrimeNonCodingExonCtr > 0 ){
		    print "'$fivePrimeNonCodingExonCtr' 5' UTR-exons; ";
		}
		if ($threePrimeNonCodingExonCtr > 0 ){
		    print "'$threePrimeNonCodingExonCtr' 3' UTR-exons";
		}
		print ") ";
	    }
	    if ($spliceSiteCtr > 0 ){
		print " created '$spliceSiteCtr' splice site features";
	    }
	    else {
		print " did not create new splice site features";
	    }
	    
	    print "\n";
	}
    }


    if ($verbose){
	print "For assembly with feature_id '$assemblyId': counted a total of '$assemblyCDSCtr' CDS features; '$assemblyExonCtr' exons; ";
	if ($assemblyUTRExonCtr > 0 ) {
	    print "'$assemblyUTRExonCtr' UTR-exons ";
	    if ($assemblyFivePrimeUTRExonCtr > 0 ){
		print "('$assemblyFivePrimeUTRExonCtr' 5' UTR-exons ";
	    }
	    if ($assemblyThreePrimeUTRExonCtr > 0 ){
		print "'$assemblyThreePrimeUTRExonCtr' 3' UTR-exons); ";
	    }
	}

	if ($assemblyOneExonCDSCtr > 0){
	    print "'$assemblyOneExonCDSCtr' one-exon CDS features. ";
	}

	if ($assemblyNewSpliceSitesCount > 0 ){
	    print "Created '$assemblyNewSpliceSitesCount' splice site features. ";
	}
	else {
	    print "Did not create any new splice site features. ";
	}
	
	if ($featureCvtermCounter > 0 ){
	    print "Created '$featureCvtermCounter' feature_cvterm records for UTR-exons.";
	}
	print "\n";
    }

    return $assemblyNewSpliceSitesCount;
}

#-----------------------------------------------------------------------------------
# createSpliceSiteRecords()
#
#-----------------------------------------------------------------------------------
sub createSpliceSiteRecords {
	
    my $self = shift;
    my ($cols, $codonCounter, $splice_site_cvterm_id, $sybase_time, $exon, $fmin, $fmax) = @_;

    ## Create a unique string for input to getFeatureUniquenameFromIdGenerator()
    ## polypeptide feature.uniquename + splice_site location on the polypeptide + splice_site
    my $uniqstring = $cols->[3] . '_' .  $codonCounter . '_splice_site';

    my $uniquename = $self->getFeatureUniquenameFromIdGenerator($self->{_db}, 'splice_site', $uniqstring);
    if (!defined($uniquename)){
	$self->{_logger}->logdie("Could not generate uniquename from uniqstring '$uniqstring'");
    }

    my $feature_id = $self->{_backend}->do_store_new_feature( dbxref_id        => undef,
							      organism_id      => $cols->[6],
							      name             => undef,
							      uniquename       => $uniquename,
							      residues         => undef,
							      seqlen           => undef,
							      md5checksum      => undef,
							      type_id          => $splice_site_cvterm_id,
							      is_analysis      => 0,
							      is_obsolete      => 0,
							      timeaccessioned  => $sybase_time,
							      timelastmodified => $sybase_time
							      );
		
    if (!defined($feature_id)){
	$self->{_logger}->logdie("Could not create a feature record for splice_site feature.  The input values were: ".
				 "organism_id '$cols->[6]' ".
				 "uniquename '$uniquename' ".
				 "type_id '$splice_site_cvterm_id' ".
				 "timeaccessioned '$sybase_time' ".
				 "timelastmodified '$sybase_time' ");
    }

    if (! $self->checkCoordinatesForChado($fmin, $fmax)){
	$self->{_logger}->logdie("Detected some problem with the coordinates while processing feature ".
				 "with feature_id '$feature_id' srcfeature_id '$cols->[5]'.  Please ".
				 "see review the log file.");
    }

    my $featureloc_id = $self->{_backend}->do_store_new_featureloc( feature_id      => $feature_id,
								    srcfeature_id   => $cols->[5],
								    fmin            => $fmin,
								    is_fmin_partial => 0,
								    fmax            => $fmax,
								    is_fmax_partial => 0,
								    strand          => $exon->[3],
								    residue_info    => undef,
								    locgroup        => 0,
								    rank            => 0
								    );
    if (!defined($featureloc_id)){
	$self->{_logger}->logdie("Could not create a featureloc record for splice_site feature with uniquename '$uniquename'. ".
				 "The input values were : ".
				 "feature_id '$feature_id' ".
				 "srcfeature_id '$cols->[5]' ".
				 "fmin '$fmin' ".
				 "is_fmin_partial '0' ".
				 "fmax '$fmax' ".
				 "is_fmax_partial '0' ".
				 "strand '$exon->[3]' ".
				 "residue_info 'undef' ".
				 "locgroup '0' ".
				 "rank '0'.");
    }
    return 1;
}

#-----------------------------------------------------------------------------------
# createAndAddFeatureCvterm()
#
#-----------------------------------------------------------------------------------
sub createAndAddFeatureCvterm {
	
    my $self = shift;
    my ($feature_id, $cvterm_id, $pub_id) = @_;
    
    if (!defined($pub_id)){
	$pub_id = 1;
    }

    my $feature_cvterm_id = $self->check_feature_cvterm_id_lookup( 
								   feature_id => $feature_id,
								   cvterm_id  => $cvterm_id,
								   pub_id     => $pub_id
								   );
    if (!defined($feature_cvterm_id)){
	## Does not already exist in the database, so create it now.
	$feature_cvterm_id = $self->{_backend}->do_store_new_feature_cvterm(
									    feature_id => $feature_id,
									    cvterm_id  => $cvterm_id,
									    pub_id     => $pub_id
									    );
	if (!defined($feature_cvterm_id)){
	    $self->{_logger}->warn("Could not create a feature_cvterm record for feature_id '$feature_id' cvterm_id '$cvterm_id' pub_id '$pub_id'");
	}
    }
    return $feature_cvterm_id;
}

#-----------------------------------------------------------------------------------
# createIntronFeature()
#
#-----------------------------------------------------------------------------------
sub createIntronFeature {
	
    my $self = shift;
    my ($fmin, $fmax, $strand, $cvterm_id, $assemblyFeatureId) = @_;
    
}

##---------------------------------------------------------
## getFeatureUniquenameFromIdGenerator()
##
##---------------------------------------------------------
sub getFeatureUniquenameFromIdGenerator {

    my $self = shift;
    my ($database, $class, $uniqstring, $version) = @_;

    my $uniquename = $uniqstring;

    if (( exists $self->{_no_id_generator}) && ( $self->{_no_id_generator} == 1 )) {
	## not using IdGenerator this round!
	
	## Do store the value in the lookup so that will be written to the ID mapping file.
	$self->{_id_mapping_lookup}->{$uniqstring} = $uniqstring;
    }
    else {

	## Need to use the IdGenerator service
	if ( exists $self->{_id_mapping_lookup}->{$uniqstring}) {
	    ## The IdGenerator identifier value was already created and cached.
	    ## Return that cached value.
	    $uniquename = $self->{_id_mapping_lookup}->{$uniqstring};
	}
	elsif ( exists $self->{_old_id_mapping_lookup}->{$uniqstring}) {
	    ## The IdGenerator identifier value was already created and cached.
	    ## Return that cached value.
	    $uniquename = $self->{_old_id_mapping_lookup}->{$uniqstring};
	}
	else {
	    ## The IdGenerator identifer value does not already exist in the ID mapping lookup.
	    ## Need to call the IdGenerator service now.

	    if (!defined($version)){
		$version = 0;
	    }

	    $uniquename = $self->{_id_generator}->next_id( project => $database,
							   type    => $class,
							   version => $version );
	    
	    if (!defined($uniquename)){
		$self->{_logger}->logdie("Did not receive a value from IdGenerator for project ".
					 "'$database' type '$class' version '$version'");
	    }

	    ## Store the value in the ID mapping lookup so that will be written to the ID mapping file.
	    $self->{_id_mapping_lookup}->{$uniqstring} = $uniquename;
	    $self->{_old_id_mapping_lookup}->{$uniquename} = $uniqstring;
	}
    }

    return $uniquename;
}



##--------------------------------------------------------------
## writeIdMappingFile()
##
##--------------------------------------------------------------
sub writeIdMappingFile {

    my $self = shift;
    my ($file) = @_;

    if (!defined($file)){
	$self->{_logger}->logdie("file was not defined");
    }

    if (-e $file){
	my $bakFile = $file . '.' . $$ . '.bak';
	rename($file, $bakFile);
    }

    ## Keep count of the number of mappings written to the ID mapping file.
    my $idCtr = 0;
    
    open (MAPPINGFILE, ">$file") || $self->{_logger}->logdie("Could not open file '$file' for output: $!");

    foreach my $oldId (keys %{$self->{_id_mapping_lookup}} ) {

	my $newId = $self->{_id_mapping_lookup}->{$oldId};
	
	print MAPPINGFILE "$oldId\t$newId\n";
	
	$idCtr++;

    }

    print "The number of mappings written to the ID mapping file '$file' was: '$idCtr'\n";

}

##--------------------------------------------------------
## loadIdMappingLookup()
##
##--------------------------------------------------------
sub loadIdMappingLookup {

    my $self = shift;
    my ($directories, $infile) = @_;

    ## Keep counts
    my $idCtr = 0;
    my $dirCtr = 0;
    my $fileCtr = 0;

    if ((!defined($infile)) && (!defined($directories))){
	$self->{_logger}->warn("Note that the user did not specify any directories nor input file that might contain input ".
			       "ID mappings. Consequently, all identifier (uniquename) values to be assigned to the features ".
			       "will be generated for the first time during the execution of this program.  These values ".
			       "will be written to a new ID mapping file.");
    }
    else {
	if (defined($infile)){
	    if (defined($directories)){
		$self->{_logger}->warn("The infile was specified therefore none of the ID mapping files in directories '$directories' ".
				       "will be read.");
	    }
	    $self->loadIdMappingLookupFromFile($infile);
	}
	else {
	    ## User did specify some value(s) for directories that may 
	    ## contain ID mapping files with file extension '.idmap'.
	    
	    my @dirs = split(/,/,$directories);
	    
	    foreach my $directory ( @dirs ){
		## Process each directory one-by-one.
		
		if (!-e $directory){
		    next;
		}
		if (!-d $directory){
		    next;
		}
		if (!-r $directory){
		    $self->{_logger}->logdie("Directory '$directory' does not have read permissions");
		}
		
		## Keep count of the number of directories that were scanned for ID mapping files.
		$dirCtr++;
		
		opendir(THISDIR, "$directory") || $self->{_logger}->logdie("Could not open directory '$directory':$!");
		
		my @allfiles1 = grep {$_ ne '.' and $_ ne '..' } readdir THISDIR;
		
		my @allfiles;
		foreach my $file (@allfiles1){
		    if ($file =~ /\S+\.idmap$/){
			push(@allfiles, $file);
		    }
		    elsif ($file =~ /\S+\.idmap.gz$/){
			push(@allfiles, $file);
		    }
		    elsif ($file =~ /\S+\.idmap.gzip$/){
			push(@allfiles, $file);
		    }
		}
		
		my $fileCount = scalar(@allfiles);
	    
		if ($fileCount > 0){
		    ## There was at least one .idmap file in the directory.
		
		    foreach my $file (@allfiles){
		    
			$file = $directory .'/'. $file;
    
			$idCtr += $self->loadIdMappingLookupFromFile($file);

			$fileCtr++;
		    }
		}
		else {
		    $self->{_logger}->warn("This directory '$directory' did not have any ID mapping files with file extension '.idmap'");
		}
	    }
	}
    }

    if ($idCtr>0){
	$self->{_logger}->warn("'$idCtr' mappings were loaded onto the ID mapping lookup. ".
			       "'$fileCtr' ID mapping files with extension '.idmap' were ".
			       "read in from '$dirCtr' directories.");
    }
    else {
	$self->{_logger}->warn("No ID mappings were loaded onto the ID mapping lookup. ".
			       "'$fileCtr' ID mapping files with extension '.idmap' were ".
			       "read in from '$dirCtr' directories.");
    }

    $self->{_logger}->info("All ID mapping loading complete.\n".
			   "Number of directories scanned for ID mapping files with extension '.idmap': '$dirCtr'\n".
			   "Number of ID mapping files read: '$fileCtr'\n".
			   "Number of ID mappings loaded into the ID mapping lookup: '$idCtr'");
}


##--------------------------------------------------------
## loadIdMappingLookupFromFile()
##
##--------------------------------------------------------
sub loadIdMappingLookupFromFile {

    my $self = shift;
    my ($infile) = @_;

    ## Keep counts
    my $idCtr = 0;
    my $fileCtr = 0;

    if (!defined($infile)){
	$self->{_logger}->logdie("The infile was not defined");
    }

    my @allfiles = split(/,/, $infile);
    
    my $fileCount = scalar(@allfiles);
    
    if ($fileCount > 0){
	## There was at least one .idmap file in the directory.
	
	foreach my $file (@allfiles){
	    
	    if (!-e $file){
		$self->{_logger}->logdie("file '$file' does not exist");
	    }
	    if (!-r $file){
		$self->{_logger}->logdie("file '$file' does not have read permissions");
	    }
	    if (!-f $file){
		$self->{_logger}->logdie("file '$file' is not a regular file");
	    }
	    if (-z $file){
		$self->{_logger}->logdie("file '$file' has zero content.  No ID mappings to read.");
	    }
	    if ($file =~ /\.idmap$/){
		$self->{_logger}->debug("will read from file '$file'");
	    }
	    elsif ($file =~ /\.gz$|\.gzip$/){
		$self->{_logger}->debug("will read from file '$file'");
	    }		
	    else {
		$self->{_logger}->logdie("file '$file' has neither .idmap, .idmap.gz nor .idmap.gzip extension");
	    }
	    
	    ## Keep count of the number of ID mapping files that were read.
	    $fileCtr++;
	    
	    my $fh;
	    if ($file =~ /\.gz$|\.gzip$/) {
		open ($fh, "<:gzip", "$file") || $self->{_logger}->logdie("Could not open ID mapping file '$file' for input: $!");
	    }
	    else {
		open ($fh, "<$file") || $self->{_logger}->logdie("Could not open ID mapping file '$file' for input: $!");
	    }
	    
	    while (my $line = <$fh>){

		chomp $line;
		
		my ($oldid, $newid) = split(/\s+/, $line);
		
		if ( exists $self->{_old_id_mapping_lookup}->{$oldid}){
		    $self->{_logger}->warn("'$oldid' already existed in the ID mapping lookup with new ID '$newid'. ".
					   "Was reading ID mapping file '$file'.");
		}
		
		$self->{_old_id_mapping_lookup}->{$oldid} = $newid;
		
		## Keep count of the number of mappings that are loaded onto the lookup.
		$idCtr++;
	    }
	}
    }
    else {
	$self->{_logger}->logdie("There were no ID mapping files to read.  Input was infile '$infile'");
    }

    
    if ($idCtr>0){
	$self->{_logger}->warn("'$idCtr' mappings were loaded onto the ID mapping lookup. ".
			       "'$fileCtr' ID mapping files with extension '.idmap' were read.");
    }
    else {
	$self->{_logger}->warn("No ID mappings were loaded onto the ID mapping lookup. ".
			       "'$fileCtr' ID mapping files with extension '.idmap' were read.");
    }

    $self->{_logger}->info("Number of ID mapping files read: '$fileCtr'\n".
			   "Number of ID mappings loaded into the ID mapping lookup: '$idCtr'");
    
    return $idCtr;
}

sub createTiedDbFileLookup {

    my $self = shift;
    my ($file) = @_;

    if (!defined($file)){
	$self->{_logger}->logdie("file was not defined");
    }

    my $tiedfile = $file . '.tie';

    if (-e $tiedfile){
	unlink($tiedfile);
	$self->{_logger}->warn("Deleted tied lookup file '$tiedfile'");
    }
    
    $self->{_logger}->info("Attempting to tie a hash to file '$tiedfile'");

    my %lookup;

    eval {  my $dbtie = tie %lookup, 'DB_File', $tiedfile, O_CREAT, undef, $DB_BTREE or $self->{_logger}->logdie("Can't tie lookup to file '$tiedfile'");    
	    $dbtie->filter_store_value( sub { $_ = join $;,@$_ } );
	    $dbtie->filter_fetch_value( sub { $_ = [split /$;/,$_] } ); 
	};

    if ($@){
	$self->{_logger}->logdie("Error detected while attemtping to tie a hash to file '$tiedfile': $!");
    }

    return \%lookup;
}



##----------------------------------------------------------------------
## allPolypeptidesWithStopCodonInResiduesForReverseStrandGenesLookup()
##
##----------------------------------------------------------------------
sub allPolypeptidesWithStopCodonInResiduesForReverseStrandGenesLookup {

    my ($self) =  shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->getAllPolypeptidesWithStopCodonInResiduesForReverseStrandGenes();
    
    my $lookup = {};
    my $i;
    my $j=0;

    for ($i=0 ; $i < scalar(@{$ret}) ; $i++){
	if ($ret->[$i][1] eq '*'){
	    $lookup->{$ret->[$i][0]} = 1;
	    $j++;
	}
    }

    print "Counted '$i' polypeptide features that are related to some reverse-strand gene\n";
    print "'$j' of those polypeptide features had a '*' stop-codon at the end of their feature.residues\n";

    return $lookup;
}

##------------------------------------------------------------------
## createInputBatches()
##
##------------------------------------------------------------------
sub createInputBatches {

    my $self = shift;
    my ($batchSize, $list) = @_;

    ## This method takes a one dimensional array, a list of identifier values
    ## and returns a two dimensional array with each inner array consisting 
    ## of two elements.  The first is the identifier at the begining of the range
    ## and the second element contains the identifier at the end of the range.
    
    my $p1 = 0;
    my $p2 = 0;
    my $listSize = scalar(@{$list}) - 1;

    if (!defined($batchSize)){
	$batchSize = 1000;
    }

    my $batches = [];
    my $batchCtr=0;

    if ($listSize == 0){
	## store
	push( @{$batches}, [$list->[0],$list->[0]]);
	$batchCtr++;

	print "Created a batch that contains one value: '$list->[0]'\n";
    }
    else {
	while ( $p2 != $listSize ){
	    
	    if (($p2 + $batchSize) <= $listSize){
		$p2 += $batchSize;
	    }
	    else {
		$p2 = $listSize;
	    }
	    
	    if (defined($list->[$p1])){
		if (defined($list->[$p2])){
		    ## store
		    push( @{$batches}, [$list->[$p1],$list->[$p2]]);
		    $batchCtr++;
		    $p1 = $p2 + 1;
		}
		else {
		    $self->{_logger}->logdie("Element number '$p2' in the list was not defined");
		}
	    }
	    else {
		$self->{_logger}->logdie("Element number '$p1' in the list was not defined");
	    }
	}
	print "Created '$batchCtr' batches of size '$batchSize'\n";
    }



    return $batches;
}

##-------------------------------------------------------------------
## assemblyFeatureIdListForSpliceSiteDerivations()
##
##-------------------------------------------------------------------
sub assemblyFeatureIdListForSpliceSiteDerivations {

    my $self = shift;
    my ($assembly_id, $abbreviation) = @_;

    my $assembly_list = [];

    if ((defined($assembly_id)) && (lc($assembly_id) eq 'all')) {

	$self->{_logger}->info("All qualifying assemblies' feature_id values will be retrieved");

	$assembly_list = $self->allAssemblyFeatureIdsForSpliceSites();
    }
    elsif ((defined($assembly_id)) && (lc($assembly_id) ne 'all')) {

	$self->{_logger}->info("Only the feature_id values for the assembly with uniquename ".
			       "'$assembly_id' will be retrieved");

	my @list = split(/,/, $assembly_id);

	foreach my $uniquename ( @list ){

	    my $feature_id = $self->{_backend}->getFeatureIdByUniquename($uniquename);

	    if (defined($feature_id->[0][0])){
		push(@{$assembly_list}, $feature_id->[0][0]);
	    }
	    else {
		$self->{_logger}->logdie("feature_id was not defined for uniquename '$uniquename'");
	    }
	}
    }
    elsif (defined($abbreviation)){

	$self->{_logger}->info("All qualifying assemblies' feature_id values will be ".
			       "retrieved only for the organism with abbreviation '$abbreviation'");
	
	$assembly_list = $self->assemblies_by_organism_abbreviation($abbreviation);
    }
    else {
	$self->{_logger}->logdie("You must specify an assembly_id or organism abbreviation");
    }

    my @sortedList = sort{$a <=> $b} (@{$assembly_list});

    return \@sortedList;
}


#----------------------------------------------------------------
# allAssemblyFeatureIdsForSpliceSites()
#
#----------------------------------------------------------------
sub allAssemblyFeatureIdsForSpliceSites {

    my ($self) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $list = [];

    my $ret =  $self->{_backend}->getAllAssemblyFeatureIdsForSpliceSites();

    my $count = scalar(@{$ret});

    for (my $i=0; $i< $count; $i++){
	push( @{$list}, $ret->[$i][0]);
    }

    print "Retrieved '$count' assembly feature_id values for assemblies which have ".
    "the CDS, polypeptide, and exon data necessary for deriving splice site features.\n";
    
    return $list;

}

#----------------------------------------------------------------
# analysisIdExists()
#
#----------------------------------------------------------------
sub analysisIdExists {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret =  $self->{_backend}->doesAnalysisIdExist(@_);

    if ((defined($ret->[0][0])) && ($ret->[0][0] > 0)){
	return 1;
    }

    return 0;
}

#----------------------------------------------------------------
# featureIdExists()
#
#----------------------------------------------------------------
sub featureIdExists {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret =  $self->{_backend}->doesFeatureIdExist(@_);

    if ((defined($ret->[0][0])) && ($ret->[0][0] > 0)){
	return 1;
    }

    return 0;
}

#----------------------------------------------------------------
# obsoleteFeaturesExist()
#
#----------------------------------------------------------------
sub obsoleteFeaturesExist {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret =  $self->{_backend}->doObsoleteFeaturesExist(@_);

    if ((defined($ret->[0][0])) && ($ret->[0][0] > 0)){
	return 1;
    }

    return 0;
}

#----------------------------------------------------------------
# algorithmExists()
#
#----------------------------------------------------------------
sub algorithmExists {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret =  $self->{_backend}->doesAlgorithmExist(@_);

    if ((defined($ret->[0][0])) && ($ret->[0][0] > 0)){
	return 1;
    }

    return 0;
}


#----------------------------------------------------------------
# organismIdExists()
#
#----------------------------------------------------------------
sub organismIdExists {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret =  $self->{_backend}->doesOrganismIdExist(@_);

    if ((defined($ret->[0][0])) && ($ret->[0][0] > 0)){
	return 1;
    }

    return 0;
}

#----------------------------------------------------------------
# analysisfeatureRecordCountByAnalysisId()
#
#----------------------------------------------------------------
sub analysisfeatureRecordCountByAnalysisId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret =  $self->{_backend}->getAnalysisfeatureRecordCountByAnalysisId(@_);

    if (defined($ret->[0][0])){
	return $ret->[0][0];
    }

    return 0;
}

#----------------------------------------------------------------
# analysisfeatureRecordCountByAlgorithm()
#
#----------------------------------------------------------------
sub analysisfeatureRecordCountByAlgorithm {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret =  $self->{_backend}->getAnalysisfeatureRecordCountByAlgorithm(@_);

    if (defined($ret->[0][0])){
	return $ret->[0][0];
    }

    return 0;
}

#----------------------------------------------------------------
# analysispropRecordCountByAnalysisId()
#
#----------------------------------------------------------------
sub analysispropRecordCountByAnalysisId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret =  $self->{_backend}->getAnalysispropRecordCountByAnalysisId(@_);

    if (defined($ret->[0][0])){
	return $ret->[0][0];
    }

    return 0;
}

#----------------------------------------------------------------
# analysispropRecordCountByAlgorithm()
#
#----------------------------------------------------------------
sub analysispropRecordCountByAlgorithm {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret =  $self->{_backend}->getAnalysispropRecordCountByAlgorithm(@_);

    if (defined($ret->[0][0])){
	return $ret->[0][0];
    }

    return 0;
}

#----------------------------------------------------------------
# deleteAnalysispropByAnalysisId()
#
#----------------------------------------------------------------
sub deleteAnalysispropByAnalysisId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_backend}->doDeleteAnalysispropByAnalysisId(@_);
}

#----------------------------------------------------------------
# deleteAnalysisByAnalysisId()
#
#----------------------------------------------------------------
sub deleteAnalysisByAnalysisId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_backend}->doDeleteAnalysisByAnalysisId(@_);
}

#----------------------------------------------------------------
# createSelectStmtsForAnalysisId()
#
#----------------------------------------------------------------
sub createSelectStmtsForAnalysisId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($analysis_id, $outdir, $for_workflow) = @_;
    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $computed_by = $self->{_backend}->getCvtermIdByTermNameByOntology('computed_by',
									 'relationship');
    if (!defined($computed_by)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by'");
    }

    my $listfile = $outdir . '/select.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    my $sql = "SELECT COUNT(analysis_id) ".
    "FROM analysis ".
    "WHERE analysis_id = $analysis_id ";

    $self->createSQLFile($listfile, $outdir, 'analysis', $sql, $for_workflow);

    $sql = "SELECT COUNT(ap.analysis_id) ".
    "FROM analysisprop ap ".
    "WHERE ap.analysis_id = $analysis_id ";

    $self->createSQLFile($listfile, $outdir, 'analysisprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(af.analysis_id) ".
    "FROM analysisfeature af ".
    "WHERE af.analysis_id = $analysis_id ";

    $self->createSQLFile($listfile, $outdir, 'analysisfeature', $sql, $for_workflow);
    
    $sql = "SELECT COUNT(f.feature_id) ".
    "FROM feature f, analysisfeature af ".
    "WHERE af.analysis_id = $analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow);

    $sql = "SELECT COUNT(fl.feature_id) ".
    "FROM featureloc fl, feature f, analysisfeature af ".
    "WHERE af.analysis_id = $analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.scrfeature_id )";

    $self->createSQLFile($listfile, $outdir, 'featureloc', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM feature_pub fp, feature f, analysisfeature af ".
    "WHERE af.analysis_id = $analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(frel.subject_id) ".
    "FROM feature_relationship frel, feature f, analysisfeature af ".
    "WHERE af.analysis_id = $analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) " ;

    $self->createSQLFile($listfile, $outdir, 'feature_relationship', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelpub.feature_relationship_pub_id) ".
    "FROM feature_relationship_pub frelpub, analysisfeature af, feature f, feature_relationship frel ".
    "WHERE af.analysis_id = $analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";


    $self->createSQLFile($listfile, $outdir, 'feature_relationship_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelprop.feature_relationshipprop_id) ".
    "FROM feature_relationshipprop frelprop, analysisfeature af, feature f, feature_relationship frel ".
    "WHERE af.analysis_id = $analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";


    $self->createSQLFile($listfile, $outdir, 'feature_relationshipprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelproppub.feature_relprop_pub_id) ".
    "FROM feature_relprop_pub frelproppub, analysisfeature af, feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE af.analysis_id = $analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND frelprop.feature_relationshipprop_id = frelproppub.feature_relationshipprop_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )";

    $self->createSQLFile($listfile, $outdir, 'feature_relprop_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fd.feature_id) ".
    "FROM feature_dbxref fd, analysisfeature af, feature f ".
    "WHERE af.analysis_id = $analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fd.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM featureprop fp, analysisfeature af, feature f ".
    "WHERE af.analysis_id = $analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'featureprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fppub.featureprop_pub_id) ".
    "FROM featureprop_pub fppub, analysisfeature af, feature f, featureprop fp ".
    "WHERE af.analysis_id = $analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fppub.featureprop_id ";

    $self->createSQLFile($listfile, $outdir, 'featureprop_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fc.feature_id) ".
    "FROM feature_cvterm fc, analysisfeature af, feature f ".
    "WHERE af.analysis_id = $analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcd.feature_cvterm_dbxref_id) ".
    "FROM feature_cvterm_dbxref fcd, analysisfeature af, feature f, feature_cvterm fc ".
    "WHERE af.analysis_id = $analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcpub.feature_cvterm_pub_id) ".
    "FROM feature_cvterm_pub fcpub, analysisfeature af, feature f, feature_cvterm fc ".
    "WHERE af.analysis_id = $analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcpub.feature_cvterm_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcp.feature_cvtermprop_id) ".
    "FROM feature_cvtermprop fcp, analysisfeature af, feature f, feature_cvterm fc ".
    "WHERE af.analysis_id = $analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvtermprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fs.feature_synonym_id) ".
    "FROM feature_synonym fs, analysisfeature af, feature f ".
    "WHERE af.analysis_id = $analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fs.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_synonym', $sql, $for_workflow);
}

#----------------------------------------------------------------
# createSelectStmtsNotForAnalysisId()
#
#----------------------------------------------------------------
sub createSelectStmtsNotForAnalysisId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($analysis_id, $outdir, $for_workflow) = @_;
    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $computed_by = $self->{_backend}->getCvtermIdByTermNameByOntology('computed_by',
									 'relationship');
    if (!defined($computed_by)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by'");
    }

    my $listfile = $outdir . '/select.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    my $sql = "SELECT COUNT(analysis_id) ".
    "FROM analysis ".
    "WHERE analysis_id != $analysis_id ";

    $self->createSQLFile($listfile, $outdir, 'analysis', $sql, $for_workflow);

    $sql = "SELECT COUNT(af.feature_id) ".
    "FROM analysisfeature af ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id )";

    $self->createSQLFile($listfile, $outdir, 'analysisfeature', $sql, $for_workflow);

    $sql = "SELECT COUNT(ap.analysis_id) ".
    "FROM analysisprop ap ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = ap.analysis_id )";

    $self->createSQLFile($listfile, $outdir, 'analysisprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(f.feature_id) ".
    "FROM feature f ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM feature_pub fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fl.feature_id) ".
    "FROM featureloc fl ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id )) ";

    $self->createSQLFile($listfile, $outdir, 'featureloc', $sql, $for_workflow);

    $sql = "SELECT COUNT(frel.subject_id) ".
    "FROM feature_relationship frel ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE  a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelpub.feature_relationship_pub_id) ".
    "FROM feature_relationship_pub frelpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_relationship frel ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelprop.feature_relationshipprop_id) ".
    "FROM feature_relationshipprop frelprop ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_relationship frel ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";


    $self->createSQLFile($listfile, $outdir, 'feature_relationshipprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelproppub.feature_relprop_pub_id) ".
    "FROM feature_relprop_pub frelproppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND frelprop.feature_relationshipprop_id = frelproppub.feature_relationshipprop_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";


    $self->createSQLFile($listfile, $outdir, 'feature_relprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fd.feature_id) ".
    "FROM feature_dbxref fd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fd.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM featureprop fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fppub.featureprop_pub_id) ".
    "FROM featureprop_pub fppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, featureprop fp ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fppub.featureprop_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fc.feature_id) ".
    "FROM feature_cvterm fc ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcd.feature_cvterm_dbxref_id) ".
    "FROM feature_cvterm_dbxref fcd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_cvterm fc ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $sql, $for_workflow);
    
    $sql = "SELECT COUNT(fcpub.feature_cvterm_pub_id) ".
    "FROM feature_cvterm_pub fcpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_cvterm fc ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcpub.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_pub', $sql, $for_workflow);
    
    $sql = "SELECT COUNT(fcp.feature_cvterm_id) ".
    "FROM feature_cvtermprop fcp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_cvterm fc ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvtermprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fs.feature_id) ".
    "FROM feature_synonym fs ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fs.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_synonym', $sql, $for_workflow);
}

#----------------------------------------------------------------
# createSelectStmtsForAlgorithm()
#
#----------------------------------------------------------------
sub createSelectStmtsForAlgorithm {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($algorithm, $outdir, $for_workflow) = @_;
    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $computed_by = $self->{_backend}->getCvtermIdByTermNameByOntology('computed_by',
									 'relationship');
    if (!defined($computed_by)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by'");
    }

    my $listfile = $outdir . '/select.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    my $sql = "SELECT COUNT(analysis_id) ".
    "FROM analysis ".
    "WHERE algorithm = '$algorithm' ";

    $self->createSQLFile($listfile, $outdir, 'analysis', $sql, $for_workflow);

    $sql = "SELECT COUNT(ap.analysis_id) ".
    "FROM analysisprop ap, analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = ap.analysis_id ";

    $self->createSQLFile($listfile, $outdir, 'analysisprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(af.analysis_id) ".
    "FROM analysisfeature af, analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ";

    $self->createSQLFile($listfile, $outdir, 'analysisfeature', $sql, $for_workflow);
    
    $sql = "SELECT COUNT(f.feature_id) ".
    "FROM feature f, analysisfeature af, analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM feature_pub fp, feature f, analysisfeature af, analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fl.feature_id) ".
    "FROM featureloc fl, feature f, analysisfeature af, analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureloc', $sql, $for_workflow);

    $sql = "SELECT COUNT(frel.subject_id) ".
    "FROM feature_relationship frel, feature f, analysisfeature af, analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND af.analysis_id = a.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelpub.feature_relationship_pub_id) ".
    "FROM feature_relationship_pub frelpub, analysisfeature af, feature f, feature_relationship frel, analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelprop.feature_relationshipprop_id) ".
    "FROM feature_relationshipprop frelprop, analysisfeature af, feature f, feature_relationship frel, analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationshipprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelproppub.feature_relprop_pub_id) ".
    "FROM feature_relprop_pub frelproppub, analysisfeature af, feature f, feature_relationship frel, feature_relationshipprop frelprop, analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND frelprop.feature_relationshipprop_id = frelproppub.feature_relationshipprop_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relprop_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fd.feature_id) ".
    "FROM feature_dbxref fd, analysisfeature af, feature f, analysis a".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fd.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM featureprop fp, analysisfeature af, feature f, analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'featureprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fppub.featureprop_pub_id) ".
    "FROM featureprop_pub fppub, analysisfeature af, feature f, featureprop fp, analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fppub.featureprop_id ";

    $self->createSQLFile($listfile, $outdir, 'featureprop_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fc.feature_id) ".
    "FROM feature_cvterm fc, analysisfeature af, feature f, analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcd.feature_cvterm_dbxref_id) ".
    "FROM feature_cvterm_dbxref fcd, analysisfeature af, feature f, feature_cvterm fc, analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcpub.feature_cvterm_pub_id) ".
    "FROM feature_cvterm_pub fcpub, analysisfeature af, feature f, feature_cvterm fc, analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcpub.feature_cvterm_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcp.feature_cvtermprop_id) ".
    "FROM feature_cvtermprop fcp, analysisfeature af, feature f, feature_cvterm fc, analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvtermprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fs.feature_synonym_id) ".
    "FROM feature_synonym fs, analysisfeature af, feature f, analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fs.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_synonym', $sql, $for_workflow);
}

#----------------------------------------------------------------
# createSelectStmtsNotForAlgorithm()
#
#----------------------------------------------------------------
sub createSelectStmtsNotForAlgorithm {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($algorithm, $outdir, $for_workflow) = @_;
    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $computed_by = $self->{_backend}->getCvtermIdByTermNameByOntology('computed_by',
									 'relationship');
    if (!defined($computed_by)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by'");
    }

    my $listfile = $outdir . '/select.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    my $sql = "SELECT COUNT(analysis_id) ".
    "FROM analysis ".
    "WHERE algorithm != '$algorithm' ";

    $self->createSQLFile($listfile, $outdir, 'analysis', $sql, $for_workflow);

    $sql = "SELECT COUNT(af.feature_id) ".
    "FROM analysisfeature af ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id )";

    $self->createSQLFile($listfile, $outdir, 'analysisfeature', $sql, $for_workflow);

    $sql = "SELECT COUNT(ap.analysis_id) ".
    "FROM analysisprop ap ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = ap.analysis_id )";

    $self->createSQLFile($listfile, $outdir, 'analysisprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(f.feature_id) ".
    "FROM feature f ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM feature_pub fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fl.feature_id) ".
    "FROM featureloc fl ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id )) ";

    $self->createSQLFile($listfile, $outdir, 'featureloc', $sql, $for_workflow);

    $sql = "SELECT COUNT(frel.subject_id) ".
    "FROM feature_relationship frel ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE  a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelpub.feature_relationship_pub_id) ".
    "FROM feature_relationship_pub frelpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_relationship frel ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelprop.feature_relationshipprop_id) ".
    "FROM feature_relationshipprop frelprop ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_relationship frel ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR  f.feature_id = frel.object_id ))";

    $self->createSQLFile($listfile, $outdir, 'feature_relationshipprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelproppub.feature_relprop_pub_id) ".
    "FROM feature_relprop_pub frelproppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND frelprop.feature_relationshipprop_id = frelproppub.feature_relationshipprop_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fd.feature_id) ".
    "FROM feature_dbxref fd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fd.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM featureprop fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fppub.featureprop_pub_id) ".
    "FROM featureprop_pub fppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, featureprop fp ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fppub.featureprop_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fc.feature_id) ".
    "FROM feature_cvterm fc ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcd.feature_cvterm_dbxref_id) ".
    "FROM feature_cvterm_dbxref fcd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_cvterm fc ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $sql, $for_workflow);
    
    $sql = "SELECT COUNT(fcpub.feature_cvterm_pub_id) ".
    "FROM feature_cvterm_pub fcpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_cvterm fc ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcpub.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_pub', $sql, $for_workflow);
    
    $sql = "SELECT COUNT(fcp.feature_cvterm_id) ".
    "FROM feature_cvtermprop fcp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_cvterm fc ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvtermprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fs.feature_id) ".
    "FROM feature_synonym fs ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fs.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_synonym', $sql, $for_workflow);
}

#----------------------------------------------------------------
# createSelectStmtsForFeatureId()
#
#----------------------------------------------------------------
sub createSelectStmtsForFeatureId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($feature_id, $outdir, $for_workflow) = @_;
    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $listfile = $outdir . '/select.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    my $sql = "SELECT COUNT(feature_id) ".
    "FROM feature ".
    "WHERE f.feature_id = $feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM feature_pub fp, feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fp.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fl.feature_id) ".
    "FROM featureloc fl, feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureloc', $sql, $for_workflow);

    $sql = "SELECT COUNT(frel.subject_id) ".
    "FROM feature_relationship frel, feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship', $sql, $for_workflow);

    $sql = "SELECT COUNT(af.feature_id) ".
    "FROM analysisfeature af, feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = af.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'analysisfeature', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelpub.feature_relationship_pub_id) ".
    "FROM feature_relationship_pub frelpub, feature f, feature_relationship frel ".
    "WHERE f.feature_id = $feature_id ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelprop.feature_relationshipprop_id) ".
    "FROM feature_relationshipprop frelprop, feature f, feature_relationship frel ".
    "WHERE f.feature_id = $feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationshipprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelproppub.feature_relprop_pub_id) ".
    "FROM feature_relprop_pub frelproppub, feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE f.feature_id = $feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND frelprop.feature_relationshipprop_id = frelproppub.feature_relationshipprop_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relprop_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fd.feature_id) ".
    "FROM feature_dbxref fd, feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fd.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM featureprop fp, feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fp.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'featureprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fppub.featureprop_pub_id) ".
    "FROM featureprop_pub fppub, feature f, featureprop fp ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fppub.featureprop_id ";

    $self->createSQLFile($listfile, $outdir, 'featureprop_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fc.feature_id) ".
    "FROM feature_cvterm fc, feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fc.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcd.feature_cvterm_dbxref_id) ".
    "FROM feature_cvterm_dbxref fcd, feature f, feature_cvterm fc ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcpub.feature_cvterm_pub_id) ".
    "FROM feature_cvterm_pub fcpub, feature f, feature_cvterm fc ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcpub.feature_cvterm_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcp.feature_cvtermprop_id) ".
    "FROM feature_cvtermprop fcp, feature f, feature_cvterm fc ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvtermprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fs.feature_synonym_id) ".
    "FROM feature_synonym fs, feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fs.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_synonym', $sql, $for_workflow);
}

#----------------------------------------------------------------
# createSelectStmtsNotForFeatureId()
#
#----------------------------------------------------------------
sub createSelectStmtsNotForFeatureId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($feature_id, $outdir, $for_workflow) = @_;
    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $listfile = $outdir . '/select.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    my $sql = "SELECT COUNT(feature_id) ".
    "FROM feature ".
    "WHERE f.feature_id != $feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM feature_pub fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fl.feature_id) ".
    "FROM featureloc fl ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id )) ";

    $self->createSQLFile($listfile, $outdir, 'featureloc', $sql, $for_workflow);

    $sql = "SELECT COUNT(frel.subject_id) ".
    "FROM feature_relationship frel ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ))";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship', $sql, $for_workflow);

    $sql = "SELECT COUNT(af.feature_id) ".
    "FROM analysisfeature af ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = af.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'analysisfeature', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelpub.feature_relationship_pub_id) ".
    "FROM feature_relationship_pub frelpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel ".
    "WHERE f.feature_id = $feature_id ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelprop.feature_relationshipprop_id) ".
    "FROM feature_relationshipprop frelprop ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel ".
    "WHERE f.feature_id = $feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ))";

    $self->createSQLFile($listfile, $outdir, 'feature_relationshipprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelproppub.feature_relprop_pub_id) ".
    "FROM feature_relprop_pub frelproppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE f.feature_id = $feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND frelprop.feature_relationshipprop_id = frelproppub.feature_relationshipprop_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ))";

    $self->createSQLFile($listfile, $outdir, 'feature_relprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fd.feature_id) ".
    "FROM feature_dbxref fd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fd.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM featureprop fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fppub.featureprop_pub_id) ".
    "FROM featureprop_pub fppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, featureprop fp ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fppub.featureprop_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fc.feature_id) ".
    "FROM feature_cvterm fc ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fc.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcd.feature_cvterm_dbxref_id) ".
    "FROM feature_cvterm_dbxref fcd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $sql, $for_workflow);
    
    $sql = "SELECT COUNT(fcpub.feature_cvterm_pub_id) ".
    "FROM feature_cvterm_pub fcpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcpub.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_pub', $sql, $for_workflow);
    
    $sql = "SELECT COUNT(fcp.feature_cvterm_id) ".
    "FROM feature_cvtermprop fcp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvtermprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fs.feature_id) ".
    "FROM feature_synonym fs ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fs.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_synonym', $sql, $for_workflow);
}

#----------------------------------------------------------------
# createSelectStmtsForFeatureIsObsolete()
#
#----------------------------------------------------------------
sub createSelectStmtsForFeatureIsObsolete {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($outdir, $for_workflow) = @_;

    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $listfile = $outdir . '/select.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    my $sql = "SELECT COUNT(feature_id) ".
    "FROM feature ".
    "WHERE is_obsolete = 1 ";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM feature_pub fp, feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fp.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fl.feature_id) ".
    "FROM featureloc fl, feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureloc', $sql, $for_workflow);

    $sql = "SELECT COUNT(frel.subject_id) ".
    "FROM feature_relationship frel, feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship', $sql, $for_workflow);

    $sql = "SELECT COUNT(af.feature_id) ".
    "FROM analysisfeature af, feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = af.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'analysisfeature', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelpub.feature_relationship_pub_id) ".
    "FROM feature_relationship_pub frelpub, feature f, feature_relationship frel ".
    "WHERE f.is_obsolete = 1 ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelprop.feature_relationshipprop_id) ".
    "FROM feature_relationshipprop frelprop, feature f, feature_relationship frel ".
    "WHERE f.is_obsolete = 1 ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationshipprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelproppub.feature_relprop_pub_id) ".
    "FROM feature_relprop_pub frelproppub, feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE f.is_obsolete = 1 ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND frelprop.feature_relationshipprop_id = frelproppub.feature_relationshipprop_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relprop_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fd.feature_id) ".
    "FROM feature_dbxref fd, feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fd.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM featureprop fp, feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fp.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'featureprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fppub.featureprop_pub_id) ".
    "FROM featureprop_pub fppub, feature f, featureprop fp ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fppub.featureprop_id ";

    $self->createSQLFile($listfile, $outdir, 'featureprop_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fc.feature_id) ".
    "FROM feature_cvterm fc, feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcd.feature_cvterm_dbxref_id) ".
    "FROM feature_cvterm_dbxref fcd, feature f, feature_cvterm fc ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcpub.feature_cvterm_pub_id) ".
    "FROM feature_cvterm_pub fcpub, feature f, feature_cvterm fc ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcpub.feature_cvterm_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcp.feature_cvtermprop_id) ".
    "FROM feature_cvtermprop fcp, feature f, feature_cvterm fc ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvtermprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fs.feature_synonym_id) ".
    "FROM feature_synonym fs, feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fs.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_synonym', $sql, $for_workflow);
}

#----------------------------------------------------------------
# createSelectStmtsNotForFeatureIsObsolete()
#
#----------------------------------------------------------------
sub createSelectStmtsNotForFeatureIsObsolete {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($outdir, $for_workflow) = @_;

    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $listfile = $outdir . '/select.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    my $sql = "SELECT COUNT(feature_id) ".
    "FROM feature ".
    "WHERE is_obsolete != 1 ";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM feature_pub fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fl.feature_id) ".
    "FROM featureloc fl ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id )) ";

    $self->createSQLFile($listfile, $outdir, 'featureloc', $sql, $for_workflow);

    $sql = "SELECT COUNT(frel.subject_id) ".
    "FROM feature_relationship frel ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ))";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship', $sql, $for_workflow);

    $sql = "SELECT COUNT(af.feature_id) ".
    "FROM analysisfeature af ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = af.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'analysisfeature', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelpub.feature_relationship_pub_id) ".
    "FROM feature_relationship_pub frelpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel ".
    "WHERE f.is_obsolete = 1 ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelprop.feature_relationshipprop_id) ".
    "FROM feature_relationshipprop frelprop ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel ".
    "WHERE f.is_obsolete = 1 ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ))";

    $self->createSQLFile($listfile, $outdir, 'feature_relationshipprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelproppub.feature_relprop_pub_id) ".
    "FROM feature_relprop_pub frelproppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE f.is_obsolete = 1 ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND frelprop.feature_relationshipprop_id = frelproppub.feature_relationshipprop_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ))";

    $self->createSQLFile($listfile, $outdir, 'feature_relprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fd.feature_id) ".
    "FROM feature_dbxref fd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fd.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM featureprop fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fppub.featureprop_pub_id) ".
    "FROM featureprop_pub fppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, featureprop fp ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fppub.featureprop_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fc.feature_id) ".
    "FROM feature_cvterm fc ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcd.feature_cvterm_dbxref_id) ".
    "FROM feature_cvterm_dbxref fcd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $sql, $for_workflow);
    
    $sql = "SELECT COUNT(fcpub.feature_cvterm_pub_id) ".
    "FROM feature_cvterm_pub fcpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcpub.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_pub', $sql, $for_workflow);
    
    $sql = "SELECT COUNT(fcp.feature_cvterm_id) ".
    "FROM feature_cvtermprop fcp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvtermprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fs.feature_id) ".
    "FROM feature_synonym fs ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fs.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_synonym', $sql, $for_workflow);
}


#----------------------------------------------------------------
# createSelectStmtsForOrganismId()
#
#----------------------------------------------------------------
sub createSelectStmtsForOrganismId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($organism_id, $outdir, $for_workflow) = @_;
    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $listfile = $outdir . '/select.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    my $sql = "SELECT COUNT(op.organism_id) ".
    "FROM organismprop op, organism o ".
    "WHERE o.organism_id = $organism_id ".
    "AND o.organism_id = op.organism_id ";

    $self->createSQLFile($listfile, $outdir, 'organismprop', $sql, $for_workflow);
    
    $sql = "SELECT COUNT(od.organism_id) ".
    "FROM organism_dbxref od, organism o ".
    "WHERE o.organism_id = $organism_id ".
    "AND o.organism_id = od.organism_id ";

    $self->createSQLFile($listfile, $outdir, 'organism_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(o.feature_id) ".
    "FROM organism o, feature f ".
    "WHERE o.organism_id = $organism_id ".
    "AND o.organism_id = f.organism_id ";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow);

    $sql = "SELECT COUNT(fl.feature_id) ".
    "FROM featureloc fl, feature f ".
    "WHERE f.organism_id = $organism_id ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureloc', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM feature_pub fp, feature f ".
    "WHERE f.organism_id = $organism_id ".
    "AND f.feature_id = fp.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(af.feature_id) ".
    "FROM analysisfeature af, feature f ".
    "WHERE f.organism_id = $organism_id ".
    "AND f.feature_id = af.feature_id ";
    
    $self->createSQLFile($listfile, $outdir, 'analysisfeature', $sql, $for_workflow);

    $sql = "SELECT COUNT(frel.subject_id) ".
    "FROM feature_relationship frel, feature f ".
    "WHERE f.organism_id = $organism_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelpub.feature_relationship_pub_id) ".
    "FROM feature_relationship_pub frelpub, feature f, feature_relationship frel ".
    "WHERE f.organism_id = $organism_id ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelprop.feature_relationshipprop_id) ".
    "FROM feature_relationshipprop frelprop, feature f, feature_relationship frel ".
    "WHERE o.feature_id = $organism_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationshipprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelproppub.feature_relprop_pub_id) ".
    "FROM feature_relprop_pub frelproppub, feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE o.feature_id = $organism_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND frelprop.feature_relationshipprop_id = frelproppub.feature_relationshipprop_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relprop_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fd.feature_id) ".
    "FROM feature_dbxref fd, feature f ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fd.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM featureprop fp, feature f ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fp.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'featureprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fppub.featureprop_pub_id) ".
    "FROM featureprop_pub fppub, feature f, featureprop fp ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fppub.featureprop_id ";

    $self->createSQLFile($listfile, $outdir, 'featureprop_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fc.feature_id) ".
    "FROM feature_cvterm fc, feature f ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fc.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcd.feature_cvterm_dbxref_id) ".
    "FROM feature_cvterm_dbxref fcd, feature f, feature_cvterm fc ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcpub.feature_cvterm_pub_id) ".
    "FROM feature_cvterm_pub fcpub, feature f, feature_cvterm fc ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcpub.feature_cvterm_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcp.feature_cvtermprop_id) ".
    "FROM feature_cvtermprop fcp, feature f, feature_cvterm fc ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvtermprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fs.feature_synonym_id) ".
    "FROM feature_synonym fs, feature f ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fs.feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature_synonym', $sql, $for_workflow);
}

#----------------------------------------------------------------
# createSelectStmtsNotForOrganismId()
#
#----------------------------------------------------------------
sub createSelectStmtsNotForOrganismId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($organism_id, $outdir, $for_workflow) = @_;
    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $listfile = $outdir . '/select.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    my $sql = "SELECT COUNT(op.organism_id) ".
    "FROM organismprop op ".
    "WHERE op.organism_id != $organism_id ";

    $self->createSQLFile($listfile, $outdir, 'organismprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(od.organism_id) ".
    "FROM organism_dbxref od ".
    "WHERE od.organism_id != $organism_id ";
    
    $self->createSQLFile($listfile, $outdir, 'organism_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(f.organism_id) ".
    "FROM feature f ".
    "WHERE f.organism_id != $organism_id ";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM feature_pub fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fl.feature_id) ".
    "FROM featureloc fl ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE o.feature_id = $organism_id ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id )) ";

    $self->createSQLFile($listfile, $outdir, 'featureloc', $sql, $for_workflow);

    $sql = "SELECT COUNT(af.feature_id) ".
    "FROM analysisfeature af ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = af.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'analysisfeature', $sql, $for_workflow);

    $sql = "SELECT COUNT(frel.subject_id) ".
    "FROM feature_relationship frel ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE o.feature_id = $organism_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelpub.feature_relationship_pub_id) ".
    "FROM feature_relationship_pub frelpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel ".
    "WHERE o.feature_id = $organism_id ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelprop.feature_relationshipprop_id) ".
    "FROM feature_relationshipprop frelprop ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel ".
    "WHERE o.feature_id = $organism_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationshipprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(frelproppub.feature_relprop_pub_id) ".
    "FROM feature_relprop_pub frelproppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE o.feature_id = $organism_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND frelprop.feature_relationshipprop_id = frelproppub.feature_relationshipprop_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relprop_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fd.feature_id) ".
    "FROM feature_dbxref fd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fd.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_dbxref', $sql, $for_workflow);

    $sql = "SELECT COUNT(fp.feature_id) ".
    "FROM featureprop fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fppub.featureprop_pub_id) ".
    "FROM featureprop_pub fppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, featureprop fp ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fppub.featureprop_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop_pub', $sql, $for_workflow);

    $sql = "SELECT COUNT(fc.feature_id) ".
    "FROM feature_cvterm fc ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fc.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm', $sql, $for_workflow);

    $sql = "SELECT COUNT(fcd.feature_cvterm_dbxref_id) ".
    "FROM feature_cvterm_dbxref fcd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $sql, $for_workflow);
    
    $sql = "SELECT COUNT(fcpub.feature_cvterm_pub_id) ".
    "FROM feature_cvterm_pub fcpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcpub.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_pub', $sql, $for_workflow);
    
    $sql = "SELECT COUNT(fcp.feature_cvterm_id) ".
    "FROM feature_cvtermprop fcp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvtermprop', $sql, $for_workflow);

    $sql = "SELECT COUNT(fs.feature_id) ".
    "FROM feature_synonym fs ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE o.feature_id = $organism_id ".
    "AND f.feature_id = fs.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_synonym', $sql, $for_workflow);
}

#----------------------------------------------------------------
# createSelectStmtsForAllTables()
#
#----------------------------------------------------------------
sub createSelectStmtsForAllTables {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($outdir, $for_workflow) = @_;
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }
    my @tables = split(/,/, CHADO_CORE_TABLE_COMMIT_ORDER);
    
    my $listfile = $outdir . '/select.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    foreach my $table (@tables){
	my $sql = "SELECT COUNT(${table}_id) FROM $table";
	$self->createSQLFile($listfile, $outdir, $table, $sql, $for_workflow);
    }
}

#----------------------------------------------------------------
# createSQLFile()
#
#----------------------------------------------------------------
sub createSQLFile {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($listfile, $outdir, $table, $sql, $for_workflow, $tableLookup) = @_;
    if (!defined($listfile)){
	$self->{_logger}->logdie("listfile was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }
    if (!defined($table)){
	$self->{_logger}->logdie("table was not defined");
    }
    if (!defined($sql)){
	$self->{_logger}->logdie("sql was not defined");
    }

    ## Change double forward slashes into a single forward slash.
    $listfile =~ s/\/\//\//g;

    my $file = $outdir . '/'. $table . '.sql';

    ## Change double forward slashes into a single forward slash.
    $file =~ s/\/\//\//g;

    open (OUTFILE, ">>$file") || $self->logdie("Could not open file '$file' for output: $!");

    print OUTFILE "$sql;\n";

    my $string;
    if ((defined($for_workflow)) && ($for_workflow == 1)){
	$string = "$table\t$file\n";
    }
    else {
	$string = "$file\n";
    }

    open (LISTFILE, ">>$listfile") || $self->logdie("Could not open listfile '$listfile' for output: $!");

    print LISTFILE $string;
    
    $tableLookup->{$table}++;

}

#----------------------------------------------------------------
# createDeleteByRangeSQLFile()
#
#----------------------------------------------------------------
sub createDeleteByRangeSQLFile {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($listfile, $outdir, $table, $for_workflow, $ret) = @_;
    if (!defined($listfile)){
	$self->{_logger}->logdie("listfile was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }
    if (!defined($table)){
	$self->{_logger}->logdie("table was not defined");
    }
    if (!defined($ret)){
	$self->{_logger}->logdie("ret was not defined");
    }

    my $check=0;
    if ( defined($ret->[0][0])){
	$check++;
    }
    if ( defined($ret->[0][1])){
	$check++;
    }
	
    if ($check == 2 ){
	my $sql = "DELETE FROM $table WHERE ${table}_id BETWEEN $ret->[0][0] AND $ret->[0][1]";

	$self->createSQLFile($listfile, $outdir, $table, $sql, $for_workflow);
    }
    elsif ($check == 0) {
	$self->{_logger}->info("Don't need to create a delete.sql file for table '$table' ".
			       "since there weren't any related records");
    }
    else {
	$self->{_logger}->logdie("Encountered some problem for table '$table' min '$ret->[0][0]' ".
				 "max '$ret->[0][1]'");
    }
}

#----------------------------------------------------------------
# createOneDeleteStmtPerRecordSQLFile()
#
#----------------------------------------------------------------
sub createOneDeleteStmtPerRecordSQLFile {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($listfile, $outdir, $table, $for_workflow, $ret) = @_;
    if (!defined($listfile)){
	$self->{_logger}->logdie("listfile was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }
    if (!defined($table)){
	$self->{_logger}->logdie("table was not defined");
    }
    if (!defined($ret)){
	$self->{_logger}->logdie("ret was not defined");
    }

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $isqlnum = '$;I_SQL_NUM$;';
	my $isql = '$;I_SQL$;';
	$self->writeListFileHeader($listfile, "$isqlnum\t$isql\n");
    }
#    print Dumper $ret;die if ($table eq 'analysisfeature');
    my $ctr=0;
    foreach my $record ( @{$ret} ){
	$ctr++;
	if (defined($record->[0])){
	    
	    my $sql = "DELETE FROM $table WHERE ${table}_id = $record->[0]";
	    if ((defined($for_workflow)) && ($for_workflow == 1)){
		$sql = "$ctr\tDELETE FROM $table WHERE ${table}_id = $record->[0]";
	    }

	    $self->createSQLFile($listfile, $outdir, $table, $sql, $for_workflow);
	}
	else {
	    $self->{_logger}->logdie("table '$table' ctr '$ctr' record:" . Dumper $record);
	}
    }
}


#----------------------------------------------------------------
# prepareMissingViewsSQL()
#
#----------------------------------------------------------------
sub prepareMissingViewsSQL {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($tableLookup, $listfile, $outdir, $mode, $for_workflow) = @_;
    if (!defined($tableLookup)){
	$self->{_logger}->logdie("tableLookup was not defined");
    }
    if (!defined($listfile)){
	$self->{_logger}->logdie("listfile was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }
    if (!defined($mode)){
	$self->{_logger}->logdie("mode was not defined");
    }

    my @tablelist = split(/,/, CHADO_CORE_TABLE_COMMIT_ORDER);
    foreach my $table (@tablelist){
	if (! exists $tableLookup->{$table}){
	    my $sql = "CREATE VIEW v_$table AS SELECT * FROM $table";
	    if ($mode eq 'drop'){
		$sql = "DROP VIEW v_$table";
	    }
	    $self->createSQLFile($listfile, $outdir, $table, $sql, $for_workflow);
	}
    }
}

#----------------------------------------------------------------
# writeListFileHeader()
#
#----------------------------------------------------------------
sub writeListFileHeader {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($listfile, $header) = @_;
    if (!defined($listfile)){
	$self->{_logger}->logdie("listfile was not defined");
    }
    if (!defined($header)){
	$self->{_logger}->logdie("header was not defined");
    }

    ## Change double forward slashes into a single forward slash.
    $listfile =~ s/\/\//\//g;

    open (OUTFILE, ">$listfile") || $self->logdie("Could not open file '$listfile' for output: $!");

    print OUTFILE $header;    
}


#----------------------------------------------------------------
# createFilteringViewsSQLForAnalysisId()
#
#----------------------------------------------------------------
sub createFilteringViewsSQLForAnalysisId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($analysis_id, $outdir, $for_workflow) = @_;
    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $listfile = $outdir . '/create_views.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    my $computed_by = $self->{_backend}->getCvtermIdByTermNameByOntology('computed_by',
									 'relationship');
    if (!defined($computed_by)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by'");
    }

    my $tableLookup = {};

    my $sql = "CREATE VIEW v_analysis AS ".
    "SELECT a.* ".
    "FROM analysis a ".
    "WHERE a.analysis_id != $analysis_id ";

    $self->createSQLFile($listfile, $outdir, 'analysis', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_analysisfeature AS ".
    "SELECT af.* ".
    "FROM analysisfeature af ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ) ";

    $self->createSQLFile($listfile, $outdir, 'analysisfeature', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_analysisprop AS ".
    "SELECT ap.* ".
    "FROM analysisprop ap ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a ".
    "WHERE a.analysis_id = $analysis_id".
    "AND a.analysis_id = ap.analysis_id ) ";

    $self->createSQLFile($listfile, $outdir, 'analysisprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature AS ".
    "SELECT f.* ".
    "FROM feature f ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_pub AS ".
    "SELECT fp.* ".
    "FROM feature_pub fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_featureloc AS ".
    "SELECT fl.* ".
    "FROM featureloc fl ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND (f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id )) ";

    $self->createSQLFile($listfile, $outdir, 'featureloc', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_relationship AS ".
    "SELECT frel.* ".
    "FROM feature_relationship frel ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_relationship_pub AS ".
    "SELECT frelpub.* ".
    "FROM feature_relationship_pub frelpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_relationship frel ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship_pub', $sql, $for_workflow, $tableLookup);

    $sql ="CREATE VIEW v_feature_relationshipprop AS ".
    "SELECT frelprop.* ".
    "FROM feature_relationshipprop frelprop ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_relationship frel ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationshipprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_relprop_pub AS ".
    "SELECT frelproppub.* ".
    "FROM feature_relprop_pub frelproppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND frelprop.feature_relationshipprop_id = frelproppub.feature_relationshipprop_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relprop_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_dbxref AS ".
    "SELECT fd.* ".
    "FROM feature_dbxref fd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fd.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_dbxref', $sql, $for_workflow, $tableLookup);

    $sql ="CREATE VIEW v_featureprop AS ".
    "SELECT fp.* ".
    "FROM featureprop fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by  ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_featureprop_pub AS ".
    "SELECT fppub.* ".
    "FROM featureprop_pub fppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, featureprop fp ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fppub.featureprop_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_cvterm AS ".
    "SELECT fc.* ".
    "FROM feature_cvterm fc ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm', $sql, $for_workflow, $tableLookup);
    
    $sql = "CREATE VIEW v_feature_cvterm_dbxref AS ".
    "SELECT fcd.* ".
    "FROM feature_cvterm_dbxref fcd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_cvterm fc ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_cvterm_pub AS ".
    "SELECT fcpub.* ".
    "FROM feature_cvterm_pub fcpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_cvterm fc ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcpub.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_cvtermprop AS ".
    "SELECT fcp.* ".
    "FROM feature_cvtermprop fcp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_cvterm fc ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvtermprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_synonym AS ".
    "SELECT fs.* ".
    "FROM feature_synonym fs ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.analysis_id = $analysis_id ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fs.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_synonym', $sql, $for_workflow, $tableLookup);

    $self->prepareMissingViewsSQL($tableLookup, $listfile, $outdir, 'create', $for_workflow);

}

#----------------------------------------------------------------
# createDropFilteringViewsSQL()
#
#----------------------------------------------------------------
sub createDropFilteringViewsSQL {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($outdir, $for_workflow) = @_;
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $listfile = $outdir . '/drop_views.sql.list';

    if ($for_workflow == 1){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    my $tableLookup = {};

    my $sql = "DROP VIEW v_analysis";

    $self->createSQLFile($listfile, $outdir, 'analysis', $sql, $for_workflow, $tableLookup);

    $sql = "DROP VIEW v_analysisfeature";

    $self->createSQLFile($listfile, $outdir, 'analysisfeature', $sql, $for_workflow, $tableLookup);

    $sql = "DROP VIEW v_analysisprop";

    $self->createSQLFile($listfile, $outdir, 'analysisprop', $sql, $for_workflow, $tableLookup);

    $sql = "DROP VIEW v_feature";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow, $tableLookup);

    $sql = "DROP VIEW v_feature_pub";

    $self->createSQLFile($listfile, $outdir, 'feature_pub', $sql, $for_workflow, $tableLookup);

    $sql = "DROP VIEW v_featureloc";

    $self->createSQLFile($listfile, $outdir, 'featureloc', $sql, $for_workflow, $tableLookup);

    $sql = "DROP VIEW v_feature_relationship";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship', $sql, $for_workflow, $tableLookup);

    $sql = "DROP VIEW v_feature_relationship_pub";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship_pub', $sql, $for_workflow, $tableLookup);

    $sql ="DROP VIEW v_feature_relationshipprop";

    $self->createSQLFile($listfile, $outdir, 'feature_relationshipprop', $sql, $for_workflow, $tableLookup);

    $sql = "DROP VIEW v_feature_relprop_pub";

    $self->createSQLFile($listfile, $outdir, 'feature_relprop_pub', $sql, $for_workflow, $tableLookup);

    $sql = "DROP VIEW v_feature_dbxref";

    $self->createSQLFile($listfile, $outdir, 'feature_dbxref', $sql, $for_workflow, $tableLookup);

    $sql ="DROP VIEW v_featureprop";

    $self->createSQLFile($listfile, $outdir, 'featureprop', $sql, $for_workflow, $tableLookup);

    $sql = "DROP VIEW v_featureprop_pub";

    $self->createSQLFile($listfile, $outdir, 'featureprop_pub', $sql, $for_workflow, $tableLookup);

    $sql = "DROP VIEW v_feature_cvterm";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm', $sql, $for_workflow, $tableLookup);
    
    $sql = "DROP VIEW v_feature_cvterm_dbxref";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $sql, $for_workflow, $tableLookup);

    $sql = "DROP VIEW v_feature_cvterm_pub";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_pub', $sql, $for_workflow, $tableLookup);

    $sql = "DROP VIEW v_feature_cvtermprop";

    $self->createSQLFile($listfile, $outdir, 'feature_cvtermprop', $sql, $for_workflow, $tableLookup);

    $sql = "DROP VIEW v_feature_synonym";

    $self->createSQLFile($listfile, $outdir, 'feature_synonym', $sql, $for_workflow, $tableLookup);

    $self->prepareMissingViewsSQL($tableLookup, $listfile, $outdir, 'drop', $for_workflow);
}

#----------------------------------------------------------------
# createFilteringViewsSQLForAlgorithm()
#
#----------------------------------------------------------------
sub createFilteringViewsSQLForAlgorithm {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($algorithm, $outdir, $for_workflow) = @_;
    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $computed_by = $self->{_backend}->getCvtermIdByTermNameByOntology('computed_by',
									 'relationship');
    if (!defined($computed_by)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by'");
    }

    my $listfile = $outdir . '/create_views.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    my $tableLookup= {};

    my $sql = "CREATE VIEW v_analysis AS ".
    "SELECT a.* ".
    "FROM analysis a ".
    "WHERE a.algorithm != '$algorithm' ";

    $self->createSQLFile($listfile, $outdir, 'analysis', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_analysisfeature AS ".
    "SELECT af.* ".
    "FROM analysisfeature af ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ) ";

    $self->createSQLFile($listfile, $outdir, 'analysisfeature', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_analysisprop AS ".
    "SELECT ap.* ".
    "FROM analysisprop ap ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a ".
    "WHERE a.algorithm = '$algorithm'".
    "AND a.analysis_id = ap.analysis_id ) ";

    $self->createSQLFile($listfile, $outdir, 'analysisprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature AS ".
    "SELECT f.* ".
    "FROM feature f ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_pub AS ".
    "SELECT fp.* ".
    "FROM feature_pub fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_featureloc AS ".
    "SELECT fl.* ".
    "FROM featureloc fl ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id )) ";

    $self->createSQLFile($listfile, $outdir, 'featureloc', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_relationship AS ".
    "SELECT frel.* ".
    "FROM feature_relationship frel ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_relationship_pub AS ".
    "SELECT frelpub.* ".
    "FROM feature_relationship_pub frelpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_relationship frel ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship_pub', $sql, $for_workflow, $tableLookup);

    $sql ="CREATE VIEW v_feature_relationshipprop AS ".
    "SELECT frelprop.* ".
    "FROM feature_relationshipprop frelprop ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_relationship frel ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationshipprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_relprop_pub AS ".
    "SELECT frelproppub.* ".
    "FROM feature_relprop_pub frelproppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND frelprop.feature_relationshipprop_id = frelproppub.feature_relationshipprop_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relprop_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_dbxref AS ".
    "SELECT fd.* ".
    "FROM feature_dbxref fd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fd.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_dbxref', $sql, $for_workflow, $tableLookup);

    $sql ="CREATE VIEW v_featureprop AS ".
    "SELECT fp.* ".
    "FROM featureprop fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by  ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_featureprop_pub AS ".
    "SELECT fppub.* ".
    "FROM featureprop_pub fppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, featureprop fp ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fppub.featureprop_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_cvterm AS ".
    "SELECT fc.* ".
    "FROM feature_cvterm fc ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm', $sql, $for_workflow, $tableLookup);
    
    $sql = "CREATE VIEW v_feature_cvterm_dbxref AS ".
    "SELECT fcd.* ".
    "FROM feature_cvterm_dbxref fcd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_cvterm fc ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_cvterm_pub AS ".
    "SELECT fcpub.* ".
    "FROM feature_cvterm_pub fcpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_cvterm fc ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcpub.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_cvtermprop AS ".
    "SELECT fcp.* ".
    "FROM feature_cvtermprop fcp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f, feature_cvterm fc ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvtermprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_synonym AS ".
    "SELECT fs.* ".
    "FROM feature_synonym fs ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.algorithm = '$algorithm' ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = $computed_by ".
    "AND af.feature_id = f.feature_id ".
    "AND f.feature_id = fs.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_synonym', $sql, $for_workflow, $tableLookup);

    $self->prepareMissingViewsSQL($tableLookup, $listfile, $outdir, 'create', $for_workflow);
}

#----------------------------------------------------------------
# createFilteringViewsSQLForFeatureId()
#
#----------------------------------------------------------------
sub createFilteringViewsSQLForFeatureId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($feature_id, $outdir, $for_workflow) = @_;
    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $listfile = $outdir . '/create_views.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    my $tableLookup = {};

    my $sql = "CREATE VIEW v_feature AS ".
    "SELECT f.* ".
    "FROM feature f ".
    "WHERE f.feature_id != $feature_id ";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_pub AS ".
    "SELECT fp.* ".
    "FROM feature_pub fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_featureloc AS ".
    "SELECT fl.* ".
    "FROM featureloc fl ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id )) ";

    $self->createSQLFile($listfile, $outdir, 'featureloc', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_relationship AS ".
    "SELECT frel.* ".
    "FROM feature_relationship frel ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND (f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_relationship_pub AS ".
    "SELECT frelpub.* ".
    "FROM feature_relationship_pub frelpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel ".
    "WHERE f.feature_id = $feature_id ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship_pub', $sql, $for_workflow, $tableLookup);

    $sql ="CREATE VIEW v_feature_relationshipprop AS ".
    "SELECT frelprop.* ".
    "FROM feature_relationshipprop frelprop ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel ".
    "WHERE f.feature_id = $feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationshipprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_relprop_pub AS ".
    "SELECT frelproppub.* ".
    "FROM feature_relprop_pub frelproppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE f.feature_id = $feature_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND frelprop.feature_relationshipprop_id = frelproppub.feature_relationshipprop_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relprop_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_dbxref AS ".
    "SELECT fd.* ".
    "FROM feature_dbxref fd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fd.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_dbxref', $sql, $for_workflow, $tableLookup);

    $sql ="CREATE VIEW v_featureprop AS ".
    "SELECT fp.* ".
    "FROM featureprop fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_featureprop_pub AS ".
    "SELECT fppub.* ".
    "FROM featureprop_pub fppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, featureprop fp ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fppub.featureprop_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_cvterm AS ".
    "SELECT fc.* ".
    "FROM feature_cvterm fc ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fc.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm', $sql, $for_workflow, $tableLookup);
    
    $sql = "CREATE VIEW v_feature_cvterm_dbxref AS ".
    "SELECT fcd.* ".
    "FROM feature_cvterm_dbxref fcd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_cvterm_pub AS ".
    "SELECT fcpub.* ".
    "FROM feature_cvterm_pub fcpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcpub.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_cvtermprop AS ".
    "SELECT fcp.* ".
    "FROM feature_cvtermprop fcp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvtermprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_synonym AS ".
    "SELECT fs.* ".
    "FROM feature_synonym fs ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.feature_id = $feature_id ".
    "AND f.feature_id = fs.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_synonym', $sql, $for_workflow, $tableLookup);

    $self->prepareMissingViewsSQL($tableLookup, $listfile, $outdir, 'create', $for_workflow);
}

#----------------------------------------------------------------
# createFilteringViewsSQLForFeatureIsObsolete()
#
#----------------------------------------------------------------
sub createFilteringViewsSQLForFeatureIsObsolete {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($outdir, $for_workflow) = @_;

    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $listfile = $outdir . '/create_views.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    my $tableLookup = {};

    my $sql = "CREATE VIEW v_feature AS ".
    "SELECT f.* ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1 ";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_pub AS ".
    "SELECT fp.* ".
    "FROM feature_pub fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_featureloc AS ".
    "SELECT fl.* ".
    "FROM featureloc fl ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id )) ";

    $self->createSQLFile($listfile, $outdir, 'featureloc', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_relationship AS ".
    "SELECT frel.* ".
    "FROM feature_relationship frel ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND (f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_relationship_pub AS ".
    "SELECT frelpub.* ".
    "FROM feature_relationship_pub frelpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel ".
    "WHERE f.is_obsolete = 1 ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship_pub', $sql, $for_workflow, $tableLookup);

    $sql ="CREATE VIEW v_feature_relationshipprop AS ".
    "SELECT frelprop.* ".
    "FROM feature_relationshipprop frelprop ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel ".
    "WHERE f.is_obsolete = 1 ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationshipprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_relprop_pub AS ".
    "SELECT frelproppub.* ".
    "FROM feature_relprop_pub frelproppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE f.is_obsolete = 1 ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND frelprop.feature_relationshipprop_id = frelproppub.feature_relationshipprop_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relprop_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_dbxref AS ".
    "SELECT fd.* ".
    "FROM feature_dbxref fd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fd.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_dbxref', $sql, $for_workflow, $tableLookup);

    $sql ="CREATE VIEW v_featureprop AS ".
    "SELECT fp.* ".
    "FROM featureprop fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_featureprop_pub AS ".
    "SELECT fppub.* ".
    "FROM featureprop_pub fppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, featureprop fp ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fppub.featureprop_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_cvterm AS ".
    "SELECT fc.* ".
    "FROM feature_cvterm fc ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm', $sql, $for_workflow, $tableLookup);
    
    $sql = "CREATE VIEW v_feature_cvterm_dbxref AS ".
    "SELECT fcd.* ".
    "FROM feature_cvterm_dbxref fcd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_cvterm_pub AS ".
    "SELECT fcpub.* ".
    "FROM feature_cvterm_pub fcpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcpub.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_cvtermprop AS ".
    "SELECT fcp.* ".
    "FROM feature_cvtermprop fcp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvtermprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_synonym AS ".
    "SELECT fs.* ".
    "FROM feature_synonym fs ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1 ".
    "AND f.feature_id = fs.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_synonym', $sql, $for_workflow, $tableLookup);

    $self->prepareMissingViewsSQL($tableLookup, $listfile, $outdir, 'create', $for_workflow);
}

#----------------------------------------------------------------
# createFilteringViewsSQLForOrganismId()
#
#----------------------------------------------------------------
sub createFilteringViewsSQLForOrganismId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($organism_id, $outdir, $for_workflow) = @_;
    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $listfile = $outdir . '/create_views.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $ibasename = '$;I_FILE_BASE$;';
	$self->writeListFileHeader($listfile, "$ibasename\t$ifilepath\n");
    }

    my $tableLookup = {};

    my $sql = "CREATE VIEW v_organism AS ".
    "SELECT o.* ".
    "FROM organism o ".
    "WHERE o.organism_id != $organism_id ";

    $self->createSQLFile($listfile, $outdir, 'organism', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_organismprop AS ".
    "SELECT op.* ".
    "FROM organismprop op ".
    "WHERE op.organism_id != $organism_id ";

    $self->createSQLFile($listfile, $outdir, 'organismprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_organism_dbxref AS ".
    "SELECT od.* ".
    "FROM organism_dbxref od ".
    "WHERE od.organism_id != $organism_id ";

    $self->createSQLFile($listfile, $outdir, 'organism_dbxref', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature AS ".
    "SELECT f.* ".
    "FROM feature f ".
    "WHERE f.organism_id != $organism_id ";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_pub AS ".
    "SELECT fp.* ".
    "FROM feature_pub fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.organism_id = $organism_id ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_featureloc AS ".
    "SELECT fl.* ".
    "FROM featureloc fl ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.organism_id = $organism_id ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id )) ";

    $self->createSQLFile($listfile, $outdir, 'featureloc', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_relationship AS ".
    "SELECT frel.* ".
    "FROM feature_relationship frel ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.organism_id = $organism_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_relationship_pub AS ".
    "SELECT frelpub.* ".
    "FROM feature_relationship_pub frelpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel ".
    "WHERE f.organism_id = $organism_id ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationship_pub', $sql, $for_workflow, $tableLookup);

    $sql ="CREATE VIEW v_feature_relationshipprop AS ".
    "SELECT frelprop.* ".
    "FROM feature_relationshipprop frelprop ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel ".
    "WHERE f.organism_id = $organism_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relationshipprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_relprop_pub AS ".
    "SELECT frelproppub.* ".
    "FROM feature_relprop_pub frelproppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE f.organism_id = $organism_id ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ".
    "AND frelprop.feature_relationshipprop_id = frelproppub.feature_relationshipprop_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )) ";

    $self->createSQLFile($listfile, $outdir, 'feature_relprop_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_dbxref AS ".
    "SELECT fd.* ".
    "FROM feature_dbxref fd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.organism_id = $organism_id ".
    "AND f.feature_id = fd.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_dbxref', $sql, $for_workflow, $tableLookup);

    $sql ="CREATE VIEW v_featureprop AS ".
    "SELECT fp.* ".
    "FROM featureprop fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.organism_id = $organism_id ".
    "AND f.feature_id = fp.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_featureprop_pub AS ".
    "SELECT fppub.* ".
    "FROM featureprop_pub fppub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, featureprop fp ".
    "WHERE f.organism_id = $organism_id ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fppub.featureprop_id ) ";

    $self->createSQLFile($listfile, $outdir, 'featureprop_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_cvterm AS ".
    "SELECT fc.* ".
    "FROM feature_cvterm fc ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.organism_id = $organism_id ".
    "AND f.feature_id = fc.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm', $sql, $for_workflow, $tableLookup);
    
    $sql = "CREATE VIEW v_feature_cvterm_dbxref AS ".
    "SELECT fcd.* ".
    "FROM feature_cvterm_dbxref fcd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.organism_id = $organism_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_cvterm_pub AS ".
    "SELECT fcpub.* ".
    "FROM feature_cvterm_pub fcpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.organism_id = $organism_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcpub.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvterm_pub', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_cvtermprop AS ".
    "SELECT fcp.* ".
    "FROM feature_cvtermprop fcp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.organism_id = $organism_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_cvtermprop', $sql, $for_workflow, $tableLookup);

    $sql = "CREATE VIEW v_feature_synonym AS ".
    "SELECT fs.* ".
    "FROM feature_synonym fs ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f ".
    "WHERE f.organism_id = $organism_id ".
    "AND f.feature_id = fs.feature_id ) ";

    $self->createSQLFile($listfile, $outdir, 'feature_synonym', $sql, $for_workflow, $tableLookup);

    $self->prepareMissingViewsSQL($tableLookup, $listfile, $outdir, 'create', $for_workflow);
}


#----------------------------------------------------------------
# featureRecordCountByOrganismId()
#
#----------------------------------------------------------------
sub featureRecordCountByOrganismId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret =  $self->{_backend}->getFeatureRecordCountByOrganismId(@_);

    if (defined($ret->[0][0])){
	return $ret->[0][0];
    }

    return 0;
}

#----------------------------------------------------------------
# organismpropRecordCountByOrganismId()
#
#----------------------------------------------------------------
sub organismpropRecordCountByOrganismId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret =  $self->{_backend}->getOrganismpropRecordCountByOrganismId(@_);

    if (defined($ret->[0][0])){
	return $ret->[0][0];
    }

    return 0;
}

#----------------------------------------------------------------
# organismDbxrefRecordCountByOrganismId()
#
#----------------------------------------------------------------
sub organismDbxrefRecordCountByOrganismId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret =  $self->{_backend}->getOrganismDbxrefRecordCountByOrganismId(@_);

    if (defined($ret->[0][0])){
	return $ret->[0][0];
    }

    return 0;
}

#----------------------------------------------------------------
# deleteOrganismpropByOrganismId()
#
#----------------------------------------------------------------
sub deleteOrganismpropByOrganismId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_backend}->doDeleteOrganismpropByOrganismId(@_);
}

#----------------------------------------------------------------
# deleteOrganismDbxrefByOrganismId()
#
#----------------------------------------------------------------
sub deleteOrganismDbxrefByOrganismId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_backend}->doDeleteOrganismDbxrefByOrganismId(@_);
}

#----------------------------------------------------------------
# createTableListFile()
#
#----------------------------------------------------------------
sub createTableListFile {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($outdir) = @_;
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $file = $outdir . '/chado.table.list';

    ## Change double forward slashes into a single forward slash.
    $file =~ s/\/\//\//g;

    my @tables = split(/,/, CHADO_CORE_TABLE_COMMIT_ORDER);
    
    open (OUTFILE, ">$file") || $self->logdie("Could not open file '$file' for output: $!");

    print OUTFILE '$;TABLE$;' . "\n";

    foreach my $table (@tables){
	print OUTFILE "$table\n";
    }
}

#----------------------------------------------------------------
# createChadoMartTableListFile()
#
#----------------------------------------------------------------
sub createChadoMartTableListFile {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($outdir) = @_;
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $file = $outdir . '/chadomart.table.list';

    ## Change double forward slashes into a single forward slash.
    $file =~ s/\/\//\//g;

    my @tables = split(/,/, CHADO_MART_TABLE_COMMIT_ORDER);
    
    open (OUTFILE, ">$file") || $self->logdie("Could not open file '$file' for output: $!");

    print OUTFILE '$;TABLE$;' . "\n";

    foreach my $table (@tables){
	print OUTFILE "$table\n";
    }
}



sub getPhylogenyModuleTableLookup {

    my $lookup = {};
    
    my $tablelist = Prism::phylogenyModuleTableCommitOrder();
    my @tablelist = split(/,/, $tablelist);

    foreach my $table (@tablelist){
	$lookup->{$table}++;
    }

    return $lookup;
}

sub getCVModuleTableLookup {

    my $lookup = {};
    
    my $tablelist = Prism::controlledVocabularyModuleTableCommitOrder();
    my @tablelist = split(/,/, $tablelist);

    foreach my $table (@tablelist){
	$lookup->{$table}++;
    }

    return $lookup;
}


sub getPubModuleTableLookup {

    my $lookup = {};
    
    my $tablelist = Prism::pubModuleTableCommitOrder();
    my @tablelist = split(/,/, $tablelist);

    foreach my $table (@tablelist){
	$lookup->{$table}++;
    }

    return $lookup;
}

sub getGeneralModuleTableLookup {

    my $lookup = {};
    
    my $tablelist = Prism::generalModuleTableCommitOrder();
    my @tablelist = split(/,/, $tablelist);

    foreach my $table (@tablelist){
	$lookup->{$table}++;
    }

    return $lookup;
}

sub getOrganismModuleTableLookup {

    my $lookup = {};
    
    my $tablelist = Prism::organismModuleTableCommitOrder();
    my @tablelist = split(/,/, $tablelist);

    foreach my $table (@tablelist){
	$lookup->{$table}++;
    }

    return $lookup;
}

sub getSequenceModuleTableLookup {

    my $lookup = {};
    
    my $tablelist = Prism::sequenceModuleTableCommitOrder();
    my @tablelist = split(/,/, $tablelist);

    foreach my $table (@tablelist){
	$lookup->{$table}++;
    }

    return $lookup;
}

sub databaseExists {

    my $self = shift;
    
    my $ret = $self->{_backend}->doesDatabaseExist(@_);
    if (defined($ret->[0][0])){
	return 1;
    }
    return 0;
}


#----------------------------------------------------------------
# createDeleteByRangeSQLFilesForAnalysisId()
#
#----------------------------------------------------------------
sub createDeleteByRangeSQLFilesForAnalysisId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($analysis_id, $outdir, $for_workflow) = @_;
    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $computed_by = $self->{_backend}->getCvtermIdByTermNameByOntology('computed_by',
									 'relationship');
    if (!defined($computed_by)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by'");
    }

    my $listfile = $outdir . '/delete_records.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $table     = '$;TABLE$;';
	$self->writeListFileHeader($listfile, "$table\t$ifilepath\n");
    }

    my $sql = "DELETE FROM analysis WHERE analysis_id = $analysis_id";

    $self->createSQLFile($listfile, $outdir, 'analysis', $sql, $for_workflow);
    
    ## table: analysisprop
    my $ret = $self->{_backend}->getMinMaxAnalysispropIdForAnalysisId($analysis_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'analysisprop', $for_workflow, $ret);

    ## table: analysisfeature
    $ret = $self->{_backend}->getMinMaxAnalysisfeatureIdForAnalysisId($analysis_id, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'analysisfeature', $for_workflow, $ret);

    ## table: feature
    $ret = $self->{_backend}->getMinMaxFeatureIdForAnalysisId($analysis_id, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature', $for_workflow, $ret);

    ## table: featureloc
    $ret = $self->{_backend}->getMinMaxFeaturelocIdForAnalysisId($analysis_id, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'featureloc', $for_workflow, $ret);

    ## table: feature_pub
    $ret = $self->{_backend}->getMinMaxFeaturePubIdForAnalysisId($analysis_id, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_pub', $for_workflow, $ret);

    ## table: feature_relationship
    $ret = $self->{_backend}->getMinMaxFeatureRelationshipIdForAnalysisId($analysis_id, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relationship', $for_workflow, $ret);

    ## table: feature_relationship_pub
    $ret = $self->{_backend}->getMinMaxFeatureRelationshipPubIdForAnalysisId($analysis_id, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relationship_pub', $for_workflow, $ret);

    ## table: feature_relationshipprop
    $ret = $self->{_backend}->getMinMaxFeatureRelationshippropIdForAnalysisId($analysis_id, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relationshipprop', $for_workflow, $ret);

    ## table: feature_relationshipprop
    $ret = $self->{_backend}->getMinMaxFeatureRelpropPubIdForAnalysisId($analysis_id, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relprop_pub', $for_workflow, $ret);

    ## table: feature_dbxref
    $ret = $self->{_backend}->getMinMaxFeatureDbxrefIdForAnalysisId($analysis_id, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_dbxref', $for_workflow, $ret);

    ## table: featureprop
    $ret = $self->{_backend}->getMinMaxFeaturepropIdForAnalysisId($analysis_id, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'featureprop', $for_workflow, $ret);

    ## table: featureprop_pub
    $ret = $self->{_backend}->getMinMaxFeaturepropPubIdForAnalysisId($analysis_id, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'featureprop_pub', $for_workflow, $ret);

    ## table: feature_cvterm
    $ret = $self->{_backend}->getMinMaxFeatureCvtermIdForAnalysisId($analysis_id, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvterm', $for_workflow, $ret);

    ## table: feature_cvterm_dbxref
    $ret = $self->{_backend}->getMinMaxFeatureCvtermDbxrefIdForAnalysisId($analysis_id, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $for_workflow, $ret);

    ## table: feature_cvterm_pub
    $ret = $self->{_backend}->getMinMaxFeatureCvtermPubIdForAnalysisId($analysis_id, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvterm_pub', $for_workflow, $ret);

    ## table: feature_cvtermprop
    $ret = $self->{_backend}->getMinMaxFeatureCvtermpropIdForAnalysisId($analysis_id, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvtermprop', $for_workflow, $ret);

    ## table: feature_synonym
    $ret = $self->{_backend}->getMinMaxFeatureSynonymIdForAnalysisId($analysis_id, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_synonym', $for_workflow, $ret);
}

#----------------------------------------------------------------
# createDeleteOneByOneSQLFilesForAnalysisId()
#
#----------------------------------------------------------------
sub createDeleteOneByOneSQLFilesForAnalysisId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($analysis_id, $outdir, $for_workflow) = @_;
    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $computed_by = $self->{_backend}->getCvtermIdByTermNameByOntology('computed_by',
									 'relationship');
    if (!defined($computed_by)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by'");
    }

    my $listfile = $outdir . '/delete_records.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $table     = '$;TABLE$;';
	$self->writeListFileHeader($listfile, "$table\t$ifilepath\n");
    }

    ## table: analysis
    my $sql = "DELETE FROM analysis WHERE analysis_id = $analysis_id";

    $self->createSQLFile($listfile, $outdir, 'analysis', $sql, $for_workflow);
    
    ## table: analysisprop
    my $ret = $self->{_backend}->getAnalysispropIdValuesForAnalysisId($analysis_id);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'analysisprop', $for_workflow, $ret);

    ## table: analysisfeature
    $ret = $self->{_backend}->getAnalysisfeatureIdValuesForAnalysisId($analysis_id, $computed_by);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'analysisfeature', $for_workflow, $ret);

    ## table: feature
    $ret = $self->{_backend}->getFeatureIdValuesForAnalysisId($analysis_id, $computed_by);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'feature', $for_workflow, $ret);

    ## table: featureloc
    $ret = $self->{_backend}->getFeaturelocIdValuesForAnalysisId($analysis_id, $computed_by);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'featureloc', $for_workflow, $ret);

    ## table: feature_pub
    $ret = $self->{_backend}->getFeaturePubIdValuesForAnalysisId($analysis_id, $computed_by);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'feature_pub', $for_workflow, $ret);

    ## table: feature_relationship
    $ret = $self->{_backend}->getFeatureRelationshipIdValuesForAnalysisId($analysis_id, $computed_by);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'feature_relationship', $for_workflow, $ret);

    ## table: feature_relationship_pub
    $ret = $self->{_backend}->getFeatureRelationshipPubIdValuesForAnalysisId($analysis_id, $computed_by);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'feature_relationship_pub', $for_workflow, $ret);

    ## table: feature_relationshipprop
    $ret = $self->{_backend}->getFeatureRelationshippropIdValuesForAnalysisId($analysis_id, $computed_by);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'feature_relationshipprop', $for_workflow, $ret);

    ## table: feature_relationshipprop
    $ret = $self->{_backend}->getFeatureRelpropPubIdValuesForAnalysisId($analysis_id, $computed_by);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'feature_relprop_pub', $for_workflow, $ret);

    ## table: feature_dbxref
    $ret = $self->{_backend}->getFeatureDbxrefIdValuesForAnalysisId($analysis_id, $computed_by);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'feature_dbxref', $for_workflow, $ret);

    ## table: featureprop
    $ret = $self->{_backend}->getFeaturepropIdValuesForAnalysisId($analysis_id, $computed_by);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'featureprop', $for_workflow, $ret);

    ## table: featureprop_pub
    $ret = $self->{_backend}->getFeaturepropPubIdValuesForAnalysisId($analysis_id, $computed_by);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'featureprop_pub', $for_workflow, $ret);

    ## table: feature_cvterm
    $ret = $self->{_backend}->getFeatureCvtermIdValuesForAnalysisId($analysis_id, $computed_by);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'feature_cvterm', $for_workflow, $ret);

    ## table: feature_cvterm_dbxref
    $ret = $self->{_backend}->getFeatureCvtermDbxrefIdValuesForAnalysisId($analysis_id, $computed_by);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $for_workflow, $ret);

    ## table: feature_cvterm_pub
    $ret = $self->{_backend}->getFeatureCvtermPubIdValuesForAnalysisId($analysis_id, $computed_by);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'feature_cvterm_pub', $for_workflow, $ret);

    ## table: feature_cvtermprop
    $ret = $self->{_backend}->getFeatureCvtermpropIdValuesForAnalysisId($analysis_id, $computed_by);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'feature_cvtermprop', $for_workflow, $ret);

    ## table: feature_synonym
    $ret = $self->{_backend}->getFeatureSynonymIdValuesForAnalysisId($analysis_id, $computed_by);

    $self->createOneDeleteStmtPerRecordSQLFile($listfile, $outdir, 'feature_synonym', $for_workflow, $ret);
}

#----------------------------------------------------------------
# createDeleteByRangeSQLFilesForAlgorithm()
#
#----------------------------------------------------------------
sub createDeleteByRangeSQLFilesForAlgorithm {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($algorithm, $outdir, $for_workflow) = @_;
    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $computed_by = $self->{_backend}->getCvtermIdByTermNameByOntology('computed_by',
									 'relationship');
    if (!defined($computed_by)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by'");
    }

    my $listfile = $outdir . '/delete_records.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $table     = '$;TABLE$;';
	$self->writeListFileHeader($listfile, "$table\t$ifilepath\n");
    }

    my $sql = "DELETE FROM analysis WHERE algorithm = '$algorithm'";

    $self->createSQLFile($listfile, $outdir, 'analysis', $sql, $for_workflow);
    
    ## table: analysisprop
    my $ret = $self->{_backend}->getMinMaxAnalysispropIdForAlgorithm($algorithm);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'analysisprop', $for_workflow, $ret);

    ## table: analysisfeature
    $ret = $self->{_backend}->getMinMaxAnalysisfeatureIdForAlgorithm($algorithm, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'analysisfeature', $for_workflow, $ret);

    ## table: feature
    $ret = $self->{_backend}->getMinMaxFeatureIdForAlgorithm($algorithm, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature', $for_workflow, $ret);

    ## table: featureloc
    $ret = $self->{_backend}->getMinMaxFeaturelocIdForAlgorithm($algorithm, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'featureloc', $for_workflow, $ret);

    ## table: feature_pub
    $ret = $self->{_backend}->getMinMaxFeaturePubIdForAlgorithm($algorithm, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_pub', $for_workflow, $ret);

    ## table: feature_relationship
    $ret = $self->{_backend}->getMinMaxFeatureRelationshipIdForAlgorithm($algorithm, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relationship', $for_workflow, $ret);

    ## table: feature_relationship_pub
    $ret = $self->{_backend}->getMinMaxFeatureRelationshipPubIdForAlgorithm($algorithm, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relationship_pub', $for_workflow, $ret);

    ## table: feature_relationshipprop
    $ret = $self->{_backend}->getMinMaxFeatureRelationshippropIdForAlgorithm($algorithm, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relationshipprop', $for_workflow, $ret);

    ## table: feature_relationshipprop
    $ret = $self->{_backend}->getMinMaxFeatureRelpropPubIdForAlgorithm($algorithm, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relprop_pub', $for_workflow, $ret);

    ## table: feature_dbxref
    $ret = $self->{_backend}->getMinMaxFeatureDbxrefIdForAlgorithm($algorithm, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_dbxref', $for_workflow, $ret);

    ## table: featureprop
    $ret = $self->{_backend}->getMinMaxFeaturepropIdForAlgorithm($algorithm, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'featureprop', $for_workflow, $ret);

    ## table: featureprop_pub
    $ret = $self->{_backend}->getMinMaxFeaturepropPubIdForAlgorithm($algorithm, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'featureprop_pub', $for_workflow, $ret);

    ## table: feature_cvterm
    $ret = $self->{_backend}->getMinMaxFeatureCvtermIdForAlgorithm($algorithm, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvterm', $for_workflow, $ret);

    ## table: feature_cvterm_dbxref
    $ret = $self->{_backend}->getMinMaxFeatureCvtermDbxrefIdForAlgorithm($algorithm, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $for_workflow, $ret);

    ## table: feature_cvterm_pub
    $ret = $self->{_backend}->getMinMaxFeatureCvtermPubIdForAlgorithm($algorithm, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvterm_pub', $for_workflow, $ret);

    ## table: feature_cvtermprop
    $ret = $self->{_backend}->getMinMaxFeatureCvtermpropIdForAlgorithm($algorithm, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvtermprop', $for_workflow, $ret);

    ## table: feature_synonym
    $ret = $self->{_backend}->getMinMaxFeatureSynonymIdForAlgorithm($algorithm, $computed_by);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_synonym', $for_workflow, $ret);
}

#----------------------------------------------------------------
# createDeleteByRangeSQLFilesForFeatureId()
#
#----------------------------------------------------------------
sub createDeleteByRangeSQLFilesForFeatureId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($feature_id, $outdir, $for_workflow) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("algorithm was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $listfile = $outdir . '/delete_records.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $table     = '$;TABLE$;';
	$self->writeListFileHeader($listfile, "$table\t$ifilepath\n");
    }

    my $sql = "DELETE FROM feature WHERE feature_id = $feature_id";

    $self->createSQLFile($listfile, $outdir, 'feature', $sql, $for_workflow);
    
    ## table: analysisfeature
    my $ret = $self->{_backend}->getMinMaxAnalysisfeatureIdForFeatureId($feature_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'analysisfeature', $for_workflow, $ret);

    ## table: featureloc
    $ret = $self->{_backend}->getMinMaxFeaturelocIdForFeatureId($feature_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'featureloc', $for_workflow, $ret);

    ## table: feature_pub
    $ret = $self->{_backend}->getMinMaxFeaturePubIdForFeatureId($feature_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_pub', $for_workflow, $ret);

    ## table: feature_relationship
    $ret = $self->{_backend}->getMinMaxFeatureRelationshipIdForFeatureId($feature_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relationship', $for_workflow, $ret);

    ## table: feature_relationship_pub
    $ret = $self->{_backend}->getMinMaxFeatureRelationshipPubIdForFeatureId($feature_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relationship_pub', $for_workflow, $ret);

    ## table: feature_relationshipprop
    $ret = $self->{_backend}->getMinMaxFeatureRelationshippropIdForFeatureId($feature_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relationshipprop', $for_workflow, $ret);

    ## table: feature_relationshipprop
    $ret = $self->{_backend}->getMinMaxFeatureRelpropPubIdForFeatureId($feature_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relprop_pub', $for_workflow, $ret);

    ## table: feature_dbxref
    $ret = $self->{_backend}->getMinMaxFeatureDbxrefIdForFeatureId($feature_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_dbxref', $for_workflow, $ret);

    ## table: featureprop
    $ret = $self->{_backend}->getMinMaxFeaturepropIdForFeatureId($feature_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'featureprop', $for_workflow, $ret);

    ## table: featureprop_pub
    $ret = $self->{_backend}->getMinMaxFeaturepropPubIdForFeatureId($feature_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'featureprop_pub', $for_workflow, $ret);

    ## table: feature_cvterm
    $ret = $self->{_backend}->getMinMaxFeatureCvtermIdForFeatureId($feature_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvterm', $for_workflow, $ret);

    ## table: feature_cvterm_dbxref
    $ret = $self->{_backend}->getMinMaxFeatureCvtermDbxrefIdForFeatureId($feature_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $for_workflow, $ret);

    ## table: feature_cvterm_pub
    $ret = $self->{_backend}->getMinMaxFeatureCvtermPubIdForFeatureId($feature_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvterm_pub', $for_workflow, $ret);

    ## table: feature_cvtermprop
    $ret = $self->{_backend}->getMinMaxFeatureCvtermpropIdForFeatureId($feature_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvtermprop', $for_workflow, $ret);

    ## table: feature_synonym
    $ret = $self->{_backend}->getMinMaxFeatureSynonymIdForFeatureId($feature_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_synonym', $for_workflow, $ret);
}

#----------------------------------------------------------------
# createDeleteByRangeSQLFilesForIsObsolete()
#
#----------------------------------------------------------------
sub createDeleteByRangeSQLFilesForIsObsolete {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($outdir, $for_workflow) = @_;

    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $listfile = $outdir . '/delete_records.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $table     = '$;TABLE$;';
	$self->writeListFileHeader($listfile, "$table\t$ifilepath\n");
    }

    ## table: feature
    my $ret = $self->{_backend}->getMinMaxFeatureIdForIsObsolete();

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature', $for_workflow, $ret);
    
    ## table: analysisfeature
    $ret = $self->{_backend}->getMinMaxAnalysisfeatureIdForIsObsolete();

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'analysisfeature', $for_workflow, $ret);

    ## table: featureloc
    $ret = $self->{_backend}->getMinMaxFeaturelocIdForIsObsolete();

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'featureloc', $for_workflow, $ret);

    ## table: feature_pub
    $ret = $self->{_backend}->getMinMaxFeaturePubIdForIsObsolete();

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_pub', $for_workflow, $ret);

    ## table: feature_relationship
    $ret = $self->{_backend}->getMinMaxFeatureRelationshipIdForIsObsolete();

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relationship', $for_workflow, $ret);

    ## table: feature_relationship_pub
    $ret = $self->{_backend}->getMinMaxFeatureRelationshipPubIdForIsObsolete();

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relationship_pub', $for_workflow, $ret);

    ## table: feature_relationshipprop
    $ret = $self->{_backend}->getMinMaxFeatureRelationshippropIdForIsObsolete();

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relationshipprop', $for_workflow, $ret);

    ## table: feature_relationshipprop
    $ret = $self->{_backend}->getMinMaxFeatureRelpropPubIdForIsObsolete();

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relprop_pub', $for_workflow, $ret);

    ## table: feature_dbxref
    $ret = $self->{_backend}->getMinMaxFeatureDbxrefIdForIsObsolete();

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_dbxref', $for_workflow, $ret);

    ## table: featureprop
    $ret = $self->{_backend}->getMinMaxFeaturepropIdForIsObsolete();

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'featureprop', $for_workflow, $ret);

    ## table: featureprop_pub
    $ret = $self->{_backend}->getMinMaxFeaturepropPubIdForIsObsolete();

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'featureprop_pub', $for_workflow, $ret);

    ## table: feature_cvterm
    $ret = $self->{_backend}->getMinMaxFeatureCvtermIdForIsObsolete();

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvterm', $for_workflow, $ret);

    ## table: feature_cvterm_dbxref
    $ret = $self->{_backend}->getMinMaxFeatureCvtermDbxrefIdForIsObsolete();

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $for_workflow, $ret);

    ## table: feature_cvterm_pub
    $ret = $self->{_backend}->getMinMaxFeatureCvtermPubIdForIsObsolete();

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvterm_pub', $for_workflow, $ret);

    ## table: feature_cvtermprop
    $ret = $self->{_backend}->getMinMaxFeatureCvtermpropIdForIsObsolete();

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvtermprop', $for_workflow, $ret);

    ## table: feature_synonym
    $ret = $self->{_backend}->getMinMaxFeatureSynonymIdForIsObsolete();

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_synonym', $for_workflow, $ret);
}


#----------------------------------------------------------------
# createDeleteByRangeSQLFilesForOrganismId()
#
#----------------------------------------------------------------
sub createDeleteByRangeSQLFilesForOrganismId {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my ($organism_id, $outdir, $for_workflow) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if (!defined($outdir)){
	$self->{_logger}->logdie("outdir was not defined");
    }

    my $listfile = $outdir . '/delete_records.sql.list';

    if ((defined($for_workflow)) && ($for_workflow == 1)){
	my $ifilepath = '$;I_FILE_PATH$;';
	my $table     = '$;TABLE$;';
	$self->writeListFileHeader($listfile, "$table\t$ifilepath\n");
    }

    my $sql = "DELETE FROM organism WHERE organism_id = $organism_id";

    $self->createSQLFile($listfile, $outdir, 'organism', $sql, $for_workflow);

    ## table: organism_dbxref
    my $ret = $self->{_backend}->getMinMaxOrganismDbxrefIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'organism_dbxref', $for_workflow, $ret);

    ## table: organismprop
    $ret = $self->{_backend}->getMinMaxOrganismpropIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'organismprop', $for_workflow, $ret);

    ## table: feature
    $ret = $self->{_backend}->getMinMaxFeatureIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature', $for_workflow, $ret);
    
    ## table: analysisfeature
    $ret = $self->{_backend}->getMinMaxAnalysisfeatureIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'analysisfeature', $for_workflow, $ret);

    ## table: featureloc
    $ret = $self->{_backend}->getMinMaxFeaturelocIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'featureloc', $for_workflow, $ret);

    ## table: feature_pub
    $ret = $self->{_backend}->getMinMaxFeaturePubIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_pub', $for_workflow, $ret);

    ## table: feature_relationship
    $ret = $self->{_backend}->getMinMaxFeatureRelationshipIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relationship', $for_workflow, $ret);

    ## table: feature_relationship_pub
    $ret = $self->{_backend}->getMinMaxFeatureRelationshipPubIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relationship_pub', $for_workflow, $ret);

    ## table: feature_relationshipprop
    $ret = $self->{_backend}->getMinMaxFeatureRelationshippropIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relationshipprop', $for_workflow, $ret);

    ## table: feature_relationshipprop
    $ret = $self->{_backend}->getMinMaxFeatureRelpropPubIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_relprop_pub', $for_workflow, $ret);

    ## table: feature_dbxref
    $ret = $self->{_backend}->getMinMaxFeatureDbxrefIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_dbxref', $for_workflow, $ret);

    ## table: featureprop
    $ret = $self->{_backend}->getMinMaxFeaturepropIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'featureprop', $for_workflow, $ret);

    ## table: featureprop_pub
    $ret = $self->{_backend}->getMinMaxFeaturepropPubIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'featureprop_pub', $for_workflow, $ret);

    ## table: feature_cvterm
    $ret = $self->{_backend}->getMinMaxFeatureCvtermIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvterm', $for_workflow, $ret);

    ## table: feature_cvterm_dbxref
    $ret = $self->{_backend}->getMinMaxFeatureCvtermDbxrefIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvterm_dbxref', $for_workflow, $ret);

    ## table: feature_cvterm_pub
    $ret = $self->{_backend}->getMinMaxFeatureCvtermPubIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvterm_pub', $for_workflow, $ret);

    ## table: feature_cvtermprop
    $ret = $self->{_backend}->getMinMaxFeatureCvtermpropIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_cvtermprop', $for_workflow, $ret);

    ## table: feature_synonym
    $ret = $self->{_backend}->getMinMaxFeatureSynonymIdForOrganismId($organism_id);

    $self->createDeleteByRangeSQLFile($listfile, $outdir, 'feature_synonym', $for_workflow, $ret);
}

#---------------------------------------------------------
# foreignKeyConstraintsList()
#
#---------------------------------------------------------
sub foreignKeyConstraintsList {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->getForeignKeyConstraintsList(@_);

    my @list;

    foreach my $retArr ( @{$ret} ){
	push(@list, $retArr->[0]);
    }

    return \@list;
}

#---------------------------------------------------------
# foreignKeyConstraintAndTableList()
#
#---------------------------------------------------------
sub foreignKeyConstraintAndTableList {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    return $self->{_backend}->getForeignKeyConstraintAndTableList(@_);
}

#---------------------------------------------------------
# dropForeignKeyConstraint()
#
#---------------------------------------------------------
sub dropForeignKeyConstraint {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_backend}->doDropForeignKeyConstraint(@_);
}

#---------------------------------------------------------
# tableList()
#
#---------------------------------------------------------
sub tableList {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $ret = $self->{_backend}->getTableList(@_);

    my @list;

    foreach my $retArr ( @{$ret} ){
	push(@list, $retArr->[0]);
    }

    return \@list;
}

#---------------------------------------------------------
# dropTable()
#
#---------------------------------------------------------
sub dropTable {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{_backend}->doDropTable(@_);
}

#---------------------------------------------------------
# orgdbToAsmblId()
#
#---------------------------------------------------------
sub orgdbToAsmblId {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    my $lookup = {};

    my $ret = $self->{_backend}->getOrgDbToAsmblId(@_);
    for (my $i=0; $i < scalar(@{$ret}); $i++){
	$lookup->{$ret->[$i][0]}->{$ret->[$i][1]}++;
    }
    return $lookup;
}


## OBO related methods 


=item $obj->ontologyLoaded($defaultNamespace)

B<Description:> Checks whether the ontology with the default-namespace is loaded in the CV module

B<Parameters:> $defaultNamespace - scalar

B<Returns:>

 0 - scalar
 1 - scalar

=cut 

sub ontologyLoaded {

    my $self = shift;
    my ($defaultNamespace) = @_;

    my $ret = $self->{_backend}->isOntologyLoaded(@_);
    if ($ret->[0][0] != 0){
	return 1;
    }
    else {
	return 0;
    }
}

=item $obj->oboTermStanzaCrossReferences($defaultNamespace)

B<Description:> Retrieve the cross-reference data

B<Parameters:> $defaultNamespace - scalar

B<Returns:> Hash reference

=cut 

sub oboTermStanzaCrossReferences {

    my $self = shift;
    my ($defaultNamespace) = @_;

    my $ret = $self->{_backend}->getOboTermStanzaCrossReferences($defaultNamespace);
    
    my $lookup = {};

    foreach my $arrayRef ( @{$ret} ){
	my $key = shift @{$arrayRef};
	push(@{$lookup->{$key}}, $arrayRef);
    }

    return $lookup;
}


=item $obj->oboTermStanzaSynonyms($defaultNamespace)

B<Description:> Retrieve the synonym data

B<Parameters:> $defaultNamespace - scalar

B<Returns:> Hash reference

=cut 

sub oboTermStanzaSynonyms {

    my $self = shift;
    my ($defaultNamespace) = @_;

    my $ret = $self->{_backend}->getOboTermStanzaSynonyms($defaultNamespace);
    
    my $lookup = {};

    foreach my $arrayRef ( @{$ret} ){
	my $key = shift @{$arrayRef};
	push(@{$lookup->{$key}}, $arrayRef);
    }

    return $lookup;
}

=item $obj->oboTermStanzaRelationships($defaultNamespace)

B<Description:> Retrieve the relationship data

B<Parameters:> $defaultNamespace - scalar

B<Returns:> Hash reference

=cut 

sub oboTermStanzaRelationships {

    my $self = shift;
    my ($defaultNamespace) = @_;

    my $ret = $self->{_backend}->getOboTermStanzaRelationships($defaultNamespace);
    
    my $lookup = {};

    foreach my $arrayRef ( @{$ret} ){
	my $key = shift @{$arrayRef};
	push(@{$lookup->{$key}}, $arrayRef);
    }

    return $lookup;
}


=item $obj->oboTermStanzaProperties($defaultNamespace)

B<Description:> Retrieve the cvterm properties

B<Parameters:> $defaultNamespace - scalar

B<Returns:> Hash reference

=cut 

sub oboTermStanzaProperties {

    my $self = shift;
    my ($defaultNamespace) = @_;

    my $ret = $self->{_backend}->getOboTermStanzaProperties($defaultNamespace);
    
    my $lookup = {};

    foreach my $arrayRef ( @{$ret} ){
	my $key = shift @{$arrayRef};
	push(@{$lookup->{$key}}, $arrayRef);
    }

    return $lookup;
}


=item $obj->deriveOboFromChado($defaultNamespace)

B<Description:> Derive the ontology data from chado CV module

B<Parameters:> $defaultNamespace - scalar

B<Returns:> Reference to OBOBuilder object

=cut 

sub deriveOboFromChado {

    my $self = shift;
    my ($defaultNamespace, $username, $date, $autoGeneratedBy) = @_;
    
    ## CV Module tables are:
    ## cvterm
    ## cvtermprop
    ## cvterm_dbxref
    ## cvterm_relationship
    ## cvtermsynonym
    ## db
    ## dbxref
    ## dbxrefprop

    my $oboBuilder = new OBO::OBOBuilder;

    $oboBuilder->setDefaultNamespace($defaultNamespace);
    $oboBuilder->addHeader('date' => $date);
    $oboBuilder->addHeader('saved-by' => $username);
    $oboBuilder->addHeader('auto-generated-by' => $autoGeneratedBy);

    # id   = dbxref.accession where dbxref.db_id = db.db_id and db.name = default-namespace
    # name = cvterm.name where cvterm.dbxref_id = dbxref.dbxref_id and dbxref.db_id = db.db_id and db.name = default-namespace
    # def  = cvterm.definition where cvterm.dbxref_id = dbxref.dbxref_id and dbxref.db_id = db.db_id and db.name = default-namespace

    my $coreTermStanzaElements = $self->{_backend}->getCoreOboTermStanzaElements($defaultNamespace);

    my $crossReferences = $self->oboTermStanzaCrossReferences($defaultNamespace);

    my $synonyms = $self->oboTermStanzaSynonyms($defaultNamespace);

    my $relationships = $self->oboTermStanzaRelationships($defaultNamespace);

    my $properties = $self->oboTermStanzaProperties($defaultNamespace);

    foreach my $array ( @{$coreTermStanzaElements} ){

	my $oboTerm = new OBO::OBOTerm($array->[0], $array->[1], $array->[2], $array->[3]);

	if (exists $crossReferences->{$array->[0]}){
	    foreach my $xrefArray ( @{$crossReferences->{$array->[0]}} ) {
		if ($xrefArray->[0] eq 'xref'){
		    $oboTerm->addXref($xrefArray->[1]);
		}
		elsif ($xrefArray->[0] eq 'alt_id'){
		    $oboTerm->addAltId($xrefArray->[1]);
		}
		else {
		    $self->{_logger}->warn("Encountered unexpected cross-reference type '$xrefArray->[0]' ".
					   "with value '$xrefArray->[1]' while processing OBO record ".
					   "with id '$array->[0]'.  This is a result of the OBO record ".
					   "having not been loaded correctly into chado.  Will simply ".
					   "assign tag alt_id.");
		    $oboTerm->addAltId($xrefArray->[1]);
		}
	    }
	}

	if (exists $synonyms->{$array->[0]}){

	    foreach my $synonymsArray ( @{$synonyms->{$array->[0]}} ) {
		if (lc($synonymsArray->[0]) =~ /exact/){
		    $oboTerm->addExactSynonym($synonymsArray->[1]);
		}
		elsif (lc($synonymsArray->[0]) =~ /narrow/){
		    $oboTerm->addNarrowSynonym($synonymsArray->[1]);
		}
		elsif (lc($synonymsArray->[0]) =~ /broad/){
		    $oboTerm->addBroadSynonym($synonymsArray->[1]);
		}
		elsif (lc($synonymsArray->[0]) =~ /related/){
		    $oboTerm->addRelatedSynonym($synonymsArray->[1]);
		}
		else {
		    $self->{_logger}->logdie("Encountered unexpected synonym type '$synonymsArray->[0]' ".
					     "with value '$synonymsArray->[1]' while processing OBO record ".
					     "with id '$array->[0]'");
		}
	    }
	}

	if (exists $relationships->{$array->[0]}){
	    foreach my $relationshipsArray ( @{$relationships->{$array->[0]}} ) {
		$oboTerm->addRelationship($relationshipsArray->[0], $relationshipsArray->[1]);
	    }
	}

	if (exists $properties->{$array->[0]}){
	    foreach my $propertiesArray ( @{$properties->{$array->[0]}} ) {
		if (lc($propertiesArray->[0]) eq 'comment'){
		    $oboTerm->setComment($propertiesArray->[1]);
		}
		else {
		    $self->{_logger}->logdie("Encountered unexpected properties type '$propertiesArray->[0]' ".
					     "with value '$propertiesArray->[1]' while processing OBO record ".
					     "with id '$array->[0]'");
		}
	    }
	}

	$oboBuilder->addTermById($array->[0], $oboTerm);
    }

    return $oboBuilder;
}


##----------------------------------------------------------------
## prepareFeaturelocRecordN()
##
##----------------------------------------------------------------
sub prepareFeaturelocRecordN {

    my $self = shift;
    my (%args) = @_;

    $self->prepareFeaturelocRecord($args{'feature_id'},
				   $args{'srcfeature_id'},
				   $args{'locgroup'},
				   $args{'rank'},
				   $args{'fmin'},
				   $args{'fmax'},
				   $args{'strand'},
				   $args{'is_fmin_partial'},
				   $args{'is_fmax_partial'});

}

##----------------------------------------------------------------
## prepareFeaturelocRecord()
##
##----------------------------------------------------------------
sub prepareFeaturelocRecord {

    my $self = shift;
    my ($feature_id, $srcfeature_id, $locgroup, $rank, $fmin, $fmax, $strand, $is_fmin_partial, $is_fmax_partial) = @_;


    ## Check whether this feature is localized to this particular srcfeature.
    ## If a featureloc record with the same fmin, fmax, strand values does not
    ## already exist, then we need to insert a new featureloc record.

    my $featureloc_id = $self->checkFeaturelocIdLookup($srcfeature_id, $feature_id, $fmin, $fmax, $strand);

    if (!defined($featureloc_id)){
	
	if (!defined($locgroup)){
	    $locgroup = 0;
	}
	if (!defined($rank)){
	    $rank = 0;
	}

	## Need to determine the correct rank value
	do {
	    $featureloc_id = $self->check_featureloc_id_lookup(
							       feature_id => $feature_id,
							       locgroup   => $locgroup,
							       rank       => $rank,
							       status     => 'warn'
							       );
	    
	} while ((defined($featureloc_id)) && (++$rank));
	
	## The API maintains a record lookup per table.
	## Attempt to insert record into chado.featureloc

	if (!defined($is_fmin_partial)){
	    $is_fmin_partial = 0;
	}
	if (!defined($is_fmax_partial)){
	    $is_fmax_partial = 0;
	}

	$featureloc_id = $self->{_backend}->do_store_new_featureloc(
								    feature_id      => $feature_id,
								    srcfeature_id   => $srcfeature_id,
								    fmin            => $fmin,
								    is_fmin_partial => $is_fmin_partial,
								    fmax            => $fmax,
								    is_fmax_partial => $is_fmax_partial,
								    strand          => $strand,
								    phase           => undef,
								    residue_info    => undef,
								    locgroup        => $locgroup,
								    rank            => $rank,
								    );
	
	if (!defined($featureloc_id)){
	    $self->{_logger}->logdie("featureloc_id was not defined.  Could not insert record into chado.featureloc ".
				     "for feature_id '$feature_id' srcfeature_id '$srcfeature_id' locgroup '$locgroup' ".
				     "rank '$rank'");
	}
    }
    else {
	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->is_debug("A featureloc record already exists for this srcfeature_id '$srcfeature_id' ".
				       "feature_id '$feature_id' fmin '$fmin' fmax '$fmax' strand '$strand'");
	}
    }
}

##----------------------------------------------------------------
## checkFeaturelocIdLookup()
##
##----------------------------------------------------------------
sub checkFeaturelocIdLookup {

    my $self = shift;

    my ($srcfeature_id, $feature_id, $fmin, $fmax, $strand) = @_;

    if (( exists $self->{'featurelocIdLookup'}) && (defined($self->{'featurelocIdLookup'}) )) {

	if (!defined($srcfeature_id)){
	    $self->{_logger}->logdie("srcfeature_id was not defined");
	}

	if (!defined($feature_id)){
	    $self->{_logger}->logdie("feature_id was not defined");
	}

	if (! $self->checkCoordinatesForChado($fmin,$fmax)){
	    $self->{_logger}->logdie("Detected some problem with the coordinates while processing feature ".
				     "with feature_id '$feature_id' srcfeature_id '$srcfeature_id'.  Please ".
				     "see review the log file.");
	}

	my $featureloc_id;
	
	my $index = $srcfeature_id . '_' . $feature_id . '_' . $fmin . '_' . $fmax . '_' . $strand;
	
	if (( exists $self->{'featurelocIdLookup'}->{$index}->[0]) && (defined($self->{'featurelocIdLookup'}->{$index}->[0]))){
	    return $self->{'featurelocIdLookup'}->{$index}->[0];
	}
	else {
	    return undef;
	}
    }
    else {
	$self->{_logger}->logdie("featurelocIdLookup does not exist");
    }
}

##----------------------------------------------------------------
## prepareFeaturepropRecord()
##
##----------------------------------------------------------------
sub prepareFeaturepropRecord {

    my $self = shift;
    my ($feature_id, $type_id, $value) = @_;

    ## Verify whether the featureprop tuple (feature_id, type_id, value) already exists.
    my $featureprop_id = $self->checkFeaturepropIdLookup($feature_id, $type_id, $value);

    if (!defined($featureprop_id)){
	## The featureprop tuple does not exist.

	## Get the next rank value for the given feature_id, type_id.
	my $rank = $self->nextFeaturepropRank($feature_id,$type_id);

	## Create the new featureprop record.
	$featureprop_id = $self->{_backend}->do_store_new_featureprop(
								      feature_id   => $feature_id,
								      type_id      => $type_id,
								      value        => $value,
								      rank         => $rank
								      );
	
	if (!defined($featureprop_id)){
	    $self->{_logger}->logdie("featureprop_id was not defined.  Could not insert record into chado.featureprop ".
				     "for feature_id '$feature_id' type_id '$type_id' value '$value' rank '$rank'");
	}
    }
    else {
	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->is_debug("A featureprop record already exists for this feature_id '$feature_id' ".
				       "type_id '$type_id' value '$value'");
	}
    }
}


##----------------------------------------------------------------
## checkFeaturepropIdLookup()
##
##----------------------------------------------------------------
sub checkFeaturepropIdLookup {

    my $self = shift;

    my ($feature_id, $type_id, $value) = @_;

    if (( exists $self->{'featurepropIdLookup'}) && (defined($self->{'featurepropIdLookup'}) )) {

	if (!defined($feature_id)){
	    $self->{_logger}->logdie("feature_id was not defined");
	}

	if (!defined($type_id)){
	    $self->{_logger}->logdie("type_id was not defined");
	}

	if (!defined($value)){
	    $self->{_logger}->logdie("value was not defined");
	}
	
	my $index = $feature_id . '_' . $type_id . '_' . $value;
	
	if (( exists $self->{'featurepropIdLookup'}->{$index}->[0]) && (defined($self->{'featurepropIdLookup'}->{$index}->[0]))){
	    return $self->{'featurepropIdLookup'}->{$index}->[0];
	}
	else {
	    if ($self->{_logger}->is_debug()){
		$self->{_logger}->debug("There was no featureprop_id in the featurepropIdLookup ".
					"for feature_id '$feature_id' type_id '$type_id' value '$value'");
	    }
	    return undef;
	}
    }
    else {
	$self->{_logger}->logdie("featurepropIdLookup does not exist");
    }
}


##----------------------------------------------------------------
## nextFeaturepropRank()
##
##----------------------------------------------------------------
sub nextFeaturepropRank {

    my $self = shift;
    my ($feature_id, $type_id) = @_;

    ## This method will return the next featureprop.rank value for the given
    ## feature_id and type_id.

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("nextFeaturepropRank");
    }

    if (( exists $self->{'featurepropMaxRankLookup'}) && (defined($self->{'featurepropMaxRankLookup'}) )) {
	## Everything is okay.
    }
    else {
	$self->{_logger}->logdie("featurepropMaxRankLookup was not defined");
    }


    my $index = $feature_id . '_' . $type_id;

    if (( exists $self->{'featurepropMaxRankLookup'}->{$index} ) && 
        ( exists $self->{'featurepropMaxRankLookup'}->{$index}->[0] ) &&
        (defined($self->{'featurepropMaxRankLookup'}->{$index}->[0]))){

	my $rank = $self->{'featurepropMaxRankLookup'}->{$index}->[0];

	$rank++;

	return $rank;
    }
    else {
	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->debug("No rank value was in featurepropMaxRankLookup ".
				    "for feature_id '$feature_id' type_id '$type_id'");
	}
    }

    ## No value was defined for this particular feature_id and type_id, therefore simply return 0
    return 0;
}

=item $obj->analysispropDuplicateRecordCount()

B<Description:> Will invoke the lower-level API method for retrieving number of duplicate records in analysisprop

B<Parameters:> None

B<Returns:> count (int)

=cut

sub analysispropDuplicateRecordCount {

    my $self = shift;

    my $count = $self->{_backend}->getAnalysispropDuplicateRecordCount();

    if (defined($count)){
	return $count->[0][0];
    }
    else {
	return 0;
    }

}

=item $obj->dbxrefpropDuplicateRecordCount()

B<Description:> Will invoke the lower-level API method for retrieving number of duplicate records in dbxrefprop

B<Parameters:> None

B<Returns:> count (int)

=cut

sub dbxrefpropDuplicateRecordCount {

    my $self = shift;
    
    my $count = $self->{_backend}->getDbxrefpropDuplicateRecordCount();

    if (defined($count)){
	return $count->[0][0];
    }
    else {
	return 0;
    }

}

=item $obj->featureCvtermpropDuplicateRecordCount()

B<Description:> Will invoke the lower-level API method for retrieving number of duplicate records in feature_cvtermprop

B<Parameters:> None

B<Returns:> count (int)

=cut

sub featureCvtermpropDuplicateRecordCount {

    my $self = shift;

    my $count = $self->{_backend}->getFeatureCvtermpropDuplicateRecordCount();

    if (defined($count)){
	return $count->[0][0];
    }
    else {
	return 0;
    }


}

=item $obj->featurepropDuplicateRecordCount()

B<Description:> Will invoke the lower-level API method for retrieving number of duplicate records in featureprop

B<Parameters:> None

B<Returns:> count (int)

=cut

sub featurepropDuplicateRecordCount {

    my $self = shift;

    my $count = $self->{_backend}->getFeaturepropDuplicateRecordCount();

    if (defined($count)){
	return $count->[0][0];
    }
    else {
	return 0;
    }


}

=item $obj->featureRelationshippropDuplicateRecordCount()

B<Description:> Will invoke the lower-level API method for retrieving number of duplicate records in feature_relationshipprop

B<Parameters:> None

B<Returns:> count (int)

=cut

sub featureRelationshippropDuplicateRecordCount {

    my $self = shift;

    my $count = $self->{_backend}->getFeatureRelationshippropDuplicateRecordCount();

    if (defined($count)){
	return $count->[0][0];
    }
    else {
	return 0;
    }   

}

=item $obj->organismpropDuplicateRecordCount()

B<Description:> Will invoke the lower-level API method for retrieving number of duplicate records in organismprop

B<Parameters:> None

B<Returns:> count (int)

=cut

sub organismpropDuplicateRecordCount {

    my $self = shift;

    my $count = $self->{_backend}->getOrganismpropDuplicateRecordCount();

    if (defined($count)){
	return $count->[0][0];
    }
    else {
	return 0;
    }


}

=item $obj->phylonodepropDuplicateRecordCount()

B<Description:> Will invoke the lower-level API method for retrieving number of duplicate records in phylonodeprop

B<Parameters:> None

B<Returns:> count (int)

=cut

sub phylonodepropDuplicateRecordCount {

    my $self = shift;

    my $count = $self->{_backend}->getPhylonodepropDuplicateRecordCount();

    if (defined($count)){
	return $count->[0][0];
    }
    else {
	return 0;
    }


}

=item $obj->pubpropDuplicateRecordCount()

B<Description:> Will invoke the lower-level API method for retrieving number of duplicate records in pubprop

B<Parameters:> None

B<Returns:> count (int)

=cut

sub pubpropDuplicateRecordCount {

    my $self = shift;

    my $count = $self->{_backend}->getPubpropDuplicateRecordCount();

    if (defined($count)){
	return $count->[0][0];
    }
    else {
	return 0;
    }


}

=item $obj->featurelocFminGreaterThanFmaxCount()

B<Description:> Will invoke the lower-level API method for retrieving number of featureloc records where fmin>fmax

B<Parameters:> None

B<Returns:> count (int)

=cut

sub featurelocFminGreaterThanFmaxCount {

    my $self = shift;

    my $count = $self->{_backend}->getFeaturelocFminGreaterThanFmaxCount();

    if (defined($count)){
	return $count->[0][0];
    }
    else {
	return 0;
    }
}

=item $obj->invalidFeaturelocStrandValueCount()

B<Description:> Will retrieve the number of featureloc records for which the strand is not NULL, -1, 0, 1

B<Parameters:> None

B<Returns:> count (int)

=cut

sub invalidFeaturelocStrandValueCount {

    my $self = shift;

    my $ret = $self->{_backend}->getDistinctFeaturelocStrandValues();

    my $count=0;

    for (my $i=0; $i < scalar(@{$ret}); $i++){

	if (defined($ret->[$i][0])){
	    if ( ( $ret->[$i][0] == -1 ) ||
		 ( $ret->[$i][0] == 0 ) ||
		 ( $ret->[$i][0] == 1 )){
		## valid record
	    }
	    else {
		$count++;
	    }
	}
    }

    return $count;
}

=item $obj->featureResiduesSeqlenLookup()

B<Description:> Will retrieve all feature_id, uniquename, residues and seqlen values from feature table

B<Parameters:> $ignore_obsolete (scalar), $feature_type (scalar)

B<Returns:> Reference to hash

=cut

sub featureResiduesSeqlenLookup {

    my $self = shift;
    
    ## Set the max text size for sequence and protein data fields
    $self->{_backend}->do_set_textsize(TEXTSIZE);
    
    my $ret = $self->{_backend}->getFeatureResiduesSeqlenValues(@_);

    my %lookup = {};

    for (my $i=0; $i < scalar(@{$ret}); $i++){
	
	$lookup{$ret->[$i][0]} = [$ret->[$i][1], $ret->[$i][2], $ret->[$i][3]];
    }

    return \%lookup;
}

=item $obj->cvtermpath_type_id_lookup()

B<Description:> Will populate the cvtermpath_type_id_lookup

B<Parameters:> None

B<Returns:> None

=cut

sub cvtermpath_type_id_lookup {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    $self->{'cvtermpath_type_id_lookup'} = $self->{_backend}->get_cvtermpath_type_id_lookup();
}

=item $obj->check_cvtermpath_type_id_lookup()

B<Description:> For assigning relationship type between two controlled vocabulary terms

B<Parameters:> $cvterm_id (scalar), $cvterm_id (scalar)

B<Returns:> $type_id (scalar)

=cut

sub check_cvtermpath_type_id_lookup {

    my $self = shift;
    my ($subject_id, $object_id) = @_;

    $self->{_logger}->debug("check_cvtermpath_type_id_lookup") if $self->{_logger}->is_debug();

    my $cvtermpath_type_id_lookup;

    if (( exists $self->{'cvtermpath_type_id_lookup'}) && (defined($self->{'cvtermpath_type_id_lookup'}) )) {

	$cvtermpath_type_id_lookup = $self->{'cvtermpath_type_id_lookup'};
    }
    else {
	return undef;
    }

    if (!defined($subject_id)){
	$self->{_logger}->logdie("subject_id was not defined");
    }
    
    if (!defined($object_id)){
	$self->{_logger}->logdie("object_id was not defined");
    }

    my $type_id;

    my $index = $subject_id . '_' . $object_id;

    if (exists $cvtermpath_type_id_lookup->{$index}){
	if (( exists $cvtermpath_type_id_lookup->{$index}->[0]) && (defined($cvtermpath_type_id_lookup->{$index}->[0]))){
	    return $cvtermpath_type_id_lookup->{$index}->[0];
	}
    }

    return undef;
}


=item $obj->asmblIdExist()

B<Description:> For determining whether the asmbl_id exists in the database

B<Parameters:> $asmbl_id (scalar)

B<Returns:> $boolean (scalar)

=cut

sub asmblIdExist {

    my $self = shift;

    my ($asmbl_id) = @_;

    $self->{_logger}->debug("asmblIdExist") if $self->{_logger}->is_debug();

    my $ret = $self->{_backend}->doesAsmblIdExist($asmbl_id);

    if (defined($ret->[0][0])){
	return 1;
    }
    
    return 0;
}

=item $obj->assemblyHaveCDSFeatures()

B<Description:> For determining whether the assembly has any CDS features

B<Parameters:> $asmbl_id (scalar)

B<Returns:> $boolean (scalar)

=cut

sub assemblyHaveCDSFeatures {

    my $self = shift;

    my ($asmbl_id) = @_;

    $self->{_logger}->debug("assemblyHaveCDSFeatures") if $self->{_logger}->is_debug();

    my $ret = $self->{_backend}->doesAssemblyHaveCDSFeatures($asmbl_id);

    if (defined($ret->[0][0])){
	if ($ret->[0][0] > 0){
	    return 1;
	}
    }
   
    return 0;
}

=item $obj->assemblySequence()

B<Description:> For retrieving the assembly.sequence

B<Parameters:> $asmbl_id (scalar)

B<Returns:> $sequence (scalar)

=cut

sub assemblySequence {

    my $self = shift;

    my ($asmbl_id) = @_;

    $self->{_logger}->debug("assemblySequence") if $self->{_logger}->is_debug();

    ## Set the max text size for sequence and protein data fields
    $self->{_backend}->do_set_textsize(TEXTSIZE);

    my $ret = $self->{_backend}->getAssemblySequence($asmbl_id);

    if (defined($ret->[0][0])){
	return $ret->[0][0];
    }
   
    $self->{_logger}->warn("assembly.sequence was not defined for asmbl_id '$asmbl_id'");

    return undef;
}

=item $obj->cdsCoordinates()

B<Description:> For retrieving the CDS feat_name, end5, end3

B<Parameters:> $asmbl_id (scalar)

B<Returns:> Reference to array of references pointing to arrays

=cut

sub cdsCoordinates {

    my $self = shift;

    my ($asmbl_id) = @_;

    $self->{_logger}->debug("cdsCoordinates") if $self->{_logger}->is_debug();
    
    return $self->{_backend}->getCDSCoordinates($asmbl_id);

}

=item $obj->currentCDSValues()

B<Description:> For retrieving the CDS asm_feature.sequence and asm_feature.protein

B<Parameters:> $asmbl_id (scalar)

B<Returns:> Reference to array of references pointing to arrays

=cut

sub currentCDSValues {

    my $self = shift;

    my ($asmbl_id) = @_;

    $self->{_logger}->debug("currentCDSValues") if $self->{_logger}->is_debug();
    
    my $ret = $self->{_backend}->getCurrentCDSValues($asmbl_id);

    my $lookup={};
    
    foreach my $arrayRef ( @{$ret} ){
	push(@{$lookup->{$arrayRef->[0]}}, [$arrayRef->[1], $arrayRef->[2]]);
    }

    return $lookup;
}


=item $obj->clusterAnalysisIdValues()

B<Description:> For retrieving the analysis_id values for any clustering related program

B<Parameters:> None

B<Returns:> $analysis_id (scalar)

=cut

sub clusterAnalysisIdValues {

    my $self = shift;

    $self->{_logger}->debug("clusterAnalysisIdValues") if $self->{_logger}->is_debug();
    
    my $ret = $self->{_backend}->getClusterAnalysisIdValues();

    my $count = scalar(@{$ret});

    if ($count > 0 ){

	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->debug("Found '$count' analysis records of type 'clustering' in the database");
	}

	my $analysis_id_list;
	
	foreach my $arrayRef ( @{$ret} ){
	    $analysis_id_list .= "$arrayRef->[0],";
	}
	
	## Get rid of trailing comma
	chop $analysis_id_list;
	
	return $analysis_id_list;
    }
    else {
	$self->{_logger}->warn("Did not find any analysis records of type 'clustering' in the database");
	return undef;
    }
}

=item $obj->blastAnalysisIdValues()

B<Description:> For retrieving the analysis_id values for any blast related program

B<Parameters:> None

B<Returns:> $analysis_id (scalar)

=cut

sub blastAnalysisIdValues {

    my $self = shift;

    $self->{_logger}->debug("blastAnalysisIdValues") if $self->{_logger}->is_debug();
    
    my $ret = $self->{_backend}->getBlastAnalysisIdValues();

    my $count = scalar(@{$ret});

    if ($count > 0 ){

	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->debug("Found '$count' analysis records of type 'blast' in the database");
	}

	my $analysis_id_list;
	
	foreach my $arrayRef ( @{$ret} ){
	    $analysis_id_list .= "$arrayRef->[0],";
	}
	
	## Get rid of trailing comma
	chop $analysis_id_list;
	
	return $analysis_id_list;
    }
    else {
	$self->{_logger}->warn("Did not find any analysis records of type 'blast' in the database");
	return undef;
    }
}

=item $obj->storeRecordsInCmBlast()

B<Description:> For storing records in the cm_blast table/BCP file

B<Parameters:> $records (reference to array)

B<Returns:> $recctr (scalar)

=cut

sub storeRecordsInCmBlast {

    my ($self, $records) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $recctr = 0;

    foreach my $rec (@{$records}){
	
	my $cm_blast_id = $self->{_backend}->doStoreRecordsInCmBlast(
								     'qfeature_id'    => $rec->[0],
								     'qorganism_id'   => $rec->[1],
								     'hfeature_id'    => $rec->[2],
								     'horganism_id'   => $rec->[3],
								     'per_id'         => $rec->[4],
								     'per_sim'        => $rec->[5],
								     'p_value'        => $rec->[6],
								     'mfeature_id'    => $rec->[7],
								     );
	
	if (!defined($cm_blast_id)){
	    $self->{_logger}->logdie("Could not store record in cm_blast with qfeature_id '$rec->[0]' ".
				     "qorganism_id '$rec->[1]' ".
				     "hfeature_id '$rec->[2]' ".
				     "horganism_id '$rec->[3]' ".
				     "per_id '$rec->[4]' ".
				     "per_sim '$rec->[5]' ".
				     "p_value '$rec->[6]' ".
				     "mfeature_id '$rec->[7]'.  Check the log file.");
	}

	$recctr++;
    }

    return $recctr;
}

=item $obj->blastRecordsForCmBlastByAnalysisId()

B<Description:> For retrieving all blast records to be processed and stored in cm_blast

B<Parameters:> $analysis_id (scalar)

B<Returns:> $cmBlastRecords (reference to array)

=cut

sub blastRecordsForCmBlastByAnalysisId {

    my $self = shift;
    my ($analysis_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }

    my $ret = $self->{_backend}->getBlastRecordsForCmBlastByAnalysisId($analysis_id);
    print STDERR "Retrieved the qorganism data\n";

    ## 0 => query.organism_id
    ## 1 => query.feature_id
    ## 2 => hit.organism_id
    ## 3 => hit.feature_id
    ## 4 => match.feature_id

    my $recordCount = scalar(@{$ret});

    if ($recordCount > 0){

	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->debug("Retrieved '$recordCount' blast records for analysis_id '$analysis_id'");
	}
#	my $lookup = $self->statisticsForCmBlastByAnalysisId($analysis_id, $ret->[5]);

# 	$self->{_logger}->fatal("ret:". Dumper $ret);
# 	$self->{_logger}->fatal("lookup:" . Dumper $lookup);die;

	my $cmBlastRecords = [];

#	my $recCtr=0;

	
	my $lookup = $self->statisticsForCmBlastByAnalysisId($analysis_id);
	print STDERR "Retrieved all scores\n";

#	die"record count '$recordCount'";	
	foreach my $record (@{$ret}){		
 
#	    $recCtr++;

#	    print STDERR "Processing record number '$recCtr' for match feature with feature_id '$record->[4]'\n";

#	    $self->{_logger}->logdie(Dumper $record);

#	    my $lookup = $self->statisticsForCmBlastByAnalysisId($analysis_id, $record->[4]);

#	    $self->{_logger}->fatal("$record->[4]:" . Dumper $lookup);

	    if (!exists $lookup->{$record->[4]}){
		$self->{_logger}->logdie("statistics did not exist for cm_blast record ".
					 "with qfeature_id '$record->[0]' ");
	    }
	    
	    my $p_value = 10000;  ## Arbitrary, large number
	    my $p_ident_sum = 0;
	    my $p_ident_count = 0;
	    my $p_sim_sum = 0;
	    my $p_sim_count = 0;
	    
	    foreach my $statisticsRecord ( @{$lookup->{$record->[4]}} ){
		
		
		$p_ident_sum += $statisticsRecord->[0];
		$p_ident_count++;
		
		$p_sim_sum += $statisticsRecord->[1];
		$p_sim_count++;
		
		if ( $statisticsRecord->[2] < $p_value ) {
		    $p_value = $statisticsRecord->[2];
		}
	    }
	    
	    ## Calculate averages
	    my $per_id = $p_ident_sum / $p_ident_count;
	    
	    my $per_sim = $p_sim_sum / $p_sim_count;
	    
	    push (@{$cmBlastRecords}, [ $record->[0],  ## qfeature_id
					$record->[1],  ## qorganism_id
					$record->[2],  ## hfeature_id
					$record->[3],  ## horganism_id
					$per_id,    ## per_id (the average percent_identity)
					$per_sim,   ## per_sim (the average percent_similarity)
					$p_value,   ## p_value (the minimum p_value)
					$record->[4]   ## mfeature_id
					]);
	}
	
	return $cmBlastRecords;
    }
    else {
	$self->{_logger}->logdie("No blast records were retrieved from the database for analysis_id '$analysis_id'");
    }
}

=item $obj->generateBlastRecordsForCmBlastByAnalysisId1()

B<Description:> Retrieve all blast records and generate records to be stored in cm_blast

B<Parameters:> $analysis_id (scalar)

B<Returns:> $cmBlastCtr (scalar)

=cut

sub generateBlastRecordsForCmBlastByAnalysisId1 {

    my $self = shift;
    my ($analysis_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }

    my $ret = $self->{_backend}->getBlastRecordsForCmBlastByAnalysisId($analysis_id);
    print STDERR "Retrieved the qorganism data\n";

    ## 0 => query.organism_id
    ## 1 => query.feature_id
    ## 2 => hit.organism_id
    ## 3 => hit.feature_id
    ## 4 => match.feature_id

    my $recordCount = scalar(@{$ret});

    if ($recordCount > 0){

	if ($self->{_logger}->is_debug()){
	    $self->{_logger}->debug("Retrieved '$recordCount' blast records for analysis_id '$analysis_id'");
	}
#	my $lookup = $self->statisticsForCmBlastByAnalysisId($analysis_id, $ret->[5]);

# 	$self->{_logger}->fatal("ret:". Dumper $ret);
# 	$self->{_logger}->fatal("lookup:" . Dumper $lookup);die;

	my $cmBlastRecords = [];

	my $recCtr=0;

	
#	my $lookup = $self->statisticsForCmBlastByAnalysisId($analysis_id);
#	print STDERR "Retrieved all scores\n";

#	die"record count '$recordCount'";	
	foreach my $record (@{$ret}){		
 
	    $recCtr++;

#	    print STDERR "Processing record number '$recCtr' for match feature with feature_id '$record->[4]'\n";

#	    $self->{_logger}->logdie(Dumper $record);

	    my $lookup = $self->statisticsForCmBlastByAnalysisId($analysis_id, $record->[4]);

#	    $self->{_logger}->fatal("$record->[4]:" . Dumper $lookup);

	    if (!exists $lookup->{$record->[4]}){
		$self->{_logger}->logdie("statistics did not exist for cm_blast record ".
					 "with qfeature_id '$record->[0]' ");
	    }
	    
	    my $p_value = 10000;  ## Arbitrary, large number
	    my $p_ident_sum = 0;
	    my $p_ident_count = 0;
	    my $p_sim_sum = 0;
	    my $p_sim_count = 0;
	    
	    foreach my $statisticsRecord ( @{$lookup->{$record->[4]}} ){
		
		
		$p_ident_sum += $statisticsRecord->[0];
		$p_ident_count++;
		
		$p_sim_sum += $statisticsRecord->[1];
		$p_sim_count++;
		
		if ( $statisticsRecord->[2] < $p_value ) {
		    $p_value = $statisticsRecord->[2];
		}
	    }
	    
	    ## Calculate averages
	    my $per_id = $p_ident_sum / $p_ident_count;
	    
	    my $per_sim = $p_sim_sum / $p_sim_count;
	    
	    my $cm_blast_id = $self->{_backend}->doStoreRecordsInCmBlast( 'qfeature_id' =>  $record->[0],  ## qfeature_id
									  'qorganism_id' => $record->[1],  ## qorganism_id
									  'hfeature_id' => $record->[2],  ## hfeature_id
									  'horganism_id' => $record->[3],  ## horganism_id
									  'per_id' => $per_id,    ## per_id (the average percent_identity)
									  'per_sim' => $per_sim,   ## per_sim (the average percent_similarity)
									  'p_value' => $p_value,   ## p_value (the minimum p_value)
									  'mfeature_id' => $record->[4]   ## mfeature_id
									  );
	    if (!defined($cm_blast_id)){
		$self->{_logger}->logdie("Could not store record in cm_blast with qfeature_id '$record->[0]' ".
					 "qorganism_id '$record->[1]' ".
					 "hfeature_id '$record->[2]' ".
					 "horganism_id '$record->[3]' ".
					 "per_id '$per_id' ".
					 "per_sim '$per_sim' ".
					 "p_value '$p_value' ".
					 "mfeature_id '$record->[4]'.  Check the log file.");

	    }
	}

	return $recCtr;
    }
    else {
	$self->{_logger}->logdie("No blast records were retrieved from the database for analysis_id '$analysis_id'");
    }
}

=item $obj->generateBlastRecordsForCmBlastByAnalysisId()

B<Description:> Retrieve all blast records and generate records to be stored in cm_blast

B<Parameters:> $analysis_id (scalar)

B<Returns:> $cmBlastCtr (scalar)

=cut

sub generateBlastRecordsForCmBlastByAnalysisId {

    my $self = shift;
    my ($analysis_id, $batchSize) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }

    if (!defined($batchSize)){ 
	$batchSize = 1000;
    }

    my $matchFeatureIdList = $self->matchFeatureIdListForCmBlastByAnalysisId($analysis_id);
    
    my $recordCount = scalar(@{$matchFeatureIdList});
    
    if ($recordCount > 0){
	
	my $batchCreator = new BatchCreator( 'array' => $matchFeatureIdList, 'batchSize' => $batchSize);

	my $batchCtr=0; 
	my $recCtr=0;

	foreach (my ($start,$end) = $batchCreator->nextRange()){
	    
	    $batchCtr++;
		
	    $self->{_logger}->fatal("batchCtr '$batchCtr' start '$start' end '$end'");

	    if ((defined($start)) && (defined($end))){

		my $ret = $self->{_backend}->getBlastRecordsForCmBlastByAnalysisId($analysis_id, $start, $end);
		     
		## 0 => query.organism_id
		## 1 => query.feature_id
		## 2 => hit.organism_id
		## 3 => hit.feature_id
		## 4 => match.feature_id

		my $lookup = $self->statisticsForCmBlastByAnalysisId($analysis_id, $start, $end);

#		$self->{_logger}->fatal("statistics lookup:".Dumper $lookup);

		foreach my $record (@{$ret}){		
		    
		    $recCtr++;

		    if (!exists $lookup->{$record->[4]}){
			$self->{_logger}->logdie("statistics did not exist for cm_blast record ".
						 "with qfeature_id '$record->[0]' ");
		    }
		    
		    my $p_value = 10000;  ## Arbitrary, large number
		    my $p_ident_sum = 0;
		    my $p_ident_count = 0;
		    my $p_sim_sum = 0;
		    my $p_sim_count = 0;
		    
		    foreach my $statisticsRecord ( @{$lookup->{$record->[4]}} ){
			
			$p_ident_sum += $statisticsRecord->[0];
			$p_ident_count++;
			
			$p_sim_sum += $statisticsRecord->[1];
			$p_sim_count++;
			
			if ( $statisticsRecord->[2] < $p_value ) {
			    $p_value = $statisticsRecord->[2];
			}
		    }
		    
		    ## Calculate averages
		    my $per_id = $p_ident_sum / $p_ident_count;
		    
		    my $per_sim = $p_sim_sum / $p_sim_count;
		    
		    my $cm_blast_id = $self->{_backend}->doStoreRecordsInCmBlast( 'qfeature_id' =>  $record->[0],  ## qfeature_id
										  'qorganism_id' => $record->[1],  ## qorganism_id
										  'hfeature_id' => $record->[2],  ## hfeature_id
										  'horganism_id' => $record->[3],  ## horganism_id
										  'per_id' => $per_id,    ## per_id (the average percent_identity)
										  'per_sim' => $per_sim,   ## per_sim (the average percent_similarity)
										  'p_value' => $p_value,   ## p_value (the minimum p_value)
										  'mfeature_id' => $record->[4]   ## mfeature_id
										  );
		    if (!defined($cm_blast_id)){
			$self->{_logger}->logdie("Could not store record in cm_blast with qfeature_id '$record->[0]' ".
						 "qorganism_id '$record->[1]' ".
						 "hfeature_id '$record->[2]' ".
						 "horganism_id '$record->[3]' ".
						 "per_id '$per_id' ".
						 "per_sim '$per_sim' ".
						 "p_value '$p_value' ".
						 "mfeature_id '$record->[4]'.  Check the log file.");
			
		    }
		}
	    }
	}
	$self->{_logger}->fatal("Processed '$batchCtr' batches and '$recCtr' records");
    }
    else {
	$self->{_logger}->logdie("No blast records were retrieved from the database for analysis_id '$analysis_id'");
    }
}

=item $obj->statisticsForCmBlastByAnalysisId()

B<Description:> For retrieving all average percent_identity, average percent_similarity 
and minimum p_value for all match features linked to some blast analysis_id

B<Parameters:> $analysis_id (scalar), $feature_id (scalar)

B<Returns:> $lookup (reference to hash)

=cut

sub statisticsForCmBlastByAnalysisId {

    my $self = shift;
    my ($analysis_id, $start, $end) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }

    my $ret = $self->{_backend}->getStatisticsForCmBlastByAnalysisId($analysis_id, $start, $end);

    my $lookup = {};

    for (my $i=0; $i < scalar(@{$ret}); $i++){

	## 0 => feature.feature_id (for the blast match feature)
	## 1 => analysisfeature.pidentity
	## 2 => featureprop.value (for percent_similarity)
	## 3 => featureprop.value (for p_value)

	push (@{$lookup->{$ret->[$i][0]}}, [$ret->[$i][1], $ret->[$i][2], $ret->[$i][3]]);

    }

    return $lookup;
}

=item $obj->matchFeatureIdListForCmBlastByAnalysisId()

B<Description:> For retrieving list of all match feature_id values linked to some blast analysis_id

B<Parameters:> $analysis_id (scalar)

B<Returns:> $arrayref (reference to array)

=cut

sub matchFeatureIdListForCmBlastByAnalysisId {

    my $self = shift;
    my ($analysis_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }

    my $ret = $self->{_backend}->getMatchFeatureIdValuesForCmBlastByAnalysisId($analysis_id);

    my @array;

    for (my $i=0; $i < scalar(@{$ret}); $i++){
	push (@array, $ret->[$i][0]);
    }

    return \@array;
}


=item $obj->allIsCurrentAssemblyArrayRef()

B<Description:> For retrieving list of assembly identifiers which are current

B<Parameters:> None

B<Returns:> $arrayref (reference to array)

=cut

sub allIsCurrentAssemblyArrayRef {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->getAllIsCurrentAssemblyArrayRef();

    my @array;

    for (my $i=0; $i < scalar(@{$ret}); $i++){
	push (@array, $ret->[$i][0]);
    }

    return \@array;
}

=item $obj->assemblyLookup()

B<Description:> Retrieves all assembly identifiers

B<Parameters:> None

B<Returns:> $assemblyLookup (reference to hash)

=cut

sub assemblyLookup {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->getAllAssemblyIdentifiers();

    my $assemblyLookup={};

    for (my $i=0; $i < scalar(@{$ret}); $i++){
	if (!exists $assemblyLookup->{$ret->[$i][0]}){
	    $assemblyLookup->{$ret->[$i][0]}++;
	}
	else {
	    $self->{_logger}->error("Already processed value '$ret->[$i][0]");
	}
    }

    return $assemblyLookup;
}


=item $obj->assemblyHasNcRNASubFeatures()

B<Description:> Verify whether the specified assembly has ncRNA subfeatures

B<Parameters:> $asmbl_id (scalar)

B<Returns:> $boolean (scalar)

=cut

sub assemblyHasNcRNASubFeatures {

    my $self = shift;
    
    my ($asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }
    
    my $ret = $self->{_backend}->doesAssemblyHaveNcRNASubFeatures($asmbl_id);

    if ((defined($ret->[0][0])) && ($ret->[0][0] > 0)){
	return 1;
    }

    return 0;
}

=item $obj->ncRNASequenceLookupByAsmblId()

B<Description:> Retrieves all sequences for the ncRNA features that 
are associated with the specified assembly

B<Parameters:> $asmbl_id (scalar)

B<Returns:> $ncRNALookup (reference to hash)

=cut

sub ncRNASequenceLookupByAsmblId {

    my $self = shift;
    
    my ($asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }
    
    my $ret = $self->{_backend}->getNcRNASequencesByAsmblId($asmbl_id);

    my $ncRNALookup={};

    for (my $i=0; $i < scalar(@{$ret}); $i++){
	$ncRNALookup->{$ret->[$i][0]} = $ret->[$i][1];
    }

    return $ncRNALookup;

}


## end of usefulness

=item $obj->asmblIdArrayRefWithIsCurrentAndHasNcRNAFeature()

B<Description:> For retrieving list of assembly identifiers which are current and have some associated ncRNA sub-features

B<Parameters:> None

B<Returns:> $arrayref (reference to array)

=cut

sub asmblIdArrayRefWithIsCurrentAndHasNcRNAFeature {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->getAsmblIdWithIsCurrentAndHasNcRNAFeature();

    my @array;

    for (my $i=0; $i < scalar(@{$ret}); $i++){
	push (@array, $ret->[$i][0]);
    }

    return \@array;
}

=item $obj->existsAssemblyWithIdentifierAndNcRNAFeatures()

B<Description:> Verify whether the assembly with specified identifier exists and whether has associated ncRNA sub-features

B<Parameters:> $asmbl_id (scalar)

B<Returns:> $boolean (scalar)

=cut

sub existsAssemblyWithIdentifierAndNcRNAFeatures {

    my $self = shift;
    
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    

    my $asmblIdLookup = $self->currentAssemblyWithNcRNASubFeatures();


    my $ret = $self->{_backend}->doesExistAssemblyWithIdentifierAndNcRNAFeatures(@_);

    
    my @array;

    for (my $i=0; $i < scalar(@{$ret}); $i++){
	push (@array, $ret->[$i][0]);
    }

    return \@array;
}

=item $obj->genusAndSpeciesByUniquename()

B<Description:> Retrieve the genus and species for the sequence given the feature.uniquename

B<Parameters:> $id (scalar)

B<Returns:> $genus (scalar), $species (scalar)

=cut

sub genusAndSpeciesByUniquename {

    my $self = shift;
    my ($id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    my $ret = $self->{_backend}->getGenusAndSpeciesByUniquename($id);

    my $genus;
    my $species;

    if (defined($ret->[0])){
	$genus = $ret->[0][0];
	$species = $ret->[0][1];
    }

    if (!defined($genus)){
	$self->{_logger}->warn("genus was not defined from feature.uniquename '$id'");
    }

    if (!defined($species)){
	$self->{_logger}->warn("species was not defined from feature.uniquename '$id'");
    }

    return ($genus, $species);
}

=item $obj->featurePropertiesByUniquename()

B<Description:> Retrieve array of cvterm.name and featureprop.value given the feature.uniquename

B<Parameters:> $id (scalar)

B<Returns:> Reference to array

=cut

sub featurePropertiesByUniquename {

    my ($self, $uniquename) = @_;

    ## 0 => cvterm.name
    ## 1 => featureprop.value WHERE featureprop.type_id = cvterm.cvterm_id AND featureprop.unquename = $uniquename

    return $self->{_backend}->getFeaturePropertiesByUniquename($uniquename);
}

=item $obj->listOfReferenceSequencesByType(type=>$type, listref=>$listref)

B<Description:> Retrieve all feature.uniquename values for all of the reference sequence types specified
by $type (comma-separated list) and store them in array ($listref).  This method supports the
create_chado2bsml_iterator_list.pl program.

B<Parameters:> 

$type (scalar - string) comma-separated list of sequence types
$listref (reference to array) array in which to push the retrieved values

B<Returns:> None

=cut

sub listOfReferenceSequencesByType {

    my $self = shift;
    my (%args) = @_;

    my $type;
    if ((exists $args{'type'}) && (defined($args{'type'}))){
	my @seqtypes = split(/,/, $type);
	foreach my $seqtype ( @seqtypes ){
	    $type .= "'" . $seqtype . "',";
	}
	chop $type; ## remove trailing comma
    } else {
	$type = "'assembly'";
	$self->{_logger}->warn("type was not defined and therefore was set to 'assembly'");
    }

    if (!exists $args{'listref'}){
	$self->{_logger}->logdie("listref was not defined");
    }
    
    my $listref = $args{'listref'};

    my $ret = $self->{_backend}->getListOfReferenceSequencesByType($type);
    if (!defined($ret)){
	$self->{_logger}->logdie("ret was not defined");
    }

    my $ctr=0;
    foreach my $array (@{$ret}){
	push(@{$listref}, $array->[0]);
	$ctr++;
    }

    $self->{_logger}->info("Loaded '$ctr' values onto array");
}


=item $obj->retrieveModelCollectionByAssemblyIdentifier(id=>$id)

B<Description:> Retrieve all model features for the specified assembly identifier

B<Parameters:> $id (scalar - string)

B<Returns:> $modelCollection (reference to Annotation::Features::ModelCollection)

=cut

sub retrieveModelCollectionByAssemblyIdentifier {

    my $self = shift;
    my (%args) = @_;

    if (! exists $args{'id'}){
	$self->{_logger}->logdie("id was not defined");
    }

    my $id = $args{'id'};
    
    my $records = $self->{_backend}->getModelCoordinatesByAssemblyIdentifier(id=>$id);

    if (!defined($records)){
	$self->{_logger}->logdie("Could not retrieve records from ".
				 "getModelCoordinatesByAssemblyIdentifier ".
				 "for id '$id'");
    }

    my $recordCtr=0;


    my $collection = new Annotation::Features::FeatureCollection();

    if (!defined($collection)){
	$self->{_logger}->logdie("Could not instantiate Annotation::".
				 "Features::FeatureCollection object ".
				 "while processing assembly with id '$id'");
    }

    foreach my $record (  @{$records } ){

	$collection->createAndAddFeature(id=>$record->[0],
					 class=>'model',
					 fmin=>$record->[1],
					 fmax=>$record->[2],
					 parent=>$record->[3]);
	$recordCtr++;
    }

    print "Added '$recordCtr' model features to the collection\n";

    return $collection;
}


=item $obj->retrieveCDSCollectionByAssemblyIdentifier(id=>$id)

B<Description:> Retrieve all CDS features for the specified assembly identifier

B<Parameters:> $id (scalar - string)

B<Returns:> $cdsCollection (reference to Annotation::Features::FeatureCollection)

=cut

sub retrieveCDSCollectionByAssemblyIdentifier {

    my $self = shift;
    my (%args) = @_;

    if (! exists $args{'id'}){
	$self->{_logger}->logdie("id was not defined");
    }

    my $id = $args{'id'};
    
    my $records = $self->{_backend}->getCDSCoordinatesByAssemblyIdentifier(id=>$id);

    if (!defined($records)){
	$self->{_logger}->logdie("Could not retrieve records from ".
				 "getCDSCoordinatesByAssemblyIdentifier ".
				 "for id '$id'");
    }

    my $recordCtr=0;


    my $collection = new Annotation::Features::FeatureCollection();

    if (!defined($collection)){
	$self->{_logger}->logdie("Could not instantiate Annotation::".
				 "Features::FeatureCollection object ".
				 "while processing assembly with id '$id'");
    }

    foreach my $record (  @{$records } ){

	$collection->createAndAddFeature(id=>$record->[1],
					 class=>'cds',
					 fmin=>$record->[2],
					 fmax=>$record->[3],
					 parent=>$record->[0]);
	$recordCtr++;
    }


    print "Added '$recordCtr' model features to the collection\n";

    return $collection;
}

sub modelSequences {
    
    my ($self, $asmbl_id, $db) = @_;
    
    return $self->{_backend}->getModelSequences($asmbl_id, $db);

}

sub getEpitopeFeatureCollection {
    
    my $self = shift;
    my ($asmbl_id, $db) = @_;
    
    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    if (!defined($db)){
	$self->{_logger}->logdie("db was not defined");
    }

    my $asmFeatureRecords = $self->{_backend}->getEpitopeAsmFeatureRecords($asmbl_id, $db);

    if (!defined($asmFeatureRecords)){
	$self->{_logger}->logdie("asmFeatureRecords was not defined for asmbl_id ".
				 "'$asmbl_id' db '$db'");
    }

    my $identRecords = $self->{_backend}->getEpitopeIdentRecords($asmbl_id, $db);

    if (!defined($identRecords)){
	$self->{_logger}->logdie("identRecords was not defined for asmbl_id ".
				 "'$asmbl_id' db '$db'");
    }

    my $evidenceRecords = $self->{_backend}->getEpitopeEvidenceRecords($asmbl_id, $db);

    if (!defined($evidenceRecords)){
	$self->{_logger}->logdie("evidenceRecords was not defined for asmbl_id ".
				 "'$asmbl_id' db '$db'");
    }

    my $scoreRecords = $self->{_backend}->getEpitopeScoreRecords($asmbl_id, $db);

    if (!defined($scoreRecords)){
	$self->{_logger}->logdie("scoreRecords was not defined for asmbl_id ".
				 "'$asmbl_id' db '$db'");
    }

    my $accessionRecords = $self->{_backend}->getEpitopeAccessionRecords($asmbl_id, $db);

    if (!defined($accessionRecords)){
	$self->{_logger}->logdie("accessionRecords was not defined for asmbl_id ".
				 "'$asmbl_id' db '$db'");
    }

    my $proteinUtil = new ProteinDBUtil(asmbl_id=>$asmbl_id,
                                        db=>$db,
                                        prism=>$self);
    if (!defined($proteinUtil)){
        $self->{_logger}->logdie("Could not instantiate ProteinDBUtil");
    }

    my $eutil = new EpitopeDBUtil(refseq=>$asmbl_id,
                                  asm_feature=>$asmFeatureRecords,
                                  ident=>$identRecords,
                                  evidence=>$evidenceRecords,
                                  accession=>$accessionRecords,
                                  score=>$scoreRecords,
                                  protein_util=>$proteinUtil);
    
    if (!defined($eutil)){
	$self->{_logger}->logdie("Could not instantiate EpitopeDBUtil");
    }

    return $eutil->getCollection();

}

sub virulenceFactors {

    my ($self, $asmbl_id, $db, $feat_type) = @_;
    
    return $self->{_backend}->getVirulenceFactors($asmbl_id, $db, $feat_type);
}

sub uniquenameToFeatureIdLookup {

    my $self = shift;

    my $ret = $self->{_backend}->getUniquenameToFeatureIdLookup(@_);

    if (!defined($ret)){
	$self->{_logger}->logdie("ret was not defined");
    }

    my $lookup={};

    foreach my $rec (@{$ret}){

	if (!exists $lookup->{$rec->[0]}){
	    $lookup->{$rec->[0]} = $rec->[1];
	} else {
	    $self->{_logger}->warn("Already encountered uniquename ".
				   "'$rec->[0]'");
	}
    }

    return $lookup;
}


sub reportTableRecordCounts {

    my $self = shift;
    my ($outfile) = @_;

    ## This will invoke the Coati::BulkHelper::write_table_record_counts_file method.
    $self->{_backend}->write_table_record_counts_file($outfile);
}


sub existsGeneModels {

    ## This will eventually will be moved into Prism::ChadoMart::Helper
    ## These checks could be improved with appropriate joins on 
    ## feature_relationship.

    my $self = shift;

    my $retval = 0;

    my $geneCountRet = $self->{_backend}->getGeneCounts();

    if (!defined($geneCountRet)){
	$self->{_logger}->logdie("geneCountRet was not defined");
    }

    if ($geneCountRet->[0][0] > 0){
	$retval = 1;
    } else {
	$self->{_logger}->warn("No genes");
    }

    my $transcriptCountRet = $self->{_backend}->getTranscriptCounts();
	
    if (!defined($transcriptCountRet)){
	$self->{_logger}->logdie("transcriptCountRet was not defined");
    }
    
    if ($transcriptCountRet->[0][0] > 0){
	$retval=1;
    } else {
	$self->{_logger}->warn("No transcripts");
    }

    my $cdsCountRet = $self->{_backend}->getCDSCounts();
	
    if (!defined($cdsCountRet)){
	$self->{_logger}->logdie("cdsCountRet was not defined");
    }
	    
    if ($cdsCountRet->[0][0] > 0){
	$retval = 1;
    } else {
	$self->{_logger}->warn("No CDS");
    }

    my $exonCountRet = $self->{_backend}->getExonCounts();
	
    if (!defined($exonCountRet)){
	$self->{_logger}->logdie("exonCountRet was not defined");
    }
	    
    if ($exonCountRet->[0][0] > 0){
	$retval = 1;
    } else {
	$self->{_logger}->warn("No exons");
    }

    return $retval;
}

sub _uniqueDbxrefRecordsForCmProteins {

    ## This will eventually will be moved into Prism::ChadoMart::Helper

    my $self = shift;
    my $records = $self->{_backend}->getDbxrefRecordsForCmProteins2();
    if (!defined($records)){
	$self->{_logger}->logdie("records was not defined");
    }

    ## Will deal with non-unique records on the client-side.

    my $recCtr=0;
    my $uniq={};
    my $retRecords;
    my $uniqRecCtr=0;

    print "Resolving unique protein dbxref records now\n";

    foreach my $record (@{$records}){

	$recCtr++;

	if (! exists $uniq->{$record->[0]}->{$record->[1]}->{$record->[2]}){
	    push(@{$retRecords}, $record);
	    $uniq->{$record->[0]}->{$record->[1]}->{$record->[2]}++;
	    $uniqRecCtr++;
	}
    }

    print "Found '$uniqRecCtr' unique protein dbxref records\n";

    return $retRecords;

}



sub hasFeatures {

    my $self = shift;
    my ($featureType) = @_;

    if (!defined($featureType)){
	$self->{_logger}->logdie("featureType was not defined");
    }

    my $ret = $self->{_backend}->getFeatureCountByFeatureType($featureType);
    if (!defined($ret)){
	$self->{_logger}->logdie("ret was not defined");
    }

    my $count = scalar(@{$ret});
    if ($count > 0) {
	return 1;
    }
    
    return 0;
}

sub featureDataList {

    my $self = shift;

    return $self->{_backend}->getPolypeptideData();
}

sub cvterm_id_from_so {
    my $self = shift;
    my ($type) = @_;
    if (!defined($type)){
	$self->{_logger}->logdie("type was not defined");
    }

    my $ret = $self->{_backend}->get_cvterm_id_from_so($type);
    if (!defined($ret)){
	$self->{_logger}->logdie("ret was not defined");
    }

    return $ret->[0][0];
    
}


sub epitopeAndPolypeptideRelationship {
    
    my $self = shift;
    return $self->{_backend}->getEpitopeAndPolypeptideRelationship();
}

sub epitopeFeatureIdLookup {

    my $self = shift;

    my $records = $self->{_backend}->getEpitopeFeatureIds();

    if (!defined($records)){
	$self->{_logger}->logdie("Could not retrieve records");
    }

    my $recCtr=0;
    my $lookup={};

    foreach my $record (@{$records}){
	$lookup->{$record->[0]} = $record->[1];
	$recCtr++;
    }

    print "Added '$recCtr' records to the epitope feature_id lookup\n";

    return $lookup;
    
}

sub polypeptideFeatureIdLookup {

    my $self = shift;

    my $records = $self->{_backend}->getPolypeptideFeatureIds();

    if (!defined($records)){
	$self->{_logger}->logdie("Could not retrieve records");
    }

    my $recCtr=0;
    my $lookup={};

    foreach my $record (@{$records}){
	$lookup->{$record->[0]} = $record->[1];
	$recCtr++;
    }

    print "Added '$recCtr' records to the polypeptide feature_id lookup\n";

    return $lookup;
    
}

sub epitopeCVLookup {

    my $self = shift;
    my $records = $self->{_backend}->getEpitopeCVRecords();
    if (!defined($records)){
	$self->{_logger}->logdie("Could not retrieve epitope CV records");
    }

    my $recCtr=0;
    my $lookup={};

    foreach my $record (@{$records}){
	$lookup->{$record->[0]} = $record->[1];
	$recCtr++;
    }

    print "Added '$recCtr' records to the epitope CV lookup\n";

    return $lookup;

}


sub loadFeatNameToSpeciesLookup {

    my $self = shift;

    my ($lookup) = @_;

    my $ret = $self->{_backend}->getFeatNameSpeciesRecordsFromIdent();
    if (!defined($ret)){
	$self->{_logger}->logdie("ret was not defined");
    }

    foreach my $record ( @{$ret} ){
	$lookup->{$record->[0]} = $record->[1];
    }
}

sub loadNtGeneProductNameLookup {

    my $self = shift;

    my ($lookup) = @_;

    my $ret = $self->{_backend}->getFeatNameComNameRecordsFromNtIdent();
    if (!defined($ret)){
	$self->{_logger}->logdie("ret was not defined");
    }

    foreach my $record ( @{$ret} ){
	$lookup->{$record->[0]} = $record->[1];
    }
}

sub proteinSequences {

    my $self = shift;
    ## Set the max text size for sequence and protein data fields
    $self->{_backend}->do_set_textsize(TEXTSIZE);
    print "Will retrieve all protein sequences\n";
    return $self->{_backend}->getProteinSequences();
}

sub proteinSequence {

    my $self = shift;

    return $self->{_backend}->getProteinSequence(@_);
}


sub proteinIdentifiersByClusterAnalysisId {
    
    my $self = shift;
    return $self->{_backend}->getProteinIdentifiersByClusterAnalysisId(@_);
}

sub proteinLengthsByClusterAnalysisId {
    
    my $self = shift;
    return $self->{_backend}->getProteinLengthByClusterAnalysisId(@_);
}

1; ## End of module

__END__

=back

=head1 ENVIRONMENT

This module checks for a PRISM environment variable to determine what relational database
type to use, which database server to connect to, and what schema type we are using.
If the variable is not set, then the module will parse the Prism.conf configuration
file to set it and will also set additional environment variables that are configured there.

=head1 DIAGNOSTICS

=over 4

=item "Error message that may appear."

Explanation of error message.

=item "Another message that may appear."

Explanation of another error message.

=back

=head1 BUGS

Description of known bugs (and any workarounds). Usually also includes an
invitation to send the author(s) bug reports.

=head1 SEE ALSO

Prism.conf - Configuration file with parameters containing which RDBMS to use,
which server it is running on, and what schema (Euk, Prok, etc...) type we need.
This file also contains other environment variables that may need to be set.

List of any other files or Perl modules needed by class and a
brief description why.

=head1 AUTHOR(S)

 The Institute for Genomic Research
 9712 Medical Center Drive
 Rockville, MD 20850

=head1 COPYRIGHT

Copyright (c) 2002, The Institute for Genomic Research. All Rights Reserved.

``
