package Annotation::BSML::Epitope::Parser;

=head1 NAME

Annotation::BSML::Epitope::Parser.pm

=head1 VERSION

1.0

=head1 SYNOPSIS

use Annotation::BSML::Epitope::Parser;


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS


=over 4

=cut

use strict;
use Carp;
use BSML::BsmlParserSerialSearch;
use BSML::BsmlParserTwig;

use constant TRUE => 1;
use constant FALSE => 0;

use constant MHC_ALLELE_IDX       => 0;
use constant PMID_IDX             => 1;
use constant MHC_QUANT_IDX        => 2;
use constant MHC_QUAL_IDX         => 3;
use constant MHC_ALLELE_CLASS_IDX => 4;
use constant ASSAY_GROUP_IDX      => 5;
use constant ASSAY_TYPE_IDX       => 6;

## Keep track of the value of the current epiPEP Feature identifier value being processed
my $id;

## Maintain a reference to a Perl hash for caching the epiPEP Feature Attribute values
my $lookup={};

=item new()

B<Description:> Private constructor for this class

B<Parameters:> None

B<Returns:> reference to the Annotation::BSML::Epitope::Parser object

=cut

sub new  {

    my $class = shift;

    my $self = {};

    bless $self, $class;

    return $self->_init(@_);

}

=item $self->_init(%args)

B<Description:> Typical Perl init() method

B<Parameters:> %args

B<Returns:> None

=cut

sub _init {

    my $self = shift;
    my (%args) = @_;

    foreach my $key (keys %args){
	$self->{"_$key"} = $args{$key};
    }

    return $self;
    
}


=item DESTROY

B<Description:> Annotation::BSML::Builder::AssemblyWriter class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

    my $self = shift;

}


=item $self->parse(%args)

B<Description:> Parse the BSML file

B<Parameters:> $args{file} (scalar - string) optional

B<Returns:> None

=cut

sub parse {

    my $self = shift;
    my $file = $self->_getFile(@_);


    my $parser = new BSML::BsmlParserSerialSearch( FeatureCallBack => sub {   
	
	my $ref = shift;
	
	if (!&isEpiPEPFeature($ref)){
	    return undef;
	}
	
	$id = &getBsmlFeatureId($ref);

	if (!defined($id)){
	    confess "id was not defined while processing ".
	    "BSML Feature:" . Dumper $ref;
	}

	&parseAttributes($ref);

	$self->{_parsed_epi_ctr}++;

    });


    if (!defined($parser)){
	confess ("Could not instantiate BSML::BsmlParserSerialSearch");
    }

    $parser->parse($file);

    $self->{_file_parsed} = 1;

    $self->{_lookup} = $lookup;
}

sub _getFile {

    my $self = shift;
    my (%args) = @_;
    
    if (( exists $args{file}) && (defined($args{file}))){
	$self->{_file} = $args{file};
    } elsif (( exists $self->{_file}) && (defined($self->{_file}))){
	## okay
    } else {
	confess "file was not defined";
    }

    return $self->{_file};
}


sub getAttributeLookup {

    my $self = shift;

    if (( exists $self->{_lookup}) && (defined($self->{_lookup}))){
	return $self->{_lookup};
    } else {
	$self->parse(@_);
	return $self->{_lookup};
    }
}



sub isEpiPEPFeature {

    my ($bsmlFeature) = @_;

    if ((exists $bsmlFeature->{attr}) && (defined($bsmlFeature->{attr}))){
	if (( exists $bsmlFeature->{attr}->{class}) && 
	    ( defined($bsmlFeature->{attr}->{class})) && 
	    ( $bsmlFeature->{attr}->{class} eq 'epiPEP')){
	    return TRUE;
	}
    }
    
    return FALSE;
}

sub getBsmlFeatureId {

    my ($bsmlFeature) = @_;

    if ((exists $bsmlFeature->{attr}) && 
	(defined($bsmlFeature->{attr}))){

	if (( exists $bsmlFeature->{attr}->{id}) && 
	    (defined($bsmlFeature->{attr}->{id}))){

	    return $bsmlFeature->{attr}->{id};
	}
    }
    
    confess ("id was not defined for BSML Feature:". Dumper $bsmlFeature);
}

