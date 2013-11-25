package Prism::DataMining::Clustering::Cluster::Mapper;

=head1 NAME

Prism::DataMining::Clustering::Cluster::Mapper

A module to assist with the mapping of cluster sets

=head1 VERSION

1.0

=head1 SYNOPSIS

use Prism::DataMining::Clustering::Cluster::Mapper;


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

new
_init
DESTROY

=over 4

=cut

use strict;
use Carp;
use Prism;
use Data::Dumper;

use constant TRUE  => 1;
use constant FALSE => 0;

use constant PROTEIN_ID => 0;
use constant CLUSTER_ID => 1;

use constant DEFAULT_USERNAME => 'access';
use constant DEFAULT_PASSWORD => 'access';
use constant DEFAULT_SERVER   => 'SYBPROD';
use constant DEFAULT_VENDOR   => 'sybase';


=item new()

B<Description:> Instantiate Prism::Cluster::Analyzer object

B<Parameters:> None

B<Returns:> reference to the Prism::Cluster::Analyzer object

=cut

sub new  {

    my $class = shift;

    my $self = {};

    bless $self, $class;

    return $self->_init(@_);

}

=item $self->_init(%args)

B<Description:> Typical Perl init() method

B<Parameters:> %args

B<Returns:> None

=cut

sub _init {

    my $self = shift;
    my (%args) = @_;

    foreach my $key (keys %args){
	$self->{"_$key"} = $args{$key};
    }

    if (! ((exists $self->{_prism}) && (defined($self->{_prism})))){


	$self->_checkVendor();
	$self->_checkServer();

	## Abstract method defined in one of the subclasses.
	$self->_setPrismEnv($self->{_vendor}, $self->{_server});

	$self->_initPrism(@_);
    }

    return $self;
}

=item $self->_init(%args)

B<Description:> Typical Perl init() method

B<Parameters:> %args

B<Returns:> None

=cut

sub _checkVendor {

    my $self = shift;

    if (! (( exists $self->{_VENDOR}) && (defined($self->{_VENDOR})))){
	$self->{_vendor} = DEFAULT_VENDOR;
    }
}

=item $self->_init(%args)

B<Description:> Typical Perl init() method

B<Parameters:> %args

B<Returns:> None

=cut

sub _checkServer {

    my $self = shift;

    if (! (( exists $self->{_server}) && (defined($self->{_server})))){
	$self->{_server} = DEFAULT_SERVER;
    }
}

=item $self->_init(%args)

B<Description:> Typical Perl init() method

B<Parameters:> %args

B<Returns:> None

=cut

sub _setPrismEnv {

    my $self = shift;
    my ($vendor, $server) = @_;

    $vendor = ucfirst($vendor);

    my $prismEnv = "Chado:$vendor:$server";

    $ENV{PRISM} = $prismEnv;
}

=item $self->_init(%args)

B<Description:> Typical Perl init() method

B<Parameters:> %args

B<Returns:> None

=cut

sub _initPrism {

    my $self = shift;
    if (! (( exists $self->{_username}) && (defined($self->{_username})))){
	$self->{_username} = DEFAULT_USERNAME;
    }

    if (! (( exists $self->{_password}) && (defined($self->{_password})))){
	$self->{_password} = DEFAULT_PASSWORD;
    }
    
    my $prism = new Prism(user     => $self->{_username},
			  password => $self->{_password},
			  db       => $self->{_database});
    
    if (!defined($prism)){
	confess "Could not instantiate Prism";
    }
    
    $self->{_prism} = $prism;

    print "Instantiated Prism object\n";

    return $self;

}

=item DESTROY

B<Description:> Prism::Cluster::Analyzer class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

    my $self = shift;
}

=item $self->mapClusters(%args)

B<Description:> Main method

B<Parameters:> %args

B<Returns:> None

=cut

sub mapClusters {

    my $self = shift;

    my $analysis_id1 = $self->_getAnalysisId1(@_);
    my $analysis_id2 = $self->_getAnalysisId2(@_);

    $self->_loadClusterSet1($analysis_id1);

    $self->_loadClusterSet2($analysis_id2);

    $self->_map();
}

sub reportMapping {

    my $self = shift;

    if (! ((exists $self->{_map}) && (defined($self->{_map})))){
	$self->mapClusters(@_);
    }

    my $analysis_id1 = $self->_getAnalysisId1(@_);
    
    my $analysis_id2 = $self->_getAnalysisId2(@_);

    my $ofh = $self->_getOutputFileHandle(@_);

    my $mapCtr = $self->{_map_ctr};

    print $ofh "The following '$mapCtr' clusters from the first set ".
    "(analysis_id '$analysis_id1') had members in the following clusters ".
    "of the second set (analysis_id '$analysis_id2')\n";

    foreach my $cluster (keys %{$self->{_map}}){

	print $ofh "cluster '$cluster' mapped to the following clusters:\n";

	foreach my $cluster2 (@{$self->{_map}->{$cluster}}){
	    print $ofh  $cluster2  . "\n";
	}
    }

#     if ($self->{_lost_cluster_ctr} > 0 ){
# 	print $ofh "The following '$self->{_lost_cluster_ctr}' clusters ".
# 	"were not found in the second cluster set:\n";
# 	foreach my $cluster (@{$self->{_lost_clusters}}){
# 	    print $ofh $cluster . "\n";
# 	}
#     }

     if ($self->{_lost_cluster_ctr} > 0 ){
 	print $ofh "The following '$self->{_lost_cluster_ctr}' clusters ".
 	"were not found in the second cluster set:\n";
 	foreach my $cluster (keys %{$self->{_lost_clusters_lookup}}){
 	    print $ofh "cluster '$cluster' had the following protein members:\n";
	    foreach my $protein (@{$self->{_lost_clusters_lookup}->{$cluster}}){
		print $ofh "@{$protein}\n";
	    }
 	}
    }
}

