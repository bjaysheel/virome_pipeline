#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#--------------------------------------------------------------------------------------------------
# $Id: validate_foreign_key_constraints.pl 3145 2006-12-07 16:42:59Z angiuoli $
#--------------------------------------------------------------------------------------------------
#
# Performs validation on foreign key constraints in BCP files
#
# 1) self-check against set of BCP files in specified directory
# 2) check against already loaded records in the target chado database
#
#
#
#
#
#--------------------------------------------------------------------------------------------------

=head1 NAME

validate_foreign_key_constraints.pl - Validates the foreign key constraints for set of BCP files

=head1 SYNOPSIS

USAGE:  validate_foreign_key_constraints.pl [-D database] [-S server] [-P password] [-U username] [-l log4perl] [-d debug_level] [-h] [-m] [-r directory] [-t table]

=head1 OPTIONS

=over 8
 
=item B<--database,-D>
    
      Optional -- Database to retrieve records from

=item B<--server,-S>
    
      Optional -- Database server to retrieve records from

=item B<--password,-P>

      Optional -- password

=item B<--username,-U>

      Optional -- username

=item B<--directory,-r>

      Optional - Directory containing all BCP .out files to be validated.  (Default is current working directory)

=item B<--table,-t>

      Optional - name of chado table on which to perform foreign key constraint validation

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--log4perl,-l>

    Optional: Log4perl logfile.  Default is /tmp/validate_foreign_key_constraints.pl.log

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--help,-h>

    Print this help

=back

=head1 DESCRIPTION

    validate_foreign_key_constraints.pl - Validates the foreign key constraints for set of BCP files


    Assumptions:

    1. User has appropriate permissions (to execute script, access chado database, read input directory).
    2. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./validate_foreign_key_constraints.pl -r /usr/local/scratch/directory -l my.log
    ./validate_foreign_key_constraints.pl -r /usr/local/scratch/directory -l my.log -D chado_test -U access -P access


=cut


#-----------------------------------------------------------------------------------------
# Critical libraries
#
#
#-----------------------------------------------------------------------------------------
use strict;

use Coati::Logger;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Data::Dumper;
use File::Copy;
use File::Basename;
use Pod::Usage;
use Prism;


#-----------------------------------------------------------------------------------------
# Retrieve command-line arguments
#
#-----------------------------------------------------------------------------------------
my ($log4perl, $debug_level, $directory, $help, $username, $man, $password, $database, $server, $table);

my $results = GetOptions (
			  'directory|r=s'         => \$directory,
			  'log4perl|l=s'          => \$log4perl,
			  'debug_level|d=s'       => \$debug_level, 
			  'help|h'                => \$help,
			  'database|D=s'          => \$database,
			  'server|S=s'			  => \$server,
			  'man|m'                 => \$man,
			  'username|U=s'          => \$username,
			  'password|P=s'          => \$password,
			  'table|t=s'             => \$table
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);



$log4perl = "/tmp/validate_foreign_key_constraints.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

if (!defined($directory)){
    $directory = '.';
    $logger->info("directory was not specified, therefore setting to current working directory");
}


    if (defined($server)){
	#
	# We override the conf/Prism.conf
	#
	if ($server eq 'SYBIL') {
	    $ENV{PRISM} = "Chado:BulkSybase:SYBIL";
	    $logger->info("User specified server '$server' therefore PRISM env var was set to '$ENV{PRISM}'");
	}
	elsif ($server eq 'SYBTIGR'){
	    $ENV{PRISM} = "Chado:BulkSybase:SYBTIGR";
	    $logger->info("User specified server '$server' therefore PRISM env var was set to '$ENV{PRISM}'");
	}
	else{
	    $logger->logdie("server '$server' was not accepted.  Please specify either SYBIL or SYBTIGR");
	}
    }


my $prism;

if (defined($database)){

    #
    # If the database has been specified, then user expects some BCP file records may contain
    # foreign key references to records currently loaded in the target chado database.
    # 
    # Need to retrieve the appropriate tuples from the target database.
    #
    
    if (!defined($username)){
	$logger->logdie("username and password must be specified");
    }
    if (!defined($password)){
	$logger->logdie("username and password must be specified");
    }

	    
    $prism = &retrieve_prism_object($username, $password, $database);
	   
	
}

#
# This is the COMMIT_ORDER Prism environment variable
#
my @qualtablist = split(/,/, $ENV{'COMMIT_ORDER'});
my $qtabhash = {};
foreach my $qtab (@qualtablist) {
    $qtabhash->{$qtab} = $qtab;
}

$logger->debug("qualified table list:\n" . Dumper $qtabhash) if $logger->is_debug;

#
# User specified table for which foreign key constraints shall be validated.
# Make sure it is a qualified chado table.
#
if (defined($table)){
    if ((exists $qtabhash->{$table}) and (defined($qtabhash->{$table}))){
	print "Will attempt to only process child table '$table'\n";
	$logger->info("As specified by user '$username' on qualified chado table '$table' will be validated");
    }
    else{
	$logger->logdie("User '$username' specified an invalid chado table '$table'");
    }
}




my $parenttables = &load_parenttables();
my $greplines = &load_greplines();


#
# Retrieve all BCP .out files in specified directory
#
if ( (-e $directory ) && (-d $directory) ){

    my @tabledotout;

    if (defined($table)){
	#
	# User specified table for which foreign key constraints shall be validated.
	# Only this table file shall be validated.
	# Make sure the file has exists and has correct permissions.
	#
	my $tfile = $directory . '/' . $table . '.out';
	if (!-e $tfile){
	    $logger->info("BCP .out file '$tfile' does not exist.  Nothing to validate.  Exiting.");
	    exit(0);
	}
	if (!-r $tfile){
	    $logger->logdie("BCP .out file '$tfile' does not have read permissions");
	}
	if (-z $tfile){
	    $logger->logdie("BCP .out file '$tfile' has zero content");
	}

	@tabledotout = ($tfile);
    }
    else {
	#
	# All BCP .out files found in the specified directory shall be validated.
	#
	@tabledotout = glob("$directory/*.out") ;
    
	chomp @tabledotout;
    }



    if (scalar(@tabledotout) > 0) {

	foreach my $bcpfile ( @tabledotout ) {

	    if (-z $bcpfile){
		$logger->info("bcpfile '$bcpfile' has zero content.  Skipping this file.");
		next;
	    }

	    my $basename = basename($bcpfile);
	    my $childtable;
	    if ($basename =~ /(\w+)\.out$/){
		$childtable = $1;

		if (exists $qtabhash->{$childtable}){
		    
		    #
		    # Does the table in question reference any parent table?
		    #
		    if ( (exists $parenttables->{$childtable}) && (scalar(@{$parenttables->{$childtable}}) > 0)) {
			
			print "Processing child table '$childtable'\n";
			$logger->info("Processing bcpfile '$bcpfile' and corresponding parent BCP files");

			my $dbtuples;

			if (defined($database)){
			    #
			    # This function should ignore bottom most level table nodes.
			    # I.e. analysisfeature, feature_cvtermprop, etc.
			    #
			    # Note that dbtuples will contain massive amount of data.  
			    # Essentially all of the data values for each child table's foreign key references.
			    #


			    #
			    # Retrieve all of this table's parents' fields which are referenced by this table!
			    #
			    foreach my $parenttable ( sort @{$parenttables->{$childtable}} ){ 
				$dbtuples->{$childtable}->{$parenttable} = $prism->retrieve_foreign_keys($childtable, $parenttable, $greplines);
			    }

			}
			
			my ($childbcprecords, $parentbcprecords) = &retrieve_and_load_data($parenttables, $directory, $greplines, $bcpfile, $childtable);
			
			&validate_foreign_references($childtable, $childbcprecords, $greplines, $parentbcprecords, $dbtuples, $database);
		    }
		    else{
			$logger->info("Child table '$childtable' does not have any parent tables, skipping BCP file '$bcpfile'");
		    }
		    
		}
		else{
		    $logger->logdie("Table '$childtable' is not a qualified chado table");
		}
	    }
	    else{
		$logger->logdie("Could not extract table name from basename '$basename'");
	    }
	}
    }
    else{
	$logger->info("Found no BCP .out files in directory '$directory'");
    }
}
else {
    if (!-e $directory ) {
	$logger->logdie("directory '$directory' does not exist");
    }
    if (!-d $directory ) {
	$logger->logdie("'$directory' is not a directory");
    }
}


