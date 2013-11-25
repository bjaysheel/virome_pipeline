package Annotation::Fasta::FastaRecord;

=head1 NAME

Annotation::Fasta::FastaRecord.pm

=head1 VERSION

1.0

=head1 SYNOPSIS

use Annotation::Fasta::FastaRecord;
my $obj = new Annotation::Fasta::FastaRecord($header, $sequence);
$obj->writeRecord($fileHandle1);

=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

=over 4

=cut

use strict;
use Annotation::Fasta::FastaBuilder;
use Annotation::Fasta::Logger;

my $logger = Annotation::Fasta::Logger::get_logger("Logger::Fasta");


=item new($header, $sequence)

B<Description:> Instantiate FastaRecord object

B<Parameters:> 

 $header (scalar) the FASTA header
 $sequence (scalar) the FASTA sequence

B<Returns:> reference to the FastaRecord

=cut

sub new  {

    my $class = shift;

    my ($header, $sequence) = @_;

    my $self = {};

    if (!defined($header)){
	$logger->logdie("header was not defined");
    }
    else {
	$self->{'_header'} = $header;
    }

    if (defined($sequence)){
	$self->{'_sequence'} = $sequence;
    }
    else {
	$logger->logdie("sequence was not defined");
    }

    bless $self, $class;    

    return $self;
}

=item $self->_init()

B<Description:> Not being used at this time.

B<Parameters:> None at this time.

B<Returns:> Nothing at this time.

=cut 

sub _init {

    my $self = shift;
}

=item DESTROY

B<Description:> FastaRecord class destructor

B<Parameters:> None

B<Returns:> None

=cut 

sub DESTROY  {
    my $self = shift;

}

=item $obj->getHeader()

B<Description:> Retrieves the header for the FastaRecord

B<Parameters:> None

B<Returns:> $header - scalar

=cut 

sub getHeader {

    my ($self) = shift;

    if (!defined($self)){
	$logger->logdie("self was not defined");
    }
    
    if ( exists $self->{'_header'} ) {
	return  $self->{'_header'};
    }
    else {
	$logger->logdie("FastaRecord does not have a header value!");
    }
}

=item $obj->setHeader()

B<Description:> Set the header value for the FastaRecord

B<Parameters:> $header - scalar

B<Returns:> none

=cut 

sub setHeader {

    my ($self) = shift;
    my ($header) = @_;

    if (!defined($self)){
	$logger->logdie("self was not defined");
    }

    if (!defined($header)){
	$logger->logdie("header was not defined");
    }
    
    $self->{'_header'} = $header;
}

=item $obj->getSequence()

B<Description:> Retrieves the sequence for the FastaRecord

B<Parameters:> None

B<Returns:> $sequence - scalar

=cut 

sub getSequence {

    my ($self) = shift;

    if (!defined($self)){
	$logger->logdie("self was not defined");
    }
    
    if ( exists $self->{'_sequence'} ) {
	return  $self->{'_sequence'};
    }
    else {
	$logger->warn("sequence is not defined for FastaRecord with header '$self->{'_header'}'");
    }
}

=item $obj->setSequence()

B<Description:> Set the sequence for the FastaRecord

B<Parameters:> $sequence - scalar

B<Returns:> none

=cut 

sub setSequence {

    my ($self) = shift;
    my ($sequence) = @_;

    if (!defined($self)){
	$logger->logdie("self was not defined");
    }

    if (!defined($sequence)){
	$logger->logdie("sequence was not defined");
    }
    
    $self->{'_sequence'} = $sequence;
}


=item $obj->writeRecord($fh)

B<Description:> Method that writes the FASTA record to the filehandle fh.

B<Parameters:>

 $fh     - filehandle for output file

B<Returns:>  None

=cut 

sub writeRecord {

    my ($self) = shift;
    my ($fh) = @_;

    if (!defined($self)){
	$logger->logdie("self was not defined");
    }
    if (!defined($fh)){
	$logger->logdie("fh was not defined");
    }

    my $formattedFastaSequence = $self->formatFastaSequence($self->{'_header'}, $self->{'_sequence'});
    
    print $fh "$formattedFastaSequence";
}

=item $obj->formatFastaSequence($header, $sequence)

B<Description:> Method that formats the final FASTA record for output

B<Parameters:>

 $header - (scalar) the FASTA record header
 $header - (scalar) the FASTA record sequence

B<Returns:>  None

=cut 

sub formatFastaSequence {

    #This subroutine takes a sequence name and its sequence and
    #outputs a correctly formatted single fasta entry (including newlines).
    
    my $self = shift;
    my ($header, $seq) = @_;
    
    my $fasta=">"."$header"."\n";

    $seq =~ s/\s+//g;

    for(my $i=0; $i < length($seq); $i+=60){

	my $seq_fragment = substr($seq, $i, 60);

	$fasta .= "$seq_fragment"."\n";
    }
    return $fasta;
}

1;
