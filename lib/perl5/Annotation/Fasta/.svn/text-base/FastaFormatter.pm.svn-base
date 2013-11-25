package Annotation::Fasta::FastaFormatter;

=head1 NAME

Annotation::Fasta::FastaFormatter.pm 

A class to facilitate the creation of Fasta files.

=head1 VERSION

1.0

=head1 SYNOPSIS

use Annotation::Fasta::FastaFormatter;
my $formattedSeq = Annotation::Fasta::FastaFormatter::formatSeqeunce($sequence);

=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

=over 4

=cut

use strict;
use Carp;


=item new()

B<Description:> Instantiate FastaFormatter object

B<Parameters:> 

%args

B<Returns:> Returns a reference to FastaFormatter

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

B<Parameters:> 

%args

B<Returns:> None

=cut

sub _init {

    my $self = shift;
    my (%args) = @_;

    foreach my $key (keys %args ){
	$self->{"_$key"} = $args{$key};
    }
}

=item DESTROY

B<Description:> FastaFormatter class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  {

    my $self = shift;

}

=item formatSequence

B<Description:> Class method for formatting FASTA sequences

B<Parameters:> $seq (scalar - string)

B<Returns:> $seq (scalar - string)

=cut

sub formatSequence {

    #This subroutine takes a sequence name and its sequence and
    #outputs a correctly formatted single fasta entry (including newlines).
    
    my ($seq) = @_;
    
    $seq =~ s/\s+//g;
    my $fasta;

    for(my $i=0; $i < length($seq); $i+=60){
	
	my $seq_fragment = substr($seq, $i, 60);
	
	$fasta .= "$seq_fragment"."\n";
    }

    return $fasta;
}


1==1; ## end of module
