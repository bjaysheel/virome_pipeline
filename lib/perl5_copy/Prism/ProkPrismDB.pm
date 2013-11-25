package Prism::ProkPrismDB;

use strict;
use base qw(Prism::PrismDB);

sub test_ProkPrismDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_PrismDB();
}

sub testProjDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_ProkPrismDB();

}


#-----------------------------------------------------------------------------
# get_common_genomes_data 
#
#-----------------------------------------------------------------------------
sub get_common_genomes_data {  

    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));
    

    #----------------------------------------------------------------------------------------------
    # editor:  sundaram@tigr.org
    # date:    2005-10-11
    # bgzcase: 2183
    # URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2183
    # comment: The syntax was correct.  Needed to include column common..genomes.type in the
    #          retrieval query.
    #
    my $query = "SELECT file_moniker, name, type ".
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
# get_exons
#
#-----------------------------------------------------------------------------
sub get_exons {

    my($self,$model) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT f.feat_name,f.end5,f.end3 ".
	"FROM asm_feature f, asm_feature f2, feat_link l ".
	"WHERE f.feat_name = l.child_feat ".
	"AND f2.feat_name = l.parent_feat ".
	"AND f2.feat_type = 'model' ".
	"AND f.feat_type = 'exon' ".
	"AND f2.feat_name = ?";


    return $self->_get_results($query,$model);
}   


#-----------------------------------------------------------------------------
# get_prok_sequence_info
#
#-----------------------------------------------------------------------------
sub get_prok_sequence_info { 

    my ($self, $asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;    

    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));


    my $query;

    if (!defined($asmbl_id)){
	$query = "SELECT a.sequence ".
	"FROM assembly a, stan s ".
	"WHERE a.asmbl_id = s.asmbl_id ".
	"AND s.iscurrent = 1 ";
    }
    else {
	$query = "SELECT a.sequence ".
	"FROM assembly a, stan s ".
	"WHERE a.asmbl_id = s.asmbl_id ".
	"AND a.asmbl_id = $asmbl_id ";
    }

    return $self->_get_results($query);

}


