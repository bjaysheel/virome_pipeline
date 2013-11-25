#!/usr/local/bin/perl
use strict;
use Data::Dumper;
use Annotation::Features::Repeat::IdMapper;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);


##
## Invocation is like this:
## perl testIdMapper.pl  --infile=/path/to/mapping/file --repeat=somevalue
##
## Contact sundaram@jcvi.org for concerns/questions.
##

## Do not buffer output stream
$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($infile, $help, $man, $rn1);

my $results = GetOptions (
			  'infile=s'          => \$infile,
			  'help|h'            => \$help,
			  'man|m'             => \$man,
			  'repeat=s'          => \$rn1,
			  );

&checkCommandLineArguments();

my $idmapper = new Annotation::Features::Repeat::IdMapper(filename=>$infile);

#print Dumper $idmapper; die;

if (!defined($idmapper)){
    die "Could not instantiate Annotation::Features::Repeat::IdMapper ".
    "for mapping file '$infile'";
}

my $newId = $idmapper->getId($rn1);

if (!defined($newId)){
    print "There was no corersponding value for repeat '$rn1'\n";
} else {
    print "The corresponding value for repeat '$rn1' is '$newId'\n";
}


print "$0 execution completed\n";
exit(0);

##-----------------------------------------------------------------
##
##    END OF MAIN -- SUBROUTINES FOLLOW
##
##-----------------------------------------------------------------

sub checkCommandLineArguments {

    if ($help){
	&pod2usage( {-exitval => 1, -verbose => 2, -output => \*STDOUT} ); 
	exit(1);
    }
    
    my $fatalCtr=0;

    if (!$infile){
	print "--infile was not specified\n";
	$fatalCtr++;
    }

    if (!$rn1){
	print "--repeat was not specified\n";
	$fatalCtr++;
    }

    if ( $fatalCtr > 0 ){
	die "Required command-line arguments were not specified";
    }
    

}
