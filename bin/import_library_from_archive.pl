#!/usr/bin/perl

=head1 NAME

 import_library_from_archive.pl: Uplaod file into mysql db from archive

=head1 SYNOPSIS

USAGE: import_library_from_archive.pl
            --input=/dir/preped/for/mysqlimport
            --env=/env/where/executing
            --outdir=/output/dir/loc
            [ --log=/path/to/logfile
             --debug=N]

=head1 OPTIONS

B<--input, -i>
    The full path to tab delimited file prepared for mysqlimport.

B<--table, -t>
    mysql db table name

B<--env, -e>
    env where is the script beeing executed diag1, diag2, igs,dbi,test

B<--outdir, -o>
    output directory

B<--debug,-d>
    Debug level.  Use a large number to turn on verbose debugging.

B<--log,-l>
    Log file

B<--help,-h>
    This help message

=head1  DESCRIPTION

This script is used to upload info into db.

=head1  INPUT

=head1  CONTACT

    Dan Nasko
    dnasko@udel.edu

=cut

use strict;
use warnings;
use DBI;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev pass_through);
use Pod::Usage;
use Data::Dumper;
use UTILS_V;

BEGIN {
  use Ergatis::Logger;
}

##############################################################################
my %options = ();
my $results = GetOptions (\%options,
                          'input|i=s',
			  'outdir|o=s',
			  'env|e=s',
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
##############################################################################
## make sure everything passed was peachy
&check_parameters(\%options);

# check if the file is empty.
# unless(-s $options{input} > 0){
#     print STDERR "This file $options{input} seem to be empty nothing therefore nothing to do.";
#     $logger->debug("This file $options{input} seem to be empty nothing therefore nothing to do.");
#     exit(0);
# }

###############################################################################

my @Tables = ( 'blastp', 'blastn', 'sequence', 'sequence_relationship', 'tRNA' );

my $utils = new UTILS_V;

$utils->set_db_params($options{env});

foreach my $table (@Tables) {
    my $column_list = '';
    if ($table =~ /sequence_relationship/i){
	$column_list = "sequence_relationship.subjectId,sequence_relationship.objectId,sequence_relationship.typeId";
	
    } elsif ($table =~ /sequence/i){
	$column_list =  "sequence.id,sequence.libraryId,sequence.name,sequence.header,";
	$column_list .= "sequence.gc,sequence.basepair,sequence.size,sequence.rRNA,sequence.orf,sequence.comment,sequence.dateCreated,sequence.dateModified,sequence.deleted,sequence.typeId";
	
    } elsif ($table =~ /orf/i){
	$column_list =  "orf.readId,orf.seqId,orf.seq_name,orf.gene_num,";
	$column_list .= "orf.gc_percent,orf.rbs_percent,orf.start,orf.end,";
	$column_list .= "orf.strand,orf.frame,orf.type,orf.score,orf.model,";
	$column_list .= "orf.rbs_start,orf.rbs_end,orf.rbs_score,";
	$column_list .= "orf.caller";
	
    } elsif ($table =~ /blast(x|n|p)/i){
	$column_list =  "$table.id,$table.sequenceId,$table.query_name,$table.query_length,$table.algorithm,";
	$column_list .= "$table.database_name,$table.db_ranking_code,$table.hit_name,$table.hit_description,";
	$column_list .= "$table.qry_start,$table.qry_end,$table.hit_start,$table.hit_end,";
	$column_list .= "$table.percent_identity,$table.percent_similarity,$table.raw_score,$table.bit_score,";
	$column_list .= "$table.blast_frame,$table.qry_strand,$table.subject_length,$table.e_value,";
	$column_list .= "$table.uniref,$table.uniref_id,$table.domain,$table.kingdom,$table.phylum,";
	$column_list .= "$table.class,$table.order,$table.family,$table.genus,$table.species,$table.organism,";
	$column_list .= "$table.hitOrder,$table.sys_topHit,$table.fxn_topHit,$table.hitToLibrary,";
	$column_list .= "$table.user_topHit,$table.comment,$table.dateCreated,$table.dateModified,";
	$column_list .= "$table.deleted";

    } elsif ($table =~ /tRNA/i){
	# id sequenceId num tRNA_start tRNA_end anti intron cove_start cove_end score dateCreated deleted
	$column_list =  "tRNA.id,tRNA.sequenceId,tRNA.num,tRNA.tRNA_start,";
	$column_list .= "tRNA.tRNA_end,tRNA.anti,tRNA.intron,tRNA.cove_start,";
	$column_list .= "tRNA.cove_end,tRNA.score,tRNA.dateCreated,tRNA.deleted";

	$table = "tRNA";

    }
    
    my $filename = $options{outdir}."/".$table.".txt";
    
    my $cmd = "ln -s $options{input}/$table.tab $filename";
    system($cmd);
    
    # setup mysql import command
    $cmd = '';
    $cmd = "mysqlimport --ignore-lines=1 --columns=$column_list --compress --fields-terminated-by='\\t'";
    $cmd .= " --lines-terminated-by='\\n' --ignore --host=". $utils->db_host ." --user=". $utils->db_user;
    $cmd .= " --password=". $utils->db_pass ." ". $utils->db_name ." -L $filename";

    # execute mysql import
    system($cmd);

    if (( $? >> 8 ) != 0 ){
	print STDERR "command failed: $!\n";
	print STDERR $cmd."\n";
	exit($?>>8);
    }

    # remove link file, prevent error if there is more than one file in the group.
    $cmd = "rm $filename";
    system($cmd);
}

exit(0);

###############################################################################
sub check_parameters {
  ## at least one input type is required
	unless ( $options{input} && $options{env} && $options{outdir}) {
		pod2usage({-exitval => 2,  -message => "error message", -verbose => 1, -output => \*STDERR});
		$logger->logdie("No input defined, plesae read perldoc $0\n\n");
		exit(1);
	}
}
