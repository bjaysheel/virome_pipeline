package Coati::Coati::MysqlMRSCoatiDB;

use strict;
use base qw(Coati::Coati::MRSCoatiDB Coati::MysqlHelper);

###################################

sub _connect {
    my ($self, $hostname, @args) = @_;
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    Coati::MysqlHelper::connect($self);
}

###################################

1;
