# JCVI::Translator::Table
#
# $Author: kgalinsk $
# $Date: 2009-04-23 15:41:12 -0400 (Thu, 23 Apr 2009) $
# $Revision: 26160 $
# $HeadURL: http://isvn.tigr.org/ANNOTATION/bioinformatics-engineers/kgalinsk/JCVI-Translator/tags/0.5.6/lib/JCVI/Translator/Base.pm $

=head1 NAME

JCVI::Translator::Base - Contains translation methods for JCVI::Translator

=head1 SYNOPSIS

    my $base = new JCVI::Translator::Base;
    $base->set_seq($seq_ref);
    $base->set_partial($partial);
    $base->prepare($strand, $table);
    $base->endpoints($upper, $lower, $offset);
    my $pep_arrayref = $base->translate();

=head1 DESCRIPTION

This package contains the actual methods that do the translation.

=cut

package JCVI::Translator::Base;

use strict;
use warnings;

=head1 CONSTRUCTOR

=cut

=head2 new

=cut

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
}

=head1 METHODS

=cut

=head2 clear

Clear all stored variables

=cut

sub clear {
    my ($self) = @_;
    undef %$self;
}

=head2 set_seq

Cache the seq_ref to be translated

=cut

sub set_seq {
    my ( $self, $seq_ref ) = @_;
    $self->{seq_ref} = $seq_ref;
}

=head2 set_partial

Set the partial status

=cut

sub set_partial {
    my ( $self, $partial ) = @_;
    $self->{partial} = $partial;
}

=head2 prepare

Prepare things related to the strand. Set up the increment, the rc boolean
value (stands for reverse complement - false for + strand, true for - strand),
and the translation tables that are being used.

=cut

sub prepare {
    my ( $self, $strand, $table ) = @_;
    
    # This is a good a place as any to clear the leftover - see below for more
    # info
    $self->{leftover} = '';

    $self->{strand}    = $strand;

    $self->{increment} = 3 * $strand;

    my $rc = $strand == 1 ? 0 : 1;
    $self->{rc}        = $rc;

    # The translation tables are keyed on $rc in JCVI::Translator::Table
    $self->{table}  = $table->_forward->[$rc];
    $self->{starts} = $table->_starts->[$rc];
}

=head2 endpoints

Set the endpoints for looping up. The translate method loops until the index is
equal to the stop endpoint. For this to work, the stop must be in the same
frame as the start. For the + strand, adjust the upper bound so that it is in
phase with lower bound and offset.

The - strand is trickier. Not only adjust is the lower bound adjusted to be in
phase with the lower bound and offset, but 3 is also subtracted from the
bounds so that the right index for substring is present. Codons are indexed on
their lower bound, so 3 is subtracted to get from the upper end to the lower.

Below is an example that might make sense of this. Suppose we are interested in
translating the sequence "CAGTTTAACAAGTCGAAACCGTTC" between positions 4 and 20:

    Positions:             0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4
    Sequence                C A G T T T A A C A A G T C G A A A C C G T T C
    Region of interest (-): . . . .4- - - - - - - - - - - - - - - -20 . . .
    For + strand:                  4- - -|- - -|- - -|- - -|- - >19
    For - strand:              2. . .|< - -|- - -|- - -|- - -17 - -|

For the + strand, endpoints will set the start to 4, and the stop to 19. This
grab the codon starting at base 4, 7, 10, 13 and 16 (at base 19, the index will
equal the stop, and the loop will terminate). Thus, we'll have the codons TTA,
ACA, AGT, CGA and AAC.

For a - strand, start is 17 and stop is 2. This will get the codons starting at
17 (which ends at base 20), 14, 11, 8 and 5. It will not take the codon
starting at base 2, which is out of the specified bounds, because at that
point, the index will equal the stop and the loop will exit.

=cut

