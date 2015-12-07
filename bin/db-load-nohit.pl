#!/usr/bin/perl

=head1 NAME
   db-load-nohit.pl

=head1 SYNOPSIS

    USAGE: db-load-nohit.pl --server server-name --env dbi [--library libraryId]

=head1 OPTIONS

B<--server,-s>
   Server name from where MGOL blastp records are updated

B<--library,-l>
    Specific libraryId whoes MGOL hit_names to updates

B<--env,-e>
    Specific environment where this script is executed.  Based on these values
    db connection and file locations are set.  Possible values are
    igs, dbi, ageek or test

B<--help,-h>
   This help message

=head1  DESCRIPTION
    Add no-hit values to DB

=head1  INPUT
    The input is defined with --server, --library.

=head1  OUTPUT
   Add no-hit infor to blast tables.

=head1  CONTACT
  Jaysheel D. Bhavsar @ bjaysheel[at]gmail[dot]com


==head1 EXAMPLE
   no-hit.pl --server calliope --env dbi --library 31

=cut

use strict;
use warnings;
use IO::File;
use DBI;
use LIBInfo;
use UTILS_V;
use XML::Writer;
use Pod::Usage;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);

BEGIN {
	use Ergatis::Logger;
}

my %options = ();
my $results = GetOptions(
	\%options,   'server|s=s',  'library|b=s', 'env|e=s',
	'input|i=s', 'outdir|od=s', 'log|l=s',     'debug|d=s',
	'help|h'
  )
  || pod2usage();

## display documentation
if ( $options{'help'} ) {
	pod2usage( { -exitval => 0, -verbose => 2, -output => \*STDERR } );
}

my $logfile = $options{'log'} || Ergatis::Logger::get_default_logfilename();
my $logger = new Ergatis::Logger(
	'LOG_FILE'  => $logfile,
	'LOG_LEVEL' => $options{'debug'}
);
$logger = $logger->get_logger();

#############################################################################
#### DEFINE GLOBAL VAIRABLES.
##############################################################################
my $dbh;
my $dbh0;

my $libinfo = LIBInfo->new();
my $libObject;

my $utils = new UTILS_V;
$utils->set_db_params( $options{env} );

## make sure everything passed was peachy
&check_parameters( \%options );
##############################################################################
timer();

my $lib_sel = $dbh0->prepare(q{SELECT id FROM library WHERE deleted=0 and server=?});
my $seq_info = $dbh->prepare(qq{SELECT name,size,id FROM sequence where id=?});

my $get_orfans = $dbh->prepare(qq{SELECT orfan_id
								  FROM statistics
								  WHERE libraryId=?
                                    and deleted=0}
);

my $filename    = $options{outdir} . "/blastp.txt";
my $column_list = qq/blastp.sequenceId,blastp.query_name,blastp.query_length,/;
$column_list = $column_list . qq/blastp.algorithm,blastp.database_name,/;
$column_list = $column_list . qq/blastp.hit_description,blastp.e_value,blastp.sys_topHit/;
my @libArray;

open( OUT, ">", $filename )
  || die $logger->logdie("Could not open file $filename");

#get all library that needs to be processed
if ( $options{library} <= 0 ) {
	$lib_sel->execute( $options{server} );
	my $rslt = $lib_sel->fetchall_arrayref( {} );

	foreach my $lib (@$rslt) {
		push @libArray, $lib->{'id'};
	}
}
else {
	push @libArray, $options{library};
}

