package Annotation::IdMapper;

=head1 NAME

Annotation::IdMapper.pm

=head1 VERSION

1.0

=head1 SYNOPSIS


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

new{}
_init{}
DESTROY{}
setOldIdN{}
setOldId{}
getOldIdN{}
getOldId{}
removeOldIdN{}
removeOldId{}
setNewIdN{}
setNewId{}
getNewId{}
getNewIdN{}
getNewId{}
removeNewIdN{}
removeNewId{}
setPairN{}
setPair{}
removePairN{}
removePair{}
setMapFileExtension{}
getMapFileExtension{}
setMapFilename{}
getMapFilename{}
verifyLookups{}
loadIdMappingLookup{}
loadIdMappingLookupFromFile{}
writeIdMappingFile{}


=over 4

=cut

use strict;
use Data::Dumper;
use Annotation::Logger;


my $logger = Annotation::Logger::get_logger("Logger::Annotation");

my $defaultExtension = 'idmap';

=item new()

B<Description:> Instantiate Annotation::IdMapper object

B<Parameters:> None

B<Returns:> reference to the Annotation::IdMapper object

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

  if (! exists $self->{'_extension'}){
      $self->{'_extension'} = $defaultExtension;
  }

  if ($logger->is_debug()){
      $logger->debug("Initialized '" . __PACKAGE__ . "' instance");
  }
}


=item DESTROY

B<Description:> Annotation::IdMapper class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  {
  my $self = shift;

  if ($logger->is_debug()){
      $logger->debug("Destroyed '" . __PACKAGE__ . "' instance");
  }

}

=item $obj->setOldIdN(old=>$oldId, new=>$newId)

B<Description:> Set old ID value for new ID

B<Parameters:> 

$oldId (scalar - string)
$newId (scalar - string)

B<Returns:> None

=cut

sub setOldIdN {

    my $self = shift;
    my (%args) = @_;
    if (!exists $args{'old'}){
	$logger->logdie("old was not defined");
    }
    if (!exists $args{'new'}){
	$logger->logdie("new was not defined");
    }

    $self->setOldId($args{'old'},$args{'new'});
}

=item $obj->setOldId($oldId,$newId)

B<Description:> Set old ID value for new ID

B<Parameters:> 

$oldId (scalar - string)
$newId (scalar - string)

B<Returns:> None

=cut

sub setOldId {

    my $self = shift;
    my ($old, $new) = @_;
    if (!defined($old)){
	$logger->logdie("old was not defined");
    }
    if (!defined($new)){
	$logger->logdie("new was not defined");
    }

    $self->{'_new2old'}->{$new} = $old;
    delete $self->{'_old2new'}->{$old};
    $self->{'_old2new'}->{$old} = $new;

}

=item $obj->getOldIdN($newId)

B<Description:> Get the old ID value for specified new ID value

B<Parameters:> 

$newId (scalar - string)

B<Returns:> $oldId (scalar - string)

=cut

sub getOldIdN {

    my $self = shift;
    my (%args) = @_;
    if (!exists $args{'new'}){
	$logger->logdie("new was not defined");
    }

    return $self->getOldId($args{'new'});

}

=item $obj->getOldId($newId)

B<Description:> Get the old ID value for specified new ID value

B<Parameters:> 

$newId (scalar - string)

B<Returns:> $oldId (scalar - string)

=cut

sub getOldId {

    my $self = shift;
    my ($new) = @_;
    if (!defined($new)){
	$logger->logdie("new was not defined");
    }

    if (! exists $self->{'_new2old'}->{$new}){
	$logger->warn("No corresponding old ID value exists for new ID value '$new'");
	return undef;
    } else {
	return $self->{'_new2old'}->{$new};
    }
}

=item $obj->removeOldIdN($oldId)

B<Description:> Remove the old ID new ID pair by specified old ID value

B<Parameters:> $oldId (scalar - string)

B<Returns:> None

=cut

sub removeOldIdN {

    my $self = shift;
    my (%args) = @_;
    if (!exists $args{'old'}){
	$logger->logdie("old was not defined");
    }

    $self->removeOldId($args{'old'});

}

