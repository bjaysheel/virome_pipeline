package Coati::Coati::BulkChadoCoatiDB;

# $Id: BulkChadoCoatiDB.pm,v 1.1 2006-10-19 20:30:27 sundaram Exp $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME

BulkChadoCoatiDB.pm - One line summary of purpose of class (or file).

=head1 VERSION

This document refers to version N.NN of BulkChadoCoatiDB.pm, released MMMM, DD, YYYY.

=head1 SYNOPSIS

Short examples of code that illustrate the use of the class (if this file is a class).

=head1 DESCRIPTION

=head2 Overview

An overview of the purpose of the file.

=head2 Constructor and initialization.

if applicable, otherwise delete this and parent head2 line.

=head2 Class and object methods

if applicable, otherwise delete this and parent head2 line.

=cut


use strict;
use base qw(Coati::Coati::ChadoCoatiDB Coati::BulkHelper);

sub test_BulkChadoCoatiDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_ChadoCoatiDB();
}

sub testDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return  $self->test_BulkChadoCoatiDB();
}

1;

__END__

=head1 ENVIRONMENT

List of environment variables and other O/S related information
on which this file relies.

=head1 DIAGNOSTICS

=over 4

=item "Error message that may appear."

Explanation of error message.

=item "Another message that may appear."

Explanation of another error message.

=back

=head1 BUGS

Description of known bugs (and any workarounds). Usually also includes an
invitation to send the author bug reports.

=head1 SEE ALSO

List of any files or other Perl modules needed by the file or class and a
brief description why.

=head1 AUTHOR(S)

 The Institute for Genomic Research
 9712 Medical Center Drive
 Rockville, MD 20850

=head1 COPYRIGHT

Copyright (c) 2002, The Institute for Genomic Research. All Rights Reserved.