sub _map {

    my $self = shift;

    my $lookup1 = $self->{_lookup1};
    my $lookup2 = $self->{_lookup2};

    my $map={};

    ## keep count of the number of clusters that map between sets
    my $mapCtr = 0; 

    my $dupLookup={};
    my $lostClusterCtr=0;

    foreach my $cluster (keys %{$lookup1}){

	my $found=0;

	foreach my $protein (@{$lookup1->{$cluster}}){

	    if (exists $lookup2->{$protein}){

		$found++;

		my $cluster2 = $lookup2->{$protein};

		if (!exists $dupLookup->{$cluster2}){
		    push(@{$map->{$cluster}}, $cluster2);
		}

		$dupLookup->{$cluster2}++;
	    }
	}

	if ($found == 0){
	    $lostClusterCtr++;
#	    push(@{$self->{_lost_clusters}}, $cluster);
	    push(@{$self->{_lost_clusters_lookup}->{$cluster}}, $lookup1->{$cluster});
	} else {
	    $mapCtr++;
	}
    }

    $self->{_lost_cluster_ctr} = $lostClusterCtr;
    $self->{_map_ctr} = $mapCtr;
    $self->{_map} = $map;
}

sub _loadClusterSet1 {

    my $self = shift;
    my ($analysis_id) = @_;
    
    print "Will retrieve all protein identifiers and corresponding cluster identifiers associated ".
    "with the cluster analysis with identifier '$analysis_id' on database '$self->{_database}' on ".
    "server '$self->{_server}'\n";
    
    my $records = $self->{_prism}->proteinIdentifiersByClusterAnalysisId($analysis_id);
    if (!defined($records)){
	confess "Could not retrieve records for analysis_id '$analysis_id'";
    }

    my $ctr=0;
    my $lookup={};


    foreach my $record (@{$records}){

	my $cluster = $record->[CLUSTER_ID];
	my $protein = $record->[PROTEIN_ID];

	push(@{$lookup->{$cluster}}, $protein);
	$ctr++;
    }

    print "Added '$ctr' proteins to the lookup\n";

    $self->{_lookup1} = $lookup;
}


sub _loadClusterSet2 {

    my $self = shift;
    my ($analysis_id) = @_;

    print "Will retrieve all protein identifiers and corresponding cluster identifiers associated ".
    "with the cluster analysis with identifier '$analysis_id' on database '$self->{_database}' on ".
    "server '$self->{_server}'\n";
    
    my $records = $self->{_prism}->proteinIdentifiersByClusterAnalysisId($analysis_id);
    if (!defined($records)){
	confess "Could not retrieve records for analysis_id '$analysis_id'";
    }

    my $ctr=0;
    my $lookup={};


    foreach my $record (@{$records}){

	$ctr++;
	if (! exists $lookup->{$record->[PROTEIN_ID]}){
	    $lookup->{$record->[PROTEIN_ID]} = $record->[CLUSTER_ID];
	} else {
	    confess "protein '" . $record->[PROTEIN_ID] . 
	    "' cluster '" . $record->[CLUSTER_ID] . 
	    "' - occurence of non-disjoint cluster";
	}

    }

    print "Processed '$ctr' proteins in cluster set 2 (analysis_id '$analysis_id')\n";
    
    $self->{_lookup2} = $lookup;
}

sub _getOutputFileHandle {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{outfile}) && (defined($args{outfile}))){
	$self->{_outfile} = $args{outfile};
    } elsif (( exists $self->{_outfile}) && (defined($self->{_outfile}))){
	## okay
    } else {
	$self->{_outfile} = '/tmp/disjoint_assertion_report.out';
	warn "outfile was not specified and therefore was set to '$self->{_outfile}'\n";
    }

    my $ofh;

    open ($ofh, ">$self->{_outfile}") || confess "Could not open output file '$self->{_outfile}' in write mode: $!";

    $self->{_ofh} = $ofh;

    return $ofh;
}

sub getOutputFile {

    my $self = shift;
    if (( exists $self->{_outfile}) && (defined($self->{_outfile}))){
	return $self->{_outfile};
    } else {
	warn "outfile was not defined\n";
	return undef;
    }
}

sub _getAnalysisId1 {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{analysis_id1}) && (defined($args{analysis_id1}))){
	$self->{_analysis_id1} = $args{analysis_id1};
    } elsif (( exists $self->{_analysis_id1}) && (defined($self->{_analysis_id1}))){
	## okay
    } else {
	confess "analysis_id1 was not defined";
    }

    return $self->{_analysis_id1};
}

sub _getAnalysisId2 {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{analysis_id2}) && (defined($args{analysis_id2}))){
	$self->{_analysis_id2} = $args{analysis_id2};
    } elsif (( exists $self->{_analysis_id2}) && (defined($self->{_analysis_id2}))){
	## okay
    } else {
	confess "analysis_id2 was not defined";
    }

    return $self->{_analysis_id2};
}


1==1; ## end of module
