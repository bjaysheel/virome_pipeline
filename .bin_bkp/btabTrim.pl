#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
BEGIN{foreach (@INC) {s/\/usr\/local\/packages/\/local\/platform/}};
use lib (@INC,$ENV{"PERL_MOD_DIR"});
no lib "$ENV{PERL_MOD_DIR}/i686-linux";
no lib ".";
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
BEGIN {
  use Ergatis::Logger;
}


=head1 NAME

btabTrim.pl - remove limits the number of hits per query in a btab file

=head1 SYNOPSIS

USAGE: btabTrim.pl
            --input_file_base=input btab file base name
            --input_file_path=input btab file path
            --input_file_extension=input btab file extension
			--output=/path/to/trim_file.btab
            --number=N
		[ 	--log=/path/to/logfile
            --debug=N
        ]

=head1 OPTIONS
B<--btab_file_base, -n>
    The base name of input btab file.

B<--output,-o>
    btab blast file trimmed to allow a maximum of N hits per query

B<--number,-N>
	Maximum number of hits per query desired

B<--debug,-d>
    Debug level.  Use a large number to turn on verbose debugging.

B<--log,-l>
    Log file

B<--help,-h>
    This help message

=head1  DESCRIPTION

This script is used to limit the number of hits per query in a btab blast result file

=head1  INPUT

The input to this is defined using the --btabIN_file_base, --btabIN_file_extension
--fasta_file_path and -btab option.  This should point
to the btab ncbi-blast output and original fasta file information.

=head1  OUTPUT

The output is defined using the --output.  This file is a btab format file.

=head1  CONTACT

    Shawn Polson
    polson@dbi.udel.edu

=cut




my %options = ();
my $results = GetOptions (\%options,
                          'btab_file_base|n=s',
                          'btab_file_path|p=s',
                          'btab_file_extension|e=s',
                          'output|o=s',
                          'number|N=i',
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

my $sizeLim=50;
$sizeLim=$options{'number'};

my $inputfile=$options{'btab_file_path'};
my $outputfile=$options{'output'};
my $sub;
my $count=0;

open(DAT, $inputfile) || die $logger->logdie("Could not open input file $inputfile");
open(OUT, "> $outputfile") || die $logger->logdie("Could not open output file $outputfile");

while(<DAT>)
{	my @temp=split(/\t/,$_);
	if ($sub && $sub eq $temp[0])
	{	$count++;
		if ($count < $sizeLim)
		{	print OUT $_;
		}
	}
	else
	{	$sub=$temp[0];
		$count=0;
		print OUT $_;
	}
}

close(DAT);
close(OUT);

