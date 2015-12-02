#!/usr/bin/perl -w

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

createEnzymeObo.pl - Parses tab delimited dump of SYBTIGR.egad.prot_function and outputs OBO formatted file

=head1 SYNOPSIS

USAGE:  createEnzymeObo.pl -i infile -o outfile [-d debug_level] [-h] [-l log4perl] [-m] 

=head1 OPTIONS

=over 8

=item B<--infile,-i>
    
    input file which contains tab delimited dump of SYBTIGR.egad.prot_function

=item B<--outfile,-o>
    
    output file which will be OBO formatted

=item B<--debug_level,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--help,-h>

    Print this help

=item B<--log4perl,-l>

    Optional - log4perl logfile.  Default is /tmp/createEnzymeObo.pl.log

=item B<--man,-m>

    Display the pod2usage page for this utility


=back

=head1 DESCRIPTION

    createEnzymeObo.pl - Parses tab delimited dump of SYBTIGR.egad.prot_function and outputs OBO formatted file

    Assumptions:
    1. User has appropriate permissions (to execute script, access chado database, write to output directory).
    2. User has properly edited the infile (removed SQL column headers and trailing row counts)

    Sample usage:
    ./createEnzymeObo.pl -i prot_function.out -o ec.obo

=cut

use strict;

use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use FileHandle;
use Coati::Logger;

#-----------------------------------------------------------------------------------------------
# Usage:
# 
# 1)
# Dump data from SYBTIGR.egad.prot_function:
# 1> select ec#, '||', substring(pfunction,1,14), '||', substring(sub1function,1,62), '||', substring(sub2function,1,100), '||', substring(sub3function,1,100), '||', reaction ,'||||'
# 2> from prot_function
# 3> \go > prot_function.out
#
# 2)
# Known issue:
# Need to clean out the column headers and trailing row counts from the prot_function.out file.
# Need to add the following string immediately after the last record in the prot_function.out file: '||LAST||'.
# Please note that the field separators are || and the record separators are ||||.
#
# 3)
# Invocation:
# ./createEnzymeObo.pl -i prot_function -o ec.obo
#
# 4)
# Edit ec.obo - upon attempting to load the ec.obo file in the DAG Editor, you will receive
# a java exception: load error.  Edit the ec.obo file at the specified line (get rid of the
# newlines as indicated).
#
#
#
#
#-----------------------------------------------------------------------------------------------

$| = 1;

my($infile, $outfile, $help, $man, $log4perl, $debug_level);


my $results = GetOptions (
			  'infile|i=s'    => \$infile, 
			  'outfile|o=s'   => \$outfile,
			  'log4perl|l=s'  => \$log4perl,
			  'help|h'        => \$help,
			  'man|m'         => \$man,
			  'debug_level|d=s' => \$debug_level
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);


print STDERR ("infile was not defined\n")    if (!$infile); 
print STDERR ("outfile was not defined\n")   if (!$outfile);

&print_usage if(!$infile or !$outfile);


#
# initialize the logger
#
$log4perl = "/tmp/createEnzymeObo.pl.log" if (!defined($log4perl));
my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

#
# Instantiate Prism object
#
my $prism = &retrieve_prism_object('access', 'access', 'egad');


#
# Set newline/record separator to ||||
#
$/ = "||||";

open (OUTFILE, ">$outfile") or $logger->logdie("Could not open outfile '$outfile'");


#
# Retrieve the contents of the infile
#
my $contents = $prism->get_file_contents($infile);


&write_header();


my $hash = {};
my $h1 = [];
my $linectr=0;

#-----------------------------------------------------------------
# show_progress related data
#
#----------------------------------------------------------------
my $bars = 30;
my $total_rows = 3964;
my $counter = int(.01 * $total_rows);
$counter = 1 if($counter ==0);
print "\n";

