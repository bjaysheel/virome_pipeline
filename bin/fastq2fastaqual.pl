#!/usr/bin/perl -w
 
use Bio::Perl;
use Data::Dumper;
use strict;
use warnings;
use Getopt::Long;

#=====================Header======================
# Convert a fastq to a fasta/qual combo using BioPerl, with some Linux commands
# Usage: $0 -i inputFastqFile [-n numCpus -q outputQualfile -f outputFastaFile]
# Code adapted from:
# http://www.bioperl.org/wiki/Converting_FASTQ_to_FASTA_QUAL_files
# January 8, 2012 dnasko@udel.edu
#=================================================

my $settings={};
 
$|=1;
my %numSequences; # static for a subroutine
 
exit(main());
 
sub main{
  die("Usage: $0 -i inputFastqFile [-n numCpus -q outputQualfile -f outputFastaFile]") if(@ARGV<1);
 
  GetOptions($settings,('numCpus=s','input=s','qualOut=s','fastaOut=s'));
 
  my $file=$$settings{input}||die("input parameter missing");
  my $outfasta=$$settings{fastaOut}||"$file.fasta";
  my $outqual=$$settings{qualOut}||"$file.qual";
  my $numCpus=$$settings{numCpus}||1;
 
  convert($file,$outfasta,$outqual);
 
  return 0;
}
 
sub convert{
  my($file,$outfasta,$outqual)=@_;
 
  my $in=Bio::SeqIO->new(-file=>$file,-format=>"fastq"); ###### this may need to be switched to fastq-illumina ######
  my $seqOut=Bio::SeqIO->new(-file=>">$outfasta",-forymat=>"fasta");
  my $qualOut=Bio::SeqIO->new(-file=>">$outqual",-format=>"qual");
  my $seqCount=0;
  my $percentDone=0;
  while(my $seq=$in->next_seq){
    $seqOut->write_seq($seq);
    $qualOut->write_seq($seq);
    $seqCount++;
  }

  return 1;
}
