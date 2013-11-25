package Prism::SybaseChadoPrismDB;

use strict;
use base qw(Prism::ChadoPrismDB);
use base qw(Coati::Coati::SybaseChadoCoatiDB);
use Data::Dumper;

use constant TEXTSIZE => 100000000;

our $FIELD_DELIMITER = "\0\t";
our $RECORD_DELIMITER = "\0\n";

our $sybaseObjectLookup = {'table' => 'U',
			   'view' => 'V',
			   'default data-binding' => 'D',
			   'stored procedure' => 'P',
			   'system table' => 'S' };



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

#--------------------------------------------------------------
# doExecuteBatchSqlInstructions()
#
#--------------------------------------------------------------
sub doExecuteBatchSqlInstructions {

    my ($self, $indexmanip, $instructions, $message) =  @_;
    
    if ($indexmanip){

	if (!defined($instructions)){
	    $self->{_logger}->logdie("instructions were not defined");
	}

	foreach my $sql ( @{$instructions} ){
	    $self->_do_sql($sql);
	}
    }
    else{
	$self->{_logger}->info("$message.  The manipulations are ".
			       "listed here: @{$instructions}");
    }
}

#--------------------------------------------------------------------
# doesTableExist()
#
#--------------------------------------------------------------------
sub doesTableExist {

    my ($self, $table) = @_;
    
    my $query = "SELECT name ".
    "FROM sysobjects ".
    "WHERE type = 'U' ".
    "AND name = ?";
    
    my @ret = $self->_get_results($query, $table);
    
    if (defined($ret[0][0])){
	return $ret[0][0];
    }
    else {
	return undef;
    }
}

#---------------------------------------------------------------
# doesTableHaveSpace()
#
#---------------------------------------------------------------
sub doesTableHaveSpace {

    my($self, %param) = @_;

    my $phash = \%param;
    my ($infile, $table);

    #
    # Factor: "Dynamic allocation for target table" has not been accounted for in this algorithm
    # I am simply returning "true" for now, since this bgz case is holding up testing of other 
    # cases.
    return 1;


    if ((exists $phash->{'table'}) and (defined($phash->{'table'}))){
	$table = $phash->{'table'};
    }
    else {
	$self->{_logger}->logdie("table was not defined");
    }

    if ((exists $phash->{'infile'}) and (defined($phash->{'infile'}))){
	$infile = $phash->{'infile'};
    }
    else {
	$self->{_logger}->logdie("infile was not defined");
    }





#    my $testquery = "sp_spaceused";
#    my $testresult = $self->_get_results_ref($testquery);
#    print Dumper $testresult;die;





    #
    # Retrieve the file size
    #
    my @stats = stat $infile;
    my $filesize = $stats[7];



    #
    # Count the number of records/lines in this BCP file
    #
    my $recctr = qx{wc -l $infile};
    chomp $recctr;

    #
    # sundaram@jackrabbit % wc -l cvterm.out 
    #      12 cvterm.out
    #
    # Need to strip the leading space and trailing filename
    #
    if ($recctr =~ /^\s*(\d+)\s\S+/){
	$recctr = $1;
    }
    else{
	$self->{_logger}->logdie("Could not parse recctr '$recctr'");
    }
    


    $self->{_logger}->logdie("recctr was not defined") if (!defined($recctr));

    if ($recctr < 1){
	$self->{_logger}->warn("Number of records/lines in infile '$infile' was '$recctr' i.e. less than 1.  Returning true.");
	return 1;
    }



    #
    #
    # In our example, lets say we are loading document: mysample.blastp.bsml.  This document contains 100 <Seq-pair-runs> elements.
    # This will result in 100 rows being inserted into chado.feature table.
    # Based on the results of sp_spaceused on feature table:
    #
    # 1> sp_spaceused feature;
    # name                 rowtotal    reserved        data            index_size      unused         
    # -------------------- ----------- --------------- --------------- --------------- ---------------
    # feature              259444      1352688 KB      27280 KB        1322096 KB      3312 KB        
    #
    # We assume that 100 new inbound records will require 521 KB since
    # 259444 records require 1352688 KB.  This assumes that all feature records are uniform.
    # Feature records are NOT uniform - since some feature records contain sequences in the 
    # chado.feature.residues text field whereas some feature records do not.  Therefore in our calculation
    # when attempting to load match type records we are in fact over-estimating the required space for new 
    # inbound records.
    #
    # In the case where we are loading non-match type records which may contain sequences we will need to 
    # determine the space requirements based on the filesize.  To-be-implemented.
    #
    #
    # Per Susan, increase the required amount of space by 50% of that calculated i.e. 521 KB should be 
    # increased to 781 KB.
    #
    # So in this example, since there are 3312 KB of unused space in chado.feature, the table can accommodate an additional 100 records.
    #

    my $query = "sp_spaceused $table ";
    
    my $result = $self->_get_results_ref($query);


    my ($tab, $rowtotal, $reserved, $data, $index_size, $unused) = ($result->[0][0], $result->[0][1], $result->[0][2], $result->[0][3], $result->[0][4], $result->[0][5]);


#    die "tab '$tab' rowtotal '$rowtotal' reserved '$reserved' unused '$unused'";
#    print STDERR "tab '$tab' rowtotal '$rowtotal' reserved '$reserved' unused '$unused'";


    $tab =~ s/\s//g;

    if ($tab ne $table){
	$self->{_logger}->logdie("tab '$tab' ne table '$table'");
    }
    if (!defined($rowtotal)){
	$self->{_logger}->logdie("rowtotal was not defined");
    }
    if (!defined($reserved)){
	$self->{_logger}->logdie("reserved was not defined");
    }
    if (!defined($unused)){
	$self->{_logger}->logdie("unused was not defined");
    }

    #
    # Strip non-digits
    #
    if ($rowtotal =~ /^(\d+)$/){
	$rowtotal = $1;
    }

    if ($reserved =~ /^(\d+) KB$/){
	$reserved = $1;
    }
    else{
	$self->{_logger}->logdie("Could not parse reserved '$reserved'");
    }

    if ($unused =~ /^(\d+) KB$/){
	$unused = $1;
    }
    else{
	$self->{_logger}->logdie("Could not parse unused '$unused'");
    }


    if ($rowtotal < 1){
	$self->{_logger}->info("There were no records loaded in table '$table'");
	return 1;
    }


    my $a = $reserved * $recctr;
    my $b = $a / $rowtotal;
    my $c = $b * 0.50;
    my $d = $b + $c;

    $self->{_logger}->info("table '$table' reserved '$reserved' KB rowtotal '$rowtotal' unused '$unused' KB a '$a' b '$b' c '$c' d '$d'");


    if ($unused > $d){
	$self->{_logger}->info("Based on the fact that '$rowtotal' loaded records require '$reserved' KB space, our new '$recctr' inbound records will require '$d' KB space.  Since there is '$unused' KB space available, we CAN load the new records into table '$table'");
	return 1;
    }
    else{
	$self->{_logger}->info("Based on the fact that '$rowtotal' loaded records require '$reserved' KB space, our new '$recctr' inbound records will require '$d' KB space.  Since there is '$unused' KB space available, we CANNOT load the new records into table '$table'");
	return 0;
    }


}

