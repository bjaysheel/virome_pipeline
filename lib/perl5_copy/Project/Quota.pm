package Project::Quota;

=head1 NAME

Project::Quota.pm

=head1 VERSION

1.0

=head1 SYNOPSIS

Coming soon!

=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

new{}
_init{}
DESTROY{}
getQuota{}
getCurrentUsage{}
getPercentRemaining{}
getKBRemaining{}
getProjectName{}
_retrieveQuota{}
updateStatistics{}
_calculatePercentRemaining{}
_haveAtleastPercent{}
haveAtleast5Percent{}
haveAtleast10Percent{}
haveAtleast15Percent{}
haveAtleast20Percent{}
_haveAtleastKB{}
haveAtleast20KB{}

=over 4

=cut

use strict;
use Annotation::Logger;
use Carp;
use File::Basename;
use Data::Dumper;
use constant GETQUOTA => '/usr/local/common/getquota';

use constant TRUE  => 1;
use constant FALSE => 0;

my $logger = Annotation::Logger::get_logger("Logger::Annotation");


=item new()

B<Description:> Instantiate Project::Quota object

B<Parameters:> None

B<Returns:> reference to the Project::Quota object

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

      if ($key eq 'project'){

	  if (-e $args{$key}){

	      if (-d $args{$key}){

		  ## The user correctly specified a path 
		  ## to some project directory
		  $self->{'_project_path'} = $args{$key};
		  
		  $self->{'_project_name'} = File::Basename::basename($args{$key});
		  
	      } else {

		  $logger->logdie("project space '$args{$key}' is not a directory!");
	      }
	  } else {

	      $logger->logdie("project space '$args{$key}' does not exist!");
	  }
      } else {
	  $self->{"_$key"} = $args{$key};
      }    
  }

}


=item DESTROY

B<Description:> Project::Quota class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  {
  my $self = shift;

}

sub _getInfo {

    my $self = shift;

    $self->_retrieveQuota();

    $self->_calculatePercentRemaining();
    
    $self->{_data_retrieved} = TRUE;
}

sub _dataNotRetrieved {

    my $self = shift;
    if (( exists $self->{_data_retrieved}) &&
	( defined($self->{_data_retrieved})) &&
	( $self->{_data_retrieved} == TRUE)){
	return FALSE;
    }

    return TRUE;
}


=item $obj->getQuota()

B<Description:> Retrieve the project space quota (allocation)

B<Parameters:> None

B<Returns:>  $quota (scalar - unsigned integer)

=cut

sub getQuota {

  my $self = shift;

  if ($self->_dataNotRetrieved()){
      $self->_getInfo();
  }

  if (! exists $self->{'_allocation'}){

      $logger->logdie("_allocation is not defined!");
  }

  return $self->{'_allocation'};

}

=item $obj->getCurrentUsage()

B<Description:> Retrieve the current usage

B<Parameters:> None

B<Returns:>  $used (scalar - unsigned integer)

=cut

sub getCurrentUsage {

  my $self = shift;

  if ($self->_dataNotRetrieved()){
      $self->_getInfo();
  }

  if (! exists $self->{'_used'}){

      $logger->logdie("_used is not defined!");
  }

  return $self->{'_used'};

}

=item $obj->getPercentRemaining()

B<Description:> Retrieve the percent of space remaining

B<Parameters:> None

B<Returns:>  $percent (scalar - unsigned float)

=cut

sub getPercentRemaining {

  my $self = shift;

  if ($self->_dataNotRetrieved()){
      $self->_getInfo();
  }

  if (! exists $self->{'_percent_remaining'}){

      $self->_calculatePercentRemaining();

      if (! exists $self->{'_percent_remaining'}){

	  $logger->logdie("_percent_remaining is not defined!");
      }
  }

  return $self->{'_percent_remaining'};

}



=item $obj->getKBRemaining()

B<Description:> Retrieve the amount of space remaining in kilobytes

B<Parameters:> None

B<Returns:>  $space (scalar - unsigned integer)

=cut

sub getKBRemaining {

  my $self = shift;

  if ($self->_dataNotRetrieved()){
      $self->_getInfo();
  }


  if (! exists $self->{'_kb_remaining'}){

      $logger->logdie("_kb_remaining is not defined!");
  }
  
  return $self->{'_kb_remaining'};

}


=item $obj->getProjectName()

B<Description:> Retrieve the project_name

B<Parameters:> None

B<Returns:>  $name (scalar - string)

=cut

sub getProjectName {

  my $self = shift;

  if (! exists $self->{'_project_name'}){

      $self->{'_project_name'} = File::Basename::basename($self->{'_project_path'});

      if (! exists $self->{'_project_name'}){

	  $logger->logdie("_project_name is not defined!");
      }
  }

  return $self->{'_project_name'};

}


=item $obj->_retrieveQuota()

B<Description:> Retrieve the quota info from the system

B<Parameters:> None

B<Returns:>  None

=cut

sub _retrieveQuota {

    my $self = shift;

    if (! exists $self->{'_project_path'}){

	$logger->logdie("_project_path does not exist!");
    }
    
    my $path = $self->{'_project_path'};


    if (!-e GETQUOTA){
	$logger->logdie(GETQUOTA . " does not exist!");
    }
    if (!-x GETQUOTA){
	$logger->logdie(GETQUOTA . " is not executable!");
    }

    my $ex = GETQUOTA . " -N $path";

    my $res;

    eval {
	$res = qx($ex);
    };

    if ($@){
	die "Caught some exception while attempting '$ex': $! $@";
    }

    chomp $res;

    $res =~ s/\s+$//;

    ($self->{'_allocation'}, $self->{'_used'}) = split(/\s+/,$res);

    $self->{'_kb_remaining'} = $self->{'_allocation'} - $self->{'_used'};
}

