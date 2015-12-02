#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
=head1 NAME

createDeleteSQLFile.pl - Creates delete.sql files which contain SQL statements for deleting records from chado tables

=head1 SYNOPSIS

USAGE:  createDeleteSQLFile.pl [--analysis_id] [--algorithm] [--bcpfile] [--database] --database_type [-d debug_level] [--delete_by_range] [--feature_id] [--file_extension] [-h] [--is_obsolete] [--logfile] [-m] [--one_by_one] [--organism_id] [--outdir] [--password] [--server] [--table] [--username]

=head1 OPTIONS

=over 8

=item B<--analysis_id>
    
Optional - The analysis.analysis_id to which all the analysis is linked to

=item B<--algorithm>
    
Optional - The analysis.algorithm to which all the analysis is linked to

=item B<--bcpfile>
    
Optional - BCP file whose primary key values should be extracted

=item B<--database>
    
Optional - Name of database that contains data (only if not invoking with --bcpfile)

=item B<--database_type>
    
Relational database management system type e.g. sybase or postgresql

=item B<--debug_level,-d>
    
Optional - Coati::Logger log4perl logging level (default is 0)

=item B<--delete_by_range>
    
Optional - Writes one SQL statement per file/table for deleting records by inclusive range

=item B<--feature_id>
    
Optional - The feature.feature_id to which all the data is linked to

=item B<--file_extension>
    
Optional - The file extension for the bcpfile (default: this program will derive it from the bcpfile).  Only necessary if --bcpfile is specified.
           

=item B<--help,-h>

Print this help

=item B<--is_obsolete>
    
Optional - The all data where the feature.is_obsolete=1

=item B<--logfile,-l>
    
Optional - Log4perl log file.  (default is /tmp/createDeleteSQLFile.pl.log)

=item B<--man,-m>

Display pod2usage man page for this utility

=item B<--one_by_one>
    
Optional - Writes multiple SQL statements per file/table for deleting records.  This is the default method.  Alternative is --delete_by_range.

=item B<--organism_id>
    
Optional - The organism.organism_id to which all the data is linked to

=item B<--outdir>
    
Optional - Directory where delete SQL file shall be written (default is current working directory)

=item B<--password>
    
Optional - The password to access the database (only necessary if not invoking with --bcpfile)

=item B<--server>
    
Optional - The name of the server on which the database resides (only necessary if not invoking with --bcpfile)

=item B<--table>
    
Optional - Name of table corresponding with contents of the bcpfile (default: this program will derive the table name from the bcpfile)

=item B<--username>
    
Optional - The username to access the database (only necessary if not invoking with --bcpfile)

=back

=head1 DESCRIPTION

    createDeleteSQLFile.pl - Converts BCP files from one vendor supported type to another
    e.g.
    1) ./createDeleteSQLFile.pl --bcpfile=/usr/local/scratch/sundaram/feature.out --database_type=sybase --outdir=/usr/local/scratch/sundaram/
    2) ./createDeleteSQLFile.pl --bcpfile=/usr/local/scratch/sundaram/feature.out --database_type=sybase --logfile=my.log
    3) ./createDeleteSQLFile.pl --analysis_id=1 --database_type=sybase --logfile=my.log

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

my ($analysis_id, $algorithm, $bcpfile, $database_type, $debug_level, $delete_by_range, $feature_id, 
    $file_extension, $help, $is_obsolete, $logfile, $man, $one_by_one, $organism_id, $outdir, $table,
    $username, $password, $database, $server);

