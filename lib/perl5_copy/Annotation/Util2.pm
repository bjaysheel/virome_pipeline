package Annotation::Util2;

=head1 NAME

Annotation::Util2.pm

=head1 VERSION

1.0

=head1 SYNOPSIS


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS

checkInputFileStatus{}
getInputFileHandle{}
getOutputFileHandle{}
checkInputDirectoryStatus{}
removeControlCharacters{}
getFileContentsArrayRef{}
removeControlCharacters{}

=over 4

=cut

use strict;
use Annotation::Logger;
use Carp;
use Data::Dumper;

my $logger = Annotation::Logger::get_logger("Logger::Annotation");


=item new()

B<Description:> Instantiate Annotation::Util2 object

B<Parameters:> None

B<Returns:> reference to the Annotation::Util2 object

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
}


=item DESTROY

B<Description:> Annotation::Util2 class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  {
  my $self = shift;

}

=item $obj->checkInputDataFile($infile)

B<Description:> Check whether file exists, has read permissions, has content, is a regular file and return true if all true

B<Parameters:> $infile (scalar)

B<Returns:>  0 for false, 1 for true (scalar - boolean)

=cut

sub checkInputFileStatus {

  my ($file) = @_;

  if (!defined($file)) {
      
    confess ("file was not defined");
  }

  if (!-e $file) {
    $logger->fatal("file '$file' does not exist");
    return 0;
  }

  if (!-r $file ) {
    $logger->fatal("file '$file' does not have read permissions");
    return 0;
  }

  if (!-f $file) {
    $logger->fatal("file '$file' is not a regular file");
    return 0;
  }

  if (!-s $file) {
    $logger->fatal("file '$file' did not have any content");
    return 0;
  }

  return 1;
}

=item $obj->getInputFileHandle($file)

B<Description:> Retrieve a file handle in read mode

B<Parameters:> $file (scalar - string)

B<Returns:> $ifh (input file handle)

=cut

sub getInputFileHandle {

  my ($file) = @_;
  if (!defined($file)) {
    $logger->logdie("file was not defined");
  }

  if (! &checkInputFileStatus($file)){
    $logger->logdie("There was a problem with the ".
		    "input file '$file'");
  }

  my $ifh;

  open ($ifh, "<$file") || $logger->logdie("Could not open file '$file' in read mode: $!");

  return $ifh;

}

=item $obj->getOutputFileHandle($file)

B<Description:> Retrieve a file handle in write mode

B<Parameters:> $file (scalar - string)

B<Returns:> $ofh (output file handle)

=cut

sub getOutputFileHandle {

  my ($file) = @_;
  if (!defined($file)) {
      confess "file was not defined";
    $logger->logdie("file was not defined");
  }

  my $ofh;

  open ($ofh, ">$file") || $logger->logdie("Could not open file '$file' in write mode: $!");

  return $ofh;
}

=item $obj->getOutputFileHandleForAppend($file)

B<Description:> Retrieve a file handle in append mode

B<Parameters:> $file (scalar - string)

B<Returns:> $ofh (output file handle)

=cut

sub getOutputFileHandleForAppend {

  my ($file) = @_;
  if (!defined($file)) {
    $logger->logdie("file was not defined");
  }

  my $ofh;

  open ($ofh, ">>$file") || $logger->logdie("Could not open file '$file' in write mode: $!");

  return $ofh;
}


=item $obj->checkInputDirectoryStatus($dir)

B<Description:> Check the input directory status: verify that exists, has read permissions, is a directory, contains content.

B<Parameters:> $dir (scalar - string)

B<Returns:> 0 for false, 1 for true (scalar - boolean)

=cut

sub checkInputDirectoryStatus {

  my ($dir) = @_;

  my $retval=1;

  if (!defined($dir)) {
    $logger->logdie("dir was not defined");
    $retval = 0;
  }
  if (!-e $dir) {
    $logger->logdie("directory '$dir' does not exist");
    $retval = 0;
  }
  if (!-r $dir ) {
    $logger->logdie("directory '$dir' does not have read permissions");
    $retval = 0;
  }
  if (!-d $dir) {
    $logger->logdie("'$dir' is not a directory");
    $retval = 0;
  }
  if (!-s $dir) {
    $logger->logdie("directory '$dir' did not have any content");
    $retval = 0;
  }

  return $retval;
}

=item $obj->removeControlCharacters($line)

B<Description:> Remove control characters and Microsoft DOS escape characters

B<Parameters:> $line (scalar - string)