=item $obj->updateStatistics()

B<Description:> Re-retrieve the quota info from the system

B<Parameters:> None

B<Returns:>  None

=cut

sub updateStatistics {

    my $self = shift;

    $self->_retrieveQuota();
}


=item $obj->_calculatePercentRemaining()

B<Description:> Calculate and store the percent of space remaining

B<Parameters:> None

B<Returns:>  None

=cut

sub _calculatePercentRemaining {

    my $self = shift;

    if (! exists $self->{'_used'}){

	$logger->logdie("_used is not defined!");
    }
    
    if (! exists $self->{'_allocation'}){

	$logger->logdie("_allocation is not defined!");
    }

    my $used = $self->{'_used'};

    my $allo = $self->{'_allocation'};

    my $percentRemaining = ($used * 100)/$allo;

    $self->{'_percent_used'} = $percentRemaining;

    $self->{'_percent_remaining'} = 100 - $self->{_percent_used};

}



=item $obj->_haveAtleastPercent()

B<Description:> Determine whether the project space has at least some percent amount of space

B<Parameters:> $int (scalar - unsigned integer)

B<Returns:>  $boolean (scalar - 0 false, 1 true)

=cut

sub _haveAtleastPercent {

  my $self = shift;

  my ($percent) = @_;

  if (!defined($percent)){

      $logger->logdie("percent was not defined");
  }

  if (! exists $self->{'_percent_remaining'}){

      $self->_calculatePercentRemaining();

      if (! exists $self->{'_percent_remaining'}){

	  $logger->logdie("_percent_remaining is not defined!");
      }
  }

  if ($self->{'_percent_remaining'} > $percent){

      return 1;
  }
  
  return 0;

}


=item $obj->haveAtleast5Percent()

B<Description:> Determine whether the project space has at least 5 percent of space remaining

B<Parameters:> None

B<Returns:>  $boolean (scalar - 0 false, 1 true)

=cut

sub haveAtleast5Percent {

  my $self = shift;

  if ($self->_dataNotRetrieved()){
      $self->_getInfo();
  }

  return $self->_haveAtleastPercent(5);

}

=item $obj->haveAtleast10Percent()

B<Description:> Determine whether the project space has at least 10 percent of space remaining

B<Parameters:> None

B<Returns:>  $boolean (scalar - 0 false, 1 true)

=cut

sub haveAtleast10Percent {

  my $self = shift;

  if ($self->_dataNotRetrieved()){
      $self->_getInfo();
  }

  return $self->_haveAtleastPercent(10);

}

=item $obj->haveAtleast15Percent()

B<Description:> Determine whether the project space has at least 15 percent of space remaining

B<Parameters:> None

B<Returns:>  $boolean (scalar - 0 false, 1 true)

=cut

sub haveAtleast15Percent {

  my $self = shift;

  if ($self->_dataNotRetrieved()){
      $self->_getInfo();
  }

  return $self->_haveAtleastPercent(15);

}

=item $obj->haveAtleast20Percent()

B<Description:> Determine whether the project space has at least 20 percent of space remaining

B<Parameters:> None

B<Returns:>  $boolean (scalar - 0 false, 1 true)

=cut

sub haveAtleast20Percent {

  my $self = shift;

  if ($self->_dataNotRetrieved()){
      $self->_getInfo();
  }

  return $self->_haveAtleastPercent(20);

}


=item $obj->_haveAtleastKB()

B<Description:> Determine whether the project space has at least some amount of space in kilobytes

B<Parameters:> $kb (scalar - unsigned integer)

B<Returns:>  $boolean (scalar - 0 false, 1 true)

=cut

sub _haveAtleastKB {

  my $self = shift;

  my ($kb) = @_;

  if (!defined($kb)){

      $logger->logdie("kb was not defined");
  }

  if (! exists $self->{'_kb_remaining'}){

      $self->{'_kb_remaining'} = $self->{'_allocation'} - $self->{'_used'};

      if (! exists $self->{'_kb_remaining'}){
	  
	  $logger->logdie("_kb_remaining is not defined!");
      }
  }

  if ($self->{'_kb_remaining'} > $kb){

      return 1;
  }
  
  return 0;

}

=item $obj->haveAtleast20KB()

B<Description:> Determine whether the project space has at least 20 kilobytes of space remaining

B<Parameters:> None

B<Returns:>  $boolean (scalar - 0 false, 1 true)

=cut

sub haveAtleast20KB {

  my $self = shift;

  if ($self->_dataNotRetrieved()){
      $self->_getInfo();
  }

  return $self->_haveAtleastKB(20);

}


sub printUserQuota {

    my $self = shift;
    my $dir = $self->_getDir(@_);
    
    my $ex = "getquota -Q -U -G $dir";
    my $results = qx($ex);

    my $ofh = $self->_getOutputStream(@_);
    my $date = localtime();
    print $ofh "At '$date' $ex:\n";
    print $ofh $results;
}

sub _getDir {

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
	return TRUE;
    }
    return FALSE;
}

1==1; ## end of module
