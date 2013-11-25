#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#-----------------------------------------------------------------------
# program:   check_bsml2chado.pl
#
# author:    Jay Sundaram
#
# date:      2005/08/25
# 
# purpose:   Queries the analysis table and retrieves listing of analyses
#            and corresponding record counts in the computational
#            analysis module's tables.
#
#            Compares these record counts with BSML encodings.
#
#-------------------------------------------------------------------------


=head1 NAME

check_bsml2chado.pl - Evaluates the loaded record counts against the BSML encodings

=head1 SYNOPSIS

USAGE:  check_bsml2chado.pl -D database -P password -U username [-d debug_level] [-h] [-l log4perl] [-m]

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

    check_bsml2chado.pl - Evaluates the loaded record counts against the BSML encodings

    Assumptions:
    1. The BSML pairwise alignment encoding should validate against the XML schema:.
    2. User has appropriate permissions (to execute script, access chado database, write to output directory).
    3. Target chado database already contains all reference features (necessary to build feature and organism lookups) Review and execute db2bsml.pl if required.
    4. Target chado database contains the necessary controlled vocabulary terms: "match" etc.
    5. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./get_analysis.pl -U access -P access -D tryp -b /usr/local/annotation/TRYP/BSML_repository/blastp/lma2_86_assembly.blastp.bsml  -l my.log -o /tmp/outdir


=cut


use strict;
use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Digest::MD5 qw(md5);
# use BSML::BsmlReader;
# use BSML::BsmlParserSerialSearch;
# use BSML::BsmlParserTwig;
use Coati::Logger;
use Config::IniFiles;
use Benchmark;

$|=1;


#die '\$;';

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($username, $password, $database, $debug_level, $help, $log4perl, $man);


my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'database|D=s'        => \$database,
			  'log4perl|l=s'        => \$log4perl,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("database was not defined\n")   if (!$database);

$username = 'access' if (!defined($username));
$password = 'access' if (!defined($password));

&print_usage if(!$database);

#
# initialize the logger
#
$log4perl = "/tmp/check_bsml2chado.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


#
# Instantiate Prism object
#
#$ENV{DBCACHE} = undef;
$ENV{DBCACHE_DIR} = undef;
my $prism = &retrieve_prism_object($username, $password, $database);



my $computational_data = $prism->computational_data();

$logger->debug(Dumper $computational_data) if $logger->is_debug();



print "Comparing retrieved computational analysis record counts against BSML encodings\n";

foreach my $sourcename (sort keys % {$computational_data} ){


    $logger->info("Processing sourcename '$sourcename'");


    my $output_repository = $sourcename;

    $output_repository =~ s/Workflow/output_repository/;


    if (!-e $sourcename){
	$logger->fatal("$sourcename does not exist");
    }


    my $count;


    if (-d $sourcename){

	if (( exists $computational_data->{$sourcename}->{'program'}) && (defined ( $computational_data->{$sourcename}->{'program'}) ) ){

	    if ($computational_data->{$sourcename}->{'program'} =~ /blast/) {
		
		#-------------------------------------------------------------------------------
		# Pairwise encoding
		#
		#-------------------------------------------------------------------------------
		my $string = "find $output_repository -name \"*.bsml\" -exec grep \"<Seq-pair-run \" {} \\; |wc -l ";

		
		$logger->info($string);


		my $seq_pair_runs = qx{$string};


		#-------------------------------------------------------------------------------
		# Check //Seq-pair-run counts against chado.analysisfeature
		#
		#-------------------------------------------------------------------------------
		if ($count != $computational_data->{$sourcename}->{'analysisfeature'}){

		    $logger->fatal("BSML //Seq-pair-run count '$seq_pair_runs' does not match corresponding counts in chado.analysisfeature '$computational_data->{$sourcename}->{'analysisfeature'}'");
		}

		
		#-------------------------------------------------------------------------------
		# Check //Seq-pair-run counts against chado.feature
		#
		#-------------------------------------------------------------------------------
		if ($seq_pair_runs != $computational_data->{$sourcename}->{'feature'}){

		    $logger->fatal("BSML //Seq-pair-run count '$seq_pair_runs' does not match corresponding counts in chado.feature '$computational_data->{$sourcename}->{'feature'}'");
		}


	    }
	    elsif ($computational_data->{$sourcename}->{'program'} =~ /jaccard|cogs/)  {

		#-------------------------------------------------------------------------------
		# Multiple-alignment encoding
		#
		#-------------------------------------------------------------------------------




		#-------------------------------------------------------------------------------
		# Check //Sequence-alignment counts against chado.analysisfeature
		#
		#-------------------------------------------------------------------------------

		my $string = "find $output_repository -name \"*.bsml\" -exec grep \"<Sequence-alignment \" {} \\; | wc -l ";


		$logger->info($string);

		my $sequence_alignments = qx{$string};

		if ($sequence_alignments != $computational_data->{$sourcename}->{'analysisfeature'}){

		    $logger->fatal("BSML //Sequence-alignment counts '$sequence_alignments' does not match corresponding counts in chado.analysisfeature '$computational_data->{$sourcename}->{'analysisfeature'}'");
		}

		#-------------------------------------------------------------------------------
		# Check //Sequence-alignment counts against chado.feature
		#
		#-------------------------------------------------------------------------------
		if ($sequence_alignments != $computational_data->{$sourcename}->{'feature'}){

		    $logger->fatal("BSML //Sequence-alignment counts '$sequence_alignments' does not match corresponding counts in chado.feature '$computational_data->{$sourcename}->{'feature'}'");
		}


		#-------------------------------------------------------------------------------
		# Check the //Aligned-sequence counts against chado.featureloc
		#
		#-------------------------------------------------------------------------------

		my $string = "find $output_repository -name \"*.bsml\" -exec grep \"<Alignment-sequence \" {} \\; | wc -l ";


		$logger->info($string);


		my $aligned_sequences = qx{$string};

		if ($aligned_sequences != $computational_data->{$sourcename}->{'featureloc'}){

		    $logger->fatal("BSML //Aligned-sequence count '$aligned_sequences' does not match corresponding counts in chado.featureloc '$computational_data->{$sourcename}->{'featureloc'}'");
		}



	    }
	    else{
		$logger->fatal("Un-recognized computational program '$computational_data->{$sourcename}->{'program'}'");
	    }
	}
	else{
	    $logger->fatal("Program was not defined for sourcename '$sourcename'");
	}
    }
    else{
	$logger->fatal("Un-recognized sourcename type '$sourcename'");
    }
}


$logger->info("Please review the log file '$log4perl'");



#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#
#                                  END OF MAIN  -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#----------------------------------------------------------------
# retrieve_prism_object()
#
#
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database) = @_;

    $logger->debug("Instantiating Prism object") if ($logger->is_debug());
    

   my $prism = new Prism( 
			  user              => $username,
			  password          => $password,
			  db                => $database,
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

    print STDERR "SAMPLE USAGE:  $0 -D database [-P password] [-U username] [-d debug_level] [-h] [-l log4perl] [-m]\n".
    "  -D|--database            = chado database\n".
    "  -P|--password            = Optional - password (default is access)\n".
    "  -U|--username            = Optional - username (default is access)\n".
    "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level.  Default is 0\n".
    "  -h|--help                = Optional - Display pod2usage help screen\n".
    "  -l|--log4perl            = Optional - Log4perl log file (default: /tmp/check_bsml2chado.pl.log)\n".
    "  -m|--man                 = Optional - Display pod2usage pages for this utility\n";
    exit 1;

}
