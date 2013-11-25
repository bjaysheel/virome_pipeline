package Coati::TermUsage;

# $Id: TermUsage.pm,v 1.9 2006-10-27 19:49:15 sundaram Exp $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME
    
TermUsage.pm - A module to convert SO types to match TIGR internal usage
    
=head1 VERSION
    
This document refers to version 1.00 of TermUsage.pm, released MMMM, DD, YYYY.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head2 Overview

=over 4

=cut

use strict;
use Coati::Logger;

=item new

B<Description:> The module constructor.

B<Parameters:> %arg, a hash containing attribute-value pairs to
initialize the object with. Initialization actually occurs in the
private _init method.

B<Returns:> $self (A Coati::TermUsage object).

=cut


sub new {
    my $class = shift;
    my $self = bless {}, ref($class) || $class;
    $self->{_logger} = Coati::Logger::get_logger(__PACKAGE__);
    $self->{_logger}->debug("Init $class") if $self->{_logger}->is_debug;
    $self->_init(@_);

    return $self;
}

=item $obj->_init([%arg])

B<Description:> Tests the Perl syntax of script names passed to it. When
testing the syntax of the script, the correct directories are included in
in the search path by the use of Perl "-I" command line flag.

B<Parameters:> %arg, a hash containing attributes to initialize the testing
object with. Keys in %arg will create object attributes with the same name,
but with a prepended underscore.

B<Returns:> None.

=cut

sub _init {
    my $self = shift;
    my %arg = @_;
    foreach my $key (keys %arg) {
        $self->{_logger}->debug("Storing member variable $key as _$key=$arg{$key}") if $self->{_logger}->is_debug;
	$self->{"_$key"} = $arg{$key}
    }

    $self->{'_types'} = &_load_terms();
    
    
}


sub _load_terms {

    my $types = {};
    
    while (<DATA>) {
	if (/^\s*(.+?)\s+(.+)\s*$/) {
	    my $type1 = lc($1);
	    my $type2 = lc($2);

	    $types->{$type1} = $type2;
	}
    }
    
    return $types;
}


sub get_usage {

    my ($self, $qry) = @_;

    $qry = lc($qry);

    if (exists $self->{'_types'}->{$qry}) {
	return $self->{'_types'}->{$qry};
    } else {
	$self->{_logger}->warn("No usage defined for SO type '$qry'");
	return $qry;
    }
}

sub is_defined{
    my ($self, $qry) = @_;

    $qry = lc($qry);

    if (exists $self->{'_types'}->{$qry}) {
	return 1;
    }
    else{
	return 0;
    }
}

1;


__DATA__

canonical_five_prime_splice_site        splice_site
canonical_splice_site                   splice_site
canonical_three_prime_splice_site       splice_site
CDS                                     CDS
coding_exon                             exon
exon                                    exon
five_prime_UTR                          five_prime_UTR
gene                                    gene
intergenic_region                       intergenic_region
intron                                  intron
noncoding_exon                          exon
polyA_signal_sequence                   polyA_signal_sequence
primary_transcript                      transcript
promoter                                promoter
repeat_region                           repeat_region
signal_peptide                          signal_peptide
splice_site                             splice_site
start_codon                             start_codon
stop_codon                              stop_codon
tandem_repeat                           repeat_region
three_prime_UTR                         three_prime_UTR
transcript                              transcript
transcription_start_site                transcription_start_site
transcription_end_site                  transcription_end_site
transit_peptide                         transit_peptide
tRNA                                    tRNA
SNP					SNP
nucleotide_insertion			nucleotide_insertion
nucleotide_deletion			nucleotide_deletion
indel					indel
gap					gap
snoRNA                                  snoRNA
mRNA                                    transcript
contig                                  assembly
rRNA                                    rRNA
assembly                                assembly
polypeptide                             polypeptide
located_sequence_feature                located_sequence_feature
microsatellite                          microsatellite
mature_peptide                          polypeptide
misc_RNA                                ncRNA
protein                                 polypeptide
