#!/usr/local/bin/perl
#-----------------------------------------------------------------------
# program:   proteinLocalization.pl
# author:    Jay Sundaram
# date:      2003/08/11
# 
# purpose:   Inserts rows into featureloc thereby storing
#            the localization of proteins to the contig
#
#
#-------------------------------------------------------------------------

=head1 NAME

proteinLocalization.pl - Executes user specified stored procedure in user specified database

=head1 SYNOPSIS

USAGE:  proteinLocalization.pl -U username -P password -D database -S server [-d debug_level] [-l logfile] [-a] [-h] [-m] [-o outdir]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database login username

=item B<--password,-P>
    
    Database login password

=item B<--database,-D>
    
    Database name

=item B<--server,-S>
    
    Sybase server name, either SYBIL or SYBTIGR

=item B<--autoload,-a>

    Automatically load the protein localizations into the database

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--help,-h>

    Print this help

=item B<--man,-m>

    Display man pages for this script

=item B<--outdir,-o>

    output directory for the featureloc.out file

=item B<--logfile,-l>

    Optional -- Log4perl output file name.  Default is /tmp/proteinLocalization.pl.log

=back

=head1 DESCRIPTION

    proteinLocalization.pl - Inserts protein localizations to contigs into featureloc table

=cut


use strict;
no strict "refs";
use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use File::Copy;
use Data::Dumper;
use Digest::MD5 qw(md5);
use Coati::Logger;
use Config::IniFiles;
use Benchmark;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($username, $password, $database, $server, $help, $verbose, $logfile, $man, $debug, $QUERYPRINT, $outdir, $autoload, $debug_level);
my $loader = '/home/sundaram/code/prok_prism/shared/loadSybaseChadoTables.pl';

my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'database|D=s'        => \$database,
			  'server|S=s'          => \$server,
			  'logfile|l=s'         => \$logfile,
			  'autoload|a'          => \$autoload,
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'outdir|o=s'          => \$outdir,
			  'verbose|v'           => \$verbose,
			  'debug_level|d=s'     => \$debug_level
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("username was not defined\n") if (!$username);
print STDERR ("password was not defined\n") if (!$password);
print STDERR ("server was not defined\n")   if (!$server);
print STDERR ("database was not defined\n") if (!$database);

&print_usage if(!$username or !$password or !$database or !$server);

# initialize the logger
#
if (!defined($logfile)){
    #
    # Log4perl log file was not specified by user, assign default
    #
    $logfile = "/tmp/bsml2chado.pl.log";
    print "logfile set to '$logfile'\n";
}

if (-e $logfile){
    #
    # Log4perl log file already exists - backup the file and continue
    #
    my $bakfile = $logfile . ".$$.bak";
    rename($logfile, $bakfile);
    print "Moved output file '$logfile' to backup file '$bakfile'\n";
}



my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


if (($server ne 'SYBIL') and ($server ne 'SYBTIGR')){
    $logger->logdie("Server name must be either \"SYBIL\" or \"SYBTIGR\", not: $server");
}

$outdir =~ s/\/+$//;
$outdir = "." if (!$outdir);
$logger->logdie("$outdir is not a directory") if (!-d $outdir);
$logger->logdie("$outdir does not have write permissions") if (!-w $outdir);


#----------------------------------------------------------
# Create writer object the conf file will be automatically
# read and loaded.
#
#----------------------------------------------------------
$logger->info("Instantiating Prism Reader object");

my $prism_reader = new Prism( 
			   user       => $username,
			   password   => $password,
			   db         => $database,
			   debug      => $debug,
			   queryprint => $QUERYPRINT
			   );


$logger->logdie("prism_reader was not defined") if (!defined($prism_reader));



my $protein_assembly_lookup = $prism_reader->protein_assembly_lookup();
$logger->logdie("protein_assembly_lookup was not defined") if (!defined($protein_assembly_lookup));



my $max_featureloc_id = &retrieve_max_featureloc_id($prism_reader);
$logger->logdie("max_featureloc_id was not defined") if (!defined($max_featureloc_id));


my $protein_rows = &retrieve_protein_contig_rows($prism_reader);
$logger->logdie("protein_rows was not defined") if (!defined($protein_rows));

