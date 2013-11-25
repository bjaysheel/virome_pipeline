#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#--------------------------------------------------------------------------------------
# program name:   fixResidues.pl
# authors:        Jay Sundaram
# date:           2004-09-24
#
# Purpose:        To repair truncated feature.residues fields in the Chado database
#
#
#
#---------------------------------------------------------------------------------------
=head1 NAME

fixResidues.pl - Updates the chado.feature.{residues, seqlen, md5checksum, timelastmodified} with the data in legacy.assembly.sequence

=head1 SYNOPSIS

USAGE:  fixResidues.pl -U username -P password -D chado_database --database_type [-l log4perl] [-d debug_level] [-h] [-m] [-r run] --server [-t type_id]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--chado_database,-D>
    
    Chado database to be repaired

=item B<--database_type>
    
    Relational database management system type e.g. sybase or postgresql

=item B<--debug_level,-d>
    
    Coati::Logger log4perl logging/debugging level.  Default is 0

=item B<--log4perl,-l>
    
    Coati::Logger log4perl log file.  Default is /tmp/fixResidues.pl.log

=item B<--help,-h>

    Print this help

=item B<--man,-m>

    Display pod2usage man pages for this script

=item B<--run,-r>

    Optional -- to acutally update records in the target chado database (--run).  Default is NOT update.

=item B<--server>

    Name of server on which the database resides

=item B<--type_id,-t>

    Optional -- chado.feature.type_id.  Default is ALL.  (Currently only supporting type_id = 5)

=back

=head1 DESCRIPTION

    fixResidues.pl - Updates the chado.feature.{residues, seqlen, md5checksum, timelastmodified} with the data in legacy.assembly.sequence

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


my ($username, $password, $chado_database, $database_type, $debug_level, $log4perl, $help, $man, $type_id, $run, $server);