foreach my $line (@{$contents}){
    
    #
    # You need to edit prot_function.out and add string '||LAST||'
    # immediately following the last ||||
    #
    if ($line =~ /\|\|LAST\|\|/){
	last;
    }

    $linectr++;
    $prism->show_progress("Parsing infile $linectr/$total_rows",$counter,$linectr,$bars,$total_rows);

    my ($ec, $pfunc, $sub1, $sub2, $sub3, $reaction) = split(/\|\|/, $line);


#                       ec                  pfunc             sub1            sub2                sub3                reaction
#
#    if ($line =~ /\s*([\S\s+])\s*\|\|\s*([\S\s+])\s*\|\|\s*([\S\s+])\s*\|\|\s*([\S\s+])\s*\|\|\s*([\S\s+])\s*\|\|\s*([\S\s+])\s*/){
#	($ec, $pfunc, $sub1, $sub2, $sub3, $reaction) = ($1,$2,$3,$4,$5,$6);
#
#    }
#    else{
#	$logger->logdie("Could not parse line '$line'");
#    }


    if ($ec =~ /^\s+(\S+)\s+/){
	$ec = $1;
    }
    else{
	$logger->logdie("linectr '$linectr' ec '$ec' was not defined for line '$line'");
    }


    if ($pfunc =~ /^\s+(\S+)\s*$/){
	$pfunc = $1;
	$pfunc =~ s/\s+$//;
    }
    else{
	$logger->logdie("pfunc '$pfunc'");
    }


    if ($sub1 =~ /^\s([\S\s]+)\s*$/){
	$sub1 = $1;
	$sub1 =~ s/\s+$//;
    }
    else{
	$logger->logdie("sub1 '$sub1'");
    }


    if ($sub2 =~ /^\s([\S\s]+)\s*$/){
	$sub2 = $1;
	$sub2 =~ s/\s+$//;
    }
    else{
	$logger->logdie("sub2 '$sub2'");
    }


    if ($sub3 =~ /^\s+([\S\s]+)\s*$/){
	$sub3 = $1;
	$sub3 =~ s/\s+$//;
    }
    else{
	$logger->logdie("sub3 '$sub3' was not defined for line '$line'");
    }


    if ($reaction =~ /^\s+([\S\s]+)\s*$/){
	$reaction = $1;
	$reaction =~ s/\s+$//;
    }
    else{
	$logger->logdie("reaction '$reaction'");
    }

    $logger->debug("ec '$ec' pfunc '$pfunc' sub1 '$sub1' sub2 '$sub2' sub3 '$sub3' reaction '$reaction'") if $logger->is_debug;


    #
    # Need to split the ec number and store hierarchically
    #
    my ($e1,$e2,$e3,$e4) = split(/\./,$ec);

    if (!defined($e1)){
	$logger->logdie("e1 was not defined for ec '$ec' linectr '$linectr' line '$line'");
    }
    if (!defined($e2)){
	$logger->logdie("e2 was not defined for ec '$ec' linectr '$linectr' line '$line'");
    }
    if (!defined($e3)){
	$logger->logdie("e3 was not defined for ec '$ec' linectr '$linectr' line '$line'");
    }
    if (!defined($e4)){
	$logger->logdie("e4 was not defined for ec '$ec' linectr '$linectr' line '$line'");
    }

    my $ec1 = $e1 . ".-.-.-";

    my $ec2 = $e1 . '.' . $e2 . '.-.-';
    my $ec3 = $e1 . '.' . $e2 . '.' . $e3 . '.-';
    my $ec4 = $e1 . '.' . $e2 . '.' . $e3 . '.' .$e4;
 

    $logger->debug("ec '$ec' ec1 '$ec1' ec2 '$ec2' ec3 '$ec3' ec4 '$ec4'") if $logger->is_debug;
    

    if (!exists $hash->{$ec1}->{'name'}){
	$hash->{$ec1}->{'name'} = $pfunc;
	my $h2;

	$h2->{$ec1}->{'name'} = $pfunc;
	push(@{$h1}, $h2);
    }
    else{
	my $old = $hash->{$ec1}->{'name'};
	if ($old ne $pfunc){
	    $logger->logdie("old '$old' != pfunc '$pfunc' for ec '$ec' line '$line'");
	}
    }

    if (!exists $hash->{$ec2}->{'name'}){
	$hash->{$ec2}->{'name'} = $sub1;
	$hash->{$ec2}->{'is_a'} = $ec1;

	my $h2;
	$h2->{$ec2}->{'name'} = $sub1;
	$h2->{$ec2}->{'is_a'} = $ec1;
	push(@{$h1}, $h2);
    }
    else{
	my $old = $hash->{$ec2}->{'name'};
	if ($old ne $sub1){
	    if ($sub1 eq 'NULL'){
		$logger->warn("sub1 '$sub1' for ec '$ec'");
	    }
	    else{
		$logger->logdie("old '$old' != sub1 '$sub1' for ec '$ec' line '$line'");
	    }
	}
    }

    if (!exists $hash->{$ec3}->{'name'}){
	$hash->{$ec3}->{'name'} = $sub2;
	$hash->{$ec3}->{'is_a'} = $ec2;

	my $h2;

	$h2->{$ec3}->{'name'} = $sub2;
	$h2->{$ec3}->{'is_a'} = $ec2;
	push(@{$h1}, $h2);
    }
    else{
	my $old = $hash->{$ec3}->{'name'};
	if ($old ne $sub2){
	    if ($sub2 eq 'NULL'){
		$logger->warn("sub2 '$sub2' for ec '$ec'");
	    }
	    else{
		$logger->logdie("old '$old' != sub2 '$sub2' for ec '$ec' line '$line'");
	    }
	    
	}
    }

    if (!exists $hash->{$ec4}->{'name'}){
	$hash->{$ec4}->{'name'} = $sub3;
	$hash->{$ec4}->{'is_a'} = $ec3;

	my $h2;
	$h2->{$ec4}->{'name'} = $sub3;
	$h2->{$ec4}->{'is_a'} = $ec3;

	if ($reaction !~ /NULL/){
	    $h2->{$ec4}->{'def'} = $reaction;
	}

	push(@{$h1}, $h2);
    }
    else{
	my $old = $hash->{$ec4}->{'name'};
	if ($old ne $sub3){
	    if ($sub3 eq 'NULL'){
		$logger->warn("sub3 '$sub3' for ec '$ec'");
	    }
	    else{
		$logger->logdie("old '$old' != sub3 '$sub3' for ec '$ec' line '$line'");
	    }
	}
    }


    $logger->debug("ec '$ec' pfunc '$pfunc' sub1 '$sub1' sub2 '$sub2' sub3 '$sub3' reaction '$reaction'") if $logger->is_debug;

#    print Dumper $h1;die;
}

