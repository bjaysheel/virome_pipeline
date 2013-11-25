package Annotation::Features::Feature;

=head1 NAME

Annotation::Features::Feature.pm

=head1 VERSION

1.0

=head1 SYNOPSIS

Coming soon!

=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

new{}
_init{}
DESTROY{}
setId{}
getId{}
setSeq{}
getSeq{}
setFmin{}
getFmin{}
setFmax{}
getFmax{}
setStrand{}
getStrand{}
addAttributeByType{}
getAttributesByType{}
deleteAttributesByType{}
print{}

=over 4

=cut

use strict;
use Annotation::Logger;
use Annotation::Features::Feature;

my $logger = Annotation::Logger::get_logger("Logger::Annotation");


=item new()

B<Description:> Instantiate Annotation::Features::Feature object

B<Parameters:> None

B<Returns:> reference to the Annotation::Features::Feature object

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

  if (( exists $self->{'_fmin'}) && ( exists $self->{'_fmax'})){
      $self->_inferStrand();
  }

}


=item DESTROY

B<Description:> Annotation::Features::Feature class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  {
  my $self = shift;

}

=item $obj->setId($id)

B<Description:> Store the ID from this Feature

B<Parameters:> $id (scalar - string)

B<Returns:>  None

=cut

sub setId {

  my $self = shift;

  my ($id, @array) = @_;

  if (!defined($id)) {
    $logger->logdie("id was not defined");
  }
  if (scalar(@array) > 0){
      $logger->logdie("Received more parameters than was expecting! '@array'");
  }

  $self->{'_id'} = $id;

  if ($logger->is_debug()){
      $logger->debug("id was set to '$id'");
  }
}

=item $obj->getId()

B<Description:> Retrieve the id for this Feature

B<Parameters:> None

B<Returns:> $id (scalar - string)

=cut

sub getId {

  my $self = shift;

  if ( exists $self->{'_id'}){
      return $self->{'_id'};
  } else {
      $logger->warn("id was not defined for this Feature");
      return undef;
  }
}

=item $obj->setSeq($seq)

B<Description:> Store the sequence for this Feature

B<Parameters:> $seq (scalar - string)

B<Returns:>  None

=cut

sub setSeq {

  my $self = shift;

  my ($seq, @array) = @_;

  if (!defined($seq)) {
    $logger->logdie("seq was not defined");
  }
  if (scalar(@array) > 0){
      $logger->logdie("Received more parameters than was expecting! '@array'");
  }

  $self->{'_seq'} = $seq;
  if ($logger->is_debug()){
      $logger->debug("seq was set to '$seq'");
  }
}

=item $obj->getSeq()

B<Description:> Retrieve the seq for this Feature

B<Parameters:> None

B<Returns:> $seq (scalar - string)

=cut

sub getSeq {

  my $self = shift;

  if ( exists $self->{'_seq'}){
      return $self->{'_seq'};
  } else {
      $logger->warn("seq was not defined for this Feature");
      return undef;
  }
}

=item $obj->deleteSeq()

B<Description:> Delete the seq for this Feature

B<Parameters:> None

B<Returns:> None

=cut

sub deleteSeq {

  my $self = shift;

  if ( exists $self->{'_seq'}){
      delete $self->{'_seq'};
  } else {
      $logger->warn("Nothing to delete - seq was not ".
		    "defined for this Feature");
  }
}

=item $obj->setFmin($fmin)

B<Description:> Store the fmin sequence for this Feature

B<Parameters:> $fmin (scalar - unsigned integer)

B<Returns:>  None

=cut

sub setFmin {

  my $self = shift;

  my ($fmin, @array) = @_;

  if (!defined($fmin)) {
    $logger->logdie("fmin was not defined");
  }
  if (scalar(@array) > 0){
      $logger->logdie("Received more parameters than was expecting! '@array'");
  }

  if (($fmin > -1) && ($fmin == int($fmin))){
      $self->{'_fmin'} = $fmin;
      if ($logger->is_debug()){
	  $logger->debug("fmin was set to '$fmin'");
      }
  } else {
      $logger->logdie("Can only store unsigned integer value for fmin. ".
		      "fmin '$fmin' in unacceptable.");
  }
}

