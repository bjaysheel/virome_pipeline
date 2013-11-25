package Coati::Coati::ProkCoatiDB;

use strict;
use base qw(Coati::Coati::CoatiDB);

###################################



######################
# GENE_ID INPUT_TYPE #
######################

sub get_gene_id_to_description {
    my($self, $gene_id, $db) = @_;

    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT i.feat_name, i.locus, i.comment, i.pub_comment, i.auto_comment, i.nt_comment, i.date, i.locus, '', i.start_edit, i.complete, i.auto_annotate, a.end5, a.end3, 0 as strand, a.sequence, a.protein, a.asmbl_id, a.sec_struct, '', '', a.feat_type, i.com_name, i.com_name, i.gene_sym, i.ec#, datalength(a.sequence), datalength(a.protein), '', i.feat_name, '', '', ad.name ".
                "FROM $db..ident i, $db..asm_feature a, $db..stan s, $db..asmbl_data ad " .
		"WHERE i.feat_name = '$gene_id' ".
		"AND i.feat_name = a.feat_name ".
		"AND a.asmbl_id = s.asmbl_id ".
		"AND s.iscurrent = 1 ".
		"AND s.asmbl_data_id = ad.id ";

    my $res = $self->_get_results_ref($query);
 
    for(my $i=0; $i<@$res; $i++) {
	if($res->[$i][16] eq "") {
	    $res->[$i][27] = "No Translation";
	}
    }
    return $res;
}

