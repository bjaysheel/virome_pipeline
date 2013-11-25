#!/usr/local/bin/perl
use strict;
use Prism::DB2FASTA::Factory;

my $type = 'chado';
my $factory = new Prism::DB2FASTA::Factory();
if (!defined($factory)){
    die "Could not instantiate Prism::DB2FASTA::Factory";
}

my $converter = $factory->create(type=>$type);
if (!defined($converter)){
    die "Could not retrieve converter for type '$type'";
}

if (ref($converter) eq 'Chado::DB2FASTA'){
    print "Received Chado::DB2FASTA object\n";
} else {
    die "Did not receive Chado::DB2FASTA object!  Instead, received: ". ref($converter);
}

print "$0 execution completed\n";
exit(0);
