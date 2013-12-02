#!/usr/bin/perl -w

=head1 NAME
  update_mgol_names_in_fasta.pl 

=head1 SYNOPSIS
  USAGE: update_mgol_name.pl --fasta fasta-file-name

=head1 OPTIONS
 
B<--fasta,-f>
  Fasta file name from where MGOL sequence(s) names needs to be updated

B<--outdir, -o>
  Output directory where updated MGOL fasta file will be stored.
  
B<--help,-h>
  This help message

=head1  DESCRIPTION
  Update MGOL sequence name to have appropriate 3 letter prefix as defined in mgol_library table.
  
=head1  INPUT
  The input is defined with --fasta and --map.

=head1  OUTPUT
  Updated sequence name in the given fasta file

=head1  CONTACT
  Jaysheel D. Bhavsar @ bjaysheel[at]gmail[dot]com

==head1 EXAMPLE
  update_mgol_names_in_fasta.pl --fasta filename.fasta --outdir /path/to/output-dir

=cut


use strict;
use DBI;
use File::Basename;
use Pod::Usage;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
BEGIN {
  use Ergatis::Logger;
}

my %par = ();
my $results = GetOptions (\%par,
                          'fasta|f=s',
			  'outdir|o=s',
                          'log|l=s',
                          'debug|d=s',
                          'help|h') || pod2usage();

my $logfile = $par{'log'} || Ergatis::Logger::get_default_logfilename();
my $logger = new Ergatis::Logger('LOG_FILE'=>$logfile,
                                  'LOG_LEVEL'=>$par{'debug'});
$logger = $logger->get_logger();

## display documentation
if( $par{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

##############################################################################
#### DEFINE GLOBAL VAIRABLES.
##############################################################################

## make sure everything passed was peachy
&check_parameters(\%par);

my $db_user = q|jbhavsar|;
my $db_pass = q|jbhavsar58|;
my $dbname = q|uniref_lookup|;
my $db_host = q|jabba|;

my $dbh = DBI->connect("DBI:mysql:database=$dbname;host=$db_host",
	"$db_user", "$db_pass",{PrintError=>1, RaiseError =>1, AutoCommit =>1}) || die $logger->logdie("Cound not open db connection\n");

$dbh->{RaiseError} = 1;

my $sel_stmt = $dbh->prepare(qq{SELECT prefix FROM map where name=?});
##############################################################################

#get dir where input fasta file is located.
my $OUTPUT_FILE = $par{outdir}."/".basename($par{fasta}).".fsa";

#open input and output fasta file
open (DAT, "<$par{fasta}") or die $logger->logdie("Cannot open file $par{fasta}\n");
open (OUT, ">$OUTPUT_FILE") or die $logger->logdie("Cannot open file $OUTPUT_FILE\n");

#print ("DEBUG: OPENING FILE TO PROCESS.\n");
while (<DAT>){
    chomp $_;
    if (length($_)){
      if ($_ =~ /^>/){
	  my @header = split(/ /,$_);
	  my $seq_name = $header[0];
	   
	  $seq_name =~ s/^>//;
	  $seq_name =~ s/^ //;
	  $seq_name =~ s/ $//;
	  
	  #print ("DEBUG: LOOKING UP PREFIX FOR $seq_name.\n");
	  $sel_stmt->execute($seq_name);
	  my $rslt = $sel_stmt->fetchall_arrayref({});
  
	  my $prefix = '';
	  foreach my $row (@$rslt) {
	      $prefix = $row->{prefix};
	  }
  
	  if (length($prefix) <= 0){
	      print STDOUT ("WARNING: prefix for $seq_name not found.  Skipping record.\n");
	  } else {
	      $seq_name =  $prefix . "_" . $seq_name;
	      $header[0] = ">" . $seq_name;
	      $_ = join (" ",@header);
	  }
      }
      print OUT $_."\n";
    }
}
close OUT;
close DAT;

#print ("DEBUG: ALL DONE.\n");

exit(0);
###############################################################################
####  SUBS
###############################################################################
sub check_parameters {
   my $par = shift;

   ## make sure sample_file and output_dir were passed
   unless (($par{fasta}) && ($par{outdir})) {
      pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
   }
}
