#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#--------------------------------------------------------------------------------------
# program name:   euktigr2chado.pl
# authors:        Jay Sundaram
# date:
# date modified:  2003/04/18
#
# Purpose:        To migrate the eukaryotic organisms from legacy euk database
#                 schema into the chado schema
#
# modifications:  Jay Sundaram 2004-02-10 Bugzilla case # 1400
#                 1) If the protein string contains a trailing '*', the '*' is removed
#                    from the protein string before it is stored in chado.  The seqlen
#                    should then reflect the length of the string without the '*'
#
#                 2) If the protein string does not contain a trailing '*', the
#                    chado.featureloc.is_fmax_partial field is set to 'true' and the
#                    protein string is migrated without modification
#
#
# modifications:  Jay Sundaram 2004-02-10 post-merge clean-up/adjustments
#                 1) removed $QUERYPRINT, $debug, $logfile, $verbose
#                 2) introduced $debug_level, $log4perl
#
#
#
#
#

#---------------------------------------------------------------------------------------
=head1 NAME

euktigr2chado.pl - Migrates Euk legacy datasets to Chado schema

=head1 SYNOPSIS

USAGE:  euktigr2chado.pl -U username -P password -D source_database -t target_database -l log4perl [-a asmbl_id_list|ALL|-F asmbl_file] [-d] [-h] [-m] [-r outdir]

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
    
    User must either specify a comma-separated list of assembly ids or "ALL"

=item B<--asmbl_file,-F>
    
    Optional  - file containing list of assembly identifiers

=item B<--help,-h>

    Print this help

=item B<--man,-m>

    Display pod2usage man pages for this script

=item B<--log4perl,-l>

    Log4perl log file

=item B<--outdir,-r>

    Output directory for .out tab delimited files

=item B<--debug,-d>

    Coati debug mode - disregard



=back

=head1 DESCRIPTION

    euktigr2chado.pl - Migrates Euk legacy datasets to Chado schema

=cut

use strict;
use lib "shared";
use lib "Chado";
no strict "refs";
use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Digest::MD5 qw(md5);
use Config::IniFiles;
use Coati::Logger;
use Benchmark;


#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($source_database, $target_database, $username, $password, $debug_level, $help, $man, $log4perl, $asmbl_id_list, $asmbl_file, $outdir); 

my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'source_database|D=s' => \$source_database,
			  'target_database|t=s' => \$target_database,
			  'asmbl_id_list|a=s'   => \$asmbl_id_list,
			  'asmbl_file|F=s'      => \$asmbl_file,
			  'debug_level|d=s'     => \$debug_level,
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'log4perl|l=s'        => \$log4perl,
			  'outdir|r=s'         => \$outdir,
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);
  
print STDERR ("username was not defined\n")        if (!$username);
print STDERR ("password was not defined\n")        if (!$password);
print STDERR ("target_database was not defined\n") if (!$target_database);
print STDERR ("source_database was not defined\n") if (!$source_database);

&print_usage if(!$username or !$password or !$target_database or !$source_database);


#
# initialize the logger
#
$log4perl = "/tmp/euktigr2chado.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);


#
# verify and set the output directory
#
$outdir = &verify_and_set_outdir($outdir);

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
# retrieve db id lookup
#
my $db_id_hashref = &retrieve_db_id_hashref($t2cwriter);

#
# retrieve organism id lookup
#
my $organism_id_hashref = &retrieve_organism_id_hashref($t2cwriter);

#
# retrieve cvterm id lookup
#
my $cvterm_ids = &retrieve_cvterm_ids($t2cwriter);


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
    $asmbl_id_string_list_ref = \$asmbl_id_list_ref;
}
elsif ($asmbl_file){
    $logger->info("File containing list of asmbl_ids specified by user, will be processed");
    ($asmbl_id_list_ref, $asmbl_id_string_list_ref) = &get_asmbl_id_list_from_file(\$asmbl_file);
}    
else{
    $logger->logdie("You must specify either asmbl_id_list OR asmbl_file");
}



#
# Migrate data from legacy to chado database
#

my $organism_asmbl_id;
if ($asmbl_id_list_ref eq "ALL"){
    #
    # Migrate all asmbl_ids associated to this organism
    #
    print ("Migrating data from euk database: \"$t2creader->{_db}\" asmbl_id: \"ALL\" (on server $t2creader->{_db_hostname}) onto chado database: \"$t2cwriter->{_db}\" (on server $t2cwriter->{_db_hostname})\n");
    

    $organism_asmbl_id = "ALL";
}
else{
    #
    # Migrate only asmbl_ids specified in the asmbl_id_list_ref
    #
    print ("Migrating data from euk database: \"$t2creader->{_db}\" asmbl_id: \"$$asmbl_id_string_list_ref\" (on server $t2creader->{_db_hostname}) onto chado database: \"$t2cwriter->{_db}\" (on server $t2cwriter->{_db_hostname})\n");

    #------------------------------------------------------------------- 
    # Migrate only one "organism-related" record for the organism
    # Simply, we choose to migrate the data related to the first
    # asmbl_id in the list.
    #-------------------------------------------------------------------
    $organism_asmbl_id = $asmbl_id_list_ref->[0];
    
#    if ($$asmbl_id_list_ref =~ /^(\d+),/){
#	$organism_asmbl_id = $1;
#    }
    $logger->logdie("organism_asmbl_id was not defined") if (!defined($organism_asmbl_id));

}