=item $obj->removeOldId($oldId)

B<Description:> Remove the old ID new ID pair by specified old ID value

B<Parameters:> $oldId (scalar - string)

B<Returns:> None

=cut

sub removeOldId {

    my $self = shift;
    my ($old) = @_;
    if (!defined($old)){
	$logger->logdie("old was not defined");
    }

    if (! exists $self->{'_old2new'}->{$old}){
	$logger->warn("Attempting to remove a value from old2new that ".
		      "does not exist (old '$old')");
    } else {
	if (! exists $self->{'_new2old'}->{$self->{'_old2new'}->{$old}}) {
	    $logger->warning("Attemping to remove a value new2old that ".
			     "does not exist (new '$self->{'_old2new'}->{$old}')");
	}

	delete $self->{'_new2old'}->{$self->{'_old2new'}->{$old}};
	delete $self->{'_old2new'}->{$old};
    }
}


=item $obj->setNewIdN(old=>$oldId, new=>$newId)

B<Description:> Set new ID value for old ID

B<Parameters:> 

$oldId (scalar - string)
$newId (scalar - string)

B<Returns:> None

=cut

sub setNewIdN {

    my $self = shift;
    my (%args) = @_;
    if (!exists $args{'old'}){
	$logger->logdie("old was not defined");
    }
    if (!exists $args{'new'}){
	$logger->logdie("new was not defined");
    }

    $self->setNewId($args{'old'},$args{'new'});
}

=item $obj->setNewId($oldId,$newId)

B<Description:> Set new ID value for old ID

B<Parameters:> 

$oldId (scalar - string)
$newId (scalar - string)

B<Returns:> None

=cut

sub setNewId {

    my $self = shift;
    my ($old, $new) = @_;
    if (!defined($old)){
	$logger->logdie("old was not defined");
    }
    if (!defined($new)){
	$logger->logdie("new was not defined");
    }

    $self->{'_old2new'}->{$old} = $new;
    delete $self->{'_new2old'}->{$new};
    $self->{'_new2old'}->{$new} = $old;
}

=item $obj->getNewIdN($oldId)

B<Description:> Get the new ID value for specified old ID value

B<Parameters:> 

$oldId (scalar - string)

B<Returns:> $newId (scalar - string)

=cut

sub getNewIdN {

    my $self = shift;
    my (%args) = @_;
    if (!exists $args{'old'}){
	$logger->logdie("old was not defined");
    }

    return $self->getNewId($args{'old'});

}

=item $obj->getNewId($old)

B<Description:> Get the new ID value for specified old ID value

B<Parameters:> 

$newId (scalar - string)

B<Returns:> $newId (scalar - string)

=cut

sub getNewId {

    my $self = shift;
    my ($old) = @_;
    if (!defined($old)){
	$logger->logdie("old was not defined");
    }

    if (! exists $self->{'_old2new'}->{$old}){
	$logger->warn("No corresponding new ID value exists for old ID value '$old'");
	return undef;
    } else {
	return $self->{'_old2new'}->{$old};
    }
}

=item $obj->removeNewIdN($newIkd)

B<Description:> Remove the old ID new ID pair by specified new ID value

B<Parameters:> $newId (scalar - string)

B<Returns:> None

=cut

sub removeNewIdN {

    my $self = shift;
    my (%args) = @_;
    if (!exists $args{'new'}){
	$logger->logdie("new was not defined");
    }

    $self->removeNewId($args{'new'});

}

=item $obj->removeNewId($newId)

B<Description:> Remove the old ID new ID pair by specified new ID value

B<Parameters:> $newId (scalar - string)

B<Returns:> None

=cut

sub removeNewId {

    my $self = shift;
    my ($new) = @_;
    if (!defined($new)){
	$logger->logdie("new was not defined");
    }

    if (! exists $self->{'_new2old'}->{$new}){
	$logger->warn("Attempting to remove a value from new2old that ".
		      "does not exist (new '$new')");
    } else {
	if (! exists $self->{'_old2new'}->{$self->{'_new2old'}->{$new}}){
	    $logger->warning("Attemping to remove a value old2new that ".
			     "does not exist (new '$self->{'_new2old'}->{$new}')");
	}

	delete $self->{'_old2new'}->{$self->{'_new2old'}->{$new}};
	delete $self->{'_new2old'}->{$new};
    }
}


