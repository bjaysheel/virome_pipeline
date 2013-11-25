#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
=head1 NAME

consolidateIdMapFiles.pl - Reads in contents of ID map files and writes consolidated master .idmap.gz file

=head1 SYNOPSIS

USAGE:  consolidateIdMapFiles.pl [--input_directories] [--input_files] [-d debug_level] [-h] [--logfile] [-m] [--no_gzip] [--output_directory] [--output_file]

=head1 OPTIONS

=over 8

=item B<--input_directories>
    
Optional - comma-separated list of directories containing .idmap files that should be read

=item B<--input_files>
    
Optional - comma-separated list of .idmap files that should be read

=item B<--debug_level,-d>
    
Optional - Coati::Logger log4perl logging level (default is 0)

=item B<--help,-h>

Print this help

=item B<--logfile,-l>
    
Optional - Log4perl log file.  (default is /tmp/consolidateIdMapFiles.pl.log)

=item B<--man,-m>

Display pod2usage man page for this utility

=item B<--no_gzip>

Optional - User can specify that the output .idmap file should not be gzipped.

=item B<--output_directory>
    
Optional - directory where the consolidated master .idmap file should be written

=item B<--output_file>
    
Optional - output consolidated master .idmap file


=back

=head1 DESCRIPTION

    consolidateIdMapFiles.pl - Reads in contents of ID map files and writes consolidated master .idmap.gz file
    e.g.
    1) ./consolidateIdMapFiles.pl --input_directories=/usr/local/annotation/STREP/output_repository/id_mapping/2007-05-08/ --output_file=/usr/local/annotation/STREP/workflow/mapping/strep.idmap

=head1 CONTACT
                                                                                                                                                             
    Jay Sundaram
    sundaram@jcvi.org

=cut

use Pod::Usage;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Coati::Logger;
use File::Basename;
use File::Path;

## Don't buffer
$|=1;

my ($input_directories, $input_files, $debug_level, $help, $logfile, $man, $no_gzip, $output_directory, $output_file);

my $results = GetOptions ('input_directories=s'     => \$input_directories,
			  'input_files=s'      => \$input_files,
			  'debug_level=s'      => \$debug_level,
			  'help|h'             => \$help,
			  'logfile=s'          => \$logfile,
			  'man|m'              => \$man, 
			  'no_gzip=s'          => \$no_gzip,
			  'output_directory=s' => \$output_directory,
			  'output_file=s'      => \$output_file
			  );

if ($man){
    &pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
}
if ($help){
    &pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
}

if ((!defined($input_directories)) && (!defined($input_files))){
    print STDERR ("Neither --input_directories nor --input_files were defined\n");
    &printUsage();
}

