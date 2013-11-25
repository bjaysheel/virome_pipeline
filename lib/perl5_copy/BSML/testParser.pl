#!/usr/local/bin/perl
use strict;
use Data::Dumper;
use BSML::Parser;
use Annotation::Util2;

my $file = $ARGV[0];
if (!defined($file)){
    $file = '/usr/local/annotation/PHYTAX/output_repository/db2bsml/14790_default/i1/g1/phytoplankton_8551_assembly..bsml';
}


if ( ! Annotation::Util2::checkInputFileStatus($file)){
    die "Detected some problem with BSML file '$file'";
}

my $parser = new BSML::Parser(file=>$file);

if (!defined($parser)){
    die "Could not instantiate BSML::Parser";
}


&reportSomeFeatures();

&reportFeatureCounts();

my $refseq = $parser->getRefSeq();
if (!defined($refseq)){
    die "Could not retrieve the reference sequence identifier";
}

print "The reference sequence identifier is '$refseq'\n";

print "$0 execution completed\n";
exit(0);

##----------------------------------------------
##
##    END OF MAIN -- SUBROUTINES FOLLOW
##
##----------------------------------------------

sub reportFeatureCounts {

    my $geneCtr = $parser->getGeneCount();
    if (!defined($geneCtr)){
	die "gene count was not defined";
    } else {
        print "Encountered '$geneCtr' genes\n";
    }

    my $transcriptCtr = $parser->getTranscriptCount();
    if (!defined($transcriptCtr)){
	die "transcript count was not defined";
    } else {
        print "Encountered '$transcriptCtr' transcripts\n";
    }

    my $cdsCtr = $parser->getCDSCount();
    if (!defined($cdsCtr)){
	die "CDS count was not defined";
    } else {
        print "Encountered '$cdsCtr' CDS features\n";
    }

    my $polypeptideCtr = $parser->getPolypeptideCount();
    if (!defined($polypeptideCtr)){
	die "polypeptide count was not defined";
    } else {
        print "Encountered '$polypeptideCtr' polypeptides\n";
    }

    my $exonCtr = $parser->getExonCount();
    if (!defined($exonCtr)){
	die "exon count was not defined";
    } else {
        print "Encountered '$exonCtr' exons\n";
    }

    my $miscCtr = $parser->getMiscellaneousFeatureCount();
    if (!defined($miscCtr)){
	print "Did not find any miscellaneous features\n";
    } else {   
	print "Encountered '$miscCtr' miscellaneous features\n";
    }
}

sub reportSomeFeatures {


    my $lookup = $parser->getLookup();
    if (!defined($lookup)){
	die "Could not retrieve feature lookup";
    }

    print "Here are the first five features in the lookup:\n";

    my $ctr=0;

    foreach my $id (keys %{$lookup}){
	$ctr++;
	print "\t$id\n";
	if ($ctr == 5){
	    last;
	}
    }
}
