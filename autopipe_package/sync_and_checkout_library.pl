#!/usr/bin/perl
use strict;
use warnings;
use DBI;

################## sync_and_checkout_library.pl ###################
##                                                               ##
## This script syncs a directory on VIROME server at Delaware    ##
##  with a directory on DIAG -- assuring that all user-submitted ##
##  VIROME libraries are present.                                ##
##                                                               ##
## Script will then attempt to check out a processing database   ##
##  to begin to work on a given library.                         ##
##                                                               ##
## Author: Dan Nasko                                             ##
## Email:  dan.nasko@gmail.com                                   ##
###################################################################

## GLOBAL VARIABLES
my $root = '/diag/projects/virome/automated_pipeline_package/';
my $stderr_file = $root . 'logs/rsync.stderr';
my $stderr_log = $root . 'logs/rsync.log';
my $checkout_log = $root . 'logs/checkout.log';
my @RESULTS;
my ($lib_name,$lib_user,$lib_env,$lib_server,$file_type,$lib_seqmethod,$virome_lib_id);
my $available_database = '';
my $instantiator_script = '';
my $instant_dir = "/diag/projects/virome/automated_pipeline_package/ergatis/util/";
my $template_directory = "/diag/projects/virome/workflow/project_saved_templates/";
my $repository_root = "/diag/projects/virome/";
my $ergatis_ini = "/var/www/html/cgi/ergatis.ini";
my $id_repository = "/diag/projects/virome/workflow/project_id_repository/";

## Perform the rsync with VIROME server at Delaware
# print `rsync -zar --delete --exclude=/.* dnasko\@virome.dbi.udel.edu:/Volumes/sputnik/VIROME-USER-LIBRARIES/ /diag/projects/virome/user_metagenomes/ 2> $stderr_file`;
# my $stderr_size = -s $stderr_file;

print " rsync complete . . .\n";

# unless ( $stderr_size == 0 ) {     ## If rsync throws an error, email dan.nasko@gmail.com
#     print `ssh dnasko\@virome.dbi.udel.edu /Users/dnasko/automated_pipeline_package/rsync_email.pl`;
#     print `date >> $stderr_log`;
#     print `cat $stderr_file >> $stderr_log`;
#     print `rm $stderr_file`;
#     print `touch $stderr_file`;
# }

## Attempt to checkout a processing database and instantiate
##  a pipeline

## Setup MySQL configs
my $queue_host = q|virome.dbi.udel.edu|;
my $queue_db = q|virome_library_queue|;
my $queue_user = q|dnasko|;
my $queue_pwd = q|Scienz@9|;
my $dbh = DBI->connect("DBI:mysql:database=$queue_db;host=$queue_host",
		    "$queue_user", "$queue_pwd",{PrintError=>1, RaiseError =>1, AutoCommit =>1}) || die print STDERR("\nCould not open db connection\n");
my $live_host = q|virome-db.igs.umaryland.edu|;
my $live_db = q|virome|;
my $live_user = q|dnasko|;
my $live_pwd = q|dnas_76|;
my $lv_dbh = DBI->connect("DBI:mysql:database=$live_db;host=$live_host",
			  "$live_user", "$live_pwd",{PrintError=>1, RaiseError =>1, AutoCommit =>1}) || die print STDERR("\nCould not open db connection\n");
print " Connected to MySQL\n";

## Setup MySQL Queries
my $available_db_sql = qq|SELECT min(database_id) FROM processing_db_checkout WHERE status = "AVAILABLE"|;
     my $sth_avail = $lv_dbh->prepare($available_db_sql);
my $update_available_sql = qq|UPDATE processing_db_checkout SET status = "checked-out" WHERE database_id = ?|;
     my $sth_update = $lv_dbh->prepare($update_available_sql);
my $next_lib_sql = qq|SELECT min(queue_rank) FROM library_status WHERE moved_to_diag = 1 AND status = "pending"|;
     my $sth_next = $dbh->prepare($next_lib_sql);
my $get_lib_info = qq|SELECT library_name, username, file_name, num_sequences FROM library_status WHERE queue_rank = ? AND moved_to_diag = 1|;
     my $sth_get = $dbh->prepare($get_lib_info);
