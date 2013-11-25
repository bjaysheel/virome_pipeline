package Prism::DB2FASTA;

=head1 NAME

Prism::DB2FASTA.pm

A module to assist with changing the state of feature records.

=head1 VERSION

1.0

=head1 SYNOPSIS

use Prism::DB2FASTA;


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

new
_init
_setPrismEnv
DESTROY



=over 4

=cut

use strict;
use Carp;
use Prism;
use Data::Dumper;
use Annotation::Util2;
use Annotation::Fasta::FastaFormatter;
use Annotation::Fasta::FastaBuilder;

use constant TEXTSIZE => 100000000;

use constant TRUE  => 1;
use constant FALSE => 0;

use constant DEFAULT_USERNAME => 'access';
use constant DEFAULT_PASSWORD => 'access';
use constant DEFAULT_SERVER   => 'SYBPROD';
use constant DEFAULT_VENDOR   => 'sybase';

use constant DEFAULT_FILE_EXTENSION => '.fsa';

use constant PROTEIN_COUNT_THRESHOLD => 1000;

=item new()

B<Description:> Instantiate Prism::DB2FASTA object

B<Parameters:> None

B<Returns:> reference to the Prism::DB2FASTA object

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

    $self->_setFileExtension();

    if (! ((exists $self->{_prism}) && (defined($self->{_prism})))){

	## Abstract method defined in one of the subclasses.
	$self->_setPrismEnv($self->{_vendor}, $self->{_server});

	$self->_initPrism(@_);
    }

    return $self;
}

sub _setFileExtension {

    my $self = shift;

    if (! (( exists $self->{_file_ext}) && (defined($self->{_file_ext})))){
	$self->{_file_ext} = DEFAULT_FILE_EXTENSION;
    }
}



=item $self->_init(%args)

B<Description:> Typical Perl init() method

B<Parameters:> %args

B<Returns:> None

=cut

sub _checkVendor {

    my $self = shift;

    if (! (( exists $self->{_VENDOR}) && (defined($self->{_VENDOR})))){
	$self->{_vendor} = DEFAULT_VENDOR;
    }
}

=item $self->_init(%args)

B<Description:> Typical Perl init() method

B<Parameters:> %args

B<Returns:> None

=cut

sub _checkServer {

    my $self = shift;

    if (! (( exists $self->{_server}) && (defined($self->{_server})))){
	$self->{_server} = DEFAULT_SERVER;
    }
}

=item $self->_init(%args)

B<Description:> Typical Perl init() method

B<Parameters:> %args

B<Returns:> None

=cut

sub _setPrimEnv {

    my $self = shift;
    confess "Abstract method";
}

=item $self->_init(%args)

B<Description:> Typical Perl init() method

B<Parameters:> %args

B<Returns:> None

=cut

sub _initPrism {

    my $self = shift;
    if (! (( exists $self->{_username}) && (defined($self->{_username})))){
	$self->{_username} = DEFAULT_USERNAME;
    }

    if (! (( exists $self->{_password}) && (defined($self->{_password})))){
	$self->{_password} = DEFAULT_PASSWORD;
    }
    
    my $prism = new Prism(user     => $self->{_username},
			  password => $self->{_password},
			  db       => $self->{_database});
    
    if (!defined($prism)){
	confess "Could not instantiate Prism";
    }
    
    $self->{_prism} = $prism;

    print "Instantiated Prism object\n";

    return $self;

}

=item DESTROY

B<Description:> Prism::DB2FASTA class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

    my $self = shift;
}

=item $self->convert(%args)

B<Description:> Main method

B<Parameters:> %args

B<Returns:> None

=cut

sub convert {

    my $self = shift;
    
    if ( $self->_infileSpecified(@_)){

	$self->_convertViaInFile();
	
    } else {
	$self->_convert(@_);
    }

}

=item $self->_infileSpecified(%args)

B<Description:> Determine whether an infile was specified

B<Parameters:> %args

B<Returns:> $bool (scalar - unsigned integer) 0 = FALSE, 1 = TRUE

=cut

sub _infileSpecified {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{infile}) && (defined($args{infile}))){

	$self->{_infile} = $args{infile};
	return TRUE;

    } elsif (( $self->{_infile}) && (defined($self->{_infile}))){
	return TRUE;

    } else {
	return FALSE;
    }
}

=item $self->_loadProteinLookup(%args)

B<Description:> Retrieve all proteins from the source database and generate a protein lookup

B<Parameters:> %args

B<Returns:> None

=cut

