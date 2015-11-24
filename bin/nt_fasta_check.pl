#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
BEGIN{foreach (@INC) {s/\/usr\/local\/packages/\/local\/platform/}};
use lib (@INC,$ENV{"PERL_MOD_DIR"});
use lib (@INC,$ENV{"LIB_INFO_MOD"});
no lib "$ENV{PERL_MOD_DIR}/i686-linux";
no lib ".";

=head1 NAME
   nt_fasta_check.pl

=head1 SYNOPSIS

    USAGE: nt_fasta_check.pl

=head1 OPTIONS

B<--fasta,-f>
    input fasta file

B<--outdir,-o>
    output directory to store results.

B<--help,-h>
   This help message

=head1  DESCRIPTION
	Takes as input a fasta file, and library prefix/library file
	Prefix each sequence id with PREFIX from library file, and
	check the quality of read bases.

=head1  INPUT
	Fasta file in .fsa, .fa, .fasta or .txt file format
	OUTPUT dir where updated input file is stored (output dir cannot be same as where input file is)

=head1  OUTPUT
	An updated fasta file with each sequenceId prefixed by PREFIX
	A ref file with original and new sequenceId

=head1  CONTACT
	bjaysheel@gmail.com

==head1 EXAMPLE
   nt_fasta_check.pl -i=input.fsa -o=/output_dir -ll=library_list_file
   or
   nt_fasta_check.pl -i=input.fsa -o=/output_dir -lf=library_file

=cut


use strict;
use Switch;
use File::Basename;
use Data::Dumper;
use Bio::SeqIO;
use LIBInfo;
use Pod::Usage;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

BEGIN {
  use Ergatis::Logger;
}

my %options = ();
my $results = GetOptions (\%options,
                          'fasta|f=s',
                          'outdir|o=s',
						  'libList|ll=s',
						  'libFile|lf=s',
						  'prefix|p=s',
                          'log|l=s',
                          'debug|d=s',
                          'help|h') || pod2usage();

## display documentation
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

my $logfile = $options{'log'} || Ergatis::Logger::get_default_logfilename();
my $logger = new Ergatis::Logger('LOG_FILE'=>$logfile,
                                  'LOG_LEVEL'=>$options{'debug'});
$logger = $logger->get_logger();
#############################################################################
#### DEFINE GLOBAL VAIRABLES.
##############################################################################
## make sure everything passed was peachy
&check_parameters(\%options);

my $count=0;
my @suffixes = (".fsa", ".fa", ".fasta", ".txt");
my $filebase = fileparse($options{fasta}, @suffixes);
my($warn1,$warn2,$warn3,$warn4,$warn5) = (0,0,0,0,0);

my $final_output=$options{outdir}."/".$filebase.".edited.fsa";
my $ref_file=$options{outdir}."/".$filebase.".ref";

my $libinfo = LIBInfo->new();
my $libObject;

if ($options{libList} && $options{libFile}){
	$logger->debug("Can not use both library list file and library file.  Using library file\n");
	$libObject = $libinfo->getLibFileInfo($options{libFile});
} elsif ((defined $options{libFile}) && (length($options{libFile}))){
	$libObject = $libinfo->getLibFileInfo($options{libFile});
} elsif ((defined $options{libList}) && (length($options{libList}))){
	$libObject = $libinfo->getLibListInfo($options{libList});
} else {
	$logger->logdie("Library list file or library file not defined");
	exit(-1);
}
##############################################################################

open(FOUT,">", $final_output) or $logger->logdie("Cannot open output file $final_output\n");
open(REF, ">", $ref_file) or $logger->logdie("Cannot open ref output file $ref_file\n");

my $inseq = Bio::SeqIO->new(
                            -file   => $options{fasta},
                            -format => 'fasta'
                            );

