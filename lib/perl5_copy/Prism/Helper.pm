package Prism::Helper;
# $Id: Helper.pm 3980 2009-01-14 02:33:00Z jaysundaram $

=head1 NAME

Prism::Helper.pm - General class methods for helping clients prior to instantiating Prism.pm

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

my $supportedDatabaseVendors = { 'sybase' => 1,
				 'postgresql' => 1,
				 'mysql' => 1 };


sub setPrismEnv {

    my ($server, $vendor, $schema) = @_;

    if (!defined($server)){
	confess "server was not defined";
    }

    if (!defined($vendor)){
	confess "vendor was not defined";
    }

    if (lc($vendor) eq 'postgresql'){
	$vendor = 'postgres';
    }

    if (!defined($schema)){
	$schema = 'Chado';
    } else {
	$schema = lc($schema);
	$schema = ucfirst($schema);
    }

    $vendor = "Bulk" . ucfirst($vendor);
    ## We're overriding the env stored in conf/Prism.conf
    my $prismenv = "$schema:$vendor:$server";


    $ENV{PRISM} = $prismenv;

    print "PRISM environment variable set to '$prismenv'\n";
}

sub verifyDatabaseType {

    my ($database_type) = @_;

    if (!defined($database_type)){
	confess "database_type was not defined";
    }

    my $retVal = (exists $supportedDatabaseVendors->{$database_type}) ? 1: 0;

    return $retVal;
}

1==1; ## end of module
