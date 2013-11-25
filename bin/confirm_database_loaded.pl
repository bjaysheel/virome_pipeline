#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#-----------------------------------------------------------------------
# program:     confirm_database_loaded.pl
# author:      Jay Sundaram
# date:        2003/05/09
# modification 2004-04-16 
#
#-------------------------------------------------------------------------

=head1 NAME

    confirm_database_loaded.pl - Retrieves the row counts from computational analysis module tables associated to specified analysis.analysis_id(s).

=head1 SYNOPSIS

USAGE:  get_analysis_counts.pl -f outfiledir -g loadlog [-l log4perl] -o outdir [-c confirm] [-d debug_level] [-h] [-m] [-M module] 

=head1 OPTIONS

=over 8

=item B<--confirm,-c>

    Optional - print confirmation file either LOAD_FAILED or LOAD_SUCCESSFUL (-c=1).  Default is not print confirmation (-c=0)

=item B<--outfiledir,-f>

    Directory which contains the BCP .out files

=item B<--loadlog,-g>

    loadSybaseChadoTables.pl log file

=item B<--help,-h>

    Print this help

=item B<--man,-m>

    Display man pages for this script

=item B<--module,-M>

    Optional - Chado module.  Default is companalysis

=item B<--outdir,-o>

    Optional - Output directory to optionally write the confirmation flag.  Default is current working directory

=item B<--log4perl,-l>

    Optional - Log4perl output file name.  Default is /tmp/confirm_database_loaded.pl.log

=back

=head1 DESCRIPTION

    confirm_database_loaded.pl - Retrieves the row counts from computational analysis module tables associated to specified analysis.analysis_id(s).


=cut


use strict;

use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Config::IniFiles;
use constant ROWCOUNT => 3000;

my @comp_table_list = (
		       'analysis',
		       'analysisfeature',
		       'analysisprop',
		       'feature',
		       'featureprop',
		       'featureloc',
		       );

my @seq_table_list = (
		      'db',
		      'dbxref',
		      'featureloc',
		      'feature',
		      'featureprop',
		      'feature_relationship',
		      'feature_dbxref',
		      'feature_cvterm',
		      'organism',
		      'organism_dbxref',		      
		      );


#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($help, $log4perl, $man, $debug_level, $outdir, $outfiledir, $loadlog, $confirm, $module);

my $results = GetOptions (
			  'outdir|o=s'           => \$outdir,
			  'outfiledir|f=s'       => \$outfiledir,
			  'loadlog|g=s'          => \$loadlog,
			  'log4perl|l=s'         => \$log4perl,
			  'confirm|c=s'          => \$confirm,
			  'debug_level|d'        => \$debug_level,
			  'help|h'               => \$help,
			  'man|m'                => \$man,
			  'module|M=s'           => \$module,
			  );



pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("loadlog was not defined\n")       if (!$loadlog);
print STDERR ("outfiledir was not defined\n")       if (!$outfiledir);

die ("confirm '$confirm' must be either 0 or 1\n") if (($confirm !~ /^0|1$/) and (defined($confirm)));

$confirm = undef if ($confirm == 0);

&print_usage if(!$outfiledir or !$loadlog);


#
# Verify outdir
#
$outdir = "." if (!$outdir);
$outdir =~ s/\/+$//g; # strip all trailing forward slashes
if (!-d $outdir){
    print STDERR "\n$outdir is not a directory\n\n";
    &print_usage();
}
if (!-w $outdir){
    print STDERR "\n$outdir does not have write permissions\n\n";
    &print_usage();
}

#
# Verify outfiledir
#
$outfiledir = "." if (!$outfiledir);
$outfiledir =~ s/\/+$//g; # strip all trailing forward slashes
if (!-d $outfiledir){
    print STDERR "\n$outfiledir is not a directory\n\n";
    &print_usage();
}

if (!-r $outfiledir){
    print STDERR "\n$outfiledir does not have read permissions\n\n";
    &print_usage();
}

#
# Verify loadlog
#
if (!-e $loadlog){
    print STDERR "\n$loadlog does not exist\n\n";
    &print_usage();
}
if (!-r $loadlog){
    print STDERR "\n$loadlog does not have read permissions\n\n";
    &print_usage();
}



#
# initialize the logger
#
$log4perl = "/tmp/confirm_database_loaded.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

if (!defined($module)){
    $module = 'companalysis';
    $logger->debug("module was set to '$module'") if $logger->is_debug;
}



#
# Retrieve counts from the load.log files
#
my $bcp_counts = &retrieve_counts_from_loadlog($loadlog);


#
# Retrieve the counts from the BCP files
#
my $outfile_counts;



$outfile_counts = &retrieve_counts_from_outfiles($outfiledir, \@comp_table_list) if ($module eq 'companalysis');
$outfile_counts = &retrieve_counts_from_outfiles($outfiledir, \@seq_table_list) if ($module eq 'sequence');



