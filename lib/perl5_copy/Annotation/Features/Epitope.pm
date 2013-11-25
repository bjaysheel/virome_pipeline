package Annotation::Features::Epitope;

=head1 NAME

Annotation::Features::Epitope.pm

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
addAttrbuteCollection{}

print{}

=over 4

=cut

use strict;
use Annotation::Logger;

my $logger = Annotation::Logger::get_logger("Logger::Annotation");


=item new()

B<Description:> Instantiate Annotation::Features::Epitope object

B<Parameters:> None

B<Returns:> reference to the Annotation::Features::Epitope object

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
}


=item DESTROY

B<Description:> Annotation::Features::Epitope class destructor

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

=item $obj->setClass($class)

B<Description:> Store the class for this Feature

B<Parameters:> $class (scalar - string)

B<Returns:>  None

=cut

sub setClass {

  my $self = shift;

  my ($class, @array) = @_;

  if (!defined($class)) {
    $logger->logdie("class was not defined");
  }
  if (scalar(@array) > 0){
      $logger->logdie("Received more parameters than was expecting! '@array'");
  }

  $self->{'_class'} = $class;

}

=item $obj->getClass()

B<Description:> Retrieve the class for this Feature

B<Parameters:> None

B<Returns:> $class (scalar - string)

=cut

sub getClass {

  my $self = shift;

  if ( exists $self->{'_class'}){
      return $self->{'_class'};
  } else {
      $logger->warn("class was not defined for this Feature");
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

  if ( exists $self->{'_stand'}){
      return $self->{'_strand'};
  } else {
      $logger->warn("strand was not defined for this Feature");
      return undef;
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
  print "seq:$self->{'_seq'}\n";
  print "fmin:$self->{'_fmin'}\n";
  print "fmax:$self->{'_fmax'}\n";
  print "strand:$self->{'_strand'}\n";

}



=item $obj->setFminIsPartial($fminIsPartial)

B<Description:> Set the fmin_is_partial for this Feature

B<Parameters:> $fmin_is_partial (scalar - unsigned integer)

B<Returns:>  None

=cut

sub setFminIsPartial {

  my $self = shift;

  my ($fminIsPartial, @array) = @_;

  if (!defined($fminIsPartial)) {
    $logger->logdie("fminIsPartial was not defined");
  }
  if (scalar(@array) > 0){
      $logger->logdie("Received more parameters than was expecting! '@array'");
  }

  if ($fminIsPartial == 1){

      $self->{_fmin_is_partial} =1;

  } elsif ($fminIsPartial == 0){

      $self->{_fmin_is_partial} =0;

  } else {

      $logger->logdie("Unacceptable value '$fminIsPartial'");
  }

}

=item $obj->isFminPartial()

B<Description:> Retrieve the fmin_is_partial for this Feature

B<Parameters:> None

B<Returns:> 0 = no, 1 = yes

=cut

sub isFminPartial {

  my $self = shift;

  if ( exists $self->{'_fmin_is_partial'}){
      return $self->{'_fmin_is_partial'};
  } else {
      $logger->warn("fmin_is_partial was not defined for this Feature");
      return 0;
  }
}


=item $obj->setFmaxIsPartial($fmaxIsPartial)

B<Description:> Store the fmax_is_partial for this Feature

B<Parameters:> $fmaxIsPartial (scalar - unsigned integer)

B<Returns:>  None

=cut

sub setFmaxIsPartial {

  my $self = shift;

  my ($fmaxIsPartial, @array) = @_;

  if (!defined($fmaxIsPartial)) {
    $logger->logdie("fmaxIsPartial was not defined");
  }
  if (scalar(@array) > 0){
      $logger->logdie("Received more parameters than was expecting! '@array'");
  }

  if ($fmaxIsPartial == 1){

      $self->{_fmax_is_partial} =1;

  } elsif ($fmaxIsPartial == 0){

      $self->{_fmax_is_partial} =0;

  } else {

      $logger->logdie("Unacceptable value '$fmaxIsPartial'");
  }

}

=item $obj->isFmaxPartial()

B<Description:> Retrieve the fmax_is_partial for this Feature

B<Parameters:> None

B<Returns:> 0 = no, 1 = yes

=cut

sub isFmaxPartial {

  my $self = shift;

  if ( exists $self->{'_fmax_is_partial'}){
      return $self->{'_fmax_is_partial'};
  } else {
      $logger->warn("fmax_is_partial was not defined for this Feature");
      return 0;
  }
}

=item $obj->addAttributeCollection($collection)

B<Description:> Add an Annotation::Features::EpitopeAACollection to this Epitope

B<Parameters:> $collection

B<Returns:> None

=cut

sub addAttributeCollection {

  my $self = shift;
  my ($collection) = @_;

  if (!defined($collection)){
      $logger->logdie("collection was not defined");
  }


  push(@{$self->{_aa_collection}}, $collection);

  $self->{_aa_collection_ctr}++;

}

1==1; ## End of module
