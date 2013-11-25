#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#-----------------------------------------------------------------------------------------------------
# program name: backuptables.pl
# author:       Jay Sundaram
# date:         2005-12-01
#
# purpose:      Dynamically generates list of auxiliary chado database tables and then creates
#               BCP .out backup files of these tables.
#
#-----------------------------------------------------------------------------------------------------


=head1 NAME

backuptables.pl - Drops tables from specified chado database

=head1 SYNOPSIS

USAGE:  backuptables.pl -D database --database_type -P password --server -U username [-a auxonly] [-b bindir] [-c coreonly] [-d debug_level] [-h] [-l logfile] [-m] [-o outdir]

=head1 OPTIONS

=over 8

=item B<--database,-D>
    
    Target database name

=item B<--database_type>
    
    Relational database management system e.g. sybase or postgresql

=item B<--password,-P>
    
    Database password

=item B<--server,-S>
    
    Name of server on which the database resides

=item B<--username,-U>
    
    Database username

=item B<--auxonly,-a>
    
    Optional - Only backup the auxiliary tables (not the core chado tables)

=item B<--coreonly,-c>
    
    Optional - Only backup the core chado tables (not the auxiliary tables)

=item B<--debug_level,-d>
    
    Optional - Coati::Logger log4perl logging level (default is 0)

=item B<--help,-h>

    Print this help

=item B<--logfile,-l>
    
    Optional - Log4perl log file.  (default is /tmp/backuptables.pl.log)

=item B<--man,-m>

    Display pod2usage man page for this utility

=item B<--outdir,-o>

    Optional - The output directory where BCP .out files will be written


=back

=head1 DESCRIPTION

    backuptables.pl - Drops all foreign key constraints and then all drops all tables
    e.g.
    1) ./backuptables.pl -U username -P password -D chado_test -S SYBIL
    2) ./backuptables.pl -U username -P password -D chado_test -S SYBIL -l backup.log

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

my ($username, $password, $database, $database_type, $server, $log4perl, $help, $man, $debug_level, $auxonly, $coreonly, $outdir, $bindir);

