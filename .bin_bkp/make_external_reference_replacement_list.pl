#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
# $Id: make_external_reference_replacement_list.pl 3145 2006-12-07 16:42:59Z angiuoli $

=head1 NAME

make_external_replacement_list.pl - Creates a master repfile.list which directs replacement among children table BCP files

=head1 SYNOPSIS

USAGE:  make_external_replacement_list.pl --dupdir=<value> [--log4perl=<value>] [-d debug_level] [-h] [-m] [--skip] [--table=<value>]

=head1 OPTIONS

=over 8
 
=item B<--dupdir>
    
    File containing a listing of all input directories containing tab delimited out files to be scanned for duplicate identifiers

=item B<--log4perl>

    Optional: log4perl log filename.  Default is /tmp/make_external_replacement_list.pl.log

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--table>

    Optional -- Table file to be processed e.g. feature.out.  Acceptable inputs analysis.out, feature_cvterm.out, feature.out, db.out.  Default is all tables in COMMIT_ORDER list.

=item B<--help,-h>

    Print this help

=item B<--skip>

    Optional: Do not run this script, simply exit(0). Default is --skip=0 (do not skip).

=back

=head1 DESCRIPTION

    For each chado table which has children tables, make_external_replacement_list.pl will read in the parent's dup.list file.  Each line in the dup.list file
    will be processed in the following way:

    The first column represents the master file:record for that particular chado table group.
  
    Here is a sample line in a dup.db.list
    /tmp/gba6615/db.out:;;db;;_1??       /tmp/gbs18rs21/db.out:;;db;;_1?? /tmp/gbs799/db.out:;;db;;_1?? /tmp/gbsa909/db.out:;;db;;_1??


    The following line will be output to replace.list:
    /tmp/gba6615/db.out:;;db;;_1??       /tmp/gbs18rs21/dbxref.out:;;db;;_1?? /tmp/gbs799/dbxref.out:;;db;;_1?? /tmp/gbsa909/dbxref.out:;;db;;_1??




    Assumptions:

    1. User has appropriate permissions (to execute script, access chado database, write to output directory).
    2. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./make_external_replacement_list.pl --dupdir=/usr/local/scratch/directory --log4perl=my.log --table=feature.out


=cut



use strict;

use Coati::Logger;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Data::Dumper;
use File::Basename;
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

print STDERR ("dupdir was not defined\n")   if (!$dupdir);


&print_usage if(!$dupdir);

my $logger = &get_logger($log4perl, $debug_level);

&is_skip($skip);

my $tablelist = &get_qualified_chado_table_list($table);

my $parent_to_children_tables_lookup = &get_parent_to_children_tables_lookup();

my $bcpfilelookup = &get_bcpfilelookup($dupdir);

my $placeholderlookup = {};

my $bcplookup = {};

my $rephash = &create_replace_hash($tablelist, $dupdir, $bcpfilelookup, $parent_to_children_tables_lookup, $bcplookup, $placeholderlookup);

&create_replace_ini_file($rephash, $dupdir, $bcplookup, $placeholderlookup, $bcpfilelookup);

$logger->info("$0 processing complete. See log file '$log4perl'.");

exit(0);


#-----------------------------------------------------------------------------------------------------------------------------------
#
#                                END OF MAIN -- SUBROUTINES FOLLOW
#
#-----------------------------------------------------------------------------------------------------------------------------------



#--------------------------------------------------
# transfer_directorykeys()
#
# Since the directory keys generated and assigned
# during both the creation of bcp.file.list.ini 
# and replace.ini are arbitrary- need to ensure 
# here that all remaining untransferred dirkeys 
# are transferred.
#
#--------------------------------------------------
sub transfer_directorykeys {

    my ($bcpfilelookup, $directorylookup) = @_;

    foreach my $dirkey (sort keys %{$bcpfilelookup->{'directories'}} ){ 

	my $directory = $bcpfilelookup->{'directories'}->{$dirkey};
	
	$directory =~ s/dd//;

	my $newdirkey = &get_key($directorylookup, $directory, 'd');

    }

}

