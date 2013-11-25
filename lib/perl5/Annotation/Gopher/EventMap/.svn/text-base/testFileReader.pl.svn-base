#!/usr/local/bin/perl
use strict;
use Data::Dumper;
use Annotation::Gopher::EventMap::FileReader;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);


##
## Invocation is like this:
## perl testFileReader.pl  --infile=/path/to/mapping/file
##
## Contact sundaram@jcvi.org for concerns/questions.
##

## Do not buffer output stream
$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($infile, $help, $man);

my $results = GetOptions (
			  'infile=s'          => \$infile,
			  'help|h'            => \$help,
			  'man|m'             => \$man,
			  );

&checkCommandLineArguments();

my $reader = new Annotation::Gopher::EventMap::FileReader(filename=>$infile);

#print Dumper $reader; die;

if (!defined($reader)){
    die "Could not instantiate Annotation::Gopher::EventMap::FileReader ".
    "for file '$infile'";
}

my $accession = 'AAFB02000004';
my $gopher_id = 1104750507028;
my $event_id = 1105170360677;



## Tests for retrieving the accession value

my $retAccession1 = $reader->getAccessionByEventId($event_id);
if (!defined($retAccession1)){
    print "accession did not exist for event_id '$event_id'\n";
} else {
    print "Retrieved accession '$retAccession1' for event_id '$event_id'\n";
}

my $retAccession2 = $reader->getAccessionByGopherId($gopher_id);
if (!defined($retAccession2)){
    print "accession did not exist for gopher_id '$gopher_id'\n";
} else {
    print "Retrieved accession '$retAccession2' for gopher_id '$gopher_id'\n";
}



## Tests for retrieving the event_id value

my $retEventId1 = $reader->getEventIdByAccession($accession);
if (!defined($retEventId1)){
    print "event_id did not exist for accession '$accession'\n";
} else {
    print "Retrieved event_id '$retEventId1' for accession '$accession'\n";
}

my $retEventId2 = $reader->getEventIdByGopherId($gopher_id);
if (!defined($retEventId2)){
    print "event_id did not exist for gopher_id '$gopher_id'\n";
} else {
    print "Retrieved event_id '$retEventId2' for gopher_id '$gopher_id'\n";
}




## Tests for retrieving the event_id value

my $retGopherId1 = $reader->getGopherIdByAccession($accession);
if (!defined($retGopherId1)){
    print "gopher_id did not exist for accession '$accession'\n";
} else {
    print "Retrieved gopher_id '$retGopherId1' for accession '$accession'\n";
}

my $retGopherId2 = $reader->getGopherIdByEventId($event_id);
if (!defined($retGopherId2)){
    print "gopher_id did not exist for event_id '$event_id'\n";
} else {
    print "Retrieved gopher_id '$retGopherId2' for event_id '$event_id'\n";
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

    if ( $fatalCtr > 0 ){
	die "Required command-line arguments were not specified";
    }
    

}
