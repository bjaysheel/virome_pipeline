#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
=head1 NAME

bcpConverter.pl - Creates PostgreSQL COPY compatible input files based on Sybase BCP input files

=head1 SYNOPSIS

USAGE:  bcpConverter.pl [--compress_output] [-d debug_level] [-h] --indir [--input_ext] --input_format [-l logfile] [-m] --outdir [--output_ext] --output_format [--table]

=head1 OPTIONS

=over 8

=item B<--compress_output>
    
    Optional - Write output BCP files in gzip format (default is no compression)

=item B<--debug_level,-d>
    
    Optional - Coati::Logger log4perl logging level (default is 0)

=item B<--help,-h>

    Print this help

=item B<--indir>
    
    Directory contain the input BCP files (of type --input_format) to be converted to --output_format type

=item B<--input_ext>
    
    Optional - The file extension for the input type e.g. 'out'

=item B<--input_format>
    
    Vendor type of input files. Valid types currently are sybase, postgresql

=item B<--logfile,-l>
    
    Optional - Log4perl log file.  (default is /tmp/bcpConverter.pl.log)

=item B<--man,-m>

    Display pod2usage man page for this utility

=item B<--outdir>
    
    Directory where converted BCP files will be output

=item B<--output_ext>
    
    Optional - The file extension for the output type e.g. 'bcp'

=item B<--output_format>
    
    Vendor type of output files. Valid types currently are sybase, postgresql

=item B<--table>
    
    Optional - the user can specify the table whose corresponding BCP file will be converted




=back

=head1 DESCRIPTION

    bcpConverter.pl - Converts BCP files from one vendor supported type to another
    e.g.
    1) ./bcpConverter.pl --input_format sybase --output_format postgresql --indir /tmp/indir --outdir /tmp/outdir
    2) ./bcpConverter.pl --input_format sybase --output_format postgresql --indir /tmp/indir --outdir /tmp/outdir --logfile /tmp/my.log --output_ext .bcp
    3) ./bcpConverter.pl --input_format sybase --output_format postgresql --indir /tmp/indir --outdir /tmp/outdir --compress_output=1

=head1 CONTACT
                                                                                                                                                             
    Jay Sundaram
    sundaram@tigr.org

=cut

use Prism;
use Pod::Usage;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use File::Basename;
use File::Copy;
use Coati::Logger;
use Data::Dumper;

## Don't buffer
$|=1;


## Supported BCP formats
my $supportedBcpFormats = { 'postgresql' => 1,
			    'sybase' => 1,
			    'mysql' => 1};

## Adopted Sybase delimiters
my $sybaseLookup = { 'field' => "\0\t",
		     'row' => "\0\n" };

## Adopted PostgreSQL delimiters
my $postgresSQLLookup = {'field' => "\t",
			 'row' => "\n",
			 'null' => '\N' };

## Adopted mySQL delimiters
my $mysqlLookup = {'field' => "\t",
		   'row' => "\n",
		   'null' => '\N' };

my $convensionsLookup = { 'sybase' => $sybaseLookup,
			  'postgresql' => $postgresSQLLookup,
			  'mysql' => $mysqlLookup};

## Default BCP file extesions
my $defaultExtensionLookup = { 'sybase' => 'sybase.bcp',
			       'postgresql' => 'psql.bcp',
			       'oracle' => 'oracle.bcp',
			       'mysql' => 'mysql.bcp' };

## Valid compress output values
my $validCompressOutputValues = { '1' => 1,
				  '0' => 1 };


## The following tables contain BIT/BOOLEAN fields
## Note that GMOD has defined cvterm.is_relationshiptype with INT data type
my $tableinfoBooleanLookup = { '3' => 1,
			       '6' => 1 };

my $cvterm_dbxrefBooleanLookup = { '3' => 1 };

my $pubBooleanLookup = { '11' => 1 };

my $pub_dbxrefBooleanLookup = {'3' => 1};

