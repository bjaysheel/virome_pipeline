#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

watchdatabase.pl - Monitors database activity - based on system stored procedure sp_who

=head1 SYNOPSIS

USAGE:  watchdatabase.pl -D database [-U username] [-P password] [-S server] [-a] [-f sqlfile] [-l log4perl] [-d debug_level] [-m] [-n] [-q] [-s sleep] [-t type]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Optional - username.  Default is 'access'

=item B<--password,-P>
    
    Optional - password.  Default is 'access'

=item B<--database,-D>
    
    Comma-separated list of database(s) to monitor

=item B<--server,-S>
    
    Optional - server.  Default is 'SYBTIGR'

=item B<--all,-a>
    
    Optional - specifies that all databases types specified by option 'type' are to be monitored.  When specified, overrides database option

=item B<--sqlfile,-f>
    
    Optional - file containing SQL commands to execute via sqsh and then grep for database on output


=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--help,-h>

    Print this help

=item B<--log4perl,-l>

    Optional - log4perl log file.  Default is /tmp/watchdatabase.pl.log

=item B<--noshow,-n>

    Optional - Do not display database in which there is no activity.  Default is show all databases regardless of activity

=item B<--quiet,-q>

    Optional - suppress header information

=back

=head1 DESCRIPTION

    watchdatabase.pl - Monitors database activity - based on system stored procedure sp_who

    Sample usages:
    ./watchdatabase.pl -D tryp
    ./watchdatabase.pl -D strep,intracell -s 5 -l my.log
    ./watchdatabase.pl -D chado_test -S SYBIL 
    ./watchdatabase.pl -a -t chado_pre -q
    ./watchdatabase.pl 

=cut



use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;

use Prism;
use strict;
use Coati::Logger;
use Log::Log4perl qw(get_logger);
use Data::Dumper;


my ($username, $password, $database, $sqlfile, $help, $log4perl, $man, $sleep, $server, $debug_level, $all, $type, $quiet, $noshow);


my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'sqlfile|f=s'         => \$sqlfile,
			  'database|D=s'        => \$database,
			  'log4perl|l=s'        => \$log4perl,
			  'sleep|s=s'           => \$sleep, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'server|S=s'          => \$server,
			  'debug_level|d=s'     => \$debug_level,
			  'all|a'               => \$all,
			  'type|t=s'            => \$type,
			  'quiet|q'             => \$quiet,
			  'noshow|n'            => \$noshow,
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&print_usage() if ($help);

$username = "access"         if (!defined($username));
$password = "access"         if (!defined($password));
$server   = "SYBTIGR"        if (!defined($server));
$sleep    = 10               if (!defined($sleep));
$type     = 'chado'          if (!defined($type));
$sqlfile  = "/usr/local/devel/ANNOTATION/sundaram/who.sql" if (!defined($sqlfile));

#
# initialize the logger
#
$log4perl = "/tmp/watchdatabase.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


if (!defined($database)){
    $logger->warn("database was not defined, therefore monitoring all databases of type '$type' on server '$server'");
    $all = 1;
}


my @dblist;

if (defined($all)){
    @dblist = &retrieve_db_list($type, $username, $password, $server);
}
else{
    @dblist = split(/,/,$database);
}

$logger->debug("Processing the following databases\n" .Dumper \@dblist) if $logger->is_debug;

my $monitor = "Monitoring server '$server' (with process id $$ )";



#print ">>$noshow<<";die;


while (1){

    print $monitor . "\n" if (!defined($quiet));
    
    foreach my $db (@dblist){

	my $shortdb = substr($db,0,10);

#	print STDERR "shortdb '$shortdb' db '$db'\n";
	my $string = "sqsh -U $username -P $password -S $server -i $sqlfile | grep $shortdb";
	
	my $result = qx{$string};
	
	if ($result =~ /^$/){
	    if (defined($noshow)){
		next;
		}
	    else{
		print "NO activity on $db\n\n";
	    }
	}
	else{
	    print "db '$db'\n$result\n";
	}
	
	$logger->info("$monitor\n$result");
	
    }
    sleep $sleep;

}

#------------------------------------------------------
# retrieve_db_list()
#
#------------------------------------------------------
sub retrieve_db_list {

    my ($type, $username, $password, $server) = @_;
    
    my $db = 'tryp';
    $db = 'chado_template' if ($server eq 'SYBIL');
    
    my $prism = new Prism(
		 	  user     => $username,
			  password => $password,
			  db       => $db,
			  );

    $logger->logdie("prism was not defined") if (!defined($prism));

    my $ref = $prism->database_list_by_type($type);

    $logger->fatal("ref was not defined") if (!defined($ref));
	
    return @$ref;

}

#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 [-D database] [-U username] [-P password] [-S server] [-a] [-f sqlfile] [-l log4perl] [-d debug_level] [-m] [-n] [-s sleep] [-t type]\n";
    print STDERR "  -D|--database            = Optional - Comma separated list of databases to monitor (all must be on the same server)\n";
    print STDERR "  -U|--username            = Optional - username.  Default is access\n";
    print STDERR "  -P|--password            = Optional - password.  Default is access\n";
    print STDERR "  -S|--server              = Optional - server.    Default is SYBTIGR\n";
    print STDERR "  -a|--all                 = Optional - To monitor all databases of specific type on specified server\n";
    print STDERR "  -f|--sqlfile             = Optional - SQL containing instruction file\n";
    print STDERR "  -l|--log4perl            = Optional - Log4perl log file. Default: /tmp/watchdatabase.pl.log\n";
    print STDERR "  -m|--man                 = Display pod2usage pages for this utility\n";
    print STDERR "  -n|--noshow              = Optional - Do not display info for database with no activity (default show all regardless of activity)\n";
    print STDERR "  -h|--help                = Display pod2usage help screen\n";
    print STDERR "  -q|--quiet               = Optional - Suppress printing header information\n";
    print STDERR "  -s|--sleep               = Optional - Default is 10\n";
    print STDERR "  -t|--type                = Optional - common..genomes.type  Default is 'chado'\n";
    print STDERR "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level.  Default is 0\n";    
    exit 1;

}
