package BSML::Parser;

=head1 NAME

BSML::Parser.pm

=head1 VERSION

1.0

=head1 SYNOPSIS

use BSML::Parser;

Module containing simple parsing support for Prism API software.

=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS


=over 4

=cut

use strict;
use Carp;
use Data::Dumper;
use XML::Twig;

use constant TRUE  => 1;
use constant FALSE => 0;

=item new()

B<Description:> Instantiate BSML::Parser object

B<Parameters:> None

B<Returns:> reference to the BSML::Parser object

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

    return $self;
}

=item DESTROY

B<Description:> BSML::Parser class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

    my $self = shift;
}

sub getLookup {

    my $self = shift;
    if (( exists $self->{_file_parsed}) &&
	( defined($self->{_file_parsed}))){
	return $self->{_lookup};
    } else {
	$self->_parse(@_);
	return $self->{_lookup};
    }
}

sub getFeatureCount {

    my $self = shift;

    if (( exists $self->{_feature_ctr}) &&
	( defined($self->{_feature_ctr}))){
	return $self->{_feature_ctr};

    } else {
	warn "feature count was not defined\n";
	return undef;
    }
}

sub _getFile {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{file}) && (defined($args{file}))){
	$self->{_file} = $args{file};
    } elsif (( exists $self->{_file}) && ( defined($self->{_file}))){
	## okay
    } else {
	confess "file was not defined";
    }

    return $self->{_file};
}

sub _parse {

    my $self = shift;
   
    my $file = $self->_getFile(@_);

    if (!defined($file)){
	confess "file was not defined";
    }

    my $lookup={};
    my $ctr=0;
    my $dupCtr=0;
    my $uniqCtr=0;
    my $refseq;

    my $twig = new XML::Twig ( TwigRoots => { 'Sequence' => 1,
					      'Feature' => 1 },
			       TwigHandlers => { 'Sequence' => sub {
				   if ($_[1]->{att}->{class} eq 'assembly'){
				       $refseq = $_[1]->{att}->{id};
				   }
			       },
						 'Feature' => sub { 
				   my $id = $_[1]->{att}->{id};
				   if (! exists $lookup->{$id}){
				       $uniqCtr++;
				   } else {
				       $dupCtr++;
				   }
				       
				   $lookup->{$id}++;
				   $ctr++;

				   if ($id =~ /polypeptide/){
				       $self->{_polypeptide_ctr}++;
				   } elsif ( $id =~ /gene/){
				       $self->{_gene_ctr}++;
				   } elsif ( $id =~ /CDS/){
				       $self->{_cds_ctr}++;
				   } elsif ( $id =~ /transcript/){
				       $self->{_transcript_ctr}++;
				   } elsif ( $id =~ /exon/){
				       $self->{_exon_ctr}++;
				   } else {
				       $self->{_misc_ctr}++;
				   }

			       }});

    if (!defined($twig)){
	confess "Could not instantiate XML::Twig";
    }

    my $bsml_fh;
    
    if ( ! -e $file && -e "$file.gz" ) {
        open($bsml_fh, "<:gzip", "$file.gz") || confess "Could not open BSML file '$file.gz' in read mode: $!";
    } else {
        open($bsml_fh, "<$file") || confess "Could not open BSML file '$file' in read mode: $!";
    }
    
    print "Processing BSML file: $file\n";

    $twig->parse( $bsml_fh );
    
    print "Parsed '$ctr' Feature elements\n";
    print "Encountered '$uniqCtr' unique Feature identifier values\n";

    if ($dupCtr>0){
	print "Encountered '$dupCtr' duplicate Feature identifier values\n";
    }

    $self->{_file_parsed} = TRUE;

    if (! defined($refseq)){
	confess "Could not retrieve the reference sequence identifier!";
    }

    $self->{_refseq} = $refseq;

    $self->{_feature_ctr} = $ctr;

    $self->{_uniq_ctr} = $uniqCtr;

    $self->{_dup_ctr} = $dupCtr;

    $self->{_lookup} = $lookup;
}

sub getRefSeq {

    my $self = shift;

    if ((exists $self->{_refseq}) && ( defined($self->{_refseq}))){
	return $self->{_refseq};
    } else {
	warn "refseq was not defined";
	return undef;
    }
}


sub getUniqueFeatureCount {

    my $self = shift;
    if (( exists $self->{_uniq_ctr}) &&
	( defined($self->{_uniq_ctr}))){
	return $self->{_uniq_ctr};
    } else {
	warn "unique feature count was not defined\n";
	return undef;
    }
}


sub getDuplicateFeatureCount {

    my $self = shift;
    if (( exists $self->{_dup_ctr}) &&
	( defined($self->{_dup_ctr}))){
	return $self->{_dup_ctr};
    } else {
	warn "duplicate feature count was not defined\n";
	return undef;
    }
}

sub getGeneCount {

    my $self = shift;
    if (( exists $self->{_gene_ctr}) &&
	( defined($self->{_gene_ctr}))){
	return $self->{_gene_ctr};
    } else {
	warn "gene feature count was not defined\n";
	return undef;
    }
}

sub getTranscriptCount {

    my $self = shift;
    if (( exists $self->{_transcript_ctr}) &&
	( defined($self->{_transcript_ctr}))){
	return $self->{_transcript_ctr};
    } else {
	warn "transcript feature count was not defined\n";
	return undef;
    }
}

sub getCDSCount {

    my $self = shift;
    if (( exists $self->{_cds_ctr}) &&
	( defined($self->{_cds_ctr}))){
	return $self->{_cds_ctr};
    } else {
	warn "CDS feature count was not defined\n";
	return undef;
    }
}

sub getPolypeptideCount {

    my $self = shift;
    if (( exists $self->{_polypeptide_ctr}) &&
	( defined($self->{_polypeptide_ctr}))){
	return $self->{_polypeptide_ctr};
    } else {
	warn "polypeptide feature count was not defined\n";
	return undef;
    }
}

sub getExonCount {

    my $self = shift;
    if (( exists $self->{_exon_ctr}) &&
	( defined($self->{_exon_ctr}))){
	return $self->{_exon_ctr};
    } else {
	warn "exon feature count was not defined\n";
	return undef;
    }
}

sub getMiscellaneousFeatureCount {

    my $self = shift;
    if (( exists $self->{_misc_ctr}) &&
	( defined($self->{_misc_ctr}))){
	return $self->{_misc_ctr};
    } else {
	warn "miscellaneous feature count was not defined\n";
	return undef;
    }
}



1==1; ## End of module