my $database_prefix = "TIGR_euk";
my $org_type_is_euk = 1;

my $organism_id = &migrate_organism_data(
					 t2creader           => $t2creader,
					 t2cwriter           => $t2cwriter,
					 cvterm_ids          => $cvterm_ids,
					 asmbl_id            => $organism_asmbl_id,
					 sybase_time         => $sybase_time,
					 db_id_hashref       => $db_id_hashref,
					 organism_id_hashref => $organism_id_hashref,
					 database_prefix     => $database_prefix,
					 org_type_is_euk     => $org_type_is_euk
					 );
$logger->logdie("organism_id was not defined") if (!defined($organism_id));

my $new_asmbl_id_list_ref = &migrate_assembly_data(
						   t2creader           => $t2creader,
						   t2cwriter           => $t2cwriter,
						   cvterm_ids          => $cvterm_ids,
						   asmbl_id            => $asmbl_id_list_ref,
						   sybase_time         => $sybase_time,
						   db_id_hashref       => $db_id_hashref,
						   organism_id_hashref => $organism_id_hashref,
						   organism_id         => $organism_id,
						   database_prefix     => $database_prefix,
						   org_type_is_euk     => $org_type_is_euk
						   );

$logger->logdie("new_asmbl_id_list_ref was not defined") if (!defined($new_asmbl_id_list_ref));


$logger->info("Retrieving role id data");

my $role_id_lookup = &retrieve_role_id_lookup($t2creader, $new_asmbl_id_list_ref);
$logger->logdie("role_id_lookup was not defined") if (!defined($role_id_lookup));


&migrate_transcript_data(
			 t2creader           => $t2creader,
			 t2cwriter           => $t2cwriter,
			 asmbl_id            => $new_asmbl_id_list_ref,
			 role_id_lookup      => $role_id_lookup,
			 cvterm_ids          => $cvterm_ids,
			 sybase_time         => $sybase_time,
			 db_id_hashref       => $db_id_hashref,
			 organism_id_hashref => $organism_id_hashref,
			 organism_id         => $organism_id,
			 database_prefix     => $database_prefix,
			 org_type_is_euk     => $org_type_is_euk
			 );



#
# write to the tab delimited .out files
#
&write_to_outfiles($t2cwriter, $outdir);
print "\n";

$logger->info("'$0': Finished migrating data from $source_database to $target_database");
$logger->info("Please verify log4perl log file: $log4perl");
print STDERR ("Tab delimited .out files were written to $outdir\n");





#------------------------------------------------------------------------------------------------------------------------------------
#
#                END OF MAIN SECTION -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------------------------------


