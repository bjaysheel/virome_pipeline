#!/usr/local/bin/perl
#---------------------------------------------------------------------
# script name: check_database_status.pl
# date:        2003.10.28
#
#
#
#
#---------------------------------------------------------------------

use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Data::Dumper;
use Log::Log4perl qw(get_logger);
use File::Basename;


my %options = ();
my ($database, $config, $mode, $verbose, $log4perl, $username, $password, $server);
my $results = GetOptions (
			  \%options,
			  'username|U=s'          => \$username,
			  'password|P=s'          => \$password,
			  'database|D=s'          => \$database,
			  'config|c=s'            => \$config,
			  'mode|m=s'                 => \$mode,
			  'verbose|v'             => \$verbose,
			  'log4perl|l=s'          => \$log4perl,
			  'server|S=s'            => \$server,
			  );

if (!$username){
    print STDERR "\nusername was not defined\n";
}
if (!$password){
    print STDERR "\npassword was not defined\n";
}
if (!$log4perl){
    print STDERR "\nlog4perl log file was not defined\n";
}
if (!$database){
    print STDERR "\ndatabase was not defined\n";
}
if (!$server){
    print STDERR "\ndatabase was not defined\n";
}
if (!$mode){
    print STDERR "\nmode was not defined\n";
}

if (!$log4perl or !$username or !$password or !$database or !$server or !$mode){
    &print_usage();
}

if ($server !~ /^SYBIL|SYBTIGR$/){
    print STDERR "\nInvalid Sybase server: $server, must be either SYBIL or SYBTIGR\n";
    exit;
}
if ($mode !~ /^migration|analysis$/){
    print STDERR "\nInvalid mode: $mode, must be either \"migration\" or \"analysis\"\n";
    exit;
}




#
# Increase log4perl reporting level to screen
#
my $screen_threshold = 'ERROR';
if ($verbose){
    $screen_threshold = 'INFO';
}


&version1(\$mode);





#
# Initialize the log4perl logger
#
Log::Log4perl->init(
		    \ qq{
			log4perl.logger                       = INFO, A1, Screen
			log4perl.appender.A1                  = Log::Dispatch::File
			log4perl.appender.A1.filename         = $log4perl
			log4perl.appender.A1.mode             = write
			log4perl.appender.A1.Threshold        = INFO
			log4perl.appender.A1.layout           = Log::Log4perl::Layout::PatternLayout
			log4perl.appender.A1.layout.ConversionPattern = %d %p> %F{1}:%L %M - %m%n 
			log4perl.appender.Screen              = Log::Dispatch::Screen
			log4perl.appender.Screen.layout       = Log::Log4perl::Layout::SimpleLayout
                        #log4perl.appender.Screen.layout.ConversionPattern =%d %p> %F{1}:%L %M - %m%n 
			log4perl.appender.Screen.Threshold    = $screen_threshold
			Log::Log4perl::SimpleLayout
		    }
		    );

#
# Instantiate logger object
#
my $logger = get_logger();


#
# The default bsml2chado configuration
#
my $conf = {
    ';TMP_DIR;'             => '/usr/local/scratch/bsml2chado',
    ';REPOSITORY_ROOT;'     => '/usr/local/annotation',
    ';WORKFLOW_DIR;'        => '/home/sundaram/code/temp/papyrus/workflow',
    ';SET_RUNTIME;'         => '/home/sundaram/code/temp/papyrus/workflow/set_runtime_vars.pl',
    ';BSML2CHADO_CONF;'     => '/home/sundaram/code/temp/papyrus/workflow/bsml2chado.ini', 
    ';BSML2CHADO_TEMPLATE;' => '/home/sundaram/code/temp/papyrus/workflow/bsml2chado_template.xml',
    ';RUN_WF;'              => '/home/sundaram/code/temp/papyrus/workflow/run_wf.sh',
    ';SERVER;'              => 'SYBIL'
    };





my $workflow_dir = $conf->{';WORKFLOW_DIR;'};
my $set_runtime  = $conf->{';SET_RUNTIME;'};
my $run_wf       = $conf->{';RUN_WF;'};

