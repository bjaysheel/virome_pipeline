#!/usr/bin/perl

# MANUAL FOR btab2viromebtab.pl

=pod

=head1 NAME

btab2viromebtab.pl -- converts btab files

=head1 SYNOPSIS

 btab2viromebtab.pl --input /path/to/file.btab --prefix=base_name --outdir=/path/to/outdir/ --algorithm=BLASTN
                     [--help] [--manual]

=head1 DESCRIPTION

Runs through your input BTAB file and will convert it to
the BTAB format needed for the VIROME pipeline.

Input Fields:
===== ======
 1 qseqid
 2 qlen
 3 sseqid
 4 qstart
 5 qend
 6 sstart
 7 send
 8 pident
 9 ppos
10 score
11 bitscore
12 salltitles
13 frames
14 sstrand
15 slen
16 evalue

Output Fields:
====== ======
 1 query_name
 2 date
 3 query_length
 4 algorithm
 5 database_name
 6 hit_name
 7 qry_start
 8 qry_end
 9 hit_start
10 hit_end
11 percent_identity
12 percent_similarity
13 raw_score
14 bit_score
15 NULL
16 hit_description
17 blast_frame
18 qry_strand
19 hit_length
20 e_value
21 p_balue

=head1 OPTIONS

=over 3

=item B<-i, --input>=FILENAME

Input file in BTAB format. (Required)

=item B<-o, --outdir>=FILENAME

Output file directory. (Required)

=item B<-p, --prefix>=FILENAME

Name of the output file. (Required)

=item B<-a, --algorithm>=FILENAME

Name of the program (BLASTN or BLASTP). (Required)

=item B<-d, --database>=FILENAME

Name of the database (UNIREF100P_SEP2013, METAGENOMES_FEB2013, UniVec_Core, rRNA). (Required)

=item B<-h, --help>

Displays the usage message.  (Optional)

=item B<-m, --manual>

Displays full manual.  (Optional)

=back

=head1 DEPENDENCIES

Requires the following Perl libraries.



=head1 AUTHOR

Written by Daniel Nasko,
Center for Bioinformatics and Computational Biology, University of Delaware.

=head1 REPORTING BUGS

Report bugs to dnasko@udel.edu

=head1 COPYRIGHT

Copyright 2013 Daniel Nasko.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Please acknowledge author and affiliation in published work arising from this script's
usage <http://bioinformatics.udel.edu/Core/Acknowledge>.

=cut


use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use Pod::Usage;

#ARGUMENTS WITH NO DEFAULT
my($infile,$outdir,$prefix,$algorithm,$database,$help,$manual);

#ARGUMENTS WITH DEFAULT
my $e = 2.71828182845904523536028747135266249775724709369995;

GetOptions (
                             "i|infile=s"=>\$infile,
                             "o|outdir=s"=>\$outdir,
                             "p|prefix=s"=>\$prefix,
                             "a|algorithm=s" =>\$algorithm,
                             "d|database=s" =>\$database,
                             "h|help"=>\$help,
                             "m|manual"=>\$manual);

# VALIDATE ARGS
pod2usage(-verbose => 2)  if ($manual);
pod2usage(-verbose => 1)  if ($help);
pod2usage( -msg  => "\n\n ERROR!  Required argument -infile missing or not found.\n", -exitval => 2, -verbose => 1)  if (! $infile );
pod2usage( -msg  => "\n\n ERROR!  Required argument -outdir missing or not found.\n", -exitval => 2, -verbose => 1)  if (! $outdir );
pod2usage( -msg  => "\n\n ERROR!  Required argument -prefix missing or not found.\n", -exitval => 2, -verbose => 1)  if (! $prefix );
pod2usage( -msg  => "\n\n ERROR!  Required argument -algorithm missing or not found.\n", -exitval => 2, -verbose => 1)  if (! $algorithm );
pod2usage( -msg  => "\n\n ERROR!  Required argument -database missing or not found.\n", -exitval => 2, -verbose => 1)   if (! $database );

my $date = `date +%Y-%m-%d`; chomp($date);

open(IN, "<", $infile) || die "\n\n Error: Cannot open the infile: $infile\n\n";
open(OUT, ">", "$outdir/$prefix.btab") || die "\n\n Error: Cannot open the outfile: $outdir/$prefix.btab\n\n";
while(<IN>) {
    chomp;
    my @A = split(/\t/, $_);

    #### Jaysheel Bhavsar 11/24/15
    #### p-value is removed in clean_expand_btab output
    #### dummpy value to keep expected columns the same for downstream scripts.
    #my $pvalue = 1-($e**(-1*$A[15]));
    my $pvalue = $e;

    if ($algorithm =~ m/blastp/i) {
	print OUT $A[0] . "\t" . $date . "\t" . $A[1] . "\t" .
	    $algorithm . "\t" . $database . "\t" . $A[2] . "\t" .
	    $A[3] . "\t" . $A[4] ."\t" . $A[5] ."\t" . $A[6] ."\t" .
	    $A[7] ."\t" . $A[8] ."\t" . $A[9] ."\t" . $A[10] ."\t" .
	    "NULL" . "\t" . $A[11] ."\t" . $A[12] ."\t" . $A[13] ."\t" .
	    $A[14] ."\t" . $A[15] ."\t" . $pvalue . "\n";
    }
    elsif ($algorithm =~ m/blastn/i) {
	print OUT $A[0] . "\t" . $A[1] . "\t" .
	    $algorithm . "\t" . $database . "\t" . $A[2] . "\t" .
	    $A[3] . "\t" . $A[4] ."\t" . $A[5] ."\t" . $A[6] ."\t" .
	    $A[7] ."\t" . $A[8] ."\t" . $A[9] ."\t" . $A[10] ."\t" .
	    $A[11] ."\t" . $A[12] ."\t" . $A[13] ."\t" .
	    $A[14] ."\t" . $A[15] ."\t" . $pvalue . "\n";
    }
    else {
        die "\n Error: The algorithm you supplied is neither BLASTp nor, BLASTn\n\n";
    }
}
close(OUT);
close(IN);

exit 0;
