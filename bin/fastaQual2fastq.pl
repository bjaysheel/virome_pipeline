#!/usr/bin/perl
use strict;
use Getopt::Long;
use Bio::SeqIO;
use Bio::Seq::Quality;
use Pod::Usage;
BEGIN {
  use Ergatis::Logger;
}

=head1 NAME
 fastaQual2fastq.pl
=cut

=head1 USAGE
 fastaQual2fastq.pl --fasta=/path/to/fasta --qual=/path/to/qual
=cut

=head1 OPTIONS
 B<--fasta, -f>
 The full path to fasta sequence file.
 B<--qual, -q>
 The full path to the associated quality file.
=cut

=head1  DESCRIPTION
 Script will merge a FASTA and the respective quality file together
 and output in FASTQ format.
=cut

=head1  INPUT
 The input to this is defined using the --fasta/-f and --qual/-q flags.  These should point
 to the fasta and quality files respectively.
=cut

=head1  CONTACT
 Daniel J. Nasko
 dan.nasko@gmail.com
=cut


##==================== USER VARIABLES ====================##
my %options = ();
my $results = GetOptions (\%options,
                        'fasta|f=s',
                        'quality|q=s',
			'outdir|o=s',
			'prefix|p=s',
                        'help|h') || pod2usage();
my $logfile = $options{'log'} || Ergatis::Logger::get_default_logfilename();
my $logger = new Ergatis::Logger('LOG_FILE'=>$logfile,
                                  'LOG_LEVEL'=>$options{'debug'});
$logger = $logger->get_logger();

## display documentation
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

##=================== GLOBAL VARIABLES ===================##
my $outfile = $options{outdir}."/".$options{prefix} . ".fastq";

##========================================================##
##                         MAIN                           ##
##========================================================##
open (IN,"<$options{quality}");
my $qual_file = <IN>;
close(IN);

open (IN,"<$options{fasta});
my $fasta_file = <IN>;
close(IN);

my $in_fasta_obj = Bio::SeqIO->new(   -file     => $fasta_file,
                                      -format   => 'fasta',
                                    );
my $in_quality_obj = Bio::SeqIO->new( -file     => $qual_file,
                                      -format   => 'qual',
                                    );
my $out_fastq_obj = Bio::SeqIO->new(  -file     => ">$outfile",
                                      -format   => 'fastq',
                                   );

while (my $seq_obj  = $in_fasta_obj->next_seq){
my $qual_obj = $in_quality_obj->next_seq;

die "The FASTA header and Quality header do not match\n" unless $seq_obj->id eq $qual_obj->id;

my $bsq_obj = Bio::Seq::Quality->new(   -id   => $seq_obj->id,
                                        -seq  => $seq_obj->seq,
                                        -qual => $qual_obj->qual,
                                    );

  $out_fastq_obj->write_fastq($bsq_obj);
}

