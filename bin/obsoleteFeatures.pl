#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

obsoleteFeatures.pl - Change the feature.is_obsolete state to 1 for specified and/or affected feature records

=head1 SYNOPSIS

USAGE:  obsoleteFeatures.pl --feature-uniquename-list-file=/path/to/some/file

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--database,-D>
    
    Target chado database 

=item B<--server,-S>
    
    Target chado database 

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--help,-h>

    Print this help

=item B<--database_type>

    Either sybase or postgresql

=back

=head1 DESCRIPTION

    Assumptions:
    1. User has appropriate permissions (to execute script, access chado database, write to output directory).
    2. All software has been properly installed, all required libraries are accessible.



=head1 CONTACT

Jay Sundaram
sundaram@jcvi.org

=cut

use strict;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Coati::Logger;
use Chado::FeatureObsoleter;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($username, $password, $server, $database, $vendor, $debug_level, 
    $help, $logfile, $man, $featureIdList, $featureIdListFile, 
    $featureUniquenameList, $featureUniquenameListFile, $outfile);


my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'database|D=s'        => \$database,
			  'server|S=s'  	=> \$server,
			  'logfile|l=s'         => \$logfile,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'vendor=s'            => \$vendor,
			  'outfile=s'           => \$outfile,
 			  'feature_id-list-file=s' => \$featureIdListFile,
 			  'feature_id-list=s'      => \$featureIdList,
 			  'uniquename-list=s'      => \$featureUniquenameList,
 			  'uniquename-list-file=s' => \$featureUniquenameListFile
			  );


&checkCommandLineArguments();

my $logger = &getLogger($logfile, $debug_level);

my $obsoleter = new Chado::FeatureObsoleter(username => $username,
					    password => $password,
					    database => $database,
					    server   => $server,
					    vendor   => $vendor,
					    logger   => $logger);
if (!defined($obsoleter)){
    $logger->logdie("Could not instantiate Chado::FeatureObsoleter");
}

$obsoleter->obsoleteAll(feature_id_list      => $featureIdList,
			feature_id_list_file => $featureIdListFile,
			uniquename_list      => $featureUniquenameList,
			uniquename_list_file => $featureUniquenameListFile,
			sqlfile => $outfile );


print "$0 execution completed\n";
print "The log file is '$logfile'\n";
exit(0);

##---------------------------------------------------------------------------
##
##               END OF MAIN  -- SUBROUTINES FOLLOW
##
##---------------------------------------------------------------------------

sub checkCommandLineArguments {

    my $fatalCtr = 0;


    if ($man){
	&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
    }

    if ($help){
	&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
    }

    if (!$database){
	print STDERR "--database was not specified\n";
	$fatalCtr++;
    }
    if (!$server){
	print STDERR "--server was not specified\n";
	$fatalCtr++;
    }
    if (!$vendor){
	print STDERR "--vendor was not specified\n";
	$fatalCtr++;
    }
    if ((!$featureIdListFile) && (!$featureIdList) && (!$featureUniquenameList) && (!$featureUniquenameListFile)){
	print STDERR "Neither --feature_id-list-file, --feature_id-list, ".
	"--uniquename-list nor --uniquename-list-file ".
	"were specified\n";
	$fatalCtr++;
    }

    if ($fatalCtr>0){
	die "Critical command-line arguments were not specified\n";
    }

    if (!$username){
	$username = 'access';
	print STDERR "--username was not specified ".
	"and therefore was set to '$username'\n";
    }
    if (!$password){
	$password = 'access';
	print STDERR "--password was not specified ".
	"and therefore was set to '$password'\n";
    }
    
    if (!$logfile){
	$logfile = '/tmp/' . File::Basename::basename($0) . '.log';
	print STDERR "--logfile was not specified ".
	"and therefore was set to '$logfile'\n";
    }

    if (!$outfile){
	$outfile = '/tmp/' . File::Basename::basename($0) . '.sql';
	print STDERR "--outfile was not specified ".
	"and therefore was set to '$outfile'\n";
    }

}


sub getLogger {

    my ($logfile, $debug_level) = @_;

    my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				     'LOG_LEVEL'=>$debug_level);
    
    return Coati::Logger::get_logger(__PACKAGE__);

}
