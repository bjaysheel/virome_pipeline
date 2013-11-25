#!/usr/bin/perl

use lib ('../lib/perl5');
use strict;
use warnings;
use DBI;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use Switch;
use UTILS_V;
use MLDBM 'DB_File';
use Data::Dumper;

##############################################################################
my %options = ();
my $results = GetOptions (\%options,
			  'env|e=s',
                          'log|l=s',
                          'debug|d=s',
                          'help|h') || pod2usage();

## display documentation
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}
##############################################################################

## make sure everything passed was peachy
&check_parameters(\%options);

my $utils = new UTILS_V;
$utils->set_db_params($options{env});

my $db_name="terpsichore";
my $db_host="jabba.igs.umaryland.edu";
my $db_user="dnasko";
my $db_pass="dnas_76";

my $dbh = DBI->connect("DBI:mysql:database=".$db_name.";host=".$db_host,
	    $db_user, $db_pass,{PrintError=>1, RaiseError =>1, AutoCommit =>1});

tie(my %mgol, 'MLDBM', "/usr/local/projects/virome/lookup/mgol.ldb");
$utils->mgol_lookup(\%mgol);

my $sel_qry = qq{SELECT b.id,b.hit_name
		 FROM   blastp b inner join sequence s on b.sequenceId=s.id
                 WHERE  b.database_name = 'METAGENOMES' and s.libraryId=69
		 ORDER BY b.id
                };


my $seq_sth = $dbh->prepare($sel_qry);
$seq_sth->execute();

while (my $row = $seq_sth->fetchrow_hashref){
    my $mgol_acc_hash = $utils->get_acc_from_lookup("mgol",substr($$row{hit_name},0,3));
    my $mgol_hash = $mgol_acc_hash->{acc_data}[0];
    
    my $dwel = "N/A";
   
    if ($mgol_hash->{org_subst} ne "UNKNOWN"){
        $dwel = 'dwelling ' .$mgol_hash->{org_subst};
    } else {
        $dwel = $mgol_hash->{phys_subst};
    }
    my $str = "$mgol_hash->{lib_type} metagenome from $mgol_hash->{ecosystem} $dwel ".
              "near $mgol_hash->{geog_place_name}, $mgol_hash->{country} [library: $mgol_hash->{lib_shortname}]";
    $str =~ s/'|"//g;
    
    my $upd_qry = "UPDATE blastp SET hit_description='$str' WHERE id=".$$row{id};
    #print $upd_qry."\n";
    my $upd = $dbh->prepare($upd_qry);
    $upd->execute();
}

exit(0);

###############################################################################
sub check_parameters {
  ## at least one input type is required
  unless ( $options{env} ) {
      pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
      exit(1);
  }
}