my $pubauthorBooleanLookup = {'3' => 1};

my $featureBooleanLookup = {'9' => 1,
			    '10' => 1};

my $featurelocBooleanLookup = {'4' => 1,
			       '6' => 1};

my $feature_dbxrefBooleanLookup = {'3' => 1 };

my $feature_cvtermBooleanLookup = {'4' => 1 };

my $feature_synonymBooleanLookup = {'4' => 1,
				    '5' => 1 };

my $tableColumnBooleanLookup = { 'tableinfo' => $tableinfoBooleanLookup,
				 'cvterm_dbxref' => $cvterm_dbxrefBooleanLookup,
				 'pub' => $pubBooleanLookup,
				 'pub_dbxref' => $pub_dbxrefBooleanLookup,
				 'pubauthor' => $pubauthorBooleanLookup,
				 'feature' => $featureBooleanLookup,
				 'featureloc' => $featurelocBooleanLookup,
				 'feature_dbxref' => $feature_dbxrefBooleanLookup,
				 'feature_cvterm' => $feature_cvtermBooleanLookup,
				 'feature_synonym' => $feature_synonymBooleanLookup
			     };


my ($inputFormat, $outputFormat, $indir, $outdir, $log4perl, $help,
    $man, $debug_level, $inputFileExtension, $outputFileExtension,
    $compressOutput, $table);

my $results = GetOptions (
			  'input_format=s'    => \$inputFormat,
			  'output_format=s'   => \$outputFormat,
			  'indir=s'           => \$indir,
			  'outdir=s'          => \$outdir,
			  'debug_level|d=s'   => \$debug_level,
			  'help|h'            => \$help, 
			  'logfile|l=s'       => \$log4perl,
			  'man|m'             => \$man,
			  'input_ext=s'       => \$inputFileExtension,
			  'output_ext=s'      => \$outputFileExtension,
			  'compress_output=s' => \$compressOutput,
			  'table=s'           => \$table
			  );


if ($man){
    &pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
}

if ($help){
    &pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
}

my $fatalCtr=0;

if (!$inputFormat){
    print STDERR ("input_format not specified\n");
    $fatalCtr++;
}

if (!$outputFormat){
    print STDERR ("output_format not specified\n");
    $fatalCtr++;
}

if (!$indir){
    print STDERR ("indir not specified\n");
    $fatalCtr++;
}

if (!$outdir){
    print STDERR ("outdir not specified\n");
    $fatalCtr++;
}

if ($fatalCtr > 0 ){
    &printUsage();
}


