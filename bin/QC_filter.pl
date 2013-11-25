#!/usr/bin/perl -w


eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
BEGIN{foreach (@INC) {s/\/usr\/local\/packages/\/local\/platform/}};

## Takes a fasta file and qual file as input, filters out low quality reads
## Author: Shulei Sun

# Updated by Jaysheel Bhavsar
# used as ergatis component

=head1 NAME
   QC_filter.pl 

=head1 SYNOPSIS

    USAGE: QC_filter.pl --fasta fasta-file --qual qual-file-list
		--cutoff cutoff-value --minlen min-length 
		--outdir output-dir
                
=head1 OPTIONS
   
B<--fasta, -f>
    
B<--qual, -q>

B<--cutoff, -c>

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
    QC_filter.pl --fasta fasta-file --qual qual-file 
		--cutoff cutoff-value --minlen min-length 
		--outdir output-dir

=cut

use strict;
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
                          'qual|q=s',
			  'cutoff|c=s',
			  'minlen|m=s',
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
my $cutoff_score = $options{cutoff};
my $minLength = $options{minlen};

my $in = Bio::SeqIO->new(-file => "$inFasta", -format => 'fasta');

my %seq_hash;
my $seq_num = 0;

while (my $seq = $in->next_seq()) {
    $seq_num ++;
    my $seq_ID = $seq->display_id;
    my $desc = $seq->desc;
    my $sequence = $seq->seq;
    $seq_hash{$seq_ID} = [$sequence, $desc];
}

my @suffixes = (".fsa",".fasta",".txt");
my $fileName = basename($inFasta,@suffixes);

#get relative quality file from qualitiy file list
#produced by sffinfo
my $inFile = `grep -m 1 "$fileName" $options{qual}`;

$fileName = $options{outdir}."/".$fileName;

my $Highscore = $fileName . ".filtered.fsa";
my $NotMatch_seq = $fileName . ".NotMatch.fsa";
my $NotMatch_qual = $fileName . ".NotMatch.qual";
my $Low_seq = $fileName . ".LowSeq.fsa";
my $Low_qual = $fileName . ".LowScore.qual";
my $No_score = $fileName . ".NoScore.qual";
my $No_seq = $fileName . ".NoSeq.fsa";
my $summary_file = $fileName . ".Summary.txt";


open (QualIN, "<$inFile") || die "can't open qual file $inFile $options{qual} $fileName";
open (OUTfas, ">$Highscore") || die "cannot open output file";
open (NoScore, ">$No_score") || die "cannot open output file";
open (NoSeq, ">$No_seq") || die "cannot open output file";
open (NotMatchScore, ">$NotMatch_qual") || die "cannot open output file";
open (NotMatchSeq, ">$NotMatch_seq") || die "cannot open output file";
open (LowSeq, ">$Low_seq") || die "cannot open output file";
open (LowQual, ">$Low_qual") || die "cannot open output file";
open (Summary, ">$summary_file") || die "cannot open output file";


my $Qline_num=0;
my $Qname="";
my $qual_des="";
my $seq_des = "";
my $Quality = "";
my @Quality = ();
my $Highquality_num=0;
my $Lowquality_num=0;
my $Notmatch_num=0;
my $Noseq_num=0;
my $Noscore_num=0;
my $totalbps = 0;

while (<QualIN>) {
	my $Qline = $_;
	chomp($Qline);

	if (($Qline =~ m/^>/) or eof) {

# rescue the last line
	if (eof) {
		$Quality .= ' ' . $Qline;
	}

		if (length($Qname) > 0) {
			$Quality =~ s/^\s+//;
      			$Quality =~ s/\s+$//;
     			@Quality = split(' ', $Quality);
			
			my $total = 0;
			foreach (@Quality) {
				$total = $total + $_;
			}
			my $avg_score = $total / ($#Quality + 1);

# check if sequence and qual match
			my $seq_str = $seq_hash{$Qname}[0];
			$seq_des = $seq_hash{$Qname}[1];



		if (defined($seq_str)) {
			if(length($seq_str) == ($#Quality+1))  {

				if ((length($seq_str) >= $minLength) && ($avg_score >= $cutoff_score)) {
				print OUTfas ">$Qname " . "$seq_des\n" . "$seq_str\n";
				$Highquality_num ++;
				$totalbps = $totalbps + length($seq_str);
				}
				else {

				print LowSeq ">$Qname " . "$seq_des\n" . "$seq_str\n";
				print LowQual ">$Qname $qual_des\n";
				
				foreach (@Quality) {
					print LowQual "$_" . " ";
				}
				print LowQual "\n";
				$ Lowquality_num ++;
				}
				
			
			} # close length matches

# print out the sequence and qual if the length doesn't match
			else {
				print NotMatchSeq ">$Qname " . "$seq_des\n" . "$seq_str\n";
				print NotMatchScore ">$Qname $qual_des\n";
				foreach (@Quality) {
					print NotMatchScore "$_" . " ";
				}
				print NotMatchScore "\n";
				$Notmatch_num ++;
			    } # close length doesn't match
				

			} # close the record found

# If there is no sequence record in the seq_hash, the print it out
		else {
			print NoSeq ">$Qname $qual_des\n";
			foreach (@Quality) {
			print NoSeq "$_" . " ";
			}
			print NoSeq "\n";
			$Noseq_num ++;
		} # close no record
# delete the sequence record from the hash table	
		
	delete $seq_hash{$Qname};
	} # close the print out process

# reset all the variables
			
#			$Qname="";
			$qual_des = "";
			$Quality = "";
			@Quality = ();

			
		$Qline_num++;
		my @pattern_list = split(' ', $Qline);
		$Qname = $pattern_list[0];
		for (my $i=1; $i<=$#pattern_list; $i++) {
			$qual_des = $qual_des . " " . $pattern_list[$i];
		}
		$Qname = substr($Qname, 1);

	}
	else {
		$Quality .= ' ' . $Qline;
	}
}

while ((my $key) = each(%seq_hash)){
	my $sequence = $seq_hash{$key}[0];
	my $description = $seq_hash{$key}[1];
     print NoScore ">$key " ."$description\n".$sequence."\n";
	$Noscore_num ++;
}

my $avg_length;
if ($Highquality_num == 0) {
    $avg_length = 0;
}
else {
    $avg_length = $totalbps/$Highquality_num;
    $avg_length = int($avg_length + 0.5);
}
print Summary "total number of reads:\t" . $seq_num . "\n";
print Summary "number of high quality reads:\t" . $Highquality_num . "\n";
print Summary "the average read length after filtering is:\t" . $avg_length . "\n";
print Summary "number of low quality reads:\t" . $Lowquality_num . "\n";
print Summary "number of length not match reads:\t" . $Notmatch_num . "\n";
print Summary "number of reads without quality reads:\t" . $Noscore_num . "\n";
print Summary "number of quality reads without sequence reads:\t" . $Noseq_num . "\n";

close Summary;
close QualIN;
close QualIN;
close OUTfas;
close NoScore;
close NoSeq;
close NotMatchScore;
close NotMatchSeq;
close LowSeq;
close LowQual;

###############################################################################
####  SUBS
###############################################################################
sub check_parameters {
    my $options = shift;

    ## make sure sample_file and output_dir were passed
    unless ($options{fasta} && $options{qual} && $options{cutoff} && $options{minlen} && $options{outdir}){
      pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
      exit(-1);
    }
}
