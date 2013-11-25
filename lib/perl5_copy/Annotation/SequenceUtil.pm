package Annotation::SequenceUtil;

=head1 NAME

Annotation::SequenceUtil.pm

=head1 VERSION

1.0

=head1 SYNOPSIS


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS


=over 4

=cut

use strict;
use Annotation::Logger;
use Carp;
use Data::Dumper;
use JCVI::Translator::Utils;

my $logger = Annotation::Logger::get_logger("Logger::Annotation");


=item new()

B<Description:> Instantiate Annotation::SequenceUtil object

B<Parameters:> None

B<Returns:> reference to the Annotation::SequenceUtil object

=cut

sub new  {

  my $class = shift;

  my $self = {};

  bless $self, $class;

  $self->_init(@_);

  return $self;
}

=item $self->_init(%args)

B<Description:> Typical Perl init() method

B<Parameters:> %args

B<Returns:> None

=cut

sub _init {

  my $self = shift;
  my (%args) = @_;

  foreach my $key (keys %args ) {
    $self->{"_$key"} = $args{$key};
  }

  my $translator = new JCVI::Translator::Utils();

  if (!defined($translator)){

      $logger->logdie("Could not instatiate JCVI::Translator::Utils object!");
  }

  $self->{'_translator'} = $translator;

}


=item DESTROY

B<Description:> Annotation::SequenceUtil class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  {
  my $self = shift;

}

=item $obj->loadSequence($sequence)

B<Description:> Store the molecule sequence from which all subfeature sequences will be derived

B<Parameters:> $sequence (scalar - string)

B<Returns:> None

=cut

sub loadSequence {

    my $self = shift;
    my ($sequence) = @_;

    if (!defined($sequence)) {
	$logger->logdie("sequence was not defined");
    }

    $self->{'_sequence'} = $sequence;

}

=item $obj->getSequence()

B<Description:> Retrieve reference to the sequence

B<Parameters:> None

B<Returns:> $sequence (reference to scalar - string)

=cut

sub getSequence {

    my $self = shift;

    if (! exists $self->{'_sequence'}){
	$logger->warn("sequence does not exist");
    }

    return $self->{'_sequence'};

}

=item $obj->deriveSequenceFromCoordinates($end5, $end3)

B<Description:> Derive a sequence for specified range

B<Parameters:>

$end5 (scalar - string)
$end3 (scalar - string)

B<Returns:> $seq (scalar - string)

=cut

sub deriveSequenceForFeature {

    my $self = shift;
    my (%args) = @_;
    

    if (! exists $args{'end5'}){
	$logger->logdie("end5 was not defined");
    }

    if (! exists $args{'end3'}){
	$logger->logdie("end3 was not defined");
    }

    my $fmin = $args{'end5'};

    my $fmax = $args{'end3'};


    if ($fmin != int($fmin)){
	$logger->logdie("Usage error: end5 was '$fmin' when ".
			"expected value is unsigned integer");
    }

    if ($fmax != int($fmax)){
	$logger->logdie("Usage error: end3 was '$fmax' when ".
			"expected value is unsigned integer");
    }

    my $key = $fmin . '_' .$fmax;

    if ( exists $self->{'_cache_sequences'}){


	if ( exists $self->{'_cached_sequences'}->{$key}){

	    return $self->{'_cached_sequences'}->{$key};
	}
    }


    my $seq;

    if ($fmin == $fmax){

	$seq = undef;

    } else {

	## Get start and length based on end5 and end3
#	my ($start, $length) = $self->_determineStartAndLengthFromCoordinates($fmin, $fmax);
	

	my $start;
	my $length;
	my $strand=1;

	if ($fmax > $fmin){

	    $start = $fmin - 1;
	    $length = $fmax - $fmin;

	} else {
	    
#	    $start = $fmax - 1;
	    $start = $fmax;
	    $length = $fmin - $fmax;
	    $strand = -1;
	}

	
	$seq = substr($self->{'_sequence'}, $start, $length);

	if ($strand == -1 ){
	    $seq = reverse $seq;
	    $seq =~ tr/ACTG/TGAC/;
	}

#	die "end5 '$fmin 'end3 '$fmax' start '$start' length '$length' seq '$seq'";
    }

    if ( exists $self->{'_cache_sequences'}){

	$self->{'_sequence_cache'}->{$key} = $seq;
    }

    return $seq;
}


