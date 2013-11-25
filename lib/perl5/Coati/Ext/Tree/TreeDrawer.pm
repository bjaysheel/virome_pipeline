package TreeDrawer;

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION $purple $red $green $blue $black $white $yellow @colorarray %htmlcolors);
use Exporter;
use GD;
use XML::Simple;
use Data::Dumper;

use Tree::DAG_Node;
use POSIX;

use TreeParse;

$VERSION = .01;
@ISA = qw(Exporter DBI CGI);
@EXPORT= qw(&parseTree &arrangeTree &graphTree &setXMLPrefs &label &dumpTree &getAttributes &setUniqueColors &setTree &getTree);

local $red;
local $green;
local $blue;
local $black;
local $purple;
local $white;
local $yellow;
my(@colorarray);
push @colorarray,"255,0,0";
push @colorarray,"100,100,120";
push @colorarray,"70,130,180";
push @colorarray,"255,0,255";
push @colorarray,"178,34,78";
push @colorarray,"0,255,137";
push @colorarray,"139,28,0";
push @colorarray,"138,43,236";
push @colorarray,"238,18,137";
push @colorarray,"139,102,139";
push @colorarray,"0,255,0";
push @colorarray,"0,255,255";
push @colorarray,"255,255,0";
push @colorarray,"255,255,255";

my(%htmlcolors);

#######################
# Tree object functions
#######################
sub new { 
    my $classname = shift;
    my $self = {};
    bless($self,$classname);
    $self->{LEGENDHEIGHT} = 200;
    $self->{LEGENDWIDTH} = 400;
    $self->{LABELNAME} = "default";
    $self->{LABELSPACING} = 100;
    $self->{NODEshared/Coati/Ext/Tree/TreeDrawer.pm_SIZE} = 2;
    $self->{LEAF_SIZE} = 4;
    $self->{XBORDER} = 10;
    $self->{YBORDER} = 10; 
    $self->{WIDTH} = 500;
    $self->{HEIGHT} = 500;
    $self->{MAPFUNC} = \&addToImageMap;
    $self->_init(@_);
    return $self;
}
sub _init {
    my $self = shift;
    if(@_){
	my %extra = @_;
	@$self{keys %extra} = values %extra;
	$self->{NODE_ATTRIBUTES}->{'init'} = 1;
	$self->{_COLORCOUNT}=0;
    }
}
sub getTree {
    my $self = shift;
    return $self->{ROOT};
}
sub setTree {
    my $self = shift;
    $self->{ROOT} = shift;
}

sub arrangeTree { 
    my $self = shift;
    my ($subnode,$rerootnode) = @_;
    #Trim to subtree if necessary
    $self->{ROOT} = &getSubTree($self->{ROOT},$subnode) if($subnode && $subnode ne "");
    #Reroot if necessary
    $self->{ROOT} = &reRootByName($self->{ROOT},$rerootnode,$self->{DEBUG}) if($rerootnode && $rerootnode ne "");
    #Set cumulative distance from root for all nodes
    ($self->{MAXNODE},$self->{MAXSINGLENODE}) = &findAndSetDistance($self->{ROOT});
}

sub graphTree {
    my($self,$type,$width,$height) = @_;
    $type = lc($type);
    $self->{WIDTH} = $width;
    $self->{HEIGHT} = $height;
    my($image) = $self->initImage();
    if($type eq "cladogram"){
	$self->{AREATAGS} = $self->graphRooted($image,$self->{ROOT},0);
    }
    if($type eq "something"){
	$self->{AREATAGS} = $self->graphRooted($image,$self->{ROOT},1);
    }
    return ($image,$self->{AREATAGS});
}