foreach my $lib (@libArray) {
	print "Procssing library $lib\n";

	#get orf file name from stats table
	$get_orfans->execute($lib);
	my $orf_file = $get_orfans->fetchrow_array();

	#open orf file and get all ids.
	my $fileLoc = "/diag/projects/virome/virome-cache-files/idFiles";
	open( ORF, "<", $fileLoc . "/" . $orf_file )
	  or die("Could not open file $orf_file\n\n $fileLoc/$orf_file\n");

	my $orfs = <ORF>;
	my @ids  = split( /,/, $orfs );

   #loop through all orfan ids and get seqeunce info to insert into blast table.
	foreach my $id (@ids) {
		$seq_info->execute($id);
		my ( $name, $size, $id ) = $seq_info->fetchrow_array();

		#print $id."\t".$name."\t".$size."\n";
		print OUT join( "\t",
			$id, $name, $size, "BLASTP", "NOHIT",
			"Sequence has no homologs in KNOWN or ENVIRONMENTAL database",
			"0.001", "1" )
		  . "\n";
	}
}
$seq_info->finish();
$get_orfans->finish();

$dbh0->disconnect;
$dbh->disconnect;

my $db_host = $utils->db_host;
my $db_user = $utils->db_user;
my $db_pass = $utils->db_pass;
my $db_name = $utils->db_name;

# my $cmd = "mysqlimport --columns=$column_list --compress --fields-terminated-by='\\t'";
# $cmd .= " --lines-terminated-by='\\n' --host=$utils->db_host --user=$utils->db_user";
# $cmd .= " --password=$utils->db_pass $utils->db_name -L $filename";

my $cmd = "mysqlimport --columns=$column_list --compress --fields-terminated-by='\\t'";
$cmd .= " --lines-terminated-by='\\n' --host=$db_host --user=$db_user";
$cmd .= " --password=$db_pass $db_name -L $filename";

#execute mysql import
system($cmd);

if ( ( $? >> 8 ) != 0 ) {
	print STDERR "command failed: $!\n";
	print STDERR $cmd . "\n";
	exit( $? >> 8 );
}

timer();    #call timer to see when process ended.
exit(0);

###############################################################################
####  SUBS
###############################################################################
sub check_parameters {
	my $options = shift;

	my $flag = 0;

	# if library list file or library file has been specified
	# get library info. server, id and library name.
	if ( ( defined $options{input} ) && ( length( $options{input} ) ) ) {
		$libObject = $libinfo->getLibFileInfo( $options{input} );
		$flag      = 1;
	}

	# if server is not specifed and library file is not specifed show error
	if ( !$options{server} && !$flag ) {
		pod2usage(
			{
				-exitval => 2,
				-message => "error message",
				-verbose => 1,
				-output  => \*STDERR
			}
		);
		exit(-1);
	}

	# if exec env is not specified show error
	unless ( $options{env} ) {
		pod2usage(
			{
				-exitval => 2,
				-message => "error message",
				-verbose => 1,
				-output  => \*STDERR
			}
		);
		exit(-1);
	}

	# if no library info set library to -1;
	unless ( $options{library} ) {
		$options{library} = -1;
	}

	# if getting info from library file set server and library info.
	if ($flag) {
		$options{library} = $libObject->{id};
		$options{server}  = $libObject->{server};
	}

	#set db connection handlers
	$dbh0 = DBI->connect(
		"DBI:mysql:database="
		  . $utils->db_live_name
		  . ";host="
		  . $utils->db_live_host,
		$utils->db_live_user,
		$utils->db_live_pass,
		{ PrintError => 1, RaiseError => 1, AutoCommit => 1 }
	);

	$dbh = DBI->connect(
		"DBI:mysql:database=" . $utils->db_name . ";host=" . $utils->db_host,
		$utils->db_user,
		$utils->db_pass,
		{ PrintError => 1, RaiseError => 1, AutoCommit => 1 }
	);
}

###############################################################################
sub timer {
	my @months   = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	my (
		$second,     $minute,    $hour,
		$dayOfMonth, $month,     $yearOffset,
		$dayOfWeek,  $dayOfYear, $daylightSavings
	  )
	  = localtime();
	my $year    = 1900 + $yearOffset;
	my $theTime =
"$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";
	print "Time now: " . $theTime . "\n";
}

###############################################################################
