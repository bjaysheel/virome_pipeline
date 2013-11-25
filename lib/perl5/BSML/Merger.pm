package BSML::Merger;

=head1 NAME

BSML::Merger.pm

=head1 VERSION

1.0

=head1 SYNOPSIS

use BSML::Merger;


=head1 DESCRIPTION

All of the non-reference Sequence, Feature-table and Feature-group elements are transfered from the second BSML file to the first BSML file.
The two BSML files should have the same reference sequence i.e. an assembly with the same id attribute.
Note that at this time:
1) all Genome information in the second BSML file is lost
2) all of the reference Sequence element's information in the second BSML file is lost
3) there is no support for transferring analysis-related information

=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

=over 4

=cut

use strict;
use Data::Dumper;
use Carp;
use BSML::BsmlBuilder;
use BSML::BsmlParserSerialSearch;
use BSML::Logger;

## Store reference of the <Genome> in the BSML file1
my $bsmlGenome;

## Store reference of the master reference <Sequence> in BSML file1
my $bsmlSequenceMasterRef;

## id for the reference <Sequence> in the BSML file1
my $sequenceId;

## id for the reference <Sequence> in the BSML file2
my $refSeqId;

## Keep track of the order in which <Sequence> elements were encountered.
my $orderedSequenceList = [];

my $bsmlFeatureTables;

my $logger = BSML::Logger::get_logger("Logger::BSML");

=item new()

B<Description:> Instantiate BSML::Merger object

B<Parameters:> None

B<Returns:> reference to the BSML::Merger object

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

    return $self;
}


=item DESTROY

B<Description:> BSML::Merger class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

    my $self = shift;

}

=item $obj->mergeAndWrite()

B<Description:> Parse the two files and write the two merged trees into a single output file

B<Parameters:> None

B<Returns:> None

=cut

sub mergeAndWrite {

    my $self = shift;

    $self->parseFile1($self->{_file1});
    $self->parseFile2($self->{_file2});
    $self->_mergeAndWrite($self->{_outfile});

}

=item $self->_mergeAndWrite()

B<Description:> Write the two merged trees into a single output file

B<Parameters:> $outfile (scalar - string) name of the output file

B<Returns:> None

=cut

sub _mergeAndWrite {

    my $self = shift;
    my ($outfile) = @_;

    if (!defined($outfile)){
	$logger->logdie("outfile was not specified");
    }

    my $builder = new BSML::BsmlBuilder();
    if (!defined($builder)){
	$logger->logdie("Could not instantiate BSML::Builder");
    }

    $builder->{'doc_name'} = $outfile;

    $builder->{'xrefctr'}++;

    $builder->addGenome($bsmlGenome);

    $builder->addSequence($bsmlSequenceMasterRef);

    foreach my $bsmlSequence (@{$orderedSequenceList}){
	$builder->addSequence($bsmlSequence);
    }

    $builder->write($outfile);
}

=item $self->parseFile1($file)

B<Description:> Parse the master reference BSML file

B<Parameters:> $file (scalar - string) name of the first input BSML file

B<Returns:> None

=cut

sub parseFile1 {

    my $self = shift;
    my ($file1) = @_;

    print "Parsing BSML file '$file1'\n";

    my $genomeCtr=0;
    my $sequenceCtr=0;

    my $parser = new BSML::BsmlParserSerialSearch( GenomeCallBack => sub { 
	$bsmlGenome = shift;
	if ($genomeCtr > 1){
	    $logger->logdie("Encountered more than 1 BSML <Genome> section!");
	}
	
	$genomeCtr++;
    },
						   SequenceCallBack => sub { 
						       
						       $bsmlSequenceMasterRef = shift;
						       
						       $sequenceCtr++;							   
						       
						       if ($sequenceCtr > 1){
							   $logger->logdie("Encountered more than 1 BSML ".
									   "<Sequence> in file '$file1'");
						       }

						       my $class = $bsmlSequenceMasterRef->returnattr('class');
						       if (!defined($class)){
							   $logger->logdie("class was not defined for the ".
									   "<Sequence> in BSML file '$file1'");
						       }
						       
						       if ($class ne 'assembly'){
							   $logger->logdie("Encountered a <Sequence> with ".
									   "class '$class' in BSML file '$file1'");
						       }

						       $sequenceId = $bsmlSequenceMasterRef->returnattr('id');
						       if (!defined($sequenceId)){
							   $logger->logdie("id was not defined for the ".
									   "<Sequence> in BSML file '$file1'");
						       }
						       
						       if ($self->_checkForFeatures($bsmlSequenceMasterRef)){
							   $logger->logdie("Unexpected children for <Sequence> ".
									   "with id '$sequenceId' in file 1 ".
									   "'$file1'");
						       }

						   });
    
    if (!defined($parser)){
	$logger->logdie("Could not instantiate BSML::BsmlParserSerialSearch");
    }
    
    $parser->parse($file1);
}

