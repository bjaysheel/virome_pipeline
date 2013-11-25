#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#-----------------------------------------------------------------------
# program:   obo2chado.pl
# author:    Jay Sundaram
# date:      2006/04/29
# 
# purpose:   Parses OBO ontology file and produces tab delimited files
#            for bcp into Chado database
#
#            Target Chado module: CV.  Tables affected are:
#            1) cv
#            2) cvterm
#            3) cvterm_relationship
#            4) cvtermsynonym
#            5) cvtermpath
#            6) cvterm_dbxref
#            7) dbxref
#            8) db
#
#-------------------------------------------------------------------------


=head1 NAME

obo2chado.pl - Parse OBO formatted ontology files and prepares contents for insertion into tab delimited .out files

=head1 SYNOPSIS

USAGE:  obo2chado.pl -D database -P password -S server -U username -b ontdoc [--checksum-placeholders] --database_type [-d debug_level] [-h] [--ignore_relationships] [-l log4perl] [-m] [-o outdir] [-p pparse] [--relationships_only] [--respect_namespace=1] [-y cache_dir]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--database,-D>
    
    Target chado database 

=item B<--server,-S>
    
    Target chado database 

=item B<--ontdoc,-b>
    
    Ontology file in OBO format

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--outdir,-o>

    Optional: Output directory for the tab delimited .out files.  Default is current directory

=item B<--pparse,-p>

    Optional: Parse use place holder functionality - supports parallel parsing by setting --pparse=1.  BCP .out files will contain Coati global placeholder vaariables.  (Default is no parallel parse --pparse=0)

=item B<--help,-h>

    Print this help

=item B<--ignore-relationships>

    Optional - Does not store any of the relations

=item B<--cache_dir,-y>

    Optional - Query caching directory to write cache files (default is ENV{DBCACHE_DIR})

=item B<--database_type>

    Either sybase or postgresql

=item B<--respect_namespace>

    Optional - User can specify whether the default-namespace value should be overriden by the Term stanza namespace values if present.  Default behavior is to always apply the default-namespace

=back

=head1 DESCRIPTION

    obo2chado.pl - Parses OBO ontology file in and prepares tab delimited .out files for bulkcopy into chado CV module.
    Out files to be produced:
    1) cv.out
    2) cvterm.out
    3) cvterm_relationship.out
    4) cvtermsynonym.out
    5) cvterm_dbxref.out
    6) db.out
    7) dbxref.out

    Please make sure that you have processed (obo2chado.pl) the relation_typedef.obo ontology file and then loaded (chadoloader.pl) the output tab delimited BCP .out files into the target database BEFORE processing and loading any other ontology files.   The [Typedef] records present in any of the ontology files (other than relation_typedef.obo) will NOT be propagated into the target database.   Please make sure that all of the valid [Typedef] records contained in the $ontdoc ontology file are present in the relation_typedef.obo ontology file.   If not, then you need to add the [Typedef] records to the relation_typedef.obo file and then re-process (obo2chado.pl -b relation_typedef.obo) in order to update the target database (chadoloader.pl).

    Each file will contain new records to be inserted via the BCP utility into a chado database. (Use the loadSybaseChadoTables.pl script to complete this task.)
    Typical actions:
    1) Parse OBO file (execute obo2chado.pl)
    2) Replace Coati::IdManager placeholder variables (execute replace_placeholders.pl)
    3) Validate master tab delimited .out files (execute any number of validate_*.pl utilities)
    4) Load the master tab delimited files into the target Chado database (execute loadSybaseChadoTables.pl)

    Assumptions:
    1. User has appropriate permissions (to execute script, access chado database, write to output directory).
    2. Target chado database already contains all reference features (necessary to build feature and organism lookups) Review and execute db2bsml.pl if required.
    3. Target chado database contains the necessary controlled vocabulary terms: "match" etc.
    4. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./obo2chado.pl -U access -P access -D tryp -b /usr/local/scatch/sundaram/SequenceOntology/ontology/so.ontology.obo  -l my.log -o /tmp/outdir


=cut

use File::Basename;
use strict;

use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Coati::Logger;
use Config::IniFiles;
use Encode;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($username, $password, $ontdoc, $database, $server, $debug_level, 
    $help, $log4perl, $man, $outdir, $pparse, $cache_dir, 
    $ignoreRelationships, $relationshipsOnly, $checksum_placeholders,
    $database_type, $respectNamespace, $allow_duplicates);


my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'ontdoc|b=s'          => \$ontdoc,
			  'database|D=s'        => \$database,
			  'server|S=s'  	=> \$server,
			  'log4perl|l=s'        => \$log4perl,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'outdir|o=s'          => \$outdir,
			  'pparse|p=s'          => \$pparse,
			  'cache_dir|y=s'       => \$cache_dir,
			  'allow_duplicates=s'  => \$allow_duplicates,
			  'ignore_relationships' => \$ignoreRelationships,
			  'relationships_only'   => \$relationshipsOnly,
			  'checksum_placeholders=s'  => \$checksum_placeholders,
			  'database_type=s'          => \$database_type,
			  'respect_namespace=s'      => \$respectNamespace
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("username was not defined\n")   if (!$username); 
print STDERR ("password was not defined\n")   if (!$password);
print STDERR ("database was not defined\n")   if (!$database);
print STDERR ("ontdoc was not defined\n")     if (!$ontdoc);
print STDERR ("server was not defined\n")     if (!$server);
print STDERR ("database_type was not defined\n")     if (!$database_type);

&print_usage if(!$username or !$password or !$database or !$ontdoc or !$database_type or !$server);

#
# Set the logger
#
my $logger = &get_logger($log4perl, $debug_level);