#-----------------------------------------------------------------------------
# get_all_assembly_records()
#
#-----------------------------------------------------------------------------
sub get_all_assembly_records { 

    my ($self, $asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;    

    my $query;
    
    if (!defined($asmbl_id)){
	$query = "SELECT a.asmbl_id, a.sequence, b.name, '', '', b.acc_num, '', a.ed_date, b.topology, b.type ".
	"FROM assembly a, stan s, asmbl_data b ".
	"WHERE a.asmbl_id = s.asmbl_id ".
	"AND s.iscurrent = 1 ".
	"AND s.asmbl_data_id = b.id ";
    }
    else {
	$query = "SELECT a.asmbl_id, a.sequence, b.name, '', '', b.acc_num, '', a.ed_date, b.topology, b.type ".
	"FROM assembly a, stan s, asmbl_data b ".
	"WHERE a.asmbl_id = s.asmbl_id ".
	"AND s.asmbl_data_id = b.id ".
	"AND a.asmbl_id = $asmbl_id ";
    }
    
    print "Retrieving all qualifying records from assembly, stan\n";

    return $self->_get_results($query);

}



#-----------------------------------------------------------------------------
# get_all_prok_accession_records()
#
#-----------------------------------------------------------------------------
sub get_all_prok_accession_records { 

    my ($self, $asmbl_id, $feat_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;    

    my $query;

    if (!defined($asmbl_id)){
	$query = "SELECT a.asmbl_id, n.feat_name, n.accession_db, n.accession_id ".
	"FROM accession n, asm_feature f, assembly a, stan s ".
	"WHERE a.asmbl_id = s.asmbl_id ".
	"AND s.iscurrent = 1 ".
	"AND a.asmbl_id = f.asmbl_id ".
	"AND f.feat_name = n.feat_name "; 
    }
    else {
	$query = "SELECT a.asmbl_id, n.feat_name, n.accession_db, n.accession_id ".
	"FROM accession n, asm_feature f, assembly a, stan s ".
	"WHERE a.asmbl_id = s.asmbl_id ".
	"AND a.asmbl_id = f.asmbl_id ".
	"AND f.feat_name = n.feat_name ".
	"AND a.asmbl_id = $asmbl_id ";
    }

    if (defined($feat_type)){
	$query .= "AND f.feat_type = '$feat_type' ";
    }

    print "Retrieving all qualifying records from accession, asm_feature, assembly, stan\n";

    return $self->_get_results($query);

}

#----------------------------------------------------------------------------------------------
# get_db_to_seq()
#
# sort of like: Coati::Coati::EukCoatiDB::get_db_to_seq_names()
#
#----------------------------------------------------------------------------------------------
sub get_db_to_seq {

    my($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT s.asmbl_id, a.name, a.type, m.sequence, datalength(m.sequence), m.com_name, m.ed_date " .
                "FROM $db..stan s, $db..asmbl_data a, $db..assembly m " .
                "WHERE s.iscurrent = 1 " .
                "AND s.asmbl_data_id = a.id " .
		"AND m.asmbl_id = s.asmbl_id ".
                "ORDER BY a.type, a.name";

    return $self->_get_results($query);
}



#----------------------------------------------------------------------------------------------
# get_sequence_features()
#
#
#----------------------------------------------------------------------------------------------
sub get_sequence_features {

    my($self, $asmbl_id, $db, $feat_type, $schemaType) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;


    $self->{_logger}->logdie("db was not defined") if (!defined($db));
    $self->{_logger}->logdie("feat_type was not defined") if (!defined($feat_type));



    print "Retrieving all sequence types for database '$db' assembly '$asmbl_id' feat_type '$feat_type'\n";# if $self->{_logger}->is_debug;

    my $query;

    if ($schemaType eq 'ntprok'){
	
	if (($feat_type eq 'ORF')  || ($feat_type eq 'NTORF')){
	    ## retrieved ORF asm_feature records must have a corresponding ident record
	    $query = "SELECT f.asmbl_id, f.feat_name, f.feat_type, f.sequence, f.protein " .
	    "FROM $db..stan s, $db..assembly a, $db..asm_feature f, $db..nt_ident i " .
	    "WHERE s.asmbl_id = a.asmbl_id " .
	    "AND a.asmbl_id = f.asmbl_id ".
	    "AND f.feat_type = '$feat_type' ".
	    "AND f.feat_name = i.feat_name ";
	}
	else {
        ## kgalens (08/13/2008)
        ## removing ident table from select statement because it's not used

	    ## all other types are not required to have an ident record
	    $query = "SELECT f.asmbl_id, f.feat_name, f.feat_type, f.sequence, f.protein " .
	    "FROM $db..stan s, $db..assembly a, $db..asm_feature f " .
	    "WHERE s.asmbl_id = a.asmbl_id " .
	    "AND a.asmbl_id = f.asmbl_id ".
	    "AND f.feat_type = '$feat_type'";
	}
    }
    else {
	
	if (($feat_type eq 'ORF')  || ($feat_type eq 'NTORF')){
	    ## retrieved ORF asm_feature records must have a corresponding ident record
	    
	    $query = "SELECT f.asmbl_id, f.feat_name, f.feat_type, f.sequence, f.protein " .
	    "FROM $db..stan s, $db..assembly a, $db..asm_feature f, $db..ident i " .
	    "WHERE s.asmbl_id = a.asmbl_id " .
	    "AND a.asmbl_id = f.asmbl_id ".
	    "AND f.feat_type = '$feat_type' ".
	    "AND f.feat_name = i.feat_name ";
	}
	else {
        ## kgalens (08/13/2008)
        ## removing ident table from select statement because it's not used
        
	    ## all other types are not required to have an ident record
	    $query = "SELECT f.asmbl_id, f.feat_name, f.feat_type, f.sequence, f.protein " .
	    "FROM $db..stan s, $db..assembly a, $db..asm_feature f " .
	    "WHERE s.asmbl_id = a.asmbl_id " .
	    "AND a.asmbl_id = f.asmbl_id ".
	    "AND f.feat_type = '$feat_type'";
	}
    }
	
	
    $query .= "AND a.asmbl_id = $asmbl_id " if (defined($asmbl_id));
    $query .= "ORDER BY f.asmbl_id";

    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;

    return $self->_get_results_ref($query);
}



#----------------------------------------------------------------------------------------------
# get_gene_model_data()
#
#
#----------------------------------------------------------------------------------------------
sub get_gene_model_data {

    my ($self, $asmbl_id, $db, $schemaType) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));


    print "Retrieving all Gene Model member types\n";# if $self->{_logger}->is_debug;

    #----------------------------------------------------------------------------------------------------------
    # editor:   sundaram@tigr.org
    # date:     Thu Nov  3 11:19:40 EST 2005
    # bgzcase:  2266
    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2266
    # comment:  The legacy2bsml.pl migration script should now retrieve the protein secondary
    #           structure data from asm_feature.sec_struct where feat_type = 'ORF'.
    #
    #           We will associate this data with the BSML and chado protein Feature as a
    #           featureprop with Sequence Ontology controlled vocabulary term name
    #           'sequence_secondary_structure'.
    #
    my $query = "SELECT f.asmbl_id, f.feat_name, f.end5, f.end3, i.locus, i.locus ".
	"FROM $db..stan s, $db..assembly a, $db..asm_feature f, $db..ident i " .
	"WHERE s.asmbl_id = a.asmbl_id " .
	"AND a.asmbl_id = f.asmbl_id ".
	"AND f.feat_type = 'ORF' ".
	"AND f.feat_name = i.feat_name ";


    if ( $schemaType eq 'ntprok' ) {

	$query = "SELECT f.asmbl_id, f.feat_name, f.end5, f.end3, i.locus, i.nt_locus ".
	"FROM $db..stan s, $db..assembly a, $db..asm_feature f, $db..nt_ident i " .
	"WHERE s.asmbl_id = a.asmbl_id " .
	"AND a.asmbl_id = f.asmbl_id ".
	"AND f.feat_type = 'NTORF' ".
	"AND f.feat_name = i.feat_name ";
    }

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";

    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query);
}

#----------------------------------------------------------------------------------------------
# get_accession_data()
#
#
#----------------------------------------------------------------------------------------------
sub get_accession_data {

    my ($self, $asmbl_id, $db, $schemaType) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));


    print "Retrieving all accession data\n";# if $self->{_logger}->is_debug;

    my $query = "SELECT f.asmbl_id, f.feat_name, ac.accession_db, ac.accession_id ".
                "FROM $db..stan s, $db..assembly a, $db..asm_feature f, $db..accession ac " .
                "WHERE s.asmbl_id = a.asmbl_id " .
		"AND a.asmbl_id = f.asmbl_id ".
		"AND f.feat_type = 'ORF' ".
		"AND f.feat_name = ac.feat_name ";


    if ( $schemaType eq 'ntprok') {

	$query = "SELECT f.asmbl_id, f.feat_name, ac.accession_db, ac.accession_id ".
	"FROM $db..stan s, $db..assembly a, $db..asm_feature f, $db..accession ac " .
	"WHERE s.asmbl_id = a.asmbl_id " .
	"AND a.asmbl_id = f.asmbl_id ".
	"AND f.feat_type = 'NTORF' ".
	"AND f.feat_name = ac.feat_name ";

    }

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";

    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;

    ## kgalens (08/13/2008)
    ## there are some prok databases without an accession table which turns
    ## out is perfectly okay.  If we fail here (most likely for a missing
    ## table), return an empty array ref.
    
    my $retval = [];
    eval {
        $retval = $self->_get_results_ref($query);
    };

    return $retval;
}


