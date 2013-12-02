#!/usr/bin/perl

use strict;

my $sizeLim=50;
my $sub;
my $count;
my %lib;

while(<>)
{	my @temp=split(/\t/,$_);
	my $clib;
	if ($temp[15] =~ /^\(/)
	{	$clib=substr($temp[5],0,3);
	}
	else
	{	$clib=$temp[15];
	}
	if ($sub && $sub eq $temp[0])
	{	$count++;
		if ($count < $sizeLim || ! $lib{$clib})
		{	print $_;
			$lib{$clib}=1;	
		}
	}
	else
	{	$sub=$temp[0];
		undef %lib;
		$lib{$clib}=1;
		$count=0;
		print $_;
	}
}
