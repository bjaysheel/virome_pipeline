package TreeBuilder;
# $Id: TreeBuilder.pm,v 1.5 2006-11-06 18:04:54 nzafar Exp $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME


=head1 VERSION


=head1 SYNOPSIS

Short examples of code that illustrate the use of the class (if this file is a class).

=head1 DESCRIPTION

=head2 Overview

Overview of the purpose of the file.

=head2 Constructor and initialization.

if applicable, otherwise delete this and parent head2 line.

=head2 Class and object methods

if applicable, otherwise delete this and parent head2 line.

=over 4

=cut

use strict;
#######################
# Tree object functions
#######################
sub new { 
    my $classname = shift;
    my $self = {};
    bless($self,$classname);
    $self->_init(@_);
    return $self;
}
sub _init {
    my $self = shift;
    if(@_){
	my %extra = @_;
	@$self{keys %extra} = values %extra;
    }
}

=item "buildTreeFromAlignment" 

 Description: Builds a NH tree from a multiple alignment
 Precondition: 
    The following environment variables must be available: $ENV{CLUSTALW}
    The multiple alignment input is in MSF format and correctly formatted.
 Postcondition: 
    A NH format tree is returned
    A XML format supported by TreeViewer is returned

=cut

sub buildTreeFromAlignment {
    my $self = shift;
    my $alignment = shift;

    my $tmpalignfile = "/tmp/tmp$$";
    my $treefile = "/tmp/tmp$$.ph";

    open FILE,"+>$tmpalignfile" or die "Can't open temporary file $tmpalignfile to store alignment";
    print FILE $abuff;
    close FILE;
    print `$ENV{CLUSTALW} -INFILE=$tmpalignfile -tree -OUTPUTTREE=phylip`;
    unlink ($tmpalignfile);

    my $treebuff;
    open TREEFILE,"/tmp/tmp$$.ph" or die "Can't open $ENV{CLUSTALW} output file $treefile to store tree";
    while(my $line=<STDIN>){
	$treebuf .= $line;
    }
    close TREEFILE;
    return $treebuff;
}

=item "buildXMLFromAlignment" 

 Description: Builds a NH tree and XML markup from a multiple alignment 
 Precondition: 
    The multiple alignment input is in MSF format and correctly formatted with valid gene_ids on the header line
    The input is a valid Coati object
 Postcondition: 
    A NH is output

=cut

sub buildXMLFromAlignment {
    my $self = shift;
    my $coatiobj = shift;
    my $alignment = shift;
    my $attrs = shift;

    my $feats = {};

    foreach my $tag (split(/\n/,$abuff)){
	if($tag =~ /^>/){
	    my($feat) = ($tag=~/>(.*)/);
	    my($feat_name) = ($tag =~ /(\w+\.\w+)/);
	    $feats->{$feat}->{'feat_name'} = $feat_name;
	}
    }

    my($xmlref) = new Coati::Ext::XML::XMLPrefs();
    
    foreach my $f (keys %$feats){
	my $query = $infoquery;
	my $ident_info = $coati_obj->feat_name_to_ident($feats->{$f}->{'feat_name'});
	my $xmlref = new Coati::Ext::XML::XMLPrefs();
	$xmlref->addValue($f,$ident_info->{'feat_name'});
	$xmlref->addValue($f,$ident_info->{'com_name'});
    }
    
    &addAttrsToXML($xmlref,$attrs);

    return $xmlref->getXML();
}

=item "addAttrsToXML" 

  Description: Add attributes to a Tree XML file

  Arguments: 
    $xmlref - reference to Coati::Ext::XML::XMLPrefs object
    $attrs - nested hash in form

{'feature1_id'=>{'attr1'=>'value1',
	         'attr2'=>'value2'},
 'feature2_id'=>{'attr1'=>'value1'
		 'attr2'=>'value2'}
}

  Returns:
    $xmlref - reference to Coati::Ext::XML::XMLPrefs object

=cut

sub addAttrsToXML{
    my $xmlref = shift;
    my $attrs = shift;
    foreach my $f (keys %$attrs){
	foreach my $at (keys %{$attrs->{$f}}){
	    $xmlref->addValue($f,$attrs->{$f}->{$at},$at);
	}
    }
}



1;

=back

=head1 ENVIRONMENT

List of environment variables and other O/S related information
on which this file relies.

=head1 DIAGNOSTICS

=over 4

=item "Error message that may appear."

Explanation of error message.

=item "Another message that may appear."

Explanation of another error message.

=back

=head1 BUGS

Description of known bugs (and any workarounds). Usually also includes an
invitation to send the author bug reports.

=head1 SEE ALSO

List of any files or other Perl modules needed by the file or class and a 
brief description why.

=head1 AUTHOR(S)

The Institute for Genomic Research
9712 Medical Center Drive
Rockville, MD 20850

=head1 COPYRIGHT
