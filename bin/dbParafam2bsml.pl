#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

dbParafam2bsml.pl - Retrieve parafam data from some database and write the data to a BSML file

=head1 SYNOPSIS

USAGE:  db2bsml.pl -D database -P password -U username -Z compute [-a autogen_feat] -b bsmldoc [-c analysis_id] [-d debug_level] [-h] [-i insert_new] [-l log4perl] [-m] [-o outdir] [-p] [-s autogen_seq] [-u update] [-x xml_schema_type] [-y cache_dir]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--database,-D>
    
    Target chado database 

=item B<--bsmldoc,-b>
    
    Bsml document containing pairwise alignment encodings

=item B<--autogen_feat,-a>
    
    Optional - Default behavior is to auto-generate (-a=1) chado feature.uniquename values for all inbound features.  To turn off behavior specify this command-line option (-a=0).

=item B<--autogen_seq,-s>
    
    Optional - Default behavior is to not (-s=0) auto-generate chado feature.uniquename values for all inbound sequences.  To turn on behavior specify this command-line option (-s=1).

=item B<--insert_new,-i>
    
    Optional - Default behavior is to insert (-i=1) insert newly encountered Sequence objects in the BSML document that are not currently present in the Chado database.  To turn off default insert behavior specify this command-line option (-i=0)

=item B<--analysis_id,-c>
    
    Optional -  analysis_id pre-assigned to the bsml document being processed.  If not provided, the bsml document is scanned for <Analysis> components (Supports workflow pre-parsing setup)

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--outdir,-o>

    Optional: Output directory for the tab delimited .out files.  Default is current directory

=item B<--pparse,-p>

    Optional - turn off parallel load support via global serial identifier replacement (default is ON)

=item B<--update,-u>

    Optional - Default behavior is to not update the database (-u=0).  To turn on update behavior specify this command-line option (-u=1).

=item B<--cache_dir,-y>

    Optional - Query caching directory to write cache files (default is ENV{DBCACHE_DIR})

=item B<--help,-h>

    Print this help

=item B<--compute,-Z>

    compute e.g. blastp, region, nucmer, promer

=back

=head1 DESCRIPTION

    bsmlqa.pl - Parse BSML document and produce tab delimited .out BCP files for insertion into Chado database

    Assumptions:
    1. The BSML pairwise alignment encoding should validate against the XML schema:.
    2. User has appropriate permissions (to execute script, access chado database, write to output directory).
    3. Target chado database already contains all reference features (necessary to build feature and organism lookups) Review and execute db2bsml.pl if required.
    4. Target chado database contains the necessary controlled vocabulary terms: "match" etc.
    5. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./bsmlqa.pl -U access -P access -D tryp -b /usr/local/annotation/TRYP/BSML_repository/blastp/lma2_86_assembly.blastp.bsml  -l my.log -o /tmp/outdir


=cut

use strict;
use File::Basename;
use File::Path;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Prism::DB2BSML::Factory;
use Coati::Logger;

use constant DEFAULT_USERNAME => 'access';
use constant DEFAULT_PASSWORD => 'access';
use constant DEFAULT_SERVER => 'SYBTIGR';
use constant DEFAULT_VENDOR => 'Sybase';

$|=1; ## do not buffer output stream

## Parse command line options
my ($username, $password, $outfile, $database, $debug_level, $help,
    $logfile, $man, $outdir, $server, $cache_dir, $id_repository,
    $idGenType, $outIdMapFile, $inIdMapDir, $inIdMapFile,
    $vendor);

my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'outfile=s'           => \$outfile,
			  'database|D=s'        => \$database,
			  'logfile|l=s'         => \$logfile,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'outdir|o=s'          => \$outdir,
			  'cache_dir|y=s'       => \$cache_dir,
			  'id-gen-type=s'       => \$idGenType,
			  'id_repository=s'     => \$id_repository,
			  'out_id_map_file=s'   => \$outIdMapFile,
			  'in-id-map-dir=s'     => \$inIdMapDir,
			  'in-id-map-file=s'    => \$inIdMapFile
			  );

&checkCommandLineArguments();

my $logger = &getLogger();

my $factory = new Prism::DB2BSML::Factory();
if (!defined($factory)){
    $logger->logdie("Could not instantiate Prism::DB2BSML::Factory");
}

my $converter = $factory->create(analysis           => 'parafam',
				 id_repository      => $id_repository,
				 output_id_map_file => $outIdMapFile,
				 input_id_map_file  => $inIdMapFile,
				 input_id_map_dir   => $inIdMapDir,
				 database           => $database,
				 server             => $server,
				 username           => $username,
				 password           => $password,
				 vendor             => $vendor,
				 outfile            => $outfile);

if (!defined($converter)){
    $logger->logdie("Could not retrieve a converter");
}

$converter->process();

print "$0 execution completed\n";
#print "The output BSML file is '$outfile'\n";
print "The log file is '$logfile'\n";
#print "The output ID map file is '$outIdMapFile'\n";
exit(0);

##-------------------------------------------------------------------
##
##      END OF MAIN  -- SUBROUTINES FOLLOW
##
##-------------------------------------------------------------------

