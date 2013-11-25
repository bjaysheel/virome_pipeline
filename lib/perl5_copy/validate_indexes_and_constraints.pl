#!/usr/local/bin/perl
#-------------------------------------------------------------------------------------------
# $Id: validate_indexes_and_constraints.pl 3141 2006-12-07 16:41:07Z angiuoli $
#-------------------------------------------------------------------------------------------
# Purpose: Performs validation on primary key and uniqueness constraint for specified
#          chado table BCP .out file.
#
#-------------------------------------------------------------------------------------------
=head1 NAME

validate_indexes_and_constraints.pl - Validates the primary key and uniqueness constraints for a given BCP .out table file

=head1 SYNOPSIS

USAGE:  validate_indexes_and_constraints.pl -D database -P password -U username [-S server] [-f file] [-l log4perl] [-d debug_level] [-h] [-m] 

=head1 OPTIONS

=over 8
 
=item B<--database,-D>
    
      Name of target chado database

=item B<--server,-S>
    
      Name of database server

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--file,-f>
    
      Name of BCP .out file to be validated

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

    validate_indexes_and_constraints.pl - Validates the primary key and uniqueness constraints for a given BCP .out table file


    Assumptions:

    1. User has appropriate permissions (to execute script, access chado database, read input directory).
    2. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./validate_indexes_and_constraints.pl -f /usr/local/scratch/chado_test/BCPFILES/analysis.out -D chado_test

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
my ($log4perl, $debug_level, $file, $help, $man, $database, $server, $username, $password);

my $results = GetOptions (
			  'log4perl|l=s'          => \$log4perl,
			  'debug_level|d=s'       => \$debug_level, 
			  'help|h'                => \$help,
			  'file|f=s'              => \$file,
			  'man|m'                 => \$man,
			  'database|D=s'          => \$database,
			  'server|S=s'			  => \$server,
			  'username|U=s'          => \$username,
			  'password|P=s'          => \$password
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);


if (!defined($database)){
    print STDERR "database was not defined\n";
    &print_usage();
}
if (!defined($username)){
    print STDERR "username was not defined\n";
    &print_usage();
}
if (!defined($password)){
    print STDERR "password was not defined\n";
    &print_usage();
}
if (!defined($file)){
    print STDERR "file was not defined\n";
    &print_usage();
}


$log4perl = "/tmp/validate_analysis.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


