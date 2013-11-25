package Prism::BulkMysqlChadoPrismDB;

use strict;
use base qw(Coati::Coati::BulkMysqlChadoCoatiDB Prism::MysqlChadoPrismDB Prism::BulkChadoPrismDB );

my $MODNAME = "BulkMysqlChadoPrismDB.pm";

sub do_test_function {
    my ($self, $feat_name,$prot_seq,$locus) = @_;
    $self->_trace if $self->{_debug};

    #$self->{_coati}->_add_row("test_table",$feat_name,$locus,$prot_seq);
}

## these are used as defaults only.   they can still be passed to doBulkLoadTable
our $RECORD_DELIMITER = '\n'; 
our $FIELD_DELIMITER = '\t'; 

 
#------------------------------------------------------------------
# doBulkLoadTable()
#
#------------------------------------------------------------------
sub doBulkLoadTable {

    my ($self, %args) = @_;

    #$self->{_logger}->logdie("This subroutine has not been implemented for MySQL yet.  Seeing this message makes it your job to write it.");

    my $infile          = $args{'infile'};
    my $table           = $args{'table'};
    my $server          = $args{'server'};
    my $database        = $args{'database'};
    my $username        = $args{'username'};
    my $password        = $args{'password'};
    my $rowdelimiter    = $args{'rowdelimiter'};
    my $fielddelimiter  = $args{'fielddelimiter'};
    my $batchsize       = $args{'batchsize'};
    my $bcplogfile      = $args{'bcplogfile'};
    my $featuretextsize = $args{'textsize'};
    my $testmode        = $args{'testmode'};
    my $printCommandsOnly = $args{'print_commands_only'};

    ## if delimiters weren't passed, check the defaults
    if ( ! defined $rowdelimiter ) {
        $rowdelimiter = $RECORD_DELIMITER;
    }
    
    if ( ! defined $fielddelimiter ) {
        $fielddelimiter = $FIELD_DELIMITER;
    }

    ## info here:
    #   http://dev.mysql.com/doc/refman/5.0/en/load-data.html
    my $sql = qq{
        LOAD DATA LOCAL INFILE '$infile'
        INTO TABLE $table
        FIELDS TERMINATED BY '$fielddelimiter'
        LINES TERMINATED BY '$rowdelimiter'
    };

    print STDERR "running SQL:\n $sql\n";

    if ($printCommandsOnly){
        print $sql . "\n";
        return 0;
    }
    
    if ($testmode){
        $self->{_logger}->info("testmode was set to '$testmode' therefore no records ".
                       "were inserted into the database - SQL was ".
                       "'$sql'");
        return 0;
    }
    
    $self->{_logger}->info("SQL: $sql");
        
    ## Real attempt at loading
    
    ## shouldn't be calling private methods here.  too bad there isn't an instance one.
    ## - JO
    $self->_do_sql($sql);
    
    ## we're supposed to return the number of rows loaded here.  if we had done this
    ##  within the mysql terminal it would give us a message like:
    ##
    ##  Records: 3  Deleted: 0  Skipped: 0  Warnings: 13
    ##
    ## DBD::mysql actually stores this, immediately after the LOAD DATA statement, 
    ##  within 'info' on the dbh.  we'll parse it from that.
    my $rows_loaded = undef;
    
    if ( $self->{_dbh}->{info} =~ /Records\:\s+(\d+)/ ) {
        $rows_loaded = $1;
    }
    
    if ( defined $rows_loaded ) {
        return $rows_loaded;
    } else {
        $self->{_logger}->logdie("Unable to determine number of rows loaded into database.  Do NOT just re-execute or duplicate rows could be loaded!");
    }
}


##------------------------------------------------------------
## bcpError()
##
##------------------------------------------------------------
sub bcpError {

    my ($error) = @_;

    $error = $error >> 8;
    
    my $retVal = ($error != 0) ? 1 : 0;

    return $retVal;    
}

#--------------------------------------------------------------
# doBulkDumpTable()
#
#--------------------------------------------------------------
sub doBulkDumpTable {

    my ($self, %args) = @_;
    
    $self->{_logger}->logdie("This subroutine has not been implemented for MySQL yet.  Seeing this message makes it your job to write it.");

    my $outfile         = $args{'outfile'};
    my $table           = $args{'table'};
    my $server          = $args{'server'};
    my $database        = $args{'database'};
    my $username        = $args{'username'};
    my $password        = $args{'password'};
    my $rowdelimiter    = $args{'rowdelimiter'};
    my $fielddelimiter  = $args{'fielddelimiter'};
    my $bcplogfile      = $args{'bcplogfile'};
    my $featuretextsize = $args{'textsize'};

    $self->{_logger}->logdie("Not implemented yet!");

    my $bcp;
    if ((defined($ENV{'BCP'})) and (defined ($ENV{'BCP'}))){
    $bcp = $ENV{'BCP'};
    }

    my $execstring;# = "$bcp $database..$table out $outfile -S $server -U $username -P $password -c -b $batchsize -e $bcplogfile -r \"$rowdelimiter\" -t \"$fielddelimiter\" -T 1000000000";

    $self->{_logger}->info("execstring : $execstring");
    my $stat = qx($execstring);

    #
    # Get the total number of rows copied to the Sybase server as reported by the BCP utility
    #
    my $rowcount;
    if ($stat =~ /(\d+)\s+rows copied\./){
    $rowcount = $1;
    if (!defined($rowcount)){
        $self->{_logger}->logdie("row count was not defined while processing table '$table'");
    }    
    }
    else{
    $self->{_logger}->logdie("Could not parse stat '$stat' to retrieve the number of rows that were copied");
    }

    my $error = $?;
    $error = $error >> 8;
    $self->{_logger}->logdie("BCP reported an error value of $error, stat was: $stat") if ($error != 0);
        
    return $rowcount;
    
}


## The do_store_new_<table> methods are inserted here because
## BulkMysqlHelper.pm methods will only substitute the 
## MysqlQL null value character \N for fields that are not
## defined.  The equivalent do_store_new_<table> methods in
## BulkChadoPrismDB.pm store empty string '' in place of any
## undefined values.

##------------------------------------------------------------------------------
## do_store_new_db()
##
##------------------------------------------------------------------------------
sub do_store_new_db {

    my ($self, %params) = @_;

    my ($name, $description, $urlprefix, $url);

    if ( defined $params{'name'}){
    $name = $params{'name'};
    }
    else {
    $self->{_logger}->error("name was not defined. Cannot insert record into chado.db");
    return undef;
    } 

    $description = ( defined $params{'description'}) ? $params{'description'} : undef ;

    $urlprefix = ( defined $params{'urlprefix'}) ? $params{'urlprefix'} : undef ;

    $url =( defined $params{'url'}) ? $params{'url'} : undef ;

    
    ##
    ## Check if db_id was previously created during this current session
    ##
    my $db_id = $self->{_id_manager}->lookupId("db", "$name");
    if (!defined($db_id)){
    ##
    ## db_id was not previously created, therefore generate and store in chado.cvterm_dbxref
    ##
    $db_id = $self->{_id_manager}->nextId("db", "$name");
    if (!defined($db_id)){
        ##
        ## Could not generate db_id 
        ##
        $self->{_logger}->error("Could not retrieve db_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was \"db\", \"$name\"\nCannot ".
                    "insert record into chado.db for name '$name' description ".
                    "'$description' urlprefix '$urlprefix' url '$url'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.db
        ##
        $self->_add_row(                
                "db",           ##  Sybase data types:             MysqlQL data types:
                $db_id,         ##  numeric(9,0) not null
                $name,          ##  varchar(255) not null
                $description,   ##  varchar(255)     null
                $urlprefix,     ##  varchar(255)     null
                $url            ##  varchar(255)     null
                );
    }
    }

    return $db_id;

}##end sub do_store_new_db {



##---------------------------------------------------------------------------------------------------------------
## do_store_new_feature()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_feature {

    my ($self, %params) = @_;
    
    my ($dbxref_id, $organism_id, $name, $uniquename, $residues, $seqlen,
    $md5checksum, $type_id, $is_analysis, $is_obsolete, $timeaccessioned,
    $timelastmodified);

    if ( defined $params{'organism_id'}){
    $organism_id = $params{'organism_id'};
    }
    else {
    $self->{_logger}->error("organism_id was not defined.  Cannot insert record into chado.feature");
    return undef;
    }

    if (defined $params{'uniquename'}){
    $uniquename = $params{'uniquename'};
    }
    else {
    $self->{_logger}->error("uniquename was not defined. ".
                "Cannot insert record into chado.feature");
    return undef;
    }

    if ( defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
    $self->{_logger}->error("type_id was not defined.  ".
                "Cannot insert record into chado.feature");
    return undef;
    }

    if ( defined $params{'timeaccessioned'}){
    $timeaccessioned = $params{'timeaccessioned'};
    }
    else {
    $self->{_logger}->error("timeaccessioned was not defined.  ".
                "Cannot insert record into chado.feature");
    return undef;
    }
    if ( defined $params{'timelastmodified'}){
    $timelastmodified = $params{'timelastmodified'};
    }
    else {
    $self->{_logger}->error("timelastmodified was not defined.  ".
                "Cannot insert record into chado.feature");
    return undef;
    }


    $dbxref_id = ( defined $params{'dbxref_id'}) ? $params{'dbxref_id'} : undef ;

    $name = ( defined $params{'name'}) ? $params{'name'} : undef ;

    if ( defined $params{'residues'}){
    $residues = $params{'residues'};
    if (lc($residues) eq 'null'){
        ## If residues is set to either string NULL or null, then set residues equal to empty string. (bgz3404)
        $residues = undef;
    }
    }
    else {
    $residues = undef;
    }

    $seqlen = ( defined $params{'seqlen'}) ? $params{'seqlen'} : undef ;

    $md5checksum = ( defined $params{'md5checksum'}) ?  $params{'md5checksum'} : undef ;

    $is_analysis = ( defined $params{'is_analysis'}) ? $params{'is_analysis'} : 0;

    $is_obsolete = ( defined $params{'is_obsolete'}) ? $params{'is_obsolete'} : 0;

    my $seed = "$organism_id:$uniquename:$type_id";

    my $feature_id = $self->{_id_manager}->lookupId("feature", $seed);

    if (!defined($feature_id)){
    $feature_id = $self->{_id_manager}->nextId("feature", $seed);
    
    if (!defined($feature_id)){
        $self->{_logger}->error("Could not retrieve feature_id from Coati::IdManager ".
                    "lookup, nor could it be generated.  Seed was 'feature', ".
                    "'$seed'\nCannot insert record ".
                    "into chado.feature for dbxref '$dbxref_id' organism_id ".
                    "'$organism_id' name '$name' uniquename '$uniquename' residues ".
                    "'$residues' seqlen '$seqlen' md5checksum '$md5checksum' type_id ".
                    "'$type_id' is_analysis '$is_analysis' timeaccessioned ".
                    "'$timeaccessioned' timelastmodified '$timelastmodified'");
    }
    else{
        $self->_add_row(
                "feature",         ##  Sybase data types:                                          MysqlQL data types:
                $feature_id,       ##  numeric(9,0)                             NOT NULL
                $dbxref_id,        ##  numeric(9,0)                                 NULL
                $organism_id,      ##  numeric(9,0)                             NOT NULL
                $name,             ##  varchar(255)                                 NULL
                $uniquename,       ##  varchar(50)                              NOT NULL
                $residues,         ##  text                                         NULL
                $seqlen,           ##  numeric(9,0)                                 NULL
                $md5checksum,      ##  char(32)                                     NULL
                $type_id,          ##  numeric(9,0)                             NOT NULL 
                $is_analysis,      ##  BIT  DEFAULT 0                           NOT NULL
                $is_obsolete,      ##  BIT  DEFAULT 0                           NOT NULL
                $timeaccessioned,  ##  timestamp    DEFAULT 'current_timestamp' NOT NULL
                $timelastmodified  ##  timestamp    DEFAULT 'current_timestamp' NOT NULL
                );
    }
    }


    return $feature_id;

}##end sub do_store_new_feature {


##---------------------------------------------------------------------------------------------------------------
## do_store_new_cvterm_dbxref()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_cvterm_dbxref {

    my ($self, %params) = @_;
 
    my ($dbxref_id, $cvterm_id, $is_for_definition);

    if (defined $params{'dbxref_id'}){
    $dbxref_id = $params{'dbxref_id'};
    }
    else {
    $self->{_logger}->error("dbxref_id was not defined.  ".
                "Cannot insert record into chado.cvterm_dbxref");
    return undef;
    }
    if (defined $params{'cvterm_id'}){
    $cvterm_id = $params{'cvterm_id'};
    }
    else {
    $self->{_logger}->error("cvterm_id was not defined.  ".
                "Cannot insert record into chado.cvterm_dbxref");
    return undef;
    }

    $is_for_definition = (defined $params{'is_for_definition'}) ? $params{'is_for_definition'} : 0;

    my $seed = "$dbxref_id:$cvterm_id";

    ##
    ## Check if cvterm_dbxref_id was previously created during this current session
    ##
    my $cvterm_dbxref_id = $self->{_id_manager}->lookupId("cvterm_dbxref", $seed);

    if (!defined($cvterm_dbxref_id)){
    ##
    ## cvterm_dbxref_id was not previously created, therefore generate and store in chado.cvterm_dbxref
    ##
    $cvterm_dbxref_id = $self->{_id_manager}->nextId("cvterm_dbxref", $seed);
    if (!defined($cvterm_dbxref_id)){
        ##
        ## Could not generate cvterm_dbxref_id 
        ##
        $self->{_logger}->error("Could not retrieve cvterm_dbxref_id from Coati::IdManager ".
                    "lookup, nor could it be generated.  Seed was 'cvterm_dbxref', ".
                    "'$seed'\nCannot insert record into ".
                    "chado.cvterm_dbxref for cvterm_id '$cvterm_id' dbxref_id '$dbxref_id'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.cvterm_dbxref
        ##
        $self->_add_row(
                "cvterm_dbxref",    ## Sybase data types:  MysqlQL data types:
                $cvterm_dbxref_id,  ## serial not null
                $cvterm_id,         ## int not null 
                $dbxref_id,         ## int not null
                $is_for_definition
                );
    }
    }

    return $cvterm_dbxref_id;

}##end sub do_store_new_cvterm_dbxref {