#----------------------------------------------------------------------------------------------
# get_rna_data()
#
#
#----------------------------------------------------------------------------------------------
sub get_rna_data {

    my ($self, $asmbl_id, $db, $feat_type, $schemaType) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));
    $self->{_logger}->logdie("feat_type was not defined") if (!defined($feat_type));


    print "Retrieving all '$feat_type' types from database '$db'\n";# if $self->{_logger}->is_debug;

    
    
    #-------------------------------------------------------------------------------------------------------------------
    # editor:    sundaram@tigr.org
    # date:      Sat Oct 29 23:00:24 EDT 2005
    # bgzcase:   2257
    # URL:       http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2257
    # comment:   Retrieve the locus for the RNAs

    ## kgalens (08/13/2008)
    ## DBMS generic select statement
    my $query = "SELECT f.asmbl_id, f.feat_name, f.end5, f.end3, f.feat_type, i.com_name, i.gene_sym, i.pub_comment, i.locus " .
        "FROM ($db..asm_feature f LEFT JOIN $db..ident i on f.feat_name = i.feat_name), $db..assembly a, $db..stan s ".
        "WHERE a.asmbl_id = s.asmbl_id ".
        "AND a.asmbl_id = f.asmbl_id ".
        "AND f.feat_type = '$feat_type' ";

    if ( $schemaType eq 'ntprok' ) {

        my $query = "SELECT f.asmbl_id, f.feat_name, f.end5, f.end3, f.feat_type, i.com_name, i.gene_sym, i.pub_comment, i.locus " .
        "FROM ($db..asm_feature f LEFT JOIN $db..nt_ident i on f.feat_name = i.feat_name), $db..assembly a, $db..stan s ".
        "WHERE a.asmbl_id = s.asmbl_id ".
        "AND a.asmbl_id = f.asmbl_id ".
        "AND f.feat_type = '$feat_type' ";
	
    }


    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";

    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;

    return $self->_get_results_ref($query);

}

#----------------------------------------------------------------
# getRnaDataByAsmblId()
#
#----------------------------------------------------------------
sub getRnaDataByAsmblId {

    my ($self, $asmbl_id, $db, $schemaType) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    if (!defined($db)){
	$self->{_logger}->logdie("db was not defined");
    }

    if (!defined($schemaType)){
	$self->{_logger}->logdie("schema_type was not defined");
    }

     my $query = "SELECT f.feat_name, f.end5, f.end3, f.feat_type, i.com_name, i.gene_sym, i.pub_comment, i.locus, f.sequence ".
        "FROM ($db..asm_feature f LEFT JOIN $db..ident i on f.feat_name = i.feat_name ), ".
        "$db..assembly a, $db..stan s ".
        "WHERE a.asmbl_id = s.asmbl_id ".
        "AND a.asmbl_id = f.asmbl_id ".
        "AND (f.feat_type = 'rRNA' ".
        "OR f.feat_type = 'sRNA' ".
        "OR f.feat_type = 'ncRNA' ".
        "OR f.feat_type = 'tRNA' ) ";

    if ( $schemaType eq 'ntprok' ) {

        $query = "SELECT f.feat_name, f.end5, f.end3, f.feat_type, i.com_name, i.gene_sym, i.pub_comment, i.locus, f.sequence " .
            "FROM ($db..asm_feature f LEFT JOIN $db..ident i on f.feat_name = i.feat_name ), ".
            "$db..assembly a, $db..stan s ".
            "WHERE a.asmbl_id = s.asmbl_id ".
            "AND a.asmbl_id = f.asmbl_id ".
            "AND (f.feat_type = 'rRNA' ".
            "OR f.feat_type = 'sRNA' ".
            "OR f.feat_type = 'ncRNA' ".
            "OR f.feat_type = 'NTtRNA' ".
            "OR f.feat_type = 'NTrRNA' ".
            "OR f.feat_type = 'NTmisc_RNA' ".
            "OR f.feat_type = 'tRNA' ) ";
	
    }

    $query .= "AND f.asmbl_id = $asmbl_id ".
    "ORDER BY f.asmbl_id";
    
    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }

    print "Retrieving all RNA features from database '$db'\n";
    return $self->_get_results_ref($query);
}

#--------------------------------------------------------
# get_trna_scores()
#
#--------------------------------------------------------
sub get_trna_scores {

    my ($self, $asmbl_id, $db, $feat_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));

    print "Retrieving all tRNA scores for feat_type '$feat_type'\n";# if $self->{_logger}->is_debug;

    my $query = "SELECT f.feat_name, fs.score ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..ORF_attribute oa, $db..feat_score fs, common..score_type st ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_type = '$feat_type' ".
    "AND f.feat_name = oa.feat_name ".
    "AND oa.att_type = 'tRNA' ".
    "AND oa.id = fs.input_id ".
    "AND fs.score_id = st.id ".
    "AND st.input_type = 'tRNA' ".
    "AND st.score_type = 'anti-codon' ";


    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";

    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;

    return $self->_get_results_ref($query);

}

#------------------------------------------------------
# getTrnaScores()
#
#------------------------------------------------------
sub getTrnaScores {

    my ($self, $asmbl_id, $db, $schema_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    if (!defined($db)){
	$self->{_logger}->logdie("db was not defined");
    }

    my $query = "SELECT f.feat_name, fs.score ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..ORF_attribute oa, $db..feat_score fs, common..score_type st ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ";

    if ($schema_type eq 'prok'){
	$query .= "AND f.feat_type = 'tRNA' ";
    }
    elsif ($schema_type eq 'ntprok'){
	$query .= "AND f.feat_type = 'NTtRNA' ";
    }
    else {
	$self->{_logger}->logdie("Unexpected schema type '$schema_type'");
    }

    $query .= "AND f.feat_name = oa.feat_name ".
    "AND oa.att_type = 'tRNA' ".
    "AND oa.id = fs.input_id ".
    "AND fs.score_id = st.id ".
    "AND st.input_type = 'tRNA' ".
    "AND st.score_type = 'anti-codon' ".
    "AND f.asmbl_id = $asmbl_id ".
    "ORDER BY f.asmbl_id";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug($query);
    }

    print "Retrieving all tRNA scores from database '$db' for asmbl_id '$asmbl_id'\n";
    return $self->_get_results_ref($query);
}