sub getLegend {
    my($self) = shift;
    return $self->{LEGENDIMG};
}
sub dumpTree { 
    my($self) = shift;
    return $self->{ROOT}->tree_to_lol_notation;
}
sub getLeaves {
    my($self) = shift;
    my(@leaves);
    my(@l) = $self->{ROOT}->leaves_under;
    foreach my $leaf (@l){
	push (@leaves,$self->{NODE_ATTRIBUTES}->{$leaf->name}->{'_key'});
    }
    return \@leaves;
}

####################
# Drawing algorithms
####################
sub graphRooted{
    my($self,$image,$newroot,$placement) = @_;
    $self->setXLocations($newroot,$placement);
    $self->setYLocations($newroot);

    my($maxdistance) = $self->{MAXNODE}->attributes->{'absolute_distance'};
    my($multiple);
    if($placement){
	$maxdistance=1 if(!$maxdistance);
	$multiple = ($self->{WIDTH} 
		     - (2 * $self->{XBORDER})
		     - $self->{LABELSPACING}
		     ) / $maxdistance;
    }
    else{
	$multiple = ($self->{WIDTH}
		     - (2 * $self->{XBORDER})
		     - $self->{LABELSPACING}
		     ) / (scalar($newroot->depth_under)+1);
    }
    print STDERR "$multiple\n" if($self->{'DEBUG'} == 1);
    return $self->doDrawEachNode($image,$newroot,$multiple,$placement);
}

sub doDrawEachNode(){
    my($self,$image,$newroot,$multiple,$placement) = @_;
    my($areatags);     
#
# Now ready to create image
# Do breadth first search to set x locations for all nodes
# while drawing nodes.  This is also done from the leaves up, where
# each parent is centered between is widest children.
#          -----------child
#          |
#  parent--| 
#          |
#          -----------child
# 
    &doBreadthFirstSearch($newroot,
			  sub{
			      my($cnode) = @_[0];
			      my($currX);
			      if($placement){
				  my($dist);
				  $dist = $cnode->attributes->{'absolute_distance'};
				  $currX = &calculateX($multiple,$dist);
			      }
			      else{
				  $currX = &calculateX($multiple,scalar($newroot->depth_under) - scalar($cnode->depth_under));
			      }
			      my($currY) = $cnode->attributes->{'_yloc'};
			      $cnode->attributes->{'_xloc'} = $currX;
			      #$currX += 6 if(!$cnode->daughters);
			      my($currLabel)= &getLabelFromParam($cnode,$self->{LABELNAME});
			      my($nodecolor) = &getNodeColorFromParam($cnode);
			      my($edgecolor) = &getEdgeColorFromParam($cnode);
			      my($labelcolor) = &getLabelColorFromParam($cnode,$self->{LABELNAME});
			      $nodecolor=$image->colorResolve(eval($nodecolor));
			      $edgecolor=$image->colorResolve(eval($edgecolor));
			      $labelcolor=$image->colorResolve(eval($labelcolor));
			      my($nx1,$ny1,$nx2,$ny2) = $self->transform($currX,$currY,$currX,$currY);
			      my($x1,$y1,$x2,$y2) = &drawNode($image,
							      $nx1,
							      $ny1,
							      $nodecolor,
							      $cnode->daughters ? $self->{NODE_SIZE} : $self->{LEAF_SIZE}
							      );
			      my($lx1,$ly1,$lx2,$ly2) = $self->transform($currX,$currY,$currX,$currY);
			      
			      my($xx1,$yy1,$xx2,$yy2) = &drawLabel($image,$lx1,$ly1,$currLabel,$labelcolor,$self->{ROTATION})
				  if($self->{LABELNAME} ne "" && !$cnode->daughters);
			      
			      $self->{MAPFUNC}(\$areatags,$cnode,$x1,$y1,$x2,$y2);
			      			      
			      my($cx1,$cy1,$cx2,$cy2) = $self->transform(
									 $cnode->mother->attributes->{'_xloc'},
									 $cnode->mother->attributes->{'_yloc'},
									 $currX,
									 $currY
									 ) if($cnode->mother);
			      &drawConnectToMother($image,
						   $cx1,
						   $cy1,
						   $cx2,
						   $cy2,
						   $edgecolor
						   ) if($cnode->mother);
			      
				#		   $self->{LABEL} > 1 ? $cnode->{attributes}->{'absolute_distance'} :"" 
			  }
			  );
    return $areatags;
}

