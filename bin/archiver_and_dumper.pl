#!/usr/bin/perl                                                                                                                                                                                                                             

=head1 NAME                                                                                                                                                                                                                                 
                                                                                                                                                                                                                                            
archiver_and_dumper.pl - A script which archives and mysqldumps the outputs of a VIROME 
analysis pipeline.
                                                                                                                                                                                                                                            
=head1 SYNOPSIS                                                                                                                                                                                                                             
                                                                                                                                                                                                                                            
USAGE: archiver_and_dumper.pl                                                                                                                                                                                                 
            --library_id=200                                                                                                                                                                                          
            --location=diag3
            --repository_root=/diag/projects/virome
            --username=ewommack
            --pipeline=9E4C8FA05632
                                                                                                                                                                                                                                            
=head1 OPTIONS                                                                                                                                                                                                                              
                                                                                                                                                                                                                                            
B<--library_id,-i>                                                                                                                                                                                                                  
    The ID for the library which ran on the VIROME pipeline of interest.
                                                                                                                                                                                                                                            
B<--location,-l>                                                                                                                                                                                                                     
    The location that this pipeline was run at.                                                                                                                                                                       
                                                                                                                                                                                                                                            
B<--repository_root,-r>
    The location of the project's repository.

B<--username,-u>
    The username for user who owns this library

B<--pipeline,-p>
    The pipeline ID for this pipeline running

B<--help,-h>                                                                                                                                                                                                                                
    This help message                                                                                                                                                                                                                       
                                                                                                                                                                                                                                            
                                                                                                                                                                                                                                            
=head1  DESCRIPTION                                                                                                                                                                                                                         
                                                                                                                                                                                                                                            
This script was conceived as a result of a frustrated man. It will archive various outputs
from the pipeline by creating a tarball and scp'ing this to a server in Delaware. Script
will then mysqldump the processing database. Script also UPDATES lib_summary table to
give it the correct number of ORFs.
                                                                                                                                                                    
                                                                                                                                                                                                                                            
=head1  INPUT                                                                                                                                                                                                                               
                                                                                                                                                                                                                                            
Described in the options above, but the main input is the library ID, the location
of where the library was analyzed, and the project's repository root, and the username,
and the pipeline ID.
                                                                                                                                                                                                                                            
=head1  OUTPUT
                                                                                                                                                                                                                                            
This script will output a tarball which will be scp'd to a local server at Delaware and
will also output the mysqldump files for the ensuing mysqlimport.
                                                                                                                                                                                                                                            
=head1  CONTACT                                                                                                                                                                                                                             
                                                                                                                                                                                                                                            
    Daniel Nasko
    dan.nasko@gmail.com                                                                                                                                                                                                                    
                                                                                                                                                                                                                                            
=cut                                                                                                                                                                                                                                        

use strict;
use DBI;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use UTILS_V;

my ($library_id,$location,$repository_root,$username,$pipeline_id);
my %options = ();
my $results = GetOptions (\%options,
                          'library_id|i=s'	=>	\$library_id,
                          'location|l=s'	=>	\$location,
                          'repository_root|r=s' =>      \$repository_root,
			  'username|u=s'        =>      \$username,
			  'pipeline|p=s'        =>      \$pipeline_id,
                          'help|h') || pod2usage();

## display documentation                                                                                                                                                                                                                    
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

## make sure everything passed was peachy
pod2usage( -msg  => "ERROR!  Required arguments -i and/or -u and/or -l and/or -r and/or -p not found.\n", -exitval => 0, -verbose => 2, -output => \*STDERR)  if (! $pipeline_id || ! $library_id || ! $location || ! $repository_root || ! $username);

## update the xDocs files to fix the issue
## with non-summed values
my @DBUPDATES = qw( ACLAME COG GO KEGG SEED );
foreach my $db (@DBUPDATES) {
    my $xdoc = $repository_root . "/virome-cache-files/xDocs/" . $db . "_XMLDOC_" . $library_id . ".xml";
    my $xdoc_new = $xdoc . ".new.xml";
    my $iddoc = $repository_root . "/virome-cache-files/xDocs/" . $db . "_IDDOC_" . $library_id . ".xml";
    my $iddoc_new = $iddoc . ".new.xml";
    print `perl $repository_root/package_virome/bin/fix_virome_xdoc.pl -x $xdoc -i $iddoc`;
    print `mv $xdoc_new $xdoc`;
    print `mv $iddoc_new $iddoc`;
}

## begin archiving
my $archive_directory = $repository_root . '/.archive/' . $library_id . '-' . $username;
my $dump_directory = $repository_root . '/mysqldumps/'. $library_id . '-' . $username;
my $output_dir = $repository_root . '/output_repository/';
print `mkdir -p $archive_directory`;
print `mkdir -p $dump_directory`;
print `cp -r $output_dir/concatenate_files/*$pipeline_id* $archive_directory`;
print `cp -r $output_dir/db-load-library/$pipeline_id* $archive_directory`;
print `tar -czvf $archive_directory.tgz $archive_directory`;
print `rm -rf $archive_directory`;

