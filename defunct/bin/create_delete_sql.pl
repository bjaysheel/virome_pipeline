#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
# $Id: create_delete_sql.pl 3556 2007-05-07 02:20:30Z sundaram $
#
=head1 NAME

create_delete_sql.pl - parses BCP file and creates delete SQL statements for deleting all records listed in the BCP file by primary key

=head1 SYNOPSIS

USAGE:  create_delete_sql.pl --bcpfile --database --database_type [-d debug_level]  [-h] [--logfile] [-m] --password --server --sqlfile --table --username

=head1 OPTIONS

=over 8

=item B<--username>
    
    Database username

=item B<--password>
    
    Database password

=item B<--database>
    
    Target chado database 

=item B<--database_type>
    
    The type of relational database management system should be specified so that the correct field and record delimiters can be applied

=item B<--server>
    
    Target database server

=item B<--table>
    
    table name corresponding with the bcpfile

=item B<--bcpfile>

    BCP file containing tab-delimited records that were inserted into the database

=item B<--sqlfile>

    File to which all delete SQL statements will be written

=item B<--logfile>

    Optional - Coati::Logger Log4perl log file (default is /tmp/create_delete_sql.pl.log)

=item B<--debug_level,-d>

    Optional - Coati::Logger log4perl logging level (default is 0)

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--help,-h>

    Print this help

=back

=head1 DESCRIPTION

    create_delete_sql.pl - Parses multiple tab delimited out files and performs global replacement on Coati::IdManager placeholder variables are merges 
                              all of the tab files into one master file.

    Sample output files: feature.out, dbxref.out

    Each file will contain new records to be inserted via the BCP utility into a chado database. (Use the loadSybaseChadoTables.pl script to complete this task.)


    Assumptions:

    1. User has appropriate permissions (to execute script, access chado database, write to output directory).
    2. Target chado database already contains all reference features (necessary to build feature and organism lookups) Review and execute db2bsml.pl if required.
    3. Target chado database contains the necessary controlled vocabulary terms: "match" etc.
    4. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./create_delete_sql.pl -username=access -password=access --database=tryp --input_directory /usr/local/scratch/nema2/bsml2chado/25341/dupdir/ --log4perl=my.log --outdir=/tmp/outdir --server=SYBTIGR


=cut

use strict;

use Prism;
use Coati::Logger;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Config::IniFiles;


my ($username, $password, $database, $server, $logfile, $debug_level, 
    $table, $bcpfile, $sqlfile, $help, $man, $database_type);

my $results = GetOptions ( 'username=s'        => \$username, 
			   'password=s'        => \$password,
			   'database=s'        => \$database,
			   'database_type=s'   => \$database_type,
			   'server=s',         => \$server,
			   'logfile=s'         => \$logfile,
			   'debug_level|d=s'   => \$debug_level, 
			   'help|h'            => \$help,
			   'table=s'           => \$table,
			   'man|m'             => \$man,
			   'sqlfile=s'         => \$sqlfile,
			   'bcpfile=s'         => \$bcpfile
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);


my $fatalCtr=0;

if (!defined($username)){
    print STDERR ("username was not defined\n");
    $fatalCtr++;
}

if (!defined($password)){
    print STDERR ("password was not defined\n");
    $fatalCtr++;
}

if (!defined($database)){
    print STDERR ("database was not defined\n");
    $fatalCtr++;
}

if (!defined($database_type)){
    print STDERR ("database_type was not defined\n");
    $fatalCtr++;
}

if (!defined($server)){
    print STDERR ("server was not defined\n");
    $fatalCtr++;
}

if (!defined($sqlfile)){
    print STDERR ("sqlfile was not defined\n");
    $fatalCtr++;
}

if (!defined($bcpfile)){
    print STDERR ("bcpfile was not defined\n");
    $fatalCtr++;
}

if (!defined($table)){
    print STDERR ("table was not defined\n");
    $fatalCtr++;
}


