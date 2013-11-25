#!/usr/bin/perl -w

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
BEGIN{foreach (@INC) {s/\/usr\/local\/packages/\/local\/platform/}};

=head1 NAME

mga2seq_pep.pl - convert metagene raw output to fasta nucliotide and peptide file

=head1 SYNOPSIS

USAGE: mga2seq_pep.pl
            --input=/path/to/fasta
	    --mga=/path/to/mga/output
	    --prefix
	    --outdir
          [ --log=/path/to/logfile
            --debug=N
          ]

=head1 OPTIONS

B<--input, -i>
    The full path to fasta sequence file.

B<--input, mga>
    Metagene output file

B<--debug,-d>
    Debug level.  Use a large number to turn on verbose debugging.

B<--log,-l>
    Log file

B<--help,-h>
    This help message

=head1  DESCRIPTION

This script is used to convert metagene output to nucleotide and peptide seq file.

=head1  INPUT

The input to this is defined using the --input/-i or mga/-m.  This should point
to the fasta file containing sequence(s), and metagene output file

=head1  CONTACT

    Jaysheel D. Bhavsar
    bjaysheel@gmail.com

=cut

use strict;
use TIGR::FASTAiterator;
use TIGR::Foundation;
use TIGR::FASTArecord;
use BeginPerlBioinfo;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
BEGIN {
	use Ergatis::Logger;
}