sub checkCommandLineArguments {

    
    if ($man){
	&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
    }
    
    if ($help){
	&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
    }


    my $fatalCtr=0;
    
    if (!defined($database)){
	print STDERR "--database was not specified\n";
	$fatalCtr++;
    }

    if (!defined($id_repository)){
	print STDERR "--id_repository was not specified\n";
	$fatalCtr++;
    }

    if ($fatalCtr> 0 ){
	die "Required command-line arguments were not specified\n";
    }


    if (!defined($username)){
	$username = DEFAULT_USERNAME;
	print STDERR "--username was not specified and ".
	"therefore was set to '$username'\n";
    }

    if (!defined($password)){
	$password = DEFAULT_PASSWORD;
	print STDERR "--password was not specified and ".
	"therefore was set to '$password'\n";
    }

    if (!defined($server)){
	$server = DEFAULT_SERVER;
	print STDERR "--server was not specified and ".
	"therefore was set to '$server'\n";
    }

    if (!defined($vendor)){
	$vendor = DEFAULT_VENDOR;
	print STDERR "--vendor was not specified and ".
	"therefore was set to '$vendor'\n";
    }

    if (!defined($outfile)){
	$outfile = $database . '_assembly.parafam.bsml';
	print STDERR "--outfile was not specified and ".
	"therefore was set to '$outfile'\n";
    }

    if (!defined($logfile)){
	$logfile = File::Basename::basename($0) . '.log';
	print STDERR "--logfile was not specified and ".
	"therefore was set to '$logfile'\n";
    }

    if (!defined($idGenType)){
	$idGenType = 'ergatis';
	print STDERR "--id-gen-type was not specified and ".
	"therefore was set to '$idGenType'\n";
    }


    if (!-e $id_repository){
	mkpath($id_repository) || die "Could not create id_repository '$id_repository': $!";
    }

    if (!-e "$id_repository/valid_id_repository"){
	my $ex = "touch $id_repository/valid_id_repository";
	qx($ex);
    }

    my $dirname = File::Basename::dirname($outfile);

    my $basename = File::Basename::basename($outfile);

    if ($dirname ne $basename){
	if (!-e $dirname){
	    mkpath($dirname) || die "Could not create directory '$dirname': $!";
	}
    }

    if (!defined($outIdMapFile)){
	$outIdMapFile = File::Basename::basename($0) . '_' . $database . '_assembly.out.idmap';
	print STDERR "--out-id-map-file was not specified and ".
	"therefore was set to '$outIdMapFile'\n";
    }

    if (!defined($inIdMapFile)){
	$inIdMapFile = File::Basename::basename($0) . '_' . $database . '_assembly.out.idmap';
	print STDERR "--in-id-map-file was not specified and ".
	"therefore was set to '$inIdMapFile'\n";
    }

}

sub getLogger {

    
    my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				     'LOG_LEVEL'=>$debug_level);
    
    if (!defined($mylogger)){
	die "mylogger was not defined";
    }


    my $logger = Coati::Logger::get_logger(__PACKAGE__);

    if (!defined($logger)){
	die "logger was not defined";
    }


    return $logger;
}


sub checkCacheDir {

    
    if (defined($cache_dir)){

	$ENV{DBCACHE} = "file";

	if (!-e $cache_dir){
	    $logger->warn("cache_dir '$cache_dir' does not exist.  ".
			  "Using default $ENV{DBCACHE_DIR}");
	    return;
	}
	 
	if (!-w $cache_dir){
	    $logger->warn("cache_dir '$cache_dir' is not readable.  ".
			  "Using default $ENV{DBCACHE_DIR}");
	    return;
	}

	if (!-r $cache_dir){
	    $logger->warn("cache_dir '$cache_dir' is not writeable.  ".
			  "Using default $ENV{DBCACHE_DIR}");
	    return;
	}

	$ENV{DBCACHE_DIR} = $cache_dir;
	$logger->info("setting cache_dir to $ENV{DBCACHE_DIR}");
    }
}


sub print_usage {

    exit(1);
    print STDERR "SAMPLE USAGE:  $0 -B bsmldir -D database -P password -U username -Z compute -b bsmldoc [-d debug_level] [-h] [-l log4perl] [-m] [-o outdir]\n";
    print STDERR "  -B|--bsmldir             = BSML_repository directory containing specified compute type BSML documents\n";
    print STDERR "  -D|--database            = Target chado database\n";
    print STDERR "  -P|--password            = Password\n";
    print STDERR "  -U|--username            = Username\n";
    print STDERR "  -b|--bsmldoc             = Bsml document containing pairwise alignment encodings\n";
    print STDERR "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level.  Default is 0\n";    
    print STDERR "  -h|--help                = Optional - Display pod2usage help screen\n";
    print STDERR "  -l|--log4perl            = Optional - Log4perl log file (default: /tmp/bsmlqa.pl.log)\n";
    print STDERR "  -m|--man                 = Optional - Display pod2usage pages for this utility\n";
    print STDERR "  -o|--outdir              = Optional - output directory for tab delimited BCP files (Default is current working directory)\n";
    exit 1;
}
