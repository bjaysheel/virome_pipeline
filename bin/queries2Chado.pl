#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#-----------------------------------------------------------------------
# program:   queries2Chado.pl
# author:    Jay Sundaram
# date:      2004/04/14
# 
# editor:   sundaram@tigr.org
# date:     2005-10-08
# bgzcase:  2146
# URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2146
# comment:  The new relationship.obo introduces typedef relationship 'derives_from'.
#           This will replace all occurences of 'derived_from'.
#
#-------------------------------------------------------------------------


=head1 NAME

queries2Chado.pl - Migrates BSML search/compute documents to the chado companalysis module

=head1 SYNOPSIS

USAGE:  queries2Chado.pl -U username -P password -D database --database_type --server [-l log4perl] [-c cache_dir] [-d debug_level] [-m] [-o ontology] [--setreadonly] [-t type] [-u update]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--database,-D>
    
    Database to be affected

=item B<--database_type>
    
    Relational database management system type e.g. sybase or postgresql

=item B<--server>
    
    Name of server on which the database resides

=item B<--cache_dir,-c>
    
    Optional - Directory to write cache files.  Default is value stored in environmental variable DBCACHE_DIR

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--ontology,-o>

    Optional - To specify caching ontology queries --ontology=1 (Default is bsml2chado standard querry caching --ontology=0)

=item B<--help,-h>

    Print this help

=item B<--setreadonly>

    Optional - To set read-only permissions on the cache files --setreadonly=1 (Default is read-write permissions --setreadonly=0)

=item B<--type,-t>

    sequence/feature type to base all queries.  Default is 'assembly'

=item B<--update,-u>

    -u=1 means update mode

=back

=head1 DESCRIPTION

    queries2Chado.pl - Cache query results to file

    Assumptions:
    1. The BSML pairwise alignment encoding should validate against the XML schema:.
    2. User has appropriate permissions (to execute script, access chado database, write to output directory).
    3. Target chado database already contains all reference features (necessary to build feature and organism lookups) Review and execute db2bsml.pl if required.
    4. Target chado database contains the necessary controlled vocabulary terms: "match" etc.
    5. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./queries2Chado.pl -U access -P access -D tryp


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

my ($username, $password, $cache_dir, $database, $database_type, $server, $debug_level, $help, $log4perl, $man, $update, $type, $ontology, $setreadonly);


my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'cache_dir|c=s'       => \$cache_dir,
			  'database|D=s'        => \$database,
			  'database_type=s'     => \$database_type,
			  'server|S=s'	    => \$server,
			  'log4perl|l=s'        => \$log4perl,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'ontology|o=s'        => \$ontology,
			  'update|u=s'          => \$update,
			  'type|t=s'            => \$type,
			  'setreadonly=s'       => \$setreadonly

			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

my $fatalCtr=0;
$fatalCtr += &checkParameter('username', $username);
$fatalCtr += &checkParameter('password', $password);
$fatalCtr += &checkParameter('database', $database);
$fatalCtr += &checkParameter('database_type', $database_type);
$fatalCtr += &checkParameter('server', $server);

if ($fatalCtr>0){
    &print_usage();
}

#
# initialize the logger
#
$log4perl = "/tmp/queries2Chado.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

## Set the PRISM env var
&setPrismEnv($server, $database_type);

if (defined($ontology)){
    if (($ontology == 0 ) or ($ontology == 1)){
	# fine.
	$logger->debug("ontology was set to '$ontology' by user '$username'") if $logger->is_debug();
    }
    else{
	$logger->logdie("ontology '$ontology' value must be 0 or 1");
    }
}
else{
    $ontology = 0;
}



if (defined($cache_dir)){

    $ENV{DBCACHE} = "file"; 

    if (-e $cache_dir){
	if (-w $cache_dir){
	    if (-r $cache_dir){
		$ENV{DBCACHE_DIR} = $cache_dir;
		$logger->info("setting cache_dir to $ENV{DBCACHE_DIR}");
	    }
	    else{
		$logger->warn("cache_dir '$cache_dir' is not writeable.  Using default $ENV{DBCACHE_DIR}");
	    }
	}
	else{
	    $logger->warn("cache_dir '$cache_dir' is not readable.  Using default $ENV{DBCACHE_DIR}");
	}
    }
    else{
	$logger->warn("cache_dir '$cache_dir' does not exist.  Using default $ENV{DBCACHE_DIR}");
    }

    if ((defined ($setreadonly)) &&
	($setreadonly == 1)){
	
	$ENV{_SET_READONLY_CACHE} = 1;

    }

}