##---------------------------------------------------------------------------------------------------------------
## do_store_new_dbxref()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_dbxref {

    my ($self, %params) = @_;

    my ($db_id, $accession, $version, $description);

    if (defined $params{'db_id'}){
    $db_id = $params{'db_id'};
    }
    else {
    $self->{_logger}->error("db_id was not defined.  Cannot insert record into chado.dbxref");
    return undef;
    }
    if (defined $params{'accession'}){
    $accession = $params{'accession'};
    }
    else {
    $self->{_logger}->error("accession was not defined.  Cannot insert record into chado.dbxref");
    return undef;
    }

    $version = (defined $params{'version'}) ?  $params{'version'} : undef;

    $description = (defined $params{'description'}) ? $params{'description'} : undef;

    my $seed = "$db_id:$accession:$version";
    ##
    ## Check if dbxref_id was previously created during this current session
    ##
    my $dbxref_id = $self->{_id_manager}->lookupId("dbxref", $seed);
    if (!defined($dbxref_id)){
    ##
    ## dbxref_id was not previously created, therefore generate and store in chado.cvterm_dbxref
    ##
    $dbxref_id = $self->{_id_manager}->nextId("dbxref", $seed);
    if (!defined($dbxref_id)){
        ##
        ## Could not generate dbxref_id 
        ##
        $self->{_logger}->error("Could not retrieve dbxref_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'dbxref', '$seed' ".
                    "\nCannot insert record into ".
                    "chado.dbxref for db_id '$db_id' accession '$accession' ".
                    "version '$version' description '$description'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.db
        ##
        $self->_add_row(
                "dbxref",      ##  Sybase data types:                    MysqlQL data types:
                $dbxref_id,    ##  numeric(9,0)  NOT NULL
                $db_id,        ##  numeric(9,0)  NOT NULL
                $accession,    ##  varchar(50)   NOT NULL
                $version,      ##  varchar(50)   DEFAULT undef NOT NULL
                $description   ##  varchar(255)  NULL
                );
    }
    }

    return $dbxref_id;

}##end sub do_store_new_dbxref {


##---------------------------------------------------------------------------------------------------------------
## do_store_new_organism()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_organism {

    my ($self, %params) = @_;

    my ($abbreviation, $genus, $species, $common_name, $comment);

    if (defined $params{'genus'}){
    $genus = $params{'genus'};
    }
    else {
    $self->{_logger}->error("genus was not defined.  Cannot insert record into chado.organism");
    return undef;
    }
    if (defined $params{'species'}){
    $species = $params{'species'};
    }
    else {
    $self->{_logger}->error("species was not defined.  Cannot insert record into chado.organism");
    return undef;
    }

    $abbreviation = (defined $params{'abbreviation'}) ? $params{'abbreviation'} : undef;

    $common_name = (defined $params{'common_name'}) ? $params{'common_name'} : undef;

    $comment = (defined $params{'comment'}) ? $params{'comment'} : undef;


    my $seed = "$genus:$species";

    ##
    ## Check if organism_id was previously created during this current session
    ##
    my $organism_id = $self->{_id_manager}->lookupId("organism", $seed);
    if (!defined($organism_id)){
    ##
    ## organism_id was not previously created, therefore generate and store in chado.cvterm_organism
    ##
    $organism_id = $self->{_id_manager}->nextId("organism", $seed);
    if (!defined($organism_id)){
        ##
        ## Could not generate organism_id 
        ##
        $self->{_logger}->error("Could not retrieve organism_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'organism', '$seed' ".
                    "\nCannot insert record into chado.organism for abbreviation '$abbreviation' ".
                    "genus '$genus' species '$species' common_name '$common_name' comment '$comment'");
        return undef;
    }
    else{

        $self->_add_row(
                "organism",   ##  Sybase data types:                 MysqlQL data types:
                $organism_id, ##  numeric(9,0)  NOT NULL
                $abbreviation,##  varchar(50)   NOT NULL
                $genus,       ##  varchar(50)   NOT NULL
                $species,     ##  varchar(50)   NOT NULL
                $common_name, ##  varchar(100)  NULL
                $comment      ##  varchar(255)  NULL
                );
    }
    }

    return $organism_id;


}##end sub do_store_new_organism {



##---------------------------------------------------------------------------------------------------------------
## do_store_new_organism_dbxref()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_organism_dbxref {

    my ($self, %params) = @_;

    my ($organism_id, $dbxref_id);

    if (defined $params{'organism_id'}){
    $organism_id = $params{'organism_id'};
    }
    else {
    $self->{_logger}->error("organism_id was not defined.  Cannot insert record into chado.organism_dbxref");
    return undef;
    }
    if (defined $params{'dbxref_id'}){
    $dbxref_id = $params{'dbxref_id'};
    }
    else {
    $self->{_logger}->error("dbxref_id was not defined.  Cannot insert record into chado.organism_dbxref");
    return undef;
    }

    my $seed = "$organism_id:$dbxref_id";

    ##
    ## Check if organism_dbxref_id was previously created during this current session
    ##
    my $organism_dbxref_id = $self->{_id_manager}->lookupId("organism_dbxref", $seed);
    if (!defined($organism_dbxref_id)){
    ##
    ## organism_dbxref_id was not previously created, therefore generate and store in chado.organism_dbxref
    ##
    $organism_dbxref_id = $self->{_id_manager}->nextId("organism_dbxref", $seed);
    if (!defined($organism_dbxref_id)){
        ##
        ## Could not generate organism_dbxref_id 
        ##
        $self->{_logger}->error("Could not retrieve organism_dbxref_id from Coati::IdManager ".
                    "lookup, nor could it be generated.  Seed was 'organism_dbxref', ".
                    "'$seed'\nCannot insert record into chado.organism_dbxref ".
                    "for organism_id '$organism_id' dbxref_id '$dbxref_id'");
        return undef;
    }
    else{
        $self->_add_row(
                "organism_dbxref",      ##  Sybase data types:               MysqlQL data types:
                $organism_dbxref_id,    ##  numeric(9,0)  NOT NULL
                $organism_id,           ##  numeric(9,0)  NOT NULL
                $dbxref_id,             ##  numeric(9,0)  NOT NULL
                );

    }
    }

    return $organism_dbxref_id;


}##end sub do_store_new_organism_dbxref {


##---------------------------------------------------------------------------------------------------------------
## do_store_new_analysis()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_analysis {

    my ($self, %params) = @_;

    my ($name, $description, $program, $programversion, $algorithm, $sourcename, $sourceversion,
    $sourceuri, $timeexecuted);

    if (defined $params{'program'}){
    $program = $params{'program'};
    }
    else {
    $self->{_logger}->error("program was not defined.  Cannot insert record into chado.analysis");
    return undef;
    }
    if (defined $params{'programversion'}){
    $programversion = $params{'programversion'};
    }
    else {
    $self->{_logger}->error("programversion was not defined.  Cannot insert record into chado.analysis");
    return undef;
    }

    if (defined $params{'timeexecuted'}){
    $timeexecuted = $params{'timeexecuted'};
    }
    else {
    $self->{_logger}->error("timeexecuted was not defined.  Cannot insert record into chado.analysis");
    return undef;
    }

    $name = (defined $params{'name'}) ? $params{'name'} : undef;

    $description = (defined $params{'description'}) ? $params{'description'} : undef;

    $algorithm = (defined $params{'algorithm'}) ? $params{'algorithm'} : undef;

    $sourcename = (defined $params{'sourcename'}) ? $params{'sourcename'} : undef;

    $sourceversion = (defined $params{'sourceversion'}) ? $params{'sourceversion'} : undef;

    $sourceuri = (defined $params{'sourceuri'}) ? $params{'sourceuri'} : undef;


    my $seed = "$program:$programversion:$sourcename";

    ##
    ## Check if analysis_id was previously created during this current session
    ##
    my $analysis_id = $self->{_id_manager}->lookupId("analysis", $seed);
    if (!defined($analysis_id)){
    ##
    ## analysis_id was not previously created, therefore generate and store in chado.analysis
    ##
    $analysis_id = $self->{_id_manager}->nextId("analysis", $seed);
    if (!defined($analysis_id)){
        ##
        ## Could not generate analysis_id 
        ##
        $self->{_logger}->error("Could not retrieve analysis_id from Coati::IdManager lookup, nor ".
                    "could it be generated.  Seed was 'analysis', '$seed' ".
                    "\nCannot insert record into ".
                    "chado.analysis for name '$name' description '$description' program ".
                    "'$program' programversion '$programversion' algorithm '$algorithm' ".
                    "sourcename '$sourcename' sourceversion '$sourceversion' sourceuri ".
                    "'$sourceuri' timeexecuted '$timeexecuted'");
        return undef;
    }
    else{
        $self->_add_row(
                "analysis",         ##  Sybase data types:                                MysqlQL data types:
                $analysis_id,       ##  numeric(9,0) NOT NULL
                $name,              ##  varchar(255)     NULL
                $description,       ##  varchar(255)     NULL
                $program,           ##  varchar(50)  NOT NULL
                $programversion,    ##  varchar(50)  NOT NULL
                $algorithm,         ##  varchar(50)      NULL
                $sourcename,        ##  varchar(255)     NULL
                $sourceversion,     ##  varchar(50)      NULL
                $sourceuri,         ##  varchar(255)     NULL
                $timeexecuted,      ##  datetime DEFAULT 'current_timestamp' NOT NULL
                );
     }
    }

    return $analysis_id;


}##end sub do_store_new_analysis {


##---------------------------------------------------------------------------------------------------------------
## do_store_new_feature_dbxref()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_feature_dbxref {

    my ($self, %params) = @_;

    my ($feature_id, $dbxref_id, $is_current);

    if (defined $params{'feature_id'}){
    $feature_id = $params{'feature_id'};
    }
    else {
    $self->{_logger}->error("feature_id was not defined.  Cannot insert record into chado.feature_dbxref");
    return undef;
    }
    if (defined $params{'dbxref_id'}){
    $dbxref_id = $params{'dbxref_id'};
    }
    else {
    $self->{_logger}->error("dbxref_id was not defined. Cannot insert record into chado.feature_dbxref");
    return undef;
    }
    
    $is_current = (defined $params{'is_current'}) ? $params{'is_current'} : 1;

    my $seed = "$feature_id:$dbxref_id";

    ##
    ## Check if feature_dbxref_id was previously created during this current session
    ##
    my $feature_dbxref_id = $self->{_id_manager}->lookupId("feature_dbxref", $seed);
    if (!defined($feature_dbxref_id)){
    ##
    ## feature_dbxref_id was not previously created, therefore generate and store in chado.feature_dbxref
    ##
    $feature_dbxref_id = $self->{_id_manager}->nextId("feature_dbxref", $seed);
    if (!defined($feature_dbxref_id)){
        ##
        ## Could not generate feature_dbxref_id 
        ##
        $self->{_logger}->error("Could not retrieve feature_dbxref_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'feature_dbxref', '$seed' ".
                    "\nCannot insert record into ".
                    "chado.feature_dbxref for feature_id '$feature_id' dbxref_id ".
                    "'$dbxref_id' is_current '$is_current'");
        return undef;
    }
    else{

        $self->_add_row(
                "feature_dbxref",   ##  Sybase data types:                      MysqlQL data types:
                $feature_dbxref_id, ##  numeric(9,0)  NOT NULL
                $feature_id,        ##  numeric(9,0)  NOT NULL
                $dbxref_id,         ##  numeric(9,0)  NOT NULL
                $is_current,        ##  varchar(6)    DEFAULT 'true' NOT NULL
                );


    }
    }

    return $feature_dbxref_id;


}##end sub do_store_new_feature_dbxref {

##---------------------------------------------------------------------------------------------------------------
## do_store_new_feature_cvterm()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_feature_cvterm {

    my ($self, %params) = @_;

    my ($feature_id, $cvterm_id, $pub_id, $is_not);

    if (defined $params{'feature_id'}){
    $feature_id = $params{'feature_id'};
    }
    else {
    $self->{_logger}->error("feature_id was not defined.  Cannot insert record into chado.feature_cvterm");
    return undef;
    }
    if (defined $params{'cvterm_id'}){
    $cvterm_id = $params{'cvterm_id'};
    }
    else {
    $self->{_logger}->error("cvterm_id was not defined. Cannot insert record into chado.feature_cvterm");
    return undef;
    }
    if (defined $params{'pub_id'}){
    $pub_id = $params{'pub_id'};
    }
    else {
    $self->{_logger}->error("pub_id was not defined. Cannot insert record into chado.feature_cvterm");
    return undef;
    }

    $is_not = (defined $params{'is_not'}) ? $params{'is_not'} : 0;

    my $seed = "$feature_id:$cvterm_id:$pub_id";

    ##
    ## Check if feature_cvterm_id was previously created during this current session
    ##
    my $feature_cvterm_id = $self->{_id_manager}->lookupId("feature_cvterm", $seed);

    if (!defined($feature_cvterm_id)){
    ##
    ## feature_cvterm_id was not previously created, therefore generate and store in chado.organism_dbxref
    ##
    $feature_cvterm_id = $self->{_id_manager}->nextId("feature_cvterm", $seed);
    if (!defined($feature_cvterm_id)){
        ##
        ## Could not generate feature_cvterm_id 
        ##
        $self->{_logger}->error("Could not retrieve feature_cvterm_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'feature_cvterm', '$seed' ".
                    "\nCannot insert record into ".
                    "chado.feature_cvterm for feature_id '$feature_id' cvterm_id ".
                    "'$cvterm_id' pub_id '$pub_id' is_not '$is_not'");
        return undef;
    }
    else{

        $self->_add_row(
                "feature_cvterm",    ##  datatype:
                $feature_cvterm_id,  ##  NUMERIC(9,0)  NOT NULL
                $feature_id,         ##  numeric(9,0)  NOT NULL
                $cvterm_id,          ##  numeric(9,0)      NULL
                $pub_id,             ##  numeric(9,0)  NOT NULL
                $is_not              ##  bit           NOT NULL
                );
        

    }
    }

    return $feature_cvterm_id;


}##end sub do_store_new_feature_cvterm {


##---------------------------------------------------------------------------------------------------------------
## do_store_new_featureprop()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_featureprop{

    my ($self, %params) = @_;

    my ($feature_id, $type_id, $value, $rank);

    if (defined $params{'feature_id'}){
    $feature_id = $params{'feature_id'};
    }
    else {
    $self->{_logger}->error("feature_id was not defined.  Cannot insert record into chado.featureprop");
    return undef;
    }
    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
    $self->{_logger}->error("type_id was not defined.  Cannot insert record into chado.featureprop");
    return undef;
    }
    if (defined $params{'value'}){
    $value = $params{'value'};
    }
    else {
    $self->{_logger}->error("value was not defined.  Cannot insert record into chado.featureprop");
    return undef;
    }

    $rank = (defined $params{'rank'}) ? $params{'rank'} : 0;


    ##
    ## Check if featureprop_id was previously created during this current session
    ##
    my $featureprop_id;

    do {
    $featureprop_id = $self->{_id_manager}->lookupId("featureprop", "$feature_id:$type_id:$rank");

    } while ((defined($featureprop_id)) && (++$rank));


    if (!defined($featureprop_id)){
    ##
    ## featureprop_id was not previously created, therefore generate and store in chado.featureprop
    ##
    $featureprop_id = $self->{_id_manager}->nextId("featureprop", "$feature_id:$type_id:$rank");

    if (!defined($featureprop_id)){
        ##
        ## Could not generate featureprop_id 
        ##
        $self->{_logger}->error("Could not retrieve featureprop_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'featureprop', ".
                    "'$feature_id:$type_id:$rank' \nCannot insert record into ".
                    "chado.featureprop for feature_id '$feature_id' type_id '$type_id' ".
                    "value '$value' rank '$rank'");
        return undef;
    }
    else{

        my $length  = length($value);
        if ($length > 1000){
        my $oldvalue = $value;
        $value = substr($oldvalue,0,999);
        $self->{_logger}->warn("Had to truncate the value since was exceeding the allocated ".
                       "field length (1000).  The length of value was '$length'. ".
                       "Shortened value\n'$oldvalue'\nto\n'$value'");
        }


        $self->_add_row(
                "featureprop",      ##  Sybase data types:                    MysqlQL data types:
                $featureprop_id,    ##  numeric(9,0)  NOT NULL
                $feature_id,        ##  numeric(9,0)  NOT NULL
                $type_id,           ##  numeric(9,0)  NOT NULL
                $value,             ##  varchar(1000) DEFAULT undef NOT NULL
                $rank               ##  varchar(50)  DEFAULT undef NOT NULL
                );

    }
    }
    else{
    $self->{_logger}->logdie("featureprop_id '$featureprop_id' was created previously ".
                 "during this current session for feature_id '$feature_id' ".
                 "type_id '$type_id' value '$value' rank '$rank'");
    }

    return $featureprop_id;


}##end sub do_store_new_featureprop {



