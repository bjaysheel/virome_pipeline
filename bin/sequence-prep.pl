#!/usr/bin/perl

=head1 NAME

sequence-prep.pl - prepare sequence info for upload to db

=head1 SYNOPSIS

USAGE: sequence-prep.pl
            --input=/path/to/fasta
			--outdir=/output/dir
			--libListFile=/library/list/file
			--type=sequence type
            --outdir=/output/dir
          [ --log=/path/to/logfile
            --debug=N ]

=head1 OPTIONS

B<--input, -i>
    The full path to fasta sequence file.
    # start a comment.
    # File format
    >ABC125234 ....
    # where ABC is three letter library prefix.

B<--outdir, -od>
    Output dir where sequence prep file is uploaded

B<--libListFile, -ll>
    Library list file eg. from db-load-library.

B<--type, -t>
    sequence type read=1, rRNA=2, orf (aa)=3, orf (dna)=4

B<--debug,-d>
    Debug level.  Use a large number to turn on verbose debugging.

B<--log,-l>
    Log file

B<--help,-h>
    This help message

=head1  DESCRIPTION

This script is used to prepare sequence for mysql upload.

=head1  INPUT

The input to this is defined using the --input.  This should point
to the fasta file containing sequence(s).  Input must be a muilt fasta
file, each file containg sequences for one library.

=head1  CONTACT

    Jaysheel D. Bhavsar
    bjaysheel@gmail.com

=cut

use strict;
use warnings;
use DBI;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use UTILS_V;
use Bio::SeqIO;

BEGIN {
  use Ergatis::Logger;
}

##############################################################################
my %options = ();
my $results = GetOptions (\%options,
                          'input|i=s',
						  'outdir|od=s',
                          'libListFile|ll=s',
						  'typeId|t=s',
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
##############################################################################

## make sure everything passed was peachy
&check_parameters(\%options);

unless(-s $options{input} > 0){
	print STDERR "This file $options{input} seem to be empty nothing therefore nothing to do.";
	$logger->debug("This file $options{input} seem to be empty nothing therefore nothing to do.");
	exit(0);
}

##############################################################################

my $utils = new UTILS_V;
my $filename = $options{outdir}."/sequence.txt";

## check if corresponding library exists.
my $libraryId = $utils->get_libraryId_from_list_file($options{input},$options{libListFile},"fasta");

#use Bio::SeqIO to parse and handle fasta file.
my $fsa = Bio::SeqIO->new( -file   => $options{input},
						   -format => 'fasta' );

open (OUT, ">>", $filename) || die $logger->logdie("Could not open file $filename");

while (my $seq = $fsa->next_seq){
	my $gc = &calculate_gc($seq->seq());

	print OUT join("\t", $libraryId, $seq->id, $seq->desc, $gc, $seq->seq(), $seq->length(), $options{typeId})."\n";
}

close OUT;
exit(0);

###############################################################################
sub check_parameters {
	## at least one input type is required
	unless ( $options{input} && $options{outdir} && $options{libListFile} && $options{typeId}) {
		pod2usage({-exitval => 2, -message => "error message", -verbose => 1, -output => \*STDERR});
		$logger->logdie("No input defined, plesae read perldoc $0\n\n");
		exit(1);
	}

	if (($options{typeId} <= 0) || ($options{typeId} > 4)){
		pod2usage({-exitval => 2, -message => "error message", -verbose => 1, -output => \*STDERR});
		$logger->logdie("Sequence type $options{type} not recognized valid values: 1,2,3,4\n");
		exit(1);
	}
}

###############################################################################
sub calculate_gc{
	my $bases = shift;

	my $c = $bases;
	my $g = $bases;

	$c =~ s/[ATG]//ig;
	$g =~ s/[ATC]//ig;

	my $gc_percent = ((length($c)+length($g))/length($bases)) * 100;

	return $gc_percent;
}
