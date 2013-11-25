package Coati::Utility;

# $Id: Utility.pm,v 1.7 2004-05-13 18:01:51 crabtree Exp $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME

Utility.pm - A module for providing utilities functions

=head1 VERSION

=head1 SYNOPSIS

    This is a library of utility functions that are auto exported.

=head1 DESCRIPTION

=head2 Overview

=over 4

=cut

use strict;
use File::Basename;
our (@ISA,@EXPORT);
use Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(create_hash do_params abs min max);

=item $hashrefarray = create_hash($fields, $ret)

B<Description:> 

Creates an array of hash references from a multidimensional array

    $ret = [['Avalue1','Bvalue1'],['Avalue2','Bvalue2']];
    $fields = ['A','B'];
    $hashrefarray = create_hash($fields,$ret);
    foreach my $elt (@$hashrefarray){
       #$elt->{'A'} eq 'Avalue1'
       #$elt->{'B'} eq 'Bvalue1'
       #$elt->{'A'} eq 'Avalue2'
       #$elt->{'B'} eq 'Bvalue2'
    }

B<Parameters:> 

$fields - array of names to be used as hash keys
$ret - multidimensional array

B<Returns:> 

$hashrefarray - an array of hash references

=cut

sub create_hash{
    my ($fields, $ret) = @_;
    
    my @s;
    
    for my $i (0 ..  $#{$ret}) {
	my %currhash = map {$fields->[$_], $ret->[$i][$_]} (0..$#{$ret->[$i]});
	push @s,\%currhash;
    }
    return \@s;
}

=item do_params()

B<Description:> function that handles named parameters given to
functions. The subroutine pre-processes named or positional arguments
and returns the result as a hash reference.

B<Parameters:> 

    Users may send an anonymous hash which describes the parameter
    names and their defaults OR a list of values. This allows users to
    make a function call with either the usual argument list, or a hash
    of named parameters. This enables adding complex variables when
    you want to get real tricky. 

    The coder must describe each key but the content may remain blank, as in:

    my $param = do_params(\@_,
			   [foo => '', 
			    bar => '']
			   );


B<Returns:> 
 A reference to a hash of params.

The following code demonstrates the use of do_params();

invoke using: $OBJ->param_demo();

 sub param_demo {
     my $self = shift;
 
     param_demo_function("Love1radio", "godzone");
     print "\n";
 
     param_demo_function();
     print "\n";
 
     param_demo_function({foo => 'mary', bar => 'palmer'});
     print "\n";
 
     param_demo_function({foo => 'dundunba'});
     print "\n";
 
 }

 sub param_demo_function {
     my $param = do_params(\@_,
			    [foo => 'val1', 
			     bar => 'val2']
			    );
 
     for (keys %$param) {
 	print "$_: $$param{$_}\n";
     }
 
     print "$param->{'foo'}\n";
 			  
 }
 
Neat huh? do_params() code was taken from Effective
Perl Programming, Joseph N. Hall. ISBN 0201419750.

=cut


sub do_params {
    my $arg = shift;
    my @defaults = @{shift()};
    my %param;

    if (ref $$arg[0] eq 'HASH' && (scalar(@$arg) == 1)) {
	%param = (@defaults, %{$$arg[0]});
    }
    else {
	my $n = 1;
	my @arg = @$arg;

	while (@arg) {

	    $defaults[$n] = shift @arg;
	    $n += 2;
	    
	}
	%param = @defaults;
    }
    return(\%param);
}




sub abs {
    my($x) = @_;
    if ($x < 0) {
        $x *= -1;
    }
    return ($x);
}

sub max {
    my($x,$y) = @_;
    return ($x >= $y) ? $x :$y;
}
        
sub min {
    my($x,$y) = @_;
    return ($x < $y) ? $x :$y;
}

1;

__END__

=back

=head1 ENVIRONMENT

This module does not use or set any environment variables. The standard
module, File::Basename is required.

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

Copyright (c) 2002, The Institute for Genomic Research. All Rights Reserved.

