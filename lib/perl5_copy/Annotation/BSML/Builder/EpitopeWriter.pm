package Annotation::BSML::Builder::EpitopeWriter;

=head1 NAME

Annotation::BSML::Builder::EpitopeWriter.pm

=head1 VERSION

1.0

=head1 SYNOPSIS

use Annotation::BSML::Builder::EpitopeWriter;


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS


=over 4

=cut

use strict;
use Data::Dumper;
use Annotation::Logger;
use Annotation::Fasta::FastaBuilder;

my $logger = Annotation::Logger::get_logger("Logger::Annotation");

my $contactBE = 'sundaram@jcvi.org';

my $contactMsg = "Please contact $contactBE.";

=item new()

B<Description:> Instantiate Annotation::BSML::Builder::EpitopeWriter object

B<Parameters:> None

B<Returns:> reference to the Annotation::BSML::Builder::EpitopeWriter object

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

  if ($logger->is_debug()){
      $logger->debug("Initializing '" . __PACKAGE__ ."'");
  }

  foreach my $key (keys %args){
      $self->{"_$key"} = $args{$key};
  }

  if (!exists $self->{_bsmldoc}){
      $logger->logdie("bsmldoc was not specified!");
  }

  if (!exists $self->{_assemblyBSMLSequence}){
      $logger->logdie("assemblyBSMLSequence was not specified!");
  }

  if (!exists $self->{_prism}){
      ## This is a temporary hack to allow access
      ## to the identifier generation and mapping
      ## methods in Prism.  Such support shall be
      ## provided more appropriately in the future.
      $logger->logdie("prism was not specified!");
  }

  if (!exists $self->{_fastadir}){
      $self->{_fastadir} = '/tmp/';
      $logger->warn("fastadir was not specified and therefore ".
		    "was set to '$self->{_fastadir}");
  }

  $self->{_fastafile} = $self->{_fastadir} . '/' . $self->{_database} . '_' . $self->{_asmbl_id} . '_epitopes.fsa';

  my $fastaBuilder = new Annotation::Fasta::FastaBuilder( filename => $self->{_fastafile});

  if (!defined($fastaBuilder)){
      $logger->logdie("Could not instantiate Annotation::Fasta::FastaBuilder ".
		      "for FASTA file '$self->{_fastafile}'");
  }

  $self->{_fasta_builder} = $fastaBuilder;

  return $self;
  
}


=item DESTROY

B<Description:> Annotation::BSML::Builder::EpitopeWriter class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

  my $self = shift;

  if ($logger->is_debug()){
      $logger->debug("Destroying '" . __PACKAGE__ ."'");
  }
}


=item $self->addCollection(%args)

B<Description:> Add the epitope collection to the BSML::BsmlDoc object

B<Parameters:> $args{collection} (reference to array of Annotation::Features::Epitope objects)

B<Returns:> None

=cut