#
# Instantiate Prism object
#
my $prism = &retrieve_prism_object($username, $password, $database);

if ((defined($update)) and ($update == 1)){
    if (!defined($type)){
	$type = 'assembly';
	$logger->info("update mode is ON, however type was not defined and therefore was set to '$type'");
    }
}


#----------------------------------------------------------------
# The following table lookup generating Prism API methods will
# be executed regardless whether loading ontologies, gene
# models, annotation, new computes


&execute_general_module_lookup_queries($prism);
&execute_cv_module_lookup_queries($prism);
&execute_other_lookup_queries($prism);
&select_max_id($prism);

if ((defined($ontology)) && ($ontology == 1)){
    
    &execute_ontology_lookup_queries($prism);
}
else {

    &execute_organism_module_lookup_queries($prism);
    &execute_pub_module_lookup_queries($prism);
    &execute_sequence_module_lookup_queries($prism);
    &execute_computational_analysis_module_lookup_queries($prism);
    &execute_phylogeny_module_lookup_queries($prism);
    &execute_bsml2bsml_lookup_queries($prism);

}


#---------------------------------------------------------------------------------------------------------------------
#
#                                  END OF MAIN  -- SUBROUTINES FOLLOW
#
#--------------------------------------------------------------------------------------------------------------------- 
   
#-------------------------------------------------------------------
# select_max_id()
#
#-------------------------------------------------------------------
sub select_max_id  {
    
    $logger->debug("") if $logger->is_debug();

    my $prism = shift;

    my $tablelist = $prism->chadoCoreTableCommitOrder();
    my @list = split(/,/,$tablelist);

    foreach my $table (sort @list){

	my $id = $table . '_id';

	$prism->max_table_id($table, $id);

    }
}
   
#-------------------------------------------------------------------
# get_file_contents()
#
#-------------------------------------------------------------------
sub get_file_contents {

    $logger->debug("Entered get_file_contents") if $logger->is_debug();

    my $file = shift;
    $logger->logdie("file was not defined") if (!defined($file));

    if (&check_file_status($file)){

	open (IN_FILE, "<$file") || $logger->logdie("Could not open file: $file for input");
	my @contents = <IN_FILE>;
	chomp @contents;
	
	return \@contents;

    }
    else{
	$logger->logdie("file $file does not have appropriate permissions");
    }
    
}#end sub get_contents()


#----------------------------------------------------------------
#  parse_comma_separated_list()
#
#----------------------------------------------------------------
sub parse_comma_separated_list {

    my $algo = shift;
    return $algo if (uc($algo) eq 'NONE');
    my @list = split(/,/,$algo);
    return \@list;
   

}

#------------------------------------------------------
#  check_file_status()
#
#------------------------------------------------------
sub check_file_status {

    $logger->info("Entered check_file_status");

    my $file = shift;

    if (!defined($file)){
	$logger->logdie("$file was not defined");
	return 0;
    }

    if (!-e $file){
	$logger->logdie("$file does not exist");
	return 0;
    }

    if ((-e $file) and (!-r $file)){
	$logger->logdie("$file does not have read permissions");
	return 0;
    }


    return 1;

}#end sub check_file_status()

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
			   use_placeholders => 0,
			   );
    
    $logger->fatal("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    

    return $prism;


}

sub execute_cv_module_lookup_queries {


    my $prism = shift;


    $prism->cv_id_lookup();
    
    $prism->cvterm_id_lookup();
    
    $prism->cvterm_relationship_id_lookup();
    
#    $prism->cvtermpath_id_lookup();
    
    $prism->cvtermsynonym_id_lookup();
    
    $prism->cvterm_dbxref_id_lookup();
  
    $prism->cvtermprop_id_lookup();

    $prism->dbxrefprop_id_lookup();

}

sub execute_general_module_lookup_queries {

    my $prism = shift;

    $prism->db_id_lookup();
    
    $prism->dbxref_id_lookup();

}
    
sub execute_other_lookup_queries {

    my $prism = shift;

    $prism->cvterm_id_by_name_lookup();

}

sub execute_ontology_lookup_queries {

    my $prism = shift;

    $prism->typedef_lookup();
    
    $prism->synonym_terms_lookup();
}

sub execute_organism_module_lookup_queries {

    my $prism = shift;

    $prism->organism_id_lookup();
    
    $prism->organism_dbxref_id_lookup();
    
    $prism->organismprop_id_lookup();
    

}
 
