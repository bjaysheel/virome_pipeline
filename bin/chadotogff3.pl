#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
=head1 NAME

chadotogff3.pl - Parse BSML document and produce tab delimited .out BCP files for insertion into Chado database

=head1 SYNOPSIS

USAGE:  chadotogff3.pl -D database --database_type -P password -U username --server -b bsmldoc [-d debug_level] [-h] [-l log4perl] [-m] [-o outdir]

=head1 OPTIONS

=over 8

=item B<--username,-U>

Database username

=item B<--password,-P>

Database password

=item B<--database,-D>

Target chado database 

=item B<--database_type>

Relational database management system type e.g. sybase or postgresql

=item B<--server>

Name of server on which the database resides

=item B<--bsmldoc,-b>

Bsml document containing pairwise alignment encodings

=item B<--autogen_feat,-a>

Optional - Default behavior is to auto-generate (-a=1) chado feature.uniquename values for all inbound features.  To turn off behavior specify this command-line option (-a=0).

=item B<--autogen_seq,-s>

Optional - Default behavior is to not (-s=0) auto-generate chado feature.uniquename values for all inbound sequences.  To turn on behavior specify this command-line option (-s=1).

=item B<--insert_new,-i>

Optional - Default behavior is to insert (-i=1) insert newly encountered Sequence objects in the BSML document that are not currently present in the Chado database.  To turn off default insert behavior specify this command-line option (-i=0)

=item B<--id_repository>

Optional - IdGenerator.pm stores files for tracking unique identifier values - some directory e.g. /usr/local/scratch/annotation/CHADO_TEST6/workflow/project_id_repository should be specified.  Default directory is ENV{ID_REPOSITORY}.

=item B<--debug_level,-d>

 Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

Display the pod2usage page for this utility

=item B<--outdir,-o>

 Optional: Output directory for the tab delimited .out files.  Default is current directory

=item B<--no-placeholders>

Optional - Do not insert placeholders variables in place of table serial identifiers (default is to insert placeholder variables)

=item B<--timestamp>

Optional - Time stamp e.g.  'Jun  5 2006  6:59PM' to be stored in feature.timeaccessioned (if required), feature.timelastmodified, analysis.timeexecuted
Default behavior is to auto-generate the timestamp.

=item B<--update,-u>

Optional - Default behavior is to not update the database (-u=0).  To turn on update behavior specify this command-line option (-u=1).


=item B<--cache_dir,-y>

Optional - Query caching directory to write cache files (default is ENV{DBCACHE_DIR})

=item B<--readonlycache,-R>

Optional - If data file caching is activated and if this readonlycache is == 1, then the tied MLDBM lookup cache files can only be accessed in read-only mode.  Default (-r=0) means cached lookup can be created and access mode is read-write.

=item B<--doctype,-z>

Optional - If specified, can direct the parser to construct concise lookup - more efficient. One of the following: nucmer, region, promer, pe, blastp, repeat, scaffold, rna, te, coverage

=item B<--help,-h>

Print this help

=item B<--gzip_bcp>

Optional - writes the BCP .out files in compressed format with .out.gz file extension

=item B<--parse-match-sequence-fasta>

Optional - If specified, chadotogff3.pl will parse the Seq-data-import and FASTA file associated with the 'match' Sequence stubs.  Default behaviour is to ignore these Sequence stubs' FASTA data.

=item B<--exclude_classes>

Optional - If specified, chadotogff3.pl will skip all Sequence and Feature objects that have anyone of the listed classes

=item B<--include_classes>

Optional - If specified, chadotogff3.pl only process Sequence and Feature objects that have anyone of the listed classes

=back

=head1 DESCRIPTION

chadotogff3.pl - Parse BSML document and produce tab delimited .out BCP files for insertion into Chado database

 Assumptions:
1. The BSML pairwise alignment encoding should validate against the XML schema:.
2. User has appropriate permissions (to execute script, access chado database, write to output directory).
3. Target chado database already contains all reference features (necessary to build feature and organism lookups) Review and execute db2bsml.pl if required.
4. Target chado database contains the necessary controlled vocabulary terms: "match" etc.
5. All software has been properly installed, all required libraries are accessible.

