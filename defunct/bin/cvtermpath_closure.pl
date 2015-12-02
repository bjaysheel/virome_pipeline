#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

cvtermpath_closure.pl - 

=head1 SYNOPSIS

USAGE:  cvtermpath_closure.pl --cv_id --database --database_type [--debug_level] [-h] [--logfile] [-m] [--outdir] --password --server --username

=head1 OPTIONS

=over 8

=item B<--cv_id>
    
    cv.cv_id of ontology to be processed

=item B<--database>
    
    name of chado database

=item B<--database_type>
    
    relational database management system type e.g. sybase or postgresql

=item B<--debug_level,-d>

    Optional - Coati::Logger Log4perl logging level.  Default is 0

=item B<--help,-h>

    Print this help

=item B<--logfile>

    Optional - log file (default is /tmp/cvtermpath_closure.pl.log)

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--outdir>

    Optional - output directory to write BCP file to be loaded into chado cvtermpath table (default is current working directory)

=item B<--password>
    
    password for the username account

=item B<--server>
    
    name of the server on which the chado database resides

=item B<--username>
    
    username account to access the chado database


=back

=head1 DESCRIPTION

    cvtermpath_closure.pl - Will calcuate transitive closure based on inherited cvterm_relationships
    Out file to be produced:
    cvtermpath.out

    Each file will contain new records to be inserted via the BCP utility into a chado database. (Use the loadSybaseChadoTables.pl script to complete this task.)
    Typical actions:
    1) Parse OBO file (execute Calculate_Cvtermpath.pl)
    2) Replace Coati::IdManager placeholder variables (execute replace_placeholders.pl)
    3) Validate master tab delimited .out files (execute any number of validate_*.pl utilities)
    4) Load the master tab delimited files into the target Chado database (execute loadSybaseChadoTables.pl)

    Assumptions:
    1. User has appropriate permissions (to execute script, access chado database, write to output directory).
    2. Target chado database already contains all reference features (necessary to build feature and organism lookups) Review and execute db2bsml.pl if required.
    3. Target chado database contains the necessary controlled vocabulary terms: "match" etc.
    4. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    perl -I shared/ -I Prism/ cvtermpath_closure.pl --username sundaram --password sundaram7 --database clostridium --cv_id 13 --logfile outdir/log --outdir=outdir --server SYBTIGR --database_type sybase

=cut


use strict;

use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Coati::Logger;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($cv_id, $database, $database_type, $debug_level, $help, $logfile,
    $man, $outdir, $password, $server, $username);


