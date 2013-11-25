#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#-----------------------------------------------------------------------------------------------------
# program name: dropchadotables.pl
# author:       Jay Sundaram
# date:         2005-09-27
#
# purpose:      Dynamically generates list of tables to be dropped from specified chado database
#
#-----------------------------------------------------------------------------------------------------


=head1 NAME

dropchadotables.pl - Drops tables from specified chado database

=head1 SYNOPSIS

USAGE:  dropchadotables.pl -D database --database_type -P password --server -U username [-d debug_level] [-h] [-l logfile] [-m]

=head1 OPTIONS

=over 8

=item B<--database,-D>
    
    Target database name

=item B<--database_type>
    
    Relational database management system type e.g. sybase or postgresql

=item B<--password,-P>
    
    Database password

=item B<--server>
    
    Name of server on which the database resides

=item B<--username,-U>
    
    Database username

=item B<--debug_level,-d>
    
    Optional - Coati::Logger log4perl logging level (default is 0)

=item B<--help,-h>

    Print this help

=item B<--logfile,-l>
    
    Optional - Log4perl log file.  (default is /tmp/dropchadotables.pl.log)

=item B<--man,-m>

    Display pod2usage man page for this utility


=back

=head1 DESCRIPTION

    dropchadotables.pl - Drops all foreign key constraints and then all drops all tables
    e.g.
    1) ./dropchadotables.pl -U username -P password -D chado_test -S SYBIL
    2) ./dropchadotables.pl -U username -P password -D chado_test -S SYBIL -l drop.log

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

my ($username, $password, $database, $database_type, $server, $log4perl, $help, $man, $debug_level);


#---------------------------------------------------------------------------------
# Process the command-line arguments
#
my $results = GetOptions (
			  'database|D=s'        => \$database,
			  'database_type=s'     => \$database_type,
			  'password|P=s'        => \$password,
			  'server|S=s'          => \$server,
			  'username|U=s'        => \$username,
			  'debug_level|d=s'     => \$debug_level,
			  'help|h'              => \$help, 
			  'logfile|l=s'         => \$log4perl,
			  'man|m'               => \$man
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

#---------------------------------------------------------------------------------
# Initialize the logger
#
if (!defined($log4perl)){
    $log4perl = '/tmp/dropchadotables.pl.log';
    print STDERR "log_file was set to '$log4perl'\n";
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

#---------------------------------------------------------------------------------
# Caching should be turned off
#
$ENV{DBCACHE} = undef;
$ENV{DBCACHE_DIR} = undef;
#
#---------------------------------------------------------------------------------

## Set the PRISM env var
&setPrismEnv($server, $database_type);

#---------------------------------------------------------------------------------
# Instantiate Prism object
#
my $prism = &retrieve_prism_object($username, $password, $database);
#
#---------------------------------------------------------------------------------


#--------------------------------------------------------------------------------
# editor:   sundaram@tigr.org
# date:     Sun Nov 13 12:18:58 EST 2005
# bgzcase:  2281
# URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2281
# comment:  This script will now drop all foreign key constraints prior to
#           dropping all tables.
#
$prism->drop_foreign_key_constraints();
#
#--------------------------------------------------------------------------------


#---------------------------------------------------------------------------------
# Retrieve the list of sysobjects where type = 'U'
#
my $tablehash = $prism->sysobjects();
#
#---------------------------------------------------------------------------------



#---------------------------------------------------------------------------------
# Retrieve the table commit order from the conf/Prism.conf
#
my $commit_order;
my @commit_list;

if ((exists $ENV{'COMMIT_ORDER'}) && (defined($ENV{'COMMIT_ORDER'}))){

    $commit_order = $ENV{'COMMIT_ORDER'};
    @commit_list = split(/,/,$commit_order);
    


}
#
#---------------------------------------------------------------------------------



#---------------------------------------------------------------------------------
# Drop the table in the correct order
#
$prism->droptables($tablehash, \@commit_list, $database);
#
#---------------------------------------------------------------------------------


print ("'$0': Program execution complete\n");
print ("Please review logfile: $log4perl\n");








#------------------------------------------------------------------------------------------------------------
#
#                                   END MAIN -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------


#----------------------------------------------------------------
# retrieve_prism_object()
#
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
			   user             => $username,
			   password         => $password,
			   db               => $database,
			   use_placeholders => $pparse,
			   );
    
    $logger->logdie("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    

    return $prism;


}

#--------------------------------------------------------------------
# print_usage()
#
#--------------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -D database --database_type -P password --server -U username [-d debug_level] [-h] [-l logfile] [-m]\n".
    "  -D|--database           = target Chado database\n".
    "  --database_type         = Relational database management system type e.g. sybase or postgresql\n".
    "  -P|--password           = password\n".
    "  -S|--server             = Name of the server on which the database resides\n".
    "  -U|--username           = username\n".
    "  -d|--debug_level        = Optional - Coati::Logger log4perl logging level (default is 0)\n".
    "  -h|--help               = This help message\n".
    "  -l|--logfile            = Optional - log4perl log file (default is /tmp/dropchadotables.pl.log)\n".
    "  -m|--man                = Display the pod2usage man page for this utility\n";
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