##---------------------------------------------------------------------------------------------------------------
## do_store_new_featureloc()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_featureloc{

    my ($self, %params) = @_;

    my ($feature_id, $srcfeature_id, $fmin, $is_fmin_partial, $fmax, $is_fmax_partial,
    $strand, $phase, $residue_info, $locgroup, $rank, $legacy);

    if (defined $params{'feature_id'}){
    $feature_id = $params{'feature_id'};
    }
    else {
    $self->{_logger}->error("feature_id was not defined.  Cannot insert record into chado.featureloc");
    return undef;
    }
    if (defined $params{'locgroup'}){
    $locgroup = $params{'locgroup'};
    }
    else {
    $self->{_logger}->logdie("locgroup was not defined.  Cannot insert record into chado.featureloc");
    }

    if (defined $params{'rank'}){
    $rank = $params{'rank'};
    }
    else {
    $self->{_logger}->logdie("rank was not defined.  Cannot insert record into chado.featureloc");
    }
    
    $legacy = (defined $params{'legacy'}) ? $params{'legacy'} : undef;


    $srcfeature_id = (defined $params{'srcfeature_id'}) ? $params{'srcfeature_id'} : undef;

    if (defined $params{'fmin'}){

    $fmin = $params{'fmin'};

    if (defined($legacy) and $legacy eq '1'){
        ## convert legacy database end5 value into space-based coordinate
        $fmin--;
    }
    }
    else {
    $fmin = undef;
    }

    $is_fmin_partial = (defined $params{'is_fmin_partial'}) ? $params{'is_fmin_partial'} : 0;
    
    $fmax = (defined $params{'fmax'}) ? $params{'fmax'} : undef;
    
    $is_fmax_partial = (defined $params{'is_fmax_partial'}) ? $params{'is_fmax_partial'} : 0;

    $strand = (defined $params{'strand'}) ? $params{'strand'} : undef;

    $phase = (defined $params{'phase'}) ? $params{'phase'} : undef;

    if (defined $params{'residue_info'}){
    $residue_info = $params{'residue_info'};
    my $length  = length($residue_info);
    if ( $length > 7500 ){
        my $oldResidueInfo = $residue_info;
        $residue_info = substr($oldResidueInfo,0,7499);
        $self->{_logger}->warn("Had to truncate the residue_info since was exceeding the allocated ".
                   "field length (7500).  The length of value was '$length'. ".
                   "Shortened value from\n'$oldResidueInfo'\nto\n'$residue_info'");
    }
    }
    else {
    $residue_info = '';
    }
    

    my $seed = "$feature_id:$locgroup:$rank";

    ##
    ## Check if featureloc_id was previously created during this current session
    ##
    my $featureloc_id = $self->{_id_manager}->lookupId("featureloc", $seed);
    if (!defined($featureloc_id)){
    ##
    ## featureloc_id was not previously created, therefore generate and store in chado.featureloc
    ##
    $featureloc_id = $self->{_id_manager}->nextId("featureloc", $seed);
    if (!defined($featureloc_id)){
        ##
        ## Could not generate featureloc_id 
        ##
        $self->{_logger}->error("Could not retrieve featureloc_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'featureloc', '$seed' ".
                    "\nCannot insert record into chado.featureloc for feature_id ".
                    "'$feature_id' srcfeature_id '$srcfeature_id' fmin '$fmin' ".
                    "is_fmin_partial '$is_fmin_partial' fmax '$fmax' is_fmax_partial ".
                    "'$is_fmax_partial' strand '$strand' phase '$phase' residue_info ".
                    "'$residue_info' locgroup '$locgroup' rank '$rank'");
        return undef;
    }
    else{

        $self->_add_row(
                "featureloc",      ##  Sybase data types:
                $featureloc_id,    ##  numeric(9,0)                             NOT NULL
                $feature_id,       ##  numeric(9,0)                             NOT NULL
                $srcfeature_id,    ##  numeric(9,0)                                 NULL
                $fmin,             ##  numeric(9,0)                                 NULL
                $is_fmin_partial,  ##  varchar(6)   DEFAULT 'false'             NOT NULL
                $fmax,             ##  numeric(9,0)                                 NULL
                $is_fmax_partial,  ##  varchar(6)   DEFAULT 'false'             NOT NULL
                $strand,           ##  numeric(9,0)                                 NULL
                $phase,            ##  numeric(9,0)                             NOT NULL 
                $residue_info,     ##  text                                         NULL
                $locgroup,         ##  numeric(9,0) DEFAULT undef NOT NULL
                $rank              ##  numeric(9,0) DEFAULT undef NOT NULL
                );

    }
    }
    else{
    $self->{_logger}->warn("featureloc_id '$featureloc_id' was created previously during ".
                   "this current session for feature_id '$feature_id' srcfeature_id ".
                   "'$srcfeature_id'  fmin '$fmin' is_fmin_partial '$is_fmin_partial' ".
                   "fmax '$fmax' is_fmax_partial '$is_fmax_partial' strand '$strand' ".
                   "phase '$phase' residue_info '$residue_info' locgroup '$locgroup' ".
                   "rank '$rank'");
    }

    return $featureloc_id;


}##end sub do_store_new_featureloc {



##---------------------------------------------------------------------------------------------------------------
## do_store_new_feature_relationship()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_feature_relationship{

    my ($self, %params) = @_;

    my ($subject_id, $object_id, $type_id, $value, $rank);

    if (defined $params{'subject_id'}){
    $subject_id = $params{'subject_id'};
    }
    else {
    $self->{_logger}->error("subject_id was not defined.  Cannot insert record into chado.feature_relationship");
    return undef;
    }

    if (defined $params{'object_id'}){
    $object_id = $params{'object_id'};
    }
    else {
    $self->{_logger}->error("object_id was not defined.  Cannot insert record into chado.feature_relationship");
    return undef;
    }

    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
    $self->{_logger}->error("type_id was not defined.  Cannot insert record into chado.feature_relationship");
    return undef;
    }

    $value = (defined $params{'value'}) ? $params{'value'} : undef ;

    $rank = (defined $params{'rank'}) ? $params{'rank'} : 0;

    my $seed = "$subject_id:$object_id:$type_id";
    ##
    ## Check if feature_relationship_id was previously created during this current session
    ##
    my $feature_relationship_id = $self->{_id_manager}->lookupId("feature_relationship", $seed);
    if (!defined($feature_relationship_id)){
    ##
    ## feature_relationship_id was not previously created, therefore generate and store in chado.feature_relationship
    ##
    $feature_relationship_id = $self->{_id_manager}->nextId("feature_relationship", $seed);
    if (!defined($feature_relationship_id)){
        ##
        ## Could not generate feature_relationship_id 
        ##
        $self->{_logger}->error("Could not retrieve feature_relationship_id from Coati::IdManager ".
                    "lookup, nor could it be generated.  Seed was 'feature_relationship', '$seed' ".
                    "\nCould not insert record into chado.feature_relationship for subject_id ".
                    "'$subject_id' object_id '$object_id' type_id '$type_id' value '$value' rank '$rank'");
        return undef;
    }
    else{

        $self->_add_row(
                "feature_relationship",    ##  Sybase data types:          MysqlQL data types:
                $feature_relationship_id,  ##  numeric(9,0)  NOT NULL
                $subject_id,               ##  numeric(9,0)  NOT NULL
                $object_id,                ##  numeric(9,0)  NOT NULL
                $type_id,                  ##  numeric(9,0)  NOT NULL
                $value,                    ##  varchar(255)      NULL
                $rank                      ##  numeric(9,0)      NULL
                );

    }
    }

    return $feature_relationship_id;


}##end sub do_store_new_feature_relationship {

##---------------------------------------------------------------------------------------------------------------
## do_store_new_analysisfeature()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_analysisfeature{

    my ($self, %params) = @_;

    my ($feature_id, $analysis_id, $rawscore, $normscore, $significance, $pidentity, $type_id);

    if (defined $params{'feature_id'}){
    $feature_id = $params{'feature_id'};
    }
    else {
    $self->{_logger}->error("feature_id was not defined.  Cannot insert record into chado.analysisfeature");
    return undef;
    }

    if (defined $params{'analysis_id'}){
    $analysis_id = $params{'analysis_id'};
    }
    else {
    $self->{_logger}->error("analysis_id was not defined.  Cannot insert record into chado.analysisfeature");
    return undef;
    }

    $rawscore = (defined $params{'rawscore'}) ? $params{'rawscore'} : undef;

    $normscore = (defined $params{'normscore'}) ? $params{'normscore'} : undef;

    $significance = (defined $params{'significance'}) ? $params{'significance'} : undef;

    $pidentity = (defined $params{'pidentity'}) ? $params{'pidentity'} : undef;

    $type_id = (defined $params{'type_id'}) ? $params{'type_id'} : undef;

    my $seed = "$feature_id:$analysis_id";

    ##
    ## Check if analysisfeature_id was previously created during this current session
    ##
    my $analysisfeature_id = $self->{_id_manager}->lookupId("analysisfeature", $seed);
    if (!defined($analysisfeature_id)){
    ##
    ## analysisfeature_id was not previously created, therefore generate and store in chado.analysisfeature
    ##
    $analysisfeature_id = $self->{_id_manager}->nextId("analysisfeature", $seed);
    if (!defined($analysisfeature_id)){
        ##
        ## Could not generate analysisfeature_id 
        ##
        $self->{_logger}->error("Could not retrieve analysisfeature_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'analysisfeature', '$seed' ".
                    "\nCannot insert record into chado.analysisfeature for analysis_id ".
                    "'$analysis_id' feature_id '$feature_id' rawscore '$rawscore' ".
                    "normscore '$normscore' significance '$significance' identity ".
                    "'$pidentity' type_id '$type_id'");
        return undef;
    }
    else{


        $self->_add_row(
                "analysisfeature",    ##  Sybase data types:              MysqlQL data types:
                $analysisfeature_id,  ##  numeric(9,0) NOT NULL
                $feature_id,          ##  numeric(9,0) NOT NULL
                $analysis_id,         ##  numeric(9,0) NOT NULL
                $rawscore,            ##  double precision NULL
                $normscore,           ##  double precision NULL
                $significance,        ##  double precision NULL
                $pidentity,           ##  double precision NULL
                $type_id              ##  numeric(9,0)     NULL
                );

    }
    }

    return $analysisfeature_id;


}##end sub do_store_new_analysisfeature {

##---------------------------------------------------------------------------------------------------------------
## do_store_new_analysisprop()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_analysisprop{

    my ($self, %params) = @_;
  
    my ($analysis_id, $type_id, $value);
 
    if (defined $params{'analysis_id'}){
    $analysis_id = $params{'analysis_id'};
    }
    else {
    $self->{_logger}->error("analysis_id was not defined.  Cannot insert record into chado.analysisprop");
    return undef;
    }
    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
    $self->{_logger}->error("type_id was not defined.  Cannot insert record into chado.analysisprop");
    return undef;
    }
    if (defined $params{'value'}){
    $value = $params{'value'};
    }
    else {
    $self->{_logger}->error("value was not defined.  Cannot insert record into chado.analysisprop");
    return undef;
    }

    my $seed = "$analysis_id:$type_id:$value";

    ##
    ## Check if analysisprop_id was previously created during this current session
    ##
    my $analysisprop_id = $self->{_id_manager}->lookupId("analysisprop", $seed);
    if (!defined($analysisprop_id)){
    ##
    ## analysisprop_id was not previously created, therefore generate and store in chado.analysisprop
    ##
    $analysisprop_id = $self->{_id_manager}->nextId("analysisprop", $seed);
    if (!defined($analysisprop_id)){
        ##
        ## Could not generate analysisprop_id 
        ##
        $self->{_logger}->error("Could not retrieve analysisprop_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'analysisprop', '$seed' ".
                    "\nCannot store record in analysisprop for analysis_id '$analysis_id' ".
                    "type_id '$type_id' value '$value'");
        return undef;
    }
    else{

        $self->_add_row(
                "analysisprop",         ##  Sybase data types:              MysqlQL data types:
                $analysisprop_id,       ##  numeric(9,0) NOT NULL
                $analysis_id,           ##  numeric(9,0) NOT NULL
                $type_id,               ##  numeric(9,0) NOT NULL
                $value,                 ##  value varchar(255) NULL
                );
    }
    }

    return $analysisprop_id;


}##end sub do_store_new_analysisprop {



##---------------------------------------------------------------------------------------------------------------
## do_store_new_cv()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_cv {

    my ($self, %params) = @_;

    my ($name, $definition);

    if (defined $params{'name'}){
    $name = $params{'name'};
    }
    else {
    $self->{_logger}->error("name was not defined.  Cannot insert record into chado.cv");
    return undef;
    }

    $definition = (defined $params{'definition'}) ? $params{'definition'} : undef;

    ##
    ## Check if cv_id was previously created during this current session
    ##
    my $cv_id = $self->{_id_manager}->lookupId("cv", "$name");
    if (!defined($cv_id)){
    ##
    ## cv_id was not previously created, therefore generate and store in chado.cv
    ##
    $cv_id = $self->{_id_manager}->nextId("cv", "$name");
    if (!defined($cv_id)){
        ##
        ## Could not generate cv_id 
        ##
        $self->{_logger}->error("Could not retrieve cv_id from Coati::IdManager lookup, nor ".
                    "could it be generated.  Seed was 'cv', '$name'\nCannot insert ".
                    "record into chado.cv for name '$name' definition '$definition'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.cv
        ##
        $self->_add_row(
                "cv",             ##  Sybase data types:               MysqlQL data types:
                $cv_id,           ##  serial not null
                $name,            ##  varchar(255) not null
                $definition,      ##  text
                );
    }
    }

    return $cv_id;

}##end sub do_store_new_cv {


