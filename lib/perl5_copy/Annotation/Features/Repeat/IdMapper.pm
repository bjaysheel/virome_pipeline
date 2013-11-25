package Annotation::Features::Repeat::IdMapper;

=head1 NAME

Annotation::Features::Repeat::IdMapper.pm

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


=item new()

B<Description:> Instantiate Annotation::Features::Repeat::IdMapper object

B<Parameters:> None

B<Returns:> reference to the Annotation::Features::Repeat::IdMapper object

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

  $self->_loadRepeatMappingLookup();

}


=item DESTROY

B<Description:> Annotation::Features::Repeat::IdMapper class destructor

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

=item $self->_loadRepeatMappingLookup()

B<Description:> Read in the contents of the mapping file and load the lookup

B<Parameters:> None

B<Returns:> None

=cut

sub _loadRepeatMappingLookup {

    my $self = shift;

    my $repeatMappingFile = $self->getFileName();

    if (!defined($repeatMappingFile)){

	$logger->logdie("repeatMappingFile was not defined");
    }

    if (! Annotation::Util2::checkInputFileStatus($repeatMappingFile)){

	$logger->logdie("Detected some problem with file ".
			"'$repeatMappingFile'.  Please view the log file.");
    }

    my $contents = Annotation::Util2::getFileContentsArrayRef($repeatMappingFile);

    if (!defined($contents)){

	$logger->logdie("Could not retrieve contents from repeat ".
			"mapping file '$repeatMappingFile'");
    }

    
    my $lineCtr=0;
    my $recordCtr=0;

    foreach my $line (@{$contents}){

	$lineCtr++;

	if ($line =~ /^\s*$/){
	    next;
	}

	$recordCtr++;

	my ($oldid, $newid) = split(/\t/, $line);
#	my ($oldid, $newid) = split(/\s+/, $line);

	if (!defined($newid)){
	    $logger->logdie("Second column at line '$lineCtr' in file ".
			    "'$repeatMappingFile' did not have a value!  ".
			    "The column 1 value was '$oldid'.");
	}

	if (! exists $self->{'_lookup'}->{$oldid}){

	    $self->{'_lookup'}->{$oldid} = $newid;

	} else {
	    $logger->logdie("Encountered oldid '$oldid' in repeat mapping ".
			    "file '$repeatMappingFile' a second time");
	}
    }

    if ($recordCtr > 0 ){

	print "Processed '$lineCtr' lines and read in ".
	"'$recordCtr' repeat identifier mappings\n";

	$self->{'_lookup_count'} = $recordCtr;

	$self->{'_is_lookup_loaded'} = 1;

    } else {

	$logger->logdie("No lines were read in from file ".
			"'$self->{'_filename'}'");
    }

}

=item $self->getId($oldid)

B<Description:> Given an identifier value, fetch corresponding value in the lookup and return value if found

B<Parameters:> $oldid (scalar - string)

B<Returns:> $newid (scalar - string)

=cut

sub getId {
    
    my $self = shift;

    my ($oldid) = @_;

    if (!defined($oldid)){
	$logger->logdie("oldid was not defined");
    }

    if (! $self->_isLookupLoaded()){

	$logger->logdie("The lookup has not yet been loaded!");
    }

    if ( exists $self->{'_lookup'}){

	if ( exists $self->{'_lookup'}->{$oldid}){

	    return $self->{'_lookup'}->{$oldid};

	} else {

	    $logger->warn("oldid '$oldid' did not exist ".
			  "in the lookup");

	    return undef;
	}

    } else {

	$logger->logdie("Logic error.  The lookup does ".
			"not exist!:" . Dumper $self);
    }
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
