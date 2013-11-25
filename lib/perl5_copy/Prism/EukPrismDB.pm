package Prism::EukPrismDB;

use strict;
use base qw(Prism::PrismDB);
use Data::Dumper;


## The ORF_attribute.att_type for the parafam analysis
my $TEMPFAM = 'TEMPFAM';


sub test_EukPrismDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_PrismDB();
}

sub testProjDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_EukPrismDB();

}

#-----------------------------------------------------------------------------
# get_all_assembly_records()
#
#-----------------------------------------------------------------------------
sub get_all_assembly_records { 

    my ($self, $asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;    

    $self->{_logger}->debug("asmbl_id '$asmbl_id' was specified") if $self->{_logger}->is_debug;

    
    #
    # editor:   sundaram@tigr.org
    # date:     2005-08-31
    # bgzcase:  2087
    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2087
    # comment:  All clone_info columns' values should be stored as <Attribute> objects under the assembly's <Sequence> object.
    #
    
    my $query = "SELECT a.asmbl_id, a.sequence, c.clone_name, c.seq_group, c.chromo, c.gb_acc, c.is_public, a.ed_date, null, null, c.clone_id, c.orig_annotation, c.tigr_annotation, c.status, c.length, c.final_asmbl, c.fa_left, c.fa_right, c.fa_orient, c.gb_desc, c.gb_comment, c.gb_date, c.comment, c.assignby, c.date, c.lib_id, c.seq_asmbl_id, c.date_for_release, c.date_released, c.authors1, c.authors2, c.seq_db, c.gb_keywords, c.sequencing_type, c.prelim, c.license, c.gb_phase, c.gb_gi ".
    "FROM assembly a, clone_info c ".
    "WHERE a.asmbl_id = c.asmbl_id ";
    
    
    if (defined($asmbl_id)){

	$query .= "AND a.asmbl_id = $asmbl_id ";
	
	print "Retrieving euk records from assembly, clone_info for asmbl_id '$asmbl_id'\n";
 
    }
    else{

	print "Retrieving all qualifying euk records from assembly, clone_info\n";

    }


   return $self->_get_results($query);

}

#-----------------------------------------------------------------------------
# get_transcripts 
#
#-----------------------------------------------------------------------------
sub get_transcripts { 

    my ($self, $asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;


    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));

    #
    # author:  sundaram@tigr.org
    # date:    2005-08-01
    # bgzcase: 2012
    # comment: Some TUs are categorized as pseudogenes.  This information needs to be
    #          correctly propagated in the BSML gene model documents and then the
    #          chado comparative databases.
    #

    #
    # author:   sundaram@tigr.org
    # date:     2005-08-10
    # bgzcase:  2039
    # comment:  Need to retrieve the alt_locus and pub_locus associated to the TU
    #

    #
    # editor:   sundaram@tigr.org
    # date:     2005-09-09
    # bgzcase:  2107
    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2107
    # comment:  Support for retrieving gene finder data - eliminate the phys_ev.ev_type = 'working' clause
    #

    #
    # editor:   sundaram@tigr.org
    # date:     2005-11-22
    # bgzcase:  2292
    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2292
    # comment:  Support for retrieving TU asm_feature.curated
    #

    my $query = "SELECT f.feat_name,f.asmbl_id,f.end5,f.end3,f.sequence,i.locus,i.com_name,f.date, i.is_pseudogene, i.alt_locus, i.pub_locus, f.curated ".
    "FROM asm_feature f, asm_feature f2, feat_link l, phys_ev p, ident i ".
    "WHERE f.feat_type = 'TU' ".
    "AND l.parent_feat = f.feat_name ".
    "AND i.feat_name = f.feat_name ".
    "AND f2.feat_name = l.child_feat ".
    "AND f2.feat_name = p.feat_name ".
    "AND p.ev_type = 'working' ".
    "AND f2.feat_type = 'model' ".
    "AND f.asmbl_id = ?";

    return $self->_get_results($query, $asmbl_id);
}   

#-----------------------------------------------------------------------------
# get_coding_regions
#
#-----------------------------------------------------------------------------
sub get_coding_regions {

    my($self, $asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));
    
    #
    # editor:   sundaram@tigr.org
    # date:     2005-11-22
    # bgzcase:  2292
    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2292
    # comment:  Support for retrieving model asm_feature.curated
    #

    my $query = "SELECT f.feat_name,f2.feat_name,f.end5,f.end3,f.sequence,f.protein,f.date, f.curated ".
    "FROM asm_feature f, asm_feature f2, feat_link l, phys_ev p ".
    "WHERE f.feat_name = l.child_feat ".
    "AND f2.feat_name = l.parent_feat ".
    "AND f2.feat_type = 'TU' ".
    "AND f.feat_type = 'model' ".
    "AND f.feat_name = p.feat_name ".
    "AND p.ev_type = 'working' ".
    "AND f.asmbl_id = ?";
    
    return $self->_get_results($query, $asmbl_id);

}   

#-----------------------------------------------------------------------------
# get_table_record_count
#
#-----------------------------------------------------------------------------
sub get_table_record_count {

    my ($self,$table) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("table was not defined") if (!defined($table));

    my $query = "SELECT count(*) ".
	"FROM ?";

    return $self->_get_results($query, $$table);

}

#-----------------------------------------------------------------------------
# get_exons
#
#-----------------------------------------------------------------------------
sub get_exons {

    my($self, $asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));


    my $query = "SELECT f.feat_name,f2.feat_name,f.end5,f.end3,f.date ".
	"FROM asm_feature f, asm_feature f2, feat_link l, phys_ev p ".
	"WHERE f.feat_name = l.child_feat ".
	"AND f2.feat_name = l.parent_feat ".
	"AND f2.feat_type = 'model' ".
	"AND f.feat_type = 'exon' ".
	"AND p.feat_name = f2.feat_name ".
	"AND p.ev_type = 'working' ".
	"AND f.asmbl_id = ?".
	"ORDER BY f.end5";

    return $self->_get_results($query, $asmbl_id);

}   


#-----------------------------------------------------------------------------
# get_common_genomes_data 
#
#-----------------------------------------------------------------------------
sub get_common_genomes_data {  

    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));
    
    my $query = "SELECT file_moniker, name ".
	"FROM common..genomes ".
	"WHERE db = ? ";

    return $self->_get_results($query, $db);

}


#-----------------------------------------------------------------------------
# get_new_project_data 
#
#-----------------------------------------------------------------------------
sub get_new_project_data {  

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT taxon_id, gram_stain, genetic_code ".
    "FROM new_project ";

    return $self->_get_results($query);

}


#-----------------------------------------------------------------------------
# get_organism_count
#
#-----------------------------------------------------------------------------
sub get_organism_count {  

    my ($self, $organism_database) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("organism_database was not defined") if (!defined($organism_database));

    my $query = "SELECT count(*) ".
	"FROM common..genomes cg, new_project np ".
	"WHERE cg.db = ? ";

    return $self->_get_results($query, $organism_database);
}


