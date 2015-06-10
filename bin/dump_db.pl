#!/usr/bin/perl -w

=head1 NAME

dump_db.pl - Dumps the contents of a database into a directory full of table tab files

=head1 SYNOPSIS

USAGE: dump_db.pl
            --info=/Path/to/library.txt
            --outdir=/Path/to/outdir

=head1 OPTIONS

B<--info,-i>
    The library info file

B<--outdir,-o>
    The output directory

B<--help,-h>
    This help message

=head1  DESCRIPTION

Dumps the contents of a database into a directory full of table tab files

=head1  INPUT                                                                                                                                                                                                                              
Output of db-load-library. Essentially a tab-dleimmited file containing:
library_id    library_name    prefix    server    processing_server

=head1  OUTPUT

Directory filled with tab-delimmited table dumps.

=head1  CONTACT                                                                                                                                                                                                                            

    Daniel Nasko
    dan.nasko@gmail.com                                                                                                                                                                                                                    

=cut                                                                                                                                                                                                                                        

use strict;
use DBI;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use UTILS_V;

my ($info,$outdir);
my %options = ();
my $results = GetOptions (\%options,
                          'info|i=s'	=>	\$info,
			  'outdir|o=s'  =>      \$outdir,
			  'help|h') || pod2usage();

## display documentation                                                                                                                                                                                                                    
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

## make sure everything passed was peachy
pod2usage( -msg  => "ERROR!  Required argument -i not found.\n", -exitval => 0, -verbose => 2, -output => \*STDERR)  if (! $info);
pod2usage( -msg  => "ERROR!  Required argument -o not found.\n", -exitval => 0, -verbose => 2, -output => \*STDERR)  if (! $outdir);

## MySQL Server information
my $db_name = "virome";
my $db_host = "virome-db.igs.umaryland.edu";
my $db_user = "dnasko";
my $db_pass = "dnas_76";
my @row;

my $dbh = DBI->connect("DBI:mysql:database=".$db_name.";host=".$db_host, $db_user, $db_pass,{PrintError=>1, RaiseError =>1, AutoCommit =>1});
my $select_sql = qq/SELECT `user` FROM library WHERE id = ? ;/;
my $sth_select = $dbh->prepare($select_sql);

###################################
## Let's Gather Some Information ##
###################################
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
print "User      = $user\n";
if ($processing_db =~ m/diag/) {
    $root = "/diag/projects/virome/";
}
else {
    die "\n\n Cannot determine the root given the processing_db: $processing_db\n\n";
}

##########################
## Dumping the Database ##
##########################

my %processing_databases = (
    'diag1'  =>  'virome_processing_1',
    'diag2'  =>  'virome_processing_2',
    'diag3'  =>  'virome_processing_3',
    'diag4'  =>  'virome_processing_4',
    'diag5'  =>  'virome_processing_5',
    'diag'   =>  'virome_processing'
    );
my @tables = ('blastn','blastp','sequence','statistics','sequence_relationship','tRNA');
my $stg_db_name = '';
if (exists $processing_databases{$processing_db}) {
    $stg_db_name = $processing_databases{$processing_db};
}
else { die "\n Invalid staging database provided: $processing_db\n"; }
print `mkdir $outdir/../$library_id`;

foreach my $table (@tables) {
    print `mysql $stg_db_name -udnasko -hdnode001.igs.umaryland.edu -pdnas_76 -e"SELECT * FROM $table" > $outdir/../$library_id/$table.tab`;
    open(TMP,">$outdir/$table.tab2") || die "\n cannot write to: $outdir/$table.tab2\n";
    print TMP "#";
    open(IN,"<$outdir/../$library_id/$table.tab") || die "\n Cannot open: $outdir/../$library_id/$table.tab\n";
    while(<IN>) {
	chomp;
	print TMP $_ . "\n";
    }
    close(TMP);
    close(IN);
    print `mv $outdir/$table.tab2 $outdir/../$library_id/$table.tab`;
    my $lines = `grep -c "^" $outdir/../$library_id/$table.tab`; chomp($lines);
    if ($lines == 1) {
	print `rm $outdir/../$library_id/$table.tab`;
	print `touch $outdir/../$library_id/$table.tab`;
    }
}

print `mkdir $outdir/../$library_id/xDocs`;
print `mkdir $outdir/../$library_id/idFiles`;
print `cp /diag/projects/virome/virome-cache-files/xDocs/*_$library_id.xml $outdir/../$library_id/xDocs`;
print `cp /diag/projects/virome/virome-cache-files/idFiles/*_$library_id.txt $outdir/../$library_id/idFiles`;
print `tar -czvf $outdir/../$library_id.tar.gz --directory=$outdir/../ $library_id`;

exit 0;