$logger->info("$0 processing has completed.  Please verify log4perl log file '$log4perl'");


#---------------------------------------------------------------------------------------------------------------------------------
#
#                                               END OF MAIN -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------------------------------------------------


#------------------------------------------------------------
# retrieve_and_load_data()
#
#------------------------------------------------------------
sub retrieve_and_load_data {
    
    my ($parents, $directory, $greplines, $bcpfile, $childtable) = @_;

    $logger->logdie("parents was not defined") if (!defined($parents));
    $logger->logdie("directory was not defined") if (!defined($directory));
    $logger->logdie("greplines was not defined") if (!defined($greplines));
    $logger->logdie("bcpfile was not defined") if (!defined($bcpfile));
    $logger->logdie("childtable was not defined") if (!defined($childtable));
    

    #
    # 1. Read in all of the key fields from the child table and store in hash
    # 2. Read in all of the foreign key fields from the parent tables and store in hash
    #
    my $childbcprecords = {};
    my $parentbcprecords = {};

    foreach my $ptable ( @{$parents->{$childtable}} ){
	
	my $pbcpfile = $directory . '/' . $ptable . '.out';
	
	if ((-e $pbcpfile) && (!-r $pbcpfile)){
	    $logger->logdie("parent BCP file '$pbcpfile' does not have read permissions for child '$bcpfile'");
	}

       

	#-----------------------------------------------------------------------------------------------------------------------------
	# Objective:
	#
	# Need to read in the contents of the child file and all of its parent files.
	# This data needs to be stored in a datahash where the important columns are organized by the column.
	# names.
	#
	#
	# We have determined that the child table does have a parent table and that both corresponding BCP files are in the directory.
	# From the grepline map-hash:
	# Need to determine which key field in the child table file references which foreign key in the parent table file.
	#
	#-----------------------------------------------------------------------------------------------------------------------------
	foreach my $childkey ( sort %{$greplines->{$childtable}->{'keys'}} ){

	    my $parenttable = $greplines->{$childtable}->{'keys'}->{$childkey}->[0];
	    my $parentkey   = $greplines->{$childtable}->{'keys'}->{$childkey}->[1];

	    #
	    # Only process correct child-parent pairs
	    #
	    next if ($parenttable ne $ptable);

	    my $childcolumn;
	    if ((exists $greplines->{$childtable}->{'columns'}->{$childkey}) and (defined($greplines->{$childtable}->{'columns'}->{$childkey}))){
		$childcolumn = $greplines->{$childtable}->{'columns'}->{$childkey};
	    }
	    else{
		$logger->logdie("childcolumn was not defined for child table '$childtable'");
	    }

	    my $childgrepline;
	    if ((exists $greplines->{$childtable}->{'record'}) and (defined($greplines->{$childtable}->{'record'}))){
		$childgrepline = $greplines->{$childtable}->{'record'};
	    }
	    else{
		$logger->logdie("childgrepline was not defined for child table '$childtable'");
	    }


	    my $parentcolumn;
	    if ((exists $greplines->{$parenttable}->{'columns'}->{$parentkey}) and (defined($greplines->{$parenttable}->{'columns'}->{$parentkey}))){
		$parentcolumn = $greplines->{$parenttable}->{'columns'}->{$parentkey};
	    }
	    else{
		$logger->logdie("parentcolumn was not defined for parent table '$parenttable'");
	    }



	    my $parentgrepline;
	    if ((exists $greplines->{$parenttable}->{'record'}) and (defined($greplines->{$parenttable}->{'record'}))){
		$parentgrepline = $greplines->{$parenttable}->{'record'};
	    }
	    else{
		$logger->logdie("parentgrepline was not defined for parent table '$parenttable'");
	    }


	    $logger->debug("childtable '$childtable' childkey '$childkey' childcolumn '$childcolumn' childgrepline '$childgrepline'".
			   "parenttable '$parenttable' parentkey '$parentkey' parentcolumn '$parentcolumn' parentgrepline '$parentgrepline'") if ($logger->is_debug());


	    #--------------------------------------------------------------------------------------------
	    # Now open and read the child file.  
	    # Read in entire line, but only extract the specific
	    # field/column which corresponds to the specific parent's field/column.
	    # Store the value in the child table hash.
	    #
	    #--------------------------------------------------------------------------------------------
	    open (CHILDFILE, "<$bcpfile") or $logger->logdie("Could not open and read child table's BCP file '$bcpfile': $!");
	    while (my $line = <CHILDFILE>){
		chomp $line;
		
		if ($line =~ /$childgrepline/){
		    # As many temp variables as the widest table
		    my @tmp = ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13);
		    
		    $childbcprecords->{$parenttable}->{$childkey}->{$tmp[$childcolumn]} = $tmp[$childcolumn];
		}
		else{
		    $logger->logdie("Could not parse line '$line' with child grepline: '$childgrepline'");
		}
	    }
	    #---------------------------------------------------------------------------------------------
	    # Now open and read the parent file.
	    # Read in the entire line, but only extract the specific 
	    # field/column which corresponds to the specific child's field/column.
	    # Store the value in the bcprecords hash.
	    #
	    #---------------------------------------------------------------------------------------------
	    if (!-e $pbcpfile){
		$logger->info("parent BCP file '$pbcpfile' does not exist for child '$bcpfile'.  Checking for child table '$childtable'\'s next parent BCP file");
		if (!defined($database)){
		    $logger->logdie("childtable '$childtable' references parent table '$ptable', however could not find the parent's BCP file in directory '$directory'.  You must re-run $0 and specify the target chado database so that the required data can be retrieved from the parent table 'cvterm' for validation");
		}

	    }
	    else {
		open (PARENTFILE, "<$pbcpfile") or $logger->logdie("Could not open and read parent '$parenttable' table's BCP file '$pbcpfile': $!");
		while (my $line = <PARENTFILE>){
		    chomp $line;
		    
		    if ($line =~ /$parentgrepline/){
			# As many temp variables as the widest table
			my @tmp = ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13);
			$parentbcprecords->{$parenttable}->{$childkey}->{$tmp[$parentcolumn]} = $tmp[$parentcolumn];
		    }
		    else{
			$logger->logdie("Could not parse line '$line' file '$pbcpfile' with parent grepline: '$parentgrepline'");
		    }
		}#	    while (my $line = <PARENTFILE>){
	    }


	}# 	foreach my $childkey ( sort %{$greplines->{$childtable}->{'keys'}} ){
    }#    foreach my $ptable ( @{$parents->{$childtable}} ){
    
    #------------------------------------------------------------
    # I'm tired.
    # Return the accumulated data.  
    # Let validate_foreign_references subroutine perform the validation.
    #
    #------------------------------------------------------------

    return ($childbcprecords, $parentbcprecords);

}# end sub




