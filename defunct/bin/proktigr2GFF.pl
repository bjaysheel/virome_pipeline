#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

proktigr2GFF.pl - Migrates legacy prok data into GFF schema

=head1 SYNOPSIS

USAGE:  proktigr2GFF.pl -U username -P password -D database -T type 

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--database,-D>
    
    Database name

=item B<--type,-T>
    
    Organism type - This can only be the following:
        1. prok
        2. euk
        3. prok_exon

=back

=head1 DESCRIPTION

    proktigr2GFF.pl - Migrates data from prokaryotic database into GFF schema

=cut

use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use DBI;
use URI::Escape;

my %options;

my $results = GetOptions(\%options,
			 'username|U=s',
			 'password|P=s',
			 'database|D=s',
			 'type|T=s',
			 'help|h');
#
# If an invalid type string is entered, script will err out
my $invalid_type = 0;
if($options{'type'} !~ /euk|prok|prok\_exon/) {
    $invalid_type = 1;
}
&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($options{'help'} || $invalid_type || (!$results));

my $connect_string = "DBI:Sybase:server=SYBTIGR;database=$options{'database'};packetSize=8192";
my $dbh = DBI->connect($connect_string, $options{'username'}, $options{'password'});

my $sequences;

my ($refgfflines,$refseqs,$gff3_file_name) = &get_contigs($dbh);
open FILE, ">$gff3_file_name";
print FILE "##gff-version 3\n";
print FILE "##feature-ontology so.obo\n";
print FILE "##attribute-ontology gff3_attributes.obo\n";


foreach my $row (@$refgfflines){
    print FILE join("\t",@$row),"\n";
}

foreach my $ref (@$refseqs){
    my $asmbl_id = $ref->[2];
    my $gfflines;
    my $gene_seqs;
    ($gfflines,$gene_seqs) = &get_genes($dbh,$asmbl_id);
    foreach my $row (@$gfflines){
	print FILE join("\t",@$row),"\n";
    }
    push(@$sequences,@$gene_seqs);
}

foreach my $ref (@$refseqs){
    my $asmbl_id = $ref->[2];
    my $gfflines;
    my $rna_seqs;
    ($gfflines,$rna_seqs) = &get_rnas($dbh,$asmbl_id);
    foreach my $row (@$gfflines){
	print FILE join("\t",@$row),"\n";
    }
    push(@$sequences,@$rna_seqs);
}

print FILE "##FASTA\n";
foreach my $seq (@$sequences,@$refseqs){
    if($seq->[1] ne ""){
	print FILE ">$seq->[0]\n";
	print FILE &format_fasta($seq->[1]);
    }
}