#-----------------------------------------------------------------------------
# get_max_table_id()
#
#-----------------------------------------------------------------------------
sub get_max_table_id {

    my ($self,$table, $id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    $self->{_logger}->logdie("table was not defined") if (!defined($table));
    $self->{_logger}->logdie("id was not defined")    if (!defined($id));
	
    my $query = "SELECT max(?) ".
	"FROM ?";

    return $self->_get_results($query, $$id, $$table);

}

#-----------------------------------------------------------------------------
# get_protein_2_contig_localization()
#
#-----------------------------------------------------------------------------
sub get_protein_2_contig_localization {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT p.feature_id,a.feature_id,fl.nbeg,fl.is_nbeg_partial,fl.nend,fl.is_nend_partial,fl.strand,fl.phase,fl.residue_info,fl.locgroup,fl.rank ".
	"FROM feature c, feature a, feature p, feature_relationship fp, featureloc fl ".
	"WHERE fp.subjfeature_id = p.feature_id  ".
	"AND fp.objfeature_id = c.feature_id ".
	"AND fp.type_id = 24 ".
	"AND c.feature_id = fl.feature_id ".
	"AND a.feature_id = fl.srcfeature_id ".
	"AND a.type_id = 5 ".
	"AND p.type_id = 16 ".
	"AND c.type_id = 55 ";

    return $self->_get_results($query);

}

#-----------------------------------------------------------------------------
# get_euk_sequence_info
#
#-----------------------------------------------------------------------------
sub get_euk_sequence_info { 

    my ($self, $asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;    

    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));

    my $query;

    if (defined($asmbl_id)){

	$query = "SELECT a.sequence ".
	"FROM assembly a, clone_info c ".
	"WHERE a.asmbl_id = c.asmbl_id ".
	"AND a.asmbl_id = $asmbl_id ";

    }
    else {
	
	#
	# editor:  sundaram@tigr.org
	# date:    2005-09-08
	# bgz:     2106
	# URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2106
     	# comment: If asmbl_id is not specified, then the only data retrieved is 
	#          qualified with the following clause clone_info.is_public = 1
	#
	$query = "SELECT a.sequence ".
	"FROM assembly a, clone_info c ".
	"WHERE a.asmbl_id = c.asmbl_id ".
	"AND c.is_public = 1 ";
	
    }


    return $self->_get_results($query);

}



#-----------------------------------------------------------------------------
# get_tu_sequence_info
#
#-----------------------------------------------------------------------------
sub get_tu_sequence_info { 

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;    

    my $query = "SELECT f.feat_name, f.sequence ".
    "FROM asm_feature f, asm_feature f2, feat_link l, phys_ev p, ident i ".
    "WHERE f.feat_type = 'TU' ".
    "AND l.parent_feat = f.feat_name ".
    "AND i.feat_name = f.feat_name ".
    "AND f2.feat_name = l.child_feat ".
    "AND f2.feat_name = p.feat_name ".
    "AND f2.feat_type = 'model' ".
    "AND p.ev_type = 'working' ";
#    "AND f.asmbl_id = ? ".
#    "AND f.feat_name = ? ";

 #   return $self->_get_results($query, $asmbl_id, $feat_name);
   return $self->_get_results($query);

}




#-----------------------------------------------------------------------------
# get_pub_locus_hash()
#
#-----------------------------------------------------------------------------
sub get_pub_locus_hash {

    my ($self, $asmbl_id) = @_;

   $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;


    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));

    
    my $query;

    if (defined($asmbl_id)){ 
	
	$query = "SELECT i.feat_name, i.pub_locus ".
	"FROM assembly a, asm_feature f, ident i ".
	"WHERE a.asmbl_id = f.asmbl_id ".
	"AND f.feat_name = i.feat_name ".
	"AND a.asmbl_id = $asmbl_id ";
    }
    else {

	#
	# editor:  sundaram@tigr.org
	# date:    2005-09-08
	# bgz:     2106
	# URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2106
     	# comment: If asmbl_id is not specified, then the only data retrieved is 
	#          qualified with the following clause clone_info.is_public = 1
	#
	$query = "SELECT i.feat_name, i.pub_locus ".
	"FROM assembly a, asm_feature f, clone_info c, ident i ".
	"WHERE a.asmbl_id = c.asmbl_id ".
	"AND a.asmbl_id = f.asmbl_id ".
	"AND f.feat_name = i.feat_name ".
	"AND c.is_public = 1 ";
    }

    return $self->_get_results($query);
}




#----------------------------------------------------------------------------------------------
# get_sequence_features()
#
#
#----------------------------------------------------------------------------------------------
sub get_sequence_features {

    my($self, $asmbl_id, $db, $feat_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;


    $self->{_logger}->logdie("db was not defined") if (!defined($db));
    $self->{_logger}->logdie("feat_type was not defined") if (!defined($feat_type));



    print "Retrieving all sequence types for database '$db' assembly '$asmbl_id' feat_type '$feat_type'\n";# if $self->{_logger}->is_debug;
 
    my $query;


    if (defined($asmbl_id)){

	$query = "SELECT f.asmbl_id, f.feat_name, f.feat_type, f.sequence, f.protein " .
	"FROM $db..assembly a, $db..asm_feature f " .
	"WHERE a.asmbl_id = f.asmbl_id ".
	"AND f.feat_type = '$feat_type' ".
	"AND a.asmbl_id = $asmbl_id ";
    
    }
    else {

	#
	# editor:  sundaram@tigr.org
	# date:    2005-09-08
	# bgz:     2106
	# URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2106
     	# comment: If asmbl_id is not specified, then the only data retrieved is 
	#          qualified with the following clause clone_info.is_public = 1
	#
	$query = "SELECT f.asmbl_id, f.feat_name, f.feat_type, f.sequence, f.protein " .
	"FROM $db..assembly a, $db..asm_feature f, $db..clone_info c " .
	"WHERE a.asmbl_id = f.asmbl_id ".
	"AND f.feat_type = '$feat_type' ".
	"AND c.is_public = 1 ";
    }


    $query .= "ORDER BY f.asmbl_id";

    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;

    return $self->_get_results_ref($query);
}


#----------------------------------------------------------------------------------------------
# get_accession_data()
#
#----------------------------------------------------------------------------------------------
sub get_accession_data {

    return;
}


#----------------------------------------------------------------------------------------------
# get_rna_data()
#
#----------------------------------------------------------------------------------------------
sub get_rna_data {

    return;
}

#----------------------------------------------
# getRnaDataByAsmblId()
#
#----------------------------------------------
sub getRnaDataByAsmblId {

    my ($self, $asmbl_id, $db, $schemaType) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    if (!defined($db)){
	$self->{_logger}->logdie("db was not defined");
    }


    my $query = "SELECT f.feat_name, f.end5, f.end3, f.feat_type, i.com_name, i.gene_sym, i.pub_comment, i.locus, f.sequence ".
    "FROM $db..asm_feature f, $db..assembly a, $db..ident i ".
    "WHERE a.asmbl_id = $asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = i.feat_name ".
    "AND (f.feat_type = 'rRNA' ".
    "OR f.feat_type = 'sRNA' ".
    "OR f.feat_type = 'ncRNA' ".
    "OR f.feat_type = 'tRNA' ) ".
    "ORDER BY f.asmbl_id";
    
    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }

    print "Retrieving all RNA features from database '$db'\n";

    return $self->_get_results_ref($query);
}


#----------------------------------------------------------------------------------------------
# get_trna_scores()
#
#----------------------------------------------------------------------------------------------
sub get_trna_scores {

    return;
}

#----------------------------------------------------------------------------------------------
# getTrnaScores()
#
#----------------------------------------------------------------------------------------------
sub getTrnaScores {

    return undef;
}

#----------------------------------------------------------------------------------------------
# get_peptide_data()
#
#----------------------------------------------------------------------------------------------
sub get_peptide_data {

    return;
}


#----------------------------------------------------------------------------------------------
# get_ribosomal_data()
#
#----------------------------------------------------------------------------------------------
sub get_ribosomal_data {

    return;
}


#----------------------------------------------------------------------------------------------
# get_terminator_data()
#
#----------------------------------------------------------------------------------------------
sub get_terminator_data {

    return;
}


#----------------------------------------------------------------------------------------------
# get_term_direction_data()
#
#----------------------------------------------------------------------------------------------
sub get_term_direction_data {

    return;
}


#----------------------------------------------------------------------------------------------
# get_term_confidence_data()
#
#----------------------------------------------------------------------------------------------
sub get_term_confidence_data {

    return;
}

 
#----------------------------------------------------------------------------------------------
# get_terminator_to_gene_data()
#
#----------------------------------------------------------------------------------------------
sub get_terminator_to_gene_data {

    return;
}

