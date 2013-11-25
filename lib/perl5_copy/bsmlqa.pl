
#!/usr/local/bin/perl
#-----------------------------------------------------------------------
# program:   bsmlqa.pl
# author:    Jay Sundaram
# date:      2004/03/18
# 
# purpose:   Parses BSML documents and produces tab delimited .out BCP
#            files for insertion into Chado database

#
#-------------------------------------------------------------------------


=head1 NAME

bsmlqa.pl - Parse BSML document and produce tab delimited .out BCP files for insertion into Chado database

=head1 SYNOPSIS

USAGE:  bsmlqa.pl -D database -P password -U username -Z compute [-a autogen_feat] -b bsmldoc [-c analysis_id] [-d debug_level] [-h] [-i insert_new] [-l log4perl] [-m] [-o outdir] [-p] [-s autogen_seq] [-u update] [-x xml_schema_type] [-y cache_dir]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--database,-D>
    
    Target chado database 

=item B<--bsmldoc,-b>
    
    Bsml document containing pairwise alignment encodings

=item B<--autogen_feat,-a>
    
    Optional - Default behavior is to auto-generate (-a=1) chado feature.uniquename values for all inbound features.  To turn off behavior specify this command-line option (-a=0).

=item B<--autogen_seq,-s>
    
    Optional - Default behavior is to not (-s=0) auto-generate chado feature.uniquename values for all inbound sequences.  To turn on behavior specify this command-line option (-s=1).

=item B<--insert_new,-i>
    
    Optional - Default behavior is to insert (-i=1) insert newly encountered Sequence objects in the BSML document that are not currently present in the Chado database.  To turn off default insert behavior specify this command-line option (-i=0)

=item B<--analysis_id,-c>
    
    Optional -  analysis_id pre-assigned to the bsml document being processed.  If not provided, the bsml document is scanned for <Analysis> components (Supports workflow pre-parsing setup)

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--outdir,-o>

    Optional: Output directory for the tab delimited .out files.  Default is current directory

=item B<--pparse,-p>

    Optional - turn off parallel load support via global serial identifier replacement (default is ON)

=item B<--update,-u>

    Optional - Default behavior is to not update the database (-u=0).  To turn on update behavior specify this command-line option (-u=1).

=item B<--cache_dir,-y>

    Optional - Query caching directory to write cache files (default is ENV{DBCACHE_DIR})

=item B<--help,-h>

    Print this help

=item B<--compute,-Z>

    compute e.g. blastp, region, nucmer, promer

=back

=head1 DESCRIPTION

    bsmlqa.pl - Parse BSML document and produce tab delimited .out BCP files for insertion into Chado database

    Assumptions:
    1. The BSML pairwise alignment encoding should validate against the XML schema:.
    2. User has appropriate permissions (to execute script, access chado database, write to output directory).
    3. Target chado database already contains all reference features (necessary to build feature and organism lookups) Review and execute db2bsml.pl if required.
    4. Target chado database contains the necessary controlled vocabulary terms: "match" etc.
    5. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./bsmlqa.pl -U access -P access -D tryp -b /usr/local/annotation/TRYP/BSML_repository/blastp/lma2_86_assembly.blastp.bsml  -l my.log -o /tmp/outdir


=cut


use strict;

use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Digest::MD5 qw(md5);
use BSML::BsmlReader;
use BSML::BsmlParserSerialSearch;
use BSML::BsmlParserTwig;
use Coati::Logger;
use Config::IniFiles;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($username, $password, $bsmldoc, $database, $analysis_id, $debug_level, $help, $log4perl, $filter_count, $filter, $xml_schema_type, $man, $outdir, $autogen_feat, $autogen_seq, $insert_new, $pparse, $cache_dir, $update, $bsmldir, $compute);


