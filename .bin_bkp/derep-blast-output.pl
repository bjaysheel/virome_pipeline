#!/usr/bin/perl -w

=head1 NAME

derep-blast-output.pl - format library header after cd-hit

=head1 SYNOPSIS

USAGE: derep-blast-output.pl
            --file_part=/blast/btab/file/name
	    --file_path=/blast/btab/file/path
            --clstr=/path/to/cdhit/clstr/list
	    --output=/full/path/to/output/file
          [ --log=/path/to/logfile
            --debug=N
          ]

=head1 OPTIONS

B<--file_path, -f>
    The full path to blast btab file output

B<--file_part, -p>
    The file part of blast btab file

B<--clstr, -c>
    The full path to cdhit clstr output file list

B<--output, -o>
    The full path to output file
  
B<--debug,-d>
    Debug level.  Use a large number to turn on verbose debugging.

B<--log,-l>
    Log file

B<--help,-h>
    This help message

=head1  DESCRIPTION

This script is used to dereplication cluster file so
blast btab includes all seq part of a cluster.

=head1  INPUT

The input to this is defined using the --file_part.  This should point
to the blast btab file part, --file_path is the blast btab file path
--clstr should point to cdhit clstr file list, --output points to full path
to new btab output file.

=head1  CONTACT

    Jaysheel D. Bhavsar & Sandeep Kumar
    bjaysheel@gmail.com, dhankars@udel.edu

=cut

use strict;
use DBI;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
BEGIN {
  use Ergatis::Logger;
}

###############################################################################
my %options = ();
my $results = GetOptions (\%options,
                          'file_part|f=s',
			  'file_path|p=s',
                          'clstr|c=s',
			  'output|o=s',
                          'log|l=s',
                          'debug|d=s',
                          'help|h') || pod2usage();

my $logfile = $options{'log'} || Ergatis::Logger::get_default_logfilename();
my $logger = new Ergatis::Logger('LOG_FILE'=>$logfile,
                                  'LOG_LEVEL'=>$options{'debug'});
$logger = $logger->get_logger();

## display documentation
if( $options{'help'} ){
    pod2usage( {-exitval => 0, -verbose => 2, -output => \*STDERR} );
}

## make sure everything passed was peachy
&check_parameters(\%options);
###############################################################################

my $idx = index($options{file_part},".");
$options{file_part} = substr($options{file_part},0,$idx-1);

#my $clstr_file = `grep $options{file_part} $options{clstr}`;
my $clstr_file = `head -1 $options{clstr}`;
print STDERR "INFO: CLSTR OPTION: $options{clstr}\n";
print STDERR "INFO: CLSTR FILE: $clstr_file\n";

chomp $clstr_file;
  
open(BTAB, "$options{file_path}") or $logger->logdie("Couldn't btab open file $options{file_path}\n");
open(NEWTAB,">>$options{output}") or $logger->logdie("Couldn't newtab open file $options{output}\n");
my @btabfile = <BTAB>;
my $btabline="";
my $prev = "";
my $curr ="";
my $prevseq = "";
my @seqarray = ();
foreach $btabline(@btabfile){
    #print $btabline."\n";
    chomp $btabline;
    my @arr = split(/\t/,$btabline);
    my $seqname = $arr[0];
     $curr = $seqname;
    ##IF THE SAME SEQUENCE ADD TO ARRAY
	#print "current:\t".$curr."\tprevious:\t".$prev."\n";
	if($curr eq $prev){
		$prev = $curr;
		#print "pushing sequence to array\n";		
		push(@seqarray,$btabline);

	}
	else{	##CHECK IF ITS NOT THE FIRST SEQUENCE
		$prevseq = $prev;
		$prev = $curr;
		if(length($prev) > 0){
		
		#print "actually going inside\n";
		
			open(CLUSTER,"$clstr_file") or $logger->logdie("Couldn't open cluster file $clstr_file\n");
    			my @clusterfile = <CLUSTER>;
			close(CLUSTER);
    			my $i=0;
    			my $size = scalar @clusterfile;

    			##GO UNTIL YOU FIND THE SEQUENCE
    			  my $clusterline = "";
			    my $k = 0;
 
			    #print $seqname."\n";
 
   			 foreach my $clusterline(@clusterfile){
      				if($clusterline =~ /$prevseq/){
       			 		#print $clusterline."\n";
        				#move backword in the cluster
        				$k = 0;
        				while(!($clusterfile[$i-$k] =~ /Cluster/)){
          					$k++;
        				}		

        				my $j=1;
        				my $line = "";
       			 		while((!($clusterfile[$i-$k+$j] =~ /Cluster/)) && (($i-$k+$j) < ($size-1))){
         		 			my @clarr = split(/\>/,$clusterfile[$i-$k+$j]);
          					#print $clarr[1]."\n";
          					my $seqlen = length $clarr[1];
         		 			if($seqlen > 0){
            						#print "line value " . $clarr[1];
            						my @clarr1 = split(/[\.][\.][\.]/,$clarr[1]);
            						#print "name value " . $clarr1[0]."\n\n";
           						 my $len = @arr;

            						foreach my $seqline(@seqarray){
								$line = &trim($clarr1[0]);
								@arr = split(/\t/,$seqline);
								#print "these are its cluster seq".$output."\n";
        	   			 			for(my $s=1; $s<$len; $s ++){
              								$line .= "\t" . &trim($arr[$s]);
            							}
           		 					$line .= "\n";

           		 					print NEWTAB $line;
            							$line = "";
							}
          					}
         		 		#print $clusterfile[$i-$k+ $j]."\n";
          				$j++;
       			 		}
      				}
      				$i++;
   			 }
			@seqarray = ();
		

		}

	}			

    open(CLUSTER,"$clstr_file") or $logger->logdie("Couldn't open cluster file\n");
}
close(BTAB);
close(NEWTAB);
exit(0);

###############################################################################
sub check_parameters {
  ## at least one input type is required
  unless ( $options{file_part} && $options{clstr} && $options{output} && $options{file_path}) {
      #print STDERR "no input defined, please read perldoc $0\n\n";
      $logger->logdie("No fasta input list defined, plesae read perldoc $0\n\n");
      exit(1);
  }

  if(0){
      pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
  }
}

###############################################################################
sub trim($) {
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  return $string;
}
