#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#-----------------------------------------------------------------------
# program:   calculate_Cvtermpath.pl
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

Calculate_Cvtermpath.pl - Parse OBO formatted ontology files and prepares contents for insertion into tab delimited .out files

=head1 SYNOPSIS

USAGE:  Calculate_Cvtermpath.pl -U username -P password -D database -b ontdoc [-l log4perl] [-d debug_level] [-h] [-m] [-o outdir] [-p]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--database,-D>
    
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

    Optional: Parse use place holder functionality - supports parallel parsing.  BCP .out files will contain Coati global placeholder vaariables.  Default is no parallel parse

=item B<--help,-h>

    Print this help

=back

=head1 DESCRIPTION

    Calculate_Cvtermpath.pl - Parses OBO ontology file in and prepares tab delimited .out files for bulkcopy into chado CV module.
    Out files to be produced:
    1) cv.out
    2) cvterm.out
    3) cvterm_relationship.out
    4) cvtermsynonym.out
    5) cvterm_dbxref.out
    6) db.out
    7) dbxref.out


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
    ./Calculate_Cvtermpath.pl -U access -P access -D tryp -b /usr/local/scatch/sundaram/SequenceOntology/ontology/so.ontology.obo  -l my.log -o /tmp/outdir


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

my ($username, $password, $ontdoc, $database,  $debug_level, $help, $log4perl, $man, $outdir, $pparse);


my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
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


&print_usage if(!$username or !$password or !$database);

#
# initialize the logger
#
$log4perl = "/tmp/Calculate_Cvtermpath.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


#
# verify and set the output directory
#
$outdir = &verify_and_set_outdir($outdir);

#
# Instantiate Prism object
#
my $prism = &retrieve_prism_object($username, $password, $database, $pparse);

#
# retrieve all cvterm_relationship rows
#
my $termref = &retrieve_cvterm_relationship($prism);


#
# calculate all cvterm_relationships
#
my $tree = &calculate_cvterm_relationships($termref);

#
# write to the tab delimited .out files
#
&write_to_outfiles($prism, $outdir);

#
# Notify of completion
#
print "\n";
$logger->info("'$0': Finished parsing ontology file: $ontdoc");
print STDERR ("Tab delimited .out files were written to directory '$outdir'\n");

$logger->info("Please verify log4perl log file: $log4perl");


#---------------------------------------------------------------------------------------------------------------------
#
#                                  END OF MAIN  -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------------------------------------



#-------------------------------------------------------
# calculate_cvterm_relationships()
#
#-------------------------------------------------------
sub calculate_cvterm_relationships {


    $logger->debug("Entered calculate_cvterm_relationships") if $logger->is_debug;
    
    my ($terms) = @_;


    my $tree = {};


    foreach my $id (keys $%$terms){
	foreach my $id2 (keys %$terms){
	    if ($terms->{$id}->{'object'} == $terms->{$id2}){
		add_term($terms, $terms->{$id}, $terms->{$id2});
		
		$terms->{$id}->{'object'}->{'object'} = $terms->{$id2};
		$terms->{$id}->{'object'}->{'depth'} = $terms->{$id}->{'depth'} + 1;
	    }
	}
    }


    return $tree;


}#end sub prepare_terms()

#--------------------------------------------------------
# add_term()
#
#--------------------------------------------------------
sub add_term {

    my ($term, $parent, $child) = @_;

    




}#end sub add_term()