sub execute_pub_module_lookup_queries {

    my $prism = shift;

#    $prism->pub_id_lookup();
    
#    $prism->pub_relationship_id_lookup();
    
#    $prism->pub_dbxref_id_lookup();
    
#    $prism->pubauthor_id_lookup();
    
#    $prism->pubprop_id_lookup();
    
}

sub execute_sequence_module_lookup_queries {


    my $prism = shift;

    $prism->featureloc_id_lookup();

    $prism->featurelocIdLookup();
    
    $prism->feature_pub_id_lookup();
    
    $prism->featurepropIdLookup();

    $prism->featurepropMaxRankLookup();
    
    $prism->featureprop_pub_id_lookup();
   
    $prism->feature_dbxref_id_lookup();
    
    $prism->feature_relationship_id_lookup();
    
    $prism->feature_relationship_pub_id_lookup();

    $prism->feature_relationshipprop_id_lookup();
    
    $prism->feature_relprop_pub_id_lookup();
    
    $prism->feature_cvterm_id_lookup();
    
    $prism->feature_cvtermprop_id_lookup();
    
    $prism->feature_cvterm_dbxref_id_lookup();
    
    $prism->feature_cvterm_pub_id_lookup();
    
    $prism->synonym_id_lookup();

    $prism->feature_synonym_id_lookup();
    

}


sub execute_computational_analysis_module_lookup_queries {

    my $prism = shift;

    $prism->analysis_id_lookup();
    
    $prism->analysisprop_id_lookup();
    
    $prism->analysisfeature_id_lookup();
    
}

sub execute_phylogeny_module_lookup_queries {

    my $prism = shift;

#    $prism->phylotree_id_lookup();
    
#    $prism->phylotree_pub_id_lookup();
    
#    $prism->phylonode_id_lookup();
    
#    $prism->phylonode_dbxref_id_lookup();
    
#    $prism->phylonode_pub_id_lookup();
    
#    $prism->phylonode_organism_id_lookup();
    
#    $prism->phylonodeprop_id_lookup();
    
#    $prism->phylonode_relationship_id_lookup();

}



sub execute_bsml2bsml_lookup_queries {

    my $prism = shift;

    
    $prism->cvterm_id_by_dbxref_accession_lookup();
    
    $prism->GOIDToCvtermIdLookup();

    $prism->cvterm_id_by_accession_lookup();
    
    $prism->cvterm_id_by_class_lookup();
    
    $prism->cvterm_relationship_type_id_lookup();

    $prism->cvtermpath_type_id_lookup();
    
    $prism->analysis_id_by_wfid_lookup();
    
    $prism->name_by_analysis_id_lookup();
    
    $prism->property_types_lookup();
    
    $prism->cvtermsynonym_synonym_lookup();
    
    $prism->evidence_codes_lookup();

    $prism->master_feature_id_lookup();
    
#    $prism->feature_orgseq();
    
#    $prism->uniquename_2_feature_id();

    $prism->cvterm_id_by_alt_id_lookup();

}


#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -U username -P password -D database --database_type [-c cache_dir] [-l log4perl] [-d debug_level] [-h] [-m] [-o ontology] [--setreadonly] --server [-t type] [-u update]\n".
    "  -U|--username            = Username\n".
    "  -P|--password            = Password\n".
    "  -D|--database            = Target chado database\n".
    "  --database_type          = Relational database management system type e.g. sybase or postgresql\n".
    "  -c|--cache_dir           = Optional - Directory to write cache files.  Default is environmental variable ENV{DBCACHE_DIR}\n".
    "  -l|--log4perl            = Optional - Log4perl log file. Default: /tmp/queries2Chado.pl.log\n".
    "  -m|--man                 = Display pod2usage pages for this utility\n".
    "  -o|--ontology            = Optional - to specify caching ontology loading queries --ontology=1 (Default is bsml2chado standard query caching --ontology=0)\n".
    "  -h|--help                = Display pod2usage help screen.\n".
    "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level.  Default is 0\n".
    "  --setreadonly            = Optional - will set read-only permissions on all cache files.  Default is read-write\n".
    "  --server                 = Name of server on which the database resides\n".
    "  -t|--type                = Optional - sequence/feature type to base queries on.  (Default is 'assembly')\n".
    "  -u|--update              = Optional - u=1 means update mode is ON  (Default -u=0)\n";
    exit 1;

}

sub checkParameter { 
    my ($paramName, $value) = @_;
    if (!defined($value)){
	print STDERR "$paramName was not defined\n";
	return 1;
    }
    return 0;
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
