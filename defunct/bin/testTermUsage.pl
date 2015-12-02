#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use strict;

use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Coati::Logger;
use Config::IniFiles;
use Tie::File;

$|=1;



my $username = 'access';
my $password = 'access';
my $database = 'gba';

#
# Instantiate Prism object
#
my $prism = &retrieve_prism_object($username, $password, $database);

my $term = 'mRNA';

my $standard = $prism->{_termusage}->so_used($term);

print "standard '$standard' for term '$term'\n";

#----------------------------------------------------------------
# retrieve_prism_object()
# 
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database) = @_;

    my $prism = new Prism(
			  user              => $username,
			  password          => $password,
			  db                => $database
			  );

    
    return $prism;

}#end sub retrieve_prism_object()