my $featureloc_file = $outdir . "/featureloc.out";

&build_protein_localization_rows($$max_featureloc_id, $protein_rows, \$featureloc_file, $protein_assembly_lookup);

if ($autoload){
    &load_protein_localizations(
				username => \$username,
				password => \$password,
				database => \$database,
				server   => \$server,
				outdir   => \$outdir,
				);
}
else{
    print STDERR "Please load $featureloc_file into the database: $database on server: $server\n";
}

print ("'$0' Execution complete\n  Verify logfile: $logfile\n");


#---------------------------------------------------------------------------------------------------
#
# END OF MAIN -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------------------


#--------------------------------------------------------
# build_protein_localization_rows()
#
#
#--------------------------------------------------------
sub build_protein_localization_rows {

    my $logger = Coati::Logger::get_logger("protein");
    $logger->info("Entered build_protein_localization_rows");

    my ($max_id, $rows, $file, $lookup) = @_;

    $logger->logdie("max_id was not defined")   if (!defined($max_id));
    $logger->logdie("rows was not defined")     if (!defined($rows));;    
    $logger->logdie("file was not defined")     if (!defined($file));
    $logger->logdie("lookup was not defined")   if (!defined($lookup));

    my $tab = "??\t??";
    my $record =  "????\n";

    my $uc = {};


    if (-e $$file){
	my $bakfile = $$file . ".$$.bak";
	rename($$file, $bakfile);
	$logger->info("Moved output file '$$file' to backup file '$bakfile'");
    }

    open (OUTFILE, ">$$file") or $logger->logdie("Could not open file $$file in output mode");
    
    foreach my $element (@$rows){

	$logger->logdie("element was not defined") if (!defined($element));
	
	my @x;
	$x[0]  = $element->{'pfeature_id'};
	$x[1]  = $element->{'afeature_id'};
	$x[2]  = $element->{'fmin'};
	$x[3]  = $element->{'is_fmin_partial'};
	$x[4]  = $element->{'fmax'};
	$x[5]  = $element->{'is_fmax_partial'};
	$x[6]  = $element->{'strand'};
	$x[7]  = $element->{'phase'};
	$x[8]  = $element->{'residue_info'};
	$x[9]  = $element->{'locgroup'};
	$x[10] = $element->{'rank'};


	#-----------------------------------------------------------------------------------------------------------------------
	# date:    2005-07-30
	# editor:  sundaram@tigr.org
	# spec:    bgzcase 2006
	# purpose: The proteinLocalization.pl script should increment the rank value for alternative isoforms being localized
	#          to the assembly.  This will satisfy the featureloc unique key constraint on feature_id, locgroup, rank.
	#
	#-----------------------------------------------------------------------------------------------------------------------
	my $key = $element->{'pfeature_id'} . '_' . $element->{'locgroup'} . '_' . $element->{'rank'};
	if (!exists $uc->{$key} ) {
	    $uc->{$key}++;
	}
	else{
	    #
	    # Assign the next rank value to the current featureloc record, simultaneously increment the rank by one
	    #
	    $x[10] = $uc->{$key}++;
	}


	#
	# Increment featureloc_id
	#
	$max_id++;


	#
	# Remove 'NULL' strings from all featureloc fields
	#
	for (my $i=0;$i<11;$i++){
	    if ($x[$i] eq 'NULL'){
		$x[$i] =~ s/NULL//;
	    }
	} 
	

	#
	# We only want to localize protein-assembly pairs once.
	#
	# comment: The intention of this code was to ensure that proteins which were already localized to
	#          some assembly were not processed and localized a second time to the same assembly.
	#
	if ($lookup->{$x[0]} == $x[1]){
	    $logger->info("protein:$x[0] was previously localized to assembly:$x[1]");
	    next;
	}
	else{
	    print OUTFILE $max_id .$tab . join($tab, @x) . $record;
	}

    }

    close OUTFILE;

}#end sub build_protein_localization_rows()


