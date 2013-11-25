#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
use strict;
use Data::Dumper;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($btabfile, $outfile, $mappingfile, $debug_level, $help, $man);


my $results = GetOptions (
			  'btabfile=s'       => \$btabfile, 
			  'outfile=s'        => \$outfile,
			  'mappingfile=s'    => \$mappingfile,
			  'debug_level|d=s'  => \$debug_level, 
			  'help|h'           => \$help,
			  'man|m'            => \$man
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

my $fatalCtr=0;

if (!defined($btabfile)){
    print STDERR ("btabfile was not defined\n");
    $fatalCtr++;
}
if (!defined($outfile)){
    print STDERR ("outfile was not defined\n");
    $fatalCtr++;
}
if (!defined($mappingfile)){
    print STDERR ("mappingfile was not defined\n");
    $fatalCtr++;
}

if ($fatalCtr>0){
    &print_usage();
}

&checkFileStatus($btabfile);
&checkFileStatus($mappingfile);

my $idMappingLookup = &getIdMappingLookup($mappingfile);

#print Dumper $idMappingLookup;die;

open (OUTFILE, ">$outfile") || die "Could not open outfile '$outfile':$!";
open (INFILE, "<$btabfile") || die "Could not open btabfile '$btabfile': $!";

my $lineCtr=0;
while (my $line = <INFILE>){

    chomp $line;

    $lineCtr++;

    my @fields = split(/\t/, $line);
   
    if (exists $idMappingLookup->{$fields[0]}){
	my $oldid = $idMappingLookup->{$fields[0]};
	$fields[0] = $oldid;
    }
    else {
	print Dumper $idMappingLookup;
	die "At line '$lineCtr' of BTAB file '$btabfile' field '0' '$fields[0]' did not ".
	"exist in the ID mapping lookup! Line was '$line'";
    }
    if (exists $idMappingLookup->{$fields[5]}){
	my $oldid = $idMappingLookup->{$fields[5]};
	$fields[5] = $oldid;
    }
    else {
	print Dumper $idMappingLookup;
	die "At line '$lineCtr' of BTAB file '$btabfile' field [5] '$fields[5]' did not ".
	"exist in the ID mapping lookup!  Line was '$line'";
    }

    my $i;

    for( $i=0 ; $i < scalar(@fields) - 1 ; $i++){
	print OUTFILE "$fields[$i]\t";
    }
    print OUTFILE "$fields[$i]\n";

}



print "$0 program execution has completed\n";
exit(0);



#------------------------------------------------------
# checkFileStatus()
#
#------------------------------------------------------
sub checkFileStatus {
    my ($file) = @_;

    if (!-e $file){
	die "file '$file' does not exist";
    }
    if (!-r $file){
	die "file '$file' does not have read permisisons";
    }
    if (!-f $file){
	die "file '$file' is not a file";
    }
    if (-z $file){
	die "file '$file' does not have any content";
    }
}


#------------------------------------------------------
# getIdMappingLookup()
#
#------------------------------------------------------
sub getIdMappingLookup {
    
    my ($mappingfile) = @_;

    open (MAPFILE, "<$mappingfile") || die "Could not open mappingfilee '$mappingfile': $!";

    my $idMappingLookup = {};

    while (my $line = <MAPFILE>){

	chomp $line;

	my ($old, $new) = split(/\t/,$line);

	my @temp = split(/_/, $old);
	
	$idMappingLookup->{$new} = $temp[2];
    }

    return $idMappingLookup;
}


#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 [-h] --btabfile [-m] --mappingfile --outfile\n".
    "  --btabfile          = The BTAB file\n".
    "  --outfile           = Output BTAB file to be written with identifiers replaced\n".
    "  --mappingfile       = ID mapping file\n".
    "  -h|--help           = Optional - Display pod2usage help screen\n".
    "  -m|--man            = Optional - Display pod2usage pages for this utility\n";

    exit(1);

}

