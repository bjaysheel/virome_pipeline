package Prism::MysqlEukPrismDB;

use strict;
use base qw(Prism::EukPrismDB);

my $MODNAME = "MysqlEukPrismDB.pm";

sub say_hello {
    my ($self, @args) = @_;
    $self->_trace if $self->{_debug};
    print "Hi there.\n";
}

1;
