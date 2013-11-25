#!/usr/bin/perl -w

=head1 NAME

  tie_seq_id.pl

=head1 SYNOPSIS

   USAGE: tie_seq_id.pl --env camera

=head1 OPTIONS

B<--env,-e>
   Specific environment where this script is executed.  Based on these values
   db connection and file locations are set.  Possible values are
   igs, dbi, ageek or test

B<--help,-h>
  This help message


=head1  DESCRIPTION
	Will populated the sequenceId field in the BLASTp table
	with the id's from the sequence table.

=head1  INPUT

	Environment, i.e. where the script is running.

=head1  OUTPUT
  
   An updated MySQL table

=head1  CONTACT

 Daniel J. Nasko @ dan[dot]nasko[at]gmail[dot]com


==head1 EXAMPLE

 tie_seq_id.pl --env dbi

=cut


use strict;
use warnings;
use DBI;
use Switch;
use LIBInfo;
use Pod::Usage;
use Data::Dumper;
use UTILS_V;
use MLDBM 'DB_File';
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

BEGIN {
  use Ergatis::Logger;
}

my %options = ();
my $results = GetOptions (\%options,
			  'env|e=s',
			  'log|l=s',
			  'debug|d=s',
			  'help|h') || pod2usage();

## display documentation
if( $options{'help'} ) {
  pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

my $logfile = $options{'log'} || Ergatis::Logger::get_default_logfilename();
my $logger = new Ergatis::Logger('LOG_FILE'=>$logfile,
				 'LOG_LEVEL'=>$options{'debug'});
$logger = $logger->get_logger();
##############################################################################
#### DEFINE GLOBAL VAIRABLES.
##############################################################################
my $db_user;
my $db_pass;
my $dbname;
my $db_host;
my $host;

my $dbh;

##########################################################################
# if exec env is not specified show error
unless ($options{env}) {
	pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
	exit(-1);
}
if ($options{env} eq 'dbi') {
	  $db_user = q|bhavsar|;
	  $db_pass = q|P3^seus|;
	  $dbname = q|VIROME|;
	  $db_host = $options{server}.q|.dbi.udel.edu|;
	  $host = q|virome.dbi.udel.edu|;
} 
elsif ($options{env} eq 'camera') {
	$db_user = q|virome_app|;
        $db_pass = q|camera123|;
        $dbname = q|virome_stage|;
        $db_host = q|coleslaw.crbs.ucsd.edu|;
        $host = q|coleslaw.crbs.ucsd.edu|;
}
elsif ($options{env} eq 'diag1') {
        $db_user = q|dnasko|;
        $db_pass = q|dnas_76|;
        $dbname = q|virome_processing_1|;
        $db_host = q|dnode001.igs.umaryland.edu|;
        $host = q|dnode001.igs.umaryland.edu|;
}
elsif ($options{env} eq 'diag2') {
        $db_user = q|dnasko|;
        $db_pass = q|dnas_76|;
        $dbname = q|virome_processing_2|;
        $db_host = q|dnode001.igs.umaryland.edu|;
	$host = q|dnode001.igs.umaryland.edu|;
}elsif ($options{env} eq 'diag3') {
        $db_user = q|dnasko|;
        $db_pass = q|dnas_76|;
        $dbname = q|virome_processing_3|;
        $db_host = q|dnode001.igs.umaryland.edu|;
	$host = q|dnode001.igs.umaryland.edu|;
}elsif ($options{env} eq 'diag4') {
        $db_user = q|dnasko|;
        $db_pass = q|dnas_76|;
        $dbname = q|virome_processing_4|;
        $db_host = q|dnode001.igs.umaryland.edu|;
	$host = q|dnode001.igs.umaryland.edu|;
}elsif ($options{env} eq 'diag5') {
        $db_user = q|dnasko|;
        $db_pass = q|dnas_76|;
        $dbname = q|virome_processing_5|;
        $db_host = q|dnode001.igs.umaryland.edu|;
	$host = q|dnode001.igs.umaryland.edu|;
}elsif ($options{env} eq 'igs') {
	$db_user = q|dnasko|;
	$db_pass = q|dnas_76|;
	$dbname = q|virome_processing|;
	$db_host = q|dnode001.igs.umaryland.edu|;
	$host = q|dnode001.igs.umaryland.edu|;
}
elsif ($options{env} eq 'ageek') {
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
my $sync_sql = qq|UPDATE blastp, sequence SET blastp.sequenceId=sequence.id WHERE query_name = sequence.`name` AND sequence.typeId = 3;|;
my $sth_sync = $dbh->prepare($sync_sql);
my $orf_sql = qq|UPDATE sequence SET orf = 1 WHERE typeId = 3 OR typeId = 4;|;
my $sth_orf = $dbh->prepare($orf_sql);

$sth_sync->execute();
$sth_orf->execute();
