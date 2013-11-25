package Annotation::Gopher::EventMap::FileReader;

=head1 NAME

Annotation::Gopher::EventMap::FileReader.pm

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
use Annotation::Util2;
use Carp;
use Data::Dumper;

my $logger = Annotation::Logger::get_logger("Logger::Annotation");

## Expected column headers
my @columnHeaders = ('EventObject_id', 'Name', 'ObjectType', 'Reference', 'ReferenceType');

## GOPHER identifier value length
my $GOPHER_ID_LENGTH = 13;


=item new()

B<Description:> Instantiate Annotation::Gopher::EventMap::FileReader object

B<Parameters:> None

B<Returns:> reference to the Annotation::Gopher::EventMap::FileReader object

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

  $self->_loadEventMapLookup();

}


=item DESTROY

B<Description:> Annotation::Gopher::EventMap::FileReader class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  {
  my $self = shift;

}


sub getFileName {

    my $self = shift;

    if (! exists $self->{'_filename'}){
	$logger->logdie("filename was not defined:" . Dumper $self);
    }

    return $self->{'_filename'};
}

=item $self->_loadEventMapLookup()

B<Description:> Read in the contents of the events maps file and load the lookup

B<Parameters:> None

B<Returns:> None

=cut

sub _loadEventMapLookup {

    my $self = shift;

    my $file = $self->getFileName();

    if (!defined($file)){

	$logger->logdie("file was not defined");
    }

    if (! Annotation::Util2::checkInputFileStatus($file)){

	$logger->logdie("Detected some problem with file ".
			"'$file'.  Please view the log file.");
    }

    my $contents = Annotation::Util2::getFileContentsArrayRef($file);

    if (!defined($contents)){

	$logger->logdie("Could not retrieve contents from GOPHER ".
			"events maps file '$file'");
    }

    
    my $lineCtr=0;
    my $recordCtr=0;

    foreach my $line (@{$contents}){

	$lineCtr++;

	if ($line =~ /^\s*$/){
	    $logger->logdie("Unexpected blank line in file '$file' at line '$lineCtr'");
	}

	if ($lineCtr ==  1){
	    ## The header
	    my @header = split(/\s+/, $line);
	    
	    $self->_validateColumnHeaders(\@header);

	    next;
	}

	my @values = split(/\s+/, $line);

	if (scalar(@values) != 5){
	    $logger->logdie("At line '$lineCtr' in file '$file', did not ".
			    "find exactly 5 fields.");
	}

	if ($values[2] ne 'gopher_id'){
	    $logger->logdie("Column 3 in GOPHER events maps file '$file' ".
			    "was '$values[2]'.  Was expecting a value of ".
			    "'gopher_id' instead.");
	}

	if ($values[4] ne 'accession'){
	    $logger->logdie("Column 5 in GOPHER events maps file '$file' ".
			    "was '$values[4]'.  Was expecting a value of ".
			    "'accession' instead.");
	}

	
	if (! exists $self->{'_event_id'}->{$values[0]}){

	    $self->_validateEventId($values[0], $lineCtr);

	    $self->{'_event_id'}->{$values[0]} = [$values[1], $values[3]];

	} else {
	    $logger->logdie("Encountered event_id '$values[0]' again at ".
			    "line '$lineCtr' in file '$file'");
	}

	if (! exists $self->{'_gopher_id'}->{$values[1]}){

	    $self->_validateGopherId($values[1], $lineCtr);

	    $self->{'_gopher_id'}->{$values[1]} = [$values[0], $values[3]];

	} else {
	    $logger->logdie("Encountered gopher_id '$values[1]' again at ".
			    "line '$lineCtr' in file '$file'");
	}

	if (! exists $self->{'_accession_id'}->{$values[3]}){

	    $self->{'_accession_id'}->{$values[3]} = [$values[0], $values[1]];

	} else {
	    $logger->logdie("Encountered accession '$values[3]' again at ".
			    "line '$lineCtr' in file '$file'");
	}

	$recordCtr++;
    }

    if ($recordCtr > 0 ){

	print "Processed '$lineCtr' lines and read in ".
	"'$recordCtr' records from file '$file'\n";

	$self->{'_lookup_count'} = $recordCtr;

	$self->{'_is_lookup_loaded'} = 1;

    } else {

	$logger->logdie("No lines were read in from file ".
			"'$file'");
    }
}


sub _validateColumnHeaders {

    my $self = shift;
    my ($headers) = @_;

    my $ctr = -1;

    my $file = $self->getFileName();
    if (!defined($file)){
	$logger->logdie("file was not defined!");
    }

    foreach my $header (@{$headers}){
	$ctr++;
	if ($header ne $columnHeaders[$ctr]){
	    $logger->fatal("Column header '$header' did not match expected ".
			   "value '$columnHeaders[$ctr]' in Gopher events ".
			   "maps file '$file'");
	}
    }

    if ($ctr > 4 ){
	$ctr++;
	$logger->logdie("Encountered '$ctr' column headers when was only ".
			"expecting 5 in file '$file'");
    }

    if ($logger->is_info()){
	$logger->info("All '$ctr' column headers were valid in GOPHER ".
		      "events maps file '$file'.");
    }
}
	