#----------------------------------------------------------------------------------------------
# get_rbs_to_gene_data()
#
#----------------------------------------------------------------------------------------------
sub get_rbs_to_gene_data {

    return;
}

#----------------------------------------------------------------------------------------------
# get_gene_annotation_ident_attribute_data()
#
#----------------------------------------------------------------------------------------------
sub get_gene_annotation_ident_attribute_data {

    my ($self, $asmbl_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    $self->{_logger}->logdie("db was not defined") if (!defined($db));
    
    print "Retrieving all TU ident data\n";

    my $query;

    if (defined($asmbl_id)) {
	
	$query = "SELECT f.asmbl_id, i.feat_name, i.com_name, i.assignby, i.date, i.comment, null, i.auto_comment, i.gene_sym, null, null, null, i.ec#, null, i.is_pseudogene, i.pub_comment ".
	"FROM $db..assembly a, $db..asm_feature f, $db..ident i ".
	"WHERE a.asmbl_id = f.asmbl_id ".
	"AND f.feat_name = i.feat_name ".
	"AND f.feat_type = 'TU' ".
	"AND f.asmbl_id = $asmbl_id ";

    }
    else {

	#
	# editor:  sundaram@tigr.org
	# date:    2005-09-08
	# bgz:     2106
	# URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2106
     	# comment: If asmbl_id is not specified, then the only data retrieved is 
	#          qualified with the following clause clone_info.is_public = 1
	#
	
	## column numbers:   0            1            2           3        4         5      6       7              8        9   10  11  12     13   14
	$query = "SELECT f.asmbl_id, i.feat_name, i.com_name, i.assignby, i.date, i.comment, '', i.auto_comment, i.gene_sym, '', '', '', i.ec#, '', i.is_pseudogene, i.pub_comment ".
	"FROM $db..assembly a, $db..clone_info c, $db..asm_feature f, $db..ident i ".
	"WHERE a.asmbl_id = c.asmbl_id ".
	"AND c.is_public = 1 ".
	"AND a.asmbl_id = f.asmbl_id ".
	"AND f.feat_name = i.feat_name ".
	"AND f.feat_type = 'TU' ";

    }

    $query .= "ORDER BY f.asmbl_id";


    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;

    return $self->_get_results_ref($query);

}


#----------------------------------------------------------------------------------------------
# get_ident_xref_attr_data()
#
#----------------------------------------------------------------------------------------------
sub get_ident_xref_attr_data {

    my ($self, $asmbl_id, $db, $xref_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    $self->{_logger}->logdie("db was not defined") if (!defined($db));

    $self->{_logger}->logdie("xref_type was not defined") if (!defined($xref_type));
    
    print "Retrieving all TU ident_xref data\n";

    my $query;

    if (defined($asmbl_id)){

	$query = "SELECT f.asmbl_id, i.feat_name, i.ident_val, i.relrank ".
	"FROM $db..assembly a, $db..asm_feature f, $db..ident_xref i ".
	"WHERE a.asmbl_id = f.asmbl_id ".
	"AND f.feat_name = i.feat_name ".
	"AND f.feat_type = 'TU' ".
	"AND i.xref_type = ? ".
	"AND f.asmbl_id = $asmbl_id ";
    }
    else {
	

	#
	# editor:  sundaram@tigr.org
	# date:    2005-09-08
	# bgz:     2106
	# URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2106
     	# comment: If asmbl_id is not specified, then the only data retrieved is 
	#          qualified with the following clause clone_info.is_public = 1
	#
	$query = "SELECT f.asmbl_id, i.feat_name, i.ident_val, i.relrank ".
	"FROM $db..assembly a, $db..clone_info c, $db..asm_feature f, $db..ident_xref i ".
	"WHERE a.asmbl_id = c.asmbl_id ".
	"AND c.is_public = 1 ".
	"AND a.asmbl_id = f.asmbl_id ".
	"AND f.feat_name = i.feat_name ".
	"AND f.feat_type = 'TU' ".
	"AND i.xref_type = ?" ;

    }

    $query .= "ORDER BY f.asmbl_id, i.feat_name, i.ident_val, i.relrank ";


    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query, $xref_type);

}


#----------------------------------------------------------------------------------------------
# get_gene_annotation_go_attribute_data()
#
#----------------------------------------------------------------------------------------------
sub get_gene_annotation_go_attribute_data {

    my ($self, $asmbl_id, $db, $ntprok) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));


    print "Retrieving all TU role_link data\n";# if $self->{_logger}->is_debug;

    my $query;

    if (defined($asmbl_id)){
	
	$query = "SELECT f.asmbl_id, r.feat_name, r.role_id, r.assignby, r.datestamp ".
	"FROM $db..assembly a, $db..asm_feature f, $db..role_link r ".
	"WHERE a.asmbl_id = f.asmbl_id ".
	"AND f.feat_name = r.feat_name ".
	"AND f.feat_type = 'TU' ".
	"AND f.asmbl_id = $asmbl_id ";

    }
    else {


	#
	# editor:  sundaram@tigr.org
	# date:    2005-09-08
	# bgz:     2106
	# URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2106
     	# comment: If asmbl_id is not specified, then the only data retrieved is 
	#          qualified with the following clause clone_info.is_public = 1
	#
	$query = "SELECT f.asmbl_id, r.feat_name, r.role_id, r.assignby, r.datestamp ".
	"FROM $db..assembly a, $db..clone_info c, $db..asm_feature f, $db..role_link r ".
	"WHERE a.asmbl_id = c.asmbl_id ".
	"AND c.is_public = 1 ".
	"AND a.asmbl_id = f.asmbl_id ".
	"AND f.feat_name = r.feat_name ".
	"AND f.feat_type = 'TU' ";

    }


    $query .= "ORDER BY f.asmbl_id";



    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query);

}

#----------------------------------------------------------------------------------------------
# method:   get_gene_annotation_evidence_data()
#
# editor:   sundaram@tigr.org
#
# date:     Fri Nov  4 12:07:12 EST 2005
#
# bgzcase:  2271
#
# URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2271
#
# input:
#
# output:
#
# return:
#
# comment:
#
#
#----------------------------------------------------------------------------------------------
sub get_gene_annotation_evidence_data {


    my ($self, $asmbl_id, $db, $feat_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));
    $self->{_logger}->logdie("feat_type was not defined") if (!defined($feat_type));

    print "Retrieving all ORF go evidence data\n";# if $self->{_logger}->is_debug;

    #                      [0]           [1]       [2]         [3]         [4]       [5]         [6]        [7]         [8]
    my $query = "SELECT f.asmbl_id, f.feat_name, g.go_id, g.assigned_by, g.date, g.qualifier, e.ev_code, e.evidence, e.with_ev ".
    "FROM $db..assembly a, $db..clone_info c, $db..asm_feature f, $db..go_role_link g, $db..go_evidence e ".
    "WHERE a.asmbl_id = c.asmbl_id ".
    "AND c.is_public = 1 ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = g.feat_name ".
    "AND g.id = e.role_link_id ".
    "AND f.feat_type = '$feat_type' ".
    "ORDER BY f.asmbl_id";

    if (defined($asmbl_id)){
	## Don't join on clone_info.asmbl_id = assembly.asmbl_id

	$query = "SELECT f.asmbl_id, f.feat_name, g.go_id, g.assigned_by, g.date, g.qualifier, e.ev_code, e.evidence, e.with_ev ".
	"FROM $db..asm_feature f, $db..go_role_link g, $db..go_evidence e ".
	"WHERE f.feat_name = g.feat_name ".
	"AND g.id = e.role_link_id ".
	"AND f.feat_type = '$feat_type' ".
	"AND f.asmbl_id = $asmbl_id ";
    }

    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;

    return $self->_get_results_ref($query);

}

