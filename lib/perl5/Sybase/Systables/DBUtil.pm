package Sybase::Systables::DBUtil;

=head1 NAME

Sybase::Systables::DBUtil.pm

=head1 VERSION

1.0

=head1 SYNOPSIS

use Sybase::Systables::DBUtil;

Sybase system tables:
http://download.sybase.com/pdfdocs/asg1250e/poster.pdf


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS


=over 4

=cut

use strict;
use Carp;
use Data::Dumper;
use DBI;

=item new()

B<Description:> Instantiate Sybase::Systables::DBUtil object

B<Parameters:> None

B<Returns:> reference to the Sybase::Systables::DBUtil object

=cut

sub new  {

    my $class = shift;

    my $self = {};

    bless $self, $class;

    return $self->_init(@_);

}

=item $self->_init(%args)

B<Description:> Typical Perl init() method

B<Parameters:> %args

B<Returns:> None

=cut

sub _init {

    my $self = shift;
    my (%args) = @_;

    foreach my $key (keys %args){
	$self->{"_$key"} = $args{$key};
    }

    $self->_connect();

    return $self;
}


sub _connect {

    my $self = shift;

    $self->_checkParameters();

    my $username = $self->{_username};
    my $password = $self->{_password};
    my $database = $self->{_database};
    my $server   = $self->{_server};

    my $connect_string = "DBI:Sybase:server=$server;database=$database;packetSize=8192";

    my $dbh = DBI->connect($connect_string, $username, $password,
			   { PrintError => 0,
			     RaiseError => 0
			 }
			   );
    
    if(!$dbh){
	confess ("Invalid username/password/db access %%Database login%%".
		 "The database server [$server] denied access to the ".
		 "username '$username'.   Please check the username/password ".
		 "and confirm you have permissions to access the database ".
		 "'$database' %%$DBI::errstr%%$database");
    }

    $self->{_dbh} = $dbh;
}

sub _checkParameters {

    my $self = shift;

    if (! (( exists $self->{_username}) && (defined($self->{_username})))){
	confess "username was not defined";
    }

    if (! (( exists $self->{_password}) && (defined($self->{_password})))){
	confess "password was not defined";
    }

    if (! (( exists $self->{_server}) && (defined($self->{_server})))){
	confess "server was not defined";
    }

    if (! (( exists $self->{_database}) && (defined($self->{_database})))){
	confess "database was not defined";
    }
}




=item DESTROY

B<Description:> BSML::Validation::Factory class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

    my $self = shift;

    $self->{_dbh}->disconnect();
}

sub getTableList {

    my $self = shift;
    my (%args) = @_;

    my $table;
    if (( exists $args{table}) && (defined($args{table}))){
	$table = $args{table};
    }

    my $query = "SELECT name ".
    "FROM sysobjects ".
    "WHERE type = 'U' ";

    my $records = $self->_getResultsRef($query);


    my $list=[];

    foreach my $record (@{$records}){
	push(@{$list}, $record->[0]);
    }

    return $list;
}

sub getIndexList {

    my $self = shift;
    my (%args) = @_;

    my $table;
    if (( exists $args{table}) && (defined($args{table}))){
	$table = $args{table};
    }

    my $query = "SELECT i.name ".
    "FROM sysobjects t, sysindexes i ".
    "WHERE t.type = 'U' ".
    "AND t.name = '$table' ".
    "AND t.id = i.id ";

    my $records = $self->_getResultsRef($query);

    my $list=[];

    foreach my $record (@{$records}){
	push(@{$list}, $record->[0]);
    }

    return $list;

}

sub getConstraintList {

    my $self = shift;
    my (%args) = @_;

    my $table;
    if (( exists $args{table}) && (defined($args{table}))){
	$table = $args{table};
    }

    my $query = "SELECT cs.name ".
    "FROM sysobjects t, sysconstraints c, sysobjects cs ".
    "WHERE t.type = 'U' ".
    "AND t.name = '$table' ".
    "AND t.id = c.tableid ".
    "AND c.constrid = cs.id ";

    my $records = $self->_getResultsRef($query);


    my $list=[];

    foreach my $record (@{$records}){
	push(@{$list}, $record->[0]);
    }

    return $list;
}


sub disconnect {

    my $self = shift;

    $self->{_dbh}->disconnect();
}

sub _getResultsRef {

    my $self = shift;
    my ($query, @args) = @_;

    if (!defined($query)){
	confess "query was not defined";
    }

    my $dbh = $self->{_dbh};

    my $sth = $dbh->prepare($query) || confess ("Invalid query statement%%SQL/Database%%There is an invalid query or ".
						"it does not match table/column names in the database.  Please check ".
						"the SQL syntax and database schema%%$DBI::errstr%%$self->{_database}%%$query%%@args%%");

    $sth->execute(@args) || confess ("Query execution error%%SQL/Database%%There is a query that could not be executed.  ".
				     "Please check the query syntax, arguments, and database schema".
				     "%%$DBI::errstr%%$self->{_database}%%$query%%@args%%");
    
    my $results = $sth->fetchall_arrayref();

    return $results;
}

1==1; ## End of module
