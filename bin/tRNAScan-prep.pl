#!/usr/bin/perl

=head1 NAME

tRNAScan-prep.pl - prepare tRNAScan raw output for mysql upload

=head1 SYNOPSIS

USAGE: tRNAScan-prep.pl
            --input=/path/to/metagene/raw/output
	    --outdir=/output/directory
	    -liblist=/library/list/file/from/db-load-library
            --lookupDir=/dir/where/mldbm/lookup/files/are
          [ --log=/path/to/logfile
            --debug=N
          ]

=head1 OPTIONS

B<--input, -i>
    The full path to metagene raw output

B<--liblist, -ll>
    Library list file, and output of db-load-library.

B<--lookupDir, -ld>
    Dir where all lookup files are stored.

B<--debug,-d>
    Debug level.  Use a large number to turn on verbose debugging.

B<--log,-l>
    Log file

B<--help,-h>
    This help message

=head1  DESCRIPTION

This script is used to prepare tRNAScan results for mysql upload.

=head1  INPUT

The input to this is defined using the --input.  This should point
to the tRNAScan-SE raw output file list.  One file per line.

=head1  CONTACT

    Jaysheel D. Bhavsar
    bjaysheel@gmail.com

=cut

use strict;
use warnings;
use DBI;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use MLDBM 'DB_File';
use Fcntl qw( O_TRUNC O_RDONLY O_RDWR O_CREAT);
use UTILS_V;
use Data::Dumper;

BEGIN {
  use Ergatis::Logger;
}

###############################################################################
my %options = ();
my $results = GetOptions (\%options,
                          'input|i=s',
                          'outdir|od=s',
                          'liblist|ll=s',
                          'lookupDir|ld=s',
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

###############################################################################
## make sure everything passed was peachy
&check_parameters(\%options);

# check if tRNA output file is not empty
# check if the file is empty.
unless(-s $options{input} > 0){
    print STDERR "This file $options{input} seem to be empty nothing therefore nothing to do.";
    $logger->debug("This file $options{input} seem to be empty nothing therefore nothing to do.");
    exit(0);
}

###############################################################################
my $utils = new UTILS_V;

my $libraryId = $utils->get_libraryId_from_list_file($options{input},$options{liblist},"tRNAScan");
my $lookup_file = $options{'lookupDir'}."/sequence_".$libraryId.".ldb";

# tie in sequence lookup db.
tie(my %sequenceLookup, 'MLDBM', $lookup_file);
$utils->set_sequence_lookup(\%sequenceLookup);

## tRNAScan-SE score threshold
my $threshold = 20.00;

my $filename = $options{outdir}."/tRNA.txt";

## open handler to read input file.
open (DAT, "<", $options{input}) || die $logger->logdie("Could not open file $options{input}\n");
open (OUT, ">>", $filename) || die $logger->logdie("Could not open file $filename\n");

#loop through input and upload them to db
while (<DAT>){
    unless (/^#/){
        chomp $_;
        my @info = split(/\t/,$_);

        ## get sequenceId.
        my $sequenceId = $utils->get_sequenceId($utils->trim($info[0]));

        ## check for duplicate entry and threshold cut off.
        if ($info[8] >= $threshold) {
            $info[4] =~ s/\$([a-z])/\u$1/ig;
            $info[4] =~ s/pse/Pseudo/i;
            $info[4] =~ s/und/Undef/i;

            print OUT join("\t",$utils->trim($sequenceId), $utils->trim($info[1]), $utils->trim($info[2]), $utils->trim($info[3]),
            	   $utils->trim($info[4]), $utils->trim($info[5]), $utils->trim($info[6]), $utils->trim($info[7]), $utils->trim($info[8]))."\n";
        }
    }
}

untie(%sequenceLookup);
close DAT;
close OUT;

exit(0);

###############################################################################
sub check_parameters {
  ## at least one input type is required
  unless ($options{input} && $options{outdir} && $options{lookupDir} && $options{liblist}){
      pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
      $logger->logdie("No input defined, plesae read perldoc $0\n\n");
      exit(1);
  }
}
