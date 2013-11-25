#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#-----------------------------------------------------------------------------------------------------
# $Id: generate_jaccard_organism_asmbl_files.pl 3145 2006-12-07 16:42:59Z angiuoli $
#
# Generates one organism file per organism loaded in the chado database.
# Each file contains a list of assembly bsml gene model documents assocated to that particular
# organism.
#
#-----------------------------------------------------------------------------------------------------


=head1 NAME

generate_jaccard_organism_asmbl_files.pl - Creates one file per organism in the chado database.  Each file contains a listing of the organism's associated gene model documents

=head1 SYNOPSIS

USAGE:  generate_jaccard_organism_asmbl_files.pl -D database -P password -U username [-d debug_level] [-h] [-l logfile] [-m] [-o directory]

=head1 OPTIONS

=over 8

=item B<--database,-D>
    
    Target database name

=item B<--password,-P>
    
    Database password

=item B<--username,-U>
    
    Database username

=item B<--debug_level,-d>
    
    Optional - Coati::Logger log4perl logging level (default is 0)

=item B<--help,-h>

    Print this help

=item B<--logfile,-l>
    
    Optional - Log4perl log file.  (default is /tmp/chadoloader.pl.log)

=item B<--man,-m>

    Display pod2usage man page for this utility

=item B<--directory,-o>
    
    Optional - Output directory for the organism files.  (default is currect working directory)

=back

=head1 DESCRIPTION

    generate_jaccard_organism_asmbl_files.pl - Creates one file per organism in the chado database.  Each file contains a listing of the organism's associated gene model documents
    e.g.
    1) ./generate_jaccard_organism_asmbl_files.pl -U sundaram -P sundaram6 -D chado_test

=head1 ASSUMPTIONS

    generate_jaccard_organism_asmbl_files.pl assumes that the BSML gene model documents are stored in the BSML repository i.e. /usr/local/annotation/PROJECT/BSML_repository
    where PROJECT is the name of the chado comparative database.

=head1 CONTACT

    sundaram@tigr.org

=cut


use Prism;
use Pod::Usage;
use Data::Dumper;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use File::Basename;
use Coati::Logger;
use Prism;

$|=1;

my ($username, $password, $database, $log4perl, $debug, $help, $man, $directory, $debug_level);

my $results = GetOptions (
			  'database|D=s'        => \$database,
			  'password|P=s'        => \$password,
			  'username|U=s'        => \$username,
			  'debug_level|d=s'     => \$debug_level,
			  'help|h'              => \$help, 
			  'logfile|l=s'         => \$log4perl,
			  'man|m'               => \$man,
			  'directory|o=s'       => \$directory
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);
  
print STDERR ("username not specified\n")  if (!$username);
print STDERR ("password not specified\n")  if (!$password);
print STDERR ("database not specified\n")  if (!$database);


&print_usage if(!$username or !$password or !$database);

#
# Initialize the logger
#
if (!defined($log4perl)){
    $log4perl = '/tmp/generate_jaccard_organism_asmbl_files.pl.log';
    print STDERR "log_file was set to '$log4perl'\n";
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

#
# verify and set the output directory
#
$directory = &verify_and_set_outdir($directory);


#
# Instantiate Prism object
#
my $prism = &retrieve_prism_object($username, $password, $database);



my $organism_assembly_hash = $prism->organism_2_assembly();


my $bsmlrepos = '/usr/local/annotation/' . uc($database) . '/BSML_repository';

foreach my $organism (sort keys %{$organism_assembly_hash} ){


    my $orgfile = $organism;
    $orgfile =~ s/\//_/g;

    my $outfile = $directory . '/' . $orgfile . '.dat';
    
    if (-e $outfile){
	my $bakfile = $outfile . '.bak';
	rename($outfile, $bakfile);
	$logger->info("Moved '$outfile' to '$bakfile'");
    }

    open (OUTFILE, ">$outfile") or $logger->logdie("Could not open file '$outfile':$!");


    foreach my $assembly (sort @{$organism_assembly_hash->{$organism}}){
    

	my $gene_model = $bsmlrepos . '/' . $assembly . '.bsml';
	print OUTFILE $gene_model . "\n";

	$logger->info("Wrote $gene_model to '$outfile'");

    }


}


print ("'$0': Program execution complete\n");
print ("Please review logfile: $log4perl\n");


#------------------------------------------------------------------------------------------------------------
#
#                                   END MAIN -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------

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
			   user             => $username,
			   password         => $password,
			   db               => $database,
			   use_placeholders => $pparse,
			   );
    
    $logger->logdie("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    

    return $prism;


}#end sub retrieve_prism_object()


#--------------------------------------------------------
# verify_and_set_outdir()
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
	    $logger->info("output directory was set to '$outdir'");
	}
    }

    $outdir .= '/';

    #
    # verify whether outdir is in fact a directory
    #
    $logger->logdie("$outdir is not a directory") if (!-d $outdir);

    #
    # verify whether outdir has write permissions
    #
    $logger->logdie("$outdir does not have write permissions") if ((-e $outdir) and (!-w $outdir));


    $logger->debug("outdir is set to:$outdir") if ($logger->is_debug());

    #
    # store the outdir in the environment variable
    #
    $ENV{OUTPUT_DIR} = $outdir;
    
    return $outdir;

}#end sub verify_and_set_outdir()

#--------------------------------------------------------------------
# print_usage()
#
#--------------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -D database -P password -U username [-d debug_level] [-h] [-l logfile] [-m] [-o directory]\n".
    "  -D|--database           = target Chado database\n".
    "  -P|--password           = password\n".
    "  -U|--username           = username\n".
    "  -d|--debug_level        = Optional - Coati::Logger log4perl logging level (default is 0)\n".
    "  -h|--help               = This help message\n".
    "  -l|--logfile            = Optional - log4perl log file (default is /tmp/chadoloader.pl.log)\n".
    "  -m|--man                = Display the pod2usage man page for this utility\n".
    "  -o|--directory          = Optional - directory to output the jaccard organism asmbl files (default is current working directory)\n";
    exit 1;

}