my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'bsmldoc|b=s'         => \$bsmldoc,
			  'database|D=s'        => \$database,
			  'filter_count|r=s'    => \$filter_count,
			  'filter|t=s'          => \$filter,
			  'analysis_id|c=s'     => \$analysis_id,
			  'log4perl|l=s'        => \$log4perl,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'xml_schema_type|x=s' => \$xml_schema_type,
			  'outdir|o=s'          => \$outdir,
			  'autogen_feat|a=s'    => \$autogen_feat,
			  'autogen_seq|s=s'     => \$autogen_seq,
			  'insert_new|i=s'      => \$insert_new,
			  'pparse|p'            => \$pparse,
			  'cache_dir|y=s'       => \$cache_dir,
			  'update|u=s'          => \$update,
			  'bsmldir|B=s'         => \$bsmldir,
			  'compute|Z=s'         => \$compute
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("username was not defined\n")   if (!$username); 
print STDERR ("password was not defined\n")   if (!$password);
print STDERR ("database was not defined\n")   if (!$database);
print STDERR ("compute was not defined\n")    if (!$compute);

&print_usage if(!$username or !$password or !$database or !$compute);


$autogen_feat = 1 if (!defined($autogen_feat));
$insert_new   = 1 if (!defined($insert_new));


#
# If these variables are defined, they should be either 0 or 1
#
die ("autogen_feat '$autogen_feat' must be either 0 or 1\n") if (($autogen_feat !~ /^0|1$/) and (defined($autogen_feat)));
die ("autogen_seq '$autogen_seq' must be either 0 or 1\n")   if (($autogen_seq !~ /^0|1$/)  and (defined($autogen_seq)));
die ("insert_new '$insert_new' must be either 0 or 1\n")     if (($insert_new !~ /^0|1$/)   and (defined($insert_new)));
    
#
# If these variables are == 0, undefine them
#
$autogen_feat = undef if ($autogen_feat == 0);
$autogen_seq  = undef if ($autogen_seq == 0);
$insert_new   = undef if ($insert_new == 0);
$update       = undef if ($update == 0);

#
# initialize the logger
#
$log4perl = "/tmp/bsmlqa.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);




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







if (defined($analysis_id)){

    if ($analysis_id !~ /^\d+$/){
	$logger->logdie("analysis_id '$analysis_id' must be non-negative integer");
    }
 
    if ($analysis_id =~ /(\d+)/){
	$analysis_id = $1;
    }
    else{
	$logger->logdie("analysis_id '$analysis_id' must be a non-negative integer");
    }
  

    if ($analysis_id < 1){
	$logger->logdie("analysis_id '$analysis_id' must be greater than 0");
    }
}
#$logger->logdie("analysis_id '$analysis_id' must be a digit") if ((defined($analysis_id)) and ($analysis_id =~ /^\d+$/) and ($analysis_id > 0));
#die "analysis_id '$analysis_id'";


#
# verify and set the output directory
#
$outdir = &verify_and_set_outdir($outdir);

#
# Check permissions of the bsml document
#
&is_file_readable($bsmldoc) if (defined($bsmldoc));


#
# Get bsmldoclist
#
my $bsmldoclist = &get_bsmldoclist($bsmldir);



#
# Instantiate BsmlReader object
#
my $bsml_reader = &retrieve_bsml_reader();

#
# Instantiate Prism object
#
my $prism = &retrieve_prism_object($username, $password, $database, $pparse);

#
# Get Sybase formatted date and time stamp
#
my $sybase_time = $prism->get_sybase_datetime();


#
# Get organism hash
#
my $organismhash = &retrieve_organismhash($prism);

#
# Get assembly uniquename to seqlen hashref
#
my $type;
if ($compute eq 'region'){
    $type = 5;
}
elsif ($compute eq 'blastp'){
    $type = 16;
}

$logger->info("compute '$compute' was specified, building hashref for type '$type'");
my $seqlen = $prism->{_backend}->uniquename_to_seqlen_hashref($type);

#die "analysis_id '$analysis_id'";


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Serially parse BSML docuemnt
#
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
print "Parsing now...\n";

#
# BSML element counters
#
my $seq_pair_alignment_ctr = 0;
my $seq_pair_run_ctr = 0;
my $gap_ctr     = 0;

