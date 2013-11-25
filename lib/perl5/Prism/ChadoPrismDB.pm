package Prism::ChadoPrismDB;

use strict;
use base qw(Prism::PrismDB);
use Data::Dumper;

sub test_ChadoPrismDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_PrismDB();
}

sub testProjDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_ChadoPrismDB();

}

#---------------------------------------------------------------
# getMaxId
#
#---------------------------------------------------------------
sub getMaxId{

    my ($self, $table, $key) = @_;

    # this routine is for the TableIdManager

    $self->{_logger}->logdie("table was not defined") if (!defined($table));
    $self->{_logger}->logdie("key was not defined")   if (!defined($key));
    
    my $query = "SELECT max($key) " .
	"FROM $table ";

    ## this should never be cached - JO
    $self->{_use_cache} = 0;
    my @res = $self->_get_results($query);
    $self->{_use_cache} = 1;
    return @res;
}

 
#---------------------------------------------------------------
# get_cvterm_id
#
#---------------------------------------------------------------
sub get_cvterm_id {

    my($self, $term) = @_;

    $self->{_logger}->logdie("term was not defined") if (!defined($term));

    $term = lc($term);

    my $query = "SELECT cvterm_id ".
	"FROM cvterm c ".
	"WHERE lower(name) = ? ";
    
    my @result = $self->_get_results($query,$term);

    my $cvterm_id = $result[0][0];

    if ($cvterm_id =~ /^\d+$/){
	return $cvterm_id;
    }
    else{
	$self->{_logger}->fatal("cvterm_id was not found for cvterm.name = '$term' OR cvterm_id '$cvterm_id' is not an integer");
	return undef;
    }
    
}


#---------------------------------------------------------------
# get_table_record_count
#
#---------------------------------------------------------------
sub get_table_record_count {

    my ($self,$table) = @_;

    $self->{_logger}->logdie("table was not defined") if (!defined($table));

    my $query = "SELECT count(*) ".
    "FROM $table";

    return $self->_get_results($query);

}


#---------------------------------------------------------------
# get_seq_id_to_description
#
#---------------------------------------------------------------
sub get_seq_id_to_description {

    my ($self, $seq_id, $assembly_cvterm_id) = @_;

    $self->{_logger}->logdie("seq_id was not defined") if (!defined($seq_id));

    if (!defined($assembly_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_so('assembly');
	$assembly_cvterm_id = $ret->[0][0];
	if (!defined($assembly_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'assembly' ontology 'SO'");
	}
    }

    
    my $maxsizequery = "SELECT datalength(f.residues) ".
	"FROM feature f ".
	"WHERE f.type_id = ? ".
	"AND f.uniquename = ?";

    my @maxsize = $self->_get_results($maxsizequery, $assembly_cvterm_id, $seq_id);
    
    $self->do_set_textsize($maxsize[0][0]);

    my $query = "SELECT f.uniquename,f.uniquename,f.seqlen,f.residues,'circular' ".
	        "FROM feature f ".
		"WHERE f.type_id = ? ".
		"AND f.uniquename = ? ";

    return $self->_get_results_ref(
				   $query, 
				   $assembly_cvterm_id, 
				   $seq_id
				   );
}

#---------------------------------------------------------------
# get_seq_id_to_description_2
#
#---------------------------------------------------------------
sub get_seq_id_to_description_2 {

    my ($self, $seq_id, $assembly_cvterm_id) = @_;

    $self->{_logger}->logdie("seq_id was not defined") if (!defined($seq_id));

    if (!defined($assembly_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_so('assembly');
	$assembly_cvterm_id = $ret->[0][0];
	if (!defined($assembly_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'assembly' ontology 'SO'");
	}
    }

    my $query = "SELECT f.uniquename,f.uniquename,f.seqlen,'circular' ".
	        "FROM feature f ".
		"WHERE f.type_id = ? ".
		"AND f.uniquename = ? ";

    return $self->_get_results_ref(
				   $query, 
				   $assembly_cvterm_id, 
				   $seq_id
				   );
}

#---------------------------------------------------------------
# get_seq_id_to_genes
#
#---------------------------------------------------------------
sub get_seq_id_to_genes {


    my ($self, $seq_id, $assembly_cvterm_id, $gene_cvterm_id, $part_of_cvterm_id, $transcript_cvterm_id) = @_;

    $self->{_logger}->logdie("seq_id was not defined")     if (!defined($seq_id));
    

    if (!defined($assembly_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_so('assembly');
	$assembly_cvterm_id = $ret->[0][0];
	if (!defined($assembly_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'assembly' ontology 'SO'");
	}
    }

    if (!defined($gene_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_so('gene');
	$gene_cvterm_id = $ret->[0][0];
	if (!defined($gene_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'gene' ontology 'SO'");
	}
    }

    if (!defined($part_of_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_typedef('part_of');
	$part_of_cvterm_id = $ret->[0][0];
	if (!defined($part_of_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'part_of' ontology 'Relation_typedef.ontology'");
	}
    }

    if (!defined($transcript_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_so('transcript');
	$transcript_cvterm_id = $ret->[0][0];
	if (!defined($transcript_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'transcript' ontology 'SO'");
	}
    }

    
    my $query = "SELECT f.uniquename, t.uniquename ,fl.fmin,fl.fmax, fl.strand ".
	"FROM feature f, feature s, feature t, featureloc fl, feature_relationship fr ".
	"WHERE t.feature_id = fl.feature_id ".
	"AND s.feature_id = fl.srcfeature_id ".
	"AND f.type_id = ? ".
	"AND s.type_id = ? ".
	"AND t.type_id = ? ".
	"AND fr.subject_id = t.feature_id ".
	"AND fr.object_id = f.feature_id ".
	"AND fr.type_id = ? ".
	"AND s.uniquename = ? ";

    return $self->_get_results_ref(
				   $query, 
				   $gene_cvterm_id, 
				   $assembly_cvterm_id,
				   $transcript_cvterm_id,
				   $part_of_cvterm_id,
				   $seq_id
				   );
}


#---------------------------------------------------------------
# get_seq_id_to_exons
#
#---------------------------------------------------------------
sub get_seq_id_to_exons {

    my ($self, $seq_id, $assembly_cvterm_id, $exon_cvterm_id, $transcript_cvterm_id, $part_of_cvterm_id) = @_;

    if (!defined($seq_id)){
	$self->{_logger}->logdie("seq_id was not defined");
    }
    if (!defined($assembly_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_so('assembly');
	$assembly_cvterm_id = $ret->[0][0];
	if (!defined($assembly_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'assembly' ontology 'SO'");
	}
    }

    if (!defined($exon_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_so('exon');
	$exon_cvterm_id = $ret->[0][0];
	if (!defined($exon_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'exon' ontology 'SO'");
	}
    }

    if (!defined($transcript_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_so('transcript');
	$transcript_cvterm_id = $ret->[0][0];
	if (!defined($transcript_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'transcript' ontology 'SO'");
	}
    }
    
    if (!defined($part_of_cvterm_id)){
	$part_of_cvterm_id = $self->get_cvterm_id('part_of');
	if (!defined($part_of_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'part_of' ontology 'Relation_typedef.ontology'");
	}
    }


    my $query = "SELECT t.uniquename,t.uniquename,f.uniquename,fl.fmin,fl.fmax, fl.strand ".
	"FROM feature f, feature s, feature t, feature_relationship fr, featureloc fl ".
	"WHERE f.feature_id = fl.feature_id ".
	"AND s.feature_id = fl.srcfeature_id ".
	"AND fr.subject_id = f.feature_id ".
	"AND fr.object_id = t.feature_id ".
	"AND fr.type_id = ? ".
	"AND t.type_id = ? ".
	"AND f.type_id = ? ".
	"AND s.type_id = ? ".
	"AND s.uniquename = ? ";
    

    return $self->_get_results_ref(
				   $query,
				   $part_of_cvterm_id,
				   $transcript_cvterm_id,
				   $exon_cvterm_id,
				   $assembly_cvterm_id,
				   $seq_id
				   );
     
}

#---------------------------------------------------------------
# get_seq_id_to_CDS
#
#---------------------------------------------------------------
sub get_seq_id_to_CDS {

    my ($self, $seq_id, $assembly_cvterm_id, $cds_cvterm_id, $polypeptide_cvterm_id, $transcript_cvterm_id, $derives_from_cvterm_id) = @_;

    $self->{_logger}->logdie("seq_id was not defined") if (!defined($seq_id));
    
    if (!defined($assembly_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_so('assembly');
	$assembly_cvterm_id = $ret->[0][0];
	if (!defined($assembly_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'assembly' ontology 'SO'");
	}
    }

    if (!defined($cds_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_so('CDS');
	$cds_cvterm_id = $ret->[0][0];
	if (!defined($cds_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'CDS' ontology 'SO'");
	}
    }

    if (!defined($polypeptide_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_so('polypeptide');
	$polypeptide_cvterm_id = $ret->[0][0];
	if (!defined($polypeptide_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'polypeptide' ontology 'SO'");
	}
    }

    if (!defined($transcript_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_so('transcript');
	$transcript_cvterm_id = $ret->[0][0];
	if (!defined($transcript_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'transcript' ontology 'SO'");
	}
    }

    if (!defined($derives_from_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_typedef('derives_from');
	$derives_from_cvterm_id = $ret->[0][0];
	if (!defined($derives_from_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'derives_from' ontology 'Relation_typedef.ontology'");
	}
    }

    ## The chado2bsml.pl script needs to exclude polypeptides which are associated to pseudogenes.
    my $gene_cvterm_id;
    my $pseudogene_cvterm_id;
    
    if (!defined($gene_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_so('gene');
	$gene_cvterm_id = $ret->[0][0];
	if (!defined($gene_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'gene' ontology 'SO'");
	}
    }

    if (!defined($pseudogene_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_so('pseudogene');
	$pseudogene_cvterm_id = $ret->[0][0];
	if (!defined($pseudogene_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'pseudogene' ontology 'SO'");
	}
    }
    

    
    my $query = "SELECT t.uniquename,t.uniquename,f.uniquename,p.uniquename,fl.fmin,fl.fmax,fl.strand, p.residues ".
	"FROM feature f, feature s, feature t, feature p, feature_relationship fr,  feature_relationship fr2, featureloc fl, feature g, feature_relationship fr3 ".
	"WHERE f.feature_id = fl.feature_id ".
	"AND s.feature_id = fl.srcfeature_id ".
	"AND fr.subject_id = f.feature_id ".
	"AND fr.object_id = t.feature_id ".
	"AND fr2.subject_id = p.feature_id ".
	"AND fr2.object_id = f.feature_id ".
	"AND fr2.type_id = ? ".
	"AND fr.type_id = ? ".
	"AND t.type_id = ? ".
	"AND f.type_id = ? ".
	"AND s.type_id = ? ".
	"AND p.type_id = ? ".
	"AND p.seqlen != 0 ".
	"AND s.uniquename = ? ".
	"AND g.type_id = ? ".
	"AND g.feature_id = fr3.object_id ".
	"AND fr3.subject_id = t.feature_id ".
	"AND NOT EXISTS ( ".
	"SELECT 1 ".
	"FROM feature_cvterm fc ".
	"WHERE fc.feature_id = g.feature_id ".
	"AND fc.cvterm_id = ? )";
    
   
    return $self->_get_results_ref(
				   $query,
				   $derives_from_cvterm_id,
				   $derives_from_cvterm_id,
				   $transcript_cvterm_id,
				   $cds_cvterm_id,
				   $assembly_cvterm_id,
				   $polypeptide_cvterm_id,
				   $seq_id,
				   $gene_cvterm_id,
				   $pseudogene_cvterm_id
				   );
        
}

#---------------------------------------------------------------
# get_org_id_to_seq_names
#
#
#---------------------------------------------------------------
sub get_org_id_to_seq_names {

    my($self, $organism_abbreviation, $assembly_cvterm_id) = @_;


    if (!defined($organism_abbreviation)){
	$self->{_logger}->logdie("organism_abbreviation was not defined");
    }
    if (!defined($assembly_cvterm_id)){
	my $ret = $self->get_cvterm_id_from_so('assembly');
	$assembly_cvterm_id = $ret->[0][0];
	if (!defined($assembly_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'assembly' ontology 'SO'");
	}
    }

    my $query = "SELECT s.uniquename, s.uniquename, 'circular', datalength(s.residues) ".
	"FROM feature s, organism o ".
	"WHERE s.type_id = ? ".
	"AND s.organism_id = o.organism_id ".
	"AND o.abbreviation = ? ";

    return $self->_get_results(
			       $query,
			       $assembly_cvterm_id,
			       $organism_abbreviation
			       );
}

#---------------------------------------------------------------
# get_feature_orgseq
#
#---------------------------------------------------------------
sub get_feature_orgseq {

    my($self) = @_;

    my $cds_cvterm_id      = $self->get_cvterm_id('CDS');
    my $polypeptide_cvterm_id  = $self->get_cvterm_id('polypeptide');
    my $assembly_cvterm_id = $self->get_cvterm_id('assembly'); 

    my $query = "SELECT f.feature_id,f.seqlen,f.organism_id,f.uniquename ".
    "FROM feature f ".
    "WHERE f.type_id = $cds_cvterm_id ".
    "OR f.type_id = $polypeptide_cvterm_id ".
    "OR f.type_id = $assembly_cvterm_id ";
    
    return $self->_get_results_ref($query);

}

#--------------------------------------------------------------
# get_master_feature_id_lookup()
#
#---------------------------------------------------------------
sub get_master_feature_id_lookup {

    my($self, $doctype, $chromosome) = @_;

    $self->{_logger}->logdie("chromosome was not defined") if (!defined($chromosome));
    
    my $query = "SELECT f.uniquename, f.feature_id ".
    "FROM feature f ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f2, cvterm c1, cvterm c2 ".
    "WHERE f2.feature_id = f.feature_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f2.type_id = c1.cvterm_id OR ".
    "f2.type_id = c2.cvterm_id )) ";
    
    print "Retrieving all feature records where the type is neither 'match' nor 'match_part'\n";

    return $self->_get_lookup_db($query);
}

#---------------------------------------------------------------
# get_uniquename_2_feature_id()
#
#---------------------------------------------------------------
sub get_uniquename_2_feature_id {


    my($self) = @_;

    my $cds_cvterm_id      = $self->get_cvterm_id('CDS');
    my $polypeptide_cvterm_id  = $self->get_cvterm_id('polypeptide');
    my $assembly_cvterm_id = $self->get_cvterm_id('assembly'); 

    my $query = "SELECT f.feature_id, f.uniquename ".
	"FROM feature f ".
	"WHERE f.type_id = $cds_cvterm_id OR f.type_id = $polypeptide_cvterm_id OR f.type_id = $assembly_cvterm_id ";

    return $self->_get_results_ref($query);
}

#-----------------------------------------------------------------------------
# get_db_to_seq_names()
#
#
#-----------------------------------------------------------------------------
sub get_db_to_seq_names {

    my($self, $db, $assembly_cvterm_id) = @_;

    if (!defined($db)){
	$self->{_logger}->warn("db was not defined");
    }
    if (!defined($assembly_cvterm_id)){
	$assembly_cvterm_id = $self->get_cvterm_id('assembly');
	if (!defined($assembly_cvterm_id)){
	    $self->{_logger}->logdie("assembly_cvterm_id was not defined");
	}
    }

    my $query = "SELECT s.uniquename,s.uniquename,'circular',datalength(s.residues) ".
	"FROM feature s ".
	"WHERE s.type_id = $assembly_cvterm_id ";

    return $self->_get_results($query);
}

#-----------------------------------------------------------------------------
# get_protein_2_contig_localization()
#
#-----------------------------------------------------------------------------
sub get_protein_2_contig_localization {


    my ($self) = @_;

    my $assembly_cvterm_id    = $self->get_cvterm_id("assembly");
    my $polypeptide_cvterm_id     = $self->get_cvterm_id("polypeptide");
    my $derives_from_cvterm_id = $self->get_cvterm_id("derives_from");
    my $cds_cvterm_id         = $self->get_cvterm_id("CDS");

    if (!defined($assembly_cvterm_id)){
	$self->{_logger}->logdie("assembly_cvterm_id was not defined");
    }
    if (!defined($polypeptide_cvterm_id)){
	$self->{_logger}->logdie("polypeptide_cvterm_id was not defined");
    }
    if (!defined($derives_from_cvterm_id)){
	$self->{_logger}->logdie("derives_from_cvterm_id was not defined");
    }
    if (!defined($cds_cvterm_id)){
	$self->{_logger}->logdie("cds_cvterm_id was not defined");
    }

    my $query = "SELECT p.feature_id, a.feature_id, fl.fmin, fl.is_fmin_partial, fl.fmax, fl.is_fmax_partial, fl.strand, fl.phase, fl.residue_info, fl.locgroup, fl.rank ".
	"FROM feature c, feature a, feature p, feature_relationship fp, featureloc fl ".
	"WHERE fp.subject_id = p.feature_id  ".
	"AND fp.object_id = c.feature_id ".
	"AND fp.type_id = $derives_from_cvterm_id ".
	"AND c.feature_id = fl.feature_id ".
	"AND a.feature_id = fl.srcfeature_id ".
	"AND a.type_id = $assembly_cvterm_id ".
	"AND p.type_id = $polypeptide_cvterm_id ".
	"AND c.type_id = $cds_cvterm_id ";

    return $self->_get_results($query);

}

#---------------------------------------------------------------
# get_source_database_to_organism_rows()
#
#---------------------------------------------------------------
sub get_source_database_to_organism_rows {

    my($self) = @_;

    my $query = "SELECT o.genus, o.species, db.name, o.abbreviation ".
	"FROM organism o, organism_dbxref od, dbxref dx, db ".
	"WHERE o.organism_id = od.organism_id ".
	"AND od.dbxref_id = dx.dbxref_id ".
	"AND dx.db_id = db.db_id ";

    return $self->_get_results_ref($query);

}



#---------------------------------------------------------------
# get_analysis_id()
#
#---------------------------------------------------------------
sub get_analysis_id {


    my ($self, %parameter) = @_;

    $self->{_logger}->logdie("self was not defined") if (!defined($self));

    my $parameter_hash = \%parameter;
    my $sourcename = $parameter_hash->{'sourcename'} if (exists $parameter_hash->{'sourcename'});

    $self->{_logger}->logdie("sourcename was not defined") if (!defined($sourcename));

    
    my $query = "SELECT a.analysis_id ".
	"FROM analysis a ".
	"WHERE a.sourcename = ? ";

    
    return $self->_get_results_ref($query, $$sourcename);


}#end sub get_analysis_id()



#---------------------------------------------------------------
# get_db_id()
#
#---------------------------------------------------------------
sub get_db_id {

    my ($self, %parameter) = @_;

    $self->{_logger}->logdie("self was not defined") if (!defined($self));

    my $parameter_hash = \%parameter;
    my $organism = $parameter_hash->{'organism'} if (exists $parameter_hash->{'organism'});

    $self->{_logger}->logdie("organism was not defined") if (!defined($organism));

    my $query = "SELECT db.db_id ".
	"FROM db ".
	"WHERE db.name like '%$organism' ";

    return $self->_get_results_ref($query);


}#end sub get_db_id()




#-----------------------------------------------------------------------------
# get_protein_assembly_lookup()
#
#-----------------------------------------------------------------------------
sub get_protein_assembly_lookup {


    my ($self) = @_;

    my $assembly_cvterm_id    = $self->get_cvterm_id("assembly");
    my $polypeptide_cvterm_id     = $self->get_cvterm_id("polypeptide");


    $self->{_logger}->logdie("assembly_cvterm_id was not defined") if (!defined($assembly_cvterm_id));
    $self->{_logger}->logdie("polypeptide_cvterm_id was not defined")  if (!defined($polypeptide_cvterm_id));


    my $query = "SELECT fl.feature_id, fl.srcfeature_id ".
	"FROM feature a, feature p, featureloc fl ".
	"WHERE fl.feature_id = p.feature_id ".
	"AND p.type_id = $polypeptide_cvterm_id ".
	"AND fl.srcfeature_id = a.feature_id ".
	"AND a.type_id = $assembly_cvterm_id ";


    return $self->_get_results($query);

}

#---------------------------------------------------------------
# get_assembly_feature_id_lookup()
#
#---------------------------------------------------------------
sub get_assembly_feature_id_lookup {

    my($self) = @_;

    my $assembly_cvterm_id = $self->get_cvterm_id('assembly'); 
    $self->{_logger}->logdie("assembly_cvterm_id was not defined") if (!defined($assembly_cvterm_id));

    my $chromosome_cvterm_id = $self->get_cvterm_id('chromosome'); 
    $self->{_logger}->logdie("chromosome_cvterm_id was not defined") if (!defined($chromosome_cvterm_id));

    
    my $query = "SELECT f.feature_id, f.uniquename, f.organism_id, fp.value ".
	"FROM feature f, featureprop fp ".
	"WHERE f.type_id = ? ".
	"AND f.feature_id = fp.feature_id ".
	"AND fp.type_id = ? ";

    return $self->_get_results_ref($query, $assembly_cvterm_id, $chromosome_cvterm_id);

}

#---------------------------------------------------------------
# get_assembly_and_scaffold_feature_id_lookup()
#
#---------------------------------------------------------------
sub get_assembly_and_scaffold_feature_id_lookup {

    my($self) = @_;

    my $assembly_cvterm_id = $self->get_cvterm_id('assembly'); 
    my $scaffold_cvterm_id = $self->get_cvterm_id('supercontig'); 
    my $chromosome_cvterm_id = $self->get_cvterm_id('chromosome'); 
    
    my $query = "SELECT f.feature_id, f.uniquename, f.organism_id, fp.value ".
    "FROM feature f, featureprop fp ".
    "WHERE (f.type_id = $assembly_cvterm_id OR f.type_id = $scaffold_cvterm_id) ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.type_id = $chromosome_cvterm_id ";
    
    return $self->_get_results_ref($query);

}






#---------------------------------------------------------------
# get_cv_id_by_name()
#
#---------------------------------------------------------------
sub get_cv_id_by_name {

    my($self, $name) = @_;

    $self->{_logger}->logdie("term was not defined") if (!defined($name));

    my $query = "SELECT cv_id ".
	"FROM cv ".
	"WHERE name = ? ";
    
    my @result = $self->_get_results($query,$name);

    my $cv_id = $result[0][0];
    if ($cv_id =~ /^\d+$/){
	return $cv_id;
    }
    else{
	return undef;
    }

}


#---------------------------------------------------------------
# get_db_id_by_name()
#
#---------------------------------------------------------------
sub get_db_id_by_name {

    my($self, $name) = @_;

    $self->{_logger}->logdie("name was not defined") if (!defined($name));

    my $query = "SELECT db_id ".
	"FROM db ".
	"WHERE name = ? ";
    
    my @result = $self->_get_results($query,$name);

    my $db_id = $result[0][0];
    if ($db_id =~ /^\d+$/){
	return $db_id;
    }
    else{
	return undef;
    }

}

#---------------------------------------------------------------
# get_cvterm_relationship_id()
#
#---------------------------------------------------------------
sub get_cvterm_relationship_id {

    my($self, $object_id, $subject_id, $type_id) = @_;

    $self->{_logger}->logdie("subject_id was not defined") if (!defined($subject_id));
    $self->{_logger}->logdie("type_id was not defined")    if (!defined($type_id));
    $self->{_logger}->logdie("object_id was not defined")  if (!defined($object_id));

    my $query = "SELECT cvterm_relationship_id ".
	"FROM cvterm_relationship ".
	"WHERE subject_id = ? ".
	"AND object_id = ? ".
	"AND type_id = ? ";
    
    my @result = $self->_get_results($query,$subject_id, $object_id, $type_id);

    my $cvterm_relationship_id = $result[0][0];
    if ($cvterm_relationship_id =~ /^\d+$/){
	return $cvterm_relationship_id;
    }
    else{
	return undef;
    }

}

#---------------------------------------------------------------
# get_cvterm_dbxref_id()
#
#---------------------------------------------------------------
sub get_cvterm_dbxref_id {

    my($self, $cvterm_id, $dbxref_id) = @_;

    $self->{_logger}->logdie("cvterm_id was not defined") if (!defined($cvterm_id));
    $self->{_logger}->logdie("dbxref_id was not defined")    if (!defined($dbxref_id));


    my $query = "SELECT cvterm_dbxref_id ".
	"FROM cvterm_dbxref ".
	"WHERE cvterm_id = ? ".
	"AND dbxref_id = ? ";
    
    my @result = $self->_get_results($query, $cvterm_id, $dbxref_id);


    my $cvterm_dbxref_id = $result[0][0];
    if ($cvterm_dbxref_id =~ /^\d+$/){
	return $cvterm_dbxref_id;
    }
    else{
	return undef;
    }

}

#---------------------------------------------------------------
# get_cvterm_id_by_name()
#
#---------------------------------------------------------------
sub get_cvterm_id_by_name {

    my($self, $term) = @_;

    $self->{_logger}->logdie("term was not defined") if (!defined($term));

    $term = lc($term);


    my $query = "SELECT cvterm_id ".
	"FROM cvterm c ".
	"WHERE lower(name) = ? ".
	"AND is_obsolete = 0 ";
    
    my @result = $self->_get_results($query,$term);

    my $cvterm_id = $result[0][0];

   if ($cvterm_id =~ /^\d+$/){
	return $cvterm_id;
    }
    else{
	return undef;
    }

}

#---------------------------------------------------------------
# get_ontology_lookup()
#
#---------------------------------------------------------------
sub get_ontology_lookup {

    my($self) = @_;

    my $query = "SELECT db.name, d.accession, c.definition, db.db_id, d.dbxref_id, c.cvterm_id ".
	"FROM db, dbxref d, cvterm c ".
	"WHERE db.db_id = d.db_id ".
	"AND c.dbxref_id = d.dbxref_id";

    return  $self->_get_results_ref($query);

}


#---------------------------------------------------------------
# get_cvterm_dbxref_lookup()
#
#---------------------------------------------------------------
sub get_cvterm_dbxref_lookup {

    my($self) = @_;

    my $query = "SELECT cvterm_id, dbxref_id, cvterm_dbxref_id ".
    "FROM cvterm_dbxref ";

    return  $self->_get_results_ref($query);
    
}


#---------------------------------------------------------------
# get_features_by_assembly_id()
#
#
#---------------------------------------------------------------
sub get_features_by_assembly_id {
    
    my ($self, $feature_id) = @_;
    
    $self->{_logger}->logdie("feature_id was not defined") if (!defined($feature_id));

    my $query = "SELECT fl.fmin, fl.fmax, fl.strand, f.uniquename, fl.feature_id, fl.phase, fl.residue_info, fl.rank, f.type_id ".
	"FROM feature a, featureloc fl, feature f ".
	"WHERE a.feature_id = ? ".
	"AND a.feature_id = fl.srcfeature_id ".
	"AND fl.feature_id = f.feature_id"; 

    return $self->_get_results($query, $feature_id);

}


#---------------------------------------------------------------
# get_scaffold_2_contig_lookup()
#
#---------------------------------------------------------------
sub get_scaffold_2_contig_lookup {

    my($self, $scaffold_uniquename) = @_;

    my $supercontig_cvterm_id = $self->get_cvterm_id('supercontig');
    if (!defined($supercontig_cvterm_id)){
	$self->{_logger}->logdie("supercontig_cvterm_id was not defined");
    }

    my $assembly_cvterm_id = $self->get_cvterm_id('assembly'); 
    if (!defined($assembly_cvterm_id)){
	$self->{_logger}->logdie("assembly_cvterm_id was not defined");
    }

    #
    # Retrieve the supercontig and assembly information for which:
    # the assembly is localized the the supercontig,
    # and the subfeatures are localized to the assembly,
    # but the subfeatures are NOT localized to the supercontig
    #
    my $query = "select sc.feature_id, sc.uniquename, ac.feature_id, ac.uniquename, fl.fmin, fl.fmax, fl.strand ".
    "from feature sc, feature ac, featureloc fl ".
    "where sc.type_id = ? ".
    "and ac.type_id = ? ".
    "and ac.feature_id = fl.feature_id ".
    "and sc.feature_id = fl.srcfeature_id ".
    "and ac.feature_id in ".
    "(select a.feature_id ".
    "from feature a, featureloc fl1, feature c ".
    "where a.type_id = ? ".
    "and c.feature_id = fl1.feature_id ".
    "and a.feature_id = fl1.srcfeature_id ".
    "and not exists ( ".
    "select 1 ".
    "from featureloc fl2, feature s ".
    "where fl2.feature_id = c.feature_id ".
    "and fl2.srcfeature_id = s.feature_id ".
    "and s.type_id = ? )) ";

    my $res =  $self->_get_results_ref($query, $supercontig_cvterm_id, $assembly_cvterm_id, $assembly_cvterm_id, $supercontig_cvterm_id);
    return $res;
}

#-----------------------------------------------------------------
# get_subfeature_lookup()
#
#-----------------------------------------------------------------
sub get_subfeature_lookup {

    my ($self, $scaffold_id) = @_;

    $self->{_logger}->logdie("scaffold_id was not defined") if (!defined($scaffold_id));
    

    #
    # Retrieve cvterms for assembly and supercontig
    #
    my $assembly_cvterm_id = $self->get_cvterm_id('assembly');
    $self->{_logger}->logdie("assembly_cvterm_id was not defined") if (!defined($assembly_cvterm_id));

    my $supercontig_cvterm_id = $self->get_cvterm_id('supercontig');
    $self->{_logger}->logdie("supercontig_cvterm_id was not defined") if (!defined($supercontig_cvterm_id));

    #
    # Retrieve the supercontig, assembly and subfeature information for which:
    # the assembly is localized to the supercontig, 
    # and the subfeatures are localized to the assembly, 
    # but the subfeatures are NOT localized the supercontig
    #
    my $query = "SELECT s.feature_id, a.feature_id, a.uniquename, fl.fmin, fl.fmax, fl.strand, f.uniquename, fl.feature_id, fl.phase, fl.residue_info, fl.rank, f.type_id ".
	"FROM feature a, featureloc fl, feature f, featureloc fls, feature s ".
	"WHERE a.type_id = ? ".
	"AND s.type_id = ? ".
	"AND s.feature_id = ? ".
	"AND s.feature_id = fls.srcfeature_id ".
	"AND fls.feature_id = a.feature_id ".
	"AND a.feature_id = fl.srcfeature_id ".
	"AND fl.feature_id = f.feature_id ".
	"AND NOT EXISTS ".
	"(SELECT 1 ".
	"FROM featureloc fr, feature x ".
	"WHERE x.type_id = ? ".
	"AND x.feature_id = fr.srcfeature_id ".
	"AND fr.feature_id = f.feature_id) ";


    return $self->_get_results_ref($query, $assembly_cvterm_id, $supercontig_cvterm_id, $scaffold_id, $supercontig_cvterm_id);
}



#-----------------------------------------------------------------
# get_feature_relationship_lookup()
#
#-----------------------------------------------------------------
sub get_feature_relationship_lookup {

    my ($self) = @_;

    my $query = "SELECT fr.feature_relationship_id, fr.subject_id, fr.object_id, fr.type_id, c.name, s.type_id, sc.name, o.type_id, oc.name ".
	"FROM feature_relationship fr, feature s, feature o, cvterm c, cvterm sc, cvterm oc ".
	"WHERE fr.subject_id = s.feature_id ".
	"AND fr.object_id = o.feature_id ".
	"AND fr.type_id = c.cvterm_id ".
	"AND s.type_id = sc.cvterm_id ".
	"AND o.type_id = oc.cvterm_id ";

    return $self->_get_results_ref($query);
}

#-----------------------------------------------------------------
# get_cvterm_relationship_lookup()
#
#-----------------------------------------------------------------
sub get_cvterm_relationship_lookup {

    my ($self) = @_;

    my $query = "SELECT cr.cvterm_relationship_id, cr.subject_id, cr.object_id, cr.type_id, cs.name, co.name, c.name ".
	"FROM cvterm_relationship cr, cvterm cs, cvterm co, cvterm c ".
	"WHERE cr.subject_id = cs.cvterm_id ".
	"AND cr.object_id = co.cvterm_id ".
	"AND cr.type_id = c.cvterm_id ";

    return $self->_get_results_ref($query);
}


#-------------------------------------------------------------------------------------------------------------------------------------------------
# get_cvterm_id_from_cvterm()
#  
#-------------------------------------------------------------------------------------------------------------------------------------------------
sub get_cvterm_id_from_cvterm{

    my ($self, %param) = @_;

    my $phash = \%param;

    my $cv_id        = $phash->{'cv_id'}          if (exists $phash->{'cv_id'});
    my $name         = $phash->{'name'}           if (exists $phash->{'name'});
    my $definition   = $phash->{'definition'}     if (exists $phash->{'definition'});
    my $dbxref_id    = $phash->{'dbxref_id'}      if (exists $phash->{'dbxref_id'});


    if (!defined($cv_id)){
	$self->{_logger}->logdie("cv_id was not defined");
	return undef;
    }

    if (!defined($name)){
	$self->{_logger}->logdie("name was not defined");
	return undef;
    }


    $name = lc($name);

    if (($cv_id =~ /;/) or ($name =~ /;/)){
	return undef;
    }


    my $query = "SELECT cvterm_id  ".
	"FROM cvterm ".
	"WHERE lower(name) = ? ".
	"AND cv_id = $cv_id ".
	"ORDER BY is_obsolete ";
    
    $query .= "AND definition  = \'$definition\'" if (defined($definition));
    $query .= "AND dbxref_id  = \'$dbxref_id\'"   if (defined($dbxref_id));

    my @result = $self->_get_results($query, $name);

    return undef if ($result[0][0] == 0);
    return $result[0][0];

}


#-------------------------------------------------------------------------------------------------------------------------------------------------
#  get_cvterm_relationship_id_from_cvterm_relationship()
#  
#-------------------------------------------------------------------------------------------------------------------------------------------------
sub get_cvterm_relationship_id_from_cvterm_relationship {

    my ($self, %param) = @_;

    my $phash = \%param;

    my $object_id    = $phash->{'object_id'}      if (exists $phash->{'object_id'});
    my $subject_id   = $phash->{'subject_id'}     if (exists $phash->{'subject_id'});
    my $type_id      = $phash->{'type_id'}        if (exists $phash->{'type_id'});

    if (!defined($object_id)){
	$self->{_logger}->logdie("object_id was not defined");
	return undef;
    }
    if (!defined($subject_id)){
	$self->{_logger}->logdie("subject_id was not defined");
	return undef;
    }
    if (!defined($type_id)){
	$self->{_logger}->logdie("type_id was not defined");
	return undef;
    }

    if (($object_id =~ /;/) or ($subject_id =~ /;/) or ($type_id =~ /;/)){
	return undef;
    }


    my $query = "SELECT cvterm_relationship_id  ".
	"FROM cvterm_relationship ".
	"WHERE object_id = ? ".
	"AND subject_id  = ? ".
	"AND type_id = ? ";
    
    my @result = $self->_get_results($query, $object_id, $subject_id, $type_id);

    return undef if ($result[0][0] == 0);
    return $result[0][0];
}


#---------------------------------------------------------------
# get_db_lookup()
#
#---------------------------------------------------------------
sub get_db_lookup {

    my($self) = @_;

    my $query = "SELECT db_id, name ".
    "FROM db ";
    
    
    return  $self->_get_results_ref($query);

}

#---------------------------------------------------------------
# get_database_list_by_type()
#
#---------------------------------------------------------------
sub get_database_list_by_type {

    my($self, $type) = @_;

    $self->{_logger}->logdie("type was not defined") if (!defined($type));


    my $query = "SELECT db ".
    "FROM common..genomes ".
    "WHERE type LIKE '%$type%'";
    
    return  $self->_get_results_ref($query);

}



#-------------------------------------------------------------------------------------------------------------------------------------------------
# get_cv_id_from_cv()
#  
#-------------------------------------------------------------------------------------------------------------------------------------------------
sub get_cv_id_from_cv{

    my ($self, %param) = @_;

    my $phash = \%param;

    my $name         = $phash->{'name'}           if (exists $phash->{'name'});
    my $definition   = $phash->{'definition'}     if (exists $phash->{'definition'});


    if (!defined($name)){
	$self->{_logger}->logdie("name was not defined");
	return undef;
    }


    if (($name =~ /;/) or ($definition =~ /;/)){
	return undef;
    }


    my $query = "SELECT cv_id  ".
	"FROM cv ".
	"WHERE name = ? ";
    
    $query .= "AND definition  = \'$definition\'" if (defined($definition));

    my @result = $self->_get_results($query, $name);
    
    return undef if ($result[0][0] == 0);
    return $result[0][0];

}


#---------------------------------------------------------------
# get_organism_id_lookup()
#
#---------------------------------------------------------------
sub get_organism_id_lookup {

    my($self) = @_;

    print "Building organism_id_lookup\n";

    my $query = "SELECT genus + '_' + species, organism_id ".
    "FROM organism ";
    
    return $self->_get_lookup_db($query);

}


#---------------------------------------------------------------
# get_organismprop_id_lookup()
#
#---------------------------------------------------------------
sub get_organismprop_id_lookup {

    my($self) = @_;

    print "Building organismprop_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, organism_id) + '_' + convert(VARCHAR, type_id) + '_' + value + '_' + convert(VARCHAR, rank), organismprop_id ".
    "FROM organismprop ";
    
    return $self->_get_lookup_db($query);

}

#---------------------------------------------------------------
# get_organism_dbxref_id_lookup()
#
#---------------------------------------------------------------
sub get_organism_dbxref_id_lookup {

    my($self) = @_;

    print "Building organism_dbxref_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, organism_id) + '_' + convert(VARCHAR, dbxref_id), organism_dbxref_id ".
    "FROM organism_dbxref ";
    
    return $self->_get_lookup_db($query);

}


#-------------------------------------------------------------------------------------------------------------------------------------------------
# get_cvterm_name_from_cvterm()
#  
#-------------------------------------------------------------------------------------------------------------------------------------------------
sub get_cvterm_name_from_cvterm{

    my ($self, %param) = @_;

    my $phash = \%param;

    my $cv_id        = $phash->{'cv_id'}          if (exists $phash->{'cv_id'});
    my $cvterm_id    = $phash->{'cvterm_id'}      if (exists $phash->{'cvterm_id'});
    my $definition   = $phash->{'definition'}     if (exists $phash->{'definition'});
    my $dbxref_id    = $phash->{'dbxref_id'}      if (exists $phash->{'dbxref_id'});


    if (!defined($cvterm_id)){
	$$self->{_logger}->logdie("cvterm_id was not defined");
	return undef;
    }

    if (($cvterm_id =~ /;/)){
	return undef;
    }


    my $query = "SELECT lower(name)  ".
	"FROM cvterm ".
	"WHERE cvterm_id = ? ";

    
    $query .= "AND definition  = \'$definition\' " if (defined($definition));
    $query .= "AND cv_id = $cv_id " if (defined($definition));
    $query .= "AND dbxref_id  = \'$dbxref_id\' "   if (defined($dbxref_id));

    
    my $result = $self->_get_results_ref($query, $cvterm_id);

    return $result->[0][0];

}



#---------------------------------------------------------------
# get_sequence_mappings_for_two_types()
#
#---------------------------------------------------------------
sub get_sequence_mappings_for_two_types {

    my($self, $type1, $type2) = @_;

    #
    # Retrieve all rows where sequence type2 localizes to sequence type1
    # e.g. assemblies localize to supercontigs
    #

    my $query = "select fs.feature_id, fs.uniquename, fa.feature_id, fa.uniquename, fl.fmin, fl.fmax, fl.strand ".
    "from feature fs, feature fa, feature_cvterm s, feature_cvterm a, featureloc fl ".
    "where s.cvterm_id = $type1 ".
    "and a.cvterm_id = $type2 ".
    "and fs.feature_id = s.feature_id ".
    "and fa.feature_id = a.feature_id ".
    "and fa.feature_id = fl.feature_id ".
    "and fs.feature_id = fl.srcfeature_id ";

    print "Sending query: All sequences type1 '$type1' and localized sequences type2 '$type2'\n";

    return $self->_get_results_ref($query);
}


#---------------------------------------------------------------
# get_features_to_sequence_by_sequence_type2()
#
#---------------------------------------------------------------
sub get_features_to_sequence_by_sequence_type2 {

    my($self, $type1, $type2, $seq1, $seq2) = @_;

    #
    # Retrieve feature and sequence type2 info
    # where feature maps to sequence type2 and
    # sequence type2 maps to sequence type1
    # but feature does not map to sequence type1
    #
    my $query = "SELECT f1.feature_id, f1.uniquename, f1.type_id, f.feature_id, f.uniquename, fl.fmin, fl.fmax, fl.strand, f.type_id ".
    "FROM feature f, feature f1, feature f2, feture_cvterm f1c, feature_cvterm f2c, featureloc fl, featureloc fl2, featureloc fl3 ".
    "WHERE f2c.cvterm_id = $type2 ".
    "AND f1c.cvterm_id = $type1 ".
    "AND f1c.feature_id = f1.feature_id ".
    "AND f2c.feature_id = f2.feature_id ".
    "AND f.type_id != $type1 ".
    "AND f.type_id != $type2 ".
    "AND f.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = f2.feature_id ".
    "AND f.feature_id = fl2.feature_id ".
    "AND fl2.srcfeature_id != f1.feature_id ".
    "AND f2.feature_id = fl3.feature_id ".
    "AND fl3.srcfeature_id = f1.feature_id ".
    "AND f1.feature_id = $seq1 ".
    "AND f2.feature_id = $seq2 ";

    return $self->_get_results_ref($query);
}

#---------------------------------------------------------------
# get_features_to_sequence_by_sequence_type1()
#
#---------------------------------------------------------------
sub get_features_to_sequence_by_sequence_type1 {

    my($self, $type1, $type2, $seq1, $seq2) = @_;

    my $query = "SELECT f1.feature_id, f1.uniquename, f1.type_id, f.feature_id, f.uniquename, fl.fmin, fl.fmax, fl.strand, f.type_id ".
    "FROM feature f, feature f1, feature f2, feture_cvterm f1c, feature_cvterm f2c, featureloc fl, featureloc fl2, featureloc fl3 ".
    "WHERE f2c.cvterm_id = $type2 ".
    "AND f1c.cvterm_id = $type1 ".
    "AND f1c.feature_id = f1.feature_id ".
    "AND f2c.feature_id = f2.feature_id ".
    "AND f.type_id != $type1 ".
    "AND f.type_id != $type2 ".
    "AND f.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = f1.feature_id ".
    "AND f.feature_id = fl2.feature_id ".
    "AND fl2.srcfeature_id != f2.feature_id ".
    "AND f2.feature_id = fl3.feature_id ".
    "AND fl3.srcfeature_id = f1.feature_id ".
    "AND f1.feature_id = $seq1 ".
    "AND f2.feature_id = $seq2 ";
    


    return $self->_get_results_ref($query);
}




#---------------------------------------------------------------
# get_exclusive_features_to_child_sequence()
#
#---------------------------------------------------------------
sub get_exclusive_features_to_child_sequence {

    my($self, $type1, $type2, $seq1, $seq2, $cfmin, $cfmax) = @_;

    #
    # Retrieve feature and child sequence info
    # where feature maps to child sequence and
    # child sequence maps to parent sequence
    # but feature does not map to parent sequence
    #
    my $query = "SELECT c.feature_id, c.uniquename, c.type_id, f.feature_id, f.uniquename, fl.fmin, fl.fmax, fl.strand, f.type_id, fl.phase, fl.residue_info, fl.rank ".
    "FROM feature c, feature f, featureloc fl, feature p, featureloc fl2, feature_cvterm fc ".
    "WHERE c.feature_id = $seq2 ".
    "AND p.feature_id = $seq1 ".
    "AND f.feature_id = fl.feature_id ".     # feature localizes to the child sequence
    "AND fl.srcfeature_id = c.feature_id ".
    "AND c.feature_id = fl2.feature_id ".    # child localizes to the parent sequence
    "AND fl2.srcfeature_id = p.feature_id ".
    "AND p.feature_id = fc.feature_id ".
    "AND fc.cvterm_id = $type1 ".
    "AND NOT EXISTS ( ".  # include only records where the feature does not localize the parent sequence
    "SELECT 1 ".
    "FROM featureloc fl3 ".
    "WHERE f.feature_id = fl3.feature_id ".
    "AND fl3.srcfeature_id = p.feature_id) ";

    return $self->_get_results_ref($query);
}

#---------------------------------------------------------------
# get_exclusive_features_to_parent_sequence()
#
#---------------------------------------------------------------
sub get_exclusive_features_to_parent_sequence {

    my($self, $type1, $type2, $seq1, $seq2, $cfmin, $cfmax) = @_;

    #
    # Retrieve feature and parent sequence info
    # where feature maps to parent sequence and
    # child sequence maps to parent sequence
    # but feature does not map to child sequence
    #
    my $query = "SELECT p.feature_id, p.uniquename, p.type_id, f.feature_id, f.uniquename, fl.fmin, fl.fmax, fl.strand, f.type_id, fl.phase, fl.residue_info, f.seqlen, fl.rank ".
    "FROM feature p, feature f, feature_cvterm fc, featureloc fl, feature c, featureloc fl2 ".
    "WHERE p.feature_id = $seq1 ".
    "AND c.feature_id = $seq2 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.cvterm_id != $type1 ".
    "AND fc.cvterm_id != $type2 ".
    "AND f.feature_id = fl.feature_id ".     # feature localizes to the parent
    "AND fl.srcfeature_id = p.feature_id ".
    "AND c.feature_id = fl2.feature_id ".    # child localizes to the parent
    "AND fl2.srcfeature_id = p.feature_id ".
    "AND fl.fmin  > $cfmin ".                 # Only consider the features whose coordinates are within the
    "AND fl.fmax < $cfmax ".                  # the boundaries of the child sequence
    "AND NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM featureloc fl3 ".
    "WHERE f.feature_id = fl3.feature_id ".    # include only records where the feature does not localize the child
    "AND fl3.srcfeature_id = c.feature_id) ";

    return $self->_get_results_ref($query);
}



#--------------------------------------------------------------
# uniquename_to_seqlen_hashref()
#
#--------------------------------------------------------------
sub uniquename_to_seqlen_hashref {

    my ($self, $type) = @_;
    
    my $query = "SELECT uniquename, seqlen ".
    "FROM feature ".
    "WHERE type_id = ? ".
    "AND seqlen > 0";

    my @ret = $self->_get_results($query,$type);

    my $hash = {};
    for (my $i = 0 ; $i < scalar @ret; $i++){
	$hash->{$ret[$i][0]} = $ret[$i][1];
    }

    return $hash;
}

#-----------------------------------------------------------------------------
# get_truncated_features()
#
#-----------------------------------------------------------------------------
sub get_truncated_features {

    my ($self, $type_id) = @_;

    my $query = "SELECT f.feature_id, f.uniquename, f.residues, db.name as 'dbname' ".
    "FROM feature f, dbxref d, db ".
    "WHERE f.dbxref_id = d.dbxref_id ".
    "AND d.db_id = db.db_id ";

    $query .= "AND f.type_id = $type_id" if (defined($type_id));

    return $self->_get_results($query);
}

#-----------------------------------------------------------------------------
# get_cvterm_relationship_for_closure()
#
#-----------------------------------------------------------------------------
sub get_cvterm_relationship_for_closure {

    my ($self, $cv_id, $ontology) = @_;

    my $query;
    
    if (defined($cv_id)){
	#
	# Only interested in retireving cvterm_relationship records related to 
	# some particular ontology
	#
	$query = "SELECT cr.subject_id, cr.object_id, cr.type_id ".
	"FROM cvterm_relationship cr, cvterm c, cv ".
	"WHERE cv.cv_id = $cv_id ".
	"AND cv.cv_id = c.cv_id ".
	"AND c.cvterm_id = cr.subject_id ";

	print STDOUT "\nExecuting query to retrieve records from cvterm_relationship for ontology '$ontology'\n";
    }
    else{

	#
	# cv_id was not defined therefore will retrieve all records from cvterm_relationship.
	# This is okay, since there is no intermingling between terms in different ontologies.
	#
	$query = "SELECT cr.subject_id, cr.object_id, cr.type_id ".
	"FROM cvterm_relationship cr, cvterm c, cv ";

	print STDOUT "\nExecuting query to retrieve records from cvterm_relationship\n";

    }


    return $self->_get_results($query);
}


#----------------------------------------------------------
# get_cvterm_id_by_dbxref_accession_lookup_args()
#  
#----------------------------------------------------------
sub get_cvterm_id_by_dbxref_accession_lookup_args {

    my ($self, %param) = @_;

    my $phash = \%param;

    my $cv_id        = $phash->{'cv_id'}      if (exists $phash->{'cv_id'});
    my $accession    = $phash->{'accession'}  if (exists $phash->{'accession'});
    my $like         = $phash->{'like'}       if (exists $phash->{'like'});


    if (!defined($cv_id)){
	$self->{_logger}->logdie("cv_id was not defined");
	return undef;
    }

    if (!defined($accession)){
	$self->{_logger}->logdie("accession was not defined");
	return undef;
    }


    if (($cv_id =~ /;/) or ($accession =~ /;/)){
	return undef;
    }


    my $query = "SELECT cvterm_id  ".
	"FROM cvterm c, dbxref d ".
	"WHERE c.cv_id = ? ".
	"AND c.dbxref_id = d.dbxref_id ";


    if ($like eq 'true'){
	$query .= "AND d.accession like '%$accession'";
    }
    else{
	$query .= "AND d.accession = '$accession' ";
    }


    my @result = $self->_get_results($query, $cv_id);#, $accession);

    return undef if ($result[0][0] == 0);
    return $result[0][0];

}


#-----------------------------------------------------------------------------
# get_tigr_roles_lookup()
#
#-----------------------------------------------------------------------------
sub get_tigr_roles_lookup {

    my ($self) = @_;

    my $query = "SELECT d1.accession, d2.accession ".
    "FROM cvterm c, cvterm_dbxref cd, dbxref d1, dbxref d2, cv ".
    "WHERE cv.name = 'TIGR_role' ".
    "AND cv.cv_id = c.cv_id ".
    "AND c.dbxref_id = d1.dbxref ".
    "AND c.cvterm_id = cd.cvterm_id ".
    "AND cd.dbxref_id = d2.dbxref_id ";
    
    
    return $self->_get_results($query);
}




#---------------------------------------------------------------
# get_cvterm_id_by_dbxref_accession_lookup()
#
#---------------------------------------------------------------
sub get_cvterm_id_by_dbxref_accession_lookup {

    my($self) = @_;

    print "Building cvterm_id_by_dbxref_accession_lookup\n";

    my $query = "SELECT convert(VARCHAR, c.cv_id) + '_' +  d.accession, c.cvterm_id  ".
	"FROM cvterm c, dbxref d ".
	"WHERE c.dbxref_id = d.dbxref_id ";

    return $self->_get_lookup_db($query);

}

#---------------------------------------------------------------
# get_cvterm_id_by_accession_lookup()
#
#---------------------------------------------------------------
sub get_cvterm_id_by_accession_lookup {

    my($self) = @_;

    my $query = "SELECT convert(VARCHAR, db.name) + '_' + convert(VARCHAR, d.accession), c.cvterm_id ".
    "FROM cv, db, dbxref d, cvterm c, cvterm_dbxref cd ".
    "WHERE db.name = cv.name ".
    "AND db.db_id = d.db_id ".
    "AND d.dbxref_id = cd.dbxref_id ".
    "AND cd.cvterm_id = c.cvterm_id ".
    "AND cv.cv_id = c.cv_id ";
        
    return $self->_get_lookup_db($query);

}


#---------------------------------------------------------------
# get_all_analysisfeature_records_by_type()
#
#---------------------------------------------------------------
sub get_all_analysisfeature_records_by_type {

    my($self, $type) = @_;

    $self->logdie("type was not defined") if (!defined($type));

    my $query;

    if ($type =~ /\d+/){
	$query = "SELECT af.analysisfeature_id, af.feature_id, af.analysis_id ".
	"FROM analysisfeature af, feature f ".
	"WHERE af.feature_id = f.feature_id ".
	"AND f.type_id = $type ";
    }
    else {
	
	$type = lc($type);

	$query = "SELECT af.analysisfeature_id, af.feature_id, af.analysis_id ".
	"FROM analysisfeature af, feature f, cvterm c ".
	"WHERE af.feature_id = f.feature_id ".
	"AND f.type_id = c.cvterm_id ".
	"AND lower(c.name) = '$type' ";
    }
    
    return $self->_get_results_ref($query);

}


#---------------------------------------------------------------
# get_all_featureprop_records_by_type()
#
#---------------------------------------------------------------
sub get_all_featureprop_records_by_type {

    my($self, $type) = @_;

    $self->logdie("type was not defined") if (!defined($type));

    my $query;

    if ($type =~ /\d+/){
 
	$query = "SELECT fp.featureprop_id, fp.feature_id, fp.type_id, fp.value, fp.rank ".
	"FROM featureprop fp, feature f ".
	"WHERE fp.feature_id = f.feature_id ".
	"AND f.type_id = $type ";
    }
    else{

	$type = lc($type);
	
	$query = "SELECT fp.featureprop_id, fp.feature_id, fp.type_id, fp.value, fp.rank ".
	"FROM featureprop fp, feature f, cvterm c ".
	"WHERE fp.feature_id = f.feature_id ".
	"AND f.type_id = c.cvterm_id ".
	"AND lower(c.name) = '$type' ";

    }

    return $self->_get_results_ref($query);

}


#---------------------------------------------------------------
# get_all_featureloc_records_by_type()
#
#---------------------------------------------------------------
sub get_all_featureloc_records_by_type {

    my($self, $type) = @_;

    $self->logdie("type was not defined") if (!defined($type));

    my $query;

    if ($type =~ /\d+/){
 
	$query = "SELECT fl.featureloc_id, fl.feature_id, fl.locgroup, fl.rank ".
	"FROM featureloc fl, feature f ".
	"WHERE fl.feature_id = f.feature_id ".
	"AND f.type_id = $type ";
    }
    else{

	$type = lc($type);

	$query = "SELECT fl.featureloc_id, fl.feature_id, fl.locgroup, fl.rank ".
	"FROM featureloc fl, feature f, cvterm c ".
	"WHERE fl.feature_id = f.feature_id ".
	"AND f.type_id = c.cvterm_id ".
	"AND lower(c.name) = '$type' ";

    }

    return $self->_get_results_ref($query);

}


#---------------------------------------------------------------
# get_all_feature_relationship_records_by_type()
#
#---------------------------------------------------------------
sub get_all_feature_relationship_records_by_type {

    my($self, $type) = @_;

    $self->logdie("type was not defined") if (!defined($type));

    my $query;

    if ($type =~ /\d+/){

	$query = "SELECT fr.feature_relationship_id, fr.subject_id, fr.object_id, fr.type_id, fr.rank ".
	"FROM feature_relationship fr, feature f ".
	"WHERE fr.subject_id = f.feature_id ".
	"AND f.type_id = $type ";
    }
    else {

	$type = lc($type);

	$query = "SELECT fr.feature_relationship_id, fr.subject_id, fr.object_id, fr.type_id, fr.rank ".
	"FROM feature_relationship fr, feature f, cvterm c ".
	"WHERE fr.subject_id = f.feature_id ".
	"AND f.type_id = c.cvterm_id ".
	"AND lower(c.name) = '$type' ";
    }
    
    return $self->_get_results_ref($query);

}


#---------------------------------------------------------------
# get_all_feature_cvterm_records_by_type()
#
#---------------------------------------------------------------
sub get_all_feature_cvterm_records_by_type {

    my($self, $type) = @_;

    $self->logdie("type was not defined") if (!defined($type));

    my $query;

    if ($type =~ /\d+/){

	$query = "SELECT fc.feature_cvterm_id, fc.feature_id, fc.cvterm_id, fc.pub_id ".
	"FROM feature_cvterm fc, feature f ".
	"WHERE fc.feature_id = f.feature_id ".
	"AND f.type_id = $type ";
    }
    else {

	$type = lc($type);

	$query = "SELECT fc.feature_cvterm_id, fc.feature_id, fc.cvterm_id, fc.pub_id ".
	"FROM feature_cvterm fc, feature f, cvterm c ".
	"WHERE fc.feature_id = f.feature_id ".
	"AND f.type_id = c.cvterm_id ".
	"AND lower(c.name) = '$type' ";
    }

    return $self->_get_results_ref($query);
}



#---------------------------------------------------------------
# get_all_feature_dbxref_records_by_type()
#
#---------------------------------------------------------------
sub get_all_feature_dbxref_records_by_type {

    my($self, $type) = @_;

    $self->logdie("type was not defined") if (!defined($type));

    my $query;
    
    if ($type =~ /\d+/){
	
 	$query = "SELECT fd.feature_dbxref_id, fd.feature_id, fd.dbxref_id, fd.is_current ".
	"FROM feature_dbxref fd, feature f ".
	"WHERE fd.feature_id = f.feature_id ".
	"AND f.type_id = $type ";
    }
    else {
	
	$type = lc($type);

 	$query = "SELECT fd.feature_dbxref_id, fd.feature_id, fd.dbxref_id, fd.is_current ".
	"FROM feature_dbxref fd, feature f, cvterm c ".
	"WHERE fd.feature_id = f.feature_id ".
	"AND f.type_id = c.cvterm_id ".
	"AND lower(c.name) = '$type' ";
    }

    return $self->_get_results_ref($query);
}

#---------------------------------------------------------------
# get_all_feature_cvtermprop_records_by_type()
#
#---------------------------------------------------------------
sub get_all_feature_cvtermprop_records_by_type {

    my($self, $type) = @_;

    $self->logdie("type was not defined") if (!defined($type));

    my $query;

    if ($type =~ /\d+/){
	
	$query = "SELECT fc.feature_cvtermprop_id, fc.feature_cvterm_id, fc.type_id, fc.value, fc.rank ".
	"FROM feature_cvtermprop fc, feature_cvterm c, feature f ".
	"WHERE fc.feature_cvterm_id = c.feature_cvterm_id ".
	"AND c.feature_id = f.feature_id ".
	"AND f.type_id = $type ";
    }
    else {
	
	$type = lc($type);

	$query = "SELECT fc.feature_cvtermprop_id, fc.feature_cvterm_id, fc.type_id, fc.value, fc.rank ".
	"FROM feature_cvtermprop fc, feature_cvterm c, feature f, cvterm t ".
	"WHERE fc.feature_cvterm_id = c.feature_cvterm_id ".
	"AND c.feature_id = f.feature_id ".
	"AND f.type_id = t.cvterm_id ".
	"AND lower(t.name) = '$type' ";
    }

    return $self->_get_results_ref($query);
}


#---------------------------------------------------------------
# get_all_seq_to_feat_analysisfeature_records()
#
#---------------------------------------------------------------
sub get_all_seq_to_feat_analysisfeature_records {

    my($self, $uniquename) = @_;

    $self->logdie("uniquename was not defined") if (!defined($uniquename));

    my $query = "SELECT af.analysisfeature_id, af.feature_id, af.analysis_id ".
    "FROM analysisfeature af, feature f, featureloc fl ".
    "WHERE af.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = f.feature_id ".
    "AND f.uniquename = ? ";
    
    return $self->_get_results_ref($query, $uniquename);

}


#---------------------------------------------------------------
# get_all_seq_to_feat_featureprop_records()
#
#---------------------------------------------------------------
sub get_all_seq_to_feat_featureprop_records {

    my($self, $uniquename) = @_;

    $self->logdie("uniquename was not defined") if (!defined($uniquename));

    my $query = "SELECT fp.featureprop_id, fp.feature_id, fp.type_id, fp.value, fp.rank ".
    "FROM featureprop fp, feature f, featureloc fl ".
    "WHERE fp.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = f.feature_id ".
    "AND f.uniquename = ? ";
    
    return $self->_get_results_ref($query, $uniquename);

}


#---------------------------------------------------------------
# get_all_seq_to_feat_featureloc_records()
#
#---------------------------------------------------------------
sub get_all_seq_to_feat_featureloc_records {

    my($self, $uniquename) = @_;

    $self->logdie("uniquename was not defined") if (!defined($uniquename));

    my $query = "SELECT fl.featureloc_id, fl.feature_id, fl.locgroup, fl.rank ".
    "FROM featureloc fl, feature f ".
    "WHERE fl.srcfeature_id = f.feature_id ".
    "AND f.uniquename = ? ";
    
    return $self->_get_results_ref($query, $uniquename);

}


#---------------------------------------------------------------
# get_all_seq_to_feat_feature_relationship_records()
#
#---------------------------------------------------------------
sub get_all_seq_to_feat_feature_relationship_records {

    my($self, $uniquename) = @_;

    $self->logdie("uniquename was not defined") if (!defined($uniquename));

    my $query = "SELECT fr.feature_relationship_id, fr.subject_id, fr.object_id, fr.type_id, fr.rank ".
    "FROM feature_relationship fr, feature f, featureloc fl ".
    "WHERE fr.subject_id = fl.feature_id ".
    "AND fl.srcfeature_id = f.feature_id ".
    "AND f.uniquename = ? ";
    
    return $self->_get_results_ref($query, $uniquename);

}


#---------------------------------------------------------------
# get_all_seq_to_feat_feature_cvterm_records()
#
#---------------------------------------------------------------
sub get_all_seq_to_feat_feature_cvterm_records {

    my($self, $uniquename) = @_;

    $self->logdie("uniquename was not defined") if (!defined($uniquename));

    my $query = "SELECT fc.feature_cvterm_id, fc.feature_id, fc.cvterm_id, fc.pub_id ".
    "FROM feature_cvterm fc, feature f, featureloc fl ".
    "WHERE fc.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = f.feature_id ".
    "AND f.uniquename = ? ";
    
    return $self->_get_results_ref($query, $uniquename);

}



#---------------------------------------------------------------
# get_all_seq_to_feat_feature_dbxref_records()
#
#---------------------------------------------------------------
sub get_all_seq_to_feat_feature_dbxref_records {

    my($self, $uniquename) = @_;

    $self->logdie("uniquename was not defined") if (!defined($uniquename));

    my $query = "SELECT fd.feature_dbxref_id, fd.feature_id, fd.dbxref_id, fd.is_current ".
    "FROM feature_dbxref fd, feature f, featureloc fl ".
    "WHERE fd.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = f.feature_id ".
    "AND f.uniquename = ? ";
    
    return $self->_get_results_ref($query, $uniquename);

}



#---------------------------------------------------------------
# get_all_seq_to_feat_feature_cvtermprop_records()
#
#---------------------------------------------------------------
sub get_all_seq_to_feat_feature_cvtermprop_records {

    my($self, $uniquename) = @_;

    $self->logdie("uniquename was not defined") if (!defined($uniquename));

    my $query = "SELECT fc.feature_cvtermprop_id, fc.feature_cvterm_id, fc.type_id, fc.value, fc.rank ".
    "FROM feature_cvtermprop fc, feature_cvterm c, feature f, featureloc fl ".
    "WHERE fc.feature_cvterm_id = c.feature_cvterm_id ".
    "AND c.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = f.feature_id ".
    "AND f.uniquename = ? ";
    
    return $self->_get_results_ref($query, $uniquename);

}


#---------------------------------------------------------------
# get_all_seq_uniquenames_by_type()
#
#---------------------------------------------------------------
sub get_all_seq_uniquenames_by_type {

    my($self, $type_id) = @_;

    $self->logdie("type_id was not defined") if (!defined($type_id));


    my $query;

    if ($type_id =~ /\d+/){
	#
	# type_id is all numeric
	#
	$query = "SELECT f.uniquename ".
	"FROM feature f ".
	"WHERE f.type_id = $type_id ";
    }
    else{

	$type_id = lc($type_id);

	#
	# type_id is string e.g. 'assembly'
	#
	$query = "SELECT f.uniquename ".
	"FROM feature f, cvterm c ".
	"WHERE f.type_id = c.cvterm_id ".
	"AND lower(c.name) = '$type_id' ";
    }

    return $self->_get_results_ref($query);

}



#---------------------------------------------------------------
# get_cv_id_lookup()
#
#---------------------------------------------------------------
sub get_cv_id_lookup {

    my($self) = @_;

    print "Building cv_id_lookup\n";

    my $query = "SELECT name, cv_id ".
    "FROM cv ";
    
    return $self->_get_lookup_db($query);

}

#---------------------------------------------------------------
# get_non_obsolete_cvterm_id_lookup()
#
#---------------------------------------------------------------
sub get_non_obsolete_cvterm_id_lookup {

    my($self) = @_;

    print "Building non_obsolete_cvterm_id_lookup\n";

    my $query = "SELECT  convert(VARCHAR, cv_id) + '_' + lower(name), cvterm_id ".
    "FROM cvterm ".
    "WHERE is_obsolete = 0 ";
    
    return $self->_get_lookup_db($query);

}


#---------------------------------------------------------------
# get_obsolete_cvterm_id_lookup()
#
#---------------------------------------------------------------
sub get_obsolete_cvterm_id_lookup {

    my($self) = @_;

    print "Building obsolete_cvterm_id_lookup\n";

    my $query = "SELECT  convert(VARCHAR, cv_id) + '_' + lower(name), cvterm_id ".
    "FROM cvterm ".
    "WHERE is_obsolete != 0 ";

    #
    # Don't know how to properly query/create this lookup since using convert statements...
    # The consequence of having commented portions of the above query only means that we cannot guarantee that the most recently
    # obsoleted version of the terms i.e. is_obsolete = max(is_obsolete) will be retrieved and stored in the lookup.
    #
    # Note that it is necessary to split the cvterm_id_lookup into two separate lookups because we need to support retrieving
    # one of the following two values without fail:
    # 1) the non-obsolete version of the term i.e. is_obsolete = 0
    # 2) else the most recently obsoleted version of the term is_obsolete = max(is_obsolete)
    #
    # -sundaram@tigr.org
    #
    return $self->_get_lookup_db($query);

}


#---------------------------------------------------------------
# get_cvtermpath_id_lookup()
#
#---------------------------------------------------------------
sub get_cvtermpath_id_lookup {

    my($self) = @_;

    print "Building cvtermpath_id_lookup\n";

    my $query = "SELECT  convert(VARCHAR, subject_id) + '_' + convert(VARCHAR, object_id) + '_' + convert(VARCHAR, type_id) + '_' + convert(VARCHAR, pathdistance), cvtermpath_id ".
    "FROM cvtermpath ";
    
    return $self->_get_lookup_db($query);

}

#---------------------------------------------------------------
# get_db_id_lookup()
#
#---------------------------------------------------------------
sub get_db_id_lookup {

    my($self) = @_;

    print "Building db_id_lookup\n";

    ## Our chado schema version chado-v1r3b4 does not contain the
    ## field db.contact_id.
    my $query = "SELECT name, db_id ".
    "FROM db ";
    
    return $self->_get_lookup_db($query);

}


#---------------------------------------------------------------
# get_dbxref_id_lookup()
#
#---------------------------------------------------------------
sub get_dbxref_id_lookup {

    my($self) = @_;

    print "Building dbxref_id_lookup\n";

    my $query = "SELECT  convert(VARCHAR,db_id) + '_' + accession + '_' + version, dbxref_id ".
    "FROM dbxref ";
    
    return $self->_get_lookup_db($query);

}


#---------------------------------------------------------------
# get_cvterm_id_by_name_lookup()
#
#---------------------------------------------------------------
sub get_cvterm_id_by_name_lookup {

    my($self) = @_;

    my $query = "SELECT lower(name), cvterm_id ".
    "FROM cvterm ";
    
    return $self->_get_lookup_db($query);

}

#---------------------------------------------------------------
# get_property_types_lookup()
#
#---------------------------------------------------------------
sub get_property_types_lookup {

    my($self) = @_;

    print "Building property_types_lookup\n";

    my $query = "SELECT lower(c.name), c.cvterm_id ".
    "FROM cvterm c, cv ".
    "WHERE cv.cv_id = c.cv_id ".
    "AND cv.name in ('SO', 'annotation_attributes.ontology', 'component.ontology', 'output.ontology', 'ARD') ";
    
    return $self->_get_lookup_db($query);

}


#---------------------------------------------------------------
# get_cvterm_relationship_type_id_lookup()
#
#---------------------------------------------------------------
sub get_cvterm_relationship_type_id_lookup {

    my($self) = @_;

    print "Building cvterm_relationship_type_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, subject_id) + '_' + convert(VARCHAR, object_id), type_id ".
    "FROM cvterm_relationship ";
    
    return $self->_get_lookup_db($query);

}

#---------------------------------------------------------------
# get_analysis_id_lookup()
#
#---------------------------------------------------------------
sub get_analysis_id_lookup {

    my($self) = @_;

    print "Building analysis_id_lookup\n";

    my $query = "SELECT  program + '_' + programversion + '_' + sourcename, analysis_id ".
    "FROM analysis ";
    
    return $self->_get_lookup_db($query);

}

#---------------------------------------------------------------
# get_analysisprop_id_lookup()
#
#---------------------------------------------------------------
sub get_analysisprop_id_lookup {

    my($self) = @_;

    print "Building analysisprop_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, analysis_id) + '_' + convert(VARCHAR, type_id) , analysisprop_id ".
    "FROM analysisprop ";
    
    return $self->_get_lookup_db($query);

}


#---------------------------------------------------------------
# get_name_by_analysis_id_lookup()
#
#---------------------------------------------------------------
sub get_name_by_analysis_id_lookup {

    my($self) = @_;

    print "Building analysis_id_by_name_lookup\n";
    
    my $query = "SELECT  a.analysis_id, a.name ".
    "FROM analysis a ";
    
    return $self->_get_lookup_db($query);

}



#---------------------------------------------------------------
# get_cvterm_id_by_class_lookup()
#
#---------------------------------------------------------------
sub get_cvterm_id_by_class_lookup {

    my($self) = @_;

    print "Building cvterm_id_by_class_lookup\n";
    
    my $query = "SELECT lower(c.name), c.cvterm_id ".
    "FROM cvterm c, cv ".
    "WHERE cv.cv_id = c.cv_id ".
    "AND (cv.name = 'SO' ".
    "OR cv.name = 'ARD')";

    return $self->_get_lookup_db($query);
}


#---------------------------------------------------------------
# get_all_cvterm_id_by_typedef()
#
#---------------------------------------------------------------
sub get_all_cvterm_id_by_typedef {

    my($self) = @_;

    my $query = "SELECT c.cvterm_id, lower(c.name) ".
    "FROM cvterm c, cv ".
    "WHERE cv.cv_id = c.cv_id ".
    "AND cv.name = 'Relation_typedef.ontology'";
    
    return $self->_get_results_ref($query);

}


#---------------------------------------------------------------
# get_cvterm_id_from_so()
#
#---------------------------------------------------------------
sub get_cvterm_id_from_so {

    my($self, $term) = @_;

    $self->{_logger}->logdie("term was not defined") if (!defined($term));


    $term = lc($term);

    my $query = "SELECT c.cvterm_id ".
	"FROM cvterm c, cv ".
	"WHERE c.cv_id = cv.cv_id ".
	"AND cv.name = 'SO' ".
	"AND lower(c.name) = ? ";
    

    return $self->_get_results_ref($query,$term);
    
}

#---------------------------------------------------------------
# get_cvterm_id_from_typedef()
#
#---------------------------------------------------------------
sub get_cvterm_id_from_typedef {

    my($self, $term) = @_;

    $self->{_logger}->logdie("term was not defined") if (!defined($term));

    $term = lc($term);


    my $query = "SELECT c.cvterm_id ".
	"FROM cvterm c, cv ".
	"WHERE c.cv_id = cv.cv_id ".
	"AND cv.name = 'Relation_typedef.ontology' ".
	"AND lower(c.name) = ? ";
    

    return $self->_get_results_ref($query,$term);
}

#---------------------------------------------------------------
# get_table_records()
#
#---------------------------------------------------------------
sub get_table_records {

    my($self, $parenttable, $parentkey) = @_;

    $self->{_logger}->logdie("parenttable was not defined") if (!defined($parenttable));
    $self->{_logger}->logdie("parentkey was not defined") if (!defined($parentkey));

    my $query = "SELECT $parentkey FROM $parenttable";
    
    return $self->_get_results($query);
}

#---------------------------------------------------------------
# get_seq_id_to_RNA()
#
#---------------------------------------------------------------
sub get_seq_id_to_RNA {

    my ($self, $asmbl_id, $assembly_cvterm_id, $rna_cvterm_id, $rnatype) = @_;


    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));
    $self->{_logger}->logdie("assembly_cvterm_id was not defined") if (!defined($assembly_cvterm_id));
    $self->{_logger}->logdie("rna_cvterm_id was not defined") if (!defined($rna_cvterm_id));
    

    if (!defined($assembly_cvterm_id)){
	$assembly_cvterm_id = $self->get_cvterm_id_from_so('assembly');
	if (!defined($assembly_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'assembly' ontology 'SO'");
	}
    }

    if (!defined($rna_cvterm_id)){
	$rna_cvterm_id = $self->get_cvterm_id_from_so($rnatype);
	if (!defined($rna_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term '$rnatype' ontology 'SO'");
	}
    }

    my $query = "SELECT r.uniquename, fl.fmin, fl.fmax, fl.strand, r.seqlen, fp.value ".
    "FROM feature r, feature a, featureloc fl, featureprop fp, cvterm c ".
    "WHERE r.type_id = ? ".
    "AND r.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = a.feature_id ".
    "AND a.type_id =  ? ".
    "AND a.uniquename = ? ".
    "AND fp.type_id = c.cvterm_id ".
    "AND lower(c.name) = 'name' ".
    "AND r.feature_id = fp.feature_id";
   
    print "Retrieving all $rnatype features for assembly '$asmbl_id'\n";

    return $self->_get_results_ref(
				   $query,
				   $rna_cvterm_id,
				   $assembly_cvterm_id,
				   $asmbl_id);    
}

#---------------------------------------------------------------
# get_seq_id_to_signal_peptide()
#
#---------------------------------------------------------------
sub get_seq_id_to_signal_peptide {

    my ($self, $asmbl_id, $assembly_cvterm_id, $signal_peptide_cvterm_id, $polypeptide_cvterm_id, $part_of_cvterm_id) = @_;

    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));

    if (!defined($assembly_cvterm_id)){
	$assembly_cvterm_id = $self->get_cvterm_id_from_so('assembly');
	if (!defined($assembly_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'assembly' ontology 'SO'");
	}
    }

    if (!defined($signal_peptide_cvterm_id)){
	$signal_peptide_cvterm_id = $self->get_cvterm_id_from_so('signal_peptide');
	if (!defined($signal_peptide_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'signal_peptide' ontology 'SO'");
	}
    }

    if (!defined($polypeptide_cvterm_id)){
	$polypeptide_cvterm_id = $self->get_cvterm_id_from_so('polypeptide');
	if (!defined($polypeptide_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'polypeptide' ontology 'SO'");
	}
    }

    if (!defined($part_of_cvterm_id)){
	$part_of_cvterm_id = $self->get_cvterm_id_from_so('part_of');
	if (!defined($part_of_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'part_of' ontology 'SO'");
	}
    }

    my $query = "SELECT p.uniquename, s.uniquename, fl.fmin, fl.fmax, fl.strand ".
    "FROM feature s, feature p, feature a, featureloc fl, feature_relationship fr ".
    "WHERE s.type_id = ? ".
    "AND s.feature_id = fr.subject_id ".
    "AND fr.object_id = p.feature_id ".
    "AND p.type_id =  ? ".
    "AND p.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = a.feature_id ".
    "AND a.type_id = ? ".
    "AND a.uniquename = ? ".
    "AND fr.type_id = ? ";
   

    print "Retrieving all signal_peptide features for assembly '$asmbl_id'\n";

    return $self->_get_results_ref(
				   $query,
				   $signal_peptide_cvterm_id,
				   $polypeptide_cvterm_id,
				   $assembly_cvterm_id,
				   $asmbl_id,
				   $part_of_cvterm_id);    
}


#---------------------------------------------------------------
# get_seq_id_to_ribosome_entry_site()
#
#---------------------------------------------------------------
sub get_seq_id_to_ribosome_entry_site {

    my ($self, $asmbl_id, $assembly_cvterm_id, $ribosome_cvterm_id) = @_;

    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));

    if (!defined($assembly_cvterm_id)){
	$assembly_cvterm_id = $self->get_cvterm_id_from_so('assembly');
	if (!defined($assembly_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'assembly' ontology 'SO'");
	}
    }

    if (!defined($ribosome_cvterm_id)){
	$ribosome_cvterm_id = $self->get_cvterm_id_from_so('ribosome_entry_site');
	if (!defined($ribosome_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'ribosome_entry_site' ontology 'SO'");
	}
    }

    my $query = "SELECT r.uniquename, fl.fmin, fl.fmax, fl.strand ".
    "FROM feature r, feature a, featureloc fl ".
    "WHERE r.type_id = ? ".
    "AND r.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = a.feature_id ".
    "AND a.type_id = ? ".
    "AND a.uniquename = ? ";
   
    print "Retrieving all ribosome_entry_site features for assembly '$asmbl_id'\n";

    return $self->_get_results_ref(
				   $query,
				   $ribosome_cvterm_id,
				   $assembly_cvterm_id,
				   $asmbl_id);    
}


#---------------------------------------------------------------
# get_seq_id_to_terminator()
#
#---------------------------------------------------------------
sub get_seq_id_to_terminator {

    my ($self, $asmbl_id, $assembly_cvterm_id, $terminator_cvterm_id) = @_;

    $self->{_logger}->logdie("asmbl_id was not defined") if (!defined($asmbl_id));
    $self->{_logger}->logdie("assembly_cvterm_id was not defined") if (!defined($assembly_cvterm_id));
    $self->{_logger}->logdie("terminator_cvterm_id was not defined") if (!defined($terminator_cvterm_id));

    if (!defined($assembly_cvterm_id)){
	$assembly_cvterm_id = $self->get_cvterm_id_from_so('assembly');
	if (!defined($assembly_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'assembly' ontology 'SO'");
	}
    }

    if (!defined($terminator_cvterm_id)){
	$terminator_cvterm_id = $self->get_cvterm_id_from_so('terminator');
	if (!defined($terminator_cvterm_id)){
	    $self->{_logger}->logdie("Could not retrieve cvterm_id for term 'terminator' ontology 'SO'");
	}
    }

    my $query = "SELECT t.uniquename, fl.fmin, fl.fmax, fl.strand ".
    "FROM feature t, feature a, featureloc fl ".
    "WHERE t.type_id = ? ".
    "AND t.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = a.feature_id ".
    "AND a.type_id = ? ".
    "AND a.uniquename = ? ";

    print "Retrieving all terminator features for assembly '$asmbl_id'\n";
   
    return $self->_get_results_ref(
				   $query,
				   $terminator_cvterm_id,
				   $assembly_cvterm_id,
				   $asmbl_id);    
}






#---------------------------------------------------------------
# get_organism_2_assembly()
#
#---------------------------------------------------------------
sub get_organism_2_assembly {

    my ($self) = @_;

    my $query = "SELECT o.genus, o.species, a.uniquename ".
    "FROM organism o, organism_dbxref od, dbxref d, db, feature a, dbxref ad, cvterm c ".
    "WHERE o.organism_id = od.organism_id ".
    "AND od.dbxref_id = d.dbxref_id " .
    "AND d.db_id = db.db_id ".
    "AND db.db_id = ad.db_id ".
    "AND ad.dbxref_id = a.dbxref_id ".
    "AND a.type_id = c.cvterm_id ".
    "AND lower(c.name) = 'assembly' ";

    print "Retrieving organism genus, species and associated assembly uniquename\n";
   
    return $self->_get_results_ref($query);
}


#---------------------------------------------------------------
# get_table_primary_and_tuples()
#
#---------------------------------------------------------------
sub get_table_primary_and_tuples {

    my ($self, $tablename, $pkey, $uckeys) = @_;

    $self->{_logger}->logdie("pkey was not defined") if (!defined($pkey));
    $self->{_logger}->logdie("uckeys was not defined") if (!defined($uckeys));
    $self->{_logger}->logdie("tablename was not defined") if (!defined($tablename));

    my $query = "SELECT $pkey ";

    foreach my $uc ( @{$uckeys} ){

	$query .= ",$uc ";

    }

    $query .= " FROM $tablename ";

    print "Retrieving primary key '$pkey' and unique keys '@{$uckeys}' from table '$tablename' query '$query'\n" if ($self->{_logger}->is_info());
    
    return $self->_get_results_ref($query);
}


#---------------------------------------------------------------
# get_chado_databases()
#
#---------------------------------------------------------------
sub get_chado_databases {

    my ($self) = @_;

    my $query = "SELECT db FROM common..genomes WHERE type like '%chado%' ";

    return $self->_get_results_ref($query);
}

#---------------------------------------------------------------
# get_organism_count()
#
#---------------------------------------------------------------
sub get_organism_count {

    my ($self, $database) = @_;

    $self->{_logger}->logdie("database was not defined") if (!defined($database));

    my $query = "SELECT count(*) FROM $database..organism ";

    return $self->_get_results_ref($query);
}

#---------------------------------------------------------------
# get_residue_sum()
#
#---------------------------------------------------------------
sub get_residue_sum {

    my ($self, $database) = @_;

    $self->{_logger}->logdie("database was not defined") if (!defined($database));

    my $query = "SELECT sum(datalength(f.residues)) FROM $database..feature f, $database..cvterm c where f.type_id = c.cvterm_id AND lower(c.name) = 'assembly' ";

    return $self->_get_results_ref($query);
}

#---------------------------------------------------------------
# get_gene_count()
#
#---------------------------------------------------------------
sub get_gene_count {

    my ($self, $database) = @_;

    $self->{_logger}->logdie("database was not defined") if (!defined($database));

    my $query = "SELECT count(f.feature_id) ".
    "FROM $database..feature f, $database..cvterm c ".
    "WHERE f.type_id = c.cvterm_id ".
    "AND lower(c.name) = 'gene' ";

    return $self->_get_results_ref($query);
}

#---------------------------------------------------------------
# get_feature_count()
#
#---------------------------------------------------------------
sub get_feature_count {

    my ($self, $database) = @_;

    $self->{_logger}->logdie("database was not defined") if (!defined($database));

    my $query = "SELECT count(f.feature_id) ".
    "FROM $database..feature f, $database..cvterm c ".
    "WHERE c.cvterm_id = f.type_id ".
    "AND lower(c.name) != 'match' ";

    return $self->_get_results_ref($query);
}

#---------------------------------------------------------------
# get_analysisfeature_count()
#
#---------------------------------------------------------------
sub get_analysisfeature_count {

    my ($self, $database) = @_;

    $self->{_logger}->logdie("database was not defined") if (!defined($database));

    my $query = "SELECT count(*) ".
    "FROM $database..analysisfeature  ";

    return $self->_get_results_ref($query);
}

#---------------------------------------------------------------
# get_featureloc_count()
#
#---------------------------------------------------------------
sub get_featureloc_count {

    my ($self, $database) = @_;

    $self->{_logger}->logdie("database was not defined") if (!defined($database));

    my $query = "SELECT count(fl.featureloc_id) ".
    "FROM $database..featureloc fl ";

    return $self->_get_results_ref($query);
}

#---------------------------------------------------------------
# get_featureprop_count()
#
#---------------------------------------------------------------
sub get_featureprop_count {

    my ($self, $database) = @_;

    $self->{_logger}->logdie("database was not defined") if (!defined($database));

    my $query = "SELECT count(fp.featureprop_id) ".
    "FROM $database..featureprop fp ";

    return $self->_get_results_ref($query);
}


#-------------------------------------------------------------------------------------------------------------------------------------------------
#  get_cvterm_id_to_accession()
#  
#-------------------------------------------------------------------------------------------------------------------------------------------------
sub get_cvterm_id_to_accession {

    my ($self) = @_;

    my $query = "SELECT c.cvterm_id, d.accession ".
    "FROM cvterm c, dbxref d ".
    "WHERE c.dbxref_id = d.dbxref_id ";

    return $self->_get_results_ref($query);
    
}

sub get_feature_uniquenamelookup{
    my($self) = @_;

    my $query = "select uniquename,seqlen,name,organism_id from feature where is_analysis = 0 ";

    #create on column 0
    my $lookupcol = 0;
    return $self->_get_lookup_db($query,$lookupcol);
    
}


sub get_analysis_id_program_sourcename_from_analysis {

    my($self) = @_;

    my $query = "SELECT analysis_id, program, sourcename ".
    "FROM analysis ".
    "WHERE description not like '%OBSOLETE%'";

    return $self->_get_results_ref($query);
    
}


sub get_feature_counts_by_analysis_id {


    my($self, $analysis_id) = @_;

    $self->{_logger}->logdie("analysis_id was not defined") if (!defined($analysis_id));


    my $query = "SELECT count(f.feature_id) ".
    "FROM analysis a, analysisfeature af, feature f ".
    "WHERE a.analysis_id = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND f.is_analysis = 1 ";

    return $self->_get_results_ref($query, $analysis_id);
    
}


sub get_analysisfeature_counts_by_analysis_id {


    my($self, $analysis_id) = @_;

    $self->{_logger}->logdie("analysis_id was not defined") if (!defined($analysis_id));


    my $query = "SELECT count(af.analysisfeature_id) ".
    "FROM analysis a, analysisfeature af ".
    "WHERE a.analysis_id = ? ".
    "AND a.analysis_id = af.analysis_id ";

    return $self->_get_results_ref($query, $analysis_id);
    
}



sub get_featureloc_counts_by_analysis_id {


    my($self, $analysis_id) = @_;

    $self->{_logger}->logdie("analysis_id was not defined") if (!defined($analysis_id));


    my $query = "SELECT count(fl.featureloc_id) ".
    "FROM analysis a, analysisfeature af, feature f, featureloc fl ".
    "WHERE a.analysis_id = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND f.is_analysis = 1 ".
    "AND f.feature_id = fl.feature_id ";

    return $self->_get_results_ref($query, $analysis_id);
    
}



#----------------------------------------------------------------
# subroutine: get_sysobjects()
#
#----------------------------------------------------------------
sub get_sysobjects {


    my($self, $objectType) = @_;

    my $query = "SELECT name FROM sysobjects WHERE type='$objectType' and uid = 1";

    return $self->_get_results_ref($query);
    
}

#------------------------------------------------------------
# get_analysisfeature_id_lookup()
#
#------------------------------------------------------------
sub get_analysisfeature_id_lookup {

    my($self) = @_;

    my $query = "SELECT  convert(VARCHAR, af.feature_id) + '_' + convert(VARCHAR, af.analysis_id), af.analysisfeature_id ".
    "FROM analysisfeature af ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, cvterm c1, cvterm c2 ".
    "WHERE f.feature_id = af.feature_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f.type_id = c1.cvterm_id ".
    "OR f.type_id = c2.cvterm_id )) ";

    print "Building analysisfeature_id_lookup\n";
    
    return $self->_get_lookup_db($query);

}

#------------------------------------------------------------
# get_cvtermsynonym_synonym_lookup()
#
#------------------------------------------------------------
sub get_cvtermsynonym_synonym_lookup {

    my($self) = @_;

    print "Building cvtermsynonym_synonym_lookup\n";

    my $query = "SELECT  lower(synonym), cvterm_id ".
    "FROM cvtermsynonym ";
    
    return $self->_get_lookup_db($query);

}

#-----------------------------------------------------------
# get_typedef_lookup()
#
#-----------------------------------------------------------
sub get_typedef_lookup {

    my($self) = @_;

    print "Building typedef_lookup\n";

    my $query = "SELECT  lower(c.name), c.cvterm_id ".
    "FROM cvterm c, cv ".
    "WHERE cv.name = 'relationship' ".
    "AND cv.cv_id = c.cv_id ".
    "AND c.is_relationshiptype = 1 ";

    return $self->_get_results_ref($query);

}

#-----------------------------------------------------------
# get_synonym_terms_lookup()
#
#-----------------------------------------------------------
sub get_synonym_terms_lookup {

    my($self) = @_;

    print "Building synonym_terms_lookup\n";

    my $query = "SELECT  lower(c.name), c.cvterm_id ".
    "FROM cvterm c, cv ".
    "WHERE cv.name = 'synonym_types' ".
    "AND cv.cv_id = c.cv_id ".
    "AND c.name like '%synonym%'";

    return $self->_get_lookup_db($query);

}

#-----------------------------------------------------------
# get_cvtermprop_id_lookup()
#
#-----------------------------------------------------------
sub get_cvtermprop_id_lookup {

    my ($self) = @_;

    print "Building cvtermprop_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, cvterm_id) + '_' + convert(VARCHAR, type_id) + '_' + convert(VARCHAR, rank) , cvtermprop_id ".
    "FROM cvtermprop ";


    return $self->_get_lookup_db($query);
}

#-----------------------------------------------------------
# get_cvterm_relationship_id_lookup()
#
#-----------------------------------------------------------
sub get_cvterm_relationship_id_lookup {
 
    my ($self) = @_;

    print "Building cvterm_relationship_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, type_id) + '_' + convert(VARCHAR, subject_id) + '_' + convert(VARCHAR, object_id) , cvterm_relationship_id ".
    "FROM cvterm_relationship ";
    
    
    return $self->_get_lookup_db($query);
}

#----------------------------------------------------------
# get_cvterm_dbxref_id_lookup()
#
#----------------------------------------------------------
sub get_cvterm_dbxref_id_lookup {

    my ($self) = @_;

    print "Building cvterm_dbxref_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, cvterm_id) + '_' + convert(VARCHAR, dbxref_id), cvterm_dbxref_id ".
    "FROM cvterm_dbxref ";
    
    
    return $self->_get_lookup_db($query);
}

#----------------------------------------------------------
# get_cvtermsynonym_id_lookup()
#
#----------------------------------------------------------
sub get_cvtermsynonym_id_lookup {

    my ($self) = @_;

    print "Building cvtermsynonym_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, cvterm_id) + '_' + synonym, cvtermsynonym_id ".
    "FROM cvtermsynonym ";
    
    
    return $self->_get_lookup_db($query);
}

#----------------------------------------------------------
# get_feature_id_lookup()
#
#----------------------------------------------------------
sub get_feature_id_lookup {

    my ($self) = @_;

    print "Building feature_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, organism_id) + '_' + uniquename + '_' + convert(VARCHAR, type_id), feature_id ".
	"FROM feature ".
    "WHERE is_analysis=0";
        
    return $self->_get_lookup_db($query);
}

#----------------------------------------------------------
# get_feature_pub_id_lookup()
#
#----------------------------------------------------------
sub get_feature_pub_id_lookup {

    my ($self) = @_;

    print "Building feature_pub_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, feature_id) + '_' + convert(VARCHAR, pub_id), feature_pub_id ".
    "FROM feature_pub ";
        
    return $self->_get_lookup_db($query);
}

#-------------------------------------------------------------
# get_featureloc_id_lookup()
#
#-------------------------------------------------------------
sub get_featureloc_id_lookup {

    my $self = shift;

    my $query = "SELECT convert(VARCHAR, fl.feature_id) + '_' + convert(VARCHAR, locgroup) + '_' + convert(VARCHAR, rank), featureloc_id ".
    "FROM featureloc fl ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, cvterm c1, cvterm c2 ".
    "WHERE f.feature_id = fl.feature_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f.type_id = c1.cvterm_id ".
    "OR f.type_id = c2.cvterm_id )) ";

    print "Retrieving all featureloc records related to some feature record having type that is neither match nor match_part\n";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }

    return $self->_get_lookup_db($query);
}

#-----------------------------------------------------------
# getFeaturelocIdLookup()
#
#-----------------------------------------------------------
sub getFeaturelocIdLookup {
        
    my $self = shift;

    my $query = "SELECT convert(VARCHAR, fl.srcfeature_id) + '_' + convert(VARCHAR, fl.feature_id) + '_' + convert(VARCHAR, fmin) + '_' + convert(VARCHAR, fmax)  + '_' + convert(VARCHAR, strand), featureloc_id ".
    "FROM featureloc fl ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, cvterm c1, cvterm c2 ".
    "WHERE f.feature_id = fl.feature_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f.type_id = c1.cvterm_id ".
    "OR f.type_id = c2.cvterm_id )) ";

    print "Retrieving all featureloc records related to some feature record having type that is neither match nor match_part\n";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }
    
    return $self->_get_lookup_db($query);
}

#-----------------------------------------------------------
# get_feature_dbxref_id_lookup()
#
#-----------------------------------------------------------
sub get_feature_dbxref_id_lookup {

    my $self = shift;

    my $query = "SELECT convert(VARCHAR, fd.feature_id) + '_' + convert(VARCHAR, fd.dbxref_id), fd.feature_dbxref_id ".
    "FROM feature_dbxref fd ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, cvterm c1, cvterm c2 ".
    "WHERE f.feature_id = fd.feature_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f.type_id = c1.cvterm_id ".
    "OR f.type_id = c2.cvterm_id )) ";

    print "Retrieving all feature_dbxref records related to some feature record having type that is neither match nor match_part\n";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }

    return $self->_get_lookup_db($query);
}

#-----------------------------------------------------------
# get_feature_relationship_id_lookup()
#
#-----------------------------------------------------------
sub get_feature_relationship_id_lookup {

    my $self = shift;
    
    my $query = "SELECT convert(VARCHAR, frel.subject_id) + '_' + convert(VARCHAR, frel.object_id) + '_' + convert(VARCHAR, frel.type_id) + '_' + convert(VARCHAR, frel.rank), frel.feature_relationship_id ".
    "FROM feature_relationship frel ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, cvterm c1, cvterm c2 ".
    "WHERE f.feature_id = frel.subject_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f.type_id = c1.cvterm_id ".
    "OR f.type_id = c2.cvterm_id )) ";
    
    print "Retrieving all feature_relationship records related to some feature record having type that is neither match nor match_part\n";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }
    
    return $self->_get_lookup_db($query);
}


#---------------------------------------------------------
# get_feature_relationship_pub_id_lookup()
#
#---------------------------------------------------------
sub get_feature_relationship_pub_id_lookup {

    my $self = shift;

    my $query = "SELECT convert(VARCHAR, fb.feature_relationship_id) + '_' + convert(VARCHAR, pub_id), feature_relationship_pub_id ".
    "FROM feature_relationship_pub fb ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature_relationship frel, feature f, cvterm c1, cvterm c2 ".
    "WHERE frel.feature_relationship_id = fb.feature_relationship_id ".
    "AND f.feature_id = frel.subject_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f.type_id = c1.cvterm_id ".
    "OR f.type_id = c2.cvterm_id )) ";
    
    print "Retrieving all feature_relationship_pub records related to some feature record having type that is neither match nor match_part\n";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }
    
    return $self->_get_lookup_db($query);
}


#----------------------------------------------------------
# get_feature_relationshipprop_id_lookup()
#
#----------------------------------------------------------
sub get_feature_relationshipprop_id_lookup {

    my $self = shift;
    
    my $query = "SELECT convert(VARCHAR, fb.feature_relationship_id) + '_' + convert(VARCHAR, fb.type_id) + '_' + convert(VARCHAR, fb.rank), feature_relationshipprop_id ".
    "FROM feature_relationshipprop fb ". 
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature_relationship frel, feature f, cvterm c1, cvterm c2 ".
    "WHERE frel.feature_relationship_id = fb.feature_relationship_id ".
    "AND f.feature_id = frel.subject_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f.type_id = c1.cvterm_id ".
    "OR f.type_id = c2.cvterm_id )) ";
    
    print "Retrieving all feature_relationshipprop records related to some feature record having type that is neither match nor match_part\n";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }
    
    return $self->_get_lookup_db($query);
}


#---------------------------------------------------------
# get_feature_relprop_pub_id_lookup()
#
#---------------------------------------------------------
sub get_feature_relprop_pub_id_lookup {

    my $self = shift;

    my $query = "SELECT convert(VARCHAR, fpub.feature_relationshipprop_id) + '_' + convert(VARCHAR, fpub.pub_id), fpub.feature_relprop_pub_id ".
    "FROM feature_relprop_pub fpub ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature_relationship frel, feature_relationshipprop fprop, feature f, cvterm c1, cvterm c2 ".
    "WHERE frel.feature_relationship_id = fprop.feature_relationship_id ".
    "AND fprop.feature_relationshipprop_id = fpub.feature_relationshipprop_id ".
    "AND frel.subject_id = f.feature_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f.type_id = c1.cvterm_id ".
    "OR f.type_id = c2.cvterm_id )) ";

    print "Retrieving all feature_relprop_pub records related to some feature record having type that is neither match nor match_part\n";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }
        
    return $self->_get_lookup_db($query);
}


#---------------------------------------------------------
# getFeaturepropIdLookup()
#
#---------------------------------------------------------
sub getFeaturepropIdLookup {

    my $self = shift;

    my $query = "SELECT convert(VARCHAR, fp.feature_id) + '_' + convert(VARCHAR, fp.type_id) + '_' + value, featureprop_id ".
    "FROM featureprop fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, cvterm c1, cvterm c2 ".
    "WHERE f.feature_id = fp.feature_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f.type_id = c1.cvterm_id ".
    "OR f.type_id = c2.cvterm_id )) ";

    print "Retrieving all featureprop records related to some feature record having type that is neither match nor match_part\n";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }
        
    return $self->_get_lookup_db($query);
}

#---------------------------------------------------------
# getFeaturepropMaxRankLookup()
#
#---------------------------------------------------------
sub getFeaturepropMaxRankLookup {

    my $self = shift;

    my $query = "SELECT convert(VARCHAR, fp.feature_id) + '_' + convert(VARCHAR, fp.type_id), MAX(rank) ".
    "FROM featureprop fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, cvterm c1, cvterm c2 ".
    "WHERE f.feature_id = fp.feature_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f.type_id = c1.cvterm_id ".
    "OR f.type_id = c2.cvterm_id )) ".
    "GROUP BY fp.feature_id, fp.type_id ";

    print "Retrieving all featureprop records related to some feature record having type that is neither match nor match_part for determining the next featureprop.rank to be assigned\n";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }
        
    return $self->_get_lookup_db($query);
}

#--------------------------------------------------------
# get_featureprop_pub_id_lookup()
#
#--------------------------------------------------------
sub get_featureprop_pub_id_lookup {

    my $self = shift;

    my $query = "SELECT convert(VARCHAR, fb.featureprop_id) + '_' + convert(VARCHAR, pub_id), featureprop_pub_id ".
    "FROM featureprop_pub fb ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM featureprop fp, feature f, cvterm c1, cvterm c2 ".
    "WHERE fp.featureprop_id = fb.featureprop_id ".
    "AND fp.feature_id = f.feature_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f.type_id = c1.cvterm_id ".
    "OR f.type_id = c2.cvterm_id )) ";

    print "Retrieving all featureprop_pub records related to some feature record having type that is neither match nor match_part\n";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }
    
    return $self->_get_lookup_db($query);
}


#---------------------------------------------------------------
# get_feature_cvterm_id_lookup()
#
#---------------------------------------------------------------
sub get_feature_cvterm_id_lookup {

    my $self = shift;

    my $query = "SELECT convert(VARCHAR, fc.feature_id) + '_' + convert(VARCHAR, cvterm_id)  + '_' + convert(VARCHAR, pub_id), feature_cvterm_id ".
    "FROM feature_cvterm fc ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, cvterm c1, cvterm c2 ".
    "WHERE f.feature_id = fc.feature_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f.type_id = c1.cvterm_id ".
    "OR f.type_id = c2.cvterm_id )) ";

    print "Retrieving all feature_cvterm records related to some feature record having type that is neither match nor match_part\n";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }
        
    return $self->_get_lookup_db($query);
}


#-----------------------------------------------------------
# get_feature_cvtermprop_id_lookup()
#
#-----------------------------------------------------------
sub get_feature_cvtermprop_id_lookup {

    my $self = shift;

    my $query = "SELECT convert(VARCHAR, fp.feature_cvterm_id) + '_' + convert(VARCHAR, fp.type_id)  + '_' + convert(VARCHAR, fp.rank), feature_cvtermprop_id ".
    "FROM feature_cvtermprop fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature_cvterm fc, feature f, cvterm c1, cvterm c2 ".
    "WHERE fc.feature_cvterm_id = fp.feature_cvterm_id ".
    "AND fc.feature_id = f.feature_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f.type_id = c1.cvterm_id ".
    "OR f.type_id = c2.cvterm_id )) ";

    print "Retrieving all feature_cvtermprop records related to some feature record having type that is neither match nor match_part\n";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }
    
    return $self->_get_lookup_db($query);
}

#-----------------------------------------------------------
# get_feature_cvterm_dbxref_id_lookup()
#
#-----------------------------------------------------------
sub get_feature_cvterm_dbxref_id_lookup {

    my $self = shift;

    my $query = "SELECT convert(VARCHAR, fp.feature_cvterm_id) + '_' + convert(VARCHAR, fp.dbxref_id), feature_cvterm_dbxref_id ".
    "FROM feature_cvterm_dbxref fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature_cvterm fc, feature f, cvterm c1, cvterm c2 ".
    "WHERE fc.feature_cvterm_id = fp.feature_cvterm_id ".
    "AND fc.feature_id = f.feature_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f.type_id = c1.cvterm_id ".
    "OR f.type_id = c2.cvterm_id )) ";

    print "Retrieving all feature_cvterm_dbxref records related to some feature record having type that is neither match nor match_part\n";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }
        
    return $self->_get_lookup_db($query);
}

#------------------------------------------------------------
# get_feature_cvterm_pub_id_lookup()
#
#------------------------------------------------------------
sub get_feature_cvterm_pub_id_lookup {

    my $self = shift;

    my $query = "SELECT convert(VARCHAR, fp.feature_cvterm_id) + '_' + convert(VARCHAR, fp.pub_id), feature_cvterm_pub_id ".
    "FROM feature_cvterm_pub fp ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature_cvterm fc, feature f, cvterm c1, cvterm c2 ".
    "WHERE fc.feature_cvterm_id = fp.feature_cvterm_id ".
    "AND fc.feature_id = f.feature_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f.type_id = c1.cvterm_id ".
    "OR f.type_id = c2.cvterm_id )) ";

    print "Retrieving all feature_cvterm_pub records related to some feature record having type that is neither match nor match_part\n";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }
        
    return $self->_get_lookup_db($query);
}

#---------------------------------------------------
# get_synonym_id_lookup()
#
#---------------------------------------------------
sub get_synonym_id_lookup {

    my ($self) = @_;

    print "Building synonym_id_lookup\n";

    my $query = "SELECT name  + '_' + convert(VARCHAR, type_id), synonym_id ".
    "FROM synonym ";
        
    return $self->_get_lookup_db($query);
}

#--------------------------------------------------------------
# get_feature_synonym_id_lookup()
#
#--------------------------------------------------------------
sub get_feature_synonym_id_lookup {

    my $self = shift;

    my $query = "SELECT convert(VARCHAR, synonym_id) + '_' + convert(VARCHAR, fs.feature_id)  + '_' + convert(VARCHAR, pub_id), feature_synonym_id ".
    "FROM feature_synonym fs ".
    "WHERE NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature f, cvterm c1, cvterm c2 ".
    "WHERE f.feature_id = fs.feature_id ".
    "AND c1.name = 'match' ".
    "AND c2.name = 'match_part' ".
    "AND ( f.type_id = c1.cvterm_id ".
    "OR f.type_id = c2.cvterm_id )) ";

    print "Retrieving all feature_synonym records related to some feature record having type that is neither match nor match_part\n";

    if ($self->{_logger}->is_debug()){
	$self->{_logger}->debug("$query");
    }

    return $self->_get_lookup_db($query);
}

#----------------------------------------------------
# get_evidence_codes_lookup()
#
#----------------------------------------------------
sub get_evidence_codes_lookup {

    my ($self) = @_;

    print "Building evidence_codes_lookup\n";

    my $query = "SELECT lower(c.name), c.cvterm_id ".
    "FROM cvterm c, cv ".
    "WHERE cv.name = 'evidence_code' ".
    "AND cv.cv_id = c.cv_id ";
        
    return $self->_get_lookup_db($query);
}

#----------------------------------------------------
# get_analysis_id_by_wfid_lookup()
#
#----------------------------------------------------
sub get_analysis_id_by_wfid_lookup {

    my($self) = @_;

    print "Building analysis_id_by_wfid_lookup\n";

    my $query = "SELECT ap.value, ap.analysis_id ".
    "FROM analysisprop ap, cvterm c ".
    "WHERE ap.type_id = c.cvterm_id ".
    "AND lower(c.name) = 'wfid' ";
    
    return $self->_get_lookup_db($query);

}

#----------------------------------------------------
# get_dbxrefprop_id_lookup()
#
#----------------------------------------------------
sub get_dbxrefprop_id_lookup {

    my($self) = @_;

    print "Building dbxrefprop_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, dbxref_id) + '_' + convert(VARCHAR, type_id) + '_' + value + '_' + convert(VARCHAR, rank), dbxrefprop_id ".
    "FROM dbxrefprop ";
    
    return $self->_get_lookup_db($query);

}

#----------------------------------------------------
# get_pub_id_lookup()
#
#----------------------------------------------------
sub get_pub_id_lookup {

    my($self) = @_;

    print "Building pub_id_lookup\n";

    my $query = "SELECT uniquename  + '_' + convert(VARCHAR, type_id), pub_id ".
    "FROM pub ";
    
    return $self->_get_lookup_db($query);

}

#-----------------------------------------------------
# get_pub_relationship_id_lookup()
#
#-----------------------------------------------------
sub get_pub_relationship_id_lookup {

    my($self) = @_;

    print "Building pub_relationship_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, subject_id) + '_' + convert(VARCHAR, object_id) + '_' + convert(VARCHAR, type_id), pub_relationship_id ".
    "FROM pub_relationship ";
    
    return $self->_get_lookup_db($query);

}

#-----------------------------------------------------
# get_pub_dbxref_id_lookup()
#
#-----------------------------------------------------
sub get_pub_dbxref_id_lookup {

    my($self) = @_;

    print "Building pub_dbxref_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, pub_id) + '_' + convert(VARCHAR, dbxref_id), pub_dbxref_id ".
    "FROM pub_dbxref ";
    
    return $self->_get_lookup_db($query);

}

#----------------------------------------------------
# get_pubauthor_id_lookup()
#
#----------------------------------------------------
sub get_pubauthor_id_lookup {

    my($self) = @_;

    print "Building pubauthor_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, pub_id) + '_' + convert(VARCHAR, rank), pubauthor_id ".
    "FROM pubauthor ";
    
    return $self->_get_lookup_db($query);

}

#----------------------------------------------------
# get_pubprop_id_lookup()
#
#----------------------------------------------------
sub get_pubprop_id_lookup {

    my($self) = @_;

    print "Building pubprop_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, pub_id) + '_' + convert(VARCHAR, type_id) , pubprop_id ".
    "FROM pubprop ";
    
    return $self->_get_lookup_db($query);

}

#----------------------------------------------------
# get_phylotree_id_lookup()
#
#----------------------------------------------------
sub get_phylotree_id_lookup {

    my($self) = @_;

    print "Building phylotree_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, phylotree_id), phylotree_id ".
    "FROM phylotree ";
    
    return $self->_get_lookup_db($query);

}

#----------------------------------------------------
# get_phylotree_pub_id_lookup()
#
#----------------------------------------------------
sub get_phylotree_pub_id_lookup {

    my($self) = @_;

    print "Building phylotree_pub_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, phylotree_id) + '_' + convert(VARCHAR, pub_id), phylotree_pub_id ".
    "FROM phylotree_pub ";
    
    return $self->_get_lookup_db($query);

}

#----------------------------------------------------
# get_phylonode_id_lookup()
#
#----------------------------------------------------
sub get_phylonode_id_lookup {

    my($self) = @_;

    print "Building phylonode_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, phylotree_id) + '_' + convert(VARCHAR, left_idx), phylonode_id ".
    "FROM phylonode ";
    
    return $self->_get_lookup_db($query);

}
 
#----------------------------------------------------
# get_phylonode_dbxref_id_lookup()
#
#----------------------------------------------------
sub get_phylonode_dbxref_id_lookup {

    my($self) = @_;

    print "Building phylonode_dbxref_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, phylonode_id) + '_' + convert(VARCHAR, dbxref_id), phylonode_dbxref_id ".
    "FROM phylonode_dbxref ";
    
    return $self->_get_lookup_db($query);

}

#----------------------------------------------------
# get_phylonode_pub_id_lookup()
#
#----------------------------------------------------
sub get_phylonode_pub_id_lookup {

    my($self) = @_;

    print "Building phylonode_pub_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, phylonode_id) + '_' + convert(VARCHAR, pub_id), phylonode_pub_id ".
    "FROM phylonode_pub ";
    
    return $self->_get_lookup_db($query);

}

#----------------------------------------------------
# get_phylonode_organism_id_lookup()
#
#----------------------------------------------------
sub get_phylonode_organism_id_lookup {

    my($self) = @_;

    print "Building phylonode_organism_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, phylonode_id) + '_' + convert(VARCHAR, organism_id), phylonode_organism_id ".
    "FROM phylonode_organism ";
    
    return $self->_get_lookup_db($query);

}

#----------------------------------------------------
# get_phylonodeprop_id_lookup()
#
#----------------------------------------------------
sub get_phylonodeprop_id_lookup {

    my($self) = @_;

    print "Building phylonodeprop_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, phylonode_id) + '_' + convert(VARCHAR, type_id) + '_' + convert(VARCHAR, rank), phylonodeprop_id ".
    "FROM phylonodeprop ";
    
    return $self->_get_lookup_db($query);

}

#----------------------------------------------------
# get_phylonode_relationship_id_lookup()
#
#----------------------------------------------------
sub get_phylonode_relationship_id_lookup {

    my($self) = @_;

    print "Building phylonode_relationship_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, subject_id) + '_' + convert(VARCHAR, object_id) + '_' + convert(VARCHAR, type_id), phylonode_relationship_id ".
    "FROM phylonode_relationship ";
    
    return $self->_get_lookup_db($query);

}

#----------------------------------------------------
# get_cvterm_id_by_alt_id_lookup()
#
#----------------------------------------------------
sub get_cvterm_id_by_alt_id_lookup {

    my($self) = @_;

    print "Building cvterm_id_by_alt_id_lookup\n";

    my $query = "SELECT convert(VARCHAR, c.cv_id) + '_' + convert(VARCHAR, d.accession), c.cvterm_id  ".
    "FROM cvterm c, dbxref d, cvterm_dbxref cd ".
    "WHERE d.dbxref_id = cd.dbxref_id ".
    "AND cd.cvterm_id = c.cvterm_id ";
    
    return $self->_get_lookup_db($query);

}

#----------------------------------------------------
# get_cvterm_max_is_obsolete_lookup()
#
#----------------------------------------------------
sub get_cvterm_max_is_obsolete_lookup {

    my ($self, $cv_id) = @_;

    if (!defined($cv_id)){
	$self->{_logger}->logdie("cv_id was not defined");
    }
 
    if ($cv_id =~ /;/){
	return undef;
    }


    print "Building cvterm_max_is_obsolete_lookup\n";

    my $query = "SELECT lower(name), cvterm_id, is_obsolete ".
    "FROM cvterm ".
    "WHERE cv_id = $cv_id ".
    "GROUP BY name ".
    "HAVING is_obsolete = max(is_obsolete) ";

    return $self->_get_lookup_db($query);

}

#---------------------------------------------------------------
# get_cvterm_id_by_accession()
#
#---------------------------------------------------------------
sub get_cvterm_id_by_accession {

    my($self, $cv_id) = @_;

    print "Building cvterm_id_by_accession lookup\n";

    my $query = "SELECT convert(VARCHAR, d.accession), c.cvterm_id  ".
    "FROM cvterm c, dbxref d ".
    "WHERE c.dbxref_id = d.dbxref_id ".
    "AND c.cv_id = $cv_id " ;
    
    return $self->_get_lookup_db($query);

}

#-------------------------------------------------------------
# get_relationship_typedef_lookup()
#
#-------------------------------------------------------------
sub get_relationship_typedef_lookup {

    my($self) = @_;

    print "Building relationship_typedef_lookup\n";

    my $query = "SELECT  lower(c.name), c.cvterm_id ".
    "FROM cvterm c, cv ".
    "WHERE cv.name = 'relationship' ".
    "AND cv.cv_id = c.cv_id ".
    "AND c.is_relationshiptype = 1 ";

    return $self->_get_results_ref($query);

}

#-------------------------------------------------------------
# get_cds_and_polypeptide_data_for_splice_site_derivation()
#
#-------------------------------------------------------------
sub get_cds_and_polypeptide_data_for_splice_site_derivation {

    my $self = shift;
    my ($assemblyFeatureId1, $assemblyFeatureId2) = @_;

    if (!defined($assemblyFeatureId1)){
	$self->{_logger}->logdie("assembly feature_id 1 was not defined");
    }
    if (!defined($assemblyFeatureId2)){
	$self->{_logger}->logdie("assembly feature_id 2 was not defined");
    }
    
    print "Retrieving CDS and polypeptide data for splice_site derivation for all assemblies between assembly with ".
    "feature_id '$assemblyFeatureId1' and assembly with feature_id '$assemblyFeatureId2'\n";
    
    my $query = "SELECT a.feature_id, c.uniquename, cfl.fmin, cfl.fmax, p.uniquename, p.seqlen, p.feature_id, p.organism_id, cfl.strand, pfl.strand, pfl.fmin, pfl.fmax ".
    "FROM feature c, feature p, feature t, cvterm cds, cvterm poly, cvterm trans, featureloc cfl, featureloc pfl, feature_relationship t2c, feature_relationship c2p, feature a, cvterm assem ".
    "WHERE c.type_id = cds.cvterm_id ".
    "AND cds.name = 'CDS' ".
    "AND p.type_id = poly.cvterm_id ".
    "AND poly.name = 'polypeptide' ".
    "AND t.type_id = trans.cvterm_id ".
    "AND trans.name = 'transcript' ".
    "AND t.feature_id = t2c.object_id ".
    "AND t2c.subject_id = c.feature_id ".
    "AND c.feature_id = c2p.object_id ".
    "AND c2p.subject_id = p.feature_id ".
    "AND c.feature_id = cfl.feature_id ".
    "AND p.feature_id = pfl.feature_id ".
    "AND p.is_analysis = 0 ".
    "AND t.is_analysis = 0 ".
    "AND c.is_analysis = 0 ".
    "AND cfl.srcfeature_id = a.feature_id ".
    "AND pfl.srcfeature_id = a.feature_id ".
    "AND assem.name = 'assembly' ".
    "AND assem.cvterm_id = a.type_id ".
    "AND a.feature_id BETWEEN ? AND ? ";

    return $self->_get_results_ref($query, $assemblyFeatureId1, $assemblyFeatureId2);

}

#-------------------------------------------------------------
# get_exons_data_for_splice_site_derivation()
#
#-------------------------------------------------------------
sub get_exon_data_for_splice_site_derivation {

    my $self = shift;
    my ($assemblyFeatureId1, $assemblyFeatureId2) = @_;

    if (!defined($assemblyFeatureId1)){
	$self->{_logger}->logdie("assembly feature_id 1 was not defined");
    }
    if (!defined($assemblyFeatureId2)){
	$self->{_logger}->logdie("assembly feature_id 2 was not defined");
    }

    my $assemblyCvtermId = $self->getCvtermIdByTermNameByOntology('assembly',
								  'SO');
    if (!defined($assemblyCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'assembly' ".
				 "in ontology 'SO'");
    }

    my $cdsCvtermId = $self->getCvtermIdByTermNameByOntology('CDS',
							     'SO');
    if (!defined($cdsCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'CDS' ".
				 "in ontology 'SO'");
    }

    my $exonCvtermId = $self->getCvtermIdByTermNameByOntology('exon',
							      'SO');
    if (!defined($exonCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'exon' ".
				 "in ontology 'SO'");
    }

    my $transcriptCvtermId = $self->getCvtermIdByTermNameByOntology('transcript',
								    'SO');
    if (!defined($transcriptCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'transcript' ".
				 "in ontology 'SO'");
    }

    print "Retrieving exon data for splice_site derivation for all assemblies between assembly with feature_id ".
    "$assemblyFeatureId1' and assembly with feature_id '$assemblyFeatureId2'\n";

    my $query = "SELECT cds.uniquename, efl.fmin, efl.fmax, exon.feature_id, efl.strand, assembly.feature_id ".
    "FROM feature exon, feature cds, feature transcript, featureloc efl, feature_relationship t2e, feature_relationship t2c, feature assembly, featureloc flcds ".
    "WHERE exon.type_id = ? ".
    "AND cds.type_id = ? ".
    "AND assembly.type_id = ? ".
    "AND transcript.type_id = ? ".
    "AND transcript.feature_id = t2e.object_id ".
    "AND t2e.subject_id = exon.feature_id ".
    "AND transcript.feature_id = t2c.object_id ".
    "AND t2c.subject_id = cds.feature_id ".
    "AND exon.feature_id = efl.feature_id ".
    "AND transcript.is_analysis = 0 ".
    "AND cds.is_analysis = 0 ". 
    "AND exon.is_analysis = 0 ".
    "AND efl.srcfeature_id = assembly.feature_id ".  ## the exon should localize to the assembly
    "AND cds.feature_id = flcds.feature_id ".   ## the CDS should localize to the same assembly
    "AND flcds.srcfeature_id = assembly.feature_id ".
    "AND assembly.feature_id BETWEEN ? AND ? ";

    return $self->_get_results_ref($query, $exonCvtermId, $cdsCvtermId, $assemblyCvtermId, $transcriptCvtermId, $assemblyFeatureId1, $assemblyFeatureId2);

}

#-------------------------------------------------------------
# get_assemblies_with_exons_list()
#
#-------------------------------------------------------------
sub get_assemblies_with_exons_list {

    my ($self) = @_;

    print "Retrieving list of assembly identifiers\n";

    #
    # Retrieve non-obsolete, non-analysis assembly identifiers
    # for which there is at least one non-obsolete, non-analysis
    # exon localized to it.
    #

    my $query = "SELECT distinct a.uniquename ".
    "FROM feature a, cvterm c, feature e, cvterm x, featureloc fl ".
    "WHERE c.name = 'assembly' ".
    "AND c.cvterm_id = a.type_id ".
    "AND a.is_obsolete = 0 ".
    "AND a.is_analysis = 0 ".
    "AND a.feature_id  = fl.srcfeature_id ".
    "AND fl.feature_id = e.feature_id ".
    "AND e.type_id = x.cvterm_id ".
    "AND x.name = 'exon' ".
    "AND e.is_analysis = 0 ".
    "AND e.is_obsolete = 0 ";


    return $self->_get_results_ref($query);

}

#-------------------------------------------------------------
# get_assemblies_by_organism_abbreviation()
#
#-------------------------------------------------------------
sub get_assemblies_by_organism_abbreviation {

    my ($self, $abbreviation) = @_;

    print "Retrieving list of assembly identifiers for organism abbreviation '$abbreviation'\n";

    #
    # Retrieve non-obsolete, non-analysis assembly identifiers
    # for which there is at least one non-obsolete, non-analysis
    # exon localized to it.  The assemblies should belong to the
    # organism with specified abbreviation.

    my $query = "SELECT distinct a.feature_id ".
    "FROM feature a, cvterm c, feature e, cvterm x, featureloc fl, organism o ".
    "WHERE c.name = 'assembly' ".
    "AND c.cvterm_id = a.type_id ".
    "AND a.organism_id = o.organism_id ".
    "AND o.abbreviation = '$abbreviation' ".    
    "AND a.is_obsolete = 0 ".
    "AND a.is_analysis = 0 ".
    "AND a.feature_id  = fl.srcfeature_id ".
    "AND fl.feature_id = e.feature_id ".
    "AND e.type_id = x.cvterm_id ".
    "AND x.name = 'exon' ".
    "AND e.is_analysis = 0 ".
    "AND e.is_obsolete = 0 ";

    return $self->_get_results_ref($query);

}

#-------------------------------------------------------------------------------------------------------------------------------------------------
# get_pub_id_from_pub()
#  
#-------------------------------------------------------------------------------------------------------------------------------------------------
sub get_pub_id_from_pub {

    my ($self, %param) = @_;

    my $phash = \%param;

    my $title       = $phash->{'title'}       if (exists $phash->{'title'});
    my $volumetitle = $phash->{'volumetitle'} if (exists $phash->{'volumetitle'});
    my $volume      = $phash->{'volume'}      if (exists $phash->{'volume'});
    my $series_name = $phash->{'series_name'} if (exists $phash->{'series_name'});
    my $issue       = $phash->{'issue'}       if (exists $phash->{'issue'});
    my $pyear       = $phash->{'pyear'}       if (exists $phash->{'pyear'});
    my $pages       = $phash->{'pages'}       if (exists $phash->{'pages'});
    my $miniref     = $phash->{'miniref'}     if (exists $phash->{'miniref'});
    my $uniquename  = $phash->{'uniquename'}  if (exists $phash->{'uniquename'});
    my $type_id     = $phash->{'type_id'}     if (exists $phash->{'type_id'});
    my $is_obsolete = $phash->{'is_obsolete'} if (exists $phash->{'is_obsolete'});
    my $publisher   = $phash->{'publisher'}   if (exists $phash->{'publisher'});
    my $pubplace    = $phash->{'pubplace'}    if (exists $phash->{'pubplace'});
    
    if (!defined($miniref)){
	$self->{_logger}->logdie("miniref was not defined");
	return undef;
    }
    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
	return undef;
    }
    if (!defined($type_id)){
	$self->{_logger}->logdie("type_id was not defined");
	return undef;
    }
    if (!defined($is_obsolete)){
	$self->{_logger}->logdie("is_obsolete was not defined");
	return undef;
    }

    if ($type_id =~ /;/){
	return undef;
    }

    my $query = "SELECT pub_id  ".
    "FROM pub ".
    "WHERE miniref = ? ".
    "AND uniquename = ? ".
    "AND type_id = ? ".
    "AND is_obsolete = ? ";
    
    $query .= "AND title = '$title' "             if (defined($title));
    $query .= "AND volumetitle = '$volumetitle' " if (defined($volumetitle));
    $query .= "AND volume = '$volume' "           if (defined($volume));
    $query .= "AND series_name = '$series_name' " if (defined($series_name));
    $query .= "AND issue = '$issue' "             if (defined($issue));
    $query .= "AND pyear = '$pyear' "             if (defined($pyear));
    $query .= "AND pages = '$pages' "             if (defined($pages));
    $query .= "AND publisher = '$publisher' "     if (defined($publisher));
    $query .= "AND pubplace = '$pubplace' "       if (defined($pubplace));

    return $self->_get_results_ref($query, $miniref, $uniquename, $type_id, $is_obsolete);

}

#-------------------------------------------------------
# getCdsSequences()
#  
#-------------------------------------------------------
sub getCdsSequences {

    my ($self, $contig) = @_;

    print "Creating CDS to residues lookup\n";

    my $query = "SELECT f.uniquename, f.residues ".
    "FROM featureloc fl, feature f, cvterm c, feature contig ".
    "WHERE c.name = 'CDS' ".
    "AND c.cvterm_id = f.type_id ".
    "AND f.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = contig.feature_id ".
    "AND contig.uniquename = '$contig' ";

    return $self->_get_results_ref($query);

}

#-------------------------------------------------------
# getContigUniquenameToResiduesLookup()
#  
#-------------------------------------------------------
sub getContigUniquenameToResiduesLookup {

    my ($self, $contig) = @_;

    print "Creating contigUniquenameToResiduesLookup\n";

    my $query = "SELECT f.uniquename, f.residues ".
    "FROM cvterm c, feature f ".
    "WHERE c.name = 'assembly' ";

    if (defined ($contig)){
	$query .= "AND f.uniquename = '$contig' ";
    }

    return $self->_get_results_ref($query);

}

#-------------------------------------------------------
# getFeaturelocDataByType()
#  
#-------------------------------------------------------
sub getFeaturelocDataByType {

    my ($self, $contig, $featureType) = @_;

    print "Creating featurelocDataByTypeLookup for feature types '$featureType'\n";

    my $query = "SELECT f.feature_id, f.uniquename, fl.fmin, fl.fmax, fl.strand ".
    "FROM featureloc fl, feature f, cvterm c, feature contig ".
    "WHERE c.name = '$featureType' ".
    "AND c.cvterm_id = f.type_id ".
    "AND f.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = contig.feature_id ".
    "AND contig.uniquename = '$contig' ";

    return $self->_get_results_ref($query);

}

#-------------------------------------------------------
# getObjectToSubjectLookup()
#  
#-------------------------------------------------------
sub getObjectToSubjectLookup {

    my ($self, $contig, $objectType, $subjectType) = @_;

    print "Creating objectToSubjectLookup for object types '$objectType' and subject types '$subjectType'\n";

    my $query = "SELECT object.feature_id, subject.feature_id ".
    "FROM featureloc fl, feature object, feature subject, feature contig, cvterm co, cvterm cs, feature_relationship frel ".
    "WHERE co.name = '$objectType' ".
    "AND cs.name = '$subjectType' ".
    "AND co.cvterm_id = object.type_id ".
    "AND cs.cvterm_id = subject.type_id ".
    "AND object.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = contig.feature_id ".
    "AND contig.uniquename = '$contig' ".
    "AND object.feature_id = frel.object_id ".
    "AND frel.subject_id = subject.feature_id ";

    return $self->_get_results_ref($query);

}

#-------------------------------------------------------
# getContigToSeqlenLookup()
#  
#-------------------------------------------------------
sub getContigToSeqlenLookup {

    my ($self) = @_;

    print "Creating contigToSeqlenLookup\n";
    
    my $query = "SELECT f.uniquename, f.seqlen ".
    "FROM feature f, cvterm c ".
    "WHERE c.name = 'assembly' ".
    "AND c.cvterm_id = f.type_id ";

    return $self->_get_results_ref($query);

}

#-------------------------------------------------------
# getContigToAttributeLookup()
#  
#-------------------------------------------------------
sub getContigToAttributeLookup {

    my ($self, $attributeType) = @_;
    
    print "Creating contigToAttributesLookup for attribute types '$attributeType'\n";

    my $query = "SELECT f.uniquename, fp.value ".
    "FROM feature f, cvterm c, cvterm c2, featureprop fp ".
    "WHERE c.name = 'assembly' ".
    "AND c.cvterm_id = f.type_id ".
    "AND c2.name = ? ".
    "AND c2.cvterm_id = fp.type_id ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $attributeType);

}

#-------------------------------------------------------
# getContigToOrganismLookup()
#  
#-------------------------------------------------------
sub getContigToOrganismLookup {

    my ($self) = @_;

    print "Creating contigToOrganismLookup\n";

    my $query = "SELECT f.uniquename, o.genus, o.species ".
    "FROM feature f, organism o, cvterm c ".
    "WHERE c.name = 'assembly' ".
    "AND c.cvterm_id = f.type_id ".
    "AND f.organism_id = o.organism_id ";

    return $self->_get_results_ref($query);
}

#-------------------------------------------------------
# getOrganismNameToAttrbuteLookup()
#  
#-------------------------------------------------------
sub getOrganismNameToAttributeLookup {

    my ($self, $attributeType) = @_;

    print "Creating organismNameToAttributeLookup for attribute types '$attributeType'\n";

    my $query = "SELECT o.genus, o.species, op.value ".
    "FROM organism o, organismprop op, cvterm c ".
    "WHERE c.name = ? ".
    "AND c.cvterm_id = op.type_id ".
    "AND o.organism_id = op.organism_id ";

    return $self->_get_results_ref($query, $attributeType);

}

#-------------------------------------------------------
# getFeatureAttributeLookup()
#  
#-------------------------------------------------------
sub getFeatureAttributeLookup {

    my ($self, $contig, $attributeType, $featureType) = @_;

    print "Creating featureAttributeLookup for feature type '$featureType' and attribute type '$attributeType'\n";

    my $query = "SELECT fp.feature_id, fp.value ".
    "FROM featureprop fp, feature t, feature contig, cvterm c1, cvterm c2, featureloc fl ".
    "WHERE c1.name = ? ".
    "AND c2.name = ? ".
    "AND c1.cvterm_id = fp.type_id ".
    "AND fp.feature_id = t.feature_id ".
    "AND c2.cvterm_id = t.type_id ".
    "AND t.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = contig.feature_id ".
    "AND contig.uniquename = ? ";

    return $self->_get_results_ref($query, $attributeType, $featureType, $contig);
}

#-------------------------------------------------------
# getFeatureCrossReferenceLookup()
#  
#-------------------------------------------------------
sub getFeatureCrossReferenceLookup {

    my ($self, $contig, $featureType) = @_;

    print "Creating featureCrossReferenceLookup for feature type '$featureType'\n";

    my $query = "SELECT t.feature_id, db.name, d.accession ".
    "FROM feature t, feature contig, cvterm c1, feature_dbxref fd, dbxref d, db, featureloc fl ".
    "WHERE c1.name = ? ".
    "AND c1.cvterm_id = t.type_id ".
    "AND t.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = contig.feature_id ".
    "AND contig.uniquename = ? ".
    "AND t.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = d.dbxref_id ".
    "AND d.db_id = db.db_id ";

    return $self->_get_results_ref($query, $featureType, $contig);
}

#-------------------------------------------------------
# getFeatureLocusLookup()
#  
#-------------------------------------------------------
sub getFeatureLocusLookup {

    my ($self, $contig, $featureType) = @_;

    print "Creating featureLocusLookup for feature type '$featureType'\n";

    my $query = "SELECT t.feature_id, d.accession ".
    "FROM feature t, feature contig, cvterm c1, feature_dbxref fd, dbxref d, featureloc fl ".
    "WHERE c1.name = ? ".
    "AND c1.cvterm_id = t.type_id ".
    "AND t.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = contig.feature_id ".
    "AND contig.uniquename = ? ".
    "AND t.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = d.dbxref_id ".
    "AND d.version = 'locus' ";
    
    return $self->_get_results_ref($query, $featureType, $contig);
}

#-------------------------------------------------------
# getGeneOntologyLookup()
#  
#-------------------------------------------------------
sub getGeneOntologyLookup {

    my ($self, $contig, $featureType) = @_;

    print "Creating geneOntologyLookup for feature type '$featureType'\n";

    my $query = "SELECT fc.feature_id, d.accession ".
	"FROM feature t, feature contig, featureloc fl, feature_cvterm fc, cvterm c1, cvterm c2, cv cv, dbxref d ".
	"WHERE contig.uniquename = ? ".
	"AND contig.feature_id = fl.srcfeature_id ".
	"AND fl.feature_id = t.feature_id ".
	"AND t.type_id = c1.cvterm_id ".
	"AND c1.name = ? ".
	"AND t.feature_id = fc.feature_id ".
	"AND fc.cvterm_id = c2.cvterm_id ".
	"AND c2.cv_id = cv.cv_id ".
	"AND cv.name = 'GO' ".
	"AND c2.dbxref_id = d.dbxref_id ";
    
    return $self->_get_results_ref($query, $featureType, $contig);
}

#-------------------------------------------------------
# getEcNumberLookup()
#  
#-------------------------------------------------------
sub getEcNumberLookup {

    my ($self, $contig, $featureType) = @_;

    print "Creating ecNumberLookup for feature type '$featureType'\n";

    my $query = "SELECT fc.feature_id, d.accession ".
	"FROM feature t, feature contig, featureloc fl, feature_cvterm fc, cvterm_dbxref cd, cvterm c1, cvterm c2, cv cv, dbxref d ".
	"WHERE contig.uniquename = ? ".
	"AND contig.feature_id = fl.srcfeature_id ".
	"AND fl.feature_id = t.feature_id ".
	"AND t.type_id = c1.cvterm_id ".
	"AND c1.name = ? ".
	"AND t.feature_id = fc.feature_id ".
	"AND fc.cvterm_id = c2.cvterm_id ".
	"AND c2.cv_id = cv.cv_id ".
	"AND cv.name = 'EC' ".
	"AND c2.cvterm_id = cd.cvterm_id ".
	"AND cd.dbxref_id = d.dbxref_id ";
    
    return $self->_get_results_ref($query, $featureType, $contig);
}

#--------------------------------------------------------------------
# doCreateView()
#
#--------------------------------------------------------------------
sub doCreateView {

    my ($self, $algorithm, $analysis_id, $testmode) = @_;
 
    my $analysis_filter        = "CREATE VIEW filt_analysis AS SELECT * FROM analysis a WHERE a.analysis_id = a.analysis_id AND ( ";
    my $analysisprop_filter    = "CREATE VIEW filt_analysisprop AS SELECT * FROM analysisprop ap WHERE NOT EXISTS ( SELECT 1 FROM analysis a WHERE ap.analysis_id = a.analysis_id AND ( ";
    my $analysisfeature_filter = "CREATE VIEW filt_analysisfeature AS SELECT * FROM analysisfeature af WHERE NOT EXISTS ( SELECT 1 FROM analysis a WHERE af.analysis_id = a.analysis_id AND ( ";
    my $feature_filter         = "CREATE VIEW filt_feature AS SELECT * FROM feature f WHERE NOT EXISTS ( SELECT 1 FROM analysis a, analysisfeature af WHERE f.feature_id = af.feature_id AND af.analysis_id = a.analysis_id AND (";
    my $featureprop_filter     = "CREATE VIEW filt_featureprop AS SELECT * FROM featureprop fp WHERE NOT EXISTS ( SELECT 1 FROM analysis a, analysisfeature af, feature f WHERE fp.feature_id = f.feature_id AND f.feature_id = af.feature_id AND af.analysis_id = a.analysis_id AND (";
    my $featureloc_filter      = "CREATE VIEW filt_featureloc AS SELECT * FROM featureloc fl WHERE NOT EXISTS ( SELECT 1 FROM analysis a, analysisfeature af, feature f WHERE fl.feature_id = f.feature_id AND f.feature_id = af.feature_id AND af.analysis_id = a.analysis_id AND (";
    
    
    if ((defined($algorithm)) and (uc($algorithm) ne 'NONE')){
	
	
	$analysis_filter        .= " a.algorithm not in ( ";
	$analysisprop_filter    .= " a.algorithm in ( ";
	$analysisfeature_filter .= " a.algorithm in ( ";
	$feature_filter         .= " a.algorithm in ( ";
	$featureprop_filter     .= " a.algorithm in ( ";
	$featureloc_filter      .= " a.algorithm in ( ";
	
	foreach my $algo (@$algorithm){
	    
	    $analysis_filter        .= "'$algo',";
	    $analysisprop_filter    .= "'$algo',";
	    $analysisfeature_filter .= "'$algo',";
	    $feature_filter         .= "'$algo',";
	    $featureprop_filter     .= "'$algo',";
	    $featureloc_filter      .= "'$algo',";
	}
	chop $analysis_filter;
	chop $analysisprop_filter;
	chop $analysisfeature_filter;
	chop $feature_filter;
	chop $featureprop_filter;
	chop $featureloc_filter;
	
	$analysis_filter .= ")";
	$analysisprop_filter .= ")";
	$analysisfeature_filter .= ")";
	$feature_filter .= ")";
	$featureprop_filter .= ")";
	$featureloc_filter .= ")";
    }
	    
    if ((defined($analysis_id)) and (uc($analysis_id) ne 'NONE')){
		
	$analysis_filter        .= " a.analysis_id not in ( ";
	$analysisprop_filter    .= " a.analysis_id in ( ";
	$analysisfeature_filter .= " a.analysis_id in ( "; 
	$feature_filter         .= " a.analysis_id in ( "; 
	$featureprop_filter     .= " a.analysis_id in ( "; 
	$featureloc_filter      .= " a.analysis_id in ( "; 
	
	
	foreach my $id (@$analysis_id){
	    
	    $analysis_filter        .= "$id,";
	    $analysisprop_filter    .= "$id,";
	    $analysisfeature_filter .= "$id,"; 
	    $feature_filter         .= "$id,"; 
	    $featureprop_filter     .= "$id,"; 
	    $featureloc_filter      .= "$id,"; 
	}
	chop $analysis_filter;
	chop $analysisprop_filter;
	chop $analysisfeature_filter;
	chop $feature_filter;
	chop $featureprop_filter;
	chop $featureloc_filter;
	
	$analysis_filter         .= ")";
	$analysisprop_filter     .= ")";
	$analysisfeature_filter  .= ")";
	$feature_filter          .= ")";
	$featureprop_filter      .= ")";
	$featureloc_filter       .= ")";
    }
    
    $analysis_filter        .= ")"; 
    $analysisfeature_filter .= "))"; 
    $analysisprop_filter    .= "))"; 
    $feature_filter         .= "))";
    $featureprop_filter     .= "))";
    $featureloc_filter      .= "))";

    my @ar = (
	      $analysis_filter,
	      $analysisprop_filter,
	      $analysisfeature_filter,
	      $feature_filter,
	      $featureprop_filter,
	      $featureloc_filter
	      );

    if ($testmode){
	$self->{_logger}->info("User specified testmode '$testmode' therefore no views will be created.  Commands are: @ar");
    }
    else{
	foreach my $sql (@ar){
	    $self->_force_do_sql($sql);
	}
    }
}

#------------------------------------------------------------------
# doDropFilters()
#
#------------------------------------------------------------------
sub do_drop_filters {
    
    my ($self, $testmode) = @_;

    my @ar = (
	      "DROP VIEW filt_analysis",
	      "DROP VIEW filt_analysisprop",
	      "DROP VIEW filt_analysisfeature",
	      "DROP VIEW filt_feature",
	      "DROP VIEW filt_featureprop",
	      "DROP VIEW filt_featureloc",
	      );
    
    if ($testmode){
	$self->{_logger}->info("User specified testmode '$testmode' therefore no views will be dropped.  Commands are: @ar");
    }
    else{
	foreach my $sql (@ar){
	    $self->_force_do_sql($sql);
	}
    }    
}

#----------------------------------------------------------------
# doUpdateFeatureRecord()
#
#----------------------------------------------------------------
sub do_update_feature_record {

    my ($self, %parameter) = @_;
    my $phash = \%parameter;

    my ($feature_id, $name, $uniquename, $residues, $seqlen, $timelastmodified, $o_name, $o_md5);
    
    if ((exists $phash->{'feature_id'}) and (defined($phash->{'feature_id'}))){
	$feature_id = $phash->{'feature_id'};
    }
    if ((exists $phash->{'name'}) and (defined($phash->{'name'}))){
	$name = $phash->{'name'};
    }
    if ((exists $phash->{'uniquename'}) and (defined($phash->{'uniquename'}))){
	$uniquename = $phash->{'uniquename'};
    }
    if ((exists $phash->{'residues'}) and (defined($phash->{'residues'}))){
	$residues = $phash->{'residues'};
    }   
    if ((exists $phash->{'seqlen'}) and (defined($phash->{'seqlen'}))){
	$seqlen = $phash->{'seqlen'};
    }
    if ((exists $phash->{'timelastmodified'}) and (defined($phash->{'timelastmodified'}))){
	$timelastmodified  = $phash->{'timelastmodified'}; 
    }
    if ((exists $phash->{'o_name'}) and (defined($phash->{'o_name'}))){
	$o_name = $phash->{'o_name'};
    }
    if ((exists $phash->{'o_md5'}) and (defined($phash->{'o_md5'}))){
	$o_md5 = $phash->{'o_md5'};
    }

    my $updateflag=0;
    my $sql = "UPDATE feature SET ";

    if ((defined($residues)) and (length($residues) > 0)){
	
	#
	# Residues was passed in, check if is different from value currently stored in chado.feature.residues
	#
	my $md5 = Digest::MD5::md5($residues);
	
	
	if ($md5 ne $o_md5){
	    
	    $updateflag=1;
	    
	    #
	    # If seqlen was not defined, set it as length of the residues
	    #
	    $seqlen = length($residues) if (!defined($seqlen));
	    
	    $sql .= " seqlen = $seqlen, md5checksum = '$md5', residues = '$residues', "; 
	    
	    #
	    # Set the textsize so that Sybase does not truncate the feature.residues field
	    #
	    $self->do_set_textsize($seqlen);
	    
	}
    }
    

    if ((defined($name)) and (length($name) > 0)){

	if ($name ne $o_name){
	    $updateflag=1;
	    $sql .= " name = '$name', ";
	}
    }

    if ($updateflag == 1){
	$sql .= " timelastmodified = '$timelastmodified' where feature_id = $feature_id";

	$self->_do_sql($sql);
	$self->{_logger}->info("$sql");
    }

}

#-----------------------------------------------------
# getTableRecordCount()
#
#-----------------------------------------------------
sub getTableRecordCount {

    my ($self, $table) = @_;

    my $query = "SELECT count(*) ".
    "FROM $table ";

    my @ret = $self->_get_results($query);
    if (defined($ret[0][0])){
	return $ret[0][0];
    }
    else {
	$self->{_logger}->error("Could not retrieve row count ".
				"for table '$table'");
	return undef;
    }
}

#----------------------------------------------------------------
# doDropTables()
#
#----------------------------------------------------------------
sub doDropTables {

    my ($self, $list, $commit_order, $database) = @_;

    #--------------------------------------------------------------------------------------------------------------
    # Drop the tables in the reverse commit order.
    # This will ensure that all tables containing foreign referenced records are only drop
    # after the referencee tables themselves have been dropped.
    #
    foreach my $table (reverse @{$commit_order}){

	#----------------------------------------------------------------------------------------------------------
	# We want to drop all tables listed in the dynamically generated sysobjects list.
	# For the tables which correspond to the known list of chado tables, we must ensure that these tables
	# are dropped in the correct order.
	# Tables which do not belong to the list of known chado tables will be dealt with further downstream.
	#
	if ((exists $list->{$table}) && (defined($list->{$table}))){


	    #-------------------------------------------------------------------------------------------------------
	    # Incremented value will be used later to verify whether all of the tables in
	    # the dynamically generated sysobjects list were dropped.
	    #
	    $list->{$table}++;
	    #
	    #
	    #-------------------------------------------------------------------------------------------------------
	    my $sql = "DROP TABLE $table";
	   
	    $self->_do_sql($sql);
	    
	}
	else {
	    #-------------------------------------------------------------------------------------------------------
	    # This particular table was not one of the known chado tables.
	    # It will be dropped later downstream...
	    #
	    $self->{_logger}->error("Table '$table' was part of COMMIT_ORDER list, however did not find this table in database '$database'");
	    #
	    #-------------------------------------------------------------------------------------------------------

	}
    }


    #---------------------------------------------------------------------------------------------------------------
    # Verify whether all of the tables in the dynamically generated sysobjects list
    # were processed.
    #
    foreach my $table (sort keys %{$list}) {

	if ($list->{$table} > 1 ){
	    #
	    # Good.
	    #
	}
	else{
	    #-------------------------------------------------------------------------------------------------------
	    # All other non-chado tables are dropped here.
	    #
	    $self->{_logger}->warn("Table '$table' was not previously processed, dropping it now...");
	    
	    my $sql = "DROP TABLE $table";
	    
	    $self->_do_sql($sql);
	}
    }
}
 
#----------------------------------------------------------------
# doDropViews()
#
#----------------------------------------------------------------
sub do_dropviews {

    my ($self, $list, $commit_order, $database) = @_;

    foreach my $view (reverse @{$commit_order}){

	## We want to drop all views listed in the dynamically 
	## generated sysobjects list. For the views which
	## correspond to the known list of chado views, we must
	## ensure that these views are dropped in the correct order.
	## Views which do not belong to the list of known chado
	## tables will be dealt with further downstream.

	if ((exists $list->{$view}) && (defined($list->{$view}))){

	    ## Incremented value will be used later to verify whether
	    ## all of the views in the dynamically generated sysobjects
	    ## list were dropped.
	    $list->{$view}++;

	    my $sql = "DROP VIEW $view";
	   
	    $self->_do_sql($sql);
	    
	}
	else {
	    
	    ## This particular view was not one of the known
	    ## chado views. It will be dropped later downstream...
	    $self->{_logger}->error("View '$view' was part of COMMIT_ORDER ".
				    "list, however did not find this view ".
				    "in database '$database'");
	}
    }

    ## Verify whether all of the views in the dynamically generated 
    ## sysobjects list were processed.
    foreach my $view (sort keys %{$list}) {

	if ($list->{$view} <= 1 ){
	    ## All other non-chado views are dropped here.
	    $self->{_logger}->warn("View '$view' was not previously ".
				   "processed, dropping it now...");
	    
	    my $sql = "DROP VIEW $view";
	    
	    $self->_do_sql($sql);
	}
    }
}

##---------------------------------------------------------------------------
## Abstract methods (pure virtual functions that must
## be implemented in the derived classes
##
##---------------------------------------------------------------------------

sub doDropForeignKeyConstraints {
    my ($self) = @_;
    my $class = ref($self);
    if ($class eq 'ChadoPrismDB'){
	$self->{_logger}->logdie("Cannot use abstract method ${class}::doDropForeignKeyConstraints");
    }
}

sub getSystemObjectsListByType {
    my ($self) = @_;
    my $class = ref($self);
    if ($class eq 'ChadoPrismDB'){
	$self->{_logger}->logdie("Cannot use abstract method ${class}::getSystemObjectsListByType");
    }
}

sub doesTableExist {
    my ($self) = @_;
    my $class = ref($self);
    if ($class eq 'ChadoPrismDB'){
	$self->{_logger}->logdie("Cannot use abstract method ${class}::doesTableExist");
    }
}

sub doesTableHaveSpace {
    my ($self) = @_;
    my $class = ref($self);
    if ($class eq 'ChadoPrismDB'){
	$self->{_logger}->logdie("Cannot use abstract method ${class}::doesTableHaveSpace");
    }
}

sub doUpdateStatistics {
    my ($self) = @_;
    my $class = ref($self);
    if ($class eq 'ChadoPrismDB'){
	$self->{_logger}->logdie("Cannot use abstract method ${class}::doUpdateStatistics");
    }
}

sub getTableList {
    my ($self) = @_;
    my $class = ref($self);
    if ($class eq 'ChadoPrismDB'){
	$self->{_logger}->logdie("Cannot use abstract method ${class}::getTableList");
    }
}


##---------------------------------------------------------------
## getSubFeatureIdentfierMappings()
##
##---------------------------------------------------------------
sub getSubFeatureIdentifierMappings {

    my ($self, $prefix, $asmbl_id) = @_;

    if (!defined($prefix)){
	$self->{_logger}->logdie("prefix was not defined");
    }
    
    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    my $query = "SELECT lower(substring(db.name,6,30)) + '_' + da.accession + '_' + d.accession + '_' +  cf.name, f.uniquename ".
    "FROM cvterm cf, dbxref da, featureloc fl, cvterm c, feature a, feature f, dbxref d, db , organism_dbxref od, dbxref d2 ".
    "WHERE cf.cvterm_id = f.type_id ".
    "AND c.name = 'assembly' ".
    "AND c.cvterm_id =  a.type_id ".
    "AND a.organism_id = od.organism_id ".
    "AND od.dbxref_id = d2.dbxref_id ".
    "AND d2.db_id = db.db_id ".
    "AND d2.version = 'legacy_annotation_database' ".
    "AND a.feature_id = fl.srcfeature_id ".
    "AND fl.feature_id = f.feature_id ".
    "AND f.dbxref_id = d.dbxref_id ".
    "AND a.dbxref_id = da.dbxref_id ".
    "AND db.name = ? ".
    "AND da.accession = ? ";

    return $self->_get_results_ref($query, $prefix, $asmbl_id);

}

##---------------------------------------------------------------
## getSubSubFeatureIdentfierMappings()
##
##---------------------------------------------------------------
sub getSubSubFeatureIdentifierMappings {

    my ($self, $prefix, $asmbl_id) = @_;

    if (!defined($prefix)){
	$self->{_logger}->logdie("prefix was not defined");
    }
    
    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    my $query = "SELECT lower(substring(db.name,6,30)) + '_' + da.accession + '_' + d.accession + '_' +  cf.name, sf.uniquename ".
    "FROM cvterm cf, dbxref da, featureloc fl, cvterm c, feature a, feature f, dbxref d, db , organism_dbxref od, dbxref d2, feature sf, cvterm poly, featureloc fl2 ".
    "WHERE cf.cvterm_id = sf.type_id ".
    "AND c.name = 'assembly' ".
    "AND poly.name = 'polypeptide' ".
    "AND c.cvterm_id =  a.type_id ".
    "AND a.organism_id = od.organism_id ".
    "AND od.dbxref_id = d2.dbxref_id ".
    "AND d2.db_id = db.db_id ".
    "AND d2.version = 'legacy_annotation_database' ".
    "AND a.feature_id = fl.srcfeature_id ".
    "AND fl.feature_id = f.feature_id ".
    "AND sf.dbxref_id = d.dbxref_id ".
    "AND a.dbxref_id = da.dbxref_id ".
    "AND db.name = ? ".
    "AND da.accession = ? ".
    "AND poly.cvterm_id = f.type_id ".
    "AND f.feature_id = fl2.srcfeature_id ".
    "AND fl2.feature_id = sf.feature_id ";

    return $self->_get_results_ref($query, $prefix, $asmbl_id);

}

##---------------------------------------------------------------
## getContigIdentfierMappings()
##
##---------------------------------------------------------------
sub getContigIdentifierMappings {

    my ($self, $prefix, $asmbl_id) = @_;

    if (!defined($prefix)){
	$self->{_logger}->logdie("prefix was not defined");
    }

    if (!defined($asmbl_id)){
	$self->{_logger}->logdie("asmbl_id was not defined");
    }

    my $query = "SELECT lower(substring(db.name,6,30)) + '_' + da.accession + '_' +  c.name, a.uniquename ".
    "FROM dbxref da, cvterm c, feature a, db , organism_dbxref od, dbxref d2 ".
    "WHERE c.name = 'assembly' ".
    "AND c.cvterm_id =  a.type_id ".
    "AND a.organism_id = od.organism_id ".
    "AND od.dbxref_id = d2.dbxref_id ".
    "AND d2.db_id = db.db_id ".
    "AND d2.version = 'legacy_annotation_database' ".
    "AND a.dbxref_id = da.dbxref_id ".
    "AND db.name = ? ".
    "AND da.accession = ? ";

    return $self->_get_results_ref($query, $prefix, $asmbl_id);
}

##---------------------------------------------------------------
## getDetailedProteinRecordsForCmProtein()
##
## This method prepares a query required for retrieving
## data from chado tables.  This data will be processed
## and the results will typically be stored in the 
## chado-mart view called cm_proteins.
##
##---------------------------------------------------------------
sub getDetailedProteinRecordsForCmProtein {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $retPolypeptideCvtermId = $self->get_cvterm_id_from_so('polypeptide');
    my $polypeptideCvtermId = $retPolypeptideCvtermId->[0][0];
    if (!defined($polypeptideCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'polypeptide'");
    }

    my $retGeneCvtermId = $self->get_cvterm_id_from_so('gene');
    my $geneCvtermId = $retGeneCvtermId->[0][0];
    if (!defined($geneCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'gene'");
    }

    my $geneProductNameCvtermId = $self->getCvtermIdByTermNameByOntology('gene_product_name',
									 'annotation_attributes.ontology');
    if (!defined($geneProductNameCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'gene_product_name'");
    }

    my $retCds = $self->get_cvterm_id_from_so('CDS');
    my $cdsCvtermId = $retCds->[0][0];
    if (!defined($cdsCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'CDS'");
    }

    my $retTranscript = $self->get_cvterm_id_from_so('transcript');
    my $transcriptCvtermId = $retTranscript->[0][0];
    if (!defined($transcriptCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'transcript'");
    }

    ## Only attempt to retrieve the polypeptide record that is localized to some assembly.
    ## We assume that each polypeptide is only localized to one assembly.
    my $retAssembly = $self->get_cvterm_id_from_so('assembly');
    my $assemblyCvtermId = $retAssembly->[0][0];
    if (!defined($assemblyCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'assembly'");
    }

#    my $query = "SELECT protein.feature_id, protein.uniquename, cds.feature_id, gene.feature_id, transcript.feature_id, fp.value, fl.fmin, fl.fmax, protein.seqlen, fl.strand, fl.srcfeature_id, protein.organism_id ".
#    "FROM feature protein, feature cds, feature gene, feature transcript, featureloc fl, feature_relationship frel1, feature_relationship frel2, feature_relationship frel3, featureprop fp, feature assembly ".
#    "WHERE fp.type_id = ? ".
#    "AND fp.feature_id = transcript.feature_id ".
#    "AND protein.feature_id = fl.feature_id ".
#    "AND fl.srcfeature_id = assembly.feature_id ".
#    "AND assembly.type_id = ? ".
#    "AND protein.feature_id = frel1.subject_id ".
#    "AND frel1.object_id = cds.feature_id ".
#    "AND cds.feature_id = frel2.subject_id ".
#    "AND frel2.object_id = transcript.feature_id ".
#    "AND transcript.feature_id = frel3.subject_id ".
#    "AND frel3.object_id = gene.feature_id ".
#    "AND protein.type_id = ? ".
#    "AND gene.type_id = ? ".
#    "AND transcript.type_id =  ? ".
#    "AND cds.type_id = ? ";

# New query that will pull records even if they do not have a gene_product_name
my $query = "SELECT protein.feature_id, protein.uniquename, cds.feature_id, gene.feature_id, transcript.feature_id, fp.value, fl.fmin, fl.fmax, protein.seqlen, fl.strand, fl.srcfeature_id, protein.organism_id ".
    "FROM feature protein ".
    "JOIN feature_relationship frel1 ON ( protein.feature_id = frel1.subject_id ) ".
    "JOIN feature cds ON (frel1.object_id = cds.feature_id) ".
    "JOIN feature_relationship frel2 ON (cds.feature_id = frel2.subject_id) ".
    "JOIN feature transcript ON  (frel2.object_id = transcript.feature_id) ".
    "JOIN feature_relationship frel3 ON ( transcript.feature_id = frel3.subject_id ) ".
    "JOIN feature gene ON (frel3.object_id = gene.feature_id) ".
    "JOIN featureloc fl ON ( protein.feature_id = fl.feature_id) ".
    "JOIN feature assembly ON (fl.srcfeature_id = assembly.feature_id) ".
    "LEFT JOIN featureprop fp ON (fp.feature_id = transcript.feature_id AND  fp.type_id = ?) ".
    "WHERE assembly.type_id = ? ".
    "AND protein.type_id =? ".
    "AND gene.type_id = ? ".
    "AND transcript.type_id = ? ".
    "AND cds.type_id = ?";

    return $self->_get_results_ref($query, $geneProductNameCvtermId, $assemblyCvtermId, $polypeptideCvtermId, 
				   $geneCvtermId, $transcriptCvtermId, $cdsCvtermId);
}

##---------------------------------------------------------------
## getDbxrefRecordsForCmProteins()
##
##---------------------------------------------------------------
sub getDbxrefRecordsForCmProteins {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $retPolypeptideCvtermId = $self->get_cvterm_id_from_so('polypeptide');
    my $polypeptideCvtermId = $retPolypeptideCvtermId->[0][0];
    if (!defined($polypeptideCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'polypeptide'");
    }
    my $retTranscriptCvtermId = $self->get_cvterm_id_from_so('transcript');
    my $transcriptCvtermId = $retTranscriptCvtermId->[0][0];
    if (!defined($transcriptCvtermId)){
        $self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'transcript'");
    }

    ## We do not guarantee which version of dbxref will be retrieved e.g.: 
    ## current, locus, display_locus, feat_name.

    # Pulling the the dbxrefs off of the transcript feature
    my $query = "SELECT distinct protein.feature_id, d.version, db.name + ':' + d.accession ".
    "FROM feature protein, feature transcript, feature_relationship fr, dbxref d, db db, feature_dbxref fd ".
    "WHERE protein.type_id = ? ".
    "AND transcript.type_id = ? ".
    "AND protein.feature_id=fr.subject_id ".
    "AND transcript.feature_id=fr.object_id ".
    "AND transcript.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = d.dbxref_id ".
    "AND d.db_id = db.db_id ".
    "AND protein.is_analysis = 0 ".
    "AND protein.is_obsolete = 0 ";
    
    return $self->_get_results_ref($query, $polypeptideCvtermId, $transcriptCvtermId);
}

##---------------------------------------------------------------
## getTranscriptFeatureIdToExonCounts()
##
## This will get the feature_id for the transcripts and
## the number of exon features for which there are
## feature_relationship records relating the exon to the 
## transcript.
##
##---------------------------------------------------------------
sub getTranscriptFeatureIdToExonCounts {

    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $retExon = $self->get_cvterm_id_from_so('exon');
    my $exonCvtermId = $retExon->[0][0];
    if (!defined($exonCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'exon'");
    }

    my $retTranscript = $self->get_cvterm_id_from_so('transcript');
    my $transcriptCvtermId = $retTranscript->[0][0];
    if (!defined($transcriptCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'transcript'");
    }

    my $query = "SELECT transcript.feature_id, count(frel.subject_id) ".
    "FROM feature transcript, feature exon, feature_relationship frel ".
    "WHERE transcript.type_id = ? ".
    "AND exon.type_id = ? ".
    "AND transcript.feature_id = frel.object_id ".
    "AND frel.subject_id = exon.feature_id ".
    "GROUP BY transcript.feature_id ";
    
    return $self->_get_results_ref($query, $transcriptCvtermId, $exonCvtermId);
}

##---------------------------------------------------------------
## getClusterIdAndMemberCountsByAnalysisId()
##
## This method prepares a query required for retrieving
## data from chado tables.  This data will be processed
## and the results will typically be stored in the 
## chado-mart view called cm_clusters.
##
##---------------------------------------------------------------
sub getClusterIdAndMemberCountsByAnalysisId {

    my ($self, $analysis_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }

    my $computedByCvtermId = $self->getCvtermIdByTermNameByOntology('computed_by',
								    'relationship');
    if (!defined($computedByCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by'");
    }

    my $query = "SELECT m.feature_id, count(fl.feature_id), count(distinct(f.organism_id)) ".
    "FROM featureloc fl, feature m, analysisfeature af, analysis a, feature f ".
    "WHERE a.analysis_id = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = ? ".
    "AND af.feature_id = m.feature_id ".
    "AND m.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = f.feature_id ".
    "AND f.is_analysis = 0 ".  ## see comment below
    "GROUP BY m.feature_id ".
    "ORDER BY m.feature_id ";

    ## comment: This is not the best way to ensure that the feature to which the cluster match
    ##          record is localized to is not a match or match_part.
    ##          More accurate method would be for feature to join on analysisfeature af2 where
    ##          the af2.type_id = 'input_of' (OR equally, af2.type_id != 'computed_by'

    return $self->_get_results_ref($query, $analysis_id, $computedByCvtermId);
}

##---------------------------------------------------------------
## getCrossReferencesForClusterMembersByAnalysisId()
##
##
##---------------------------------------------------------------
sub getCrossReferencesForClusterMembersByAnalysisId {

    my ($self, $analysis_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $computedByCvtermId = $self->getCvtermIdByTermNameByOntology('computed_by',
								    'relationship');

    my $retPolypeptideCvtermId = $self->get_cvterm_id_from_so('polypeptide');
    my $polypeptideCvtermId = $retPolypeptideCvtermId->[0][0];
    if (!defined($polypeptideCvtermId)){
        $self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'polypeptide'");
    }
    my $retTranscriptCvtermId = $self->get_cvterm_id_from_so('transcript');
    my $transcriptCvtermId = $retTranscriptCvtermId->[0][0];
    if (!defined($transcriptCvtermId)){
        $self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'transcript'");
    }

    # Pulling the the dbxrefs off of the transcript feature
    my $query = "SELECT DISTINCT p.feature_id, db.name + ':' + d.accession ".
    "FROM feature_dbxref fd, dbxref d, db db, feature p, feature t, feature_relationship fr, featureloc fl, feature m, analysisfeature af, analysis a ".
    "WHERE a.analysis_id = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = ? ".
    "AND af.feature_id = m.feature_id ".
    "AND m.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = p.feature_id ".
    "AND t.feature_id=fr.object_id ".
    "AND p.feature_id=fr.subject_id ".
    "AND fd.dbxref_id = d.dbxref_id  ".
    "AND d.db_id = db.db_id  ".
    "AND t.feature_id = fd.feature_id ".
    "AND p.is_analysis = 0 ".
    "AND p.type_id=? ".
    "AND t.type_id=? ";

    my $trans_results = $self->_get_results_ref($query, $analysis_id, $computedByCvtermId,$polypeptideCvtermId,$transcriptCvtermId);

    # Pulling the the dbxrefs off of the gene feature
    my $query = "SELECT p.feature_id, db.name + ':' + d.accession ".
    "FROM feature_dbxref fd, dbxref d, db db, feature p, feature t, feature g, feature_relationship fr, feature_relationship fr2, featureloc fl, feature m, analysisfeature af, analysis a ".
    "WHERE a.analysis_id = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = ? ".
    "AND af.feature_id = m.feature_id ".
    "AND m.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = p.feature_id ".
    "AND t.feature_id=fr.object_id ".
    "AND p.feature_id=fr.subject_id ".
    "AND t.feature_id=fr2.subject_id ".
    "AND g.feature_id=fr2.object_id ".
    "AND fd.dbxref_id = d.dbxref_id  ".
    "AND d.db_id = db.db_id  ".
    "AND g.feature_id = fd.feature_id ".
    "AND p.is_analysis = 0 ".
    "AND p.type_id=? ".
    "AND t.type_id=? ";

    my $gene_results = $self->_get_results_ref($query, $analysis_id, $computedByCvtermId,$polypeptideCvtermId,$transcriptCvtermId);

    my @all_results = (@$trans_results,@$gene_results);

    return \@all_results;
}

##---------------------------------------------------------------
## getClusterMembersByAnalysisId()
##
## This method prepares a query required for retrieving
## data from chado tables.  This data will be processed
## and the results will typically be stored in the 
## chado-mart view called cm_cluster_members.
##
##---------------------------------------------------------------
sub getClusterMembersByAnalysisId {

    my ($self, $analysis_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }

    my $computedByCvtermId = $self->getCvtermIdByTermNameByOntology('computed_by',
								    'relationship');
    if (!defined($computedByCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by'");
    }

    my $query = "SELECT m.feature_id, f.feature_id, f.organism_id, f.uniquename ".
    "FROM feature f, featureloc fl, feature m, analysisfeature af, analysis a ".
    "WHERE a.analysis_id = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = ? ".
    "AND af.feature_id = m.feature_id ".
    "AND m.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = f.feature_id ".
    "ORDER BY m.feature_id ";

    return $self->_get_results_ref($query, $analysis_id, $computedByCvtermId);
}

##---------------------------------------------------------------
## getCvtermIdByTermNameByOntology()
##
##---------------------------------------------------------------
sub getCvtermIdByTermNameByOntology {

    my($self, $name, $ontology) = @_;

    if (!defined($name)){
	$self->{_logger}->logdie("name was not defined");
    }
    if (!defined($ontology)){
	$self->{_logger}->logdie("ontology was not defined");
    }

    my $query = "SELECT c.cvterm_id ".
    "FROM cvterm c, cv ".
    "WHERE cv.cv_id = c.cv_id ".
    "AND cv.name = ? ".
    "AND c.name = ? ";
    
    my $ret = $self->_get_results_ref($query, $ontology, $name);

    return $ret->[0][0];
}

##---------------------------------------------------------------
## getCvtermIdListByCvId()
##
##---------------------------------------------------------------
sub getCvtermIdListByCvId {

    my($self, $cv_id) = @_;

    if (!defined($cv_id)){
	$self->{_logger}->logdie("cv_id was not defined");
    }

    my $query = "SELECT cvterm_id ".
    "FROM cvterm  ".
    "WHERE cv_id = ? ";
    
    return $self->_get_results_ref($query, $cv_id);
}

##---------------------------------------------------------------
## getCvterRelationshipForClosure()
##
##---------------------------------------------------------------
sub getCvtermRelationshipForClosure {

    my($self, $cv_id) = @_;

    if (!defined($cv_id)){
	$self->{_logger}->logdie("cv_id was not defined");
    }

    my $query = "SELECT cr.subject_id, cr.object_id, cr.type_id ".
    "FROM cvterm_relationship cr, cvterm c ".
    "WHERE c.cv_id = ? ".
    "AND c.cvterm_id = cr.subject_id ";
    
    return $self->_get_results_ref($query, $cv_id);
}

##---------------------------------------------------------------
## getCvtermPathIdCachedLookup()
##
##---------------------------------------------------------------
sub getCvtermPathIdCachedLookup {

    my($self) = @_;

    print "Building cvtermpath_id cached lookup\n";

    my $query = "SELECT convert(VARCHAR, type_id) + '_' + convert(VARCHAR, subject_id) + '_' + convert(VARCHAR, object_id) + '_' + convert(VARCHAR,cv_id) + '_' + convert(VARCHAR,pathdistance), cvtermpath_id ".
    "FROM cvtermpath ";
    
    return $self->_get_lookup_db($query);
}

##---------------------------------------------------------------
## getGOIDToCvtermIdLookup()
##
##---------------------------------------------------------------
sub getGOIDToCvtermIdLookup {

    my($self) = @_;

    my $query = "SELECT d.accession, c.cvterm_id  ".
	"FROM dbxref d ".
	"  INNER JOIN (cvterm c INNER JOIN cv ON c.cv_id = cv.cv_id) ON d.dbxref_id = c.dbxref_id ".
	"WHERE cv.name = 'biological_process' ".
	"OR cv.name = 'molecular_component' ".
	"OR cv.name = 'cellular_function' ".
	"OR cv.name = 'GO' ";

    print "Retrieving all GO cvterm records\n";

    return $self->_get_lookup_db($query);
}

##---------------------------------------------------------------
## getAssemblyUniquenameList()
##
##---------------------------------------------------------------
sub getAssemblyUniquenameList {

    my($self) = @_;

    my $assemblyCvtermId = $self->getCvtermIdByTermNameByOntology('assembly',
								  'SO');
    if (!defined($assemblyCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'assembly' ".
				 "with cv.name = 'SO'");
    }
    
    my $query = "SELECT f.uniquename ".
    "FROM feature f ".
    "WHERE f.type_id = ? ";

    print "Retrieving data all assembly uniquename values\n";

    return $self->_get_results_ref($query, $assemblyCvtermId);
}

##---------------------------------------------------------------
## getSequenceDataByFeatureUniquename()
##
##---------------------------------------------------------------
sub getSequenceDataByFeatureUniquename {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }

    my $moleculeNameCvtermId = $self->getCvtermIdByTermNameByOntology('molecule_name',
								      'annotation_attributes.ontology');
    if (!defined($moleculeNameCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'molecule_name' ".
				 "with cv.name = 'annotation_attributes.ontology'");
    }

    my $moleculeTypeCvtermId = $self->getCvtermIdByTermNameByOntology('molecule_type',
								      'GFF3');
    if (!defined($moleculeTypeCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'molecule_type' ".
				 "with cv.name = 'GFF3'");
    }

    my $primaryAnnotationCvtermId = $self->getCvtermIdByTermNameByOntology('Primary_annotation',
									   'ANNFLG');
    if (!defined($primaryAnnotationCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'Primary_annotation' ".
				 "with cv.name = 'ANNFLG'");
    }

    my $tigrAnnotationCvtermId = $self->getCvtermIdByTermNameByOntology('TIGR_annotation',
									'ANNFLG');
    if (!defined($tigrAnnotationCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'TIGR_annotation' ".
				 "with cv.name = 'ANNFLG'");
    }
    
    my $topologyCvtermId = $self->getCvtermIdByTermNameByOntology('topology','GFF3');
    if (!defined($topologyCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'topology' ".
				 "with cv.name = 'GFF3'");
    }


    print "Retrieving data for sequence with uniquename '$uniquename'\n";
    
    my $query = "SELECT f.seqlen, f.residues, fp1.value, fp2.value, fc1.feature_cvterm_id, fc2.feature_cvterm_id, '', fp3.value ".
    "FROM feature f ".
    "  LEFT JOIN featureprop fp1 ON f.feature_id = fp1.feature_id AND fp1.type_id = ? ".
    "  LEFT JOIN featureprop fp2 ON f.feature_id = fp2.feature_id AND fp2.type_id = ? ".
    "  LEFT JOIN feature_cvterm fc1 ON f.feature_id = fc1.feature_id AND fc1.cvterm_id = ? ".
    "  LEFT JOIN feature_cvterm fc2 ON f.feature_id = fc2.feature_id AND fc2.cvterm_id = ? ".
    "  LEFT JOIN featureprop fp3 ON f.feature_id = fp3.feature_id AND fp3.type_id = ? ".
    "WHERE f.uniquename = ? ";

    return $self->_get_results_ref($query, $moleculeNameCvtermId, $moleculeTypeCvtermId, $primaryAnnotationCvtermId,
				   $tigrAnnotationCvtermId, $topologyCvtermId, $uniquename);
}

##---------------------------------------------------------------
## getSequenceSubfeatureCount()
##
##---------------------------------------------------------------
sub getSequenceSubfeatureCount {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }
    
    print "Retrieving the number of subfeatures that are localized to the sequence with uniquename '$uniquename'\n";
    
    my $query = "SELECT COUNT(fl.srcfeature_id) ".
    "FROM featureloc fl ".
    "  INNER JOIN feature f ON fl.srcfeature_id = f.feature_id ".
    "WHERE f.uniquename = ? ";

    return $self->_get_results_ref($query, $uniquename);
}

##---------------------------------------------------------------
## getSequencePolypeptideCount()
##
##---------------------------------------------------------------
sub getSequencePolypeptideCount {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }
    
    my $polypeptideCvtermId = $self->getCvtermIdByTermNameByOntology('polypeptide','SO');
    if (!defined($polypeptideCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'polypeptide' with ".
				 "cv.name = 'SO'");
    }

    my $query = "SELECT COUNT(fl.srcfeature_id) ".
    "FROM feature a, featureloc fl, feature f ".
    "WHERE a.uniquename = ? ".
    "AND a.feature_id = fl.srcfeature_id ".
    "AND fl.feature_id = f.feature_id ".
    "AND f.type_id = ? ";

    print "Retrieving the number of polypeptide features that are localized to the sequence with uniquename '$uniquename'\n";

    return $self->_get_results_ref($query, $uniquename, $polypeptideCvtermId);
}

##---------------------------------------------------------------
## getOrganismDataByFeatureUniquename()
##
##---------------------------------------------------------------
sub getOrganismDataByFeatureUniquename {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }

    my $geneticCodeCvtermId = $self->getCvtermIdByTermNameByOntology('genetic_code',
								    'annotation_attributes.ontology');
    if (!defined($geneticCodeCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'genetic_code' ".
				 "with cv.name = 'annotation_attributes.ontology'");
    }

    my $mtGeneticCodeCvtermId = $self->getCvtermIdByTermNameByOntology('mt_genetic_code',
								    'annotation_attributes.ontology');
    if (!defined($mtGeneticCodeCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'mt_genetic_code' ".
				 "with cv.name = 'annotation_attributes.ontology'");
    }

    my $gramStainCvtermId = $self->getCvtermIdByTermNameByOntology('gram_stain',
								    'annotation_attributes.ontology');
    if (!defined($gramStainCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'gram_stain' with ".
				 "cv.name = 'annotation_attributes.ontology'");
    }

    my $strainCvtermId = $self->getCvtermIdByTermNameByOntology('strain',
								'GFF3');
    if (!defined($strainCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'strain' with ".
				 "cv.name = 'GFF3'");
    }

    my $translationTableCvtermId = $self->getCvtermIdByTermNameByOntology('translation_table', 'GFF3');
    if (!defined($translationTableCvtermId)){
      $self->{_logger}->logdie("cvterm_id was not defined for ".
			       "cvterm.name = 'translation_table' ".
			       "with cv.name = 'GFF3'");
    }

    my $query = "SELECT DISTINCT o.genus, o.species, op4.value, o.abbreviation, op1.value, op2.value, op3.value, o.comment, op5.value ".
    "FROM organism o ".
    "  INNER JOIN feature f on o.organism_id = f.organism_id ".
    "    LEFT JOIN organismprop op1 ON o.organism_id = op1.organism_id AND op1.type_id = ? ".
    "    LEFT JOIN organismprop op2 ON o.organism_id = op2.organism_id AND op2.type_id = ? ".
    "    LEFT JOIN organismprop op3 ON o.organism_id = op3.organism_id AND op3.type_id = ? ".
    "    LEFT JOIN organismprop op4 ON o.organism_id = op4.organism_id AND op4.type_id = ? ".
    "    LEFT JOIN organismprop op5 ON o.organism_id = op5.organism_id AND op5.type_id = ? ".
    "WHERE f.uniquename = ? ";

    print "Retrieving data for organism with uniquename '$uniquename'\n";
    
    return $self->_get_results_ref($query,
				   $geneticCodeCvtermId,
				   $mtGeneticCodeCvtermId,
				   $gramStainCvtermId,
				   $strainCvtermId,
				   $translationTableCvtermId,
				   $uniquename);
}

##---------------------------------------------------------------
## getCrossReferenceDataByFeatureUniquename()
##
##---------------------------------------------------------------
sub getCrossReferenceDataByFeatureUniquename {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }
    
    my $query = "SELECT db.name, d.accession, d.version ".
    "FROM dbxref d ".
    "INNER JOIN db ON d.db_id = db.db_id ".
    "INNER JOIN (feature_dbxref fd INNER JOIN feature f ON fd.feature_id = f.feature_id AND f.uniquename = ? ) ON d.dbxref_id = fd.dbxref_id ";
    
    print "Retrieving cross-reference data for sequence with uniquename '$uniquename'\n";

    return $self->_get_results_ref($query, $uniquename);
}

##---------------------------------------------------------------
## getOrganismCrossReferenceDataByFeatureUniquename()
##
##---------------------------------------------------------------
sub getOrganismCrossReferenceDataByFeatureUniquename {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }
    
    my $sourceDatabaseCvtermId = $self->getCvtermIdByTermNameByOntology('source_database',
								    'component.ontology');
    if (!defined($sourceDatabaseCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'source_database' with ".
				 "cv.name = 'component.ontology'");
    }

    my $schemaTypeCvtermId = $self->getCvtermIdByTermNameByOntology('schema_type',
								    'ARD');
    if (!defined($schemaTypeCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'schema_type' with ".
				 "cv.name = 'ARD'");
    }

    my $query ="SELECT DISTINCT db.name, d.accession, d.version, dp1.value, dp2.value ".
    "FROM dbxref d ".
    "INNER JOIN (organism_dbxref od inner join ( organism o INNER JOIN feature f ON o.organism_id = f.organism_id AND f.uniquename = ? ) ON od.organism_id = o.organism_id ) ON d.dbxref_id = od.dbxref_id ".
    "INNER JOIN db ON d.db_id = db.db_id ".
    "LEFT JOIN dbxrefprop dp1 ON d.dbxref_id = dp1.dbxref_id AND dp1.type_id = ? ".
    "LEFT JOIN dbxrefprop dp2 ON d.dbxref_id = dp2.dbxref_id AND dp2.type_id = ? ";
    
    print "Retrieving cross-reference data for organism with uniquename '$uniquename'\n";

    return $self->_get_results_ref($query, $uniquename, $sourceDatabaseCvtermId, $schemaTypeCvtermId);
}

##---------------------------------------------------------------
## getSubfeatureDataByAssemblyFeatureUniquename()
##
##---------------------------------------------------------------
sub getSubfeatureDataByAssemblyFeatureUniquename {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }
    
    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match',
							       'SO');
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match' with ".
				 "cv.name = 'SO'");
    }
    my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part',
								   'SO');
    if (!defined($matchPartCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part' with ".
				 "cv.name = 'SO'");
    }

    my $query = qq( SELECT f.uniquename, f.seqlen, f.residues, c.name, fl.fmin, fl.fmax, fl.strand, fl.is_fmin_partial, fl.is_fmax_partial
                    FROM feature f
                    INNER JOIN cvterm c ON f.type_id = c.cvterm_id
                    INNER JOIN (featureloc fl INNER JOIN feature p ON fl.srcfeature_id = p.feature_id AND p.uniquename = ? ) ON f.feature_id = fl.feature_id
                    WHERE f.is_obsolete = FALSE
                      AND NOT EXISTS ( 
                                      SELECT 1
                                      FROM cvterm c2
                                      WHERE f.type_id = c2.cvterm_id
                                      AND (c2.name = ? OR c2.name = ? ) )
                  );
    
    print "Retrieving all subfeatures that are localized to the sequence with uniquename '$uniquename'\n";

    return $self->_get_results_ref($query, $uniquename, $matchCvtermId, $matchPartCvtermId);
}

##---------------------------------------------------------------
## getPolypeptideDataByAssemblyFeatureUniquename()
##
##---------------------------------------------------------------
sub getPolypeptideDataByAssemblyFeatureUniquename {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }
    
    my $polypeptideCvtermId = $self->getCvtermIdByTermNameByOntology('polypeptide','SO');
    if (!defined($polypeptideCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'polypeptide' with ".
				 "cv.name = 'SO'");
    }

    my $query = "SELECT f.uniquename, f.seqlen, f.residues, 'polypeptide', fl.fmin, fl.fmax, fl.strand ".
    "FROM feature p, featureloc fl, feature f ".
    "WHERE p.uniquename = ? ".
    "AND p.feature_id = fl.srcfeature_id ".
    "AND fl.feature_id = f.feature_id ".
    "AND f.type_id = ? ".
    "AND f.is_obsolete = 0 ";

    print "Retrieving all polypeptide subfeatures that are localized to the sequence with uniquename '$uniquename'\n";

    return $self->_get_results_ref($query, $uniquename, $polypeptideCvtermId);
}

##---------------------------------------------------------------
## getAllSubfeaturePropertiseDataByAssemblyFeatureUniquename()
##
##---------------------------------------------------------------
sub getAllSubfeaturePropertiesDataByAssemblyFeatureUniquename {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }
    
    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match',
							       'SO');
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match' with ".
				 "cv.name = 'SO'");
    }
    my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part',
								   'SO');
    if (!defined($matchPartCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part' with ".
				 "cv.name = 'SO'");
    }

    my $query = qq( 
     SELECT f.uniquename, c.name, fp.value 
     FROM feature f 
       INNER JOIN (featureprop fp INNER JOIN cvterm c ON fp.type_id = c.cvterm_id) ON f.feature_id = fp.feature_id 
       INNER JOIN (featureloc fl INNER JOIN feature p ON fl.srcfeature_id = p.feature_id AND p.uniquename = ? ) ON f.feature_id = fl.feature_id 
     WHERE f.is_obsolete = FALSE
     AND NOT EXISTS ( 
     SELECT 1 
     FROM cvterm c2 
     WHERE f.type_id = c2.cvterm_id 
     AND (c2.name = ? OR c2.name = ? ) )
   );
    
    print "Retrieving properties for all subfeatures that are localized to the sequence with uniquename '$uniquename'\n";

    return $self->_get_results_ref($query, $uniquename, $matchCvtermId, $matchPartCvtermId);
}

##---------------------------------------------------------------
## getAllSubfeatureCrossReferenceDataByAssemblyFeatureUniquename()
##
##---------------------------------------------------------------
sub getAllSubfeatureCrossReferenceDataByAssemblyFeatureUniquename {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }
    
    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match',
							       'SO');
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match' with ".
				 "cv.name = 'SO'");
    }
    my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part',
								   'SO');
    if (!defined($matchPartCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part' with ".
				 "cv.name = 'SO'");
    }

    my $query = qq( SELECT f.uniquename, db.name, d.accession, d.version 
                    FROM feature f 
                    INNER JOIN (feature_dbxref fd INNER JOIN (dbxref d INNER JOIN db ON d.db_id = db.db_id ) ON fd.dbxref_id = d.dbxref_id ) ON fd.feature_id = f.feature_id 
                    INNER JOIN (featureloc fl INNER JOIN feature p ON fl.srcfeature_id = p.feature_id AND p.uniquename = ? ) ON f.feature_id = fl.feature_id 
                    WHERE f.is_obsolete = FALSE 
                      AND NOT EXISTS ( 
                                      SELECT 1 
                                      FROM cvterm c2 
                                      WHERE f.type_id = c2.cvterm_id 
                                      AND (c2.name = ? OR c2.name = ? ) ) 
                  );

    
    print "Retrieving cross-reference for all subfeatures that are localized to the sequence with uniquename '$uniquename'\n";

    return $self->_get_results_ref($query, $uniquename, $matchCvtermId, $matchPartCvtermId);
}

##---------------------------------------------------------------
## getAllGOAssignmentsForSubfeaturesByAssemblyFeatureUniquename()
##
##---------------------------------------------------------------
sub getAllGOAssignmentsForSubfeaturesByAssemblyFeatureUniquename {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }

    my $missingCtr=0;

    my $processCvId = $self->getCvIdByName('process');
    if (!defined($processCvId)){
	$self->{_logger}->warn("cv_id was not defined for cv.name 'process'");
	$missingCtr++;
    }

    my $functionCvId = $self->getCvIdByName('function');
    if (!defined($functionCvId)){
	$self->{_logger}->warn("cv_id was not defined for cv.name 'function'");
	$missingCtr++;
    }

    my $componentCvId = $self->getCvIdByName('component');
    if (!defined($componentCvId)){
	$self->{_logger}->warn("cv_id was not defined for cv.name 'component'");
	$missingCtr++;
    }

    if ($missingCtr > 0){
      if ($missingCtr == 3){
	$self->{_logger}->warn("The Gene Ontology was not split by ".
			       "namespace, therefore could not build ".
			       "lookup by subcategories");
	## return empty lookup
	return undef;
      } else {
	if ($missingCtr == 1){
	  $self->{_logger}->logdie("'$missingCtr' of the Gene Ontology ".
				   "subcategories was missing");
	} else {
	  $self->{_logger}->logdie("'$missingCtr' of the Gene Ontology ".
				   "subcategories were missing");
	}
      }
    }

    my $query = "SELECT f.uniquename, d.accession, fc.feature_cvterm_id ".
    "FROM feature f, cvterm c, dbxref d, featureloc fl, feature a, feature_cvterm fc ".
    "WHERE a.feature_id = fl.srcfeature_id ".
    "AND fl.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.cvterm_id = c.cvterm_id ".
    "AND c.dbxref_id = d.dbxref_id ".
    "AND a.uniquename = ? ".
    "AND (c.cv_id = ? ".
    "OR c.cv_id = ? ".
    "OR c.cv_id = ? )";

    print "Retrieving all GO assignments for all subfeatures that are localized to the sequence with uniquename '$uniquename'\n";

    return $self->_get_results_ref($query, $uniquename, $processCvId, $functionCvId, $componentCvId);
}

##---------------------------------------------------------------
## getAllGOAssignmentAttributesForSubfeaturesByAssemblyFeatureUniquename()
##
##---------------------------------------------------------------
sub getAllGOAssignmentAttributesForSubfeaturesByAssemblyFeatureUniquename {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }

    my $missingCtr=0;

    my $processCvId = $self->getCvIdByName('process');
    if (!defined($processCvId)){
	$self->{_logger}->warn("cv_id was not defined for cv.name 'process'");
	$missingCtr++;
    }
    
    my $functionCvId = $self->getCvIdByName('function');
    if (!defined($functionCvId)){
	$self->{_logger}->warn("cv_id was not defined for cv.name 'function'");
	$missingCtr++;
    }
    
    my $componentCvId = $self->getCvIdByName('component');
    if (!defined($componentCvId)){
	$self->{_logger}->warn("cv_id was not defined for cv.name 'component'");
	$missingCtr++;
    }

    if ($missingCtr > 0){
      if ($missingCtr == 3){
	$self->{_logger}->warn("The Gene Ontology was not split by ".
			       "namespace, therefore could not build ".
			       "lookup by subcategories");
	## return empty lookup
	return undef;
      } else {
	if ($missingCtr == 1){
	  $self->{_logger}->logdie("'$missingCtr' of the Gene Ontology ".
				   "subcategories was missing");
	} else {
	  $self->{_logger}->logdie("'$missingCtr' of the Gene Ontology ".
				   "subcategories were missing");
	}
      }
    }

    my $query = "SELECT fcp.feature_cvterm_id, c.name, fcp.value ".
    "FROM feature_cvtermprop fcp, cvterm c, cvterm c2, feature f, feature_cvterm fc, featureloc fl, feature a ".
    "WHERE a.feature_id = fl.srcfeature_id ".
    "AND fl.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.cvterm_id = c2.cvterm_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ".
    "AND fcp.type_id = c.cvterm_id ".
    "AND a.uniquename = ? ".
    "AND (c2.cv_id = ? ".
    "OR c2.cv_id = ? ".
    "OR c2.cv_id = ? )";

    print "Retrieving all properties for all GO assignments for all subfeatures that are localized to the sequence with uniquename '$uniquename'\n";

    return $self->_get_results_ref($query, $uniquename, $processCvId, $functionCvId, $componentCvId);
}

##---------------------------------------------------------------
## getEvidenceCodesLookup()
##
##---------------------------------------------------------------
sub getEvidenceCodesLookup {

    my($self) = @_;

    my $evidenceCodesCvId = $self->getCvIdByName('evidence_code');
    if (!defined($evidenceCodesCvId)){
	$self->{_logger}->logdie("cv_id was not defined for cv.name 'evidence_code'");
    }

    my $query = "SELECT c.name, cs.synonym ".
    "FROM cvterm c  ".
    "LEFT JOIN cvtermsynonym cs ON c.cvterm_id = cs.cvterm_id ".
    "WHERE c.cv_id = ? ";

    print "Retrieving evidence code synonyms\n";

    return $self->_get_results_ref($query, $evidenceCodesCvId);
}

##---------------------------------------------------------------
## getAllNonGOAssignmentsForSubfeaturesByAssemblyFeatureUniquename()
##
##---------------------------------------------------------------
sub getAllNonGOAssignmentsForSubfeaturesByAssemblyFeatureUniquename {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }

    my $missingCtr=0;

    my $processCvId = $self->getCvIdByName('process');
    if (!defined($processCvId)){
	$self->{_logger}->warn("cv_id was not defined for cv.name 'process'");
	$missingCtr++;
    }
    
    my $functionCvId = $self->getCvIdByName('function');
    if (!defined($functionCvId)){
	$self->{_logger}->warn("cv_id was not defined for cv.name 'function'");
	$missingCtr++;
    }
    
    my $componentCvId = $self->getCvIdByName('component');
    if (!defined($componentCvId)){
	$self->{_logger}->warn("cv_id was not defined for cv.name 'component'");
	$missingCtr++;
    }
    
    my $GOCvId = $self->getCvIdByName('GO');
    if (!defined($GOCvId)){
	$self->{_logger}->warn("cv_id was not defined for cv.name 'GO'");
	$missingCtr++;
    }

    print STDERR "Here with $missingCtr\n";
    if ($missingCtr > 0){
      if ($missingCtr == 4){
	$self->{_logger}->warn("The Gene Ontology was not split by ".
			       "namespace, therefore could not build ".
			       "lookup by subcategories");
	## return empty lookup
	return undef;
      } 
      else {
          if ($missingCtr == 1){
      #        $self->{_logger}->logdie("'$missingCtr' of the Gene Ontology ".
      #                                 "subcategories was missing");
          } else {
      #        $self->{_logger}->logdie("'$missingCtr' of the Gene Ontology ".
      #                                 "subcategories were missing");
          }
      }
    }

    my $query = "SELECT f.uniquename, cv.name, d.accession, fc.feature_cvterm_id ".
    "FROM feature f, cvterm c, cvterm_dbxref cd, dbxref d, featureloc fl, feature a, feature_cvterm fc, cv, db ".
    "WHERE a.feature_id = fl.srcfeature_id ".
    "AND fl.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.cvterm_id = c.cvterm_id ".
    "AND c.cvterm_id = cd.cvterm_id ".
    "AND cd.dbxref_id = d.dbxref_id ".
    "AND c.cv_id = cv.cv_id ".
    "AND d.db_id = db.db_id ".
    "AND db.name != 'TIGR_roles_order' ".
    "AND a.uniquename = ? ".
    "AND NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM cv cv2 ".
    "WHERE cv2.cv_id = c.cv_id ".
    "AND (c.cv_id = ? ".
    "OR c.cv_id = ? ".
    "OR c.cv_id = ? ".
    "OR c.cv_id = ?))";

    print "Retrieving all non-GO assignments for all subfeatures that are localized to the sequence with uniquename '$uniquename'\n";

    return $self->_get_results_ref($query, $uniquename, $processCvId, $functionCvId, $componentCvId, $GOCvId);
}

##---------------------------------------------------------------
## getAllNonGOAssignmentAttributesForSubfeaturesByAssemblyFeatureUniquename()
##
##---------------------------------------------------------------
sub getAllNonGOAssignmentAttributesForSubfeaturesByAssemblyFeatureUniquename {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }

    my $missingCtr=0;

    my $processCvId = $self->getCvIdByName('process');
    if (!defined($processCvId)){
	$self->{_logger}->warn("cv_id was not defined for cv.name 'process'");
	$missingCtr++;
    }
    
    my $functionCvId = $self->getCvIdByName('function');
    if (!defined($functionCvId)){
	$self->{_logger}->warn("cv_id was not defined for cv.name 'function'");
	$missingCtr++;
    }
    
    my $componentCvId = $self->getCvIdByName('component');
    if (!defined($componentCvId)){
	$self->{_logger}->warn("cv_id was not defined for cv.name 'component'");
	$missingCtr++;
    }

    if ($missingCtr > 0){
      if ($missingCtr == 3){
	$self->{_logger}->warn("The Gene Ontology was not split by ".
			       "namespace, therefore could not build ".
			       "lookup by subcategories");
	## return empty lookup
	return undef;
      } else {
	if ($missingCtr == 1){
	  $self->{_logger}->logdie("'$missingCtr' of the Gene Ontology ".
				   "subcategories was missing");
	} else {
	  $self->{_logger}->logdie("'$missingCtr' of the Gene Ontology ".
				   "subcategories were missing");
	}
      }
    }


    my $query = "SELECT fcp.feature_cvterm_id, c.name, fcp.value ".
    "FROM feature_cvtermprop fcp, cvterm c, cvterm c2, feature f, feature_cvterm fc, featureloc fl, feature a ".
    "WHERE a.feature_id = fl.srcfeature_id ".
    "AND fl.feature_id = f.feature_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.cvterm_id = c2.cvterm_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ".
    "AND fcp.type_id = c.cvterm_id ".
    "AND a.uniquename = ? ".
    "AND NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM cv  ".
    "WHERE cv.cv_id = c.cv_id ".
    "AND (c2.cv_id = ? ".
    "OR c2.cv_id = ? ".
    "OR c2.cv_id = ? )) ";

    print "Retrieving all properties for non-GO assignments for all subfeatures that are localized to the sequence with uniquename '$uniquename'\n";

    return $self->_get_results_ref($query, $uniquename, $processCvId, $functionCvId, $componentCvId);
}

##---------------------------------------------------------------
## getCvIdByName()
##
##---------------------------------------------------------------
sub getCvIdByName {

    my($self, $name) = @_;

    if (!defined($name)){
	$self->{_logger}->logdie("name was not defined");
    }

    my $query = "SELECT cv_id ".
    "FROM cv ".
    "WHERE name = ? ";
    
    my $ret = $self->_get_results_ref($query, $name);

    return $ret->[0][0];
}

##---------------------------------------------------------------
## getAllFeatureRelationshipsBySequenceFeatureUniquename()
##
##---------------------------------------------------------------
sub getAllFeatureRelationshipsBySequenceFeatureUniquename {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }

    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match',
							       'SO');
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match' with ".
				 "cv.name = 'SO'");
    }
    my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part',
								   'SO');
    if (!defined($matchPartCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part' with ".
				 "cv.name = 'SO'");
    }

    my $query = qq( 
     SELECT o.uniquename, co.name, s.uniquename, cs.name 
     FROM feature_relationship frel, feature s, feature o, cvterm cs, cvterm co, feature a, featureloc fl 
     WHERE a.feature_id = fl.srcfeature_id 
       AND fl.feature_id = o.feature_id 
       AND o.feature_id = frel.object_id 
       AND frel.subject_id = s.feature_id 
       AND s.type_id = cs.cvterm_id 
       AND o.type_id = co.cvterm_id 
       AND a.uniquename = ? 
       AND s.is_obsolete = FALSE
       AND o.is_obsolete = FALSE
       AND NOT EXISTS ( 
                       SELECT 1 
                       FROM cvterm c2 
                       WHERE c2.cvterm_id = s.type_id
                       AND (c2.name = ? OR c2.name = ? ) )
     );
 

    print "Retrieving all feature relationships for all subfeatures that are localized to the sequence with uniquename '$uniquename'\n";

    return $self->_get_results_ref($query, $uniquename, $matchCvtermId, $matchPartCvtermId);
}

##---------------------------------------------------------------
## getAllSubfeaturesAnalysisByAssembly()
##
##---------------------------------------------------------------
sub getAllSubfeaturesAnalysisByAssembly {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }
    ## The data returned by this method will be used by chado2bsml.pl for creating
    ## <Link> elements that will link the <Feature> elements to their corresponding
    ## <Analysis> elements.


    ## Note that it is currently the case that neither 'match' nor 'match_part' features
    ## are localized to the assembly features-  nor are there plans to do so in the 
    ## foreseeable future.  If that should change, then the second section of this
    ## method should be activated and the first section should be deactivated.
    ## Because of the nested select statement in the second query, its performance is
    ## not as good as the first query's.

    if (1){ ## activated

	##
	## Section 1 - where 'match' and 'match_part' features are NOT localized to the assembly feature.
	##
	my $query = "SELECT f.uniquename, a.program, c.name ".
	"FROM feature assem, featureloc fl, feature f, analysisfeature af, analysis a, cvterm c ".
	"WHERE assem.feature_id = fl.srcfeature_id ".
	"AND fl.feature_id = f.feature_id ".
	"AND f.feature_id = af.feature_id ".
	"AND af.analysis_id = a.analysis_id ".
	"AND af.type_id = c.cvterm_id ".
	"AND assem.uniquename = ? ".
	"AND f.is_obsolete = 0 ";
	
	print "Retrieving all analysis data for all subfeatures that are localized to the sequence with uniquename '$uniquename'\n";
	
	return $self->_get_results_ref($query, $uniquename);
    }

    if (0) { ## deactivated

	##
	## Section 2 - where 'match' and 'match_part' features are localized to the assembly feature.
	##
	my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match',
								   'SO');
	if (!defined($matchCvtermId)){
	    $self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match' with ".
				     "cv.name = 'SO'");
	}
	my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part',
								       'SO');
	if (!defined($matchPartCvtermId)){
	    $self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part' with ".
				     "cv.name = 'SO'");
	}
	
	my $query = "SELECT f.uniquename, a.program, c.name ".
	"FROM feature assem, featureloc fl, feature f, analysisfeature af, analysis a, cvterm c ".
	"WHERE assem.feature_id = fl.srcfeature_id ".
	"AND fl.feature_id = f.feature_id ".
	"AND f.feature_id = af.feature_id ".
	"AND af.analysis_id = a.analysis_id ".
	"AND af.type_id = c.cvterm_id ".
	"AND assem.uniquename = ? ".
	"AND f.is_obsolete = 0 ".
	"AND NOT EXISTS ( ".
	"SELECT 1 ".
	"FROM cvterm c2 ".
	"WHERE c2.cvterm_id = f.type_id ".
	"AND (c2.name = ? OR c2.name = ? ) ) ";
    

	print "Retrieving all analysis data for all subfeatures that are localized to the sequence with uniquename '$uniquename'\n";

	return $self->_get_results_ref($query, $uniquename, $matchCvtermId, $matchPartCvtermId);
    }
}

##---------------------------------------------------------------
## getAllAnalysisData()
##
##---------------------------------------------------------------
sub getAllAnalysisData {

    my($self) = @_;

    my $query = "SELECT program, programversion, sourcename, description, analysis_id ".
    "FROM analysis ";    

    print "Retrieving all analysis data\n";

    return $self->_get_results_ref($query);
}

##---------------------------------------------------------------
## getAllAnalysisProperties()
##
##---------------------------------------------------------------
sub getAllAnalysisProperties {

    my($self) = @_;

    my $query = "SELECT ap.analysis_id, c.name, ap.value ".
    "FROM analysisprop ap ".
    "  INNER JOIN cvterm c ON ap.type_id = c.cvterm_id ";

    print "Retrieving all analysis properties\n";

    return $self->_get_results_ref($query);
}

##---------------------------------------------------------------
## getAllSubfeaturesNotLocalizedToSomeAssembly()
##
##---------------------------------------------------------------
sub getAllSubfeaturesNotLocalizedToSomeAssembly {

    my($self, $uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }

    ## We want all features (f1) that are localized to some other features (f2)
    ## where f1 features are not localized to the assembly
    ## and f2 features are localized to the assembly.

    my $query = "SELECT subf.uniquename, f.uniquename, f.seqlen, f.residues, c.name, fl.fmin, fl.fmax, fl.strand ".
    "FROM cvterm c, feature f, featureloc fl, feature assem, featureloc fl2, feature subf ".
    "WHERE assem.uniquename = ? ".
    "AND assem.feature_id = fl2.srcfeature_id ".
    "AND fl2.feature_id = subf.feature_id ".
    "AND subf.feature_id = fl.srcfeature_id ".
    "AND c.cvterm_id = f.type_id ".
    "AND f.is_analysis = 0 ".
    "AND f.feature_id = fl.feature_id ".
    "AND NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM feature assem2, featureloc fl3 ".
    "WHERE assem2.feature_id = fl3.srcfeature_id ".
    "AND fl3.feature_id = f.feature_id ".
    "AND assem2.uniquename = ? ) ";
    
    print "Retrieving all subfeatures that localized to some Sequences that are themselves localized to the Sequence with uniquename '$uniquename'\n";

    return $self->_get_results_ref($query, $uniquename, $uniquename);
}

##---------------------------------------------------------------
## getAllPropertiesForAllSubfeaturesNotLocalizedToSomeAssembly()
##
##---------------------------------------------------------------
sub getAllPropertiesForAllSubfeaturesNotLocalizedToSomeAssembly {

    my($self, $uniquename, $parent, $child) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }
    
    my $parentFeatureCvtermId = $self->getCvtermIdByTermNameByOntology($parent,'SO');
    if (!defined($parentFeatureCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = '$parent' with cv.name = 'SO'");
    }

    my $childFeatureCvtermId = $self->getCvtermIdByTermNameByOntology($child,'SO');
    if (!defined($childFeatureCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = '$child' with cv.name = 'SO'");
    }

    my $query = "SELECT subf.uniquename, f.uniquename, c.name, fp.value ".
    "FROM feature f, featureloc fl, feature subf, featureloc fl2, feature assem, featureprop fp, cvterm c ".
    "WHERE f.type_id = ? ".
    "AND subf.type_id = ? ".
    "AND f.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = subf.feature_id ".
    "AND subf.feature_id = fl2.feature_id ".
    "AND fl2.srcfeature_id = assem.feature_id ".
    "AND assem.uniquename = ? ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.type_id = c.cvterm_id ";

    return $self->_get_results_ref($query, $childFeatureCvtermId, $parentFeatureCvtermId, $uniquename);

}


##---------------------------------------------------------------
## getAllCrossReferenceForAllSubfeaturesNotLocalizedToSomeAssembly()
##
##---------------------------------------------------------------
sub getAllCrossReferenceForAllSubfeaturesNotLocalizedToSomeAssembly {

    my($self, $uniquename, $parent, $child) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }
    
    ## We want all features (f1) that are localized to some other features (f2)
    ## where f1 features are not localized to the assembly
    ## and f2 features are localized to the assembly.

    my $parentFeatureCvtermId = $self->getCvtermIdByTermNameByOntology($parent,'SO');
    if (!defined($parentFeatureCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = '$parent' with cv.name = 'SO'");
    }

    my $childFeatureCvtermId = $self->getCvtermIdByTermNameByOntology($child,'SO');
    if (!defined($childFeatureCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = '$child' with cv.name = 'SO'");
    }

    my $query ="SELECT subf.uniquename, f.uniquename, db.name, d.accession, d.version ".
    "FROM feature f, featureloc fl, feature subf, featureloc fl2, feature assem, dbxref d, db, feature_dbxref fd ".
    "WHERE f.type_id = ? ".
    "AND subf.type_id = ? ".
    "AND f.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = subf.feature_id ".
    "AND subf.feature_id = fl2.feature_id ".
    "AND fl2.srcfeature_id = assem.feature_id ".
    "AND assem.uniquename = ? ".
    "AND f.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = d.dbxref_id ".
    "AND d.db_id = db.db_id ";

    return $self->_get_results_ref($query, $childFeatureCvtermId, $parentFeatureCvtermId, $uniquename);
}

##---------------------------------------------------------------
## getAllComputationalAnalysisDataByAssemblyAndProgram()
##
##---------------------------------------------------------------
sub getAllComputationalAnalysisDataByAssemblyAndProgram {
    
    my ($self, $uniquename, $program) = @_;
    
    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }

    if (!defined($program)){
	$self->{_logger}->logdie("program was not defined");
    }

    my $computedByCvtermId = $self->getCvtermIdByTermNameByOntology('computed_by','relationship');
    if (!defined($computedByCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by' with cv.name = 'relationship'");
    }

    my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part','SO');
    if (!defined($matchPartCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part' with cv.name = 'SO'");
    }

    #                                                            0         1          2        3           4         5            6             7              8              9              10             11
    my $query = "SELECT query.uniquename, subject.uniquename, flq.fmin, flq.fmax, flq.strand, fls.fmin, fls.fmax, fls.strand, af.rawscore, af.normscore, af.significance, af.pidentity, m.residues, m.feature_id ".
    "FROM feature query, feature subject, feature m, featureloc flq, featureloc fls, analysisfeature af, feature assembly, featureloc fla, analysis a ".
    "WHERE fla.srcfeature_id = assembly.feature_id ".
    "AND assembly.uniquename = ? ".
    "AND fla.feature_id = query.feature_id ".
    "AND query.feature_id = flq.srcfeature_id ".
    "AND flq.rank = 1 ".
    "AND flq.feature_id = m.feature_id ".
    "AND m.feature_id = fls.feature_id ".
    "AND fls.rank = 0 ".
    "AND fls.srcfeature_id = subject.feature_id ".
    "AND m.feature_id = af.feature_id ".
    "AND af.type_id = ? ".  ## computed_by
    "AND af.analysis_id = a.analysis_id ".
    "AND a.program = ? ".
    "AND m.type_id = ? ";


    print "Retrieving all computational analysis for program '$program' related to features localized to the Sequence with uniquename '$uniquename'\n";

    return $self->_get_results_ref($query, $uniquename, $computedByCvtermId, $program, $matchPartCvtermId);
}

##---------------------------------------------------------------
## getAllMatchPartPropertiesByAssemblyAndProgram()
##
##---------------------------------------------------------------
sub getAllMatchPartPropertiesByAssemblyAndProgram {

    my($self, $uniquename, $program) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }
    
    if (!defined($program)){
	$self->{_logger}->logdie("program was not defined");
    }

    my $computedByCvtermId = $self->getCvtermIdByTermNameByOntology('computed_by','relationship');
    if (!defined($computedByCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by' with cv.name = 'relationship'");
    }

    my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part','SO');
    if (!defined($matchPartCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part' with cv.name = 'SO'");
    }

    my $query = "SELECT m.feature_id, c.name, fp.value ".
    "FROM feature query, feature m, featureloc flq, analysisfeature af, feature assembly, featureloc fla, analysis a, cvterm c, featureprop fp ".
    "WHERE fla.srcfeature_id = assembly.feature_id ".
    "AND assembly.uniquename = ? ".
    "AND fla.feature_id = query.feature_id ".
    "AND query.feature_id = flq.srcfeature_id ".
    "AND flq.rank = 1 ".
    "AND flq.feature_id = m.feature_id ".
    "AND m.feature_id = fp.feature_id ".
    "AND fp.type_id = c.cvterm_id ".
    "AND m.feature_id = af.feature_id ".
    "AND af.type_id = ? ".  ## computed_by
    "AND af.analysis_id = a.analysis_id ".
    "AND a.program = ? ".
    "AND m.type_id = ? ";

    print "Retrieving all attributes for the match_part features part of '$program' analysis related to features localized to the Sequence with uniquename '$uniquename'\n";

    return $self->_get_results_ref($query, $uniquename, $computedByCvtermId, $program, $matchPartCvtermId);
}

##-------------------------------------------------------------------------
## getAllComputationalAnalysisSubjectsCrossReferenceByAssemblyAndProgram)(
##
##-------------------------------------------------------------------------
sub getAllComputationalAnalysisSubjectsCrossReferenceByAssemblyAndProgram {

    my($self, $uniquename, $program) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }
    
    if (!defined($program)){
	$self->{_logger}->logdie("program was not defined");
    }

    my $computedByCvtermId = $self->getCvtermIdByTermNameByOntology('computed_by','relationship');
    if (!defined($computedByCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by' with cv.name = 'relationship'");
    }

    my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part','SO');
    if (!defined($matchPartCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part' with cv.name = 'SO'");
    }

    my $query = "SELECT DISTINCT subject.uniquename, db.name, d.accession, d.version ".
    "FROM feature query, feature subject, feature m, featureloc flq, featureloc fls, analysisfeature af, feature assembly, featureloc fla, analysis a, db, dbxref d, feature_dbxref fd ".
    "WHERE fla.srcfeature_id = assembly.feature_id ".
    "AND assembly.uniquename = ? ".
    "AND fla.feature_id = query.feature_id ".
    "AND query.feature_id = flq.srcfeature_id ".
    "AND flq.rank = 1 ".
    "AND flq.feature_id = m.feature_id ".
    "AND m.feature_id = fls.feature_id ".
    "AND fls.rank = 0 ".
    "AND fls.srcfeature_id = subject.feature_id ".
    "AND subject.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = d.dbxref_id ".
    "AND d.db_id = db.db_id ".
    "AND m.feature_id = af.feature_id ".
    "AND af.type_id = ? ".  ## computed_by
    "AND af.analysis_id = a.analysis_id ".
    "AND a.program = ? ".
    "AND m.type_id = ? ";

    print "Retrieving all cross-reference data for subject sequences part of the '$program' analysis for features localized to the sequence with uniquename '$uniquename'\n";

    return $self->_get_results_ref($query, $uniquename, $computedByCvtermId, $program, $matchPartCvtermId);
}

##-------------------------------------------------------------------------
## getAnalysisIdForProgram()
##
##-------------------------------------------------------------------------
sub getAnalysisIdForProgram {

    my($self, $program) = @_;

    if (!defined($program)){
	$self->{_logger}->logdie("program was not defined");
    }
    my $query = "SELECT analysis_id FROM analysis WHERE program = ? ";

    print "Retrieving analysis_id for analysis.program '$program'\n";

    return $self->_get_results_ref($query, $program);
}

##-------------------------------------------------------------------------
## doesAnalysisIdExistInAnalysis()
##
##-------------------------------------------------------------------------
sub doesAnalysisIdExistInAnalysis {

    my($self, $analysis_id) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    my $query = "SELECT analysis_id FROM analysis WHERE analysis_id = ? ";

    return $self->_get_results_ref($query, $analysis_id);
}

##---------------------------------------------------------------
## getPairwiseAlignmentDataForClusterId()
##
##---------------------------------------------------------------
sub getPairwiseAlignmentDataForClusterId {

    my ($self, $cluster_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($cluster_id)){
	$self->{_logger}->logdie("cluster_id was not defined");
    }

    my $computedByCvtermId = $self->getCvtermIdByTermNameByOntology('computed_by',
								    'relationship');
    if (!defined($computedByCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by' ".
				 "in ontology 'relationship'");
    }

    my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part', 'SO');

    if (!defined($matchPartCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part' ".
				 "in ontology 'SO'");
    }


    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match', 'SO');
    
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match' ".
				 "in ontology 'SO'");
    }
    
    my $percentSimilarityCvtermId = $self->getCvtermIdByTermNameByOntology('percent_similarity',
									   'output.ontology');
    if (!defined($percentSimilarityCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'percent_similarity' ".
				 "in ontology 'output.ontology'");
    }

    print "Retrieving all wu-blastp pairwise alignment data where for cluster with feature_id '$cluster_id'\n";


    my $query = "SELECT query.feature_id, subject.feature_id, af2.significance, af2.pidentity, fp.value, query.seqlen, subject.seqlen, flq.fmin, flq.fmax, flq.strand, fls.fmin, fls.fmax, fls.strand ".
    "FROM analysis a2, analysisfeature af1, analysisfeature af2, feature cluster, feature match, feature query, feature subject, featureloc fl1, featureloc fl2, featureloc flq, featureloc fls, featureprop fp ".
    "WHERE cluster.feature_id = ? ". ## cluster_id
    "AND a2.program = 'wu-blastp' ".
    "AND af1.type_id = ? ". ## computed_by
    "AND cluster.is_analysis = 1 ".
    "AND match.is_analysis = 1".
    "AND af2.type_id = ? ". ## computed_by
    "AND a2.analysis_id = af2.analysis_id ".
    "AND af1.feature_id = cluster.feature_id ".
    "AND cluster.type_id = ? ". ## match
    "AND af2.feature_id = match.feature_id ".
    "AND match.type_id = ? ". ## match_part
    "AND cluster.feature_id = fl1.feature_id ".
    "AND fl1.srcfeature_id = query.feature_id ".
    "AND cluster.feature_id = fl2.feature_id ".
    "AND fl2.srcfeature_id = subject.feature_id ".
    "AND match.feature_id = flq.feature_id ".
    "AND flq.srcfeature_id = query.feature_id ".
    "AND match.feature_id = fls.feature_id ".
    "AND fls.srcfeature_id = subject.feature_id ".
    "AND query.feature_id != subject.feature_id ". ## eliminate self-hits
    "AND flq.rank = 1 ". ## query
    "AND fls .rank = 0 ". ## subject
    "AND match.feature_id = fp.feature_id ".
    "AND fp.type_id = ? "; ## percent_similarity

    return $self->_get_results_ref($query, $cluster_id, $computedByCvtermId, $computedByCvtermId, $matchCvtermId,  $matchPartCvtermId, $percentSimilarityCvtermId);
}

##---------------------------------------------------------------
## getPairwiseAlignmentDataForClusterId2()
##
##---------------------------------------------------------------
sub getPairwiseAlignmentDataForClusterId2 {

    my ($self, $clusterIdStart, $clusterIdEnd) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($clusterIdStart)){
	$self->{_logger}->logdie("clusterIdStart was not defined");
    }
    if (!defined($clusterIdEnd)){
	$self->{_logger}->logdie("clusterIdEnd was not defined");
    }


    my $computedByCvtermId = $self->getCvtermIdByTermNameByOntology('computed_by',
								    'relationship');
    if (!defined($computedByCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by' ".
				 "in ontology 'relationship'");
    }

    my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part', 'SO');

    if (!defined($matchPartCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part' ".
				 "in ontology 'SO'");
    }


    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match', 'SO');
    
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match' ".
				 "in ontology 'SO'");
    }
    
    my $percentSimilarityCvtermId = $self->getCvtermIdByTermNameByOntology('percent_similarity',
									   'output.ontology');
    if (!defined($percentSimilarityCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'percent_similarity' ".
				 "in ontology 'output.ontology'");
    }

    print "Retrieving all wu-blastp pairwise alignment data for cluster with feature_id between '$clusterIdStart' and '$clusterIdEnd'\n";


    my $query = "SELECT query.feature_id, subject.feature_id, af2.significance, af2.pidentity, fp.value, query.seqlen, subject.seqlen, flq.fmin, flq.fmax, flq.strand, fls.fmin, fls.fmax, fls.strand, cluster.feature_id ".
    "FROM analysis a2, analysisfeature af1, analysisfeature af2, feature cluster, feature match, feature query, feature subject, featureloc fl1, featureloc fl2, featureloc flq, featureloc fls, featureprop fp ".
    "WHERE a2.program = 'wu-blastp' ".
    "AND af1.type_id = ? ". ## computed_by
    "AND cluster.is_analysis = 1 ".
    "AND match.is_analysis = 1 ".
    "AND af2.type_id = ? ". ## computed_by
    "AND a2.analysis_id = af2.analysis_id ".
    "AND af1.feature_id = cluster.feature_id ".
    "AND cluster.type_id = ? ". ## match
    "AND af2.feature_id = match.feature_id ".
    "AND match.type_id = ? ". ## match_part
    "AND cluster.feature_id = fl1.feature_id ".
    "AND fl1.srcfeature_id = query.feature_id ".
    "AND cluster.feature_id = fl2.feature_id ".
    "AND fl2.srcfeature_id = subject.feature_id ".
    "AND match.feature_id = flq.feature_id ".
    "AND flq.srcfeature_id = query.feature_id ".
    "AND match.feature_id = fls.feature_id ".
    "AND fls.srcfeature_id = subject.feature_id ".
    "AND query.feature_id != subject.feature_id ". ## eliminate self-hits
    "AND flq.rank = 1 ". ## query
    "AND fls .rank = 0 ". ## subject
    "AND match.feature_id = fp.feature_id ".
    "AND fp.type_id = ? ". ## percent_similarity
    "AND cluster.feature_id between ? AND ? ".
    "ORDER BY cluster.feature_id ";

    return $self->_get_results_ref($query, $computedByCvtermId, $computedByCvtermId, 
				   $matchCvtermId,  $matchPartCvtermId, $percentSimilarityCvtermId,
				   $clusterIdStart, $clusterIdEnd);
}

##---------------------------------------------------------------
## getPairwiseAlignmentDataForClusterId3()
##
## Sends several smaller queries. Can be much faster than v2
##---------------------------------------------------------------
sub getPairwiseAlignmentDataForClusterId3 {

    my ($self, $cluster_analysis_id, $align_analysis_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $computedByCvtermId = $self->getCvtermIdByTermNameByOntology('computed_by',
								    'relationship');
    if (!defined($computedByCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by' ".
				 "in ontology 'relationship'");
    }

    my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part', 'SO');

    if (!defined($matchPartCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part' ".
				 "in ontology 'SO'");
    }


    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match', 'SO');
    
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match' ".
				 "in ontology 'SO'");
    }
    
    my $percentSimilarityCvtermId = $self->getCvtermIdByTermNameByOntology('percent_similarity',
									   'output.ontology');
    if (!defined($percentSimilarityCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'percent_similarity' ".
				 "in ontology 'output.ontology'");
    }


    # Step 1: Retrieve all proteins and their cluster assignments
    my $query = "SELECT pfl.srcfeature_id, c.feature_id ".
        "FROM analysis a JOIN analysisfeature af ON (a.analysis_id=$cluster_analysis_id AND af.type_id=$computedByCvtermId AND a.analysis_id=af.analysis_id) ".
        "JOIN feature c ON ( af.feature_id=c.feature_id ) ".
        "JOIN featureloc pfl ON (pfl.feature_id=c.feature_id) ";

    my $clusters = $self->_get_results_ref($query);
    print @$clusters." clusters were found\n";
    my $clusters2proteins = {};
    map { 
        if(!$clusters2proteins->{$_->[1]}) {
            $clusters2proteins->{$_->[1]} = [];
#            print  "Creating an entry for cluster $_->[1]\n";
        }
        push(@{$clusters2proteins->{$_->[1]}}, $_->[0]);
    } @$clusters;

    # Step 2: Retrieve all alignments associated with the proteins in the cluster lists.
    my $resultsref = [];
    my $num =0;
    my $lastnum = 0;
    my $total = scalar keys %{$clusters2proteins};
    foreach my $cluster  (keys %$clusters2proteins) { 
        $num++;
        my $per = ($num/$total)*100;
        if(!$lastnum || ($per >= $lastnum+10)) {
            print sprintf("%.2f",$per)."\% complete pulling alignment data (prints every 10%) \n";
            $lastnum = $per;
        }   

        my $results = $self->getProteinIdsToProteinAlignments($align_analysis_id, $clusters2proteins->{$cluster},$clusters2proteins->{$cluster},1,,,,);
        foreach my $row (@$results) {
            push (@$row, $cluster);
        }
        push (@$resultsref, @$results);
    }
    print "\nDone pulling alignment data\n\n";

    return $resultsref;
}

##---------------------------------------------------------------
## getPairwiseAlignmentDataForClusterIdCmBlast()
##
## Utilizes a prepopulated cm_blast table to pull the alignment 
## data
##---------------------------------------------------------------
sub getPairwiseAlignmentDataForClusterIdCmBlast {

    my ($self, $cluster_analysis_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $computedByCvtermId = $self->getCvtermIdByTermNameByOntology('computed_by',
								    'relationship');
    if (!defined($computedByCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'computed_by' ".
				 "in ontology 'relationship'");
    }

    my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part', 'SO');

    if (!defined($matchPartCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part' ".
				 "in ontology 'SO'");
    }


    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match', 'SO');
    
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match' ".
				 "in ontology 'SO'");
    }
    
    my $percentSimilarityCvtermId = $self->getCvtermIdByTermNameByOntology('percent_similarity',
									   'output.ontology');
    if (!defined($percentSimilarityCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'percent_similarity' ".
				 "in ontology 'output.ontology'");
    }

    # Step 1: Retrieve all proteins and their cluster assignments

    my $query = "SELECT pfl.srcfeature_id, c.feature_id ".
        "FROM analysis a JOIN analysisfeature af ON (a.analysis_id=$cluster_analysis_id AND af.type_id=$computedByCvtermId AND a.analysis_id=af.analysis_id) ".
        "JOIN feature c ON ( af.feature_id=c.feature_id ) ".
        "JOIN featureloc pfl ON (pfl.feature_id=c.feature_id) ";
#        "ORDER BY c.feature_id";

    my $clusters = $self->_get_results_ref($query);
    print  @$clusters." clusters were found\n";
    my $clusters2proteins = {};
    map { 
        #print STDERR "@$_\n"; 
        if(!$clusters2proteins->{$_->[1]}) {
            $clusters2proteins->{$_->[1]} = [];
  #          print STDERR "Creating an entry for cluster $_->[1]\n";
        }
        push(@{$clusters2proteins->{$_->[1]}}, $_->[0]);
    } @$clusters;
   

    ## The embedded query which follows will run much quicker if
    ## the Sybase statement_cache is set to off
    $self->_turnStatementCacheOff();


    # Step 2: Pull alignment data
    my $num =0;
    my $lastnum = 0;
    my $total = scalar keys %{$clusters2proteins};
    my $resultsref = [];
    foreach my $cluster  (keys %$clusters2proteins) { 

        # HACK - This should be configurable 
        my $maxDisjunctSize = 100; 

        $num++;
        my $per = ($num/$total)*100;
        if(!$lastnum || ($per >= $lastnum+10)) {
            print sprintf("%.2f",$per)."\% complete pulling alignment data from cm_blast (prints every 10%) \n";
            $lastnum = $per;
        }   

        # break $queryProteinIds and $subjectProteinIds into groups of no more than $maxDisjunctSize
        my $queryGroups = &partitionListRef($clusters2proteins->{$cluster}, $maxDisjunctSize);
        my $targetGroups = &partitionListRef($clusters2proteins->{$cluster}, $maxDisjunctSize);
        
        my $rows = [];
        
        foreach my $queryIds (@$queryGroups) {
            foreach my $targetIds (@$targetGroups) {
                
                my $query = "SELECT qfeature_id, hfeature_id, per_id, per_sim, per_cov, p_value ".
                    " FROM cm_blast ".
                    " WHERE qfeature_id IN(" . join(',', @$queryIds) . ") ".
                    " AND hfeature_id IN(" . join(',', @$targetIds) . ") " .
                    " AND qfeature_id != hfeature_id ";

                my $results = $self->_get_results_ref($query);
                foreach my $row (@$results) {
                    push (@$row, $cluster);
                }
                push (@$resultsref, @$results);
            }
        }
    }

    ## Restore Sybase statement_cache
    $self->_turnStatementCacheOn();

    return $resultsref;
}

sub partitionListRef {
    my($listref, $newLen) = @_;

    return [undef] if (!defined($listref));
    my $listLen = scalar(@$listref);
    my $groups = [];
    
    for (my $i = 0;$i < $listLen;++$i) {
	my $groupNum = int($i / $newLen);

	if (!defined($groups->[$groupNum])) {
	    $groups->[$groupNum] = [];
	}
	push(@{$groups->[$groupNum]}, $listref->[$i]);
    }
    return $groups;
}

sub getProteinIdsToProteinAlignments {
    my($self,$analysis_id,$queryProteinIds,$targetProteinIds,$noSelfHits,$minLen,$minPctId,$maxSignificance,$db) = @_;
    my $dbp = $db ? "${db}.." : "";
    my $prot_cv_id = $self->getCvtermIdByTermNameByOntology('polypeptide','SO');

    # HACK - TODO make this configurable
    my $maxDisjunctSize = 100; #$config->getDbmsMaxDisjunctSize();

    # break $queryProteinIds and $subjectProteinIds into groups of no more than $maxDisjunctSize
    my $queryGroups = &partitionListRef($queryProteinIds, $maxDisjunctSize);
    my $targetGroups = &partitionListRef($targetProteinIds, $maxDisjunctSize);

    my $rows = [];

    foreach my $queryIds (@$queryGroups) {
	foreach my $targetIds (@$targetGroups) {
	    my $sql = 
		# query protein
		"SELECT prot1.feature_id, ".
#		" prot1.uniquename, ".
#		" (fl1.fmax - fl1.fmin), ".
		" prot1.seqlen, ".
		" fl1.fmin, ".
		" fl1.fmax, ".
		" fl1.strand, ".
		# target protein
		" prot2.feature_id, ".
#		" prot2.uniquename, ".
#		" (fl2.fmax - fl2.fmin), ".
		" prot2.seqlen, ".
		" fl2.fmin, ".
		" fl2.fmax, ".
		" fl2.strand, ".
		# target organism
	#	" prot2.organism_id, ".

		# alignment properties
		" align.pidentity, ".
		" align.significance, ".
		" align.rawscore " .

		"FROM ${dbp}analysisfeature align, " .
		"     ${dbp}featureloc fl1, ${dbp}feature prot1, " .
		"     ${dbp}featureloc fl2, ${dbp}feature prot2 " .

		"WHERE align.analysis_id = $analysis_id " .
		"AND align.feature_id = fl1.feature_id " .
		"AND fl1.rank = 1 " .
		"AND fl1.srcfeature_id = prot1.feature_id " .
		"AND prot1.type_id = $prot_cv_id ". 
		"AND align.feature_id = fl2.feature_id " .
		"AND fl2.rank = 0 " .
		"AND fl2.srcfeature_id = prot2.feature_id " .
		"AND prot2.type_id = $prot_cv_id ". 
        "AND align.significance IS NOT NULL ". # HACK - to filter out match_set features

		($queryIds ? "AND prot1.feature_id in (" . join(',', @$queryIds) . ") " : "") .
		($targetIds ? "AND prot2.feature_id in (" . join(',', @$targetIds) . ") " : "") . 
		($noSelfHits ? "AND prot1.feature_id != prot2.feature_id " : "") . 
		($minLen ? "AND abs(fl1.fmax - fl1.fmin) <= $minLen " : "" ) .
		($minPctId ? "AND align.pidentity >= $minPctId " : "" ) .
		($maxSignificance ? "AND align.significance <= $maxSignificance " : "" );

	    my $srows = $self->_get_results_ref($sql);
	    push(@$rows, @$srows);
	}
    }
    return $rows;
}

##---------------------------------------------------------------
## getFeatureCountByType()
##
##---------------------------------------------------------------
sub getFeatureCountByType {

    my ($self, $type_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($type_id)){
	$self->{_logger}->logdie("type_id was not defined");
    }

    my $query = "SELECT COUNT(f.type_id) ".
    "FROM feature f ".
    "WHERE f.type_id = ? ";

    print "Sending query: Counting number of records in feature with type_id = '$type_id'\n";
    
    return $self->_get_results_ref($query, $type_id);
}

##---------------------------------------------------------------
## getFeatureCountBySecondaryType()
##
##---------------------------------------------------------------
sub getFeatureCountBySecondaryType {

    my ($self, $type_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($type_id)){
	$self->{_logger}->logdie("type_id was not defined");
    }

    my $query = "SELECT COUNT(f.type_id) ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.feature_id = fc.feature_id ".
    "AND fc.cvterm_id =  ? ";
    
    print "Sending query: Counting number of records in feature with secondary type '$type_id'\n";
    
    return $self->_get_results_ref($query, $type_id);
}

##---------------------------------------------------------------
## getFeaturelocCountByTypes()
##
##---------------------------------------------------------------
sub getFeaturelocCountByTypes {

    my ($self, $type_id1, $type_id2) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($type_id1)){
	$self->{_logger}->logdie("type_id1 was not defined");
    }
    if (!defined($type_id2)){
	$self->{_logger}->logdie("type_id2 was not defined");
    }

    my $query = "select count(fa.feature_id) ".
    "from feature fs, feature fa, feature_cvterm s, feature_cvterm a, featureloc fl ".
    "where s.cvterm_id = ? ".
    "and a.cvterm_id = ? ".
    "and fs.feature_id = s.feature_id ".
    "and fa.feature_id = a.feature_id ".
    "and fa.feature_id = fl.feature_id ".
    "and fs.feature_id = fl.srcfeature_id ";

    print "Sending query: Counting number of records in featureloc where sequences with secondary type '$type_id2' ".
    "are localized to sequences with secondary type '$type_id1'\n";
    
    return $self->_get_results_ref($query, $type_id1, $type_id2);
}

##---------------------------------------------------------------
## getFeaturelocCountBySecondaryTypes()
##
##---------------------------------------------------------------
sub getFeaturelocCountBySecondaryTypes {

    my ($self, $type_id1, $type_id2) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($type_id1)){
	$self->{_logger}->logdie("type_id1 was not defined");
    }
    if (!defined($type_id2)){
	$self->{_logger}->logdie("type_id2 was not defined");
    }

    my $query = "select count(fa.feature_id) ".
    "from feature fs, feature fa, feature_cvterm s, feature_cvterm a, featureloc fl ".
    "where s.cvterm_id = ? ".
    "and a.cvterm_id = ? ".
    "and fs.feature_id = s.feature_id ".
    "and fa.feature_id = a.feature_id ".
    "and fa.feature_id = fl.feature_id ".
    "and fs.feature_id = fl.srcfeature_id ";

    print "Sending query: Counting number of records in featureloc where sequences with secondary type '$type_id2' ".
    "are localized to sequences with secondary type '$type_id1'\n";
    
    return $self->_get_results_ref($query, $type_id1, $type_id2);
}

##---------------------------------------------------------------
## getNoLocalizationsByTypes()
##
##---------------------------------------------------------------
sub getNoLocalizationsByTypes {

    my ($self, $type_id1, $type_id2) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($type_id1)){
	$self->{_logger}->logdie("type_id1 was not defined");
    }
    if (!defined($type_id2)){
	$self->{_logger}->logdie("type_id2 was not defined");
    }

    my $query = "SELECT COUNT(p.feature_id) ".
    "FROM feature p ".
    "WHERE p.type_id = ? ".
    "AND NOT EXISTS  ( ".
    " SELECT 1 ".
    " FROM featureloc fl, feature c ".
    " WHERE c.type_id = ? ".
    " AND c.feature_id = fl.feature_id ".
    " AND fl.srcfeature_id = p.feature_id ) ";


    print "Sending query: Counting number of features of type '$type_id1' that do not have any features of type '$type_id2' localized to them.\n";
    
    return $self->_get_results_ref($query, $type_id1, $type_id2);
}


##---------------------------------------------------------------
## getLocalizationsAmongSequencesBySecondaryTypes()
##
##---------------------------------------------------------------
sub getLocalizationsAmongSequencesBySecondaryTypes {

    my($self, $type1, $type2) = @_;

    if (!defined($type1)){
	$self->{_logger}->logdie("type1 was not defined");
    }
    if (!defined($type2)){
	$self->{_logger}->logdie("type2 was not defined");
    }

    #
    # Retrieve all rows where sequence type2 localizes to sequence type1
    # e.g. assemblies localize to supercontigs
    #

    my $query = "select fa.feature_id, fa.uniquename, fs.feature_id, fs.uniquename, fl.fmin, fl.fmax, fl.strand ".
    "from feature fs, feature fa, feature_cvterm s, feature_cvterm a, featureloc fl ".
    "where s.cvterm_id = ? ".
    "and a.cvterm_id = ? ".
    "and fs.feature_id = s.feature_id ".
    "and fa.feature_id = a.feature_id ".
    "and fa.feature_id = fl.feature_id ".
    "and fs.feature_id = fl.srcfeature_id ";

    print "Sending query: All type1 sequences with secondary type '$type1' and localized type2 sequences with secondary type '$type2'\n";

    return $self->_get_results_ref($query, $type1, $type2);
}


##---------------------------------------------------------------
## getFeatureToSequenceSecondaryType2()
##
##---------------------------------------------------------------
sub getFeatureToSequenceSecondaryType2 {

    my($self, $type1, $type2, $seq1, $seq2, $cfmin, $cfmax) = @_;

    #
    # Retrieve feature and child sequence info
    # where feature maps to child sequence and
    # child sequence maps to parent sequence
    # but feature does not map to parent sequence
    #
    my $query = "SELECT f.feature_id, fl.fmin, fl.fmax, fl.strand, fl.phase, fl.residue_info, fl.rank ".
    "FROM feature c, feature f, featureloc fl, feature p, featureloc fl2, feature_cvterm fc ".
    "WHERE c.feature_id = $seq2 ".
    "AND p.feature_id = $seq1 ".
    "AND f.feature_id = fl.feature_id ".     # feature localizes to the child sequence
    "AND fl.srcfeature_id = c.feature_id ".
    "AND c.feature_id = fl2.feature_id ".    # child localizes to the parent sequence
    "AND fl2.srcfeature_id = p.feature_id ".
    "AND p.feature_id = fc.feature_id ".
    "AND fc.cvterm_id = $type1 ".
    "AND NOT EXISTS ( ".  # include only records where the feature does not localize the parent sequence
    "SELECT 1 ".
    "FROM featureloc fl3 ".
    "WHERE f.feature_id = fl3.feature_id ".
    "AND fl3.srcfeature_id = p.feature_id) ";

    return $self->_get_results_ref($query);
}

#---------------------------------------------------------------
# getFeatureToSequenceSecondaryType1()
#
#---------------------------------------------------------------
sub getFeatureToSequenceSecondaryType1 {

    my($self, $type1, $type2, $seq1, $seq2, $cfmin, $cfmax) = @_;

    #
    # Retrieve feature and parent sequence info
    # where feature maps to parent sequence and
    # child sequence maps to parent sequence
    # but feature does not map to child sequence
    #
    my $query = "SELECT f.feature_id, fl.fmin, fl.fmax, fl.strand, fl.phase, fl.residue_info, fl.rank ".
    "FROM feature p, feature f, feature_cvterm fc, featureloc fl, feature c, featureloc fl2 ".
    "WHERE p.feature_id = $seq1 ".
    "AND c.feature_id = $seq2 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.cvterm_id != $type1 ".
    "AND fc.cvterm_id != $type2 ".
    "AND f.feature_id = fl.feature_id ".     # feature localizes to the parent
    "AND fl.srcfeature_id = p.feature_id ".
    "AND c.feature_id = fl2.feature_id ".    # child localizes to the parent
    "AND fl2.srcfeature_id = p.feature_id ".
    "AND fl.fmin  > $cfmin ".                 # Only consider the features whose coordinates are within the
    "AND fl.fmax < $cfmax ".                  # the boundaries of the child sequence
    "AND NOT EXISTS ( ".
    "SELECT 1 ".
    "FROM featureloc fl3 ".
    "WHERE f.feature_id = fl3.feature_id ".    # include only records where the feature does not localize the child
    "AND fl3.srcfeature_id = c.feature_id) ";

    return $self->_get_results_ref($query);
}


#--------------------------------------------------------------------
# getAllPolypeptidesWithStopCodonInResiduesForReverseStrandGenes()
#
#--------------------------------------------------------------------
sub getAllPolypeptidesWithStopCodonInResiduesForReverseStrandGenes {

    my $self = shift;


    my $assemblyCvtermId = $self->getCvtermIdByTermNameByOntology('assembly',
								  'SO');
    if (!defined($assemblyCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'assembly' ".
				 "in ontology 'SO'");
    }

    my $geneCvtermId = $self->getCvtermIdByTermNameByOntology('gene',
							      'SO');
    if (!defined($geneCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'gene' ".
				 "in ontology 'SO'");
    }

    my $transcriptCvtermId = $self->getCvtermIdByTermNameByOntology('transcript',
								    'SO');
    if (!defined($transcriptCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'transcript' ".
				 "in ontology 'SO'");
    }

    my $cdsCvtermId = $self->getCvtermIdByTermNameByOntology('CDS',
							     'SO');
    if (!defined($cdsCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'CDS' ".
				 "in ontology 'SO'");
    }

    my $polypeptideCvtermId = $self->getCvtermIdByTermNameByOntology('polypeptide',
								     'SO');
    if (!defined($polypeptideCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'polypeptide' ".
				 "in ontology 'SO'");
    }



    ## Only way that I know of to get the last character in a text field:
    my $query = "select polypeptide.feature_id, substring(convert(varchar(16384),polypeptide.residues), datalength(convert(varchar(16384),polypeptide.residues)),1) ".
#    my $query = "select polypeptide.feature_id, substring(convert(varchar(100000),polypeptide.residues), datalength(convert(varchar(100000),polypeptide.residues)),1) ".
    "from feature polypeptide, feature cds, feature trans, feature gene, feature_relationship frel1, feature_relationship frel2, feature_relationship frel3, featureloc fl, feature assembly ".
    "where assembly.type_id = ? ".
    "and gene.type_id = ? ".
    "and trans.type_id = ? ".
    "and cds.type_id = ? ".
    "and polypeptide.type_id = ? ".
    "and gene.feature_id = fl.feature_id ".
    "and fl.srcfeature_id = assembly.feature_id ".
    "and fl.strand = -1 ". ## reverse-strand genes only
    "and gene.is_analysis = 0 ". ## non-computationally derived genes only
    "and gene.feature_id = frel1.object_id ".
    "and frel1.subject_id = trans.feature_id ". ## gene is related to transcript
    "and trans.feature_id = frel2.object_id ".
    "and frel2.subject_id = cds.feature_id ". ## transcript is related to cds
    "and cds.feature_id = frel3.object_id ".
    "and frel3.subject_id = polypeptide.feature_id "; ## cds is related to polypeptide

    return $self->_get_results_ref($query, $assemblyCvtermId, $geneCvtermId, $transcriptCvtermId, $cdsCvtermId, $polypeptideCvtermId);
}

##-------------------------------------------------------------
## getAllAssemblyFeatureIdsForSpliceSites()
##
##-------------------------------------------------------------
sub getAllAssemblyFeatureIdsForSpliceSites {

    my ($self) = @_;

    print "Retrieving list of assembly identifiers that qualify for splice site derivation\n";

    ## Retrieve non-obsolete, non-analysis assembly identifiers
    ## for which there is at least one non-obsolete, non-analysis
    ## exon localized to it.

    my $query = "SELECT distinct a.feature_id ".
    "FROM feature a, cvterm c, feature e, cvterm x, featureloc fl ".
    "WHERE c.name = 'assembly' ".
    "AND c.cvterm_id = a.type_id ".
    "AND a.is_obsolete = 0 ".
    "AND a.is_analysis = 0 ".
    "AND a.feature_id  = fl.srcfeature_id ".
    "AND fl.feature_id = e.feature_id ".
    "AND e.type_id = x.cvterm_id ".
    "AND x.name = 'exon' ".
    "AND e.is_analysis = 0 ".
    "AND e.is_obsolete = 0 ".
    "ORDER BY a.feature_id ";

    return $self->_get_results_ref($query);
}


##-------------------------------------------------------------
## getFeatureIdByUniquename()
##
##-------------------------------------------------------------
sub getFeatureIdByUniquename {

    my $self = shift;
    my ($uniquename) = @_;

    if (!defined($uniquename)){
	$self->{_logger}->logdie("uniquename was not defined");
    }

    print "Retrieving feature_id for uniquename '$uniquename'\n";

    ## Retrieve non-obsolete, non-analysis assembly identifiers
    ## for which there is at least one non-obsolete, non-analysis
    ## exon localized to it.

    my $query = "SELECT feature_id ".
    "FROM feature ".
    "WHERE uniquename = ? ";

    return $self->_get_results_ref($query, $uniquename);
}

##-------------------------------------------------------------
## doesAnalysisIdExist()
##
##-------------------------------------------------------------
sub doesAnalysisIdExist {

    my $self = shift;
    my ($analysis_id) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }

    my $query = "SELECT COUNT(*) ".
    "FROM analysis ".
    "WHERE analysis_id = ? ";

    return $self->_get_results_ref($query, $analysis_id);
}
 
##-------------------------------------------------------------
## doesAlgorithmExist()
##
##-------------------------------------------------------------
sub doesAlgorithmExist {

    my $self = shift;
    my ($algorithm) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    my $query = "SELECT COUNT(*) ".
    "FROM analysis ".
    "WHERE algorithm = ? ";

    return $self->_get_results_ref($query, $algorithm);
}


##-------------------------------------------------------------
## doesFeatureIdExist()
##
##-------------------------------------------------------------
sub doesFeatureIdExist {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT COUNT(feature_id) ".
    "FROM feature ".
    "WHERE feature_id = ? ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## doObsoleteFeaturesExist()
##
##-------------------------------------------------------------
sub doObsoleteFeaturesExist {

    my $self = shift;

    my $query = "SELECT COUNT(is_obsolete) ".
    "FROM feature ".
    "WHERE is_obsolete = 1 ";

    return $self->_get_results_ref($query);
}


##-------------------------------------------------------------
## doesOrganismIdExist()
##
##-------------------------------------------------------------
sub doesOrganismIdExist {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT COUNT(*) ".
    "FROM organism ".
    "WHERE organism_id = ? ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getAnalysisfeatureRecordCountByAnalysisId()
##
##-------------------------------------------------------------
sub getAnalysisfeatureRecordCountByAnalysisId {

    my $self = shift;
    my ($analysis_id) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }

    my $query = "SELECT COUNT(*) ".
    "FROM analysisfeature ".
    "WHERE analysis_id = ? ";

    return $self->_get_results_ref($query, $analysis_id);
}

##-------------------------------------------------------------
## getAnalysisfeatureRecordCountByAlgorithm()
##
##-------------------------------------------------------------
sub getAnalysisfeatureRecordCountByAlgorithm {

    my $self = shift;
    my ($algorithm) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    my $query = "SELECT COUNT(af.analysis_id) ".
    "FROM analysisfeature af, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ";

    return $self->_get_results_ref($query, $algorithm);
}

##-------------------------------------------------------------
## getAnalysispropRecordCountByAnalysisId()
##
##-------------------------------------------------------------
sub getAnalysispropRecordCountByAnalysisId {

    my $self = shift;
    my ($analysis_id) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }

    my $query = "SELECT COUNT(*) ".
    "FROM analysisprop ".
    "WHERE analysis_id = ? ";

    return $self->_get_results_ref($query, $analysis_id);
}

##-------------------------------------------------------------
## getAnalysispropRecordCountByAlgorithm()
##
##-------------------------------------------------------------
sub getAnalysispropRecordCountByAlgorithm {

    my $self = shift;
    my ($algorithm) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    my $query = "SELECT COUNT(ap.analysis_id) ".
    "FROM analysisprop ap, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = ap.analysis_id ";

    return $self->_get_results_ref($query, $algorithm);
}

##-------------------------------------------------------------
## doDeleteAnalysispropByAnalysisId()
##
##-------------------------------------------------------------
sub doDeleteAnalysispropByAnalysisId {

    my $self = shift;
    my ($analysis_id) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }

    my $query = "DELETE FROM analysisprop ".
    "WHERE analysis_id = ? ";

    return $self->_get_results_ref($query, $analysis_id);
}

##-------------------------------------------------------------
## doDeleteAnalysispropByAlgorithm()
##
##-------------------------------------------------------------
sub doDeleteAnalysispropByAlgorithm {

    my $self = shift;
    my ($algorithm) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    my $query = "DELETE analysisprop ".
    "FROM analysisprop ap, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = ap.analysis_id ";

    return $self->_get_results_ref($query, $algorithm);
}

##-------------------------------------------------------------
## doDeleteAnalysisByAnalysisId()
##
##-------------------------------------------------------------
sub doDeleteAnalysisByAnalysisId {

    my $self = shift;
    my ($analysis_id) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }

    my $query = "DELETE FROM analysis ".
    "WHERE analysis_id = ? ";

    return $self->_get_results_ref($query, $analysis_id);
}

##-------------------------------------------------------------
## doDeleteAnalysisByAlgorithm()
##
##-------------------------------------------------------------
sub doDeleteAnalysisByAlgorithm {

    my $self = shift;
    my ($algorithm) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    my $query = "DELETE FROM analysis ".
    "WHERE algorithm = ? ";

    return $self->_get_results_ref($query, $algorithm);
}

##-------------------------------------------------------------
## getFeatureRecordCountByOrganismId()
##
##-------------------------------------------------------------
sub getFeatureRecordCountByOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT COUNT(*) ".
    "FROM feature ".
    "WHERE organism_id = ? ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getOrganismpropRecordCountByOrganismId()
##
##-------------------------------------------------------------
sub getOrganismpropRecordCountByOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT COUNT(*) ".
    "FROM organismprop ".
    "WHERE organism_id = ? ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getOrganismDbxrefRecordCountByOrganismId()
##
##-------------------------------------------------------------
sub getOrganismDbxrefRecordCountByOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT COUNT(*) ".
    "FROM organism_dbxref ".
    "WHERE organism_id = ? ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## doDeleteOrganismpropByOrganismId()
##
##-------------------------------------------------------------
sub doDeleteOrganismpropByOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "DELETE FROM organismprop ".
    "WHERE organism_id = ? ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## doDeleteOrganismDbxrefByOrganismId()
##
##-------------------------------------------------------------
sub doDeleteOrganismDbxrefByOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "DELETE FROM organism_dbxref ".
    "WHERE organism_id = ? ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getMinMaxAnalysispropIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxAnalysispropIdForAnalysisId {

    my $self = shift;
    my ($analysis_id) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }

    my $query = "SELECT MIN(analysisprop_id), MAX(analysisprop_id) ".
    "FROM analysisprop ".
    "WHERE analysis_id = ? ";

    return $self->_get_results_ref($query, $analysis_id);
}

##-------------------------------------------------------------
## getMinMaxAnalysisfeatureIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxAnalysisfeatureIdForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(analysisfeature_id), MAX(analysisfeature_id) ".
    "FROM analysisfeature ".
    "WHERE analysis_id = ? ".
    "AND type_id = ? ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureIdForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(f.feature_id), MAX(f.feature_id) ".
    "FROM feature f, analysisfeature af ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeaturelocIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxFeaturelocIdForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fl.featureloc_id), MAX(fl.featureloc_id) ".
    "FROM feature f, analysisfeature af, featureloc fl ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id ) ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeaturePubIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxFeaturePubIdForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fp.feature_pub_id), MAX(fp.feature_pub_id) ".
    "FROM feature f, analysisfeature af, feature_pub fp ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureRelationshipIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelationshipIdForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(frel.feature_relationship_id), MAX(frel.feature_relationship_id) ".
    "FROM feature f, analysisfeature af, feature_relationship frel ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}


##-------------------------------------------------------------
## getMinMaxFeatureRelationshipPubIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelationshipPubIdForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(frelpub.feature_relationship_pub_id), MAX(frelpub.feature_relationship_pub_id) ".
    "FROM feature f, analysisfeature af, feature_relationship frel, feature_relationship_pub frelpub ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureRelationshippropIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelationshippropIdForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(frelprop.feature_relationshipprop_id), MAX(frelprop.feature_relationshipprop_id) ".
    "FROM feature f, analysisfeature af, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}


##-------------------------------------------------------------
## getMinMaxFeatureRelpropPubIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelpropPubIdForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fpp.feature_relprop_pub_id), MAX(fpp.feature_relprop_pub_id) ".
    "FROM feature f, analysisfeature af, feature_relationship frel, feature_relationshipprop fp, feature_relprop_pub fpp ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = fp.feature_relationship_id ".
    "AND fp.feature_relationshipprop_id = fpp.feature_relationshipprop_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureDbxrefIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureDbxrefIdForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fd.feature_dbxref_id), MAX(fd.feature_dbxref_id) ".
    "FROM feature f, analysisfeature af, feature_dbxref fd ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fd.feature_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeaturepropIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxFeaturepropIdForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fp.featureprop_id), MAX(fp.featureprop_id) ".
    "FROM feature f, analysisfeature af, featureprop fp ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeaturepropPubIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxFeaturepropPubIdForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fpp.featureprop_pub_id), MAX(fpp.featureprop_pub_id) ".
    "FROM feature f, analysisfeature af, featureprop fp, featureprop_pub fpp ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fpp.featureprop_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermIdForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fc.feature_cvterm_id), MAX(fc.feature_cvterm_id) ".
    "FROM feature f, analysisfeature af, feature_cvterm fc ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fc.feature_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermDbxrefIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermDbxrefIdForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fcd.feature_cvterm_dbxref_id), MAX(fcd.feature_cvterm_dbxref_id) ".
    "FROM feature f, analysisfeature af, feature_cvterm fc, feature_cvterm_dbxref fcd ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermPubIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermPubIdForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fcp.feature_cvterm_pub_id), MAX(fcp.feature_cvterm_pub_id) ".
    "FROM feature f, analysisfeature af, feature_cvterm fc, feature_cvterm_pub fcp ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermpropIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermpropIdForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fcp.feature_cvtermprop_id), MAX(fcp.feature_cvtermprop_id) ".
    "FROM feature f, analysisfeature af, feature_cvterm fc, feature_cvtermprop fcp ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureSynonymIdForAnalysisId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureSynonymIdForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fs.feature_synonym_id), MAX(fs.feature_synonym_id) ".
    "FROM feature f, analysisfeature af, feature_synonym fs ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fs.feature_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxAnalysispropIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxAnalysispropIdForAlgorithm {

    my $self = shift;
    my ($algorithm) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    my $query = "SELECT MIN(ap.analysisprop_id), MAX(ap.analysisprop_id) ".
    "FROM analysisprop ap, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = ap.analysis_id ";

    return $self->_get_results_ref($query, $algorithm);
}

##-------------------------------------------------------------
## getMinMaxAnalysisfeatureIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxAnalysisfeatureIdForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(af.analysisfeature_id), MAX(af.analysisfeature_id) ".
    "FROM analysisfeature af, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = ? ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxFeatureIdForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(f.feature_id), MAX(f.feature_id) ".
    "FROM feature f, analysisfeature af, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeaturelocIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxFeaturelocIdForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fl.featureloc_id), MAX(fl.featureloc_id) ".
    "FROM feature f, analysisfeature af, featureloc fl, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id ) ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeaturePubIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxFeaturePubIdForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fp.feature_pub_id), MAX(fp.feature_pub_id) ".
    "FROM feature f, analysisfeature af, feature_pub fp, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureRelationshipIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelationshipIdForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(frel.feature_relationship_id), MAX(frel.feature_relationship_id) ".
    "FROM feature f, analysisfeature af, feature_relationship frel, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}


##-------------------------------------------------------------
## getMinMaxFeatureRelationshipPubIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelationshipPubIdForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(frelpub.feature_relationship_pub_id), MAX(frelpub.feature_relationship_pub_id) ".
    "FROM feature f, analysisfeature af, feature_relationship frel, feature_relationship_pub frelpub, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureRelationshippropIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelationshippropIdForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(frelprop.feature_relationshipprop_id), MAX(frelprop.feature_relationshipprop_id) ".
    "FROM feature f, analysisfeature af, feature_relationship frel, feature_relationshipprop frelprop, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}


##-------------------------------------------------------------
## getMinMaxFeatureRelpropPubIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelpropPubIdForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fpp.feature_relprop_pub_id), MAX(fp.feature_relprop_pub_id) ".
    "FROM feature f, analysisfeature af, feature_relationship frel, feature_relationshipprop fp, feature_relprop_pub fpp, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = fp.feature_relationship_id ".
    "AND fp.feature_relationshipprop_id = fpp.feature_relationshipprop_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureDbxrefIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxFeatureDbxrefIdForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fd.feature_dbxref_id), MAX(fd.feature_dbxref_id) ".
    "FROM feature f, analysisfeature af, feature_dbxref fd, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fd.feature_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeaturepropIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxFeaturepropIdForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fp.featureprop_id), MAX(fp.featureprop_id) ".
    "FROM feature f, analysisfeature af, featureprop fp, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeaturepropPubIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxFeaturepropPubIdForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fpp.featureprop_pub_id), MAX(fpp.featureprop_pub_id) ".
    "FROM feature f, analysisfeature af, featureprop fp, featureprop_pub fpp, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fpp.featureprop_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermIdForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fc.feature_cvterm_id), MAX(fc.feature_cvterm_id) ".
    "FROM feature f, analysisfeature af, feature_cvterm fc, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fc.feature_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermDbxrefIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermDbxrefIdForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fcd.feature_cvterm_dbxref_id), MAX(fcd.feature_cvterm_dbxref_id) ".
    "FROM feature f, analysisfeature af, feature_cvterm fc, feature_cvterm_dbxref fcd, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermPubIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermPubIdForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fcp.feature_cvterm_pub_id), MAX(fcp.feature_cvterm_pub_id) ".
    "FROM feature f, analysisfeature af, feature_cvterm fc, feature_cvterm_pub fcp, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermpropIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermpropIdForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fcp.feature_cvtermprop_id), MAX(fcp.feature_cvtermprop_id) ".
    "FROM feature f, analysisfeature af, feature_cvterm fc, feature_cvtermprop fcp, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getMinMaxFeatureSynonymIdForAlgorithm()
##
##-------------------------------------------------------------
sub getMinMaxFeatureSynonymIdForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT MIN(fs.feature_synonym_id), MAX(fs.feature_synonym_id) ".
    "FROM feature f, analysisfeature af, feature_synonym fs, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fs.feature_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}


##-------------------------------------------------------------
## getMinMaxAnalysisfeatureIdForFeatureId()
##
##-------------------------------------------------------------
sub getMinMaxAnalysisfeatureIdForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT MIN(af.analysisfeature_id), MAX(af.analysisfeature_id) ".
    "FROM analysisfeature af, feature f ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = af.feature_id ";

    return $self->_get_results_ref($query, $feature_id);
}


##-------------------------------------------------------------
## getMinMaxFeaturelocIdForFeatureId()
##
##-------------------------------------------------------------
sub getMinMaxFeaturelocIdForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fl.featureloc_id), MAX(fl.featureloc_id) ".
    "FROM feature f, featureloc fl ".
    "WHERE f.feature_id = ? ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id ) ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getMinMaxFeaturePubIdForFeatureId()
##
##-------------------------------------------------------------
sub getMinMaxFeaturePubIdForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fp.feature_pub_id), MAX(fp.feature_pub_id) ".
    "FROM feature f, feature_pub fp ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureRelationshipIdForFeatureId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelationshipIdForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT MIN(frel.feature_relationship_id), MAX(frel.feature_relationship_id) ".
    "FROM feature f, feature_relationship frel ".
    "WHERE f.feature_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )";

    return $self->_get_results_ref($query, $feature_id);
}


##-------------------------------------------------------------
## getMinMaxFeatureRelationshipPubIdForFeatureId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelationshipPubIdForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT MIN(frelpub.feature_relationship_pub_id), MAX(frelpub.feature_relationship_pub_id) ".
    "FROM feature f, feature_relationship frel, feature_relationship_pub frelpub ".
    "WHERE f.feature_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureRelationshippropIdForFeatureId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelationshippropIdForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT MIN(frelprop.feature_relationshipprop_id), MAX(frelprop.feature_relationshipprop_id) ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE f.feature_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ";

    return $self->_get_results_ref($query, $feature_id);
}


##-------------------------------------------------------------
## getMinMaxFeatureRelpropPubIdForFeatureId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelpropPubIdForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fpp.feature_relprop_pub_id), MAX(fp.feature_relprop_pub_id) ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop fp, feature_relprop_pub fpp ".
    "WHERE f.feature_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = fp.feature_relationship_id ".
    "AND fp.feature_relationshipprop_id = fpp.feature_relationshipprop_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureDbxrefIdForFeatureId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureDbxrefIdForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fd.feature_dbxref_id), MAX(fd.feature_dbxref_id) ".
    "FROM feature f, feature_dbxref fd ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fd.feature_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getMinMaxFeaturepropIdForFeatureId()
##
##-------------------------------------------------------------
sub getMinMaxFeaturepropIdForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fp.featureprop_id), MAX(fp.featureprop_id) ".
    "FROM feature f, featureprop fp ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getMinMaxFeaturepropPubIdForFeatureId()
##
##-------------------------------------------------------------
sub getMinMaxFeaturepropPubIdForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fpp.featureprop_pub_id), MAX(fpp.featureprop_pub_id) ".
    "FROM feature f, featureprop fp, featureprop_pub fpp ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fpp.featureprop_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermIdForFeatureId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermIdForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fc.feature_cvterm_id), MAX(fc.feature_cvterm_id) ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fc.feature_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermDbxrefIdForFeatureId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermDbxrefIdForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fcd.feature_cvterm_dbxref_id), MAX(fcd.feature_cvterm_dbxref_id) ".
    "FROM feature f, feature_cvterm fc, feature_cvterm_dbxref fcd ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermPubIdForFeatureId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermPubIdForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fcp.feature_cvterm_pub_id), MAX(fcp.feature_cvterm_pub_id) ".
    "FROM feature f, feature_cvterm fc, feature_cvterm_pub fcp ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermpropIdForFeatureId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermpropIdForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fcp.feature_cvtermprop_id), MAX(fcp.feature_cvtermprop_id) ".
    "FROM feature f, feature_cvterm fc, feature_cvtermprop fcp ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureSynonymIdForFeatureId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureSynonymIdForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fs.feature_synonym_id), MAX(fs.feature_synonym_id) ".
    "FROM feature f, feature_synonym fs ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fs.feature_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureIdForIsObsolete()
##
##-------------------------------------------------------------
sub getMinMaxFeatureIdForIsObsolete {

    my $self = shift;

    my $query = "SELECT MIN(f.feature_id), MAX(f.feature_id) ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getMinMaxAnalysisfeatureIdForIsObsolete()
##
##-------------------------------------------------------------
sub getMinMaxAnalysisfeatureIdForIsObsolete {

    my $self = shift;

    my $query = "SELECT MIN(af.analysisfeature_id), MAX(af.analysisfeature_id) ".
    "FROM analysisfeature af, feature f ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = af.feature_id ";

    return $self->_get_results_ref($query);
}


##-------------------------------------------------------------
## getMinMaxFeaturelocIdForIsObsolete()
##
##-------------------------------------------------------------
sub getMinMaxFeaturelocIdForIsObsolete {

    my $self = shift;

    my $query = "SELECT MIN(fl.featureloc_id), MAX(fl.featureloc_id) ".
    "FROM feature f, featureloc fl ".
    "WHERE f._is_obsolete = 1 ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id ) ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getMinMaxFeaturePubIdForIsObsolete()
##
##-------------------------------------------------------------
sub getMinMaxFeaturePubIdForIsObsolete {

    my $self = shift;

    my $query = "SELECT MIN(fp.feature_pub_id), MAX(fp.feature_pub_id) ".
    "FROM feature f, feature_pub fp ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getMinMaxFeatureRelationshipIdForIsObsolete()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelationshipIdForIsObsolete {

    my $self = shift;

    my $query = "SELECT MIN(frel.feature_relationship_id), MAX(frel.feature_relationship_id) ".
    "FROM feature f, feature_relationship frel ".
    "WHERE f._is_obsolete = 1 ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )";

    return $self->_get_results_ref($query);
}


##-------------------------------------------------------------
## getMinMaxFeatureRelationshipPubIdForIsObsolete()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelationshipPubIdForIsObsolete {

    my $self = shift;

    my $query = "SELECT MIN(frelpub.feature_relationship_pub_id), MAX(frelpub.feature_relationship_pub_id) ".
    "FROM feature f, feature_relationship frel, feature_relationship_pub frelpub ".
    "WHERE f._is_obsolete = 1 ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getMinMaxFeatureRelationshippropIdForIsObsolete()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelationshippropIdForIsObsolete {

    my $self = shift;

    my $query = "SELECT MIN(frelprop.feature_relationshipprop_id), MAX(frelprop.feature_relationshipprop_id) ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE f._is_obsolete = 1 ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ";

    return $self->_get_results_ref($query);
}


##-------------------------------------------------------------
## getMinMaxFeatureRelpropPubIdForIsObsolete()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelpropPubIdForIsObsolete {

    my $self = shift;

    my $query = "SELECT MIN(fpp.feature_relprop_pub_id), MAX(fp.feature_relprop_pub_id) ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop fp, feature_relprop_pub fpp ".
    "WHERE f._is_obsolete = 1 ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = fp.feature_relationship_id ".
    "AND fp.feature_relationshipprop_id = fpp.feature_relationshipprop_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getMinMaxFeatureDbxrefIdForIsObsolete()
##
##-------------------------------------------------------------
sub getMinMaxFeatureDbxrefIdForIsObsolete {

    my $self = shift;

    my $query = "SELECT MIN(fd.feature_dbxref_id), MAX(fd.feature_dbxref_id) ".
    "FROM feature f, feature_dbxref fd ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fd.feature_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getMinMaxFeaturepropIdForIsObsolete()
##
##-------------------------------------------------------------
sub getMinMaxFeaturepropIdForIsObsolete {

    my $self = shift;

    my $query = "SELECT MIN(fp.featureprop_id), MAX(fp.featureprop_id) ".
    "FROM feature f, featureprop fp ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getMinMaxFeaturepropPubIdForIsObsolete()
##
##-------------------------------------------------------------
sub getMinMaxFeaturepropPubIdForIsObsolete {

    my $self = shift;

    my $query = "SELECT MIN(fpp.featureprop_pub_id), MAX(fpp.featureprop_pub_id) ".
    "FROM feature f, featureprop fp, featureprop_pub fpp ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fpp.featureprop_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermIdForIsObsolete()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermIdForIsObsolete {

    my $self = shift;

    my $query = "SELECT MIN(fc.feature_cvterm_id), MAX(fc.feature_cvterm_id) ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermDbxrefIdForIsObsolete()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermDbxrefIdForIsObsolete {

    my $self = shift;

    my $query = "SELECT MIN(fcd.feature_cvterm_dbxref_id), MAX(fcd.feature_cvterm_dbxref_id) ".
    "FROM feature f, feature_cvterm fc, feature_cvterm_dbxref fcd ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermPubIdForIsObsolete()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermPubIdForIsObsolete {

    my $self = shift;

    my $query = "SELECT MIN(fcp.feature_cvterm_pub_id), MAX(fcp.feature_cvterm_pub_id) ".
    "FROM feature f, feature_cvterm fc, feature_cvterm_pub fcp ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermpropIdForIsObsolete()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermpropIdForIsObsolete {

    my $self = shift;

    my $query = "SELECT MIN(fcp.feature_cvtermprop_id), MAX(fcp.feature_cvtermprop_id) ".
    "FROM feature f, feature_cvterm fc, feature_cvtermprop fcp ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getMinMaxFeatureSynonymIdForIsObsolete()
##
##-------------------------------------------------------------
sub getMinMaxFeatureSynonymIdForIsObsolete {

    my $self = shift;

    my $query = "SELECT MIN(fs.feature_synonym_id), MAX(fs.feature_synonym_id) ".
    "FROM feature f, feature_synonym fs ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fs.feature_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getMinMaxOrganismpropIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxOrganismpropIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(op.organismprop_id), MAX(op.organismprop_id) ".
    "FROM organismprop op, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = op.organism_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getMinMaxOrganismDbxrefIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxOrganismDbxrefIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(od.organism_dbxref_id), MAX(od.organism_dbxref_id) ".
    "FROM organism_dbxref od, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = od.organism_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(f.feature_id), MAX(f.feature_id) ".
    "FROM feature f, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getMinMaxAnalysisfeatureIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxAnalysisfeatureIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(af.analysisfeature_id), MAX(af.analysisfeature_id) ".
    "FROM analysisfeature af, feature f, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = af.feature_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getMinMaxFeaturelocIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxFeaturelocIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fl.featureloc_id), MAX(fl.featureloc_id) ".
    "FROM feature f, featureloc fl, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.feature_id ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id ) ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getMinMaxFeaturePubIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxFeaturePubIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fp.feature_pub_id), MAX(fp.feature_pub_id) ".
    "FROM feature f, feature_pub fp, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureRelationshipIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelationshipIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(frel.feature_relationship_id), MAX(frel.feature_relationship_id) ".
    "FROM feature f, feature_relationship frel, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )";

    return $self->_get_results_ref($query, $organism_id);
}


##-------------------------------------------------------------
## getMinMaxFeatureRelationshipPubIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelationshipPubIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(frelpub.feature_relationship_pub_id), MAX(frelpub.feature_relationship_pub_id) ".
    "FROM feature f, feature_relationship frel, feature_relationship_pub frelpub, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureRelationshippropIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelationshippropIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(frelprop.feature_relationshipprop_id), MAX(frelprop.feature_relationshipprop_id) ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop frelprop, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ";

    return $self->_get_results_ref($query, $organism_id);
}


##-------------------------------------------------------------
## getMinMaxFeatureRelpropPubIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureRelpropPubIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fpp.feature_relprop_pub_id), MAX(fp.feature_relprop_pub_id) ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop fp, feature_relprop_pub fpp, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = fp.feature_relationship_id ".
    "AND fp.feature_relationshipprop_id = fpp.feature_relationshipprop_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureDbxrefIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureDbxrefIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fd.feature_dbxref_id), MAX(fd.feature_dbxref_id) ".
    "FROM feature f, feature_dbxref fd, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = fd.feature_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getMinMaxFeaturepropIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxFeaturepropIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fp.featureprop_id), MAX(fp.featureprop_id) ".
    "FROM feature f, featureprop fp, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getMinMaxFeaturepropPubIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxFeaturepropPubIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fpp.featureprop_pub_id), MAX(fpp.featureprop_pub_id) ".
    "FROM feature f, featureprop fp, featureprop_pub fpp, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fpp.featureprop_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fc.feature_cvterm_id), MAX(fc.feature_cvterm_id) ".
    "FROM feature f, feature_cvterm fc, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = fc.feature_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermDbxrefIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermDbxrefIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fcd.feature_cvterm_dbxref_id), MAX(fcd.feature_cvterm_dbxref_id) ".
    "FROM feature f, feature_cvterm fc, feature_cvterm_dbxref fcd, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermPubIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermPubIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fcp.feature_cvterm_pub_id), MAX(fcp.feature_cvterm_pub_id) ".
    "FROM feature f, feature_cvterm fc, feature_cvterm_pub fcp, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureCvtermpropIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureCvtermpropIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fcp.feature_cvtermprop_id), MAX(fcp.feature_cvtermprop_id) ".
    "FROM feature f, feature_cvterm fc, feature_cvtermprop fcp, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getMinMaxFeatureSynonymIdForOrganismId()
##
##-------------------------------------------------------------
sub getMinMaxFeatureSynonymIdForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT MIN(fs.feature_synonym_id), MAX(fs.feature_synonym_id) ".
    "FROM feature f, feature_synonym fs, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.organism_id = fs.organism_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getAnalysispropIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getAnalysispropIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }

    my $query = "SELECT analysisprop_id ".
    "FROM analysisprop ".
    "WHERE analysis_id = ? ";

    return $self->_get_results_ref($query, $analysis_id);
}

##-------------------------------------------------------------
## getAnalysisfeatureIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getAnalysisfeatureIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT analysisfeature_id ".
    "FROM analysisfeature ".
    "WHERE analysis_id = ? ".
    "AND type_id = ? ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getFeatureIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getFeatureIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT f.feature_id ".
    "FROM feature f, analysisfeature af ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getFeaturelocIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getFeaturelocIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fl.featureloc_id ".
    "FROM feature f, analysisfeature af, featureloc fl ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id ) ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getFeaturePubIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getFeaturePubIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fp.feature_pub_id ".
    "FROM feature f, analysisfeature af, feature_pub fp ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getFeatureRelationshipIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getFeatureRelationshipIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT frel.feature_relationship_id ".
    "FROM feature f, analysisfeature af, feature_relationship frel ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}


##-------------------------------------------------------------
## getFeatureRelationshipPubIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getFeatureRelationshipPubIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT frelpub.feature_relationship_pub_id ".
    "FROM feature f, analysisfeature af, feature_relationship frel, feature_relationship_pub frelpub ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getFeatureRelationshippropIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getFeatureRelationshippropIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT frelprop.feature_relationshipprop_id ".
    "FROM feature f, analysisfeature af, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}


##-------------------------------------------------------------
## getFeatureRelpropPubIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getFeatureRelpropPubIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fpp.feature_relprop_pub_id ".
    "FROM feature f, analysisfeature af, feature_relationship frel, feature_relationshipprop fp, feature_relprop_pub fpp ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = fp.feature_relationship_id ".
    "AND fp.feature_relationshipprop_id = fpp.feature_relationshipprop_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getFeatureDbxrefIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getFeatureDbxrefIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fd.feature_dbxref_id ".
    "FROM feature f, analysisfeature af, feature_dbxref fd ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fd.feature_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getFeaturepropIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getFeaturepropIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fp.featureprop_id ".
    "FROM feature f, analysisfeature af, featureprop fp ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getFeaturepropPubIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getFeaturepropPubIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fpp.featureprop_pub_id ".
    "FROM feature f, analysisfeature af, featureprop fp, featureprop_pub fpp ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fpp.featureprop_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getFeatureCvtermIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getFeatureCvtermIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fc.feature_cvterm_id ".
    "FROM feature f, analysisfeature af, feature_cvterm fc ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fc.feature_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getFeatureCvtermDbxrefIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getFeatureCvtermDbxrefIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fcd.feature_cvterm_dbxref_id ".
    "FROM feature f, analysisfeature af, feature_cvterm fc, feature_cvterm_dbxref fcd ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getFeatureCvtermPubIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getFeatureCvtermPubIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fcp.feature_cvterm_pub_id ".
    "FROM feature f, analysisfeature af, feature_cvterm fc, feature_cvterm_pub fcp ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getFeatureCvtermpropIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getFeatureCvtermpropIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fcp.feature_cvtermprop_id ".
    "FROM feature f, analysisfeature af, feature_cvterm fc, feature_cvtermprop fcp ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getFeatureSynonymIdValuesForAnalysisId()
##
##-------------------------------------------------------------
sub getFeatureSynonymIdValuesForAnalysisId {

    my $self = shift;
    my ($analysis_id, $computed_by) = @_;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }
    if ($analysis_id !~ /^\d+$/){
	$self->{_logger}->logdie("analysis_id '$analysis_id' is not a numeric value");
    }
    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fs.feature_synonym_id ".
    "FROM feature f, analysisfeature af, feature_synonym fs ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fs.feature_id ";

    return $self->_get_results_ref($query, $analysis_id, $computed_by);
}

##-------------------------------------------------------------
## getAnalysispropIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getAnalysispropIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    my $query = "SELECT ap.analysisprop_id ".
    "FROM analysisprop ap, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = ap.analysis_id ";

    return $self->_get_results_ref($query, $algorithm);
}

##-------------------------------------------------------------
## getAnalysisfeatureIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getAnalysisfeatureIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT af.analysisfeature_id ".
    "FROM analysisfeature af, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.type_id = ? ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getFeatureIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getFeatureIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT f.feature_id ".
    "FROM feature f, analysisfeature af, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getFeaturelocIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getFeaturelocIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fl.featureloc_id ".
    "FROM feature f, analysisfeature af, featureloc fl, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id ) ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getFeaturePubIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getFeaturePubIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fp.feature_pub_id ".
    "FROM feature f, analysisfeature af, feature_pub fp, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getFeatureRelationshipIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getFeatureRelationshipIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT frel.feature_relationship_id ".
    "FROM feature f, analysisfeature af, feature_relationship frel, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}


##-------------------------------------------------------------
## getFeatureRelationshipPubIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getFeatureRelationshipPubIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT frelpub.feature_relationship_pub_id ".
    "FROM feature f, analysisfeature af, feature_relationship frel, feature_relationship_pub frelpub, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getFeatureRelationshippropIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getFeatureRelationshippropIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT frelprop.feature_relationshipprop_id ".
    "FROM feature f, analysisfeature af, feature_relationship frel, feature_relationshipprop frelprop, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}


##-------------------------------------------------------------
## getFeatureRelpropPubIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getFeatureRelpropPubIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fpp.feature_relprop_pub_id ".
    "FROM feature f, analysisfeature af, feature_relationship frel, feature_relationshipprop fp, feature_relprop_pub fpp, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = fp.feature_relationship_id ".
    "AND fp.feature_relationshipprop_id = fpp.feature_relationshipprop_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getFeatureDbxrefIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getFeatureDbxrefIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fd.feature_dbxref_id ".
    "FROM feature f, analysisfeature af, feature_dbxref fd, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fd.feature_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getFeaturepropIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getFeaturepropIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fp.featureprop_id ".
    "FROM feature f, analysisfeature af, featureprop fp, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getFeaturepropPubIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getFeaturepropPubIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fpp.featureprop_pub_id ".
    "FROM feature f, analysisfeature af, featureprop fp, featureprop_pub fpp, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fpp.featureprop_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getFeatureCvtermIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getFeatureCvtermIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fc.feature_cvterm_id ".
    "FROM feature f, analysisfeature af, feature_cvterm fc, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fc.feature_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getFeatureCvtermDbxrefIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getFeatureCvtermDbxrefIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fcd.feature_cvterm_dbxref_id ".
    "FROM feature f, analysisfeature af, feature_cvterm fc, feature_cvterm_dbxref fcd, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getFeatureCvtermPubIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getFeatureCvtermPubIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fcp.feature_cvterm_pub_id ".
    "FROM feature f, analysisfeature af, feature_cvterm fc, feature_cvterm_pub fcp, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getFeatureCvtermpropIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getFeatureCvtermpropIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fcp.feature_cvtermprop_id ".
    "FROM feature f, analysisfeature af, feature_cvterm fc, feature_cvtermprop fcp, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getFeatureSynonymIdValuesForAlgorithm()
##
##-------------------------------------------------------------
sub getFeatureSynonymIdValuesForAlgorithm {

    my $self = shift;
    my ($algorithm, $computed_by) = @_;

    if (!defined($algorithm)){
	$self->{_logger}->logdie("algorithm was not defined");
    }

    if (!defined($computed_by)){
	$self->{_logger}->logdie("computed_by was not defined");
    }
    if ($computed_by !~ /^\d+$/){
	$self->{_logger}->logdie("computed_by '$computed_by' is not a numeric value");
    }

    my $query = "SELECT fs.feature_synonym_id ".
    "FROM feature f, analysisfeature af, feature_synonym fs, analysis a ".
    "WHERE a.algorithm = ? ".
    "AND a.analysis_id = af.analysis_id ".
    "AND af.feature_id = f.feature_id ".
    "AND af.type_id = ? ".
    "AND f.feature_id = fs.feature_id ";

    return $self->_get_results_ref($query, $algorithm, $computed_by);
}

##-------------------------------------------------------------
## getAnalysisfeatureIdValuesForFeatureId()
##
##-------------------------------------------------------------
sub getAnalysisfeatureIdValuesForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT af.analysisfeature_id ".
    "FROM analysisfeature af, feature f ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = af.feature_id ";

    return $self->_get_results_ref($query, $feature_id);
}


##-------------------------------------------------------------
## getFeaturelocIdValuesForFeatureId()
##
##-------------------------------------------------------------
sub getFeaturelocIdValuesForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT fl.featureloc_id ".
    "FROM feature f, featureloc fl ".
    "WHERE f.feature_id = ? ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id ) ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getFeaturePubIdValuesForFeatureId()
##
##-------------------------------------------------------------
sub getFeaturePubIdValuesForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT fp.feature_pub_id ".
    "FROM feature f, feature_pub fp ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getFeatureRelationshipIdValuesForFeatureId()
##
##-------------------------------------------------------------
sub getFeatureRelationshipIdValuesForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT frel.feature_relationship_id ".
    "FROM feature f, feature_relationship frel ".
    "WHERE f.feature_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )";

    return $self->_get_results_ref($query, $feature_id);
}


##-------------------------------------------------------------
## getFeatureRelationshipPubIdValuesForFeatureId()
##
##-------------------------------------------------------------
sub getFeatureRelationshipPubIdValuesForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT frelpub.feature_relationship_pub_id ".
    "FROM feature f, feature_relationship frel, feature_relationship_pub frelpub ".
    "WHERE f.feature_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getFeatureRelationshippropIdValuesForFeatureId()
##
##-------------------------------------------------------------
sub getFeatureRelationshippropIdValuesForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT frelprop.feature_relationshipprop_id ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE f.feature_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ";

    return $self->_get_results_ref($query, $feature_id);
}


##-------------------------------------------------------------
## getFeatureRelpropPubIdValuesForFeatureId()
##
##-------------------------------------------------------------
sub getFeatureRelpropPubIdValuesForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT fpp.feature_relprop_pub_id ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop fp, feature_relprop_pub fpp ".
    "WHERE f.feature_id = ? ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = fp.feature_relationship_id ".
    "AND fp.feature_relationshipprop_id = fpp.feature_relationshipprop_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getFeatureDbxrefIdValuesForFeatureId()
##
##-------------------------------------------------------------
sub getFeatureDbxrefIdValuesForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT fd.feature_dbxref_id ".
    "FROM feature f, feature_dbxref fd ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fd.feature_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getFeaturepropIdValuesForFeatureId()
##
##-------------------------------------------------------------
sub getFeaturepropIdValuesForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT fp.featureprop_id ".
    "FROM feature f, featureprop fp ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getFeaturepropPubIdValuesForFeatureId()
##
##-------------------------------------------------------------
sub getFeaturepropPubIdValuesForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT fpp.featureprop_pub_id ".
    "FROM feature f, featureprop fp, featureprop_pub fpp ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fpp.featureprop_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getFeatureCvtermIdValuesForFeatureId()
##
##-------------------------------------------------------------
sub getFeatureCvtermIdValuesForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT fc.feature_cvterm_id ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fc.feature_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getFeatureCvtermDbxrefIdValuesForFeatureId()
##
##-------------------------------------------------------------
sub getFeatureCvtermDbxrefIdValuesForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT fcd.feature_cvterm_dbxref_id ".
    "FROM feature f, feature_cvterm fc, feature_cvterm_dbxref fcd ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getFeatureCvtermPubIdValuesForFeatureId()
##
##-------------------------------------------------------------
sub getFeatureCvtermPubIdValuesForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT fcp.feature_cvterm_pub_id ".
    "FROM feature f, feature_cvterm fc, feature_cvterm_pub fcp ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getFeatureCvtermpropIdValuesForFeatureId()
##
##-------------------------------------------------------------
sub getFeatureCvtermpropIdValuesForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT fcp.feature_cvtermprop_id ".
    "FROM feature f, feature_cvterm fc, feature_cvtermprop fcp ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getFeatureSynonymIdValuesForFeatureId()
##
##-------------------------------------------------------------
sub getFeatureSynonymIdValuesForFeatureId {

    my $self = shift;
    my ($feature_id) = @_;

    if (!defined($feature_id)){
	$self->{_logger}->logdie("feature_id was not defined");
    }
    if ($feature_id !~ /^\d+$/){
	$self->{_logger}->logdie("feature_id '$feature_id' is not a numeric value");
    }

    my $query = "SELECT fs.feature_synonym_id ".
    "FROM feature f, feature_synonym fs ".
    "WHERE f.feature_id = ? ".
    "AND f.feature_id = fs.feature_id ";

    return $self->_get_results_ref($query, $feature_id);
}

##-------------------------------------------------------------
## getFeatureIdValuesForIsObsolete()
##
##-------------------------------------------------------------
sub getFeatureIdValuesForIsObsolete {

    my $self = shift;

    my $query = "SELECT f.feature_id ".
    "FROM feature f ".
    "WHERE f.is_obsolete = 1";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getAnalysisfeatureIdValuesForIsObsolete()
##
##-------------------------------------------------------------
sub getAnalysisfeatureIdValuesForIsObsolete {

    my $self = shift;

    my $query = "SELECT af.analysisfeature_id ".
    "FROM analysisfeature af, feature f ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = af.feature_id ";

    return $self->_get_results_ref($query);
}


##-------------------------------------------------------------
## getFeaturelocIdValuesForIsObsolete()
##
##-------------------------------------------------------------
sub getFeaturelocIdValuesForIsObsolete {

    my $self = shift;

    my $query = "SELECT fl.featureloc_id ".
    "FROM feature f, featureloc fl ".
    "WHERE f._is_obsolete = 1 ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id ) ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getFeaturePubIdValuesForIsObsolete()
##
##-------------------------------------------------------------
sub getFeaturePubIdValuesForIsObsolete {

    my $self = shift;

    my $query = "SELECT fp.feature_pub_id ".
    "FROM feature f, feature_pub fp ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getFeatureRelationshipIdValuesForIsObsolete()
##
##-------------------------------------------------------------
sub getFeatureRelationshipIdValuesForIsObsolete {

    my $self = shift;

    my $query = "SELECT frel.feature_relationship_id ".
    "FROM feature f, feature_relationship frel ".
    "WHERE f._is_obsolete = 1 ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )";

    return $self->_get_results_ref($query);
}


##-------------------------------------------------------------
## getFeatureRelationshipPubIdValuesForIsObsolete()
##
##-------------------------------------------------------------
sub getFeatureRelationshipPubIdValuesForIsObsolete {

    my $self = shift;

    my $query = "SELECT frelpub.feature_relationship_pub_id ".
    "FROM feature f, feature_relationship frel, feature_relationship_pub frelpub ".
    "WHERE f._is_obsolete = 1 ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getFeatureRelationshippropIdValuesForIsObsolete()
##
##-------------------------------------------------------------
sub getFeatureRelationshippropIdValuesForIsObsolete {

    my $self = shift;

    my $query = "SELECT frelprop.feature_relationshipprop_id ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop frelprop ".
    "WHERE f._is_obsolete = 1 ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ";

    return $self->_get_results_ref($query);
}


##-------------------------------------------------------------
## getFeatureRelpropPubIdValuesForIsObsolete()
##
##-------------------------------------------------------------
sub getFeatureRelpropPubIdValuesForIsObsolete {

    my $self = shift;

    my $query = "SELECT fpp.feature_relprop_pub_id ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop fp, feature_relprop_pub fpp ".
    "WHERE f._is_obsolete = 1 ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = fp.feature_relationship_id ".
    "AND fp.feature_relationshipprop_id = fpp.feature_relationshipprop_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getFeatureDbxrefIdValuesForIsObsolete()
##
##-------------------------------------------------------------
sub getFeatureDbxrefIdValuesForIsObsolete {

    my $self = shift;

    my $query = "SELECT fd.feature_dbxref_id ".
    "FROM feature f, feature_dbxref fd ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fd.feature_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getFeaturepropIdValuesForIsObsolete()
##
##-------------------------------------------------------------
sub getFeaturepropIdValuesForIsObsolete {

    my $self = shift;

    my $query = "SELECT fp.featureprop_id ".
    "FROM feature f, featureprop fp ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getFeaturepropPubIdValuesForIsObsolete()
##
##-------------------------------------------------------------
sub getFeaturepropPubIdValuesForIsObsolete {

    my $self = shift;

    my $query = "SELECT fpp.featureprop_pub_id ".
    "FROM feature f, featureprop fp, featureprop_pub fpp ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fpp.featureprop_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getFeatureCvtermIdValuesForIsObsolete()
##
##-------------------------------------------------------------
sub getFeatureCvtermIdValuesForIsObsolete {

    my $self = shift;

    my $query = "SELECT fc.feature_cvterm_id ".
    "FROM feature f, feature_cvterm fc ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getFeatureCvtermDbxrefIdValuesForIsObsolete()
##
##-------------------------------------------------------------
sub getFeatureCvtermDbxrefIdValuesForIsObsolete {

    my $self = shift;

    my $query = "SELECT fcd.feature_cvterm_dbxref_id ".
    "FROM feature f, feature_cvterm fc, feature_cvterm_dbxref fcd ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getFeatureCvtermPubIdValuesForIsObsolete()
##
##-------------------------------------------------------------
sub getFeatureCvtermPubIdValuesForIsObsolete {

    my $self = shift;

    my $query = "SELECT fcp.feature_cvterm_pub_id ".
    "FROM feature f, feature_cvterm fc, feature_cvterm_pub fcp ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getFeatureCvtermpropIdValuesForIsObsolete()
##
##-------------------------------------------------------------
sub getFeatureCvtermpropIdValuesForIsObsolete {

    my $self = shift;

    my $query = "SELECT fcp.feature_cvtermprop_id ".
    "FROM feature f, feature_cvterm fc, feature_cvtermprop fcp ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getFeatureSynonymIdValuesForIsObsolete()
##
##-------------------------------------------------------------
sub getFeatureSynonymIdValuesForIsObsolete {

    my $self = shift;

    my $query = "SELECT fs.feature_synonym_id ".
    "FROM feature f, feature_synonym fs ".
    "WHERE f._is_obsolete = 1 ".
    "AND f.feature_id = fs.feature_id ";

    return $self->_get_results_ref($query);
}

##-------------------------------------------------------------
## getOrganismpropIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getOrganismpropIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT op.organismprop_id ".
    "FROM organismprop op, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = op.organism_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getOrganismDbxrefIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getOrganismDbxrefIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT od.organism_dbxref_id ".
    "FROM organism_dbxref od, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = od.organism_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getFeatureIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getFeatureIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT f.feature_id ".
    "FROM feature f, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getAnalysisfeatureIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getAnalysisfeatureIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT af.analysisfeature_id ".
    "FROM analysisfeature af, feature f, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = af.feature_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getFeaturelocIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getFeaturelocIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT fl.featureloc_id ".
    "FROM feature f, featureloc fl, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.feature_id ".
    "AND ( f.feature_id = fl.feature_id ".
    "OR f.feature_id = fl.srcfeature_id ) ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getFeaturePubIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getFeaturePubIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT fp.feature_pub_id ".
    "FROM feature f, feature_pub fp, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getFeatureRelationshipIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getFeatureRelationshipIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT frel.feature_relationship_id ".
    "FROM feature f, feature_relationship frel, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id )";

    return $self->_get_results_ref($query, $organism_id);
}


##-------------------------------------------------------------
## getFeatureRelationshipPubIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getFeatureRelationshipPubIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT frelpub.feature_relationship_pub_id ".
    "FROM feature f, feature_relationship frel, feature_relationship_pub frelpub, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelpub.feature_relationship_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getFeatureRelationshippropIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getFeatureRelationshippropIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT frelprop.feature_relationshipprop_id ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop frelprop, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = frelprop.feature_relationship_id ";

    return $self->_get_results_ref($query, $organism_id);
}


##-------------------------------------------------------------
## getFeatureRelpropPubIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getFeatureRelpropPubIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT fpp.feature_relprop_pub_id ".
    "FROM feature f, feature_relationship frel, feature_relationshipprop fp, feature_relprop_pub fpp, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND ( f.feature_id = frel.subject_id ".
    "OR f.feature_id = frel.object_id ) ".
    "AND frel.feature_relationship_id = fp.feature_relationship_id ".
    "AND fp.feature_relationshipprop_id = fpp.feature_relationshipprop_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getFeatureDbxrefIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getFeatureDbxrefIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT fd.feature_dbxref_id ".
    "FROM feature f, feature_dbxref fd, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = fd.feature_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getFeaturepropIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getFeaturepropIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT fp.featureprop_id ".
    "FROM feature f, featureprop fp, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = fp.feature_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getFeaturepropPubIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getFeaturepropPubIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT fpp.featureprop_pub_id ".
    "FROM feature f, featureprop fp, featureprop_pub fpp, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.featureprop_id = fpp.featureprop_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getFeatureCvtermIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getFeatureCvtermIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT fc.feature_cvterm_id ".
    "FROM feature f, feature_cvterm fc, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = fc.feature_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getFeatureCvtermDbxrefIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getFeatureCvtermDbxrefIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT fcd.feature_cvterm_dbxref_id ".
    "FROM feature f, feature_cvterm fc, feature_cvterm_dbxref fcd, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcd.feature_cvterm_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getFeatureCvtermPubIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getFeatureCvtermPubIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT fcp.feature_cvterm_pub_id ".
    "FROM feature f, feature_cvterm fc, feature_cvterm_pub fcp, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getFeatureCvtermpropIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getFeatureCvtermpropIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT fcp.feature_cvtermprop_id ".
    "FROM feature f, feature_cvterm fc, feature_cvtermprop fcp, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.feature_id = fc.feature_id ".
    "AND fc.feature_cvterm_id = fcp.feature_cvterm_id ";

    return $self->_get_results_ref($query, $organism_id);
}

##-------------------------------------------------------------
## getFeatureSynonymIdValuesForOrganismId()
##
##-------------------------------------------------------------
sub getFeatureSynonymIdValuesForOrganismId {

    my $self = shift;
    my ($organism_id) = @_;

    if (!defined($organism_id)){
	$self->{_logger}->logdie("organism_id was not defined");
    }
    if ($organism_id !~ /^\d+$/){
	$self->{_logger}->logdie("organism_id '$organism_id' is not a numeric value");
    }

    my $query = "SELECT fs.feature_synonym_id ".
    "FROM feature f, feature_synonym fs, organism o ".
    "WHERE o.organism_id = ? ".
    "AND o.organism_id = f.organism_id ".
    "AND f.organism_id = fs.organism_id ";

    return $self->_get_results_ref($query, $organism_id);
}


##-------------------------------------------------------------
## doDropForeignKeyConstraint()
##
##-------------------------------------------------------------
sub doDropForeignKeyConstraint {

    my $self = shift;
    my ($fkConstraint, $table) = @_;

    if (!defined($fkConstraint)){
	$self->{_logger}->logdie("foreign key constraint was not defined");
    }

    if (!defined($table)){
	$self->{_logger}->logdie("table was not defined");
    }

    my $sql = "ALTER TABLE $table DROP CONSTRAINT $fkConstraint ";

    return $self->_do_sql($sql);
}


##-------------------------------------------------------------
## doDropTable()
##
##-------------------------------------------------------------
sub doDropTable {

    my $self = shift;
    my ($table) = @_;

    if (!defined($table)){
	$self->{_logger}->logdie("table was not defined");
    }

    my $sql = "DROP TABLE $table ";

    $self->_do_sql($sql);
}

##-------------------------------------------------------------
## getOrgDbToAsmblId()
##
##-------------------------------------------------------------
sub getOrgDbToAsmblId {

    my $self = shift;

    my $query = "SELECT SUBSTRING(db.name,6,20), SUBSTRING(d2.accession,1,5) ".
    "FROM db, dbxref d, organism_dbxref od, organism o, cvterm c, feature f, dbxref d2 ".
    "WHERE db.name LIKE 'TIGR_%' ".
    "AND db.db_id = d.db_id ".
    "AND d.dbxref_id = od.dbxref_id ".
    "AND od.organism_id = o.organism_id ".
    "AND c.name = 'assembly' ".
    "AND c.cvterm_id = f.type_id ".
    "AND o.organism_id = f.organism_id ".
    "AND f.dbxref_id = d2.dbxref_id ";

    $self->_get_results_ref($query);
}

=item $obj->isOntologyLoaded($defaultNamespace)

B<Description:> Checks whether the ontology with the default-namespace is loaded in the CV module

B<Parameters:> $defaultNamespace - scalar

B<Returns:> TBA

=cut 

sub isOntologyLoaded {

    my $self = shift;
    my ($defaultNamespace) = @_;
    
    if (!defined($defaultNamespace)){
	$self->{_logger}->logdie("defaultNamespace was not defined");
    }

    my $query = "SELECT COUNT(*) FROM cv WHERE name = ? ";

    print "Querying database for number of cv records with namespace '$defaultNamespace'\n";

    $self->_get_results_ref($query, $defaultNamespace);
}

=item $obj->getCoreOboTermStanzaElements($defaultNamespace)

B<Description:> Retrieve the core values that are typically stored in the OBO term stanzas

B<Parameters:> $defaultNamespace - scalar

B<Returns:> Reference to double array
  
  Inner array elements are:
  0 - scalar: dbxref.accession
  1 - scalar: cvterm.name
  2 - scalar: cvterm.definition
  3 - scalar: cvterm.is_obsolete

=cut 

sub getCoreOboTermStanzaElements {

    my $self = shift;
    my ($defaultNamespace) = @_;
    
    if (!defined($defaultNamespace)){
	$self->{_logger}->logdie("defaultNamespace was not defined");
    }

    my $query = "SELECT d.accession, c.name, c.definition, c.is_obsolete ".
    "FROM cv, cvterm c, db, dbxref d ".
    "WHERE cv.name = ? ".
    "AND db.name = ? ".
    "AND cv.cv_id = c.cv_id ".
    "AND c.dbxref_id = d.dbxref_id ".
    "AND d.db_id = db.db_id ";

    print "Querying database for core Term stanza elements\n";

    $self->_get_results_ref($query, $defaultNamespace, $defaultNamespace);
}
 

=item $obj->getOboTermStanzaCrossReferences($defaultNamespace)

B<Description:> Retrieve the alt_id and xref data

B<Parameters:> $defaultNamespace - scalar

B<Returns:> Reference to double array
  
  Inner array elements are:
  0 - scalar: dbxref.accession
  1 - scalar: dbxref.version
  2 - scalar: dbxref.accession

=cut 

sub getOboTermStanzaCrossReferences {

    my $self = shift;
    my ($defaultNamespace) = @_;
    
    if (!defined($defaultNamespace)){
	$self->{_logger}->logdie("defaultNamespace was not defined");
    }

    my $query = "SELECT d1.accession, d.version, d.accession ".
    "FROM cv, cvterm c, db, dbxref d, cvterm_dbxref cd, dbxref d1 ".
    "WHERE cv.name = ? ".
    "AND db.name = ? ".
    "AND cv.cv_id = c.cv_id ".
    "AND c.cvterm_id = cd.cvterm_id ".
    "AND cd.dbxref_id = d.dbxref_id ".
    "AND c.dbxref_id = d1.dbxref_id ".
    "AND d1.db_id = db.db_id ";

    print "Querying database for all OBO term cross-references\n";

    $self->_get_results_ref($query, $defaultNamespace, $defaultNamespace);
}

=item $obj->getOboTermStanzaRelationships($defaultNamespace)

B<Description:> Retrieve the relationship data

B<Parameters:> $defaultNamespace - scalar

B<Returns:> Reference to double array
  
  Inner array elements are:
  0 - scalar: dbxref.accession
  1 - scalar: cvterm.name where cvterm.cvterm_id = cvterm_relationship.type_id
  2 - scalar: dbxref.accession

=cut 

sub getOboTermStanzaRelationships {

    my $self = shift;
    my ($defaultNamespace) = @_;
    
    if (!defined($defaultNamespace)){
	$self->{_logger}->logdie("defaultNamespace was not defined");
    }

    my $query = "SELECT d1.accession, c.name, d2.accession ".
    "FROM cv, cvterm c1, cvterm c2, db, dbxref d1, dbxref d2, cvterm_relationship crel, cvterm c ".
    "WHERE cv.name = ? ".
    "AND db.name = ? ".
    "AND cv.cv_id = c1.cv_id ".
    "AND cv.cv_id = c2.cv_id ".
    "AND c1.dbxref_id = d1.dbxref_id ".
    "AND c2.dbxref_id = d2.dbxref_id ".
    "AND c1.cvterm_id = crel.subject_id ".
    "AND c2.cvterm_id = crel.object_id ".
    "AND d1.db_id = db.db_id ".
    "AND d2.db_id = db.db_id ".
    "AND crel.type_id = c.cvterm_id ";

    print "Querying database for all OBO term relationships\n";

    $self->_get_results_ref($query, $defaultNamespace, $defaultNamespace);
}

=item $obj->getOboTermStanzaSynonyms($defaultNamespace)

B<Description:> Retrieve the synonym data

B<Parameters:> $defaultNamespace - scalar

B<Returns:> Reference to double array
  
  Inner array elements are:
  0 - scalar: dbxref.accession
  1 - scalar: cvterm.name where cvterm.cvterm_id = cvtermsynonym.type_id
  2 - scalar: cvtermsynonym.synonym

=cut 

sub getOboTermStanzaSynonyms {

    my $self = shift;
    my ($defaultNamespace) = @_;
    
    if (!defined($defaultNamespace)){
	$self->{_logger}->logdie("defaultNamespace was not defined");
    }

    my $query = "SELECT d.accession, t.name, cs.synonym ".
    "FROM cv, cvterm c, db, dbxref d, cvtermsynonym cs, cvterm t ".
    "WHERE cv.name = ? ".
    "AND db.name = ? ".
    "AND cv.cv_id = c.cv_id ".
    "AND c.dbxref_id = d.dbxref_id ".
    "AND c.cvterm_id = cs.cvterm_id ".
    "AND cs.type_id = t.cvterm_id ".
    "AND d.db_id = db.db_id ";

    print "Querying database for all OBO term synonyms\n";

    $self->_get_results_ref($query, $defaultNamespace, $defaultNamespace);
}

=item $obj->getOboTermStanzaProperties($defaultNamespace)

B<Description:> Retrieve cvtermprop data

B<Parameters:> $defaultNamespace - scalar

B<Returns:> Reference to double array
  
  Inner array elements are:
  0 - scalar: dbxref.accession
  1 - scalar: cvterm.name where cvterm.cvterm_id = cvtermprop.type_id
  2 - scalar: cvtermprop.value

=cut 

sub getOboTermStanzaProperties {

    my $self = shift;
    my ($defaultNamespace) = @_;
    
    if (!defined($defaultNamespace)){
	$self->{_logger}->logdie("defaultNamespace was not defined");
    }

    my $query = "SELECT d.accession, t.name, cp.value ".
    "FROM cv, cvterm c, db, dbxref d, cvtermprop cp, cvterm t ".
    "WHERE cv.name = ? ".
    "AND db.name = ? ".
    "AND cv.cv_id = c.cv_id ".
    "AND c.dbxref_id = d.dbxref_id ".
    "AND c.cvterm_id = cp.cvterm_id ".
    "AND cp.type_id = t.cvterm_id ".
    "AND d.db_id = db.db_id ";

    print "Querying database for all OBO term cvtermprop records\n";

    $self->_get_results_ref($query, $defaultNamespace, $defaultNamespace);
}


=item $obj->getAnalysispropDuplicateRecordCount()

B<Description:> Will retrieve the number of duplicate tuples in the analysisprop table

B<Parameters:> None

B<Returns:> Perl DBI results array reference

=cut

sub getAnalysispropDuplicateRecordCount {
    
    my $self = shift;
    
    my $query = "SELECT COUNT(p1.analysisprop_id) ".
    "FROM analysisprop p1 ".
    "WHERE EXISTS ( ".
    "SELECT 1 ".
    "FROM analysisprop p2 ".
    "WHERE p1.analysisprop_id != p2.analysisprop_id ".
    "AND p2.type_id = p1.type_id ".
    "AND p1.value = p2.value ".
    "AND p1.analysis_id = p2.analysis_id) ";
    
    $self->_get_results_ref($query);
}

=item $obj->getDbxrefpropDuplicateRecordCount()

B<Description:> Will retrieve the number of duplicate tuples in the dbxrefprop table

B<Parameters:> None

B<Returns:> Perl DBI results array reference

=cut

sub getDbxrefpropDuplicateRecordCount {
    
    my $self = shift;
    
    my $query = "SELECT COUNT(p1.dbxrefprop_id) ".
    "FROM dbxrefprop p1 ".
    "WHERE EXISTS ( ".
    "SELECT 1 ".
    "FROM dbxrefprop p2 ".
    "WHERE p1.dbxrefprop_id != p2.dbxrefprop_id ".
    "AND p2.type_id = p1.type_id ".
    "AND p1.value = p2.value ".
    "AND p1.dbxref_id = p2.dbxref_id) ";
    
    $self->_get_results_ref($query);
}


=item $obj->getFeatureCvtermpropDuplicateRecordCount()

B<Description:> Will retrieve the number of duplicate tuples in the feature_cvtermprop table

B<Parameters:> None

B<Returns:> Perl DBI results array reference

=cut

sub getFeatureCvtermpropDuplicateRecordCount {
    
    my $self = shift;
    
    my $query = "SELECT COUNT(p1.feature_cvtermprop_id) ".
    "FROM feature_cvtermprop p1 ".
    "WHERE EXISTS ( ".
    "SELECT 1 ".
    "FROM feature_cvtermprop p2 ".
    "WHERE p1.feature_cvtermprop_id != p2.feature_cvtermprop_id ".
    "AND p2.type_id = p1.type_id ".
    "AND p1.value = p2.value ".
    "AND p1.feature_cvterm_id = p2.feature_cvterm_id) ";
    
    $self->_get_results_ref($query);
}

=item $obj->getFeaturepropDuplicateRecordCount()

B<Description:> Will retrieve the number of duplicate tuples in the featureprop table

B<Parameters:> None

B<Returns:> Perl DBI results array reference

=cut

sub getFeaturepropDuplicateRecordCount {
    
    my $self = shift;
    
    my $query = "SELECT COUNT(p1.featureprop_id) ".
    "FROM featureprop p1 ".
    "WHERE EXISTS ( ".
    "SELECT 1 ".
    "FROM featureprop p2 ".
    "WHERE p1.featureprop_id != p2.featureprop_id ".
    "AND p2.type_id = p1.type_id ".
    "AND p1.value = p2.value ".
    "AND p1.feature_id = p2.feature_id) ";
    
    $self->_get_results_ref($query);
}

=item $obj->getFeatureRelationshippropDuplicateRecordCount()

B<Description:> Will retrieve the number of duplicate tuples in the feature_relationshipprop table

B<Parameters:> None

B<Returns:> Perl DBI results array reference

=cut

sub getFeatureRelationshippropDuplicateRecordCount {
    
    my $self = shift;
    
    my $query = "SELECT COUNT(p1.feature_relationshipprop_id) ".
    "FROM feature_relationshipprop p1 ".
    "WHERE EXISTS ( ".
    "SELECT 1 ".
    "FROM feature_relationshipprop p2 ".
    "WHERE p1.feature_relationshipprop_id != p2.feature_relationshipprop_id ".
    "AND p2.type_id = p1.type_id ".
    "AND p1.value = p2.value ".
    "AND p1.feature_relationship_id = p2.feature_relationship_id) ";
    
    $self->_get_results_ref($query);
}


=item $obj->getOrganismpropDuplicateRecordCount()

B<Description:> Will retrieve the number of duplicate tuples in the organismprop table

B<Parameters:> None

B<Returns:> Perl DBI results array reference

=cut

sub getOrganismpropDuplicateRecordCount {
    
    my $self = shift;
    
    my $query = "SELECT COUNT(p1.organismprop_id) ".
    "FROM organismprop p1 ".
    "WHERE EXISTS ( ".
    "SELECT 1 ".
    "FROM organismprop p2 ".
    "WHERE p1.organismprop_id != p2.organismprop_id ".
    "AND p2.type_id = p1.type_id ".
    "AND p1.value = p2.value ".
    "AND p1.organism_id = p2.organism_id) ";
    
    $self->_get_results_ref($query);
}


=item $obj->getPhylonodepropDuplicateRecordCount()

B<Description:> Will retrieve the number of duplicate tuples in the phylonodeprop table

B<Parameters:> None

B<Returns:> Perl DBI results array reference

=cut

sub getPhylonodepropDuplicateRecordCount {
    
    my $self = shift;
    
    my $query = "SELECT COUNT(p1.phylonodeprop_id) ".
    "FROM phylonodeprop p1 ".
    "WHERE EXISTS ( ".
    "SELECT 1 ".
    "FROM phylonodeprop p2 ".
    "WHERE p1.phylonodeprop_id != p2.phylonodeprop_id ".
    "AND p2.type_id = p1.type_id ".
    "AND p1.value = p2.value ".
    "AND p1.phylonode_id = p2.phylonode_id) ";
    
    $self->_get_results_ref($query);
}

=item $obj->getPubpropDuplicateRecordCount()

B<Description:> Will retrieve the number of duplicate tuples in the pubprop table

B<Parameters:> None

B<Returns:> Perl DBI results array reference

=cut

sub getPubpropDuplicateRecordCount {
    
    my $self = shift;
    
    my $query = "SELECT COUNT(p1.pubprop_id) ".
    "FROM pubprop p1 ".
    "WHERE EXISTS ( ".
    "SELECT 1 ".
    "FROM pubprop p2 ".
    "WHERE p1.pubprop_id != p2.pubprop_id ".
    "AND p2.type_id = p1.type_id ".
    "AND p1.value = p2.value ".
    "AND p1.pub_id = p2.pub_id) ";
    
    $self->_get_results_ref($query);
}

=item $obj->getFeaturelocFminGreaterThanFmaxCount()

B<Description:> Will retrieve the number of featureloc records where fmin>fmax

B<Parameters:> None

B<Returns:> Perl DBI results array reference

=cut

sub getFeaturelocFminGreaterThanFmaxCount {
    
    my $self = shift;
    
    my $query = "SELECT COUNT(featureloc_id) ".
    "FROM featureloc ".
    "WHERE fmin > fmax";
    
    $self->_get_results_ref($query);
}

=item $obj->getDistinctFeaturelocStrandValues()

B<Description:> Will retrieve all distinct strand values from featureloc

B<Parameters:> None

B<Returns:> Perl DBI results array reference

=cut

sub getDistinctFeaturelocStrandValues {
    
    my $self = shift;
    
    my $query = "SELECT distinct(strand) ".
    "FROM featureloc ".
    "WHERE strand is not null";
    
    $self->_get_results_ref($query);
}


=item $obj->getFeatureResiduesSeqlenValues()

B<Description:> Will retrieve all feature_id, uniquename, residues and seqlen values from feature

B<Parameters:> $ignore_obsolete (scalar)

B<Returns:> Perl DBI results array reference

=cut

sub getFeatureResiduesSeqlenValues {
    
    my $self = shift;
    my ($ignore_obsolete, $feature_type) = @_;

    my $query = "SELECT feature_id, uniquename, residues, seqlen ".
    "FROM feature ".
    "WHERE is_analysis = 0 ";

    if (defined($ignore_obsolete)){
	$query .= "AND is_obsolete != 1";
    }

    if (defined($feature_type)){

	my $retFeatureTypeId = $self->get_cvterm_id_from_so($feature_type);

	my $featureTypeId = $retFeatureTypeId->[0][0];

	if (!defined($featureTypeId)){
	    $self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = '$feature_type'");
	}

	"AND type_id = $featureTypeId ";
    }
    
    return $self->_get_results_ref($query);
}

=item $obj->get_cvtermpath_type_id_lookup()

B<Description:> Will execute query to retrieve all subject_id, object_id, type_id tuples from cvtermpath

B<Parameters:> None

B<Returns:> Perl DBI results array reference

=cut

sub get_cvtermpath_type_id_lookup {

    my($self) = @_;

    my $query = "SELECT convert(VARCHAR, subject_id) + '_' + convert(VARCHAR, object_id), type_id ".
    "FROM cvtermpath ";

    print "Retrieving all subject_id, object_id, type_id tuples from cvtermpath\n";    

    return $self->_get_lookup_db($query);

}

=item $obj->getClusterAnalysisIdValues()

B<Description:> Retrieve analysis_id values for all analysis records where the program is j_ortholog_clusters or jaccard

B<Parameters:> None

B<Returns:> Perl DBI results array reference

=cut

sub getClusterAnalysisIdValues {

    my($self) = @_;

    my $query = "SELECT analysis_id ".
    "FROM analysis ".
    "WHERE program = 'j_ortholog_clusters' ".
    "OR program = 'jaccard' ".
    "ORDER BY analysis_id ";

    print "Retrieving all analysis_id values where program is jaccard or j_ortholog_clusters\n";    

    return $self->_get_results_ref($query);

}

=item $obj->getBlastAnalysisIdValues()

B<Description:> Retrieve analysis_id values for all analysis records where the program is like blast

B<Parameters:> None

B<Returns:> Perl DBI results array reference

=cut

sub getBlastAnalysisIdValues {

    my($self) = @_;

    my $query = "SELECT analysis_id ".
    "FROM analysis ".
    "WHERE program like '%blast%' ".
    "ORDER BY analysis_id ";

    print "Retrieving all analysis_id values where program is like blast\n";    

    return $self->_get_results_ref($query);

}

=item $obj->getBlastRecordsForCmBlastByAnalysisId()

B<Description:> Retrieve 

B<Parameters:> $analysis_id (scalar)

B<Returns:> Perl DBI results array reference

=cut

sub getBlastRecordsForCmBlastByAnalysisId {

    my $self = shift;
    my ($analysis_id, $start, $end) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }

    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match', 'SO');
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match'");
    }

    my $query = "SELECT query.feature_id, query.organism_id, hit.feature_id, hit.organism_id, match.feature_id ".
#    my $query = "SELECT TOP 10 query.feature_id, query.organism_id, hit.feature_id, hit.organism_id, match.feature_id ".
    "FROM feature match, feature query, feature hit, featureloc q2mfl, featureloc h2mfl, analysisfeature af ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = match.feature_id ".
    "AND q2mfl.srcfeature_id = query.feature_id ".
    "AND q2mfl.feature_id = match.feature_id ".
    "AND q2mfl.rank = 0 ". 
    "AND h2mfl.srcfeature_id = hit.feature_id ".
    "AND h2mfl.feature_id = match.feature_id ".
    "AND h2mfl.rank = 1 ".
    "AND match.type_id = ? ";

    if ((defined($start)) && (defined($end))){
	$query .= "AND match.feature_id BETWEEN ? AND ? ";
	return $self->_get_results_ref($query, $analysis_id, $matchCvtermId, $start, $end);
    }
    else {
	return $self->_get_results_ref($query, $analysis_id, $matchCvtermId);
    }
}

=item $obj->getMatchFeatureIdValuesForCmBlastByAnalysisId()

B<Description:> Retrieve 

B<Parameters:> $analysis_id (scalar)

B<Returns:> Perl DBI results array reference

=cut

sub getMatchFeatureIdValuesForCmBlastByAnalysisId {

    my $self = shift;
    my ($analysis_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }

    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match', 'SO');
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match'");
    }

    my $query = "SELECT match.feature_id ".
    "FROM feature match, feature query, feature hit, featureloc q2mfl, featureloc h2mfl, analysisfeature af ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = match.feature_id ".
    "AND q2mfl.srcfeature_id = query.feature_id ".
    "AND q2mfl.feature_id = match.feature_id ".
    "AND q2mfl.rank = 0 ". 
    "AND h2mfl.srcfeature_id = hit.feature_id ".
    "AND h2mfl.feature_id = match.feature_id ".
    "AND h2mfl.rank = 1 ".
    "AND match.type_id = ? ";

    return $self->_get_results_ref($query, $analysis_id, $matchCvtermId);
}


=item $obj->getStatisticsForCmBlastByAnalysisId()

B<Description:> Retrieve percent_identity, percent_similarity, p_value for all match_part features linked to some blast analysis_id

B<Parameters:> $analysis_id (scalar), $start (scalar), $end (scalar)

B<Returns:> Perl DBI results array reference

=cut

sub getStatisticsForCmBlastByAnalysisId {

    my $self = shift;
    my ($analysis_id, $start, $end) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }

    my $percentSimilarityCvtermId = $self->getCvtermIdByTermNameByOntology('percent_similarity', 'output.ontology');
    if (!defined($percentSimilarityCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'percent_similarity'");
    }

    my $pValueCvtermId = $self->getCvtermIdByTermNameByOntology('p_value', 'output.ontology');
    if (!defined($pValueCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'p_value'");
    }

    my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part', 'SO');
    if (!defined($matchPartCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part'");
    }

    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match', 'SO');
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match'");
    }

#    my $query = "SELECT match.feature_id, af.pidentity, percsim.value, pval.value ".
    my $query = "SELECT TOP 1000 match.feature_id, af.pidentity, percsim.value, pval.value ".
#    my $query = "SELECT count(match.feature_id) ".
    "FROM feature match_part, feature match, analysisfeature af, feature_relationship frel, featureprop percsim, featureprop pval ".
    "WHERE match_part.feature_id = af.feature_id ".
    "AND frel.subject_id = match_part.feature_id ".
    "AND frel.object_id = match.feature_id ".
    "AND percsim.feature_id = match_part.feature_id ".
    "AND percsim.type_id = ? ".
    "AND pval.feature_id = match_part.feature_id ".
    "AND pval.type_id = ? ".
    "AND pval.rank = 0 ".
    "AND af.analysis_id = ? ".
    "AND match_part.type_id = ? ".
    "AND match.type_id = ? ";

    if ((defined($start)) && (defined($end))){
	$query .= "AND match.feature_id BETWEEN ? AND ? ";
#	$self->{_logger}->warn("Retrieving data for match feature with feature_id '$matchFeatureId'");
	return $self->_get_results_ref($query, $percentSimilarityCvtermId, 
				       $pValueCvtermId, $analysis_id, 
				       $matchPartCvtermId, $matchCvtermId,
				       $start, $end);
    }
    else {
	$query .= "GROUP BY match.feature_id ";
	return $self->_get_results_ref($query, $percentSimilarityCvtermId, 
				       $pValueCvtermId, $analysis_id, 
				       $matchPartCvtermId, $matchCvtermId);

    }

#     $query = "SELECT match.feature_id, af.pidentity, percsim.value, pval.value ".
#     "FROM feature match_part, feature match, analysisfeature af, feature_relationship frel, featureprop percsim, featureprop pval ".
#     "WHERE match_part.feature_id = af.feature_id ".
#     "AND frel.subject_id = match_part.feature_id ".
#     "AND frel.object_id = match.feature_id ".
#     "AND percsim.feature_id = match_part.feature_id ".
#     "AND percsim.type_id = $percentSimilarityCvtermId ".
#     "AND pval.feature_id = match_part.feature_id ".
#     "AND pval.type_id = $pValueCvtermId ".
#     "AND pval.rank = 0 ".
#     "AND af.analysis_id = $analysis_id ".
#     "AND match_part.type_id = $matchPartCvtermId ".
#     "AND match.type_id = $matchCvtermId ".
#     "AND match.feature_id = $matchFeatureId ";

#     die "$query";


}

=item $obj->getStatisticsForCmBlastByAnalysisId1()

B<Description:> Retrieve percent_identity, percent_similarity, p_value for all match_part features linked to some blast analysis_id

B<Parameters:> $analysis_id (scalar), $matchFeatureId (scalar)

B<Returns:> Perl DBI results array reference

=cut

sub getStatisticsForCmBlastByAnalysisId1 {

    my $self = shift;
    my ($analysis_id, $matchFeatureId) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }

    my $percentSimilarityCvtermId = $self->getCvtermIdByTermNameByOntology('percent_similarity', 'output.ontology');
    if (!defined($percentSimilarityCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'percent_similarity'");
    }

    my $pValueCvtermId = $self->getCvtermIdByTermNameByOntology('p_value', 'output.ontology');
    if (!defined($pValueCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'p_value'");
    }

    my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part', 'SO');
    if (!defined($matchPartCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part'");
    }

    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match', 'SO');
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match'");
    }

    my $query = "SELECT match.feature_id, af.pidentity, percsim.value, pval.value ".
    "FROM feature match_part, feature match, analysisfeature af, feature_relationship frel, featureprop percsim, featureprop pval ".
    "WHERE match_part.feature_id = af.feature_id ".
    "AND frel.subject_id = match_part.feature_id ".
    "AND frel.object_id = match.feature_id ".
    "AND percsim.feature_id = match_part.feature_id ".
    "AND percsim.type_id = ? ".
    "AND pval.feature_id = match_part.feature_id ".
    "AND pval.type_id = ? ".
    "AND pval.rank = 0 ".
    "AND af.analysis_id = ? ".
    "AND match_part.type_id = ? ".
    "AND match.type_id = ? ";

    if (defined($matchFeatureId)){
	$query .= "AND match.feature_id = $matchFeatureId ";
	$self->{_logger}->warn("Retrieving data for match feature with feature_id '$matchFeatureId'");
    }
    else {
	$query .= "GROUP BY match.feature_id ";
    }

#     $query = "SELECT match.feature_id, af.pidentity, percsim.value, pval.value ".
#     "FROM feature match_part, feature match, analysisfeature af, feature_relationship frel, featureprop percsim, featureprop pval ".
#     "WHERE match_part.feature_id = af.feature_id ".
#     "AND frel.subject_id = match_part.feature_id ".
#     "AND frel.object_id = match.feature_id ".
#     "AND percsim.feature_id = match_part.feature_id ".
#     "AND percsim.type_id = $percentSimilarityCvtermId ".
#     "AND pval.feature_id = match_part.feature_id ".
#     "AND pval.type_id = $pValueCvtermId ".
#     "AND pval.rank = 0 ".
#     "AND af.analysis_id = $analysis_id ".
#     "AND match_part.type_id = $matchPartCvtermId ".
#     "AND match.type_id = $matchCvtermId ".
#     "AND match.feature_id = $matchFeatureId ";

#     die "$query";

    return $self->_get_results_ref($query, $percentSimilarityCvtermId, $pValueCvtermId, $analysis_id, $matchPartCvtermId, $matchCvtermId);
}

=item $obj->getPercentSimilarityForCmBlastByAnalysisId()

B<Description:> Retrieve percent_identity for all match_part features linked to some blast analysis_id

B<Parameters:> $analysis_id (scalar), $matchFeatureId (scalar)

B<Returns:> Perl DBI results array reference

=cut

sub getPercentSimilarityForCmBlastByAnalysisId {

    my $self = shift;
    my ($analysis_id, $matchFeatureId) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }

    my $percentSimilarityCvtermId = $self->getCvtermIdByTermNameByOntology('percent_similarity', 'output.ontology');
    if (!defined($percentSimilarityCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'percent_similarity'");
    }

    my $pValueCvtermId = $self->getCvtermIdByTermNameByOntology('p_value', 'output.ontology');
    if (!defined($pValueCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'p_value'");
    }

    my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part', 'SO');
    if (!defined($matchPartCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part'");
    }

    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match', 'SO');
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match'");
    }

    my $query = "SELECT match.feature_id, percsim.value ".
    "FROM feature match_part, feature match, analysisfeature af, feature_relationship frel, featureprop percsim, featureprop pval ".
    "WHERE match_part.feature_id = af.feature_id ".
    "AND frel.subject_id = match_part.feature_id ".
    "AND frel.object_id = match.feature_id ".
    "AND percsim.feature_id = match_part.feature_id ".
    "AND percsim.type_id = ? ".
    "AND pval.feature_id = match_part.feature_id ".
    "AND pval.type_id = ? ".
    "AND pval.rank = 0 ".
    "AND af.analysis_id = ? ".
    "AND match_part.type_id = ? ".
    "AND match.type_id = ? ";

    if (defined($matchFeatureId)){
	$query .= "AND match.feature_id = $matchFeatureId ";
	$self->{_logger}->warn("Retrieving data for match feature with feature_id '$matchFeatureId'");
    }
    else {
	$query .= "GROUP BY match.feature_id ";
    }


    return $self->_get_lookup_db($query, $percentSimilarityCvtermId, $pValueCvtermId, $analysis_id, $matchPartCvtermId, $matchCvtermId);
}

=item $obj->getPercentIdentityForCmBlastByAnalysisId()

B<Description:> Retrieve percent_identity for all match_part features linked to some blast analysis_id

B<Parameters:> $analysis_id (scalar), $matchFeatureId (scalar)

B<Returns:> Perl DBI results array reference

=cut

sub getPercentIdentityForCmBlastByAnalysisId {

    my $self = shift;
    my ($analysis_id, $matchFeatureId) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }

    my $percentSimilarityCvtermId = $self->getCvtermIdByTermNameByOntology('percent_similarity', 'output.ontology');
    if (!defined($percentSimilarityCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'percent_similarity'");
    }

    my $pValueCvtermId = $self->getCvtermIdByTermNameByOntology('p_value', 'output.ontology');
    if (!defined($pValueCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'p_value'");
    }

    my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part', 'SO');
    if (!defined($matchPartCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part'");
    }

    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match', 'SO');
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match'");
    }

    my $query = "SELECT match.feature_id, af.pidentity ".
    "FROM feature match_part, feature match, analysisfeature af, feature_relationship frel, featureprop percsim, featureprop pval ".
    "WHERE match_part.feature_id = af.feature_id ".
    "AND frel.subject_id = match_part.feature_id ".
    "AND frel.object_id = match.feature_id ".
    "AND percsim.feature_id = match_part.feature_id ".
    "AND percsim.type_id = ? ".
    "AND pval.feature_id = match_part.feature_id ".
    "AND pval.type_id = ? ".
    "AND pval.rank = 0 ".
    "AND af.analysis_id = ? ".
    "AND match_part.type_id = ? ".
    "AND match.type_id = ? ";

    if (defined($matchFeatureId)){
	$query .= "AND match.feature_id = $matchFeatureId ";
	$self->{_logger}->warn("Retrieving data for match feature with feature_id '$matchFeatureId'");
    }
    else {
	$query .= "GROUP BY match.feature_id ";
    }

    return $self->_get_lookup_db($query, $percentSimilarityCvtermId, $pValueCvtermId, $analysis_id, $matchPartCvtermId, $matchCvtermId);
}

=item $obj->getPValueForCmBlastByAnalysisId()

B<Description:> Retrieve p_value for all match_part features linked to some blast analysis_id

B<Parameters:> $analysis_id (scalar), $matchFeatureId (scalar)

B<Returns:> Perl DBI results array reference

=cut

sub getPValueForCmBlastByAnalysisId {

    my $self = shift;
    my ($analysis_id, $matchFeatureId) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($analysis_id)){
	$self->{_logger}->logdie("analysis_id was not defined");
    }

    my $percentSimilarityCvtermId = $self->getCvtermIdByTermNameByOntology('percent_similarity', 'output.ontology');
    if (!defined($percentSimilarityCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'percent_similarity'");
    }

    my $pValueCvtermId = $self->getCvtermIdByTermNameByOntology('p_value', 'output.ontology');
    if (!defined($pValueCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'p_value'");
    }

    my $matchPartCvtermId = $self->getCvtermIdByTermNameByOntology('match_part', 'SO');
    if (!defined($matchPartCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match_part'");
    }

    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match', 'SO');
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match'");
    }

    my $query = "SELECT match.feature_id, pval.value ".
    "FROM feature match_part, feature match, analysisfeature af, feature_relationship frel, featureprop percsim, featureprop pval ".
    "WHERE match_part.feature_id = af.feature_id ".
    "AND frel.subject_id = match_part.feature_id ".
    "AND frel.object_id = match.feature_id ".
    "AND percsim.feature_id = match_part.feature_id ".
    "AND percsim.type_id = ? ".
    "AND pval.feature_id = match_part.feature_id ".
    "AND pval.type_id = ? ".
    "AND pval.rank = 0 ".
    "AND af.analysis_id = ? ".
    "AND match_part.type_id = ? ".
    "AND match.type_id = ? ";

    if (defined($matchFeatureId)){
	$query .= "AND match.feature_id = $matchFeatureId ";
	$self->{_logger}->warn("Retrieving data for match feature with feature_id '$matchFeatureId'");
    }
    else {
	$query .= "GROUP BY match.feature_id ";
    }

    return $self->_get_lookup_db($query, $percentSimilarityCvtermId, $pValueCvtermId, $analysis_id, $matchPartCvtermId, $matchCvtermId);
}


=item $obj->getGenusAndSpeciesByUniquename()

B<Description:> Retrieve the organism.genus and organism.species given a feature.uniquename value

B<Parameters:> $id (scalar)

B<Returns:> Perl DBI results array reference

=cut

sub getGenusAndSpeciesByUniquename {

    my $self = shift;
    my ($id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($id)){
	$self->{_logger}->logdie("id was not defined");
    }


    my $query = "SELECT o.genus, o.species ".
    "FROM feature f, organism o ".
    "WHERE f.uniquename = ? ".
    "AND f.organism_id = o.organism_id ";

    return $self->_get_results_ref($query, $id);
}

=item $obj->getFeaturePropertiesByUniquename()

B<Description:> Retrieve all cvterm.name and the featureprop.value values given a feature.uniquename value

B<Parameters:> $id (scalar)

B<Returns:> Perl DBI results array reference

=cut

sub getFeaturePropertiesByUniquename {

    my $self = shift;
    my ($id) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($id)){
	$self->{_logger}->logdie("id was not defined");
    }


    my $query = "SELECT c.name, fp.value ".
    "FROM feature f, featureprop fp, cvterm c ".
    "WHERE f.uniquename = ? ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.type_id = c.cvterm_id ";

    return $self->_get_results_ref($query, $id);
}


=item $obj->getCmClusterMembersLookup($memCount, $organismCount, $jocId)

B<Description:> 

B<Parameters:> $memCount (scalar), $organismCount (scalar), $jocId (scalar)

B<Returns:> Perl DBI results array reference

=cut

sub getCmClusterMembersLookup {

    my $self = shift;
    my ($memCount, $organismCount, $jocId) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($memCount)){
	$self->{_logger}->logdie("memCount was not defined");
    }
    if (!defined($organismCount)){
	$self->{_logger}->logdie("organismCount was not defined");
    }
    if (!defined($jocId)){
	$self->{_logger}->logdie("jocId was not defined");
    }
	
    my $query = "SELECT cm.cluster_id, cm.feature_id ".
    "FROM cm_cluster_members cm, cm_clusters c ".
    "WHERE c.analysis_id = ? ".
    "AND c.num_members >= ? ".
    "AND c.num_organisms = ? ".
    "AND c.cluster_id = cm.cluster_id ";   

    print STDOUT "Retrieving data from cm_cluster_members where analysis_id = '$jocId', num_members = '$memCount', num_organism = '$organismCount'\n";

    return $self->_get_results_ref($query, $jocId, $memCount, $organismCount);
}

=item $obj->getCmBlastLookup($cutoff)

B<Description:> 

B<Parameters:> $cutoff (scalar)

B<Returns:> Perl DBI results array reference

=cut

sub getCmBlastLookup {

    my $self = shift;
    my ($cutoff) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($cutoff)){
	$self->{_logger}->logdie("cutoff was not defined");
    }
    
    my $query = "SELECT cb.qfeature_id, cb.hfeature_id, cb.p_value, cb.horganism_id ".
    "FROM cm_blast cb ".
    "WHERE cb.qfeature_id != cb.hfeature_id ".
    "AND cb.qorganism_id != cb.horganism_id ".
    "AND cb.p_value <= ? ".
    "ORDER BY cb.p_value ";
    
    print STDOUT "Retrieving data from cm_blast where p_value <= '$cutoff'\n";

    return $self->_get_results_ref($query, $cutoff);
}

=item $obj->getCmBlastByOrganismLookup($cutoff)

B<Description:> 

B<Parameters:> $cutoff (scalar)

B<Returns:> Perl DBI results array reference

=cut

sub getCmBlastByOrganismLookup {

    my $self = shift;
    my ($cutoff) = @_;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if (!defined($cutoff)){
	$self->{_logger}->logdie("cutoff was not defined");
    }
    
    my $query = "SELECT qorganism_id, qfeature_id, horganism_id, hfeature_id, per_id ".
    "FROM cm_blast ".
    "WHERE qfeature_id != hfeature_id ".
    "AND qorganism_id != horganism_id ".
    "AND p_value <= ? ".
#    "GROUP BY qorganism_id, qfeature_id ".
    "ORDER BY p_value ";
    
    print STDOUT "Retrieving data from cm_blast by organism where p_value <= '$cutoff'\n";

    return $self->_get_results_ref($query, $cutoff);
}

=item $obj->getLineageSpecificAnalysisProteinInfo()

B<Description:> 

B<Parameters:> none

B<Returns:> Perl DBI results array reference

=cut

sub getLineageSpecificAnalysisProteinInfo {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    

    my $query = "SELECT cp.protein_id, cp.uniquename, d1.accession, d2.accession, cp.gene_product_name, gene.seqlen, protein.seqlen, cp.exon_count ".
    "FROM cm_proteins cp, feature gene, feature protein, dbxref d1, dbxref d2, feature_dbxref fd1, feature_dbxref fd2 ".
    "WHERE cp.protein_id = protein.feature_id ".
    "AND cp.gene_id = gene.feature_id ".
    "AND cp.protein_id = fd1.feature_id ".
    "AND fd1.dbxref_id = d1.dbxref_id ".
    "AND d1.version = 'feat_name' ".
    "AND cp.protein_id = fd2.feature_id ".
    "AND fd2.dbxref_id = d2.dbxref_id ".
    "AND d2.version = 'pub_locus' ";

    print STDOUT "Retrieving lineage specific analysis protein info\n";

    return $self->_get_results_ref($query);
}

=item $obj->getParalogCountLookup()

B<Description:> 

B<Parameters:> none

B<Returns:> Perl DBI results array reference

=cut

sub getParalogCountLookup {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    

    my $query = "SELECT qfeature_id, count(hfeature_id) ".
    "FROM cm_blast ".
    "WHERE qfeature_id != hfeature_id ".
    "AND qorganism_id = horganism_id ".
    "GROUP BY qfeature_id ";

    print STDOUT "Retrieving paralog counts from cm_blast\n";

    return $self->_get_results_ref($query);
}

=item $obj->getSameSpeciesParalogCountLookup()

B<Description:> 

B<Parameters:> none

B<Returns:> Perl DBI results array reference

=cut

sub getSameSpeciesParalogCountLookup {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    

    my $query = "SELECT qfeature_id, count(hfeature_id) ".
    "FROM cm_blast ".
    "WHERE qfeature_id != hfeature_id ".
    "AND qorganism_id = horganism_id ".
    "GROUP BY qfeature_id ";

    print STDOUT "Retrieving same species paralog counts from cm_blast\n";

    return $self->_get_results_ref($query);
}


=item $obj->getOrganismLookup()

B<Description:> 

B<Parameters:> none

B<Returns:> Perl DBI results array reference

=cut

sub getOrganismLookup {

    my $self = shift;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;
    
    my $query = "SELECT organism_id, genus, species ".
    "FROM organism ".
    "WHERE genus ! = 'not known' ";

    print STDOUT "Retrieving organism_id, genus, species from organism\n";

    return $self->_get_results_ref($query);
}

=item $obj->getUniquenameToFeatureIdLookup()

B<Description:> Retrieve the uniquename and feature_id tuples from feature table

B<Parameters:> $args{no_obsolete} (scalar - unsigned integer)

B<Returns:> Perl DBI results array reference

=cut

sub getUniquenameToFeatureIdLookup {

    my $self = shift;
    my (%args) = @_;
    
    my $query = "SELECT uniquename, feature_id ".
    "FROM feature ".
    "WHERE is_obsolete = 0 ";

    print STDOUT "Retrieving uniquename and feature_id from feature\n";

    return $self->_get_results_ref($query);
}

sub getGeneCounts {

    my $self = shift;

    my $query = "SELECT count(f.feature_id) ".
    "FROM feature f, cvterm c ".
    "WHERE f.type_id = c.cvterm_id ".
    "AND lower(c.name) = 'gene' ";

    return $self->_get_results_ref($query);
}

sub getTranscriptCounts {

    my $self = shift;

    my $query = "SELECT count(f.feature_id) ".
    "FROM feature f, cvterm c ".
    "WHERE f.type_id = c.cvterm_id ".
    "AND lower(c.name) = 'transcript' ";

    return $self->_get_results_ref($query);
}

sub getCDSCounts {

    my $self = shift;

    my $query = "SELECT count(f.feature_id) ".
    "FROM feature f, cvterm c ".
    "WHERE f.type_id = c.cvterm_id ".
    "AND lower(c.name) = 'cds' ";

    return $self->_get_results_ref($query);
}

sub getExonCounts {

    my $self = shift;

    my $query = "SELECT count(f.feature_id) ".
    "FROM feature f, cvterm c ".
    "WHERE f.type_id = c.cvterm_id ".
    "AND lower(c.name) = 'exon' ";

    return $self->_get_results_ref($query);
}


sub getDbxrefRecordsForCmProteins2 {

    my ($self) = @_;

    ## This version of getDbxrefRecordsForCmProteins eliminates the use of 'distinct'
    ## in the select syntax.  The duplicate tuples will be removed on the client side.

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    my $retPolypeptideCvtermId = $self->get_cvterm_id_from_so('polypeptide');
    my $polypeptideCvtermId = $retPolypeptideCvtermId->[0][0];
    if (!defined($polypeptideCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'polypeptide'");
    }
    my $retTranscriptCvtermId = $self->get_cvterm_id_from_so('transcript');
    my $transcriptCvtermId = $retTranscriptCvtermId->[0][0];
    if (!defined($transcriptCvtermId)){
        $self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'transcript'");
    }

    ## We do not guarantee which version of dbxref will be retrieved e.g.: 
    ## current, locus, display_locus, feat_name.

    # Pulling the the dbxrefs off of the transcript feature
    my $query = "SELECT protein.feature_id, d.version, db.name + ':' + d.accession ".
    "FROM feature protein, feature transcript, feature_relationship fr, dbxref d, db db, feature_dbxref fd ".
    "WHERE protein.type_id = ? ".
    "AND transcript.type_id = ? ".
    "AND protein.feature_id=fr.subject_id ".
    "AND transcript.feature_id=fr.object_id ".
    "AND transcript.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = d.dbxref_id ".
    "AND d.db_id = db.db_id ".
    "AND protein.is_analysis = 0 ".
    "AND protein.is_obsolete = 0 ";
    
    my $trans_results = $self->_get_results_ref($query, $polypeptideCvtermId, $transcriptCvtermId);

    # Pulling the the dbxrefs off of the gene feature
    my $query = "SELECT protein.feature_id, d.version, db.name + ':' + d.accession ".
    "FROM feature protein, feature transcript, feature_relationship fr, feature_relationship fr2, feature g, dbxref d, db db, feature_dbxref fd ".
    "WHERE protein.type_id = ? ".
    "AND transcript.type_id = ? ".
    "AND protein.feature_id=fr.subject_id ".
    "AND transcript.feature_id=fr.object_id ".
    "AND transcript.feature_id=fr2.subject_id ".
    "AND g.feature_id = fr2.object_id ".
    "AND g.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = d.dbxref_id ".
    "AND d.db_id = db.db_id ".
    "AND protein.is_analysis = 0 ".
    "AND protein.is_obsolete = 0 ";

    my $gene_results = $self->_get_results_ref($query, $polypeptideCvtermId, $transcriptCvtermId);

    my @all_results = (@$trans_results,@$gene_results);
    
    return \@all_results;
}

 
sub getFeatureCountByFeatureType {

    my $self = shift;
    my ($featureType) = @_;

    my $ret = $self->get_cvterm_id_from_so($featureType);
    my $cvterm_id = $ret->[0][0];
    if (!defined($cvterm_id)){
	$self->{_logger}->logdie("cvterm_id was not defined ".
				 "for cvterm.name = '$featureType'");
    }

    my $query = "SELECT COUNT(type_id) ".
    "FROM feature ".
    "WHERE type_id = ? ";
    
    return $self->_get_results_ref($query, $cvterm_id);
}

sub getPolypeptideData {

    my $self = shift;

    my $ret = $self->get_cvterm_id_from_so('polypeptide');
    my $cvterm_id = $ret->[0][0];
    if (!defined($cvterm_id)){
	$self->{_logger}->logdie("cvterm_id was not defined ".
				 "for cvterm.name = 'polypeptide'");
    }

    my $query = "SELECT f.feature_id, f.uniquename, fl.fmin, fl.fmax, fl.strand, fl.srcfeature_id ".
    "FROM feature f, featureloc fl ".
    "WHERE f.type_id = ? ".
    "AND f.feature_id = fl.feature_id ";
    
    return $self->_get_results_ref($query, $cvterm_id);
}


sub getEpitopeFeatureIds {

    my $self = shift;

    my $ret = $self->get_cvterm_id_from_so('epiPEP');
    my $cvterm_id = $ret->[0][0];
    if (!defined($cvterm_id)){
	$self->{_logger}->logdie("cvterm_id was not defined ".
				 "for cvterm.name = 'epiPEP'");
    }

    my $query = "SELECT uniquename, feature_id ".
    "FROM feature f ".
    "WHERE f.type_id = ? ";
    
    return $self->_get_results_ref($query, $cvterm_id);
}

sub getPolypeptideFeatureIds {

    my $self = shift;

    my $ret = $self->get_cvterm_id_from_so('polypeptide');
    my $cvterm_id = $ret->[0][0];
    if (!defined($cvterm_id)){
	$self->{_logger}->logdie("cvterm_id was not defined ".
				 "for cvterm.name = 'polypeptide'");
    }

    my $query = "SELECT uniquename, feature_id ".
    "FROM feature f ".
    "WHERE f.type_id = ? ";
    
    return $self->_get_results_ref($query, $cvterm_id);
}


sub getEpitopeCVRecords {

    my $self = shift;

    my $query = "SELECT name, cvterm_id ".
    "FROM cvterm ".
    "WHERE name in ('MHC Allele', 'PMID', ".
    "'MHC Quantitative Binding Assay Result', ".
    "'MHC Qualitative Binding Assay Result', ".
    "'MHC Allele Class', ".
    "'Assay Group', ".
    "'Assay Type') ";
    
    return $self->_get_results_ref($query);
}

sub getFeatureCount {

    my $self = shift;
    my $query = "SELECT COUNT(*) FROM feature";
    return $self->_get_results_ref($query);
}

sub getFeatureRelationshipsCount {

    my $self = shift;
    my $query = "SELECT COUNT(*) FROM feature_relationship";
    return $self->_get_results_ref($query);
}

sub getFeatureLocalizationsCount {

    my $self = shift;
    my $query = "SELECT COUNT(*) FROM featureloc";
    return $self->_get_results_ref($query);
}

sub getFeaturesByCount {

    my $self = shift;

    my $query = "SELECT c.name, count(f.type_id) ".
    "FROM feature f, cvterm c ".
    "WHERE f.type_id = c.cvterm_id ".
    "GROUP BY c.name ";

    return $self->_get_results_ref($query);
}

sub getAnalysisCount {

    my $self = shift;
    my $query = "SELECT COUNT(*) FROM analysis";

    return $self->_get_results_ref($query);
}

sub getFeatureIdentifiers {

    my $self = shift;
    my $query = "SELECT feature_id FROM feature";

    return $self->_get_results_ref($query);
}

sub getFeatureIdentifiersByRefSequence {

    my $self = shift;
    my ($refseq) = @_;

    if (!defined($refseq)){
	$self->{_logger}->logdie("refseq was not defined");
    }

    my $query = "SELECT f.uniquename ".
    "FROM feature f, featureloc fl, feature ref ".
    "WHERE f.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = ref.feature_id ".
    "AND ref.uniquename = ? ";

    return $self->_get_results_ref($query,$refseq);
}

sub getModelFeatureProperties {

    my $self = shift;
    my ($feat_name) = @_;
    if (!defined($feat_name)){
	$self->{_logger}->logdie("feat_name was not defined");
    }

    my $query = "SELECT substring(c.name,1,50), fp.value ".
    "FROM featureprop fp, feature f, feature_dbxref fd, cvterm c, dbxref d ".
    "WHERE d.accession = ? ".
    "AND d.version = 'feat_name' ".
    "AND d.dbxref_id = fd.dbxref_id ".
    "AND fd.feature_id = f.feature_id ".
    "AND f.feature_id = fp.feature_id ".
    "AND fp.type_id = c.cvterm_id ";
    
    return $self->_get_results_ref($query, $feat_name);

}

sub getModelFeatureGeneProductName {

    my $self = shift;
    my ($feat_name) = @_;
    if (!defined($feat_name)){
	$self->{_logger}->logdie("feat_name was not defined");
    }

    my $query = "SELECT fp.value ".
    "FROM featureprop fp, feature cds, feature_dbxref fd, cvterm c, dbxref d, feature_relationship frel, feature transcript, cvterm c2, cvterm ccds ".
    "WHERE ccds.name = 'CDS' ".
    "AND ccds.cvterm_id = cds.type_id ".
    "AND d.accession = ? ".
    "AND d.version = 'feat_name' ".
    "AND d.dbxref_id = fd.dbxref_id ".
    "AND fd.feature_id = cds.feature_id ".
    "AND fp.type_id = c.cvterm_id ".
    "AND c.name = 'gene_product_name' ".
    "AND cds.feature_id = frel.subject_id ".
    "AND frel.object_id = transcript.feature_id ".
    "AND transcript.type_id = c2.cvterm_id ".
    "AND c2.name = 'transcript' ".
    "AND transcript.feature_id = fp.feature_id ";
    
    return $self->_get_results_ref($query, $feat_name);
}

sub getModelExons {

    my $self = shift;
    my ($feat_name) = @_;
    if (!defined($feat_name)){
	$self->{_logger}->logdie("feat_name was not defined");
    }

    my $query = "SELECT d2.accession, fl.fmin, fl.fmax ".
    "FROM feature cds, feature_dbxref fd, dbxref d, feature_relationship frel, feature transcript, cvterm c2, cvterm ccds, feature_relationship frel2, feature exon, cvterm ce, feature_dbxref fd2, dbxref d2, featureloc fl ".
    "WHERE ccds.name = 'CDS' ".
    "AND ce.name = 'exon' ".
    "AND ce.cvterm_id = exon.type_id ".
    "AND ccds.cvterm_id = cds.type_id ".
    "AND d.accession = ? ".
    "AND d.version = 'feat_name' ".
    "AND d.dbxref_id = fd.dbxref_id ".
    "AND fd.feature_id = cds.feature_id ".
    "AND cds.feature_id = frel.subject_id ".
    "AND frel.object_id = transcript.feature_id ".
    "AND transcript.type_id = c2.cvterm_id ".
    "AND c2.name = 'transcript' ".
    "AND frel2.object_id = transcript.feature_id ".
    "AND frel2.subject_id = exon.feature_id ".
    "AND fl.feature_id = exon.feature_id ".
    "AND exon.feature_id = fd2.feature_id ".
    "AND fd2.dbxref_id = d2.dbxref_id ".
    "AND d2.version = 'feat_name' ";
    
    return $self->_get_results_ref($query, $feat_name);
}

sub getModelCrossReferences {

    my $self = shift;
    my ($feat_name) = @_;
    if (!defined($feat_name)){
	$self->{_logger}->logdie("feat_name was not defined");
    }

    my $query = "SELECT d2.accession, d2.version ".
    "FROM feature cds, feature_dbxref fd, dbxref d, feature_relationship frel, feature transcript, cvterm c2, cvterm ccds, feature_dbxref fd2, dbxref d2 ".
    "WHERE ccds.name = 'CDS' ".
    "AND ccds.cvterm_id = cds.type_id ".
    "AND d.accession = ? ".
    "AND d.version = 'feat_name' ".
    "AND d.dbxref_id = fd.dbxref_id ".
    "AND fd.feature_id = cds.feature_id ".
    "AND cds.feature_id = frel.subject_id ".
    "AND frel.object_id = transcript.feature_id ".
    "AND transcript.type_id = c2.cvterm_id ".
    "AND c2.name = 'transcript' ".
    "AND transcript.feature_id = fd2.feature_id ".
    "AND fd2.dbxref_id = d2.dbxref_id ";
    
    return $self->_get_results_ref($query, $feat_name);
}

sub getModelHmmPfam {

    my $self = shift;
    my ($feat_name) = @_;
    if (!defined($feat_name)){
	$self->{_logger}->logdie("feat_name was not defined");
    }

    my $query = "SELECT hit.uniquename, fp.value ".
    "FROM feature hit, feature protein, featureprop fp, analysis a, analysisfeature af, feature match, featureloc fl1, featureloc fl2, cvterm c, feature_dbxref fd, dbxref d ".
    "WHERE d.accession = ? ".
    "AND d.version = 'feat_name' ".
    "AND d.dbxref_id = fd.dbxref_id ".
    "AND fd.feature_id = protein.feature_id ".
    "AND protein.feature_id = fl1.srcfeature_id ".
    "AND fl1.feature_id = match.feature_id ".
    "AND match.feature_id = fl2.feature_id ".
    "AND fl1.featureloc_id != fl2.featureloc_id ".
    "AND fl2.srcfeature_id = hit.feature_id ".
    "AND hit.feature_id = fp.feature_id ".
    "AND fp.type_id = c.cvterm_id ".
    "AND c.name = 'com_name' ".
    "AND match.feature_id = af.feature_id ".
    "AND af.analysis_id = a.analysis_id ".
    "AND a.program = 'HMMPFAM' ";

    return $self->_get_results_ref($query, $feat_name);
}

sub getModelGO {

    my $self = shift;
    my ($feat_name) = @_;
    if (!defined($feat_name)){
	$self->{_logger}->logdie("feat_name was not defined");
    }

    return [];
    my $query;
    return $self->_get_results_ref($query, $feat_name);
}

sub getProteinSequences {

    my $self = shift;

    my $query = "SELECT f.uniquename, f.residues ".
    "FROM feature f, cvterm c ".
    "WHERE c.name = 'polypeptide' ".
    "AND c.cvterm_id = f.type_id ".
    "AND f.is_obsolete = 0 ";

    return $self->_get_results_ref($query);
}

sub getProteinSequence {

    my $self = shift;
    my ($id) = @_;

    if (!defined($id)){
	$self->{_logger}->logdie("id was not defined");
    }

    my $query = "SELECT residues ".
    "FROM feature f ".
    "WHERE f.uniquename = ? ";

    return $self->_get_results_ref($query, $id);
}


sub getProteinIdentifiersByClusterAnalysisId {

    my $self = shift;
    my ($id) = @_;

    if (!defined($id)){
	$self->{_logger}->logdie("id was not defined");
    }
    
    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match', 'SO');
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match'");
    }

    my $retProteinCvtermId = $self->get_cvterm_id_from_so('polypeptide');
    my $proteinCvtermId = $retProteinCvtermId->[0][0];
    if (!defined($proteinCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'polypeptide'");
    }

    my $query = "SELECT f.feature_id, m.feature_id ".
    "FROM feature f, feature m, featureloc fl, analysisfeature af ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = m.feature_id ".
    "AND m.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = f.feature_id ".
    "AND f.type_id = ? ".
    "AND m.type_id = ? ";

    return $self->_get_results_ref($query, $id, $proteinCvtermId, $matchCvtermId);
}

sub getProteinLengthByClusterAnalysisId {

    my $self = shift;
    my ($id) = @_;

    if (!defined($id)){
	$self->{_logger}->logdie("id was not defined");
    }
    
    my $matchCvtermId = $self->getCvtermIdByTermNameByOntology('match', 'SO');
    if (!defined($matchCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'match'");
    }

    my $retProteinCvtermId = $self->get_cvterm_id_from_so('polypeptide');
    my $proteinCvtermId = $retProteinCvtermId->[0][0];
    if (!defined($proteinCvtermId)){
	$self->{_logger}->logdie("cvterm_id was not defined for cvterm.name = 'polypeptide'");
    }

    my $query = "SELECT f.feature_id, m.feature_id, datalength(f.residues) ".
    "FROM feature f, feature m, featureloc fl, analysisfeature af ".
    "WHERE af.analysis_id = ? ".
    "AND af.feature_id = m.feature_id ".
    "AND m.feature_id = fl.feature_id ".
    "AND fl.srcfeature_id = f.feature_id ".
    "AND f.type_id = ? ".
    "AND m.type_id = ? ";

    return $self->_get_results_ref($query, $id, $proteinCvtermId, $matchCvtermId);
}




1==1; ## End of module