#----------------------------------------------------------------------------------------------
# method:  get_gene_orf_attributes()
#
# editor:  sundaram@tigr.org
#
# date:    Tue Nov  1 17:05:53 EST 2005
#
# bgzcase: 2141
#
# URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2141
#
# input:   prism object reference, array reference (asmbl_id list), scalar (database name),
#          scalar (feat_type), scalar (att_type)
#
# output:  status message
#
# return:  model ORF_attributes MW, pI hash reference
#
#
#
#----------------------------------------------------------------------------------------------
sub get_gene_orf_attributes {


    my ($self, $asmbl_id, $db, $feat_type, $att_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined")        if (!defined($db));
    $self->{_logger}->logdie("feat_type was not defined") if (!defined($feat_type));
    $self->{_logger}->logdie("att_type was not defined")  if (!defined($att_type));


    print "Retrieving all gene annotation ORF attributes for feat_type '$feat_type' att_type '$att_type'\n";# if $self->{_logger}->is_debug;
    
    my $query = "SELECT f.asmbl_id, f.feat_name, oa.att_type, oa.score ".
    "FROM $db..assembly a, $db..clone_info c, $db..asm_feature f, $db..ORF_attribute oa ".
    "WHERE a.asmbl_id = c.asmbl_id ".
    "AND c.is_public = 1 ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = oa.feat_name ".
    "AND oa.att_type = '$att_type' ".
    "AND f.feat_type  = '$feat_type' ";



    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";


    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query);

}

#----------------------------------------------------------------------------------------------
# get_gene_orf_score_data()
#
#----------------------------------------------------------------------------------------------
sub get_gene_orf_score_data {

    return;
}

#----------------------------------------------------------------------------------------------
# get_tigr_roles_lookup()
#
#----------------------------------------------------------------------------------------------
sub get_tigr_roles_lookup {

    return;
}

#----------------------------------------------------------------------------------------------
# get_ber_evidence_data()
#
#----------------------------------------------------------------------------------------------
sub get_ber_evidence_data {

    return;
}

#----------------------------------------------------------------------------------------------
# get_hmm_evidence_data()
#
#----------------------------------------------------------------------------------------------
sub get_hmm_evidence_data {


	my ($self, $asmbl_id, $db, $feat_type, $ev_type, $score_type) = @_;
	
	$self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
	
	$self->{_logger}->logdie("db was not defined")           if (!defined($db));
	$self->{_logger}->logdie("feat_type was not defined")    if (!defined($feat_type));
	$self->{_logger}->logdie("ev_type was not defined")      if (!defined($ev_type));
	
	print "Retrieving all HMM2 evidence data for feat_type '$feat_type' ev_type '$ev_type'\n";
	
	my $query = "SELECT f.asmbl_id, f.feat_name, e.accession, '', e.rel_end5, e.rel_end3, e.m_lend, e.m_rend, e.total_score, e.expect_whole, e.curated, e.domain_score, e.expect_domain, e.assignby, e.date ".
	"FROM $db..assembly a, $db..clone_info c, $db..asm_feature f, $db..evidence e, $db..phys_ev p ".
	"WHERE a.asmbl_id = c.asmbl_id ".
	"AND c.is_public = 1 ".
	"AND a.asmbl_id = f.asmbl_id ".
	"AND f.feat_name = e.feat_name ".
	"AND f.feat_type = '$feat_type' ".
	"AND e.ev_type = '$ev_type' ".
	"AND p.ev_type = 'working' ".
	"AND p.feat_name = f.feat_name ";
	
	
	$query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));
	
	$query .= "ORDER BY f.asmbl_id";
	
	$self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;
	
	return $self->_get_results_ref($query);
	
}

#----------------------------------------------------------------------------------------------
# get_cog_evidence_data()
#
#----------------------------------------------------------------------------------------------
sub get_cog_evidence_data {

    return;
}

#----------------------------------------------------------------------------------------------
# get_prosite_evidence_data()
#
#----------------------------------------------------------------------------------------------
sub get_prosite_evidence_data {

    return;
}


#-----------------------------------------------------------------------------
# subroutine: get_gene_finder_models()
#
# editor:     sundaram@tigr.org
#
# date:       2005-09-14
#
# bgzcase:
#
# URL:
#
# input:
#
# output:
#
# return:
#
# comment:
#
#-----------------------------------------------------------------------------
sub get_gene_finder_models {

    my($self, $asmbl_id, $includetype) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));

    print "Retrieving gene finder data for models from asm_feature, phys_ev, assembly for asmbl_id '$asmbl_id'\n";
    
    my $query = "SELECT model.feat_name, model.end5, model.end3, model.sequence, model.protein, model.date, p.ev_type ".
    "FROM asm_feature model, phys_ev p, assembly a ".
    "WHERE a.asmbl_id = model.asmbl_id ".
    "AND model.feat_name = p.feat_name ".
    "AND model.feat_type = 'model' ".
    "AND p.ev_type != 'working' ".
    "AND model.asmbl_id = ? ";


    #-----------------------------------------------------------------------------------------------
    #
    # editor:   sundaram@tigr.org
    # date:     2005-09-15
    # bgzcase:  2123
    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2123
    # comment:  User can specify which gene finder data type to include in the migration;
    #           we modify our query accordingly.
    #
    if (defined($includetype)){
	if ($includetype ne 'all'){
	    $query .= "AND p.ev_type = '$includetype' ";
	}
    }
    #
    #-----------------------------------------------------------------------------------------------
    
    return $self->_get_results($query, $asmbl_id);

}   



#-----------------------------------------------------------------------------
# subroutine: get_gene_finder_exons()
#
# editor:     sundaram@tigr.org
#
# date:       2005-09-14
#
# bgzcase:
#
# URL:
#
# input:
#
# output:
#
# return:
#
# comment:
#
#-----------------------------------------------------------------------------
sub get_gene_finder_exons {

    my($self, $asmbl_id, $includetype) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));

    print "Retrieving gene finder data for exons from asm_feature, phys_ev, assembly for asmbl_id '$asmbl_id'\n";

    my $query = "SELECT f.feat_name,f2.feat_name,f.end5,f.end3,f.date, p.ev_type ".
    "FROM asm_feature f, asm_feature f2, feat_link l, phys_ev p ".
    "WHERE f.feat_name = l.child_feat ".
    "AND f2.feat_name = l.parent_feat ".
    "AND f2.feat_type = 'model' ".
    "AND p.ev_type != 'working' ".
    "AND f.feat_type = 'exon' ".
    "AND p.feat_name = f2.feat_name ".
    "AND f.asmbl_id = ?";


    #-----------------------------------------------------------------------------------------------
    #
    # editor:   sundaram@tigr.org
    # date:     2005-09-15
    # bgzcase:  2123
    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2123
    # comment:  User can specify which gene finder data type to include in the migration;
    #           we modify our query accordingly.
    #
    if (defined($includetype)){
	if ($includetype ne 'all'){
	    $query .= "AND p.ev_type = '$includetype' ";
	}
    }
    #
    #-----------------------------------------------------------------------------------------------

    $query .= "ORDER BY f.end5";
    
    return $self->_get_results($query, $asmbl_id);

}   


