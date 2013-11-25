package Coati::SybaseHelper;
use strict;
use DBI;

sub connect {
    my ($self, @args) = @_;

    my $logger = $self->{_logger};

    $logger->debug("Running sybase connect") if($logger->is_debug);

    my(@vendors) = DBI->available_drivers(1);
    if(! (join('',@vendors) =~ /Sybase/)){
	$logger->logdie("Drivers for Sybase not found%%Perl Configuration%%The DBD::Sybase drivers are not installed.  Check the conf/Manatee.conf file to set the correct database vendor type%%Available drivers ",join(',',@vendors));
    } 

    my $user = $self->{_user};
    my $password = $self->{_password};
    my $db = $self->{_db};
    my $hostname = $self->{_server};

    $logger->debug("Checking/setting the SYBASE environment variable.") if($logger->is_debug);

    if($ENV{"SERVER_NAME"} =~ /pathema/){
    }
    else{
	$ENV{"SYBASE"} ||= "/usr/local/packages/sybase";
    }

    my $connect_string = "DBI:Sybase:server=$hostname;database=$db;packetSize=8192";
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
    
    if(!$dbh){
	$logger->logdie("Invalid username/password/db access %%Database login%%The database server [$hostname] denied access to the username [$user].   Please check the username/password and confirm you have permissions to access the [$db] database%%$DBI::errstr%%$db");
    }
    return $dbh;
}

sub modify_query_for_db {
    my ($self,$query) = @_;
    return $query;
}

sub commit {
    my $self = shift;
}

#################################

1;
