package BSML::FeatureRelationshipLookup;

use strict;
use warnings;
use XML::Twig;
use Carp;
use File::OpenFile qw(open_file);

sub new {
    my ($class, %args) = @_;

    my $self = {
        '_bsml' => undef,
        '_lookup' => undef,
    };

    bless($self, $class);
    $self->_init( %args );
    return $self;
}

sub add_bsml {
    my ($self, @bsml_files) = @_;
    
    foreach my $bsml ( @bsml_files ) {
        $self->_parse_bsml( $bsml );
    }
}

#Name: add_to_lookup
#Desc: adds a hash to the lookup
#Args: $hash->{$class} = $id
#      $hash->{'transcript'} = 'kev1.transcript.1234.1'
#      $hash->{'gene'} = 'kev1.gene.1234.1'
#      etc...
#Rets: nothing
#      Will store a reference of the hash, keyed by each id found
sub add_to_lookup {
    my ($self, $hash) = @_;
    
    foreach my $id ( values( %{$hash} ) ) {
        $self->{'_lookup'}->{$id} = $hash;
    }

}

sub lookup {
    my ($self, $id, $class) = @_;
    my $retval;

    if( exists( $self->{'_lookup'}->{$id} ) ) {
        if( exists( $self->{'_lookup'}->{$id}->{$class} ) ) {
            $retval = $self->{'_lookup'}->{$id}->{$class};
        } else {
            croak("Could not find $class id in lookup for $id");
        }
    } else {
        croak("Could not find $id in lookup");
    }

    return $retval;    
}

sub get_ids {
    my ($self, $class) = @_;
    my $retval;
    if( $class ) {
        map{ $retval->{$self->{'_lookup'}->{$_}->{$class}} = 1 } keys( %{$self->{'_lookup'}} );
    } else {
        map{ $retval->{$_} = 1 } keys( %{$self->{'_lookup'}} );
    }
    return keys %{$retval};
}

############### private sub ###############
sub _init {
    my ($self, %args) = @_;
    
    if( $args{'bsml'} ) {
        $self->{'_bsml'} = $args{'bsml'};
        $self->_parse_bsml( $args{'bsml'} );
    }
    
}

sub _parse_bsml {
    my ($self, $bsml) = @_;
    my @files = ($bsml);

    # is this an array ref to many bsml files?
    if( ref( $bsml ) eq 'ARRAY' ) {
        @files = @{$bsml};
    }
    
    my $twig = new XML::Twig( 'twig_handlers' => {
        'Feature-group' => sub {
            my ($twig, $fg) = @_;
            my @fgms = $fg->children( 'Feature-group-member' );
            $self->_add_feature_group_members_to_lookup( @fgms );
            $twig->purge();
        } } );

    foreach my $file (@files) {

        my $in = open_file( $file, 'in' );
        $twig->parse( $in );
        close($in);

    }

}

sub _add_feature_group_members_to_lookup {
    my ($self, @fgms) = @_;
    
    my $tmp;
    foreach my $fgm ( @fgms ) {
        my $feat_id = $fgm->att('featref');
        my $class = $fgm->att('feature-type');

        $tmp->{$class} = $feat_id;
    }

    $self->add_to_lookup( $tmp );
}
1==1;
