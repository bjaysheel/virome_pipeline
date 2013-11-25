# JCVI::Translator::Table
#
# $Author: kgalinsk $
# $Date: 2009-04-13 17:49:08 -0400 (Mon, 13 Apr 2009) $
# $Revision: 25913 $
# $HeadURL: http://isvn.tigr.org/ANNOTATION/bioinformatics-engineers/kgalinsk/JCVI-Translator/tags/0.5.6/lib/JCVI/Translator/Table.pm $

=head1 NAME

JCVI::Translator::Table - Translation table for JCVI::Translator

=head1 SYNOPSIS

    use JCVI::Translator::Table;
    
    my $table = new JCVI::Translator();
    my $table = new JCVI::Translator(11);
    my $table = new JCVI::Translator( 12, { type => 'id' } );
    my $table = new JCVI::Translator( 'Yeast Mitochondrial', { type => 'name' } );
    my $table = new JCVI::Translator( 'mito', { type => 'name' } );

    my $table = custom JCVI::Translator( \$custom_table );
    my $tale = custom JCVI::Translator( \$custom_table, { bootstrap => 0 } );


=cut

package JCVI::Translator::Table;

use strict;
use warnings;

use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(qw(id names _forward _starts _reverse));

use Log::Log4perl qw(:easy);
use Params::Validate;

#use JCVI::Translator::_TablePair;

use JCVI::DNATools qw(
  %degenerate_map
  $degen_match
  @nucs
  $nuc_match
  reverse_complement
);

use JCVI::AATools qw(
  %ambiguous_forward
  $aa_match
);

our $DEFAULT_ID        = 1;
our $DEFAULT_TYPE      = 'id';
our $DEFAULT_BOOTSTRAP = 1;

# Helper constructor. Instantiates the object with arrayrefs and hashrefs in
# the right places
sub _new {
    shift->SUPER::new(
        {
            names    => [],
            _forward => JCVI::Translator::_TablePair->new(),
            _starts  => JCVI::Translator::_TablePair->new(),
            _reverse => JCVI::Translator::_TablePair->new()
        }
    );
}

=head1 CONSTRUCTORS

=cut

=head2 new

    my $table = JCVI::Translator::Table->new();
    my $table = JCVI::Translator::Table->new( $id );
    my $table = JCVI::Translator::Table->new( $id, \%params );

This method creates a translation table by loading a table string from the
internal list. Pass an ID and the type of ID. By default, it will load the
translation table with id 1. The type of ID may be "id" or "name," which
correspond to the numeric id of the translation table or the long name of the
translation table. For instance, below are the headers for the first 3 table
strings.

    {
    name "Standard" ,
    name "SGC0" ,
    id 1 ,
    ...
    },
    {
    name "Vertebrate Mitochondrial" ,
    name "SGC1" ,
    id 2 ,
    ...
    },
    {
    name "Yeast Mitochondrial" ,
    name "SGC2" ,
    id 3 ,
    ...
    },
    ...

By default, the "Standard" translation table will be loaded. You may instantiate
this translation table by calling any of the following:

    my $t = JCVI::Translator::Table->new();
    my $t = JCVI::Translator::Table->new(1);
    my $t = JCVI::Translator::Table->new( 1,          { type => 'id' } );
    my $t = JCVI::Translator::Table->new( 'Standard', { type => 'name' } );
    my $t = JCVI::Translator::Table->new( 'SGC0',     { type => 'name' } );
    my $t = JCVI::Translator::Table->new( 'standard', { type => 'name' } );
    my $t = JCVI::Translator::Table->new( 'stan',     { type => 'name' } );

For partial matches, this module will use the first matching translation
table.

    my $t = JCVI::Translator::Table->new( 'mitochondrial', { type => 'name' } );

This will use translation table with ID 2, "Vertebrate Mitochondrial," because
that is the first match (even though "Yeast Mitochondrial" would also match).

=cut

sub new {
    TRACE('new called');

    my $class = shift;

    my ( $id, @p );

    # id has a default, but if supplied, must be a scalar
    ( $id, $p[0] ) = validate_pos(
        @_,
        { type => Params::Validate::SCALAR,  default => $DEFAULT_ID },
        { type => Params::Validate::HASHREF, default => {} }
    );

    # type must be either id or name
    my %p = validate(
        @p,
        {
            type => {
                default => $DEFAULT_TYPE,
                regex   => qr/id|name/
            }
        }
    );

    TRACE( uc( $p{type} ) . ': ' . $id );

    # Get the beginning DATA so that we can seek back to it
    my $start_pos = tell DATA;

    # Set up regular expression for searching.
    my $match = ( $p{type} eq 'id' ) ? qr/id $id\b/ : qr/name ".*$id.*"/i;

    # Go through every internal table until it matches on id or name.
    my $found = 0;
    local $/ = "}";
    local $_;
    while (<DATA>) {
        if ( $_ =~ $match ) {
            $found = 1;
            last;
        }
    }

    # Reset DATA
    seek DATA, $start_pos, 0;

    # Call custom with internal table. We don't want to bootstrap.
    return $class->custom( \$_, { bootstrap => 0 } ) if ($found);

    # Internal table not matched.
    ERROR("Table with $p{type} of $id not found");
    return undef;
}

