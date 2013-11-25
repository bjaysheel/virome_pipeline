#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#---------------------------------------------------------
# editor:  sundaram@tigr.org
#
# date:    A long, long time ago...
#
# input:   dir1 = contains BCP .out files
#
# output:  dir2 = directory to move all BCP .out files
#          having zero content
#
# return:  none
#
#
# comment:
#
#---------------------------------------------------------
=head1 NAME

movezerofiles.pl - Moves BCP .out files to specified directory - optionally archives good BCP .out files

=head1 SYNOPSIS

USAGE:  movezerofiles.pl -dir1 directory1 -dir2 directory2 [-tgz 1|0]

=head1 OPTIONS

=over 8

=item B<--dir1>
    
    Directory containing the BCP .out files

=item B<--dir2>

    Directory to move BCP .out files having zero content

=item B<--tgz>
    
    Optional - If user specifies 1 will tar zcvf all BCP .out files in dir1 and then remove them

=item B<--help,-h>

    Print this help

=item B<--man,-m>

    Display pod2usage man page for this utility


=back

=head1 DESCRIPTION

    movezerofiles.pl - Moves BCP .out files with zero content to specified directory (optionally archives good BCP .out files)
    e.g.
    1) ./movezerofiles.pl -dir1 /usr/local/annotation/CHADO_TEST/BCPFILES/2005-04-10/ -dir2 /usr/local/scratch


=head1 AUTHOR

    sundaram@tigr.org

=cut

use strict;
use Pod::Usage;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use File::Basename;
use Data::Dumper;

$|=1;

my ($dir1, $dir2, $tgz, $help, $man);

my $results = GetOptions (
			  'dir1=s' => \$dir1,
			  'dir2=s' => \$dir2,
			  'tgz=s'  => \$tgz,
			  'help|h' => \$help,
			  'man|m'  => \$man			  
			  );



&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

  
print STDERR ("dir1 was not specified\n")  if (!$dir1);
print STDERR ("dir2 was not specified\n")  if (!$dir2);

&print_usage if(!$dir1 or !$dir2);

&check_dir($dir1);
&check_dir($dir2);

my $bcpfiles = &move_zero_content_files($dir1, $dir2);


if (defined($tgz)){

    if ($tgz == 1){
	#
	# User wishes to compress the files
	#
	&compress_files($dir1, $bcpfiles);
    }
    else {
	#
	# User does not want to compress the files
	# 
    }
}

#-------------------------------------------------------------------------------------------------
#
#                 END OF MAIN  --  SUBROUTINES FOLLOW
#
#-------------------------------------------------------------------------------------------------



sub compress_files {
    
    my ($dir, $bcpfiles) = @_;


    #
    # We'll change directory and then proces files.
    # This will ensure that the BCP .out files are 
    # archived such that they can later be extracted locally.
    #
    chdir($dir);

#    --remove-files seems to not be working...
#    my $execstring = "tar -zcvf --remove-files $dir/bcp.tgz $dir/*.out";
    my $execstring = "tar zcvf bcp.tgz *.out";


    eval {
	qx($execstring);
    };
    if ($@){
	die "Some error occured while attempting to tgz BCP .out files in directory '$dir'.  Error was: $!";
    }
    else {

	my @cannot = grep {not unlink} @{$bcpfiles};
	die "$0: could not unlink @{$bcpfiles}\n" if (@cannot);

	print "Files archived: $dir/bcp.tgz\n";
    }
    
}



sub check_dir {

    my $dir = shift;

    die "directory '$dir' does not exist" if (!-e $dir);
    die "'$dir' is not a directory" if (!-d $dir);


}



sub move_zero_content_files {

    my ($dir1, $dir2) = @_;

    my $x = "find $dir1 -name \"*.out\" -type f -maxdepth 1";


    my @bcpfiles;

    my @files = qx{$x};
    chomp @files;

    if (scalar(@files) > 0 ){
	
	foreach my $file (@files){
	    if (-z $file){
		
		eval {
		    my $x2 = "mv $file $dir2";
		    qx{$x2};
		};
		if ($@){
		    die "Some error occured while attempt to move zero content file '$file': $!";
		}
	    }
	    else {
		my $basename = File::Basename::basename($file);
		push(@bcpfiles, $basename);
	    }
	}
    }
    else{
	print "No BCP .out files in directory '$dir1' to be processed\n";
	exit(0);
    }

    return \@bcpfiles;

}


#--------------------------------------------------------------------
# print_usage()
#
#--------------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -dir1 directory1 -dir2 directory2 [-tgz tgz]\n".
    "  --dir1          = directory containing BCP .out files\n".
    "  --dir2          = directory to move zero content BCP .out files\n".
    "  --tgz           = Optional - 1 to tar -zxvf the BCP .out files (Default 0 to not)\n";
    exit 1;

}