=item $obj->_determineStartAndLengthFromCoordinates($end5, $end3)

B<Description:> Determine the start and the running length for the specified range

B<Parameters:>

$end5 (scalar - string)
$end3 (scalar - string)

B<Returns:> 

$start (scalar - string)
$length (scalar - string)

=cut


sub _determineStartAndLengthFromCoordinates {

    my $self = shift;
    my ($end5, $end3) = @_;

    if ($end3 > $end5){

	return ($end5 - 1, $end3 - $end5);

    } else {

	return ($end3 - 1, $end5 - $end3);
    }

}


=item $obj->translateCDS()

B<Description:> Translate the coding domain sequences into amino acid sequence

B<Parameters:>

B<Returns:> $aa (scalar - string)
 
=cut

sub translateCDS {

    my $self = shift;

    my (%args,$strand) = @_;

    if (! exists $args{'cdslist'}){

	$logger->logdie("cdslist was not defined");
    }

    my $cdslist = $args{'cdslist'};

    my $newList = &_rearrangeCoordinatesForTranslation($cdslist);

    my @CDSs = sort { $a->getFmin() <=> $b->getFmin() } (@{$newList});
		 
    if (!defined($strand)){

	$strand = $cdslist->[0]->getStrand();

	if (!defined($strand)){

	    $logger->logdie("strand was not defined for Feature:".
			    Dumper $cdslist->[0]);
	}
    }

    my $seq = $self->{'_translator'}->translate_exons(strand=>$strand, [map {[$_->getFmin(), $_->getFmax()]} @CDSs] );

    if (!defined($seq)){

	$logger->logdie("Could not derive sequence for the ".
			"following CDS features:". Dumper $args{'cdslist'});
    }

    return $seq;
}


sub translate_exons {

    my $self = shift;

    my ($sequence, $cdslist, $strand, $partial) = @_;

    if (!defined($sequence)){
	## If the sequence was not included in the parameter list
	## check if is available as an attribute of the Annotation::SequenceUtil class.
	if (( exists $self->{_sequence}) && (defined($self->{_sequence}))){
	    $sequence = \$self->{_sequence};
	} else {
	    confess "reference to sequence was not defined";
	}
    }

    if (!defined($cdslist)){
	confess "cdslist was not defined";
    }

    my $newList = &_rearrangeCoordinatesForTranslation($cdslist);

    my @CDSs = sort { $a->getFmin() <=> $b->getFmin() } (@{$newList});

    my $hash = {};


    if (!defined($strand)){
	$strand = $cdslist->[0]->getNumericStrandValue();
	if (!defined($strand)){
	    confess "strand was not defined for Feature:".
	    Dumper $cdslist->[0];
	}

	$hash->{strand} = $strand;
    } else {
	confess "strand was defined!";
    }

    if (defined($partial)){
	$hash->{partial} = $partial;
    }

    my $seq = $self->{'_translator'}->translate_exons($sequence, [map {[$_->getFmin(), $_->getFmax()]} @CDSs], $hash);

    if (!defined($seq)){
	confess "Could not derive sequence for the ".
	"following CDS features:". Dumper $cdslist;
    }

    return $seq;
}


=item $obj->_rearrangeCoordinatesForTranslation($cdsList)

B<Description:> Order the CDS features by their fmin coordinate value

B<Parameters:> $cdsList (reference to Perl list)

B<Returns:> $newList (reference to Perl list)
 
=cut

sub _rearrangeCoordinatesForTranslation {
    
    my ($cdsList) = @_;

    my $newList;

    foreach my $feature (@{$cdsList}){

	my $clone = $feature->clone();

	$clone->rearrangeCoordinatesNonDecreasingOrder();

	$clone->interbaseConversion();

	push(@{$newList}, $clone);
    }
    

    return $newList;
}

=item $obj->verifyCDSAndExonStrands($assemblyLookup)

B<Description:> Verify that the exons and corresponding CDS features share the same strand value

B<Parameters:> $assemblyLookup (reference to multi-dimensional Perl hash)

B<Returns:> None
 
=cut

