package Coati::Coati::PostgresEukCoatiDB;

# $Id: PostgresEukCoatiDB.pm,v 1.10 2003-12-01 23:16:36 angiuoli Exp $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME

PostgresEukCoatiDB.pm - One line summary of purpose of class (or file).

=head1 VERSION

This document refers to version N.NN of PostgresEukCoatiDB.pm, released MMMM, DD, YYYY.

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
use base qw(Coati::Coati::EukCoatiDB Coati::PostgresHelper);

sub test_PostgresEukCoatiDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_EukCoatiDB();
}

sub testDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_PostgresEukCoatiDB();
}

sub _connect {
    my ($self, $hostname, @args) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    Coati::PostgresHelper::connect($self);
}


=item $obj->get_asmbl_seq()

B<Description:> Retrieves the sequence for an assembly.

B<Parameters:> asmbl_id
asmbl_id - unique identifier for an assembly

B<Returns:> A string containing the sequence data

=cut

sub get_asmbl_seq {
    my ($self, $asmbl_id) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

    my $query = "SELECT sequence ".
                "FROM assembly ".
                "WHERE asmbl_id = ?";

    # NEEDS DBUSAGE

    my @results = $self->_get_results($query, $asmbl_id);
    return ($results[0][0]);
}

=item $obj->do_set_textsize($size) 

B<Description:>

B<Parameters:> 

    $size - 

B<Returns:>

    NONE

=cut

sub do_set_textsize {
    my ($self, $size) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
}

=item $obj->do_update_ident($feat_name, $identref) 

B<Description:> 

    Updates ident annotation associated with a feat_name

B<Parameters:> 

    $feat_name - identifier for the gene
    $ident_ref - 

B<Returns:>

    NONE

=cut

sub do_update_ident {
    my ($self, $feat_name, $identref) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @args;
    
    my $query = "UPDATE ident SET ".
	        "date = getdate(), save_history = 1 ";
    #########
    # Iterate thru the hash ref of ident fields to build the update
    # query to be executed on the ident table.  The @args array gets
    # populated with the data that should be inserted into each field
    # and is then passed to _get_results.
    #########
    foreach my $field (sort keys %$identref) {
	#########
	# If value = NULL, cannot use ? notation b/c the NULL will get 
	# inserted as a string.
	#########
	if (defined($identref->{$field}) && $identref->{$field} ne "NULL") {
	    $query .= ", $field = ? ";
	    push(@args, $identref->{$field});
	} 
	#########
	# Else if value = NULL, create query portion without ? notation
	#########
	elsif (defined($identref->{$field}) && $identref->{$field} eq "NULL") {
	    $query .= ", $field = $identref->{$field} ";
	}
    }
    $query .= "WHERE feat_name = ? ";
    push(@args, $feat_name);
    # <TIGR_DB_USE> TIGR Database Usage Comments
    # Type: Table Usage
    # Application: coati
    # Process: CoatiDB.pm
    # Sub-process: do_update_ident
    # 	Database: projects
    #    	 Tables: ident
    #    		 Fields: feat_name
    #    		 Fields: com_name
    #    		 Fields: gene_sym
    #                    Fields: ec#
    #    		 Fields: comment
    #    		 Fields: pub_comment
    #    		 Fields: assignby
    #    		 Fields: save_history
    #    		 Operations: W
    # </TIGR_DB_USE> End TIGR Database Usage Comment
    $self->_set_values($query, @args);
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

