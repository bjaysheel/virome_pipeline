package BSML2CHADO::Validator;

=head1 NAME

BSML2CHADO::Validator.pm

=head1 VERSION

1.0

=head1 SYNOPSIS

use BSML2CHADO::Validator;

Module for verifying whether the bsml2chado process was successful.

=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS


=over 4

=cut

use strict;
use Carp;
use Data::Dumper;
use Prism;
use BSML::Parser;
use Annotation::Util2;

use constant TRUE  => 1;
use constant FALSE => 0;

use constant BSML_FILE => 0;
use constant REFSEQ    => 1;
use constant MISMATCH_LIST => 2;


=item new()

B<Description:> Instantiate BSML2CHADO::Validator object

B<Parameters:> None

B<Returns:> reference to the BSML2CHADO::Validator object

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

    if (( exists $self->{_prism}) &&
	( defined($self->{_prism}))){
	## okay
    } else {
	$self->_initPrism();
    }

    return $self;
}


sub _initPrism {

    my $self = shift;

    $self->_checkParameters();

    $ENV{PRISM} = "Chado:Sybase:$self->{_server}";

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

 
=item _checkParameters

B<Description:> Check the database connectivity parameters

B<Parameters:> None

B<Returns:> None

=cut

sub _checkParameters {

    my $self = shift;

    if (! (( exists $self->{_username}) && (defined($self->{_username})))){
	confess "username was not defined";
    }

    if (! (( exists $self->{_password}) && (defined($self->{_password})))){
	confess "password was not defined";
    }

    if (! (( exists $self->{_server}) && (defined($self->{_server})))){
	confess "server was not defined";
    }

    if (! (( exists $self->{_database}) && (defined($self->{_database})))){
	confess "database was not defined";
    }
}

=item DESTROY

B<Description:> BSML::Validation::Factory class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

    my $self = shift;

    $self->{_dbh}->disconnect();
}

sub validate {

    my $self = shift;

    $self->_populateIdLookupFromBSMLFiles(@_);
}


sub _isValid {

    my $self = shift;

    $self->_compareBSMLToChado();

    if (( exists $self->{_bsml_to_chado_mismatch_ctr}) &&
	( defined( $self->{_bsml_to_chado_mismatch_ctr})) && 
	( $self->{_bsml_to_chado_mismatch_ctr} > 0 )){
	return FALSE;
    }

    return TRUE;
}


sub _compareBSMLToChado {

    my $self = shift;
    
    my $missingCtr=0;
    my $foundCtr=0;
    my $missingList=[];
    my $ctr=0;

    foreach my $bsmlId (sort keys  %{$self->{_bsml_lookup}}){

	$ctr++;

	if (! exists $self->{_chado_lookup}->{$bsmlId}){
	    push(@{$missingList}, $bsmlId);
	    $missingCtr++;
	} else {
	    $foundCtr++;
	}
    }

    if ($ctr == $foundCtr){
	print "Number of BSML features ($ctr) matches chado feature count ($foundCtr)\n";
    } else {
	print "'$missingCtr' BSML features were not found in the chado feature list\n";
	$self->_storeMismatchData($missingList);
    }

    $self->{_bsml_to_chado_mismatch_ctr} = $missingCtr;
    $self->{_bsml_to_chado_found_ctr} = $foundCtr;

#    print Dumper $self;die;
}
	

sub _storeMismatchData {

    my $self = shift;
    my ($missingList) = @_;

    my $currentBSMLFile = $self->_getCurrentBSMLFile();

    my $currentRefSeq = $self->_getCurrentRefSeq();

    push(@{$self->{_mismatch}}, [$currentBSMLFile, $currentRefSeq, $missingList]);

    $self->{_mismatch_ctr}++;
}



sub _populateIdLookupFromChado {

    my $self = shift;
   
    my $refseq = $self->_getCurrentRefSeq();

    print "Will retrieve uniquename values from the ".
    "database '$self->{_database}' on server ".
    "'$self->{_server}' associated with reference ".
    "sequence '$refseq'\n";

    my $records = $self->{_prism}->{_backend}->getFeatureIdentifiersByRefSequence($refseq);
    if (!defined($records)){
	confess "Could not retrieve records";
    }

    my $ctr=0;
    my $lookup = {};

    foreach my $record (@{$records}){
	$ctr++;
	$lookup->{$record->[0]}++;
    }

    print "Added '$ctr' features to the chado lookup\n";

    $self->{_chado_lookup} = $lookup;
}

sub _getCurrentRefSeq {

    my $self = shift;
    if (( exists $self->{_current_refseq}) && (defined($self->{_current_refseq}))){
	return $self->{_current_refseq};
    } else {
	confess "The current reference sequence identifier is not defined";
    }
}