#-----------------------------------------------------------------------------------------
# migrate_organism_data()
#
#    
# This sub migrates the organism related data into the Chado database
#
#
#------------------------------------------------------------------------------------------
sub migrate_organism_data{
    
    $logger->debug("Entered migrate_organism_data") if $logger->is_debug();

    my $warn_flag = 0;

    my %parameter = @_;
    my $parameter_hash = \%parameter;

    my $t2creader;
    my $t2cwriter;
    my $asmbl_id;
    my $cvterm_ids;
    my $sybase_time;
    my $database_prefix;
    my $org_type_is_euk;
    #
    # hash refererences
    #
    my $db_id_hashref;
    my $organism_id_hashref;

    #-----------------------------------------------------
    # Extract arguments from parameter hash
    #
    #-----------------------------------------------------
    $t2creader           = $parameter_hash->{'t2creader'}           if (exists $parameter_hash->{'t2creader'});
    $t2cwriter           = $parameter_hash->{'t2cwriter'}           if (exists $parameter_hash->{'t2cwriter'});
    $asmbl_id            = $parameter_hash->{'asmbl_id'}            if (exists $parameter_hash->{'asmbl_id'});
    $cvterm_ids          = $parameter_hash->{'cvterm_ids'}          if (exists $parameter_hash->{'cvterm_ids'});
    $sybase_time         = $parameter_hash->{'sybase_time'}         if (exists $parameter_hash->{'sybase_time'});
    $db_id_hashref       = $parameter_hash->{'db_id_hashref'}       if (exists $parameter_hash->{'db_id_hashref'});
    $organism_id_hashref = $parameter_hash->{'organism_id_hashref'} if (exists $parameter_hash->{'organism_id_hashref'});
    $database_prefix     = $parameter_hash->{'database_prefix'}     if (exists $parameter_hash->{'database_prefix'});
    $org_type_is_euk     = $parameter_hash->{'org_type_is_euk'}     if (exists $parameter_hash->{'org_type_is_euk'});


    $logger->debug("parameter_hash:")       if $logger->is_debug();
    $logger->debug(Dumper($parameter_hash)) if $logger->is_debug();

    #------------------------------------------------------
    # Verify whether arguments were defined
    #
    #------------------------------------------------------
    $logger->logdie("t2creader was not defined")           if (!defined($t2creader));
    $logger->logdie("t2cwriter was not defined")           if (!defined($t2cwriter));
    $logger->logdie("asmbl_id was not defined")            if (!defined($asmbl_id));
    $logger->logdie("cvterm_ids was not defined")          if (!defined($cvterm_ids));
    $logger->logdie("sybase_time was not defined")         if (!defined($sybase_time));
    $logger->logdie("db_id_hashref was not defined")       if (!defined($db_id_hashref));
    $logger->logdie("organism_id_hashref was not defined") if (!defined($organism_id_hashref));
    $logger->logdie("database_prefix was not defined")     if (!defined($database_prefix));
    $logger->logdie("org_type_is_euk was not defined")     if (!defined($org_type_is_euk));
    
    my $database = $t2creader->{_db};
    $logger->logdie("database was not defined") if (!defined($database));    

    # retrieve organism related data
    # query executed by get_organism_data():
    # SELECT cg.file_moniker, cg.name, np.taxon_id
    # FROM common..genomes cg, new_project np 
    # WHERE cg.db = $database

    my $tigr_organism_data = $t2creader->organism_data($database);
    $logger->logdie("tigr_organism_data was not defined") if (!defined($tigr_organism_data));    


    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = 1;
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);

    printf "%-60s   %-12s     0%", qq!Migrating organism data:!, "[". " "x$bars . "]";



    #-----------------------------------------------------------------
    # write datasets to out files
    #
    #-----------------------------------------------------------------
    my $organism_id;
    for(my $i=0;$i<1;$i++){
	
	$organism_id = $t2cwriter->store_organism_data(
						       organism_name       => $tigr_organism_data->{'name'},           # common..genomes.name
						       file_moniker        => $tigr_organism_data->{'file_moniker'},   # common..genomes.file_moniker
						       taxon_id            => $tigr_organism_data->{'taxon_id'},       # new_project.taxon_id
						       organism_database   => $t2creader->{_db},                       # euk_database eg. "tba1"
						       asmbl_id            => $asmbl_id,
						       sybase_time         => $sybase_time,
						       db_id_hashref       => $db_id_hashref,
						       organism_id_hashref => $organism_id_hashref,
						       database_prefix     => $database_prefix,
						       org_type_is_euk     => $org_type_is_euk
						       );

	&show_progress("organism data",$counter,++$row_count,$bars,$total_rows);
    }
    print ("\n");

    return $organism_id;

}# end sub migrate_organism_data()
    

