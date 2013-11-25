#!/usr/local/bin/perl
=head1 NAME

bcpdir2iterator.pl - Migrates BSML search/compute documents to the chado companalysis module

=head1 SYNOPSIS

USAGE:  bcpdir2iterator.pl --bcp_directory --bcp_extension [--debug] [--help|h] [--log] [-m man] 

=head1 OPTIONS

=over 8

=item B<--bcp_directory>
    
Directory containing all of the delimited files for bulk-loading

=item B<--bcp_extension>
    
The filename extension of the delimited files

=item B<--debug,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--help,-h>

    Print this help

=back

=head1 DESCRIPTION

=cut

use strict;
use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Coati::Logger;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my %options;
my $results = GetOptions (\%options, 
			  'output_iterator_list|o=s',
			  'bcp_directory|b=s',
			  'bcp_extension|e=s',
			  'log|l=s',
			  'debug|d=s',
			  'help|h',       
			  );

## initialize the logger
$options{'log'} = "/tmp/bcpdir2iterator.pl.log" if (!defined($options{'log'}));

my $mylogger = new Coati::Logger('LOG_FILE'=>$options{'log'},
				 'LOG_LEVEL'=>$options{'debug'});

my $logger = Coati::Logger::get_logger(__PACKAGE__);


my $tableCommitOrder = Prism::chadoTableCommitOrder();

open OUTFH,">$options{'output_iterator_list'}" or $logger->logdie("Can't open file $options{'output_iterator_list'}");

my @tables = split(/,/,$tableCommitOrder);
print OUTFH "\$;I_TABLE_NAME\$;\t\$;I_BCP_FILE\$;\t\$;I_BCP_FILE_BASE\$;\n";
foreach my $table (@tables){
    if(-e "$options{'bcp_directory'}/$table.$options{'bcp_extension'}"){
	print OUTFH "$table\t$options{'bcp_directory'}/$table.$options{'bcp_extension'}\t$table.$options{'bcp_extension'}\n";
    }
}
close OUTFH;