=item $obj->setPairN(old=>$oldId,new=>$newId)

B<Description:> Set old ID and new ID value pair

B<Parameters:> 

$oldId (scalar - string)
$newId (scalar - string)

B<Returns:> None

=cut

sub setPairN {

    my $self = shift;
    my (%args) = @_;

    if (! exists $args{'old'}){
	$logger->logdie("old was not defined");
    }
    if (! exists $args{'old'}){
	$logger->logdie("new was not defined");
    }
    
    $self->setPair($args{'old'}, $args{'new'});
}


=item $obj->setPair($oldId,$newId)

B<Description:> Set old ID and new ID value pair

B<Parameters:> 

$oldId (scalar - string)
$newId (scalar - string)

B<Returns:> None

=cut

sub setPair {

    my $self = shift;
    my ($old, $new) = @_;

    if (!defined($old)){
	$logger->logdie("old was not defined");
    }
    if (!defined($new)){
	$logger->logdie("new was not defined");
    }

    if (exists $self->{'_old2new'}->{$old}){
	$logger->warn("Deleting old '$old' new '$new' pair from old2new");
	delete $self->{'_old2new'}->{$old};
    }

    $self->{'_old2new'}->{$old} = $new;

    if (exists $self->{'_new2old'}->{$new}){
	$logger->warn("Deleting new '$new' old '$old'  pair from new2old");
	delete $self->{'_new2old'}->{$new};
    }

    $self->{'_new2old'}->{$new} = $old;
}


=item $obj->removePairN(old=>$oldId, new=>$newId)

B<Description:> Remove the old ID new ID pair

B<Parameters:> 

$oldId (scalar - string)
$newId (scalar - string)

B<Returns:> None

=cut

sub removePairN {

    my $self = shift;
    my (%args) = @_;
    if (!exists $args{'old'}){
	$logger->logdie("old was not defined");
    }
    if (!exists $args{'new'}){
	$logger->logdie("new was not defined");
    }

    $self->removePair($args{'old'}, $args{'new'});

}

=item $obj->removePair($oldId, $newId)

B<Description:> Remove the old ID new ID pair by specified new ID value

B<Parameters:> 

$oldId (scalar - string)
$newId (scalar - string)

B<Returns:> None

=cut

sub removePair {

    my $self = shift;
    my ($old, $new) = @_;
    if (!defined($old)){
	$logger->logdie("old was not defined");
    }
    if (!defined($new)){
	$logger->logdie("new was not defined");
    }

    if (! exists $self->{'_new2old'}->{$new}){
	$logger->logdie("Attempting to remove a value (new '$new') from new2old that ".
		      "does not exist (old '$old')");
    } else {
	if (! exists $self->{'_old2new'}->{$self->{'_new2old'}->{$new}}){
	    $logger->logdie("old '$self->{'_new2old'}->{$new}' does not exist in old2new");
	}
	if ($new ne $self->{'_old2new'}->{$old}){
	    $logger->logdie("new '$new' does not match value in old2new for old '$old'");
	}
    }

    if (! exists $self->{'_old2new'}->{$old}){
	$logger->logdie("Attempting to remove a value (old '$old') from old2new that ".
		      "does not exist (new '$new')");
    } else {
	if (! exists $self->{'_new2old'}->{$self->{'_old2new'}->{$old}}){
	    $logger->logdie("new '$self->{'_old2new'}->{$old}' does not exist in new2old");
	}
	if ($old ne $self->{'_new2old'}->{$new}){
	    $logger->logdie("old '$old' does not match value in new2old for new '$new'");
	}
    }

    delete $self->{'_old2new'}->{$old};
    delete $self->{'_new2old'}->{$new};
}

=item $obj->setMapFileExtension($ext)

