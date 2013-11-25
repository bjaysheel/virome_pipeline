package Prism::MysqlChadoPrismDB;

use strict;
use base qw(Prism::ChadoPrismDB);
use base qw(Coati::Coati::MysqlChadoCoatiDB);

my $MODNAME = "MysqlChadoPrismDB.pm";

sub say_hello {
    my ($self, @args) = @_;
    $self->_trace if $self->{_debug};
    print "Hi there.\n";
}


sub test_MysqlChadoPrismDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_ChadoPrismDB();
}

sub testProjDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_MysqlChadoPrismDB();
}

our $FIELD_DELIMITER = "\t";
our $RECORD_DELIMITER = "\n";

#-----------------------------------------------------------------------------------------
# doDropForeignKeyConstraints()
#
#-----------------------------------------------------------------------------------------
sub doDropForeignKeyConstraints {

    ## Might be $self->{_db}
    my ($self) = @_;

    $self->{_logger}->logdie("This subroutine has not been implemented for MySQL yet.  Seeing this message makes it your job to write it.");

    ## Report names and count of foreign keys prior to dropping them.
    ## Need a query that retrieves a list of all the foreign key constraints
    my $fkey_query = qq{
        SELECT DISTINCT ke.table_name, ke.constraint_name
          FROM information_schema.KEY_COLUMN_USAGE ke
         WHERE ke.referenced_table_name IS NOT NULL
           AND ke.constraint_schema = ?
    };

    my $fkey_names = $self->_get_results_ref($fkey_query);

    my $j;
    
    $self->{_logger}->warn("Will drop the following foreign keys");

    for ($j=0; $j < scalar(@{$fkey_names}) ;  $j++ ) {
        my $fkey = $fkey_names->[$j][1];
        $self->{_logger}->warn("$fkey");
    }

    $self->{_logger}->warn("Will drop '$j' foreign keys");

    my $instructions = [];
    
    for (@$fkey_names ) {
        push @$instructions, "ALTER TABLE $$fkey_names[0] DROP FOREIGN KEY $$fkey_names[1]";
    }

    my $i;

    for ( $i=0; $i < scalar(@{$instructions}) ; $i++) {
        my $instruct = $instructions->[$i][0];
        $self->_do_sql($instruct);
        $self->{_logger}->warn("instruct: $instruct");
    }
    
    $self->{_logger}->warn("Dropped '$i' foreign keys");

    #--------------------------------------------------------------------------------------------------------------
    # Report names and count of any remaining foreign keys after having attempted to drop them.
    #
    $fkey_names = $self->_get_results_ref($fkey_query);

    $j;
    
    $self->{_logger}->warn("Foreign keys remaining");

    for ($j=0; $j < scalar(@{$fkey_names}) ;  $j++ ) {
        my $fkey = $fkey_names->[$j][1];
        $self->{_logger}->warn("$fkey");
    }

    $self->{_logger}->warn("The number of foreign keys remaining after attempting to drop them: '$j'");
    #
    #--------------------------------------------------------------------------------------------------------------


    
}


#----------------------------------------------------------------
# getSystemObjectsListByType()
#
#----------------------------------------------------------------
sub getSystemObjectsListByType {

    my($self, $objectType) = @_;

    
    $self->{_logger}->logdie("getSystemObjectsListByType call not yet implemented!");
    
    ## Need appropriate mysql query here.  what is the goal of this?
    my $query = "SELECT name FROM sysobjects WHERE type='$objectType' and uid = 1";

    return $self->_get_results_ref($query);
    
}


#--------------------------------------------------------------------------------
# doesTableExist()
#
#--------------------------------------------------------------------------------
sub doesTableExist {

    my ($self, $table) = @_;

    my $query = qq{
        SELECT count(*) 
          FROM information_schema.tables
         WHERE table_name = ?
           AND table_schema = ?  
    };

    my @ret = $self->_get_results($query, $table, $self->{_db});

    my $retVal = (defined($ret[0][0])) ? $ret[0][0] : undef;

    return $retVal;
}

 
#--------------------------------------------------------------
# doesTableHaveSpace()
#
#--------------------------------------------------------------
sub doesTableHaveSpace {

    my($self, %params) = @_;

    my ($infile, $table);

    if (exists $params{'table'}){
        $table = $params{'table'};
    } else {
        $self->{_logger}->logdie("table was not defined");
    }

    if (exists $params{'infile'}){
        $infile = $params{'infile'};
    } else {
        $self->{_logger}->logdie("infile was not defined");
    }
  
    $self->{_logger}->fatal("Need to implement this method!");

    return 1;
}