#---------------------------------------------------------------------------------
# Process the command-line arguments
#
my $results = GetOptions (
						  'database|D=s'        => \$database,
						  'database_type=s'        => \$database_type,
						  'password|P=s'        => \$password,
						  'server|S=s'          => \$server,
						  'username|U=s'        => \$username,
						  'debug_level|d=s'     => \$debug_level,
						  'help|h'              => \$help, 
						  'logfile|l=s'         => \$log4perl,
						  'man|m'               => \$man,
						  'auxonly|a=s'         => \$auxonly,
						  'coreonly|c=s'        => \$coreonly,
						  'outdir|o=s'          => \$outdir,
						  'bindir|b=s'          => \$bindir
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
if (!defined($log4perl)){
    $log4perl = '/tmp/backuptables.pl.log';
    print STDERR "log_file was set to '$log4perl'\n";
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

#
#
#---------------------------------------------------------------------------------

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


#---------------------------------------------------------------------------------
# Retrieve the list of sysobjects where type = 'U'
#
my $tablehash = $prism->sysobjects();
#
#---------------------------------------------------------------------------------



#---------------------------------------------------------------------------------
# Retrieve the table commit order from the conf/Prism.conf
#

my $commit_hash = {};

if ((exists $ENV{'COMMIT_ORDER'}) && (defined($ENV{'COMMIT_ORDER'}))){

    my $commit_order = $ENV{'COMMIT_ORDER'};

    my @commit_list = split(/,/,$commit_order);

    foreach my $table ( @commit_list ) {

		$commit_hash->{$table} = $table;
	}


}
#
#---------------------------------------------------------------------------------




#
# verify and set the output directory
#
$outdir = &verify_and_set_outdir($outdir);

my $repository = File::Basename::dirname($log4perl);

my $chadoloader = $bindir . "/chadoloader.pl";

if ((-e $chadoloader) && (-s $chadoloader) && (-x $chadoloader)) {
	

	my $chadowrapper = $bindir . "/chadoloader";

	if ((-e $chadowrapper) && (-s $chadowrapper)) {


		
		#---------------------------------------------------------------------------------
		# backup the auxiliary chado tables in the correct order
		#
		&backuptables($tablehash, $commit_hash, $auxonly, $coreonly, $username, $password, $database, $server, $outdir, $repository, $chadoloader, $chadowrapper);
		#
		#---------------------------------------------------------------------------------
	}
	else {
		$logger->logdie("chadowrapper '$chadowrapper' does not exist");
	}
}
else {
	if (!-e $chadoloader){
		$logger->logdie("'$chadoloader' does not exist");
	}
	if (!-s $chadoloader){
		$logger->logdie("'$chadoloader' has zero size");
	} 
	if (!-x $chadoloader){
		$logger->logdie("'$chadoloader' is not executable");
	}
}

print ("'$0': Program execution complete\n");
print ("Please review logfile: $log4perl\n");








#------------------------------------------------------------------------------------------------------------
#
#                                   END MAIN -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------


#----------------------------------------------------------------
# backuptables()
#
#
#----------------------------------------------------------------
sub backuptables {

    my ( $instantiatedtablelist, $corechadotablelist, $auxonly, $coreonly, $username, $password, $database, $server, $outdir, $repository, $chadoloader, $chadowrapper) = @_;

	my $backuplist = [];
	
	my $ignoredlist = [];


	$logger->debug("List of instantiated tables in database '$database': ". Dumper $instantiatedtablelist) if ($logger->is_debug());


	foreach my $insttable ( keys %{$instantiatedtablelist} ) {
		
		
		if (( exists $corechadotablelist->{$insttable}) && (defined($corechadotablelist->{$insttable}))){
			#
			# This instantiated table is one of the core chado tables
			#

			if ((defined($coreonly)) && ($coreonly == 1)){
				#
				# Backup this instantiated core chado table because we only want to backup the core tables
				#
				push ( @{$backuplist}, $insttable );
			}
			else {
				push( @{$ignoredlist}, $insttable);
			}

		}
		else {
			#
			# This instantiated table is not one of the core chado tables
			#
			if ((defined($auxonly)) && ($auxonly == 1)){
				#
				# Ignore this instantiated core chado table because we only want to backup the auxiliary tables
				#
				push( @{$backuplist}, $insttable);
			}
			else {
				push( @{$ignoredlist}, $insttable);
			}

		}
	}


	$logger->warn("The following tables in database '$database' will not be backed-up by this script: '@{$ignoredlist}'");
	
	

	foreach my $backuptable ( @{$backuplist} ) {

		#
		# This will ensure that each log4perl log file will be written to the workflow instance repository
		#
		my $logfile = $repository . "/" . $backuptable . ".log";

		my $execstring = "$chadowrapper --username=$username --password=$password --database=$database --server=$server --bcpmode=out --logfile=$logfile --directory=$outdir --abort=1 --debug_level=5 --table=$backuptable --batchsize=1000000";

#		$logger->fatal("$execstring");die;
		&execute_command($execstring);
	}

}








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


}#end sub retrieve_prism_object()

#--------------------------------------------------------------------
# execute_command()
#
#--------------------------------------------------------------------
sub execute_command {

    my $cmd = shift;
    
    $logger->debug("$cmd") if $logger->is_debug();
    
    system($cmd);
    
    if ($? == -1) {
       print STDERR "failed to execute: $!\n";
       exit(1);
    } 
	elsif ($? & 127) {

		printf STDERR "child died with signal %d, %s coredump\n",
		($? & 127),  ($? & 128) ? 'with' : 'without';
       exit(1);
    }
	
}



#--------------------------------------------------------
# verify_and_set_outdir()
#
#
#--------------------------------------------------------
sub verify_and_set_outdir {

    my ( $outdir) = @_;

    $logger->debug("Verifying and setting output directory") if ($logger->is_debug());

    #
    # strip trailing forward slashes
    #
    $outdir =~ s/\/+$//;
    
    #
    # set to current directory if not defined
    #
    if (!defined($outdir)){
		if (!defined($ENV{'OUTPUT_DIR'})){
			$outdir = "." 
		}
		else{
			$outdir = $ENV{'OUTPUT_DIR'};
		}
    }

    $outdir .= '/';

    #
    # verify whether outdir is in fact a directory
    #
    $logger->logdie("$outdir is not a directory") if (!-d $outdir);

    #
    # verify whether outdir has write permissions
    #
    $logger->logdie("$outdir does not have write permissions") if ((-e $outdir) and (!-w $outdir));


    $logger->debug("outdir is set to:$outdir") if ($logger->is_debug());

    #
    # store the outdir in the environment variable
    #
    $ENV{OUTPUT_DIR} = $outdir;
    
    return $outdir;

}#end sub verify_and_set_outdir()


#--------------------------------------------------------------------
# print_usage()
#
#--------------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -D database --database_type -P password [-S server] -U username [-a auxonly] [-c coreonly] [-d debug_level] [-h] [-l logfile] [-m] [-o outdir]\n".
    "  -D|--database           = target Chado database\n".
    "  --database_type         = Relational database management system e.g. sybase or postgresql\n".
    "  -P|--password           = password\n".
    "  -S|--server             = Name of server on which the database resides\n".
    "  -U|--username           = username\n".
    "  -a|--auxonly            = Optional - Only backup the auxiliary tables (not the core chado tables)\n".
    "  -b|--bindir             = Optional - Directory containing chadoloader.pl (Default is current working directory)\n".
    "  -c|--coreonly           = Optional - Only backup the core chado tables (not the auxiliary tables)\n".
    "  -d|--debug_level        = Optional - Coati::Logger log4perl logging level (default is 0)\n".
    "  -h|--help               = This help message\n".
    "  -l|--logfile            = Optional - log4perl log file (default is /tmp/backuptables.pl.log)\n".
    "  -m|--man                = Display the pod2usage man page for this utility\n".
    "  -o|--outdir             = Optional - The output directory where BCP .out files will be written\n";
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
