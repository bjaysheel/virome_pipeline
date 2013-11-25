#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#-----------------------------------------------------------------------
# program:   OBO2Chado.pl
# author:    Jay Sundaram
# date:      2003/05/09
# 
# purpose:   Parses OBO ontology file and produces tab delimited files
#            for Bulkcopy into Chado database
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

OBO2Chado.pl - Parse OBO formatted ontology files and prepares contents for insertion into tab delimited .out files

=head1 SYNOPSIS

USAGE:  OBO2Chado.pl -U username -P password -D database --database_type -b ontdoc [-S server] [-l log4perl] [-d debug_level] [-h] [-m] [-o outdir] [-p pparse]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--database,-D>
    
    Target chado database 

=item B<--database_type>
    
    Relational database management system type.

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

=item B<--cache_dir,-y>

    Optional - Query caching directory to write cache files (default is ENV{DBCACHE_DIR})


=back

=head1 DESCRIPTION

    OBO2Chado.pl - Parses OBO ontology file in and prepares tab delimited .out files for bulkcopy into chado CV module.
    Out files to be produced:
    1) cv.out
    2) cvterm.out
    3) cvterm_relationship.out
    4) cvtermsynonym.out
    5) cvterm_dbxref.out
    6) db.out
    7) dbxref.out

    Please make sure that you have processed (OBO2Chado.pl) the relation_typedef.obo ontology file and then loaded (chadoloader.pl) the output tab delimited BCP .out files into the target database BEFORE processing and loading any other ontology files.   The [Typedef] records present in any of the ontology files (other than relation_typedef.obo) will NOT be propagated into the target database.   Please make sure that all of the valid [Typedef] records contained in the $ontdoc ontology file are present in the relation_typedef.obo ontology file.   If not, then you need to add the [Typedef] records to the relation_typedef.obo file and then re-process (OBO2Chado.pl -b relation_typedef.obo) in order to update the target database (chadoloader.pl).

    Each file will contain new records to be inserted via the BCP utility into a chado database. (Use the loadSybaseChadoTables.pl script to complete this task.)
    Typical actions:
    1) Parse OBO file (execute OBO2Chado.pl)
    2) Replace Coati::IdManager placeholder variables (execute replace_placeholders.pl)
    3) Validate master tab delimited .out files (execute any number of validate_*.pl utilities)
    4) Load the master tab delimited files into the target Chado database (execute loadSybaseChadoTables.pl)

    Assumptions:
    1. User has appropriate permissions (to execute script, access chado database, write to output directory).
    2. Target chado database already contains all reference features (necessary to build feature and organism lookups) Review and execute db2bsml.pl if required.
    3. Target chado database contains the necessary controlled vocabulary terms: "match" etc.
    4. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./OBO2Chado.pl -U access -P access -D tryp -b /usr/local/scatch/sundaram/SequenceOntology/ontology/so.ontology.obo  -l my.log -o /tmp/outdir


=cut

use File::Basename;
use strict;

use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Coati::Logger;
use Config::IniFiles;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($username, $password, $ontdoc, $database, $database_type, $server, $debug_level, $help, $log4perl, $man, $outdir, $pparse, $cache_dir);


my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'ontdoc|b=s'          => \$ontdoc,
			  'database|D=s'        => \$database,
			  'database_type=s'        => \$database_type,
			  'server|S=s'			=> \$server,
			  'log4perl|l=s'        => \$log4perl,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'outdir|o=s'          => \$outdir,
			  'pparse|p=s'          => \$pparse,
			  'cache_dir|y=s'       => \$cache_dir
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("username was not defined\n")   if (!$username); 
print STDERR ("password was not defined\n")   if (!$password);
print STDERR ("database was not defined\n")   if (!$database);
print STDERR ("ontdoc was not defined\n")     if (!$ontdoc);

&print_usage if(!$username or !$password or !$database or !$ontdoc or !$database_type or !$server);

#
# initialize the logger
#
$log4perl = "/tmp/OBO2Chado.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