sub get_contigs{
    my($dbh) = @_;
    
    my @contigs;
    my @gfflines;
    my $gff_org = "";
    my $gff_genus = "";
    my $gff_species = "";
    my $gff_strain = "";
    
    my $query = "SET TEXTSIZE 10000000 ";
    &do_sql($dbh,$query);

    my $query = "select a.asmbl_id,a.sequence,datalength(sequence) ".
	        "from assembly a, stan s ".
		"where a.asmbl_id = s.asmbl_id ".
		"and s.iscurrent=1";
    
    my $results = &do_sql($dbh,$query);
    foreach my $row (@$results) {
	my $number = $row->[0];
	my $id = $options{'database'}."."."contig".".".$number;
	push @contigs,[$id,$row->[1],$number];
	
	my $orgquery = "select t.taxon_id,t.genus,t.species,t.strain,d.genetic_code ".
	               "from omnium..db_data d, omnium..taxon t, omnium..taxon_link l ".
		       "where d.original_db = '$options{'database'}' ".
		       "and d.id = l.db_taxonl_id ".
		       "and l.taxon_uid = t.uid ";

	my $oresults = &do_sql($dbh,$orgquery);
	my $oresultsrow = $oresults->[0];

	my $taxon = $oresultsrow->[0];
	my $name = $oresultsrow->[1] . " " . $oresultsrow->[2];
	my $genus = $oresultsrow->[1];
	my $species = $oresultsrow->[2];
	my $organism_name = $oresultsrow->[1] . " " . $oresultsrow->[2];
	my $strain = $oresultsrow->[3];
	my $genetic_code = $oresultsrow->[4];

	if(scalar(@$oresults)==0) {
	    my $orgquery = "select t.taxon_id,t.genus,t.species,t.strain,d.genetic_code ".
		           "from omnium..db_data1 d, omnium..taxon t, omnium..taxon_link1 l ".
			   "where d.original_db = '$options{'database'}' ".
			   "and d.id = l.db_taxonl_id ".
			   "and l.taxon_uid = t.uid ";

	    $oresults = &do_sql($dbh,$orgquery);
	    $oresultsrow = $oresults->[0];

	    $taxon = $oresultsrow->[0];
	    $name = $oresultsrow->[1] . " " . $oresultsrow->[2];
	    $genus = $oresultsrow->[1];
	    $species = $oresultsrow->[2];
	    $organism_name = $oresultsrow->[1] . " " . $oresultsrow->[2];
	    $strain = $oresultsrow->[3];
	    $genetic_code = $oresultsrow->[4];
	}

	### get the GenBank accession for the assembly sequence (if it exists)
	my $data_query = "select d.acc_num ".
	                 "from asmbl_data d, stan s ".
			 "where d.id = s.asmbl_data_id ".
			 "and s.iscurrent = 1 ".
			 "and s.asmbl_id = $number ";

	my $data_results = &do_sql($dbh, $data_query);
	my $asmbl_gb_acc = $data_results->[0][0];

	### set up dbxrefs; taxon id will always be present but the 
	### GenBank accession may not be; append to the end of the gff3 line
	my $dbxref = ";Dbxref=taxon:$taxon,";
	if($asmbl_gb_acc) {
	    $dbxref .= "GenBank:$asmbl_gb_acc";
	}
	$dbxref =~ s/\,$//;

	$gff_genus = $genus;
	$gff_species = $species;
	$gff_strain = $strain;
	
	push @gfflines, [$id,'Pathema','contig',1,$row->[2],'.','+','.',"ID=$id;Name=$name;molecule_type=dsDNA;organism_name=$organism_name;strain=$strain;translation_table=$genetic_code;topology=linear;localization=chromosomal".$dbxref];
    }

    
    ($gff_genus) = ($gff_genus =~ /(^\w{1})(.*)/);
    $gff_strain =~ s/\s+/\_/g;
    $gff_strain =~ s/\.//g;
    $gff_org = lc($gff_genus) ."_". lc($gff_species) ."_". lc($gff_strain);
    my $gff3_file_name = $gff_org .".gff3";

    return (\@gfflines,\@contigs, $gff3_file_name);	
}