sub get_gene_id_to_transmembrane_regions {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT s1.score, s2.score ".
                "FROM  $db..ORF_attribute a, $db..feat_score s1, $db..feat_score s2 " .
                "WHERE feat_name = '$gene_id' " .
                "AND a.id = s1.input_id " .
                "AND a.id = s2.input_id " .
                "AND s1.score_id = 30201 " .
		"AND s2.score_id = 32 "; 

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_lipoprotein {
    my($self, $gene_id,$db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT f.score ".
                "FROM $db..feat_score f, $db..ORF_attribute o ".
                "WHERE o.feat_name = ? ".
                "AND f.input_id = o.id ".
                "AND f.score_id = ? "; 

    return $self->_get_results_ref($query, $gene_id, 35);
}

sub get_gene_id_to_outer_membrane_protein {
    my($self, $gene_id,$db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT f.score ".
                "FROM $db..feat_score f, $db..ORF_attribute o ".
                "WHERE o.feat_name = ? ".
                "AND f.input_id = o.id ".
                "AND f.score_id = ? "; 
    
    return $self->_get_results_ref($query, $gene_id, 15);
}

sub get_gene_id_to_signalP { 
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;


    my @results;
    my @final;
    my @score_ids = (40206, 40204, 40205, 24, 25, 27, 33, 28);
    
    for(my $i=0; $i<@score_ids; $i++) {
	my $query = "SELECT f.score ".
	            "FROM $db..feat_score f, $db..ORF_attribute o ".
		    "WHERE o.feat_name = '$gene_id ' ".
		    "AND o.id = f.input_id ".
		    "AND f.score_id = $score_ids[$i] ";

	my $r = $self->_get_results_ref($query);
	$final[$i] = $r->[0][0];
    }
    
    my $query = "SELECT o.curated ".
	        "FROM $db..ORF_attribute o ".
		"WHERE o.feat_name = '$gene_id '";
    my $ret = $self->_get_results_ref($query);
    
    $results[0][0] = $final[0];
    $results[0][1] = "";
    $results[0][2] = $final[1];
    $results[0][3] = "";
    $results[0][4] = $final[2];
    $results[0][5] = $ret->[0][0];
    $results[0][6] = "";
    $results[0][7] = $final[3];
    $results[0][8] = $final[4];
    $results[0][9] = $final[5];
    $results[0][10] = $final[6];
    $results[0][11] = $final[7];

    return \@results;
}

sub get_gene_id_to_molecular_weight {
    my($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT f.score ".
                "FROM feat_score f, ORF_attribute o ".
                "WHERE o.feat_name = '$gene_id' ".
                "AND f.input_id = o.id ".
                "AND f.score_id = 30 "; 
    
    return $self->_get_results_ref($query);
}

sub get_gene_id_to_seleno_cysteine {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT f.score ".
                "FROM feat_score f, ORF_attribute o ".
                "WHERE o.feat_name = '$gene_id' ".
                "AND f.input_id = o.id ".
                "AND f.score_id = 69391 "; 
    
    return $self->_get_results_ref($query);
}

sub get_gene_id_to_programmed_frameshifts {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT f.score ".
                "FROM feat_score f, ORF_attribute o ".
                "WHERE o.feat_name = '$gene_id' ".
                "AND f.input_id = o.id ".
                "AND f.score_id =  81508 "; 
    
    return $self->_get_results_ref($query);
}

sub get_gene_id_to_pI {
    my($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT f.score ".
                "FROM feat_score f, ORF_attribute o ".
                "WHERE o.feat_name = '$gene_id' ".
                "AND f.input_id = o.id ".
                "AND f.score_id = 31 "; 
    
    return $self->_get_results_ref($query);
}

sub get_gene_id_to_secondary_structure {
    my($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT s1.score, s2.score, s3.score " .
                "FROM ORF_attribute a, feat_score s1, feat_score s2, feat_score s3 " .
                "WHERE a.feat_name = ? " .
                "AND a.id = s1.input_id " .
                "AND a.id = s2.input_id " .
                "AND a.id = s3.input_id " . 
                "AND s1.score_id = ? " .
                "AND s2.score_id = ? " .
                "AND s3.score_id = ? ";

    return $self->_get_results_ref($query, $gene_id, 50279, 50280, 50281);
}

sub get_gene_id_to_start_confidence {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT f.score " .
                "FROM feat_score f, ORF_attribute o " .
                "WHERE o.feat_name = ? " .
                "AND f.input_id = o.id " .
                "AND f.score_id = ? ";

    return $self->_get_results_ref($query, $gene_id, 50354);
}

sub get_gene_id_to_feat_score {
    my ($self, $gene_id, $score_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT f.score ".
                "FROM feat_score f, ORF_attribute o ".
                "WHERE o.feat_name = ? ".
                "AND f.input_id = o.id ".
                "AND f.score_id = ? "; 

    return $self->_get_results_ref($query, $gene_id, $score_id);
}

sub get_gene_id_to_HMMs {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

#    my $query = "SELECT e.id, e.accession, e.ev_type, s.score, t.score_type ,0,0, e.curated, e.end5, e.end3, e.rel_end5, e.rel_end3, h.trusted_cutoff, h.noise_cutoff, e.assignby, e.date, e.m_lend, e.m_rend, h.hmm_com_name, h.iso_type, h.hmm_len, h.ec_num, h.gene_sym, h.trusted_cutoff2, h.noise_cutoff2, h.gathering_cutoff, h.gathering_cutoff2 " .
    my $query = "SELECT e.id, e.accession, s.score, t.score_type ,0,0, e.curated, e.end5, e.end3, e.rel_end5, e.rel_end3, e.assignby, e.date, e.m_lend, e.m_rend, h.trusted_cutoff, h.noise_cutoff, h.hmm_com_name, h.iso_type, h.hmm_len, h.ec_num, h.gene_sym, h.tc_num, h.trusted_cutoff2, h.noise_cutoff2, h.gathering_cutoff, h.gathering_cutoff2 " .
                "FROM $db..evidence e, $db..feat_score s, egad..hmm2 h, common..score_type t " .
                "WHERE e.feat_name = '$gene_id' " .
                "AND h.is_current = 1 " .
                "AND e.id = s.input_id " .
                "AND t.input_type = 'HMM2' " .
                "AND t.id = s.score_id " .
                "AND e.accession = h.hmm_acc ";

    my $ret = $self->_get_results_ref($query);
    
    #
    # Need to reformat results because feat_score gives them back in unusable format
    my %scores;
    for (my $i=0; $i<@$ret; $i++) {
	my $score_type = $ret->[$i][3];
	my $score = $ret->[$i][2];
	$scores{$ret->[$i][0]}->{$score_type} = $score;
	
	if(!$scores{$ret->[$i][0]}->{'row'}) {
	    my @row = @{$ret->[$i]};
	    $scores{$ret->[$i][0]}->{'row'} = \@row;
	}
    }
    
    my @results_format;
    foreach my $eid (keys %scores) {
	$scores{$eid}->{'row'}[2] = $scores{$eid}->{'score'};
	$scores{$eid}->{'row'}[3] = $scores{$eid}->{'e-value'};
	$scores{$eid}->{'row'}[4] = $scores{$eid}->{'tot_score'} ? $scores{$eid}->{'tot_score'} : $scores{$eid}->{'score'};
	$scores{$eid}->{'row'}[5] = $scores{$eid}->{'tot_e-value'} ? $scores{$eid}->{'tot_e-value'} : $scores{$eid}->{'e-value'};
	push (@results_format,$scores{$eid}->{'row'});
    }
    return \@results_format;
}

sub get_gene_id_to_prosite {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT e.id, e.accession, f.score, e.curated, e.end5, e.end3, e.rel_end5, e.rel_end3, e.assignby, e.date, p.description, p.hit_precision, p.recall, p.pdoc " .
                "FROM $db..evidence e, $db..feat_score f, common..prosite p " .
                "WHERE e.feat_name = ? " .
                "AND e.ev_type = ? " .
                "AND e.id = f.input_id " .
                "AND f.score_id = ? " .
                "AND e.accession = p.accession " .
                "ORDER BY lower(e.accession), e.rel_end5 ";

    return $self->_get_results_ref($query, $gene_id, 'PROSITE', 92);
}

sub get_gene_id_to_BER {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT DISTINCT e.id, e.accession, e.curated, e.rel_end5, e.rel_end3, ".
	        "e.m_lend, e.m_rend, s.score_type, f.score ".
	        "FROM $db..evidence e, $db..feat_score f, common..score_type s ".
		"WHERE e.feat_name = ? ".
		"AND e.ev_type = 'BER' ".
		"AND e.id = f.input_id ".
		"AND f.score_id = s.id ".
		"ORDER BY e.accession ";

    my $ret = $self->_get_results_ref($query, $gene_id);

    #
    # Create a hash that uses the different score_types to build one ret array ref
    my %final;
    for(my $i=0; $i<@$ret; $i++) {
	$final{$ret->[$i][0]}->{'accession'} = $ret->[$i][1];
	$final{$ret->[$i][0]}->{'curated'} = $ret->[$i][2];
	$final{$ret->[$i][0]}->{'rel_end5'} = $ret->[$i][3];
	$final{$ret->[$i][0]}->{'rel_end3'} = $ret->[$i][4];
	$final{$ret->[$i][0]}->{'m_lend'} = $ret->[$i][5];
	$final{$ret->[$i][0]}->{'m_rend'} = $ret->[$i][6];
	$final{$ret->[$i][0]}->{$ret->[$i][7]} = $ret->[$i][8];
    }

    #
    # Have to create new return array ref to include the new score values for the BER
    my $ret;
    my $j = 0;
    foreach my $eid (keys %final) {
	$ret->[$j][0] = $eid;
	$ret->[$j][1] = $final{$eid}->{'accession'};
	$ret->[$j][2] = $final{$eid}->{'curated'};
	$ret->[$j][3] = $final{$eid}->{'rel_end5'};
	$ret->[$j][4] = $final{$eid}->{'rel_end3'};
	$ret->[$j][5] = $final{$eid}->{'m_lend'};
	$ret->[$j][6] = $final{$eid}->{'m_rend'};
	$ret->[$j][7] = $final{$eid}->{'score'};
	$ret->[$j][8] = $final{$eid}->{'Pvalue'};
	$ret->[$j][9] = $final{$eid}->{'per_id'};
	$ret->[$j][10] = $final{$eid}->{'per_sim'};
	$j++;
    }
    return $ret;
}

sub get_gene_id_to_evidence {
    my($self, $gene_id, $ev_type, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT e.id, e.ev_type, e.accession, e.end5, e.end3, e.rel_end5, e.rel_end3, e.m_lend, e.m_rend, e.curated, e.date, e.assignby, e.change_log, e.save_history, e.method " .
                "FROM $db..evidence e, $db..asm_feature a, $db..stan s " .
                "WHERE e.feat_name = '$gene_id' ".
		"AND e.feat_name = a.feat_name ".
		"AND a.asmbl_id = s.asmbl_id ".
		"AND s.iscurrent = 1 ";
    
    if($ev_type) {
	$query .= "AND LOWER(ev_type) = LOWER('$ev_type') ";
    }

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_protein {
    my($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query  = "SELECT a.protein " .
                 "FROM asm_feature a, stan s " .
                 "WHERE a.feat_name = '$gene_id' ".
		 "AND a.asmbl_id = s.asmbl_id ".
		 "AND s.iscurrent = 1 ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_transcript {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query  = "SELECT a.sequence " .
                 "FROM asm_feature a, stan s " .
                 "WHERE a.feat_name = ? ".
		 "AND a.asmbl_id = s.asmbl_id ".
		 "AND s.iscurrent = 1 ";

    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_CDS {
    my($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query  = "SELECT a. sequence " .
                 "FROM asm_feature a, stan s ".
                 "WHERE a.feat_name = ? ".
		 "AND a.asmbl_id = s.asmbl_id ".
		 "AND s.iscurrent = 1 ";

    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_att_id {
    my ($self, $gene_id, $att_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT o.id " .
                "FROM ORF_attribute o " .
                "WHERE feat_name = ? ".
		"AND att_type = ? ";
    
    return $self->_get_results_ref($query, $gene_id, $att_type);
}

sub get_gene_id_to_evidence2 {
    my($self, $gene_id, $ev_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT e.accession, e.rel_end5, e.rel_end3, '' ".
                "FROM evidence e ".
		"WHERE e.feat_name = ? ";
    if($ev_type) {
	$query .= "AND e.ev_type = '$ev_type' ";
    }

    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_asm_feature_history {
    my ($self, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a.feat_name, a.feat_type, a.end5, a.end3, a.asmbl_id, a.assignby, a.prev_mod_date, a.last_mod_date, a.type " .
                "FROM asm_feature_history a " .
                "WHERE feat_name = ? ";

    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_gene_attributes {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SELECT DISTINCT o.feat_name, o.att_type, t.score_type, f.score, i.com_name ".
	        "FROM ORF_attribute o, feat_score f, common..score_type t, ident i ". 
		"WHERE o.feat_name = ? ".
		"AND o.feat_name = i.feat_name ".
		"AND o.id = f.input_id ".
		"AND f.score != '' ".
		"AND f.score_id = t.id ".
		"ORDER BY o.feat_name ";

    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_frameshifts {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT id, feat_name, assignby, curated, fs_accession, date, att_type, comment, cpt_date, vrf_date, labperson, reviewby " .
                "FROM $db..frameshift " .
                "WHERE feat_name = ? ".
		"ORDER BY date DESC ";

    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_ec_numbers {
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT i.ec# ".
	        "FROM $db..ident i, $db..stan s, $db..asm_feature a ".
		"WHERE i.feat_name = '$gene_id' ".
		"AND i.feat_name = a.feat_name ".
		"AND a.asmbl_id = s.asmbl_id ".
		"AND s.iscurrent = 1 ";

    return $self->_get_results_ref($query);
}

sub get_handle_gene_id {
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    return $gene_id;
}

sub get_gene_id_to_prints {
    my($self, $gene_id,$db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
 
    my $query = "SELECT id, ev_type, accession, end5, end3, rel_end5, rel_end3, m_lend, ".
	        "m_rend, curated, date, assignby, change_log, save_history, method " .
                "FROM $db..evidence " .
                "WHERE feat_name = '$gene_id' ".
		"AND ev_type = 'FPrintScan' ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_prodom {
    my($self, $gene_id,$db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT id, ev_type, accession, end5, end3, rel_end5, rel_end3, m_lend, ".
	        "m_rend, curated, date, assignby, change_log, save_history, method " .
                "FROM $db..evidence " .
                "WHERE feat_name = '$gene_id' ".
		"AND ev_type = 'BlastProDom' ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_profiles {
    my($self, $gene_id,$db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT id, ev_type, accession, end5, end3, rel_end5, rel_end3, m_lend, ".
	        "m_rend, curated, date, assignby, change_log, save_history, method " .
                "FROM $db..evidence " .
                "WHERE feat_name = '$gene_id' ".
		"AND ev_type = 'ProfileScan' ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_COG {
    my($self, $gene_id,$db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT accession, rel_end5, rel_end3 ".
	        "m_rend, curated, date, assignby, change_log, save_history, method " .
                "FROM $db..evidence " .
                "WHERE feat_name = '$gene_id' ".
		"AND ev_type = 'COG accession' ";
    
    return $self->_get_results_ref($query);
}

sub get_gene_id_to_legacy_data {
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a.feat_name, a.asmbl_id, '$db' ".
	        "FROM $db..asm_feature a, $db..stan s ".
		"WHERE a.feat_name = '$gene_id' ".
		"AND a.asmbl_id = s.asmbl_id ".
		"AND s.iscurrent = 1 ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_roles {
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT r.role_id, mainrole, sub1role, sub2role " . 
                "FROM $db..role_link r, egad..roles e " . 
                "WHERE feat_name = ? " .
                "AND e.role_id = r.role_id ".
		"ORDER by role_id";
    
    return $self->_get_results_ref($query, $gene_id);
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

sub get_gene_id_to_frameshifts {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT id, feat_name, assignby, curated, fs_accession, date, att_type, comment, cpt_date, vrf_date, labperson, reviewby " .
                "FROM $db..frameshift " .
                "WHERE feat_name = '$gene_id' ".
		"ORDER BY date DESC ";

    return $self->_get_results_ref($query);
}

############################
#^ END GENE_ID INPUT_TYPE ^#
##################################################################





#####################
# SEQ_ID INPUT_TYPE #
#####################

sub get_seq_id_to_length {
    my($self, $seq_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query  = "SELECT datalength(sequence) " .
                 "FROM $db..assembly " .
                 "WHERE asmbl_id = $seq_id ";

    return $self->_get_results_ref($query);
}

sub get_seq_id_to_sequence {
    my($self, $seq_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query  = "SELECT sequence " .
                 "FROM $db..assembly " .
                 "WHERE asmbl_id = ? ";

    return $self->_get_results_ref($query, $seq_id);
}

sub get_seq_id_to_genes {
    my ($self, $seq_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT i.feat_name, i.locus, i.com_name, i.gene_sym, i.ec#, a.asmbl_id, a.end5, a.end3, ".
	        "r.role_id, e.mainrole, e.sub1role, i.complete, i.start_edit ".
	        "FROM $db..ident i, $db..asm_feature a ".
		"LEFT JOIN $db..role_link r ON (a.feat_name = r.feat_name) ".
		"LEFT JOIN egad..roles e    ON (r.role_id   = e.role_id) ".
		"WHERE a.asmbl_id = $seq_id " .
		"AND a.feat_name = i.feat_name ".
		"AND a.feat_type = 'ORF' ";

    return $self->_get_results_ref($query);
}

sub get_seq_id_to_roles {
    my($self, $seq_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
 
    my $query = "SELECT DISTINCT l.feat_name, l.role_id, r.mainrole, r.sub1role, r.sub2role, a.end5, a.end3, '' ".
	        "FROM $db..asm_feature a, $db..role_link l, egad..roles r ".
		"WHERE l.role_id = r.role_id ".
		"AND l.feat_name = a.feat_name ".
		"AND a.asmbl_id = ? ";

    return $self->_get_results_ref($query, $seq_id);
}

sub get_seq_id_to_max_gene_id {
    my ($self, $seq_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SELECT max(f.feat_name) ".
	        "FROM $db..asm_feature f, $db..stan s ". 
		"WHERE f.feat_type IN ('ORF','RORF','MRORF') ".
		"AND f.asmbl_id = s.asmbl_id ".
		"AND s.iscurrent = 1 ".
		"AND f.asmbl_id = $seq_id ";

    my @results = $self->_get_results($query);
    return $results[0][0];
}

###########################
#^ END SEQ_ID INPUT_TYPE ^#
##################################################################




######################
# ROLE_ID INPUT_TYPE #
######################

sub get_role_id_to_notes {
    my($self, $role_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT notes ".
	        "FROM role_notes ".
		"WHERE role_id = $role_id ";

    return $self->_get_results_ref($query);
}

sub get_seq_id_to_sub_to_final {
    my ($self, $seq_id) = @_;

    my $query = "SELECT asmbl_id, asm_lend, asm_rend, sub_asmbl_id, sub_asm_lend, sub_asm_rend ".
	        "FROM sub_to_final ".
		"WHERE asmbl_id = ? ";

    return $self->_get_results_ref($query,  $seq_id);
}

###########################
#^ END SEQ_ID INPUT_TYPE ^#
##################################################################




######################
# ROLE_ID INPUT_TYPE #
######################

sub get_role_id_to_categories {
    my($self, $id, $main) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT e.role_order, e.role_id, e.mainrole, e.sub1role ".
	        "FROM egad..roles e ";
    
    if ($id ne "all" && $main eq "all") {         # one role only
        $query .= "WHERE e.role_id = $id";
    } elsif ($id eq "all" && $main ne "all") {    # main role only
        $query .= "WHERE e.compartment = 'microbial' AND mainrole = \"$main\"";
    } else {
        $query .= "WHERE e.compartment = 'microbial'";
    }
    $query .= " ORDER BY e.role_order";

    return $self->_get_results_ref($query);
}

sub get_role_id_to_genes {
    my($self, $role_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
 
    my $query = "SELECT l.feat_name ".
	        "FROM role_link l ".
		"WHERE role_id = ? ";

    return $self->_get_results_ref($query, $role_id);
}

sub get_role_id_to_common_notes {
    my($self, $role_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
 
    my $query = "SELECT r.notes, e.mainrole, e.sub1role " . 
                "FROM common..role_notes r, egad..roles e " .
                "WHERE e.role_id = r.role_id " .
                "AND e.compartment = ? " .
                "AND e.role_id = ? ";

    return $self->_get_results_ref($query, "microbial", $role_id);
}

############################
#^ END ROLE_ID INPUT_TYPE ^#
##################################################################




#####################
#   DB INPUT_TYPE   #
#####################

sub get_db_to_seq_names {
    my($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT s.asmbl_id, a.name, a.type, m.sequence, datalength(m.sequence) " .
                "FROM $db..stan s, $db..asmbl_data a, $db..assembly m " .
                "WHERE s.iscurrent = 1 " .
                "AND s.asmbl_data_id = a.id " .
		"AND m.asmbl_id = s.asmbl_id ".
                "ORDER BY a.type, a.name";

    return $self->_get_results_ref($query);
}

sub get_db_to_genes {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SELECT a.feat_name, a.sequence, i.com_name " .
                "FROM $db..asm_feature a, $db..stan s, $db..ident i " .
                "WHERE s.iscurrent = 1 " .
                "AND s.asmbl_id = a.asmbl_id " .
		"AND a.feat_type = 'ORF' ".
		"AND a.feat_name = i.feat_name ".
		"ORDER BY a.feat_name ";

    return $self->_get_results_ref($query);
}

sub get_db_to_frameshifts {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT fs.feat_name,f.asmbl_id,f.end5,f.end3,fs.att_type, fs.id, fs.date, fs.cpt_date, fs.vrf_date, fs.assignby, fs.labperson, fs.reviewby, fs.curated, fs.fs_accession, fs.comment, i.com_name ".
	        "FROM $db..asm_feature f, $db..frameshift fs, $db..stan s, $db..ident i ".
		"WHERE f.asmbl_id = s.asmbl_id ".
		"AND s.iscurrent = 1 ".
		"AND f.feat_name = i.feat_name ".
		"AND f.feat_name = fs.feat_name ".
		"AND (fs.att_type = 'FS' ".
		"OR fs.att_type = 'AMB' ".
		"OR fs.att_type = 'DEG' ".
		"OR fs.att_type = 'FRAG' ".
		"OR fs.att_type = 'AFS' ".
		"OR fs.att_type = 'FIXED' ".
		"OR fs.att_type = 'APM' ".
		"OR fs.att_type = 'PM') ".
		"ORDER BY fs.feat_name, fs.date ";

    return $self->_get_results_ref($query);
}

sub get_db_to_roles {
    my($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT r.feat_name, r.role_id, e.mainrole, e.sub1role, e.sub2role " . 
                "FROM $db..role_link r, egad..roles e " . 
                "WHERE e.role_id = r.role_id ".
		"ORDER by role_id ";
    
    return $self->_get_results_ref($query);
}

sub get_db_to_role_notes {
    my($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SELECT n.role_id, r.mainrole, r.sub1role, n.notes " .
                "FROM $db..role_notes n, egad..roles r " .
	        "WHERE n.role_id = r.role_id ";

    return $self->_get_results_ref($query);
}

sub get_db_to_role_breakdown {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT r.role_id, count(i.feat_name), count(i.complete) ".
	        "FROM $db..role_link r, $db..ident i, $db..asm_feature a, $db..stan s ".
		"WHERE r.feat_name = i.feat_name ".
		"AND i.feat_name = a.feat_name ".
		"AND a.asmbl_id = s.asmbl_id ".
		"AND s.iscurrent = 1 ".
		"GROUP BY r.role_id ";

    my $res = $self->_get_results_ref($query);
}

sub get_db_to_tRNAs {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a.feat_name, a.asmbl_id, d.name, a.end5, a.end3, f.score " .
                "FROM asm_feature a, ORF_attribute o, feat_score f, stan s, asmbl_data d " .
                "WHERE a.asmbl_id = s.asmbl_id " .
                "AND s.asmbl_data_id = d.id " .
                "AND a.feat_name = o.feat_name " .
                "AND o.id = f.input_id " .
                "AND s.iscurrent = 1 " .
                "AND a.feat_type = 'tRNA' " . 
                "ORDER BY d.name ";

    return $self->_get_results_ref($query);
}

sub get_db_to_rRNAs {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a.feat_name, a.asmbl_id, d.name, a.end5, a.end3, f.name ".
                "FROM $db..asm_feature a, $db..stan s, common..feat_type f, $db..asmbl_data d ".
                "WHERE s.iscurrent = 1 ".
                "AND s.asmbl_id = a.asmbl_id ".
		"AND s.asmbl_data_id = d.id ".
		"AND a.feat_type = f.feat_type ".
		"AND a.feat_type = 'rRNA' ".
		"ORDER BY a.feat_name ";

    return $self->_get_results_ref($query);
}

sub get_db_to_snRNAs {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a.feat_name, a.asmbl_id, d.name, a.end5, a.end3, f.name ".
                "FROM $db..asm_feature a, $db..stan s, common..feat_type f, $db..asmbl_data d ".
                "WHERE s.iscurrent = 1 ".
                "AND s.asmbl_id = a.asmbl_id ".
		"AND s.asmbl_data_id = d.id ".
		"AND a.feat_type = f.feat_type ".
		"AND a.feat_type = 'sRNA' ".
		"ORDER BY a.feat_name ";

    return $self->_get_results_ref($query);
}

sub get_db_to_max_gene_id {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SELECT max(f.feat_name) ".
	        "FROM $db..asm_feature f, $db..stan s ". 
		"WHERE f.feat_type IN ('ORF','RORF','MRORF') ".
		"AND f.asmbl_id = s.asmbl_id ".
		"AND s.iscurrent = 1 ";

    return $self->_get_results_ref($query);
}

sub get_db_to_current_seq_id {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SELECT DISTINCT f.asmbl_id ".
	        "FROM $db..asm_feature f, $db..stan s ". 
		"WHERE f.asmbl_id = s.asmbl_id ".
		"AND s.iscurrent = 1 ";

    return $self->_get_results_ref($query);
}

sub get_db_to_GO {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT feat_name, go_id ".
	        "FROM $db..go_role_link ";

    return $self->_get_results_ref($query);
}

sub get_db_to_roles {
    my($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT r.feat_name, r.role_id, mainrole, sub1role, sub2role " . 
                "FROM $db..role_link r, egad..roles e " . 
                "WHERE e.role_id = r.role_id ORDER by role_id";

    return $self->_get_results_ref($query);
}

#######################
#^ END DB INPUT_TYPE ^#
##################################################################

sub get_db_to_gene_features {
    my ($self, $db, $feat_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a.feat_name, a.asmbl_id, d.name, a.end5, a.end3, '', f.name, a.feat_type, '', s.iscurrent, s.asmbl_id, s.asmbl_data_id, d.id, f.feat_type ".
                "FROM $db..asm_feature a, $db..stan s, common..feat_type f, $db..asmbl_data d ".
                "WHERE s.iscurrent = 1 ".
                "AND s.asmbl_id = a.asmbl_id ".
		"AND s.asmbl_data_id = d.id ".
		"AND a.feat_type = f.feat_type ";

    if($feat_type ne "") {
	$query .= "AND a.feat_type = '$feat_type' ";
    }
    
    if($feat_type ne "") {
	$query .= "AND a.feat_type = '$feat_type' ";
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



###########################
#   ATT_TYPE INPUT_TYPE   #
###########################

sub get_att_type_to_membrane_proteins {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT DISTINCT o.feat_name, o.att_type, t.score_type, f.score, i.com_name ".
	        "FROM ORF_attribute o, feat_score f, common..score_type t, ident i ". 
		"WHERE o.att_type IN ('GES', 'OMP', 'LP', 'SP') ".
		"AND o.feat_name = i.feat_name ".
		"AND o.id = f.input_id ".
		"AND f.score != '' ".
		"AND f.score_id = t.id ";

    return $self->_get_results_ref($query);
}

sub get_att_type_to_gene_attributes {
    my ($self, $att_type, $att_order) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SELECT DISTINCT o.feat_name, o.att_type, t.score_type, f.score, i.com_name ".
	        "FROM ORF_attribute o, feat_score f, common..score_type t, ident i ". 
		"WHERE o.att_type = '$att_type' ".
		"AND o.feat_name = i.feat_name ".
		"AND o.id = f.input_id ".
		"AND f.score != '' ".
		"AND f.score_id = t.id ";

    if($att_order ne "") {
	$query .= "AND t.score_type = '$att_order' ";
    }
    $query .= "ORDER BY o.feat_name ";

    return $self->_get_results_ref($query);
}

#############################
#^ END ATT_TYPE INPUT_TYPE ^#
##################################################################




######################
#   ACC INPUT_TYPE   #
######################

sub get_acc_to_genes {
    my ($self, $acc) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SELECT DISTINCT e.feat_name, i.com_name ".
                "FROM evidence e, ident i ".
		"WHERE e.accession = ? ".
		"AND e.feat_name = i.feat_name ";
 
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

sub get_HMM_acc_to_evidence {
    my ($self, $HMM_acc, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT h.feat_name, f.score, i.com_name, h.curated " .
                "FROM $db..evidence h, $db..ident i, $db..feat_score f " .
                "WHERE h.accession = ? " .
                "AND h.feat_name = i.feat_name " .
		"AND h.id = f.input_id ".
		"AND f.score_id = 51 ";
    
    return $self->_get_results_ref($query, $HMM_acc);
}

sub get_HMM_acc_to_scores {
    my ($self, $HMM_acc) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SELECT e.feat_name, e.id, e.rel_end5, e.rel_end3, e.m_lend, e.m_rend, s.score_id, s.score ".
	        "FROM evidence e, feat_score s ".
		"WHERE e.accession = '$HMM_acc' ".
		"AND e.id = s.input_id ".
		"AND s.score_id IN (143, 51) ".
		"ORDER BY s.score DESC ";
    
    return $self->_get_results_ref($query);
}

sub get_HMM_acc_to_features {
    my ($self, $HMM_acc) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SELECT DISTINCT i.feat_name, i.com_name, i.ec#, i.gene_sym ".
	        "FROM evidence e, egad..hmm2 h, ident i ".
		"WHERE i.feat_name = e.feat_name ".
	        "AND h.hmm_acc = e.accession ".
		"AND e.accession = ? ".
		"AND h.is_current = 1 ";

    return $self->_get_results_ref($query, $HMM_acc);
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

    my $query = "INSERT $db..role_link (feat_name, role_id, assignby, datestamp) ".
	        "VALUES (?, ?, ?, getdate())";

    $self->_set_values($query, $gene_id, $role_id, $self->{_user});
}

sub do_insert_feat_score {
    my ($self, $input_id, $score_id, $score, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my $query = "INSERT feat_score(input_id, score_id, score) ".
	        "VALUES (?, ?, ?)";
    $self->_set_values($query, $input_id, $score_id, $score);
}

sub do_insert_SOP_summary {
    my ($self, $summary_type, $SOP_type, $start_date, $end_date, $completed_by) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    #
    # Modify start date.
    if ($start_date) { 
	$start_date = "\"$start_date\"";
    } 
    else { 
	$start_date = "NULL";
    }
    
    #
    # Modify end date.
    if($end_date) { 
	$end_date = "\"$end_date\"";
    } 
    else { 
	$end_date = "NULL";
    }
    
    #
    # Modify completed_by.
    if(!($completed_by)) { 
	$completed_by = "noname"; 
    }

    my $query = "INSERT common..SOP_summary(SOP_type, start_date, end_date, db, completed_by, summary_type) ".
                "VALUES (?, $start_date, $end_date, ?, ?, ?) ";    

    $self->_set_values($query, $SOP_type, $self->{_db}, $completed_by, $summary_type);
}

sub do_insert_selenocysteine {
    my ($self, $gene_id, $curated, $method) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my $query = "INSERT ORF_attribute (feat_name, att_type, curated, method, date, assignby) ".
                "VALUES(?, ?, ?, ?, getdate(),  ?) ";
    $self->_set_values($query, $gene_id, 'SELENO_CYS', $curated, $method, $self->{_user});
}

sub do_insert_attribute {
    my ($self, $att_ref) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my $query = "INSERT ORF_attribute (feat_name, att_type, curated, method, date, assignby) ".
                "VALUES(?, ?, ?, ?, getdate(),  ?) ";
    $self->_set_values($query, 
		       $att_ref->{'gene_id'}, 
		       $att_ref->{'att_type'}, 
		       $att_ref->{'curated'}, 
		       $att_ref->{'method'}, 
		       $self->{_user});
}

sub do_insert_evidence {
    my ($self, $gene_id, $acc, $type, $coords_ref, $scores_ref, $curated) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "INSERT evidence (feat_name, ev_type, accession, end5, end3, rel_end5, rel_end3, m_lend, m_rend, curated, date, assignby, change_log, save_history, method) " .
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, getdate(), ?, 1, 1, ?)";

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
		       $curated,
		       $self->{_user},
		       "Manatee");

    my $idquery = "SELECT max(id) " .
                  "FROM evidence ".
                  "WHERE feat_name = ? " .
                  "AND ev_type = ? " .
                  "AND accession = ?";

    my $ret = $self->_get_results_ref($idquery, $gene_id, $type, $acc);

    my $scorequery = "INSERT feat_score (input_id, score_id, score) ".
	             "VALUES (?,?,?) ";

    $self->_set_values($scorequery, $ret->[0][0], 9,  $scores_ref->{'praze'});
    $self->_set_values($scorequery, $ret->[0][0], 10, $scores_ref->{'pvalue'});
    $self->_set_values($scorequery, $ret->[0][0], 11, $scores_ref->{'per_sim'});
    $self->_set_values($scorequery, $ret->[0][0], 12, $scores_ref->{'per_id'});
}

sub do_insert_asm_feature {
    my ($self, $feat_ref) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "INSERT asm_feature (feat_type, feat_method, assignby, date, feat_name, asmbl_id, end5, end3, change_log) ".
	        "VALUES (?,?,?,getdate(),?,?,?,?,?)";
    
    $self->_set_values($query, 
		       $feat_ref->{'feat_type'}, 
		       $feat_ref->{'feat_method'}, 
		       $self->{_user}, 
		       $feat_ref->{'gene_id'}, 
		       $feat_ref->{'seq_id'}, 
		       $feat_ref->{'end5'}, 
		       $feat_ref->{'end3'}, 
		       1);
}

sub do_insert_ident {
    my ($self, $ident_ref) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "INSERT ident (feat_name, com_name, assignby, date, save_history) ".
	        "VALUES (?,?,?,getdate(),1)";
    
    $self->_set_values($query, 
		       $ident_ref->{'gene_id'}, 
		       $ident_ref->{'gene_name'}, 
		       $self->{_user});
}

##########################
#^ END INSERT FUNCTIONS ^#
##################################################################




######################
#  UPDATE FUNCTIONS  #
######################

sub do_update_auto_annotate {
    my ($self, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "UPDATE $db..ident ".
	        "SET auto_annotate = 0 ".
		"WHERE feat_name = ? ";

    $self->_set_values($query, $gene_id);
}

sub do_update_completed {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "UPDATE $db..ident ".
	        "SET complete = ? ".
		"WHERE feat_name = ? ";
    $self->_set_values($query, $self->{_user}, $gene_id);
}

sub do_delete_completed {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "UPDATE $db..ident ".
	        "SET complete = NULL ".
		"WHERE feat_name = '$gene_id' ";
    $self->_set_values($query);
}

sub do_update_start_edit {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "UPDATE $db..ident ".
	        "SET start_edit = ? ".
		"WHERE feat_name = ? ";
    $self->_set_values($query, $self->{_user}, $gene_id);
}

sub do_delete_start_edit {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "UPDATE $db..ident ".
	        "SET start_edit = NULL ".
		"WHERE feat_name = '$gene_id' ";
    $self->_set_values($query);
}

sub do_update_new_project {
    my($self,$hashref) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "UPDATE new_project SET ".
	        "organism_name = '$hashref->{org_name}', ".
		"project_leader = '$hashref->{proj_lead}', ".
		"notify = '$hashref->{notify}', ".
		"funded_by = '$hashref->{fund}', ".
		"grant# = '$hashref->{tigr_grant}', ".
		"genome_URL = '$hashref->{url}', ".
		"lib_construct_date = '$hashref->{lib_date}', ".
		"seq_date = '$hashref->{seq_date}', ".
		"closure_date = '$hashref->{close_date}', ".
		"annotation_date = '$hashref->{ann_date}', ".
		"lit_submit_date = '$hashref->{sub_date}', ".
		"publish_date = '$hashref->{pub_date}', ".
		"grant_deadline = '$hashref->{grantdead}', ".
		"accession_submit_date = '$hashref->{acc_date}' ";

    if((length($hashref->{gram}) > 0) && ($hashref->{gram} ne "none")) {
	$query .= ", gram_stain = '$hashref->{gram}' ";
    }

    if($hashref->{tax_id} > 0) {
	$query .= ", taxon_id = $hashref->{tax_id} ";
    }

    if($hashref->{code} > 0) {
	$query .= ", genetic_code = $hashref->{code} ";
    }
    
    if($hashref->{asmbl_len} > 0) {
	$query .= ", asmbl_len = $hashref->{asmbl_len} ";
    }
    
    if($hashref->{project_type}) {
	$query .= ", CMR_email = '$hashref->{pi_username}' ";
    }

    if($hashref->{team_lead}) {
	$query .= ", team_leader = '$hashref->{team_lead}' ";
    }
    $query .= "WHERE id != 0 ";

    $query =~ s/\= \' \'/= NULL/g;
    $query =~ s/\= \'\'/= NULL/g;
    $self->_set_values($query);
}

sub do_update_SOP_summary {
    my ($self, $summary_type, $SOP_type, $start_date, $end_date, $completed_by) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    #
    # Modify start date.
    if ($start_date) { 
	$start_date = "\"$start_date\"";
    } 
    else { 
	$start_date = "NULL";
    }
    
    #
    # Modify end date.
    if($end_date) { 
	$end_date = "\"$end_date\"";
    } 
    else { 
	$end_date = "NULL";
    }
    
    #
    # Modify completed_by.
    if(!($completed_by)) { 
	$completed_by = "noname"; 
    }

    my $query = "UPDATE common..SOP_summary ".
                "SET start_date = $start_date, end_date = $end_date, completed_by = ?, summary_type = ? ".
                "WHERE SOP_type = ? ".
                "AND db = ? ";

    $self->_set_values($query, $completed_by, $summary_type, $SOP_type, $self->{_db});
}

sub do_update_asm_feature_for_deleted_gene {
    my ($self, $gene_id, $seq_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "UPDATE asm_feature ".
	        "SET assignby = ?, feat_method = ?, date = getdate() ".
		"WHERE asmbl_id = ? ".
		"AND feat_name = ? ";

    $self->_set_values($query, $self->{_user}, "GenomeViewer", $seq_id, $gene_id);
}

sub do_update_asm_feature {
    my ($self, $gene_id, $feat_ref) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "UPDATE asm_feature SET ";
    
    if (defined($feat_ref->{'end5'})) {
        $query .= "end5 = $feat_ref->{'end5'},";
    }
    if (defined($feat_ref->{'end3'})) {
        $query .= "end3 = $feat_ref->{'end3'},";
    }
    if (defined($feat_ref->{'sequence'})) {
        $query .= "sequence = '$feat_ref->{'sequence'}',";
    }
    if (defined($feat_ref->{'protein'})) {
	if($feat_ref->{'protein'} eq "NULL") {
	    $query .= "protein = NULL,";
	}
	else {
	    $query .= "protein = '$feat_ref->{'protein'}',";
	}
    }

    ## always set assignby
    $query .= "assignby = '$self->{_user}' ";
    $query .= "WHERE feat_name = ? ".
	      "AND asmbl_id = ? ";
    
    $self->_set_values($query, $gene_id, $feat_ref->{'asmbl_id'});
}

sub do_update_property {
    my ($self, $hashref) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "";
    $query .= "UPDATE common..property SET ";
    $query .= "curator_comment = \"$hashref->{'curator_comment'}\", ";
    #
    # Determine query portion for state.    
    if($hashref->{'state'} && $hashref->{'state'} ne "NULL") {
	$query .= "state = \"$hashref->{'state'}\", ";
    }
    #
    # Determine query portion for experiment.
    if($hashref->{'experiment'} && $hashref->{'experiment'} ne "NULL") {
	$query .= "experiment = $hashref->{'experiment'}, ";
    }
    elsif($hashref->{'experiment'} && $hashref->{'experiment'} eq "NULL") {
	$query .= "experiment = NULL, ";
    }
    #
    # Determine query portion for prediction.
    if($hashref->{'prediction'} && $hashref->{'prediction'} ne "NULL") {
	$query .= "prediction = $hashref->{'prediction'}, ";
    }
    elsif($hashref->{'prediction'} && $hashref->{'prediction'} eq "NULL") {
	$query .= "prediction = NULL, ";
    }

    $query .= "assignby = \"$hashref->{'assignby'}\", " if($hashref->{'assignby'});
    #### remove the trailing comma
    $query =~ s/(\,\s+)$/ /g;

    $query .= "WHERE prop_def_id = $hashref->{'prop_def_id'} ".
              "AND db = \"$hashref->{'db'}\" ";
    
    #
    # Update the common..property table.
    $self->_set_values($query);
}

sub do_update_property_role_id {
    my ($self, $prop_def_id, $role_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    $role_id = "NULL" if(!$role_id);
    my $query = "UPDATE common..prop_def ".
	        "SET role_id = $role_id ".
	        "FROM common..prop_def d, common..property p ".
		"WHERE d.prop_def_id = $prop_def_id ".
		"AND d.prop_def_id = p.prop_def_id ".
		"AND p.db = '$db' ";
    #
    # Update the common..property table.
    $self->_set_values($query);
}

sub do_update_property_GO_id {
    my ($self, $prop_def_id, $GO_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "UPDATE common..prop_go_link ".
	        "SET go_id = ? ".
		"FROM common..prop_go_link g, common..property p ".
		"WHERE g.prop_def_id = $prop_def_id ".
		"AND g.prop_def_id = p.prop_def_id ".
		"AND p.db = '$db' ";
    #
    # Update the common..property table.
    $self->_set_values($query, $GO_id);
}

sub do_update_ident {
    my ($self, $gene_id, $identref, $xref, $changeref, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    #
    # Only toggle prok auto_annotate = 0 for the following:
    my $no_auto_annotate = 0;
    if ($identref->{'com_name'} || $identref->{'gene_sym'} || $identref->{'ec'}) {
	$no_auto_annotate = 1;
    }
    
    my $query = "UPDATE $db..ident SET ".
	        "date = getdate(), save_history = 1 ";
    $query   .= ", auto_annotate = 0 " if($no_auto_annotate);
    
    foreach my $field (sort keys %$identref) {
	#
	# Put quotes around values unless value = "NULL".
	if ($identref->{$field} ne "NULL") {
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
}

##########################
#^ END UPDATE FUNCTIONS ^#
##################################################################




######################
#  DELETE FUNCTIONS  #
######################

sub do_delete_selenocysteine {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE FROM ORF_attribute ".
	        "WHERE feat_name = ? ".
		"AND att_type = ?";

    $self->_set_values($query, $gene_id, 'SELENO_CYS');
}

sub do_delete_attribute {
    my ($self, $gene_id, $att_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE FROM ORF_attribute ".
	        "WHERE feat_name = ? ".
		"AND att_type = ?";

    $self->_set_values($query, $gene_id, $att_type);
}

sub do_delete_evidence {
    my ($self, $gene_id, $acc, $ev_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $idquery = "SELECT max(id) " .
                  "FROM evidence ".
                  "WHERE feat_name = ? " .
                  "AND ev_type = ? " .
                  "AND accession = ?";
    
    my $ret = $self->_get_results_ref($idquery, $gene_id, $ev_type, $acc);

    my $query = "DELETE FROM evidence ".
	        "WHERE id = ? ";
    $self->_set_values($query, $ret->[0][0]);


    my $query = "DELETE FROM feat_score ".
	        "WHERE input_id = ? ";
    $self->_set_values($query, $ret->[0][0]);
}

sub do_delete_feat_score_evidence {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE feat_score ".
	        "FROM evidence e, feat_score, common..score_type t, asm_feature a ".
		"WHERE e.id = feat_score.input_id ".
		"AND feat_score.score_id = t.id ".
		"AND e.ev_type = t.input_type ".
		"AND a.feat_name = ? ".
		"AND a.asmbl_id = ? ".
		"AND a.feat_name = e.feat_name ";

    $self->_set_values($query, $gene_id, $seq_id);
}

sub do_delete_feat_score_ORF_attribute {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE feat_score ".
	        "FROM ORF_attribute o, feat_score, common..score_type t, asm_feature a ".
		"WHERE o.id = feat_score.input_id ".
		"AND feat_score.score_id = t.id ". 
		"AND o.att_type = t.input_type ". 
		"AND a.feat_name = ? ".
		"AND a.asmbl_id = ? ".
		"AND a.feat_name = o.feat_name "; 

    $self->_set_values($query, $gene_id, $seq_id);
}

sub do_delete_score_text {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE FROM score_text ".
	        "WHERE feat_name = ? ";

    $self->_set_values($query, $gene_id);
}

sub do_delete_evidence_for_gene_id {
    my ($self, $gene_id, $seq_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "DELETE evidence ".
	        "FROM asm_feature f, evidence ".
		"WHERE f.feat_name = evidence.feat_name ". 
		"AND f.asmbl_id = ? ".
		"AND f.feat_name = ? ";

    $self->_set_values($query, $seq_id, $gene_id);
}

sub do_delete_ORF_attribute_for_gene_id {
    my ($self, $gene_id, $seq_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "DELETE ORF_attribute ".
	        "FROM asm_feature f, ORF_attribute ".
		"WHERE f.feat_name = ORF_attribute.feat_name ". 
		"AND f.asmbl_id = ? ".
		"AND f.feat_name = ? ";

    $self->_set_values($query, $seq_id, $gene_id);
}

sub do_delete_ident_for_gene_id {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE ident ".
	        "FROM asm_feature f, ident ".
		"WHERE f.feat_name = ident.feat_name ".
		"AND f.asmbl_id = ? ".
		"AND f.feat_name = ? ";

    $self->_set_values($query, $seq_id, $gene_id);
}

sub do_delete_role_link_for_gene_id {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE role_link ".
	        "FROM asm_feature f, role_link ".
		"WHERE f.feat_name = role_link.feat_name ". 
		"AND f.asmbl_id = ? ".
		"AND f.feat_name = ? ";

    $self->_set_values($query, $seq_id, $gene_id);
}

sub do_delete_frameshift_for_gene_id {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE FROM frameshift ".
	        "WHERE feat_name = ? ";

    $self->_set_values($query, $gene_id);
}

sub do_delete_asm_feature_for_gene_id {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE asm_feature ".
	        "FROM asm_feature ".
		"WHERE asmbl_id = ? ".
		"AND feat_name = ? ";

    $self->_set_values($query, $seq_id, $gene_id);
}

sub do_delete_role {
    my ($self, $gene_id, $role_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE FROM $db..role_link ".
                "WHERE feat_name = ? ".
                "AND role_id = ?";

    $self->_set_values($query, $gene_id, $role_id);
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
sub get_coordinates_to_genes {
    my ($self,$seq_id,$end5, $end3,$db) = @_;

    my $query = "";

    #
    # Run this query if both the end5 and the end3 coordinates are passed in.
    if ($end5 && $end3) {
	$query = "SELECT i.feat_name, a.end5, a.end3, i.com_name, i.locus, i.gene_sym, i.ec#, i.complete, i.auto_annotate, a.feat_type, a.protein, r.role_id ".
	         "FROM $db..ident i, $db..stan s, $db..asm_feature a ".
		 "LEFT JOIN $db..role_link r ON (a.feat_name = r.feat_name) ".
		 "WHERE ((a.end5 > $end5 AND a.end3 < $end3) ".
		 "OR (a.end5 < $end3 AND a.end3 > $end5)) ".
		 "AND i.feat_name = a.feat_name ";

	if($seq_id eq "ISCURRENT"){
	    $query .= "AND a.asmbl_id = s.asmbl_id ".
		      "AND s.iscurrent = 1 ";
	} else {
	    $query .= "AND a.asmbl_id = $seq_id ";
	    $query .= "AND a.asmbl_id = s.asmbl_id ";
	}
	
	$query .= "ORDER BY (a.end5 + a.end3)/2 ";

    }
    #
    # Run this query if only one coordinate is passed in.
    else {
	
	#### if only one coordinate, assign it to a general variable.
	my $coord = 0;
	if($end5) {
	    $coord = $end5;
	}
	elsif($end3) {
	    $coord = $end3;
	}
	
	$query = "SELECT i.feat_name, a.end5, a.end3, i.com_name, i.locus, i.gene_sym, i.ec#, i.complete, i.auto_annotate, '', '', r.role_id ".
	         "FROM $db..ident i, $db..stan s, $db..asm_feature a ".
		 "LEFT JOIN $db..role_link r ON (a.feat_name = r.feat_name) ".
		 "WHERE ((a.end5 > $coord AND a.end3 < $coord) ".
		 "OR (a.end5 < $coord AND a.end3 > $coord)) ".
		 "AND i.feat_name = a.feat_name ";

	if($seq_id eq "ISCURRENT"){
	    $query .= "AND a.asmbl_id = s.asmbl_id ".
		      "AND s.iscurrent = 1 ";
	} else {
	    $query .= "AND a.asmbl_id = $seq_id ";
	}
	
	$query .= "ORDER BY (a.end5 + a.end3)/2 ";
    }

    return $self->_get_results_ref($query);
}


sub get_handle_btab_names {
    my ($self, $seq_id, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = uc($db);
    
    my $btab_file = sprintf("%s/%s/BER_searches/CURRENT/%s.nr.btab",
			    $ENV{ANNOTATION_DIR},
			    $db,
			    $gene_id);

    my $btab_dir = sprintf("%s/%s/BER_searches/CURRENT",
			   $ENV{ANNOTATION_DIR},
			   $db);

    return ($btab_file,$btab_dir);
}

sub get_handle_blast_names { 	 
    my ($self, $seq_id, $gene_id, $db) = @_; 	 
    return undef; 	 
} 	 

sub get_signalP_file_name {
    my ($self, $seq_id, $gene_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    return "tmpfile";
}

sub get_psipred_name {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $psipred_file = sprintf("%s/%s/PSIPRED_results/%s.psipred2",
			       $ENV{ANNOTATION_DIR},
			       $db,
			       $gene_id);
    return $psipred_file;
}

sub get_intergenic_name {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $intergenic_file = sprintf("%s/%s/intergenic_regions/%s.REPORT",
				  $ENV{ANNOTATION_DIR},
				  uc($db),
				  $db);
    return $intergenic_file;
}

sub get_previous_sigP_results {
    my ($self, $seq_id, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $path = sprintf("%s/%s/asmbls/%s/signalP/sigp.%.gz",
		       $ENV{ANNOTATION_DIR},
		       uc($db),
		       $seq_id,
		       $gene_id);
    return $path;
} 

sub get_overlaps_name {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $overlaps_file = sprintf("%s/%s/overlap_analysis/%s.overlaps",
				$ENV{ANNOTATION_DIR},
				uc($db),
				$db);
    return $overlaps_file;
}

##########################
#^ END MISC INPUT_TYPES ^#
##################################################################




###############################
#     EV_TYPE INPUT_TYPE      #
###############################

sub get_ev_type_to_gene_evidence {
    my ($self, $ev_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;    

    my $query = "";

    if($ev_type eq "HMM2") {
	$query = "SELECT DISTINCT e.accession, count(e.feat_name), h.hmm_com_name, e.ev_type, h.hmm_acc ".
	         "FROM evidence e, egad..hmm2 h ".
		 "WHERE e.ev_type = '$ev_type' ".
		 "AND e.accession = h.hmm_acc ".
		 "GROUP BY e.accession ".
		 "HAVING e.ev_type = '$ev_type' ".
		 "AND e.accession = h.hmm_acc ".
		 "ORDER BY e.accession ";
    } elsif (($ev_type eq "PROSITE") || ($ev_type eq "ProfileScan") || ($ev_type eq "ScanPrositeC")) {
	$query = "SELECT DISTINCT e.accession, count(e.feat_name), p.description, e.ev_type, p.accession ".
	         "FROM evidence e, common..prosite p ".
		 "WHERE e.ev_type = '$ev_type' ".
		 "AND e.accession = p.accession ".
		 "GROUP BY e.accession ".
		 "HAVING e.ev_type = '$ev_type' ".
		 "AND e.accession = p.accession ".
		 "ORDER BY e.accession ";
    } elsif ($ev_type eq "COG accession") {
	$query = "SELECT DISTINCT e.accession, count(e.feat_name), c.com_name, e.ev_type, c.accession ".
	         "FROM evidence e, common..cog c ".
		 "WHERE e.ev_type = '$ev_type' ".
		 "AND e.accession = c.accession ".
		 "GROUP BY e.accession ".
		 "HAVING e.ev_type = '$ev_type' ".
		 "AND e.accession = c.accession ".
		 "ORDER BY e.accession ";
    }
    else {
	$query = "SELECT DISTINCT e.accession, count(e.feat_name), '', e.ev_type  ".
	         "FROM evidence e ".
		 "WHERE e.ev_type = '$ev_type' ".
		 "GROUP BY e.accession ".
		 "HAVING e.ev_type = '$ev_type' ".
		 "ORDER BY e.accession ";
    }

    return $self->_get_results_ref($query);
}

############################
#^ END EV_TYPE INPUT_TYPE ^#
#################################################################



sub get_all_attribute_types {
    my ($self) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT DISTINCT t.input_type ".
	        "FROM common..score_type t, ORF_attribute o ".
		"WHERE t.input_type = o.att_type ".
		"ORDER BY t.input_type ASC ";

    my $res = $self->_get_results_ref($query);

    for (my $i=0; $i<@$res; $i++) {

	my $query = "SELECT t.score_type ".
	            "FROM common..score_type t ".
		    "WHERE input_type = '$res->[$i][0]' ";
	
	my $res2 = $self->_get_results_ref($query);
	
	$res->[$i][1] = "";
	for (my $j=0; $j<@$res2; $j++) {
	    $res->[$i][1] .= "$res2->[$j][0]:";
	}
	$res->[$i][1] =~ s/\:$//;
    }
    return $res;
}

sub get_all_evidence_types {
    my ($self, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT DISTINCT e.ev_type ".
	        "FROM $db..evidence e ".
		"WHERE e.ev_type NOT IN ('AUTO_BER', 'BER', 'BLASTN') ";
	
    return $self->_get_results_ref($query);
}

sub get_GO_id_to_term {
    my($self, $GO_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT go_id, name, type, definition " .
                "FROM common..go_term " .
                "WHERE go_id = '$GO_id' ";

    return $self->_get_results_ref($query);
}

sub get_cv_term {
    my($self, $term, $ontology) = @_;
	return undef;
}

###################################

1;
