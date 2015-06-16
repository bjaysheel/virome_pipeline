#!/usr/bin/perl -w

=head1 NAME

transfer_checkin.pl - Pushes the outputs of virome pipeline to the sipho.dbi.udel.edu

=head1 SYNOPSIS

USAGE: transfer_checkin.pl
            --info=/Path/to/library.txt

=head1 OPTIONS

B<--info,-i>
    Thie library info file

B<--help,-h>
    This help message

=head1  DESCRIPTION

Pushes the SQL dumps to sipho.dbi.udel.edu. Also checks in the processing database.

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

my ($info);
my %options = ();
my $results = GetOptions (\%options,
                          'info|i=s'	=>	\$info,
			  'help|h') || pod2usage();

## display documentation                                                                                                                                                                                                                    
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

## make sure everything passed was peachy
pod2usage( -msg  => "ERROR!  Required argument -i not found.\n", -exitval => 0, -verbose => 2, -output => \*STDERR)  if (! $info);

## MySQL Server information
my $db_name = "virome";
my $db_host = "virome-db.igs.umaryland.edu";
my $db_user = "dnasko";
my $db_pass = "dnas_76";
my @row;

my $dbh = DBI->connect("DBI:mysql:database=".$db_name.";host=".$db_host, $db_user, $db_pass,{PrintError=>1, RaiseError =>1, AutoCommit =>1});
my $select_sql = qq/SELECT `user` FROM library WHERE id = ? ;/;
my $sth_select = $dbh->prepare($select_sql);


############################################
## Gather some information on the library ##
############################################
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
$dbh->disconnect;

print "User      = $user\n";
if ($processing_db =~ m/diag/) {
    $root = "/diag/projects/virome/";
}
else {
    die "\n\n Cannot determine the root given the processing_db: $processing_db\n\n";
}

#################################################################
## Secure copy the tar ball from dump_db to sipho.dbi.udel.edu ##
#################################################################
# print `scp /diag/projects/virome/output_repository/dump_db/$library_id.tar.gz dnasko@sipho.dbi.udel.edu:/data/diag_libraries`;
print `ssh fnode1 scp /diag/projects/virome/output_repository/dump_db/$prefix.tar.gz dnasko\@sipho.dbi.udel.edu:/data/diag_libraries`;

###########################################################################
## Update the processing checkout table to check in the current database ##
###########################################################################
$dbh = DBI->connect("DBI:mysql:database=".$db_name.";host=".$db_host, $db_user, $db_pass,{PrintError=>1, RaiseError =>1, AutoCommit =>1});
$processing_db =~ s/^diag//; ## need to do this for the SQL table.
my $check_sql = qq/UPDATE processing_db_checkout SET status = "AVAILABLE" WHERE database_id = ?/;
my $sth_check = $dbh->prepare($check_sql);
$sth_check->execute ($processing_db);
$dbh->disconnect;

exit 0;
