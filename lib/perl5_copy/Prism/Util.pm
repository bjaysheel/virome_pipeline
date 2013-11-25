package Prism::Util;
# $Id: Util.pm 3980 2009-01-14 02:33:00Z jaysundaram $

=head1 NAME

Prism::Util.pm - General class methods for helping client programs

=head1 VERSION

1.0

=head1 SYNOPSIS

Coming

=head1 DESCRIPTION

=head2 Overview

An overview of the purpose of the file.

=head2 Constructor and initialization.

if applicable, otherwise delete this and parent head2 line.

=head2 Class and object methods

if applicable, otherwise delete this and parent head2 line.

=head1 CONTACT

Jay Sundaram
sundaram@jcvi.org


=cut


use strict;
use Carp;

## Do not buffer output stream
$|=1;

my $REVISION = q|$REVISION$|;
my $VERSION = q|$NAME$|;


sub removeParentheses {

    my $string = shift;

    # remove all open parentheses
    $string =~ s/\(//g;
    
    # remove all close parentheses
    $string =~ s/\)//g;

    return $string;
}


1==1; ## end of module