sub endpoints {
    my ( $self, $lower, $upper, $offset ) = @_;

    # If offset isn't provided, designate the offset by how much is required to
    # complete the leftover codon.
    $offset = 3 - length( $self->{leftover} ) unless ( defined $offset );

    $self->{lower} = $lower;
    $self->{upper} = $upper;

    # Calculate the phase difference between the upper and lower adjusting for
    # offset. This will be the same as the number of bases left over after
    # translation.
    my $phase = ( $upper - $lower - $offset ) % 3;
    $self->{phase} = $phase;

    # Here is where the endpoints are actually set up.
    if ( $self->{rc} ) {
        # Set the start by adjusting for offset and subtract 3 as explained
        # above
        $self->{start} = $upper - $offset - 3;
        $self->{stop}  = $lower - 3 + $phase;
    }
    else {
        # Just adjust for stop and phase.
        $self->{start} = $lower + $offset;
        $self->{stop}  = $upper - $phase;
    }
}

=head2 translate

Perform the actual translation. Try to translate the start codon if partial
isn't set, and then do the translation. Return the results as an arrayref.

=cut

sub translate {
    my ($self) = @_;

    my @residues;

    # Try to translate the start codon
    push @residues, $self->start() unless ( $self->{partial} );

    my $seq_ref = $self->{seq_ref};
    my $index   = $self->{start};

    # Iterate until the index is the end of the loop
    until ( $index == $self->{stop} ) {

        # Grab the codon, and look it up in the translation table
        my $codon = substr( $$seq_ref, $index, 3 );
        push @residues, $self->{table}->{$codon} || 'X';
        
        # Increment the index
        $index += $self->{increment};
    }

    return \@residues;
}

=head2 start

Translate the start codon if possible

=cut

sub start {
    my ($self) = @_;

    # If start == stop, don't do anything
    return () if ( $self->{start} == $self->{stop} );

    my $seq_ref = $self->{seq_ref};
    
    # Grab the codon and look it up in the starts table.
    my $codon   = substr( $$seq_ref, $self->{start}, 3 );
    my $start   = $self->{starts}->{$codon};

    # Return the empty string if start isn't found in the translation table
    return () unless ($start);

    # Increment the start location and return the start codon
    $self->{start} += $self->{increment};
    return $start;
}

=head2 store_leftover

Store the leftover bases from translation. These are codons that have been cut
by splice sites.

=cut

sub store_leftover {
    my ($self) = @_;

    my $seq_ref = $self->{seq_ref};

    if ( $self->{rc} ) {
        # For the - strand, the leftover starts from the lower bound
        $self->{leftover} = substr( $$seq_ref, $self->{lower}, $self->{phase} );
    }
    else {
        # For the + strand, the leftover ends at the upper bound and starts
        # where translation finished.
        $self->{leftover} = substr( $$seq_ref, $self->{stop}, $self->{phase} );
    }
}

=head2 finish_leftover

Extend the leftover to completion in the current codon, if possible.

=cut

sub finish_leftover {
    my ($self) = @_;

    # Calculate how many bases are required to finish the codon
    my $to_go = 3 - length( $self->{leftover} );
    
    # If the current exon is shorter than that number, adjust so that leftover
    # codon doesn't run into the intron
    if ( ( my $length = $self->{upper} - $self->{lower} ) < $to_go ) {
        $to_go = $length;
    }

    my $seq_ref = $self->{seq_ref};

    if ( $self->{rc} ) {
        # On the - strand, prefix the leftover
        $self->{leftover} =
          substr( $$seq_ref, $self->{upper} - $to_go, $to_go )
          . $self->{leftover};
    }
    else {
        # On the + srand, append to the leftover
        $self->{leftover} .= substr( $$seq_ref, $self->{lower}, $to_go );
    }

    return length( $self->{leftover} ) == 3;
}

=head2 translate_leftover

Translate the leftover codon. If partial isn't set, translate and then set the
partial flag.

=cut

sub translate_leftover {
    my ($self) = @_;

    my $leftover = $self->{leftover};

    # If this is partial, then translate the leftover normally
    return $self->{table}->{$leftover} if ( $self->{partial} );

    # Try to translate the start, but mark partial as 1 so that it doesn't try
    # to translate the start again 
    $self->{partial} = 1;
    return $self->{starts}->{$leftover} || $self->{table}->{$leftover};
}

1;

=head1 AUTHOR

Kevin Galinsky, <kgalinsk@jcvi.org>

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 J. Craig Venter Institute, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut