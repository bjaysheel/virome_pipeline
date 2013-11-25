#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#--------------------------------------------------------------------------------------
# program name:   proktigr2chado.pl
# authors:        Jay Sundaram
# date:
# date modified:  2003/10/24 - -r to override ENV{OUTPUT_DIR}
#
# Purpose:        To migrate the prokaryotic organisms from legacy prok database
#                 schema into the chado unified data model (whereby, prok data is 
#                 pushed into euk style data model)
#
#
# modifications: 2004-02-17 post merge adjustments
#                1) removed verbose, autoload options
#                2) out_dir -> renamed outdir
#                3) introduced Coati::Logger (log4perl and debug_level)
#
#
#
#---------------------------------------------------------------------------------------
=head1 NAME

proktigr2chado.pl - Migrates legacy prok data into Chado schema

=head1 SYNOPSIS

USAGE:  proktigr2chado.pl -U username -P password -D source_database -t target_database [-a asmbl_id_list] [-F asmbl_file] [-f] [-l log4perl] [-d debug_level] [-h] [-m] [-r outdir]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--source_database,-D>
    
    Source database name

=item B<--target_database,-t>
    
    Destination database name

=item B<--asmbl_id_list,-a>
    
    Comma-separated list of assembly identifiers

=item B<--asmbl_file,-F>
    
    File containing newline separated list of assembly identifiers

=item B<--debug_level,-d>
    
    Coati::Logger log4perl logging/debugging level.  Default is 0

=item B<--log4perl,-l>
    
    Coati::Logger log4perl log file.  Default is /tmp/proktigr2chado.pl.log

=item B<--help,-h>

    Print this help

=item B<--man,-m>

    Display pod2usage man pages for this script

=item B<--outdir,-r>

    Output directory for .out tab delimited files

=back

=head1 DESCRIPTION

    proktigr2chado.pl - Migrates legacy prok data into Chado schema

=cut

use strict;
use lib "shared";
use lib "Chado";
use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Digest::MD5 qw(md5);
use Config::IniFiles;
use Coati::Logger;
use Benchmark;

#------------------------------------------------------------------
# Parse command line options
#
#------------------------------------------------------------------


my ($username, $password, $source_database, $target_database, $debug_level, $log4perl, $help, $man, $asmbl_id_list, $asmbl_file, $outdir);


