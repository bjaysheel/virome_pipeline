#!/usr/local/bin/perl
use strict;
use Prism::Helper;
use Data::Dumper;

my $vendor = "sybase";
my $server = "SYBTIGR";

if (! Prism::Helper::verifyDatabaseType($vendor)){
    die "Database type '$vendor' is not supported";
} else {
    print "Database type '$vendor' is supported by Prism\n";
}

Prism::Helper::setPrismEnv($server, $vendor);

my $env = $ENV{PRISM};

print "In the client, the PRISM environment variable is '$env'\n";

print "$0 execution completed\n";
exit(0);
