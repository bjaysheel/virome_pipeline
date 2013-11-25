package Coati::Coati::ChadoCoatiDB;

use strict;
use base qw(Coati::Coati::CoatiDB);
use MLDBM qw(DB_File);
use Fcntl;

use Data::Dumper;

#################### Pathema Survey Subs ######################

sub get_highest_p_user_num {
    my($self) = @_;
    my($query);

    # doing this beacuse the query would be cached and we don't want
    # that!

    my $random_number = int rand(100000);

    $query = "SELECT max(user_number), $random_number FROM pathema_survey ";

    my @results = $self->_get_results($query);

    return(@results);
}

sub get_add_data_to_p_survey_table {
    my($self, $user_num, $question_num, $question_part, $answer, $organism) = @_;

    my($query);

    $query = "INSERT devel..pathema_survey (user_number, question_number, question_part, answer, organism)
              VALUES ($user_num, $question_num, '$question_part', '$answer', '$organism') ";

    $self->_get_results($query);
}

###################################

sub get_cv_term {
    my($self, $term, $ontology) = @_;

    my $query = "";
    if($ontology) {
    $query = "SELECT c.cvterm_id ".
            "FROM cvterm c, cv ".
	    "WHERE c.name = '$term' ".
	    "AND c.cv_id = cv.cv_id ".
	    "AND cv.name = '$ontology' ";
    }
    else {
    $query = "SELECT cvterm_id ".
            "FROM cvterm ".
        "WHERE name = '$term' ";
    }
    return $self->_get_results($query);
}


sub get_cv_term_id_by_accession { # accession_to_cvterm accession_to_cv_term
    my ($self, $accession, $ontology) = @_;
    
    my $query = "";

    if($ontology) {
        $query = "SELECT c.cvterm_id ".
            "FROM cvterm c, cv, dbxref dx ".
            "WHERE dx.accession = '$accession' ".
            "AND c.cv_id = cv.cv_id ".
            "AND cv.name = '$ontology' ".
            "AND c.dbxref_id = dx.dbxref_id";
    }
    else {
        $query = "SELECT c.cvterm_id ".
            "FROM cvterm c, dbxref db ".
            "WHERE c.dbxref_id = db.dbxref_id ".
            "AND db.accession = '$accession'";
    }

    return $self->_get_results($query);
}


sub get_analysis_ids {
    my ($self, $algorithm, $program) = @_;

    my $whereConds = [];
    push(@$whereConds, "algorithm = '$algorithm'") if (defined($algorithm));
    push(@$whereConds, "program = '$program'") if (defined($program));

    my $query = "SELECT analysis_id ".
            "FROM analysis ".
        "WHERE " . join(" AND ", @$whereConds);

    my $res = $self->_get_results_ref($query);
    my @ids = map { $_->[0] } @$res;
    return \@ids;
}

sub get_algorithms_to_analysis_ids {
    my($self, $algorithmList) = @_;
    my $result = [];

    foreach my $alg (@$algorithmList) {
    my $ids = $self->get_analysis_ids($alg);
    push(@$result, @$ids);
    }
    return $result;
}

sub get_feature_id {
    my ($self, $uniquename) = @_;

    my $query = "SELECT h.feature_id ".
            "FROM feature h ".
        "WHERE h.uniquename = '$uniquename' ";

    my @r = $self->_get_results($query);
    #
    # Return a zero value if the accession does not exist in the feature table
    $r[0][0] = 0 if(!@r);
    return @r;
}

sub get_feature_cvtermprop_id {
    my ($self, $feature_cvterm_id) = @_;

    my $query = "SELECT feature_cvtermprop_id ".
            "FROM feature_cvtermprop ".
        "WHERE feature_cvterm_id = $feature_cvterm_id ";

    my $ret = $self->_get_results_ref($query);
    return $ret->[0][0];
}

sub get_auto_incremented_id {
    my ($self, $table, $field) = @_;

    my $query = "SELECT max($field) ".
            "FROM $table ";

    my $res = $self->_get_results_ref($query);
    my $new_id = $res->[0][0] + 1;
    return $new_id;
}

sub row_exists {
    my ($self, $table, $field, $type, $feature_id, $type_id) = @_;

    my $query = "SELECT $field ".
            "FROM $table ".
        "WHERE feature_id = $feature_id ".
        "AND $type = $type_id ";

    my $res = $self->_get_results_ref($query);

    return $res->[0][0];

}

sub get_master_go_id_lookup {
    my ($self, $db) = @_;

    my $query = "SELECT d.accession, c.cvterm_id, c.name ".
            "FROM $db..dbxref d, $db..db, $db..cvterm c, $db..cv ".
        "WHERE db.name = 'GO' ".
        "AND db.db_id = d.db_id ".
        "AND d.dbxref_id = c.dbxref_id ".
        "AND c.cv_id = cv.cv_id ".
        "AND cv.name = 'GO' ";

    return $self->_get_lookup_db($query);
}

sub get_databases {
    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT DISTINCT o.comment ".
            "FROM organism o ".
        "WHERE o.comment IS NOT NULL";

    return $self->_get_results_ref($query);
}

sub get_all_asmbl_info {
    my ($self, @args) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT f.uniquename,'','','','','','','',length(f.residues),d.accession,'',f.timelastmod,fp1.value,1,0 ".
            "FROM feature f, dbxref d, featureprop fp1, feature_dbxref fd ".
            "WHERE f.type_id = 5 ".
            "AND f.feature_id = fd.feature_id ".
            "AND d.dbxrefstr = fd.dbxrefstr ".
            "AND fp1.feature_id = f.feature_id ".
            "AND fp1.type_id = 6 ";

    return $self->_get_results_ref($query);
}




########################
#    DB INPUT_TYPE     #
########################

sub get_db_to_seq_names {
    my($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my @as_id = $self->get_cv_term('assembly');

    my $query = "SELECT a.uniquename, '', 'chromosome', a.residues, a.seqlen ".
            "FROM feature a, organism o ".
        "WHERE a.type_id = $as_id[0][0] ".
        "AND a.organism_id = o.organism_id ".
        "AND o.common_name != 'not known' ";

    return $self->_get_results_ref($query);
}

sub get_db_to_seq_description {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');

    my $query = "SELECT a.uniquename, 'clone_id', 'clone_name', 'seq_group', 'orig_annotation', ".
		        "'tigr_annotation', 'status', 'length', 'final_asmbl', 'gb_acc', 'assignby', ".
				"a.timelastmodified, 'chromo', 'is_public', 'prelim' ".
				"FROM feature a, organism o ".
				"WHERE a.type_id = $as_id[0][0] ".
				"AND a.organism_id = o.organism_id ".
				"AND o.common_name != 'not known' ";

    return $self->_get_results_ref($query);
}

sub get_db_to_organism_name {
    my($self) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT o.genus, o.species, o.common_name ".
				"FROM organism o ".
				"WHERE o.genus != 'not known' ";

    return $self->_get_results_ref($query);
     
}

sub get_db_to_genes {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @ge_id = $self->get_cv_term('gene');
    my @tr_id = $self->get_cv_term('transcript');
    my @cd_id = $self->get_cv_term('CDS');
    my @gp_id = $self->get_cv_term('gene_product_name');
    my @gs_id = $self->get_cv_term('gene_symbol');
    my @df_id = $self->get_cv_term('derives_from');

	my $db_name = $self->get_db_name_from_conf($db);

    my $query = "SELECT t.uniquename, c.residues, fp.value, fp2.value, d2.accession ".
		        "FROM feature a, featureloc fl, feature c, feature_relationship fr, organism o, ".
				"dbxref d2, db db2, feature_dbxref fd2, feature g, feature_relationship tg, feature t ".
				"LEFT JOIN featureprop fp  ON (t.feature_id = fp.feature_id  AND fp.type_id = $gp_id[0][0]) ".
				"LEFT JOIN featureprop fp2 ON (t.feature_id = fp2.feature_id AND fp2.type_id = $gs_id[0][0]) ".
				"WHERE t.feature_id = fr.object_id ".
				"AND fr.subject_id = c.feature_id ".
				"AND t.feature_id = tg.subject_id ".
				"AND tg.object_id = g.feature_id ".
				"AND g.feature_id = fd2.feature_id ".
				"AND fd2.dbxref_id = d2.dbxref_id ".
				"AND d2.db_id = db2.db_id ".
				"AND db2.name = '$db_name' ".
				"AND d2.version = 'locus' ".
				"AND t.feature_id = fl.feature_id ".
				"AND fl.srcfeature_id = a.feature_id ".
				"AND t.organism_id = o.organism_id ".
				"AND o.common_name != 'not known' ".
				"AND t.is_obsolete = 0 ".
				"AND a.type_id = $as_id[0][0] ".
				"AND g.type_id = $ge_id[0][0] ".
				"AND t.type_id = $tr_id[0][0] ".
				"AND c.type_id = $cd_id[0][0] ".
				"AND fr.type_id = $df_id[0][0] ".
				"AND tg.type_id = $df_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_db_to_tRNAs {
    my ($self, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my @as_id = $self->get_cv_term('assembly');
    my @ge_id = $self->get_cv_term('gene');
    my @df_id = $self->get_cv_term('derives_from');
    my @trna_id = $self->get_cv_term('tRNA');
    my @gp_id = $self->get_cv_term('gene_product_name');
    my $db_name = $self->get_db_name_from_conf($db);
    
    
    my $query = "SELECT DISTINCT d.accession, a.uniquename, fl.fmin, fl.fmax, t.uniquename, fp.value, a.residues ". 
	"FROM feature a, featureloc fl, organism o, feature g, feature_relationship fr, dbxref d, feature_dbxref fd, db, feature t, featureprop fp, cvterm cfp ".
	"WHERE t.feature_id = fl.feature_id ".
	"AND fl.srcfeature_id = a.feature_id ".
	"AND t.organism_id = o.organism_id ".
	"AND o.common_name != 'not known' ".
	"AND t.feature_id = fr.subject_id ".
	"AND fr.object_id = g.feature_id ".
	"AND g.feature_id = fd.feature_id ".
	"AND fd.dbxref_id = d.dbxref_id ".
	"AND d.db_id = db.db_id ".
	"AND db.name = '$db_name' ".
	"AND d.version = 'locus' ".
	"AND t.type_id = $trna_id[0][0] ".
	"AND a.type_id = $as_id[0][0] ".
	"AND g.type_id = $ge_id[0][0] ".
	"AND fr.type_id = $df_id[0][0] ".
	"AND fp.type_id= cfp.cvterm_id ".
	"AND cfp.cvterm_id = $gp_id[0][0] ".
	"AND fp.feature_id = t.feature_id ";
    return $self->_get_results_ref($query);
}


sub get_db_to_rRNAs {
    my ($self, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my @as_id = $self->get_cv_term('assembly');
    my @ge_id = $self->get_cv_term('gene');
    my @df_id = $self->get_cv_term('derives_from');
    my @rrna_id = $self->get_cv_term('rRNA');
    my @gp_id = $self->get_cv_term('gene_product_name');
    my $db_name = $self->get_db_name_from_conf($db);


    my $query = "SELECT DISTINCT d.accession, a.uniquename, fl.fmin, fl.fmax, t.uniquename, fp.value, a.residues ". 
    		"FROM feature a, featureloc fl, organism o, feature g, feature_relationship fr, dbxref d, feature_dbxref fd, db, feature t, featureprop fp, cvterm cfp ".
		"WHERE t.feature_id = fl.feature_id ".
		"AND fl.srcfeature_id = a.feature_id ".
		"AND t.organism_id = o.organism_id ".
		"AND o.common_name != 'not known' ".
		"AND t.feature_id = fr.subject_id ".
		"AND fr.object_id = g.feature_id ".
		"AND g.feature_id = fd.feature_id ".
		"AND fd.dbxref_id = d.dbxref_id ".
		"AND d.db_id = db.db_id ".
		"AND db.name = '$db_name' ".
		"AND d.version = 'locus' ".
		"AND t.type_id = $rrna_id[0][0] ".
		"AND a.type_id = $as_id[0][0] ".
		"AND g.type_id = $ge_id[0][0] ".
		"AND fr.type_id = $df_id[0][0] ".
		"AND fp.type_id= cfp.cvterm_id ".
		"AND cfp.cvterm_id = $gp_id[0][0] ".
		"AND fp.feature_id = t.feature_id ";

    return $self->_get_results_ref($query);
}

sub get_db_to_snRNAs {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('snRNA');

    my $query = "SELECT DISTINCT f.uniquename, a.uniquename, 'asmbl_name', fl.fmin, fl.fmax ".
            "FROM $db..cvterm cv, $db..feature f, $db..featureloc fl, $db..feature a ".
        "WHERE f.type_id = cv.cvterm_id ".
        "AND f.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND a.type_id = $as_id[0][0] ".
        "AND f.type_id = $tr_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_db_to_project_description {
    my($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT o.organism_id, o.comment, o.common_name, g.investigator, g.type, g.stage, ".
            "g.locus_sym, g.asmbl_start, g.asmbl_end, g.contact_BA, g.contact_BA_email, g.grant\#, ".
        "g.good_seqs_needed, g.success_percent, g.has_cloneset, g.in_cmr, g.is_public, g.name ".
            "FROM common..genomes g, organism o ".
        "WHERE o.comment = '$db' ".
        "AND g.db = '$db' ";

    return $self->_get_results_ref($query);
}

sub get_db_to_SNP_ref_seqs {
    my($self, $db, $algorithm_names) = @_;

    # TODO - Do something about the $db argument, which is getting ignored.  Perhaps the issue
    #        is that "${db}..tablename" is Sybase-specific syntax?  A number of the other
    #        queries in this file _do_ pay attention to the $db argument, however, so the use
    #        of it needs to be standardized somehow.

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my @seq_cv_id = $self->get_cv_term('assembly');
    my @snp_cv_id = $self->get_cv_term('SNP');
    my @snpCvList = map { $_->[0] } @snp_cv_id;
    my $snpIdWhere = join(',', @snpCvList);
    my $analysis_ids = $self->get_algorithms_to_analysis_ids($algorithm_names);
    my $numAnalysisIds = defined($analysis_ids) ? scalar(@$analysis_ids) : 0;

    my $query = "SELECT DISTINCT f.uniquename, f.seqlen, o.common_name, o.genus, o.species " .
            "FROM feature f, featureloc fl, feature snp, organism o, organism_dbxref od, analysisfeature af, analysis a " .
        "WHERE f.type_id = $seq_cv_id[0][0] " .
        "AND f.feature_id = fl.srcfeature_id " .
        "AND fl.feature_id = snp.feature_id " .
        "AND snp.type_id IN ($snpIdWhere) " .
                "AND o.organism_id = od.organism_id ".
        "AND f.organism_id = o.organism_id ".
        "AND f.feature_id = af.feature_id ".
        "AND af.analysis_id = a.analysis_id ".
        "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) ";

    $query .= "AND af.analysis_id in (" . join(',', @$analysis_ids) . ") " if($numAnalysisIds > 0);
    return $self->_get_results_ref($query);
}

sub get_db_to_SNP_query_organisms {
    my($self, $db, $algorithm_names) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @seq_cv_id = $self->get_cv_term('assembly');
    my @snp_cv_id = $self->get_cv_term('SNP');
    my $analysis_ids = $self->get_algorithms_to_analysis_ids($algorithm_names);
    my $numAnalysisIds = defined($analysis_ids) ? scalar(@$analysis_ids) : 0;

    my $query = "SELECT DISTINCT o.organism_id, o.common_name, o.genus, o.species " .
            "FROM feature f, featureloc fl, feature snp, organism o, analysisfeature af, analysis a " .
        "WHERE f.type_id = $seq_cv_id[0][0] " .
        "AND f.feature_id = fl.srcfeature_id " .
        "AND fl.feature_id = snp.feature_id " .
        "AND snp.type_id = $snp_cv_id[0][0] " .
        "AND f.organism_id = o.organism_id ".
        "AND snp.feature_id = af.feature_id ".
        "AND af.analysis_id = a.analysis_id ".
        "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) ";

    $query .= "AND af.analysis_id in (" . join(',', @$analysis_ids) . ") " if($numAnalysisIds > 0);
    return $self->_get_results_ref($query);
}

sub get_db_to_indel_ref_seqs {
    my($self, $db) = @_;

    my @seq_cv_id = $self->get_cv_term('assembly');
    my @indel_cv_id = $self->get_cv_term('indel');

    my @snp_cv_id1 = $self->get_cv_term('SNP');
    my @snp_cv_id2 = $self->get_cv_term('snp');
    my $snp_cv_id = defined($snp_cv_id1[0][0]) ? $snp_cv_id1[0][0] : $snp_cv_id2[0][0];
    my $ref_rank = defined($snp_cv_id1[0][0]) ? 0 : 1;

    # if the cvterms aren't defined then we can't have any data of this type!
    return [] if (!@indel_cv_id);

    my $query = "SELECT DISTINCT f.uniquename, f.seqlen, o.common_name, o.genus, o.species " .
    "FROM feature f, featureloc fl, feature snp, organism o, analysisfeature af, analysis a " .
    "WHERE f.type_id = $seq_cv_id[0][0] " .
    "AND f.feature_id = fl.srcfeature_id " .
    "AND fl.feature_id = snp.feature_id " .
    "AND snp.feature_id = af.feature_id " .
    "AND af.analysis_id = a.analysis_id " .
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND fl.rank = $ref_rank " .
    "AND snp.type_id = $indel_cv_id[0][0] " .
    "AND f.organism_id = o.organism_id ";

    return $self->_get_results($query);
}

sub get_db_to_indel_query_organisms {
    my($self, $db) = @_;

    my @seq_cv_id = $self->get_cv_term('assembly');
    my @indel_cv_id = $self->get_cv_term('indel');

    my @snp_cv_id1 = $self->get_cv_term('SNP');
    my @snp_cv_id2 = $self->get_cv_term('snp');
    my $snp_cv_id = defined($snp_cv_id1[0][0]) ? $snp_cv_id1[0][0] : $snp_cv_id2[0][0];
    my $ref_rank = defined($snp_cv_id1[0][0]) ? 0 : 1;
    my $qry_rank = defined($snp_cv_id1[0][0]) ? 1 : 0;

    return [] if (!@indel_cv_id);

    my $query = "SELECT DISTINCT o.organism_id, o.common_name, o.genus, o.species " .
    "FROM feature f, featureloc fl, feature snp, organism o, analysisfeature af, analysis a " .
    "WHERE f.type_id = $seq_cv_id[0][0] " .
    "AND f.feature_id = fl.srcfeature_id " .
    "AND fl.feature_id = snp.feature_id " .
    "AND fl.rank = $qry_rank " .
    "AND snp.feature_id = af.feature_id " .
    "AND af.analysis_id = a.analysis_id " .
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND snp.type_id = $indel_cv_id[0][0] " .
    "AND f.organism_id = o.organism_id ";

    return $self->_get_results($query);
}

sub get_db_to_current_seq_id {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @asm_cv_id = $self->get_cv_term('assembly');

    my $query = "SELECT DISTINCT a.uniquename ".
            "FROM $db..cvterm cv, $db..feature a ".
        "WHERE cv.cvterm_id = $asm_cv_id[0][0] ".
        "AND cv.cvterm_id = a.type_id ";

    return $self->_get_results_ref($query);
}

sub get_db_to_max_gene_id {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT MAX(t.uniquename) ".
            "FROM $db..feature t, $db..feature a, $db..featureloc fl ".
        "WHERE t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ";

    return $self->_get_results_ref($query);
}

sub get_db_to_GO {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @tr_id = $self->get_cv_term('transcript');

    my $query = "SELECT t.uniquename, d.accession ".
            "FROM $db..cvterm c, $db..cv, $db..feature t, $db..feature_cvterm fc, $db..dbxref d, $db..db ".
        "WHERE t.feature_id = fc.feature_id ".
        "AND fc.cvterm_id = c.cvterm_id ".
        "AND c.cv_id = cv.cv_id ".
        "AND cv.cv_id = 4 ".
        "AND c.dbxref_id = d.dbxref_id ".
        "AND d.db_id = db.db_id ".
        "AND t.type_id = $tr_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_db_to_frameshifts {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    return undef;

#    my $query = "SELECT fs.feat_name,f.asmbl_id,f.end5,f.end3,fs.att_type, fs.id, fs.date, fs.cpt_date, fs.vrf_date, fs.assignby, fs.labperson, fs.reviewby, fs.curated, fs.fs_accession, fs.comment, i.com_name ".
#	        "FROM $db..asm_feature f, $db..frameshift fs, $db..stan s, $db..ident i ".
#		"WHERE f.asmbl_id = s.asmbl_id ".
#		"AND s.iscurrent = 1 ".
#		"AND f.feat_name = i.feat_name ".
#		"AND f.feat_name = fs.feat_name ".
#		"AND (fs.att_type = 'FS' ".
#		"OR fs.att_type = 'AMB' ".
#		"OR fs.att_type = 'DEG' ".
#		"OR fs.att_type = 'AFS' ".
#		"OR fs.att_type = 'FIXED' ".
#		"OR fs.att_type = 'APM' ".
#		"OR fs.att_type = 'PM') ".
#		"ORDER BY fs.feat_name, fs.date ";
#
#    return $self->_get_results_ref($query);
}

#######################
#^ END DB INPUT_TYPE ^#
##################################################################




############################
#    SEQ_ID INPUT_TYPE     #
############################

sub get_seq_id_to_transcripts {
    my ($self, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @cd_id = $self->get_cv_term('CDS');
    my @gene_cv_id = $self->get_cv_term('gene');
    my @df_id = $self->get_cv_term('derives_from');

    my $query = "SELECT t.uniquename, fl.fmin, fl.fmax, fl.strand, c.residues ".
            "FROM feature a, feature t, feature c, featureloc fl, feature_relationship tc, ".
        "feature g, feature_relationship tg ".
        "WHERE t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND a.uniquename = '$seq_id' ".
        "AND t.feature_id = tc.object_id ".
        "AND tc.subject_id = c.feature_id ".
        "AND t.feature_id = tg.subject_id ".
        "AND g.feature_id = tg.object_id ".
        "AND t.is_analysis = 0 ".
        "AND t.is_obsolete = 0 ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND g.type_id = $gene_cv_id[0][0] ".
        "AND c.type_id = $cd_id[0][0] ".
        "AND tc.type_id = $df_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_seq_id_to_length {
    my($self, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a.seqlen ".
            "FROM feature a ".
        "WHERE a.uniquename = '$seq_id' ";

    return $self->_get_results_ref($query);
}

sub get_seq_id_to_gene_features {
    my($self, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @seq_cv_id = $self->get_cv_term('assembly');
    my @cds_cv_id = $self->get_cv_term('CDS');
    my @prot_cv_id = $self->get_cv_term('polypeptide', 'SO');
    my @prod_cv_id = $self->get_cv_term('derives_from');

    my $query = "SELECT p.uniquename, a.uniquename, a.name, fl.fmin, fl.fmax, fl.strand, p.uniquename, 0, 'gene' ".
            "FROM feature p, feature c, feature a, featureloc fl, feature_relationship fr ".
        "WHERE c.feature_id = fl.feature_id ".
        "AND a.feature_id = fl.srcfeature_id ".
        "AND p.feature_id = fr.subject_id ".
        "AND c.feature_id = fr.object_id ".
        "AND fr.type_id = $prod_cv_id[0][0] ".
        "AND p.type_id = $prot_cv_id[0][0] ".
        "AND a.type_id = $seq_cv_id[0][0] ".
        "AND c.type_id = $cds_cv_id[0][0] ".
        "AND a.uniquename = '$seq_id' ";

    return $self->_get_results_ref($query);

}

sub get_seq_id_to_CDS {
    my ($self,$seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @trans_cv_id = $self->get_cv_term('transcript');
    my @cds_cv_id = $self->get_cv_term('CDS');
    my @gene_cv_id = $self->get_cv_term('gene');
    my @prot_cv_id = $self->get_cv_term('polypeptide', 'SO');
    my @prod_cv_id = $self->get_cv_term('derives_from');
    my @mo_id      = $self->get_cv_term('derives_from');

    my $query = "SELECT g.uniquename, t.uniquename, c.uniquename, p.uniquename, ".
            "fl.fmin, fl.fmax, fl.strand, c.residues, p.residues ".
            "FROM feature a, feature t, feature c, feature g, feature p, featureloc fl, ".
        "feature_relationship pc, feature_relationship ct, feature_relationship tg ".
        "WHERE p.feature_id = pc.subject_id ".
        "AND c.feature_id = pc.object_id ".
        "AND c.feature_id = ct.subject_id ".
        "AND t.feature_id = ct.object_id ".
        "AND t.feature_id = tg.subject_id ".
        "AND g.feature_id = tg.object_id ".
        "AND c.feature_id = fl.feature_id ".
        "AND a.feature_id = fl.srcfeature_id ".
        "AND pc.type_id = $prod_cv_id[0][0] ".
        "AND ct.type_id = $prod_cv_id[0][0] ".
        "AND tg.type_id = $mo_id[0][0] ".
        "AND p.type_id = $prot_cv_id[0][0] ".
        "AND c.type_id = $cds_cv_id[0][0] ".
        "AND t.type_id = $trans_cv_id[0][0] ".
        "AND g.type_id = $gene_cv_id[0][0] ".
        "AND a.uniquename = '$seq_id' ";

    return  $self->_get_results_ref($query);
}

sub get_seq_id_to_exons {
    my ($self,$seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @trans_cv_id = $self->get_cv_term('transcript');
    my @exon_cv_id = $self->get_cv_term('exon');
    my @gene_cv_id = $self->get_cv_term('gene');
#    my @prod_cv_id = $self->get_cv_term('derives_from');
    my @part_cv_id = $self->get_cv_term('part_of');
    my @mo_id      = $self->get_cv_term('derives_from');

    my $query = "SELECT g.uniquename,t.uniquename,e.uniquename,fl.fmin,fl.fmax,fl.strand ".
            "FROM feature a, feature t, feature e, feature g, featureloc fl, ".
        "feature_relationship et, feature_relationship tg ".
        "WHERE e.feature_id = et.subject_id ".
        "AND t.feature_id = et.object_id ".
        "AND t.feature_id = tg.subject_id ".
        "AND g.feature_id = tg.object_id ".
        "AND e.feature_id = fl.feature_id ".
        "AND a.feature_id = fl.srcfeature_id ".
        "AND et.type_id = $part_cv_id[0][0] ".
        #"AND tg.type_id = $prod_cv_id[0][0] ".
        "AND tg.type_id = $mo_id[0][0] ".
        "AND e.type_id = $exon_cv_id[0][0] ".
        "AND t.type_id = $trans_cv_id[0][0] ".
        "AND g.type_id = $gene_cv_id[0][0] ".
        "AND a.uniquename = '$seq_id' ";
#	print STDERR "$query\n";

    return $self->_get_results_ref($query);
}

sub get_seq_id_to_SNPs {
    my($self,$refseq_id,$queryseq_id,$query_org_ids,$analysis_ids) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my $numQueryOrgIds = defined($query_org_ids) ? scalar(@$query_org_ids) : 0;
    my $numAnalysisIds = defined($analysis_ids) ? scalar(@$analysis_ids) : 0;
    my @seq_cv_id = $self->get_cv_term('assembly');
    my @snp_cv_id = $self->get_cv_term('SNP');

    my $query = "SELECT s.uniquename,fl1.fmin,fl1.strand,a2.uniquename,fl2.fmin,fl2.strand ".
            "FROM feature s, feature a1, feature a2, featureloc fl1, featureloc fl2, analysisfeature af, analysis a ".
        "WHERE s.feature_id = fl1.feature_id ".
        "AND s.feature_id = fl2.feature_id ".
        "AND a1.feature_id = fl1.srcfeature_id ".
        "AND a2.feature_id = fl2.srcfeature_id " .
        "AND a1.type_id = $seq_cv_id[0][0] ".
        "AND a2.type_id = $seq_cv_id[0][0] ".
        "AND s.type_id = $snp_cv_id[0][0] ".
        "AND s.feature_id = af.feature_id ".
        "AND fl1.rank != fl2.rank ".
        # ensure that only "traditional" SNPs are retrieved:
        "AND fl2.fmax - fl2.fmin = 1 ".
        "AND fl1.fmax - fl1.fmin = 1 ".
        "AND a1.uniquename = '$refseq_id' ".
        "AND s.feature_id=af.feature_id ".
        "AND af.analysis_id = a.analysis_id ".
        "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) ";

    $query .= "AND a2.uniquename = '$queryseq_id' " if($queryseq_id ne "");
    $query .= "AND a2.organism_id in (" . join(',', @$query_org_ids) . ") " if($numQueryOrgIds > 0);
    $query .= "AND af.analysis_id in (" . join(',', @$analysis_ids) . ") " if($numAnalysisIds > 0);
    return $self->_get_results_ref($query);
}

sub get_seq_id_to_indels{
    my($self,$refseq_id,$queryseq_id,$query_org_ids,$analysis_ids) = @_;

    my $numQueryOrgIds = defined($query_org_ids) ? scalar(@$query_org_ids) : 0;
    my $numAnalysisIds = defined($analysis_ids) ? scalar(@$analysis_ids) : 0;
    my @seq_cv_id = $self->get_cv_term('assembly');
    my @indel_cv_id = $self->get_cv_term('indel');

    my @snp_cv_id1 = $self->get_cv_term('SNP');
    my @snp_cv_id2 = $self->get_cv_term('snp');
    my $snp_cv_id = defined($snp_cv_id1[0][0]) ? $snp_cv_id1[0][0] : $snp_cv_id2[0][0];
    my $ref_rank = defined($snp_cv_id1[0][0]) ? 0 : 1;
    my $qry_rank = defined($snp_cv_id1[0][0]) ? 1 : 0;

    my $query = "SELECT s.uniquename,cv.name,a1.uniquename,fl1.fmin,fl1.fmax,fl1.strand,fl1.residue_info, ".
    "a2.uniquename,fl2.fmin,fl2.fmax,fl2.strand,fl2.residue_info ".
    "FROM feature s, feature a1, feature a2, featureloc fl1, featureloc fl2, analysisfeature af, analysis a, cvterm cv ".
    "WHERE s.feature_id = fl1.feature_id ".
    "AND s.feature_id = fl2.feature_id ".
    "AND a1.feature_id = fl1.srcfeature_id ".
    "AND a2.feature_id = fl2.srcfeature_id " .
    "AND a1.type_id = $seq_cv_id[0][0] ".
    "AND a2.type_id = $seq_cv_id[0][0] ".
    "AND s.type_id = $indel_cv_id[0][0] ".
    "AND s.type_id = cv.cvterm_id " .
    "AND s.feature_id = af.feature_id ".
    "AND af.analysis_id = a.analysis_id ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND fl1.rank != fl2.rank ".
#	"AND fl1.rank = $ref_rank ".
#	"AND fl2.rank = $qry_rank ".
    "AND a1.uniquename = ? ";
    $query .= "AND a2.uniquename = '$queryseq_id' " if($queryseq_id ne "");
    $query .= "AND a2.organism_id in (" . join(',', @$query_org_ids) . ") " if($numQueryOrgIds > 0);
    $query .= "AND af.analysis_id in (" . join(',', @$analysis_ids) . ") " if($numAnalysisIds > 0);

    return $self->_get_results_ref($query, $refseq_id);
}

sub get_indel_id_to_indel_info{
    my($self,$indel_id) = @_;

    my @seq_cv_id = $self->get_cv_term('assembly');
    my @indel_cv_id = $self->get_cv_term('indel');

    my @snp_cv_id1 = $self->get_cv_term('SNP');
    my @snp_cv_id2 = $self->get_cv_term('snp');
    my $snp_cv_id = defined($snp_cv_id1[0][0]) ? $snp_cv_id1[0][0] : $snp_cv_id2[0][0];
    my $ref_rank = defined($snp_cv_id1[0][0]) ? 0 : 1;
    my $qry_rank = defined($snp_cv_id1[0][0]) ? 1 : 0;

    my $query = "SELECT s.uniquename,cv.name,a1.uniquename,fl1.fmin,fl1.fmax,fl1.strand,fl1.residue_info, ".
    "a2.uniquename,fl2.fmin,fl2.fmax,fl2.strand,fl2.residue_info ".
    "FROM feature s, feature a1, feature a2, featureloc fl1, featureloc fl2, analysisfeature af, analysis a, cvterm cv ".
    "WHERE s.feature_id = fl1.feature_id ".
    "AND s.feature_id = fl2.feature_id ".
    "AND a1.feature_id = fl1.srcfeature_id ".
    "AND a2.feature_id = fl2.srcfeature_id " .
    "AND a1.type_id = $seq_cv_id[0][0] ".
    "AND a2.type_id = $seq_cv_id[0][0] ".
    "AND s.uniquename = ? ".
    "AND s.type_id = $indel_cv_id[0][0] ".
    "AND s.type_id = cv.cvterm_id " .
    "AND s.feature_id = af.feature_id ".
    "AND af.analysis_id = a.analysis_id ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND fl1.rank = $ref_rank ".
    "AND fl2.rank = $qry_rank ";

    return $self->_get_results_ref($query, $indel_id);
}

sub get_seq_id_to_gene_symbols {
    my ($self, $seq_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @trans_cv_id = $self->get_cv_term('transcript');
    my @gs_cv_id = $self->get_cv_term('gene_symbol');

    my $query = "SELECT t.uniquename, fp.value ".
            "FROM $db..cvterm c, $db..cvterm c2, $db..feature a, ".
        "$db..feature t, $db..featureloc l, $db..featureprop fp ".
        "WHERE a.uniquename = '$seq_id' ".
        "AND a.feature_id = l.srcfeature_id ".
        "AND l.feature_id = t.feature_id ".
        "AND t.type_id = c.cvterm_id ".
        "AND c.cvterm_id = $trans_cv_id[0][0] ".
        "AND t.feature_id = fp.feature_id ".
        "AND fp.type_id = c2.cvterm_id ".
        "AND c2.cvterm_id = $gs_cv_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_seq_id_to_ec_numbers {
    my ($self, $seq_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT t.uniquename, d.accession ".
            "FROM $db..cv, $db..cvterm c, $db..feature a, $db..feature t, ".
        "$db..featureloc l, $db..dbxref d, $db..feature_cvterm fc, $db..cvterm_dbxref cd ".
        "WHERE a.uniquename = '$seq_id' ".
        "AND a.feature_id = l.srcfeature_id ".
        "AND l.feature_id = t.feature_id ".
        "AND t.feature_id = fc.feature_id ".
        "AND fc.cvterm_id = c.cvterm_id ".
        "AND cv.cv_id = c.cv_id ".
        "AND cv.name = 'EC' ".
        "AND c.cvterm_id = cd.cvterm_id ".
        "AND cd.dbxref_id = d.dbxref_id ";

    return $self->_get_results_ref($query);
}

sub get_ref_seq_posn_to_SNPs{
    my($self,$refseq_id,$refseq_posn,$analysis_ids) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @seq_cv_id = $self->get_cv_term('assembly');
    my @snp_cv_id = $self->get_cv_term('SNP');
    my $numAnalysisIds = defined($analysis_ids) ? scalar(@$analysis_ids) : 0;

    my $query = "SELECT s.uniquename,fl1.fmin,fl1.strand,a2.uniquename,fl2.fmin,fl2.fmax,fl2.strand ".
            "FROM feature s, feature a1, feature a2, featureloc fl1, featureloc fl2, analysisfeature af ".
        "WHERE s.type_id = $snp_cv_id[0][0] ".
        "AND s.feature_id = fl1.feature_id ".
        "AND s.feature_id = fl2.feature_id ".
        "AND a1.feature_id = fl1.srcfeature_id ".
        "AND a2.feature_id = fl2.srcfeature_id " .
        "AND a2.type_id = $seq_cv_id[0][0] " .
        "AND fl1.rank != fl2.rank ".
        "AND a1.uniquename = '$refseq_id' ".
        "AND fl1.fmin = $refseq_posn ".
        "AND s.feature_id = af.feature_id ";

    $query .= "AND af.analysis_id in (" . join(',', @$analysis_ids) . ") " if($numAnalysisIds > 0);
    return $self->_get_results_ref($query);
}

sub get_seq_id_to_sequence{
    my($self,$seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a.residues ".
            "FROM feature a ".
        "WHERE a.uniquename = '$seq_id' ";

    return $self->_get_results_ref($query);
}

# Retrieves all coverage features that overlap with the specified interval (start, stop)
#
sub get_seq_id_to_coverage_data{
    my($self,$seq_id,$data_type,$start,$stop) = @_;
    my @data_type_cv_id = $self->get_cv_term($data_type);
    return undef if (!defined($data_type_cv_id[0][0]));

    my $query = "SELECT cov.residues, fl.fmin, fl.fmax ".
    "FROM feature seq, featureloc fl, feature cov ".
    "WHERE seq.uniquename = ? " .
    "AND seq.feature_id = fl.srcfeature_id " .
    "AND fl.feature_id = cov.feature_id " .
    "AND cov.type_id = $data_type_cv_id[0][0] " .
    (defined($start) ? "AND fl.fmax >= $start " : "" ) .
    (defined($stop) ? "AND fl.fmin <= $stop " : "" ) .
    "ORDER BY fl.fmin ASC ";

    return $self->_get_results_ref($query,$seq_id);
}

sub get_seq_id_to_sub_to_final {
    my ($self, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "";
    return $self->_get_results_ref($query);
#    my $query = "SELECT asmbl_id, asm_lend, asm_rend, sub_asmbl_id, sub_asm_lend, sub_asm_rend ".
#	        "FROM sub_to_final ".
#		"WHERE asmbl_id = ? ";
#
#    return $self->_get_results_ref($query,  $seq_id);
}

sub get_seq_id_to_new_transposable_element_id {
    my ($self, $seq_id, $feat_type) = @_;
    return undef;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "";
    return $self->_get_results_ref($query);
}

############# ?????????????????????????????????? look at function below too.
sub get_asmbl_id_to_genes {
    my ($self, $asmbl_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT f1.uniquename, f2.uniquename, fl.fmin, fl.fmax, fl.strand, fl.phase ".
            "FROM feature f1, feature f2, feature f3, featureloc fl, feature_relationship fr1, feature_relationship fr2 ".
            "WHERE f1.feature_id = fr1.subject_id ".
            "AND f2.feature_id = fr1.object_id ".
            "AND f1.feature_id = fr2.subject_id ".
            "AND f3.feature_id = fr2.object_id ".
            "AND f1.type_id = 17 ".
            "AND f2.type_id = 13 ".
            "AND f3.type_id = 5 ".
            "AND fl.feature_id = f2.feature_id ".
            "AND fl.srcfeature_id = f3.feature_id ";

    return $self->_get_results_ref($query);
}

sub get_seq_id_to_genes {
    my ($self, $seq_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my @seq_cv_id = $self->get_cv_term('assembly');
    my @trans_cv_id  = $self->get_cv_term('transcript');
    my @cds_cv_id = $self->get_cv_term('CDS');
    my @prot_cv_id = $self->get_cv_term('polypeptide', 'SO');
    my @gs_cv_id = $self->get_cv_term('gene_symbol');
    my @gpn_cvterm_id = $self->get_cv_term('gene_product_name');
    my @prod_cv_id = $self->get_cv_term('derives_from');

    my $query = "SELECT t.uniquename, 'pub_locus', gpn.value, fp.value, '', 'seq_id', fl.fmin, fl.fmax, fl.strand, fl.phase ".
            "FROM $db..feature a, $db..feature c, $db..feature p, $db..featureloc fl, ".
        "$db..feature_relationship tc, $db..feature_relationship cp, $db..featureprop gpn, ".
        "$db..feature t ".
	"LEFT JOIN (SELECT * FROM $db..featureprop fp WHERE fp.type_id = $gs_cv_id[0][0]) AS fp ON (t.feature_id = fp.feature_id) ".
        "WHERE t.feature_id = fl.feature_id ".
        "AND a.feature_id = fl.srcfeature_id ".
        "AND t.feature_id = tc.object_id ".
        "AND tc.subject_id = c.feature_id ".
        "AND c.feature_id = cp.object_id ".
        "AND p.feature_id = cp.subject_id ".
        "AND tc.type_id = $prod_cv_id[0][0] ".
        "AND cp.type_id = $prod_cv_id[0][0] ".
        "AND t.type_id = $trans_cv_id[0][0] ".
        "AND c.type_id = $cds_cv_id[0][0] ".
        "AND p.type_id = $prot_cv_id[0][0] ".
        "AND a.type_id = $seq_cv_id[0][0] ".
        "AND a.uniquename = '$seq_id' ".
	"AND gpn.feature_id = t.feature_id ".
	"AND gpn.type_id = $gpn_cvterm_id[0][0]";

    my $res = $self->_get_results_ref($query);

    my $query2 = "SELECT t.uniquename, d.accession ".
            "FROM $db..feature a, $db..feature t, $db..featureloc fl, ".
            "$db..feature_cvterm fc, $db..cvterm_dbxref cd, $db..dbxref d, $db..db db ".
        "WHERE t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.type_id = $trans_cv_id[0][0] ".
        "AND a.type_id = $seq_cv_id[0][0] ".
        "AND a.uniquename = '$seq_id' ".
        "AND t.feature_id = fc.feature_id ".
        "AND fc.cvterm_id = cd.cvterm_id ".
        "AND cd.dbxref_id = d.dbxref_id ".
        "AND d.db_id = db.db_id ".
        "AND db.name = 'EC' ";

    my $res2 = $self->_get_results_ref($query2);

	### assign ec_number to hash with query2 results above
    my %e;
    for(my $j=0; $j<@$res2; $j++) {
		$e{$res2->[$j][0]}->{'ec_number'} = $res2->[$j][1];
    }

    my $query3 = "SELECT t.uniquename, d.accession ".
            "FROM $db..feature a, $db..feature t, $db..featureloc fl, ".
        "$db..feature_dbxref fd, $db..dbxref d ".
        "WHERE t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.type_id = $trans_cv_id[0][0] ".
        "AND a.type_id = $seq_cv_id[0][0] ".
        "AND a.uniquename = '$seq_id' ".
        "AND t.feature_id = fd.feature_id ".
        "AND fd.dbxref_id = d.dbxref_id ".
        "AND d.version = 'locus' ";

    my $res3 = $self->_get_results_ref($query3);
	
	### assign pub_locus to hash from query3 results above
    my %l;
    for(my $j=0; $j<@$res3; $j++) {
		$l{$res3->[$j][0]}->{'pub_locus'} = $res3->[$j][1];
	}
	
	### assign ec_number and pub_locus from the pre-constructed hashes above
    my %s;
    for(my $i=0; $i<@$res; $i++) {
		$s{$i}->{'gene_id'}->{$res->[$i][0]}->{'ec_number'} = $e{$res->[$i][0]}->{'ec_number'};
		$s{$i}->{'gene_id'}->{$res->[$i][0]}->{'pub_locus'} = $l{$res->[$i][0]}->{'pub_locus'};

    }
	
	### do final assignment of the ec_number and pub_locus to the final hashref
    for(my $j=0; $j<keys %s; $j++) {
		my $gene_ref = $s{$j}->{'gene_id'};
		foreach my $gene_id (sort keys %$gene_ref) {
			$res->[$j][1]  = $gene_ref->{$gene_id}->{'pub_locus'};
			$res->[$j][4] = $gene_ref->{$gene_id}->{'ec_number'};
			$res->[$j][5] = $seq_id;
			
			# correcting for interbase coordinates on fmin
			$res->[$j][6] += 1;

			### determine what strand the gene is on and switch end5 / end3 if needed
			my $end5 = $res->[$j][6];
			my $end3 = $res->[$j][7];
			my $strand = $res->[$j][8];
			if($strand < 0) {
				$res->[$j][6] = $end3;
				$res->[$j][7] = $end5;
				
			}
		}
    }	
    return $res;
}

###########################
#^ END SEQ_ID INPUT_TYPE ^#
##################################################################





######################
# GENE_ID INPUT_TYPE #
######################

sub get_gene_id_to_legacy_data {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @cd_id = $self->get_cv_term('CDS');
    my @df_id = $self->get_cv_term('derives_from');

    my $query = "SELECT d.accession, '', '' ".
            "FROM $db..feature a, $db..feature t, $db..feature c, $db..featureloc fl, $db..dbxref d, ".
        "$db..feature_relationship tc ".
        "WHERE a.feature_id = fl.srcfeature_id ".
        "AND fl.feature_id = t.feature_id ".
        "AND t.uniquename = '$gene_id' ".
        "AND t.feature_id = tc.object_id ".
        "AND tc.subject_id = c.feature_id ".
        "AND c.dbxref_id = d.dbxref_id ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND c.type_id = $cd_id[0][0] ".
        "AND tc.type_id = $df_id[0][0] ";

    my ($legacy_db, $legacy_seq_id) = split(/\_/,$gene_id);
    my $res = $self->_get_results_ref($query);
    for(my $i=0; $i<@$res; $i++) {
    $res->[$i][1] = $legacy_seq_id;
    $res->[$i][2] = $legacy_db;
    }
    return $res;
}

sub get_gene_id_to_GO {
    my ($self, $gene_id, $db, $GO_id, $assigned_by_exclude) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @dt_id = $self->get_cv_term('date');
    my @ab_id = $self->get_cv_term('assignby');

    my $query = "SELECT dbx.accession, cv.name, cvt.name, 'id', fcp2.value, fcp1.value, '' ".
            "FROM feature t, feature a, featureloc fl, cvterm cvt, cv cv, dbxref dbx, ".
        "feature_cvterm fc ".
        "LEFT JOIN (SELECT *
                            FROM feature_cvtermprop fcp1, cvterm c
                            WHERE c.cvterm_id = fcp1.type_id AND c.name = 'assignby')
                            AS fcp1 ON (fc.feature_cvterm_id = fcp1.feature_cvterm_id) ".
        "LEFT JOIN (SELECT *
                            FROM feature_cvtermprop fcp2, cvterm c
                            WHERE c.cvterm_id = fcp2.type_id AND c.name = 'date')
                            AS fcp2 ON (fc.feature_cvterm_id = fcp2.feature_cvterm_id) ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = fc.feature_id ".
        "AND fc.cvterm_id = cvt.cvterm_id ".
        "AND cvt.cv_id = cv.cv_id ".
        "AND  cv.name IN ('process', 'function', 'component','biological_process', 'molecular_function', 'cellular_component', 'GO') ".
        "AND cvt.dbxref_id = dbx.dbxref_id ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND a.type_id = $as_id[0][0] ";
	
    #
    # If a GO id was passed in, constrain the query
    $query .= "AND dbx.accession = '$GO_id' " if($GO_id);

    return $self->_get_results_ref($query);
}


sub get_org_id_to_go_terms{
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @dt_id = $self->get_cv_term('date');
    my @ab_id = $self->get_cv_term('assignby');
    my $fnamelookup = $self->get_feature_id_to_gene_name_lookup();

    my $query = "SELECT t.feature_id, dbx.accession, cv.name, cvt.name  ".
        "FROM feature t, cvterm cvt, cv cv, dbxref dbx, ".
        "feature_cvterm fc ".
        "WHERE t.organism_id = $db ".
        "AND t.feature_id = fc.feature_id ".
        "AND fc.cvterm_id = cvt.cvterm_id ".
        "AND cvt.cv_id = cv.cv_id ".
        "AND cv.name IN ('process', 'function', 'component', 'biological_process', 'molecular_function', 'cellular_component', 'GO') ".
        "AND cvt.dbxref_id = dbx.dbxref_id ".
        "AND t.type_id = $tr_id[0][0] ";

    my @results = $self->_get_results($query);
    for(my $i = 0; $i < scalar @results; $i++){
        $results[$i][0] = $fnamelookup->{$results[$i][0]}->[1];
    }

    return (\@results);
}

sub get_gene_id_to_GO_evidence {
    my ($self, $gene_id, $GO_id, $id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT cs.synonym, fcp.value ".
        "FROM dbxref d, cvterm c, feature t, feature_cvterm fc, cv cv, ".
        "feature_cvtermprop fcp, cvtermsynonym cs ".
        "WHERE d.accession = '$GO_id' ".
        "AND t.uniquename = '$gene_id' ".
        "AND t.feature_id = fc.feature_id ".
        "AND fc.cvterm_id = c.cvterm_id ".
        "AND c.cv_id = cv.cv_id ".
        "AND cv.name IN ('process', 'function', 'component', 'biological_process', 'molecular_function', 'cellular_component', 'GO') ".
        "AND c.dbxref_id = d.dbxref_id ".
        "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ".
        "AND fcp.type_id = cs.cvterm_id ";

    my $ret = $self->_get_results_ref($query);

    my @f;
    for(my $i=0; $i<@$ret; $i++) {
        #
        # If a WITH value exists for the GO evidence, it must be parsed out
        if($ret->[$i][1] =~ /WITH/g) {
                my ($e,$w) = split(/WITH/, $ret->[$i][1]);
                $f[$i][0] = $ret->[$i][0];
                $f[$i][1] = $e;
                $f[$i][2] = $w
                }
        else {
                $f[$i][0] = $ret->[$i][0];
                $f[$i][1] = $ret->[$i][1];
                $f[$i][2] = "";
        }
    }
    return \@f;
}

sub get_gene_id_to_protein {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $gene_id = $self->get_handle_gene_id($gene_id, $db) if($gene_id =~ /^ORF/);
    $db = $self->{_db} if (!$db);
    my @trans_cv_id = $self->get_cv_term('transcript');
    my @cds_cv_id = $self->get_cv_term('CDS');
    my @prot_cv_id = $self->get_cv_term('polypeptide', 'SO');
    my @df_id = $self->get_cv_term('derives_from');
    my @po_id = $self->get_cv_term('part_of');

    my $query = "SELECT p.residues, t.uniquename, p.uniquename ".
		"FROM feature t, feature p, feature_relationship tp ".
		"WHERE t.feature_id = tp.object_id ".
		"AND tp.subject_id = p.feature_id ".
		"AND tp.type_id = $po_id[0][0] ".
		"AND t.type_id = $trans_cv_id[0][0] ".
		"AND p.type_id = $prot_cv_id[0][0] ".
		"AND t.is_obsolete = 0 ".
		"AND t.uniquename = '$gene_id' ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_protein_id {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $gene_id = $self->get_handle_gene_id($gene_id, $db) if($gene_id =~ /^ORF/);
    $db = $self->{_db} if (!$db);

    my @trans_cv_id = $self->get_cv_term('transcript');
    my @cds_cv_id = $self->get_cv_term('CDS');
    my @prot_cv_id = $self->get_cv_term('polypeptide', 'SO');
    my @po_id = $self->get_cv_term('part_of');

    my $query = "SELECT p.uniquename ".
		        "FROM feature t, feature p, feature_relationship tp ".
				"WHERE t.feature_id = tp.object_id ".
				"AND tp.subject_id = p.feature_id ".
				"AND t.type_id = $trans_cv_id[0][0] ".
				"AND p.type_id = $prot_cv_id[0][0] ".
				"AND tp.type_id = $po_id[0][0] ".
				"AND t.uniquename = '$gene_id' ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_transcript {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @tr_id = $self->get_cv_term('transcript');

    my $query = "SELECT t.residues ".
            "FROM $db..feature t ".
        "WHERE t.type_id = $tr_id[0][0] ".
        "AND t.uniquename = '$gene_id' ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_CDS {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @tr_id = $self->get_cv_term('transcript');
    my @cd_id = $self->get_cv_term('CDS');
    my @df_id = $self->get_cv_term('derives_from');

    my $query = "SELECT c.residues, t.uniquename, c.uniquename ".
		"FROM feature t, feature c, feature_relationship tc ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = tc.object_id ".
        "AND tc.subject_id = c.feature_id ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND c.type_id = $cd_id[0][0] ".
		"AND tc.type_id = $df_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_predictions {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my @glim_cv_id = $self->get_cv_term('glimmer');
    my @gscan_cv_id = $self->get_cv_term('genscan');
    my @gmark_cv_id = $self->get_cv_term('genmarkhmm');

    my $query = "SELECT t.uniquename, fl.fmin, fl.fmax ".
            "FROM $db..feature t, $db..featureloc fl ".
        "WHERE t.feature_id = fl.feature_id ".
        "AND t.type_id IN ($glim_cv_id[0][0], $gscan_cv_id[0][0], $gmark_cv_id[0][0]) ".
        "AND t.uniquename = ? ";

    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_nucleotide_evidence {
    my ($self, $gene_id, $ev_type, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "";
#    my $query = "SELECT id, ev_type, accession, end5, end3, rel_end5, rel_end3, m_lend, m_rend, curated, date, assignby, change_log, save_history, method, per_id, per_sim, score, db, pvalue, domain_score, expect_domain, total_score, expect_whole ".
#                "FROM evidence ".
#		"WHERE feat_name = ? ";
#
#    if($ev_type) {
#	$query .= "AND LOWER(ev_type) = LOWER('$ev_type') ";
#    }
#    $query .= "ORDER BY accession, end5 ";

    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_exons {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @ex_id = $self->get_cv_term('exon');
    my @po_id = $self->get_cv_term('part_of');

    my $query = "SELECT e.uniquename, te.fmin, te.fmax ".
            "FROM $db..feature a, $db..feature t, $db..feature e, $db..featureloc fl, ".
        "$db..featureloc te, $db..feature_relationship fr ".
        "WHERE a.feature_id = fl.srcfeature_id ".
        "AND fl.feature_id = t.feature_id ".
        "AND t.uniquename = '$gene_id' ".
        "AND t.feature_id = fr.object_id ".
        "AND fr.subject_id = e.feature_id ".
        "AND e.feature_id = te.feature_id ".
        "AND te.srcfeature_id = a.feature_id ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND e.type_id = $ex_id[0][0] ".
        "AND fr.type_id = $po_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_fam_id {
    my ($self, $gene_id) = @_;
    return undef;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT f.uniquename ".
    "FROM feature m, feature f, featureloc fl, analysisfeature af, analysis a ".
    "WHERE f.feature_id = af.feature_id ".
    "AND af.analysis_id = a.analysis_id ".
    "AND f.feature_id = fl.srcfeature_id ".
    "AND m.feature_id = fl.feature_id ".
    "AND a.program = 'paralogous_domain' ".
#	"AND a.program = 'paralogs_family' ".
#	"AND a.description NOT LIKE \"%OBSOLETE%\" ".
    "AND a.description IS NULL ".
    "AND m.uniquename = ? ".
    "UNION ALL ".
    "SELECT f.uniquename ".
    "FROM feature m, feature f, featureloc fl, analysisfeature af, analysis a, feature_relationship pc, feature_relationship ct, feature_relationship tg, feature c, feature t, feature g, dbxref d ".
    "WHERE f.feature_id = af.feature_id ".
    "AND af.analysis_id = a.analysis_id ".
    "AND f.feature_id = fl.srcfeature_id ".
    "AND m.feature_id = fl.feature_id ".
    "AND a.program = 'paralogous_domain' ".
    #"AND a.program = 'paralogs_family' ".
#	"AND a.description NOT LIKE \"%OBSOLETE%\" ".
    "AND a.description IS NULL ".
    "AND m.feature_id = pc.subject_id ".
    "AND c.feature_id = pc.object_id ".
    "AND pc.type_id = 24 ".
    "AND c.feature_id = ct.subject_id ".
    "AND t.feature_id = ct.object_id ".
    "AND ct.type_id = 24 ".
    "AND t.feature_id = tg.subject_id ".
    "AND g.feature_id = tg.object_id ".
    "AND tg.type_id = 24 ".
    "AND g.type_id = 54 ".
    "AND c.type_id = 55 ".
    "AND t.type_id = 56 ".
    "AND m.type_id = 16 ".
    "AND g.dbxref_id = d.dbxref_id ".
    "AND d.accession = ? ";

    my $ret = $self->_get_results_ref($query, $gene_id, $gene_id);

    if(scalar(@$ret) == 0){
    my @orgs = $self->get_databases();

    for (my $i=0; $i<@orgs; $i++) {
        my $db = $orgs[$i][0];
        my $query = "SELECT  f.uniquename ".
        "FROM feature m, feature f, featureloc fl, analysisfeature af, analysis a, ".
        "feature_relationship pc, feature_relationship ct, feature_relationship tg, ".
        "feature c, feature t, feature g, dbxref d, $db..asm_feature f1, $db..phys_ev pe, ".
        "$db..clone_info cl, $db..asm_feature f2, $db..feat_link l ".
        "WHERE f.feature_id = af.feature_id ".
        "AND af.analysis_id = a.analysis_id ".
        "AND f.feature_id = fl.srcfeature_id ".
        "AND m.feature_id = fl.feature_id ".
        "AND a.program = 'paralogs_family' ".
        "AND m.feature_id = pc.subject_id ".
        "AND c.feature_id = pc.object_id ".
        "AND pc.type_id = 24 ".
        "AND c.feature_id = ct.subject_id ".
        "AND t.feature_id = ct.object_id ".
        "AND ct.type_id = 24 ".
        "AND t.feature_id = tg.subject_id ".
        "AND g.feature_id = tg.object_id ".
        "AND tg.type_id = 24 ".
        "AND g.type_id = 54 ".
        "AND c.type_id = 55 ".
        "AND t.type_id = 56 ".
        "AND m.type_id = 16 ".
        "AND g.dbxref_id = d.dbxref_id ".
        "AND d.accession = f2.feat_name ".
        "AND f2.feat_name = l.parent_feat ".
        "AND f1.feat_name = l.child_feat  ".
        "AND f1.feat_type = 'model'  ".
        "AND f1.feat_name = pe.feat_name ".
        "AND pe.ev_type = 'working'  ".
        "AND f1.asmbl_id = cl.asmbl_id ".
        "AND f1.feat_name = ? ";

        my $proj_ref = $self->_get_results_ref($query,$gene_id);

        push(@$ret, @$proj_ref);
    }
      }
    return $ret;
}

sub get_gene_id_to_HMM_acc {
    my ($self, $gene_id, $HMM_acc) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @cd_id = $self->get_cv_term('CDS');
    my @pr_id = $self->get_cv_term('polypeptide', 'SO');
    my @tr_id = $self->get_cv_term('transcript');
    my @ma_id = $self->get_cv_term('match_part');
    my @df_id = $self->get_cv_term('derives_from');

    my $query = "SELECT h.uniquename ".
            "FROM feature t, feature c, feature p, feature m, feature h, ".
        "feature_relationship tc, feature_relationship cp, featureloc pm, featureloc mh ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = tc.object_id ".
        "AND tc.subject_id = c.feature_id ".
        "AND c.feature_id = cp.object_id ".
        "AND cp.subject_id = p.feature_id ".
        "AND p.feature_id = pm.srcfeature_id ".
        "AND pm.feature_id = m.feature_id ".
        "AND m.feature_id = mh.feature_id ".
        "AND mh.srcfeature_id = h.feature_id ".
        "AND mh.rank = 0 ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND c.type_id = $cd_id[0][0] ".
        "AND p.type_id = $pr_id[0][0] ".
        "AND m.type_id = $ma_id[0][0] ".
        "AND tc.type_id = $df_id[0][0] ".
        "AND cp.type_id = $df_id[0][0] ";

    $query .=   "AND h.uniquename != '$HMM_acc' " if($HMM_acc);

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_interpro {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "";
#    my $query = "SELECT e.accession ".
#	        "FROM evidence e " .
#                "WHERE feat_name = ? " .
#                "AND ev_type = ? ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_GO_suggestions {
    my ($self, $gene_id, $db1, $db2) = @_;

    return undef;

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

sub get_gene_id_to_prosite {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @cd_id = $self->get_cv_term('CDS');
    my @pr_id = $self->get_cv_term('polypeptide', 'SO');
    my @tr_id = $self->get_cv_term('transcript');
    my @ma_id = $self->get_cv_term('match_part');
    my @po_id = $self->get_cv_term('part_of');

   my $query = "SELECT h.uniquename, h.uniquename, af.rawscore, 'curated', pm.fmin, pm.fmax, pm.fmin, pm.fmax, 'assignby', 'date' ".
            "FROM feature a, feature t, feature p, feature m, feature h, featureloc fl, ".
        "feature_relationship tp, featureloc pm, featureloc mh, ".
        "analysis an, analysisfeature af ".
        "WHERE t.feature_id = fl.feature_id ".
        "AND t.uniquename = '$gene_id' ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = tp.object_id ".
        "AND tp.subject_id = p.feature_id ".
        "AND p.feature_id = pm.srcfeature_id ".
        "AND pm.feature_id = m.feature_id ".
        "AND m.feature_id = mh.feature_id ".
        "AND mh.srcfeature_id = h.feature_id ".
        "AND mh.rank = 0 ".
        "AND an.program = 'ps_scan' ".
        "AND an.analysis_id = af.analysis_id ".
        "AND af.feature_id = m.feature_id ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND p.type_id = $pr_id[0][0] ".
        "AND m.type_id = $ma_id[0][0] ".
        "AND tp.type_id = $po_id[0][0] ".
		"GROUP BY h.uniquename, pm.fmin ";

    return $self->_get_results_ref($query);
}

sub get_prosite_lookup_data {
	my ($self) = @_;
	my %prosite;
	my $file = $ENV{PROSITE_LOOKUP_FILE};
	my $dbm = tie %prosite, 'MLDBM', $file, O_RDONLY or die "Can't tie lookup file - $file: $!";
	return \%prosite;
}

sub get_gene_id_to_evidence {
    my($self, $gene_id, $ev_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    return undef;
    my $query = "";
    return $self->_get_results_ref($query);
#    my $query = "SELECT id, ev_type, accession, end5, end3, rel_end5, rel_end3, m_lend, m_rend, curated, date, assignby, change_log, save_history, method " .
#                "FROM evidence " .
#                "WHERE feat_name = ? ";
#
#    if($ev_type) {
#	$query .= "AND LOWER(ev_type) = LOWER('$ev_type') ";
#    }
#
#    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_partial_gene_toggles {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @fp_id = $self->get_cv_term('five_prime_partial');
    my @tp_id = $self->get_cv_term('three_prime_partial');

    my $query = "SELECT fp1.value, fp2.value ".
 		        "FROM $db..featureloc fl, $db..feature a, ".
				"$db..feature t ".
				"LEFT JOIN featureprop fp1  ON (t.feature_id = fp1.feature_id  AND fp1.type_id = $fp_id[0][0]) ".
				"LEFT JOIN featureprop fp2  ON (t.feature_id = fp2.feature_id  AND fp2.type_id = $tp_id[0][0]) ".
				"WHERE t.uniquename = '$gene_id' ".
				"AND t.feature_id = fl.feature_id ".
				"AND fl.srcfeature_id = a.feature_id ".
				"AND t.type_id = $tr_id[0][0] ".
				"AND a.type_id = $as_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_pseudogene_toggle {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @pg_id = $self->get_cv_term('is_pseudogene');

    my $query = "SELECT fp.value ".
            "FROM $db..featureprop fp, $db..featureloc fl, $db..feature t, $db..feature a ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = fp.feature_id ".
        "AND fp.type_id = $pg_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND a.type_id = $as_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_curated_structure {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @gs_id = $self->get_cv_term('gene_structure_curated');

    my $query = "SELECT fp.value ".
            "FROM $db..featureprop fp, $db..featureloc fl, $db..feature t, $db..feature a ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = fp.feature_id ".
        "AND fp.type_id = $gs_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND a.type_id = $as_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_curated_annotation {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @ga_id = $self->get_cv_term('gene_annotation_curated');

    my $query = "SELECT fp.value ".
            "FROM $db..featureprop fp, $db..featureloc fl, $db..feature t, $db..feature a ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = fp.feature_id ".
        "AND fp.type_id = $ga_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND a.type_id = $as_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_targetP {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @tp_id = $self->get_cv_term('targetp');

    return undef;
    my $query = "SELECT 'location', 'cmso_scores', 'rc_value', 'network', 'cmso_cutoffs', 'curated', 'id' ".
            "FROM feature t, feature a, featureprop fp1, featureloc fl ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = fp1.feature_id ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND fp1.type_id = $tp_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_synonyms {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    return undef;
    my $query = "";
    return $self->_get_results_ref($query);
#    my $query = "SELECT g.syn_feat_name ".
#	        "FROM gene_synonym g ".
#		"WHERE g.feat_name = ? ";
#
#    return $self->_get_results_ref($query, $gene_id);
}

sub get_synonym_to_gene_id {
    my($self, $syn_feat_name) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    return undef;
    my $query = "";
    return $self->_get_results_ref($query);
#    my $query = "SELECT g.feat_name ".
#		"FROM gene_synonym g ".
#		"WHERE g.syn_feat_name = ? ";
#
#    return $self->_get_results_ref($query, $syn_feat_name);
}

sub get_gene_id_to_pI {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @pp_id = $self->get_cv_term('polypeptide');
    my @pi_id = $self->get_cv_term('pI');

    my $query = "SELECT fp.value ".
            "FROM $db..feature t, $db..featureprop fp, $db..feature a, $db..featureloc fl, ".
        "$db..feature p, $db..feature_relationship fr ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = fr.object_id ".
        "AND fr.subject_id = p.feature_id ".
        "AND p.feature_id = fp.feature_id ".
        "AND fp.type_id = $pi_id[0][0] ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND p.type_id = $pp_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_lipoprotein {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @pp_id = $self->get_cv_term('polypeptide');
    my @lp_id = $self->get_cv_term('lipo_membrane_protein');

    my $query = "SELECT fp.value ".
            "FROM $db..feature t, $db..featureprop fp, $db..feature a, $db..featureloc fl, ".
        "$db..feature p, $db..feature_relationship fr ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = fr.object_id ".
        "AND fr.subject_id = p.feature_id ".
        "AND p.feature_id = fp.feature_id ".
        "AND fp.type_id = $lp_id[0][0] ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND p.type_id = $pp_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_outer_membrane_protein {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @pp_id = $self->get_cv_term('polypeptide');
    my @om_id = $self->get_cv_term('outer_membrane_protein');

    my $query = "SELECT fp.value ".
            "FROM $db..feature t, $db..featureprop fp, $db..feature a, $db..featureloc fl, ".
        "$db..feature p, $db..feature_relationship fr ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = fr.object_id ".
        "AND fr.subject_id = p.feature_id ".
        "AND p.feature_id = fp.feature_id ".
        "AND fp.type_id = $om_id[0][0] ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND p.type_id = $pp_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_transmembrane_regions {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    my @tr_id = $self->get_cv_term('transcript');
    my @pp_id = $self->get_cv_term('polypeptide');
    my @ls_id = $self->get_cv_term('transmembrane_region');

	my $query = "SELECT '', fl.fmin, fl.fmax ".
		        "FROM feature t, feature p, feature l, feature_relationship tp, featureloc fl, analysis a, analysisfeature af ".
				"WHERE t.uniquename = '$gene_id' ".
				"AND p.feature_id = tp.subject_id ".
				"AND tp.object_id = t.feature_id ".
				"AND p.feature_id = fl.srcfeature_id ".
				"AND fl.feature_id = l.feature_id ".
				"AND l.feature_id = af.feature_id ".
				"AND af.analysis_id = a.analysis_id ".
				"AND a.name = 'tmhmm' ".
				"AND t.type_id = $tr_id[0][0] ".
				"AND p.type_id = $pp_id[0][0] ".
				"AND l.type_id = $ls_id[0][0] ";

	my $ret = $self->_get_results_ref($query);
	
	# build a string with the coordinates with specific delimeters
	# this is so legacy databases are also supported
	my $coord_str = "";
	for(my $i=0; $i<@$ret; $i++) {
		my $fmin = $ret->[$i][1];
		my $fmax = $ret->[$i][2];
		$coord_str .= "$fmin-$fmax:";
	}
	# remove trailing (:)
	$coord_str =~ s/\:$//;
	
	# set the value for the arrayref
	$ret->[0][0] = $coord_str;
	return $ret;
}

sub get_gene_id_to_start_confidence {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @pp_id = $self->get_cv_term('polypeptide');
    my @sc_id = $self->get_cv_term('start_confidence');

    my $query = "SELECT fp.value ".
            "FROM $db..feature t, $db..featureprop fp, $db..feature a, $db..featureloc fl, ".
        "$db..feature p, $db..feature_relationship fr ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = fr.object_id ".
        "AND fr.subject_id = p.feature_id ".
        "AND p.feature_id = fp.feature_id ".
        "AND fp.type_id = $sc_id[0][0] ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND p.type_id = $pp_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_molecular_weight {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @pp_id = $self->get_cv_term('polypeptide');
    my @mw_id = $self->get_cv_term('MW');

    my $query = "SELECT fp.value ".
            "FROM $db..feature t, $db..featureprop fp, $db..feature a, $db..featureloc fl, ".
        "$db..feature p, $db..feature_relationship fr ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = fr.object_id ".
        "AND fr.subject_id = p.feature_id ".
        "AND p.feature_id = fp.feature_id ".
        "AND fp.type_id = $mw_id[0][0] ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND p.type_id = $pp_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_seleno_cysteine {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @pp_id = $self->get_cv_term('polypeptide');
    my @sc_id = $self->get_cv_term('seleno_cysteine');

    my $query = "SELECT fp.value ".
            "FROM $db..feature t, $db..featureprop fp, $db..feature a, $db..featureloc fl, ".
        "$db..feature p, $db..feature_relationship fr ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = fr.object_id ".
        "AND fr.subject_id = p.feature_id ".
        "AND p.feature_id = fp.feature_id ".
        "AND fp.type_id = $sc_id[0][0] ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND p.type_id = $pp_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_programmed_frameshifts {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @pp_id = $self->get_cv_term('polypeptide');
    my @pf_id = $self->get_cv_term('programmed frameshift');

    my $query = "SELECT fp.value ".
            "FROM $db..feature t, $db..featureprop fp, $db..feature a, $db..featureloc fl, ".
        "$db..feature p, $db..feature_relationship fr ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = fr.object_id ".
        "AND fr.subject_id = p.feature_id ".
        "AND p.feature_id = fp.feature_id ".
        "AND fp.type_id = $pf_id[0][0] ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND p.type_id = $pp_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_signalP {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @pp_id = $self->get_cv_term('polypeptide');
    my @sp_id = $self->get_cv_term('signal_peptide');
    my @cs_id = $self->get_cv_term('cleavage_site');

    my $query = "SELECT fl2.fmax, 'HMM-prediction', fp1.value, 'HMM-SAprob', fp6.value, 0, ".
            "'id', fp3.value, fp4.value, fp2.value, fp5.value, fl3.fmax ".
        "FROM $db..feature a, $db..featureloc fl, $db..feature t, $db..feature_relationship fr, ".
        "$db..featureloc fl2, $db..featureloc fl3, $db..feature p, ".

        "$db..feature sp ".
        "LEFT JOIN (SELECT *
                            FROM $db..featureprop fp1, $db..cvterm c
                            WHERE fp1.type_id = c.cvterm_id AND c.name = 'signal_probability')
                            AS fp1 ON (sp.feature_id = fp1.feature_id) ".
        "LEFT JOIN (SELECT *
                            FROM $db..featureprop fp4, $db..cvterm c
                            WHERE fp4.type_id = c.cvterm_id AND c.name = 's-score')
                            AS fp4 ON (sp.feature_id = fp4.feature_id ) ".
        "LEFT JOIN (SELECT *
                            FROM $db..featureprop fp5, $db..cvterm c
                            WHERE fp5.type_id = c.cvterm_id AND c.name = 's-mean')
                            AS fp5 ON (sp.feature_id = fp5.feature_id ), ".

        "$db..feature cs ".
        "LEFT JOIN (SELECT *
                            FROM $db..featureprop fp2, $db..cvterm c
                            WHERE fp2.type_id = c.cvterm_id AND c.name = 'y-score')
                            AS fp2 ON (cs.feature_id = fp2.feature_id ) ".
        "LEFT JOIN (SELECT *
                            FROM $db..featureprop fp3, $db..cvterm c
                            WHERE fp3.type_id = c.cvterm_id AND c.name = 'c-score')
                            AS fp3 ON (cs.feature_id = fp3.feature_id ) ".
        "LEFT JOIN (SELECT *
                            FROM $db..featureprop fp6, $db..cvterm c
                            WHERE fp6.type_id = c.cvterm_id AND c.name = 'max_cleavage_site_probability')
                            AS fp6 ON (cs.feature_id = fp6.feature_id ) ".

        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = fr.object_id ".
        "AND fr.subject_id = p.feature_id ".
        "AND p.feature_id = fl2.srcfeature_id ".
        "AND fl2.feature_id = sp.feature_id ".
        "AND p.feature_id = fl3.srcfeature_id ".
        "AND fl3.feature_id = cs.feature_id ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND p.type_id = $pp_id[0][0] ".
        "AND sp.type_id = $sp_id[0][0] ".
        "AND cs.type_id = $cs_id[0][0] ".
        "AND a.type_id = $as_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_evidence2 {
    my($self, $gene_id, $ev_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    return undef;
    my $query = "";
    return $self->_get_results_ref($query);
#    my $query = "SELECT e.accession, e.rel_end5, e.rel_end3, '' ".
#                "FROM evidence e ".
#		"WHERE e.feat_name = ? ";
#    if($ev_type) {
#	$query .= "AND e.ev_type = '$ev_type' ";
#    }
#
#    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_child_id {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    return undef;
    my $query = "";
    return $self->_get_results_ref($query);
#    my $query = "SELECT child_feat ".
#	        "FROM feat_link ".
#	        "WHERE parent_feat = ? ";
#
#    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_transposable_element {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    return undef;
    my $query = "";
    return $self->_get_results_ref($query);
#    my $query = "SELECT a.asmbl_id, a.end5, a.end3, a.feat_type ".
#	        "FROM asm_feature a ".
#	        "WHERE a.feat_name = ? ";
#
#    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_COG_curation {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    return undef;
    if($gene_id !~ /\d+\.m\d+/) {
    $gene_id = $self->get_handle_gene_id($gene_id, $db);
    }

    my $query = "";
    return $self->_get_results_ref($query);
#    my $query = "SELECT o.score, o.score2, o.score3, o.curated, o.id ".
#                "FROM $db..ORF_attribute o ".
#                "WHERE o.feat_name = ? ".
#	        "AND o.att_type = ? ";
#
#    return $self->_get_results_ref($query, $gene_id, 'COG_curation');
}

sub get_gene_id_to_primary_descriptions {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    return undef;
    if($gene_id !~ /\d+\.t\d+/) {
    $gene_id = $self->get_handle_gene_id($gene_id, $db);
    }

    my $query = "";
    return $self->_get_results_ref($query);
#    my $ret;
#    my @types = ("product name", "gene name", "gene symbol", "ec number");
#
#    my $query = "SELECT x.ident_val ".
#	        "FROM $db..ident_xref x ".
#		"WHERE x.feat_name = ? ".
#		"AND x.xref_type = ? ".
#		"AND x.relrank = 1 ";
#
#    for(my $i=0; $i<@types; $i++) {
#	my $x = $self->_get_results_ref($query, $gene_id, $types[$i]);
#	$ret->[0][$i] = $x->[0][0];
#    }
#    return $ret;
}

sub get_gene_id_to_gene_attributes {
    my ($self, $gene_id) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    return undef;
}

sub get_gene_id_to_ec_numbers {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    $gene_id = $self->get_handle_gene_id($gene_id, $db) if($gene_id =~ /^ORF/);

    my $query = "SELECT d.accession ".
            "FROM $db..feature t, $db..cvterm c, $db..cv, $db..feature_cvterm fc, ".
        "$db..cvterm_dbxref cd, $db..dbxref d, $db..db, $db..feature a, $db..featureloc fl ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND t.feature_id = fc.feature_id ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND a.type_id = $as_id[0][0] ".
        "AND fc.cvterm_id = c.cvterm_id ".
        "AND c.cv_id = cv.cv_id ".
        "AND cv.name = 'EC' ".
        "AND c.cvterm_id = cd.cvterm_id ".
        "AND cd.dbxref_id = d.dbxref_id ".
        "AND d.db_id = db.db_id ".
        "AND db.name = 'EC' ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_secondary_structure {
    my($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @pp_id = $self->get_cv_term('polypeptide');
    my @pi_id1 = $self->get_cv_term('sequence_secondary_structure');
    my @pi_id2 = $self->get_cv_term('sequence_secondary_structure');
    my @pi_id3 = $self->get_cv_term('sequence_secondary_structure');


    my $query = "SELECT fp1.value, fp2.value, fp3.value ".
            "FROM $db..feature t, $db..featureprop fp1, $db..featureprop fp2, $db..featureprop fp3, $db..feature a, $db..featureloc fl, ".
        "$db..feature p, $db..feature_relationship fr ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = fr.object_id ".
        "AND fr.subject_id = p.feature_id ".
        "AND p.feature_id = fp1.feature_id ".
        "AND p.feature_id = fp2.feature_id ".
        "AND p.feature_id = fp3.feature_id ".
        "AND fp1.type_id = $pi_id1[0][0] ".
        "AND fp2.type_id = $pi_id2[0][0] ".
        "AND fp3.type_id = $pi_id3[0][0] ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND p.type_id = $pp_id[0][0] ";

    return $self->_get_results_ref($query);



    my $query2 = "SELECT s1.score, s2.score, s3.score " .
                "FROM ORF_attribute a, feat_score s1, feat_score s2, feat_score s3 " .
                "WHERE a.feat_name = ? " .
                "AND a.id = s1.input_id " .
                "AND a.id = s2.input_id " .
                "AND a.id = s3.input_id " .
                "AND s1.score_id = ? " .
                "AND s2.score_id = ? " .
                "AND s3.score_id = ? ";

    return $self->_get_results_ref($query2, $gene_id, 50279, 50280, 50281);
}

sub get_gene_id_to_BER {
    my($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

	return undef;

    # missing e.per_id, e.per_sim, e.date
    my @match_cv_id = $self->get_cv_term_id('match_part', 'SO');
    my @per_sim_cv_id = $self->get_cv_term_id('percent_similarity');

    my $query = "SELECT f2.uniquename, fl.fmin, fl.fmax, af.pidentity, fp.value "
    ."FROM analysis a, analysisfeature af, feature f, featureloc fl, feature f2, featureprop fp "
    #."WHERE a.name = \"BER_analysis\" "
    ."WHERE a.name = 'ber' "
    ."AND a.analysis_id = af.analysis_id "
    ."AND af.feature_id = f.feature_id "
    ."AND f.feature_id = fl.feature_id "
    ."AND fl.srcfeature_id = f2.feature_id "
    ."AND f.type_id = $match_cv_id[0][0] "
    ."AND fl.rank = 0 "
    ."AND af.feature_id = fp.feature_id "
    ."AND fp.type_id = $per_sim_cv_id[0][0] ";

    $query .= "ORDER BY f2.uniquename ";

    my @results = $self->_get_results($query);
    return @results;
}

sub get_gene_id_to_prints {
    my($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @cd_id = $self->get_cv_term('CDS');
    my @pr_id = $self->get_cv_term('polypeptide', 'SO');
    my @tr_id = $self->get_cv_term('transcript');
    my @ma_id = $self->get_cv_term('match_part');
    my @df_id = $self->get_cv_term('derives_from');

    my $query = "SELECT h.uniquename, mh.fmin, mh.fmax ".
            "FROM feature a, feature t, feature c, feature p, feature m, feature h, featureloc fl, ".
        "feature_relationship tc, feature_relationship cp, featureloc pm, featureloc mh, ".
        "analysis an, analysisfeature af ".
        "WHERE t.feature_id = fl.feature_id ".
        "AND t.uniquename = '$gene_id' ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = tc.object_id ".
        "AND tc.subject_id = c.feature_id ".
        "AND c.feature_id = cp.object_id ".
        "AND cp.subject_id = p.feature_id ".
        "AND p.feature_id = pm.srcfeature_id ".
        "AND pm.feature_id = m.feature_id ".
        "AND m.feature_id = mh.feature_id ".
        "AND mh.srcfeature_id = h.feature_id ".
        "AND mh.rank = 0 ".
        "AND an.program = 'FPrintScan' ".
        "AND an.analysis_id = af.analysis_id ".
        "AND af.feature_id = m.feature_id ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND c.type_id = $cd_id[0][0] ".
        "AND p.type_id = $pr_id[0][0] ".
        "AND m.type_id = $ma_id[0][0] ".
        "AND tc.type_id = $df_id[0][0] ".
        "AND cp.type_id = $df_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_prodom {
    my($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @cd_id = $self->get_cv_term('CDS');
    my @pr_id = $self->get_cv_term('polypeptide', 'SO');
    my @tr_id = $self->get_cv_term('transcript');
    my @ma_id = $self->get_cv_term('match_part');
    my @df_id = $self->get_cv_term('derives_from');

    my $query = "SELECT h.uniquename, mh.fmin, mh.fmax ".
            "FROM feature a, feature t, feature c, feature p, feature m, feature h, featureloc fl, ".
        "feature_relationship tc, feature_relationship cp, featureloc pm, featureloc mh, ".
        "analysis an, analysisfeature af ".
        "WHERE t.feature_id = fl.feature_id ".
        "AND t.uniquename = '$gene_id' ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = tc.object_id ".
        "AND tc.subject_id = c.feature_id ".
        "AND c.feature_id = cp.object_id ".
        "AND cp.subject_id = p.feature_id ".
        "AND p.feature_id = pm.srcfeature_id ".
        "AND pm.feature_id = m.feature_id ".
        "AND m.feature_id = mh.feature_id ".
        "AND mh.srcfeature_id = h.feature_id ".
        "AND mh.rank = 0 ".
        "AND an.program = 'BlastProDom' ".
        "AND an.analysis_id = af.analysis_id ".
        "AND af.feature_id = m.feature_id ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND c.type_id = $cd_id[0][0] ".
        "AND p.type_id = $pr_id[0][0] ".
        "AND m.type_id = $ma_id[0][0] ".
        "AND tc.type_id = $df_id[0][0] ".
        "AND cp.type_id = $df_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_profiles {
    my($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @cd_id = $self->get_cv_term('CDS');
    my @pr_id = $self->get_cv_term('polypeptide', 'SO');
    my @tr_id = $self->get_cv_term('transcript');
    my @ma_id = $self->get_cv_term('match_part');
    my @df_id = $self->get_cv_term('derives_from');

    my $query = "SELECT h.uniquename, mh.fmin, mh.fmax ".
            "FROM feature a, feature t, feature c, feature p, feature m, feature h, featureloc fl, ".
        "feature_relationship tc, feature_relationship cp, featureloc pm, featureloc mh, ".
        "analysis an, analysisfeature af ".
        "WHERE t.feature_id = fl.feature_id ".
        "AND t.uniquename = '$gene_id' ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = tc.object_id ".
        "AND tc.subject_id = c.feature_id ".
        "AND c.feature_id = cp.object_id ".
        "AND cp.subject_id = p.feature_id ".
        "AND p.feature_id = pm.srcfeature_id ".
        "AND pm.feature_id = m.feature_id ".
        "AND m.feature_id = mh.feature_id ".
        "AND mh.srcfeature_id = h.feature_id ".
        "AND mh.rank = 0 ".
        "AND an.program = 'ProfileScan' ".
        "AND an.analysis_id = af.analysis_id ".
        "AND af.feature_id = m.feature_id ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND c.type_id = $cd_id[0][0] ".
        "AND p.type_id = $pr_id[0][0] ".
        "AND m.type_id = $ma_id[0][0] ".
        "AND tc.type_id = $df_id[0][0] ".
        "AND cp.type_id = $df_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_COG {
    my($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @cd_id = $self->get_cv_term('CDS');
    my @pr_id = $self->get_cv_term('polypeptide', 'SO');
    my @tr_id = $self->get_cv_term('transcript');
    my @ma_id = $self->get_cv_term('match_part');
    my @df_id = $self->get_cv_term('derives_from');

    my $query = "SELECT h.uniquename, mh.fmin, mh.fmax ".
            "FROM feature a, feature t, feature c, feature p, feature m, feature h, featureloc fl, ".
        "feature_relationship tc, feature_relationship cp, featureloc pm, featureloc mh, ".
        "analysis an, analysisfeature af ".
        "WHERE t.feature_id = fl.feature_id ".
        "AND t.uniquename = '$gene_id' ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = tc.object_id ".
        "AND tc.subject_id = c.feature_id ".
        "AND c.feature_id = cp.object_id ".
        "AND cp.subject_id = p.feature_id ".
        "AND p.feature_id = pm.srcfeature_id ".
        "AND pm.feature_id = m.feature_id ".
        "AND m.feature_id = mh.feature_id ".
        "AND mh.srcfeature_id = h.feature_id ".
        "AND mh.rank = 0 ".
        "AND an.program = 'NCBI_COG' ".
        "AND an.analysis_id = af.analysis_id ".
        "AND af.feature_id = m.feature_id ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND c.type_id = $cd_id[0][0] ".
        "AND p.type_id = $pr_id[0][0] ".
        "AND m.type_id = $ma_id[0][0] ".
        "AND tc.type_id = $df_id[0][0] ".
        "AND cp.type_id = $df_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_frameshifts {
    my($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    return undef;
}

sub get_gene_id_to_frameshift_locations {
    my($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @fr = $self->get_cv_term_id('frameshift');
    my $fs_id = $fr[0][0];

    my $query = "SELECT f.feature_id, f.uniquename, t.feature_id, t.uniquename, fl.fmin, fl.fmax, f.seqlen, f.organism_id, fl.srcfeature_id, f.is_obsolete,f.is_analysis ".
        "FROM feature f, feature t, featureloc fl, feature_relationship fr ".
        "WHERE t.uniquename = ? ".
        "AND t.feature_id = fr.object_id ".
        "AND fr.subject_id = f.feature_id ".
        "AND f.type_id = ? ".
        "AND fl.feature_id = f.feature_id";

#    my $query = "SELECT id, feat_name, assignby, curated, fs_accession, date, att_type, comment, cpt_date, vrf_date, labperson, reviewby " .
#                "FROM frameshift " .
#                "WHERE feat_name = ? ".
#		"ORDER BY date DESC ";

    return $self->_get_results_ref($query, $gene_id,$fs_id);
}

sub get_gene_id_to_clusters {
    my($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @pr_id = $self->get_cv_term('polypeptide', 'SO');

    my $query = "SELECT c.feature_id, c.uniquename " .
	"FROM dbxref x1, feature_dbxref fd, feature p, featureloc fl, feature c, analysisfeature af, analysis a " .
        "WHERE x1.version = \"locus\" " .
	"AND x1.accession = ? " .
	"AND x1.dbxref_id = fd.dbxref_id " .
	"AND fd.feature_id = p.feature_id " .
	"AND p.type_id = $pr_id[0][0]" .
	"AND p.feature_id = fl.srcfeature_id ".
	"AND fl.feature_id = c.feature_id " .
	"AND c.feature_id = af.feature_id " .
	"AND af.analysis_id = a.analysis_id ".
	"AND a.name like '%clusters%' ";

    return $self->_get_results_ref($query, $gene_id);
}

############################
#^ END GENE_ID INPUT_TYPE ^#
##################################################################

############################
# FRAMESHIFT_ID INPUT_TYPE #
############################
sub get_frameshift_id_to_frameshift_location {
    my($self, $frameshift_id) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my @tr = $self->get_cv_term_id('transcript');
    my $trans_id = $tr[0][0];

    my $query = "SELECT f.feature_id, f.uniquename, t.feature_id, t.uniquename, fl.fmin, fl.fmax, fl.srcfeature_id, f.is_obsolete, fl.strand ".
        "FROM feature f, feature t, featureloc fl, feature_relationship fr ".
        "WHERE f.uniquename = ? ".
        "AND t.feature_id = fr.object_id ".
        "AND fr.subject_id = f.feature_id ".
        "AND t.type_id = ? ".
        "AND t.is_obsolete =0 ".
        "AND fl.feature_id = f.feature_id";

    return $self->_get_results_ref($query, $frameshift_id,$trans_id);
}


######################
# EXON_ID INPUT_TYPE #
######################

sub get_exon_id_to_CDS {
    my ($self, $exon_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @asm_cv_id = $self->get_cv_term('assembly');
    my @exon_cv_id = $self->get_cv_term('exon');
    my @trans_cv_id = $self->get_cv_term('transcript');
    my @cds_cv_id = $self->get_cv_term('CDS');
    my @prod_cv_id = $self->get_cv_term('derives_from');
    my @part_cv_id = $self->get_cv_term('part_of');

    my $query = "SELECT c.uniquename, cfl.fmin, cfl.fmax ".
            "FROM $db..feature a, $db..feature t, $db..feature e, $db..feature c, $db..featureloc cfl, ".
        "$db..feature_relationship et, $db..feature_relationship tc ".
        "WHERE e.feature_id = et.subject_id ".
        "AND et.object_id = t.feature_id ".
        "AND et.type_id = $part_cv_id[0][0] ".
        "AND t.feature_id = tc.object_id ".
        "AND tc.subject_id = c.feature_id ".
        "AND tc.type_id = $prod_cv_id[0][0] ".
        "AND a.type_id = $asm_cv_id[0][0] ".
        "AND t.type_id = $trans_cv_id[0][0] ".
        "AND e.type_id = $exon_cv_id[0][0] ".
        "AND c.type_id = $cds_cv_id[0][0] ".
        "AND c.feature_id = cfl.feature_id ".
        "AND cfl.srcfeature_id = a.feature_id ".
        "AND e.uniquename = '$exon_id' ";

    return $self->_get_results_ref($query);
}

############################
#^ END EXON_ID INPUT_TYPE ^#
##################################################################

###################################
#     ANALYSIS_ID INPUT_TYPE      #
###################################

sub get_analysis_id_to_feature_ids {
     my($self, $analysis_id, $feature_type) = @_;
     $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

     my $query = "";

     if ( $feature_type ) {
	 my @feature_type_id = $self->get_cv_term($feature_type);
	 $query = qq| SELECT f.feature_id
                      FROM feature f, analysisfeature af
                      WHERE af.feature_id = f.feature_id
                      AND af.analysis_id = ?
                      AND f.type_id = ? |;
	 return $self->_get_results_ref($query, $analysis_id, $feature_type_id[0][0]);
     }
     else {
	 $query = qq| SELECT f.feature_id
                      FROM feature f, analysisfeature af
                      WHERE af.feature_id = f.feature_id
                      AND af.analysis_id = ?
                    |;
	 return $self->_get_results_ref($query, $analysis_id);
     }
}

sub get_feature_id_to_featureloc_feature_ids {
     my($self, $feature_id) = @_;
     $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

     my $query = qq| SELECT fl.srcfeature_id, f.uniquename, c.name
                     FROM featureloc fl, feature f, cvterm c
                     WHERE fl.srcfeature_id = f.feature_id
                       AND f.type_id = c.cvterm_id
                       AND fl.feature_id = ?
                   |;

    return $self->_get_results_ref($query, $feature_id); 
}

# return the transcript_id(s?) associated with a polypeptide
sub get_polypeptide_id_to_transcript_id {
     my($self, $feature_id) = @_;
     $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

     # SQL query requires polypeptide_id as subject_id,
     # cvterm_id of 'part_of'
     # cvterm_id of 'transcript'
     my @po_id = $self->get_cv_term('part_of');
     my @tr_id = $self->get_cv_term('transcript');

     my $query = qq| SELECT o.feature_id, o.uniquename
                     FROM feature_relationship fr, feature o
                     WHERE fr.subject_id = ?
                       AND fr.object_id = o.feature_id
                       AND fr.type_id = ?
                       AND o.type_id = ?
                   |;

    return $self->_get_results_ref($query, $feature_id, $po_id[0][0], $tr_id[0][0]);
}

sub get_feature_id_to_EC_numbers {
     my($self, $feature_id) = @_;
     $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

     my @ec_id = $self->get_cv_id('EC');

     my $query = qq| SELECT d.accession, c.name
                     FROM feature_cvterm fc, cvterm c, dbxref d
                     WHERE fc.cvterm_id = c.cvterm_id
                       AND fc.feature_id = ?
                       AND c.cv_id = ?
                       AND d.dbxref_id = c.dbxref_id
                   |;

    return $self->_get_results_ref($query, $feature_id, $ec_id[0][0]);
}

sub get_feature_id_to_featureprops {
     my($self, $feature_id, $name) = @_;
     $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

     my $query = "";

     if ( $name ) {
	 my @type_id = $self->get_cv_term( $name );
	 $query = qq| SELECT fp.featureprop_id, c.name, fp.value, fp.rank
                      FROM featureprop fp, cvterm c
                      WHERE c.cvterm_id = fp.type_id
                        AND fp.feature_id = ?
                        AND c.cvterm_id = ?
                    |;
	 return $self->_get_results_ref($query, $feature_id, $type_id[0][0]);
     }
     else {
	 $query = qq| SELECT fp.featureprop_id, c.name, fp.value, fp.rank
                      FROM featureprop fp, cvterm c
                      WHERE c.cvterm_id = fp.type_id
                        AND fp.feature_id = ?
                    |;
	 return $self->_get_results_ref($query, $feature_id);
     }
}

sub get_taxon_organism_info {
     my($self) = @_;
     $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

     my $query = qq| SELECT d.accession, o.organism_id, o.common_name
                     FROM organism o, organism_dbxref od, dbxref d, db db
                     WHERE o.organism_id = od.organism_id
                       AND od.dbxref_id = d.dbxref_id
                       AND d.db_id = db.db_id
                       AND db.name = 'taxon'
                   |;

    return $self->_get_results_ref($query,);
}


sub get_organism_id_to_features {
    my ( $self, $organism_id, $type) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = '';
    if ( $type ) {
	my @type_id = $self->get_cv_term( $type );
	defined ($type_id[0][0]) || die "No cvterm defined for type $type";

	$query = qq| SELECT f.feature_id, f.organism_id, f.name, f.uniquename, f.type_id, fl.fmin, fl.fmax, fl.strand 
                     FROM feature f, featureloc fl 
                     WHERE f.organism_id = ?
                       AND f.type_id = ?
                       AND fl.feature_id = f.feature_id
                   |;
	return $self->_get_results_ref($query, $organism_id, $type_id[0][0], );
    }
    else {
	$query = qq| SELECT f.feature_id, f.organism_id, f.name, f.uniquename, f.type_id, fl.fmin, fl.fmax, fl.strand 
                     FROM feature f, featureloc fl 
                     WHERE f.organism_id = ?
                       AND fl.feature_id = f.feature_id
                   |;
	return $self->_get_results_ref($query, $organism_id );
    }
}


sub get_gene_id_to_feature {
     my ( $self, $uniquename ) = @_;
     $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

     my $query = qq| SELECT f.feature_id, f.organism_id, f.name, f.uniquename, f.type_id, fl.fmin, fl.fmax, fl.strand 
                     FROM feature f, featureloc fl 
                     WHERE f.uniquename = ?
                       AND fl.feature_id = f.feature_id
                   |;

    return $self->_get_results_ref( $query, $uniquename );
}

sub get_retrieve_feature_cvterms {
     my ($self, $cv, $feature_id) = @_;
     $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

     my $query = "";

     if ( $feature_id ) {
	 $query = qq| SELECT cv.name as cv, fc.feature_id, fc.feature_cvterm_id, c.cvterm_id, c.name, d.accession
                      FROM feature_cvterm fc, cvterm c, cv cv, dbxref d
                      WHERE fc.cvterm_id = c.cvterm_id
                        AND c.cv_id = cv.cv_id
                        AND c.dbxref_id = d.dbxref_id
                        AND cv.name = ?
                        AND fc.feature_id = ?
                    |;
	 return $self->_get_results_ref($query, $cv, $feature_id);
     }
     elsif ( $cv ) {
	 $query = qq| SELECT cv.name as cv, fc.feature_id, fc.feature_cvterm_id, c.cvterm_id, c.name, d.accession
                      FROM feature_cvterm fc, cvterm c, cv cv, dbxref d
                      WHERE fc.cvterm_id = c.cvterm_id
                        AND c.cv_id = cv.cv_id
                        AND c.dbxref_id = d.dbxref_id
                        AND cv.name = ?
                    |;
	 return $self->_get_results_ref($query, $cv);
     }
     else {
	 $query = qq| SELECT cv.name as cv, fc.feature_id, fc.feature_cvterm_id, c.cvterm_id, c.name, d.accession
                      FROM feature_cvterm fc, cvterm c, cv cv, dbxref d
                      WHERE fc.cvterm_id = c.cvterm_id
                        AND c.cv_id = cv.cv_id
                        AND c.dbxref_id = d.dbxref_id
                    |;
	 return $self->_get_results_ref($query);
     }
}


# return (most likely 1) feature in a tag/organism/analysis combination
sub get_match_feature_tag_to_match_features {
     my ( $self, $featureprop_value, $organism_id, $analysis_id ) = @_;
     $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

     my $query = qq| SELECT fp.value, fl.srcfeature_id, f.uniquename, f.organism_id, af.analysis_id
                     FROM featureprop fp, featureloc fl, feature f, analysisfeature af
                     WHERE fp.value = ?
                       AND fp.feature_id = fl.feature_id
                       AND fl.srcfeature_id = f.feature_id
                       AND f.organism_id = ?
                       AND fp.feature_id = af.feature_id
                       AND af.analysis_id = ?
                   |;

    return $self->_get_results_ref( $query, $featureprop_value, $organism_id, $analysis_id );
}

# INSERT, DELETE, or UPDATE a featureprop.value of the provided type
# actual table update is performed by do_update_featureprop_value()
sub do_update_featureprop {
    my ($self, $gene_id, $type, $value) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @cvterm_id = $self->get_cv_term($type);
    my @feature_id = $self->get_feature_id($gene_id);
    my $delete_row = 1 if($value eq "DELETE");

    # query the featureprop_id if it exists
    my $featureprop_id = $self->row_exists('featureprop', 'featureprop_id', 'type_id', $feature_id[0][0], $cvterm_id[0][0]);
	
    if(!$featureprop_id && !$delete_row) {
		$self->do_insert_featureprop($feature_id[0][0], $type, $value);
    }
    elsif($featureprop_id && $delete_row) {
		$self->do_delete_featureprop_value($featureprop_id, $value);
    }
    else {
		$self->do_update_featureprop_value($featureprop_id, $value);
    }
}

sub do_insert_featureprop {
    my($self, $feature_id, $type, $value) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my @type_id = $self->get_cv_term( $type );
    defined ($type_id[0][0]) || die "No cvterm defined for type $type";

    my $featureprop_id = $self->get_auto_incremented_id('featureprop', 'featureprop_id');

    my $query = qq| INSERT INTO featureprop (featureprop_id, feature_id, type_id, value, rank)
                    VALUES (?, ?, ?, ?, 0)
                  |;
    $self->_set_values($query, $featureprop_id, $feature_id, $type_id[0][0], $value);
}

sub do_update_featureprop_value {
    my($self, $featureprop_id, $value) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = qq| UPDATE featureprop
                    SET value = ?
                    WHERE featureprop_id = ?
                  |;
    $self->_set_values($query, $value, $featureprop_id);
}

sub do_delete_featureprop_value {
    my($self, $featureprop_id, $value) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = qq| DELETE FROM featureprop
                    WHERE featureprop_id = ?
                  |;
    $self->_set_values($query, $featureprop_id);
}

# Changed and combined from the versions in MysqlChadoCoatiDB.pm and SybaseChadoCoatiDB.pm
# - removed $db..table
# - just using feature_id for update
# $db parameter was deleted
# Everything moved to do_update_featureprop
sub do_update_gene_product_name {
    my ($self, $gene_id, $gene_product_name) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->do_update_featureprop($gene_id, 'gene_product_name', $gene_product_name);

}

# Modified to use generic do_insert_featureprop
# Removed $db
sub do_insert_gene_product_name {
    my ($self, $gene_id, $value) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my @feature_id = $self->get_feature_id($gene_id);
    die "Unable to update gene_id/uniquename $gene_id" unless defined($feature_id[0][0]);

    $self->do_insert_featureprop($feature_id[0][0], 'gene_product_name', $value);
}


# Everything moved to do_update_featureprop
sub do_update_gene_symbol {
    my ($self, $gene_id, $gene_symbol) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->do_update_featureprop($gene_id, 'gene_symbol', $gene_symbol);

}

# Modified to use generic do_insert_featureprop
sub do_insert_gene_symbol {
    my ($self, $gene_id, $value) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my @feature_id = $self->get_feature_id($gene_id);
    die "Unable to update gene_id/uniquename $gene_id" unless defined($feature_id[0][0]);

    $self->do_insert_featureprop($feature_id[0][0], 'gene_symbol', $value);
}

# For the provided feature.uniquename, wipe existing feature_cvterms
# and add in new ones ($value could be comma delimited)
# We assume a single ontology (not separate process/function/component for GO)
sub do_update_feature_cvterms {
    my ($self, $gene_id, $values, $cv) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my @feature_id = $self->get_feature_id($gene_id);
    die "Unable to update gene_id/uniquename $gene_id" unless defined($feature_id[0][0]);

    # delete the existing terms
    $self->do_delete_feature_cvterms_by_feature_id($feature_id[0][0], $cv);

    # add in the new ones
    foreach my $term ( split(",", $values) ) {
	# currently not using this
        # $self->do_insert_GO_id( $gene_id, $term );

	my @cvterm_id = $self->get_cv_term_id_by_accession($term, $cv);
	die "Unable to pull cvterm for $term" unless defined($cvterm_id[0][0]);

#	die Dumper($cvterm_id[0][0]);
#	die Dumper($feature_id[0][0]);

	# just inserting feature_cvterm record, no prop, etc
	$self->do_insert_feature_cvterm( $feature_id[0][0], $cvterm_id[0][0] );
    }
}


# For the provided feature.uniquename, wipe existing GO terms
# and add in new ones ($value could be comma delimited)
# We assume a single GO ontology (not separate process/function/component)
sub do_update_GO_terms {
    my ($self, $gene_id, $values) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->do_update_feature_cvterms( $gene_id, $values, 'GO' );
}

# For the provided feature.uniquename, wipe existing EC terms
# and add in new ones ($value could be comma delimited)
sub do_update_EC_terms {
    my ($self, $gene_id, $values) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->do_update_feature_cvterms( $gene_id, $values, 'EC' );
}

sub do_insert_feature_cvterm {
    my($self, $feature_id, $cvterm_id) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    # Get a new id for feature_cvterm
    my $feature_cvterm_id = $self->get_auto_incremented_id('feature_cvterm', 'feature_cvterm_id');
    my ( $pub_id, $is_not ) = ( 1, 0 ); # default values for required columns

    my $query = qq| INSERT INTO feature_cvterm (feature_cvterm_id, feature_id, cvterm_id, pub_id, is_not)
                    VALUES (?, ?, ?, ?, ?)
                  |;
    $self->_set_values($query, $feature_cvterm_id, $feature_id, $cvterm_id, $pub_id, $is_not);
}

# delete all the feature_cvterms for a feature_id from the cv.name
sub do_delete_feature_cvterms_by_feature_id {
    my ($self, $feature_id, $cv) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    # query all the feature_cvterms we're going to delete
    my $feature_cvterms = $self->get_retrieve_feature_cvterms($cv, $feature_id);

    foreach my $feature_cvterm ( @$feature_cvterms ) {
	my $feature_cvterm_id = $feature_cvterm->[2];
	$self->do_delete_feature_cvterm ( $feature_cvterm_id );
    }
}


sub do_delete_feature_cvterm {
    my ($self, $feature_cvterm_id) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    # delete the entries from the dependant tables
    # delete from feature_cvterm_dbxref
    $self->do_delete_feature_cvterm_dbxref_by_feature_cvterm_id( $feature_cvterm_id );
    # delete from feature_cvterm_pub
    $self->do_delete_feature_cvterm_pub_by_feature_cvterm_id( $feature_cvterm_id );
    # delete from feature_cvtermprop
    $self->do_delete_feature_cvtermprop_by_feature_cvterm_id( $feature_cvterm_id );

    # delete this feature_cvterm_id
    my $query = qq| DELETE FROM feature_cvterm
                    WHERE feature_cvterm_id = ?
                  |;
    $self->_set_values($query, $feature_cvterm_id);
}

# delete feature_cvterm_dbxref entries by feature_cvterm_id
sub do_delete_feature_cvterm_dbxref_by_feature_cvterm_id {
    my ($self, $feature_cvterm_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = qq| DELETE FROM feature_cvterm_dbxref
                    WHERE feature_cvterm_id = ?
                  |;
    $self->_set_values($query, $feature_cvterm_id);
}

# delete feature_cvterm_pub entries by feature_cvterm_id
sub do_delete_feature_cvterm_pub_by_feature_cvterm_id {
    my ($self, $feature_cvterm_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = qq| DELETE FROM feature_cvterm_pub
                    WHERE feature_cvterm_id = ?
                  |;
    $self->_set_values($query, $feature_cvterm_id);
}

# delete feature_cvtermprop entries by feature_cvterm_id
sub do_delete_feature_cvtermprop_by_feature_cvterm_id {
    my ($self, $feature_cvterm_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = qq| DELETE FROM feature_cvtermprop
                    WHERE feature_cvterm_id = ?
                  |;
    $self->_set_values($query, $feature_cvterm_id);
}

#########################################
#^     END ANALYSIS_ID INPUT_TYPE      ^#
#########################################



############################
#     MISC INPUT_TYPE      #
############################

sub get_handle_gene_id {
    my ($self, $gene_id, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    return $gene_id;
}

sub get_handle_btab_names {
    my ($self, $seq_id, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = lc($db);
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @cd_id = $self->get_cv_term('CDS');
    my @df_id = $self->get_cv_term('derives_from');

    my $query = "SELECT an.sourcename ".
                "FROM analysis an, analysisfeature af, feature t, feature c, feature a, featureloc fl, organism o, feature_relationship tc ".
				"WHERE an.name = 'ber' ".
				"AND an.analysis_id = af.analysis_id ".
				"AND af.feature_id = c.feature_id ".
				"AND c.organism_id = o.organism_id ".
				"AND o.common_name != 'not known' ".
				"AND t.uniquename = '$gene_id' ".
				"AND t.feature_id = tc.object_id ".
				"AND tc.subject_id = c.feature_id ".
				"AND c.feature_id = fl.feature_id ".
				"AND fl.srcfeature_id = a.feature_id ".
				"AND c.type_id = $cd_id[0][0] ".
				"AND a.type_id = $as_id[0][0] ".
				"AND t.type_id = $tr_id[0][0] ".
				"AND tc.type_id = $df_id[0][0] ";
	
    if($self->{_seq_id}) {
		$query .= "AND a.uniquename = '$self->{_seq_id}' ";
    }
    elsif($seq_id) {
		$query .= "AND a.uniquename = '$seq_id' ";
    }


    my $res = $self->_get_results_ref($query);
    my $ber_location = $res->[0][0];
    my $ber_list_file = $ber_location . "/ber.btab.list";
    my $btab_file = "";

	### this is done b/c the database original database stores BER searches
	### in /usr/local/projects.  This is not the location on khan or any other server. 
	### Hack but it works. 	 
	if( $ber_list_file =~ /\/usr\/local\/projects/ ) { 	 
		$ber_list_file =~ s/\/usr\/local\/projects/$ENV{ANNOTATION_DIR}/g;
	}


    ### get the identifier for the polypeptide
    my $res2 = $self->get_gene_id_to_protein_id($gene_id);
    my $protein_id = $res2->[0][0];
    $protein_id =~ s/\./\\./g;

	### get the identifier for the CDS
    my $res3 = $self->get_gene_id_to_CDS($gene_id);
	my $cds_id = $res3->[0][2];
	$cds_id =~ s/\./\\./g;

    open BER, "$ber_list_file";
    while(<BER>) {
		chomp;
		
		if( ($protein_id) && (grep {/$protein_id/g} $_) ) {
			$btab_file = $_;
			### this is done b/c the database original database stores BER searches
			### in /usr/local/projects.  This is not the location on khan or any other server. 
			### Hack but it works. 	 
			if( $btab_file =~ /\/usr\/local\/projects/ ) { 	 
				$btab_file =~ s/\/usr\/local\/projects/$ENV{ANNOTATION_DIR}/g;
			}
		} elsif( ($cds_id) && (grep {/$cds_id/g} $_) ) {
			$btab_file = $_;
			### this is done b/c the database original database stores BER searches
			### in /usr/local/projects.  This is not the location on khan or any other server. 
			### Hack but it works. 	 
			if( $btab_file =~ /\/usr\/local\/projects/ ) { 	 
				$btab_file =~ s/\/usr\/local\/projects/$ENV{ANNOTATION_DIR}/g;
			}			
		}
    }
    close BER;

    return $btab_file;
}

sub get_handle_btab_names_prok {
    my ($self, $seq_id, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = uc($db);

    my $btab_file = sprintf("%s/%s/BER_searches/CURRENT/%s.nr.btab",
                $ENV{ANNOTATION_DIR},
                $db,
                $gene_id);

    return $btab_file;
}

sub get_handle_blast_names {
    my ($self, $seq_id, $gene_id, $db) = @_;
    my ($blast_modif_date);
    my $blast_file = "";
    my @custom_blasts;
    $db = uc($db);

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    ### get file system location of the BER searches
    my $query = "SELECT sourcename ".
            "FROM analysis ".
        "WHERE name = 'wu-blastp' ";

    my $res = $self->_get_results_ref($query);
    my $blast_location = $res->[0][0];
    my $blast_list_file = $blast_location . "/wu-blastp.btab.list";

    ### get the identifier for the protein
    my $res2 = $self->get_gene_id_to_protein($gene_id);
    my $protein_id = $res2->[0][2];
    $protein_id =~ s/\./\\./g;

    open BER, "$blast_list_file";
    while(<BER>) {
    chomp;
    if(grep {/$protein_id/g} $_) {
        $blast_file = $_;
    }
    }
    close BER;

    $blast_modif_date = (stat($blast_file))[9];
    my $blast_file_date = localtime($blast_modif_date);

    return($blast_file, $blast_modif_date, $blast_file_date, \@custom_blasts);
}

sub get_signalP_file_name {
    my ($self, $seq_id, $gene_id, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT sourcename ".
            "FROM analysis ".
        "WHERE name = 'signalp' ";

    my $res = $self->_get_results_ref($query);
    my $sp_location = $res->[0][0];
    $sp_location =~ s/i1$//g;
    my $sp_list_file = $sp_location . "/signalp.raw.list";
    my $sp_file = "";

    my $res2 = $self->get_gene_id_to_protein_id($gene_id);
    my $protein_id = $res2->[0][0];
    $protein_id =~ s/\./\\./g;

    open SP, "$sp_list_file";
    while(<SP>) {
    chomp;
    if(grep {/$protein_id/g} $_) {
        $sp_file = $_ . ".gz";
    }
    }
    close SP;

    return $sp_file;
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

sub get_previous_sigP_results {
    my ($self, $seq_id, $gene_id, $db) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my $path = sprintf("$ENV{ANNOTATION_DIR}/%s/asmbls/%s/signalP/sigp.%s.gz",
            uc($db),
            $seq_id,
            $gene_id);
    return $path;
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

sub get_overlaps_name {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $overlaps_file = sprintf("%s/%s/overlap_analysis/%s.overlaps",
                $ENV{ANNOTATION_DIR},
                uc($db),
                $db);
    return $overlaps_file;
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
    return undef;
}

sub get_custom_query_to_results {
    my ($self, $query, @args) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    return $self->_get_results_ref($query, @args);
}

sub get_search_str_to_organisms {
    my ($self, $search_str, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');

    #
    # Escape characters from the search string
    $search_str = lc($search_str);
    $search_str =~ s/\./\\./g;
    $search_str =~ s/\,/\\,/g;
    $search_str =~ s/\'/\\\'/g;
    $search_str =~ s/\"/\\\"/g;
    $search_str =~ s/\s+/\|/g;

    my $query = "SELECT a.uniquename, o.common_name, o.organism_id, d.accession, db2.name ".
            "FROM feature a, organism o, organism_dbxref od, dbxref d, db db, organism_dbxref od2, dbxref d2, db db2  ".
        "WHERE a.type_id = $as_id[0][0] ".
        "AND a.organism_id = o.organism_id ".
        "AND o.organism_id = od.organism_id ".
        "AND od.dbxref_id = d.dbxref_id ".
        "AND d.db_id = db.db_id ".
        "AND db.name = 'taxon' ".
        "AND o.organism_id = od2.organism_id ".
        "AND od2.dbxref_id = d2.dbxref_id ".
        "AND d2.version = 'brc_name' ".
        "AND d2.db_id = db2.db_id ".
        "AND LOWER(o.common_name) LIKE \"%$search_str%\" ";

    return $self->_get_results_ref($query);
}

##########################
#^ END MISC INPUT_TYPES ^#
##################################################################




########################
#   ACC INPUT_TYPE     #
########################

sub get_acc_to_genes {
    my ($self, $acc) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @cd_id = $self->get_cv_term('CDS');
    my @pr_id = $self->get_cv_term('polypeptide', 'SO');
    my @ma_id = $self->get_cv_term('match_part');
    my @df_id = $self->get_cv_term('derives_from');
    my @gp_id = $self->get_cv_term('gene_product_name');

    my $query = "SELECT t.uniquename, fp.value ".
            "FROM feature a, feature t, feature c, feature p, feature m, feature h, featureloc fl, ".
        "feature_relationship tc, feature_relationship cp, featureloc pm, featureloc mh, featureprop fp ".
        "WHERE t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = tc.object_id ".
        "AND tc.subject_id = c.feature_id ".
        "AND c.feature_id = cp.object_id ".
        "AND cp.subject_id = p.feature_id ".
        "AND p.feature_id = pm.srcfeature_id ".
        "AND pm.feature_id = m.feature_id ".
        "AND m.feature_id = mh.feature_id ".
        "AND mh.srcfeature_id = h.feature_id ".
        "AND mh.rank = 0 ".
        "AND h.uniquename = '$acc' ".
        "AND t.feature_id = fp.feature_id ".
        "AND fp.type_id = $gp_id[0][0] ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND c.type_id = $cd_id[0][0] ".
        "AND p.type_id = $pr_id[0][0] ".
        "AND m.type_id = $ma_id[0][0] ".
        "AND tc.type_id = $df_id[0][0] ".
        "AND cp.type_id = $df_id[0][0] ";

    if($self->{_seq_id}) {
    $query .= "AND a.uniquename = '$self->{_seq_id}' ";
    }

    return $self->_get_results_ref($query);
}

########################
#^ END ACC INPUT_TYPE ^#
##################################################################





######################
# ROLE_ID INPUT_TYPE #
######################




sub get_role_id_to_genes {
    my($self, $role_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @tr_id = $self->get_cv_term('transcript');

    my $query = "SELECT t.uniquename ".
            "FROM $db..feature t, $db..feature_cvterm fc, $db..cvterm_dbxref cd, $db..dbxref d, $db..db ".
        "WHERE d.accession = '$role_id' ".
        "AND d.db_id = db.db_id ".
        "AND db.name = 'TIGR_role' ".
        "AND d.dbxref_id = cd.dbxref_id ".
        "AND cd.cvterm_id = fc.cvterm_id ".
        "AND fc.feature_id = t.feature_id ";

    return $self->_get_results_ref($query);
}

sub get_role_id_to_notes {
    my($self, $role_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT notes ".
            "FROM role_notes ".
        "WHERE role_id = '$role_id' ";

    return $self->_get_results_ref($query);
}

sub get_role_id_to_common_notes {
    my($self, $role_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

	my $query = "SELECT r.notes, e.mainrole, e.sub1role ".
		        "FROM common..role_notes r, egad..roles e ".
				"WHERE r.role_id = $role_id ".
				"AND r.role_id = e.role_id ";

    return $self->_get_results_ref($query);	
}


############################
#^ END ROLE_ID INPUT_TYPE ^#
##################################################################








########################
#   ALL INPUT_TYPE     #
########################

sub get_all_attribute_types {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT DISTINCT input_type ".
    "FROM common..score_type ".
    "WHERE input_type in ('GC', 'GES', 'LP', 'MW', 'OMP', 'PI', 'SP', 'TERM', 'tRNA') ";
    my $results = $self->_get_results_ref($query);

    #
    # Iterate thru all the attribute types for the given database and pull out
    # each score type (i.e. sub att types) that corresponds to that attribute type
    for (my $i=0; $i<@$results; $i++) {
    my $query = "SELECT t.score_type ".
                "FROM common..score_type t ".
            "WHERE input_type = '$results->[$i][0]' ";
    my $results2 = $self->_get_results_ref($query);
    #
    # Make sure the second element is set to empty
    $results->[$i][1] = "";
    for(my $j=0; $j<@$results2; $j++) {
        $results->[$i][1] .= "$results2->[$j][0]:";
    }
    $results->[$i][1] =~ s/\:$//;
    }
    return $results;
}

sub get_all_evidence_types {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT DISTINCT p.program FROM $db..analysis p ".
            "WHERE p.program NOT IN ('BER','ber','RBS','TERM','cogs','jaccard', 'clustalw')";

    return $self->_get_results_ref($query);
}

sub get_common_name_to_legacy_db {
    my($self, $common_name, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT d.accession ".
            "FROM $db..organism o, $db..organism_dbxref od, $db..dbxref d ".
        "WHERE o.common_name = '$common_name' ".
        "AND o.organism_id = od.organism_id ".
        "AND od.dbxref_id = d.dbxref_id ";

    my $ret =  $self->_get_results_ref($query);
    return $ret->[0][0];
}

sub get_all_organisms {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');

    my $query = qq( SELECT a.uniquename, o.abbreviation, o.common_name, o.genus, o.species, o.organism_id
                    FROM feature a, organism o
                    WHERE o.organism_id = a.organism_id
                    AND a.type_id = $as_id[0][0]
                    ORDER BY a.uniquename );

    return $self->_get_results_ref($query);
}

########################
#^ END ALL INPUT_TYPE ^#
##################################################################





###############################
#     EV_TYPE INPUT_TYPE      #
###############################

sub get_ev_type_to_HMM_evidence {
    my ($self, $ev_type, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @pr_id = $self->get_cv_term('polypeptide', 'SO');
    my @cd_id = $self->get_cv_term('CDS');
    my @tr_id = $self->get_cv_term('transcript');
    my @as_id = $self->get_cv_term('assembly');
    my @ma_id = $self->get_cv_term('match_part');
    my @df_id = $self->get_cv_term('derives_from');


    my $query = "SELECT hmm.uniquename, t.uniquename, h.hmm_com_name ".
            "FROM $db..feature hmm, $db..feature m, $db..feature p, $db..feature c, egad..hmm2 h, ".
        "$db..feature t, $db..feature_relationship pc, $db..feature_relationship ct, ".
        "$db..featureloc fl, $db..featureloc fl2, $db..featureloc fl3, $db..feature a ".
        "WHERE hmm.uniquename = h.hmm_acc ".
        "AND hmm.feature_id = fl.srcfeature_id ".
        "AND fl.feature_id = m.feature_id ".
        "AND m.feature_id = fl2.feature_id ".
        "AND fl2.srcfeature_id = p.feature_id ".
        "AND p.feature_id = pc.subject_id ".
        "AND pc.object_id = c.feature_id ".
        "AND c.feature_id = ct.subject_id ".
        "AND ct.object_id = t.feature_id ".
        "AND t.feature_id = fl3.feature_id ".
        "AND fl3.srcfeature_id = a.feature_id ".
        "AND hmm.type_id = $pr_id[0][0] ".
        "AND m.type_id = $ma_id[0][0] ".
        "AND c.type_id = $cd_id[0][0] ".
        "AND p.type_id = $pr_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND pc.type_id = $df_id[0][0] ".
        "AND ct.type_id = $df_id[0][0] ".
        "AND a.type_id = $as_id[0][0] ";

    my $res = $self->_get_results_ref($query);

    my %s;
    my %seen;
    for(my $i=0; $i<@$res; $i++) {
    if(!$seen{$res->[$i][1]}) {
        $s{$res->[$i][0]}->{'gene_count'}++;
        $s{$res->[$i][0]}->{'HMM_name'} = $res->[$i][2];
    }
    $seen{$res->[$i][1]} = 1;
    }

    my @f;
    my $i = 0;
    foreach my $hmm (sort keys %s) {
    $f[$i][0] = $hmm;
    $f[$i][1] = $s{$hmm}->{'gene_count'};
    $f[$i][2] = $s{$hmm}->{'HMM_name'};
    $i++;
    }
    return \@f;
}

sub get_ev_type_to_COG_evidence {
    my ($self, $ev_type, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @cd_id = $self->get_cv_term('CDS');
    my @pr_id = $self->get_cv_term('polypeptide', 'SO');
    my @tr_id = $self->get_cv_term('transcript');
    my @ma_id = $self->get_cv_term('match_part');
    my @df_id = $self->get_cv_term('derives_from');

    my $query = "SELECT h.uniquename, t.uniquename ".
            "FROM feature a, feature t, feature c, feature p, feature m, feature h, featureloc fl, ".
        "feature_relationship tc, feature_relationship cp, featureloc pm, featureloc mh, ".
        "analysis an, analysisfeature af ".
        "WHERE t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = tc.object_id ".
        "AND tc.subject_id = c.feature_id ".
        "AND c.feature_id = cp.object_id ".
        "AND cp.subject_id = p.feature_id ".
        "AND p.feature_id = pm.srcfeature_id ".
        "AND pm.feature_id = m.feature_id ".
        "AND m.feature_id = mh.feature_id ".
        "AND mh.srcfeature_id = h.feature_id ".
        "AND mh.rank = 0 ".
        "AND an.program = 'NCBI_COG' ".
        "AND an.analysis_id = af.analysis_id ".
        "AND af.feature_id = m.feature_id ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND c.type_id = $cd_id[0][0] ".
        "AND p.type_id = $pr_id[0][0] ".
        "AND m.type_id = $ma_id[0][0] ".
        "AND tc.type_id = $df_id[0][0] ".
        "AND cp.type_id = $df_id[0][0] ";

    my $res = $self->_get_results_ref($query);

    my %s;
    my %seen;
    for(my $i=0; $i<@$res; $i++) {
    if(!$seen{$res->[$i][1]}) {
        $s{$res->[$i][0]}->{'gene_count'}++;
    }
    $seen{$res->[$i][1]} = 1;
    }

    my @f;
    my $i = 0;
    foreach my $cog (sort keys %s) {
    $f[$i][0] = $cog;
    $f[$i][1] = $s{$cog}->{'gene_count'};
    $i++;
    }
    return \@f;
}

sub get_ev_type_to_gene_evidence {
    my ($self, $ev_type, $db) = @_;

$self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my @as_id = $self->get_cv_term('assembly');
    my @cd_id = $self->get_cv_term('CDS');
    my @pr_id = $self->get_cv_term('polypeptide', 'SO');
    my @tr_id = $self->get_cv_term('transcript');
    my @ma_id = $self->get_cv_term('match_part');
    my @df_id = $self->get_cv_term('derives_from');

    my $query = "SELECT h.uniquename, count(t.uniquename), 'com_name', '', h.uniquename ".
            "FROM feature a, feature t, feature c, feature p, feature m, feature h, featureloc fl, ".
        "feature_relationship tc, feature_relationship cp, featureloc pm, featureloc mh, ".
        "analysis an, analysisfeature af ".
        "WHERE t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = tc.object_id ".
        "AND tc.subject_id = c.feature_id ".
        "AND c.feature_id = cp.object_id ".
        "AND cp.subject_id = p.feature_id ".
        "AND p.feature_id = pm.srcfeature_id ".
        "AND pm.feature_id = m.feature_id ".
        "AND m.feature_id = mh.feature_id ".
        "AND mh.srcfeature_id = h.feature_id ".
        "AND mh.rank = 0 ".
        "AND an.program = \"$ev_type\" ".
        "AND an.analysis_id = af.analysis_id ".
        "AND af.feature_id = m.feature_id ";

    if($self->{_seq_id}) {
    $query .= "AND a.uniquename = '$self->{_seq_id}' ";
    }

    $query .= "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND c.type_id = $cd_id[0][0] ".
        "AND p.type_id = $pr_id[0][0] ".
        "AND m.type_id = $ma_id[0][0] ".
        "AND tc.type_id = $df_id[0][0] ".
        "AND cp.type_id = $df_id[0][0] ".
        "GROUP BY h.uniquename ";

    return $self->_get_results_ref($query);
}

############################
#^ END EV_TYPE INPUT_TYPE ^#
#################################################################




########################
# ACCESSION INPUT_TYPE #
########################

sub get_HMM_acc_to_evidence {
    my ($self, $HMM_acc, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "";
    return $self->_get_results_ref($query);
#    my $query = "SELECT h.feat_name, f.score, i.com_name " .
#                "FROM $db..evidence h, $db..ident i, $db..feat_score f " .
#                "WHERE h.accession = ? " .
#                "AND h.feat_name = i.feat_name " .
#		 "AND h.id = f.input_id ".
#		 "AND f.score_id = 51 ";
#
#    return $self->_get_results_ref($query, $HMM_acc);
}

sub get_HMM_acc_to_features {
    my ($self, $HMM_acc, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @cd_id = $self->get_cv_term('CDS');
    my @pr_id = $self->get_cv_term('polypeptide', 'SO');
    my @ma_id = $self->get_cv_term('match_part');
    my @df_id = $self->get_cv_term('derives_from');
    my @gn_id = $self->get_cv_term('gene_product_name');
    my @feature_id = $self->get_feature_id($HMM_acc);

    my $query = "SELECT t.uniquename, fp.value ".
            "FROM feature m, feature h, feature p, feature c, feature t, ".
        "featureloc fl, featureloc fl2, feature_relationship pc, organism o, ".
        "feature_relationship ct, featureprop fp, feature a, featureloc fl3 ".
        "WHERE h.feature_id = $feature_id[0][0] ".
        "AND h.feature_id = fl.srcfeature_id ".
        "AND fl.feature_id = m.feature_id ".
        "AND m.feature_id = fl2.feature_id  ".
        "AND fl2.srcfeature_id = p.feature_id ".
        "AND p.feature_id = pc.subject_id ".
        "AND pc.object_id = c.feature_id ".
        "AND c.feature_id = ct.subject_id ".
        "AND ct.object_id = t.feature_id ".
        "AND t.feature_id = fl3.feature_id ".
        "AND fl3.srcfeature_id = a.feature_id ".
        "AND a.type_id = $as_id[0][0] ".
        "AND m.type_id = $ma_id[0][0] ".
        "AND c.type_id = $cd_id[0][0] ".
        "AND p.type_id = $pr_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND pc.type_id = $df_id[0][0] ".
        "AND ct.type_id = $df_id[0][0] ".
        "AND t.feature_id = fp.feature_id ".
        "AND fp.type_id = $gn_id[0][0] ".
        "AND t.organism_id = o.organism_id ".
        "AND o.common_name != 'not known' ";

    return $self->_get_results_ref($query);
}

sub get_HMM_acc_to_scores {
    my ($self, $HMM_acc, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @cd_id = $self->get_cv_term('CDS');
    my @pr_id = $self->get_cv_term('polypeptide', 'SO');
    my @ma_id = $self->get_cv_term('match_part');
    my @df_id = $self->get_cv_term('derives_from');
    my @feature_id = $self->get_feature_id($HMM_acc);

    my $query = "SELECT t.uniquename, h.feature_id, fl2.fmin, fl2.fmax, fl.fmin, fl.fmax, 'SCORE_ID', af.rawscore ".
            "FROM feature m, feature h, feature p, feature c, feature t, ".
        "featureloc fl, featureloc fl2, feature_relationship pc, organism o, ".
        "feature_relationship ct, analysisfeature af, feature a, featureloc fl3 ".
        "WHERE h.feature_id = $feature_id[0][0] ".
        "AND h.feature_id = fl.srcfeature_id ".
        "AND fl.feature_id = m.feature_id ".
        "AND m.feature_id = fl2.feature_id  ".
        "AND fl2.srcfeature_id = p.feature_id ".
        "AND p.feature_id = pc.subject_id ".
        "AND pc.object_id = c.feature_id ".
        "AND c.feature_id = ct.subject_id ".
        "AND ct.object_id = t.feature_id ".
        "AND m.feature_id = af.feature_id ".
        "AND t.feature_id = fl3.feature_id ".
        "AND fl3.srcfeature_id = a.feature_id ".
        "AND a.type_id = $as_id[0][0] ".
        "AND m.type_id = $ma_id[0][0] ".
        "AND c.type_id = $cd_id[0][0] ".
        "AND p.type_id = $pr_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND pc.type_id = $df_id[0][0] ".
        "AND ct.type_id = $df_id[0][0] ".
        "AND t.organism_id = o.organism_id ".
        "AND o.common_name != 'not known' ";

    return $self->_get_results_ref($query);
}

##############################
#^ END ACCESSION INPUT_TYPE ^#
##################################################################




###########################
#   ATT_TYPE INPUT_TYPE   #
###########################

sub get_att_type_to_membrane_proteins {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @cd_id = $self->get_cv_term('CDS');
    my @pr_id = $self->get_cv_term('polypeptide', 'SO');
    my @sp_id = $self->get_cv_term('signal_peptide');
    my @gp_id = $self->get_cv_term('gene_product_name');

    my $query = "SELECT t.uniquename, c.name, fp.value, gp.value ".
            "FROM $db..feature t, $db..cvterm c, $db..featureprop fp, ".
        "$db..featureprop gp, $db..feature a, $db..featureloc fl ".
        "WHERE c.name IN ('transmembrane_regions', 'outer_membrane_protein', 'lipo_membrane_protein') ".
        "AND c.cvterm_id = fp.type_id ".
        "AND fp.feature_id = t.feature_id ".
        "AND t.feature_id = fl.feature_id ".
        "AND t.feature_id = gp.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND a.type_id = $as_id[0][0] ".
        "AND gp.type_id = $gp_id[0][0] ";

    if($self->{_seq_id}) {
    $query .= "AND a.uniquename = '$self->{_seq_id}' ";
    }

    my $res = $self->_get_results_ref($query);

    my $query2 = "SELECT t.uniquename, sc.name, sp.value, gp.value ".
            "FROM $db..feature a, $db..feature t, $db..feature c, $db..feature p, $db..feature s, $db..featureloc fl, ".
        "$db..feature_relationship tc, $db..feature_relationship cp, $db..feature_relationship ps, $db..featureprop gp, ".
        "$db..featureprop sp, $db..cvterm sc ".
        "WHERE a.feature_id = fl.srcfeature_id ".
        "AND fl.feature_id = t.feature_id ".
        "AND t.feature_id = tc.object_id ".
        "AND t.feature_id = gp.feature_id ".
        "AND tc.subject_id = c.feature_id ".
        "AND c.feature_id = cp.object_id ".
        "AND cp.subject_id = p.feature_id ".
        "AND p.feature_id = ps.object_id ".
        "AND ps.subject_id = s.feature_id ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND c.type_id = $cd_id[0][0] ".
        "AND p.type_id = $pr_id[0][0] ".
        "AND s.type_id = $sp_id[0][0] ".
        "AND gp.type_id = $gp_id[0][0] ".
        "AND s.feature_id = sp.feature_id ".
        "AND sp.type_id = sc.cvterm_id ";

    if($self->{_seq_id}) {
    $query2 .= "AND a.uniquename = '$self->{_seq_id}' ";
    }

    my $res2 = $self->_get_results_ref($query2);

    my %s;
    for(my $i=0; $i<@$res; $i++) {
    $s{$res->[$i][0]}->{$res->[$i][1]}->{'score'} = $res->[$i][2];
    $s{$res->[$i][0]}->{$res->[$i][1]}->{'product_name'} = $res->[$i][3];
    }

    for(my $i=0; $i<@$res2; $i++) {
    $s{$res2->[$i][0]}->{$res2->[$i][1]}->{'score'} = $res2->[$i][2];
    $s{$res2->[$i][0]}->{$res2->[$i][1]}->{'product_name'} = $res2->[$i][3];
    }

    my @f;
    my $i = 0;
    foreach my $gene_id (keys %s) {
    my $t = $s{$gene_id};
    foreach my $att_type (sort keys %$t) {
        $f[$i][0] = $gene_id;
        $f[$i][1] = $att_type;
        $f[$i][2] = $t->{$att_type}->{'score'};
        $f[$i][3] = $t->{$att_type}->{'product_name'};
        $i++;
    }
    }
    return \@f;
}

#^ END ATT_TYPE INPUT_TYPE ^#
##################################################################





##########################
#   DB_XREF INPUT_TYPE   #
##########################


############################
#^ END DB_XREF INPUT_TYPE ^#
##################################################################

sub get_organism_id_to_taxon_id {
    my ($self, $organism_id, $db) = @_;

    my $query = qq| 
                   SELECT d.accession
                   FROM organism_dbxref od, dbxref d, db db
                   WHERE od.dbxref_id = d.dbxref_id
                      AND d.db_id = db.db_id
                      AND db.name = 'taxon'
                      AND od.organism_id = ?
                  |;

    return $self->_get_results_ref($query, $organism_id);
}

sub do_insert_role {
    my ($self, $gene_id, $role_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my $new_fc_id  = $self->get_auto_incremented_id('feature_cvterm', 'feature_cvterm_id');
    my @feature_id = $self->get_feature_id($gene_id);

    my $query = "SELECT c.cvterm_id ".
            "FROM cvterm c, cv cv, cvterm_dbxref cd, dbxref d ".
        "WHERE d.accession = '$role_id' ".
        "AND d.dbxref_id = cd.dbxref_id ".
        "AND cd.cvterm_id = c.cvterm_id ".
        "AND c.cv_id = cv.cv_id ".
        "AND cv.name = 'TIGR_role' ";

    my $ret = $self->_get_results_ref($query);
    my $cvterm_id = $ret->[0][0];

    ### the role id does not exist for this feature_id, go ahead and insert the new role_id
    if(!$self->row_exists('feature_cvterm', 'feature_cvterm_id', 'cvterm_id', $feature_id[0][0], $cvterm_id)) {
    my $query2 = "INSERT feature_cvterm (feature_cvterm_id, feature_id, cvterm_id, pub_id, is_not) ".
                "VALUES ($new_fc_id, $feature_id[0][0], $cvterm_id, 1, 0) ";

    $self->_set_values($query2);
    }
}

sub do_insert_ident {
    my ($self, $gene_id, $identref, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->do_insert_gene_product_name($gene_id, $identref->{'com_name'}, $db);
    $self->do_insert_gene_symbol($gene_id, $identref->{'gene_sym'}, $db);
    $self->do_insert_ec_number($gene_id, $identref->{'ec#'}, $db);
    $self->do_insert_comment($gene_id, $identref->{'comment'}, $db);
    $self->do_insert_public_comment($gene_id, $identref->{'pub_comment'}, $db);
    $self->do_insert_assignby($gene_id, $self->{_user}, $db);
    $self->do_insert_date($gene_id, $db);
}

sub do_insert_comment {
    my ($self, $gene_id, $comment, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @co_id = $self->get_cv_term('comment', 'annotation_attributes.ontology');
    my @feature_id = $self->get_feature_id($gene_id);
    my $new_id = $self->get_auto_incremented_id('featureprop', 'featureprop_id');

    my $query = "INSERT $db..featureprop (featureprop_id, feature_id, type_id, value, rank) ".
            "VALUES ($new_id, $feature_id[0][0], $co_id[0][0], \"$comment\", 0)";

    $self->_set_values($query);
}

sub do_insert_public_comment {
    my ($self, $gene_id, $public_comment, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @pc_id = $self->get_cv_term('public_comment');
    my @feature_id = $self->get_feature_id($gene_id);
    my $new_id = $self->get_auto_incremented_id('featureprop', 'featureprop_id');

    my $query = "INSERT $db..featureprop (featureprop_id, feature_id, type_id, value, rank) ".
            "VALUES ($new_id, $feature_id[0][0], $pc_id[0][0], \"$public_comment\", 0)";

    $self->_set_values($query);
}

sub do_insert_ec_number {
    my ($self, $gene_id, $ec_number, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @ec_id = $self->get_cv_term('ec_number');
    my @feature_id = $self->get_feature_id($gene_id);
    my $new_id = $self->get_auto_incremented_id('featureprop', 'featureprop_id');

#    my $query = "INSERT $db..dbxref (accession, db_id, version, dbxref_id) ".
#	        "VALUES ('$ec_number', 5, 'current', ) ";

    my $query = "INSERT $db..featureprop (featureprop_id, feature_id, type_id, value, rank) ".
            "VALUES ($new_id, $feature_id[0][0], $ec_id[0][0], \"$ec_number\", 0)";

    $self->_set_values($query);
}

sub do_insert_assignby {
    my ($self, $gene_id, $assignby, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @ab_id = $self->get_cv_term('assignby');
    my @feature_id = $self->get_feature_id($gene_id);
    my $new_id = $self->get_auto_incremented_id('featureprop', 'featureprop_id');

    my $query = "INSERT $db..featureprop (featureprop_id, feature_id, type_id, value, rank) ".
            "VALUES ($new_id, $feature_id[0][0], $ab_id[0][0], \"$assignby\", 0)";

    $self->_set_values($query);
}

sub do_insert_date {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @ab_id = $self->get_cv_term('assignby');
    my @dt_id = $self->get_cv_term('date');
    my @feature_id = $self->get_feature_id($gene_id);
    my $new_id = $self->get_auto_incremented_id('featureprop', 'featureprop_id');

    my $query = "INSERT $db..featureprop (featureprop_id, feature_id, type_id, value, rank) ".
            "VALUES ($new_id, $feature_id[0][0], $dt_id[0][0], getdate(), 0)";

    $self->_set_values($query);
}

sub do_insert_GO_id {
    my ($self, $gene_id, $GO_id, $qualifier, $db) = @_;
    my @as_id = $self->get_cv_term('assignby');
    my @dt_id = $self->get_cv_term('date');

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    #
    # Get the feature_id for the given gene_id
    my @feature_id = $self->get_feature_id($gene_id);

    #
    # Get a new id for feature_cvterm
    my $feature_cvterm_id = $self->get_auto_incremented_id('feature_cvterm', 'feature_cvterm_id');

    #
    # Get the cvterm_id for the given GO id
    my $query = "SELECT c.cvterm_id ".
            "FROM $db..cvterm c, $db..dbxref d ".
        "WHERE d.accession = '$GO_id' ".
        "AND d.dbxref_id = c.dbxref_id ";
    my $res = $self->_get_results_ref($query);
    my $go_cv_id = $res->[0][0];

    #
    # Insert a new row into feature_cvterm to link the GO id to the gene id
    my $query2 = "INSERT $db..feature_cvterm (cvterm_id, feature_cvterm_id, feature_id, pub_id, is_not) ".
            "VALUES ($go_cv_id, $feature_cvterm_id, $feature_id[0][0], 1, 0) ";
    $self->_set_values($query2);
}

sub do_insert_GO_evidence {
    my ($self, $gene_id, $GO_id, $ev_code, $evidence, $with, $qualifier, $db) = @_;
    my @as_id = $self->get_cv_term('assignby');
    my @dt_id = $self->get_cv_term('date');

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    #
    # Get the feature_id for the given gene_id
    my @feature_id = $self->get_feature_id($gene_id);

    #
    # Get the cvterm_id for the given GO id
    my $query = "SELECT c.cvterm_id ".
            "FROM $db..cvterm c, $db..dbxref d ".
        "WHERE d.accession = '$GO_id' ".
        "AND d.dbxref_id = c.dbxref_id ";
    my $res = $self->_get_results_ref($query);
    my $go_cv_id = $res->[0][0];

    #
    # Get feature_cvterm_id for the given gene/GO_id combo
    my $query2 = "SELECT fc.feature_cvterm_id ".
            "FROM $db..feature_cvterm fc ".
        "WHERE fc.feature_id = $feature_id[0][0] ".
        "AND fc.cvterm_id = $go_cv_id ";
    my $res2 = $self->_get_results_ref($query2);
    my $feature_cvterm_id = $res2->[0][0];

    #
    # Get a new id for feature_cvtermprop
    my $feature_cvtermprop_id = $self->get_auto_incremented_id('feature_cvtermprop', 'feature_cvtermprop_id');

    #
    # Concatenate to make evidence value to be inserted into the database
    my $ev_value = $evidence ." WITH ". $with;

    #
    # Get the cvterm_id for the evidence code.  This will be used in feature_cvtermprop also
    my $query3 = "SELECT c.cvterm_id ".
            "FROM $db..cvterm c, $db..cvtermsynonym cs ".
        "WHERE cs.synonym = '$ev_code' ".
        "AND cs.cvterm_id = c.cvterm_id ";
    my $res3 = $self->_get_results_ref($query3);
    my $cvterm_id = $res3->[0][0];

    #
    # Insert a new row into feature_cvtermprop for the ev code
    my $query4 = "INSERT feature_cvtermprop (feature_cvtermprop_id, feature_cvterm_id, type_id, value, rank) ".
                 "VALUES ($feature_cvtermprop_id, $feature_cvterm_id, $cvterm_id, '$ev_value', 0) ";

    $self->_set_values($query4);



    #
    # Get a new id for feature_cvtermprop
    my $feature_cvtermprop_id2 = $self->get_auto_incremented_id('feature_cvtermprop', 'feature_cvtermprop_id');

    #
    # Insert a new row into feature_cvtermprop for the assignby
    my $query5 = "INSERT feature_cvtermprop (feature_cvtermprop_id, feature_cvterm_id, type_id, value, rank) ".
                 "VALUES ($feature_cvtermprop_id2, $feature_cvterm_id, $as_id[0][0], '$self->{_user}', 0) ";

    $self->_set_values($query5);

    #
    # Get a new id for feature_cvtermprop
    my $feature_cvtermprop_id3 = $self->get_auto_incremented_id('feature_cvtermprop', 'feature_cvtermprop_id');

    #
    # Insert a new row into feature_cvtermprop for the date
    my $query6 = "INSERT feature_cvtermprop (feature_cvtermprop_id, feature_cvterm_id, type_id, value, rank) ".
		         "VALUES ($feature_cvtermprop_id3, $feature_cvterm_id, $dt_id[0][0], getdate(), 0) ";

    $self->_set_values($query6);

}

sub do_insert_5prime_partial {
    my ($self, $gene_id, $db) = @_;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @fp_id = $self->get_cv_term('five_prime_partial');
    my @feature_id = $self->get_feature_id($gene_id);
    my $new_id = $self->get_auto_incremented_id('featureprop', 'featureprop_id');

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "INSERT $db..featureprop (featureprop_id, feature_id, type_id, value, rank) ".
            "VALUES ($new_id, $feature_id[0][0], $fp_id[0][0], \"1\", 0)";

    $self->_set_values($query);
}

sub do_insert_3prime_partial {
    my ($self, $gene_id, $db) = @_;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @tp_id = $self->get_cv_term('three_prime_partial');
    my @feature_id = $self->get_feature_id($gene_id);
    my $new_id = $self->get_auto_incremented_id('featureprop', 'featureprop_id');

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "INSERT $db..featureprop (featureprop_id, feature_id, type_id, value, rank) ".
            "VALUES ($new_id, $feature_id[0][0], $tp_id[0][0], \"1\", 0)";

    $self->_set_values($query);
}

sub do_insert_pseudogene_toggle {
    my ($self, $gene_id, $db) = @_;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @pg_id = $self->get_cv_term('is_pseudogene');
    my @feature_id = $self->get_feature_id($gene_id);
    my $new_id = $self->get_auto_incremented_id('featureprop', 'featureprop_id');

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "INSERT $db..featureprop (featureprop_id, feature_id, type_id, value, rank) ".
            "VALUES ($new_id, $feature_id[0][0], $pg_id[0][0], \"1\", 0)";

    $self->_set_values($query);
}

sub do_insert_curated_structure {
    my ($self, $gene_id, $db) = @_;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @gs_id = $self->get_cv_term('gene_structure_curated');
    my @feature_id = $self->get_feature_id($gene_id);
    my $new_id = $self->get_auto_incremented_id('featureprop', 'featureprop_id');

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "INSERT $db..featureprop (featureprop_id, feature_id, type_id, value, rank) ".
            "VALUES ($new_id, $feature_id[0][0], $gs_id[0][0], \"1\", 0)";

    $self->_set_values($query);
}

sub do_insert_curated_annotation {
    my ($self, $gene_id, $db) = @_;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @ga_id = $self->get_cv_term('gene_annotation_curated');
    my @feature_id = $self->get_feature_id($gene_id);
    my $new_id = $self->get_auto_incremented_id('featureprop', 'featureprop_id');

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "INSERT $db..featureprop (featureprop_id, feature_id, type_id, value, rank) ".
            "VALUES ($new_id, $feature_id[0][0], $ga_id[0][0], \"1\", 0)";

    $self->_set_values($query);
}

sub do_insert_signalP_curation {
    my ($self, $gene_id, $db) = @_;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @sp_id = $self->get_cv_term('signalp_curated');
    my @feature_id = $self->get_feature_id($gene_id);
    my $new_id = $self->get_auto_incremented_id('featureprop', 'featureprop_id');

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "INSERT $db..featureprop (featureprop_id, feature_id, type_id, value, rank) ".
            "VALUES ($new_id, $feature_id[0][0], $sp_id[0][0], \"1\", 0)";

    $self->_set_values($query);
}

sub do_insert_evidence {
    my ($self, $gene_id, $acc, $type, $coords_ref, $scores_ref, $curated) = @_;
	
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

	#my $query = "SELECT max( analysis_id ) FROM analysis";
	#my @results = $self->_get_results($query);
	#my $next_id = $results[0][0] + 1;
	#print "next_id = $next_id<br>";

#    my $query = "INSERT evidence (feat_name, ev_type, accession, end5, end3, rel_end5, rel_end3, m_lend, m_rend, curated, date, assignby, change_log, save_history, method) " .
#                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, getdate(), ?, 1, 1, ?)";
#    $self->_set_values($query,
#		       $gene_id,
#		       $type,
#		       $acc,
#		       $coords_ref->{'end5'},
#		       $coords_ref->{'end3'},
#		       $coords_ref->{'rel_end5'},
#		       $coords_ref->{'rel_end3'},
#		       $coords_ref->{'m_lend'},
#		       $coords_ref->{'m_rend'},
#		       $curated,
#		       $self->{_user},
#		       "Manatee");

#    my $idquery = "SELECT max(id) " .
#                  "FROM evidence ".
#                  "WHERE feat_name = ? " .
#                  "AND ev_type = ? " .
#                  "AND accession = ?";
#
#    my $ret = $self->_get_results_ref($idquery, $gene_id, $type, $acc);
#
#    my $scorequery = "INSERT feat_score (input_id, score_id, score) ".
#	             "VALUES (?,?,?) ";
#
#    $self->_set_values($scorequery, $ret->[0][0], 9,  $scores_ref->{'praze'});
#    $self->_set_values($scorequery, $ret->[0][0], 10, $scores_ref->{'pvalue'});
#    $self->_set_values($scorequery, $ret->[0][0], 11, $scores_ref->{'per_sim'});
#    $self->_set_values($scorequery, $ret->[0][0], 12, $scores_ref->{'per_id'});
}

sub do_insert_ident_xref {
    return undef;
}

sub do_update_signalP_curation {
    my ($self, $gene_id, $id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @sp_id = $self->get_cv_term('signalp_curated');
    my @feature_id = $self->get_feature_id($gene_id);
    my $featureprop_id = $self->get_auto_incremented_id('featureprop', 'featureprop_id');

    my $query = "";
    if(!$self->row_exists('featureprop', 'value', 'type_id', $feature_id[0][0], $sp_id[0][0])) {
    $self->do_insert_signalP_curation($gene_id, $db);
    }
    else {
    $self->do_delete_signalP_curation($gene_id, $db);
    }
}


sub do_update_start_edit {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @se_id = $self->get_cv_term('start_site_editor');
    my @feature_id = $self->get_feature_id($gene_id);

    my $query = "";

    if(!$self->row_exists('featureprop', 'value', 'type_id', $feature_id[0][0], $se_id[0][0])) {
		my $featureprop_id = $self->get_auto_incremented_id('featureprop', 'featureprop_id');
		$query = "INSERT featureprop (featureprop_id, feature_id, type_id, value, rank) ".
			     "VALUES ($featureprop_id, $feature_id[0][0], $se_id[0][0], '$self->{_user}', 0) ";
    } else {
		$query = "UPDATE featureprop ".
                 "SET value = '$self->{_user}' ".
				 "WHERE feature_id = $feature_id[0][0] ";
    }
	
    $self->_set_values($query);
}

sub do_delete_start_edit {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @se_id = $self->get_cv_term('start_site_editor');
    my @feature_id = $self->get_feature_id($gene_id);
    my $featureprop_id = $self->row_exists('featureprop', 'featureprop_id', 'type_id', $feature_id[0][0], $se_id[0][0]);

    if($featureprop_id) {
		my $query = "DELETE FROM featureprop ".
			        "WHERE featureprop_id = $featureprop_id ".
					"AND feature_id = $feature_id[0][0] ".
					"AND type_id = $se_id[0][0] ";

		$self->_set_values($query);
    }
}

sub do_update_completed {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @co_id = $self->get_cv_term('completed_by');
    my @feature_id = $self->get_feature_id($gene_id);

    my $query = "";

    if(!$self->row_exists('featureprop', 'value', 'type_id', $feature_id[0][0], $co_id[0][0])) {
    my $featureprop_id = $self->get_auto_incremented_id('featureprop', 'featureprop_id');
    $query = "INSERT featureprop (featureprop_id, feature_id, type_id, value, rank) ".
            "VALUES ($featureprop_id, $feature_id[0][0], $co_id[0][0], '$self->{_user}', 0) ";
    } else {
    $query = "UPDATE featureprop ".
            "SET value = '$self->{_user}' ".
        "WHERE feature_id = $feature_id[0][0] ";
    }

    $self->_set_values($query);
}

sub do_delete_completed {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @co_id = $self->get_cv_term('completed_by');
    my @feature_id = $self->get_feature_id($gene_id);
    my $featureprop_id = $self->row_exists('featureprop', 'featureprop_id', 'type_id', $feature_id[0][0], $co_id[0][0]);

    if($featureprop_id) {
    my $query = "DELETE FROM featureprop ".
                "WHERE featureprop_id = $featureprop_id ".
            "AND feature_id = $feature_id[0][0] ".
            "AND type_id = $co_id[0][0] ";

    $self->_set_values($query);

    }
}

sub do_update_gene_curation {
    my ($self, $gene_id, $curated_type, $curated, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @sc_id = $self->get_cv_term('gene_structure_curated');
    my @an_id = $self->get_cv_term('gene_annotation_curated');
    my @feature_id = $self->get_feature_id($gene_id);
    my $featureprop_id = $self->get_auto_incremented_id('featureprop', 'featureprop_id');

    if($curated_type eq "structure") {
    if(!$self->row_exists('featureprop', 'value', 'type_id', $feature_id[0][0], $sc_id[0][0])) {
        $self->do_insert_curated_structure($gene_id, $db);
    }
    else {
        $self->do_delete_curated_structure($gene_id, $db);
    }
    }
    elsif($curated_type eq "annotation") {
    if(!$self->row_exists('featureprop', 'value', 'type_id', $feature_id[0][0], $an_id[0][0])) {
        $self->do_insert_curated_annotation($gene_id, $db);
    }
    else {
        $self->do_delete_curated_annotation($gene_id, $db);
    }
    }
}

sub do_update_ident {
    my ($self, $gene_id, $identref, $xref, $changeref, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($identref->{'com_name'} ne "") {
		$self->do_update_gene_product_name($gene_id, $identref->{'com_name'}, $db) if($changeref->{'com_change'});
    } elsif($identref->{'product_name'} ne "") {
		$self->do_update_gene_product_name($gene_id, $xref->{'product_name'}, $db) if($changeref->{'pn_change'});
    }
    $self->do_update_gene_symbol($gene_id, $xref->{'gene_symbol'}, $db) if($changeref->{'gs_change'});

	if( $changeref->{'ec_change'} ) {
		# $xref->{'ec_number'} may have more than one EC number separated by a space
		$self->do_update_ec_number($gene_id, $xref->{'ec_number'}, $db);
	}

    $self->do_update_comment($gene_id, $identref->{'comment'}, $db) if($changeref->{'co_change'});
    $self->do_update_public_comment($gene_id, $identref->{'pub_comment'}, $db) if($changeref->{'pc_change'});
    $self->do_update_assignby($gene_id, $self->{_user}, $db);
    $self->do_update_date($gene_id, $db);
}

sub do_update_ident_xref {
    return undef;
}

sub do_update_5prime_partial {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @fp_id = $self->get_cv_term('five_prime_partial');
    my @feature_id = $self->get_feature_id($gene_id);

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if(!$self->row_exists('featureprop', 'value', 'type_id', $feature_id[0][0], $fp_id[0][0])) {
    $self->do_insert_5prime_partial($gene_id, $db);
    }
    else {
    $self->do_delete_5prime_partial($gene_id, $db);
    }
}

sub do_update_3prime_partial {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @tp_id = $self->get_cv_term('three_prime_partial');
    my @feature_id = $self->get_feature_id($gene_id);

    if(!$self->row_exists('featureprop', 'value', 'type_id', $feature_id[0][0], $tp_id[0][0])) {
    $self->do_insert_3prime_partial($gene_id, $db);
    }
    else {
    $self->do_delete_3prime_partial($gene_id, $db);
    }

}

sub do_update_pseudogene_toggle {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @pg_id = $self->get_cv_term('is_pseudogene');
    my @feature_id = $self->get_feature_id($gene_id);

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if(!$self->row_exists('featureprop', 'value', 'type_id', $feature_id[0][0], $pg_id[0][0])) {
    $self->do_insert_pseudogene_toggle($gene_id, $db);
    }
    else {
    $self->do_delete_pseudogene_toggle($gene_id, $db);
    }
}

sub do_delete_ident_xref {
    return undef;
}

sub do_delete_role {
    my ($self, $gene_id, $role_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);
    my @feature_id = $self->get_feature_id($gene_id);

    my $query = "SELECT c.cvterm_id ".
            "FROM cvterm c, cv cv, cvterm_dbxref cd, dbxref d ".
        "WHERE d.accession = '$role_id' ".
        "AND d.dbxref_id = cd.dbxref_id ".
        "AND cd.cvterm_id = c.cvterm_id ".
        "AND c.cv_id = cv.cv_id ".
        "AND cv.name = 'TIGR_role' ";

    my $ret = $self->_get_results_ref($query);
    my $cvterm_id = $ret->[0][0];

    my $feature_cvterm_id = $self->row_exists('feature_cvterm', 'feature_cvterm_id', 'cvterm_id', $feature_id[0][0], $cvterm_id);
    my $feature_cvtermprop_id = $self->get_feature_cvtermprop_id($feature_cvterm_id);

    if($feature_cvtermprop_id) {
    my $query2 = "DELETE FROM feature_cvtermprop WHERE feature_cvtermprop_id = $feature_cvtermprop_id ";
    $self->_set_values($query2);
    }

    if($feature_cvterm_id) {
    my $query3 = "DELETE FROM feature_cvterm WHERE feature_cvterm_id = $feature_cvterm_id ";
    $self->_set_values($query3);
    }
}



###################################
# PATHEMA Subs follow
# Note: They will be cleaned up and put in the appropriate
# files.  These are here for now due to the Jan 15
# BRC deadline
###################################
sub get_omnium_to_all_ori_dbs{
    my($self, $ispublic) = @_;
    my($query);

    
    $query = "SELECT LOWER(SUBSTRING(d.name, 6, 15)), o.common_name, om.kingdom, om.taxon_id, o.organism_id, 1 ".
             "FROM organism o, organism_dbxref od, dbxref dx, db d, ".
        "(SELECT d.original_db, t.kingdom, t.taxon_id FROM common..db_data1 d, common..taxon_link1 l, common..taxon t WHERE d.id = l.db_taxonl_id AND l.taxon_uid = t.uid ) as om ".
             "WHERE LOWER(om.original_db) =* LOWER(SUBSTRING(d.name, 6, 15)) ".
             "AND d.db_id = dx.db_id ".
             "AND dx.version = \"legacy_annotation_database\" ".
             "AND o.organism_id = od.organism_id ".
             "AND od.dbxref_id = dx.dbxref_id ".
        "ORDER BY o.common_name ";
    
    my @results = $self->_get_results($query);

    return(@results);
}


sub get_all_genome_in_omnium_sorted_by_taxon{
    my($self) = @_;
    my($query);

    $query = "SELECT o.common_name, LOWER(om.original_db), om.intermediate_rank_1, om.intermediate_rank_2, om.kingdom, om.intermediate_rank_3 ".
             "FROM organism o, organism_dbxref od, dbxref dx, db d, ".
        "(SELECT d.original_db, t.kingdom, t.taxon_id, t.intermediate_rank_1, t.intermediate_rank_2, t.intermediate_rank_3 FROM common..db_data1 d, common..taxon_link1 l, common..taxon t WHERE d.id = l.db_taxonl_id AND l.taxon_uid = t.uid ) as om ".
             "WHERE LOWER(om.original_db) = LOWER(SUBSTRING(d.name, 6, 15)) ".
             "AND d.db_id = dx.db_id ".
             "AND dx.version = \"legacy_annotation_database\" ".
             "AND o.organism_id = od.organism_id ".
             "AND od.dbxref_id = dx.dbxref_id ".
        "ORDER BY om.kingdom, om.intermediate_rank_1, om.intermediate_rank_2, om.intermediate_rank_3, o.common_name";

    my @results = $self->_get_results($query);
    return(@results);
}

sub get_gene_id_to_spanning_clones{
   my($self, $gene_id, $asm_id, $ori_db) = @_;
   my @results;

   # Emtpy query to allow GenePageSidebar to work.
   # Not needed by Pathema

   return (@results);
}

sub get_ntl_locus_to_nt_locus {
    my($self, $NTL_locus) = @_;

    #Empty query to allow GenePageAllvsAll to work
    # Needed by pathema

    my @results;
    $results[0][0] = ($NTL_locus);
    return(@results);
}

sub get_omnium_to_all_orgs_sorted_by_taxon{
    my($self) = @_;
    my($query);

    $query = "SELECT o.organism_id, o.common_name, LOWER(om.original_db), om.kingdom, om.genus, om.species, om.strain, om.intermediate_rank_1, om.intermediate_rank_2, om.intermediate_rank_3, om.intermediate_rank_4, om.intermediate_rank_5, om.intermediate_rank_6 ".
             "FROM organism o, organism_dbxref od, dbxref dx, db d, ".
        "(SELECT d.original_db, t.kingdom, t.genus, t.species, t.strain, t.intermediate_rank_1, t.intermediate_rank_2, t.intermediate_rank_3, t.intermediate_rank_4, t.intermediate_rank_5, t.intermediate_rank_6 FROM common..db_data1 d, common..taxon_link1 l, common..taxon t WHERE d.id = l.db_taxonl_id AND l.taxon_uid = t.uid ) as om ".
             "WHERE LOWER(om.original_db) = LOWER(SUBSTRING(d.name, 6, 15)) ".
             "AND d.db_id = dx.db_id ".
             "AND dx.version = \"legacy_annotation_database\" ".
             "AND o.organism_id = od.organism_id ".
             "AND od.dbxref_id = dx.dbxref_id ".
        "ORDER BY  om.kingdom, om.intermediate_rank_1, om.intermediate_rank_2, om.intermediate_rank_3, om.intermediate_rank_4, om.intermediate_rank_5, om.intermediate_rank_6 ";


    my @results = $self->_get_results($query);
    return(@results);
}

sub get_direction_id_to_gene_ids{
    my($self, $direction_id) = @_;
    my($query);

    $query = "SELECT distinct d.gene_id ".
        "FROM operon..results r, operon..directons d ".
        "WHERE d.directon_id = ? ".
        "AND ((r.gene1_id = d.gene_id) ".
             "OR (r.gene2_id = d.gene_id)) ";

    my @results = $self->_get_results($query, $direction_id);
    return(@results);
}

sub get_operon_gene_id_to_gene_id{
    my($self, $operon_gene_id) = @_;
    my($query);

    $query = "SELECT g.locus ".
        "FROM operon..genes g ".
        "WHERE g.gene_id = ?";

    my @results = $self->_get_results($query, $operon_gene_id);
    return(@results);
}

sub get_operon_gene_id_to_operon_results{
    my($self, $gene_id, $number) = @_;
    my($query);

    $query = "SELECT r.number, r.confidence, d.directon_id ".
        "FROM operon..results r, operon..directons d ".
        "WHERE r.gene" . $number . "_id = $gene_id " .
        "AND d.gene_id = gene" . $number . "_id";

    my @results = $self->_get_results($query);
    return(@results);
}

sub get_operon_gene_id_to_operon_results_including_genes{
    my($self, $gene_id) = @_;
    my($query);

    $query = "SELECT r.number, r.confidence, r.gene1_id, r.gene2_id ".
        "FROM operon..results r ".
        "WHERE ((r.gene1_id = $gene_id) ".
             "OR (r.gene2_id = $gene_id)) ";

    my @results = $self->_get_results($query);
    return(@results);
}

sub get_gene_id_to_transporter {
    my ($self, $gene_id) = @_;
    $self->_trace if $self->{_debug};

    ## NOTE TO ANU: LEGACY NAME = ? needs to change to locus = ?

    my $query = "SELECT f.name, f.type, f.tc, m.locus, ".
            "m.subtype, m.substrate, m.tc, m.evidence, ".
                "m.substrate_type, m.legacy_name, m.legacy_org ".
                "FROM common..transport_family f, common..transport_members m, common..transport_members m2 ".
        "WHERE m2.locus = ? ".
        "AND m2.family_id = m.family_id ".
        "AND m2.group_id = m.group_id ".
            "AND m2.ori_db = m.ori_db ".
        "AND f.family_id = m.family_id ".
                "ORDER BY m.subtype";

    my $results = $self->_get_results_ref($query, $gene_id);
    return($results);

}

sub get_org_id_to_transporter {
    my ($self, $org_id, $fid) = @_;
    $self->_trace if $self->{_debug};

    ## NOTE TO ANU: LEGACY NAME = ? needs to change to locus = ?

    my $query = "SELECT f.name, f.type, f.tc, m.locus, ".
        "m.subtype, m.substrate, m.tc, m.evidence, ".
        "m.substrate_type, m.legacy_name, m.group_id ".
        "FROM common..transport_family f, common..transport_members m ".
        "WHERE LOWER(m.ori_db) = ? ".
        "AND f.family_id = m.family_id ";

    $query .= "AND f.family_id = '$fid' " if ($fid);

    $query .= "ORDER BY f.family_id, m.group_id";

    my $results = $self->_get_results_ref($query, $org_id);
    return($results);

}




sub get_all_transporter{
    my ($self) = @_;
    $self->_trace if $self->{_debug};

    my $query = "SELECT f.name, f.type, f.tc, f.family_id ".
            "FROM common..transport_family f ";

    my $results = $self->_get_results_ref($query);
    return($results);
}

sub get_ori_db_to_taxon_info{
     my ($self, $ori_db) = @_;
     $self->_trace if $self->{_debug};

     my $query = "SELECT t.kingdom, t.intermediate_rank_1, t.intermediate_rank_2, t.intermediate_rank_3, t.intermediate_rank_4, t.intermediate_rank_5, t.intermediate_rank_6, t.genus, t.species, t.strain, t.short_name, t.taxon_id ".
            "FROM common..db_data1 d, common..taxon_link1 l, common..taxon t ".
        "WHERE LOWER(d.original_db) = ? ".
        "AND d.id = l.db_taxonl_id ".
        "AND l.taxon_uid = t.uid ";

     my @results = $self->_get_results($query, $ori_db);
     return @results;
}

sub get_taxon_id_to_ori_db{
     my ($self, $taxon_id) = @_;
     $self->_trace if $self->{_debug};

     my $query = "SELECT LOWER(d.original_db), d.organism_name ".
	 "FROM common..db_data1 d, common..taxon_link1 l, common..taxon t ".
	 "WHERE t.taxon_id = ? ".
	 "AND d.id = l.db_taxonl_id ".
	 "AND l.taxon_uid = t.uid ";

     my @results = $self->_get_results($query, $taxon_id);
     return @results;
}

sub get_ori_db_to_bug_attribute{
    my($self, $ori_db, $att_type)=@_;
    my($query);

    $query = "SELECT a.score, b.att_type ".
        "FROM common..bug_attribute b, common..bug_asmbl_score a, common..db_data1 d ".
        "WHERE LOWER(d.original_db) = ? ".
        "AND d.id = b.db_data_id ".
        "AND b.id = a.input_id ";

    $query .= "AND b.att_type = '$att_type' " if($att_type);

    my @results = $self->_get_results($query, $ori_db);

    return(\@results);
}

sub get_ori_db_to_rna_count{
    my($self, $ori_db)=@_;

    ## get ori_db to org_id conversion
    my $orgs = $self->get_ori_db_org_id_lookup;
    my $org_id = $orgs->{$ori_db};

    my @args = ();

    my $query = qq/SELECT count(*)
                   FROM cm_gene
		   WHERE feat_type = ?
                  /; 

    if($ori_db){
        $query .= qq/ AND organism_id = ? /;
	push @args, $org_id;
    }

    ## formatted for the API
    my @return_results;
    my $index = 0;
    
    foreach ('tRNA', 'rRNA', 'snRNA') {
	my @results = $self->_get_results($query, ($_, @args));	
	$return_results[0][$index] = $results[0][0];
	$index++;
    }

    return(\@return_results);
}

sub get_ori_db_to_gene_count{
    my($self, $ori_db)=@_;
    my($query);

    my $orgs = $self->get_ori_db_org_id_lookup;
    my $org_id = $orgs->{$ori_db};
    
    my $query = qq/SELECT count(*) 
	           FROM cm_gene 
		   WHERE feat_type = 'gene'
		   AND organism_id = ? /;

    my @results = $self->_get_results($query, $org_id);
    return(@results);
}

sub get_ori_db_to_asm_count{
    my($self, $ori_db, $feat_type)=@_;
    my($query);

    my $orgs = $self->get_ori_db_org_id_lookup;
    my $org_id = $orgs->{$ori_db};

    # For now the feat_type doesn't matter, b/c we only have TIGR genes

    my @results;

    my @assembly_cv_id = $self->get_cv_term_id('assembly');

    $query = "SELECT count(*) "
    ." FROM feature "
    ." WHERE type_id = $assembly_cv_id[0][0] "
    ." AND organism_id = $org_id ";

    @results = $self->_get_results($query);

    return(@results);
}

sub get_ori_db_to_coding_region_len{
    my($self, $ori_db, $feat_type)=@_;
    my($query);

    my $orgs = $self->get_ori_db_org_id_lookup;
    my $org_id = $orgs->{$ori_db};

    # For now the feat_type doesn't matter, b/c we only have TIGR genes

    my @results;

    my @polypeptide_cv_id = $self->get_cv_term_id('polypeptide');

    $query = "SELECT sum(seqlen) "
	." FROM feature f "
	." WHERE type_id = $polypeptide_cv_id[0][0] "
	." AND organism_id = $org_id ";

    @results = $self->_get_results($query);
    return(@results);
}

sub get_seq_id_to_coding_region_len{
    my($self, $seq_id)=@_;
    my($query);

    my @mol_info = $self->get_mol_info_from_seq_id($seq_id);

    my @results;

    my @transcript_cv_id = $self->get_cv_term_id('polypeptide');

    $query = "SELECT sum(f.seqlen) "
    ." FROM feature f, featureloc fl "
    ." WHERE f.type_id = ? "
    ." AND f.feature_id = fl.feature_id "
    ." AND fl.srcfeature_id = ? ";

    @results = $self->_get_results($query, $transcript_cv_id[0][0], $mol_info[0][1]);
    
    return(@results);
}

sub get_ori_db_to_sequence_len{
    my($self, $ori_db, $feat_type)=@_;
    my($query);

    my $orgs = $self->get_ori_db_org_id_lookup;
    my $org_id = $orgs->{$ori_db};

    # For now the feat_type doesn't matter, b/c we only have TIGR genes

    my @results;

    my @assembly_cv_id = $self->get_cv_term_id('assembly');

    $query = "SELECT sum(seqlen) "
	." FROM feature f "
	." WHERE type_id = $assembly_cv_id[0][0] "
	." AND organism_id = $org_id ";

    @results = $self->_get_results($query);
    return(@results);
}


sub get_ori_db_to_org_attribute{
    my($self, $ori_db, $att_type)=@_;
    my($query);

    my $orgs = $self->get_ori_db_org_id_lookup;
    my $org_id = $orgs->{$ori_db};

    # For now the feat_type doesn't matter, b/c we only have TIGR genes

    my @results;

    my @att_type_cv_id = $self->get_cv_term_id($att_type);

    $query = "SELECT value  "
    ." FROM organismprop "
    ." WHERE type_id = $att_type_cv_id[0][0] "
    ." AND organism_id = $org_id ";

    @results = $self->_get_results($query);
    return(@results);
}

sub get_ori_db_and_feat_name_to_gene_id{
    my ($self, $ori_db, $feat_name)=@_;

    my $fnamelookup = $self->get_feature_id_to_gene_name_lookup();
    my $orgs = $self->get_ori_db_org_id_lookup;
    my $org_id = $orgs->{$ori_db};
    my @transcript_cv_id = $self->get_cv_term_id('transcript');

    my $query = "SELECT f.feature_id ".
        "FROM feature f, dbxref x ".
        "WHERE f.dbxref_id = x.dbxref_id ".
        "AND x.accession = '$feat_name' ".
        "AND x.version = 'feat_name' ".
        "AND f.organism_id = $org_id ".
        "AND f.type_id = $transcript_cv_id[0][0] ";

    my @return_result;
    my @results = $self->_get_results($query);

    for (my $i=0; $i<@results; $i++) {
        $return_result[$i][0] = $fnamelookup->{$results[$i][0]}->[1];
    }

    return(\@return_result);
}

sub get_org_id_to_locus_info{
    my($self,$org_id,$seq_type,$feat_type,$seq_id)=@_;

    my $field = ($seq_type eq 'protein') ? "polypeptide" : "cds";
    my $query = qq/SELECT g.locus, g.locus, g.com_name, g.gene_sym, g.ec_num,
	                  f.residues, g.organism_name, g.end5, g.end3, g.seq_name 
		   FROM   cm_gene g, feature f
		   WHERE  g.${field}_id = f.feature_id
		   AND    g.organism_id = ? /;

    my @args = ($org_id);

    ## filter by seq_id
    if($seq_id){
	$query .= qq/ AND g.seq_id = ? /;
	push @args, $seq_id;
    }

    return $self->_get_results($query, @args);

}

sub get_org_db_to_locus_info{
    my($self,$org_id,$seq_type,$feat_type,$seq_id)=@_;
    my($query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @gene_sym_cv_id = $self->get_cv_term_id('gene_symbol', 'annotation_attributes.ontology');
    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @com_name_cv_id = $self->get_cv_term_id('gene_product_name');
    my @protein_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @cds_cv_id = $self->get_cv_term_id('CDS');
    my $ec_hashref = &make_ec_hash($self);

    my @results;
    $org_id = lc($org_id);
    my $fposlookup = $self->get_feature_id_to_gene_pos_lookup;
    my $org_lookup = $self->get_org_id_to_org_name_lookup();
    my $fnamelookup = $self->get_feature_id_to_gene_name_lookup();
    my $orgs = $self->get_ori_db_org_id_lookup;
    $org_id = $orgs->{$org_id};

    $query = "SELECT f.feature_id ";
    if($seq_type eq "protein"){
    $query .= ", protein.residues ";
    }else{
    $query .= ", cds.residues ";
    }

    $query .= "FROM feature f, feature_relationship fr, feature cds ";
    if($seq_type eq "protein"){
    $query .= " ,feature protein, feature_relationship fr2 ";
    }

    $query .= "WHERE f.type_id = $transcript_cv_id[0][0] ".
        "AND f.feature_id = fr.object_id ".
        "AND cds.feature_id = fr.subject_id ".
        "AND cds.type_id = $cds_cv_id[0][0] ";

    if($seq_type eq "protein"){
    $query .= "AND cds.feature_id = fr2.object_id ".
            "AND protein.feature_id = fr2.subject_id ".
        "AND protein.type_id = $protein_cv_id[0][0] ";
    }
    if($org_id){
    $query .= "AND f.organism_id = $org_id  ";
    }

    @results = $self->_get_results($query);

    my @return_result;
    my $j = 0;
    for(my $i = 0; $i < scalar @results; $i++){
    next if($seq_id && ($fposlookup->{$results[$i][0]}->[6] ne $seq_id));
    $return_result[$j][0] = $fnamelookup->{$results[$i][0]}->[1];
    $return_result[$j][1] = $fnamelookup->{$results[$i][0]}->[1];
    $return_result[$j][4] = $ec_hashref->{$fnamelookup->{$results[$i][0]}->[1]};
    $return_result[$j][2] = $fnamelookup->{$results[$i][0]}->[2];
    $return_result[$j][3] = $fnamelookup->{$results[$i][0]}->[3];
    $return_result[$j][5] = $results[$i][1];
    $return_result[$j][6] = $org_lookup->{$fnamelookup->{$results[$i][0]}->[4]};

    if($fposlookup->{$results[$i][0]}->[3] == 1){
        $return_result[$j][7] = ($fposlookup->{$results[$i][0]}->[1] + 1);
        $return_result[$j][8] = $fposlookup->{$results[$i][0]}->[2];
    }else{
        $return_result[$j][8] = $fposlookup->{$results[$i][0]}->[2];
        $return_result[$j][7] = ($fposlookup->{$results[$i][0]}->[1] + 1);
    }

    $j++;

    }

    return(sort {$a->[6] cmp $b->[6] || $a->[7] <=> $b->[7]} @return_result);

}


sub get_org_id_to_locus_and_orf_att_info{
    my($self, $org_id, $feat_type, $att_type)=@_;
    my($query);

    $att_type =~ s/PI/pi/;
    $att_type =~ s/pI/pi/;
    $att_type =~ s/GC/percent_GC/;
    $att_type =~ s/TERM direction/term_direction/;
    $att_type =~ s/TERM confidence/term_confidence/;
    $att_type =~ s/OMP/outer_membrane_protein/;
    $att_type =~ s/LP/lipo_membrane_protein/;
    $att_type =~ s/GES/transmembrane_regions/;
    $att_type =~ s/GES coordinates/transmembrane_coords/;
    $att_type =~ s/SP C-score/c-score/;
    $att_type =~ s/SP S-score/s-score/;
    $att_type =~ s/SP s-mean/s-mean/;
    $att_type =~ s/SP site/NN_cleavage_site/;
    $att_type =~ s/SP Y-score/y-score/;

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @cds_cv_id = $self->get_cv_term_id('CDS');
    my @protein_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @com_name_cv_id = $self->get_cv_term_id('gene_product_name');

    $query = "SELECT x.accession, x.accession, fp1.value, l.fmin, l.fmax, l.strand, c.name, convert(float,fp.value) ".
    "FROM feature f, featureprop fp, featureprop fp1, cvterm c, feature_dbxref fd, dbxref x, featureloc l, feature fa ".
    "WHERE f.type_id = $transcript_cv_id[0][0] ".
    "AND f.organism_id = $org_id ".
    "AND f.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = x.dbxref_id ".
    "AND x.version = \"locus\" ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.type_id = c.cvterm_id ".
    "AND c.name in $att_type ".
    "AND f.feature_id = fp1.feature_id  ".
    "AND fp1.type_id = $com_name_cv_id[0][0] ".
    "AND f.feature_id = l.feature_id ".
    "AND l.srcfeature_id = fa.feature_id ".
    "AND fa.type_id = $assembly_cv_id[0][0] ".
    "UNION ALL ".
    "SELECT x.accession, x.accession, fp1.value, l.fmin, l.fmax, l.strand, c.name, convert(float,fp.value) ".
    "FROM feature f, featureprop fp, featureprop fp1, cvterm c, feature_dbxref fd, dbxref x, featureloc l, feature f2, feature_relationship fr, feature fa  ".
    "WHERE f.type_id = $cds_cv_id[0][0] ".
    "AND f.organism_id = $org_id ".
    "AND f.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = x.dbxref_id ".
    "AND x.version = \"locus\" ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.type_id = c.cvterm_id ".
    "AND c.name in $att_type ".
    "AND f.feature_id = fr.subject_id  ".
    "AND f2.feature_id = fr.object_id ".
    "AND f2.type_id = $transcript_cv_id[0][0] ".
    "AND fp1.feature_id = f2.feature_id ".
    "AND fp1.type_id = $com_name_cv_id[0][0] ".
    "AND f.feature_id = l.feature_id ".
    "AND l.srcfeature_id = fa.feature_id ".
    "AND fa.type_id = $assembly_cv_id[0][0] ".
    "UNION ALL ".
    "SELECT x.accession, x.accession, fp1.value, l.fmin, l.fmax, l.strand, c.name, convert(float,fp.value) ".
    "FROM feature f, featureprop fp, featureprop fp1, cvterm c, feature_dbxref fd, dbxref x, featureloc l, feature f2, feature_relationship fr, feature fa  ".
    "WHERE f.type_id = $protein_cv_id[0][0] ".
    "AND f.organism_id = $org_id ".
    "AND f.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = x.dbxref_id ".
    "AND x.version = \"locus\" ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.type_id = c.cvterm_id ".
    "AND c.name in $att_type ".
    "AND f.feature_id = fr.subject_id  ".
    "AND f2.feature_id = fr.object_id ".
    "AND f2.type_id = $transcript_cv_id[0][0] ".
    "AND fp1.feature_id = f2.feature_id ".
    "AND fp1.type_id = $com_name_cv_id[0][0] ".
    "AND l.srcfeature_id = fa.feature_id ".
    "AND fa.type_id = $assembly_cv_id[0][0] ".
    "AND f.feature_id = l.feature_id ";


    my @results = $self->_get_results($query);

    # SELECT i.locus, i.nt_locus, i.com_name, f.end5, f.end3, o.att_type, convert(float,o.score)

    my @return_result;

    for (my $i=0; $i<@results; $i++) {
    $return_result[$i][0] = $results[$i][0];
    $return_result[$i][1] = $results[$i][1];
    $return_result[$i][2] = $results[$i][2];

    if($results[$i][5] == 1){
        $return_result[$i][3] = ($results[$i][3] + 1);
        $return_result[$i][4] = $results[$i][4];
    }else{
        $return_result[$i][3] = $results[$i][4];
        $return_result[$i][4] = ($results[$i][3] + 1);
    }

    $results[$i][6] =~ s/pi/PI/;
    $results[$i][6] =~ s/percent_GC/GC/;
    $results[$i][6] =~ s/term_direction/TERM direction/;
    $results[$i][6] =~ s/term_confidence/TERM confidence/;
    $results[$i][6] =~ s/outer_membrane_protein/OMP/;
    $results[$i][6] =~ s/lipo_membrane_protein/LP/;
    $results[$i][6] =~ s/transmembrane_regions/GES/;
    $results[$i][6] =~ s/transmembrane_coords/GES coordinates/;
    $results[$i][6] =~ s/c-score/SP C-score/;
    $results[$i][6] =~ s/s-score/SP S-score/;
    $results[$i][6] =~ s/s-mean/SP s-mean/;
    $results[$i][6] =~ s/NN_cleavage_site/SP site/;
    $results[$i][6] =~ s/y-score/SP Y-score/;

    $return_result[$i][5] = $results[$i][6];
    $return_result[$i][6] = $results[$i][7];
    }


    return(@return_result);
}



sub get_all_genome_in_omnium{
    my($self)=@_;
    my($query);

    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @mol_name_cv_id = $self->get_cv_term_id('molecule_name');

    $query = "SELECT o.organism_id, LOWER(SUBSTRING(db.name, 6, 15)), o.common_name, \"\", \"\", f.uniquename, p.value, f.seqlen, \"NTORF\" "
    ." FROM organism o, organism_dbxref od, dbxref dx, feature f, featureprop p, db "
    ." WHERE o.organism_id = od.organism_id "
    ." AND od.dbxref_id = dx.dbxref_id "
    ." AND o.organism_id = f.organism_id "
    ." AND dx.version = 'legacy_annotation_database' "
    ." AND dx.db_id = db.db_id "
    ." AND f.type_id = $assembly_cv_id[0][0] "
    ." AND f.feature_id = p.feature_id "
    ." AND p.type_id = $mol_name_cv_id[0][0] "
    ." ORDER BY o.organism_id,  f.seqlen ";

    my @results = $self->_get_results($query);
    return(@results);
}


# return features of type assembly for an ori_db
sub get_ori_db_to_assembly {
    my ($self, $ori_db) = @_;
    $self->_trace if $self->{_debug};

    my @assembly_cv_id = $self->get_cv_term_id('assembly');

    my $query = "SELECT f.feature_id, f.dbxref_id, f.organism_id, f.name, f.uniquename, f.residues, f.seqlen, f.md5checksum, f.type_id, f.is_analysis, f.is_obsolete"
      ." FROM feature f, db, dbxref d, organism_dbxref od"
      ." WHERE lower(substring(db.name, 6, 15)) = ?"
      ." AND db.db_id = d.db_id"
      ." AND d.dbxref_id = od.dbxref_id"
      ." AND f.organism_id = od.organism_id"
      ." AND f.type_id = ?"
      ." ORDER BY f.seqlen DESC";
    
    return $self->_get_results($query, $ori_db, $assembly_cv_id[0][0]);
}


sub get_ori_db_to_molecule_info{
    my($self,$ori_db)=@_;
    $self->_trace if $self->{_debug};

    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @mol_name_cv_id = $self->get_cv_term_id('molecule_name');
    my @mol_type_cv_id = $self->get_cv_term_id('molecule_type');
    my @mol_topo_cv_id = $self->get_cv_term_id('topology');

    if(!($mol_type_cv_id[0][0])){
    $mol_type_cv_id[0][0] = $mol_topo_cv_id[0][0];
    }

    my $query = "SELECT o.common_name, o.organism_id, f.uniquename, p.value, p1.value, p2.value, f.seqlen ,gb.accession "
    ." FROM organism o, organism_dbxref od, dbxref dx, db db, featureprop p, "
    ."feature f "
    ."LEFT JOIN (SELECT * FROM featureprop p1 WHERE p1.type_id = $mol_type_cv_id[0][0]) AS p1 ON (f.feature_id = p1.feature_id) "
    ."LEFT JOIN (SELECT * FROM featureprop p2 WHERE p2.type_id = $mol_topo_cv_id[0][0]) AS p2 ON (f.feature_id = p2.feature_id ) "
    ."LEFT JOIN (SELECT fd.feature_id, dt.accession from dbxref dt,feature_dbxref fd,db d WHERE fd.dbxref_id = dt.dbxref_id AND dt.db_id = d.db_id  AND d.name =\"Genbank\" ) AS gb ON (f.feature_id = gb.feature_id ) "
    ." WHERE o.organism_id = od.organism_id "
    ." AND od.dbxref_id = dx.dbxref_id "
    ." AND o.organism_id = f.organism_id "
    ." AND f.type_id = $assembly_cv_id[0][0] "
    ." AND f.feature_id = p.feature_id "
    ." AND p.type_id = $mol_name_cv_id[0][0] ";

    my(@results);

    if($ori_db){
    $query .= "AND dx.version = \"legacy_annotation_database\" ".
        "AND dx.db_id = db.db_id ".
        "AND LOWER(SUBSTRING(db.name, 6, 15)) = \"$ori_db\" ";
    }

    $query .= " ORDER BY o.common_name ";

    @results = $self->_get_results($query);

    return(@results);
}

sub get_ori_db_role_id_to_gene_count{
    my($self, $ori_db, $role_id, $feat_type, $not)=@_;

    ## get org_id - faster lookup
    my $oridb_lookup = $self->get_ori_db_org_id_lookup();
    my $org_id = $oridb_lookup->{$ori_db};

    my($query, @results, $not_in, @args);

    if($not){
	$not_in = "not";
    }

    if($role_id){
	$query = qq/SELECT count(distinct g.transcript_id) 
	            FROM cm_gene g, cm_roles r 
		    WHERE r.role_id $not_in in $role_id
		    AND g.organism_id = ?
		    AND g.transcript_id = r.transcript_id /;

	push @args, $org_id;

    }else{
	$query = qq/SELECT count(g.transcript_id)
	            FROM cm_gene g
	            WHERE g.organism_id = ?
		    AND g.feat_type = 'gene'
	            AND NOT EXISTS 
	                (SELECT g.transcript_id 
	                 FROM cm_roles r
	                 WHERE r.transcript_id = g.transcript_id)
	           /;
	push @args, $org_id;
	
	
    }

    @results = $self->_get_results($query, @args);

    return(@results);

}

sub get_genome_org_check_all_db{
    my ($self, $ori_db) = @_;
    my ($query);
    my (@results);

    @results = $self->get_org_name_from_org_id_check_all_db($ori_db,'burkholderia');

    if(!@results){
        @results = $self->get_org_name_from_org_id_check_all_db($ori_db,'clostridium');

        if(!@results){
                @results = $self->get_org_name_from_org_id_check_all_db($ori_db,'bacillus');

                if(!@results){
                    @results = $self->get_org_name_from_org_id_check_all_db($ori_db,'entamoeba');
                }
        }
    }

    return($results[0][0]);
}

sub get_org_name_from_org_id_check_all_db{
    my($self, $ori_db, $organism) = @_;

    my $query = "SELECT o.common_name ".
            "FROM $organism..organism o, $organism..organism_dbxref od, $organism..dbxref dx, $organism..db db ".
            "WHERE o.organism_id = od.organism_id ".
            "AND od.dbxref_id = dx.dbxref_id ".
            "AND dx.db_id = db.db_id ".
            "and dx.version = \"legacy_annotation_database\" ".
            "AND LOWER(db.name) LIKE \"tigr_$ori_db\" ";

    return $self->_get_results($query);
}

sub get_ori_db_to_db_data_info{
    my ($self, $ori_db) = @_;
    $self->_trace if $self->{_debug};

    my @genetic_code_cv_id = $self->get_cv_term_id('genetic_code');
    my @gram_stain_cv_id = $self->get_cv_term_id('gram_stain');

    my $query = "SELECT o.organism_id, o.common_name, op1.value, op2.value, 1, \"NTORF\", t.short_name "
        ." FROM organismprop op1, organism_dbxref od, dbxref dx, db d, common..db_data1 d1, common..taxon_link1 l, common..taxon t,  "
        ."organism o "
        ."LEFT JOIN (SELECT * FROM organismprop op2 WHERE op2.type_id = $gram_stain_cv_id[0][0] ) AS op2 ON (o.organism_id = op2.organism_id) "
        ." WHERE o.organism_id = op1.organism_id "
        ." AND op1.type_id = $genetic_code_cv_id[0][0] "
        ." AND d1.id = l.db_taxonl_id "
        ." AND l.taxon_uid = t.uid "
        ." AND LOWER(d1.original_db) = LOWER(SUBSTRING(d.name, 6, 15)) "
        ." AND o.organism_id = od.organism_id "
        ." AND od.dbxref_id = dx.dbxref_id "
        ." AND dx.version = \"legacy_annotation_database\" "
        ." AND dx.db_id = d.db_id "
        ." AND LOWER(SUBSTRING(d.name, 6, 15)) = ? ";

    #print STDERR "query = $query \n";
    my @results = $self->_get_results($query, $ori_db);

    return @results;
}

sub get_species_name_to_curation{
    my($self, $species)=@_;
    my($manual_query, $auto_query_1, $auto_query_2, $prop_query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @assignby_cv_id = $self->get_cv_term_id('completed_by');
    my @results;

    $manual_query = "SELECT count(f.feature_id) ".
        "FROM featureprop fp, feature f, organism o ".
        "WHERE f.type_id = $transcript_cv_id[0][0] ".
        "AND f.organism_id = o.organism_id ".
        "AND o.common_name like \"%$species%\" ".
        "AND fp.feature_id = f.feature_id ".
        "AND fp.type_id = $assignby_cv_id[0][0] ".
        "AND fp.value != NULL ".
        "AND fp.value != \"sgc\" ".
        "AND fp.value != \"autoAnno\" ";

    my @manual_results = $self->_get_results($manual_query);

    $auto_query_1 = "SELECT count(f.feature_id) ".
        "FROM feature f, organism o ".
        "WHERE f.type_id = $transcript_cv_id[0][0] ".
        "AND f.organism_id = o.organism_id ".
        "AND o.common_name like \"%$species%\" ".
        "AND NOT EXISTS (SELECT *
                              FROM featureprop fp
                              WHERE fp.feature_id = f.feature_id
                              AND fp.type_id = $assignby_cv_id[0][0])";

    my @auto_results_1 = $self->_get_results($auto_query_1);

    $auto_query_2 = "SELECT count(f.feature_id) ".
        "FROM featureprop fp, feature f, organism o " .
        "WHERE f.type_id = $transcript_cv_id[0][0] ".
        "AND f.organism_id = o.organism_id ".
        "AND o.common_name like \"%$species%\" ".
        "AND fp.feature_id = f.feature_id ".
        "AND fp.type_id = $assignby_cv_id[0][0] ".
        "AND (fp.value = \"sgc\" ".
        "OR fp.value = \"autoAnno\") ";

    my @auto_results_2 = $self->_get_results($auto_query_2);

    $prop_query = "SELECT count(f.feature_id) ".
        "FROM featureprop fp, feature f, organism o ".
        "WHERE f.type_id = $transcript_cv_id[0][0] ".
        "AND f.organism_id = o.organism_id ".
        "AND o.common_name like \"%$species%\" ".
        "AND fp.feature_id = f.feature_id ".
        "AND fp.type_id = $assignby_cv_id[0][0] ".
        "AND fp.value = 'mummer_r' ";

    my @prop_results = $self->_get_results($prop_query);

    my @return_result;

    $return_result[0][0] = $manual_results[0][0];
    $return_result[0][1] = $auto_results_1[0][0] + $auto_results_2[0][0];
    $return_result[0][2] = $prop_results[0][0];

    return(@return_result);
}

sub get_user_email_to_info{
    my($self, $email)=@_;
    my($query);

    $query = "SELECT first_name, last_name, organization, research ".
        "FROM devel..pathema_registry ".
        "WHERE email = '$email' ";

    my @results = $self->_get_results($query);

    return(@results);
}

sub get_org_id_to_total_genes_euk{
    my($self,$org_id,$feat_type,$seq_id)=@_;
    $self->_trace if $self->{_debug};

    if($feat_type eq "TERM"){
	$feat_type = "terminator";
    }elsif($feat_type =~ /orf/i || $feat_type =~ /ntorf/i || !$feat_type){
	$feat_type = "gene";
    }

    my @mol_info = $self->get_mol_info_from_seq_id($seq_id);

    my $query = "SELECT count(f.feature_id) "
             ." FROM  feature f,feature_dbxref fdb "
        .",dbxref ld ,cvterm c , featureloc floc "
        ." WHERE fdb.feature_id = f.feature_id "
        ." AND ld.dbxref_id = fdb.dbxref_id "
        ." AND ld.version =\"locus\" "
        ." AND f.type_id = c.cvterm_id "
        ." AND c.name = ?  "
        ." AND floc.srcfeature_id = $mol_info[0][1] "
        ." AND f.feature_id = floc.feature_id "
        ." AND f.organism_id = $org_id";



      my @results = $self->_get_results($query);

    return(@results);

}



sub get_org_id_to_total_genes{
    my($self,$org_id,$feat_type,$seq_id)=@_;
    $self->_trace if $self->{_debug};


    if($seq_id){

	my @mol_info = $self->get_mol_info_from_seq_id($seq_id);
    }

    if($feat_type =~ /term/i){
	my @terminator_cv_id = $self->get_cv_term_id('terminator');
	$feat_type = $terminator_cv_id[0][0];
    }else{
	my @transcript_cv_id = $self->get_cv_term_id('transcript');
	$feat_type = $transcript_cv_id[0][0];
    }

    my @mol_info = $self->get_mol_info_from_seq_id($seq_id);

    my $query = "SELECT count (f.feature_id) ".
	"FROM feature f ";

    if($seq_id){
	$query .= ", featureloc fl ";
    }

    $query .= "WHERE f.type_id = $feat_type ";

    if($seq_id){
	$query .= "AND fl.feature_id = f.feature_id "
	    ."AND fl.srcfeature_id = $mol_info[0][1] ";
    }

    if($org_id){
	$query .= "AND f.organism_id = $org_id ";
    }

    my @results = $self->_get_results($query);
    return(@results);

}



sub get_org_id_to_role{
    my($self,$org_id,$seq_type,$feat_type,$org_type,$role,$seq_id,$sub_list)=@_;

    my($query);

    ## set query based on if residues are being pulled out
    ## due to performance benefit of not yanking them
    if($seq_type){

	my $field = "";
	if($seq_type eq "protein"){
	    $field = "cds_id";
	}else{
	    $field = "polypeptide_id";
	}

	$query = qq/ SELECT g.locus, g.locus, g.com_name, g.gene_sym,
	                    g.ec_num, c.residues, g.organism_name,
	                    r.mainrole, r.role_id, g.end5, g.end3, g.seq_name 
	             FROM cm_gene g, cm_roles r, feature c
		     WHERE g.$field = c.feature_id
		     AND g.transcript_id = r.transcript_id /;

    }else{
	$query = qq/ SELECT g.locus, g.locus, g.com_name, g.gene_sym,
	                    g.ec_num, g.organism_name,
	                    r.mainrole, r.role_id, g.end5, g.end3, g.seq_name  
	             FROM cm_gene g, cm_roles r
		     WHERE g.transcript_id = r.transcript_id /;	
    }

    my @args;

    ## restrict by organism id
    if($org_id){
	$query .= qq/ AND g.organism_id = ? /;
	push @args, $org_id;
    }

    ## restrict by sequence id
    if($seq_id){
	$query .= qq/ AND g.seq_id = ? /;
	push @args, $seq_id;
    }

    ## restrict by mainrole
    if($role) {
	$query .= qq/ AND r.mainrole = ? /;
	push @args, $role;
    }

    ## restrict by subrole
    if($sub_list) {
	## process string
	my $subroles = $sub_list;
	$subroles =~ s/[!,]/,/g;
	$subroles =~ s/,,/,/g;
	$subroles =~ s/^,//;
	$subroles =~ s/,$//;

	$query .= qq/ AND r.role_id IN ($subroles) /;
    }


    my @results = $self->_get_results($query, @args);
    return(@results);



}

sub get_org_id_to_hypotheticals{
    my($self,$org_id,$seq_type,$feat_type,$org_type,$seq_id)=@_;
    my($query);

    ## set query based on if residues are being pulled out
    ## due to performance benefit of not yanking them
    if($seq_type){

	my $field = "";
	if($seq_type eq "protein"){
	    $field = "cds_id";
	}else{
	    $field = "polypeptide_id";
	}

	$query = qq/ SELECT g.locus, g.locus, g.com_name, g.gene_sym,
	                    g.ec_num, c.residues, g.organism_name,
	                    g.end5, g.end3, g.seq_name 
	             FROM cm_gene g, feature c
		     WHERE g.$field = c.feature_id
		     AND g.feat_type = 'gene'
		     AND NOT EXISTS (SELECT * 
				     FROM cm_roles r
				     WHERE r.transcript_id = g.transcript_id) /;

    }else{
	$query = qq/ SELECT g.locus, g.locus, g.com_name, g.gene_sym,
	                    g.ec_num, '', g.organism_name,
	                    g.end5, g.end3, g.seq_name  
	             FROM cm_gene g 
		     WHERE g.feat_type = 'gene'
		     AND NOT EXISTS (SELECT * 
				     FROM cm_roles r
				     WHERE r.transcript_id = g.transcript_id)/;
    }

    my @args;

    ## restrict by organism id
    if($org_id){
	$query .= qq/ AND g.organism_id = ? /;
	push @args, $org_id;
    }

    ## restrict by sequence id
    if($seq_id){
	$query .= qq/ AND g.seq_id = ? /;
	push @args, $seq_id;
    }


    my @results = $self->_get_results($query, @args);

    return @results;
}

sub get_org_id_to_assigned_genes{
    my($self,$org_id,$seq_type,$feat_type,$org_type,$seq_id)=@_;
    my($query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @protein_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @tigr_role_cv_id = $self->get_cv_id('TIGR_role');
    my @cds_cv_id = $self->get_cv_term_id('CDS');
    my $ec_hashref = &make_ec_hash($self);

    my @results;
    $org_id = lc($org_id);

    my $org_lookup = $self->get_org_id_to_org_name_lookup();
    my ($role_lookup) = $self->get_role_lookup;
    my $fnamelookup = $self->get_feature_id_to_gene_name_lookup();
    my $fposlookup = $self->get_feature_id_to_gene_pos_lookup;



    $query = "SELECT f.feature_id, r.cvterm_id ";
    if($seq_type eq "protein"){
    $query .= ", protein.residues ";
    }else{
    $query .= ", cds.residues ";
    }

    $query .= "FROM feature_relationship fr, feature cds, ".
        "feature f ".
        "LEFT JOIN (SELECT fc.feature_id, fc.cvterm_id FROM feature_cvterm fc, cvterm c WHERE fc.cvterm_id = c.cvterm_id AND c.cv_id = $tigr_role_cv_id[0][0]) AS r ON (f.feature_id = r.feature_id) ";
    if($seq_type eq "protein"){
    $query .= " ,feature protein, feature_relationship fr2 ";
    }

    $query .= "WHERE f.type_id = $transcript_cv_id[0][0] ".
        "AND f.feature_id = fr.object_id ".
        "AND cds.feature_id = fr.subject_id ".
        "AND cds.type_id = $cds_cv_id[0][0] ";

    if($seq_type eq "protein"){
    $query .= "AND cds.feature_id = fr2.object_id ".
            "AND protein.feature_id = fr2.subject_id ".
        "AND protein.type_id = $protein_cv_id[0][0] ";
    }
    if($org_id){
    $query .= "AND f.organism_id = $org_id  ";
    }

    @results = $self->_get_results($query);

    @results = $self->_get_results($query);

    my @return_result;
    my $j = 0;
    my %locus_hash;

    for(my $i = 0; $i < scalar @results; $i++){
    next if (exists($locus_hash{$results[$i][0]}));
    next if($seq_id && ($fposlookup->{$results[$i][0]}->[6] ne $seq_id));
    next if (!exists($role_lookup->{$results[$i][1]}->[0]));

    $locus_hash{$results[$i][0]} = 1;

    $return_result[$j][0] = $fnamelookup->{$results[$i][0]}->[1];
    $return_result[$j][1] = $fnamelookup->{$results[$i][0]}->[1];
    $return_result[$j][2] = $fnamelookup->{$results[$i][0]}->[2];
    $return_result[$j][3] = $fnamelookup->{$results[$i][0]}->[3];
    $return_result[$j][4] = $ec_hashref->{$fnamelookup->{$results[$i][0]}->[1]};
    $return_result[$j][5] = $results[$i][2];
    $return_result[$j][6] = $org_lookup->{$fnamelookup->{$results[$i][0]}->[4]};
    $j++;

    }
#    print $query; exit;
#    print Data::Dumper::Dumper (\@return_result);
#    return(sort {$a->[6] cmp $b->[6] || $a->[7] <=> $b->[7]} @return_result);
    return(@return_result);

}


sub get_org_id_to_db_data_info{
     my ($self, $org_id) = @_;
     $self->_trace if $self->{_debug};

     my @genetic_code_cv_id = $self->get_cv_term_id('genetic_code');
     my @gram_stain_cv_id = $self->get_cv_term_id('gram_stain');

     my $query = "SELECT LOWER(d.original_db), o.common_name, op1.value, op2.value, 1, \"NTORF\", t.short_name "
    ." FROM organismprop op1, organism_dbxref od, dbxref dx, db db, common..db_data1 d, common..taxon_link1 l, common..taxon t, "
         ."organism o "
    ."LEFT JOIN (SELECT * FROM organismprop op2 WHERE op2.type_id = $gram_stain_cv_id[0][0] ) AS op2 ON (o.organism_id = op2.organism_id) "
    ." WHERE o.organism_id = op1.organism_id "
    ." AND op1.type_id = $genetic_code_cv_id[0][0] "
    ." AND d.id = l.db_taxonl_id "
    ." AND l.taxon_uid = t.uid "
         ." AND LOWER(d.original_db) = LOWER(SUBSTRING(db.name, 6, 15)) "
         ." AND db.db_id = dx.db_id "
         ." AND dx.version = \"legacy_annotation_database\" "
    ." AND o.organism_id = ? "
    ." AND o.organism_id = od.organism_id "
    ." AND od.dbxref_id = dx.dbxref_id ";

     my @results = $self->_get_results($query, $org_id);

     return @results;
}

sub get_ori_db_to_gene_list{
    my($self, $ori_db, $feat_type, $seq_id, $ev_code, $curation_type)=@_;
    my @results;

    #results [0]-ev_code
    my $fgoplookup = $self->get_feature_id_to_gene_go_lookup('biological_process');
    my $fgoflookup = $self->get_feature_id_to_gene_go_lookup('molecular_function');
    
    my $query = qq/SELECT  g.locus, g.gene_sym, g.com_name, g.ec_num,
                   g.end5, g.end3, g.locus, g.seq_name, 
                   g.transcript_id, g.transcript_id, g.curation_status
	           FROM cm_gene g
		   WHERE g.ori_db = ?
		   AND g.feat_type = 'gene'
		   /;

    my @args = ($ori_db);

    ## add seq_id filter
    if($seq_id && $seq_id ne 'all'){
	my @seq_id_array = split(/\!/,$seq_id);
	my $seq_id_list;

	for(my $p=0; $p<@seq_id_array; $p++){
	    $seq_id_list .= "'$seq_id_array[$p]',";
	}

	#prepare seq_id list for query
	$seq_id_list =~ s/[!,]/,/g;
	$seq_id_list =~ s/,,/,/g;
	$seq_id_list =~ s/^,//;
	$seq_id_list =~ s/,$//;

 	$query .= qq/AND g.seq_id IN ($seq_id_list) /;
    }

     ## add curation status filter
     if($curation_type){
	$query .= qq/AND g.curation_status = ? /;
	push @args, $curation_type;
    }

    @results = $self->_get_results($query, @args);
  
    my @return_result;
    my $q = 0;
    my @ev_code_array = split(/\!/,$ev_code);

    for (my $i=0; $i<@results; $i++) {

        # This code restricts the results to the ev_code
        # results passed in to this sub, if no ev_code
        # then all results returned

        my $continue = 1;

        if($ev_code){
	    $continue = 0;
	    for(my $p=0; $p<@ev_code_array; $p++){
		## if any ev_code in the array matches
		if(($fgoflookup->{$results[$i][8]}->[0] =~ /$ev_code_array[$p]/) 
		   || ($fgoflookup->{$results[$i][8]}->[0] =~ /$ev_code_array[$p]/)){
		    $continue = 1;
		}
	    }
        }


        if($continue){
	    $return_result[$q] = $results[$i];
	    ## set ev types
	    $return_result[$q][8] = $fgoflookup->{$results[$i][8]}->[0];
	    $return_result[$q][9] = $fgoplookup->{$results[$i][9]}->[0];
	    $q++;

        }
    }
    return(sort {$a->[7] cmp $b->[7] || $a->[4] <=> $b->[4]} @return_result);
}

sub get_ori_db_to_rna_list{
    my($self, $ori_db, $rna_type, $seq_id)=@_;
    my($query);

    if($rna_type eq "sRNA"){
        $rna_type = "snRNA";
    }

    my @results;

    my $oridb_lookup = $self->get_ori_db_org_id_lookup();

    my @trna_cv_id = $self->get_cv_term_id('tRNA');
    my @rrna_cv_id = $self->get_cv_term_id('rRNA');
    my @snrna_cv_id = $self->get_cv_term_id('snRNA');
    my @name_cv_id = $self->get_cv_term_id('name');
    my @gene_symbol_cv_id = $self->get_cv_term_id('gene_symbol', 'annotation_attributes.ontology');
    my @anticodon_cv_id = $self->get_cv_term_id('tRNA_anti-codon');
    my @public_comment_cv_id = $self->get_cv_term_id('public_comment');
    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @molecule_name_cv_id = $self->get_cv_term_id('molecule_name');

    if($rna_type eq "tRNA"){

        $query = "SELECT x.accession, fp1.value, fp2.value, fp3.value, l.fmin, l.fmax, l.strand, p.value, f1.residues, f1.seqlen, fp4.value, f1.uniquename, f2.uniquename ";

		  
		  $query .= "FROM featureloc l, feature f2, featureprop p, feature_dbxref fd, dbxref x,  "
				."feature f1 "
				."LEFT JOIN (SELECT * FROM featureprop fp1 WHERE fp1.type_id = $gene_symbol_cv_id[0][0]) AS fp1 ON (f1.feature_id = fp1.feature_id) "
				."LEFT JOIN (SELECT * FROM featureprop fp2 WHERE fp2.type_id = $name_cv_id[0][0]) AS fp2 ON (f1.feature_id = fp2.feature_id) "
				."LEFT JOIN (SELECT * FROM featureprop fp3 WHERE fp3.type_id = $public_comment_cv_id[0][0]) AS fp3 ON (f1.feature_id = fp3.feature_id) "
				."LEFT JOIN (SELECT * FROM featureprop fp4 WHERE fp4.type_id = $anticodon_cv_id[0][0]) AS fp4 ON (f1.feature_id = fp4.feature_id) ";

        $query .= " WHERE f1.organism_id = $oridb_lookup->{$ori_db} " if ($ori_db);
        $query .= " AND f1.type_id = $trna_cv_id[0][0] "
				." AND f1.feature_id = l.feature_id "
				." AND f2.organism_id = f1.organism_id "
				." AND f2.type_id = $assembly_cv_id[0][0] "
				." AND l.srcfeature_id = f2.feature_id "
				." AND f1.feature_id = fd.feature_id "
				." AND fd.dbxref_id = x.dbxref_id "
				." AND x.version = 'locus' "
				." AND f2.feature_id = p.feature_id "
				." AND p.type_id = $molecule_name_cv_id[0][0] ";

  

    }else{
        $query = "SELECT x.accession, fp1.value, fp2.value, fp3.value, l.fmin, l.fmax, l.strand, p.value, f1.residues, f1.seqlen, '', f1.uniquename, f2.uniquename ";

  
		  $query .= " FROM featureloc l, feature f2, featureprop p, feature_dbxref fd, dbxref x, "
				."feature f1 "
				."LEFT JOIN (SELECT * FROM featureprop fp1 WHERE fp1.type_id = $gene_symbol_cv_id[0][0]) AS fp1 ON (f1.feature_id = fp1.feature_id) "
				."LEFT JOIN (SELECT * FROM featureprop fp2 WHERE fp2.type_id = $name_cv_id[0][0]) AS fp2 ON (f1.feature_id = fp2.feature_id) "
				."LEFT JOIN (SELECT * FROM featureprop fp3 WHERE fp3.type_id = $public_comment_cv_id[0][0]) AS fp3 ON (f1.feature_id = fp3.feature_id) ";

        $query .= " WHERE f1.organism_id = $oridb_lookup->{$ori_db} " if ($ori_db);

        if($rna_type eq "snRNA"){
                $query .= " AND f1.type_id = $snrna_cv_id[0][0] ";
        }elsif($rna_type eq "rRNA"){
                $query .= " AND f1.type_id = $rrna_cv_id[0][0] ";
        }

        $query .= " AND f1.feature_id = l.feature_id "
                ." AND f2.organism_id = f1.organism_id "
                ." AND l.srcfeature_id = f2.feature_id "
					 ." AND f1.feature_id = fd.feature_id "
					 ." AND fd.dbxref_id = x.dbxref_id "
					 ." AND x.version = 'locus' "
                ." AND f2.type_id = $assembly_cv_id[0][0] "
                ." AND f2.feature_id = p.feature_id "
                ." AND p.type_id = $molecule_name_cv_id[0][0] ";

  
    }

    $query .= "ORDER BY f2.uniquename, (l.fmin + l.fmax)/2 ";




	 @results = $self->_get_results($query);

    my @return_result;
    my $j = 0;
    for (my $i=0; $i<@results; $i++) {
	next if($seq_id && ($seq_id !~ /$results[$i][12]/));
        $return_result[$j][0] = $results[$i][0];
        $return_result[$j][1] = $results[$i][1];
        $return_result[$j][2] = $results[$i][2];
        $return_result[$j][3] = $results[$i][3];

        if($results[$i][6] == 1){
                $return_result[$j][4] = ($results[$i][4] + 1);
                $return_result[$j][5] = $results[$i][5];
        }else{
                $return_result[$j][4] = $results[$i][5];
                $return_result[$j][5] = ($results[$i][4] + 1);
        }

        $return_result[$j][6] = $results[$i][7];
        $return_result[$j][7] = $results[$i][8];
        $return_result[$j][8] = $results[$i][9];
        $return_result[$j][9] = $results[$i][11];
        $return_result[$j][10] = $results[$i][10];
	$j++;
    }

    return(@return_result);
}


sub get_ori_db_to_transposon_list{
    my($self, $ori_db, $rna_type)=@_;
    my($query);


    my @results;


    $query = "SELECT oa.feat_name, oa.score, af.end5, af.end3, ci.clone_name
FROM eha2..ORF_attribute oa, eha2..asm_feature af, eha2..clone_info ci
WHERE oa.att_type=\"repeat\"
and oa.feat_name=af.feat_name
and oa.score in (\"$rna_type\")
AND af.asmbl_id = ci.asmbl_id
ORDER BY af.asmbl_id,  (af.end5+af.end3)/2";


    @results = $self->_get_results($query);

    return(@results);
}

sub get_ori_db_to_terminator_list{
    my($self, $ori_db)=@_;
    my($query);

    my @results;

    my @terminator_cv_id = $self->get_cv_term_id('terminator');
    my @term_confidence_cv_id = $self->get_cv_term_id('term_confidence');
    my @term_direction_cv_id = $self->get_cv_term_id('term_direction');
    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @molecule_name_cv_id = $self->get_cv_term_id('molecule_name');
    my @trans_cv_id = $self->get_cv_term_id('transcript');

    $query = "SELECT f1.uniquename, x1.accession, fl.fmin, fl.fmax, fl.strand, p1.value, f1.residues, p3.value, p2.value ";

    if($ori_db){
	$query .= "FROM featureprop p1, feature f2, feature f3, featureloc fl, feature_dbxref fd, dbxref x1, feature_relationship r, organism o, organism_dbxref od, dbxref dx, db, "
            ."feature f1 "
	    ."LEFT JOIN (SELECT * FROM featureprop p2 WHERE p2.type_id = $term_direction_cv_id[0][0]) AS p2 ON (f1.feature_id = p2.feature_id) "
	    ."LEFT JOIN (SELECT * FROM featureprop p3 WHERE p3.type_id = $term_confidence_cv_id[0][0]) AS p3 ON (f1.feature_id = p3.feature_id) ";
    }else{
	$query .= "FROM featureprop p1, feature f2, feature f3, featureloc fl, feature_dbxref fd, dbxref x1, feature_relationship r, organism o, "
            ."feature f1 "
	    ."LEFT JOIN (SELECT * FROM featureprop p2 WHERE p2.type_id = $term_direction_cv_id[0][0]) AS p2 ON (f1.feature_id = p2.feature_id) "
	    ."LEFT JOIN (SELECT * FROM featureprop p3 WHERE p3.type_id = $term_confidence_cv_id[0][0]) AS p3 ON (f1.feature_id = p3.feature_id) ";
    }

    $query .= "WHERE f1.type_id = $terminator_cv_id[0][0] ".
	"AND f1.feature_id = fl.feature_id ".
	"AND f2.type_id = $assembly_cv_id[0][0] ".
	"AND fl.srcfeature_id = f2.feature_id " .
	"AND f2.organism_id = f1.organism_id ".
	"AND f2.feature_id = p1.feature_id ".
	"AND p1.type_id = $molecule_name_cv_id[0][0] ".
	"AND f3.feature_id = r.object_id ".
	"AND r.subject_id = f1.feature_id ".
	"AND f3.feature_id = fd.feature_id ".
	"AND f3.type_id = $trans_cv_id[0][0] ".
	"AND fd.dbxref_id = x1.dbxref_id ".
	"AND x1.version = \"locus\" ".
	"AND f1.organism_id = o.organism_id ";

    if($ori_db){
        $query .= " AND o.organism_id = od.organism_id "
	    ." AND od.dbxref_id = dx.dbxref_id "
	    ." AND dx.version = \"legacy_annotation_database\" "
	    ." AND dx.db_id = db.db_id "
	    ." AND LOWER(SUBSTRING(db.name, 6, 15)) = ? ";
    }

    $query .= "ORDER BY x1.accession ";

    if($ori_db){
	@results = $self->_get_results($query, $ori_db);
    }else{
	@results = $self->_get_results($query);
    }

    my @return_result;

    for (my $i=0; $i<@results; $i++) {
	$return_result[$i][0] = $results[$i][0];
	$return_result[$i][1] = $results[$i][1];

	if($results[$i][4] == 1){
	    $return_result[$i][2] = ($results[$i][2] + 1);
	    $return_result[$i][3] = $results[$i][3];
	}else{
	    $return_result[$i][2] = $results[$i][3];
	    $return_result[$i][3] = ($results[$i][2] + 1);
	}

	$return_result[$i][4] = $results[$i][5];
	$return_result[$i][5] = $results[$i][6];
	$return_result[$i][6] = $results[$i][7];
	$return_result[$i][7] = $results[$i][8];
    }

    return(@return_result);
}

sub get_distinct_hmms {
    my($self, $ev_type, $org_id) = @_;

    my @match_cv_id = $self->get_cv_term_id('match_part', 'SO');

    my $query = "SELECT distinct h.hmm_acc, h.hmm_name, h.hmm_com_name, h.ec_num, h.iso_type ".
        "FROM egad..hmm2 h, analysis a, analysisfeature af, feature f, featureloc fl, feature f2, feature f3, featureloc fl2 ";

    if($ev_type eq "TIGRFAM"){
        $query .= "WHERE h.hmm_type = \"TOGA\" ";
    }elsif($ev_type eq "PFAM"){
        $query .= "WHERE h.hmm_type != \"TOGA\" ";
    }

    $query .= "AND a.name = \"HMM2_analysis\" "
        ."AND a.analysis_id = af.analysis_id  "
        ."AND af.feature_id = f.feature_id  "
        ."AND f.feature_id = fl.feature_id  "
        ."AND fl.srcfeature_id = f2.feature_id  "
        ."AND f.type_id = $match_cv_id[0][0] "
        ."AND fl.rank=0 "
        ."AND f2.uniquename = h.hmm_acc "
        ."AND f.feature_id = fl2.feature_id "
        ."AND fl2.srcfeature_id = f3.feature_id "
        ."AND fl2.rank=1 ";

    if($org_id){

        $query .= "AND f3.organism_id = $org_id ";
    }

    $query .= "ORDER BY h.hmm_acc ";

    my @results = $self->_get_results($query);
    return(@results);
}

sub get_distinct_hmms_by_org_ids {
    my($self, $ev_type, $org_ids) = @_;

    my $query = qq/SELECT distinct h.hmm_acc, h.hmm_name, 
                          h.hmm_com_name, h.ec_num, h.iso_type 
		   FROM cm_gene g, cm_evidence e, egad..hmm2 h
		   WHERE e.transcript_id = g.transcript_id
		   AND e.ev_type = 'HMM2_analysis'
		   AND e.ev_accession = h.hmm_acc /;

    if($ev_type eq "TIGRFAM"){
        $query .= qq/AND h.hmm_type = 'TOGA' /;
    }elsif($ev_type eq "PFAM"){
        $query .= qq/AND h.hmm_type != 'TOGA' /;
    }

    if($org_ids){
	$query .= qq/ AND g.org_id IN ( $org_ids ) /;
    }

    $query .= qq/ORDER BY h.hmm_acc /;

    my @results = $self->_get_results($query);
    return(@results);
}


sub get_distinct_interpros{
    my($self, $org_id)=@_;
    my($query);

    $query = "SELECT distinct i.ip_id, i.name ".
    "FROM common..interpro i ";

    if($org_id){
    $query .= ", evidence e, asm_feature f ";
    $query .= "WHERE e.accession = i.ip_id ";
    $query .= "AND e.locus = f.locus ";
    $query .= "AND f.db_data_id = $org_id ";
    }

    $query .= "ORDER BY ip_id";

    my @results = $self->_get_results($query);
    return(@results);
}

sub get_distinct_cogs{
    my($self, $org_id)=@_;
    my($query);

    my @match_cv_id = $self->get_cv_term_id('match_part', 'SO');

    $query = "SELECT distinct c.accession, c.com_name, c.gene_sym "
    ."FROM common..cog c, analysis a, analysisfeature af, feature f, featureloc fl, feature f2, feature f3, featureloc fl2 "
    ."WHERE a.name = \"NCBI_COG\" "
    ."AND a.analysis_id = af.analysis_id "
    ."AND af.feature_id = f.feature_id "
    ."AND f.feature_id = fl.feature_id "
    ."AND fl.srcfeature_id = f2.feature_id "
    ."AND f.type_id = $match_cv_id[0][0] "
    ."AND fl.rank=0 "
    ."AND f2.uniquename = c.accession "
    ."AND f.feature_id = fl2.feature_id "
    ."AND fl2.srcfeature_id = f3.feature_id "
    ."AND fl2.rank=1 ";

    if($org_id){
    $query .= "AND f3.organism_id = $org_id ";
    }

    $query .= "ORDER BY c.accession";

    my @results = $self->_get_results($query);
    return(@results);
}

sub get_distinct_cogs_by_org_ids {
    my($self, $org_ids)=@_;
    my($query);
    
    my @match_cv_id = $self->get_cv_term_id('match_part', 'SO');

    $query = "SELECT distinct c.accession, c.com_name, c.gene_sym "
    ."FROM common..cog c, analysis a, analysisfeature af, feature f, featureloc fl, feature f2, feature f3, featureloc fl2 "
    ."WHERE a.name = \"NCBI_COG\" "
    ."AND a.analysis_id = af.analysis_id "
    ."AND af.feature_id = f.feature_id "
    ."AND f.feature_id = fl.feature_id "
    ."AND fl.srcfeature_id = f2.feature_id "
    ."AND f.type_id = $match_cv_id[0][0] "
    ."AND fl.rank=0 "
    ."AND f2.uniquename = c.accession "
    ."AND f.feature_id = fl2.feature_id "
    ."AND fl2.srcfeature_id = f3.feature_id "
    ."AND fl2.rank=1 ";

    if($org_ids){
	$query .= "AND f3.organism_id in($org_ids) ";
    }
    
    $query .= "ORDER BY c.accession";

    my @results = $self->_get_results($query);
    return(@results);
}


sub get_distinct_prosites{
    my($self, $org_id)=@_;
    my($query);

    $query = "SELECT distinct p.accession, p.name, p.description ".
        "FROM common..prosite p ";

    if($org_id){
    }

    $query .= "ORDER BY accession";

    my @results = $self->_get_results($query);
    return(@results);
}


sub get_tigrfam_role_categories {
    my($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT distinct e.role_id ".
            "FROM egad..roles e, egad..hmm_role_link hl, egad..hmm2 h ".
        "WHERE e.compartment = 'microbial' ".
        "AND e.role_id = hl.role_id ".
        "AND hl.hmm_acc = h.hmm_acc ".
        "AND h.hmm_type = \"TOGA\" ".
        "AND e.mainrole != \"cell/organism defense\" ".
        "AND e.mainrole != \"Glimmer rejects\" ".
        "ORDER BY e.role_order";

    return $self->_get_results_ref($query);
}

sub get_role_id_to_categories_cmr{
    my($self, $id, $main, $ori_list) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my @trans_cv_id = $self->get_cv_term_id('transcript');
    my @tigr_role_cv_id = $self->get_cv_id('TIGR_role');

    my $query = "SELECT distinct e.role_order, e.role_id, e.mainrole, e.sub1role ".
            "FROM egad..roles e ";

    if ($ori_list){
	$query .= ", cvterm c, feature_cvterm fc, feature f, dbxref d, cvterm_dbxref cd, organism o, organism_dbxref od, dbxref dx, db ";
    }

    if ($id ne "all" && $main eq "all") {         # one role only
        $query .= "WHERE e.role_id = $id ";
    } elsif ($id eq "all" && $main ne "all") {    # main role only
        $query .= "WHERE e.compartment = 'microbial' AND mainrole = \"$main\" ";
    } else {
        $query .= "WHERE e.compartment = 'microbial' ";
    }

    if ($ori_list){
	$query .= "AND dx.version = \"legacy_annotation_database\" ".
	    "AND dx.db_id = db.db_id ".
	    "AND LOWER(SUBSTRING(db.name, 6, 15)) IN ($ori_list) ".
	    "AND d.accession = convert(varchar,e.role_id) ".
	    "AND f.type_id = $trans_cv_id[0][0] ".
	    "AND f.feature_id = fc.feature_id ".
	    "AND c.cvterm_id = fc.cvterm_id ".
	    "AND c.cv_id = $tigr_role_cv_id[0][0] ".
	    "AND cd.cvterm_id = c.cvterm_id ".
	    "AND cd.dbxref_id = d.dbxref_id ".
	    "AND f.organism_id = o.organism_id ".
	    "AND o.organism_id = od.organism_id ".
	    "AND od.dbxref_id = dx.dbxref_id ";
	

    }

    $query .= " AND e.mainrole != \"cell/organism defense\" ".
        " AND e.mainrole != \"Glimmer rejects\" ".
        " ORDER BY e.role_order ";

    return $self->_get_results_ref($query);
}

sub get_role_id_to_tigrfams {
    my($self, $id, $org_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my @trans_cv_id = $self->get_cv_term_id('transcript');

    my $query = "SELECT distinct h.hmm_acc, h.hmm_com_name, h.iso_type, h.hmm_name, h.ec_num ".
    "FROM egad..hmm2 h, egad..hmm_role_link l ";

    if($org_id){
    $query .= ", analysis a, analysisfeature af, feature f, featureloc fl, feature f2, feature f3, featureloc fl2 ";
    }

    $query .= "WHERE l.role_id = $id ".
    "AND l.hmm_acc = h.hmm_acc ".
    "AND h.hmm_type = \"TOGA\" ";

    if($org_id){
    $query .= "AND h.hmm_acc = f2.uniquename ".
        "AND a.name = \"HMM2_analysis\" ".
        "AND a.analysis_id = af.analysis_id ".
        "AND af.feature_id = f.feature_id ".
        "AND f.type_id = $trans_cv_id[0][0] ".
        "AND f.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = f2.feature_id ".
        "AND fl.rank=0 ".
        "AND f.feature_id = fl2.feature_id ".
        "AND fl2.srcfeature_id = f3.feature_id ".
        "AND fl2.rank=1 ".
        "AND f3.organism_id = $org_id ";
    }

    $query .= "ORDER BY h.hmm_acc ";

    return $self->_get_results_ref($query);
}

#this function gets all the info about the molecule for transposonPage.cgi from Chado since not available in SGD
sub get_seq_id_to_org_and_mol_info_transposon{
    my($self, $seq_id) = @_;
    my($query);


    $query = "SELECT fp.value, fe.uniquename FROM feature fe, featureprop fp WHERE fp.feature_id = fe.feature_id AND fe.feature_id = ? ";

    my @results = $self->_get_results($query, $seq_id);
    return(@results);

}


sub get_seq_id_to_org_and_mol_info{
    my($self, $seq_id) = @_;
    my($query);

    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @mol_name_cv_id = $self->get_cv_term_id('molecule_name');
    my @mol_type_cv_id = $self->get_cv_term_id('molecule_type');
    my @mol_topo_cv_id = $self->get_cv_term_id('topology');

    if(!($mol_type_cv_id[0][0])){
    $mol_type_cv_id[0][0] = $mol_topo_cv_id[0][0];
    }

    $query = "SELECT o.common_name, LOWER(SUBSTRING(db.name, 6, 15)), o.organism_id, \"NTORF\", f.uniquename, p.value, p1.value, p2.value, o.common_name, gb.accession "
    ." FROM organism o, organism_dbxref od, dbxref dx, featureprop p, db, "
    ." feature f "
    ." LEFT JOIN (SELECT * FROM featureprop p1 WHERE p1.type_id = $mol_type_cv_id[0][0]) AS p1 ON (f.feature_id = p1.feature_id) "
    ." LEFT JOIN (SELECT * FROM featureprop p2 WHERE p2.type_id = $mol_topo_cv_id[0][0]) AS p2 ON (f.feature_id = p2.feature_id) "
    ." LEFT JOIN (SELECT fd.feature_id, dt.accession from dbxref dt,feature_dbxref fd,db d WHERE fd.dbxref_id = dt.dbxref_id AND dt.db_id = d.db_id  AND d.name =\"Genbank\" ) AS gb ON (f.feature_id = gb.feature_id ) "
    ." WHERE o.organism_id = od.organism_id "
    ." AND od.dbxref_id = dx.dbxref_id "
        ." AND dx.version = \"legacy_annotation_database\" "
        ." AND dx.db_id = db.db_id "
    ." AND f.uniquename = ? "
    ." AND o.organism_id = f.organism_id "
    ." AND f.type_id = $assembly_cv_id[0][0] "
    ." AND f.feature_id = p.feature_id "
    ." AND p.type_id = $mol_name_cv_id[0][0] ";

    my @results = $self->_get_results($query, $seq_id);
    return(@results);
}

sub get_seq_id_to_sequence_cmr{
    my($self, $seq_id, $length) = @_;

    my $query = "SET TEXTSIZE $length";
    $self->_do_sql($query);
    #SET TEXTSIZE 32000 
    my $query2 = "SELECT residues ".
            "FROM feature ".
        "WHERE uniquename = ? ";


    my @results = $self->_get_results($query2, $seq_id);
    return(@results);
}

sub get_seq_id_to_sequence_length{
    my($self,$seq_id) = @_;
    my($query);

    $query = "SELECT seqlen ".
        "FROM feature ".
        "WHERE uniquename = ? ";

    my @results = $self->_get_results($query,$seq_id);

    return(@results);
}

sub get_ec_num_list {
    my($self, $ori_list) = @_;

    my @transcript_cv_id = $self->get_cv_term_id('transcript');

    #may be able to use egad..prot_function after Heaney looks into query
    #my $query = "SELECT distinct x2.accession ".
    #	        "FROM egad..prot_function pf, feature f, feature_dbxref fd, dbxref x1, cvterm c, cv v, cvterm_dbxref cd, feature_cvterm fc, dbxref x2 ";

    my $query = "SELECT distinct x2.accession ".
            "FROM feature f, feature_dbxref fd, dbxref x1, cvterm c, cv v, cvterm_dbxref cd, feature_cvterm fc, dbxref x2 ";

    if ($ori_list){
    $query .= ", organism o, organism_dbxref od, dbxref dx, db ";
    }

    #$query .= "AND x2.accession = pf.ec# "

    $query .= "WHERE f.type_id = $transcript_cv_id[0][0] "
    ." AND f.feature_id = fd.feature_id "
    ." AND fd.dbxref_id = x1.dbxref_id "
    ." AND x1.version = \"locus\" "
    ." AND f.feature_id = fc.feature_id "
    ." AND c.cvterm_id = fc.cvterm_id "
    ." AND c.cvterm_id = cd.cvterm_id "
    ." AND cd.dbxref_id = x2.dbxref_id "
    ." AND c.cv_id = v.cv_id "
    ." AND v.name = \"EC\" ";

    if ($ori_list){
    $query .= " AND f.organism_id = o.organism_id "
        ." AND o.organism_id = od.organism_id "
        ." AND od.dbxref_id = dx.dbxref_id "
        ." AND dx.version = \"legacy_annotation_database\" "
        ." AND dx.db_id = db.db_id "
        ." AND LOWER(SUBSTRING(db.name, 6, 15)) IN ($ori_list) ";
    }

    $query .= "ORDER BY x2.accession ";

    return $self->_get_results_ref($query);
}

sub get_ec_num_to_ec_info {
    my($self, $ec_num) = @_;

    my $query = "SELECT f.pfunction, f.sub1function, f.sub2function, f.sub3function, f.reaction ".
    "FROM egad..prot_function f ".
    "WHERE f.ec# = \"$ec_num\" ";

    my @results = $self->_get_results($query);

    return(@results);
}

sub get_egad_num_to_protein_info{
    my ($self, $egad) = @_;

    my $query = "SELECT p.taxon_id, pl.seq_id ".
            "FROM egad..prot_link pl, egad..protein p ".
                "WHERE pl.prot_id = ? ".
                "AND pl.prot_id = p.prot_id ";

    my @results = $self->_get_results($query, $egad);

    return (@results);
}

sub get_egad_num_to_protein_seq{
    my ($self, $egad) = @_;

    my $query = "SELECT p.prot_seq ".
                "FROM egad..protein p ".
                "WHERE p.prot_id = ?";


    my @results = $self->_get_results($query, $egad);

    return (@results);
}

sub get_egad_taxon_to_gene_info{
    my ($self, $seq_id, $taxon_id) = @_;



    my $query = "SELECT g.com_name, t.genus, t.species, g.locus, s.sequence ".
                "FROM egad..acc_link l, egad..gene g, egad..taxon t, egad..sequence s ".
                "WHERE l.seq_id = ? ".
                "AND l.seq_id = s.seq_id ".
                "AND l.gene_id = g.gene_id  ".
                "AND t.taxon_id = ? ";

    my @results = $self->_get_results($query, $seq_id, $taxon_id);

    return (@results);

}

sub get_egad_seq_num_to_acc_info{
    my ($self, $seq_id) = @_;

    #Sequence ID in egad table is different from the pathema seq id
    $seq_id = $self->get_omnium_seq_id_to_seq_id($seq_id);

    my $query = "SELECT DISTINCT db, acc#, db_name ".
                "FROM egad..acc_link l1, egad..acc_link l2, egad..accession a ".
            "WHERE l1.seq_id = ? ".
                "AND l1.gene_id = l2.gene_id ".
                "AND l2.acc_id = a.acc_id ".
                "AND db != \"GP\" ";

    my @results = $self->_get_results($query, $seq_id);

    return (@results);

}

=pod

    _get_list_values_from_sql_result_set
    Parameters:
        \@results = array of hash_refs -- essentially, the result of $sth->fetchall_arrayref({})
        @keys = a list of unique column names to collate by
    Returns:
        a list of unique key-sets, based on the values

=cut 

sub _get_list_values_from_result_set {
    my $result_list = shift;
    my @keys = @_;
    
    my %results;
    foreach my $row (@$result_list) {
        my %key_values;
        @key_values{@keys} = @$row{@keys};
        no warnings 'uninitialized';
        my $unique_id = join('^',@key_values{@keys});
        use warnings 'uninitialized';
        if ($unique_id) { # skip nulls
            $results{$unique_id} = \%key_values;
        }
    }
    return map {$results{$_}} sort keys %results;
}

sub get_gene_id_to_characterization {
    # $DB::single = 1; # drop to debugger, if we're running in debugger
    my $self = shift;
    my $gene_id = shift;
    my @accessions = map { {db=>'SP', accession => $_->[0] } } $self->get_gene_id_to_accession($gene_id, 'SP');
    push @accessions, map { {db=>'GB', accession => $_->[0]} } $self->get_gene_id_to_accession($gene_id, 'protein_id');
    my @single_val_fields = qw/protein_id accession com_name status/;
    my @list_fields = qw/ec_num role_id pmid/;
    my @complex_list_fields = ( {pk => 'go_id', keys =>[qw/go_id go_ev_code go_qualifier go_with_ev_type go_with_ev_value/],}, );
    my @select_fields = ( @single_val_fields, @list_fields, (map { @{$_->{keys}} } @complex_list_fields), );
    my $query = qq{
        SELECT p.id as protein_id, 
            a.acc_db + '|' + a.accession as accession,
            p.primary_common_name as com_name, p.status, 
            ec.ec_num, tr.role_id, r.name as pmid, 
            go.go_id, go.ev_code as go_ev_code, 
            go.qualifier as go_qualifier, 
            go.with_ev_type as go_with_ev_type, 
            go.with_ev_value as go_with_ev_value
        FROM charprot..proteins as p
            JOIN charprot..accessions as a
            ON p.id = a.protein_id
            JOIN charprot..protein_ref as pr
            ON pr.protein_id = p.id
            JOIN charprot..refs as r
            ON r.id = pr.ref_id
            LEFT JOIN charprot..protein_ec as ec
            ON ec.protein_id = p.id
            LEFT JOIN charprot..protein_tigr_roles as tr
            ON tr.protein_id = p.id
            LEFT JOIN charprot..protein_go as go
            ON go.protein_id = p.id
        WHERE a.acc_db = ?
            AND a.accession = ?
            AND r.ref_type = 'PMID'
        ORDER BY p.id, ec.ec_num, tr.role_id, go.go_id, r.name
    };
    my %all_proteins;
    foreach my $acc (@accessions) {
        my $db = $acc->{db};
        my $accession = $acc->{accession};
        $accession =~ s/^[^\|]*\|//; # strip prefix 
        my $results = $self->_get_results_ref($query, $db, $accession);
        my %proteins; # all rows by protein_id
        foreach my $row (@$results) { 
            my %result;
            @result{@select_fields} = @$row;
            push @{$proteins{$result{protein_id}}}, \%result;
        }
        # generate merged protein description
        foreach my $protein_id (keys %proteins) {
            my $protein_results = $proteins{$protein_id};
            if (not exists  $all_proteins{$protein_id} ) {
                my %merged_protein;
                @merged_protein{@single_val_fields} = @{$protein_results->[0]}{@single_val_fields};
                foreach my $field (@list_fields) {
                    my @vals = _get_list_values_from_result_set($protein_results,$field);
                    $merged_protein{$field} = [map {values %$_ } @vals];
                }
                foreach my $complex_field (@complex_list_fields) {
                    my $pk = $complex_field->{pk};
                    my $keys = $complex_field->{keys};
                    my @vals = _get_list_values_from_result_set($protein_results, @$keys);
                    $merged_protein{$pk} = \@vals;
                }
                $all_proteins{$merged_protein{protein_id}} = \%merged_protein;
            }
        }
    }
    return values(%all_proteins);
}

sub get_genus_to_characterized_list{
    my $self = shift;
    my ($genus, $ev_status) = @_;
    warn "get_genus_to_characterized_list deprecated in favor of get_characterized_for_genus\n";
#    my $query = "SELECT co.display_name, t.com_name, t.ec_nums, t.role_ids, t.GO_terms, c.organism, e.PMID, e.status ".
#                "FROM tchar..Character c, tchar..Tan t, tchar..CharObj co, tchar..Evidence e,  tchar..CharObj co2 ".
#            "WHERE c.organism like \"%$genus%\" ".
#                "AND t.DB_ID=co.DB_ID ".
#                "AND co2.DB_ID=e.DB_ID ".
#        "AND co2.display_name = c.accession ".
#                "AND co.display_name = c.accession ";
#
#    if($ev_status){
#
#    if($ev_status eq 'DB_PARSE'){
#        $query .= "AND e.status like 'DB_PARSE' ";
#    }else{
#        $query .= "AND e.status not like 'DB_PARSE' ";
#    }
#    }
#
#    $query .=   "ORDER BY c.organism, co.display_name ";
#
#    my @results = $self->_get_results($query);
    my $results = $self->get_characterized_for_genus($genus, $ev_status);
    # convert to array from hash, and flatten name lists
    my @field_map = qw/accession com_name ec_num role_id go_id organism pmid status/;
    my @normalized_results;
    foreach my $row (@$results) {
        # normalize GO ids:
        $row->{go_id} = [ map { "GO:$_" } @{$row->{go_id}} ];
        # normalize PMIDs:
        $row->{pmid} = [ map { "PMID:$_" } @{$row->{pmid}} ];
        my @new_row = map { (ref $_ eq 'ARRAY' )? join(" ", @$_) : $_ } @$row{@field_map};
        # die Data::Dumper::Dumper({orig=>$row, parsed=>\@new_row});
        push @normalized_results, \@new_row;
    }
    return (@normalized_results);

}

sub get_characterized_for_genus {
    my $self = shift;
    my ($genus, $ev_status) = @_;

    my @select_fields = qw/
        id accession com_name ec_num
        role_id go_id organism pmid status/;
    my @identifier_fields = qw/id accession com_name organism status/;
    my @list_fields = qw/ec_num role_id go_id pmid/;
    my $query = qq{
        SELECT p.id, a.acc_db + '|' +a.accession as accession,
            p.primary_common_name as com_name, ec.ec_num, tr.role_id,
            go.go_id, o.name as organism, r.name as PMID, p.status
        FROM charprot..proteins as p
            JOIN charprot..organisms as o
            ON p.taxon_id = o.taxon_id
            JOIN charprot..accessions as a
            ON p.id = a.protein_id
            JOIN charprot..protein_ref as pr
            ON pr.protein_id = p.id
            JOIN charprot..refs as r
            ON r.id = pr.ref_id
            LEFT JOIN charprot..protein_ec as ec
            ON ec.protein_id = p.id
            LEFT JOIN charprot..protein_tigr_roles as tr
            ON tr.protein_id = p.id
            LEFT JOIN charprot..protein_go as go
            ON go.protein_id = p.id
        WHERE a.id = (SELECT min(id) FROM charprot..accessions
            WHERE protein_id = p.id
            AND acc_db != 'CHAR')
        AND r.ref_type = 'PMID'
        AND o.name like ?
    };
    if (not $ev_status) {
        1;
        # pass
    }
    elsif (lc($ev_status) eq 'db_parse' or lc($ev_status) eq 'dbparse') {
        $query .= qq{
            AND p.status = 'dbparse'
        };
	#$query .= qq{
        #    AND p.status IN('dbparse', 'legacy')
	#};
    }
    else {
        $query .= qq{
            AND p.status != 'dbparse'
        }
	#$query .= qq{
	#    AND p.status NOT IN('dbparse', 'legacy')
	#};
    }
    $query .= qq{
        ORDER BY p.id, ec.ec_num, tr.role_id, go.go_id, r.name
    };

    my $results = $self->_get_results_ref($query, "$genus\%",);
    # warn scalar(@$results)," raw rows\n";
    # merge rows w/ multiple refs, ec, go, roles
    my @normalized_results;
    my $current_rec = {};
    my $current_acc;
    foreach my $row_ar (@$results) {
        # warn "processing row ",$row_ar->[0],"\n";
        my %row;
        @row{@select_fields} = @$row_ar; # convert row to hashref
        if ($current_acc ne $row{accession}) {
            # warn "new row $row{accession}\n";
            if ($current_acc) {
                # add the old record into the result list
                foreach my $list_field (@list_fields) {
                    # convert hashref to listref
                    $current_rec->{$list_field} = [ sort keys %{$current_rec->{$list_field}} ];
                }
                # warn "saving old row $current_rec{accession}\n";
                push @normalized_results, $current_rec;
                $current_rec = {};
            }
            $current_acc = $row{accession};
            foreach my $list_field (@list_fields) {
                $current_rec->{$list_field} = {};
            }
            @$current_rec{@identifier_fields} = @row{@identifier_fields};
        }
        # add multi-value fields
        foreach my $list_field (@list_fields) {
            if (my $id = $row{$list_field}) {
                # strip standard prefixes: (NB. This would be quite dangerous for text-type fields)
                $id =~ s/^\s*(GO|PMID|EC)[: \|]//i;
                $current_rec->{$list_field}{$id} ++;
            }
        }
    }
    # catch the final record
    if ($current_acc) {
        # warn "saving old row $current_rec{accession}\n";
        foreach my $list_field (@list_fields) {
            $current_rec->{$list_field} = [ sort keys %{$current_rec->{$list_field}} ];
        }
        push @normalized_results, $current_rec;
    }

    # die "<pre>",Data::Dumper::Dumper(\@normalized_results),"</pre>";
    return \@normalized_results;
}

sub get_ps_id_to_description{
     my ($self, $ps_id) = @_;
     $self->_trace if $self->{_debug};

     my $query = "SELECT description FROM common..prosite WHERE accession = '$ps_id'";

     my @results = $self->_get_results($query);
     return @results;
}

sub get_ip_id_to_description{
     my ($self, $ip_id) = @_;
     $self->_trace if $self->{_debug};

     my $query = "SELECT name FROM common..interpro WHERE ip_id = '$ip_id'";

     my @results = $self->_get_results($query);
     return @results;
}

sub get_search_pattern_to_gene_ids{
    my($self, $search_pattern, $ori_list, $match_type, $exact)=@_;
    my($query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @gene_sym_cv_id = $self->get_cv_term_id('gene_symbol', 'annotation_attributes.ontology');
    my @com_name_cv_id = $self->get_cv_term_id('gene_product_name');
    $search_pattern = "%$search_pattern%" if (!$exact);


    $search_pattern =~ s/_/\[_\]/g;

    $query = "SELECT f.feature_id, f.organism_id ".
        "FROM feature f, featureprop fp ".
        "WHERE f.feature_id = fp.feature_id ".
        "AND f.type_id = $transcript_cv_id[0][0] ";

    if($match_type){
        $query .= "AND fp.type_id = $gene_sym_cv_id[0][0] " if ($match_type eq "gene_sym");
        $query .= "AND fp.type_id = $com_name_cv_id[0][0] " if ($match_type eq "com_name");
    }else{
        $query .= "AND (fp.type_id = $gene_sym_cv_id[0][0] OR fp.type_id = $com_name_cv_id[0][0]) ";
    }

    $query .= "AND lower(fp.value) like '$search_pattern' ";

    if(!$match_type || $match_type eq "locus" || $match_type eq "nt_locus"){
        $query .= "UNION ALL " if (!$match_type);
        $query = "" if ($match_type eq "locus" || $match_type eq "nt_locus");

        $query .= "SELECT f.feature_id, f.organism_id ".
                "FROM feature f, feature_dbxref fd, dbxref x ".
                "WHERE f.type_id = $transcript_cv_id[0][0] ".
                "AND f.feature_id = fd.feature_id ".
                "AND fd.dbxref_id = x.dbxref_id ".
                "AND x.version = \"locus\" ".
                "AND lower(x.accession) like '$search_pattern' ";
    }

#    print "$match_type: ".$query;
#    exit;
    my @results = $self->_get_results($query);

    return (\@results);

}

sub get_search_pattern_to_gene_ids_extended{
    my($self, $search_pattern, $ori_list, $feat_type, $terms_ref, $logic_ref, $match_type, $exact, $curation_type)=@_;
    my($query);

    my @terms = @$terms_ref;
    my @logic = @$logic_ref;
    $search_pattern = $terms[0];

    my $results = &get_search_pattern_to_gene_ids($self, $search_pattern, $ori_list, $match_type, $exact);

    my $e;
    my $prev_e = 0;

    my @full_list;

    foreach $e (@$results) {
        next if ($e->[0] == $prev_e);
        push @full_list,  $e->[0];
    }

    my $fnamelookup = $self->get_feature_id_to_gene_name_lookup;
    my $fposlookup = $self->get_feature_id_to_gene_pos_lookup;
    my $org_lookup = $self->get_org_id_to_org_name_lookup();
    my $oridb_lookup = $self->get_ori_db_org_id_lookup();

    my $fproplookup;
    $fproplookup = $self->get_feature_id_to_featureprop_lookup if ($curation_type);

    for(my $i = 1; $i < scalar @terms; $i++){

        my %union; my %isect;
        $results = &get_search_pattern_to_gene_ids($self, $terms[$i], $ori_list, $match_type, $exact);
        my @b_list = sort {$a->[0] <=> $b->[0]} @$results;
        foreach $e (@full_list) { $union{$e} = 1 }
        $prev_e = 0;
        foreach $e (@b_list) {
                next if ($e->[0] == $prev_e);
                if ( $union{$e->[0]} ) { $isect{$e->[0]} = 1 }
                $union{$e->[0]} = 1;
                $prev_e = $e->[0];
        }

        @full_list = keys %isect if ($logic[$i-1] =~ /and/);
        @full_list = keys %union if ($logic[$i-1] =~ /or/);


    }

    my $ec_hashref = &make_ec_hash($self);

    my @return_result;

    my $prev_locus = "";
    my $j = 0;

    @full_list = sort {$a <=> $b} @full_list;
    for (my $i=0; $i<scalar @full_list; $i++) {

        next if $full_list[$i] == $prev_locus;

        my $org_name ="'$oridb_lookup->{$fnamelookup->{$full_list[$i]}->[4]}'";

        if ($ori_list && ($ori_list !~ /$org_name/)) {
                next;
        }

        my $automated_list = "autoAnno,pamadeo,egc,egc2,autoBYOB";
        if($curation_type){
                next if (&determine_curation_type($curation_type, $fproplookup->{$full_list[$i]}));
        }

        $return_result[$j][0] = $fnamelookup->{$full_list[$i]}->[1];
        $return_result[$j][1] = $fnamelookup->{$full_list[$i]}->[1];

        # EC
        $return_result[$j][2] = $ec_hashref->{$fnamelookup->{$full_list[$i]}->[1]};
        $return_result[$j][3] = $fnamelookup->{$full_list[$i]}->[2];
        $return_result[$j][4] = $fnamelookup->{$full_list[$i]}->[3];
        $return_result[$j][5] = $org_lookup->{$fnamelookup->{$full_list[$i]}->[4]};

        if($fposlookup->{$full_list[$i]}->[3] == 1){
                $return_result[$j][6] = ($fposlookup->{$full_list[$i]}->[1] + 1);
                $return_result[$j][7] = $fposlookup->{$full_list[$i]}->[2];
        }else{
                $return_result[$j][6] = $fposlookup->{$full_list[$i]}->[2];
                $return_result[$j][7] = ($fposlookup->{$full_list[$i]}->[1] + 1);
        }
        $j++;
        $prev_locus = $full_list[$i];
    }

    return(\@return_result);

}


sub determine_curation_type{
    my ($curation_type, $curation_value) = @_;
    #returns 1 if we need to skip

    my $automated_list = "autoAnno,pamadeo,egc,egc2,autoBYOB";

    if($curation_type eq 'manual'){
        return 1 if (!$curation_value || $automated_list =~ /$curation_value/ || $curation_value eq  'mummer_r'); # no curation, or mummer remap, or auto annotate
    }elsif($curation_type eq 'mummer_r'){
        return 1 if (!$curation_value || $curation_value ne 'mummer_r');
    }else{							  # auto annotation
        return 1 if( $curation_value && $curation_value ne 'autoAnno' );
    }

    return 0;

}

sub get_search_pattern_to_old_loci_extended{
    my($self, $search_pattern, $ori_list, $feat_type, $terms_ref, $logic_ref)=@_;
    my($query);
    my @transcript_cv_id = $self->get_cv_term_id('transcript');

    $ori_list = &convert_ori_list_to_org_id_list($self, $ori_list)  if ($ori_list  && ($ori_list ne "'all'"));

    my $fnamelookup = $self->get_feature_id_to_gene_name_lookup;
    my $fposlookup = $self->get_feature_id_to_gene_pos_lookup;
    my $org_lookup = $self->get_org_id_to_org_name_lookup();
    my $oridb_lookup = $self->get_ori_db_org_id_lookup();

    $query = "SELECT f.feature_id FROM feature f, feature_dbxref fd, dbxref x, db db WHERE db.name = 'gb_old_locus_tag' AND db.db_id = x.db_id and LOWER(x.accession) LIKE '$search_pattern' AND x.dbxref_id = fd.dbxref_id and fd.feature_id = f.feature_id  AND f.type_id = $transcript_cv_id[0][0] ";

    $query .= "AND f.organism_id IN ($ori_list)" if ($ori_list  && ($ori_list ne "'all'"));

#	 print "$query";
    my $ec_hashref = &make_ec_hash($self);
    my @full_list = $self->_get_results($query);
    my @return_result;

    my $prev_locus = "";
    my $j = 0;

    for (my $i=0; $i<scalar @full_list; $i++) {
        next if $full_list[$i] == $prev_locus;
        my $org_name ="'$oridb_lookup->{$fnamelookup->{$full_list[$i][0]}->[4]}'";

        if ($ori_list && ($ori_list !~ /$org_name/)) {
                next;
        }

        $return_result[$j][0] = $fnamelookup->{$full_list[$i][0]}->[1];
        $return_result[$j][1] = $fnamelookup->{$full_list[$i][0]}->[1];

        # EC
        $return_result[$j][2] = $ec_hashref->{$full_list[$i][0]};
        $return_result[$j][3] = $fnamelookup->{$full_list[$i][0]}->[2];
        $return_result[$j][4] = $fnamelookup->{$full_list[$i][0]}->[3];
        $return_result[$j][5] = $org_lookup->{$fnamelookup->{$full_list[$i][0]}->[4]};

        if($fposlookup->{$full_list[$i]}->[3] == 1){
                $return_result[$j][6] = ($fposlookup->{$full_list[$i][0]}->[1] + 1);
                $return_result[$j][7] = $fposlookup->{$full_list[$i][0]}->[2];
        }else{
                $return_result[$j][6] = $fposlookup->{$full_list[$i][0]}->[2];
                $return_result[$j][7] = ($fposlookup->{$full_list[$i][0]}->[1] + 1);
        }
        $j++;
        $prev_locus = $full_list[$i][0];
    }

    return(\@return_result);



}

sub get_search_pattern_to_gene_ids_extended2{
    my($self, $search_pattern, $ori_list, $feat_type, $terms_ref, $logic_ref)=@_;
    my($query);

    my @terms = @$terms_ref;
    my @logic = @$logic_ref;
    $search_pattern = $terms[0];

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @gene_sym_cv_id = $self->get_cv_term_id('gene_symbol', 'annotation_attributes.ontology');
    my @com_name_cv_id = $self->get_cv_term_id('gene_product_name');

    $query = "SELECT feature_id FROM feature_prop WHERE lc(value) LIKE '%$search_pattern%' UNION ".
        "SELECT f.feature_id FROM feeature f, feature_dbxref fd, dbxref x WHERE x.accession like '%$search_pattern%' AND x.version = \"locus\" ";

    $query = "SELECT x1.accession, fp1.value, fp2.value, l.fmin, l.fmax, l.strand, o.common_name, 1 ".
        "FROM feature f2, feature_dbxref fd, dbxref x1, featureloc l, organism o, organism_dbxref od, dbxref dx, db, ".
        "feature f1 ".
        "LEFT JOIN (SELECT * FROM featureprop fp1 WHERE fp1.type_id = $gene_sym_cv_id[0][0]) AS fp1 ON (f1.feature_id = fp1.feature_id) ".
        "LEFT JOIN (SELECT * FROM featureprop fp2 WHERE fp2.type_id = $com_name_cv_id[0][0]) AS fp2 ON (f1.feature_id = fp2.feature_id) ".
        "WHERE o.organism_id = od.organism_id ".
        "AND od.dbxref_id = dx.dbxref_id ".
        "AND dx.version = \"legacy_annotation_database\" ".
        "AND dx.db_id = db.db_id ".
        "AND f1.organism_id = o.organism_id ".
        "AND f1.type_id = $transcript_cv_id[0][0] ".
        "AND f1.feature_id = fd.feature_id ".
        "AND fd.dbxref_id = x1.dbxref_id ".
        "AND x1.version = \"locus\" ".
        "AND f1.feature_id = l.feature_id ".
        "AND f2.feature_id = l.srcfeature_id ".
        "AND f2.type_id = $assembly_cv_id[0][0] ".
        "AND ((lower(x1.accession) like '%$search_pattern%' ".
        "OR lower(fp2.value) like '%$search_pattern%'  ".
    "OR lower(fp1.value) like '%$search_pattern%') ";

    for(my $i = 0; $i < scalar @logic; $i++){
        $query .= $logic[$i];
        $search_pattern = $terms[$i+1];

        $query .= "(lower(x1.accession) like '%$search_pattern%' ".
                "OR lower(fp2.value) like '%$search_pattern%'  ".
                "OR lower(fp1.value) like '%$search_pattern%') ";
    }

    $query .= ") ";

    if(($ori_list) && ($ori_list ne "'all'")){
        $query .= "AND  LOWER(SUBSTRING(db.name, 6, 15)) in ($ori_list) ";
    }

    $query .= "ORDER BY l.srcfeature_id, (l.fmin + l.fmax)/2 ";

    my $results;

    return  $self->_get_results_refmod($query, sub {
                            my $aref = shift;
                            my @return_result = ();

                            $return_result[0] = $aref->[0];
                            $return_result[1] = $aref->[0];

                            # EC
                            $return_result[2] = "";

                            $return_result[3] = $aref->[2];
                            $return_result[4] = $aref->[1];
                            $return_result[5] = $aref->[6];

                            if($aref->[5] == 1){
                            $return_result[6] = ($aref->[3] + 1);
                            $return_result[7] = $aref->[4];
                            }else{
                            $return_result[6] = $aref->[4];
                            $return_result[7] = ($aref->[3] + 1);
                            }

                            $aref->[0] = $return_result[0];
                            $aref->[1] = $return_result[1];
                            $aref->[2] = $return_result[2];
                            $aref->[3] = $return_result[3];
                            $aref->[4] = $return_result[4];
                            $aref->[5] = $return_result[5];
                            $aref->[6] = $return_result[6];
                            $aref->[7] = $return_result[7];

                        });



}

sub make_ec_hash{
    my($self)=@_;

    my @transcript_cv_id = $self->get_cv_term_id('transcript');

    my $ec_query = "SELECT x1.accession, x2.accession "
    ." FROM feature f, feature_dbxref fd, dbxref x1, cvterm c, cv v, cvterm_dbxref cd, feature_cvterm fc, dbxref x2 "
    ." WHERE f.type_id = $transcript_cv_id[0][0] "
    ." AND f.feature_id = fd.feature_id "
    ." AND fd.dbxref_id = x1.dbxref_id "
    ." AND x1.version = \"locus\" "
    ." AND f.feature_id = fc.feature_id "
    ." AND c.cvterm_id = fc.cvterm_id "
    ." AND c.cvterm_id = cd.cvterm_id "
    ." AND cd.dbxref_id = x2.dbxref_id "
    ." AND c.cv_id = v.cv_id "
    ." AND v.name = \"EC\" ";

    my @ec_results = $self->_get_results($ec_query);


    my %ec_hash;

    for (my $i=0; $i<@ec_results; $i++) {
    $ec_hash{$ec_results[$i][0]} .= " " . $ec_results[$i][1];
    }

    return(\%ec_hash);
}

sub make_gene_info_hash{
    my($self)=@_;

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @gene_sym_cv_id = $self->get_cv_term_id('gene_symbol', 'annotation_attributes.ontology');
    my @com_name_cv_id = $self->get_cv_term_id('gene_product_name');
    my @public_comment_cv_id = $self->get_cv_term_id('public_comment');

    my $query = "SELECT x1.accession, fp1.value, fp2.value, fp3.value, l.fmin, l.fmax, l.strand, f1.feature_id, o.common_name, l.srcfeature_id ".
    "FROM feature f2, feature_dbxref fd, dbxref x1, featureprop fp2, featureloc l, organism o, ".
    "feature f1 ".
    "LEFT JOIN (SELECT * FROM featureprop fp1 WHERE fp1.type_id = $gene_sym_cv_id[0][0]) AS fp1 ON (f1.feature_id = fp1.feature_id) ".
    "LEFT JOIN (SELECT * FROM featureprop fp3 WHERE fp3.type_id = $public_comment_cv_id[0][0]) AS fp3 ON (f1.feature_id = fp3.feature_id) ".
    "WHERE f1.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = x1.dbxref_id ".
    "AND f1.type_id = $transcript_cv_id[0][0] ".
    "AND x1.version = \"locus\" ".
    "AND f1.feature_id = fp2.feature_id ".
    "AND fp2.type_id = $com_name_cv_id[0][0] ".
    "AND f1.feature_id = l.feature_id ".
    "AND f2.feature_id = l.srcfeature_id ".
    "AND f2.type_id = $assembly_cv_id[0][0] ".
    "AND f1.organism_id = o.organism_id ";

    my @results = $self->_get_results($query);

    my %gene_info_hash;

    for (my $i=0; $i<@results; $i++) {
    $gene_info_hash{$results[$i][7]}->{'locus'} = $results[$i][0];
    $gene_info_hash{$results[$i][7]}->{'gene_sym'} = $results[$i][1];
    $gene_info_hash{$results[$i][7]}->{'com_name'} = $results[$i][2];
    $gene_info_hash{$results[$i][7]}->{'pub_comment'} = $results[$i][3];
    $gene_info_hash{$results[$i][7]}->{'org_name'} = $results[$i][8];

    if($results[$i][6] == 1){
        $gene_info_hash{$results[$i][7]}->{'end5'} = ($results[$i][4] + 1);
        $gene_info_hash{$results[$i][7]}->{'end3'} = $results[$i][5];
    }else{
        $gene_info_hash{$results[$i][7]}->{'end5'} = $results[$i][5];
        $gene_info_hash{$results[$i][7]}->{'end3'} = ($results[$i][4] + 1);
    }

    $gene_info_hash{$results[$i][7]}->{'asmbl_feature_id'} = $results[$i][9];
    }

    return(\%gene_info_hash);
}

sub convert_ori_list_to_org_id_list{
    my ($self, $ori_list) = @_;

    my $org_lookup = $self->get_ori_db_org_id_lookup();
    $ori_list =~ s/\'//g;
    my @arr = split(/,/, $ori_list);

    for(my $i = 0; $i < scalar @arr; $i++){
        $arr[$i] = $org_lookup->{$arr[$i]};
    }

    $ori_list = join(",", @arr);
    return $ori_list;
}

sub get_accession_to_gene_ids{
    my($self, $accession, $acc_type, $ori_list, $feat_type)=@_;
    my($query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');

    if($acc_type eq "SP"){
        $acc_type = "Swiss-Prot";
    }elsif($acc_type eq "protein_id"){
        $acc_type = "Genbank";
    }elsif($acc_type eq "PID"){
        $acc_type = "NCBI_gi";
    }

    $ori_list = &convert_ori_list_to_org_id_list($self, $ori_list)  if ($ori_list  && ($ori_list ne "'all'"));
    $query = "SELECT f.feature_id, x.accession ".
        "FROM feature f, feature_dbxref fd, dbxref x, db ".
        "WHERE f.feature_id = fd.feature_id ".
        "AND fd.dbxref_id = x.dbxref_id ".
        "AND x.db_id = db.db_id ".
        "AND f.type_id = $transcript_cv_id[0][0] ".
        "AND db.name IN (\"$acc_type\") ".
        "AND x.accession like \"$accession%\" ";
    $query .= "AND f.organism_id IN ($ori_list)" if ($ori_list  && ($ori_list ne "'all'"));
    my @results;

    @results = $self->_get_results($query);

    my $ec_hashref = &make_ec_hash($self);

    my $fnamelookup = $self->get_feature_id_to_gene_name_lookup;
    my $fposlookup = $self->get_feature_id_to_gene_pos_lookup;
    my $org_lookup = $self->get_org_id_to_org_name_lookup();

    my @return_result;
    for (my $i=0; $i<scalar @results; $i++) {

    $return_result[$i][0] = $fnamelookup->{$results[$i][0]}->[1];
    $return_result[$i][1] = $fnamelookup->{$results[$i][0]}->[1];

    # EC
    $return_result[$i][2] = $ec_hashref->{$fnamelookup->{$results[$i][0]}->[1]};
    $return_result[$i][3] = $fnamelookup->{$results[$i][0]}->[2];
    $return_result[$i][4] = $fnamelookup->{$results[$i][0]}->[3];
#	$return_result[$i][5] = $org_lookup->{$fnamelookup->{$results[$i][0]}->[4]};

    if($fposlookup->{$results[$i][0]}->[3] == 1){
        $return_result[$i][5] = ($fposlookup->{$results[$i][0]}->[1] + 1);
        $return_result[$i][6] = $fposlookup->{$results[$i][0]}->[2];
    }else{
        $return_result[$i][6] = $fposlookup->{$results[$i][0]}->[2];
        $return_result[$i][5] = ($fposlookup->{$results[$i][0]}->[1] + 1);
    }

    $return_result[$i][7] = $org_lookup->{$fnamelookup->{$results[$i][0]}->[4]};
    $return_result[$i][8] = $results[$i][1];
    }

    return(@return_result);
}

sub get_ec_num_to_gene_ids{
    my($self, $ec_num, $ori_list, $feat_type)=@_;
    my($query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @gene_sym_cv_id = $self->get_cv_term_id('gene_symbol', 'annotation_attributes.ontology');
    my @com_name_cv_id = $self->get_cv_term_id('gene_product_name');
    my @assembly_cv_id = $self->get_cv_term_id('assembly');



    my $fnamelookup = $self->get_feature_id_to_gene_name_lookup;
    my $fposlookup = $self->get_feature_id_to_gene_pos_lookup;
    my $org_lookup = $self->get_org_id_to_org_name_lookup();
    my $oridb_lookup = $self->get_ori_db_org_id_lookup();


    $query = "SELECT f1.feature_id, x2.accession ".
        "FROM cvterm c, cv v, cvterm_dbxref cd, feature_cvterm fc, dbxref x2, feature f1 ".
        "WHERE  f1.type_id = $transcript_cv_id[0][0] ".
        "AND f1.feature_id = fc.feature_id ".
        "AND c.cvterm_id = fc.cvterm_id ".
        "AND c.cvterm_id = cd.cvterm_id ".
        "AND cd.dbxref_id = x2.dbxref_id ".
        "AND c.cv_id = v.cv_id ".
        "AND v.name = \"EC\" ".
        "AND x2.accession like \"$ec_num\" ";



    my @results;

    @results = $self->_get_results($query);

    my @return_result;
    my $prev_locus; my $j = 0;
    for (my $i=0; $i<scalar @results; $i++) {
        next if $results[$i] == $prev_locus;
        my $org_name ="'$oridb_lookup->{$fnamelookup->{$results[$i][0]}->[4]}'";

        if ($ori_list && ($ori_list !~ /$org_name/) && ($ori_list ne "'all'")) {
                next;
        }

        $return_result[$j][0] = $fnamelookup->{$results[$i][0]}->[1];
        $return_result[$j][1] = $fnamelookup->{$results[$i][0]}->[1];

        # EC
        $return_result[$j][2] = $results[$i][1];
        $return_result[$j][3] = $fnamelookup->{$results[$i][0]}->[2];
        $return_result[$j][4] = $fnamelookup->{$results[$i][0]}->[3];
        $return_result[$j][5] = $org_lookup->{$fnamelookup->{$results[$i][0]}->[4]};

        if($fposlookup->{$results[$i]}->[3] == 1){
                $return_result[$j][6] = ($fposlookup->{$results[$i][0]}->[1] + 1);
                $return_result[$j][7] = $fposlookup->{$results[$i][0]}->[2];
        }else{
                $return_result[$j][6] = $fposlookup->{$results[$i][0]}->[2];
                $return_result[$j][7] = ($fposlookup->{$results[$i][0]}->[1] + 1);
        }
        $j++;
        $prev_locus = $results[$i];
    }




 return(sort {$a->[7] cmp $b->[7] || $a->[6] <=> $b->[6]} @return_result);
  #  return(@return_result);
}

sub get_evidence_to_gene_ids{
    my($self, $evidence, $ev_type, $ori_list, $feat_type)=@_;
    ## NOTE: We are not limiting by ev_type here
    ##       If needed, add the analysis table eventually

    $ori_list = &convert_ori_list_to_org_id_list($self, $ori_list)  if ($ori_list  && ($ori_list ne "'all'"));

    my $query = qq/SELECT g.locus, g.locus, g.ec_num, g.com_name, g.gene_sym,
	                  g.end5, g.end3, g.organism_name, e.ev_accession,
	                  e.score, e.ev_description
		   FROM cm_evidence e, cm_gene g
		   WHERE g.transcript_id = e.transcript_id 
		   AND e.ev_accession = ? /;
    

    $query .= qq/AND g.organism_id IN ($ori_list) / if ($ori_list  && ($ori_list ne "'all'"));

    return $self->_get_results($query, $evidence);
}

sub get_search_pattern_to_hmms{
    my($self, $search_pattern)=@_;
    my($query);

    $query = "SELECT distinct hmm_acc, hmm_name, hmm_com_name, iso_type, ec_num ".
    "FROM egad..hmm2 ".
    "WHERE (lower(hmm_acc) like '%$search_pattern%' ".
    "OR lower(hmm_name) like '%$search_pattern%' ".
    "OR lower(hmm_com_name) like '%$search_pattern%')";

    $query .= " ORDER BY hmm_acc ";

    my @results;

    @results = $self->_get_results($query);

    return(@results);
}

sub get_search_pattern_to_hmms_extended{
    my($self, $search_pattern, $terms_ref, $logic_ref)=@_;
    my($query);


    my @terms = @$terms_ref;
    my @logic = @$logic_ref;

    $search_pattern = $terms[0];

    $query = "SELECT distinct hmm_acc, hmm_name, hmm_com_name, iso_type, ec_num ".
    "FROM egad..hmm2 ".
    "WHERE ((lower(hmm_acc) like '%$search_pattern%' ".
    "OR lower(hmm_name) like '%$search_pattern%' ".
    "OR lower(hmm_com_name) like '%$search_pattern%')";

    for(my $i = 0; $i < scalar @logic; $i++){
    $query .= $logic[$i];
    $search_pattern = $terms[$i+1];

    $query .= " (lower(hmm_acc) like '%$search_pattern%' ".
    "OR lower(hmm_name) like '%$search_pattern%' ".
    "OR lower(hmm_com_name) like '%$search_pattern%') ";
    }

    $query .= ") ";

    $query .= " ORDER BY hmm_acc ";

    my @results;

    @results = $self->_get_results($query);

    return(@results);
}

sub get_search_pattern_to_prosites{
    my($self, $search_pattern)=@_;
    my($query);

    $query = "SELECT distinct accession, name, type, description ".
    "FROM common..prosite ".
    "WHERE (lower(accession) like '%$search_pattern%' ".
    "OR lower(name) like '%$search_pattern%' ".
    "OR lower(description) like '%$search_pattern%')";

    $query .= " ORDER BY accession ";

    my @results = $self->_get_results($query);

    return(@results);
}

sub get_search_pattern_to_prosites_extended{
    my($self, $search_pattern, $terms_ref, $logic_ref)=@_;
    my($query);

    my @terms = @$terms_ref;
    my @logic = @$logic_ref;

    $search_pattern = $terms[0];

    $query = "SELECT distinct accession, name, type, description ".
    "FROM common..prosite ".
    "WHERE ((lower(accession) like '%$search_pattern%' ".
    "OR lower(name) like '%$search_pattern%' ".
    "OR lower(description) like '%$search_pattern%')";

    for(my $i = 0; $i < scalar @logic; $i++){
    $query .= $logic[$i];
    $search_pattern = $terms[$i+1];

    $query .= " (lower(accession) like '%$search_pattern%' ".
    "OR lower(name) like '%$search_pattern%' ".
    "OR lower(description) like '%$search_pattern%') ";
    }

    $query .= ") ";
    $query .= " ORDER BY accession ";

    my @results;

    @results = $self->_get_results($query);

    return(@results);
}


sub get_search_pattern_to_interpros{
    my($self, $search_pattern)=@_;
    my($query);

    $query = "SELECT distinct ip_id, name ".
    "FROM common..interpro ".
    "WHERE (lower(ip_id) like '%$search_pattern%' ".
    "OR lower(name) like '%$search_pattern%')";

    $query .= " ORDER BY ip_id ";

    my @results;

    @results = $self->_get_results($query);

    return(@results);
}

sub get_search_pattern_to_interpros_extended{
    my($self, $search_pattern, $terms_ref, $logic_ref)=@_;
    my($query);
    my @terms = @$terms_ref;
    my @logic = @$logic_ref;

    $search_pattern = $terms[0];

    $query = "SELECT distinct ip_id, name ".
    "FROM common..interpro ".
    "WHERE ((lower(ip_id) like '%$search_pattern%' ".
    "OR lower(name) like '%$search_pattern%')";

    for(my $i = 0; $i < scalar @logic; $i++){
    $query .= $logic[$i];
    $search_pattern = $terms[$i+1];

    $query .= " (lower(ip_id) like '%$search_pattern%' ".
    "OR lower(name) like '%$search_pattern%')";
    }

    $query .= ") ";

    $query .= " ORDER BY ip_id ";

    my @results;

    @results = $self->_get_results($query);

    return(@results);
}


sub get_search_pattern_to_cogs{
    my($self, $search_pattern)=@_;
    my($query);

    $query = "SELECT distinct accession, com_name, gene_sym ".
    "FROM common..cog ".
    "WHERE (lower(accession) like '%$search_pattern%' ".
    "OR lower(com_name) like '%$search_pattern%' " .
    "OR lower(gene_sym) like '%$search_pattern%')";

    $query .= " ORDER BY accession ";

    my @results;

    @results = $self->_get_results($query);

    return(@results);
}

sub get_search_pattern_to_cogs_extended{
    my($self, $search_pattern, $terms_ref, $logic_ref)=@_;
    my($query);

    my @terms = @$terms_ref;
    my @logic = @$logic_ref;

    $search_pattern = $terms[0];

    $query = "SELECT distinct accession, com_name, gene_sym ".
    "FROM common..cog ".
    "WHERE ((lower(accession) like '%$search_pattern%' ".
    "OR lower(com_name) like '%$search_pattern%' " .
    "OR lower(gene_sym) like '%$search_pattern%')";

    for(my $i = 0; $i < scalar @logic; $i++){
    $query .= $logic[$i];
    $search_pattern = $terms[$i+1];

    $query .= " (lower(accession) like '%$search_pattern%' ".
    "OR lower(com_name) like '%$search_pattern%' " .
    "OR lower(gene_sym) like '%$search_pattern%')";
    }

    $query .= ") ";
    $query .= " ORDER BY accession ";

    my @results;

    @results = $self->_get_results($query);

     return(@results);
}


sub get_search_pattern_to_go_description{
    my($self, $search_pattern)=@_;

    my $query = "SELECT go_id, name, type ".
            "FROM common..go_term ".
        "WHERE (lower(name) like '%$search_pattern%' ".
        "OR go_id  like '%$search_pattern%')";

    $query .= " ORDER BY go_id ";

    my @results;

    @results = $self->_get_results($query);

    return(@results);

}

sub get_search_pattern_to_go_description_extended{
    my($self, $search_pattern, $terms_ref, $logic_ref)=@_;

    my @terms = @$terms_ref;
    my @logic = @$logic_ref;

    $search_pattern = $terms[0];

    my $query = "SELECT go_id, name, type ".
            "FROM common..go_term ".
        "WHERE ((lower(name) like '%$search_pattern%' ".
        "OR lower(go_id)  like '%$search_pattern%')";

   for(my $i = 0; $i < scalar @logic; $i++){
    $query .= $logic[$i];
    $search_pattern = $terms[$i+1];

    $query .= " (lower(name) like '%$search_pattern%' ".
        "OR lower(go_id)  like '%$search_pattern%')";
    }
    $query .= ") ";

    $query .= " ORDER BY go_id ";

    my @results;

    @results = $self->_get_results($query);

    return(@results);

}

sub get_search_pattern_to_ec_info {
    my($self, $search_pattern) = @_;

    my $query = "SELECT ec#, sub3function ".
    "FROM egad..prot_function ".
    "WHERE (lower(ec#) like '%$search_pattern%' ".
    "OR sub3function like '%$search_pattern%')";

    my @results = $self->_get_results($query);

    return(@results);
}

sub get_search_pattern_to_ec_info_extended {
    my($self, $search_pattern, $terms_ref, $logic_ref) = @_;

    my @terms = @$terms_ref;
    my @logic = @$logic_ref;

    $search_pattern = $terms[0];

    my $query = "SELECT ec#, sub3function ".
    "FROM egad..prot_function ".
    "WHERE ((lower(ec#) like '%$search_pattern%' ".
    "OR sub3function like '%$search_pattern%')";

  for(my $i = 0; $i < scalar @logic; $i++){
    $query .= $logic[$i];
    $search_pattern = $terms[$i+1];

    $query .= " (lower(ec#) like '%$search_pattern%' ".
    "OR sub3function like '%$search_pattern%')";
    }
    $query .= ") ";

    my @results = $self->_get_results($query);

    return(@results);
}


sub get_seq_id_to_asm_feat_seqs{
    my($self, $db_id, $seq_id, $feat_type, $rolelist, $coord1, $coord2) = @_;

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @prot_cv_id = $self->get_cv_term_id('protein');
    my @mol_info = $self->get_mol_info_from_seq_id($seq_id);
    my @cds_cv_id = $self->get_cv_term_id('CDS');
    my $seq_lookup = $self->get_seq_lookup;

    if($rolelist){
    my (@role_lookup_info, $roles) = $self->get_role_lookup_array;

    my %role_lookup_hash;
    for(my $i=0; $i<@role_lookup_info; $i++){
        $role_lookup_hash{$role_lookup_info[$i][1]} = $role_lookup_info[$i][0];
    }

    my @roles_array = split(/,/,$rolelist);

    my $role_ids = "";
    foreach my $role(@roles_array){
        $role =~ s/\s//g;
        my $new_role_id = $role_lookup_hash{$role};
        $role_ids .= "$new_role_id,";
    }
    chop $role_ids;

    $rolelist = $role_ids;
    }


    my $query = "";
    my @ret;
    my @final_seqs = ();

    my $select = "SELECT t.feature_id, s.residues ";

    my $from = "FROM feature t, feature_relationship fr, feature s ";

    my $where = "WHERE t.organism_id = $db_id ".
    "AND t.type_id = $transcript_cv_id[0][0] ".
    "AND t.feature_id = fr.object_id ".
    "AND fr.subject_id = s.feature_id ".
    "AND s.type_id = $cds_cv_id[0][0] ";

    if($rolelist){
    $from = $from.", feature_cvterm trans_roles ";

    $where = $where."AND trans_roles.feature_id = t.feature_id ".
        "AND trans_roles.cvterm_id IN ($rolelist) ";
    }

    if($seq_id){
    $from = $from.", featureloc f1 ";

    $where = $where."AND t.feature_id = f1.feature_id ".
        "AND f1.srcfeature_id = $mol_info[0][1] ";
    }

    if (($coord1) && ($coord2)){
    $where = $where."AND f1.fmin >= $coord1 ".
        "AND f1.fmin <= $coord2 ".
        "AND f1.fmax >= $coord1 ".
        "AND f1.fmax <= $coord2 ";
    }



    $query = $select.$from.$where." ORDER BY t.feature_id ";

    @ret = $self->_get_results($query);

    my $i = 0;

    for(my $j = 0; $j < scalar @ret; $j++){

#	$final_seqs[$j][0] = $seq_lookup->{$ret[$j][0]}->[0];
    next if($j > 0 && $ret[$j][0] == $ret[$j-1][0]);
    $final_seqs[$i][0] = $ret[$j][1];
#	print $final_seqs[$j][0], "$ret[$j][0] $seq_lookup->{$ret[$j][0]}->[0] / <BR>";
    if($final_seqs[$i][0] eq "NULL"){
        $final_seqs[$i][0] = "";
    }
    $i++;

    }

    for(my $i = 0; $i < scalar @final_seqs; $i++){
    $final_seqs[$i][0] =~ s/\W//g;
    }

    return @final_seqs;
}


sub get_seq_id_to_rna_count{
    my($self, $seq_id, $ori_db)=@_;

    my (@args, @return_results);

    my $query = qq/SELECT count(transcript_id)
	           FROM cm_gene
		   WHERE feat_type = ? /;

    if($seq_id){
	$query .= qq/AND seq_id = ? /;
	push @args, $seq_id;
    }elsif($ori_db){
	$query .= qq/AND ori_db = ? /;
	push @args, $ori_db;
    }
    
    my @tRNA_count = $self->_get_results($query, ('tRNA', @args));
    my @rRNA_count = $self->_get_results($query, ('rRNA', @args));

    $return_results[0][0] = $tRNA_count[0][0];
    $return_results[0][1] = $rRNA_count[0][0];

    return(@return_results);
}

sub get_seq_id_to_gene_count{
    my($self, $seq_id, $feat_type)=@_;



    my $query = qq/SELECT count(transcript_id)
	           FROM cm_gene 
		   WHERE feat_type = 'gene'
		   AND seq_id = ?
		   /;

    my @results = $self->_get_results($query, $seq_id);

    return(@results);
}

sub get_seq_id_role_id_to_gene_count{
    my($self, $seq_id, $role_id, $feat_type, $not,$euk)=@_;

    my($query, @results, $not_in, @args);

    if($not){
	$not_in = "not";
    }

    if($role_id){
	$query = qq/SELECT count(distinct g.transcript_id) 
	            FROM cm_gene g, cm_roles r 
		    WHERE r.role_id $not_in in $role_id
		    AND g.seq_id = ?
		    AND g.transcript_id = r.transcript_id /;

	push @args, $seq_id;

    }else{
	$query = qq/SELECT count( distinct g.transcript_id )
	            FROM cm_gene g
	            WHERE g.seq_id = ?
		    AND g.feat_type = 'gene'
	            AND NOT EXISTS 
	                (SELECT g.transcript_id 
	                 FROM cm_roles r
	                 WHERE r.transcript_id = g.transcript_id)
	           /;
	push @args, $seq_id;
	
	
    }

    @results = $self->_get_results($query, @args);

    return(@results);
}

sub get_seq_id_and_coords_to_surrounding_genes{
    my($self,$ori_db,$seq_id,$begin_coord,$end_coord,$orf_type,$rna,$center,$genomeprop)=@_;

    if(!$ori_db || !$seq_id){

    my @results = ();
    return @results;
    }


    ## add genome prop's TERM and CRISPR later
    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @trna_cv_id = $self->get_cv_term_id('tRNA');
    my @rrna_cv_id = $self->get_cv_term_id('rRNA');
    my @snrna_cv_id = $self->get_cv_term_id('snRNA');
    my @term_cv_id = $self->get_cv_term_id('terminator');
    my @crispr_cv_id = $self->get_cv_term_id('CRISPR');
    my @gene_sym_cv_id = $self->get_cv_term_id('gene_symbol', 'annotation_attributes.ontology');
    my @com_name_cv_id = $self->get_cv_term_id('gene_product_name');
    my @org_info = $self->get_org_id_org_name_from_ori_db($ori_db);
    my @mol_info = $self->get_mol_info_from_seq_id($seq_id);
    my @tigr_role_cv_id = $self->get_cv_id('TIGR_role');
    my ($role_lookup) = $self->get_role_lookup;

#    my $roles  = "(" . join(",", keys %$role_lookup) . ")";
#    $roles =~ s/\(,/\(/;
    my $feat_type_add;

    if($rna){
	$feat_type_add = " AND f.type_id in ($transcript_cv_id[0][0], $trna_cv_id[0][0], $rrna_cv_id[0][0], $snrna_cv_id[0][0]) ";
    }elsif($genomeprop){
	$feat_type_add = " AND f.type_id in ($transcript_cv_id[0][0], $term_cv_id[0][0]) ";
    }else{
	$feat_type_add = " AND f.type_id = $transcript_cv_id[0][0] ";
    }



    my $query = "SELECT f.feature_id, f.type_id, fc.cvterm_id, x.accession ".
            "FROM dbxref x, ".
        "feature f ".
        "LEFT JOIN (SELECT fc1.feature_id, fc1.cvterm_id FROM feature_cvterm fc1, cvterm c WHERE fc1.cvterm_id = c.cvterm_id AND c.cv_id =$ tigr_role_cv_id[0][0] ) AS fc ON (f.feature_id = fc.feature_id ) ".
        "WHERE ".
        "f.organism_id = $org_info[0][0] ".
        "AND f.dbxref_id = x.dbxref_id ".
        $feat_type_add ;

    my @results = $self->_get_results($query);

    my @return_result;

    # SELECT d.organism_name, d.orf_type, f.locus, f.feat_type, f.end5, f.end3, a.name, l.role_id, r.mainrole, r.sub1role, i.com_name, i.nt_locus, f.feat_name, i.gene_sym, f.feat_name

    # "SELECT l.fmin, l.fmax, l.strand, x2.accession, fp1.value, fp2.value, f1.type_id, x1.accession, fc.cvterm_id

    my $fposlookup = $self->get_feature_id_to_gene_pos_lookup;
    my $fnamelookup = $self->get_feature_id_to_gene_name_lookup;
    my $j = 0;
    for (my $i=0; $i<@results; $i++) {

	next if ($seq_id && ($seq_id ne $fposlookup->{$results[$i][0]}->[6]));

        if($begin_coord && $end_coord){

	    if($center){
		next if ((($fposlookup->{$results[$i][0]}->[1] + $fposlookup->{$results[$i][0]}->[2])/2 < $begin_coord) || (($fposlookup->{$results[$i][0]}->[1] + $fposlookup->{$results[$i][0]}->[2])/2 > $end_coord)) ;
	

            }else{
		next if (($fposlookup->{$results[$i][0]}->[1] < $begin_coord && $fposlookup->{$results[$i][0]}->[2] < $begin_coord) || ($fposlookup->{$results[$i][0]}->[1] > $end_coord && $fposlookup->{$results[$i][0]}->[2] > $begin_coord)) ;
	    }

	}

	$return_result[$j][0] = $org_info[0][1];
	$return_result[$j][1] = "NTORF";


	if($results[$i][1] == $transcript_cv_id[0][0]){
	    $return_result[$j][3] = "NTORF";
	    $return_result[$j][2] = $fnamelookup->{$results[$i][0]}->[1];
	    $return_result[$j][11] = $fnamelookup->{$results[$i][0]}->[1];

	    $return_result[$j][7] = $role_lookup->{$results[$i][2]}->[0];
	    $return_result[$j][8] = $role_lookup->{$results[$i][2]}->[1];
	    $return_result[$j][9] = $role_lookup->{$results[$i][2]}->[2];


	}elsif($results[$i][1] == $trna_cv_id[0][0]){
	    $return_result[$j][3] = "tRNA";
	}elsif($results[$i][1] == $rrna_cv_id[0][0]){
	    $return_result[$j][3] = "rRNA";
	}elsif($results[$i][1] == $snrna_cv_id[0][0]){
	    $return_result[$j][3] = "sRNA";
	}elsif($results[$i][1] == $term_cv_id[0][0]){
	    $return_result[$j][3] = "TERM";
	}elsif($results[$i][1] == $crispr_cv_id[0][0]){
	    $return_result[$j][3] = "CRISPR";
	}

	$return_result[$j][2] = $fnamelookup->{$results[$i][0]}->[1];
	$return_result[$j][11] = $fnamelookup->{$results[$i][0]}->[1];

	# 5' end 3' end

	if($fposlookup->{$results[$i][0]}->[3] == 1){
	    $return_result[$j][4] = ($fposlookup->{$results[$i][0]}->[1] + 1);
	    $return_result[$j][5] = $fposlookup->{$results[$i][0]}->[2];
	}else{
	    $return_result[$j][4] = $fposlookup->{$results[$i][0]}->[2];
	    $return_result[$j][5] = ($fposlookup->{$results[$i][0]}->[1] + 1);
	}

	# SELECT 0 d.organism_name, 1 d.orf_type, 2 f.locus, 3 f.feat_type, 4 f.end5, 5 f.end3, 6 a.name, 7 l.role_id, 8 r.mainrole, 9 r.sub1role, 10 i.com_name, 11 i.nt_locus, 12 f.feat_name, 13 i.gene_sym
	$return_result[$j][6] = $mol_info[0][0];
	$return_result[$j][10] = $fnamelookup->{$results[$i][0]}->[2];
	$return_result[$j][12] = $results[$i][3];
	$return_result[$j][13] = $fnamelookup->{$results[$i][0]}->[3];
	$return_result[$j][14] = $results[$i][3];
	$j++;
    }

    return(sort {$a->[4] <=> $b->[4]} @return_result);
}

sub get_seq_id_and_coords_to_overlapping_genes{
    my ($self, $seq_id, $min, $max) = @_;

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @mol_info = $self->get_mol_info_from_seq_id($seq_id);

    my $query = "SELECT f.feature_id ".
            "FROM feature f, featureloc fl ".
        "WHERE f.feature_id = fl.feature_id ".
        "AND f.type_id =  $transcript_cv_id[0][0] ".
        "AND fl.srcfeature_id = $mol_info[0][1] ".
        "AND fl.fmin < $min ".
        "AND fl.fmax > $max ";

    my $results = $self->_get_results_ref($query);

    my $fname_lookup = $self->get_feature_id_to_gene_name_lookup;

    for(my $i = 0; $i < @$results; $i++){
    my $tmp = $fname_lookup->{$results->[$i][0]}->[1];
#	print "BEFORE MOD:  $results->[$i][0] <BR>";
    if($tmp ne ""){
        $results->[$i][0] =  $fname_lookup->{$results->[$i][0]}->[1];
    }
#	print "AFTER MOD:  $results->[$i][0] <BR>";
    }

    return($results);

}

sub get_seq_id_and_coords_to_quality{
    my ($self, $seq_id, $min, $max) = @_;

    my @quality_cv_id = $self->get_cv_term_id('consensus_quality_value');
    my @depth_cv_id = $self->get_cv_term_id('read_depth');
    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @mol_info = $self->get_mol_info_from_seq_id($seq_id);

    my $query = "SELECT f.residues, fl.fmin, fl.fmax, f2.residues, fl2.fmin, fl2.fmax  ".
            "FROM feature f, feature f2, featureloc fl, featureloc fl2 ".
        "WHERE f.feature_id = fl.feature_id ".
        "AND f.type_id =  $depth_cv_id[0][0] ".
        "AND fl.srcfeature_id = $mol_info[0][1] ".
        "AND fl.fmin < $min ".
        "AND fl.fmax > $max ".
        "AND f2.type_id =  $quality_cv_id[0][0] ".
        "AND fl2.srcfeature_id = $mol_info[0][1] ".
        "AND f2.feature_id = fl2.feature_id ".
        "AND fl2.fmin < $min ".
        "AND fl2.fmax > $max ";

    my $results = $self->_get_results_ref($query);

    return($results);

}


sub get_seq_id_and_coords_to_microarray_probes{
    my($self, $seq_id, $begin_coord, $end_coord)=@_;

    my $query = "SELECT distinct e.accession, MIN(e.end5) as min_end5, MAX(e.end5) as max_end5, MIN(e.end3) as min_end3, MAX(e.end3) as max_end3, e.method ".
        "FROM eha2..asm_feature a, eha2..evidence e ".
        "WHERE a.feat_name = e.feat_name ".
        "AND e.ev_type = \"microarray\" ".
        "AND a.asmbl_id = $seq_id ".
        "AND e.end5 < $end_coord ".
        "AND e.end3 > $begin_coord ".
        "GROUP BY e.accession ".
        "ORDER BY (MIN(e.end5)+MAX(e.end3))/2";

    my @results = $self->_get_results($query);

    return(@results);

}


sub get_role_lookup_array{
    my($self)=@_;

    my @tigr_role_cv_id = $self->get_cv_id('TIGR_role');

    my $query = "SELECT c.cvterm_id, d.accession, r.mainrole, r.sub1role ".
        "FROM dbxref d, cvterm c, cvterm_dbxref cd, egad..roles r ".
        "WHERE c.cv_id = $tigr_role_cv_id[0][0] ".
        "AND c.cvterm_id = cd.cvterm_id ".
        "AND cd.dbxref_id = d.dbxref_id ".
        "AND d.accession = convert(varchar,r.role_id) ";

    my @results = $self->_get_results($query);

    return(@results);
}

sub get_role_lookup{
    my($self)=@_;

    my @tigr_role_cv_id = $self->get_cv_id('TIGR_role');

    my $query = "SELECT c.cvterm_id, d.accession, r.mainrole, r.sub1role ".
    "FROM dbxref d, cvterm c, cvterm_dbxref cd, egad..roles r ".
    "WHERE c.cv_id = $tigr_role_cv_id[0][0] ".
    "AND c.cvterm_id = cd.cvterm_id ".
    "AND cd.dbxref_id = d.dbxref_id ".
    "AND d.accession = convert(varchar,r.role_id) ";

    my $results = $self->_get_lookup_db($query);
    return($results);
}

sub get_feature_id_role_lookup {
    my ($self) = @_;
    
    my @tigr_role_cv_id = $self->get_cv_id('TIGR_role');
    
    my $query = qq/SELECT fc.feature_id, r.role_id, r.mainrole, r.sub1role 
	           FROM feature_cvterm fc, cvterm c, egad..roles r, cvterm_dbxref cd, dbxref x
		   WHERE fc.cvterm_id = c.cvterm_id 
		   AND c.cv_id = ?
		   AND c.cvterm_id = cd.cvterm_id
		   AND cd.dbxref_id = x.dbxref_id 
		   AND x.accession = convert(varchar,r.role_id) /;

    my $results = $self->_get_results_ref($query, $tigr_role_cv_id[0][0]);
    return($results);
}

sub get_seq_lookup{
    my($self)=@_;

    my @prot_cv_id = $self->get_cv_term_id('protein');
    my @cds_cv_id = $self->get_cv_term_id('CDS');

    my $query = "SELECT f1.object_id, g.residues, p.residues ".
    "FROM feature g, feature_relationship f1, feature p, feature_relationship f2 ".
    "WHERE g.feature_id = f1.subject_id ".
    "AND g.type_id = $cds_cv_id[0][0] ".
    "AND g.feature_id = f2.object_id ".
    "AND f2.subject_id = p.feature_id ".
    "AND p.type_id = $prot_cv_id[0][0] ";



    my $results = $self->_get_lookup_db($query);

    return($results);
}


sub get_old_gene_id_to_orf_feat_type{
    return "";
}

sub get_gene_id_to_rna_info{
    my($self, $gene_id, $rna_type)=@_;
    my($query);

    my @results;

    if($rna_type eq "sRNA"){
	$rna_type = "snRNA";
    }

    my @trna_cv_id = $self->get_cv_term_id('tRNA');
    my @rrna_cv_id = $self->get_cv_term_id('rRNA');
    my @snrna_cv_id = $self->get_cv_term_id('snRNA');
    my @name_cv_id = $self->get_cv_term_id('name');
    my @gene_symbol_cv_id = $self->get_cv_term_id('gene_symbol', 'annotation_attributes.ontology');
    my @anticodon_cv_id = $self->get_cv_term_id('tRNA_anti-codon');
    my @public_comment_cv_id = $self->get_cv_term_id('public_comment');
    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @molecule_name_cv_id = $self->get_cv_term_id('molecule_name');

    if($rna_type eq "tRNA"){

    $query = "SELECT x.accession, fp1.value, fp2.value, fp3.value, l.fmin, l.fmax, l.strand, p.value, f1.residues, f1.seqlen, fp4.value "
        ." FROM featureloc l, feature f2, featureprop p, feature_dbxref fd, dbxref x, "
        ."feature f1 "
        ."LEFT JOIN (SELECT * FROM featureprop fp1 WHERE fp1.type_id = $gene_symbol_cv_id[0][0]) AS fp1 ON (f1.feature_id = fp1.feature_id) "
        ."LEFT JOIN (SELECT * FROM featureprop fp2 WHERE fp2.type_id = $name_cv_id[0][0]) AS fp2 ON (f1.feature_id = fp2.feature_id) "
        ."LEFT JOIN (SELECT * FROM featureprop fp3 WHERE fp3.type_id = $public_comment_cv_id[0][0]) AS fp3 ON (f1.feature_id = fp3.feature_id) "
        ."LEFT JOIN (SELECT * FROM featureprop fp4 WHERE fp4.type_id = $anticodon_cv_id[0][0]) AS fp4 ON (f1.feature_id = fp4.feature_id) "
        ." WHERE x.accession = ? "
		  ." AND x.dbxref_id = fd.dbxref_id "
		  ." AND fd.feature_id = f1.feature_id "
        ." AND f1.type_id = $trna_cv_id[0][0] "
        ." AND f1.feature_id = l.feature_id "
        ." AND f2.organism_id = f1.organism_id "
        ." AND f2.type_id = $assembly_cv_id[0][0] "
        ." AND l.srcfeature_id = f2.feature_id "
        ." AND f2.feature_id = p.feature_id "
        ." AND p.type_id = $molecule_name_cv_id[0][0] ";

    }else{
		  $query = "SELECT x.accession, fp1.value, fp2.value, fp3.value, l.fmin, l.fmax, l.strand, p.value, f1.residues, f1.seqlen "
        ." FROM featureloc l, feature f2, featureprop p, feature_dbxref fd, dbxref x, "
        ."feature f1 "
        ."LEFT JOIN (SELECT * FROM featureprop fp1 WHERE fp1.type_id = $gene_symbol_cv_id[0][0]) AS fp1 ON (f1.feature_id = fp1.feature_id) "
        ."LEFT JOIN (SELECT * FROM featureprop fp2 WHERE fp2.type_id = $name_cv_id[0][0]) AS fp2 ON (f1.feature_id = fp2.feature_id) "
        ."LEFT JOIN (SELECT * FROM featureprop fp3 WHERE fp3.type_id = $public_comment_cv_id[0][0]) AS fp3 ON (f1.feature_id = fp3.feature_id) "
        ." WHERE x.accession = ? "
		  ." AND x.dbxref_id = fd.dbxref_id "
		  ." AND fd.feature_id = f1.feature_id "
        ." AND f1.feature_id = l.feature_id "
        ." AND f2.organism_id = f1.organism_id "
        ." AND l.srcfeature_id = f2.feature_id "
        ." AND f2.type_id = $assembly_cv_id[0][0] "
        ." AND f2.feature_id = p.feature_id "
        ." AND p.type_id = $molecule_name_cv_id[0][0] ";

    if($rna_type eq "snRNA"){
        $query .= " AND f1.type_id = $snrna_cv_id[0][0] ";
    }elsif($rna_type eq "rRNA"){
        $query .= " AND f1.type_id = $rrna_cv_id[0][0] ";
    }

    }

    @results = $self->_get_results($query, $gene_id);

    my @return_result;

    for (my $i=0; $i<@results; $i++) {
    $return_result[$i][0] = $results[$i][0];
    $return_result[$i][1] = $results[$i][1];
    $return_result[$i][2] = $results[$i][2];
    $return_result[$i][3] = $results[$i][3];

    if($results[$i][6] == 1){
        $return_result[$i][4] = ($results[$i][4] + 1);
        $return_result[$i][5] = $results[$i][5];
    }else{
        $return_result[$i][4] = $results[$i][5];
        $return_result[$i][5] = ($results[$i][4] + 1);
    }

    $return_result[$i][6] = $results[$i][7];
    $return_result[$i][7] = $results[$i][8];
    $return_result[$i][8] = $results[$i][9];
    $return_result[$i][9] = $results[$i][10];
    }

    return(@return_result);
}

sub get_gene_id_to_type {
    my ($self, $gene_id) = @_;

    my $query = qq/SELECT c.name
	           FROM cvterm c, feature f, feature_dbxref fd, dbxref x
		   WHERE x.accession = ?
		   AND x.dbxref_id = fd.dbxref_id 
		   AND fd.feature_id = f.feature_id
		   AND f.type_id = c.cvterm_id /;
    
    my @results = $self->_get_results($query, $gene_id);

    for (my $i=0; $i<@results; $i++) {
	if($results[$i][0] =~ /rna/i){
	    return $results[$i][0];
	}

	if($results[$i][0] =~ /polypeptide/i){
	    return "gene";
	}
    }

    return "";
}

sub get_transposon_id_to_transposon_info{
    my($self, $gene_id, $transposon_type)=@_;
    my($query);

    my @results;

#these queries are handled in the eha2 database
 $query = "select oa.feat_name, oa.score, af.end5, af.end3, ci.clone_name, asmb.sequence
from eha2..ORF_attribute oa, eha2..asm_feature af, eha2..assembly asmb, eha2..clone_info ci
where oa.att_type=\"repeat\"
and af.asmbl_id = asmb.asmbl_id
and af.asmbl_id = ci.asmbl_id
and oa.feat_name=af.feat_name
and oa.feat_name in (\"$gene_id\")";

    @results = $self->_get_results($query);

    return(@results);


}


sub get_gene_id_to_ec_num{
    my($self, $gene_id)=@_;

    my $ec_hashref = &make_ec_hash($self);
    my @results;
    $results[0][0] = $ec_hashref->{$gene_id};
    return(@results);



}

## pulls basic locus info + sequence
sub get_gene_id_to_identity_and_sequence {
    my ($self, $gene_id, $seq_type) = @_;

    ## determine which type of sequence to pull
    my $field = ($seq_type eq 'nucleotide') ? "cds" : "polypeptide";

    my $query = qq/SELECT g.locus, g.com_name, g.gene_sym, g.ec_num, g.curation_status,
                          g.seq_name, g.seq_id, g.organism_name, g.ori_db, g.end5, g.end3,
                          r.role_id, r.mainrole, r.sub1role,
                          f.residues
		   FROM   cm_gene g 
		          LEFT JOIN cm_roles r ON g.transcript_id = r.transcript_id
		          JOIN feature f ON g.${field}_id = f.feature_id
		   WHERE  g.locus = ?
		  /;

    my $results = $self->_get_results_ref($query, $gene_id);
    return $results;
}

sub get_gene_id_to_identity{
    my($self, $gene_id)=@_;
    my($query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @cds_cv_id = $self->get_cv_term_id('CDS');
    my @gene_sym_cv_id = $self->get_cv_term_id('gene_symbol', 'annotation_attributes.ontology');
    my @com_name_cv_id = $self->get_cv_term_id('gene_product_name');
    my @public_comment_cv_id = $self->get_cv_term_id('public_comment');

    # looking up specific info on the gene

    my @mol_info = $self->get_mol_info_from_gene_id($gene_id);

    my @ec_info = $self->get_gene_id_to_ec_num($gene_id);

    my @protein_info = $self->get_gene_id_to_protein_info($gene_id);

    my @db_data_info = $self->get_db_data_info_from_gene_id($gene_id);

    if(scalar @mol_info == 0){
        my @results = ();
        for my $i (0..11){
                $results[0][$i] = "";
        }
        return \@results;
    }


    $query = "SELECT f2.seqlen, l.fmin, l.fmax, l.strand, fp1.value, fp2.value, fp3.value ".
        "FROM feature_dbxref fd, dbxref x1, featureprop fp2, featureloc l, feature f2, feature_relationship fr, ".
        "feature f1 ".
        "LEFT JOIN (SELECT * FROM featureprop fp1 WHERE fp1.type_id = $gene_sym_cv_id[0][0]) AS fp1 ON (f1.feature_id = fp1.feature_id) ".
        "LEFT JOIN (SELECT * FROM featureprop fp3 WHERE fp3.type_id = $public_comment_cv_id[0][0]) AS fp3 ON (f1.feature_id = fp3.feature_id) ".
        "WHERE f1.type_id = $transcript_cv_id[0][0] ".
        "AND f1.feature_id = fd.feature_id ".
        "AND fd.dbxref_id = x1.dbxref_id  ".
        "AND x1.version = \"locus\" ".
        "AND x1.accession = ? ".
        "AND f1.feature_id = fp2.feature_id  ".
        "AND fp2.type_id = $com_name_cv_id[0][0] ".
        "AND f1.feature_id = l.feature_id  ".
        "AND l.srcfeature_id =  $mol_info[0][1] ".
        "AND f1.feature_id = fr.object_id ".
        "AND fr.subject_id  = f2.feature_id ".
        "AND f2.type_id = $cds_cv_id[0][0]";

    my @results = $self->_get_results($query, $gene_id);
    my @return_result;

#    SELECT i.com_name, i.gene_sym, i.pub_comment, af.end5, af.end3, a.name, i.ec_num, t.kingdom, t.intermediate_rank_1, datalength(af.sequence), datalength(af.protein), i.nt_locus

    for (my $i=0; $i<@results; $i++) {
        $return_result[$i][0] = $results[$i][5];
        $return_result[$i][1] = $results[$i][4];
        $return_result[$i][2] = $results[$i][6];

        if($results[$i][3] == 1){
                $return_result[$i][3] = ($results[$i][1] + 1);
                $return_result[$i][4] = $results[$i][2];
        }else{
                $return_result[$i][3] = $results[$i][2];
                $return_result[$i][4] = ($results[$i][1] + 1);
        }

        $return_result[$i][5] = $mol_info[0][0];
        $return_result[$i][6] = $ec_info[0][0];
        $return_result[$i][7] = $db_data_info[0][3];
        $return_result[$i][8] = $db_data_info[0][4];
        $return_result[$i][9] = $results[$i][0];
        $return_result[$i][10] = $protein_info[0][0];
        $return_result[$i][11] = $gene_id;
    }

    return(\@return_result);
}


sub get_rna_id_to_asm_feature_info{
    my($self, $gene_id) = @_;
    my($query);
    my @mol_info = $self->get_mol_info_from_gene_id($gene_id);
    my @db_data_info = $self->get_db_data_info_from_gene_id($gene_id);
    my @trna_cv_id = $self->get_cv_term_id('tRNA');
    my @rrna_cv_id = $self->get_cv_term_id('rRNA');
    my @snrna_cv_id = $self->get_cv_term_id('snRNA');


    if(!$mol_info[0][1]){
        my @ret = ();
        return (\@ret);
    }

    # Need to add secondary structure to this!!
    my $type_ids = "$trna_cv_id[0][0],$rrna_cv_id[0][0],$snrna_cv_id[0][0]"; 

    $query = "SELECT f1.residues, l.fmin, l.fmax, l.strand, '', f1.type_id ".
        "FROM feature f1, feature_dbxref fd, dbxref x1, featureloc l ".
        "WHERE f1.type_id in ($type_ids) ".
        "AND f1.feature_id = fd.feature_id ".
        "AND fd.dbxref_id = x1.dbxref_id  ".
        "AND x1.version = \"locus\" ".
        "AND x1.accession = ? ".
        "AND f1.feature_id = l.feature_id  ".
        "AND l.srcfeature_id =  $mol_info[0][1] ";
   
    my @results = $self->_get_results($query, $gene_id);
    my @return_result;

    # SELECT f.end5, f.end3, f.asmbl_id, f.sequence, f.protein, f.db_data_id, f.feat_name, f.feat_type, f.sec_struct

    for (my $i=0; $i<@results; $i++) {

        if($results[$i][3] == 1){
                $return_result[$i][0] = ($results[$i][1] + 1);
                $return_result[$i][1] = $results[$i][2];
        }else{
                $return_result[$i][0] = $results[$i][2];
                $return_result[$i][1] = ($results[$i][1] + 1);
        }
	
	
        $return_result[$i][2] = $mol_info[0][2];
        $return_result[$i][3] = $results[$i][0];
        $return_result[$i][4] = "";
        $return_result[$i][5] = $db_data_info[0][2];
        $return_result[$i][6] = $results[$i][4];
	if ($results[$i][5] == $trna_cv_id[0][0]){
	    $return_result[$i][7] = "tRNA";
	}elsif ($results[$i][5] == $rrna_cv_id[0][0]){
	    $return_result[$i][7] = "rRNA";
	}elsif ($results[$i][5] == $snrna_cv_id[0][0]){
	    $return_result[$i][7] = "snRNA";
	}else {
	    $return_result[$i][7] = "RNA";
	}
        $return_result[$i][8] = "";
    }

    return(\@return_result);
}



sub get_gene_id_to_asm_feature_info{
    my($self, $gene_id) = @_;
    my($query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @cds_cv_id = $self->get_cv_term_id('CDS');
    my @mol_info = $self->get_mol_info_from_gene_id($gene_id);
    my @protein_info = $self->get_gene_id_to_protein_info($gene_id);
    my @db_data_info = $self->get_db_data_info_from_gene_id($gene_id);

    if(!$mol_info[0][1]){
        my @ret = ();
		  return (\@ret);
    }

    $query = "SELECT f2.residues, l.fmin, l.fmax, l.strand, '' ".

		  "FROM feature f1, feature_dbxref fd, dbxref x1, featureloc l, feature f2, feature_relationship fr ".
		  "WHERE f1.type_id = $transcript_cv_id[0][0] ". 
		  "AND f1.feature_id = fd.feature_id ".   
		  "AND fd.dbxref_id = x1.dbxref_id  ".
		  "AND x1.version = \"locus\" ".
		  "AND x1.accession = ? ".
		  "AND f1.feature_id = l.feature_id  ".
		  "AND l.srcfeature_id =  $mol_info[0][1] ".
		  "AND f1.feature_id = fr.object_id ".
		  "AND fr.subject_id  = f2.feature_id ".
		  "AND f2.type_id = $cds_cv_id[0][0]";
   
    my @results = $self->_get_results($query, $gene_id);
    my @return_result;

    # SELECT f.end5, f.end3, f.asmbl_id, f.sequence, f.protein, f.db_data_id, f.feat_name, f.feat_type, f.sec_struct

    for (my $i=0; $i<@results; $i++) {

		  if($results[$i][3] == 1){
				$return_result[$i][0] = ($results[$i][1] + 1);
				$return_result[$i][1] = $results[$i][2];
		  }else{
				$return_result[$i][0] = $results[$i][2];
				$return_result[$i][1] = ($results[$i][1] + 1);
		  }

		  $return_result[$i][2] = $mol_info[0][2];
		  $return_result[$i][3] = $results[$i][0];
		  $return_result[$i][4] = $protein_info[0][2];
		  $return_result[$i][5] = $db_data_info[0][2];
		  $return_result[$i][6] = $results[$i][4];
		  $return_result[$i][7] = "NTORF";
		  $return_result[$i][8] = "";
	 }

    return(\@return_result); 

}

sub get_gene_id_to_org_and_mol_info{
    my($self, $gene_id, $all_genomes) = @_;
    my($query);
    my (@db_data_info,@mol_info);
    my @results;


    if($all_genomes){
        @db_data_info = $self->get_db_data_info_from_gene_id_check_all($gene_id,'burkholderia');

        if(!@db_data_info){
                @db_data_info = $self->get_db_data_info_from_gene_id_check_all($gene_id,'clostridium');

                if(!@db_data_info){
                    @db_data_info = $self->get_db_data_info_from_gene_id_check_all($gene_id,'bacillus');

                    if(!@db_data_info){
                        @db_data_info = $self->get_db_data_info_from_gene_id_check_all($gene_id,'entamoeba');
                    }
                }
        }

        $results[0][0] = $db_data_info[0][1];
        $results[0][1] = $db_data_info[0][0];
        $results[0][2] = $db_data_info[0][2];

        return(@results);
    }else{
        @mol_info = $self->get_mol_info_from_gene_id($gene_id);
        @db_data_info = $self->get_db_data_info_from_gene_id($gene_id);

        $results[0][0] = $db_data_info[0][1];
        $results[0][1] = $db_data_info[0][0];
        $results[0][2] = $db_data_info[0][2];
        $results[0][3] = $mol_info[0][2];
        $results[0][4] = $mol_info[0][0];
        $results[0][5] = $mol_info[0][3];
        $results[0][6] = $mol_info[0][4];

        return(@results);
    }

}


sub get_display_locus_to_id_locus{
    my($self, $display_locus) = @_;
    my($query);
    my @transcript_cv_id = $self->get_cv_term_id('transcript');

    $query = "SELECT x.accession ".
        "FROM dbxref x, feature_dbxref fd, feature f ".
        "WHERE lower(x.accession) like \"$display_locus\" ".
        "AND x.version = \"locus\" ".
		  "AND x.dbxref_id = fd.dbxref_id ".
		  "AND fd.feature_id = f.feature_id ".
		  "AND f.type_id = $transcript_cv_id[0][0] ";

    my @results = $self->_get_results($query);
    return(@results);

}

sub get_display_gene_id_to_identity{
    my($self, $display_locus) = @_;
    my($query);
    my @transcript_cv_id = $self->get_cv_term_id('transcript');

    $display_locus = lc($display_locus);

    $query = "SELECT distinct l.accession ".
        "FROM dbxref x, dbxref l, feature_dbxref fd, feature_dbxref lfd, feature f ".
        "WHERE lower(x.accession) like \"$display_locus\" ".
        "AND x.dbxref_id = fd.dbxref_id ".
        "AND lfd.feature_id = fd.feature_id ".
        "AND lfd.dbxref_id = l.dbxref_id ".
        "AND l.version = \"locus\" ".
        "AND f.feature_id = fd.feature_id ".
        "AND f.type_id = $transcript_cv_id[0][0] ";

    my @results = $self->_get_results($query);
    my @return_results;
    for(my $i=0; $i<@results; $i++) {
        my $gene_results = &get_gene_id_to_identity($self, $results[$i][0]);

        foreach  my $j (0..11) {
                $return_results[$i][$j] = $gene_results->[0][$j];
        }
        $return_results[$i][12] = $results[$i][0];

    }

    ## last column (12) should be locus, so replace it



    return(@return_results);
}


###################### GENOME PROPERTIES subs ############################
sub get_evaluable_genome_properties {
    # if passed a genome properties prop_def_id, returns true if it is evaluable
    # if not passed anything, returns a list of evaluable prop_def_ids
    my $self = shift;
    my $accession = shift;
    my $query = qq{
        SELECT prop_def_id
        FROM common..prop_def
        WHERE eval_method IS NOT NULL
    };

    my @results;
    if ($accession) {
        $query .= " AND prop_def_id = ?";
        @results = $self->_get_results($query, $accession)
    }
    else {
        @results = $self->_get_results($query);
    }
    @results = map {$_->[0]} @results;
    return @results;
}

sub get_all_genome_properties{
    my($self) = @_;

    my $query = "SELECT DISTINCT p.prop_def_id, p.property, p.state, d.prop_type  ".
            "FROM common..property p, common..prop_def d ".
        "WHERE d.prop_type not like \"ROOT\" ".
        "AND d.prop_type not like \"NULL\" ".
        "AND d.prop_type not like \"QC-CHECK\" ".
        "AND d.prop_type not like \"VIRTUAL-TAXON\" ".
        "AND p.prop_def_id = d.prop_def_id ".
        "ORDER BY p.property";


    my @results = $self->_get_results($query);
    return(@results);
}

sub get_prop_type_to_prop_id{
    my ($self, $type) = @_;

    my $query = "SELECT DISTINCT d.prop_def_id, d.property, d.prop_acc, d.prop_type ".
            "FROM common..prop_def d ".
        "WHERE d.prop_type like \"$type\" ";

    if(!$type){
    $query = "SELECT DISTINCT p.prop_def_id, p.property, d.prop_acc, d.prop_type ".
        "FROM common..property p, common..prop_def d ".
        "WHERE d.prop_type not like \"ROOT\" ".
        "AND d.prop_type not like \"NULL\" ".
        "AND d.prop_type not like \"QC-CHECK\" ".
        "AND d.prop_type not like \"VIRTUAL-TAXON\" ".
        "AND p.prop_def_id = d.prop_def_id ".
        "ORDER BY p.property";

    }

    my $results = $self->_get_results_ref($query);
    return($results);
}

sub get_root_genome_prop{
    my($self) = @_;

    my $query = "SELECT DISTINCT d.prop_def_id, d.property, d.prop_acc ".
        "FROM common..prop_def d, common..prop_link l, common..prop_def d2 ".
        "WHERE d.prop_def_id = l.child_id ".
        "AND d2.prop_def_id = l.parent_id ".
        "AND d2.prop_type like \"ROOT\" ";

    my @results = $self->_get_results($query);
    return(@results);

}


sub get_search_pattern_to_genome_prop_extended{
    my($self, $search_pattern, $search_type, $terms_ref, $logic_ref)=@_;
    my($query);

    my @terms = @$terms_ref;
    my @logic = @$logic_ref;

    $search_pattern = $terms[0];

    my $add_on = " (lower(property) like '%$search_pattern%' ".
                 "OR lower(prop_acc) like '%$search_pattern%' )";

    if($search_type eq "all"){
    $add_on = " (lower(property) like '%$search_pattern%' ".
        "OR lower(prop_acc) like '%$search_pattern%' ".
        "OR description like '%$search_pattern%' ) ";
    }


    $query = "SELECT distinct prop_acc, property, prop_type ".
        "FROM common..prop_def ".
        "WHERE prop_type not like \"ROOT\" ".
        "AND prop_type not like \"NULL\" ".
        "AND prop_type not like \"QC-CHECK\" ".
        "AND prop_type not like \"VIRTUAL-TAXON\" ".
        "AND ($add_on  ";

    for(my $i = 0; $i < scalar @logic; $i++){
    $query .= $logic[$i];
    $search_pattern = $terms[$i+1];

    $add_on = " (lower(property) like '%$search_pattern%' ".
        "OR lower(prop_acc) like '%$search_pattern%' )";

    if($search_type eq "all"){
        $add_on = " (lower(property) like '%$search_pattern%' ".
        "OR lower(prop_acc) like '%$search_pattern%' ".
        "OR description like '%$search_pattern%' ) ";
    }

    $query .= " ($add_on) ";

    }

    $query .= ") ";

    $query .= " ORDER BY prop_acc ";

    my @results;

    @results = $self->_get_results($query);


    return(@results);
}


sub get_prop_id_to_property_definition_info{
     my ($self, $prop_id) = @_;

     my $query = "SELECT prop_def_id, property, description, prop_type, " .
            "role_id, prop_acc, ispublic ".
        "FROM common..prop_def ".
        "WHERE prop_def_id = ? ";

     my @results = $self->_get_results($query, $prop_id);

     return @results;
}

sub get_prop_list_to_property_definition_info{
     my ($self, $prop_list, $restrict) = @_;

     my $query = "SELECT prop_def_id, property, description, prop_type, " .
            "role_id, prop_acc, ispublic ".
        "FROM common..prop_def ";

     if($prop_list){
    $query .= "WHERE prop_def_id IN $prop_list ";
     }

     my @results = $self->_get_results($query);

     return @results;
}


sub get_state_type_to_prop_list{
    my ($self, $prop_list, $restrict) = @_;

    my $query = "SELECT distinct d.prop_def_id, d.property FROM common..prop_def d, common..property p WHERE d.prop_def_id = p.prop_def_id AND p.state = \"$restrict\" ";

    if($prop_list){
    $query .= "AND p.prop_def_id IN $prop_list ";
    }

     my @results = $self->_get_results($query);

     return @results;
}

sub get_pacc_to_property_definition_info{
     my ($self, $pacc) = @_;

     my $query = "SELECT prop_def_id, property, description, prop_type, " .
            "role_id, prop_acc, ispublic ".
        "FROM common..prop_def ".
        "WHERE prop_acc = \"$pacc\" ";

     my @results = $self->_get_results($query);
     return @results;

}

sub get_prop_id_to_go_info{
    my($self, $prop_id) = @_;
    my($query);

    $query = "SELECT pg.go_id, g.name, g.type ".
             "FROM common..prop_go_link pg, common..go_term g ".
             "WHERE pg.prop_def_id = ? ".
             "AND pg.go_id = g.go_id";

    my @results = $self->_get_results($query, $prop_id);
    return(@results);
}

sub get_prop_id_to_parents_info{
    my($self, $prop_id) = @_;
    my($query);

    $query = "SELECT d.property, d.prop_acc, d.prop_def_id, d.ispublic ".
        "FROM common..prop_def d, common..prop_link l ".
        "WHERE l.child_id = $prop_id ".
        "AND l.parent_id = d.prop_def_id ".
        "AND l.link_type = \"DAG\" ";

    my @results = $self->_get_results($query);
#    my $num_r = scalar @results;
#    print "$query <BR> $num_r <BR>";
    return(@results);
}



sub get_prop_id_to_child_info{
    my($self, $prop_id) = @_;
    my($query);

    $query = "SELECT d.property, d.prop_acc, d.prop_def_id, d.ispublic ".
        "FROM common..prop_def d, common..prop_link l ".
        "WHERE l.parent_id = ? ".
        "AND l.child_id = d.prop_def_id ".
        "AND l.link_type = \"DAG\" ";

    my @results = $self->_get_results($query, $prop_id);
    return(@results);
}


sub get_prop_id_list_to_state_info{
    my($self, $prop_id_list, $org_list) = @_;
    my($query);

    $query = "SELECT p.prop_def_id, p.property, p.state, p.value, p.db, p.assignby ";

    $query .= "FROM common..property p, common..prop_def d ";

    $query .= "WHERE p.prop_def_id = d.prop_def_id ".
    "AND d.prop_type not like \"ROOT\" ".
    "AND d.prop_type not like \"NULL\" ".
    "AND d.prop_type not like \"QC-CHECK\" ".
    "AND d.prop_type not like \"VIRTUAL-TAXON\" ";

    if($prop_id_list){
    $query .= "AND p.prop_def_id IN $prop_id_list ";
    }
    if($org_list){
    $query .= "AND p.db IN $org_list ";
    }

    $query .= "ORDER BY p.db ";


    my @results = $self->_get_results($query);
    return(@results);
}

sub get_prop_id_to_state_info{
    my($self, $prop_id, $ori_db) = @_;
    my($query);

    $query = "SELECT p.prop_def_id, p.property, p.state, p.value, p.db, p.assignby ";

    $query .= "FROM common..property p, common..prop_def d ";

    $query .= "WHERE p.prop_def_id = d.prop_def_id ".
    "AND d.prop_type not like \"ROOT\" ".
    "AND d.prop_type not like \"NULL\" ".
    "AND d.prop_type not like \"QC-CHECK\" ".
    "AND d.prop_type not like \"VIRTUAL-TAXON\" ";

    if($prop_id){
    $query .= "AND p.prop_def_id = $prop_id ";
    }
    if($ori_db){
    $query .= "AND p.db = $ori_db ";
    }


    my @results = $self->_get_results($query);
    return(@results);
}

sub get_prop_id_to_prop_step_ev{
    ##FIX THIS FOR GETTING DL SEQS
	 my($self, $prop_id, $ori_list, $locus_flag, $dl_seqs) = @_;
	 my($query);

	 my @com_name_cv_id = $self->get_cv_term_id('gene_product_name');
	 my @transcript_cv_id = $self->get_cv_term_id('transcript');
	 my @assembly_cv_id = $self->get_cv_term_id('assembly');

    $query = "SELECT f.db, s.prop_step_id, e.query, e.method, f.feat_name, s.step_name, s.step_num, f.assignby ";

    if($locus_flag){
		  # CONNECT TO NT LOCUS LATER
		  $query .= ", x2.accession, fp.value, NULL, NULL, NULL, NULL ";
    }


    $query .= "FROM common..prop_step s, common..step_ev_link e, common..step_feat_link f ";
    if($locus_flag){
		  $query .= ", feature f1, dbxref x, feature_dbxref fd, featureprop fp, dbxref x2, featureloc fl, feature f2, organism_dbxref od, dbxref x3, db ";
    }

    $query .= "WHERE s.prop_def_id = $prop_id ".
		  "AND s.prop_step_id = e.prop_step_id ".
		  "AND e.step_ev_id = f.step_ev_id ".
		  "AND f.feat_name NOT IN ('POINT%MUTATION', 'TRUNCATION', 'FRAME%SHIFT', 'MISSING', 'SEQ%GAP')  ";

    if($locus_flag){

		  $query .= "AND f1.dbxref_id = x.dbxref_id ".
				"AND x.accession = f.feat_name ".
				"AND f1.type_id = $transcript_cv_id[0][0] ".
				"AND f1.feature_id = fd.feature_id ".
				"AND fd.dbxref_id = x2.dbxref_id ".
				"AND x2.version = \"locus\" ".
				"AND fp.feature_id =* f1.feature_id ".
				"AND fp.type_id = $com_name_cv_id[0][0] ".
				"AND fl.feature_id = f1.feature_id ".
				"AND fl.srcfeature_id = f2.feature_id ".
				"AND f2.organism_id = od.organism_id ".
				"AND f2.type_id = $assembly_cv_id[0][0] ".
				"AND od.dbxref_id = x3.dbxref_id ".
				"AND x3.version = \"legacy_annotation_database\" ".
				"AND x3.db_id = db.db_id ". 
				"AND LOWER(SUBSTRING(db.name, 6, 15)) IN $ori_list ";
    }

    if($ori_list){ 
		  $query .= "AND LOWER(f.db) IN $ori_list ";  
    }

    if($locus_flag){
		  $query .= "ORDER BY f.feat_name ";
    }

#     print "get_prop_id_to_prop_step_ev: <BR> $query <BR>";
    my @results = $self->_get_results($query);
#     print "got results <BR>";
    return(@results);
}


sub get_feat_name_to_prop_id{
    my($self, $ori_db, $feat_name, $second_feat_name ) = @_;

    my $query = "SELECT distinct d.prop_def_id, d.property, d.prop_acc ".
            "FROM common..step_feat_link f, common..step_ev_link e, common..prop_step s, common..prop_def d ".
        "WHERE f.db = '$ori_db' ".
        "AND f.step_ev_id = e.step_ev_id ".
        "AND e.prop_step_id = s.prop_step_id ".
        "AND s.prop_def_id = d.prop_def_id ";

    if($second_feat_name){
    $query .= "AND f.feat_name IN ('$feat_name', '$second_feat_name') ";
    }else{
    $query .= "AND f.feat_name = '$feat_name' ";
    }

    my @results = $self->_get_results($query);

    return(@results);
}

sub get_feat_name_to_cluster_num{
    my($self, $prop_id, $ori_db, $feat_name ) = @_;

    my $query = "SELECT cluster_num, end5_feat, end3_feat ".
        "FROM common..cluster_link c ".
        "WHERE (c.end5_feat = '$feat_name' OR c.end3_feat = '$feat_name') ".
        "AND c.db = '$ori_db' ".
        "AND c.prop_def_id = $prop_id ";

#    print "get_feat_name_to_cluster_num: <BR> $query <BR>";
    my @results = $self->_get_results($query);

    return(@results);
}

sub get_prop_id_to_prop_step_ev_meta{
    my($self, $prop_id, $ori_list) = @_;
    my($query);

    $query = "SELECT p.db, s.prop_step_id, e.query, e.method, p.state ".
        "FROM common..prop_step s, common..step_ev_link e, common..prop_def d, common..property p ".
        "WHERE s.prop_def_id = $prop_id ".
        "AND s.prop_step_id = e.prop_step_id ".
        "AND e.method = \"GENPROP\" ".
        "AND e.query = d.prop_acc ".
        "AND d.prop_def_id = p.prop_def_id ";

    if($ori_list){
    $query .= "AND p.db IN $ori_list ";
    }



    my @results = $self->_get_results($query);


    return(@results);
}

sub get_prop_id_to_prop_step_info{
    my($self, $prop_id) = @_;
    my($query);

    $query = "SELECT prop_def_id, prop_step_id, step_num, step_name, in_rule, branch ".
        "FROM common..prop_step ".
        "WHERE prop_def_id = ? ".
        "ORDER BY step_num ";

#    print "get_prop_id_to_prop_step_info: <Br>";
#    print "$query <BR>";
    my @results = $self->_get_results($query, $prop_id);
    return(@results);
}

sub get_step_ev_id_to_info{
    my($self, $prop_step_id) = @_;
    my($query);

    $query = "SELECT prop_step_id, step_ev_id, query, method ".
        "FROM common..step_ev_link ".
        "WHERE prop_step_id = ? ";

    my @results = $self->_get_results($query, $prop_step_id);
    return(@results);
}

sub get_prop_id_ori_db_to_num_clusters{
    my($self, $prop_id, $ori_db) = @_;

    my $query = "select distinct cluster_num "
        ." from common..cluster_link "
        ." where prop_def_id = $prop_id "
        ." and db =\"$ori_db\" order by cluster_num";

    my @results = $self->_get_results($query);
    return(@results);

}

sub get_prop_id_ori_db_to_cluster{
    my($self, $prop_id, $ori_db) = @_;

    my $query = "SELECT cluster_num, end5_feat, end3_feat ".
            "FROM cluster_link ".
        "WHERE db = $ori_db ".
        "AND prop_def_id = $prop_id ";

    my @results = $self->_get_results($query);
    return(@results);


}

sub get_prop_id_ori_db_to_cluster_coords{
    my($self, $prop_id, $ori_db, $cluster_num) = @_;

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my $oridb_lookup = $self->get_ori_db_org_id_lookup();
    my $fposlookup = $self->get_feature_id_to_gene_pos_lookup;

    my $query = "SELECT f.feature_id "
        . "FROM common..cluster_link cl, feature f, dbxref x "
        . "WHERE cl.cluster_num = $cluster_num "
        . "AND cl.prop_def_id = $prop_id "
        . "AND LOWER(cl.db) = \"$ori_db\" "
        . "AND ((cl.end5_feat = x.accession) or (cl.end3_feat = x.accession)) "
        . "AND x.dbxref_id = f.dbxref_id "
        . "AND f.type_id = $transcript_cv_id[0][0] "
        . "AND f.organism_id = $oridb_lookup->{$ori_db} ";


    my @results = $self->_get_results($query);
    my $asms;
    for (my $i=0; $i<scalar @results; $i++) {

    $asms->{$fposlookup->{$results[$i][0]}->[6]}->{min} = $fposlookup->{$results[$i][0]}->[1] if (!exists($asms->{$fposlookup->{$results[$i][0]}->[6]}->{min}) || $asms->{$fposlookup->{$results[$i][0]}->[6]}->{min} > $fposlookup->{$results[$i][0]}->[1]);
    $asms->{$fposlookup->{$results[$i][0]}->[6]}->{max} = $fposlookup->{$results[$i][0]}->[2] if (!exists($asms->{$fposlookup->{$results[$i][0]}->[6]}->{max}) || $asms->{$fposlookup->{$results[$i][0]}->[6]}->{max} < $fposlookup->{$results[$i][0]}->[2]);
    }

    my @tmp = keys %$asms;
    my @final_results;
    for (my $i=0; $i<scalar @tmp; $i++){
    $final_results[$i][0] = $tmp[$i];
    $final_results[$i][2] = $asms->{$tmp[$i]}->{min};
    $final_results[$i][1] = $asms->{$tmp[$i]}->{max};

    }

    return(@final_results);

 }

sub get_prop_id_to_prop_acc{

     my ($self) = @_;
     $self->_trace if $self->{_debug};

     my $query = "SELECT prop_def_id, prop_acc, property ".
            "FROM common..prop_def ";


     my @results = $self->_get_results($query);
     return(@results);
}

sub get_prop_id_to_common_components{

     my ($self, $prop_id, $link_types) = @_;
     $self->_trace if $self->{_debug};

     my $query = "SELECT d.prop_def_id, d.prop_acc, d.property, l.link_string ".
            "FROM common..prop_def d, common..prop_link l ".
                 "WHERE l.parent_id = $prop_id ".
        "AND l.child_id = d.prop_def_id ".
        "AND l.link_type IN ($link_types) ";

     my @results = $self->_get_results($query);
     return(@results);
}

sub get_prop_id_to_dir_components{

     my ($self, $prop_id, $link_types) = @_;
     $self->_trace if $self->{_debug};

     my $second_link = "parent_id";
     if($link_types eq "parent_id"){
    $second_link = "child_id";
     }

     my $query = "SELECT d.prop_def_id, d.prop_acc, d.property, l.link_string ".
            "FROM common..prop_def d, common..prop_link l ".
                 "WHERE l.$link_types = $prop_id ".
        "AND l.$second_link = d.prop_def_id ".
        "AND l.link_type IN ('BRANCH_LINK', 'BRANCH_POINT') ";


     my @results = $self->_get_results($query);
     return(@results);
}


sub get_prop_step_org_list_to_gene_info{
    my($self, $prop_step_id, $ori_list, $prop_state)=@_;
    my($query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @molecule_name_cv_id = $self->get_cv_term_id('molecule_name');

    $query = "SELECT lower(d.original_db), d.orf_type, f2.uniquename, x.accession, x2.accession, fl.fmin, fl.fmax, fl.strand, fp.value, x2.accession ".
    "FROM feature f, feature f2, dbxref x, dbxref x2, featureprop fp, featurelink fl, dbxref dx, common..step_ev_link e, common..step_feat_link sf ";

   if($prop_state){
    $query .= ", common..prop_step s, common..property p ";
    }

    $query .= "WHERE f.type_id = $transcript_cv_id[0][0] ".
        "AND f.dbxref_id = x.dbxref_id ".
        "AND x.accession = sf.feat_name ".
        "AND e.prop_step_id = $prop_step_id ".
        "AND e.step_ev_id = sf.step_ev_id ".
        "AND sf.db = f2.uniquename ".
        "AND f2.type_id = $assembly_cv_id[0][0] ".
        "AND f2.feature_id = fl.srcfeature_id ".
        "AND fl.feature_id = f.feature_id ".
        "AND f.feature_id = dx.feature_id ".
        "AND dx.dbxref_id = x2.dbxref_id ".
        "AND x2.version = \"locus\" ".
        "AND f2.feature_id = fp.feature_id ".
        "AND fp.type_id = $molecule_name_cv_id[0][0] ";

    if($ori_list){
    $query .= "AND lower(d.original_db) IN ($ori_list)";
    }

    if($prop_state){
    $query .= "AND s.prop_step_id = e.prop_step_id ".
            "AND p.prop_def_id = s.prop_def_id ".
            "AND p.db = f2.uniquename ".
        "AND p.state IN $prop_state ";
    }

    $query .= "ORDER BY x2.accession ";
    my @results = $self->_get_results($query);


    for (my $i = 0; $i < scalar @results; $i++){
    my $min = $results[$i][5];
    my $max = $results[$i][6];
    my $strand = $results[$i][7];

    if($strand == 1){
        $results[$i][7] = "";
    }else{
        $results[$i][5] = $max;
        $results[$i][6] = $min;
        $results[$i][7] = "";
    }
    }

    return @results;
}

sub get_prop_acc_locus_to_prop_step{
    my($self, $prop_acc, $locus)=@_;
    my @transcript_cv_id = $self->get_cv_term_id('transcript');

    my $query = "SELECT lower(f.db), f.feat_name, e.prop_step_id, s.prop_def_id ".
            "FROM common..step_feat_link fl, common..step_ev_link e, common..prop_step s, common..prop_def d, feature f, dbxref x, dbxref x2, feature_dbxref dx ".
        "WHERE x.accession = \"$locus\" ".
        "AND x.version = \"locus\" ".
        "AND dx.dbxref_id = x.dbxref_id ".
        "AND f.feature_id = dx.feature_id ".
        "AND f.type_id = $transcript_cv_id[0][0] ".
        "AND f.uniquename = fl.db ".
        "AND f.dbxref_id = x2.dbxref_id ".
        "AND x2.accession = fl.feat_name ".
        "AND fl.step_ev_id = e.step_ev_id ".
        "AND e.prop_step_id = s.prop_step_id ".
        "AND s.prop_def_id = d.prop_def_id ".
        "AND d.prop_acc = \"$prop_acc\" ".
        "ORDER BY f1.feat_name ";

    my @results = $self->_get_results($query);
    return @results;
}

sub get_prop_id_ori_db_to_non_cluster_genes{
    my ($self, $prop_id, $ori_db) = @_;
    my $query = "";
    my @assembly_cv_id = $self->get_cv_term_id('assembly');


    $query = "SELECT x.accession, f1.uniquename, fl.fmin, fl.fmax, fl.strand ".
        "FROM common..step_feat_link f, common..step_ev_link e, common..prop_step s, dbxref x, feature f1, feature f2, featureloc fl, organism_dbxref od, dbxref x2, db ".
        "WHERE f.step_ev_id = e.step_ev_id ".
        "AND e.prop_step_id = s.prop_step_id  ".
        "AND lower(f.db) = \"$ori_db\" ".
        "AND s.prop_def_id = $prop_id ".
        "AND NOT EXISTS (SELECT c.* FROM common..cluster_link c WHERE c.db = f.db AND c.prop_def_id = $prop_id AND (c.end3_feat = f.feat_name OR c.end5_feat = f.feat_name)) ".
        "AND f.feat_name = x.accession ".
        "AND x.dbxref_id = f2.dbxref_id ".
        "AND f2.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = f1.feature_id ".
        "AND f1.type_id = $assembly_cv_id[0][0] ".
        "AND f1.organism_id = od.organism_id ".
        "AND od.dbxref_id = x2.dbxref_id ".
        "AND x2.version = \"legacy_annotation_database\" ".
        "AND x2.db_id = db.db_id ".
        "AND LOWER(SUBSTRING(db.name, 6, 15)) = \"$ori_db\" ";

#    print "$query <BR><BR>";

    my @results = $self->_get_results($query);

    for (my $i = 0; $i < scalar @results; $i++){
    my $min = $results[$i][2];
    my $max = $results[$i][3];
    my $strand = $results[$i][4];

    if($strand == 1){
        $results[$i][4] = "";
    }else{
        $results[$i][2] = $max;
        $results[$i][3] = $min;
        $results[$i][4] = "";
    }


    }


    return @results;
}

sub get_prop_id_to_references{
    my ($self, $prop_id, $ref_type) = @_;

    my $query = "";

    $query = "SELECT * "
        ."FROM common..prop_ref "
            ."WHERE  prop_def_id = $prop_id "
        ."AND ref_type = \"$ref_type\" ";

    my @results = $self->_get_results($query);
    return @results;
}


sub get_seq_id_to_both_annotations_in_region{
    my ($self, $seq_id, $feat_type, $opp_feat_type, $begin_coord, $end_coord) = @_;
    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my $fnamelookup = $self->get_feature_id_to_gene_name_lookup;
    my $query = "SELECT f.feature_id, x.accession, fl.fmin, fl.fmax, fl.strand ".
            "FROM feature f, featureloc fl, feature a, dbxref x ".
        "WHERE a.uniquename = '$seq_id' ".
        "AND a.type_id = $assembly_cv_id[0][0] ".
        "AND a.feature_id = fl.srcfeature_id ".
        "AND f.dbxref_id = x.dbxref_id ".
        "AND fl.feature_id = f.feature_id ".
        "AND f.type_id = $transcript_cv_id[0][0] ".
        "AND fl.fmin > $begin_coord ".
        "AND fl.fmax < $end_coord ";
    my @return_result;
    my @results = $self->_get_results($query);
    for (my $i=0; $i<@results; $i++) {
    $return_result[$i][0] = "primary";
    $return_result[$i][1] = $fnamelookup->{$results[$i][0]}->[1];
    $return_result[$i][2] = $fnamelookup->{$results[$i][0]}->[1];
    $return_result[$i][3] = $results[$i][1];
    $return_result[$i][4] = $fnamelookup->{$results[$i][0]}->[2];
    $return_result[$i][5] = $results[$i][2]+1 if ($results[$i][4] == 1);
    $return_result[$i][5] = $results[$i][3] if ($results[$i][4] == -1);
    $return_result[$i][6] = $results[$i][3] if ($results[$i][4] == 1);
    $return_result[$i][6] = $results[$i][2]+1 if ($results[$i][4] == -1);
    $return_result[$i][7] = "ORF";
    $return_result[$i][8] = "";
    $return_result[$i][9] = "";#$fnamelookup->{$results[$i][0]}->[1]";
    $return_result[$i][10] = "";#$results[$i][1]";
    $return_result[$i][11] = "";#$fnamelookup->{$results[$i][0]}->[1]";


    }

    return (@return_result);

}


sub get_gene_id_to_genome_prop{

    my ($self, $gene_id, $ori_db) = @_;
    $self->_trace if $self->{_debug};
    my @transcript_cv_id = $self->get_cv_term_id('transcript');

    my $query = "SELECT d.property, d.prop_acc, d.prop_def_id, p.state, s.step_name, s.step_num, s.prop_step_id, e.query, e.method ".
            "FROM feature f2, dbxref feat, dbxref locus, feature_dbxref fd, common..step_feat_link f, common..step_ev_link e, common..prop_step s, common..prop_def d, common..property p ".
        "WHERE locus.accession = '$gene_id' ".
        "AND locus.version = 'locus' ".
        "AND f2.type_id = $transcript_cv_id[0][0] ".
        "AND locus.dbxref_id = fd.dbxref_id ".
        "AND fd.feature_id = f2.feature_id ".
        "AND f2.dbxref_id = feat.dbxref_id ".
        "AND feat.accession = f.feat_name ".
        "AND LOWER(f.db) = '$ori_db' ".
        "AND f.step_ev_id = e.step_ev_id ".
        "AND e.prop_step_id = s.prop_step_id ".
        "AND s.prop_def_id = d.prop_def_id ".
        "AND p.prop_def_id = d.prop_def_id ".
        "AND LOWER(p.db) = '$ori_db' ";
#		"AND p.state IN ('YES', 'some evidence') ";

     my $results = $self->_get_results_ref($query);

     return $results;
}



###################### END GENOME PROPERTIES subs ############################

###################### REACTOME subs ############################

sub get_gene_id_to_reactome_id{
    my ($self, $gene_id) = @_;

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my ($kegg_locus, $enz_id, $react_id, $org_name) = "";

    my $query = "select x2.accession, o.common_name ".
            "from feature_dbxref fd1, dbxref x1, feature_dbxref fd2, dbxref x2, feature f, organism o  ".
        "where x1.accession = \"$gene_id\" ".
        "and x1.version = \"locus\" ".
        "and x1.dbxref_id = fd1.dbxref_id ".
        "and fd1.feature_id = fd2.feature_id ".
        "and fd2.dbxref_id = x2.dbxref_id ".
        "and x2.version = \"nt_locus\" ".
        "and f.type_id = $transcript_cv_id[0][0] ".
        "and f.feature_id = fd1.feature_id ".
        "AND f.organism_id = o.organism_id ";

    my @results = $self->_get_results($query);


    if(scalar @results){
    $kegg_locus = $results[0][0];
    $org_name = $results[0][1];
    my ($genus, $species, $junk) = split(/ /, $org_name);
    $org_name = "$genus $species";
    }else{
    return "";
    }

    $query = "select DB_ID from test_gk..Taxon_2_name where name like \"%$org_name%\"";
    my @ret_txon = $self->_get_results($query);
    my $taxon_id = $ret_txon[0][0];

    if(!$taxon_id){
    return "";
    }

    $query = "select d.DB_ID from test_gk..DatabaseObject d, test_gk..ReferencePeptideSequence r where  d._displayName like \"$kegg_locus%\" and d.DB_ID = r.DB_ID";
    my @ret1 = $self->_get_results($query);
    $enz_id = $ret1[0][0];

    if(!$enz_id){
    return "";
    }

    $query = "select d.DB_ID from test_gk..Event e, test_gk..DatabaseObject d, test_gk..Event_2_catalystActivity ec where e.taxon= $taxon_id and d._class = 'ConcreteReaction' and e.DB_ID = d.DB_ID and ec.catalystActivity = $enz_id and e.DB_ID = ec.DB_ID";
    my @ret2 = $self->_get_results($query);
    my $rxn_id = $ret2[0][0];

    if (!$rxn_id){
    return "$enz_id";
    }

    $query = "select en.DB_ID from test_gk..Event e, test_gk..Event_2_name en, test_gk..Pathway_2_hasComponent p where e.DB_ID= $rxn_id and e.DB_ID = p.hasComponent and p.DB_ID = en.DB_ID";
    my @ret5 = $self->_get_results($query);
    my $path_id = $ret5[0][0];

    if(!$path_id){
    return $rxn_id;
    }else{
    return $path_id;
    }
}

###################### END REACTOME subs ############################

######### SNP subs ##########
sub get_gene_id_to_SNPs{
    my ($self,$analysis,$locus) = @_;

    my $locus_hash = $self->get_locus_to_feature_id_lookup("transcript");
    my $fposlookup = $self->get_feature_id_to_gene_pos_lookup;
    my @snp_cv_id = $self->get_cv_term_id('SNP');
    my @asm_cv_id = $self->get_cv_term_id('assembly');


    my $snp_analyses = &get_snp_analysis_ids($self, $analysis);

    my $fid = $locus_hash->{$locus}->[0];

    my $fmin = $fposlookup->{$fid}->[1];
    my $fmax = $fposlookup->{$fid}->[2];



    my $query = "SELECT f.feature_id, f.uniquename, fl.fmin, fl.fmax, f2.uniquename, fl.residue_info, fl.strand, a.name ".
            "FROM feature f, feature f2, featureloc fl, featureloc fl2, analysisfeature af, analysis a ".
        "WHERE f.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = f2.feature_id ".
        "AND f2.type_id = $asm_cv_id[0][0] ".
        "AND f.type_id = $snp_cv_id[0][0] ".
#		"AND f.feature_id >= 4914047 ".
        "AND fl.fmin >= $fmin ".
        "AND fl.fmax <= $fmax ".
        "AND af.feature_id = f.feature_id ".
#		"AND af.analysis_id IN (3035, 3036, 3037) ".
        "AND af.analysis_id IN ($snp_analyses) ".
        "AND af.analysis_id = a.analysis_id ".
        "AND fl2.srcfeature_id = f2.feature_id ".
        "AND fl2.feature_id = $fid ";

    my @results = $self->_get_results($query);
    return(sort {$a->[3] <=> $b->[3]} @results);
}

sub get_SNP_id_to_all_SNP_hits{
    my ($self,$snp_id) = @_;
    my @asm_cv_id = $self->get_cv_term_id('assembly');
    my @mol_name_cv_id = $self->get_cv_term_id('molecule_name');
    my $org_lookup = $self->get_ori_db_org_id_lookup();

    my $query = "SELECT f.uniquename, f.organism_id, fp.value, fl.fmin, fl.fmax, a.name, fl.residue_info, fl.strand, a.name ".
            "FROM feature f, featureloc fl, featureprop fp, analysisfeature af, analysis a ".
            "WHERE fl.feature_id = $snp_id ".
        "AND f.feature_id = fl.srcfeature_id ".
        "AND f.type_id = $asm_cv_id[0][0] ".
        "AND f.feature_id = fp.feature_id ".
        "AND fp.type_id = $mol_name_cv_id[0][0] ".
        "AND af.feature_id = $snp_id ".
        "AND af.analysis_id = a.analysis_id ";

    my @results = $self->_get_results($query);

    foreach (my $i = 0; $i < scalar @results; $i++){
    $results[$i][1] = $org_lookup->{$results[$i][1]};
    }


    return(sort {$a->[0] <=> $b->[0]} @results);
}

sub get_org_id_to_SNPs{
    my ($self,$analysis,$ori_db, $seq_id, $min, $max) = @_;

    my $org_lookup = $self->get_ori_db_org_id_lookup();
    my @snp_cv_id = $self->get_cv_term_id('SNP');
    my @asm_cv_id = $self->get_cv_term_id('assembly');

    my $snp_analyses = &get_snp_analysis_ids($self, $analysis);


    my $query = "SELECT f.feature_id, f.uniquename, fl.fmin, fl.fmax, f2.uniquename, fl.residue_info, fl.strand, a.name ".
            "FROM feature f, feature f2, featureloc fl, analysisfeature af, analysis a ".
        "WHERE f.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = f2.feature_id ".
        "AND f2.type_id = $asm_cv_id[0][0] ".
        "AND f.type_id = $snp_cv_id[0][0] ".
#		"AND f.feature_id >= 4914047 ".
        "AND af.feature_id = f.feature_id ".
        "AND af.analysis_id IN ($snp_analyses) ".
        "AND af.analysis_id = a.analysis_id ".
        "AND f2.organism_id = $org_lookup->{$ori_db} ";

    if($min && $max){
    $query .= "AND fl.fmin >= $min AND fl.fmax <= $max AND f2.uniquename = '$seq_id' ";
    }elsif($seq_id){
    $query .= " AND f2.uniquename = '$seq_id' ";
    }

#    print $query, "\n";
 #   exit;
    my @results = $self->_get_results($query);


    return(sort {$a->[3] <=> $b->[3]} @results);
}

sub get_snp_analysis_ids{
    my ($self, $analysis) = @_;

    my $nucmer_analysis_id = $self->get_analysis_id_list('nucmer_snps');
    my $jacques_analysis_id = $self->get_analysis_id_list('jacques_snps');

    my $snp_analyses = "(3033)";

    # REMOVE LATER AND ADD CORRECT ARRAY OF NUCMER ANALYSIS IDs
#    @nucmer_analysis_id = (3035, 3036, 3037) if(!$analysis || $analysis eq "nucmer");
#    @nucmer_analysis_id = (3033) if(!$analysis || $analysis eq "nucmer");

#    $snp_analyses .= join(",", @nucmer_analysis_id) if ($analysis eq "nucmer" || !$analysis);
#    $snp_analyses .= "," if (!$analysis);
#    $snp_analyses .= $jacques_analysis_id[0][0] if ($analysis eq "jacques" || !$analysis);

#    chop $snp_analyses if ($snp_analyses =~ /\,$/);

    return $snp_analyses;
}

sub get_genome_to_all_vs_all_hits{
    my($self,$genome1_id,$scatter_chooser,$per_sim,$p_value,$per_id)= @_;

    my @per_sim_cv_id = $self->get_cv_term_id('percent_similarity');
    my ($wublast_analysis_id) = $self->get_analysis_id_list('wu-blastp');
    my @protein_id = $self->get_cv_term_id('polypeptide');
    my @match_id = $self->get_cv_term_id('match_part');

    my $min_val = "";
    if($scatter_chooser != 1){
    my $query = "SELECT min(p_value) ".
            "FROM cm_blast ".
        "WHERE qorganism_id = $genome1_id ";
    my @tmp_results = $self->_get_results($query);
    $min_val = $tmp_results[0][0];
    }



    my $query = "SELECT horganism_id, count(qfeature_id) ".
            "FROM cm_blast ".
        "WHERE qorganism_id = $genome1_id ".
        "AND per_id >= $per_id ".
        "AND per_sim >= $per_sim ".
        "AND p_value <= $p_value ";

    $query .= "AND p_value = $min_val " if ($scatter_chooser != 1);

    $query .= "GROUP BY horganism_id ";
    my @results;
    @results = $self->_get_results($query);

    return @results;

}



sub get_ref_and_match_genomes_to_all_vs_all_hits{
    my($self,$genome1_id,$genome2_id,$molecule1,$molecule2,$genome1_type,$genome2_type,$scatter_chooser,$feat_type,$maxXIn,$maxYIn,$minXIn,$minYIn,$per_sim,$per_id,$p_value,$att_type)= @_;


    my @mol1_info = $self->get_mol_info_from_seq_id($molecule1);
    my @mol2_info = $self->get_mol_info_from_seq_id($molecule2);

    my $fnamelookup = $self->get_pfeature_id_to_gene_name_lookup;
    my $fposlookup = $self->get_feature_id_to_gene_pos_lookup;

    my $query = "SELECT qfeature_id, hfeature_id, per_id, per_sim, p_value ".
            "FROM cm_blast ".
        "WHERE qorganism_id = $genome1_id ".
        "AND horganism_id = $genome2_id ".
        "AND per_id >= $per_id ".
        "AND per_sim >= $per_sim ".
        "AND p_value <= $p_value ";



    my @results = $self->_get_results($query);

    my $min_val = "";

    if($scatter_chooser == 2){
    $query = "SELECT min(p_value) ".
            "FROM cm_blast ".
        "WHERE qorganism_id = $genome1_id ";
    my @tmp_results = $self->_get_results($query);
    $min_val = $tmp_results[0][0];
    }



    my $j=0; my @fresults;
    for(my $i = 0; $i < scalar @results; $i++){
    my $qfeat_id = $fnamelookup->{$results[$i][0]}->[0];
    my $hfeat_id = $fnamelookup->{$results[$i][1]}->[0];


    next if($molecule1 && ($fposlookup->{$qfeat_id}->[6] ne $molecule1));
    next if($molecule2 && ($fposlookup->{$hfeat_id}->[6] ne $molecule2));
    next if(($scatter_chooser == 2) && ($min_val != $results[$i][4]));

    my $qend5 = ($fposlookup->{$qfeat_id}->[3] == 1) ? $fposlookup->{$qfeat_id}->[1] : $fposlookup->{$qfeat_id}->[2];
    my $qend3 = ($fposlookup->{$qfeat_id}->[3] == 1) ? $fposlookup->{$qfeat_id}->[2] : $fposlookup->{$qfeat_id}->[1];

    my $hend5 = ($fposlookup->{$hfeat_id}->[3] == 1) ? $fposlookup->{$hfeat_id}->[1] : $fposlookup->{$hfeat_id}->[2];
    my $hend3 = ($fposlookup->{$hfeat_id}->[3] == 1) ? $fposlookup->{$hfeat_id}->[2] : $fposlookup->{$hfeat_id}->[1];

    if($maxXIn || $maxYIn || $minXIn || $minYIn ){
        if($att_type){
        next if ($fnamelookup->{$results[$i][0]}->[6] < $minXIn || $fnamelookup->{$results[$i][0]}->[6] > $maxXIn );
        next if ($fnamelookup->{$results[$i][1]}->[6] < $minYIn || $fnamelookup->{$results[$i][1]}->[6] > $maxYIn );
        }else{
        next if ($qend5 < $minXIn || $qend5 > $maxXIn);
        next if ($hend5 < $minYIn || $hend5 > $maxYIn);
        }
    }

    $fresults[$j][0] = $fnamelookup->{$results[$i][0]}->[2];
    $fresults[$j][1] = $fnamelookup->{$results[$i][1]}->[2];
    $fresults[$j][2] = $results[$i][4];
    $fresults[$j][3] = $results[$i][3];
    $fresults[$j][4] = $results[$i][2];
    $fresults[$j][5] = $fnamelookup->{$results[$i][0]}->[2];
    $fresults[$j][6] = $fnamelookup->{$results[$i][0]}->[3];
    $fresults[$j][7] = $qend5;
    $fresults[$j][8] = $qend3;
    $fresults[$j][9] = $fnamelookup->{$results[$i][1]}->[2];
    $fresults[$j][10] = $fnamelookup->{$results[$i][1]}->[3];
    $fresults[$j][11] = $hend5;
    $fresults[$j][12] = $hend3;
    $fresults[$j][13] = "";
    $fresults[$j][14] = ($att_type) ? $fnamelookup->{$results[$i][0]}->[6] : "";
    $fresults[$j][15] = ($att_type) ? $fnamelookup->{$results[$i][1]}->[6] : "";
    $j++;

    }


    return @fresults;

}

sub get_go_term_to_gene_ids{
    my($self, $go_term, $ori_list, $feat_type)=@_;

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @process_cv_id = $self->get_cv_id('process');
    my @function_cv_id = $self->get_cv_id('function');
    my @component_cv_id = $self->get_cv_id('component');

    my $go_cvs = "";
    my @go_cv_id = $self->get_cv_id('GO');
    if ($process_cv_id[0][0] ne ""){
        $go_cvs = "$process_cv_id[0][0], $function_cv_id[0][0], $component_cv_id[0][0]";
    }else{
        $go_cvs = "$go_cv_id[0][0]";
    }

    my $query = "SELECT f.feature_id, g.accession ".
            "FROM feature f, dbxref g, cvterm c, feature_cvterm fc ".
            "WHERE f.feature_id = fc.feature_id ".
            "AND f.type_id = $transcript_cv_id[0][0] ".
            "AND fc.cvterm_id = c.cvterm_id ".
            "AND c.cv_id in ($go_cvs) ".
            "AND c.dbxref_id = g.dbxref_id ".
            "AND g.accession = \"$go_term\" ";

    if(($ori_list) && ($ori_list ne "'all'")){
        $ori_list = &convert_ori_list_to_org_id_list($self, $ori_list);
        $query .= "AND f.organism_id IN ($ori_list)";
    }

    my @results;

    @results = $self->_get_results($query);

    my @return_result;

    my $ec_hashref = &make_ec_hash($self);

    my $fnamelookup = $self->get_feature_id_to_gene_name_lookup;
    my $fposlookup = $self->get_feature_id_to_gene_pos_lookup;
    my $org_lookup = $self->get_org_id_to_org_name_lookup();

    my ($org_name, $prev_org_id);

    for (my $i=0; $i<@results; $i++) {


    $return_result[$i][0] = $fnamelookup->{$results[$i][0]}->[1];
    $return_result[$i][1] = $fnamelookup->{$results[$i][0]}->[1];

    # EC
    $return_result[$i][2] = $ec_hashref->{$fnamelookup->{$results[$i][0]}->[1]};
    $return_result[$i][3] = $fnamelookup->{$results[$i][0]}->[2];
    $return_result[$i][4] = $fnamelookup->{$results[$i][0]}->[3];
#	$return_result[$i][5] = $org_lookup->{$fnamelookup->{$results[$i][0]}->[4]};

    if($fposlookup->{$results[$i][0]}->[3] == 1){
        $return_result[$i][5] = ($fposlookup->{$results[$i][0]}->[1] + 1);
        $return_result[$i][6] = $fposlookup->{$results[$i][0]}->[2];
    }else{
        $return_result[$i][6] = $fposlookup->{$results[$i][0]}->[2];
        $return_result[$i][5] = ($fposlookup->{$results[$i][0]}->[1] + 1);
    }

    $return_result[$i][7] = $org_lookup->{$fnamelookup->{$results[$i][0]}->[4]};
    $return_result[$i][8] = $results[$i][1];
    }

    return(@return_result);
}

sub get_gene_id_to_go_id{
    my($self, $gene_id) = @_;
    my($query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @process_cv_id = $self->get_cv_id('process');
    my @function_cv_id = $self->get_cv_id('function');
    my @component_cv_id = $self->get_cv_id('component');

# GO terms stored in two different ways
    my $go_cvs = "";
    my @go_cv_id = $self->get_cv_id('GO');
    if ($process_cv_id[0][0] ne ""){
        $go_cvs = "$process_cv_id[0][0], $function_cv_id[0][0], $component_cv_id[0][0]";
    }else{
        $go_cvs = "$go_cv_id[0][0]";
    }

    $query = "SELECT d.accession ".
    "FROM feature f1, feature_dbxref fd, dbxref x1, dbxref d, feature_cvterm fc, cvterm c ".
    "WHERE f1.type_id = $transcript_cv_id[0][0] ".
    "AND f1.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = x1.dbxref_id  ".
    "AND x1.version = \"locus\" ".
    "AND x1.accession = ? ".
    "AND f1.feature_id = fc.feature_id ".
    "AND fc.cvterm_id = c.cvterm_id ".
    "AND c.cv_id in ($go_cvs) ".
    "AND c.dbxref_id = d.dbxref_id ";

    my @results = $self->_get_results($query, $gene_id);

    return(@results);
}

sub get_ori_db_role_id_to_gene_list{
    my($self, $ori_db, $role_id, $feat_type, $seq_id)=@_;
    my($query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @tigr_role_cv_id = $self->get_cv_id('TIGR_role');

    my $orgs = $self->get_ori_db_org_id_lookup;

    my @results;

    if($role_id){

	$query = "SELECT f.feature_id ".
            "FROM dbxref d, cvterm_dbxref cd, cvterm c, feature f, feature_cvterm fc  ".
	    "WHERE f.type_id = $transcript_cv_id[0][0] ".
	    "AND f.feature_id = fc.feature_id ".
	    "AND fc.cvterm_id = c.cvterm_id ".
	    "AND c.cv_id = $tigr_role_cv_id[0][0] ".
	    "AND c.cvterm_id = cd.cvterm_id ".
	    "AND cd.dbxref_id = d.dbxref_id ".
	    "AND d.accession  = \"$role_id\" ";

    }else{

	$query = "SELECT f.feature_id ".
	    "FROM  feature f ".
	    "WHERE f.type_id = $transcript_cv_id[0][0] ".
	    "AND not exists ".
	    "(SELECT * FROM cvterm c, feature_cvterm fc, dbxref d, cvterm_dbxref cd ".
	    "WHERE f.feature_id = fc.feature_id ".
	    "AND fc.cvterm_id = c.cvterm_id ".
	    "AND c.cv_id = $tigr_role_cv_id[0][0] ".
	    "AND c.cvterm_id = cd.cvterm_id ".
	    "AND cd.dbxref_id = d.dbxref_id) ";
    }

    if($ori_db){
	$query .= "AND f.organism_id = $orgs->{$ori_db} ";
    }

    @results = $self->_get_results($query);

    my $fnamelookup = $self->get_feature_id_to_gene_name_lookup;
    my $fposlookup = $self->get_feature_id_to_gene_pos_lookup;

    my $ec_hashref = &make_ec_hash($self);

    my @return_result;

    my ($mol_name, $prev_asmbl_feature_id);
    my $j = 0;
    for (my $i=0; $i<@results; $i++) {

        # SELECT i.locus, i.gene_sym, i.com_name, i.ec_num, f.end5, f.end3, i.nt_locus, a.name
	next if ($seq_id && $seq_id !~ /$fposlookup->{$results[$i][0]}->[6]/);
	$return_result[$j][0] = $fnamelookup->{$results[$i][0]}->[1];
	$return_result[$j][1] = $fnamelookup->{$results[$i][0]}->[3];
	$return_result[$j][2] = $fnamelookup->{$results[$i][0]}->[2];
	$return_result[$j][3] = $ec_hashref->{$fnamelookup->{$results[$i][0]}->[1]};

	if($fposlookup->{$results[$i][0]}->[3] == 1){
	    $return_result[$j][4] = ($fposlookup->{$results[$i][0]}->[1] + 1);
	    $return_result[$j][5] = $fposlookup->{$results[$i][0]}->[2];
	}else{
	    $return_result[$j][5] = $fposlookup->{$results[$i][0]}->[2];
	    $return_result[$j][4] = ($fposlookup->{$results[$i][0]}->[1] + 1);
	}
	$return_result[$j][6] = $fnamelookup->{$results[$i][0]}->[1];
	$return_result[$j][7] = $fposlookup->{$results[$i][0]}->[4];
	$j++;
    }

    return(sort {$a->[7] cmp $b->[7] || $a->[4] <=> $b->[4]} @return_result);

}

sub get_role_id_to_role_info{
    my($self, $role_id)=@_;
    my($query);

    $query = "SELECT r.mainrole, r.sub1role, n.notes ".
        "FROM egad..roles r ".
        "LEFT JOIN common..role_notes n ON (r.role_id = n.role_id) ".
        "WHERE r.role_id = ? ";

    my @results = $self->_get_results($query, $role_id);
    return(@results);
}

sub get_ori_db_to_total_seq_size{
    my ($self, $ori_db) = @_;
    $self->_trace if $self->{_debug};

    my @assembly_cv_id = $self->get_cv_term_id('assembly');

    my $query = "SELECT sum(f.seqlen) ".
    "FROM feature f, organism o, organism_dbxref od, dbxref dx, db ".
    "WHERE o.organism_id = od.organism_id ".
    "AND od.dbxref_id = dx.dbxref_id ".
    "AND LOWER(SUBSTRING(db.name, 6, 15)) = ? ".
        "AND dx.version = \"legacy_annotation_database\" ".
        "AND dx.db_id = db.db_id ".
    "AND o.organism_id = f.organism_id ".
    "AND f.type_id = $assembly_cv_id[0][0] ";

    my @results = $self->_get_results($query, $ori_db);

    return @results;
}

sub get_gene_id_to_orf_feat_type{
    my($self, $gene_id) = @_;
    my($query);

    $query = "SELECT \"ORF\" ";

    my @results = $self->_get_results($query);
    return(@results);

}

sub get_tigr_locus_to_ntl_and_nt_locus {
    my($self, $TIGR_locus) = @_;
    my($query);

    my @results;
    return(@results);
}

sub get_org_id_to_accessions{
    my ($self, $org_id, $acc_db) = @_;
    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my $fnamelookup = $self->get_feature_id_to_gene_name_lookup();

    if($acc_db eq "SP"){
        $acc_db = "Swiss-Prot";
    }elsif($acc_db eq "protein_id"){
        $acc_db = "Genbank";
    }elsif($acc_db eq "PID"){
        $acc_db = "NCBI_gi";
    }

    my $query = "SELECT f.feature_id, x.accession ".
        "FROM feature f, feature_dbxref fd, dbxref x,  db d ".
        "WHERE f.type_id = $transcript_cv_id[0][0] ".
        "AND f.organism_id = ? ".
        "AND f.feature_id = fd.feature_id ".
        "AND fd.dbxref_id = x.dbxref_id ".
        "AND x.db_id = d.db_id  ".
        "AND d.name = ? ";

    my @results = $self->_get_results($query, $org_id, $acc_db);

    for(my $i = 0; $i < scalar @results; $i++){
        $results[$i][0] = $fnamelookup->{$results[$i][0]}->[1];
    }

    return(\@results);

}

sub get_gene_id_to_accession{
    my ($self, $gene_id, $acc_db) = @_;
    my @transcript_cv_id = $self->get_cv_term_id('transcript');

    if($acc_db eq "SP"){
        $acc_db = "Swiss-Prot";
    }elsif($acc_db eq "protein_id"){
        $acc_db = "Genbank";
    }elsif($acc_db eq "PID"){
        $acc_db = "NCBI_gi";
    }

    my $query = "SELECT x2.accession ".
        "FROM feature f, feature_dbxref fd, dbxref x, ".
        "feature_dbxref fd2, dbxref x2, db d ".
        "WHERE f.type_id = $transcript_cv_id[0][0] ".
        "AND f.feature_id = fd.feature_id ".
        "AND fd.dbxref_id = x.dbxref_id ".
        "AND x.version = \"locus\" ".
        "AND x.accession = ? ".
        "AND f.feature_id = fd2.feature_id ".
        "AND fd2.dbxref_id = x2.dbxref_id ".
        "AND x2.db_id = d.db_id  ".
        "AND d.name = ?";

    my @results = $self->_get_results($query, $gene_id, $acc_db);
    return(@results);
}


sub get_gene_id_to_distinct_accession_db{
    my($self, $gene_id)=@_;
    my($query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');

    $query = "SELECT distinct d.name ".
    "FROM feature f1, feature_dbxref fd, feature_dbxref fd2, dbxref x1, dbxref x2, db d ".
    "WHERE f1.type_id = $transcript_cv_id[0][0] ".
    "AND f1.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = x1.dbxref_id ".
    "AND x1.version = \"locus\" ".
    "AND x1.accession = ? ".
    "AND f1.feature_id = fd2.feature_id ".
    "AND fd2.dbxref_id = x2.dbxref_id ".
    "AND x2.db_id = d.db_id ";

    my @results = $self->_get_results($query, $gene_id);
    return(@results);
}

sub get_gene_id_to_orf_attribute{
    my($self, $gene_id, $att_type)=@_;
    my($query);

    my($protein, $cds);
 
    my @transcript_cv_id = $self->get_cv_term_id('transcript');
  

    if($att_type eq "PI"){
        $att_type = "pi";
        $protein = 1;
    }elsif($att_type eq "MW"){
        $protein = 1;
    }elsif($att_type eq "GC"){
        $att_type = "percent_GC";
        $cds = 1;
    }elsif($att_type eq "TERM direction"){
        $att_type = "term_direction";
    }elsif($att_type eq "TERM confidence"){
        $att_type = "term_confidence";
    }elsif($att_type eq "OMP"){
        $att_type = "outer_membrane_protein";
    }elsif($att_type eq "LP"){
        $att_type = "lipo_membrane_protein";
    }elsif($att_type eq "GES"){
        $att_type = "transmembrane_regions";
    }elsif($att_type eq "GES coordinates"){
        $att_type = "transmembrane_coords";
    }elsif($att_type eq "SP C-score"){
        $att_type = "c-score";
        $protein = 1;
    }elsif($att_type eq "SP S-score"){
        $att_type = "s-score";
        $protein = 1;
    }elsif($att_type eq "SP s-mean"){
        $att_type = "s-mean";
        $protein = 1;
    }elsif($att_type eq "SP site"){
        $att_type = "NN_cleavage_site";
        $protein = 1;
    }elsif($att_type eq "SP Y-score"){
        $att_type = "y-score";
        $protein = 1;
    }

    my @results;

    if($protein || $cds){
        my @protein_info = $self->get_gene_id_to_protein_info($gene_id);

        my $feature_id = "";
        if($protein) {
                $feature_id = $protein_info[0][1];
        }else{
                $feature_id = $protein_info[0][3];
        }

        $query = "SELECT fp.value ".
                "FROM feature f, featureprop fp, cvterm c ".
                "WHERE f.feature_id = $feature_id ".
                "AND f.feature_id = fp.feature_id ".
                "AND fp.type_id = c.cvterm_id ".
                "AND c.name = \"$att_type\" ";


        @results = $self->_get_results($query);

    }else{
	
        if(($att_type eq "term_direction") || ($att_type eq "term_confidence")){

                $query = "SELECT fp.value ".
                    "FROM feature f, featureprop fp, cvterm c ".
                    "WHERE f.uniquename = ? ".
                    "AND f.feature_id = fp.feature_id ".
                    "AND fp.type_id = c.cvterm_id ".
                    "AND c.name = ? ";

        }else{

                $query = "SELECT fp.value ".
                    "FROM feature f, featureprop fp, cvterm c, feature_dbxref fd, dbxref x ".
                    "WHERE f.type_id = $transcript_cv_id[0][0] ".
                    "AND f.feature_id = fd.feature_id ".
                    "AND fd.dbxref_id = x.dbxref_id ".
                    "AND x.version = \"locus\" ".
                    "AND x.accession = ? ".
                    "AND f.feature_id = fp.feature_id ".
                    "AND fp.type_id = c.cvterm_id ".
                    "AND c.name = ? ";


        }

        @results = $self->_get_results($query, $gene_id, $att_type);
    }

    return(@results);
}

sub get_gene_id_to_all_vs_all{
    my ($self, $gene_id) = @_;


    my $org_lookup = $self->get_ori_db_org_id_lookup();
    my @feature_ids = $self->get_locus_to_feature_ids($gene_id);
    my $org_name_lookup = $self->get_org_id_to_org_name_lookup();



    my $query = "SELECT m.hfeature_id, m.p_value, m.per_id, m.per_sim, m.horganism_id ".
            "FROM cm_blast m ".
	    "WHERE m.qfeature_id = $feature_ids[0][0] ".
	    "AND m.qfeature_id != m.hfeature_id ";


    my @results = $self->_get_results($query);
    my $fnamelookup = $self->get_pfeature_id_to_gene_name_lookup();

    my $j = 0;
    my @return_results;
	  	 
    for(my $i = 0; $i < scalar @results; $i++){ 	 
	my $locus = $fnamelookup->{$results[$i][0]}->[2]; ## locus
	next if($locus eq "");
	## transformed data
	$return_results[$j][5] = $org_name_lookup->{$results[$i][4]}; ## ori_name
	$return_results[$j][4] = $org_lookup->{$results[$i][4]}; ## ori_db
	$return_results[$j][0] = $locus;
	
	## direct copies
	$return_results[$j][1] = $results[$i][1];
	$return_results[$j][2] = $results[$i][2];
	$return_results[$j][3] = $results[$i][3];
	$j++;
    }
    
    @results = sort {$b->[2] <=> $a->[2]} @return_results;
    return \@results;

}

sub get_gene_id_to_role_id{
    my($self, $gene_id)=@_;
    my($query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @tigr_role_cv_id = $self->get_cv_id('TIGR_role');

    $query = "SELECT d.accession ".
    "FROM cvterm c, feature_cvterm fc, feature f, dbxref d, cvterm_dbxref cd, feature_dbxref fd, dbxref x ".
    "WHERE f.type_id = $transcript_cv_id[0][0] ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.cvterm_id = c.cvterm_id ".
    "AND c.cv_id = $tigr_role_cv_id[0][0] ".
    "AND c.cvterm_id = cd.cvterm_id ".
    "AND cd.dbxref_id = d.dbxref_id ".
    "AND f.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = x.dbxref_id ".
    "AND x.version = \"locus\" ".
    "AND x.accession = ? ";
    my @results = $self->_get_results($query, $gene_id);
    return(@results);
}

sub get_gene_id_to_go_term_info{
    my($self, $gene_id) = @_;

    my($query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @process_cv_id = $self->get_cv_id('process');
    my @function_cv_id = $self->get_cv_id('function');
    my @component_cv_id = $self->get_cv_id('component');
    my @ev_code_cv_id = $self->get_cv_id('evidence_code');

# GO terms stored in two different ways
    my $go_cvs = "";
    my @go_cv_id = $self->get_cv_id('GO');
    if ($process_cv_id[0][0] ne ""){
        $go_cvs = "$process_cv_id[0][0], $function_cv_id[0][0], $component_cv_id[0][0]";
    }else{
        $go_cvs = "$go_cv_id[0][0]";
    }

    $query = "SELECT ct.name, fcp.value, fcp.value, t.name, t.type, t.definition, d.accession ".
        "FROM feature f1, feature_dbxref fd, dbxref x1, dbxref d, feature_cvterm fc, cvterm c, common..go_term t, feature_cvtermprop fcp, cvterm ct ".
        "WHERE d.accession = t.go_id ".
        "AND f1.type_id = $transcript_cv_id[0][0] ".
        "AND f1.feature_id = fd.feature_id ".
        "AND fd.dbxref_id = x1.dbxref_id  ".
        "AND x1.version = \"locus\" ".
        "AND x1.accession = ? ".
        "AND f1.feature_id = fc.feature_id ".
        "AND fc.cvterm_id = c.cvterm_id ".
        "AND c.cv_id in ($go_cvs) ".
        "AND c.dbxref_id = d.dbxref_id ".
        "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ".
        "AND fcp.type_id = ct.cvterm_id ".
        "AND ct.cv_id = $ev_code_cv_id[0][0] ";

    my @results = $self->_get_results($query, $gene_id);

    my $junk;

    for (my $i=0; $i<@results; $i++) {

        ($results[$i][1], $junk) = split(/ WITH /,$results[$i][1]);
        ($junk, $results[$i][2]) = split(/ WITH /,$results[$i][2]);

    }

    return(@results);
}



## replacement query with cm_table
## that needs to be moved to ChadoMartCoatiDB.pm
sub get_org_id_to_evidence {
    my($self, $org_id, $ev_type, $ev_acc) = @_;

    ## map evidence types from script to db storage
    my $orig_ev_type = $ev_type;  # store for splitting TIGR/PFam
    if($ev_type eq "COG accession"){
        $ev_type = "NCBI_COG";
    }elsif($ev_type eq "HMM2"){
        $ev_type = "HMM2_analysis";
    }elsif($ev_type eq "BER"){
        $ev_type = "BER_analysis";
    }elsif($ev_type eq "AUTO_BER"){
        $ev_type = "BER_analysis";
    }elsif($ev_type eq "TIGRFAM"){
        $ev_type = "HMM2_analysis";
    }elsif($ev_type eq "PFAM"){
        $ev_type = "HMM2_analysis";
    }

    my $query = qq/SELECT e.ev_accession, g.locus, e.cutoff, e.score,
	                  e.ev_description, g.seq_id, e.rel_end5,
	                  e.rel_end3, e.genomic_end5, e.genomic_end3
			      FROM cm_evidence e, cm_gene g /;

    if($orig_ev_type eq 'TIGRFAM' || $orig_ev_type eq 'PFAM' ){
	$query .= qq/, egad..hmm2 h /;
    }
    
    $query .= qq/ WHERE e.transcript_id = g.transcript_id 
		  AND e.ev_type = ?
	        /;

    if($orig_ev_type eq "TIGRFAM"){
        $query .= qq/ AND h.hmm_type = 'TOGA' 
	              AND h.hmm_acc = e.ev_accession /;
    }elsif($orig_ev_type eq "PFAM"){
        $query .= qq/ AND h.hmm_type != 'TOGA'
	              AND h.hmm_acc = e.ev_accession  /;
    }

    ## args array
    my @args = ($ev_type);

    if($org_id){
	$query .= qq/AND g.organism_id = ? /;
	push @args, $org_id;
    }

    if($ev_acc){
	$query .= qq/AND e.ev_accession = ? /;
	push @args, $ev_acc;
    }

    return $self->_get_results_ref($query, @args);

}

## original sub for get_org_id_to_evidence that queries the base tables
## this is too slow, tho ... we use this query to generate cm_evidence
##
## this needs to be moved over to ChadoMartCoatiDB.pm
sub _get_org_id_to_evidence{
    my($self, $org_id, $ev_type, $ev_acc) = @_;

    if($ev_type eq "COG accession"){
        $ev_type = "NCBI_COG";
    }elsif($ev_type eq "HMM2"){
        $ev_type = "HMM2_analysis";
    }elsif($ev_type eq "BER"){
        $ev_type = "BER_analysis";
    }elsif($ev_type eq "AUTO_BER"){
        $ev_type = "BER_analysis";
    }

    my $analysis_id = $self->get_analysis_id_list($ev_type);
    my @match_cv_id = $self->get_cv_term_id('match_part', 'SO');

    ## feature lookup
    ## set type so we know how to look up info
    my ($fnamelookup, $type, $transcript_id_lookup);
    if($ev_type eq 'BER_analysis'){
	$type = "transcript";
	$transcript_id_lookup = $self->get_locus_to_feature_id_lookup('transcript');
	$fnamelookup =  $self->get_feature_id_to_gene_name_lookup();;
    }else{
	$type = "polypeptide";
	$fnamelookup = $self->get_pfeature_id_to_gene_name_lookup();
    }

    my $fposlookup = $self->get_feature_id_to_gene_pos_lookup();

    $analysis_id =~ s/\s//g;

    # if there's no results for the evidence type, return nothing
    my @final_results;
    if(!$analysis_id){
	return (\@final_results);
    }

    #placeholders for cutoff, score, description
    my $tmp_ev_select = "'', '', ''";
    if($ev_type eq "HMM2_analysis"){
        $tmp_ev_select = "h.trusted_cutoff, af.rawscore, h.hmm_com_name ";
    }

    my $query = "SELECT f2.uniquename, f3.feature_id, $tmp_ev_select, fl2.fmin, fl2.fmax, fl2.strand, x.accession  ".
	"FROM analysisfeature af, feature f, featureloc fl, ".
	"feature f2, feature f3, featureloc fl2, feature_dbxref fd, dbxref x ";

    $query .= ", egad..hmm2 h " if($ev_type eq "HMM2_analysis");

    $query .= "WHERE  af.analysis_id IN ($analysis_id) "
        ."AND af.feature_id = f.feature_id "
        ."AND f.feature_id = fl.feature_id "
        ."AND fl.srcfeature_id = f2.feature_id "
        ."AND f.type_id = $match_cv_id[0][0] "
        ."AND fl.rank = 0 "
        ."AND f.feature_id = fl2.feature_id "
        ."AND fl2.srcfeature_id = f3.feature_id "
        ."AND fl2.rank = 1 "
        ."AND f3.organism_id = $org_id "
	."AND fd.feature_id = f3.feature_id "
	."AND fd.dbxref_id = x.dbxref_id "
	."AND x.version = 'locus' ";


    if($ev_type eq "HMM2_analysis"){
        $query .= "AND f2.uniquename = h.hmm_acc ";
    }

    if($ev_acc){
        $query .= "AND f2.uniquename = \"$ev_acc\" ";
    }

    my @results = $self->_get_results($query);
    for(my $i = 0; $i < scalar @results; $i++){
	my ($transcript_id, $locus);

	if($type eq "polypeptide"){
	    $transcript_id = $fnamelookup->{$results[$i][1]}->[0];
	    $locus = $results[$i][8];
	}else{
	    $locus = $results[$i][8];
	    $transcript_id = $transcript_id_lookup->{$locus}->[0];
	}

	$final_results[$i][0] = $results[$i][0]; # evidence accession
	$final_results[$i][1] = $locus;          # locus
	$final_results[$i][2] = $results[$i][2]; # cutoff
	$final_results[$i][3] = $results[$i][3]; # score
	$final_results[$i][4] = $results[$i][4]; # description
	$final_results[$i][5] = $fposlookup->{$transcript_id}->[6]; # seq_id

	# Store relative position information
	$final_results[$i][6] = $results[$i][5]; # rel fmin
	$final_results[$i][7] = $results[$i][6]; # rel fmax
	# Don't need to pull relative strand as it is always pos (relative to direction of locus/gene)
	# my $strand = $results[$i][7]; # strand
	# also don't need to swap rel end5/end3 according to strand

	# convert interbase fmin to base relative coordinates
	$final_results[$i][6] += 1;

	# Calculate genomic context position information
	# rel coords are always given relative to end5 of the gene/locus
	# so this can be calculated as
	# genomic_coord = gene_end5 + strand * 3 * rel_coord
	# note: strand is 1 or -1 which is why this works
	my $gene_strand = $fposlookup->{$transcript_id}->[3]; 
	my $gene_end5 = ($gene_strand == -1) ? $fposlookup->{$transcript_id}->[2] : $fposlookup->{$transcript_id}->[1] + 1;
	$final_results[$i][8] = $gene_end5 + $gene_strand * 3 * $results[$i][5]; # genomic_end5
	$final_results[$i][9] = $gene_end5 + $gene_strand * 3 * $results[$i][6]; # genomic_end3

    }

    return (\@final_results);

}

sub get_gene_id_to_evidence_count {
 
    my($self, $gene_id, $ev_type, $ev_acc) = @_;
 
    my($query);

    if($ev_type eq "COG accession"){
        $ev_type = "NCBI_COG";
    }elsif($ev_type eq "HMM2"){
        $ev_type = "HMM2_analysis";
    }elsif($ev_type eq "BER"){
        $ev_type = "BER_analysis";
    }elsif($ev_type eq "AUTO_BER"){
        $ev_type = "BER_analysis";
    }   
    my @protein_info = $self->get_gene_id_to_protein_info($gene_id) if ($gene_id);
    my $analysis_ids = $self->get_analysis_id_list($ev_type);

    my @results;

    $analysis_ids =~ s/\s//g;

    if(!$analysis_ids){
	return (\@results);
    }

    $query = qq/SELECT count(af.feature_id)
                FROM analysisfeature af
		WHERE af.analysis_id IN /;
    $query .= "($analysis_ids)";

    if($gene_id){ # generalized query for generating db reports
        if($ev_type eq "BER_analysis"){
                $query .= "AND af.feature_id = $protein_info[0][3] ";
        }else{
                $query .= "AND af.feature_id = $protein_info[0][1] ";
        }
    }


    @results = $self->_get_results($query);

    return(@results);
}

sub get_gene_id_to_evidence_cmr{
    my($self, $gene_id, $ev_type, $ev_acc) = @_;
    my($query);

    if($ev_type eq "COG accession"){
        $ev_type = "NCBI_COG";
    }elsif($ev_type eq "HMM2"){
        $ev_type = "HMM2_analysis";
    }elsif($ev_type eq "BER"){
        $ev_type = "BER_analysis";
    }elsif($ev_type eq "AUTO_BER"){
        $ev_type = "BER_analysis";
    }

    my @protein_info = $self->get_gene_id_to_protein_info($gene_id) if ($gene_id);
    my @match_cv_id = $self->get_cv_term_id('match_part', 'SO');

    $query = "SELECT f2.uniquename, af.rawscore, convert(varchar,af.significance), (fl2.fmin + 1), fl2.fmax, (fl.fmin + 1), fl.fmax "
        ."FROM analysis a, analysisfeature af, feature f, featureloc fl, feature f2, feature f3, featureloc fl2 ";

    if($ev_type eq "HMM2_analysis"){
        $query .= ", egad..hmm2 h ";
    }

    $query .= "WHERE a.name = \"$ev_type\" "
        ."AND a.analysis_id = af.analysis_id "
        ."AND af.feature_id = f.feature_id "
        ."AND f.feature_id = fl.feature_id "
        ."AND fl.srcfeature_id = f2.feature_id "
        ."AND f.type_id = $match_cv_id[0][0] "
        ."AND fl.rank = 0 "
        ."AND f.feature_id = fl2.feature_id "
        ."AND fl2.srcfeature_id = f3.feature_id "
        ."AND fl2.rank = 1 ";

    if($gene_id){ # generalized query for generating db reports
        if($ev_type eq "BER_analysis"){
                $query .= "AND f3.feature_id = $protein_info[0][3] ";
        }else{
                $query .= "AND f3.feature_id = $protein_info[0][1] ";
        }
    }

    if($ev_type eq "HMM2_analysis"){
        $query .= "AND f2.uniquename = h.hmm_acc ";
    }

    if($ev_acc){
        $query .= "AND f2.uniquename = \"$ev_acc\" ";
    }

    $query .= "ORDER BY f2.uniquename ";
;

    my @results = $self->_get_results($query);

    for (my $i=0; $i<@results; $i++) {

        if(!($results[$i][1] =~ /\./)){
                $results[$i][1] = $results[$i][1] . ".0";
        }

        if($results[$i][2] =~ /e/){
                my($before1, $after1) = split(/e/,$results[$i][2]);
                my($before2, $after2) = split(/\./,$before1);
                my(@before3) = split(//,$after2);
                $results[$i][2] = $before2 . "." . $before3[0] . "e" . $after1;
        }elsif($results[$i][2] =~ /\./){
                my($before2, $after2) = split(/\./,$results[$i][2]);
                my(@before3) = split(//,$after2);
                $results[$i][2] = $before2 . "." . $before3[0];
        }
        $results[$i][9] = substr($protein_info[0][2],$results[$i][3], $results[$i][4] - $results[$i][3]); ;


    }

    return(@results);
}

sub get_gene_id_to_distinct_evidence_acc{
    my($self, $gene_id, $ev_type, $above_noise) = @_;
    my($query);

    if($ev_type eq "COG accession"){
        $ev_type = "NCBI_COG";
    }elsif($ev_type eq "HMM2"){
        $ev_type = "HMM2_analysis";
    }elsif($ev_type eq "BER"){
        $ev_type = "BER_analysis";
    }elsif($ev_type eq "AUTO_BER"){
        $ev_type = "BER_analysis";
    }

    my @protein_info = $self->get_gene_id_to_protein_info($gene_id);
    my @match_cv_id = $self->get_cv_term_id('match_part', 'SO');

    $query = "SELECT distinct f2.uniquename "
        ."FROM analysis a, analysisfeature af, feature f, featureloc fl, feature f2, feature f3, featureloc fl2 ";

    if($ev_type eq "HMM2_analysis"){
        $query .= ", egad..hmm2 h ";
    }

    $query .= "WHERE a.name = \"$ev_type\" "
        ."AND a.analysis_id = af.analysis_id "
        ."AND af.feature_id = f.feature_id "
        ."AND f.feature_id = fl.feature_id "
        ."AND fl.srcfeature_id = f2.feature_id "
        ."AND f.type_id = $match_cv_id[0][0] "
        ."AND fl.rank = 0 "
        ."AND f.feature_id = fl2.feature_id "
        ."AND fl2.srcfeature_id = f3.feature_id "
        ."AND fl2.rank = 1 ";

    if($ev_type eq "BER_analysis"){
        $query .= "AND f3.feature_id = $protein_info[0][3] ";
    }else{
        $query .= "AND f3.feature_id = $protein_info[0][1] ";
    }

    if($ev_type eq "HMM2_analysis"){
        $query .= "AND f2.uniquename = h.hmm_acc ";

        if($above_noise){
                $query .= "AND convert(float, af.rawscore) >= h.noise_cutoff ";
        }
    }

    $query .= "ORDER BY f2.uniquename ";

    my @results = $self->_get_results($query);
    return(@results);
}

sub get_gene_id_to_ber_hits{
    my ($self, $gene_id) = @_;
    $self->_trace if $self->{_debug};

    # missing e.per_id, e.per_sim, e.date

    my @protein_info = $self->get_gene_id_to_protein_info($gene_id);
    my @match_cv_id = $self->get_cv_term_id('match_part', 'SO');
    my @per_sim_cv_id = $self->get_cv_term_id('percent_similarity');

    my $query = "SELECT f2.uniquename, fl.fmin, fl.fmax, fl2.fmin, fl2.fmax, af.pidentity, fp.value "
    ."FROM analysis a, analysisfeature af, feature f, featureloc fl, feature f2, feature f3, featureloc fl2, featureprop fp "
    ."WHERE a.name = \"BER_analysis\" "
    #."WHERE a.name = 'ber' "
    ."AND a.analysis_id = af.analysis_id "
    ."AND af.feature_id = f.feature_id "
    ."AND f.feature_id = fl.feature_id "
    ."AND fl.srcfeature_id = f2.feature_id "
    ."AND f.type_id = $match_cv_id[0][0] "
    ."AND fl.rank = 0 "
    ."AND f.feature_id = fl2.feature_id "
    ."AND fl2.srcfeature_id = f3.feature_id "
    ."AND fl2.rank = 1 "
    ."AND f3.feature_id = $protein_info[0][3] "
    ."AND af.feature_id = fp.feature_id "
    ."AND fp.type_id = $per_sim_cv_id[0][0] ";

    $query .= "ORDER BY f2.uniquename ";

    my @results = $self->_get_results($query);
    return @results;
}

sub get_cog_accession_to_description{
    my($self, $accession)=@_;
    my($query);

    $query = "SELECT com_name, gene_sym ".
        "FROM common..cog ".
        "WHERE accession = ? ";

    my @results = $self->_get_results($query, $accession);
    return(@results);
}



sub get_gene_id_to_child{
    my($self, $gene_id, $feat_type) = @_;
    my($query);

    if($feat_type eq "RBS"){
    $feat_type = "ribosome_entry_site";
    }if($feat_type eq "TERM"){
    $feat_type = "terminator";
    }

    my @feat_type_cv_id = $self->get_cv_term_id($feat_type);
    my @transcript_cv_id = $self->get_cv_term_id('transcript');

    $query = "SELECT f2.uniquename, f2.residues, l.fmax, l.fmin, l.strand ".
    "FROM feature f1, feature_dbxref fd, dbxref x1, featureloc l, feature f2, feature_relationship fr ".
    "WHERE f1.type_id = $transcript_cv_id[0][0] ".
    "AND f1.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = x1.dbxref_id  ".
    "AND x1.version = \"locus\" ".
    "AND x1.accession = ? ".
    "AND f2.feature_id = l.feature_id  ".
    "AND f1.feature_id = fr.object_id ".
    "AND fr.subject_id  = f2.feature_id ".
    "AND f2.type_id = $feat_type_cv_id[0][0]";




    my @results = $self->_get_results($query, $gene_id);

    for (my $i=0; $i<@results; $i++) {
    if($results[$i][4] == 1){
        $results[$i][2] = $results[$i][2];
        $results[$i][3] = ($results[$i][3] + 1);
    }else{
        my $tmp = $results[$i][2];
        $results[$i][2] = ($results[$i][3] + 1);
        $results[$i][3] = $tmp;
    }
    }



    return(@results);
}

sub get_gene_id_to_operon{
    my($self, $gene_id) = @_;
    my($query);

#    $query = "SELECT locus, taxon_id, gene_id ".
#	     "FROM operon..genes ".
#	     "WHERE locus = ? ";

    my @results;# = $self->_get_results($query, $gene_id);
    return(@results);
}

sub get_gene_id_to_align_id{
    my($self, $gene_id) = @_;
    my($query);

    my @results;# = $self->_get_results($query, $gene_id);
    return(@results);
}

sub get_locus_to_feature_ids {
    # First, pre-select chado's gene id and transcript id
    # for the given $gene_id
    my($self,$gene_id) = @_;

    my @protein_cv_id = $self->get_cv_term_id('protein');
    my @transcript_cv_id = $self->get_cv_term_id('transcript');


    my $query = "SELECT p.feature_id, p2.feature_id ".
            "FROM feature p, feature_dbxref fd, dbxref x, feature p2, feature_dbxref fd2 ".
        "WHERE  x.version = \"locus\" ".
        "AND x.accession = \"$gene_id\" ".
        "AND fd.dbxref_id = x.dbxref_id  ".
        "AND p.feature_id = fd.feature_id  ".
        "AND p.type_id = $protein_cv_id[0][0] ".
        "AND fd2.dbxref_id = x.dbxref_id ".
        "AND p2.feature_id = fd2.feature_id ".
        "AND p2.type_id = $transcript_cv_id[0][0] ";


    my @results = $self->_get_results($query);

    return @results;

}



sub get_gene_id_to_all_vs_all_hits {
    my($self,$ori_db,$seq_id,$gene_id,$org_list)=@_;

    # Do not need $ori_db or $seq_id
    # Check with Nikhat to see why it was added
    # - Anu (Oct 18, 2005)

    # First, pre-select chado's gene id and transcript id
    # for the given $gene_id

    my @ids = $self->get_locus_to_feature_ids($gene_id);

    my $protein_id = $ids[0][0];

    # Now use these to determine all vs all hits
    my $query = "SELECT m.hfeature_id, m.p_value, m.per_id, m.per_sim, m.horganism_id ".
        "FROM cm_blast m ".
        "WHERE m.qfeature_id = $protein_id ";

    my $fnamelookup = $self->get_pfeature_id_to_gene_name_lookup();
    my $fposlookup = $self->get_feature_id_to_gene_pos_lookup();
    my $org_lookup = $self->get_ori_db_org_id_lookup(); #get_org_id_to_org_name_lookup();

    my @results = $self->_get_results($query);
    my @final_results;
    my $j = 0;

    for(my $i = 0; $i < scalar @results; $i++){

        next if ($org_list !~ /$org_lookup->{$results[$i][4]}/ && $org_list);
        my $hfeat_id = $fnamelookup->{$results[$i][0]}->[0];
        $final_results[$j][0] = $org_lookup->{$results[$i][4]}; #ori_db
        $final_results[$j][1] = "NTORF";
        $final_results[$j][2] = $fposlookup->{$hfeat_id}->[6]; #seq_id
        $final_results[$j][3] = $fnamelookup->{$results[$i][0]}->[2]; #locus
        $final_results[$j][4] = $fnamelookup->{$results[$i][0]}->[2]; #locus
        $final_results[$j][5] = ($fposlookup->{$hfeat_id}->[3] == 1) ? $fposlookup->{$hfeat_id}->[1] : $fposlookup->{$hfeat_id}->[2]; #end5
        $final_results[$j][6] = ($fposlookup->{$hfeat_id}->[3] == 1) ? $fposlookup->{$hfeat_id}->[2] : $fposlookup->{$hfeat_id}->[1]; #end3
        $final_results[$j][7] = $results[$i][1]; #p_value
        $final_results[$j][8] = $fposlookup->{$hfeat_id}->[4]; #seq_name
        $final_results[$j][9] = $fnamelookup->{$results[$i][0]}->[2];
        $final_results[$j][10] = $results[$i][2];
        $final_results[$j][11] = $results[$i][3];
        $j++;
    }

    return @final_results;
}


sub get_genome_compare_gene_match{
     my($self, $ASMBLID1, $ASMBLID2, $LOGIC, $all_vs_all_field, $exclude_asmbl_id)=@_;

     my @results = &get_genome_compare_gene_match_query($self, $ASMBLID1, $ASMBLID2, $LOGIC, $all_vs_all_field, $exclude_asmbl_id);
     my @exc_results = &get_genome_compare_gene_match_query($self, $ASMBLID1, $exclude_asmbl_id, $LOGIC, $all_vs_all_field) if ($exclude_asmbl_id);
     my @fresults;
     my $j = 0;
     my %locus_lookup;

     ## Might be worth looping through asmbl_ids and getting list

     my $fnamelookup = $self->get_pfeature_id_to_gene_name_lookup;
     my $fposlookup = $self->get_feature_id_to_gene_pos_lookup;

     for (my $i=0; $i<@exc_results; $i++) {
    my $key = "$exc_results[$i][0] $exc_results[$i][1]";
    next if ($exclude_asmbl_id && $exclude_asmbl_id =~ /$fposlookup->{$fnamelookup->{$exc_results[$i][1]}->[0]}->[6]/ );
    $locus_lookup{$key} = 1;
     }

     for (my $i=0; $i<@results; $i++) {

    my $key = "$results[$i][0] $results[$i][1]";
    next if(exists($locus_lookup{$key}));
    $locus_lookup{$key} = 1;

    my $qfeat_id = $fnamelookup->{$results[$i][0]}->[0];
    my $hfeat_id = $fnamelookup->{$results[$i][1]}->[0];

    next if($ASMBLID1 && ($fposlookup->{$qfeat_id}->[6] ne $ASMBLID1));
    next if($ASMBLID2 && ($ASMBLID2 !~ /$fposlookup->{$hfeat_id}->[6]/));

    my $qend5 = ($fposlookup->{$qfeat_id}->[3] == 1) ? $fposlookup->{$qfeat_id}->[1] : $fposlookup->{$qfeat_id}->[2];
    my $qend3 = ($fposlookup->{$qfeat_id}->[3] == 1) ? $fposlookup->{$qfeat_id}->[2] : $fposlookup->{$qfeat_id}->[1];

    my $hend5 = ($fposlookup->{$hfeat_id}->[3] == 1) ? $fposlookup->{$hfeat_id}->[1] : $fposlookup->{$hfeat_id}->[2];
    my $hend3 = ($fposlookup->{$hfeat_id}->[3] == 1) ? $fposlookup->{$hfeat_id}->[2] : $fposlookup->{$hfeat_id}->[1];

    $fresults[$j][0] = $qend5;
    $fresults[$j][1] = $qend3;
    $fresults[$j][2] = $fposlookup->{$qfeat_id}->[6];
    $fresults[$j][3] = $fnamelookup->{$results[$i][0]}->[2];
    $fresults[$j][4] = $results[$i][2];
    $fresults[$j][6] = $fnamelookup->{$results[$i][0]}->[3];
    $fresults[$j][7] = $fnamelookup->{$results[$i][0]}->[2];

    $fresults[$j][8] = $hend5;
    $fresults[$j][9] = $hend3;
    $fresults[$j][10] = $fposlookup->{$hfeat_id}->[6];
    $fresults[$j][11] = $fnamelookup->{$results[$i][1]}->[2];
    $fresults[$j][12] = $results[$i][2];
    $fresults[$j][14] = $fnamelookup->{$results[$i][1]}->[3];
    $fresults[$j][15] = $fnamelookup->{$results[$i][1]}->[2];
    $j++;


     }


     return(@fresults);

}
sub convert_asmbl_id_to_org_id{
    my ($self, $asms) = @_;

    my $query = "SELECT organism_id FROM feature WHERE uniquename IN $asms ";
    my @results = $self->_get_results($query);
    my $org_id;

    for(my $i = 0; $i < scalar @results; $i++){
    $org_id .= "$results[$i][0],";
    }

    chop $org_id;
    return $org_id;
}


sub get_genome_compare_gene_match_query{
     my($self, $ASMBLID1, $ASMBLID2, $LOGIC, $all_vs_all_field, $exclude_asmbl_id)=@_;

     my @att_type_cv_id = $self->get_cv_term_id('percent_GC');
     my @per_sim_cv_id = $self->get_cv_term_id('percent_similarity');
     my @mol1_info = $self->get_mol_info_from_seq_id($ASMBLID1);
     my @com_name_cv_id = $self->get_cv_term_id('gene_product_name');
     my @transcript_cv_id = $self->get_cv_term_id('transcript');
     my @cds_cv_id = $self->get_cv_term_id('CDS');

     $ASMBLID2 =~ s/\s//g;
     $ASMBLID2 =~ s/\(/\(\'/;
     $ASMBLID2 =~ s/\)/\'\)/;
     $ASMBLID2 =~ s/\,/\'\,\'/g;

     my $org_id_in = $self->convert_asmbl_id_to_org_id($ASMBLID2);
     my $org_id_ref = $self->convert_asmbl_id_to_org_id("('$ASMBLID1')");


     $org_id_ref =~ s/\(//;
     $org_id_ref =~ s/\)//;



     my $select = "SELECT m.qfeature_id, m.hfeature_id, m.per_sim ".
                "FROM cm_blast m ";

     my $where = "WHERE m.horganism_id IN ($org_id_in) ".
            "AND m.qorganism_id = $org_id_ref ";





     if($all_vs_all_field eq "per_sim"){
    $where .= "AND m.per_sim $LOGIC ";
     }elsif($all_vs_all_field eq "per_id"){
    $where .= "AND m.per_id $LOGIC ";
     }elsif($all_vs_all_field eq "Pvalue"){
    $where .= "AND m.p_value $LOGIC ";
     }





     if($all_vs_all_field eq "Pvalue"){
    $where .= " ORDER BY m.p_value ";
     }elsif($all_vs_all_field eq "per_sim"){
    $where .= " ORDER BY m.per_sim desc ";
     }
     my $query = $select . $where;
     my @results = $self->_get_results($query);


}

sub get_genome_compare_no_gene_match{
    my($self, $ASMBLID1, $ASMBLID2, $LOGIC, $all_vs_all_field, $orf_type)=@_;
    my($query);

    my @results = &get_genome_compare_gene_match_query($self, $ASMBLID1, $ASMBLID2, $LOGIC, $all_vs_all_field);
    my @results2 = &get_seq_id_to_gene_count($self, $ASMBLID1);

    my %locus_lookup;

    for (my $i=0; $i<@results; $i++) {
    my $key = "$results[$i][0]";
    $locus_lookup{$key} = 1;
     }

    my $tot = $results2[0][0] - scalar keys %locus_lookup;


    @results = ();#$self->_get_results($query);
    $results[0][0] = $tot;

    return(@results);

}

##### End CMR/Pathema queries #####

sub do_say_hello_schema {
    my ($self, @args) = @_;
    $self->_trace if $self->{_debug};
    print "Hi there.\n"; # I'm a little insect.
}

sub get_cv_term_id {
    my($self, $term, $cv_name) = @_;

    # $cv_name is optional, added because there were two cvterm.name = "gene_symbol"
    # one from GFF3, one from annotation_attributes.ontology we needed a way to tell
    # the difference

    if($term eq "protein"){
        $term = "polypeptide";
    }elsif($term eq 'completed_by' && $ENV{IS_EUK}){
        ## euks use assigned_by flag, not completed_by
        $term = "assignby";
    }



    my $query = "SELECT c.cvterm_id ";

    if($cv_name){
        $query .= "FROM cvterm c, cv v ".
                "WHERE c.name = ? ".
                "AND v.name = \"$cv_name\" ".
                "AND v.cv_id = c.cv_id ";
    }else{
        $query .= "FROM cvterm c ".
                "WHERE c.name = ? ";
    }

    return $self->_get_results($query,$term);
}

sub get_analysis_id_list {
    my($self, $name) = @_;

    my $query = "SELECT analysis_id ".
            "FROM analysis a ".
        "WHERE name = ? ";

    my @results = $self->_get_results($query,$name);
    my $str = "";
    for(my $i = 0; $i < scalar @results; $i++){
        $str .= "$results[$i][0],";
    }
    chop $str;
    return $str;
}

sub get_cv_id {
    my($self, $term) = @_;
    my $query = "SELECT cv_id ".
    "FROM cv ".
    "WHERE name = ? ";

    return $self->_get_results($query,$term);
}

sub get_omnium_seq_id_to_seq_id {
    my($self, $seq_id);

    my $index = index($seq_id, "_");
    my $new_seq_id = substr($seq_id, $index+1);
    $index = index($seq_id, "_");
    $new_seq_id = substr($seq_id, 0, $index);

    return $new_seq_id;
}

sub get_org_id_org_name_from_ori_db {
    my($self, $ori_db) = @_;

    my $query = "SELECT o.organism_id, o.common_name ".
    "FROM organism o, organism_dbxref od, dbxref dx, db ".
    "WHERE o.organism_id = od.organism_id ".
    "AND od.dbxref_id = dx.dbxref_id ".
    "AND dx.db_id = db.db_id ".
    "and dx.version = \"legacy_annotation_database\" ".
    "AND LOWER(db.name) LIKE \"tigr_$ori_db\" ";
    return $self->_get_results($query);
}

sub get_ori_db_org_name_from_org_id {
    my($self, $org_id) = @_;
    my $query = "SELECT LOWER(SUBSTRING(db.name, 6, 15)), o.common_name ".
    "FROM organism o, organism_dbxref od, dbxref dx, db ".
    "WHERE o.organism_id = od.organism_id ".
    "AND od.dbxref_id = dx.dbxref_id ".
    "AND dx.version = \"legacy_annotation_database\" ".
        "AND dx.db_id = db.db_id ".
    "AND o.organism_id = $org_id ";

    return $self->_get_results($query);
}

sub get_mol_info_from_feature_id {
    my($self, $feature_id) = @_;

    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @molecule_name_cv_id = $self->get_cv_term_id('molecule_name');

    my $query = "SELECT p.value, f.uniquename ".
    "FROM feature f, featureprop p ".
    "WHERE f.type_id = $assembly_cv_id[0][0] ".
    "AND f.feature_id = $feature_id ".
    "AND f.feature_id = p.feature_id ".
    "AND p.type_id = $molecule_name_cv_id[0][0] ";


    return $self->_get_results($query);
}

sub get_mol_info_from_seq_id {
    my($self, $seq_id) = @_;

    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @molecule_name_cv_id = $self->get_cv_term_id('molecule_name');

    my $query = "SELECT p.value, f.feature_id ".
    "FROM feature f, featureprop p ".
    "WHERE f.type_id = $assembly_cv_id[0][0] ".
    "AND f.uniquename = \"$seq_id\" ".
    "AND f.feature_id = p.feature_id ".
    "AND p.type_id = $molecule_name_cv_id[0][0] ";

    return $self->_get_results($query);
}

sub get_mol_info_from_gene_id {
    my($self, $gene_id) = @_;

    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @molecule_name_cv_id = $self->get_cv_term_id('molecule_name');
    my @mol_type_cv_id = $self->get_cv_term_id('molecule_type');
    my @mol_topo_cv_id = $self->get_cv_term_id('molecule_topology');
    ## add genome prop's TERM and CRISPR later 
    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @trna_cv_id = $self->get_cv_term_id('tRNA');
    my @rrna_cv_id = $self->get_cv_term_id('rRNA');
    my @snrna_cv_id = $self->get_cv_term_id('snRNA');
    my $type_ids .= "$transcript_cv_id[0][0],$trna_cv_id[0][0],$rrna_cv_id[0][0],$snrna_cv_id[0][0]";
    
    if(!($mol_type_cv_id[0][0])){
    $mol_type_cv_id[0][0] = $mol_topo_cv_id[0][0];
    }

    my $query = "SELECT p.value, f1.feature_id, f1.uniquename, p1.value, p2.value ".
    "FROM feature f2, featureloc l, featureprop p, feature_dbxref fd, dbxref x1, ".
    "feature f1 ".
    "LEFT JOIN (SELECT * FROM featureprop p1 WHERE p1.type_id = $mol_type_cv_id[0][0]) AS p1 ON (f1.feature_id = p1.feature_id) ".
    "LEFT JOIN (SELECT * FROM featureprop p2 WHERE p2.type_id = $mol_topo_cv_id[0][0]) AS p2 ON (f1.feature_id = p2.feature_id ) ".
    "WHERE f1.type_id = $assembly_cv_id[0][0] ".
    "AND f1.feature_id = p.feature_id ".
    "AND p.type_id = $molecule_name_cv_id[0][0] ".
#    "AND f2.type_id = $transcript_cv_id[0][0] ".
    "AND f2.type_id in ($type_ids) ".
    "AND f2.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = x1.dbxref_id ".
    "AND x1.version = \"locus\" ".
    "AND x1.accession = \"$gene_id\" ".
    "AND f2.feature_id = l.feature_id ".
    "AND l.srcfeature_id = f1.feature_id ";

    return $self->_get_results($query);
}

sub get_db_data_info_from_gene_id {
    my($self, $gene_id) = @_;

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @trna_cv_id = $self->get_cv_term_id('tRNA');
    my @rrna_cv_id = $self->get_cv_term_id('rRNA');
    my @snrna_cv_id = $self->get_cv_term_id('snRNA');


    my $query = "SELECT LOWER(d.original_db), o.common_name, o.organism_id, t.kingdom, t.intermediate_rank_1 ".
    "FROM feature f1, organism o, organism_dbxref od, dbxref dx, feature_dbxref fd, dbxref x1, db db, common..db_data1 d, common..taxon_link1 tl, common..taxon t ".
    "WHERE f1.type_id in( $transcript_cv_id[0][0], $trna_cv_id[0][0],$rrna_cv_id[0][0],$snrna_cv_id[0][0]) ".
    "AND f1.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = x1.dbxref_id ".
    "AND x1.version = \"locus\" ".
    "AND x1.accession = \"$gene_id\" ".
    "AND f1.organism_id = o.organism_id ".
    "AND o.organism_id = od.organism_id ".
    "AND od.dbxref_id = dx.dbxref_id ".
    "AND LOWER(d.original_db) = LOWER(SUBSTRING(db.name, 6, 15)) ".
        "AND db.db_id = dx.db_id ".
        "AND dx.version = \"legacy_annotation_database\" ".
    "AND d.id = tl.db_taxonl_id ".
    "AND tl.taxon_uid = t.uid ";

    return $self->_get_results($query);
}

sub get_db_data_info_from_gene_id_check_all{
    my($self, $gene_id, $organism) = @_;

    my $query;

    my $select = "SELECT LOWER(d.original_db), o.common_name, o.organism_id, t.kingdom, t.intermediate_rank_1 ";
    my $from = "FROM $organism..feature f1, $organism..organism o, $organism..organism_dbxref od, $organism..dbxref dx, $organism..feature_dbxref fd, $organism..dbxref x1, $organism..db db, common..db_data1 d, common..taxon_link1 tl, common..taxon t ";
    my $where = "WHERE f1.feature_id = fd.feature_id ".
        "AND fd.dbxref_id = x1.dbxref_id ".
        "AND x1.version = \"locus\" ".
        "AND x1.accession = \"$gene_id\" ".
        "AND f1.organism_id = o.organism_id ".
        "AND o.organism_id = od.organism_id ".
        "AND od.dbxref_id = dx.dbxref_id ".
        "AND LOWER(d.original_db) = LOWER(SUBSTRING(db.name, 6, 15)) ".
        "AND db.db_id = dx.db_id ".
        "AND dx.version = \"legacy_annotation_database\" ".
        "AND d.id = tl.db_taxonl_id ".
        "AND tl.taxon_uid = t.uid ";

    $query .= $select;
    $query .= $from;
    $query .= $where;

    return $self->_get_results($query);
}

sub get_feature_id_from_gene_id {
    my($self, $gene_id, $type) = @_;

    $type = "transcript" unless defined $type;
    my @transcript_cv_id = $self->get_cv_term_id($type);

    my $query = "SELECT f.feature_id ".
    "FROM feature f, feature_dbxref fd, dbxref x1 ".
    "WHERE f.type_id = $transcript_cv_id[0][0] ".
    "AND f.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = x1.dbxref_id ".
    "AND x1.version = \"locus\" ".
    "AND x1.accession = \"$gene_id\" ";

    return $self->_get_results($query);
}

sub get_gene_id_to_protein_info {
    my($self, $gene_id) = @_;

    my @protein_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @cds_cv_id = $self->get_cv_term_id('CDS');
    my @transcript_cv_id = $self->get_cv_term_id('transcript');

    my $query = "SELECT f1.seqlen, f1.feature_id, f1.residues, f2.feature_id ".
    "FROM feature f1, feature f2, feature f3, feature_relationship fr1, feature_relationship fr2, feature_dbxref d, dbxref x ".
    "WHERE f1.type_id = $protein_cv_id[0][0] ".
    "AND f2.type_id = $cds_cv_id[0][0] ".
    "AND f3.type_id = $transcript_cv_id[0][0] ".
    "AND fr1.subject_id = f1.feature_id ".
    "AND fr1.object_id = f2.feature_id ".
    "AND fr2.subject_id = f2.feature_id ".
    "AND fr2.object_id = f3.feature_id ".
    "AND f3.feature_id = d.feature_id ".
    "AND d.dbxref_id = x.dbxref_id ".
    "AND x.version = \"locus\" ".
    "AND x.accession = \"$gene_id\" ";

    return $self->_get_results($query);
}

sub get_org_db_org_name_to_cv_name{
    my ($self, $cv_name) = @_;
   
    my $query = "select LOWER(SUBSTRING(db.name, 6, 15)), o.common_name ".
	"from feature f, cvterm c, db, organism o, dbxref dx, organism_dbxref od ".
	"where c.name = \"$cv_name\" ".
	"and f.type_id = c.cvterm_id ".
	"and f.organism_id = o.organism_id ".
	"and o.organism_id = od.organism_id ".
	"and od.dbxref_id = dx.dbxref_id ".
	"and dx.db_id = db.db_id ".
	"and dx.version = \"legacy_annotation_database\" ".
 	"group by db.name, o.common_name";

    
    my @orgs = $self->_get_results($query);

    return \@orgs;
}

sub get_ori_db_to_epitope_info {
     my ($self , $ori_db) = @_;
    my @epitope_cv_id = $self->get_cv_term_id('epiPEP');
    my @results = ();
    my @ori_dbs = split (',', $ori_db) if defined $ori_db;
    my %db_hash = ();
    foreach my $db (@ori_dbs){
	$db_hash{$db} = 1 if $db ne '';
    }
    
    return \@results if scalar @epitope_cv_id == 0; 
    # mapping gene feature_id to epitope feature_ids
    my $query = "SELECT f2.feature_id as epi_pep_id, f2.uniquename , fl.fmin as end5, fl.fmax as end3, f2.residues as sequence, cm.ori_db, cm.locus, cm.com_name, cm.organism_name "
	. "FROM feature f, feature_relationship fr, feature f2, featureloc fl, cm_gene cm "
	. "WHERE f.feature_id = fr.object_id "
	. "AND fr.subject_id = f2.feature_id "
	. "AND f2.type_id = $epitope_cv_id[0][0] "
	. "AND f2.feature_id = fl.feature_id "
	. "AND f.feature_id = cm.polypeptide_id order by cm.organism_name";
    my @epitopes = $self->_get_results($query);

    my $k = 0;
    for (my $i=0; $i<scalar @epitopes; $i++){
	if (defined $ori_db){
	    next unless $db_hash{$epitopes[$i][5]};
	}
	
	 my $info_query = "SELECT c.name, fp.value FROM cvterm c, feature f, featureprop fp "
	     . "WHERE f.feature_id = fp.feature_id "
	     . "AND f.feature_id = $epitopes[$i][0] "
	     . "AND fp.type_id = c.cvterm_id " ;

	 my $info_query_results = $self->_get_results_ref($info_query);
	 my $nr = scalar(@$info_query_results);
	 my $info_hash = {};
	 for(my $r = 0;$r < $nr; $r++) {
	     $info_hash->{$info_query_results->[$r]->[0]} = $info_query_results->[$r]->[1];   
	     #print STDERR "field=$info_query_results->[$r]->[0], value=$info_query_results->[$r]->[1] \n"
	 }

	 my $iedb_query = "SELECT dx.accession as IEDB_ID "
	     . "FROM dbxref dx, feature_dbxref fd, db d "
	     . "WHERE fd.feature_id = $epitopes[$i][0] and fd.is_current =1 "
	     . "AND fd.dbxref_id = dx.dbxref_id and dx.db_id = d.db_id and d.name = \'IEDB ID\'";
	 my @iedb_ids = $self->_get_results($iedb_query);

	 $results[$k][0] = $epitopes[$i][8];   #organism_name
         $results[$k][1] = $info_hash->{'Epitope Name'}; 
	 $results[$k][2] = "$epitopes[$i][2] - $epitopes[$i][3]"; # coords
	 $results[$k][3] = $epitopes[$i][4]; # sequence
	 $results[$k][4] = $info_hash->{'PMID'}; #PMID
	 $results[$k][5] = $iedb_ids[0][0];  #IEDB_ID
  	 $results[$k][6] = $epitopes[$i][6]; # locus
       	 $results[$k][7] = $epitopes[$i][7];  #com_name
	 $results[$k][8] = $info_hash->{'comment'};  #curation comment
	 $results[$k][9] = $info_hash->{'Assay Group'};  #assay group
	 $results[$k][10] = $info_hash->{'Assay Type'};  #assay type
	 $results[$k][11] = $info_hash->{'MHC Allele'};  #mhc_allele
	 $results[$k][12] = $info_hash->{'MHC Qualitative Binding Assay Result'}; #mhc_quality

	 #print STDERR "k = $k: epitope_name=$info_hash->{'Epitope Name'}, PMID=$results[$k][4] \n";	
	$k++;
    }
    return \@results;
}


sub get_gene_id_to_epitope_info {
    my ($self, $gene_id) = @_;
    my @gene_feature_id = $self->get_feature_id_from_gene_id($gene_id,"polypeptide");

    my @epitope_cv_id = $self->get_cv_term_id('epiPEP');
    my @results = ();

    return \@results if scalar @epitope_cv_id == 0; 
    # mapping gene feature_id to epitope feature_ids
    my $query = "SELECT f2.feature_id, f2.uniquename, fl.fmin as end5, fl.fmax as end3, f2.residues as sequence "
	. "FROM feature f, feature_relationship fr, feature f2, featureloc fl "
	. "WHERE f.feature_id = $gene_feature_id[0][0] "
	. "AND f.feature_id = fr.object_id "
	. "AND fr.subject_id = f2.feature_id "
	. "AND f2.type_id = $epitope_cv_id[0][0] "
	. "AND f2.feature_id = fl.feature_id ";

    #print STDERR "Epitope query: $query \n";

    my @epitopes =  $self->_get_results($query);
    
    #print STDERR "Number of epitopes: " . scalar @epitopes . "\n"; 
    for (my $i=0; $i<scalar @epitopes; $i++) {
	 my $info_query = "SELECT c.name, fp.value FROM cvterm c, feature f, featureprop fp "
	     . "WHERE f.feature_id = fp.feature_id "
	     . "AND f.feature_id = $epitopes[$i][0] "
	     . "AND fp.type_id = c.cvterm_id " ;

	 my $info_query_results = $self->_get_results_ref($info_query);
	 my $nr = scalar(@$info_query_results);
	 my $info_hash = {};
	 for(my $r = 0;$r < $nr; $r++) {
	     $info_hash->{$info_query_results->[$r]->[0]} = $info_query_results->[$r]->[1];   
	     #print STDERR "field=$info_query_results->[$r]->[0], value=$info_query_results->[$r]->[1] \n"
	 }

	 my $iedb_query = "SELECT dx.accession as IEDB_ID "
	     . "FROM dbxref dx, feature_dbxref fd, db d "
	     . "WHERE fd.feature_id = $epitopes[$i][0] and fd.is_current =1 "
	     . "AND fd.dbxref_id = dx.dbxref_id and dx.db_id = d.db_id and d.name = \'IEDB ID\'";
	 my @iedb_ids = $self->_get_results($iedb_query);

	 $results[$i][0] = $info_hash->{'Epitope Name'};
	 $results[$i][1] = $epitopes[$i][2]; # end5
	 $results[$i][2] = $epitopes[$i][3]; # end3
	 $results[$i][3] = $epitopes[$i][4]; # sequence
	 $results[$i][4] = $info_hash->{'PMID'}; #PMID
	 $results[$i][5] = $iedb_ids[0][0];  #IEDB_ID
	 $results[$i][6] = $info_hash->{'comment'};  #comment
	 $results[$i][7] = $info_hash->{'Assay Group'};  #assay group
	 $results[$i][8] = $info_hash->{'Assay Type'};  #assay type
	 $results[$i][9] = $info_hash->{'MHC Allele'};  #mhc_allele
	 $results[$i][10] = $info_hash->{'MHC Qualitative Binding Assay Result'}; #mhc_quality
	 #print STDERR "comment=$info_hash->{comment}, PMID=$results[$i][4] \n";

    }
    return \@results;
}

sub get_gene_id_to_virulence_info {
    my ($self, $gene_id) = @_;

    my $query = "SELECT g.curation_status, fcp.value "
	. " FROM cm_gene g, cvterm c, feature_cvterm fc, feature_cvtermprop fcp "
	. " WHERE c.name = 'pathogenesis' and c.cvterm_id = fc.cvterm_id and fc.feature_id = g.polypeptide_id "
	. " AND fc.feature_cvterm_id = fcp.feature_cvterm_id and g.locus = \'$gene_id\' ";

    my @virulences = $self->_get_results($query);
    return \@virulences;

}


sub get_ori_db_to_virulence_info {
    my ($self, $ori_db) = @_;
    my @ori_dbs = split (',', $ori_db) if defined $ori_db;
    my $db_names = "";
    foreach my $db (@ori_dbs){
       $db_names .= "'" .$db ."'," if $db ne '';
    }
    $db_names =~ s/,$//;
    my $query = "SELECT g.locus, g.gene_sym, g.com_name, g.organism_name,  g.curation_status, fcp.value "
        . " FROM cm_gene g, cvterm c, feature_cvterm fc, feature_cvtermprop fcp "
        . " WHERE c.name = 'pathogenesis' and c.cvterm_id = fc.cvterm_id and fc.feature_id = g.polypeptide_id " 
    . " AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";
    if ($db_names ne "'all'"){
	$query .= " and g.ori_db in  ( $db_names)";
    }
    $query .= " order by g.organism_name ";
    #print STDERR "virulence query = $query \n";
    my @virulences = $self->_get_results($query);
    return \@virulences;
}


sub get_ori_db_org_name_with_pathogenesis {

    my ($self) = @_;

    my $query = "SELECT DISTINCT d.original_db, g.organism_name "
	. " FROM cm_gene g, cvterm c, feature_cvterm fc, common..db_data1 d "
	. " WHERE c.name = 'pathogenesis' and c.cvterm_id = fc.cvterm_id and fc.feature_id = g.polypeptide_id and d.organism_name = g.organism_name";

    my @virulence_orgs = $self->_get_results($query);
    return \@virulence_orgs;

}

sub get_organism_id {
    my($self, $organism) = @_;
    my $query = "SELECT organism_id ".
    "FROM organism o ".
    "WHERE abbreviation = ? ";

    return $self->_get_results($query,$organism);
}

sub get_analysis_table_dump {
    my($self) = @_;

    my $query = "SELECT analysis_id, name, description, program, programversion, algorithm, sourcename, sourceversion, sourceuri, timeexecuted " .
         "FROM analysis";

    return $self->_get_results_ref($query);
}

sub get_db_to_feature_lookup{
    my($self) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @trans_cv_id = $self->get_cv_term_id('transcript');
    my @cds_cv_id = $self->get_cv_term_id('CDS');
    my @gene_cv_id = $self->get_cv_term_id('gene');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @prod_cv_id = $self->get_cv_term_id('produced_by');
    my @part_cv_id = $self->get_cv_term_id('part_of');

    my $query = "SELECT o.abbreviation,a.uniquename,t.uniquename,c.uniquename,g.uniquename,p.uniquename,dbx.accession ".
    "FROM feature a, feature t, feature c, feature g, feature p, feature_relationship pc, feature_relationship ct, feature_relationship tg, feature_relationship ga, organism o, dbxref dbx ".
    "WHERE p.feature_id = pc.subject_id ".
    "AND c.feature_id = pc.object_id ".
    "AND c.feature_id = ct.subject_id ".
    "AND t.feature_id = ct.object_id ".
    "AND t.feature_id = tg.subject_id ".
    "AND g.feature_id = tg.object_id ".
    "AND g.feature_id = ga.subject_id ".
    "AND a.feature_id = ga.object_id ".
    "AND p.type_id = $prot_cv_id[0][0] ".
    "AND c.type_id = $cds_cv_id[0][0] ".
    "AND t.type_id = $trans_cv_id[0][0] ".
    "AND g.type_id = $gene_cv_id[0][0] ".
    "AND a.type_id = $seq_cv_id[0][0] ".
    "AND pc.type_id = $prod_cv_id[0][0] ".
    "AND ct.type_id = $prod_cv_id[0][0] ".
    "AND tg.type_id = $prod_cv_id[0][0] ".
    "AND ga.type_id = $part_cv_id[0][0] ".
    "AND g.dbxref_id = dbx.dbxref_id ".
    "AND a.organism_id = o.organism_id";

    return $self->_get_results_ref($query);
}

sub get_db_to_transcript_gene_products {
    my($self) = @_;

    my @trans_cv_id = $self->get_cv_term_id('transcript');
    my @gene_prod_cv_id = $self->get_cv_term_id('gene product name');

    my $query = "select trans.uniquename, fp.value as product_name " .
    "from featureprop fp, feature trans " .
    "where trans.type_id = $trans_cv_id[0][0] ".
    "and trans.feature_id = fp.feature_id " .
    "and fp.type_id = $gene_prod_cv_id[0][0] ";

    return $self->_get_results_ref($query);
}

sub get_org_id_to_feature_lookup{
    my($self,$org_id) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @trans_cv_id = $self->get_cv_term_id('transcript');
    my @cds_cv_id = $self->get_cv_term_id('CDS');
    my @gene_cv_id = $self->get_cv_term_id('gene');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @prod_cv_id = $self->get_cv_term_id('produced_by');
    my @part_cv_id = $self->get_cv_term_id('part_of');

    my $query = "SELECT a.uniquename,t.uniquename,c.uniquename,g.uniquename,p.uniquename,dbx.accession ".
    "FROM feature a, feature t, feature c, feature g, feature p, feature_relationship pc, feature_relationship ct, feature_relationship tg, feature_relationship ga, organism o, dbxref dbx ".
    "WHERE p.feature_id = pc.subject_id ".
    "AND c.feature_id = pc.object_id ".
    "AND c.feature_id = ct.subject_id ".
    "AND t.feature_id = ct.object_id ".
    "AND t.feature_id = tg.subject_id ".
    "AND g.feature_id = tg.object_id ".
    "AND g.feature_id = ga.subject_id ".
    "AND a.feature_id = ga.object_id ".
    "AND p.type_id = $prot_cv_id[0][0] ".
    "AND c.type_id = $cds_cv_id[0][0] ".
    "AND t.type_id = $trans_cv_id[0][0] ".
    "AND g.type_id = $gene_cv_id[0][0] ".
    "AND a.type_id = $seq_cv_id[0][0] ".
    "AND pc.type_id = $prod_cv_id[0][0] ".
    "AND ct.type_id = $prod_cv_id[0][0] ".
    "AND tg.type_id = $prod_cv_id[0][0] ".
    "AND ga.type_id = $part_cv_id[0][0] ".
    "AND g.dbxref_id = dbx.dbxref_id ".
    "AND a.organism_id = o.organism_id ".
    "AND o.abbreviation = ? ";

    return $self->_get_results_ref($query,$org_id);
}




sub get_org_id_to_genes{
    my($self, $org_id) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @trans_cv_id = $self->get_cv_term_id('transcript');
    my @cds_cv_id = $self->get_cv_term_id('CDS');
    my @gene_cv_id = $self->get_cv_term_id('gene');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @gene_name_cv_id = $self->get_cv_term_id('gene product name');
    my @prod_cv_id = $self->get_cv_term_id('produced_by');
    my @part_cv_id = $self->get_cv_term_id('part_of');
    my @chrom_cv_id = $self->get_cv_term_id('chromosome');

    my $ischromquery = "SELECT count(*) from featureprop ap where ap.type_id = $chrom_cv_id[0][0] ";

    my @ischrom = $self->_get_results($ischromquery);

    my $query;

    if($ischrom[0][0] > 0){

    $query = "SELECT g.uniquename,t.uniquename,a.uniquename,fl.fmin,fl.fmax,dbx.accession,pr.value,p.uniquename,db.name,o.abbreviation,ap.value ".
    "FROM feature a, feature t, feature c, feature g, feature p, featureloc fl, feature_relationship pc, feature_relationship ct, feature_relationship tg, feature_relationship ga, dbxref dbx, db db, featureprop pr, organism o, featureprop ap ".
    "WHERE p.feature_id = pc.subject_id ".
    "AND c.feature_id = pc.object_id ".
    "AND c.feature_id = ct.subject_id ".
    "AND t.feature_id = ct.object_id ".
    "AND t.feature_id = tg.subject_id ".
    "AND g.feature_id = tg.object_id ".
    "AND g.feature_id = ga.subject_id ".
    "AND a.feature_id = ga.object_id ".
    "AND t.feature_id = fl.feature_id ".
    "AND a.feature_id = fl.srcfeature_id ".
    "AND pc.type_id = $prod_cv_id[0][0] ".
    "AND ct.type_id = $prod_cv_id[0][0] ".
    "AND tg.type_id = $prod_cv_id[0][0] ".
    "AND ga.type_id = $part_cv_id[0][0] ".
    "AND p.type_id = $prot_cv_id[0][0] ".
    "AND c.type_id = $cds_cv_id[0][0] ".
    "AND t.type_id = $trans_cv_id[0][0] ".
    "AND g.type_id = $gene_cv_id[0][0] ".
    "AND a.type_id = $seq_cv_id[0][0] ".
    "AND t.dbxref_id = dbx.dbxref_id ".
    "AND dbx.db_id = db.db_id ".
    "AND t.feature_id = pr.feature_id ".
    "AND pr.type_id = $gene_name_cv_id[0][0] ".
    "AND ap.type_id = $chrom_cv_id[0][0] ".
    "AND a.feature_id = ap.feature_id ".
    "AND a.organism_id = o.organism_id ".
    "AND o.abbreviation = ? ";
    }
    else{
    $query = "SELECT g.uniquename,t.uniquename,a.uniquename,fl.fmin,fl.fmax,dbx.accession,pr.value,p.uniquename,db.name,o.abbreviation,0 ".
    "FROM feature a, feature t, feature c, feature g, feature p, featureloc fl, feature_relationship pc, feature_relationship ct, feature_relationship tg, feature_relationship ga, dbxref dbx, db db, featureprop pr, organism o ".
    "WHERE p.feature_id = pc.subject_id ".
    "AND c.feature_id = pc.object_id ".
    "AND c.feature_id = ct.subject_id ".
    "AND t.feature_id = ct.object_id ".
    "AND t.feature_id = tg.subject_id ".
    "AND g.feature_id = tg.object_id ".
    "AND g.feature_id = ga.subject_id ".
    "AND a.feature_id = ga.object_id ".
    "AND t.feature_id = fl.feature_id ".
    "AND a.feature_id = fl.srcfeature_id ".
    "AND pc.type_id = $prod_cv_id[0][0] ".
    "AND ct.type_id = $prod_cv_id[0][0] ".
    "AND tg.type_id = $prod_cv_id[0][0] ".
    "AND ga.type_id = $part_cv_id[0][0] ".
    "AND p.type_id = $prot_cv_id[0][0] ".
    "AND c.type_id = $cds_cv_id[0][0] ".
    "AND t.type_id = $trans_cv_id[0][0] ".
    "AND g.type_id = $gene_cv_id[0][0] ".
    "AND a.type_id = $seq_cv_id[0][0] ".
    "AND t.dbxref_id = dbx.dbxref_id ".
    "AND dbx.db_id = db.db_id ".
    "AND t.feature_id = pr.feature_id ".
    "AND pr.type_id = $gene_name_cv_id[0][0] ".
    "AND a.organism_id = o.organism_id ".
    "AND o.abbreviation = ? "
    }

    return $self->_get_results_refmod($query,
                    sub {
                        my $aref = shift;
                        my ($db_acc) = ($aref->[5] =~ /(\w+)\:/);
                        $db_acc = $aref->[5] if($db_acc eq "");
                        $aref->[5] = $db_acc;
                        my ($dbname) = ($aref->[8] =~ /\:(.+)/);
                        $aref->[8] = $dbname;
                    },
                        $org_id);
}

sub get_org_id_to_exons{
    my($self, $org_id) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @trans_cv_id = $self->get_cv_term_id('transcript');
    my @cds_cv_id = $self->get_cv_term_id('CDS');
    my @gene_cv_id = $self->get_cv_term_id('gene');
    my @exon_cv_id = $self->get_cv_term_id('exon');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @gene_name_cv_id = $self->get_cv_term_id('gene product name');
    my @prod_cv_id = $self->get_cv_term_id('produced_by');
    my @part_cv_id = $self->get_cv_term_id('part_of');
    my @chrom_cv_id = $self->get_cv_term_id('chromosome');

    my $ischromquery = "SELECT count(*) from featureprop ap where ap.type_id = $chrom_cv_id[0][0] ";

    my @ischrom = $self->_get_results($ischromquery);

    my $query;

    if($ischrom[0][0] > 0){

    $query = "SELECT g.uniquename,t.uniquename,e.uniquename,a.uniquename,fl.fmin,fl.fmax,dbx.accession,pr.value,p.uniquename,db.name,o.abbreviation,ap.value ".
    "FROM feature a, feature t, feature c, feature g, feature p, feature e, featureloc fl, feature_relationship pc, feature_relationship ct, feature_relationship tg, feature_relationship ga, feature_relationship et, dbxref dbx, db db, featureprop pr, organism o, featureprop ap ".
    "WHERE p.feature_id = pc.subject_id ".
    "AND c.feature_id = pc.object_id ".
    "AND c.feature_id = ct.subject_id ".
    "AND t.feature_id = ct.object_id ".
    "AND t.feature_id = tg.subject_id ".
    "AND g.feature_id = tg.object_id ".
    "AND g.feature_id = ga.subject_id ".
    "AND a.feature_id = ga.object_id ".
    "AND e.feature_id = fl.feature_id ".
    "AND a.feature_id = fl.srcfeature_id ".
    "AND e.feature_id = et.subject_id ".
    "AND t.feature_id = et.object_id ".
    "AND pc.type_id = $prod_cv_id[0][0] ".
    "AND ct.type_id = $prod_cv_id[0][0] ".
    "AND tg.type_id = $prod_cv_id[0][0] ".
    "AND ga.type_id = $part_cv_id[0][0] ".
    "AND et.type_id = $part_cv_id[0][0] ".
    "AND p.type_id = $prot_cv_id[0][0] ".
    "AND c.type_id = $cds_cv_id[0][0] ".
    "AND t.type_id = $trans_cv_id[0][0] ".
    "AND g.type_id = $gene_cv_id[0][0] ".
    "AND a.type_id = $seq_cv_id[0][0] ".
    "AND e.type_id = $exon_cv_id[0][0] ".
    "AND t.dbxref_id = dbx.dbxref_id ".
    "AND dbx.db_id = db.db_id ".
    "AND t.feature_id = pr.feature_id ".
    "AND pr.type_id = $gene_name_cv_id[0][0] ".
    "AND ap.type_id = $chrom_cv_id[0][0] ".
    "AND a.feature_id = ap.feature_id ".
    "AND a.organism_id = o.organism_id ".
    "AND o.abbreviation = ? ";
    }
    else{
    $query = "SELECT g.uniquename,t.uniquename,e.uniquename,a.uniquename,fl.fmin,fl.fmax,dbx.accession,pr.value,p.uniquename,db.name,o.abbreviation,0 ".
    "FROM feature a, feature t, feature c, feature g, feature p, featureloc fl, feature_relationship pc, feature_relationship ct, feature_relationship tg, feature_relationship ga, feature_relationship et, dbxref dbx, db db, featureprop pr, organism o ".
    "WHERE p.feature_id = pc.subject_id ".
    "AND c.feature_id = pc.object_id ".
    "AND c.feature_id = ct.subject_id ".
    "AND t.feature_id = ct.object_id ".
    "AND t.feature_id = tg.subject_id ".
    "AND g.feature_id = tg.object_id ".
    "AND g.feature_id = ga.subject_id ".
    "AND a.feature_id = ga.object_id ".
    "AND e.feature_id = fl.feature_id ".
    "AND a.feature_id = fl.srcfeature_id ".
    "AND e.feature_id = et.subject_id ".
    "AND t.feature_id = et.object_id ".
    "AND pc.type_id = $prod_cv_id[0][0] ".
    "AND ct.type_id = $prod_cv_id[0][0] ".
    "AND tg.type_id = $prod_cv_id[0][0] ".
    "AND ga.type_id = $part_cv_id[0][0] ".
    "AND et.type_id = $part_cv_id[0][0] ".
    "AND p.type_id = $prot_cv_id[0][0] ".
    "AND c.type_id = $cds_cv_id[0][0] ".
    "AND t.type_id = $trans_cv_id[0][0] ".
    "AND g.type_id = $gene_cv_id[0][0] ".
    "AND a.type_id = $seq_cv_id[0][0] ".
    "AND e.type_id = $exon_cv_id[0][0] ".
    "AND t.dbxref_id = dbx.dbxref_id ".
    "AND dbx.db_id = db.db_id ".
    "AND t.feature_id = pr.feature_id ".
    "AND pr.type_id = $gene_name_cv_id[0][0] ".
    "AND a.organism_id = o.organism_id ".
    "AND o.abbreviation = ? "
    }

    return $self->_get_results_refmod($query,
                    sub {
                        my $aref = shift;
                        my ($db_acc) = ($aref->[5] =~ /(\w+)\:/);
                        $db_acc = $aref->[5] if($db_acc eq "");
                        $aref->[5] = $db_acc;
                        my ($dbname) = ($aref->[8] =~ /\:(.+)/);
                        $aref->[8] = $dbname;
                    },
                        $org_id);
}

sub get_org_id_to_seq_exons {
    my($self, $org_id) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @exon_cv_id = $self->get_cv_term_id('exon');

    my $query = "SELECT a.uniquename, count(e.feature_id) ".
    "FROM feature a, feature e, featureloc fl, organism o ".
    "WHERE a.type_id = $seq_cv_id[0][0] ".
    "AND a.organism_id = o.organism_id ".
    "AND o.abbreviation= ? ".
    "AND e.type_id = $exon_cv_id[0][0] ".
    "AND a.feature_id = fl.srcfeature_id ".
    "AND e.feature_id = fl.feature_id ".
    "AND fl.rank = 0 ".
    "GROUP BY a.uniquename ";

    return $self->_get_results_ref($query,$org_id);
}


sub get_curation_to_asm_feature_info {
    my($self, $curation_type, $ori_list)=@_;

    my($query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @assignby_cv_id = $self->get_cv_term_id('completed_by');


    if($curation_type eq 'manual'){
        $query = "SELECT f.feature_id ".
                "FROM featureprop fp, feature f ".
                "WHERE f.type_id = $transcript_cv_id[0][0] ".
                "AND fp.feature_id = f.feature_id ".
                "AND fp.type_id = $assignby_cv_id[0][0] ".
                "AND fp.value NOT IN ('autoAnno', 'mummer_r', 'pamadeo', 'egc', 'egc2', 'autoBYOB') ".
                "ORDER BY f.feature_id ";
    }elsif($curation_type eq 'autoAnno'){
        $query = "SELECT f.feature_id ".
                "FROM featureprop fp, feature f ".
                "WHERE f.type_id = $transcript_cv_id[0][0] ".
                "AND fp.feature_id = f.feature_id ".
                "AND fp.type_id = $assignby_cv_id[0][0] ".
                "AND fp.value IN ('autoAnno', 'mummer_r', 'pamadeo', 'egc', 'egc2', 'autoBYOB') ".
                "UNION ".
                "SELECT f.feature_id ".
                "FROM feature f ".
                "WHERE f.type_id = $transcript_cv_id[0][0] ".
                "AND f.feature_id NOT IN ".
                "(SELECT fp.feature_id FROM featureprop fp WHERE fp.type_id = $assignby_cv_id[0][0])";
    }else{
        $query = "SELECT f.feature_id ".
                "FROM featureprop fp, feature f ".
                "WHERE f.type_id = $transcript_cv_id[0][0] ".
                "AND fp.feature_id = f.feature_id ".
                "AND fp.type_id = $assignby_cv_id[0][0] ".
                "AND fp.value = '$curation_type' ".
                "ORDER BY f.feature_id ";

    }


    my @results = $self->_get_results($query);



    my $fnamelookup = $self->get_feature_id_to_gene_name_lookup;
    my $fposlookup = $self->get_feature_id_to_gene_pos_lookup;
    my $org_lookup = $self->get_org_id_to_org_name_lookup();
    my $oridb_lookup = $self->get_ori_db_org_id_lookup();
    my $ec_hashref = &make_ec_hash($self);

    my @return_result;
    my $prev_locus = "";


    my $j = 0;
    for (my $i=0; $i<scalar @results; $i++) {
        next if ($results[$i][0] eq $prev_locus);
        next if (!$fnamelookup->{$results[$i][0]}->[1]);


        $prev_locus = $results[$i][0];
        my $org_name ="$oridb_lookup->{$fnamelookup->{$results[$i][0]}->[4]}";
        if ($ori_list && ($ori_list ne $org_name)) {
                next;
        }



        $return_result[$j][0] = $fnamelookup->{$results[$i][0]}->[1];
        $return_result[$j][1] = $fnamelookup->{$results[$i][0]}->[1];

        # EC
        $return_result[$j][2] = $ec_hashref->{$fnamelookup->{$results[$i][0]}->[1]};
        $return_result[$j][3] = $fnamelookup->{$results[$i][0]}->[2];
        $return_result[$j][4] = $fnamelookup->{$results[$i][0]}->[3];
        $return_result[$j][5] = $org_lookup->{$fnamelookup->{$results[$i][0]}->[4]};

        if($fposlookup->{$results[$i][0]}->[3] == 1){
                $return_result[$j][6] = ($fposlookup->{$results[$i][0]}->[1] + 1);
                $return_result[$j][7] = $fposlookup->{$results[$i][0]}->[2];
        }else{
                $return_result[$j][6] = $fposlookup->{$results[$i][0]}->[2];
                $return_result[$j][7] = ($fposlookup->{$results[$i][0]}->[1] + 1);
        }
        $return_result[$j][8] = $fposlookup->{$results[$i][0]}->[4];
        $j++;
    }
    return(sort {$a->[6] <=> $b->[6]} @return_result);

}



sub get_ori_db_to_curation{
    my($self, $ori_db)=@_;
    my($query);

    my $orgs = $self->get_ori_db_org_id_lookup;
    my $org_id = $orgs->{$ori_db};

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @assignby_cv_id = $self->get_cv_term_id('completed_by');

    $query = "SELECT x.accession, fp.value ".
        "FROM featureprop fp, feature f, feature_dbxref fd, dbxref x ".
        "WHERE f.type_id = $transcript_cv_id[0][0] ".
        "AND f.feature_id = fd.feature_id ".
        "AND fd.dbxref_id = x.dbxref_id ".
        "AND x.version = \"locus\" ".
	"AND f.organism_id = ? ".
        "AND fp.feature_id = f.feature_id ".
        "AND fp.type_id = $assignby_cv_id[0][0] ";

    my @results = $self->_get_results($query, $org_id);
    return(@results);
}


sub get_gene_id_to_curation{
    my($self, $gene_id)=@_;
    my($query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @assignby_cv_id = $self->get_cv_term_id('completed_by');

    $query = "SELECT fp.value ".
        "FROM featureprop fp, feature f, feature_dbxref fd, dbxref x ".
        "WHERE f.type_id = $transcript_cv_id[0][0] ".
        "AND f.feature_id = fd.feature_id ".
        "AND fd.dbxref_id = x.dbxref_id ".
        "AND x.version = \"locus\" ".
        "AND x.accession = ? ".
        "AND fp.feature_id = f.feature_id ".
        "AND fp.type_id = $assignby_cv_id[0][0] ";

    my @results = $self->_get_results($query, $gene_id);
    return(@results);
}



sub get_db_to_assemblies{
    my($self,$doGetResidues,$db) = @_;

    my $addquery="";
    my @seq_cv_id = $self->get_cv_term_id('assembly');

    if($doGetResidues){
    $addquery = ",a.residues";
    }

    my @chrom_cv_id = $self->get_cv_term_id('chromosome');

    my $ischromquery = "SELECT count(*) from featureprop ap where ap.type_id = $chrom_cv_id[0][0] ";

    my @ischrom = $self->_get_results($ischromquery);

    my $query;

    if($ischrom[0][0] > 0){
    $query = "SELECT a.uniquename,a.seqlen,o.abbreviation,ap.value$addquery ".
        "FROM feature a, organism o, featureprop ap ".
        "WHERE ap.type_id = $chrom_cv_id[0][0] ".
        "AND a.feature_id = ap.feature_id ".
        "AND a.type_id = $seq_cv_id[0][0] ".
        "AND a.organism_id = o.organism_id";
    }
    else{
    $query = "SELECT a.uniquename,a.seqlen,o.abbreviation,0$addquery ".
        "FROM feature a, organism o ".
        "WHERE a.type_id = $seq_cv_id[0][0] ".
        "AND a.organism_id = o.organism_id";
    }
    return  $self->_get_results_ref($query);
}

sub get_db_to_organisms{
    my($self,$db) = @_;
    my $query = "SELECT o.common_name,o.abbreviation,db.name,o.genus,o.species ".
    "FROM organism o ".
    "LEFT JOIN organism_dbxref odb ON (o.organism_id = odb.organism_id) ".
    "LEFT JOIN dbxref dbx ON (odb.dbxref_id = dbx.dbxref_id) ".
    "LEFT JOIN db db ON (dbx.db_id = db.db_id) ";

    return  $self->_get_results_ref($query);
}

sub get_seq_id_to_feature_lookup{
    my($self,$seq_id) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @trans_cv_id = $self->get_cv_term_id('transcript');
    my @cds_cv_id = $self->get_cv_term_id('CDS');
    my @gene_cv_id = $self->get_cv_term_id('gene');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @prod_cv_id = $self->get_cv_term_id('produced_by');
    my @part_cv_id = $self->get_cv_term_id('part_of');

    my $query = "SELECT a.uniquename,t.uniquename,c.uniquename,g.uniquename,p.uniquename,dbx.accession ".
    "FROM feature a, feature t, feature c, feature g, feature p, feature_relationship pc, feature_relationship ct, feature_relationship tg, feature_relationship ga, dbxref dbx ".
    "WHERE p.feature_id = pc.subject_id ".
    "AND c.feature_id = pc.object_id ".
    "AND c.feature_id = ct.subject_id ".
    "AND t.feature_id = ct.object_id ".
    "AND t.feature_id = tg.subject_id ".
    "AND g.feature_id = tg.object_id ".
    "AND g.feature_id = ga.subject_id ".
    "AND a.feature_id = ga.object_id ".
    "AND p.type_id = $prot_cv_id[0][0] ".
    "AND c.type_id = $cds_cv_id[0][0] ".
    "AND t.type_id = $trans_cv_id[0][0] ".
    "AND g.type_id = $gene_cv_id[0][0] ".
    "AND a.type_id = $seq_cv_id[0][0] ".
    "AND dbx.dbxref_id = g.dbxref_id ".
    "AND pc.type_id = $prod_cv_id[0][0] ".
    "AND ct.type_id = $prod_cv_id[0][0] ".
    "AND tg.type_id = $prod_cv_id[0][0] ".
    "AND ga.type_id = $part_cv_id[0][0] ".
    "AND a.uniquename = ? ";

    return  $self->_get_results_ref($query, $seq_id);

}



sub get_db_seq_ids_to_organism_ids{
    my($self) = @_;
    my @seq_cv_id = $self->get_cv_term_id('assembly');

    my $query = "SELECT f.uniquename, o.abbreviation ".
    "FROM feature f, organism o ".
    "WHERE f.type_id = $seq_cv_id[0][0] ".
    "AND f.organism_id = o.organism_id";

    return $self->_get_results_ref($query);
}

sub get_seq_id_to_matching_regions{
    my $self = shift;

    my($param) = do_params(\@_,
            [query_seq_id => '',
                match_seq_id => '']
            );

    my($ref_asmbl, $match_asmbl);

    $ref_asmbl = $param->{'query_seq_id'};
    $match_asmbl = $param->{'match_seq_id'};

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @region_cv_id = $self->get_cv_term_id('alignment_hsp');

    my $query = "SELECT a1.uniquename,afl1.fmin,afl1.fmax,afl2.fmin,afl2.fmax,a2.uniquename,o1.abbreviation,o2.abbreviation ".
    "FROM feature a1, feature a2, feature f, featureloc afl1, featureloc afl2, analysisfeature af, analysis a, organism o1, organism o2 ".
    "WHERE a1.feature_id = afl1.srcfeature_id ".
    "AND a2.feature_id = afl2.srcfeature_id ".
    "AND f.feature_id = afl1.feature_id ".
    "AND f.feature_id = afl2.feature_id ".
    "AND f.type_id = $region_cv_id[0][0] ".
    "AND a1.type_id = $seq_cv_id[0][0] ".
    "AND a2.type_id = $seq_cv_id[0][0] ".
    "AND f.feature_id = af.feature_id ".
    "AND af.analysis_id = a.analysis_id ".
    "AND a.program = 'region' ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "and o1.organism_id = a1.organism_id ".
    "and o2.organism_id = a2.organism_id ".
    "and afl1.rank = 1 ".
    "and afl2.rank = 0 ".
    "AND a1.uniquename = ? ";
    $query .= "AND a2.uniquename = '$match_asmbl' " if($match_asmbl ne "");

     return  $self->_get_results_ref($query, $ref_asmbl);

}

sub get_org_id_to_matching_regions{
    my($self,$ref_org,$match_org) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @region_cv_id = $self->get_cv_term_id('alignment_hsp');

    my $query = "SELECT a1.uniquename,afl1.fmin,afl1.fmax,afl2.fmin,afl2.fmax,a2.uniquename ".
    "FROM feature a1, feature a2, feature f, featureloc afl1, featureloc afl2,organism o1, organism o2, analysisfeature af, analysis a ".
    "WHERE a1.feature_id = afl1.srcfeature_id ".
    "AND a2.feature_id = afl2.srcfeature_id ".
    "AND f.feature_id = afl1.feature_id ".
    "AND f.feature_id = afl2.feature_id ".
    "AND f.type_id = $region_cv_id[0][0] ".
    "AND a1.type_id = $seq_cv_id[0][0] ".
    "AND a2.type_id = $seq_cv_id[0][0] ".
    "AND f.feature_id = af.feature_id ".
    "AND af.analysis_id = a.analysis_id ".
    "AND a.program = 'region' ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND a1.organism_id = o1.organism_id ".
    "AND a2.organism_id = o2.organism_id ".
    "and afl1.rank = 1 ".
    "and afl2.rank = 0 ".
    "AND o1.abbreviation = ? ";
    $query .= "AND o2.abbreviation = '$match_org' " if($match_org ne "");

     return  $self->_get_results_ref($query, $ref_org);

}


sub get_org_id_to_promermatches {
    my($self,$ref_org,$match_org) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @pe_cv_id = $self->get_cv_term_id('alignment_hsp');

    my $query = "select q.uniquename,s.uniquename,oq.abbreviation,os.abbreviation,flq.fmin,flq.fmax,fls.fmin,fls.fmax ".
    "FROM feature q, feature s, feature p, featureloc flq, featureloc fls, analysisfeature af, analysis a, organism oq, organism os ".
    "WHERE q.feature_id = flq.srcfeature_id ".
    "AND q.type_id = $seq_cv_id[0][0] ".
    "AND s.feature_id = fls.srcfeature_id ".
    "AND s.type_id = $seq_cv_id[0][0] ".
    "and p.feature_id = flq.feature_id ".
    "and p.feature_id = fls.feature_id ".
    "and p.feature_id = af.feature_id ".
    "and af.analysis_id = a.analysis_id ".
    "and q.organism_id = oq.organism_id ".
    "and s.organism_id = os.organism_id ".
    "and a.program = 'PROmer' ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "and oq.abbreviation = ? ";

    $query .= "AND os.abbreviation = '$match_org' " if($match_org ne "");

    return  $self->_get_results_ref($query, $ref_org);
}


sub get_org_id_to_nucmermatches {
    my($self,$ref_org,$match_org) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @pe_cv_id = $self->get_cv_term_id('alignment_hsp');

    my $query = "select q.uniquename,s.uniquename,oq.abbreviation,os.abbreviation,flq.fmin,flq.fmax,fls.fmin,fls.fmax ".
    "FROM feature q, feature s, feature p, featureloc flq, featureloc fls, analysisfeature af, analysis a, organism oq, organism os ".
    "WHERE q.feature_id = flq.srcfeature_id ".
    "AND q.type_id = $seq_cv_id[0][0] ".
    "AND s.feature_id = fls.srcfeature_id ".
    "AND s.type_id = $seq_cv_id[0][0] ".
    "and p.feature_id = flq.feature_id ".
    "and p.feature_id = fls.feature_id ".
    "and p.feature_id = af.feature_id ".
    "and af.analysis_id = a.analysis_id ".
    "and q.organism_id = oq.organism_id ".
    "and s.organism_id = os.organism_id ".
    "and a.program = 'NUCmer' ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "and oq.abbreviation = ? ";

    $query .= "AND os.abbreviation = '$match_org' " if($match_org ne "");

    return  $self->_get_results_ref($query, $ref_org);
}

sub get_seq_id_to_promermatches {
    my $self = shift;
    my($param) = do_params(\@_,
            [query_seq_id => '',
                match_seq_id => '']
            );

    my($ref_asmbl, $match_asmbl);

    $ref_asmbl = $param->{'query_seq_id'};
    $match_asmbl = $param->{'match_seq_id'};

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @pe_cv_id = $self->get_cv_term_id('alignment_hsp');

    my $query = "select q.uniquename,s.uniquename,oq.abbreviation,os.abbreviation,flq.fmin,flq.fmax,fls.fmin,fls.fmax ".
    "FROM feature q, feature s, feature p, featureloc flq, featureloc fls, analysisfeature af, analysis a, organism oq, organism os ".
    "WHERE q.feature_id = flq.srcfeature_id ".
    "AND q.type_id = $seq_cv_id[0][0] ".
    "AND s.feature_id = fls.srcfeature_id ".
    "AND s.type_id = $seq_cv_id[0][0] ".
    "and p.feature_id = flq.feature_id ".
    "and p.feature_id = fls.feature_id ".
    "and p.feature_id = af.feature_id ".
    "and af.analysis_id = a.analysis_id ".
    "and q.organism_id = oq.organism_id ".
    "and s.organism_id = os.organism_id ".
    "and a.program = 'PROmer' ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "and q.uniquename = ? ";

    $query .= "AND s.uniquename = '$match_asmbl' " if($match_asmbl ne "");

    return  $self->_get_results_ref($query, $ref_asmbl);
}


sub get_seq_id_to_nucmermatches {
    my $self = shift;

    my($param) = do_params(\@_,
            [query_seq_id => '',
                match_seq_id => '']
            );

    my $ref_asmbl = $param->{'query_seq_id'};
    my $match_asmbl = $param->{'match_seq_id'};

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @pe_cv_id = $self->get_cv_term_id('alignment_hsp');

    my $query = "select q.uniquename,s.uniquename,oq.abbreviation,os.abbreviation,flq.fmin,flq.fmax,fls.fmin,fls.fmax ".
    "FROM feature q, feature s, feature p, featureloc flq, featureloc fls, analysisfeature af, analysis a, organism oq, organism os ".
    "WHERE q.feature_id = flq.srcfeature_id ".
    "AND q.type_id = $seq_cv_id[0][0] ".
    "AND s.feature_id = fls.srcfeature_id ".
    "AND s.type_id = $seq_cv_id[0][0] ".
    "and p.feature_id = flq.feature_id ".
    "and p.feature_id = fls.feature_id ".
    "and p.feature_id = af.feature_id ".
    "and af.analysis_id = a.analysis_id ".
    "and q.organism_id = oq.organism_id ".
    "and s.organism_id = os.organism_id ".
    "and a.program = 'NUCmer' ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "and q.uniquename = ? ";

    $query .= "AND s.uniquename = '$match_asmbl' " if($match_asmbl ne "");

    return  $self->_get_results_ref($query, $ref_asmbl);
}


sub get_seq_id_to_PEmatches {
    my $self = shift;

    my($param) = do_params(\@_,
            [query_seq_id => '',
                match_seq_id => '',
                analysis_id => '',
                ]
            );

    my $ref_asmbl = $param->{'query_seq_id'};
    my $match_asmbl = $param->{'match_seq_id'};
    my $analysis_id = $param->{'analysis_id'};

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');

    my $query = "SELECT p1.uniquename,p2.uniquename,a1.uniquename,a2.uniquename,pfl1.fmin,pfl1.fmax,pfl2.fmin,pfl2.fmax,pef.rawscore ".
    "FROM feature p1, feature p2, feature a1, feature a2, featureloc pfl1, featureloc pfl2, feature pe, featureloc afl1, featureloc afl2, analysisfeature pef, analysis a ".
    "WHERE pe.feature_id = afl1.feature_id ".
    "AND pe.feature_id = afl2.feature_id ".
    "AND afl1.srcfeature_id = p1.feature_id ".
    "AND afl2.srcfeature_id = p2.feature_id ".
    "AND pfl1.feature_id = p1.feature_id ".
    "AND pfl1.srcfeature_id = a1.feature_id ".
    "AND pfl2.feature_id = p2.feature_id ".
    "AND pfl2.srcfeature_id = a2.feature_id ".

# JC: removed these lines to get query to run faster on "upgraded" Sybase server.
#	"AND p1.type_id = $prot_cv_id[0][0] ".
#	"AND p2.type_id = $prot_cv_id[0][0] ".
#	"AND a1.type_id = $seq_cv_id[0][0] ".

    "AND a2.type_id = $seq_cv_id[0][0] ".
    "AND pe.feature_id = pef.feature_id ".
    "AND afl1.rank = 1 ".
    "AND afl2.rank = 0 ".
        "AND pef.analysis_id = a.analysis_id ".
    (defined($analysis_id) ? "AND a.analysis_id = $analysis_id " : "" ).
    "AND (a.program = 'peffect' OR a.program = 'pe') ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND a1.uniquename = ? ";

    $query .= "AND a2.uniquename = '$match_asmbl' " if($match_asmbl ne "");

    return  $self->_get_results_ref($query, $ref_asmbl);
}

sub get_seq_id_to_promer {
    my $self = shift;
    my($param) = do_params(\@_,
            [query_seq_id => '',
                match_seq_id => '',
                ]
            );

    my $ref_asmbl = $param->{'query_seq_id'};
    my $match_asmbl = $param->{'match_seq_id'};

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @pe_cv_id = $self->get_cv_term_id('alignment_hsp');


    my $query = "SELECT p1.uniquename,p2.uniquename,a1.uniquename,a2.uniquename,pfl1.fmin,pfl1.fmax,pfl2.fmin,pfl2.fmax,pef.rawscore ".
    "FROM feature p1, feature p2, feature a1, feature a2, featureloc pfl1, featureloc pfl2, feature pe, featureloc afl1, featureloc afl2, analysisfeature pef, analysis a ".
    "WHERE pe.feature_id = afl1.feature_id ".
    "AND pe.feature_id = afl2.feature_id ".
    "AND afl1.srcfeature_id = p1.feature_id ".
    "AND afl2.srcfeature_id = p2.feature_id ".
    "AND pfl1.feature_id = p1.feature_id ".
    "AND pfl1.srcfeature_id = a1.feature_id ".
    "AND pfl2.feature_id = p2.feature_id ".
    "AND pfl2.srcfeature_id = a2.feature_id ".
    "AND p1.type_id = $prot_cv_id[0][0] ".
    "AND p2.type_id = $prot_cv_id[0][0] ".
    "AND a1.type_id = $seq_cv_id[0][0] ".
    "AND a2.type_id = $seq_cv_id[0][0] ".
    "AND pe.type_id = $pe_cv_id[0][0] ".
    "AND pe.feature_id = pef.feature_id ".
    "AND afl1.rank = 1 ".
    "AND afl2.rank = 0 ".
        "AND pef.analysis_id = a.analysis_id ".
    "AND a.program = 'PROmer' ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND a1.uniquename = ? ";

    $query .= "AND a2.uniquename = '$match_asmbl' " if($match_asmbl ne "");

    return  $self->_get_results_ref($query, $ref_asmbl);
}

sub get_org_id_to_PEmatches {
    my($self,$ref_org,$match_org,$analysis_id) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');

    my $query = "SELECT p1.uniquename,p2.uniquename,a1.uniquename,a2.uniquename,pfl1.fmin,pfl1.fmax,pfl2.fmin,pfl2.fmax,o2.abbreviation,pef.rawscore ".
    "FROM feature p1, feature p2, feature a1, feature a2, featureloc pfl1, featureloc pfl2, feature pe, featureloc afl1, featureloc afl2, analysisfeature pef, analysis a, organism o1, organism o2 ".
    "WHERE pe.feature_id = afl1.feature_id ".
    "AND pe.feature_id = afl2.feature_id ".
    "AND afl1.srcfeature_id = p1.feature_id ".
    "AND afl2.srcfeature_id = p2.feature_id ".
    "AND pfl1.feature_id = p1.feature_id ".
    "AND pfl1.srcfeature_id = a1.feature_id ".
    "AND pfl2.feature_id = p2.feature_id ".
    "AND pfl2.srcfeature_id = a2.feature_id ".
    "AND p1.type_id = $prot_cv_id[0][0] ".
    "AND p2.type_id = $prot_cv_id[0][0] ".
    "AND a1.type_id = $seq_cv_id[0][0] ".
    "AND a2.type_id = $seq_cv_id[0][0] ".
    "AND pe.feature_id = pef.feature_id ".
    "AND afl1.rank = 1 ".
    "AND afl2.rank = 0 ".
        "AND pef.analysis_id = a.analysis_id ".
    (defined($analysis_id) ? "AND a.analysis_id = $analysis_id " : "" ) .
    "AND (a.program = 'peffect' or a.program = 'pe') ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND o1.organism_id = a1.organism_id ".
    "AND o2.organism_id = a2.organism_id ".
        "AND o1.abbreviation = ? ";

    $query .= "AND o2.abbreviation = '$match_org' " if($match_org ne "");

    return  $self->_get_results_ref($query, $ref_org);
}

sub get_protein_id_to_PEmatches {
    my($self,$protein_id) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @pe_cv_id = $self->get_cv_term_id('match_part', 'SO');

    my $query = "SELECT p1.uniquename,p2.uniquename,a1.uniquename,a2.uniquename,pfl1.fmin,pfl1.fmax,pfl2.fmin,pfl2.fmax,o2.abbreviation,o1.abbreviation,pef.rawscore ".
    "FROM feature p1, feature p2, feature a1, feature a2, featureloc pfl1, featureloc pfl2, feature pe, featureloc afl1, featureloc afl2, analysisfeature pef, analysis a, organism o1, organism o2 ".
    "WHERE pe.feature_id = afl1.feature_id ".
    "AND pe.feature_id = afl2.feature_id ".
    "AND afl1.srcfeature_id = p1.feature_id ".
    "AND afl2.srcfeature_id = p2.feature_id ".
    "AND pfl1.feature_id = p1.feature_id ".
    "AND pfl1.srcfeature_id = a1.feature_id ".
    "AND pfl2.feature_id = p2.feature_id ".
    "AND pfl2.srcfeature_id = a2.feature_id ".
    "AND p1.type_id = $prot_cv_id[0][0] ".
    "AND p2.type_id = $prot_cv_id[0][0] ".
    "AND a1.type_id = $seq_cv_id[0][0] ".
    "AND a2.type_id = $seq_cv_id[0][0] ".
    "AND pe.type_id = $pe_cv_id[0][0] ".
    "AND pe.feature_id = pef.feature_id ".
    "AND afl1.rank = 1 ".
    "AND afl2.rank = 0 ".
        "AND pef.analysis_id = a.analysis_id ".
    "AND (a.program = 'peffect' or a.program = 'pe') ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND o1.organism_id = a1.organism_id ".
    "AND o2.organism_id = a2.organism_id ".
    "AND p1.uniquename = ? ";

    return  $self->_get_results_ref($query, $protein_id);
}

sub get_org_id_to_COGmatches {
    my($self,$ref_org,$match_org,$analysis_id) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @o1_org_id = $self->get_organism_id($ref_org);
    my @o2_org_id = ($match_org ne "") ? $self->get_organism_id($match_org) : undef;

    my $query = "SELECT p1.uniquename,p2.uniquename,a1.uniquename,a2.uniquename,pfl1.fmin,pfl1.fmax,pfl2.fmin,pfl2.fmax,o2.abbreviation ".
    "FROM feature p1, feature p2, feature a1, feature a2, featureloc pfl1, featureloc pfl2, feature cog, featureloc afl1, featureloc afl2, analysisfeature af, analysis a, organism o2 ".
    "WHERE cog.feature_id = afl1.feature_id ".
    "AND cog.feature_id = afl2.feature_id ".
    "AND afl1.srcfeature_id = p1.feature_id ".
    "AND afl2.srcfeature_id = p2.feature_id ".
    "AND pfl1.feature_id = p1.feature_id ".
    "AND pfl1.srcfeature_id = a1.feature_id ".
    "AND pfl2.feature_id = p2.feature_id ".
    "AND pfl2.srcfeature_id = a2.feature_id ".
    "AND p1.type_id = $prot_cv_id[0][0] ".
    "AND p2.type_id = $prot_cv_id[0][0] ".
    "AND a1.type_id = $seq_cv_id[0][0] ".
    "AND a2.type_id = $seq_cv_id[0][0] ".
    "AND cog.feature_id = af.feature_id ".
    "AND p1.feature_id != p2.feature_id ".
        "AND af.analysis_id = a.analysis_id ".
    (defined($analysis_id) ? "AND a.analysis_id = $analysis_id " : "") .
    "AND (a.program = 'COGS' or a.program = 'cogs') ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND a1.organism_id = ? ".
    "AND a2.organism_id = o2.organism_id ";

    $query .= "AND a2.organism_id = $o2_org_id[0][0] " if (@o2_org_id);

    return  $self->_get_results_ref($query, $o1_org_id[0][0]);
}

sub get_seq_id_to_COGmatches {
    my $self = shift;

    my($param) = do_params(\@_,
            [query_seq_id => '',
                match_seq_id => '',
                analysis_id => '',
                ]
            );

    my $ref_asmbl = $param->{'query_seq_id'};
    my $match_asmbl = $param->{'match_seq_id'};
    my $analysis_id = $param->{'analysis_id'};

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');

    my $query = "SELECT p1.uniquename,p2.uniquename,a1.uniquename,a2.uniquename,pfl1.fmin,pfl1.fmax,pfl2.fmin,pfl2.fmax ".
    "FROM feature p1, feature p2, feature a1, feature a2, featureloc pfl1, featureloc pfl2, feature cog, featureloc afl1, featureloc afl2, analysisfeature cf, analysis a ".
    "WHERE cog.feature_id = afl1.feature_id ".
    "AND cog.feature_id = afl2.feature_id ".
    "AND afl1.srcfeature_id = p1.feature_id ".
    "AND afl2.srcfeature_id = p2.feature_id ".
    "AND pfl1.feature_id = p1.feature_id ".
    "AND pfl1.srcfeature_id = a1.feature_id ".
    "AND pfl2.feature_id = p2.feature_id ".
    "AND pfl2.srcfeature_id = a2.feature_id ".
    "AND p1.type_id = $prot_cv_id[0][0] ".
    "AND p2.type_id = $prot_cv_id[0][0] ".
    "AND a1.type_id = $seq_cv_id[0][0] ".
    "AND a2.type_id = $seq_cv_id[0][0] ".
    "AND cog.feature_id = cf.feature_id ".
    "AND p1.feature_id != p2.feature_id ".
        "AND cf.analysis_id = a.analysis_id ".
    (defined($analysis_id) ? "AND a.analysis_id = $analysis_id " : "" ).
    "AND (a.program = 'COGS' OR a.program = 'cogs') ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND a1.uniquename = ? ";

    $query .= "AND a2.uniquename = '$match_asmbl' " if ($match_asmbl ne "");

    return  $self->_get_results_ref($query, $ref_asmbl);
}

sub get_seq_id_to_bitscoreavgs {
    my($self,$ref_asmbl,$match_asmbl) = @_;

    #caculate on the 1,2,3 position avgs on the fly for now until
    #the position avgs are stored in the db.
    #this data is cached anyways so no harm in asking for it multiple times
    my (@ret, @s, $i);
    @ret = $self->get_seq_id_to_blastpmatches($ref_asmbl,$match_asmbl);

    my $hitref;

    for ($i=0; $i<@ret; $i++) {
    my $query = $ret[$i][0];
    my $subject = $ret[$i][1];
    my $bitscoreratio = $ret[$i][7];
    #$hitref->{query}->{subject} = bitscore
    #capture best scoring HSP for any query/subject pair
    if(exists $hitref->{$query}->{$subject}){
        $hitref->{$query}->{$subject} = $bitscoreratio if($bitscoreratio > $hitref->{$query}->{$subject});
    }
    else{
    $hitref->{$query}->{$subject} = $bitscoreratio;
       }
    }

    my $onehitstotal=0;
    my $onehitscounter=0;
    my $twohitstotal=0;
    my $twohitscounter=0;
    my $threehitstotal=0;
    my $threehitscounter=0;

    foreach my $query (keys %$hitref){
    my @subjhits = sort {$hitref->{$query}->{$b} <=> $hitref->{$query}->{$a}} (keys %{$hitref->{$query}});
    my $onehit = $hitref->{$query}->{$subjhits[0]};
    my $twohit = $hitref->{$query}->{$subjhits[1]};
    my $threehit = $hitref->{$query}->{$subjhits[2]};

    if($onehit ne ""){
        $onehitstotal+=$onehit;
        $onehitscounter++;
    }
    else{
        #there is a problem. should be at least for each key pair in hash
    }
    if($twohit ne ""){
        $twohitstotal+=$twohit;
        $twohitscounter++;
    }
    if($threehit ne ""){
        $threehitstotal+=$threehit;
        $threehitscounter++;
    }
    }

    my ($onehitsavg,$twohitsavg,$threehitsavg);
    if($onehitscounter>0){
    $onehitsavg = $onehitstotal/$onehitscounter;
    }
    if($twohitscounter>0){
    $twohitsavg = $twohitstotal/$twohitscounter;
    }
    if($threehitscounter>0){
    $threehitsavg = $threehitstotal/$threehitscounter;
    }
    return ($onehitsavg,$twohitsavg,$threehitsavg);
}

sub get_org_id_to_bitscoreavgs {
    my($self,$ref_org,$match_org) = @_;

    #caculate on the 1,2,3 position avgs on the fly for now until
    #the position avgs are stored in the db.
    #this data is cached anyways so no harm in asking for it multiple times
    my (@ret, @s, $i);
    @ret = $self->get_org_id_to_blastpmatches($ref_org,$match_org);

    my $hitref;
    for ($i=0; $i<@ret; $i++) {
    my $query = $ret[$i][0];
    my $subject = $ret[$i][1];
    my $bitscoreratio = $ret[$i][7];

    #$hitref->{query}->{subject} = bitscore
    #capture best scoring HSP for any query/subject pair
    if(exists $hitref->{$query}->{$subject}){
        $hitref->{$query}->{$subject} = $bitscoreratio if($bitscoreratio > $hitref->{$query}->{$subject});
    }
    else{
    $hitref->{$query}->{$subject} = $bitscoreratio;
       }
    }

    my $onehitstotal=0;
    my $onehitscounter=0;
    my $twohitstotal=0;
    my $twohitscounter=0;
    my $threehitstotal=0;
    my $threehitscounter=0;

    foreach my $query (keys %$hitref){
    my @subjhits = sort {$hitref->{$query}->{$b} <=> $hitref->{$query}->{$a}} (keys %{$hitref->{$query}});
    my $onehit = $hitref->{$query}->{$subjhits[0]};
    my $twohit = $hitref->{$query}->{$subjhits[1]};
    my $threehit = $hitref->{$query}->{$subjhits[2]};

    if($onehit ne ""){
        $onehitstotal+=$onehit;
        $onehitscounter++;
    }
    else{
        #there is a problem. should be at least for each key pair in hash
    }
    if($twohit ne ""){
        $twohitstotal+=$twohit;
        $twohitscounter++;
    }
    if($threehit ne ""){
        $threehitstotal+=$threehit;
        $threehitscounter++;
    }
    }

    my ($onehitsavg,$twohitsavg,$threehitsavg);
    if($onehitscounter>0){
    $onehitsavg = $onehitstotal/$onehitscounter;
    }
    if($twohitscounter>0){
    $twohitsavg = $twohitstotal/$twohitscounter;
    }
    if($threehitscounter>0){
    $threehitsavg = $threehitstotal/$threehitscounter;
    }
    return ($onehitsavg,$twohitsavg,$threehitsavg);
}


sub get_seq_id_to_blastpmatches {
    my $self = shift;
    my($param) = do_params(\@_,
            [query_seq_id => '',
                match_seq_id => '']
            );

    my $ref_asmbl = $param->{'query_seq_id'};
    my $match_asmbl = $param->{'match_seq_id'};

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @blastp_cv_id = $self->get_cv_term_id('match_part', 'SO');


    my $query = "SELECT p1.uniquename,p2.uniquename,pfl1.fmin,pfl1.fmax,pfl2.fmin,pfl2.fmax,bpf.rawscore,bpf.normscore,a2.uniquename,bpf.significance ".
    "FROM feature p1, feature p2, feature a1, feature a2, featureloc afl1, featureloc afl2, featureloc pfl1, featureloc pfl2, feature bp, analysisfeature bpf, analysis a  ".
    "WHERE bp.feature_id = afl1.feature_id  ".
    "AND bp.feature_id = afl2.feature_id  ".
    "AND afl1.srcfeature_id = p1.feature_id  ".
    "AND afl2.srcfeature_id = p2.feature_id  ".
    "AND pfl1.feature_id = p1.feature_id  ".
    "AND pfl1.srcfeature_id = a1.feature_id  ".
    "AND pfl2.feature_id = p2.feature_id  ".
    "AND pfl2.srcfeature_id = a2.feature_id  ".
    "AND p1.type_id = $prot_cv_id[0][0]  ".
    "AND p2.type_id = $prot_cv_id[0][0]  ".
    "AND a1.type_id = $seq_cv_id[0][0]  ".
    "AND a2.type_id = $seq_cv_id[0][0]  ".
    "AND bp.type_id = $blastp_cv_id[0][0]  ".
    "AND bp.feature_id = bpf.feature_id  ".
    "AND afl1.rank = 1  ".
    "AND afl2.rank = 0  ".
    "AND bpf.analysis_id = a.analysis_id  ".
    "AND (a.program = 'washu blastp' OR a.program = 'blastp') ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND a1.uniquename = ? ";

    $query .= "AND a2.uniquename = '$match_asmbl' " if($match_asmbl ne "");

    return  $self->_get_results_ref($query, $ref_asmbl);
}

sub get_protein_id_to_blastpmatches {
    my($self,$protein_id) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @blastp_cv_id = $self->get_cv_term_id('match_part', 'SO');

    my $query = "SELECT p1.uniquename,p2.uniquename,pfl1.fmin,pfl1.fmax,pfl2.fmin,pfl2.fmax,bpf.rawscore,bpf.normscore,a1.uniquename,a2.uniquename,bpf.significance ".
    "FROM feature p1, feature p2, feature a1, feature a2, featureloc afl1, featureloc afl2, featureloc pfl1, featureloc pfl2, feature bp, analysisfeature bpf, analysis a  ".
    "WHERE bp.feature_id = afl1.feature_id  ".
    "AND bp.feature_id = afl2.feature_id  ".
    "AND afl1.srcfeature_id = p1.feature_id  ".
    "AND afl2.srcfeature_id = p2.feature_id  ".
    "AND pfl1.feature_id = p1.feature_id  ".
    "AND pfl1.srcfeature_id = a1.feature_id  ".
    "AND pfl2.feature_id = p2.feature_id  ".
    "AND pfl2.srcfeature_id = a2.feature_id  ".
    "AND p1.type_id = $prot_cv_id[0][0]  ".
    "AND p2.type_id = $prot_cv_id[0][0]  ".
    "AND a1.type_id = $seq_cv_id[0][0]  ".
    "AND a2.type_id = $seq_cv_id[0][0]  ".
    "AND bp.type_id = $blastp_cv_id[0][0]  ".
    "AND bp.feature_id = bpf.feature_id  ".
    "AND afl1.rank = 1  ".
    "AND afl2.rank = 0  ".
    "AND bpf.analysis_id = a.analysis_id  ".
    "AND (a.program = 'washu blastp' OR a.program = 'blastp') ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND p1.uniquename = ? ";

    return  $self->_get_results_ref($query, $protein_id);
}


sub get_org_id_to_blastpmatches {
    my($self,$ref_org,$match_org) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @blastp_cv_id = $self->get_cv_term_id('match_part', 'SO');

    my $query = "SELECT p1.uniquename,p2.uniquename,pfl1.fmin,pfl1.fmax,pfl2.fmin,pfl2.fmax,bpf.rawscore,bpf.normscore,a1.uniquename,a2.uniquename,o2.abbreviation, bpf.significance ".
    "FROM feature p1, feature p2, feature a1, feature a2, featureloc afl1, featureloc afl2, featureloc pfl1, featureloc pfl2, feature bp, analysisfeature bpf, analysis a, organism o1, organism o2  ".
    "WHERE bp.feature_id = afl1.feature_id  ".
    "AND bp.feature_id = afl2.feature_id  ".
    "AND afl1.srcfeature_id = p1.feature_id  ".
    "AND afl2.srcfeature_id = p2.feature_id  ".
    "AND pfl1.feature_id = p1.feature_id  ".
    "AND pfl1.srcfeature_id = a1.feature_id  ".
    "AND pfl2.feature_id = p2.feature_id  ".
    "AND pfl2.srcfeature_id = a2.feature_id  ".
    "AND p1.type_id = $prot_cv_id[0][0]  ".
    "AND p2.type_id = $prot_cv_id[0][0]  ".
    "AND a1.type_id = $seq_cv_id[0][0]  ".
    "AND a2.type_id = $seq_cv_id[0][0]  ".
    "AND bp.type_id = $blastp_cv_id[0][0]  ".
    "AND bp.feature_id = bpf.feature_id  ".
    "AND afl1.rank = 1  ".
    "AND afl2.rank = 0  ".
    "AND bpf.analysis_id = a.analysis_id  ".
    "AND (a.program = 'washu blastp' OR a.program = 'blastp') ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND a1.organism_id = o1.organism_id ".
    "AND a2.organism_id = o2.organism_id ".
    "AND o1.abbreviation = ? ";

    $query .= "AND o2.abbreviation = '$match_org' " if($match_org ne "");

#    print STDERR "Q: $query :: $ref_org\n";

    return  $self->_get_results_ref($query, $ref_org);
}


sub get_org_id_to_assemblies{
    my($self, $org_id) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @chrom_cv_id = $self->get_cv_term_id('chromosome');

    my $ischromquery = "SELECT count(*) from featureprop ap where ap.type_id = $chrom_cv_id[0][0] ";

    my @ischrom = $self->_get_results($ischromquery);

    my $query;

    if($ischrom[0][0] > 0){
    $query = "SELECT a.uniquename,a.seqlen,db.name,dbx.accession,a.timelastmodified,ap.value ".
        "FROM feature a, organism o, dbxref dbx, db db, featureprop ap ".
        "WHERE a.dbxref_id = dbx.dbxref_id ".
        "AND dbx.db_id = db.db_id ".
        "AND a.type_id = $seq_cv_id[0][0] ".
        "AND o.organism_id = a.organism_id ".
        "AND ap.type_id = $chrom_cv_id[0][0] ".
        "AND a.feature_id = ap.feature_id ".
        "AND o.abbreviation = ? ";
    }
    else{
    $query = "SELECT a.uniquename,a.seqlen,db.name,dbx.accession,a.timelastmodified,0 ".
        "FROM feature a, organism o, dbxref dbx, db db ".
        "WHERE a.dbxref_id = dbx.dbxref_id ".
        "AND dbx.db_id = db.db_id ".
        "AND a.type_id = $seq_cv_id[0][0] ".
        "AND o.organism_id = a.organism_id ".
        "AND o.abbreviation = ? ";
    }

    return $self->_get_results_ref($query,$org_id);
}

sub get_seq_id_to_assembly{
    my($self,$seq_id,$doGetResidues) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @chrom_cv_id = $self->get_cv_term_id('chromosome');

    my $ischromquery = "SELECT count(*) from featureprop ap where ap.type_id = $chrom_cv_id[0][0] ";

    my @ischrom = $self->_get_results($ischromquery);

    my $query;

    my $addquery;
    if($doGetResidues){
    $addquery = ",a.residues";
    }

    my $sizequery = "SELECT datalength(residues) from feature where uniquename = ?";
    my @sizeval =  $self->_get_results($sizequery,$seq_id);

    $self->do_set_textsize($sizeval[0][0]) if($sizeval[0][0]);

    if($ischrom[0][0] > 0){
    $query = "SELECT a.uniquename,a.seqlen,db.name,dbx.accession,a.timelastmodified,ap.value,o.abbreviation$addquery ".
        "FROM feature a, organism o, dbxref dbx, db db, featureprop ap ".
        "WHERE a.dbxref_id = dbx.dbxref_id ".
        "AND dbx.db_id = db.db_id ".
        "AND a.type_id = $seq_cv_id[0][0] ".
        "AND o.organism_id = a.organism_id ".
        "AND ap.type_id = $chrom_cv_id[0][0] ".
        "AND a.feature_id = ap.feature_id ".
        "AND a.uniquename = ? ";
    }
    else{
    $query = "SELECT a.uniquename,a.seqlen,db.name,dbx.accession,a.timelastmodified,0,o.abbreviation$addquery ".
        "FROM feature a, organism o, dbxref dbx, db db ".
        "WHERE a.dbxref_id = dbx.dbxref_id ".
        "AND dbx.db_id = db.db_id ".
        "AND a.type_id = $seq_cv_id[0][0] ".
        "AND o.organism_id = a.organism_id ".
        "AND a.uniquename = ? ";
    }

    return $self->_get_results_ref($query,$seq_id);
}

sub get_seq_id_to_scaffold {
    my($self, $seq_id, $type) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');

    my $query = "SELECT db.name, dbx.accession " .
    "FROM dbxref dbx, db db, feature f " .
    "WHERE f.type_id = $seq_cv_id[0][0] " .
    "AND f.dbxref_id = dbx.dbxref_id " .
    "AND dbx.db_id = db.db_id ".
    "AND f.uniquename = ?";

    my @result = $self->_get_results($query,$seq_id);

    # OBSERVE excessive hackery to get the scaffold from the external
    #  database.

    my $target_db = $result[0][0];
    $target_db =~ s/.*://;

    my $asmbl_id = $result[0][1];
    $asmbl_id =~ s/.*://;

    my $table = $target_db . "..sub_to_final";

    my $query2 = "SELECT $table.asmbl_id, \"$target_db\", \"$result[0][1]\", $table.sub_asmbl_id, $table.sub_asm_lend, $table.sub_asm_rend, $table.asm_lend, $table.asm_rend, datalength(sequence) " .
    "FROM $table, $target_db..assembly a " .
    "WHERE $table.$type = ? " .
    "AND a.asmbl_id = $table.asmbl_id";

    return $self->_get_results_ref($query2, $asmbl_id);
}



sub get_org_id_to_description{
    my($self, $org_id) = @_;

    my $query = "SELECT o.common_name,o.abbreviation,o.comment ".
    "FROM organism o ".
    "WHERE o.abbreviation = ? ";

     return  $self->_get_results($query, $org_id);
}

sub get_org_id_to_searches{
    my($self, $org_id) = @_;

    my $query = "SELECT a.analysis_id,af.feature_id,a.name,a.program,a.sourcename,a.timeexecuted ".
    "FROM analysis a, analysisfeature af, feature f, organism o ".
    "WHERE af.analysis_id = a.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND f.organism_id = o.organism_id ".
    "AND o.abbreviation = ?";

     return  $self->_get_results($query, $org_id);
}

sub get_seq_id_to_BERmatches {
    my($self,$ref_asmbl,$match_asmbl) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @cds_cv_id = $self->get_cv_term_id('CDS');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @prod_cv_id = $self->get_cv_term_id('produced_by');
    my @ber_cv_id = $self->get_cv_term_id('alignment_hsp');


    my $query = "SELECT p1.uniquename,p2.uniquename,a2.uniquename,af.pidentity,af.significance ".
    "FROM feature p1, feature c2, feature p2, feature a1, feature a2, feature_relationship fp2, featureloc pfl1, featureloc cfl2, feature ber, analysisfeature af, analysis a, featureloc afl1, featureloc afl2 ".
    "WHERE ber.feature_id = afl1.feature_id ".
    "AND ber.feature_id = afl2.feature_id ".
    "AND afl1.srcfeature_id = p1.feature_id ".
    "AND afl2.srcfeature_id = c2.feature_id ".
    "AND pfl1.feature_id = p1.feature_id ".
    "AND pfl1.srcfeature_id = a1.feature_id ".
    "AND cfl2.feature_id = c2.feature_id ".
    "AND cfl2.srcfeature_id = a2.feature_id ".
    "AND p1.type_id = $prot_cv_id[0][0] ".
    "AND c2.type_id = $cds_cv_id[0][0] ".
    "AND a1.type_id = $seq_cv_id[0][0] ".
    "AND a2.type_id = $seq_cv_id[0][0] ".
    "AND ber.type_id = $ber_cv_id[0][0] ".
    "AND afl1.rank = 0 ".
    "AND afl2.rank = 1 ".
    "AND pfl1.rank = 2 ".
    "AND cfl2.rank = 1 ".
    "AND fp2.subject_id = p2.feature_id  ".
    "AND fp2.object_id = c2.feature_id  ".
    "AND fp2.type_id = $prod_cv_id[0][0] ".
    "AND af.feature_id = ber.feature_id  ".
    "AND a.analysis_id = af.analysis_id  ".
    "AND a.program = 'allvsall'  ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND a1.uniquename = ? ";
    $query .= "AND a2.uniquename = '$match_asmbl' " if($match_asmbl ne "");

    return  $self->_get_results_ref($query, $ref_asmbl);
}

#-----------------------------------------------------------------------------------------------------
# get_org_id_to_BERmatches()
#
# argument: 1) reference organism name (required) (organism.abbreviation)
#           2) match organism name     (optional) (organism.abbreviation)
#
# returns:  1) refseq protein's uniquename            (feature.uniquename)
#           2) compseq protein's uniquename           (feature.uniquename)
#           3) compseq organism's abbreviation        (organism.abbreviation)
#           4) compseq's source assembly's uniquename (feature.uniquename)
#           5) allvsall percent identity              (analysisfeature.pidentity)
#           6) allvsall significance                  (analysisfeature.significance)
#
#-----------------------------------------------------------------------------------------------------
sub get_org_id_to_BERmatches {

    my($self,$ref_org,$match_org) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @cds_cv_id = $self->get_cv_term_id('CDS');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @prod_cv_id = $self->get_cv_term_id('produced_by');
    my @ber_cv_id = $self->get_cv_term_id('alignment_hsp');


    my $query = "SELECT p1.uniquename,p2.uniquename, o2.abbreviation, a2.uniquename,af.pidentity,af.significance ".
    "FROM feature p1, feature c2, feature p2, feature a1, feature a2, feature_relationship fp2, featureloc pfl1, featureloc cfl2, feature ber, analysisfeature af, analysis a, featureloc afl1, featureloc afl2, organism o1, organism o2 ".
    "WHERE ber.feature_id = afl1.feature_id ".
    "AND ber.feature_id = afl2.feature_id ".
    "AND afl1.srcfeature_id = p1.feature_id ".
    "AND afl2.srcfeature_id = c2.feature_id ".
    "AND pfl1.feature_id = p1.feature_id ".
    "AND pfl1.srcfeature_id = a1.feature_id ".
    "AND cfl2.feature_id = c2.feature_id ".
    "AND cfl2.srcfeature_id = a2.feature_id ".
    "AND p1.type_id = $prot_cv_id[0][0] ".
    "AND c2.type_id = $cds_cv_id[0][0] ".
    "AND a1.type_id = $seq_cv_id[0][0] ".
    "AND a2.type_id = $seq_cv_id[0][0] ".
    "AND ber.type_id = $ber_cv_id[0][0] ".
    "AND afl1.rank = 0 ".
    "AND afl2.rank = 1 ".
    "AND pfl1.rank = 2 ".
    "AND cfl2.rank = 1 ".
    "AND fp2.subject_id = p2.feature_id  ".
    "AND fp2.object_id = c2.feature_id  ".
    "AND fp2.type_id = $prod_cv_id[0][0]  ".
    "AND af.feature_id = ber.feature_id  ".
    "AND a.analysis_id = af.analysis_id  ".
    "AND a.program = 'allvsall'  ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND a1.organism_id = o1.organism_id ".
    "AND o1.abbreviation = ? ".
    "AND a2.organism_id = o2.organism_id ";
    $query .= "AND o2.abbreviation  = '$match_org' " if($match_org ne "");

    return  $self->_get_results_ref($query, $ref_org);
}

#-----------------------------------------------------------------------------------------------------
# get_org_id_to_BERmatches()
#
# argument: 1) reference organism name (required) (organism.abbreviation)
#           2) match organism name     (optional) (organism.abbreviation)
#
# returns:  1) refseq protein's uniquename            (feature.uniquename)
#           2) compseq protein's uniquename           (feature.uniquename)
#           3) compseq organism's abbreviation        (organism.abbreviation)
#           4) compseq's source assembly's uniquename (feature.uniquename)
#           5) allvsall percent identity              (analysisfeature.pidentity)
#           6) allvsall significance                  (analysisfeature.significance)
#
#-----------------------------------------------------------------------------------------------------
sub get_protein_id_to_BERmatches {

    my($self,$protein_id) = @_;

    my @seq_cv_id = $self->get_cv_term_id('assembly');
    my @cds_cv_id = $self->get_cv_term_id('CDS');
    my @prot_cv_id = $self->get_cv_term_id('protein', 'SO');
    my @prod_cv_id = $self->get_cv_term_id('produced_by');
    my @ber_cv_id = $self->get_cv_term_id('alignment_hsp');


    my $query = "SELECT p1.uniquename,p2.uniquename, o2.abbreviation, o1.abbreviation, a2.uniquename, a1.uniquename, af.pidentity,af.significance ".
    "FROM feature p1, feature c2, feature p2, feature a1, feature a2, feature_relationship fp2, featureloc pfl1, featureloc cfl2, feature ber, analysisfeature af, analysis a, featureloc afl1, featureloc afl2, organism o1, organism o2 ".
    "WHERE ber.feature_id = afl1.feature_id ".
    "AND ber.feature_id = afl2.feature_id ".
    "AND afl1.srcfeature_id = p1.feature_id ".
    "AND afl2.srcfeature_id = c2.feature_id ".
    "AND pfl1.feature_id = p1.feature_id ".
    "AND pfl1.srcfeature_id = a1.feature_id ".
    "AND cfl2.feature_id = c2.feature_id ".
    "AND cfl2.srcfeature_id = a2.feature_id ".
    "AND p1.type_id = $prot_cv_id[0][0] ".
    "AND c2.type_id = $cds_cv_id[0][0] ".
    "AND a1.type_id = $seq_cv_id[0][0] ".
    "AND a2.type_id = $seq_cv_id[0][0] ".
    "AND ber.type_id = $ber_cv_id[0][0] ".
    "AND afl1.rank = 0 ".
    "AND afl2.rank = 1 ".
    "AND pfl1.rank = 2 ".
    "AND cfl2.rank = 1 ".
    "AND fp2.subject_id = p2.feature_id  ".
    "AND fp2.object_id = c2.feature_id  ".
    "AND fp2.type_id = $prod_cv_id[0][0]  ".
    "AND af.feature_id = ber.feature_id  ".
    "AND a.analysis_id = af.analysis_id  ".
    "AND a.program = 'allvsall'  ".
    "AND ((a.description is NULL) or (a.description not like '%OBSOLETE%')) " .
    "AND a1.organism_id = o1.organism_id ".
    "AND p1.uniquename = ?";

    return  $self->_get_results_ref($query, $protein_id);
}


#---------------------------------------------------------------------------------------
# get_organism_details()
#
# argument: organism.abbreviation
# returns:  1) (feature.uniquename)
#           2) (organism.common_name
#           3) (datalength(feature.residues)
#
#---------------------------------------------------------------------------------------
sub get_organism_details {

    my($self, $org_abbrev) = @_;

    if (!defined($org_abbrev)){
    }

    my @assembly_cv_id = $self->get_cv_term_id('assembly');


    my $query = "SELECT f.uniquename, o.common_name, datalength(f.residues) ".
    "FROM feature f, organism o ".
    "WHERE o.abbreviation = ? ".
    "AND   o.organism_id = f.organism_id ".
    "AND   f.type_id = $assembly_cv_id[0][0] ";


    return  $self->_get_results_ref($query, $org_abbrev);
}


#---------------------------------------------------------------------------------------
# get_organism_gene_count()
#
# argument: NONE
# returns:  1) organism abbrev (organism.abbreviation)
#           2) number of genes on this organism's assembly/genomic axis/genomic contig
#
#---------------------------------------------------------------------------------------
sub get_organism_gene_count {

    my($self) = @_;

    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @gene_cv_id = $self->get_cv_term_id('gene');
    my @part_of_cv_id = $self->get_cv_term_id('part_of');


    my $query = "SELECT o.abbreviation, count(fr.subject_id) ".
    "FROM organism o, feature f, feature g, feature_relationship fr ".
    "WHERE o.organism_id = f.organism_id ".
    "AND   f.type_id = $assembly_cv_id[0][0] ".
    "AND   f.feature_id = fr.object_id ".
    "AND   fr.type_id = $part_of_cv_id[0][0] ".
    "AND   fr.subject_id = g.feature_id ".
    "AND   g.type_id = $gene_cv_id[0][0] ".
    "GROUP BY o.abbreviation ";

    return  $self->_get_results_ref($query);
}


#---------------------------------------------------------------------------------------
# get_organism_details_2()
#
# argument: NONE
# returns:  1) assembly name                   (feature.uniquename)
#           2) organism common name            (organism.common_name)
#           3) length of assembly sequence     (datalength(feature.residues))
#           4) organism abbreviation           (organism.abbrev)
#           5) number of genes on the assembly (count(featureloc(subject_id)))
#
#---------------------------------------------------------------------------------------
sub get_organism_details_2 {

    my($self) = @_;

    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @gene_cv_id = $self->get_cv_term_id('gene');
    my @part_of_cv_id = $self->get_cv_term_id('part_of');


    my $query = "SELECT f.uniquename, o.common_name, f.seqlen, o.abbreviation, count(fr.subject_id) ".
    "FROM organism o, feature f, feature g, feature_relationship fr ".
    "WHERE o.organism_id = f.organism_id ".
    "AND   f.type_id = $assembly_cv_id[0][0] ".
    "AND   f.feature_id = fr.object_id ".
    "AND   fr.type_id = $part_of_cv_id[0][0] ".
    "AND   fr.subject_id = g.feature_id ".
    "AND   g.type_id = $gene_cv_id[0][0] ".
    "GROUP BY f.uniquename, o.common_name, f.seqlen, o.abbreviation ";

    return  $self->_get_results_ref($query);
}

sub get_locus_to_protein_feature_id_lookup{
    my ($self) = @_;

    my @protein_cv_id = $self->get_cv_term_id('protein');

    my $query = "SELECT p.feature_id, x.accession ".
            "FROM feature p, feature_dbxref fd, dbxref x ".
        "WHERE p.type_id = $protein_cv_id[0][0] ".
        "AND p.feature_id = fd.feature_id ".
        "AND fd.dbxref_id = x.dbxref_id ".
        "AND x.version = 'locus' ";

    my @results = $self->_get_results($query);

    return @results;
}

sub get_feature_id_to_gene_go_lookup{
    my($self, $type) = @_;

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @go_cv_id = $self->get_cv_id('GO');
    my @ev_code_cv_id = $self->get_cv_id('evidence_code');


    my @process_cv_id = $self->get_cv_id('process');
    my @function_cv_id = $self->get_cv_id('function');
    my @component_cv_id = $self->get_cv_id('component');

    my $go_cvs = "";
    if ($process_cv_id[0][0] ne ""){
        $go_cvs = "$process_cv_id[0][0], $function_cv_id[0][0], $component_cv_id[0][0]";
    }else{
        $go_cvs = "$go_cv_id[0][0]";
    }


	 



    my $query = "SELECT f1.feature_id, s.sortName ".
		  "FROM feature f1, dbxref d, feature_cvterm fc, cvterm c, common..go_term t, feature_cvtermprop fcp, cvterm ct, common..go_order s ". 
		  "WHERE d.accession = t.go_id ".
		  "AND f1.type_id = $transcript_cv_id[0][0] ".
		  "AND fc.cvterm_id = c.cvterm_id ". 
		  "AND c.cv_id IN ($go_cvs) ".
		  "AND c.dbxref_id = d.dbxref_id ". 
		  "AND f1.feature_id = fc.feature_id ". 
		  "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ".
		  "AND fcp.type_id = ct.cvterm_id ".
		  "AND ct.cv_id = $ev_code_cv_id[0][0] ".
		  "AND t.type = \"$type\" ".
		  "AND ct.name = s.KeyID ".
		  "ORDER BY f1.feature_id, s.SortOrder ";

    my $tied_lookup = $self->_get_lookup_db($query);  

    return $tied_lookup;
}



sub get_all_curation{
    my($self, $ori_db)=@_;
    my($query);


    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @assignby_cv_id = $self->get_cv_term_id('completed_by');

    $query = "SELECT x.accession, fp.value ".
        "FROM featureprop fp, feature f, feature_dbxref fd, dbxref x ".
        "WHERE f.type_id = $transcript_cv_id[0][0] ".
        "AND f.feature_id = fd.feature_id ".
        "AND fd.dbxref_id = x.dbxref_id ".
        "AND x.version =  \"locus\"  ".
        "AND fp.feature_id = f.feature_id ".
        "AND fp.type_id = $assignby_cv_id[0][0] ";

    my $results = $self->_get_lookup_db($query);
    return($results);
}



sub get_locus_to_feature_id_lookup{
    my ($self, $type_term) = @_;

    my @cv_id = $self->get_cv_term_id($type_term);

    my $query = "SELECT  x.accession, p.feature_id ".
            "FROM feature p, feature_dbxref fd, dbxref x ".
        "WHERE p.type_id = $cv_id[0][0] ".
        "AND p.feature_id = fd.feature_id ".
        "AND fd.dbxref_id = x.dbxref_id ".
        "AND x.version = 'locus' ";


    my $results = $self->_get_lookup_db($query);

    return $results;
}



sub get_ori_db_org_id_lookup{
    my ($self) = @_;

    my $query = "SELECT db.name, o.organism_id ".
            "FROM organism o, organism_dbxref od, dbxref x, db db ".
        "WHERE o.organism_id = od.organism_id ".
        "AND od.dbxref_id = x.dbxref_id ".
                "AND x.version = \"legacy_annotation_database\" ".
                "AND x.db_id = db.db_id ";
    my @results = $self->_get_results($query);

    my $o_hash;
    for(my $i = 0; $i < scalar @results; $i++){
    my $org_db = $results[$i][1];
    my ($junk, $db) = split(/\_/, $results[$i][0]);
    $db = "\l$db";
    $db = lc($db);
    $o_hash->{$results[$i][1]} = $db;
    $o_hash->{$db} = $results[$i][1];

    }

    $o_hash->{'not_known'} = -1;

    return $o_hash;
}


sub get_org_id_to_org_name_lookup{
    my ($self) = @_;

    my $query = "SELECT o.organism_id, o.common_name FROM organism o ";
    my @results = $self->_get_results($query);

    my $o_hash;
    for(my $i = 0; $i < scalar @results; $i++){
    $o_hash->{$results[$i][0]} = $results[$i][1];
    }



    $o_hash->{'not_known'} = -1;

    return $o_hash;
}





sub get_feature_id_to_featureprop_lookup {
    ## db lookup for common feature property lookups like curation status

    my($self)=@_;

    my($query);

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @assignby_cv_id = $self->get_cv_term_id('completed_by');


    $query = "SELECT f.feature_id, fp.value ".
        "FROM featureprop fp, feature f ".
        "WHERE f.type_id = $transcript_cv_id[0][0] ".
        "AND fp.feature_id = f.feature_id ".
        "AND fp.type_id = $assignby_cv_id[0][0] ";

    return $self->_get_lookup_db($query);
}

sub get_feature_id_to_gene_name_lookup{
    my($self) = @_;

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @gene_sym_cv_id = $self->get_cv_term_id('gene_symbol', 'annotation_attributes.ontology');
    my @com_name_cv_id = $self->get_cv_term_id('gene_product_name');
    my @rna_name_cv_id = $self->get_cv_term_id('name');
    my @trna_cv_id = $self->get_cv_term_id('tRNA');
    my @rrna_cv_id = $self->get_cv_term_id('rRNA');
    my @snrna_cv_id = $self->get_cv_term_id('snRNA');
    my @term_cv_id = $self->get_cv_term_id('terminator');

    # 1 - locus, 2 - com_name, 3 - gene_sym, 4 - org_id, 5 - type_id

    my $query = "SELECT f.feature_id, f.uniquename, d.accession, fp1.value, fp2.value, f.organism_id, f.type_id ".
    "FROM feature_dbxref fd, dbxref d, featureprop fp1, ".
    "feature f ".
    "LEFT JOIN (SELECT * FROM featureprop fp2 WHERE fp2.type_id = $gene_sym_cv_id[0][0]) AS fp2 ON (f.feature_id = fp2.feature_id) ".
    "WHERE f.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = d.dbxref_id ".
    "AND d.version = 'locus' ".
    "AND f.feature_id = fp1.feature_id ".
    "AND fp1.type_id IN( $com_name_cv_id[0][0], $rna_name_cv_id[0][0]) ".
    "AND f.type_id IN ($transcript_cv_id[0][0],$trna_cv_id[0][0],$rrna_cv_id[0][0],$snrna_cv_id[0][0],$term_cv_id[0][0]) ";
    #print STDERR "Gene name lookup query is: $query \n";

    return $self->_get_lookup_db($query);
}

sub get_feature_id_to_gene_pos_lookup{
    my($self) = @_;

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @assembly_cv_id = $self->get_cv_term_id('assembly');
    my @mol_name_cv_id = $self->get_cv_term_id('molecule_name');
    #Added for query rna related feature
    my @trna_cv_id = $self->get_cv_term_id('tRNA');
    my @rrna_cv_id = $self->get_cv_term_id('rRNA');
    my @snrna_cv_id = $self->get_cv_term_id('snRNA');
    my @term_cv_id = $self->get_cv_term_id('terminator');

 
    #  0-transcript_id, 1-t.uniquename, 2- min, 3 - max, 4 - strand, 5 - mol name, 6-a.feature_id, 7 - seq_id
    my $query = "SELECT f.feature_id, f.uniquename, fl.fmin, fl.fmax, fl.strand, fp.value, s.feature_id, s.uniquename ".

    "FROM feature f, featureloc fl, feature s, featureprop fp ".
    "WHERE f.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = s.feature_id ".
    "AND f.type_id in( $transcript_cv_id[0][0], $trna_cv_id[0][0], $rrna_cv_id[0][0], $snrna_cv_id[0][0], $term_cv_id[0][0]) ".
    "AND s.type_id = $assembly_cv_id[0][0] ".
    "AND s.feature_id = fp.feature_id ".
    "AND fp.type_id = $mol_name_cv_id[0][0] ";

    return $self->_get_lookup_db($query);
}

sub get_pfeature_id_to_gene_name_lookup{
    my($self) = @_;

    my @transcript_cv_id = $self->get_cv_term_id('transcript');
    my @protein_cv_id = $self->get_cv_term_id('protein');
    my @gene_sym_cv_id = $self->get_cv_term_id('gene_symbol', 'annotation_attributes.ontology');
    my @com_name_cv_id = $self->get_cv_term_id('gene_product_name');
    my @att_type_cv_id = $self->get_cv_term_id('percent_gc'); # for all v all stuff

    # 2 - locus, 3 - com_name, 4 - gene_sym, 5 - org_id, 6 - GC

    my $query = "SELECT f2.feature_id, f.feature_id, f.uniquename, d.accession, fp1.value, fp2.value, f.organism_id, fp3.value ".
    "FROM feature_dbxref fd, dbxref d, featureprop fp1, feature_dbxref fd2, feature f2, featureprop fp3, feature_relationship fr, ".
    "feature f ".
    "LEFT JOIN (SELECT * FROM featureprop fp2 WHERE fp2.type_id = $gene_sym_cv_id[0][0]) AS fp2 ON (f.feature_id = fp2.feature_id) ".
    "WHERE f.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = d.dbxref_id ".
    "AND d.version = 'locus' ".
    "AND f.feature_id = fp1.feature_id ".
    "AND fp1.type_id = $com_name_cv_id[0][0] ".
    "AND f.type_id = $transcript_cv_id[0][0] ".
    "AND f2.feature_id = fd2.feature_id ".
    "AND f2.type_id = $protein_cv_id[0][0] ".
    "AND fp3.feature_id = fr.subject_id ".
    "AND fr.object_id = f.feature_id ".
    "AND fp3.type_id = $att_type_cv_id[0][0] ".
    "AND fd2.dbxref_id = d.dbxref_id ";
    return $self->_get_lookup_db($query);
}

sub get_restriction_enzyme_info{
    my($self)=@_;
    my($query);

    $query = "SELECT r.id, r.enzyme, r.site, r.cut_5, r.cut_3, "
        ." r.organism, r.cut2_5, r.cut2_3, r.ncuts, "
        ." r.type, r.methylated, c.name, c.phone, c.url "
        ." FROM common..rebase r "
        ." LEFT JOIN common..rebase_link l ON (r.id = l.rebase_id) "
        ." LEFT JOIN common..company c ON (l.company_id = c.id) ";

    my @results = $self->_get_results($query);

    return(@results);
}

sub get_hmm_acc_to_hmm_info{
     my($self, $hmm_acc) = @_;
     my($query);

     $query = "SELECT h.hmm_name, h.hmm_com_name, h.noise_cutoff, h.trusted_cutoff, ".
              "h.avg_score, h.hmm_acc, h.entry_date, h.mod_date, h.ec_num, h.author, ".
              "h.hmm_comment, h.reference, h.iso_type, h.hmm_len, h.std_dev, ".
              "r.mainrole, r.sub1role, h.noise_cutoff2, h.trusted_cutoff2, a.alignment ".
              "FROM egad..alignment a, ".
              "egad..hmm2 h ".
              "LEFT JOIN egad..hmm_role_link rl ON (h.hmm_acc = rl.hmm_acc) ".
              "LEFT JOIN egad..roles r ON (rl.role_id = r.role_id) ".
              "WHERE h.hmm_acc = ? ".
              "AND h.is_current = 1 ".
              "AND h.iso_id = a.iso_id ".
              "AND a.align_type = \"seed\"";

     my @results = $self->_get_results($query, $hmm_acc);
     return(@results);
}

sub get_HMM_acc_to_description {
    my ($self, $HMM_acc) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
	
	my $hmm_data = $self->get_hmm_data_lookup();

	my $ret;
	$ret->[0][0]  = $HMM_acc;
	$ret->[0][1]  = $hmm_data->{$HMM_acc}->{'hmm_type'}; # does not exist
	$ret->[0][2]  = $hmm_data->{$HMM_acc}->{'name'}; # does not exist
	$ret->[0][3]  = $hmm_data->{$HMM_acc}->{'hmm_com_name'};
	$ret->[0][4]  = $hmm_data->{$HMM_acc}->{'hmm_len'};
	$ret->[0][5]  = $hmm_data->{$HMM_acc}->{'trusted_cutoff'};
	$ret->[0][6]  = $hmm_data->{$HMM_acc}->{'noise_cutoff'};
	$ret->[0][7]  = $hmm_data->{$HMM_acc}->{'hmm_comment'}; # does not exist
	$ret->[0][8]  = $hmm_data->{$HMM_acc}->{'related_hmm'}; # does not exist
	$ret->[0][9]  = $hmm_data->{$HMM_acc}->{'author'}; # does not exist
	$ret->[0][10] = $hmm_data->{$HMM_acc}->{'entry_date'}; # does not exist
	$ret->[0][11] = $hmm_data->{$HMM_acc}->{'mod_date'}; # does not exist
	$ret->[0][12] = ""; # nothing
	$ret->[0][13] = $hmm_data->{$HMM_acc}->{'ec_num'};
	$ret->[0][14] = $hmm_data->{$HMM_acc}->{'avg_score'}; # does not exist
	$ret->[0][15] = $hmm_data->{$HMM_acc}->{'std_dev'}; # does not exist
	$ret->[0][16] = $hmm_data->{$HMM_acc}->{'isotype'};
	$ret->[0][17] = $hmm_data->{$HMM_acc}->{'private'}; # does not exist
	$ret->[0][18] = $hmm_data->{$HMM_acc}->{'gene_symbol'};
	$ret->[0][19] = $hmm_data->{$HMM_acc}->{'reference'}; # does not exist
	$ret->[0][20] = $hmm_data->{$HMM_acc}->{'expanded_name'}; # does not exist
	$ret->[0][21] = $hmm_data->{$HMM_acc}->{'trusted_cutoff2'};
	$ret->[0][22] = $hmm_data->{$HMM_acc}->{'noise_cutoff2'};
	$ret->[0][23] = $hmm_data->{$HMM_acc}->{'iso_id'}; # does not exist
	$ret->[0][24] = $hmm_data->{$HMM_acc}->{'id'}; # does not exist

	return $ret;
}

sub get_HMM_acc_to_roles {
    my($self, $HMM_acc) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

	# remove version number if it exists; hmm_go_link does not use version numbers yet
	if($HMM_acc =~ /\./) {
		$HMM_acc =~ s/\.(.*)//g;
	}

	my $results;
	my $index = 0;
	
	# get all lookup files needed to retrieve role info from the HMM accession
	my $tfam_lookup = $self->get_tigrfam2roles_lookup_data();
	my $pfam_lookup = $self->get_pfam2roles_lookup_data();
	my $role_lookup = $self->get_roles_lookup_data();

	if($HMM_acc =~ /^TIGR/) {
		my $tfam_roles = $tfam_lookup->{$HMM_acc};
		foreach my $role_id (@$tfam_roles) {
			my $main_role = $role_lookup->{$role_id}->{'main_role'};
			my $sub1_role = $role_lookup->{$role_id}->{'sub1role'};

			# set up results array to return back to Coati caller
			$results->[$index][0] = $role_id;
			$results->[$index][1] = $main_role;
			$results->[$index][2] = $sub1_role;
		}
	} else {
		my $pfam_roles = $pfam_lookup->{$HMM_acc};
		foreach my $role_id (@$pfam_roles) {
			my $main_role = $role_lookup->{$role_id}->{'main_role'};
			my $sub1_role = $role_lookup->{$role_id}->{'sub1role'};

			# set up results array to return back to Coati caller
			$results->[$index][0] = $role_id;
			$results->[$index][1] = $main_role;
			$results->[$index][2] = $sub1_role;
		}
	}
	
	return $results;
}

sub get_all_role_categories{
     my($self)=@_;
     my($query);

     $query = "SELECT distinct e.mainrole, e.sub1role, e.role_id, e.role_order "
              . "FROM  egad..roles e "
              . "WHERE e.mainrole != \"cell/organism defense\" "
              . "AND e.mainrole != \"Glimmer rejects\" "
              . "AND e.compartment in (\"microbial\", \"viral\") "
              . "ORDER BY e.role_order ";

     my @results = $self->_get_results($query);

     return(@results);
}

sub get_gene_id_to_HMMs {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if (!$db);

    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @cd_id = $self->get_cv_term('CDS');
    my @pr_id = $self->get_cv_term('polypeptide');
    my @ma_id = $self->get_cv_term('match_part');
    my @ev_id = $self->get_cv_term('e_value');
    my @df_id = $self->get_cv_term('derives_from');
    my @po_id = $self->get_cv_term('part_of');

    my $query = "SELECT h.feature_id, h.uniquename, '', '', af.rawscore, fp.value, '', mh.fmin, mh.fmax, ".
		        "pm.fmin, pm.fmax, 'assignby', h.timeaccessioned, pm.fmin, pm.fmax ".
				"FROM feature a, feature t, feature p, feature h, feature_relationship tp, ".
				"featureloc fl, featureloc pm, featureloc mh, analysisfeature af, ".
				"feature m ".
				"LEFT JOIN featureprop fp ON (m.feature_id = fp.feature_id AND fp.type_id = $ev_id[0][0]) ".
				"WHERE t.uniquename = '$gene_id' ".
				"AND t.feature_id = fl.feature_id ".
				"AND fl.srcfeature_id = a.feature_id ".
				"AND t.feature_id = tp.object_id ".
				"AND tp.subject_id = p.feature_id ".
				"AND p.feature_id = pm.srcfeature_id ".
				"AND pm.feature_id = m.feature_id ".
				"AND m.feature_id = mh.feature_id ".
				"AND m.feature_id = af.feature_id ".
				"AND mh.srcfeature_id = h.feature_id ".
				"AND mh.rank = 0 ".
				"AND a.type_id = $as_id[0][0] ".
				"AND t.type_id = $tr_id[0][0] ".
				"AND p.type_id = $pr_id[0][0] ".
				"AND m.type_id = $ma_id[0][0] ".
				"AND tp.type_id = $po_id[0][0] ".
				"AND h.type_id = $pr_id[0][0] ";

    my $ret = $self->_get_results_ref($query);


	my $hmm_data = $self->get_hmm_data_lookup();
	
	for(my $i=0; $i<@$ret; $i++) {
		my $chado_hmm = $ret->[$i][1];
		$ret->[$i][1]  = $chado_hmm;
		$ret->[$i][15] = $hmm_data->{$chado_hmm}->{'trusted_cutoff'}; # trusted_cutoff
		$ret->[$i][16] = $hmm_data->{$chado_hmm}->{'noise_cutoff'}; # noise_cutoff
		$ret->[$i][17] = $hmm_data->{$chado_hmm}->{'hmm_com_name'}; # hmm_com_name
		$ret->[$i][18] = $hmm_data->{$chado_hmm}->{'isotype'}; # iso_type
		$ret->[$i][19] = $hmm_data->{$chado_hmm}->{'hmm_len'}; # hmm_len
		$ret->[$i][20] = $hmm_data->{$chado_hmm}->{'ec_num'}; # ec_num
		$ret->[$i][21] = $hmm_data->{$chado_hmm}->{'gene_symbol'}; # gene_sym
		$ret->[$i][22] = ""; # tc_num not available
		$ret->[$i][23] = $hmm_data->{$chado_hmm}->{'trusted_cutoff2'}; # trusted_cutoff2
		$ret->[$i][24] = $hmm_data->{$chado_hmm}->{'noise_cutoff2'};  #noise_cutoff2
		$ret->[$i][25] = $hmm_data->{$chado_hmm}->{'gathering_cutoff'}; # gathering_cutoff
		$ret->[$i][26] = $hmm_data->{$chado_hmm}->{'gathering_cutoff2'};# gathering_cutoff2
	}
	return $ret;
}

sub do_delete_feat_score_evidence {
    my ($self, $gene_id, $seq_id) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
}

sub do_delete_feat_score_ORF_attribute {
    my ($self, $gene_id, $seq_id) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
}

sub do_delete_score_text {
    my ($self, $gene_id) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
}

sub do_delete_evidence_for_gene_id {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE evidence ".
            "FROM asm_feature f, evidence e ".
        "WHERE f.feat_name = e.feat_name ".
        "AND f.asmbl_id = ? ".
        "AND f.feat_name = ? ";

    $self->_set_values($query, $seq_id, $gene_id);
}

sub do_delete_ORF_attribute_for_gene_id {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE ORF_attribute ".
            "FROM asm_feature f, ORF_attribute o ".
        "WHERE f.feat_name = o.feat_name ".
        "AND f.asmbl_id = ? ".
        "AND f.feat_name = ? ";

    $self->_set_values($query, $seq_id, $gene_id);
}

sub do_delete_ident_for_gene_id {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @feature_id = $self->get_feature_id($gene_id);

    my $query = "DELETE FROM featureprop ".
            "WHERE feature_id = $feature_id[0][0] ";

    #$self->_set_values($query);
}

sub do_delete_role_link_for_gene_id {
    my ($self, $gene_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');
    my @feature_id = $self->get_feature_id($gene_id);

    my $query = "SELECT c.cvterm_id ".
            "FROM feature t, feature a, featureloc fl, cvterm c, cv cv, ".
        "feature_cvterm fc, cvterm_dbxref cd, dbxref d ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND a.uniquename = '$seq_id' ".
        "AND t.feature_id = fc.feature_id ".
        "AND fc.cvterm_id = c.cvterm_id ".
        "AND c.cvterm_id = cd.cvterm_id ".
        "AND cd.dbxref_id = d.dbxref_id ".
        "AND c.cv_id = cv.cv_id ".
        "AND cv.name = 'TIGR_role' ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND a.type_id = $as_id[0][0] ";

    my $ret = $self->_get_results_ref($query);
    for(my $i=0; $i<@$ret; $i++) {
    my $cvterm_id = $ret->[$i][0];
    my $feature_cvterm_id = $self->row_exists('feature_cvterm', 'feature_cvterm_id', 'cvterm_id', $feature_id[0][0], $cvterm_id);
    my $feature_cvtermprop_id = $self->get_feature_cvtermprop_id($feature_cvterm_id);

    if($feature_cvtermprop_id) {
        my $query2 = "DELETE FROM feature_cvtermprop WHERE feature_cvtermprop_id = $feature_cvtermprop_id ";
        #$self->_set_values($query2);
    }

    if($feature_cvterm_id) {
        my $query3 = "DELETE FROM feature_cvterm WHERE feature_cvterm_id = $feature_cvterm_id ";
        #$self->_set_values($query3);
    }
    }
}

sub do_delete_frameshift_for_gene_id {
    my ($self, $gene_id) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
}

sub do_validate_frameshift {
    my ($self, $fs) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @fr = $self->get_cv_term('frameshift');
    my $frameshift_cvterm_id = $fr[0][0];
    my @li = $self->get_cv_term('located_in');
    my $located_in_cvterm_id = $li[0][0];
    my $frameshift_id = $fs->{'frameshift_id'};
    
    my $fs_id = $fs->{'frameshift_name'};
    $fs_id =~ /(.+)\.(\d+)/;
    my $new_fs_id = $1.'.'.($2+1);
    if(!$fs->{'is_obsolete'}) {

        my @fid = $self->get_feature_id($new_fs_id);
        if(!$fid[0][0]) {
            # Step 1: Insert the new feature.
            my $query = qq{
                INSERT INTO feature (feature_id, uniquename, type_id, seqlen, organism_id, is_obsolete, is_analysis)
                SELECT max(feature_id)+1, ?, ?, ?, ?,0,0 from feature
            };
            $self->_set_values($query,$new_fs_id,$frameshift_cvterm_id, $fs->{'seqlen'}, $fs->{'organism_id'});

            
            my @fid = $self->get_feature_id($new_fs_id);
            # Step 2: Insert the featureloc
            my $query = qq{
              INSERT INTO featureloc (featureloc_id, feature_id, srcfeature_id, fmin, fmax,strand)
              SELECT max(fl.featureloc_id)+1, ?, ?, ?, ?, ? from featureloc fl
            };
            $self->_set_values($query,$fid[0][0], $fs->{'assembly_id'}, $fs->{'fmin'}, $fs->{'fmax'},$fs->{'frameshift_strand'});
            # Step 3: Insert the feature_relationship. NOTE that this is a relationship to the transcript of type 'located_in'
            my $query = qq{
              INSERT INTO feature_relationship (feature_relationship_id, subject_id, object_id, type_id)
              SELECT max(fr.feature_relationship_id)+1, ?, ?, ? from feature_relationship fr
            };
            $self->_set_values($query,$fid[0][0],$fs->{'gene_id'},$located_in_cvterm_id);
            
            # Step 4: Mark the old object as is_obsolete=1
            my $query = qq{
                UPDATE feature set is_obsolete=1 where feature_id = ?
            };
            $self->_set_values($query,$fs->{'frameshift_id'});
            
        }
    }
    return $new_fs_id;
}

sub do_ignore_frameshift {
    my ($self, $fs) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @li = $self->get_cv_term('located_in');
    my $located_in_cvterm_id = $li[0][0];
    my $frameshift_id = $fs->{'frameshift_id'};
    my $query = qq{
        UPDATE feature set is_obsolete=1 where feature_id = ?
    };
    $self->_set_values($query,$frameshift_id);
}

sub do_unignore_frameshift {
    my ($self, $fs) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @li = $self->get_cv_term('located_in');
    my $located_in_cvterm_id = $li[0][0];
    my $frameshift_id = $fs->{'frameshift_id'};
    my $query = qq{
        UPDATE feature set is_obsolete=0 where feature_id = ?
    };
    $self->_set_values($query,$frameshift_id);
}

sub do_invalidate_frameshift {
    my ($self, $fs) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @fr = $self->get_cv_term('frameshift');
    my $frameshift_cvterm_id = $fr[0][0];
    my @li = $self->get_cv_term('located_in');
    my $located_in_cvterm_id = $li[0][0];
    my $frameshift_id = $fs->{'frameshift_id'};
    
    my $fs_id = $fs->{'frameshift_name'};
    $fs_id =~ /(.+)\.(\d+)/;
    my $old_fs_id = $1.'.'.($2-1);
    if(!$fs->{'is_obsolete'}) {

        my @fid = $self->get_feature_id($old_fs_id);
        if($fid[0][0]) {

            # Step 1: delete feature_relationship. NOTE that this is a relationship to the transcript of type 'located_in'
            my $query = qq{
                delete from feature_relationship where subject_id = ?
            };
           $self->_set_values($query,$fs->{'frameshift_id'});
            
            # Step 2: delete featureloc
            my $query = qq{
                delete from featureloc where feature_id = ?
            };
            $self->_set_values($query,$fs->{'frameshift_id'});

            # Step 3: delete feature.
            my $query = qq{
                delete from feature where feature_id = ?
            };
            $self->_set_values($query,$fs->{'frameshift_id'});

            # Step 4: Mark the old object as is_obsolete=0
            my $query = qq{
                UPDATE feature set is_obsolete=0 where feature_id = ?
            };
            $self->_set_values($query,$fid[0][0]);
            
        }
    }
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

sub do_delete_GO_for_gene_id {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    $self->do_delete_GO_id($gene_id);
    $self->do_update_auto_annotate($gene_id, $db);
}

sub get_hmm_data_lookup {
	my ($self) = @_;
	my %hmms;
	my $file = $ENV{HMM_LOOKUP_FILE};
	my $dbm = tie %hmms, 'MLDBM', $file, O_RDONLY or die "Can't tie lookup file - $file: $!";
	return \%hmms;
}

sub get_GO_id_to_term {
    my($self, $GO_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

	my $query = "SELECT d.accession, c.name, cv.name ".
		        "FROM cv, cvterm c, dbxref d ".
				"WHERE d.accession = '$GO_id' ".
				"AND d.dbxref_id = c.dbxref_id ".
				"AND c.cv_id = cv.cv_id ".
				"AND cv.name IN ('process', 'function', 'component', 'biological_process', 'molecular_function', 'cellular_component') ";

    return $self->_get_results_ref($query);
}

sub get_tigrfam2roles_lookup_data {
	my ($self) = @_;
	my %roles;
	my $file = $ENV{TFAM_ROLES_LOOKUP_FILE};
	my $dbm = tie %roles, 'MLDBM', $file, O_RDONLY or die "Can't tie lookup file - $file: $!";
	return \%roles;
}

sub get_pfam2roles_lookup_data {
	my ($self) = @_;
	my %roles;
	my $file = $ENV{PFAM_ROLES_LOOKUP_FILE};
	my $dbm = tie %roles, 'MLDBM', $file, O_RDONLY or die "Can't tie lookup file - $file: $!";
	return \%roles;
}

1;
