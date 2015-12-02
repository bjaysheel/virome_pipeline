#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#-----------------------------------------------------------------------
# program:   externalAnnotation2Chado.pl
# author:    Jay Sundaram
# date:      2003/05/09
# 
# purpose:   Parses external annotation file and produces tab delimited files
#            for Bulkcopy into Chado database
#
#            Target Chado module: CV.  Tables affected are:
#            1) cvterm_dbxref
#            2) dbxref
#            3) db
#
#-------------------------------------------------------------------------


=head1 NAME

externalAnnotation2Chado.pl - Parse external annotation file and produces tab delimited .out files

=head1 SYNOPSIS

USAGE:  externalAnnotation2Chado.pl -U username -P password -D database -a annodoc [-l log4perl] [-d debug_level] [-h] [-m] [-o outdir] [-p]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--database,-D>
    
    Target chado database 

=item B<--annodoc,-a>
    
    External annotation file

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--outdir,-o>

    Optional: Output directory for the tab delimited .out files.  Default is current directory

=item B<--pparse,-p>

    Optional: Parse use place holder functionality - supports parallel parsing.  BCP .out files will contain Coati global placeholder vaariables.  Default is no parallel parse

=item B<--help,-h>

    Print this help

=back

=head1 DESCRIPTION

    externalAnnotation2Chado.pl - Parse external annotation file and produces tab delimited .out files
    Out files to be produced:
    1) cvterm_dbxref.out
    2) dbxref.out
    3) db.out


    Each file will contain new records to be inserted via the BCP utility into a chado database. (Use the loadSybaseChadoTables.pl script to complete this task.)
    Typical actions:
    1) Parse external annotation file (execute externalAnnotation2Chado.pl)
    2) Replace Coati::IdManager placeholder variables (execute replace_placeholders.pl)
    3) Validate master tab delimited .out files (execute any number of validate_*.pl utilities)
    4) Load the master tab delimited files into the target Chado database (execute loadSybaseChadoTables.pl)

    Assumptions:
    1. User has appropriate permissions (to execute script, access chado database, write to output directory).
    2. Target chado database already contains all reference features (necessary to build feature and organism lookups) Review and execute db2bsml.pl if required.
    3. Target chado database contains the necessary controlled vocabulary terms: "match" etc.
    4. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./externalAnnotation2Chado.pl -U access -P access -D tryp -a /usr/local/devel/ANNOTATION/go/external2go/metacyc2go  -l my.log -o /tmp/outdir


=cut


use strict;

no strict "refs";
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

my ($username, $password, $annodoc, $database,  $debug_level, $help, $log4perl, $man, $outdir, $pparse);


my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'annodoc|a=s'         => \$annodoc,
			  'database|D=s'        => \$database,
			  'log4perl|l=s'        => \$log4perl,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'outdir|o=s'          => \$outdir,
			  'pparse|p'            => \$pparse,

			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("username was not defined\n")   if (!$username); 
print STDERR ("password was not defined\n")   if (!$password);
print STDERR ("database was not defined\n")   if (!$database);
print STDERR ("annodoc was not defined\n")     if (!$annodoc);
print "\n";

&print_usage if(!$username or !$password or !$database or !$annodoc);

#
# initialize the logger
#
$log4perl = "/tmp/externalAnnotation2Chado.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


#
# verify and set the output directory
#
$outdir = &verify_and_set_outdir($outdir);

#
# Check mission critical file permissions
# 1) external annotation file

&is_file_readable($annodoc) if (defined($annodoc));

#
# Instantiate Prism object
#
my $prism = &retrieve_prism_object($username, $password, $database, $pparse);

#
# Get Sybase formatted date and time stamp
#
my $sybase_time = &retrieve_sybase_datetime_stamp();

#
# parse external annotation file
#
my ($mapping, $map_count, $version, $description) = &parse_annotation_file($prism, \$annodoc);
print "\n";

#
# Retrieve required db lookup
#
my ($dblookup) = &retrieve_db_lookup($prism);
print "\n";

#
# Retrieve required db lookup
#
my ($dbxref_id_lookup) = $prism->dbxref_id_lookup();
print "\n";

#
# Retrieve required lookup
#
my ($lookup) = &retrieve_lookups($prism);
print "\n";

#
# Retrieve required lookup
#
my ($lookup2) = &retrieve_cvterm_dbxref_lookup($prism);
print "\n";

#
# prepare the terms for producing tab delimited files
#
$prism->store_external_annotation_mappings(
					   mapping       => $mapping,
					   map_count     => $map_count,
					   version       => $version,
					   description   => $description,
					   lookup        => $lookup,
					   dblookup      => $dblookup,
					   dbxref_id_lookup      => $dbxref_id_lookup,
					   cvterm_dbxref_lookup => $lookup2,
					   );

