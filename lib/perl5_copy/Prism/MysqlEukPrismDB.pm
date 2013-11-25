package Prism::MysqlEukPrismDB;

use strict;
use base qw(Prism::EukPrismDB Coati::Coati::MysqlEukCoatiDB);

my $MODNAME = "MysqlEukPrismDB.pm";

sub test_MysqlEukPrismPrismDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_EukPrismDB();
}

sub testProjDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_MysqlEukPrismDB();
}

1;
