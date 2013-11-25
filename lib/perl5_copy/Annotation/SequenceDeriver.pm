package Annotation::SequenceDeriver;

=head1 NAME

Annotation::SequenceDeriver.pm

=head1 VERSION

1.0

=head1 SYNOPSIS


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS


=over 4

=cut

use strict;
use Carp;
use Data::Dumper;
use File::Basename;
use File::Path;
use Annotation::SequenceUtil;
use JCVI::Translator::Utils;
use Euk::Prism::ORFAttribute::PartialSequenceUtil;

=item new()

B<Description:> Instantiate Annotation::SequenceDeriver object

B<Parameters:> None

B<Returns:> reference to the Annotation::SequenceDeriver object

=cut

sub new  {

    my $class = shift;

    my $self = {};

    bless $self, $class;

    $self->_init(@_);

    return $self;
}

=item $self->_init(%args)

B<Description:> Typical Perl init() method

B<Parameters:> %args

B<Returns:> None

=cut

sub _init {

    my $self = shift;
    my (%args) = @_;

    foreach my $key (keys %args ) {
	$self->{"_$key"} = $args{$key};
    }

    if (! ( exists $self->{_model_collection}) && (defined($self->{_model_collection}))){
	confess "model collection was not defined";
    }

    if (! ( exists $self->{_cds_collection}) && (defined($self->{_cds_collection}))){
	confess "CDS collection was not defined";
    }

    if (! ( exists $self->{_asmbl_id}) && (defined($self->{_asmbl_id}))){
	confess "asmbl_id was not defined";
    }

    if (! ( exists $self->{_fastadir}) && (defined($self->{_fastadir}))){
	confess "fastadir was not defined";
    }

    if (! ( exists $self->{_sequence}) && (defined($self->{_sequence}))){
	confess "sequence was not defined";
    }

}
=item DESTROY

B<Description:> Annotation::SequenceDeriver class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  {
  my $self = shift;

}

=item $obj->writeFile()

B<Description:> Write the multi-FASTA file(s)

B<Parameters:> None

B<Returns:> None

=cut

sub writeFile {

    my $self = shift;

    if (! (( exists $self->{_sequences_derived}) && 
	   ( defined($self->{_sequences_derived})) && 
	   ( $self->{_sequences_derived} == 1))){

	$self->_deriveSequences(@_);
    }
    

    $self->_writeProteinFastaFile(@_);
#    $self->_writeCDSFastaFile(@_);
}


sub _deriveSequences {

    my $self = shift;

    my $seqUtil = new Annotation::SequenceUtil();
    if (!defined($seqUtil)){
	confess "Could not instantiate Annotation::SequenceUtil object";
    }

    my $refSeqRef = $self->_getReferenceSequence(@_);
    
    my $modelList = $self->_getModelList(@_);

    my $cdsCollection = $self->_getCDSCollection(@_);
    
    my $ctr=0;

    my $util = new Euk::Prism::ORFAttribute::PartialSequenceUtil(prism=>$self->{_prism},
								 database=>$self->{_database});    
    if (!defined($util)){
 	die "Could not instantiate Euk::Prism::".
 	"ORFAttribute::PartialSequenceUtil";
    }


    foreach my $record ( @{$modelList}){

	my $feat_name = $record->[1];
    
	my $cdsList = $cdsCollection->getFeatureListByParent(parent=>$feat_name);
    
	if (!defined($cdsList)){
	    print "model record:". Dumper $record;
	    print "cdsCollection:" . Dumper $cdsCollection;
	    confess "featureList was not defined while processing ".
	    "parent with feat_name '$feat_name'\n";
	}

	my $partial = $util->isPartial($feat_name);
	if ($partial){
	    print "feat_name '$feat_name' is partial\n";
	    print Dumper $record;
	} else {
	    print "feat_name '$feat_name' is not partial\n";
	}


#	my $seqref = $seqUtil->translate_exons($refSeqRef, $cdsList)
	my $seqref = $seqUtil->translate_exons($refSeqRef, $cdsList, undef, $partial);

	push(@{$self->{_protein_fasta_records}}, [$feat_name, $$seqref]);

	$ctr++;
    }


    my $asmbl_id = $self->_getAsmblId(@_);

    print "Derived '$ctr' protein sequences for asmbl_id '$asmbl_id'\n";
    
    ## indicate that the sequences have been derived
    $self->{_sequences_derived} = 1;
}


