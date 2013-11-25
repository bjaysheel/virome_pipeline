#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#-----------------------------------------------------------------------
# program:   compare_cvterm_relationships.pl
# author:    Jay Sundaram
# date:      2005/06/23
# 
# purpose:   Scans cv,cvterm,cvterm_relationship in two chado databases
#            and performs comparisons.
#
#
#-------------------------------------------------------------------------


=head1 NAME

    compare_cvterm_relationships.pl - Scans cv, cvterm, cvterm_relationship tables in two chado databases and performs comparisons

=head1 SYNOPSIS

USAGE:  compare_cvterm_relationships.pl -U username -P password -D database1 -E database2 [-l log4perl] [-d debug_level] [-h] [-m] -o ontology

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--database1,-D>
    
    Chado database 1

=item B<--database2,-E>
    
    Chado database 2

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--ontology,-o>

    Name (default-namespace) for ontology being examined. E.g. SO for sequence ontology (cv.name)

=item B<--help,-h>

    Print this help

=back

=head1 DESCRIPTION

    compare_cvterm_relationships.pl - Scans cv, cvterm, cvterm_relationship tables in two chado databases and performs comparisons

    Assumptions:
    1. User has appropriate permissions (to execute script, access chado database, write to output directory).
    2. Target chado database already contains all reference features (necessary to build feature and organism lookups) Review and execute db2bsml.pl if required.
    3. Target chado database contains the necessary controlled vocabulary terms: "match" etc.
    4. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./validateRelationships.pl -U access -P access -D tryp -l my.log


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

my ($username, $password, $database1,  $database2, $debug_level, $help, $log4perl, $man, $ontology);


my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'database1|D=s'       => \$database1,
			  'database2|E=s'       => \$database2,
			  'log4perl|l=s'        => \$log4perl,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'ontology|o=s'        => \$ontology
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("username was not defined\n")   if (!$username); 
print STDERR ("password was not defined\n")   if (!$password);
print STDERR ("database1 was not defined\n")   if (!$database1);
print STDERR ("database2 was not defined\n")   if (!$database2);
print STDERR ("ontology was not defined\n")   if (!$ontology);


&print_usage if(!$username or !$password or !$database1 or !$database2 or !$ontology);

#
# initialize the logger
#
$log4perl = "/tmp/compare_cvterm_relationship.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


my $cr = {};
my $prism2 = &retrieve_prism_object($username, $password, $database1);

foreach my $database ($database1, $database2){

    my $prism = &retrieve_prism_object($username, $password, $database);
    
    my $cv_id = $prism->cv_id_from_cv(name=>$ontology);
    $logger->logdie("cv_id was not defined for ontology '$ontology'") if ((!defined($cv_id)) or ($cv_id == 0));
    $cr->{$database} = &build_cvterm_relationship_hash($prism, $cv_id, $database, $ontology);

}

#-----------------------------------------------------------------------
# bi-directional comparison: 
# is record A from database 1 in database 2 ?
# is record B from database 2 in database 1 ?
#
#-----------------------------------------------------------------------
&compare_database_ontologies_relationships($prism2, $database1, $database2, $cr);
&compare_database_ontologies_relationships($prism2, $database2, $database1, $cr);

#
# Notify of completion
#
print STDOUT "\n$0 execution completed.  Please verify log4perl log file: $log4perl\n";



#---------------------------------------------------------------------------------------------------------------------
#
#                                  END OF MAIN  -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------------------------------------


#------------------------------------------------------
# compare_database_ontologies_relationships()
#
#------------------------------------------------------
sub compare_database_ontologies_relationships {

    my ($prism, $db1, $db2, $cr) = @_;

    my @keys = keys %{$cr->{$db1}};


    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = scalar(@keys);
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);

    print("\nComparing (authoritative database) '$db1' against '$db2'\n");

    foreach my $tuple ( @keys ){
	
	$row_count++;
	$prism->show_progress("$row_count/$total_rows",$counter,$row_count,$bars,$total_rows);


	if ((exists $cr->{$db2}->{$tuple}) && (defined($cr->{$db2}->{$tuple}))){
	    # fine
	}
	else{
	    $tuple =~ s/\|\|\|/ /g;
	    $logger->fatal("tuple '$tuple' was in database1 '$db1' but not in database2 '$db2'");
	}
	
    }
}

#------------------------------------------------------
# build_cvterm_relationship_hash()
#
#------------------------------------------------------
sub build_cvterm_relationship_hash {

    my ($prism, $cv_id, $database, $ontology) = @_;

    my $ret = $prism->cvterm_relationships($cv_id);
    
    my $lookup = {};


    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = scalar(@{$ret});
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);


    print("\nBuilding cvterm_relationship lookup for database '$database' ontology '$ontology'\n");

    my $i;

    for ($i=0; $i < scalar(@{$ret}); $i++){

	$row_count++;
	$prism->show_progress("$row_count/$total_rows",$counter,$row_count,$bars,$total_rows);



	my $tuple = $ret->[$i][0] . '|||' . $ret->[$i][2] . '|||' . $ret->[$i][1];
	if (!exists $lookup->{$tuple}){
	    $lookup->{$tuple} = $i;
	}
	else{
	    $logger->logdie("Duplicate record found '$tuple' at cvterm_relationship record number '$i'");
	}
    }

    $logger->info("database '$database' had '$i' cvterm_relationship");

    return $lookup;
}


#----------------------------------------------------------------
# retrieve_prism_object()
#
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database, $pparse) = @_;

    $logger->debug("Instantiating Prism object") if ($logger->is_debug());
    
    if (defined($pparse)){
	$pparse = 1;
    }
    else{
	$pparse = 0;
    }
    

    my $prism = new Prism( 
			   user             => $username,
			   password         => $password,
			   db               => $database,
			   use_placeholders => $pparse,
			   );
    
    $logger->fatal("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    

    return $prism;


}#end sub retrieve_prism_object()


#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {
    
    print STDERR "SAMPLE USAGE:  $0 -U username -P password -D database1 -E database2 [-l log4perl] [-d debug_level] [-h] [-m] -o ontology\n".
    "  -U|--username            = Username\n".
    "  -P|--password            = Password\n".
    "  -D|--database1           = Chado database 1\n".
    "  -E|--database2           = Chado database 2\n".
    "  -l|--log4perl            = Optional - Log4perl log file (default: /tmp/validateRelationships.pl.log)\n".
    "  -m|--man                 = Display pod2usage pages for this utility\n".
    "  -o|--ontology            = Name (default-namespace) for the ontology\n".
    "  -h|--help                = Display pod2usage help screen.\n".
    "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level (default level is 0)\n";   
    exit 1;

}
