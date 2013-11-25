package EpitopeDBUtil;

=head1 NAME

EpitopeDBUtil.pm

Collection class for Annotation Attributes

=head1 VERSION

1.0

=head1 SYNOPSIS

use EpitopeDBUtil;


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

new{}
_init{}
DESTROY{}
getCollection{}
getCount{}


=over 4

=cut

use strict;
use Carp;
use Data::Dumper;
use Annotation::Logger;
use Annotation::Features::Epitope;
use Annotation::Features::EpitopeAACollection;


my $identAttributeNameLookup={};

my $commonScoreTypeLookup={};

=item new()

B<Description:> Instantiate EpitopeDBUtil object

B<Parameters:> None

B<Returns:> reference to the EpitopeDBUtil object

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

  if (! exists $self->{_logger}){
      my $logger = Annotation::Logger::get_logger("Logger::Annotation");
      $self->{_logger} = $logger;
  }

  if ((exists $self->{_protein_util}) && (defined($self->{_protein_util}))){
      ## okay
  } else {
      confess "protein util was not defined";
  }

  ##
  ## Initialize the common score_type lookup.
  ##
  $commonScoreTypeLookup = { 97911 => "Assay Group",
			     97912 => "Assay Type",
			     97913 => "PMID",
			     97914 => "MHC Allele",
			     97908 => "MHC Allele Class",
			     97909 => "MHC Quantitative Binding Assay Result",
			     97910 => "MHC Qualitative Binding Assay Result"
			 };

  $self->_loadIdentAttributeNameLookup();

  $self->_buildCollection();



  return $self;
}

=item $self->_loadIdentAttributeNameLookup()

B<Description:> Load the identAttributeNameLookup

B<Parameters:> None

B<Returns:> None

=cut

sub _loadIdentAttributeNameLookup {

  my $self = shift;

  $identAttributeNameLookup = { 0 => 'feat_name',
				1 => 'com_name',
				2 => 'comment',
				3 => 'assignby',
				4 => 'date',
				5 => 'ec#',
				6 => 'auto_comment',
				7 => 'gene_sym' };

}




=item DESTROY

B<Description:> EpitopeDBUtil class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

  my $self = shift;

  if ($self->{_logger}->is_debug()){
      $self->{_logger}->debug("Destroying '" . __PACKAGE__ ."'");
  }
}

=item $self->_buildCollection()

B<Description:> Process the records and build an EpitopeAACollection

B<Parameters:> None

B<Returns:> None

=cut

