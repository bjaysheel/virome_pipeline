# DNATools
#
# $Author: kgalinsk $
# $Date: 2008-11-14 10:35:59 -0500 (Fri, 14 Nov 2008) $
# $Revision: 23931 $
# $HeadURL: http://isvn.tigr.org/ANNOTATION/DM_Scripts/lib/JCVI/DNATools.pm $

=head1 NAME

JCVI::DNATools - JCVI Basic DNA tools

=head1 SYNOPSES

    use JCVI::DNATools qw(:all);

    my $clean_ref = cleanDNA($seq_ref);
    my $seq_ref = randomDNA(100);
    my $rev_ref = reverse_complement($seq_ref);

=head1 DESCRIPTION

Provides a set of functions and predefined variables which
are handy when working with DNA.

=cut

package JCVI::DNATools;

use strict;
use warnings;

use version; our $VERSION = qv('0.1.8');

use Exporter 'import';

my $funcs = [
        qw(
          cleanDNA
          randomDNA
          reverse_complement
          rev_comp
          )
    ]; 

our %EXPORT_TAGS = (
    all => [
        qw(
          %degenerate_map

          $nucs
          @nucs
          $nuc_match
          $nuc_fail

          $degens
          @degens
          $degen_match
          $degen_fail
          ), @$funcs
          
    ],

    funcs => $funcs
);

our @EXPORT_OK = @{ $EXPORT_TAGS{all} };

=head1 VARIABLES

=head2 %degenerate_map

Hash of degenerate nucleotides. Each entry contains a
reference to an array of nucleotides that each degenerate
nucleotide stands for.

=cut

our %degenerate_map = (
    N => [ 'A', 'C', 'G', 'T' ],
    V => [ 'A', 'C', 'G' ],
    H => [ 'A', 'C', 'T' ],
    D => [ 'A', 'G', 'T' ],
    B => [ 'C', 'G', 'T' ],
    M => [ 'A', 'C' ],
    R => [ 'A', 'G' ],
    W => [ 'A', 'T' ],
    S => [ 'C', 'G' ],
    Y => [ 'C', 'T' ],
    K => [ 'G', 'T' ]
);

=head2 BASIC VARIABLES

Basic nucleotide variables that could be useful. $nucs is a
string containing all the nucleotides (including the
degenerate ones). $nuc_match and $nuc_fail are precompiled
regular expressions that can be used to match for/against
a nucleotide. $degen* is the same thing but with degenerates.

=cut

our $nucs      = 'ABCDGHKMNRSTUVWY';
our @nucs      = split //, $nucs;
our $nuc_match = qr/[$nucs]/i;
our $nuc_fail  = qr/[^$nucs]/i;

our $degens      = 'BDHKMNRSVWY';
our @degens      = split //, $degens;
our $degen_match = qr/[$degens]/i;
our $degen_fail  = qr/[^$degens]/i;

=head1 FUNCTIONS

=head2 cleanDNA

    my $clean_ref = cleanDNA($seq_ref);

Cleans the sequence for use. Strips out comments (lines starting with '>') and
whitespace, converts uracil to thymine, and capitalizes all characters.

Examples:

    my $clean_ref = cleanDNA($seq_ref);

    my $seq_ref = cleanDNA(\'actg');
    my $seq_ref = cleanDNA(\'act tag cta');
    my $seq_ref = cleanDNA(\'>some mRNA
                             acugauauagau
                             uauagacgaucc');

=cut

sub cleanDNA {
    my $seq_ref = shift;

    my $clean = uc $$seq_ref;
    $clean =~ s/^>.*//m;
    $clean =~ s/$nuc_fail+//g;
    $clean =~ tr/U/T/;

    return \$clean;
}

=head2 randomDNA

    my $seq_ref = randomDNA($length);

Generate random DNA for testing this module or your own
scripts. Default length is 100 nucleotides.

Example:

    my $seq_ref = randomDNA();
    my $seq_ref = randomDNA(600);

=cut

sub randomDNA {
    my $length = shift;
    $length = $length || 100;

    my $seq;
    $seq .= int rand 4 while ( $length-- > 0 );
    $seq =~ tr/0123/ACGT/;

    return \$seq;
}

=head2 reverse_complement

    my $reverse_ref = reverse_complement($seq_ref);

Finds the reverse complement of the sequence and handles
degenerate nucleotides.

Example:

    $reverse_ref = reverse_complement(\'act');

=cut

sub reverse_complement {
    my $seq_ref = shift;

    my $reverse = reverse $$seq_ref;
    $reverse =~ tr/acgtmrykvhdbnACGTMRYKVHDBN/tgcakyrmbdhvnTGCAKYRMBDHVN/;

    return \$reverse;
}

=head2 rev_comp

See reverse_complement.

=cut

*rev_comp = \&reverse_complement;

1;

=head1 AUTHOR

Kevin Galinsky, <kgalinsk@jcvi.org>

=cut