##---------------------------------------------------------------------------------------------------------------
## do_store_new_cvterm()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_cvterm {

    my ($self, %params) = @_;
  
    my ($cv_id, $name, $definition, $dbxref_id, $is_obsolete, $is_relationshiptype);

    if (defined $params{'cv_id'}){
    $cv_id = $params{'cv_id'};
    }
    else {
    $self->{_logger}->error("cv_id was not defined.  Cannot insert record into chado.cvterm");
    return undef;
    }
    if (defined $params{'name'}){
    $name = $params{'name'};
    }
    else {
    $self->{_logger}->error("name was not defined.  Cannot insert record into chado.cvterm");
    return undef;
    }
    
    $definition = (defined $params{'definition'}) ? $params{'definition'} : undef;

    $dbxref_id = (defined $params{'dbxref_id'}) ? $params{'dbxref_id'} : undef;

    $is_obsolete = (defined $params{'is_obsolete'}) ?  $params{'is_obsolete'} : 0;

    $is_relationshiptype = (defined $params{'is_relationshiptype'}) ?  $params{'is_relationshiptype'} : 0;


    ##
    ## Check if cvterm_id was previously created during this current session
    ##
    my $cvterm_id;

    do {

    ##
    ## Embedding the logic in this code for handling new usage of is_obsolete.
    ## See bgzcase 1840
    ##

    $cvterm_id = $self->{_id_manager}->lookupId("cvterm", "$cv_id:$name:$is_obsolete");

    } while ( (defined($cvterm_id)) and ($is_obsolete > 0) and (++$is_obsolete) );

    if (!defined($cvterm_id)){
    ##
    ## cvterm_id was not previously created, therefore generate and store in chado.cvterm
    ##
    $cvterm_id = $self->{_id_manager}->nextId("cvterm", "$cv_id:$name:$is_obsolete");

    if (!defined($cvterm_id)){
        ##
        ## Could not generate cvterm_id 
        ##
        $self->{_logger}->error("Could not retrieve cvterm_id from Coati::IdManager lookup, nor ".
                    "could it be generated.  Seed was \"cvterm\", ".
                    "\"$cv_id:name:$is_obsolete\"\nCannot insert record into ".
                    "chado.cvterm for cv_id '$cv_id' name '$name' definition ".
                    "'$definition' dbxref_id '$dbxref_id is_obsolete '$is_obsolete' ".
                    "is_relationshiptype '$is_relationshiptype'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.cvterm
        ##
        my $length  = length($definition);
        if ($length > 1200){
        my $oldvalue = $definition;
        $definition =  substr($oldvalue,0,1199);
        $self->{_logger}->warn("Had to truncate the definition since was exceeding the ".
                       "allocated field length (1200).  The length of definition ".
                       "was '$length', shortened definition\n'$oldvalue'\nto\n'$definition'");
        }


        $self->_add_row(
                "cvterm",              ##  Sybase data types:              MysqlQL data types:
                $cvterm_id,            ##  numeric(9,0)  not null
                $cv_id,                ##  numeric(9,0)  not null
                $name,                 ##  varchar(255)  not null
                $definition,           ##  varchar(255)  not null
                $dbxref_id,            ##  numeric(9,0)      null
                $is_obsolete,          ##  bit           not null
                $is_relationshiptype   ##  bit           not null
                );
    }
    }

    return $cvterm_id;

}##end sub do_store_new_cvterm {



##---------------------------------------------------------------------------------------------------------------
## do_store_new_cvterm_relationship()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_cvterm_relationship {

    my ($self, %params) = @_;
  
    my ($type_id, $subject_id, $object_id);

    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
    $self->{_logger}->error("type_id was not defined.  Cannot insert record into chado.cvterm_relationship");
    return undef;
    }

    if (defined $params{'subject_id'}){
    $subject_id = $params{'subject_id'};
    }
    else {
    $self->{_logger}->error("subject_id was not defined.  Cannot insert record into chado.cvterm_relationship");
    return undef;
    }

    if (defined $params{'object_id'}){
        $object_id = $params{'object_id'};
    }
    else {
    $self->{_logger}->error("object_id was not defined.  Cannot insert record into chado.cvterm_relationship");
    return undef;
    }
    
    my $seed = "$type_id:$subject_id:$object_id";

    ##
    ## Check if cvterm_relationship_id was previously created during this current session
    ##
    my $cvterm_relationship_id = $self->{_id_manager}->lookupId("cvterm_relationship", $seed);
    if (!defined($cvterm_relationship_id)){
    ##
    ## cvterm_relationship_id was not previously created, therefore generate and store in chado.cvterm_relationship
    ##
    $cvterm_relationship_id = $self->{_id_manager}->nextId("cvterm_relationship", $seed);
    if (!defined($cvterm_relationship_id)){
        ##
        ## Could not generate cvterm_relationship_id 
        ##
        $self->{_logger}->error("Could not retrieve cvterm_relationship_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'cvterm_relationship', '$seed' ".
                    "\nCannot insert record into chado.cvterm_relationship for type_id ".
                    "'$type_id' subject_id '$subject_id' object_id '$object_id'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.cvterm_relationship
        ##
        $self->_add_row(
                "cvterm_relationship",   ##  Sybase data types:     MysqlQL data types:
                $cvterm_relationship_id, ## serial not null
                $type_id,                ## int not null
                $subject_id,             ## int not null
                $object_id,              ## int not null
                );
    }
    }

    return $cvterm_relationship_id;

}##end sub do_store_new_cvterm_relationship {



##---------------------------------------------------------------------------------------------------------------
## do_store_new_cvtermpath()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_cvtermpath {

    my ($self, %params) = @_;
  
    my ($type_id, $subject_id, $object_id, $cv_id, $pathdistance);

    if (defined $params{'subject_id'}){
    $subject_id = $params{'subject_id'};  
    }
    else {
    $self->{_logger}->error("subject_id was not defined.  Cannot insert record into chado.cvtermpath");
    return undef;
    }

    if (defined $params{'object_id'}){
    $object_id = $params{'object_id'};
    }
    else {
    $self->{_logger}->error("object_id was not defined.  Cannot insert record into chado.cvtermpath");
    return undef;
    }

    if (defined $params{'cv_id'}){
    $cv_id = $params{'cv_id'};
    }
    else {
    $self->{_logger}->error("cv_id was not defined.  Cannot insert record into chado.cvtermpath");
    return undef;
    }

    $pathdistance = (defined $params{'pathdistance'}) ?  $params{'pathdistance'} : undef;

    $type_id = (defined $params{'type_id'}) ? $params{'type_id'} : undef;

    my $seed = "$type_id:$subject_id:$object_id:$cv_id:$pathdistance";

    ##
    ## Check if cvtermpath_id was previously created during this current session
    ##
    my $cvtermpath_id = $self->{_id_manager}->lookupId("cvtermpath", $seed);
    if (!defined($cvtermpath_id)){
    ##
    ## cvtermpath_id was not previously created, therefore generate and store in chado.cvtermpath
    ##
    $cvtermpath_id = $self->{_id_manager}->nextId("cvtermpath", $seed);
    if (!defined($cvtermpath_id)){
        ##
        ## Could not generate cvtermpath_id 
        ##
        $self->{_logger}->error("Could not retrieve cvtermpath_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'cvtermpath', '$seed' ".
                    "\nCannot insert record into chado.cvtermpath for type_id ".
                    "'$type_id' subject_id '$subject_id' object_id '$object_id' ".
                    "cv_id '$cv_id' pathdistance '$pathdistance'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.cvtermpath
        ##
        $self->_add_row(
                "cvtermpath",    ##  datatype:
                $cvtermpath_id, ## serial not null
                $type_id,       ## int 
                $subject_id,    ## int not null
                $object_id,     ## int not null
                $cv_id,         ## int not null
                $pathdistance,  ## int 
                );
    }
    }

    return $cvtermpath_id;

}##end sub do_store_new_cvtermpath {


##---------------------------------------------------------------------------------------------------------------
## do_store_new_cvtermsynonym()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_cvtermsynonym {

    my ($self, %params) = @_;

    my ($cvterm_id, $synonym, $type_id);

    if (defined $params{'cvterm_id'}){
    $cvterm_id = $params{'cvterm_id'};
    }
    else {
    $self->{_logger}->error("cvterm_id was not defined.  Cannot insert record into chado.cvtermsynonym");
    return undef;
    }

    if (defined $params{'synonym'}){
    $synonym = $params{'synonym'};   
    }
    else {
    $self->{_logger}->error("synonym was not defined.  Cannot insert record into chado.cvtermsynonym");
    return undef;
    }

    $type_id = (defined $params{'type_id'}) ? $params{'type_id'} : undef;

    my $seed = "$cvterm_id:$synonym";
    
    ##
    ## Check if cvtermsynonym_id was previously created during this current session
    ##
    my $cvtermsynonym_id = $self->{_id_manager}->lookupId("cvtermsynonym", $seed);
    if (!defined($cvtermsynonym_id)){
    ##
    ## cvtermsynonym_id was not previously created, therefore generate and store in chado.cvtermsynonym
    ##
    $cvtermsynonym_id = $self->{_id_manager}->nextId("cvtermsynonym", $seed);
    if (!defined($cvtermsynonym_id)){
        ##
        ## Could not generate cvtermsynonym_id 
        ##
        $self->{_logger}->error("Could not retrieve cvtermsynonym_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'cvtermsynonym', '$seed' ".
                    "\nCannot insert record into chado.cvtermsynonym for cvterm_id ".
                    "'$cvterm_id' synonym '$synonym'");
        return undef;
    }
    else{


        my $length  = length($synonym);
        if ($length > 1024){
        my $oldvalue = $synonym;
        $synonym =  substr($oldvalue,0,1023);
        $self->{_logger}->warn("Had to truncate the synonym since was exceeding the allocated ".
                       "field length (1024).  The length of synonym was '$length'. ".
                       "Shortened synonym\n'$oldvalue'\nto\n'$synonym'");
        }



        ##
        ## slot record in chado.cvtermsynonym
        ##
        $self->_add_row(
                "cvtermsynonym",   ## Sybase data types:
                $cvtermsynonym_id, ## numeric(9,0)  not null
                $cvterm_id,        ## numeric(9,0)  not null
                $synonym,          ## varchar(1024) not null
                $type_id           ## numeric(9,0)      null
                );
    }
    }

    return $cvtermsynonym_id;
    
}##end sub do_store_new_cvtermsynonym {

##---------------------------------------------------------------------------------------------------------------
## do_store_new_cvtermprop()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_cvtermprop {

    my ($self, %params) = @_;
  
    my ($cvterm_id, $type_id, $value, $rank);

    
    if (defined $params{'cvterm_id'}){
        $cvterm_id = $params{'cvterm_id'};
    }
    else {
    $self->{_logger}->error("cvterm_id was not defined.  Cannot insert record into chado.cvtermprop");
    return undef;
    }

    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
     $self->{_logger}->error("type_id was not defined.  Cannot insert record into chado.cvtermprop");
    return undef;
    }

    if (defined $params{'value'}){

    $value = $params{'value'};

    my $length = length($value);

    if ($length > 255){
        my $oldvalue = $value;
        $value = substr($oldvalue,0,254);
        $self->{_logger}->warn("Had to truncate the value since was exceeding the allocated ".
                   "field length (255).  The length of value was '$length'. ".
                   "Shortened value\n'$oldvalue'\nto\n'$value'");
    }

    }
    else {
    $self->{_logger}->error("value was not defined.  Cannot insert record into chado.cvtermprop");
    return undef;
    }





    $rank = (defined $params{'rank'}) ?  $params{'rank'} : 0;

    ##
    ## Check if cvtermprop_id was previously created during this current session
    ##
    my $cvtermprop_id;

    do {

    $cvtermprop_id = $self->{_id_manager}->lookupId("cvtermprop", "$cvterm_id:$type_id:$rank");

    } while ((defined($cvtermprop_id)) && (++$rank));


    if (!defined($cvtermprop_id)){
    ##
    ## cvtermprop_id was not previously created, therefore generate and store in chado.cvtermprop
    ##
    $cvtermprop_id = $self->{_id_manager}->nextId("cvtermprop", "$cvterm_id:$type_id:$rank");

    if (!defined($cvtermprop_id)){
        ##
        ## Could not generate cvtermprop_id 
        ##
        $self->{_logger}->error("Could not retrieve cvtermprop_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'cvtermprop', '$cvterm_id:$type_id:$rank' ".
                    "\nCannot insert record into chado.cvtermprop for cvterm_id '$cvterm_id' ".
                    "type_id '$type_id' value '$value' rank '$rank'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.cvtermprop
        ##
        $self->_add_row(
                "cvtermprop",   ##  Sybase data types:     MysqlQL data types:
                $cvtermprop_id, ## serial not null
                $cvterm_id,     ## int not null 
                $type_id,       ## int not null
                $value,
                $rank
                );
    }
    }
    else{
    $self->{_logger}->logdie("cvtermprop_id '$cvtermprop_id' was created previously during this ".
                 "current session for cvterm_id '$cvterm_id' type_id '$type_id' ".
                 "value '$value' rank '$rank'");
    }

    return $cvtermprop_id;

}##end sub do_store_new_cvtermprop {




##---------------------------------------------------------------------------------------------------------------
## do_store_new_dbxrefprop()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_dbxrefprop {

    my ($self, %params) = @_;
  
    my ($dbxref_id, $type_id, $value, $rank);

    if (defined $params{'dbxref_id'}){
    $dbxref_id = $params{'dbxref_id'};
    }
    else {
    $self->{_logger}->error("dbxref_id was not defined.  Cannot insert record into chado.dbxrefprop");
    return undef;
    }

    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
    $self->{_logger}->error("type_id was not defined.  Cannot insert record into chado.dbxrefprop");
    return undef;
    }

    if (defined $params{'value'}){
    $value = $params{'value'};
    }
    else {
    $self->{_logger}->error("value was not defined.  Cannot insert record into chado.dbxrefprop");
    return undef;
    }

    if (defined $params{'rank'}){
    $rank = $params{'rank'};
    }
    else {
    $self->{_logger}->error("rank was not defined.  Cannot insert record into chado.dbxrefprop");
    return undef;
    }


    ##
    ## Check if dbxrefprop_id was previously created during this current session
    ##
    my $dbxrefprop_id;

    do {
    $dbxrefprop_id = $self->{_id_manager}->lookupId("dbxrefprop", "$dbxref_id:$type_id:$rank");

    } while ((defined($dbxrefprop_id)) && (++$rank));

    if (!defined($dbxrefprop_id)){
    ##
    ## dbxrefprop_id was not previously created, therefore generate and store in chado.dbxrefprop
    ##
    $dbxrefprop_id = $self->{_id_manager}->nextId("dbxrefprop", "$dbxref_id:$type_id:$rank");
    if (!defined($dbxrefprop_id)){
        ##
        ## Could not generate dbxrefprop_id 
        ##
        $self->{_logger}->error("Could not retrieve dbxrefprop_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'dbxrefprop', '$dbxref_id:$type_id:$rank' ".
                    "\nCannot insert record into chado.dbxrefprop for dbxref_id '$dbxref_id' ".
                    "type_id '$type_id' value '$value' rank '$rank'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.dbxrefprop
        ##
        $self->_add_row(
                "dbxrefprop",    ## Sybase data types:       MysqlQL data types:
                $dbxrefprop_id,  ## serial not null
                $dbxref_id,      ## int not null 
                $type_id,        ## int not null
                $value,
                $rank
                );
    }
    }
    else{
    $self->{_logger}->logdie("dbxrefprop_id '$dbxrefprop_id' was created previously during ".
                 "this current session for dbxref_id '$dbxref_id' type_id '$type_id' ".
                 "value '$value' rank '$rank'");
    }


    return $dbxrefprop_id;

}##end sub do_store_new_dbxrefprop {



