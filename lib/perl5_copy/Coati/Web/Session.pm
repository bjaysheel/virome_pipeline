package Coati::Web::Session;

=head1 NAME

Coati::Web::Session

=head1 DESCRIPTION

	This module is a wrapper around CGI::Session.  It either creates a new session and 
	stores it on the filesystem, or uses a session that has already been created by 
	referencing the session id ($sid).

=cut


use strict;
use CGI::Session;


=item $obj->new($class)

B<Description:>

	Instantiate new Coati::Web::Session object

B<Parameters:> 

	$class - module to instantiate

B<Returns:>

	$self - reference to object

=cut

sub new {
	my ($class) = shift;
	my $self = {};
	bless( $self, $class );
	$self->_init(@_);
	return $self;
}

=item $obj->init($dsn, $sid, %args)

B<Description:>

	Create new CGI::Session object and store it on the filesystem

B<Parameters:> 

	$dsn  - if using database
	$sid  - session id
	%args - additional arguments that can be passed into CGI::Session

B<Returns:>

	NONE

=cut

sub _init {
	my ($self) = shift;
	my ($dsn)  = shift;
	my ($sid)  = shift;
	my %args = @_;
	$self->{_session} = CGI::Session->new( $dsn, $sid, {directory => $args{'directory'}} );
	$self->{_id} = $self->{_session}->id;
	$self->{_name} = $self->{_session}->name;
}

=item $obj->add_param($name, $value)

B<Description:>

	Add data to the session file

B<Parameters:> 
	
	$name  - name of the data to be loaded
	$value - value of the data to be loaded

B<Returns:>

	NONE

=cut

sub add_param {
	my ($self, $name, $value) = @_;
	$self->{_session}->param( $name, $value );
}

=item $obj->get_param($name)

B<Description:>

	Get data from the session file

B<Parameters:> 
	
	$name  - name of the data to be retrieved

B<Returns:>

	reference to an array filled with data values

=cut

sub get_param {
	my ($self, $name) = @_;
	if( !defined $self->{_session}->param( $name ) ) {
		return undef;
	}
	return $self->{_session}->param( $name );
}

=item $obj->remove_param($param)

B<Description:>

	Remove data from the session file

B<Parameters:> 
	
	$param - name of the data to be removed

B<Returns:>

	NONE

=cut

sub remove_param {
	my ($self, $param) = @_;
	$self->{_session}->clear( [$param] );
}

=item $obj->print_header()

B<Description:>

	Print the CGI header.  The cookie is attached to the header.

B<Parameters:> 
	
	NONE

B<Returns:>

	NONE

=cut

sub print_header {
	my ($self) = @_;
	print $self->{_session}->header();
}

=item $obj->remove_duplicates($list)

B<Description:>

	Removes any duplicates in the list of data that will be stored on the filesystem.

B<Parameters:> 
	
	$list - reference to an array

B<Returns:>

	\@new_list - reference to array that contains new non-redundant list

=cut

sub remove_duplicates {
	my ($self, $list) = @_;
	my %seen;
	my @new_list;
	foreach my $item (@$list) {
		if(!$seen{$item}) {
			push @new_list, $item;
		}
		$seen{$item} = 1;
	}
	return \@new_list;
}

1;
