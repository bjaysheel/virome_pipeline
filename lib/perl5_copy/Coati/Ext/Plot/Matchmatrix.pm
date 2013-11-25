package Coati::Ext::Plot::Matchmatrix;

# $Id: Matchmatrix.pm,v 1.6 2004-05-13 18:01:51 crabtree Exp $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME

matchmatrix 

=head1 VERSION

This document refers to version 1.0 of matchmatrix, released MMMM, DD, YYYY.

=head1 SYNOPSIS

my(@col1) = ("a1","b1","c1","e1","f1");
my(@col2) = ("b2","c2","d2","e2","f2");
my(@col3) = ("a3","b3","c3","d3","f3");

my($matches) = [{'a1'=>'a3'},
		{'b1'=>'b3'},
		{'b1'=>'b2'},
		{'c1'=>'c2'},
		{'c1'=>'c3'},
		{'e1'=>'e2'},
		{'f1'=>'f3'},
		{'f1'=>'f2'},
		{'c2'=>'c3'},
		{'d2'=>'d3'},
		{'f2'=>'f3'}
		];

my($mult) = new Coati::Ext::Plot::Matchmatrix();
$mult->addOrderedList(\@col1,0);
$mult->addOrderedList(\@col2,1);
$mult->addOrderedList(\@col3,2);
$mult->addMatches($matches);
my($output) = $mult->getMatrix();


=head1 DESCRIPTION

=head2 Overview

Generates a matrix of matches between multiple ordered lists based on
pairwise match information.  Useful for building a table of
alignments/matches between multiple ordered sets. 

The inputs are sets of ordered list and matches between elements in
the lists..  Each ordered list comprises a column in the match matrix.
Matches between columns comprise the rows and "gaps" are inserted
where there are no matches.  The requirements are that all the element
names are unique and that elements match no more than one other
element in another column.  Eg. Each elements in column 1 can match no
more than one element in column 2 and so forth.

The algorithm makes a best effort preserve the order sets in the
output although only the first column, the reference column, is
guaranteed to be ordered.  The composition of the matches will
determine the degree of ordering amongst all the other columns.

The output is a nested array reference, which allows traversal of the
matrix by column and row.

The matrix is most useful for inserting/displaying gaps in ordered
sets with a high frequency of matches in conserved order.  The
algorithm works as follows:

1) Data of column 0 is added to the matrix in order.  This is the
 reference column.

2) Matches to reference elements are filled for all other columns.

3) Each column is traversed and non matching elements inserted into
   the matrix in order following the closest matching element from the
   column.

=head2 Constructor and initialization.

my($mult) = new Coati::Ext::Plot::Matchmatrix();

No input options are currently supported.

=head2 Class and object methods

$mult->addOrderedList(arrayref,int);

$mult->addMatches(hashref);

arrayref = $mult->getMatrix();

=over 4

=cut

use strict;
use GD;

my $VERSION = .01;
my @ISA = qw(Exporter);
my @EXPORT = qw();

#######################
# object functions
#######################
sub new {
    my $classname = shift;
    my $self = {};
    bless($self,$classname); 
    $self->_init(@_);
    $self->{'COLS'} = {}; # key:col pos -> ordered array
    $self->{'POS'} = {}; # key:feat -> col pos
    $self->{'MARKED'} = {}; #key:feat -> finished
    $self->{'OUTPUT'} = {}; #key:output position -> array ref
    $self->{'MATCHES'} = {};
    $self->{'MATCHLOOKUP'} = {};
    $self->{'COORDLOOKUP'} = {};
    $self->{'MAXLENGTH'} = 0;
    $self->{'DIRTY'} =1;
    $self->{'GAPINCREMENT'} = 0.000001; #leaves 1,000000 available "gap" columns between matches
    return $self;
}
sub _init {
    my $self = shift;
    if(@_){
        my %extra = @_;
        @$self{keys %extra} = values %extra;
    }
}

####################
# Public functions 
####################
#INPUT
=item addOrderedList()

B<Description:>  Add an ordered list.  The list must have unique 

B<Parameters:>

B<Returns:>

=cut

sub addOrderedList(){
    my($self,$aref,$num) = @_;
    #Store ordered list in $self->{'COLS'}->{column number}
    $self->{'COLS'}->{$num} = $aref;
    #Mark all feats with their column number in $self->{'POS'}->{feature name}
    foreach my $feat (@$aref){
	$self->{'POS'}->{$feat} = $num;
    }
    $self->{'DIRTY'}=1;
}

=item addMatches()

B<Description:>  Add a set of matches.

B<Parameters:>

B<Returns:>

=cut

