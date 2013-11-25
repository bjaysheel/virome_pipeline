package IGS::Storage::Panasas::Quota;

use strict;
use Net::SNMP;
use Carp;
use base qw(Exporter);
our @EXPORT = qw(get_volume_stats);
our $VERSION = '0.9';

my $results;

my $oid_voltable = '1.3.6.1.4.1.10159.1.3.4.1.1';
my $panasas = 'pansnmp.igs.umaryland.edu';
my $community = 'igspublic';
my $vers = 'snmpv1';

my $columns_meaning = { 1 => "Name",
                        2 => "Blade Set",
                        3 => "Soft Quota",
                        4 => "Hard Quota",
                        5 => "Space Used",
                        6 => "RAID Level",
                        7 => "Status",
                       };

#############################################################################

sub _get_results {
    my ($session, $error) = Net::SNMP->session(
       -hostname    => $panasas,
       -community   => $community,
       -version     => $vers,
    );

    if (!defined $session) {
       croak "ERROR: $error";
    }

    $session->snmp_dispatcher();

    $results = $session->get_table($oid_voltable);

    #my $results = $session->get_entries(%$results_ref);

    $session->close();

    return $results;
}

sub get_volume_stats {
    my $dir = shift;

    if (! defined $results) {
        $results = _get_results();
    }
    #  Removed below line of code as it appears to be an unused artifact.  Will permanetly delete once confirmed. - DS
    #my $partial_dotted_oid = _convert_dir_to_oid($dir);

    my $dir_stats;

    # We don't know the OID for the directory, so we search for it in the hash.
    my $full_oid_for_directory_name = _search_hash_for_oid($dir, $results);
     
    my @dots = split(/\./, $full_oid_for_directory_name);

    for (my $counter = 1; $counter <= 7; $counter++) {
         $dots[12] = $counter;

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



sub _convert_dir_to_oid {
    # Panasas lays out oid's according to the ascii values of the directories
    # inside the volumes, or something like that...
    my $dir = shift;
    my @ascii = unpack("C*", $dir);
    my $ascii = join(".", @ascii);
    return $ascii; 
}


1;
