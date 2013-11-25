package Coati::Coati::MysqlEukCoatiDB;

use strict;
use base qw(Coati::Coati::EukCoatiDB);
use base qw(Coati::MysqlHelper);

#################################

sub _connect {
    my ($self, $hostname, @args) = @_;
    
    $self->{_logger}->debug("Args: ",join(',',splice(@_,1))) if $self->{_logger}->is_debug;
    #
    # Connect to the MySQL database
    Coati::MysqlHelper::connect($self);
}

sub do_set_textsize {
    my ($self, $size) = @_;
    return undef;
}

#################################

1;
