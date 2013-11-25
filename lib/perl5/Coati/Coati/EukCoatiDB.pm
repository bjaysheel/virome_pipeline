package Coati::Coati::EukCoatiDB;

use strict;
use base qw(Coati::Coati::CoatiDB);

###################################



######################
# GENE_ID INPUT_TYPE #
######################

sub get_gene_id_to_description {
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id, $db);
    }
    
    my $query = "SELECT a2.feat_name, i.locus, i.comment, i.pub_comment, i.auto_comment, i.nt_comment, i.date, i.pub_locus, i.is_pseudogene, '', '', '', a2.end5, a2.end3, 0 as strand, a2.sequence, a2.protein, a.asmbl_id, '', a2.curated, a.curated, a.feat_type ,i.com_name ".
                "FROM $db..ident i, $db..asm_feature a, $db..asm_feature a2, $db..feat_link l ".
		"WHERE a2.feat_name = '$gene_id' ".
		"AND a2.feat_name = l.child_feat ".
		"AND l.parent_feat = a.feat_name ".
		"AND i.feat_name = a.feat_name ";
    my $ret = $self->_get_results_ref($query);
    
    #
    # Get primary names and other data from the ident_xref table
    my $ret2 = $self->get_gene_id_to_primary_descriptions($gene_id, $db);
    
    $ret->[0][23] = $ret2->[0][0]; ### product name
    $ret->[0][24] = $ret2->[0][1]; ### gene name
    $ret->[0][25] = $ret2->[0][2]; ### gene symbol
    $ret->[0][26] = $ret2->[0][3]; ### EC number
    
    #
    # Determine the length of the protein.
    $ret->[0][27] = length($ret->[0][15]);
    $ret->[0][28] = length($ret->[0][16]);

    $ret->[0][30] = $ret2->[0][4]; ### community functional assignment
    $ret->[0][31] = $ret2->[0][5]; ### community gene name
    
    return $ret;
}

sub get_gene_id_to_primary_descriptions {
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id, $db);
    }

    my $ret;
    my @types = ("product name", "gene name", "gene symbol", "ec number", "ca_functional_assignment", "ca_gene_name");
    
    my $query = "SELECT x.ident_val ".
	        "FROM $db..ident_xref x ".
		"WHERE x.feat_name = ? ".
		"AND x.xref_type = ? ".
		"AND x.relrank = 1 ";    

    for(my $i=0; $i<@types; $i++) {
	my $x = $self->_get_results_ref($query, $gene_id, $types[$i]);
	$ret->[0][$i] = $x->[0][0];
    }
    return $ret;
}

sub get_gene_id_to_molecular_weight {
    my ($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT o.score ".
	        "FROM ORF_attribute o ".
	        "WHERE o.feat_name = '$gene_id' ".
		"AND o.att_type = 'MW' ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_pI {
    my ($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT o.score ".
	        "FROM ORF_attribute o ".
	        "WHERE o.feat_name = ? ".
		"AND o.att_type = ? ";

    return $self->_get_results_ref($query, $gene_id, 'PI');
}

sub get_gene_id_to_HMMs {
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id, $db);
    }
    
    my $query = "SELECT e.id, e.accession, e.domain_score, e.expect_domain,e.total_score, e.expect_whole, e.curated, e.end5, e.end3, e.rel_end5, e.rel_end3, e.assignby, e.date, e.m_lend, e.m_rend, h.trusted_cutoff, h.noise_cutoff, h.hmm_com_name, h.iso_type, h.hmm_len, h.ec_num, h.gene_sym, h.trusted_cutoff2, h.noise_cutoff2, h.gathering_cutoff, h.gathering_cutoff2 " .
                "FROM $db..evidence e, egad..hmm2 h " .
                "WHERE e.feat_name = '$gene_id' " .
                "AND e.ev_type = 'HMM2' " .
                "AND h.is_current = 1 " .
                "AND e.accession = h.hmm_acc " .
                "ORDER BY curated, lower(h.hmm_com_name), rel_end5 desc";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_prosite {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }

    my $query = "SELECT e.id, e.accession, e.score, e.curated, e.end5, e.end3, e.rel_end5, e.rel_end3, e.assignby, e.date, p.description, p.hit_precision, p.recall, p.pdoc " .
                "FROM $db..evidence e, common..prosite p " .
                "WHERE e.feat_name = ? " .
                "AND e.ev_type = ? " .
                "AND e.accession = p.accession " .
                "ORDER BY lower(e.accession), e.rel_end5";

    return $self->_get_results_ref($query, $gene_id, "PROSITE");
}

sub get_gene_id_to_signalP { 
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }
    
    my $query = "SELECT o.score, o.score2, o.score3, o.score4, o.score5, o.curated, o.id " .
                "FROM $db..ORF_attribute o " .
                "WHERE o.feat_name = ? ".
	        "AND o.att_type = ? ";

    return $self->_get_results_ref($query, $gene_id, 'SP-HMM');
}

sub get_gene_id_to_targetP { 
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }
    
    my $query = "SELECT o.score, o.score2, o.score3, o.score4, o.score5, o.curated, o.id " .
                "FROM ORF_attribute o " .
                "WHERE o.feat_name = ? ".
	        "AND o.att_type = ? ";

    return $self->_get_results_ref($query, $gene_id, 'targetP');
}

sub get_gene_id_to_BER {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }

    my $query = "SELECT e.id, e.accession, e.rel_end5, e.rel_end3, e.pvalue, e.per_id, e.per_sim, e.curated " .
                "FROM evidence e " .
                "WHERE e.feat_name = ? " .
                "AND e.ev_type = ? " .
                "ORDER BY e.accession ";

    return $self->_get_results_ref($query, $gene_id, 'BER');
}

