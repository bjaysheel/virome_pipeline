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
              'database|d=s',
              'database_type=s',
              'server|s=s',
              'username|u=s',
              'password|p=s',
              'checksum_file|c=s',
              'output_file|o=s',
              'report_file|r=s',
              'log|l=s',
              'debug=s',
              'help|h') || pod2usage();

my $logfile = $options{'log'} || Coati::Logger::get_default_logfilename();
my $logger = new Coati::Logger('LOG_FILE'=>$logfile,
			       'LOG_LEVEL'=>$options{'debug'});
$logger = Coati::Logger::get_logger();

## Set the PRISM env var
&setPrismEnv($options{'server'}, $options{'database_type'});

my $prism = &get_prism_object($options{'username'}, $options{'password'}, $options{'database'});

open CHECKSUMS,"$options{'checksum_file'}" or $logger->logdie("Can't file file $options{'checksum_file'}");
open OUTPUT,">$options{'output_file'}" or $logger->logdie("Can't file file $options{'output_file'}");

my $tableidmanager = new Coati::TableIDManager( 
						'max_func'=>sub {
						    my ($table,$field) = @_; 
						    my @idarray = $prism->{_backend}->getMaxId($table,$field);
						    return $idarray[0][0];
						});
my $minid_lookup = {};
my $maxid_lookup = {};
my $lastpk;
my $lastchecksum;
while(my $line=<CHECKSUMS>){
    chomp $line;
    my(@elts) = split(/\s+/,$line);
    if($lastchecksum ne $elts[0]){
	if(! exists $maxid_lookup->{$elts[2]}){
	    $maxid_lookup->{$elts[2]} = $tableidmanager->nextId($elts[2])-1;
	}
	if (! exists $minid_lookup->{$elts[2]}){
	    $minid_lookup->{$elts[2]} = $maxid_lookup->{$elts[2]} + 1;
	}

	$lastpk = ++$maxid_lookup->{$elts[2]};
    }
    elsif($elts[1] != 1){
	die "Bad checksum line encountered. Column 2 suggests same PK assigned across two tables.\n$line"
    }
    print OUTPUT "$elts[2] $elts[3] $lastpk\n";
    $lastchecksum = $elts[0];
}
close CHECKSUMS;
close OUTPUT;

&reportMinMax($minid_lookup, $maxid_lookup);

exit(0);

#------------------------------------------------------
# get_prism_object()
#
#------------------------------------------------------
sub get_prism_object {

    my ($username, $password, $database) = @_;

    my $prism = new Prism( user       => $username,
			   password   => $password,
			   db         => $database,
			   );

    return $prism;
}


#--------------------------------------------------
# setPrismEnv()
#
#--------------------------------------------------
sub setPrismEnv {

    my ($server, $vendor) = @_;

    if (!defined($server)){
	$logger->logdie("server was not defined");
    }
    if (!defined($vendor)){
	$logger->logdie("vendor was not defined");
    }
    
    if ($vendor eq 'postgresql'){
	$vendor = 'postgres';
    }

    $vendor = "Bulk" . ucfirst($vendor);
    ## We're overriding the env stored in conf/Prism.conf
    my $prismenv = "Chado:$vendor:$server";


    $ENV{PRISM} = $prismenv;
}

sub reportMinMax {

    my ($minid_lookup, $maxid_lookup) = @_;
    
    my $report_file;

    if (exists $options{'report_file'}){
	$report_file = $options{'report_file'};
    } else {
	$report_file = $options{'output_file'} . '.rpt';
    }

    open (REPORT, ">$report_file") || die $logger->logdie("Could not open report file '$report_file' in write mode:$!");

    foreach my $table (sort keys %{$minid_lookup}){

	if (!exists $maxid_lookup->{$table}){
	    $logger->logdie("table '$table' does not exist in maxid_lookup!");
	}

	my $min = $minid_lookup->{$table};
	my $max = $maxid_lookup->{$table};

	print REPORT "table '$table' min '$min' max '$max'\n";
    }

    foreach my $table (sort keys %{$maxid_lookup}){

	if (!exists $minid_lookup->{$table}){
	    $logger->logdie("table '$table' does not exist in minid_lookup!");
	}
    }

    close(REPORT);

}
