#!/usr/local/bin/perl
=head1 NAME
    
    bcpScanner.pl 
    
=head1 USAGE

    
=head1 OPTIONS

    REQUIRED

    OPTIONAL

=head1 DESCRIPTION



=head1 INPUT


=head1 OUTPUT




=head1  CONTACT

    Jay Sundaram
    sundaram@jcvi.org

=begin comment

  ## legal values for status are active, inactive, hidden, unstable
  status: active

  keywords: sybase bcp chado

=end comment

=cut


use strict;
use Getopt::Long;
use Pod::Usage;
use File::Basename;
use Data::Dumper;
use Annotation::Logger;
use Annotation::Util2;

# set up options
my ($infile, $indir, $infilelist, $logfile, $help, $man, $debug_level, $outfile);

&GetOptions(
	    'infile=s'      => \$infile,
	    'infilelist=s'  => \$infilelist,
	    'indir=s'       => \$indir,
	    'outfile=s'     => \$outfile,
	    'logfile=s'     => \$logfile,
	    'help|h'        => \$help,
	    'man|m'         => \$man,
	    'debug_level=s' => \$debug_level,
	    );

&checkCommandLineArguments();

my $logger = &getLogger($logfile, $debug_level);

my $fileCtr=0;

my $fileList = &getFileList($indir, $infile, $infilelist);

&scanFiles($fileList);

print "$0 execution completed\n";
print "The log file is '$logfile'\n";
print "The output file is '$outfile'\n";
exit(0);


##-------------------------------------------------------------
##
##        END OF MAIN -- SUBROUTINES FOLLOW
##
##-------------------------------------------------------------

sub checkCommandLineArguments {

    if ($help){
	&pod2usage( {-exitval => 1, -verbose => 2, -output => \*STDOUT} ); 
	exit(1);
    }
    
    my $fatalCtr=0;

    if ((!$infile) && (!$indir) && (!$infilelist)){
	print STDERR "You must specified either --infile, --indir or --infilelist\n";
	$fatalCtr++;
    }

    if ($fatalCtr>0){
	die "Required command-line arguments were not specified";
    }

    if (!defined($logfile)){
	$logfile = '/tmp/' . basename($0) . '.log';
	print STDERR "--logfile was not specified and therefore was set to '$logfile'\n";
    }

    if (!defined($outfile)){
	$outfile = '/tmp/' . basename($0) . '.rpt';
	print STDERR "--outfile was not specified and therefore was set to '$outfile'\n";
    }

}

sub getLogger {

    my ($logfile, $debug_level) = @_;

    my $mylogger = new Annotation::Logger('LOG_FILE'=>$logfile,
					  'LOG_LEVEL'=>$debug_level);
    
    my $logger = Annotation::Logger::get_logger(__PACKAGE__);

    if (!defined($logger)){
	die "Could not get the Logger";
    }

    return $logger;
}

sub getFileList {

    my ($indir, $infile, $infilelist) = @_;
    my $fileList=[];

    if (defined($infile)){
	&addFilesToListFromInfile($infile, $fileList);
    }
    if (defined($indir)){
	&addFilesToListFromIndir($indir, $fileList);
    }
    if (defined($infilelist)){
	&addFilesToListFromInfileList($infilelist, $fileList);
    }


    if ($fileCtr < 1){
	die "Thre were no files to process";
    }

    return $fileList;
}

sub addFilesToListFromInfile {

    my ($infile, $fileList) = @_;

    $infile =~ s/\s*//g; ## remove all white space

    my @list = split(/,/,$infile);

    my $ctr=0;
    foreach my $file (@list){
	push(@{$fileList}, $file);
	$ctr++;
    }
    
    print "Added '$ctr' BCP files to the list from '$infile'\n";

    $fileCtr += $ctr;
}

sub addFilesToListFromIndir {

    my ($indir, $fileList) = @_;

    if (!-e $indir){
	$logger->logdie("directory '$indir' does not exist");
    }

    if (!-d $indir){
	$logger->logdie("'$indir' is not a directory");
    }

    if (!-r $indir){
	$logger->logdie("directory '$indir' does not have read permissions");
    }

    
    opendir(INDIR, "$indir") or $logger->logdie("Could not open directory '$indir' in read mode");
                                                                                                                                                                                                                                          
    my @files = grep {$_ ne '.' and $_ ne '..' and $_ =~ /\S+\.out$/} readdir INDIR;

    my $ctr=0;
    foreach my $file (@files){
	$file = $indir . '/'. $file;
	push(@{$fileList}, $file);
	$ctr++;
    }

    print "Added '$ctr' BCP files to the list from directory '$indir'\n";

    $fileCtr += $ctr;
}

sub addFilesToListFromInfileList {

    my ($infilelist, $fileList) = @_;

    die "NOT YET IMPLEMENTED";
}


sub scanFiles {

    my ($fileList) = @_;

    ## Track number of files processed
    my $pFileCtr=0;

    my $errorCtr=0;

    open (OUTFILE, ">$outfile") || die "Could not open output file '$outfile' in write mode:$!";

    foreach my $file (@{$fileList}){

	$pFileCtr++;

	if (!Annotation::Util2::checkInputFileStatus($file)){
	    print STDERR "Encountered some problem with file '$file'\n";
	    $errorCtr++;
	    next;
	}

	my $table = File::Basename::basename($file);
	my @pieces = split(/\./,$table);
	$table = $pieces[0];

	print "Processing table '$table' file '$file'\n";

	open (INFILE, "<$file") || die "Could not open file '$file' in read mode: $!";

	my $lineCtr=0;
	my $min=1000000000000000;
	my $max=-1;

	## Set end of record delimiter
	$/ = "\0\n";

	while (my $line = <INFILE>){

	    chomp $line;
	    $lineCtr++;

	    my @fields = split(/\0\t/, $line);

	    if ($fields[0] < $min){
		$min = $fields[0];
	    }
	    if ($fields[0] > $max){
		$max = $fields[0];
	    }
	}

	## reset end of record delimiter
	$/ = "\n";

	print OUTFILE "$table:$min:$max:$lineCtr\n";
    }


    print "Processed '$pFileCtr' BCP files\n";
    if ($errorCtr>0){
	die "Detected problems with '$errorCtr' BCP files\n";
    }
}

