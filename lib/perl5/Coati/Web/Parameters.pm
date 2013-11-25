package Coati::Web::Parameters;

=head1 NAME

Coati::Web::Parameters

=head1 VERSION

    This document refers to version 1.0 of URL.pm, released MMMM, DD, YYYY.

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

our @EXPORT = qw(
&new 
&set
&get
);

use vars qw(@ISA $DEBUG);

$DEBUG = 0;

use strict;
use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser set_message);
use Coati::Logger;

sub new {
    my $classname = shift;
    my $self = {};
    bless($self,$classname); 
    #
    #User configurable options
    $self->{USE_COOKIE} = 1;
    $self->{COOKIE_NAME} = "CoatiDefault";
    $self->{_logger} = Coati::Logger::get_logger(__PACKAGE__);
    $self->{_logger}->debug("Init $classname") if $self->{_logger}->is_debug;
    $self->_init(@_); 
    if($self->{force_login}){
	$self->check_login();
    }
    return $self;
}

sub _init {
    my $self = shift;
    if(@_){
	my %arg = @_;
	foreach my $key (keys %arg) {
	    $self->{_logger}->debug("Storing member variable $key as $key=$arg{$key}") if $self->{_logger}->is_debug;
	    $self->{$key} = $arg{$key}
	}
    }
}

sub get {
    my $self = shift;
    my $key = shift;
    my %cvals = CGI::cookie($self->{COOKIE_NAME});
    $self->{_logger}->debug("Getting cookie value $key=$cvals{$key} from $self->{COOKIE_NAME}") if $self->{_logger}->is_debug;
    return $cvals{$key};
}

sub set {
    my $self = shift;
    my %cvals = CGI::cookie($self->{COOKIE_NAME});
    my $expires = "";
    if(scalar(@_) == 3){
	my($key,$value) = @_;
	$self->{_logger}->debug("Setting cookie param $key=$value") if($self->{_logger}->is_debug);
	if($key =~ /expires/g) {
	    $expires = $value;
	}
	$cvals{$key} = $value;
    }
    else{
	my(%pairs) = @_;
        foreach my $key (keys %pairs){
	    $self->{_logger}->debug("Setting cookie param $key=$pairs{$key}") if($self->{_logger}->is_debug);
	    if($key =~ /expires/g) {
		$expires = $pairs{$key};
	    }
            $cvals{$key} = $pairs{$key};
        }
    }
    $self->{_logger}->debug("Writing cookie $self->{COOKIE_NAME} with ".scalar(keys %cvals)." values") if($self->{_logger}->is_debug);
    return CGI::cookie(-name=>$self->{COOKIE_NAME},
		       -value=>\%cvals,
		       -expires=>$expires
		       );
}

sub set_null {
    my $self = shift;
    $self->{_logger}->debug("Setting null cookie") if($self->{_logger}->is_debug);
    return CGI::cookie(-name=>$self->{COOKIE_NAME},
		       -value=>{});
}

sub check_login{
    my $self = shift;
    my @missingparams;
    foreach my $param (@{$self->{force_login}}){
	if(! CGI::param($param)){
	    $self->{_logger}->debug("Required CGI param $param is missing") if($self->{_logger}->is_debug);
	    push @missingparams,$param;
	}
    }
    if(scalar(@missingparams)>0){
	die "Missing parameters ",join(',',@missingparams),"%%Invalid login%%The login parameters are not valid\n";
    }
}

sub import_parameters{
    my $self = shift;
    my %cvals = CGI::cookie($self->{COOKIE_NAME});
    foreach my $cookie_parm (keys %cvals){
	$self->{_logger}->debug("Setting CGI param $cookie_parm=$cvals{$cookie_parm} from cookie $self->{COOKIE_NAME}") if($self->{_logger}->is_debug);
	CGI::param(-name=>$cookie_parm,-value=>$cvals{$cookie_parm});
      }
}

1;
