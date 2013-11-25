#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
# $Id: dup_list.pl 3145 2006-12-07 16:42:59Z angiuoli $


=head1 NAME

dup_list.pl - Performs grep in specified directory and identifies duplicate identifiers, produces duplicate list file

=head1 SYNOPSIS

USAGE:  dup_list.pl --dupdir=<value> [--log4perl=<value>] [-d debug_level] [-h] [-m] [--outdir=<value>] [--skip] [--table=<value>]

=head1 OPTIONS

=over 8
 
=item B<--dupdir>
    
    File containing a listing of all input directories containing tab delimited out files to be scanned for duplicate identifiers

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--outdir>

    Optional: Output directory for the tab delimited duplicate identifiers files.  Default is current directory

=item B<--skip>

    Optional: Do not run this script, simply exit(0). Default is --skip=0 (do not skip)

=item B<--table>

    Optional: table files to be processed e.g. feature.out or db.out.  Default is all of the following analysis.out, feature_cvterm.out, feature.out, db.out

=item B<--help,-h>

    Print this help

=back

=head1 DESCRIPTION

    dup_list.pl - Performs grep in specified directory and identifiers duplicate identifiers, produces duplicate list file

    Sample output files: feature.out, db.out


    Assumptions: 

    1. User has appropriate permissions (to execute script, access chado database, write to output directory).
    2. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./dup_list.pl --dupdir=/usr/local/scratch/directory --log4perl=my.log --outdir=/tmp/outdir
    ./dup_list.pl --dupdir=/usr/local/scratch/directory --log4perl=my.log --outdir=/tmp/outdir --table=feature.out


=cut



use strict;

use Coati::Logger;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Data::Dumper;
use File::Copy;
use Config::IniFiles;




my ($log4perl, $debug_level, $dupdir, $help, $outdir, $man, $table, $skip);

