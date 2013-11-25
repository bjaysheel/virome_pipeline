#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Coati::Logger;
use File::Basename;
use Prism;


my %options = ();
my $results = GetOptions (\%options, 
			  'bcp_dir|d=s',
			  'bcp_extension|e=s',
			  'output_dir|o=s',
			  'checksum_file|c=s',
			  'buffersize|b=s',
			  'table|t=s',
			  'log|l=s',
			  'debug=s',
			  'help|h') || pod2usage();

my $logfile = $options{'log'} || Coati::Logger::get_default_logfilename();
my $logger = new Coati::Logger('LOG_FILE'=>$logfile,
			       'LOG_LEVEL'=>$options{'debug'});
$logger = Coati::Logger::get_logger();

my %infhs;
my %outfhs;
my %outbuffer;
$options{'buffersize'}=100000000 if(!$options{'buffer_size'});
if(! $options{'bcp_extension'}){
    $logger->logdie("Must specify extension for bcp files with --bcp_extension");
}
if(! -d $options{'output_dir'}){
    $logger->logdie("Must specify valid output dir with --output_dir. User specified $options{'output_dir'}");
}
if(-d $options{'bcp_dir'}){
    open CHECKSUMS,"$options{'checksum_file'}" or $logger->logdie("Can't file file $options{'checksum_file'}");
    
    #preopen all file handles for bcp output files
    my @bcpfiles = glob $options{'bcp_dir'}.'/*.'.$options{'bcp_extension'};
    foreach my $bcpfile (@bcpfiles){
	my $bcpfilebasename= basename($bcpfile,".$options{'bcp_extension'}");
	if(!$options{'table'} || ($options{'table'} eq $bcpfilebasename)){
	    open $infhs{$bcpfilebasename},"<","$bcpfile" or $logger->logdie("Can't open bcp file $bcpfile");
	    open $outfhs{$bcpfilebasename},"+>","$options{'output_dir'}/$bcpfilebasename.$options{'bcp_extension'}" or $logger->logdie("Can't open bcp file $options{'output_dir'}/$bcpfilebasename.$options{'bcp_extension'}");
	    my @stats = stat($bcpfile);
	    $outbuffer{$bcpfilebasename}->{'offset'} = -1*$options{'buffersize'};
	    $outbuffer{$bcpfilebasename}->{'buffer'} = undef;
	    $outbuffer{$bcpfilebasename}->{'filesize'} = $stats[7];
	    $outbuffer{$bcpfilebasename}->{'lastbuffersize'} = $options{'buffersize'};
	}
    }

    my $count=0;
    while (my $line = <CHECKSUMS>){
	    chomp $line;
	    my(@elts) = split(/\s+/,$line);
	    
	    #seek($outfhs{$elts[0]}, $elts[3], 0);
	    if($elts[1]>=($outbuffer{$elts[0]}->{'offset'}+$outbuffer{$elts[0]}->{'lastbuffersize'})){
		#flush last buffer
		if(length($outbuffer{$elts[0]}->{'buffer'})){
		    print "flushing buffer for $elts[0] w/ offset $outbuffer{$elts[0]}->{'offset'}\n";
		    print {$outfhs{$elts[0]}} "$outbuffer{$elts[0]}->{'buffer'}";
		    #in case we need to strip leading zeros
		    #seek($outfhs{$elts[0]}, $outbuffer{$elts[0]}->{'offset'}, 0);
		    #foreach my $line (split(/\n/,$outbuffer{$elts[0]}->{'buffer'})){
		    #	$line =~ s/([^|\0|\?])([0-9]{32})/$1.&trim($2)/ge;
		    #	print {$outfhs{$elts[0]}} $line,"\n";
		    #}
		    #print {$outfhs{$elts[0]}} "$outbuffer{$elts[0]}->{'buffer'}";
		}
		#read next buffer
		print "reading next buffer for $elts[0] starting at ",$outbuffer{$elts[0]}->{'offset'}+$outbuffer{$elts[0]}->{'lastbuffersize'},"\n";
		my $seekpos = $outbuffer{$elts[0]}->{'offset'}+$outbuffer{$elts[0]}->{'lastbuffersize'};
		if($seekpos<$outbuffer{$elts[0]}->{'filesize'}){
		    #align buffer to line boundary by pulling up to next newline
		    seek($infhs{$elts[0]},$seekpos+$options{'buffersize'}, 0);
		    my $addlbuffer=0;
		    my $nextline= readline $infhs{$elts[0]};
		    if(tell $infhs{$elts[0]} < $outbuffer{$elts[0]}->{'filesize'}){
			$addlbuffer = (tell $infhs{$elts[0]}) - ($seekpos+$options{'buffersize'});
		    }
		    seek($infhs{$elts[0]},$seekpos, 0);
		    print "Setting addlbuffer for aligning on line boundaries $addlbuffer\n";
		    
		    read($infhs{$elts[0]},$outbuffer{$elts[0]}->{'buffer'},$options{'buffersize'}+$addlbuffer);
		    		    
		    $outbuffer{$elts[0]}->{'offset'}+=$outbuffer{$elts[0]}->{'lastbuffersize'};
		    $outbuffer{$elts[0]}->{'lastbuffersize'} = $options{'buffersize'}+$addlbuffer;
		    print "set offset pointer to $outbuffer{$elts[0]}->{'offset'} with current buffer $outbuffer{$elts[0]}->{'lastbuffersize'} and file size $outbuffer{$elts[0]}->{'filesize'}\n";
		}
		else{
		    $logger->logdie("Attempt to seek past end of file $elts[0]");
		}
	    }
	    substr($outbuffer{$elts[0]}->{'buffer'},$elts[1]-$outbuffer{$elts[0]}->{'offset'},32) = sprintf("%032d", $elts[2],32);
	}
    
    close CHECKSUMS;


    foreach my $table (keys %outfhs){
	if(length($outbuffer{$table}->{'buffer'})){
	    print "flushing buffer offset $outbuffer{$table}->{'offset'}\n";
	    print {$outfhs{$table}} "$outbuffer{$table}->{'buffer'}";
	    $outbuffer{$table}->{'offset'}+=$outbuffer{$table}->{'lastbuffersize'};
	}
	if($outbuffer{$table}->{'offset'}<$outbuffer{$table}->{'filesize'}){
	    seek ($infhs{$table},$outbuffer{$table}->{'offset'},0);
	    while(my $line=<$infhs{$table}>){
		print {$outfhs{$table}} $line;
	    }
	}
	close $outfhs{$table};
    }
}
else{
    $logger->logdie("Can't find bcp directory $options{'bcp_dir'}");
}

sub trim{
    my $str=shift;s/^0*//;
    $str =~ s/^0*(\d+)/$1/;
    return $str;
}

