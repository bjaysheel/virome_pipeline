# $Id: PrismDB.pm 1278 2004-07-06 17:27:51Z sundaram $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME

PrismDB.pm - One line summary of purpose of class (or file).

=head1 VERSION

This document refers to version 1.00 of PrismDB.pm, released MMMM, DD, YYYY.

=head1 SYNOPSIS

Short examples of code that illustrate the use of the class (if this file is a class).

=head1 DESCRIPTION

=head2 Overview

An overview of the purpose of the file.

=head2 Constructor and initialization.

if applicable, otherwise delete this and parent head2 line.

=head2 Class and object methods

if applicable, otherwise delete this and parent head2 line.

=over 4

=cut

package Prism::PrismDB;

use strict;
use Coati::Logger;
use vars qw($AUTOLOAD $VERSION);

$VERSION = (qw$Revision: 1278 $)[-1];


=item $obj->AUTOLOAD()

B<Description:> 

Retrieves

B<Parameters:> 

Parameters

B<Returns:> 

Returns

=cut

sub AUTOLOAD {
    # This is intended to inform the developer that the method he tried to
    # call is not implemented in the modules.
    my ($self, @args) = @_;
    die "Sorry, but $AUTOLOAD is not defined.\n";
}

=item $obj->DESTROY()

B<Description:> 

Retrieves

B<Parameters:> 

Parameters

B<Returns:> 

Returns

=cut

sub DESTROY {
    # This method intentionally left blank.
}

sub test_PrismDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return __PACKAGE__;
}

sub testProjDB {
    my ($self, @args) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_PrismDB();
}


1;

__END__

=back

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