my $results = GetOptions (
			  'dupdir=s'        => \$dupdir,
			  'log4perl=s'      => \$log4perl,
			  'debug_level|d=s' => \$debug_level, 
			  'help|h'          => \$help,
			  'outdir=s'        => \$outdir,
			  'man|m'           => \$man,
			  'table=s'         => \$table,
			  'skip=s'          => \$skip
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("dupdir  was not defined\n")   if (!$dupdir);

&print_usage if(!$dupdir);

#
# 1. use directory name to retrieve all table.out files
# 2. retrieve duplicate list
# 3. output list to dup.table.list
#
    
my $logger = &get_logger($log4perl, $debug_level);

&is_skip($skip);

#
# Default outdir is current working directory
#
if (!defined($outdir)){
    $outdir = $dupdir;
}

my $bcpfilelookup = &get_bcpfilelookup($dupdir);

my $parenttables = &load_parenttables();

my $uniquecols = &get_uniquekey_columns();

my $foreign_key_lookup = &get_foreignkey_columns();

my $tablelist = &get_qualified_chado_table_list($table);

#
# We want to produce one duplicates list for each major table (feature, db, analysis)
#
foreach my $table ( @{$tablelist} ) {
    
    $logger->info("Processing the '$table' group");

    
    if ($bcpfilelookup->{'table_count'}->{$table} > 1){
	
	#
	# Foreach table that has parent tables, retrieve those duplicate files and load
	# data hashes
	#
	my $parent_duplicates = &get_parents_duplicate_lists($table, $parenttables, $outdir);

	my $filelookup = {};
	
	my $maxcols = &get_maxcols($table, $uniquecols);

	my $fileplaceholderlookup = {};

	my $duplicates = &get_duplicates($bcpfilelookup, $table, $parent_duplicates, $filelookup, $dupdir, $uniquecols, $foreign_key_lookup, $maxcols, $fileplaceholderlookup);

	&write_duplicates($duplicates, $outdir, $table, $filelookup, $maxcols, $fileplaceholderlookup);

    }
    else{

	my $emptyfile = $outdir . '/dup.' . $table . '.list';

	$logger->warn("Did not file any '$table' files nested below directory '$dupdir'.  Will create an empty file '$emptyfile'");

	eval {qx{touch $emptyfile}};

	if ($@){

	    $logger->logdie("Error occured when attempting to create empty file '$emptyfile': $!");
	}
    }
}




#--------------------------------------------------------------------------------------------------
#
#                    END OF MAIN -- SUBROUTINES FOLLOW
#
#--------------------------------------------------------------------------------------------------




#--------------------------------------
# retrieve_duplicate_lists()
#
#--------------------------------------
sub retrieve_duplicate_lists {

    my ($parent, $outdir, $table, $dupfile) = @_;

    if (!-e $dupfile){
	$logger->logdie("duplicate list file '$dupfile' (parent of '$table') does not exist");
    }
    if (!-r $dupfile){
	$logger->logdie("duplicate list file '$dupfile' (parent of '$table') does not have read permissions");
    }

    open (DUPFILE, "<$dupfile") or $logger->logdie("Could not open dupfile '$dupfile'");

    my $duphash = {};
    
    #
    # Load the duphash. The first identifier on each line is the master identifier for that line.
    # 
    while (my $dupline = <DUPFILE>){
	    
	chomp $dupline;

	my @ar = split(/\s+/, $dupline);
	    
	for (my $i=0; $i < scalar(@ar); $i++) {
	    $duphash->{$ar[$i]} = $ar[0];
		
	}

    }
    close DUPFILE;

    return $duphash;


}

 
#--------------------------------------
# get_duplicates()
#
#--------------------------------------
sub get_duplicates {

    my ($bcpfilelookup, $table, $parenthashes, $filelookup, $dupdir, $uniquecols, $foreign_key_lookup, $maxcols, $fileplaceholderlookup) = @_;

    my $dups = {};

    my $uniquafier = 0;

    my $tableout = $table . ".out";

    my @abbreviatedBcpFiles = keys ( %{$bcpfilelookup->{'files'}->{$tableout}});

    my $TotalBcpFileCount = scalar(@abbreviatedBcpFiles);

    my $bcpFileCounter = 0;

    foreach my $abbreviatedbcpfile (@abbreviatedBcpFiles) {

	$bcpFileCounter++;

	my $infile = &build_file_from_bcpfilelookup($bcpfilelookup, $tableout, $dupdir, $abbreviatedbcpfile);

	$logger->info("Reading in BCP file '$infile'");

	open (INFILE, "<$infile") or $logger->logdie("Could not open table BCP .out file '$infile'");

	my $fileindex = scalar(keys (%$filelookup));

	# remove the fullpath to dupdir
	$infile =~ s/$dupdir\/*//;

	$filelookup->{$fileindex} = $infile;

	my $authfile = $infile;

	my $linectr=0;

	$/ = "\?\?\?\?\n";

	while ( my $line = <INFILE> ){

	    chomp $line;

	    $linectr++;

	    $uniquafier++;

	    &get_duplicates_from_line($line, $linectr, $uniquafier, $uniquecols, $dups, $authfile, $parenthashes, $fileindex, $foreign_key_lookup, $maxcols, $fileplaceholderlookup);


	}
	$/ = '\n';
    }
    
    return $dups;
}



#--------------------------------------
# get_duplicates_from_line()
#
#--------------------------------------
sub get_duplicates_from_line {

    my ($line, $linectr, $uniquafier, $uniquecols, $dups, $authfile, $parenthashes, $fileindex, $foreign_key_lookup, $maxcols, $fileplaceholderlookup) = @_;
    
    $line =~ s/\?\?\?\?$//;

    my @x = split('\?\?\s+\?\?',$line);

    if ( ( $table eq 'feature') &&
	 ( $x[$uniquecols->{'feature'}->[3]] =~ /feature/ ) && # is uniquename like feature
	 ( $x[$uniquecols->{'feature'}->[3]] =~ /match/) ) {   # is uniquename like match
	# found a computational match feature
	return;
    }

    my $prefix;
    my $val;

    # We replace the split method with the following regular expression
    # in order to reliably extract table name and index from the
    # placeholder table serial identifier value.
    # The previous split method failed for tables that contained
    # underscores in their names e.g. feature_dbxref
    #
    # Example placeholder value  ;;feature_dbxref;;_1??
    #
    if ($x[0] =~ /^(;;\D+;;)_(\d+)$/){
	$prefix = $1;
	$val = $2;
    }
    else {
	$logger->logdie("Could not extract the prefix nor val from table identifier '$x[0]'");
    }


    my $infoindex;

    if (exists $fileplaceholderlookup->{'prefix'}->{$prefix}){
	$infoindex = $fileplaceholderlookup->{'prefix'}->{$prefix};
    }
    else {
	$infoindex = scalar(keys (%{$fileplaceholderlookup->{'prefix'}}));
	$fileplaceholderlookup->{'prefix'}->{$prefix} = $infoindex;
	$fileplaceholderlookup->{'indexes'}->{$infoindex} = $prefix;
    }

    my $info = $fileindex . ':' . $infoindex . '_' . $val;

    #
    # Capture the keys
    #
    my @ucarray;


    #
    # Store only the columns which make up the uniqueness constraint for this record
    #
    foreach my $col (@{$uniquecols->{$table}}){
	
	#
	# Foreach key, determine whether is a foreign key
	# Note that the use of foreign_key_lookup will greatly reduce the number
	# of calls to get_foreign_referenced_column().
	#
	# We need to make the following determination:
	# 1) is the column a foreign key referencing column?
	# 2) is the foreign key a qualified one which needs to be resolved?
	# 3) does the column not contain an empty string?
	# 4) does the column contain a valid placeholder value?
	# If all of those conditions are satisfied, then we need to resolve the
	# placeholder's foreign key reference i.e. inline the referenced column's
	# value.
	# If any one of the conditions are not met, then we do not attempt to resolve.
	#
 	if ( ( $x[$col] !~ /;;$table;;/) && # more efficient to perform this check first
	     ( exists $foreign_key_lookup->{$table}->{$col}) &&
	     ( $x[$col] ne ''          ) && 
	     ( $x[$col] =~ /;;(\w+);;_\d+/) ) {
	    
	    #
	    # Found a foreign key column containing a placeholder value
	    #
	    my $tablekey = $1;
	    
	    $x[$col] = &get_foreign_referenced_column($tablekey,
						      $parenthashes,
						      $authfile,
						      $table,
						      $x[$col],
						      $uniquafier);
	}
     
	#
	# Create the unique constraint key by concatenating values
	#
	push @ucarray,$x[$col];

    }

    

    &store_dups(\@ucarray, $dups, $info, $maxcols);

}# end sub get_duplicates_from_line()

#--------------------------------------
# get_foreign_referenced_column()
#
#--------------------------------------
sub get_foreign_referenced_column {
    
    my ($tablekey, $parenthashes, $path, $table, $columnvalue, $uniquafier) = @_;

    #
    # Check if the table (tablekey) has an entry
    # in the parenthashes lookup
    #
    if ( ( exists $parenthashes->{$tablekey}  ) &&
	 ( defined($parenthashes->{$tablekey})) ){
	
	# e.g. infile = /usr/local/scratch/sundaram/duptest/gbs799/organism_dbxref.out
	# basefilename = organism_dbxref.out
	# table = organism_dbxref
	# $1 is a found table name e.g. dbxref
	# authfile = infile
	# authfile =~ s/$table/$1/;
	# authfile .= ':' $columnvalue
	
	$path =~ s/$table/$tablekey/;
	$path .= ':' . $columnvalue . '??';
	
	#
	# Get the authoritative file:id for the foreign/parent id
	#
	if ( ( exists $parenthashes->{$tablekey}->{$path}  ) &&
	     ( defined($parenthashes->{$tablekey}->{$path} )) ){
    
	    $uniquafier = $parenthashes->{$tablekey}->{$path};
	}
    }
    #
    # The placeholder in this file did not reference a foreign key
    # placeholder which was unique across all previous generation
    # BCP .out files.
    # Assign some truly unique value (uniquafier) to trick the
    # key2id lookup check...
    
    return $uniquafier;

}# end sub get_foreign_referenced_column()
	

#--------------------------------------
# write_duplicates()
#
#--------------------------------------
sub write_duplicates {

    my ($dups, $outdir, $tabl, $filelookup, $maxcols, $fileplaceholderlookup) = @_;

    my $outfile = $outdir . '/' . 'dup.' . $tabl . '.list';
    
    open OUTFILE, ">$outfile" or $logger->logdie("Can't open outfile '$outfile'");
    
    if ($maxcols == 4) {

	foreach my $key1 (keys %{$dups}){
	    foreach my $key2 (keys %{$dups->{$key1}}){
		foreach my $key3 (keys %{$dups->{$key1}->{$key2}}){
		    foreach my $key4 (keys %{$dups->{$key1}->{$key2}->{$key3}}){
			if (scalar(@{$dups->{$key1}->{$key2}->{$key3}->{$key4}}) > 1 ){
			    
			    my $duparray = $dups->{$key1}->{$key2}->{$key3}->{$key4};
			    
			    &write_records($duparray, $filelookup, $fileplaceholderlookup);
			}
		    }
		}
	    }
	}
    }
    elsif ($maxcols == 3) {

	foreach my $key1 (keys %{$dups}){
	    foreach my $key2 (keys %{$dups->{$key1}}){
		foreach my $key3 (keys %{$dups->{$key1}->{$key2}}){
		    if (scalar(@{$dups->{$key1}->{$key2}->{$key3}}) > 1 ){

			my $duparray = $dups->{$key1}->{$key2}->{$key3};
			
			&write_records($duparray, $filelookup, $fileplaceholderlookup);
		    }
		}
	    }
	}
    }
    elsif ($maxcols == 2){

	foreach my $key1 (keys %{$dups}){
	    foreach my $key2 (keys %{$dups->{$key1}}){
		if (scalar(@{$dups->{$key1}->{$key2}}) > 1 ){

		    my $duparray = $dups->{$key1}->{$key2};

		    &write_records($duparray, $filelookup, $fileplaceholderlookup);
		}
	    }
	}

    }
    elsif ($maxcols == 1){

	foreach my $key1 (keys %{$dups}){
	    if (scalar(@{$dups->{$key1}}) > 1 ){

		my $duparray = $dups->{$key1};
		
		    &write_records($duparray, $filelookup, $fileplaceholderlookup);
	    }
       	}
	
    }
    else {
	$logger->logdie("maxcols '$maxcols' unexpected");
    }

    print "Wrote duplicates to '$outfile'\n";

}

#--------------------------------------
# write_records()
#
#--------------------------------------
sub write_records {

    my ($duparray, $filelookup, $fileplaceholderlookup) = @_;

    # more than just the representative stored in the array
    my $representative = shift (@{$duparray});
    
    $representative =~ s/^(\d+):(\d+)_(\d+)/&replace($1,$2,$3,$filelookup, $fileplaceholderlookup)/e;

    print OUTFILE "$representative\t";
    
    foreach my $member ( @{$duparray} ) {

	$member =~ s/^(\d+):(\d+)_(\d+)/&replace($1,$2,$3, $filelookup,$fileplaceholderlookup)/e;

	print OUTFILE "$member ";
	
    }

    print OUTFILE "\n";
}

sub replace {

    my ($one, $two, $three, $file, $place) = @_;

    my $key1 = $file->{$one};
    my $key2 = $place->{'indexes'}->{$two};


    my $ret = $key1 .':' . $key2 . '_' . $three . '??';

    return $ret;
}


#--------------------------------------
# load_parenttables()
#
#--------------------------------------
sub load_parenttables {

    my $parenttables = {
			  'dbxref'              => [ 'db'],
			  'cvterm'              => [ 'cv','dbxref'],
			  'cvterm_relationship' => [ 'cvterm'],
			  'cvtermpath'          => [ 'cvterm', 'cv' ],
			  'cvtermsynonym'       => [ 'cvterm'],
			  'cvterm_dbxref'       => [ 'cvterm','dbxref'],
			  'cvtermprop'          => [ 'cvterm' ],
			  'dbxrefprop'          => [ 'dbxref', 'cvterm' ],
			  'pub'                 => [ 'cvterm' ],
			  'pub_relationship'    => [ 'pub', 'cvterm' ],
			  'pub_dbxref'          => [ 'pub', 'dbxref' ],
			  'author'              => [ 'contact' ],
			  'pub_author'          => [ 'author' , 'pub' ],
			  'pubprop'             => [ 'pub', 'cvterm' ],
			  'organism_dbxref'     => [ 'organism', 'dbxref' ],
			  'organismprop'        => [ 'organism', 'cvterm' ],
			  'feature'             => [ 'dbxref', 'organism', 'cvterm' ],
			  'featureloc'          => [ 'feature' ],
			  'feature_pub'         => [ 'feature', 'pub' ],
			  'featureprop'         => [ 'feature', 'cvterm' ],
			  'featureprop_pub'     => [ 'featureprop', 'pub' ],
			  'feature_dbxref'      => [ 'feature', 'dbxref' ],
			  'feature_relationship'     => [ 'feature', 'cvterm' ],
			  'feature_relationship_pub' => [ 'feature_relationship', 'pub' ],
			  'feature_relationshipprop' => [ 'feature_relationship', 'cvterm' ],
			  'feature_relprop_pub'      => [ 'feature_relationshipprop', 'pub' ],
			  'feature_cvterm'           => [ 'feature', 'cvterm', 'pub' ],
			  'feature_cvtermprop'       => [ 'feature_cvterm', 'cvterm' ],
			  'synonym'                  => [ 'cvterm' ],
			  'feature_synonym'          => [ 'synonym', 'feature', 'pub' ],
			  'analysisprop'             => [ 'analysis', 'cvterm' ],
#			  'analysisfeature'          => [ 'feature', 'analysis' ]
			  'analysisfeature'          => [ 'analysis' ]
		      };


    return $parenttables;
}


#--------------------------------------
# get_uniquekey_columns()
#
#--------------------------------------
sub get_uniquekey_columns{
    
    #
    # The order of the indexes for the unique keys reflects our expectations so far as
    # the more common values appear towards the beginning of the array and the
    # more varied values appear towards the end of the array.  This will support
    # the creation of more compact (efficient hash lookups).
    #

    my $ref= {
	'tableinfo' => [1], # name
	'project' => [1], # name
	'db'=> [1], # name
	'dbxref' => [3,1,2], # version, db_id, accession
	'cv' => [1], # name 
	'cvterm' => [1,5,2], # cv_id, is_obsolete, name
	'cvterm_relationship' => [1,3,2], # type_id, object_id, subject_id
	'cvtermpath' => [5,1,3,2], # cv_id, type_id, object_id, subject_id
	'cvtermsynonym' => [1,2], # cvterm_id, synonym
	'cvterm_dbxref' => [1,2], # cvterm_id, dbxref_id
	'cvtermprop' => [4,2,1,3], # rank, type_id, cvterm_id, value
	'dbxrefprop' => [4,2,1,3], # rank, type_id, dbxref_id, value
	'organism' => [2,3], # genus, species
	'organism_dbxref' => [1,2], # organism_id, dbxref_id
	'organismprop' => [4,2,1,3], # rank, type_id, organism_id, value
	'pub' => [10,9], # type_id, uniquename
	'pub_relationship' => [3,2,1],  # type_id, object_id, subject_id
	'pub_dbxref' => [2,3], # pub_id, dbxref_id
	'pubauthor' => [2,3], # pub_id, rank
	'pubprop' => [1,2,3], # pub_id, type_id, value
	'feature' => [2,8,4],  # organism_id, type_id, uniquename
	'featureloc' => [10,11,1], # locgroup, rank, feature_id
	'featurepub' => [2,1], # pub_id, feature_id
	'featureprop' => [4,2,1,3], # rank, type_id, feature_id, value
	'featureprop_pub' => [2,1], # pub_id, featureprop_id
	'feature_dbxref' => [1,2], # feature_id, dbxref_id
	'feature_relationship' => [3,2,1], # type_id, object_id, subject_id 
	'feature_relationship_pub' => [2,1], # pub_id, feature_relationship_id
	'feature_relationshipprop' => [4,1,2], # rank, feature_relationship_id, type_id
	'feature_relprop_pub' => [2,1], # pub_id, feature_relationshipprop_id
	'feature_cvterm' => [3,2,1], # pub_id, cvterm_id, feature_id
	'feature_cvtermprop' => [4,1,2], # rank, feature_cvterm_id, type_id
	'feature_cvterm_dbxref' => [1,2], # feature_cvterm_id, dbxref_id
	'feature_cvterm_pub' => [2,1], # pub_id, feature_cvterm_id
	'synonym' => [2,1], # type_id, name
	'feature_synonym' => [3,1,2], # pub_id, synonym_id, feature_id
	'analysis' => [4,3,6], # programversion, program, sourcename
	'analysisprop' => [1,2], # analysis_id, type_id
	'analysisfeature' => [2,1] # analysis_id, feature_id
	};

    return $ref;
}

#--------------------------------------
# get_foreignkey_columns()
#
#--------------------------------------
sub get_foreignkey_columns{
    
    #
    # We make the following assertion:  For all tables not part of the CV Module, all foreign key references to cvterm.cvterm_id
    # will not need to be processed since we expect all cvterm_id identifiers to be resolved- that is to be true numeric values
    # and not ever be placeholder values.  This assertion does not apply to tables that are part of the CV Module.  These CV Module
    # tables may contain placeholder variables during the execution of obo2chado.pl (ontology loader).
    #

    #
    # Note that there are no foreign key referencing columns in the following top tier chado tables:
    # tableinfo, project, db, cv, organism, analysis
    #
    
    # Note that the keys are table->{column}
    # e.g. $foreign_key_lookup->{'dbxref'}->{1} means that the first column of dbxref is a foreign key referencing column
    #
    my $foreign_key_lookup = {
	'dbxref' => {1=>1}, # dbxref.db_id -> db.db_id
	'cvterm' => {1=>1,4=>1}, # cvterm.cv_id -> cv.cv_id; cvterm.dbxref_id -> dbxref.dbxref_id
	'cvterm_relationship' => {1=>1,2=>1,3=>1}, # type_id, subject_id, object_id -> cvterm.cvterm_id
	'cvtermpath' => {1=>1,2=>1,3=>1,5=>1}, # type_id, subject_id, object_id -> cvterm.cvterm_id; cv_id -> cv.cv_id
	'cvtermsynonym' => {1=>1,3=>1}, # cvterm_id, type_id -> cvterm.cvterm_id
	'cvterm_dbxref' => {1=>1,2=>1}, # cvterm_id -> cvterm.cvterm_id; dbxref_id -> dbxref.dbxref_id
	'cvtermprop' => {1=>1,2=>1}, # cvterm_id, type_id -> cvterm.cvterm_id
	'dbxrefprop' => {1=>1,2=>1}, # dbxref_id -> dbxref.dbxref_id; type_id -> cvterm.cvterm_id
	'organism_dbxref' => {1=>1,2=>1}, # organism_id -> organism.organism_id; dbxref_id -> dbxref.dbxref_id
	'organismprop' => {1=>1}, # organism_id -> organism.organism_id
	'pub_dbxref' => {1=>1,2=>1}, # pub_id -> pub.pub_id; dbxref_id -> dbxref.dbxref_id
	'pubauthor' => {1=>1}, # pub_id -> pub.pub_id
	'pubprop' => {1=>1}, # pub_id -> pub.pub_id
	'feature' => {1=>1,2=>1},  # dbxref_id -> dbxref.dbxref_id; organism_id -> organism.organism_id
	'featureloc' => {1=>1,2=>1}, # feature_id -> feature.feature_id; srcfeature_id -> feature.feature_id
	'featurepub' => {1=>1,2=>1}, # feature_id -> feature.feature_id; pub_id -> pub.pub_id
	'featureprop' => {1=>1}, # feature_id  -> feature.feature_id
	'featureprop_pub' => {1=>1,2=>1}, # featureprop_id -> featureprop.featureprop_id; pub_id -> pub.pub_id
	'feature_dbxref' => {1=>1,2=>1}, # feature_id -> dbxref_id -> dbxref.dbxref_id; feature.feature_id
	'feature_relationship' => {1=>1,2=>1}, # subject_id -> feature.feature_id; object_id -> feature.feature_id
	'feature_relationship_pub' => {1=>1,2=>1}, # feature_relationship_id -> feature_relationship.feature_relationship_id; pub_id -> pub.pub_id
	'feature_relationshipprop' => {1=>1}, # feature_relationship_id -> feature_relationship.feature_relationship_id
	'feature_relprop_pub' => {1=>1,2=>1}, # feature_relationshipprop_id -> feature_relationshipprop.feature_relationshipprop_id; pub_id -> pub.pub_id
	'feature_cvterm' => {1=>1,3=>1}, # feature_id -> feature.feature_id; pub_id -> pub.pub_id
	'feature_cvtermprop' => {1=>1}, # feature_cvterm_id -> feature_cvterm.feature_cvterm_id
	'feature_cvterm_dbxref' => {1=>1,2=>1}, # feature_cvterm_id -> feature_cvterm.feature_cvterm.id; dbxref_id -> dbxref.dbxref_id
	'feature_cvterm_pub' => {1=>1,2=>1}, # feature_cvterm_id -> feature_cvterm.feature_cvterm.id; pub_id -> pub.pub_id
	'feature_synonym' => {1=>1,2=>1,3=>1}, # synonym_id -> synonym.synonym_id; feature_id -> feature.feature_id; pub_id -> pub.pub_id
	'analysisprop' => {1=>1}, # analysis_id -> analysis.analysis_id
	'analysisfeature' => {1=>1,2=>1} # feature_id -> feature.feature_id; analysis_id -> analysis.analysis_id
    };
    
    return $foreign_key_lookup;
}

#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 --dupdir [--log4perl] [-d debug_level] [-h] [-m] [--outdir] [--skip] [--table]\n".
    "  --dupdir              = Directory containing all input groups\n".
    "  --log4perl            = Optional - Log4perl log file (default: /tmp/dup_list.pl.log)\n".
    "  -m|--man              = Display pod2usage pages for this utility\n".
    "  -h|--help             = Display pod2usage help screen.\n".
    "  -d|--debug_level      = Optional - Coati::Logger log4perl logging level (default level is 0)\n".
    "  --outdir              = Optional - Output directory for tab delimited out files (default is current directory)\n".
    "  --skip                = Optional - Do not run this script, simply exit(0)\n".
    "  --table               = Optional - table\n";
    exit 1;

}




#------------------------------------------------------
# get_bcpfilelookup()
#
#------------------------------------------------------
sub get_bcpfilelookup {

    my $dupdir = shift;

    my $file  = $dupdir . "/bcp.file.list.ini";

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



#------------------------------------------------------
# get_parents_duplicate_lists()
#
#------------------------------------------------------
sub get_parents_duplicate_lists {

    my ($table, $parenttables, $outdir) = @_;

    my $parenthashes = {};

    if (exists $parenttables->{$table}){
	    
	if (scalar (@{$parenttables->{$table}}) > 0 ){
		
	    foreach my $parent ( @{$parenttables->{$table}} ) {
		    
		my $dupfile = $outdir . '/dup.' . $parent . '.list';


		if (-e $dupfile){
			
		    if (!-z $dupfile){
			
			$parenthashes->{$parent} = &retrieve_duplicate_lists($parent, $outdir, $table, $dupfile)
		    }
		    else {
			$logger->info("duplicate list file '$dupfile' (parent of '$table') has zero content i.e. no duplicates");
		    }
		}
		else{
		    $logger->info("duplicate list file '$dupfile' (parent of '$table') does not exist");
		}
	    }
	}
	else {
	    $logger->info("There are no parent tables for table '$table'");
	}
    }
    else {
	$logger->info("There are no parent tables for table '$table'");
    }
    
    return $parenthashes;
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

    my $file = $dupdir . '/' . $dir2 . "/" . $tableout;

    return $file;
}



#--------------------------------------------------
# store_dups()
#
#--------------------------------------------------
sub store_dups {

    my ($uclist, $dups, $info, $maxcols) = @_;

    # So instead of a duplicates lookup with the hash-key being the representative tuple
    # and hash-value being an array reference where the array referenced is a list
    # of the duplicate/member tuples-
    # We now create a duplicates lookup with the representative being the first element in the
    # referenced array with all duplicate/member tuples stored in the subsequent array elements.
    # The keys for the new lookup consist of the uniqueness constraint columns.
    #

    if ($maxcols == 4){
	# tables: organismprop,

	push( @{$dups->{$uclist->[0]}->{$uclist->[1]}->{$uclist->[2]}->{$uclist->[3]}}, $info);
    }
    elsif ($maxcols == 3){
	# tables: feature, 
	push( @{$dups->{$uclist->[0]}->{$uclist->[1]}->{$uclist->[2]}}, $info);
    }
    elsif ($maxcols == 2){
	# tables: feature_dbxref, 

	push( @{$dups->{$uclist->[0]}->{$uclist->[1]}}, $info);
    }
    elsif ($maxcols == 1){
	# tables: feature_dbxref, 

 	push( @{$dups->{$uclist->[0]}}, $info);
    }
    else {
	$logger->logdie("maxcols '$maxcols' unexpected");
    }

}



#--------------------------------------------------
# get_maxcols()
#
#--------------------------------------------------
sub get_maxcols {

    my ($table, $uniquecols) = @_;

    my $maxcols = scalar(@{$uniquecols->{$table}});

    return $maxcols;
}
