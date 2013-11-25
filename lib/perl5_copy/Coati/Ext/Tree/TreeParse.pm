package TreeParse;
# $Id: TreeParse.pm,v 1.5 2006-12-07 16:41:07 angiuoli Exp $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME

ORF_infopage.dbi - One line summary of purpose of class (or file).

=head1 VERSION

This document refers to version 1.0 of ORF_infopage.dbi, released MMMM, DD, YYYY.

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

use Tree::DAG_Node;
use POSIX;
use Data::Dumper;

#######################
# Tree object functions
#######################
sub new { 
    my $classname = shift;
    my $self = {};
    bless($self,$classname);
    $self->{STATUS} = 0;
    $self->{NODE_ATTRIBUTES} = {};
    $self->{PARSENAMES} = 0; #not sure wtf this does anymore
    $self->{NODE_PREFIX} = "N_";
    $self->{LEAF_PREFIX} = "L_";
    $self->{NAME_STATUS} = 0;
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
=item "parseNHTree" 

 Description: Converts a NH format tree to a Tree::DAG_Node
 Precondition: 
    The input tree is a string representation of a valid NH tree. 
 Postcondition: 
    The output tree is the status of the parse

=cut
sub parseNHTree { 
    my $self = shift;
    my $treedata = shift;
    my $debug = shift;
    # massage input to make DAG_Node happy
    $self->{PARSE_STATUS} = &convertNHToChomsky(\$treedata, $self->{NODE_ATTRIBUTES},$self->{PARSENAMES},$debug); 
    $self->{ROOT} = Tree::DAG_Node->lol_to_tree(eval($treedata)); 
    $self->addAttributes($self->{NODE_ATTRIBUTES});
    if(!ref($self->{ROOT}) || $self->{ROOT}->depth_under <=0){
	$self->{PARSE_STATUS}--;
    }
    return $self->{PARSE_STATUS};
}

sub addAttributes{
    my($self,$attrs) = @_;
    $self->{ROOT}->walk_down(
			     {
				 'attributes' => $attrs,
				 'callback' => \&addAttributesToTree
				 }
			     );
}

sub addAttributesToTree{
    my($node,$attrs) = @_;
    my($nodeattrs) = $attrs->{'attributes'}->{$node->name};
    foreach my $key (keys %$nodeattrs){
	$node->attributes->{$key} = $nodeattrs->{$key};
    }
    return 1;
}

sub getTree { 
    my($self) = @_;
    return ($self->{PARSE_STATUS}>0) ? undef : $self->{ROOT};
}

=item "dumpTreeText" 

 Description: Converts a NH format tree to a Tree::DAG_Node
 Precondition: 
    A tree has been parsed using TreeParse::parseNHTree.
 Postcondition: 
    The output is a ascii representation of a tree.

=cut

sub dumpTreeText {
    my $self = shift;
    return map "$_\n", @{$self->{ROOT}->draw_ascii_tree};
}

=item "dumpTreeDistances" 

 Description: Dumps the distances associated with nodes in a parsed tree 
 Precondition: 
    A tree has been parsed using TreeParse::parseNHTree.
 Postcondition: 
    The output is tab delimited list of node type,node,distance,[label].

=cut

sub dumpTreeAttributes{
    my $self = shift;
    $self->{ROOT}->walk_down(
			     {
				'callback' => sub{
				    my $node = shift;
				    print "NAME: ".$node->name."\n";
				    print Dumper($node->attributes),"\n";
				}
			    }
			     );
}
##########
# Tree file parsers
##########
#
=item "convertNHToChomsky" 

 Description: Converts a valid New Hampshire format tree to Chomsky format. Chomsky format is read by Tree::DAG_Node.
    See http://search.cpan.org/doc/SBURKE/Tree-DAG_Node-1.04/DAG_Node.pm for more information on Chomsky format.
 Precondition: 
    The input tree is a string representation of a valid NH tree. 
    Any names containing non-alphanumeric characters are quoted by \' or \" 
 Postcondition: The output tree is an accurate Chomsky representation of the input tree.

=cut

sub convertNHToChomsky{
    # Preconditions
    # All names start with alphanumeric
    #
    # List of conversions:
    #-------------------------
    # New Hampshire format (conversion used)
    #-------------------------
    # preparses quoted names to remove bad characters , and :
    # defines un-named internal nodes and explicitly names
    # distance attribute stored following node def (parsed out and stored in $tattrs)
    # () converted to []
    my($ctree,$tattrs,$debug)=@_;
    print "TREEPARSE::NH=$$ctree\n" if($debug);
    my($count)=0;
    my($maxdistance)=0;
    my($quotes)=0;
    my($oldname);
    $$ctree =~ s/;\z//;
    $$ctree=~s/:-*\d\z//; 
    #
    # If quotes are used make sure characters are valid
    my $status = &cleanNames($ctree,$debug);
    #Replace distances
    while($$ctree =~ /:-*\d+.\d+/){
        my($name)="";
        my($dist)="";
	#names must not contain ,:'" at this point
        #capture names and distances and convert
	($name,$dist) = ($$ctree =~ /(\w[^,:]+):(-*\d+.\d+)/);
	print "TREEPARSE::preparse name=$name dist=$dist\n" if($debug);
	$oldname=$name; 
	my($oldnamem) = quotemeta($oldname);
	my($namekey);
	if($name=~/\)\z/){
	    $count++;
	    $name = "N_$count"; 
	    $$ctree =~ s/\)/,'$name']/;
	    $namekey = $name;
        }
        else{
	    $oldname = $name;
	    $name = "L_$count";
	    $count++;
	    $$ctree =~ s/$oldnamem/'$name'/;
	    $namekey = $oldnamem;
        }
        $tattrs->{$name}->{'relative_distance'} = $dist;
        $tattrs->{$name}->{'nh_label'} = $namekey;
        $tattrs->{$name}->{'_key'} = $name;
        $$ctree =~ s/:-*\d+.\d+//;
        print "TREEPARSE::Name=$name NHParseEquiv=$tattrs->{$name}->{'_key'} Dist=$dist $tattrs->{$name}->{'relative_distance'}\n" if($debug);
        print "TREEPARSE::$$ctree\n" if($debug>1);
    }
    #change the ( for all internal nodes to [
    $$ctree =~ s/\(/[/g; 
    #the last ) and optional distance for the root is converted to ] and distance is ignored 
    $$ctree =~ s/\):*\d*\.*\d*\z/,'N_$count']/;
    print "TREEPARSE::Chomsky=$$ctree\n" if($debug);
    return $status;
}
##}    
##"