if (defined($respectNamespace)){
    if (($respectNamespace == 1) || ($respectNamespace == 0)){
	if ($logger->is_debug()){
	    $logger->debug("User specified --respect_namespace=$respectNamespace");
	}
    }
    else {
	$logger->logdie("Unacceptable value specified by user for --respect_namespace '$respectNamespace'");
    }
}

#
# Check mission critical file permissions
#
&is_file_readable($ontdoc);

## Use class method to verify the database vendor type
if (! Prism::verifyDatabaseType($database_type)){
    $logger->logdie("Unsupported database type '$database_type'");
}

## Set the PRISM env var
&setPrismEnv($server, $database_type);


#
# Set the cache directory
#
&set_cache_directory($cache_dir);

#
# Instantiate Prism object
#
my $prism = &retrieve_prism_object($username, $password, $database, $pparse, $checksum_placeholders);

#
# verify and set the output directory
#
$outdir = &verify_and_set_outdir($outdir);

#
# Generate the static MLDBM tied lookups
#
&load_lookups($prism);

#
# Determine whether processing the relationship typedef OBO file
#
my $typedef = &is_relationship_typedef($ontdoc);

$prism->create_pub_record();

#
# We'll keep track of the number of different id prefixes (there should only be one type per OBO file)
#
my $prefix_lookup = {};

if (!defined($ignoreRelationships)){
    $ignoreRelationships = 0;
}

#
# parse OBO ontology file
#
my ($headerLookup, $termLookup, $typedefLookup) = &parseOntologyFile($prism, $ontdoc, $typedef, $ignoreRelationships, $relationshipsOnly);

if ($relationshipsOnly != 1){
    ## Ensure that the namespace-term tuples are unique
    &checkForDuplicates($headerLookup->{'default-namespace'},
			$termLookup);
}



#
# prepare the terms for producing tab delimited files
#
&prepare_terms($prism, $headerLookup, $termLookup, $typedef, 
	       $typedefLookup, $relationshipsOnly, $ignoreRelationships, $respectNamespace  );

#
# write to the tab delimited .out files
#
&write_to_outfiles($prism, $outdir);

#
# Wrap-up
#
&end_of_program($ontdoc, $outdir, $log4perl);

exit(0);

#---------------------------------------------------------------------------------------------------------------------
#
#                                  END OF MAIN  -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------
# prepare_terms()
#
#-------------------------------------------------------
sub prepare_terms {


    my ($prism, $headerLookup, $termLookup, $typedef, $typedefLookup, 
	$relationshipsOnly, $ignoreRelationships, $respectNamespace ) = @_;

    ## If the obo file was previously processed and terms were previously loaded in
    ## the CV Module (at the very least there is a record in cv)
    ## then the appendmode will be set to 1.  This means that obo2chado.pl believes
    ## that it is operating in "append" mode.  In other words should
    ## only attempt to "append" the new terms present in the obo file to the CV Module.
    ## Should still obey the new rules for the cvterm.is_obsolete field.

    my ($cv_id, $db_id, $defaultNamespace, $appendMode) = $prism->store_cv_table( cv => $headerLookup );

    if ( (defined($cv_id)) &&
	 (defined($db_id)) &&
	 (defined($appendMode)) ) {


	if ($relationshipsOnly){
	    if (!$typedef){

		$prism->cvterm_id_by_dbxref_accession_lookup();
		
		print "Exclusively storing cvterm_relationship records\n";
		$prism->store_cvterm_relationships_exclusively($headerLookup, $cv_id, $db_id, $termLookup, $defaultNamespace, $typedef, $appendMode, $typedefLookup);
	    }
	    else {
		$logger->logdie("Exclusively storing cvterm_relationships for typedef ontology is not supported");
	    }
	}
       else{

	    my $cvterm_max_is_obsolete_lookup;

	    if ((defined($checksum_placeholders))  && ($checksum_placeholders == 1)){
		# Do not retrieve data if using checksum_placeholders
	    }
	    else {
		$cvterm_max_is_obsolete_lookup = $prism->cvterm_max_is_obsolete_lookup($cv_id);
	    }


	    my $loadedTypedefLookup = $prism->typedef_lookup();

	    $prism->storeTypedefRecordsInChadoCVModule( $headerLookup,
							$typedefLookup,
							$cv_id,
							$db_id,
							$appendMode,
							$typedef,
							$loadedTypedefLookup );
	    
 	    $prism->storeTermRecordsInChadoCVModule( $headerLookup,
 						     $termLookup,
 						     $cv_id,
 						     $db_id,
 						     $defaultNamespace,
 						     $appendMode,
 						     $loadedTypedefLookup,
 						     $cvterm_max_is_obsolete_lookup,
						     $ignoreRelationships,
						     $respectNamespace);
	}
    }
    else {
	$logger->logdie("cv_id '$cv_id' db_id '$db_id' appendMode '$appendMode'");
    }
	


}#end sub prepare_terms()


