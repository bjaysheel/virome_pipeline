#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

# This script is used to retrieve quota information from the
# Panasas storage given directory paths as argumetns:
#
#  Example: get_quota.pl <dir1>
#           get_quota.pl <dir1> <dir2> ... <dirN>

# Author: Victor Felix <vfelix@som.umaryland.edu>

use strict;
use IGS::Storage::Isilon::Quota;
use IGS::Storage::Panasas::Quota;
print "***Each project area look up can take up to 30 seconds***\n";
print "------------------------------\n";
foreach my $dir (@ARGV) {
    my $stats = get_volume_isilon($dir);
    my $path = "";
    if (defined $stats->{'Path'}) {
	my $usage = (((($stats->{'Usage'})/1024)/1024)/1024);
	my $softQuota = (((($stats->{'Soft Quota'})/1024)/1024)/1024);
	my $hardQuota = (((($stats->{'Hard Quota'})/1024)/1024)/1024);
	if ( $stats->{'Path'} =~ m/\/(\w+)$/) {
		$path = $1;
	} else {
		$path = $stats->{'Path'};
	}
        print "Name:       " . $path . "\n";
        printf "Space Used: %.2f GB\n", $usage;
        printf "Soft Quota: %.2f GB\n", $softQuota;
        printf "Hard Quota: %.2f GB\n", $hardQuota;
    } else {
	$stats = get_volume_stats($dir);
	if (defined $stats->{'Status'} && defined $stats->{'Name'}) {
		print "Name:       " . $stats->{'Name'} . "\n";
		print "Space Used: " . $stats->{'Space Used'} . "\n";
		print "Soft Quota: " . $stats->{'Soft Quota'} . "\n";
		print "Hard Quota: " . $stats->{'Hard Quota'} . "\n";
		print "Status:     " . $stats->{'Status'} . "\n";
	} else {
		print "$dir Volume does not appear to be on Panasas or Isilon.\n";
    	}
    }
    print "------------------------------\n";
}

