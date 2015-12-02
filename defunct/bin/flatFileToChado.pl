
#!/usr/local/bin/perl

=head1 NAME

flatFileToChado.pl - Loads delimited flat files into chado databases

=head1 SYNOPSIS

USAGE:  flatFileToChado.pl -D database [-O outfile]  -P password [-S server] -U username [--bcp_ext] -b bcpmode --database_type [-d debug_level] [-h] [--ignore_empty_bcp] [-i infile] [-l logfile] [-m] [-n nodie] [-o directory] [-s batchsize] [-t table] [-u noupdatestats] [-z testmode] [-Z tgz]

=head1 OPTIONS

=over 8

=item B<--database,-D>
    
    Target database name

=item B<--outfile,-O>

    Optional - name of file to which tabbed delimited records will be dumped to

=item B<--password,-P>
    
    Database password

=item B<--server,-S>
    
    Optional - server name e.g. "SYBTIGR" or "SYBIL".  (default is "SYBTIGR")

=item B<--username,-U>
    
    Database username

=item B<--abort,-a>
    
    Optional - abort (-a=1) if load count discrepancies are detected.  Default is not to abort (-a=0)

=item B<--bcpmode,-b>
    
    bcp mode either "in" or "out"

=item B<--bcp_ext>
    
    Optional - user can specify the tab-delimited file extension (default values are sybase.bcp for --database_type=sybase and pgsql.bcp for --database_type=postgresql)

=item B<--debug_level,-d>
    
    Optional - Coati::Logger logfile logging level (default is 0)

=item B<--database_type>
    
    Database vendor type e.g. sybase or postgresql

=item B<--help,-h>

    Print this help

=item B<--infile,-i>

    Optional - name of file to be loaded. If named feature.out, then target table is feature.  If name is arbitrary e.g. my.out, then --table option must be specified

=item B<--ignore_empty_bcp>

    Optional - If BCP file contains no content, do not process - skip.  (default - die if BCP file has no content)

=item B<--logfile,-l>
    
    Optional - Logfile log file.  (default is /tmp/flatFileToChado.pl.log)

=item B<--man,-m>

    Display pod2usage man page for this utility

=item B<--directory,-o>
    
    Optional - source/target directory where .out files can be found/produced in.  (default is currect working directory)

=item B<--batchsize,-s>

    Optional - batch size (default 500 rows)

=item B<--table,-t>

    Optional - chado table to be loaded

=item B<--noupdatestats,-u>

    Optional -  update statistics of tables which were just loaded.  Default is -u=1 (do not update the statistics).  To turn on this feature, that is to update the statistics: -u=0

=item B<--testmode,-z>

    Optional - test mode, records are not inserted into database

=item B<--tgz,-Z>

    Optional - if --tgz=1 will tar, gzip, and in the process remove the output BCP .out files (default --tgz=0)


=back

=head1 DESCRIPTION

    flatFileToChado.pl - Performs BCP in to load Chado database tables on Sybase server OR BCP out to dump Chado tables to tab delimited .out files
    e.g.
    1) ./flatFileToChado.pl -U sundaram -P sundaram6 -D chado_pneumo -S SYBIL -d /usr/local/annotation/ASP -l perl.log -t "analysis, analysisfeature, feature, featureloc" > load.stats
    2) ./flatFileToChado.pl -U sundaram -P sundaram6 -D chado_pneumo -S SYBIL -d ~/tmp -l perl.log -T sequence_module_table_list.dat > load.stats
    3) ./flatFileToChado.pl -U sundaram -P sundaram6 -D chado_pneumo -S SYBIL -l perl.log -T companalysis_module_table_list.dat  
    4) ./flatFileToChado.pl -U sundaram -P sundaram6 -D chado_pneumo -S SYBIL -l perl.log -t featureloc -r "\0\n" -f "\0\t" 
    5) ./flatFileToChado.pl -U sundaram -P sundaram6 -D chado_pneumo -S SYBIL -l perl.log -M companalysis
    6) ./flatFileToChado.pl -U sundaram -P sundaram6 -D chado_pneumo -S SYBIL -l perl.log -M sequence > load.stats
    7) ./flatFileToChado.pl -U sundaram -P sundaram6 -D chado_pneumo -S SYBIL -l perl.log -M stable 
    8) ./flatFileToChado.pl -D chado_test -P sundaram7 -S SYBIL -U sundaram -a 0 -b in -d 5 -o /usr/local/scratch/sundaram/newsnps -l my.log -s 3000

