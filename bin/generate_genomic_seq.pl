#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#------------------------------------------------------------------------------------------------
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# modifications:  Jay Sundaram 2004-02-10 post-merge adjustments
#                 1) introduced Coati::Logger log4perl logging and debug_level
#                 2) queryprint and debug removed
#                 3) pod2usage inserted
#
#
#                 This utility generates multi-fasta file containing protein sequences.
# 
# $Id: generate_genomic_seq.pl 3145 2006-12-07 16:42:59Z angiuoli $                 
#------------------------------------------------------------------------------------------------

=head1 NAME

generate_genomic_seq.pl - Generates multi-fasta file

=head1 SYNOPSIS

USAGE:  generate_genomic_seq.pl -U username -P password -D database -a asmbl_ids|ALL [-d debug_level] [-h] [-l log4perl] [-m] [-o output_dir]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--database,-D>
    
    Target chado database 

=item B<--asmbl_ids,-b>
    
    Comma separated list of assembly identifiers or ALL.   
    User can specify which  assemblies should be inserted into the multi-fasta file

=item B<--debug_level,-d>
    
    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--help,-h>

    Print help statement

=item B<--log4perl,-l>

    Optional:  Coati::Logger log4perl log file name.  
    Default is /tmp/generate_genomic_seq.pl.log

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--output_dir,-o>

    Optional: Output directory for the multi-fasta file.  
    Default is retrieved from the FASTA_REPOSITORY environmental variable

=back

=head1 DESCRIPTION

    generate_genomic_seq.pl - generates a multi-fasta which contains fasta formatted assembly sequences

    Assumptions:
    1. The BSML gene model encodings have been produced or will be produced in conjunction with the execution of this utility.
       generate_genomic_seq.pl does not require that the db2bsml.pl script have been previously executed.  The procedures 
       downstream of the execution of either scripts depends on the output of both.
    2. User has appropriate permissions (to execute script, access chado database, write to output directory).
    3. Target chado database already contains all reference features (necessary to build feature and organism lookups)
    4. All software has been properly installed, all required libraries are accessible.

    Sample usage:
    ./generate_genomic_seq.pl -U access -P access -D tryp -a ALL -l my.log -o /tmp/outdir


=cut




use strict;
use DBI;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use English;
use Prism;
use Coati::Logger;
use Pod::Usage;
use Data::Dumper;

my %options = ();
my $results = GetOptions (
			  \%options, 
			  'database|D=s',
			  'username|U=s',
			  'password|P=s',
			  'asmbl_ids|a=s',
			  'output_dir|o=s',
			  'debug_level|d=s',
			  'help|h',
			  'log4perl|l=s',
			  'man|m',
			  );

my $database    = $options{'database'};
my $user        = $options{'username'};
my $password    = $options{'password'};
my $asmbl_ids   = $options{'asmbl_ids'};
my $output_dir  = $options{'output_dir'};
my $log4perl    = $options{'log4perl'};
my $debug_level = $options{'debug_level'};
my $man         = $options{'man'};
my $help        = $options{'help'};

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

&print_usage() if(!$database or !$user or !$password or !$asmbl_ids or exists($options{'help'}));


#
# initialize the logger
#
$log4perl = "/tmp/generate_genomic_seq.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

#
# Instantiate Prism object
#
my $Prism = &retrieve_prism_object($user, $password, $database);


#
# Verify and set the output directory for the gene model documents
#
$output_dir = &verify_and_set_outdir($output_dir, $ENV{'FASTA_REPOSITORY'});


#
# Determine the asmbl_ids to process
#
my $asm_ids = &retrieve_asmbl_ids($asmbl_ids, $database);

#
# Create the multi-fasta file
#
&create_multifasta($asm_ids, $output_dir, $database);




$logger->info("'$0': Finished creating multifasta file");
$logger->info("Please verify log4perl log file: $log4perl");
print STDERR ("Tab multifasta file was written to directory: $output_dir\n");


#-----------------------------------------------------------------------------------------------------------------------------------
#
#     END OF MAIN -- SUBROUTINES FOLLOW
#
#-----------------------------------------------------------------------------------------------------------------------------------





#---------------------------------------------------------------
# create_multifasta()
#
#---------------------------------------------------------------
sub create_multifasta {


    $logger->debug("Entered create_multifasta") if $logger->is_debug;

    my ($asm_ids, $outdir, $db) = @_;

    my $fastafile = $outdir . "/" . $db . ".fsa";

    open (FASTA, ">$fastafile") or $logger->logdie("Can't open file $fastafile for writing: $!");

    foreach my $asmbl_id (@$asm_ids) {

	$logger->debug("processing assembly: $asmbl_id") if $logger->is_debug;

	my $asmbl_sequence = &get_asmbl_seq($asmbl_id);

	next if(!$asmbl_sequence);
	
	$asmbl_sequence =~ s/\>//g;
	
	if (!defined($asmbl_sequence)){
	    $logger->error("No assembly sequence was retrieved for assembly: $asmbl_id\nSkipping...");
	    next;
	} 
	else {
	    my $fasta_header = "$database"."_"."$asmbl_id";
	    my $fastaout = &fasta_out($fasta_header, $asmbl_sequence);
	    print FASTA $fastaout;
	}
    }

    close FASTA;
    chmod 0666, $fastafile;

}#end sub create_multifasta()


