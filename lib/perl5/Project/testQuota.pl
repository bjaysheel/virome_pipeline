#!/usr/local/bin/perl
use strict;
use Project::Quota;
use Data::Dumper;

my $project = '/usr/local/annotation/NTSF05';
my $outfile = '/usr/local/scratch/sundaram/quota-check.txt';

my $q = new Project::Quota(project_path=>$project);

if (!defined($q)){
    die "Could not instantiate Project::Quota object";
}

print "The quota is : "  . $q->getQuota() . "\n";

print "The current usage is : " . $q->getCurrentUsage() . "\n";


my $projectName = $q->getProjectName();

print "The project space for project '$projectName':\n";

if ($q->haveAtleast5Percent()){
    print "\thas at least 5% of its space remaining\n";
}

if ($q->haveAtleast10Percent()){
    print "\thas at least 10% of its space remaining\n";
}

if ($q->haveAtleast15Percent()){
    print "\thas at least 15% of its space remaining\n";
}

if ($q->haveAtleast20Percent()){
    print "\thas at least 20% of its space remaining\n";
}

my $premaining = $q->getPercentRemaining();

print "The amount of space remaining is '$premaining'\n";

my $kb = $q->getKBRemaining();

print "The amount of space remaining in kilobytes is '$kb'\n";

if ($q->haveAtleast20KB()){
    print "This project has at least 20 kilobytes of space remaining!\n";
}

$q->printUserQuota(dir => '/usr/local/scratch/',
		   append=>1,
		   outfile => $outfile);


print "$0 execution completed\n";
print "The output file is '$outfile'\n";
exit(0);