#-----------------------------------------------------------------------------------------
# migrate_assembly_data()
#
#    
# This sub migrates the Genomic Contig/Genomic Axis/Assembly
# data from the eukaryotic database into the target database with chado schema
#
#
#------------------------------------------------------------------------------------------
sub migrate_assembly_data{

    $logger->debug("Entered migrate_assembly_data") if $logger->is_debug();

    my (%parameter) = @_;
    my $parameter_hash = \%parameter;

    my $warn_flag = 0;

    my $t2creader;
    my $t2cwriter;
    my $asmbl_id_list_ref;
    my $cvterm_ids;
    my $sybase_time;
    my $organism_id;
    my $database_prefix;
    my $org_type_is_euk;

    #
    # hash references
    #
    my $db_id_hashref;
    my $organism_id_hashref;

    #-------------------------------------------------
    # Extract arguments from parameter hash
    #
    #-------------------------------------------------
    $t2creader           = $parameter_hash->{'t2creader'}           if (exists $parameter_hash->{'t2creader'});
    $t2cwriter           = $parameter_hash->{'t2cwriter'}           if (exists $parameter_hash->{'t2cwriter'});
    $asmbl_id_list_ref   = $parameter_hash->{'asmbl_id'}            if (exists $parameter_hash->{'asmbl_id'});
    $cvterm_ids          = $parameter_hash->{'cvterm_ids'}          if (exists $parameter_hash->{'cvterm_ids'});
    $sybase_time         = $parameter_hash->{'sybase_time'}         if (exists $parameter_hash->{'sybase_time'});
    $db_id_hashref       = $parameter_hash->{'db_id_hashref'}       if (exists $parameter_hash->{'db_id_hashref'});
    $organism_id_hashref = $parameter_hash->{'organism_id_hashref'} if (exists $parameter_hash->{'organism_id_hashref'});
    $organism_id         = $parameter_hash->{'organism_id'}         if (exists $parameter_hash->{'organism_id'});
    $database_prefix     = $parameter_hash->{'database_prefix'}     if (exists $parameter_hash->{'database_prefix'});
    $org_type_is_euk     = $parameter_hash->{'org_type_is_euk'}     if (exists $parameter_hash->{'org_type_is_euk'});

    #-------------------------------------------------
    # Verify whether arguments were defined
    #
    #-------------------------------------------------
    $logger->logdie("t2creader was not defined")           if (!defined($t2creader));
    $logger->logdie("t2cwriter was not defined")           if (!defined($t2cwriter));
    $logger->logdie("asmbl_id_list_ref was not defined")   if (!defined($asmbl_id_list_ref));
    $logger->logdie("cvterm_ids was not defined")          if (!defined($cvterm_ids));
    $logger->logdie("sybase_time was not defined")         if (!defined($sybase_time));
    $logger->logdie("db_id_hashref was not defined")       if (!defined($db_id_hashref));
    $logger->logdie("organism_id_hashref was not defined") if (!defined($organism_id_hashref));
    $logger->logdie("organism_id was not defined")         if (!defined($organism_id));
    $logger->logdie("database_prefix was not defined")     if (!defined($database_prefix));
    $logger->logdie("org_type_is_euk was not defined")     if (!defined($org_type_is_euk));

    $logger->debug("asmbl_id_list_ref:")       if $logger->is_debug();
    $logger->debug(Dumper($asmbl_id_list_ref)) if $logger->is_debug();
   
    my $database = $t2creader->{_db};
    $logger->logdie("database was not defined") if (!defined($database));

    #--------------------------------------------------
    # Retrieve assembly related data from the database
    #
    #--------------------------------------------------
    my $tigr_assembly_data;

    # if asmbl_id is defined, means that we are migrating a completed pseudomolecule
    #

    #--------------------------------------------------
    # Retrieving data only for a specific set of 
    # assemblies as specified in asmbl_id_list_ref
    #
    #--------------------------------------------------
    if ($asmbl_id_list_ref ne "ALL"){

	($tigr_assembly_data, $asmbl_id_list_ref) = $t2creader->euk_assembly_data($asmbl_id_list_ref);
	$logger->logdie("tigr_assembly_data was not defined") if (!defined($tigr_assembly_data));
	$logger->logdie("asmbl_id_list_ref was not defined")  if (!defined($asmbl_id_list_ref));

    }


    #--------------------------------------------------
    # Retrieving data for all assemblies
    #
    #--------------------------------------------------
    elsif ($asmbl_id_list_ref eq "ALL"){

	($tigr_assembly_data, $asmbl_id_list_ref) = $t2creader->euk_assembly_data();
	$logger->logdie("tigr_assembly_data was not defined") if (!defined($tigr_assembly_data));
	$logger->logdie("asmbl_id_list_ref was not defined")  if (!defined($asmbl_id_list_ref));

        my @retrieved_asmbl_ids;
	for (my $i=0;$i<$tigr_assembly_data->{'count'};$i++){
	    push (@retrieved_asmbl_ids, $tigr_assembly_data->{$i}->{'asmbl_id'});
	}
	my @ids;

	$asmbl_id_list_ref = \@retrieved_asmbl_ids;

	foreach my $id (sort {$a <=> $b} @{$asmbl_id_list_ref}){#(sort @retrieved_asmbl_ids){
	    push (@ids, $id);
	}
	$asmbl_id_list_ref = \@ids;

    }

   
    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $row_count = 0;
    my $bars = 30;
    my $total_rows = $tigr_assembly_data->{'count'};
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);

    printf "%-60s   %-12s     0%", qq!Migrating assembly \#!, "[". " "x$bars . "]";

    

    my ($assembly_cvterm_id, $assembly_name_cvterm_id, $chromosome_cvterm_id);

    $assembly_cvterm_id = $cvterm_ids->{'assembly_cvterm_id'} if (exists $cvterm_ids->{'assembly_cvterm_id'});
    $logger->logdie("assembly_cvterm_id was not defined") if (!defined($assembly_cvterm_id));
    
    $assembly_name_cvterm_id = $cvterm_ids->{'assembly_name_cvterm_id'} if (exists $cvterm_ids->{'assembly_name_cvterm_id'});	
    $logger->logdie("assembly_name_cvterm_id was not defined") if (!defined($assembly_name_cvterm_id));
    
    $chromosome_cvterm_id = $cvterm_ids->{'chromosome_cvterm_id'} if (exists $cvterm_ids->{'chromosome_cvterm_id'});
    $logger->logdie("chromosome_cvterm_id was not defined") if (!defined($chromosome_cvterm_id));
    
    



    #-----------------------------------------------------------------
    # write datasets to out files
    #
    #-----------------------------------------------------------------
    for(my $i=0;$i<$tigr_assembly_data->{'count'};$i++){
	my $asmbl_id = $tigr_assembly_data->{$i}->{'asmbl_id'};
	$logger->logdie("asmbl_id was not defined") if (!defined($asmbl_id));

	if ($asmbl_id !~ /^\d+$/){
	    $logger->fatal("asmbl_id:$asmbl_id is not a digit, skipping");
	    next;
	}

	$t2cwriter->store_assembly_data(
					asmbl_id                => $asmbl_id,                                     # a.asmbl_id
					sequence                => $tigr_assembly_data->{$i}->{'sequence'},       # a.sequence
					clone_name              => $tigr_assembly_data->{$i}->{'clone_name'},     # c.clone_name
					gb_acc                  => $tigr_assembly_data->{$i}->{'gb_accession'},   # c.gb_acc
					chromosome              => $tigr_assembly_data->{$i}->{'chromosome'},     # c.chromo
					is_public               => $tigr_assembly_data->{$i}->{'is_public'},      # c.is_public
					ed_date                 => $tigr_assembly_data->{$i}->{'ed_date'},        # a.ed_date
					database                => $t2creader->{_db},
					org_type_is_euk         => $org_type_is_euk,                              # tells BulkSybaseChadoPrismDB whether migrating euk or not
					assembly_cvterm_id      => $assembly_cvterm_id,
					assembly_name_cvterm_id => $assembly_name_cvterm_id,
					chromosome_cvterm_id    => $chromosome_cvterm_id,
					db_id_hashref           => $db_id_hashref,
					organism_id_hashref     => $organism_id_hashref,
					organism_id             => $organism_id,
					sybase_time             => $sybase_time,
					database_prefix         => $database_prefix,
					);

	&show_progress("assembly #$asmbl_id",$counter,++$row_count,$bars,$total_rows);
	    undef $tigr_assembly_data->{$i};
    }

    print ("\n");

    return $asmbl_id_list_ref;


}# end sub migrate_assembly_data()



