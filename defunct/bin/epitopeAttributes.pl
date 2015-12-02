#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

epitopeAttributes.pl - Parse BSML document and produce a tab-delimited featureprop.out BCP file for insertion into chado database

=head1 SYNOPSIS

USAGE:  epitopeAttributes.pl -D database --database_type -P password -U username --server -b bsmldoc [-d debug_level] [-h] [--id_repository] [-l logfile] [-m] [-o outdir] [--rel_type_id]

=head1 OPTIONS

=over 8

=item B<--username,-U>

Database username

=item B<--password,-P>

Database password

=item B<--database,-D>

Target chado database 

=item B<--database_type>

Relational database management system type e.g. sybase or postgresql

=item B<--server>

Name of server on which the database resides

=item B<--bsmldoc,-b>

Bsml document containing pairwise alignment encodings

=item B<--debug_level,-d>

 Optional: Coati::Logger Log4perl logging level.  Default is 0

=item B<--man,-m>

Display the pod2usage page for this utility

=item B<--outdir,-o>

 Optional: Output directory for the tab delimited .out files.  Default is current directory

=item B<--help,-h>

Print this help

=item B<--help,-h>

Optional - cvterm_id for the relationship term that will associate the epiPEP record to the corresponding polypeptide record

=head1 DESCRIPTION

eptiopeAttributes.pl - Parse BSML document and produce a tab-delimited featureprop.out BCP file for insertion into chado database

 Assumptions:

Sample usage:
./epitopeRelationships.pl -U access -P access -D burkholderia -b /path/to/bsml/file.bsml  -l my.log -o /tmp/outdir


=head1 CONTACT

Jay Sundaram
sundaram@jcvi.org

=cut


use strict;
use File::Basename;
use File::Path;
use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Coati::Logger;
use Chado::Featureprop::BCP::Util;
use Annotation::BSML::Epitope::Parser;


## Do not buffer output stream
$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($username, $password, $bsmldoc, $database, $server, $debug_level, 
    $help, $logfile, $man, $outdir, $database_type, $recordCountFile);

my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'bsmldoc|b=s'         => \$bsmldoc,
			  'database|D=s'        => \$database,
			  'server=s'            => \$server,
			  'logfile|l=s'         => \$logfile,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'outdir|o=s'          => \$outdir,
			  'database_type=s'     => \$database_type,
			  'record_count_file=s' => \$recordCountFile
			  );

&checkCommandLineArguments();

my $logger = &set_logger($logfile, $debug_level);



my $validDatabaseTypes = { 'postgresql' => 1,
                           'sybase' => 1,
                           'mysql' => 1};

my $mysqlDelimiters = { '_row_delimiter' => "\n",
                        '_field_delimiter' => "\t" };

my $postgresqlDelimiters = { '_row_delimiter' => "\n",
			     '_field_delimiter' => "\t" };

my $sybaseDelimiters = { '_row_delimiter' => "\0\n",
			 '_field_delimiter' => "\0\t" };

my $databaseTypeToDelimiterLookup = { 'postgresql' => $postgresqlDelimiters,
                                      'sybase' => $sybaseDelimiters,
                                      'mysql' => $mysqlDelimiters };

my $databaseTypeToBulkVendorLookup = { 'postgresql' => 'BulkPostgres',
				   'sybase' => 'BulkSybase',
				   'mysql' => 'BulkMysql',
				   'oracle' => 'BulkOracle' };


$database_type = lc($database_type);

if (defined($database_type)){
    if (!exists $validDatabaseTypes->{$database_type}){
	$logger->logdie("Unsupported database type '$database_type'");
    }
}
else {
    $database_type = 'sybase';
}

&set_prism_env($server, $databaseTypeToBulkVendorLookup->{$database_type});

my $prism = new Prism(user              => $username,
		      password          => $password,
		      db                => $database,
		      use_placeholders  => undef,
		      );

if (!defined($prism)){
    $logger->logdie("Could not instantiate Prism for username ".
		    "'$username' password '$password' db '$database'");
}


# my $featureRef;
# my $epiPEPCtr=0;
# my $epiAttrLookup={};
# my $epi;

my $parser = new Annotation::BSML::Epitope::Parser(file=>$bsmldoc);
if (!defined($parser)){
    $logger->logdie("Could not instantiate Annotation::BSML::Epitope::Parser");
}

my $lookup = $parser->getAttributeLookup();
if (!defined($lookup)){
    $logger->logdie("Could not retrieve attributes lookup");
}

#print Dumper $lookup;die;

my $util = new Chado::Featureprop::BCP::Util(prism=>$prism);

