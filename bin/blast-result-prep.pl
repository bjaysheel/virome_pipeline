#!/usr/bin/perl

=head1 NAME

blast-result-prep.pl - prepare blast btabl file for mysql upload

=head1 SYNOPSIS

USAGE: blast-result-prep.pl
            --input=/path/to/blast/btab/output
            --liblist=/library/list/file/from/db-load-library
            --lookupDir=/dir/where/mldbm/lookup/files/are
          [ --log=/path/to/logfile
            --debug=N
          ]

=head1 OPTIONS

B<--input, -i>
    The full path to blast btab output

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

This script is used to load blast results in to MySQL database.

=head1  INPUT

The input to this is defined using the --input.  This should point
to the blast btab output

Fields that are load are

  1   query_name
  2   query_length
  3   algorithm
  4   database_name
  5   hit_name
  6   qry_start
  7   qry_end
  8   hit_start
  9  hit_end
  10  percent_identity
  11  percent_similarity
  12  raw_score
  13  bit_score
  14  hit_description
  15  blast_frame
  16  qry_strand (Plus | Minus)
  17  hit_length
  18  e_value

  if UNIREF100P blast result then following are also added

  19  domain
  20  kingdom
  21  phylum
  22  class
  23  order
  24  family
  25  genus
  26  species
  27  organism
  28  fxn_topHit

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
use File::Basename;
use Data::Dumper;

#BEGIN {
#  use Ergatis::Logger;
#}

my %options = ();
my $results = GetOptions (\%options,
                          'input|i=s',
                          'outdir|od=s',
                          'liblist|ll=s',
                          'lookupDir|ld=s',
                          'log|l=s',
                          'debug|d=s',
                          'help|h') || pod2usage();

#my $logfile = $options{'log'} || Ergatis::Logger::get_default_logfilename();
#my $logger = new Ergatis::Logger('LOG_FILE'=>$logfile,
#                                  'LOG_LEVEL'=>$options{'debug'});
#$logger = $logger->get_logger();

## display documentation
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}
##############################################################################

## make sure everything passed was peachy
&check_parameters(\%options);

#if file size is greater than 0, mostly a check for rRNA blast.
unless(-s $options{input} > 0){
    print STDERR "This file $options{input} seem to be empty nothing therefore nothing to do.";
    #$logger->debug("This file $options{input} seem to be empty nothing therefore nothing to do.");
    exit(0);
}

##############################################################################
my $utils = new UTILS_V;
my $libraryId = $utils->get_libraryId_from_list_file($options{input},$options{liblist},"blast");
my $lookup_file = $options{'lookupDir'}."/sequence_".$libraryId.".ldb";

my $name = fileparse($options{input}, ".modified.btab");
my $filename = $options{outdir} ."/". $name . ".blast.btab";

# tie in sequence lookup db.
tie(my %sequenceLookup, 'MLDBM', $lookup_file);

#print Dumper(\%sequenceLookup);
#exit();

$utils->set_sequence_lookup(\%sequenceLookup);

## name
my $prev_seq="";
my $curr_seq="";
my $prev_db="";
my $curr_db="";
my $topHit=0;

# temp filename assignment
#my $filename = $options{outdir}."/blast-results.tab";

my ($qname, $qlen, $algo, $dname, $hname, $hdesc, $qstart, $qend, $hstart, $hend);
my ($pident, $psim, $rscr, $bscr, $bframe, $qstrand, $slen, $eval, $fxn_topHit);
my ($dom, $kin, $phl, $cls, $ord, $fam, $gen, $spe, $org, $hit, $db_ranking);

$qname=$qlen=$algo=$dname=$hname=$hdesc=$qstart=$qend=$hstart=$hend = '';
$pident=$psim=$rscr=$bscr=$bframe=$qstrand=$slen=$eval = '';
$dom=$kin=$phl=$cls=$ord=$fam=$gen=$spe=$org= '';
$hit=1;
$db_ranking=0;
$fxn_topHit=0;

