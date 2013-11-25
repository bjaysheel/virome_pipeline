package Annotation::Features::AACollection;

=head1 NAME

Annotation::Features::AACollection.pm

Collection class for Annotation Attributes

=head1 VERSION

1.0

=head1 SYNOPSIS

use Annotation::Features::AACollection;


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

new{}
_init{}
DESTROY{}
createAndAddAttribute{}
addAttribute{}
nextAttribute{}
getCount{}


=over 4

=cut

use strict;
use Annotation::Logger;
use Annotation::Features::AnnotationAttribute;

## Keep track of the PredictedGene objects to be returned
my $recordIndex=0;

my $logger = Annotation::Logger::get_logger("Logger::Annotation");

=item new()

B<Description:> Instantiate Annotation::Features::AACollection object

B<Parameters:> None

B<Returns:> reference to the Annotation::Features::AACollection object

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

B<Description:> Annotation::Features::AACollection class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

  my $self = shift;

  if ($logger->is_debug()){
      $logger->debug("Destroying '" . __PACKAGE__ ."'");
  }
}

=item $self->createAndAddAttribute(%args)

B<Description:> Create and add an AnnotationAttribute to the collection

B<Parameters:> 

$name (scalar - string)
$value (scalar - unsigned integer)

B<Returns:> None

=cut

sub createAndAddAttribute {

    my $self = shift;
    my (%args) = @_;
    
    my $aa = new Annotation::Features::AnnotationAttribute(name=>$args{name},
							   value=>$args{value});
    if (! defined ($aa)){
	$logger->logdie("Could not instantiate Annotation::Features::AnnotationAttribute ".
			"for name '$args{name}' value '$args{value}'");
    }

    push(@{$self->{'_collection'}}, $aa);

    $self->{'_counter'}++;

}

=item $self->addAttribute($attribute)

B<Description:> Add an AnnotationAttribute to the collection

B<Parameters:> $aa (Annotation::Features::AnnotationAttribute)

B<Returns:> None

=cut

sub addAttribute {

    my $self = shift;
    my ($attribute) = @_;
    
    if (!defiend($attribute)){
	$logger->logdie("attribute was not defined!");
    }

    push(@{$self->{'_collection'}}, $attribute);

    $self->{'_counter'}++;

}


=item $self->nextAttribute()

B<Description:> Retrieve the next Annotation::Features::AnnotationAttribute object

B<Parameters:>  None

B<Returns:> $aa (Reference to Annotation::Features::AnnotationAttribute)

=cut

sub nextAttribute { 

  my $self = shift;
  
  if (( exists $self->{'_counter'}) && 
      ( $self->{'_counter'} > 0)) {

      if ( $recordIndex < $self->{'_counter'} ){
      
	  return $self->{'_collection'}->[$recordIndex++];

      } else {

	  $logger->warn("No more AnnotationAttribute objects in the collection");

	  return undef;
      }

  } else {

      $logger->logdie("There are no AnnotationAttribute objects in the collection");
  }
}


=item $self->getCount()

B<Description:> Retrieve the number of Annotation::Features::AnnotationAttribute objects in the collection

B<Parameters:>  None

B<Returns:> $count (scalar - unsigned integer)

=cut

sub getCount  { 

  my $self = shift;
  
  if ( exists $self->{'_counter'}){

      return $self->{'_counter'};

  } else {

      return 0;
  }
}


1==1; ## end of module
