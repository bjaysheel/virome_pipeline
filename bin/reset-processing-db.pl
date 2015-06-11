#!/usr/bin/perl -w

=head1 NAME
   reset-processing-db.pl

=head1 SYNOPSIS

    USAGE: reset-processing-db.pl --lib_file tab/delimited/lib/info/file

=head1 OPTIONS

B<--lib_file,-lf>
   Absolute file path that contains tab delimited library information

  eg: id   name    server    location

B<--output_dir,-o>
   Output directory

B<--env,-e>
   Environment [ageek|igs|dbi|test]

B<--help,-h>
   This help message

=head1  DESCRIPTION
    Create backup of processing db, empty processing db, set ids of processing
    db to respective server info.  This is only for igs processing

=head1  INPUT
    The input is defined with --lib_file --env.

=head1  OUTPUT
   mysql dump of processing db.

=head1  CONTACT
  Jaysheel D. Bhavsar @ bjaysheel[at]gmail[dot]com


==head1 EXAMPLE
   reset-processing-db.pl --lib_file file_name.tab --env igs

=cut

use IO::File;
use strict;
use DBI;
use Pod::Usage;
use Data::Dumper;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
BEGIN {
  use Ergatis::Logger;
}

my %options = ();
my $results = GetOptions (\%options,
                          'lib_file|ls=s',
                          'output_dir|o=s',
                          'env|e=s',
                          'log|l=s',
                          'debug|d=s',
                          'help|h') || pod2usage();

## display documentation
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

my $logfile = $options{'log'} || Ergatis::Logger::get_default_logfilename();
my $logger = new Ergatis::Logger('LOG_FILE'=>$logfile,
                                  'LOG_LEVEL'=>$options{'debug'});
$logger = $logger->get_logger();
#############################################################################
#### DEFINE GLOBAL VAIRABLES.
##############################################################################

unless ($options{lib_file} || $options{output_dir} || $options{env}) {
    pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
    exit(-1);
}

my $server = '';
my $min = '';
my $max = '';

parse_library_info();
    my %processing_databases = (
        'diag1'  =>  'virome_processing_1',
        'diag2'  =>  'virome_processing_2',
	'diag3'  =>  'virome_processing_3',
        'diag4'  =>  'virome_processing_4',
        'diag5'  =>  'virome_processing_5',
    );
my $lv_db_host = q|virome-db|;
my $lv_db_user = q|dnasko|;
my $lv_db_pass = q|dnas_76|;
my $lv_db_name = $server;

my $stg_db_host = q|dnode001.igs.umaryland.edu|;
my $stg_db_user = q|dnasko|;
my $stg_db_pass = q|dnas_76|;
my $stg_db_name = $processing_databases{$options{env}};

## Two hashes to assure our ID's don't overlap between processing databases
my %MIN = ('diag1','1000000000000','diag2','2000000000000','diag3','3000000000000','diag4','4000000000000','diag5','5000000000000');
my %MAX = ('diag1','2000000000000','diag2','3000000000000','diag3','4000000000000','diag4','5000000000000','diag5','6000000000000');
my $location = $options{env};
if (exists $MIN{$location}) {
    $min = $MIN{$location};
    $max = $MAX{$location};
}
else {
    die "\n\n The location you have enetered was an invalid location for DIAG: $location $options{env}\n\n";
}

#my @tables = ('blastn','blastp','blastx','sequence','orf','statistics','tRNA', 'sequence_relationship');
my @tables = ('blastn','blastp','sequence','statistics','tRNA', 'sequence_relationship');
print STDOUT " Hey Dan: $lv_db_name\n\n";
# my $lv_dbh = DBI->connect("DBI:mysql:database=$lv_db_name;host=$lv_db_host",
#     "$lv_db_user", "$lv_db_pass",{PrintError=>1, RaiseError =>1, AutoCommit =>1});

my $stg_dbh = DBI->connect("DBI:mysql:database=$stg_db_name;host=$stg_db_host",
                "$stg_db_user", "$stg_db_pass",{PrintError=>1, RaiseError =>1, AutoCommit =>1});
##############################################################################
timer(); #call timer to see when process started.

#create backup of processing db
my $dump = "mysqldump -u$stg_db_user -p$stg_db_pass -h$stg_db_host $stg_db_name --skip-lock-tables > $options{output_dir}/virome_processing_".time().".ddl";
my $zip = "gzip $options{output_dir}/virome_processing_".time().".ddl";
system($dump);
system($zip);

#empty processing db
foreach my $tbl (@tables){
    my $trunc_stmt = q|delete from | . $tbl;
    my $trunc = $stg_dbh->prepare($trunc_stmt);
    print "Empting table $tbl\n";
    $trunc->execute();
}

#update ids on processing db
foreach my $tbl (@tables){
	next if ($tbl =~ /sequence_relationship/i);

    my $rslt = '';

    #fetch auto increment ids.
    my $id_sel_stmt = qq|SELECT max(id) FROM $tbl WHERE id > $min AND id < $max|;
    my $ids = $lv_dbh->prepare($id_sel_stmt);
    print "Getting max ID for $tbl . . .\n";
    $ids->execute();
    $rslt = $ids->fetchrow_array();
    $rslt = 0 if !$rslt;

    print "Max id for $tbl is $rslt\n";
    #update auto_increment ids
    my $id_upd_stmt = "ALTER table ". $tbl . " AUTO_INCREMENT=".($rslt+1);
    my $upd = $stg_dbh->prepare($id_upd_stmt);
    $upd->execute();
}

timer(); #call timer to see when process ended.
exit(0);

###############################################################################
####  SUBS
###############################################################################
sub timer {
    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
    my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
    my $year = 1900 + $yearOffset;
    my $theTime = "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";
    print "Time now: " . $theTime."\n";
}

###############################################################################
sub parse_library_info {
    open (FHD, "<$options{lib_file}") or die "Could not open file $options{lib_file} to read\n";
    while(<FHD>){
        chomp $_;
        my @lib_info = split(/\t/,$_);
        $server = $lib_info[3];
	$location = $lib_info[4];
    }
}