#--------------------------------------------------
# create_replace_hash()
#
#--------------------------------------------------
sub create_replace_hash {

    my ($tablelist, $dupdir, $bcpfilelookup, $parent_to_children_tables_lookup, $bcplookup, $placeholderlookup) = @_;

    my $rephash = {};

    foreach my $table ( @{$tablelist} ) {

	print "Processing all table files related to '$table'\n";
	
	#--------------------------------------------------------------------------------------------------------------
	# Retrieve this table's dup.list file
	#
	#--------------------------------------------------------------------------------------------------------------
	my $dupfile = $dupdir . '/dup.' . $table . '.list';
	
	$logger->info("dupfile set to '$dupfile'");


	if ((-e $dupfile) && (-r $dupfile) && ($bcpfilelookup->{'table_count'}->{$table} > 0) && (!-z $dupfile)){ 
	    #
	    # Only proceed if the dupfile exists, is readable, has content and there do exist corresponding BCP .out 
	    # files for the specified table in the specified dupdir.
	    #

	    my ($childbcpfilesfound, $childhasbcpfiles) = &get_children_bcp_files($table, $bcpfilelookup, $parent_to_children_tables_lookup);

	    if ( $childbcpfilesfound ){
		#
		# We only proceed if there exist some BCP .out files associated to the children tables of the
		# specified parent table in the specified dupdir.
		#
		$logger->info("Found BCP .out files for the children tables associated with parent table '$table'");
			
		&resolve_external_reference($table, $childhasbcpfiles, $rephash, $dupdir, $dupfile, $bcplookup, $placeholderlookup, $bcpfilelookup);
	    }
	    else {
		$logger->info("Prent table '$table' did not have any children tables which had associated BCP .out files in the specified dupdir '$dupdir'");
	    }
	}
	else{
	    if (!-e $dupfile){
		$logger->info("dupfile '$dupfile' for table '$table' does not exist.  Continuing on to the next table...");
		next;
	    }
	    if (-z $dupfile){
		$logger->info("dupfile '$dupfile' for table '$table' had no content and therefore will not be processed.  Continuing on to next table...");
		next;
	    }
	    if (!-r $dupfile){
		$logger->logdie("dupfile '$dupfile' does not have read permissions.");
	    }
	}

	$logger->info("Finished processing all of children table BCP .out files associated with parent table '$table'");
    }

    return $rephash;
}


#----------------------------------------------------------
# resolve_external_reference()
#
#----------------------------------------------------------
sub resolve_external_reference {

    my ($table, $childhasbcpfiles, $rephash, $dupdir, $dupfile, $bcplookup, $placeholderlookup, $bcpfilelookup) = @_;

    open (DUPFILE, "<$dupfile") or $logger->logdie("Could not open dupfile '$dupfile'");

    while (my $dupline = <DUPFILE>){
			    
	chomp $dupline;
	#
	# E.g. dupline = /tmp/gba6615/organism.out:;;organism;;_1??       /tmp/gbs18rs21/organism.out:;;organism;;_1?? /tmp/gbs799/organism.out:;;organism;;_1?? /tmp/gbsa909/organism.out:;;organism;;_1??
	#

	foreach my $childtable ( sort keys %{$childhasbcpfiles} ) {

	    my @ar = split(/\s+/, $dupline);
	    
	    my $abbreviated_master_record_key = &get_abbreviated_master_record_key($ar[0], $dupdir, $bcpfilelookup, $placeholderlookup);

	    for (my $i=1; $i < scalar(@ar); $i++) {
		
		my $outval = $ar[$i];                    # e.g. $outval = /tmp/gbs799/db.out:;;db;;_1
		
		my $basename = basename($ar[$i]);        # e.g. $basename = db.out:;;db;;_1        
		my $dirname = dirname($ar[$i]);
		
		my $dirkey = &get_dirkey($dirname, $dupdir, $bcpfilelookup);

		my ($placeholderbcpfile, $placeholdertable, $placeholdercount);
		
		# basename = dbxref.out:;;db;;_1??
		if ($basename =~ /(\S+):;;(\S+);;_(\d+)/){
		    
		    $placeholderbcpfile = $1;  # dbxref.out
		    $placeholdertable = $2;    # db
		    $placeholdercount = $3;    # 1
		}
		else {
		    $logger->logdie("Could not parse '$basename'");
		}
		
		my $t = $table . '.out';
		my $c = $childtable . '.out';
		$placeholderbcpfile =~ s/$t/$c/ge;   
		# e.g. $fp = dbxref.out
		# e.g. $placeholderbcpfile = dbxref.out


		my $bcpfilekey = &get_key($bcplookup, $placeholderbcpfile, 'b');
		# e.g. $bcpfilekey = b1
	
		my $placeholderkey = &get_key($placeholderlookup, $placeholdertable, 'p');

		
		my $child_record = $dirkey . '/' . $bcpfilekey . ':' . $placeholderkey . '_' . $placeholdercount;
		# e.g. $child_record = /tmp/gbs799/dbxref.out:;;db;;_1
		

		push ( @{$rephash->{$table}->{$abbreviated_master_record_key}}, $child_record);

		
	    }
	}
    }

    close DUPFILE;

}


