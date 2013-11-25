package Annotation::Features::AnnotationAttribute;

=head1 NAME

Annotation::Features::AnnotationAttribute.pm

=head1 VERSION

1.0

=head1 SYNOPSIS

use Annotation::Features::AnnotationAttribute;


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

new{}
_init{}
DESTROY{}

=over 4

=cut

use strict;
use Annotation::Logger;


my $logger = Annotation::Logger::get_logger("Logger::Annotation");

=item new()

B<Description:> Instantiate Annotation::Features::AnnotationAttribute object

B<Parameters:> None

B<Returns:> reference to the Annotation::Features::AnnotationAttribute object

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

B<Description:> Annotation::Features::AnnotationAttribute class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

  my $self = shift;

  if ($logger->is_debug()){
      $logger->debug("Destroying '" . __PACKAGE__ ."'");
  }
}


1==1; ## end of module