#
# write to the tab delimited .out files
#
&write_to_outfiles($prism, $outdir);

#
# Notify of completion
#
print "\n";
$logger->info("'$0': Finished parsing ontology file: $annodoc");
print STDERR ("Tab delimited .out files were written to $outdir\n");

$logger->info("Please verify log4perl log file: $log4perl");


#---------------------------------------------------------------------------------------------------------------------
#
#                                  END OF MAIN  -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------------------------------------



#------------------------------------------------------
# retrieve_lookups()
#
#------------------------------------------------------
sub retrieve_lookups {

    $logger->debug("Entered retrieve_lookups") if $logger->is_debug;
    my ($prism) = @_;

    $logger->logdie("prism was not defined") if (!defined($prism));

        
    $logger->debug("Retrieving db.name, dbxref.accession and cvterm.definition from the database") if $logger->is_debug;

    my $data = $prism->ontology_lookup();

    $logger->logdie("data was not defined") if (!defined($data));
        
    my $lookup = {};


    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = scalar(@$data);
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);


    for(my $j=0;$j<scalar(@$data);$j++){
	
	$row_count++;
	$prism->show_progress("Building lookup $row_count/$total_rows",$counter,$row_count,$bars,$total_rows);

	my $accession  = $data->[$j]->{'accession'}  if (exists ($data->[$j]->{'accession'}));

	$lookup->{$accession}->{'cvterm_definition'} = $data->[$j]->{'definition'} if (exists ($data->[$j]->{'definition'}));
	$lookup->{$accession}->{'cvterm_id'}         = $data->[$j]->{'cvterm_id'}  if (exists ($data->[$j]->{'cvterm_id'}));
	$lookup->{$accession}->{'dbxref_id'}         = $data->[$j]->{'dbxref_id'}  if (exists ($data->[$j]->{'dbxref_id'}));
	$lookup->{$accession}->{'db_id'}             = $data->[$j]->{'db_id'}      if (exists ($data->[$j]->{'db_id'}));
	$lookup->{$accession}->{'db_name'}           = $data->[$j]->{'name'}       if (exists ($data->[$j]->{'name'}));

    }


    
    $logger->info("db.name, dbxref.accession, cvterm.definition lookup has been created");
    $logger->debug("db.name, dbxref.accession, cvterm.definition lookup is:\n" . Dumper($lookup)) if $logger->is_debug;
    
    

#    print Dumper $lookup;die;
    return $lookup;


}#end sub retrieve_lookups {



#------------------------------------------------------
# retrieve_cvterm_dbxref_lookup()
#
#------------------------------------------------------
sub retrieve_cvterm_dbxref_lookup {

    $logger->debug("Entered retrieve_cvterm_dbxref_lookup") if $logger->is_debug;
    my ($prism) = @_;

    $logger->logdie("prism was not defined") if (!defined($prism));

        
    $logger->debug("Retrieving cvterm_dbxref.cvterm_id and cvterm_dbxref.dbxref_id from the database") if $logger->is_debug;

    my $data = $prism->cvterm_dbxref_lookup();

    $logger->logdie("data was not defined") if (!defined($data));
        
    my $cvterm_dbxref_lookup = {};


    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = scalar(@$data);
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);


    for(my $j=0;$j<scalar(@$data);$j++){
	
	$row_count++;
	$prism->show_progress("Building cvterm_dbxref_lookup $row_count/$total_rows",$counter,$row_count,$bars,$total_rows);



	my $cvterm_id        = $data->[$j]->{'cvterm_id'}         if (exists ($data->[$j]->{'cvterm_id'}));
	my $dbxref_id        = $data->[$j]->{'dbxref_id'}         if (exists ($data->[$j]->{'dbxref_id'}));
	my $cvterm_dbxref_id = $data->[$j]->{'cvterm_dbxref_id'}  if (exists ($data->[$j]->{'cvterm_dbxref_id'}));

	my $cd = $cvterm_id ."_". $dbxref_id;

	if (!exists $cvterm_dbxref_lookup->{$cd}){
	    $cvterm_dbxref_lookup->{$cd} = $cd;
	}
	else{
	    $logger->warn("Duplicate cvterm_dbxref record detected for cvterm_dbxref_id '$cvterm_dbxref_id'");
	}
    }

    $logger->info("cvterm_dbxref.cvterm and cvterm_dbxref.dbxref_id values retrieved.  cvterm_dbxref_lookup has been created");
    $logger->debug("cvterm_dbxref_lookup is:\n" . Dumper($cvterm_dbxref_lookup)) if $logger->is_debug;
    
    return $cvterm_dbxref_lookup;


}#end sub retrieve_cvterm_dbxref_lookups {