=head2 custom()

    my $table = JCVI::Translator::Table->custom( $table_ref );
    my $table = JCVI::Translator::Table->custom( $table_ref, \%params );

Create a translation table based off a passed table reference for custom
translation tables. Loads degenerate nucleotides if bootstrap isn't set (this
can take a little time). The format of the translation table should reflect
those of the internal tables:

    name "Names separated; by semicolons"
    name "May have multiple lines"
    id 99
    ncbieaa  "AMINOACIDS...",
    sncbieaa "-M--------..."
    -- Base1  AAAAAAAAAA...
    -- Base2  AAAACCCCGG...
    -- Base3  ACGTACTGAC...

This module is a bit more permissive than that; see the $TABLE_REGEX regular
expression to see that actual format.

Examples:

    $translator = new Translator(
        table_ref => \'name "All Alanines; All the Time"
                       id 9000
                       ncbieaa  "AAAAAAAA"
                       sncbieaa "----M---"
                       base1     AAAAAAAA
                       base2     AACCGGTT
                       base3     ACACACAC'
    );

    $translator = new Translator(
        table_ref => \$table,
        bootstrap  => 0
    );

=cut

# Regular expression which should match translation tables and also extracts
# relevant information.
our $TABLE_REGEX = qr/
                        ( (?:name\s+".+?".*?) + )
                        id\s+(\d+).*
                        ncbieaa\s+"([a-z*]+)".*
                        sncbieaa\s+"([a-z-]+)".*
                        base1\s+([a-z]+).*
                        base2\s+([a-z]+).*
                        base3\s+([a-z]+).*
                     /isx;

sub custom {
    TRACE('custom called');

    my $class = shift;

    my ( $table_ref, @p );

    # table_ref is required and must be a refrerence to a scalar
    ( $table_ref, $p[0] ) = validate_pos(
        @_,
        { type => Params::Validate::SCALARREF },
        { type => Params::Validate::HASHREF, default => {} }
    );

    # get the bootstrap parameter
    my %p = validate(
        @p,
        {
            bootstrap => {
                default => $DEFAULT_BOOTSTRAP,
                regex   => qr/^[01]$/
            }
        }
    );

    # Match the table or return undef.
    unless ( $$table_ref =~ $TABLE_REGEX ) {
        ERROR( 'Translation table is in invalid format', $$table_ref );
        return undef;
    }

    # Store the data that has been stripped using descriptive names;
    my $names    = $1;
    my $id       = $2;
    my $residues = $3;
    my $starts   = $4;
    my $base1    = $5;
    my $base2    = $6;
    my $base3    = $7;

    my $self = $class->_new();

    $self->id($id);

    # Extract each name, massage, and push it onto names array
    while ( $names =~ /"(.+?)"/gis ) {
        my @names = split( /;/, $1 );
        local $_;
        foreach (@names) {
            s/^\s+//;
            s/\s+$//;
            s/\n/ /g;
            s/\s{2,}/ /g;
            push @{ $self->names }, $_ if $_;
        }
    }

    # Get all the table pairs so we don't have to keep using accessors
    my $forward_table = $self->_forward;
    my $starts_table  = $self->_starts;
    my $reverse_table = $self->_reverse;

    # Chop is used to efficiently get the last character from each string
    while ( my $residue = uc( chop $residues ) ) {
        my $start = uc( chop $starts );
        my $codon = uc( chop($base1) . chop($base2) . chop($base3) );

        my $reverse = ${ reverse_complement( \$codon ) };

        # If the residue is valid, store it
        if ( $residue ne 'X' ) {
            $forward_table->store( $residue, $codon, $reverse );
            $reverse_table->push( $residue, $codon, $reverse );
        }

        # If the start is valid, store it
        if ( ( $start ne '-' ) ) {
            $starts_table->store( $start, $codon, $reverse );
            $reverse_table->push( '+', $codon, $reverse );
        }
    }

    # Bootstrap the translation table
    $self->bootstrap() if ( $p{bootstrap} );

    return $self;
}

=head1 METHODS

=cut

=head2 add_translation

    $translator->add_translation( $codon, $residue );
    $translator->add_translation( $codon, $residue, \%params );

Add a codon-to-residue translation to the translation table. $start inidicates
if this is a start codon.