sub get_genes{
    my($dbh,$asmbl_id) = @_;
    
    my @gfflines;
    my @sequences;
    my $query = "";
    my $unsafe = ",=;\t";

    if($options{'database'} =~ /^nt/) {
	##Name = i.locus, ##locus_tag = nt.nt_locus
	$query = "SELECT f.feat_name, f.end5, f.end3, i.com_name, i.locus, i.ec#, i.gene_sym, f.sequence, f.protein, nt.nt_locus ".
	         "FROM ident i, asm_feature f ".
		 "LEFT JOIN (SELECT * FROM feat_link fl, nt_ident n WHERE fl.child_feat = n.feat_name) AS nt ON (f.feat_name = nt.parent_feat) ".
		 "WHERE f.feat_type = 'ORF' ".
		 "AND f.feat_name = i.feat_name ".
		 "AND f.asmbl_id = $asmbl_id ".
		 "ORDER BY f.feat_name ";
    }
    else {
	##Name = i.locus, ##locus_tag = i.locus
	$query = "SELECT f.feat_name, f.end5, f.end3, i.com_name, i.locus, i.ec#, i.gene_sym, f.sequence, f.protein ".
	         "FROM asm_feature f, ident i ".
		 "WHERE f.feat_name = i.feat_name ".
		 "AND f.asmbl_id = $asmbl_id ".
		 "AND f.feat_type = 'ORF' ".
		 "ORDER BY 2 ";
    }

    my $results = &do_sql($dbh,$query);

    
    foreach my $row (@$results) {
	my $number = "";
	
	if($row->[0] =~ /ORF(\d+)/) {      ### ORF00001
	    ($number) = ($row->[0] =~ /ORF(\d+)/);
	}
	elsif($row->[0] =~ /ORF\w(\d+)/) { ### ORFE00001
	    ($number) = ($row->[0] =~ /ORF(\w\d+)/);
	}
	elsif($row->[0] =~ /\_(\d+)/g) {   ### GBAA_pXO2_0001 
	    ($number) = $1;
	}
	elsif($row->[0] =~ /\D+(\d+)/g) {  ### GBAA0001
	    ($number) = $1;
	}

	my $geneid = $options{'database'}.".".$asmbl_id."."."gene".".".$number;
	my $transcriptid = $options{'database'}.".".$asmbl_id."."."mRNA".".".$number;
	my $cdsid = $options{'database'}.".".$asmbl_id.".". "cds".".".$number;
	my $exonid = $options{'database'}.".".$asmbl_id."."."exon".".".$number;
	my $proteinid = $options{'database'}.".".$asmbl_id."."."protein".".".$number;
	my $seqid = $options{'database'}."."."contig".".".$asmbl_id;

	my ($start,$stop) = ($row->[1] < $row->[2]) ? ($row->[1],$row->[2]) : ($row->[2],$row->[1]);
	my $strand = ($row->[1]<$row->[2]) ? '+' : '-';

	### Determine the parent id for the CDS based on the organism type being used
	my $cds_parent_id = $geneid;
	my $exon_parent_id = $transcriptid;
	if($options{'type'} eq "euk") {
	    $cds_parent_id = $transcriptid;
	}
	elsif($options{'type'} eq "prok_exon") {
	    $exon_parent_id = $transcriptid;
	}
	
	my @geneattrs = ("ID=$geneid");
	my @tranattrs = ("ID=$transcriptid","Parent=$geneid");
	my $genbank_id = &get_accession($dbh,$row->[0]);
	my @cdsattrs;
	
	## escape unsafe characters in the attribute value fields:
	my $escaped_cdsid = uri_escape($cdsid, $unsafe);
	my $escaped_name = uri_escape($row->[4], $unsafe);
	my $escaped_parent_id = uri_escape($cds_parent_id, $unsafe);

	@cdsattrs = ("ID=$escaped_cdsid","Name=$escaped_name","Parent=$escaped_parent_id");
	

	### SOPs (this is temporary until we have something in the database)
	### this will point to a static page on Pathema.
	#my $sop = "SOP_gene1";
	my $sop = "";

	
	### concatenate all of the dbxrefs
	my $dbxref = "";

	if($genbank_id ne "" || $row->[4] || $sop ne "") {
	    $dbxref = "Dbxref=";
	}

	if($genbank_id ne "") {
	    my $escaped_genbankid = uri_escape($genbank_id, $unsafe);
	    $dbxref .= "GenBank:$escaped_genbankid,";
	}
	
	if($row->[4]) {
	    $dbxref .= "TIGR_CMR:$escaped_name,";
	}

	if($sop ne "") {
	    my $escaped_sop = uri_escape($sop, $unsafe);
	    $dbxref .= "Pathema:$escaped_sop,";
	}
	
	### remove fields from the database that have an empty space
	$row->[5] =~ s/\+s//;
	if($row->[5] ne "" && $row->[5] =~ /.+\..+\..+\..+/) {
	    my $escaped_ec = uri_escape($row->[5], $unsafe);
	    $dbxref .= "EC:$escaped_ec,";
	}
	$dbxref =~ s/\,$//;


	if($dbxref ne "") {
	    push @cdsattrs,"$dbxref";
	}


	my @exonattrs = ("ID=$exonid","Parent=$exon_parent_id");

	### remove fields from the database that have an empty space	
	$row->[6] =~ s/\s+//;
	if($row->[6] ne ""){
	    my $escaped_genesymbol = uri_escape($row->[6], $unsafe);
	    push @cdsattrs,"gene_symbol=$escaped_genesymbol";
	}
	if($row->[9] ne ""){
	    my $escaped_locustag = uri_escape($row->[9], $unsafe);
	    push @cdsattrs,"locus_tag=$escaped_locustag";
	}
	else {
	    push @cdsattrs,"locus_tag=$escaped_name";
	}
	if($row->[3] ne ""){
	    $row->[3] =~ s/\;/ /g;
	    my $escaped_des = uri_escape($row->[3], $unsafe);
	    push @cdsattrs,"description=$escaped_des";
	}
	
	my $godata = &get_go($dbh,$row->[0]);
	### commenting out, we will take the coordinates of the gene for the CDS
	#my ($fsstart,$fsend) = &get_programmed_fs($dbh,$seqid,$row->[0]);

	my @goids;
	foreach my $go (@$godata) {
	    if ($go->[1] =~ /^GO\:[0-9]{7}$/) {
		push @goids,$go->[1];
	    }
	}
	if(scalar(@goids)>0) {
	    push @cdsattrs, "Ontology_term=".join(',',@goids);
	}

	push @gfflines,[$seqid,'Pathema','gene',$start,$stop,'.',$strand,'.',join(';',@geneattrs)];
	if($options{'type'} eq "euk") {
	    push @gfflines,[$seqid,'Pathema','mRNA',,$start,$stop,'.',$strand,'.',join(';',@tranattrs)];
	}
	
	### if euk organism, get exons
	my @exonlines = &get_exons($dbh,$seqid,$transcriptid,$start,$stop) if($options{'type'} eq "euk");
	
	if(scalar(@exonlines)) {
	    push @gfflines,@exonlines;
	    push @gfflines,[$seqid,'Pathema','CDS',$exonlines[0]->[3],$exonlines[0]->[4],'.',$strand,'.',join(';',@cdsattrs)];
	    push @gfflines,[$seqid,'Pathema','CDS',$exonlines[1]->[3],$exonlines[1]->[4],'.',$strand,'.',join(';',@cdsattrs)];
	    
	    if($options{'type'} eq "euk" || $options{'type'} eq "prok_exon") {	    
		push @gfflines,[$seqid,'Pathema','exon',$exonlines[0]->[3],$exonlines[0]->[4],'.',$strand,'0',join(';',@exonattrs)];
		push @gfflines,[$seqid,'Pathema','exon',$exonlines[1]->[3],$exonlines[1]->[4],'.',$strand,'0',join(';',@exonattrs)];
	    }
	}
#	elsif($fsstart) {
#	    if($strand eq '+'){
#		push @gfflines,[$seqid,'Pathema','CDS',$start,$start+$fsstart,'.',$strand,'.',join(';',@cdsattrs)];
#		push @gfflines,[$seqid,'Pathema','CDS',$start+$fsend,$stop,'.',$strand,'.',join(';',@cdsattrs)];
#		if($options{'type'} eq "euk" || $options{'type'} eq "prok_exon") {	    
#		    push @gfflines,[$seqid,'Pathema','exon',$start,$start+$fsstart,'.',$strand,'0',join(';',@exonattrs)];
#		    push @gfflines,[$seqid,'Pathema','exon',$start+$fsend,$stop,'.',$strand,'0',join(';',@exonattrs)];
#		}
#	    }
#	    elsif($strand eq '-'){
#		push @gfflines,[$seqid,'Pathema','CDS',$start,$stop-$fsend,'.',$strand,'.',join(';',@cdsattrs)];
#		push @gfflines,[$seqid,'Pathema','CDS',$stop-$fsstart+1,$stop,'.',$strand,'.',join(';',@cdsattrs)];
#		if($options{'type'} eq "euk" || $options{'type'} eq "prok_exon") {	    
#		    push @gfflines,[$seqid,'Pathema','exon',$start,$stop-$fsend,'.',$strand,'0',join(';',@exonattrs)];
#		    push @gfflines,[$seqid,'Pathema','exon',$stop-$fsstart+1,$stop,'.',$strand,'0',join(';',@exonattrs)];
#		}
#	    }
#	}
	else{
	    push @gfflines,[$seqid,'Pathema','CDS',$start,$stop,'.',$strand,'.',join(';',@cdsattrs)];
	    if($options{'type'} eq "euk" || $options{'type'} eq "prok_exon") {	    
		push @gfflines,[$seqid,'Pathema','exon',$start,$stop,'.',$strand,'0',join(';',@exonattrs)];
	    }
	}
	push @sequences,[$cdsid,$row->[8]];

    }
    return (\@gfflines,\@sequences);
}