#--------------------------------------------------------------------------------------------------------------------------------------------
# subroutine:  get_model_orf_attributes_is_partial()
# 
# editor:      sundaram@tigr.org
#
# date:        Tue Nov 22 16:10:14 EST 2005
#
# bgzcase:     2292
#
# URL:         http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2292
#
# comment:     The models' ORF_attributes score and score2 where att_type = 'is_partial' shall be associated with the
#              corresponding CDS features in BSML and chado
#
# input:       prism object reference, scalar (asm_feature.asmbl_id), scalar (asm_feature.feat_type), scalar (ORF_attribute.att_type)
#
# output:      none
#
# return:      hash reference
#
#--------------------------------------------------------------------------------------------------------------------------------------------
sub get_model_orf_attributes_is_partial {


    my ($self, $asmbl_id, $db, $feat_type, $att_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined")        if (!defined($db));
    $self->{_logger}->logdie("feat_type was not defined") if (!defined($feat_type));
    $self->{_logger}->logdie("att_type was not defined")  if (!defined($att_type));


    print "Retrieving all model annotation ORF attributes for feat_type '$feat_type' att_type '$att_type'\n";
    
    my $query = "SELECT f.asmbl_id, f.feat_name, oa.att_type, oa.score, oa.score2, oa.curated ".
    "FROM $db..assembly a, $db..clone_info c, $db..asm_feature f, $db..ORF_attribute oa ".
    "WHERE a.asmbl_id = c.asmbl_id ".
    "AND c.is_public = 1 ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = oa.feat_name ".
    "AND oa.att_type = '$att_type' ".
    "AND f.feat_type  = '$feat_type' ";

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";

    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query);

}


#---------------------------------------------------------------
# get_miscellaneous_features()
#
#---------------------------------------------------------------
sub get_miscellaneous_features {

    my ($self, $db, $asmbl_id, $feat_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    print "Retrieving all miscellaneous feature types for db '$db' asmbl_id '$asmbl_id' feat_type '$feat_type'\n";
    
    my $query = "SELECT f.asmbl_id, f.feat_name, f.end5, f.end3, f.comment ".
    "FROM $db..assembly a, $db..clone_info c, $db..asm_feature f ".
    "WHERE a.asmbl_id = c.asmbl_id ".
    "AND c.is_public = 1 ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_type  = '$feat_type' ";
    
    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));
    
    $query .= "ORDER BY f.asmbl_id";
    
    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;
    
    return $self->_get_results_ref($query);

}


#---------------------------------------------------------------
# get_repeat_features()
#
#---------------------------------------------------------------
sub get_repeat_features {

    my ($self, $db, $asmbl_id, $feat_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    print "Retrieving all repeat feature types for db '$db' asmbl_id '$asmbl_id' feat_type '$feat_type'\n";
    
    my $query = "SELECT f.asmbl_id, f.feat_name, f.end5, f.end3, o.score ".
    "FROM $db..assembly a, $db..clone_info c, $db..asm_feature f, $db..ORF_attribute o ".
    "WHERE a.asmbl_id = c.asmbl_id ".
    "AND c.is_public = 1 ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_type  = '$feat_type' ".
    "AND o.att_type = '$feat_type' ".
    "AND o.feat_name = f.feat_name " ;
    
    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));
    
    $query .= "ORDER BY f.asmbl_id";
    
    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;
    
    return $self->_get_results_ref($query);

}


#---------------------------------------------------------------
# get_transposon_features()
#
#---------------------------------------------------------------
sub get_transposon_features {

    my ($self, $db, $asmbl_id, $feat_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    print "Retrieving all transposon feature types for asmbl_id '$asmbl_id' feat_type '$feat_type'\n";
    
    my $query = "SELECT f.asmbl_id, f.feat_name, f.end5, f.end3, i.com_name ".
    "FROM $db..assembly a, $db..clone_info c, $db..asm_feature f, $db..ident i ".
    "WHERE a.asmbl_id = c.asmbl_id ".
    "AND c.is_public = 1 ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_type  = '$feat_type' ".
    "AND f.feat_name = i.feat_name ";
    
    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));
    
    $query .= "ORDER BY f.asmbl_id";
    
    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;
    
    return $self->_get_results_ref($query);

}

#----------------------------------------------------------------------------------------------
# get_domain_to_paralogous_family()
#
#----------------------------------------------------------------------------------------------
sub get_domain_to_paralogous_family {

    my ($self, $family_id, $ev_type, $att_type, $chromosome) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    if (!defined($family_id)){
	$self->{_logger}->logdie("family_id was not defined");
    }

    if (!defined($ev_type)){
	$ev_type = 'para2';
	$self->{_logger}->warn("evidence.ev_type was not specified and so was set to '$ev_type'");
    }

    if (!defined($att_type)){
	$att_type = 'TEMPFAM2';
	$self->{_logger}->warn("ORF_attribute.att_type was not specified and so was set to '$att_type'");
    }
    
    print "Retrieving all domain to paralogous family data for paralogous family '$family_id' with evidence.ev_type '$ev_type' and ORF_attribute.att_type '$att_type'\n";

    #
    # 0 => ORF_attribute.score  (family_id)
    # 1 => alignment.align_name (domain_name)
    # 2 => evidence.feat_name
    # 3 => evidence.accession   (domain_id)
    # 4 => asm_feature.asmbl_id
    # 5 => asm_feature.end5
    # 6 => asm_feature.end3
    # 7 => evidence.rel_end5
    # 8 => evidence.rel_end3
    # 9 => evidence.m_lend
    # 10 => evidence.m_rend
    #

    my $query = "SELECT o.score, a.align_name, e.feat_name, e.accession, f.asmbl_id, f.end5, f.end3, e.rel_end5, e.rel_end3, e.m_lend, e.m_rend, f.feat_type ".
    "FROM evidence e, alignment a,ORF_attribute o, asm_feature f,phys_ev pe, clone_info c ".
    "WHERE e.ev_type = ? ".
    "AND e.feat_name = f.feat_name ".
    "AND o.att_type = ? ".
    "AND f.feat_name = o.feat_name ".
    "AND f.feat_type = 'model' ".
    "AND f.feat_name = pe.feat_name ".
    "AND pe.ev_type = 'working' ".
    "AND f.asmbl_id = c.asmbl_id ".
    "AND c.is_public = 1 ".
    "AND c.asmbl_id != c.final_asmbl ".
    "AND convert(numeric(9,0),e.accession) = a.align_id ".
    "AND o.score = '$family_id' ";

    if (defined($chromosome)){
	$query .= "AND c.chromo =  $chromosome ";
    }

    return $self->_get_results_ref($query, $ev_type, $att_type);
    
}


#----------------------------------------------------------------------------------------------
# get_paralogous_family_alignment()
#
#----------------------------------------------------------------------------------------------
sub get_paralogous_family_alignment {

    
    my ($self, $family_id, $ev_type, $att_type, $chromosome) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    if (!defined($family_id)){
	$self->{_logger}->logdie("family_id was not defined");
    }

    if (!defined($ev_type)){
	$ev_type = 'para2';
	$self->{_logger}->warn("evidence.ev_type was not specified and so was set to '$ev_type'");
    }

    if (!defined($att_type)){
	$att_type = 'TEMPFAM2';
	$self->{_logger}->warn("ORF_attribute.att_type was not specified and so was set to '$att_type'");
    }
    
    print "Retrieving all paralogous family alignments for paralogous family '$family_id' with evidence.ev_type '$ev_type' and ORF_attribute.att_type '$att_type'\n";

    #
    # 0 => ORF_attribute.score      (family_id)
    # 1 => alignment.alignment_name (domain_name)
    # 2 => alignment.alignment
    #
    my $query = "SELECT o.score, a.align_name, a.alignment ".
    "FROM ORF_attribute o, alignment a, clone_info c, evidence e, asm_feature f ".
    "WHERE f.asmbl_id = c.asmbl_id ".
    "AND c.is_public = 1 ".
    "AND c.asmbl_id != c.final_asmbl ".
    "AND f.feat_name = e.feat_name ".
    "AND f.feat_name = o.feat_name ".
    "AND e.ev_type = ? ".
    "AND o.att_type = ? ".
    "AND convert(NUMERIC(9,0), e.accession) = a.align_id ".
    "AND o.score = '$family_id' ";
    
    if (defined($chromosome)){
	$query .= "AND c.chromo = $chromosome ";
    }

    $query .= "ORDER BY o.score, a.align_name ";
    
    return $self->_get_results_ref($query, $ev_type, $att_type);
    
}