while (my $s = $inseq->next_seq){

	my $new_name = name_modifier($s->id, $libObject->{prefix});
	my $qc_flag = freq_cal($s->seq, $s->id);
	my $sequence_string = $s->seq;
	my $ATGC = $sequence_string =~ tr/ATGCatgc/ATGCatgc/;
	my $sequence_size = length($sequence_string);
	my $atgc = $ATGC / $sequence_size;
	
	if ($qc_flag == 1) {
	    print FOUT ">".$new_name."\n".$s->seq."\n";
	}
	$count++;
}


#if(($warn1/$count) > 0.05) {
#	print STDERR "ERROR 255: Number of ATCG minor warnings exceeds 5\% (".($warn1/$count).")\n";
#	exit(255);
#}

#if(($warn2/$count) > 0.03) {
#	print STDERR "ERROR 256: Number of ATCG major warnings exceeds 3\% (".($warn2/$count).")\n";
#    exit(256);
#}
#if(($warn3/$count) > 0.05) {
#	print STDERR "ERROR 257: Number of N minor warnings exceeds 5\% (".($warn3/$count).")\n";
#    exit(257);
#}
#if(($warn4/$count) > 0.03) {
#	print STDERR "ERROR 258: Number of N major warnings exceeds 3\% (".($warn4/$count).")\n";
#    exit(258);
#}

close(FOUT);
close(REF);

###############################################################################
####  SUBS
###############################################################################
sub check_parameters {
    my $options = shift;

	my @required = qw(fasta outdir);

	foreach my $key (@required) {
		unless ($options{$key}) {
			pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
			$logger->logdie("Inputs not defined, plesae read perldoc $0\n");
			exit(-1);
		}
	}
}

###############################################################################
sub name_modifier{
	my $id = shift;
	my $prefix = shift;

	## replace any underscore with dash to identify
	## prefix from rest of the sequence.
        #$id =~ s/_/-/g;
	## get rid of pipes and slashes in the header too
	$id =~ s/\|/-/g;
	$id =~ s/\//-/g;
	## get rid of parentheses as well
	$id =~ s/\(//g;
	$id =~ s/\)//g;

    my $name = $prefix . '_'. $id;

	## add old id to new id mapping
	print REF $id."\t".$name."\n";
	if (length($name) > 255) {
	    die "\n\n ERROR: There was a FASTA header longer than 255 characterss. Here's the culprit: \n $name\n\n";
	}
	return $name;
}

###############################################################################
sub freq_cal
{
    my $seq = shift;
    my $seq_name = shift;
    my $flag = 1;

    my $len = length($seq);
    $seq =~ s/X//gi;
    if ($seq =~ m/[^ATCGNRYSWKMBDHV]/i) {
	# print STDERR "Invalid base(s) in $seq_name";
	# exit(259);
	print STDERR "Warning (Major) for INVALID BASES for seq id: $seq_name\n";
	$flag = 0;
	$warn5++;
    }
    
    my $ATCGcount = () = $seq =~ /[ATCG]/ig;
    my $Ncount = () = $seq =~ /[N]/ig;
    
    my $freq_atcg = ($ATCGcount/$len)*100;
    my $freq_n = ($Ncount/$len)*100;
    
    if($freq_atcg < 97) {
	print STDERR "Warning (Minor) for ATCG Frequency (".$freq_atcg."\%) for seq id: $seq_name\n";
	$warn1++;
    }
    if($freq_atcg < 93) {
	print STDERR "Warning (Major) for ATCG Frequency (".$freq_atcg."\%) for seq id: $seq_name\n";
	$flag = 0;
	$warn2++;
    }
    if($freq_n > 5) {
	print STDERR "Warning (Major) for N frequency (".$freq_n."\%)  for seq id: $seq_name\n";
	$flag = 0;
	$warn4++;
    }
    if($freq_n > 2) {
	print STDERR "Warning (Minor) for N frequncy (".$freq_n."\%) for seq id: $seq_name\n";
	$warn3++;
    }
    return $flag;
}