## Set the PRISM env var
&setPrismEnv($server, $database_type);

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

#
# Instantiate Prism object
#
my $prism = &retrieve_prism_object($username, $password, $database, $pparse);

print "**************************************************************************************************\n".
"*   Please note that lookups will be read from/written to cache directory '$ENV{DBCACHE_DIR}'\n".
"*\n".
"**************************************************************************************************\n";




#
# verify and set the output directory
#
$outdir = &verify_and_set_outdir($outdir);

#
# Check mission critical file permissions
#

&is_file_readable($ontdoc) if (defined($ontdoc));

 
print "\n";

#
# Generate the static MLDBM tied lookups
#
&load_lookups($prism);

#
# parse OBO ontology file
#
my ($cv, $terms, $term_count, $typedef_lookup) = &parse_ontology_file($prism, \$ontdoc);




#
# Determine whether processing the relationship typedef OBO file
#
my $typedef = &is_relationship_typedef($ontdoc);


#
# prepare the terms for producing tab delimited files
#
&prepare_terms($prism, 
	       $cv,
	       $terms,
	       $term_count,
	       $typedef,
	       $typedef_lookup );

#
# write to the tab delimited .out files
#
&write_to_outfiles($prism, $outdir);

#
# Notify of completion
#

$logger->info("'$0': Finished parsing ontology file: $ontdoc");
print STDERR ("\nTab delimited .out files were written to directory '$outdir'\n");

$logger->info("Please verify log4perl log file: $log4perl");


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


    my ($prism, $cv, $terms, $term_count, $typedef, $typedef_lookup) = @_;


    #
    # If the obo file was previously processed and terms were previously loaded in the CV Module (at the very least there is a record in cv)
    # then the appendmode will be set to 1.  This means that OBO2Chado.pl believes that it is operating in "append" mode.  In other words should
    # only attempt to "append" the new terms present in the obo file to the CV Module.
    # Should still obey the new rules for the cvterm.is_obsolete field.
    #
    my ($cv_id, $db_id, $dbname, $appendmode) = $prism->store_cv_table( cv => $cv );

    if ( (defined($cv_id)) &&
	 (defined($db_id)) &&
	 (defined($appendmode)) ) {

	my $cvterm_max_is_obsolete_lookup = $prism->cvterm_max_is_obsolete_lookup($cv_id);

	$prism->store_cv_module(
				cv         => $cv,
				terms      => $terms,
				term_count => $term_count,
				cv_id      => $cv_id,
				db_id      => $db_id,
				dbname     => $dbname,
				typedef    => $typedef,
				appendmode => $appendmode,
				new_typedef_lookup => $typedef_lookup->{'id'},
				obsolete_lookup => $cvterm_max_is_obsolete_lookup
				);
    }
    else {
	
	$logger->logdie("cv_id '$cv_id' db_id '$db_id' appendmode '$appendmode'");
    }
	


}#end sub prepare_terms()


