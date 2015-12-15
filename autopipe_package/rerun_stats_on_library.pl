#!/usr/bin/perl -w

# MANUAL FOR rerun_stats_on_library.pl

=pod

=head1 NAME

rerun_stats_on_library.pl -- Rerun the stats scripts on a library that has a db_dump.

=head1 SYNOPSIS

 rerun_stats_on_library.pl --prefix=PRF --db=diag5 --lib_info=/diag/projects/virome/output_repository/db-load-libaray/EREAFD3241/db-load-librart.txt.list
                     [--help] [--manual]

=head1 DESCRIPTION

 
=head1 OPTIONS

=over 3

=item B<-p, --prefix>=NAME

Prefix. (Required) 

=item B<-l, --lib_info>=FILENAME

The path to the library file list. (Required)

=item B<-h, --help>

Displays the usage message.  (Optional) 

=item B<-m, --manual>

Displays full manual.  (Optional) 

=back

=head1 DEPENDENCIES

Requires the following Perl libraries.

DBI

=head1 AUTHOR

Written by Daniel Nasko, 
Center for Bioinformatics and Computational Biology, University of Delaware.

=head1 REPORTING BUGS

Report bugs to dnasko@udel.edu

=head1 COPYRIGHT

Copyright 2015 Daniel Nasko.  
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.  
This is free software: you are free to change and redistribute it.  
There is NO WARRANTY, to the extent permitted by law.  

Please acknowledge author and affiliation in published work arising from this script's 
usage <http://bioinformatics.udel.edu/Core/Acknowledge>.

=cut


use strict;
use Getopt::Long;
use File::Basename;
use Pod::Usage;
use DBI;

#ARGUMENTS WITH NO DEFAULT
my($prefix,$lib_info,$db,$help,$manual);
GetOptions (
                         "p|prefix=s"   => \$prefix,
                         "l|lib_info=s" => \$lib_info,
                         "d|db=s"       => \$db,
                         "h|help"       => \$help,
                         "m|manual"     => \$manual );

# VALIDATE ARGS
pod2usage(-verbose => 2)  if ($manual);
pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} )  if ($help);
pod2usage( -msg  => "\n\n ERROR!  Required argument --prefix not found.\n\n", -exitval => 2, -verbose => 1)   if (! $prefix );
pod2usage( -msg  => "\n\n ERROR!  Required argument --lib_info not found.\n\n", -exitval => 2, -verbose => 1) if (! $lib_info );
pod2usage( -msg  => "\n\n ERROR!  Required argument --db not found.\n\n", -exitval => 2, -verbose => 1)       if (! $db );

my $db_load_file = $lib_info;
$db_load_file =~ s/.list$//;
print `sed -i 's/diag.\$/diag5/' $db_load_file`;
my $pipeline_id = $lib_info;
$pipeline_id =~ s/.*db-load-library\///;
$pipeline_id =~ s/_default.*//;

## GLOBAL VARIABLES
my $root = '/diag/projects/virome/automated_pipeline_package/';
my $instantiator_script = 'virome_rerun_stats.pl';
my $instant_dir = "/diag/projects/virome/automated_pipeline_package/ergatis/util/";
my $template_directory = "/diag/projects/virome/workflow/project_saved_templates/rerun_stats_scripts";
my $repository_root = "/diag/projects/virome/";
my $ergatis_ini = "/var/www/html/cgi/ergatis.ini";
my $id_repository = "/diag/projects/virome/workflow/project_id_repository/";


## INSTANTIATE AN ERGATIS PIPELINE
my $instantiate = "perl " . $instant_dir . $instantiator_script
    . " --template_directory=" . $template_directory 
    . " --repository_root="   . $repository_root
    . " --ergatis_ini="       . $ergatis_ini
    . " --id_repository="     . $id_repository
    . " --lib_info="          . $lib_info
    . " --database="          . $db
    . " --prefix="            . $prefix
    . " --pipeline="          . $pipeline_id
    ;
print `$instantiate`;

exit 0;
