#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#-----------------------------------------------------------------------
# program:   validateRelationships.pl
# author:    Jay Sundaram
# date:      2004/03/24
# 
# purpose:   Scans feature_relationship table and cross-references against
#            cvterm_relationship inorder to validate that the relationships
#            are preserved across the two tables
#
#-------------------------------------------------------------------------


=head1 NAME

    validateRelationships.pl - Scans feature_relationship table and cross-references against cvterm_relationship inorder to validate that the relationships are preserved across the two tables

=head1 SYNOPSIS

USAGE:  validateRelationships.pl -U username -P password -D database [-l log4perl] [-d debug_level] [-h] [-m]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--database,-D>
    
    Target chado database 

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--help,-h>

    Print this help

=back

=head1 DESCRIPTION

    validateRelationships.pl - Scans feature_relationship table and cross-references against cvterm_relationship inorder to validate that the relationships are preserved across the two tables

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

my ($username, $password, $database,  $debug_level, $help, $log4perl, $man);


my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'database|D=s'        => \$database,
			  'log4perl|l=s'        => \$log4perl,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("username was not defined\n")   if (!$username); 
print STDERR ("password was not defined\n")   if (!$password);
print STDERR ("database was not defined\n")   if (!$database);


&print_usage if(!$username or !$password or !$database);

#
# initialize the logger
#
$log4perl = "/tmp/validateRelationships.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

#
# Instantiate Prism object
#
my $prism = &retrieve_prism_object($username, $password, $database);


#
# Check record counts
#
my $fr_count = $prism->table_record_count("feature_relationship");
my $cr_count = $prism->table_record_count("cvterm_relationship");

if ($fr_count < 1){
    print STDERR "Table $database..feature_relationship had no records\n\n";
    exit(1);
}
if ($cr_count < 1){
    print STDERR "Record count for table $database..feature_relationship was '$fr_count', however $database..cvterm_relationship had no records.  Unable to validate relationships\n\n";
    exit(1);
}
    

#
# Retrieve lookup1 (feature_relationship)
#
my ($lookup1, $fcount) = &retrieve_feature_relationship($prism);
#print Dumper $lookup1;

#
# Retrieve lookup2 (cvterm_relationship)
#
my ($lookup2, $ccount) = &retrieve_cvterm_relationship($prism);
#print Dumper $lookup2;

#
# Perform validation
#
&validate_relationships($lookup1, $lookup2, $fcount, $ccount);

#
# Notify of completion
#
print STDERR "\nPlease verify log4perl log file: $log4perl\n";


#---------------------------------------------------------------------------------------------------------------------
#
#                                  END OF MAIN  -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------------------------------------

#------------------------------------------------------
# validate_relationships()
#
#------------------------------------------------------
sub validate_relationships {
    
    my ($lookup1, $lookup2, $fcount, $ccount) = @_;

    my $cleanup = {};

    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = $fcount;
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);

    foreach my $key (sort keys %$lookup1){


	$row_count++;
	$prism->show_progress("Verifying relationships $row_count/$total_rows",$counter,$row_count,$bars,$total_rows);
	

	my $string = $lookup1->{$key}->{'string'};
	
	if (!exists $lookup2->{$string}){
	    $logger->error("string '$string' was not in cvterm_relationship lookup\n".
			   "feature_relationship_id '$lookup1->{$key}'\n".
			   "subject's name '$lookup1->{$key}->{'sc_name'}'  subject_id '$lookup1->{$key}->{'subject_id'}'\n".
			   "object's name '$lookup1->{$key}->{'oc_name'}' object_id '$lookup1->{$key}->{'object_id'}'\n".
			   "type's name '$lookup1->{$key}->{'c_name'}' type_id '$lookup1->{$key}->{'type_id'}'\n");
#	    $cleanup->{$key} = $lookup1->{$key};
#	    $lookup1->{$key} = undef;
	}
    }


}