my $results = GetOptions (
			  'username|U=s'              => \$username, 
			  'password|P=s'              => \$password,
			  'source_database|D=s'       => \$source_database,
			  'target_database|t=s'       => \$target_database,
			  'debug_level|d=s'           => \$debug_level,
			  'log4perl|l=s'               => \$log4perl,
			  'help|h'                    => \$help,
			  'man|m'                     => \$man,
			  'asmbl_id_list|a=s'         => \$asmbl_id_list,
			  'asmbl_file|F=s'            => \$asmbl_file,
			  'outdir|r=s'                => \$outdir,
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("username was not defined\n") if (!$username);
print STDERR ("password was not defined\n") if (!$password);
print STDERR ("target_database was not defined\n") if (!$target_database);
print STDERR ("source_database was not defined\n") if (!$source_database);

&print_usage if(!$username or !$password or !$target_database or !$source_database);


#
# initialize the logger
#
$log4perl = "/tmp/proktigr2chado.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


#
# verify and set the output directory
#
$outdir = &verify_and_set_outdir($outdir);



my $list_of_asmbl_ids;
my $asmbl_id_list_ref;
my @asmbl_ids;
my $asmbl_id_string_list_ref;
#--------------------------------------------------------
# Get the asmbl_id list reference
#--------------------------------------------------------
if (($asmbl_id_list) and ($asmbl_id_list ne 'ALL')){
    $logger->info("List of asmbl_ids specified by user, will be processed");
    $asmbl_id_list_ref = &get_asmbl_id_list_ref($asmbl_id_list);
    $asmbl_id_string_list_ref = \$asmbl_id_list;
}
elsif (($asmbl_id_list) and ($asmbl_id_list eq 'ALL')){
    $logger->info("All asmbl_ids for the organism will be processed");
    $asmbl_id_list_ref = "ALL";
    $asmbl_id_string_list_ref = \$asmbl_id_list;
}
elsif ($asmbl_file){
    $logger->info("File containing list of asmbl_ids specified by user, will be processed");
    ($asmbl_id_list_ref, $asmbl_id_string_list_ref) = &get_asmbl_id_list_from_file(\$asmbl_file);
}
else{
    $logger->logdie("You must either specify asmbl_id_list OR asmbl_file");
    &print_usage();
}

#
# Instantiate new Prism reader object
#
my $t2creader = &retrieve_prism_reader($username, $password, $source_database);

#
# Instantiate new Prism writer object
#
my $t2cwriter = &retrieve_prism_writer($username, $password, $target_database);

#
# retrieve sybase time stamp
#
my $sybase_time = &retrieve_sybase_time();

#
# retrieve cvterm id lookup
#
my $cvterm_ids = &retrieve_cvterm_ids($t2cwriter);


#
# retrieve db id lookup
#
my $db_id_hashref = &retrieve_db_id_hashref($t2cwriter);

#
# retrieve organism id lookup
#
my $organism_id_hashref = &retrieve_organism_id_hashref($t2cwriter);


#----------------------------------------------------------
# Prepare to migrate the 
# a) assembly related data
# b) subfeature data
#
#----------------------------------------------------------
my $database_prefix = "TIGR_prok";
my $org_type_is_euk = 0;

$logger->info("Migrating assembly data");
my ($organism_id, $new_asmbl_id_list_ref) = &migrate_assembly_data(
								   t2creader           => $t2creader,
								   t2cwriter           => $t2cwriter,
								   cvterm_ids          => $cvterm_ids,
								   sybase_time         => $sybase_time,
								   db_id_hashref       => $db_id_hashref,
								   organism_id_hashref => $organism_id_hashref,
								   database_prefix     => $database_prefix,
								   org_type_is_euk     => $org_type_is_euk,
								   asmbl_id_list_ref   => $asmbl_id_list_ref
							       );



$logger->logdie("organism_id was not defined")           if (!defined($organism_id));
$logger->logdie("new_asmbl_id_list_ref was not defined") if (!defined($new_asmbl_id_list_ref));

$logger->info("Retrieving role id data");
my $role_id_lookup = &retrieve_role_id_lookup($t2creader, $new_asmbl_id_list_ref);
$logger->logdie("role_id_lookup was not defined") if (!defined($role_id_lookup));

$logger->info("Migrating sub-feature data");


&migrate_subfeature_data(
			 t2creader           => $t2creader,
			 t2cwriter           => $t2cwriter,
			 role_id_lookup      => $role_id_lookup,
			 cvterm_ids          => $cvterm_ids,
			 sybase_time         => $sybase_time,
			 db_id_hashref       => $db_id_hashref,
			 organism_id_hashref => $organism_id_hashref,
			 organism_id         => $organism_id,
			 database_prefix     => $database_prefix,
			 org_type_is_euk     => $org_type_is_euk,
			 asmbl_id_list_ref   => $new_asmbl_id_list_ref
			 );


#
# write to the tab delimited .out files
#
&write_to_outfiles($t2cwriter, $outdir);
print "\n";

$logger->info("'$0': Finished migrating data from $source_database to $target_database");
$logger->info("Please verify log4perl log file: $log4perl");
print STDERR ("Tab delimited .out files were written to $outdir\n");




#-------------------------------------------------------------------------------------------------------
# END OF MAIN  -- SUBROUTINES FOLLOW
#-------------------------------------------------------------------------------------------------------

=head2 Subroutines

=cut

=head3 migrate_assembly_data

=over 4

Migrates the assembly/genomic axis/genomic contig data

=back

=cut

#--------------------------------------------------------------------------
# sub migrate_assembly_data()
#
# migrate_assembly_to_feature() 
#
# This section will move the following data fields:
#
# 1) prok_database.assembly.asmbl_id
# 2) prok_database.assembly.sequence
# 3) prok_database.assembly.com_name
#
# The values will be passed to t2writer's do_store_sequence_data 
# function
#
# The "assembly" OR "genomic axis" OR "genomic contig" data is moved from
# the prok_database.assembly table.
# migrate_assembly_data() should populate the following chado tables:
# 1) feature            
# 2) dbxref
# 3) feature_dbxref
# 4) organism
# 5) featureprop
#---------------------------------------------------------------------------
sub migrate_assembly_data{

    $logger->debug("Entered migrate_assembly_data") if $logger->is_debug();

    my $warn_flag =0;

    my(%parameter) = @_;
    my $parameter_hash = \%parameter;

    my $t2creader;
    my $t2cwriter;
    my $sybase_time;
    my $cvterm_ids;
    my $db_id_hashref;
    my $organism_id_hashref;
    my $database_prefix;
    my $org_type_is_euk;
    my $asmbl_id_list_ref;

    #--------------------------------------------------
    # Extract parameters from parameter hash
    #
    #--------------------------------------------------
    $t2creader           = $parameter_hash->{'t2creader'}           if ((exists $parameter_hash->{'t2creader'})           and (defined($parameter_hash->{'t2creader'})));
    $t2cwriter           = $parameter_hash->{'t2cwriter'}           if ((exists $parameter_hash->{'t2cwriter'})           and (defined($parameter_hash->{'t2cwriter'})));
    $sybase_time         = $parameter_hash->{'sybase_time'}         if ((exists $parameter_hash->{'sybase_time'})         and (defined($parameter_hash->{'sybase_time'})));
    $cvterm_ids          = $parameter_hash->{'cvterm_ids'}          if ((exists $parameter_hash->{'cvterm_ids'})          and (defined($parameter_hash->{'cvterm_ids'})));
    $db_id_hashref       = $parameter_hash->{'db_id_hashref'}       if ((exists $parameter_hash->{'db_id_hashref'})       and (defined($parameter_hash->{'db_id_hashref'})));
    $organism_id_hashref = $parameter_hash->{'organism_id_hashref'} if ((exists $parameter_hash->{'organism_id_hashref'}) and (defined($parameter_hash->{'organism_id_hashref'})));
    $database_prefix     = $parameter_hash->{'database_prefix'}     if ((exists $parameter_hash->{'database_prefix'})     and (defined($parameter_hash->{'database_prefix'})));
    $org_type_is_euk     = $parameter_hash->{'org_type_is_euk'}     if ((exists $parameter_hash->{'org_type_is_euk'})     and (defined($parameter_hash->{'org_type_is_euk'})));
    $asmbl_id_list_ref   = $parameter_hash->{'asmbl_id_list_ref'}   if ((exists $parameter_hash->{'asmbl_id_list_ref'})   and (defined($parameter_hash->{'asmbl_id_list_ref'})));

    #--------------------------------------------------
    # Verify whether parameters were defined
    #
    #--------------------------------------------------
    $logger->logdie("t2creader was not defined")           if (!defined($t2creader));
    $logger->logdie("t2cwriter was not defined")           if (!defined($t2cwriter));
    $logger->logdie("sybase_time was not defined")         if (!defined($sybase_time));
    $logger->logdie("cvterm_ids was not defined")          if (!defined($cvterm_ids));
    $logger->logdie("db_id_hashref was not defined")       if (!defined($db_id_hashref));
    $logger->logdie("organism_id_hashref was not defined") if (!defined($organism_id_hashref));
    $logger->logdie("database_prefix was not defined")     if (!defined($database_prefix));
    $logger->logdie("org_type_is_euk was not defined")     if (!defined($org_type_is_euk));
    $logger->logdie("asmbl_id_list_ref was not defined")   if (!defined($asmbl_id_list_ref));
    

    #-------------------------------------------------------------------------
    # retrieve the assembly data
    # query submitted:
    # SELECT a.asmbl_id,a.sequence,a.com_name,'','','',''
    # FROM assembly a, stan s
    # WHERE a.asmbl_id = s.asmbl_id and s.iscurrent = 1
    #-------------------------------------------------------------------------

    my ($tigr_assembly) = $t2creader->prok_assembly_data($asmbl_id_list_ref);
    $logger->logdie("tigr_assembly was not defined") if (!defined($tigr_assembly));
    

    if ($tigr_assembly->{'count'}<1){
	my $asslist = join(',', @$asmbl_id_list_ref);
	$logger->logdie("\n\nNone of your specified assemblies:\n$asslist\nwere found to have \"current\" status in the stan table...\nTherefore, no assemblies were be processed\nExiting $0\n\n");
	exit(0);
    }


    my @retrieved_asmbl_ids;
    for (my $i=0;$i<$tigr_assembly->{'count'};$i++){
	push (@retrieved_asmbl_ids, $tigr_assembly->{$i}->{'asmbl_id'});
    }
    my @ids;
    
    $asmbl_id_list_ref = \@retrieved_asmbl_ids;
    
    foreach my $id (sort {$a <=> $b} @{$asmbl_id_list_ref}){#(sort @retrieved_asmbl_ids){
	push (@ids, $id);
    }
    $asmbl_id_list_ref = \@ids;


    #-------------------------------------------------------------------------
    # retrieve the organism data
    # query submitted:
    # SELECT g.file_moniker, g.name, np.taxon_id 
    # FROM common..genomes g, new_project np
    # WHERE g.db = '$database_organism'
    #-------------------------------------------------------------------------
    my $database_organism = $t2creader->{'_db'};
    $logger->logdie("database_organism was not defined") if (!defined($database_organism));

    my $tigr_organism = $t2creader->organism_data($database_organism); 
    $logger->logdie("tigr_organism was not defined") if (!defined($tigr_organism));
    
    $logger->debug("tigr_organism:")       if $logger->is_debug();
    $logger->debug(Dumper($tigr_organism)) if $logger->is_debug();

    #-------------------------------------
    # print progress related code
    #-------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = $tigr_assembly->{'count'};
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);

    printf "%-50s   %-12s     0%", qq!Migrating assemblies:!, "[". " "x$bars . "]";

    #------------------------------------
    # write the organism data
    #------------------------------------
    my $organism_id = $t2cwriter->store_organism_data(
						      organism_name       => $tigr_organism->{'name'},
						      file_moniker        => $tigr_organism->{'file_moniker'},
						      taxon_id            => $tigr_organism->{'taxon_id'},
						      organism_database   => $t2creader->{'_db'},
						      asmbl_id            => $tigr_assembly->{'0'}->{'asmbl_id'},    # from prok_database.assembly.asmbl_id
						      db_id_hashref       => $db_id_hashref,
						      organism_id_hashref => $organism_id_hashref,
						      database_prefix     => $database_prefix,
						      org_type_is_euk     => $org_type_is_euk
						      );
    $logger->logdie("organism_id was not defined") if (!defined($organism_id));

    #
    # Extract the necessary cvterm ids
    #
    my ($assembly_cvterm_id, $assembly_name_cvterm_id, $chromosome_cvterm_id);
    $assembly_cvterm_id      = $cvterm_ids->{'assembly_cvterm_id'}      if ((exists $cvterm_ids->{'assembly_cvterm_id'})      and (defined($cvterm_ids->{'assembly_cvterm_id'})));
    $assembly_name_cvterm_id = $cvterm_ids->{'assembly_name_cvterm_id'} if ((exists $cvterm_ids->{'assembly_name_cvterm_id'}) and (defined($cvterm_ids->{'assembly_name_cvterm_id'})));
    $chromosome_cvterm_id    = $cvterm_ids->{'chromosome_cvterm_id'}    if ((exists $cvterm_ids->{'chromosome_cvterm_id'})    and (defined($cvterm_ids->{'chromosome_cvterm_id'})));


    #------------------------------------
    # write the assembly data
    #------------------------------------
    for(my $i=0;$i<$tigr_assembly->{'count'};$i++){
	$t2cwriter->store_assembly_data(
					asmbl_id                => $tigr_assembly->{$i}->{'asmbl_id'},    # from prok_database.assembly.asmbl_id
					sequence                => $tigr_assembly->{$i}->{'sequence'},    # from prok_database.assembly.sequence
					clone_name              => $tigr_assembly->{$i}->{'clone_name'},        # from prok_database.assembly.com_name
					gb_acc                  => undef, #"", $tigr_assembly->{$i}->{'gb_acc'},
					chromosome              => undef, #"", $tigr_assembly->{$i}->{'chromosome'},
					is_public               => undef, #"", $tigr_assembly->{$i}->{'is_public'},
					ed_date                 => $tigr_assembly->{$i}->{'ed_date'},       # 
					name                    => $tigr_organism->{'name'},                #
					database                => $t2creader->{'_db'},                     # contains name of database eg. 'gbs'
					org_type_is_euk         => $org_type_is_euk,
					assembly_cvterm_id      => $assembly_cvterm_id,
					assembly_name_cvterm_id => $assembly_name_cvterm_id,
					chromosome_cvterm_id    => $chromosome_cvterm_id,
					sybase_time             => $sybase_time,
					db_id_hashref           => $db_id_hashref,
					organism_id_hashref     => $organism_id_hashref,
					organism_id             => $organism_id,
					database_prefix         => $database_prefix
					);

	my $assembly_count = $i+1;
	&show_progress("Assembly #$assembly_count",$counter,++$row_count,$bars,$total_rows);
    }
#    print ("\tnumber of assembly records migrated: $tigr_assembly->{'count'}\n");
    print ("\n");


    return ($organism_id, $asmbl_id_list_ref);
}


=head3 migrate_subfeature_data

=over 4

Migrates the ORF and protein related data

=back
    
=cut
#----------------------------------------------------------------------------------------
# sub migrate_subfeature_data()
#
# This subroutine will migrate the TranscriptionalUnit, CodingDomainSequence and
# the exon features from the legacy database into the chado database
#
# Transcriptional Unit   (TU)  store_transcript()      for transcripts and genes
# Coding Domain Sequence (CDS) store_coding_regions()  for CDS' and proteins
# Exon                         store_exons()           for exons
#
#----------------------------------------------------------------------------------------
sub migrate_subfeature_data{

    $logger->debug("Entered migrate_subfeature_data") if $logger->is_debug();

    my $warn_flag = 0;
  
    my (%parameter) = @_;
    my $parameter_hash = \%parameter;
    my $t2creader;
    my $t2cwriter;
    my $role_id_lookup;
    my $sybase_time;
    my $cvterm_ids;
    my $db_id_hashref;
    my $organism_id_hashref;
    my $organism_id;
    my $database_prefix;
    my $org_type_is_euk;
    my $asmbl_id_list_ref;

    #------------------------------------------------------------
    # Extract arguments from parameter hash
    #
    #------------------------------------------------------------
    $t2creader           = $parameter_hash->{'t2creader'}           if ((exists $parameter_hash->{'t2creader'})           and (defined($parameter_hash->{'t2creader'})));
    $t2cwriter           = $parameter_hash->{'t2cwriter'}           if ((exists $parameter_hash->{'t2cwriter'})           and (defined($parameter_hash->{'t2cwriter'})));
    $role_id_lookup      = $parameter_hash->{'role_id_lookup'}      if ((exists $parameter_hash->{'role_id_lookup'})      and (defined($parameter_hash->{'role_id_lookup'})));
    $sybase_time         = $parameter_hash->{'sybase_time'}         if ((exists $parameter_hash->{'sybase_time'})         and (defined($parameter_hash->{'sybase_time'})));
    $cvterm_ids          = $parameter_hash->{'cvterm_ids'}          if ((exists $parameter_hash->{'cvterm_ids'})          and (defined($parameter_hash->{'cvterm_ids'})));
    $db_id_hashref       = $parameter_hash->{'db_id_hashref'}       if ((exists $parameter_hash->{'db_id_hashref'})       and (defined($parameter_hash->{'db_id_hashref'})));
    $organism_id_hashref = $parameter_hash->{'organism_id_hashref'} if ((exists $parameter_hash->{'organism_id_hashref'}) and (defined($parameter_hash->{'organism_id_hashref'})));
    $organism_id         = $parameter_hash->{'organism_id'}         if ((exists $parameter_hash->{'organism_id'})         and (defined($parameter_hash->{'organism_id'})));
    $database_prefix     = $parameter_hash->{'database_prefix'}     if ((exists $parameter_hash->{'database_prefix'})     and (defined($parameter_hash->{'database_prefix'})));
    $org_type_is_euk     = $parameter_hash->{'org_type_is_euk'}     if ((exists $parameter_hash->{'org_type_is_euk'})     and (defined($parameter_hash->{'org_type_is_euk'})));
    $asmbl_id_list_ref   = $parameter_hash->{'asmbl_id_list_ref'}   if ((exists $parameter_hash->{'asmbl_id_list_ref'})   and (defined($parameter_hash->{'asmbl_id_list_ref'})));

    #------------------------------------------------------------
    # Verify whether arguments were defined
    #
    #------------------------------------------------------------
    $logger->logdie("t2creader was not defined")           if (!defined($t2creader));
    $logger->logdie("t2cwriter was not defined")           if (!defined($t2cwriter));
    $logger->logdie("role_id_lookup was not defined")      if (!defined($role_id_lookup));
    $logger->logdie("sybase_time not defined")             if (!defined($sybase_time));
    $logger->logdie("cvterm_ids was not defined")          if (!defined($cvterm_ids));
    $logger->logdie("db_id_hashref was not defined")       if (!defined($db_id_hashref));
    $logger->logdie("organism_id_hashref was not defined") if (!defined($organism_id_hashref));
    $logger->logdie("organism_id was not defined")         if (!defined($organism_id));
    $logger->logdie("database_prefix was not defined")     if (!defined($database_prefix));
    $logger->logdie("org_type_is_euk was not defined")     if (!defined($org_type_is_euk));
    $logger->logdie("asmbl_id_list_ref was not defined")   if (!defined($asmbl_id_list_ref));



    $logger->debug("Assembly identifiers to be processed:\n" . Dumper $asmbl_id_list_ref) if $logger->is_debug;

    #----------------------------------
    # retrieve ORF related data
    #----------------------------------
    my $tigr_orf_data = $t2creader->subfeature_data($asmbl_id_list_ref);

    $logger->logdie("tigr_org_data was not defined") if (!defined($tigr_orf_data));

    return undef if ($tigr_orf_data eq 'none');


    #----------------------------------
    # progress related code
    #----------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = $tigr_orf_data->{'count'};
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);
    					     
    printf "%-50s   %-12s     0%", qq!Copying "Migrating ORFs":!, "[". " "x$bars . "]";

    #------------------------------------------------------------
    # store ORF related data in transcript and gene data model
    #------------------------------------------------------------
    my $orf_count = $tigr_orf_data->{'count'};
    $logger->logdie("orf_count was not defined") if (!defined($orf_count));



    #
    # Extract all the neccessary cvterm_ids
    #
    my ($transcript_cvterm_id, $part_of_cvterm_id, $gene_cvterm_id, $assembly_cvterm_id, $produced_by_cvterm_id);
    my ($gene_product_name_cvterm_id, $tigr_role_cvterm_id, $protein_cvterm_id, $cds_cvterm_id, $exon_cvterm_id);

    $transcript_cvterm_id        = $cvterm_ids->{'transcript_cvterm_id'}        if ((exists $cvterm_ids->{'transcript_cvterm_id'})         and (defined($cvterm_ids->{'transcript_cvterm_id'})));
    $part_of_cvterm_id           = $cvterm_ids->{'part_of_cvterm_id'}           if ((exists $cvterm_ids->{'part_of_cvterm_id'})            and (defined($cvterm_ids->{'part_of_cvterm_id'})));
    $gene_cvterm_id              = $cvterm_ids->{'gene_cvterm_id'}              if ((exists $cvterm_ids->{'gene_cvterm_id'})               and (defined($cvterm_ids->{'gene_cvterm_id'})));
    $assembly_cvterm_id          = $cvterm_ids->{'assembly_cvterm_id'}          if ((exists $cvterm_ids->{'assembly_cvterm_id'})           and (defined($cvterm_ids->{'assembly_cvterm_id'})));
    $produced_by_cvterm_id       = $cvterm_ids->{'produced_by_cvterm_id'}       if ((exists $cvterm_ids->{'produced_by_cvterm_id'})        and (defined($cvterm_ids->{'produced_by_cvterm_id'})));
    $gene_product_name_cvterm_id = $cvterm_ids->{'gene_product_name_cvterm_id'} if ((exists $cvterm_ids->{'gene_product_name_cvterm_id'})  and (defined($cvterm_ids->{'gene_product_name_cvterm_id'})));
    $tigr_role_cvterm_id         = $cvterm_ids->{'tigr_role_cvterm_id'}         if ((exists $cvterm_ids->{'tigr_role_cvterm_id'})          and (defined($cvterm_ids->{'tigr_role_cvterm_id'})));
    $protein_cvterm_id           = $cvterm_ids->{'protein_cvterm_id'}           if ((exists $cvterm_ids->{'protein_cvterm_id'})            and (defined($cvterm_ids->{'protein_cvterm_id'})));
    $cds_cvterm_id               = $cvterm_ids->{'cds_cvterm_id'}               if ((exists $cvterm_ids->{'cds_cvterm_id'})                and (defined($cvterm_ids->{'cds_cvterm_id'})));
    $exon_cvterm_id              = $cvterm_ids->{'exon_cvterm_id'}              if ((exists $cvterm_ids->{'exon_cvterm_id'})               and (defined($cvterm_ids->{'exon_cvterm_id'})));
    $exon_cvterm_id              = $cvterm_ids->{'org_type_is_euk'}             if ((exists $cvterm_ids->{'org_type_is_euk'})              and (defined($cvterm_ids->{'org_type_is_euk'})));
    

    
    for(my $i=0;$i<$orf_count;$i++){


	my $feat_name;
	my $role_id_array;
	if (! exists $tigr_orf_data->{$i}->{'feat_name'}){
	    $logger->logdie("feat_name does not exist i = $i");
	}
	else {
	    $feat_name = $tigr_orf_data->{$i}->{'feat_name'};
	    if (!defined($feat_name)){
		$logger->fatal(Dumper $tigr_orf_data->{$i});
		$logger->logdie("feat_name was not defined for i:$i of orf_count:$orf_count");
	    }
	    $role_id_array  = $role_id_lookup->{$feat_name}; 
	}

	#
	# Store the transcriptional unit (TU) related data (transcripts and genes)
	# in the chado database
	#
	$t2cwriter->store_transcripts(
				      feat_name                   => $feat_name,                           # asm_feature.asmbl_id
				      asmbl_id                    => $tigr_orf_data->{$i}->{'asmbl_id'},   # asm_feature.asmbl_id
				      end5                        => $tigr_orf_data->{$i}->{'end5'},       # asm_feature.end5
				      end3                        => $tigr_orf_data->{$i}->{'end3'},       # asm_feature.end3
				      sequence                    => $tigr_orf_data->{$i}->{'sequence'},   # feature.sequence for transcript and gene types is set to empty field
				      locus                       => $tigr_orf_data->{$i}->{'locus'},      # ident.locus
				      com_name                    => $tigr_orf_data->{$i}->{'com_name'},   # ident.com_name
				      date                        => $tigr_orf_data->{$i}->{'date'},       # asm_feature.date
				      database                    => $t2creader->{'_db'},                  # database
				      role_id_lookup              => $role_id_array,
				      org_type_is_euk             => $org_type_is_euk,
				      transcript_cvterm_id        => $transcript_cvterm_id,
				      part_of_cvterm_id           => $part_of_cvterm_id,
				      gene_cvterm_id              => $gene_cvterm_id,
				      assembly_cvterm_id          => $assembly_cvterm_id,
				      derived_from_cvterm_id       => $produced_by_cvterm_id,
				      gene_product_name_cvterm_id => $gene_product_name_cvterm_id,
				      tigr_role_cvterm_id         => $tigr_role_cvterm_id,
				      sybase_time                 => $sybase_time,
				      db_id_hashref               => $db_id_hashref,
				      organism_id_hashref         => $organism_id_hashref,
				      organism_id                 => $organism_id,
				      database_prefix             => $database_prefix
				      );
	
	my $trans_ctr = $i+1;
	&show_progress("ORF #$trans_ctr as transcripts",$counter,++$row_count,$bars,$total_rows);
    }

    print ("\n");
    #----------------------------------
    # progress related code
    #----------------------------------
    $row_count = 0;
    $bars = 30;
    $total_rows = $tigr_orf_data->{'count'};
    $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);
    					     
    printf "%-50s   %-12s     0%", qq!Copying "Migrating coding regions":!, "[". " "x$bars . "]";

    #------------------------------------------------------------
    # store ORF related code in CDS and protein data model
    #------------------------------------------------------------

    #
    # Store the Coding domain sequence (CDS) related data (CDS and proteins)
    # in the chado database
    #
    for(my $i=0;$i<$orf_count;$i++){

	$t2cwriter->store_coding_regions(
					 parent_feat           => $tigr_orf_data->{$i}->{'feat_name'},  #
					 asmbl_id              => $tigr_orf_data->{$i}->{'asmbl_id'},   # asm_feature.asmbl_id
					 feat_name             => $tigr_orf_data->{$i}->{'feat_name'},  #
					 end5                  => $tigr_orf_data->{$i}->{'end5'},       # asm_feature.end5
					 end3                  => $tigr_orf_data->{$i}->{'end3'},       # asm_feature.end3
					 sequence              => $tigr_orf_data->{$i}->{'sequence'},   # asm_feature.sequence
					 protein               => $tigr_orf_data->{$i}->{'protein'},    # asm_feature.protein
					 date                  => $tigr_orf_data->{$i}->{'date'},       # asm_feature.date
					 locus                 => $tigr_orf_data->{$i}->{'locus'},      # ident.locus
					 database              => $t2creader->{'_db'},                  # database
					 org_type_is_euk       => $org_type_is_euk,
					 transcript_cvterm_id  => $transcript_cvterm_id,
					 protein_cvterm_id     => $protein_cvterm_id,
					 cds_cvterm_id         => $cds_cvterm_id,
					 assembly_cvterm_id    => $assembly_cvterm_id,
					 derived_from_cvterm_id => $produced_by_cvterm_id,
					 sybase_time           => $sybase_time,
					 db_id_hashref         => $db_id_hashref,
					 organism_id_hashref   => $organism_id_hashref,
					 organism_id           => $organism_id,
					 database_prefix       => $database_prefix,
					 );
	
	my $cds_ctr = $i+1;
	&show_progress("ORF #$cds_ctr as coding regions",$counter,++$row_count,$bars,$total_rows);
    }
    print ("\n");

    #----------------------------------
    # progress related code
    #----------------------------------
    $row_count = 0;
    $bars = 30;
    $total_rows = $tigr_orf_data->{'count'};
    $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);
    					     
    printf "%-50s   %-12s     0%", qq!Copying "Migrating exons":!, "[". " "x$bars . "]";

    #------------------------------------------------------------
    # store ORF related code in exon data model
    #------------------------------------------------------------

    my $exon2transcript_rank = {};
    #
    # Store the exon data in the chado database
    #
    for(my $i=0;$i<$orf_count;$i++){


	#
	# Bugzilla case 1262
	# Store relative rank info for exon to transcript
	#
	$exon2transcript_rank->{$tigr_orf_data->{$i}->{'feat_name'}}++;


	$t2cwriter->store_exons(
				parent_feat          => $tigr_orf_data->{$i}->{'feat_name'},   # asm_feature.end5
				tu_feat_name         => $tigr_orf_data->{$i}->{'feat_name'},   # asm_feature.end5
				feat_name            => $tigr_orf_data->{$i}->{'feat_name'},   # asm_feature.end5
				end5                 => $tigr_orf_data->{$i}->{'end5'},        # asm_feature.end5
				end3                 => $tigr_orf_data->{$i}->{'end3'},        # asm_feature.end3
				date                 => $tigr_orf_data->{$i}->{'date'},        # asm_feature.date
				asmbl_id             => $tigr_orf_data->{$i}->{'asmbl_id'},    # asm_feature.asmbl_id
				database             => $t2creader->{'_db'},                   # database
				locus                => $tigr_orf_data->{$i}->{'locus'},       # ident.locus
				org_type_is_euk      => $org_type_is_euk,
				exon_cvterm_id       => $exon_cvterm_id,
				part_of_cvterm_id    => $part_of_cvterm_id,
				assembly_cvterm_id   => $assembly_cvterm_id,
				transcript_cvterm_id => $transcript_cvterm_id,
				sybase_time          => $sybase_time,
				db_id_hashref        => $db_id_hashref,
				organism_id_hashref  => $organism_id_hashref,
				organism_id          => $organism_id,
				database_prefix      => $database_prefix,
				rank                 => $exon2transcript_rank->{$tigr_orf_data->{$i}->{'feat_name'}},
				);
	
	my $exon_ctr = $i+1;
	&show_progress("ORF #$exon_ctr as exons",$counter,++$row_count,$bars,$total_rows);
    }
    print ("\n");    
    
    print ("Number of ORF records migrated: $tigr_orf_data->{'count'}\n");

}




#---------------------------------------------------------------
# retrieve_role_id_lookup()
#
#
#
#---------------------------------------------------------------
sub retrieve_role_id_lookup {
    
    $logger->debug("Entered retrieve_role_id_lookup") if $logger->is_debug();

    my ($t2creader, $asmbl_id_list_ref) = @_;

    $logger->logdie("t2creader was not defined") if (!defined($t2creader));
    $logger->logdie("asmbl_id_list_ref was not defined") if (!defined($asmbl_id_list_ref));

    #---------------------------------------
    # Retrieve role info from database
    #
    #---------------------------------------
    my $role_lookup = $t2creader->role_id_lookup($asmbl_id_list_ref);
    $logger->logdie("role_lookup was not defined") if (!defined($role_lookup));
    
    my $role_id_lookup = {};
    
    my $role_count = scalar(@$role_lookup);

    $logger->debug("role_count:$role_count") if $logger->is_debug();
    
    #----------------------------------------
    # New datastructure
    #
    #----------------------------------------
    for (my $j=0;$j<$role_count;$j++){
	

	my ($feat_name, $role_id);
	if (exists $role_lookup->[$j]->{'feat_name'}){
	    $feat_name = $role_lookup->[$j]->{'feat_name'};
	}
	if (exists $role_lookup->[$j]->{'role_id'}){
	    $role_id = $role_lookup->[$j]->{'role_id'};
	    if ($role_id !~ /^\d+$/){
		print Dumper $role_id;
		$logger->logdie("role_id:$role_id was not a digit");
	    }
	}

	if ((defined($feat_name)) && (defined($role_id))){
	    push(@{$role_id_lookup->{$feat_name}}, $role_id);
	}
	else {
	    $logger->logdie("feat_name:$feat_name and role_id:$role_id pair were not loaded");
	}
    }	
    

    $logger->debug("role_id_lookup:")       if $logger->is_debug();
    $logger->debug(Dumper($role_id_lookup)) if $logger->is_debug();
    
    return $role_id_lookup;
}#end sub retrieve_role_id_lookup
    
