#!/usr/local/bin/perl
use strict;
use Data::Dumper;
use Accession::Util;
use Prism::Helper;

my $database = 'gbm7';
my $asmbl_id = 199;
my $server   = 'SYBTIGR';
my $rdbms    = 'Sybase';
my $schema_type = 'prok';

Prism::Helper::setPrismEnv($server, $rdbms, $schema_type);

my $util = new Accession::Util(database=>$database,
			       schema_type=>$schema_type);

if (!defined($util)){
    die "Could not instantiate Accession::Util";
}

my $lookup = $util->getLookup(asmbl_id=>$asmbl_id);

foreach my $asmbl_id (keys %{$lookup}){
    
    print "For asmbl_id '$asmbl_id'\n";

    foreach my $feat_name (keys %{$lookup->{$asmbl_id}}){

	print "feat_name '$feat_name'\n"; 

	foreach my $db (keys %{$lookup->{$asmbl_id}->{$feat_name}}){

	    print "\tdatabase '$db' id '$lookup->{$asmbl_id}->{$feat_name}->{$db}'\n";
	}
    }
}

print "$0 execution completed\n";
exit(0);
