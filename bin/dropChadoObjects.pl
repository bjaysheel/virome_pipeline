#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
=head1 NAME

dropchadotables.pl - Drops tables from specified chado database

=head1 SYNOPSIS

USAGE:  dropChadoObjects.pl --database --database_type [--debug_level] [--help|-h] [--logfile] [-m] --password --server --username

=head1 OPTIONS

=over 8

=item B<--database>
    
Name of the chado database

=item B<--database_type>
    
Relational database management system type e.g. sybase or postgresql

=item B<--password>
    
Database password

=item B<--server>
    
Name of server on which the database resides

=item B<--username>
    
Database username

=item B<--debug_level>
    
Optional - Coati::Logger log4perl logging level (default is 0)

=item B<--help,-h>

Print this help

=item B<--logfile>
    
Optional - Log4perl log file.  (default is /tmp/dropchadotables.pl.log)

=item B<--man,-m>

Display pod2usage man page for this utility


=back

=head1 DESCRIPTION

    dropchadotables.pl - Drops all foreign key constraints and then all drops all tables
    e.g.
    1) ./dropChadoObjects.pl --username=sundaram --password=sundaram7 --database=chado_test --database_type=sybase --logfile=my.log --server=SYBIL

=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=cut


use Prism;
use Pod::Usage;
use Data::Dumper;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use File::Basename;
use File::Copy;
use Coati::Logger;

$|=1;

my ($username, $password, $database, $database_type, $server, $logfile, $help, $man, $debug_level);

my $results = GetOptions (
			  'database=s'        => \$database,
			  'database_type=s'   => \$database_type,
			  'password=s'        => \$password,
			  'server=s'          => \$server,
			  'username=s'        => \$username,
			  'debug_level|d=s'   => \$debug_level,
			  'help|h'            => \$help, 
			  'logfile=s'         => \$logfile,
			  'man|m'             => \$man
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);
  
my $fatalCtr=0;
$fatalCtr += &checkParameter('username', $username);
$fatalCtr += &checkParameter('password', $password);
$fatalCtr += &checkParameter('database', $database);
$fatalCtr += &checkParameter('database_type', $database_type);
$fatalCtr += &checkParameter('server', $server);

if ($fatalCtr>0){
    &print_usage();
}

## Initialize the logger
if (!defined($logfile)){
    $logfile = '/tmp/dropchadotables.pl.log';
    print STDERR "log file was set to '$logfile'\n";
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

## Caching should be turned off
$ENV{DBCACHE} = undef;
$ENV{DBCACHE_DIR} = undef;

## Set the PRISM env var
&setPrismEnv($server, $database_type);

## Instantiate Prism object
my $prism = new Prism( user => $username,
		       password => $password,
		       db => $database
		       );
if (!defined($prism)){
    $logger->logdie("prism was not defined");
}

my $tableList = $prism->tableList();
my $tableCount = scalar(@{$tableList});

if ($tableCount > 0 ){

    # JC: isn't this redundant with the call to foreignKeyConstraintAndTableList, which provides strictly more information?
    my $foreignKeyConstraintsList = $prism->foreignKeyConstraintsList();
    my $constraintCount = scalar(@{$foreignKeyConstraintsList});

    if ($constraintCount > 0 ){
	print "Will drop '$constraintCount' foreign key constraint(s) prior to dropping remaining '$tableCount' table(s)\n";

	my $fkConstraintTableList = $prism->foreignKeyConstraintAndTableList();

	my $fkConstraintDropCtr=0;

	foreach my $array (@{$fkConstraintTableList}){
	    $prism->dropForeignKeyConstraint($array->[0], $array->[1]);
	    $fkConstraintDropCtr++;
	}
	print "Attempted to drop '$fkConstraintDropCtr' foreign key constraints\n";
    }
    else {
	if ($logger->is_debug()){
	    $logger->debug("No foreign constraints need to be dropped");
	}
    }
    my $tableDropCtr=0;
    foreach my $table (@{$tableList}){
	$prism->dropTable($table);
	$tableDropCtr++;
    }
    print "Attempted to drop '$tableDropCtr' tables\n";
}
else {
    if ($logger->is_debug()){
	$logger->debug("No tables need to be dropped");
    }
}

print "'$0' program execution complete\n";
print "The log file is '$logfile'\n";
exit(0);

#------------------------------------------------------------------------------------------------------------
#
#                                   END MAIN -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------

#--------------------------------------------------------------------
# print_usage()
#
#--------------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 --database --database_type [--debug_level] [--help|-h] [--logfile] [-m] --password --server --username\n".
    "  --database              = Name of the chado database\n".
    "  --database_type         = Relational database management system type e.g. sybase or postgresql\n".
    "  --debug_level           = Optional - Coati::Logger log4perl logging level (default is 0)\n".
    "  -h|--help               = This help message\n".
    "  -l|--logfile            = Optional - log4perl log file (default is /tmp/dropchadotables.pl.log)\n".
    "  -m|--man                = Display the pod2usage man page for this utility\n".
    "  -P|--password           = password\n".
    "  -S|--server             = Name of the server on which the database resides\n".
    "  -U|--username           = username\n";
    exit 1;

}

sub checkParameter { 
    my ($paramName, $value) = @_;
    if (!defined($value)){
	print STDERR "$paramName was not defined\n";
	return 1;
    }
    return 0;
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
