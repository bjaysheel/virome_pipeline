#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
use strict;

die "list file was not defined" if (!defined($ARGV[0]));
open (LISTFILE, "<$ARGV[0]") or die "Could not open asmbl_id list file '$ARGV[0]";

while (my $line = <LISTFILE>){
    
    chomp $line;

    if ($line =~ /^(\d+)/){
	my $asmbl_id = $1;
	my $execstring = "perl -I /usr/local/scratch/sundaram/bsml/src -I shared -I Prism ./legacy2bsml.pl -U sundaram -P sundaram7 -a $asmbl_id -D bma1 -F /usr/local/scratch/annotation/NEMA/FASTA_repository/ -o /usr/local/scratch/annotation/NEMA/BSML_repository/legacy2bsml/ -M 2 -e 1 -l /usr/local/scratch/annotation/NEMA/BSML_repository/legacy2bsml/bma1_$asmbl_id.log";
	
	print "legacy2bsml.pl on asmbl_id '$asmbl_id'\n";
	qx($execstring);
    }
    else{
	die "Could not parse line '$line'";
    }
}