#-----------------------------------------------------------------
# retrieve_cvterm_ids()
#
#
#-----------------------------------------------------------------
sub retrieve_cvterm_ids {

    $logger->debug("Entered retrieve_cvterm_ids") if $logger->is_debug();

    my $t2cwriter = shift;
    $logger->logdie("t2cwriter was not defined") if (!defined($t2cwriter));
    
    my $transcript_cvterm_id        = $t2cwriter->cvterm_id("transcript");
    my $part_of_cvterm_id           = $t2cwriter->cvterm_id("part_of");
    my $gene_cvterm_id              = $t2cwriter->cvterm_id("gene");
    my $assembly_cvterm_id          = $t2cwriter->cvterm_id("assembly");
    my $produced_by_cvterm_id       = $t2cwriter->cvterm_id("produced_by");
    my $gene_product_name_cvterm_id = $t2cwriter->cvterm_id("gene product name");
    my $tigr_role_cvterm_id         = $t2cwriter->cvterm_id("TIGR_role");
    my $protein_cvterm_id           = $t2cwriter->cvterm_id("protein");
    my $cds_cvterm_id               = $t2cwriter->cvterm_id("CDS");
    my $exon_cvterm_id              = $t2cwriter->cvterm_id("exon");
    my $assembly_name_cvterm_id     = $t2cwriter->cvterm_id("assembly name");
    my $chromosome_cvterm_id        = $t2cwriter->cvterm_id("chromosome");

    $logger->logdie("transcript_cvterm_id was not defined")        if (!defined($transcript_cvterm_id));
    $logger->logdie("part_of_cvterm_id was not defined")           if (!defined($part_of_cvterm_id));
    $logger->logdie("gene_cvterm_id was not defined")              if (!defined($gene_cvterm_id));
    $logger->logdie("assembly_cvterm_id was not defined")          if (!defined($assembly_cvterm_id));
    $logger->logdie("produced_by_cvterm_id was not defined")       if (!defined($produced_by_cvterm_id));
    $logger->logdie("gene_product_name_cvterm_id was not defined") if (!defined($gene_product_name_cvterm_id));
    $logger->logdie("tigr_role_cvterm_id was not defined")         if (!defined($tigr_role_cvterm_id));
    $logger->logdie("protein_cvterm_id was not defined")           if (!defined($protein_cvterm_id));
    $logger->logdie("cds_cvterm_id was not defined")               if (!defined($cds_cvterm_id));
    $logger->logdie("exon_cvterm_id was not defined")              if (!defined($exon_cvterm_id));
    $logger->logdie("assembly_name_cvterm_id was not defined")     if (!defined($assembly_name_cvterm_id));
    $logger->logdie("chromosome_cvterm_id was not defined")        if (!defined($chromosome_cvterm_id));
    
    my $cvterm_ids = {};
    
    $cvterm_ids->{'transcript_cvterm_id'}        = $transcript_cvterm_id;
    $cvterm_ids->{'part_of_cvterm_id'}           = $part_of_cvterm_id;
    $cvterm_ids->{'gene_cvterm_id'}              = $gene_cvterm_id;
    $cvterm_ids->{'assembly_cvterm_id'}          = $assembly_cvterm_id;
    $cvterm_ids->{'produced_by_cvterm_id'}       = $produced_by_cvterm_id;
    $cvterm_ids->{'gene_product_name_cvterm_id'} = $gene_product_name_cvterm_id;
    $cvterm_ids->{'tigr_role_cvterm_id'}         = $tigr_role_cvterm_id;
    $cvterm_ids->{'protein_cvterm_id'}           = $protein_cvterm_id;
    $cvterm_ids->{'cds_cvterm_id'}               = $cds_cvterm_id;
    $cvterm_ids->{'exon_cvterm_id'}              = $exon_cvterm_id;
    $cvterm_ids->{'assembly_name_cvterm_id'}     = $assembly_name_cvterm_id;
    $cvterm_ids->{'chromosome_cvterm_id'}        = $chromosome_cvterm_id;


    $logger->debug("cvterms retrieved:\n". Dumper $cvterm_ids) if $logger->is_debug;

    return $cvterm_ids;

}#end sub retrieve_cvterm_ids()