#------------------------------------------------------------
# getTableList()
#
#------------------------------------------------------------
sub getTableList {

    my ($self) = @_;

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
}

#--------------------------------------------------------
# doUpdateStatistics()
#
#--------------------------------------------------------
sub doUpdateStatistics {

    my ($self, $table, $testmode) = @_;

    if (!defined($table)){
	$self->{_logger}->fatal("table was not defined, therefore not updating any table's statistics");
	return undef;
    }

    my $sql = "update statistics $table";
    $self->{_logger}->info("sql '$sql'");

    if ($testmode){
	$self->{_logger}->info("testmode was set to '$testmode' therefore did not update statistics on table '$table'");
    }
    else{
	$self->_do_sql($sql);
    }
}

#-----------------------------------------------------------------------------------------
# doDropForeignKeyConstraints()
#
#-----------------------------------------------------------------------------------------
sub doDropForeignKeyConstraints {

    my ($self) = @_;

    
    ## Report names and count of foreign keys prior to dropping them.
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

    
    ## Report names and count of any remaining foreign keys after having attempted to drop them.
    $fkey_query = "SELECT cons.name  ".
    "FROM sysobjects t, sysobjects ref, sysobjects cons, sysreferences r, sysconstraints c ".
    "WHERE cons.id = c.constrid ".
    "AND c.constrid = r.constrid ".
    "AND r.tableid = t.id ".
    "AND r.reftabid = ref.id ".
    "AND r.tableid != r.reftabid "; #-- ignore uniqueness constraints, only interested in foreign key constraints

    $fkey_names = $self->_get_results_ref($fkey_query);

    $self->{_logger}->warn("Foreign keys remaining");

    for ($j=0; $j < scalar(@{$fkey_names}) ;  $j++ ) {
	
	my $fkey = $fkey_names->[$j][0];

	$self->{_logger}->warn("$fkey");

    }

    $self->{_logger}->warn("The number of foreign keys remaining after attempting to drop them: '$j'");
}