#----------------------------------------------------------------------------------------------
# get_peptide_data()
#
#
#----------------------------------------------------------------------------------------------
sub get_peptide_data {

    my ($self, $asmbl_id, $db, $schemaType) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));


    print "Retrieving all peptide data\n";# if $self->{_logger}->is_debug;


    my $query = "SELECT f.feat_name, st.score_type, fs.score ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..ORF_attribute oa, $db..feat_score fs, common..score_type st ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_type = 'ORF' ".
    "AND f.feat_name = oa.feat_name ".
    "AND oa.att_type = 'SP' ".
    "AND oa.id = fs.input_id ".
    "AND fs.score_id = st.id ".
    "AND st.input_type = 'SP' ";

    if ( $schemaType eq 'ntprok' ){

	$query = "SELECT f.feat_name, st.score_type, fs.score ".
	"FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..ORF_attribute oa, $db..feat_score fs, common..score_type st ".
	"WHERE a.asmbl_id = s.asmbl_id ".
	"AND a.asmbl_id = f.asmbl_id ".
	"AND f.feat_type = 'NTORF' ".
	"AND f.feat_name = oa.feat_name ".
	"AND oa.att_type = 'SP' ".
	"AND oa.id = fs.input_id ".
	"AND fs.score_id = st.id ".
	"AND st.input_type = 'SP' ";
    }



    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";


    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query);

}

#----------------------------------------------------------------------------------------------
# get_ribosomal_data()
#
#
#----------------------------------------------------------------------------------------------
sub get_ribosomal_data {

    my ($self, $asmbl_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));

    print "Retrieving all ribosomal data\n";# if $self->{_logger}->is_debug;

    my $query = "SELECT f.asmbl_id, f.feat_name, f.end5, f.end3 ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_type = 'RBS' ";

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";


    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query);

}


#----------------------------------------------------------------------------------------------
# get_terminator_data()
#
#
#----------------------------------------------------------------------------------------------
sub get_terminator_data {

    my ($self, $asmbl_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));

    print "Retrieving all terminator data\n";# if $self->{_logger}->is_debug;

    my $query = "SELECT f.asmbl_id, f.feat_name, f.end5, f.end3, f.comment ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_type = 'TERM' ";

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";


    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query);

}

#----------------------------------------------------------------------------------------------
# get_term_direction_data()
#
#
#----------------------------------------------------------------------------------------------
sub get_term_direction_data {

    my ($self, $asmbl_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));

    print "Retrieving all terminator direction data\n";# if $self->{_logger}->is_debug;

    my $query = "SELECT f.asmbl_id, f.feat_name, fs.score ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..ORF_attribute oa, $db..feat_score fs ".
    "WHERE f.feat_type = 'TERM' ".
    "AND f.feat_name = oa.feat_name ".
    "AND oa.att_type = 'TERM' ".
    "AND oa.id = fs.input_id ".
    "AND fs.score_id = 91 ".
    "AND a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ";

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";


    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query);

}

#----------------------------------------------------------------------------------------------
# get_term_confidence_data()
#
#
#----------------------------------------------------------------------------------------------
sub get_term_confidence_data {

    my ($self, $asmbl_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));

    print "Retrieving all terminator confidence data\n";# if $self->{_logger}->is_debug;

    my $query = "SELECT f.asmbl_id, f.feat_name, fs.score ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..ORF_attribute o, $db..feat_score fs ".
    "WHERE f.feat_type = 'TERM' ".
    "AND f.feat_name = o.feat_name ".
    "AND o.att_type = 'TERM' ".
    "AND o.id = fs.input_id ".
    "AND fs.score_id = 90 ".
    "AND a.asmbl_id = f.asmbl_id ";

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";


    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query);

}


 
#----------------------------------------------------------------------------------------------
# get_terminator_to_gene_data()
#
#----------------------------------------------------------------------------------------------
sub get_terminator_to_gene_data {

    my ($self, $asmbl_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));

    print "Retrieving all terminator-to-gene data\n";# if $self->{_logger}->is_debug;

    my $query = "SELECT a.asmbl_id, f1.feat_name, f2.feat_name ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f1, $db..asm_feature f2, $db..feat_link fl ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f2.asmbl_id ".
    "AND f1.feat_type = 'TERM' ".
    "AND f2.feat_type = 'ORF' ".
    "AND f1.feat_name = fl.child_feat ".
    "AND f2.feat_name = fl.parent_feat ";

    $query .= "AND f2.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f2.asmbl_id";


    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query);

}



#----------------------------------------------------------------------------------------------
# get_rbs_to_gene_data()
#
#----------------------------------------------------------------------------------------------
sub get_rbs_to_gene_data {

    my ($self, $asmbl_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));

    print "Retrieving all RBS-to-gene data\n";# if $self->{_logger}->is_debug;

    my $query = "SELECT a.asmbl_id, f1.feat_name, f2.feat_name ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f1, $db..asm_feature f2, $db..feat_link fl ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f2.asmbl_id ".
    "AND f1.feat_type = 'RBS' ".
    "AND f2.feat_type = 'ORF' ".
    "AND f1.feat_name = fl.child_feat ".
    "AND f2.feat_name = fl.parent_feat ";

    $query .= "AND f2.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f2.asmbl_id";


    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query);

}


#----------------------------------------------------------------------------------------------
# get_gene_annotation_ident_attribute_data()
#
#
#----------------------------------------------------------------------------------------------
sub get_gene_annotation_ident_attribute_data {

    my ($self, $asmbl_id, $db, $schemaType ) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));

    print "Retrieving all ORF ident data\n";# if $self->{_logger}->is_debug;

    my $query = "SELECT f.asmbl_id, i.feat_name, i.com_name, i.assignby, i.date, i.comment, i.nt_comment, i.auto_comment, i.gene_sym, i.start_edit, i.complete, i.auto_annotate, i.ec#, i.pub_comment ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..ident i ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = i.feat_name ".
    "AND f.feat_type = 'ORF' ";

    if ( $schemaType eq 'ntprok' ){
	$query = "SELECT f.asmbl_id, i.feat_name, i.com_name, i.assignby, i.date, i.comment, i.nt_comment, i.auto_comment, i.gene_sym, NULL, NULL, NULL, i.ec#, i.pub_comment  ".
	"FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..nt_ident i ".
	"WHERE a.asmbl_id = s.asmbl_id ".
	"AND a.asmbl_id = f.asmbl_id ".
	"AND f.feat_name = i.feat_name ".
	"AND f.feat_type = 'NTORF' ";
    }


    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";


    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query);

}




