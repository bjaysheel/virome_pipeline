package Plot::XYPlot;

#Yet Another Plotter
#--BUGS:
#invert option not valid on polygon line types
use strict;
use GD;
use POSIX;

my $VERSION = qw$Revision: 1.5 $[1];
my @ISA = qw(Exporter);
my @EXPORT = qw(&setView &doPlot &addPoints &addRectangles &addLines &testColorArray);

#######################
# object functions
#######################
sub new {
    my $classname = shift;
    my $self = {};
    bless($self,$classname); 
    $self->{'ELEMENTS'} = {};
    $self->{'VISELTS'} = [];
    $self->{'NUMELEMENTS'} = 0;
    $self->{'XBORDER'}=0;
    $self->{'YBORDER'}=0;
    $self->{'LINETHICKNESS'} = 3;
    $self->{'ATTRKEY'} = "__NONE__";
    $self->{'COLORLOOKUP'} = {};
    $self->{'COLORARRAY'} = [];
    $self->{'COLORCOUNT'} = 0;
    $self->{'GRADIENT'} = 0;
    $self->{'TOTAL_COLORS'} = 255;
    $self->{'LOWER_GRADIENT'} = .5;
    $self->{'UPPER_GRADIENT'} = .95;
    $self->{_color_indexhash} = {};
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

####################
# Public functions 
####################
#
# return png graphic file
sub doPlot(){
    my($self) = @_;
    if($self->{'WIDTH'} eq "" || $self->{'HEIGHT'} eq ""){
	print STDERR "Enter width and height\n. eg: new Yap('WIDTH'=>300,'HEIGHT'=>400)\n";
    }
    if($self->{'XSTART'} eq "" || $self->{'YSTART'} eq ""){
	print STDERR "Enter viewing box\n. eg: yap->setView(x1,y1,x2,y2);\n";
    }
    #
    # Init image
    my($image);
    if($self->{'INVERT'}==1 || $self->{'INVERT'}==2){
	$image = new GD::Image($self->{'YBORDER'}+$self->{'HEIGHT'},$self->{'XBORDER'}+$self->{'WIDTH'});
    }
    else{
	$image = new GD::Image($self->{'XBORDER'}+$self->{'WIDTH'},$self->{'YBORDER'}+$self->{'HEIGHT'});
    }
    $image->interlaced('true');
    $image->colorAllocate(255,255,255); # set background white
    if($self->{'GRADIENT'}){
	($self->{'GRADIENT_MIN'},$self->{'GRADIENT_MAX'}) =  &getMinMax($self->{'ELEMENTS'},$self->{'ATTRKEY'},$self->{'LOWER_GRADIENT'},$self->{'UPPER_GRADIENT'});
	$self->{'GRADIENT_LOOKUP'} = $self->init_color_spectrum($image);
    }
    #
    # Cycle through elements and print
    my($eltsref) = $self->{'ELEMENTS'};
    $self->{'VISELTS'} = [];
    my($visref) = $self->{'VISELTS'};
    foreach my $elt (sort {$a <=> $b} (keys %$eltsref)){
	my($currelt) = $self->{'ELEMENTS'}->{$elt};
	my($coordref) = $currelt->{'COORDS'};
	print "Plotting element $elt type: $currelt->{'TYPE'} with ",scalar(@$coordref)," points\n" if($self->{'DEBUG'});
	my($aref) = $currelt->{'ATTRS'};
	my($iref) = $currelt->{'IMGCOORDS'};
	splice @$iref,scalar($iref); #clear imagemap array
	my($imgcoords) = [];
	if($self->isVisible($coordref)){
	    push (@$visref,$aref) if($aref ne "");
	    if($currelt->{'TYPE'} eq "rect"){
		$imgcoords = $self->plotRects($image,$coordref,$aref);
	    }
	    elsif($currelt->{'TYPE'} eq "line"){
		$imgcoords = $self->plotLines($image,$coordref,$aref);
	    }
	    elsif($currelt->{'TYPE'} eq "point"){
		$imgcoords = $self->plotPoints($image,$coordref,$aref);
	    }
	    elsif($currelt->{'TYPE'} eq "blip"){
		$imgcoords = $self->plotBlips($image,$coordref,$aref);
	    }
	}
	push (@$iref,@$imgcoords);
    }
    return $image->png;
}
sub getMinMax(){
    my($eltsref,$key,$lower,$upper) = @_;
    my($min)=1e100;
    my($max)=0;
    my(@ascores);
    foreach my $elt (sort {$a <=> $b} (keys %$eltsref)){
	my($currelt) = $eltsref->{$elt};
	my($aref) = $currelt->{'ATTRS'};
	my($val) = $aref->{$key};
	$min = ($val<$min) ? $min : $val;
	$max = ($val>$max) ? $max : $val;	
	push @ascores,$val;
    }
    my($min_score, $max_score) = process_limits($lower,$upper, \@ascores);
    return ($min_score,$max_score);
}
sub getColorByAttribute(){
    my($self,$val) = @_;
    return $self->{'COLORLOOKUP'}->{$val};
}
sub setColorByAttribute(){
    my($self,$attr,$type) = @_;
    if($type eq "gradient"){
	$self->{'GRADIENT'} = 1;
	#gradient coloring
    }
    else{
	#fixed value coloring eg color by role num
	&initColorArray($self->{'COLORARRAY'}); 
	$self->{'GRADIENT'} = 0;
    }
    $self->{'ATTRKEY'} = $attr;
}
sub seedColors(){
    my($self,$values) = @_;
    &initColorArray($self->{'COLORARRAY'});
    foreach my $val (@$values){
	if(!exists $self->{'COLORLOOKUP'}->{$val}){
	    $self->{'COLORLOOKUP'}->{$val} = &getUniqueColor($self->{'COLORARRAY'},++$self->{'COLORCOUNT'});
	}
    }
}
sub setView(){
    my($self,$xstart,$xstop,$ystart,$ystop) = @_;
    &setXScale($self,$xstart,$xstop);
    &setYScale($self,$ystart,$ystop);
}
sub invertaxis(){
    my($self,$type) = @_;
    $type = 1 if($type eq "");
    $self->{'INVERT'} = $type;
}
#
# coords (ax1,ay1,bx1,by1,...,axN,ayN,bxN,byN);
# aref [OPTIONAL] {'COLOR'=>"r,g,b",'TYPE'->"connected|scatter"}
sub addPoints(){
    my($self,$coordref,$aref) = @_;
    $self->{'ELEMENTS'}->{++$self->{'NUMELEMENTS'}} = {'TYPE' => 'point','COORDS' => $coordref,'ATTRS' => $aref,'IMGCOORDS'=> []}; 
    print "Saved point element number $self->{'NUMELEMENTS'} as $coordref $self->{'ELEMENTS'}->{$self->{'NUMELEMENTS'}}->{'IMGCOORDS'}\n" if($self->{'DEBUG'});
    return $self->{'ELEMENTS'}->{$self->{'NUMELEMENTS'}}->{'IMGCOORDS'};
}
#
# coords (ax1,ay1,bx1,by1,...,axN,ayN,bxN,byN);
# aref [OPTIONAL] {'COLOR'=>"r,g,b",'TYPE'->"filled|unfilled"}
sub addRectangles(){
    my($self,$coordref,$aref) = @_;
    $self->{'ELEMENTS'}->{++$self->{'NUMELEMENTS'}} = {'TYPE' => 'rect','COORDS' => $coordref,'ATTRS' => $aref,'IMGCOORDS'=> []}; 
    print "Saved rect element number $self->{'NUMELEMENTS'} as $coordref\n" if($self->{'DEBUG'});
    return  $self->{'ELEMENTS'}->{$self->{'NUMELEMENTS'}}->{'IMGCOORDS'};
}
#
# coordref (ax1,ay1,bx1,by1,...,axN,ayN,bxN,byN);
# aref [OPTIONAL] {'COLOR'=>"r,g,b",'TYPE'=>"dotted|full"}
sub addLines(){
    my($self,$coordref,$aref) = @_;
    $self->{'ELEMENTS'}->{++$self->{'NUMELEMENTS'}} = {'TYPE' => 'line','COORDS' => $coordref,'ATTRS' => $aref,'IMGCOORDS'=> []};
    print "Saved line element number $self->{'NUMELEMENTS'} as $coordref\n" if($self->{'DEBUG'});
    return  $self->{'ELEMENTS'}->{$self->{'NUMELEMENTS'}}->{'IMGCOORDS'};
}
#
# coords (ax1,ay1,axN,ayN);
# aref [OPTIONAL] {'COLOR'=>"r,g,b",'TYPE'->"filled|unfilled"}
sub addBlips(){
    my($self,$coordref,$aref) = @_;
    $self->{'ELEMENTS'}->{++$self->{'NUMELEMENTS'}} = {'TYPE' => 'blip','COORDS' => $coordref,'ATTRS' => $aref,'IMGCOORDS'=> []}; 
    print "Saved rect element number $self->{'NUMELEMENTS'} as $coordref\n" if($self->{'DEBUG'});
    return  $self->{'ELEMENTS'}->{$self->{'NUMELEMENTS'}}->{'IMGCOORDS'};
}
sub img2datacoords(){
    my($self,$ix,$iy) =@_;
    my($cx,$cy);
    ($cx,$cy) = (((($ix/($self->{'WIDTH'}))*$self->{'XSPAN'})+$self->{'XSTART'}),((($iy/($self->{'HEIGHT'}))*$self->{'YSPAN'})+$self->{'YSTART'}));
#    print "axis :$self->{'INVERT'}: $ix $iy ($cx $cy)\t";
    #if($self->{'INVERT'}){
#	($cx,$cy) = $self->invertcoords($cx,$cy);
#    }
#    print "axis :$self->{'INVERT'}: $ix $iy ($cx $cy)\n";
    return ($cx,$cy);
}
sub getVisible(){
    my($self) = @_;
    return $self->{'VISELTS'};
}
###################
# Private functions
###################
#Coordinate functions
sub setXScale(){
    my($self,$xstart,$xstop) = @_;
    if($xstart>=$xstop){
	print STDERR "YAP: Bad xscale[$xstart:$xstop]\n";
    }
    else{
	$self->{'XSTART'} = $xstart;
	$self->{'XSTOP'} = $xstop;
	$self->{'XSPAN'} = $xstop-$xstart;
    }
}
sub setYScale(){
    my($self,$ystart,$ystop) = @_;
    if($ystart>=$ystop){
	print STDERR "YAP: Bad yscale[$ystart:$ystop]\n";
    }
    $self->{'YSTART'} = $ystart;
    $self->{'YSTOP'} = $ystop;
    $self->{'YSPAN'} = $ystop-$ystart;
}
sub transform_y {
    my($self,$y) = @_;
    return $self->{'HEIGHT'} - (
				$self->{'YBORDER'} + (((
							($y-$self->{'YSTART'})
							)
						       / $self->{'YSPAN'}
						       )
						      * $self->{'HEIGHT'}
						      )
				);
}
sub transform_x {
    my($self,$x) = @_;
    return $self->{'XBORDER'} + (((
				   ($x-$self->{'XSTART'})
				   )
				  / $self->{'XSPAN'}
				  )
				 * $self->{'WIDTH'}
				 );
}
sub correctCoords{
    my($coords,$i) = @_;
    if(@$coords[$i]>@$coords[$i+2]){
	(@$coords[$i],@$coords[$i+2]) =  (@$coords[$i+2],@$coords[$i]);
    }
    if(@$coords[$i+1]>@$coords[$i+3]){
	(@$coords[$i+1],@$coords[$i+3]) =  (@$coords[$i+3],@$coords[$i+1]);
    }
}
sub invertcoords(){
    my($self,$x1,$y1,$x2,$y2) = @_;
    if($self->{'INVERT'} ==1){
	return ($y1,$self->{'WIDTH'}-$x1,$y2,$self->{'WIDTH'}-$x2);
    }
    elsif($self->{'INVERT'} ==2){
	#return ($self->{'HEIGHT'} - $y1,$x1,$self->{'HEIGHT'} - $y2,$x2);
    }
    elsif($self->{'INVERT'} ==3){
	return ($x1,$self->{'HEIGHT'} - $y1,$x2,$self->{'HEIGHT'} - $y2);
    }
    else{
	return ($x1,$y1,$x2,$y2);
    }
}	
sub isVisible{
    my($self,$coords) = @_;
    my($minx,$miny) = (1e100,1e100);
    my($maxx,$maxy) = (0,0);
    for(my $i=0;$i<scalar(@$coords);$i+=2){
	if($i%2){}
	else{
	    $minx = @$coords[$i] if(@$coords[$i]<$minx);
	    $maxx = @$coords[$i] if(@$coords[$i]>$maxx);
	    $miny = @$coords[$i+1] if(@$coords[$i+1]<$miny);
	    $maxy = @$coords[$i+1] if(@$coords[$i+1]>$maxy);
	    if(@$coords[$i]>=$self->{'XSTART'} && @$coords[$i]<=$self->{'XSTOP'} && @$coords[$i+1]>=$self->{'YSTART'} && @$coords[$i+1]<=$self->{'YSTOP'}){
		return 1;
	    }
	}
    }
    #check feature that spans viewable window
    if(($minx < $self->{'XSTART'} && $maxx > $self->{'XSTOP'}) || ($miny < $self->{'YSTART'} && $maxy > $self->{'YSTOP'})){
	return 1;
    }
    return 0;
}
#
#Coloring functions
#
sub initColorArray2{
    my($aref,$num) = @_;
    $num = 100 if(!$num);
    return 1 if(scalar(@$aref)>0);
    my($ra)=srand(3);
    my($hstep) = 1/$num;
    my($lstep) = .4/$num;
    
    my(@rgbs);
    for(my $h=0;$h<=1;$h+=$hstep){
	for(my $l=.6;$l<=1;$l+=$lstep){
	    #my $l = rand(.2);
	    #$l+=.8;
	    print STDERR "H:$h L:$l\n";
	    push @rgbs,hls2rgb($h,$l,1);
	}
    }
    for(my $i=0;$i<$num;$i++){
	my($index) = int(rand(scalar(@rgbs)));
	print STDERR "$i $index $rgbs[$index]\n";
	push @$aref,$rgbs[$index];
    }
    return 0;
}
sub initColorArray{
    my($aref,$num) = @_;
    $num = 100 if(!$num);
    return 1 if(scalar(@$aref)>0);
    my($ra)=srand(300); 
    for(my $i=0;$i<$num;$i++){
	my($h)=rand(1); 
	my($l)=.8+rand(.2);
	push @$aref,hls2rgb($h,$l,1);
    }
    return 0;
}
sub testColorArray{
    my($numcolors) = @_;
    my($size)=2;
    my($plot) = new yap('WIDTH'=>400,'HEIGHT'=>100,'DEBUG'=>0);
    my($x)=0;
    for(my $i=0;$i<=$numcolors;$i++){
	$plot->addRectangles([$x,0,$x+$size,20],{'DATA'=>$i});
	$x+=$size;
    }
    $plot->setView(0,$numcolors,0,20);
    $plot->setColorByAttribute("DATA");
    return $plot->doPlot();
}
sub getUniqueColor{
    my($aref,$number) = @_;
    if($number>=scalar(@$aref)){
	$number = $number % scalar(@$aref);
    }
    return @$aref[$number];
}
sub getColor(){
    my($self,$image,$color) = @_;
    my $colorindex;
    if(exists $self->{_color_indexhash}->{$color}){
	return $self->{_color_indexhash}->{$color};
    }
    else{
	if(!($color =~ /\d+,\d+,\d+/)){
	    $colorindex = $image->colorResolve(0,0,0);
	}
	else{
	    $colorindex = $image->colorResolve(eval($color));
	}
	$self->{_color_indexhash}->{$color} = $colorindex;
	return $colorindex;
    }
}
sub parseColor(){
    my($self,$image,$attrs) = @_;
    if($self->{'GRADIENT'}){
       #print "Getting color $self->{'ATTRKEY'}\n";
	if($attrs->{$self->{'ATTRKEY'}}){
	    #print "$attrs->{$self->{'ATTRKEY'}}\n";
	    my($n) = $self->calc_color_assignment($attrs->{$self->{'ATTRKEY'}});
	    return $self->{'GRADIENT_LOOKUP'}->{$n}->{'index'};
	}
    }
    else{
	if(exists $attrs->{$self->{'ATTRKEY'}} && $attrs->{$self->{'ATTRKEY'}} ne "" && $attrs->{$self->{'ATTRKEY'}} ne "NULL"){
	    if(!exists $self->{'COLORLOOKUP'}->{$attrs->{$self->{'ATTRKEY'}}}){
		$self->{'COLORLOOKUP'}->{$attrs->{$self->{'ATTRKEY'}}} = &getUniqueColor($self->{'COLORARRAY'},++$self->{'COLORCOUNT'});
	    }
	    print "ATTRCOLOR: ".
		"Found color $self->{'COLORLOOKUP'}->{$attrs->{$self->{'ATTRKEY'}}}"
		    ." using key $attrs->{$self->{'ATTRKEY'}} for attribute $self->{'ATTRKEY'}\n" if($self->{'DEBUG'});
	    return $self->getColor($image,$self->{'COLORLOOKUP'}->{$attrs->{$self->{'ATTRKEY'}}});
	}
    }
    if($attrs->{'COLOR'}){
	return $self->getColor($image,$attrs->{'COLOR'});
    }
    else{
	return $self->getColor($image,"0,0,0");
    }
}
sub init_color_spectrum {
    my($self,$image) = @_;
    my($TOTAL_COLORS) = $self->{'TOTAL_COLORS'};
    my($i, %palette);
    my($r,$g,$b);
    my($pi);
    
    $pi = atan2(1,1) * 4;
    $r = 0, $g = 0, $b = 0;

    for($i=0;$i<$TOTAL_COLORS;$i++) {

	# spectrum algorithm by john quackenbush.
	#  the value of $i must be between 0 and 255

	$r = 255 if ($i <=32);
	$r = abs(int(255*cos(($i-32)*$pi/151))) if ($i>32 && $i <= 107)  ;
	$r = 0 if ($i > 107);
 
	$g = 0 if ($i < 4);
	$g = abs(int(255*cos(($i-100)*$pi/189))) if ($i > 4 && $i <= 100) ;
	$g = abs(int(255*cos(($i-100)*$pi/294))) if ($i > 100 && $i <= 228) ;
	$g = 0 if ($i > 230) ;
    
	$b = 0 if ($i < 71);
	$b = abs(int(255*cos(($i-199)*$pi/256))) if ($i >= 71 && $i <= 199) ;
	$b = abs(int(255*cos(($i-199)*$pi/113))) if ($i > 199) ;
	$palette{$i}->{'index'} = $image->colorResolve($r,$g,$b);
	$palette{$i}->{'rgb'} = "$r,$g,$b";
    }

    return(\%palette);
}

sub calc_color_assignment {
    my($self, $score) = @_;
    my($min,$max) = ($self->{'GRADIENT_MIN'},$self->{'GRADIENT_MAX'});
    my($TOTAL_COLORS) = $self->{'TOTAL_COLORS'};
    my($r, $q);

    # you get a choice of 0 through $TOTAL_COLORS
    $r = $TOTAL_COLORS / ($max - $min);

    $q = int($r * ($score-$min));
    $q = $TOTAL_COLORS - $q;
    
    $q = $TOTAL_COLORS - 1 if ($q >= $TOTAL_COLORS);
    #if($q < 0){
#	print STDERR "BAD score $q $score\n";
#    } 
     $q = 0 if ($q <=0);

    return($q);
}
sub process_limits {
    my($ll, $ul, $l) = @_;
    my($len, $x1, $x2);

    $len = scalar(@$l);
    my(@k) = sort {$a<=>$b} (@$l);
    if ($ll != -1) {
	$x1 = $k[int($len * $ll)];
	$x2 = $k[int($len * $ul)];
    }
    else {
	$x1 = $k[0];
	$x2 = $k[$len-1];
    }

    return($x1, $x2);
}

sub hls2rgb(){
    my($h,$l,$s) = @_;
    my $h6 = ($h-floor($h))*6;
    my $r = ($h6 <= 3) ? 2-$h6	: $h6-4;
    my $g = ($h6 <= 2) ? $h6 : ($h6 <= 5) ? 4-$h6 : $h6-6;
    my $b  = $h6 <= 1 ? -$h6 : ($h6 <= 4) ? $h6-2   : 6-$h6;
    $r = ($r < 0.0) ? 0.0 : ($r > 1.0) ? 1.0 : $r;
    $g = ($g < 0.0) ? 0.0 : ($g > 1.0) ? 1.0 : $g;
    $b = ($b < 0.0) ? 0.0 : ($b > 1.0) ? 1.0 : $b;
    $r = (($r-1)*$s+1)*$l;
    $g = (($g-1)*$s+1)*$l;
    $b = (($b-1)*$s+1)*$l;
    $r = int($r * 255);
    $b = int($b * 255);
    $g = int($g * 255);
    return "$r,$g,$b";
}
#
#Plotting functions
#
sub plotRects(){
    my($self,$image,$coords,$attrs) = @_;
    my($color) = $self->parseColor($image,$attrs);
    my(@icoords);
    for(my $i=0;$i<scalar(@$coords);$i+=4){
	print "Plotting lines for @$coords[$i] @$coords[$i+1] @$coords[$i+2] @$coords[$i+3] with color: $color\n" if($self->{'DEBUG'});
	my(@cicoords) = (&transform_x($self,(@$coords[$i])),&transform_y($self,(@$coords[$i+1])),&transform_x($self,(@$coords[$i+2])),&transform_y($self,(@$coords[$i+3])));
	@cicoords = $self->invertcoords(@cicoords) if($self->{'INVERT'});
	&correctCoords(\@cicoords,0); #fit to GD expectations 
	if($attrs->{'TYPE'} eq "unfilled"){
	    $image->rectangle(@cicoords,$color);
	}
	else{
	    print "Rect $self->{'INVERT'} coords ",@cicoords[0],"::",@cicoords[1],"::",@cicoords[2],"::",@cicoords[3],"\n" if($self->{'DEBUG'});
	    $image->filledRectangle(@cicoords,$color);
	}
	push(@icoords,@cicoords);
    }
    return \@icoords;
}
sub plotLines(){
    my($self,$image,$coords,$attrs) = @_;
    my($color) = $self->parseColor($image,$attrs);
    my(@icoords);
    for(my $i=0;$i<scalar(@$coords);$i+=4){
	print "Plotting lines for @$coords[$i] @$coords[$i+1] @$coords[$i+2] @$coords[$i+3] with color: $color\n" if($self->{'DEBUG'});
	if($attrs->{'TYPE'} eq "dotted"){
	    my(@cicoords) = (&transform_x($self,(@$coords[$i])),&transform_y($self,(@$coords[$i+1])),&transform_x($self,(@$coords[$i+2])),&transform_y($self,(@$coords[$i+3])));
	    @cicoords = $self->invertcoords(@cicoords) if($self->{'INVERT'});
	    $image->dashedLine(@cicoords,$color);
	    push(@icoords,@cicoords);
	}
	else{
	    my $poly = new GD::Polygon;
	    #
	    # polygon size dictated by data coords
	    if($attrs->{'COORDSPAN'}){
		my(@cicoords) = (&transform_x($self,(@$coords[$i]-$attrs->{'COORDSPAN'})),&transform_x($self,(@$coords[$i]+$attrs->{'COORDSPAN'})),
				 &transform_y($self,(@$coords[$i+1])),
				 &transform_x($self,(@$coords[$i+2]+$attrs->{'COORDSPAN'})),&transform_x($self,(@$coords[$i+2]-$attrs->{'COORDSPAN'})),
				 &transform_y($self,(@$coords[$i+3])));
		$poly->addPt($cicoords[0],$cicoords[2]);
		$poly->addPt($cicoords[1],$cicoords[2]);
		$poly->addPt($cicoords[3],$cicoords[5]);
		$poly->addPt($cicoords[4],$cicoords[5]);
		$poly->addPt($cicoords[0],$cicoords[2]);
	    }
	    #
	    # polygon size dictated by pixel size
	    else{
		my(@cicoords) = (&transform_x($self,(@$coords[$i])),&transform_y($self,(@$coords[$i+1])),&transform_x($self,(@$coords[$i+2])),&transform_y($self,(@$coords[$i+3])));
		my $span = $self->{'LINETHICKNESS'}/2;
		$poly->addPt($cicoords[0]-$span,$cicoords[1]);
		$poly->addPt($cicoords[0]+$span,$cicoords[1]);
		$poly->addPt($cicoords[2]+$span,$cicoords[3]);
		$poly->addPt($cicoords[2]-$span,$cicoords[3]);
		$poly->addPt($cicoords[0]-$span,$cicoords[1]);
	    }
	    my @vertices = $poly->vertices;
	    print "NUMPTS: ",scalar(@vertices),"\n" if($self->{'DEBUG'}>1);
	    foreach my $v (@vertices){
		push(@icoords,@$v);
	    }
	    if($attrs->{'TYPE'} eq "unfilled"){
		$image->polygon($poly,$color);
	    }
	    else{
		$image->filledPolygon($poly,$color);
	    }
	}
    }
    return \@icoords;
}
sub plotPoints(){
    my($self,$image,$coords,$attrs) = @_;
    my($color) = $self->parseColor($image,$attrs);
    my(@icoords);
    my($prevx) = $self->{'PREVPX'};
    my($prevy) = $self->{'PREVPY'};
    for(my $i=0;$i<scalar(@$coords);$i+=2){
	if($prevx eq "" && $prevy eq ""){
	    $prevx = &transform_x($self,@$coords[$i]);
	    $prevy = &transform_y($self,@$coords[$i+1]);
	    print "Initial coord @$coords[$i] @$coords[$i+1] $prevx $prevy\n" if($self->{'DEBUG'});
	}
	else{
	    print "Plotting lines for @$coords[$i] @$coords[$i+1] with color: $color with size".scalar(@$coords)."\n" if($self->{'DEBUG'});
	    my(@cicoords) = ($prevx,$prevy,&transform_x($self,(@$coords[$i])),&transform_y($self,(@$coords[$i+1])));
	    ($prevx,$prevy) = ($cicoords[2],$cicoords[3]);
	    @cicoords = $self->invertcoords(@cicoords) if($self->{'INVERT'});
	    $image->line(@cicoords,$color);
	    print "Plotted $cicoords[0] $cicoords[1] $cicoords[2]  $cicoords[3]\n"  if($self->{'DEBUG'});
	    push(@icoords,@cicoords);
	}
    }
    $self->{'PREVPX'} = $prevx;
    $self->{'PREVPY'} = $prevy;
    return \@icoords;
}
sub plotBlips(){
    my($self,$image,$coords,$attrs) = @_;
    my($color) =  $self->parseColor($image,$attrs);
    $attrs->{'SIZE'} = 3 if($attrs->{'SIZE'} eq "");
    my(@icoords);
    for(my $i=0;$i<scalar(@$coords);$i+=2){
	my($x1) = &transform_x($self,(@$coords[$i]));
	my($y1) = &transform_y($self,(@$coords[$i+1]));
	my($step) = $attrs->{'SIZE'}/2;
	my(@cicoords) = ($x1-$step,$y1-$step,$x1+$step,$y1+$step);
	@cicoords = $self->invertcoords(@cicoords) if($self->{'INVERT'});
	$image->filledRectangle(@cicoords,$color);
	push(@icoords,@cicoords);
    }
    return \@icoords;
}
	
1;