sub parseAttributes {

    my ($bsmlFeature) = @_;

    if (( exists $bsmlFeature->{BsmlAttr}) && (defined($bsmlFeature->{BsmlAttr}))){

	if (( exists $bsmlFeature->{BsmlAttr}->{'MHC Allele'}) && 
	    ( defined($bsmlFeature->{BsmlAttr}->{'MHC Allele'}))){
	    
	    $lookup->{$id}->[MHC_ALLELE_IDX] = $bsmlFeature->{BsmlAttr}->{'MHC Allele'}->[0];
	    
	} else {
	    confess ("MHC Allele was not define for epiPEP with id '$id'");
	}

	if (( exists $bsmlFeature->{BsmlAttr}->{'PMID'}) && 
	    ( defined($bsmlFeature->{BsmlAttr}->{'PMID'}))){

	    $lookup->{$id}->[PMID_IDX] = $bsmlFeature->{BsmlAttr}->{'PMID'}->[0];

	} else {
	    confess ("PMID was not defined for epiPEP with id '$id'");
	}


	if (( exists $bsmlFeature->{BsmlAttr}->{'MHC Quantitative Binding Assay Result'}) && 
	    (defined($bsmlFeature->{BsmlAttr}->{'MHC Quantitative Binding Assay Result'}))){
	    
	    $lookup->{$id}->[MHC_QUANT_IDX] = $bsmlFeature->{BsmlAttr}->{'MHC Quantitative Binding Assay Result'}->[0];
	    
	} else {
	    warn ("MHC Quantitative Binding Assay Result ".
		  "was not defined for epiPEP with id '$id'");
	}


	if (( exists $bsmlFeature->{BsmlAttr}->{'MHC Qualitative Binding Assay Result'}) && 
	    (defined($bsmlFeature->{BsmlAttr}->{'MHC Qualitative Binding Assay Result'}))){
	    
	    $lookup->{$id}->[MHC_QUAL_IDX] = $bsmlFeature->{BsmlAttr}->{'MHC Qualitative Binding Assay Result'}->[0];

	} else {
	    confess ("MHC Qualitative Binding Assay Result ".
		     "was not defined for epiPEP with id '$id':".
		     Dumper $bsmlFeature);
	}
	

	if (( exists $bsmlFeature->{BsmlAttr}->{'MHC Allele Class'}) && 
	    (defined($bsmlFeature->{BsmlAttr}->{'MHC Allele Class'}))){
	    
	    $lookup->{$id}->[MHC_ALLELE_CLASS_IDX] = $bsmlFeature->{BsmlAttr}->{'MHC Allele Class'}->[0];

	} else {
	    confess ("MHC Allele Class was not defined for ".
		     "epiPEP with id '$id'");
	}

	if (( exists $bsmlFeature->{BsmlAttr}->{'Assay Group'}) && 
	    (defined($bsmlFeature->{BsmlAttr}->{'Assay Group'}))){

	    $lookup->{$id}->[ASSAY_GROUP_IDX] = $bsmlFeature->{BsmlAttr}->{'Assay Group'}->[0];

	} else {
	    confess ("Assay Group was not defined for ".
		     "epiPEP with id '$id'");
	}

	if (( exists $bsmlFeature->{BsmlAttr}->{'Assay Type'}) && (defined($bsmlFeature->{BsmlAttr}->{'Assay Type'}))){

	    $lookup->{$id}->[ASSAY_TYPE_IDX] = $bsmlFeature->{BsmlAttr}->{'Assay Type'}->[0];
	    
	} else {
	    confess ("Assay Type was not defined for ".
		     "epiPEP with id '$id'");
	}
    } else {
	confess("BsmlAttr was not defined for epiPEP with id '$id'");
    }
}


1==1; ## End of module
