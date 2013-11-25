#!/usr/local/bin/perl
use strict;
use Annotation::Fasta::FastaFormatter;

my $seq = 'TGATCGACTGACTAGTCGATCGATCGATCGATCGATCGATCGATGCATGCATGCATCGATGCTACGATGCATCGATCGTTGTGACGAGACACTAGCTAGCTAGTAGTAGCTCGATTAGCATCGATCATCGTATATGTCGATCGATCGATCGATGCTACATCGATCGATGCATGC';

print "sequence '$seq'\n";

my $formattedSeq = Annotation::Fasta::FastaFormatter::formatSequence($seq);
if (!defined($formattedSeq)){
    die "Could not retrieve formatted sequence";
}

print "Formatted sequence:\n";
print $formattedSeq;

print "$0 execution completed\n";
exit(0);