#---------------------------------------------
# validate_foreign_references()
#
#---------------------------------------------
sub validate_foreign_references {

    my ($childtable, $childbcprecords, $greplines, $parentbcprecords, $tablerecords, $database) = @_;

    foreach my $parenttable (sort keys %{$childbcprecords} ) {

	$logger->info("Validating all foreign key relations between child table '$childtable' and parent table '$parenttable'");


	foreach my $childkey (sort keys %{$childbcprecords->{$parenttable}} ) {
	    foreach my $childvalue (sort keys %{$childbcprecords->{$parenttable}->{$childkey}} ) {

		#
		# feature.dbxref_id is a nullable field
		#
		if (($childtable eq 'feature') && ($parenttable eq 'dbxref') && ($childkey eq 'dbxref_id') && ($childvalue eq '')){ 
		    next;
		}

		if (!exists $parentbcprecords->{$parenttable}->{$childkey}->{$childvalue}) {
		    #
		    # Could not find the corresponding value in the referenced parent table's BCP file's
		    # specified field/column, therefore need to check the already loaded parent table's
		    # columns...
		    #
		    if (defined($database)){


			my $parentkey = $greplines->{$childtable}->{'keys'}->{$childkey}->[1];

			if (!exists ($tablerecords->{$childtable}->{$parenttable}->{$parentkey}->{$childvalue}) ){

			    #----------------------------------------------------------------------------------------------
			    # editor:  sundaram@tigr.org
			    # date:    2005-10-09
			    # comment: The cvtermsynonym.type_id is a nullable field (foreign key reference between
			    #          cvtermsynonym.type_id and cvterm.cvterm_id.
			    #
			    if (($childtable eq 'cvtermsynonym') && ($childkey eq 'type_id') && ($parenttable eq 'cvterm')){
				#
				# While cvtermsynonym.type_id is a foreign key, it is nullable
				#
			    }
			    elsif  (($childtable eq 'cvterm') && ($childkey eq 'dbxref') && ($parenttable eq 'dbxref')){
				#
				# While cvterm.dbxref_id is a foreign key, it is nullable
				#
			    }
			    else {

				$logger->logdie("Could not find child table '$childtable'\'s child value '$childvalue' for column '$childkey' in parent table '$parenttable' nor BCP file in directory '$directory'.  The foreign key constraint between this child and parent table has been violated.  Contact sundaram\@tigr.org");
			    }
			}
		    }
		    else{
			$logger->logdie("You did not specify database, therefore $0 is only checking for foreign key constraints among the BCP files in the specified directory.  $0 could not find the value for the child table '$childtable' value '$childvalue' in the parent table '$parenttable' BCP file.  Perhaps the value is already loaded in the target chado database?  Please re-run this script specifying the chado database (and requisite database login credentials).");
		    }
		}
	    }
	}
    }
}


#--------------------------------------
# load_parenttables()
#
#--------------------------------------
sub load_parenttables {

    my $parenttables = {
			  'dbxref'                   => [ 'db'],
			  'cvterm'                   => [ 'cv','dbxref'],
			  'cvterm_relationship'      => [ 'cvterm'],
			  'cvtermpath'               => [ 'cvterm', 'cv' ],
			  'cvtermsynonym'            => [ 'cvterm'],
			  'cvterm_dbxref'            => [ 'cvterm','dbxref'],
			  'cvtermprop'               => [ 'cvterm' ],
			  'dbxrefprop'               => [ 'dbxref', 'cvterm' ],
			  'pub'                      => [ 'cvterm' ],
			  'pub_relationship'         => [ 'pub', 'cvterm' ],
			  'pub_dbxref'               => [ 'pub', 'dbxref' ],
			  'author'                   => [ 'contact' ],
			  'pub_author'               => [ 'author' , 'pub' ],
			  'pubprop'                  => [ 'pub', 'cvterm' ],
			  'organism_dbxref'          => [ 'organism', 'dbxref' ],
			  'organismprop'             => [ 'organism', 'cvterm' ],
			  'feature'                  => [ 'dbxref', 'organism', 'cvterm' ],
			  'featureloc'               => [ 'feature' ],
			  'feature_pub'              => [ 'feature', 'pub' ],
			  'featureprop'              => [ 'feature', 'cvterm' ],
			  'featureprop_pub'          => [ 'featureprop', 'pub' ],
			  'feature_dbxref'           => [ 'feature', 'dbxref' ],
			  'feature_relationship'     => [ 'feature', 'cvterm' ],
			  'feature_relationship_pub' => [ 'feature_relationship', 'pub' ],
			  'feature_relationshipprop' => [ 'feature_relationship', 'cvterm' ],
			  'feature_relprop_pub'      => [ 'feature_relationshipprop', 'pub' ],
			  'feature_cvterm'           => [ 'feature', 'cvterm', 'pub' ],
			  'feature_cvtermprop'       => [ 'feature_cvterm', 'cvterm' ],
			  'synonym'                  => [ 'cvterm' ],
			  'feature_synonym'          => [ 'synonym', 'feature', 'pub' ],
			  'analysisprop'             => [ 'analysis', 'cvterm' ],
			  'analysisfeature'          => [ 'analysis', 'feature' ]
		      };


    $logger->debug("parenttables:" . Dumper $parenttables) if $logger->is_debug;
    
    return $parenttables;
}



