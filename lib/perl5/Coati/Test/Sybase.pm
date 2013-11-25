package Coati::Test::Sybase;

# $Id: Sybase.pm,v 1.7 2003-12-01 23:16:37 angiuoli Exp $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME

Sybase.pm - A module for providing Sybase table extraction & loading to Coati::Test.

=head1 VERSION

This document refers to version 1.00 of Sybase.pm, released MMMM, DD, YYYY.

=head1 SYNOPSIS

use DBI;
use Coati::Test::Sybase;
$obj = Coati::Test::Sybase->new($self)

($self is a Coat::Test object).

=head1 DESCRIPTION

This module provides methods to the Coati test system for operating on
Sybase databases. When a test is encountered that modifies a database
( through an insert, update or delete operation ), a way of restoring the
test database to its former state is required. Files containing the test
data are read and used to reload the database tables. Both Mysql and Sybase
have different ways and utilities of accomplishing this, hence, the two
test modules.

=head2 Overview

This module is intended to provide Coati::Test, with an easy to
use api for debugging. Methods for tracing execution and outputting debugging information
based upon a "debug" level will be provided.

=over 4

=cut


use strict;
use DBI;
use base qw(Coati::Logger);

use vars qw($VERSION);
$VERSION = (qw$Revision: 1.7 $)[-1];


=item new($proj_obj)

B<Description:> This is the module constructor. For this module
to work properly it needs to have the $test Coat::Test object passed in
as the object produced requires access to many of the same attributes.

B<Parameters:> $proj_obj, a Coati::Test object.

B<Returns:> $self, a Coati::Test::Sybase object.

=cut

sub new {
    my ($class, $proj_obj) = @_;
    my $self = bless {}, ref($class) || $class;
    $self->_init($proj_obj);
    if ($self->{_debug} > 2) {
        require Data::Dumper;
        $Data::Dumper::Purity = 1;
        warn Data::Dumper->Dump([\$self], ['*self->{_sybase}']);
    }
    return $self;
}


=item $obj->_init($proj_obj)

B<Description:> A private method used to initialize the Coati::Test::Sybase
object. Initialization is accomplished by duplicating the attributes of $proj_obj
into this object so that internal methods have access to the same
data.

B<Parameters:> $proj_obj, a Coati::Test object.

B<Returns:> $self, a Coati::Test::Mysql object.

=cut

sub _init {
    my ($self, $proj_obj) = @_;
    foreach my $key (keys %$proj_obj) {
        $self->{$key} = $proj_obj->{$key};
    }
}


=item $obj->_connect()

B<Description:> Connects to a Sybase server and returns a database handle.

B<Parameters:> 

B<Returns:> $dbh, DBI database handle.

=cut

sub _connect {
    my ($self, @args) = @_;
    $self->_trace if $self->{_debug};
    my ($dbh, $dsn);

    my $server = $self->{_backends}->{Sybase};
    my $username = $self->{_testuser};
    my $password = $self->{_testpasswd};

    $dsn = "dbi:Sybase:server=$server; packetSize=4096";
    $ENV{SYBASE} ||= "/usr/local/packages/sybase";

    $dbh = DBI->connect("$dsn", $username, $password,
                           { PrintError => 1,
                             RaiseError => 1
                           }
                        )
           or warn "*** Warning: Cannot connect to Sybase on $server: $DBI::errstr\n";

    return $dbh;
}


=item $obj->_extract_table($dbmodstruct_ref)

B<Description:> Uses the Sybase BCP utility to dump the data
from a Sybase database table into a file in the Sybase devel
area in the project testing directory.

B<Parameters:> $dbmodstruct_ref, a reference to a datastructure containing
information on which database, and tables to process for that
particular test. %dbmodstruct is assembled in Coati::Test::_parse_dbmod_testfile.

B<Returns:> None.

=cut

sub _extract_table {
    my ($self, $dbmodstruct_ref) = @_;
    $self->_trace if $self->{_debug};
    
    my $database = $dbmodstruct_ref->{Sybase}->{database};
    my $server   = $self->{_backends}->{Sybase};
    my $username = $self->{_testuser};
    my $password = $self->{_testpasswd};

    my @tables = keys %{ $dbmodstruct_ref->{Sybase}->{tables} };
    foreach my $table (@tables) {
        my ($datafile, $identity) = @{ $dbmodstruct_ref->{Sybase}->{tables}->{$table} };
        warn qq|Extracting "$table" to $datafile.\n| if $main::debug;
        my $command = "$self-{_paths}->{'bcp'} $database..$table out $self->{_paths}->{devel}/Sybase/${datafile} " .
                      "-S $server -U $username -P $password -c -b 1000";
        $command .= " 1>/dev/null" unless $self->{_debug}; 
        warn qq|Executing: "$command"\n| if $self->{_debug};
        system("$command");    
    }
}


=item $obj->_load_table($dbmodstructref)

B<Description:> Uses the Sybase BCP utility to load data
from a file in the project testing repository into a Sybase
database table.

B<Parameters:> $dbmodstruct_ref, a reference to a datastructure containing
information on which database, and tables to process for that
particular test. %dbmodstruct is assembled in Coati::Test::_parse_dbmod_testfile.

B<Returns:> None.

=cut

sub _load_table {
    my ($self, $dbmodstruct_ref) = @_;
    $self->_trace if $self->{_debug};

    my $database = $dbmodstruct_ref->{Sybase}->{database};
    my $server = $self->{_backends}->{Sybase};
    my @tables = keys %{ $dbmodstruct_ref->{Sybase}->{tables} };
    foreach my $table (@tables) {
        my ($datafile, $identity) = @{ $dbmodstruct_ref->{Sybase}->{tables}->{$table} };
        warn qq|Loading "$table" from $datafile.\n| if $main::debug;

        my $username = $self->{_testuser};
        my $password = $self->{_testpasswd};

        my $command = "$self->{_paths}->{'bcp'} $database..$table in $self->{_paths}->{repository}/Sybase/${datafile} " .
                      "-S $server -U $username -P $password -c -b 1000";
        # Check if identity is present. If so, then pass the -E flag to BCP for identity inserts.
        $command .= " -E" if ($identity eq "identity");
        $command .= " 1>/dev/null" unless $self->{_debug}; 
        warn qq|Executing: "$command".\n| if $self->{_debug};
        
        if ( system("$command") == 0 ) {
            $self->_trace("BCP load succeeded.") if $self->{_debug};
        } else {
            $self->_trace("*** WARNING: BCP load failed.");
        }
    }
}

1;

__END__

=back

=head1 ENVIRONMENT

This module does not use or set any environment variables. The standard
module, File::Basename is required.

=head1 DIAGNOSTICS

=over 4

=item "*** WARNING: BCP load failed."

They Sybase utility BCP was unable to load data in a Sybase
database from a flat file. This could indicate a database
server error, or unavailability. In addition, the file containing
the data to be loaded may be in an improper format.

=back

=head1 BUGS

No known bugs at this time. Please report bugs and/or anomalies to the authors.

=head1 SEE ALSO

  Coati::Logger
  Coati::Test
  Coati::Test::Mysql
  Data::Dumper

=head1 AUTHOR(S)

 The Institute for Genomic Research
 9712 Medical Center Drive
 Rockville, MD 20850

=head1 COPYRIGHT

Copyright (c) 2002, The Institute for Genomic Research. All Rights Reserved.