sub setXLocations(){
    my($self,$newroot,$placement) = @_;
#
# Set y locations for leaf nodes
# Here, all leaf nodes are spaced evenly
    my(@leaves) = $newroot->leaves_under;
    my($currY)=$self->{YBORDER};
    my($currX)=$self->{WIDTH}-$self->{XBORDER}-$self->{LABELSPACING};
    my($spacing) = ($self->{HEIGHT}-(2*$self->{YBORDER}))/(scalar(@leaves)-1);
    foreach my $leaf (@leaves){
	$leaf->attributes->{'_yloc'} = $currY;
	$leaf->attributes->{'_xloc'} = $currX if(!$placement); #don't place if using distance
	#print STDERR $leaf->name."Y LOC $currY\n";
        #print STDERR $leaf->name."X LOC $currX\n";
	$currY+=($spacing);
    }
}

sub setYLocations(){
    my($self,$newroot) = @_;
#
# Do depth first search to set y locations for internal nodes
# from the bottom out
    $newroot->root->walk_down({
	'callbackback' => sub {
	    my($cnode) = @_[0];
	    my(@dnodes) = $cnode->daughters;
	    if(scalar(@dnodes)){
		sort {
		    $a->attributes->{'_yloc'} <=> $b->attributes->{'_yloc'}
		} @dnodes;
		my($miny,$maxy) = ($dnodes[0]->attributes->{'_yloc'},$dnodes[scalar(@dnodes)-1]->attributes->{'_yloc'});
		my $currY = ($miny+$maxy)/2;
		$cnode->attributes->{'_yloc'} = $currY;
	    }
	    return 1;
	}});
}



#################
# Graphical subs
#################
sub drawNode{
    my($image,$xloc,$yloc,$ncolor,$size) = @_;
    my($maxx,$maxy);
    my($minx) = $xloc;
    my($miny) = $yloc-($size/2);
    $maxx = $minx+$size;
    $maxy = $miny+$size;
    $image->filledRectangle($minx,$miny,$maxx,$maxy,$ncolor);
    #print "minx: $minx\tminy: $miny\tmaxx: $maxx\tmaxy: $maxy\n";
    return ($minx,$miny,$maxx,$maxy);
}
sub drawLabel{
    my($image,$xloc,$yloc,$labelstr,$color,$rotation) = @_;
    my($width,$height) = $image->getBounds();
    my($minx,$miny,$maxx,$maxy);
    #GD::Font->Small
    if($rotation == 1){
	$minx = $xloc;
	$miny = $yloc;
	$maxx = $minx+((GD::Font->Tiny->width));
	$maxy = $yloc-(GD::Font->Tiny->width*length($labelstr));
	$image->stringUp(GD::Font->Tiny,$minx,$miny,$labelstr,$color);
    }elsif($rotation == 2){
	$minx = $xloc - ((GD::Font->Tiny->width));
	$miny = $yloc+(GD::Font->Tiny->width*length($labelstr));
	$maxx = $minx+((GD::Font->Tiny->width));
	$maxy = $yloc;
	$image->stringUp(GD::Font->Tiny,$minx,$miny,$labelstr,$color);
    }
    elsif($rotation == 3){
	$minx = $xloc -((GD::Font->Tiny->width)*length($labelstr));
	$miny = $yloc - (GD::Font->Tiny->height/2);
	$maxx += $xloc;
	$maxy += GD::Font->Tiny->height;
	$image->string(GD::Font->Tiny,$minx,$miny,$labelstr,$color);
    }
    else{
	$minx = $xloc+3;
	$miny = $yloc - (GD::Font->Tiny->height/2);
	$maxx += 3+((GD::Font->Tiny->width)*length($labelstr));
	$maxy += GD::Font->Tiny->height;
	$image->string(GD::Font->Tiny,$minx,$miny,$labelstr,$color);
    }
    return ($minx,$miny,$maxx,$maxy);
}