=cut


use Prism;
use Pod::Usage;
use Data::Dumper;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use File::Basename;
use File::Copy;
use Coati::Logger;

$|=1;

my ($username, $password, $database, $server,
    $logfile, $debug, $help, $table, $man, $bcpmode, $directory, $batchsize, 
    $abort, $debug_level, $infile, $outfile, $nodie, $testmode, $noupdatestats, 
    $tgz, $ignoreEmptyBcp, $database_type, $printCommandsOnly,
    $bcpExt);

my $results = GetOptions (
			  'database|D=s'        => \$database,
			  'outfile|O=s'         => \$outfile,
			  'password|P=s'        => \$password,
			  'server|S=s'          => \$server,
			  'username|U=s'        => \$username,
			  'bcpmode|b=s'         => \$bcpmode,
			  'debug_level|d=s'     => \$debug_level,
			  'help|h'              => \$help, 
			  'infile|i=s'          => \$infile,
			  'logfile|l=s'         => \$logfile,
			  'man|m'               => \$man,
			  'directory|o=s'       => \$directory, 
			  'batchsize|s=s'       => \$batchsize,
			  'table|t=s'           => \$table,
			  'noupdatestats|u=s'   => \$noupdatestats,
			  'testmode|z=s'        => \$testmode,
			  'tgz|Z=s'             => \$tgz,
			  'ignore_empty_bcp=s'  => \$ignoreEmptyBcp,
			  'database_type=s'     => \$database_type,
			  'print-commands-only' => \$printCommandsOnly,
			  'bcp_ext=s'           => \$bcpExt
			  );

if ($man){
    &pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
}
if ($help){
    &pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
}

my $fatalCtr=0;

if (!$username){
    print STDERR ("username not specified\n");
    $fatalCtr++;
}

if (!$password){
    print STDERR ("password not specified\n");
    $fatalCtr++;
}

if (!$database){
    print STDERR ("database not specified\n");
    $fatalCtr++;
}

if (!$bcpmode){
    print STDERR ("bcpmode not specified\n");
    $fatalCtr++;
}

if (!$database_type){
    print STDERR ("database_type not specified\n");
    $fatalCtr++;
}

if (!$server){
    print STDERR ("server not specified\n");
    $fatalCtr++;
}

if ($fatalCtr>0){
    &printUsage();
}

if (!defined($logfile)){
    $logfile = '/tmp/flatFileToChado.pl.log';
    print "logfile was set to '$logfile'\n";
}

## Initialize the logger
my $logger = &getLogger($logfile, $debug_level);

if (($bcpmode ne 'in') and ($bcpmode ne 'out')){
    $logger->error("bcpmode '$bcpmode' is invalid.  Must be either ".
		   "in or out\n");
    &printUsage();
}

## Use class method to verify the database vendor type
if (! Prism::verifyDatabaseType($database_type)){
    $logger->logdie("Unsupported database type '$database_type'");
}

## verify and set the output directory
$directory = &verifyAndSetOutdir($directory);

## Caching should be turned off
$ENV{DBCACHE} = undef;
$ENV{DBCACHE_DIR} = undef;

## Set the PRISM env var
&setPrismEnv($server, $database_type);

## Instantiate Prism object
my $prism = new Prism(user => $username, 
		      password => $password, 
		      db => $database );

if (!defined($prism)){
    $logger->logdie("prism was not defined");
}

## Set default values
if (!$batchsize){
    if ($database_type eq 'sybase'){
	$batchsize = Prism::sybaseBatchSize();
    }
    else{
	## not used by postgresql, but will assign some
	## value to allow checks to pass
	$batchsize = 0;
    }
}

## test mode - no records are inserted into the target database
if (!defined($testmode)){
    $testmode = 0;
}
else {
    if (($testmode == 1 ) || ($testmode == 0)){
	$logger->info("user specified testmode '$testmode'");
    }
    else{
	$logger->logdie("testmode '$testmode' was not recognized.  ".
			"Aborting.");
    }
}

