package System::StatusChecker;

=head1 NAME

System::StatusChecker.pm

=head1 VERSION

1.0

=head1 SYNOPSIS

Coming soon!

=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

new
_init
DESTROY
check
=over 4

=cut

use strict;
use Carp;
use Data::Dumper;
use Project::Quota;

use constant TRUE  => 1;
use constant FALSE => 0;

use constant DEFAULT_SCRATCH => '/usr/local/scratch/';

=item new()

B<Description:> Instantiate System::StatusChecker object

B<Parameters:> None

B<Returns:> reference to the System::StatusChecker object

=cut

sub new  {

    my $class = shift;

    my $self = {};

    bless $self, $class;

    $self->_init(@_);

    return $self;
}

=item $self->_init(%args)

B<Description:> Typical Perl init() method

B<Parameters:> %args

B<Returns:> None

=cut

sub _init {

    my $self = shift;

    my (%args) = @_;

    foreach my $key (keys %args ) {
	$self->{"_$key"} = $args{$key};
    }    
    

    $self->_initQuotaUtil();

    return $self;
}

sub _initQuotaUtil {

    my $self = shift;

    my $quotaUtil = new Project::Quota(project_path=>$self->{_project_path});
    if (!defined($quotaUtil)){
	confess "Could not instantiate Project::Quota";
    }

    $self->{_quota_util} = $quotaUtil;
}


=item DESTROY

B<Description:> System::StatusChecker class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  {

    my $self = shift;
}

=item $obj->check()

B<Description:> Perform required system checks

B<Parameters:> None

B<Returns:>  None

=cut

sub check {

    my $self = shift;


    $self->_snapShotDirectory(@_);

    $self->_checkScratchVolume(@_);

    $self->{_quota_util}->printUserQuota(dir=>'/usr/local/scratch/',
					 append=>$self->{_append},
					 outfile=>$self->{_outfile});
}

sub _snapShotDirectory {

    my $self = shift;

    my $dir = $self->_getDirectory(@_);

    my $ofh = $self->_getOutputStream(@_);

    my $ex = "ls -ltr $dir";
    my $results = qx($ex);

    my $date = localtime();
    print $ofh "At '$date' $ex:\n";
    print $ofh $results;

}

sub _checkScratchVolume {

    my $self = shift;

    my $ofh = $self->_getOutputStream(@_);
   
    my $scratch = $self->_getScratch(@_);

    my $ex = "df -h $scratch";
    my $results = qx($ex);

    my $date = localtime();
    print $ofh "At '$date' $ex:\n";
    print $ofh $results;

}

sub _getDirectory {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{dir}) && (defined($args{dir}))){

	$self->{_dir} = $args{dir};

    } elsif (( exists $self->{_dir}) && (defined($self->{_dir}))){

	## okay
    } else {
	confess "directory was not defined";
    }

    return $self->{_dir};
}

sub _getScratch {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{scratch}) && (defined($args{scratch}))){

	$self->{_scratch} = $args{scratch};

    } elsif (( exists $self->{_scratch}) && (defined($self->{_scratch}))){

	## okay
    } else {
	$self->{_scratch} = DEFAULT_SCRATCH;
    }

    return $self->{_scratch};
}
	
sub _getOutputStream {

    my $self = shift;
    my (%args) = @_;

    my $ofh;

    my $appendMode = $self->_getAppendMode(@_);

    if (( exists $args{outfile}) && (defined($args{outfile}))){

	$self->{_outfile} = $args{outfile};
	
	if ($appendMode){
	    open($ofh, ">>$self->{_outfile}") || confess "Could not open output file '$self->{_outfile}' in append mode: $!";
	} else {
	    open($ofh, ">$self->{_outfile}") || confess "Could not open output file '$self->{_outfile}' in write mode: $!";
	}

    } elsif (( exists $self->{_outfile}) && (defined($self->{_outfile}))){

	if ($appendMode){
	    open($ofh, ">>$self->{_outfile}") || confess "Could not open output file '$self->{_outfile}' in append mode: $!";
	} else {
	    open($ofh, ">$self->{_outfile}") || confess "Could not open output file '$self->{_outfile}' in write mode: $!";
	}

    } else {
	$ofh = \*STDOUT;
    }
    

    $self->{_ofh} = $ofh;
    return $ofh;
}
	
sub _getAppendMode {

    my $self = shift;

    my (%args) = @_;

    if (( exists $args{append}) && (defined($args{append})) && ($args{append} == TRUE)){
	$self->{_append} = $args{append};
	return TRUE;
    } elsif (( exists $self->{_append}) && (defined($self->{_append})) && ($self->{_append} == TRUE)){
	return TRUE;
    } else {
	return FALSE;
    }
}


1==1; ## end of module
