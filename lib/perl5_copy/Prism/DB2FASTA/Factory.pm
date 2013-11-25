package Prism::DB2FASTA::Factory;

=head1 NAME

Prism::DB2FASTA::Factory

=head1 VERSION

1.0

=head1 SYNOPSIS


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

new
_init
DESTROY
create

=over 4

=cut


use strict;
use Carp;
use Chado::DB2FASTA;
use Euk::DB2FASTA;
use Prok::DB2FASTA;

=item new()

B<Description:> Instantiate Prism::DB2FASTA::Factory object

B<Parameters:> None

B<Returns:> reference to the Prism::DB2FASTA::Factory object

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
	
	if (lc($args{type}) eq 'chado'){

	    my $converter = new Chado::DB2FASTA(@_);

	    if (!defined($converter)){
		confess "Could not instantiate Chado::DB2FASTA";
	    }

	    return $converter;

	} elsif (lc($args{type}) eq 'euk'){

	    my $converter = new Euk::DB2FASTA(@_);

	    if (!defined($converter)){
		confess "Could not instantiate Euk::DB2FASTA";
	    }

	    return $converter;

	} elsif (lc($args{type}) eq 'prok'){

	    my $converter = new Prok::DB2FASTA(@_);
	    
	    if (!defined($converter)){
		confess "Could not instantiate Prok::DB2FASTA";
	    }
	    
	    return $converter;
	    
	} else {

	    confess "type '$args{type}' is not currrently supported";
	}

    } else {
	
	confess "type was not specified";
    }
}

1==1; ## end of module
