package Accession::Util;

use strict;
use Carp;
use Prism;
use Prism::Util;
use Annotation::Logger;

use constant ASMBL_ID     => 0;
use constant FEAT_NAME    => 1;
use constant ACCESSION_DB => 2;
use constant ACCESSION_ID => 3;


=item new()

B<Description:> Instantiate Accession::Util object

B<Parameters:> None

B<Returns:> reference to the Accession::Util object

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

  if (! exists $self->{_database}){
      confess "database was not specified";
  }

  if (! exists $self->{_prism}){

      if (! exists $self->{_username}){
	  $self->{_username} = 'access';
      }
      if (! exists $self->{_password}){
	  $self->{_password} = 'access';
      }

      my $prism = new Prism(user => $self->{_username},
			    password => $self->{_password},
			    db => $self->{_database});

      if (!defined($prism)){
	  confess "Could not instantiate Prism";
      }

      $self->{_prism} = $prism;
  }

  if (! exists $self->{_logger}){
      my $logger = Annotation::Logger::get_logger("Logger::Annotation");
      $self->{_logger} = $logger;
  }

  
  if (! exists $self->{_accession_database_lookup}){
      $self->_loadAccessionDatabaseLookup();
  }


  return $self;
}

sub _loadAccessionDatabaseLookup {

    my $self = shift;

    $self->{_accession_database_lookup} = { 'PID'        => 'NCBI_gi',
					    'protein_id' => 'Genbank',
					    'SP'         => 'Swiss-Prot',
					    'ECOCYC'     => 'Ecocyc' };
}

sub DESTROY {
    
    my $self = shift;
    ## Nothing special
}

sub getLookup {

    my $self = shift;
    my (%args) = @_;

    if (!(exists $self->{_lookup}) || (!defined($self->{_lookup}))){
	$self->_buildLookup(@_);
    }

    return $self->{_lookup};
}

sub _buildLookup {

    my $self = shift;
    my (%args) = @_;
    
    my $asmbl_id = $self->_getAsmblId(@_);

    my $schema_type = $self->_getSchemaType(@_);

    my $records = $self->{_prism}->accession_data($asmbl_id, 
						  $self->{_database},
						  $schema_type);
    
    if (!defined($records)){
	confess "records was not defined";
    }

    my $nullCtr=0;

    my $lookup={};

    foreach my $record ( @{$records} ) {
	
	if ((!defined($record->[ACCESSION_ID])) || (lc($record->[ACCESSION_ID]) eq 'null') || ($record->[ACCESSION_ID] eq '')){
	    $self->{_logger}->warn("Excluding accession record for ".
				   "feat_name '$record->[FEAT_NAME]' with ".
				   "database '$record->[ACCESSION_DB]' because ".
				   "accession.accession_id is not defined");
	    $nullCtr++;
	    next;
	}


	my $feat_name = Prism::Util::removeParentheses($record->[FEAT_NAME]);
	
	my $accession_db = $record->[ACCESSION_DB];

	if ( exists $self->{_accession_database_lookup}->{$accession_db}) {
	    
	    $accession_db = $self->{_accession_database_lookup}->{$accession_db};
	}

	$lookup->{$record->[ASMBL_ID]}->{$feat_name}->{$accession_db} = $record->[ACCESSION_ID];
	## An even more condensed, efficient data structure would be a
	## two-level deep hash keyed on asmbl_id and feat_name with value
	## being a reference to a two dimensional array [accession_db, accession_id].
    }


    if ($nullCtr > 0 ){
	print "Excluded '$nullCtr' accession records because ".
	"of undefined accession.accession_id values\n";
    }

    $self->{_lookup} = $lookup;
}

sub _getAsmblId {

    my $self = shift;
    my (%args) = @_;
    
    if (( exists $args{asmbl_id}) && (defined($args{asmbl_id}))){

	return $args{asmbl_id};

    } elsif (( exists $self->{_asmbl_id}) && (defined($self->{_asmbl_id}))){

	return $self->{_asmbl_id};

    } else {

	confess "asmbl_id was not specified";
    }
}

sub _getSchemaType {

    my $self = shift;
    my (%args) = @_;
    
    my $schema_type;

    if (( exists $args{schema_type}) && (defined($args{schema_type}))){

	$schema_type = $args{schema_type};

    } elsif (( exists $self->{_schema_type}) && (defined($self->{_schema_type}))){

	$schema_type = $self->{_schema_type};

    } else {

	confess "schema_type was not specified";
    }

    return $schema_type;
}

1==1; ## end of module