sub addToImageMap{
    my($imagemap,$node,$x1,$y1,$x2,$y2) = @_;
    if($imagemap){
	if($node->attributes->{"hlink"}){
	    $x1 = int($x1); $y1 = int($y1); $x2 = int($x2); $y2 = int($y2);
	    $$imagemap.="<area shape=rect coords='$x1,$y1,$x2,$y2' href='".$node->attributes->{'hlink'}."' alt='".$node->attributes->{'label'}."'>";
	    #print "#########################################<br>\n";
	    #print "x1: $x1\ty1: $y1\tx2: $x2\ty2: $y2<br>\n";
	    #print "hlink: ".$node->attributes->{'hlink'}."\tlabel: ".$node->attributes->{'label'}."<br>\n";
	    #print "#########################################<br>\n";
	}
    }
}

sub drawConnectToMother{
    my($image,$mxloc,$myloc,$xloc,$yloc,$color,$label) = @_;
    #print STDERR "$xloc,$yloc,$mxloc,$yloc,$color\n" if($self->{'DEBUG'} == 1);
    $image->line($xloc,$yloc,$mxloc,$yloc,$color);
    $image->line($mxloc,$yloc,$mxloc,$myloc,$color);
    #print "(xloc,mxloc): ($xloc,$mxloc)\t(yloc,yloc): ($yloc,$yloc)\n";
    #print "(mxloc,mxloc): ($mxloc,$mxloc)\t(yloc,myloc): ($yloc,$myloc)\n";
    
    $image->string(GD::Font->Small,$mxloc+(($xloc-$mxloc)/2),$yloc,$label,$color) if($label);
    return 1;
}
sub drawConnectToMotherCircular{
    my($image,$mxloc,$myloc,$xloc,$yloc,$color,$label) = @_;
    $image->line($xloc,$yloc,$mxloc,$myloc,$color);
    $image->string(GD::Font->Small,$mxloc,$myloc,$label,$color) if($label); # this needs to be positioned on line
    return 1;
}

sub setRotations(){
    my($self) = @_;
    if($self->{ROTATION} == 1){
	($self->{HEIGHT},$self->{WIDTH}) = ($self->{WIDTH},$self->{HEIGHT});
    }
}

sub transform{
    my($self,$x1,$y1,$x2,$y2) = @_;
    if($self->{ROTATION} == 1){
	return ($y2,$self->{WIDTH}-$x2+5,$y1,$self->{WIDTH}-$x1+5);
    }
    elsif($self->{ROTATION} == 2){
	return ($y2,$x2-5,$y1,$x1-5);
    }
    elsif($self->{ROTATION} == 3){
	return ($self->{WIDTH}-$x1+5,$y1,$self->{WIDTH}-$x2+5,$y2);
    }
    return ($x1-5,$y1,$x2-5,$y2);
}
 

###################
# Pref file options
####################

sub getNodeColorFromParam{
    my($node,$colorname) = @_; 
    my($color) =  $node->daughters ? "0,0,0" : "255,0,0";
    $color = $node->attributes->{$colorname} if(exists $node->attributes->{'colorname'});
    return $color;
}
sub getEdgeColorFromParam{
    my($node,$colorname) = @_;
    my($color) =  "0,0,0";
    $color = $node->attributes->{$colorname} if(exists $node->attributes->{'colorname'});
    return $color;
}
sub getLabelColorFromParam{
    my($node,$colorname) = @_;
    my($color) = "0,0,255";
    $color = $node->attributes->{$colorname} if(exists $node->attributes->{'colorname'});
    return $color;
}
sub getLabelFromParam{
    my($node,$labelname) = @_;
    my($label) = $node->attributes->{'nh_label'} || $node->attributes->{'_key'};
    $label = $node->attributes->{$labelname} if(exists $node->attributes->{$labelname});
    #print "#########################################################################################################################\n";
    #print "nh_label: ".$node->attributes->{'nh_label'}."\tkey: ".$node->attributes->{'_key'}."\tlabelname: ".$node->attributes->{$labelname}."\n";
    #print "label: $label\n";
    #print "#########################################################################################################################\n";
    $label =~ s/\'//g;
    return $label;
}

