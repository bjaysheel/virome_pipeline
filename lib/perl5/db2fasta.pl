#!/usr/local/bin/perl

=head1 NAME

db2fasta.pl - Retrieve protein sequences from the database and write FASTA file(s)

=head1 SYNOPSIS

USAGE:  db2fasta.pl -D database -P password -U username -Z compute [-a autogen_feat] -b bsmldoc [-c analysis_id] [-d debug_level] [-h] [-i insert_new] [-l log4perl] [-m] [-o outdir] [-p] [-s autogen_seq] [-u update] [-x xml_schema_type] [-y cache_dir]

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
use Prism::DB2FASTA::Factory;
use Coati::Logger;

use constant DEFAULT_USERNAME => 'access';
use constant DEFAULT_PASSWORD => 'access';
use constant DEFAULT_SERVER => 'SYBPROD';
use constant DEFAULT_VENDOR => 'Sybase';

$|=1; ## do not buffer output stream

## Parse command line options
my ($username, $password, $outfile, $database, $debug_level, $help,
    $logfile, $man, $outdir, $server, $vendor, $infile, $outdir, $schema, $single);

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
			  'infile=s'            => \$infile,
			  'vendor=s'            => \$vendor,
			  'schema=s'            => \$schema,
			  'single=s'            => \$single,
			  );

&checkCommandLineArguments();

my $logger = &getLogger();

my $factory = new Prism::DB2FASTA::Factory();
if (!defined($factory)){
    $logger->logdie("Could not instantiate Prism::DB2FASTA::Factory");
}

my $converter = $factory->create(type      => $schema,
				 infile    => $infile,
				 outfile   => $outfile,
				 outdir    => $outdir,
				 database  => $database,
				 server    => $server,
				 username  => $username,
				 password  => $password,
				 single    => $single,
				 vendor    => $vendor);

if (!defined($converter)){
    $logger->logdie("Could not retrieve a converter");
}

$converter->convert();

print "$0 execution completed\n";
print "The log file is '$logfile'\n";
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

    if (!defined($schema)){
	print STDERR "--schema was not specified\n";
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

    if (!defined($outdir)){
	$outdir = '/tmp/';
	print STDERR "--outdir was not specified and ".
	"therefore was set to '$outdir'\n";
    }

    if (!defined($logfile)){
	$logfile = '/tmp/' . File::Basename::basename($0) . '.log';
	print STDERR "--logfile was not specified and ".
	"therefore was set to '$logfile'\n";
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


