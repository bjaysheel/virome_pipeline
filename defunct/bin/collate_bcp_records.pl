#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
# $Id: collate_bcp_records.pl 3145 2006-12-07 16:42:59Z angiuoli $


=head1 NAME

collate_bcp_records.pl - Merges all unique BCP records into one BCP file per table

=head1 SYNOPSIS

USAGE:  collate_bcp_records.pl --bcplistfile [--log4perl] [--cachefile] [--debug_level] [-h] [-m] [--outdir] [--skip] --table

=head1 OPTIONS

=over 8
 
=item B<--bcplistfile>
    
    File containing a listing of all input BCP files per chado table

=item B<--cachefile>

    Optional: Tied lookup cache file (Default is ./collate_bcp_records.$table.cch)

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--outdir>

    Optional: Output directory where final merged BCP file is to be written.  Default is current directory

=item B<--skip>

    Optional: Do not run this script, simply exit(0). Default is --skip=0 (do not skip)

=item B<--table>

    Optional: table files to be processed e.g. feature.out or db.out.  Default is all of the following analysis.out, feature_cvterm.out, feature.out, db.out

=item B<--help,-h>

    Print this help

=back

=head1 DESCRIPTION

    collate_bcp_records.pl - Merges all unique BCP records into one BCP file per table

    Sample output files: feature.out, db.out


    Assumptions: 

    1. User has appropriate permissions (to execute script, access chado database, write to output directory).
    2. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./collate_bcp_records.pl --bcplistfiler=/usr/local/scratch/dupdir/feature.bcp.list --log4perl=my.log --outdir=/tmp/outdir --table=feature



=cut



use strict;

use Coati::Logger;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Data::Dumper;
use File::Copy;
use Config::IniFiles;
use Split_DB_File;

my ($log4perl, $debug_level, $bcplistfile, $help, $outdir, $man,  $table, $skip, $cachefile);

my $results = GetOptions (
			  'bcplistfile=s'   => \$bcplistfile,
			  'log4perl=s'      => \$log4perl,
			  'debug_level|d=s' => \$debug_level, 
			  'help|h'          => \$help,
			  'outdir=s'        => \$outdir,
			  'man|m'           => \$man,
			  'skip=s'          => \$skip,
			  'table=s'         => \$table,
			  'cachefile=s'    => \$cachefile
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("bcplistfile was not defined\n")  if (!$bcplistfile);
print STDERR ("outdir was not defined\n")       if (!$outdir);
print STDERR ("table was not defined\n")        if (!$table);

&print_usage if(!$bcplistfile);
&print_usage if(!$outdir);
&print_usage if(!$table);
    

# Instantiate the Logger object
my $logger = &get_logger($log4perl, $debug_level);

# Determine whether this script should be executed
&is_skip($skip);

# Verify the output directory status
$outdir = &verify_and_set_outdir($outdir);

# Get list of all BCP files for the BCP list file
my $bcpfiles = &get_bcp_files($bcplistfile);

my $uniquerecords = &get_tied_lookup($cachefile, $table);

# Set the end of record separator
$/ = "\?\?\?\?\n";

# Define the collated BCP output filename
my $outfile = $outdir . "/$table.out.gz";

# Open the collated BCP file for output
my $fho;

open ($fho, ">:gzip", "$outfile") or $logger->logdie("Can't open $outfile for writing due to $!");

foreach my $file (@{$bcpfiles}){

    if (-e $file){

	if (-r $file){

	    if (!-z $file){
		
		# Open the BCP file for input
		open (INFILE, "<:gzip", "$file") || $logger->logdie("Could not open file '$file' for input: $!");
		
		while (my $line = <INFILE>){
		    
		    chomp $line;

		    my @x = split('\?\?\s+\?\?',$line);
		    
		    # Only store unique records
		    if (! exists $uniquerecords->{$x[0]}){

			$uniquerecords->{$x[0]}++;
			
			# Write the unique records to the BCP file
			print $fho $line . "\?\?\?\?\n";
		    }
		}
		close INFILE;
	    }
	    else {
		$logger->warn("file '$file' had zero content and so shall not be processed");
	    }
	}
	else {
	    $logger->logdie("file '$file' did not have read permissions");
	}
    }
    else{
	$logger->logdie("file '$file' does not exist");
    }
}


# Reset the end of record separator
$/ = '\n';

print "Finished merging all BCP records for table '$table'\n";
exit(0);



#--------------------------------------------------------------------------------------------------
#
#                    END OF MAIN -- SUBROUTINES FOLLOW
#
#--------------------------------------------------------------------------------------------------

#--------------------------------------
# get_bcp_files()
#
#--------------------------------------
sub get_bcp_files {

    my ($file) = @_;

    &check_file_status($file);

    if (!-z $file){
	
	my @files;
	
	open (INFILE, "<$file") || $logger->logdie("Could not open file '$file' for input: $!");
	
	while (my $line = <INFILE>){
	    
	    chomp $line;
	    
	    push (@files, $line);
	}
	close INFILE;
    
	return \@files;
    }
    else {
	$logger->warn("No BCP files listed in bcplistfile '$file'");
	exit(0);
    }

}

#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 --bcpfilelist [--log4perl] [--cachefile] [-d debug_level] [-h] [-m] [--outdir] [--skip] --table\n".
    "  --bcpfilelist         = File containing list of BCP files per chado table\n".
    "  --log4perl            = Optional - Log4perl log file (default: /tmp/dup_list.pl.log)\n".
    "  -m|--man              = Display pod2usage pages for this utility\n".
    "  -h|--help             = Display pod2usage help screen.\n".
    "  --cachefile           = Optional - Tied lookup cache file (Default is ./collate_bcp_records.\$table.cch)\n".
    "  -d|--debug_level      = Optional - Coati::Logger log4perl logging level (default level is 0)\n".
    "  --outdir              = Optional - Output directory where final merged BCP file should be written (Default is current working directory)\n".
    "  --skip                = Optional - Do not run this script, simply exit(0)\n".
    "  --table               = Optional - table\n";
    exit 1;

}