## update the table statistics for tables into which data
## was just loaded.  Default behavior is to not update the 
## table statistics.
## Sybase: update statistics
## PostgreSQL: vacuum
if (!defined($noupdatestats)){
    $noupdatestats = 1;
}
else{
    if (($noupdatestats == 1) || ($noupdatestats == 0)){
	# true therefore DO NOT update stats
	$logger->info("user specified noupdatestats '$noupdatestats'");
    }
    else{
	$logger->logdie("noupdatestats '$noupdatestats' was not recognized.  Aborting.");
    }
}

#----------------------------------------------------------------------------------
# Determine whether the user wishes to tar-gzip the output BCP .out files
# Check tgz for valid values
#
#----------------------------------------------------------------------------------
if ((defined($directory)) && ($bcpmode eq 'out') && (defined($tgz))){
    if ($tgz == 0){
	if ($logger->is_debug()){
	    $logger->debug("User has specified not to tar-gzip the output BCP .out files");
	}
    }
    elsif ($tgz == 1) {
	if ($logger->is_debug()){
	    $logger->debug("User has specified to tar-gzip the output BCP .out files");
	}
    }
    else{
	$logger->warn("tgz '$tgz' was not recognized - default behavior is to not tar-gzip the output .out files");
    }
}


my $tableCommitOrder = Prism::chadoTableCommitOrder();

my @commitorder = split(/,/,$tableCommitOrder);

&checkDirectory($directory);

$table =~ s/^\s+//; ## strip leading whitespace
$table =~ s/\s+$//; ## strip trailing whitespace

if (!defined($bcpExt)){
    $bcpExt = Prism::getBcpFileExtension($database_type);
}

if ($bcpmode eq 'in'){

    ## Two supported use cases are:
    ## 1) load all bcp files contained in the specified directory
    ## 2) load a specified bcp file
    
    my $infileListLookup = {};

    ## Qualify the infile
    if (defined($infile)){

	if (!-e $infile){
	    $logger->logdie("infile '$infile' does not exist");
	}
	if (!-f $infile){
	    $logger->logdie("infile '$infile' is not a file");
	}
	if (!-r $infile){
	    $logger->logdie("infile '$infile' does not have read permissions");
	}
	
	## Qualify the target table
	if (!defined($table)){

	    ## table was not specified by user, therefore assume that the
	    ## file is named after the target table # i.e. infile is
	    ## /usr/local/scratch/sundaram/feature.out therefore target 
	    ##table is feature
	    $table = File::Basename::basename($infile);

	    ## strip off the file extension
	    $table =~ s/\.$bcpExt//;
	}
	else{
	    ## table was defined, however contains a list of target tables
	    ## - not acceptable in bcpmode 'in'
	    if ( $table =~ /,/){
		$logger->logdie("When loading tables, you can only specify one target ".
				"table OR else all files in the specified directory ".
				"'$directory' must be name according to target table ".
				"e.g. feature.out targets feature.");
	    }
	}
	
	## Load the infile-table key value pair
	$infileListLookup->{$infile} = $table;

    }
    else {

	#
	# infile was not specified therefore all bcp files located in directory will be processed/loaded
	# even if targettable is defined, its irrelevant 
	# All bcp files in the specified directory must be named after the target table e.g. analysis.out targets analysis
	#

	opendir(INDIR, "$directory") or $logger->logdie("Could not open directory '$directory' ".
							"in read mode");


	## Read all of the file with the file extention $bcpExt
	my @bcpFileList = grep {$_ ne '.' and $_ ne '..' and $_ =~ /\S+\.$bcpExt/} readdir INDIR;
	
	chomp @bcpFileList;	

	my $bcpFileCount = $#bcpFileList + 1;

	if ($bcpFileCount < 1){
	    $logger->logdie("Did not find any BCP files in directory ".
			    "'$directory' with file extension '$bcpExt'");
	}
	else {
	    $logger->info("Found $bcpFileCount BCP files in directory ".
			  "'$directory' with file extension '$bcpExt'");
	}


	foreach my $infile (@bcpFileList){

	    $infile = $directory . '/' . $infile;
	    
	    if (!-f $infile){
		$logger->logdie("infile '$infile' is not a file");
	    }
	    if (!-r $infile){
		$logger->logdie("infile '$infile' does not have read permissions");
	    }
	    
	    ## Derive the table name
	    my $tableName = File::Basename::basename($infile);

	    $tableName =~ s/\.$bcpExt//;
	    
	    $infileListLookup->{$infile} = $tableName;
	}
    }

    my $tableinfo = &qualifyInputTableList( $prism,
					    $database,
					    $server,
					    $infileListLookup,
					    $ignoreEmptyBcp
					    );

    if (!defined($tableinfo)){
	$logger->logdie("tableinfo was not defined.  Unable to load database ".
		       "'$database' on server '$server' database_type '$database_type'");
    }
    else{
	&executeBcpInOperations( $prism,
				 $username,
				 $password,
				 $database,
				 $server,
				 $tableinfo,
				 $batchsize,
				 \@commitorder,
				 $testmode,
				 $noupdatestats,
				 $printCommandsOnly
				 );
    }

    if ($database_type ne 'postgresql'){
	&verifyLoadedRecordCounts($tableinfo);
    }
}
elsif ($bcpmode eq 'out'){
    
    ## Two supported use cases are:
    ## 1) dump specified table(s) to specific directory
    ## 2) dump all tables to specific directory

    my $tablelist;

    if (!defined($table)){
	$tablelist = $prism->systemObjectsListByType("table");
    }
    else{
	if ($table =~ /,/){
	    ## Get the list of tables
	    @{$tablelist} = split(/,/, $table);
	}
	else{
	    # Else, push the single specified table onto the list
	    push(@{$tablelist}, $table);
	}
    }
    
    ## Qualify the table(s) in the list. Sets the outfile names.
    my $qualifiedtableinfo = &qualifyOutputTableList( $prism,
						      $tablelist,
						      $directory
						      );
    
    if (!defined($qualifiedtableinfo)){
	$logger->logdie("qualifiedtableinfo was not defined.  Unable to dump @{$tablelist} ".
			"from '$database' on server '$server'.");
    }

    &executeBcpOutOperations( $prism,
			      $username,
			      $password,
			      $database,
			      $server,
			      $qualifiedtableinfo,
			      $directory,
			      $batchsize,
			      $printCommandsOnly
			      );

    &verifyDumpedRecordCounts($qualifiedtableinfo);
    
    
    if ((defined($directory)) && ($tgz == 1)) {
	&createTarBall($database, $directory);
    }

}

