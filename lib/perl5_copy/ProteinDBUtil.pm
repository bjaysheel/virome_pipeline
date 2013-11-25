package ProteinDBUtil;

=head1 NAME

ProteinDBUtil.pm



=head1 VERSION

1.0

=head1 SYNOPSIS

use ProteinDBUtil;


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

new
_init
DESTROY
isQualified
_processRecords


=over 4

=cut

use strict;
use Carp;
use Data::Dumper;

use constant TRUE => 1;
use constant FALSE => 0;

=item new()

B<Description:> Instantiate ProteinDBUtil object

B<Parameters:> None

B<Returns:> reference to the ProteinDBUtil object

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


    if (( exists $self->{_records}) && (defined($self->{_records}))){
	## okay

    } else {
	## Need to retrieve the records from the database

	my $asmbl_id;

	if (( exists $self->{_asmbl_id}) && (defined($self->{_asmbl_id}))){
	    $asmbl_id = $self->{_asmbl_id};
	} else {
	    confess "asmbl_id was not defined";
	}

	my $db;
	
	if (( exists $self->{_db}) && (defined($self->{_db}))){
	    $db = $self->{_db};
	} else {
	    confess "db was not defined";
	}

	if (( exists $self->{_prism}) && (defined($self->{_prism}))){
	
	    my $proteinRecords = $self->{_prism}->{_backend}->getDisruptedProteinRecords($asmbl_id, $db);

	    if (!defined($proteinRecords)){
		confess "proteinRecords was not defined for asmbl_id ".
		"'$asmbl_id' db '$db'";
	    }
	
	    $self->{_records} = $proteinRecords;
	    
	} else {
	    confess "prism was not defined";
	}
    }

    $self->_processRecords();

    return $self;
}


=item DESTROY

B<Description:> ProteinDBUtil class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

    my $self = shift;
}


sub _processRecords {

    my $self = shift;
    my $lookup={};
    my $recCtr=0;

    foreach my $record (@{$self->{_records}}){
	$recCtr++;

	if (($record->[1] eq '') || (!defined($record->[1]))){
	    $record->[1] = undef;
	}

	$lookup->{$record->[0]}->[0] = $record->[1]; ## asm_feature.protein
	$lookup->{$record->[0]}->[1] = $record->[2]; ## ORF_attribute.att_type
    }

    $self->{_lookup} = $lookup;
    print "Processed '$recCtr' records\n";
}


=item $obj->isDisrupted($id)

B<Description:> Determine whether the protein identifier exists in the lookup of proteins with disrupted reading frames

B<Parameters:> $id (scalar - string) 

B<Returns:> $boolean (scalar - unsigned integer) 

=cut

sub isDisrupted {

    my $self = shift;
    my ($id) = @_;
    
    if (!defined($id)){
	confess "id was not defined";
    }

    if ( exists $self->{_lookup}->{$id}){
	## The protein does exist in the lookup
	## so it had AFS or APM or DEG in ORF_attribute.att_type

	if (defined($self->{_lookup}->{$id}->[0])){

	    ## The protein does not have any sequence
	    ## i.e.: asm_feature.protein
	    my $seq = $self->{_lookup}->{$id}->[0];
	    my $code = $self->{_lookup}->{$id}->[1];
	    confess "An asm_feature record had a value in the asm_feature.protein ".
	    "field however has '$code' in ORF_attribute.att_type.  The feat_name is '$id. ".
	    "Please investigate.";

	} else {
	    my $code = $self->{_lookup}->{$id}->[1];
	    print "Disrupted reading frame for protein '$id' with code '$code'\n";
	    return TRUE;
	}
    } else {
	## Not a protein with AFS, APM or DEG
	return FALSE;
    }
}


1==1; ## end of module
