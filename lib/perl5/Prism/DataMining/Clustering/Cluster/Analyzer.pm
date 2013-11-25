package Prism::DataMining::Cluster::Analyzer;

=head1 NAME

Prism::DataMining::Cluster::Analyzer.pm

A module to assist with changing the state of feature records.

=head1 VERSION

1.0

=head1 SYNOPSIS

use Prism::DataMining::Cluster::Analyzer;


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

new
_init
_setPrismEnv
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

B<Description:> Instantiate Prism::DataMining::Cluster::Analyzer object

B<Parameters:> None

B<Returns:> reference to the Prism::DataMining::Cluster::Analyzer object

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

B<Description:> Prism::DataMining::Cluster::Analyzer class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

    my $self = shift;
}

=item $self->assertDisjoint(%args)

B<Description:> Main method

B<Parameters:> %args

B<Returns:> None

=cut

sub areDisjoint {

    my $self = shift;

    my $analysis_id = $self->_getAnalysisId(@_);

    print "Will retrieve all protein identifiers and corresponding cluster identifiers associated ".
    "with the cluster analysis with identifier '$analysis_id' on database '$self->{_database}' on ".
    "server '$self->{_server}'\n";

    my $records = $self->{_prism}->proteinIdentifiersByClusterAnalysisId($analysis_id);
    if (!defined($records)){
	confess "Could not retrieve records for analysis_id '$analysis_id'";
    }

    my $lookup={};
    my $dupLookup={};
    my $dupCtr=0;
    my $proteinCtrLookup={};
    my $dupProteinCtr=0;
    my $proteinCtr=0;


    if (FALSE){
	$self->_initTestCondition($records);
    }

    foreach my $record (@{$records}){

	$proteinCtr++;

	if (!exists $lookup->{$record->[PROTEIN_ID]}){
	    $lookup->{$record->[PROTEIN_ID]} = $record->[CLUSTER_ID];
	} else {
	    $dupCtr++;
	    push(@{$dupLookup->{$record->[PROTEIN_ID]}}, $record->[CLUSTER_ID]);
	    if (! exists $proteinCtrLookup->{$record->[PROTEIN_ID]}){
		push(@{$dupLookup->{$record->[PROTEIN_ID]}}, $lookup->{$record->[PROTEIN_ID]});
		$dupProteinCtr++;
	    }
	}
    }


    my $ofh = $self->_getOutputFileHandle(@_);

    $self->{_protein_ctr} = $proteinCtr;

    if ($dupCtr > 0){

	$self->{_disjoint} = FALSE;
	$self->{_dup_protein_ctr} = $dupProteinCtr;
	$self->{_dup_lookup} = $dupLookup;
	return FALSE;

    } else {
	$self->{_disjoint} = TRUE;
	print $ofh "All '$self->{_protein_ctr}' proteins are members of disjoint clusters\n";
	return TRUE;
    }

}

sub printNonDisjointReport {

    my $self = shift;

    my $ofh = $self->{_ofh};

    if ((exists $self->{_disjoint}) && (defined($self->{_disjoint})) && ($self->{_disjoint} == FALSE)){

	if ($self->{_dup_protein_ctr} == 1){
	    print $ofh "Found '$self->{_dup_protein_ctr}' protein that is a member of more than one cluster\n";
	} else {
	    print $ofh "Found '$self->{_dup_protein_ctr}' proteins that are members of more than one cluster\n";
	}
	

	foreach my $protein (sort keys %{$self->{_dup_lookup}}){

	    print $ofh "Protein '$protein' is member of the following clusters:\n";

	    foreach my $cluster (@{$self->{_dup_lookup}->{$protein}}){

		print $ofh "$cluster\n";
	    }

	    print $ofh "\n";
	}
    } else {
	
	print $ofh "All '$self->{_protein_ctr}' proteins are members of disjoint clusters\n";
    }
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

    return $self->{_analysis_id};
}

sub _initTestCondition {

    my $self = shift;
    my ($records) = @_;

    push(@{$records}, [999900,1505433]);

    #Protein '999854' is member of the following clusters:
    #1505433

    #Protein '999900' is member of the following clusters:
    #1498461
}


1==1; ## end of module
