package Annotation::Fasta::FastaParser;
=head1 NAME

Annotation::Fasta::FastaParser.pm 

A class to facilitate the parsing of FASTA files.

=head1 VERSION

1.0

=head1 SYNOPSIS

 use Annotation::Fasta::FastaParser;
 my $parser = new Annotation::Fasta::FastaParser( filename => '/tmp/myfile.fsa');
 my $lookup = $parser->getFastaLookup();


 use Annotation::Fasta::FastaParser;
 my $parser = new Annotation::Fasta::FastaParser( filename => '/tmp/myfile.fsa', checksums => 1, checksum_file => '/tmp/mycheck.txt');
 $parser->writeChecksumFile();

=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS


=over 4

=cut

use strict;
use Annotation::Fasta::Logger;
use Digest::MD5 qw(md5_hex);

my $logger = Fasta::Logger::get_logger("Logger::Fasta");

=item new()

B<Description:> Instantiate FastaParser object

B<Parameters:> 

 %args

B<Returns:> Returns a reference to FastaParser

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

B<Description:> FastaParser class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  {
    my $self = shift;

}

=item $obj->setFilename($filename)

B<Description:> Set the input Fasta filename

B<Parameters:> $filename - scalar/string name of the input file

B<Returns:> None

=cut

sub setFilename {

    my ($self) = shift;
    my ($filename) = @_;

    if (!defined($filename)){
	$logger->logdie("input filename was not defined");
    }

    $self->{'_filename'} = $filename;
}

=item $obj->getFilename()

B<Description:> Get the input Fasta filename

B<Parameters:> none

B<Returns:> $filename - scalar/string name of the input file

=cut

sub getFilename {

    my ($self) = shift;

    if (exists $self->{'_filename'}){
	return $self->{'_filename'};
    }
    else {
	$logger->warn("input filename does not exist");
    }
}

=item $obj->setChecksumFilename($filename)

B<Description:> Set the output checksum filename

B<Parameters:> $filename - scalar/string name of the output checksum file

B<Returns:> None

=cut

sub setChecksumFilename {

    my ($self) = shift;
    my ($filename) = @_;

    if (!defined($filename)){
	$logger->logdie("input filename was not defined");
    }

    $self->{'_checksum_file'} = $filename;
}

=item $obj->getChecksumFilename()

B<Description:> Get the output checksum filename

B<Parameters:> none

B<Returns:> $filename - scalar/string name of the output checksum file

=cut

sub getChecksumFilename {

    my ($self) = shift;

    if (exists $self->{'_checksum_file'}){
	return $self->{'_checksum_file'};
    }
    else {
	$logger->warn("output checksum filename does not exist");
    }
}


=item $obj->getFastaLookup()

B<Description:> Retrieve a hash keyed on FASTA-headers with values being the FASTA sequences

B<Parameters:> None

B<Returns:> reference to a hash

=cut

sub getFastaLookup {

    my $self = shift;

    if (! exists $self->{'_parsed'}){
	return $self->_parseFile();
    }
    else {
	return $self->{'_lookup'};
    }
}



=item $obj->_parseFile()

B<Description:> Parses the input Fasta file and creates/returns a reference to a hash

B<Parameters:> None

B<Returns:> reference to a hash

=cut

sub _parseFile {

    my $self = shift;

    if (exists $self->{'_filename'}){

	my ($infile) = $self->{'_filename'};

	open(INFILE, "<$infile") || $logger->logdie("Could not open infile '$infile' in read mode:$!");
	
	my $lookup={};
	my $header;
	my $seq;
	my $headerctr=0;
	
	while (my $line = <INFILE>){
	    chomp $line;

	    if ($line =~ /^>/){

		$headerctr++;

		if ((defined($header)) && (defined($seq))){

		    $seq =~ s/\s+//g;
		    $seq =~ s/\n+//g;
		    
		    $lookup->{$header} = $seq;
		    
		    if (exists $self->{'_checksums'}){
			$self->{'_checksum_lookup'}->{$header} = Digest::MD5::md5_hex($seq);
		    }
		    
		    $header=undef;
		    $seq=undef;
		}
		$header = $line;
		$header =~ s/^>//;

	    } elsif ($line =~ /^\#/){
	      ## Any commented lines should be entirely ignored.
	      next;
	    } else {
		$seq.=$line;
	    }
	}
	
	## Store the last FASTA record in the lookup!
	$lookup->{$header} = $seq;

	if ($logger->is_debug()){
	    $logger->debug("FASTA lookup:" . Dumper $lookup);
	}
	
	$logger->info("Counted '$headerctr' FASTA headers in file '$infile'");

	## Store the number of FASTA headers encounted during this parse.
	$self->{'_record_ctr'} = $headerctr;

	## Store reference to the lookup.
	$self->{'_lookup'} = $lookup;

	## Set state to indicate that the FASTA file was parsed by this method.
	$self->{'_parsed'} = 1;

	return $lookup;
    }
    else {
	$logger->logdie("Which file did you want me to parse?");
    }
}

=item $obj->_getFileContents()

B<Description:> Read in entire contents of the Fasta file

B<Parameters:> $filename - scalar name of the Fasta file

B<Returns:> Reference to array

=cut

sub _getFileContents {

    my $self = shift;
    my ($filename) = @_;

    if (!defined($filename)){
	$logger->logdie("filename was not defined");
    }

    if (!-e $filename){
	$logger->logdie("file '$filename' does not exist");
    }

    if (!-r $filename){
	$logger->logdie("file '$filename' does not have read permissions");
    }

    if (!-f $filename){
	$logger->logdie("file '$filename' is not a regular file");
    }

    if (!-s $filename){
	$logger->logdie("file '$filename' does not have any content");
    }


    print "Reading entire contents of file '$filename'\n";

    open (INFILE, "<$filename") or $logger->logdie("Could not open file '$filename' in read mode: $!");

    my @lines = <INFILE>;
    
    chomp @lines;

    return \@lines;
}

=item $obj->writeChecksumFile()

B<Description:> 

B<Parameters:> 

B<Returns:> None

=cut

sub writeChecksumFile {

    my $self = shift;

    if (! exists $self->{'_parsed'}){
	$self->_parseFile();
    }

    if (exists $self->{'_checksum_lookup'}){
	$logger->logdie("checksum lookup does not exist");
    }
    
    if (exists $self->{'_checksum_file'}){
	$logger->logdie("checksum file was not defined");
    }
	
    if (exists $self->{'_lookup'}){
	$logger->logdie("lookup was not defined!");
    }

    my $lookup = $self->{'_lookup'};

    open (OUTFILE, ">$self->{'_checksum_file'}") || $logger->logdie("Could not open checksum file '$self->{'_checksum_file'}' in write mode:$!");

    foreach my $header ( keys %{$lookup}){

	print OUTFILE "$header\t$self->{'_checksum_lookup'}->{$header}\n";
    }
}

=item $obj->getSequenceById()

B<Description:> 

B<Parameters:> 

B<Returns:> None

=cut

sub getSequenceById {

    my $self = shift;
    my ($id) = @_;

    if (!defined($id)){
	$logger->logdie("id was not defined");
    }

    if (! exists $self->{'_parsed'}){
	$self->_parseFile();
    }
    if (! exists $self->{'_lookup'}){
	$logger->logdie("_lookup is not defined!");
    }

    if ( exists $self->{'_lookup'}->{$id}){
	return $self->{'_lookup'}->{$id};
    } else {
	$logger->warn("id '$id' does not exist in lookup");
	return undef;
    }
}


1; ## End of module

