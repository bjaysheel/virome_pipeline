#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
=head1 NAME

checkDeletedTableRecordCounts.pl - Creates select count SQL statement files for chado tables

=head1 SYNOPSIS

USAGE:  checkDeletedTableRecordCounts.p [--analysis_id] [--algorithm] --directory [-d debug_level][--feature_id] [-h] [--is_obsolete] [--logfile] [-m] [--organism_id]

=head1 OPTIONS

=over 8

=item B<--analysis_id>
    
Optional -  This script should be invoked with the same parameters as was createViewsSQL.pl

=item B<--algorithm>
    
Optional -  This script should be invoked with the same parameters as was createViewsSQL.pl

=item B<--directory>
    
Directory where all count files exist

=item B<--debug_level,-d>
    
Optional - Coati::Logger log4perl logging level (default is 0)

=item B<--feature_id>
    
Optional -  This script should be invoked with the same parameters as was createViewsSQL.pl

=item B<--help,-h>

Print this help

=item B<--is_obsolete>
    
Optional -  This script should be invoked with the same parameters as was createViewsSQL.pl

=item B<--logfile,-l>
    
Optional - Log4perl log file.  (default is /tmp/checkDeletedTableRecordCounts.pl.log)

=item B<--man,-m>

Display pod2usage man page for this utility

=item B<--organism_id>
    
Optional -  This script should be invoked with the same parameters as was createViewsSQL.pl

=back

=head1 DESCRIPTION

    checkDeletedTableRecordCounts.pl - Creates select count SQL statement files for chado tables
    e.g.
    1) ./checkDeletedTableRecordCounts.pl --directory=/usr/local/scratch/sundaram

=head1 CONTACT
                                                                                                                                                             
    Jay Sundaram
    sundaram@tigr.org

=cut

use Prism;
use Pod::Usage;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Coati::Logger;


## Don't buffer
$|=1;

my ($analysis_id, $algorithm, $directory, $debug_level, $feature_id, $help, $is_obsolete, $logfile, $man, $organism_id);

my $results = GetOptions (
			  'analysis_id=s'   => \$analysis_id,
			  'algorithm=s'     => \$algorithm,
			  'directory=s'     => \$directory,
			  'debug_level=s'   => \$debug_level,
			  'feature_id=s'    => \$feature_id,
			  'help|h'          => \$help,
			  'is_obsolete=s'   => \$is_obsolete,
			  'logfile=s'       => \$logfile,
			  'man|m'           => \$man,
			  'organism_id=s'   => \$organism_id
			  );

if ($man){
    &pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
}
if ($help){
    &pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
}

my $fatalCtr=0;

if (!$directory){
    print STDERR ("directory not specified\n");
    $fatalCtr++;
}

if ($fatalCtr > 0 ){
    &printUsage();
}