#---------------------------------------------------------------------------------------
# migrate_transcript_data()
#
#
#---------------------------------------------------------------------------------------
sub migrate_transcript_data {
 
    $logger->debug("Entered migrate_transcript_data") if $logger->is_debug();

    my $warn_flag = 0;

    my %parameter = @_;
    my $parameter_hash = \%parameter;

    my $feat_exon_ctr = {};


    #---------------------------------------------------
    # Extract arguments from parameter hash
    #
    #---------------------------------------------------
    my $t2creader           = $parameter_hash->{'t2creader'}           if (exists $parameter_hash->{'t2creader'});
    my $t2cwriter           = $parameter_hash->{'t2cwriter'}           if (exists $parameter_hash->{'t2cwriter'});
    my $asmbl_id_list_ref   = $parameter_hash->{'asmbl_id'}            if (exists $parameter_hash->{'asmbl_id'});
    my $role_id_lookup      = $parameter_hash->{'role_id_lookup'}      if (exists $parameter_hash->{'role_id_lookup'});
    my $cvterm_ids          = $parameter_hash->{'cvterm_ids'}          if (exists $parameter_hash->{'cvterm_ids'});
    my $sybase_time         = $parameter_hash->{'sybase_time'}         if (exists $parameter_hash->{'sybase_time'});
    my $db_id_hashref       = $parameter_hash->{'db_id_hashref'}       if (exists $parameter_hash->{'db_id_hashref'});
    my $organism_id_hashref = $parameter_hash->{'organism_id_hashref'} if (exists $parameter_hash->{'organism_id_hashref'});
    my $organism_id         = $parameter_hash->{'organism_id'}         if (exists $parameter_hash->{'organism_id'});
    my $database_prefix     = $parameter_hash->{'database_prefix'}     if (exists $parameter_hash->{'database_prefix'});
    my $org_type_is_euk     = $parameter_hash->{'org_type_is_euk'}     if (exists $parameter_hash->{'org_type_is_euk'});
    
    #--------------------------------------------------
    # Verify whether arguments were defined
    #
    #--------------------------------------------------
    $logger->logdie("t2creader was not defined")           if (!defined($t2creader));
    $logger->logdie("t2cwriter was not defined")           if (!defined($t2cwriter));
    $logger->logdie("asmbl_id_list_ref was not defined")   if (!defined($asmbl_id_list_ref));
    $logger->logdie("role_id_lookup was not defined")      if (!defined($role_id_lookup));
    $logger->logdie("cvterm_ids was not defined")          if (!defined($cvterm_ids));
    $logger->logdie("sybase_time was not defined")         if (!defined($sybase_time));
    $logger->logdie("db_id_hashref was not defined")       if (!defined($db_id_hashref));
    $logger->logdie("organism_id_hashref was not defined") if (!defined($organism_id_hashref));
    $logger->logdie("organism_id was not defined")         if (!defined($organism_id));
    $logger->logdie("database_prefix was not defined")     if (!defined($database_prefix));
    $logger->logdie("org_type_is_euk was not defined")     if (!defined($org_type_is_euk));

   
    $logger->debug("asmbl_id_list_ref:\n" . Dumper($asmbl_id_list_ref)) if $logger->is_debug();
    
     
    my $asmbl_id;
    my $exon2transcript_rank = {};

    foreach $asmbl_id (sort {$a <=> $b} @{$asmbl_id_list_ref}){
	$logger->logdie("asmbl_id was not defined") if (!defined($asmbl_id));


	#-----------------------------------------
	# retrieve transcript/gene related data
	#-----------------------------------------
	my $tigr_transcripts = $t2creader->transcripts($asmbl_id);
	$logger->logdie("tigr_transcripts was not defined") if (!defined($tigr_transcripts));

	#-------------------------------------------
	# retrieve model (CDS/protein) related data
	#-------------------------------------------
	my($model_lookup) = {};
	my $tigr_coding_regions = $t2creader->coding_regions($asmbl_id);
	$logger->logdie("tigr_coding_regions was not defined") if (!defined($tigr_coding_regions));

	for(my $i=0;$i<$tigr_coding_regions->{'count'};$i++){
	    if(! exists $model_lookup->{$tigr_coding_regions->{$i}->{'parent_feat_name'}}){
		$model_lookup->{$tigr_coding_regions->{$i}->{'parent_feat_name'}} = [];
	    }
	    my $model_ref = $model_lookup->{$tigr_coding_regions->{$i}->{'parent_feat_name'}};
	    push @$model_ref, $tigr_coding_regions->{$i};
	     if(! (ref $tigr_coding_regions->{$i})){ 
		 $logger->logdie("Bad reference $tigr_coding_regions->{$i}");
	     }
	}

	#--------------------------------------
	# retrieve exon related data
	#--------------------------------------
	my($exon_lookup) = {};
	my $tigr_exons = $t2creader->exons($asmbl_id);
	$logger->logdie("tigr_exons was not defined") if (!defined($tigr_exons));

	for(my $i=0;$i<$tigr_exons->{'count'};$i++){	
	    if(! exists $exon_lookup->{$tigr_exons->{$i}->{'parent_feat_name'}}){
		$exon_lookup->{$tigr_exons->{$i}->{'parent_feat_name'}} = [];
	    }
	    my $exon_ref = $exon_lookup->{$tigr_exons->{$i}->{'parent_feat_name'}};
	    push @$exon_ref, $tigr_exons->{$i};
	}

	#------------------------------------------------------------
	# store gene/transcript related data
	#------------------------------------------------------------

	#--------------------------------------------------------------
	# show_progress related data
	#
	#--------------------------------------------------------------
	my $total_rows = $tigr_transcripts->{'count'};
	$logger->logdie("total_rows was not defined") if (!defined($total_rows));

	my $row_count = 0;
	my $bars = 30;
	my $counter = int(.01 * $total_rows);
	$counter = 1 if($counter ==0);

	printf "%-60s   %-12s     0%", qq!Migrating features:!, "[". " "x$bars . "]";

	
	# transcript related cvterm_ids
	my ($transcript_cvterm_id, $part_of_cvterm_id, $gene_cvterm_id, $assembly_cvterm_id, $produced_by_cvterm_id, $gene_product_name_cvterm_id, $tigr_role_cvterm_id);
	$transcript_cvterm_id        = $cvterm_ids->{'transcript_cvterm_id'}        if (exists $cvterm_ids->{'transcript_cvterm_id'});
	$part_of_cvterm_id           = $cvterm_ids->{'part_of_cvterm_id'}           if (exists $cvterm_ids->{'part_of_cvterm_id'});
	$gene_cvterm_id              = $cvterm_ids->{'gene_cvterm_id'}              if (exists $cvterm_ids->{'gene_cvterm_id'});
	$assembly_cvterm_id          = $cvterm_ids->{'assembly_cvterm_id'}          if (exists $cvterm_ids->{'assembly_cvterm_id'});
	$produced_by_cvterm_id       = $cvterm_ids->{'produced_by_cvterm_id'}       if (exists $cvterm_ids->{'produced_by_cvterm_id'});
	$gene_product_name_cvterm_id = $cvterm_ids->{'gene_product_name_cvterm_id'} if (exists $cvterm_ids->{'gene_product_name_cvterm_id'});
	$tigr_role_cvterm_id         = $cvterm_ids->{'tigr_role_cvterm_id'}         if (exists $cvterm_ids->{'tigr_role_cvterm_id'});
	    

	my ($protein_cvterm_id, $cds_cvterm_id, $exon_cvterm_id);
        $protein_cvterm_id = $cvterm_ids->{'protein_cvterm_id'} if (exists $cvterm_ids->{'protein_cvterm_id'});
	$cds_cvterm_id     = $cvterm_ids->{'cds_cvterm_id'}     if (exists $cvterm_ids->{'cds_cvterm_id'});
	$exon_cvterm_id    = $cvterm_ids->{'exon_cvterm_id'}    if (exists $cvterm_ids->{'exon_cvterm_id'});


	my $locuslookup = {};

	for(my $i=0;$i<$total_rows;$i++){

	    my $feat_name; 
	    my $role_id_array;

	    if (! exists $tigr_transcripts->{$i}->{'feat_name'}){
		$logger->logdie("feat_name does not exist i = $i");
	    }
	    else {
		$feat_name = $tigr_transcripts->{$i}->{'feat_name'};
		$logger->logdie("feat_name was not defined") if (!defined($feat_name));

		$role_id_array  = $role_id_lookup->{$feat_name}; 
	    }
	    
	    $t2cwriter->store_transcripts(
					  feat_name                   => $tigr_transcripts->{$i}->{'feat_name'},
					  asmbl_id                    => $tigr_transcripts->{$i}->{'asmbl_id'},
					  end5                        => $tigr_transcripts->{$i}->{'end5'},
					  end3                        => $tigr_transcripts->{$i}->{'end3'},
					  sequence                    => $tigr_transcripts->{$i}->{'sequence'},
					  locus                       => $tigr_transcripts->{$i}->{'locus'},
					  com_name                    => $tigr_transcripts->{$i}->{'com_name'},
					  date                        => $tigr_transcripts->{$i}->{'date'},
					  database                    => $t2creader->{_db},
					  role_id_lookup              => $role_id_array,
					  org_type_is_euk             => $org_type_is_euk,                   # tells BulkSybaseChadoPrismDB whether migrating euk or not
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
					  database_prefix             => $database_prefix,
					  locuslookup                 => $locuslookup,
					  );

	    my $tigr_models = $model_lookup->{$tigr_transcripts->{$i}->{'feat_name'}};
	    $logger->logdie("tigr_models was not defined") if (!defined($tigr_models));

	    foreach my $model (@$tigr_models){
		$logger->logdie("model was not defined") if (!defined($model));

		#--------------------------------------------------------------------
		# store CDS/protein related data
		#--------------------------------------------------------------------

		my $is_fmax_partial = 'false';

		#
		# modification Bugzilla case # 1400
		#
		if ((exists $model->{'protein'}) and (defined($model->{'protein'}))){


		    my $proteinseq = $model->{'protein'};
		    #
		    #  1) If the protein string contains a trailing '*', the '*' is removed
		    #     from the protein string before it is stored in chado.  The seqlen
		    #     should then reflect the length of the string without the '*'
		    #
		    if ($proteinseq =~ /\*+$/){
			#
			# strip all trailing '*'
			#
			$proteinseq =~ s/\*+$//;
			$model->{'protein'} = $proteinseq;
			$logger->info("trailing '*' was stripped from protein: $model->{'feat_name'}");
		    }
		
		    else{
			#  2) If the protein string does not contain a trailing '*', the
			#     chado.featureloc.is_fmax_partial field is set to 'true' and the
			#     protein string is migrated without modification
			$is_fmax_partial = 'true';			
			$logger->info("is_fmax_partial = 'true' for CDS: $model->{'feat_name'}");
		    }
		}


		$t2cwriter->store_coding_regions(
						 parent_feat           => $tigr_transcripts->{$i}->{'feat_name'},
						 asmbl_id              => $tigr_transcripts->{$i}->{'asmbl_id'},
						 feat_name             => $model->{'feat_name'},
						 end5                  => $model->{'end5'},
						 end3                  => $model->{'end3'},
						 sequence              => $model->{'sequence'},
						 protein               => $model->{'protein'},
						 date                  => $model->{'date'},
						 database              => $t2creader->{_db},
						 locus                 => $tigr_transcripts->{$i}->{'locus'},
						 org_type_is_euk       => $org_type_is_euk,                     # tells BulkSybaseChadoPrismDB whether migrating euk or not
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
						 is_fmax_partial       => $is_fmax_partial,
						 tu_end5               => $tigr_transcripts->{$i}->{'end5'},
						 tu_end3               => $tigr_transcripts->{$i}->{'end3'},
						 tu_seq_length         => length($tigr_transcripts->{$i}->{'sequence'}),
						 );

		#deal with CDS/UTR/start/stop issues later
		
		# retrieve exon related data
		#
		my $tigr_exons = $exon_lookup->{$model->{'feat_name'}};
		$logger->warn("tigr_exons was not defined for TU: $tigr_transcripts->{$i}->{'feat_name'} and MODEL: $model->{'feat_name'} ") if (!defined($tigr_exons));
		
		if (defined($tigr_exons)){
		    foreach my $exon (@$tigr_exons){
			$logger->logdie("exon was not defined") if (!defined($exon));
			
			$feat_exon_ctr->{$model->{'feat_name'}}++;


			#
			# Bugzilla case 1262
			# storing relative ranks of the exons
			#
			$exon2transcript_rank->{$tigr_transcripts->{$i}->{'feat_name'}}++;

		    
			#-----------------------------------------------------------------
			# store exon related data
			#-----------------------------------------------------------------
			$t2cwriter->store_exons(
						parent_feat          => $model->{'feat_name'},
						tu_feat_name         => $tigr_transcripts->{$i}->{'feat_name'},
						feat_name            => $exon->{'feat_name'},
						end5                 => $exon->{'end5'},
						end3                 => $exon->{'end3'},
						date                 => $exon->{'date'},
						asmbl_id             => $asmbl_id,
						database             => $t2creader->{_db},
						locus                => $tigr_transcripts->{$i}->{'locus'},
						org_type_is_euk      => $org_type_is_euk,                    # tells BulkSybaseChadoPrismDB whether migrating euk or not
						exon_cvterm_id       => $exon_cvterm_id,
						part_of_cvterm_id    => $part_of_cvterm_id,
						assembly_cvterm_id   => $assembly_cvterm_id,
						transcript_cvterm_id => $transcript_cvterm_id,
						sybase_time          => $sybase_time,
						db_id_hashref        => $db_id_hashref,
						organism_id_hashref  => $organism_id_hashref,
						organism_id          => $organism_id,
						database_prefix      => $database_prefix,
						rank                 => $exon2transcript_rank->{$tigr_transcripts->{$i}->{'feat_name'}},

						);
		    }#foreach exon
		}#end if (defined($tigr_exons))
	    }#foreach model



	    &show_progress("$total_rows feature group(s) for assembly #$asmbl_id", $counter, ++$row_count, $bars, $total_rows);
	    undef $tigr_transcripts->{$i};
	}#foreach transcriptional unit
	print ("\n");

    }#foreach assembly


	$logger->debug("Each model's exon counts are listed here:") if $logger->is_debug;
    $logger->debug(Dumper $feat_exon_ctr) if $logger->is_debug;


    


}# end sub migrate_transcript_data()



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
    
    my $role_count = @$role_lookup;
    $logger->debug("role_count:$role_count")  if $logger->is_debug();

    $logger->info("No role ids available in the legacy database") if ($role_count <= 0);


    #----------------------------------------
    # New datastructure
    #
    #----------------------------------------
    for (my $j=0;$j<$role_count;$j++){
	
	my $feat_name = $role_lookup->[$j]->{'feat_name'};
	my $role_id   = $role_lookup->[$j]->{'role_id'};
	
	push(@{$role_id_lookup->{$feat_name}}, $role_id);
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

    return $cvterm_ids;

}#end sub retrieve_cvterm_ids()