Examples:

    # THESE AREN'T REAL!!!
    $translator->add_translation( 'ABA', 'G' );
    $translator->add_translation( 'ABA', 'M', 1 );

=cut

sub add_translation {
    TRACE('add_translation called');

    my $self = shift;

    my ( $codon, $residue, @p );

    ( $codon, $residue, $p[0] ) = validate_pos(
        @_,
        { regex => qr/^${nuc_match}{3}$/ },
        { regex => qr/^$aa_match$/ },
        { type  => Params::Validate::HASHREF, default => {} }
    );

    my %p = validate(
        @p,
        {
            strand => {
                default => 1,
                regex   => qr/^[+-]?1$/,
                type    => Params::Validate::SCALAR
            },
            start => {
                default => 0,
                regex   => qr/^[01]$/,
                type    => Params::Validate::SCALAR
            }
        }
    );

    my $codon_ref;
    my $rc_codon_ref;

    if ( $p{strand} == 1 ) {
        $codon_ref    = \$codon;
        $rc_codon_ref = reverse_complement( \$codon );
    }
    else {
        $rc_codon_ref = \$codon;
        $codon_ref    = reverse_complement( \$codon );
    }

    # Store residue in the starts or regular translation table.
    my $table = $p{start} ? '_starts' : '_forward';
    $table = $self->$table;

    $table->store( $residue, $$codon_ref, $$rc_codon_ref );

    # Store the reverse lookup
    $residue = '+' if ( $p{start} );
    $self->_reverse->push( $residue, $$codon_ref, $$rc_codon_ref );
}

=head2 bootstrap

    $translator->bootstrap();

Bootstrap the translation table. Find every possible translation, even those
that involve degenerate nucleotides or ambiguous amino acids.

=cut

sub bootstrap {
    TRACE('bootstrap called');

    my $self = shift;

    # Loop through every nucleotide combination and run _translate_codon on
    # each.
    foreach my $n1 (@nucs) {
        foreach my $n2 (@nucs) {
            foreach my $n3 (@nucs) {
                $self->_unroll( $n1 . $n2 . $n3, $self->_forward->[0] );
                $self->_unroll(
                    $n1 . $n2 . $n3,
                    $self->_starts->[0],
                    { start => 1 }
                );
            }
        }
    }
}

# This is the helper function for bootstrap. Handles codons with degenerate
# nucleotides: [RYMKWS] [BDHV] or N. Several codons may map to the same amino
# acid. If all possible codons for an amibguity map to the same residue, store
# that residue.

sub _unroll {
    my $self  = shift;
    my $codon = shift;
    my $table = shift;

    # Return the codon if we have it
    return $table->{$codon} if ( $table->{$codon} );

    # Check for base case: no degenerate nucleotides; we can't unroll further.
    unless ( $codon =~ /($degen_match)/ ) {
        return undef;
    }

    my $consensus;
    my $nuc = $1;

    # Replace the nucleotide with every possiblity from degenerate map hash.
    foreach ( @{ $degenerate_map{$nuc} } ) {
        my $new_codon = $codon;
        $new_codon =~ s/$nuc/$_/;

        # Recursively call this function
        my $residue = $self->_unroll( $new_codon, $table, @_ );

        # If the new_codon didn't come to a consensus, or if the translation
        # isn't defined for new_codon in a custom translation table, return
        # undef.
        return undef unless ( defined $residue );

        # If consensus isn't set, set it to the current residue.
        $consensus = $residue unless ($consensus);

        # This is an interesting step. If the residue isn't the same as the
        # consensus, check to see if they map to the same ambiguous amino acid.
        # If true, then change the consensus to that ambiguous acid and proceed.
        # Otherwise, return undef (consensus could not be reached).
        if ( $residue ne $consensus ) {
            if (
                   ( defined $ambiguous_forward{$residue} )
                && ( defined $ambiguous_forward{$consensus} )
                && ( $ambiguous_forward{$residue} eq
                    $ambiguous_forward{$consensus} )
              )
            {
                $consensus = $ambiguous_forward{$consensus};
            }
            else {
                return undef;
            }
        }
    }

    # If we got this far, it means that we have a valid consensus sequence for
    # a degenerate-nucleotide-containing codon. Cache and return results.
    DEBUG("New codon translation found: $codon => $consensus");
    $self->add_translation( $codon, $consensus, @_ );
    return $consensus;
}

=head2 string

    my $table_string_ref = $translator->string();
    my $table_string_ref = $translator->string( \%params );

Returns the table string. %params can specify whether or not this table should
try to bootstrap itself using the bootstrap function above. By default, it will
try to.

Examples:

    my $table_string_ref = $translator->string();
    my $table_string_ref = $translator->string( { bootstrap => 0 } );

=cut

