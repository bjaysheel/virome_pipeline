package Prism::SybaseProkPrismDB;

use strict;
use base qw(Prism::ProkPrismDB);
use base qw(Coati::Coati::SybaseProkCoatiDB);


sub test_SybaseProkPrismDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_ProkPrismDB();
}

sub testProjDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_SybaseProkPrismDB();
}

1;