#------------------------------------------------------------------------
# get_key()
#
#------------------------------------------------------------------------
sub get_key {

    my ($lookup, $value, $prefix) = @_;

    my $key;

    if (( exists $lookup->{'valtokey'}->{$value}) &&
	(defined($lookup->{'valtokey'}->{$value}))){
	
	$key = $lookup->{'valtokey'}->{$value};
    }
    else {

	my $count = scalar(keys(%{$lookup->{'keytoval'}}));

	$key = $prefix . ++$count;

	$lookup->{'keytoval'}->{$key} = $value;
	$lookup->{'valtokey'}->{$value} = $key;
    }

    return $key;
}

#------------------------------------------------------------------------
# get_abbreviated_master_record_key()
#
#------------------------------------------------------------------------
sub get_abbreviated_master_record_key {

    my ($record, $dupdir, $bcpfilelookup, $placeholderlookup) = @_;

    my $basename = basename($record);
    my $dirname  = dirname($record);
   
   my $dirkey = &get_dirkey($dirname, $dupdir, $bcpfilelookup);

    my ($bcpfile, $table, $count);

    # basename = dbxref.out:;;db;;_1??
    if ($basename =~ /(\S+):;;(\S+);;_(\d+)/){

	$bcpfile = $1;  # dbxref.out
	$table = $2;    # db
	$count = $3;    # 1
    }
    else {
	$logger->logdie("Could not parse '$basename'");
    }

    my $bcpfilekey = &get_key($bcplookup, $bcpfile, 'b');
    # e.g. $fpkey = b1

    my $tablekey = &get_key($placeholderlookup, $table, 'p');
    # e.g. $idkey = p1_1
		
    my $abbreviated_record = $dirkey . '/' . $bcpfilekey . ':' . $tablekey . '_' . $count;       
    # e.g. $abbreviated_record = d2/b1:p1_1

    return $abbreviated_record;
}




#------------------------------------------------------------------------
# get_placeholderkey()
#
#------------------------------------------------------------------------
sub get_placeholderkey {

    my ($placeholderlookup, $id) = @_;

    if ($id =~ /(;;\S+;;)_(\d+)/){

	my $placeholder = $1;
	my $digit = $2;


	my $placeholderkey = &get_key($placeholderlookup, $placeholder, 'p');

	$placeholderkey .= "_$digit";
	
	return $placeholderkey;

    }
    else {
	$logger->logdie("Could not parse placeholder in id '$id'");
    }


}




#------------------------------------------------------------------------
# get_dirkey()
#
#------------------------------------------------------------------------
sub get_dirkey {

    my ($dirname, $dupdir, $bcpfilelookup) = @_;
    
    my $instancedir = $dirname;

    $instancedir = '/' . $instancedir;

    my $dirkey = &get_key($bcpfilelookup->{'directorylookup'}, $instancedir, 'd');

    return $dirkey;

}



