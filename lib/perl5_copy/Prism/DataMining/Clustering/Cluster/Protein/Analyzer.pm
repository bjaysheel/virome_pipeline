package Prism::DataMining::Clustering::Cluster::Protein::Analyzer;

=head1 NAME

Prism::DataMining::Clustering::Cluster::Protein::Analyzer.pm



=head1 VERSION

1.0

=head1 SYNOPSIS

use Prism::DataMining::Clustering::Cluster::Protein::Analyzer;


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

new
_init
_checkVendor
_checkServer
_initPrism
_setPrismEnv
DESTROY
generateReport
_loadLookup
_calculateStats
_printHeader
_getOutputFileHandle
getOutputFile
_getAnalysisId



=over 4

=cut

use strict;
use Carp;
use Prism;
use Data::Dumper;
use Statistics::Descriptive;

use constant TEST => 0;
use constant TEST_COUNT => 10;
use constant DEFAULT_MIN_COUNT => 2;

use constant TRUE  => 1;
use constant FALSE => 0;

use constant PROTEIN_ID => 0;
use constant CLUSTER_ID => 1;
use constant LENGTH     => 2;

use constant DEFAULT_USERNAME => 'access';
use constant DEFAULT_PASSWORD => 'access';
use constant DEFAULT_SERVER   => 'SYBPROD';
use constant DEFAULT_VENDOR   => 'sybase';


=item new()

B<Description:> Instantiate Prism::DataMining::Clustering::Cluster::Protein::Analyzer object

B<Parameters:> None

B<Returns:> reference to the Prism::DataMining::Clustering::Cluster::Protein::Analyzer object

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

    if (! (( exists $self->{_min_count}) && (defined($self->{_min_count})))){
	$self->{_min_count} = DEFAULT_MIN_COUNT;
    }

    if (! ((exists $self->{_prism}) && (defined($self->{_prism})))){

	## Abstract method defined in one of the subclasses.
	$self->_setPrismEnv($self->{_vendor}, $self->{_server});

	$self->_initPrism(@_);
    }


    return $self;
}

=item $self->_checkVendor(%args)

B<Description:> Set the default relational database manage system type if not specified

B<Parameters:> %args

B<Returns:> None

=cut

sub _checkVendor {

    my $self = shift;

    if (! (( exists $self->{_VENDOR}) && (defined($self->{_VENDOR})))){
	$self->{_vendor} = DEFAULT_VENDOR;
    }
}

=item $self->_checkServer(%args)

B<Description:> Set the default server if not specified

B<Parameters:> %args

B<Returns:> None

=cut

sub _checkServer {

    my $self = shift;

    if (! (( exists $self->{_server}) && (defined($self->{_server})))){
	$self->{_server} = DEFAULT_SERVER;
    }
}

=item $self->_setPrismEnv(%args)

B<Description:> Set the PRISM environment variable

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

=item $self->_initPrism(%args)

B<Description:> Instantiate a Prism class instance

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

B<Description:> Prism::DataMining::Clustering::Cluster::Protein::Analyzer class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

    my $self = shift;
}

=item $self->generateReport(%args)

B<Description:> Generate the statistics on the protein sequence lengths

B<Parameters:> %args

B<Returns:> None

=cut

sub generateReport {

    my $self = shift;
    $self->_loadLookup(@_);
    $self->_calculateStats(@_);

}

=item $self->_loadLookup(%args)

B<Description:> Retrieve the records from the database and load the data-structure

B<Parameters:> %args

B<Returns:> None

=cut

sub _loadLookup {

    my $self = shift;

    my $analysis_id = $self->_getAnalysisId(@_);

    print "Will retrieve all protein identifiers and corresponding cluster identifiers associated ".
    "with the cluster analysis with identifier '$analysis_id' on database '$self->{_database}' on ".
    "server '$self->{_server}'\n";

    my $records = $self->{_prism}->proteinLengthsByClusterAnalysisId($analysis_id);
    if (!defined($records)){
	confess "Could not retrieve records for analysis_id '$analysis_id'";
    }

    my $lookup={};
    my $proteinCtr=0;

    foreach my $record (@{$records}){

	$proteinCtr++;

	push(@{$lookup->{$record->[CLUSTER_ID]}}, [$record->[PROTEIN_ID], $record->[LENGTH]]);
    }

    print "Loaded '$proteinCtr' proteins into the lookup\n";

    $self->{_lookup} = $lookup;
    $self->{_protein_count} = $proteinCtr;
}

