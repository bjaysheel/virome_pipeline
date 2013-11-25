#!/usr/bin/perl -w

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
BEGIN{foreach (@INC) {s/\/usr\/local\/packages/\/local\/platform/}};
use lib (@INC,$ENV{"PERL_MOD_DIR"});
no lib "$ENV{PERL_MOD_DIR}/i686-linux";
no lib ".";

=head1 NAME

db-load-sequence.pl - load fasta sequence to db

=head1 SYNOPSIS

USAGE: db-load-fams.pl
            --input=/path/to/fasta
          [ --log=/path/to/logfile
            --debug=N
          ]

=head1 OPTIONS

B<--input, -i>
    The full path to hmm fams output
    #                                           --- full sequence ---- --- best 1 domain ---- --- domain number estimation ----
    # target             query                    E-value  score  bias   E-value  score  bias   exp reg clu  ov env dom rep inc description of target
    #-------------------   -------------------- --------- ------ ----- --------- ------ -----   --- --- --- --- --- --- --- --- ---------------------
    APH                  BRPAOIX4483_983_1509_1   4.5e-10   39.1   0.0   4.9e-10   39.0   0.0   1.0   1   0   0   1   1   1   1 Phosphotransferase enzyme family

B<--fam, -f>
    HMM fam database and vesion used as subject db
    e.g: PFam 23.0
    
B<--debug,-d>
    Debug level.  Use a large number to turn on verbose debugging.

B<--log,-l>
    Log file

B<--help,-h>
    This help message

=head1  DESCRIPTION

This script is used to load hmm output into MySQL database.

=head1  INPUT

The input to this is defined using the --input.  This should point
to a tab delimited output file containing hmm output results.
-- fam should indicate which hmm family db and version was used.
USAGE: db-load-fams -i <hmm-tab-output> -f PFAM 23.0

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
##############################################################################
my %options = ();
my $results = GetOptions (\%options,
                          'input|i=s',
			  'fam|f=s',
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

## make sure everything passed was peachy
&check_parameters(\%options);
##############################################################################

## check if corresponding library exists.
my $libraryId = 0;
my $server = "";
($libraryId, $server) = &check_library(\%options);

#open db connection handler
my $dbh = DBI->connect('DBI:mysql:'.$server.';host=10.254.0.1', 'bhavsar', 'Application99') || die $logger->logdie("Cound not open db connection\n");

## sql statemet to insert library info.
my $insert_fam_sql = qq/INSERT INTO hmm (target,sequence,full_eval,full_score,full_bias,best_eval,best_score,best_bias,exp,reg,clu,ov,env,dom,rep,inc,description,fam)
			VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)/;
			
## prep statement
my $sth_insert = $dbh->prepare($insert_fam_sql);

## local variables needed to parse file.
my @info="";

## open handler to read input file.
open (DAT, $options{input}) || die $logger->logdie("Could not open file $options{input}");

#loop through input and upload them to db
while (<DAT>){
  unless (/^#/){
    chomp $_;
    @info = split (/\t/,$_);
    
    $sth_insert->execute((&trim($info[0]),&trim($info[1]),$info[2],$info[3],$info[4],
			 $info[5],$info[6],$info[7],$info[8],$info[9],$info[10],
			 $info[11],$info[12],$info[13],$info[14],$info[15],&trim($info[16]),&trim($options{fam})));

    #raise error.
    $sth_insert->{RaiseError} = 1;
  }
}

$dbh->disconnect();
close(DAT);
exit(0);

##############################################################################
sub check_parameters {
  unless ( $options{input} ) {
    $logger->logdie("No input defined, plesae read perldoc $0\n\n");
    exit(1);
  }
  
  unless ($options{fam}){
    $logger->logdie("Family type not defined\n\n");
    exit(1);
  }

  if(0){
      pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
  }
}

##############################################################################
sub check_library{
  my $dbh = DBI->connect('DBI:mysql:virome;host=10.254.0.1', 'bhavsar', 'Application99') || die $logger->logdie("Cound not open db connection\n");

  ## sql statement to check lib existance.
  my $check_lib_sql = qq/SELECT id, server FROM library WHERE prefix like ?/;
  
  # prepare statement.
  my $sth_check = $dbh->prepare($check_lib_sql);

  open (FLE,$options{input}) || die $logger->logdie("Counld not open file $options{input}");
  while (<FLE>){
    unless(/^#/){
      chomp $_;
      my @line = split(/\t/,$_);
      my $prefix = substr($line[1],0,3);
  
      $sth_check->execute((&trim($prefix)));
      my $ref = $sth_check->fetchall_arrayref([],1);
  
      if (@{$ref}){
	## return libraryId and server name.
	return ($ref->[0]->[0], $ref->[0]->[1]);
	#print $ref->[0]->[0]."\n";
      }
      else{
	$logger->logdie("No corresponding library for this fasta sequence $prefix.\n");
	exit(1);
      }
    }
  }  
}

##############################################################################
sub trim($) {
  my $string = shift;
  $string =~ s/^\s+/;
  $string =~ s/\s+$/;
  return $string;
}