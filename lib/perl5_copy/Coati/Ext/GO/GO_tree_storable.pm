package Coati::Ext::GO::GO_tree_storable;

=head1 NAME

GO_tree_storable.pm - Represent the Gene Ontology Tree in a Tree Data Structure.

=head1 VERSION

This document refers to version 1.00 of GO_tree_storable.pm, released 4, 30, 2002.

=head1 SYNOPSIS

Short examples of code that illustrate the use of the class (if this file is a class).

=head1 DESCRIPTION

=head2 Overview

This module is designed to assemble the GO Tree from the database into a Tree Structure
using the DAG_Node module.  Furthermore, it also stores that complicated data structure 
into a binary flat file using the Storable module so that subsequent tree construction can
be very FAST


=head2 Class and object methods


=over 4

=cut

use strict;



use Tree::DAG_Node;
use Storable;
use base qw(Exporter);


our @EXPORT = qw(construct_go_tree_storable
             fetch_tree_storable
	    );


my ($go_term, $go_link, $go_syn);
my $counter = 0;
my $go_id_lookup = {};
my $node;

my  $_get_info_from_db = sub {
    my ($Manatee) = @_;

    #Dumping Entire GO Tables into memory
    #GLOBAL HASHES
    $go_term = $Manatee->all_GO_term();
    $go_link = $Manatee->all_GO_link();
    $go_syn  = $Manatee->all_GO_synonym();

    #ADJUSTING THE INTERNAL DATA STRUCTURE#
    $go_term = &_adjust_go_term($go_term);
    $go_link = &_adjust_go_link($go_link);
    $go_syn  = &_adjust_go_syn($go_syn);
   

};



=item construct_go_tree_storable($go_term, $go_tree_flat )

B<Description:> 

    Constructs the Entire GO Tree from the Database using DAG_Node.  At 
    the same time, it also dumps the tree data structure into a binary flat
    file using Storable for subsequence quicker retrieval. 

B<Parameters:> 

    This function takes 2 arguments:
    1.  The GO Term of the Root (for entire GO Tree, it is TI:0000001)
    2.  The complete path of the binary flat file to dump the data structure into (optional)

B<Returns:> 

    lookup table with key as GO Terms and values as list 
    of Node Objects with corresponding GO Term

=cut

sub construct_go_tree_storable  {
    my $Manatee     = shift;
    my $root        = shift;
    my $binary_flat = shift;

    #FETCHING DATA#
    $_get_info_from_db->($Manatee);
    
    ###MAKE THE ROOT NODE####
    my $mom = Tree::DAG_Node->new();
    $mom->name($counter);
    $mom = &_retrieve_node_info($mom, $root, $go_id_lookup);

    ###GROW THE TREE###
    &_extend_tree($mom);

    $node = $go_id_lookup->{$root}->[0];   #POINT $node to the top of the GO_TREE

    if(defined($binary_flat)) {
	system("rm -f go_tree.bin.*");
        ###DUMPING the ENTIRE TREE TO A BINARY FILE###
	my $tree_lookup = {'tree'=> $node, 'lookup'=>$go_id_lookup};
        store $tree_lookup,  "$binary_flat.$$";
	chmod(0777,"$binary_flat.$$");
        rename("$binary_flat.$$", $binary_flat);
    }
    return ($go_id_lookup, $node);
}


=item fetch_tree_storable()


B<Description:> 

    Returns (1.) the hash reference that points to all the NODES of the GO TREE.
    The key of the hash is GO Term, the values are an anonymous list of Nodes whose
    GO Term matches that of the key. (2.) Root node of the GO Tree

B<Parameters:> 

    Absolute Path of the location of the storable file containing GO Tree

B<Returns:> 

    Root of the GO_Tree, reference to a hash with keys as GO Terms, 
    values as list of nodes with that GO Term

=cut

sub fetch_tree_storable  {

    my $path = shift;

    if(-s $path) {
	my $hash_ref = retrieve($path);
	$node = $hash_ref->{'tree'};
	$go_id_lookup = $hash_ref->{'lookup'};
	return ($go_id_lookup, $node);
    }
    else {
        die "The File \"$path\" is NOT VALID\n";
    }

}