#print Dumper $h1;die;

$logger->debug("h1:\n" . Dumper $h1) if $logger->is_debug;

#
# Restore newline/record separator to \n
#
$/ = "\n";

&write_terms($h1);

#-----------------------------------------------------------------------------------------------------------------------------
#
#                                END OF MAIN -- SUBROUTINES FOLLOW
#
#-----------------------------------------------------------------------------------------------------------------------------



#--------------------------------------------------------------------------------
# write_terms()
#
# This function should write each node
# in the following manner:
#
#
# [Term]
# id: EC:0000001
# name: OXIDOREDUCTASE
# xref_analog: EC:1.-.-.-
#
# [Term]
# id: EC:0000002
# name: ACTING ON THE CH-OH GROUP OF DONOR
# xref_analog: EC:1.1.-.-
# is_a: EC:0000001
#
# [Term]
# id: EC:0000003
# name: WITH NAD(+) OR NADP(+) AS ACCEPTOR
# xref_analog: EC:1.1.1.-
# is_a: EC:0000002
#
# [Term]
# id: EC:0000004
# name: Alcohol dehydrogenase
# def: An alcohol + NAD(+) = an aldehyde or ketone + NADH
# xref_analog: EC:1.1.1.1
# is_a: EC:0000003
#
#-----------------------------------------------------------------------------------
sub write_terms {

    my ($arr) = @_;

    my $linectr=0;

    print "\n\n";

    #-----------------------------------------------------------------
    # show_progress related data
    #
    #----------------------------------------------------------------
    my $bars = 30;
    my $total_rows = scalar(@{$arr});
    my $counter = int(.01 * $total_rows);
    $counter = 1 if($counter ==0);


    my $keycount = 0;

    #
    # Lookup hashes
    #
    my $ec2id = {};
    my $id2ec = {};


    foreach my $hash (@{$arr}){
	
	
	foreach my $ec (keys %{$hash}){
	    


	    $linectr++;
	    $prism->show_progress("Writing OBO file $linectr/$total_rows",$counter,$linectr,$bars,$total_rows);
	    
	    $keycount++;

	    my $ident = &make_ident($keycount, 'EC:', 7);


	    $ec2id->{$ec} = $ident;
	    $id2ec->{$ident} = $ec;


	    my $is_a        = $hash->{$ec}->{'is_a'}; 
	    my $name        = $hash->{$ec}->{'name'}; 
	    my $xref_analog = $ec;
	    my $def         = $hash->{$ec}->{'def'};
	    
	    
	    my $node = "[Term]\n".
	    "id: $ident\n".
	    "name: $name\n";
	    
	    if (defined($def)){
		chomp $def;
		$node .= "def: \"$def\" []\n";
	    }

	    $node .= "xref_analog: EC:$xref_analog\n" if (defined($xref_analog));

	    if (defined($is_a)){
		my $is_aa = $ec2id->{$is_a};
		$node .= "is_a: $is_aa\n";
	    }
	    


	    
	    
	    print OUTFILE $node . "\n";
	    
	}
    }

}