my $bsmlparser = new BSML::BsmlParserSerialSearch(
						  #-----------------------------------------------------------------------------------
						  # Alignment Callback 
						  #
						  #-----------------------------------------------------------------------------------
						  AlignmentCallBack => sub {
						      my ($alnref) = @_;
						      
						      $seq_pair_alignment_ctr++;
						      
						      #
						      # Retrieve the seq-pair-alignment object via the BsmlReader::readSeqPairAlignment method
						      #
						      my $spa = $bsml_reader->readSeqPairAlignment($alnref);
						      $logger->logdie("spa was not defined") if (!defined($spa));
						      
#
#						      print Dumper $spa;die;


						      my $refseq = $spa->{'refseq'};
						      my $compseq = $spa->{'compseq'};
						      


						      my $refseqlen  = $seqlen->{$refseq};
						      my $compseqlen = $seqlen->{$compseq};


						      #
						      # Get the seq-pair-runs and process
						      #
						      my $spr = $spa->{'seqPairRuns'};
						      $logger->fatal("spr was not defined\nseq-pair-alignment:\n" . Dumper($spa)) if (!defined($spr));
						      
						      #
						      # Get the number of seq-pair-runs associated to the seq-pair-alignment
						      #
						      my $seq_pair_run_record_count = @$spr;
						      $logger->fatal("seq_pair_run_record_count was not defined") if (!defined($seq_pair_run_record_count));
						      
						      



						      for (my $j=0; $j<$seq_pair_run_record_count; $j++){
							  
							  $seq_pair_run_ctr++;
							  &show_count("\n<Seq-pair-alignment> $seq_pair_alignment_ctr <Seq-pair-run> $seq_pair_run_ctr") if $logger->is_info;
							  
							  #
							  # Count and skip GAPs
							  #       
							  if (($spa->{'compseq'} eq 'GAP') || ($spa->{'refseq'} eq 'GAP')){
							      $gap_ctr++;
							      next;
							  }
							  
							  #
							  # Strip the arbitrary enumeration values
							  #
							  my $refseq = $spa->{'refseq'};
							  if ($refseq =~ /^\S+:(\S+)$/){
							      $refseq=$1;
							  }
							  

							  #-----------------------------------------------------------------------------------------------------------
							  # Perform the comparison
							  #
							  #-----------------------------------------------------------------------------------------------------------
							  
							  my $comprunlength  = $spr->[$j]->{'comprunlength'};
							  my $refpos         = $spr->[$j]->{'refpos'};
							  my $refcomplement  = $spr->[$j]->{'refcomplement'};
							  my $runlength      = $spr->[$j]->{'runlength'};
							  my $comppos        = $spr->[$j]->{'comppos'};
							  my $compcomplement = $spr->[$j]->{'compcomplement'};


							  #
							  # if not defined, assume dealing with forward strand (SA will make corrections such that
							  # refcomplement is mandatory in BSML documents)
							  #
							  $refcomplement = 0 if (!defined($refcomplement));

							  #
							  # Check the refseq
							  #

							  if ($refcomplement == 0){
							      $logger->debug("refcomplement = '$refcomplement' i.e. forward strand i.e. chado.featureloc.strand = 1") if $logger->is_debug;

							      if ($refseqlen >= $runlength + $refpos){
								  # ok
								  #  0                                        4000                            4800            5000
								  #  +----------------------------------------================================>---------------+
								  #
								  # refseqlen    = 5000
								  # runlength    = 800
								  # refpos       = 4000
								  #
							      }
							      else{
								  my $sum = $runlength +  $refpos;
								  $logger->fatal("refseqlen '$refseqlen' is not >= $sum (runlength '$runlength' + refpos '$refpos') for refseq '$refseq' compseq '$compseq'");
							      }
							  }
							  else{

							      $logger->debug("refcomplement = '$refcomplement' i.e. reverse strand i.e. chado.featureloc.strand = -1") if $logger->is_debug;

							      if (($refpos - $runlength) >= 0){
								  # ok
								  #  0                                        3200                     4000                   5000
								  #  +----------------------------------------<========================-----------------------+
								  #
								  # refseqlen    = 5000
								  # runlength    = 800
								  # refpos       = 4000
								  #
							      }
							      else{
								  my $diff = $refpos - $runlength;
								  $logger->fatal("$diff is not >= 0, runlength '$runlength' refpos '$refpos' don't make sense given refseqlen '$refseqlen' for refseq '$refseq' compseq '$compseq'");
							      }
							  }
							  
							  #
							  # Check the compseq
							  #
							  if ($compcomplement == 0){
							      $logger->debug("compcomplement = '$compcomplement' i.e. forward strand i.e. chado.featureloc.strand = 1") if $logger->is_debug;

							      if ($compseqlen >= $comprunlength + $comppos){
								  # ok
								  #  0                                        4000                            4800            5000
								  #  +----------------------------------------================================>---------------+
								  #
								  # compseqlen    = 5000
								  # comprunlength    = 800
								  # comppos       = 4000
								  #
							      }
							      else{
								  my $sum = $comprunlength + $comppos;
								  $logger->fatal("compseqlen '$compseqlen' is not >= $sum ( comprunlength '$comprunlength' + comppos '$comppos') for refseq '$refseq' compseq '$compseq'");
							      }
							  }
							  else{

							      $logger->debug("compcomplement = '$compcomplement' i.e. reverse strand i.e. chado.featureloc.strand = -1") if $logger->is_debug;

							      if (($comppos - $comprunlength) >= 0){
								  # ok
								  #  0                                        3200                     4000                   5000
								  #  +----------------------------------------<========================-----------------------+
								  #
								  # compseqlen    = 5000
								  # comprunlength    = 800
								  # compfpos       = 4000
								  #
							      }
							      else{
								  my $diff = $comppos - $comprunlength;
								  $logger->fatal("$diff is not >= 0, comprunlength '$comprunlength' comppos '$comppos' don't make sense given compseqlen '$compseqlen' for refseq '$refseq' compseq '$compseq'");
							      }
							  }



						      }
						  }
						  );

