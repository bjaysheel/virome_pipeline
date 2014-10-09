#!/usr/bin/perl -w

# MANUAL FOR sync_and_run_library.pl

=pod

=head1 NAME

sync_and_run_library.pl -- make decisions and starts a VIROME ergatis pipeline

=head1 SYNOPSIS

 sync_and_run_library.pl --name="My Metagenome" --user="dnasko" --file="./Path/To/filname.fasta" --seqs=1000
                     [--help] [--manual]

=head1 DESCRIPTION

 This script will check to see that there is an available
 temporary DB and if so will instantiate an Ergatis pipeline.
 
=head1 OPTIONS

=over 3

=item B<-n, --name>=LIBNAME

Library name. (Required) 

=item B<-o, --user>=USER

Username. (Required) 

=item B<-f, --file>=FILENAME

Relative path to file. (Required)

=item B<-s,--seqs>=INT

Number of sequences in library. (Required)

=item B<-h, --help>

Displays the usage message.  (Optional) 

=item B<-m, --manual>

Displays full manual.  (Optional) 

=back

=head1 DEPENDENCIES

Requires the following Perl libraries.



=head1 AUTHOR

Written by Daniel Nasko, 
Center for Bioinformatics and Computational Biology, University of Delaware.

=head1 REPORTING BUGS

Report bugs to dnasko@udel.edu

=head1 COPYRIGHT

Copyright 2014 Daniel Nasko.  
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
my($name,$user,$file,$seqs,$help,$manual);

GetOptions (
    "n|name=s" => \$name,
    "u|user=s" => \$user,
    "f|file=s" => \$file,
    "s|seqs=i" => \$seqs,
    "h|help"   => \$help,
    "m|manual" => \$manual);

# VALIDATE ARGS
pod2usage(-verbose => 2)  if ($manual);
pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} )  if ($help);
pod2usage( -msg  => "\n\n ERROR!  Required argument -name not found.\n\n", -exitval => 2, -verbose => 1)  if (! $name );
pod2usage( -msg  => "\n\n ERROR!  Required argument -user not found.\n\n", -exitval => 2, -verbose => 1)  if (! $user);
pod2usage( -msg  => "\n\n ERROR!  Required argument -file not found.\n\n", -exitval => 2, -verbose => 1) if (! $file);
pod2usage( -msg  => "\n\n ERROR!  Required argument -seqs not found.\n\n", -exitval => 2, -verbose => 1) if (! $seqs);

## Globals
my $root = "/diag/project/virome";
my $auto_root = $root . "/automated_pipeline_package";
my $stderr_log = $auto_root . "/logs/rsync.log";
my $instant_dir = $auto_root . "/ergatis/util";
my $template_directory = $root . "/workflow/project_saved_templates";
my $ergatis_ini = "/var/www/html/cgi/ergatis.ini";
my $id_repository = $root . "/workflow/project_id_repository";
my @RESULTS;
my ($lib_name,$lib_user,$lib_env,$lib_server,$file_type,$lib_seqmethod,$virome_lib_id,$available_database,$instantiator_script) = ('','','','','','','','','');

##
## Rsync will go here.
##

## 
## Attempt to checkout a processing DB
## 
# my $live_host = q|virome-db.igs.umaryland.edu|;
# my $live_db = q|virome|;
# my $live_user = q|dnasko|;
# my $live_pwd = q|dnas_76|;
# my $lv_dbh = DBI->connect("DBI:mysql:database=$live_db;host=$live_host",
# 			  "$live_user", "$live_pwd",{PrintError=>1, RaiseError =>1, AutoCommit =>1}) || die print STDERR("\nCould not open db connection\n");

# my $available_db_sql = qq|SELECT min(database_id) FROM processing_db_checkout WHERE status = "AVAILABLE"|;
# my $sth_avail = $lv_dbh->prepare($available_db_sql);
# my $update_available_sql = qq|UPDATE processing_db_checkout SET status = "checked-out" WHERE database_id = ?|;
# my $sth_update = $lv_dbh->prepare($update_available_sql);

print "

Name = $name
User = $user
File = $file
Seqs = $seqs

";

exit 0;
