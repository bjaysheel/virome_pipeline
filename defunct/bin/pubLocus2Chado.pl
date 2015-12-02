#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#--------------------------------------------------------------------------------------
# program name:   euktigr2chado.pl
# authors:        Jay Sundaram
# date:
#
# Purpose:        To migrate the eukaryotic organisms from legacy euk database
#                 schema into the chado schema
#
#---------------------------------------------------------------------------------------
=head1 NAME

euktigr2chado.pl - Migrates Euk legacy datasets to Chado schema

=head1 SYNOPSIS

USAGE:  euktigr2chado.pl -U username -P password -D source_database -t target_database -l log4perl [-a asmbl_id_list|ALL|-F asmbl_file] [-d] [-h] [-m] [-r outdir]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--source_database,-D>
    
    Source database name

=item B<--target_database,-t>
    
    Destination database name

=item B<--asmbl_id_list,-a>
    
    User must either specify a comma-separated list of assembly ids or "ALL"

=item B<--asmbl_file,-F>
    
    Optional  - file containing list of assembly identifiers

=item B<--help,-h>

    Print this help

=item B<--man,-m>

    Display pod2usage man pages for this script

=item B<--log4perl,-l>

    Log4perl log file

=item B<--outdir,-r>

    Output directory for .out tab delimited files

=item B<--debug,-d>

    Coati debug mode - disregard



=back

=head1 DESCRIPTION

    euktigr2chado.pl - Migrates Euk legacy datasets to Chado schema

=cut

use strict;
use lib "shared";
use lib "Chado";
no strict "refs";
use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Digest::MD5 qw(md5);
use Config::IniFiles;
use Coati::Logger;
use Benchmark;


#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($source_database, $target_database, $username, $password, $debug_level, $help, $man, $log4perl, $outdir); 

my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'source_database|D=s' => \$source_database,
			  'target_database|t=s' => \$target_database,
			  'debug_level|d=s'     => \$debug_level,
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'log4perl|l=s'        => \$log4perl,
			  'outdir|r=s'         => \$outdir,
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);
  
print STDERR ("username was not defined\n")        if (!$username);
print STDERR ("password was not defined\n")        if (!$password);
print STDERR ("target_database was not defined\n") if (!$target_database);
print STDERR ("source_database was not defined\n") if (!$source_database);

&print_usage if(!$username or !$password or !$target_database or !$source_database);


#
# initialize the logger
#
$log4perl = "/tmp/euktigr2chado.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


#
# verify and set the output directory
#
$outdir = &verify_and_set_outdir($outdir);

#
# Instantiate new Prism reader object
#
my $t2creader = &retrieve_prism_reader($username, $password, $source_database);

#
# Instantiate new Prism writer object
#
my $chado = &retrieve_prism_writer($username, $password, $target_database);


if (0){

    my ($asmbl_featname, $asmbl_id_list_ref) = $chado->asmbl_id_feat_name($source_database);

    my $publocushash = $t2creader->pub_locus_hash($asmbl_id_list_ref);

    #print Dumper $publocushash;die;

    $chado->store_pub_locus(
			    $asmbl_featname,
			    $publocushash
			    );
}
else{

    my ($asmbl_featname, $asmbl_id_list_ref) = $chado->asmbl_id_feat_name_for_update($source_database);


#    print Dumper $asmbl_featname;die;

    my $publocushash = $t2creader->pub_locus_hash($asmbl_id_list_ref);

#    print Dumper $publocushash;die;

    $chado->update_pub_locus(
			     $asmbl_featname,
			     $publocushash
			     );
}



#
# write to the tab delimited .out files
#
&write_to_outfiles($chado, $outdir);
print "\n";

$logger->info("'$0': Finished migrating data from $source_database to $target_database");
$logger->info("Please verify log4perl log file: $log4perl");
print STDERR ("Tab delimited .out files were written to $outdir\n");


#------------------------------------------------------------------------------------------------------------------------------------
#
#                END OF MAIN SECTION -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------------------------------

#----------------------------------------------------------------
# retrieve_prism_writer()
#
#
#----------------------------------------------------------------
sub retrieve_prism_writer {

    my ( $username, $password, $database) = @_;

    $logger->debug("Instantiating Prism writer") if ($logger->is_debug());
    
    my $prism = new Prism( 
			   user       => $username,
			   password   => $password,
			   db         => $database,
			   use_config => $ENV{'WRITER_CONF'},
			   );
    
    $logger->fatal("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    

    return $prism;


}#end sub retrieve_prism_writer()



#----------------------------------------------------------------
# retrieve_prism_reader()
#
#
#----------------------------------------------------------------
sub retrieve_prism_reader {

    my ( $username, $password, $database) = @_;

    $logger->debug("Instantiating Prism reader") if ($logger->is_debug());
    
    my $prism = new Prism( 
			   user       => $username,
			   password   => $password,
			   db         => $database,
			   );
    
    $logger->fatal("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());



    return $prism;


}#end sub retrieve_prism_reader()




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


    $outdir = $outdir . '/';

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


#--------------------------------------------------------------
# write_to_outfiles() 
#
#
#--------------------------------------------------------------
sub write_to_outfiles {

    my ( $writer, $outdir ) = @_;

    $logger->debug("Entered write_to_outfiles") if ($logger->is_debug());

    $logger->fatal("writer was not defined") if (!defined($writer));

    #
    # Output the datasets to file and/or batch load into database 
    #

    $logger->info("Writing tab delimited .out files to directory: '$outdir'");

    $writer->{_backend}->output_tables($outdir);

}#end sub write_to_outfiles()



#-----------------------------------------------------------------
# print_usage()
#
#-----------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -U username -P password -D source_database -t target_database [-l log4perl] [-a asmbl_id_list | ALL | -F asmbl_file] [-d debug_level] [-h] [-m] [-r outdir]\n";
    print STDERR "  -- U|username           = login username for database\n";
    print STDERR "  -- P|password           = login password for database\n";
    print STDERR "  -- D|source_database    = source database name\n";
    print STDERR "  -- t|target_database    = target database name\n";
    print STDERR "  -- a|asmbl_id_list      = list of assembly idenitifiers\n"; 
    print STDERR "  -- F|asmbl_file         = file containing list of assembly ids\n";
    print STDERR "  -- l|log4perl           = Log4perl output filename\n";
    print STDERR "  -- d|debug_level        = Coati::Logger log4perl logging level\n";
    print STDERR "  -- h|help               = This help message\n";
    print STDERR "  -- r|outdir             = Output directory for the tab delmitied .out files\n";
    print STDERR "  -- m|man                = Display the pod2usage pages for this script\n";
    exit 1;

}