B<Description:> Set the map filename extension

B<Parameters:> $ext (scalar - string)

B<Returns:> None

=cut

sub setMapFileExtension {

    my $self = shift;
    my ($ext) = @_;
    if (!defined($ext)){
	$logger->logdie("ext was not defined");
    }

    $self->{'_extension'} = $ext;
    if ($logger->is_debug()){
	$logger->debug("extension was set to '$ext'");
    }
}

=item $obj->getMapFileExtension()

B<Description:> Get the map filename extension

B<Parameters:> None

B<Returns:> $ext (scalar - string)

=cut

sub getMapFileExtension {

    my $self = shift;

    if (! exists $self->{'_extension'}){
	$self->{'_extension'} = $defaultExtension;
	$logger->warn("extension was not defined therefore set it to default ".
		      "value '$defaultExtension'");
    }

    return $self->{'_extension'};    
}

=item $obj->setMapFilename($name)

B<Description:> Set the map filename

B<Parameters:> $name (scalar - string)

B<Returns:> None

=cut

sub setMapFilename {

    my $self = shift;
    my ($name) = @_;
    if (!defined($name)){
	$logger->logdie("name was not defined");
    }

    $self->{'_filename'} = $name;

    if ($logger->is_debug()){
	$logger->debug("filename was set to '$name'");
    }
}

=item $obj->getMapFilename()

B<Description:> Get the map filename

B<Parameters:> None

B<Returns:> $name (scalar - string)

=cut

sub getMapFilename {

    my $self = shift;

    if (exists $self->{'_filename'}){
	return $self->{'_filename'};
    }

    $logger->warn("filename is not defined!");
    return undef;
    
}

=item $obj->verifyLookups()

B<Description:> Verify that the two identifier lookups are synchronized

B<Parameters:> None

B<Returns:> $boolean (scalar - unsigned integer) 0 - false, 1 - true

=cut

sub verifyLookups {

    my $self = shift;

    my $missingInOld=[];
    my $missingInNew=[];
    my $missingInOldCtr=0;
    my $missingInNewCtr=0;
    my $newCtr=0;
    my $oldCtr=0;
    my $errorCtr=0;

    foreach my $old (keys %{$self->{'_old2new'}}){
	$oldCtr++;
	my $new = $self->{'_old2new'}->{$old};
	if (!exists $self->{'_new2old'}->{$new}){
	    push(@{$missingInNew}, $new);
	    $missingInNewCtr++;
	}
    }

    if ($missingInNewCtr>0){
	$logger->fatal("The following '$missingInNewCtr' new ID values were ".
		       "missing in the new2old lookup:" . join("\n", @{$missingInNew}));
	$errorCtr++;
    }


    foreach my $new (keys %{$self->{'_new2old'}}){
	$newCtr++;
	my $old = $self->{'_new2old'}->{$new};
	if (!exists $self->{'_old2new'}->{$old}){
	    push(@{$missingInOld}, $old);
	    $missingInOldCtr++;
	}
    }

    if ($missingInOldCtr>0){
	$logger->fatal("The following '$missingInOldCtr' old ID values were ".
		       "missing in the old2new lookup:" . join("\n", @{$missingInOld}));
	$errorCtr++;
    }


    if ($errorCtr>0){
	$logger->fatal("Please view log file.  The identifier lookups were out of synch!");
	return 0;
    }

    return 1;    
}

=item $obj->writeIdMappingFile($filename)

B<Description:> Write the ID mapping file

B<Parameters:> $filename (scalar - string) optional

B<Returns:> None

=cut

