#!/usr/local/bin/perl

=head1 NAME

oboRecordSorter.pl - Parse OBO formatted ontology file and create a new one with the records sorted by id tag

=head1 SYNOPSIS

USAGE:  oboRecordSorter.pl [-h] --infile [--logfile] [-m] --outfile

=head1 OPTIONS

=over 8

=item B<--help,-h>

    Print this help

=item B<--infile>

    The OBO file to be processed

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--outfile>

    The name of new OBO file to be created.

=back

=head1 DESCRIPTION

    oboRecordSorter.pl - Parse OBO formatted ontology file and create a new one with the records sorted by id tag

    Sample usage:
    perl ./oboRecordSorter --infile=/usr/local/devel/ANNOTATION/ard/testing_manual/docs/obo/so.obo --outfile=/usr/local/scratch/sundaram/so.obo.sorted

=head1 AUTHOR

Jay Sundaram

sundaram@tigr.org

=cut

use strict;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;


$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($debug, $help, $infile, $man, $outfile);


my $results = GetOptions (
			  'debug=s'    => \$debug, 
			  'help|h'     => \$help,
			  'infile=s'   => \$infile,
			  'man|m'      => \$man,
			  'outfile=s'  => \$outfile
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

my $fatalCtr=0;

if (!defined($infile)){
    print STDERR ("infile was not defined\n");
    $fatalCtr++;
}
if (!defined($outfile)){
    print STDERR ("outfile was not defined\n");
    $fatalCtr++;
}

if ($fatalCtr>0){
    &print_usage();
}


## Check mission critical file permissions
&checkFile($infile);

# The unique id variable is defined outside the loop
my $id;
my $stanzaType;
my $someStanzaEncountered;
my $oboLookup = {};

print "Will process OBO file '$infile' and created '$outfile'\n";

open (INFILE, "<$infile") || die "Could not open infile '$infile':$!";
open (OUTFILE, ">$outfile") || die "Could not open outfile '$outfile':$!";

my $lineCtr=0;

while (my $line = <INFILE>){

    chomp $line;

    $lineCtr++;

    if ($line =~ /^\[(.*)\]/){
	
	$stanzaType = $1;

	$someStanzaEncountered = 1;

	## undefine the current id value
	$id = undef;
	next;

    }
    if ($someStanzaEncountered == 0){
	## This will print everything at the head of the
	## input OBO file up to the first encountered stanza.
	print OUTFILE $line ."\n";
    }
    else {
	
	if ($line =~ /^id:/){
	    $id = $line;
	    ## strip trailing white spaces
	    $id =~ s/\s+$//;

	    if (defined($stanzaType)){
		$oboLookup->{$id}->{'stanza'} = $stanzaType;
	    }
	    else {
		die "stanzaType was not defined for id '$id' line number '$lineCtr' line '$line'";
	    }
	}
	else {
	    if (defined($id)){
		push(@{$oboLookup->{$id}->{'attr'}}, $line);
	    }
	    else {
		die "id was not defined for line '$line'";
	    }
	}
    }
}

my $recCtr=0;
foreach my $id ( sort keys %{$oboLookup} ){
    $recCtr++;
    my $stanza = $oboLookup->{$id}->{'stanza'};
    print OUTFILE "[$stanza]\n$id\n";
    foreach my $attr ( @{$oboLookup->{$id}->{'attr'}} ){
	print OUTFILE "$attr\n";
    }
}



print "$0 program execution completed\n";
print "Sorted OBO file was created '$outfile'\n";
print "$recCtr records were sorted\n";
exit(0);

#---------------------------------------------------------------------------------------------------------------------
#
#                                  END OF MAIN  -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------------------------------------

##-------------------------------------------------------------------
## checkFile()
##
##------------------------------------------------------------------
sub checkFile {

    my ( $file) = @_;

    if (!defined($file)){
	die "file was not defined";
    }

    if (!-e $file){
	die "file '$file' does not exist";
    }
    if (!-f $file){
	die "file '$file' is not a regular file";
    }
    if (!-r $file){
	die "file '$file' does not have read permissions";
    }
    if (-z $file){
	die "file '$file' has no content";
    }

}

##------------------------------------------------------
## print_usage()
##
##------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 [-h] --infile [-m] --outfile\n".
    "  -h|--help   = Display pod2usage help screen.\n".
    "  --infile    = Name of input OBO file to be parsed\n";
    "  -m|--man    = Display pod2usage pages for this utility\n".
    "  --outfile   = Name of output file to contain sorted records\n";
    exit 1;

}


