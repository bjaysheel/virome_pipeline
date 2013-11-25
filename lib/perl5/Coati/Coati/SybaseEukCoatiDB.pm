package Coati::Coati::SybaseEukCoatiDB;

use strict;
use base qw(Coati::Coati::EukCoatiDB Coati::SybaseHelper);

#################################

sub _connect {
    my ($self, $hostname, @args) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    #
    # Connect to the Sybase database
    Coati::SybaseHelper::connect($self);
}

sub do_set_textsize {
    my ($self, $size) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    
    my $query = "SET TEXTSIZE $size ";
    $self->_do_sql($query);
}

#################################

1;