if (!-e $file){
    $logger->info("file '$file' does not exist");
    #
    # Nothing to do, exit
    #
    exit(0);
}
if (!-r $file){
    $logger->logdie("file '$file' does not have read permissions");
}
if (-z $file){
    $logger->logdie("file '$file' exists and yet has zero content");
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


#
#
#
my $prism = &retrieve_prism_object(
				   $username,
				   $password,
				   $database
				   );

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
# Extract the table name from the filename
#
my $tablename = basename($file);
$tablename =~ s/\.out//;

if (! exists $qtabhash->{$tablename}){
    $logger->logdie("table '$tablename' for file '$file' is not a qualified chado table.  Here is the list of qualified tables:@qualtablist");
}

my $greplines = &load_greplines();

my $record_grepline;
if ((exists $greplines->{$tablename}->{'record'}) && (defined($greplines->{$tablename}->{'record'}))){
    $record_grepline = $greplines->{$tablename}->{'record'};
}
else{
    $logger->logdie("grepline was not defined for table '$tablename'");
}


my $uc_keys;
if ((exists $greplines->{$tablename}->{'uc_keys'}) && (defined($greplines->{$tablename}->{'uc_keys'}))){
    $uc_keys = $greplines->{$tablename}->{'uc_keys'};
}
else {
    $logger->logdie("uckeys was not defined for table '$tablename'");
}



#
# Open the input file
#
open (INFILE, "<$file") or $logger->logdie("Could not open file '$file':$!");



my $linectr = 0;

my $uniqueness_hash ={};
my $pk_hash = {};

while (my $line = <INFILE> ){

    chomp $line;

    $linectr++;

    if ($line =~ /$record_grepline/){

	#
	# Tally the primary key counts
	#
	$pk_hash->{$1}++;

	#
	# Collect columns that are part of the uniqueness constraint
	#
	my @columns = ($2, $3, $4, $5, $6, $7);

	my $uc;

# 	my $count = scalar(@{$uc_keys});
# 	die "uc_keys '$count'";
	
	for (my $i=0; $i < (scalar(@{$uc_keys})) ; $i++){ 
	    $uc .= $columns[$i] . '__' if (defined($columns[$i]));
	}
	     
	#
	# Strip the trailing '__'
	#
	$uc =~ s/__$//;

	#
	# Tally the unique keys counts
	#
	$uniqueness_hash->{$uc}++;
    }
    else{
	$logger->logdie("Could not parse line number '$linectr': '$line' record_grepline was: $record_grepline");
    }
}

$logger->info("Total number of lines processed in file '$file' was '$linectr'");

&check_constraint($pk_hash, "primary key", $tablename, $file);
&check_constraint($uniqueness_hash, "unique key", $tablename, $file, $uc_keys);


if (defined($database)){
    
    #
    # Retrieve records from the target chado table
    #
    my ($db_pk_hash, $db_uc_hash) = &load_table_tuples($prism, $tablename, $uc_keys);
    &check_constraints_against_database($db_pk_hash,$db_uc_hash, $pk_hash, $uniqueness_hash, $tablename, $file, $database);
    

}




#------------------------------------------------------------------------------------------------------------------------------------------------------
#
#                                                    END OF MAIN -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------------------------------------------------



#----------------------------------------------------------
# check_constraint()
#
#----------------------------------------------------------
sub check_constraint {

    my ($hashref, $constraint_name, $tablename, $file, $uc_keys) = @_;

    $logger->logdie("hashref was not defined")         if (!defined($hashref));
    $logger->logdie("constraint_name was not defined") if (!defined($constraint_name));
    $logger->logdie("tablename was not defined")       if (!defined($tablename));
    $logger->logdie("file was not defined")            if (!defined($file));
    
    $logger->info("Verifying table constraint '$constraint_name' for table '$tablename' file '$file'");

    my $errorcount =0;


    #
    # The one thing that is missing from this script is:
    # We should be retrieving records from the affected table in the chado database
    # and counting those keys as well.
    # Currently, this script only verifies the primary keys and uniqueness constraints
    # among the BCP file.
    #

    foreach my $key (sort keys %{$hashref}){
	
	if (exists $hashref->{$key}){
	    
	    if ($hashref->{$key} > 1){
		print "key '$key' occured '$hashref->{$key}' times\n";
		$errorcount++;
	    }
	}
	else{
	    $logger->logdie("No value count for key '$key'");
	}
    }


    if ($errorcount < 1){
	print ("Table constraint '$constraint_name' for table '$tablename' file '$file' was not violated\n");
	$logger->info("Table constraint '$constraint_name' for table '$tablename' file '$file' was not violated");
    }
    else{
	if (defined($uc_keys)){
	    print ("Table constraint '$constraint_name' for table '$tablename' file '$file' was violated.  uc keys are '@{$uc_keys}'\n");
	    $logger->fatal("Table constraint '$constraint_name' for table '$tablename' file '$file' was violated. uc keys are '@{$uc_keys}'");
	}
	else{
	    print ("Table constraint '$constraint_name' for table '$tablename' file '$file' was violated\n");
	    $logger->fatal("Table constraint '$constraint_name' for table '$tablename' file '$file' was violated");
	}
    }
}

#----------------------------------------------------------
# check_constraints_against_database()
#
#----------------------------------------------------------
sub check_constraints_against_database {

    my ($dbpkhash, $dbuchash, $pkhash, $uchash, $tablename, $file, $database) = @_;

    $logger->logdie("dbpkhash was not defined")         if (!defined($dbpkhash));
    $logger->logdie("dbuchash was not defined")         if (!defined($dbuchash));
    $logger->logdie("pkhash was not defined")       if (!defined($pkhash));
    $logger->logdie("uchash not defined")            if (!defined($uchash));
    $logger->logdie("tablename not defined")            if (!defined($tablename));
    $logger->logdie("file not defined")            if (!defined($file));
    
    $logger->info("Verifying file '$file'  against table '$tablename' contents for contraint violations");

    my $pkerrorcount =0;

    foreach my $pkhashkey (sort keys %{$pkhash}){
	
	if ((exists $dbpkhash->{$pkhashkey}) && (defined($dbpkhash->{$pkhashkey}))){
	    
	    $pkerrorcount++;	    
	    $logger->fatal("pkhashkey '$pkhashkey' already exists in table '$tablename' for target chado database '$database'");
	    
	    
	}
    }
    if ($pkerrorcount>0){
	$logger->fatal("Primary key constraint between file '$file' contents and target chado database '$database' table '$tablename' was violated '$pkerrorcount' times");
    }



    my $ucerrorcount =0;

    foreach my $uchashkey (sort keys %{$uchash}){
	
	if ((exists $dbuchash->{$uchashkey}) && (defined($dbuchash->{$uchashkey}))){
	    
	    $ucerrorcount++;	    
	    $logger->fatal("uchashkey '$uchashkey' already exists in table '$tablename' for target chado database '$database'");
	    
	    
	}
    }
    if ($ucerrorcount>0){
	$logger->fatal("Unique key constraint between file '$file' contents and target chado database '$database' table '$tablename' was violated '$ucerrorcount' times");
    }


    if (($ucerrorcount > 0) or ($pkerrorcount>0)){
	$logger->logdie("Please review logfile '$log4perl'");
    }
    else{
	$logger->info("file '$file' did not violate any constraints");
    }
}

#---------------------------------------------------------
# load_greplines()
#
#---------------------------------------------------------
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
	     'tableinfo' => {              #   0     1    2       3     4      5      6     7    
		              'record'  => "^($x)$f($v+)$f$v*$f\\d{1}$f\\d*$f\\d*$f\\d{1}$f$v+$r\$",
			      'uc_keys' => ['name'],
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
 	     'project' => {              #   0     1     2 
		            'record'  => "^($x)$f($v+)$f$v+$r\$",
			    'uc_keys' => ['name'],
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
		             'record'  => "^($x)$f($v+)$f$v*$r\$",
			     'uc_keys' => ['name'],
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
	     'db' => {               #   0     1     2   3    4     
		         'record' => "^($x)$f($v+)$f$v*$f$v*$f$v*$r\$",
			 'uc_keys' => ['name'],
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
		           'record'  => "^($x)$f($x)$f($v+)$f($v*)$f$v*$r\$",
			   'uc_keys' => ['db_id', 'accession', 'version'],
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
	     'cv' => {               #   0     1     2
		        'record'  => "^($x)$f($v+)$f$v*$r\$",
			'uc_keys' => ['name'],
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
	     'cvterm' => {               #   0     1     2     3    4     5        6
		            'record'  => "^($x)$f($x)$f($v+)$f$v*$f$v*$f(\\d+)$f\\d{1}$r\$",
			    'uc_keys' => ['name', 'cv_id', 'is_obsolete'],
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
	     'cvterm_relationship' => {               #   0     1     2     3
		                         'record'  => "^($x)$f($x)$f($x)$f($x)$r\$",
					 'uc_keys' => ['type_id', 'subject_id', 'object_id'],
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
	     'cvtermpath' => {               #   0     1     2     3    4    5
		                'record'  => "^($x)$f($x)$f($x)$f($x)$f$x$f(\\d*)$r\$",
				'uc_keys' => ['subject_id', 'object_id', 'type_id', 'pathdistance'],
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
	     'cvtermsynonym' => {               #   0     1      2           3
		                   'record'  => "^($x)$f($x)$f($v\{1,1024})$f$o$r\$",
				   'uc_keys' => ['cvterm_id', 'synonym'],
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
	     'cvterm_dbxref' => {               #   0     1    2      3
		                   'record'  => "^($x)$f($x)$f($x)$f\\d{1}$r\$",
				   'uc_keys' => ['cvterm_id', 'dbxref_id'],
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
	     'cvtermprop' => {               #  0      1     2     3       4
		                'record'  => "^($x)$f($x)$f($x)$f($v+)$f(\\d+)$r\$",
				'uc_keys' => ['cvterm_id', 'type_id', 'value', 'rank'],
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
	     'dbxrefprop' => {               #   0     1     2     3      4
		                'record'  => "^($x)$f($x)$f($x)$f($v+)$f(\\d+)$r\$",
				'uc_keys' => ['dbxref_id', 'type_id', 'value', 'rank'],
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
	     'organism' => {                 #   0    1     2      3     4    5
		                'record'  => "^($x)$f$v*$f($v+)$f($v+)$f$v*$f$v*$r\$",
				'uc_keys' => ['genus', 'species'],
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
				      'uc_keys' => ['organism_id', 'dbxref_id'],
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
				  'uc_keys' => ['organism_id', 'type_id', 'value', 'rank'],
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
	     'pub' => {              #   0    1    2    3    4    5    6    7    8     9      10       11     12   13
		         'record' => "^($x)$f$v*$f$v*$f$v*$f$v*$f$v*$f$v*$f$v*$f$v+$f($v+)$f(\\d+)$f\\d{1}*$f$v*$f$v*$r\$",
			 'uc_keys' => ['uniquename', 'type_id'],
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
	     # uc1_pub_relationship (subject_id, object_id, type_id)
	     #
	     #  
             'pub_relationship' => {               #   0     1     2    3
		                      'record'  => "^($x)$f($x)$f($x)$f($x)$r\$",
				      'uc_keys' => ['subject_id','object_id','type_id'],
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
		                'record'  => undef,
				'uc_keys' => ['pub_id', 'dbxref_id'],
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
		           'record'  => undef,
			   'uc_keys' => ['surname', 'givennames', 'suffix'],
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
		                'record'  => undef,
				'uc_keys' => ['author_id', 'pub_id'],
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
	     #                 1       3       4
	     # uc1_pubprop (pub_id, type_id, value)
	     #
	     #
	     'pubprop' => {
		             'record'  => undef,
			     'uc_keys' => ['pub_id', 'type_id', 'value'],
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
	     #                    2           4         8
	     # uc1_feature (organism_id, uniquename, type_id)
	     #
	     #    
	     'feature' => {               #  0     1    2         3           4       5     6    7     8      9     10   11    12
		             'record'  => "^($x)$f$o$f($x)$f$v\{0,255}$f($v\{1,50})$f$v*$f\\d*$f$v*$f($x)$f\\d{1}$f\\d{1}$f$v+$f$v+$r\$",
			     'uc_keys' => ['organism_id', 'uniquename', 'type_id'],
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
	     #                     1          10      11
	     # uc1_featureloc (feature_id, locgroup, rank)
	     #
             'featureloc' => {                 #   0     1    2    3       4     5      6          7        8    9     10      11
		                  'record'  => "^($x)$f($x)$f$o$f\\d*$f\\d{1}$f\\d*$f\\d{1}$f\[\\d|\\-]*$f\\d*$f$v*$f(\\d+)$f(\\d+)$r\$",
				  'uc_keys' => ['feature_id', 'locgroup', 'rank'],
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
	     #                     1          2 
	     # uc1_featurepub (feature_id, pub_id)
	     #
	     #
	     'featurepub' => {
		                'record'  => undef,
				'uc_keys' => ['feature_id', 'pub_id'],
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
	     #                       1         2       3      4
	     # uc1_featureprop (feature_id, type_id, value, rank)
	     #
	     #
             'featureprop' => {               #   0     1     2        3           4
		                 'record'  => "^($x)$f($x)$f($x)$f($v\{1,1000})$f(\\d+)$r\$",
				 'uc_keys' => ['feature_id', 'type_id', 'value', 'rank'],
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
	     #                             1           2
	     # uc1_featureprop_pub (featureprop_id, pub_id)
	     #
	     #
	     'featureprop_pub' => {
		                    'record'  => undef,
				    'uc_keys' => ['featureprop_id', 'pub_id'],
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
	     #                         1           2
	     # uc1_feature_dbxref (feature_id, dbxref_id)
	     #
	     #
	     'feature_dbxref' => {              #   0     1     2      3
		                   'record'  => "^($x)$f($x)$f($x)$f\\d{1}$r\$",
				   'uc_keys' => ['feature_id', 'dbxref_id'],
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
	     #                                1         2          3
	     # uc1_feature_relationship (subject_id, object_id, type_id)
	     #
	     #
	     'feature_relationship' => {               #   0     1     2     3     4
		                          'record'  => "^($x)$f($x)$f($x)$f($x)$f\\d*$r\$",
					  'uc_keys' => ['subject_id', 'object_id', 'type_id'],
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
	     #                                         1                2
	     # uc1_feature_relationship_pub (feature_relationship_id, pub_id)
	     #
	     #
	     'feature_relationship_pub' => {
		                              'record'  =>  undef,
					      'uc_keys' => ['feature_relationship_id', 'pub_id'],
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
	     #                                         1                 2      4
	     # uc1_feature_relationshipprop (feature_relationship_id, type_id, rank)
	     #
	     #
	     'feature_relationshipprop' => {
		                              'record'  => undef,
					      'uc_keys' => ['feature_relationship_id', 'type_id', 'rank'],
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
	     #                                      1                  2
	     # uc1_feature_relprop_pub (feature_relationshipprop_id, pub_id)
	     #
	     #
	     'feature_relprop_pub' => {
		                        'record'  => undef,
					'uc_keys' => ['feature_relationshipprop_id', 'pub_id'],
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
	     #                        1            2        3
	     # uc1_feature_cvterm (feature_id, cvterm_id, pub_id)
	     #
	     # 
             'feature_cvterm' => {               #   0     1     2     3 
		                    'record'  => "^($x)$f($x)$f($x)$f($x)$r\$",
				    'uc_keys' => ['feature_id', 'cvterm_id', 'pub_id'],
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
	     #                                 1             2      4
	     # uc1_feature_cvtermprop (feature_cvterm_id, type_id, rank)
	     #
	     #
	     'feature_cvtermprop' => {               #   0     1     2     3     4
		                        'record'  => "^($x)$f($x)$f($x)$f$v+$f(\\d+)$r\$",
					'uc_keys' => ['feature_cvterm_id', 'type_id', 'rank'],
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
	     #                1      2
	     # uc1_synonym (name, type_id)
	     #
	     #
	     'synonym' => {
		              'record'  => undef,
			      'uc_keys' => ['name', 'type_id'],
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
	     #
	     #                           1          2         3
	     # uc1_feature_synonym (synonym_id, feature_id, pub_id)
	     #
	     #
	     'feature_synonym' => {
		                     'record'  => undef,
				     'uc_keys' => ['synonym_id', 'feature_id', 'pub_id'],
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
	     #                  3            4            6
	     # uc1_analysis (program, programversion, sourcename)
	     #
	     #
	     'analysis' => {              #   0        1          2           3             4          5            6            7           8       9
		             'record'  => "^($x)$f$v\{0,255}$f$v\{0,255}$f($v\{1,50})$f($v\{1,50})$f$v\{0,50}$f($v\{0,255})$f$v\{0,50}$f$v\{0,255}$f$v+$r\$",
			     'uc_keys' => ['program', 'programversion', 'sourcename'],
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
	     #
	     #                        1          2       3
	     # uc1_analysisprop (analysis_id, type_id, value)
	     #
	     #
	     'analysisprop' => {               #   0     1     2       3
		                  'record'  => "^($x)$f($x)$f($x)$f($v\{0,255})$r\$",
				  'uc_keys' => ['analysis_id', 'type_id', 'value'],
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
	     # 6 pidentity          DOUBLE PRECISION NULL,
	     # 7 type_id            NUMERIC(9,0)     NULL
	     #
	     #                          1            2
	     # uc1_analysisfeature (feature_id, analysis_id)
	     #
	     #
	     'analysisfeature' => {               #   0    1      2    3    4    5    6    7
		                     'record'  => "^($x)$f($x)$f($x)$f$v*$f$v*$f$v*$f$v*$f$o$r\$",
				     'uc_keys' => ['feature_id', 'analysis_id'],
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

    my ( $username, $password, $database ) = @_;

    $logger->debug("Instantiating Prism object") if ($logger->is_debug());
    
    if (!defined($username)){
	$username = 'access';
	$logger->info("username was set to '$username'");
    }
    if (!defined($password)){
	$password = 'access';
	$logger->info("password was set to '$password'");
    }


    my $prism = new Prism(
			  user              => $username,
			  password          => $password,
			  db                => $database
			  );
    

    $logger->logdie("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    

    return $prism;


}#end sub retrieve_prism_object()

#-----------------------------------------------------------------
# load_table_tuples()
#
#-----------------------------------------------------------------
sub load_table_tuples {

    my ($prism, $tablename, $uc_keys) = @_;

    my $primary = $tablename . '_id';

    my $ret = $prism->table_primary_and_tuples($tablename, $primary, $uc_keys);

    $logger->logdie("ret was not defined") if (!defined($tablename));


    my $pk_hash = {};
    my $uc_hash = {};

    for (my $i=0; $i < scalar(@{$ret}) ; $i++){

	my $uc;

	for (my $j=1; $j < (scalar@{$uc_keys}) + 1 ; $j++) {

	    if (defined($ret->[$i][$j])){
		$uc .= $ret->[$i][$j] . '__';
	    }
	}


	$pk_hash->{$ret->[$i][0]}++;

	#
	# Strip the trailing '__'
	#
	$uc =~ s/__$//;
	$uc_hash->{$uc}++;
    }


    return ($pk_hash, $uc_hash);

}



#-----------------------------------------------------------------
# print_usage()
#
#-----------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -D database -P password -U username -f file [-l log4perl] [-d debug_level] [-h] [-m]\n".
    "  -D|--database            = Name of target chado database\n".
    "  -P|--password            = Password to access the target chado database\n".
    "  -U|--username            = Username to access the target chado database\n".
    "  -f|--file                = Name of chado table BCP .out file to be validated\n".
    "  -l|--log4perl            = Optional - Log4perl log file (default: /tmp/dup_list.pl.log)\n".
    "  -m|--man                 = Display pod2usage pages for this utility\n".
    "  -h|--help                = Display pod2usage help screen.\n".
    "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level (default level is 0)\n";
    exit 1;

}