#------------------------------------------------------
# parse_ontology_file()
#
#------------------------------------------------------
sub parse_ontology_file {

    my ($prism, $file) = @_;

    open (INFILE, "<$$file") or $logger->logdie("Could not open $$file in read mode");

    my @contents;

    my $basename = basename($$file);


    my $term_ctr=0;
    my $terms = {};
    my $cv = {};


    $logger->info("Reading in all contents of OBO ontology file");
    @contents = <INFILE>;
    chomp @contents;
    
    my $id;

    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = scalar(@contents);
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);
    print "\n";
    

    my $dirtylines;

    my $countall = {};

    my $obs_in_def=0;

    my $typedef_encountered = 0;

    my $typedef = {};
    my $typedefctr = 0;

    my $name_hash = {};
    my $obsolete_hash = {};


    my $name;

    foreach my $line (@contents){

	$countall->{'linectr'}++;

	$row_count++;
	$prism->show_progress("Parsing OBO file $row_count/$total_rows",$counter,$row_count,$bars,$total_rows) if $logger->info;


	if ($typedef_encountered == 1){
	    if ($line =~ /^\[/){
		$typedef_encountered = 0;
	    }
	    elsif ($line =~ /^id:/){
		# allow flow to continue so as to store the id in the typedef hash
	    }
	    else{
		#
		# Skip all lines following the:
		# [Typedef]
		# id: derived_from
		# name: derived_from   <skip line>
		# is_transitive: true  <skip line>
		#
		#
		next;
	    }
	}

	#
	# Header information gets parsed out
	# 
	if ($line =~ /format-version:\s*(\S+)\s*$/){
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    $cv->{'format-version'} = $1;
	}
	elsif ($line =~ /date:\s*([\S\s]+)\s*$/){
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    $cv->{'date'} = $1;
	}
	elsif ($line =~ /saved-by:\s*([\S\s]+)\s*$/){
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    $cv->{'saved-by'} = $1;
	}	
	elsif ($line =~ /auto-generated-by:\s*([\S\s]+)\s*$/){
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    $cv->{'auto-generated-by'} = $1;
	}
	elsif ($line =~ /default-namespace:\s*([\S\s]+)\s*$/){
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    
	    my $dns = &set_default_namespace($1, $basename, $file);

	    $cv->{'default-namespace'} = $dns;
	}
	elsif ($line =~ /^subsetdef:/){
	    $logger->info("We're not storing any of the info stored in the subsetdef line '$line'");
	}
	elsif ($line =~ /^remark:/){
	    $logger->info("We're not storing any of the info stored in the remark line '$line'");
	}
	elsif ($line =~ /^\[Term\]$/){

	    $countall->{'termstubctr'}++;
	}
	elsif ($line =~ /^\[Typedef\]$/){

	    #------------------------------------------------------------------------
	    # In the relationship.obo file, all terms are typedef.  To process
	    # correctly, need to set the typedef encountered flag unless dealing with
	    # relationship.obo
	    #
	    if ($cv->{'default-namespace'} ne 'relationship'){
		$typedef_encountered = 1;
		$countall->{'typedefctr'}++;

	    }
	    #
	    #-----------------------------------------------------------------------
	}
	elsif ($line =~ /^id:\s*(\S+)$/){
	    
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));


	    #
	    # Get the id
	    #
	    $id = $1;


	    if ($typedef_encountered == 1){
		$typedef->{'id'}->{$id}++;
		next;
	    }
	    else{
	
		if (exists($terms->{$id})){
		    $logger->fatal("duplicate id for $id found.  Will not insert again.  Is the OBO file corrupt?  Skipping...");
		    next;
		}
		else{
		    $terms->{$id}->{'id'} = $id;
		    $countall->{'term_ctr'}++;
		}
	    }
#	    die "typedef '$1'" if ($1 eq 'derived_from');
	}
	elsif ($line =~ /^name:\s*([\S\s]+)$/){
	    	
	    $name = $1;

	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	 
	    # strip leading white spaces
	    $name =~ s/^\s*//;
	    # strip trailing white spaces
	    $name =~ s/\s*$//;


	    $name_hash->{$name}->{'ctr'}++;
	    $name_hash->{$name}->{$id} = $id;


	    #
	    # Get the name
	    #

	    if ($typedef_encountered == 1){
		$typedef->{'name'}->{$name}++;
		$typedef_encountered = 0;
		next;
	    }
	    else{
		if (exists($terms->{$id}->{'name'})){
		    $logger->fatal("duplicate name for $id found.  Will not insert again.  Is the OBO file corrupt?  Skipping...");
		    next;
		}
		else{
		    $terms->{$id}->{'name'} = $name;
		}
	    }

	}
	elsif ($line =~ /^namespace:\s*([\S\s]+)$/){
	    
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the namespace
	    #
	    if (exists($terms->{$id}->{'namespace'})){
		$logger->fatal("duplicate namespace for $id found.  Will not insert again.  Is the OBO file corrupt?  Skipping...");
		next;
	    }
	    $terms->{$id}->{'namespace'} = $1;
	}
	elsif ($line =~ /^def:\s*([\S\s]+)$/){
	    
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the def
	    #
	    my $def = $1;

	    if (exists($terms->{$id}->{'def'})){
		$logger->fatal("duplicate def for $id found.  Will not insert again.  Is the OBO file corrupt?  Skipping...");
		next;
	    }

	    #
	    # Check for OBSOLETE in definition field
	    #
	    if ($def =~ /OBSOLETE/){
		$obs_in_def++;
		$terms->{$id}->{'is_obsolete'} = 1;

#		$name_hash->{$name}->{'obsolete'}++;

	    }

	    #
	    # Don't need the double quotes
	    #
	    $def =~ s/\"//g;
	    

	    #
	    # and lastly, remove the xref info from the definition
	    #
	    $def =~ s/\[[\S\s]+\]//;


	    #
	    # store the definition for this term
	    #
	    $terms->{$id}->{'def'} = $def;

	}
	elsif ($line =~ /^comment:\s*([\S\s]+)$/){
	    
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the comment
	    #
	    if (exists($terms->{$id}->{'comment'})){
		$logger->fatal("duplicate comment for '$id' found.  Will not insert again.  Is the OBO file corrupt?  Skipping...");
		next;
	    }
	    $terms->{$id}->{'comment'} = $1;
	}
	elsif ($line =~ /^is_a:\s*(\S+)/){
	    
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the is_a
	    #
	    push (@{$terms->{$id}->{'is_a'}},$1);
	}
	elsif ($line =~ /^alt_id:\s*(\S+)/){

	    #
	    # editor:   sundaram@tigr.org
	    # date:     Sat Nov  5 09:37:28 EST 2005
	    # bgzase:   2272
	    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2272
	    # comment:  Need to store alt_id in chado.cvterm_dbxref.
	    
	    
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the is_a
	    #
	    push (@{$terms->{$id}->{'alt_id'}},$1);
	}
	elsif ($line =~ /^synonym:\s*([\S\s]+)\s*$/){
	    
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the synonym
	    #
	    my $syn = $1;
	    $syn =~ s/\"//g;
	    #
	    # Comment out the next two lines if synonym field contains information in the trailing []
	    #
	    $syn =~ s/\[[\S\s]*\]//g;
	    $syn =~ s/\s*$//g;


	    $countall->{'synonym'}++;


	    push (@{$terms->{$id}->{'synonym'}},$syn);
	}
	elsif ($line =~ /^narrow_synonym:\s*\"([\S\s]+)\"\s*/){
	    
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the narrow_synonym
	    #
	    my $syn = $1;
	    $syn =~ s/\"//g;
	    #
	    # Comment out the next two lines if synonym field contains information in the trailing []
	    #
	    $syn =~ s/\[[\S\s]*\]//g;
	    $syn =~ s/\s*$//g;

	    $countall->{'narrow_synonym'}++;

	    push (@{$terms->{$id}->{'narrow_synonym'}},$syn);
	}
	elsif ($line =~ /^related_synonym:\s*([\S\s]+)\s*$/){
	    
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the related_synonym
	    #
	    my $syn = $1;
	    $syn =~ s/\"//g;
	    #
	    # Comment out the next two lines if synonym field contains information in the trailing []
	    #
	    $syn =~ s/\[[\S\s]*\]//g;
	    $syn =~ s/\s*$//g;

	    $countall->{'related_synonym'}++;

	    push (@{$terms->{$id}->{'related_synonym'}},$syn);
	}
	elsif ($line =~ /^exact_synonym:\s*([\S\s]+)\s*$/){
	    
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the exact_synonym
	    #
	    my $syn = $1;
	    $syn =~ s/\"//g;
	    #
	    # Comment out the next two lines if synonym field contains information in the trailing []
	    #
	    $syn =~ s/\[[\S\s]*\]//g;
	    $syn =~ s/\s*$//g;


	    $countall->{'exact_synonym'}++;

	    push (@{$terms->{$id}->{'exact_synonym'}},$syn);
	}
	elsif ($line =~ /^broad_synonym:\s*([\S\s]+)\s*$/){
	    
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the broad_synonym
	    #
	    my $syn = $1;
	    $syn =~ s/\"//g;
	    #
	    # Comment out the next two lines if synonym field contains information in the trailing []
	    #
	    $syn =~ s/\[[\S\s]*\]//g;
	    $syn =~ s/\s*$//g;

	    $countall->{'broad_synonym'}++;

	    push (@{$terms->{$id}->{'broad_synonym'}},$syn);
	}
	elsif ($line =~ /^relationship: (\S+)\s+(\S+).*/){
	    
	    #
	    # editor:   sundaram@tigr.org
	    # date:     2005-09-22
	    # bgzcase:  2142
	    # URL:      http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2142
	    # comment:  The script should continue to correctly parse the relationship field
	    #           inspite of the ! comment .
	    #

	    $logger->logdie("Could not parse line '$line'") if ((!defined($1)) or (!defined($2)));
	    #
	    # Get the relationship
	    #

	    $countall->{'relationship'}++;

	    push (@{$terms->{$id}->{$1}},$2);
	}
	elsif ($line =~ /^xref_analog:\s*([\S\s]+)$/){
	    
	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the xref_analog -- database cross-reference
	    # 

	    $countall->{'xref_analog'}++;

	    push (@{$terms->{$id}->{'xref_analog'}},$1);
	}
	elsif ($line =~ /^xref_unknown:\s*([\S\s]+)$/){
	    

	    $countall->{'xref_unknownctr'}++;

	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the xref_unknown
	    # 

	    $countall->{'xref_unknown'}++;

	    push (@{$terms->{$id}->{'xref_unknown'}},$1);
	}
	elsif ($line =~ /^subset:\s*(\S+)$/){
	    

	    $countall->{'subsetctr'}++;

	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the subset
	    # 
	    push (@{$terms->{$id}->{'subset'}},$1);

	    $countall->{'subset'}++;

	}
	elsif ($line =~ /^domain:\s*(\S+)$/){
	    
	    $countall->{'domainctr'}++;

	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the domain
	    # 
	    push (@{$terms->{$id}->{'domain'}},$1);

	    $countall->{'domain'}++;
	    
	}
	elsif ($line =~ /^range:\s*(\S+)$/){
	    
	    $countall->{'rangectr'}++;

	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the range
	    # 
	    push (@{$terms->{$id}->{'range'}},$1);

	    $countall->{'range'}++;

	}
	elsif ($line =~ /^is_transitive:\s*(\S+)$/){
	    
	    $countall->{'is_transitivectr'}++;

	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the is_transitive
	    # 
	    push (@{$terms->{$id}->{'is_transitive'}},$1);

	    $countall->{'is_transitive'}++;

	}
	elsif ($line =~ /^is_obsolete:\s*(\S+)$/){
	    
	    $countall->{'is_obsoletectr'}++;

	    $logger->logdie("Could not parse line '$line'") if (!defined($1));
	    #
	    # Get the is_obsolete
	    #
	    if ($1 eq 'true'){
		$terms->{$id}->{'is_obsolete'} = 1;
		$countall->{'is_obsolete'}++;
		$name_hash->{$name}->{'obsolete'}++;
#		$obsolete_hash->{$id}++;
	    }
	}
	elsif ($line =~ /^\s*$/){

	    $countall->{'blanklinectr'}++;
	}
	else{
	    

	    if ($line =~ /^xref_analog:/){
		die "line '$line\n";
	    }

	    $countall->{'dirtylinectr'}++;
	    
	    if ($line =~ /^(\S+):/){
		$dirtylines->{$1} = $1;
	    }
	    else{
		$logger->fatal("Unable to determine key for line '$line'");
	    }
   

	    push (@{$dirtylines->{'array'}}, $line);
	}



	#
	# Assurance that relation typedef
	# id's are not penetrating the terms lookup
	#
	if ($logger->is_debug){
	    foreach my $dd (sort keys %{$terms}){
		if ($dd eq 'derived_from'){
		    die "linectr '$countall->{'linectr'}' id '$id'";
		}
		if ($terms->{$dd}->{'name'} eq 'is_a'){
#		    die "linectr '$linectr' id '$id'";
		}
	    }
	}
    }


    
    #----------------------------------------------------------------------------------------------
    # editor:  sundaram@tigr.org
    # date:    2005-10-19
    # bgzcase: 2219
    # URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2219
    # comment: 
    #
    &check_duplicate_term_names($name_hash);
    #
    #----------------------------------------------------------------------------------------------




    #----------------------------------------------------------------------------------------------
    # editor:  sundaram@tigr.org
    # date:    2005-10-19
    # bgzcase: 2219
    # URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2219
    # comment: Sweep some code under the carpet...
    #
    &check_miscellaneous_counts($countall, $ontdoc, $obs_in_def, $dirtylines);
    #
    #----------------------------------------------------------------------------------------------
    

    return ($cv, $terms, $countall->{'term_ctr'}, $typedef);

       

}#end sub parse_ontology_file()