#----------------------------------------------------------------------------------------------
# get_paralogous_family_identifiers()
#
#----------------------------------------------------------------------------------------------
sub get_paralogous_family_identifiers {

    
    my ($self, $ev_type, $att_type, $chromosome) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    if (!defined($ev_type)){
	$ev_type = 'para2';
	$self->{_logger}->warn("evidence.ev_type was not specified and so was set to '$ev_type'");
    }

    if (!defined($att_type)){
	$ev_type = 'TEMPFAM2';
	$self->{_logger}->warn("ORF_attribute.att_type was not specified and so was set to '$att_type'");
    }

    print "Retrieving all paralogous family identifiers with evidence.ev_type '$ev_type' and ORF_attribute.att_type '$att_type'\n";

    #
    # 0 => ORF_attribute.score      (family_id)

    my $query = "SELECT distinct o.score ".
    "FROM ORF_attribute o, alignment a, clone_info c, evidence e, asm_feature f ".
    "WHERE f.asmbl_id = c.asmbl_id ".
    "AND c.is_public = 1 ".
    "AND c.asmbl_id != c.final_asmbl ".
    "AND f.feat_name = e.feat_name ".
    "AND f.feat_name = o.feat_name ".
    "AND e.ev_type = ? ".
    "AND o.att_type = ? ".
    "AND convert(NUMERIC(9,0), e.accession) = a.align_id ";

    if (defined($chromosome)){
	$query .= "AND c.chromo = $chromosome ";
    }


    
    return $self->_get_results_ref($query, $ev_type, $att_type);
    
}


#----------------------------------------------------------------------------------------------
# get_pmark_data()
#
#----------------------------------------------------------------------------------------------
sub get_pmark_data {

    my ($self, $asmbl_id, $db) = @_;

    if (!defined($db)){
	$self->{_logger}->logdie("db was not defined");
    }

    print "Retrieving all pmark data\n";

    my $query = "SELECT f.asmbl_id, f.feat_name, f.end5, f.end3, f.comment, f.sequence ".
    "FROM $db..clone_info c, $db..assembly a, $db..asm_feature f ".
    "WHERE c.asmbl_id = a.asmbl_id " .
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_type = 'PMARK' ";

    if (defined($asmbl_id)){
	$query .= "AND f.asmbl_id = $asmbl_id ";
    }
    else {
	$query .= "AND c.is_public = 1 ";
    }



    $query .= "ORDER BY f.asmbl_id";

    return $self->_get_results_ref($query);

}


##--------------------------------------------------------------------------------------------
## getInterproEvidenceDataByAsmblId()
##
##--------------------------------------------------------------------------------------------
sub getInterproEvidenceDataByAsmblId {

    return undef;
}



##----------------------------------------------------------------
## getOrganismData()
##
##----------------------------------------------------------------
sub getOrganismData {

    my ($self, $database) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($database)){
	$self->{_logger}->logdie("database was not defined");
    }


    # return hash
    my %s;


    ##
    ## Retrieve data from common..genomes
    ##
    my @ret = $self->get_common_genomes_data($database);

    my $fatalCtr=0;

    ##
    ## Extract the common..genomes.file_moniker
    ##
    if (!defined($ret[0][0])){
	$self->{_logger}->fatal("common..genomes.file_moniker was not ".
				"defined for common..genomes.db = '$database'");
	$fatalCtr++;
    }
    else {
	$s{'abbreviation'} = $ret[0][0]; # common..genomes.file_moniker
    }


    ##
    ## Extract the common..genomes.name
    ##
    if (!defined($ret[0][1])){
	$self->{_logger}->fatal("common..genomes.name was not defined for ".
				"common..genomes.db = '$database'");
	$fatalCtr++;
    }
    else {
	$s{'name'} = $ret[0][1]; # common..genomes.name
    }



    if ($fatalCtr>0){
	$self->{_logger}->logdie("Fatal errors detected.  See logfile");
    }

    if (!defined($ret[0][2])){
	$self->{_logger}->warn("common..genome.type was not defined for common..genomes.db = '$database'");
    }
    else {
	$s{'type'} = $ret[0][2]; # common..genomes.type
    }


    my @ret2 = $self->get_new_project_data();
    

    ##
    ## extract the taxon_id
    ##
    if (!defined($ret2[0][0])){
	$self->{_logger}->warn("new_project.taxon_id was not defined for database '$database'");
    }
    else {
	$s{'taxon_id'} = $ret2[0][0]; # new_project.taxon_id
    }
  
    if (!defined($ret2[0][2])){
	## set default genetic code value for eukaryotes
	$s{'genetic_code'} = 1;

	$self->{_logger}->warn("new_project.genetic_code was not defined for ".
			       "database '$database' so default value '1' ".
			       "was assigned");
    }
    else {
	$s{'genetic_code'} = $ret2[0][2]; # new_project.genetic_code
    }
    

    ## mitochondrial genetic code value
    $s{'mt_genetic_code'} = 4;


    return (\%s);
}


=item $obj->doesAsmblIdExist()

B<Description:> For determining whether the asmbl_id exists in the database

B<Parameters:> $asmbl_id (scalar)

B<Returns:> DBI result array reference

=cut

