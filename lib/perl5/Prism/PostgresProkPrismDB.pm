package Prism::MysqlProkPrismDB;

use strict;
use base qw(Prism::ProkPrismDB);

my $MODNAME = "MysqlProkPrismDB.pm";

sub say_hello {
    my ($self, @args) = @_;
    $self->_trace if $self->{_debug};
    print "Hi there.\n";
}

1;
