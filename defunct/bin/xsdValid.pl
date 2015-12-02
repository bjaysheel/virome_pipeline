#!/usr/local/bin/perl

use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);

my %options = ();

my $results = GetOptions( \%options, 'schema|s=s', 'help|h' );

if( $options{'help'} )
{
    
    print "\nxsdValid.pl validates xml documents using a user specified schema.\n\n";
    print "Usage:    ./xsdValid.pl -s schema.xsd file.xml\n\n";
    print "Options:\n    --schema | -s   : the file path to the schema\n";
    print "    --help | -h   : this message\n\n";
    print "Output:\n    Nothing if validation is successful\n";
    print "    XML Schema errors if validation is unsuccessful\n\n\n";

    exit(4);
}

##############################################################################
## TEMPORARY HACK
## because of library differences between the servers and desktop machines,
## this script will return true any time it is run on a machine with the 2.6
## series kernel.  this should be removed once the servers are upgraded.

my $uname = `uname -r`;

if ($uname =~ /^2.6/) {
    exit(0);
}

$ENV{LD_LIBRARY_PATH} = "/usr/local/lib:$ENV{LD_LIBRARY_PATH}";

##############################################################################

my $file = $ARGV[0];

my $schema = $options{'schema'};

$schema =~ s/\//\\\//g;

my ($dir) = ($0 =~ /(.*)\/.*/);

my $status = system "sed -e \'s/<\\!DOCTYPE Bsml PUBLIC \"-\\/\\/EBI\\/\\/Labbook, Inc. BSML DTD\\/\\/EN\" \"http:\\/\\/www.labbook.com\\/dtd\\/bsml3_1.dtd\">//\' -e \'s/<Bsml>/<Bsml xmlns:xsi=\"http:\\/\\/www.w3.org\\/2001\\/XMLSchema-instance\" xsi:noNamespaceSchemaLocation=\"$schema\">/\' $file | $dir/Xerces-xsdValid";

my $exit_value = $status >> 8;
my $signal_num = $status & 127;
my $dumped_core = $status & 128;

exit($exit_value);