$logger->logdie("bsmlparser was not defined") if (!defined($bsmlparser));

foreach my $bsmlfile (@{$bsmldoclist}){
    $logger->info("Processing bsmlfile '$bsmlfile'");
    $bsmlparser->parse($bsmlfile);
}

$logger->info("bsmlqa detected:\n".
	      "'$seq_pair_alignment_ctr' <Seq-pair-alignment> elements\n".
	      "'$seq_pair_run_ctr' <Seq-pair-run> elements\n".
	      "'$gap_ctr' GAPS");
    

 
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Finished parsing the BSML document.  Now need to write to the tab delimited .out files and output in the outdir
#
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
$logger->info("Writing tab delimited .out files to directory: $outdir");
$prism->{_backend}->output_tables($outdir);
print "\n";

$logger->info("'$0': Finished processing BSML document '$bsmldoc'");
$logger->info("Please review the log file '$log4perl'");
print STDERR ("Tab delimited .out files were written to $outdir\n");



#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#
#                                  END OF MAIN  -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



#--------------------------------------------------------
# retrieve_master_feature_id_lookup()
#
#--------------------------------------------------------    
sub retrieve_master_feature_id_lookup {
    
    $logger->debug("Entered retrieve_master_feature_id_lookup") if $logger->is_debug;

    my $prism = shift;

    $logger->fatal("prism was not defined") if (!defined($prism));
	
    $logger->debug("Retrieving sequence/feature data from the database") if $logger->is_debug;

    my $ref = $prism->master_feature_id_lookup();

    $logger->fatal("ref was not defined") if (!defined($ref));
	
    my $lookup = {};

    for(my $j=0;$j<scalar(@$ref);$j++){
	$lookup->{$ref->[$j]->{'uniquename'}}->{'seqlen'}      = $ref->[$j]->{'seqlen'};
	$lookup->{$ref->[$j]->{'uniquename'}}->{'feature_id'}  = $ref->[$j]->{'feature_id'};
	$lookup->{$ref->[$j]->{'uniquename'}}->{'organism_id'} = $ref->[$j]->{'organism_id'};
	$lookup->{$ref->[$j]->{'uniquename'}}->{'chromosome'}  = $ref->[$j]->{'chromosome'};
	$lookup->{$ref->[$j]->{'uniquename'}}->{'name'}        = $ref->[$j]->{'name'};
	$lookup->{$ref->[$j]->{'uniquename'}}->{'md5'}         = $ref->[$j]->{'md5'};
    }	
    

    $logger->debug("Sequence reference lookup created") if $logger->is_debug;
    
    return $lookup;
    
}#end sub retrieve_seq_pair_feature_id_lookup()