=item $self->parseFile2($file)

B<Description:> Parse the second BSML file

B<Parameters:> $file (scalar - string) name of the second input BSML file

B<Returns:> None

=cut

sub parseFile2 {

    my $self = shift;
    my ($file2) = @_;

    print "Parsing BSML file '$file2'\n";

    my $referenceSeqCtr=0;

    my $parser = new BSML::BsmlParserSerialSearch( SequenceCallBack => sub { 
	
	my $bsmlSequence = shift;
	
	my $class = $bsmlSequence->returnattr('class');
	if (!defined($class)){
	    $logger->logdie("class was not defined for the <Sequence> ".
			    "in BSML file '$file2'");
	}
	
	if ($class eq 'assembly'){

	    $referenceSeqCtr++;

	    if ($referenceSeqCtr > 1){
		$logger->logdie("Encountered more than one reference ".
				"sequence in BSML file '$file2'");
	    }
	    
	    $refSeqId = $bsmlSequence->returnattr('id');
	    if (!defined($refSeqId)){
		$logger->logdie("id was not defined for the <Sequence> ".
				"in BSML file '$file2'");
	    }

	    if ($refSeqId ne $sequenceId){
		$logger->logdie("The reference <Sequence> id in '$self->{_file1}' ".
				"was '$sequenceId' and does not match the reference ".
				"<Sequence> id in '$file2' which was '$refSeqId'");
	    }

	    
	    if (exists $bsmlSequence->{BsmlFeatureTables}){

		## Get the Feature-tables
		my $bsmlFeatureTables = $bsmlSequence->returnBsmlFeatureTableListR();
		if (!defined($bsmlFeatureTables)){
		    $logger->logdie("bsmlFeatureTables was not defined");
		}

		$bsmlSequenceMasterRef->addBsmlFeatureTables($bsmlFeatureTables);
	    }

	    if (exists $bsmlSequence->{BsmlFeatureGroups}){

		my $bsmlFeatureGroups = $bsmlSequence->returnBsmlFeatureGroupListR();
		if (!defined($bsmlFeatureGroups)){
		    $logger->logdie("bsmlFeatureGroups was not defined");
		}

		$bsmlSequenceMasterRef->addBsmlFeatureGroups($bsmlFeatureGroups);
	    }
	    

	} else {

	    ## Transfer all <Sequence> elements except for the
	    ## reference sequence i.e. the assembly
	    push(@{$orderedSequenceList}, $bsmlSequence);
	}

    });
    

    if (!defined($parser)){
	$logger->logdie("Could not instantiate BSML::BsmlParserSerialSearch");
    }
    
    $parser->parse($file2);
}

=item $self->_checkForFeatures($bsmlSequence)

B<Description:> Verify whether this BSML Sequence has Feature-tables and/or Feature-group children

B<Parameters:> $bsmlSequence (reference to BSML::BsmlSequence)

B<Returns:> $boolean (scalar - unsigned integer) 0 == false, 1 == true

=cut

sub _checkForFeatures {

    my $self = shift;
    my ($bsmlSequence) = @_;

    if (exists $bsmlSequence->{'Feature-tables'}){
	return 1;
    }

    if (exists $bsmlSequence->{'Feature-groups'}){
	return 1;
    }
    
    return 0;
}

1==1; ## end of module
