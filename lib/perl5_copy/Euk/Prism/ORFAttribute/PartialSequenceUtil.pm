package Euk::Prism::ORFAttribute::PartialSequenceUtil;

use strict;
use Carp;
use Data::Dumper;
use Prism;
use Prism::Util;
use Annotation::Logger;
use base "Prism::DBUtil";
#use base "Prism::PartialSequenceUtil";

use constant TRUE => 1;
use constant FALSE => 0;

use constant FEAT_NAME => 0;
use constant SCORE => 1;
use constant SCORE2 => 2;

=item new()

B<Description:> Instantiate Euk::Prism::ORFAttribute::PartialSequenceUtil object

B<Parameters:> None

B<Returns:> reference to the Euk::Prism::ORFAttribute::PartialSequenceUtil object

=cut

sub new  {

  my $class = shift;

  my $self = {};

  bless $self, $class;

  $self->_init(@_);

  $self->_loadLookups();

  return $self;
}


=item $self->_loadLookups()

B<Description:> Load any special lookups

B<Parameters:> None

B<Returns:> None

=cut

sub _loadLookups {

    my $self = shift;
    
    my $asmbl_id = $self->_getAsmblId(@_);

    my $records = $self->{_prism}->{_backend}->getPartialSequenceInfo($asmbl_id);

    if (!defined($records)){
	confess "records was not defined";
    }

    my $ctr=0;

    my $lookup5 = {};
    my $lookup3 = {};
    my $lookupBoth = {};

    foreach my $record (@{$records}){

	$ctr++;
	
	my $feat_name = $record->[FEAT_NAME];

	my $five = $record->[SCORE];

	my $three = $record->[SCORE2];

	my $fiveYes;
	my $threeYes;

	if ($self->_isPartial($five)){
	    $lookup5->{$feat_name}++;
	    $fiveYes=1;
	}

	if ($self->_isPartial($three)){
	    $lookup3->{$feat_name}++;
	    $threeYes=1;
	}

	if ($self->_bothPartial($fiveYes, $threeYes)){
	    $lookupBoth->{$feat_name}++;
	}
    }

    print "Processed '$ctr' ORF_attribute records and ".
    "classified the partials accordingly\n";


    $self->{_five_prime_partial_lookup} = $lookup5;

    $self->{_three_prime_partial_lookup} = $lookup3;

    $self->{_five_and_three_prime_partial_lookup} = $lookupBoth;
}	

sub _bothPartial {

    my $self = shift;
    my ($five, $three) = @_;

    if ((defined($five)) && (defined($three))){
	return TRUE;
    }

    return FALSE;
}


sub _isPartial {

    my $self = shift;
    my ($val) = @_;

    if (!defined($val)){
	return FALSE;
    }

    if (lc($val) eq 'null'){
	return FALSE;
    }

    if ($val eq '0'){
	return FALSE;
    }

    if ($val == 0){
	return FALSE;
    }

    return TRUE;
}




sub isFivePrimePartial {

    my $self = shift;
    my ($id) = @_;

    if (!defined($id)){
	confess "id was not defined";
    }


    if (( exists $self->{_five_prime_partial_lookup}->{$id}) &&
	( defined($self->{_five_prime_partial_lookup}->{$id}))){

	return TRUE;
    }

    return FALSE;
}

sub isThreePrimePartial {

    my $self = shift;
    my ($id) = @_;

    if (!defined($id)){
	confess "id was not defined";
    }


    if (( exists $self->{_three_prime_partial_lookup}->{$id}) &&
	( defined($self->{_three_prime_partial_lookup}->{$id}))){

	return TRUE;
    }

    return FALSE;
}

sub isFiveAndThreePrimePartial {

    my $self = shift;
    my ($id) = @_;

    if (!defined($id)){
	confess "id was not defined";
    }


    if (( exists $self->{_five_and_three_prime_partial_lookup}->{$id}) &&
	( defined($self->{_five_and_three_prime_partial_lookup}->{$id}))){
	
	return TRUE;
    }
    
    return FALSE;
}

sub _getAsmblId {

    my $self = shift;
    my (%args) = @_;
    
    if (( exists $args{asmbl_id}) && (defined($args{asmbl_id}))){

	return $args{asmbl_id};

    } elsif (( exists $self->{_asmbl_id}) && (defined($self->{_asmbl_id}))){

	return $self->{_asmbl_id};

    } else {

	return undef;
    }
}


1==1; ## end of module