#################################
# Tree manipulation subs
#################################
sub doBreadthFirstSearch{
    # Fake queue structure by using unshift on array
    # (unshift)-> [->->->->] ->(pop)
    my($root,$func,$order) = @_;
    my(@queue);
    unshift @queue, ($root);
    while(scalar(@queue)){
	my($cnode) = pop(@queue);
	$func->($cnode) if(!$order);
	unshift @queue, ($cnode->daughters);
	$func->($cnode) if($order);
    }
}

sub findAndSetDistance{
    # From root node, walk out through each generation 
    # and accumulate distance from root
    # return totaldistance and max single distance
    my($newroot,$debug) = @_;
    my($maxdist)=$newroot;
    my($maxsingledist) = $newroot;
    &doBreadthFirstSearch($newroot,
			  sub{
			    my($cnode) = @_[0];
			    if($cnode->mother){
				my($mdist) = $cnode->mother->attributes->{'absolute_distance'};
				my($dist) = $cnode->attributes->{'absolute_distance'};
				my($addist) = $mdist+$dist;
				$cnode->attributes->{'absolute_distance'} = $addist;
				$cnode->attributes->{'relative_distance'} = $dist;
				$maxsingledist = $cnode if($cnode->attributes->{'relative_distance'} > $maxsingledist->attributes->{'relative_distance'});
				$maxdist = $cnode if($cnode->attributes->{'absolute_distance'} > $maxdist->attributes->{'absolute_distance'});
#				print "SETTING ".$cnode->name." ".$cnode->attributes->{'absolute_distance'}." : ".$cnode->attributes->{'nh_label'}."\n" if($debug);
			    }
    });
    return ($maxdist,$maxsingledist);
}

sub getSubTree{
    my($root,$branch) = @_;
    if(!$branch || ($branch ==$root)){
	return $root;
    }
    my($newroot) = &getNodeByName($root,$branch);
    $newroot->unlink_from_mother;
    $newroot->{parent_child_hash_ref} = $root->{parent_child_hash_ref} if($root->{parent_child_hash_ref});
    return $newroot;
}
	
sub reRootByName{
    # Find new root and reroot
    my($root,$nodename,$debug) = @_;
    my($retrnode) = &getNodeByName($root,$nodename);
    if($retrnode == $root || !$retrnode){
	return $root;
    }
    my($newroot) = &reRoot($retrnode);
    
    return $newroot;
}

