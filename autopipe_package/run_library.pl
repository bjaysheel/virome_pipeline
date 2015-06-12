#!/usr/bin/perl -w

# MANUAL FOR run_library.pl

=pod

=head1 NAME

run_library.pl -- Use info from Asana and run a library!

=head1 SYNOPSIS

 run_library.pl --name="Metagenome name!" --prefix=PRF --asm=0 --seqs=60000 --id=123 --technology=illumina
                     [--help] [--manual]

=head1 DESCRIPTION

 This is a script that should primarily be run by the asana Ruby
 script that preceeds it. It is used to figure out which
 instantiation script to run.
 
=head1 OPTIONS

=over 3

=item B<-n, --name>=NAME

Input library name. (Required)

=item B<-i, --id>=INT

Input library ID. (Required)

=item B<-p, --prefix>=NAME

Prefix. (Required) 

=item B<-f, --filename>=FILENAME

The path to the file for the next library. (Required)

=item B<-a, --asm>

Flag to indicate if assembled (default=NOT assembled)

=item B<-t, --technology>=TECH

Sequencing technology. (illumina, 454, sanger, pacbio, ion torrent)

=item B<-s, --seqs>=INT

Number of sequences in the library. (Required)

=item B<-h, --help>

Displays the usage message.  (Optional) 

=item B<-m, --manual>

Displays full manual.  (Optional) 

=back

=head1 DEPENDENCIES

Requires the following Perl libraries.

DBI

=head1 AUTHOR

Written by Daniel Nasko, 
Center for Bioinformatics and Computational Biology, University of Delaware.

=head1 REPORTING BUGS

Report bugs to dnasko@udel.edu

=head1 COPYRIGHT

Copyright 2015 Daniel Nasko.  
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.  
This is free software: you are free to change and redistribute it.  
There is NO WARRANTY, to the extent permitted by law.  

Please acknowledge author and affiliation in published work arising from this script's 
usage <http://bioinformatics.udel.edu/Core/Acknowledge>.

=cut


use strict;
use Getopt::Long;
use File::Basename;
use Pod::Usage;
use DBI;

#ARGUMENTS WITH NO DEFAULT
my($id,$name,$prefix,$seqs,$filename,$technology,$asm,$help,$manual);
GetOptions (
                         "n|name=s"     => \$name,
                         "i|id=i"       => \$id,
                         "p|prefix=s"   => \$prefix,
                         "a|asm"        => \$asm,
                         "s|seqs=i"     => \$seqs,
                         "f|filename=s" => \$filename,
                         "t|technology=s" => \$technology,
                         "h|help"       => \$help,
                         "m|manual"     => \$manual );

# VALIDATE ARGS
pod2usage(-verbose => 2)  if ($manual);
pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} )  if ($help);
pod2usage( -msg  => "\n\n ERROR!  Required argument --name not found.\n\n", -exitval => 2, -verbose => 1)      if (! $name     );
pod2usage( -msg  => "\n\n ERROR!  Required argument --prefix not found.\n\n", -exitval => 2, -verbose => 1)  if (! $prefix );
pod2usage( -msg  => "\n\n ERROR!  Required argument --seqs not found.\n\n", -exitval => 2, -verbose => 1)      if (! $seqs     );
pod2usage( -msg  => "\n\n ERROR!  Required argument --filename not found.\n\n", -exitval => 2, -verbose => 1)  if (! $filename );
pod2usage( -msg  => "\n\n ERROR!  Required argument --id not found.\n\n", -exitval => 2, -verbose => 1)      if (! $id     );
pod2usage( -msg  => "\n\n ERROR!  Required argument --technology not found.\n\n", -exitval => 2, -verbose => 1)      if (! $technology     );
$technology = lc($technology);
my %ValidPlatforms = ('illumina' => 1, '454' => 1, 'pacbio' => 1, 'ion torrent' => 1, 'sanger' => 1);
unless (exists $ValidPlatforms{$technology}) { die " Error: The sequencing technology provded is not valid: $technology\n\n"; }

## GLOBAL VARIABLES
my $root = '/diag/projects/virome/automated_pipeline_package/';
my $stderr_file = $root . 'logs/rsync.stderr';
my $stderr_log = $root . 'logs/rsync.log';
my $checkout_log = $root . 'logs/checkout.log';
my @RESULTS;
my ($lib_name,$lib_user,$lib_env,$lib_server,$file_type,$lib_seqmethod,$virome_lib_id);
$virome_lib_id=$id;
my $available_database = '';
my $instantiator_script = '';
my $instant_dir = "/diag/projects/virome/automated_pipeline_package/ergatis/util/";
my $template_directory = "/diag/projects/virome/workflow/project_saved_templates/";
my $repository_root = "/diag/projects/virome/";
my $ergatis_ini = "/var/www/html/cgi/ergatis.ini";
my $id_repository = "/diag/projects/virome/workflow/project_id_repository/";

print " rsync'ing with sipho.dbi.udel.edu . . .\n";
## Perform the rsync with VIROME server at Delaware
print `rsync -zar --delete --exclude=/.* dnasko\@sipho.dbi.udel.edu:/data/virome_user_libraries/ /diag/projects/virome/user_metagenomes/ 2> $stderr_file`;
# my $stderr_size = -s $stderr_file;
print "\t[ rsync complete ]\n";