my $results = GetOptions (
			  'cv_id=s'             => \$cv_id,
			  'database=s'          => \$database,
			  'database_type=s'     => \$database_type,
			  'debug_level=s'       => \$debug_level,
			  'help|h'              => \$help,
			  'logfile=s'           => \$logfile,
			  'man|m'               => \$man,
			  'outdir|o=s'          => \$outdir,
			  'password|P=s'        => \$password,
			  'server=s'            => \$server,
			  'username|U=s'        => \$username
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

my $fatalCtr=0;

if (!defined($cv_id)){
    print STDERR ("cv_id was not defined\n");
    $fatalCtr++;
}
if (!defined($database)){
    print STDERR ("database was not defined\n");
    $fatalCtr++;
}
if (!defined($database_type)){
    print STDERR ("database_type was not defined\n");
    $fatalCtr++;
}
if (!defined($password)){
    print STDERR ("password was not defined\n");
    $fatalCtr++;
}
if (!defined($server)){
    print STDERR ("server was not defined\n");
    $fatalCtr++;
}
if (!defined($username)){
    print STDERR ("username was not defined\n");
    $fatalCtr++;
}

if ($fatalCtr > 0 ){
    &print_usage();
}

## initialize the logger
$logfile = "/tmp/cvtermpath_closure.pl.log" if (!defined($logfile));

my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


##verify and set the output directory
$outdir = &verify_and_set_outdir($outdir);


## Use class method to verify the database vendor type
if (! Prism::verifyDatabaseType($database_type)){
    $logger->logdie("Unsupported database type '$database_type'");
}

## Set the PRISM env var
&setPrismEnv($server, $database_type);

## Instantiate Prism object
my $prism = &retrieve_prism_object($username, $password, $database);

my $cvIdArray = [];

if (defined($cv_id)){
    ## cv_id was specified by the user
    if ($cv_id =~ /^\d+$/){
	## the cv_id is a numeric value

	push(@{$cvIdArray}, $cv_id);
    }
    else{
	$logger->fatal("cv_id was not a numeric value.  ".
		       "Please review usage.");
	&print_usage();
    }
}
else{
    ## retrieve all cv.cv_id values from the chado database
    $cvIdArray = $prism->cvIdList();
}

my $cvtermRelationshipSubjectToObjectLookup = {};

## This will help ensure that only unique records are produced and 
## inserted regardless number of times this script is executed 
## against the same chado database
$prism->generateCvtermPathIdCachedLookup();


foreach my $cvId (@{$cvIdArray}){
    
    print "Processing cv_id '$cv_id'\n";

    my $cvtermIdList = $prism->cvtermIdListByCvId($cvId);


    ## retrieve all cvterm_relationship rows
    $cvtermRelationshipSubjectToObjectLookup = $prism->cvtermRelationshipLookupsByCvId($cvId);

    ## we'll capture 
    my $cvtermpathLookup = {};
    
    foreach my $cvterm_id ( @{$cvtermIdList} ) {

	&ascendCvtermRelationshipTree($cvtermpathLookup,
				      $cvterm_id,
				      $cvtermRelationshipSubjectToObjectLookup->{$cvterm_id},
				      0
				      );
    }

    $prism->storeCvtermPathRecords($cvtermpathLookup, $cvId);
}


## write to the tab delimited .out files
&write_to_outfiles($prism, $outdir);

## Notify of completion
print "$0 program execution completed\n";
print "Tab delimited BCP file has been written to directory '$outdir'\n";
print "The log file is '$logfile'\n";

exit(0);


#---------------------------------------------------------------------------------------------------------------------
#
#                                  END OF MAIN  -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------------------------------------




##-----------------------------------------------------
## ascendCvtermRelationshipTree()
##
##-----------------------------------------------------
sub ascendCvtermRelationshipTree {

    my ($cvtermpathLookup, $subject_id, $parentLookups, $pathdistance) = @_;

    ## increment the distance by 1
    $pathdistance++;

    ## parentLookup is an array of arrays
    ## the first element of the array contains the object_id
    ## the second element of the array contains the type_id
    ##
    foreach my $parentLookup ( @{$parentLookups} ){

	my $object_id = $parentLookup->[0];

	if (! exists $cvtermpathLookup->{$subject_id}->{$object_id}){

	    my $type_id = $parentLookup->[1];

	    $cvtermpathLookup->{$subject_id}->{$object_id} = [ $parentLookup->[1], # type_id
							       $pathdistance ];
	}

	&ascendCvtermRelationshipTree($cvtermpathLookup, 
				      $subject_id, 
				      $cvtermRelationshipSubjectToObjectLookup->{$object_id},
				      $pathdistance);
    }
}


#--------------------------------------------------------
# verify_and_set_outdir()
#
#
#--------------------------------------------------------
sub verify_and_set_outdir {

    my ( $outdir) = @_;

    $logger->debug("Verifying and setting output directory") if ($logger->is_debug());

    #
    # strip trailing forward slashes
    #
    $outdir =~ s/\/+$//;
    
    #
    # set to current directory if not defined
    #
    if (!defined($outdir)){
	if (!defined($ENV{'OUTPUT_DIR'})){
	    $outdir = "." 
	}
	else{
	    $outdir = $ENV{'OUTPUT_DIR'};
	}
    }

    #
    # verify whether outdir is in fact a directory
    #
    $logger->fatal("$outdir is not a directory") if (!-d $outdir);

    #
    # verify whether outdir has write permissions
    #
    $logger->fatal("$outdir does not have write permissions") if ((-e $outdir) and (!-w $outdir));


    $logger->debug("outdir is set to:$outdir") if ($logger->is_debug());

    #
    # store the outdir in the environment variable
    #
    $ENV{OUTPUT_DIR} = $outdir;
    
    return $outdir;

}#end sub verify_and_set_outdir()

#----------------------------------------------------------------
# retrieve_prism_object()
#
#
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database) = @_;

    $logger->debug("Instantiating Prism object") if ($logger->is_debug());
    

    my $prism = new Prism( 
			   user             => $username,
			   password         => $password,
			   db               => $database,
			   );
    
    $logger->fatal("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    

    return $prism;


}#end sub retrieve_prism_object()


#--------------------------------------------------------------
# write_to_outfiles() 
#
#
#--------------------------------------------------------------
sub write_to_outfiles {

    my ( $writer,$outdir) = @_;

    $logger->debug("Entered write_to_outfiles") if ($logger->is_debug());

    $logger->fatal("writer was not defined") if (!defined($writer));

    #
    # Output the datasets to file and/or batch load into database 
    #

    $logger->info("Writing tab delimited .out files to directory: $outdir");

    $writer->{_backend}->output_tables("$outdir/");

}#end sub write_to_outfiles()



#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 --cv_id --database --database_type [--debug_level] [-h] [--logfile] [-m] [--outdir] --password --server --username\n".
    "  --cv_id               = cv.cv_id for the ontology to be processed \n".
    "  --database            = name of the chado database\n".
    "  --database_type       = relational database management system type e.g. sybase or postgresql\n".
    "  -d|--debug_level      = Optional - Coati::Logger Log4perl logging level (default level is 0)\n".
    "  -h|--help             = Optional - Display pod2usage help screen.\n".
    "  --logfile             = Optional - Log4perl log file (default is /tmp/cvtermpath_closure.pl.log)\n".
    "  -m|--man              = Optional - Display pod2usage pages for this utility\n".
    "  --outdir              = Optional - Output directory to which the BCP file to be loaded into chado table cvtermpath will be written (default is current directory)\n";    
    "  --password            = password for the username account to access the chado database\n".
    "  --server              = name of server on which the database resides\n".
    "  --username            = username account for accessing the chado database\n".

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

