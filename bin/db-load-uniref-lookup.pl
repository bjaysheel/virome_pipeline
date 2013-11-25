#!/usr/bin/perl -w

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
BEGIN{foreach (@INC) {s/\/usr\/local\/packages/\/local\/platform/}};
use lib (@INC,$ENV{"PERL_MOD_DIR"});
no lib "$ENV{PERL_MOD_DIR}/i686-linux";
no lib ".";

=head1 NAME

db-load-uniref-lookup.pl - load uniref100+ cluster output

=head1 SYNOPSIS

USAGE: db-load-blast.pl
            --input=/path/to/cluster/output
          [ --log=/path/to/logfile
            --debug=N
          ]

=head1 OPTIONS

B<--input, -i>
    The full path to cd-hit cluster output
        
B<--debug,-d>
    Debug level.  Use a large number to turn on verbose debugging.

B<--log,-l>
    Log file

B<--help,-h>
    This help message

=head1  DESCRIPTION

This script is used to load uniref100+ cd-hit cluster output in to MySQL database.

=head1  INPUT

The input to this is defined using the --input.  This should point
to the cd-hit cluster output

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

###############################################################################
my %options = ();
my $results = GetOptions (\%options,
                          'input|i=s',
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
###############################################################################

#open db connection handler
my $dbh = DBI->connect('DBI:mysql:virome;host=10.254.0.1', 'bhavsar', 'Application99') || die $logger->logdie("Cound not open db connection\n");

## sql statemet to insert library info.
my $insert_sql = qq/INSERT INTO uniref_clst (representative, members, version)
			VALUES (?, ?, ?)/;
			
## prep statement
my $sth_insert = $dbh->prepare($insert_sql);

## open handler to read input file.
open (DAT, $options{input}) || die $logger->logdie("Could not open file $options{input}");

my $rep = "";
my $mem = "";
my $ver = 0;

#loop through input and upload them to db
while (<DAT>){
  if (length($_)){
    if (/^>/){
      if (length($rep) && length($mem)){
	#print "$rep\t$mem\t$ver\n";
	$sth_insert->execute(($rep, $mem, $ver));
      }
      
      $rep = "";
      $mem = "";
      $ver = 0;
    }
    else{
      chomp $_;
      
      if (m/^0/){
	if ( m/.*>(.*)\.\.\..*/ )
	{ $rep = $1; }
      }
      else {
	if ( m/.*>(.*)\.\.\..*/ ){
	  if (length($mem))
	    { $mem .= " ^|^ ".$1; }
	  else {$mem = $1;}
	}
      }
      
      $ver = &lookUpVersion($rep,$mem) + 1;
    }
  }
}

#print "$rep\t$mem\t$ver\n";
$sth_insert->execute(($rep, $mem, $ver));
#raise error.
$sth_insert->{RaiseError} = 1;

$dbh->disconnect();
close(DAT);
exit(0);

###############################################################################
sub check_parameters {
  ## at least one input type is required
  unless ( $options{input} ) {
      #print STDERR "no input defined, please read perldoc $0\n\n";
      $logger->logdie("No input defined, plesae read perldoc $0\n\n");
      exit(1);
  }

  if(0){
      pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
  }
}

###############################################################################
sub lookUpVersion{
  my ($rep, $mem) = @_;
  my $dbh = DBI->connect('DBI:mysql:virome;host=10.254.0.1', 'bhavsar', 'Application99') || die $logger->logdie("Cound not open db connection\n");

  ## sql statement to check lib existance.
  my $check_sql = qq/SELECT version FROM uniref_clst WHERE representative like ? and members like ?/;
  
  # prepare statement.
  my $sth_check = $dbh->prepare($check_sql);

  $sth_check->execute((&trim($rep), &trim($mem)));
  my $ref = $sth_check->fetchall_arrayref([],1);
  
  if (@{$ref}){
    ## return libraryId and server name.
    return ($ref->[0]->[0]);
  }
  else{
    return 0;
  }
}

###############################################################################
sub trim($) {
  my $string = shift;
  $string =~ s/^\s+/;
  $string =~ s/\s+$/;
  return $string;
}