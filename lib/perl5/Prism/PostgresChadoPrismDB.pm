package Prism::PostgresChadoPrismDB;

use strict;
use base qw(Prism::ChadoPrismDB);
use base qw(Coati::Coati::PostgresChadoCoatiDB);

my $MODNAME = "PostgresChadoPrismDB.pm";

sub say_hello {
    my ($self, @args) = @_;
    $self->_trace if $self->{_debug};
    print "Hi there.\n";
}


sub test_SybaseChadoPrismDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_ChadoPrismDB();
}

sub testProjDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_SybaseChadoPrismDB();
}

our $FIELD_DELIMITER = "\t";
our $RECORD_DELIMITER = "\n";

#-----------------------------------------------------------------------------------------
# doDropForeignKeyConstraints()
#
#-----------------------------------------------------------------------------------------
sub doDropForeignKeyConstraints {

    my ($self) = @_;

    ## Report names and count of foreign keys prior to dropping them.
    ## Need a query that retrieves a list of all the foreign key constraints
    my $fkey_query = "SELECT cons.name  ".
    "FROM sysobjects t, sysobjects ref, sysobjects cons, sysreferences r, sysconstraints c ".
    "WHERE cons.id = c.constrid ".
    "AND c.constrid = r.constrid ".
    "AND r.tableid = t.id ".
    "AND r.reftabid = ref.id ".
    "AND r.tableid != r.reftabid "; #-- ignore uniqueness constraints, only interested in foreign key constraints

    my $fkey_names = $self->_get_results_ref($fkey_query);

    my $j;
    
    $self->{_logger}->warn("Will drop the following foreign keys");

    for ($j=0; $j < scalar(@{$fkey_names}) ;  $j++ ) {
	
	my $fkey = $fkey_names->[$j][0];

	$self->{_logger}->warn("$fkey");

    }

    $self->{_logger}->warn("Will drop '$j' foreign keys");

    ## Drop the foreign keys
    ## Need the appropriate SQL here
    my $query = "SELECT 'ALTER TABLE ' + t.name + ' DROP CONSTRAINT ' + cons.name ".
    "FROM sysobjects t, sysobjects ref, sysobjects cons, sysreferences r, sysconstraints c ".
    "WHERE cons.id = c.constrid ".
    "AND c.constrid = r.constrid ".
    "AND r.tableid = t.id ".
    "AND r.reftabid = ref.id ".
    "AND r.tableid != r.reftabid "; #-- ignore uniqueness constraints, only interested in foreign key constraints

    my $instructions = $self->_get_results_ref($query);

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
    my $fkey_query = "SELECT cons.name  ".
    "FROM sysobjects t, sysobjects ref, sysobjects cons, sysreferences r, sysconstraints c ".
    "WHERE cons.id = c.constrid ".
    "AND c.constrid = r.constrid ".
    "AND r.tableid = t.id ".
    "AND r.reftabid = ref.id ".
    "AND r.tableid != r.reftabid "; #-- ignore uniqueness constraints, only interested in foreign key constraints

    my $fkey_names = $self->_get_results_ref($fkey_query);

    $j;
    
    $self->{_logger}->warn("Foreign keys remaining");

    for ($j=0; $j < scalar(@{$fkey_names}) ;  $j++ ) {
	
	my $fkey = $fkey_names->[$j][0];

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

    
    $self->{_logger}->logdie("Note yet implemented!");
    
    ## Need appropriate postgresql query here.
    my $query = "SELECT name FROM sysobjects WHERE type='$objectType' and uid = 1";

    return $self->_get_results_ref($query);
    
}


#--------------------------------------------------------------------------------
# doesTableExist()
#
#--------------------------------------------------------------------------------
sub doesTableExist {

    my ($self, $table) = @_;

    ## Query the system table pg_class
    
    my $query = "SELECT count(*) ".
    "FROM pg_class ".
    "WHERE relname = ? ";

    my @ret = $self->_get_results($query, $table);

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
    }
    else {
	$self->{_logger}->logdie("table was not defined");
    }

    if (exists $params{'infile'}){
	$infile = $params{'infile'};
    }
    else {
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

    $self->{_logger}->logdie("Not yet implemented!");

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

    $self->{_logger}->logdie("Not yet implemented!");

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

    my $query = "SELECT genus || '_' || species, organism_id ".
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

    my $query = "SELECT organism_id || '_' || type_id || '_' || value || '_' || rank, organismprop_id ".
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

    my $query = "SELECT organism_id || '_' || dbxref_id, organism_dbxref_id ".
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

    my $query = "SELECT c.cv_id || '_' ||  d.accession, c.cvterm_id  ".
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

    my $query = "SELECT db.name || '_' || d.accession, c.cvterm_id ".
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

    my $query = "SELECT  cv_id || '_' || lower(name), cvterm_id ".
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

    my $query = "SELECT  cv_id || '_' || lower(name), cvterm_id ".
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

    my $query = "SELECT  subject_id || '_' || object_id || '_' || type_id || '_' || pathdistance, cvtermpath_id ".
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

    my $query = "SELECT  db_id || '_' || accession || '_' || version, dbxref_id ".
    "FROM dbxref ";
    
    return $self->_get_lookup_db($query);

}

#---------------------------------------------------------------
# get_cvterm_relationship_type_id_lookup()
#
#---------------------------------------------------------------
sub get_cvterm_relationship_type_id_lookup {

    my($self) = @_;

    print "Building cvterm_relationship_type_id_lookup\n";

    my $query = "SELECT subject_id || '_' || object_id, type_id ".
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

    my $query = "SELECT  program || '_' || programversion || '_' || sourcename, analysis_id ".
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

    my $query = "SELECT analysis_id || '_' || type_id , analysisprop_id ".
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

    my $query = "SELECT  af.feature_id || '_' || analysis_id, analysisfeature_id ".
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

    my $query = "SELECT cvterm_id || '_' || type_id || '_' || rank , cvtermprop_id ".
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

    my $query = "SELECT  type_id || '_' || subject_id || '_' || object_id , cvterm_relationship_id ".
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

    my $query = "SELECT cvterm_id || '_' || dbxref_id, cvterm_dbxref_id ".
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

    my $query = "SELECT cvterm_id || '_' || synonym, cvtermsynonym_id ".
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

    my $query = "SELECT organism_id || '_' || uniquename || '_' || type_id, feature_id ".
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

    my $query = "SELECT feature_id || '_' || pub_id, feature_pub_id ".
    "FROM feature_pub ";
        
    return $self->_get_lookup_db($query);
}


#----------------------------------------------------------------
# get_featureloc_id_lookup()
#
#----------------------------------------------------------------
sub get_featureloc_id_lookup {

    my $self = shift;

    my $query = "SELECT fl.feature_id || '_' || locgroup || '_' || rank, featureloc_id ".
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

    my $query = "SELECT fl.srcfeature_id || '_' || fl.feature_id || '_' || fmin || '_' || fmax || '_' || strand, featureloc_id ".
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

#----------------------------------------------------------------
# get_feature_dbxref_id_lookup()
#
#----------------------------------------------------------------
sub get_feature_dbxref_id_lookup {

    my $self = shift;

    my $query = "SELECT fd.feature_id || '_' || fd.dbxref_id, fd.feature_dbxref_id ".
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


#---------------------------------------------------------------
# get_feature_relationship_id_lookup()
#
#---------------------------------------------------------------
sub get_feature_relationship_id_lookup {

    my $self = shift;
    
    my $query = "SELECT frel.subject_id || '_' || frel.object_id || '_' || frel.type_id || '_' || frel.rank, frel.feature_relationship_id ".
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


#---------------------------------------------------------------
# get_feature_relationship_pub_id_lookup()
#
#---------------------------------------------------------------
sub get_feature_relationship_pub_id_lookup {

    my $self = shift;

    my $query = "SELECT fb.feature_relationship_id || '_' || pub_id, feature_relationship_pub_id ".
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


#---------------------------------------------------------------
# get_feature_relationshipprop_id_lookup()
#
#---------------------------------------------------------------
sub get_feature_relationshipprop_id_lookup {

    my $self = shift;
    
    my $query = "SELECT fb.feature_relationship_id || '_' || fb.type_id || '_' || fb.rank, feature_relationshipprop_id ".
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


#---------------------------------------------------------------
# get_feature_relprop_pub_id_lookup()
#
#---------------------------------------------------------------
sub get_feature_relprop_pub_id_lookup {

    my $self = shift;

    my $query = "SELECT fpub.feature_relationshipprop_id || '_' || fpub.pub_id, fpub.feature_relprop_pub_id ".
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

    my $query = "SELECT fp.feature_id || '_' || fp.type_id || '_' || value, featureprop_id ".
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

    my $query = "SELECT fp.feature_id || '_' || fp.type_id, MAX(rank) ".
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

#---------------------------------------------------------------
# get_featureprop_pub_id_lookup()
#
#---------------------------------------------------------------
sub get_featureprop_pub_id_lookup {

    my $self = shift;

    my $query = "SELECT fb.featureprop_id || '_' || pub_id, featureprop_pub_id ".
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


#--------------------------------------------------------------
# get_feature_cvterm_id_lookup()
#
#--------------------------------------------------------------
sub get_feature_cvterm_id_lookup {

    my $self = shift;

    my $query = "SELECT fc.feature_id || '_' || cvterm_id || '_' || pub_id, feature_cvterm_id ".
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


#--------------------------------------------------------------
# get_feature_cvtermprop_id_lookup()
#
#--------------------------------------------------------------
sub get_feature_cvtermprop_id_lookup {

    my $self = shift;

    my $query = "SELECT fp.feature_cvterm_id || '_' || fp.type_id || '_' || fp.rank, feature_cvtermprop_id ".
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

#--------------------------------------------------------------
# get_feature_cvterm_dbxref_id_lookup()
#
#--------------------------------------------------------------
sub get_feature_cvterm_dbxref_id_lookup {

    my $self = shift;

    my $query = "SELECT fp.feature_cvterm_id || '_' || fp.dbxref_id, feature_cvterm_dbxref_id ".
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

#---------------------------------------------------------------
# get_feature_cvterm_pub_id_lookup()
#
#---------------------------------------------------------------
sub get_feature_cvterm_pub_id_lookup {

    my $self = shift;

    my $query = "SELECT fp.feature_cvterm_id || '_' || fp.pub_id, feature_cvterm_pub_id ".
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



#----------------------------------------------------------------
# get_synonym_id_lookup()
#
#----------------------------------------------------------------
sub get_synonym_id_lookup {

    my ($self) = @_;

    print "Building synonym_id_lookup\n";

    my $query = "SELECT name  || '_' || type_id, synonym_id ".
    "FROM synonym ";
        
    return $self->_get_lookup_db($query);
}



#----------------------------------------------------------------
# get_feature_synonym_id_lookup()
#
#----------------------------------------------------------------
sub get_feature_synonym_id_lookup {

    my $self = shift;

    my $query = "SELECT synonym_id || '_' || fs.feature_id || '_' || pub_id, feature_synonym_id ".
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



#---------------------------------------------------------------
# get_dbxrefprop_id_lookup()
#
#---------------------------------------------------------------
sub get_dbxrefprop_id_lookup {

    my($self) = @_;

    print "Building dbxrefprop_id_lookup\n";

    my $query = "SELECT dbxref_id || '_' || type_id || '_' || value || '_' || rank, dbxrefprop_id ".
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

    my $query = "SELECT uniquename  || '_' || type_id, pub_id ".
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

    my $query = "SELECT subject_id || '_' || object_id || '_' || type_id, pub_relationship_id ".
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

    my $query = "SELECT pub_id || '_' || dbxref_id, pub_dbxref_id ".
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

    my $query = "SELECT pub_id || '_' || rank, pubauthor_id ".
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

    my $query = "SELECT pub_id || '_' || type_id , pubprop_id ".
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

    my $query = "SELECT phylotree_id || '_' || pub_id, phylotree_pub_id ".
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

    my $query = "SELECT phylotree_id || '_' || left_idx, phylonode_id ".
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

    my $query = "SELECT phylonode_id || '_' || dbxref_id, phylonode_dbxref_id ".
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

    my $query = "SELECT phylonode_id || '_' || pub_id, phylonode_pub_id ".
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

    my $query = "SELECT phylonode_id || '_' || organism_id, phylonode_organism_id ".
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

    my $query = "SELECT phylonode_id || '_' || type_id || '_' || rank, phylonodeprop_id ".
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

    my $query = "SELECT subject_id || '_' || object_id || '_' || type_id, phylonode_relationship_id ".
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

    my $query = "SELECT c.cv_id || '_' || d.accession, c.cvterm_id  ".
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

#     produlus 2619
#     Removing the change to the below query made in revision 3983
#     below changes the functionality of the query from
#     "the max is_obsolete value for each unique accession"
#     to
#     "all obsolete cvterms"
#     obov1p2tochado.pl expects the former behavior, so I am changing
#     it back, to coincide with MysqlChadoPRismDB.pm and ChadoPrismDB.pm
#
#      my $query = "SELECT lower(name), cvterm_id, is_obsolete ".
#     "FROM cvterm ".
#     "WHERE cv_id = $cv_id ".
#     "AND is_obsolete > 0 ".
#     "GROUP BY name, cvterm_id, is_obsolete ".
#     "ORDER by is_obsolete desc";

    my $query = qq| SELECT lower(name), cvterm_id, is_obsolete
                    FROM cvterm
                    WHERE cv_id = $cv_id
                    GROUP BY name, cvterm_id, is_obsolete
                    HAVING is_obsolete = max(is_obsolete) 
                  |;

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

    my $query = "SELECT type_id || '_' || subject_id || '_' || object_id || '_' || cv_id || '_' || pathdistance, cvtermpath_id ".
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

    my $query = "SELECT datname ".
    "FROM pg_database ".
    "WHERE datname = ? ";

    return $self->_get_results_ref($query, $database);
}

#----------------------------------------------------------------
# getForeignKeyConstraintsList()
#
#----------------------------------------------------------------
sub getForeignKeyConstraintsList {

    my $self = shift;

    my $query = "SELECT pgc.conname ".
    "FROM pg_constraint pgc, pg_namespace pgn ".
    "WHERE pgc.connamespace = pgn.oid ".
    "AND pgn.nspname != 'information_schema' ";

    return $self->_get_results_ref($query);
}

#----------------------------------------------------------------
# getForeignKeyConstraintAndTableList()
#
#----------------------------------------------------------------
sub getForeignKeyConstraintAndTableList {

    my $self = shift;

    my $query = "SELECT c.conname, t.tablename ".
    "FROM pg_constraint c, pg_class cl, pg_tables t ".
    "WHERE  c.conrelid = cl.oid ".
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

    my $query = "SELECT tablename ".
    "FROM pg_tables ".
    "WHERE schemaname = 'public' ";

    return $self->_get_results_ref($query);
}

=item $obj->get_cvtermpath_type_id_lookup()

B<Description:> Will execute query to retrieve all subject_id, object_id, type_id tuples from cvtermpath

B<Parameters:> None

B<Returns:> Perl DBI results array reference

=cut

sub get_cvtermpath_type_id_lookup {

    my($self) = @_;

    my $query = "SELECT subject_id || '_' || object_id, type_id ".
    "FROM cvtermpath ";

    print "Retrieving all cvtermpath subject_id, object_id, type_id tuples from cvtermpath\n";    

    return $self->_get_lookup_db($query);

}

sub _turnStatementCacheOff {

    my $self = shift;
    ## Nothing for now.

}

sub _turnStatementCacheOn {

    my $self = shift;
    ## Nothing for now.


}

1;