#----------------------------------------------------------------------------------------------
# get_gene_annotation_go_attribute_data()
#
#
#----------------------------------------------------------------------------------------------
sub get_gene_annotation_go_attribute_data {

    my ($self, $asmbl_id, $db, $schemaType) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));


    print "Retrieving all ORF role_link data\n";# if $self->{_logger}->is_debug;

    my $query = "SELECT f.asmbl_id, r.feat_name, r.role_id, r.assignby, r.datestamp, n.notes ".
        "FROM ($db..role_link r LEFT JOIN $db..role_notes n on r.role_id = n.role_id), $db..assembly a, $db..stan s, $db..asm_feature f ".
        "WHERE a.asmbl_id = s.asmbl_id ".
        "AND a.asmbl_id = f.asmbl_id ".
        "AND f.feat_name = r.feat_name ".
        "AND f.feat_type = 'ORF' ";

    if ( $schemaType eq 'ntprok' ){
        my $query = "SELECT f.asmbl_id, r.feat_name, r.role_id, r.assignby, r.datestamp, n.notes ".
            "FROM ($db..role_link r LEFT JOIN $db..role_notes n on r.role_id = n.role_id), $db..assembly a, $db..stan s, $db..asm_feature f ".
            "WHERE a.asmbl_id = s.asmbl_id ".
            "AND a.asmbl_id = f.asmbl_id ".
            "AND f.feat_name = r.feat_name ".
            "AND f.feat_type = 'NTORF' ";
    }

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";



    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query);

}





#----------------------------------------------------------------------------------------------
# get_gene_annotation_evidence_data()
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
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..go_role_link g, $db..go_evidence e ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = g.feat_name ".
    "AND g.id = e.role_link_id ".
    "AND f.feat_type = '$feat_type' ";

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";

    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;

    return $self->_get_results_ref($query);

}



#----------------------------------------------------------------------------------------------
# get_gene_orf_attributes()
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
    
    my $query = "SELECT f.asmbl_id, f.feat_name, oa.att_type, fs.score ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..ORF_attribute oa, $db..feat_score fs, common..score_type st ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = oa.feat_name ".
    "AND oa.id = fs.input_id ".
    "AND fs.score_id =  st.id ".
    "AND st.input_type = '$att_type' ".
    "AND f.feat_type = '$feat_type' ".
    "AND st.score_type = '$att_type' ".
    "AND oa.att_type = '$att_type' ";



    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";


    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query);

}

#------------------------------------------------
# getLipoMembraneProteins()
#
#------------------------------------------------
sub getLipoMembraneProteins {

    my $self = shift;
    my ($asmbl_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    if (!defined($db)){
	$self->{_logger}->logdie("db was not defined");
    }
    
    my $query = "SELECT f.feat_name, fs.score ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..ORF_attribute oa, $db..feat_score fs, common..score_type st ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = oa.feat_name ".
    "AND oa.id = fs.input_id ".
    "AND fs.score_id =  st.id ".
    "AND st.input_type = 'LP' ".
    "AND f.feat_type = 'ORF' ".
    "AND oa.att_type = 'LP' ".
    "AND fs.score != '0' ".
    "AND st.score_type = 'subsequence' ";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("query : $query");
    }

    print "Retrieving all lipo_membrane_protein ORF_attribute data\n";

    return $self->_get_results_ref($query);

}