#------------------------------------------------------
# parse_ontology_file()
#
#------------------------------------------------------
sub parse_ontology_file {

    my ($prism, $file) = @_;

    $logger->debug("Entered parse_ontology_file") if $logger->is_debug;

    open (INFILE, "<$$file") or $logger->logdie("Could not open $$file in read mode");

    my @contents;


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
    
    foreach my $line (@contents){
	
	$row_count++;
	$prism->show_progress("Parsing OBO file $row_count/$total_rows",$counter,$row_count,$bars,$total_rows);
	
	#
	# Header information gets parsed out
	# 
	if ($line =~ /format-version:\s*(\S+)\s*$/){
	    $cv->{'format-version'} = $1;
	}
	
	if ($line =~ /date:\s*([\S\s]+)\s*$/){
	    $cv->{'date'} = $1;
	}
	
	if ($line =~ /saved-by:\s*([\S\s]+)\s*$/){
	    $cv->{'saved-by'} = $1;
	}
	
	if ($line =~ /auto-generated-by:\s*([\S\s]+)\s*$/){
	    $cv->{'auto-generated-by'} = $1;
	}
	
	if ($line =~ /default-namespace:\s*([\S\s]+)\s*$/){
	    $cv->{'default-namespace'} = $1;
	}
	


	#
	# Get the id
	#
	if ($line =~ /^id:\s*(\S+)$/){
	    
	    $id = $1;
	    
	    if (exists($terms->{$id})){
		$logger->fatal("duplicate id for $id found\nSkipping...");
		next;
	    }
	    $terms->{$id}->{'id'} = $id;
	    $term_ctr++;
	}
	
	
	#
	# Get the name
	#
	if ($line =~ /^name:\s*([\S\s]+)$/){
	    
	    if (exists($terms->{$id}->{'name'})){
		$logger->fatal("duplicate name for $id found\nSkipping...");
		next;
	    }
	    $terms->{$id}->{'name'} = $1;
	}
	
	#
	# Get the namespace
	#
	if ($line =~ /^namespace:\s*([\S\s]+)$/){
	    
	    if (exists($terms->{$id}->{'namespace'})){
		$logger->fatal("duplicate namespace for $id found\nSkipping...");
		next;
	    }
	    $terms->{$id}->{'namespace'} = $1;
	}
	
	
	#
	# Get the def
	#
	if ($line =~ /^def:\s*([\S\s]+)$/){
	    
	    my $def = $1;

	    if (exists($terms->{$id}->{'def'})){
		$logger->fatal("duplicate def for $id found\nSkipping...");
		next;
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
	
	
	#
	# Get the comment
	#
	if ($line =~ /^comment:\s*([\S\s]+)$/){
	    
	    if (exists($terms->{$id}->{'comment'})){
		$logger->fatal("comment for '$id' already exists\nSkipping...");
		next;
	    }
	    $terms->{$id}->{'comment'} = $1;
	    }
	
	
	#
	# Get the is_a
	#
	if ($line =~ /^is_a:\s*(\S+)$/){
	    
	    push (@{$terms->{$id}->{'is_a'}},$1);
	}
	
	
	#
	# Get the synonym
	#
	if ($line =~ /^synonym:\s*([\S\s]+)\s*$/){
	    
	    my $syn = $1;
	    $syn =~ s/\"//g;
	    #
	    # Comment out the next two lines if synonym field contains information in the trailing []
	    #
	    $syn =~ s/\[[\S\s]*\]//g;
	    $syn =~ s/\s*$//g;


	    push (@{$terms->{$id}->{'synonym'}},$syn);
	}
	
	#
	# Get the relationship: part_of
	#
	if ($line =~ /^relationship: part_of\s+(\S+)\s*$/){
	    
		push (@{$terms->{$id}->{'part_of'}},$1);

	    }
	
	    #
	# Get the relationship: part_of
	#
	if ($line =~ /^xref_analog:\s*(\S+)$/){
	    
	    push (@{$terms->{$id}->{'xref_analog'}},$1);
	}
	
    }
    
#    $logger->debug("cv hash contains:" . Dumper($cv)) if $logger->is_debug;
#    $logger->debug("terms hash contains:" . Dumper($terms)) if $logger->is_debug;
    

    return ($cv, $terms, $term_ctr);

       

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
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -U username -P password -b ontdoc -D database [-l log4perl] [-d debug_level] [-h] [-m] [-o outdir] [-p]\n";
    print STDERR "  -U|--username            = Username\n";
    print STDERR "  -P|--password            = Password\n";
    print STDERR "  -b|--ontdoc              = OBO ontology file to be parsed\n";
    print STDERR "  -D|--database            = Target chado database\n";
    print STDERR "  -l|--log4perl            = Optional - Log4perl log file (default: /tmp/Calculate_Cvtermpath.pl.log)\n";
    print STDERR "  -m|--man                 = Display pod2usage pages for this utility\n";
    print STDERR "  -h|--help                = Display pod2usage help screen.\n";
    print STDERR "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level (default level is 0)\n";    
    print STDERR "  -o|--outdir              = Optional - Output directory for tab delimited out files (default is current directory)\n";    
    print STDERR "  -p|--pparse              = Optional - Parallel parse (default is non-parallel parse)\n";
    exit 1;

}
