#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

proktigr2chado.pl - Migrates legacy prok data into GFF schema

=head1 SYNOPSIS

USAGE:  proktigr2chado.pl -U username -P password -D database -T type 

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
    push(@$sequences, @$gene_seqs);
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

    my $query = "SET TEXTSIZE 10000000 ";
    &do_sql($dbh,$query);

    my $query = "SELECT a.asmbl_id, a.sequence, datalength(a.sequence) ".
	        "FROM assembly a, clone_info c ".
		"WHERE a.asmbl_id = c.asmbl_id ".
		"AND c.is_public = 1 ".
		"ORDER BY a.asmbl_id ";

    my $results = &do_sql($dbh,$query);
    foreach my $row (@$results) {
	my $number = $row->[0];
	my $id = $options{'database'}."."."contig".".".$number;
	push @contigs,[$id,$row->[1],$number];
	
	my $orgquery = "select t.taxon_id,t.genus+\" \"+t.species,t.strain,d.genetic_code ".
	    "from omnium..db_data d, omnium..taxon t, omnium..taxon_link l ".
	    "where d.original_db = '$options{'database'}' ".
	    "and d.id = l.db_taxonl_id ".
	    "and l.taxon_uid = t.uid ";

	my $oresults = &do_sql($dbh,$orgquery);

	my $oresultsrow = $oresults->[0];
	
	my $name = $oresultsrow->[1];
	my $organism_name = $oresultsrow->[1];
	my $taxon = $oresultsrow->[0];
	my $strain = $oresultsrow->[2];
	my $genetic_code = $oresultsrow->[3];

	if(scalar(@$oresults)==0) {
	my $orgquery = "select t.taxon_id,t.genus+\" \"+t.species,t.strain,d.genetic_code ".
	    "from omnium..db_data1 d, omnium..taxon t, omnium..taxon_link1 l ".
	    "where d.original_db = '$options{'database'}' ".
	    "and d.id = l.db_taxonl_id ".
	    "and l.taxon_uid = t.uid ";

	    $oresults = &do_sql($dbh,$orgquery);
	    $oresultsrow = $oresults->[0];

	    $name = $oresultsrow->[1];
	    $organism_name = $oresultsrow->[1];
	    $taxon = $oresultsrow->[0];
	    $strain = $oresultsrow->[2];
	    $genetic_code = $oresultsrow->[3];
	}
	
	my $name = "Entamoeba histolytica";
	my $organism_name = "Entamoeba histolytica";
	my $taxon = "5759";
	my $strain = "";
	my $genetic_code = "1";

	push @gfflines, [$id,'Pathema','contig',1,$row->[2],'.','+','.',"ID=$id;Name=$name;molecule_type=dsDNA;Dbxref=taxon:$taxon;organism_name=$organism_name;translation_table=$genetic_code;topology=linear;localization=chromosomal"];
    }
    
    my $gff3_file_name = "e_histolytica.gff3";
    return (\@gfflines,\@contigs, $gff3_file_name);	
}