#------------------------------------------------------------------------------------------
# show_progress()
#
#
#
#------------------------------------------------------------------------------------------
sub show_progress{
    my($table_name,$counter,$row_count,$bars,$total_rows) = @_;
    my($percent);
    if (($row_count % $counter == 0) or ($row_count == $total_rows)) {
	$percent = int( ($row_count/$total_rows) * 100 );
	
	# $complete is the number of bars to fill in.
	my $complete = int($bars * ($percent/100));
	
	# $complete is the number of bars yet to go.
	my $incomplete = $bars - $complete;
	
	# This will backspace to before the first bracket.
	print "\b"x(62+$bars);
	printf "%-50s   %-12s   ", qq!Migrating $table_name:!, "[". "X"x$complete . " "x$incomplete . "]";
	printf "%3d%%", $percent;
    }
}



#---------------------------------------------
# retrieve_sybase_time()
#
#---------------------------------------------
sub retrieve_sybase_time {

# perl localtime   = Tue Apr  1 18:31:09 2003
# sybase getdate() = Apr  2 2003 10:15AM

    $logger->debug("Entered retrieve_sybase_time") if $logger->is_debug();


    my $datetime = localtime;
    #                  Day of Week                        Month of Year                                       Day of Month  Hour      Mins     Seconds    Year   
    if ($datetime =~ /^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)[\s]+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+([\d]{1,2})\s+([\d]{2}):([\d]{2}):[\d]{2}\s+([\d]{4})$/){
	my $hour = $4;
	my $ampm = "AM";
	if ($4 ge "13"){
	    
	    $hour = $4 - 12;
	    $ampm = "PM";
	}
    $datetime = "$2  $3 $6  $hour:$5$ampm";
}
else{
    $logger->error("Could not parse datetime");
    return;
}
 return \$datetime;

}#end sub retrieve_sybase_time()