##---------------------------------------------------------------------------------------------------------------
## do_store_new_feature_pub()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_feature_pub {

    my ($self, %params) = @_;
  
    my ($feature_id, $pub_id);

    if (defined $params{'feature_id'}){
    $feature_id = $params{'feature_id'};
    }
    else {
    $self->{_logger}->error("feature_id was not defined.  Cannot insert record into chado.feature_pub");
    return undef;
    }

    if (defined $params{'pub_id'}){
    $pub_id = $params{'pub_id'};
    }
    else {
    $self->{_logger}->error("pub_id was not defined.  Cannot insert record into chado.feature_pub");
    return undef;
    }
    
    my $seed = "$feature_id:$pub_id";
    ##
    ## Check if feature_pub_id was previously created during this current session
    ##
    my $feature_pub_id = $self->{_id_manager}->lookupId("feature_pub", $seed);
    if (!defined($feature_pub_id)){
    ##
    ## feature_pub_id was not previously created, therefore generate and store in chado.feature_pub
    ##
    $feature_pub_id = $self->{_id_manager}->nextId("feature_pub", $seed);
    if (!defined($feature_pub_id)){
        ##
        ## Could not generate feature_pub_id 
        ##
        $self->{_logger}->error("Could not retrieve feature_pub_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'feature_pub', '$seed' ".
                    "\nCannot insert record into chado.feature_pub for feature_id ".
                    "'$feature_id' pub_id '$pub_id'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.feature_pub
        ##
        $self->_add_row(
                "feature_pub",    ## Sybase data types:              MysqlQL data types:
                $feature_pub_id,  ## serial not null
                $feature_id,      ## int not null 
                $pub_id           ## int not null
                );
    }
    }

    return $feature_pub_id;

}##end sub do_store_new_feature_pub {


##---------------------------------------------------------------------------------------------------------------
## do_store_new_featureprop_pub()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_featureprop_pub {

    my ($self, %params) = @_;
  
    my ($featureprop_id, $pub_id);

    if (defined $params{'featureprop_id'}){
    $featureprop_id = $params{'featureprop_id'};
    }
    else {
     $self->{_logger}->error("featureprop_id was not defined.  Cannot insert record into chado.featureprop_pub");
     return undef;
    }
    
    if (defined $params{'pub_id'}){
    $pub_id = $params{'pub_id'};
    }
    else {
    $self->{_logger}->error("pub_id was not defined.  Cannot insert record into chado.featureprop_pub");
    return undef;
    }

    my $seed = "$featureprop_id:$pub_id";

    ##
    ## Check if featureprop_pub_id was previously created during this current session
    ##
    my $featureprop_pub_id = $self->{_id_manager}->lookupId("featureprop_pub", $seed);
    if (!defined($featureprop_pub_id)){
    ##
    ## featureprop_pub_id was not previously created, therefore generate and store in chado.featureprop_pub
    ##
    $featureprop_pub_id = $self->{_id_manager}->nextId("featureprop_pub", $seed);
    if (!defined($featureprop_pub_id)){
        ##
        ## Could not generate featureprop_pub_id 
        ##
        $self->{_logger}->error("Could not retrieve featureprop_pub_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'featureprop_pub', '$seed' ".
                    "\nCannot insert record into chado.featureprop_pub for featureprop_id ".
                    "'$featureprop_id' pub_id '$pub_id'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.featureprop_pub
        ##
        $self->_add_row(
                "featureprop_pub",    ## Sybase data types:     MysqlQL data types:
                $featureprop_pub_id,  ## serial not null
                $featureprop_id,      ## int not null 
                $pub_id               ## int not null
                );
    }
    }
 
    return $featureprop_pub_id;

}##end sub do_store_new_featureprop_pub {




##---------------------------------------------------------------------------------------------------------------
## do_store_new_feature_relationship_pub()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_feature_relationship_pub {

    my ($self, %params) = @_;

    my ($feature_relationship_id, $pub_id);

    if (defined $params{'feature_relationship_id'}){
    $feature_relationship_id = $params{'feature_relationship_id'};
    }
    else {
    $self->{_logger}->error("feature_relationship_id was not defined.  Cannot insert record into chado.feature_relationship_pub");
    return undef;
    }
    if (defined $params{'pub_id'}){
    $pub_id = $params{'pub_id'};
    }
    else {
    $self->{_logger}->error("pub_id was not defined.  Cannot insert record into chado.feature_relationship_pub");
    return undef;
    }

    my $seed = "$feature_relationship_id:$pub_id";

    ##
    ## Check if feature_relationship_pub_id was previously created during this current session
    ##
    my $feature_relationship_pub_id = $self->{_id_manager}->lookupId("feature_relationship_pub", $seed);
    if (!defined($feature_relationship_pub_id)){
    ##
    ## feature_relationship_pub_id was not previously created, therefore generate and store in chado.feature_relationship_pub
    ##
    $feature_relationship_pub_id = $self->{_id_manager}->nextId("feature_relationship_pub", $seed);
    if (!defined($feature_relationship_pub_id)){
        ##
        ## Could not generate feature_relationship_pub_id 
        ##
        $self->{_logger}->error("Could not retrieve feature_relationship_pub_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'feature_relationship_pub', '$seed' ".
                    "\nCannot insert record into chado.feature_relationship_pub for ".
                    "feature_relationship_id '$feature_relationship_id' pub_id '$pub_id'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.feature_relationship_pub
        ##
        $self->_add_row(
                "feature_relationship_pub",    ##  datatype:
                $feature_relationship_pub_id,  ## serial not null
                $feature_relationship_id,      ## int not null 
                $pub_id                        ## int not null
                );
    }
    }

    return $feature_relationship_pub_id;

}##end sub do_store_new_feature_relationship_pub {




##---------------------------------------------------------------------------------------------------------------
## do_store_new_feature_relationshipprop()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_feature_relationshipprop {

    my ($self, %params) = @_;

    my ($feature_relationship_id, $type_id, $value, $rank);

    if (defined $params{'feature_relationship_id'}){
    $feature_relationship_id = $params{'feature_relationship_id'};
    }
    else {
    $self->{_logger}->error("feature_relationship_id was not defined.  Cannot insert record into chado.feature_relationshipprop");
    return undef;
    }

    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
    $self->{_logger}->error("type_id was not defined.  Cannot insert record into chado.feature_relationshipprop");
    return undef;
    }


    if (defined $params{'value'}){
    $value = $params{'value'};
    }
    else {
    $self->{_logger}->error("value was not defined.  Cannot insert record into chado.feature_relationshipprop");
    return undef;
    }

    $rank = (defined $params{'rank'}) ? $params{'rank'} : 0;

    ##
    ## Check if feature_relationshipprop_id was previously created during this current session
    ##
    my $feature_relationshipprop_id;

    do {
    $feature_relationshipprop_id = $self->{_id_manager}->lookupId("feature_relationshipprop", "$feature_relationship_id:$type_id:$rank");

    } while ((defined($feature_relationshipprop_id)) && (++$rank));


    if (!defined($feature_relationshipprop_id)){
    ##
    ## feature_relationshipprop_id was not previously created, therefore generate and store in chado.feature_relationshipprop
    ##
    $feature_relationshipprop_id = $self->{_id_manager}->nextId("feature_relationshipprop", "$feature_relationship_id:$type_id:$rank");
    if (!defined($feature_relationshipprop_id)){
        ##
        ## Could not generate feature_relationshipprop_id 
        ##
        $self->{_logger}->error("Could not retrieve feature_relationshipprop_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'feature_relationshipprop', '$feature_relationship_id:$type_id:$rank' ".
                    "\nCannot insert record into chado.feature_relationshipprop for ".
                    "feature_relationship_id '$feature_relationship_id' type_id '$type_id' ".
                    "value '$value' rank '$rank'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.feature_relationshipprop
        ##
        $self->_add_row(
                "feature_relationshipprop",    ## Sybase data types:         MysqlQL data types:
                $feature_relationshipprop_id,  ## serial not null
                $feature_relationship_id,      ## int not null 
                $type_id,                      ## int not null
                $value,                        ## int not null
                $rank,                         ## int not null
                );
    }
    }
    else{
    $self->{_logger}->logdie("feature_relationshipprop_id '$feature_relationshipprop_id' was ".
                 "created previously during this current session for ".
                 "feature_relationship_id '$feature_relationship_id' ".
                 "type_id '$type_id' value '$value' rank '$rank'");
    }

    return $feature_relationshipprop_id;

}##end sub do_store_new_feature_relationshipprop {

##---------------------------------------------------------------------------------------------------------------
## do_store_new_feature_relprop_pub()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_feature_relprop_pub {

    my ($self, %params) = @_;
  
    my ($feature_relationshipprop_id, $pub_id);

    if (defined $params{'feature_relationshipprop_id'}){
    $feature_relationshipprop_id = $params{'feature_relationshipprop_id'};
    }
    else {
    $self->{_logger}->error("feature_relationshipprop_id was not defined.  Cannot insert record into chado.feature_relprop_pub");
    return undef;
    }

    if (defined $params{'pub_id'}){
    $pub_id = $params{'pub_id'};
    }
    else {
    $self->{_logger}->error("pub_id was not defined.  Cannot insert record into chado.feature_relprop_pub");
    return undef;
    }

    my $seed = "$feature_relationshipprop_id:$pub_id";
    
    ##
    ## Check if feature_relprop_pub_id was previously created during this current session
    ##
    my $feature_relprop_pub_id = $self->{_id_manager}->lookupId("feature_relprop_pub", $seed);
    if (!defined($feature_relprop_pub_id)){
    ##
    ## feature_relprop_pub_id was not previously created, therefore generate and store in chado.feature_relprop_pub
    ##
    $feature_relprop_pub_id = $self->{_id_manager}->nextId("feature_relprop_pub", $seed);
    if (!defined($feature_relprop_pub_id)){
        ##
        ## Could not generate feature_relprop_pub_id 
        ##
        $self->{_logger}->error("Could not retrieve feature_relprop_pub_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'feature_relprop_pub', '$seed' ".
                    "\nCannot insert record into chado.feature_relprop_pub for ".
                    "feature_relationshipprop_id '$feature_relationshipprop_id' pub_id '$pub_id'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.feature_relprop_pub
        ##
        $self->_add_row(
                "feature_relprop_pub",        ## Sybase data types:
                $feature_relprop_pub_id,      ## serial not null
                $feature_relationshipprop_id, ## int not null 
                $pub_id                       ## int not null
                );
    }
    }

    return $feature_relprop_pub_id;

}##end sub do_store_new_feature_relprop_pub {



##---------------------------------------------------------------------------------------------------------------
## do_store_new_feature_cvtermprop()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_feature_cvtermprop {

    my ($self, %params) = @_;
  
    my ($feature_cvterm_id, $type_id, $value, $rank);


    if (defined $params{'feature_cvterm_id'}){
    $feature_cvterm_id = $params{'feature_cvterm_id'};
    }
    else {
    $self->{_logger}->error("feature_cvterm_id was not defined.  Cannot insert record into chado.feature_cvtermprop");
    return undef;
    }

    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
    $self->{_logger}->error("type_id was not defined.  Cannot insert record into chado.feature_cvtermprop");
    return undef;
    }

    if (defined $params{'value'}){
    $value = $params{'value'};
    }
    else {
    $self->{_logger}->error("value was not defined.  Cannot insert record into chado.feature_cvtermprop");
    return undef;
    }

    $rank = (defined $params{'rank'}) ? $params{'rank'} : 0;


    ##
    ## Check if feature_cvtermprop_id was previously created during this current session
    ##
    my $feature_cvtermprop_id;

    do {

    $feature_cvtermprop_id = $self->{_id_manager}->lookupId("feature_cvtermprop", "$feature_cvterm_id:$type_id:$rank");

    } while ((defined($feature_cvtermprop_id)) && (++$rank));


    if (!defined($feature_cvtermprop_id)){
    ##
    ## feature_cvtermprop_id was not previously created, therefore generate and store in chado.feature_cvtermprop
    ##
    $feature_cvtermprop_id = $self->{_id_manager}->nextId("feature_cvtermprop", "$feature_cvterm_id:$type_id:$rank");
    if (!defined($feature_cvtermprop_id)){
        ##
        ## Could not generate feature_cvtermprop_id 
        ##
        $self->{_logger}->error("Could not retrieve feature_cvtermprop_id from Coati::IdManager lookup, nor could it be generated.  Seed was \"feature_cvtermprop\", \"$feature_cvterm_id:$type_id:$rank\"\nCannot insert record into chado.feature_cvtermprop for feature_cvterm_id '$feature_cvterm_id' type_id '$type_id' value '$value' rank '$rank'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.feature_cvtermprop
        ##
        $self->_add_row(
                "feature_cvtermprop",        ##  datatype:
                $feature_cvtermprop_id,      ## serial not null
                $feature_cvterm_id,          ## int not null 
                $type_id,                    ## int not null
                $value,                      ## varchar(255) not null
                $rank                        ## int not null
                );
    }
    }
    else{
    $self->{_logger}->logdie("feature_cvtermprop_id '$feature_cvtermprop_id' was created previously during this current session for feature_cvterm_id '$feature_cvterm_id' type_id '$type_id' value '$value' rank '$rank'");
    }

    return $feature_cvtermprop_id;

}##end sub do_store_new_feature_cvtermprop {




##---------------------------------------------------------------------------------------------------------------
## do_store_new_synonym()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_synonym {

    my ($self, %params) = @_;
  
    my ($name, $type_id, $synonym_sgml);


    if (defined $params{'name'}){
    $name = $params{'name'};
    }
    else {
    $self->{_logger}->error("name was not defined.  Cannot insert record into chado.synonym");
    return undef;
    }
    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
    $self->{_logger}->error("type_id was not defined.  Cannot insert record into chado.synonym");
    return undef;
    }

    if (defined $params{'synonym_sgml'}){
    $synonym_sgml = $params{'synonym_sgml'};
    }
    else {
    $self->{_logger}->error("synonym_sgml was not defined.  Cannot insert record into chado.synonym");
    return undef;
    }

    my $seed = "$name:$type_id:$synonym_sgml";

    ##
    ## Check if synonym_id was previously created during this current session
    ##
    my $synonym_id = $self->{_id_manager}->lookupId("synonym", $seed);
    if (!defined($synonym_id)){
    ##
    ## synonym_id was not previously created, therefore generate and store in chado.synonym
    ##
    $synonym_id = $self->{_id_manager}->nextId("synonym", $seed);
    if (!defined($synonym_id)){
        ##
        ## Could not generate synonym_id 
        ##
        $self->{_logger}->error("Could not retrieve synonym_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'synonym', '$seed'".
                    "\nCannot insert record into chado.synonym for name '$name' ".
                    "type_id '$type_id' synonym_sgml '$synonym_sgml'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.synonym
        ##
        $self->_add_row(
                "synonym",        ##  datatype:
                $synonym_id,      ## serial not null
                $name,            ## varchar(255) not null 
                $type_id,         ## int not null
                $synonym_sgml     ## varchar(255) not null
                );
    }
    }

    return $synonym_id;

}##end sub do_store_new_synonym {