#------------------------------------------------------
# retrieve_feature_relationship()
#
#------------------------------------------------------
sub retrieve_feature_relationship {

    my $prism = shift;

    $logger->debug("Entered retrieve_feature_relationship") if $logger->is_debug;

    print "Executing SQL query in order to retrieve feature_relationship data from database...\n";
    my $ref = $prism->feature_relationship_lookup();

    $logger->logdie("ref was not defined") if (!defined($ref));

    my $lookup = {};
    my $feature_relationship_types = {};



    
    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = scalar(@$ref);
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);
    

   for(my $j=0;$j<scalar(@$ref);$j++){
  

       $row_count++;
       $prism->show_progress("Building feature_relationship lookup $row_count/$total_rows",$counter,$row_count,$bars,$total_rows);


       my $feature_relationship_id = $ref->[$j]->{'feature_relationship_id'};

       $lookup->{$feature_relationship_id}->{'subject_id'}  = $ref->[$j]->{'subject_id'};
       $lookup->{$feature_relationship_id}->{'object_id'}   = $ref->[$j]->{'object_id'};
       $lookup->{$feature_relationship_id}->{'type_id'}     = $ref->[$j]->{'type_id'};
       $lookup->{$feature_relationship_id}->{'c_name'}      = $ref->[$j]->{'c_name'};
       $lookup->{$feature_relationship_id}->{'s_type_id'}   = $ref->[$j]->{'s_type_id'};
       $lookup->{$feature_relationship_id}->{'sc_name'}     = $ref->[$j]->{'sc_name'};
       $lookup->{$feature_relationship_id}->{'o_type_id'}   = $ref->[$j]->{'o_type_id'};
       $lookup->{$feature_relationship_id}->{'oc_name'}     = $ref->[$j]->{'oc_name'};

       $lookup->{$feature_relationship_id}->{'string'}      = $ref->[$j]->{'s_type_id'} . '_' . $ref->[$j]->{'o_type_id'} . '_' . $ref->[$j]->{'type_id'};
       
       
       $feature_relationship_types->{$ref->[$j]->{'c_name'}}++;

    }
    
    foreach my $key (sort keys %$feature_relationship_types){
	
	my $val = $feature_relationship_types->{$key};
	$logger->info("feature_relationship type '$key' occurred '$val'");
    }


    $logger->debug("Returning fully built feature_relationship_lookup with '$row_count' relationships") if $logger->is_debug;

    return $lookup, $row_count;

}#end sub retrieve_feature_relationship()

#------------------------------------------------------
# retrieve_cvterm_relationship()
#
#------------------------------------------------------
sub retrieve_cvterm_relationship {

    my $prism = shift;

    $logger->debug("Entered retrieve_cvterm_relationship") if $logger->is_debug;

    my $ref = $prism->cvterm_relationship_lookup();

    $logger->logdie("ref was not defined") if (!defined($ref));

    my $lookup = {};
    my $cvterm_relationship_types = {};


    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = scalar(@$ref);
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);


    for(my $j=0;$j<scalar(@$ref);$j++){


	$row_count++;
	$prism->show_progress("Building cvterm_relationship lookup $row_count/$total_rows",$counter,$row_count,$bars,$total_rows);

	
	my $string = $ref->[$j]->{'subject_id'} . '_' . $ref->[$j]->{'object_id'} . '_' . $ref->[$j]->{'type_id'};
	
	if (!exists ($lookup->{$string})){
	    
	    $lookup->{$string}->{'cvterm_relationship_id'} = $ref->[$j]->{'cvterm_relationship_id'};
	    $lookup->{$string}->{'subject_id'}             = $ref->[$j]->{'subject_id'};
	    $lookup->{$string}->{'object_id'}              = $ref->[$j]->{'object_id'};
	    $lookup->{$string}->{'type_id'}                = $ref->[$j]->{'type_id'};
	    $lookup->{$string}->{'cs_name'}                = $ref->[$j]->{'cs_name'};
	    $lookup->{$string}->{'co_name'}                = $ref->[$j]->{'co_name'};
	    $lookup->{$string}->{'c_name'}                 = $ref->[$j]->{'c_name'};
	    
	    
	    $cvterm_relationship_types->{$ref->[$j]->{'c_name'}}++;
	}
	else{
	    $logger->error("string '$string' occurred more than once at record '$j' cvterm_relationship_id '$ref->[$j]->{'cvterm_relationship_id'}'");
	}
	
	
    }
    
    
    foreach my $key (sort keys %$cvterm_relationship_types){
	
	my $val = $cvterm_relationship_types->{$key};
	$logger->info("cvterm_relationship type '$key' occurred '$val'");
	
    }
    
    
    $logger->debug("Returning fully built cvterm_relationship_lookup with '$row_count' relationships") if $logger->is_debug;
    return $lookup, $row_count;

}#end sub retrieve_cvterm_relationship()


#------------------------------------------------------
# show_count()
#
#------------------------------------------------------
sub show_count{
    
    $logger->info("Entered show_count");

    my $string = shift;
    $logger->logdie("string was not defined") if (!defined($string));

    print "\b"x(50);
    printf "%-50s", $string;

}#end sub show_count()

#----------------------------------------------------------------
# retrieve_prism_object()
#
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

    print STDERR "SAMPLE USAGE:  $0 -U username -P password -D database [-l log4perl] [-d debug_level] [-h] [-m]\n";
    print STDERR "  -U|--username            = Username\n";
    print STDERR "  -P|--password            = Password\n";
    print STDERR "  -D|--database            = Target chado database\n";
    print STDERR "  -l|--log4perl            = Optional - Log4perl log file (default: /tmp/validateRelationships.pl.log)\n";
    print STDERR "  -m|--man                 = Display pod2usage pages for this utility\n";
    print STDERR "  -h|--help                = Display pod2usage help screen.\n";
    print STDERR "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level (default level is 0)\n";    
    exit 1;

}
