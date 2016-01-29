#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

BEGIN{foreach (@INC) {s/\/usr\/local\/packages/\/local\/platform/}};
use lib (@INC,$ENV{"PERL_MOD_DIR"});
no lib "$ENV{PERL_MOD_DIR}/i686-linux";
no lib ".";

=head1 NAME

cluster_restrict_blast_parse.pl - parse inputs so we can perform a cluster restrict BLAST

=head1 SYNOPSIS

USAGE: cluster_restrict_blast_parse.pl
            --btab=/path/to/input.btab
            --fasta=/path/to/original_query.fasta
            --lookup=/path/to/cluster_lookup_file.txt
            --output_dir=/path/to/somedir

=head1 OPTIONS

B<--btab,-b>
    The output from a BLASTp against the clustered database.

B<--fasta,-f>
    The query FASTA file that was used in the clustered blast.

B<--lookup,-u>
    The database lookup file. Cluster_ID [tab] Member_ID

B<--output_dir,-o>
    The directory to which the output files will be written.

B<--debug,-d> 
    Debug level.  Use a large number to turn on verbose debugging. 

B<--log,-l> 
    Log file

B<--help,-h>
    This help message

=head1  DESCRIPTION

This script is used to prepare the intermediary files used in the cluster-restricted
blast pipeline.

=head1  OUTPUT

There will be two output files created under the --output_dir directory:
    1.) restricted_query.fasta
    2.) restricted_members.txt

restricted_query.fasta will be the input query file for the next blast and restricted_members.txt
file will be used in the next blast, passed in as the -seqidlist argument.

=head1  CONTACT

    Dan Nasko
    dnasko@udel.edu

=cut

use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use POSIX;
BEGIN {
use Ergatis::Logger;
}

my %options = ();
my $results = GetOptions (\%options, 
			  'btab|b=s',
			  'fasta|f=s',
			  'lookup|u=s',
                          'output_dir|o=s',
                          'log|l=s',
                          'debug=s',
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

## Globals
my (%Subjects,%Queries);

open(IN,"<$options{btab}") || die "\n Cannot read the input btab: $options{btab}\n";
while(<IN>) {
    chomp;
    my @fields = split(/\t/, $_);
    $Subjects{$fields[1]} = 1;
    $Queries{$fields[0]} = 1;
}
close(IN);

open(OUT,">$options{output_dir}/restricted_members.txt") || die "\n Cannot write to the restriction list output: $options{output_dir}/restricted_members.txt\n\n";
open(IN,"<$options{lookup}") || die "\n Cannot open the lookup file: $options{lookup}\n";
while(<IN>) {
    chomp;
    my @fields = split(/\t/, $_);
    if (exists $Subjects{$fields[0]}) {
	print OUT $fields[1] . "\n";
    }
}
close(IN);
close(OUT);

my $print_flag = 0;
open(FAS,"<$options{fasta}") || die "\n Cannot open the FASTA file: $options{fasta}\n";
open(OUT,">$options{output_dir}/restricted_query.fasta") || die "\n Cannot write to the output query FASTA: $options{output_dir}/restricted_query.fasta\n";
while(<FAS>) {
    chomp;
    if ($_ =~ m/^>/) {
	$print_flag = 0;
	my $header = $_;
	$header =~ s/^>//;
	$header =~ s/ .*//;
	if (exists $Queries{$header}) {
	    print OUT $_ . "\n";
	    $print_flag = 1;
	}
    }
    elsif ($print_flag == 1) {
	print OUT $_ . "\n";
    }    
}
close(FAS);

sub check_parameters {
    my $options = shift;
    
    if ( $options{fasta} ) {
	if (! -e $options{fasta} ) {
	    $logger->logdie("the input file passed ($options{fasta}) cannot be read or does not exist");
	}
    }
    else {
	$logger->logdie("You must provide the --fasta argument");
    }
    if ( $options{btab} ) {
	if (! -e $options{btab} ) {
            $logger->logdie("the input file passed ($options{btab}) cannot be read or does not exist");
	}
    }
    else {
	$logger->logdie("You must provide the --btab argument");
    }
    unless ( $options{output_dir} ) {
	$logger->logdie("You must provide the --output_dir argument");
    }
}


exit 0;