sub writeIdMappingFile {

    my $self = shift;
    my ($filename) = @_;

    if (! $self->verifyLookups()){
	$logger->logdie("Some problem was detected with identifier lookups.");
    }

    if (!defined($filename)){
	$filename = $self->{'_filename'};
    }

    if (-e $filename){
	my $bakFile = $filename . '.' . $$ . '.bak';
	rename($filename, $bakFile);
	$logger->warn("file '$filename' was backed up to '$bakFile'");
    }

    ## Keep count of the number of mappings written to the ID mapping file.
    my $idCtr = 0;
    
    open (MAPPINGFILE, ">$filename") || $logger->logdie("Could not open file '$filename' for output: $!");

    my $old2new = $self->{'_old2new'};
    
    foreach my $oldId (keys %{$old2new} ) {
	
	my $newId = $old2new->{$oldId};
	
	print MAPPINGFILE "$oldId\t$newId\n";
	
	$idCtr++;
    }

    print "The number of mappings written to the ID mapping file '$filename' was: '$idCtr'\n";

}

=item $obj->loadIdMappingLookupN($directories, $infile)

B<Description:> Load ID pairs from ID map files

B<Parameters:> 

$directories (scalar - string) 
$infile (scalar - string) 

B<Returns:> None

=cut

sub loadIdMappingLookupN {

    my $self = shift;
    my (%args) = @_;
    $self->loadIdMappingLookup($args{'directories'}, $args{'infile'});
}


=item $obj->loadIdMappingLookup($directories, $infile)

B<Description:> Load ID pairs from ID map files

B<Parameters:> 

$directories (scalar - string) 
$infile (scalar - string) 

B<Returns:> None

=cut

sub loadIdMappingLookup {

    my $self = shift;
    my ($directories, $infile) = @_;

    ## Keep counts
    my $idCtr = 0;
    my $dirCtr = 0;
    my $fileCtr = 0;

    if ((!defined($infile)) && (!defined($directories))){
	$logger->logdie("Note that the user did not specify any directories ".
			       "nor input file that might contain input ID mappings.");
    }


    if (defined($infile)){
	$idCtr = $self->loadIdMappingLookupFromFile($infile);
    }

    my $ext = $self->getMapFileExtension();

    if (defined($directories)){
	## User did specify some value(s) for directories that may 
	## contain ID mapping files with file extension '.idmap'.
	    
	my @dirs = split(/,/,$directories);
	    


	my $didCtr=0;

	foreach my $directory ( @dirs ){
	    ## Process each directory one-by-one.
		
	    if (!-e $directory){
		$logger->warn("directory '$directory' does not exist");
		next;
	    }
	    if (!-d $directory){
		$logger->warn("directory '$directory' is not a regular directory");
		next;
	    }
	    if (!-r $directory){
		$logger->logdie("directory '$directory' does not have read ".
					 "permissions");
	    }
		
	    ## Keep count of the number of directories that were scanned 
	    ## for ID mapping files.
	    $dirCtr++;
		
	    opendir(THISDIR, "$directory") || $logger->logdie("Could not open directory '$directory':$!");
		
	    my @allfiles1 = grep {$_ ne '.' and $_ ne '..' } readdir THISDIR;
		
	    my @allfiles;
	    foreach my $file (@allfiles1){
		if (($file =~ /\S+\.$ext$/) || ($file =~ /\S+\.$ext\.gz$/) || ($file =~ /\S+\.$ext\.gzip$/)){
		    push(@allfiles, "$directory/$file");
		}
	    }

	    my $fileCount = scalar(@allfiles);
	    
	    if ($fileCount > 0){
		## There was at least one .idmap file in the directory.
		
		my $filelist = join(",", @allfiles);

		$didCtr += $self->loadIdMappingLookupFromFile($filelist);

		$fileCtr += scalar(@allfiles);
		
	    } else {
		$logger->warn("directory '$directory' did not have any ID ".
				       "mapping files with file extension '$ext'");
	    }
	}

	if ($didCtr>0){
	    $logger->warn("'$idCtr' mappings were loaded onto the ID mapping ".
				   "lookup. '$fileCtr' ID mapping files with extension ".
				   "'$ext' were read in from '$dirCtr' directories.");
	    $idCtr += $didCtr;
	}
	else {
	    $logger->warn("No ID mappings were loaded onto the ID mapping ".
				   "lookup. '$fileCtr' ID mapping files with extension ".
				   "'$ext' were read in from '$dirCtr' directories.");
	}
    }


    $logger->info("All ID mapping loading complete.\n".
			   "Number of directories scanned for ID mapping files with ".
			   "extension '$ext': '$dirCtr'\n".
			   "Number of ID mapping files read: '$fileCtr'\n".
			   "Number of ID mappings loaded into the ID mapping lookup: ".
			   "'$idCtr'");
}


