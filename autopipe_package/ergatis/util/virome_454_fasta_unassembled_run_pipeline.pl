#!/usr/bin/perl

=head1 NAME

virome_454_fasta_run_pipeline.pl - A script allowing VIROME-Ergatis pipeline instantiation
and execution via the API.

=head1 SYNOPSIS

USAGE: virome_454_fasta_run_pipeline.pl 
            --template_directory=/path/to/some_dir/
            --repository_root=/path/to/project_dir
            --id_repository=/path/to/foo/id_repository
            --ergatis_ini=/path/to/ergatis.ini
            --fasta=/path/to/file.fasta
            --library_id=123
            --sequences=50000
            --prefix=PRF
            --database=diag1
            

=head1 OPTIONS

B<--template_directory,-t>
    The full path to a directory containing a pipeline.layout file and its associated
    INI configs

B<--repository_root,-r>
    Also known as a project area, under this directory we should find 

B<--id_repository,-i>
    Path to some global-level ID repository.  Will only be used to pull a pipeline ID.

B<--ergatis_ini,-e>
    Path to the ergatis.ini file, usually kept in the cgi directory of an interface instance.

B<--sequences,-s>
    Number of sequences in the input FASTA file

B<--fasta,-f>
    Path to the input FASTA file

B<--library_id,-y>
    The library ID

B<--prefix,-p>
    Prefix of the library

B<--database,-d>
    Database which this run will occur

B<--log,-l> 
    Log file

B<--help,-h>
    This help message


=head1  DESCRIPTION

It's not uncommon to want to instantiate and launch a pipeline from the command-line rather
than using the web interface.  This script illustrates how to do that in just a few lines of
code (4 lines, really, the rest is common perl script template code).

=head1  INPUT

Described in the options above, but the main input is the directory containing an Ergatis
pipeline template.  Once the template is loaded, you can use the Ergatis::ConfigFiles module
to customize the component configuration files for your application.  An example is shown in the
code.

=head1  OUTPUT

This script will use the pipeline template to instantiate a full pipeline in the passed project
area (repository root) and then execute it.

=head1  CONTACT

    Joshua Orvis
    jorvis@users.sf.net

    Daniel Nasko
    dan.nasko@gmail.com

=cut

use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib ("/var/www/html/cgi") ;

use Ergatis::ConfigFile;
use Ergatis::SavedPipeline;


my %options = ();
my $results = GetOptions (\%options,
			  'database|d=s',
			  'prefix|p=s',
			  'library_id|y=i',
                          'fasta|f=s',
			  'sequences|s=i',
                          'template_directory|t=s',
                          'repository_root|r=s',
                          'id_repository|i=s',
                          'ergatis_ini|e=s',
                          'log|l=s',
                          'help|h') || pod2usage();

## display documentation
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

## make sure everything passed was peachy
&check_parameters(\%options);

## open the log if requested
my $logfh;
if (defined $options{log}) {
    open($logfh, ">$options{log}") || die "can't create log file: $!";
}


##############################
## important bits here
##############################
my $fasta = $options{'fasta'};
my $database = $options{'database'};
my $library_id = $options{'library_id'};
my $prefix = $options{'prefix'};
my $sequences = $options{'sequences'};

my $template = Ergatis::SavedPipeline->new( 
               template => "$options{template_directory}/pipeline.layout");

my $pipeline = $template->write_pipeline( repository_root => $options{repository_root}, 
                                          id_repository => $options{id_repository} );

## here you can use Ergatis::ConfigFiles to edit some of the newly-written
##  component configurations before pipeline execution.  One example is shown.
##  naming and path conventions allow you to know where the component file is

## db-load-library
my $db_load_library_config = new Ergatis::ConfigFile(
    -file => "$options{repository_root}/workflow/runtime/db-load-library/" . $pipeline->id . "_default/db-load-library.default.user.config"
    );
$db_load_library_config->setval( 'parameter', '$;LOCATION$;', $database);
$db_load_library_config->RewriteConfig();
$db_load_library_config->setval( 'parameter', '$;PREFIX$;', $prefix);
$db_load_library_config->RewriteConfig();
$db_load_library_config->setval( 'parameter', '$;ID$;', $library_id);
$db_load_library_config->RewriteConfig();

## reset-processing-db
my $reset_proc_db_config = new Ergatis::ConfigFile(
    -file => "$options{repository_root}/workflow/runtime/reset_db/" . $pipeline->id . "_default/reset_db.default.user.config");
$reset_proc_db_config->setval('parameter', '$;LOCATION$;', $database );
$reset_proc_db_config->RewriteConfig();

## $fasta_size_filter
my $fasta_size_filter_config = new Ergatis::ConfigFile(
    -file => "$options{repository_root}/workflow/runtime/fasta_size_filter/" . $pipeline->id . "_default/fasta_size_filter.default.user.config");
$fasta_size_filter_config->setval('input', '$;INPUT_FILE$;', $fasta );
$fasta_size_filter_config->RewriteConfig();

## split_multifasta (if needed)
if ($sequences < 20) {
    my $split_multifasta_config = new Ergatis::ConfigFile(
	-file => "$options{repository_root}/workflow/runtime/split_multifasta/" . $pipeline->id . "_default/split_multifasta.default.user.config");
    $split_multifasta_config->setval('parameters', '$;TOTAL_FILES$;', $sequences );
    $split_multifasta_config->RewriteConfig();
}

## All of the components needing to get the location update . . .
my @LOCATION = qw( clean_expand_btab.mgol clean_expand_btab.uniref db-load-library.default db-load-nohit.default db-to-lookup.seq-lookup db-upload.blastp db-upload.orfs db-upload.orfs_nuc db-upload.rna-blast db-upload.rna-clean db-upload.rna db-upload.sequence_relationship-prep db-upload.trna env_lib_stats.default fxnal_count_chart_creator_all.default fxnal_count_chart_creator.default gen_lib_stats.default libraryHistogram.default sequence_relationship-prep.default viromeClassification.default viromeTaxonomyXML.default );

foreach my $component (@LOCATION) {
    my @a = split(/\./, $component);
    my $root = $a[0];
    my $token = $a[1];
    my $location_update = new Ergatis::ConfigFile(
	-file => "$options{repository_root}/workflow/runtime/$root/" . $pipeline->id .
	         "_$token/$component.user.config");
    $location_update->setval('parameter', '$;LOCATION$;', $database );
    $location_update->RewriteConfig();
}

## inspector
#my $inspector_config = new Ergatis::ConfigFile(
#    -file => "$options{repository_root}/workflow/runtime/inspector/" . $pipeline->id . "_default/inspector.default.user.config");
#my $db_number = $database;
#$db_number =~ s/diag//;
#$db_number = "virome_processing_" . $db_number;
#$inspector_config->setval('parameter', '$;LOCATION$;', $db_number );
#$inspector_config->RewriteConfig();

## Get ready to rumble . . .

my $ergatis_cfg = new Ergatis::ConfigFile( -file => $options{ergatis_ini} );

$pipeline->run( ergatis_cfg => $ergatis_cfg );


##############################
##############################


exit(0);


sub _log {
    my $msg = shift;

    print $logfh "$msg\n" if $logfh;
}


sub check_parameters {
    my $options = shift;
    
    ## make sure required arguments were passed
    my @required = qw( template_directory repository_root id_repository ergatis_ini fasta prefix library_id database sequences);
    for my $option ( @required ) {
        unless  ( defined $$options{$option} ) {
            die "--$option is a required option";
        }
    }
}