my %options = ();
my $results = GetOptions (\%options,
                          'input|i=s',
						  'mga|m=s',
						  'prefix|p=s',
						  'outdir|o=s',
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

#from TIGR (Jacques Ravel)
#
# REVISION HISTORY
# 6/18/08   - fixed bug with sequence header not matching metagene output - S. Polson
# 1/5/2009  - fixed bug with long sequence headers - S. Polson
# 1/15/2009 - modified to accept metagene annotator output - S. Dhankar
# 2/3/2009  - additonal output was added on the fasta line for clustering - S Polson
# 4/9/2009  - fixed issue with negative strand nucleotide orf outputs not being rev. comp. - S Polson
# 4/9/2009  - fixed issue with alternate start codons being translated incorrectly - S. Polson
# 4/27/2009 - ergatis component - J. D. Bhavsar
# 4/4/2011  - fixed issue with single-digit ergatis split input files

my ($read, $pep, $gc, $domain, $info, $tag, $sub_seq, $sub_prot, $ln, $ln2, $tag2);
my %h_info;
my %h_prot;
my $i=0;
my $mark=0;
my ($rbs, $pairing, $model, @tp, $line);

open(NOPREDICT, ">".$options{outdir}."/".$options{prefix}.".no_prediction.list") or $logger->logdie("Could not open file $options{outdir}/$options{prefix}.no_prediction.list");
open(SEQ, ">".$options{outdir}."/".$options{prefix}.".seq") or $logger->logdie("Could not open file $options{outdir}/$options{prefix}.seq");
open(PROT, ">".$options{outdir}."/".$options{prefix}.".pep") or $logger->logdie("Could not open file $options{outdir}/$options{prefix}.pep");

my $file = `egrep "$options{prefix}\\." $options{mga}`;   # modified 4/4/11 SWP

unless (length($file)){
    $logger->logdie("No metagene output file for $options{prefix}");
    exit(1);
}

open(META, $file);
my @metagene = <META>;
close(META);

foreach $line (@metagene) {
	if ($line =~ /^\#\s(\S+)/ && $line !~ /^\#\sself\:/ && $line !~ /^\#\sgc\s\=/) {
		$read = $1;
		$metagene[$i+1] =~ /^\#\sgc\s=\s(0\.\d+)\,\srbs\s=\s(\S+)$/;
		#print $metagene[$i+1]."\n";
		$gc=$1;
		$rbs=$2;
		($domain) = ($metagene[$i+2] =~ /^\# self\: (\S+)/);

		if($domain eq "a") {
			$domain = "archaea";
		} elsif($domain eq "p") {
			$domain ="phage";
		} elsif($domain eq "b") {
			$domain = "bacteria";
		} elsif($domain eq "s") {
			$domain = "self";
		}

		if ($metagene[$i+3] && $metagene[$i+3] =~ /^gene/) {
			$h_info{$read} = "gc=$gc";
			#$h_info{$read} = "readGC=$gc readRBSpct=$rbs readModel=$domain";
		} else {
			print NOPREDICT "$read\n";
		}
	} elsif ($line =~ /^gene/) {
		chomp $line;
		@tp = split(/\s+/, $line);

		if($tp[7] eq "a"){
		  $model = "archaea";
		} elsif($tp[7] eq "p"){
		  $model ="phage";
		} elsif($tp[7] eq "b"){
		  $model = "bacteria";
		} elsif($tp[7] eq "s"){
		  $model = "self";
		}

		my $type = "";
		if ($tp[5] =~ /00/) {
			$type="incomplete";
		} elsif ($tp[5] =~ /10/) {
			$type = "lack_stop";
		} elsif ($tp[5] =~ /01/){
			$type = "lack_start";
		} elsif ($tp[5] =~ /11/){
			$type = "complete";
		}

		# edited: May 18th 2012
		# update sequence description
		# Jaysheel D. Bhavsar
		if($tp[3] eq "+"){
			push (@{$h_prot{$read}}, "start=$tp[1]\tstop=$tp[2]\tstrand=$tp[3]\tframe=$tp[4]\tmodel=$model\tscore=$tp[6]\ttype=$type\tcaller=MetaGENE\n");
			#push (@{$h_prot{$read}}, "start=$tp[1]\tstop=$tp[2]\tstrand=$tp[3]\tframe=$tp[4]\tmodel=$model\tends=$tp[5]\tORFscore=$tp[6]\tRBSstart=$tp[8]\tRBSstop=$tp[9]\tRBSscore=$tp[10]\n");
		} elsif($tp[3] eq "-"){
			push (@{$h_prot{$read}}, "start=$tp[2]\tstop=$tp[1]\tstrand=$tp[3]\tframe=$tp[4]\tmodel=$model\tscore=$tp[6]\ttype=$type\tcaller=MetaGENE\n");
			#push (@{$h_prot{$read}}, "start=$tp[2]\tstop=$tp[1]\tstrand=$tp[3]\tframe=$tp[4]\tmodel=$model\tends=$tp[5]\tORFscore=$tp[6]\tRBSstart=$tp[8]\tRBSstop=$tp[9]\tRBSscore=$tp[10]\n");
		}
	}
	$i++;
}

my $tf = new TIGR::Foundation;

if (!defined $tf){
    $logger->logdie("Bad foundation\n");
}

my @errors;
my $cmd = "awk NF $options{input} > $options{outdir}/tmp.seq.fsa";
system($cmd);
$cmd = "cp ".$options{outdir}."/tmp.seq.fsa $options{input}";
system($cmd);
my $fr = new TIGR::FASTAiterator($tf, \@errors, "$options{input}");

if (!defined $fr){
	$logger->logdie("Bad reader\n");
}

my $none;
my $success;
while ($fr->hasNext){
    my $rec = $fr->next();

    # eliminate empty line error.
    #if (defined $rec){
	my $id = $rec->getIdentifier();
	my $body = $rec->getData();

	my $z = 1;
	if (!defined $h_prot{$id}){
	    #print "$id: NO ORFS FOUND\n";
	    $none++;
	    #next;
	} else {

		foreach my $line (@{$h_prot{$id}}) {
			chomp $line;

			my @att = split ("\t", $line);
			my $h;
			for($h=0; $h<6; $h++) {
				($att[$h])=($att[$h]=~/^\S+\=(\S+)$/);
			}
			$line =~ s/\t/ /g;
			#$line =~ s/\'/\-prime/g;

			if ($att[2] eq "+") {
				$sub_seq = quickcut ($body, ($att[0]+$att[3]), $att[1]);
			} elsif ($att[2] eq "-") {
				$sub_seq = quickcut ($body, $att[1], ($att[0]-$att[3]));
			}

			$ln = length($sub_seq);
			$tag = $id . "_$att[0]_$att[1]_$z" . " size=$ln " . $h_info{$id}. " " . $line;

			$success++;
			if ($att[2] eq "+") {
				printFastaSequence(\*SEQ, $tag, $sub_seq);
				$sub_prot = dna2peptide2($sub_seq);
				$ln2 = length($sub_prot);
				$tag2 = $id . "_$att[0]_$att[1]_$z" . " size=$ln2 " . $h_info{$id}. " ". $line;
				printFastaSequence(\*PROT, $tag2, $sub_prot);
			} elsif ($att[2] eq "-") {
				printFastaSequence(\*SEQ, $tag, revcom($sub_seq));
				$sub_prot = dna2peptide2(revcom($sub_seq));

				if ($att[5] =~ /^1/){
					$sub_prot =~ s/^./M/
				}

				$ln2 = length($sub_prot);
				$tag2 = $id . "_$att[0]_$att[1]_$z" . " size=$ln2 " . $h_info{$id}. " ". $line;
				printFastaSequence(\*PROT, $tag2, $sub_prot);
			}
			$z++;
		}
	}
    #}
}

exit(0);

sub printFastaSequence
{
    my($file) = $_[0];
    my($header) = $_[1];
    my($seqs) = $_[2];
    print $file ">$header\n";
    printSEQ($file, $seqs);

} # printFastaSequence

sub printSEQ
{
	my $file = shift;
	my $seqs = shift;

	for (my $j = 0; $j < length($seqs); $j += 80) {
		print $file substr($seqs, $j, 80), "\n";
	}
} # printSEQ

sub check_parameters {
    ## at least one input type is required
    unless ( $options{input} && $options{mga} && $options{prefix} && $options{outdir}) {
		$logger->logdie("Missing input, plesae read perldoc $0\n\n");
		exit(1);
    }

	if(0){
		pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
	}
}
