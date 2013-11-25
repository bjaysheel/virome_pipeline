#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

chadoToObo.pl - Dump data from CV Module to OBO file

=head1 SYNOPSIS

USAGE:  chadoToObo.pl --database --database_type [-d debug_level] [--filename] [-h] [--logfile] [-m] --namespace [--outdir] --password --server --username

=head1 OPTIONS

=over 8

=item B<--database>
    
Source chado database

=item B<--database_type>

Relational database management system type e.g. sybase or postgresql

=item B<--debug_level,-d>
    
    Optional - Coati::Logger logfile logging level (default is 0)

=item B<--filename>
    
Name of the output OBO file.  Default is /tmp/\$namespace.obo.

=item B<--help,-h>

Print this help

=item B<--logfile>
    
Optional - Logfile log file.  (default is /tmp/chadoToObo.pl.log)

=item B<--man,-m>

Display pod2usage man page for this utility

=item B<--namespace>
    
The default-namespace value that is stored in chado cv.name.

=item B<--outdir>
    
Optional - output directory where the OBO file should be written (if --filename not specified).  Default is current working directory.

=item B<--password>

Password for the username account to access the chado database

=item B<--server>
    
Name of the server on which the database resides

=item B<--username>
    
Username account to access the chado database

=back

=head1 DESCRIPTION

chadoToObo.pl - Dump data from CV Module to OBO file
e.g.
1) ./chadoToObo.pl --database=chado_test --database_type=sybase --server=SYBIL --username=sundaram --password=sundaram7 --namespace=SO --filename=so.obo

=head1 AUTHOR

Jay Sundaram

sundaram@jcvi.org

=cut

use strict;
use OBO::OBOBuilder;
use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Coati::Logger;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($username, $password, $database, $server, $debug_level, 
    $help, $logfile, $man, $outdir, $database_type, $namespace,
    $filename);

my $results = GetOptions (
			  'username=s'        => \$username, 
			  'password=s'        => \$password,
			  'database=s'        => \$database,
			  'server=s'   	      => \$server,
			  'logfile|l=s'       => \$logfile,
			  'debug_level|d=s'   => \$debug_level, 
			  'help|h'            => \$help,
			  'man|m'             => \$man,
			  'outdir=s'          => \$outdir,
			  'database_type=s'   => \$database_type,
			  'namespace=s'       => \$namespace,
			  'filename=s'        => \$filename
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

if (!defined($namespace)){
    print STDERR ("namespace was not defined\n");
    $fatalCtr++;
}

if ($fatalCtr > 0 ){
    &print_usage();
}

## Get the Log4perl logger
if (!defined($logfile)){
    $logfile = "/tmp/chadoToObo.pl.log";
    print "logfile was not specified and so was set to '$logfile'\n";
}
my $mylogger = new Coati::Logger('LOG_FILE' => $logfile,
				 'LOG_LEVEL'=> $debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


## Use class method to verify the database vendor type
if (! Prism::verifyDatabaseType($database_type)){
    $logger->logdie("Unsupported database type '$database_type'");
}

## Caching should be turned off
$ENV{DBCACHE} = undef;
$ENV{DBCACHE_DIR} = undef;

## Set the PRISM env var
&setPrismEnv($server, $database_type);

## verify and set the output directory
$outdir = &verify_and_set_outdir($outdir);

## Instantiate Prism object
my $prism = new Prism( user     => $username,
		       password => $password,
		       db       => $database
		       );

if (!defined($prism)){
    $logger->logdie("prism was not defined");
}

if ($logger->is_debug()){
    $logger->debug("prism:". Dumper $prism);
}

if (!defined($filename)){
    $filename = '/tmp/'. $namespace . '.obo';
}

my $oboBuilder = new OBO::OBOBuilder( filename => $filename );

if ($prism->ontologyLoaded($namespace)){
    my $oboBuilder = $prism->deriveOboFromChado($namespace, $username, $prism->get_sybase_datetime, "$0");
    $oboBuilder->setFilename($filename);
    $oboBuilder->writeFile();
}
else {
    $logger->logdie("'$namespace' is not loaded the CV module of chado database '$database'");
}

print "$0 program execution complete\n";
print "OBO file was written here '$filename'\n";
print "Log file is '$logfile'\n";
exit(0);

##--------------------------------------------------
## setPrismEnv()
##
##--------------------------------------------------
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

    if ($logger->is_debug()){
	$logger->debug("PRISM was set to '$prismenv'");
    }

    $ENV{PRISM} = $prismenv;
}


##------------------------------------------------------
## print_usage()
##
##------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 --database --database_type [--debug_level] [--filename] [-h] [--logfile] [-m] --namespace [--outdir] --password --server --username\n".
    "  --database          = Name of chado database\n".
    "  --database_type     = RDBMS type e.g. sybase or postgresql\n".
    "  --debug_level       = Optional - Coati::Logger log4perl logging level.  Default is 0\n".
    "  --filename          = Optional - Name of output OBO file.  Default is /tmp/\$namespace.obo\n".
    "  -h|--help           = Optional - Display pod2usage help screen\n".
    "  --logfile           = Optional - Log4perl log file (default: /tmp/chadoToObo.pl.log)\n".
    "  -m|--man            = Optional - Display pod2usage pages for this utility\n".
    "  --namespace         = The default-namespace value stored in chado cv.name\n".
    "  --outdir            = Optional - output directory to write the OBO file (if --filename not specified).  Default is current working directory.\n".
    "  --password          = Database account password\n".
    "  --server            = Name of server on which the database resides\n".
    "  --username          = Database account username\n";
    exit 1;

}

##--------------------------------------------------------
## verify_and_set_outdir()
##
##--------------------------------------------------------
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

}
