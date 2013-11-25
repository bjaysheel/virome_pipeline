package Coati::ModulesFactory;
use strict;
use Coati::Logger;

# ------------------------------------------------------------
# Constructor
# ------------------------------------------------------------

sub new {
    my ($class,%arg) = @_;
    my $self = bless {}, ref($class) || $class;
    $self->{_logger} = Coati::Logger::get_logger(__PACKAGE__);
    
    $self->{_schema} = undef;
    $self->{_vendor} = undef;
    $self->{_package} = undef;
    $self->{_package_path} = undef;

    # default value of 'DB' required to maintain backwards compatibility
    $self->{_package_suffix} = 'DB';
    $self->{_args} = undef;

    $self->{_logger}->debug("Init $class");
    $self->_init(%arg);

    #check for proper module types.  Need at least a package name.
    #Need a schema if a vendor is specified.
    if(($self->{_package} eq "") || ($self->{_vendor} ne "" && ($self->{_schema} eq ""))){
	$self->{_logger}->logdie("Undefined package:$self->{_package} or vendor:$self->{_vendor} specified without schema:$self->{_schema}");
    }

    # JC 01/06/2005: This is an unusual way to implement a factory class, but we're stuck
    # with it until we're ready to give up backwards compatibility.
    return $self->createobj();
}

# ------------------------------------------------------------
# Public methods
# ------------------------------------------------------------

# Create a new object of the requested type based on the schema, vendor, package, 
# and package_path passed to the factory's constructor.  This method is a generalized 
# version of the old 'createobj' method.
# 
sub createobj {
    my ($self, @args) = @_;

    my($pkg, $pkgPath, $pkgSuffix, $vendor, $schema) = map { $self->{$_} } ('_package', '_package_path', '_package_suffix', '_vendor', '_schema');
    my $pkgPrefix = (defined($pkgPath) && ($pkgPath ne '')) ? "${pkgPath}::" : "";

    my $modules = [];

    # try three modules in turn, listed here from most specific to least specific

    push(@$modules, $pkgPrefix . $pkg . '::' . $vendor . $schema . $pkg . $pkgSuffix);
    push(@$modules, $pkgPrefix . $pkg . '::' . $schema . $pkg . $pkgSuffix);
    push(@$modules, $pkgPrefix . $pkg . '::' . $pkg . $pkgSuffix);

    $self->{_logger}->debug("Prefix: $pkgPrefix Package: $pkg Vendor: $vendor Schema: $schema Suffix: $pkgSuffix");

    my $args = $self->{'_args'};
    my @argArray = defined($args) ? @$args : ();
    my $result = undef;
    my $warnings = [];

    foreach my $module (@$modules) {
	$self->{_logger}->debug("Trying to instantiate object of type $module with constructor args=" . join(',', @argArray));

	eval "require $module";
	if ($@) {
	    my $copy = $@;
	    push(@$warnings, $copy) unless ($copy =~ /can\'t locate/i);
	} else {
	    eval {
		$result = $module->new(@argArray);
	    };
	    if ($@) {
		my $copy = $@;
		push(@$warnings, $copy);
	    }
	}

	if (defined($result)) {
	    $self->{_logger}->debug("Instantiated object of type $module with constructor args=" . join(',', @argArray));
	    last;
	}
    }

    if (!defined($result) || ($result == 1)) {
	my $msg = "Failed to create $pkg module for $vendor/$schema.  Nested errors follow:\n" . join("\n", @$warnings);
	$self->{_logger}->logdie($msg);
    }

    return $result;
}

# ------------------------------------------------------------
# Private methods
# ------------------------------------------------------------

sub _init {
    my ($self,%arg) = @_;
    
    foreach my $key (keys %arg) {
	$self->{_logger}->debug("Storing member variable $key as _$key=$arg{$key}");
        $self->{"_$key"} = $arg{$key}
    }
}

#################################

1;
