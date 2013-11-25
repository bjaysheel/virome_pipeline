#!/usr/local/bin/perl
=head1	NAME

addCommentToBsml.pl - Add a comment to the BSML file

=head1	SYNOPSIS

USAGE: addCommentToBsml.pl
		--bsmlfile=/path/to/file.bsml
		--comment="some comment"
                [
		--logfile=/path/to/file.log
                --location=top
                --outfile=/path/to/outfile.bsml
                --disable=1
          	]

=head1	OPTIONS

B<--bsmlfile>
	BSML file into which the comment should be inserted.

B<--comment>
	The comment that will be inserted into the BSML file.

B<--logfile>
	Output Log4perl logfile.

B<--location>
	Location where the comment will be inserted.  Options are 'top' or 'bottom' with default 'bottom'.

B<--outfile>
	Name of the new output BSML file that will contain the comment.
        If not specified, the --bsmlfile will obtain the comment and the
        original BSML file will be saved with the same filename plus
        filename extension of .orig.

B<--disable>
	If specified as 1, will not insert comment and just exit(0).  Added this to support toggle during
        legacy2bsml ergatis-workflow component execution.

B<--debug_level>
	Log4perl debug level.  Use a large number to turn on verbose debugging

B<--help,-h>
	Print help

=head1	DESCRIPTION

This script will insert a comment to the top or bottom of a BSML file.
Note, another method considered for inserting these comments into 
the BSML file is by enhancing the BSML API to support the insertion
of comments into the BSML::BsmlDoc object.  While I might eventually
implement such support, this method implemented here will continue to
be a useful means to add comments and meta comments as part of a 
post-process execution.

This was implemented primarily to support the insertion of the
command-line invocation used to generate the original BSML file.

One might also consider inserting auxiliary post-process information
like BSML DTD validation invocation related information.

I did consider using a Perl Tie::File approach, however decided to
go ahead with just streaming the contents of the files instead.


=head1	INPUT

The first input is a BSML file.
The second input is the comment.
The third input (optional) is the location in the BSML file where the comment will be inserted.
The forth input (optional) is the name of the output BSML file that will contain the comment.

=head1	OUTPUT

The primary output is the BSML file with the inserted comment.
The secondary output is the Log4perl logfile.

=head1	AUTHOR

   Jay Sundaram
   sundaram@jcvi.org

=cut

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use File::Copy;
use File::Basename;
use Annotation::Util2;
use Annotation::Logger;

## Do not buffer output stream
$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($bsmlfile, $logfile, $comment, $debug_level, $help, $location, $man, $outfile, $disable);

my $results = GetOptions (
			  'debug_level=s'   => \$debug_level,
			  'bsmlfile=s'      => \$bsmlfile,
			  'help|h'          => \$help,
			  'logfile=s'       => \$logfile,
			  'man|m'           => \$man,
			  'comment=s'       => \$comment,
			  'location=s'      => \$location,
			  'outfile=s'       => \$outfile,
			  'disable=s'       => \$disable,
			  );

if ($disable == 1){

    exit(0);
}

&checkCommandLineArguments();


my $logger;

&getLogger($logfile, $debug_level);

if (! Annotation::Util2::checkInputFileStatus($bsmlfile)){

    $logger->logdie("Detected problems with the BSML file '$bsmlfile'");
}

$comment = &cleanseComment($comment);

my $contents = Annotation::Util2::getFileContentsArrayRef($bsmlfile);

if (!defined($contents)){

    $logger->logdie("Could not retrieve contents of BSML file '$bsmlfile'");
}

my $token = '<Bsml>';

if ($location eq 'bottom'){

    $token = '</Bsml>';
}

my $ofh = Annotation::Util2::getOutputFileHandle($outfile);

if (!defined($ofh)){

    $logger->logdie("Could not retrieve output file handle ".
		    "for outfile '$outfile'");
}


my $lineCtr=0;

my $tokenFound=0;

foreach my $line (@{$contents}){

    chomp $line;

    $lineCtr++;

    if ($line =~ /$token/){

	if ($tokenFound == 0 ){

	    if ($location eq 'top'){

		print $ofh "<!-- $comment -->\n";
		
		print $ofh $line . "\n";

	    } elsif ($location eq 'bottom'){


		print $ofh $line . "\n";
		
		print $ofh "<!-- $comment -->\n";

	    } else {

		$logger->logdie("Internal logic error: location ".
				"'$location' not supported!");
	    }

	    $tokenFound = 1;

	} else {

	    $logger->logdie("Encountered the token '$token' a second time ".
			    "at line '$lineCtr' in BSML file '$bsmlfile'!");
	}
    } else {
	
	print $ofh $line ."\n";
    }
}

if ($tokenFound == 0){

    $logger->logdie("Did not encounter the token '$token' in BSML file ".
		    "'$bsmlfile' after processing '$lineCtr' lines!");
}

print "$0 execution completed\n";
exit(0);


##---------------------------------------------------------
##
##       END OF MAIN -- SUBROUTINES FOLLOW
##
##---------------------------------------------------------

sub checkCommandLineArguments {

    if ($help){
	&pod2usage( {-exitval => 1, -verbose => 2, -output => \*STDOUT} ); 
	exit(1);
    }
    
    my $fatalCtr=0;

    if (!$bsmlfile){

	print STDERR "--bsmlfile was not specified\n";

	$fatalCtr++;
    }

    if (!$comment){

	print STDERR "--comment was not specified\n";

	$fatalCtr++;
    }

    if ($location){

	if (! (($location eq 'top') || ($location eq 'bottom')) ){

	    print STDERR "--location must be either 'top' or 'bottom'\n";

	    $fatalCtr++;
	}
    }

    if ( $fatalCtr > 0 ){

	die "Required command-line arguments were not specified";
    }

    if (!defined($outfile)){

	$outfile = $bsmlfile;

	$bsmlfile = $bsmlfile . '.orig';

	move($outfile,$bsmlfile) || die "Could not move $outfile to $bsmlfile:$!";
    }
    
    if (!defined($location)){

	$location = 'bottom';

	print "--location was not specified and therefore was set to '$location'\n";
    }

    if (!defined($logfile)){

	$logfile = '/tmp/' . File::Basename::basename($0) . '.log';

	print "--logfile was not specified and therefore was set to '$logfile'\n";
    }


    if (!defined($disable)){
	$disable = 0;
    }
}

sub cleanseComment {

    my ($comment) = @_;

    if ($comment =~ /\-/){
	## backslash escape all hyphens
	$comment =~ s/\-/\\-/g;
    }

    if ($comment =~ />/){
	## backslash escape all greater than symbols
	$comment =~ s/>/\>/g;
    }

    if ($comment =~ /</){
	## backslash escape all greater than symbols
	$comment =~ s/</\</g;
    }

    return $comment;
}

sub getLogger {

    my ($logfile, $debug_level) = @_;

    my $mylogger = new Annotation::Logger('LOG_FILE'=>$logfile,
					  'LOG_LEVEL'=>$debug_level);
    
    if (!defined($mylogger)){

	die "Could not instantiate Annotation::Logger object for logfile ".
	"'$logfile' level '$debug_level'";
    }


    $logger = Annotation::Logger::get_logger(__PACKAGE__);
    
    if (!defined($logger)){

	die "Could not retrieve Annotation::Logger object for logfile ".
	"'$logfile' level '$debug_level' for package " . __PACKAGE__ ."'";
    }
}