#-------------------------------------------------------------------------
# fasta_out()
#
#-------------------------------------------------------------------------
sub fasta_out {

    #This subroutine takes a sequence name and its sequence and
    #outputs a correctly formatted single fasta entry (including newlines).
    

    $logger->debug("Entered fasta_out") if $logger->is_debug;


    my ($seq_name, $seq) = @_;

    my $fasta=">"."$seq_name"."\n";
    $seq =~ s/\s+//g;
    for(my $i=0; $i < length($seq); $i+=60){
	my $seq_fragment = substr($seq, $i, 60);
	$fasta .= "$seq_fragment"."\n";
    }
    return $fasta;

}

#------------------------------------------------------------------------
# get_asmbl_seq()
#
#------------------------------------------------------------------------
sub get_asmbl_seq {

    #This subroutine returns the sequence of the assembly given asmbl_id
    #The returned data is a string representing the sequence of an asmbl_id

    $logger->debug("Entered get_asmbl_seq") if $logger->is_debug;

    my $asmbl_id = shift;

    my $result = $Prism->seq_id_to_description($asmbl_id);
    $logger->logdie("result was not defined") if (!defined($result));


    my $asmbl_seq = $result->[0]->{'sequence'} if ((exists $result->[0]->{'sequence'}) and (defined($result->[0]->{'sequence'})));

    return $asmbl_seq;

}


#---------------------------------------------------------------------
# retrieve_asmbl_ids()
#
#---------------------------------------------------------------------
sub retrieve_asmbl_ids {

    $logger->debug("Entered retrieve_asmbl_ids") if $logger->is_debug;

    my ($asmbl, $db) = @_;
    my @asmbids;

    if($asmbl ne 'ALL'){
	@asmbids = split(/,/, $asmbl);
    }
    elsif ($asmbl eq 'ALL') {
	
	my $result = $Prism->db_to_seq_names($db);
	$logger->logdie("result was not defined") if (!defined($result));

	for(my $i=0; $i<@$result; $i++) {
	    my $asmbl_id = $result->[$i]->{'seq_id'} if ((exists $result->[$i]->{'seq_id'}) and (defined($result->[$i]->{'seq_id'})));
	    push(@asmbids, $asmbl_id);
	}
#	print Dumper $result;die;

	$logger->debug("Retrieved the following assembly identifiers from database: $db:\n@asmbids\n") if $logger->is_debug;
    }

    return \@asmbids;

}#end retrieve_asmbl_ids()

#----------------------------------------------------------------
# retrieve_prism_object()
#
#
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database) = @_;

    $logger->debug("Instantiating Prism object") if ($logger->is_debug());
    
    my $prism = new Prism( 
			   user       => $username,
			   password   => $password,
			   db         => $database,
			   );
    
    $logger->fatal("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    

    return $prism;


}#end sub retrieve_prism_object()

#--------------------------------------------------------
# verify_and_set_outdir()
#
#
#--------------------------------------------------------
sub verify_and_set_outdir {

    my ( $outdir, $option) = @_;

    $logger->debug("Verifying and setting output directory") if ($logger->is_debug());

    #
    # strip trailing forward slashes
    #
    $outdir =~ s/\/+$//;
    
    #
    # set to current directory if not defined
    #
     if (!defined($outdir)){
	if (!defined($option)){
	    $outdir = "." 
	}
	else{
	    $outdir = $option;
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
    
    return $outdir;
    
}#end sub verify_and_set_outdir()



#---------------------------------------------------------------------
# print_usage()
#
#---------------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -U username -P password -D database -a asmbl_ids|ALL [-d debug_level] [-h] [-l log4perl] [-m] [-o output_dir]\n";
    print STDERR "  -U|--username    = Database username\n";
    print STDERR "  -P|--password    = Database password\n";
    print STDERR "  -D|--database    = Source chado database name\n";
    print STDERR "  -a|--asmbl_ids   = Comma separated list of assembly identifiers  or \"ALL\"\n";
    print STDERR "  -d|--debug_level = Coati::Logger log4perl logging level (0-5) Default is 0\n";
    print STDERR "  -h|--help        = This help message\n";
    print STDERR "  -l|--log4perl    = Coati::Logger log4perl log file name\n";
    print STDERR "  -m|--man         = Display the pod2usage help message\n";
    print STDERR "  -o|--output_dir  = Output directory to store the multi-fasta file.  Default directory is retrieved from FASTA_REPOSITORY environment variable\n";
    exit 1;

}