sub _loadProteinLookup {

    ## This method should be moved to Prism::DB2FASTA
    my $self = shift;

    print "Will retrieve all protein sequences from ".
    "database '$self->{_database}' on server '$self->{_server}'\n";

    my $records = $self->{_prism}->proteinSequences();
    if (!defined($records)){
	confess "Could not retrieve records";
    }

    
    my $lookup={};
    my $ctr=0;

    print "Will build the protein lookup now\n";

    foreach my $record (@{$records}){
	$lookup->{$record->[0]} = $records->[1];
	$ctr++;
    }

    print "Added '$ctr' protein sequences to the lookup\n";

    $self->{_protein_lookup} = $lookup;
}

=item $self->_loadSmallProteinLookup(%args)

B<Description:> Retrieve specific proteins from the source database and generate a protein lookup

B<Parameters:> %args

B<Returns:> None

=cut

sub _loadSmallProteinLookup {

    my $self = shift;
    my ($contents) = @_;

    print "Will retrieve specific protein sequences from ".
    "database '$self->{_database}' on server '$self->{_server}'\n";

    my $lookup={};
    my $ctr=0;

    ## Set the max text size for sequence and protein data fields
    $self->{_prism}->{_backend}->do_set_textsize(TEXTSIZE);
    
    foreach my $line (@{$contents}){

	my @parts = split(/\s+/, $line);

	foreach my $protein (@parts){

	    if ($protein =~ /:$/){
		## This protein group was given a group identifier
		## likely the cluster ID
		next;
	    }

	    my $record = $self->{_prism}->proteinSequence($protein);
	    if (!defined($record)){
		confess "Could not retrieve records";
	    }

	    $lookup->{$protein} = $record->[0][0];
	    $ctr++;
	}
    }

    print "Added '$ctr' protein sequences to the lookup\n";

    $self->{_protein_lookup} = $lookup;
}

=item $self->_convertViaInfile(%args)

B<Description:> Process only the proteins cited in the input file

B<Parameters:> %args

B<Returns:> None

=cut

sub _convertViaInFile {

    my $self = shift;

    my $file = $self->_getInfile(@_);
    if (!Annotation::Util2::checkInputFileStatus($file)){
	confess "Detected some problem with file '$file'";
    }
    
    my $contents = Annotation::Util2::getFileContentsArrayRef($file);
    if (!defined($contents)){
	confess "Could not retrieve contents of file '$file'";
    }

    if ($self->_getProteinCount($contents) > PROTEIN_COUNT_THRESHOLD){
	$self->_loadProteinLookup(@_);
    } else {
	$self->_loadSmallProteinLookup($contents);
    }

    my $outdir = $self->_getOutdir(@_);
    if (!-e $outdir){
	mkpath($outdir) || confess "Could not create output directory '$outdir': $!";
    }

    my $ctr=0;
    my $outfile;
    my $groupID;

    foreach my $line (@{$contents}){

	my @parts = split(/\s+/, $line);

#	print Dumper \@parts;die;

	if ($parts[0] =~ /:$/){

	    ## This protein group was given a group identifier
	    ## likely the cluster ID

	    $groupID = shift(@parts);

	    chop($groupID);  ## remove that trailing colon.

	} else {

	    ## The first protein listed in this group will be the
	    ## representative.

	    $groupID = $parts[0];
	}
	
	if (!defined($groupID)){
	    confess "groupID was not defined for set:". Dumper \@parts;
	}

	$outfile = $outdir . '/' . $groupID . $self->{_file_ext};

	print "outfile '$outfile'\n";

	my $builder = new Annotation::Fasta::FastaBuilder(filename=>$outfile);
	if (!defined($builder)){
	    confess "Could not instantiate Annotation::Fasta::FastaBuilder";
	}

	foreach my $protein (@parts){

	    if ((exists $self->{_protein_lookup}->{$protein}) && (defined($self->{_protein_lookup}->{$protein}))){
		my $seq = $self->{_protein_lookup}->{$protein};
		my $header = $self->_createHeader($protein);
		$builder->createAndAddFastaRecord($header, $seq);
	    } else {
		
		confess "protein '$protein' does not exist in the protein lookup!";
	    }
	}

	$builder->write();
	$ctr++;
    }

    if ($ctr > 1){
	print "Wrote FASTA files to output directory '$outdir'\n";
    } elsif ($ctr == 0){
	confess "Did not write any output FASTA files";
    } else {
	print "Wrote the FASTA file to output directory '$outdir'\n";
    }

}

=item $self->_convert(%args)

B<Description:> 

B<Parameters:> %args

B<Returns:> None

=cut