sub _retrieve_node_info {
#private methods that retrieves information about each GO Term.
#It takes 2 arguments: 1. Node object , 2. GO Term of the object
#Returns the Node object with all the information attached

    my $node = shift;
    my $go_id = shift;
    
    ###GRAB GO_ID BASIC ATTRIBUTES### "GO_TERM Table"
    $node->attributes->{'go_id'} = $go_id;
    $node->attributes->{'name'} = $go_term->{$go_id}->{'name'};
    $node->attributes->{'type'} = $go_term->{$go_id}->{'type'};
    $node->attributes->{'definition'} = $go_term->{$go_id}->{'definition'};
    $node->attributes->{'comment'} = $go_term->{$go_id}->{'comment'};
    $node->attributes->{'syn'} = [];
    $node->attributes->{'secondary_id'} = [];
    $node->attributes->{'genes'} = {};

    ###GRAB THE IMMEDIATE PARENT AND ITS TYPE
    my $tmp_mom_node = $node->mother;
    my $tmp_hash = {};
    #my $tmp_mom_go_id = $tmp_mom_node->attributes->{'go_id'};
    if(defined($tmp_mom_node)) {        #current node is not root
         my $tmp_mom_go_id = $tmp_mom_node->attributes->{'go_id'};
         $node->attributes->{'parent_link'} = [$tmp_mom_go_id, $go_link->{$go_id}->{'parents'}->{$tmp_mom_go_id}]; 
    }


    ###GRAB all of GO_ID's PARENTS### NO Secondary IDs
    while(my ($p_go_id, $ln_type) = each %{ $go_link->{$go_id}->{'parents'} }) {
        next if($ln_type eq "supercedes");
        $node->attributes->{'parents'}->{$p_go_id} = $ln_type;
    }  

    
    ###GRAB SYNONYMS###
    push( @{ $node->attributes->{'syn'} }, $go_syn->{$go_id}) if(exists($go_syn->{$go_id}));



    ###GRAB Secondary GO_IDs### link_type = 'supercedes'
    while(my ($c_go_id, $ln_type) = each %{ $go_link->{$go_id}->{'children'} }) {
	next if($ln_type ne "supercedes");
        push( @{ $node->attributes->{'secondary_id'} }, $c_go_id." : ".$go_term->{$c_go_id}->{'name'});
    }  

    ###Keep track of each node by GO_IDs###
    push (@{ $go_id_lookup->{ $node->attributes->{'go_id'} } }, $node);
    return $node;

}


sub _extend_tree {
    my $adult = shift;
    
    my $parent_id = $adult->attributes->{'go_id'};
    while(my($child_id, $ln_type) = each %{ $go_link->{$parent_id}->{'children'} }) {
	if($ln_type ne "supercedes") {
	    $adult = &_connect_daughter_to_mom($adult, $child_id);
	    &_extend_tree($adult);
	    $adult = $adult->mother;
	}
    }
}


sub _connect_daughter_to_mom {
    my $mom = shift;            #NODE OBJECT
    my $kid = shift;            #GO_ID of a child
    my $daughter;

    $counter++;
    $daughter = $mom->new_daughter;
    $daughter->name($counter);
    
    $daughter = &_retrieve_node_info($daughter, $kid);    
    $mom = $daughter;

    return $mom;
}


sub _adjust_go_term {
#private methods
    my $old_ds = shift;                  #old_ds = 'old data structure'

    my %new_ds;

    foreach my $href (@$old_ds) {
        my $go_id = $href->{'go_id'};
        my $name  = $href->{'name'};
        my $type  = $href->{'type'};
        my $defn  = $href->{'definition'};
        my $com   = $href->{'comment'};
        $new_ds{$go_id}->{'name'} = $name;
        $new_ds{$go_id}->{'type'} = $type;
        $new_ds{$go_id}->{'definition'} = $defn;
        $new_ds{$go_id}->{'comment'} = $com;
    }

    return (\%new_ds);

}    

sub _adjust_go_link {

    my $old_ds = shift;                  

    my %new_ds;
    foreach my $href (@$old_ds) {  
        my $parent_id = $href->{'parent_id'};
        my $child_id  = $href->{'child_id'};
        my $link_type = $href->{'link_type'};
        $new_ds{$child_id}->{'parents'}->{$parent_id} = $link_type;
        $new_ds{$parent_id}->{'children'}->{$child_id} = $link_type;
    }
    
    return (\%new_ds);

}


sub _adjust_go_syn {

    my $old_ds = shift;

    my %new_ds;
    foreach my $href (@$old_ds) {
        my $go_id = $href->{'go_id'};
        my $syn   = $href->{'synonym'};

	if(!$new_ds{$go_id}) {
	    $new_ds{$go_id} = $syn;
	}
	else {
	    $new_ds{$go_id} .= "\t" . $syn;
	}
    }
   
    return (\%new_ds);

}

1;        # For the "use" or "require" to succeed.








__END__

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

This module require DAG_Node, Storable

=head1 AUTHOR(S)

 The Institute for Genomic Research
 9712 Medical Center Drive
 Rockville, MD 20850

=head1 COPYRIGHT

Copyright (c) 2002, The Institute for Genomic Research. All Rights Reserved.