Sample usage:
./chadotogff3.pl -U access -P access -D tryp -b /usr/local/annotation/TRYP/BSML_repository/blastp/lma2_86_assembly.blastp.bsml  -l my.log -o /tmp/outdir


=cut


use strict;
use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Coati::Logger;
use Config::IniFiles;
use Tie::File;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($username, $password, $database, $server, $debug_level,
    $help, $log4perl, $man, $outdir, $source, $contig, $topology,
    $translation_table, $localization, $molecule_type, $gffFilename,
    $database_type);


my $results = GetOptions (
			  'username=s'       => \$username, 
			  'password=s'       => \$password,
			  'database=s'       => \$database,
			  'database_type=s'  => \$database_type,
			  'server=s'         => \$server,
			  'log4perl=s'       => \$log4perl,
			  'debug_level|d=s'  => \$debug_level, 
			  'help|h'           => \$help,
			  'man|m'            => \$man,
			  'outdir=s'         => \$outdir,
			  'source=s'         => \$source,
			  'contig=s'         => \$contig,
			  'topology=s'       => \$topology,
			  'translation_table=s' => \$translation_table,
			  'localization=s'       => \$localization,
			  'molecule_type=s'      => \$molecule_type,
			  'outfile=s'            => \$gffFilename
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

my $fatalCtr=0;

if (!defined($database)){
    print STDERR "database was not defined\n";
    $fatalCtr++;
}
if (!defined($database_type)){
    print STDERR "database_type was not defined\n";
    $fatalCtr++;
}
if (!defined($username)){
    print STDERR "username was not defined\n";
    $fatalCtr++;
}
if (!defined($password)){
    print STDERR "password was not defined\n";
    $fatalCtr++;
}
if (!defined($server)){
    print STDERR "server was not defined\n";
    $fatalCtr++;
}

if($fatalCtr>0){
    &printUsage();
}

## Valid strand values
my $validStrandTypes = { '+' => 1,
			 '-' => 1,
			 '.' => 1 };

## Valid phase values
my $validPhaseTypes = { '.' => 1,
			'0' => 1,
			'1' => 1,
			'2' => 1 };


my $validMoleculeTypes = { 'dsDNA' => 1 };

my $validTranslationTableValues = { '11' => 1 };

my $validTopologyValues = { 'linear' => 1 };

my $validFeatureTypes = { 'transcript' => 1,
			  'gene' => 1,
			  'CDS' => 1,
			  'exon' => 1 };
			  

## Get the Log4perl logger
my $logger = &setLogger($log4perl, 
			$debug_level,
			$contig);


if (!defined($source)){
    $source = $database;
}
if (! defined ($topology)){
    $topology = 'linear';
}
if (! defined ($translation_table)){
    $translation_table = '11';
}
if (! defined ($localization)){
    $localization = 'chromosomal';
}
if (! defined ($molecule_type)){
    $molecule_type = 'dsDNA';
}



## verify and set the output directory
$outdir = &verifyAndSetOutdir($outdir);


## Set the PRISM env var
&setPrismEnv($server, $database_type);

my $prism = &createPrismObject($username,
			       $password,
			       $database);


my $gffLines = [];

&buildGFF3HeaderSection();

my $seq_id = &buildContigGFFRecords($database,
				    $contig,
				    $prism);


&buildGeneModelGFFRecords($database,
			  $contig,
			  $seq_id,
			  $prism);


&addContigFastaRecord($database,
		      $contig,
		      $prism);

&buildCDSFastaRecords($database,
		      $contig,
		      $prism);


&writeGFF3File($outdir,
	       $contig,
	       $database);


print "$0 execution completed\n";
exit(0);

#------------------------------------------------------------------------------------------
#
#                        END OF MAIN  -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------


#------------------------------------------------
# addContigFastaRecord()
#
#------------------------------------------------
sub addContigFastaRecord {
    
    my ($database, $contig, $prism) = @_;
    
    my $contigToResiduesLookup = $prism->contigUniquenameToResiduesLookup($contig);

    push ( @{$gffLines}, "##FASTA" );

    push ( @{$gffLines}, ">$contig" );

    my $formattedFastaSequence = &formatFastaSequence($contigToResiduesLookup->{$contig});

    push ( @{$gffLines}, "$formattedFastaSequence" );
}


#------------------------------------------------
# buildCDSFastaRecords()
#
#------------------------------------------------
sub buildCDSFastaRecords {

    my ($database, $contig, $prism) = @_;

    my $cdsSequenceHashRef = $prism->cdsSequences($contig);

    &buildGFF3FastaRecord($cdsSequenceHashRef);
}



#------------------------------------------------
# buildGeneModelGFFRecords()
#
#------------------------------------------------
sub buildGeneModelGFFRecords {

    my ($database, $contig, $seq_id, $prism) = @_;

    ## Typical TIGR GFF3 transcript/mRNA record:
    ## gbm3.contig.507	TIGR	mRNA	1454161	1454412	.	-	.	ID=gbm3.507.mRNA.A01425;Parent=gbm3.507.gene.A01425;Name=A02_B1440;Dbxref=TIGR_CMR:A02_B1440;locus=A02_B1440;description=conserved hypothetical protein;Ontology_term=GO:0000004,GO:0005554
    ## feature.uniquename = gbm3.contig.506      seq_id
    ## $source            = TIGR                 source
    ## 'contig'           = contig               type
    ## '1'                = 1                    start
    ## feature.seqlen     = 2284095              end
    ## '.'                = .                    score
    ## featureloc.strand  = +                    strand
    ## '.'                = .                    phase
    ## feature.uniquename = gbm3.contig.506      ID                
    ## organism.{genus+species} = Burkholderia mallei
    ##

    ## Get gene
    my $geneHashRef = $prism->featurelocDataByType($contig,
						 'gene');

    ## This program assumes that the following feature_relationships exist:
    ## transcript derives_from gene
    ## CDS derives_from transcript
    ## exon part_of transcript


    ## Get mRNA-to-gene, mRNA-to-CDS, mRNA-to-exon lookups
    my $geneToMrnaLookup = $prism->objectToSubjectLookup($contig,
							 'gene',
							 'transcript');

    my $mrnaToCdsLookup = $prism->objectToSubjectLookup($contig,
							'transcript',
							'CDS');

    my $mrnaToExonLookup = $prism->objectToSubjectLookup($contig,
							 'transcript',
							 'exon');

    ## Get mRNAs/mRNA 
    my $mrnaHashRef = $prism->featurelocDataByType($contig,
						 'transcript');


    ## Get CDS
    my $cdsHashRef = $prism->featurelocDataByType($contig,
						'CDS');

    ## Get exon
    my $exonHashRef = $prism->featurelocDataByType($contig,
						 'exon');

    ## Get mRNA gene_name values
    my $transcriptGeneNameLookup = $prism->featureAttributeLookup($contig,
								  'gene_name',
								  'transcript');

    ## Get mRNA gene_product_name values
    my $transcriptGeneProductNameLookup = $prism->featureAttributeLookup($contig,
									 'gene_product_name',
									 'transcript');
    
    ## Get mRNA Cross-reference data
    my $transcriptCrossReferenceLookup = $prism->featureCrossReferenceLookup($contig,
									     'transcript');
    
    ## Get mRNA locus data
    my $transcriptLocusLookup = $prism->featureLocusLookup($contig,
							   'transcript');
    

    foreach my $geneId ( keys %{$geneHashRef} ) {

	my $type = 'gene';
	my $start = $geneHashRef->{$geneId}->{'fmin'};
	my $end = $geneHashRef->{$geneId}->{'fmax'};
	my $score = '.';
	my $strand = $geneHashRef->{$geneId}->{'strand'};

	$strand = ($strand eq '1') ? '+' : ($strand eq '-1') ? '-' : '.';

	my $phase = '.';

	my $geneUniquename = $geneHashRef->{$geneId}->{'uniquename'};
	my $attributesSectionString = "ID=$geneUniquename";
	
	&buildGFF3AnnotationRecord($seq_id, 
				   $type,
				   $start,
				   $end,
				   $score, 
				   $strand, 
				   $phase, 
				   $attributesSectionString );

	foreach my $mRNAId ( @{$geneToMrnaLookup->{$geneId}} ) {

	    my $type = 'mRNA';
	    my $start = $mrnaHashRef->{$mRNAId}->{'fmin'};
	    my $end = $mrnaHashRef->{$mRNAId}->{'fmax'};
	    my $score = '.';
	    my $strand = $mrnaHashRef->{$mRNAId}->{'strand'};
	    $strand = ($strand eq '1') ? '+' : ($strand eq '-1') ? '-' : '.';

	    my $phase = '.';

	    my $mRnaUniquename = $mrnaHashRef->{$mRNAId}->{'uniquename'};
	    my $attributesSectionString = "ID=$mRnaUniquename;Parent=$geneUniquename";
	    
	    if ( exists $transcriptGeneNameLookup->{$mRNAId}){
		$attributesSectionString .= ";Name=" . $transcriptGeneNameLookup->{$mRNAId};
	    }

	    if ( exists $transcriptGeneProductNameLookup->{$mRNAId}){
		$attributesSectionString .= ";description=" . 
		$transcriptGeneProductNameLookup->{$mRNAId};
	    }

	    if ( exists $transcriptCrossReferenceLookup->{$mRNAId} ){
		$attributesSectionString .= ";Dbxref=" . 
		$transcriptCrossReferenceLookup->{$mRNAId}->{'name'};

		$attributesSectionString .= ":" . 
		$transcriptCrossReferenceLookup->{$mRNAId}->{'accession'};
	    }

	    if ( exists $transcriptLocusLookup->{$mRNAId}){
		$attributesSectionString .= ";locus=" . 
		$transcriptLocusLookup->{$mRNAId};
	    }

	    &buildGFF3AnnotationRecord($seq_id, 
				       $type,
				       $start,
				       $end,
				       $score, 
				       $strand, 
				       $phase, 
				       $attributesSectionString );


	    foreach my $cdsId ( @{$mrnaToCdsLookup->{$mRNAId}} ) {

		my $type = 'CDS'; 
		my $start = $cdsHashRef->{$cdsId}->{'fmin'};
		my $end = $cdsHashRef->{$cdsId}->{'fmax'};
		my $score = '.'; 
		my $strand = $cdsHashRef->{$cdsId}->{'strand'};
		$strand = ($strand eq '1') ? '+' : ($strand eq '-1') ? '-' : '.';

		my $phase = '.'; 

		my $cdsUniquename = $cdsHashRef->{$cdsId}->{'uniquename'};
		my $attributesSectionString = "ID=$cdsUniquename;Parent=$mRnaUniquename";

		&buildGFF3AnnotationRecord($seq_id, 
					   $type,
					   $start,
					   $end, 
					   $score,
					   $strand,
					   $phase,
					   $attributesSectionString );
	    }

	    foreach my $exonId ( @{$mrnaToExonLookup->{$mRNAId}} ) {

		my $type = 'exon';
		my $start = $exonHashRef->{$exonId}->{'fmin'};
		my $end = $exonHashRef->{$exonId}->{'fmax'};
		my $score = '.';
		my $strand = $exonHashRef->{$exonId}->{'strand'};
		$strand = ($strand eq '1') ? '+' : ($strand eq '-1') ? '-' : '.';

		my $phase = '0';

		my $exonUniquename = $exonHashRef->{$exonId}->{'uniquename'};
		my $attributesSectionString = "ID=$exonUniquename;Parent=$mRnaUniquename";
		
		&buildGFF3AnnotationRecord($seq_id, 
					   $type,
					   $start,
					   $end,
					   $score, 
					   $strand, 
					   $phase, 
					   $attributesSectionString );
	    }
	}		    
    }
}


#------------------------------------------------
# buildContigGFFRecords()
#
#------------------------------------------------
sub buildContigGFFRecords {

    my ($database, $contig, $prism) = @_;

    ## Typical TIGR GFF3 contig record:
    ## gbm3.contig.506	TIGR	contig	1	2284095	.	+	.	ID=gbm3.contig.506;Name=Burkholderia mallei;molecule_type=dsDNA;Dbxref=taxon:320386;organism_name=Burkholderia mallei;strain=10229;translation_table=11;topology=linear;localization=chromosomal

    ## feature.uniquename = gbm3.contig.506      seq_id
    ## $source            = TIGR                 source
    ## 'contig'           = contig               type
    ## '1'                = 1                    start
    ## feature.seqlen     = 2284095              end
    ## '.'                = .                    score
    ## featureloc.strand  = +                    strand
    ## '.'                = .                    phase
    ## feature.uniquename = gbm3.contig.506      ID                
    ## organism.{genus+species} = Burkholderia mallei
    ##

    my $contigToSeqlenLookup = $prism->contigToSeqlenLookup();

    my $contigToMoleculeTypeLookup = $prism->contigToAttributeLookup('molecule_type');

    my $contigToTopologyLookup = $prism->contigToAttributeLookup('topology');

    my $contigToLocalizationLookup = $prism->contigToAttributeLookup('localization');

    my $seq_id = $contig;
    my $type = 'contig';
    my $start = 1;
    my $end = $contigToSeqlenLookup->{$contig};
    my $score = '.';
    my $strand = '+';
    my $phase;
    
    my $contigToOrganismLookup = $prism->contigToOrganismLookup();

    my $organismNameToStrainLookup = $prism->organismNameToAttributeLookup('strain');

    my $organismNameToTranslationTableLookup = $prism->organismNameToAttributeLookup('translation_table');

    my $attributesSection = {};

    $attributesSection->{'ID'} = $contig;
    
    my $genus;
    my $species;
    my $organismName;

    if ( exists $contigToOrganismLookup->{$contig}){
 
	$genus = $contigToOrganismLookup->{$contig}->{'genus'};
	$species = $contigToOrganismLookup->{$contig}->{'species'};

	$organismName = $genus . ' ' . $species;

	push( @{$attributesSection->{'Name'}}, $organismName);
    }
    else {
	$logger->logdie("organism data not available for contig '$contig'");
    }





    if ( exists $contigToMoleculeTypeLookup->{$contig} ){
	$molecule_type = $contigToMoleculeTypeLookup->{$contig};
    }

    if (defined($molecule_type)){
	push( @{$attributesSection->{'molecule_type'}}, $molecule_type);
    }
    else {
	$logger->logdie("molecule_type was not defined");
    }

    push( @{$attributesSection->{'organism_name'}}, $organismName);

    if (exists $organismNameToStrainLookup->{$organismName} ) {
	push( @{$attributesSection->{'strain'}}, $organismNameToStrainLookup->{$organismName});
    }


    if ( exists $organismNameToTranslationTableLookup->{$organismName} ){
	$translation_table = $organismNameToTranslationTableLookup->{$organismName};
    }

    if (defined($translation_table)){
	push( @{$attributesSection->{'translation_table'}}, $translation_table );
    }
    else {
	$logger->logdie("translation_table was not defined");
    }

    if ( exists $contigToTopologyLookup->{$contig} ){
	$topology = $contigToTopologyLookup->{$contig};
    }

    if (defined($topology)){
	push( @{$attributesSection->{'topology'}}, $topology );
    }
    else {
	$logger->logdie("topology was not defined");
    }
    
    if ( exists $contigToLocalizationLookup->{$contig} ){
	$localization = $contigToLocalizationLookup->{$contig};
    }

    if (defined($localization)){
	push( @{$attributesSection->{'localization'}}, $localization );
    }
    else {
	$logger->logdie("localization was not defined");
    }

    my $attributesSectionString = &buildGFF3AnnotationAttributesSection($attributesSection);

    &buildGFF3AnnotationRecord($seq_id, 
			       $type,
			       $start,
			       $end,
			       $score, 
			       $strand, 
			       $phase, 
			       $attributesSectionString );

    return $seq_id;
}


#------------------------------------------------
# buildGFF3HeaderSection()
#
#------------------------------------------------
sub buildGFF3HeaderSection {

    my ($headerInfoArrayRef) = @_;

    push ( @{$gffLines}, "##gff-version 3");
    push ( @{$gffLines}, "##feature-ontology so.obo");
    push ( @{$gffLines}, "##attribute-ontology gff3_attributes.obo");

    foreach my $additionalHeaderLine ( @{$headerInfoArrayRef} ){

	push ( @{$gffLines}, "##$additionalHeaderLine");    
    }

}


#------------------------------------------------
# buildGFF3AnnotationRecord()
#
#------------------------------------------------
sub buildGFF3AnnotationRecord {

    my ($seq_id, $type, $start, $end, $score,
	$strand, $phase, $attributes) = @_;

    if (!defined($seq_id)){
	$logger->logdie("seq_id was not defined");
    }
    if (!defined($type)){
	$logger->logdie("type was not defined");
    }
    if (!defined($start)){
	$logger->logdie("start was not defined");
    }
    if (!defined($end)){
	$logger->logdie("end was not defined");
    }
    if (!defined($score)){
	$score ='.';
    }

    if (!defined($strand)){
	$logger->logdie("strand was not defined");
    }
    ## Validate the strand
    else {
	if ( ! exists $validStrandTypes->{$strand} ) {
	    $logger->logdie("Invalid strand '$strand'");
	}
    }


    if (!defined($phase)){
	if ($type ne 'exon'){
	    $phase = '.';
	}
	else {
	    $phase = 0;
	}
    }
    else {
	## Validate the phase
	if ( ! exists $validPhaseTypes->{$phase} ) {
	    $logger->logdie("Invalid phase '$phase' for type '$type'");
	}
    }

    my $gffLine = "$seq_id\t$source\t$type\t$start\t$end\t$score\t$strand\t$phase\t$attributes";

    push ( @{$gffLines}, $gffLine );
}

#------------------------------------------------
# buildGFF3AnnotationAttributesSection()
#
#------------------------------------------------
sub buildGFF3AnnotationAttributesSection {

    my ($attributesHashRef) = @_;

    my $id = $attributesHashRef->{'ID'};

    my $attributesSection = "ID=$id";

    delete $attributesHashRef->{'ID'};

    foreach my $attributeType ( keys %{$attributesHashRef} ) {

	$attributesSection .= ";$attributeType=";
	
	foreach my $attrValue ( @{$attributesHashRef->{$attributeType}} ) {

	    $attributesSection .= "$attrValue";
	}

    }

    return $attributesSection;
}


#------------------------------------------------
# buildGFF3FastaRecord()
#
#------------------------------------------------
sub buildGFF3FastaRecord {

    my ($fastaHashRef) = @_;

    foreach my $fastaHeader ( keys %{$fastaHashRef} ) {

	push ( @{$gffLines}, ">$fastaHeader" );

	my $fastaSequence = &formatFastaSequence($fastaHashRef->{$fastaHeader});

	push ( @{$gffLines}, "$fastaSequence" );
	
    }
}

#------------------------------------------------
# formatFastaSequence()
#
#------------------------------------------------
sub formatFastaSequence {

    my($seq) = @_;

    my $formatseq;

    for(my $i=0; $i < length($seq); $i+=60){

	my $seq_fragment = substr($seq, $i, 60);

	$formatseq .= $seq_fragment."\n";
    }

    return $formatseq;
}


#------------------------------------------------------------------
# verifyAndSetOutdir()
#
#------------------------------------------------------------------
sub verifyAndSetOutdir {

    my ( $outdir) = @_;

    ## strip trailing forward slashes
    $outdir =~ s/\/+$//;
    
    ## set to current directory if not defined
    if (!defined($outdir)){
	if (!defined($ENV{'OUTPUT_DIR'})){
	    $outdir = "." 
	}
	else{
	    $outdir = $ENV{'OUTPUT_DIR'};
	}
    }

    $outdir .= '/';

    ## verify whether outdir is in fact a directory
    if (!-d $outdir){
	$logger->logdie("$outdir is not a directory");
    }

    ## verify whether outdir has write permissions
    if ((-e $outdir) and (!-w $outdir)){
	$logger->logdie("$outdir does not have write permissions");
    }

    ## store the outdir in the environment variable
    $ENV{OUTPUT_DIR} = $outdir;
    
    return $outdir;

}#end sub verifyAndSetOutdir()


#----------------------------------------------------------------
# createPrismObject()
#
#----------------------------------------------------------------
sub createPrismObject {

    my ( $username, $password, $database) = @_;

    my $prism = new Prism(
			  user              => $username,
			  password          => $password,
			  db                => $database,
			  );

    if (!defined($prism)){
	$logger->logdie("Could not create instance of Prism");
    }

    return $prism;

}#end sub createPrismObject()


#------------------------------------------------------
# printUsage()
#
#------------------------------------------------------
sub printUsage {

    print STDERR "SAMPLE USAGE:  $0 -D database --database_type --server --password --username --contig [-d debug_level] [-h|--help] [--localization] [--log4perl] [-m|--man] [--molecule_type] [--outdir] [--outfile] [-R readonlycache] [--source] [--topology] [--translation_table] [-y cache_dir]\n".
    "  --database            = Target chado database\n".
    "  --database_type       = Relation database management system type e.g. sybase or postgresql\n".
    "  --server              = Name of server on which the database resides\n".
    "  --password            = Password\n".
    "  --username            = Username\n".
    "  -d|--debug_level         = Optional - Coati::Logger log4perl logging level.  Default is 0\n".
    "  -h|--help                = Optional - Display pod2usage help screen\n".
    "  --log4perl               = Optional - Log4perl log file (default: /tmp/chadotogff3.pl.log)\n".
    "  -m|--man                 = Optional - Display pod2usage pages for this utility\n".
    "  --outdir                 = Optional - output directory for tab delimited BCP files (Default is current working directory)\n".
    "  --outfile                = Optional - output directory for tab delimited BCP files (Default is current working directory)\n".
    "  -R|--readonlycache       = Optional - If data file caching is activated and if this readonlycache is == 1, then the tied MLDBM lookup cache files can only be accessed in read-only mode. (Default is OFF -r=0)\n".
    "  -y|--cache_dir           = Optional - To turn on file-caching and specify directory to write cache files.  (Default no file-caching. If specified directory does not exist, default is environmental variable ENV{DBCACHE_DIR}\n".
    "  --source                 = Optional - GFF source (default is chado database)\n".
    "  --contig                 = contig uniquename e.g. gbm3.contig.506\n".
    "  --topology               = Optional - \n".
    "  --translation_table      = Optional - \n".
    "  --localization           = Optional - \n".
    "  --molecule_type          = Optional - \n";
    exit 1;

}



#-----------------------------------------------------------------------------------
# setLogger()
#
#-----------------------------------------------------------------------------------
sub setLogger {

    my ($log4perl, $debug_level, $contig) = @_;

    if (!defined($log4perl)){
	$log4perl = "/tmp/chadotogff3.pl.$contig.log";
    }

    my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				     'LOG_LEVEL'=>$debug_level);
    

    my $logger = Coati::Logger::get_logger(__PACKAGE__);
    
    return $logger;
}

#-----------------------------------------------------------------------------------
# writeGFF3File()
#
#-----------------------------------------------------------------------------------
sub writeGFF3File {

    my ($outdir, $contig, $database, $gffFileName) = @_;

    if (!defined($gffFilename)){
	$gffFilename = $outdir . '/' . $database . '_' . $contig . '.gff3';
    }

    open (OUTFILE, ">$gffFilename") || $logger->logdie("Could not open ".
						       "file '$gffFilename' for output ".
						       ":$!");
    
    foreach my $gffLine ( @{$gffLines} ){
	print OUTFILE $gffLine . "\n";
    }
} 

#--------------------------------------------------
# setPrismEnv()
#
#--------------------------------------------------
sub setPrismEnv {

    my ($server, $vendor) = @_;

    if (!defined($server)){
	$logger->logdie("server was not defined");
    }
    if (!defined($vendor)){
	$logger->logdie("vendor was not defined");
    }
    
    if ($vendor eq 'postgresql'){
	$vendor = 'postgres';
    }

    $vendor = "Bulk" . ucfirst($vendor);
    ## We're overriding the env stored in conf/Prism.conf
    my $prismenv = "Chado:$vendor:$server";


    $ENV{PRISM} = $prismenv;
}