#-----------------------------------------------------------------------
# make_ident()
#
#-----------------------------------------------------------------------
sub make_ident {

    my ($id, $tag, $threshold) = @_;

    while ( length($id) < $threshold){
	
	my $zero = "0";
	$id = $zero . $id;

    }

    $tag .= $id;
    $logger->debug("tag '$tag'") if $logger->is_debug;

    return $tag;
}


#-----------------------------------------------------------------------
# write_header()
#
#-----------------------------------------------------------------------
sub write_header {

    my $header = "format-version: 1.0\n".
    "date: 22:09:2004 16:32\n".
    "saved-by: sundaram\n".
    "auto-generated-by: createEnzymeObo.pl\n".
    "default-namespace: ec.ontology\n".
    "remark: autogenerated-by\\\:     createEnzymeObo.pl\\nsaved-by\\\:             sundaram\\ndate\\\:                 Wed Sep 26 15\\\:56\\\:55 EST 2004\\nversion\\\: \$Revision\\\: 1.1 $\n";
    

    print OUTFILE $header . "\n\n";



}

#----------------------------------------------------------------
# retrieve_prism_object()
#
#
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database, $pparse) = @_;

    $logger->debug("Instantiating Prism object") if ($logger->is_debug());
    
    if (defined($pparse)){
	$pparse = 1;
    }
    else{
	$pparse = 0;
    }
    

    my $prism = new Prism( 
			   user             => $username,
			   password         => $password,
			   db               => $database,
			   use_placeholders => $pparse,
			   );
    
    $logger->fatal("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    

    return $prism;


}#end sub retrieve_prism_object()

#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -i infile -o outfile [-d debug_level] [-h] [-l log4perl] [-m]\n";
    print STDERR "  -i|--infile           = input tab delimited file containing dump of SYBTIGR.egad.prot_function as indicate by query (see --help)\n";
    print STDERR "  -o|--outfile          = output file in OBO format\n";
    print STDERR "  -d|--debug_level      = Optional - Coati::Logger log4perl logging level.  Default is 0\n";    
    print STDERR "  -h|--help             = Optional - Display pod2usage help screen\n";
    print STDERR "  -l|--log4perl         = Optional - Log4perl log file (default: /tmp/bsml2chado.pl.log)\n";
    print STDERR "  -m|--man              = Optional - Display pod2usage pages for this utility\n";
    exit 1;

}