sub _buildCollection {

    my $self = shift;


    my $asmFeatureLookup = $self->_getAsmFeatureLookup();

    if (!defined($asmFeatureLookup)){
	$self->{_logger}->logdie("asmFeatureLookup was not defined");
    }

    my $identLookup = $self->_getIdentLookup();

    if (!defined($identLookup)){
	$self->{_logger}->logdie("identLookup was not defined");
    }

    my $evidenceLookup = $self->_getEvidenceLookup();

    if (!defined($evidenceLookup)){
	$self->{_logger}->logdie("evidenceLookup was not defined");
    }

    my $accessionLookup = $self->_getAccessionLookup();

    if (!defined($accessionLookup)){
	$self->{_logger}->logdie("accessionLookup was not defined");
    }

    my $scoreLookup = $self->_getScoreLookup();

    if (!defined($scoreLookup)){
	$self->{_logger}->logdie("scoreLookup was not defined");
    }


    foreach my $feat_name (keys %{$asmFeatureLookup}){

	if (!exists $identLookup->{$feat_name}){
	    $self->{_logger}->logdie("feat_name '$feat_name' did not exist in identLookup");
	}

	if (!exists $evidenceLookup->{$feat_name}){
	    $self->{_logger}->logdie("feat_name '$feat_name' did not exist in evidenceLookup");
	}

	if (!exists $accessionLookup->{$feat_name}){
	    $self->{_logger}->logdie("feat_name '$feat_name' did not exist in accessionLookup");
	}

	if (!exists $scoreLookup->{$feat_name}){
	    $self->{_logger}->fatal("feat_name '$feat_name' identLookup:". Dumper $identLookup->{$feat_name});
	    $self->{_logger}->fatal("feat_name '$feat_name' evidenceLookup:". Dumper $evidenceLookup->{$feat_name});
	    $self->{_logger}->fatal("feat_name '$feat_name' scoreLookup:". Dumper $scoreLookup->{$feat_name});
	    print STDERR ("feat_name '$feat_name' identLookup:". Dumper $identLookup->{$feat_name});
	    print STDERR ("feat_name '$feat_name' evidenceLookup:". Dumper $evidenceLookup->{$feat_name});
	    print STDERR ("feat_name '$feat_name' scoreLookup:". Dumper $scoreLookup->{$feat_name});
	    $self->{_logger}->logdie("feat_name '$feat_name' did not exist in scoreLookup");
	}
	

	my $asmFeatureRecord = $asmFeatureLookup->{$feat_name};

	my $epi = new Annotation::Features::Epitope(id=>$feat_name,
						    class=>$asmFeatureRecord->[0],
						    fmin=>$asmFeatureRecord->[1],
						    fmax=>$asmFeatureRecord->[2],
						    seq=>$asmFeatureRecord->[3],
						    parent=>$asmFeatureRecord->[4]
						    );
	
	if (! defined ($epi)){
	    $self->{_logger}->logdie("Could not instantiate Annotation::Features::Epitope ".
			    "for id '$feat_name' and asm_feature record:".
			    Dumper $asmFeatureRecord);
	}


	my $aaCollection = new Annotation::Features::EpitopeAACollection();
	if (!defined($aaCollection)){
	    $self->{_logger}->logdie("Could not instantiate Annotation::Features::EpitopeAACollection ".
			    "while processing Epitope:". Dumper $epi);
	}

	my $iCtr=0;

	foreach my $val (@{$identLookup->{$feat_name}}){

	    $iCtr++;

	    if (defined($val)){

		my $name = $identAttributeNameLookup->{$iCtr};

		if (!defined($name)){
		    if ($iCtr < 8){
			print Dumper $identLookup->{$feat_name};
			$self->{_logger}->logdie("name was not defined in ".
						 "identAttributeLookup for '$iCtr' ".
						 "while processing feat_name '$feat_name'");
		    } else {
			next;
		    }
		}

		if ($name eq 'com_name'){
		    ## We don't want to store the gene_product_name of the
		    ## corresponding ORF/polypeptide with this epitope.
		    next;
		}

		$aaCollection->createAndAddAttribute(name=>$name, value=>$val);
	    }
	}

	my $accession = $evidenceLookup->{$feat_name}->[1];

	if (defined($accession)){
	    push(@{$epi->{_xref}}, {id=>$accession});
	}

	foreach my $recArr (@{$accessionLookup->{$feat_name}}){
	    push(@{$epi->{_xref}}, {db=>$recArr->[1], id=>$recArr->[0]});
	}

	my $method = $evidenceLookup->{$feat_name}->[2];

	if (defined($method)){
	    $aaCollection->createAndAddAttribute(name=>'method',value=>$method);
	}

	foreach my $recArr (@{$scoreLookup->{$feat_name}}){

	    my $score = $recArr->[0];

	    if ((defined($score)) &&
		(length($score) > 0) && 
		($score !~ /^\s+$/)){

		my $score_type = $recArr->[1];
		
		if (!defined($score_type)){
		    $self->{_logger}->logdie("score_type was not defined for score ".
				    "'$score' feat_name '$feat_name'");
		}
		    
		if (!exists $commonScoreTypeLookup->{$score_type}){
		    $self->{_logger}->warn("score_type '$score_type' does not exist ".
					   "in the commonScoreTypeLookup (while ".
					   "processing feat_name '$feat_name'");

		    $self->{_logger}->warn("feat_score record:" .Dumper $recArr);
		    $self->{_logger}->warn("commonScoreTypeLookup:". Dumper $commonScoreTypeLookup);

		    next;
		}

		$aaCollection->createAndAddAttribute(name=>$commonScoreTypeLookup->{$score_type},value=>$score);

	    } else {
		$self->{_logger}->logdie("score was not defined for feat_name ".
				"'$feat_name'");
	    }
	}


	$epi->addAttributeCollection($aaCollection);

	push(@{$self->{'_collection'}}, $epi);

	$self->{'_counter'}++;
    }
}

