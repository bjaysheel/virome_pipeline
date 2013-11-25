package Coati::Coati::OmniumCoatiDB;

# $Id: OmniumCoatiDB.pm,v 1.5 2003-12-01 23:16:36 angiuoli Exp $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME

OmniumCoatiDB.pm - Provides data retrieval methods for Omnium schemas to Coati
projects.

=head1 VERSION

This document refers to version N.NN of OmniumCoatiDB.pm, released MMMM, DD, YYYY.

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
use base qw(Coati::Coati::CoatiDB);

sub test_OmniumCoatiDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_CoatiDB();
}

sub testDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_OmniumCoatiDB();
}

=item $obj->get_feat_name_to_asmbl_info() 

B<Description:> Retrieves some assembly information associated with locus.

B<Parameters:> locus

B<Returns:> id,end5,end3,asmbl_id,is_public,chromo

=cut

sub get_feat_name_to_asmbl_info {
    my ($self, $locus) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT a.feat_id, a.end5, a.end3, a.asmbl_id,d.ispublic,-1 " .
                "FROM asm_feature a, db_data d " .
	        "WHERE a.locus = ? " .
		"AND a.db_data_id = d.id ";

    my @results = $self->_get_results($query, $locus);
    return @results;
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

