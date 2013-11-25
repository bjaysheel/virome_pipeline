#!/usr/local/bin/perl
#-----------------------------------------------------------------------
# $Id: chado_statistics.pl 3141 2006-12-07 16:41:07Z angiuoli $
# program:   chado_statistics.pl
# author:    Jay Sundaram
# date:      2005/05/16
# 
# purpose:   Retrieve chado database statistics
#
#
#-------------------------------------------------------------------------


=head1 NAME

chado_statistics.pl - Retrieve chado database statistics

=head1 SYNOPSIS

USAGE:  chado_statistics.pl [-D database] -P password -U username [-d debug_level] [-h] [-l log4perl] [-m] [-o outdir] [-p] [-s html] [-y cache_dir]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--database,-D>
    
    Optional - Target chado database. (Default 'common')

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--pparse,-p>

    Optional - turn off parallel load support via global serial identifier replacement (default is ON)

=item B<--html,-s>

    Optional - If specified this script will output the statistics in HTML table format to specified file (Default output file name is /tmp/chado_statistics.html

=item B<--cache_dir,-y>

    Optional - Query caching directory to write cache files (default is ENV{DBCACHE_DIR})

=item B<--help,-h>

    Print this help

=back

=head1 DESCRIPTION

    chado_statistics.pl - Report chado database statistics

    Assumptions:
    1. The BSML pairwise alignment encoding should validate against the XML schema:.
    2. User has appropriate permissions (to execute script, access chado database, write to output directory).
    3. Target chado database already contains all reference features (necessary to build feature and organism lookups) Review and execute db2bsml.pl if required.
    4. Target chado database contains the necessary controlled vocabulary terms: "match" etc.
    5. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./chado_statistics.pl -U access -P access 


=cut


use strict;

use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Coati::Logger;
use Config::IniFiles;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($username, $password, $database, $debug_level, $help, $log4perl, $man, $pparse, $cache_dir, $html, $file);


my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'database|D=s'        => \$database,
			  'log4perl|l=s'        => \$log4perl,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'pparse|p'            => \$pparse,
			  'cache_dir|y=s'       => \$cache_dir,
			  'html|s=s'            => \$html,
			  'file|f=s'            => \$file
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("username was not defined\n")   if (!$username); 
print STDERR ("password was not defined\n")   if (!$password);


&print_usage if(!$username or !$password);

#
# initialize the logger
#
$log4perl = "/tmp/chado_statistics.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);



if (!defined($database)){
    $database = 'common';
    $logger->info("database was set to 'common'");
}

#
# Instantiate Prism object
#
my $prism = &retrieve_prism_object($username, $password, $database, $pparse);


my $chadodbs = [];

if ($database eq 'common'){
    print "Retrieving data for all chado database!\n";
    $chadodbs = $prism->chado_databases();
}
else{
    print "Retrieving data for chado database '$database' only!\n";
    $chadodbs->[0][0] = $database;
}

my $data = {};

foreach my $array ( sort @{$chadodbs}) {

    foreach my $database (@{$array}){

	if (($database eq 'rice') or ($database eq 'reseq')){
	    print "Skipping database '$database'\n";
	    next;
	} 

	print "Retrieving data for database '$database'\n";

	my $ret = $prism->organism_count($database);
	$logger->logdie() if (!defined($ret));
	$data->{$database}->{'organism_count'} = $ret->[0][0];




	$ret = $prism->residue_sum($database);
	$logger->logdie() if (!defined($ret));       
	$data->{$database}->{'mbp'} = $ret->[0][0];


	$ret = $prism->gene_count($database);
	$logger->logdie() if (!defined($ret));
	$data->{$database}->{'gene_count'} = $ret->[0][0];


	$ret = $prism->feature_count($database);
	$logger->logdie() if (!defined($ret));
	$data->{$database}->{'feature_count'} = $ret->[0][0];


	$ret = $prism->analysisfeature_count($database);
	$logger->logdie() if (!defined($ret));
	$data->{$database}->{'analysisfeature_count'} = $ret->[0][0];


	$ret = $prism->featureloc_count($database);
	$logger->logdie() if (!defined($ret));
	$data->{$database}->{'featureloc_count'} = $ret->[0][0];

	
	$ret = $prism->featureprop_count($database);
	$logger->logdie() if (!defined($ret));
	$data->{$database}->{'featureprop_count'} = $ret->[0][0];

    }

}


if (!defined($html)){
    $html = '/tmp/chado_statistics.html';
    $logger->info("html was set to '$html'");
}


if (!defined($html)){
    $html = '/tmp/chado_statistics.html';
    $logger->info("Output file was set to '$html'");
}

if (-e $html){
    my $bakfile = $html. '.bak';
    rename($html, $bakfile);
    $logger->info("Moved file '$html' to '$bakfile'");
}

open (OUTFILE, ">$html") or $logger->logdie("Could not open '$html' in write mode: $!");

my $title  = "Chado Comparative Genomics Databases Statistics";
my $header = $title;
&display_header($title, $header);
&display_body($data);

close OUTFILE;


my $datfile = '/tmp/chado_statistics.dat';
if (-e $datfile){
    my $bakfile = $datfile . '.bak';
    rename($datfile, $bakfile);
    $logger->info();
}

open (STDOUT, ">$datfile") or $logger->logdie("Could not open '$datfile' in write mode: $!");
&report_statistics($data);


#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#
#                                  END OF MAIN  -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------
# report_statistics()
#
#-----------------------------------------------------
sub report_statistics {

    my ($data) = @_;



foreach my $database (sort keys %{$data}){

    format top =
DB Name       organisms Mbp                genes      features      analysisfeatures   featurelocs     featureprops
---------------------------------------------------------------------------------------------------------------
.



format STDOUT = 
@<<<<<<<<<<<<<@<<<<<<<<<@<<<<<<<<<<<<<<<<<<@<<<<<<<<<<@<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<
$database, $data->{$database}->{'organism_count'}, $data->{$database}->{'mbp'}, $data->{$database}->{'gene_count'}, $data->{$database}->{'feature_count'}, $data->{$database}->{'analysisfeature_count'}, $data->{$database}->{'featureloc_count'}, $data->{$database}->{'featureprop_count'}
.

write;
}
}


#-----------------------------------------------------
# display_header()
#
#-----------------------------------------------------
sub display_header {

    my ($title, $header) = @_;

    print OUTFILE "Content-type: text/html\n\n".
	   "<html>\n".
	   "<head>\n".
	   "<title>$title</title>\n".
	   "</head>\n".
	   "<center>\n".
	   "<h4>$header</h4>\n".
	   "</center>\n";
    
}

#-----------------------------------------------------
# display_body()
#
#-----------------------------------------------------
sub display_body {

    my $data = shift;

    print OUTFILE "<body>".
    "<center><table border=1>\n";

    print OUTFILE "<tr>".
    "<th>DB name</th>".
    "<th># organisms</th>".
    "<th>Mbp</th>".
    "<th># genes</th>".
    "<th>total # features</th>".
    "<th># analysisfeatures</th>".
    "<th># featurelocs</th>".
    "<th># featureprops</th>".
    "</tr>\n";


    foreach my $database (sort keys %{$data}){

	print OUTFILE "<tr>".
	"<td>$database</td>".
	"<td>$data->{$database}->{'organism_count'}</td>".
	"<td>$data->{$database}->{'mbp'}</td>".
	"<td>$data->{$database}->{'gene_count'}</td>".
	"<td>$data->{$database}->{'feature_count'}</td>".
	"<td>$data->{$database}->{'analysisfeature_count'}</td>".
	"<td>$data->{$database}->{'featureloc_count'}</td>".
	"<td>$data->{$database}->{'featureprop_count'}</td>".
	"</tr>\n";
    


    }

    print OUTFILE "</table>".
    "</body>".
    "</html>\n";

}



#----------------------------------------------------------------
# retrieve_prism_object()
#
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database, $pparse) = @_;

    $logger->debug("Instantiating Prism object") if ($logger->is_debug());
    
    if (defined($pparse)){
	$pparse = 0;
    }
    else{
	$pparse = 1;
    }


    my $prism = new Prism(
			  user              => $username,
			  password          => $password,
			  db                => $database,
			  use_placeholders  => $pparse,
			  );
    
    $logger->logdie("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    


    return $prism;


}#end sub retrieve_prism_object()



#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -D database -P password -U username [-d debug_level] [-h] [-l log4perl] [-m] [-p] [-s html] [-y cache_dir]\n".
    "  -D|--database            = Target chado database\n".
    "  -P|--password            = Password\n".
    "  -U|--username            = Username\n".
    "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level.  Default is 0\n".
    "  -h|--help                = Optional - Display pod2usage help screen\n".
    "  -l|--log4perl            = Optional - Log4perl log file (default: /tmp/chado_statistics.pl.log)\n".
    "  -m|--man                 = Optional - Display pod2usage pages for this utility\n".
    "  -p|--pparse              = Optional - to turn off parallel load support (default is ON)\n".
    "  -s|--html                = Optional - Name of output HTML document (Default /tmp/chado_statistics.html)\n".
    "  -y|--cache_dir           = Optional - To turn on file-caching and specify directory to write cache files.  (Default no file-caching. If specified directory does not exist, default is environmental variable ENV{DBCACHE_DIR}\n";    
    exit 1;

}