## Initialize the logger
if (!defined($logfile)){
    $logfile = '/tmp/checkDeletedTableRecordCounts.pl.log';
    print STDERR "logfile was set to '$logfile'\n";
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

my $allcounts = $directory .'/allcounts';
my $allcounts2 = $directory .'/allcounts2';
my $notcounts = $directory .'/notcounts';
my $withcounts = $directory .'/withcounts';

&checkDirectory($directory);
&checkDirectory($allcounts);
&checkDirectory($allcounts2);
&checkDirectory($notcounts);
&checkDirectory($withcounts);

my $startCountsLookup  = &getLookup($allcounts);
my $finalCountsLookup = &getLookup($allcounts2);
my $notCountsLookup  = &getLookup($notcounts);
my $withCountsLookup = &getLookup($withcounts);

my $phylogenyModuleTableLookup = Prism::getPhylogenyModuleTableLookup();
my $cvTableLookup = Prism::getCVModuleTableLookup();
my $pubTableLookup = Prism::getPubModuleTableLookup();
my $generalTableLookup = Prism::getGeneralModuleTableLookup();
my $organismTableLookup = Prism::getOrganismModuleTableLookup();
my $sequenceTableLookup = Prism::getSequenceModuleTableLookup();

my $errorCtr=0;

foreach my $table ( sort keys %{$startCountsLookup}){
    my $startcount = $startCountsLookup->{$table};
    my $withcount;
    my $finalcount;
    my $notcount;

    if ( exists $finalCountsLookup->{$table}){
	$finalcount = $finalCountsLookup->{$table};
    }
    else {
	$logger->logdie("table '$table' does not exist in finalCountsLookup - directory '$allcounts2'");
    }
    if ( exists $withCountsLookup->{$table}){
	$withcount = $withCountsLookup->{$table};
    }
    else {
	if ($logger->is_debug()){
	    $logger->debug("table '$table' does not exist in withCountsLookup - directory '$withcounts'");
	}
    }
    if ( exists $notCountsLookup->{$table}){
	$notcount = $notCountsLookup->{$table};
    }
    else {
	if ($logger->is_debug()){
	    $logger->debug("table '$table' does not exist in notCountsLookup - directory '$notcounts'");
	}
    }



    if ($finalcount > $startcount){
	$logger->error("The final count is greater than the initial count! This is very troubling ".
		       "considering records should have been deleted.  table '$table' startcount ".
		       "'$startcount' finalcount '$finalcount' withcount '$withcount' notcount '$notcount'");
	$errorCtr++;
    }
    elsif ($startcount == $finalcount){
	if (defined($withcount)){
	    if ($withcount != 0){
		$logger->error("The initial and final counts are the same and yet the with count is not zero! ".
			       "Meaning, some records should have been deleted but apparently were not. ".
			       "table '$table' startcount '$startcount' finalcount '$finalcount' withcount ".
			       "'$withcount' notcount '$notcount'");
		$errorCtr++;
	    }
	}
	elsif (defined($notcount)){
	    if ($startcount != $notcount){
		$logger->error("The not-with count does not match the initial and final counts.  Looks like ".
			       "records were not deleted.  table '$table' startcount '$startcount' finalcount ".
			       "'$finalcount' withcount '$withcount' notcount '$notcount'");
		$errorCtr++;
	    }
	}
	else {
	    if ( exists $phylogenyModuleTableLookup->{$table}){
		if ($logger->is_debug()){
		    $logger->debug("We're not using the phylogeny module at this time.");
		}
	    }
	    elsif (exists $cvTableLookup->{$table}){
		if ($logger->is_debug()){
		    $logger->debug("This script currently does not support evaluation of CV module record deletions");
		}
	    }
	    elsif (exists $pubTableLookup->{$table}){
		if ($logger->is_debug()){
		    $logger->debug("We're not using the pub module at this time");
		}
	    }
	    elsif (exists $generalTableLookup->{$table}){
		if ($logger->is_debug()){
		    $logger->debug("This script currently does not support evaluation of General module record deletions");
		}
	    }
	    elsif ($table eq 'synonym'){
		if ($logger->is_debug()){
		    $logger->debug("This script currently does not support evaluation of deletion of records from table 'synonym'");
		}
	    }
	    elsif ((defined($analysis_id)) || (defined($algorithm))){
		if (exists $organismTableLookup->{$table}){
		    if ($logger->is_debug()){
			$logger->debug("When analysis related records are deleted from the chado database, the tables of the organism ".
				       "module are not affected.");
		    }
		}
		elsif (exists $sequenceTableLookup->{$table}){
		    $logger->logdie("Some records related to some analysis were deleted, however the counts for this sequence module ".
				    "is missing - table '$table' startcount '$startcount' finalcount '$finalcount' withcount ".
				    "'$withcount' notcount '$notcount'");
		    $errorCtr++;

		}
		else {
		    $logger->logdie("table '$table' startcount '$startcount' finalcount '$finalcount' withcount ".
				    "'$withcount' notcount '$notcount'");
		}
	    }
	    elsif ((defined($organism_id)) || (defined($feature_id)) || (defined($is_obsolete))){
		if ($table eq 'analysisfeature'){
		    $logger->error("Initial and final counts match, but neither the with nor the not counts exist. ".
				   "table '$table' startcount '$startcount' finalcount '$finalcount' withcount ".
				   "'$withcount' notcount '$notcount'");
		    $errorCtr++;
		}
		else {
		    if ($logger->is_debug()){
			$logger->debug("When deleting records related to primary records either by organism_id, feature_id or is_obsolete ".
				       "tables 'analysis' and 'analysisprop' are not affected.");
		    }
		}
	    }
	    else {		
		$logger->error("Initial and final counts match, but neither the with nor the not counts exist. ".
			       "table '$table' startcount '$startcount' finalcount '$finalcount' withcount ".
			       "'$withcount' notcount '$notcount'");
		$errorCtr++;
	    }
	}    	
    }
    elsif ($startcount > $finalcount) {
	if (($startcount - $finalcount) != $withcount){
	    $logger->error("Looks like the wrong number of records were deleted. ".
			   "table '$table' startcount '$startcount' finalcount '$finalcount' withcount ".
			   "'$withcount' notcount '$notcount'");
	    
	    $errorCtr++;
	}
    }
    else {
	$logger->logdie("What?  Did you expect me to do something?");
    }
}

if ($errorCtr>0){
    $logger->logdie("Problems detected.  Please review the log file '$logfile'");
}
else {
    print "$0 program execution complete\n";
    print "Log file is '$logfile'\n";
    exit(0);
}


#---------------------------------------------------------------------------------------
#
#            END MAIN -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------

#--------------------------------------------------------------------
# printUsage()
#
#--------------------------------------------------------------------
sub printUsage {

    print STDERR "SAMPLE USAGE:  $0 [--analysis_id] [--algorithm] --directory [-d debug_level] [--feature_id] [-h] [--is_obsolete] [--logfile] [-m] [--organism_id]\n".
    "  --analysis_id    = Optional - This script should be invoke with the same parameters as was createViewsSQL.pl\n".
    "  --algorithm      = Optional - This script should be invoke with the same parameters as was createViewsSQL.pl\n".
    "  --directory      = Directory that contains all count files\n".
    "  -d|--debug_level = Optional - Coati::Logger log4perl logging level (default is 0)\n".
    "  --feature_id     = Optional - This script should be invoke with the same parameters as was createViewsSQL.pl\n".
    "  -h|--help        = Optional - This help message\n".
    "  --is_obsolete    = Optional - This script should be invoke with the same parameters as was createViewsSQL.pl\n".
    "  --logfile        = Optional - log4perl log file (default is /tmp/checkDeletedTableRecordCounts.pl.log)\n".
    "  -m|--man         = Optional - Display the pod2usage man page for this utility\n".
    "  --organism_id    = Optional - This script should be invoke with the same parameters as was createViewsSQL.pl\n";
    exit(1);
}

#----------------------------------------------------------------------------
# checkDirectory()
#
#----------------------------------------------------------------------------
sub checkDirectory {

    my $directory = shift;

    #
    # Qualify the directory
    #
    if (!defined($directory)){
	$logger->logdie("directory was not defined\n");
    }
    else{
	if (!-e $directory){
	    $logger->logdie("directory '$directory' does not exist");
	}
	if (!-d $directory){
	    $logger->logdie("directory '$directory' is not a directory");
	}
	if (!-r $directory){
	    $logger->logdie("directory '$directory' does not have read permissions");
	}
    }
}

sub getLookup {
    my $dir = shift;
    my $lookup = {};
    
    my $chadoCoreTableList = Prism::chadoCoreTableCommitOrder();
    my @tablelist = split(/,/, $chadoCoreTableList);

    my $foundFileCtr=0;

    foreach my $table (@tablelist){
	my $file = $dir . '/' . $table . '.stdout';
	my $count;
	if (-e $file){
	    if (-r $file){
		if (-f $file){
		    if (-s $file){
			open (INFILE, "<$file") || $logger->logdie("Could not open file '$file' in read mode:$!");
			$count = <INFILE>;
			chomp $count;
			$lookup->{$table} = $count;
			$foundFileCtr++;
		    }
		    else {
			$logger->logdie("file '$file' has zero content");
		    }
		}
		else {
		    $logger->logdie("file '$file' is not a regular file");
		}
	    }
	    else {
		$logger->logdie("file '$file' does not have read permissions");
	    }
	}
	else {
	    if ($dir =~ /not/){
		if ($logger->is_debug()){
		    $logger->debug("notcount file '$file' for table '$table' does not exist");
		}
	    }
	    elsif ($dir =~ /with/){
		if ($logger->is_debug()){
		    $logger->debug("withcount file '$file' for table '$table' does not exist");
		}
	    }
	    else {
		$logger->warn("file '$file' does ot exist");
	    }
	}
    }

    print "Found '$foundFileCtr' count files in directory '$dir'\n";
    return $lookup;
}