#-----------------------------------------------------------------
# retrieve_db_id_hashref()
#
#-----------------------------------------------------------------
sub retrieve_db_id_hashref {

    $logger->debug("Entered retrieve_db_id_hashref") if $logger->is_debug();

    my $prism = shift;
    $logger->logdie("prism was not defined") if (!defined($prism));

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


#-----------------------------------------------------------------
# show_progress()
#
#-----------------------------------------------------------------
sub show_progress{
    my($table_name,$counter,$row_count,$bars,$total_rows) = @_;
    my($percent);
    if (($row_count % $counter == 0) or ($row_count == $total_rows)) {
	
	print STDERR ("\nzero detected, row_count:$row_count\n") if ($row_count == 0);
	print STDERR ("zero detected, total_rows:$total_rows\n") if ($total_rows ==0);

	eval {$percent = int( ($row_count/$total_rows) * 100 );};
	if ($@){
	    print STDERR ("row_count:$row_count\n");
	    print STDERR ("total_rows:$total_rows\n");
	    die;
	}
	
	# $complete is the number of bars to fill in.
	my $complete = int($bars * ($percent/100));
	
	# $complete is the number of bars yet to go.
	my $incomplete = $bars - $complete;
	
	# This will backspace to before the first bracket.
	print "\b"x(72+$bars);
	printf "%-60s   %-12s   ", qq!Migrating $table_name:!, "[". "X"x$complete . " "x$incomplete . "]";
	printf "%3d%%", $percent;

    }
}


#---------------------------------------------------------------
# get_asmbl_id_list_ref()
#
#
#---------------------------------------------------------------
sub get_asmbl_id_list_ref {

    $logger->debug("Entered get_asmbl_id_list_ref") if $logger->is_debug();
    my $warn_flag = 0;


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
# get_contents()
#
#
#--------------------------------------------------------
sub get_contents {

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
    $logger->logdie("file was not defined") if (!defined($file));

    $logger->debug("Entered check_file_status for $$file") if $logger->is_debug();

    $logger->logdie("$$file does not exist") if (!-e $$file);
    $logger->logdie("$$file does not have read permissions") if (!-r $$file);

}#end sub check_file_status()

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


#--------------------------------------------------------------
# write_to_outfiles() 
#
#
#--------------------------------------------------------------
sub write_to_outfiles {

    my ( $writer, $outdir ) = @_;

    $logger->debug("Entered write_to_outfiles") if ($logger->is_debug());

    $logger->fatal("writer was not defined") if (!defined($writer));

    #
    # Output the datasets to file and/or batch load into database 
    #

    $logger->info("Writing tab delimited .out files to directory: '$outdir'");

    $writer->{_backend}->output_tables($outdir);

}#end sub write_to_outfiles()



#-----------------------------------------------------------------
# print_usage()
#
#-----------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -U username -P password -D source_database -t target_database [-l log4perl] [-a asmbl_id_list | ALL | -F asmbl_file] [-d debug_level] [-h] [-m] [-r outdir]\n";
    print STDERR "  -- U|username           = login username for database\n";
    print STDERR "  -- P|password           = login password for database\n";
    print STDERR "  -- D|source_database    = source database name\n";
    print STDERR "  -- t|target_database    = target database name\n";
    print STDERR "  -- a|asmbl_id_list      = list of assembly idenitifiers\n"; 
    print STDERR "  -- F|asmbl_file         = file containing list of assembly ids\n";
    print STDERR "  -- l|log4perl           = Log4perl output filename\n";
    print STDERR "  -- d|debug_level        = Coati::Logger log4perl logging level\n";
    print STDERR "  -- h|help               = This help message\n";
    print STDERR "  -- r|outdir             = Output directory for the tab delmitied .out files\n";
    print STDERR "  -- m|man                = Display the pod2usage pages for this script\n";
    exit 1;

}

