#!/usr/bin/perl

=head1 NAME

split-tab-output.pl: split tab output created for mysql upload

=head1 SYNOPSIS

USAGE: split-tab-output.pl
            --input=/library/info/file
	    --outdir=/output/dir
	    --prefix=/file/prefix/name
	    --numSplit=/number/of/splits
          [ --log=/path/to/logfile
            --debug=N
          ]

=head1 OPTIONS

B<--input, -i>
    tab delimited library info file.

B<--outdir, -o>
    output dir where lookup file will be stored

B<--prefix, -p>
    prefix file name

B<--numSplit, -s>
    no of splits to create

B<--debug,-d>
    Debug level.  Use a large number to turn on verbose debugging.

B<--log,-l>
    Log file

B<--help,-h>
    This help message

=head1  DESCRIPTION

This script is used to split tab output created for mysql upload

=head1  INPUT

=head1  CONTACT

    Jaysheel D. Bhavsar
    bjaysheel@gmail.com

=cut

use strict;
use warnings;
use POSIX qw(ceil floor);
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;

BEGIN {
  use Ergatis::Logger;
}

##############################################################################
my %options = ();
my $results = GetOptions (\%options,
                          'input|i=s',
                          'outdir|o=s',
                          'prefix|p=s',
                          'numSplit|s=s',
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

my $cmd = "cat $options{input} | wc -l";
my $total_lines = `$cmd`;

if ($total_lines <= 0){
    print STDERR "Cannot determin number of lines in input file $options{input}\n";
    exit(-1);
}

my $perFile = ceil($total_lines/$options{numSplit});
my $filename = $options{outdir}."/".$options{prefix};

$cmd = "split -l $perFile $options{input} $filename";
system($cmd);

my $part = 1;
opendir (DIR, $options{outdir}) or $logger->logdie("Could not open output dir $options{outdir}");
while (my $file = readdir(DIR)) {
	if ($file =~ /^$options{prefix}/) {
		$cmd = "mv $options{outdir}/$file $options{outdir}/${file}_$part.split";
		system($cmd);
	}
	$part++;
}

if (( $? >> 8 ) != 0 ){
    print STDERR "command failed: $!\n";
    print STDERR $cmd."\n";
    exit($?>>8);
}

exit(0);

###############################################################################
sub check_parameters {
  ## at least one input type is required
  unless ( $options{input} && $options{outdir} && $options{prefix} && $options{numSplit} ) {
      pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
      $logger->logdie("No input defined, plesae read perldoc $0\n\n");
      exit(1);
  }
}
