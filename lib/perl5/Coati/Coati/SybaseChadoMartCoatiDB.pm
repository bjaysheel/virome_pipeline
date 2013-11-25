package Coati::Coati::SybaseChadoMartCoatiDB;

use strict;
use base qw(Coati::Coati::ChadoMartCoatiDB Coati::SybaseHelper);

###################################

sub _connect {
    my ($self, $hostname, @args) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    Coati::SybaseHelper::connect($self);    
}

###################################

=item $obj->do_set_forceplan($force)

B<Description:>

   Modifies the setting of FORCEPLAN for the current session.  When FORCEPLAN is
   set to 'on' Sybase will attempt to use the join order implied by the order in
   which the tables are named in the FROM clause, rather than relying on the query
   planner to determine the join order.

B<Parameters:> 

    $force - a true value turns the forceplan option on, false turns it off

B<Returns:>

    NONE

=cut

sub do_set_forceplan {
    my ($self, $force) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    my $newValue = $force ? 'on' : 'off';
    $self->_do_sql("SET FORCEPLAN $newValue");
}

sub do_set_textsize {
    my ($self, $size) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SET TEXTSIZE $size ";
    $self->_do_sql($query);
}

1;

