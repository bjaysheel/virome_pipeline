package Prism::IdManager;

=head1 NAME

Prism::IdManager.pm

=head1 VERSION

1.0

=head1 SYNOPSIS


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

new
_init
DESTROY
setOldIdN
setOldId
getOldIdN
getOldId
removeOldIdN
removeOldId
setNewIdN
setNewId
getNewId
getNewIdN
getNewId
removeNewIdN
removeNewId
setPairN
setPair
removePairN
removePair
setMapFileExtension
getMapFileExtension
setMapFilename
getMapFilename
verifyLookups
loadIdMappingLookup
loadIdMappingLookupFromFile
writeIdMappingFile


=over 4

=cut

use strict;
use Carp;
use Data::Dumper;
use Prism::IdMapper;
use Ergatis::IdGenerator;

my $defaultExtension = 'idmap';

=item new()

B<Description:> Instantiate Prism::IdManager object

B<Parameters:> None

B<Returns:> reference to the Prism::IdManager object

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


    $self->_initializeMapper();

    $self->_initializeGenerator();

    $self->_setProject();

    return $self;
}

sub _initializeMapper {

    my $self = shift;
    my $mapper = new Prism::IdMapper(indir  => $self->{_indir},
				     infile => $self->{_infile},
				     outfile => $self->{_outfile});
    if (!defined($mapper)){
	confess "Could not instantiate Prism::IdMapper";
    }

    $self->{_mapper} = $mapper;
}

sub _initializeGenerator {

    my $self = shift;
    my $generator;

    eval {
	$generator = new Ergatis::IdGenerator(id_repository=>$self->{_id_repository});
    };

    if ($@){
	confess "Encountered some error during Ergatis::IdGenerator constructor call: $@ $!";
    }

    if (!defined($generator)){
	confess "Could not instantiate Ergatis::IdGenerator";
    }

    $self->{_generator} = $generator;
}


sub _setProject {

    my $self = shift;
    $self->{_project} = $self->{_database};
}


=item DESTROY

B<Description:> Prism::IdManager class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  {

    my $self = shift;

}


sub setOldIdN {

    my $self = shift;
    $self->{_mapper}->setOldIdN(@_);
}

sub setOldId {

    my $self = shift;
    $self->{_mapper}->setOldId(@_);
}

sub getOldIdN {

    my $self = shift;
    return $self->{_mapper}->getOldIdN(@_);
}

sub getOldId {

    my $self = shift;
    return $self->{_mapper}->getOldId(@_);
}

sub removeOldIdN {

    my $self = shift;
    $self->{_mapper}->removeOldIdN(@_);
}

sub removeOldId {

    my $self = shift;
    $self->{_mapper}->removeOldId(@_);
}

sub setNewIdN {

    my $self = shift;
    $self->{_mapper}->setNewIdN(@_);
}

sub setNewId {

    my $self = shift;
    $self->{_mapper}->setNewId(@_);
}

sub getNewIdN {

    my $self = shift;
    return $self->{_mapper}->getNewIdN(@_);
}
sub getNewId {

    my $self = shift;
    return  $self->{_mapper}->getNewId(@_);
}

sub removeNewIdN {

    my $self = shift;
    $self->{_mapper}->removeNewIdN(@_);
}

sub removeNewId {

    my $self = shift;
    $self->{_mapper}->removeNewId(@_);
}

sub setPairN {

    my $self = shift;
    $self->{_mapper}->setPairN(@_);
}

sub setPair {

    my $self = shift;
    $self->{_mapper}->setPair(@_);
}

sub removePairN {

    my $self = shift;
    $self->{_mapper}->removePairN(@_);
}

sub removePair {

    my $self = shift;
    $self->{_mapper}->removePair(@_);
}

sub setMapFileExtension {

    my $self = shift;
    $self->{_mapper}->setMapFileExtension(@_);
}

sub getMapFileExtension {

    my $self = shift;
    return $self->{_mapper}->getMapFileExtension(@_);
}

sub setMapFilename {

    my $self = shift;
    $self->{_mapper}->setMapFilename(@_);
}

sub getMapFilename {

    my $self = shift;
    return $self->{_mapper}->getMapFilename(@_);
}

sub verifyLookups {

    my $self = shift;
    return $self->{_mapper}->verifyLookups(@_);
}

sub writeIdMappingFile {

    my $self = shift;
    my $outfile = $self->_getOutputMappingFile(@_);
    $self->{_mapper}->writeIdMappingFile($outfile);
}

sub _getOutputMappingFile {
    my $self = shift;
    my (%args) = @_;

    if (( exists $args{outfile}) && (defined($args{outfile}))){
	$self->{_outfile} = $args{outfile};
    } elsif (( exists $self->{_outfile}) && (defined($self->{_outfile}))){
	##
    } else {
	confess "output ID mapping file was not defined";
    }

    return $self->{_outfile};
}


sub loadIdMappingLookupN {

    my $self = shift;
    my (%args) = @_;
    $self->{_mapper}->loadIdMappingLookup($args{'directories'}, $args{'infile'});
}

sub loadIdMappingLookup {

    my $self = shift;
    $self->{_mapper}->loadIdMappingLookup(@_);
}

sub loadIdMappingLookupFromFile {

    my $self = shift;
    $self->{_mapper}->loadIdMappingLookupFromFile(@_);
}

sub _nextFeature {

    my $self = shift;
    my ($type, $old) = @_;

    if (!defined($old)){

	my $new = $self->{_generator}->next_id(project=>$self->{_project}, type=>$type);
	if (!defined($new)){
	    confess "Could not retrieve next id for type '$type'";
	}
	
	$self->{_mapper}->setPair($old, $new);

	return $new;

    } else {

	if ( exists $self->{_type_lookup}->{$type}->{$old}){
	    return $self->{_type_lookup}->{$type}->{$old};
	} else {

	    my $new = $self->{_mapper}->getNewId($old);
	    
	    if (!defined($new)){
		
#	    print "project '$self->{_project}' type '$type' old '$old'\n";
		
		$new = $self->{_generator}->next_id(project=>$self->{_project}, type=>$type);
		if (!defined($new)){
		    confess "Could not retrieve next id for type '$type'";
		}
		
#	    die "project '$self->{_project}' type '$type' old '$old' new '$new'\n";
		$self->{_mapper}->setPair($old, $new);
	    }	
	    
	    $self->{_type_lookup}->{$type}->{$old} = $new;

	    return $new;    
	}
    }
}


sub nextGene {

    my $self = shift;
    my ($old) = @_;
    return $self->_nextFeature('gene', $old);
}

sub nextTranscript {

    my $self = shift;
    my ($old) = @_;
    return $self->_nextFeature('transcript', $old);
}

sub nextCDS {

    my $self = shift;
    my ($old) = @_;
    return $self->_nextFeature('CDS', $old);
}

sub nextPolypeptide {

    my $self = shift;
    my ($old) = @_;
    return $self->_nextFeature('polypeptide', $old);
}

sub nextExon {

    my $self = shift;
    my ($old) = @_;
    return $self->_nextFeature('exon', $old);
}

sub nextAssembly {

    my $self = shift;
    my ($old) = @_;
    my $id = $self->_nextFeature('assembly', $old);
    if (!defined($id)){
	confess "id was not defined or old assembly id '$old'";
    }

    return $id;
}

1==1; ## end of module