sub _populateIdLookupFromBSMLFiles {

    my $self = shift;
    
    my $fileList = $self->_getFileList(@_);
    
    if (!Annotation::Util2::checkInputFileStatus($fileList)){
	confess "Detected some problem with file list '$fileList'";
    }

    my $contents = Annotation::Util2::getFileContentsArrayRef($fileList);
    if (!defined($contents)){
	confess "Could not retrieve contents of file '$fileList'";
    }
    
    my $fileCtr=0;

    foreach my $bsmlfile (@{$contents}){

	$fileCtr++;

	$self->{_current_bsml_file} = $bsmlfile;

	$self->_getFeatureIdentifiersFromBSMLFile($bsmlfile);

	$self->_populateIdLookupFromChado();

	if ($self->_isValid()){
	    print "The feature identifier counts for BSML file '$bsmlfile' match database counts\n";
	} else {
	    warn "The feature identifier counts for BSML file '$bsmlfile' do not match database counts\n";
	}

    }

    print "Processed '$fileCtr' BSML files\n";

    if ($self->_detectedMismatches()){
	$self->_printMismatchReport();
    } else {
	$self->_printOk();
    }
}

sub _detectedMismatches {
    my $self = shift;
    if (( exists $self->{_mismatch_ctr}) && 
	( defined($self->{_mismatch_ctr})) &&
	( $self->{_mismatch_ctr} > 0 )){
	return TRUE;
    }

    return FALSE;
}
	
sub _printMismatchReport {

    my $self = shift;

    my $reportfile = $self->_getReportFile();
 
    open (OUTFILE, ">$reportfile") || confess "Could not open report file '$reportfile' in write mode: $!";

    foreach my $set (@{$self->{_mismatch}}){
	my $bsmlfile = $set->[BSML_FILE];
	my $refseq = $set->[REFSEQ];
	my $list   = $set->[MISMATCH_LIST];

	print OUTFILE "For BSML file '$bsmlfile' reference ".
	"sequence '$refseq' - the following features were not found in the database:\n";
	foreach my $feature (@{$list}){
	    print OUTFILE "$feature\n";
	}

	print OUTFILE "\n\n";
    }
}

sub _printOk {

    my $self = shift;

    my $reportfile = $self->_getReportFile();
 
    open (OUTFILE, ">$reportfile") || confess "Could not open report file '$reportfile' in write mode: $!";

    print OUTFILE "All features cited in the BSML files in bsml-file-list ".
    "'$self->{_filelist}' were found in the database '$self->{_database}' ".
    "on server '$self->{_server}'\n";
}

sub _getReportFile {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{reportfile}) && (defined($args{reportfile}))){

	$self->{_reportfile} = $args{reportfile};
    } elsif (( exists $self->{_reportfile}) && (defined($self->{_reportfile}))){
	## okay
    } else {
	$self->{_reportfile} = '/tmp/bsml2chado_validator.txt';
	warn "report file was not defined and therefore was set to '$self->{_reportfile}'\n";
    }

    return $self->{_reportfile};
}


sub _getFeatureIdentifiersFromBSMLFile {

    my $self = shift;
    my ($bsmlfile) = @_;
    if ( ! Annotation::Util2::checkInputFileStatus($bsmlfile)){
	confess "Detected some problem with BSML file '$bsmlfile'";
    }

    my $parser = new BSML::Parser(file=>$bsmlfile);
    if (!defined($parser)){
	confess "Could not instantiate BSML::Parser for BSML file '$bsmlfile'";
    }

    my $lookup = $parser->getLookup();
    if (!defined($lookup)){
	confess "Could not retrieve feature identifier lookup";
    }

    $self->{_bsml_lookup} = $lookup;

    my $currentRefSeq = $parser->getRefSeq();
    if (!defined($currentRefSeq)){
	confess "Could not retrieve reference sequence from BSML file '$bsmlfile'";
    }

    $self->{_current_refseq} = $currentRefSeq;

}

sub _getFileList {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{filelist}) && (defined($args{filelist}))){
	$self->{_filelist} = $args{filelist};
    } elsif (( exists $self->{_filelist}) && (defined($self->{_filelist}))){
	## okay
    } else {
	confess "BSML file list was not defined";
    }

    return $self->{_filelist};
}

sub _getCurrentBSMLFile {

    my $self = shift;

    if (( exists $self->{_current_bsml_file}) &&
	( defined($self->{_current_bsml_file}))){
	return $self->{_current_bsml_file};
    } else {
	confess "current BSML file is not defined";
    }
}

1==1; ## End of module
