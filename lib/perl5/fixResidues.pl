#!/usr/local/bin/perl
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

USAGE:  fixResidues.pl -U username -P password -D chado_database [-l log4perl] [-d debug_level] [-h] [-m] [-t type_id]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--chado_database,-D>
    
    Chado database to be repaired

=item B<--debug_level,-d>
    
    Coati::Logger log4perl logging/debugging level.  Default is 0

=item B<--log4perl,-l>
    
    Coati::Logger log4perl log file.  Default is /tmp/fixResidues.pl.log

=item B<--help,-h>

    Print this help

=item B<--man,-m>

    Display pod2usage man pages for this script

=item B<--type_id,-t>

    Optional -- chado.feature.type_id.  Default is ALL.  (Currently only supporting type_id = 5)


=back

=head1 DESCRIPTION

    fixResidues.pl - Updates the chado.feature.{residues, seqlen, md5checksum, timelastmodified} with the data in legacy.assembly.sequence

=cut

use strict;


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


my ($username, $password, $chado_database, $debug_level, $log4perl, $help, $man, $type_id);


my $results = GetOptions (
			  'username|U=s'           => \$username, 
			  'password|P=s'           => \$password,
			  'chado_database|D=s'     => \$chado_database,
			  'debug_level|d=s'        => \$debug_level,
			  'log4perl|l=s'           => \$log4perl,
			  'help|h'                 => \$help,
			  'man|m'                  => \$man,
			  'type_id|t=s'            => \$type_id
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

print STDERR ("username was not defined\n") if (!$username);
print STDERR ("password was not defined\n") if (!$password);
print STDERR ("chado_database was not defined\n") if (!$chado_database);

&print_usage if(!$username or !$password or !$chado_database);


#
# initialize the logger
#
$log4perl = "/tmp/fixResidues.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

#
# Instantiate new Prism object to communicate with the chado database
#
my $chadoprism = &retrieve_prism_writer($username, $password, $chado_database);

#print Dumper $chadoprism;die;

if (defined($type_id)){
    if ($type_id !~ /\d+/){
	$logger->logdie("type_id '$type_id' was not a numeric value");
    }
    else{
	$logger->debug("user specified type_id = '$type_id'") if $logger->is_debug;
    }
  
}


$logger->logdie("Only support correction of assembly residues (type_id must be = 5)") if ($type_id != 5);


#
# Retrieve uniquename, residues/md5
#
my $truncated = &retrieve_truncated_info($chadoprism, $type_id);

#print Dumper $truncated;die;

#
# retrieve sybase time stamp
#
my $sybase_time = $chadoprism->get_sybase_datetime();

&process_data($username, $password, $truncated, $sybase_time, $chadoprism);



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

=head3 retrieve_truncated_info

=over 4

Retrieves hashref lookup containing Chado feature objects

=back

=cut
#---------------------------------------------------------------------
# retrieve_truncated_info()
#
#---------------------------------------------------------------------
sub retrieve_truncated_info {

    my ($prism, $type_id) = @_;

    my $hash = {};

    if ($type_id ne 'ALL'){


	my $lookup = $prism->truncated_features($type_id);
	$logger->logdie("lookup was not defined") if (!defined($lookup));
	

	for (my $i=0;$i<$lookup->{'count'};$i++){
	    
	    
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

=head3 process_data

=over 4

Updates the feature residues, md5checksum and timelastmodified fields in feature

=back

=cut
#--------------------------------------------------
# process_data()
#
#--------------------------------------------------
sub process_data {

    my ($username, $password, $truncated, $sybase, $chadoprism) = @_;


    $logger->logdie("username was not defined") if (!defined($username));
    $logger->logdie("password was not defined") if (!defined($password));
    $logger->logdie("truncated was not defined") if (!defined($truncated));
    $logger->logdie("sybase was not defined") if (!defined($sybase));

    
    foreach my $database (sort keys %{$truncated}){
	
	$logger->debug("processing database '$database'") if $logger->is_debug;


	my $prism = &retrieve_prism_reader($username, $password, $database);
	
	
	foreach my $hash (@{$truncated->{$database}}){
	    
	    my $asmbl_id   = $hash->{'asmbl_id'};
	    my $orgtype    = $hash->{'orgtype'};
	    my $uniquename = $hash->{'uniquename'};
	    my $feature_id = $hash->{'feature_id'};


	    $logger->debug("feature_id '$feature_id' asmbl_id '$asmbl_id' orgtype '$orgtype' uniquename '$uniquename'") if $logger->is_debug;

	    
	    my $sequence = $prism->sequence_info($asmbl_id, $orgtype);
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
	    else{
		$logger->info("feature_id '$feature_id' uniquename '$uniquename' residues field matches source in database '$database' for asmbl_id '$asmbl_id'");
	    }
	    
	}
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

    print STDERR "SAMPLE USAGE:  $0 -U username -P password -D chado_database [-l log4perl] [-d debug_level] [-h] [-m] [-t type_id]\n";
    print STDERR "  -U|--username               = Database login username\n";
    print STDERR "  -P|--password               = Database login password\n";
    print STDERR "  -D|--chado_database         = Name of chado database\n";
    print STDERR "  -l|--log4perl               = Optional - Coati::Logger log4perl log file. Default is /tmp/fixResidues.pl.log\n";
    print STDERR "  -d|--debug_level            = Optional - Coati::Logger log4perl logging/debugging level.  Default is 0\n";
    print STDERR "  -h|--help                   = This help message\n";
    print STDERR "  -m|--man                    = Display man pages for this script\n";
    print STDERR "  -t|--type_id                = Optional - type_id of features to repair.  Default is ALL\n";
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