if (!defined($util)){
    $logger->logdie("Could not instantiate Chado::".
		    "Featureprop::BCP::Util");
}

#&parseBSMLFile();

#print "Encountered '$epiPEPCtr' epiPEP Feature sections in the BSML file\n";
#print Dumper $epiAttrLookup;die;

$util->processFeatures(lookup=>$lookup);

if (!-e $outdir){
    mkpath($outdir) || $logger->logdie("Could not create output directory '$outdir': $!");
}

print "Writing tab delimited .out files to directory: '$outdir'\n";

$prism->{_backend}->output_tables($outdir);

#$prism->reportTableRecordCounts($recordCountFile);

print "\n$0 program execution completed\n";
print "Tab delimited .out files were written to $outdir\n";
print "Run flatFileToChado.pl to load the contents of the ".
"tab-delimited files into chado database '$database'\n";
print "The log file is '$logfile'\n";
exit(0);


##----------------------------------------------------------------
##
##         END OF MAIN  -- SUBROUTINES FOLLOW
##
##----------------------------------------------------------------


sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -D database --database_type --server -P password -U username -b bsmldoc [-d debug_level] [-h] [-l logfile] [-m] [-o outdir]\n".
    "  -D|--database                = Target chado database\n".
    "  --database_type              = Relational database management system type e.g. sybase or postgresql\n".
    "  --server                     = Name of the server on which the database resides\n".
    "  -P|--password                = Password\n".
    "  -U|--username                = Username\n".
    "  -b|--bsmldoc                 = Bsml document containing pairwise alignment encodings\n".
    "  -d|--debug_level             = Optional - Coati::Logger Log4perl logging level.  Default is 0\n".
    "  -h|--help                    = Optional - Display pod2usage help screen\n".
    "  -l|--logfile                 = Optional - Log4perl log file (default: /tmp/bsml2chado.pl.log)\n".
    "  -m|--man                     = Optional - Display pod2usage pages for this utility\n".
    "  -o|--outdir                  = Optional - output directory for tab delimited BCP files (Default is current working directory)\n".

    exit 1;

}

sub set_prism_env {

    my ($server, $vendor) = @_;

    if (!defined($server)){
	$logger->logdie("server was not defined");
    }
    if (!defined($vendor)){
	$logger->logdie("vendor was not defined");
    }

    ## We're overriding the env stored in conf/Prism.conf
    my $prismenv = "Chado:$vendor:$server";

    $ENV{PRISM} = $prismenv;
}

sub set_logger {

    my ($logfile, $debug_level) = @_;

    my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				     'LOG_LEVEL'=>$debug_level);
    

    my $logger = Coati::Logger::get_logger(__PACKAGE__);
    if (!defined($logger)){
	die "Could not get the Coati::Logger";
    }

    return $logger;
}

sub checkCommandLineArguments {

    
    &pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);

    &pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

    my $fatalCtr=0;

    if (!defined($database)){
	print STDERR ("--database was not defined\n");
	$fatalCtr++;
    }

    if (!defined($bsmldoc)){
	print STDERR ("--bsmldoc was not defined\n");
	$fatalCtr++;
    }


    if ($fatalCtr>0){
	die "Required command-line arguments were not provided\n";
	&print_usage();
    }

    if (!defined($username)){
	$username = 'access';
	print STDERR ("--username was not specified and therefore ".
		      "was set to '$username'\n");
    }

    if (!defined($password)){
	$password = 'access';
	print STDERR ("--password was not specified and therefore ".
		      "was set to '$password'\n");
    }


    if (!defined($database_type)){
	$database_type = 'Sybase';
	print STDERR ("--database_type was not specified and ".
		      "therefore was set to '$database_type'\n");
    }

    if (!defined($server)){
	$server = 'SYBTIGR';
	print STDERR ("--server was not specified and therefore ".
		      "was set to '$server'\n");
    }

    if (!defined($outdir)){
	$outdir = '/tmp/' . File::Basename::basename($0);
	print STDERR ("--outdir was not specified and therefore ".
		      "was set to '$outdir'\n");
    }

    $outdir .= '/';

    if (!defined($logfile)){
	$logfile = '/tmp/' . File::Basename::basename($0) . '.log';
	print STDERR ("--logfile was not specified and therefore ".
		      "was set to '$logfile'\n");
    }

    if (!$recordCountFile){
	my $basename = File::Basename::basename($bsmldoc);
	$recordCountFile = $outdir . '/' . $basename . '_record_count.rpt';
	print STDERR "--record_count_file was not specified and ".
	"therefore was set to '$recordCountFile'\n";
    }    
}