#--------------------------------------------------------
# retrieve_seq_pair_feature_id_lookup()
#
#--------------------------------------------------------    
sub retrieve_seq_pair_feature_id_lookup {
    
    $logger->debug("Entered get_seq_ref_lookup") if $logger->is_debug;

    my $prism = shift;

    $logger->fatal("prism was not defined") if (!defined($prism));
	


    $logger->debug("Retrieving sequence data from the database") if $logger->is_debug;

    my $seq_ref = $prism->feature_orgseq();

    $logger->fatal("seq_ref was not defined") if (!defined($seq_ref));
	
    my $seq_ref_lookup = {};

    for(my $j=0;$j<scalar(@$seq_ref);$j++){
	$seq_ref_lookup->{$seq_ref->[$j]->{'uniquename'}}->{'seqlen'}      = $seq_ref->[$j]->{'seqlen'};
	$seq_ref_lookup->{$seq_ref->[$j]->{'uniquename'}}->{'feature_id'}  = $seq_ref->[$j]->{'feature_id'};
	$seq_ref_lookup->{$seq_ref->[$j]->{'uniquename'}}->{'organism_id'} = $seq_ref->[$j]->{'organism_id'};
    }	
    

    $logger->debug("Sequence reference lookup created") if $logger->is_debug;
    
    return $seq_ref_lookup;
    
}#end sub retrieve_seq_pair_feature_id_lookup()




#------------------------------------------------------------------
# retrieve_feature_id_lookup()
#
#
#------------------------------------------------------------------
sub retrieve_feature_id_lookup {
    
    my ( $prism) = @_;

    $logger->debug("prism was not defined") if ($logger->is_debug());

    $logger->fatal("prism was not defined") if (!defined($prism));
    
    my $feature_id_lookup = {};
    
    #
    # retrieve the hash containing feature.uniquename and feature.feature_id
    # from chado database
    #
    my $feature_ref = $prism->uniquename_2_feature_id();

    $logger->fatal("feature_ref was not defined") if (!defined($feature_ref));
    
    #
    # rearrange the datastructure
    #
    for(my $j=0;$j<scalar(@$feature_ref);$j++){
	$feature_id_lookup->{$feature_ref->[$j]->{'uniquename'}} = $feature_ref->[$j]->{'feature_id'};
    }	
    
    $logger->info("Feature_id_lookup constructed");
    

    return $feature_id_lookup;
    
}#end sub retrieve_feature_id_lookup()
    

#------------------------------------------------------
#  check_file_status()
#
#------------------------------------------------------
sub check_file_status {

    $logger->info("Entered check_file_status");

    my $file = shift;

    $logger->logdie("$$file was not defined") if (!defined($file));

    $logger->logdie("$$file does not exist") if (!-e $$file);
    $logger->logdie("$$file does not have read permissions") if ((-e $$file) and (!-r $$file));

}#end sub check_file_status()


#------------------------------------------------------
# show_count()
#
#------------------------------------------------------
sub show_count{
    
    $logger->info("Entered show_count");

    my $string = shift;
    $logger->logdie("string was not defined") if (!defined($string));

    print "\b"x(30);
    printf "%-30s", $string;

}#end sub show_count()


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

    $outdir .= '/';

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

#-----------------------------------------------------------------
# validate_bsmldoc()
#
#-----------------------------------------------------------------
sub validate_bsmldoc {
    
    my ( $doc, $schema) = @_;

    $logger->fatal("doc was not defined")    if (!defined($doc));
    $logger->fatal("schema was not defined") if (!defined($schema));

    $logger->debug("Validating the bsml document: $doc using schema: $schema") if ($logger->is_debug());


    my $validator = $ENV{SCHEMAVALID};
    $logger->fatal("validator was not defined") if (!defined($validator));
	
    $logger->info("Validating BSML document:$doc against XML schema: $schema");


    my $result;
    eval { 
	$result = qx{$validator -s $$schema $$doc};
    };
    if ($@){
	$logger->fatal("Error occured: $@");
    }
    if ($result){
	$logger->fatal("Validation failed:$result");
    }
    

}#end sub validate_bsmldoc()

#-----------------------------------------------------------------------------
# retrieve_bsml_reader()
#
#
#-----------------------------------------------------------------------------
sub retrieve_bsml_reader {

    my ($self) = @_;

    $logger->debug("Instantiating BsmlReader object") if ($logger->is_debug());

    my $bsmlreader = new BSML::BsmlReader();
    
    $logger->fatal("bsmlreader was not defined") if (!defined($bsmlreader));
    
    $logger->debug("bsmlreader:" . Dumper($bsmlreader)) if ($logger->is_debug());
    
    return $bsmlreader;

}#end sub retrieve_bsml_reader()