#------------------------------------------------------
# parseOntologyFile()
#
#------------------------------------------------------
sub parseOntologyFile {

    my ($prism, $oboFilename, $typedef, $ignoreRelationships, $relationshipsOnly) = @_;

    ## The OBO Flat File Format Specification version 1.2 (OFFFSV1.2) at
    ## http://www.geneontology.org/GO.format.obo-1_2.shtml
    ## states the rules for the OBO tags.
    ##
    ## In the comments that follow, the value in the key-value pair,
    ## descriptions have the following meaning:
    ##
    ## "required, processed" means that the particular tag is required 
    ## by OFFFSV1.2 and is processed by obov1p2tochado.
    ##
    ## "optional, processed" means that the particular tag is regarded
    ## as being optional by OFFFSV1.2 and all instances will be
    ## processed by obov1p2tochado.
    ##
    ## "optional, ignored" means that the particular tag is regarded
    ## as being optional by OFFFSV1.2 and no instances will be 
    ## processed by obov1p2tochado.

    ## Header Tags
    ##
    ## Cardinality rules: 
    ## Not explicitly stated in the OBO Flat File Format Specification version 1.2 (OFFFSV1.2).
    ## obov1p2tochado.pl will only accept one instance of each tag.
    ##
    ## For the key-value pairs, the value means:
    ## 1 : required, processed
    ## 2 : optional, processed
    ## 3 : optional, ignored
    my $headerTags = { 'format-version' => 1,
		       'data-version' => 3,
		       'version' => 3,
		       'date' => 3,
		       'saved-by' => 3,
		       'auto-generated-by' => 3,
		       'subsetdef' => 3,
		       'import' => 3,
		       'synonymtypedef' => 3,
		       'idspace' => 3,
		       'default-relationship-id-prefix' => 2,
		       'id-mapping' => 3,
		       'remark'  => 3,
		       'default-namespace' => 2
		   };    


    ## There are only three stanza types
    ##
    ## For the key-value pairs, the value means:
    ## 1 : required, processed
    ## 2 : optional, processed
    ## 3 : optional, ignored
    my $stanzaTypes = { 'Typedef' => 2,
			'Term' => 1,
			'Instance' => 3
		    };

    ## Legal IDs and Special Identifiers
    ## Any string is a legal id, as long as it is not one of
    ## the built in identifiers. 
    ## Four of these are defined by the OBO spec.
    ## For the key-value pairs, the value has no meaning.
    my $specialIdentifiers = { 'OBO:TYPE' => 1,
			       'OBO:TERM' => 1,
			       'OBO:TERM_OR_TYPE' => 1,
			       'OBO:INSTANCE' => 1 
			   };


    ## Term Stanza Tags
    ##
    ## For the key-value pairs, the value means:
    ## 1 : required, processed
    ## 2 : optional, processed
    ## 3 : optional, ignored
    my $termStanzaTags = { 'id' => 1,
			   'name' => 1,
			   'is_anonymous' => 3,
			   'alt_id' => 2,
			   'def' => 2,
			   'comment' => 2,
			   'subset' => 3,
			   'synonym' => 2,
			   'exact_synonym' => 2,
			   'related_synonym' => 2,
			   'narrow_synonym' => 2,
			   'broad_synonym' => 2,
			   'xref' => 2,
			   'is_a' => 2,
			   'intersection_of' => 3,
			   'union_of' => 3,
			   'disjoint_from' => 3,
			   'relationship' => 2,
			   'is_obsolete' => 2,
			   'replaced_by' => 3,
			   'consider' => 3,
			   'builtin' => 3,
			   'namespace' => 2,
			   'use_term' => 3,    ## OBO1.0, deprecated, ignored
			   'xref_analog' => 2, ## OBO1.0, deprecated but support here
			   'xref_unk' => 2     ## OBO1.0, deprecated but support here
		       };

    ## Typedef Stanza Tags
    ##
    ## For the key-value pairs, the value means:
    ## 1 : required, processed 
    ## 2 : optional, processed
    ## 3 : optional, ignored
    my $typedefStanzaTags = { 'id' => 1,
			      'name' => 1,
			      'is_anonymous' => 3,
			      'alt_id' => 2,
			      'def' => 2,
			      'comment' => 2,
			      'subset' => 3,
			      'synonym' => 2,
			      'exact_synonym' => 2,
			      'related_synonym' => 2,
			      'narrow_synonym' => 2,
			      'broad_synonym' => 2,
			      'xref' => 2,
			      'is_a' => 2,
			      'relationship' => 2,
			      'is_obsolete' => 2,
			      'replaced_by' => 3,
			      'consider' => 3,
			      'builtin' => 3,     ## Typedef only tags follow
			      'domain' => 3,       
			      'range' => 3,
			      'inverse_of' => 3,
			      'transitive_over' => 3,
			      'is_cyclic' => 3,
			      'is_reflexive' => 3,
			      'is_symmetric' => 3,
			      'is_anti_symmetric' => 3,
			      'is_transitive' => 3,
			      'is_metadata_tag' => 3,
			      'use_term' => 3,    ## OBO1.0, deprecated, ignored
			      'xref_analog' => 2, ## OBO1.0, deprecated but support here
			      'xref_unk' => 2     ## OBO1.0, deprecated but support here
			  };


    ## Cardinality rules for the Typedef Stanza Tags
    ##
    ## For the key-value pairs, the value means:
    ## 1: Only 1
    ## 2: Only 2 (etc.)
    ## m: one-to-many
    my $typedefStanzaTagCardinality = { 'id' => 1,
					'name' => 1,
					'is_anonymous' => 1,
					'alt_id' => 'm',
					'def' => 1,
					'comment' => 1,
					'subset' => 1,
					'synonym' => 1,
					'exact_synonym' => 1,
					'related_synonym' => 1,
					'narrow_synonym' => 1,
					'broad_synonym' => 1,
					'xref' => 'm',
					'is_a' => 1,
					'relationship' => 1,
					'is_obsolete' => 1,
					'replaced_by' => 1,
					'consider=' => 1,
					'builtin' => 1,
					'domain' => 1,
					'range' => 1,
					'inverse_of' => 1,
					'transitive_over' => 1,
					'is_cyclic' => 1,
					'is_reflexive' => 1,
					'is_symmetric' => 1,
					'is_anti_symmetric' => 1,
					'is_transitive' => 1,
					'is_metadata_tag' => 1,
					'xref_analog' => 'm',
				    };


    ## Cardinality rules for the Term Stanza Tags
    ##
    ##
    ## For the key-value pairs, the value means:
    ## 1: Only 1
    ## 2: Only 2 (etc.)
    ## m: one-to-many
    my $termStanzaTagCardinality = { 'id' => 1,
				     'name' => 1,
				     'is_anonymous' => 1,
				     'alt_id' => 'm',
				     'def' => 1,
				     'comment' => 1,
				     'subset' => 1,
				     'synonym' => 'm',
				     'exact_synonym' => 'm',
				     'related_synonym' => 'm',
				     'narrow_synonym' => 'm',
				     'broad_synonym' => 'm',
				     'xref' => 'm',
				     'is_a' => 'm',
				     'intersection_of' => 'm',
				     'union_of' => 'm',
				     'disjoint_from' => 'm',
				     'relationship' => 'm',
				     'is_obsolete' => 1,
				     'replaced_by' => 1,
				     'consider=' => 1,
				     'builtin' => 1,
				     'namespace' => 1,
				     'xref_analog' => 'm'
				 };


    ## Instance Stanza Tags
    ##
    ## For the key-value pairs, the value means:
    ## 1 : required, processed
    ## 2 : optional, processed
    ## 3 : optional, ignored
    my $instanceOfStanzaTags = { 'id' => 1,
				 'name' => 1,
				 'instance_of' => 1,
				 'property_value' => 3,
				 'is_anonymous' => 3,
				 'namespace' => 3,
				 'alt_id' => 3,
				 'comment' => 3,
				 'xref' => 3,
				 'synonym' => 3,
				 'is_obsolete' => 3,
				 'replaced_by' => 3,
				 'consider' => 3,
				 'xref_analog' => 3,
			     };
    


    ## If Term Stanza contains tag is_obsolete == true
    ## then the obsoleted term should not have the 
    ## following tags.
    ## For the key-value pairs, the value has no meaning.
    my $ifIsObsoleteDisallowTags = { 'is_a' => 1,
				     'relationship' => 1,
				     'inverse_of' => 1,
				     'disjoint_from' => 1,
				     'union_of' => 1,
				     'intersection_of' => 1
				 };
    
    ## When any one of the following type of stanzas (Typedef, Term, Instance)
    ## then the header section has terminated
    my $headerSectionTerminated = 0;

    ## Flag for tracking when any one of the three stanza types
    ## have been encountered.
    my $someStanzaEncountered = 0;
    my $termStanzaEncountered = 0;
    my $typedefStanzaEncountered = 0;
    my $instanceStanzaEncountered = 0;


    ## Keep track of unexpected tags
    my $unexpectedHeaderTags = {};
    my $unexpectedTermStanzaTags = {};
    my $unexpectedTypedefStanzaTags = {};
    my $unexpectedInstanceStanzaTags = {};


    ## Keep track of ignored tags
    my $ignoredHeaderTags = {};
    my $ignoredTermStanzaTags = {};
    my $ignoredTypedefStanzaTags = {};
    my $ignoredInstanceStanzaTags = {};
    
    ## Keep track of all encountered tags
    my $headerTagsTracker = {};
    my $termStanzaTagsTracker = {};
    my $typedefStanzaTagsTracker = {};
    my $instanceStanzaTagsTracker = {};

    # lookup for all OBO records
    my $termLookup = {};

    # lookup for all OBO header info
    my $headerLookup = {};

    # lookup for all new Typedef records
    my $typedefLookup = {};

    # keep track of line numbers
    my $lineCounter=0;

    # lookup containing all OBO tags that we process
    &setTermStanzaTags($termStanzaTags, $ignoreRelationships, $relationshipsOnly);

    # all OBO file's contents in a list
    my $fileContents = &get_file_contents($oboFilename);

    print "Processing '$oboFilename' contents\n";

    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = scalar(@{$fileContents});
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);


    # The unique id variable is defined outside the loop
    my $id;

    # Keep count of all tags encountered
    my $oboTagCounter = {};

    # Keep track of all unique id values encountered
    my $uniqueIdLookup = {};

    foreach my $line (@{$fileContents}){

	$lineCounter++;

	$row_count++;

	if ($logger->info("parsing")) {
	    $prism->show_progress("Parsing OBO file $row_count/$total_rows",
				  $counter,$row_count,$bars,$total_rows) 
	}

	$line = Encode::encode("utf-8",$line);

	if ($line =~ /^\s*$/){
	    next; # skip blank lines
	}

	if ($line =~ /^!/){
	    next; # skip commented lines
	}

	if ($line =~ /^\[(.*)\]/){
	    
	    my $stanzaType = $1;

	    $someStanzaEncountered = 1;

	    if ( exists $stanzaTypes->{$stanzaType} ){
	    
		## Figure out what kind of stanza we're processing.
		## This will have bearing on how the tags in this
		## stanza will be processed.
		##
		if ($stanzaType eq 'Typedef'){
		    $typedefStanzaEncountered = 1;
		    $termStanzaEncountered = 0;
		    $instanceStanzaEncountered = 0;
		}
		elsif ($stanzaType eq 'Term'){
		    $termStanzaEncountered = 1;
		    $typedefStanzaEncountered = 0;
		    $instanceStanzaEncountered = 0;
		}
		elsif ($stanzaType eq 'Instance'){
		    $instanceStanzaEncountered = 1;
		    $termStanzaEncountered = 0;
		    $typedefStanzaEncountered = 0;
		}
		else {
		    $logger->logdie("Unrecognized stanza type '$stanzaType'");
		}
	    }
	    else {
		$logger->logdie("Unexpected stanza type '$stanzaType' ".
				"encountered at line '$lineCounter' in OBO file '$oboFilename'");
	    }

	    next;
	}

	if ($line =~ /^(\S+):(.+)$/){
	    ## Parse all tag:value pairs
	    my $tag = $1;
	    my $value = &strip_white_spaces($2);
	    
	    ## Maintain a count of all tag types encountered.
	    $oboTagCounter->{$tag}++;

	    if ($someStanzaEncountered == 0) {
		## Processing the header information

		## Keep track of all header tags encountered
		$headerTagsTracker->{$tag}++;

		if ( exists $headerTags->{$tag} ) {
		    ## This is a recognized tag

		    if ( $headerTags->{$tag} != 3 ){
			## This tag-value shall be processed

			if ( exists $headerLookup->{$tag} ){
			    $logger->logdie("Already encountered Header tag '$tag'");
			}
			else {
			    $headerLookup->{$tag} = $value
			}
		    }
		    else {
			$ignoredHeaderTags->{$tag}++;
		    }
		}
		else {
		    ## This tag is unrecognized
		    $logger->warn("Unexpected Header tag '$tag' encountered at line '$lineCounter'");
		    $unexpectedHeaderTags->{$tag}++;
		}
	    }
	    else {
		## Not processing header information
		
		    
		if ($termStanzaEncountered == 1){

		    ## Keep track of all Term stanza tags encountered
		    $termStanzaTagsTracker->{$tag}++;

		    if ( exists $termStanzaTags->{$tag} ){
			## This is a recognized tag
			if ( $termStanzaTags->{$tag} != 3){
			    ## This tag shall be processed
			    $id = &storeTermTagValue($termLookup, $tag, $value, $termStanzaTags, 
						     $id, $lineCounter, $oboFilename,
						     $uniqueIdLookup, $specialIdentifiers,
						     $termStanzaTagCardinality);
			}
			else {
			    ## This tag was ignored
			    $ignoredTermStanzaTags->{$tag}++;
			}
		    }
		    else {
			## This tag is unrecognized
			$logger->warn("Unexpected Term stanza tag '$tag' encountered at line '$lineCounter'");
			$unexpectedTermStanzaTags->{$tag}++;
		    }
		}
		elsif ($typedefStanzaEncountered == 1){

		    ## Keep track of all Typedef stanza tags encountered
		    $typedefStanzaTagsTracker->{$tag}++;

		    if ( exists $typedefStanzaTags->{$tag} ){
			## This is a recognized tag
			if ($typedefStanzaTags->{$tag} != 3 ){
			    ## This tag shall be processed
			    $id = &storeTermTagValue($typedefLookup, $tag, $value, 
						     $typedefStanzaTags, $id, $lineCounter,
						     $oboFilename, $uniqueIdLookup, 
						     $specialIdentifiers,
						     $typedefStanzaTagCardinality);
			}
			else {
			    ## This tag was ignored
			    $ignoredTypedefStanzaTags->{$tag}++;
			}
		    }
		    else {
			## This tag is unrecognized
			$logger->warn("Unexpected Typedef stanza tag '$tag' encountered at line '$lineCounter'");
			$unexpectedTypedefStanzaTags->{$tag}++;
		    }
		}
		elsif ($instanceStanzaEncountered == 1) {
		    ## Keep track of all Instance stanza tags encountered
		    $instanceStanzaTagsTracker->{$tag}++;

		    $logger->warn("$0 currently does not process Instance Stanza tags");
		}
		else {
		    $logger->logdie("tag '$tag' value '$value' ".
				    "someStanzaEncountered '$someStanzaEncountered' ".
				    "termStanzaEncountered '$termStanzaEncountered' ".
				    "typedefStanzaEncountered '$typedefStanzaEncountered' ".
				    "instanceStanzaEncountered '$instanceStanzaEncountered' ".
				    "at line '$lineCounter' in OBO file '$oboFilename'");
		}
	    }
	}
	else {
	    $logger->logdie("Unexpected line content at line '$lineCounter': $line");
	}
    }

    ## Reports for Header tags
    &reportTagsEncountered($headerTagsTracker, $headerTags, "Header");
    &reportUnexpectedTagsEncountered($unexpectedHeaderTags, "Header");
    &reportIgnoredTagsEncountered($ignoredHeaderTags, "Header");

    ## Reports for Term stanza tags
    &reportTagsEncountered($termStanzaTagsTracker, $termStanzaTags, "Term");
    &reportUnexpectedTagsEncountered($unexpectedTermStanzaTags, "Term");
    &reportIgnoredTagsEncountered($ignoredTermStanzaTags, "Term");

    ## Reports for Typedef stanza tags
    &reportTagsEncountered($typedefStanzaTagsTracker, $typedefStanzaTags, "Typedef");
    &reportUnexpectedTagsEncountered($unexpectedTypedefStanzaTags, "Typedef");
    &reportIgnoredTagsEncountered($ignoredTypedefStanzaTags, "Typedef");

    ## Reports for Instance tags
    &reportTagsEncountered($instanceStanzaTagsTracker, $instanceOfStanzaTags,  "Instance");

    ## Report the number of terms encountered i.e. 'name:' OBO attribute
    print "Found '$oboTagCounter->{'name'}' terms in OBO file '$ontdoc'\n";
    $logger->info("Found '$oboTagCounter->{'name'}' terms in OBO file '$ontdoc'");

    return ($headerLookup, $termLookup, $typedefLookup);

}#end sub parse_ontology_file()