=item $self->_calculateStats(%args)

B<Description:> Calculate the cluster sequence length statistics and print the results to the output file

B<Parameters:> %args

B<Returns:> None

=cut

sub _calculateStats {

    my $self = shift;
    my $ofh = $self->_getOutputFileHandle(@_);

    $self->_printHeader();

    my $clusterCtr=0;

    foreach my $cluster (keys %{$self->{_lookup}}){

	$clusterCtr++;

	my $count=0;

	
	my $stats = new Statistics::Descriptive::Full();
	if (!defined($stats)){
	    confess "Could not instantiate Statistics::Descriptive::Full";
	}

	foreach my $list (@{$self->{_lookup}->{$cluster}}){
	    if (TEST){
		print $ofh $list->[0] . "\t" . $list->[1] . "*** \n";
	    }

	    $stats->add_data($list->[1]);
	    $count++;
	}

	if ($count < $self->{_min_count}){
	    next;
	}

	my $mode = $stats->mode();
	if ((!defined($mode)) || ($mode eq '')){
	    $mode = 'undef';
	}

	if (TEST){
	    print $ofh "cluster '$cluster'\tcount '$count'\tmean '" . $stats->mean();
	    print $ofh "'\tmedian '" . $stats->median();
	    print $ofh "'\tmode '" . $mode;
	    print $ofh "'\tmin '" . $stats->min();
	    print $ofh "'\tmax '" . $stats->max();
	    print $ofh "'\tstd '" . $stats->standard_deviation() ."'\n";
	}
	
	print $ofh $cluster . "\t" . $count . "\t" . $stats->mean();
	print $ofh "\t" . $stats->median();
	print $ofh "\t" . $mode;
	print $ofh "\t" . $stats->standard_deviation() ."\n";
	

	if (TEST){
	    if ($clusterCtr > TEST_COUNT){
		last;
	    }
	}
    }
}

=item $self->_printHeader(%args)

B<Description:> Print the header to the output file

B<Parameters:> %args

B<Returns:> None

=cut

sub _printHeader {

    my $self = shift;

    my $ofh = $self->_getOutputFileHandle(@_);
    print $ofh "## This file contains the cluster statistics for the analysis_id '$self->{_analysis_id}'\n";
    print $ofh "## on database '$self->{_database}' server '$self->{_server}'\n";
    print $ofh "## The minimum cluster member size is '$self->{_min_count}'\n";
    print $ofh "## The column definitions for the records that follow are:\n";
    print $ofh "## cluster\tcount\taverage\tmedian\tmode\tstd\n";
}

=item $self->_getOutputFileHandle(%args)

B<Description:> Retrieve reference to the output stream object for the specified output file

B<Parameters:> %args

B<Returns:> $ofh (reference to output stream)

=cut

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

=item $self->getOutputFile(%args)

B<Description:> Retrieve the output filename

B<Parameters:> %args

B<Returns:> $file (scalar - string)

=cut

sub getOutputFile {

    my $self = shift;
    if (( exists $self->{_outfile}) && (defined($self->{_outfile}))){
	return $self->{_outfile};
    } else {
	warn "outfile was not defined\n";
	return undef;
    }
}

=item $self->_getAnalysisId(%args)

B<Description:> Retrieve the analysis_id

B<Parameters:> %args

B<Returns:> $analysis_id (scalar - unsigned integer)

=cut

sub _getAnalysisId {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{analysis_id}) && (defined($args{analysis_id}))){
	$self->{_analysis_id} = $args{analysis_id};
    } elsif (( exists $self->{_analysis_id}) && (defined($self->{_analysis_id}))){
	## okay
    } else {
	confess "analysis_id was not defined";
    }

    if ($self->{_analysis_id} != int($self->{_analysis_id})){
	confess "analysis_id should be some unsigned integer value and not '$self->{_analysis_id}'";
    }

    return $self->{_analysis_id};
}



1==1; ## end of module