sub string {
    TRACE('table_string called');

    my $self = shift;

    my $bootstrap =
      validate_pos( @_,
        { default => $DEFAULT_BOOTSTRAP, regex => qr/^[01]$/ } );

    # Bootstrap if necessary
    $self->bootstrap() if ($bootstrap);

    # Generate the names string
    my $names = join( '; ', @{ $self->names } );

    my ( $residues, $starts );    # starts/residues string
    my @base = (undef) x 3;       # this will store the base strings

    # Loop over all stored codons. Sort the codons in the translation table and
    # starts table, then use grep to get the unique ones with the help of $prev
    # which stores the previous value
    my $prev = '';
    foreach my $codon (
        grep ( ( $_ ne $prev ) && ( $prev = $_ ),
            sort { $a cmp $b } (
                keys( %{ $self->_forward->[0] } ),
                keys( %{ $self->_starts->[0] } )
              ) )
      )
    {
        $residues .= $self->_forward->[0]->{$codon} || 'X';
        $starts   .= $self->_starts->[0]->{$codon}  || '-';

        # Chop up the codon because the bases are stored on separate lines
        $base[ -$_ ] .= chop $codon foreach ( 1 .. 3 );
    }

    # Generate the string
    my $string = join( "\n",
        '{',
        qq(name "$names" ,),
        qq(id $self->{id} ,),
        qq(ncbieaa  "$residues",),
        qq(sncbieaa "$starts"),
        map( {"-- Base$_  $base[$_ - 1]"} ( 1 .. 3 ) ),
        '}' );

    return \$string;
}

{
    package JCVI::Translator::_TablePair;

    use strict;
    use warnings;

    use JCVI::DNATools qw(reverse_complement);

    sub new {
        my $class = shift;
        my $self = [ {}, {} ];
        bless $self, $class;
    }

    sub store {
        my ( $self, $residue, $codon, $reverse ) = @_;

        $reverse ||= ${ reverse_complement($codon) };

        $self->[0]->{$codon}   = $residue;
        $self->[1]->{$reverse} = $residue;
    }

    sub push {
        my ( $self, $residue, $codon, $reverse ) = @_;

        $reverse ||= ${ reverse_complement($codon) };

        $self->[0]->{$residue} ||= [];
        $self->[1]->{$residue} ||= [];

        push @{ $self->[0]->{$residue} }, $codon;
        push @{ $self->[1]->{$residue} }, $reverse;
    }

    1;
}

1;

=head1 MISC