#------------------------------------------------------
#  check_file_status()
#
#------------------------------------------------------
sub check_file_status {

    $logger->info("Entered check_file_status");#

    my $file = shift;

    $logger->logdie("$$file was not defined") if (!defined($file));

    $logger->logdie("$$file does not exist") if (!-e $$file);
    $logger->logdie("$$file does not have read permissions") if ((-e $$file) and (!-r $$file));

}#end sub check_file_status()

#-------------------------------------------------------------------
# is_file_readable()
#
#-------------------------------------------------------------------
sub is_file_readable {

    my ( $file) = @_;

    $logger->fatal("file was not defined") if (!defined($file));

    my $fatal_flag=0;

    if (!-e $file){
	$logger->fatal("$file does not exist");
	$fatal_flag++;
    }

    else{#if ((-e $file)){
	if ((!-r $file)){
	    $logger->fatal("$file does not have read permissions");
	    $fatal_flag++;
	}
	if ((-z $file)){
	    $logger->fatal("$file has no content");
	    $fatal_flag++;
	}
    }


    return 0 if ($fatal_flag>0);
    return 1;
   

}#end sub is_file_readable()

#--------------------------------------------------------
# verify_and_set_outdir()
#
#--------------------------------------------------------
sub verify_and_set_outdir {

    my ( $outdir) = @_;

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


    #
    # store the outdir in the environment variable
    #
    $ENV{OUTPUT_DIR} = $outdir;
    
    return $outdir;

}#end sub verify_and_set_outdir()

