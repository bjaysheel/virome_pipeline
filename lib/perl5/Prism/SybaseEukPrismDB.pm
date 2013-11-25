package Prism::SybaseEukPrismDB;

use strict;
use base qw(Prism::EukPrismDB);
use base qw(Coati::Coati::SybaseEukCoatiDB);


sub test_SybaseEukPrismDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_EukPrismDB();
}

sub testProjDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_SybaseEukPrismDB();
}

1;