my $results = GetOptions (
			  'analysis_id=s'    => \$analysis_id,
			  'algorithm=s'      => \$algorithm,
			  'bcpfile=s'        => \$bcpfile,
			  'database=s'       => \$database,
			  'database_type=s'  => \$database_type,
			  'debug_level=s'    => \$debug_level,
			  'delete_by_range=s'=> \$delete_by_range,
			  'feature_id=s'     => \$feature_id,
			  'file_extension=s' => \$file_extension,
			  'help|h'           => \$help,
			  'is_obsolete=s'    => \$is_obsolete,
			  'logfile=s'        => \$logfile,
			  'man|m'            => \$man, 
			  'one_by_one=s'     => \$one_by_one,
			  'organism_id=s'    => \$organism_id,
			  'outdir=s'         => \$outdir,
			  'password=s'       => \$password,
			  'username=s'       => \$username,
			  'server=s'         => \$server,
			  'table=s'          => \$table
			  );

if ($man){
    &pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
}
if ($help){
    &pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
}

my $fatalCtr=0;

if (!$database_type){
    print STDERR ("database_type not specified\n");
    $fatalCtr++;
}

if ($fatalCtr > 0 ){
    &printUsage();
}


## Initialize the logger
if (!defined($logfile)){
    $logfile = '/tmp/createDeleteSQLFile.pl.log';
    print STDERR "logfile was set to '$logfile'\n";
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

my $criticalParamCtr=0;

if (defined($analysis_id)){
    $criticalParamCtr++;
}
if (defined($algorithm)){
    $criticalParamCtr++;
}
if (defined($bcpfile)){
    $criticalParamCtr++;
}
if (defined($feature_id)){
    $criticalParamCtr++;
}
if (defined($is_obsolete)){
    $criticalParamCtr++;
}
if (defined($organism_id)){
    $criticalParamCtr++;
}

if ($criticalParamCtr == 0 ){
    $logger->warn("Neither --analysis_id, --algorithm, --bcpfile, --feature_id, --is_obsolete, or --organism_id were defined");
}
if ($criticalParamCtr > 1){
    $logger->fatal("Only one of the following command-line arguments must be specified --analysis_id, --algorithm, --bcpfile, --feature_id, --is_obsolete, or --organism_id");
    &printUsage()
}


if (! Prism::verifyDatabaseType($database_type)){
    $logger->logdie("This database_type '$database_type is not supported by Prism");
}

## Adopted Sybase delimiters
my $sybaseLookup = { 'field' => "\0\t",
		     'row' => "\0\n" };

## Adopted PostgreSQL delimiters
my $postgresSQLLookup = {'field' => "\t",
			 'row' => "\n",
			 'null' => '\N' };

my $convensionsLookup = { 'sybase' => $sybaseLookup,
			  'postgresql' => $postgresSQLLookup };


## Verify and set the output directory
$outdir = &verifyAndSetOutdir($outdir);

if ((defined($bcpfile)) && ($bcpfile == 1)){

    my ($primaryKeyList, $min, $max) = &getPrimaryKeysFromFile($bcpfile, $convensionsLookup->{$database_type});
    &createDeleteFile($primaryKeyList, $outdir, $bcpfile, $file_extension, $table, $delete_by_range, $one_by_one, $min, $max);
}
else {

    my $fatalCtr=0;
    
    if (!$database){
	print STDERR ("database not specified\n");
	$fatalCtr++;
    }
    if (!$username){
	print STDERR ("username not specified\n");
	$fatalCtr++;
    }
    if (!$password){
	print STDERR ("password not specified\n");
	$fatalCtr++;
    }
    if (!$server){
	print STDERR ("server not specified\n");
	$fatalCtr++;
    }
    
    if ($fatalCtr > 0 ){
	&printUsage();
    }


    ## Set the PRISM env var
    &setPrismEnv($server, $database_type);

    my $prism = new Prism( user     => $username,
			   password => $password,
			   db       => $database
			  );


    if (!defined($prism)){
	$logger->logdie("prism was not defined");
    }


    if (defined($analysis_id)){
	if ($analysis_id !~ /^\d+$/){
	    $logger->logdie("analysis_id '$analysis_id' is not a numeric value");
	}
	
	if (! $prism->analysisIdExists($analysis_id)){
	    $logger->logdie("analysis_id '$analysis_id' does not exist in table 'analysis', database '$database' on server '$server'");
	}
	
	if (defined($delete_by_range)){
	    $prism->createDeleteByRangeSQLFilesForAnalysisId($analysis_id, $outdir);
	}
	else {
	    $prism->createDeleteOneByOneSQLFilesForAnalysisId($analysis_id, $outdir);
	}
    }
    elsif (defined($algorithm)){
	
	if (! $prism->algorithmExists($algorithm)){
	    $logger->logdie("No analysis record with algorithm '$algorithm' exists in table 'analysis', database '$database' on server '$server'");
	}
	
	if (defined($delete_by_range)){
	    $prism->createDeleteByRangeSQLFilesForAlgorithm($algorithm, $outdir);
	}
	else {
	    $prism->createDeleteOneByOneSQLFilesForAlgorithm($algorithm, $outdir);
	}
    }
    elsif (defined($feature_id)){
	if ($feature_id !~ /^\d+$/){
	    $logger->logdie("feature_id '$feature_id' is not a numeric value");
	}
	
	if (! $prism->featureIdExists($feature_id)){
	    $logger->logdie("feature_id '$feature_id' does not exist in table 'feature', database '$database' on server '$server'");
	}
	
	if (defined($delete_by_range)){
	    $prism->createDeleteByRangeSQLFilesForFeatureId($feature_id, $outdir);
	}
	else {
	    $prism->createDeleteOneByOneSQLFilesForFeatureId($feature_id, $outdir);
	}
    }
    elsif (defined($is_obsolete)){
	
	if (! $prism->obsoleteFeaturesExist()){
	    $logger->logdie("There aren't any features with is_obsolete = 1 in database '$database' on server '$server'");
	}
	
	if (defined($delete_by_range)){
	    $prism->createDeleteByRangeSQLFilesForIsObsolete($is_obsolete, $outdir);
	}
	else {
	    $prism->createDeleteOneByOneSQLFilesForIsObsolete($is_obsolete, $outdir);
	}
    }
    elsif (defined($organism_id)){
	if ($organism_id !~ /^\d+$/){
	    $logger->logdie("organism_id '$organism_id' is not a numeric value");
	}
	
	if (! $prism->organismIdExists($organism_id)){
	    $logger->logdie("organism_id '$organism_id' does not exist in table 'organism', database '$database' on server '$server'");
	}
	
	if (defined($delete_by_range)){
	    $prism->createDeleteByRangeSQLFilesForOrganismId($organism_id, $outdir);
	}
	else {
	    $prism->createDeleteOneByOneSQLFilesForOrganismId($organism_id, $outdir);
	}
    }
    else {
	$logger->logdie("Logic error.");
    }
}
print "$0 program execution complete\n";
print "Log file is '$logfile'\n";
exit(0);


#---------------------------------------------------------------------------------------
#
#            END MAIN -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------

#----------------------------------------------------------------
# getPrimaryKeysFromFile()
#
#----------------------------------------------------------------
sub getPrimaryKeysFromFile {

    my ($bcpfile, $lookup) = @_;

    ## Set the newline separator
    $/ = $lookup->{'row'};

    my $inputFileHandle;

    open ($inputFileHandle, "<$bcpfile") || $logger->logdie("Could not open infile '$bcpfile':$!");

    my $recordCtr=0;

    my $fieldDelimiter = $lookup->{'field'};

    my $primaryKeyList = [];
    my $min=100000000000000000000000;
    my $max=-1;

    while (my $line = <$inputFileHandle>){
	    
	$recordCtr++;

	chomp $line;
	
	## LIMIT = -1 to ensure that trailing null fields are propagated
	my @fields = split(/$fieldDelimiter/, $line, -1);
	
	my $primarykey = $fields[0];
	if ($primarykey !~ /^\d+$/){
	    $logger->logdie("Found a primary key that was not all numeric at record number '$recordCtr' in BCP file '$bcpfile'");
	}

	$primarykey =~ s/^[0]+//; ## remove all leading zeros

	if ($primarykey < $min){
	    $min = $primarykey;
	}
	if ($primarykey > $max){
	    $max = $primarykey;
	}

	push(@{$primaryKeyList}, $primarykey);
    }

    ## Set the regular newline separator
    $/ = "\n";

    print "Extracted '$recordCtr' primary keys from BCP file '$bcpfile'\n";

    return ($primaryKeyList, $min, $max);
}

#----------------------------------------------------------------
# createDeleteFile()
#
#----------------------------------------------------------------
sub createDeleteFile {

    my ($list, $outdir, $bcpfile, $file_extension, $table, $delete_by_range, $one_by_one, $min, $max) = @_;
    
    if (!defined($list)){
	$logger->logdie("list was not defined");
    }
    if (!defined($outdir)){
	$logger->logdie("outdir was not defined");
    }
    if (!defined($bcpfile)){
	$logger->logdie("bcpfile was not defined");
    }

    my $basename = basename($bcpfile);

    if (!defined($table)){
	 $table = $basename;
	 my @parts = split(/\./, $table);
	 $table = $parts[0];
	 if ($logger->is_debug()){
	     $logger->debug("Derived table '$table' from bcpfile '$bcpfile' basename '$basename'");
	 }
     }

    my $outfile = $outdir . "/delete_" . $table . ".sql";

    open (OUTFILE, ">$outfile") || $logger->logdie("Could not open '$outfile' for output:$!");

    my $stmtCtr=0;

    if (defined($delete_by_range)){
	my $stmt = "DELETE FROM $table WHERE ${table}_id BETWEEN $min AND $max;\n";
	print OUTFILE $stmt;
	$stmtCtr++;
    }
    else {
	foreach my $primarykey ( @{$list}){
	    my $stmt = "DELETE FROM $table WHERE ${table}_id = $primarykey;\n";
	    print OUTFILE $stmt;
	    $stmtCtr++;
	}
    }
    
    print "Wrote '$stmtCtr' delete statements to file '$outfile'\n";
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

    print STDERR "SAMPLE USAGE:  $0 [--analysis_id] [--algorithm] [--bcpfile] --database_type [-d debug_level] [--delete_by_range] [--feature_id] --file_extension [-h] [--is_obsolete] [--logfile] [-m] [--outdir] [--one_by_one] [--organism_id] [--table]\n".
    "  --analysis_id    = Optional - analysis.analysis_id to which all the analysis is linked to\n".
    "  --algorithm      = Optional - analysis.algorithm to which all the analysis is linked to\n".
    "  --bcpfile        = BCP file to be parsed\n".
    "  --database_type  = Relational database management system i.e. sybase or postgresql (necessary to determine the field/record separators)\n".
    "  -d|--debug_level = Optional - Coati::Logger log4perl logging level (default is 0)\n".
    "  --feature_id     = Optional - feature.feature_id to which all the data is linked to\n".
    "  --file_extension = Optional - file extension of the bcpfile (default: this program will derive the value from the bcpfile)\n".
    "  -h|--help        = Optional - This help message\n".
    "  --is_obsolete    = Optional - all data linked to features where feature.is_obsolete=1\n".
    "  --logfile        = Optional - log4perl log file (default is /tmp/createDeleteSQLFile.pl.log)\n".
    "  -m|--man         = Optional - Display the pod2usage man page for this utility\n".
    "  --organism_id    = Optional - organism.organism_id to which all the data is linked to\n".
    "  --outdir         = Optional - Directory where converted BCP file will be output to\n".
    "  --table          = Optional - Name of table corresponding with contents of the bcpfile (default: this program will derive the table name from the bcpfile)\n";
    exit(1);
}

#--------------------------------------------------
# setPrismEnv()
#
#--------------------------------------------------
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

    $vendor = "Bulk" . ucfirst($vendor);
    ## We're overriding the env stored in conf/Prism.conf
    my $prismenv = "Chado:$vendor:$server";


    $ENV{PRISM} = $prismenv;
}