sub reRoot{
    # At reroot node, unlink making two subtrees.
    # For one of the subtrees, reverse all parent-child up to the old root
    # Then add this subtree as a child of the new root.
    #
    # could be done recursively
    # maybe later
    my($retrnode) = @_;
    my($nextoldmother);
    my($oldmother) = $retrnode->unlink_from_mother;
    my($isDone) = 0;
    my($newroot) = $retrnode;
    while(!$isDone){
	$nextoldmother = $oldmother->unlink_from_mother;
	if(!$nextoldmother){
	    $isDone = 1;
	}
	$retrnode->add_daughter($oldmother);
	$retrnode = $oldmother;
	$oldmother = $nextoldmother;
    }
    return $newroot;
}
sub unRoot{
    # may not work??
    my($root) = @_;
    my($daughter) = $root->new_daughter;
    my($oldroot) = $daughter->unlink_from_mother;
    $daughter->add_daughter($oldroot);
    return $daughter;
}
sub getNodeByName{
    # expensive, better way of doing this may be to store all 
    # nodes in a hash by name?
    # In any case current implementation only calls this once
    my($start,$name) = @_;
    my($foundnode);
    $start->root->walk_down({
	'callback' => sub {
	    if($_[0]->name eq $name){$foundnode=$_[0];}return 1;
	}
    });
    return $foundnode;
}
#############################
# Graphical utility functions
#############################
sub initImage{
    my($self) = @_;
    my($image);
    if($self->{ROTATION} == 1 || $self->{ROTATION} == 2){
	$image = new GD::Image($self->{HEIGHT},$self->{WIDTH});
    }else{
	$image = new GD::Image($self->{WIDTH},$self->{HEIGHT});
    }
    my($white) = $image->colorAllocate(255,255,255);
    $image->transparent($white); 
    $black = $image->colorAllocate(0,0,0);
    $blue = $image->colorAllocate(0,0,255);
    $red = $image->colorAllocate(255,0,0);
    $green = $image->colorAllocate(0,255,0);
    $purple = $image->colorAllocate(0,255,255);
    $yellow = $image->colorAllocate(255,255,0);
    return $image;
}
sub calculateCircular{
    my($mult,$dist,$angle) = @_;
    my($actualdist) = $mult*$dist;
    my($xcomponent);
    my($ycomponent);
    if($angle>=0 && $angle < 90){
	$xcomponent = cos(&deg2rad($angle));
	$ycomponent = sin(&deg2rad($angle));
    }
    elsif($angle>=90 && $angle<180){
	$angle = 180-$angle;
	$xcomponent = -1*(cos(&deg2rad($angle)));
	$ycomponent = sin(&deg2rad($angle));
    }
    elsif($angle>=180 && $angle<270){
	$angle = $angle-180;
	$xcomponent = -1*(cos(&deg2rad($angle)));
	$ycomponent = -1*(sin(&deg2rad($angle)));
    }
    elsif($angle>=270 && $angle<360){
	$angle = 360-$angle;
	$xcomponent = (cos(&deg2rad($angle)));
	$ycomponent = -1*(sin(&deg2rad($angle)));
    }
    return ($xcomponent*$actualdist,$ycomponent*$actualdist);
}

sub getPoint{
    my($a,$b,$c) = @_;
    my($icosA) = ($a**2 - $b**2 - $c**2)/(-2*$b*$c) if($b!=0 && $c!=0);
    my($angle) = POSIX::acos($icosA);
}
sub calculateX{
    my($mult,$loc) = @_;
    return ($mult*$loc)+10;
}
sub deg2rad{
    return (@_[0]/180)*3.1415;
}

