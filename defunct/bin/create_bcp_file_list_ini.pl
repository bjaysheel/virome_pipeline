#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
# $Id: create_bcp_file_list_ini.pl 3145 2006-12-07 16:42:59Z angiuoli $


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

my ($log4perl, $debug_level, $dupdir, $help, $outdir, $man, $table, $skip, $tablegrouplist, $extension);

my $results = GetOptions (
			  'dupdir|f=s'         => \$dupdir,
			  'log4perl|l=s'        => \$log4perl,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'outdir|o=s'          => \$outdir,
			  'man|m'               => \$man,
			  'table|t=s'           => \$table,
			  'skip|s=s'            => \$skip,
			  'tablegrouplist|s=s'  => \$tablegrouplist,
			  'extension|e=s'       => \$extension
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

if (!defined($extension)){
    $extension = 'out';
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
my $execstring = "find $dupdir -name \"*.$extension\" -type f";
$logger->debug("execstring '$execstring'") if $logger->is_debug();
my @bcpfiles = qx{$execstring};

chomp @bcpfiles;


# strip trailing forward slash
$dupdir =~ s/\/+$//;

my $key_to_directory_lookup = {};
my $directory_to_key_lookup = {};
my $bcp_lookup = {};
my $dirctr=0;


foreach my $bfile ( @bcpfiles ){

    my $bcpfilename = basename($bfile);
    # e.g. $table = analysis.out
    
    my $table = $bcpfilename;
    # e.g. $table = analysis.out

    $table =~ s/\.$extension\s*//;
    # strip the .out extension to get accurate table name


    if (exists $qtabhash->{$table}){

	my $dirname = dirname($bfile);
	my $instancedir;
	    
#	if ($dirname =~ /$dupdir\/(\S+\/\S+)/){
	if ($dirname =~ /$dupdir\/(\S+)/){
	    $instancedir = $1;
	    
	    my $dirkey = &store_instance_directory($key_to_directory_lookup, $directory_to_key_lookup, $instancedir, \$dirctr);
	    # e.g. $direkey = d1
	    
	    &store_bcp_instance_file($bcp_lookup, $dirkey, $table, $dirname);
	    


	}
	else {
	    $logger->logdie("Could not extract instance directory from dirname '$dirname' given dupdir '$dupdir'");
	}
    }
    else{
	$logger->logdie("table '$table' is not a qualified chado table for bcp file '$bfile'");
    }
}

&create_output_ini_file($dupdir);

&create_directory_ini_section($key_to_directory_lookup, $dupdir);

&create_bcpfiles_ini_section($bcp_lookup, $extension);

&create_bcp_instance_ini_section($bcp_lookup, $extension);


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



#------------------------------------------------------
# store_instance_directory()
#
#------------------------------------------------------
sub store_instance_directory {


    my ($key_to_directory_lookup, $directory_to_key_lookup, $instancedir, $dirctr) = @_;

    my $dirkey;

    if ((exists $directory_to_key_lookup->{$instancedir}) && (defined($directory_to_key_lookup->{$instancedir}))){
	#
	# Already stored in the lookup.  Do nothing.
	#
	$dirkey = $directory_to_key_lookup->{$instancedir};
    }
    else{
	#
	# Create a new directory key and store value in lookups
	#
	$dirkey = "d" . $$dirctr++;

	$key_to_directory_lookup->{$dirkey} = $instancedir;
	$directory_to_key_lookup->{$instancedir} = $dirkey;

    }

    return $dirkey;
}


#------------------------------------------------------
# store_bcp_instance_file()
#
#------------------------------------------------------
sub store_bcp_instance_file {


    my ($bcp_lookup, $dirkey, $table, $dirname) = @_;

    if ((exists $bcp_lookup->{$table}->{$dirkey}) && (defined($bcp_lookup->{$table}->{$dirkey}))){
	#
	# Already stored in the lookup.  Problem.  There should only be one table BCP file
	# in this instance directory!
	#
	$logger->logdie("BCP file for table '$table' already exists in directory '$dirname'");
    }
    else{
	#
	# Store this BCP instance file in the lookup
	#
	$bcp_lookup->{$table}->{$dirkey} = 1;
    }
}

sub create_directory_ini_section {

    my ($key_to_directory_lookup, $dupdir) = @_;

    print INIFILE "\n[directories]\ndd=$dupdir\n";

    foreach my $key (keys %{$key_to_directory_lookup} ) {

	my $directory = $key_to_directory_lookup->{$key};

	print INIFILE "$key=/$directory\n";

    }

}

sub create_bcp_instance_ini_section {

    my ($bcp_lookup, $extension) = @_;

    foreach my $table (sort keys %{$bcp_lookup} ){ 

	print INIFILE "\n[$table.$extension]\n";

	foreach my $instancedir (sort keys %{$bcp_lookup->{$table}} ) {

	    print INIFILE "$instancedir=1\n";

	}
    }
}

sub create_bcpfiles_ini_section {

    my ($bcp_lookup, $extension) = @_;

    print INIFILE "\n[bcpfiles]\n";
    
    foreach my $table (sort keys %{$bcp_lookup} ){ 

	print INIFILE "$table.$extension=1\n";
    }
}


sub create_output_ini_file {

    my ($dupdir) = @_;


    
    my $bcpfilelist = $dupdir . '/bcp.file.list.ini';
    
    if (-e $bcpfilelist){
	my $bakfile = $dupdir . '/bcp.file.list.ini.bak';
 	rename($bcpfilelist, $bakfile);
 	$logger->info("Renaming '$bcpfilelist' '$bakfile'");
    }
    
    open (INIFILE, ">$bcpfilelist") or $logger->logdie("Could not open file '$bcpfilelist': $!");
    
}
