package IGS::MysqlUIDGenerator;

=head1 NAME

IGS::MysqlUIDGenerator -- A module for creating unique ID's.

=head1 SYNOPSIS

  use IGS::MysqlUIDGenerator;

  my $uid_obj = IGS::MysqlUIDGenerator->new();
  my $new_id = $uid_obj->get_next_id();
	
=head1 DESCRIPTION

This module provides a unique numeric identifier at IGS. The IDs are sequential.

=head1 METHODS

=over

=cut

use strict;
use warnings;
use File::Basename;
use FindBin qw($Bin);
use Config::IniFiles;
use DBI;
use Log::Log4perl qw(:easy);
use fields qw( batch_size current_id );
			 
# Defined version variables.
our $REVISION = (qw$Revision:1.0 $)[-1];
our $VERSION = '1.0';
our $VERSION_STRING = "$VERSION (Build $REVISION)";

####################################################
##             GLOBAL/CONSTANT VARS               ##
####################################################
my $MAX_NUM_RETRIES = 6;
my @stored_ids = ();
my ($db_name, $username, $password, $host);

=item $uid_obj = IGS::MysqlUIDGenerator->new($batch_size);

This method is used for instantiation of a new MysqlUIDGenerator. It returns
the object handle. It takes an optional parameter batch_size.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class || ref($class);
    $self->_init(@_);
    return $self;
}

sub _init {
    my ($self, $batch_size) = @_;
	
    # We want to find where our idgenerator conf is
    my $cfg = $self->_get_config();  

    my $config_section = "mysql";
    my $logger_conf = $cfg->val($config_section, 'log4perlconf');
    Log::Log4perl->init_once($logger_conf) if ($logger_conf);

    $db_name = $cfg->val($config_section, 'db_name');
    $host = $cfg->val($config_section, 'host');
    $username = $cfg->val($config_section, 'username');
    $password = $cfg->val($config_section, 'password');

    if (! (_check_config($db_name) && _check_config($host) &&
          _check_config($username) && _check_config($password))) {
        warn "Bad configuration. You must have the following: db_name, host, username and password.\n";
        warn "These configuration parameters must also be inside a [mysql] section in INI format.\n";
        exit 1;
    }

    $self->{_logger} = Log::Log4perl->get_logger("MysqlUIDGenerator.pm");
    $self->{batch_size} = $batch_size ||= 1;
    $self->{current_id} = undef;
    $self->{dbh} = $self->_connect_to_db();
}

# Just a subroutine to check the validity of configuration parameters.
sub _check_config {
    my $config = shift;
    # Assume a bad config. Prove me wrong.
    my $valid = 0;
    if (defined $config && length($config) > 0) {
        $valid = 1;
    }
    return $valid;
}

# Shamlessly stolen from Victor's Grid::Request module :)
sub _get_config {
    my ($self) = @_;
    my $user_config = "$ENV{HOME}/.id_generator.ini";
    my $global_config = "/etc/id_generator.ini";
    my $config;
    
    if (-f $global_config && -r $global_config) {
        # The global config is available.
        $config = $global_config;
    }

    if (-f $user_config && -r $user_config) {
        # The user has overridden the global
        $config = $user_config;
    }

    if (! defined $config || length($config) == 0) {
        warn "No config file accessible at $user_config or $global_config.";
        exit 1;
    }

    my $cfg = Config::IniFiles->new(-file => $config);
    if (! defined $cfg) {
        warn "Config file $config could not be used.";
        exit 1;
    }

    return $cfg;
}

=item $uid = $uid_obj->get_next_id();

Return a new UID. The method will connect to the database and retrieve a batch of UIDs. 
Each call to this method returns a new UID from the batch.

=cut

