#!/usr/local/bin/perl
=head1 NAME

deriveCDSSequences.pl - Derives the values for asm_feature.sequence and asm_feature.protein values for CDS features

=head1 SYNOPSIS

USAGE:  deriveCDSSequences.pl --asmbl_id=<asmbl_id> --database=<database> [--debug_level=<debug level>] [-h] [--logfile=<log file>] [-m] --password=<password> --username=<username> [--output_directory=<output directory>] [--output_sequence_file=<output sequence file>] [--server=<server>]

=head1 OPTIONS

=over 8

=item B<--asmbl_id>

The asmbl_id for the assembly from which all CDS sequences will be derived

=item B<--database>

The database which contains the assembly whose CDS's sequences should be derived

=item B<--debug_level>

Optional - The Log::Cabin debug level (default is 0)

=item B<--help,-h>

Print this help

=item B<--man,-m>

Display pod2usage man pages for this script

=item B<--logfile>

Optional - Log::Cabin log file (default is /tmp/deriveCDSSequences.pl.<database>_<asmbl_id>.log

=item B<--server>

Optional - Name of the server on which the database resides (default is SYBTIGR)

=item B<--password>

Database password

=item B<--username>

Database username

=item B<--output_directory>

Optional - the output directory (default is current working directory)

=item B<--output_sequence_file>

Optional - the output file that will contain the new derived sequences (default is /tmp/deriveSequences.pl.<database>_<asmbl_id>.dat

=back

=head1 DESCRIPTION

deriveCDSSequences.pl - 

=head1 CONTACT

Jay Sundaram 

sundaram@jcvi.org

=cut

use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Coati::Logger;
use File::Copy;
use File::Basename;
use Prism;
use Nuc_translator;

$| = 1;


#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------
my ($asmbl_id, $database, $debug_level, $help, $logfile, $man, $server, $password, $username,
    $output_directory, $output_sequence_file, $output_protein_file, $schema_type);

my $results = GetOptions (
			  'asmbl_id=s'       => \$asmbl_id,
			  'database=s'       => \$database,
			  'debug_level=s'    => \$debug_level,
			  'help|h'           => \$help,
			  'logfile=s'        => \$logfile,
			  'man|m'            => \$man,
			  'server=s'         => \$server,
			  'password=s'       => \$password,
			  'username=s'       => \$username, 
			  'output_directory=s' => \$output_directory,
			  'output_sequence_file=s' => \$output_sequence_file,
			  'output_protein_file=s' => \$output_protein_file
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);


my $fatalCtr=0;
if (!defined($asmbl_id)){
    print STDERR "asmbl_id was not defined\n";
    $fatalCtr++;
}
if (!defined($database)){
    print STDERR "database was not defined\n";
    $fatalCtr++;
}
if (!defined($password)){
    print STDERR "password was not defined\n";
    $fatalCtr++;
}
if (!defined($username)){
    print STDERR "username was not defined\n";
    $fatalCtr++;
}

if ($fatalCtr>0){
    &printUsage();
}

if (!defined($logfile)){
	
    $logfile = '/tmp/deriveCDSSequences.pl.' . $database . '_' . $asmbl_id . '.log';
    
    print STDERR "logfile was not defined, therefore was set to '$logfile'\n";
}

## Get the logger
my $logger = &getLogger($logfile, $debug_level, $database, $asmbl_id);

## Verify and set the output directory
$output_directory = &verifyAndSetOutputDirectory($output_directory);

if (!defined($server)){
    $server = 'SYBTIGR';
    $logger->info("server was not defined and therefore was set to '$server'");
}

my $database_type = 'sybase';

&setPrismEnv($server, $database_type);
 
## Instantiate new Prism reader object
my $prism = new Prism( user => $username, password => $password, db => $database );

if (!defined($prism)){
    $logger->logdie("prism was not defined") 
}

if ($prism->asmblIdExist($asmbl_id)){

    if ($prism->assemblyHaveCDSFeatures($asmbl_id)){

	my $sequence = $prism->assemblySequence($asmbl_id);

#	$logger->fatal("sequence '$sequence'");

	if (defined($sequence)){

	    my $cdsLookup = $prism->cdsCoordinates($asmbl_id);

# 	    $logger->fatal("cdsLookup " . Dumper $cdsLookup);
#	    die ;

	    if (!defined($cdsLookup)){
		$logger->logdie("Could not retrieve the coordinates ".
				"for the CDS features with asmbl_id ".
				"'$asmbl_id' for database '$database'");
	    }
	    else {
		my $dataLookup = &deriveSequences($cdsLookup, $sequence, $asmbl_id, $database);

		&writeSequencesToFiles($output_sequence_file, $output_protein_file, $output_directory, $dataLookup);

		## Deallocate ASAP.
		$dataLookup = {};

		my $currentCDSValues = $prism->currentCDSValues($asmbl_id, $database);

		&writeSequencesToFiles("/tmp/${database}_${asmbl_id}.current.sequence.dat", "/tmp/${database}_${asmbl_id}.current.protein.dat", $output_directory, $currentCDSValues);
	    }
	}
	else {
	    $logger->logdie("Could not retrieve assembly.sequence for database '$database'");
	}
    }
    else {
	$logger->warn("assembly with asmbl_id '$asmbl_id' for database ".
		      "'$database' did not have any CDS features");
    }
}
else {
    $logger->logdie("assembly.asmbl_id does not exist in database '$database'");
}



print "$0 program execution completed\n";
print "The log file is '$logfile'\n";
exit(0);

##--------------------------------------------------------------------------------------
##
##                 END OF MAIN -- SUBROUTINES FOLLOW
##
##--------------------------------------------------------------------------------------

=over 4

=item translate_sequence()

B<Description:> translates a nucleotide sequence given a specific frame 1, 2, or 3.

B<Parameters:> $nuc_sequence, $frame

B<Returns:> $protein_sequence

=back

=cut


sub printUsage {

    print STDERR "SAMPLE USAGE:  $0 --asmbl_id=<asmbl_id> --database=<database> [--debug_level=<debug level>] [-h] [--logfile=<log file>] [-m] --password=<password> --username=<username> [--output_directory=<output directory>] [--output_sequence_file=<output sequence file>] [--server=<server>]\n".
    " --asmbl_id              = The assembly.asmbl_id\n".
    " --database              = The legacy annotation database\n".
    " --debug_level           = Optional - Coati::Logger's Log::Cabin logging level (Default is WARN)\n".
    " -h|--help               = This help message\n".
    " --logfile               = Optional - Log::Cabin output filename (Default is /tmp/deriveCDSSequences.<database>_<asmbl_id>.log)\n".
    " -m|--man                = Display the pod2usage pages for this script\n".
    " --password              = login password for database\n".
    " --username              = login username for database\n".
    " --output_directory      = Optional - The output directory (default is current working directory)\n".
    " --output_sequence_file  = Optional - The output tab-delimited sequence file (default is /tmp/deriveCDSSequence.<database>_<asmbl_id>.dat)\n".
    " --server                = Optional - Name of the server on which the database resides (default is SYBTIGR)\n";

    exit(1);
}


=over 4

=item translate_sequence()

B<Description:> translates a nucleotide sequence given a specific frame 1, 2, or 3.

B<Parameters:> $nuc_sequence, $frame

B<Returns:> $protein_sequence

=back

=cut

sub getLogger {

    my ($logfile, $debug_level, $database, $asmbl_id) = @_;

    ## initialize the logger
    my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				     'LOG_LEVEL'=>$debug_level);

    return Coati::Logger::get_logger(__PACKAGE__);
}

=over 4

=item translate_sequence()

B<Description:> translates a nucleotide sequence given a specific frame 1, 2, or 3.

B<Parameters:> $nuc_sequence, $frame

B<Returns:> $protein_sequence

=back

=cut

sub verifyAndSetOutputDirectory {

    my ( $outdir ) = @_;

    if (!defined($outdir)){
	
	if ($logger->is_debug()){
	    $logger->debug("outdir was not defined");
	}

	if (defined($ENV{'OUTPUT_DIR'})){
	    ## set the outdir to the env var OUTPUT_DIR
	    $outdir = $ENV{'OUTPUT_DIR'};
	    if ($logger->is_debug()){
		$logger->debug("outdir was set to the environmental variable OUTPUT_DIR '$ENV{'OUTPUT_DIR'}'");
	    }
	}
	else{
	    ## set the outdir to the current working directory
	    $outdir = ".";
	    if ($logger->is_debug()){
		$logger->debug("outdir was set to the current working directory");
	    }
	}
    }

    ## strip trailing forward slashes
    $outdir =~ s/\/+$//;

    $outdir = $outdir . '/';

    if (!-e $outdir){
	$logger->logdie("directory '$outdir' does not exist");
    }
    if (!-d $outdir){
	$logger->logdie("'$outdir' is not a directory");
    }
    if (!-w $outdir){
	$logger->logdie("directory '$outdir' does not have write permissions");
    }

    ## store the outdir in the environment variable
    $ENV{OUTPUT_DIR} = $outdir;
    
    return $outdir;

}

=over 4

=item deriveSequences()

B<Description:> 

B<Parameters:> $cdsLookup, $sequence, $asmbl_id, $database

B<Returns:> $dataLookup

=back

=cut

sub deriveSequences {
    
    my ($cdsLookup, $sequence, $asmbl_id, $database) = @_;

    my $dataLookup = {};

    ## Count the number of CDS features processed.
    my $cdsCtr=0;

    ## Count the number of times that the asm_feature.end5 is not defined.
    my $endFiveErrorCtr=0;

    ## Count the number of times that the asm_feature.end3 is not defined.
    my $endThreeErrorCtr=0;

    ## Count the number of times that we could not derive the
    ## nucleotide sequence.
    my $missingNucleotideSequenceCtr=0;

    ## Count the number of times that Nuc_translator::get_protein()
    ## cannot derive a protein sequence from the supplied nucleotide sequence.
    my $missingProteinSequenceCtr=0;

#    my $reverseComplementAssemblySequence = reverse_complement($sequence);
    my $reverseComplementAssemblySequence = $sequence;

    if (!defined($reverseComplementAssemblySequence)){
	$logger->logdie("reverse complement of the assembly sequence could not be derived");
    }


    foreach my $arrayRef ( @{$cdsLookup} ){

	## arrayRef->[0] == asm_feature.feat_name
	## arrayRef->[1] == asm_feature.end5
	## arrayRef->[2] == asm_feature.end3

	$cdsCtr++;

	if ($logger->is_debug()){
	    $logger->debug("Processing CDS '$cdsCtr' with feat_name '$arrayRef->[0]'");
	}

	my $skip=0;

	if (!defined($arrayRef->[1])){
	    $logger->error("asm_feature.end5 was not defined for CDS with ".
			   "feat_name '$arrayRef->[0]' for asmbl_id ".
			   "'$asmbl_id' in database '$database'");
	    $endFiveErrorCtr++;
	    $skip=1;
	}
	
	if (!defined($arrayRef->[2])){
	    $logger->error("asm_feature.end3 was not defined for CDS with ".
			   "feat_name '$arrayRef->[0]' for asmbl_id ".
			   "'$asmbl_id' in database '$database'");
	    
	    $endThreeErrorCtr++;
	    $skip=1;
	}

	if ($skip==1){
	    next;
	}

	my $nucleotideSequence;

	if ($arrayRef->[2] > $arrayRef->[1]){

	    $nucleotideSequence = substr($sequence, $arrayRef->[1], $arrayRef->[1] + $arrayRef->[2]);

	}
	else {
	    $nucleotideSequence = substr($reverseComplementAssemblySequence, $arrayRef->[2], $arrayRef->[1] - $arrayRef->[2]);
	}

	my $proteinSequence;

	if (defined($nucleotideSequence)){

	    $proteinSequence = get_protein($nucleotideSequence);
	    
	    if (!defined($proteinSequence)){

		$logger->warn("Could not derive protein sequence for CDS with feat_name ".
			      "'$arrayRef->[0]' asmbl_id '$asmbl_id' in database ".
			      "'$database'");
		
		$missingProteinSequenceCtr++;
	    }
	}
	else {
	    $logger->fatal("Could not derive nucleotide sequence for CDS with feat_name ".
			   "'$arrayRef->[0]' asmbl_id '$asmbl_id' in database '$database'");
	    
	    $missingNucleotideSequenceCtr++;

	    next;
	}

	push(@{$dataLookup->{$arrayRef->[0]}}, ($nucleotideSequence, $proteinSequence));

    }

    my $errorCtr = $endFiveErrorCtr + $endThreeErrorCtr;

    if ($errorCtr>0){
	$logger->logdie("Undefined encountered '$endFiveErrorCtr' undefined ".
			"asm_feature.end5 values and '$endThreeErrorCtr' ".
			"undefined asm_feature.end3 values in database ".
			"'$database' for asmbl_id '$asmbl_id'");
    }

    $logger->info("Processed '$cdsCtr' CDS features for asmbl_id '$asmbl_id' from database '$database'");
    
    return $dataLookup;
}

=over 4a

=item writeSequencesToFiles()

B<Description:> 

B<Parameters:> $output_sequence_file, $output_protein_file, $output_directory, $dataLookup

B<Returns:> None

=back

=cut

sub writeSequencesToFiles {

    my ($output_sequence_file, $output_protein_file, $output_directory, $dataLookup) = @_;


    if (!defined($output_sequence_file)){
	$output_sequence_file = $output_directory . 'deriveCDSSequence.' . $database . '.' . $asmbl_id . '.sequence.dat';
    }
    if (!defined($output_protein_file)){
	$output_protein_file = $output_directory . 'deriveCDSSequence.' . $database . '.' . $asmbl_id . '.protein.dat';
    }

    open (SEQUENCE, ">$output_sequence_file") || $logger->logdie("Could not open output sequence file '$output_sequence_file' in write mode:$!");

    open (PROTEIN, ">$output_protein_file") || $logger->logdie("Could not open output protein file '$output_protein_file' in write mode:$!");

    my $sequenceCtr=0;

    my $proteinCtr=0;

    my $cdsCtr=0;
    
    foreach my $cds ( sort keys %{$dataLookup}){
	
	$cdsCtr++;
	
	my $arrayRef = $dataLookup->{$cds};

#	print "cds '$cds' sequence '$arrayRef->[0]' protein '$arrayRef->[1]'";die;
	if (defined($arrayRef->[0])){
	    
	    print SEQUENCE $cds . "\t" . $arrayRef->[0] . "\n";
	    
	    $sequenceCtr++;
	}
	
	if (defined($arrayRef->[1])){
	    
	    print PROTEIN $cds . "\t" . $arrayRef->[1] . "\n";
	    
	    $proteinCtr++;
	}
    }

    close SEQUENCE;

    close PROTEIN;
    
    $logger->info("Out of '$cdsCtr' CDS features, wrote '$sequenceCtr' nucleotide sequences ".
		  "to '$output_sequence_file' and wrote '$proteinCtr' protein sequences ".
		  "to '$output_protein_file'");


    print "The CDS sequence file is '$output_sequence_file\n";

    print "The CDS protein file is '$output_protein_file'\n";
    
}




=over 4

=item setPrismEnv()

B<Description:> 

B<Parameters:> $server, $vendor

B<Returns:> None

=back

=cut

sub setPrismEnv {

    my ($server, $vendor) = @_;

    if (!defined($server)){
	$logger->logdie("server was not defined");
    }
    if (!defined($vendor)){
	$logger->logdie("vendor was not defined");
    }
    
    if ($vendor eq 'postgresql'){
	$vendor = 'postgres';
    }

    $vendor = ucfirst($vendor);
    ## We're overriding the env stored in conf/Prism.conf
    my $prismenv = "Euk:$vendor:$server";

    if ($logger->is_debug()){
	$logger->debug("PRISM was set to '$prismenv'");
    }

    $ENV{PRISM} = $prismenv;
}
