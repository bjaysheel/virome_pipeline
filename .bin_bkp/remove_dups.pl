#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
# $Id: remove_dups.pl 3145 2006-12-07 16:42:59Z angiuoli $


=head1 NAME

remove_dups.pl - Removes all lines from file if the identifier is a duplicate of an identifier in some other similar type file (designate master file)

=head1 SYNOPSIS

USAGE:  remove_dups.pl --dupdir=<value> [--log4perl=<value>] [-d debug_level] [-h] [-m] [--skip] --table=<value>

=head1 OPTIONS

=over 8
 
=item B<--dupdir>
    
    Directory containing all BCP groups containing tab delimited out files to be scanned for duplicate identifiers

=item B<--log4perl>

    Optional: log4perl log filename.  Default is /tmp/remove_dups.pl.log

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--table>

    Table file to be processed e.g. feature.out.  Acceptable inputs analysis.out, feature_cvterm.out, feature.out, db.out

=item B<--help,-h>

    Print this help

=item B<--skip>

    Optional: Do not run this script, simply exit(0). Default is --skip=0 (do not skip).

=back

=head1 DESCRIPTION

    remove_dups.pl - Removes all lines from file if the identifier is a duplicate of an identifier in some other similar type file (designate master file)

    Assumptions:

    1. User has appropriate permissions (to execute script, access chado database, write to output directory).
    2. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./remove_dups.pl --dupdir=/usr/local/scratch/directory --log4perl=my.log --table=feature.out


=cut



use strict;

use Coati::Logger;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Data::Dumper;
use Config::IniFiles;

my ($log4perl, $debug_level, $dupdir, $help, $man, $table, $skip);