sub get_next_id {
    my $self = shift;

    my $success = 0;
    my $id = 0;
    my $num_retries = 0;
    my $retry = 1;
    my $batch_size = $self->{batch_size};
    
    $self->{_logger}->debug("In get_next_id");

    do { 
        eval{
            $id = $self->_retrieve_next_id();
            $success = 1;
        }; 
        if ($@) {
            $self->{_logger}->error("Unable to retrieve an ID: $@");
            $success = 0;
        }
        
        if ($success) {
            $retry = 0;
        } else {
            my $delay = int( rand() * (4 ** $num_retries++));
            eval {
                    $self->{_logger}->warn("Sleeping for $delay.");
                    sleep($delay);
            };
            if ($@) {
                    $retry = 0;
                    $self->{_logger}->error("Could not delay ID query.");
            }
        }
    } while ($retry && $num_retries < $MAX_NUM_RETRIES);
    
    if ($id == 0) {
        $self->{_logger}->logdie("Unable to retrieve a valid ID.");
    }
    
    return $id;
}

# $uid = $uid_obj->_retrieve_next_id()
#
#This is a private method. It is not to be used by client code.
#Retrieves a new ID from the array containing IDs. If the array contains no IDs 
#we connect to the database and grab a fresh batch of IDs.

sub _retrieve_next_id {
    my $self = shift;

    $self->{_logger}->debug("In _retrieve_next_id.");
    
    if (scalar @stored_ids == 0) {
        $self->fill_cache();
    }
    
    $self->{current_id} = pop (@stored_ids);
    
    return $self->{current_id};
}

=item $uid_obj->fill_cache();

Retrieves a number of IDs, defined by $batch_size, from the database.

=cut

# TODO: Find a way to work in a connection check here and connect if we need to. Also add a disconnect.
sub fill_cache {
    my ($self) = shift;
    my $batch_size = $self->{batch_size};
    my $dbh = $self->get_dbh();
    
    $self->{_logger}->debug("In fill_cache");
    
    eval {
        if ( !($dbh->{Active}) ) {
            $dbh = _connect_to_db();
        }

        while (scalar @stored_ids < $batch_size) {
            my $id = $self->get_id_from_connection($dbh, $batch_size) ;
            push (@stored_ids, $id);
        }
        
        _disconnect_from_db($dbh);
    };
    if ($@) {
        $self->{_logger}->logdie("Problem querying the next ID from the Mysql server: $@");
    }
}

=item $uid_obj->get_id_from_connection()

Retrieves an ID from the Mysql server

=cut

sub get_id_from_connection {
    my ($self, $dbh, $batch_size) = @_;
    my $id;
    
    eval {
        my $sqle = "call get_next_id(\@id)";
        my $sqlq = "select \@id";
        
        $dbh->do($sqle);
        my $sth = $dbh->prepare($sqlq);
        $sth->execute();
        my $rows = $sth->fetchall_arrayref();
        $sth->finish();
        
        $id = $rows->[0]->[0];
    }; 
    if ($@) {
        $self->{_logger}->logdie("Problem querying the next ID from the Mysql server: $@");
    }
                    
    return $id;
}

=item $uid = $uid_obj->get_current_id();

Return the current UID. This method returns undef if no current UID available

=cut

sub get_current_id {
    my $self = shift;
    return $self->{current_id};
}

=item $uid = $uid_obj->get_dbh();

Return the database handle.

=cut

sub get_dbh {
    my $self = shift;
    return $self->{dbh};
}

sub get_batch_size() {
    my $self = shift;
    return $self->{batch_size};
}

=item $uid = $uid_obj->set_batch_size();

Set the batch size as the specified value

=cut

sub set_batch_size {
    my $self = shift;
    my $size = shift;
    $self->{batch_size} = $size;
}


sub _connect_to_db {
    my ($self) = shift;
    my $dbh = DBI->connect( "dbi:mysql:database=$db_name;host=$host", $username, $password,
                            { RaiseError => 1 } );
    return $dbh;
}

sub _disconnect_from_db {
    my $dbh = shift;
    $dbh->disconnect();
}

1;

__END__

=back 

=head1 USAGE

The following example demonstrates how to use IGS::MysqlUIDGenerator

#!/usr/bin/perl

use IGS::MysqlUIDGenerator;

my $uid_obj = new IGS::MysqlUIDGenerator(2);
my @list = qw( apple   orange );

foreach my $item (@list) {
	my $uid = $uid_obj->getNextID();
	print "Item \'$item\' gets ID \'$uid\' . \n";
}

exit 0;

=head1 AUTHOR(S)

Cesar Arze

Victor Felix

=cut