sub addCollection {

    my $self = shift;
    my (%args) = @_;

    if (!exists $args{collection}){
	$logger->logdie("collection was not defined");
    }

    if (!exists $args{featureTableLookup}){
	$logger->logdie("featureTableLookup was not defined");
    }

    if (!exists $args{bsmlSequenceLookup}){
	$logger->logdie("bsmlSequenceLookup was not defined");
    }

    my $epiCtr=0;

    foreach my $epitope (@{$args{collection}}){

	$epiCtr++;

	my $epitopeId = $self->_get_uniquename($self->{_database},
					       $self->{_asmbl_id},
					       $epitope->{_id},
					       $epitope->{_class});

	if (!defined($epitopeId)){
	    $logger->logdie("Could not retrieve identifier for database ".
			    "'$self->{_database}' asmbl_id '$self->{_asmbl_id}' ".
			    "feat_name '$epitope->{_id}' class '$epitope->{_class}'");
	}

	my $refseqId = $self->_get_uniquename($self->{_database},
					      $self->{_asmbl_id},
					      $epitope->{_parent},
					      'polypeptide');
	if (!defined($refseqId)){
	    $logger->logdie("Could not retrieve refseqId for ".
			    "parent feat_name '$epitope->{_parent}'");
	}

	## Add <Sequence> and <Seq-data-import> for the epitope
	my $uniquename_seq = $epitopeId . '_seq';

	$self->_createSequenceSection($epitopeId, 
				      $uniquename_seq,
				      $epitope
				      );

	## Add <Feature> for the epitope
	
	## First get the <Feature-table> of the reference sequence
	## i.e.: the polypeptide.
	my $refSeqBSMLFeatureTable = $self->_getRefSeqFeatureTable($args{featureTableLookup}, 
								   $args{bsmlSequenceLookup},
								   $epitope->{_id},
								   $epitope->{_parent});

	if (!defined($refSeqBSMLFeatureTable)){
	    $logger->warn("Could not retrieve reference sequence's ".
			    "<Feature-table>.  The reference sequence ".
			    "has id '$refseqId");
	    next;
	}

	## sundaram testing 2009-03-19
	print Dumper $refSeqBSMLFeatureTable;

	my $fmin = $epitope->{_fmin};
	my $fmax = $epitope->{_fmax};
	my $complement = 0;

	if ($fmin > $fmax){
	    my $tmp = $fmax;
	    $fmax = $fmin;
	    $fmin = $tmp;
	    $complement = 1;
	}

	## convert to interbase coordinate system
	$fmin--;
	
	my $bsmlFeature = $self->{_bsmldoc}->createAndAddFeatureWithLoc(
									$refSeqBSMLFeatureTable,   # <Feature-table> element object reference
									$epitopeId,          # id
									undef,               # title
									$epitope->{_class},  # class
									undef, ## comment
									undef, ## displayAuto
									$fmin,       ## start
									$fmax,       ## stop
									$complement  ## complement
									);
	

	if (!defined($bsmlFeature)){
	    $logger->logdie("Could not create <Feature> element for epitope ".
			    "'$epitopeId' database '$self->{_database}' ".
			    "asmbl_id '$self->{_asmbl_id}' feat_name '$epitope->{_id}'");
	}


	## Add <Link> to link the <Sequence> to the <Feature>
	my $bsmlLink = $self->{_bsmldoc}->createAndAddLink( $bsmlFeature,       # element
							    'sequence',          # rel
							    "#$uniquename_seq"   # href
							    );
	
	if (!defined($bsmlLink)){
	    $logger->logdie("Could not create a 'sequence' <Link> ".
			    "for epitope <Feature> with id '$epitopeId' ".
			    "(feat_name '$epitope->{_id}' ".
			    "to associate with epitope <Sequence> with ".
			    "id '$uniquename_seq'");
	}

	## Add <Cross-reference> to the <Feature>
	my $bsmlCrossReference = $self->{_bsmldoc}->createAndAddCrossReference(
									       'parent'          => $bsmlFeature,
									       'id'              => $self->{_bsmldoc}->{'xrefctr'}++,
									       'database'        => $self->{_database},
									       'identifier'      => $epitope->{_id},
									       'identifier-type' => 'feat_name'
									       );
	
	if (!defined($bsmlCrossReference)){
	    $logger->logdie("Could not create a <Cross-reference> element for epitope ".
			    "'$epitopeId' feat_name '$epitope->{_id}'");
	}
	    
	## Add <Cross-reference> to the <Feature>
	$self->_createAndAddCrossReferences($bsmlFeature, $epitope);

	## Add <Attribute> to the <Feature>
	$self->_createAndAddAttributes($bsmlFeature, $epitopeId, $epitope);

	## Add <Feature-group>
	$self->_createAndAddFeatureGroup($epitopeId,         ## Ergatis::IdGenerator identifier value
					 $epitope->{_id},    ## feat_name
					 $epitope->{_class}, ## feat_type
					 $refseqId ); ## feat_name value for the reference ORF/polypeptide
    }

    print "Added '$epiCtr' epitopes to the BSML document\n";

    $self->{_fasta_builder}->writeFile();

    print "Wrote epitope FASTA file '$self->{_fastafile}'\n";
}

    
=item $self->_getRefSeqFeatureTable($featureTableLookup, $idToBsmlSequenceLookup, $feat_name, $parent_feat_name)

B<Description:> Retrieve or create a <Feature-table> object

B<Parameters:> 

$featureTableLookup (reference to PERL hash) key=identifier value=reference to BSML <Feature-table> object
$idToBsmlSequenceLookup (reference to PERL hash) key=identifier value=reference to BSML <Sequence> object
$feat_name (scalar - string)
$parent_feat_name (scalar - string)

