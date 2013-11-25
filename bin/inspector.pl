#!/usr/bin/perl                                                                                                                                                                                                                             

=head1 NAME                                                                                                                                                                                                                                 
                                                                                                                                                                                                                                            
inspector.pl - A script which inspects the outputs of a VIROME analysis pipeline                                                                                                                                              
to ensure everything is peachy.                                                                                                                                                                                                                  
                                                                                                                                                                                                                                            
=head1 SYNOPSIS                                                                                                                                                                                                                             
                                                                                                                                                                                                                                            
USAGE: inspector.pl                                                                                                                                                                                                 
            --library_id=200                                                                                                                                                                                         
            --proc_db_name=virome_processing3
            --repository_root=/diag/projects/virome
                                                                                                                                                                                                                                            
                                                                                                                                                                                                                                            
=head1 OPTIONS                                                                                                                                                                                                                              
                                                                                                                                                                                                                                            
B<--library_id,-i>                                                                                                                                                                                                                  
    The ID for the library which ran on the VIROME pipeline of interest.
                                                                                                                                                                                                                                            
B<--proc_db_name,-p>                                                                                                                                                                                                                     
    Name of the MySQL database that this pipeline used to process                                                                                                                                                                       
                                                                                                                                                                                                                                            
B<--repository_root,-r>
    The location of the project's repository

B<--help,-h>                                                                                                                                                                                                                                
    This help message                                                                                                                                                                                                                       
                                                                                                                                                                                                                                            
                                                                                                                                                                                                                                            
=head1  DESCRIPTION                                                                                                                                                                                                                         
                                                                                                                                                                                                                                            
This script was conceived as a reuslt of a frustrated man. After every VIROME pipeline it
alwasy seemed like at least one of the many outputs of a pipeline had an unnoticed issue.
This script checks each output of the pipeline to see if it looks sensible.
                                                                                                                                                                    
                                                                                                                                                                                                                                            
=head1  INPUT                                                                                                                                                                                                                               
                                                                                                                                                                                                                                            
Described in the options above, but the main input is the library ID, the MySQL processing
database that the library was analyzed on, and the project's repository root.
                                                                                                                                                                                                                                            
=head1  OUTPUT
                                                                                                                                                                                                                                            
This script will use the library ID to perform a thorough check of all outputs from the pipeline
and will DIE if there are too many problems, or throwing a simple warning to STDOUT if something
looks fishy, or pass just fine if everything was peachy.
                                                                                                                                                                                                                                            
=head1  CONTACT                                                                                                                                                                                                                             
                                                                                                                                                                                                                                            
    Daniel Nasko
    dan.nasko@gmail.com                                                                                                                                                                                                                    
                                                                                                                                                                                                                                            
=cut                                                                                                                                                                                                                                        

use strict;
use DBI;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use UTILS_V;

my ($library_id,$proc_db_name,$repository_root);
my %options = ();
my $results = GetOptions (\%options,
                          'library_id|l=s'	=>	\$library_id,
                          'proc_db_name|p=s'	=>	\$proc_db_name,
                          'repository_root|p=s'     =>      \$repository_root,
                          'help|h') || pod2usage();

## display documentation                                                                                                                                                                                                                    
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

## make sure everything passed was peachy
pod2usage( -msg  => "ERROR!  Required arguments -l and/or -p and/or -r not found.\n", -exitval => 0, -verbose => 2, -output => \*STDERR)  if (! $library_id || ! $proc_db_name || ! $repository_root);

my (%xDocs_sizes,%idFiles_sizes);
my $empty_files = 0;