sub getIdFromName{
#
    my($name) = @_;
    $name =~ s/\/\d+-\d+//g;
    $name =~ s/\w+\|//g;
    return $name;
}
=item "cleanNames" 

 Description: removes rogue characters [,:\'\"] from names that will screw up parsing
 Precondition: 
    The input tree is a string representation of a valid NH tree. 
    Any names containing [,:\'\"] are quoted by \' or \" 
 Postcondition: The input tree does not contain names with [,:\'\"]

=cut

sub cleanNames{
    my($ctree,$debug) = @_;
    my($totalstatus)=0;
    if($$ctree =~ /\(\'/){
       my $badandy;
       my $goodandy;
       while(($badandy) = ($$ctree =~ /([\'\"][^\'\"]+[\'\"])/gi)){
	   $goodandy = $badandy;
	   $goodandy =~ s/,//g;
	   $goodandy =~ s/://g;
	   $goodandy =~ s/\'//g;
	   $goodandy =~ s/\"//g;
	   $badandy = quotemeta($badandy);
	   my($status) = ($$ctree =~ s/$badandy/$goodandy/); 
	   print "TREEPARSE: Cleaning $badandy with $goodandy STATUS:$status\n" if($debug >2);
	   $totalstatus -= ($status == 1 ? 0 : 1);
       }
   }
    return $totalstatus;
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