#---------------------------------------------------------------------------------------------------------------
# doUpdateStatistics()
#
# Method for deleting a project record from the chado database.
# 
# input:       project_id, name, description
#
# output:      none
#
# return:      none
#
#
#---------------------------------------------------------------------------------------------------------------
sub doUpdateStatistics {

    my ($self, $table, $testmode) = @_;

    if (!defined($table)){
    $self->{_logger}->fatal("table was not defined, therefore ".
                "not updating any table's statistics");
    return undef;
    }

    $self->{_logger}->logdie("This subroutine has not been implemented for MySQL yet.  Seeing this message makes it your job to write it.");

    my $sql = "update statistics $table";
    $self->{_logger}->info("sql '$sql'");

    if ($testmode){
    $self->{_logger}->info("testmode was set to '$testmode' ".
                   "therefore did not update statistics ".
                   "on table '$table'");
    }
    else{
    $self->_do_sql($sql);
    }
    
}


#---------------------------------------------------------------------------------------------------------------
# subroutine:  getTableList()
#
# Method for retrieving list of all user tables not like 'temp%'.
# 
# input:       none
#
# output:      none
#
# return:      none
#
#
#---------------------------------------------------------------------------------------------------------------
sub getTableList {

    my ($self) = @_;

    $self->{_logger}->logdie("This subroutine has not been implemented for MySQL yet.  Seeing this message makes it your job to write it.");

    my $query = "SELECT name ".
    "FROM sysobjects ".
    "WHERE type = 'U' ".
    "AND name not like 'temp%'";

    my @list;

    my @ret = $self->_get_results($query);

    for (my $i=0;$i<scalar @ret;$i++){
    push(@list, $ret[$i][0]);
    }

    return \@list;

}# end sub getTableList()


#---------------------------------------------------------------
# get_organism_id_lookup()
#
#---------------------------------------------------------------
sub get_organism_id_lookup {

    my($self) = @_;

    print "Building organism_id_lookup\n";

    my $query = "SELECT CONCAT(genus, '_', species), organism_id ".
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

    my $query = "SELECT CONCAT(organism_id, '_', type_id, '_', value, '_', rank), organismprop_id ".
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

    my $query = "SELECT CONCAT(organism_id, '_', dbxref_id), organism_dbxref_id ".
    "FROM organism_dbxref ";
    
    return $self->_get_lookup_db($query);

}


#---------------------------------------------------------------
# get_cvterm_id_by_dbxref_accession_lookup()
#
#---------------------------------------------------------------
sub get_cvterm_id_by_dbxref_accession_lookup {

    my($self) = @_;

    print "Building cvterm_id_by_dbxref_accession_lookup\n";

    my $query = "SELECT CONCAT(c.cv_id, '_',  d.accession), c.cvterm_id  ".
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

    my $query = "SELECT CONCAT(db.name, '_', d.accession), c.cvterm_id ".
    "FROM cv, db, dbxref d, cvterm c, cvterm_dbxref cd ".
    "WHERE db.name = cv.name ".
    "AND db.db_id = d.db_id ".
    "AND d.dbxref_id = cd.dbxref_id ".
    "AND cd.cvterm_id = c.cvterm_id ".
    "AND cv.cv_id = c.cv_id ";
        
    return $self->_get_lookup_db($query);

}