sub initHTMLColors(){
$htmlcolors{'aliceblue'}  = "240,248,255";
$htmlcolors{'antiquewhite'}  = "250,235,215";
$htmlcolors{'aqua'}  = "0,255,255";
$htmlcolors{'aquamarine'}  = "127,255,212";
$htmlcolors{'azure'}  = "240,255,255";
$htmlcolors{'beige'}  = "245,245,220";
$htmlcolors{'bisque'}  = "255,228,196";
$htmlcolors{'black'}  = "0,0,0";
$htmlcolors{'blanchedalmond'}  = "255,235,205";
$htmlcolors{'blue'}  = "0,0,255";
$htmlcolors{'blueviolet'}  = "138,43,226";
$htmlcolors{'brown'}  = "165,42,42";
$htmlcolors{'burlywood'}  = "222,184,135";
$htmlcolors{'cadetblue'}  = "95,158,160";
$htmlcolors{'chartreuse'}  = "127,255,0";
$htmlcolors{'chocolate'}  = "210,105,30";
$htmlcolors{'coral'}  = "255,127,80";
$htmlcolors{'cornflowerblue'}  = "100,149,237";
$htmlcolors{'cornsilk'}  = "255,248,220";
$htmlcolors{'crimson'}  = "220,20,60";
$htmlcolors{'cyan'}  = "0,255,255";
$htmlcolors{'darkblue'}  = "0,0,139";
$htmlcolors{'darkcyan'}  = "0,139,139";
$htmlcolors{'darkgoldenrod'}  = "184,134,11";
$htmlcolors{'darkgray'}  = "169,169,169";
$htmlcolors{'darkgreen'}  = "0,100,0";
$htmlcolors{'darkkhaki'}  = "189,183,107";
$htmlcolors{'darkmagenta'}  = "139,0,139";
$htmlcolors{'darkolivegreen'}  = "85,107,47";
$htmlcolors{'darkorange'}  = "255,140,0";
$htmlcolors{'darkorchid'}  = "153,50,204";
$htmlcolors{'darkred'}  = "139,0,0";
$htmlcolors{'darksalmon'}  = "233,150,122";
$htmlcolors{'darkseagreen'}  = "143,188,143";
$htmlcolors{'darkslateblue'}  = "72,61,139";
$htmlcolors{'darkslategray'}  = "47,79,79";
$htmlcolors{'darkturquoise'}  = "0,206,209";
$htmlcolors{'darkviolet'}  = "148,0,211";
$htmlcolors{'deeppink'}  = "255,20,147";
$htmlcolors{'deepskyblue'}  = "0,191,255";
$htmlcolors{'dimgray'}  = "105,105,105";
$htmlcolors{'dodgerblue'}  = "30,144,255";
$htmlcolors{'firebrick'}  = "178,34,34";
$htmlcolors{'floralwhite'}  = "255,250,240";
$htmlcolors{'forestgreen'}  = "34,139,34";
$htmlcolors{'fuchsia'}  = "255,0,255";
$htmlcolors{'gainsboro'}  = "220,220,220";
$htmlcolors{'ghostwhite'}  = "248,248,255";
$htmlcolors{'gold'}  = "255,215,0";
$htmlcolors{'goldenrod'}  = "218,165,32";
$htmlcolors{'gray'}  = "128,128,128";
$htmlcolors{'green'}  = "0,128,0";
$htmlcolors{'greenyellow'}  = "173,255,47";
$htmlcolors{'honeydew'}  = "240,255,240";
$htmlcolors{'hotpink'}  = "255,105,180";
$htmlcolors{'indianred'}  = "205,92,92";
$htmlcolors{'indigo'}  = "75,0,130";
$htmlcolors{'ivory'}  = "255,255,240";
$htmlcolors{'khaki'}  = "240,230,140";
$htmlcolors{'lavender'}  = "230,230,250";
$htmlcolors{'lavenderblush'}  = "255,240,245";
$htmlcolors{'lawngreen'}  = "124,252,0";
$htmlcolors{'lemonchiffon'}  = "255,250,205";
$htmlcolors{'lightblue'}  = "173,216,230";
$htmlcolors{'lightcoral'}  = "240,128,128";
$htmlcolors{'lightcyan'}  = "224,255,255";
$htmlcolors{'lightgoldenrodyellow'}  = "250,250,210";
$htmlcolors{'lightgreen'}  = "144,238,144";
$htmlcolors{'lightgrey'}  = "211,211,211";
$htmlcolors{'lightpink'}  = "255,182,193";
$htmlcolors{'lightsalmon'}  = "255,160,122";
$htmlcolors{'lightseagreen'}  = "32,178,170";
$htmlcolors{'lightskyblue'}  = "135,206,250";
$htmlcolors{'lightslategray'}  = "119,136,153";
$htmlcolors{'lightsteelblue'}  = "176,196,222";
$htmlcolors{'lightyellow'}  = "255,255,224";
$htmlcolors{'lime'}  = "0,255,0";
$htmlcolors{'limegreen'}  = "50,205,50";
$htmlcolors{'linen'}  = "250,240,230";
$htmlcolors{'magenta'}  = "255,0,255";
$htmlcolors{'maroon'}  = "128,0,0";
$htmlcolors{'mediumaquamarine'}  = "102,205,170";
$htmlcolors{'mediumblue'}  = "0,0,205";
$htmlcolors{'mediumorchid'}  = "186,85,211";
$htmlcolors{'mediumpurple'}  = "147,112,219";
$htmlcolors{'mediumseagreen'}  = "60,179,113";
$htmlcolors{'mediumslateblue'}  = "123,104,238";
$htmlcolors{'mediumspringgreen'}  = "0,250,154";
$htmlcolors{'mediumturquoise'}  = "72,209,204";
$htmlcolors{'mediumvioletred'}  = "199,21,133";
$htmlcolors{'midnightblue'}  = "25,25,112";
$htmlcolors{'mintcream'}  = "245,255,250";
$htmlcolors{'mistyrose'}  = "255,228,225";
$htmlcolors{'moccasin'}  = "255,228,181";
$htmlcolors{'navajowhite'}  = "255,222,173";
$htmlcolors{'navy'}  = "0,0,128";
$htmlcolors{'oldlace'}  = "253,245,230";
$htmlcolors{'olive'}  = "128,128,0";
$htmlcolors{'olivedrab'}  = "107,142,35";
$htmlcolors{'orange'}  = "255,165,0";
$htmlcolors{'orangered'}  = "255,69,0";
$htmlcolors{'orchid'}  = "218,112,214";
$htmlcolors{'palegoldenrod'}  = "238,232,170";
$htmlcolors{'palegreen'}  = "152,251,152";
$htmlcolors{'paleturquoise'}  = "175,238,238";
$htmlcolors{'palevioletred'}  = "219,112,147";
$htmlcolors{'papayawhip'}  = "255,239,213";
$htmlcolors{'peachpuff'}  = "255,218,185";
$htmlcolors{'peru'}  = "205,133,63";
$htmlcolors{'pink'}  = "255,192,203";
$htmlcolors{'plum'}  = "221,160,221";
$htmlcolors{'powderblue'}  = "176,224,230";
$htmlcolors{'purple'}  = "128,0,128";
$htmlcolors{'red'}  = "255,0,0";
$htmlcolors{'rosybrown'}  = "188,143,143";
$htmlcolors{'royalblue'}  = "65,105,225";
$htmlcolors{'saddlebrown'}  = "139,69,19";
$htmlcolors{'salmon'}  = "250,128,114";
$htmlcolors{'sandybrown'}  = "244,164,96";
$htmlcolors{'seagreen'}  = "46,139,87";
$htmlcolors{'seashell'}  = "255,245,238";
$htmlcolors{'sienna'}  = "160,82,45";
$htmlcolors{'silver'}  = "192,192,192";
$htmlcolors{'skyblue'}  = "135,206,235";
$htmlcolors{'slateblue'}  = "106,90,205";
$htmlcolors{'slategray'}  = "112,128,144";
$htmlcolors{'snow'}  = "255,250,250";
$htmlcolors{'springgreen'}  = "0,255,127";
$htmlcolors{'steelblue'}  = "70,130,180";
$htmlcolors{'tan'}  = "210,180,140";
$htmlcolors{'teal'}  = "0,128,128";
$htmlcolors{'thistle'}  = "216,191,216";
$htmlcolors{'tomato'}  = "255,99,71";
$htmlcolors{'turquoise'}  = "64,224,208";
$htmlcolors{'violet'}  = "238,130,238";
$htmlcolors{'wheat'}  = "245,222,179";
$htmlcolors{'white'}  = "255,255,255";
$htmlcolors{'whitesmoke'}  = "245,245,245";
$htmlcolors{'yellow'}  = "255,255,0";
$htmlcolors{'yellowgreen'}  = "154,205,50";
}

1;
