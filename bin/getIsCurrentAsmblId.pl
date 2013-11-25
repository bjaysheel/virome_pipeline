#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
##
## Real simple way to find the iscurrent=1 asmbl_id values
##
=head1 NAME

getIsCurrentAsmblId.pl -

=head1 SYNOPSIS

USAGE:  getIsCurrentAsmblId.pl --database-list=<database-list> --database-list-file<file> [--control-file=<legacy2bsml-control-file>] [--logfile=<logfile>] [-m|--man]

=head1 OPTIONS

=over 8

=item B<--database-list>

Optional - Should be the same comma-separated list of sgc/prok databases

=item B<--database-list-file>

Optional - File containing new-line separated list of sgc/prok databases

=item B<--generate-control-file>

Optional - If a control file is specified, this script will generate that named legacy2bsml control file

=item B<--help,-h>

Print this help

=item B<--logfile>

Optional - Basic log file (default is /tmp/getIsCurrentAsmblId.pl.log)

=item B<--man,-m>

Display the pod2usage page for this utility

=back

=head1 DESCRIPTION

getIsCurrentAsmblId.pl - 

 Assumptions:
1. User has appropriate permissions (to execute script, access database, write to output directory).
3. All software has been properly installed, all required libraries are accessible.

Sample usage:

perl getIsCurrentAsmblId.pl --database-list=ntcp03,bcl,gcpe,ntcb02,ntcd03,ntcm01,ntca01,ntct02,bcpe2,bcb2,bcb3,bcb6
perl getIsCurrentAsmblId.pl --database-list-file=/tmp/my.list
perl getIsCurrentAsmblId.pl --database-list-file=/tmp/my.list --control-file=/tmp/control.txt

=head1 CONTACT

Jay Sundaram
sundaram@jcvi.org

=cut

use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use File::Basename;
use Data::Dumper;
use DBI;
use Carp;
use Mail::Mailer;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($database_list, $database_list_file, $control_file, $help, $logfile, $man);