##---------------------------------------------------------------------------------------------------------------
## do_store_new_feature_synonym()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_feature_synonym {

    my ($self, %params) = @_;
  
    my ($synonym_id, $feature_id, $pub_id, $is_current, $is_internal);

    if (defined $params{'synonym_id'}){
    $synonym_id = $params{'synonym_id'};
    }
    else {
    $self->{_logger}->error("synonym_id was not defined.  Cannot insert record into chado.feature_synonym");
    return undef;
    }

    if (defined $params{'feature_id'}){
    $feature_id = $params{'feature_id'};
    }
    else {
    $self->{_logger}->error("feature_id was not defined.  Cannot insert record into chado.feature_synonym");
    return undef;
    }

    if (defined $params{'pub_id'}){
    $pub_id = $params{'pub_id'};
    }
    else {
    $self->{_logger}->error("pub_id was not defined.  Cannot insert record into chado.feature_synonym");
    return undef;
    }

    if (defined $params{'is_current'}){
    $is_current = $params{'is_current'};
    }
    else {
    $self->{_logger}->error("is_current was not defined.  Cannot insert record into chado.synonym");
    return undef;
    }

    if (defined $params{'is_internal'}){
    $is_internal = $params{'is_internal'};
    }
    else {
    $self->{_logger}->error("is_internal was not defined.  Cannot insert record into chado.synonym");
    return undef;
    }

    my $seed = "$synonym_id:$feature_id:$pub_id:$is_current:$is_internal";

    ##
    ## Check if feature_synonym_id was previously created during this current session
    ##
    my $feature_synonym_id = $self->{_id_manager}->lookupId("feature_synonym", $seed);
    if (!defined($feature_synonym_id)){
    ##
    ## feature_synonym_id was not previously created, therefore generate and store in chado.feature_synonym
    ##
    $feature_synonym_id = $self->{_id_manager}->nextId("feature_synonym", $seed);
    if (!defined($feature_synonym_id)){
        ##
        ## Could not generate feature_synonym_id 
        ##
        $self->{_logger}->error("Could not retrieve feature_synonym_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'feature_synonym', '$seed' ".
                    "\nCannot insert record into chado.feature_synonym for synonym_id ".
                    "'$synonym_id' feature_id '$feature_id' pub_id '$pub_id' is_current ".
                    "'$is_current' is_internal '$is_internal'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.feature_synonym
        ##
        $self->_add_row(
                "feature_synonym",    ##  datatype:
                $feature_synonym_id,  ## serial not null
                $synonym_id,          ## int not null 
                $feature_id,          ## int not null
                $pub_id,              ## int not null
                $is_current,          ## bit not null
                $is_internal          ## bit not null
                );
    }
    }

    return $feature_synonym_id;

}##end sub do_store_new_feature_synonym {




##---------------------------------------------------------------------------------------------------------------
## do_store_new_organismprop()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_organismprop {

    my ($self, %params) = @_;

    my ($organism_id, $type_id, $value, $rank);


    if (defined $params{'organism_id'}){
    $organism_id = $params{'organism_id'};
    }
    else {
    $self->{_logger}->logdie("organism_id was not defined");
    }

    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
    $self->{_logger}->logdie("type_id was not defined");
    }
    
    if (defined $params{'value'}){
    $value = $params{'value'};
    }
    else {
    $self->{_logger}->logdie("value was not defined");
    }

    $rank = (defined $params{'rank'}) ? $params{'rank'} : 0;

    ##
    ## Check if organismprop_id was previously created during this current session
    ##
    my $organismprop_id;

    do {

    $organismprop_id = $self->{_id_manager}->lookupId("organismprop", "$organism_id:$type_id:$rank");
    } while ((defined($organismprop_id)) && (++$rank));


    if (!defined($organismprop_id)){
    ##
    ## organismprop_id was not previously created, therefore generate and store in chado.organismprop
    ##
    $organismprop_id = $self->{_id_manager}->nextId("organismprop", "$organism_id:$type_id:$rank");
    if (!defined($organism_id)){
        ##
        ## Could not generate organismprop_id 
        ##
        $self->{_logger}->error("Could not retrieve organismprop_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'organismprop', '$organism_id:$type_id:$rank' ".
                    "\nCannot insert record into chado.organismprop for organism_id '$organism_id' ".
                    "type_id '$type_id' value '$value' rank '$rank'");
        return undef;
    }
    else{

        $self->_add_row(
                "organismprop",    ##  datatype:
                $organismprop_id,  ##  numeric(9,0)  NOT NULL
                $organism_id,      ##  numeric(9,0)  NOT NULL
                $type_id,          ##  numeric(9,0)  NOT NULL
                $value,            ##  varchar(50)   NOT NULL
                $rank              ##  numeric(9,0)  NOT NULL
                );
    }
    }
    else{
    $self->{_logger}->logdie("organismprop_id $organismprop_id was created previously during this ".
                 "current session for organism_id '$organism_id' type_id '$type_id' ".
                 "value '$value' rank '$rank'");
    }

    return $organismprop_id;


}##end sub do_store_new_organismprop {

##---------------------------------------------------------------------------------------------------------------
## do_store_new_project()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_project {

    my ($self, %params) = @_;

    my ($name, $description);


    if (defined $params{'name'}){
    $name = $params{'name'};
    }
    else {
    $self->{_logger}->error("name was not defined.  Cannot insert record into chado.project");
    return undef;
    }

    if (defined $params{'description'}){
    $description = $params{'description'};
    }
    else {
    $self->{_logger}->error("description was not defined.  Cannot insert record into chado.project");
    return undef;
    }

    ##
    ## Check if project_id was previously created during this current session
    ##
    my $project_id = $self->{_id_manager}->lookupId("project", "$name");
    if (!defined($project_id)){
    ##
    ## project_id was not previously created, therefore generate and store in chado.project
    ##
    $project_id = $self->{_id_manager}->nextId("project", "$name");
    if (!defined($project_id)){
        ##
        ## Could not generate project_id 
        ##
        $self->{_logger}->error("Could not retrieve project_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'project', '$name' ".
                    "\nCannot insert record into chado.project for name '$name' ".
                    "description '$description'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.project
        ##
        $self->_add_row(
                "project",    ##  datatype:
                $project_id,  ## numeric(9,0) not null
                $name,        ## varchar(255) not null
                $description  ## varchar(255) not null
                );
    }
    }

    return $project_id;

}##end sub do_store_new_project {


##---------------------------------------------------------------------------------------------------------------
## do_store_new_tableinfo()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_tableinfo {

    my ($self, %params) = @_;

    my ($name, $primary_key_column, $is_view, $view_on_table_id, $superclass_table_id, $is_updateable, $modification_date);


    if (defined $params{'name'}){
    $name = $params{'name'};
    }
    else {
    $self->{_logger}->error("name was not defined.  Cannot insert record into chado.tableinfo");
    return undef;
    }

    if (defined $params{'is_view'}){
    $is_view = $params{'is_view'};
    }
    else {
    $self->{_logger}->error("is_view was not defined.  Cannot insert record into chado.tableinfo");
    return undef;
    }

    if (defined $params{'is_updateable'}){
    $is_updateable = $params{'is_updateable'};
    }
    else {
    $self->{_logger}->error("is_updateable was not defined.  Cannot insert record into chado.tableinfo");
    return undef;
    }
    
    if (defined $params{'modification_date'}){
    $modification_date = $params{'modification_date'};
    }
    else {
    $self->{_logger}->error("modification_date was not defined.  Cannot insert record into chado.tableinfo");
    return undef;
    }
    
    $primary_key_column = (defined $params{'primary_key_column'}) ?  $params{'primary_key_column'} : undef;

    $view_on_table_id = (defined $params{'view_on_table_id'}) ?  $params{'view_on_table_id'} : undef;

    $superclass_table_id = (defined $params{'superclass_table_id'}) ? $params{'superclass_table_id'} : undef;


    ##
    ## Check if project_id was previously created during this current session
    ##
    my $tableinfo_id = $self->{_id_manager}->lookupId("tableinfo", "$name");
    if (!defined($tableinfo_id)){
    ##
    ## tableinfo_id was not previously created, therefore generate and store in chado.tableinfo
    ##
    $tableinfo_id = $self->{_id_manager}->nextId("tableinfo", "$name");
    if (!defined($tableinfo_id)){
        ##
        ## Could not generate tableinfo_id 
        ##
        $self->{_logger}->error("Could not retrieve tableinfo_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'tableinfo', '$name' ".
                    "\nCannot insert record into chado.tableinfo for name '$name'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.tableinfo
        ##
        $self->_add_row(
                "tableinfo",          ##  datatype:
                $tableinfo_id,        ## numeric(9,0)  not null
                $name,                ## varchar(30)   not null
                $primary_key_column,  ## varchar(30)       null
                $is_view,             ## bit           not null
                $view_on_table_id,    ## numeric(9,0)      null
                $superclass_table_id, ## numeric(9,0)      null
                $is_updateable,       ## bit           not null
                $modification_date    ## smalldatetime not null
                );
    }
    }

    return $tableinfo_id;

}##end sub do_store_new_tableinfo {

##---------------------------------------------------------------------------------------------------------------
## do_store_new_pub()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_pub {

    my ($self, %params) = @_;

    my ($title, $volumetitle, $volume, $series_name, $issue, $pyear, $pages, $miniref, $uniquename,
     $type_id, $is_obsolete, $publisher, $pubplace);

    if (defined $params{'uniquename'}){
    $uniquename = $params{'uniquename'};
    }
    else {
    $self->{_logger}->error("uniquename was not defined.  Cannot insert record into chado.pub");
    return undef;
    }

    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
    $self->{_logger}->error("type_id was not defined.  Cannot insert record into chado.pub");
    return undef;
    }

    if (defined $params{'is_obsolete'}){
    $is_obsolete = $params{'is_obsolete'};
    }
    else {
    $self->{_logger}->error("is_obsolete was not defined.  Cannot insert record into chado.pub");
    return undef;
    }

    $title = (defined $params{'title'}) ? $params{'title'} : undef;

    $volumetitle = (defined $params{'volumetitle'}) ? $params{'volumetitle'} : undef;

    $volume = (defined $params{'volume'}) ? $params{'volume'} : undef;

    $series_name = (defined $params{'series_name'}) ? $params{'series_name'} : undef;

    $issue = (defined $params{'issue'}) ? $params{'issue'} : undef;

    $pyear = (defined $params{'pyear'}) ? $params{'pyear'} : undef;

    $pages = (defined $params{'pages'}) ? $params{'pages'} : undef;

    $miniref = (defined $params{'miniref'}) ? $params{'miniref'} : undef;

    $publisher = (defined $params{'publisher'}) ? $params{'publisher'} : undef;

    $pubplace = (defined $params{'pubplace'}) ? $params{'pubplace'} : undef;

    my $seed = "$uniquename:$type_id";
    ##
    ## Check if pub_id was previously created during this current session
    ##
    my $pub_id = $self->{_id_manager}->lookupId("pub", $seed );
    if (!defined($pub_id)){
    ##
    ## pub_id was not previously created, therefore generate and store in chado.pub
    ##
    $pub_id = $self->{_id_manager}->nextId("pub", $seed);
    if (!defined($pub_id)){
        ##
        ## Could not generate pub_id 
        ##
        $self->{_logger}->error("Could not retrieve project_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'pub', '$seed' ".
                    "\nCannot insert record into chado.pub for title '$title' ".
                    "volumetitle '$volumetitle' volume '$volume' series_name ".
                    "'$series_name' issue '$issue' pyear '$pyear' pages '$pages' ".
                    "miniref '$miniref' uniquename '$uniquename' type_id '$type_id' ".
                    "is_obsolete '$is_obsolete' publisher '$publisher' pubplace '$pubplace'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.pub
        ##
        $self->_add_row(
                "pub",    ##  datatype:
                $pub_id,      ## numeric(9,0) not null
                $title,       ## varchar(255)     null
                $volumetitle, ## varchar(255)     null
                $volume,      ## varchar(255)     null
                $series_name, ## varchar(255)     null
                $issue,       ## varchar(255)     null
                $pyear,       ## varchar(255)     null
                $pages,       ## varchar(255)     null
                $miniref,     ## varchar(255)     null
                $uniquename,  ## varchar(255) not null
                $type_id,     ## numeric(9,0) not null
                $is_obsolete, ## bit          not null
                $publisher,   ## varchar(255)     null
                $pubplace     ## varchar(255)     null
                );
    }
    }

    return $pub_id;

}##end sub do_store_new_pub {



##---------------------------------------------------------------------------------------------------------------
## do_store_new_pub_relationship()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_pub_relationship {

    my ($self, %params) = @_;

    my ($subject_id, $object_id, $type_id);

    if (defined $params{'subject_id'}){
    $subject_id = $params{'subject_id'};
    }
    else {
     $self->{_logger}->error("subject_id was not defined.  Cannot insert record into chado.pub_relationship");
    return undef;
    }

    if (defined $params{'object_id'}){
    $object_id = $params{'object_id'};
    }
    else {
      $self->{_logger}->error("object_id was not defined.  Cannot insert record into chado.pub_relationship");
    return undef;
    }
    
    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
     $self->{_logger}->error("type_id was not defined.  Cannot insert record into chado.pub_relationship");
    return undef;
    }

    my $seed = "$subject_id:$object_id:$type_id";

    ##
    ## Check if pub_relationship_id was previously created during this current session
    ##
    my $pub_relationship_id = $self->{_id_manager}->lookupId("pub_relationship", $seed);
    if (!defined($pub_relationship_id)){
    ##
    ## pub_relationship_id was not previously created, therefore generate and store in chado.pub_relationship
    ##
    $pub_relationship_id = $self->{_id_manager}->nextId("pub_relationship", $seed);
    if (!defined($pub_relationship_id)){
        ##
        ## Could not generate pub_relationship_id 
        ##
        $self->{_logger}->error("Could not retrieve pub_relationship_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'pub_relationship', '$seed' ".
                    "\nCannot insert record into chado.pub_relationship for subject_id ".
                    "'$subject_id' object_id '$object_id' type_id '$type_id'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.pub_relationship
        ##
        $self->_add_row(
                "pub_relationship",    ##  datatype:
                $pub_relationship_id,  ## numeric(9,0) not null
                $subject_id,           ## numeric(9,0) not null
                $object_id,            ## numeric(9,0) not null
                $type_id               ## numeric(9,0) not null
                );
    }
    }

    return $pub_relationship_id;

}##end sub do_store_new_pub_relationship {



