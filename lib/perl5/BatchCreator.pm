# $Id: BatchCreator.pm 3761 2007-11-09 06:14:14Z jaysundaram $
=head1 NAME

Prism.pm - One line summary of purpose of class (or file).

=head1 VERSION

This document refers to version N.NN of Prism.pm, released MMMM, DD, YYYY.

=head1 SYNOPSIS

Short examples of code that illustrate the use of the class (if this file is a class).

=head1 DESCRIPTION

=head2 Overview

An overview of the purpose of the file.

=head2 Constructor and initialization.

if applicable, otherwise delete this and parent head2 line.

=head2 Class and object methods

if applicable, otherwise delete this and parent head2 line.

=over 4

=cut


package BatchCreator;

use strict;
use Carp;
use vars qw($AUTOLOAD);
use Coati::Logger;
use constant DEFAULT_BATCHSIZE => 400;

umask 0000;

=item $obj->new(%arg)

B<Description:> 

Retrieves

B<Parameters:> 

%arg - 

B<Returns:> 

Returns

=cut

#----------------------------------------------------------------
# new
#
#----------------------------------------------------------------

sub new {
    my $class = shift;
    
    my $self = bless {}, ref($class) || $class;
    $self->{_logger} = Coati::Logger::get_logger(__PACKAGE__."API");
    $self->{_array} = undef;
    $self->{_min} = 0;
    $self->{_batchSize} = 0;
    $self->{_max} = 0;
    $self->{_listSize} = 0;

    $self->{_logger}->debug("Init $class") if $self->{_logger}->is_debug;
    $self->_init(@_);

    return $self; 
}


=item $obj->_init(%arg)

B<Description:> Initializes the Coati Modules that Prism
depends upon due to multiple inheritance. In addition, a database handle
is created and set up as an object attribute. A local Prism object is
also created and setup as a _backend object attribute. This is a private
method that should not be called from front-end scripts.

B<Parameters:> %arg, hash received from "new" containing parameters for object attributes.

B<Returns:> None.

B<Returns:> 

Returns

=cut


#----------------------------------------------------------------
# _init
#
#----------------------------------------------------------------
sub _init {
    my $self = shift;
    my %arg = @_;
    
    foreach my $key (keys %arg) {
	$self->{_logger}->debug("Storing member variable $key as _$key=$arg{$key}") if $self->{_logger}->is_debug;
	$self->{"_$key"} = $arg{$key};
    }

    my @array = ( sort {$a <=> $b } @{$self->{_array}});

    $self->{_listSize} = scalar(@array) - 1;

    $self->{_array} = \@array;

    if (! exists $self->{_batchSize}){
	$self->{_batchSize} = DEFAULT_BATCHSIZE;
	$self->{_logger}->warn("The batchSize was not defined and therefore was set to '$self->{_batchSize}'");
    }
    elsif (($self->{_batchSize} < 1) || ($self->{_batchSize} eq '')) { 
	$self->{_logger}->warn("The batchSize should be unsigned int value, ".
			       "'$self->{_batchSize}' is not acceptable. ".
			       "Setting default batchSize: " . DEFAULT_BATCHSIZE);
	$self->{_batchSize} = DEFAULT_BATCHSIZE;
    }
	
    $self->{_batchSize}--;

    if ($self->{_batchSize} > $self->{_listSize}){
	confess "The batch size is larger than the list size!";
    }

    $self->{_max} = $self->{_batchSize};

}


=item $obj->AUTOLOAD()

B<Description:> 

Retrieves

B<Parameters:> 

Parameters

B<Returns:> 

Returns

=cut

sub AUTOLOAD {
    # We're not interested in reporting the non-existence of a destructor.
    # This is intended to inform the developer that the method he tried to
    # call is not implemented in the modules. The package variable $AUTOLOAD
    # contains the method that was called, but that did not exist.
    return if $AUTOLOAD =~ m/DESTROY/;
    die "Sorry, but $AUTOLOAD is not defined.\n";
}

=item $obj->DESTROY()

B<Description:> 

Retrieves

B<Parameters:> 

Parameters

B<Returns:> 

Returns

=cut

sub DESTROY {
    my $self = shift;
    #end perf metrics here
}

=item $obj->nextRange()

B<Description:> 

Retrieves

B<Parameters:> 

Parameters

B<Returns:> 

Returns

=cut

sub nextRange {

    my $self = shift;
            
    my $minVal;
    my $maxVal;

    if ($self->{_min} != 0){
	
	if ( ($self->{_max} + $self->{_batchSize} + 1 <= $self->{_listSize})){
	    $self->{_max} = $self->{_max} + $self->{_batchSize} + 1; 
	}
	else {
	    $self->{_max} = $self->{_listSize};
	}
    }

    $minVal = $self->{_array}->[$self->{_min}];
    $maxVal = $self->{_array}->[$self->{_max}];
	
    $self->{_min} = $self->{_max} + 1;

    return($minVal, $maxVal);
}

 
1; ## End of module

__END__

=back

=head1 ENVIRONMENT

This module checks for a PRISM environment variable to determine what relational database
type to use, which database server to connect to, and what schema type we are using.
If the variable is not set, then the module will parse the Prism.conf configuration
file to set it and will also set additional environment variables that are configured there.

=head1 DIAGNOSTICS

=over 4

=item "Error message that may appear."

Explanation of error message.

=item "Another message that may appear."

Explanation of another error message.

=back

=head1 BUGS

Description of known bugs (and any workarounds). Usually also includes an
invitation to send the author(s) bug reports.

=head1 SEE ALSO

Prism.conf - Configuration file with parameters containing which RDBMS to use,
which server it is running on, and what schema (Euk, Prok, etc...) type we need.
This file also contains other environment variables that may need to be set.

List of any other files or Perl modules needed by class and a
brief description why.

=head1 AUTHOR(S)

 Jay Sundaram
 The J Craig Venter Institute
 9712 Medical Center Drive
 Rockville, MD 20850

=head1 COPYRIGHT

Copyright (c) 2002, The Institute for Genomic Research. All Rights Reserved.

``