#--------------------------------------------------------
# retrieve_max_featureloc_id()
#
#
#--------------------------------------------------------
sub retrieve_max_featureloc_id {

    my $logger = Coati::Logger::get_logger("protein");
    $logger->info("Entered retrieve_max_featureloc_id") if $logger->is_info();

    my ($reader) = @_;
    $logger->logdie("reader was not defined") if (!defined($reader));

    my $table = "featureloc";
    my $key   = "featureloc_id";
    my $max_id = $reader->max_table_id($table, $key);
    $logger->logdie("max_id was not defined") if (!defined($max_id));

    return \$max_id;

}#end sub is_stored_procedure_valid()


#--------------------------------------------------------
# retrieve_protein_contig_rows()
#
#
#--------------------------------------------------------
sub retrieve_protein_contig_rows {

    my $logger = Coati::Logger::get_logger("protein");
    $logger->info("Entered retrieve_protein_contig_rows");

    my ($reader) = @_;
    $logger->logdie("reader was not defined") if (!defined($reader));
    
    my $localizations = $reader->protein_2_contig_localization();
    $logger->logdie("localizations was not defined") if (!defined($localizations));

    return $localizations;

}#end sub is_stored_procedure_valid()

#--------------------------------------------------------
# load_protein_localizations()
#
#
#--------------------------------------------------------
sub load_protein_localizations {

    my $logger = Coati::Logger::get_logger("protein");
    $logger->info("Entered load_protein_localizations");

    my %parameter = @_;
    my $parameter_hash = \%parameter;
    my ($username, $password, $database, $server);

    #
    # Extract arguments from parameter hash
    #
    if (exists $parameter_hash->{'username'}){
	$username = $parameter_hash->{'username'};
    }
    if (exists $parameter_hash->{'password'}){
	$password = $parameter_hash->{'password'};
    }
    if (exists $parameter_hash->{'database'}){
	$database = $parameter_hash->{'database'};
    }
    if (exists $parameter_hash->{'server'}){
	$server = $parameter_hash->{'server'};
    }

    #
    # Verify whether arguments were defined
    #
    $logger->logdie("username was not defined") if (!defined($username));
    $logger->logdie("password was not defined") if (!defined($password));
    $logger->logdie("database was not defined") if (!defined($database));
    $logger->logdie("server was not defined")   if (!defined($server));
    
    my $load = $loader . " -U " . $$username . " -P " . $$password  ." -S " . $$server . " -D " . $$database . " -b in -l " . $$outdir ."/protein_localization.load.log -d " . $$outdir ." > " . $$outdir ."/protein_localization.load.stats";

    if (&is_execution_string_safe(\$load)){
	$logger->info("Executing: $load");
	my $status = qx($load);
    }
    else{
	$logger->fatal("Execution string was deemed un-safe: $load");
    }
    
}#end sub load_protein_localizations()

#-----------------------------------------------------------------
# is_execution_string_safe()
#
#-----------------------------------------------------------------
sub is_execution_string_safe {

    my $logger = Coati::Logger::get_logger("batch");
    $logger->info("Entered is_execution_string_safe");

    my $string = shift;

    if (!defined($string)){
        $logger->fatal("string was not defined");
        return 0;
    }
    if ($$string =~ /rm/){
        $logger->fatal("string was not safe: $$string");
        return 0;
    }

    return 1;

}#end sub is_execution_string_safe()





#-----------------------------------------------------------------
# print_usage()
#
#-----------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -U username -P password -D database -S server [-d debug_level] [-l logfile] [-h] [-m] [-o outdir] [-v]\n";
    print STDERR "  -U|--username            = Database login username\n";
    print STDERR "  -P|--password            = Database login password\n";
    print STDERR "  -S|--server              = Server name\n";
    print STDERR "  -D|--database            = Database\n";
    print STDERR "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level.  Default is 0\n";    
    print STDERR "  -l|--logfile             = Optional - Log4perl log file.  Default is /tmp/proteinLocalization.pl.log\n"; 
    print STDERR "  -h|--help                = This help message\n";
    print STDERR "  -m|--man                 = Display man pages for this script\n";
    print STDERR "  -o|--outdir              = Optional - output directory for the featureloc.out file.  Default is current working directory\n";
    exit 1;

}