my $results = GetOptions (
			  'username|U=s'           => \$username, 
			  'password|P=s'           => \$password,
			  'chado_database|D=s'     => \$chado_database,
			  'database_type=s'        => \$database_type,
			  'debug_level|d=s'        => \$debug_level,
			  'log4perl|l=s'           => \$log4perl,
			  'help|h'                 => \$help,
			  'man|m'                  => \$man,
			  'run|r'                  => \$run,
			  'type_id|t=s'            => \$type_id
			  'server=s'               => \$server
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

my $fatalCtr=0;
$fatalCtr += &checkParameter('username', $username);
$fatalCtr += &checkParameter('password', $password);
$fatalCtr += &checkParameter('database', $database);
$fatalCtr += &checkParameter('database_type', $database_type);
$fatalCtr += &checkParameter('server', $server);

if ($fatalCtr>0){
    &print_usage();
}

## initialize the logger
$log4perl = "/tmp/fixResidues.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

## Set the PRISM env var
&setPrismEnv($server, $database_type);

#
# Instantiate new Prism object to communicate with the chado database
#
my $chadoprism = &retrieve_prism_writer($username, $password, $chado_database);


#
# retrieve sybase time stamp
#
my $sybase_time = $chadoprism->get_sybase_datetime();

#print Dumper $chadoprism;die;

if (defined($type_id)){
    if ($type_id !~ /\d+/){
	$logger->logdie("type_id '$type_id' was not a numeric value");
    }
    else{
	if ($type_id == 5){
	    $logger->debug("Will construct lookup for all assemby features") if $logger->is_debug;
	    #
	    # Retrieve uniquename, residues/md5
	    #
	    my $truncated = &retrieve_assembly_info($chadoprism, $type_id);
	 
	    $logger->debug("Will attempt to repair truncated assembly residues") if $logger->is_debug;
	    &process_assembly_data($username, $password, $truncated, $sybase_time, $chadoprism);

	}
	elsif ($type_id == 54){
	    $logger->debug("Will construct lookup for all gene features") if $logger->is_debug;

	    #
	    # Retrieve uniquename, residues/md5
	    #
	    my $truncated = &retrieve_subfeature_info($chadoprism, $type_id, $chado_database);
	 

#	    print Dumper $truncated;die;

	    $logger->debug("Will attempt to repair truncated gene residues") if $logger->is_debug;
	    &process_subfeature_data($username, $password, $truncated, $sybase_time, $chadoprism, $type_id);
	}
	elsif ($type_id == 55){
	    $logger->debug("Will construct lookup for all CDS features") if $logger->is_debug;

	    #
	    # Retrieve uniquename, residues/md5
	    #
	    my $truncated = &retrieve_subfeature_info($chadoprism, $type_id, $chado_database);
	 
	    print Dumper $truncated;die;

	    $logger->debug("Will attempt to repair truncated CDS residues") if $logger->is_debug;
	    &process_subfeature_data($username, $password, $truncated, $sybase_time, $chadoprism, $type_id);

	}
	elsif ($type_id == 56){
	    $logger->debug("Will construct lookup for all transcript features") if $logger->is_debug;


	    #
	    # Retrieve uniquename, residues/md5
	    #
	    my $truncated = &retrieve_subfeature_info($chadoprism, $type_id, $chado_database);
	 
	    print Dumper $truncated;die;

	    $logger->debug("Will attempt to repair truncated transcript residues") if $logger->is_debug;
	    &process_subfeature_data($username, $password, $truncated, $sybase_time, $chadoprism, $type_id);


	}
	else{
	    $logger->logdie("Unacceptable type_id '$type_id'");
	}
    }
  
}
print "\n";





#-------------------------------------------------------------------------------------------------------
# END OF MAIN  -- SUBROUTINES FOLLOW
#-------------------------------------------------------------------------------------------------------

=head2 Subroutine

=cut

=head3 retrieve_prism_writer

=over 4

Instantiates Prism Object related to Chado database

=back

=cut
#----------------------------------------------------------------
# retrieve_prism_writer()
#
#
#----------------------------------------------------------------
sub retrieve_prism_writer {

    my ( $username, $password, $database) = @_;

    $logger->debug("Instantiating Prism writer") if ($logger->is_debug());
    

    $ENV{'WRITER_CONF'} = "Chado:BulkSybase:SYBTIGR" if (!defined($ENV{'WRITER_CONF'}));

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


=head2 Subroutine

=cut

=head3 retrieve_prism_reader

=over 4

Instantiates Prism Object related to prok/euk legacy database

=back

=cut
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


=head2 Subroutine

=cut

=head3 retrieve_assembly_info

=over 4

Retrieves hashref lookup containing Chado feature objects

=back

=cut
#---------------------------------------------------------------------
# retrieve_assembly_info()
#
#---------------------------------------------------------------------
sub retrieve_assembly_info {

    my ($prism, $type_id) = @_;

    my $hash = {};

    if ($type_id ne 'ALL'){


	print "Retrieving assembly feature records\n";

	my $lookup = $prism->truncated_features($type_id);
	$logger->logdie("lookup was not defined") if (!defined($lookup));
	

	#-----------------------------------------------------------------
	# show_progress related data
	#
	#----------------------------------------------------------------
	my $row_count = 0;
	my $bars = 30;
	my $total_rows = $lookup->{'count'};
	my $counter = int(.01 * $total_rows);
	$counter = 1 if ( $counter == 0 );
	print "\n";

#	print "Building assembly feature record lookup\n";

	for (my $i=0;$i<$lookup->{'count'};$i++){
	    
#	    my $j = $i+1;
	    
#	    $prism->show_progress("Building assembly feature record lookup $j/$total_rows",$counter,$j,$bars,$total_rows);
	    $prism->show_progress("Building assembly feature record lookup $i/$total_rows",$counter,$i,$bars,$total_rows);


	    
	    my $tmphash= {};

	    my $feature_id = $lookup->{$i}->{'feature_id'};
	    my $uniquename = $lookup->{$i}->{'uniquename'};
	    my $residues   = $lookup->{$i}->{'residues'};
	    my $dbname     = $lookup->{$i}->{'dbname'};
	    
	    if (!defined($uniquename)){
		$logger->logdie("uniquename was not defined");
	    }
	    my $md5;
	    if (defined($residues)){
		$md5 = Digest::MD5::md5_hex($residues);
	    }
	    else{
		$logger->logdie("residues was not defined for uniquename '$uniquename'");
	    }

	    
	    my $orgtype;

	    if (!defined($dbname)){
		$logger->logdie("dbname was not defined for uniquename '$uniquename'");
	    }
	    else{
		if ($dbname =~ /^TIGR_(\S+):/){
		    $orgtype = $1;
		}
		else{
		    $logger->logdie("Could not extract orgtype from dbname '$dbname'");
		}

	    }


	    my ($sourcedb, $asmbl_id);

	    if ($uniquename =~ /^(\S+)_(\d+)_(\S+)/ ){

		$sourcedb = $1;
		$asmbl_id = $2;

		$tmphash->{'asmbl_id'}   = $asmbl_id;
		$tmphash->{'md5'}        = $md5;
		$tmphash->{'uniquename'} = $uniquename;
		$tmphash->{'orgtype'}    = $orgtype;
		$tmphash->{'feature_id'} = $feature_id;

		push(@{$hash->{$sourcedb}}, $tmphash);

	    }	    
	    else{
		$logger->logdie("Could not extract sourcedb asmbl_id from uniquename '$uniquename'");
	    }
	}
	$logger->info("Finished building lookup for all features with type_id = '$type_id'");
    }
    else{
	$logger->logdie("type_id == 'ALL' not yet implemented");
    }



    return $hash;
}

=head2 Subroutine

=cut

=head3 retrieve_subfeature_info

=over 4

Retrieves hashref lookup containing Chado feature objects

=back

=cut
#---------------------------------------------------------------------
# retrieve_subfeature_info()
#
#---------------------------------------------------------------------
sub retrieve_subfeature_info {

    my ($prism, $type_id, $chado_database) = @_;

    my $hash = {};

    if ($type_id ne 'ALL'){


	print "Retrieving subfeature data from chado database '$chado_database'\n";

	my $lookup = $prism->truncated_features($type_id);
	$logger->logdie("lookup was not defined") if (!defined($lookup));
	
	$logger->debug("Retrieved '$lookup->{'count'}' records of type_id '$type_id'") if $logger->is_debug;

	#-----------------------------------------------------------------
	# show_progress related data
	#
	#----------------------------------------------------------------
	my $row_count = 0;
	my $bars = 30;
	my $total_rows = $lookup->{'count'};
	my $counter = int(.01 * $total_rows);
	$counter = 1 if ( $counter == 0 );
	print "\n";


	for (my $i=0;$i<$lookup->{'count'};$i++){
	    
	    my $j = $i+1;

	    $prism->show_progress("Building chado feature type_id '$type_id' record lookup $j/$total_rows",$counter,$j,$bars,$total_rows);
#	    $prism->show_progress("Building chado feature type_id '$type_id' record lookup $i/$total_rows",$counter,$i,$bars,$total_rows);


 
	    my $tmphash= {};

	    my $feature_id = $lookup->{$i}->{'feature_id'};
	    my $uniquename = $lookup->{$i}->{'uniquename'};
	    my $residues   = $lookup->{$i}->{'residues'};
	    my $dbname     = $lookup->{$i}->{'dbname'};
	    
	    if (!defined($uniquename)){
		$logger->logdie("uniquename was not defined");
	    }
	    my $md5;
	    if (defined($residues)){
		$md5 = Digest::MD5::md5_hex($residues);
	    }
	    else{
		$logger->logdie("residues was not defined for uniquename '$uniquename'");
	    }

	    
	    my $orgtype;
	    # typical euk gene, CDS, transcript uniquename in chado.feature:
	    #
	    # "source_database"."assembly.asmbl_id"."asm_feature.feat_name"."_gene"
	    #
	    # cspa1.4.t00255_gene
	    # cspa1.4.m00255_cds 
	    # cspa1.4.t00255_transcript


	    if (!defined($dbname)){
		$logger->logdie("dbname was not defined for uniquename '$uniquename'");
	    }
	    else{
		if ($dbname =~ /^TIGR_(\S+):/){
		    $orgtype = $1;
		}
		else{
		    $logger->logdie("Could not extract orgtype from dbname '$dbname'");
		}

	    }


	    my ($sourcedb, $asmbl_id, $feat_name);

	    if ($uniquename =~ /^(\S+)\.(\d+)\.(\S+)_[gene|transcript|cds]/ ){

		$sourcedb = $1;
		$asmbl_id = $2;
		$feat_name = $3;

		
		$tmphash->{'asmbl_id'}   = $asmbl_id;
		$tmphash->{'feat_name'}  = $feat_name;
		$tmphash->{'md5'}        = $md5;
		$tmphash->{'uniquename'} = $uniquename;
		$tmphash->{'orgtype'}    = $orgtype;
		$tmphash->{'feature_id'} = $feature_id;

		push(@{$hash->{$sourcedb}}, $tmphash);

	    }	    
	    else{
		$logger->logdie("Could not extract sourcedb asmbl_id from uniquename '$uniquename'");
	    }
	}
	$logger->info("Finished building lookup for all features with type_id = '$type_id'");
    }
    else{
	$logger->logdie("type_id == 'ALL' not yet implemented");
    }



    return $hash;
}


=head2 Subroutine

=cut

=head3 process_assembly_data

=over 4

Updates the feature residues, md5checksum and timelastmodified fields in feature

=back

=cut
#--------------------------------------------------
# process_assembly_data()
#
#--------------------------------------------------
sub process_assembly_data {

    my ($username, $password, $truncated, $sybase, $chadoprism) = @_;


    $logger->logdie("username was not defined") if (!defined($username));
    $logger->logdie("password was not defined") if (!defined($password));
    $logger->logdie("truncated was not defined") if (!defined($truncated));
    $logger->logdie("sybase was not defined") if (!defined($sybase));

    
    foreach my $database (sort keys %{$truncated}){
	
	$logger->debug("processing database '$database'") if $logger->is_debug;


	my $prism = &retrieve_prism_reader($username, $password, $database);
	

	#-----------------------------------------------------------------
	# show_progress related data
	#
	#----------------------------------------------------------------
	my $row_count = 0;
	my $bars = 30;
#	my $total_rows = scalar(@{$truncated->{$database}}) + 1;
	my $total_rows = scalar(@{$truncated->{$database}}) + 1;
	my $counter = int(.01 * $total_rows);
	$counter = 1 if ( $counter == 0 );
	print "\n";
	

#	my $j=1;
	my $j=0;
	

	foreach my $hash (@{$truncated->{$database}}){
	    
	    $j++;
	    $prism->show_progress("Processing sequences for database '$database' $j/$total_rows",$counter,$j,$bars,$total_rows);


	    my $asmbl_id   = $hash->{'asmbl_id'};
	    my $orgtype    = $hash->{'orgtype'};
	    my $uniquename = $hash->{'uniquename'};
	    my $feature_id = $hash->{'feature_id'};


	    $logger->debug("feature_id '$feature_id' asmbl_id '$asmbl_id' orgtype '$orgtype' uniquename '$uniquename'") if $logger->is_debug;

	    
	    my $sequence = $prism->sequence_info($asmbl_id, $orgtype);

#	    print Dumper $sequence; die;

	    if (!defined($sequence)){
		$logger->fatal("sequence was not defined for database '$database' asmbl_id '$asmbl_id' orgtype '$orgtype' uniquename '$uniquename' feature_id '$feature_id'"); 
		next;
	    }

	    #
	    # 1) Generate the md5 checksum for the retrieved assembly.sequence
	    # 2) if not equal the value in $truncated->{'database'}->{'md5'} then need to update chado
	    #
	    my $sequence_md5 = Digest::MD5::md5_hex($sequence);
	    
	    if ($sequence_md5 ne $hash->{'md5'}){
		
		
		my $seqlen = length($sequence);
		
		$logger->warn("Will UPDATE record for feature_id '$feature_id' WHERE uniquename '$uniquename' seqlen '$seqlen' md5checksum '$sequence_md5' timelastmodified '$$sybase'");
		
		if (defined($run)){
		    die;
		    $chadoprism->{_backend}->do_update_feature(
							       feature_id       => $feature_id,
							       dbxref_id        => undef,
							       organism_id      => undef,
							       name             => undef,
							       uniquename       => undef,
							       residues         => $sequence,
							       seqlen           => $seqlen,
							       md5checksum      => $sequence_md5,
							       type_id          => undef,
							       is_analysis      => undef,
							       timeaccessioned  => undef,
							       timelastmodified => $$sybase
							       );
		}
		
	    }
	    else{
		$logger->info("feature_id '$feature_id' uniquename '$uniquename' residues field matches source in database '$database' for asmbl_id '$asmbl_id'");
	    }
	    
	}
    }
}

=head2 Subroutine

=cut

=head3 process_subfeature_data

=over 4

Updates the feature residues, md5checksum and timelastmodified fields in feature

=back

=cut
#--------------------------------------------------
# process_subfeature_data()
#
#--------------------------------------------------
sub process_subfeature_data {

    my ($username, $password, $truncated, $sybase, $chadoprism, $type_id) = @_;


    $logger->logdie("username was not defined")   if (!defined($username));
    $logger->logdie("password was not defined")   if (!defined($password));
    $logger->logdie("truncated was not defined")  if (!defined($truncated));
    $logger->logdie("sybase was not defined")     if (!defined($sybase));
    $logger->logdie("chadoprism was not defined") if (!defined($chadoprism));
    $logger->logdie("type_id was not defined")    if (!defined($type_id));

    my $updatectr=0;


    my $legacytype;
    if (($type_id == 54) or ($type_id == 56)){
	$legacytype = 'TU';
    }
    elsif ($type_id == 55){
	$legacytype = 'model';
    }
    else{
	$logger->logdie("Unrecognized type_id '$type_id'");
    }
    

    foreach my $database (sort keys %{$truncated}){
	
	$logger->debug("processing database '$database'") if $logger->is_debug;


	my $prism = &retrieve_prism_reader($username, $password, $database);

   
	#
	# Build a hash per database - containing of asm_feature.feat_name->asm_feature.sequence
	#
	print "\nRetrieving sequence data from legacy database '$database'";
	my $lookup = $prism->subfeature_sequence_hash($legacytype);
	

	#-----------------------------------------------------------------
	# show_progress related data
	#
	#----------------------------------------------------------------
	my $row_count = 0;
	my $bars = 30;
#	my $total_rows = scalar(@{$truncated->{$database}}) + 1;
	my $total_rows = scalar(@{$truncated->{$database}});
	my $counter = int(.01 * $total_rows);
	$counter = 1 if ( $counter == 0 );
	print "\n";

	
       	my $textsize;
#	my $j=1;
	my $j=0;


	foreach my $hash (@{$truncated->{$database}}){

	    $j++;
	    $prism->show_progress("Checking for altered residues against legacy db '$database' $j/$total_rows",$counter,$j,$bars,$total_rows);


	    
	    my $asmbl_id   = $hash->{'asmbl_id'};
	    my $orgtype    = $hash->{'orgtype'};
	    my $uniquename = $hash->{'uniquename'};
	    my $feature_id = $hash->{'feature_id'};
	    my $feat_name  = $hash->{'feat_name'};

	    $logger->debug("feature_id '$feature_id' asmbl_id '$asmbl_id' feat_name '$feat_name' orgtype '$orgtype' uniquename '$uniquename'") if $logger->is_debug;


	    my $sequence;
	    $feat_name = $asmbl_id . '.' . $feat_name;

#	    ($sequence, $textsize) = $prism->subfeature_sequence_info($asmbl_id, $orgtype, $type_id, $textsize, $feat_name);
	    #
	    # Retrieve sequence from lookup instead of interactively querying the
	    # legacy database everytime...
	    #
	    $sequence = $lookup->{$feat_name};

	    if (!defined($sequence)){
		$logger->fatal("sequence was not defined for database '$database' asmbl_id '$asmbl_id' feat_name '$feat_name' orgtype '$orgtype' uniquename '$uniquename' feature_id '$feature_id'"); 
		next;
	    }


	    $logger->debug("textsize '$textsize' was set for database '$database'") if $logger->is_debug;


	    #
	    # 1) Generate the md5 checksum for the retrieved assembly.sequence
	    # 2) if not equal the value in $truncated->{'database'}->{'md5'} then need to update chado
	    #
	    my $sequence_md5 = Digest::MD5::md5_hex($sequence);
	    
	    if ($sequence_md5 ne $hash->{'md5'}){
		
		$updatectr++;

		my $seqlen = length($sequence);
		
		$logger->warn("Will UPDATE record for feature_id '$feature_id' WHERE uniquename '$uniquename' seqlen '$seqlen' md5checksum '$sequence_md5' timelastmodified '$$sybase' feat_name '$feat_name'");
		

		if (0){
#		if (defined($run)){
		    die;
		    $chadoprism->{_backend}->do_update_feature(
							       feature_id       => $feature_id,
							       dbxref_id        => undef,
							       organism_id      => undef,
							       name             => undef,
							       uniquename       => undef,
							       residues         => $sequence,
							       seqlen           => $seqlen,
							       md5checksum      => $sequence_md5,
							       type_id          => undef,
							       is_analysis      => undef,
							       timeaccessioned  => undef,
							       timelastmodified => $$sybase
							       );
		}
		
	    }
	    else{
		$logger->info("feature_id '$feature_id' uniquename '$uniquename' residues field matches source in database '$database' for asmbl_id '$asmbl_id'");
	    }
	    
	}
    }

    if (defined($run)){
	$logger->warn("Updated '$updatectr' feature records");
        print "\nUpdated '$updatectr' feature records\n";
    }
    else{
	$logger->warn("Would have updated '$updatectr' feature records if run was defined.");
        print "\nWould have updated '$updatectr' feature records if run was defined.\n";
    }
}


=head2 Subroutine

=cut

=head3 print_usage

=over 4

Displays proper usage for this script

=back

=cut
#--------------------------------------------------
# print_usage()
#
#--------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -U username -P password -D chado_database --database_type [-l log4perl] [-d debug_level] [-h] [-m] [-t type_id] --server\n";
    print STDERR "  -U|--username               = Database login username\n";
    print STDERR "  -P|--password               = Database login password\n";
    print STDERR "  -D|--chado_database         = Name of chado database\n";
    print STDERR "  --database_type             = Relational database management system type e.g. sybase or postgresql\n";
    print STDERR "  -l|--log4perl               = Optional - Coati::Logger log4perl log file. Default is /tmp/fixResidues.pl.log\n";
    print STDERR "  -d|--debug_level            = Optional - Coati::Logger log4perl logging/debugging level.  Default is 0\n";
    print STDERR "  -h|--help                   = This help message\n";
    print STDERR "  -m|--man                    = Display man pages for this script\n";
    print STDERR "  -t|--type_id                = Optional - type_id of features to repair.  Default is ALL\n";
    print STDERR "  --server                    = Name of the server on which the database resides\n";
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
