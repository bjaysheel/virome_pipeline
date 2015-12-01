#!/usr/bin/perl

=head1 NAME

db-load-library.pl - load Library output to db

=head1 SYNOPSIS

USAGE: db-load-library.pl
            --id=124
            --prefix="PRF"
            --name="Library name"
	    --outdir=/path/to/output/dir
	    --env=/env where to execute script
          [ --log=/path/to/logfile
            --debug=N
          ]

=head1 OPTIONS

B<--id, -i>
    The id number of the library you are running.

B<--prefix, -p>
    Three letter prefix for the library.

B<--name, -n>
    The name of the library.

B<--env, -e>
    The environment that this pipeline is running at.

B<--outdir, o>
    Path to output dir where a tab file of library id and library prefix is stored.

B<--debug,-d>
    Debug level.  Use a large number to turn on verbose debugging.

B<--log,-l>
    Log file

B<--help,-h>
    This help message

=head1  DESCRIPTION

This script is used to load library infomation into MySQL database.

=head1  INPUT

The input to this is defined using the --id.  This should be
the id number of the library you wish to run. If the library you
wish to run does not have an id than you will need to add
the information tot he table.

=head1  CONTACT

    Daniel J. Nasko
    dan.nasko@gmail.com

=cut

use strict;
use warnings;
use DBI;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
BEGIN {
  use Ergatis::Logger;
}

## ARGUMENTS WITH NO DEFAULT
my($id,$outdir,$prefix,$name,$env,$help,$manual);

GetOptions (
    "i|id=s"       =>  \$id,
    "o|outdir=s"   =>  \$outdir,
    "p|prefix=s"   =>  \$prefix,
    "n|name=s"     =>  \$name,
    "e|env=s"      =>  \$env,
    "h|help"       =>  \$help,
    "m|manual"     =>  \$manual);

## VALIDATE ARGS
pod2usage(-verbose => 2) if ($manual);
pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} ) if ($help);
pod2usage( -msg  => "\n\n Fatal! Required argument -id not found.\n\n", -exitval => 2, -verbose => 1)     if (! $id );
pod2usage( -msg  => "\n\n Fatal! Required argument -outdir not found.\n\n", -exitval => 2, -verbose => 1) if (! $outdir );
pod2usage( -msg  => "\n\n Fatal! Required argument -prefix not found.\n\n", -exitval => 2, -verbose => 1) if (! $prefix );
pod2usage( -msg  => "\n\n Fatal! Required argument -name not found.\n\n", -exitval => 2, -verbose => 1)   if (! $name );
pod2usage( -msg  => "\n\n Fatal! Required argument -env not found.\n\n", -exitval => 2, -verbose => 1)    if (! $env );

open(OUT, ">", "$outdir/db-load-library.txt") || die "\n Cannot open: $outdir/db-load-library.txt\n";
print OUT $id . "\t" . $name . "\t" . $prefix . "\t" . "noDB" . "\t" . $env . "\n";
close(OUT);

exit 0;