B<Returns:> None

=cut

sub _getRefSeqFeatureTable {

    my $self = shift;
    my ($featureTableLookup, $idToBsmlSequenceLookup, $feat_name, $parent_feat_name) = @_;

    my $refseqId = $self->_get_uniquename($self->{_database},
					  $self->{_asmbl_id},
					  $parent_feat_name,
					  'polypeptide');
    if (!defined($refseqId)){
	$logger->logdie("Could not retrieve new ID for parent ".
			"with feat_name '$parent_feat_name' while ".
			"processing epitope with feat_name '$feat_name'");
    }

    if (exists $featureTableLookup->{$refseqId}){

	return $featureTableLookup->{$refseqId};

    } else {
	## The corresponding polypeptide did not have a Feature-table

	if ( exists $idToBsmlSequenceLookup->{$refseqId}){
	    my $bsmlSequence = $idToBsmlSequenceLookup->{$refseqId};
	    
	    ## Create a Feature-table for this polypeptide now
	    my $bsmlFeatureTable = $self->{_bsmldoc}->createAndAddFeatureTable($bsmlSequence);

	    if (!defined($bsmlFeatureTable)){
		$logger->logdie("Could not create a Feature-table for polypeptide ".
				"'$refseqId'");
	    } else {
		## Store the new polypeptide Feature-table in the lookup
		$featureTableLookup->{$refseqId} = $bsmlFeatureTable;
	    }

	    return $bsmlFeatureTable;

	} else {
	    ## I'm assuming that the polypeptide would have already been processed
	    ## and stored before attempting to process and store the epitope.
	    $logger->warn("Error occured while attempting to create a epitope feature ".
			  "with feat_name '$feat_name' associated with polypeptide ".
			  "'$refseqId'.  The polypeptide should have been processed ".
			  "before attempting to process the epitope.");
	    return undef;
	}
    }
}

sub _get_uniquename {

    my $self = shift;
    my ($database, $asmbl_id, $feat_name, $class) = @_;

    if (!defined($database)){
	$logger->logdie("database was not defined");
    }
    if (!defined($asmbl_id)){
	$logger->logdie("asmbl_id was not defined");
    }
    if (!defined($feat_name)){
	$logger->logdie("feat_name was not defined");
    }
    if (!defined($class)){
	$logger->logdie("class was not defined");
    }

    my $uniqstring = $database . '_' .$asmbl_id . '_' . $feat_name . '_' . $class;

    ## Now using IdGenerator
    my $id = $self->{_prism}->getFeatureUniquenameFromIdGenerator($database,
								  $class,
								  $uniqstring,
								  0);
    
    if (!defined($id)){
	$logger->logdie("id was not defined for database '$database' ".
			"class '$class' uniqstring '$uniqstring' ".
			"version '0'");
    }

    return $id;
}


sub _createAndAddAttributes {
    
    my $self = shift;
    my ($bsmlFeature, $id, $epitope) = @_;

    my $attrCtr=0;

    if (exists $epitope->{_aa_collection}){

	foreach my $aaCollection (@{$epitope->{_aa_collection}}){

	    if (exists $aaCollection->{_collection}){

		foreach my $aa (@{$aaCollection->{_collection}}){

		    my $bsmlAttribute = $self->{_bsmldoc}->createAndAddBsmlAttribute( $bsmlFeature,
										      $aa->{_name},
										      $aa->{_value});
		    
		    if (!defined($bsmlAttribute)){
			$logger->logdie("Could not create <Attribute> for ".
					"with name '$aa->{_name}' content '$aa->{_value}' ".
					"for epitope with id '$id' and ".
					"feat_name = '$epitope=>{_id}'");
		    }

		    $attrCtr++;
		    
		}
	    }
	}
    }

    if ($attrCtr == 0){
	$logger->warn("No <Attribute> objects were added for epitope with ".
		      "id '$id' feat_name '$epitope->{_id}'");
    }

}