sub _convert {

    my $self = shift;
    my (%args) = @_;

    $self->_loadProteinLookup();
    
    if ((exists $self->{_single}) && (defined($self->{_single}))){
	
	$self->_writeIndividualFastaFiles(@_);
	
    } else {

	$self->_writeMultiFastaFile(@_);
    }
}

=item $self->_writeIndividualFastaFiles()

B<Description:> Write a individual single-FASTA files (one per protein)

B<Parameters:> None

B<Returns:> None

=cut

sub _writeIndividualFastaFiles {

    my $self = shift;
    my $outdir = $self->_getOutdir(@_);

    my $ctr=0;

    foreach my $protein (keys %{$self->{_protein_lookup}}){

	my $outfile = $outdir . '/' . $protein . $self->{_file_ext};

	open (OUTFILE, ">$outfile") || confess "Could not open output file '$outfile': $!";

	my $seq = $self->{_protein_lookup}->{$protein};

	my $header = $self->_createHeader($protein);

	my $formattedSeq = Annotation::Fasta::FastaFormatter::formatSequence($seq);

	if (!defined($formattedSeq)){
	    confess "formatted sequence was not defined";
	}

	print OUTFILE ">$header\n$formattedSeq";

	$ctr++;
    }

    print "Wrote '$ctr' FASTA sequences to as many FASTA files\n";
}

=item $self->_writeMultiFastaFile()

B<Description:> Write a single multi-FASTA file containing all of the proteins

B<Parameters:> None

B<Returns:> None

=cut

sub _writeMultiFastaFile {

    my $self = shift;

    my $outfile = $self->getOutfile(@_);

    open (OUTFILE, ">$outfile") || confess "Could not open output file '$outfile': $!";
 
    my $ctr=0;

    foreach my $protein (keys %{$self->{_protein_lookup}}){

	my $seq = $self->{_protein_lookup}->{$protein};

	my $header = $self->_createHeader($protein);

	my $formattedSeq = Annotation::Fasta::FastaFormatter::formatSequence($seq);

	if (!defined($formattedSeq)){
	    confess "formatted sequence was not defined";
	}

	print OUTFILE ">$header\n$formattedSeq";
	$ctr++;
    }

    print "Wrote '$ctr' FASTA sequences to multi-FASTA file '$outfile'\n";
}

=item $self->_createHeader($protein, $groupID)

B<Description:> Format the FASTA header

B<Parameters:>

$protein (scalar - string)
$groupID (scalar - string)

B<Returns:> $header (scalar - string)

=cut

sub _createHeader {

    my $self = shift;

    my ($protein, $groupID) = @_;

    return $protein;
}

=item $self->_getInfile(%args)

B<Description:> Retrieve the infile

B<Parameters:> %args

B<Returns:> $infile (scalar - string)

=cut

sub _getInfile {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{infile}) && (defined($args{infile}))){

	$self->{_infile} = $args{infile};

    } elsif (( $self->{_infile}) && (defined($self->{_infile}))){
	## okay

    } else {
	confess "infile was not defined";
    }

    return $self->{_infile};
}

=item $self->_getOutdir(%args)

B<Description:> Retrieve the outdir

B<Parameters:> %args

B<Returns:> $outdir (scalar - string)

=cut

sub _getOutdir {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{outdir}) && (defined($args{outdir}))){

	$self->{_outdir} = $args{outdir};

    } elsif (( $self->{_outdir}) && (defined($self->{_outdir}))){
	## okay

    } else {
	confess "outdir was not defined";
    }

    return $self->{_outdir};
}

=item $self->_getOutfile(%args)

B<Description:> Retrieve the outfile

B<Parameters:> %args

B<Returns:> $outfile (scalar - string)

=cut

sub _getOutfile {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{outfile}) && (defined($args{outfile}))){

	$self->{_outfile} = $args{outfile};

    } elsif (( $self->{_outfile}) && (defined($self->{_outfile}))){
	## okay

    } else {
	confess "outfile was not defined";
    }

    return $self->{_outfile};
}

sub _getProteinCount {

    my $self = shift;
    my ($contents) = @_;
    
    my $ctr=0;
    foreach my $line (@{$contents}){
	chomp $line;
	my @parts = split(/\s+/, $line);
	if ($parts[0] =~ /:$/){
	    $ctr+= scalar(@parts) - 1;
	} else {
	    $ctr+= scalar(@parts);
	}

	if ($ctr > PROTEIN_COUNT_THRESHOLD){
	    last;
	}
    }

    if ($ctr > PROTEIN_COUNT_THRESHOLD){
	return (PROTEIN_COUNT_THRESHOLD + 1);
    } else {
	return $ctr;
    }
}


1==1; ## end of module
