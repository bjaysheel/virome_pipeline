#!/usr/bin/perl -w

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell


=head1 NAME

db-load-library.pl - load Library output to db

=head1 SYNOPSIS

USAGE: db-load-library.pl
            --input=/path/to/library/info
            --user=/user/who/is/uploading/component
	    --outdir=/path/to/output/dir
	    --env=/env where to execute script
          [ --log=/path/to/logfile
            --debug=N
          ]

=head1 OPTIONS

B<--input, -i>
    The full path to library info file. Tab delimited text file.
    # start a comment.
    # File heading
    Library-Name Prefix Description Pepetide?   Environment Lat Lon Publish
    
B<--user, -u>
    User who is uplaoding library infomation.

B<--outdir, o>
    Path to output dir where a tab file of library id and library prefix is stored.
    
B<--debug,-d>
    Debug level.  Use a large number to turn on verbose debugging.

B<--log,-l>
    Log file

B<--help,-h>
    This help message

=head1  DESCRIPTION

This script is used to load library infomation into MySQL database.

=head1  INPUT

The input to this is defined using the --input.  This should point
to the tab delimited library info file.

=head1  CONTACT

    Jaysheel D. Bhavsar
    bjaysheel@gmail.com

=cut

use strict;
use DBI;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
BEGIN {
  use Ergatis::Logger;
}

my %options = ();
my $results = GetOptions (\%options,
                          'input|i=s',
                          'user|u=s',
			  'outdir|o=s',
			  'loc|e=s',
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

#############################################################################
#### DEFINE GLOBAL VAIRABLES.
##############################################################################
my $db_user;
my $db_pass;
my $dbname;
my $db_host;
my $host;

my $dbh;

print STDOUT ("CHECKING PARAMS\n");

## make sure everything passed was peachy
&check_parameters(\%options);
##############################################################################

print STDOUT ("opening file and setup db qry\n");

## open handler to read input file.
open (DAT, $options{input}) || die print STDERR("Could not open file $options{input}\n");

## sql statement to check lib existance.
my $check_lib_sql = qq/SELECT id, name, prefix FROM library WHERE name like ? and prefix like ?/;

## sql statemet to insert library info.
my $insert_lib_sql = qq/INSERT INTO library (name, prefix, description, environment, publish, project, user, server, groupId)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)/;
my $lst_val = qq/SELECT max(id) from library/;

  
## prep statement
my $sth_check = $dbh->prepare($check_lib_sql);
my $sth_insert = $dbh->prepare($insert_lib_sql);
my $last_insrt = $dbh->prepare($lst_val);

print STDOUT ("PROCESS FILE\n");
#loop through input and upload them to db
while (<DAT>){
  unless (/^#/){
    chomp $_;
    my @info = split(/\t/,$_);

    #print $info[0]."\n";
  
    ## get server name
    my $server = &getServer($info[3]);

    #execute to check lib existance.
    $sth_check->execute((&trim($info[0]), &trim($info[1])));
    
    #raise error.
    $sth_check->{RaiseError} = 1;
  
    ## ref db result set
    my ($id,$name,$prefix) = $sth_check->fetchrow_array();
    
    my $outfile = &trim($info[0]);
    $outfile =~ s/\s+/_/g;
    $outfile = $options{outdir}."/".$outfile.".txt";
    
    open (LIB, ">$outfile") or logger->logdie("Cannot open output file $outfile\n");
    if ($id > 0){
      ## library already exist.
      $logger->debug("Library named $info[0] with prefix $info[1] already exist in the database. Skipping library.\n");
      print LIB "$id\t$name\t$prefix\t$server";
      #print "Library named $info[0] with prefix $info[1] already exist in the database. Skipping library.\n";
    }
    else {
      ## new lib instert lib info.
      $sth_insert->execute((&trim($info[0]), &trim($info[1]), &trim($info[2]), &trim($info[3]), &trim($info[4]), &trim($info[5]), &trim($options{user}), &trim($server),-1));

      $last_insrt->execute();
      my ($lst_id) = $last_insrt->fetchrow_array();

      #raise error.
      $sth_check->{RaiseError} = 1;
      print LIB "$lst_id\t$info[0]\t$info[1]\t$server";
    }
    close LIB;
  }
}

$dbh->disconnect();
close(DAT);
exit(0);

##############################################################################
# SUBS
##############################################################################
sub check_parameters {
    
    ## at least one input type is required
    unless ( $options{input} && $options{user} && $options{outdir} && $options{loc}) {
	$logger->logdie("No input defined, plesae read perldoc $0\n");
        exit(1);
    }

    if(0){
        pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
    }
    
    if ($options{loc} eq 'dbi'){
	$db_user = q|bhavsar|;
	$db_pass = q|P3^seus|;
	$dbname = q|VIROME|;
	$db_host = q|virome.dbi.udel.edu|;
	$host = q|virome.dbi.udel.edu|;
    }elsif ($options{loc} eq 'igs'){
	$db_user = q|dnasko|;
	$db_pass = q|dnas_76|;
	$dbname = q|virome_processing|;
	$db_host = q|dnode001.igs.umaryland.edu|;
	$host = q|dnode001.igs.umaryland.edu|;
    }elsif ($options{loc} eq 'camera'){
        $db_user = q|virome_app|;
        $db_pass = q|camera123|;
        $dbname = q|virome_stage|;
        $db_host = q|dory.internal.crbs.ucsd.edu|;
        $host = q|dory.internal.crbs.ucsd.edu|;
    }elsif ($options{loc} eq 'ageek') {
	$db_user = q|bhavsar|;
	$db_pass = q|Application99|;
	$dbname = q|virome|;
	$db_host = q|10.254.0.1|;
	$host = q|10.254.0.1|;
    }else {
	$db_user = q|kingquattro|;
	$db_pass = q|Un!c0rn|;
	$dbname = q|VIROME|;
	$db_host = q|localhost|;
	$host = q|localhost|;
    }
    
    $dbh = DBI->connect("DBI:mysql:database=$dbname;host=$db_host",
	"$db_user", "$db_pass",{PrintError=>1, RaiseError =>1, AutoCommit =>1}) || die print STDERR("Cound not open db connection\n");
}

##############################################################################
sub getServer{
  my $env = $_[0];
  my @server = ("calliope", "polyhymnia", "terpsichore", "thalia");
  
  if ($env =~ /water/i){
    return $server[2];
  } elsif ($env =~ /soil/i){
    return $server[1];
  } elsif ($env =~ /extreme/i){
    return $server[3];
  } elsif ($env =~ /solid substrate/i){
    return $server[3];
  } else {
    return $server[0];
  }
}

##############################################################################
sub trim($) {
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  return $string;
}