#--------------------------------------------------------------------------------------------
# Override the defaults if the user has specified a config file
#
#--------------------------------------------------------------------------------------------
if( $config ){
    my $contents = &get_file_contents(\$config);
    if (!defined($contents)){
	$logger->logdie("The contents of $config were not retrieved, contents was not defined");
    }

    foreach my $line (@$contents){
	if (!defined($line)){
	    $logger->logdie("line was not defined");
	}
	my ($key, $value) = split( '=', $line );
	if (!defined($key)){
	    $logger->logdie("key was not defined");
	}
	if (!defined($value)){
	    $logger->logdie("value was not defined");
	}
	$conf->{$key} = $value;
    }
}

#---------------------------------------------------------------------------------------------
# Set some configuration values
#
#---------------------------------------------------------------------------------------------

# Set the database
$conf->{';DATABASE_UC;'} = uc( $database );
$conf->{';DATABASE_LC;'} = lc( $database );

# Set the username and password 
$conf->{';USERNAME;'} = $username;
$conf->{';PASSWORD;'} = $password;

# Set the server
$conf->{';SERVER;'} = $server;



#-------------------------------------------------------------------
# get_file_contents()
#
#-------------------------------------------------------------------
sub get_file_contents {

    my $file = shift;
    if (!defined($file)){
	$logger->logdie("file was not defined");
    }

    if (&is_file_status_ok($file)){

	open (IN_FILE, "<$$file") || $logger->logdie("Could not open file: $$file for input");
	my @contents = <IN_FILE>;
	chomp @contents;
	
	return \@contents;

    }
    else{
	$logger->logdie("file $file does not have appropriate permissions");
    }
    
}#end sub get_contents()


#-------------------------------------------------------------------
# is_file_status_ok()
#
#-------------------------------------------------------------------
sub is_file_status_ok {

    my $file = shift;
    my $fatal_flag=0;
    if (!defined($file)){
	$logger->fatal("file was not defined");
	$fatal_flag++;
    }
    if (!-e $$file){
	$logger->fatal("$$file does not exist");
	$fatal_flag++;
    }
    if (!-r $$file){
	$logger->fatal("$$file does not have read permissions");
	$fatal_flag++;
    }

    if ($fatal_flag>0){
	return 0;
    }
    else{
	return 1;
    }

}#end sub is_file_status_ok()


#-----------------------------------------------------------------
# execute()
#
#-----------------------------------------------------------------
sub execute {
    
    my $string = shift;
    if (!defined($string)){
	$logger->logdie("string was not defined");
    }
    $logger->info("$$string");
    system $$string;
    
    
}#end sub execute()
    
#------------------------------------------------------------------
# version1()
#
#------------------------------------------------------------------
sub version1{
    
    my $mode = shift;
    if (!defined($mode)){
	$logger->logdie("mode was not defined");
    }
    print STDERR ("\n\nThis is version 1.0 of $0\n");
    print STDERR ("Note that this version only displays these messages.\n");
    print STDERR ("You will need to verify all of the following items manually.\n");
    print STDERR ("Verify that you have permissions to access the database\n");
    print STDERR ("Verify that you can select/insert/update from specific tables\n");
    print STDERR ("Verify that there is enough space in the database/table for new data\n");
    if ($$mode eq 'migration'){
	print STDERR ("Verify that cv, cvterm and pub tables are already populated\n");
    }    
    print STDERR ("The next version of this program will automatically perform all of these tasks for you\n");
    print STDERR ("\n\n");
    exit;
}#end sub version1

#------------------------------------------------------------------
# print_usage()
#
#------------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0  -U username -P password -S server -D database -l log4perl -m mode [-c config_file] [-v]\n";
    print STDERR "  -U|--username          = Database login username\n";
    print STDERR "  -P|--password          = Database login password\n";
    print STDERR "  -S|--server            = Server\n";
    print STDERR "  -D|--database          = name of database to load analysis into\n";
    print STDERR "  -l|--log4perl          = log4perl log file\n";
    print STDERR "  -m|--mode              = either \"migration\" or \"analysis\"\n";              
    print STDERR "  -c|--config_file       = configuration file\n";
    print STDERR "  -v|--verbose           = Increases log4perl reporting level to screen from WARN to INFO\n";
    exit 1;

}#end sub print_usage()

