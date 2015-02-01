#!/usr/bin/perl -w

=head1 NAME

publish_checkin.pl - Pushes the outputs of virome pipeline to the site.

=head1 SYNOPSIS

USAGE: archiver_and_dumper.pl
            --info=/Path/to/library.txt --mgol="MGOL_VERSION" --uniref="UNIREF_VERSION"

=head1 OPTIONS

B<--info,-i>
    Thie library info file

B<--mgol,-m>
    The mgol version

B<--uniref,-u>
    The uniref version

B<--pipeline,-p>
    The pipeline version

B<--help,-h>
    This help message

=head1  DESCRIPTION

Pushes the SQL dumps to the live site. Also checks in the processing database.

=head1  INPUT                                                                                                                                                                                                                              

Output of db-load-library. Essentially a tab-dleimmited file containing:
library_id    library_name    prefix    server    processing_server

=head1  OUTPUT

No output, no hastle.

=head1  CONTACT                                                                                                                                                                                                                            

    Daniel Nasko
    dan.nasko@gmail.com                                                                                                                                                                                                                    

=cut                                                                                                                                                                                                                                        

use strict;
use DBI;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use UTILS_V;

my ($info,$mgol,$uniref,$pipeline);
my %options = ();
my $results = GetOptions (\%options,
                          'info|i=s'	=>	\$info,
                          'mgol|m=s'    =>      \$mgol,
			  'uniref|u=s'  =>      \$uniref,
			  'pipeline|p=s'=>      \$pipeline,
			  'help|h') || pod2usage();

## display documentation                                                                                                                                                                                                                    
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

## make sure everything passed was peachy
pod2usage( -msg  => "ERROR!  Required argument -i not found.\n", -exitval => 0, -verbose => 2, -output => \*STDERR)  if (! $info);
pod2usage( -msg  => "ERROR!  Required argument -mgol not found.\n", -exitval => 0, -verbose => 2, -output => \*STDERR)  if (! $mgol);
pod2usage( -msg  => "ERROR!  Required argument -uniref not found.\n", -exitval => 0, -verbose => 2, -output => \*STDERR)  if (! $uniref);
pod2usage( -msg  => "ERROR!  Required argument -pipeline not found.\n", -exitval => 0, -verbose => 2, -output => \*STDERR)  if (! $pipeline);

## MySQL Server information
my $db_name = "virome";
my $db_host = "virome-db.igs.umaryland.edu";
my $db_user = "dnasko";
my $db_pass = "dnas_76";
my @row;

my $dbh = DBI->connect("DBI:mysql:database=".$db_name.";host=".$db_host, $db_user, $db_pass,{PrintError=>1, RaiseError =>1, AutoCommit =>1});
my $select_sql = qq/SELECT `user` FROM library WHERE id = ? ;/;
my $sth_select = $dbh->prepare($select_sql);

my ($library_id,$library_name,$prefix,$server,$processing_db,$root,$user);
open(IN,"<$info") || die "\n\n Cannot open the db-load-library file: $info\n\n";
while(<IN>) {
    chomp;
    my @A = split(/\t/, $_);
    $library_id = $A[0];
    $library_name = $A[1];
    $prefix = $A[2];
    $server = $A[3];
    $processing_db = $A[4];
}
close(IN);

print "
Library ID   = $library_id
Library Name = $library_name
Prefix       = $prefix
Server       = $server
Proc DB      = $processing_db
";

$sth_select->execute ($library_id);
while (@row = $sth_select->fetchrow_array) {
    $user = $row[0];
}
print "User      = $user\n";
if ($processing_db =~ m/diag/) {
    $root = "/diag/projects/virome/";
}
else {
    die "\n\n Cannot determine the root given the processing_db: $processing_db\n\n";
}

## Everything is uploaded to live site, just need to update a couple of SQL tables
my $update_sql = qq/UPDATE library SET progress = "complete" WHERE id = ?/;
my $sth_update = $dbh->prepare($update_sql);
$sth_update->execute ($library_id);

my $update_sql_two = qq/UPDATE library SET deleted = 0 WHERE id = ?/;
my $sth_update_two = $dbh->prepare($update_sql_two);
$sth_update_two->execute ($library_id);

my $proc = $processing_db;
$proc =~ s/diag//;

my $complete_sql = qq/UPDATE library SET dateCompleted = ? WHERE id = ?/;
my $sth_complete = $dbh->prepare($complete_sql);
my $date_time = `date --rfc-3339='seconds'`;
chomp($date_time);
my $rev = scalar reverse($date_time);
$rev =~ s/^......//;
$date_time = scalar reverse($rev);
$sth_complete->execute($date_time,$library_id);

my $mgol_sql = qq/UPDATE library SET mgolVersion = "$mgol" WHERE id = ?/;
my $sth_mgol = $dbh->prepare($mgol_sql);
my $uniref_sql = qq/UPDATE library SET fxndbLookupVersion = "$uniref" WHERE id = ?/;
my $sth_uniref = $dbh->prepare($uniref_sql);
my $pipeline_sql = qq/UPDATE library SET pipelineVersion = "$pipeline" WHERE id = ?/;
my $sth_pipeline = $dbh->prepare($pipeline_sql);
$sth_mgol->execute($library_id);
$sth_uniref->execute($library_id);
$sth_pipeline->execute($library_id);
$dbh -> disconnect;

my @Tables = ("blastn","sequence","sequence_relationship","statistics","tRNA","blastp");
foreach my $table (@Tables) {
    print `mysql $server -udnasko -hvirome-db.igs.umaryland.edu -pdnas_76 <$root/mysqldumps/$library_id-$user/$table.sql`;
    print "mysql $server -udnasko -hvirome-db.igs.umaryland.edu -pdnas_76 <$root/mysqldumps/$library_id-$user/$table.sql\n";
}

$dbh = DBI->connect("DBI:mysql:database=".$db_name.";host=".$db_host, $db_user, $db_pass,{PrintError=>1, RaiseError =>1, AutoCommit =>1});
my $check_sql = qq/UPDATE processing_db_checkout SET status = "AVAILABLE" WHERE database_id = ?/;
my $sth_check = $dbh->prepare($check_sql);
$sth_check->execute ($proc);

exit 0;