##---------------------------------------------------------------------------------------------------------------
## do_store_new_pub_dbxref()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_pub_dbxref {

    my ($self, %params) = @_;

    my ($pub_id, $dbxref_id, $is_current);

    if (defined $params{'pub_id'}){
    $pub_id = $params{'pub_id'};
    }
    else {
     $self->{_logger}->error("pub_id was not defined.  Cannot insert record into chado.pub_dbxref");
    return undef;
    }

    if (defined $params{'dbxref_id'}){
    $dbxref_id = $params{'dbxref_id'};
    }
    else {
     $self->{_logger}->error("dbxref_id was not defined.  Cannot insert record into chado.pub_dbxref");
    return undef;
    }

    if (defined $params{'is_current'}){
    $is_current = $params{'is_current'};
    }
    else {
     $self->{_logger}->error("is_current was not defined.  Cannot insert record into chado.pub_dbxref");
    return undef;
    }

    my $seed = "$pub_id:$dbxref_id";

    ##
    ## Check if pub_dbxref_id was previously created during this current session
    ##
    my $pub_dbxref_id = $self->{_id_manager}->lookupId("pub_dbxref", $seed);
    if (!defined($pub_dbxref_id)){
    ##
    ## pub_dbxref_id was not previously created, therefore generate and store in chado.pub_dbxref
    ##
    $pub_dbxref_id = $self->{_id_manager}->nextId("pub_dbxref", $seed);
    if (!defined($pub_dbxref_id)){
        ##
        ## Could not generate pub_dbxref_id 
        ##
        $self->{_logger}->error("Could not retrieve pub_dbxref_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'pub_dbxref', '$seed' ".
                    "\nCannot insert record into chado.pub_dbxref for pub_id ".
                    "'$pub_id' dbxref_id '$dbxref_id' is_current '$is_current'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.pub_dbxref
        ##
        $self->_add_row(
                "pub_dbxref",    ##  datatype:
                $pub_dbxref_id,  ## numeric(9,0) not null
                $pub_id,         ## numeric(9,0) not null
                $dbxref_id,      ## numeric(9,0) not null
                $is_current      ## bit          not null
                );
    }
    }

    return $pub_dbxref_id;

}##end sub do_store_new_pub_dbxref {




##---------------------------------------------------------------------------------------------------------------
## do_store_new_pubauthor()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_pubauthor {

    my ($self, %params) = @_;

    my ($pub_id, $rank, $editor, $surname, $givennames, $suffix);


    if (defined $params{'pub_id'}){
    $pub_id = $params{'pub_id'};
    }
    else {
     $self->{_logger}->error("pub_id was not defined.  Cannot insert record into chado.pubauthor");
    return undef;
    }

    if (defined $params{'rank'}){
    $rank = $params{'rank'};
    }
    else {
     $self->{_logger}->error("rank was not defined.  Cannot insert record into chado.pubauthor");
    return undef;
    }

    if (defined $params{'editor'}){
    $editor = $params{'editor'};
    }
    else {
     $self->{_logger}->error("editor was not defined.  Cannot insert record into chado.pubauthor");
    return undef;
    }

    if (defined $params{'surname'}){
    $surname = $params{'surname'};
    }
    else {
     $self->{_logger}->error("surname was not defined.  Cannot insert record into chado.pubauthor");
    return undef;
    }

    $givennames = (defined $params{'givennames'}) ? $params{'givennames'} : undef;

    $suffix = (defined $params{'suffix'}) ? $params{'suffix'} : undef ;

    my $seed = "$pub_id:$rank";


    ##
    ## Check if pubauthor_id was previously created during this current session
    ##
    my $pubauthor_id = $self->{_id_manager}->lookupId("pubauthor", $seed);
    if (!defined($pubauthor_id)){
    ##
    ## pubauthor_id was not previously created, therefore generate and store in chado.pubauthor
    ##
    $pubauthor_id = $self->{_id_manager}->nextId("pubauthor", $seed);
    if (!defined($pubauthor_id)){
        ##
        ## Could not generate pubauthor_id 
        ##
        $self->{_logger}->error("Could not retrieve pubauthor_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'pubauthor', '$seed' ".
                    "\nCannot insert record into chado.pubauthor for pub_id '$pub_id' ".
                    "rank '$rank' editor '$editor' surname '$surname' givennames ".
                    "'$givennames' suffix '$suffix'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.pubauthor
        ##
        $self->_add_row(
                "pubauthor",    ##  datatype:
                $pubauthor_id,  ## numeric(9,0) not null
                $pub_id,        ## numeric(9,0) not null
                $rank,          ## numeric(9,0) not null
                $editor,        ## bit          not null
                $surname,       ## varchar(255) not null
                $givennames,    ## varchar(100)     null
                $suffix         ## varchar(100)     null
                );
    }
    }

    return $pubauthor_id;

}##end sub do_store_new_pubauthor {




##---------------------------------------------------------------------------------------------------------------
## do_store_new_pubprop()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_pubprop {

    my ($self, %params) = @_;

    my ($pub_id, $type_id, $value, $rank);

    if (defined $params{'pub_id'}){
    $pub_id = $params{'pub_id'};
    }
    else {
     $self->{_logger}->error("pub_id was not defined.  Cannot insert record into chado.pubprop");
    return undef;
    }

    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
     $self->{_logger}->error("type_id was not defined.  Cannot insert record into chado.pubprop");
    return undef;
    }

    if (defined $params{'value'}){
    $value = $params{'value'};
    }
    else {
     $self->{_logger}->error("value was not defined.  Cannot insert record into chado.pubprop");
    return undef;
    }

    $rank = (defined $params{'rank'}) ?  $params{'rank'} : 0;


    ##
    ## Check if pubprop_id was previously created during this current session
    ##
    my $pubprop_id;
    
    do {

    $pubprop_id = $self->{_id_manager}->lookupId("pubprop", "$pub_id:$type_id:$rank");

    } while ((defined($pubprop_id)) && (++$rank));

    if (!defined($pubprop_id)){
    ##
    ## pubprop_id was not previously created, therefore generate and store in chado.pubprop
    ##
    $pubprop_id = $self->{_id_manager}->nextId("pubprop", "$pub_id:$type_id:$rank");
    if (!defined($pubprop_id)){
        ##
        ## Could not generate pubprop_id 
        ##
        $self->{_logger}->error("Could not retrieve pubprop_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'pubprop', '$pub_id:$type_id:$rank' ".
                    "\"\nCannot insert record into chado.pubprop for pub_id '$pub_id' ".
                    "type_id '$type_id' value '$value' rank '$rank'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.pubprop
        ##
        $self->_add_row(
                "pubprop",    ##  datatype:
                $pubprop_id,  ## numeric(9,0) not null
                $pub_id,      ## numeric(9,0) not null
                $type_id,     ## numeric(9,0) not null
                $value,       ## varchar(255) not null
                $rank         ## numeric(9,0)     null
                );
    }
    }
    else{
    $self->{_logger}->logdie("pubprop_id '$pubprop_id' was previously created during this ".
                 "current session for pub_id '$pub_id' type_id '$type_id' ".
                 "value '$value' rank '$rank'");
    }

    return $pubprop_id;

}##end sub do_store_new_pubprop {



##---------------------------------------------------------------------------------------------------------------
## do_store_new_feature_cvterm_dbxref()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_feature_cvterm_dbxref {

    my ($self, %params) = @_;

    my ($feature_cvterm_id, $dbxref_id);

    if (defined $params{'feature_cvterm_id'}){
    $feature_cvterm_id = $params{'feature_cvterm_id'};
    }
    else {
     $self->{_logger}->error("feature_cvterm_id was not defined.  Cannot insert record into chado.feature_cvterm_dbxref");
    return undef;
    }

    if (defined $params{'dbxref_id'}){
    $dbxref_id   = $params{'dbxref_id'};
    }
    else {
     $self->{_logger}->error("dbxref_id was not defined.  Cannot insert record into chado.feature_cvterm_dbxref");
    return undef;
    }

    my $seed = "$feature_cvterm_id:$dbxref_id";

    ##
    ## Check if feature_cvterm_dbxref_id was previously created during this current session
    ##
    my $feature_cvterm_dbxref_id = $self->{_id_manager}->lookupId("feature_cvterm_dbxref", $seed);
    if (!defined($feature_cvterm_dbxref_id)){
    ##
    ## feature_cvterm_dbxref_id was not previously created, therefore generate and store in chado.feature_cvterm_dbxref
    ##
    $feature_cvterm_dbxref_id = $self->{_id_manager}->nextId("feature_cvterm_dbxref", $seed);
    if (!defined($feature_cvterm_dbxref_id)){
        ##
        ## Could not generate feature_cvterm_dbxref_id 
        ##
        $self->{_logger}->error("Could not retrieve feature_cvterm_dbxref_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'feature_cvterm_dbxref', '$seed' ".
                    "\nCannot insert record into chado.feature_cvterm_dbxref for feature_cvterm_id ".
                    "'$feature_cvterm_id' dbxref_id '$dbxref_id'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.feature_cvterm_dbxref
        ##
        $self->_add_row(
                "feature_cvterm_dbxref",    ##  datatype:
                $feature_cvterm_dbxref_id,  ## numeric(9,0) not null
                $feature_cvterm_id,         ## numeric(9,0) not null
                $dbxref_id                  ## numeric(9,0) not null
                );
    }
    }

    return $feature_cvterm_dbxref_id;

}##end sub do_store_new_feature_cvterm_dbxref {



##---------------------------------------------------------------------------------------------------------------
## do_store_new_feature_cvterm_pub()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_feature_cvterm_pub {

    my ($self, %params) = @_;

    my ($feature_cvterm_id, $pub_id);

    if (defined $params{'feature_cvterm_id'}){
    $feature_cvterm_id = $params{'feature_cvterm_id'};
    }
    else {
     $self->{_logger}->error("feature_cvterm_id was not defined.  Cannot insert record into chado.feature_cvterm_pub");
    return undef;
    }

    if (defined $params{'pub_id'}){
    $pub_id = $params{'pub_id'};
    }
    else {
     $self->{_logger}->error("pub_id was not defined.  Cannot insert record into chado.feature_cvterm_pub");
    return undef;
    }

    my $seed = "$feature_cvterm_id:$pub_id";

    ##
    ## Check if feature_cvterm_pub_id was previously created during this current session
    ##
    my $feature_cvterm_pub_id = $self->{_id_manager}->lookupId("feature_cvterm_pub", $seed);
    if (!defined($feature_cvterm_pub_id)){
    ##
    ## feature_cvterm_pub_id was not previously created, therefore generate and store in chado.feature_cvterm_pub
    ##
    $feature_cvterm_pub_id = $self->{_id_manager}->nextId("feature_cvterm_pub", $seed);
    if (!defined($feature_cvterm_pub_id)){
        ##
        ## Could not generate feature_cvterm_pub_id 
        ##
        $self->{_logger}->error("Could not retrieve feature_cvterm_pub_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'feature_cvterm_pub', '$seed' ".
                    "\nCannot insert record into chado.feature_cvterm_pub for ".
                    "feature_cvterm_id '$feature_cvterm_id' pub_id '$pub_id'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.feature_cvterm_pub
        ##
        $self->_add_row(
                "feature_cvterm_pub",    ##  datatype:
                $feature_cvterm_pub_id,  ## numeric(9,0) not null
                $feature_cvterm_id,         ## numeric(9,0) not null
                $pub_id                  ## numeric(9,0) not null
                );
    }
    }

    return $feature_cvterm_pub_id;

}##end sub do_store_new_feature_cvterm_pub {
 



##---------------------------------------------------------------------------------------------------------------
## do_store_new_phylotree()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_phylotree {

    my ($self, %params) = @_;

    my ($dbxref_id, $type_id, $name, $comment);

    if (defined $params{'dbxref_id'}){
    $dbxref_id = $params{'dbxref_id'};
    }
    else {
     $self->{_logger}->error("dbxref_id was not defined.  Cannot insert record into chado.phylotree");
    return undef;
    }

    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
     $self->{_logger}->error("type_id was not defined.  Cannot insert record into chado.phylotree");
    return undef;
    }

    $name = (defined $params{'name'}) ?  $params{'name'} : undef;

    $comment = (defined $params{'comment'}) ?  $params{'comment'} : undef;


    ##
    ## Check if phylotree_id was previously created during this current session
    ## 
    ## The second key "phylotree" is temp. -jay
    ##
    my $phylotree_id = $self->{_id_manager}->lookupId("phylotree", "phylotree");
    if (!defined($phylotree_id)){
    ##
    ## phylotree_id was not previously created, therefore generate and store in chado.phylotree
    ##
    $phylotree_id = $self->{_id_manager}->nextId("phylotree", "phylotree");
    if (!defined($phylotree_id)){
        ##
        ## Could not generate phylotree_id 
        ##
        $self->{_logger}->error("Could not retrieve phylotree_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'phylotree', 'phylotree' ".
                    "\nCannot insert record into chado.phylotree for dbxref_id ".
                    "'$dbxref_id' name '$name' type_id '$type_id' comment '$comment'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.phylotree
        ##
        $self->_add_row(
                "phylotree",    ##  datatype:
                $phylotree_id,  ## numeric(9,0) not null
                $dbxref_id,     ## numeric(9,0) not null
                $name,          ## varchar(255)     null
                $type_id,       ## numeric(9,0) not null
                $comment        ## varchar(255)     null
                );
    }
    }

    return $phylotree_id;

}##end sub do_store_new_phylotree {




##---------------------------------------------------------------------------------------------------------------
## do_store_new_phylotree_pub()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_phylotree_pub {

    my ($self, %params) = @_;

    my ($phylotree_id, $pub_id);

    if (defined $params{'phylotree_id'}){
    $phylotree_id = $params{'phylotree_id'};
    }
    else {
     $self->{_logger}->error("phylotree_id was not defined.  Cannot insert record into chado.phylotree_pub");
    return undef;
    }

    if (defined $params{'pub_id'}){
    $pub_id = $params{'pub_id'};
    }
    else {
     $self->{_logger}->error("pub_id was not defined.  Cannot insert record into chado.phylotree_pub");
    return undef;
    }

    my $seed = "$phylotree_id:$pub_id";

    ##
    ## Check if phylotree_pub_id was previously created during this current session
    ## 
    my $phylotree_pub_id = $self->{_id_manager}->lookupId("phylotree_pub", $seed);
    if (!defined($phylotree_pub_id)){
    ##
    ## phylotree_pub_id was not previously created, therefore generate and store in chado.phylotree_pub
    ##
    $phylotree_pub_id = $self->{_id_manager}->nextId("phylotree_pub", $seed);
    if (!defined($phylotree_pub_id)){
        ##
        ## Could not generate phylotree_pub_id 
        ##
        $self->{_logger}->error("Could not retrieve phylotree_pub_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'phylotree_pub', '$seed' ".
                    "\nCannot insert record into chado.phylotree_pub for phylotree_id  ".
                    "'$phylotree_id' pub_id '$pub_id'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.phylotree
        ##
        $self->_add_row(
                "phylotree_pub",    ##  datatype:
                $phylotree_pub_id,  ## numeric(9,0) not null
                $phylotree_id,      ## numeric(9,0) not null
                $pub_id             ## numeric(9,0) not null
                );
    }
    }

    return $phylotree_pub_id;

}##end sub do_store_new_phylotree_pub {




