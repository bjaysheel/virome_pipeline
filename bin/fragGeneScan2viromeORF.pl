#!/usr/bin/perl

=head1 NAME
	fragGeneScan2viromeORF.pl

=head1 SYNOPSIS

	USAGE: fragGeneScan2viromeORF.pl -i=input dir -p=inputFilePrefix -r=originalReadFile.fsa

=head1 OPTIONS

B<--input_dir,-i>
   Input directory where all fragGeneScan output files are
   expecting
		PREFIX.frag_gene_scan.raw file
		PREFIX.faa
		PREFIX.ffn and
		PREFIX

B<--inputFilePrefix, -p>
	Input file name prefix

B<--read_file, -r>
	Original read file input to FragGeneScan

B<--help,-h>
   This help message

=head1  DESCRIPTION


=head1  INPUT


=head1  OUTPUT


=head1  CONTACT
  Jaysheel D. Bhavsar @ bjaysheel[at]gmail[dot]com


==head1 EXAMPLE


=cut

use strict;
use warnings;
use Bio::SeqIO;
use Bio::Index::Fasta;
use File::Basename;
use Data::Dumper;
use Pod::Usage;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
#use VIROMEORF;

my %options = ();
my $results = GetOptions (\%options,
                          'input_file|i=s',
						  'read_file_lst|r=s',
                          'output_dir|o=s',
						  'help|h') || pod2usage();

# display documentation
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

timer(); #call timer to see when process started.
&check_parameters(\%options);
##############################################################################
my $base_dir = dirname($options{input_file});
my $basename = basename($options{input_file}, ".faa");

my $faa_name = $base_dir."/".$basename.".faa";
my $ffn_name = $base_dir."/".$basename.".ffn";
my $raw = $base_dir."/".$basename;

my $read_file = `grep "$basename.fsa" $options{read_file_lst}`;
chomp $read_file;

my $faa_idx = Bio::Index::Fasta->new( '-filename' => '/tmp/'.$basename.'.faa.idx',
								  '-write_flag' => 1 );

my $ffn_idx = Bio::Index::Fasta->new( '-filename' => '/tmp/'.$basename.'.ffn.idx',
								  '-write_flag' => 1 );

my $read_idx = Bio::Index::Fasta->new( '-filename' => '/tmp/'.$basename.'.fsa.idx',
								  '-write_flag' => 1 );

$faa_idx->make_index($faa_name);
$ffn_idx->make_index($ffn_name);
$read_idx->make_index($read_file);

open (FAA_OUT, ">", $options{output_dir}."/".$basename.".mod.faa") or die "Could not open file to write\n$!\n";
open (FFN_OUT, ">", $options{output_dir}."/".$basename.".mod.ffa") or die "Could not open file to write\n$!\n";

open(RAW, "<", $raw) or die "Could not open fragGeneScan raw file $raw\n$!\n";
my @fragGeneScan = <RAW>;

my $read_id = "";
my $start = 0;
my $stop = 0;
my $strand = "";
my $frame = "";
my $score = 0;
my $type = "";
my $indel = "";
my $faa_id = "";
my $caller = "FragGeneScan";
my $model = "NA";
my $z = 0;
my $id_n_header = "";

foreach my $line (@fragGeneScan){
	chomp $line;

	if ($line =~ /^>/){
		# get orf id
		$read_id = substr($line,1);
		$z = 0;
	} else {
		my @bits = split(/\t|\s+/,$line);

		$start = $bits[0];
		$stop = $bits[1];
		$strand = $bits[2];
		$frame = $bits[3];
		$score = $bits[4];
		$indel = $bits[5]."".$bits[6];

		$z++;

		$faa_id = $read_id ."_". $start ."_". $stop ."_". $strand;

		# take account of insert and delete operations.
		#my $delta = calculateDelta($bits[5], $bits[6]);

		#adjust end with delta;
		#$stop += $delta;

		my $stopC = 0;
		my $faa = $faa_idx->fetch($faa_id);
		my $ffn = $ffn_idx->fetch($faa_id);
		my $read = $read_idx->fetch($read_id);
		my $seq = $faa->seq;

		if ($strand =~ /-/){
			# reverse the amino acid seq this way always checking
			# from of the seq to find M (start codon).
			$seq = reverse($faa->seq);

			# reverse completement read seq this way always checking
			# end of seq for stop codon
			$read = $read->revcom();
		}

		if ($stop+3 < length($read->seq)){
			if ($read->subseq($stop,($stop+3)) =~ /TAG|TAA|TGA/){
				$stopC = 1;
			}
		}

		if (($seq =~ /^M/i) && $stopC){
			$type = "complete";
		} elsif (($seq =~ /^M/i) && !$stopC){
			$type = "lack stop";
		} elsif (($seq =~ /[^M]/i) && $stopC){
			$type = "lack start";
		} else {
			$type = "incomplete";
		}

		$id_n_header = ">". $read_id ."_". $start ."_". $stop ."_". $z ." start=$start\tstop=$stop\tstrand=$strand\tframe=$frame\tmodel=$model\tscore=$score\ttype=$type\tcaller=$caller\tother=$indel\n";

		print FAA_OUT $id_n_header;
		print FAA_OUT $faa->seq."\n";

		print FFN_OUT $id_n_header;
		print FFN_OUT $ffn->seq."\n";
	}
}

exit();

###############################################################################
####  SUBS
###############################################################################
sub check_parameters {
    my $options = shift;
	my @required = qw(input_file output_dir read_file_lst);

	foreach my $param (@required){
		if (!defined $options->{$param}){
			print STDERR "ERROR: Parameter $param required\n";
			pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
			exit(-1);
		}
	}
}

sub calculateDelta{
	my($insert, $delete) = (shift,shift);

	my $delta = 0;

	# remove I: and D:
	$insert =~ s/^I://;
	$delete =~ s/^D://;

	# remove trailing ,
	$insert =~ s/,$//;
	$delete =~ s/,$//;

	my @in = split(/,/, $insert);
	my @del = split(/,/, $delete);

	$delta += scalar(@in);
	$delta -= scalar(@del);

	return $delta;
}

###############################################################################
sub timer {
    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
    my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
    my $year = 1900 + $yearOffset;
    my $theTime = "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";
    print "Time now: " . $theTime."\n";
}