#-----------------------------------------------------------------
# retrieve_db_id_hashref()
#
#-----------------------------------------------------------------
sub retrieve_db_id_hashref {

    $logger->debug("Entered retrieve_db_id_hashref") if $logger->is_debug();

    my $prism = shift;
    $logger->logdie("prism was not defined") if (!defined($prism));



    $logger->debug("Calling Prism::db_id_hashref") if $logger->is_debug;


    my $arrayref = $prism->db_id_hashref();
    $logger->logdie("arrayref was not defined") if (!defined($arrayref));

    my $db_id_hashref = {};

     if ($arrayref != 0){

	for (my $i=0;$i<scalar(@$arrayref);$i++){
	    my $db_id = $arrayref->[$i]->{'db_id'};
	    my $name  = $arrayref->[$i]->{'name'};
	    $logger->logdie("db_id was not defined") if (!defined($db_id));
	    $logger->logdie("name was not defined")  if (!defined($name));

	    $db_id_hashref->{$name} = $db_id;
	}
    }


    $logger->debug("Prism::db_id_hashref returned:\n" . Dumper $db_id_hashref) if $logger->is_debug;


    return $db_id_hashref;

}#end sub retrieve_db_id_hashref()

#-----------------------------------------------------------------
# retrieve_organism_id_hashref()
#
#-----------------------------------------------------------------
sub retrieve_organism_id_hashref {

    $logger->debug("Entered retrieve_organism_id_hashref") if $logger->is_debug();

    my $prism = shift;
    $logger->logdie("prism was not defined") if (!defined($prism));

    $logger->debug("Calling Prism::organism_id_hashref") if $logger->is_debug;

    my $arrayref = $prism->organism_id_hashref();
    $logger->logdie("arrayref was not defined") if (!defined($arrayref));

    my $organism_id_hashref = {};

    if ($arrayref != 0){
	for (my $i=0;$i<scalar(@$arrayref);$i++){
	    my $organism_id  = $arrayref->[$i]->{'organism_id'};
	    my $abbreviation = $arrayref->[$i]->{'abbreviation'};
	    my $genus        = $arrayref->[$i]->{'genus'};
	    my $species      = $arrayref->[$i]->{'species'};
	    $logger->logdie("organism_id was not defined")  if (!defined($organism_id));
	    $logger->logdie("abbreviation was not defined") if ((!defined($abbreviation)) and ($species ne 'cog'));
	    $logger->logdie("genus was not defined")        if (!defined($genus));
	    $logger->logdie("species was not defined")      if (!defined($species));
	    
	    my $organism_name = $genus . " " . $species;
	    
	    $organism_id_hashref->{$organism_name} = $organism_id;
	}
    }

    $logger->debug("organism_id_hashref was:\n". Dumper $organism_id_hashref) if $logger->is_debug;

    return $organism_id_hashref;

}#end sub retrieve_organism_id_hashref()


#---------------------------------------------------------------
# get_asmbl_id_list_ref()
#
#
#---------------------------------------------------------------
sub get_asmbl_id_list_ref {

    my $warn_flag = 0;

    $logger->debug("Entered get_asmbl_id_list_ref") if $logger->is_debug();

    my $list_of_asmbl_ids = shift;
    $logger->logdie("list_of_asmbl_ids was not defined") if (!defined($list_of_asmbl_ids));
    
#    print ("list_of_asmbl_ids:$list_of_asmbl_ids\n");
    #
    # Translate all of the commas into ":" colons to
    # produce a colon separated list.
    #
    $list_of_asmbl_ids =~ s/[\D]+/:/g; 
#    print ("list_of_asmbl_ids:$list_of_asmbl_ids\n");

    #
    # Now split the string at each element separator 
    # (each colon).
    #
    @asmbl_ids = split(/:/, $list_of_asmbl_ids);
    $logger->debug("List of assemble ID's to be migrated for organism $source_database:") if $logger->is_debug();
    $logger->debug("@asmbl_ids") if $logger->is_debug();

    return \@asmbl_ids;

}