#------------------------------------------------------------------------------------------------------------
# parse_annotation_file()
#
#------------------------------------------------------------------------------------------------------------
sub parse_annotation_file {

    my ($prism, $file) = @_;

    $logger->debug("Entered parse_annotation_file") if $logger->is_debug;

    open (INFILE, "<$$file") or $logger->logdie("Could not open $$file in read mode");

    my @contents;

    my $ctr=0;
    my $map = {};

    $logger->info("Reading in all contents of external annotation file $$file");
    @contents = <INFILE>;
    chomp @contents;
    
    my $id;
    my $version = undef;
    my $description = undef;
    my $linectr=0;



    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = scalar(@contents);
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);


    foreach my $line (@contents){
	
	$row_count++;
	$prism->show_progress("Parsing external annotation file $row_count/$total_rows",$counter,$row_count,$bars,$total_rows);

	$linectr++;


	$logger->debug("Processing line: $line") if $logger->is_debug;

	#
	# Header information gets parsed out
	# 
	if ($line =~ /^!/){
	    if (($line =~ /^!version:/) and ($line =~ /Revision/) and ($line =~ /(\d+\.\d*)/)){# \$Revision: 3145 $\s*$/){
		$version = $1;
		$logger->debug("version '$version'") if $logger->is_debug;
	    }
	
	    if (($line !~ /^!version/) and ($line !~ /^!date/) and ($line !~/^!Last update/)){
		if ($line =~ /^!([\S\s]+)/){
		    $description = $1;
		    $logger->debug("description '$description'") if $logger->is_debug;
		}
	    }
	}

	#
	# Process non-header lines
	#
	else{
	    #
	    # split the line to produce external and go
	    #
	    if ($line =~ />/){
		my ($ext, $go) = split(/\s*>\s*/, $line);
		if (!defined($ext)){
		    $logger->error("ext was not defined. Could not split line:$line");
		    next;
		}
		if (!defined($go)){
		    $logger->error("go was not defined. Could not split line:$line");
		    next;
		}

		$logger->debug("ext '$ext'\n".
			       "go '$go'") if $logger->is_debug;
		
		#
		# split the ext and produce ext.dbname, ext.accession and ext.definition
		#
		my ($ext_fullaccession, $ext_definition) = split(/\s*:\s*/, $ext);
		if (!defined($ext_definition)){
		    $logger->error("ext_definition was not defined.  Could not split $ext at line:$line");
		    next;
		}
		if (!defined($ext_fullaccession)){
		    $logger->error("ext_fullaccession was not defined.  Could not split $ext at line:$line");
		    next;
		}
		
		$logger->debug("ext_definition '$ext_definition'") if $logger->is_debug;
		$logger->debug("ext_fullaccession '$ext_fullaccession'") if $logger->is_debug;




		my ($ext_dbname, $ext_accession) = split(/:/, $ext_fullaccession);
		if (!defined($ext_dbname)){
		    $logger->error("ext_dbname was not defined.  Could not split $ext_fullaccession at line:$line");
		    next;
		}
		if (!defined($ext_accession)){
		    #
		    # Temp. solution to get around the inconsistent encoding style across the different annotation files
		    #
		    $ext_accession = $ext_definition;
		    if (!defined($ext_accession)){
			$logger->warn("ext_accession was not defined.  ext_dbname was set to '$ext_dbname'  ext_accession was set to '$ext_accession' Could not split ext_fullaccession '$ext_fullaccession' at line '$line' because there was no accession associated to the database name");
		    }
		    else{
			$logger->warn("ext_accession was set to '$ext_accession'");
		    }
		}

		$logger->debug("ext_dbname '$ext_dbname'\n".
			       "ext_accession '$ext_accession'") if $logger->is_debug;

		
		#
		# split the go and produce go.dbname, go.accession and go.definition
		#
		my ($go_definition, $go_fullaccession) = split(/\s*;\s*/, $go);
		if (!defined($go_definition)){
		    $logger->error("go_definition was not defined.  Could not split $go at line:$line");
		    next;
		}
		if (!defined($go_fullaccession)){
		    $logger->error("go_fullaccession was not defined.  Could not $go at line:$line");
		    next;
		}
		
		$logger->debug("go_definition '$go_definition'\n".
			       "go_fullaccession '$go_fullaccession'") if $logger->is_debug;



		my ($go_dbname, $go_accession) = split(/:/, $go_fullaccession);
		if (!defined($go_dbname)){
		    $logger->error("go_dbname was not defined.  Could not split $go_fullaccession at line:$line");
		    next;
		}
		if (!defined($go_accession)){
		    $logger->error("go_accession was not defined.  Could not $go_fullaccession at line:$line");
		    next;
		}


		$logger->debug("go_dbname '$go_dbname'\n".
			       "go_accession '$go_accession'") if $logger->is_debug;

		if (!exists $map->{$ext}){
		    $map->{$ext}->{'go_dbname'}      = $go_dbname;
		    $map->{$ext}->{'go_accession'}   = $go_accession;
		    $map->{$ext}->{'go_definition'}  = $go_definition;
		    $map->{$ext}->{'ext_dbname'}     = $ext_dbname;
		    $map->{$ext}->{'ext_accession'}  = $ext_accession;
		    $map->{$ext}->{'ext_definition'} = $ext_definition;
		    $ctr++;
		}


	    }
	    else{
		$logger->error("Could not parse line:$line");
		next;
	    }
	}

    }    
    $logger->debug("Processed $linectr lines in file $$file") if $logger->is_debug;