#----------------------------------------------------------------------------------------------
# get_gene_orf_score_data()
#
#
#----------------------------------------------------------------------------------------------
sub get_gene_orf_score_data {

    my ($self, $asmbl_id, $db, $feat_type, $att_type, $score_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined") if (!defined($db));
    $self->{_logger}->logdie("feat_type was not defined") if (!defined($feat_type));
    $self->{_logger}->logdie("att_type was not defined") if (!defined($att_type));
    $self->{_logger}->logdie("score_type was not defined") if (!defined($score_type));


    print "Retrieving all gene ORF score data for feat_type '$feat_type' att_type '$att_type' score_type '$score_type'\n";# if $self->{_logger}->is_debug;


    my $query = "SELECT f.asmbl_id, f.feat_name, st.score_type, fs.score ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..ORF_attribute oa, $db..feat_score fs, common..score_type st ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = oa.feat_name ".
    "AND oa.id = fs.input_id ".
    "AND f.feat_type = '$feat_type' ".
    "AND oa.att_type = '$att_type' ".
    "AND st.id = fs.score_id ".
    "AND st.score_type = '$score_type' ";

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";


    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;


    return $self->_get_results_ref($query);

}



#----------------------------------------------------------------------------------------------
# get_ber_evidence_data()
#
#
#----------------------------------------------------------------------------------------------
sub get_ber_evidence_data {

    my ($self, $asmbl_id, $db, $feat_type, $ev_type, $score_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined")           if (!defined($db));
    $self->{_logger}->logdie("feat_type was not defined")    if (!defined($feat_type));
    $self->{_logger}->logdie("ev_type was not defined")      if (!defined($ev_type));
    $self->{_logger}->logdie("score_type was not defined")   if (!defined($score_type));


    print "Retrieving all BER evidence data for feat_type '$feat_type' ev_type '$ev_type' score_type '$score_type'\n";# if $self->{_logger}->is_debug;


    my $query = "SELECT f.asmbl_id, f.feat_name, e.accession, fs.score, e.end5, e.end3, e.m_lend, e.m_rend, e.date ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..evidence e, $db..feat_score fs, common..score_type st ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = e.feat_name ".
    "AND e.id = fs.input_id ".
    "AND f.feat_type = '$feat_type' ".
    "AND e.ev_type = '$ev_type' ".
    "AND st.id = fs.score_id ".
    "AND st.score_type = '$score_type' ";

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";


    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;

    return $self->_get_results_ref($query);

}
 



#----------------------------------------------------------------------------------------------
# get_hmm_evidence_data()
#
#
#----------------------------------------------------------------------------------------------
sub get_hmm_evidence_data {

    my ($self, $asmbl_id, $db, $feat_type, $ev_type, $score_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined")           if (!defined($db));
    $self->{_logger}->logdie("feat_type was not defined")    if (!defined($feat_type));
    $self->{_logger}->logdie("ev_type was not defined")      if (!defined($ev_type));
    $self->{_logger}->logdie("score_type was not defined")   if (!defined($score_type));


    print "Retrieving all HMM evidence data for feat_type '$feat_type' ev_type '$ev_type' score_type '$score_type'\n";# if $self->{_logger}->is_debug;


    my $query = "SELECT f.asmbl_id, f.feat_name, e.accession, fs.score, e.rel_end5, e.rel_end3, e.m_lend, e.m_rend ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..evidence e, $db..feat_score fs, common..score_type st ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = e.feat_name ".
    "AND e.id = fs.input_id ".
    "AND f.feat_type = '$feat_type' ".
    "AND e.ev_type = '$ev_type' ".
    "AND st.id = fs.score_id ".
    "AND st.score_type = '$score_type' ";

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";

    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;

    return $self->_get_results_ref($query);

}
 
#----------------------------------------------------------------------------------------------
# get_cog_evidence_data()
#
#
#----------------------------------------------------------------------------------------------
sub get_cog_evidence_data {

    my ($self, $asmbl_id, $db, $feat_type, $ev_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined")           if (!defined($db));
    $self->{_logger}->logdie("feat_type was not defined")    if (!defined($feat_type));
    $self->{_logger}->logdie("ev_type was not defined")      if (!defined($ev_type));


    print "Retrieving all COG accession evidence data for feat_type '$feat_type' ev_type '$ev_type'\n";# if $self->{_logger}->is_debug;


    my $query = "SELECT f.asmbl_id, f.feat_name, e.accession, e.rel_end5, e.rel_end3, e.m_lend, e.m_rend ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..evidence e ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = e.feat_name ".
    "AND f.feat_type = '$feat_type' ".
    "AND e.ev_type = '$ev_type' ";

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";

    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;

    return $self->_get_results_ref($query);

}
 
#----------------------------------------------------------------------------------------------
# get_prosite_evidence_data()
#
#
#----------------------------------------------------------------------------------------------
sub get_prosite_evidence_data {

    my ($self, $asmbl_id, $db, $feat_type, $ev_type, $score_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined")           if (!defined($db));
    $self->{_logger}->logdie("feat_type was not defined")    if (!defined($feat_type));
    $self->{_logger}->logdie("ev_type was not defined")      if (!defined($ev_type));
    $self->{_logger}->logdie("score_type was not defined")   if (!defined($score_type));


    print "Retrieving all PROSITE evidence data for feat_type '$feat_type' ev_type '$ev_type' score_type '$score_type'\n";# if $self->{_logger}->is_debug;


    my $query = "SELECT f.asmbl_id, f.feat_name, e.accession, fs.score, e.rel_end5, e.rel_end3, e.m_lend, e.m_rend ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..evidence e, $db..feat_score fs, common..score_type st ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = e.feat_name ".
    "AND e.id = fs.input_id ".
    "AND f.feat_type = '$feat_type' ".
    "AND e.ev_type = '$ev_type' ".
    "AND st.id = fs.score_id ".
    "AND st.score_type = '$score_type' ";

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";

    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;

    return $self->_get_results_ref($query);

}
 


#-----------------------------------------------------------------------------
# get_all_valid_prok_asmbl_ids()
#
#-----------------------------------------------------------------------------
sub get_all_valid_prok_asmbl_ids { 

    my ($self, $organism) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;    

    my $query = "SELECT a.asmbl_id ".
    "FROM $organism..assembly a, $organism..stan s ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND s.iscurrent = 1 ";
    
    print "Retrieving all valid asmbl_ids for organism '$organism' from assembly, stan\n";
    return $self->_get_results($query);

}



#-----------------------------------------------------------------------------
# get_orf_ntorf_feat_link()
#
#-----------------------------------------------------------------------------
sub get_orf_ntorf_feat_link {

    my($self, $asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT p.feat_name, c.feat_name ".
	"FROM asm_feature p, asm_feature c, feat_link fl, assembly a ".
	"WHERE a.asmbl_id = p.asmbl_id ".
	"AND a.asmbl_id = c.asmbl_id ".
	"AND p.feat_name = fl.parent_feat ".
	"AND fl.child_feat = c.feat_name ".
	"AND fl.parent_feat like 'NTORF%' ".
	"AND fl.child_feat like 'ORF%' " .
	"AND p.feat_name != c.feat_name ";

    if (defined($asmbl_id)){
	$query .= "AND a.asmbl_id = $asmbl_id ";
    }

    return $self->_get_results($query);
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
    "FROM $db..stan s, $db..assembly a, $db..asm_feature f ".
    "WHERE s.asmbl_id = a.asmbl_id " .
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_type = 'PMARK' ";

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";

    return $self->_get_results_ref($query);

}

#----------------------------------------------------------------------------------------------
# getInterproEvidenceDataByAsmblId()
#
#
#----------------------------------------------------------------------------------------------
sub getInterproEvidenceDataByAsmblId {

    my ($self, $asmbl_id, $db, $feat_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if (!defined($db)){
	$self->{_logger}->logdie("db was not defined");
    }           

    if (!defined($feat_type)){
	$self->{_logger}->logdie("feat_type was not defined");
    }
    
    print "Retrieving all Interpro data for feat_type '$feat_type' ev_type 'interpro'\n";

    my $query = "SELECT f.feat_name, e.accession, e.end5, e.end3 ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..evidence e ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = e.feat_name ".
    "AND f.feat_type = ? ".
    "AND e.ev_type = 'Interpro' ";

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));
    
    $query .= "ORDER BY f.asmbl_id";
    
    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;

    return $self->_get_results_ref($query, $feat_type);

}

#--------------------------------------------------
# get_gene_finder_models()
#
#--------------------------------------------------
sub get_gene_finder_models {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    ## Not implemented for prok schema

    ## kgalens (08/13/2008)
    ## returning an empty array for no results instead of undef (causing failures)
    return ();

}

#--------------------------------------------------
# get_gene_finder_exons()
#
#--------------------------------------------------
sub get_gene_finder_exons {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    ## Not implemented for prok schema

    return undef;

}

=item $obj->getAllIsCurrentAssemblyArrayRef()

B<Description:> For retrieving all assembly identifiers which are current

B<Parameters:> None

B<Returns:> $arrayref (DBI reference to array)

=cut

sub getAllIsCurrentAssemblyArrayRef {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a.asmbl_id ".
    "FROM assembly a, stan s ".
    "WHERE s.iscurrent = 1 ".
    "AND s.asmbl_id = a.asmbl_id ";
    
    return $self->_get_results_ref($query);
}

=item $obj->getAssemblyIdentifiers()

B<Description:> For retrieving all assembly identifiers

B<Parameters:> None

B<Returns:> $arrayref (DBI reference to array)

=cut

sub getAllAssemblyIdentifiers {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a.asmbl_id FROM assembly a ";

    return $self->_get_results_ref($query);
}


=item $obj->doesAssemblyHaveNcRNASubFeatures()

B<Description:> Verify whether the specified assembly has ncRNA subfeatures

B<Parameters:> $asmbl_id (scalar)

B<Returns:> $arrayref (DBI reference to array)

=cut

sub doesAssemblyHaveNcRNASubFeatures {

    my $self = shift;

    my ($asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT COUNT(f.feat_name) ".
    "FROM asm_feature f ".
    "WHERE f.asmbl_id = ? ".
    "AND f.feat_type = 'ncRNA' ";
    
    return $self->_get_results_ref($query, $asmbl_id);
}

=item $obj->getNcRNASequencesByAsmblId()

B<Description:> Retrieve all sequences for the ncRNA features that
are associated with the specified assembly

B<Parameters:> $asmbl_id (scalar)

B<Returns:> $arrayref (DBI reference to array)

=cut

sub getNcRNASequencesByAsmblId {

    my $self = shift;

    my ($asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT f.feat_name, f.sequence ".
    "FROM asm_feature f ".
    "WHERE f.asmbl_id = ? ".
    "AND f.feat_type = 'ncRNA' ";
    
    return $self->_get_results_ref($query, $asmbl_id);
}


=item $obj->getEpitopeAsmFeatureRecords($asmbl_id, $db)

B<Description:> Retrieve all data associated with the epitope features for the specified asmbl_id and db

B<Parameters:> 

$asmbl_id (scalar - unsigned integer)
$db (scalar - string)

B<Returns:> $arrayref (DBI reference to array)

=cut

sub getEpitopeAsmFeatureRecords {

    my $self = shift;

    my ($asmbl_id, $db) = @_;

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }
    if (!defined($db)){
	$self->{_logger}->logdie("db was not defined");
    }

    my $query = "SELECT f.feat_name, f.feat_type, f.feat_method, ".
    "f.end5, f.end3, f.assignby, f.date, f.sequence, f.protein, ".
#    "f.sequence_other, f.sequence_other_type, fl.parent_feat ".
    "null, null, fl.parent_feat ".
    "FROM $db..asm_feature f, $db..feat_link fl ".
    "WHERE f.asmbl_id = ? ".
    "AND f.feat_class = 'EPI' ".
    "AND f.feat_name = fl.child_feat ";


    print "Will retrieve all asm_feature epitope records for asmbl_id '$asmbl_id' database '$db'\n";

    return $self->_get_results_ref($query, $asmbl_id);
}


=item $obj->getEpitopeIdentRecords($asmbl_id, $db)

B<Description:> Retrieve all data associated with the epitope features for the specified asmbl_id and db

B<Parameters:> 

$asmbl_id (scalar - unsigned integer)
$db (scalar - string)

B<Returns:> $arrayref (DBI reference to array)

=cut

sub getEpitopeIdentRecords {

    my $self = shift;

    my ($asmbl_id, $db) = @_;
 
    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }
    if (!defined($db)){
	$self->{_logger}->logdie("db was not defined");
    }

    my $query = "SELECT i.feat_name, i.com_name, i.comment, i.assignby, i.date, i.ec#, i.auto_comment, i.gene_sym, i.pub_comment ".
    "FROM $db..asm_feature f, $db..ident i ".
    "WHERE f.asmbl_id = ? ".
    "AND f.feat_class = 'EPI' ".
    "AND f.feat_name = i.feat_name ";

    print "Will retrieve all ident epitope records for asmbl_id '$asmbl_id' database '$db'\n";
    
    return $self->_get_results_ref($query, $asmbl_id);
}

=item $obj->getEpitopeEvidenceRecords($asmbl_id, $db)

B<Description:> Retrieve all data associated with the epitope features for the specified asmbl_id and db

B<Parameters:> 

$asmbl_id (scalar - unsigned integer)
$db (scalar - string)

B<Returns:> $arrayref (DBI reference to array)

=cut

sub getEpitopeEvidenceRecords {

    my $self = shift;

    my ($asmbl_id, $db) = @_;
 
    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }
    if (!defined($db)){
	$self->{_logger}->logdie("db was not defined");
    }

    my $query = "SELECT e.feat_name, e.id, e.accession, e.method ".
    "FROM $db..asm_feature f, $db..evidence e ".
    "WHERE f.asmbl_id = ? ".
    "AND f.feat_class = 'EPI' ".
    "AND e.ev_type = 'EPI' ".
    "AND f.feat_name = e.feat_name ";

    print "Will retrieve all evidence epitope records for asmbl_id '$asmbl_id' database '$db'\n";

    return $self->_get_results_ref($query, $asmbl_id);
}

=item $obj->getEpitopeAccessionRecords($asmbl_id, $db)

B<Description:> Retrieve all data associated with the epitope features for the specified asmbl_id and db

B<Parameters:> 

$asmbl_id (scalar - unsigned integer)
$db (scalar - string)

B<Returns:> $arrayref (DBI reference to array)

=cut

sub getEpitopeAccessionRecords {

    my $self = shift;

    my ($asmbl_id, $db) = @_;
 
    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }
    if (!defined($db)){
	$self->{_logger}->logdie("db was not defined");
    }

    my $query = "SELECT a.feat_name, a.accession_id, a.accession_db ".
    "FROM $db..asm_feature f, $db..accession a ".
    "WHERE f.asmbl_id = ? ".
    "AND f.feat_class = 'EPI' ".
    "AND f.feat_name = a.feat_name ";

    print "Will retrieve all accession epitope records for asmbl_id '$asmbl_id' database '$db'\n";

    return $self->_get_results_ref($query, $asmbl_id);
}


=item $obj->getEpitopeScoreRecords($asmbl_id, $db)

B<Description:> Retrieve all data associated with the epitope features for the specified asmbl_id and db

B<Parameters:> 

$asmbl_id (scalar - unsigned integer)
$db (scalar - string)

B<Returns:> $arrayref (DBI reference to array)

=cut

sub getEpitopeScoreRecords {

    my $self = shift;

    my ($asmbl_id, $db) = @_;
 
    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }
    if (!defined($db)){
	$self->{_logger}->logdie("db was not defined");
    }

    my $query = "SELECT e.feat_name, fs.score, st.id, st.description, st.date, st.assignby ".
    "FROM $db..asm_feature f, $db..evidence e, $db..feat_score fs, common..score_type st ".
    "WHERE f.asmbl_id = ? ".
    "AND f.feat_class = 'EPI' ".
    "AND f.feat_name = e.feat_name ".
    "AND e.ev_type = 'EPI' ".
    "AND e.id = fs.input_id ".
    "AND st.id = fs.score_id ".
    "AND st.input_type = 'EPI' ";

    print "Will retrieve all feat_score and score_type epitope records for asmbl_id '$asmbl_id' database '$db'\n";

    return $self->_get_results_ref($query, $asmbl_id);
}

sub getVirulenceFactors {

    my $self = shift;
    my ($asmbl_id, $db, $feat_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_logger}->logdie("db was not defined")        if (!defined($db));
    $self->{_logger}->logdie("feat_type was not defined") if (!defined($feat_type));


    print "Retrieving all virulence factor data from ORF_attributes for feat_type '$feat_type'\n";
    
    my $query = "SELECT f.asmbl_id, f.feat_name, oa.att_type, fs.score ".
    "FROM $db..assembly a, $db..stan s, $db..asm_feature f, $db..ORF_attribute oa, $db..feat_score fs, common..score_type st ".
    "WHERE a.asmbl_id = s.asmbl_id ".
    "AND a.asmbl_id = f.asmbl_id ".
    "AND f.feat_name = oa.feat_name ".
    "AND oa.id = fs.input_id ".
    "AND fs.score_id =  st.id ".
    "AND st.input_type = 'VIR' ".
    "AND f.feat_type = '$feat_type' ".
    "AND st.score_type = 'PMID' ".
    "AND oa.att_type = 'VIR' ";

    $query .= "AND f.asmbl_id = $asmbl_id " if (defined($asmbl_id));

    $query .= "ORDER BY f.asmbl_id";

    $self->{_logger}->debug("query : $query") if $self->{_logger}->is_debug;

    return $self->_get_results_ref($query);
}

=item $obj->getUnqualifiedProteinRecords($asmbl_id, $db)

B<Description:> Retrieve all records where ORF_attribute.att_type is AFS/APM/DEG for the specified asmbl_id and db

B<Parameters:> 

$asmbl_id (scalar - unsigned integer)
$db (scalar - string)

B<Returns:> $arrayref (DBI reference to array)

=cut

sub getDisruptedProteinRecords {

    my $self = shift;

    my ($asmbl_id, $db) = @_;
 
    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }
    if (!defined($db)){
	$self->{_logger}->logdie("db was not defined");
    }

    my $query = "SELECT f.feat_name, f.protein, o.att_type ".
    "FROM $db..asm_feature f, $db..ORF_attribute o ".
    "WHERE f.asmbl_id = ? ".
    "AND f.feat_type = 'ORF' ".
    "AND f.feat_name = o.feat_name ".
    "AND ( o.att_type = 'AFS' ".
    "OR o.att_type = 'APM' ".
    "OR o.att_type = 'DEG' )";

    print "Will retrieve all proteins that have AFS/APM/DEG att_type ".
    "values for asmbl_id '$asmbl_id' database '$db'\n";

    return $self->_get_results_ref($query, $asmbl_id);
}

=item $obj->getFeatNameSpeciesRecordsFromIdent()

B<Description:> Retrieve all feat_name and species values from ident

B<Parameters:> None

B<Returns:> $arrayref (PERL DBI reference to array)

=cut

sub getFeatNameSpeciesRecordsFromIdent {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT i.feat_name, i.species ".
    "FROM ident i ";
    
    return $self->_get_results_ref($query);
}

=item $obj->getFeatNameComNameRecordsFromNtIdent()

B<Description:> Retrieve all feat_name and com_name values from nt_ident

B<Parameters:> None

B<Returns:> $arrayref (PERL DBI reference to array)

=cut

sub getFeatNameComNameRecordsFromNtIdent {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT i.feat_name, nt.com_name ".
    "FROM nt_ident nt, feat_link fl, ident i, asm_feature f, assembly a ".
    "WHERE nt.feat_name = fl.child_feat ".
    "AND fl.parent_feat = i.feat_name ".
    "AND i.feat_name = f.feat_name ".
    "AND f.asmbl_id = a.asmbl_id ";
    
    return $self->_get_results_ref($query);
}




1;  ## End of module 