#----------------------------------------------------------------
# retrieve_prism_object()
#
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database, $pparse, $checksum_placeholders) = @_;

    if (!defined($pparse)){
	$pparse = 0;
    }


    #
    # If checksum_placeholders == 1, then we want md5 checksum values inserted in place of the table
    # serial identifiers.
    #
    #
    if ((defined($checksum_placeholders)) && ($checksum_placeholders == 1)){
	$pparse = undef;
    }

    my $prism;

    if (($pparse == 0) or ($pparse == 1)){


	$prism = new Prism( 
			    user             => $username,
			    password         => $password,
			    db               => $database,
			    use_placeholders => $pparse,
			    checksum_placeholders => $checksum_placeholders,
			    );

	$logger->logdie("prism was not defined") if (!defined($prism));

    }
    else{
	$logger->logdie("pparse '$pparse' was neither '0' nor '1'");
    }
   
    return $prism;


}#end sub retrieve_prism_object()


#--------------------------------------------------------------
# write_to_outfiles() 
#
#
#--------------------------------------------------------------
sub write_to_outfiles {

    my ( $writer,$outdir) = @_;

    $logger->fatal("writer was not defined") if (!defined($writer));

    #
    # Output the datasets to file and/or batch load into database 
    #

    $logger->info("Writing tab delimited .out files to directory: $outdir");

    $writer->{_backend}->output_tables("$outdir/");

}#end sub write_to_outfiles()



