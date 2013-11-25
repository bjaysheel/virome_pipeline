package Annotation::Features::FeatureCollection;

=head1 NAME

Annotation::Features::FeatureCollection.pm

=head1 VERSION

1.0

=head1 SYNOPSIS

use Annotation::Features::FeatureCollection;


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS


=over 4

=cut

use strict;
use Annotation::Logger;
use Annotation::Features::Feature;
use Data::Dumper;

## Keep track of the Feature objects to be returned
my $recordIndex=0;

my $logger = Annotation::Logger::get_logger("Logger::Annotation");

=item new()

B<Description:> Instantiate Annotation::Features::FeatureCollection object

B<Parameters:> None

B<Returns:> reference to the Annotation::Features::FeatureCollection object

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

  if ($logger->is_debug()){
      $logger->debug("Initializing '" . __PACKAGE__ ."'");
  }

  return $self;
}


=item DESTROY

B<Description:> Annotation::Features::FeatureCollection class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

  my $self = shift;

  if ($logger->is_debug()){
      $logger->debug("Destroying '" . __PACKAGE__ ."'");
  }
}

=item $self->createAndAddFeature(%args)

B<Description:> Create and add Feature to the collection

B<Parameters:> 

$id (scalar - string)
$length (scalar - unsigned integer)
$moleculeType (scalar - string)
$fmin (scalar - unsigned integer)
$fmax (scalar - unsigned integer)
$product (scalar - string)
$parent (scalar - string)

B<Returns:> None

=cut

sub createAndAddFeature {

    my $self = shift;
    my (%args) = @_;
    
    my $feature = new Annotation::Features::Feature(id=>$args{'id'},
						    moltype=>$args{'moltype'},
						    fmin=>$args{'fmin'},
						    fmax=>$args{'fmax'},
						    product=>$args{'product'},
						    seq=>$args{'seq'},
						    parent=>$args{'parent'});
    if (! defined ($feature)){
	$logger->logdie("Could not instantiated Annotation::Features::Feature ".
			"id '$args{'id'}' moltype '$args{'moltype'}' fmin ".
			"'$args{'fmin'}' fmax '$args{'fmax'}' product ".
			"'$args{'product'}' seq '$args{'seq'}'");
    }

    push(@{$self->{'_collection'}}, $feature);

    if ( exists $self->{'_id_lookup'}->{$args{'id'}}){

	$logger->logdie("id '$args{'id'}' already exists in the  ".
			"collection.  Here is that Feature:" .
			Dumper $self->{'_id_lookup'}->{$args{'id'}});

    } else {

	$self->{'_id_lookup'}->{$args{'id'}} = $feature;
    }


    ## Group the features by parent feature
    if (exists $args{'parent'}){

	push (@{$self->{'_parent_group'}->{$args{'parent'}}}, $feature);

	$self->{'_parent_group_counts'}->{$args{'parent'}}++;

	if (! exists $self->{'_parent_lookup'}->{$args{'parent'}}){

	    $self->{'_parent_lookup'}->{$args{'parent'}} = $feature;

	} else {

	    $logger->warn("parent '$args{'parent'}' already exists in the ".
			  "parent lookup!");
	}
    }


    $self->{'_counter'}++;

}


=item $self->getFeatureByParent(parent=>$parentId)

B<Description:> Retrieve the Feature object that is associated with the specified parent

B<Parameters:>  None

B<Returns:> $feature (Reference to Annotation::Features::Feature)

=cut

sub getFeatureByParent  { 

  my $self = shift;
  my (%args) = @_;

  if ( ! exists $args{'parent'}){
      $logger->logdie("parent was not specified");
  }

  if (exists $self->{'_parent_lookup'}){

      if (exists $self->{'_parent_lookup'}->{$args{'parent'}}){
	  
	  return $self->{'_parent_lookup'}->{$args{'parent'}};

      }
  }

  return undef;

}


=item $self->getFeatureListByParent(parent=>$parentId)

B<Description:> Retrieve the list of Feature objects that are associated with the specified parent

B<Parameters:>  $parent (scalar - string)

B<Returns:> $feature (Reference to Annotation::Features::Feature)

=cut

sub getFeatureListByParent  { 

  my $self = shift;
  my (%args) = @_;

  if ( ! exists $args{'parent'}){
      $logger->logdie("parent was not specified");
  }

  if (exists $self->{'_parent_group'}){

      if (exists $self->{'_parent_group'}->{$args{'parent'}}){
	  
	  return $self->{'_parent_group'}->{$args{'parent'}};

      }
  }

  return undef;

}



=item $self->nextFeatureByParent(parent=>$parentId)

B<Description:> Retrieve the next Feature object that is grouped by the specified parent

B<Parameters:>  None