sub get_rnas{
    my($dbh,$asmbl_id) = @_;
    my $rna_count = 1;
    my @gfflines;
    my @sequences;
    my $unsafe = ",=;\t";

    my $query = "select f.feat_name,f.end5,f.end3,i.com_name,i.locus,i.ec#,i.gene_sym,f.sequence,f.protein, f.feat_type ".
	        "from asm_feature f, ident i ".
		"where f.feat_name = i.feat_name ".
		"and f.asmbl_id = $asmbl_id ".
		"and lower(f.feat_type) like \"%rna\" order by 2";

    my $results = &do_sql($dbh,$query);


    foreach my $row (@$results) {

	if($row->[9] =~ /tRNA/) {

	    my $trna_id = $options{'database'}.".".$asmbl_id."."."rna".".".$rna_count;
	    my $seqid = $options{'database'}."."."contig".".".$asmbl_id;
	    my ($start,$stop) = ($row->[1] < $row->[2]) ? ($row->[1],$row->[2]) : ($row->[2],$row->[1]);
	    my $strand = ($row->[1]<$row->[2]) ? '+' : '-';
	    my $escaped_trnaid = uri_escape($trna_id, $unsafe);
	    my $escaped_name = uri_escape($row->[0], $unsafe);
	    my @trnaattrs = ("ID=$escaped_trnaid","Name=$escaped_name");
	    if($row->[3] ne ""){
		$row->[3] =~ s/\;/ /g;
		my $escaped_des = uri_escape($row->[3], $unsafe);
		push @trnaattrs,"description=$escaped_des";
	    }
	    push @gfflines,[$seqid,'Pathema','tRNA',$start,$stop,'.',$strand,'.',join(';',@trnaattrs)];
	    push @sequences,[$trna_id,$row->[8]];
	    $rna_count++;
	}
	elsif($row->[9] =~ /rRNA/) {
	    my $rrna_id = $options{'database'}.".".$asmbl_id."."."rna".".".$rna_count;
	    my $seqid = $options{'database'}."."."contig".".".$asmbl_id;
	    my ($start,$stop) = ($row->[1] < $row->[2]) ? ($row->[1],$row->[2]) : ($row->[2],$row->[1]);
	    my $strand = ($row->[1]<$row->[2]) ? '+' : '-';
	    my $escaped_rrnaid = uri_escape($rrna_id, $unsafe);
	    my $escaped_name = uri_escape($row->[0], $unsafe);
	    my @rrnaattrs = ("ID=$escaped_rrnaid","Name=$escaped_name");
	    if($row->[3] ne ""){
		$row->[3] =~ s/\;/ /g;
		my $escaped_des = uri_escape($row->[3], $unsafe);
		push @rrnaattrs,"description=$escaped_des";
	    }
	    push @gfflines,[$seqid,'Pathema','rRNA',$start,$stop,'.',$strand,'.',join(';',@rrnaattrs)];
	    push @sequences,[$rrna_id,$row->[8]];
	    $rna_count++;
	}	
    }
    return (\@gfflines,\@sequences);
}

