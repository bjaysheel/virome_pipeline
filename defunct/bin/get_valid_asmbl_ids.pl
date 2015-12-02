#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#--------------------------------------------------------------------------------------
#
# $Id: get_valid_asmbl_ids.pl 2446 2006-01-03 17:14:37Z sundaram $
#
# program name:   legacy2bsml.pl
# authors:        Jay Sundaram
# date:           2004-06-02
# 
#
# Purpose:        Retrieve list of valid assembly identifiers from the source
#                 legacy annotation database
#
#---------------------------------------------------------------------------------------
=head1 NAME

get_valid_asmbl_ids.pl - Migrates Nt/Prok/Euk legacy databases to BSML documents

=head1 SYNOPSIS

USAGE:  get_valid_asmbl_ids.pl -U username -P password -D database [-d debug_level] -g organism [-l log4perl] [-h] [-m]

=head1 OPTIONS

=over 8

=item B<--username,-U>

Database username

=item B<--password,-P>

Database password

=item B<--database,-D>

Source legacy organism database name

=item B<--debug_level,-d>

Optional - Log4perl logging level (Default is 0)

=item B<--organism,-g>

Legacy annotation database for organism e.g. 'gbs'

=item B<--help,-h>

Print this help

=item B<--man,-m>

Display pod2usage man pages for this script

=item B<--log4perl,-l>

Optional - Log4perl log file.  Defaults are:
           If asmbl_list is defined /tmp/get_valid_asmbl_ids.pl.database_$database.asmbl_id_$asmbl_id.log
           Else /tmp/get_valid_asmbl_ids.pl.database_$database.pid_$$.log

=back

=head1 DESCRIPTION

euktigr2chado.pl - Migrates Euk legacy datasets to Chado schema

=cut

use strict;
use lib "shared";
use lib "Chado";
use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Config::IniFiles;
use Coati::Logger;

$| = 1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------
my ($database, $username, $password, $debug_level, $help, $man, $log4perl, $organism); 

my $results = GetOptions (
			  'username|U=s'       => \$username, 
			  'password|P=s'       => \$password,
			  'database|D=s'       => \$database,
			  'debug_level|d=s'    => \$debug_level,
			  'help|h'             => \$help,
			  'man|m'              => \$man,
			  'log4perl|l=s'       => \$log4perl,
			  'organism|g=s'       => \$organism
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("username was not defined\n")        if (!$username);
print STDERR ("password was not defined\n")        if (!$password);
print STDERR ("database was not defined\n")        if (!$database);

&print_usage if(!$username or !$password or !$database);


if (!defined($log4perl)){
    $log4perl = '/tmp/get_valid_asmbl_ids.pl.log';
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);



my @orglist;

if (!defined($organism)){
    $logger->logdie("organism was not defined");
}
else{
    @orglist = split(/,/, $organism);

}

#
# Instantiate new Prism reader object
#
my $prism = &retrieve_prism_object($username, $password, $database);


my $complist = {};

foreach my $org (sort @orglist){

    
    my ($asmbl_id) = $prism->all_valid_prok_asmbl_ids($org);

    push ( @{$complist->{$org}}, $asmbl_id->[0]);
#    print "org '$org' asmbl_id '$asmbl_ids->[0]'\n";
#    print Dumper $asmbl_ids;
}



foreach my $key (sort keys %{$complist} ){
    foreach my $asmbl (sort @{$complist->{$key}}) {
	print "Organism:$key\tasmbl_id:$asmbl\n";
    }
}




print ("Please verify log4perl log file: $log4perl\n");






#------------------------------------------------------------------------------------------------------------------------------------
#
#                END OF MAIN SECTION -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------------------------------

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


#----------------------------------------------------------------
# retrieve_prism_object()
#
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database) = @_;

    $logger->debug("Instantiating Prism object") if ($logger->is_debug());
    
    my $prism = new Prism(
			  user              => $username,
			  password          => $password,
			  db                => $database
			  );
    
    $logger->logdie("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    

    return $prism;


}#end sub retrieve_prism_object()


#-----------------------------------------------------------------
# print_usage()
#
#-----------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -D database -P password -U username [-d debug_level] -g organism [-h] [-l log4perl] [-m]\n".
    " -D|--database           = Source database name\n".
    " -P|--password           = login password for database\n".
    " -U|--username           = login username for database\n".
    " -d|--debug_level        = Optional - Coati::Logger log4perl logging level (Default is WARN)\n".
    " -g|--organism           = Optional - comma-separated (no spaces) list of organisms to validate\n".
    " -h|--help               = This help message\n".
    " -l|--log4perl           = Optional - Log4perl output filename (Default is /tmp/get_valid_asmbl_ids.pl.database_\$database.asmbl_id_\$asmbl_id.log)\n".
    " -m|--man                = Display the pod2usage pages for this script\n";

    exit 1;

}


