package IGS::Storage::Isilon::Quota;

use strict;
use Net::SNMP;
use Carp;
use base qw(Exporter);
our @EXPORT = qw(get_volume_isilon);
our $VERSION = '0.10';

my $results;

#  Declare variables to be used globally.
my $oid_voltable = '1.3.6.1.4.1.12124.1.12.1.1';
my $isilon = 'isilon';
my $community = 'igspublic';
my $vers = 'snmpv2c';

#
#    quotaDomainID                       DisplayString,
#    quotaType                           INTEGER,
#    quotaID                             Gauge32,
#    quotaIncludesSnapshotUsage          INTEGER,
#    quotaPath                           DisplayString,
#    quotaHardThresholdDefined           INTEGER,
#    quotaHardThreshold                  CounterBasedGauge64,
#    quotaSoftThresholdDefined           INTEGER,
#    quotaSoftThreshold                  CounterBasedGauge64,
#    quotaAdvisoryThresholdDefined       INTEGER,
#    quotaAdvisoryThreshold              CounterBasedGauge64,
#    quotaGracePeriod                    Integer32,
#    quotaUsage                          CounterBasedGauge64,
#    quotaUsageWithOverhead              CounterBasedGauge64,
#    quotaInodeUsage                     CounterBasedGauge64,
#    quotaIncludesOverhead               INTEGER



#  Defining the column headings as matched up in the MIBs.
my $columns_meaning = { 1 => "Domain ID",
                        2 => "Quota Type",
                        3 => "Quota ID",
                        4 => "Usage Including Snapshot",
                        5 => "Path",
                        6 => "Hard Quota Defined",
                        7 => "Hard Quota",
                        8 => "Soft Quota Defined",
                        9 => "Soft Quota",
                        10 => "Advisory Quota Defined",
                        11 => "Advisory Quota",
                        12 => "Grace Period",
                        13 => "Usage",
                        14 => "Usage With Overhead",
                        15 => "Includes Overhead",
                       };

#############################################################################

sub _get_results {
    my ($session, $error) = Net::SNMP->session(
       -hostname    => $isilon,
       -community   => $community,
       -version     => $vers,
    );

    if (!defined $session) {
       croak "ERROR: $error";
    }

    $session->snmp_dispatcher();

    $results = $session->get_table($oid_voltable,
				-maxrepetitions => 10,
				);

    $session->close();
    
	return $results;
}

sub get_volume_isilon {
    my $dir = shift;

    if (! defined $results) {
        $results = _get_results();
    }
		
    my $dir_stats;

    # We don't know the OID for the directory, so we search for it in the hash.
    my $full_oid_for_directory_name = _search_hash_for_oid($dir, $results);
     
    my @dots = split(/\./, $full_oid_for_directory_name);

    for (my $counter = 1; $counter <= 15; $counter++) {
        
         #  Replacing the correct spot in the OID to gather all columns about a specific volume.
         $dots[11] = $counter;

         my $specific_full_oid = join('.', @dots);

         my $col_name = $columns_meaning->{$counter};
         $dir_stats->{$col_name} = $results->{$specific_full_oid};
    }
    return $dir_stats;
}


sub _search_hash_for_oid {
    my ($dir_to_search, $hash_ref) = @_;
    if ( ! defined $dir_to_search || length($dir_to_search) == 0) {
        croak "Invalid project provided.";
    }

    my $found_oid;
    foreach my $candidate (keys %$hash_ref) {
        my $statistic = $hash_ref->{$candidate};
        if ($statistic =~ m/\/$dir_to_search$/) {
            # Found it...
            $found_oid = $candidate;
	    last;
	}
    }
    return $found_oid;
}


#  Depreciated.
sub _convert_dir_to_oid {
    # Panasas lays out oid's according to the ascii values of the directories
    # inside the volumes, or something like that...
    my $dir = shift;
    my @ascii = unpack("C*", $dir);
    my $ascii = join(".", @ascii);
    return $ascii; 
}


1;
