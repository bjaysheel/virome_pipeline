package Coati::Test::Mysql;

# $Id: Mysql.pm,v 1.6 2003-12-01 23:16:37 angiuoli Exp $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME

Mysql.pm - A module for providing Mysql table extraction & loading to Coati::Test.

=head1 VERSION

This document refers to version 1.00 of Mysql.pm, released MMMM, DD, YYYY.

=head1 SYNOPSIS

use Coati::Test::Mysql;
$obj = Coati::Test::Mysql->new($self)

($self is a Coat::Test object).

=head1 DESCRIPTION

This module provides methods to the Coati test system for operating on
Mysql databases. When a test is encountered that modifies a database
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
$VERSION = (qw$Revision: 1.6 $)[-1];


=item new($proj_obj)

B<Description:> This is the module constructor. For this module
to work properly it needs to have the $test Coat::Test object passed in
as the object produced requires access to many of the same attributes.

B<Parameters:> $proj_obj, a Coati::Test object.

B<Returns:> $self, a Coati::Test::Mysql object.

=cut

sub new {
    my ($class, $proj_obj) = @_;
    my $self = bless {}, ref($class) || $class;
    $self->_init($proj_obj);
    if ($self->{_debug} > 2) {
        require Data::Dumper;
        $Data::Dumper::Purity = 1;
        warn Data::Dumper->Dump([\$self], ['*self->{_mysql}']);
    }
    return $self;
}


=item $obj->_init($proj_obj)

B<Description:> A private method used to initialize the Coati::Test::Mysql
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

B<Description:> Connects to a Mysql server and returns a database handle.

B<Parameters:> 

B<Returns:> $dbh, DBI database handle.

=cut

sub _connect {
    my ($self, $database, @args) = @_;
    $self->_trace if $self->{_debug};
    my ($dbh, $dsn);

    my $server = $self->{_backends}->{Mysql};
    my $username = $self->{_testuser};
    my $password = $self->{_testpasswd};

    $dsn = "dbi:mysql:database=$database:hostname=$server";

    $dbh = DBI->connect("$dsn", $username, $password,
                           { PrintError => 1,
                             RaiseError => 1
                           }
                        )
           or warn "*** Warning: Cannot connect to Mysql on $server: $DBI::errstr\n";
    return $dbh;
}


=item $obj->_extract_table($dbmodstruct_ref)

B<Description:> Uses the mysqldump utility to dump the data
from a Mysql database table into a file in the Mysql devel
area in the project testing directory.

B<Parameters:> $dbmodstruct_ref, a reference to a datastructure containing
information on which database, and tables to process for that
particular test. %dbmodstruct is assembled in Coati::Test::_parse_dbmod_testfile.

B<Returns:> None.

=cut

sub _extract_table {
    my ($self, $dbmodstruct_ref) = @_;
    $self->_trace if $self->{_debug};

    my $database = $dbmodstruct_ref->{Mysql}->{database};
    my $server   = $self->{_backends}->{Mysql};
    my $username = $self->{_testuser};
    my $password = $self->{_testpasswd};

    my @tables = keys %{ $dbmodstruct_ref->{Mysql}->{tables} };
    foreach my $table (@tables) {
        my ($datafile) = @{ $dbmodstruct_ref->{Mysql}->{tables}->{$table} };
        $self->_trace(qq|Extracting "$table" to $datafile.|) if $self->{_debug};
        my $command = "$self->{_paths}->{mysqldump} -t -h $server -u $username --password=$password " .
                      "$database $table > $self->{_paths}->{devel}/Mysql/${datafile}"; 
        $command .= " 2>/dev/null" unless $self->{_debug};
        $self->_trace("$command") if $self->{_debug};
        system("$command");    
    }
}


=item $obj->_load_table($dbmodstructref)

B<Description:> Uses the mysqlimport utility to load data
from a file in the project testing repository into a Mysql
database table.

B<Parameters:> $dbmodstruct_ref, a reference to a datastructure containing
information on which database, and tables to process for that
particular test. %dbmodstruct is assembled in Coati::Test::_parse_dbmod_testfile.

B<Returns:> None.

=cut

sub _load_table {
    my ($self, $dbmodstruct_ref) = @_;
    $self->_trace if $self->{_debug};

    my $database = $dbmodstruct_ref->{Mysql}->{database};
    my $server = $self->{_backends}->{Mysql};
    my $username = $self->{_testuser}->{Mysql};
    my $password = $self->{_password}->{Mysql};

    my @tables = keys %{ $dbmodstruct_ref->{Mysql}->{tables} };
    foreach my $table (@tables) {
        my ($datafile) = @{ $dbmodstruct_ref->{Mysql}->{tables}->{$table} };
        $self->_trace(qq|Loading "$table" from $datafile.|) if $self->{_debug};
        # -d => Delete all data in table before inserting new data.
        # -f => Force. Do not exit if an error is encountered.
        # -r => If new data conflicts with an existing key, replace.
        # -s => Act silently.
        my $command = "$self->{_paths}->{'mysqlimport'} -d -f -r -s -L " .
                      "$database $self->{_paths}->{repository}/Mysql/${datafile} " .
                      "-h $server --user=$username --password=$password";
        self->_trace("$command") if $self->{_debug};
        system("$command");    
    }
}

1;

__END__

=back

=head1 ENVIRONMENT

This module does not use or set any environment variables.
The Coati::Logger module is inherited for debugging output.

=head1 DIAGNOSTICS

This module uses Coati::Logger for debuggin purposes. To view details
of the operation of this modules, $test should have a non-zero _debug
attribute when calling the constructor:

  $obj = Coati::Test::Mysql->new($test);

=head1 BUGS

No known bugs at this time. Please send the authors a description of
any bugs or anomalies encountered.

=head1 SEE ALSO

  Coati::Test
  Coati::Test::Html
  Coati::Test::Sybase
  Coati::Logger

=head1 AUTHOR(S)

 The Institute for Genomic Research
 9712 Medical Center Drive
 Rockville, MD 20850

=head1 COPYRIGHT

Copyright (c) 2002, The Institute for Genomic Research. All Rights Reserved.