##---------------------------------------------------------------------------------------------------------------
## do_store_new_phylonode()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_phylonode {

    my ($self, %params) = @_;

    my ($phylotree_id, $parent_phylonode_id, $left_idx, $right_idx, $type_id, $feature_id, $label,
    $distance);

    if (defined $params{'phylotree_id'}){
    $phylotree_id = $params{'phylotree_id'};
    }
    else {
     $self->{_logger}->error("phylotree_id was not defined.  Cannot insert record into chado.phylonode");
    return undef;
    }

    if (defined $params{'left_idx'}){
    $left_idx = $params{'left_idx'};        
    }
    else {
     $self->{_logger}->error("left_idx was not defined.  Cannot insert record into chado.phylonode");
    return undef;
    }

    if (defined $params{'right_idx'}){
    $right_idx = $params{'right_idx'};
    }
    else {
     $self->{_logger}->error("right_idx was not defined.  Cannot insert record into chado.phylonode");
    return undef;
    }

    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
     $self->{_logger}->error("type_id was not defined.  Cannot insert record into chado.phylonode");
    return undef;
    }

    $parent_phylonode_id = (defined $params{'parent_phylonode_id'}) ?  $params{'parent_phylonode_id'} : undef;

    $feature_id = (defined $params{'feature_id'}) ?  $params{'feature_id'} : undef;

    $label = (defined $params{'label'}) ?  $params{'label'} : undef;

    $distance = (defined $params{'distance'}) ?  $params{'distance'} : undef;

    my $seed =  "$phylotree_id:$left_idx";

    ##
    ## Check if phylonode_id was previously created during this current session
    ## 
    my $phylonode_id = $self->{_id_manager}->lookupId("phylonode", $seed);
    if (!defined($phylonode_id)){
    ##
    ## phylonode_id was not previously created, therefore generate and store in chado.phylonode
    ##
    $phylonode_id = $self->{_id_manager}->nextId("phylonode", $seed);
    if (!defined($phylonode_id)){
        ##
        ## Could not generate phylonode_id 
        ##
        $self->{_logger}->error("Could not retrieve phylonode_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'phylonode', '$seed' ".
                    "\nCannot insert record into chado.phylonode for phylotree_id ".
                    "'$phylotree_id' parent_phylonode_id '$parent_phylonode_id' ".
                    "left_idx '$left_idx' right_idx '$right_idx' type_id '$type_id' ".
                    "feature_id '$feature_id' label '$label' distance '$distance'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.phylonode
        ##
        $self->_add_row(
                "phylonode",          ## datatype:
                $phylonode_id,        ## numeric(9,0) not null
                $phylotree_id,        ## numeric(9,0) not null
                $parent_phylonode_id, ## numeric(9,0)     null
                $left_idx,            ## numeric(9,0) not null
                $right_idx,           ## numeric(9,0) not null
                $type_id,             ## numeric(9,0) not null
                $feature_id,          ## numeric(9,0)     null
                $label,               ## varchar(255)     null
                $distance             ## double precision null
                );
    }
    }

    return $phylonode_id;

}##end sub do_store_new_phylonode {
 



##---------------------------------------------------------------------------------------------------------------
## do_store_new_phylonode_dbxref()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_phylonode_dbxref {

    my ($self, %params) = @_;

    my ($phylonode_id, $dbxref_id);

    if (defined $params{'phylonode_id'}){
    $phylonode_id = $params{'phylonode_id'};
    }
    else {
     $self->{_logger}->error("phylonode_id was not defined.  Cannot insert record into chado.phylonode_dbxref");
    return undef;
    }

    if (defined $params{'dbxref_id'}){
    $dbxref_id = $params{'dbxref_id'};
    }
    else {
     $self->{_logger}->error("dbxref_id was not defined.  Cannot insert record into chado.phylonode_dbxref");
    return undef;
    }

    my $seed = "$phylonode_id:$dbxref_id";

    ##
    ## Check if phylonode_dbxref_id was previously created during this current session
    ## 
    my $phylonode_dbxref_id = $self->{_id_manager}->lookupId("phylonode_dbxref", $seed);
    if (!defined($phylonode_dbxref_id)){
    ##
    ## phylonode_dbxref_id was not previously created, therefore generate and store in chado.phylonode_dbxref
    ##
    $phylonode_dbxref_id = $self->{_id_manager}->nextId("phylonode_dbxref", $seed);
    if (!defined($phylonode_dbxref_id)){
        ##
        ## Could not generate phylonode_dbxref_id 
        ##
        $self->{_logger}->error("Could not retrieve phylonode_dbxref_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'phylonode_dbxref', '$seed' ".
                    "\nCannot insert record into chado.phylonode_dbxref for phylonode_id ".
                    "'$phylonode_id' dbxref_id '$dbxref_id'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.phylonode_dbxref
        ##
        $self->_add_row(
                "phylonode_dbxref",    ## datatype:
                $phylonode_dbxref_id,  ## numeric(9,0) not null
                $phylonode_id,         ## numeric(9,0) not null
                $dbxref_id             ## numeric(9,0) not null
                );
    }
    }

    return $phylonode_dbxref_id;

}##end sub do_store_new_phylonode_dbxref {
 


##---------------------------------------------------------------------------------------------------------------
## do_store_new_phylonode_pub()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_phylonode_pub {

    my ($self, %params) = @_;

    my ($phylonode_id, $pub_id);

    if (defined $params{'phylonode_id'}){
    $phylonode_id = $params{'phylonode_id'};
    }
    else {
     $self->{_logger}->error("phylonode_id was not defined.  Cannot insert record into chado.phylonode_pub");
    return undef;
    }

    if (defined $params{'pub_id'}){
    $pub_id = $params{'pub_id'};
    }
    else {
     $self->{_logger}->error("pub_id was not defined.  Cannot insert record into chado.phylonode_pub");
    return undef;
    }
    
    my $seed = "$phylonode_id:$pub_id";

    ##
    ## Check if phylonode_pub_id was previously created during this current session
    ## 
    my $phylonode_pub_id = $self->{_id_manager}->lookupId("phylonode_pub", $seed);
    if (!defined($phylonode_pub_id)){
    ##
    ## phylonode_pub_id was not previously created, therefore generate and store in chado.phylonode_pub
    ##
    $phylonode_pub_id = $self->{_id_manager}->nextId("phylonode_pub", $seed);
    if (!defined($phylonode_pub_id)){
        ##
        ## Could not generate phylonode_pub_id 
        ##
        $self->{_logger}->error("Could not retrieve phylonode_pub_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'phylonode_pub', '$seed' ".
                    "\nCannot insert record into chado.phylonode_pub for ".
                    "phylonode_id '$phylonode_id' pub_id '$pub_id'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.phylonode_pub
        ##
        $self->_add_row(
                "phylonode_pub",    ## datatype:
                $phylonode_pub_id,  ## numeric(9,0) not null
                $phylonode_id,      ## numeric(9,0) not null
                $pub_id             ## numeric(9,0) not null
                );
    }
    }

    return $phylonode_pub_id;

}##end sub do_store_new_phylonode_pub {
 
##---------------------------------------------------------------------------------------------------------------
## do_store_new_phylonode_organism()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_phylonode_organism {

    my ($self, %params) = @_;

    my ($phylonode_id, $organism_id);

    if (defined $params{'phylonode_id'}){
    $phylonode_id = $params{'phylonode_id'};
    }
    else {
     $self->{_logger}->error("phylonode_id was not defined.  Cannot insert record into chado.phylonode_organism");
    return undef;
    }
    
    if (defined $params{'organism_id'}){
    $organism_id = $params{'organism_id'};
    }
    else {
     $self->{_logger}->error("organism_id was not defined.  Cannot insert record into chado.phylonode_organism");
    return undef;
    }

    my $seed = "$phylonode_id:$organism_id";

    ##
    ## Check if phylonode_organism_id was previously created during this current session
    ## 
    my $phylonode_organism_id = $self->{_id_manager}->lookupId("phylonode_organism", $seed);
    if (!defined($phylonode_organism_id)){
    ##
    ## phylonode_organism_id was not previously created, therefore generate and store in chado.phylonode_organism
    ##
    $phylonode_organism_id = $self->{_id_manager}->nextId("phylonode_organism", $seed);
    if (!defined($phylonode_organism_id)){
        ##
        ## Could not generate phylonode_organism_id 
        ##
        $self->{_logger}->error("Could not retrieve phylonode_organism_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'phylonode_organism', '$seed' ".
                    "\nCannot insert record into chado.phylonode_organism for phylonode_id ".
                    "'$phylonode_id' organism_id '$organism_id'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.phylonode_organism
        ##
        $self->_add_row(
                "phylonode_organism",    ## datatype:
                $phylonode_organism_id,  ## numeric(9,0) not null
                $phylonode_id,           ## numeric(9,0) not null
                $organism_id             ## numeric(9,0) not null
                );
    }
    }

    return $phylonode_organism_id;

}##end sub do_store_new_phylonode_organism {
 



##---------------------------------------------------------------------------------------------------------------
## do_store_new_phylonodeprop()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_phylonodeprop {

    my ($self, %params) = @_;

    my ($phylonode_id, $type_id, $value, $rank);

    
    if (defined $params{'phylonode_id'}){
    $phylonode_id = $params{'phylonode_id'};
    }
    else {
     $self->{_logger}->error("phylonode_id was not defined.  Cannot insert record into chado.phylonodeprop");
    return undef;
    }

    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
     $self->{_logger}->error("type_id was not defined.  Cannot insert record into chado.phylonodeprop");
    return undef;
    }

    if (defined $params{'value'}){
    $value = $params{'value'};
    }
    else {
     $self->{_logger}->error("value was not defined.  Cannot insert record into chado.phylonodeprop");
    return undef;
    }

    if (defined $params{'rank'}){
    $rank = $params{'rank'};
    }
    else {
     $self->{_logger}->error("rank was not defined.  Cannot insert record into chado.phylonodeprop");
    return undef;
    }
    

    ##
    ## Check if phylonodeprop_id was previously created during this current session
    ## 
    my $phylonodeprop_id;

    do {

    $phylonodeprop_id = $self->{_id_manager}->lookupId("phylonodeprop", "$phylonode_id:$type_id:$rank");

    } while ((defined($phylonodeprop_id)) && (++$rank));


    if (!defined($phylonodeprop_id)){
    ##
    ## phylonodeprop_id was not previously created, therefore generate and store in chado.phylonodeprop
    ##
    $phylonodeprop_id = $self->{_id_manager}->nextId("phylonodeprop", "$phylonode_id:$type_id:$rank");
    if (!defined($phylonodeprop_id)){
        ##
        ## Could not generate phylonodeprop_id 
        ##
        $self->{_logger}->error("Could not retrieve phylonodeprop_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'phylonodeprop', '$phylonode_id:$type_id:$rank' ".
                    "\nCannot insert record into chado.phylonode_dbxref for phylonode_id ".
                    "'$phylonode_id' type_id '$type_id' value '$value' rank '$rank'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.phylonodeprop
        ##
        $self->_add_row(
                "phylonodeprop",   ## datatype:
                $phylonodeprop_id, ## numeric(9,0) not null
                $phylonode_id,     ## numeric(9,0) not null
                $type_id,          ## numeric(9,0) not null
                $value,            ## varchar(255) not null
                $rank              ## numeric(9,0) not null
                );
    }
    }
    else{
    $self->{_logger}->logdie("phylonodeprop_id '$phylonodeprop_id' was previously created during this ".
                 "current session for phylonode_id '$phylonode_id' type_id '$type_id' ".
                 "value '$value' rank '$rank'");
    }

    return $phylonodeprop_id;

}##end sub do_store_new_phylonodeprop {
 
##---------------------------------------------------------------------------------------------------------------
## do_store_new_phylonode_relationship()
##
##---------------------------------------------------------------------------------------------------------------
sub do_store_new_phylonode_relationship {

    my ($self, %params) = @_;
    
    my ($subject_id, $object_id, $type_id, $rank);

    if (defined $params{'subject_id'}){
    $subject_id = $params{'subject_id'};
    }
    else {
     $self->{_logger}->error("subject_id was not defined.  Cannot insert record into chado.phylonode_relationship");
    return undef;
    }

    if (defined $params{'object_id'}){
    $object_id = $params{'object_id'};
    }
    else {
     $self->{_logger}->error("subject_id was not defined.  Cannot insert record into chado.phylonode_relationship");
    return undef;
    }

    if (defined $params{'type_id'}){
    $type_id = $params{'type_id'};
    }
    else {
      $self->{_logger}->error("type_id was not defined.  Cannot insert record into chado.phylonode_relationship");
    return undef;
    }

    if (defined $params{'rank'}){
    $rank = $params{'rank'};
    }
    else {
     $self->{_logger}->error("rank was not defined.  Cannot insert record into chado.phylonode_relationship");
    return undef;
    }

    my $seed = "$subject_id:$object_id:$type_id";

    ##
    ## Check if phylonode_relationship_id was previously created during this current session
    ## 
    my $phylonode_relationship_id = $self->{_id_manager}->lookupId("phylonode_relationship", $seed);
    if (!defined($phylonode_relationship_id)){
    ##
    ## phylonode_relationship_id was not previously created, therefore generate and store in chado.phylonode_relationship
    ##
    $phylonode_relationship_id = $self->{_id_manager}->nextId("phylonode_relationship", $seed);
    if (!defined($phylonode_relationship_id)){
        ##
        ## Could not generate phylonode_relationship_id 
        ##
        $self->{_logger}->error("Could not retrieve phylonode_relationship_id from Coati::IdManager lookup, ".
                    "nor could it be generated.  Seed was 'phylonode_relationship', '$seed' ".
                  "\nCannot insert record into chado.phylonode_relationship for subject_id ".
                    "'$subject_id' object_id '$object_id' type_id '$type_id' rank '$rank'");
        return undef;
    }
    else{
        ##
        ## slot record in chado.phylonode_relationship
        ##
        $self->_add_row(
                "phylonode_relationship",   ## datatype:
                $phylonode_relationship_id, ## numeric(9,0) not null 
                $subject_id,                ## numeric(9,0) not null
                $object_id,                 ## numeric(9,0) not null
                $type_id,                   ## numeric(9,0) not null
                $rank                       ## numeric(9,0) not null
                );
    }
    }

    return $phylonode_relationship_id;

}##end sub do_store_new_phylonode_relationship {





1;




__END__


