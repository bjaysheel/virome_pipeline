#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
# $Id: create_table_group_file_list.pl 3145 2006-12-07 16:42:59Z angiuoli $


=head1 NAME

create_table_group_file_list.pl - Creates a file which contains list of all table BCP .out files for a given group (e.g. all feature.out files)

=head1 SYNOPSIS

USAGE:  create_table_group_file_list.pl -f dupdir [-l log4perl] [-d debug_level] [-g tablegrouplist] [-h] [-m] [-o outdir] [-s skip] [-t table]

=head1 OPTIONS

=over 8
 
=item B<--dupdir,-f>
    
    Directory containing all input directories containing tab delimited out files to be scanned for duplicate identifiers

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--tablegrouplist,-f>

    Optional: Output list file name (which will contain the listing of all table BCP .out files for a given group)

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--outdir,-o>

    Optional: Output directory for the default group file list.  Default is current directory

=item B<--skip,-s>

    Optional: Do not run this script, simply exit(0). Default is --skip=0 (do not skip)

=item B<--table,-t>

    Optional: table files to be processed e.g. feature.out or db.out.  Default is all of the following analysis.out, feature_cvterm.out, feature.out, db.out

=item B<--help,-h>

    Print this help

=back

=head1 DESCRIPTION

    create_table_group_file_list.pl -  Creates a file which contains list of all table BCP .out files for a given group (e.g. all feature.out files)

    Sample output files: feature.out, db.out


    Assumptions:

    1. User has appropriate permissions (to execute script, access chado database, write to output directory).
    2. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./create_table_group_file_list.pl -f /usr/local/scratch/directory -l my.log -o /tmp/outdir
    ./create_table_group_file_list.pl -f /usr/local/scratch/directory -l my.log -o /tmp/outdir -t feature.out


=cut



use strict;

use Coati::Logger;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Data::Dumper;
use File::Copy;
use File::Basename;

my ($log4perl, $debug_level, $dupdir, $help, $outdir, $man, $table, $skip, $tablegrouplist);

my $results = GetOptions (
			  'dupdir|f=s'         => \$dupdir,
			  'log4perl|l=s'        => \$log4perl,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'outdir|o=s'          => \$outdir,
			  'man|m'               => \$man,
			  'table|t=s'           => \$table,
			  'skip|s=s'            => \$skip,
			  'tablegrouplist|s=s'  => \$tablegrouplist
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("dupdir  was not defined\n")   if (!$dupdir);

&print_usage if(!$dupdir);


$log4perl = "/tmp/create_table_group_file_list.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

if (!defined($skip)){
    $skip = 0;
    $logger->debug("was not defined, therefore set to '$skip'") if $logger->is_debug;
}
if ( (defined($skip)) and ($skip == 1)) {
    $logger->info("skip parameter was specified, therefore will not run $0");
    exit(0);
}


#
# Default outdir is current working directory
#
if (!defined($outdir)){
    $outdir = $dupdir;
    $logger->debug("outdir was set to '$outdir'") if $logger->is_debug();

}

#
# This is the COMMIT_ORDER Prism environment variable
#
my $qualifiedtablelist = 'tableinfo,project,contact,db,cv,dbxref,cvterm,dbxrefprop,cvtermprop,author,pub,synonym,pubprop,pub_relationship,pub_dbxref,pub_author,organism,organismprop,organism_dbxref,cvtermpath,cvtermsynonym,cvterm_relationship,cvterm_dbxref,feature,featureprop,feature_pub,featureprop_pub,feature_synonym,feature_cvterm,feature_cvtermprop,feature_dbxref,featureloc,feature_relationship,feature_relationship_pub,feature_relationshipprop,feature_relprop_pub,analysis,analysisprop,analysisfeature';
my @qualtablist = split(/,/, $qualifiedtablelist);
my $qtabhash = {};
foreach my $qtab (@qualtablist) {
    $qtabhash->{$qtab} = $qtab;
}

#
# Listing of all BCP .out file types to process for duplicate lists
#

my @tablelist;
if (defined($table)){
    if (exists $qtabhash->{$table}){
	push(@tablelist, $table);
    }
    else{
	$logger->logdie("Not a valid table '$table'");
    }

}
else{

    push(@tablelist, @qualtablist);
    $logger->debug("table was not defined, therefore will process the following table files @tablelist") if $logger->is_debug;
}

#
# Get all table.out files in the specified dupdir
#
my $execstring = "find $dupdir -name \"*.out\" -type f";
$logger->debug("execstring '$execstring'") if $logger->is_debug();
my @bcpfiles = qx{$execstring};

chomp @bcpfiles;

my $filehash = {};

foreach my $bfile ( @bcpfiles ){

    my $basename = basename($bfile);
    my $table = $basename;
    $table =~ s/\.out\s*//;

    if (exists $qtabhash->{$table}){
	
	push (@{$filehash->{$table}}, $bfile);
	
    }
    else{
	$logger->logdie("table '$table' is not a qualified chado table for bcp file '$bfile'");
    }
}

foreach my $tabgrp ( @qualtablist ){


    my $tablegrouplist = $dupdir . '/' . $tabgrp . '.tablegroup.list';

    if (-e $tablegrouplist){
	my $bakfile = $dupdir . '/' . $table . '.tablegroup.list.bak';
	rename($tablegrouplist, $bakfile);
	$logger->info("Renaming '$tablegrouplist' '$bakfile'");
    }

    open (GRPFILE, ">$tablegrouplist") or $logger->logdie("Could not open file '$tablegrouplist': $!");
    foreach my $file (@{$filehash->{$tabgrp}}){
	print GRPFILE $file . "\n";
    }
}





#--------------------------------------------------------------------------------------------------
#
#                    END OF MAIN -- SUBROUTINES FOLLOW
#
#--------------------------------------------------------------------------------------------------




#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -f dupdir [-l log4perl] [-d debug_level] [-g tablegrouplist] [-h] [-m] [-o outdir] [-s skip] [-t table]\n".
    "  -f|--dupdir              = Directory containing all input groups\n".
    "  -l|--log4perl            = Optional - Log4perl log file (default: /tmp/create_table_group_file_list.pl.log)\n".
    "  -m|--man                 = Display pod2usage pages for this utility\n".
    "  -h|--help                = Display pod2usage help screen.\n".
    "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level (default level is 0)\n".
    "  -g|--tablegrouplist      = Optional - file containing list of all table group BCP .out files (e.g. all feature.out files)\n".
    "  -o|--outdir              = Optional - Output directory for tab delimited out files (default is current directory)\n".
    "  -s|--skip                = Optional - Do not run this script, simply exit(0)\n".
    "  -t|--table               = Optional - table\n";
    exit 1;

}
