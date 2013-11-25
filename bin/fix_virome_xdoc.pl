#!/usr/bin/perl -w

# MANUAL FOR fix_virome_xdocs.pl

=pod

=head1 NAME

fix_virome_xdocs.pl -- fix the issue with virome xDocs counts

=head1 SYNOPSIS

 fix_virome_xdocs.pl --xml /path/to/file.xmldoc.xml --iddoc /path/to/file.iddoc.xml
                     [--help] [--manual]

=head1 DESCRIPTION

Blah
 
=head1 OPTIONS

=over 3

=item B<-x, --xdoc>=FILENAME

Input xmlxdoc (Required) 

=item B<-i, --iddoc>=FILENAME

Input iddoc. (Required) 

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

#ARGUMENTS WITH NO DEFAULT
my($xdoc,$iddoc,$help,$manual);

GetOptions (	
				"x|xdoc=s"	=>	\$xdoc,
				"i|iddoc=s"	=>	\$iddoc,
				"h|help"	=>	\$help,
				"m|manual"	=>	\$manual);

# VALIDATE ARGS
pod2usage(-verbose => 2)  if ($manual);
pod2usage(-verbose => 1)  if ($help);
pod2usage( -msg  => "ERROR!  Required arguments -a and/or -b not found.\n", -exitval => 2, -verbose => 1)  if (! $xdoc || ! $iddoc);

my $strip_id_file_name = $iddoc;
$strip_id_file_name =~ s/.*\///;
my %ID;
my %LEVELS;
my $MAX_TAG;
my $OUT_IDDOC = $iddoc . ".new.xml";
my $OUT_XDOC =  $xdoc . ".new.xml";

open(OUT_X, ">$OUT_XDOC") || die "\n\n cannot write to xdoc output file\n\n";
open(OUT_I, ">$OUT_IDDOC") || die "\n\n cannot write to iddoc output file\n\n";
open(IN,"<$iddoc") || die "\n\n Cannot open the iddoc file\n\n";
while(<IN>) {
    chomp;
    my $line = $_;
    if ($line =~ m/TAG/) {
	my $tag = $line; $tag =~ s/<//; $tag =~ s/ .*//;
	my $ids = $line; $ids =~ s/.*="//;$ids =~ s/"\/>//;
	my @IDS = split(/,/, $ids);
	foreach my $i (@IDS) {
	    $ID{$tag}{$i} = 1;
	}
	$MAX_TAG = $tag;
    }
    unless ($_ =~ m/<\/root>/) {	print OUT_I "$_\n";}
}
close(IN);
$MAX_TAG =~ s/TAG_//;		## strip TAG_ so we have only a number now... Need this variable so we can create and assign new tags.


open(IN,"<$xdoc") || die "\n\n Cannot open the xDoc file\n\n";
while(<IN>) {
    chomp;
    unless ($_ =~ m/FUNCTION/) {
	print OUT_X "$_\n";
    }
    elsif ($_ !~ m/<\//) {
	my @fields = split(/" /, $_);
	my $level = $fields[0];		$level =~ s/ .*//;$level =~ s/.*<FUNCTION_//;
	my $tag = $fields[3];		$tag =~ s/TAG=//;$tag =~ s/"//;
	my $name = $fields[0];		$name =~ s/.*NAME="//;
	$tag = $tag . ";;" . $name;
	if (exists $LEVELS{$level}) {
	    $LEVELS{$level} = "$tag--" . $LEVELS{$level};
	}
	else {
	    $LEVELS{$level} = "$tag";
	}
	print OUT_X "$_\n";
    }
    elsif ($_ =~ m/<\//) {
	my %exists = ();
	my %not_exist = ();
	my $level = $_;	$level =~ s/<\/FUNCTION_//; $level =~ s/>//; $level =~ s/\t*//;
	my $level_up = $level + 1;
	
	if (exists $LEVELS{$level_up}) {
	    my $last_parent_tag =  $LEVELS{$level};
	    $last_parent_tag =~ s/--.*//;
	    $last_parent_tag =~ s/;;.*//;
	    foreach my $j (keys %{ $ID{$last_parent_tag}}) {
		$not_exist{$j} = 1;
	    }
	    my @children_to_check = split (/--/, $LEVELS{$level_up});
	    foreach my $child (@children_to_check) {
		$child =~ s/;;.*//;
		foreach my $j (keys %{ $ID{$child}}) {
		    if (exists $not_exist{$j}) {
			$exists{$j} = 1;
			delete $not_exist{$j};
		    }
		}
	    }
	    my $missing = keys (%not_exist);
	    my $parent_name = $LEVELS{$level}; $parent_name =~ s/--.*//; $parent_name =~ s/.*;;//;
	    unless ($missing == 0) {
		$MAX_TAG++;
		my $iddoc_output = qq |<TAG_$MAX_TAG IDLIST="|;
		foreach my $i (keys %not_exist) {	$iddoc_output .= "$i,"}
		$iddoc_output =~ s/,$/"\/>/;
		print OUT_I "$iddoc_output\n";
		
		my $xdoc_output = "";
		for (my $i = 1; $i <= $level; $i++) {		$xdoc_output .= "\t";}
		$xdoc_output .= qq |<FUNCTION_$level_up NAME="Undefined $parent_name" LABEL="Undefined $parent_name" VALUE ="$missing" TAG="TAG_$MAX_TAG" IDFNAME="$strip_id_file_name"/>|;
		print OUT_X "$xdoc_output\n";
	    }
	    print OUT_X "$_\n";
	    delete $LEVELS{$level_up};			## Erase the previous level
	}
    }
}
close(IN);

print OUT_I "</root>";
close(OUT_X);
close(OUT_I);

#foreach my $i (keys %ID) {
#    foreach my $j (keys %{ $ID{$i}}) {
#	print "$i\t$j\n";
#    }
#}
## Undefined [parent]