if ($fatalCtr>0){
    &print_usage();
}

if (!defined($logfile)){
    $logfile = "/tmp/create_delete_sql.pl.log";
}

my $logger = &get_logger($logfile, $debug_level);

## Set the PRISM env var
&setPrismEnv($server, $database_type);

## Why do we need Prism?  In the future, we may
## want to collect information from the target
## chado database (prior to deleting records).
my $prism = new Prism( user       => $username,
		       password   => $password,
		       db         => $database,
		       );


my $primaryIdentifiers = &getPrimaryIdentifiersFromBcpFile($bcpfile, $database_type);

&writeDeleteSQLStatementsToSqlFile($primaryIdentifiers,
				   $table,
				   $sqlfile);


print "$0 program execution completed\n";
print "Log file is '$logfile'\n";
exit(0);

#------------------------------------------------------------------------------------------------------------------------------------------------------
#
#                                                 END OF MAIN -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------------------------------------------------


##------------------------------------------------------
## getPrimaryIdentifiersFromBcpFile()
##
##------------------------------------------------------
sub getPrimaryIdentifiersFromBcpFile {

    my ($bcpfile, $database_type) = @_;

    print  "Processing BCP file '$bcpfile'\n";

    ## default field delimiter
    my $field_delimiter = "\t";

    if (lc($database_type) eq 'sybase'){
	## Set the end-of-record delimiter
	$/ = "\0\n";

	## Set the sybase BCP compatible field delimiter 
	$field_delimiter = "\0\t";
    }
	   

    ## Open the BCP file in read mode
    open (INFILE, "<$bcpfile") or $logger->logdie("Could not open BCP file '$bcpfile':$!");
    
    my $keys;

    ## Process each line in the BCP file
    while (my $line = <INFILE>){
	
	chomp $line;
	
	## Split each record on the field-delimiter
	my @elts = split(/$field_delimiter/,$line,-1);

	push (@{$keys}, $elts[0]);
    }
    
    close INFILE;

    $/ = "\n";

    return $keys;

}


##------------------------------------------------------
## writeDeleteSQLStatementsToSqlFile()
##
##------------------------------------------------------
sub writeDeleteSQLStatementsToSqlFile {

    my ($primaryIdentifiers, $table, $sqlfile) = @_;

    ## Open the sqlfile in write mode
    open (OUTFILE, ">$sqlfile") or $logger->logdie("Could not open sqlfile '$sqlfile':$!");
    
    foreach my $primaryIdentifier (sort @{$primaryIdentifiers} ){
	print OUTFILE "DELETE FROM $table WHERE ${table}_id = $primaryIdentifier;\n";
    }
}


##------------------------------------------------------
## print_usage()
##
##------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 --bcpfile --database [-d debug_level]  [-h] [--logfile] [-m] --password --server --sqlfile --table --username\n".
    "  --bcpfile             = Fullpath to the BCP file\n".
    "  --database            = Target chado database\n".
    "  --debug_level         = Optional - Coati::Logger Log4perl logging level (default is 0)\n".
    "  -h|--help             = Optional - Display pod2usage help screen.\n".
    "  --logfile             = Optional - Coati::Logger Log4perl log file (default is /tmp/create_delete_sql.pl.log)\n".
    "  -m|--man              = Optional - Display pod2usage pages for this utility\n".
    "  --password            = Password\n".
    "  --server              = Name of server on which the database resides\n".
    "  --sqlfile             = Fullpath to the SQL file to which the delete SQL statements will be written\n".
    "  --table               = The name of the table corresponding with the bcpfile\n".
    "  --username            = Username\n";

    exit 1;

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

#--------------------------------------------------
# get_logger()
#
#--------------------------------------------------
sub get_logger {

    my ($logfile, $debug_level) = @_;

    my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				     'LOG_LEVEL'=>$debug_level);
    

    return Coati::Logger::get_logger(__PACKAGE__);
}

