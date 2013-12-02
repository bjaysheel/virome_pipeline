#!/usr/bin/perl -w

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
BEGIN{foreach (@INC) {s/\/usr\/local\/packages/\/local\/platform/}};

=head1 NAME

sequence-prep.pl - prepare sequence info for upload to db

=head1 SYNOPSIS

USAGE: sequence-prep.pl
            --input=/path/to/fasta
	    --outdir=/output/dir
	    --libListFile=/library/list/file
	    --rna=/rna/flag
	    --orf=/orf/flag
            --outdir=/output/dir
          [ --log=/path/to/logfile
            --debug=N
          ]

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

B<--rna, -r>
    flag indication RNA sequences
    
B<--orf, -o>
    flag indication ORF sequences

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
use DBI;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use UTILS_V;

BEGIN {
  use Ergatis::Logger;
}

##############################################################################
my %options = ();
my $results = GetOptions (\%options,
                          'input|i=s',
			  'outdir|od=s',
                          'libListFile|ll=s',
			  'rna|r=s',
			  'orf|o=s',
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

## local variables needed to parse file.
my $basepair = "";
my $name = "";
my $header = "";
my $size = 0;
my $gc = 0;

## open handler to read input file.
open (DAT, "<", $options{input}) || die $logger->logdie("Could not open file $options{input}");
open (OUT, ">>", $filename) || die $logger->logdie("Could not open file $filename");

#loop through input and upload them to db
while (<DAT>){
  unless (/^#/){
    chomp $_;
    
    if (/^>/){
      if (length($basepair)){
	$size = length($basepair);
	$gc = &calculate_gc($basepair);
	
	#print out seq to tab file for mysqlimport
	print OUT join("\t", $libraryId, $utils->trim($name), $utils->trim($header),
		       $utils->trim($gc), $utils->trim($basepair), $utils->trim($size),
		       $options{rna}, $options{orf})."\n";
      }
      
      $header = $_;
      my @info = split(/ /,$header);
      $name = substr($info[0],1);
      $basepair = "";
    }
    else {
      $basepair .= $_;
    } 
  }
}

## insert the last sequence in fasta file.
$size = length($basepair);
$gc = &calculate_gc($basepair);
print OUT join("\t", $libraryId, $utils->trim($name), $utils->trim($header),
	       $utils->trim($gc), $utils->trim($basepair), $utils->trim($size),
	       $options{rna}, $options{orf})."\n";

close DAT;
close OUT;
exit(0);

###############################################################################
sub check_parameters {
  ## at least one input type is required
  unless ( $options{input} && $options{outdir} && $options{libListFile}) {
      pod2usage({-exitval => 2, -message => "error message", -verbose => 1, -output => \*STDERR});
      $logger->logdie("No input defined, plesae read perldoc $0\n\n");
      exit(1);
  }
}

###############################################################################
sub calculate_gc{
  my $bp = shift;
  my $offset = 0;
  my $c = 0;
  my $result = index($bp, "G", $offset);

  # count number of G's
  while ($result != -1){
    $c += 1;
    $offset = $result + 1;
    $result = index($bp, "G", $offset);
  }

  $offset = 0;
  $result = index($bp, "C", $offset);
  
  #count number of C's
  while ($result != -1){
    $c += 1;
    $offset = $result + 1;
    $result = index($bp, "C", $offset);
  }
  
  return (($c/length($bp)*100));
}