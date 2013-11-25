package BSML::BsmlAlignmentFilter;

=head1 NAME

  BSML::BsmlAlignmentFilter - allows filtering of bsml alignment results while parsing.

=head1 SYNOPSIS

use BSML::BsmlAlignmentFilter;

my $alignment = new BSML::BsmlAlignmentFilter( { 'file' => '/path/to/file.bsml' } );
$alignment->add_filter( 'p_value', '-1e-5' );  #Retun those Seq-pair-run (HSP) with a p_value of less than
                                               #1e-5.  
$alignment->add_filter( 'percent_similarity', '+30' );  #Return only those HSPs with % similarity greater
                                                        #than 30.
$alignment->add_filter( 'compseq', qr/^gb/ );  #Return those HSPs that have a compseq starting with gb.

$alignment->parse_alignment_file();

$alignment->get_evidence( $refseq );          # Will return evidence for specified refseq if available
 or 
$alignment->get_evidence( );                  # Will return evidence for all refseqs available


=head1 INPUT

    The bsml input file for this module is any alignment BSML document.  See
    bsml documentation for that format

=head1 FUTURE


    --ACCESSING PARSED DATA

    Unfortunately, there are no accessor methods for any of the data and the data structure should
    be used to retrieve the alignment data.  A brief overview of the data structure follows:

    $self = {
    
    'filters' => { 'key' => 'value' },    #Any added filters will be stored here.

    'alignments' => { 'compseq' => {  'key' => 'value',                      #Seq-pair-alignment[@whatever] and child Attribute 
                                                                             #name and content are stored here ( keyed by compseq)

                                      'spr' => [ { 'key' => 'value' } ]      #Seq-pair-run[@whatever] and child Attribute name and
                                                                             #content are stored in an array ref under the key
                                                                             

    ...


    --PRINTING TO FILE

    I would also like to eventually put in a couple methods that will print this filtered information
    out to different formats (btab, bsml) to be used in other places.  But this will work for right now.

=head1 CONTACT

    Kevin Galens
    kgalens@som.umaryland.edu

=cut

############# IMPORTS ####################
use strict;
use warnings;
use XML::Twig;
use File::OpenFile qw(open_file);
use MLDBM 'DB_File';
use DB_File;
use Carp;
use Data::Dumper;

############ CLASS VARIABLES #################
my $prok_pipeline_hmm_data_db = "/usr/local/projects/db/coding_hmm/coding_hmm.lib.db";


############ CONSTRUCTOR #####################
=item $alignment->new( { args => value } );

B<Description:> Creates a BsmlAlignmentFilter object. 
    Arguments can be just the input Bsml Alignment file
    and you can also include a set of filters.

B<Parameters:> Takes a hash ref.
    'file' => '/path/to/file',
    'filters' => { key => value }

B<Returns:> A BsmlAlignmentFilter object reference.

=cut 
sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    $self->_init( shift @_ );

    return $self;
}

###########################PUBLIC SUBROUTINES##################################
=item $alignment->add_filter( 'key', 'value' );

B<Description:> Adds a filter to the object.  

B<Parameters:> key and value pair.  If the value on which you are
    filtering is numeric, the value should be in format:

       +n = greather than n
       -n = less than n
       =n = equal to n

    if the value is a string, a string regex should be passed in:

       my $string_filter = qr/^(gb|sp)/;
       $alignment->add_filter( 'compseq', $string_filter );


B<Returns:> Nothing

=cut
sub add_filter {
    my ($self,$key,$value) = @_;
    $self->{'filters'}->{$key} = $value;
}

=item $alignment->parse_alignment_file

B<Description:> Will apply the added filters and parse the
    alignment file.

B<Parameters:> Optional file parameter will parse 
    instead of what is stored in $self->{'file'}

B<Returns:> Nothing.

=cut    
sub parse_alignment_file {
    my ($self, $file) = @_;

    $file = $self->{'file'} unless( $file );

    my $twig = new XML::Twig( 'twig_handlers' => {
        'Seq-pair-alignment' => sub {
            my ($twig, $spa) = @_;
            my $attributes = $spa->atts();

            my $data = {};
            
            while( my ($key, $value) = each( %{$attributes} ) ) {
                $data->{$key} = $value;                
                if( $self->{'filters'}->{$key} && 
                    !$self->passes_filter( $key, $value )  ) {
                    return;
                }
            }

            my @sprs = $spa->children('Seq-pair-run');

          SPR:
            foreach my $spr ( @sprs ) {
                my $spr_data = {};

                $attributes = $spr->atts();
              ATT:
                while( my ($key, $value) = each( %{$attributes} )) {
                    $spr_data->{$key} = $value;
                    if( $self->{'filters'}->{$key} && 
                        !$self->passes_filter( $key, $value )  ) {
                        next SPR;
                    }
                }

                my @bsml_attributes = $spr->children( "Attribute" );
                
              BSML_ATT:
                foreach my $child_att ( @bsml_attributes ) {
                    my ($key, $value) = ( $child_att->att('name'), $child_att->att('content') );

                    $spr_data->{$key} = $value;
                    if( $self->{'filters'}->{$key} &&
                        !$self->passes_filter( $key, $value ) ) {
                        next SPR;
                    }
                }

                push( @{$data->{'spr'}}, $spr_data );

            }       

            #If we don't have any Seq-pair-runs, then don't store the Seq-pair-alignment
            return if( !exists( $data->{'spr'} ) || @{$data->{'spr'}} == 0 );

            #Check special case filters (i.e. information that's not stored withing the bsml)
            $self->special_case_filters( $data );

            #Skip if there is no data
            return unless( defined($data) && scalar( keys %$data ) );

            #Store the data if it made it this far.
            $self->{'alignments'}->{ $data->{'refseq'} }->{ $data->{'compseq'} } = $data;

            $twig->purge();
        }

    });

    my $th = &open_file( $file, 'in' );
    $twig->parse( $th );
    close( $th );
                              
}

=item $alignment->get_alignment

B<Description:> Returns alignment information for all alignments that passed 
    the filters or a specific refseq if an accession is passed.

    Alignment hash returned in the following format:
    $alignment->{$compseq} = { 'key' => 'value',
                               'spr' => [ {'key' => 'value'},
                                          {'key' => 'value'} ],
                                        [ {'key' => 'value'} ]...

                                        }
    where the key value pairs are attributes parsed from the bsml
                                         

B<Parameters:> Optional refseq argument.  

B<Returns:> All alignments if no refseq is passed in
               - if used in array context, will return an array of alignments
               - otherwise will return a hash reference keyed by refseq id
            A set of alignments if a refseq is used
               - hash reference in format described above
            An empty data structure
               - if a refseq is passed but is not found will return
                 an empty list in list context
               - or an empty hash reference otherwise

=cut    
sub get_alignment {
    my ($self, $acc) = @_;

    my $alignments = $self->{'alignments'};

    if( !$acc ) {
        return wantarray ? values %{$alignments} : $alignments;
    }

    if( exists( $alignments->{$acc} ) ) {
        return $alignments->{$acc};
    } else {
        return wantarray ? () : {};
    }
}

=item B<SUBROUTINE>  $alignment->get_alignment_intervals

B<Description:> Returns an abbreviated data structure only containing
    the compseq id as well as the coordinates for the match in the following
    format:
B<Parameters:> 

B<Returns:>

=cut 
sub get_alignment_interval {
    my ($self, $acc) = @_;
    my $retval = [];

    if( $acc ) {
        my $alignments = $self->get_alignment( $acc );
        return $retval if( keys %{$alignments} == 0 );
        
        foreach my $compseq ( keys %{$alignments} ) {
            foreach my $spr ( @{$alignments->{$compseq}->{'spr'}} ) {
                my $left = $spr->{'refpos'};
                my $right = $spr->{'refpos'} + $spr->{'runlength'};
                push( @{$retval}, { 'compseq' => $compseq,
                                    'left' => $left,
                                    'right' => $right } );
            }
        }
    } else {
        my $alignments = $self->get_alignment();

        foreach my $refseq ( keys %{$alignments} ) {
            foreach my $compseq( keys %{$alignments->{$refseq}} ) {
                foreach my $spr( @{$alignments->{$refseq}->{$compseq}->{'spr'}} ) {
                    my $left = $spr->{'refpos'};
                    my $right = $spr->{'refpos'} + $spr->{'runlength'};
                    push( @{$retval}, { 'compseq' => $compseq,
                                        'left' => $left,
                                        'right' => $right } );

                }
            }
        }
    }
    
    return $retval;
}

sub refseqs {
    my ($self) = @_;
    return keys %{$self->{'alignments'}};
}

############################### PRIVATE(ISH) SUBROUTINES ##########################
sub special_case_filters {
    my ($self, $data) = @_;

    #HMM Trusted cutoff score
    if( exists( $self->{'filters'}->{'trusted_cutoff'} ) ) {
        my $num = $self->_pass_trusted_cutoff( $data );
    }

    return 1;
}

sub _pass_trusted_cutoff {
    my ($self, $data) = @_;
    my $tied_hmm_lookup = $self->{'_hmm_lookup'};

    my $trusted_cutoff;    
    if( exists( $tied_hmm_lookup->{$data->{'compseq'}}->{'trusted_cutoff'} ) ) {
        $trusted_cutoff = $tied_hmm_lookup->{$data->{'compseq'}}->{'trusted_cutoff'};
    }
    
    #This means it's not an hmm and we can't apply this filter to the sequence
    return 0 unless( $trusted_cutoff );

    $data->{'trusted_cutoff'} = $trusted_cutoff;

    my @passed_sprs = ();
    foreach my $spr ( @{$data->{'spr'}} ) {
        next unless( $spr->{'runscore'} );
        if( $spr->{'runscore'} > $trusted_cutoff ) {
            push(@passed_sprs, $spr);
        }
    }

    if( @passed_sprs == 0 ) {
        undef(%$data);
    } else {
        $data->{'spr'} = \@passed_sprs;
    }

    return scalar( @passed_sprs );
    
}

sub passes_filter {
    my ($self, $key, $value) = @_;
    
    my $t = "\t\t";

    #If there is no filter, we just return with 1.
    return 1 unless( exists( $self->{'filters'}->{$key} ) );

    my $filter_value = $self->{'filters'}->{$key};

    #Strings are passed in as regex (ex. my $var = qr/pat[te]+rn/)
    if( ref( $filter_value ) eq 'Regexp' ) {

        return 1 if( $value =~ /$filter_value/ );

    #Numeric args are prefixed by +,-, or =
    } elsif( $filter_value =~ /^([\+\-\=])/ ) {

        my $compare = $1;
        my $num = substr( $filter_value, 1 );

        if( $compare eq '+' ) {
            return 1 if( $value > $num );
        } elsif( $compare eq '-' ) {
            return 1 if( $value < $num );
        } elsif( $compare eq '=' ) {
            return 1 if( $value == $num );
        }

    } else {
        die("Bad value for filter: $key.");
    }

    return 0;
}

sub _init {
    my ($self, $args) = @_;

    $self->{'valid_filters'} = 
    { 'p-value' => 1,
      'percent_identity' => 1,
      'percent_similarity' => 1,
      'percent_coverage_refseq' => 1,
      'percent_coverage_compseq' => 1,
      'trusted_cutoff' => 1,
  };

    if( $args->{'filters'} ) {
        while( my ($key,$value) = each( %{$args->{'filters'}} ) ) {
            $self->add_filter( $key, $value );
        }
    }

    if( $args->{'file'} ) {
        $self->{'file'} = $args->{'file'};
    }

    my %tmp;
    tie(%tmp, 'MLDBM', $prok_pipeline_hmm_data_db, O_RDONLY) or
        croak("Could not tie hash to $prok_pipeline_hmm_data_db");
    $self->{'_hmm_lookup'} = \%tmp;
}

##### EOF ####

1;