#--------------------------------------
# load_greplines()
#
#--------------------------------------
sub load_greplines {

    my ($r, $f) = @_;

    # field delimiter
    $f = '\?\?\s+\?\?' if (!defined($f));
    # row delimiter
    $r = '\?\?\?\?' if (!defined($r));
    # varchar
    my $v = '[\w|\s|\:|\;|\-|\.|\+|\/|\(|\)|\\n|\=|\\\|\,|\#|\'|\||\[|\]|\{|\}|\~|\?|\`|\>|\<|\"|\@|\%|\!|\^|\&|\*]';

    # NULLABLE place holder variable
    my $o = '[;;\w;;_\d|\d]*';

    # NOT NULLABLE place holder variable
    my $x = '[;;\w;;_\d|\d]+';


    my $hash = {
	     #
	     # 0 tableinfo_id        NUMERIC(9,0)  NOT NULL,
	     # 1 name                VARCHAR(30)   NOT NULL,
	     # 2 primary_key_column  VARCHAR(30)   NULL,
	     # 3 is_view             BIT           NOT NULL,
	     # 4 view_on_table_id    NUMERIC(9,0)  NULL,
	     # 5 superclass_table_id NUMERIC(9,0)  NULL,
	     # 6 is_updateable       BIT           NOT NULL,
	     # 7 modification_date   SMALLDATETIME NOT NULL
	     #
	     # uc1_tableinfo (name)
	     #
	     #              
	     'tableinfo' => {              #   0     1      2       3         4      5        6        7    
		              'record'  => "^($x)$f($v+)$f($v*)$f(\\d{1})$f(\\d*)$f(\\d*)$f(\\d{1})$f($v+)$r\$",
			      'columns' =>  {
				              'tableinfo_id'        => 0,
					      'name'                => 1,
					      'primary_key_column'  => 2,
					      'is_view'             => 3,
					      'view_on_table_id'    => 4,
					      'superclass_table_id' => 5,
					      'is_updateable'       => 6,
					      'modification_date'   => 7
					  }
			  },
	     #
	     #
	     # 0 project_id  NUMERIC(9,0) NOT NULL,
	     # 1 name        VARCHAR(255) NOT NULL,
	     # 2 description VARCHAR(255) NOT NULL
	     #
	     # uc1_project (name)
	     #
	     #            
 	     'project' => {              #  0      1      2 
		            'record'  => "^($x)$f($v+)$f($v+)$r\$",
			    'columns' => {
				            'project_id'  => 0,
					    'name'        => 1,
					    'description' => 2
					}
			},
	     #
	     # 0 contact_id  NUMERIC(9,0) NOT NULL,
	     # 1 name        VARCHAR(255) NOT NULL,
	     # 2 description VARCHAR(255) NULL
	     #
	     # uc1_contact (name) 
	     #
	     #            
	     'contact' => {               #   0     1     2
		             'record'  => "^($x)$f($v+)$f($v*)$r\$",
			     'columns' => {
				             'contact_id'  => 0,
					     'name'        => 1,
					     'description' => 2
					 }
 			 },
	     #
	     # 0 db_id       NUMERIC(9,0) NOT NULL,
	     # 1 name        VARCHAR(50)  NOT NULL,
	     # 2 contact_id  NUMERIC(9,0) NOT NULL,
	     # 3 description VARCHAR(255) NULL,
	     # 4 urlprefix   VARCHAR(255) NULL,
	     # 5 url         VARCHAR(255) NULL
	     #
	     # uc1_db (name)
	     #
	     #
	     'db' => {               #   0     1      2      3       4
		         'record' => "^($x)$f($v+)$f($v*)$f($v*)$f($v*)$r\$",
			 'columns' => {
			                 'db_id'       => 0,
					 'name'        => 1,
					 'description' => 2,
					 'urlprefix'   => 3,
					 'url'         => 4
				     }
		     },
	     #
	     # 0 dbxref_id   NUMERIC(9,0) NOT NULL,
	     # 1 db_id       NUMERIC(9,0) NOT NULL,
	     # 2 accession   VARCHAR(50)  NOT NULL,
	     # 3 version     VARCHAR(50)  NOT NULL,
	     # 4 description VARCHAR(255) NULL
	     #
	     # uc1_dbxref (db_id, accession, version)
	     #
	     'dbxref' => {              #  0      1     2      3      4
		           'record'  => "^($x)$f($x)$f($v+)$f($v*)$f($v*)$r\$",
			   'columns' => {
			                   'dbxref_id'   => 0,
					   'db_id'       => 1,
					   'accession'   => 2,
					   'version'     => 3,
					   'description' => 4
				       },
			    'keys'   => {
				              'db_id' => [
							  'db',
							  'db_id'
							  ]
						      }
		       },
	     #
	     # 0 cv_id      NUMERIC(9,0) NOT NULL,
	     # 1 name       VARCHAR(255) NOT NULL,
	     # 2 definition VARCHAR(255) NULL
	     #
	     # uc1_cv (name)
	     #
	     #        
	     'cv' => {              #   0     1      2
		        'record' => "^($x)$f($v+)$f($v*)$r\$",
			'columns' => {
			               'cv_id'      => 0,
				       'name'       => 1,
				       'definition' => 2
				   }
		    },
	     #
	     # 0 cvterm_id           NUMERIC(9,0) NOT NULL,
	     # 1 cv_id               NUMERIC(9,0) NOT NULL,
	     # 2 name                VARCHAR(255) NOT NULL,
	     # 3 definition          VARCHAR(255) NULL,
	     # 4 dbxref_id           NUMERIC(9,0) NULL,
	     # 5 is_obsolete         TINYINT      NOT NULL,
	     # 6 is_relationshiptype BIT          NOT NULL
	     #
	     # uc1_cvterm (name, cv_id, is_obsolete)
	     #
	     #  
	     'cvterm' => {               #   0     1     2     3      4       5       6
		            'record'  => "^($x)$f($x)$f($v+)$f($v*)$f($v*)$f(\\d+)$f(\\d{1})$r\$",
			    'columns' => {
				           'cvterm_id'           => 0,
					   'cv_id'               => 1,
					   'name'                => 2,
					   'definition'          => 3,
					   'dbxref_id'           => 4,
					   'is_obsolete'         => 5,
					   'is_relationshiptype' => 6
				       },
			    'keys' => {
				            'cv_id'   => [
							  'cv',
							  'cv_id'
							  ],
					    'dbxref_id' => [
							    'dbxref',
							    'dbxref_id'
							    ]
							}
			},
	     #
	     # 0 cvterm_relationship_id NUMERIC(9,0) NOT NULL,
	     # 1 type_id                NUMERIC(9,0) NOT NULL,
	     # 2 subject_id             NUMERIC(9,0) NOT NULL,
	     # 3 object_id              NUMERIC(9,0) NOT NULL
	     #
	     # uc1_cvterm_relationship (type_id, subject_id, object_id)
	     #
	     #  
	     'cvterm_relationship' => {               # 
		                         'record'  => "^($x)$f($x)$f($x)$f($x)$r\$",
					 'columns' => {
					                  'cvterm_relationship_id' => 0,
							  'type_id'                => 1,
							  'subject_id'             => 2,
							  'object_id'              => 3
					 },
					 'keys'   => {
					                'type_id' => [
								      'cvterm',
								      'cvterm_id'
								      ],
							'subject_id' => [
									 'cvterm',
									 'cvterm_id'
								       ],
							'object_id'  => [
									 'cvterm',
									 'cvterm_id'
									 ]
								     }
				     },

	     #
	     # 0 cvtermpath_id NUMERIC(9,0) NOT NULL,
	     # 1 type_id       NUMERIC(9,0) NULL,
	     # 2 subject_id    NUMERIC(9,0) NOT NULL,
	     # 3 object_id     NUMERIC(9,0) NOT NULL,
	     # 4 cv_id         NUMERIC(9,0) NOT NULL,
	     # 5 pathdistance  NUMERIC(9,0) NULL
	     #
	     # uc1_cvtermpath (subject_id, object_id, type_id, pathdistance)
	     #
	     #
	     'cvtermpath' => {               #  0      1     2    3      4     5
		                'record'  => "^($x)$f($x)$f($x)$f($x)$f($x)$f(\\d*)$r\$",
				'columns' => {
				                 'cvtermpath_id' => 0,
						 'type_id'       => 1,
						 'subject_id'    => 2,
						 'object_id'     => 3,
						 'cv_id'         => 4,
						 'pathdistance'  => 5
					     },
				'keys'   => {
				                'type_id' => [
							      'cvterm',
							      'cvterm_id'
							      ],
						'subject_id'  => [
								  'cvterm',
								  'cvterm_id'
								  ],
						'object_id'  => [
								 'cvterm',
								 'cvterm_id'
								 ],   
						'cv_id'   => [
							      'cv',
							      'cv_id'
							      ]
							     }
			    },
	     #
	     # 0 cvtermsynonym_id NUMERIC(9,0) NOT NULL,
	     # 1 cvterm_id        NUMERIC(9,0) NOT NULL,
	     # 2 synonym          VARCHAR(255) NOT NULL,
	     # 3 type_id          NUMERIC(9,0) NULL
	     #
	     # uc1_cvtermsynonym (cvterm_id, synonym)
	     #
	     'cvtermsynonym' => {               #   0    1          2        3
		                   'record'  => "^($x)$f($x)$f($v\{1,1024})$f($o)$r\$",
				   'columns' => {
				                   'cvtermsynonym_id' => 0,
						   'cvterm_id'        => 1,
						   'synonym'          => 2,
						   'type_id'          => 3
					       },
				   'keys'   => {
				                  'cvterm_id' => [
								  'cvterm',
								  'cvterm_id'
								  ],
						  'type_id' => [
								'cvterm',
						                'cvterm_id'
								]
							    }
			       },
	     #
	     # 0 cvterm_dbxref_id  NUMERIC(9,0) NOT NULL,
	     # 1 cvterm_id         NUMERIC(9,0) NOT NULL,
	     # 2 dbxref_id         NUMERIC(9,0) NOT NULL,
	     # 3 is_for_definition BIT          NOT NULL
	     #
	     # uc1_cvterm_dbxref (cvterm_id, dbxref_id)
	     #
	     #
	     'cvterm_dbxref' => {               #   0     1    2        3
		                   'record'  => "^($x)$f($x)$f($x)$f(\\d{1})$r\$",
				   'columns' => {
				                    'cvterm_dbxref_id'  => 0,
						    'cvterm_id'         => 1,
						    'dbxref_id'         => 2,
						    'is_for_definition' => 3
						},
				   'keys'   => {
				                  'cvterm_id' => [
								  'cvterm',
								  'cvterm_id'
								  ],
						  'dbxref_id'  => [
								   'dbxref',
								   'dbxref_id'
								 ]
							     }
			       },
	     #
	     # 0 cvtermprop_id NUMERIC(9,0) NOT NULL,
	     # 1 cvterm_id     NUMERIC(9,0) NOT NULL,
	     # 2 type_id       NUMERIC(9,0) NOT NULL,
	     # 3 value         VARCHAR(255) NOT NULL,
	     # 4 rank          NUMERIC(9,0) NOT NULL
	     #
	     # uc1_cvtermprop (cvterm_id, type_id, value, rank)
	     #
	     #  
	     'cvtermprop' => {               #  0      1    2      3       4
		                'record'  => "^($x)$f($x)$f($x)$f($v+)$f(\\d+)$r\$",
				'columns' => {
				                'cvtermprop_id' => 0,
						'cvterm_id'     => 1,
						'type_id'       => 2,
						'value'         => 3,
						'rank'          => 4
					    },
				'keys'   => {
				               'cvterm_id' => [
							       'cvterm',
							       'cvterm_id'
							     ],
					       'type_id' => [
							     'cvterm',
							     'cvterm_id'
							     ]
							 }
			    },
	     #
	     # 0 dbxrefprop_id NUMERIC(9,0) NOT NULL,
	     # 1 dbxref_id     NUMERIC(9,0) NOT NULL,
	     # 2 type_id       NUMERIC(9,0) NOT NULL,
	     # 3 value         VARCHAR(255) NOT NULL,
	     # 4 rank          NUMERIC(9,0) NOT NULL
	     #
	     # uc1_dbxrefprop (dbxref_id, type_id, value, rank)
	     #
	     #
	     'dbxrefprop' => {               #   0     1    2      3      4
		                'record'  => "^($x)$f($x)$f($x)$f($v+)$f(\\d+)$r\$",
				'columns' => {
				                'dbxrefprop_id' => 0,
						'dbxref_id'     => 1,
						'type_id'       => 2,
						'value'         => 3,
						'rank'          => 4
					    },
				'keys'   => {
				               'dbxref_id' => [
							       'dbxref',
							       'dbxref_id'
							       ],
					       'type_id' => [
							     'cvterm',
							     'cvterm_id'
							     ]
							 }
			    },
	     #
	     # 0 organism_id  NUMERIC(9,0) NOT NULL,
	     # 1 abbreviation VARCHAR(50)  NULL,
	     # 2 genus        VARCHAR(50)  NOT NULL,
	     # 3 species      VARCHAR(50)  NOT NULL,
	     # 4 common_name  VARCHAR(100) NULL,
	     # 5 comment      VARCHAR(255) NULL
	     #
	     # uc1_organism (genus, species)
	     #
	     #
	     'organism' => {                 #   0     1      2      3      4      5
		                'record'  => "^($x)$f($v*)$f($v+)$f($v+)$f($v*)$f($v*)$r\$",
				'columns' => {
				                'organism_id'  => 0,
						'abbreviation' => 1,
						'genus'        => 2,
						'species'      => 3,
						'common_name'  => 4,
						'comment'      => 5
					    }
			    },
	     #
	     # 0 organism_dbxref_id NUMERIC(9,0) NOT NULL,
	     # 1 organism_id        NUMERIC(9,0) NOT NULL,
	     # 2 dbxref_id          NUMERIC(9,0) NOT NULL
	     #
	     # uc1_organism_dbxref (organism_id, dbxref_id)
	     #
	     #
	     'organism_dbxref' => {                #  0      1     2
		                      'record'  => "^($x)$f($x)$f($x)$r\$",
				      'columns' => {
					              'organism_dbxref_id' => 0,
						      'organism_id'        => 1,
						      'dbxref_id'          => 2
						  },
				      'keys'   => {
					            'organism_id' => [
								      'organism',
								      'organism_id'
								      ],
						    'dbxref_id' => [
								    'dbxref',
								    'dbxref_id'
								    ]
								}
				  },

	     #
	     # 0 organismprop_id NUMERIC(9,0) NOT NULL,
	     # 1 organism_id     NUMERIC(9,0) NOT NULL,
	     # 2 type_id         NUMERIC(9,0) NOT NULL,
	     # 3 value           VARCHAR(255) NOT NULL,
	     # 4 rank            NUMERIC(9,0) NOT NULL
	     #
	     # uc1_organismprop (organism_id, type_id, value, rank)
	     #
	     #
	     'organismprop' => {               #   0     1     2     3       4
		                  'record'  => "^($x)$f($x)$f($x)$f($v+)$f(\\d+)$r\$",
				  'columns' => {
				                  'organismprop_id' => 0,
						  'organism_id'     => 1,
						  'type_id'         => 2,
						  'value'           => 3,
						  'rank'            => 4
					      },
				  'keys'   => {
				                 'organism_id' => [
								   'organism',
								   'organism_id'
								 ],
						 'type_id' => [
							       'cvterm',
							       'cvterm_id'
							       ]
							   }
			      },
	     #
	     # 0  pub_id        NUMERIC(9,0) NOT NULL,
	     # 1  title         VARCHAR(255) NULL,
	     # 2  volumetitle   VARCHAR(255) NULL,
	     # 3  volume        VARCHAR(255) NULL,
	     # 4  series_name   VARCHAR(255) NULL,
	     # 5  issue         VARCHAR(255) NULL,
	     # 6  pyear         VARCHAR(255) NULL,
	     # 7  pages         VARCHAR(255) NULL,
	     # 8  miniref       VARCHAR(255) NOT NULL,
	     # 9  uniquename    VARCHAR(255) NOT NULL,
	     # 10 type_id       NUMERIC(9,0) NOT NULL,
	     # 11 is_obsolete   BIT          NOT NULL,
	     # 12 publisher     VARCHAR(255) NULL,
	     # 13 pubplace      VARCHAR(255) NULL
	     #
	     # uc1_pub (uniquename, type_id)
	     #
	     #
	     'pub' => {              #   0     1      2      3      4      5      6      7      8      9      10       11       12     13
		         'record' => "^($x)$f($v*)$f($v*)$f($v*)$f($v*)$f($v*)$f($v*)$f($v*)$f($v+)$f($v+)$f(\\d+)$f(\\d{1})$f($v*)$f($v*)$r\$",
			 'columns' => {
			                 'pub_id'      => 0,
					 'title'       => 1,
					 'volumetitle' => 2,
					 'volume'      => 3,
					 'series_name' => 4,
					 'issue'       => 5,
					 'pyear'       => 6,
					 'pages'       => 7,
					 'miniref'     => 8,
					 'uniquename'  => 9,
					 'type_id'     => 10,
					 'is_obsolete' => 11,
					 'publisher'   => 12,
					 'pubplace'    => 13
				     },
			 'keys'   => {
			               'type_id' => [
						     'cvterm',
						     'cvterm_id'
						   ]
				   }
		     },
             #
             # 0 pub_relationship_id NUMERIC(9,0) NOT NULL,
	     # 1 subject_id          NUMERIC(9,0) NOT NULL,
	     # 2 object_id           NUMERIC(9,0) NOT NULL,
	     # 3 type_id             NUMERIC(9,0) NOT NULL
	     #
	     # uc1_pub_relationship (subject_id, object_id, pub_id)
	     #
	     #  
             'pub_relationship' => {               #   0     1     2    3
		                      'record'  => "^($x)$f($x)$f($x)$f($x)$r\$",
				      'columns' => {
					              'pub_relationship_id' => 0,
						      'subject_id'          => 1,
						      'object_id'           => 2,
						      'type_id'             => 3
						  },
				      'keys'   => {
					              'subject_id' => [
								       'cvterm',
								       'cvterm_id'
								       ],
						     'object_id' => [
								     'cvterm',
								     'cvterm_id'
								   ],
						     'type_id' => [
								   'cvterm',
								   'cvterm_id'
								   ]
						 }
				  },
	     
	    

	     #
             # 0 pub_dbxref_id NUMERIC(9,0) NOT NULL,
	     # 1 pub_id        NUMERIC(9,0) NOT NULL,
	     # 2 dbxref_id     NUMERIC(9,0) NOT NULL
	     #
	     # uc1_pub_dbxref (pub_id, dbxref_id)
	     #
	     #
	     'pub_dbxref' => {
		                'record'  => undef,     # not encoded
				'columns' => {
				                'pub_dbxref_id' => 0,
						'pub_id'        => 1,
						'dbxref_id'     => 2
					    },
				'keys' => {
				             'pub_id' => [
							  'pub',
							  'pub_id'
							  ],
					     'dbxref_id' => [
							     'dbxref',
							     'dbxref_id'
							     ]
							 }
			    },

	     #
	     # 1 author_id  NUMERIC(9,0) NOT NULL,
	     # 2 contact_id NUMERIC(9,0) NOT NULL,
	     # 3 surname    VARCHAR(100) NOT NULL,
	     # 4 givennames VARCHAR(100) NULL,
	     # 5 suffix     VARCHAR(100) NULL
	     #
	     # uc1_author (surname, givennames, suffix)
	     #
	     #
	     'author' => {
		           'record'  => undef,     # not encoded
			   'columns' => {
			                   'author_id'  => 0,
					   'contact_id' => 1,
					   'surname'    => 2,
					   'givennames' => 3,
					   'suffix'     => 4
				       },
			   'keys' => {
			                 'contact_id' => [
							  'contact',
							  'contact_id'
							  ]
						      }
		       },
	     #
	     # 1 pub_author_id NUMERIC(9,0) NOT NULL,
	     # 2 author_id     NUMERIC(9,0) NOT NULL,
	     # 3 pub_id        NUMERIC(9,0) NOT NULL,
	     # 4 rank          NUMERIC(9,0) NOT NULL,
	     # 5 editor        BIT          NOT NULL
	     #
	     # uc1_pub_author (author_id, pub_id) 
	     #
	     #
	     'pub_author' => {
		                'record'  => undef,     # not encoded
				'columns' => {
				                'pub_author_id' => 0,
						'author_id'     => 1,
						'pub_id'        => 2,
						'rank'          => 3,
						'editor'        => 4
					    },
				'keys'   => {
				               'author_id' => [
							       'author',
							       'author_id'
							     ],
					       'pub_id' => [
							    'pub',
							    'pub_id'
							    ]
							}
			    },
	     #
	     # 1 pubprop_id NUMERIC(9,0) NOT NULL,
	     # 2 pub_id     NUMERIC(9,0) NOT NULL,
	     # 3 type_id    NUMERIC(9,0) NOT NULL,
	     # 4 value      VARCHAR(255) NOT NULL,
	     # 5 rank       NUMERIC(9,0) NULL
	     #
	     # uc1_pubprop (pub_id, type_id, value)
	     #
	     #
	     'pubprop' => {
		             'record' => undef,     # not encoded
			     'columns' => {
				             'pubprop_id' => 0,
					     'pub_id'     => 1,
					     'type_id'    => 2,
					     'value'      => 3,
					     'rank'       => 4
			     },
			     'keys'   => {
				            'pub_id' => [
							 'pub',
							 'pub_id'
							 ],
					    'type_id' => [
							  'cvterm',
							  'cvterm_id'
							  ]
						      }
			 },

	     #--------------------------------------------------------------------------------------------
	     # editor:  sundaram@tigr.org
	     # date:    2005-10-14
	     # bgzcase: 2152
	     # URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2152
	     # comment: The new chado schema (version chado-v1r3b4) introduces a new column feature.is_obsolete
	     #


	     #
	     # 0  feature_id       NUMERIC(9,0)  NOT NULL,
	     # 1  dbxref_id        NUMERIC(9,0)  NULL,
	     # 2  organism_id      NUMERIC(9,0)  NOT NULL,
	     # 3  name             VARCHAR(255)  NULL,
	     # 4  uniquename       VARCHAR(50)   NOT NULL,
	     # 5  residues         TEXT          NULL,
	     # 6  seqlen           NUMERIC(9,0)  NULL,
	     # 7  md5checksum      CHAR(32)      NULL,
	     # 8  type_id          NUMERIC(9,0)  NOT NULL,
	     # 9  is_analysis      BIT           NOT NULL,
	     # 10 is_obsolete      BIT           NOT NULL,
	     # 11 timeaccessioned  SMALLDATETIME NOT NULL,
	     # 12 timelastmodified SMALLDATETIME NOT NULL
	     #
	     # uc1_feature (organism_id, uniquename, type_id)
	     #
	     #    
	     'feature' => {              #  0      1     2         3           4          5      6       7     8        9      10     11       12
		             'record' => "^($x)$f($o)$f($x)$f($v\{0,255})$f($v\{1,50})$f($v*)$f(\\d*)$f($v*)$f($x)$f(\\d{1})$f(\\d{1})$f($v+)$f($v+)$r\$",
#		             'record' => "^($x)$f($o)$f($x)$f($v\{0,255})$f($v\{1,50})$f($v*)$f(\\d*)$f($v*)$f($x)$f($v+)$f($v+)$f($v+)$r\$", # chado-v1r1b0
			     'columns' => {
				 'feature_id'       => 0,
				 'dbxref_id'        => 1,
				 'organism_id'      => 2,
				 'name'             => 3,
				 'uniquename'       => 4,
				 'residues'         => 5,
				 'seqlen'           => 6,
				 'md5checksum'      => 7,
				 'type_id'          => 8,
				 'is_analysis'      => 9,
				 'is_obsolete'      => 10,
				 'timeaccessioned'  => 11,
				 'timelastmodified' => 12
			     },
			     'keys'   => {
				            'dbxref_id'   => [
							      'dbxref',
							      'dbxref_id'
							     ],
					    'organism_id' => [
							      'organism',
							      'organism_id'
							      ],
					    'type_id' => [
							  'cvterm',
							  'cvterm_id'
							  ]
						      }
			 },
			 
	     #
             # 0  featureloc_id   NUMERIC(9,0) NOT NULL,
	     # 1  feature_id      NUMERIC(9,0) NOT NULL,
	     # 2  srcfeature_id   NUMERIC(9,0) NULL,
	     # 3  fmin            NUMERIC(9,0) NULL,
	     # 4  is_fmin_partial BIT          NOT NULL,
	     # 5  fmax            NUMERIC(9,0) NULL,
	     # 6  is_fmax_partial BIT          NOT NULL,
	     # 7  strand          NUMERIC(9,0) NULL,
	     # 8  phase           NUMERIC(9,0) NULL,
	     # 9  residue_info    TEXT         NULL,
	     # 10 locgroup        NUMERIC(9,0) NOT NULL,
	     # 11 rank            NUMERIC(9,0) NOT NULL
	     #
	     # uc1_featureloc (feature_id, locgroup, rank)
	     #
             'featureloc' => {                 #  0      1     2      3       4         5       6          7            8       9      10      11
		                  'record'  => "^($x)$f($x)$f($o)$f(\\d*)$f(\\d{1})$f(\\d*)$f(\\d{1})$f(\[\\d|\\-]*)$f(\\d*)$f($v*)$f(\\d+)$f(\\d+)$r\$",
#		                  'record'  => "^($x)$f($x)$f($o)$f(\\d*)$f($v+)$f(\\d*)$f($v+)$f(\[\\d|\\-]*)$f(\\d*)$f($v*)$f(\\d+)$f(\\d+)$r\$", # chado-v1r1b0
				  'columns' => {
				                  'featureloc_id'   => 0,
						  'feature_id'      => 1,
						  'srcfeature_id'   => 2,
						  'fmin'            => 3,
						  'is_fmin_partial' => 4,
						  'fmax'            => 5,
						  'is_fmax_partial' => 6,
						  'strand'          => 7,
						  'phase'           => 8,
						  'residue_info'    => 9,
						  'locgroup'        => 10,
						  'rank'            => 11
					      },
				   'keys'   => {
				                   'feature_id' => [
								    'feature',
								    'feature_id'
								    ],
						   'srcfeature_id' => [
								       'feature',
								       'feature_id'
								       ]
								   }
			      },
	     #
             # 0 feature_pub_id NUMERIC(9,0) NOT NULL,
	     # 1 feature_id     NUMERIC(9,0) NOT NULL,
	     # 2 pub_id         NUMERIC(9,0) NOT NULL
	     #
	     # uc1_featurepub (feature_id, pub_id)
	     #
	     #
	     'featurepub' => {
		                'record'  => undef,     # not encoded
				'columns' => {
				               'feature_pub_id' => 0,
					       'feature_id'     => 1,
					       'pub_id'         => 2
					   },
				'keys'   => {
				               'feature_id' => [
								'feature',
								'feature_id'
								],
					       'pub_id' => [
							    'pub',
							    'pub_id'
							    ]
							}
			    },
             #
	     # 0 featureprop_id NUMERIC(9,0)  NOT NULL,
	     # 1 feature_id     NUMERIC(9,0)  NOT NULL,
	     # 2 type_id        NUMERIC(9,0)  NOT NULL,
	     # 3 value          VARCHAR(1000) NOT NULL,
	     # 4 rank           NUMERIC(9,0)  NOT NULL
	     #
	     # uc1_featureprop (feature_id, type_id, value, rank)
	     #
	     #
             'featureprop' => {               #   0     1     2        3           4
		                 'record'  => "^($x)$f($x)$f($x)$f($v\{1,1000})$f(\\d+)$r\$",
#		                 'record'  => "^($x)$f($x)$f($x)$f($v\{1,1000})$f(\\d*)$r\$", # chado-v1r1b0
				 'columns' => {
				                 'featureprop_id' => 0,
						 'feature_id'     => 1,
						 'type_id'        => 2,
						 'value'          => 3,
						 'rank'           => 4
					     },
				 'keys'   => {
				                 'feature_id' => [
								  'feature',
								  'feature_id'
								  ],
						 'type_id' => [
							       'cvterm',
							        'cvterm_id'
							       ]
							   }
			     },
	     #
             # 0 featureprop_pub_id NUMERIC(9,0) NOT NULL,
	     # 1 featureprop_id     NUMERIC(9,0) NOT NULL,
	     # 2 pub_id             NUMERIC(9,0) NOT NULL
	     #
	     # uc1_featureprop_pub (featureprop_id, pub_id)
	     #
	     #
	     'featureprop_pub' => {
		                    'record'  => undef,     # not encoded
				    'columns' => {
					            'featureprop_pub_id' => 0,
						    'featureprop_id'     => 1,
						    'pub_id'             => 2
						},
				    'keys'   => {
 					           'featureprop_id' => [
									'featureprop',
									'featureprop_id'
									],
						   'pub_id' => [
								'pub',
								'pub_id'
								]
							    }
				},
	     #
             # 0 feature_dbxref_id NUMERIC(9,0) NOT NULL,
	     # 1 feature_id        NUMERIC(9,0) NOT NULL,
	     # 2 dbxref_id         NUMERIC(9,0) NOT NULL,
	     # 3 is_current        BIT          NOT NULL
	     #
	     # uc1_feature_dbxref (feature_id, dbxref_id)
	     #
	     #
	     'feature_dbxref' => {              #   0     1     2        3
		                   'record'  => "^($x)$f($x)$f($x)$f(\\d{1})$r\$",
				   'columns' => {
				                   'feature_dbxref_id' => 0,
						   'feature_id'        => 1,
						   'dbxref_id'         => 2,
						   'is_current'        => 3
					       },
				   'keys'   => {
				                  'feature_id' => [
								   'feature',
								   'feature_id'
								   ],
						   'dbxref_id' => [
								   'dbxref',
								   'dbxref_id'
								   ]
							       }
			       },
	     # 
	     # 0 feature_relationship_id NUMERIC(9,0) NOT NULL,
	     # 1 subject_id              NUMERIC(9,0) NOT NULL,
	     # 2 object_id               NUMERIC(9,0) NOT NULL,
	     # 3 type_id                 NUMERIC(9,0) NOT NULL,
	     # 4 rank                    NUMERIC(9,0) NULL
	     #
	     # uc1_feature_relationship (subject_id, object_id, type_id)
	     #
	     #
	     'feature_relationship' => {               #   0     1     2     3     4
		                          'record'  => "^($x)$f($x)$f($x)$f($x)$f(\\d*)$r\$",
					  'columns' => {
					                 'feature_relationship_id' => 0,
							 'subject_id'              => 1,
							 'object_id'               => 2,
							 'type_id'                 => 3,
							 'rank'                    => 4
						     },
					  'keys'   => {
					                 'subject_id' => [
									  'feature',
									  'feature_id'
									  ],
							 'object_id' => [
									 'feature',
									 'feature_id'
									 ],
							 'type_id' => [
								       'cvterm',
								       'cvterm_id'
								       ]
								   }
				      },

	     #
	     # 0 feature_relationship_pub_id NUMERIC(9,0) NOT NULL,
	     # 1 feature_relationship_id     NUMERIC(9,0) NOT NULL,
	     # 2 pub_id                      NUMERIC(9,0) NOT NULL
	     #
	     # uc1_feature_relationship_pub (feature_relationship_id, pub_id)
	     #
	     #
	     'feature_relationship_pub' => {
		                              'record'  => undef,     # not encoded
					      'columns' => {
						             'feature_relationship_pub_id' => 0,
							     'feature_relationship_id'     => 1,
							     'pub_id'                      => 2
							 },
					      'keys'   => {
 						             'feature_relationship_id' => [
											   'feature_relationship',
											   'feature_relationship_id'
											   ],
							     'pub_id' => [
									  'pub',
									  'pub_id'
									  ]
								      }
					  },
	     #
	     # 0 feature_relationshipprop_id NUMERIC(9,0) NOT NULL,
	     # 1 feature_relationship_id     NUMERIC(9,0) NOT NULL,
	     # 2 type_id                     NUMERIC(9,0) NOT NULL,
	     # 3 value                       VARCHAR(255) NOT NULL,
	     # 4 rank                        NUMERIC(9,0) NOT NULL
	     #
	     # uc1_feature_relationshipprop (feature_relationship_id, type_id, rank)
	     #
	     #
	     'feature_relationshipprop' => {
		                              'record'  => undef,     # not encoded
					      'columns' => {
						             'feature_relationshipprop_id' => 0,
							     'feature_relationship_id'     => 1,
							     'type_id'                     => 2,
							     'value'                       => 3,
							     'rank'                        => 4
							 },
					      'keys'   => {
						             'feature_relationship_id' => [
											   'feature_relationship',
											   'feature_relationship_id'
											   ],
							      'type_id' => [
									    'cvterm',
									    'cvterm_id'
									    ],
									}
					  },
	     #
	     #
	     # 0 feature_relprop_pub_id NUMERIC(9,0) NOT NULL,
	     # 1 feature_relationshipprop_id     NUMERIC(9,0) NOT NULL,
	     # 2 pub_id                          NUMERIC(9,0) NOT NULL
	     #
	     # uc1_feature_relprop_pub (feature_relationshipprop_id, pub_id)
	     #
	     #
	     'feature_relprop_pub' => {
		                        'record'  => undef,     # not encoded
					'columns' => {
					                 'feature_relprop_pub_id'      => 0,
							 'feature_relationshipprop_id' => 1,
							 'pub_id'                      => 2
						     },
					'keys'    => {
					                'feature_relationshipprop_id' => [
											  'feature_relationshipprop',
											  'feature_relationshipprop_id'
											  ],
							'pub_id' => [
								     'pub',
								     'pub_id'
								     ]
								 }
				    },

	     #
	     # 0 feature_cvterm_id NUMERIC(9,0) NOT NULL,
	     # 1 feature_id        NUMERIC(9,0) NOT NULL,
	     # 2 cvterm_id         NUMERIC(9,0) NOT NULL,
	     # 3 pub_id            NUMERIC(9,0) NOT NULL
	     #
	     # uc1_feature_cvterm (feature_id, cvterm_id, pub_id)
	     #
	     # 
             'feature_cvterm' => {               #   0     1     2     3 
		                    'record'  => "^($x)$f($x)$f($x)$f($x)$r\$",
				    'columns' => {
					            'feature_cvterm_id' => 0,
						    'feature_id'        => 1,
						    'cvterm_id'         => 2,
						    'pub_id'            => 3
						},
				    'keys'   => {
					            'feature_id' => [
								     'feature',
								     'feature_id'
								     ],
						    'cvterm_id' => [
								    'cvterm',
								    'cvterm_id'
								    ],
						    'pub_id' => [
								 'pub',
								 'pub_id'
								 ]
							     }
				},

	     #
	     #
	     # 0 feature_cvtermprop_id NUMERIC(9,0) NOT NULL,
	     # 1 feature_cvterm_id     NUMERIC(9,0) NOT NULL,
	     # 2 type_id               NUMERIC(9,0) NOT NULL,
	     # 3 value                 VARCHAR(255) NOT NULL,
	     # 4 rank                  NUMERIC(9,0) NOT NULL
	     #
	     # uc1_feature_cvtermprop (feature_cvterm_id, type_id, rank)
	     #
	     #
	     'feature_cvtermprop' => {               #   0     1     2     3       4
		                        'record'  => "^($x)$f($x)$f($x)$f($v+)$f(\\d+)$r\$",
					'columns' => {
					                'feature_cvtermprop_id' => 0,
							'feature_cvterm_id'     => 1,
							'type_id'               => 2,
							'value'                 => 3,
							'rank'                  => 4
						    },
					'keys'   => {
					              'feature_cvterm_id' => [
									      'feature_cvterm',
									      'feature_cvterm_id'
									      ],
						       'type_id' => [
								     'cvterm',
								     'cvterm_id'
								     ]
								 }
				    },
	     # 
	     # 0 synonym_id   NUMERIC(9,0) NOT NULL,
	     # 1 name         VARCHAR(255) NOT NULL,
	     # 2 type_id      NUMERIC(9,0) NOT NULL,
	     # 3 synonym_sgml VARCHAR(255) NOT NULL
	     #
	     # uc1_synonym (name, type_id)
	     #
	     #
	     'synonym' => {
		              'record'  => undef,     # not encoded
			      'columns' => {
				              'synonym_id'   => 0,
					      'name'         => 1,
					      'type_id'      => 2,
					      'synonym_sgml' => 3
					  },
			      'keys'   => {
 				            'type_id' => [
							  'cvterm',
							  'cvterm_id'
							  ],
						      }
			  },
	     #
	     # 0 feature_synonym_id NUMERIC(9,0) NOT NULL,
	     # 1 synonym_id         NUMERIC(9,0) NOT NULL,
	     # 2 feature_id         NUMERIC(9,0) NOT NULL,
	     # 3 pub_id             NUMERIC(9,0) NOT NULL,
	     # 4 is_current         BIT          NOT NULL,
	     # 5 is_internal        BIT          NOT NULL
	     
	     # uc1_feature_synonym (synonym_id, feature_id, pub_id)
	     #
	     #
	     'feature_synonym' => {
		                     'record'  => undef,     # not encoded
				     'columns' => {
					            'feature_synonym_id' => 0,
						    'synonym_id'         => 1,
						    'feature_id'         => 2,
						    'pub_id'             => 3,
						    'is_current'         => 4,
						    'is_internal'        => 5
						},
				     'keys'   => {
					            'synonym_id' => [
								     'synonym',
								     'synonym_id'
								     ],
						    'feature_id' => [
								     'feature',
								     'feature_id'
								     ],
						     'pub_id' => [
								  'pub',
								  'pub_id'
								  ]
							      }
				 },

	     #
	     # 0  analysis_id    NUMERIC(9,0)  NOT NULL,
	     # 1  name           VARCHAR(255)  NULL,
	     # 2  description    VARCHAR(255)  NULL,
	     # 3  program        VARCHAR(50)   NOT NULL,
	     # 4  programversion VARCHAR(50)   NOT NULL,
	     # 5  algorithm      VARCHAR(50)   NULL,
	     # 6  sourcename     VARCHAR(255)  NULL,
	     # 7  sourceversion  VARCHAR(50)   NULL,
	     # 8  sourceuri      VARCHAR(255)  NULL,
	     # 9  timeexecuted   SMALLDATETIME NOT NULL
	     #
	     # uc1_analysis (program, programversion, sourcename)
	     #
	     #
	     'analysis' => {              #   0        1          2              3              4            5            6            7           8            9
		             'record'  => "^($x)$f($v\{0,255})$f($v\{0,255})$f($v\{1,50})$f($v\{1,50})$f($v\{0,50})$f($v\{0,255})$f($v\{0,50})$f($v\{0,255})$f($v+)$r\$",
			     'columns' => {
				            'analysis_id'    => 0,
					    'name'           => 1,
					    'description'    => 2,
					    'program'        => 3,
					    'programversion' => 4,
					    'algorithm'      => 5,
					    'sourcename'     => 6,
					    'sourceversion'  => 7,
					    'sourceuri'      => 8,
					    'timeexecuted'   => 9
					}
			 },
		     
	     #
	     # 0 analysisprop_id NUMERIC(9,0) NOT NULL,
	     # 1 analysis_id     NUMERIC(9,0) NOT NULL,
	     # 2 type_id         NUMERIC(9,0) NOT NULL,
	     # 3 value           VARCHAR(255) NULL
	     #
	     # uc1_analysisprop (analysis_id, type_id, value)
	     #
	     #
	     'analysisprop' => {               #   0     1     2       3
		                  'record'  => "^($x)$f($x)$f($x)$f($v\{0,255})$r\$",
				  'columns' => {
				                  'analysisprop_id' => 0,
						  'analysis_id'     => 1,
						  'type_id'         => 2,
						  'value'           => 3
					      },
				  'keys'   => {
				                 'analysis_id' => [
								   'analysis',
								   'analysis_id'
								   ],
						 'type_id' => [
							       'cvterm',
							       'cvterm_id'
							       ]
							   }
			      },
	     #
	     # 0 analysisfeature_id NUMERIC(9,0) NOT NULL,
	     # 1 feature_id         NUMERIC(9,0) NOT NULL,
 	     # 2 analysis_id        NUMERIC(9,0) NOT NULL,
	     # 3 rawscore           DOUBLE PRECISION NULL,
	     # 4 normscore          DOUBLE PRECISION NULL,
	     # 5 significance       DOUBLE PRECISION NULL,
	     # 6 pidentity          DOUBLE PRECISION NULL
	     # 7 type_id            NUMERIC(9,0)     NULL
	     #
	     #
	     # uc1_analysisfeature (feature_id, analysis_id)
	     #
	     #
	     'analysisfeature' => {               #   0    1      2     3      4      5      6  7
		                     'record'  => "^($x)$f($x)$f($x)$f($v*)$f($v*)$f($v*)$f($v*)$f$o$r\$",
				     'columns' => {
					             'analysisfeature_id' => 0,
						     'feature_id'         => 1,
						     'analysis_id'        => 2,
						     'rawscore'           => 3,
						     'normscore'          => 4,
						     'significance'       => 5,
						     'pidentity'          => 6,
						     'type_id'            => 7
						 },
				     'keys'   => {
					            'feature_id'  => [
								      'feature',
								      'feature_id'
								      ],
						    'analysis_id' => [
								      'analysis',
								      'analysis_id'
								      ]
								  }
				 }
		     
	     };
 

    return $hash;
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

    print STDERR "SAMPLE USAGE:  $0 -D database -P password -U username [-l log4perl] [-d debug_level] [-h] [-m] [-r directory] [-t table]\n".
    "  -D|--database            = Optional - chado database to pull tuples from\n".
    "  -P|--password            = Optional - password (Required when database is specified)\n".
    "  -U|--username            = Optional - username (Required when database is specified)\n".
    "  -l|--log4perl            = Optional - Log4perl log file (default: /tmp/validate_foreign_key_constraints.pl.log)\n".
    "  -m|--man                 = Display pod2usage pages for this utility\n".
    "  -h|--help                = Display pod2usage help screen.\n".
    "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level (default level is 0)\n".
    "  -r|--directory           = Optional - Directory containing BCP files to have foreign constraints validated (defaults is current directory)\n".
    "  -t|--table               = Optional - user can specified one table to be validated  (Default, all BCP .out files in specified directory are validated)\n";
    exit 1;

}