sub _validateEventId {

    my $self = shift;

    my ($event_id, $lineCtr) = @_;

    if ( $event_id != int($event_id)){

	$logger->logdie("Found '$event_id' in field 1 at line '$lineCtr' ".
			"in file '$self->getFileName()'.  Was expected an ".
			"unsigned integer value.");
    }
    
    my $len = length($event_id);

    if ($len != $GOPHER_ID_LENGTH){
	$logger->logdie("event_id '$event_id' has '$len' digits.  Was ".
			"expecting '$GOPHER_ID_LENGTH' at line '$lineCtr' ".
			"in file '$self->getFileName()'");
    }
}

sub _validateGopherId {

    my $self = shift;

    my ($gopher_id, $lineCtr) = @_;

    if ( $gopher_id != int($gopher_id)){

	$logger->logdie("Found '$gopher_id' in field 1 at line '$lineCtr' ".
			"in file '$self->getFileName()'.  Was expected an ".
			"unsigned integer value.");
    }
    
    my $len = length($gopher_id);

    if ($len != $GOPHER_ID_LENGTH){
	$logger->logdie("gopher_id '$gopher_id' has '$len' digits.  Was ".
			"expecting '$GOPHER_ID_LENGTH' at line '$lineCtr' ".
			"in file '$self->getFileName()'");
    }
}

=item $self->getAccessionByEventId($event_id)

B<Description:> Retrieve the accession for the specified event_id

B<Parameters:> $event_id (scalar - unsigned integer)

B<Returns:> $accession (scalar - string)

=cut

sub getAccessionByEventId {
    
    my $self = shift;

    my ($event_id) = @_;

    if (!defined($event_id)){
	$logger->logdie("event_id was not defined");
    }

    if (! $self->_isLookupLoaded()){

	$logger->logdie("The lookup has not yet been loaded!");
    }


    if ( exists $self->{'_event_id'}){

	if ( exists $self->{'_event_id'}->{$event_id}){

	    if ( defined $self->{'_event_id'}->{$event_id}->[1]){

		return $self->{'_event_id'}->{$event_id}->[1];

	    }

	} else {
		
	    $logger->warn("accession was not defined for event_id ".
			  "'$event_id' in file '$self->getFileName()'");

	    return undef;
	}
    } else {

	$logger->logdie("Internal error.  The event_id lookup table ".
			"is not defined!:" . Dumper $self);
    }
}

=item $self->getAccessionByGopherId($gopher_id)

B<Description:> Retrieve the accession for the specified gopher_id

B<Parameters:> $gopher_id (scalar - unsigned integer)

B<Returns:> $accession (scalar - string)

=cut

sub getAccessionByGopherId {
    
    my $self = shift;

    my ($gopher_id) = @_;

    if (!defined($gopher_id)){
	$logger->logdie("gopher_id was not defined");
    }

    if (! $self->_isLookupLoaded()){

	$logger->logdie("The lookup has not yet been loaded!");
    }


    if ( exists $self->{'_gopher_id'} ){

	if ( defined $self->{'_gopher_id'}->{$gopher_id}){

	    if ( defined $self->{'_gopher_id'}->{$gopher_id}->[1]){

		return $self->{'_gopher_id'}->{$gopher_id}->[1];

	    } 
	}

	$logger->warn("accession was not defined for gopher_id ".
		      "'$gopher_id' in file '$self->getFileName()'");

	return undef;

    } else {

	$logger->fatal("The gopher_id lookup table ".
			"is not defined!:" . Dumper $self);

	$logger->logdie("Internal error!");
    }
}


=item $self->getEventIdByAccession($accession)

B<Description:> Retrieve the event_id for the specified accession

B<Parameters:> $accession (scalar - string)

B<Returns:> $event_id (scalar - unsigned integer)

=cut

sub getEventIdByAccession {
    
    my $self = shift;

    $logger->logdie("Method has not been implemented");

}

=item $self->getEventIdByGopherId($gopher_id)

B<Description:> Retrieve the event_id for the specified gopher_id

B<Parameters:> $gopher_id (scalar - unsigned integer)

B<Returns:> $event_id (scalar - unsigned integer)

=cut

sub getEventIdByGopherId {
    
    my $self = shift;

    $logger->logdie("Method has not been implemented");

}

=item $self->getGopherIdByEventId($event_id)

B<Description:> Retrieve the gopher_id for the specified event_id

B<Parameters:> $event_id (scalar - unsigned integer)

B<Returns:> $gopher_id (scalar - unsigned integer)

=cut

sub getGopherIdByEventId {
    
    my $self = shift;

    $logger->logdie("Method has not been implemented");

}


=item $self->getGopherIdByAccession($accession)

B<Description:> Retrieve the gopher_id for the specified accession

B<Parameters:> $accession (scalar - string)

B<Returns:> $gopher_id (scalar - unsigned integer)

=cut

sub getGopherIdByAccession {
    
    my $self = shift;

    $logger->logdie("Method has not been implemented");

}

=item $self->_isLookupLoaded()

B<Description:> Verify whether the lookup has been loaded

B<Parameters:> None

B<Returns:> $boolean (scalar - unsigned int) 0 for false, 1 for true

=cut

sub _isLookupLoaded {

    my $self = shift;

    if (exists $self->{'_is_lookup_loaded'}){

	if ($self->{'_is_lookup_loaded'} == 1 ){

	    return 1;
	}
    }

    return 0;
}


1==1;
## end of module