#------------------------------------------------------------------------
# get_children_bcp_files()
#
# This routine will determine whether the specified table has any
# children tables which for which there exist corresponding BCP .out
# files.
#
# This script does not need to process the contents of those 
# corresponding BCP .out files.  Therefore, we will simply set a flag
# to indicate that BCP .out files were detected in the specified dupdir.
#
#-------------------------------------------------------------------------
sub get_children_bcp_files {

    my ($parenttable, $bcpfilelookup, $parent_to_children_tables_lookup) = @_;

    my $childhasbcpfiles = {};

    my $childbcpfilesfound = 0;

    

    if ( exists $parent_to_children_tables_lookup->{$parenttable}) {
	 #
	 # Yes, this parent table does have corresponding child tables
	 #
	 foreach my $childtable ( @{$parent_to_children_tables_lookup->{$parenttable}} ) {
	     #
	     # For each of the children tables, need to determine whether
	     # there exist any corresponding BCP .out files in the dupdir.
	     #
	     if ((exists $bcpfilelookup->{'table_count'}->{$childtable}) &&
		 (defined($bcpfilelookup->{'table_count'}->{$childtable}))){

		 
		 my $childbcpfilecounts = $bcpfilelookup->{'table_count'}->{$childtable};
		 

		 if ($childbcpfilecounts > 0 ){
		     
		     $childhasbcpfiles->{$childtable}++;
		     
		     $childbcpfilesfound++;

		 }
	     }
	     else {
		 $logger->info("Did not find any BCP .out files for child table '$childtable' associated with parent table '$parenttable'");
	     }
	 }
     }
    else {
	$logger->info("This parent table '$parenttable' does not have any associated children tables");
    }

    return ($childbcpfilesfound, $childhasbcpfiles);
}



#-------------------------------------------------------
# create_replace_ini_file()
#
#-------------------------------------------------------
sub create_replace_ini_file {

    my ($rephash, $dupdir, $bcplookup, $placeholderlookup, $bcpfilelookup) = @_;

    my $repfile = $dupdir . '/replace.ini';

    if (-e $repfile){

	&create_backup_file($repfile);
    }

    open (REPFILE, ">>$repfile") or $logger->logdie("Could not open '$repfile' in append mode");

    &write_tables_to_ini($rephash);

    &write_section_to_ini($bcpfilelookup->{'directorylookup'}, 'directorylookup');

    &write_section_to_ini($bcplookup, 'bcplookup');
    
    &write_section_to_ini($placeholderlookup, 'placeholderlookup');

    &write_master_records_to_ini($rephash);

    &write_all_records_to_ini($rephash);

}



#------------------------------------------------------
# write_section_to_ini()
#
#------------------------------------------------------
sub write_section_to_ini {

    my ($lookup, $section) = @_;

    print REPFILE "\n[$section]\n";

    foreach my $key (sort keys %{$lookup->{'keytoval'}} ){

	my $value = $lookup->{'keytoval'}->{$key};

	print REPFILE "$key=$value\n";

    }
}


#------------------------------------------------------
# write_all_records_to_ini()
#
#------------------------------------------------------
sub write_all_records_to_ini {

    my ($rephash) = @_;

    foreach my $table (sort keys %{$rephash} ){

	foreach my $master_record (sort keys %{$rephash->{$table}}) {

	    print REPFILE "\n[$master_record]\n";

	    foreach my $record (sort @{$rephash->{$table}->{$master_record}} ) {

		print REPFILE "$record=1\n";
	    }
	}
    }
}


#------------------------------------------------------
# write_master_records_to_ini()
#
#------------------------------------------------------
sub write_master_records_to_ini {

    my ($rephash) = @_;

    foreach my $table (sort keys %{$rephash} ){

	print REPFILE "\n[$table]\n";

	foreach my $master_record (sort keys %{$rephash->{$table}}) {

	    print REPFILE "$master_record=1\n";

	}
    }
}

#------------------------------------------------------
# write_tables_to_ini()
#
#------------------------------------------------------
sub write_tables_to_ini {

    my ($rephash) = @_;

    

    print REPFILE "\n[tables]\n";

    foreach my $table (sort keys %{$rephash} ){
    
	print REPFILE "$table=1\n";

    }
}