sub get_gene_id_to_synonyms {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT g.syn_feat_name ".
	        "FROM gene_synonym g ".
		"WHERE g.feat_name = ? ";

    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_transcript {
    my ($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }
    
    my $query = "SELECT a.sequence ".
	        "FROM asm_feature a ".
		"WHERE a.feat_name = ? ";

    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_CDS {
    my ($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }
    
    my $query = "SELECT a.sequence ".
	        "FROM asm_feature a ".
		"WHERE a.feat_name = ? ";

    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_legacy_data {
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }
    
    my $query = "SELECT a.feat_name, a.asmbl_id, '$db' ".
	        "FROM asm_feature a, clone_info c ".
		"WHERE a.feat_name = '$gene_id' ".
		"AND a.asmbl_id = c.asmbl_id ".
		"AND c.is_public = 1 ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_protein {
    my ($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }

    my $query = "SELECT a.protein ".
	        "FROM asm_feature a ".
		"WHERE a.feat_name = ? ";

    return $self->_get_results_ref($query, $gene_id);
 }

sub get_gene_id_to_exons {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a.feat_name, a.end5, a.end3 ".
	        "FROM asm_feature a, feat_link f " .
                "WHERE f.parent_feat = ? " .
                "AND f.child_feat = a.feat_name " .
                "AND a.feat_type = ? ";

    return $self->_get_results_ref($query, $gene_id, 'exon');
}

sub get_gene_id_to_predictions {
    my ($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }
    
    my $query = "SELECT f.feat_name, f.end5, f.end3, p.ev_type ".
	        "FROM feat_link l, phys_ev p, asm_feature f ".
		"WHERE l.parent_feat = ? ".
		"AND l.child_feat = p.feat_name ".
		"AND p.feat_name = f.feat_name ".
		"AND f.feat_type = 'model' ".
		"AND p.ev_type != 'makemodel' ".
		"ORDER BY p.ev_type DESC ";

    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_evidence {
    my ($self, $gene_id, $ev_type, $gene_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }
    
    my $query = "SELECT id, ev_type, accession, end5, end3, rel_end5, rel_end3, m_lend, m_rend, curated, date, assignby, change_log, save_history, method, per_id, per_sim, score, db, pvalue, domain_score, expect_domain, total_score, expect_whole ".
                "FROM evidence ".
		"WHERE feat_name = ? ";
    
    if($ev_type) {
	$query .= "AND LOWER(ev_type) = LOWER('$ev_type') ";
    }

    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_transmembrane_regions {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }    

    my $query = "SELECT o.score2, 'regions', o.score, o.score3, o.score4, o.score5 " .
                "FROM ORF_attribute o " .
                "WHERE o.feat_name = ? ".
		"AND o.att_type = ? ";

    return $self->_get_results_ref($query, $gene_id, 'GES');
}

sub get_gene_id_to_fam_id {
    my ($self, $gene_id, $ev_type, $att_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }    

    my $query = "SELECT o.score " . 
	        "FROM ORF_attribute o " .
                "WHERE o.feat_name = '$gene_id' ".
		"AND o.att_type = '$att_type' ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_partial_gene_toggles { 
    my ($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SELECT score, score2 ".
                "FROM ORF_attribute " .
                "WHERE feat_name = ? ".
		"AND att_type = ? ";

    return $self->_get_results_ref($query, $gene_id, 'is_partial');
}

sub get_gene_id_to_child_id {
    my ($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT child_feat ".
	        "FROM feat_link ".
	        "WHERE parent_feat = ? ";

    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_transposable_element {
    my ($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a.asmbl_id, a.end5, a.end3, a.feat_type ".
	        "FROM asm_feature a ".
	        "WHERE a.feat_name = ? ";
    
    return $self->_get_results_ref($query, $gene_id);
}

sub get_synonym_to_gene_id {
    my($self, $syn_feat_name) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT g.feat_name ".
		"FROM gene_synonym g ".
		"WHERE g.syn_feat_name = ? ";

    return $self->_get_results_ref($query, $syn_feat_name);
}

sub get_gene_id_to_evidence2 {
    my($self, $gene_id, $ev_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT e.accession, e.rel_end5, e.rel_end3, pvalue ".
                "FROM evidence e ".
		"WHERE e.feat_name = ? ";
    if($ev_type) {
	$query .= "AND e.ev_type = '$ev_type' ";
    }
    
    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_COG {
    my($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT e.accession, e.rel_end5, e.rel_end3, pvalue ".
                "FROM $db..evidence e ".
		"WHERE e.feat_name = '$gene_id' ".
		"AND e.ev_type = 'COG accession' ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_COG_curation {
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }
    
    my $query = "SELECT o.score, o.score2, o.score3, o.curated, o.id ".
                "FROM $db..ORF_attribute o ".
                "WHERE o.feat_name = ? ".
	        "AND o.att_type = ? ";

    return $self->_get_results_ref($query, $gene_id, 'COG_curation');
}

sub get_gene_id_to_lipoprotein {
    return undef;
}

sub get_gene_id_to_outer_membrane_protein {
    return undef;
}

sub get_handle_gene_id {
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    #
    # If gene_id = TU, get model gene_id
    if ($gene_id =~ /([0-9]+)\.t/) {
	
	my $query = "SELECT f2.feat_name " .
                    "FROM $db..asm_feature f2, $db..feat_link l, $db..phys_ev p " .
                    "WHERE l.parent_feat = ? " .
                    "AND l.child_feat = f2.feat_name " .
                    "AND f2.feat_type = ? " .
                    "AND f2.feat_name = p.feat_name " .
                    "AND p.ev_type = ?";
	
	my $res = $self->_get_results_ref($query, $gene_id, 'model', 'working');
	return $res->[0][0];
    }
    #
    # Else if gene_id = model, get TU gene_id
    elsif ($gene_id =~ /([0-9]+)\.m/) {

	my $query = "SELECT f2.feat_name " .
	            "FROM $db..asm_feature f, $db..asm_feature f2, $db..feat_link l " .
                    "WHERE f.asmbl_id = f2.asmbl_id " .
                    "AND f.feat_name = ? " .
                    "AND f.feat_type = ? " .
                    "AND f.feat_name = l.child_feat " .
                    "AND l.parent_feat = f2.feat_name " .
                    "AND f2.feat_type = ? ";
	
	my $res = $self->_get_results_ref($query, $gene_id, 'model', 'TU');
	return $res->[0][0];
    }
}

sub get_gene_id_to_nucleotide_evidence {
    my ($self, $gene_id, $ev_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }
    
    my $query = "SELECT id, ev_type, accession, end5, end3, rel_end5, rel_end3, m_lend, m_rend, curated, date, assignby, change_log, save_history, method, per_id, per_sim, score, db, pvalue, domain_score, expect_domain, total_score, expect_whole ".
                "FROM evidence ".
		"WHERE feat_name = '$gene_id' ";
    
    if($ev_type) {
	$query .= "AND LOWER(ev_type) = LOWER('$ev_type') ";
    }
    $query .= "ORDER BY accession, end5 ";
    
    return $self->_get_results_ref($query);
}

sub get_gene_id_to_prints {
    my($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
 
    my $query = "SELECT id, ev_type, accession, end5, end3, rel_end5, rel_end3, m_lend, m_rend, curated, date, assignby, change_log, save_history, method ".
                "FROM evidence " .
                "WHERE feat_name = '$gene_id' ".
		"AND ev_type = 'FPrintScan' ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_prodom {
    my($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT id, ev_type, accession, end5, end3, rel_end5, rel_end3, m_lend, m_rend, curated, date, assignby, change_log, save_history, method ".
                "FROM evidence " .
                "WHERE feat_name = '$gene_id' ".
		"AND ev_type = 'BlastProDom' ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_profiles {
    my($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT id, ev_type, accession, end5, end3, rel_end5, rel_end3, m_lend, m_rend, curated, date, assignby, change_log, save_history, method ".
                "FROM evidence " .
                "WHERE feat_name = '$gene_id' ".
		"AND ev_type = 'ProfileScan' ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_ec_numbers {
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
 
    my $query = "SELECT x.ident_val ".
	        "FROM $db..ident_xref x ".
		"WHERE x.feat_name = '$gene_id' ".
		"AND x.xref_type = 'ec number' ".
		"AND x.relrank = 1 ";    

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_curated_structure { 
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }

    my $query = "SELECT a.curated ".
	        "FROM $db..asm_feature a, $db..clone_info c ".
		"WHERE a.feat_name = '$gene_id' ".
		"AND a.feat_type = 'model' ".
		"AND a.asmbl_id = c.asmbl_id ".
		"AND c.is_public = 1 ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_curated_annotation { 
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }

    my $query = "SELECT a.curated ".
	        "FROM $db..asm_feature a, $db..clone_info c ".
		"WHERE a.feat_name = '$gene_id' ".
		"AND a.feat_type = 'TU' ".
		"AND a.asmbl_id = c.asmbl_id ".
		"AND c.is_public = 1 ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_pseudogene_toggle { 
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }

    my $query = "SELECT i.is_pseudogene ".
	        "FROM $db..ident i, $db..clone_info c, $db..asm_feature a, $db..feat_link l, $db..phys_ev p ".
		"WHERE i.feat_name = '$gene_id' ".
		"AND i.feat_name = l.parent_feat ".
		"AND l.child_feat = a.feat_name ".
		"AND a.feat_type = 'model' ".
		"AND a.feat_name = p.feat_name ".
		"AND p.ev_type = 'working' ".
		"AND a.asmbl_id = c.asmbl_id ".
		"AND c.is_public = 1 ";
		
    return $self->_get_results_ref($query);
}

sub get_gene_id_to_GO {
    my ($self, $gene_id, $db, $GO_id, $assigned_by_exclude, $assigned_by) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id, $db);
    }    

    my $query = "SELECT gr.go_id, type, name, gr.id, gr.date, gr.assigned_by, gr.qualifier " .
                "FROM $db..go_role_link gr, common..go_term gt " .
		"WHERE feat_name = '$gene_id' ";
    if($GO_id) { 
	$query .= "AND gr.go_id = '$GO_id' "; 
    }
    $query .= "AND gt.go_id = gr.go_id ";
    if($assigned_by_exclude) {
	$query .= "AND gr.assigned_by != '$assigned_by_exclude' ";
    }
    if($assigned_by) {
	$query .= "AND gr.assigned_by = '$assigned_by' ";
    }

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_GO_suggestions {
    my ($self, $gene_id, $db1, $db2) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT gi.feat_name, gi.com_name, a.Pvalue " .
                "FROM $db1..ident i, omnium..all_vs_all a, omnium..db_data d, $db2..ident gi " .
                "WHERE i.feat_name = '$gene_id' " .
                "AND a.locus = i.locus " .
	        "AND d.original_db = '$db2' ".
		"AND d.id = a.db_id_acc ".
                "AND gi.locus = a.accession " .
                "ORDER BY a.Pvalue, gi.feat_name";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_GO_evidence {
    my ($self, $gene_id, $GO_id, $id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }

    my $query = "SELECT e.ev_code, e.evidence, e.with_ev ".
	        "FROM $db..go_evidence e ".
		"WHERE e.role_link_id = ? ";

    return $self->_get_results_ref($query, $id);
}

sub get_gene_id_to_roles {
    my ($self, $gene_id, $db) = @_;
    return undef;
}

############################
#^ END GENE_ID INPUT_TYPE ^#
##################################################################





######################
# EXON_ID INPUT_TYPE #
######################

sub get_exon_id_to_CDS {
    my ($self, $exon_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a.feat_name, a.end5, a.end3 ".
                "FROM asm_feature a, feat_link f " .
                "WHERE f.parent_feat = ? " .
                "AND f.child_feat = a.feat_name ".
                "AND a.feat_type = ? ";

    return $self->_get_results_ref($query, $exon_id, 'CDS');
}

############################
#^ END EXON_ID INPUT_TYPE ^#
##################################################################




######################
# ROLE_ID INPUT_TYPE #
######################

sub get_role_id_to_notes {
    my($self, $role_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SELECT notes ".
	        "FROM role_notes ".
		"WHERE role_id = ? ";
    
    return $self->_get_results_ref($query, $role_id);
}

sub get_role_id_to_common_notes {
    my($self, $role_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
 
    my $query = "SELECT r.notes, e.mainrole, e.sub1role " . 
                "FROM common..role_notes r, egad..roles e " .
                "WHERE e.role_id = r.role_id " .
                "AND e.role_id = ? ";

    return $self->_get_results_ref($query, $role_id);
}

############################
#^ END EXON_ID INPUT_TYPE ^#
##################################################################




#####################
# SEQ_ID INPUT_TYPE #
#####################

sub get_seq_id_to_description {
    my ($self, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT clone_id, clone_name, seq_group, orig_annotation, tigr_annotation, status, length, final_asmbl, gb_acc, assignby, date, chromo, is_public, prelim " .
	        "FROM clone_info ".
		"WHERE asmbl_id = ? ".
		"AND is_public = 1 ";

    return $self->_get_results_ref($query, $seq_id);
}

sub get_seq_id_to_transcripts { 
    my ($self, $seq_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a2.feat_name, a2.end5, a2.end3, a1.sequence ".
	        "FROM $db..asm_feature a1, $db..asm_feature a2, $db..phys_ev p, $db..feat_link l, $db..clone_info c ".
	        "WHERE a1.feat_type = 'TU' ".
		"AND a1.asmbl_id = $seq_id  ".
		"AND a2.asmbl_id = $seq_id ".
		"AND a1.feat_name = l.parent_feat ".
		"AND a2.feat_name = l.child_feat ".
		"AND a2.feat_name = p.feat_name ".
		"AND a2.feat_type = 'model' ".
		"AND p.ev_type = 'working' ".
		"AND a1.asmbl_id = c.asmbl_id ".
		"AND c.is_public = 1 ".
		"ORDER BY a1.end5 ";

    return $self->_get_results_ref($query);
}

sub get_seq_id_to_length {
    my ($self, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT length ".
	        "FROM clone_info ".
	        "WHERE asmbl_id = ? ".
		"AND is_public = 1";

    return $self->_get_results_ref($query, $seq_id);
}

sub get_seq_id_to_sequence { 
    my ($self, $seq_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SELECT a.sequence ".
                "FROM assembly a ".
                "WHERE a.asmbl_id = ? ";

    return $self->_get_results_ref($query, $seq_id);
}

sub get_seq_id_to_new_transposable_element_id {
    my ($self, $seq_id, $feat_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SELECT max(feat_name) ".
	        "FROM asm_feature ".
		"WHERE asmbl_id = ? ".
		"AND feat_type = ? ";

    return $self->_get_results_ref($query, $seq_id, $feat_type);
}

###########################
#^ END SEQ_ID INPUT_TYPE ^#
##################################################################





#####################
#   DB INPUT_TYPE   #
#####################

sub get_db_to_seq_description {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT asmbl_id, clone_id, clone_name, seq_group, orig_annotation, tigr_annotation, status, length, final_asmbl, gb_acc, assignby, date, chromo, is_public, prelim " .
                "FROM $db..clone_info ".
		"WHERE is_public = 1 ";

    if($self->get_conditional() > 0) {
	$query .=  "AND asmbl_id != final_asmbl ";
    } 

    if($ENV{RESTRICT_DATA}){
	$query .= "AND license != 2 ";
    }
    $query .= "ORDER BY chromo, asmbl_id ASC ";

    return $self->_get_results_ref($query);
}

sub get_db_to_seq_names {
    my($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT asmbl_id, clone_id, clone_name, seq_group, orig_annotation, tigr_annotation, status, length, final_asmbl, gb_acc, assignby, date, chromo, is_public, prelim " .
	        "FROM $db..clone_info ".
		"WHERE is_public = 1 ";

    return $self->_get_results_ref($query);
}

=item $obj->get_db_to_gene_count($db)

B<Description:> 

Retrieves

B<Parameters:> 

$db - 

B<Returns:> 

Returns

=cut

sub get_db_to_gene_count { 
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT c.asmbl_id, count(a.feat_name) ".
	        "FROM $db..clone_info c, $db..asm_feature a, $db..phys_ev p ".
		"WHERE c.is_public = 1 ".
		"AND c.asmbl_id = a.asmbl_id ".
		"AND a.feat_type = 'model' ".
		"AND a.feat_name = p.feat_name ".
		"AND p.ev_type = 'working' ";
 
    if($self->get_conditional() > 0) {
	$query .=  "AND c.asmbl_id != c.final_asmbl ";
    } 

    if($ENV{RESTRICT_DATA}){
	$query .= "AND c.license != 2 ";
    }
    
    $query .= "GROUP BY c.asmbl_id ".
	      "ORDER BY c.asmbl_id ASC";

    return $self->_get_results_ref($query);
}

sub get_db_to_GO {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a.feat_name, g.go_id ".
	        "FROM $db..go_role_link g, $db..clone_info c, $db..asm_feature a, $db..feat_link l, $db..ident i, $db..phys_ev p ".
		"WHERE c.is_public = 1 ".
		"AND g.feat_name = i.feat_name ".
		"AND i.is_pseudogene = 0 ".
		"AND i.feat_name = l.parent_feat ".
		"AND l.child_feat = a.feat_name ".
		"AND a.feat_type = 'model' ".
		"AND c.asmbl_id = a.asmbl_id ".
		"AND a.feat_name = p.feat_name ".
		"AND p.ev_type = 'working' ";
    
    if($self->get_conditional() > 0) {
	$query .=  "AND c.asmbl_id != c.final_asmbl ";
    }
    else {
	$query .=  "AND c.asmbl_id = c.final_asmbl ";
    }

    
    if($ENV{RESTRICT_DATA}){
	$query .= "AND c.license != 2 ";
    }
    
    return $self->_get_results_ref($query);
}

sub get_db_to_organism_name {
    my($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT name ".
            "FROM common..genomes ".
        "WHERE db = ? ";

    return $self->_get_results_ref($query, $db);
}

#######################
#^ END DB INPUT_TYPE ^#
##################################################################



########################
#   ACC INPUT_TYPE     #
########################

sub get_acc_to_genes {
    my ($self, $acc) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SELECT e.feat_name, i.ident_val ".
                "FROM evidence e, asm_feature a, feat_link l, ident_xref i, clone_info c ".
		"WHERE e.accession = ? ".
		"AND e.feat_name = a.feat_name ".
		"AND a.feat_name = l.child_feat ".
		"AND l.parent_feat = i.feat_name ".
		"AND i.xref_type = 'product name' ".
		"AND i.relrank = 1 ".
		"AND a.asmbl_id = c.asmbl_id ".
		"AND c.is_public = 1 ";

    return $self->_get_results_ref($query, $acc);
}

sub get_HMM_acc_to_description {
    my ($self, $HMM_acc) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT e.hmm_acc, e.hmm_type, e.hmm_name, e.hmm_com_name, e.hmm_len, e.trusted_cutoff, e.noise_cutoff, e.hmm_comment, e.related_hmm, e.author, e.entry_date, e.mod_date, '', e.ec_num, e.avg_score, e.std_dev, e.iso_type, e.private, e.gene_sym, e.reference, e.expanded_name, e.trusted_cutoff2, e.noise_cutoff2, e.iso_id, e.id ".
                "FROM egad..hmm2 e ".
                "WHERE e.hmm_acc = '$HMM_acc' ".
        "AND e.is_current = 1 ";

    return $self->_get_results_ref($query);
}

sub get_HMM_acc_to_scores {
    my ($self, $HMM_acc) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $conditional_count = $self->get_conditional();
    
    my $query = "SELECT e.feat_name, e.id, e.rel_end5, e.rel_end3, e.m_lend, e.m_rend, 143, convert(float,e.total_score) ".
                "FROM evidence e, asm_feature a, clone_info c, ident i, feat_link l ".
		"WHERE i.feat_name = l.parent_feat ".
		"AND l.child_feat = e.feat_name ".
                "AND e.accession = ? " .
		"AND e.ev_type = 'HMM2' ".
		"AND e.feat_name = a.feat_name ".
		"AND a.asmbl_id = c.asmbl_id ".
		"AND c.is_public = 1 ";
    $query .= "AND c.asmbl_id != c.final_asmbl " if($conditional_count > 0);

    if($ENV{RESTRICT_DATA}){
	$query .= "AND c.license != 2 ";
    }    

    $query .= "ORDER BY convert(float, e.total_score) DESC ";

    my $ret = $self->_get_results_ref($query, $HMM_acc);

    my $query = "SELECT e.feat_name, e.id, e.rel_end5, e.rel_end3, e.m_lend, e.m_rend, 51, convert(float,e.domain_score) ".
                "FROM evidence e, asm_feature a, clone_info c, ident i, feat_link l ".
		"WHERE i.feat_name = l.parent_feat ".
		"AND l.child_feat = e.feat_name ".
                "AND e.accession = ? " .
		"AND e.ev_type = 'HMM2' ".
		"AND e.feat_name = a.feat_name ".
		"AND a.asmbl_id = c.asmbl_id ".
		"AND c.is_public = 1 ";
    $query .= "AND c.asmbl_id != c.final_asmbl " if($conditional_count > 0);

    if($ENV{RESTRICT_DATA}){
	$query .= "AND c.license != 2 ";
    }    

    $query .= "ORDER BY convert(float,e.domain_score) DESC ";

    my $ret2 = $self->_get_results_ref($query, $HMM_acc);

    push(@$ret, @$ret2);
    return $ret;
}

sub get_HMM_acc_to_features {
    my ($self, $HMM_acc) = @_;
    my $final_ret;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SELECT DISTINCT e.feat_name " .
                "FROM evidence e, egad..hmm2 h, clone_info c, asm_feature a " .
                "WHERE e.accession = ? " .
                "AND h.hmm_acc = e.accession " .
                "AND h.is_current = 1 ".
		"AND e.feat_name = a.feat_name ".
		"AND a.asmbl_id = c.asmbl_id ".
		"AND c.is_public = 1 ";
    $query .= "AND c.asmbl_id != c.final_asmbl " if($self->get_conditional() > 0);

    if($ENV{RESTRICT_DATA}){
	$query .= "AND c.license != 2 ";
    }    

    my $ret = $self->_get_results_ref($query, $HMM_acc);

    for(my $i=0; $i<@$ret; $i++) {
	#
	# Get primary names and other data from the ident_xref table
	my $ret2 = $self->get_gene_id_to_primary_descriptions($ret->[$i][0]);
	$final_ret->[$i][0] = $ret->[$i][0]; ### gene id
	$final_ret->[$i][1] = $ret2->[0][0]; ### product name
	$final_ret->[$i][2] = $ret2->[0][3]; ### EC number
    }
    return $final_ret;
}

sub get_HMM_acc_to_roles {
    my($self, $HMM_acc) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

	# remove version number if it exists; hmm_go_link does not use version numbers yet
	if($HMM_acc =~ /\./) {
		$HMM_acc =~ s/\.(.*)//g;
	}

    my $query = "SELECT e.role_id, r.mainrole, r.sub1role ".
            "FROM egad..hmm_role_link e, egad..roles r ".
        "WHERE e.hmm_acc = '$HMM_acc' ".
        "AND e.role_id = r.role_id ";

    return $self->_get_results_ref($query);
}

########################
#^ END ACC INPUT_TYPE ^#
##################################################################




######################
#  INSERT FUNCTIONS  #
######################

sub do_insert_role {
    my ($self, $gene_id, $role_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    return undef;
}

sub do_insert_evidence {
    my ($self, $gene_id, $acc, $type, $coords_ref, $scores_ref, $curated) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "INSERT evidence (feat_name, ev_type, accession, end5, end3, rel_end5, rel_end3, m_lend, m_rend, curated, date, assignby, change_log, save_history, method, per_id, per_sim, score, db, pvalue) " .
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, $curated, getdate(), '$self->{_user}', 1, 1, 'Manatee', ?, ?, ?, ?, ?)";
    
    $self->_set_values($query, 
		       $gene_id, 
		       $type, 
		       $acc, 
		       $coords_ref->{'end5'}, 
		       $coords_ref->{'end3'},
		       $coords_ref->{'rel_end5'}, 
		       $coords_ref->{'rel_end3'},
		       $coords_ref->{'m_lend'}, 
		       $coords_ref->{'m_rend'},
		       $scores_ref->{'per_id'},
		       $scores_ref->{'per_sim'},
		       $scores_ref->{'score'},
		       $scores_ref->{'db'},
		       $scores_ref->{'pvalue'});
}

sub do_insert_ident_xref {
    my ($self, $gene_id, $xref_type, $ident_val, $relrank, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "";

    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id, $db);
    }

    if(!$relrank) {
	$relrank = 1;
    }

    if($xref_type eq "gene name" && $ident_val ne "") {
	$query = "INSERT $db..ident_xref (feat_name, xref_id, ident_val, xref_type, method, mod_date, assignby, relrank) ".
	         "VALUES ('$gene_id', 0, \"$ident_val\", 'gene name', 'Manatee', getdate(), '$self->{_user}', $relrank) ";
	$self->_set_values($query);
    }
    
    if($xref_type eq "product name" && $ident_val ne "") {
	$query = "INSERT $db..ident_xref (feat_name, xref_id, ident_val, xref_type, method, mod_date, assignby, relrank) ".
	         "VALUES ('$gene_id', 0, \"$ident_val\", 'product name', 'Manatee', getdate(), '$self->{_user}', $relrank) ";
	$self->_set_values($query);
    }
    
    if($xref_type eq "gene symbol" && $ident_val ne "") {
	$query = "INSERT $db..ident_xref (feat_name, xref_id, ident_val, xref_type, method, mod_date, assignby, relrank) ".
	         "VALUES ('$gene_id', 0, \"$ident_val\", 'gene symbol', 'Manatee', getdate(), '$self->{_user}', $relrank) ";
	$self->_set_values($query);
    }
    
    if($xref_type eq "ec number" && $ident_val ne "") {
	$query = "INSERT $db..ident_xref (feat_name, xref_id, ident_val, xref_type, method, mod_date, assignby, relrank) ".
	         "VALUES ('$gene_id', 0, \"$ident_val\", 'ec number', 'Manatee', getdate(), '$self->{_user}', $relrank) ";
	$self->_set_values($query);
    }
}

sub do_insert_asm_feature {
    my ($self, $feat_ref) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $qw = sub { $self->qw_string_or_null(@_) };
    my $nn = sub { $self->num_or_null(@_) }; ## aliases for clumsy names.

    my $query = "INSERT asm_feature (feat_type, feat_class, feat_method, end5, end3, comment, assignby, date, sequence, protein, feat_name, lock_id, asmbl_id, parent_id, change_log, save_history, is_gb, db_xref, pub_comment, curated) ".
	        "VALUES (";
    
    $query .= $qw->($feat_ref->{'feat_type'}) . "," . 
	      $qw->($feat_ref->{'feat_class'}) . "," . 
	      $qw->($feat_ref->{'method'}) . "," .
	      $nn->($feat_ref->{'end5'}) . "," . 
	      $nn->($feat_ref->{'end3'}) . "," . 
	      $qw->($feat_ref->{'comment'}) . "," .
	      $qw->($self->{_user}) . "," . 
	      "getdate()" . "," . 
	      $qw->($feat_ref->{'sequence'}) . "," .
              $qw->($feat_ref->{'protein'}) . "," . 
	      $qw->($feat_ref->{'gene_id'}) . "," . 
	      $nn->($feat_ref->{'lock_id'}) . "," .
              $nn->($feat_ref->{'seq_id'}) . "," . 
	      $nn->($feat_ref->{'parent_id'}) . "," . 
	      $nn->($feat_ref->{'change_log'}) . "," .
              $nn->($feat_ref->{'save_history'}) . "," . 
	      $nn->($feat_ref->{'is_gb'}) . "," . 
	      $qw->($feat_ref->{'db_xref'}) . "," .
              $qw->($feat_ref->{'pub_comment'}) . "," . 
	      $nn->($feat_ref->{'curated'}) . ")";

    $self->_set_values($query);
}

sub do_insert_feat_link {
    my ($self, $parent_id, $child_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "INSERT feat_link (parent_feat, child_feat, assignby, datestamp) " .
                "VALUES (\"$parent_id\", \"$child_id\", \"$self->{_user}\", getdate())";
    
    $self->_set_values($query);
}

##########################
#^ END INSERT FUNCTIONS ^#
##################################################################






######################
#  UPDATE FUNCTIONS  #
######################

sub do_update_ident_xref {
    my ($self, $gene_id, $xref_type, $ident_val, $relrank, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id, $db);
    }
    
    if(!$relrank) {
	$relrank = 1;
    }

    my $query = "UPDATE $db..ident_xref ".
	        "SET mod_date = getdate(), assignby = ?, ident_val = \"$ident_val\" ".
	        "WHERE feat_name = ? ".
	        "AND relrank = ? ".
	        "AND xref_type = ? ";	
    $self->_set_values($query, $self->{_user}, $gene_id, $relrank, $xref_type);
}

sub do_update_aliases {
    my ($self, $gene_id, $hash_ref, $db) = @_;

    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id, $db);
    }

    ################
    # create and execute query for each id.
    ################
    foreach my $i (sort keys %$hash_ref) {

	my $query = "";
	### delete row if name is empty ###
	if($hash_ref->{$i}->{'name'} eq "") {
	    $query = "DELETE $db..ident_xref ".
		     "WHERE feat_name = '$gene_id' ".
		     "AND id = $i ";
	}
	### else, update the row ###
	else {
	    $query = "UPDATE $db..ident_xref ".
	             "SET mod_date = getdate(), assignby = '$self->{_user}', ident_val = \"$hash_ref->{$i}->{'name'}\" ".
		     "WHERE feat_name = '$gene_id' ".
		     "AND relrank = 2 ".
		     "AND id = $i ";
	}
	$self->_set_values($query);
    }
}

sub do_update_5prime_partial {
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }

    #
    # Determine if an is_partial row already exists.
    my $query = "SELECT feat_name, score ".
                "FROM ORF_attribute " .
                "WHERE feat_name = ? ".
		"AND att_type = ? ";

    my $ret = $self->_get_results_ref($query, $gene_id, 'is_partial');
    my $has_rows = @$ret;
    my $new = $ret->[0][1];
    my $curated = ($new == 0) ? 1 : 0;
    
    #
    # Insert the is_partial row if one does not already exist.
    if(!$has_rows) {
	my $query2 = "INSERT INTO ORF_attribute ".
	             "(feat_name, att_type, curated, method, date, assignby, score, score2, score_desc, score2_desc) ".
		     "VALUES ".
		     "('$gene_id', 'is_partial', 0, 'Manatee', getdate(), '$self->{_user}', '$curated', '0', \"5' partial\", \"3' partial\") ";
	
	$self->_set_values($query2);
    }
    else {
	my $query3 = "UPDATE ORF_attribute ".
		     "SET score = ? ".
		     "WHERE feat_name = ? ".
		     "AND att_type = ? ";
	
	$self->_set_values($query3, $curated, $gene_id, 'is_partial');
    }
}

sub do_update_3prime_partial {
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }
    
    #
    # Determine if an is_partial row already exists.
    my $query = "SELECT feat_name, score2 ".
                "FROM ORF_attribute " .
                "WHERE feat_name = ? ".
		"AND att_type = ? ";
    
    my $ret = $self->_get_results_ref($query, $gene_id, 'is_partial');
    my $has_rows = @$ret;
    my $new = $ret->[0][1];
    my $curated = ($new == 0) ? 1 : 0;

    #
    # Insert the is_partial row if one does not already exist.
    if(!$has_rows) {
	my $query2 = "INSERT INTO ORF_attribute ".
	             "(feat_name, att_type, curated, method, date, assignby, score, score2, score_desc, score2_desc) ".
		     "VALUES ".
		     "('$gene_id', 'is_partial', 0, 'Manatee', getdate(), '$self->{_user}', '0', '$curated', \"5' partial\", \"3' partial\") ";

	$self->_set_values($query2);
    }
    else {
	my $query3 = "UPDATE ORF_attribute ".
	             "SET score2 = ? ".
		     "WHERE feat_name = ? ".
		     "AND att_type = ? ";

	$self->_set_values($query3, $curated, $gene_id, 'is_partial');
    }
}

sub do_update_asm_feature {
    my ($self, $gene_id, $feat_ref) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "UPDATE asm_feature SET ";
    
    if (defined($feat_ref->{'change_log'})) {
        $query .= "change_log = $feat_ref->{'change_log'},";
    }
    if (defined($feat_ref->{'save_history'})) {
        $query .= "save_history = $feat_ref->{'save_history'},";
    }
    if ($feat_ref->{'feat_type'}) {
        $query .= "feat_type = \"$feat_ref->{'feat_type'}\",";
    }
    if ($feat_ref->{'feat_class'}) {
        $query .= "feat_class = \"$feat_ref->{'feat_class'}\",";
    }
    if ($feat_ref->{'feat_method'}) {
        $query .= "feat_method = \"$feat_ref->{'feat_method'}\",";
    } 
    if (defined ($feat_ref->{'end5'})) {
        $query .= "end5 = $feat_ref->{'end5'},";
    }
    if (defined($feat_ref->{'end3'})) {
        $query .= "end3 = $feat_ref->{'end3'},";
    }
    if ($feat_ref->{'comment'}) {
        $query .= "comment = \"$feat_ref->{'comment'}\",";
    }
    if ($feat_ref->{'sequence'}) {
        $query .= "sequence = \"$feat_ref->{'sequence'}\",";
    }
    if ($feat_ref->{'protein'}) {
        $query .= "protein = \"$feat_ref->{'protein'}\",";
    }
    if (defined($feat_ref->{'lock_id'})) {
        $query .= "lock_id = $feat_ref->{'lock_id'},";
    }
    if (defined($feat_ref->{'asmbl_id'})) {
        $query .= "asmbl_id = $feat_ref->{'asmbl_id'},";
    }
    if (defined($feat_ref->{'parent_id'})) {
        $query .= "parent_id = $feat_ref->{'parent_id'},";
    }
    if (defined($feat_ref->{'is_gb'})) {
        $query .= "is_gb = $feat_ref->{'is_gb'},";
    }
    if ($feat_ref->{'db_xref'}) {
        $query .= "db_xref = \"$feat_ref->{'db_xref'}\",";
    }
    if ($feat_ref->{'pub_comment'}) {
        $query .= "pub_comment = \"$feat_ref->{'pub_comment'}\",";
    }
    if (defined($feat_ref->{'curated'})) {
        $query .= "curated = $feat_ref->{'curated'},";
    }
    ## always set assignby
    $query .= "assignby = \"$self->{_user}\" ";
    $query .= "WHERE feat_name = ? ";

    $self->_set_values($query, $gene_id);
}

sub do_update_ident {
    my ($self, $gene_id, $identref, $xref, $changeref, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $identref->{'assignby'} = $self->{_user};
    
    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id, $db);
    }
    
    my $query = "UPDATE $db..ident SET ".
	        "date = getdate(), save_history = 1 ";

    foreach my $field (sort keys %$identref) {
	#
	# Put quotes around values unless value = "NULL".
	if ($field eq "is_pseudogene") {
	    $identref->{$field} = $identref->{$field};
	}
	elsif ($identref->{$field} ne "NULL") {
	    $identref->{$field} = "\"$identref->{$field}\"";	    
	}
	
	#
	# Create query snippet if $fields value is defined.
	if (defined $identref->{$field}) {
	    $query .= ", $field = ". $identref->{$field} ." ";
	}
    }
    $query .= "WHERE feat_name = ? ";

    $self->_set_values($query, $gene_id);
    return $gene_id;
}


sub do_update_pseudogene_toggle {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id, $db);
    }

    my $query = "SELECT is_pseudogene ".
	        "FROM $db..ident ".
	        "WHERE feat_name = '$gene_id' ";

    my $x =  $self->_get_results_ref($query);
    my $curation = $x->[0][0];
    my $new = ($curation == 0) ? 1 : 0;

    my $query = "UPDATE $db..ident SET is_pseudogene = $new ".
	        "WHERE  feat_name = '$gene_id' ";

    $self->_set_values($query);
}

sub do_update_gene_curation {
    my ($self, $gene_id, $curated_type, $curated, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    if($gene_id !~ /\d+\.m\d+/ && $curated_type eq "structure") {
	$gene_id = $self->get_handle_gene_id($gene_id, $db);
    }
    elsif($gene_id !~ /\d+\.t\d+/ && $curated_type eq "annotation") {
	$gene_id = $self->get_handle_gene_id($gene_id, $db);
    }

    my $query = "UPDATE $db..asm_feature ".
	        "SET curated = $curated ".
		"WHERE feat_name = '$gene_id' ";

    $self->_set_values($query);
}

##########################
#^ END UPDATE FUNCTIONS ^#
##################################################################





######################
#  DELETE FUNCTIONS  #
######################

sub do_delete_ident_xref {
    my ($self, $gene_id, $xref_type, $relrank, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id, $db);
    }
    
    my $query = "DELETE $db..ident_xref ".
	        "WHERE feat_name = ? ".
	        "AND relrank = ? ".
	        "AND xref_type = ? ";

    $self->_set_values($query, $gene_id, $relrank, $xref_type);
}

sub do_delete_ident {
    my ($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }
    
    my $query = "DELETE ident ".
	        "WHERE feat_name = ? ";

    $self->_set_values($query, $gene_id);
}

sub do_delete_partials {
    my ($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.m\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }
    
    my $query = "DELETE ORF_attribute ".
		"WHERE feat_name = ? ".
		"AND att_type = ? ";
    
    $self->_set_values($query, $gene_id, 'is_partial');
}

sub do_delete_asm_feature {
    my ($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE ".
	        "FROM asm_feature ".
	        "WHERE feat_name = ? ";

    $self->_set_values($query, $gene_id);
}

sub do_delete_feat_link {
    my ($self, $parent_id, $child_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE ".
	        "FROM feat_link ".
		"WHERE parent_feat = ? ".
		"AND child_feat = ? ";
    
    $self->_set_values($query, $parent_id, $child_id);
}

sub do_delete_evidence {
    my ($self, $gene_id, $acc, $type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE FROM evidence ".
                "WHERE feat_name = ? ".
                "AND accession = ? ".
                "AND ev_type = ?";

    $self->_set_values($query, $gene_id, $acc, $type);
}

sub do_delete_role {
    my ($self, $gene_id, $role_id, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    return undef;
}

sub do_insert_GO_id {
    my ($self, $gene_id, $GO_id, $qualifier, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id, $db);
    }    

    my $query = "INSERT $db..go_role_link (feat_name, go_id, assigned_by, date, qualifier) ".
                "VALUES (?, ?, ?, getdate(), ?)";
    
    $self->_set_values($query, $gene_id, $GO_id, $self->{_user}, $qualifier);
} 

sub do_insert_GO_evidence {
    my ($self, $gene_id, $GO_id, $ev_code, $evidence, $with, $qualifier, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }    

    my $ret = $self->get_gene_id_to_GO($gene_id, $db, $GO_id);
    my $evidence_id;
    for(my $i=0; $i<@$ret; $i++) {

	if($GO_id eq $ret->[$i][0]) {
	    $evidence_id = $ret->[$i][3];
	}
    }
    
    if(!$evidence_id) {
	warn "Unable to add GO evidence. Make go assignment first\n";		
    }
    else {
	
	#####################
	# Set $evidence value to NULL if empty
	#####################
	if($evidence eq "") {
	    $evidence = 'NULL';
	}
	
	#####################
	# Set $with value to NULL if empty
	#####################		
	if($with eq "") {
	    $with = 'NULL';
	}
	
	##################
	# Build the query.
	##################
	my $query = "INSERT $db..go_evidence (role_link_id, ev_code, evidence, with_ev) ". 
	            "VALUES ($evidence_id, '$ev_code', ";
	
	if($evidence eq "NULL") {
	    $query .= $evidence .", ";
	} 
	else {
	    $query .= "\'$evidence\', ";
	}
	
	if($with eq "NULL") {
	    $query .= $with;
	} 
	else {
	    $query .= "\'$with\'";
	}
	
	$query .= ")";

	$self->_set_values($query);

	#####################
	# update assigned_by
	#####################
	$query  = "UPDATE $db..go_role_link ".
	          "SET assigned_by = '$self->{_user}', date = getdate(), ";
	$query .= "qualifier = NULL " if($qualifier eq "");
	$query .= "qualifier = '$qualifier' " if($qualifier ne "");
	$query .= "WHERE go_id = '$GO_id' ".
	          "AND feat_name = '$gene_id' ".
		  "AND id = $evidence_id ";

        $self->_set_values($query);
    }
}

sub do_delete_GO_id {
    my ($self, $gene_id, $GO_id, $assigned_by_exclude, $db, $ev_code, $assigned_by) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id, $db);
    }    
    
    my $ret = $self->get_gene_id_to_GO($gene_id, $db, $GO_id, $assigned_by_exclude, $assigned_by);
    
    for(my $i=0; $i<@$ret; $i++) {
	if($GO_id eq $ret->[$i][0]) {
	    my $evidence_id = $ret->[$i][3];
	    
	    my $query = "DELETE FROM $db..go_evidence ".
		        "WHERE role_link_id = ? ";
	    if($ev_code){
		$query .= "AND ev_code = '$ev_code' ";
	    }
	    
	    $self->_set_values($query, $evidence_id);
	}
    }

    my $query = "SELECT e.ev_code, e.evidence " .
	"FROM $db..go_evidence e, $db..go_role_link l " .
	"WHERE l.go_id = ? AND l.feat_name = ? and l.id = e.role_link_id ";
    my $r = $self->_get_results_ref($query, $GO_id, $gene_id);

    if(!@$r){
	my $query = "DELETE from $db..go_role_link ".
	    "WHERE feat_name = ? ".
	    "AND go_id = ? ";
	
	if($assigned_by_exclude) {
	    $query .= "AND assigned_by != '$assigned_by_exclude' ";
	}
	if($assigned_by) {
	    $query .= "AND assigned_by = '$assigned_by' ";
	}
	$self->_set_values($query, $gene_id, $GO_id);
    }
}

sub do_delete_GO_evidence {
    my ($self, $gene_id, $GO_id, $assigned_by_exclude, $db, $assigned_by) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.t\d+/) {
	$gene_id = $self->get_handle_gene_id($gene_id);
    }    

    my $ret = $self->get_gene_id_to_GO($gene_id, $db, $GO_id, $assigned_by_exclude);
    
    for(my $i=0; $i<@$ret; $i++) {
	
	if($GO_id eq $ret->[$i][0]) {
	    my $evidence_id = $ret->[$i][3];
	    
	    my $query = "DELETE FROM $db..go_evidence ".
		        "WHERE role_link_id = ? ";
	    
	    $self->_set_values($query, $evidence_id);

	    $query = "UPDATE $db..go_role_link ".
		"SET qualifier = NULL ".
		"WHERE go_id = '$GO_id' ".
		"AND feat_name = '$gene_id' ";
	    $query .= "AND assigned_by = '$assigned_by' " if ($assigned_by);

	    $self->_set_values($query);
	}
    }
}

##########################
#^ END DELETE FUNCTIONS ^#
##################################################################





############################
#     MISC INPUT_TYPE      #
############################

sub get_handle_btab_names {
    my ($self, $seq_id, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = uc($db);

    my $btab_file = sprintf("%s/%s/asmbls/%s/BER_searches/CURRENT/%s.nr.btab",
			    $ENV{ANNOTATION_DIR},
			    $db,
			    $seq_id,
			    $gene_id);

    my $btab_dir = sprintf("%s/%s/asmbls/%s/BER_searches/CURRENT",
			   $ENV{ANNOTATION_DIR},
			   $db,
			   $seq_id);
    return ($btab_file, $btab_dir);
}

sub get_handle_btab_names2 {
    my ($self, $seq_id, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = uc($db);
    my $btab_file = "";
    
    #### get BER file location (hard coded for Tryp annotation jamboree)
    #### this will have to be dealt with at a later date -- tcreasy, 04/05/200
    if($db eq "TBA1" || $db eq "LMA1" || $db eq "TCA1") {
	$btab_file = sprintf("%s/%s/asmbls/%s/BER_searches/TriTryp.v3.pep/%s.nr.btab",
			     $ENV{ANNOTATION_DIR},
			     $db,
			     $seq_id,
			     $gene_id);
    }
    else {
	$btab_file = sprintf("%s/%s/asmbls/%s/BER_searches/CURRENT/%s.nr.btab",
			     $ENV{ANNOTATION_DIR},
			     $db,
			     $seq_id,
			     $gene_id);
    }
    return $btab_file;
}

sub get_handle_blast_names {
    my ($self, $seq_id, $gene_id, $db) = @_;
    my ($blast_modif_date);
    my $blast_file = "";
    $db = uc($db);
    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    #
    # This is put in place b/c of directory limit on the Solaris machines on the
    # external webservers.  If the "split" directory exists under the "asmbls" 
    # directory, then this will drill down into the split directories.
    my $dir = sprintf("%s/%s/split/asmbls", $ENV{ANNOTATION_DIR}, $db);
    if(-e $dir) {
	my $cmd = "ls $dir";
	open(CMD, "$cmd |");
	while(<CMD>) {
	    chomp;
	    my $blast_dir = "$dir/$_/$seq_id";
	    if(-e $blast_dir) {
		$blast_file = sprintf("$dir/$_/$seq_id/blastp/%s.nr", $gene_id);
	    }
	}
	close CMD;
    }
    else {
	$blast_file = sprintf("%s/%s/asmbls/%s/blastp/%s.nr", $ENV{ANNOTATION_DIR}, $db, $seq_id, $gene_id);
    }
    
    if(!-e($blast_file) && -e($blast_file . ".gz")) { 
	$blast_modif_date = (stat($blast_file.".gz"))[9];
    } 
    else {
	$blast_modif_date = (stat($blast_file))[9];
    }
    
    my $blast_file_date = localtime($blast_modif_date);
    
    
    #
    # Retrieve custom blast results
    my @custom_blasts;
    my $custom_dir = sprintf("%s/%s/asmbls/%s/custom_BLAST",
			     $ENV{ANNOTATION_DIR}, $db, $seq_id);
    my $cmd = "ls $custom_dir";
    open(CMD, "$cmd |");
    while (<CMD>) {
	chomp;
	my $custom_file = $custom_dir . "/$_/$gene_id.nr";
	push(@custom_blasts, {'CUSTOM_FILE'=>$custom_file,
			      'CUSTOM_NAME'=>$_});
    }
    close CMD;
    return($blast_file, $blast_modif_date, $blast_file_date, \@custom_blasts);
}

sub get_signalP_file_name {
    my ($self, $seq_id, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    return sprintf("%s/%s/asmbls/%s/signalP/sigp.%s.gz", $ENV{ANNOTATION_DIR}, uc($db), $seq_id, $gene_id);
}

sub get_previous_sigP_results {
    my ($self, $seq_id, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $path = sprintf("$ENV{ANNOTATION_DIR}/%s/asmbls/%s/signalP/sigp.%s.gz",
		       uc($db), 
		       $seq_id, 
		       $gene_id);
    return $path;
} 

sub qw_string_or_null {
    my ($self, $string) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    if ($string) {
        return "\"$string\"";
    } 
    else {
        return "NULL";
    }
} 

sub num_or_null {
    my ($self, $num) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    if (defined($num)) {
        return $num;
    } 
    else {
        return "NULL";
    }
}

sub _boolean2SQL{
    my($self, $searchstr,$field) = @_;
    my($query);
    #
    # The following code was taken from an e2k1 script written by LAU
    $searchstr =~ s/[\s\t\,]+/ /g;
    $searchstr =~ tr/[A-Z]/[a-z]/; 
    my @name = split(/\s/, $searchstr);
    
    my $number = $#name;
    shift(@name) until ( ( $name[0] ne "" ) 
			 && (  $name[0] ne "or" ) && ( $name[0] ne "and") );
    
    $query .= " AND ";
    
    for (my $i = 0; $i <= $#name; $i++) {
	my $oper;
	my $like = " LIKE ";
	if ( $name[$i] eq "or" ) {                        ## A or 
	    if ( $name[$i+1] eq "not") {
		$i += 2;                                  ## let the not handle it
		$oper = " OR ";
		$like = " NOT LIKE ";
	    }
	    else {
		$oper = " OR ";
		$i++;
	    }
	}
	elsif ( $name[$i] eq "and" ) {
	    if ( $name[$i+1] eq "not") {
		$i += 2;                                  ## let the not handle it
		$oper = " AND ";
		$like = " NOT LIKE ";
	    }
	    else {
		$oper = " AND ";
		$i++;
	    }
	}
	elsif ( $name[$i] eq "not" ) {
	    if ( $name[$i-1] eq "and") {                  ## AND NOT
		$oper = " AND ";
		$i++;
	    }
	    elsif ( $name[$i-1] eq "or") {	              ## OR NOT
		$oper = " OR ";
		$i++;
	    }
	    elsif ($i == 0)	{	                      ## Not protein
		$oper = " ";
		$i++;
	    }
	    else {			                      ## A not B, default	
		$oper = " AND ";
		$i++;
	    }
	    
	    $like = " NOT LIKE ";
	}
	else {                                            ## default, and AND, like
	    if ( $i == 0 ) {
		$oper = "";
	    }
	    else {
		$oper = " AND ";
	    }
	}
	
	$query .= $oper . "(upper($field) $like upper(\"%$name[$i]%\"))\n";
    }
    return $query;
}

sub do_update_auto_annotate {
    my ($self, $gene_id, $db) = @_;
    return undef;
}

##########################
#^ END MISC INPUT_TYPES ^#
##################################################################

sub get_GO_id_to_term {
    my($self, $GO_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT go_id, name, type, definition " .
                "FROM common..go_term " .
                "WHERE go_id = '$GO_id' ";

    return $self->_get_results_ref($query);
}

###################################

1;