#--------------------------------------------------------
# sub get_asmbl_id_list_from_file()
#
#
#--------------------------------------------------------
sub get_asmbl_id_list_from_file {

    $logger->debug("Entered get_asmbl_id_list_from_file") if $logger->is_debug();

    my $file = shift;
    $logger->logdie("file was not defined") if (!defined($file));

    my $contents = &get_contents($file);
    $logger->logdie("contents were not defined") if (!defined($contents));

    my $comma = ",";
    my $string = join ($comma, @$contents);

#    return \$string;
    return $contents, \$string;


}#end sub get_asmbl_id_list_from_file()


#--------------------------------------------------------
# get_contents()
#
#
#--------------------------------------------------------
sub get_contents {

    my $logger = Coati::Logger::get_logger("snp");
    $logger->debug("Entered get_contents") if $logger->is_debug();

    my $file = shift;
    $logger->logdie("file was not defined") if (!defined($file));

    &check_file_status($file);

    $logger->debug("Extracting contents from $$file") if $logger->is_debug();

    open (IN_FILE, "<$$file") || $logger->logdie("Could not open file: $$file for input");
    my @contents = <IN_FILE>;
    chomp @contents;

    return \@contents;


}#end sub get_contents()



#-------------------------------------------------------
#  check_file_status()
#
#
#-------------------------------------------------------
sub check_file_status {


    my $file = shift;

    $logger->debug("Entered check_file_status for $$file") if $logger->is_debug();

    $logger->logdie("file was not defined") if (!defined($file));

    $logger->logdie("$$file does not exist") if (!-e $$file);
    $logger->logdie("$$file does not have read permissions") if (!-r $$file);

}#end sub check_file_status()

#--------------------------------------------------------
# verify_and_set_outdir()
#
#
#--------------------------------------------------------
sub verify_and_set_outdir {

    my ( $outdir) = @_;

    $logger->debug("Verifying and setting output directory") if ($logger->is_debug());

    #
    # strip trailing forward slashes
    #
    $outdir =~ s/\/+$//;
    
    #
    # set to current directory if not defined
    #
    if (!defined($outdir)){
	if (!defined($ENV{'OUTPUT_DIR'})){
	    $outdir = "." 
	}
	else{
	    $outdir = $ENV{'OUTPUT_DIR'};
	}
    }

    $outdir = $outdir . '/';

    #
    # verify whether outdir is in fact a directory
    #
    $logger->fatal("$outdir is not a directory") if (!-d $outdir);

    #
    # verify whether outdir has write permissions
    #
    $logger->fatal("$outdir does not have write permissions") if ((-e $outdir) and (!-w $outdir));


    $logger->debug("outdir is set to:$outdir") if ($logger->is_debug());

    #
    # store the outdir in the environment variable
    #
    $ENV{OUTPUT_DIR} = $outdir;
    
    return $outdir;

}#end sub verify_and_set_outdir()


#----------------------------------------------------------------
# retrieve_prism_writer()
#
#
#----------------------------------------------------------------
sub retrieve_prism_writer {

    my ( $username, $password, $database) = @_;

    $logger->debug("Instantiating Prism writer") if ($logger->is_debug());
    
    my $prism = new Prism( 
			   user       => $username,
			   password   => $password,
			   db         => $database,
			   use_config => $ENV{'WRITER_CONF'},
			   );
    
    $logger->fatal("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    

    return $prism;


}#end sub retrieve_prism_writer()


#--------------------------------------------------------------
# write_to_outfiles() 
#
#
#--------------------------------------------------------------
sub write_to_outfiles {

    my ( $writer, $outdir) = @_;

    $logger->debug("Entered write_to_outfiles") if ($logger->is_debug());

    $logger->fatal("writer was not defined") if (!defined($writer));

    #
    # Output the datasets to file and/or batch load into database 
    #

    $logger->info("Writing tab delimited .out files to directory: '$outdir'");

    $writer->{_backend}->output_tables($outdir);

}#end sub write_to_outfiles()



#----------------------------------------------------------------
# retrieve_prism_reader()
#
#
#----------------------------------------------------------------
sub retrieve_prism_reader {

    my ( $username, $password, $database) = @_;

    $logger->debug("Instantiating Prism reader") if ($logger->is_debug());
    
    my $prism = new Prism( 
			   user       => $username,
			   password   => $password,
			   db         => $database,
			   );
    
    $logger->fatal("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    

    return $prism;


}#end sub retrieve_prism_reader()


#--------------------------------------------------
# print_usage()
#
#--------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -U username -P password -D source_database -t target_database [-a asmbl_id_list|ALL] [-F asmbl_file] [-l log4perl] [-d debug_level] [-h] [-m] [-r outdir]\n";
    print STDERR "  -U|--username               = Database login username\n";
    print STDERR "  -P|--password               = Database login password\n";
    print STDERR "  -D|--source_database        = Name of source database\n";
    print STDERR "  -t|--target_database        = Name of destination database\n";  
    print STDERR "  -a|--asmbl_id_list          = Optional - \"ALL\" OR comma-separated list of assembly identifiers\n";
    print STDERR "  -F|--asmbl_file             = Optional - file containing newline separated list of assembly identifiers\n";
    print STDERR "  -l|--log4perl               = Optional - Coati::Logger log4perl log file. Default is /tmp/proktigr2chado.pl.log\n";
    print STDERR "  -d|--debug_level            = Optional - Coati::Logger log4perl logging/debugging level.  Default is 0\n";
    print STDERR "  -h|--help                   = This help message\n";
    print STDERR "  -m|--man                    = Display man pages for this script\n";
    print STDERR "  -r|--outdir                 = Optional - Output directory for the tab delimited .out files\n";
    exit 1;

}

__END__

=back

=head1 ENVIRONMENT

List of environment variables here

=head1 DIAGNOSTICS

=over4

=head3 "Error message that may appear"
Explanation of error message.

=head3 "Another message that may appear"
Explanation of another error message.

=back

=head1 SEE ALSO

List of any other files or Perl modules needed by class and a brief description why.

=head1 AUTHOR(S)

The Institute for Genomic Research
9712 Medical Center Drive
Rockville, MD 20850

=head1 COPYRIGHT

Copyright (c) 2003, The Institute for Genomic Research.  All Rights Reserved.
