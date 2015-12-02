#!/usr/bin/perl

=head1 NAME

db-to-lookup.pl: Create a MLDBM lookup file

=head1 SYNOPSIS

USAGE: db-to-lookup.pl
            --input=/library/info/file
			--table=/tablename
			--env=/env/where/executing
            --outdir=/output/dir
			[ --log=/path/to/logfile
            --debug=N]

=head1 OPTIONS

B<--input, -i>
    tab delimited library info file.

B<--table, -t>
    mysql db table name

B<--env, -e>
    env where executing script igs,dbi,test

B<--outdir, -o>
    Output dir where lookup file will be stored

B<--debug,-d>
    Debug level.  Use a large number to turn on verbose debugging.

B<--log,-l>
    Log file

B<--help,-h>
    This help message

=head1  DESCRIPTION

This script is used to upload info into db.

=head1  INPUT

=head1  CONTACT

    Jaysheel D. Bhavsar
    bjaysheel@gmail.com

=cut

use strict;
use warnings;
use DBI;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use UTILS_V;
use MLDBM 'DB_File';
use Fcntl qw( O_TRUNC O_RDONLY O_RDWR O_CREAT);

BEGIN {
  use Ergatis::Logger;
}

##############################################################################
my %options = ();
my $results = GetOptions (\%options,
                          'input|i=s',
						  'outdir|o=s',
						  'table|t=s',
						  'env|e=s',
                          'log|l=s',
                          'debug|d=s',
                          'help|h') || pod2usage();

my $logfile = $options{'log'} || Ergatis::Logger::get_default_logfilename();
my $logger = new Ergatis::Logger('LOG_FILE'=>$logfile,
                                  'LOG_LEVEL'=>$options{'debug'});
$logger = $logger->get_logger();

## display documentation
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}
##############################################################################

## make sure everything passed was peachy
&check_parameters(\%options);

my $utils = new UTILS_V;
my $libraryId = $utils->get_libraryId_from_file($options{input});

$utils->set_db_params($options{env});

my $sel_qry='';

if ($options{table} =~ /sequence/i){
    $sel_qry = qq{SELECT s.id, s.libraryId, s.name, s.header
				  FROM sequence s
				  WHERE s.libraryId=?
					and s.typeId != 4
					and s.deleted=0};
}

if (length($sel_qry)) {  #table info is passed and expected
    if ($libraryId > 0){  # check for validity of library id
        my $dbh = DBI->connect("DBI:mysql:database=".$utils->db_name.";host=".$utils->db_host,
			       $utils->db_user, $utils->db_pass,{PrintError=>1, RaiseError =>1, AutoCommit =>1});

        print STDOUT "\n DEBUG: Trying to write to this file:\n\n";
        print STDOUT $options{outdir}."/".$options{table}."_".$libraryId.".ldb" . "\n";
        print STDOUT "\noutdir = $options{outdir}\n";
        print STDOUT "table = $options{table}\n";
        print STDOUT "library id = $libraryId\n\n";
        my $filename = $options{outdir}."/".$options{table}."_".$libraryId.".ldb";

	# remove file if it already exists;
	# over write the files with all sequence and orfs
	if (-s $filename > 0){
	    system("rm $filename");
	}

        ## create the tied hash
	tie(my %info, 'MLDBM', $filename);
	
	my $seq_sth = $dbh->prepare($sel_qry);
	$seq_sth->execute($libraryId);
	
	my %sel_data;
	while (my $row = $seq_sth->fetchrow_hashref) {
	    $info{$$row{name}} = {id => $$row{id},
				  libraryId => $$row{libraryId},
				  header => $$row{header}};
	}
	
	$seq_sth->finish();
	untie(%info);
	$dbh->disconnect();
    }
}

exit(0);

###############################################################################
sub check_parameters {
  ## at least one input type is required
  unless ( $options{input} && $options{table} && $options{env} && $options{outdir}) {
      pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
      $logger->logdie("No input defined, plesae read perldoc $0\n\n");
      exit(1);
  }
}
