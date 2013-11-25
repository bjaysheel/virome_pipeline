package Annotation::IdGenerator::Ergatis::Util;

=head1 NAME

Annotation::IdGenerator::Ergatis::Util.pm

=head1 VERSION

1.0

=head1 SYNOPSIS


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS


=over 4

=cut

use strict;
use Annotation::Logger;

my $logger = Annotation::Logger::get_logger("Logger::Annotation");


=item new()

B<Description:> Instantiate Annotation::IdGenerator::Ergatis::Util object

B<Parameters:> None

B<Returns:> reference to the Annotation::IdGenerator::Ergatis::Util object

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

B<Description:> Annotation::IdGenerator::Ergatis::Util class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  {
  my $self = shift;

}

=item $obj->isRepositoryValid($dir)

B<Description:> Verify that the specified directory is set up correctly

B<Parameters:> $dir (scalar - string)

B<Returns:> $boolean 0 = false, 1 = true

=cut

sub isRepositoryValid {

    my $self = shift;
    my ($dir) = @_;

    if (!defined($dir)) {

	if (exists $self->{_repository}){

	    $dir = $self->{_repository};

	} else {

	    $logger->logdie("dir was not defined");
	}
    }

    my $boolean = 1;

    if (!-e $dir){
	$logger->warn("The repository '$dir' does not exist");
	$boolean = 0;
    }

    if (!-w $dir){
	$logger->warn("The repository '$dir' does not have write permissions");
	$boolean = 0;
    }
    
    if (!-r $dir){
	$logger->warn("The repository '$dir' does not have read permissions");
	$boolean = 0;
    }

    if (!-s $dir){
	$logger->warn("The repository '$dir' does not have any content");
	$boolean = 0;
    }


    if (!-e "$dir/valid_id_repository"){
	$logger->warn("The repository '$dir' does not have the required valid_id_repository file.");
	$boolean = 0;
    }

    return $boolean;
}

1==1; ## end of module
