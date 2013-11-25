package Prism::DB2BSML::Factory;


use strict;
use Carp;
use Prism::DB2BSML;
use Phytoplankton::EUK2BSML;


=item new()

B<Description:> Instantiate Prism::DB2BSML::Factory object

B<Parameters:> None

B<Returns:> reference to the Prism::DB2BSML::Factory object

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


sub create {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{type}) && (defined($args{type}))){
	
	if (lc($args{type}) eq 'phytoplankton'){

	    my $converter = new Phytoplankton::EUK2BSML(@_);

	    if (!defined($converter)){
		confess "Could not instantiate Phytoplankton::EUK2BSML";
	    }

	    return $converter;

	} else {
	    confess "type '$args{type}' is not currrently supported";
	}

    } else {

	my $converter = new Prism::DB2BSML(@_);

	if (!defined($converter)){
	    confess "Could not instantiate Prism::DB2BSML";
	}

	return $converter;
	
    }
}

1==1; ## end of module