sub addMatches(){
    my($self,$mref,$ambigref) = @_;
    $self->{'MATCHES'} = $mref;
    foreach my $href (@$mref){
	foreach my $f (keys %$href){ 
	    # check and preserve only one match per feat to a given column
	    my($currmatches)  = $self->{'MATCHLOOKUP'}->{$f};
	    foreach my $cmatch (keys %$currmatches){
		if($self->{'POS'}->{$cmatch} eq $self->{'POS'}->{$href->{$f}}){
		    $self->{'MATCHLOOKUP'}->{$f}->{$cmatch} = 0;
		    # record that $f has ambiguous matches
		    $ambigref->{$f} = 1 if (defined($ambigref) && ($cmatch ne $href->{$f}));
		}
	    }
	    #Mark match between feature=>feature
	    $self->{'MATCHLOOKUP'}->{$f}->{$href->{$f}} =1;
	}
    }
    $self->{'DIRTY'}=1;
}
#OUTPUT
sub printTab(){
    my($self,$gapmark) = @_;
    $gapmark = "---" if($gapmark eq "");
    my($output) = $self->getMatrix();
    foreach my $row (@$output){
	foreach my $col (@$row){
	    if($col ne ""){
		print $col,"\t";
	    }
	    else{
		print $gapmark,"\t";
	    }
	}
	print "\n";
    }
}
sub getMatrix(){
    my($self) = @_;
    $self->doOrdering() if($self->{'DIRTY'}==1);
    my($colref) = $self->{'COLS'};
    my($oref) = $self->{'OUTPUT'};
    my(@oref);
    foreach my $pos (sort {$a<=>$b} (keys %$oref)){
	my($cref) = [];
	my($mref) = $oref->{$pos};
	foreach my $col (keys %$colref){
	    push @$cref,"";
	}
	foreach my $feat (sort {$self->{'POS'}->{$a} <=> $self->{'POS'}->{$b}} (@$mref)){
	    my($lfeat) = length($feat);
	    $self->{'MAXLENGTH'} = $lfeat if($lfeat > $self->{'MAXLENGTH'});
	    @$cref[$self->{'POS'}->{$feat}] = $feat;
	}
	push @oref,$cref;
    }
    return \@oref;
}
sub getImageCoords(){
    my($self) = @_;
    return $self->{'COORDLOOKUP'};
}
sub getImage(){
    my($self,$width,$height,$opts,$ambigref) = @_;
    $self->doOrdering() if($self->{'DIRTY'}==1);
    
    my($FONTSIZE) = $self->{'MAXLENGTH'} * gdSmallFont->width;
    my($output) = $self->getMatrix(); 
    
    my($colref) = $self->{'COLS'};
    my($numcols) = scalar(keys %$colref);
    my($xstep) = $width/$numcols;
    print "COLS: $numcols YSTEP: $xstep\n" if($self->{'DEBUG'});;
    
    my($numrows) = scalar(@$output);
    my($ystep) = $height/$numrows; 
    print "ROWS: $numrows XSTEP: $ystep\n" if($self->{'DEBUG'});;
    my($xpos) = $FONTSIZE; 

    my $image;
    if($opts->{'VERT'}){
	$image = new GD::Image($height+$FONTSIZE,$width+$FONTSIZE+2);
    }
    else{
	$image = new GD::Image($width+$FONTSIZE,$height+$FONTSIZE+2);
    }
    my $WHITE = $image->colorAllocate(255,255,255);
    my $BLACK = $image->colorAllocate(0,0,0);
    my $GREEN = $image->colorAllocate(0,200,0);
    my $RED = $image->colorAllocate(255,0,0);
    my $GREY = $image->colorAllocate(155,155,155);
    my $BLUEISH = $image->colorAllocate(153,200,229);

    if(!$opts->{'NOXLABELS'}){
	foreach my $col (sort {$a<=>$b} (keys %$colref)){
	    if($opts->{'VERT'}){
		$image->string(gdSmallFont,0,$xpos,$col,$BLACK) 
		}
	    else{
		$image->stringUp(gdSmallFont,$xpos,$FONTSIZE,$col,$BLACK);
	    }
	    $xpos += $xstep;
	}
    }
    my($ypos) = $FONTSIZE+2;
    
    foreach my $row (@$output){
	my($xpos)=$FONTSIZE;
	my($colcount)=0;
	my($nummatches)=0;
	foreach my $col (@$row){
	    if($col ne ""){
		$nummatches++;
	    }
	}
	foreach my $col (@$row){
	    my($color)=$GREY;

	    if(defined($ambigref) && ($ambigref->{$col})) {
		$color = $BLUEISH;
	    } elsif($nummatches == $numcols){
		$color = $GREEN;
	    }
	    elsif($nummatches > 1){
		$color = $RED;
	    }
	
	    if($col ne ""){ 
		$image->string(gdSmallFont,0,$ypos,$col,$BLACK) if($colcount ==0 && !$opts->{'NOXLABELS'});
		if($opts->{'VERT'}){
		    $image->filledRectangle($ypos,$xpos,$ypos+$ystep,$xpos+$xstep,$color);
		    $self->{'COORDLOOKUP'}->{$col} = [$ypos,$xpos,$ypos+$ystep,$xpos+$xstep];
		}
		else{
		   $image->filledRectangle($xpos,$ypos,$xpos+$xstep,$ypos+$ystep,$color); 
		   $self->{'COORDLOOKUP'}->{$col} = [$xpos,$ypos,$xpos+$xstep,$ypos+$ystep];
		} 
	    }
	    else{
		#$image->filledRectangle($xpos,$ypos,$xpos+$xstep,$ypos+$ystep,$GREY);
	    }
	    $image->line($xpos,$FONTSIZE+2,$xpos,$height+$FONTSIZE+2,$BLACK) if($opts->{'LINES'} ==1);
	    $xpos += $xstep;
	    $colcount++;
	}	
	$image->line($FONTSIZE,$ypos,$width+$FONTSIZE,$ypos,$BLACK) if($opts->{'LINES'} ==1);;
	$ypos += $ystep;
    }
    return $image->png;
}

	
###################
#Private functions
###################
sub doOrdering{
    my($self) = @_;
    my($colref) = $self->{'COLS'};
    #Sort columns
    my(@scols) = sort {$a<=>$b} (keys %$colref);
    #Mark reference as first column
    my($reffeats) = $colref->{$scols[0]};
    my($outref) = $self->{'OUTPUT'};
    my($markref) = $self->{'MARKED'};
    my($lastloc)=1;
    print  "Storing ".@$reffeats." feats for ref col with matches to $scols[0] to $scols[$#scols]\n" if($self->{'DEBUG'});
    #
    # Store ref feats
    foreach my $feat (@$reffeats){
	$self->storeMatches($feat,$lastloc,$scols[0],$#scols);
	$lastloc++;
    }

    print  "DONE\n" if($self->{'DEBUG'});
    #
    # Store matches for each column
    # Keep track of current row using lastloc
    my($lastloc)=0;
    for(my $col=1;$col<=$#scols;$col++){
	my($oref) = $colref->{$scols[$col]};
	print  "Storing ".@$oref." feats for col $col to $scols[$#scols]\n" if($self->{'DEBUG'});
	foreach my $feat (@$oref){
	    my($markloc) = $markref->{$feat};
	    if($markloc>0){
		$lastloc = $markloc;
	    }
	    else{
		while(exists $outref->{$lastloc}){
		    $lastloc += $self->{'GAPINCREMENT'};
		}
		$self->storeMatches($feat,$lastloc,$scols[$col],$scols[$#scols]);
	    }
	}
    }
    $self->{'DIRTY'}=0;
}
sub findMatch(){
    my($href,$feat,$acol,$bcol,$posref) = @_;
    foreach my $elt (keys %$href){
	if(($elt eq $feat) 
	   && ($posref->{$href->{$elt}} > $acol) 
	   && ($posref->{$href->{$elt}} <= $bcol)){
	    return $href->{$elt};
	    }
    }
}

=item getAllMatches()

B<Description:> Return all matches for element in columns from start-->stop

B<Parameters:>  element name, start column, stop column

B<Returns:> none

=cut

sub getAllMatches(){
    my($self,$feat,$acol,$bcol) = @_;
    my($mref) = $self->{'MATCHES'};
    my($href) = $self->{'MATCHLOOKUP'}->{$feat};
    my(@matches); 
    foreach my $match (sort {$self->{'POS'}->{$a} <=> $self->{'POS'}->{$b}} (keys %$href)){ 
	if($href->{$match} > 0){
	    if($self->{'POS'}->{$match} > $acol && $self->{'POS'}->{$match}<=$bcol){
		push @matches,$match;
	    }
	}
    }
    return \@matches;
}

=item storeMatches()

B<Description:> Store all matches between start column and stop column
for a given element.  This sets the row number for all the matching
elements.

B<Parameters:>  element name, row number, start column, stop column

B<Returns:> none

=cut

sub storeMatches(){
    my($self,$feat,$pos,$startcol,$stopcol) = @_;
    #get all matches for columns $startcol-$stopcol
    my $allmatches = $self->getAllMatches($feat,$startcol,$stopcol);
    print "Num matches for $feat :".scalar(@$allmatches)."\n" if($self->{'DEBUG'}>1);
    unshift @$allmatches,$feat;
    #mark matches as finished and save position
    foreach my $match (sort {$self->{'POS'}->{$a} <=> $self->{'POS'}->{$b}} (@$allmatches)){
	print "$feat::$match $self->{'POS'}->{$match}\n" if($self->{'DEBUG'}>1);
	if($self->{'POS'}->{$match} == $stopcol || $self->{'POS'}->{$match} eq $self->{'POS'}->{$feat}){
	    $self->{'MARKED'}->{$match} = $pos;
	}
	else{
	    # check if row is reciprocal
	    my($checkmatches) = $self->getAllMatches($match,$self->{'POS'}->{$match},$stopcol);
	    if(scalar(@$checkmatches) ne (scalar(@$allmatches) - $self->{'POS'}->{$match} - 1)){
		print  "#WARNING: Matches for $feat: $match not in agreement\n" if($self->{'DEBUG'});
	    }
	    $self->{'MARKED'}->{$match} = $pos;
	}
    } 
    #save output for position
    $self->{'OUTPUT'}->{$pos} = $allmatches;
}

1;
