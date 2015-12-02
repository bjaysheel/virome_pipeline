#!/usr/bin/perl

=head1 NAME

rRNA-scrub.pl - remove rRNA sequences identified by blast from the input FASTA.

=head1 SYNOPSIS

USAGE: rRNA-scrub.pl
            --fasta_file_base=fasta file base name
            --fasta_file_path=/path/to/fasta_file
            --fasta_file_extension=fasta file extension
            --btab=/path/to/input_file.btab
            --outputA=/path/to/rRNA_minus_original.fasta
            --outputB=/path/to/rRNA_identified_sequences.fasta
          [ --log=/path/to/logfile
            --debug=N
          ]

=head1 OPTIONS

B<--fasta_file_base, -n>
    The base name of fasta file.

B<--fasta_file_path, -b>
    The full path to fasta file.

B<--fasta_file_extension, -e>
    The file extension

B<--btab,-b>
    The input btab blast output from the ncbi-blastn suite.

B<--outputA,-oA>
    The file to which all sequence except for rRNA identified sequence will be written.

B<--outputB, -oB>
    The file to which all rRNA identified sequences will be written

B<--debug,-d>
    Debug level.  Use a large number to turn on verbose debugging.

B<--log,-l>
    Log file

B<--help,-h>
    This help message

=head1  DESCRIPTION

This script is used to scrub rRNA identified sequences from ncbi-blast suite, and create
a new fasta file.

=head1  INPUT

The input to this is defined using the --fasta_file_base, --fasta_file_extension
--fasta_file_path and -btab option.  This should point
to the btab ncbi-blast output and original fasta file information.

=head1  OUTPUT

The output is defined using the --outputA and -outputB option.  These files created
are fasta files of original fasta minus the rRNA sequences, and fasta file of
rRNA identified sequences.

=head1  CONTACT

    Jaysheel D. Bhavsar
    bjaysheel@gmail.com

=cut

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
BEGIN {
  use Ergatis::Logger;
}

my %options = ();
my $results = GetOptions (\%options,
                          'fasta_file_base|n=s',
                          'btab_file_list|b=s',
                          'fasta_file_path|p=s',
                          'fasta_file_extension|e=s',
                          'outputA|oA=s',
                          'outputB|oB=s',
                          'tmp_dir|td=s',
                          'log|l=s',
                          'debug|d=s',
                          'help|h') || pod2usage();

my $logfile = $options{'log'} || Ergatis::Logger::get_default_logfilename();
my $logger = new Ergatis::Logger('LOG_FILE'=>$logfile,
                                  'LOG_LEVEL'=>$options{'debug'});
$logger = $logger->get_logger();

## display documentation
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

## make sure everything passed was peachy
&check_parameters(\%options);

my %ident = ();
my $rRNA_positive = "";

##get blast output btab file to look in.
my $btab_blast_result = `grep "$options{fasta_file_base}\\." $options{btab_file_list}`;
chomp($btab_blast_result);
$btab_blast_result =~ s/ $//;

#open blast btab result file
open (DAT, "<", $btab_blast_result) || die $logger->logdie("Could not open file $btab_blast_result");

#loop through results of blast
while (<DAT>){
    chomp $_;

    # store tab delimited values into an array
    # btab file is from clean_expand btab.
    my @result = split(/\t/, $_);

    # seq are rRNA positive only if (b.qry_end - b.qry_start) >= 150)
    # AND ((b.qry_start<=20) OR (b.qry_end >= (b.query_length-20)))
    if ( $result[6]-$result[5] >= 150 && ( $result[5] <= 20 || ($result[6] >= ($result[1]-20)) ) ){

      #get rRNA identified sequence.
      $ident{$result[0]} = 1;
      #push @ident, $result[0];

      #$ident .= `sed -n -r '/\($result[0]\$\)|\($result[0]\ +\)|\($result[0]\t\)/p' $options{outputA}`;
      #$ident .= `sed -n -r '0,/\($result[0]\$\)|\($result[0]\ +\)|\($result[0]\t\)/!{/>/,/\($result[0]\$\)|\($result[0]\ +\)|\($result[0]\t\)/!p;}' $options{outputA}`;

      $rRNA_positive .= $_ ."\n";

      #remove rRNA idendified sequence from fasta.
      #system `sed -r '0,/\($result[0]\$\)|\($result[0]\ +\)|\($result[0]\t\)/!{/>/,/\($result[0]\$\)|\($result[0]\ +\)|\($result[0]\t\)/!d;}' $options{outputA} | sed -r '/\($result[0]\$\)|\($result[0]\ +\)|\($result[0]\t\)/d' > $temp`;
      #system `mv $temp $options{outputA}`;
    }
}
close DAT;

open(rPOS, ">", $options{outputB}) || die $logger->logdie("Could not open file $options{outputB}");
open(rNEG, ">", $options{outputA}) || die $logger->logdie("Could not open file $options{outputA}");

# my $idx = -1;
# my $flag = 0;
# my $seq = '';

use Bio::SeqIO;
my $seq_in  = Bio::SeqIO->new(
    -format => 'fasta',
    -file   => $options{fasta_file_path} );
while( my $seq = $seq_in->next_seq() ) {
    my $header = $seq->id;
    my $sequence = $seq->seq;
    if (exists $ident{$header}) {
	print rPOS ">" . $header . "\n";
	print rPOS $sequence . "\n";
	delete $ident{$header};
    }
    else {
	print rNEG ">" . $header . "\n";
	print rNEG $sequence . "\n";
    }
}
close rPOS;
close rNEG;

# open btab_blast_result to overwrite it with rRNA positive results.
open(OUT, ">", $btab_blast_result) || die $logger->logdie("Could not open file $btab_blast_result");
print OUT $rRNA_positive;
close OUT;


if (scalar keys %ident > 0) {
    foreach my $k (keys %ident) {
	my $total_missing = scalar keys %ident;
        print STDERR "Sequence $k missing from input fasta file: There are a total of $total_missing missing\n\n";
    }
    die "\nError: It appears that I didn't scrub all rRNA identifed sequences\n";
}

exit(0);

############################################################################
sub check_parameters {

    ## at least one input type is required
    unless ( $options{btab_file_list} ||
             $options{fasta_file_base} ||
             $options{fasta_file_path} ) {

        print STDERR "no input defined, please read perldoc $0\n\n";
		$logger->logdie("No input defined, plesae read perldoc $0\n\n");
        exit(1);
    }

    if(0){
        pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
    }
}