B<Returns:> $feature (Reference to Annotation::Features::Feature)

=cut

sub nextFeatureByParent  { 

  my $self = shift;
  my (%args) = @_;
  
  if (! exists $args{'parent'}){
      $logger->logdie("parent was not specified");
  }

  my $parentId = $args{'parent'};
  
  if (( exists $self->{'_parent_group_counts'}->{$parentId}) && 
      ( $self->{'_parent_group_counts'}->{$parentId} > 0)) {
      
      ## Okay, we should have some Feature objects that belong to
      ## this parent which we can iterate over.

      if (( ! exists $self->{'_next_feature_by_parent_called'}) ||
	  (exists $self->{'_next_feature_by_parent_called'} != 1)){

	  ## If this is the first time we're calling this method,
	  ## we need to initialize each counter for each parent.

	  $self->_initialAllParentCounters();
      }


      if ( $self->{'_pIndex'}->{$parentId} < $self->{'_parent_group_counts'}->{$parentId} ){
      
	  return $self->{'_parent_group'}->{$parentId}->[$self->{'_pIndex'}->{$parentId}++];

      } else {

	  $logger->warn("No more Feature objects associated with parent '$parentId'");

	  return undef;
      }

  } else {

      $logger->logdie("There are no Feature objects in the ".
		      "collection that are associated with ".
		      "parent '$parentId'");
  }
}

=item $self->_initialAllParentCounters()

B<Description:> Initialize the counters to for parent groups

B<Parameters:>  None

B<Returns:> None

=cut

sub _initialAllParentCounters {

    my $self = shift;

    foreach my $parentId (keys %{$self->{'_parent_group'}}){

	$self->{'_pIndex'}->{$parentId} = 0;
    }


    ## Don't call this again
    $self->{'_next_feature_by_parent_called'} = 1;
   
}

=item $self->_unInitialAllParentCounters()

B<Description:> Uninitialize the indexes counters to for parent groups

B<Parameters:>  None

B<Returns:> None

=cut

sub _unInitialAllParentCounters {

    my $self = shift;

    foreach my $parentId (keys %{$self->{'_pindex'}}){

	delete $self->{'_pIndex'}->{$parentId};
    }

    delete $self->{'_next_feature_by_parent_called'};
   
}


=item $self->nextFeature()

B<Description:> Retrieve the next Feature object

B<Parameters:>  None

B<Returns:> $feature (Reference to Annotation::Features::Feature)

=cut

sub nextFeature  { 

  my $self = shift;
  
  if (( exists $self->{'_counter'}) && 
      ( $self->{'_counter'} > 0)) {

      if ( $recordIndex < $self->{'_counter'} ){
      
	  return $self->{'_collection'}->[$recordIndex++];

      } else {

	  $logger->warn("No more Feature objects in the collection");

	  return undef;
      }

  } else {

      $logger->logdie("There are no Feature objects in the collection");
  }
}


=item $self->getCount()

B<Description:> Retrieve the number of Feature objects in the collection

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


=item $self->getFeatureById($id)

B<Description:> Retrieve the Feature object given the specified identifier

B<Parameters:>  $id (scalar - string)

B<Returns:> $feature (reference to Annotation::Features::Feature)

=cut

sub getFeatureById  { 

  my $self = shift;
  my ($id) = @_;
  
  if (!defined($id)){
      $logger->logdie("id was not defined");
  }

  if ( exists $self->{'_id_lookup'}){

      if ( exists $self->{'_id_lookup'}->{$id}){

      
	  return $self->{'_id_lookup'}->{$id};

      } 
  }

  return undef;
}


sub getFeatNameList {

    my $self = shift;
    if (( exists $self->{_feat_name_list}) && (defined($self->{_feat_name_list}))){
	return $self->{_feat_name_list};
    } else {
	
	my $list=[];
	my $ctr=0;

	foreach my $feat_name (keys %{$self->{_id_lookup}}){
	    push(@{$list}, $feat_name);
	    $ctr++;
	}
	print "Added '$ctr' feat_name values to the list\n";

	$self->{_feat_name_list} = $list;

	return $self->{_feat_name_list};
    }
}

sub getParentFeatNameList {

    my $self = shift;
    if (( exists $self->{_parent_feat_name_list}) && (defined($self->{_parent_feat_name_list}))){
	return $self->{_parent_feat_name_list};
    } else {
	
	my $list=[];
	my $ctr=0;

	foreach my $feat_name (keys %{$self->{_parent_group}}){
	    push(@{$list}, $feat_name);
	    $ctr++;
	}
	print "Added '$ctr' feat_name values to the list\n";

	$self->{_parent_feat_name_list} = $list;

	return $self->{_parent_feat_name_list};
    }
}



1==1; ## end of module
