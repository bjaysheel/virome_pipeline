#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
BEGIN{foreach (@INC) {s/\/usr\/local\/packages/\/local\/platform/}};

=head1 NAME

metagene-prep.pl - prepare metagene raw output for mysql upload

=head1 SYNOPSIS

USAGE: metagene-prep.pl
            --input=/path/to/metagene/raw/output
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

This script is used to prepare metagene raw output for mysql upload

=head1  INPUT

The input to this is defined using the --input.  This should point
to the metagene raw output file.

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

my $libraryId = $utils->get_libraryId_from_list_file($options{input},$options{liblist},"metagene");
my $lookup_file = $options{'lookupDir'}."/sequence_".$libraryId.".ldb";

# tie in sequence lookup db.
tie(my %sequenceLookup, 'MLDBM', $lookup_file);
$utils->set_sequence_lookup(\%sequenceLookup);

#loop through input and upload them to db
my $headLine = 0;
my @info;
my $gc = 0;
my $rbs = 0;
my $model = "";
my $self = "";
my $gene_num = 0;
my $name = "";
my $readId = 0;
my $seqId = 0;

my $filename = $options{outdir}."/orf.txt";

## open handler to read input file.
open (DAT, "<", $options{input}) || die $logger->logdie("Could not open file $options{input}\n");
open (OUT, ">>", $filename) || die $logger->logdie("Could not open file $filename\n");

while (<DAT>){
    chomp $_;
    undef @info;
    
    if (/^#/){
      $gene_num = 0;

      if ($headLine > 2){
	#there is no gene prediction for the current name;
	print STDERR "No gene prediction for gene $name\n";
	$logger->debug("No gene prediction for gene $name\n");
	$headLine=0;
	$gene_num=0;
	$readId=0;
	$seqId=0;
	undef @info;
      }

      ## read and parse header info
      if ($headLine == 0){
	@info = split(/ /, $_);
	$name = $info[1];
    
        ## get sequenceId.
	$readId = $utils->get_sequenceId($name);
      }
      if ($headLine == 1){
	@info = split(/,/, $_);
	## get gc number from $info[0] i.e # gc = 0.0000
	if ($info[0] =~ m/[+-]?(\d+\.\d+|\d+\.|\.\d+)/){
	  $gc = $1;
	}
	## get rbs number from $info[1] i.e rbs = -1
	if ($info[1] =~ m/([+-]?\d+)/){
	  $rbs = $1;
	}
      }
      if ($headLine == 2){
	#skipping self: - line
      }
      
      $headLine += 1;
    }
    elsif (length($_)) {
      ## reset header line number
      $headLine = 0;
      $gene_num += 1;
      my $n = "";
      
      ## read and prase gene
      @info = split(/\t/, $_);
            
      ## store gene info.
      my $type = getORFType($utils->trim($info[5]));
      my $model = getModel($utils->trim($info[7]));
      
      $info[8] = ($info[8] eq "-") ? 0 : $info[8];
      $info[9] = ($info[9] eq "-") ? 0 : $info[9];
      $info[10] = ($info[10] eq "-") ? 0.00 : $info[10];
      
      #set name as $name_$start_$stop_$gene_num;
      if ($utils->trim($info[3]) eq '-'){
	$n = $name ."_".$info[2]."_".$info[1]."_".$gene_num;
      } else {
	$n = $name ."_".$info[1]."_".$info[2]."_".$gene_num;
      }
      
      #get sequenceId
      $seqId = $utils->get_sequenceId($n);

	#make sure start < end.
	$info[1] = $utils->trim($info[1]);
	$info[2] = $utils->trim($info[2]);

	if ($info[1] > $info[2]){
		my $tmp = $info[1];
		$info[1] = $info[2];
		$info[2] = $tmp;
		$info[3] = "-";
	}
      
      print OUT join("\t",$readId, $seqId, $utils->trim($n), $utils->trim($gene_num), $utils->trim($gc),
		     $utils->trim($rbs), $utils->trim($info[1]), $utils->trim($info[2]), $utils->trim($info[3]),
		     $utils->trim($info[4]), $utils->trim($type), $utils->trim($info[6]), $utils->trim($model),
		     $utils->trim($info[8]), $utils->trim($info[9]), $utils->trim($info[10]), 'MetaGENE')."\n";
    }
    else {
      print STDERR "ERROR empty line encounted in file.";
      $logger->debug("ERROR empty line encounted in file.");
      $headLine=0;
      $gene_num=0;
      $readId=0;
      $seqId=0;
      undef @info;
    }
    
}

#close file handlers
untie(%sequenceLookup);
close DAT;
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