## open handler to read input file.
open (DAT, "<", $options{input}) || die; #$logger->logdie("Could not open file $options{input}");
open (OUT, ">", $filename) || die; # $logger->logdie("Could not open file $filename");

#loop through input and upload them to db
print "Starting updates...\n";
# print "Total # of bytes to process: $total_bytes\n";

while (<DAT>){
    unless (/^#/) {

        my $line = $_;
        chomp $line;

        my @info = split (/\t/, $line);
        my $sequenceId = $utils->get_sequenceId($info[0]);

        #print $sequenceId."\t".$info[0]."\n";
        #exit();

        #update on 10/6/10 by Jaysheel, assuming that input comes from
        #clean_expand_btab.pl file. Which will format ncbi-blast btab file
        #to proper standard for virome blastx/n/p tables.

        #if array length is of size 17 or 18 elements then its a METAGENOMES
        #output with out any taxonomy data.
        #else its a UNIREF100P formated blast result.

        if ($#info == 27){
            $dom = $utils->trim($info[18]);
            $kin = $utils->trim($info[19]);
            $phl = $utils->trim($info[20]);
            $cls = $utils->trim($info[21]);
            $ord = $utils->trim($info[22]);
            $fam = $utils->trim($info[23]);
            $gen = $utils->trim($info[24]);
            $spe = $utils->trim($info[25]);
            $org = $utils->trim($info[26]);
            $fxn_topHit = $utils->trim($info[27]);
        }

        $qname = $utils->trim($info[0]);
        $qlen = $utils->trim($info[1]);
        $algo = $utils->trim($info[2]);
        $dname = $utils->trim($info[3]);
        $hname = $utils->trim($info[4]);
        $qstart = $utils->trim($info[5]);
        $qend = $utils->trim($info[6]);
        $hstart = $utils->trim($info[7]);
        $hend = $utils->trim($info[8]);
        $pident = $utils->trim($info[9]);
        $psim = $utils->trim($info[10]);
        $rscr = $utils->trim($info[11]);
        $bscr = $utils->trim($info[12]);
        $hdesc = $utils->trim($info[13]);
        $bframe = $utils->trim($info[14]);
        $qstrand = $utils->trim($info[15]);
        $slen = $utils->trim($info[16]);
        $eval = $utils->trim($info[17]);

        ## end update 10/6/10

        # check if self blast result
        if ($qname ne $hname) {

            # check if this is the first hit, and set tophit flag
            $curr_seq = $qname;
            $curr_db = $dname;

            if (($curr_seq ne $prev_seq) || ($curr_db ne $prev_db)){
                $topHit = 1;
                $prev_seq = $curr_seq;
                $prev_db = $curr_db;
            } else {
                $topHit = 0;
            }

            # db ranking system
            if ($dname =~ /uniref100p/i){
                $db_ranking = 100;
            } elsif ($dname =~ /aclame/i){
                $db_ranking = 90;
            } elsif ($dname =~ /phgseed/i){
            	$db_ranking = 80;
            } elsif ($dname =~ /seed/i){
                $db_ranking = 70;
            } elsif ($dname =~ /kegg/i){
                $db_ranking = 60;
            } elsif ($dname =~ /cog/i){
                $db_ranking = 50;
            } elsif ($dname =~ /metagenomes/i){
                $db_ranking = 10;
            }

            #output data to tab file for import.
            print OUT join("\t",$qname, $qlen, $algo, $dname, $hname,
            	  $qstart, $qend, $hstart, $hend, $pident, $psim,
            	  $rscr, $bscr, $hdesc, $bframe, $qstrand, $slen, $eval,
            	  $dom, $kin, $phl, $cls, $ord, $fam, $gen, $spe, $org,
            	  $sequenceId, $topHit, $db_ranking, $fxn_topHit);
            print OUT "\n";
        } # end check for self blast.
        else {
            print "SELF BLAST : \n@info\n\n";
        }

    } #end check for comments
} #end while loop

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
      #$logger->logdie("No input defined, plesae read perldoc $0\n\n");
      exit(1);
  }
}