sub loadIdMappingLookupFromFile {

    my $self = shift;
    my ($infile) = @_;
    if (!defined($infile)){
	$logger->logdie("The infile was not defined");
    }

    ## Keep counts
    my $idCtr = 0;
    my $fileCtr = 0;

    my @allfiles = split(/,/, $infile);
    
    my $fileCount = scalar(@allfiles);
    
    if ($fileCount < 1){
	$logger->logdie("There were no ID mapping files to read.  ".
				 "Input was infile '$infile'");
    }

    ## There was at least one .idmap file in the directory.
	
    my $ext = $self->getMapFileExtension();

    foreach my $file (@allfiles){
	    
	if (!-e $file){
	    $logger->logdie("file '$file' does not exist");
	}
	if (!-r $file){
	    $logger->logdie("file '$file' does not have read permissions");
	}
	if (!-f $file){
	    $logger->logdie("file '$file' is not a regular file");
	}
	if (-z $file){
	    $logger->logdie("file '$file' has zero content.  No ID mappings ".
				     "to read.");
	}
	if ($file =~ /\.$ext$/){
	    $logger->debug("will read from file '$file'");
	}
	elsif ($file =~ /\.gz$|\.gzip$/){
	    $logger->debug("will read from file '$file'");
	}		
	else {
	    $logger->logdie("file '$file' has neither .${ext}, .${ext}.gz nor ".
				     ".${ext}.gzip extension");
	}
	    
	## Keep count of the number of ID mapping files that were read.
	$fileCtr++;
	    
	my $fh;
	if ($file =~ /\.gz$|\.gzip$/) {
	    open ($fh, "<:gzip", "$file") || $logger->logdie("Could not open ID mapping file '$file' for input: $!");
	}
	else {
	    open ($fh, "<$file") || $logger->logdie("Could not open ID mapping file '$file' for input: $!");
	}

	my $lineCtr=0;
	my $blankLineCtr=0;
	my $commentedLineCtr=0;

	while (my $line = <$fh>){

	    chomp($line);
	    $lineCtr++;

	    if ($line =~ /^\s*$/){
		$blankLineCtr++;
		next;
	    }
	    if ($line =~ /^\#$/){
		$commentedLineCtr++;
		next;
	    }

	    my ($oldid, $newid) = split(/\s+/, $line);
		
	    if ( exists $self->{'_old2new'}->{$oldid}){
		$logger->warn("'$oldid' already existed in the ID mapping ".
				       "lookup with new ID '$newid'.  Was reading ID ".
				       "mapping file '$file'.");
	    }
		
	    $self->{'_old2new'}->{$oldid} = $newid;
	    $self->{'_new2old'}->{$newid} = $oldid;
		
	    ## Keep count of the number of mappings that are loaded onto the lookup.
	    $idCtr++;
	}

	if ($logger->is_debug()){
	    $logger->debug("Read '$lineCtr' lines from file '$file'");
	    if ($blankLineCtr>0){
		$logger->debug("Encountered '$blankLineCtr' blank lines");
	    }
	    if ($blankLineCtr>0){
		$logger->debug("Encountered '$commentedLineCtr' commented lines");
	    }	    
	}
    }

    if ($idCtr>0){
	$logger->warn("'$idCtr' mappings were loaded onto the ID mapping ".
			       "lookup.  '$fileCtr' ID mapping files with extension ".
			       "'$ext' were read.");
    } else {
	$logger->warn("No ID mappings were loaded onto the ID mapping lookup. ".
			       "'$fileCtr' ID mapping files with extension '$ext' were ".
			       "read.");
    }

    $logger->info("Number of ID mapping files read: '$fileCtr'\n".
			   "Number of ID mappings loaded into the ID mapping lookup: ".
			   "'$idCtr'");
    
    return $idCtr;
}


1; ## End of module