#---------------------------------------------------------------
# get_non_obsolete_cvterm_id_lookup()
#
#---------------------------------------------------------------
sub get_non_obsolete_cvterm_id_lookup {

    my($self) = @_;

    print "Building non_obsolete_cvterm_id_lookup\n";

    my $query = "SELECT CONCAT(cv_id, '_', lower(name)), cvterm_id ".
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

    my $query = "SELECT CONCAT(cv_id, '_', lower(name)), cvterm_id ".
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
# method:  get_cvtermpath_id_lookup()
#
#---------------------------------------------------------------
sub get_cvtermpath_id_lookup {

    my($self) = @_;

    print "Building cvtermpath_id_lookup\n";

    my $query = "SELECT CONCAT(subject_id, '_', object_id, '_', type_id, '_', pathdistance), cvtermpath_id ".
    "FROM cvtermpath ";
    
    return $self->_get_lookup_db($query);

}


#---------------------------------------------------------------
# get_dbxref_id_lookup()
#
#---------------------------------------------------------------
sub get_dbxref_id_lookup {

    my($self) = @_;

    print "Building dbxref_id_lookup\n";

    my $query = "SELECT CONCAT(db_id, '_', accession, '_',version), dbxref_id FROM dbxref";

    return $self->_get_lookup_db($query);

}

#---------------------------------------------------------------
# get_cvterm_relationship_type_id_lookup()
#
#---------------------------------------------------------------
sub get_cvterm_relationship_type_id_lookup {

    my($self) = @_;

    print "Building cvterm_relationship_type_id_lookup\n";

    my $query = "SELECT CONCAT(subject_id, '_', object_id), type_id ".
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

    my $query = "SELECT CONCAT(program, '_', programversion, '_', sourcename), analysis_id ".
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

    my $query = "SELECT CONCAT(analysis_id, '_', type_id), analysisprop_id ".
    "FROM analysisprop ";
    
    return $self->_get_lookup_db($query);

}

#---------------------------------------------------------------
# get_analysisfeature_id_lookup()
#
#---------------------------------------------------------------
sub get_analysisfeature_id_lookup {

    my($self) = @_;

    print "Building analysisfeature_id_lookup\n";

    my $query = "SELECT CONCAT(af.feature_id, '_', analysis_id), analysisfeature_id ".
    "FROM analysisfeature af, feature f ".
    "WHERE af.feature_id = f.feature_id ".
    "AND f.is_analysis = false";
    
    return $self->_get_lookup_db($query);

}


#---------------------------------------------------------------
# get_cvtermprop_id_lookup()
#
#---------------------------------------------------------------
sub get_cvtermprop_id_lookup {

    my ($self) = @_;

    print "Building cvtermprop_id_lookup\n";

    my $query = "SELECT CONCAT(cvterm_id, '_', type_id, '_', rank), cvtermprop_id ".
    "FROM cvtermprop ";

    return $self->_get_lookup_db($query);
}


#---------------------------------------------------------------
# get_cvterm_relationship_id_lookup()
#
#---------------------------------------------------------------
sub get_cvterm_relationship_id_lookup {
 
    my ($self) = @_;

    print "Building cvterm_relationship_id_lookup\n";

    my $query = "SELECT CONCAT(type_id, '_', subject_id, '_', object_id), cvterm_relationship_id ".
    "FROM cvterm_relationship ";
     
    return $self->_get_lookup_db($query);
}



#---------------------------------------------------------------
# get_cvterm_dbxref_id_lookup()
#
#---------------------------------------------------------------
sub get_cvterm_dbxref_id_lookup {

    my ($self) = @_;

    print "Building cvterm_dbxref_id_lookup\n";

    my $query = "SELECT CONCAT(cvterm_id, '_', dbxref_id), cvterm_dbxref_id ".
    "FROM cvterm_dbxref ";
    
    
    return $self->_get_lookup_db($query);
}


#----------------------------------------------------------------
# get_cvtermsynonym_id_lookup()
#
#----------------------------------------------------------------
sub get_cvtermsynonym_id_lookup {

    my ($self) = @_;

    print "Building cvtermsynonym_id_lookup\n";

    my $query = "SELECT CONCAT(cvterm_id, '_', synonym), cvtermsynonym_id ".
    "FROM cvtermsynonym ";
    
    
    return $self->_get_lookup_db($query);
}





#----------------------------------------------------------------
# get_feature_id_lookup()
#
#----------------------------------------------------------------
sub get_feature_id_lookup {

    my ($self) = @_;

    print "Building feature_id_lookup\n";

    my $query = "SELECT CONCAT(organism_id, '_', uniquename, '_', type_id), feature_id ".
    "FROM feature ".
    "WHERE is_analysis = false";
        
    return $self->_get_lookup_db($query);
}


#----------------------------------------------------------------
# get_feature_pub_id_lookup()
#
#----------------------------------------------------------------
sub get_feature_pub_id_lookup {

    my ($self) = @_;

    print "Building feature_pub_id_lookup\n";

    my $query = "SELECT CONCAT(feature_id, '_', pub_id), feature_pub_id ".
    "FROM feature_pub ";
        
    return $self->_get_lookup_db($query);
}


#----------------------------------------------------------------
# get_featureloc_id_lookup()
#
#----------------------------------------------------------------
sub get_featureloc_id_lookup {

    my ($self) = @_;

    print "Building featureloc_id_lookup\n";

    my $query = "SELECT CONCAT(fl.feature_id, '_', locgroup, '_', rank), featureloc_id ".
    "FROM featureloc fl, feature s, feature t ".
    "WHERE t.feature_id = fl.feature_id ".
    "AND fl.rank = 1 ".
    "AND s.feature_id = fl.srcfeature_id ".
    "AND fl.rank = 0 ".
    "AND s.is_analysis = false ".
    "AND t.is_analysis = false ";
        
    return $self->_get_lookup_db($query);
}

#----------------------------------------------------------------
# get_feature_dbxref_id_lookup()
#
#----------------------------------------------------------------
sub get_feature_dbxref_id_lookup {

    my ($self) = @_;

    print "Building feature_dbxref_id_lookup\n";

    my $query = "SELECT CONCAT(fd.feature_id, '_', fd.dbxref_id), feature_dbxref_id ".
    "FROM feature_dbxref fd, feature f ".
    "WHERE fd.feature_id = f.feature_id ".
    "AND f.is_analysis = false";
        
    return $self->_get_lookup_db($query);
}


#---------------------------------------------------------------
# get_feature_relationship_id_lookup()
#
#---------------------------------------------------------------
sub get_feature_relationship_id_lookup {

    my ($self) = @_;

    print "Building feature_relationship_id_lookup\n";

    my $query = "SELECT CONCAT(subject_id, '_', object_id, '_', fr.type_id, '_', rank), feature_relationship_id ".
    "FROM feature_relationship fr, feature s, feature o ".
    "WHERE fr.subject_id = s.feature_id ".
    "AND fr.object_id = o.feature_id ".
    "AND s.is_analysis = false ".
    "AND o.is_analysis = false ";
        
    return $self->_get_lookup_db($query);
}


#---------------------------------------------------------------
# get_feature_relationship_pub_id_lookup()
#
#---------------------------------------------------------------
sub get_feature_relationship_pub_id_lookup {

    my ($self) = @_;

    print "Building feature_relationship_pub_id_lookup\n";

    my $query = "SELECT CONCAT(fb.feature_relationship_id, '_', pub_id), feature_relationship_pub_id ".
    "FROM feature_relationship_pub fb, feature_relationship fr, feature o, feature s ".
    "WHERE fb.feature_relationship_id = fr.feature_relationship_id ".
    "AND fr.subject_id = s.feature_id ".
    "AND fr.object_id = o.feature_id ".
    "AND s.is_analysis = false ".
    "AND o.is_analysis = false ";
        
    return $self->_get_lookup_db($query);
}


#---------------------------------------------------------------
# get_feature_relationshipprop_id_lookup()
#
#---------------------------------------------------------------
sub get_feature_relationshipprop_id_lookup {

    my ($self) = @_;

    print "Building feature_relationshipprop_id_lookup\n";

    my $query = "SELECT CONCAT(fb.feature_relationship_id, '_', fb.type_id, '_', fb.rank), feature_relationshipprop_id ".
    "FROM feature_relationshipprop fb, feature_relationship fr,  feature o, feature s ".
    "WHERE fb.feature_relationship_id = fr.feature_relationship_id ".
    "AND fr.subject_id = s.feature_id ".
    "AND fr.object_id = o.feature_id ".
    "AND s.is_analysis = false ".
    "AND o.is_analysis = false ";
        
    return $self->_get_lookup_db($query);
}


#---------------------------------------------------------------
# get_feature_relprop_pub_id_lookup()
#
#---------------------------------------------------------------
sub get_feature_relprop_pub_id_lookup {

    my ($self) = @_;

    print "Building feature_relprop_pub_id_lookup\n";

    my $query = "SELECT CONCAT(feature_relationshipprop_id, '_', pub_id), feature_relprop_pub_id ".
    "FROM feature_relprop_pub ";
        
    return $self->_get_lookup_db($query);
}

#---------------------------------------------------------------
# getFeaturepropMaxRankLookup()
#
#---------------------------------------------------------------
sub getFeaturepropMaxRankLookup {

    my ($self) = @_;

    print "Building featurepropMaxRankLookup\n";

    my $query = "SELECT CONCAT(fp.feature_id, '_', fp.type_id), MAX(rank) ".
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
        
    return $self->_get_lookup_db($query);
}

#---------------------------------------------------------------
# get_featureprop_id_lookup()
#
#---------------------------------------------------------------
sub getFeaturepropIdLookup {
    my ($self) = @_;
    return $self->get_featureprop_id_lookup;
}
sub get_featureprop_id_lookup {

    my ($self) = @_;

    print "Building featureprop_id_lookup\n";

    my $query = "SELECT CONCAT(fp.feature_id, '_', fp.type_id, '_', value), featureprop_id ".
    "FROM featureprop fp, feature f ".
    "WHERE fp.feature_id = f.feature_id ".
    "AND f.is_analysis = false ";
        
    return $self->_get_lookup_db($query);
}



#---------------------------------------------------------------
# get_featureprop_pub_id_lookup()
#
#---------------------------------------------------------------
sub get_featureprop_pub_id_lookup {

    my ($self) = @_;

    print "Building featureprop_pub_id_lookup\n";

    my $query = "SELECT CONCAT(fb.featureprop_id, '_', pub_id), featureprop_pub_id ".
    "FROM featureprop_pub fb, featureprop fp, feature f ".
    "WHERE fb.featureprop_id = fp.featureprop_id ".
    "AND fp.feature_id = f.feature_id ".
    "AND f.is_analysis = false ";
        
    return $self->_get_lookup_db($query);
}


#--------------------------------------------------------------
# get_feature_cvterm_id_lookup()
#
#--------------------------------------------------------------
sub get_feature_cvterm_id_lookup {

    my ($self) = @_;

    print "Building feature_cvterm_id_lookup\n";

    my $query = "SELECT CONCAT(fc.feature_id, '_', cvterm_id, '_', pub_id), feature_cvterm_id ".
    "FROM feature_cvterm fc, feature f ".
    "WHERE fc.feature_id = f.feature_id ".
    "AND f.is_analysis = false ";
        
    return $self->_get_lookup_db($query);
}


#--------------------------------------------------------------
# get_feature_cvtermprop_id_lookup()
#
#--------------------------------------------------------------
sub get_feature_cvtermprop_id_lookup {

    my ($self) = @_;

    print "Building feature_cvtermprop_id_lookup\n";

    my $query = "SELECT CONCAT(fp.feature_cvterm_id, '_', fp.type_id, '_', fp.rank), feature_cvtermprop_id ".
    "FROM feature_cvtermprop fp, feature_cvterm fc, feature f ".
    "WHERE fp.feature_cvterm_id = fc.feature_cvterm_id ".
    "AND fc.feature_id = f.feature_id ".
    "AND f.is_analysis = false ";
        
    return $self->_get_lookup_db($query);
}


#--------------------------------------------------------------
# get_feature_cvterm_dbxref_id_lookup()
#
#--------------------------------------------------------------
sub get_feature_cvterm_dbxref_id_lookup {

    my ($self) = @_;

    print "Building feature_cvterm_dbxref_id_lookup\n";

    my $query = "SELECT CONCAT(fp.feature_cvterm_id, '_', fp.dbxref_id), feature_cvterm_dbxref_id ".
    "FROM feature_cvterm_dbxref fp, feature_cvterm fc, feature f ".
    "WHERE fp.feature_cvterm_id = fc.feature_cvterm_id ".
    "AND fc.feature_id = f.feature_id ".
    "AND f.is_analysis = false ";
        
    return $self->_get_lookup_db($query);
}




#---------------------------------------------------------------
# get_feature_cvterm_pub_id_lookup()
#
#---------------------------------------------------------------
sub get_feature_cvterm_pub_id_lookup {

    my ($self) = @_;

    print "Building feature_cvterm_pub_id_lookup\n";

    my $query = "SELECT CONCAT(fp.feature_cvterm_id, '_', fp.pub_id), feature_cvterm_pub_id ".
    "FROM feature_cvterm_pub fp, feature_cvterm fc, feature f ".
    "WHERE fp.feature_cvterm_id = fc.feature_cvterm_id ".
    "AND fc.feature_id = f.feature_id ".
    "AND f.is_analysis = false ";
        
    return $self->_get_lookup_db($query);
}



#----------------------------------------------------------------
# get_synonym_id_lookup()
#
#----------------------------------------------------------------
sub get_synonym_id_lookup {

    my ($self) = @_;

    print "Building synonym_id_lookup\n";

    my $query = "SELECT CONCAT(name, '_', type_id), synonym_id ".
    "FROM synonym ";
        
    return $self->_get_lookup_db($query);
}



#----------------------------------------------------------------
# get_feature_synonym_id_lookup()
#
#----------------------------------------------------------------
sub get_feature_synonym_id_lookup {

    my ($self) = @_;

    print "Building synonym_id_lookup\n";

    my $query = "SELECT CONCAT(synonym_id, '_', fs.feature_id, '_', pub_id), feature_synonym_id ".
    "FROM feature_synonym fs, feature f ".
    "WHERE fs.feature_id = f.feature_id ".
    "AND f.is_analysis = false ";
        
    return $self->_get_lookup_db($query);
}



#---------------------------------------------------------------
# get_dbxrefprop_id_lookup()
#
#---------------------------------------------------------------
sub get_dbxrefprop_id_lookup {

    my($self) = @_;

    print "Building dbxrefprop_id_lookup\n";

    my $query = "SELECT CONCAT(dbxref_id, '_', type_id, '_', value, '_', rank), dbxrefprop_id ".
    "FROM dbxrefprop ";
    
    return $self->_get_lookup_db($query);

}

 
#---------------------------------------------------------------
# get_pub_id_lookup()
#
#---------------------------------------------------------------
sub get_pub_id_lookup {

    my($self) = @_;

    print "Building pub_id_lookup\n";

    my $query = "SELECT CONCAT(uniquename, '_', type_id), pub_id ".
    "FROM pub ";
    
    return $self->_get_lookup_db($query);

}


#---------------------------------------------------------------
# get_pub_relationship_id_lookup()
#
#---------------------------------------------------------------
sub get_pub_relationship_id_lookup {

    my($self) = @_;

    print "Building pub_relationship_id_lookup\n";

    my $query = "SELECT CONCAT(subject_id, '_', object_id, '_', type_id), pub_relationship_id ".
    "FROM pub_relationship ";
    
    return $self->_get_lookup_db($query);

}

#---------------------------------------------------------------
# get_pub_dbxref_id_lookup()
#
#---------------------------------------------------------------
sub get_pub_dbxref_id_lookup {

    my($self) = @_;

    print "Building pub_dbxref_id_lookup\n";

    my $query = "SELECT CONCAT(pub_id, '_', dbxref_id), pub_dbxref_id ".
    "FROM pub_dbxref ";
    
    return $self->_get_lookup_db($query);

}


#---------------------------------------------------------------
# get_pubauthor_id_lookup()
#
#---------------------------------------------------------------
sub get_pubauthor_id_lookup {

    my($self) = @_;

    print "Building pubauthor_id_lookup\n";

    my $query = "SELECT CONCAT(pub_id, '_', rank), pubauthor_id ".
    "FROM pubauthor ";
    
    return $self->_get_lookup_db($query);

}

#---------------------------------------------------------------
# get_pubprop_id_lookup()
#
#---------------------------------------------------------------
sub get_pubprop_id_lookup {

    my($self) = @_;

    print "Building pubprop_id_lookup\n";

    my $query = "SELECT CONCAT(pub_id, '_', type_id), pubprop_id ".
    "FROM pubprop ";
    
    return $self->_get_lookup_db($query);

}


#---------------------------------------------------------------
# get_phylotree_pub_id_lookup()
#
#---------------------------------------------------------------
sub get_phylotree_pub_id_lookup {

    my($self) = @_;

    print "Building phylotree_pub_id_lookup\n";

    my $query = "SELECT CONCAT(phylotree_id, '_', pub_id), phylotree_pub_id ".
    "FROM phylotree_pub ";
    
    return $self->_get_lookup_db($query);

}

#--------------------------------------------------------------
# get_phylonode_id_lookup()
#
#--------------------------------------------------------------
sub get_phylonode_id_lookup {

    my($self) = @_;

    print "Building phylonode_id_lookup\n";

    my $query = "SELECT CONCAT(phylotree_id, '_', left_idx), phylonode_id ".
    "FROM phylonode ";
    
    return $self->_get_lookup_db($query);

}


 
#--------------------------------------------------------------
# get_phylonode_dbxref_id_lookup()
#
#--------------------------------------------------------------
sub get_phylonode_dbxref_id_lookup {

    my($self) = @_;

    print "Building phylonode_dbxref_id_lookup\n";

    my $query = "SELECT CONCAT(phylonode_id, '_', dbxref_id), phylonode_dbxref_id ".
    "FROM phylonode_dbxref ";
    
    return $self->_get_lookup_db($query);

}


#--------------------------------------------------------------
# get_phylonode_pub__id_lookup()
#
#--------------------------------------------------------------
sub get_phylonode_pub_id_lookup {

    my($self) = @_;

    print "Building phylonode_pub_id_lookup\n";

    my $query = "SELECT CONCAT(phylonode_id, '_', pub_id), phylonode_pub_id ".
    "FROM phylonode_pub ";
    
    return $self->_get_lookup_db($query);

}

#--------------------------------------------------------------
# get_phylonode_organism__id_lookup()
#
#--------------------------------------------------------------
sub get_phylonode_organism_id_lookup {

    my($self) = @_;

    print "Building phylonode_organism_id_lookup\n";

    my $query = "SELECT CONCAT(phylonode_id, '_', organism_id), phylonode_organism_id ".
    "FROM phylonode_organism ";
    
    return $self->_get_lookup_db($query);

}

#-------------------------------------------------------------
# get_phylonodeprop_id_lookup()
#
#-------------------------------------------------------------
sub get_phylonodeprop_id_lookup {

    my($self) = @_;

    print "Building phylonodeprop_id_lookup\n";

    my $query = "SELECT CONCAT(phylonode_id, '_', type_id, '_', rank), phylonodeprop_id ".
    "FROM phylonodeprop ";
    
    return $self->_get_lookup_db($query);

}

#------------------------------------------------------------
# get_phylonode_relationship_id_lookup()
#
#------------------------------------------------------------
sub get_phylonode_relationship_id_lookup {

    my($self) = @_;

    print "Building phylonode_relationship_id_lookup\n";

    my $query = "SELECT CONCAT(subject_id, '_', object_id, '_', type_id), phylonode_relationship_id ".
    "FROM phylonode_relationship ";
    
    return $self->_get_lookup_db($query);

}

#---------------------------------------------------------------
# get_cvterm_id_by_alt_id_lookup()
#
#---------------------------------------------------------------
sub get_cvterm_id_by_alt_id_lookup {

    my($self) = @_;

    print "Building cvterm_id_by_alt_id_lookup\n";

    my $query = "SELECT CONCAT(c.cv_id, '_', d.accession), c.cvterm_id  ".
    "FROM cvterm c, dbxref d, cvterm_dbxref cd ".
    "WHERE d.dbxref_id = cd.dbxref_id ".
    "AND cd.cvterm_id = c.cvterm_id ";
    
    return $self->_get_lookup_db($query);

}


#---------------------------------------------------------------
# get_master_feature_id_lookup()
#
#---------------------------------------------------------------
sub get_master_feature_id_lookup {

    my($self, $doctype, $chromosome) = @_;

    print "Building master_feature_id_lookup\n";

    if (!defined($chromosome)){
    $self->{_logger}->logdie("chromosome was not defined");
    }

    # Retrieve a master feature_id lookup
    # which contains all of the uniquename to feature_id tuples
    # present in chado.feature, however excluding all
    # pairs which belong to chado.analysisfeature

    my $query = "SELECT f.uniquename, f.feature_id ".
    "FROM feature f ".
    "WHERE f.is_analysis = false ";
    
    return $self->_get_lookup_db($query);
}


#-------------------------------------------------------------------------------------------------------------------------------------------------
# get_cvterm_max_is_obsolete_lookup()
#
#-------------------------------------------------------------------------------------------------------------------------------------------------
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
    "GROUP BY name, cvterm_id, is_obsolete ".
    "HAVING is_obsolete = max(is_obsolete) ";

    return $self->_get_lookup_db($query);

}