## being dumping MySQL
my %processing_databases = (
    'diag1'  =>  'virome_processing_1',
    'diag2'  =>  'virome_processing_2',
    'diag3'  =>  'virome_processing_3',
    'diag4'  =>  'virome_processing_4',
    'diag5'  =>  'virome_processing_5',
    'diag'   =>  'virome_processing'
);
my @tables = ('blastn','blastp','sequence','statistics','sequence_relationship','tRNA');
my $stg_db_name = '';


if (exists $processing_databases{$location}) {
    $stg_db_name = $processing_databases{$location};
}
else {
    die "\n\n The location you've entered is not valid and does not have
  a processing database\n\n";
}

foreach my $table (@tables) {
    print `mysqldump $stg_db_name $table -udnasko -hdnode001.igs.umaryland.edu -pdnas_76 -t > $dump_directory/$table.sql`;
    open(IN,"<$dump_directory/$table.sql");
    open(OUT,">$dump_directory/$table.sql2");
    while(<IN>) {
	chomp;
	my $line = $_;
	$line =~ s/LOCK TABLES `$table` WRITE;//;
	$line =~ s/\/\*\!40000 ALTER TABLE `$table` DISABLE KEYS \*\/\;//;
	$line =~ s/UNLOCK TABLES;//;
	$line =~ s/\/\*\!40000 ALTER TABLE `$table` ENABLE KEYS \*\/\;//;
	print OUT "$line\n";
    }
    close(IN);
    close(OUT);
    print `mv $dump_directory/$table.sql2 $dump_directory/$table.sql`;
}

## UPDATE THE ORF VALUE FOR LIBRARY TABLE
my $db_user;
my $db_pass;
my $dbname;
my $db_host;
my $host;
my $dbh;

unless ($location) {
    pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
    exit(-1);
}
if ($location eq 'dbi') {
    $db_user = q|bhavsar|;
    $db_pass = q|P3^seus|;
    $dbname = q|VIROME|;
    $db_host = $options{server}.q|.dbi.udel.edu|;
    $host = q|virome.dbi.udel.edu|;
}
elsif ($location eq 'camera') {
    $db_user = q|virome_app|;
    $db_pass = q|camera123|;
    $dbname = q|virome_stage|;
    $db_host = q|coleslaw.crbs.ucsd.edu|;
    $host = q|coleslaw.crbs.ucsd.edu|;
}
elsif ($location eq 'diag1') {
    $db_user = q|dnasko|;
    $db_pass = q|dnas_76|;
    $dbname = q|virome_processing_1|;
    $db_host = q|dnode001.igs.umaryland.edu|;
    $host = q|dnode001.igs.umaryland.edu|;
}
elsif ($location eq 'diag2') {
    $db_user = q|dnasko|;
    $db_pass = q|dnas_76|;
    $dbname = q|virome_processing_2|;
    $db_host = q|dnode001.igs.umaryland.edu|;
    $host = q|dnode001.igs.umaryland.edu|;
}elsif ($location eq 'diag3') {
    $db_user = q|dnasko|;
    $db_pass = q|dnas_76|;
    $dbname = q|virome_processing_3|;
    $db_host = q|dnode001.igs.umaryland.edu|;
    $host = q|dnode001.igs.umaryland.edu|;
}elsif ($location eq 'diag4') {
    $db_user = q|dnasko|;
    $db_pass = q|dnas_76|;
    $dbname = q|virome_processing_4|;
    $db_host = q|dnode001.igs.umaryland.edu|;
    $host = q|dnode001.igs.umaryland.edu|;
}elsif ($location eq 'diag5') {
    $db_user = q|dnasko|;
    $db_pass = q|dnas_76|;
    $dbname = q|virome_processing_5|;
    $db_host = q|dnode001.igs.umaryland.edu|;
    $host = q|dnode001.igs.umaryland.edu|;
}elsif ($location eq 'igs') {
    $db_user = q|dnasko|;
    $db_pass = q|dnas_76|;
    $dbname = q|virome_processing|;
    $db_host = q|dnode001.igs.umaryland.edu|;
    $host = q|dnode001.igs.umaryland.edu|;
}
elsif ($location eq 'ageek') {
    $db_user = q|bhavsar|;
    $db_pass = q|Application99|;
    $dbname = $options{server};
    $db_host = q|10.254.0.1|;
    $host = q|10.254.0.1|;
}
else {
    $db_user = q|kingquattro|;
    $db_pass = q|Un!c0rn|;
    $dbname = q|VIROME|;
    $db_host = q|localhost|;
    $host = q|localhost|;
}

$dbh = DBI->connect("DBI:mysql:database=$dbname;host=$db_host","$db_user", "$db_pass",{PrintError=>1, RaiseError =>1, AutoCommit =>1});
my $get_orfs = qq|SELECT count(*) FROM sequence WHERE sequence.typeId = 3;|;
my $sth_get = $dbh->prepare($get_orfs);

$sth_get->execute();
     my ($number_of_orfs) = $sth_get->fetchrow_array();

$dbh = DBI->connect("DBI:mysql:database=virome;host=virome-db.igs.umaryland.edu","dnasko", "dnas_76",{PrintError=>1, RaiseError =>1, AutoCommit =>1});
my $update_orf = qq|UPDATE lib_summary SET orfs = ? WHERE libraryId = ?;|;
my $sth_update = $dbh->prepare($update_orf);

$sth_update->execute($number_of_orfs,$library_id);


exit 0;
