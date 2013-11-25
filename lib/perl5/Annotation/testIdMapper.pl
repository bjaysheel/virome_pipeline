#!/usr/local/bin/perl
use strict;
use File::Basename;
use Annotation::IdMapper;


my $file = $ARGV[0];
if (!defined($file)){
    die "Usage: $0 <file> <dir>";
}
my $dir = $ARGV[1];
if (!defined($dir)){
    die "Usage: $0 <file> <dir>";
}

my $outfile = '/tmp/' . File::Basename::basename($file);

my $idmapper = new Annotation::IdMapper(filename=>$outfile);

$idmapper->loadIdMappingLookup($dir, $file);

#print "idmapper:" . Dumper $idmapper;

$idmapper->writeIdMappingFile($outfile);

print "$0 execution completed\n";
print "Wrote ID mapping file '$outfile'\n";
exit(0);
