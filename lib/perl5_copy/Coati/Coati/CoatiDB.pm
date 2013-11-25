package Coati::Coati::CoatiDB;

use strict;
use Carp;
use DBI;
use File::Basename;
use XML::Simple;
use Coati::Utility;
use Data::Dumper;
use Fcntl qw(O_RDONLY O_CREAT O_RDWR);
use DB_File;

sub new {
    my ($class) = shift;

    my $self = bless {}, ref($class) || $class;
    $self->{_logger} = Coati::Logger::get_logger(__PACKAGE__);
    $self->{_querylogger} = Coati::Logger::get_logger(__PACKAGE__.'_queries');
    $self->{_logger}->debug("Init $class") if $self->{_logger}->is_debug;
    $self->_init(@_);

    return $self;
}

sub _init {
    my $self = shift;

    my %arg = @_;
    foreach my $key (keys %arg) {
    $self->{_logger}->debug("Storing member variable $key as _$key=$arg{$key}") if $self->{_logger}->is_debug;
        $self->{"_$key"} = $arg{$key}
    }
}

sub DESTROY {
    my $self = shift;

    if($self->{_dbh}) {
    $self->{_dbh}->disconnect;
    }
}

sub set_login {
    my($self,$user,$password,$server,$db,$org,$seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->{_user} = $user;
    $self->{_password} = $password;
    $self->{_server} = $server;
    $self->{_db} = $db;
    $self->{_org} = $org,
    $self->{_seq_id} = $seq_id;
}

sub _get_results {
    my $self = shift;
    my $results = $self->_get_results_ref(@_);
    $self->{_querylogger}->debug("Returning database rows reference as array")  if $self->{_querylogger}->is_debug;
    return @$results;
}

sub _get_results_ref {
    my $self = shift;
    my ($query, @args) = @_;
    my $time = time;

    $self->{_logger}->debug("Args: ",join(',',@_)) if $self->{_logger}->is_debug;

    if(defined $self->{_data_cache_handler} && $self->{_data_cache_handler}->queryCache($self->{_db},$query,@args)) {
        return $self->{_data_cache_handler}->dumpCache;
    }

    $self->{_logger}->logdie("Attempting to run query $query with readonlycache flag set") if($ENV{_CACHE_FILE_ACCESS} eq 'O_RDONLY');

    if(! $self->{_dbh}){
        $self->{_dbh} = $self->connect;
    }


    my $dbh = $self->{_dbh};

    #################
    # modify query for MySQL if necessary.
    #################
    $query = $self->modify_query_for_db($query);

    if($self->{_querylogger}->is_debug){
        $self->{_querylogger}->debug("Preparing query $query");
    }
    my $sth = $dbh->prepare($query) or $self->{_querylogger}->logdie("Invalid query statement%%SQL/Database%%There is an invalid query or ".
        "it does not match table/column names in the database.  Please check ".
        "the SQL syntax and database schema%%$DBI::errstr%%$self->{_db}%%$query%%@args%%");

    #################
    # execute the query.
    #################
    $self->{_querylogger}->debug("Executing query with args '",join(',',@args),"'") if $self->{_querylogger}->is_debug;
    $sth->execute(@args) or $self->{_querylogger}->logdie("Query execution error%%SQL/Database%%There is a query that could not be executed.  ".
        "Please check the query syntax, arguments, and database schema".
        "%%$DBI::errstr%%$self->{_db}%%$query%%@args%%");

    my $results = $sth->fetchall_arrayref();

    if(defined $self->{_data_cache_handler}){
        $self->{_data_cache_handler}->seedCache($results,$self->{_db},$query,@args);
    }
    $self->{_querylogger}->debug("Returning ",scalar(@$results)," rows as reference")  if $self->{_querylogger}->is_debug;

    $time = time - $time;
    my (@call_info) = caller(1);

    open FILE, ">>$ENV{EXECUTION_TIME}" if ($ENV{EXECUTION_TIME});
    print FILE "\n------------";
    print FILE "\nCALLER: $call_info[3] ";
    print FILE "\nTIME: $time";
    print FILE "\nQUERY: $query";
    print FILE "\n";
    close FILE;
    return $results;
}
sub _get_results_hashref {
    my ($self, $query, @args) = @_;
    my $time = time;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;


    if(defined $self->{_data_cache_handler} && $self->{_data_cache_handler}->queryCache($self->{_db},$query,@args)) {
          return $self->{_data_cache_handler}->dumpCache;
    }

    if(! $self->{_dbh}){
          $self->{_dbh} = $self->connect;
    }

    $self->{_logger}->logdie("Attempting to run query $query with readonlycache flag set") if($ENV{_CACHE_FILE_ACCESS} eq 'O_RDONLY');

    my $dbh = $self->{_dbh};

    #################
    # modify query for MySQL if necessary.
    #################
    $query = $self->modify_query_for_db($query);

     if($self->{_querylogger}->is_debug){
          $self->{_querylogger}->debug("Preparing query $query");
    }
    my $sth = $dbh->prepare($query) or $self->{_querylogger}->logdie("Invalid query statement%%SQL/Database%%There is an invalid query or ".
                                                                                            "it does not match table/column names in the database.  Please check ".
                                                                                            "the SQL syntax and database schema%%$DBI::errstr%%$self->{_db}%%$query%%@args%%");

    #################
    # execute the query.
    #################
    $self->{_querylogger}->debug("Executing query with args '",join(',',@args),"'") if $self->{_querylogger}->is_debug;
    $sth->execute(@args) or $self->{_querylogger}->logdie("Query execution error%%SQL/Database%%There is a query that could not be executed.  ".
                                                                             "Please check the query syntax, arguments, and database schema".
                                                                             "%%$DBI::errstr%%$self->{_db}%%$query%%@args%%");
    my @results;
    while (my $hash_ref = $sth->fetchrow_hashref) {
          push @results, $hash_ref;  # Copy the array contents (See Perl DBI pg. 114)
    }
     
    if(defined $self->{_data_cache_handler}){
          $self->{_data_cache_handler}->seedCache(\@results,$self->{_db},$query,@args);
    }
    $self->{_querylogger}->debug("Returning ",scalar(@results)," rows as reference")  if $self->{_querylogger}->is_debug;
     
    $time = time - $time;    
    my (@call_info) = caller(1);
     
    open FILE, ">>$ENV{EXECUTION_TIME}" if ($ENV{EXECUTION_TIME});
    print FILE "\n------------";
    print FILE "\nCALLER: $call_info[3] ";
    print FILE "\nTIME: $time";
    print FILE "\nQUERY: $query";
    print FILE "\n";
    close FILE;
    return \@results;
}

sub _get_results_refmod {
    my ($self, $query, $subref, @args) = @_;
    my $results = $self->_get_results_ref($query, @args);
    $self->{_querylogger}->debug("Modifying result set with coderef: $subref") if $self->{_querylogger}->is_debug;;
    foreach $_ (@$results) {
        $subref->($_); # implicitly changes the results;
    }

    return $results;
}

sub _get_lookup_db {

    my ($self, $query, $keyColumnsLookup, @args) = @_;
    my $time = time;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my(@call_info) = caller(1);

    my $cachename = $self->{_data_cache_handler}->_buildCacheName($self->{_db},$query,('lookup_db',@args));

    my $filename =  "$self->{_data_cache_handler}->{_cachedir}/$cachename.$self->{_data_cache_handler}->{_fileext}";

    my %lookup;


    if(-e $filename){
    #
    # The tied DB_FILE cache lookup file does exist
    #
    if (( exists $self->{_data_cache_handler}->{_CACHE_FILE_ACCESS}) && (defined($self->{_data_cache_handler}->{_CACHE_FILE_ACCESS})) && ($self->{_data_cache_handler}->{_CACHE_FILE_ACCESS} eq 'O_RDONLY')   ){
        #
        # The tied DB_FILE cache file should have already been created by this point, therefore this module will only attempt to open the file in read-only mode.
        #
        eval {  my $dbtie = tie %lookup, 'DB_File', $filename, O_RDONLY, undef, $DB_BTREE or $self->{_logger}->logdie("Can't tie lookup $filename");
            $dbtie->filter_store_value( sub { $_ = join $;,@$_ } );
            $dbtie->filter_fetch_value( sub { $_ = [split /$;/,$_] } );
        };


        if ($@){
        $self->{_logger}->logdie("Error detected during tie: $!");
        }

        $self->{_logger}->debug("Opened lookup in read-only mode for $query $self->{_db},".join(',',@args)."\n");

    }
    else {
        #
        # Open the lookup in read-write mode
        #
        eval { my $dbtie = tie %lookup, 'DB_File', $filename, O_RDWR, undef, $DB_BTREE or $self->{_logger}->logdie("Can't tie lookup $filename");
        $dbtie->filter_store_value( sub { $_ = join $;,@$_ } );
        $dbtie->filter_fetch_value( sub { $_ = [split /$;/,$_] } );
        };


        if ($@){
        $self->{_logger}->logdie("Error detected:$!");
        }

        $self->{_logger}->debug("Opened lookup in read-write mode for $query $self->{_db},".join(',',@args)."\n");

    }


    #
    # Return reference to the tied DB_FILE lookup
    #
    return \%lookup;

    }
    else{
    #
    # The tied DB_FILE cache lookup file does not exist
    #
    if (( exists $self->{_data_cache_handler}->{_CACHE_FILE_ACCESS}) && (defined($self->{_data_cache_handler}->{_CACHE_FILE_ACCESS})) && ($self->{_data_cache_handler}->{_CACHE_FILE_ACCESS} eq 'O_RDONLY')   ){
        #
        # If the cached DB_FILE lookup does not already exist and the Cache/Data.pm attribute _CACHE_FILE_ACCESS == 'O_RDONLY', then this
        # CoatiDB.pm module should not attempt to create the cached lookup at this time.
        #
        $self->{_logger}->logdie("Cache file '$filename' does not exist, however cannot create cached lookup now since Cache::Data::_CACHE_FILE_ACCESS is '$self->{_data_cache_handler}->{_CACHE_FILE_ACCESS}'.  Parameters were db [$self->{_db}] query [$query] args [@args]");

    }
    else {
            #
        # When the cached DB_FILE lookup is being created for the first time, this module will open the cache file in read/write mode.
        #
        eval { my $dbtie = tie %lookup, 'DB_File', $filename, O_RDWR|O_CREAT, 0660, $DB_BTREE or $self->{_logger}->logdie("Can't tie lookup $filename: $!");
        $dbtie->filter_store_value( sub { $_ = join $;,@$_ } );
        $dbtie->filter_fetch_value( sub { $_ = [split /$;/,$_] } );

        };

        if ((exists $self->{_data_cache_handler}->{_SET_READONLY_CACHE}) &&
        ( defined($self->{_data_cache_handler}->{_SET_READONLY_CACHE}) ) &&
        ( $self->{_data_cache_handler}->{_SET_READONLY_CACHE} == 1) ){
        chmod 0444, $filename;
        }
        else{
        chmod 0666,$filename;
        }

        if ($@){
        $self->{_logger}->logdie("Error detected:$!");
        }

        $self->{_logger}->debug("Generating lookup for $query $self->{_db},".join(',',@args)."\n");
    }


    #
    # Initiate database connectivity and retrieval...
    #

    if(! $self->{_dbh}){
        $self->{_dbh} = $self->connect;
    }

    my $dbh = $self->{_dbh};

    #################
    # modify query for MySQL if necessary.
    #################
    $query = $self->modify_query_for_db($query);

    if($self->{_querylogger}->is_debug){
        $self->{_querylogger}->debug("Preparing query $query");
    }
    my $sth = $dbh->prepare($query) or $self->{_querylogger}->logdie("Invalid query statement%%SQL/Database%%There is an invalid query or ".
                                    "it does not match table/column names in the database.  Please check ".
                                    "the SQL syntax and database schema%%$DBI::errstr%%$self->{_db}%%$query%%@args%%");

    #################
    # execute the query.
    #################
    $self->{_querylogger}->debug("Executing query with args '",join(',',@args),"'") if $self->{_querylogger}->is_debug;
    $sth->execute(@args) or $self->{_querylogger}->logdie("Query execution error%%SQL/Database%%There is a query that could not be executed.  ".
                                "Please check the query syntax, arguments, and database schema".
                                "%%$DBI::errstr%%$self->{_db}%%$query%%@args%%");

    if (!defined $keyColumnsLookup){
        ## If none specified, then the first column returned shall alone be the lookup key
        while (my @array = $sth->fetchrow_array) {
        my $key = shift @array;
        $lookup{$key} = \@array;
        }
    }
    else{
        while (my @array = $sth->fetchrow_array) {

        my @lookupKeys;
        my @lookupValues;

        for (my $i=0; $i <scalar(@array);$i++){

            if (exists $keyColumnsLookup->{$i}){
            push(@lookupKeys, $array[$i]);
            }
            else {
            push(@lookupValues, $array[$i]);
            }
        }

        my $concatenatedKey = join("_", @lookupKeys);

        $lookup{ $concatenatedKey } = \@lookupValues;
        }
    }

    ## Return the newly populated tied DB_FILE lookup cache file
    $time = time - $time;

    open FILE, ">>$ENV{EXECUTION_TIME}" if ($ENV{EXECUTION_TIME});
    print FILE "\n------------";
    print FILE "\nCALLER: $call_info[3] ";
    print FILE "\nTIME: $time";
    print FILE "\nQUERY: $query";
    print FILE "\n";
    close FILE;
    return \%lookup;
    }
}








sub _do_sql {
    my ($self, $query, @args) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if(! $self->{_dbh}){
    $self->{_dbh} = $self->connect;
    }
    my $dbh = $self->{_dbh};

    #################
    # modify query for MySQL if necessary.
    #################
    $query = $self->modify_query_for_db($query);

    #################
    # check for invalid query.
    #################
    if($self->{_querylogger}->is_debug){
    $self->{_querylogger}->debug("Preparing query $query");
    }
    my $sth = $dbh->prepare($query) or $self->{_querylogger}->logdie("Invalid query statement%%SQL/Database%%There is an invalid query or it does ".
                                "not match table/column names in the database.  Please check the SQL syntax and ".
                                "database schema%%$DBI::errstr%%$self->{_db}%%$query%%@args%%");

    #################
    # execute the query.
    $sth->execute(@args) or $self->{_logger}->logdie("Query Execution Error%%SQL/Database%%There is a query that could not be executed.  ".
                            "Please check the query syntax, arguments, and database schema%%$DBI::errstr%%".
                            "$self->{_db}%%$query%%@args%%");

    #################
    # Notify calling function of success.
    #################
    $self->{_querylogger}->debug("Returning error string $DBI::errstr") if $self->{_querylogger}->is_debug;
    return $DBI::errstr;
}

sub _force_do_sql {
    my ($self, $query, @args) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if(! $self->{_dbh}){
    $self->{_dbh} = $self->connect;
    }
     my $dbh = $self->{_dbh};

    #################
    # modify query for MySQL if necessary.
    #################
    $query = $self->modify_query_for_db($query);

    #################
    # check for invalid query.
    #################
    if($self->{_querylogger}->is_debug){
    $self->{_querylogger}->debug("Preparing query $query");
    }
    my $sth = $dbh->prepare($query);
    if  (($DBI::errstr eq "") or ($DBI::errstr=~ /number=3701/) or ($DBI::errstr =~ /number=3712/) or ($DBI::errstr =~ /number=4622/)){
    # fine
    $self->{_querylogger}->debug("Sybase reported return code '$DBI::errstr'");
    }
    else{
    $self->{_querylogger}->warn("Invalid query statement%%SQL/Database%%There is an invalid query or it does ".
                "not match table/column names in the database.  Please check the SQL syntax and ".
                "database schema%%$DBI::errstr%%$self->{_db}%%$query%%@args%%");
    }

    #################
    # execute the query.
    #################
    $self->{_querylogger}->debug("Executing query with args '",join(',',@args),"'") if $self->{_querylogger}->is_debug;
    $sth->execute(@args);
    if  (($DBI::errstr eq "") or ($DBI::errstr=~ /number=3701/) or ($DBI::errstr =~ /number=3712/) or ($DBI::errstr =~ /number=4622/)){
    #fine
    $self->{_querylogger}->debug("Sybase reported return code '$DBI::errstr'");
    }
    else{
    $self->{_logger}->warn("Query Execution Error%%SQL/Database%%There is a query that could not be executed.  ".
                "Please check the query syntax, arguments, and database schema%%$DBI::errstr%%".
                "$self->{_db}%%$query%%@args%%");
    }


    #################
    # Notify calling function of success.
    #################
    $self->{_querylogger}->debug("Returning error string $DBI::errstr") if $self->{_querylogger}->is_debug;
    return $DBI::errstr;
}

sub _do_sql_lines {
    my ($self, $query, @args) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if(! $self->{_dbh}){
    $self->{_dbh} = $self->connect;
    }
    my $dbh = $self->{_dbh};

    #################
    # modify query for MySQL if necessary.
    #################
    $query = $self->modify_query_for_db($query);


    $self->{_dbh}->{'syb_chained_txn'} = 0;

    #################
    # check for invalid query.
    #################
    if($self->{_querylogger}->is_debug){
    $self->{_querylogger}->debug("Preparing query $query");
    }
    my $sth = $dbh->prepare($query) or $self->{_querylogger}->logdie("Invalid query statement%%SQL/Database%%There is an invalid query or it does ".
                                "not match table/column names in the database.  Please check the SQL syntax and ".
                                "database schema%%$DBI::errstr%%$self->{_db}%%$query%%@args%%");

    #################
    # execute the query.
    #################
    $sth->execute(@args) or $self->{_logger}->logdie("Query Execution Error%%SQL/Database%%There is a query that could not be executed.  ".
                            "Please check the query syntax, arguments, and database schema%%$DBI::errstr%%".
                            "$self->{_db}%%$query%%@args%%");


    $self->{_dbh}->commit();
    $self->{_dbh}->{'syb_chained_txn'} = 1;

    #################
    # Notify calling function of success.
    #################
    $self->{_querylogger}->debug("Returning error string $DBI::errstr") if $self->{_querylogger}->is_debug;
    return $DBI::errstr;
}



sub _add_row{ 	                     #################
     my($self) = shift; 	     # Notify calling function of success.
     $self->set_row(@_); 	     #################
     return $DBI::errstr;
 }

sub _set_values {
    my ($self, $query, @args) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if(! $self->{_dbh}) {
    $self->{_dbh} = $self->connect;
    }
    my $dbh = $self->{_dbh};

    #################
    # modify query for MySQL if necessary.
    #################
    $query = $self->modify_query_for_db($query);

    #################
    # check for invalid query.
    #################
    if($self->{_querylogger}->is_debug){
    $self->{_querylogger}->debug("Preparing query $query");
    }
    my $sth = $dbh->prepare($query) or $self->{_querylogger}->logdie("Invalid query statement%%SQL/Database%%There is an invalid query or it ".
                                "does not match table/column names in the database.  Please check the SQL ".
                                "syntax and database schema%%$DBI::errstr%%$self->{_db}%%$query%%@args%%");

    #################
    # execute the query.
    #################
    $sth->execute(@args) or $self->{_logger}->logdie("Query Execution Error%%SQL/Database%%There is a query that could not be executed.  ".
                            "Please check the query syntax, arguments, and database schema%%$DBI::errstr%%".
                            "$self->{_db}%%$query%%@args%%");

    $self->{_querylogger}->debug("Returning error string $DBI::errstr") if $self->{_querylogger}->is_debug;
    return $DBI::errstr;
}

sub _do_db_to_permissions {
    my ($self, $query, @args) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if(! $self->{_dbh}){
    $self->{_dbh} = $self->connect;
    }
    my $dbh = $self->{_dbh};


    #################
    # check for invalid query.
    #################
    if($self->{_querylogger}->is_debug){
    $self->{_querylogger}->debug("Preparing query $query");
    }
    my $sth = $dbh->prepare($query) or return 1;

    #################
    # execute the query.
    #################
    $self->{_querylogger}->debug("Executing query with args '",join(',',@args),"'") if $self->{_querylogger}->is_debug;
    $sth->execute(@args) or return 1;
    $self->{_querylogger}->debug("Returning error string $DBI::errstr") if $self->{_querylogger}->is_debug;
    return $DBI::errstr; ## Notify calling function of success.
}


sub get_dbtest{
    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT 1 ";

    return $self->_get_results_ref($query);
}



######################
# GENE_ID INPUT_TYPE #
######################

sub get_gene_id_to_feat_id {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT feat_id ".
            "FROM asm_feature ".
        "WHERE feat_name = ? ";

    return $self->_get_results_ref($query, $gene_id);
}

sub get_gene_id_to_HMM_acc {
    my ($self, $gene_id, $HMM_acc) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT accession ".
            "FROM evidence ".
                "WHERE feat_name = ? ".
        "AND ev_type = ? ";

    if($HMM_acc) {
    $query .= "AND accession != '$HMM_acc' ";
    }

    return $self->_get_results_ref($query, $gene_id, 'HMM2');
}

sub get_gene_id_to_interpro {
    my ($self, $gene_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT e.accession ".
            "FROM evidence e " .
                "WHERE feat_name = ? " .
                "AND ev_type = ? ";

    return $self->_get_results_ref($query, $gene_id, "Interpro");
}

############################
#^ END GENE_ID INPUT_TYPE ^#
##################################################################




#####################
# SEQ_ID INPUT_TYPE #
#####################

sub get_seq_id_to_genome_properties {
    my ($self, $seq_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT fl.feat_name, pd.prop_acc, p.property, p.state ".
            "FROM common..step_feat_link fl, common..step_ev_link el, common..prop_step ps, ".
        "common..prop_def pd, common..property p ".
        "WHERE fl.asmbl_id = $seq_id ".
        "AND fl.db = '$db' ".
        "AND fl.step_ev_id = el.step_ev_id ".
        "AND el.prop_step_id = ps.prop_step_id ".
        "AND ps.prop_def_id = pd.prop_def_id ".
        "AND pd.prop_def_id = p.prop_def_id ".
        "AND p.db = '$db' ";

    return $self->_get_results_ref($query);
}

###########################
#^ END SEQ_ID INPUT_TYPE ^#
##################################################################





######################
# ROLE_ID INPUT_TYPE #
######################

sub get_role_id_to_gene_descriptions {
    my ($self, $role_id, $seq_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT i.feat_name, i.locus, i.com_name, i.gene_sym, i.complete, i.auto_annotate, i.ec#, a.asmbl_id, a.end5, a.end3 ";

    if ($seq_id eq "ISCURRENT") {
        $query .= "FROM ident i, role_link r, asm_feature a, stan s " .
                  "WHERE r.role_id = $role_id " .
                  "AND r.feat_name = a.feat_name " .
        "AND a.asmbl_id = s.asmbl_id ".
        "AND s.iscurrent = 1 ".
                  "AND a.feat_name = i.feat_name ";
    } else {
        $query .= "FROM ident i, role_link r, asm_feature a " .
                  "WHERE role_id = $role_id " .
                  "AND r.feat_name = a.feat_name " .
                  "AND a.asmbl_id = $seq_id " .
                  "AND a.feat_name = i.feat_name ";
    }
    $query .= "ORDER BY upper(com_name), i.feat_name";

    return $self->_get_results_ref($query);
}

############################
#^ END ROLE_ID INPUT_TYPE ^#
##################################################################





#################################
# FS_ID (FRAMESHIFT) INPUT_TYPE #
#################################

sub get_fs_id_to_edit_report {
    my ($self, $fs_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT feat_id, fs_id, report, person, date_loaded, olapid, end5, end3, comment, repair# ".
            "FROM edit_report ".
        "WHERE fs_id = ? ";

    return $self->_get_results_ref($query, $fs_id);
}

sub get_fs_id_to_region_evaluation {
    my ($self, $fs_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT person, date_comp, \#repaired, comment ".
            "FROM region_evaluation ".
        "WHERE fs_id = ? ".
        "ORDER BY date_comp DESC ";

    return $self->_get_results_ref($query, $fs_id);
}

sub get_fs_id_to_sequence {
    my ($self, $fs_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT subst_old, subst_new ".
            "FROM subst_table ".
        "WHERE fs_id = ? ";

    return $self->_get_results_ref($query, $fs_id);
}

#######################################
#^ END FS_ID (FRAMESHIFT) INPUT_TYPE ^#
##################################################################




########################
#   ALL INPUT_TYPE     #
########################

sub get_all_GO_term {
    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT go_id, name, type, definition, comment ".
            "FROM common..go_term ";

    return $self->_get_results_ref($query);
}

sub get_all_GO_link {
    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT parent_id, child_id, link_type ".
            "FROM common..go_link ";

    return $self->_get_results_ref($query);
}

sub get_all_GO_synonym  {
     my ($self) = @_;

     $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

     my $query = "SELECT go_id, synonym ".
            "FROM common..go_synonym ";

    return $self->_get_results_ref($query);
}

sub get_all_TI_terms {
    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT go_id, name, type, definition, last_update, assigned_by ".
            "FROM common..go_term ".
        "WHERE go_id like \"TI%\" ";

    return $self->_get_results_ref($query);
}

sub get_all_genome_databases {
    my ($self) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT db ".
            "FROM common..genomes " .
                "WHERE type LIKE \"%microbial\" " .
                "AND stage IN ('annotation', 'published')";

    return $self->_get_results_ref($query);
}






########################
#^ END ALL INPUT_TYPE ^#
##################################################################





########################
#    DB INPUT_TYPE     #
########################

sub get_db_to_GO {
    my ($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT feat_name, go_id ".
            "FROM $db..go_role_link ";

    return $self->_get_results_ref($query);
}

sub get_db_to_permissions {
    my ($self, $db) = @_;

    return $self->_do_db_to_permissions("use $db");
}

#######################
#^ END DB INPUT_TYPE ^#
##################################################################




###########################
#    GO ID INPUT_TYPE     #
###########################

sub get_GO_id_to_parent {
    my ($self, $GO_id, $link_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT parent_id, child_id, link_type, assigned_by, date ".
            "FROM common..go_link ".
            "WHERE child_id = ? ";

    if($link_type) {
    $query .= "AND link_type = '$link_type' ";
    }

    return $self->_get_results_ref($query, $GO_id);
}

sub get_GO_id_to_child {
    my ($self, $GO_id, $link_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @query_params = ($GO_id);

    my $query = "SELECT parent_id, child_id, link_type, assigned_by, date " .
                "FROM common..go_link " .
                "WHERE parent_id = ? ";

    if ($link_type) {
        push (@query_params, $link_type);
        $query .= "AND link_type = ?";
    }

    return $self->_get_results_ref($query, @query_params);
}

sub get_GO_id_to_gene_association {
    my ($self, $GO_id, $gene_id, $prok_only) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT DISTINCT gene_id, go_id, db, gene_name, aspect ".
            "FROM common..go_gene_association ";

    if(!$gene_id) {
    $query .= "WHERE go_id = '$GO_id' ";
    }
    else {
    $query .= "WHERE gene_id = '$gene_id' ";
    }

    if($prok_only) {
    $query .= "AND db = '$self->{_db}_TIGR' ";
    }

    $query .= "ORDER BY gene_id ASC";

    return $self->_get_results_ref($query);
}

sub get_GO_id_to_new_GO_id {
    my ($self, $GO_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $next_id;
    my $max_num = 0;
    $GO_id = uc($GO_id);
    my $prefix = $GO_id;
    $prefix =~ s/.*(\w{2}\:)\d+.*/$1/;

    if($prefix) {

        if($prefix =~ /go/i) {
            $prefix = "TI:";
        }

        my $query = "SELECT max(go_id) ".
                "FROM common..go_term ".
            "WHERE go_id LIKE \"$prefix%\" ";

        my $ret = $self->_get_results_ref($query);
        my $max_id = $ret->[0][0];

        if ($max_id =~ /(\d+)$/) {
            $max_num = int($1);
        }
        $max_num++;
        my $pad = 7 - length ($max_num);
        $max_num = (0 x $pad) . $max_num;
        $next_id = $prefix . $max_num;
    }
    return $next_id;
}

sub get_GO_id_to_db_xref {
    my($self, $GO_id, $type) = @_;

    my $query = "SELECT gm.identifier " .
            "FROM common..go_map gm " .
            "WHERE gm.go_id = ? " .
            "AND gm.db = ? ";

    return $self->_get_results_ref($query, $GO_id, $type);
}

##########################
#^ END GO_ID INPUT_TYPE ^#
##################################################################





########################
# ACCESSION INPUT_TYPE #
########################

sub get_HMM_acc_to_GO {
    my ($self, $HMM_acc) = @_;
	
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

	# remove version number if it exists; hmm_go_link does not use version numbers yet
	if($HMM_acc =~ /\./) {
		$HMM_acc =~ s/\.(.*)//g;
	}

    my $query = "SELECT id, hmm_acc, go_term, curated, owner, mod_date, comment, qualifier, arch_term, bact_term, euk_term ".
            "FROM egad..hmm_go_link ".
            "WHERE hmm_acc = '$HMM_acc' ";

    return $self->_get_results_ref($query);
}

sub get_cog_acc_to_COG {
    my ($self, $cog_acc) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT accession, com_name, gene_sym " .
            "FROM common..cog " .
        "WHERE accession = ? ";

    return $self->_get_results_ref($query, $cog_acc);
}

sub acc_to_GO_gene_association {
    my ($self, $acc) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a.db, a.gene_id, a.gene_symbol, a.go_id, a.id, e.db_ref, e.ev_code, e.with_ev ".
            "FROM common..go_gene_association a, common..association_evidence e ".
        "WHERE a.gene_id = ? ".
        "AND a.id = e.association_id ";

    return $self->_get_results_ref($query, $acc);
}

##############################
#^ END ACCESSION INPUT_TYPE ^#
##################################################################





############################
#     MISC INPUT_TYPE      #
############################

sub get_custom_query_to_results {
    my ($self, $query, @args) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    return $self->_get_results_ref($query, @args);
}

sub get_conditional {
    my ($self, $query) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($query eq "") {
    $query = "SELECT count(*) ".
            "FROM asm_feature f, ORF_attribute o, clone_info c ".
        "WHERE f.feat_name = o.feat_name ".
        "AND f.asmbl_id = c.asmbl_id ".
        "AND c.asmbl_id != c.final_asmbl ".
        "AND o.att_type = 'TEMPFAM' ";
    }

    #
    # Check for cached data first
    if(!$self->{_data_cache_handler}) {
    #
    # Turn memory query caching on.
    # Persist queries for current instance only.
    $self->{_data_cache_handler} = new Coati::Cache::Data('MEMORY'=>1,
                                'FILE'=>1);
    $self->{_use_cache} = 1;
    #
    # Turn memory query caching off
    $self->{_data_cache_handler} = undef;
    $self->{_use_cache} = 0;
    my $ret = $self->_get_results_ref($query);
    return $ret->[0][0];
    }
    #
    # Else, run query and return result
    else {
    my $ret = $self->_get_results_ref($query);
    return $ret->[0][0];
    }
}


sub get_score_type_to_score_id{
    my($self,$score_type,$input_type)=@_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT id "
        ." FROM common..score_type "
        ." WHERE score_type =\"$score_type\" "
        ." and input_type= \"$input_type\" ";



    return $self->_get_results_ref($query);
}

##########################
#^ END MISC INPUT_TYPES ^#
##################################################################





######################
#  INSERT FUNCTIONS  #
######################

sub do_insert_new_ontology_id {
    my ($self, $parent_id, $ontology_id, $link_type, $name, $definition, $parent_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    ####################
    # Retrieve a list of parent_ids which are not also children.
    ####################
    my $query = "INSERT common..go_link (parent_id, child_id, link_type, assigned_by, date) " .
                "VALUES (?, ?, ?, ?, getdate())";
    $self->_set_values($query, $parent_id, $ontology_id, $link_type, $self->{_user});

    #####################
    # Insert new ontology term.
    #####################
    my $query_pt1 = "INSERT common..go_term (go_id, name, assigned_by, date, last_update";
    my $query_pt2 = " VALUES (\"$ontology_id\", \"$name\", \"$self->{_user}\", getdate(), getdate()";
    if ($parent_type) {
    $query_pt1 .= ", type";
    $query_pt2 .= ", \"$parent_type\"";
    }
    if ($definition) {
    $query_pt1 .= ", definition";
    $query_pt2 .= ", \"$definition\"";
    }
    $query = "$query_pt1) $query_pt2)";
    $self->_set_values($query);
}

sub do_insert_ontology_link {
    my ($self, $parent_id, $child_id, $link_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "INSERT common..go_link (parent_id, child_id, link_type, assigned_by, date) " .
                "VALUES (?, ?, ?, ?, getdate())";

    $self->_set_values($query, $parent_id, $child_id, $link_type, $self->{_user});
}

sub do_insert_frameshift {
    my ($self, $fs_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query_pt1 = "INSERT frameshift (feat_name, fs_accession, att_type, curated, assignby ";
    my $query_pt2 =  "VALUES ('$fs_ref->{'gene_id'}', '$fs_ref->{'fs_accession'}', '$fs_ref->{'att_type'}', $fs_ref->{'curated'}, '$fs_ref->{'assignby'}' ";

    if(defined $fs_ref->{'comment'}){
    $query_pt1 .= ", comment";
    $query_pt2 .= ", '$fs_ref->{'comment'}'";
    }

    if($fs_ref->{'assigndate'}) {
    $query_pt1 .= ", date";
    if($fs_ref->{'assigndate'} == 1) {
        $query_pt2 .= ", getdate()";
    }
    else {
        $query_pt2 .= ", '$fs_ref->{'assigndate'}'";
    }
    }

    if ($fs_ref->{'cpt_date'}) {
    $query_pt1 .= ", cpt_date";
    if ($fs_ref->{'cpt_date'} == 1){
        $query_pt2 .= ", getdate()";
    }
    else {
        $query_pt2 .= ", '$fs_ref->{'cpt_date'}'";
    }
    }

    if ($fs_ref->{'vrf_date'}) {
    $query_pt1 .= ", vrf_date";
    if ($fs_ref->{'vrf_date'} == 1) {
        $query_pt2 .= ", getdate()";
    }
    else {
        $query_pt2 .= ", '$fs_ref->{'vrf_date'}'";
    }
    }

    if (defined $fs_ref->{'labperson'}) {
    $query_pt1 .= ", labperson";
    $query_pt2 .= ", '$fs_ref->{'labperson'}'";
    }

    if (defined $fs_ref->{'reviewby'}) {
    $query_pt1 .= ", reviewby";
    $query_pt2 .= ", '$fs_ref->{'reviewby'}'";
    }
    my $query = "$query_pt1) $query_pt2)";

    $self->_set_values($query);
}

sub do_insert_subst {
    my ($self, $subst_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "INSERT subst_table (fs_id, subst_old, subst_new) ".
            "VALUES (?, ?, ?)";

    $self->_set_values($query, $subst_ref->{'fs_id'}, $subst_ref->{'subst_old'}, $subst_ref->{'subst_new'});
}

sub do_insert_edit_report {
    my ($self, $report_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "INSERT edit_report (feat_id, fs_id, report, person, date_loaded, olapid, end5, end3, comment, repair#) ".
            "VALUES ($report_ref->{'feat_id'},  $report_ref->{'fs_id'}, \"$report_ref->{'report'}\", '$report_ref->{'person'}', getdate(), '$report_ref->{'olapid'}', $report_ref->{'end5'}, $report_ref->{'end3'}, '$report_ref->{'comment'}', $report_ref->{'repair#'}) ";

    $self->_set_values($query);
}

sub do_insert_region_evaluation {
    my ($self, $labinfo_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my $comment = $labinfo_ref->{'comment'} ? $labinfo_ref->{'comment'} : "";

    my $query = "INSERT region_evaluation (fs_id, person, date_comp, \#repaired, comment) ".
            "VALUES (?, ?, getdate(), ?, ?) ";

    $self->_set_values($query, $labinfo_ref->{'fs_id'}, $labinfo_ref->{'person'}, $labinfo_ref->{'#repaired'}, $comment);
}

sub do_insert_role_notes {
    my ($self, $role_id, $new_notes, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $len = length($new_notes);
    $self->do_set_textsize($len);

    my $query = "INSERT $db..role_notes (role_id, notes) ".
            "VALUES ($role_id, \"$new_notes\") ";

    $self->_set_values($query);
}

##########################
#^ END INSERT FUNCTIONS ^#
##################################################################






######################
#  UPDATE FUNCTIONS  #
######################

sub do_update_evidence {
    my($self, $evidence_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "UPDATE evidence SET ".
            "curated = $evidence_ref->{'curated'}, ".
            "assignby = isnull(\"$self->{_user}\", suser_name()), ".
            "date = getdate(),  ".
            "save_history = 1 ".
            "WHERE id = $evidence_ref->{'id'} ";

    $self->_set_values($query);
}

sub do_update_evidence_curation {
    my ($self, $id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT curated ".
            "FROM evidence ".
        "WHERE id = ? ";

    my $x = $self->_get_results_ref($query, $id);

    my $curation = $x->[0][0];
    my $new = ($curation == 0) ? 1 : 0;

    $query = "UPDATE evidence ".
             "SET curated = $new ".
             "WHERE id = ? ";

    $self->_set_values($query, $id);
}

sub do_update_attribute_curation {
    my ($self, $id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT curated ".
            "FROM ORF_attribute ".
            "WHERE id = ? ";

    my $x =  $self->_get_results_ref($query, $id);

    my $curation = $x->[0][0];
    my $new = ($curation == 0) ? 1 : 0;

    $query = "UPDATE ORF_attribute ".
             "SET curated = $new ".
             "WHERE id = ? ";

    $self->_set_values($query, $id);
}

sub do_update_signalP_curation {
    my ($self, $gene_id, $id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT curated ".
            "FROM ORF_attribute ".
            "WHERE id = ? ";

    my $x =  $self->_get_results_ref($query, $id);

    my $curation = $x->[0][0];
    my $new = ($curation == 0) ? 1 : 0;

    $query = "UPDATE ORF_attribute ".
             "SET curated = $new ".
             "WHERE id = ? ";

    $self->_set_values($query, $id);
}

sub do_update_COG_curation {
    my ($self, $gene_id, $curated, $COG_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "UPDATE $db..ORF_attribute ".
            "SET curated = ? ".
        "WHERE feat_name = ? ".
        "AND score = ? ".
        "AND att_type = 'COG_curation' ";

    $self->_set_values($query, $curated, $gene_id, $COG_id);
}

sub do_update_signalP {
    my ($self, $gene_id, $prediction, $type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "UPDATE ORF_attribute " .
                "SET score2 = ?, assignby = ?, date = getdate() ".
                "WHERE att_type = ? ".
                "AND feat_name = ?";

    $self->_set_values($query, $prediction, $self->{_user}, $type, $gene_id);
}

sub do_update_GO_term {
    my ($self, $GO_id, $name, $type, $definition) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "UPDATE common..go_term ".
            "SET name = \"$name\", type = \"$type\", definition = \"$definition\" ".
        "WHERE go_id = ? ";

    $self->_set_values($query, $GO_id);
}

sub do_update_GO_link {
    my ($self, $child_id, $parent_id) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "UPDATE common..go_link ".
            "SET parent_id = \"$parent_id\" ".
        "WHERE child_id = ? ";

    $self->_set_values($query, $child_id);
}

sub do_update_frameshift {
    my ($self, $fs_ref, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query_pt1  = "UPDATE frameshift SET ";
    $query_pt1 .= "assignby = '$fs_ref->{'user'}, "             if(defined $fs_ref->{'user'});
    $query_pt1 .= "curated = $fs_ref->{'curated'}, "            if(defined $fs_ref->{'curated'});
    $query_pt1 .= "date = getdate(), "                           if(defined $fs_ref->{'assigndate'});
    $query_pt1 .= "fs_accession = '$fs_ref->{'fs_accession'}', " if(defined $fs_ref->{'fs_accession'});
    $query_pt1 .= "comment = '$fs_ref->{'comment'}', "           if(defined $fs_ref->{'comment'});
    $query_pt1 .= "cpt_date = getdate(), "                       if(defined $fs_ref->{'cpt_date'});
    $query_pt1 .= "labperson = '$fs_ref->{'labperson'}', "       if(defined $fs_ref->{'labperson'});
    $query_pt1 .= "reviewby = '$fs_ref->{'reviewby'}', "         if(defined $fs_ref->{'reviewby'});

    if(defined $fs_ref->{'vrf_date'}) {
    $query_pt1 .= "vrf_date = getdate(), ";
    }
    else{
    $query_pt1 .= "vrf_date = null, ";
    }


    ################
    # Create the constraint part of the update query.
    ################
    my $query_pt2  = " WHERE ";

    if($fs_ref->{'key_gene_id'} && $fs_ref->{'key_att_type'}) {
    $query_pt2 .= "feat_name = '$fs_ref->{'gene_id'}' ".
                "AND att_type in ('FS', 'PM', 'AMB', 'AFS', 'APM', 'DEG', 'FRAG', 'FIXED') ";
    }
    else {
    $query_pt1 .= "att_type = 'FS', "    if(defined $fs_ref->{'FS'});
    $query_pt1 .= "att_type = 'PM', "    if(defined $fs_ref->{'PM'});
    $query_pt1 .= "att_type = 'AMB', "   if(defined $fs_ref->{'AMB'});
    $query_pt1 .= "att_type = 'AFS', "   if(defined $fs_ref->{'AFS'});
    $query_pt1 .= "att_type = 'APM', "   if(defined $fs_ref->{'APM'});
    $query_pt1 .= "att_type = 'DEG', "   if(defined $fs_ref->{'DEG'});
    $query_pt1 .= "att_type = 'FRAG', "  if(defined $fs_ref->{'FRAG'});
    $query_pt1 .= "att_type = 'FIXED', " if(defined $fs_ref->{'FIXED'});

    if($fs_ref->{'key_gene_id'} && $fs_ref->{'key_fs_id'}) {
        $query_pt2 .= "feat_name = '$fs_ref->{'gene_id'}' ".
                "AND id = $fs_ref->{'fs_id'} ";
    }
    elsif ($fs_ref->{'key_fs_id'}) {
        $query_pt2 .= "id = $fs_ref->{'fs_id'} ";
    }
    elsif ($fs_ref->{'key_gene_id'}) {
        $query_pt2 .= "feat_name = '$fs_ref->{'gene_id'}' ";
    }
    }
    $query_pt1 =~ s/\s+$//;
    $query_pt1 =~ s/\,$//;
    my $query = $query_pt1 . $query_pt2;

    $self->_set_values($query);
}

sub do_update_subst {
    my ($self, $subst_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "UPDATE subst_table ".
            "SET subst_new = ? " .
            "WHERE fs_id = ? ".
        "AND subst_old = ?";

    $self->_set_values($query, $subst_ref->{'subst_new'}, $subst_ref->{'fs_id'}, $subst_ref->{'subst_old'});
}

sub do_update_hmm_inter_link {
    my ($self, $hmm_acc, $rel_acc, $rel_type, $rel_base, $status) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "INSERT egad..hmm_inter_link (hmm_acc, rel_acc, rel_type, rel_base, status) ".
        "VALUES (?, ?, ?, ?, ?) ";

    $self->_set_values($query, $hmm_acc, $rel_acc, $rel_type, $rel_base, $status);
}

sub do_update_role_notes {
    my ($self, $role_id, $new_notes, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $len = length($new_notes);
    $self->do_set_textsize($len);

    my $query = "UPDATE $db..role_notes ".
            "SET notes = \"$new_notes\" ".
            "WHERE role_id = ? ";

    $self->_set_values($query, $role_id);
}

sub do_update_GO_id {
    my ($self, $gene_id, $GO_id, $qualifier, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    if($gene_id !~ /\d+\.t\d+/) {
    $gene_id = $self->get_handle_gene_id($gene_id, $db);
    }

    my $query = "UPDATE $db..go_role_link SET assigned_by = ? ".
            "WHERE feat_name = ? ".
        "AND go_id = ? ";

    $self->_set_values($query, $self->{_user}, $gene_id, $GO_id);
}

sub do_custom_query_update {
    my ($self, $query, @args) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    $self->_set_values($query, @args);
}

##########################
#^ END UPDATE FUNCTIONS ^#
##################################################################





######################
#  DELETE FUNCTIONS  #
######################

sub do_delete_GO_for_gene_id {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = $self->{_db} if(!$db);

    $self->do_delete_GO_id($gene_id);
    $self->do_update_auto_annotate($gene_id, $db);
}

sub do_delete_frameshift {
    my ($self, $fs_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE ".
            "FROM frameshift ".
        "WHERE feat_name = ? ".
        "AND id = ? ";

    $self->_set_values($query, $fs_ref->{'gene_id'}, $fs_ref->{'fs_id'});
}

sub do_delete_subst {
    my ($self, $subst_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE ".
            "FROM subst_table ".
        "WHERE fs_id = ? ";

    $self->_set_values($query, $subst_ref->{'fs_id'});
}

sub do_delete_edit_report {
    my ($self, $report_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE ".
            "FROM edit_report ".
        "WHERE fs_id = ? ";

    $self->_set_values($query, $report_ref->{'fs_id'});
}

sub do_delete_region_evaluation {
    my ($self, $labinfo_ref) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE ".
            "FROM region_evaluation ".
        "WHERE fs_id = ? ";

    $self->_set_values($query, $labinfo_ref->{'fs_id'});
}

sub do_delete_hmm_inter_link {
    my ($self, $hmm_acc, $rel_acc, $rel_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE FROM egad..hmm_inter_link ".
            "WHERE hmm_acc = ? ".
        "AND rel_acc = ? ".
        "AND rel_type = ? ";

    $self->_set_values($query, $hmm_acc, $rel_acc, $rel_type);
}

sub do_delete_role_notes {
    my ($self, $role_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $db = "common" if !($db);

    my $query = "DELETE ".
            "FROM $db..role_notes ".
        "WHERE role_id = ? ";

    $self->_set_values($query, $role_id);
}

sub do_delete_ontology_link {
    my ($self, $child_id, $link_type) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "DELETE common..go_link ".
            "WHERE child_id = ? ".
        "AND link_type = ? ";

    $self->_set_values($query, $child_id, $link_type);
}

##########################
#^ END DELETE FUNCTIONS ^#
##################################################################



###################################

1;