sub _createAndAddFeatureGroup {

    my $self = shift;
    my ($epitopeId, $feat_name, $class, $polypeptideId) = @_;

    ## Create a <Feature-group> for this epitope
    ## This will be nested below the assembly <Sequence>
    my $epitopeBsmlFeatureGroup = $self->{_bsmldoc}->createAndAddFeatureGroup(
									      $self->{_assemblyBSMLSequence},   # <Sequence> element object reference
									      undef,     # id
									      $epitopeId # groupset
									      );  
	
    if (!defined($epitopeBsmlFeatureGroup)){
	$logger->logdie("Could not create <Feature-group> element for ".
			"epitope '$epitopeId' with feat_name '$feat_name'");
    }

    ## Add a <Feature-group-member> for this signal peptide
    my $epitopeBsmlFeatureGroupMember = $self->{_bsmldoc}->createAndAddFeatureGroupMember(
											  $epitopeBsmlFeatureGroup,  # <Feature-group> object
											  $epitopeId,      # featref
											  $class,          # feattype
											  undef,           # grouptype
											  undef,           # cdata
											  ); 
    if (!defined($epitopeBsmlFeatureGroupMember)){
	$logger->logdie("Could not create <Feature-group-member> for ".
			"epitope '$epitopeId' with feat_name '$feat_name' ".
			"class '$class'");
    }

    ## Add the polypeptide to the <Feature-group>
    my $polypeptideBsmlFeatureGroupMember = $self->{_bsmldoc}->createAndAddFeatureGroupMember(
											      $epitopeBsmlFeatureGroup,  # <Feature-group> object
											      $polypeptideId,   # featref
											      'polypeptide',    # feattype
											      undef,            # grouptype
											      undef,            # cdata
											      ); 
    if (!defined($polypeptideBsmlFeatureGroupMember)){
	$logger->logdie("Could not create <Feature-group-member> for ".
			"polypeptide '$polypeptideId' while processing ".
			"epitope with id '$epitopeId' feat_name '$feat_name' ".
			"class '$class'");
    }
}

sub _createSequenceSection {
    
    my $self = shift;
    my ($epitopeId, $uniquename_seq, $epitope) = @_;

    my $length = length($epitope->{_seq});

    ## Create <Sequence> element object for the subfeature as a sequence
    my $bsmlSequence = $self->{_bsmldoc}->createAndAddSequence( $uniquename_seq,      # id
								undef,                # title
								$length,              # length
								$epitope->{_moltype}, # molecule
								$epitope->{_class}    # class
								);
    
    if (!defined($bsmlSequence)){
	$logger->logdie("Could not create <Sequence> for ".
			"the sequence '$uniquename_seq'");
    }  

    ##
    ## Create some <Seq-data-import> BSML element object
    ##
    my $bsmlSeqDataImport = $self->{_bsmldoc}->createAndAddSeqDataImport(
									 $bsmlSequence,  # <Sequence> element object reference
									 'fasta',        # format
									 $self->{_fastafile},  # source
									 undef,          # id
									 $epitopeId      # identifier
									 );
    if (!defined($bsmlSeqDataImport)){
	$logger->logdie("BSML <Seq-data-import> was not ".
			"defined for <Sequence> with id ".
			"'$uniquename_seq'");
    }


    $self->{_fasta_builder}->createAndAddFastaRecord($epitopeId, $epitope->{_seq});

}

sub _createAndAddCrossReferences {

    my $self = shift;
    my ($bsmlFeature, $epitope) = @_;

    foreach my $xrefHash (@{$epitope->{_xref}}){

	my $id;
	my $db;
	my $version;

	if (!exists $xrefHash->{id}){
	    $logger->logdie("id does not exist in xref for epitope:". Dumper $epitope);
	}

	$id = $xrefHash->{id};

	if ((!exists $xrefHash->{db}) || ($xrefHash->{db} eq '')){
	    $db = $self->{_database};
	} else {
	    $db = $xrefHash->{db};
	}

	if (exists $xrefHash->{version}){
	    $version = $xrefHash->{version};
	} else {
	    $version = 'current';
	}

	my $bsmlCrossReference = $self->{_bsmldoc}->createAndAddCrossReference(
									       'parent'          => $bsmlFeature,
									       'id'              => $self->{_bsmldoc}->{'xrefctr'}++,
									       'database'        => $db,
									       'identifier'      => $id,
									       'identifier-type' => $version
									       );
	
	if (!defined($bsmlCrossReference)){
	    $logger->logdie("Could not create a <Cross-reference> element for epitope ".
			    "'$epitope->{_id}' identifier '$id' database '$db' ".
			    "version '$version'");
	}
    }
}
	
1==1; ## End of module