#--------------------------------------------------
# check_duplicate_term_names()
#
#--------------------------------------------------
sub check_duplicate_term_names {

    my $name_hash = shift;

    my $duplicate_term_name_ctr;

    foreach my $name ( sort keys %{$name_hash} ){

	my $namectr;
	
	if (( exists ($name_hash->{$name}->{'ctr'})) and (defined ($name_hash->{$name}->{'ctr'}))){
	    $namectr = $name_hash->{$name}->{'ctr'};
	
	    if ($namectr > 1 ){
		
		$duplicate_term_name_ctr++;
		
		my $obcount;
		if ((exists ($name_hash->{$name}->{'obsolete'})) and (defined($name_hash->{$name}->{'obsolete'})) ) {
		    
		    $obcount = $name_hash->{$name}->{'obsolete'};
		    if ($obcount =~ /\d+/){
			
			if (   $obcount <= $namectr  ) {
			    
			    $logger->info("Might be OK -- name '$name' occured '$namectr' times.  However, did detect '$obcount' obsoleted versions.");
			}
			else{
			    $logger->fatal("Not OK -- name '$name' occured '$namectr' times, but only detected '$obcount' obsoleted versions.");
			}
		    }
		    else{
			$logger->fatal("obcount '$obcount' was not numeric value for name '$name' namectr '$namectr'");
		    }
		}
		else{
		    $logger->fatal("Definite problems.  No obsolete versions for term '$name', yet occured in obo file '$namectr' times.");
		}
	    }
	}
	else{
	    $logger->warn("namectr did not exist for name '$name'");
	}
    }


    #----------------------------------------------------------------------------------------------
    # editor:  sundaram@tigr.org
    # date:    2005-10-19
    # bgzcase: 2219
    # URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2219
    # comment: Perform the check here, keep the variable local.
    #
    if ($duplicate_term_name_ctr > 0 ){
	$logger->warn("Some term name occured more than once in this obo file.  See '$log4perl'");
    }
    #
    #----------------------------------------------------------------------------------------------

}