These are the original translation tables. The translation tables used by this
module have been boostrapped - they include translations for degenerate
nucleotides and allow ambiguous amino acids to be the targets of translation
(e.g. every effort has been made to give a translation that isn't "X").

    {
    name "Standard" ,
    name "SGC0" ,
    id 1 ,
    ncbieaa  "FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
    sncbieaa "---M---------------M---------------M----------------------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    },
    {
    name "Vertebrate Mitochondrial" ,
    name "SGC1" ,
    id 2 ,
    ncbieaa  "FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIMMTTTTNNKKSS**VVVVAAAADDEEGGGG",
    sncbieaa "--------------------------------MMMM---------------M------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    },
    {
    name "Yeast Mitochondrial" ,
    name "SGC2" ,
    id 3 ,
    ncbieaa  "FFLLSSSSYY**CCWWTTTTPPPPHHQQRRRRIIMMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
    sncbieaa "----------------------------------MM----------------------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    },
    {
    name "Mold Mitochondrial; Protozoan Mitochondrial;"
    name "Coelenterate Mitochondrial; Mycoplasma; Spiroplasma" ,
    name "SGC3" ,
    id 4 ,
    ncbieaa  "FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
    sncbieaa "--MM---------------M------------MMMM---------------M------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    },
    {
    name "Invertebrate Mitochondrial" ,
    name "SGC4" ,
    id 5 ,
    ncbieaa  "FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIMMTTTTNNKKSSSSVVVVAAAADDEEGGGG",
    sncbieaa "---M----------------------------MMMM---------------M------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    },
    {
    name "Ciliate Nuclear; Dasycladacean Nuclear; Hexamita Nuclear" ,
    name "SGC5" ,
    id 6 ,
    ncbieaa  "FFLLSSSSYYQQCC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
    sncbieaa "-----------------------------------M----------------------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    },
    {
    name "Echinoderm Mitochondrial; Flatworm Mitochondrial" ,
    name "SGC8" ,
    id 9 ,
    ncbieaa  "FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIIMTTTTNNNKSSSSVVVVAAAADDEEGGGG",
    sncbieaa "-----------------------------------M---------------M------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    },
    {
    name "Euplotid Nuclear" ,
    name "SGC9" ,
    id 10 ,
    ncbieaa  "FFLLSSSSYY**CCCWLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
    sncbieaa "-----------------------------------M----------------------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    },
    {
    name "Bacterial and Plant Plastid" ,
    id 11 ,
    ncbieaa  "FFLLSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
    sncbieaa "---M---------------M------------MMMM---------------M------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    },
    {
    name "Alternative Yeast Nuclear" ,
    id 12 ,
    ncbieaa  "FFLLSSSSYY**CC*WLLLSPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
    sncbieaa "-------------------M---------------M----------------------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    },
    {
    name "Ascidian Mitochondrial" ,
    id 13 ,
    ncbieaa  "FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIMMTTTTNNKKSSGGVVVVAAAADDEEGGGG",
    sncbieaa "---M------------------------------MM---------------M------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    },
    {
    name "Alternative Flatworm Mitochondrial" ,
    id 14 ,
    ncbieaa  "FFLLSSSSYYY*CCWWLLLLPPPPHHQQRRRRIIIMTTTTNNNKSSSSVVVVAAAADDEEGGGG",
    sncbieaa "-----------------------------------M----------------------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    } ,
    {
    name "Blepharisma Macronuclear" ,
    id 15 ,
    ncbieaa  "FFLLSSSSYY*QCC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
    sncbieaa "-----------------------------------M----------------------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    } ,
    {
    name "Chlorophycean Mitochondrial" ,
    id 16 ,
    ncbieaa  "FFLLSSSSYY*LCC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
    sncbieaa "-----------------------------------M----------------------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    } ,
    {
    name "Trematode Mitochondrial" ,
    id 21 ,
    ncbieaa  "FFLLSSSSYY**CCWWLLLLPPPPHHQQRRRRIIMMTTTTNNNKSSSSVVVVAAAADDEEGGGG",
    sncbieaa "-----------------------------------M---------------M------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    } ,
    {
    name "Scenedesmus obliquus Mitochondrial" ,
    id 22 ,
    ncbieaa  "FFLLSS*SYY*LCC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
    sncbieaa "-----------------------------------M----------------------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    } ,
    {
    name "Thraustochytrium Mitochondrial" ,
    id 23 ,
    ncbieaa  "FF*LSSSSYY**CC*WLLLLPPPPHHQQRRRRIIIMTTTTNNKKSSRRVVVVAAAADDEEGGGG",
    sncbieaa "--------------------------------M--M---------------M------------"
    -- Base1  TTTTTTTTTTTTTTTTCCCCCCCCCCCCCCCCAAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGG
    -- Base2  TTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGGTTTTCCCCAAAAGGGG
    -- Base3  TCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAGTCAG
    }

=head1 AUTHOR

Kevin Galinsky, <kgalinsk@jcvi.org>

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 J. Craig Venter Institute, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

__DATA__

{
name "Standard; SGC0" ,
id 1 ,
ncbieaa  "KNKNKNTTTTTTTTTTTTTTTRSRSRSIIMIIIIIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLLLLLLLLLLLLLLEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBB*Y*Y*YSSSSSSSSSSSSSSS*CWCCLFLFLF*JXRRRJJXJJJJJZZZJXLLL",
sncbieaa "-----------------------------M-------------------------------------------M----------------------------------------------------------------------------------------------M-----M-----M---------M-M-"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTHHMMMMMMMMMMMSSSWWYYY
-- Base2  AAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAAACCCCCCCCCCCCCCCGGGGGTTTTTTRTTGGGTTTTTTTTAAATTTTT
-- Base3  ACGTRYACGTBDHKMNRSVWYACGTRYACGTHMWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTRYACGTBDHKMNRSVWYACGTYACGTRYAAGAGRACGTHMWYAGRAGAGR
}
{
name "Vertebrate Mitochondrial; SGC1" ,
id 2 ,
ncbieaa  "KNKNKNTTTTTTTTTTTTTTT*S*S*SMIMIXXXXXXMXXXIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLLLLLLLLLLLLLLEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBB*Y*Y*YSSSSSSSSSSSSSSSWCWCWCLFLFLFJJJXZZZLLL",
sncbieaa "---------------------------MMMMMMMMMMMMMMM-----------------------------------------------------------------------------------------M---------------------------------------------------M------"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTMMMRSSSYYY
-- Base2  AAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTTTAAATTT
-- Base3  ACGTRYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTRYACGTBDHKMNRSVWYACGTRYACGTRYCTYGAGRAGR
}
{
name "Yeast Mitochondrial; SGC2" ,
id 3 ,
ncbieaa  "KNKNKNTTTTTTTTTTTTTTTRSRSRSMIMIMIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRTTTTTTTTTTTTTTTEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBB*Y*Y*YSSSSSSSSSSSSSSSWCWCWCLFLFLFRRRZZZ",
sncbieaa "---------------------------M-M-M-------------------------------------------------------------------------------------------------------------------------------------------------"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTMMMSSS
-- Base2  AAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTGGGAAA
-- Base3  ACGTRYACGTBDHKMNRSVWYACGTRYACGTRYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTRYACGTBDHKMNRSVWYACGTRYACGTRYAGRAGR
}
{
name "Mold Mitochondrial; Protozoan Mitochondrial; Coelenterate Mitochondrial; Mycoplasma; Spiroplasma; SGC3" ,
id 4 ,
ncbieaa  "KNKNKNTTTTTTTTTTTTTTTRSRSRSIIMIXXIXIXXXXIIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLLLLLLLLLLLLLLEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBB*Y*Y*YSSSSSSSSSSSSSSSWCWCWCLFLFLFXXJXXRRRJJXJJJJJXXZZZXXJXXLLL",
sncbieaa "---------------------------MMMMMMMMMMMMMMM--------------------------------------M--------------------------------------------------M------------------------------------------M-M-M-MM-MM-----M-----MM---MMMMM-M-"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTBDHHKMMMMMMMMMMMNRSSSSVWWWYYY
-- Base2  AAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTTTTGGGTTTTTTTTTTAAATTTTTTTT
-- Base3  ACGTRYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTRYACGTBDHKMNRSVWYACGTRYACGTRYGGAGGAGRACGTHMWYGGAGRGGAGRAGR
}
{
name "Invertebrate Mitochondrial; SGC4" ,
id 5 ,
ncbieaa  "KNKNKNTTTTTTTTTTTTTTTSSSSSSSSSSSSSSSMIMIXXXXXXMXXXIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLLLLLLLLLLLLLLEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBB*Y*Y*YSSSSSSSSSSSSSSSWCWCWCLFLFLFXXJJJXZZZXLLL",
sncbieaa "------------------------------------MMMMMMMMMMMMMMM-----------------------------------------------------------------------------------------M--------------------------------------------M---MM---M---M---"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTDKMMMRSSSWYYY
-- Base2  AAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTTTTTAAATTTT
-- Base3  ACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTRYACGTBDHKMNRSVWYACGTRYACGTRYGGCTYGAGRGAGR
}
{
name "Ciliate Nuclear; Dasycladacean Nuclear; Hexamita Nuclear; SGC5" ,
id 6 ,
ncbieaa  "KNKNKNTTTTTTTTTTTTTTTRSRSRSIIMIIIIIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLLLLLLLLLLLLLLEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBBQYQYQYSSSSSSSSSSSSSSS*CWCCLFLFLFZZZJZZZRRRJJJJJJJZZZJQQQLLL",
sncbieaa "-----------------------------M-------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTBBBHKKKMMMMMMMMMMSSSWYYYYYY
-- Base2  AAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAAACCCCCCCCCCCCCCCGGGGGTTTTTTAAATAAAGGGTTTTTTTAAATAAATTT
-- Base3  ACGTRYACGTBDHKMNRSVWYACGTRYACGTHMWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTRYACGTBDHKMNRSVWYACGTYACGTRYAGRAAGRAGRACTHMWYAGRAAGRAGR
}
{
name "Echinoderm Mitochondrial; Flatworm Mitochondrial; SGC8" ,
id 9 ,
ncbieaa  "NNKNNNNNTTTTTTTTTTTTTTTSSSSSSSSSSSSSSSIIMIIIIIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLLLLLLLLLLLLLLEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBB*Y*Y*YSSSSSSSSSSSSSSSWCWCWCLFLFLFJJJJJJJJXZZZJLLL",
sncbieaa "----------------------------------------M----------------------------------------------------------------------------------------------M--------------------------------------------------------M-------"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTHMMMMMMMRSSSWYYY
-- Base2  AAAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTTTTTTTTAAATTTT
-- Base3  ACGTHMWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTHMWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTRYACGTBDHKMNRSVWYACGTRYACGTRYAACTHMWYGAGRAAGR
}
{
name "Euplotid Nuclear; SGC9" ,
id 10 ,
ncbieaa  "KNKNKNTTTTTTTTTTTTTTTRSRSRSIIMIIIIIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLLLLLLLLLLLLLLEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBB*Y*Y*YSSSSSSSSSSSSSSSCCWCCCCCLFLFLFJRRRJJJJJJJZZZJLLL",
sncbieaa "-----------------------------M-------------------------------------------------------------------------------------------------------------------------------------------------------------------"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTHMMMMMMMMMMSSSWYYY
-- Base2  AAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAAACCCCCCCCCCCCCCCGGGGGGGGTTTTTTTGGGTTTTTTTAAATTTT
-- Base3  ACGTRYACGTBDHKMNRSVWYACGTRYACGTHMWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTRYACGTBDHKMNRSVWYACGTHMWYACGTRYAAGRACTHMWYAGRAAGR
}
{
name "Bacterial and Plant Plastid" ,
id 11 ,
ncbieaa  "KNKNKNTTTTTTTTTTTTTTTRSRSRSIIMIXXIXIXXXXIIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLLLLLLLLLLLLLLEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBB*Y*Y*YSSSSSSSSSSSSSSS*CWCCLFLFLF*XXJXXRRRJJXJJJJJXXZZZXXJXLLL",
sncbieaa "---------------------------MMMMMMMMMMMMMMM--------------------------------------M--------------------------------------------------M-------------------------------------------M----MM-MM-----M-----MM---MM-M-M-"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTBDHHKMMMMMMMMMMMNRSSSSVWWYYY
-- Base2  AAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAAACCCCCCCCCCCCCCCGGGGGTTTTTTRTTTTTGGGTTTTTTTTTTAAATTTTTTT
-- Base3  ACGTRYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTRYACGTBDHKMNRSVWYACGTYACGTRYAGGAGGAGRACGTHMWYGGAGRGGAGAGR
}
{
name "Alternative Yeast Nuclear" ,
id 12 ,
ncbieaa  "KNKNKNTTTTTTTTTTTTTTTRSRSRSIIMIIIIIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLSLLLLLEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBB*Y*Y*YSSSSSSSSSSSSSSS*CWCCLFLFLF*JRRRJJXJJJJJZZZJL",
sncbieaa "-----------------------------M-------------------------------------------M--------------------------------------------------------------------------------------------------M----------"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTHMMMMMMMMMMMSSSWY
-- Base2  AAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAAACCCCCCCCCCCCCCCGGGGGTTTTTTRTGGGTTTTTTTTAAATT
-- Base3  ACGTRYACGTBDHKMNRSVWYACGTRYACGTHMWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTHMWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTRYACGTBDHKMNRSVWYACGTYACGTRYAAAGRACGTHMWYAGRAA
}
{
name "Ascidian Mitochondrial" ,
id 13 ,
ncbieaa  "KNKNKNTTTTTTTTTTTTTTTGSGSGSMIMIMIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLLLLLLLLLLLLLLEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBB*Y*Y*YSSSSSSSSSSSSSSSWCWCWCLFLFLFXXJJJGGGXZZZXLLL",
sncbieaa "---------------------------M-M-M------------------------------------------------------------------------------------------M--------------------------------------------M---MM------M---M---"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTDKMMMRRRRSSSWYYY
-- Base2  AAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTTTTGGGTAAATTTT
-- Base3  ACGTRYACGTBDHKMNRSVWYACGTRYACGTRYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTRYACGTBDHKMNRSVWYACGTRYACGTRYGGCTYAGRGAGRGAGR
}
{
name "Alternative Flatworm Mitochondrial" ,
id 14 ,
ncbieaa  "NNKNNNNNTTTTTTTTTTTTTTTSSSSSSSSSSSSSSSIIMIIIIIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLLLLLLLLLLLLLLEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBBYY*YYYYYSSSSSSSSSSSSSSSWCWCWCLFLFLFJJJJJJJJZZZJLLL",
sncbieaa "----------------------------------------M----------------------------------------------------------------------------------------------------------------------------------------------------------------"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTHMMMMMMMSSSWYYY
-- Base2  AAAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTTTTTTTAAATTTT
-- Base3  ACGTHMWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTHMWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTHMWYACGTBDHKMNRSVWYACGTRYACGTRYAACTHMWYAGRAAGR
}
{
name "Blepharisma Macronuclear" ,
id 15 ,
ncbieaa  "KNKNKNTTTTTTTTTTTTTTTRSRSRSIIMIIIIIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLLLLLLLLLLLLLLEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBB*YQYYSSSSSSSSSSSSSSS*CWCCLFLFLF*ZJZRRRJJJJJJJZZZJQLLL",
sncbieaa "-----------------------------M-------------------------------------------------------------------------------------------------------------------------------------------------------------------"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTBHKMMMMMMMMMMSSSWYYYY
-- Base2  AAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAACCCCCCCCCCCCCCCGGGGGTTTTTTRATAGGGTTTTTTTAAATATTT
-- Base3  ACGTRYACGTBDHKMNRSVWYACGTRYACGTHMWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTYACGTBDHKMNRSVWYACGTYACGTRYAGAGAGRACTHMWYAGRAGAGR
}
{
name "Chlorophycean Mitochondrial" ,
id 16 ,
ncbieaa  "KNKNKNTTTTTTTTTTTTTTTRSRSRSIIMIIIIIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLLLLLLLLLLLLLLEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBB*YLYYSSSSSSSSSSSSSSS*CWCCLFLFLF*LJRRRJJJJJJJZZZJLLL",
sncbieaa "-----------------------------M-----------------------------------------------------------------------------------------------------------------------------------------------------------------"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTHMMMMMMMMMMSSSWYYY
-- Base2  AAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAACCCCCCCCCCCCCCCGGGGGTTTTTTRWTGGGTTTTTTTAAATTTT
-- Base3  ACGTRYACGTBDHKMNRSVWYACGTRYACGTHMWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTYACGTBDHKMNRSVWYACGTYACGTRYAGAAGRACTHMWYAGRAAGR
}
{
name "Trematode Mitochondrial" ,
id 21 ,
ncbieaa  "NNKNNNNNTTTTTTTTTTTTTTTSSSSSSSSSSSSSSSMIMIMIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLLLLLLLLLLLLLLEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBB*Y*Y*YSSSSSSSSSSSSSSSWCWCWCLFLFLFJJJXZZZLLL",
sncbieaa "----------------------------------------M--------------------------------------------------------------------------------------------M---------------------------------------------------M------"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTMMMRSSSYYY
-- Base2  AAAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTTTAAATTT
-- Base3  ACGTHMWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTRYACGTBDHKMNRSVWYACGTRYACGTRYCTYGAGRAGR
}
{
name "Scenedesmus obliquus Mitochondrial" ,
id 22 ,
ncbieaa  "KNKNKNTTTTTTTTTTTTTTTRSRSRSIIMIIIIIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLLLLLLLLLLLLLLEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBB*YLYY*SSSSSSS*CWCCLFLFLF****LJRRRJJJJJJJZZZJLLL",
sncbieaa "-----------------------------M-------------------------------------------------------------------------------------------------------------------------------------------------------------"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTHMMMMMMMMMMSSSWYYY
-- Base2  AAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAACCCCCCCCGGGGGTTTTTTMRSVWTGGGTTTTTTTAAATTTT
-- Base3  ACGTRYACGTBDHKMNRSVWYACGTRYACGTHMWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTYACGTBKSYACGTYACGTRYAAAAGAAGRACTHMWYAGRAAGR
}
{
name "Thraustochytrium Mitochondrial" ,
id 23 ,
ncbieaa  "KNKNKNTTTTTTTTTTTTTTTRSRSRSIIMIIXIIIQHQHQHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLLLLLLLLLLLLLLEDEDEDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGVVVVVVVVVVVVVVVBBB*Y*Y*YSSSSSSSSSSSSSSS*CWCC*FLFF****RRRJJJJJJJXZZZL",
sncbieaa "-----------------------------MM-M--------------------------------------------------------------------------------------------M------------------------------------------------------------M----"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTMMMMMMMMMMRSSSY
-- Base2  AAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTMMMAAAAAACCCCCCCCCCCCCCCGGGGGTTTTTDKRWGGGTTTTTTTTAAAT
-- Base3  ACGTRYACGTBDHKMNRSVWYACGTRYACGTHKMWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTRYACGTBDHKMNRSVWYACGTBDHKMNRSVWYACGTBDHKMNRSVWYCTYACGTRYACGTBDHKMNRSVWYACGTYACGTYAAAAAGRACTHMWYGAGRG
}
{
name "Strict Standard" ,
ncbieaa  "KNKKNNTTTTTTTTTTTTTTTRSRRSSIIMIIIIIQHQQHHPPPPPPPPPPPPPPPRRRRRRRRRRRRRRRLLLLLLLLLLLLLLLEDEEDDAAAAAAAAAAAAAAAGGGGGGGGGGGGGGGBBBVVVVVVVVVVVVVVVJRRRJJJJJJJZZZ*Y**YYSSSSSSSSSSSSSSS*CWCC*LFLLFFJLLL",
sncbieaa "-----------------------------M-----------------------------------------------------------------------------------------------------------------------------------------------------------------"
-- Base1  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGHMMMMMMMMMMSSSTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTWYYY
-- Base2  AAAAAACCCCCCCCCCCCCCCGGGGGGTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGTTTTTTTTTTTTTTTAAAAAACCCCCCCCCCCCCCCGGGGGGGGGGGGGGGMMMTTTTTTTTTTTTTTTTGGGTTTTTTTAAAAAAAAACCCCCCCCCCCCCCCGGGGGRTTTTTTTTTT
-- Base3  ACGRTYABCDGHKMNRSTVWYACGRTYACGHMTWYACGRTYABCDGHKMNRSTVWYABCDGHKMNRSTVWYABCDGHKMNRSTVWYACGRTYABCDGHKMNRSTVWYABCDGHKMNRSTVWYCTYABCDGHKMNRSTVWYAAGRACHMTWYAGRACGRTYABCDGHKMNRSTVWYACGTYAACGRTYAAGR
}
