package Annotation::Fasta::FastaBuilder;
=head1 NAME

Annotation::Fasta::FastaBuilder.pm 

A class to facilitate the creation of Fasta files.

=head1 VERSION

1.0

=head1 SYNOPSIS

use Annotation::Fasta::FastaBuilder;
my $obj = new Annotation::Fasta::FastaBuilder( filename => '/tmp/myfile.fsa');
$obj->addRecord($fastaRecord);
$obj->writeFile();

=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

=over 4

=cut

use strict;
use Annotation::Fasta::FastaRecord;
use Annotation::Fasta::Logger;
use Data::Dumper;

my $logger = Annotation::Fasta::Logger::get_logger("Logger::Fasta");


## Class variable for keeping track of the number of FastaRecord records
my $fastaRecordCtr = 0;

## Instance variable for supporting the nextRecord() method
my $recordIndex = 0;

## Instance variable for supporting the nextRecord() method
my $sorted = 0;

=item new()

B<Description:> Instantiate FastaBuilder object

B<Parameters:> 

%args

B<Returns:> Returns a reference to FastaBuilder

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

    ## Instance data members

    ## This lookup is keyed on Fasta headers name with value being the FastaRecord values.
    $self->{'_records'} = {};

}

=item DESTROY

B<Description:> FastaBuilder class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  {
    my $self = shift;

}

=item $obj->addRecord($fastaRecord)

B<Description:> Add FASTA record

B<Parameters:> 

$fastaRecord - FastaRecord object

B<Returns:> None

=cut

sub addRecord {

    my ($self) = shift;
    my ($fastaRecord) = @_;

    if (!defined($fastaRecord)){
	$logger->logdie("fastaRecord was not defined");
    }

    my $header = $fastaRecord->getHeader();
    if (!defined($header)){
	$logger->logdie("Could not retrieve FASTA header for FastaRecord:" . Dumper $fastaRecord);
    }
    else {
	$self->{'_records'}->{$fastaRecord->getHeader()} = $fastaRecord;
    }
}

=item $obj->deleteRecord($header)

B<Description:> Remove all references to the FastaRecord given the FASTA header value

B<Parameters:> $header (scalar)

B<Returns:> None

=cut

sub deleteRecord {

    my ($self) = shift;
    my ($header) = @_;

    if (exists $self->{'_records'}->{$header}){
	delete $self->{'_records'}->{$header};

	## Decrement the class member
	$fastaRecordCtr--;

	## Keep track of which id values for FastaTerms that have been removed.
	$self->{'_removed_records'}->{$header}++;
    }
    else {
	$logger->warn("FastaRecord with FASTA header value '$header' does not exist");
    }
}

=item $obj->doesRecordExist($header)

B<Description:> Check whether a FASTA record header already exists

B<Parameters:> $header - scalar/string FASTA record header

B<Returns:> 

0 - scalar false
1 - scalar true

=cut

sub doesRecordExist {

    my ($self) = shift;
    my ($header) = @_;

    if (!defined($header)){
	$logger->logdie("header name was not defined");
    }

    if (exists $self->{'_records'}->{$header}){
	return 1;
    }
    return 0;
}


=item $obj->setFilename($filename)

B<Description:> Set the output Fasta filename

B<Parameters:> $filename - scalar/string name of the output file

B<Returns:> None

=cut

sub setFilename {

    my ($self) = shift;
    my ($filename) = @_;

    if (!defined($filename)){
	$logger->logdie("output filename was not defined");
    }

    $self->{'_filename'} = $filename;
}

=item $obj->getFilename($filename)

B<Description:> Get the output Fasta filename

B<Parameters:> none

B<Returns:> $filename - scalar/string name of the output file

=cut

sub getFilename {

    my ($self) = shift;

    if (exists $self->{'_filename'}){
	return $self->{'_filename'};
    }
    else {
	$logger->warn("output filename does not exist");
    }
}

sub createAndAddFastaRecord {

    my ($self) = shift;
    my ($header, $sequence) = @_;

    my $fastaRecord = new Annotation::Fasta::FastaRecord($header, $sequence);

    if (!defined($fastaRecord)){
	$logger->logdie("Could not instantiate Annotation::Fasta::FastaRecord for header '$header' sequence '$sequence'");
    }
    
    ## Store reference to this new FastaRecord
    $self->{'_records'}->{$header} = $fastaRecord;
    
    ## Increment the class member
    $fastaRecordCtr++;

    return $fastaRecord;
}


sub writeFile {

    my ($self) = shift;

    if (exists $self->{'_filename'} ){
	my $fh;
	open ($fh, ">$self->{'_filename'}") || $logger->logdie("Could not open file '$self->{'_filename'}' in write mode: $!");

	foreach my $header ( keys %{$self->{'_records'}} ) {
	    $self->{'_records'}->{$header}->writeRecord($fh);
	    print $fh "\n";
	}

	close $fh;	
    }
    else {
	$logger->logdie("output filename not defined");
    }
}


sub write {

    my ($self) = shift;

    if (exists $self->{'_filename'} ){
	$self->writeFile();
    } else {

	my $outdir;

	if (exists $self->{'_outdir'}){
	    $outdir = $self->{'_outdir'};
	} else {
	    $outdir = '/tmp/';
	    $self->{'_outdir'} = $outdir;
	}

	foreach my $header ( keys %{$self->{'_records'}} ) {
	
	    my ($basename, @junk) = split(/\s/, $header);

#	    $basename =~ s/\s+/\s/g;
#	    $basename =~ s/\s/_/g;

	    my $filename = $outdir . '/' . $basename . '.fsa';

	    my $fh;

	    open ($fh, ">$filename") || $logger->logdie("Could not open file '$filename in write mode: $!");

	    $self->{'_records'}->{$header}->writeRecord($fh);

	    close $fh;	
	}
    }
}

# =item $obj->nextRecord()

# B<Description:> Iteratively returns reference to each FastaRecord

# B<Parameters:> None

# B<Returns:> reference to FastaTerm

# =cut

# sub nextRecord {

#     my ($self) = shift;

#     if ($oboTermCtr > 0 ){

# 	if ($sorted == 0 ) {
# 	    if ($logger->is_debug()){
# 		$logger->debug("The FastaTerms have not yet been sorted by id");
# 	    }
# 	    ## If the FastaTerms aren't already sorted, do so now.
# 	    foreach my $id (sort keys %{$self->{'_terms'}} ) {
# 		push ( @{$self->{'_sorted_terms'}}, $id );	
# 	    }
	    
# 	    ## The list has been sorted once, let's not do it again.
# 	    $sorted = 1;
# 	}
	
# 	if ( $recordIndex < $oboTermCtr ){
# 	    my $id = $self->{'_sorted_terms'}->[$recordIndex++];
# 	    if (defined($id)){
# 		return $self->getRecordById($id);
# 	    }
# 	    else {
# 		$logger->logdie("id was not defined for recordIndex '$recordIndex'");
# 	    }
# 	}
#     }
#     else {
# 	return $self->nextTypedef();
#     }

#     return undef;
# }


# =item $obj->resetTermIndex()

# B<Description:> Reset the FastaTerm index

# B<Parameters:> None

# B<Returns:> None

# =cut

# sub resetTermIndex {

#     my ($self) = shift;
#     $recordIndex=0;
# }


=item $obj->getFastaRecordCount()

B<Description:> Get the number of FASTA records

B<Parameters:> none

B<Returns:> $count - scalar/string

=cut

sub getFastaRecordCount {

    my ($self) = shift;

    return $fastaRecordCtr;
}


1;