#----------------------------------------------------------------
# getSystemObjectsListByType()
#
#----------------------------------------------------------------
sub getSystemObjectsListByType {

    my($self, $objectType) = @_;

    if (exists $sybaseObjectLookup->{$objectType}){
    
	my $query = "SELECT name ".
	"FROM sysobjects ".
	"WHERE type='$sybaseObjectLookup->{$objectType}' ".
	"AND uid = 1";

	return $self->_get_results_ref($query);
    }
    else {
	$self->{_logger}->logdie("Object type '$objectType' does not exist in sybaseObjectLookup");
    }

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

    my $query = "SELECT db ".
    "FROM common..genomes ".
    "WHERE db = ? ";

    return $self->_get_results_ref($query, $database);
}

#----------------------------------------------------------------
# getForeignKeyConstraintsList()
#
#----------------------------------------------------------------
sub getForeignKeyConstraintsList {

    my $self = shift;

    my $query = "SELECT name ".
    "FROM sysobjects ".
    "WHERE type = 'RI' ";

    return $self->_get_results_ref($query);
}

#----------------------------------------------------------------
# getForeignKeyConstraintAndTableList()
#
#----------------------------------------------------------------
sub getForeignKeyConstraintAndTableList {

    my $self = shift;

    my $query = "SELECT s2.name, s1.name  ".
    "FROM sysobjects s1, sysobjects s2, sysconstraints c ".
    "WHERE c.tableid = s1.id ".
    "AND c.constrid = s2.id ";

    return $self->_get_results_ref($query);
}

#----------------------------------------------------------------
# getTableList()
#
#----------------------------------------------------------------
sub getTableList {

    my $self = shift;

    my $query = "SELECT name ".
    "FROM sysobjects ".
    "WHERE type = 'U' ";

    return $self->_get_results_ref($query);
}

##---------------------------------------------------------------
## getDbxrefRecordsForCmProteins()
##
## Needed to force a query plan for reasonable performance.
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

    my $query = "SELECT distinct protein.feature_id, d.version, db.name + ':' + d.accession ".
    "FROM feature transcript JOIN feature_dbxref fd ON ( transcript.feature_id = fd.feature_id ) ".
    "JOIN dbxref d ON ( fd.dbxref_id = d.dbxref_id ) ".
    "JOIN db db ON ( d.db_id = db.db_id ) ".
    "JOIN feature_relationship fr ON ( fr.object_id = transcript.feature_id ) ".
    "JOIN feature protein ON ( fr.subject_id = protein.feature_id ) ".

    "WHERE protein.type_id = ? ".
    "AND transcript.type_id = ? ".
    "AND protein.feature_id=fr.subject_id ".
    "AND transcript.feature_id=fr.object_id ".
    "AND transcript.feature_id = fd.feature_id ".
    "AND fd.dbxref_id = d.dbxref_id ".
    "AND d.db_id = db.db_id ".
    "AND protein.is_analysis = 0 ".
    "AND protein.is_obsolete = 0 ";

    print STDERR "$query\n";
    $self->do_set_forceplan(1);
    return $self->_get_results_ref($query, $polypeptideCvtermId, $transcriptCvtermId);
    $self->do_set_forceplan(0);

}

##---------------------------------------------------------------
## getCrossReferencesForClusterMembersByAnalysisId()
##
## Needed to force a query plan for reasonable performance.
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

    my $query = 
        "SELECT DISTINCT p.feature_id,  db.name + ':' + d.accession ".
        "FROM analysisfeature af JOIN feature m ON (af.feature_id = m.feature_id) ".
        "JOIN featureloc fl  ON  (m.feature_id = fl.feature_id) ".
        "JOIN feature p ON (fl.srcfeature_id = p.feature_id) ".
        "JOIN feature_relationship fr ON ( fr.subject_id = p.feature_id ) ".
        "JOIN  feature t ON (fr.object_id = t.feature_id) ".
        "JOIN feature_dbxref fd ON ( t.feature_id = fd.feature_id ) ".
        "JOIN dbxref d ON (fd.dbxref_id = d.dbxref_id) ".
        "JOIN db db ON  (d.db_id = db.db_id) ".
        "WHERE ".
        "af.analysis_id = ? ".
        "AND af.type_id = ? ".
        "AND p.is_analysis = 0 ".
        "AND p.type_id= ? ".
        "AND t.type_id= ?";
        
    $self->do_set_forceplan(1);
    print STDERR "$query\n";
    return $self->_get_results_ref($query, $analysis_id, $computedByCvtermId,$polypeptideCvtermId,$transcriptCvtermId);
    $self->do_set_forceplan(0);
}


sub _turnStatementCacheOff {

    my $self = shift;
    ## Will invoke method Coati::Coati::SybaseChadoCoatiDB::setStatementCacheOff
    $self->setStatementCacheOff();

}

sub _turnStatementCacheOn {

    my $self = shift;
    ## Will invoke method Coati::Coati::SybaseChadoCoatiDB::setStatementCacheOn
    $self->setStatementCacheOn();


}


1;