sub doesAsmblIdExist {

    my $self = shift;
    my ($asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    my $query = "SELECT asmbl_id FROM assembly WHERE asmbl_id = ? ";

    return $self->_get_results_ref($query, $asmbl_id);
}


=item $obj->doesAssemblyHaveCDSFeatures()

B<Description:> For determining whether the assembly has any CDS features

B<Parameters:> $asmbl_id (scalar)

B<Returns:> DBI result array reference

=cut

sub doesAssemblyHaveCDSFeatures {

    my $self = shift;
    my ($asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    my $query = "SELECT COUNT(feat_type) FROM asm_feature WHERE asmbl_id = ? AND feat_type = 'model'";

    return $self->_get_results_ref($query, $asmbl_id);
}

=item $obj->getAssemblySequence()

B<Description:> For retrieving the assembly.sequence

B<Parameters:> $asmbl_id (scalar)

B<Returns:> DBI result array reference

=cut

sub getAssemblySequence {

    my $self = shift;
    my ($asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    my $query = "SELECT sequence FROM assembly WHERE asmbl_id = ?";

    return $self->_get_results_ref($query, $asmbl_id);
}

=item $obj->getCDSCoordinates()

B<Description:> For retrieving the assembly.sequence

B<Parameters:> $asmbl_id (scalar)

B<Returns:> DBI result array reference

=cut

sub getCDSCoordinates {

    my $self = shift;
    my ($asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    my $query = "SELECT feat_name, end5, end3 FROM asm_feature WHERE asmbl_id = ? AND feat_type = 'model'";

    return $self->_get_results_ref($query, $asmbl_id);
}

=item $obj->getCurrentCDSValues()

B<Description:> For retrieving the asm_feature.sequence and asm_feature.protein for models

B<Parameters:> $asmbl_id (scalar)

B<Returns:> DBI result array reference

=cut

sub getCurrentCDSValues {

    my $self = shift;
    my ($asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    my $query = "SELECT feat_name, sequence, protein FROM asm_feature WHERE asmbl_id = ? AND feat_type = 'model'";

    return $self->_get_results_ref($query, $asmbl_id);
}




=item $obj->getModelCoordinatesByAssemblyIdentifier(id=>$id)

B<Description:> Retrieve all model data for the specified assembly

B<Parameters:> $id (scalar - string)

B<Returns:> DBI result array reference

=cut

sub getModelCoordinatesByAssemblyIdentifier {

    my $self = shift;
    my (%args) = @_;

    if (! exists $args{'id'}){
	$self->{_logger}->logdie("id was not specified");
    }

    my $query = "SELECT m.feat_name, m.end5, m.end3, t.feat_name ".
    "FROM asm_feature m, asm_feature t, feat_link fl, ident i, phys_ev p ".
    "WHERE m.feat_type = 'model' ".
    "AND m.feat_name = fl.child_feat ".
    "AND fl.parent_feat = t.feat_name ".
    "AND t.feat_type = 'TU' ".
    "AND t.feat_name = i.feat_name ".
    "AND i.is_pseudogene = 0 ".
    "AND m.feat_name = p.feat_name ".
    "AND p.ev_type = 'working' ".
    "AND m.asmbl_id = $args{'id'} ";

    return $self->_get_results_ref($query);
}

=item $obj->getCDSCoordinatesByAssemblyIdentifier(id=>$id)

B<Description:> Retrieve all CDS data for the specified assembly

B<Parameters:> $id (scalar - string)

B<Returns:> DBI result array reference

=cut

sub getCDSCoordinatesByAssemblyIdentifier {

    my $self = shift;
    my (%args) = @_;

    if (! exists $args{'id'}){
	$self->{_logger}->logdie("id was not specified");
    }

    my $query = "SELECT m.feat_name, c.feat_name, c.end5, c.end3 ".
    "FROM asm_feature c, asm_feature m, feat_link fl, asm_feature t, feat_link fl2, ident i, phys_ev p, asm_feature e, feat_link fl3 ".
    "WHERE c.feat_type = 'CDS' ".
    "AND e.feat_type = 'exon' ".
    "AND m.feat_type = 'model' ".
    "AND t.feat_type = 'TU' ".
    "AND t.feat_name = fl.parent_feat ".
    "AND fl.child_feat = m.feat_name ".
    "AND m.feat_name = fl2.parent_feat ".
    "AND fl2.child_feat = e.feat_name ".
    "AND e.feat_name = fl3.parent_feat ".
    "AND fl3.child_feat = c.feat_name ".
    "AND t.feat_name = i.feat_name ".
    "AND i.is_pseudogene = 0 ".
    "AND m.feat_name = p.feat_name ".
    "AND p.ev_type = 'working' ".
    "AND m.asmbl_id = $args{'id'} ".
    "GROUP BY m.feat_name, c.feat_name, c.end5, c.end3 ".
    "ORDER BY c.end5";

    return $self->_get_results_ref($query);
}


=item $obj->getModelSequences($asmbl_id, $db)

B<Description:> Retrieve sequence and protein for all qualifying models for the specified assembly and database

B<Parameters:> 

$asmbl_id (scalar - string
$database (scalar - string)

B<Returns:> DBI result array reference

=cut

sub getModelSequences {

    my $self = shift;
    my($asmbl_id, $db) = @_;

    if (!defined($db)){
	$self->{_logger}->logdie("db was not defined");
    }

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    print "Retrieving all sequence data for models in database '$db' associated with assembly '$asmbl_id'\n";
 
    my $query = "SELECT model.asmbl_id, model.feat_name, model.feat_type, model.sequence, model.protein " .
#"FROM $db..assembly a, $db..asm_feature model, $db..phys_ev p, $db..feat_link fl, $db..asm_feature tu, $db..ident i " .
    "FROM $db..asm_feature model, $db..phys_ev p, $db..feat_link fl, $db..asm_feature tu, $db..ident i " .
    "WHERE tu.feat_type = 'TU'".
    "AND model.feat_type = 'model' ".
    "AND tu.feat_name = i.feat_name ".
    "AND i.is_pseudogene = 0 ".
    "AND tu.feat_name = fl.parent_feat ".
    "AND fl.child_feat = model.feat_name " .
    "AND model.feat_name = p.feat_name ".
    "AND p.ev_type = 'working' ".
    "AND model.asmbl_id = $asmbl_id ";
#    "AND model.asmbl_id = a.asmbl_id ";
#    "AND a.asmbl_id = $asmbl_id ";
    
    return $self->_get_results_ref($query);
}


sub getAssemblyData {

    my $self = shift;
    my ($asmbl_id) = @_;
    
    my $query = "SELECT a.sequence, c.clone_name, c.seq_group, c.chromo, c.gb_acc, c.is_public, a.ed_date, null, null, c.clone_id, c.orig_annotation, c.tigr_annotation, c.status, c.length, c.final_asmbl, c.fa_left, c.fa_right, c.fa_orient, c.gb_desc, c.gb_comment, c.gb_date, c.comment, c.assignby, c.date, c.lib_id, c.seq_asmbl_id, c.date_for_release, c.date_released, c.authors1, c.authors2, c.seq_db, c.gb_keywords, c.sequencing_type, c.prelim, c.license, c.gb_phase, c.gb_gi ".
    "FROM assembly a, clone_info c ".
    "WHERE a.asmbl_id = c.asmbl_id ";
    
    
    if (defined($asmbl_id)){

	$query .= "AND a.asmbl_id = $asmbl_id ";
	
	print "Retrieving euk records from assembly, clone_info for asmbl_id '$asmbl_id'\n";
 
    } else{

	print "Retrieving all qualifying euk records from assembly, clone_info\n";

    }

    return $self->_get_results_ref($query);
}

sub getTUs { 

    my $self = shift;
    my ($asmbl_id) = @_;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    my $query = "SELECT f.feat_name, f.end5,f.end3,f.sequence,i.locus,i.com_name,f.date, i.is_pseudogene, i.alt_locus, i.pub_locus, f.curated ".
    "FROM asm_feature f, asm_feature f2, feat_link l, phys_ev p, ident i ".
    "WHERE f.feat_type = 'TU' ".
    "AND l.parent_feat = f.feat_name ".
    "AND i.feat_name = f.feat_name ".
    "AND f2.feat_name = l.child_feat ".
    "AND f2.feat_name = p.feat_name ".
    "AND p.ev_type = 'working' ".
    "AND f2.feat_type = 'model' ".
    "AND f.asmbl_id = ?";

    return $self->_get_results_ref($query, $asmbl_id);
}   

sub getModels {

    my $self = shift;
    my ($asmbl_id) = @_;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    my $query = "SELECT f2.feat_name,f.feat_name,f.end5,f.end3,f.sequence,f.protein,f.date, f.curated ".
    "FROM asm_feature f, asm_feature f2, feat_link l, phys_ev p ".
    "WHERE f.feat_name = l.child_feat ".
    "AND f2.feat_name = l.parent_feat ".
    "AND f2.feat_type = 'TU' ".
    "AND f.feat_type = 'model' ".
    "AND f.feat_name = p.feat_name ".
    "AND p.ev_type = 'working' ".
    "AND f.asmbl_id = ?";
    
    return $self->_get_results_ref($query, $asmbl_id);
}   


sub getExons {

    my $self = shift;
    my ($asmbl_id) = @_;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }


    my $query = "SELECT f2.feat_name,f.feat_name,f.end5,f.end3,f.date ".
	"FROM asm_feature f, asm_feature f2, feat_link l, phys_ev p ".
	"WHERE f.feat_name = l.child_feat ".
	"AND f2.feat_name = l.parent_feat ".
	"AND f2.feat_type = 'model' ".
	"AND f.feat_type = 'exon' ".
	"AND p.feat_name = f2.feat_name ".
	"AND p.ev_type = 'working' ".
	"AND f.asmbl_id = ?".
	"ORDER BY f.end5";

    return $self->_get_results_ref($query, $asmbl_id);

}   

sub getAllIdentXrefRecords {

    my $self = shift;
    my ($asmbl_id, $db) = @_;

    if (!defined($db)){
	$self->{_logger}->logdie("db was not defined");
    }

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    my $query = "SELECT i.feat_name, i.xref_type, i.ident_val, i.relrank ".
    "FROM $db..assembly a, $db..asm_feature f, $db..ident_xref i ".
    "WHERE a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = i.feat_name ".
    "AND f.feat_type = 'TU' ".
    "AND f.asmbl_id = ? ".
    "ORDER BY i.feat_name, i.xref_type, i.ident_val, i.relrank ";

    print "Retrieving all TU ident_xref data\n";

    return $self->_get_results_ref($query, $asmbl_id);
}


sub getGORoles {

    my $self = shift;
    my ($asmbl_id, $db) = @_;

    if (!defined($db)){
	$self->{_logger}->logdie("db was not defined");
    }

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    print "Retrieving all TU GO evidence\n";

    #                      [0]           [1]       [2]         [3]         [4]       [5]         [6]        [7]    
    my $query = "SELECT  f.feat_name, g.go_id, g.assigned_by, g.date, g.qualifier, e.ev_code, e.evidence, e.with_ev ".
    "FROM $db..asm_feature f, $db..go_role_link g, $db..go_evidence e ".
    "WHERE f.feat_name = g.feat_name ".
    "AND g.id = e.role_link_id ".
    "AND f.feat_type = 'TU' ".
    "AND f.asmbl_id = ? ";
    

    return $self->_get_results_ref($query, $asmbl_id);

}

sub getGenusAndSpeciesFromCloneInfo {
    
    my $self = shift;

    my ($asmbl_id) = @_;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    my $query = "SELECT comment ".
    "FROM clone_info ".
    "WHERE asmbl_id = ? ";

    return $self->_get_results_ref($query, $asmbl_id);
}


sub getPartialSequenceInfo {
    
    my $self = shift;

    my ($asmbl_id) = @_;


    my $query = "SELECT o.feat_name, o.score, o.score2 ".
    "FROM ORF_attribute o, asm_feature f ".
    "WHERE o.att_type = 'is_partial' ".
    "AND o.feat_name = f.feat_name ";

    if (defined($asmbl_id)){
	$query .= "AND f.asmbl_id = $asmbl_id ";
    }

    return $self->_get_results_ref($query);
}

sub getParamData {

    my $self = shift;
    my ($asmbl_id) = @_;

    my $query;

    if (!defined($asmbl_id)){

	$query = "SELECT DISTINCT o.feat_name, o.score ".
	"FROM ORF_attribute o, asm_feature a, clone_info c, feat_link l, ident i ".
	"WHERE i.feat_name = l.parent_feat ".
	"AND l.child_feat = a.feat_name ".
	"AND o.feat_name = a.feat_name ".
	"AND a.asmbl_id = c.asmbl_id ".
	"AND o.att_type = '$TEMPFAM' "; 

    } else {

	$query = "SELECT DISTINCT o.feat_name, o.score ".
	"FROM ORF_attribute o, asm_feature a, feat_link l, ident i ".
	"WHERE i.feat_name = l.parent_feat ".
	"AND l.child_feat = a.feat_name ".
	"AND o.feat_name = a.feat_name ".
	"AND a.asmbl_id = $asmbl_id ".
	"AND o.att_type = '$TEMPFAM' "; 
	
    }

    return $self->_get_results_ref($query);
}


sub getTmhmmRecords {

    my $self = shift;
    my ($asmbl_id) = @_;

    my $query;

    if (!defined($asmbl_id)){

	$query = "SELECT o.feat_name, o.score, o.score2 ".
	"FROM ORF_attribute o, asm_feature f, phys_ev p, clone_info c ".
	"WHERE p.ev_type = 'working' ".
	"AND p.feat_name = f.feat_name ".
	"AND f.feat_name = o.feat_name ".
	"AND o.att_type = 'GES' ".
	"AND c.asmbl_id = f.asmbl_id ";

    } else {

	$query = "SELECT o.feat_name, o.score, o.score2 ".
	"FROM ORF_attribute o, asm_feature f, phys_ev p ".
	"WHERE p.ev_type = 'working' ".
	"AND p.feat_name = f.feat_name ".
	"AND f.feat_name = o.feat_name ".
	"AND o.att_type = 'GES' ".
	"AND f.asmbl_id = $asmbl_id ";
	
    }

    return $self->_get_results_ref($query);
}



sub getSignalPHMMRecords {

    my $self = shift;
    my ($asmbl_id) = @_;

    my $query;

    if (!defined($asmbl_id)){

	$query = "SELECT o.feat_name, o.score, o.score2 ".
	"FROM ORF_attribute o, asm_feature f, phys_ev p, clone_info c ".
	"WHERE p.ev_type = 'working' ".
	"AND p.feat_name = f.feat_name ".
	"AND f.feat_name = o.feat_name ".
	"AND o.att_type = 'SP-HMM' ".
	"AND c.asmbl_id = f.asmbl_id ";

    } else {

	$query = "SELECT o.feat_name, o.score, o.score2 ".
	"FROM ORF_attribute o, asm_feature f, phys_ev p ".
	"WHERE p.ev_type = 'working' ".
	"AND p.feat_name = f.feat_name ".
	"AND f.feat_name = o.feat_name ".
	"AND o.att_type = 'SP-HMM' ".
	"AND f.asmbl_id = $asmbl_id ";
	
    }

    return $self->_get_results_ref($query);
}

sub getSignalPNNRecords {

    my $self = shift;
    my ($asmbl_id) = @_;

    my $query;

    if (!defined($asmbl_id)){

	$query = "SELECT o.feat_name, o.score, o.score2 ".
	"FROM ORF_attribute o, asm_feature f, phys_ev p, clone_info c ".
	"WHERE p.ev_type = 'working' ".
	"AND p.feat_name = f.feat_name ".
	"AND f.feat_name = o.feat_name ".
	"AND o.att_type = 'SP-NN' ".
	"AND c.asmbl_id = f.asmbl_id ";

    } else {

	$query = "SELECT o.feat_name, o.score, o.score2 ".
	"FROM ORF_attribute o, asm_feature f, phys_ev p ".
	"WHERE p.ev_type = 'working' ".
	"AND p.feat_name = f.feat_name ".
	"AND f.feat_name = o.feat_name ".
	"AND o.att_type = 'SP-NN' ".
	"AND f.asmbl_id = $asmbl_id ";
	
    }

    return $self->_get_results_ref($query);
}



sub getScopRecords {

    my $self = shift;
    my ($asmbl_id) = @_;

    my $query;

    if (!defined($asmbl_id)){

	$query = "SELECT o.feat_name, o.score, o.score2 ".
	"FROM ORF_attribute o, asm_feature f, phys_ev p, clone_info c ".
	"WHERE p.ev_type = 'working' ".
	"AND p.feat_name = f.feat_name ".
	"AND f.feat_name = o.feat_name ".
	"AND o.att_type = 'scop' ".
	"AND c.asmbl_id = f.asmbl_id ";

    } else {

	$query = "SELECT o.feat_name, o.score, o.score2 ".
	"FROM ORF_attribute o, asm_feature f, phys_ev p ".
	"WHERE p.ev_type = 'working' ".
	"AND p.feat_name = f.feat_name ".
	"AND f.feat_name = o.feat_name ".
	"AND o.att_type = 'scop' ".
	"AND f.asmbl_id = $asmbl_id ";
	
    }

    return $self->_get_results_ref($query);
}


sub getHmmPfamRecords {

    my $self = shift;
    my ($asmbl_id) = @_;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    my $query = "SELECT e.feat_name, hmm_acc, hmm_com_name ".
    "FROM evidence e, egad..hmm2 h, asm_feature a, clone_info c ".
    "WHERE e.feat_name = a.feat_name ".
    "AND a.asmbl_id = $asmbl_id ".
    "AND e.accession = h.hmm_acc ".
    "AND a.asmbl_id = c.asmbl_id ".
    "AND is_public = 1 ".
    "AND CONVERT (numeric (9,2), total_score) >= trusted_cutoff ";

    return $self->_get_results_ref($query);
}



1==1; ## End of module