sub _getAsmFeatureLookup {

    my $self = shift;

    if (! exists $self->{_asm_feature}){
	$self->{_logger}->logdie("asm_feature does not exist");
    }

    my $lookup={};
    my $recCtr=0;
    my $addedCtr=0;
    my $invalidCtr=0;

    ## [0] feat_name
    ## [1] feat_type
    ## [2] feat_method
    ## [3] end5
    ## [4] end3
    ## [5] assignby
    ## [6] date
    ## [7] sequence
    ## [8] protein
    ## [9] sequence_other
    ## [10] sequence_type
    ## [11] feat_link.parent_feat
    

    foreach my $record (@{$self->{_asm_feature}}){

	$recCtr++;

	my $feat_name = $record->[0];

	if ($self->{_protein_util}->isDisrupted($record->[11])){
	    push(@{$self->{_invalid_epitopes}}, "$record->[0] $record->[11]");
	    $invalidCtr++;
	    next;
	}

	my $seqCtr=0;
	my $seq;

	if (defined($record->[7])){
	    $seqCtr++;
	    $seq = $record->[7];
	}

	if (defined($record->[8])){
	    $seqCtr++;
	    $seq = $record->[8];
	}

	if (defined($record->[9])){
	    $seqCtr++;
	    $seq = $record->[9];
	}

	if ($seqCtr == 0){

	    $self->{_logger}->logdie("No sequence retrieved for epitope ".
			    "with feat_name '$feat_name'");

	} elsif ($seqCtr != 1){
	    $seq = $record->[8];
	}
	
	if (exists $lookup->{$feat_name}){
	    $self->{_logger}->logdie("feat_name '$feat_name' already exists ".
			    "in the lookup");
	}

	$lookup->{$feat_name} = [$record->[1], ## feat_type
				 $record->[3], ## end5
				 $record->[4], ## end3
				 $seq,         ## sequence
				 $record->[11] ## parent_feat
				 ];

	$addedCtr++;

	$self->{_epi_to_protein_lookup}->{$feat_name} = $record->[1];
    }

    print "Processed '$recCtr' epitope asm_feature records\n";

    print "Added '$addedCtr' epitope asm_feature records to the lookup\n";


    if ($invalidCtr > 0 ){
	print "The following '$invalidCtr' epitopes will be excluded ".
	"because their corresponding protein records have no sequence:\n";
	print join("\n", @{$self->{_invalid_epitopes}});
    }

    $self->{_invalid_epitope_ctr} = $invalidCtr;

    return $lookup;
}

sub _getIdentLookup {

    my $self = shift;

    if (! exists $self->{_ident}){
	$self->{_logger}->logdie("ident does not exist");
    }

    my $lookup={};
    my $recCtr=0;

    ## [0] feat_name
    ## [1] com_name
    ## [2] comment
    ## [3] assignby
    ## [4] date
    ## [5] ec#
    ## [6] auto_comment
    ## [7] gene_sym

    foreach my $record (@{$self->{_ident}}){

	$recCtr++;

	my $feat_name = shift(@{$record});

	if (exists $lookup->{$feat_name}){
	    $self->{_logger}->logdie("feat_name '$feat_name' already exists in the lookup");
	}

	$lookup->{$feat_name} = $record;
    }

    print "Added '$recCtr' epitope ident records to the lookup\n";

    return $lookup;
}

sub _getEvidenceLookup {

    my $self = shift;

    if (! exists $self->{_evidence}){
	$self->{_logger}->logdie("evidence does not exist");
    }

    my $lookup={};
    my $recCtr=0;

    ## [0] feat_name
    ## [1] id
    ## [2] accession
    ## [3] method

    foreach my $record (@{$self->{_evidence}}){

	$recCtr++;

	my $feat_name = shift(@{$record});

	if (exists $lookup->{$feat_name}){
	    $self->{_logger}->logdie("feat_name '$feat_name' already exists in the lookup");
	}

	$lookup->{$feat_name} = $record;
    }

    print "Added '$recCtr' epitope evidence records to the lookup\n";

    return $lookup;
}

sub _getScoreLookup {

    my $self = shift;

    if (! exists $self->{_score}){
	$self->{_logger}->logdie("score does not exist");
    }

    my $lookup={};
    my $recCtr=0;

    ## [0] feat_name
    ## [1] score
    ## [2] score_type
    ## [3] description
    ## [4] date
    ## [5] assignby

    foreach my $record (@{$self->{_score}}){

	$recCtr++;

	my $feat_name = shift(@{$record});

	push(@{$lookup->{$feat_name}}, $record);
    }

    print "Added '$recCtr' epitope score records to the lookup\n";

    return $lookup;
}

sub _getAccessionLookup {

    my $self = shift;

    if (! exists $self->{_accession}){
	$self->{_logger}->logdie("accession does not exist");
    }

    my $lookup={};
    my $recCtr=0;

    ## [0] feat_name
    ## [1] accession_id
    ## [2] accession_db

    foreach my $record (@{$self->{_accession}}){

	$recCtr++;

	my $feat_name = shift(@{$record});

	push(@{$lookup->{$feat_name}}, $record);
    }

    print "Added '$recCtr' epitope accession records to the lookup\n";

    return $lookup;
}


=item $self->getCollection()

B<Description:> Retrieve the EpitopeAACollection

B<Parameters:> None

B<Returns:>  $collection (EpitopeAACollection)

=cut

sub getCollection { 

  my $self = shift;
  
  if ( exists $self->{'_collection'}){

      return $self->{'_collection'};

  } else {

      $self->{_logger}->warn("the collection does not exist!");
      return undef;
  }
}


=item $self->getCount()

B<Description:> Retrieve the number of Annotation::Features::AnnotationAttribute objects in the collection

B<Parameters:>  None

B<Returns:> $count (scalar - unsigned integer)

=cut

sub getCount  { 

  my $self = shift;
  
  if ( exists $self->{'_counter'}){

      return $self->{'_counter'};

  } else {

      return 0;
  }
}


1==1; ## end of module
