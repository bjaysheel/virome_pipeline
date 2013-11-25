package Annotation::Features::EpitopeAACollection;

=head1 NAME

Annotation::Features::EpitopeAACollection.pm

=head1 VERSION

1.0

=head1 SYNOPSIS

use Annotation::Features::EpitopeAACollection;


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

new{}
_init{}
DESTROY{}
addAttributes{}

=over 4

=cut

use strict;
use Annotation::Logger;
use base "Annotation::Features::AACollection";

## Keep track of the PredictedGene objects to be returned
my $recordIndex=0;

my $logger = Annotation::Logger::get_logger("Logger::Annotation");

=item new()

B<Description:> Instantiate Annotation::Features::EpitopeAACollection object

B<Parameters:> None

B<Returns:> reference to the Annotation::Features::EpitopeAACollection object

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

  if ($logger->is_debug()){
      $logger->debug("Initializing '" . __PACKAGE__ ."'");
  }

  return $self;
}


=item DESTROY

B<Description:> Annotation::Features::EpitopeAACollection class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

  my $self = shift;

  if ($logger->is_debug()){
      $logger->debug("Destroying '" . __PACKAGE__ ."'");
  }
}

=item $obj->addAttributes(name=>$name,val=>$val)

B<Description:> Add attributes to the collection

B<Parameters:> 

$args{name} (scalar - string) required
$args{val} (scalar - string) required

B<Returns:> None

=cut

sub addAttributes  { 

  my $self = shift;
  my (%args)= @_;

  if (!exists $args{name}){
      $logger->logdie("name was not defined!");
  }
  if (!exists $args{val}){
      $logger->logdie("val was not defined!");
  }

  push(@{$self->{_attrs}->{$args{name}}}, $args{val});
 

}

1==1; ## end of module