#
# Perform the comparisons
#
my $errorcount=0;

foreach my $table (sort keys %$outfile_counts){
    $logger->logdie("table was not defined") if (!defined($table));

    $logger->info("Verifying row counts for table: $table");

    my $out = $outfile_counts->{$table} if ((exists $outfile_counts->{$table}) and (defined($outfile_counts->{$table})));
    $logger->logdie("out was not defined") if (!defined($out));

    my $bcp = $bcp_counts->{$table} if ((exists $bcp_counts->{$table}) and (defined($bcp_counts->{$table})));
    if (!defined($bcp)){
	$logger->warn("bcp was not defined for table:$table\nDealing with empty pairwise BSML search encoding document") if ($module eq 'companalysis');
	next;
    }



    if (($table eq 'feature') and ($module eq 'sequence')){
	$logger->info("Could not compare the feature.out file against the bcp nor the tables counts because of newline encodings in the md5checksum field: feature.residues");
	next;
    }

    #
    # Compare the .out file against the bcp file
    #
    if ($out == $bcp){
	$logger->info(".out and bcp are $out");
    }
    else{
	$logger->error("For table: $table .out is $out and bcp is $bcp");
	$errorcount++;
    }

}

if ($errorcount>1){
    $logger->error("Discrepancy detected. Please review the log4perl file: $log4perl"); 
    if ($confirm){
	my $file = $outdir . "/LOAD_FAILED";
	`touch $file`;
    }
}
else{
    if ($confirm){
	my $file = $outdir . "/LOAD_SUCCESSFUL";
	`touch $file`;
    }
}

#-------------------------------------------------------------------------------------------------------------------------
#
#                        END OF MAIN -- SUBROUTINES FOLLOW
#
#-------------------------------------------------------------------------------------------------------------------------

#-------------------------------------------------------------------
# retrieve_counts_from_loadlog()
#
#-------------------------------------------------------------------
sub retrieve_counts_from_loadlog {

    $logger->debug("Entered retrieve_counts_from_loadlog") if $logger->is_debug();

    my $file = shift;
    $logger->logdie("file was not defined") if (!defined($file));


    my $contents = &get_file_contents(\$file);
    $logger->logdie("contents was not defined") if (!defined($contents));

    my $ctr=0;
    my $table_stats = {};
    my $table;

    
    #----------------------------------------------------------------
    # Parse all .out files
    #
    #----------------------------------------------------------------
    foreach my $line (@$contents){
	$logger->logdie("line was not defined") if (!defined($line));

	if (($line !~ /BCPing table:/)){
	    $ctr++;
	}
	if ($line !~ /rows copied/){
	    $ctr++;
	}
	if ($line =~ /BCPing table:\s+(.*)/){
	    $table = $1;
	    $logger->logdie("table was not defined") if (!defined($table));
	}
	if ($line =~ /([\d]+)[\s]+rows copied\..*$/){
	    my $count = $1;
	    $logger->logdie("count was not defined") if (!defined($count));
	    $table_stats->{$table} = $count;
	}
    }

    $table_stats->{'featureprop'} = 0 if (!defined($table_stats->{'featureprop'}));;
    $table_stats->{'analysisprop'} = 0 if (!defined($table_stats->{'analysisprop'}));;

    $table_stats->{'feature'}              = 0 if (!defined($table_stats->{'feature'}));;
    $table_stats->{'featureloc'}           = 0 if (!defined($table_stats->{'featureloc'}));;
    $table_stats->{'featureprop'}          = 0 if (!defined($table_stats->{'featureprop'}));;
    $table_stats->{'feature_relationship'} = 0 if (!defined($table_stats->{'feature_relationship'}));;
    $table_stats->{'feature_dbxref'}       = 0 if (!defined($table_stats->{'feature_dbxref'}));;
    $table_stats->{'feature_cvterm'}       = 0 if (!defined($table_stats->{'feature_cvterm'}));;
    $table_stats->{'db'}                   = 0 if (!defined($table_stats->{'db'}));;
    $table_stats->{'dbxref'}               = 0 if (!defined($table_stats->{'dbxref'}));;
    $table_stats->{'organism'}             = 0 if (!defined($table_stats->{'organism'}));;
    $table_stats->{'organism_dbxref'}      = 0 if (!defined($table_stats->{'organism_dbxref'}));;

    return $table_stats;

}#end sub retrieve_counts_from_loadlog()

#-------------------------------------------------------------------
# get_file_contents()
#
#-------------------------------------------------------------------
sub get_file_contents {

    $logger->debug("Entered get_file_contents") if $logger->is_debug();

    my $file = shift;
    $logger->logdie("file was not defined") if (!defined($file));

    if (&is_file_status_ok($file)){

	open (IN_FILE, "<$$file") || $logger->logdie("Could not open file: $$file for input");
	my @contents = <IN_FILE>;
	chomp @contents;
	
	return \@contents;

    }
    else{
	$logger->logdie("file $file does not have appropriate permissions");
    }
    
}#end sub get_contents()