#--------------------------------------------------------------
# is_relationship_typedef()
#
#--------------------------------------------------------------
sub is_relationship_typedef {

    my $file = shift;

    open (OBOFILE, "<$file") or $logger->logdie("Could not open OBO file '$file': $!");

    #
    # default-namespace should be defined within the first 6 lines of the OBO file
    #
    my $i=0;
    while ((my $line = <OBOFILE>) && ( $i<6 )){
	
	if ($line =~ /^default-namespace:\s*(.+)/){
	    my $namespace = $1;
	    if ($namespace =~ /relation_typedef\.ontology/i){
		return 1;
	    }
	    elsif ($namespace =~ /relationship/i){
		return 1;
	    }
	}
    }

    return 0;
}


#------------------------------------------------------------------------------------------------------------------------------------
# subroutine:  load_lookups
#
# editor:      sundaram@tigr.org
#
# date:        2005-10-25
#
# bgzcase:     2229
#
# URL:         http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2229
#
# comment:     These lookups are tied to MLDBM files!
#              These lookups should be STATIC!
#              It is up to each client to load the necessary lookups in similar fashion:
#
# input:       Prism object reference
#
# output:      none
#
# return:      none
#
#------------------------------------------------------------------------------------------------------------------------------------
sub load_lookups {

    my $prism = shift;


    $prism->cv_id_lookup();
    $prism->cvterm_id_lookup();
    $prism->db_id_lookup();
    $prism->dbxref_id_lookup();
    $prism->cvterm_relationship_id_lookup();
    $prism->cvterm_dbxref_id_lookup();
    $prism->cvtermprop_id_lookup();
    $prism->cvtermsynonym_id_lookup();
    $prism->synonym_terms_lookup();    
}

#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -D database -P password -S server -U username -b ontdoc [--checksum-placeholders] --database_type  [-d debug_level] [h] [--ignore_relationships] [-l log4perl] [-m] [-o outdir] [-p pparse] [--relationships_only] [-y cache_dir]\n".
    "  -D|--database            = Target chado database\n".
    "  -P|--password            = Password\n".
    "  -S|--server              = Target server\n".
    "  -U|--username            = Username\n".
    "  -b|--ontdoc              = OBO ontology file to be parsed\n".
    "  --checksum-placeholders  = Optional - specified during non-parallel processing\n".
    "  --database_type          = RDBMS type: sybase or postgresql\n".
    "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level (default level is 0)\n".
    "  -h|--help                = Optional - Display pod2usage help screen.\n".
    "  --ignore_relationships   = Optional - Process the .obo file, but ignore term relationships\n".
    "  -l|--log4perl            = Optional - Log4perl log file (default: /tmp/obo2chado.pl.log)\n".
    "  -m|--man                 = Display pod2usage pages for this utility\n".
    "  -o|--outdir              = Optional - Output directory for tab delimited out files (default is current directory)\n".
    "  -p|--pparse              = Optional - Parallel parse (default is non-parallel parse)\n".
    "  --relationships_only     = Optional - Process the .obo file, but only store the term relationships\n".
    "  -y|--cache_dir           = Optional - To turn on file-caching and specify directory to write cache files.  (Default no file-caching. If specified directory does not exist, default is environmental variable ENV{DBCACHE_DIR}\n";
    exit 1;

}


#------------------------------------------------------
# set_so_default_namespace()
#
#------------------------------------------------------
sub set_so_default_namespace {

    my ($dns, $file) = @_;

    if (($file =~ /so\.obo$/) && ($dns ne 'SO')) {

	$logger->warn("Changing the default-namespace for file '$file' from '$dns' to 'SO'");

	$dns = 'SO';
    }

    return $dns;
}