#    $logger->debug("map hash contains:" . Dumper($map)) if $logger->is_debug;

    my $fatalctr=0;

    if (!defined($version)){
	$logger->fatal("version was not defined");
	$fatalctr++;
    }
    if (!defined($description)){
	$logger->fatal("description was not defined");
	$fatalctr++;
    }
    if (!defined($map)){
	$logger->fatal("map was not defined");
	$fatalctr++;
    }
    $logger->logdie("Fatal errors detected.  Please see log file.") if ($fatalctr > 0);




    $description .= "-- Loaded via CAS:externalAnnotation2Chado.pl  source file: $$file";

    return ($map, $ctr, $version, $description);

       

}#end sub parse_ontology_file()


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

    print "\b"x(50);
    printf "%-50s", $string;

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
	    $outdir = "."; 
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

#---------------------------------------------
# retrieve_sybase_datetime_stamp()
#
#---------------------------------------------
sub retrieve_sybase_datetime_stamp {

    my ($self) = @_;

# perl localtime   = Tue Apr  1 18:31:09 2003
# sybase getdate() = Apr  2 2003 10:15AM
    
    $logger->debug("Creating Sybase formatted datetime") if ($logger->is_debug());


    my $datetime = localtime;
    #                  Day of Week                        Month of Year                                       Day of Month  Hour      Mins     Seconds    Year   
    if ($datetime =~ /^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)[\s]+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+([\d]{1,2})\s+([\d]{2}):([\d]{2}):[\d]{2}\s+([\d]{4})$/){
	my $hour = $4;
	my $ampm = "AM";
	if ($4 ge "13"){
	    
	    $hour = $4 - 12;
	    $ampm = "PM";
	}
	$datetime = "$2  $3 $6  $hour:$5$ampm";
    }
    else{
	$logger->fatal("Could not parse datetime");
	return;
    }


    $logger->debug("datetime:$datetime") if ($logger->is_debug());

    return \$datetime;

}#end sub sybase_datetime_stamp

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
# retrieve_db_lookup()
#
#------------------------------------------------------
sub retrieve_db_lookup {

    $logger->debug("Entered retrieve_db_lookup") if $logger->is_debug;
    my ($prism) = @_;

    $logger->logdie("prism was not defined") if (!defined($prism));

        
    $logger->debug("Retrieving db.db_id, db.name from the database") if $logger->is_debug;

    my $data = $prism->db_lookup();

    $logger->logdie("data was not defined") if (!defined($data));
        
    my $lookup = {};


    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = scalar(@$data);
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);


    for(my $j=0;$j<scalar(@$data);$j++){
	
	$row_count++;
	$prism->show_progress("Building db lookup $row_count/$total_rows",$counter,$row_count,$bars,$total_rows);

	$lookup->{$data->[$j]->{'name'}} = $data->[$j]->{'db_id'};

    }

    $logger->info("db.name, db.db_id lookup has been created");
    
#    print Dumper $lookup;die;
    return $lookup;


}#end sub retrieve_db_lookup {

#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -U username -P password -a annodoc -D database [-l log4perl] [-d debug_level] [-h] [-m] [-o outdir] [-p]\n";
    print STDERR "  -U|--username            = Username\n";
    print STDERR "  -P|--password            = Password\n";
    print STDERR "  -b|--annodoc             = External annotation file to be parsed\n";
    print STDERR "  -D|--database            = Target chado database\n";
    print STDERR "  -l|--log4perl            = Optional - Log4perl log file (default: /tmp/externalAnnotation2Chado.pl.log)\n";
    print STDERR "  -m|--man                 = Display pod2usage pages for this utility\n";
    print STDERR "  -h|--help                = Display pod2usage help screen.\n";
    print STDERR "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level (default level is 0)\n";    
    print STDERR "  -o|--outdir              = Optional - Output directory for tab delimited out files (default is current directory)\n";
    print STDERR "  -p|--pparse              = Optional - Parallel parse (default is non-parallel parse)\n";
    exit 1;

}