## Initialize the logger
if (!defined($log4perl)){
    if (!defined($table)){
	$log4perl = '/tmp/bcpConverter.pl.log';
    }
    else {
	$log4perl = '/tmp/bcpConverter.pl.' . $table . '.log';
    }
    print STDERR "log_file was set to '$log4perl'\n";
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

if ( ! exists $supportedBcpFormats->{$inputFormat}){
    $logger->logdie("Input format '$inputFormat' is not supported");
}

if ( ! exists $supportedBcpFormats->{$outputFormat}){
    $logger->logdie("Output format '$outputFormat' is not supported");
}

if ($outputFormat eq $inputFormat){
    $logger->logdie("input_format '$inputFormat' == output_format '$outputFormat' (are you kidding me?)");
}

if (!defined($outputFileExtension)){
    $outputFileExtension = $defaultExtensionLookup->{$outputFormat};
}

if (!defined($inputFileExtension)){
    $inputFileExtension = $defaultExtensionLookup->{$inputFormat};
}

## strip leading . on the file extensions
$inputFileExtension =~ s/^\.//;
$outputFileExtension =~ s/^\.//;

## we shouldn't output to the same input directory if the file extensions
## are the same.
if (($indir eq $outdir) && ($inputFileExtension eq $outputFileExtension)){
    $logger->logdie("indir '$indir' == outdir '$outdir' and input_ext ".
		    "'$inputFileExtension' == output_ext '$outputFileExtension'. ".
		    "\nEither change the one of the directories or one of the file ".
		    "extensions.");
}

if (defined($compressOutput)){
    if (! exists $validCompressOutputValues->{$compressOutput}){
	$logger->logdie("Invalid compress_output '$compressOutput'");
    }
}
else {
    ## Default behavior - do not compress output
    $compressOutput = 0;
}


my $inputFileLookup = &getInputFileLookup($indir,$inputFileExtension, $table);

## Verify and set the output directory
$outdir = &verifyAndSetOutdir($outdir);

my $outputFileLookup = &getOutputFileLookup($inputFileLookup, 
					    $inputFileExtension,
					    $outdir,
					    $outputFileExtension);

&createConvertedFiles($outputFileLookup,
		      $inputFormat,
		      $outputFormat,
		      $convensionsLookup,
		      $compressOutput);


print "'$0': Program execution complete\nPlease review logfile: $log4perl\n";
exit(0);


#---------------------------------------------------------------------------------------
#
#            END MAIN -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------


#----------------------------------------------------------------
# getInputFileLookup()
#
#----------------------------------------------------------------
sub getInputFileLookup {

    my ($indir, $inputFileExtension, $table) = @_;

    my $inputFileLookup = {};

    opendir(THISDIR, "$indir") || $logger->logdie("Could not open directory '$indir'");
    
    my @allfiles = grep {$_ ne '.' and $_ ne '..'  and $_ =~ /\S+\.$inputFileExtension/} readdir THISDIR;

    my $validFileCtr=0;

    foreach my $file (sort @allfiles){
	    
	if (defined($table)){
	    ## If the table value was defined, then the user only
	    ## intends to convert the BCP file corresponding with 
	    ## this table.

	    ## Derive the table name from the file
	    my $tableName = File::Basename::basename($file);

	    ## Remove the file extension from the table name
	    $tableName =~ s/\.$inputFileExtension$//;	
	    
	    if ($table eq $tableName){
		## The derived table name does match the table
		## specified by the user so we should process
		## this file.
		if ($file =~ /\S+\.$inputFileExtension$/){
		    
		    $file = $indir . '/' . $file;
		    
		    $inputFileLookup->{$file} = $file;
		    
		    $validFileCtr++;
		}
		else {
		    ## This file did not have the correct file extension
		    ## and so shall be ignored.
		    $logger->warn("file '$file' did not have file extension '$inputFileExtension' ".
				  "and so will not be converted");
		}
	    }
	    else {
		$logger->warn("User specified table '$table', so this file '$file' will not be ".
			      "converted");
	    }
	}
	else {
	    if ($file =~ /\S+\.$inputFileExtension$/){
		
		$file = $indir . '/' . $file;
		
		$inputFileLookup->{$file} = $file;
		
		$validFileCtr++;
	    }
	    else {
		## This file did not have the correct file extension
		## and so shall be ignored.
		$logger->warn("file '$file' did not have file extension '$inputFileExtension' ".
			      "and so will not be converted");
		
	    }
	}
    }

    if ($validFileCtr < 1){
	if (!defined($table)){
	    $logger->logdie("Did not find any files with extension '$inputFileExtension' in directory '$indir'");
	}
	else{
	    $logger->logdie("Did not find a BCP file for table '$table' with file extension '$inputFileExtension' in directory '$indir'");
	}
    }

    return $inputFileLookup;
    
}

#----------------------------------------------------------------
# createConvertedFiles()
#
#----------------------------------------------------------------
sub createConvertedFiles {

    my ($outputFileLookup, $inputFormat, $outputFormat, $convensionsLookup,
	$compressOutput) = @_;

    my $inputFieldDelimiter = $convensionsLookup->{$inputFormat}->{'field'};

    my $inputRowDelimiter = $convensionsLookup->{$inputFormat}->{'row'};

    my $outputFieldDelimiter = $convensionsLookup->{$outputFormat}->{'field'};

    my $outputRowDelimiter = $convensionsLookup->{$outputFormat}->{'row'};

    my $inputNullValue = $convensionsLookup->{$inputFormat}->{'null'};

    my $outputNullValue = $convensionsLookup->{$outputFormat}->{'null'};

    foreach my $tableName ( keys %{$outputFileLookup} ){ 

	my $infile = $outputFileLookup->{$tableName}->{'infile'};

	my $outfile = $outputFileLookup->{$tableName}->{'outfile'};

	my $booleanLookup = $tableColumnBooleanLookup->{$tableName};

	## Set the input format's newline/record separator
	$/ = $inputRowDelimiter;
	
	my $inputFileHandle;

	if ($infile =~ /\.(gz|gzip)$/){
	    ## input file is gzip compressed
	    open ($inputFileHandle, "<:gzip", $infile) || $logger->logdie("Could not open gzip file '$infile': $!");
	}
	else {
	    ## input file is not gzip compressed
	    open ($inputFileHandle, "<$infile") || $logger->logdie("Could not open infile '$infile':$!");
	}


	my $outputFileHandle;
	
	if ($compressOutput == 1){
	    open ($outputFileHandle, ">:gzip", "$outfile") || $logger->logdie("Could not open outfile '$outfile':$!");
	}
	else {
	    open ($outputFileHandle, ">$outfile") || $logger->logdie("Could not open outfile '$outfile':$!");
	}

	## Keep track of the number of records in this BCP file.
	my $lineCtr = 0;

	while (my $line = <$inputFileHandle>){
	    
	    $lineCtr++;

	    chomp $line;

	    ## LIMIT = -1 to ensure that trialing null fields are propagated
	    my @fields = split(/$inputFieldDelimiter/, $line, -1);

	    my $outline;

	    if (($inputFormat eq 'postgresql') || ($inputFormat eq 'mysql')){

		for (my $i=0; $i < scalar(@fields) ; $i++){
		    
		    my $fieldValue = $fields[$i];

		    if ( exists $booleanLookup->{$i}){
			## Convert BOOLEAN to BIT values

			if (($fieldValue eq 'true') || ($fieldValue eq 't')){
			    $fieldValue = 1;
			}
			elsif (($fieldValue eq 'false') || ($fieldValue eq 'f')){
			    $fieldValue = 0;
			}
			else {
			    $logger->logdie("column '$i' for table '$tableName' should be ".
					    "boolean data type value.  Found '$fieldValue' ".
					    "instead!");
			}
		    }
		    else {
			##Get rid of \N
			$fieldValue =~ s/^\\N//g;
			
			## Convert all escaped tabs into real tabs
			$fieldValue =~ s/\\t/\t/g;
			
			## Convert all escaped all newlines into real newlines
			$fieldValue =~ s/\\n/\n/g;
			
			## Convert all escaped backslashes into real backslashes
			$fieldValue =~ s/\\\\/\\/g;
		    }

		    $fields[$i] = $fieldValue;
		    
		}
	    }

	    if ($outputFormat eq 'postgresql'){

		## Don't need to convert BIT (1|0) to BOOLEAN (true|false)
		## because PostgreSQL COPY command converts automatically

		for (my $i=0; $i < scalar(@fields); $i++){
		    
		    my $fieldValue = $fields[$i];
		    
		    ## Null fields become \N
		    if ((!defined($fieldValue)) || (length($fieldValue) < 1)){
			$fieldValue = $outputNullValue;
		    }
		    else {
			## Escape all tabs
			$fieldValue =~ s/\t/\\t/g;
			
			## Escape all newlines
			$fieldValue =~ s/\n/\\n/g;
			
			## Escape all newlines
			$fieldValue =~ s/\n/\\n/g;

			## Escape all backslashes
			$fieldValue =~ s/\\/\\\\/g;
		    }
		    
		    $fields[$i] = $fieldValue;
		}
	    }

	    ## combine the fields into one record
	    $outline = join($outputFieldDelimiter, @fields);

	    if ($outputFormat ne 'sybase'){
		## Just get rid of any null terminators.
		$outline =~ s/\0//g;
	    }

	    ## Set the output format's newline/record separator
	    $/ = $outputRowDelimiter;	    

	    ## output the record to file
	    print $outputFileHandle $outline . $outputRowDelimiter;

	    ## Set the input format's newline/record separator
	    $/ = $inputRowDelimiter;

	}

	$logger->warn("Converted '$lineCtr' records in file '$infile' input ".
		      "format '$inputFormat' into output format '$outputFormat' ".
		      "stored output in file '$outfile'");
    }
}

#----------------------------------------------------------------
# getOutputFileLookup()
#
#----------------------------------------------------------------
sub getOutputFileLookup {

    my ($inputFileLookup, $inputFileExtension, $outdir, $outputFileExtension) = @_;
    


    ## Add the period before the file extension
    $inputFileExtension = '.' . $inputFileExtension;

    my $outputFileLookup = {};

    foreach my $inFile ( keys %{$inputFileLookup} ){
	
	my $tableName = File::Basename::basename($inFile);


	## Remove the file extension from the table name
	$tableName =~ s/$inputFileExtension$//;

	## Create the output filename
	my $outFile = $outdir . $tableName . '.' . $outputFileExtension;
	
	$outputFileLookup->{$tableName}->{'outfile'} = $outFile;
	$outputFileLookup->{$tableName}->{'infile'} = $inFile;
	
    }
    
    return $outputFileLookup;    
}


#--------------------------------------------------------
# verifyAndSetOutdir()
#
#--------------------------------------------------------
sub verifyAndSetOutdir {

    my ( $outdir) = @_;

    ## strip trailing forward slashes
    $outdir =~ s/\/+$//;
    
    # set to current directory if not defined
    if (!defined($outdir)){
	if (!defined($ENV{'OUTPUT_DIR'})){
	    $outdir = "." 
	}
	else{
	    $outdir = $ENV{'OUTPUT_DIR'};
	}
    }

    $outdir .= '/';

    ## verify whether outdir is in fact a directory
    if (!-d $outdir){
	$logger->logdie("$outdir is not a directory");
    }

    ## verify whether outdir has write permissions
    if ((-e $outdir) and (!-w $outdir)){
	$logger->logdie("$outdir does not have write permissions");
    }

    ## store the outdir in the environment variable
    $ENV{OUTPUT_DIR} = $outdir;
    
    return $outdir;

}#end sub verifyAndSetOutdir()


#--------------------------------------------------------------------
# printUsage()
#
#--------------------------------------------------------------------
sub printUsage {

    print STDERR "SAMPLE USAGE:  $0 [--compress_output] [-d debug_level] [-h] --indir [--input_ext] --input_format [-l logfile] [-m] --outdir [--output_ext] --output_format [--table]\n".
    "  --compress_output  = Optional - Write output BCP files in gzip format (default is no compression)\n".
    "  -d|--debug_level   = Optional - Coati::Logger log4perl logging level (default is 0)\n".
    "  -h|--help          = This help message\n".
    "  --indir            = Directory that contains BCP files of type input_format to be converted to output_format\n".
    "  --input_ext        = Optional - File extension of the input_format BCP files e.g. out\n".
    "  --input_format     = Vendor type of input BCP files e.g. sybase or postgresql\n".
    "  -l|--logfile       = Optional - log4perl log file (default is /tmp/bcpConverter.pl.log)\n".
    "  -m|--man           = Display the pod2usage man page for this utility\n".
    "  --outdir           = Directory where converted BCP file will be output to\n".
    "  --output_ext       = Optional - File extension of the output_format BCP files e.g. bcp\n".
    "  --output_format    = Vendor type of output BCP files e.g. sybase or postgresql\n".
    "  --table            = Optional - user can specify only one bcp file (by table name) to be converted\n";

    exit(1);
}

