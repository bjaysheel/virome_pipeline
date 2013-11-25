#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#-----------------------------------------------------------------------
# program:   generate_custome_cvterm_relationships.pl
# author:    Jay Sundaram
# date:      2005/05/09
# 
# purpose:   Generates BCP .out files containing custom 
#            cvterm_relationship records.
#
#-------------------------------------------------------------------------


=head1 NAME

generate_custom_cvterm_relationships.pl - Generates BCP .out files containing custom cvterm_relationship records.

=head1 SYNOPSIS

USAGE:  generate_custom_cvterm_relationships.pl -U username -P password -D database [-l log4perl] [-d debug_level] [-h] [-m] [-o outdir] [-p pparse]

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

=item B<--outdir,-o>

    Optional: Output directory for the tab delimited .out files.  Default is current directory

=item B<--pparse,-p>

    Optional: Parse use place holder functionality - supports parallel parsing by setting --pparse=1.  BCP .out files will contain Coati global placeholder vaariables.  (Default is no parallel parse --pparse=0)

=item B<--help,-h>

    Print this help

=back

=head1 DESCRIPTION

    generate_custom_cvterm_relationships.pl - Generates BCP .out files containing custom cvterm_relationship records.

    Assumptions:
    1. User has appropriate permissions (to execute script, access chado database, write to output directory).
    2. Target chado database already contains all reference features (necessary to build feature and organism lookups) Review and execute db2bsml.pl if required.
    3. Target chado database contains the necessary controlled vocabulary terms: "match" etc.
    4. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./generate_custom_cvterm_relationships.pl -U access -P access -D chado_test -o /usr/local/scratch/sundaram/chado_test/custom_cvterm_relationships


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

my ($username, $password, $database,  $debug_level, $help, $log4perl, $man, $outdir, $pparse);


my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'database|D=s'        => \$database,
			  'log4perl|l=s'        => \$log4perl,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'outdir|o=s'          => \$outdir,
			  'pparse|p=s'          => \$pparse,
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("username was not defined\n")   if (!$username); 
print STDERR ("password was not defined\n")   if (!$password);
print STDERR ("database was not defined\n")   if (!$database);

&print_usage if(!$username or !$password or !$database );

#
# initialize the logger
#
$log4perl = "/tmp/OBO2Chado.pl.log" if (!defined($log4perl));
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


print "\n";

my $custom = {
    'gene' => [	'part_of',
		'assembly'],
    'CDS' => ['derived_from',
	      'transcript'],
    'protein' => ['derived_from',
		  'CDS'],
    'signal_peptide' => ['part_of',
			 'protein']
};



$logger->debug("custom cvterm_relationships to be loaded:" . Dumper $custom) if $logger->is_debug();

$prism->store_custom_cvterm_relationships($custom);


#
# write to the tab delimited .out files
#
&write_to_outfiles($prism, $outdir);

#
# Notify of completion
#


print STDERR ("\nTab delimited .out files were written to directory '$outdir'\n");

$logger->info("Please verify log4perl log file: $log4perl");


#---------------------------------------------------------------------------------------------------------------------
#
#                                  END OF MAIN  -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------------------------------------



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
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database, $pparse) = @_;

    $logger->debug("Instantiating Prism object") if ($logger->is_debug());
    
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

    print STDERR "SAMPLE USAGE:  $0 -U username -P password -D database [-l log4perl] [-d debug_level] [-h] [-m] [-o outdir] [-p]\n".
    "  -U|--username            = Username\n".
    "  -P|--password            = Password\n".
    "  -D|--database            = Target chado database\n".
    "  -l|--log4perl            = Optional - Log4perl log file (default: /tmp/OBO2Chado.pl.log)\n".
    "  -m|--man                 = Display pod2usage pages for this utility\n".
    "  -h|--help                = Display pod2usage help screen.\n".
    "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level (default level is 0)\n".
    "  -o|--outdir              = Optional - Output directory for tab delimited out files (default is current directory)\n".
    "  -p|--pparse              = Optional - Parallel parse (default is non-parallel parse)\n";
    exit 1;

}
