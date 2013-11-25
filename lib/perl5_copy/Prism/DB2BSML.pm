package Prism::DB2BSML;


use strict;
use Carp;


=item new()

B<Description:> Instantiate Prism::DB2BSML object

B<Parameters:> None

B<Returns:> reference to the Prism::DB2BSML object

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



1==1; ## end of module
