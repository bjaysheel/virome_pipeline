package Coati::MysqlHelper;

use strict;
use DBI;

#################################

sub connect {
    my ($self, @args) = @_;

    my $logger = $self->{_logger};

    $logger->debug("Running mysql connect") if($logger->is_debug);
    
    my(@vendors) = DBI->available_drivers(1);
    if(! (join('',@vendors) =~ /mysql/)){
	$logger->logdie ("Drivers for Mysql not found%%Perl Configuration%%The DBD::Mysql drivers are not installed.  Check the conf/Manatee.conf file to set the correct database vendor type%%%%Available drivers ",join(',',@vendors));
    }

    my $user = $self->{_user};
    my $password = $self->{_password};
    my $db = $self->{_db};
    my $hostname = $self->{_server};
    
    my $connect_string = "DBI:mysql:database=$db:hostname=$hostname";
    $logger->debug("$connect_string\n\t\tUSER - $user\n" .
		   "\t\tPASSWORD - $password\n" .
		   "\t\tDB - $db\n".
		   "\t\tHOSTNAME - $hostname\n"
		   ) if($logger->is_debug);
    
    
    my $dbh = DBI->connect($connect_string, $user, $password,
                                 { PrintError => 0,
                                   RaiseError => 0
                                 }
			   );
    if(! $dbh){
	$logger->logdie("Invalid username/password/db access %%Database login%%The database server [$hostname] denied access to the username [$user].  Please check the username/password and confirm you have permissions to access the [$db] database%%$DBI::errstr%%$db\n");
    }
    return $dbh;
}

sub modify_query_for_db {
  my ($self, $query) = @_;

  # quote reserved column names
  $query =~ s/i\.ec\#/i.\`ec\#\`/;

  $query =~ s/\.\./\./g;
  $query =~ s/convert\s*\(\s*\w+,/\(/ig;
  
  #
  # Below is an example of a convert that will be substituted out 
  # with the next statement:
  # e.g for below: convert(numeric(9,0),e.accession) = a.align_id
  $query =~ s/convert\s*\(\s*\w+\(\d,\d\),/\(/ig;
  $query =~ s/datalength/LENGTH/ig;
  $query =~ s/getdate\(\)/now\(\)/g;
  return $query;
}

sub commit {
    my $self = shift;
}

#################################

1;

