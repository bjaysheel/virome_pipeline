#!/usr/bin/perl

## Takes a fasta file and qual file as input, filters out low quality reads
## Author: Shulei Sun

# Updated by Jaysheel Bhavsar
# used as ergatis component

=head1 NAME
   fasta_size_filter.pl

=head1 SYNOPSIS

    USAGE: fasta_size_filter.pl --fasta fasta-file
		--minlen min-length
		--outdir output-dir

=head1 OPTIONS

B<--fasta, -f>

B<--minlen, -m>

B<--outdir, -o>

B<--help,-h>
   This help message

=head1  DESCRIPTION

=head1  INPUT

=head1  OUTPUT

=head1  CONTACT
  Jaysheel D. Bhavsar @ bjaysheel[at]gmail[dot]com


==head1 EXAMPLE
    fasta_size_filter.pl --fasta fasta-file
		--minlen min-length
		--outdir output-dir

=cut

use strict;
use warnings;
use File::Basename;
use Pod::Usage;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Bio::SeqIO;
BEGIN {
  use Ergatis::Logger;
}

my %options = ();
my $results = GetOptions (\%options,
                          'fasta|f=s',
			  'minlen|m=i',
			  'outdir|o=s',
                          'help|h') || pod2usage();

## display documentation
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

## make sure everything passed was peachy
&check_parameters(\%options);
#############################################################

my $inFasta = $options{fasta}; # get the file name, somehow
my $minLength = $options{minlen};
my $in;

if ( $inFasta =~ m/\.gz$/) {
    $in = Bio::SeqIO->new(-file => "gunzip -c $inFasta |", -format => 'fasta');
} else {
    $in = Bio::SeqIO->new(-file => "$inFasta", -format => 'fasta');
}

my %seq_hash;
my $seq_num = 0;
my $seq_pass = 0;

my @suffixes = (".fsa",".fasta",".fna",".txt");
my $fileName = basename($inFasta,@suffixes);

$fileName = $options{outdir}."/".$fileName;
my $Highscore = $fileName . ".filtered.fsa";
open (OUTfas, ">$Highscore") || die "cannot open output file";

while (my $seq = $in->next_seq()) {
    $seq_num ++;
    my $seq_ID = $seq->display_id;
    my $desc = $seq->desc;
    my $sequence = $seq->seq;

    if (length($sequence) >= $minLength) {
        $seq_pass++;
        print OUTfas ">$seq_ID\n$sequence\n";
    }
}
close(OUTfas);

my $percent_pass = sprintf ("%0.2f", (($seq_pass/$seq_num)*100));
print STDOUT "Total number of sequence processed: $seq_num\n";
print STDOUT "Number of sequence pass min lenght filter of $minLength: $seq_pass ($percent_pass%)\n";

exit(0);
###############################################################################
####  SUBS
###############################################################################
sub check_parameters {
    my $options = shift;

    ## make sure sample_file and output_dir were passed
    unless ($options{fasta} && $options{minlen} && $options{outdir}){
      pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
      exit(-1);
    }
}
