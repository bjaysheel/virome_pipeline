#!/usr/bin/perl -w

# MANUAL FOR split_multifasta.pl

=pod

=head1 NAME

 split_multifasta.pl -- split a fasta ... a little more accurately.

=head1 SYNOPSIS

 split_multifasta.pl -in /Path/to/infile.fasta -out /Path/to/outdir/ -prefix output_root  -splits 20 
                     [--help] [--manual]

=head1 DESCRIPTION

 Split a multifasta file into $splits splits and make sure
 there's an even distribuition of bases in those splits!
 
=head1 OPTIONS

=over 3

=item B<-i, --in>=FILENAME

Input file in FASTA format. (Required) 

=item B<-o, --out>=DIR

Output directory. (Required)

=item B<-p, --prefix>=NAME

Root name for all the output splits. ( Default="split")

=item B<-s, --split>=INT

Number of files to split the FASTA into. (Required)

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

Copyright 2014 Daniel Nasko.  
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

#ARGUMENTS WITH NO DEFAULT
my($infile,$out,$splits,$help,$manual);
my $prefix = "split";
GetOptions (
    "i|in=s"=>\$infile,
    "o|out=s"=>\$out,
                                "s|splits=i"    =>      \$splits,
    "p|prefix=s"    =>      \$prefix,
    "h|help"=>\$help,
    "m|manual"=>\$manual);

# VALIDATE ARGS
pod2usage(-verbose => 2)  if ($manual);
pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} )  if ($help);
pod2usage( -msg  => "\n\n ERROR!  Required argument -infile not found.\n\n", -exitval => 2, -verbose => 1)  if (! $infile );
pod2usage( -msg  => "\n\n ERROR!  Required argument -out not found.\n\n", -exitval => 2, -verbose => 1)     if (! $out);
pod2usage( -msg  => "\n\n ERROR!  Required argument -splits not found.\n\n", -exitval => 2, -verbose => 1)  if (! $splits );

my $line_count = 0;
my ($header,$seq);

my %Size;

if ($infile =~ m/\.gz$/) { ## if a gzip compressed infile
    open(IN,"gunzip -c $infile |") || die "\n\n Cannot open the input file: $infile\n\n";
}
else { ## If not gzip comgressed
    open(IN,"<$infile") || die "\n\n Cannot open the input file: $infile\n\n";
}
while(<IN>) {
    chomp;
    if ($line_count == 0) {
	$header = $_;
	$header =~ s/^>//;
    }
    elsif ($_ =~ m/^>/) {
	$Size{length($seq)}{$header} = 0;
	$seq = "";
	$header = $_;
	$header =~ s/^>//;
    }
    else {
	$seq = $seq . $_;
    }
    $line_count++;
}
close(IN);
$Size{length($seq)}{$header} = 0;

## Okay, let's divy up which seqs got to which file:
## 1, 2, 3, ..., n-1, n, n, n-1, ..., 3, 2, 1, 1, 2, 3 ...

my $num = 1;
my $up = 1;
foreach my $i (sort {$b<=>$a} keys %Size) {
    foreach my $j (keys %{$Size{$i}}) {
	if ($num == 1) {
	    if ($up == 1) {
		$Size{$i}{$j} = $num;
		$num++;
	    }
	    else {
		$up = 1;
		$Size{$i}{$j} =$num;
	    }
	}
	elsif ($num == $splits) {
	    if ($up == 1) {
		$up = 0;
		$Size{$i}{$j} = $num;
	    }
            else {
		$Size{$i}{$j} = $num;
		$num--;
            }
	}
	else {
	    $Size{$i}{$j} =$num;
	    if ($up == 1) { $num++; }
	    else { $num--; }
	}
    }
}

## If any of the split files exist already, get rid of them!
for (my $i=1;$i <= $splits; $i++) {
    if (-e "$out/$prefix-$i.fasta") {
	print `rm $out/$prefix-$i.fasta`;
    }
}

## Okay, lets go through again, and start printing some things out here...
($line_count,$header,$seq) = (0,"","");
if ($infile =~ m/\.gz$/) { ## if a gzip compressed infile
    open(IN,"gunzip -c $infile |") || die "\n\n Cannot open the input file: $infile\n\n";
}
else { ## If not gzip comgressed
    open(IN,"<$infile") || die "\n\n Cannot open the input file: $infile\n\n";
}
while(<IN>) {
    chomp;
    if ($line_count == 0) {
	$header = $_;
        $header =~ s/^>//;
    }
    elsif ($_ =~ m/^>/) {
	if (exists $Size{length($seq)}{$header}) {
	    open(OUT,">>$out/$prefix-$Size{length($seq)}{$header}.fasta") || die "\n Cannot write to: $out/$prefix-$Size{length($seq)}{$header}.fasta\n";
	    print OUT ">" . $header . "\n" . $seq . "\n";
	    close(OUT);
	}
	else {
	    die "\n Error: This sequence is missing: $header\n\n";
	}
	$seq = "";
	$header = $_;
	$header =~ s/^>//;
    }
    else {
        $seq = $seq . $_;
    }
    $line_count++;
}
close(IN);
if (exists $Size{length($seq)}{$header}) {
    open(OUT,">>$out/$prefix-$Size{length($seq)}{$header}.fasta") || die "\n Cannot write to: $out/$prefix-$Size{length($seq)}{$header}.fasta\n";
    print OUT ">" . $header . "\n" . $seq . "\n";
    close(OUT);
}
else {
    die "\n Error: This sequence is missing: $header\n\n";
}

exit 0;