print ("'$0': Program execution complete\n");
print ("Please review logfile: $logfile\n");
exit(0);

#------------------------------------------------------------------------------------------------------------
#
#                                   END MAIN -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------
 
sub createTarBall {

    my ($database, $directory) = @_;

    ## Change to the directory in order to create .tgz which will extract locally
    chdir($directory);

    my $tfile = 'chado.' . $database . '.tables.tgz';

    if (-e $tfile){
	
	# If the file already exists, create backup
	my $bakfile = $directory .'/chado.' . $database . ".tables.$$.tgz";

	$logger->info("Creating backup of $tfile as $bakfile");

	rename ($tfile, $bakfile);
    }

    ## tar and gzip the BCP .out files (remove the .out files in the process)

    my $x = "tar -zcvf $tfile --remove-files *.out";

    eval {  qx{$x};  };
    if ($@){
	$logger->warn("Error occured while attempting the following system call: ".
		      "$x -- The error was: $! -- Your BCP .out files are fine");
    }
}



#-------------------------------------------------------------------------
# verifyLoadedRecordCounts()
#
#-------------------------------------------------------------------------
sub verifyLoadedRecordCounts {
    
    my ($tableinfo) = @_;

    my $fatalCtr=0;

    foreach my $table (sort keys %{$tableinfo}){

	my $precount  = $tableinfo->{$table}->{'pre-count'};

	my $bcpcount  = $tableinfo->{$table}->{'bcp-count'};

	my $postcount = $tableinfo->{$table}->{'post-count'};


	if ($precount + $bcpcount != $postcount){
	    $logger->warn("Counts incorrect for table '$table' pre-count ".
			  "'$precount' bcp-count '$bcpcount' post-count '$postcount'");
	    $fatalCtr++;
	}
	else{
	    $logger->info("Number of records loaded into table '$table' '$bcpcount'");
	}
    }

    if ($fatalCtr>0){
	$logger->logdie("Record counts were off.  Please check logfile.");
    }
}

#-------------------------------------------------------------------------
# verifyDumpedRecordCounts()
#
#-------------------------------------------------------------------------
sub verifyDumpedRecordCounts {
    
    my ($tableinfo) = @_;

    foreach my $table (sort keys %{$tableinfo}){

	my $rowcount  = $tableinfo->{$table}->{'pre-count'};

	my $dumpcount  = $tableinfo->{$table}->{'dump-count'};

	if ($rowcount != $dumpcount){
	    $logger->logdie("Counts incorrect for table '$table' rowcount '$rowcount' ".
			    "dumped record count '$dumpcount'");
	}
	else{
	    $logger->info("Number of records dumped from table/view '$table' '$dumpcount'");
	}
    }
}