sub get_genes{
    my($dbh,$asmbl_id) = @_;
    my @gfflines;
    my @sequences2;
    my $unsafe = ",=;\t";

    my $query = "SELECT a.feat_name, a.end5, a.end3, x.ident_val, i.pub_locus, x2.ident_val, x3.ident_val, a.sequence, a.protein ".
	        "FROM asm_feature a, clone_info c, phys_ev p, feat_link l, ident i, ident_xref x, ident_xref x2, ident_xref x3 ".
		"WHERE a.feat_type = 'model' ".
		"AND a.feat_name = p.feat_name ".
		"AND p.ev_type = 'working' ".
		"AND a.asmbl_id = c.asmbl_id ".
		"AND c.is_public = 1 ".
		"AND a.feat_name = l.child_feat ".
		"AND l.parent_feat = i.feat_name ".
		"AND i.feat_name *= x.feat_name ".
		"AND i.feat_name *= x2.feat_name ".
		"AND i.feat_name *= x3.feat_name ".
		"AND x.xref_type = 'product name' ".
		"AND x.relrank = 1 ".
		"AND x2.xref_type = 'ec number' ".
		"AND x2.relrank = 1 ".
		"AND x3.xref_type = 'gene symbol' ".
		"AND x3.relrank = 1 ".
		"AND a.asmbl_id = $asmbl_id ";

    my $results = &do_sql($dbh,$query);


    foreach my $row (@$results) {
	my $number = "";
	
	if($row->[0] =~ /\d+\.m(\d+)/) {
	    ($number) = ($row->[0] =~ /\d+\.m(\d+)/);	    
	}

	my $seqid = $options{'database'}."."."contig".".".$asmbl_id;
	my $geneid = $options{'database'}."."."gene".".".$asmbl_id.".".$number;
	my $transcriptid = $options{'database'}."."."mRNA".".".$asmbl_id.".".$number;
	my $cdsid = $options{'database'}."."."cds".".".$asmbl_id.".".$number;

	my ($start,$stop) = ($row->[1] < $row->[2]) ? ($row->[1],$row->[2]) : ($row->[2],$row->[1]);
	my $strand = ($row->[1]<$row->[2]) ? '+' : '-';

	### Determine the parent id
	my $cds_parent_id = $transcriptid;
	my $exon_parent_id = $transcriptid;

	###
	my @geneattrs = ("ID=$geneid");
	my $pub_locus = $row->[4] || "$row->[0]";
	my @tranattrs = ("ID=$transcriptid","Parent=$geneid","Name=$pub_locus");
	my @cdsattrs  = ("ID=$cdsid","Parent=$cds_parent_id");
	my $genbank_id = &get_accession($dbh,$row->[0]);

	if($row->[6] ne ""){
	    push @tranattrs,"gene_symbol=$row->[6]";
	}

	### concatenate all of the dbxrefs
	my $dbxref = "";
        ### remove fields from the database that have an empty space
	$row->[5] =~ s/\+s//;

	if($genbank_id ne "" || $row->[5]) {
	    $dbxref = "Dbxref=";	    
	}
	if($genbank_id ne "") {
	    my $escaped_genbankid = uri_escape($genbank_id, $unsafe);
	    $dbxref .= "GenBank:$escaped_genbankid,";
	}
	
	if($row->[5] ne "" && $row->[5] =~ /.+\..+\..+\..+/) {
	    my $escaped_ec = uri_escape($row->[5], $unsafe);
	    $dbxref .= "EC:$escaped_ec,";
	}
	$dbxref =~ s/\,$//;
	if($dbxref ne "") {
	    push @cdsattrs,"$dbxref";
	}

	if($row->[3] ne ""){
	    $row->[3] =~ s/\;/ /g;
	    my $escaped_des = uri_escape($row->[3], $unsafe);
	    push @tranattrs,"description=$escaped_des";
	}

	my $godata = &get_go($dbh,$row->[0]);
	my ($frameshift,$fsstart,$fsend) = &get_programmed_fs($dbh,$seqid,$row->[0]);

	push @tranattrs,@$frameshift;

	my @goids;
	foreach my $go (@$godata){
	    push @goids,$go->[1];
	}
	if(scalar(@goids)>0){
	    push @tranattrs, "Ontology_term=".join(',',@goids);
	}

	### Create gene feature
	push @gfflines,[$seqid,'Pathema','gene',$start,$stop,'.',$strand,'.',join(';',@geneattrs)];
	
	### Create mRNA feature
	push @gfflines,[$seqid,'Pathema','mRNA',$start,$stop,'.',$strand,'.',join(';',@tranattrs)];

	### Create CDS feature
	push @gfflines,[$seqid,'Pathema','CDS',$start,$stop,'.',$strand,'.',join(';',@cdsattrs)];

	### Create exon features
	my (@exonlines) = &get_exons($dbh,$seqid,$transcriptid,$start,$stop,$row->[0],$asmbl_id);
	
	push @gfflines,@exonlines;
	push @sequences2,[$cdsid,$row->[8]];
    }
    return (\@gfflines,\@sequences2);
}