#------------------------------------------------------
# write_directories_to_ini()
#
#------------------------------------------------------
sub write_directories_to_ini {

    my ($directorylookup) = @_;


    print REPFILE "\n[directories]\n";


    foreach my $dirkey (sort keys %{$directorylookup->{'keytodir'}}){

	my $instancedir = $directorylookup->{'keytodir'}->{$dirkey};

	print REPFILE "$dirkey=$instancedir\n";

    }
}


#------------------------------------------------------
# create_backup_file()
#
#------------------------------------------------------
sub create_backup_file {

    my ($file) = @_;
    
    my $bakfile = $file . '.bak';

    $logger->info("Renaming file '$file' to '$bakfile'");

    rename($file, $bakfile);

}


#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 --dupdir=<value> [--log4perl=<value>] [-d debug_level] [-h] [-m] [--skip] [--table=<value>]\n".
     "  --dupdir              = File containing input directory listing\n".
     "  --log4perl            = Optional - Log4perl log file (default: /tmp/dup_list.pl.log)\n".
     "  -m|--man              = Display pod2usage pages for this utility\n".
     "  -h|--help             = Display pod2usage help screen.\n".
     "  -d|--debug_level      = Optional - Coati::Logger log4perl logging level (default level is 0)\n".    
     "  --skip                = Optional - Do not execute this script, exit(0) (Default --skip=0)\n".
     "  --table               = Optional - table\n";
    exit 1;

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
    }

    return \@tablelist;
}


#--------------------------------------------------
# build_file_from_bcpfilelookup()
#
#--------------------------------------------------
sub build_file_from_bcpfilelookup {

    my ($bcpfilelookup, $tableout, $dupdir, $abbreviatedbcpfile) = @_;

    my $dir2 = $bcpfilelookup->{'directories'}->{$abbreviatedbcpfile};

    my $file = $dir2 . "/" . $tableout;

    $file =~ s/dd/$dupdir/;

    return $file;
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



#--------------------------------------------------
# get_parent_to_children_tables_lookup()
#
#--------------------------------------------------
sub get_parent_to_children_tables_lookup {

    my $hash = { 'db'      => ['dbxref'],
		 'dbxref'  => ['cvterm','cvterm_dbxref','dbxrefprop','pub_dbxref','organism_dbxref','feature', 'feature_dbxref'],
		 'cv'      => ['cvterm','cvtermpath'],
		 'cvterm'  => ['cvterm_relationship','cvtermpath','cvtermsynonym','cvterm_dbxref','cvtermprop','dbxrefprop','pub', 'pub_relationship','pubprop','organismprop', 'feature','featureprop','feature_relationship','feature_relationshipprop','feature_cvterm','feature_cvtermprop','synonym','analysisprop'],
		 'pub'         => ['pub_relationship', 'pub_dbxref','pub_author','pubprop','feature_pub','featureprop_pub','feature_relationship_pub','feature_relprop_pub','feature_cvterm','feature_synonym',],
		 'author'      => [ 'pub_author' ],
		 'organism'    => ['organism_dbxref','organismprop','feature'],
		 'feature'     => ['featureloc','feature_pub','featureprop','feature_dbxref','feature_relationship','feature_cvterm','feature_synonym'],
		 'featureprop' => [ 'featureprop_pub' ],
		 'feature_relationship'     => ['feature_relationship_pub','feature_relationshipprop'],
		 'feature_relationshipprop' => [ 'feature_relprop_pub' ],
		 'feature_cvterm' => [ 'feature_cvtermprop' ],
		 'synonym'        => [ 'feature_synonym' ],
		 'analysis'       => ['analysisprop','analysisfeature']
	     };

    return $hash;
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
	    
	    foreach my $dirkey (sort keys %{$cfg->{'v'}->{'directories'}}) {

		my $directory = $cfg->{'v'}->{'directories'}->{$dirkey};

		$lookup->{'directorylookup'}->{'keytoval'}->{$dirkey} = $directory;
		$lookup->{'directorylookup'}->{'valtokey'}->{$directory} = $dirkey;


	    }




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
		    my $count = scalar(keys( %{$cfg->{'v'}->{$bcpfile}} )) ;

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

