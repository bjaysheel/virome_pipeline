#!/usr/bin/perl -w

=head1 NAME
updateQualityFile.pl

=head1 SYNOPSIS
USAGE: updateQualityFile.pl
                --fasta=/path/to/fasta.fsa
                --quality=/path/to/quality_file.qual

=head1 OPTIONS
B<--input, -f>
    The full path to fasta sequence file.

B<--input, -q>
    The full path to the associated quality file.

B<--debug,-d>
    Debug level.  Use a large number to turn on verbose debugging.

B<--log,-l>
    Log file

B<--help,-h>
    This help message

=head1  DESCRIPTION
    Script is designed to look at the sequence file and pull out only those
    relavent quality scores. This is necessary as the FASTA file is passed thru
    QC compoennts that will throw out certain sequences.

=head1  INPUT
    The input to this is defined using the --fasta/-f AND --quality/-q flags.
    These should point to the files contianing the fasta and quality files, respectively.

=head1  CONTACT
    Daniel J. Nasko
    dan.nasko@gmail.com

=cut

use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;

##==================== USER VARIABLES ====================##
my %options = ();
my $results = GetOptions (\%options,
                        'fasta|f=s',
                        'quality|q=s',
			'outdir|o=s',
			'prefix|p=s',
                        'help|h') || pod2usage();

##=================== GLOBAL VARIABLES ===================##
my @SEQUENCES;
my %QUALITY;
my $outfile = $options{outdir}."/".$options{prefix}.".updated.qual";
my $fasta_count = 0;
my $quality_count = 0;

##========================================================##
##                         MAIN                           ##
##========================================================##
#open (IN,"<$options{quality}");
#my $quality_file = <IN>;
#close(IN);
#open (IN,"<$options{fasta}");
#my $fasta_file = <IN>;
#close(IN);
my $quality_file = $options{quality};
my $fasta_file = $options{fasta};

&QUALITYread($quality_file);

open(FASTA, "<$fasta_file") || die "\n\nCannot find (or perhaps read) $fasta_file\n\n";
$/='>';    # input break character
my @FASTin = <FASTA>;
close(IN);
shift(@FASTin);     
foreach my $fasta (@FASTin) {
    my @d = split('\n',$fasta);
    push (@SEQUENCES,$d[0]);
    $fasta_count += 1;
}
close(FASTA);

open (OUT,">$outfile");
foreach my $seq (@SEQUENCES) {
	if (exists $QUALITY{$seq}) {
		print OUT ">$seq\n$QUALITY{$seq}\n";
		$quality_count ++;
    	}
	$fasta_count ++;
}


if ($fasta_count != $quality_count) {
    print "\nERROR!\n\tNumber of sequences in fasta file = $fasta_count while\n\tNumber of sequences extracted from quality file = $quality_count\n\n";
}

close(OUT);



##========================================================##
##                      SUBROUTINES                       ##
##========================================================##
sub QUALITYread
{	my $in = $_[0];
	open(IN,"<$in") || die "\n\nCannot find (or perhaps read) $quality_file\n\n";
	$/='>';    # input break character
	my @FASTin = <IN>;
	close(IN);
	shift(@FASTin);     
	foreach my $fasta (@FASTin)  
	{	my @d = split('\n',$fasta);
		my $head = $d[0];
		my $seq = '';	
		foreach my $i (1..$#d)
		{	$seq = $seq." ". $d[$i]; }
		$seq =~ s/>//;
		$QUALITY{$head} = $seq;
	}
	$/='\n';
}
##========================== EOF =========================##