my @xDocs = `ls -l $repository_root/virome-cache-files/xDocs/*_$library_id.xml`;
my @idFiles = `ls -l $repository_root/virome-cache-files/idFiles/*_$library_id.txt`;
if (! @xDocs) {   die "\n\n Inspector found an issue!\n There are no xDocs files for library $library_id\n\n Well, at least none under: $repository_root/virome-cache-files/xDocs/\n\n"}
if (! @idFiles) {   die "\n\n Inspector found an issue!\n There are no idFiles files for library $library_id\n\n Well, at least none under: $repository_root/virome-cache-files/idFiles/\n\n"}
foreach my $file (@xDocs) {
    chomp($file);
    $file =~ s/.*?\//\//;
    my $file_size = -s $file;
    $xDocs_sizes{$file} = $file_size;
}
foreach my $file (@idFiles) {
    chomp($file);
    $file =~ s/.*?\//\//;
    my $file_size = -s $file;
    $idFiles_sizes{$file} = $file_size;
}
foreach my $file (sort keys %xDocs_sizes) {
    if ($xDocs_sizes{$file} < 1000) {
        $empty_files++;
        print " $file APPEARS TO BE EMPTY IT IS $xDocs_sizes{$file} BYTES!\n";
    }
}
foreach my $file (sort keys %idFiles_sizes) {
    if ($idFiles_sizes{$file} == 0) {
        $empty_files++;
        print " $file APPEARS TO BE EMPTY IT IS $idFiles_sizes{$file} BYTES!\n";
    }
}
if ($empty_files >= 5) {
    die "

CRITICAL ERROR: INSPECTOR HAS FOUND $empty_files FILES WHICH IT
                BELIEVES TO BE EMPTY! Correct these and re-run.

";
}

#################################################################
##         Checking MySQL Processing Database Now . . .        ##
#################################################################
my $utils = new UTILS_V;
$utils->set_db_params($proc_db_name);

my $dbh = DBI->connect("DBI:mysql:database=".$utils->db_name.";host=".$utils->db_host, $utils->db_user, $utils->db_pass,{PrintError=>1, RaiseError =>1, AutoCommit =>1});

my $sequence_sql = qq|SELECT count(*) FROM sequence;|;
    my $sth_sequence = $dbh->prepare($sequence_sql);
my $blastp_sql = qq|SELECT count(*) FROM blastp;|;
    my $sth_blastp = $dbh->prepare($blastp_sql);
my $tRNA_sql = qq|SELECT count(*) FROM tRNA;|;
    my $sth_tRNA = $dbh->prepare($tRNA_sql);
my $sequence_relationship_sql = qq|SELECT count(*) FROM sequence_relationship;|;
    my $sth_sequence_relationship = $dbh->prepare($sequence_relationship_sql);
my $statistics_sql = qq|SELECT count(*) FROM statistics;|;
    my $sth_statistics = $dbh->prepare($statistics_sql);
my $blastp_tie_check = qq|SELECT count(*) FROM blastp WHERE sequenceId = 0;|;
    my $sth_blp_tie = $dbh->prepare($blastp_tie_check);

$sth_sequence->execute ();
    my ($sequence) = $sth_sequence->fetchrow_array();
$sth_blastp->execute ();
    my ($blastp) = $sth_blastp->fetchrow_array();
$sth_tRNA->execute ();
    my ($tRNA) = $sth_tRNA->fetchrow_array();
$sth_sequence_relationship->execute ();
    my ($sequence_relationship) = $sth_sequence_relationship->fetchrow_array();
$sth_statistics->execute ();
    my ($statistics) = $sth_statistics->fetchrow_array();
$sth_blp_tie->execute ();
    my ($tie_check) = $sth_blp_tie->fetchrow_array();

print "
sequence              = $sequence
blastp                = $blastp
tRNA                  = $tRNA
sequence_relationship = $sequence_relationship
statistics            = $statistics
";

if ($sequence == 0 || $blastp == 0 || $tRNA == 0 || $sequence_relationship == 0 || $statistics == 0) {
    die "
 CRITICAL ERROR: INSPECTOR HAS FOUND A SQL TABLE THAT IS EMPTY!!!
                 SEE ABOVE, AND FIX THIS!!!
";
}
if ($tie_check > 0 ) {
    die "
 CRITICAL ERROR: INSPECTOR HAS FOUND A sequenceId IN blastp THAT HAS
                 A VALUE OF 0!

";
}


exit 0;