B<Returns:> $line (scalar - string)

=cut

sub removeControlCharacters {

  my ($line) = @_;

  if (!defined($line)) {

    $logger->warn("line was not defined");

    return undef;

  } else {

    $line =~ tr/\t\n\000-\037\177-\377/\t\n/d; # remove cntrls

    return $line;
  }
}

=item $obj->getFileContentsArrayRef($file)

B<Description:> Retrieve the contents of specified file and return reference to array containing said contents

B<Parameters:> $file (scalar - string) filename

B<Returns:> $arrayRef (reference to array) the contents of the file (new-line separated)

=cut

sub getFileContentsArrayRef {

    my ($file) = @_;
    if (!defined($file)){
	$logger->logdie("file was not defined");
    }


    open (INFILE, "<$file") || $logger->logdie("Could not open file '$file' in read mode:$!");
#    open (INFILE, "<$file") || confess ("Could not open file '$file' in read mode:$!");
    my @contents = <INFILE>;
    chomp(@contents);
    return \@contents;

}

=item $obj->getFileList(dir=>$dir, extension=>$extension)

B<Description:> Retrieve a listing of files with specified file extension in the specified directory

B<Parameters:> 

$dir (scalar - string) directory name
$extension (scalar - string) file extension

B<Returns:> $arrayRef (reference to array) listing of all qualified files (new-line separated)

=cut

sub getFileList {

    my (%args) = @_;

    if (! exists $args{'dir'}){
	$logger->logdie("dir was not defined");
    }

    my $dir = $args{'dir'};
    my $ext;

    if ( exists $args{'extension'}){
	$ext = $args{'extension'};
    }

    my $xstring = "find $dir ";
    if (defined($ext)){
	$xstring .= "-name '*.$ext'";
    }

#    die "$xstring";
    my @files = qx($xstring);
    chomp @files;

    if (0){
	opendir(INDIR, "<$args{'dir'}") || $logger->logdie("Could not open directory '$args{'dir'}' in read mode:$!");
	
	my @files;
	
	if ( exists $args{'extension'}){
	    @files = grep { /^\./ && /$args{'extension'}$/ && -f $_ } readdir(INDIR);
	} else {
	    @files = grep { /^\./ && -f $_ } readdir(INDIR);
	}

	closedir INDIR;
	
	chomp(@files);
    }
	
    return \@files;
    
}

=item $obj->removeControlCharacters($text)

B<Description:> Remove control characters from the string

B<Parameters:> $text (scalar - string)

B<Returns:> $text (scalar - string) cleaned string

=cut
sub removeControlCharacters {

    my ($text) = @_;

    $text =~ tr/\t\n\000-\037\177-\377/\t\n/d;
    
    return $text;
}


sub isInputFileQualified {

    my ($file) =@_;

    if (!defined($file)){
	$logger->logdie("file was not defined");
    }

    if (!-e $file){
	$logger->warn("file '$file' does not exist");
	return 0;
    }
    if (!-r $file){
	$logger->warn("file '$file' does not have read permissions");
	return 0;
    }
    if (!-s $file){
	$logger->warn("file '$file' does not have any content");
	return 0;
    }
    if (!-s $file){
	$logger->warn("file '$file' does not have any content");
	return 0;
    }
    return 1;
}

sub checkInputFileStatus {

    my ($file) = @_;
    
    my $retval=1;

    if (!-e $file){
	print STDERR "file '$file' does not exist\n";
	$retval=0;
    }
    if (!-f $file){
	print STDERR "file '$file' is not a regular file\n";
	$retval=0;
    }
    if (!-r $file){
	print STDERR "file '$file' does not have read permissions\n";
	$retval=0;
    }
    if (!-s $file){
	print STDERR "file '$file' does not have any content\n";
	$retval=0;
    }

    return $retval;
}

sub getListOfFilesInDirectory {

    my ($dir) = @_;

    opendir(INDIR, "$dir") || confess "Could not open directory '$dir' in read mode:$!";

    my @files = readdir(INDIR);

    closedir(INDIR);

#    print Dumper \@files;die;

    return \@files;
}

sub getListOfFilesUnderDirectory {

    my ($dir) = @_;

    my $ex = "find $dir -type f";

    my @files = qx($ex);

    chomp @files;

#    print Dumper \@files;die;
    return \@files;
}


sub backupFile {

    my ($file) = @_;

    my $filebak = $file . '.bak';

    copy($file, $filebak) || confess "Could not backup file '$file' to '$filebak'";

}



1; ## End of module
