#!/usr/bin/perl -w

=head1 NAME
    LIBINFO: class that will extract library info from library list file or
    library file.  An output of db-load-library.

=head1 SYNOPSIS
    use LIBINFO;

    ##################
    # class methods
    ##################
    $libinfo = LIBInfo->new;

=cut

package LIBInfo;

use strict;
use Carp;

my $obj = {};

sub new{
    my $self = shift;

    return bless({},$self);
}

sub getLibFileInfo{
    my $self = shift;
    my $filename = $_[0];

    open (FHD, $filename) or die "Can not open input file $filename\n";

    while (<FHD>){
        chomp $_;
        my @info = split (/\t/,$_);

		$self->{id} = $info[0];
        $self->{name} = $info[1];
        $self->{prefix} = $info[2];
        $self->{server} = $info[3];
    }

    return $self;
}

sub getLibListInfo{
    my $self = shift;
    my $filename = $_[0];

    open (LIB, $filename) or die ("Cannot open library file $filename");

    while (<LIB>){
        chomp $_;
        $self = $self->getLibFileInfo($_);
    }

    return $self;
}
