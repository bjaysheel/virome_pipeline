#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
=head1 NAME

createTableIteratorListFile.pl - Creates table list file for workflow iterators

=head1 SYNOPSIS

USAGE:  createTableIteratorListFile.pl [--chado_mart] [-d debug_level] [-h] [--logfile] [-m] [--outdir]

=head1 OPTIONS

=over 8

=item B<--chado_mart>
    
Optional - Create a list of chado-mart tables (default creates a list of core chado tables only)

=item B<--debug_level,-d>
    
Optional - Coati::Logger log4perl logging level (default is 0)

=item B<--help,-h>

Print this help

=item B<--logfile,-l>
    
Optional - Log4perl log file.  (default is /tmp/createTableIteratorListFile.pl.log)

=item B<--man,-m>

Display pod2usage man page for this utility

=item B<--outdir>
    
Optional - Output directory were the selectcount.sql files will be written (default is current working directory)

=back

=head1 DESCRIPTION

    createTableIteratorListFile.pl - Creates table list file for workflow iterators
    e.g.
    1) ./createTableIteratorListFile.pl
    1) ./createTableIteratorListFile.pl --chado_mart=1

=head1 CONTACT
                                                                                                                                                             
    Jay Sundaram
    sundaram@tigr.org

=cut

use Prism;
use Pod::Usage;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Coati::Logger;


## Don't buffer
$|=1;

my ($chadomart, $debug_level, $help, $logfile, $man, $outdir);

my $results = GetOptions (
			  'chado_mart=s'   => \$chadomart,
			  'debug_level=s'   => \$debug_level,
			  'help|h'          => \$help,
			  'logfile=s'       => \$logfile,
			  'man|m'           => \$man, 
			  'outdir=s'        => \$outdir
			  );

if ($man){
    &pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
}
if ($help){
    &pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
}


## Initialize the logger
if (!defined($logfile)){
    $logfile = '/tmp/createTableIteratorListFile.pl.log';
    print STDERR "logfile was set to '$logfile'\n";
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$logfile,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

if (!defined($outdir)){
    $outdir = '.';
}

my $commitorder;
my $file;
if (defined($chadomart)){
    $commitorder = Prism::chadoMartTableCommitOrder();
    $file = $outdir . '/chado_mart.table.list';
}
else {
    $commitorder = Prism::chadoCoreTableCommitOrder();
    $file = $outdir . '/chado.table.list';
}

if (!defined($commitorder)){
    $logger->logdie("commitorder was not defined");
}

my @tablelist = split(/,/, $commitorder);

open (OUTFILE, ">$file") || $logger->logdie("Could not open file '$file' for output:$!");

print OUTFILE '$;TABLE$;' . "\n";
foreach my $table (@tablelist){
    print OUTFILE "$table\n";
}

print "iterator file is '$file'\n";
print "$0 program execution complete\n";
print "Log file is '$logfile'\n";
exit(0);


#---------------------------------------------------------------------------------------
#
#            END MAIN -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------

#--------------------------------------------------------------------
# printUsage()
#
#--------------------------------------------------------------------
sub printUsage {

    print STDERR "SAMPLE USAGE:  $0 [--chado_mart] [-d debug_level] [-h] [--logfile] [-m] [--outdir]\n".
    "  --chado_mart     = Optional - creates a chado-mart table list file (default creates a chado core table list file)\n".
    "  -d|--debug_level = Optional - Coati::Logger log4perl logging level (default is 0)\n".
    "  -h|--help        = Optional - This help message\n".
    "  --logfile        = Optional - log4perl log file (default is /tmp/createTableIteratorListFile.pl.log)\n".
    "  -m|--man         = Optional - Display the pod2usage man page for this utility\n".
    "  --outdir         = Optional - directory to which the select.sql files should be written (default is current working directory)\n";
    exit(1);
}