sub verifyCDSAndExonStrands {
    
    my $self = shift;
    my ($assemblyLookup, $database) = @_;
    
    my $totalExonCtr=0;
    my $totalModelCtr=0;
    my $tuCtr=0;

    my $tuModelConflicts = {};
    my $tuModelConflictCtr=0;

    my $modelExonConflicts = {};
    my $modelExonConflictCtr=0;

    foreach my $asmbl_id ( sort keys %{$assemblyLookup}){
	foreach my $lookup ( @{$assemblyLookup->{$asmbl_id}} ) {

	    foreach my $tuFeatName (sort keys %{$lookup->{'transcripts'}}){

		$tuCtr++;
		my $tuStrand = $lookup->{'transcripts'}->{$tuFeatName}->{'complement'};
		my $modelCtr=0;

		foreach my $modelLookup ( @{$lookup->{'coding_regions'}->{$tuFeatName}} ){

		    $modelCtr++;
		    my $modelFeatName = $modelLookup->{'feat_name'};
		    my $modelStrand = $modelLookup->{'complement'};
		    
		    if ($tuStrand != $modelStrand){
			$tuModelConflictCtr++;
			push(@{$tuModelConflicts->{$tuFeatName}}, $modelFeatName);
		    }
		    my $exonCtr=0;

		    foreach my $exonLookup ( @{$lookup->{'exons'}->{$modelFeatName}} ){

			$exonCtr++;

			my $exonFeatName = $exonLookup->{'feat_name'};
			my $exonStrand = $exonLookup->{'complement'};

			if ($exonStrand != $modelStrand){
			    my $exonLen = abs($exonLookup->{'end5'} - $exonLookup->{'end3'});
			    # JC: it is impossible to determine the orientation of a 1bp exon in the 
			    # legacy db from its coordinates alone because in the (original) end5/end3 
			    # encoding we will have end5 == end3
			    if ($exonLen == 1) {
				$exonStrand = $exonLookup->{'complement'} = $modelStrand;
			    } else {
				$modelExonConflictCtr++;
				push(@{$modelExonConflicts->{$tuFeatName}->{$modelFeatName}}, $exonFeatName);
			    }
			}
		    }
		    $totalExonCtr += $exonCtr;
		}
		$totalModelCtr += $modelCtr;
	    }

	    if ($modelExonConflictCtr>0){
		if ($modelExonConflictCtr == 1){
		    $logger->fatal("The strand value for '$modelExonConflictCtr' exon did not match the ".
				   "corresponding model's strand value.  The following model and exon ".
				   "should be corrected in the source legacy annotation database '$database'.");
		}
		else {
		    $logger->fatal("The strand values for '$modelExonConflictCtr' exons did not match their ".
				   "corresponding models' strand values.  The following models and exons ".
				   "should be corrected in the source legacy annotation database '$database'.");
		}

		foreach my $tu (sort keys %{$modelExonConflicts}){
		    foreach my $model (sort keys %{$modelExonConflicts->{$tu}}){
			foreach my $exon ( sort @{$modelExonConflicts->{$tu}->{$model}}){
			    $logger->fatal("TU '$tu' model '$model' exon '$exon'");
			}
		    }
		}
	    }
	    
	    if ($tuModelConflictCtr>0){
		if ($tuModelConflictCtr == 1 ){
		    $logger->fatal("The strand value for '$tuModelConflictCtr' model did not match the ".
				   "corresponding TU's strand value.  The following TU and model ".
				   "should be corrected in the source legacy annotation database '$database'.");
		}
		else {
		    $logger->fatal("The strand values for '$tuModelConflictCtr' models did not match the ".
				   "corresponding TUs' strand values.  The following TUs and models ".
				   "should be corrected in the source legacy annotation database '$database'.");
		}

		foreach my $tu (sort keys %{$tuModelConflicts}){
		    foreach my $model ( @{$tuModelConflicts->{$tu}}){
			$logger->fatal("TU '$tu' model '$model'");
		    }
		}
	    }

	    if (($tuModelConflictCtr>0) || ($modelExonConflictCtr>0)){
		$logger->logdie("Extracted '$tuCtr' TUs, '$totalModelCtr' models and '$totalExonCtr' exons ".
				"from database '$database' for assembly with asmbl_id '$asmbl_id'.  Found ".
				"strand data conflicts for some number of these extracted features.  ".
				"Please review the log file.");
	    }
	}
    }
}

1==1; ## end of module