=item $obj->getFmin()

B<Description:> Retrieve the fmin for this Feature

B<Parameters:> None

B<Returns:> $fmin (scalar - unsigned integer)

=cut

sub getFmin {

  my $self = shift;

  if ( exists $self->{'_fmin'}){
      return $self->{'_fmin'};
  } else {
      $logger->warn("fmin was not defined for this Feature");
      return undef;
  }
}


=item $obj->setFmax($fmax)

B<Description:> Store the fmax sequence for this Feature

B<Parameters:> $fmax (scalar - unsigned integer)

B<Returns:>  None

=cut

sub setFmax {

  my $self = shift;

  my ($fmax, @array) = @_;

  if (!defined($fmax)) {
    $logger->logdie("fmax was not defined");
  }
  if (scalar(@array) > 0){
      $logger->logdie("Received more parameters than was expecting! '@array'");
  }

  if (($fmax > -1) && ($fmax == int($fmax))){
      $self->{'_fmax'} = $fmax;
      if ($logger->is_debug()){
	  $logger->debug("fmax was set to '$fmax'");
      }
  } else {
      $logger->logdie("Can only store unsigned integer value for fmax. ".
		      "fmax '$fmax' in unacceptable.");
  }
}

=item $obj->getFmax()

B<Description:> Retrieve the fmax for this Feature

B<Parameters:> None

B<Returns:> $fmax (scalar - unsigned integer)

=cut

sub getFmax {

  my $self = shift;

  if ( exists $self->{'_fmax'}){
      return $self->{'_fmax'};
  } else {
      $logger->warn("fmax was not defined for this Feature");
      return undef;
  }
}


=item $obj->getSeqLength()

B<Description:> Retrieve the length of the sequence

B<Parameters:> None

B<Returns:> $length (scalar - unsigned integer)

=cut

sub getSeqLength {

  my $self = shift;

  if ( exists $self->{'_seq_length'}){
      return $self->{'_seq_length'};
  } elsif (exists $self->{'_seq'}){
      $self->{'_seq_length'} = length($self->{'_seq'});
      return $self->{'_seq_length'};
  } elsif ((exists $self->{'_fmin'}) && (exists $self->{'_fmax'})) {
      $self->{'_seq_length'} = ( $self->{'_fmax'} - $self->{'_fmin'} );
      return $self->{'_seq_length'};
  } else {
      $logger->warn("Cannot derive sequence length!");
      return undef;
  }
}


=item $obj->setStrand($strand)

B<Description:> Store the strand for this Feature

B<Parameters:> $strand (scalar - integer)

B<Returns:>  None

=cut

sub setStrand {

  my $self = shift;

  my ($strand, @array) = @_;

  if (!defined($strand)) {
    $logger->logdie("strand was not defined");
  }
  if (scalar(@array) > 0){
      $logger->logdie("Received more parameters than was expecting! '@array'");
  }

  if (($strand >= -1) && ($strand <= 1)){
      $self->{'_strand'} = $strand;
      if ($logger->is_debug()){
	  $logger->debug("strand was set to '$strand'");
      }
  } else {
      $logger->logdie("The strand value '$strand' is unacceptable. ".
		      "Can only store -1, 0 or 1");
  }
}

=item $obj->getStrand()

B<Description:> Retrieve the strand for this Feature

B<Parameters:> None

B<Returns:> $strand (scalar - integer)

=cut

sub getStrand {

  my $self = shift;

  if (! exists $self->{'_strand'}){

      $self->_inferStrand();
  }

  return $self->{'_strand'};
  
}