#-------------------------------------------------------------
# get_typedef_lookup()
#
#-------------------------------------------------------------
sub get_typedef_lookup {

    my($self) = @_;

    print "Building typedef_lookup\n";

    my $query = "SELECT  lower(c.name), c.cvterm_id ".
    "FROM cvterm c, cv ".
    "WHERE cv.name = 'relationship' ".
    "AND cv.cv_id = c.cv_id ".
    "AND c.is_relationshiptype = true ";

    return $self->_get_results_ref($query);
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
    "AND c.is_relationshiptype = true ";

    return $self->_get_results_ref($query);

}

##---------------------------------------------------------------
## getCvtermPathIdCachedLookup()
##
##---------------------------------------------------------------
sub getCvtermPathIdCachedLookup {

    my($self) = @_;

    print "Building cvtermpath_id cached lookup\n";

    my $query = "SELECT CONCAT(type_id, '_', subject_id, '_', object_id, '_', cv_id, '_', pathdistance), cvtermpath_id ".
    "FROM cvtermpath ";
    
    return $self->_get_lookup_db($query);

}

#----------------------------------------------------------------
# doesDatabaseExist()
#
#----------------------------------------------------------------
sub doesDatabaseExist {

    my $self = shift;
    my ($database) = @_;

    if (!defined($database)){
    $self->{_logger}->logdie("database was not defined");
    }

    my $query = qq{
        SELECT schema_name
          FROM information_schema.schemata
         WHERE schema_name = ?
    };

    return $self->_get_results_ref($query, $database);
}