sub get_rnas{
    my($dbh,$asmbl_id) = @_;
    my $rna_count = 1;
    my @gfflines;
    my @sequences;


    my $query = "select f.feat_name,f.end5,f.end3,i.com_name,i.locus,i.ec#,i.gene_sym,f.sequence,f.protein, f.feat_type ".
	        "from asm_feature f, ident i ".
		"where f.feat_name = i.feat_name ".
		"and f.asmbl_id = $asmbl_id ".
		"and lower(f.feat_type) like \"%rna\" order by 2";

    my $results = &do_sql($dbh,$query);


    foreach my $row (@$results) {

	if($row->[9] =~ /tRNA/) {
	    #my $trna_id = $options{'database'}."."."trna".".".$row->[0];
	    my $trna_id = $options{'database'}.".".$asmbl_id.".rna".".".$rna_count;
	    my $seqid = $options{'database'}."."."contig".".".$asmbl_id;
	    my ($start,$stop) = ($row->[1] < $row->[2]) ? ($row->[1],$row->[2]) : ($row->[2],$row->[1]);
	    my $strand = ($row->[1]<$row->[2]) ? '+' : '-';
	    my @trnaattrs = ("ID=$trna_id","Name=$row->[0]");
	    if($row->[3] ne ""){
		$row->[3] =~ s/\;/ /g;
		push @trnaattrs,"description=$row->[3]";
	    }
	    push @gfflines,[$seqid,'Pathema','tRNA',$start,$stop,'.',$strand,'.',join(';',@trnaattrs)];
	    push @sequences,[$trna_id,$row->[8]];
	    $rna_count++;
	}
	elsif($row->[9] =~ /rRNA/) {
	    my $rrna_id = $options{'database'}.".".$asmbl_id.".rna".".".$rna_count;
	    my $seqid = $options{'database'}."."."contig".".".$asmbl_id;
	    my ($start,$stop) = ($row->[1] < $row->[2]) ? ($row->[1],$row->[2]) : ($row->[2],$row->[1]);
	    my $strand = ($row->[1]<$row->[2]) ? '+' : '-';
	    my @rrnaattrs = ("ID=$rrna_id","Name=$row->[0]");
	    if($row->[3] ne ""){
		$row->[3] =~ s/\;/ /g;
		push @rrnaattrs,"description=$row->[3]";
	    }
	    push @gfflines,[$seqid,'Pathema','rRNA',$start,$stop,'.',$strand,'.',join(';',@rrnaattrs)];
	    push @sequences,[$rrna_id,$row->[8]];
	    $rna_count++;
	}	
	elsif($row->[9] =~ /sRNA/) {
	    my $srna_id = $options{'database'}.".".$asmbl_id.".rna".".".$rna_count;
	    my $seqid = $options{'database'}."."."contig".".".$asmbl_id;
	    my ($start,$stop) = ($row->[1] < $row->[2]) ? ($row->[1],$row->[2]) : ($row->[2],$row->[1]);
	    my $strand = ($row->[1]<$row->[2]) ? '+' : '-';
	    my @srnaattrs = ("ID=$srna_id","Name=$row->[0]");
	    if($row->[3] ne ""){
		$row->[3] =~ s/\;/ /g;
		push @srnaattrs,"description=$row->[3]";
	    }
	    push @gfflines,[$seqid,'Pathema','sRNA',$start,$stop,'.',$strand,'.',join(';',@srnaattrs)];
	    push @sequences,[$srna_id,$row->[8]];
	    $rna_count++;
	}	
    }
    return (\@gfflines);
}

sub get_go{
    my ($dbh,$feat_name) = @_;
    
    my $query = "SELECT DISTINCT a.feat_name, g.go_id ".
	        "FROM asm_feature a, asm_feature a2, feat_link l, go_role_link g ".
		"WHERE a2.feat_name = '$feat_name' ".
		"AND a2.feat_name = l.child_feat ".
		"AND l.parent_feat = a.feat_name ".
	        "AND a.feat_name = g.feat_name ".
		"AND g.go_id IS NOT NULL ".
		"AND g.go_id != 'NULL' ";

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

    my @atts;
    my $start = 0;
    my $end = 0;

    
    return (\@atts,$start,$end);
    
    my $query = "select fs.score,f.sequence from asm_feature f, ORF_attribute o, feat_score fs, common..score_type st ".
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

    foreach my $row (@$results){
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
	push @atts, "Dbxref=$soterm";
    }
    return (\@atts,$start,$end);
}

sub get_exons{
    my($dbh,$seqid,$transcriptid,$cdsstart,$cdsstop,$model,$asmbl_id) = @_;
    
    my $query = "SELECT a2.feat_name, a2.end5, a2.end3, a3.feat_name, a3.end5, a3.end3 ".
	        "FROM asm_feature a, asm_feature a2, clone_info c, phys_ev p, feat_link l, asm_feature a3, feat_link l2 ".
		"WHERE a.feat_type = 'model' ".
		"AND a.asmbl_id = $asmbl_id ".
		"AND a.feat_name = p.feat_name ".
		"AND p.ev_type = 'working' ".
		"AND a.asmbl_id = c.asmbl_id ".
		"AND c.is_public = 1 ".
		"AND a.feat_name = l.parent_feat ".
		"AND l.child_feat = a2.feat_name ".
		"AND a2.feat_type = 'exon' ".
		"AND a2.feat_name = l2.parent_feat ".
		"AND l2.child_feat = a3.feat_name ".
		"AND a3.feat_type = 'CDS' ".
		"AND l.parent_feat = '$model' ";
     
    my $results = &do_sql($dbh,$query);


    my @gff3;
    my @gff4;

    foreach my $row (@$results) {
	my @gffline1;
	my @gffline2;

	my ($number)  = ($row->[0] =~ /\d+\.e(\d+)/);
	my ($number2) = ($row->[3] =~ /\d+\.m(\d+)/);
	my $coord1 = $row->[1];
	my $coord2 = $row->[2];
	my $exonid = $options{'database'}."."."exon".".".$asmbl_id.".".$number;
	my($intronstart,$intronstop,$strand) = ($coord1 < $coord2) ? ($coord1,$coord2,'+') : ($coord2,$coord1,'-');

	@gffline1 = ($seqid,'Pathema','exon',$intronstart,$intronstop,'.',$strand,'.',"ID=$exonid;Parent=$transcriptid");
	push @gff3, \@gffline1;
    }
    return @gff3;
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