#----------------------------------------------------------------------------------------------
#
#
# subroutine: check_miscellaneous_counts()
#
# editor:  sundaram@tigr.org
#
# date:    2005-10-19
#
# bgzcase: 2219
#
# URL:     http://serval.tigr.org:8080/bugzilla/show_bug.cgi?id=2219
#
# comment: Sweep some code under the carpet...
#
#
#
#----------------------------------------------------------------------------------------------
sub check_miscellaneous_counts {

    my $countall = shift;
    my $ontdoc   = shift;
    my $obs_in_def = shift;
    my $dirtylines = shift;

    
    if ($countall->{'typedefctr'} > 0){

	#
	# If not processing relation_typedef.obo and such [Typedef] records
	# are encountered, then inform the user:
	#
	
	my $file = basename($ontdoc);

	if ( ($file =~ /relation_typedef\.obo/)  || ($file =~ /relationship\.obo/)){
	    $logger->warn("Please make sure that you have processed (OBO2Chado.pl) the relation_typedef.obo ontology file and then loaded (chadoloader.pl) the output tab delimited BCP .out files into the target database BEFORE processing and loading any other ontology files.   The [Typedef] records present in any of the ontology files (other than relation_typedef.obo) will NOT be propagated into the target database.   This script has determined that you are not processing relation_typedef.obo and has detected the presence [Typedef] records in this ontology file ($ontdoc).   Please make sure that all of the valid [Typedef] records contained in the $ontdoc ontology file are present in the relation_typedef.obo ontology file AND were already loaded into the target database.   If not, then you need to add the [Typedef] records to the relation_typedef.obo file and then re-process (OBO2Chado.pl -b relation_typedef.obo) and update the target database (chadoloader.pl).  Here is a listing of the typedef records found in this $ontdoc ontology file\n:". Dumper $typedef);
	}
    }



    if ($countall->{'subsetctr'} > 0){
	$logger->info("What are we doing with \"subset\" information? counted '$countall->{'subsetctr'}' occurrences");
    }
    if ($countall->{'rangectr'} > 0){
	$logger->info("What are we doing with \"range\" information? counted '$countall->{'rangectr'}' occurrences");
    }
    if ($countall->{'is_obsoletectr'} > 0){
	$logger->info("Detected '$countall->{'is_obsoletectr'}' obsoleted records");
    }
    if ($countall->{'domainctr'} > 0){
	$logger->info("What are we doing with \"domain\" information? counted '$countall->{'domainctr'}' occurrences");
    }
    if ($countall->{'is_transitivectr'} > 0){
	$logger->info("What are we doing with \"is_transitive\" information? counted '$countall->{'is_transitivectr'}' occurrences");
    }
    if ($countall->{'dirtylinectr'} > 0){

    }
    if ($obs_in_def > 0){

    }
    if ($countall->{'xref_unknownctr'} > 0){
	$logger->info("What are we doing with \"xref_unknown\" information?  counted '$countall->{'xref_unknownctr'}' occurrences");
    }



}

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
#
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database, $pparse) = @_;

    if (!defined($pparse)){
	$pparse = 0;
    }

    my $prism;

    if (($pparse == 0) or ($pparse == 1)){


	$prism = new Prism( 
			    user             => $username,
			    password         => $password,
			    db               => $database,
			    use_placeholders => $pparse,
			    );

	$logger->fatal("prism was not defined") if (!defined($prism));

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

    print STDERR "SAMPLE USAGE:  $0 -U username -P password -b ontdoc -D database [-l log4perl] [-d debug_level] [-h] [-m] [-o outdir] [-p] [-y cache_dir]\n".
    "  -U|--username            = Username\n".
    "  -P|--password            = Password\n".
    "  -b|--ontdoc              = OBO ontology file to be parsed\n".
    "  -D|--database            = Target chado database\n".
    "  -l|--log4perl            = Optional - Log4perl log file (default: /tmp/OBO2Chado.pl.log)\n".
    "  -m|--man                 = Display pod2usage pages for this utility\n".
    "  -h|--help                = Display pod2usage help screen.\n".
    "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level (default level is 0)\n".
    "  -o|--outdir              = Optional - Output directory for tab delimited out files (default is current directory)\n".
    "  -p|--pparse              = Optional - Parallel parse (default is non-parallel parse)\n".
    "  -y|--cache_dir           = Optional - To turn on file-caching and specify directory to write cache files.  (Default no file-caching. If specified directory does not exist, default is environmental variable ENV{DBCACHE_DIR}\n";
    exit 1;

}

sub set_default_namespace {

    my ($dns, $basename, $file) = @_;

    if (($basename eq 'so.obo') &&
	($dns ne 'SO')){
	$logger->warn("Changing the default-namespace for file '$$file' from '$dns' to 'SO'");
	$dns = 'SO';
    }

    return $dns;
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