print " connecting to virome-db . . .\n";
## Setup MySQL configs
my $live_host = q|virome-db.igs.umaryland.edu|;
my $live_db   = q|virome|;
my $live_user = q|dnasko|;
my $live_pwd  = q|dnas_76|;
my $lv_dbh    = DBI->connect("DBI:mysql:database=$live_db;host=$live_host",
			  "$live_user", "$live_pwd",{PrintError=>1, RaiseError =>1, AutoCommit =>1}) || die print STDERR("\nCould not open db connection\n");
print "\t[ connected to virome-db ]\n";

## Setup MySQL Queries
my $available_db_sql = qq|SELECT min(database_id) FROM processing_db_checkout WHERE status = "AVAILABLE"|;
     my $sth_avail = $lv_dbh->prepare($available_db_sql);
my $update_available_sql = qq|UPDATE processing_db_checkout SET status = "checked-out" WHERE database_id = ?|;
     my $sth_update = $lv_dbh->prepare($update_available_sql);
# my $lib_info_sql = qq|SELECT id, environment, server, seqMethod FROM library WHERE name = ? AND user = ? AND progress = "standby";|;
#      my $sth_lib = $lv_dbh->prepare($lib_info_sql);
# my $assembled = qq|SELECT assembled, file_type FROM lib_summary WHERE libraryId = ?|;
#      my $sth_assembled = $lv_dbh->prepare($assembled);

## Check to see if there's an available processing database
print " searching for processing DB . . .\n";
$sth_avail->execute();
while (@RESULTS = $sth_avail->fetchrow_array) {
    $available_database = $RESULTS[0];
}
print "\t[ using proc. DB $available_database ]\n";

## If there is one . . .
unless ($available_database == 1 || $available_database == 2 || $available_database == 3 || $available_database == 4 || $available_database == 5) {
    $lv_dbh->disconnect;
    die "\n There are no available databases!\n Something must have gone wrong!\n\n";
}
else {
    $sth_update->execute($available_database);                          ## Check out that database
    $filename = "/diag/projects/virome/user_metagenomes/" . $filename;
    # $sth_lib->execute($name,$username);
    # while(@RESULTS = $sth_lib->fetchrow_array) {
    # 	$virome_lib_id = $RESULTS[0];
    # 	$lib_env = $RESULTS[1];
    # 	$lib_server = $RESULTS[2];
    # 	$lib_seqmethod = $RESULTS[3];
    # }
#     print "
# lib name      = $name
# username      = $username
# lib id        = $virome_lib_id
# lib env       = $lib_env
# lib server    = $lib_server
# lib seqmethod = $lib_seqmethod

# ";
    my $file_type = "fasta";
    if ($filename =~ m/\.fastq/ || $filename =~ m/\.fq/) { $file_type = "fastq"; }

    ## If assembled
    if ( $asm ) {
	if ($file_type =~ m/FASTA/i){
	    $template_directory = $template_directory . "/sanger-anyAssembled-fasta";
	    $instantiator_script = "virome_sanger_anyAssembled_run_pipeline.pl ";
	}
	elsif ($file_type =~ m/FASTQ/i){
	    $template_directory = $template_directory . "/sanger-anyAssembled-fastq";
	    $instantiator_script = "virome_sanger_fastq_assembled_run_pipeline.pl ";
	}
    }
    elsif ( $technology eq "454" ) {
	if ($file_type =~ m/FASTA/i){
	    $template_directory= $template_directory ."454-fasta-unassembled";
	    $instantiator_script = "virome_454_fasta_unassembled_run_pipeline.pl ";
	}
	elsif ($file_type =~ m/sff/i) {
	    $template_directory= $template_directory ."454-sff-unassembled";
	    $instantiator_script = "virome_454_sff_unassembled_run_pipeline.pl ";
	}
	elsif ($file_type =~ m/FASTQ/i){
	    $template_directory= $template_directory ."454-fastq-unassembled";
	    $instantiator_script = "virome_454_fastq_unassembled_run_pipeline.pl ";
	}
    }
    elsif ( ! $asm ) {
	    if ($file_type =~ m/FASTA/i){
		$template_directory = $template_directory . "/sanger-anyAssembled-fasta";
		$instantiator_script = "virome_sanger_anyAssembled_run_pipeline.pl ";
	    }
	    elsif ($file_type =~ m/FASTQ/i){
		$template_directory = $template_directory . "/sanger-anyAssembled-fastq";
		$instantiator_script = "virome_sanger_fastq_assembled_run_pipeline.pl ";
	    }
    }
    else {   die "\n\n Error: I cannot tell if this library was or wasn't assembled\n\n"}
    
    ## INSTANTIATE AN ERGATIS PIPELINE
    my $instantiate = "perl " . $instant_dir . $instantiator_script
	. "--template_directory=" . $template_directory 
	. " --repository_root="   . $repository_root
	. " --ergatis_ini="       . $ergatis_ini
	. " --id_repository="     . $id_repository
	. " --fasta="             . $filename
	. " --library_id="        . $virome_lib_id
	. " --database=diag"      . $available_database
	. " --prefix="            . $prefix
	. " --sequences="         . $seqs
	;
    print `$instantiate`;
}

$lv_dbh->disconnect;

exit 0;
