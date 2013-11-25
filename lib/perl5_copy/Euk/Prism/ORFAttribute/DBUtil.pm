package Euk::Prism::ORFAttribute::DBUtil;

use strict;
use Carp;
use Prism;
use Prism::Util;
use Annotation::Logger;
use base "Prism::DBUtil";

use constant ASMBL_ID  => 0;
use constant FEAT_NAME => 1;
use constant SCORE     => 2;
use constant ATT_TYPE  => 3;
use constant SCORE2    => 4;
use constant CURATED   => 5;

use constant MW       => 0;
use constant PI       => 1;
use constant PARTIAL5 => 2;
use constant PARTIAL3 => 3;
use constant SP_HMM   => 4;
use constant TARGETP  => 5;


my $FEATURE_TYPE = 'ORFAttribute';

=item new()

B<Description:> Instantiate Euk::Prism::ORFAttribute::DBUtil object

B<Parameters:> None

B<Returns:> reference to the Euk::Prism::ORFAttribute::DBUtil object

=cut

sub new  {

  my $class = shift;

  my $self = {};

  bless $self, $class;

  return SUPER::_init(@_);

}

=item $self->_loadLookups()

B<Description:> Load any special lookups

B<Parameters:> None

B<Returns:> None

=cut

sub _loadLookups {

    my $self = shift;

}

=item $self->_buildLookup()

B<Description:> Retrieve the data from the database, process it, store it in a Perl hash

B<Parameters:> $args{asmbl_id} (scalar - unsigned integer) optional

B<Returns:> None

=cut

sub _buildLookup {

    my $self = shift;

    my $asmbl_id = $self->_getAsmblId(@_);

    ##
    ## Note that the records returned are now those originally return by
    ## both Euk::Prism::EukPrismDB::get_model_orf_attributes_is_partial 
    ## (for legacy2bsml.pl's create_euk_cds_orf_attributes_lookup)
    ## AND 
    ## Euk::Prism::EukPrismDB::get_gene_orf_attributes 
    ## (for legacy2bsml.pl's create_euk_polypeptide_orf_attributes_lookup
    ##
    
    my $records = $self->{_prism}->modelORFAttributes($asmbl_id,
						      $self->{_database});

    if (!defined($records)){
	confess "records was not defined";
    }

    my $ctr=0;

    my $lookup = {};

    foreach my $record ( @{$records} ) {

	my $feat_name = Prism::Util::cleanse_uniquename($record->[FEAT_NAME]);
	
	my $att_type = $record->[ATT_TYPE];

	if (lc($att_type) eq 'is_partial'){
	
	    my $fivePrimePartial = $record->[SCORE];
	    
	    if ((defined($fivePrimePartial)) && ($fivePrimePartial ne '') && (lc($fivePrimePartial) ne 'null')){
		
		$lookup->{$feat_name}->[PARTIAL5] = $fivePrimePartial;
	    }
	    
	    my $threePrimePartial = $record->[SCORE2];
	    
	    if ((defined($threePrimePartial)) && ($threePrimePartial ne '') && (lc($threePrimePartial) ne 'null')){
		
		$lookup->{$feat_name}->[PARTIAL3] = $threePrimePartial;
	    }

	} else {

	    my $score = $record->[SCORE];
	    
	    if ((!defined($score)) || ($score eq '') || (lc($score) eq 'null')){
		$self->{_logger}->warn("invalid score for att_type '$att_type ".
				       "while processing feat_name '$feat_name'");
		next;
	    }

	    if (lc($att_type) eq 'mw'){
		
		$lookup->{$feat_name}->[MW] = $score;

	    } elsif (lc($att_type) eq 'pi'){
		
		$lookup->{$feat_name}->[PI] = $score;

	    } elsif (lc($att_type) eq 'sp-hmm'){
		
		$lookup->{$feat_name}->[SP_HMM] = $record->[CURATED];

	    } elsif (lc($att_type) eq 'targetp'){
		
		$lookup->{$feat_name}->[TARGETP] = $record->[CURATED];
		
	    } else {
		
		$self->{_logger}->warn("Unexpected att_type 'att_type' ".
				       "while processing feat_name ".
				       "'$feat_name'");
		next;
	    }
	}

   	$ctr++;
    }
    
    print "Added '$ctr' $FEATURE_TYPE records to the $FEATURE_TYPE lookup\n";
   
    $self->{_lookup} = $lookup;

    $self->{_rec_count} = $ctr;
}


1==1; ## end of module