sub get_go{
    my ($dbh,$feat_name) = @_;
    
    my $query = "select distinct f.feat_name,g.go_id ".
	        "from asm_feature f, go_role_link g ".
		"where f.feat_name = g.feat_name ".
		"and g.feat_name = '$feat_name' and g.go_id is NOT NULL and g.go_id != 'NULL'";

    my $results = &do_sql($dbh,$query);
    return $results;
}

sub get_accession{
    my ($dbh,$feat_name) = @_;

    my $query = "select a.accession_id ".
	        "from accession a ".
		"where a.feat_name = '$feat_name' ".
		"and a.accession_db = 'protein_id' ";
    
    my $results = &do_sql($dbh,$query);
    return $results->[0]->[0];

}



sub get_programmed_fs{
    my($dbh,$seqid,$feat_name,$strand) = @_;

    my ($asmbl_id) = ($seqid =~ /(\d+)$/);

    my $query = "select fs.score,f.sequence ".
	        "from asm_feature f, ORF_attribute o, feat_score fs, common..score_type st ".
		"where o.att_type = 'PROGRAMMED_FS' ".
		"and f.feat_name = o.feat_name ".
		"and o.id = fs.input_id ".
		"and fs.score_id = st.id ".
		"and st.input_type = o.att_type ".
		"and o.feat_name = '$feat_name' ".
		"and f.asmbl_id = $asmbl_id";
    
    my $results = &do_sql($dbh,$query);

    my $soterm;
    my $start;
    my $end;

    foreach my $row (@$results) {
	print STDERR "Programmed frameshift for orf $feat_name $query\n";
	my ($seq,$sign,$num) = ($row->[0] =~ /(\w+)\:([+-])(\d)/);
	my $sequence = lc($row->[1]);
	$sequence =~ s/\s//g;
	$seq =~ s/\s//g;

	my $pos;
	if($sequence =~ m/$seq/g){
	    print STDERR "Found sequence\n";
	    $pos = pos($sequence)-length($seq);
	    print STDERR substr($sequence,$pos,length($seq))."\n";
	    print STDERR "Set pos to $pos ",substr($sequence,$pos,1),"\n";
	}
	print STDERR "$pos $seq $sign $num $sequence\n";

	if($sign eq '-'){
	    if($num == 1){
		$soterm = "SO:1001262";
		$start= $pos-1;
		$end=$pos;
	    }
	    elsif($num ==2){
		$soterm = "SO:1000069";
		$start = $pos-2;
		$end=$pos;
	    }
	}
	elsif($sign eq '+'){
	    if($num == 1){
		$soterm = "SO:1000066";
		$start = $pos;
		$end=$pos+1;
	    }
	    elsif($num==2){
		$soterm = "SO:1000068";
		$start = $pos;
		$end = $pos+2;
	    }
	}
    }
    return ($start,$end);
}