#----------------------------------------------------------------
# getForeignKeyConstraintsList()
#
#----------------------------------------------------------------
sub getForeignKeyConstraintsList {

    my $self = shift;

    my $query = qq{
        SELECT constraint_name
          FROM information_schema.table_constraints
         WHERE constraint_type = 'FOREIGN KEY'
           AND table_schema = ?
    };
    
    return $self->_get_results_ref($query, $self->{_db});
}

#----------------------------------------------------------------
# getForeignKeyConstraintAndTableList()
#
#----------------------------------------------------------------
sub getForeignKeyConstraintAndTableList {

    my $self = shift;

    $self->{_logger}->logdie("This subroutine has not been implemented for MySQL yet.  Seeing this message makes it your job to write it.");

    my $query = "SELECT c.conname, t.tablename ".
    "FROM pg_constraint c, pg_class cl, pg_tables t ".
    "WHERE  c.confrelid = cl.oid ".
    "AND cl.relname = t.tablename ".
    "AND t.schemaname = 'public' ";

    return $self->_get_results_ref($query);
}

#----------------------------------------------------------------
# getTableList()
#
#----------------------------------------------------------------
sub getTableList {

    my $self = shift;

    my $query = qq{
        SELECT table_name 
          FROM information_schema.tables
         WHERE table_type = 'BASE TABLE'
           AND table_schema = ?
    };    

    return $self->_get_results_ref($query, $self->{_db});
}

1;







