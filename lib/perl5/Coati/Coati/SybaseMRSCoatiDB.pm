package Coati::Coati::SybaseMRSCoatiDB;

use strict;
use base qw(Coati::Coati::MRSCoatiDB Coati::SybaseHelper);

###################################

sub _connect {
    my ($self, $hostname, @args) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    Coati::SybaseHelper::connect($self);    
}

###################################

1;

