#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Coati::Logger;
use File::Basename;


my %options = ();
my $results = GetOptions (\%options, 
			  'bcp_dir|f=s',
			  'bcp_extension|e=s',
			  'output_file|d=s',
			  'log|l=s',
			  'debug=s',
			  'database_type=s',
			  'help|h') || pod2usage();

my $logfile = $options{'log'} || Coati::Logger::get_default_logfilename();
my $logger = new Coati::Logger('LOG_FILE'=>$logfile,
			       'LOG_LEVEL'=>$options{'debug'});
$logger = Coati::Logger::get_logger();

if(! $options{'bcp_extension'}){
    $logger->logdie("Must specify extension for bcp files with --bcp_extension");
}
if(! $options{'database_type'}){
    $options{'database_type'} = 'sybase';
    if ($logger->is_debug()){
	$logger->debug("--database_type was not defined and so was set to 'sybase'");
    }
}

if(-d $options{'bcp_dir'}){
    open OUTFILE,">$options{'output_file'}" or $logger->logdie("Can't open output file $options{'output_file'}");
    my @bcpfiles = glob $options{'bcp_dir'}.'/*.'.$options{'bcp_extension'};
    foreach my $bcpfile (@bcpfiles){
	open BCPFILE,"<$bcpfile" or $logger->logdie("Can't open bcp file $bcpfile");
	my $start_pos = tell(BCPFILE);	    
	my $bcpfilebasename = basename($bcpfile,".$options{'bcp_extension'}");
	while (my $line = <BCPFILE>) {

	    if ($options{'database_type'} eq 'sybase'){
		if ($line =~ /^([0-9a-f]{32})[\0\?]/g) {
		    print OUTFILE "$1 0 $bcpfilebasename ",($-[0] + $start_pos),"\n";
		}
		while ($line =~ /([0-9a-f]{32})[\0\?]/g) {
		    print OUTFILE "$1 1 $bcpfilebasename ",($-[0] + $start_pos),"\n";
		}
	    }
	    elsif ($options{'database_type'} eq 'postgresql' || $options{'database_type'} eq 'mysql'){
		if ($line =~ /^([0-9a-f]{32})[\t|\n]/g) {
		    print OUTFILE "$1 0 $bcpfilebasename ",($-[0] + $start_pos),"\n";
		}
		while ($line =~ /([0-9a-f]{32})[\t|\n]/g) {
		    print OUTFILE "$1 1 $bcpfilebasename ",($-[0] + $start_pos),"\n";
		}
	    }
	    else {
		$logger->logdie("Unsupported database vendor type '$options{'database_type'}'");
	    }

	    $start_pos = tell(BCPFILE);
	}
	close BCPFILE;
    }
    close OUTFILE;
}
else{
    $logger->logdie("Can't find bcp directory $options{'bcp_dir'}");
}
