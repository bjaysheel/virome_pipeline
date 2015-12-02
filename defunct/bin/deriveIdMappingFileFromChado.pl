#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

deriveIdMappingFileFromChado.pl - Loads delimited flat files into chado databases

=head1 SYNOPSIS

USAGE:  deriveIdMappingFileFromChado.pl --database --database_type --password --server --username [--asmbl_id] [--bsmlfile] [--bsmllistfile] [--debug_level] [-h] [--logfile] [-m] [--outdir] [--orgdb]

=head1 OPTIONS

=over 8

=item B<--database>
    
    Target database name

=item B<--password>
    
    Database password

=item B<--server>
    
    Server name

=item B<--username>
    
    Database username

=item B<--database_type>
    
    sybase or postgresql

=item B<--debug_level>
    
    Optional - Coati::Logger logfile logging level (default is 0)

=item B<--help,-h>

    Print this help

=item B<--logfile>
    
    Optional - Logfile log file.  (default is /tmp/deriveIdMappingFileFromChado.pl.log)

=item B<--man,-m>

    Display pod2usage man page for this utility

=item B<--outdir>
    
    Optional - output directory where mapping file should be written

=item B<--asmbl_id>
    
    Optional - orgdb must be specified as well

=item B<--orgdb>
    
    Optional - asmbl_id must be specified as well

=item B<--bsmlfile>
    
    Optional - legacy2bsml.pl output file.  This script will derive the orgdb and asmbl_id from the .bsml filename

=item B<--bsmllistfile>
    
    Optional - legacy2bsml bsml list file.  This script will process each .bsml file listed in the file and will derive the orgdb and asmbl_id from the filenames


=back

=head1 DESCRIPTION

    deriveIdMappingFileFromChado.pl - Retrieve dbxref.accession to feature.uniquename tuples from the chado database and create an identifier mapping file
    e.g.
    1) perl -I shared/ -I Prism/ deriveIdMappingFileFromChado.pl --username sundaram --password sundaram7 --database clostridium --database_type sybase --server SYBTIGR --orgdb=bcl --asmbl_id=4306
    2) perl -I shared/ -I Prism/ deriveIdMappingFileFromChado.pl --username sundaram --password sundaram7 --database clostridium --database_type sybase --server SYBTIGR --bsmllistfile /usr/local/annotation/CLOSTRIDIUM/output_repository/legacy2bsml/7164_default/legacy2bsml.bsml.list
    3) perl -I shared/ -I Prism/ deriveIdMappingFileFromChado.pl --username sundaram --password sundaram7 --database clostridium --database_type sybase --server SYBTIGR --bsmlfile /usr/local/annotation/CLOSTRIDIUM/output_repository/legacy2bsml/7164_default/i1/g1/bcl_4306_assembly.prok.bsml

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

my ($username, $password, $database, $server, $database_type,
    $logfile, $debug, $help, $man, $bsmlfile,
    $debug_level, $orgdb, $asmbl_id, $outdir,
    $bsmllistfile);

my $results = GetOptions (
			  'database=s'        => \$database,
			  'password=s'        => \$password,
			  'server=s'          => \$server,
			  'username=s'        => \$username,
			  'debug_level=s'     => \$debug_level,
			  'help|h'            => \$help, 
			  'logfile=s'         => \$logfile,
			  'man|m'             => \$man,
			  'database_type=s'   => \$database_type,
			  'bsmlfile=s'        => \$bsmlfile,
			  'orgdb=s'           => \$orgdb,
			  'asmbl_id=s'        => \$asmbl_id,
			  'outdir=s'          => \$outdir,
			  'bsmllistfile=s'    => \$bsmllistfile
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
    $logfile = '/tmp/deriveIdMappingFileFromChado.pl.log';
    print STDERR "log file was set to '$logfile'\n";
}


## Initialize the logger
my $logger = &getLogger($logfile, $debug_level);


## Use class method to verify the database vendor type
if (! Prism::verifyDatabaseType($database_type)){
    $logger->logdie("Unsupported database type '$database_type'");
}

## verify and set the output directory
$outdir = &verifyAndSetOutdir($outdir);

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

&checkDirectory($outdir);

my $orgdbToAsmblIdLookup = {};


if (defined($bsmlfile)){   
    &loadOrgdbAsmblIdLookupFromBsmlFile($bsmlfile, $orgdbToAsmblIdLookup);
}
elsif (defined($bsmllistfile)){
    &loadOrgdbAsmblIdLookupFromBsmlListFile($bsmllistfile, $orgdbToAsmblIdLookup);
}
elsif ((defined($orgdb)) && (defined($asmbl_id))){
    $asmbl_id =~ s/\s*//g;
	    
    if ($asmbl_id !~ /^\d+$/){
	$logger->logdie("asmbl_id '$asmbl_id' is not a natural number");
    }
	    
    $orgdbToAsmblIdLookup->{$orgdb}->{$asmbl_id}++;
}
else {
    $logger->warn("User did not specify --bsmllistfile, --bsmlfile, nor --orgdb and --asmbl_id ".
		  "therefore, will derive all ID mappings for all non-match features");
    $orgdbToAsmblIdLookup = $prism->orgdbToAsmblId();
}

my $orgDbCtr=0;
my $asmblIdCtr=0;