my $results = GetOptions (
			  'dupdir=s'          => \$dupdir,
			  'log4perl=s'        => \$log4perl,
			  'debug_level|d=s'   => \$debug_level, 
			  'help|h'            => \$help,
			  'man|m'             => \$man,
			  'table=s'           => \$table,
			  'skip=s'            => \$skip
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("dupdir   was not defined\n")   if (!$dupdir);
print STDERR ("table    was not defined\n")   if (!$table);

&print_usage if(!$dupdir or !$table);


#
# 1. use directory name to retrieve all table.out files and all dup.table.out.list files
# Foreach file
# 2. move file.out to file.bak
# 3. open new output file.out
# Foreach duplicate list
# 4. decide whether to output line
#

my $logger = &get_logger($log4perl, $debug_level);

&is_skip($skip);

my $bcpfilelookup = &get_bcpfilelookup($dupdir);

my $tablelist = &get_qualified_chado_table_list($table);


#
# We want to produce one duplicates list for each major table (feature, db, analysis)
#
foreach my $table ( @{$tablelist} ) {

    print "Processing all BCP .out files for table '$table'\n";
    $logger->debug("Processing all BCP .out files for table '$table") if $logger->is_debug();

    #
    # Get all dup.table.out.list files
    #
    my $dupfile = $dupdir . '/dup.' . $table . '.list';

    if ((-e $dupfile) && (-r $dupfile) && ($bcpfilelookup->{'table_count'}->{$table} > 0) && (!-z $dupfile)){ 

	#
	# Continue only if:
	# 1) the duplicate file exists & has read permissions for this table AND
	# 2) there do exist .out files to be processed
	#
	my $duphash = &get_duphash($dupfile);

	&remove_duplicate_lines($bcpfilelookup, $table, $duphash, $dupdir);
	    
    }
    else{

	&what_is_wrong_with_dupfile($dupfile, $dupdir, $bcpfilelookup, $table);
    }
}



#----------------------------------------------------------------------------------------------------
#
#                         END OF MAIN -- SUBROUTINES FOLLOW
#
#----------------------------------------------------------------------------------------------------





#---------------------------------------------------
# remove_duplicate_lines()
#
#---------------------------------------------------
sub remove_duplicate_lines {

    my ($bcpfilelookup, $table, $duphash, $dupdir) = @_;

	
    my $tableout = $table . ".out";
   
    foreach my $abbreviatedbcpfile (keys %{$bcpfilelookup->{'files'}->{$tableout}}) {
	
	my $infile = &build_file_from_bcpfilelookup($bcpfilelookup, $tableout, $dupdir, $abbreviatedbcpfile);

	$logger->debug("Processing BCP file '$infile'") if $logger->is_debug;


	my $bakfile = $infile . '.remove_dups.bak';
	$logger->info("Renaming '$infile' '$bakfile'");
	rename($infile, $bakfile);

	
	$logger->info("Opening '$bakfile' for input");
	open (INFILE, "<$bakfile") or $logger->logdie("Could not open table BCP .out file '$bakfile':$!");

	$logger->info("Opening '$infile' for output");
	open (OUTFILE, ">$infile") or $logger->logdie("Could not open table BCP .out outfile '$infile':$!");


	# remove the fullpath to dupdir
	$infile =~ s/$dupdir\/*//;


	# Set BCP record terminator
	$/ = "\?\?\?\?\n";

        while (my $line = <INFILE>){

	    chomp $line;

	    my ($id) = ($line =~ /^(;;\w+;;_\d+\?\?)/);
	    if (exists $duphash->{$infile}->{$id}){
		# skip line
	    }
	    else{
		
		# print non-duplicate record to BCP file, append BCP record terminator
		print OUTFILE $line . "\?\?\?\?\n";
	    }
	}

	# Restore newline character
        $/ = "\n";
    }

}



#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0  --dupdir=<value> [-d debug_level] [-h] [--log4perl=<value>] [-m] [--skip] --table=<value>\n";
    "  --dupdir              = Directory containing all tab delimited BCP .out files to be cleansed of duplicate serial identifiers\n".
    "  -d|--debug_level      = Optional - Coati::Logger log4perl logging level (default level is 0)\n".
    "  -h|--help             = Display pod2usage help screen.\n".
    "  --log4perl            = Optional - Log4perl log file (default: /tmp/dup_list.pl.log)\n".
    "  -m|--man              = Display pod2usage pages for this utility\n".
    "  --skip                = Optional - Do not execute this script, exit(0) (Default --skip=0)\n".
    "  --table               = Table group file e.g. feature.out or db.out\n";
    exit 1;

}

	

#--------------------------------------------------------
# get_duphash()
#
#--------------------------------------------------------
sub get_duphash {

    my ($dupfile) = @_;

    my $duphash = {};


    open (DUPFILE, "<$dupfile") or $logger->logdie("Could not open dupfile '$dupfile'");
    #
    # Load the duphash. The first identifier on each line is the master identifier for that line.
    # 
    while (my $dupline = <DUPFILE>){
	    
	chomp $dupline;

	my @ar = split(/\s+/, $dupline);
	    
	for (my $i=1; $i < scalar(@ar); $i++) {
		
	    my ($file,$pholder) = split(/:/, $ar[$i]);
	    
	    if (!defined($file)){
		$logger->logdie("file was not defined for '$ar[$i]'");
	    }
	    if (!defined($pholder)){
		$logger->logdie("pholder was not defined for '$ar[$i]'");
	    }

	    $duphash->{$file}->{$pholder} = $ar[0];
		
	}

    }
    close DUPFILE;

    return $duphash;
}


#---------------------------------------------------
# what_is_wrong_with_dupfile()
#
#---------------------------------------------------
sub what_is_wrong_with_dupfile {

    my ($dupfile, $dupdir, $bcpfilelookup, $table) = @_;
    
    if (!-e $dupfile){
	$logger->logdie("dupfile '$dupfile' does not exist in directory '$dupdir' for table '$table'");
    }
    if (!-r $dupfile){
	$logger->logdie("dupfile '$dupfile' does not not have read permissions in directory '$dupdir' for table '$table'");
    }
    if (-z $dupfile){
	$logger->info("dupfile '$dupfile' had zero content. No records need to be deleted from any of the BCP table '$table' files in directory '$dupdir'.  Exiting...");
	exit(0);
    }
    if ($bcpfilelookup->{'table_count'}->{$table} < 1){
	$logger->info("Could not find any BCP .out files for table '$table' in directory '$dupdir'.  Exiting...");
	exit(0);
    }
}



#------------------------------------------------------
# get_bcpfilelookup()
#
#------------------------------------------------------
sub get_bcpfilelookup {

    my ($dupdir) = @_;

    my $file = $dupdir . "/bcp.file.list.ini";

    &check_file_status($file);

    my $lookup = {};

    
    my $cfg = Config::IniFiles->new( -file => "$file" );


    if ((exists $cfg->{'v'}) &&
	(defined($cfg->{'v'}))){


	if ((exists $cfg->{'v'}->{'directories'}) &&
	    (defined($cfg->{'v'}->{'directories'}))){
	    
	    $lookup->{'directories'} = $cfg->{'v'}->{'directories'};

	}
	else {
	    $logger->logdie("Did not find [directories] INI section!");
	}


	if ((exists $cfg->{'v'}->{'bcpfiles'}) &&
	    (defined($cfg->{'v'}->{'bcpfiles'}))){

	    my $bcpfilenames = $cfg->{'v'}->{'bcpfiles'};
	
	    foreach my $bcpfile (sort keys %{$bcpfilenames} ) {
		
		if ((exists $cfg->{'v'}->{$bcpfile}) &&
		    (defined($cfg->{'v'}->{$bcpfile}))){
		    
		    $lookup->{'files'}->{$bcpfile} = $cfg->{'v'}->{$bcpfile};
		    my $count = keys ( %{$cfg->{'v'}->{$bcpfile}} ) ;

		    my $table = $bcpfile;
		    $table =~ s/\.out//;

		    $lookup->{'table_count'}->{$table} = $count;
		}
		else {
		    $logger->logdie("Did not find [$bcpfile] INI section!");
		}
	    }
	}
	else {
	    $logger->logdie("Did not find [bcpfiles] INI section!");
	}
    }
    else {
	$logger->logdie("Did not find [v] INI section!");
    }

    return $lookup;
}



#--------------------------------------------------
# get_logger()
#
#--------------------------------------------------
sub get_logger {

    my ($log4perl, $debug_level) = @_;

    $log4perl = "/tmp/remove_dups.pl.log" if (!defined($log4perl));

    my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				     'LOG_LEVEL'=>$debug_level);
    

    return Coati::Logger::get_logger(__PACKAGE__);
}




#--------------------------------------------------
# is_skip()
#
#--------------------------------------------------
sub is_skip {

    my ($skip) = @_;


    if (!defined($skip)){
	$skip = 0;
	$logger->debug("was not defined, therefore set to '$skip'") if $logger->is_debug;
    }
    if ( (defined($skip)) and ($skip == 1) ){
	$logger->info("skip parameter was specified, therefore will not run delete_refs.pl");
	exit(0);
    }
}




#--------------------------------------------------
# get_qualified_chado_table_list()
#
#--------------------------------------------------
sub get_qualified_chado_table_list {

    my ($table) = @_;


    #
    # This is the COMMIT_ORDER Prism environment variable
    #
    my $qualifiedtablelist = 'project,db,cv,dbxref,cvterm,dbxrefprop,cvtermprop,pub,synonym,pubprop,pub_relationship,pub_dbxref,pubauthor,organism,organismprop,organism_dbxref,cvtermpath,cvtermsynonym,cvterm_relationship,cvterm_dbxref,feature,featureprop,feature_pub,featureprop_pub,feature_synonym,feature_cvterm,feature_cvterm_dbxref,feature_cvterm_pub,feature_cvtermprop,feature_dbxref,featureloc,feature_relationship,feature_relationship_pub,feature_relationshipprop,feature_relprop_pub,analysis,analysisprop,analysisfeature,phylotree,phylotree_pub,phylonode,phylonode_dbxref ,phylonode_pub,phylonode_organism,phylonodeprop,phylonode_relationship';

    my @qualtablist = split(/,/, $qualifiedtablelist);

    my $qtabhash = {};

    foreach my $qtab (@qualtablist) {

	$qtab =~ s/^\s*$//g; # remove all spaces

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

    return \@tablelist;
}



#------------------------------------------------------
# build_file_from_bcpfilelookup()
#
#------------------------------------------------------
sub build_file_from_bcpfilelookup {

    my ($bcpfilelookup, $tableout, $dupdir, $abbreviatedbcpfile) = @_;

    my $dir2 = $bcpfilelookup->{'directories'}->{$abbreviatedbcpfile};

    my $file = $dupdir . '/' . $dir2 . "/" . $tableout;

    return $file;
}



#------------------------------------------------------
# check_file_status()
#
#------------------------------------------------------
sub check_file_status {

    my $file = shift;

    if (!defined($file)){
	$logger->logdie("file '$file' was not defined");
    }

    if (!-e $file){
	$logger->logdie("file '$file' does not exist");
    }

    if (!-r $file){
	$logger->logdie("file '$file' does not have read permissions");
    }

    if (-z $file){
	$logger->logdie("file '$file' has zero content");
    }


}

