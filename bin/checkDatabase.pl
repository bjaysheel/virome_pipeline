#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
=head1 NAME

checkDatabase.pl - Verifies whether database exists on server by querying the common..genomes table

=head1 SYNOPSIS

USAGE:  checkDatabase.pl [--assert] --database --database_type [-d debug_level] [-h] [--logfile] [-m] --password --server --username

=head1 OPTIONS

=over 8

=item B<--assert>
    
Optional - The program execution will abort if the database does not exist.

=item B<--database>
    
Relational database

=item B<--database_type>
    
Relational database management system type e.g. sybase or postgresql

=item B<--debug_level,-d>
    
Optional - Coati::Logger log4perl logging level (default is 0)

=item B<--help,-h>

Print this help

=item B<--logfile,-l>
    
Optional - Log4perl log file.  (default is /tmp/checkDatabase.pl.log)

=item B<--man,-m>

Display pod2usage man page for this utility

=item B<--password>
    
Password to log onto the database

=item B<--server>
    
Server on which the database resides

=item B<--username>
    
Username to log onto the database

=back

=head1 DESCRIPTION

    checkDatabase.pl - Verifies whether database exists on server by querying the common..genomes table
    e.g.
    1) ./checkDatabase.pl --database=chado_test --database_type=sybase --die=1 --server=SYBIL 

=head1 CONTACT
                                                                                                                                                             
    Jay Sundaram
    sundaram@tigr.org

=cut

use Prism;
use Pod::Usage;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Coati::Logger;


## Don't buffer
$|=1;

my ($database, $database_type, $debug_level, $assert, $help, $logfile, $man, $password, $server, $username);

my $results = GetOptions ('assert=s'   => \$assert,
			  'database=s'      => \$database,
			  'database_type=s' => \$database_type,
			  'debug_level=s'   => \$debug_level,
			  'help|h'          => \$help,
			  'logfile=s'       => \$logfile,
			  'man|m'           => \$man, 
			  'password=s'      => \$password,
			  'server=s'        => \$server,
			  'username=s'      => \$username
			  );

if ($man){
    &pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
}
if ($help){
    &pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
}

my $fatalCtr=0;

if (!$database){
    print STDERR ("database not specified\n");
    $fatalCtr++;
}
if (!$database_type){
    print STDERR ("database_type not specified\n");
    $fatalCtr++;
}
if (!$password){
    print STDERR ("password not specified\n");
    $fatalCtr++;
}
if (!$server){
    print STDERR ("server not specified\n");
    $fatalCtr++;
}
if (!$username){
    print STDERR ("username not specified\n");
    $fatalCtr++;
}

if ($fatalCtr > 0 ){
    &printUsage();
}

## Initialize the logger
if (!defined($logfile)){
    $logfile = '/tmp/checkDatabase.pl.log';
    print STDERR "logfile was set to '$logfile'\n";
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


if (! Prism::verifyDatabaseType($database_type)){
    $logger->logdie("This database_type '$database_type is not supported by Prism");
}

if (( $database_type eq 'sybase' ) && ($server eq 'SYBIL')){
    $logger->warn("At this time, cannot verify if the database exists on the sybase server 'SYBIL'. ".
		  "Simply returning true value.");
    exit(0);
}

## Set the PRISM env var
&setPrismEnv($server, $database_type);

## Instantiate Prism object
my $prism = new Prism( user => $username, 
		       password => $password, 
		       db => $database );

if (!defined($prism)){
    $logger->logdie("prism was not defined");
}

if (! $prism->databaseExists($database)){
    if ($assert == 1){
	$logger->logdie("database '$database' does not exist on server '$server'");
    }
    else {
	print "database '$database' does not exist on server '$server'\n";
    }
}
else {
    print "database '$database' does exist on server '$server'\n";
}

print "The log file is '$logfile'\n";
print "$0 script execution complete\n";
exit(0);



#---------------------------------------------------------------------------------------
#
#            END MAIN -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------

#--------------------------------------------------------------------
# printUsage()
#
#--------------------------------------------------------------------
sub printUsage {

    print STDERR "SAMPLE USAGE:  $0 [--assert] --database --database_type [-d debug_level] [-h] [--logfile] [-m] --password --server --username\n".
    "  --assert         = Optional - die if the database does not exist\n".
    "  --database       = Relational database\n".
    "  --database_type  = Relational database management system i.e. sybase or postgresql\n".
    "  -d|--debug_level = Optional - Coati::Logger log4perl logging level (default is 0)\n".
    "  -h|--help        = Optional - This help message\n".
    "  --logfile        = Optional - log4perl log file (default is /tmp/checkDatabase.pl.log)\n".
    "  -m|--man         = Optional - Display the pod2usage man page for this utility\n".
    "  --password       = Password to log onto the database\n".
    "  --server         = The server on which the database resides\n".
    "  --username       = Username to log onto the database\n";
    exit(1);
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