sub _writeProteinFastaFile {

    my $self = shift;
    my $file = $self->_getProteinFastaFile(@_);

    my $builder = new Annotation::Fasta::FastaBuilder(filename=>$file);
    if (!defined($builder)){
	confess "Could not instantiate Annotation::Fasta::FastaBuilder";
    }

    my $ctr=0;

    foreach my $rec (@{$self->{_protein_fasta_records}}){
	$builder->createAndAddFastaRecord($rec->[0], $rec->[1]);
	$ctr++;
    }

    $builder->write();

    print "Wrote '$ctr' FASTA records to the protein multi-FASTA file '$file'\n";
}

sub _writeCDSFastaFile {

    my $self = shift;
    my $file = $self->_getCDSFastaFile(@_);

    my $builder = new Annotation::Fasta::FastaBuilder(filename=>$file);
    if (!defined($builder)){
	confess "Could not instantiate Annotation::Fasta::FastaBuilder";
    }

    my $ctr=0;

    foreach my $rec (@{$self->{_cds_fasta_records}}){
	$builder->createAndAddFastaRecord($rec->[0], $rec->[1]);
	$ctr++;
    }

    $builder->write();

    print "Wrote '$ctr' FASTA records to the CDS multi-FASTA file '$file'\n";
}


sub _getCDSFastaFile {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{cds_file}) && (defined($args{cds_file}))){
	$self->{_cds_file} = $args{cds_file};
    } elsif (( exists $self->{_cds_file}) && (defined($self->{_cds_file}))){
	## okay
    } else {

	my $asmbl_id = $self->_getAsmblId(@_);
	my $fastadir = $self->_getFastaDir(@_);
	my $project = $self->_getProject(@_);

	my $file = $fastadir . '/' . $project . '_' . $asmbl_id . '_CDS.fsa';

	my $dirname = File::Basename::dirname($file);
	if (!defined($dirname)){
	    confess "Could not derive dirname from file '$file'";
	}

	if (!-e $dirname){
	    mkpath($dirname) || confess "Could not create directory '$dirname': $!";
	}

	$self->{_cds_file} = $file;
    }

    return $self->{_cds_file};
}

sub _getProteinFastaFile {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{protein_file}) && (defined($args{protein_file}))){
	$self->{_protein_file} = $args{protein_file};
    } elsif (( exists $self->{_protein_file}) && (defined($self->{_protein_file}))){
	## okay
    } else {

	my $asmbl_id = $self->_getAsmblId(@_);
	my $fastadir = $self->_getFastaDir(@_);
	my $project = $self->_getProject(@_);

	my $file = $fastadir . '/' . $project . '_' . $asmbl_id . '_polypeptide.fsa';

	my $dirname = File::Basename::dirname($file);
	if (!defined($dirname)){
	    confess "Could not derive dirname from file '$file'";
	}

	if (!-e $dirname){
	    mkpath($dirname) || confess "Could not create directory '$dirname': $!";
	}

	$self->{_protein_file} = $file;
    }

    return $self->{_protein_file};
}

sub _getAsmblId {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{asmbl_id}) && (defined($args{asmbl_id}))){
	$self->{_asmbl_id} = $args{asmbl_id};
    } elsif (( exists $self->{_asmbl_id}) && (defined($self->{_asmbl_id}))){
	## okay
    } else {
	confess "asmbl_id was not defined";
    }

    return $self->{_asmbl_id};
}

sub _getFastaDir {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{fastadir}) && (defined($args{fastadir}))){
	$self->{_fastadir} = $args{fastadir};
    } elsif (( exists $self->{_fastadir}) && (defined($self->{_fastadir}))){
	## okay
    } else {
	confess "fastadir was not defined";
    }

    return $self->{_fastadir};
}


sub _getReferenceSequence {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{sequence}) && (defined($args{sequence}))){

	$self->{_sequence} = $args{sequence};

    } elsif (( exists $self->{_sequence}) && (defined($self->{_sequence}))){
	## okay
    } else {
	confess "sequence was not defined";
    }

    return $self->{_sequence};
}


sub _getModelList {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{model_collection}) && (defined($args{model_collection}))){

	$self->{_model_collection} = $args{model_collection};

    } elsif (( exists $self->{_model_collection}) && (defined($self->{_model_collection}))){
	## okay
    } else {
	confess "model collection was not defined";
    }

    return $self->{_model_collection};
}

sub _getCDSCollection {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{cds_collection}) && (defined($args{cds_collection}))){

	$self->{_cds_collection} = $args{cds_collection};

    } elsif (( exists $self->{_cds_collection}) && (defined($self->{_cds_collection}))){
	## okay
    } else {
	confess "CDS collection was not defined";
    }

    return $self->{_cds_collection};
}



sub _getProject {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{project}) && (defined($args{project}))){

	$self->{_project} = $args{project};

    } elsif (( exists $self->{_project}) && (defined($self->{_project}))){
	## okay
    } else {
	confess "project was not defined";
    }

    return $self->{_project};
}





1==1; ## end of module