sub _inferStrand {

    my $self = shift;

    if (! exists $self->{'_fmin'}){
	$logger->logdie("fmin was not defined");
    }

    if (! exists $self->{'_fmax'}){
	$logger->logdie("fmax was not defined");
    }


    if ($self->{'_fmin'} == $self->{'_fmax'}){

	$self->{'_strand'} = '.';

    } elsif ($self->{'_fmin'} > $self->{'_fmax'}){

	$self->{'_strand'} = '-';

    } elsif ($self->{'_fmax'} > $self->{'_fmin'}){

	$self->{'_strand'} = '+';

    } else {

	$logger->logdie("Logic error: fmin '$self->{'_fmin'}' ".
			"fmax '$self->{'_fmax'}'");
    }
}


=item $obj->print($featureType)

B<Description:> Print the attributes of this Exon attributes to STDOUT

B<Parameters:> $featureType (optional: scalar - string)

B<Returns:> None

=cut

sub print {

  my $self = shift;
  my ($featureType) = @_;
  if (defined($featureType)){
      print "Here are the primary attributes of this '$featureType':\n";
  } else {
      print "Here are the primary attributes of this Feature:\n";
  }

  print "id:$self->{'_id'}\n";
  print "class:$self->{'_class'}\n";
  print "seq:$self->{'_seq'}\n";
  print "fmin:$self->{'_fmin'}\n";
  print "fmax:$self->{'_fmax'}\n";
  print "strand:$self->{'_strand'}\n";
  print "parent:$self->{'_parent'}\n";
  print "product:$self->{'_product'}\n";
  print "moltype:$self->{'_moltype'}\n";

}

=item $obj->clone()

B<Description:> Create a carbon copy of this Feature

B<Parameters:> None

B<Returns:> $feature (Annotation::Features::Feature)

=cut

sub clone {

  my $self = shift;

  my $feature = new Annotation::Features::Feature(id => $self->{_id},
						  class => $self->{_class},
						  seq => $self->{_seq},
						  fmin => $self->{_fmin},
						  fmax => $self->{_fmax},
						  strand => $self->{_strand},
						  parent => $self->{_parent},
						  product => $self->{_product},
						  moltype => $self->{_moltype} );


  if (!defined($feature)){
      $logger->logdie("Could not instantiate Annotation::Features::Feature ".
		      "object this was :" . Dumper $self);
  }

  return $feature;
}


=item $obj->rearrangeCoordinatesNonDecreasingOrder()

B<Description:> Rearrange the coordinates in non-decreasing order

B<Parameters:> None

B<Returns:> None

=cut

sub rearrangeCoordinatesNonDecreasingOrder {
    
    my $self = shift;
    
    if (( exists $self->{_fmin}) && ( exists $self->{_fmax} )){
	
	if ($self->{_fmin} > $self->{_fmax}){
	    
	    my $swapHold = $self->{_fmin};
	    
	    $self->{_fmin} = $self->{_fmax};
	    
	    $self->{_fmax} = $swapHold;

	    $self->{_strand} = '-';
	}
    }
}



=item $obj->interbaseConversion()

B<Description:> Convert to interbase coordinate system

B<Parameters:> None

B<Returns:> None

=cut

sub interbaseConversion {
    
    my $self = shift;
    
    $self->{_fmin} = $self->{_fmin} - 1;
}

=item $obj->getNumericStrandValue()

B<Description:> Retrieve the strand for this Feature

B<Parameters:> None

B<Returns:> $strand (scalar - integer)

=cut

sub getNumericStrandValue {

    my $self = shift;

    if (( exists $self->{_numeric_strand_value}) && 
	( defined($self->{_numeric_strand_value}))){
	return $self->{_numeric_strand_value};
    }


    if (! exists $self->{'_strand'}){
	$self->_inferStrand();
    }


    my $strandSign = $self->{_strand};
    if ($strandSign eq '-'){
	$self->{_numeric_strand_value} = -1;
    } else {
	$self->{_numeric_strand_value} = 1;
    }

    return $self->{_numeric_strand_value};
}


1==1; ## End of module
