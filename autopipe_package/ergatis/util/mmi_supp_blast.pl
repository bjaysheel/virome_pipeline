#!/usr/bin/perl

=head1 NAME

mmi_supp_blast.pl

=head1 SYNOPSIS

USAGE: mmi_supp_blast.pl

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

B<--username,-u>
    Username of the user who owns this library

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

use DBI;

my $template_directory = "/diag/projects/virome/workflow/project_saved_templates/mmi_supp_blast";
my $repository_root = "/diag/projects/virome/";
my $id_repository = "/diag/projects/virome/workflow/project_id_repository/";
my $ergatis_ini = "/var/www/html/cgi/ergatis.ini";

##############################
## Get some things from SQL
##############################
my $library_name = "";
my $db_name = "mmi";
my $db_host = "virome-db.igs.umaryland.edu";
my $db_user = "dnasko";
my $db_pass = "dnas_76";
my @row;
my $dbh = DBI->connect("DBI:mysql:database=".$db_name.";host=".$db_host, $db_user, $db_pass,{PrintError=>1, RaiseError =>1, AutoCommit =>1});
my $check_sql = qq/SELECT count(*) FROM mmi_supp_blast WHERE complete = 0/;
my $sth_check = $dbh->prepare($check_sql);
$sth_check -> execute();
while (@row = $sth_check->fetchrow_array) {
    if ($row[0] == 0) {
	die "\n\n No more libraries to run...\n\n";
    }
}
my $select_sql = qq/SELECT name FROM mmi_supp_blast WHERE complete = 0 ORDER BY seqs ASC limit 1;/;
my $sth_select = $dbh->prepare($select_sql);
$sth_select->execute ();
while (@row = $sth_select->fetchrow_array) {
    $library_name = $row[0];
}

my $update_sql = qq/UPDATE mmi_supp_blast SET complete = 1 WHERE name = ?;/;
my $sth_update = $dbh->prepare($update_sql);
$sth_update->execute ($library_name);

my $input_library_file = "/home/dnasko/mgol_reference_construction_feb2013/MMI_METAGENOME_ORFs/" . $library_name . ".filtered.cd-hit-454.pep";
my $output_library_file = "/diag/projects/virome/mmi/uniref_supplementary/" . $library_name . ".virome.btab";
##############################
## important bits here
##############################

my $template = Ergatis::SavedPipeline->new( 
               template => "$template_directory/pipeline.layout");

my $pipeline = $template->write_pipeline( repository_root => $repository_root,
                                          id_repository => $id_repository );

## here you can use Ergatis::ConfigFiles to edit some of the newly-written
##  component configurations before pipeline execution.  One example is shown.
##  naming and path conventions allow you to know where the component file is

## Split MultiFASTA
my $split_multifasta_config = new Ergatis::ConfigFile(
    -file => "$repository_root/workflow/runtime/split_multifasta/" . $pipeline->id . "_default/split_multifasta.default.user.config");
$split_multifasta_config->setval('input', '$;INPUT_FILE$;', $input_library_file );
$split_multifasta_config->RewriteConfig();

## Btab2ViromeBtab
my $btab2viromebtab_config = new Ergatis::ConfigFile(
    -file => "$repository_root/workflow/runtime/btab2viromebtab/" . $pipeline->id . "_default/btab2viromebtab.default.user.config");
$btab2viromebtab_config->setval('output', '$;OUTPUT_FILE$;', $output_library_file );
$btab2viromebtab_config->RewriteConfig();

## Get ready to rumble . . .

my $ergatis_cfg = new Ergatis::ConfigFile( -file => $ergatis_ini );

$pipeline->run( ergatis_cfg => $ergatis_cfg );


##############################
##############################


exit(0);
