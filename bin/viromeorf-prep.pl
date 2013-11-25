#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
BEGIN{foreach (@INC) {s/\/usr\/local\/packages/\/local\/platform/}};

=head1 NAME

viromeorf-prep.pl - prepare orf calls for mysql upload

=head1 SYNOPSIS

USAGE: viromeorf-prep.pl
            --input=/path/orf/output
			-liblist=/library/list/file/from/db-load-library
            --lookupDir=/dir/where/mldbm/lookup/files/are
          [ --log=/path/to/logfile
            --debug=N
          ]

=head1 OPTIONS

B<--input, -i>
    The full path to orf output

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

This script is used to prepare orf output for mysql upload

=head1  INPUT

The input to this is defined using the --input.  This should point
to orf output file.

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
use Bio::SeqIO;
use UTILS_V;

BEGIN {
  use Ergatis::Logger;
}

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

##############################################################################

## make sure everything passed was peachy
&check_parameters(\%options);
my $utils = new UTILS_V;

# check if the file is empty.
unless(-s $options{input} > 0){
	print STDERR "This file $options{input} seem to be empty nothing therefore nothing to do.";
	$logger->debug("This file $options{input} seem to be empty nothing therefore nothing to do.");
	exit(0);
}

my $libraryId = $utils->get_libraryId_from_list_file($options{input},$options{liblist},"fasta");
my $lookup_file = $options{'lookupDir'}."/sequence_".$libraryId.".ldb";

# tie in sequence lookup db.
tie(my %sequenceLookup, 'MLDBM', $lookup_file);
$utils->set_sequence_lookup(\%sequenceLookup);

my $fsa = Bio::SeqIO->new(-file   => $options{'input'},
						  -format => 'fasta'
					     );

my $filename = $options{outdir}."/orf.txt";

open (OUT, ">>", $filename) || die $logger->logdie("Could not open file $filename\n");

while(my $seq = $fsa->next_seq) {
	#my $info;
	my %info;
	my $seq_desc = $seq->desc;
	$seq_desc =~ s/lack (start|stop)/lack_$1/;
	map { $info{$1} = $2 if( /([^=]+)\s*=\s*([^=]+)/ ) } split(/\s+/, $seq_desc);

	my @name = split(/_/, $seq->id);
	my $read = join('_',@name[0..$#name-3]);

	my $seqId = $utils->get_sequenceId($seq->id);
	my $readId = $utils->get_sequenceId($read);

	$info{type} =~ s/_/ /;

	#make sure start < end.
	$info{start} = $utils->trim($info{start});
	$info{end} = $utils->trim($info{end});

	if ($info{start} > $info{end}){
		my $tmp = $info{start};
		$info{start} = $info{end};
		$info{end} = $tmp;
		$info{strand} = "-";
	}

	print OUT join("\t",$readId, $seqId, $utils->trim($seq->id), $utils->trim($info{geneNum}), 0, 0,
					$utils->trim($info{start}), $utils->trim($info{end}), $utils->trim($info{strand}),
					$utils->trim($info{frames}), $utils->trim($info{type}), $utils->trim($info{score}),
					$utils->trim($info{model}), 0, 0, 0, $utils->trim($info{caller})
				  )."\n";
}

#close file handlers
untie(%sequenceLookup);
close OUT;
exit(0);

##############################################################################
sub check_parameters {
  ## at least one input type is required
  unless ($options{input} && $options{outdir} && $options{lookupDir} && $options{liblist}){
      pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
      $logger->logdie("No input defined, plesae read perldoc $0\n\n");
      exit(1);
  }

}

##############################################################################
sub getORFType{
  my $type = $_[0];

  if ($type == 11){
    return "complete";
  }
  if ($type == 00){
    return "incomplete";
  }
  if ($type == 10){
    return "lack stop";
  }
  if ($type == 01){
    return "lack start";
  }
  else { return "n/a"; }
}

##############################################################################
sub getModel{
  my $model = $_[0];

  if ($model =~ m/s/i){
    return "self";
  }
  if ($model =~ m/b/i){
    return "bacteria";
  }
  if ($model =~ m/a/i){
    return "archaea";
  }
  if ($model =~ m/p/i){
    return "phage";
  }
  else { return "n/a"; }
}