#-------------------------------------------------------------------
# is_file_status_ok()
#
#-------------------------------------------------------------------
sub is_file_status_ok {

    my $file = shift;
    my $fatal_flag=0;
    if (!defined($file)){
	$logger->fatal("file was not defined");
	$fatal_flag++;
    }
    if (!-e $$file){
	$logger->fatal("$$file does not exist");
	$fatal_flag++;
    }
    if (!-r $$file){
	$logger->fatal("$$file does not have read permissions");
	$fatal_flag++;
    }

    if ($fatal_flag>0){
	return 0;
    }
    else{
	return 1;
    }

}#end sub is_file_status_ok()


#-------------------------------------------------------------------
# retrieve_counts_from_outfiles()
#
#-------------------------------------------------------------------
sub retrieve_counts_from_outfiles {

    $logger->debug("Entered retrieve_counts_from_outfiles") if $logger->is_debug();
    my ($dir, $comp_table_list) = @_;
    
    $logger->logdie("dir was not defined") if (!defined($dir));
    $logger->logdie("comp_table_list was not defined") if (!defined($comp_table_list));

    my $tablehash = {};

    foreach my $table (@$comp_table_list){
	$logger->logdie("table was not defined") if (!defined($table));

	my $exec = "wc -l " . $dir . "/" . $table . ".out";
	my $ret = &execute(\$exec);
	my $count;

#	print "$table ret>>" . $ret ."<<\n";

	if ($ret =~ /^\s*(\d+)/){
	    $count = $1;
	}
	elsif ($ret =~ /\s*/){
	    $count = 0;	    
	}
	else{
	    $logger->logdie("Could not parse $ret");
	}

#	$logger->logdie("count was not defined") if (!defined($count));
	$tablehash->{$table} = $count;# if ((defined($count)) and ($count =~ /^\d+$/));
    }

     return $tablehash;

}#end sub retrieve_counts_from_outfiles()


#-----------------------------------------------------------------
# execute()
#
#-----------------------------------------------------------------
sub execute {
    
    my $string = shift;
    $logger->logdie("string was not defined") if (!defined($string));

    $logger->info("$$string");
    my $ret = `$$string`;
    chomp $ret;
#    print "ret:$ret\n";
    return $ret;
    
}#end sub execute()


#-----------------------------------------------------------------
# is_execution_string_safe()
#
#-----------------------------------------------------------------
sub is_execution_string_safe {

    my $string = shift;
    if (!defined($string)){
	$logger->logdie("string was not defined");
    }
    if ($$string =~ /rm/){
	$logger->fatal("string was not safe: $$string");
	return 0;
    }
    return 1;

}#end sub is_execution_string_safe()



#----------------------------------------------------------------
# retrieve_prism_object()
#
#
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database ) = @_;

    $logger->debug("Instantiating Prism object") if ($logger->is_debug());
    

    my $prism = new Prism( 
			   user             => $username,
			   password         => $password,
			   db               => $database,
			   );
    
    $logger->fatal("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    

    return $prism;


}#end sub retrieve_prism_object()




#-----------------------------------------------------------------
# print_usage()
#
#-----------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -U username -P password -D database -S server -f outfiledir -g loadlog [-l log4perl] -o outdir -M module [-a analysis_type] [-c confirm] [-d debug_level] [-h] [-i organism] [-m]\n";
    print STDERR "  -U|--username            = Database login username\n";
    print STDERR "  -P|--password            = Database login password\n";
    print STDERR "  -S|--server              = Server name\n";
    print STDERR "  -D|--database            = Database\n";
    print STDERR "  -M|--module              = Optional - sequence or companalysis\n";
    print STDERR "  -g|--loadlog             = loadSybaseChadoTables.pl log4perl log file\n";
    print STDERR "  -f|--outfiledir          = outfiledir\n";
    print STDERR "  -l|--log4perl            = Optional - Log4perl log file. (default is /tmp/confirm_database_loaded.pl.log)\n"; 
    print STDERR "  -o|--outdir              = outdir\n";
    print STDERR "  -a|--analysis_type       = Optional - 1=pairwise alignment 2=multiple alignment 3=SNP 4=custom search 5=subassembly\n";
    print STDERR "  -c|--confirm             = Optional - confirmation file \"LOAD_SUCCESSFUL\" will be written to outdir if comparisons are good(-c=1).  Default is no confirmation(-c=0)\n";
    print STDERR "  -d|--debug_level         = Optional - Coati log4perl logging level\n";
    print STDERR "  -h|--help                = Optional - This help message\n";
    print STDERR "  -i|--organism            = Optional - legacy organism database name\n";
    print STDERR "  -m|--man                 = Optional - Display man pages for this script\n";
    exit 1;

}