sub get_exons{
    my($dbh,$seqid,$transcriptid,$cdsstart,$cdsstop) = @_;
    
    my ($asmbl_id) = ($seqid =~ /(\d+)$/);

    my $query = "select f.feat_name,f.end5,f.end3,f.feat_class ".
	        "from asm_feature f ".
		"where f.asmbl_id = $asmbl_id ".
		"and f.feat_type = 'INTRON' ".
		"and f.end5 between $cdsstart and $cdsstop";

    my $results = &do_sql($dbh,$query);

    my @gffline1;
    my @gffline2;

    foreach my $row (@$results){
	my ($number) = ($row->[0] =~ /INTRON(\d+)/);
	my $feat_class = $row->[3];
	my $coord1 = $row->[1];
	my $coord2 = $row->[2];
	

	my($intronstart,$intronstop,$strand) = ($coord1 < $coord2) ? ($coord1,$coord2,'+') : ($coord2,$coord1,'-');

	my $exonid1 = $options{'database'}."."."exon".".".($number*100+1);
	my $exonid2 = $options{'database'}."."."exon".".".($number*100+2);
	@gffline1 = ($seqid,'Pathema','exon',$cdsstart,$intronstart,'.',$strand,'.',"ID=$exonid1;Parent=$transcriptid");
	@gffline2 = ($seqid,'Pathema','exon',$intronstop,$cdsstop,'.',$strand,'.',"ID=$exonid2;Parent=$transcriptid");
	print STDERR "Returning exon lines for $exonid1 $exonid2\n";
	return (\@gffline1,\@gffline2);
    }
    
    return ();
}

sub do_sql {
    my ($dbhandle, $query, @args) = @_;
    
    #################
    # check for invalid query.
    #################
    my $sth = $dbhandle->prepare($query) or die("Invalid query statement%%SQL/Database%%There is an invalid query or it does ".
						"not match table/column names in the database.  Please check the SQL syntax and ".
						"database schema%%$DBI::errstr%%$query%%@args%%");

    #################
    # execute the query.
    #################    
    $sth->execute(@args) or die("Query execution error%%SQL/Database%%There is a query that could not be executed.  ".
				"Please check the query syntax, arguments, and database schema%%$DBI::errstr%%".
				"%%$query%%@args%%");
    
     my (@results, $array_ref);
    while ($array_ref = $sth->fetchrow_arrayref) {
        push @results, [ @$array_ref ];  # Copy the array contents (See Perl DBI pg. 114)
    }
    return \@results;
}

sub format_fasta{
    my($seq) = @_;
    my $formatseq;
    for(my $i=0; $i < length($seq); $i+=60){
	my $seq_fragment = substr($seq, $i, 60);
	$formatseq .= $seq_fragment."\n";
    }
    return $formatseq;
}