my $results = GetOptions (
			  'database-list=s'      => \$database_list,
			  'database-list-file=s' => \$database_list_file, 
			  'control-file=s'       => \$control_file, 
			  'help|h'               => \$help,
			  'logfile=s'            => \$logfile,
			  'man|m'                => \$man
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

my $fatalCtr=0;

if ((!defined($database_list)) && (!defined($database_list_file))){
    print STDERR ("database_list or database_list_file must be defined\n");
    $fatalCtr++;
}

if ($fatalCtr>0){
    &print_usage();
}

if (!defined($logfile)){
    $logfile = '/tmp/getIsCurrentAsmblId.pl.log';
}

open (LOGFILE, ">$logfile") || confess "Could not open log file '$logfile' in write mode: $!";

use strict;
use Carp;


my $masterDatabaseList = $database_list; 

if (defined($database_list_file)){
    $masterDatabaseList .= &getCommaSeparatedListFromFile($database_list_file);
}

my $databaseAsmblIdLookup = &getDatabaseAsmblIdLookup($masterDatabaseList);



if (defined($control_file)){
    &createLegacy2bsmlControlFile($control_file, $databaseAsmblIdLookup, $database_list, $database_list_file, $logfile);
}
else {
    &report($databaseAsmblIdLookup);
}


print "$0 execution completed\n";
print "Please review log file '$logfile'\n";
exit(0);

##-------------------------------------------------------------------
##
##              END OF MAIN -- SUBROUTINES FOLLOW
##
##-------------------------------------------------------------------

sub createLegacy2bsmlControlFile {
    
    my ($control_file, $databaseAsmblIdLookup, $database_list, $database_list_file, $logfile) = @_;

    print "Creating legacy2bsml control file '$control_file'\n";

    my $databaseCtr=0;

    my $asmblIdCtr=0;

    my $masterString;

    foreach my $database (sort keys %{$databaseAsmblIdLookup}){
	
	$databaseCtr++;

	my $string ="database:$database organism_type:prok include_genefinders: exclude_genefinders:all\n";

	foreach my $asmbl_id (sort { $a <=> $b }  keys %{$databaseAsmblIdLookup->{$database}}){

	    $asmblIdCtr++;

	    $string .= "$asmbl_id\n";
	}
	
	$masterString .= $string;
    }


    open (CONTROLFILE, ">$control_file") || confess "Could not open control file '$control_file' in write mode:$!";

    my $date = `date`;

    chomp $date;

    my $login = getlogin();

    my $prefix = "# This legacy2bsml control file was generated on '$date'\n".
    "# by user '$login'\n".
    "# The script invocation was:\n# $0 --control-file=$control_file";
    
    if (defined($database_list)){
	$prefix .= " --database-list=$database_list";
    }

    if (defined($database_list_file)){
	$prefix .= " --database-list-file=$database_list_file";
    }

    $prefix .= " --logfile=$logfile\n# Number of database values '$databaseCtr'\n# Number of asmbl_id values '$asmblIdCtr'\n";
    
    print CONTROLFILE $prefix . $masterString;

    close CONTROLFILE;

    print LOGFILE "Added '$databaseCtr' databases and '$asmblIdCtr' asmbl_id values to control file '$control_file'\n";
}


sub getDatabaseAsmblIdLookup {

    my ($database_list) = @_;

    my @databaseList = split(/,/,$database_list);

    my $databaseAsmblIdLookup={};

    print "Will attempt to retieve database/asmbl_id data from the server\n";

    foreach my $db (@databaseList){

	if ($db eq ''){
	    next;
	}

	my $sql = "SELECT a.asmbl_id FROM assembly a, stan s WHERE s.iscurrent = 1 AND s.asmbl_id = a.asmbl_id;";

	my $execstring = "echo \"$sql\" | sqsh -U access -P access -D $db -h";

	my @results = qx{$execstring};
	
	chomp @results;

	foreach my $asmbl_id (@results){

	    $asmbl_id =~ s/^\s+//;
	    $asmbl_id =~ s/\s+$//;
	    
	    $databaseAsmblIdLookup->{$db}->{$asmbl_id}++;

	}
    }

    return $databaseAsmblIdLookup;
}

sub report {

    my ($databaseAsmblIdLookup) = @_;

    my $databaseCtr=0;

    my $asmblIdCtr=0;

    foreach my $database (sort keys %{$databaseAsmblIdLookup}){

	$databaseCtr++;

	print "The current asmbl_id values for database '$database' are:\n";

	foreach my $asmbl_id (sort keys %{$databaseAsmblIdLookup->{$database}}){

	    $asmblIdCtr++;

	    print "$asmbl_id\n";

	}
    }
    print LOGFILE "All in all, counted '$databaseCtr' databases with '$asmblIdCtr' asmbl_id values\n";
}

=item print_usage()

B<Description:> Describes proper invocation of this program

B<Parameters:> None

B<Returns:> None

=cut

sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 --database-list=<database-list> --database-list-file=<database list file>] [--control-file=<legacy2bsml control file>] [-h|--help] [--logfile=<logfile>] [-m|--man]\n".
    "  --database-list      = Optional - Comma-separated list of sgc/prok databases\n".
    "  --database-list-file = Optional - file that contains new-line separated list of sgc/prok databases\n".
    "  --control-file       = Optional - Will create legacy2bsml control file\n".
    "  -h|--help            = Optional - Display pod2usage help screen\n".
    "  --logfile            = Optional - Basic log file (default is /tmp/getIsCurrentAsmblId.pl.log)\n".
    "  -m|--man             = Optional - Display pod2usage pages for this utility\n";
    exit(1);
}

sub getCommaSeparatedListFromFile {

    my ($file) = @_;

    if (!-e $file){
	confess "file '$file' does not exist";
    }
    if (!-f $file){
	confess "'$file' is not a file.";
    }
    if (!-s $file){
	confess "file '$file' does not have any content!";
    }
    if (!-r $file){
	confess "file '$file' does not have read permissions!";
    }

    open (INFILE, "<$file") || confess "Could not open file '$file' in read mode: $!";
    
    my $lineCtr=0;
    
    my $list;
    
    while (my $line = <INFILE>){
	
	$lineCtr++;
	
	chomp $line;

	## Now expecting a record with white-space separated fields where
	## the database name in the first field.

	my @parts = split(/\s+/, $line);
	$list .= "$parts[0],";
    }
    chop $list;
    
    print LOGFILE "Read '$lineCtr' lines from file '$file'\n";
    
    return $list;
}