foreach my $orgDb ( sort keys %{$orgdbToAsmblIdLookup}){
    
    $orgDbCtr++;

    foreach my $asmbl_id ( sort keys %{$orgdbToAsmblIdLookup->{$orgDb}} ){

	$asmblIdCtr++;

	my $prefix = &getPrefix($orgDb);
	
	print "Processing orgdb '$orgDb' asmbl_id '$asmbl_id' with prefix '$prefix'\n";
	
	my $contigRecords = $prism->contigIdentifierMappings($prefix, 
							     $asmbl_id);
	
	if (scalar(@{$contigRecords}) < 1 ){
	    $logger->logdie("No contig record retrieve for orgdb '$orgDb' ".
			    "asmbl_id '$asmbl_id' prefix '$prefix'");
	}
	
	my $subfeatureRecords = $prism->subFeatureIdentifierMappings($prefix,
								     $asmbl_id);
	
	$prism->subSubFeatureIdentifierMappings($prefix,
						$asmbl_id,
						$subfeatureRecords);
	
	my $mapfile = &createMapFileName($prefix,
					 $orgDb,
					 $asmbl_id,
					 $outdir);
	
	&writeRecordsToMappingFile($mapfile,
				   $subfeatureRecords,
				   $contigRecords);
    }
}
    
print "Processed '$orgDbCtr' orgdbs\n";    
print "Processed '$asmblIdCtr' asmbl_ids\n";    
print ("'$0': Program execution complete\n");
print ("Please review logfile: $logfile\n");
exit(0);

#------------------------------------------------------------------------------------------------------------
#
#                                   END MAIN -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------

sub createMapFileName {
    my ($prefix, $orgdb, $asmbl_id, $outdir) = @_;

    my $mapfile = $outdir . '/' . $orgdb . '_' . $asmbl_id . '.idmap';

    if ($logger->is_debug()){
	$logger->debug("map file was set to '$mapfile'");
    }

    return $mapfile;
}

sub writeRecordsToMappingFile {

    my ($mapfile, $subfeatureRecords, $contigRecords) = @_;

    open (MAPFILE, ">$mapfile") || $logger->logdie("Could not open map file '$mapfile' in output mode. Error was: $!");

    for (my $i=0; $i< scalar(@{$contigRecords}); $i++){
	print MAPFILE "$contigRecords->[$i][0]\t$contigRecords->[$i][1]\n";
    }

    if (defined($subfeatureRecords)){
	for (my $i=0; $i< scalar(@{$subfeatureRecords}); $i++){
	    print MAPFILE "$subfeatureRecords->[$i][0]\t$subfeatureRecords->[$i][1]\n";
	}
    }

    print "Ientifier mappings were written to '$mapfile'\n";

}

sub loadOrgdbAsmblIdLookupFromBsmlListFile {
    
    my ($bsmllistfile, $orgdbToAsmblIdLookup) = @_;
    
    if (-e $bsmllistfile){
	if (-f $bsmllistfile){
	    
	    open (BSMLLISTFILE, "<$bsmllistfile") || $logger->logdie("Could not open BSML list ".
								     "file '$bsmllistfile' in read ".
								     " mode.  Error was $! ");
	    
	    while (my $bsmlfile = <BSMLLISTFILE>){
		chomp $bsmlfile;
		&loadOrgdbAsmblIdLookupFromBsmlFile($bsmlfile, $orgdbToAsmblIdLookup);
	    }
	}
	else {
	    $logger->logdie("bsmllistfile '$bsmllistfile' is not a file");
	}
    }
    else {
	$logger->logdie("bsmllistfile '$bsmllistfile' does not exist");
    }
}

sub loadOrgdbAsmblIdLookupFromBsmlFile {

    my ($bsmlfile, $orgdbToAsmblIdLookup) = @_;

    if (-e $bsmlfile){
	if (-f $bsmlfile){
	    my $basename = basename($bsmlfile);
	    
	    my ($orgdb, $asmbl_id) = split(/_/, $basename);
	    
	    
	    $orgdbToAsmblIdLookup->{$orgdb}->{$asmbl_id}++;
	}
	else {
	    $logger->logdie("BSML file '$bsmlfile' is not a file");
	}
    }
    else {
	$logger->logdie("BSML file '$bsmlfile' does not exist");
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

    print STDERR "SAMPLE USAGE:  $0 --database --database_type --password --server --username [--asmbl_id] [--bsmlfile] [--bsmllistfile] [--debug_level] [-h] [--logfile] [-m] [--outdir] [--orgdb]\n".
    "  --database          = target chado database\n".
    "  --database_type     = relational database management system type e.g. sybase or postgresql\n".
    "  --password          = database password\n".
    "  --server            = server name on which the database resides\n".
    "  --username          = database username\n".
    "  --asmbl_id          = Optional - legacy annotation database assembly identifier. Note that orgdb must be specified as well\n".
    "  --bsmlfile          = Optional - BSML file produced by legacy2bsml.pl\n".
    "  --bsmllistfile      = Optional - BSML list file produced by legacy2bsml workflow component\n".
    "  --debug_level       = Optioanl - Coati Logger debugging level (default is 0)\n".
    "  -h|--help           = This help message\n".
    "  --logfile           = Optional - logfile log file (default is /tmp/deriveIdMappingFileFromChado.pl.log)\n".
    "  -m|--man            = Display the pod2usage man page for this utility\n".
    "  --outdir            = Optional - output directory to which the mapping file(s) will be written (default is current working directory)\n".
    "  --orgdb             = Optional - legacy annotation database identifier.  Note that the asmbl_id must be specified as well\n";

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
    
    $vendor = "Bulk" . ucfirst($vendor);
    ## We're overriding the env stored in conf/Prism.conf
    my $prismenv = "Chado:$vendor:$server";


    $ENV{PRISM} = $prismenv;
}

sub getPrefix {
    my ($orgdb) = @_;

    my $prefix = 'TIGR_' . ucfirst($orgdb);

    return $prefix;
}

