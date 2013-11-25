#!/usr/local/bin/perl
use Getopt::Std;
use vars qw($opt_i);

getopt('i');
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
#$mult->printTab("--");
my($output) = $mult->getMatrix();
#output is the matrix represented as array references
if($opt_i){
    print $mult->getImage(100,100);
}
else{
    foreach my $row (@$output){
	foreach my $col (@$row){
	    print $col,"\t";
	}
	print "\n";
    }
}
