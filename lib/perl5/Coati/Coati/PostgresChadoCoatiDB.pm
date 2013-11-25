package Coati::Coati::PostgresChadoCoatiDB;

# $Id: PostgresChadoCoatiDB.pm,v 1.7 2007-02-23 20:09:41 tcreasy Exp $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME

PostgresChadoCoatiDB.pm - One line summary of purpose of class (or file).

=head1 VERSION

This document refers to version N.NN of PostgresChadoCoatiDB.pm, released MMMM, DD, YYYY.

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
use base qw(Coati::Coati::ChadoCoatiDB Coati::PostgresHelper);

sub test_PostgresChadoCoatiDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_ChadoCoatiDB();
}

sub testDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_PostgresChadoCoatiDB();
}

sub _connect {
    my ($self, $hostname, @args) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    Coati::PostgresHelper::connect($self);
}

sub do_set_textsize {
    my ($self, $size) = @_;
    return undef;
}

sub get_db_to_permissions {
    my ($self, $db) = @_;
    ### tcreasy - need to revist this.  Right now, there is no good way
    ### to check if a user can or cannot access a database.
    return 0;
    #return $self->_do_db_to_permissions($query);
}

sub get_role_id_to_categories {
    my($self, $id, $main) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;

	my $query = "SELECT d2.accession, d1.accession ".
                "FROM db db1, cvterm c, cvterm_dbxref cd1, db db2, cvterm_dbxref cd2, dbxref d2, ".
				"dbxref d1 ".
				"WHERE d1.db_id = db1.db_id ".
				"AND db1.name = 'TIGR_role' ".
				"AND d1.dbxref_id = cd1.dbxref_id ".
				"AND cd1.cvterm_id = c.cvterm_id ".
				"AND c.cvterm_id = cd2.cvterm_id ".
				"AND cd2.dbxref_id = d2.dbxref_id ".
				"AND d2.db_id = db2.db_id ".
				"AND db2.name = 'TIGR_roles_order' ".
				"ORDER BY d2.accession ";				

    return $self->_get_results_ref($query);
}

sub get_gene_id_to_roles {
    my ($self, $gene_id, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');

    my $query = "SELECT d.accession ".
            "FROM feature a, feature t, featureloc fl, feature_cvterm fc, cvterm_dbxref cd, ".
        "dbxref d, db db, cvterm c, cv cv, organism o ".
        "WHERE t.uniquename = '$gene_id' ".
        "AND t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = fc.feature_id ".
        "AND fc.cvterm_id = c.cvterm_id ".
        "AND c.cv_id = cv.cv_id ".
        "AND cv.name = 'TIGR_role' ".
        "AND c.cvterm_id = cd.cvterm_id ".
        "AND cd.dbxref_id = d.dbxref_id ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND t.organism_id = o.organism_id ".
        "AND o.common_name != 'not known' ".
        "AND d.db_id = db.db_id ".
        "AND db.name = 'TIGR_role' ";

    if($self->{_seq_id}) {
		$query .= "AND a.uniquename = '$self->{_seq_id}' ";
    }

    return $self->_get_results_ref($query);
}

sub get_db_to_roles {
    my($self, $db) = @_;

    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my @as_id = $self->get_cv_term('assembly');
    my @tr_id = $self->get_cv_term('transcript');

    my $query = "SELECT t.uniquename, d.accession ".
            "FROM feature a, feature t, feature_cvterm fc, cvterm_dbxref cd, db, ".
        "cvterm c, featureloc fl, organism o, dbxref d ".
        "WHERE t.feature_id = fl.feature_id ".
        "AND fl.srcfeature_id = a.feature_id ".
        "AND t.feature_id = fc.feature_id ".
        "AND fc.cvterm_id = c.cvterm_id ".
        "AND c.cvterm_id = cd.cvterm_id ".
        "AND cd.dbxref_id = d.dbxref_id ".
		"AND d.db_id = db.db_id ".
		"AND db.name = 'TIGR_role' ".
        "AND a.type_id = $as_id[0][0] ".
        "AND t.type_id = $tr_id[0][0] ".
        "AND t.organism_id = o.organism_id ".
		"AND o.common_name != 'not known' ";

    return $self->_get_results_ref($query);
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