my $lib_info_sql = qq|SELECT id, environment, server, seqMethod FROM library WHERE name = ? AND user = ?|;
     my $sth_lib = $lv_dbh->prepare($lib_info_sql);
my $update_virome_queue = qq|UPDATE library_status SET status = "RUNNING" WHERE queue_rank = ?|;
     my $sth_upqu = $dbh->prepare($update_virome_queue);
my $assembled = qq|SELECT assembled, file_type FROM lib_summary WHERE libraryId = ?|;
     my $sth_assembled = $lv_dbh->prepare($assembled);

## Check to see if there's an available processing database
$sth_avail->execute();
while (@RESULTS = $sth_avail->fetchrow_array) {
    $available_database = $RESULTS[0];
}
print " Found an available processing database\n";

## If there is one . . . 
if ($available_database == 1 || $available_database == 2 || $available_database == 3 || $available_database == 4 || $available_database == 5) {
    $sth_next -> execute();                                                 ## Find the next library that should run
    my ($next_library_id) = $sth_next->fetchrow_array();
    if ($next_library_id) {                                                 ## If there was a library that should run
	$sth_update->execute($available_database);                          ## Check out that database
	$sth_get->execute($next_library_id);                                ## Gather more information on that library
	my ($lib_name,$lib_user,$lib_fileName,$sequences) = $sth_get->fetchrow_array();
	print " library name: $lib_name\n library user: $lib_user\n lib filename = $lib_fileName\n";
	$lib_fileName = "/diag/projects/virome/user_metagenomes" . $lib_fileName;
#       print "\n\n $available_database\t$lib_name\t$lib_user\t$lib_fileName\t$sequences\n\n";
	$sth_lib->execute($lib_name,$lib_user);
	while(@RESULTS = $sth_lib->fetchrow_array) {
	    $virome_lib_id = $RESULTS[0];
	    $lib_env = $RESULTS[1];
	    $lib_server = $RESULTS[2];
	    $lib_seqmethod = $RESULTS[3];
	}
	$sth_assembled->execute($virome_lib_id);
        my ($asm_flag,$file_type) = $sth_assembled->fetchrow_array();
        ## If assembled
	if ($asm_flag == 1 || $lib_seqmethod =~ m/sanger/i || $lib_seqmethod =~ m/illumina/i || $lib_seqmethod =~ m/pacbio/i || $lib_seqmethod =~ m/ion torrent/i) {
	    if ($file_type =~ m/FASTA/i){
		$template_directory = $template_directory . "/sanger-anyAssembled-fasta";
		$instantiator_script = "virome_sanger_anyAssembled_run_pipeline.pl ";
	    }
	    elsif ($file_type =~ m/FASTQ/i){
		$template_directory = $template_directory . "/sanger-anyAssembled-fastq";
		$instantiator_script = "virome_sanger_fastq_assembled_run_pipeline.pl ";
	    }
	}
	elsif ($asm_flag == 0 && $lib_seqmethod =~ m/454/ || $asm_flag == 0 && $lib_seqmethod =~ /other/i) {
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
	else {   die "\n\n Error: I cannot tell if this library was or wasn't assembled\n\n"}

	## INSTANTIATE AN ERGATIS PIPELINE
	my $instantiate = "perl " . $instant_dir . $instantiator_script
	    . "--template_directory=" . $template_directory 
	    . " --repository_root="   . $repository_root
	    . " --ergatis_ini="       . $ergatis_ini
	    . " --id_repository="     . $id_repository
	    . " --fasta="             . $lib_fileName
	    . " --library_id="        . $virome_lib_id
	    . " --database=diag"      . $available_database
	    . " --username="          . $lib_user
	    . " --sequences="         . $sequences
	    ;
	print `$instantiate`;
	$sth_upqu->execute($next_library_id);
    }    
}


#else {
#    print `echo '#-----------------------------------#' >> $checkout_log`;
#    print `date >> $checkout_log`;
#    print `echo ' No available databases for checkout ' >> $checkout_log`;
#}

