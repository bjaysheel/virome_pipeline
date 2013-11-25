package Coati::Modify;

use strict;
use File::Basename;

#################################


######################
#  INSERT FUNCTIONS  #
######################

sub insert_role { 
    my ($self, $gene_id, $role_id, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);
    
    $self->{_backend}->do_insert_role($gene_id, $role_id, $db);
    #
    # This is run for prok only.  If a new role is inserted, 
    # the toggle for auto_annotate is set to 0.
    $self->{_backend}->do_update_auto_annotate($gene_id, $db);    
}

sub insert_GO_id { 
    my ($self, $gene_id, $GO_id, $qualifier, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);
    
    $self->{_backend}->do_insert_GO_id($gene_id, $GO_id, $qualifier, $db);
    #
    # This is run for prok only.  If a new role is inserted, 
    # the toggle for auto_annotate is set to 0.
    $self->{_backend}->do_update_auto_annotate($gene_id, $db);
}

sub insert_GO_evidence { 
    my ($self, $gene_id, $GO_id, $ev_code, $evidence, $with, $qualifier, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    $self->{_backend}->do_insert_GO_evidence($gene_id, $GO_id, $ev_code, $evidence, $with, $qualifier, $db);
    #
    # This is run for prok only.  If a new role is inserted, 
    # the toggle for auto_annotate is set to 0.
    $self->{_backend}->do_update_auto_annotate($gene_id, $db);    
}

sub insert_evidence { 
    my ($self, $gene_id, $acc, $type, $coords_ref, $scores_ref, $curated) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_insert_evidence($gene_id, $acc, $type, $coords_ref, $scores_ref, $curated);
    #
    # This is run for prok only.  If a new role is inserted, 
    # the toggle for auto_annotate is set to 0.
    $self->{_backend}->do_update_auto_annotate($gene_id);    
}

sub insert_ident_xref { 
    my ($self, $gene_id, $xref_type, $ident_val, $relrank, $db) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    $self->{_backend}->do_insert_ident_xref($gene_id, $xref_type, $ident_val, $relrank, $db);
}

sub insert_frameshift { 
    my ($self, $fs_ref) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_insert_frameshift($fs_ref);
}

sub insert_selenocysteine { 
    my ($self, $gene_id, $curated, $method) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_insert_selenocysteine($gene_id, $curated, $method);
}

sub insert_subst { 
    my ($self, $subst_ref) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_insert_subst($subst_ref);
}

sub insert_edit_report {
    my ($self, $report_ref) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_insert_edit_report($report_ref);
}

sub insert_region_evaluation { 
    my ($self, $labinfo_ref) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_insert_region_evaluation($labinfo_ref);
}

sub insert_feat_score { 
    my ($self, $input_id, $score_id, $score) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_insert_feat_score($input_id, $score_id, $score);
}

sub insert_new_ontology_id {
    my ($self, $parent_id, $ontology_id, $link_type, $name, $definition) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $parent_ref = $self->GO_id_to_term($parent_id);
    my $parent_type = "";
    if(@$parent_ref) {
	$parent_type = @$parent_ref[0]->{'type'}; 
    }
    
    $self->{_backend}->do_insert_new_ontology_id($parent_id, $ontology_id, $link_type, $name, $definition, $parent_type);
}

sub insert_ontology_link { 
    my ($self, $parent_id, $child_id, $link_type) = @_;
    my $errors = "";
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    #
    # Make sure ids aren't identical
    if ($parent_id eq $child_id) {
        return ("ERROR: Both IDs are identical.  Shouldn't be self-referrential.");
    }
    
    #
    # Make sure IDs exist.
    foreach my $id ($parent_id, $child_id) {
	my $GO_ref = $self->GO_id_to_term($id);
	unless (@$GO_ref) {
            return ("ERROR: $id doesn't exist in the existing database.");
        }
    }

    #
    # Make sure desired link doesn't already exist.
    my $existing_links = $self->GO_id_to_child($parent_id);
    my $count = @$existing_links;
    if ($count) {
	foreach my $href (@$existing_links) {
	    my $existing_child = $href->{'child_id'};
            if ($existing_child eq $child_id) {
                $errors = "Error: Child $child_id already exists for parent $parent_id.";
                return ($errors);
            }
        }
    }
    
    $self->{_backend}->do_insert_ontology_link($parent_id, $child_id, $link_type);
    return 0;
}

sub insert_SOP_summary { 
    my ($self, $summary_type, $SOP_type, $start_date, $end_date, $completed_by) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_insert_SOP_summary($summary_type, $SOP_type, $start_date, $end_date, $completed_by);
}

sub insert_role_notes {
   my($self, $role_id, $new_notes, $db) = @_;

   $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
   $db = "common" if(!$db);

   $self->set_textsize(length($new_notes));

   $self->{_backend}->do_insert_role_notes($role_id, $new_notes, $db);
}

sub insert_attribute { 
    my ($self, $info_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_insert_attribute($info_ref);
}

sub insert_asm_feature { 
    my ($self, $feat_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_insert_asm_feature($feat_ref);
}

sub insert_feat_link { 
    my ($self, $parent_id, $child_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_insert_feat_link($parent_id, $child_id);
}

sub insert_ident { 
    my ($self, $ident_ref, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    $self->{_backend}->do_insert_ident($ident_ref, $db);
}

sub insert_step_ev_link {
    my ($self, $step_ev_id, $prop_step_id, $accession) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $self->{_backend}->do_insert_step_ev_link($step_ev_id, $prop_step_id, $accession);
}

sub insert_step_feat_link {
    my ($self, $gene_id, $step_ev_id, $seq_id, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    $self->{_backend}->do_insert_step_feat_link($gene_id, $step_ev_id, $seq_id, $db);
}

sub insert_5prime_partial { 
    my ($self, $gene_id, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    $self->{_backend}->do_insert_5prime_partial($gene_id, $db);
}

sub insert_3prime_partial { 
    my ($self, $gene_id, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    $self->{_backend}->do_insert_3prime_partial($gene_id, $db);
}

##########################
#^ END INSERT FUNCTIONS ^#
##################################################################




######################
#  UPDATE FUNCTIONS  #
######################

sub update_auto_annotate {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    $self->{_backend}->do_update_auto_annotate($gene_id, $db);
}

sub update_completed { 
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    $self->{_backend}->do_update_completed($gene_id, $db);
}

sub update_start_edit { 
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    $self->{_backend}->do_update_start_edit($gene_id, $db);
}

sub update_HMM_curation { 
    my ($self, $HMM_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_evidence_curation($HMM_id);
}

sub update_prosite_curation { 
    my ($self, $prosite_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_evidence_curation($prosite_id);
}

sub update_signalP_curation {
    my ($self, $gene_id, $signalp_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    $self->{_backend}->do_update_attribute_curation($gene_id, $signalp_id, $db);
}

sub update_targetP_curation {
    my ($self, $targetp_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    
    $self->{_backend}->do_update_attribute_curation($targetp_id, $db);
}

sub update_gene_curation { 
    my ($self, $gene_id, $curated_type, $curated, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    my $new = ($curated == 0) ? 1 : 0;
    $self->{_backend}->do_update_gene_curation($gene_id, $curated_type, $new, $db);
}

sub update_COG_curation { 
    my ($self, $gene_id, $curated, $COG_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    $self->{_backend}->do_update_COG_curation($gene_id, $curated, $COG_id, $db);
}

sub update_5prime_partial { 
    my ($self, $gene_id, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    $self->{_backend}->do_update_5prime_partial($gene_id, $db);
}

sub update_3prime_partial { 
    my ($self, $gene_id, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    $self->{_backend}->do_update_3prime_partial($gene_id, $db);
}

sub update_pseudogene_toggle { 
    my ($self, $gene_id, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    $self->{_backend}->do_update_pseudogene_toggle($gene_id, $db);
}

sub update_ident_xref { 
    my ($self, $gene_id, $xref_type, $ident_val, $relrank, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    $self->{_backend}->do_update_ident_xref($gene_id, $xref_type, $ident_val, $relrank, $db);
}

sub update_aliases { 
    my ($self, $gene_id, $hash_ref, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    $self->{_backend}->do_update_aliases($gene_id, $hash_ref, $db);
}

sub update_genomes { 
    my ($self, $hashref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_genomes($hashref);
}

sub update_new_project { 
    my ($self, $hashref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_new_project($hashref);
}

sub update_frameshift { 
    my ($self, $fs_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_frameshift($fs_ref);
}

sub update_evidence { 
    my ($self, $evidence_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_evidence($evidence_ref);
}

sub update_signalP { 
    my ($self, $gene_id, $prediction, $type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_signalP($gene_id, $prediction, $type);
}

sub update_ident { 
    my ($self, $gene_id, $identref, $xref, $changeref, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    $self->{_backend}->do_update_ident($gene_id, $identref, $xref, $changeref, $db);

    #
    # Update ident_xref if necessary (EUK ONLY)
    if($xref->{'xref_yes'}) {
	#
	# Update gene name
	if (defined $xref->{'gene_name'}) {
	    my $alias_ref = $self->gene_id_to_aliases($gene_id, 'gene name', 1, $db);
	    my $count = @$alias_ref;
	    if($count == 0 && $xref->{'gene_name'} ne "DELETE") {
		$self->insert_ident_xref($gene_id, 'gene name', $xref->{'gene_name'}, '', $db);
	    }
	    elsif($xref->{'gene_name'} ne "DELETE") {
		$self->update_ident_xref($gene_id, 'gene name', $xref->{'gene_name'}, 1, $db);
	    }
	    else {
		$self->delete_ident_xref($gene_id, 'gene name', 1, $db);
	    }
	}
	
	#
	# Update product name
	if (defined $xref->{'product_name'}) {
	    my $alias_ref = $self->gene_id_to_aliases($gene_id, 'product name', 1, $db);
	    my $count = @$alias_ref;
	    if($count == 0 && $xref->{'product_name'} ne "DELETE") {
		$self->insert_ident_xref($gene_id, 'product name', $xref->{'product_name'}, '', $db);
	    }
	    elsif($xref->{'product_name'} ne "DELETE") {
		$self->update_ident_xref($gene_id, 'product name', $xref->{'product_name'}, 1, $db);
	    }
	    else {
		$self->delete_ident_xref($gene_id, 'product name', 1, $db);
	    }
	}
	
	#
	# Update gene symbol
	if (defined $xref->{'gene_symbol'}) {
	    my $alias_ref = $self->gene_id_to_aliases($gene_id, 'gene symbol', 1, $db);
	    my $count = @$alias_ref;
	    if($count == 0 && $xref->{'gene_symbol'} ne "DELETE") {
		$self->insert_ident_xref($gene_id, 'gene symbol', $xref->{'gene_symbol'}, '', $db);
	    }
	    elsif($xref->{'gene_symbol'} ne "DELETE") {
		$self->update_ident_xref($gene_id, 'gene symbol', $xref->{'gene_symbol'}, 1, $db);
	    }
	    else {
		$self->delete_ident_xref($gene_id, 'gene symbol', 1, $db);
	    }
	}
	
	#
	# Update EC number
	if (defined $xref->{'ec_number'}) {
	    my $alias_ref = $self->gene_id_to_aliases($gene_id, 'ec number', 1, $db);
	    my $count = @$alias_ref;
	    if($count == 0 && $xref->{'ec_number'} ne "DELETE") {
		$self->insert_ident_xref($gene_id, 'ec number', $xref->{'ec_number'}, '', $db);
	    }
	    elsif($xref->{'ec_number'} ne "DELETE") {
		$self->update_ident_xref($gene_id, 'ec number', $xref->{'ec_number'}, 1, $db);
	    }
	    else {
		$self->delete_ident_xref($gene_id, 'ec number', 1, $db);
	    }
	}
    }
}

sub update_role_notes {
   my($self, $role_id, $new_notes, $db) = @_;

   $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
   $db = "common" if(!$db);

   $self->set_textsize(length($new_notes));

   $self->{_backend}->do_update_role_notes($role_id, $new_notes, $db);
}

sub update_hmm_inter_link { 
    my ($self, $hmm_acc, $rel_acc, $rel_type, $rel_base, $status) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_hmm_inter_link($hmm_acc, $rel_acc, $rel_type, $rel_base, $status);
}

sub update_GO_term {
    my ($self, $GO_id, $name, $type, $definition) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_GO_term($GO_id, $name, $type, $definition);
}

sub update_GO_link {
    my ($self, $child_id, $parent_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_GO_link($child_id, $parent_id);
}

sub update_SOP_summary { 
    my ($self, $summary_type, $SOP_type, $start_date, $end_date, $completed_by) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_SOP_summary($summary_type, $SOP_type, $start_date, $end_date, $completed_by);
}

sub update_subst { 
    my ($self, $subst_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_subst($subst_ref);
}

sub custom_query_update {
    my ($self, $query, @args) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_custom_query_update($query, @args);
}

sub update_asm_feature { 
    my ($self, $gene_id, $feat_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_asm_feature($gene_id, $feat_ref);
}

sub update_transposable_element_coords {
    my ($self, $gene_id, $TE_end5, $TE_end3) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    #
    # TE_end5 and TE_end3 are optional.  If undef(), "", or 0, will ignore them.
    my @coords;
    my $direction = undef();
    
    #
    # If TE coordinates are available, consider them with all 
    # the other child feat coordinates.
    unless ($TE_end5 && $TE_end3) {
	#
        # Get coords from db
	my $feat_ref = $self->gene_id_to_description($gene_id);
	foreach my $href (@$feat_ref) {
	    $TE_end5 = $href->{'end5'};
	    $TE_end3 = $href->{'end3'};
	}
    }
    if ($TE_end5 && $TE_end3) {
        $direction = $self->get_orientation($TE_end5, $TE_end3);
        push (@coords, $TE_end5, $TE_end3);
    }
    
    my $child_ref = $self->gene_id_to_child_id($gene_id);
    foreach my $child_feat (@$child_ref) {
	#
	# Target site duplications not contained within TE	
        if ($child_feat =~ /tsd/i) {
	    next;
	}
	
	my ($end5, $end3);
	my $feat_ref = $self->gene_id_to_description($child_feat);
	foreach my $href (@$feat_ref) {
	    ($end5, $end3) = ($href->{'end5'}, $href->{'end3'});
	}
	
        unless (defined($direction)) {
            $direction = $self->get_orientation($end5, $end3);
        }
        if ($end5 && $end3) {
            push (@coords, $end5, $end3);
        }
    }
    
    @coords = sort {$a<=>$b} @coords;
    #
    # Use to update TE coordinates.
    my ($end5, $end3);
    $end5 = shift @coords;
    $end3 = pop @coords;
    
    my $error; #for return purposes.
    
    if ($end5 && $end3) {
        if ($direction eq '-') {
            ($end5, $end3) = ($end3, $end5);
        }
	my %TE_hash;
	$TE_hash{'end5'} = $end5;
	$TE_hash{'end3'} = $end3;
	$self->update_asm_feature($gene_id, \%TE_hash);
    } 
}

sub update_property { 
    my ($self, $hashref) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_property($hashref);
}


sub update_asm_feature_for_deleted_gene {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_update_asm_feature_for_deleted_gene($gene_id, $seq_id);
}

sub update_property_role_id { 
    my ($self, $prop_def_id, $role_id, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);
    $self->{_backend}->do_update_property_role_id($prop_def_id, $role_id, $db);
}

sub update_property_GO_id { 
    my ($self, $prop_def_id, $GO_id, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);
    $self->{_backend}->do_update_property_GO_id($prop_def_id, $GO_id, $db);
}

=item $obj->update_GO_id($gene_id, $GO_id, $qualifer, $db)

B<Description:> 

Retrieves

B<Parameters:> 

$gene_id - 
$GO_id - 
$db - 
$qualifer - 

B<Returns:> 

Returns

=cut

sub update_GO_id { 
    my ($self, $gene_id, $GO_id, $qualifier, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);
    $self->{_backend}->do_update_GO_id($gene_id, $GO_id, $qualifier, $db);
    #
    # This is run for prok only.  If a new role is inserted, 
    # the toggle for auto_annotate is set to 0.
    $self->{_backend}->do_update_auto_annotate($gene_id, $db);
}

##########################
#^ END UPDATE FUNCTIONS ^#
##################################################################





######################
#  DELETE FUNCTIONS  #
######################

sub delete_partials {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_partials($gene_id);    
}

sub delete_role { 
    my ($self, $gene_id, $role_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    $self->{_backend}->do_delete_role($gene_id, $role_id, $db);
    #
    # This is run for prok only.  If a new role is inserted, 
    # the toggle for auto_annotate is set to 0.
    $self->{_backend}->do_update_auto_annotate($gene_id, $db);    
}

sub delete_GO_id { 
    my ($self, $gene_id, $GO_id, $assigned_by_exclude, $db, $ev_code) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    $self->{_backend}->do_delete_GO_id($gene_id, $GO_id, $assigned_by_exclude, $db, $ev_code);
    #
    # This is run for prok only.  If a new role is inserted, 
    # the toggle for auto_annotate is set to 0.
    $self->{_backend}->do_update_auto_annotate($gene_id, $db);    
}

sub delete_GO_evidence { 
    my ($self, $gene_id, $GO_id, $assigned_by_exclude, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);    

    $self->{_backend}->do_delete_GO_evidence($gene_id, $GO_id, $assigned_by_exclude, $db);
    #
    # This is run for prok only.  If a new role is inserted, 
    # the toggle for auto_annotate is set to 0.
    $self->{_backend}->do_update_auto_annotate($gene_id, $db);
}

sub delete_evidence { 
    my ($self, $gene_id, $acc, $type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    $self->{_backend}->do_delete_evidence($gene_id, $acc, $type);
    #
    # This is run for prok only.  If a new role is inserted, 
    # the toggle for auto_annotate is set to 0.
    $self->{_backend}->do_update_auto_annotate($gene_id);    
}

sub delete_frameshift { 
    my ($self, $fs_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_frameshift($fs_ref);
}

sub delete_ident_xref { 
    my ($self, $gene_id, $xref_type, $relrank, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    $self->{_backend}->do_delete_ident_xref($gene_id, $xref_type, $relrank, $db);
}

sub delete_ident {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_ident($gene_id);    
}

sub delete_selenocysteine { 
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_selenocysteine($gene_id);
}

sub delete_subst { 
    my ($self, $subst_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_subst($subst_ref);
}

sub delete_edit_report {
    my ($self, $report_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_edit_report($report_ref);
}

sub delete_region_evaluation { 
    my ($self, $labinfo_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_region_evaluation($labinfo_ref);
}

sub delete_role_notes {
   my($self, $role_id, $db) = @_;

   $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
   $db = "common" if(!$db);

   $self->{_backend}->do_delete_role_notes($role_id, $db);
}

sub delete_hmm_inter_link { 
    my ($self, $hmm_acc, $rel_acc, $rel_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_hmm_inter_link($hmm_acc, $rel_acc, $rel_type);
}

sub delete_attribute { 
    my ($self, $gene_id, $att_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_attribute($gene_id, $att_type);
}

sub delete_transposable_element { 
    my ($self, $TE_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $TE_components_ref = $self->gene_id_to_child_id($TE_id);
    foreach my $component (@$TE_components_ref) {
        $self->delete_transposable_element_component($TE_id, $component);
    }
    #
    # Remove the actual TE element.
    $self->delete_asm_feature($TE_id);
    $self->delete_ident($TE_id);
    
    my $GO_ref = $self->gene_id_to_GO($TE_id);
    foreach my $GO_id (@$GO_ref) {
	$self->delete_GO_id($TE_id, $GO_id);
    }
}

sub delete_transposable_element_component {
    my ($self, $TE_id, $gene_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    #
    # Make sure not a gene, and delete it from asm_feature
    if($TE_id =~ /te/) {
	$self->delete_asm_feature($TE_id);
	$self->delete_feat_link($TE_id, $gene_id);
    }
}

sub delete_feat_link { 
    my ($self, $parent_id, $child_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_feat_link($parent_id, $child_id);
}

sub delete_ontology_link { 
    my ($self, $child_id, $link_type) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_ontology_link($child_id, $link_type);
}

sub delete_feat_score_evidence {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_feat_score_evidence($gene_id, $seq_id);
}

sub delete_feat_score_ORF_attribute {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_feat_score_ORF_attribute($gene_id, $seq_id);
}

sub delete_score_text {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_score_text($gene_id);
}

sub delete_evidence_for_gene_id {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_evidence_for_gene_id($gene_id, $seq_id);
}

sub delete_ORF_attribute_for_gene_id {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_ORF_attribute_for_gene_id($gene_id, $seq_id);
}

sub delete_ident_for_gene_id {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_ident_for_gene_id($gene_id, $seq_id);
}

sub delete_role_link_for_gene_id {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_role_link_for_gene_id($gene_id, $seq_id);
}

sub delete_frameshift_for_gene_id {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_frameshift_for_gene_id($gene_id);
}

sub delete_asm_feature_for_gene_id {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_backend}->do_delete_asm_feature_for_gene_id($gene_id, $seq_id);
}

sub delete_GO_for_gene_id {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    $self->{_backend}->do_delete_GO_for_gene_id($gene_id);
}

sub delete_5prime_partial { 
    my ($self, $gene_id, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $self->{_backend}->do_delete_5prime_partial($gene_id, $db);
}

sub delete_3prime_partial { 
    my ($self, $gene_id, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    $self->{_backend}->do_delete_3prime_partial($gene_id, $db);
}

sub delete_start_edit { 
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    $self->{_backend}->do_delete_start_edit($gene_id, $db);
}

sub delete_completed { 
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    $self->{_backend}->do_delete_completed($gene_id, $db);
}

##########################
#^ END DELETE FUNCTIONS ^#
##################################################################





#################################

1;