#------------------------------------------------------
# setTermStanzaTags()
#
#------------------------------------------------------
sub setTermStanzaTags {

    my ($termStanzaTags, $ignoreRelationships, $relationshipsOnly) = @_;

    if ($ignoreRelationships == 1){

	## These tags become optional, ignored
	$termStanzaTags->{'is_a'} = 3;
	$termStanzaTags->{'relationship'} = 3;

    }	
    if ($relationshipsOnly == 1){

	## All tags save id, is_a, relationship,
	## namespace become optional, ignored
	$termStanzaTags = { 'id' => 1,
			    'name' => 3,
			    'is_anonymous' => 3,
			    'alt_id' => 3,
			    'def' => 3,
			    'comment' => 3,
			    'subset' => 3,
			    'synonym' => 3,
			    'exact_synonym' => 3,
			    'related_synonym' => 3,
			    'narrow_synonym' => 3,
			    'broad_synonym' => 3,
			    'xref' => 3,
			    'is_a' => 2,
			    'intersection_of' => 3,
			    'union_of' => 3,
			    'disjoint_from' => 3,
			    'relationship' => 2,
			    'is_obsolete' => 3,
			    'replaced_by' => 3,
			    'consider=' => 3,
			    'builtin' => 3,
			    'namespace' => 2,
			    'xref' => 3
			   };
    }

}

#------------------------------------------------------
# storeTermTagValue()
#
#------------------------------------------------------
sub storeTermTagValue {

    my ($termLookup, $tag, $value, $termStanzaTags, $id, 
	$lineCounter, $file, $uniqueIdLookup, $specialIdentifiers,
	$termStanzaTagCardinality) = @_;


    if ($tag eq 'id'){

	if ( exists $specialIdentifiers->{$value} ){
	    $logger->logdie("Encountered reserved id '$specialIdentifiers->{$value}' ".
			    "at line '$lineCounter' in OBO file '$file'");
	}

	if ( exists $uniqueIdLookup->{$value} ){
	    $logger->logdie("Found duplicate id '$value' at line '$lineCounter' of OBO file '$file'");
	}
	else {
	    $uniqueIdLookup->{$value}++;
	}
	$id = $value;
    }
    elsif (defined($id)){

	if ($tag =~ /synonym/){
	    if ($value =~ /\"(.+)\"\s+(.+)/){
		my $synonymString = $1;
		my $optionalInfo = $2;
		if ($logger->is_debug()){
		    $logger->debug("synonymString '$synonymString' optionalInfo '$optionalInfo'");
		}
		$value = $synonymString;
		if ($optionalInfo =~ /EXACT/){
		    $tag = 'exact_synonym';
		}
		elsif ($optionalInfo =~ /NARROW/){
		    $tag = 'narrow_synonym';
		}
		elsif ($optionalInfo =~ /BROAD/){
		    $tag = 'broad_synonym';
		}
		elsif ($optionalInfo =~ /RELATED/){
		    $tag = 'related_synonym';
		}
	    }
	    else {
		$logger->logdie("Could not parse value '$value' with tag '$tag'");
	    }
	}
	
	if  (($value =~ /^\"/) && ($value =~ /\"$/)){
	    if (($tag =~ /synonym/) || ($tag eq 'def') || ($tag eq 'comment')) {
		
		$value = &extract_value_from_double_quotes($value);
	    }
	    else {
		$logger->logdie("Unexpectedly found surrounding double quotes ".
				"for tag '$tag' value '$value' at line '$lineCounter' ".
				"of OBO file '$file'");
	    }
	}


	if ($tag eq 'is_obsolete'){
	    $value = ($value eq 'true') ? 1 : 0;
	}

	
	if ($tag eq 'is_a'){
	    $value = &remove_trailing_comment($value);
	}




	if ($tag eq 'relationship'){
	    &store_relationship($id, $value, $termLookup);
	}
	elsif ($termStanzaTagCardinality->{$tag} == 1) {

	    ## OBO record tag for which there can only be one value
	    if (!exists $termLookup->{$id}->{$tag}){

		$termLookup->{$id}->{$tag} = $value;
		
	    }
	    else{
		$logger->logdie("Found another occurence of tag '$tag' for ".
				"id '$id' value '$value' at line '$lineCounter' of OBO file '$file'");
	    }
	}
	elsif ($termStanzaTagCardinality->{$tag} eq 'm') {

	    ## OBO record tag for which there can be multiple values
	    push(@{$termLookup->{$id}->{$tag}}, $value);
	}
	else {
	    $logger->logdie("id '$id' tag '$tag' value '$value' at line '$lineCounter' of OBO file '$file'");
	}
    }


    return $id;
}



#------------------------------------------------------
# extract_value_from_double_quotes()
#
#------------------------------------------------------
sub extract_value_from_double_quotes {

    my ($value) = @_;

    if ($value =~ /\"(.+)\"/){

	my $newvalue = $1;

	# remove leading whitespaces
	$newvalue =~ s/^\s*//;

	# remove trailing whitespaces
	$newvalue =~ s/\s*$//;

	return $newvalue;
    }
    else {
	$logger->logdie("Could not parse synonym '$value'");
    }
}


#------------------------------------------------------
# strip_double_quotes()
#
#------------------------------------------------------
sub strip_double_quotes {

    my ($value) = @_;

    $value =~ s/^\"//;
    $value =~ s/\"$//;
    
    return $value;
}


#------------------------------------------------------
# strip_white_spaces()
#
#------------------------------------------------------
sub strip_white_spaces {

    my ($value) = @_;

    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    
    return $value;
}

#------------------------------------------------------
# remove_trailing_comment()
#
#------------------------------------------------------
sub remove_trailing_comment {

    my ($value) = @_;

    if ($value =~ /^(\S+)\s*/){
	$value = $1;
    }
    else {
	$logger->logdie("Could not parse is_a value '$value'");
    }
    
    return $value;
}

#------------------------------------------------------
# store_relationship()
#
#------------------------------------------------------
sub store_relationship {

    my ($id, $value, $termLookup) = @_;

    # E.g.:
    # relationship: part_of SO:0000673 ! transcript

    my ($reltype, $val) = split(/\s+/, $value);

    if ((defined($reltype)) && (defined($val))){
	push(@{$termLookup->{$id}->{$reltype}}, $val );
    }
    else {
	$logger->logdie("reltype '$reltype' val '$val' id '$id' value '$value'");
    }

}

#------------------------------------------------------
# get_file_contents()
#
#------------------------------------------------------
sub get_file_contents {

    my ($file) = @_;

    print "Reading '$file' contents\n";

    open (INFILE, "<$file") or $logger->logdie("Could not open $file in read mode: $!");

    my @lines = <INFILE>;
    
    chomp @lines;

    return \@lines;
}

#------------------------------------------------------
# get_logger()
#
#------------------------------------------------------
sub get_logger {

    my ($log4perl, $debug_level) = @_;

    #
    # initialize the logger
    #
    $log4perl = "/tmp/obo2chado.pl.log" if (!defined($log4perl));
    my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
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
    
    if (lc($vendor) eq 'postgresql'){
       $vendor = 'postgres';
   }
    
    $vendor = "Bulk" . ucfirst($vendor);
    ## We're overriding the env stored in conf/Prism.conf
    my $prismenv = "Chado:$vendor:$server";


    $ENV{PRISM} = $prismenv;
}

#------------------------------------------------------
# set_cache_directory()
#
#------------------------------------------------------
sub set_cache_directory {

    my ($cache_dir) = @_;

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
    }

    print "**************************************************************************************************\n".
    "   Please note that lookups will be read from/written to cache directory '$ENV{DBCACHE_DIR}'\n".
    "\n".
    "**************************************************************************************************\n";


}