#------------------------------------------------------
# check_file_status()
#
#------------------------------------------------------
sub check_file_status {

    my $file = shift;

    if (!defined($file)){
	$logger->logdie("file '$file' was not defined");
    }

    if (!-e $file){
	$logger->logdie("file '$file' does not exist");
    }

    if (!-f $file){
	$logger->logdie("'$file' is not a file");
    }

    if (!-r $file){
	$logger->logdie("file '$file' does not have read permissions");
    }


}


#--------------------------------------------------
# get_logger()
#
#--------------------------------------------------
sub get_logger {

    my ($log4perl, $debug_level) = @_;

    $log4perl = "/tmp/collate_records.pl.log" if (!defined($log4perl));

    my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				     'LOG_LEVEL'=>$debug_level);
    

    return Coati::Logger::get_logger(__PACKAGE__);
}

#--------------------------------------------------
# is_skip()
#
#--------------------------------------------------
sub is_skip {

    my ($skip) = @_;

    if (!defined($skip)){
	$skip = 0;
    }
    if ( (defined($skip)) and ($skip == 1) ){
	$logger->info("skip parameter was specified, therefore will not run delete_refs.pl");
	exit(0);
    }
}

#--------------------------------------------------
# verify_and_set_outdir()
#
#--------------------------------------------------
sub verify_and_set_outdir {

    my ($outdir) = @_;
    #
    # Default outdir is current working directory
    #
    if (!defined($outdir)){
	$outdir = "./";
    }
    if (!-e $outdir){
	$logger->logdie("outdir '$outdir' does not exist");
    }
    if (!-d $outdir){
	$logger->logdie("outdir '$outdir' is not a directory");
    }
    if (!-w $outdir){
	$logger->logdie("outdir '$outdir' does not have write permissions");
    }
    
    return $outdir;
}



sub get_tied_lookup {

    my ($filename, $table) = @_;

    if (!defined($filename)){
	$filename = "./collate_bcp_records.$table.cch";
    }

    if (-e $filename){
	if ( -f $filename) {
	    unlink $filename;
	}
	elsif ( -d $filename) {
	    $logger->logdie("'$filename' is a directory");
	}
	else {
	    $logger->logdie("Don't know what to do with '$filename'");
	}
    }

    my %lookup;

    eval { tie %lookup, 'Split_DB_File', $filename, O_RDWR|O_CREAT, 0660, $DB_BTREE or $logger->logdie("Can't tie lookup $filename"); 
	  
      };
	 
    if ($@){
	$logger->logdie("Error detected:$!");
    }

    return \%lookup;
}

