#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
use strict;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use BSML2CHADO::Validator;
use Annotation::Util2;

use constant DEFAULT_USERNAME => 'sundaram';
use constant DEFAULT_PASSWORD => 'sundaram7';
use constant DEFAULT_SERVER   => 'SYBPROD';
use constant DEFAULT_VENDOR   => 'sybase';


$|=1; ## do not buffer output stream

## Parse command line options
my ($username, $password, $outfile, $database, $help,
    $man, $outdir, $server, $vendor, $bsmlfilelist);

my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'outfile=s'           => \$outfile,
			  'database|D=s'        => \$database,
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'vendor=s'            => \$vendor,
			  'bsmlfilelist=s'      => \$bsmlfilelist
			  );

&checkCommandLineArguments();


if (!Annotation::Util2::checkInputFileStatus($bsmlfilelist)){
    die "Detected some problem with BSML file list '$bsmlfilelist'";
}

my $validator = new BSML2CHADO::Validator(username=>$username,
					  password=>$password,
					  database=>$database,
					  server=>$server,
					  database_type=>$vendor,
					  filelist=>$bsmlfilelist,
					  reportfile=>$outfile);
if (!defined($validator)){
    die "Could not instantiate BSML2CHADO::Validator";
}

$validator->validate();


print "$0 execution completed\n";
print "The report file is '$outfile'\n";
exit(0);

##--------------------------------------------------------
##
##    END OF MAIN -- SUBROUTINES FOLLOW
##
##--------------------------------------------------------

sub checkCommandLineArguments {

    
    if ($man){
	&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
    }
    
    if ($help){
	&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
    }


    my $fatalCtr=0;
    
    if (!defined($bsmlfilelist)){
	print STDERR "--bsmlfilelist was not specified\n";
	$fatalCtr++;
    }

    if (!defined($database)){
	print STDERR "--database was not specified\n";
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
	$outfile = '/tmp/'. File::Basename::basename($0) . '_' . File::Basename::basename($bsmlfilelist) . '_' . $database . '.rpt.txt';
	print STDERR "--outfile was not specified and ".
	"therefore was set to '$outfile'\n";
    }


}