#----------------------------------------------------------------
# retrieve_prism_object()
#
#
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database, $pparse) = @_;

    $logger->debug("Instantiating Prism object") if ($logger->is_debug());
    
    if (defined($pparse)){
	$pparse = 0;
    }
    else{
	$pparse = 1;
    }


   my $prism = new Prism( 
			   user              => $username,
			   password          => $password,
			   db                => $database,
			   use_placeholders  => $pparse,
			   );
    
    $logger->fatal("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    

    return $prism;


}#end sub retrieve_prism_object()

#--------------------------------------------------------------------
# retrieve_mapping_hash()
#
#
#
#--------------------------------------------------------------------
sub retrieve_mapping_hash {

    my ( $file) = @_;

    $logger->debug("Retrieving compute mapping information from the mapping file...") if ($logger->is_debug());


    if (!defined($file)){

	$logger->debug("Using centrally installed mapping configuration file") if ($logger->is_debug());
	
	$file = $ENV{'COMPUTESINI'};

	$logger->fatal("mapping config file was not defined/centrally installed") if (!defined($file));
    }
    

    my $hash = new Config::IniFiles( -file => $file );

    $logger->fatal("hash was not defined") if (!defined($hash));

    $logger->debug("Compute mapping data hash:" . Dumper($hash)) if ($logger->is_debug());


    return $hash;
 
}#end sub retrieve_mapping_hash()


#------------------------------------------------------
# retrieve_score_mappings()
#
#
#------------------------------------------------------
sub retrieve_score_mappings {

    my ($compute_type, $compute_mapping_hash) = @_;

    #
    # Retrieve the compute mapping information
    #

    my $normscore        = $compute_mapping_hash->{'v'}->{$compute_type}->{'normscore'};
    my $rawscore         = $compute_mapping_hash->{'v'}->{$compute_type}->{'rawscore'};
    my $significance     = $compute_mapping_hash->{'v'}->{$compute_type}->{'significance'};
    my $percent_identity = $compute_mapping_hash->{'v'}->{$compute_type}->{'percent_identity'};
    
    
    $logger->fatal("normscore was not defined")        if (!defined($normscore));
    $logger->fatal("rawscore was not defined")         if (!defined($rawscore));
    $logger->fatal("significance was not defined")     if (!defined($significance));
    $logger->fatal("percent_identity was not defined") if (!defined($percent_identity));
    
    #
    # If user has not specified the filter and filter count, 
    # use the defaults present in the mapping config file
    #
    $logger->debug("before\nfilter_count:$filter_count\tfilter:$filter") if $logger->is_debug;
    
    if (!defined($filter_count)){
	$filter_count = $compute_mapping_hash->{'v'}->{$compute_type}->{'filter_count'} if (exists $compute_mapping_hash->{'v'}->{$compute_type}->{'filter_count'});
	$logger->fatal("filter_count was not defined") if (!defined($filter_count));
    }
    if (!defined($filter)){
	$filter = $compute_mapping_hash->{'v'}->{$compute_type}->{'filter'} if (exists $compute_mapping_hash->{'v'}->{$compute_type}->{'filter'});
	$logger->fatal("filter was not defined") if (!defined($filter));
    }
    
    $logger->debug("after\nfilter_count:$filter_count\tfilter:$filter") if $logger->is_debug;
    
    
    
    
    $logger->fatal("filter was not defined")                 if (!defined($filter));
    $logger->fatal("filter_count was not defined")           if (!defined($filter_count));



    $logger->debug("normscore '$normscore' rawscore '$rawscore' significance '$significance' percent_identity '$percent_identity' filter '$filter' filter_count '$filter_count'") if $logger->is_debug;
    return ($normscore, $rawscore, $significance, $percent_identity, $filter, $filter_count);

}#end sub retrieve_score_mappings()


