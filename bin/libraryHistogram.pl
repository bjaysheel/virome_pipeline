#!/usr/bin/perl

=head1 NAME
   libraryHistorgram.pl

=head1 SYNOPSIS

    USAGE: libraryHistogram.pl --server server-name --env dbi [--library libraryId]

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
    Create XML document that contaions information to draw histogram
    of GC, read sizes and orf sizes to be displayed on VIROME library
    statistics page.

=head1  INPUT
    The input is defined with --server,  --library.

=head1  OUTPUT
   Updated blastp tables for all/specifed library.

=head1  CONTACT
  Jaysheel D. Bhavsar @ bjaysheel[at]gmail[dot]com


==head1 EXAMPLE
   libraryHistogram.pl --server calliope --env dbi --library 31

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
my $results = GetOptions (\%options,
                          'server|s=s',
                          'library|b=s',
			  'env|e=s',
                          'input|i=s',
                          'outdir|o=s',
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
my $dbh0;
my $dbh;

my $libinfo = LIBInfo->new();
my $libObject;

my $utils = new UTILS_V;
$utils->set_db_params($options{env});

my $file_loc = $options{outdir}."/xDocs";

## make sure everything passed was peachy
&check_parameters(\%options);
##############################################################################
timer(); #call timer to see when process started.

my $lib_sel = $dbh0->prepare(q{SELECT id FROM library WHERE deleted=0 and server=?});

my $orf_sel = $dbh->prepare(q{SELECT s.size*3 as hval
							  FROM 	sequence s
								INNER JOIN
									sequence_relationship sr on s.id = sr.objectId
							  WHERE s.libraryId = ?
								and sr.typeId = 3
								and s.deleted = 0
							  ORDER BY hval desc});

my $read_sel = $dbh->prepare(q{SELECT s.size as hval
							  FROM 	sequence s
								INNER JOIN
									sequence_relationship sr on s.id = sr.objectId
							  WHERE s.libraryId = ?
								and sr.typeId = 1
								and s.deleted = 0
							  ORDER BY hval desc});

my $gc_sel = $dbh->prepare(q{SELECT s.gc as hval
							  FROM 	sequence s
								INNER JOIN
									sequence_relationship sr on s.id = sr.objectId
							  WHERE s.libraryId = ?
								and sr.typeId = 1
								and s.deleted = 0
							  ORDER BY hval desc});

my $rslt = '';
my @libArray;

if ($options{library} <= 0){
    $lib_sel->execute($options{server});
    $rslt = $lib_sel->fetchall_arrayref({});

    foreach my $lib (@$rslt){
	push @libArray, $lib->{'id'};
    }
} else {
    push @libArray, $options{library};
}

foreach my $lib (@libArray){
    print "Processing library: $lib\n";

    #print "\n\nBin ORFs\n";
    $orf_sel->execute($lib);
    $rslt = $orf_sel->fetchall_arrayref({});
    binORFnREADs($rslt, $lib, "ORF");

    #print "\n\nBin READs\n";
    $read_sel->execute($lib);
    $rslt = $read_sel->fetchall_arrayref({});
    binORFnREADs($rslt, $lib, "READ");

    #print "\n\nBin GC\n";
    $gc_sel->execute($lib);
    $rslt = $gc_sel->fetchall_arrayref({});
    binGC($rslt, $lib, "GC");
}

timer(); #call timer to see when process ended.
exit(0);


###############################################################################
####  SUBS
###############################################################################
sub check_parameters {
   my $options = shift;

    my $flag = 0;

    # if library list file or library file has been specified
    # get library info. server, id and library name.
    if ((defined $options{input}) && (length($options{input}))){
      $libObject = $libinfo->getLibFileInfo($options{input});
      $flag = 1;
    }

    # if server is not specifed and library file is not specifed show error
    if (!$options{server} && !$flag){
      pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
      exit(-1);
    }

    # if exec env is not specified show error
    unless ($options{env}) {
      pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
      exit(-1);
    }

    # if no library info set library to -1;
    unless ($options{library}){
        $options{library} = -1;
    }

	system ("mkdir -p $options{outdir}/idFiles");
	system ("mkdir -p $options{outdir}/xDocs");

	$dbh0 = DBI->connect("DBI:mysql:database=".$utils->db_name.";host=".$utils->db_host,
		$utils->db_user, $utils->db_pass, {PrintError=>1, RaiseError =>1, AutoCommit =>1});

    $dbh = DBI->connect("DBI:mysql:database=".$utils->db_name.";host=".$utils->db_host,
		$utils->db_user, $utils->db_pass, {PrintError=>1, RaiseError =>1, AutoCommit =>1});

}

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
sub binORFnREADs {
    my ($rslt, $lib, $type) = @_;

    if (@{$rslt} > 0){
        my $lastIdx = 0 + @{$rslt} -1;

        my $k = 30;
        my $min = $rslt->[$lastIdx]->{hval};
        my $max = $rslt->[0]->{hval}; #not order is desc hense max is first.
        my $bin = int(($max-$min)/$k);

        my @range_arr = ();
        for (my $i=0; $i<$k; $i++){
            push @range_arr, {'bin' => ($min +  ($bin*$i)),
                              'count' => 0};
        }

        my @t_sort = sort { $b->{bin} <=> $a->{bin} } @range_arr;

        foreach my $row (@$rslt) {
            for (my $i=0; $i<=$#t_sort; $i++){
                if ($row->{hval} >= $t_sort[$i]->{'bin'}){
                    $t_sort[$i]->{'count'}++;
                    $i = $#t_sort;
                }
            }
        }

        @range_arr = sort { $a->{bin} <=> $b->{bin} } @t_sort;
        printXML($lib, $type, \@range_arr);

        #foreach $bin (@range_arr){
        #    print $bin->{bin}."\t".$bin->{count}."\n";
        #}
    } else {
        print "Nothing to do, empty result set\n";
    }
}

###############################################################################
sub binGC {
    my ($rslt, $lib, $type) = @_;
    if (@{$rslt} > 0){
        my $lastIdx = 0 + @{$rslt} -1;

        my $k = 21;
        my $min = 0;
        my $max = 100;
        my $bin = 5;

        my @range_arr;
        for (my $i=0; $i<$k; $i++){
            push @range_arr, {'bin' => ($min +  ($bin*$i)),
                              'count' => 0};
        }

        my @t_sort = sort { $b->{bin} <=> $a->{bin} } @range_arr;

        foreach my $row (@$rslt) {
            for (my $i=0; $i<=$#t_sort; $i++){
                if ($row->{hval} >= $t_sort[$i]->{'bin'}){
                    $t_sort[$i]->{'count'}++;
                    $i = $#t_sort;
                }
            }
        }

        @range_arr = sort { $a->{bin} <=> $b->{bin} } @t_sort;
        printXML($lib, $type, \@range_arr);

        #foreach $bin (@range_arr){
        #    print $bin->{bin}."\t".$bin->{count}."\n";
        #}
    } else {
        print "Nothing to do, empty result set\n";
    }
}

###############################################################################
sub printXML {
    my ($lib, $type, $arr) = @_;

    my $filename = $file_loc . "/".$type."_HISTOGRAM_".$lib.".xml";

    my $output = new IO::File(">$filename") or die "Could not open file $filename to write\n";
    my $writer = new XML::Writer(OUTPUT=>$output);

    #print $arr[0]."\n";

    $writer->xmlDecl("UTF-8");

    $writer->startTag("root");
    foreach my $bin (@{$arr}){
        $writer->emptyTag("CATEGORY", 'LABEL'=> $bin->{bin}, 'VALUE'=> $bin->{count});
    }
    $writer->endTag("root");
    $writer->end();
    $output->close();
}