#------------------------------------------------------
# end_of_prgram()
#
#------------------------------------------------------
sub end_of_program {

    my ($ontdoc, $outdir, $log4perl) = @_;

    #
    # Notify of completion
    #
    
    $logger->info("'$0': Finished parsing ontology file: $ontdoc\nPlease verify log4perl log file: $log4perl");

    print ("\n\n$0 finished processing OBO file '$ontdoc'\nBCP files were written to directory '$outdir'\nLog file is '$log4perl'\n\n");
}

##-----------------------------------------------------
## checkForDuplicates()
##
##-----------------------------------------------------
sub checkForDuplicates {

    my ($defaultNamespace, $termLookup) = @_;

    my $uniqueTuplesLookup = {};

    my $duplicatesLookup = {};

    my $duplicateCtr=0;

    foreach my $id (sort keys %{$termLookup}){

	if ((exists $termLookup->{$id}->{'is_obsolete'}) &&
	    ($termLookup->{$id}->{'is_obsolete'} == 1 )){
	    next;
	}


	if (exists $termLookup->{$id}->{'name'}){


	    my $name = $termLookup->{$id}->{'name'};

	    my $namespace = $defaultNamespace;

	    if (exists $termLookup->{$id}->{'namespace'}){
		$namespace = $termLookup->{$id}->{'namespace'};
	    }

	    ## Check to see if we have duplicates
	    if (exists $uniqueTuplesLookup->{$name,$namespace}){
		if($allow_duplicates){
		    $termLookup->{$id}->{'name'} .= " ($duplicateCtr)";
		}
		else{
		    $duplicatesLookup->{$name,$namespace}++;
		}
		$duplicateCtr++;
	    }		
	    ## Store reference on the lookup
	    $uniqueTuplesLookup->{$name,$namespace}++;

	}
	else {
	    $logger->logdie("name did not exist for id '$id' ".
			    "in OBO file '$ontdoc'");
	}
    }


    if ($duplicateCtr>0 && !$allow_duplicates){
	$logger->fatal("Here are the duplicate term namespace tuples");

	foreach my $dup (sort keys %{$duplicatesLookup}){
	    $logger->fatal("$dup");
	}

	$logger->logdie("Found '$duplicateCtr' duplicate ".
			"term-namespace tuples in OBO file ".
			"'$ontdoc'");
    }
}

##-----------------------------------------------------
## reportTagsEncountered()
##
##-----------------------------------------------------
sub reportTagsEncountered {

    my ($encounteredTagsLookup, $tagsLookup, $type) = @_;

    $logger->warn("Examining the '$type' tags");

    foreach my $tag (keys %{$tagsLookup}){
	if (exists $encounteredTagsLookup->{$tag}){
	    $logger->warn("Found '$encounteredTagsLookup->{$tag}' instances of '$tag'");
	}
	else {
	    $logger->warn("Found no occurences of '$tag'");
	}
    }

    foreach my $tag (keys %{$encounteredTagsLookup}){
	if (!exists $tagsLookup->{$tag}){
	    $logger->warn("Found '$encounteredTagsLookup->{$tag}' instances of '$tag'.  These tags are not part of the OBO 1.2 spec.");
	}
    }
}

##-----------------------------------------------------
## reportUnexpectedTagsEncountered()
##
##-----------------------------------------------------
sub reportUnexpectedTagsEncountered {

    my ($unexpectedTagsLookup, $type) = @_;

    $logger->warn("Examining unexpected '$type' tags that were encountered. Note that $0 will not process these tags.");

    foreach my $tag (keys %{$unexpectedTagsLookup}){
	$logger->warn("Unexpectedly encountered '$unexpectedTagsLookup->{$tag}' instances of tag '$tag'");
    }
}

##-----------------------------------------------------
## reportIgnoredTagsEncountered()
##
##-----------------------------------------------------
sub reportIgnoredTagsEncountered {

    my ($ignoredTagsLookup, $type) = @_;

    $logger->warn("Examining ignored '$type' tags that were encountered. Note that $0 will not process these tags.");

    foreach my $tag (keys %{$ignoredTagsLookup}){
	$logger->warn("'$ignoredTagsLookup->{$tag}' instance(s) of tag '$tag' wwill be ignored");
    }
}