#------------------------------------------------------------------
# retrieve_sequence_feature_id_lookup()
#
#
#------------------------------------------------------------------
sub retrieve_sequence_feature_id_lookup {

    $logger->debug("Entered retrieve_sequence_feature_id_lookup") if $logger->is_debug();

    my $chadowriter = shift;
    $logger->logdie("chadowriter was not defined") if (!defined($chadowriter));

    my $feature_id_lookup  = {};
    my $organism_id_lookup = {};


    $logger->info("Generating feature_id_lookup") if $logger->is_info();

#    my $feature_ref = $chadowriter->assembly_feature_id_lookup();
    my $feature_ref = $chadowriter->assembly_and_scaffold_feature_id_lookup();
    $logger->logdie("feature_ref was not defined") if (!defined($feature_ref));


    for(my $j=0;$j<scalar(@$feature_ref);$j++){
	
	my $chromosome  = $feature_ref->[$j]->{'chromosome'};
	my $uniquename  = $feature_ref->[$j]->{'uniquename'};
	my $feature_id  = $feature_ref->[$j]->{'feature_id'};
	my $organism_id = $feature_ref->[$j]->{'organism_id'};


	$feature_id_lookup->{$uniquename}->{'feature_id'} = $feature_id;
	$feature_id_lookup->{$uniquename}->{'chromosome'} = $chromosome;
	$feature_id_lookup->{$uniquename}->{'organism_id'} = $organism_id;
	
	$organism_id_lookup->{$feature_id} = $feature_ref->[$j]->{'organism_id'};
    }	

    $logger->info("Feature_id_lookup constructed") if $logger->is_info();
    
    return $feature_id_lookup, $organism_id_lookup;

}#end sub retrieve_sequence_feature_id_lookup()




#------------------------------------------------------------------
# retrieve_organismhash()
#
#
#------------------------------------------------------------------
sub retrieve_organismhash {

    $logger->debug("Entered retrieve_organismhash") if $logger->is_debug();

    my $chadowriter = shift;
    $logger->logdie("chadowriter was not defined") if (!defined($chadowriter));

    my $lookup  = {};

    $logger->info("Generating lookup") if $logger->is_info();

    my $ref = $chadowriter->organismhash();
    $logger->logdie("ref was not defined") if (!defined($ref));


    for(my $j=0;$j<scalar(@$ref);$j++){
	
	my $organism_id  = $ref->[$j]->{'organism_id'};
	my $genus        = $ref->[$j]->{'genus'};
	my $species      = $ref->[$j]->{'species'};


	my $key = $genus . '_' . $species;

	$lookup->{$key} = $organism_id;

    }	

    $logger->info("lookup constructed") if $logger->is_info();
    
    return $lookup;

}#end sub retrieve_sequence_feature_id_lookup()


#------------------------------------------------------
# show_count()
#
#------------------------------------------------------
sub show_count{
    
    $logger->info("Entered show_count");

    my $string = shift;
    $logger->logdie("string was not defined") if (!defined($string));

    print "\b"x(100);
    printf "%-100s", $string;

}#end sub show_count()



#------------------------------------------------------
# get_bsmldoclist()
#
#------------------------------------------------------
sub get_bsmldoclist {


    my $directory = shift;
    

    opendir(INDIR, "$directory") or $logger->logdie("Could not open directory '$directory' in read mode");
    
    my @bsmlfilelist = grep {$_ ne '.' and $_ ne '..' and $_ =~ /\S+\.bsml$/} readdir INDIR;


    my @goodlist;


    foreach my $file (@bsmlfilelist){
	my $fullpath = $directory . '/' . $file;
	push (@goodlist, $fullpath);
    }




    return \@goodlist;



}



#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -B bsmldir -D database -P password -U username -Z compute -b bsmldoc [-d debug_level] [-h] [-l log4perl] [-m] [-o outdir]\n";
    print STDERR "  -B|--bsmldir             = BSML_repository directory containing specified compute type BSML documents\n";
    print STDERR "  -D|--database            = Target chado database\n";
    print STDERR "  -P|--password            = Password\n";
    print STDERR "  -U|--username            = Username\n";
    print STDERR "  -b|--bsmldoc             = Bsml document containing pairwise alignment encodings\n";
    print STDERR "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level.  Default is 0\n";    
    print STDERR "  -h|--help                = Optional - Display pod2usage help screen\n";
    print STDERR "  -l|--log4perl            = Optional - Log4perl log file (default: /tmp/bsmlqa.pl.log)\n";
    print STDERR "  -m|--man                 = Optional - Display pod2usage pages for this utility\n";
    print STDERR "  -o|--outdir              = Optional - output directory for tab delimited BCP files (Default is current working directory)\n";
    exit 1;

}