#--------------------------------------------------------
# verifyAndSetOutdir()
#
#--------------------------------------------------------
sub verifyAndSetOutdir {

    my ( $outdir) = @_;

    ## strip trailing forward slashes
    $outdir =~ s/\/+$//;
    
    ## set to current directory if not defined
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

    print STDERR "SAMPLE USAGE:  $0 -D database [-O outfile] -P password [-S server] -U username [-Z tgz] [--bcp_ext] -b bcpmode --database_type [-d debug_level] [-h] [-i infile] [-l logfile] [-m] [-o directory] [-s batchsize] [-t table] [-u noupdatestats] [-z testmode]\n".
    "  -D|--database           = target Chado database\n".
    "  -O|--outfile            = Optional - Output file to dump table records to\n".
    "  -P|--password           = password\n".
    "  -S|--server             = Optional - server (default is SYBTIGR)\n".
    "  -U|--username           = username\n".
    "  -a|--abort              = Optional - abort (-a=1) if load count discrepancies are detected (default is abort (-a=1) to override -a=0)\n".
    "  -b|--bcpmode            = bcp mode either in or out\n".
    "  --bcp_ext               = Optional - tab-delimited file extension (Default sybase.bcp or pgsql.bcp depending on database_type)\n".
    "  -d|--debug_level        = Optional - Coati::Logger logfile logging level (default is 0)\n".
    "  --database_type         = Database vendor type e.g. sybase or postgresql\n".
    "  -h|--help               = This help message\n".
    "  -i|--infile             = Optional - Input BCP file to be loaded into the target database\n".
    "  -l|--logfile            = Optional - logfile log file (default is /tmp/flatFileToChado.pl.log)\n".
    "  -m|--man                = Display the pod2usage man page for this utility\n".
    "  -o|--directory          = Optional - directory to read/write BCP files (default is current working directory)\n".
    "  -s|--batchsize          = Optional - bcp utility batchsize (default 3000 rows)\n".
    "  -t|--table              = Optional - chado table to be affected\n".
    "  -u|--noupdatestats      = Optional - Default is -u=1 (do not update stats) to update stats: -u=0\n".
    "  -z|--testmode           = Optional - records are not inserted into the target database\n".
    "  -Z|--tgz                = Optional - tgz=1 means tar -zcvf --remove-files *.out (default is -tgz=0)\n";
    exit 1;

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

#----------------------------------------------------------------------------
# getLogger()
#
#----------------------------------------------------------------------------
sub getLogger {

    my ($logfile, $debug_level) = @_;
    
    my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				     'LOG_LEVEL'=>$debug_level);
    
    my $logger = Coati::Logger::get_logger(__PACKAGE__);
    
    return $logger;
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



##----------------------------------------------------------------------------
## qualifyInputTableList()
##
## This will qualify 
## 1) target tables (verify that the table exists and given the size
##    of the input that there is enough space in the database/table)
## 2) input delimited files
## 3) assign individual bcp/COPY logfiles per target table
##
##----------------------------------------------------------------------------
sub qualifyInputTableList {

    my ($prism, $database, $server, $infileListLookup,$ignoreEmptyBcp) = @_;

    my $qualifiedtableinfo = {};

    my $bcpfilecount=0;
    
    foreach my $infile ( keys %{$infileListLookup} ) {

	$bcpfilecount++;
	## infile was already qualified in flatFileToChado.pl

	if (-z  $infile){
	    ## The infile had zero content
	    if ((defined($ignoreEmptyBcp)) && ($ignoreEmptyBcp == 1)){
		$logger->warn("Will ignore empty BCP file '$infile'");
		next;
	    }
	    else {
		$logger->logdie("'$infile' has zero content and thus will not be processed");
	    }
	}

	my $targetTable;

	## Lookup the table name
	if (exists $infileListLookup->{$infile}){
	    $targetTable = $infileListLookup->{$infile};
	}
	else {
	    $logger->logdie("targetTable was not defined");
	}

	## Cannot continue unless the table in question exists
	if (! $prism->tableExist($targetTable)) {
	    $logger->logdie("table '$targetTable' does not exist in database '$database' ".
				     "on server '$server'");
	}

	## Cannot continue unless the table in question has enough space
	## to accomodate the inbound data.
	if (! $prism->tableHaveSpace(
				     table  => $targetTable,
				     infile => $infile
				     )){
	    
	    $logger->logdie("The target table '$targetTable' does not have enough ".
				     "space for input file '$infile'");
	}

	$qualifiedtableinfo->{$targetTable}->{'infile'} = $infile;
	
	my $rowcount = $prism->tableRecordCount($targetTable);
	
	if (defined($rowcount)){
	    $qualifiedtableinfo->{$targetTable}->{'pre-count'} = $rowcount;
	}
	else {
	    $logger->logdie("Could not retrieve record counts");
	}
	
    }

    if ($bcpfilecount > 0){
	return $qualifiedtableinfo;
    }
    else{
	$logger->logdie("No BCP files to load");
    }
}




#------------------------------------------------------------------------------
# qualifyOutputTableList()
#
#------------------------------------------------------------------------------
sub qualifyOutputTableList {

    ## Note that this function should/could be moved to the client
    ## bcptochado.pl (unless some other client can use the method.

    my ($prism, $tablelist, $directory) = @_;

    if (!defined($prism)){
	$logger->logdie("prism was not defined");
    }
    if (!defined($tablelist)){
	$logger->logdie("tablelist was not defined");
    }
    if (!defined($directory)){
	$logger->logdie("directory was not defined");
    }

    ## Table list has been created, now need to assign the bcp .out files and bcp error log files
    my $qualifiedtableinfo = {};

    foreach my $table (sort @{$tablelist}){
	
	my $outfile = $directory . '/' . $table . '.out';
	
	if (-e $outfile){
	    if (!-w $outfile){
		$logger->logdie("Unable to dump table '$table' since outfile ".
					 "'$outfile' exists but does not have write ".
					 "permissions.");
	    }
	}

	## Note: we presume the output directory has enough space for 
	## dumping out table contents to files
	$qualifiedtableinfo->{$table}->{'outfile'} = $outfile;
    }

    return $qualifiedtableinfo;
}



#------------------------------------------------------------------------------
# executeBcpOutOperations()
#
#------------------------------------------------------------------------------
sub executeBcpOutOperations {

    my ($prism, $username, $password, $database, $server, $qualifiedTableInfo, $directory,
	$batchsize, $printCommandsOnly) = @_;

    if (!defined($prism)){
	$logger->logdie("prism was not defined");
    }
    if (!defined($username)){
	$logger->logdie("username was not defined");
    }
    if (!defined($password)){
	$logger->logdie("password was not defined");
    }
    if (!defined($database)){
	$logger->logdie("database was not defined");
    }
    if (!defined($server)){
	$logger->logdie("server was not defined");
    }
    if (!defined($qualifiedTableInfo)){
	$logger->logdie("qualifiedTableInfo was not defined");
    }
    if (!defined($directory)){
	$logger->logdie("directory was not defined");
    }
    if (!defined($batchsize)){
	$logger->logdie("batchsize was not defined");
    }

    foreach my $table (sort keys %{$qualifiedTableInfo}){
	
	my ($outfile);
	
	if ((exists ($qualifiedTableInfo->{$table}->{'outfile'})) and (defined($qualifiedTableInfo->{$table}->{'outfile'}))){
	    
	    $outfile = $qualifiedTableInfo->{$table}->{'outfile'};
	    
	    my $rowcount = $prism->tableRecordCount($table);
	    
	    if (defined($rowcount)){
		$qualifiedTableInfo->{$table}->{'pre-count'} = $rowcount;
	    }
	    
	    my $dirname = dirname($logfile);
	    my $bcperrorfile = $dirname . '/' . $table . '.bcperror';

	    my $dump_count = $prism->bulkDumpTable(
						   outfile        => $outfile,
						   table          => $table,
						   bcperrorfile   => $bcperrorfile,
						   server         => $server,
						   database       => $database,
						   username       => $username,
						   password       => $password,
						   batchsize      => $batchsize,
						   );
	    
	    if (defined($dump_count)){
		$qualifiedTableInfo->{$table}->{'dump-count'} = $dump_count;
	    }
	    
	    
	    if ($dump_count != $rowcount){
		$logger->logdie("dump-count '$dump_count' != rowcount '$rowcount' ".
				"for table '$table'.");
	    }
	}
	else{
	    $logger->logdie("outfile was not defined for source table '$table'.  ".
			    "Continuing to process other outfiles/tables");
	}
    }
}

#----------------------------------------------------------------------------
# executeBcpInOperations()
#
# This will load delimited file via vendor provided utilities
#
#----------------------------------------------------------------------------
sub executeBcpInOperations {

    my ($prism, $username, $password, $database, $server, $tableinfo,
	$batchsize, $commitorder, $testmode, $noupdatestats, $printCommandsOnly) = @_;

    if (!defined($prism)){
	$logger->logdie("prism was not defined");
    }
    if (!defined($username)){
	$logger->logdie("username was not defined");
    }
    if (!defined($password)){
	$logger->logdie("password was not defined");
    }
    if (!defined($database)){
	$logger->logdie("database was not defined");
    }
    if (!defined($server)){
	$logger->logdie("server was not defined");
    }
    if (!defined($tableinfo)){
	$logger->logdie("tableinfo was not defined");
    }
    if (!defined($batchsize)){
	$logger->logdie("batchsize was not defined");
    }
    if (!defined($commitorder)){
	$logger->logdie("commitorder was not defined");
    }
    if (!defined($testmode)){
	$logger->logdie("testmode was not defined");
    }
    if (!defined($noupdatestats)){
	$logger->logdie("noupdatestats was not defined");
    }
    
    my $tableCounter=0;

    foreach my $orderedtable (@{$commitorder}){

	$tableCounter++;
		
	my ($infile);

	if ((exists ($tableinfo->{$orderedtable})) &&
	    (defined($tableinfo->{$orderedtable}))){
	    
	    if ((exists ($tableinfo->{$orderedtable}->{'infile'})) &&
		(defined($tableinfo->{$orderedtable}->{'infile'}))){

		$infile = $tableinfo->{$orderedtable}->{'infile'};
	    }
	    else{
		$logger->logdie("infile was not defined for target table '$orderedtable'.  ".
					  "Continuing to process other infiles/tables");
	    }
		    
	    my $dirname = dirname($logfile);

	    my $bcperrorfile = $dirname . '/' . $tableCounter . '.bcperror';
	    $logger->warn("The bcp error file for table '$orderedtable' was set to '$bcperrorfile'");

	    my $bcpcount = $prism->bulkLoadTable(
						 infile         => $infile,
						 table          => $orderedtable,
						 server         => $server,
						 database       => $database,
						 username       => $username,
						 password       => $password,
						 batchsize      => $batchsize,
						 bcperrorfile   => $bcperrorfile,
						 testmode       => $testmode,
						 print_commands_only => $printCommandsOnly
						 );


	    if ($database_type ne 'postgresql'){
		## If user specified that update statistics should be run executed:

		if (defined($noupdatestats)){
		    if ($noupdatestats == 0){
			$prism->updateStatistics($orderedtable, $testmode);
		    }
		}


		$tableinfo->{$orderedtable}->{'bcp-count'} = $bcpcount;
		
		my $rowcount = $prism->tableRecordCount($orderedtable);
		
		if (defined($rowcount)){
		    $tableinfo->{$orderedtable}->{'post-count'} = $rowcount;
		}
		else {
		    $logger->logdie("rowcount was not defined for table '$orderedtable'");
		}
		
		## If abort option was specified, and if load counts are not correct need to
		## abort execution right here.
		## That is if pre-count + bcpcount != post-count then abortx
		if ((exists $tableinfo->{$orderedtable}->{'pre-count'}) && 
		    (defined($tableinfo->{$orderedtable}->{'pre-count'}))){
		    
		    my $precount = $tableinfo->{$orderedtable}->{'pre-count'};
		    
		    if ($precount + $bcpcount != $rowcount){
			$logger->logdie("precount '$precount' + bcpcount '$bcpcount' ".
					"!= rowcount '$rowcount' for table ".
					"'$orderedtable'.");
		    }
		}
		else{
		    $logger->logdie("Unable to retrieve pre-count for table ".
				    "'$orderedtable'");
		}
	    }
	}
	else{
	    $logger->info("orderedtable '$orderedtable' was not one of the user defined ".
			  "target tables.  Continuing to process other infiles/tables");
	}
    }
}