## Initialize the logger
if (!defined($logfile)){
    $logfile = '/tmp/consolidateIdMapFiles.pl.log';
    print STDERR "logfile was set to '$logfile'\n";
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


my $oldToNewLookup = {};
my $dupOldLookup = {};
my $dupOldCtr=0;
my $diffOldId = {};
my $diffOldCtr=0;

my $newToOldLookup = {};
my $dupNewLookup = {};
my $dupNewCtr=0;
my $diffNewId = {};
my $diffNewCtr=0;

if (defined($output_directory)){
    &checkDirectory($output_directory);
}

&loadIdMappingLookup($input_directories, $input_files);

my $errorCtr=0;

if ($dupOldCtr>0){
    if ($dupOldCtr == 1){
	$logger->error("Found one instance where an old ID value was repeated");
    }
    else {
	$logger->error("Found '$dupOldCtr' instances where old ID values were repeated");
    }
    &reportDuplicates($dupOldLookup);
    $errorCtr++;
}

if ($dupNewCtr>0){
    if ($dupNewCtr == 1){
	$logger->error("Found one instance where a new ID value was repeated");
    }
    else {
	$logger->error("Found '$dupNewCtr' instances where new ID values were repeated");
    }
    &reportDuplicates($dupNewLookup);
    $errorCtr++;
}

if ($diffNewCtr>0){
    if ($diffNewCtr == 1){
	$logger->error("Found one instance where an old ID was associated with different new ID values");
    }
    else {
	$logger->error("Found '$diffNewCtr' instances where an old ID was associated with different new ID values");
    }
    &reportMismatches($diffNewId);
    $errorCtr++;
}

if ($diffOldCtr>0){
    if ($diffOldCtr == 1){
	$logger->error("Found one instance' where a new ID was associated with different old ID values");
    }
    else {
	$logger->error("Found '$diffOldCtr' instances where a new ID was associated with different old ID values");
    }
    &reportMismatches($diffOldId);
    $errorCtr++;
}

if ($errorCtr>0){
    $logger->logdie("Please review log file '$logfile'");
}

&writeIdMappingFile($output_directory, $output_file, $no_gzip);

print "The log file is '$logfile'\n";
print "$0 script execution complete\n";
exit(0);



#---------------------------------------------------------------------------------------
#
#            END MAIN -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------


##--------------------------------------------------------
## reportDuplicates()
##
##--------------------------------------------------------
sub reportDuplicates {

    my ($lookup) = @_;

    foreach my $id (sort keys %{$lookup}){
	$logger->error("'$id' was found in the following files:");
	foreach my $file ( @{$lookup->{$id}} ){
	    $logger->error("$file");
	}
    }
}

##--------------------------------------------------------
## reportMismatches()
##
##--------------------------------------------------------
sub reportMismatches {

    my ($lookup) = @_;

    foreach my $id (sort keys %{$lookup}){
	$logger->error("'$id' was linked to the following ids:");
	foreach my $id2 (sort keys %{$lookup->{$id}} ){
	    $logger->error("$id2");
	}
    }
}


sub checkDirectory {
    my $dir = shift;
    if (!defined($dir)){
	return "./";
    }
    else {
	if (!-e $dir){
	    $logger->logdie("directory '$dir' does not exist");
	}
	if (!-w $dir){
	    $logger->logdie("directory '$dir' does not have write permissions");
	}
    }

    return $dir;
}
##--------------------------------------------------------------
## writeIdMappingFile()
##
##--------------------------------------------------------------
sub writeIdMappingFile {

    my ($dir, $file, $no_gzip) = @_;

    if (!defined($file)){
	$dir = &checkDirectory($dir);
	$logger->info("file was not defined so setting to '$file'");
	$file = $dir . $$ . '.idmap';
    }

    if ((!defined($no_gzip)) || ($no_gzip != 1)){
	$file .= '.gz';
    }

    if (-e $file){
	my $bakFile = $file . '.' . $$ . '.bak';
	rename($file, $bakFile);
    }

    my $dirname = File::Basename::dirname($file);
    if (!defined($dirname)){
	$logger->logdie("Could not derive dirname from file '$file'");
    }
	
    if (!-e $dirname){
	mkpath($dirname) || $logger->logdie("Could not create directory '$dirname': !");
    }

    ## Keep count of the number of mappings written to the ID mapping file.
    my $idCtr = 0;
    
    my $fh;
   
    if ((defined($no_gzip)) && ($no_gzip == 1)){
	open ($fh, ">$file") || $logger->logdie("Could not open file '$file' for output: $!");
    }
    else {
	open ($fh, ">:gzip", "$file") || $logger->logdie("Could not open file '$file' for output: $!");
    }

    foreach my $oldId (keys %{$oldToNewLookup} ) {

	my $newId = $oldToNewLookup->{$oldId};
	
	print $fh "$oldId\t$newId\n";
	
	$idCtr++;
    }

    print "The number of mappings written to the ID mapping file '$file' was: '$idCtr'\n";
}

##--------------------------------------------------------
## loadIdMappingLookup()
##
##--------------------------------------------------------
sub loadIdMappingLookup {

    my ($directories, $infile) = @_;

    ## Keep counts
    my $idCtr = 0;
    my $dirCtr = 0;
    my $fileCtr = 0;

    if ((!defined($infile)) && (!defined($directories))){
	$logger->warn("Note that the user did not specify any directories nor input file that might contain input ".
			       "ID mappings. Consequently, all identifier (uniquename) values to be assigned to the features ".
			       "will be generated for the first time during the execution of this program.  These values ".
			       "will be written to a new ID mapping file.");
    }


    if (defined($infile)){
	if (defined($directories)){
	    $logger->warn("The infile was specified therefore none of the ID mapping files in directories '$directories' ".
				   "will be read.");
	}
	$idCtr += &loadIdMappingLookupFromFile($infile);
    }
    else {
	## User did specify some value(s) for directories that may 
	## contain ID mapping files with file extension '.idmap'.
	
	my @dirs = split(/,/,$directories);
	
	foreach my $directory ( @dirs ){
	    ## Process each directory one-by-one.
	    
	    if (!-e $directory){
		next;
	    }
	    if (!-d $directory){
		next;
	    }
	    if (!-r $directory){
		$logger->logdie("Directory '$directory' does not have read permissions");
	    }
	    
	    ## Keep count of the number of directories that were scanned for ID mapping files.
	    $dirCtr++;
	    
	    opendir(THISDIR, "$directory") || $logger->logdie("Could not open directory '$directory':$!");

	    my @allfiles1 = grep {$_ ne '.' and $_ ne '..' } readdir THISDIR;

	    my @allfiles;
	    foreach my $file (@allfiles1){
		if ($file =~ /\S+\.idmap$/){
		    push(@allfiles, $file);
		}
		elsif ($file =~ /\S+\.idmap.gz$/){
		    push(@allfiles, $file);
		}
		elsif ($file =~ /\S+\.idmap.gzip$/){
		    push(@allfiles, $file);
		}
	    }

	    my $fileCount = scalar(@allfiles);
	    
	    if ($fileCount > 0){
		$logger->info("Found '$fileCount' ID mapping files in directory '$directory'");

		## There was at least one .idmap file in the directory.
		
		foreach my $file (@allfiles){
		    
		    $file = $directory .'/'. $file;
		    
		    $idCtr += &loadIdMappingLookupFromFile($file);

		    $fileCtr++;
		}
	    }
	    else {
		$logger->warn("This directory '$directory' did not have any ID mapping files with file extension '.idmap'");
	    }
	}
    }


    if ($idCtr>0){
	if ($logger->is_debug()){
	    $logger->debug("'$idCtr' mappings were loaded onto the ID mapping lookup. ".
			   "'$fileCtr' ID mapping files with extension '.idmap' were ".
			   "read in from '$dirCtr' directories.");
	}
    }
    else {
	$logger->warn("No ID mappings were loaded onto the ID mapping lookup. ".
			       "'$fileCtr' ID mapping files with extension '.idmap' were ".
			       "read in from '$dirCtr' directories.");
    }

    $logger->info("All ID mapping loading complete.\n".
			   "Number of directories scanned for ID mapping files with extension '.idmap': '$dirCtr'\n".
			   "Number of ID mapping files read: '$fileCtr'\n".
			   "Number of ID mappings loaded into the ID mapping lookup: '$idCtr'");
}


##--------------------------------------------------------
## loadIdMappingLookupFromFile()
##
##--------------------------------------------------------
sub loadIdMappingLookupFromFile {

    my ($infile) = @_;

    ## Keep counts
    my $idCtr = 0;
    my $fileCtr = 0;

    if (!defined($infile)){
	$logger->logdie("The infile was not defined");
    }

    my @allfiles = split(/,/, $infile);
    
    my $fileCount = scalar(@allfiles);
    
    if ($fileCount > 0){
	## There was at least one .idmap file in the directory.
	
	foreach my $file (@allfiles){
	    
	    if (!-e $file){
		$logger->logdie("file '$file' does not exist");
	    }
	    if (!-r $file){
		$logger->logdie("file '$file' does not have read permissions");
	    }
	    if (!-f $file){
		$logger->logdie("file '$file' is not a regular file");
	    }
	    if (-z $file){
		$logger->logdie("file '$file' has zero content.  No ID mappings to read.");
	    }
	    if ($file =~ /\.idmap$/){
		$logger->debug("will read from file '$file'");
	    }
	    elsif ($file =~ /\.gz$|\.gzip$/){
		$logger->debug("will read from file '$file'");
	    }		
	    else {
		$logger->logdie("file '$file' has neither .idmap, .idmap.gz nor .idmap.gzip extension");
	    }

	    ## Keep count of the number of ID mapping files that were read.
	    $fileCtr++;
	    
	    my $fh;
	    if ($file =~ /\.gz$|\.gzip$/) {
		open ($fh, "<:gzip", "$file") || $logger->logdie("Could not open ID mapping file '$file' for input: $!");
	    }
	    else {
		open ($fh, "<$file") || $logger->logdie("Could not open ID mapping file '$file' for input: $!");
	    }

	    while (my $line = <$fh>){
		
		chomp $line;
		
		my ($oldid, $newid) = split(/\s+/, $line);
		
		if ( exists $oldToNewLookup->{$oldid}){
		    $dupOldCtr++;
		    push (@{$dupOldLookup->{$oldid}}, $file);
		    if ($oldToNewLookup->{$oldid} ne $newid){
			if (! exists $diffNewId->{$oldid}->{$newid}){
			    $diffNewId->{$oldid}->{$newid}++;
			}
			if (! exists $diffNewId->{$oldid}->{$oldToNewLookup->{$oldid}}){
			    $diffNewId->{$oldid}->{$oldToNewLookup->{$oldid}}++;
			}
			$diffNewCtr++;
		    }
		}
		
		$oldToNewLookup->{$oldid} = $newid;

		if ( exists $newToOldLookup->{$newid}){
		    $dupNewCtr++;
		    push (@{$dupNewLookup->{$newid}}, $file);
		    if ($newToOldLookup->{$newid} ne $oldid){
			if (! exists $diffOldId->{$newid}->{$oldid}){
			    $diffOldId->{$newid}->{$oldid}++;
			}
			if (! exists $diffOldId->{$newid}->{$newToOldLookup->{$newid}}){
			    $diffOldId->{$newid}->{$newToOldLookup->{$newid}}++;
			}
			$diffOldCtr++;
		    }
		}
		
		$newToOldLookup->{$newid} = $oldid;
		

		## Keep count of the number of mappings that are loaded onto the lookup.
		$idCtr++;
	    }
	}
    }
    else {
	$logger->logdie("There were no ID mapping files to read.  Input was infile '$infile'");
    }

    
    if ($idCtr>0){
	if ($logger->is_debug()){
	    $logger->debug("'$idCtr' mappings were loaded onto the ID mapping lookup. ".
			   "'$fileCtr' ID mapping files with extension '.idmap' were read.");
	}
    }
    else {
	$logger->warn("No ID mappings were loaded onto the ID mapping lookup. ".
			       "'$fileCtr' ID mapping files with extension '.idmap' were read.");
    }

    $logger->info("Number of ID mapping files read: '$fileCtr'\n".
			   "Number of ID mappings loaded into the ID mapping lookup: '$idCtr'");
    
    return $idCtr;
}

#--------------------------------------------------------------------
# printUsage()
#
#--------------------------------------------------------------------
sub printUsage {

    print STDERR "SAMPLE USAGE:  $0 [--input_directories] [--input_files] [-d debug_level] [-h] [--logfile] [-m] [--no_gzip] [--output_directory] [--output_file]\n".
    "  --input_directories = Optional - die if the database does not exist\n".
    "  --input_files       = Relational database\n".
    "  -d|--debug_level    = Optional - Coati::Logger log4perl logging level (default is 0)\n".
    "  -h|--help           = Optional - This help message\n".
    "  --logfile           = Optional - log4perl log file (default is /tmp/consolidateIdMapFiles.pl.log)\n".
    "  -m|--man            = Optional - Display the pod2usage man page for this utility\n".
    "  --no_gzip           = Optional - does not write output .idmap file in compressed format\n".
    "  --output_directory  = Optional - directory where the .idmap file should be written\n".
    "  --output_file       = Optional - .idmap file\n";
    exit(1);
}
