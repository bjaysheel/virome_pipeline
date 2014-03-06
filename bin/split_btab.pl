#!/usr/bin/perl -w

# MANUAL FOR split_btab.pl

=pod

=head1 NAME

split_btab.pl -- splits btab results

=head1 SYNOPSIS

 split_btab.pl --btab /Path/to/infile.btab --out /Path/to/outdir/ --splits=25
                     [--help] [--manual]

=head1 DESCRIPTION

Split btab files such that they don't break up query results.
 
=head1 OPTIONS

=over 3

=item B<-b, --btab>=FILENAME

Input file in BTAB format. (Required) 

=item B<-o, --outdir>=FILENAME

Output directory. (Required) 

=item B<-s, --splits>=INT

Number of splits. (Required)

=item B<-h, --help>

Displays the usage message.  (Optional) 

=item B<-m, --manual>

Displays full manual.  (Optional) 

=back

=head1 DEPENDENCIES

Requires the following Perl libraries.

POSIX

=head1 AUTHOR

Written by Daniel Nasko, 
Center for Bioinformatics and Computational Biology, University of Delaware.

=head1 REPORTING BUGS

Report bugs to dnasko@udel.edu

=head1 COPYRIGHT

Copyright 2012 Daniel Nasko.  
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.  
This is free software: you are free to change and redistribute it.  
There is NO WARRANTY, to the extent permitted by law.  

Please acknowledge author and affiliation in published work arising from this script's 
usage <http://bioinformatics.udel.edu/Core/Acknowledge>.

=cut


use strict;
use Getopt::Long;
use File::Basename;
use Pod::Usage;
use POSIX;

#ARGUMENTS WITH NO DEFAULT
my($btab,$outdir,$splits,$help,$manual);

GetOptions (	
				"b|btab=s"	=>	\$btab,
				"o|outdir=s"	=>	\$outdir,
				"s|splits=i"	=>	\$splits,
				"h|help"	=>	\$help,
				"m|manual"	=>	\$manual);

# VALIDATE ARGS
pod2usage(-verbose => 2)  if ($manual);
pod2usage(-verbose => 1)  if ($help);
pod2usage( -msg  => "ERROR: Required arguments -i not found.\n", -exitval => 2, -verbose => 1)  if (! $btab );
pod2usage( -msg  => "ERROR: Required arguments -o not found.\n", -exitval => 2, -verbose => 1)  if (! $outdir );
pod2usage( -msg  => "ERROR: Required arguments -s not found.\n", -exitval => 2, -verbose => 1)  if (! $splits );


my $lines;
my $infileRoot = $btab;
$infileRoot =~ s/.*\///;
my $r = scalar reverse $infileRoot;
if ($btab =~ m/\.gz$/) { ## if a gzip compressed infile
    open(IN,"gunzip -c $btab |") || die "\n\n Cannot open the input file: $btab\n\n";
    $lines = `zgrep -c "^" $btab`;
    chomp($lines);
    $r =~ s/^.*?\.//;
    $r =~ s/^.*?\.//;
    $infileRoot = scalar reverse $r;
}
else { ## If not gzip comgressed
    open(IN,"<$btab") || die "\n\n Cannot open the input file: $btab\n\n";
    my $lines = `egrep -c "^" $btab`;
    chomp($lines);
    $r =~ s/^.*?\.//;
    $infileRoot= scalar reverse $r;
}
my $file_lines = ceil($lines / $splits);
my $j = 0;

my $split = 1;
my $previous = "";

open(OUT, ">$outdir/$infileRoot-split0$split.btab") || die "\n\n Cannot open output\n\n";
while(<IN>) {
    chomp;
    my $current = $_;
    $current =~ s/\t.*//;
    if ($j >= $file_lines) {
	if ($current ne $previous) {
	    close(OUT);
	    $split++;
	    if (length($split) == 1) {
		open(OUT, ">$outdir/$infileRoot-split0$split.btab") || die "\n\n Cannot open output\n\n";
	    }
	    else {
		open(OUT, ">$outdir/$infileRoot-split$split.btab") || die "\n\n Cannot open output\n\n";
	    }
	    $j = 0;
	    print OUT "$_\n";
	}
	else {
	    print OUT "$_\n";
	}
    }
    else {
	print OUT "$_\n"; 
    }
    $j++;
    $previous = $current;
}
close(IN);
close(OUT);

exit 0;
