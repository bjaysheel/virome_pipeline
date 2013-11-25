#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

=head1 NAME

bsml2chado.pl - Parse BSML document and produce tab delimited .out BCP files for insertion into Chado database

=head1 SYNOPSIS

USAGE:  bsml2chado.pl -D database --database_type -P password -U username [-S server] [-a autogen_feat] -b bsmldoc [--checksum-placeholders] [-d debug_level] [--gzip_bcp] [-h] [--id_repository] [-i insert_new] [-l log4perl] [-m] [-o outdir] [-p] [-R readonlycache] [-s autogen_seq] [--timestamp] [-u update] [-x xml_schema_type] [-y cache_dir] [-z doctype] [--append-bcp]

=head1 OPTIONS

=over 8

=item B<--username,-U>

Database username

=item B<--password,-P>

Database password

=item B<--database,-D>

Target chado database 

=item B<--database_type>

Relational database management system type e.g. sybase or postgresql

=item B<--server,-S>

Name of server on which the database resides

=item B<--bsmldoc,-b>

Bsml document containing pairwise alignment encodings

=item B<--autogen_feat,-a>

Optional - Default behavior is to auto-generate (-a=1) chado feature.uniquename values for all inbound features.  To turn off behavior specify this command-line option (-a=0).

=item B<--autogen_seq,-s>

Optional - Default behavior is to not (-s=0) auto-generate chado feature.uniquename values for all inbound sequences.  To turn on behavior specify this command-line option (-s=1).

=item B<--insert_new,-i>

Optional - Default behavior is to insert (-i=1) insert newly encountered Sequence objects in the BSML document that are not currently present in the Chado database.  To turn off default insert behavior specify this command-line option (-i=0)

=item B<--id_repository>

Optional - IdGenerator.pm stores files for tracking unique identifier values - some directory e.g. /usr/local/scratch/annotation/CHADO_TEST6/workflow/project_id_repository should be specified.  Default directory is ENV{ID_REPOSITORY}.

=item B<--debug_level,-d>

 Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

Display the pod2usage page for this utility

=item B<--outdir,-o>

 Optional: Output directory for the tab delimited .out files.  Default is current directory

=item B<--no-placeholders>

Optional - Do not insert placeholders variables in place of table serial identifiers (default is to insert placeholder variables)

=item B<--timestamp>

Optional - Time stamp e.g.  'Jun  5 2006  6:59PM' to be stored in feature.timeaccessioned (if required), feature.timelastmodified, analysis.timeexecuted
Default behavior is to auto-generate the timestamp.

=item B<--update,-u>

Optional - Default behavior is to not update the database (-u=0).  To turn on update behavior specify this command-line option (-u=1).


=item B<--cache_dir,-y>

Optional - Query caching directory to write cache files (default is ENV{DBCACHE_DIR})

=item B<--readonlycache,-R>

Optional - If data file caching is activated and if this readonlycache is == 1, then the tied MLDBM lookup cache files can only be accessed in read-only mode.  Default (-r=0) means cached lookup can be created and access mode is read-write.

=item B<--doctype,-z>

Optional - If specified, can direct the parser to construct concise lookup - more efficient. One of the following: nucmer, region, promer, pe, blastp, repeat, scaffold, rna, te, coverage

=item B<--help,-h>

Print this help

=item B<--gzip_bcp>

Optional - writes the BCP .out files in compressed format with .out.gz file extension

=back

=head1 DESCRIPTION

bsml2chado.pl - Parse BSML document and produce tab delimited .out BCP files for insertion into Chado database

 Assumptions:
1. The BSML pairwise alignment encoding should validate against the XML schema:.
2. User has appropriate permissions (to execute script, access chado database, write to output directory).
3. Target chado database already contains all reference features (necessary to build feature and organism lookups) Review and execute db2bsml.pl if required.
4. Target chado database contains the necessary controlled vocabulary terms: "match" etc.
5. All software has been properly installed, all required libraries are accessible.

Sample usage:
./bsml2chado.pl -U access -P access -D tryp -b /usr/local/annotation/TRYP/BSML_repository/blastp/lma2_86_assembly.blastp.bsml  -l my.log -o /tmp/outdir


=cut


use strict;

use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Coati::Logger;
use Config::IniFiles;
use Tie::File;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my ($username, $password, $database, $database_type, $server, $log4perl, $debug_level, $help, $man, $outdir, $exonfile, $cdsfile, $assembly_id, $abbreviation);

my $results = GetOptions (
			  'username|U=s'        => \$username, 
			  'password|P=s'        => \$password,
			  'database|D=s'        => \$database,
			  'database_type=s'     => \$database_type,
			  'server=s'            => \$server,
			  'log4perl|l=s'        => \$log4perl,
			  'debug_level|d=s'     => \$debug_level, 
			  'help|h'              => \$help,
			  'man|m'               => \$man,
			  'outdir|o=s'          => \$outdir,
			  'exonfile=s'          => \$exonfile,
			  'cdsfile=s'           => \$cdsfile,
			  'assembly_id=s'       => \$assembly_id,
			  'abbreviation=s'      => \$abbreviation,
			  );

&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);

my $fatalCtr=0;
$fatalCtr += &checkParameter('username', $username);
$fatalCtr += &checkParameter('password', $password);
$fatalCtr += &checkParameter('database', $database);
$fatalCtr += &checkParameter('database_type', $database_type);
$fatalCtr += &checkParameter('server', $server);

if ($fatalCtr>0){
    &print_usage();
}

#
# Get the Log4perl logger
#
my $logger = &set_logger($log4perl, $debug_level);

## Set the PRISM env var
&setPrismEnv($server, $database_type);

#
# verify and set the output directory
#
$outdir = &verify_and_set_outdir($outdir);

#
# Instantiate Prism object
#
my $prism = &retrieve_prism_object($username, $password, $database);

my $assembly_list;

if ((defined($assembly_id)) && (lc($assembly_id) eq 'all')) {
    $assembly_list = $prism->assemblies_with_exons_list();
}
elsif ((defined($assembly_id)) && (lc($assembly_id) ne 'all')) {
    push(@{$assembly_list}, $assembly_id);
}
elsif (defined($abbreviation)){
    $assembly_list = $prism->assemblies_by_organism_abbreviation($abbreviation);
}
else {
    $logger->fatal("You must specify an assembly_id or organism abbreviation");
    &print_usage();
}

my $sybase_time = $prism->get_sybase_datetime();

if (!defined($sybase_time)){
    $logger->logdie("sybase_time was not defined");
}

my $splice_site_cvterm_id = $prism->{_backend}->get_cvterm_id('splice_site');

if (!defined($splice_site_cvterm_id)){
    $logger->logdie("Could not retrieve cvterm_id for cvterm.name = 'splice_site'");
}


my $assembly_count = scalar(@{$assembly_list});

$logger->warn("Will process '$assembly_count' assemblies");

foreach my $asid ( sort @{$assembly_list} ) {

    $logger->warn("Processing assembly '$asid'");
    
    #
    # Create exons lookup
    #
    my $exons = &get_exon_lookup($exonfile, $prism, $asid);
    
    #
    # Create CDS lookup
    #
    my $cdslookup = &get_cds_lookup($asid, $cdsfile, $prism);

    #
    # Produce the splice feature and featureloc records
    #
    &create_splice_records($exons, $prism, $asid, $sybase_time, $splice_site_cvterm_id, $cdslookup);
}



#
# Output the BCP out files
#
$prism->{_backend}->output_tables($outdir);

print "Tab-delimited BCP .out files were written to directory: $outdir\n";

exit(0);

#-----------------------------------------------------------------------------------------------------
#
#       END OF MAIN  -- SUBROUTINES FOLLOW
#
#-----------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------
# get_exon_lookup()
#
#-------------------------------------------------------------------------
sub get_exon_lookup {

    my ($file, $prism, $assembly_id) = @_;

    my $exons = {};

    if (defined($file)){

	open (INFILE, "<$file") or $logger->logdie("Could not open file '$file': $!");
	
	
	while (my $line = <INFILE>){
	    
	    chomp $line;
	    #
	    # 0 cds.uniquename
	    # 1 exon.fmin
	    # 2 exon.fmax
	    # 3 exon.uniquename
	    # 4 exon.strand
	    #
	    
	    my @cols = split(/\s+/, $line);
	    
	    #
	    # Remove the first element (CDS uniquename) and store it in
	    # variable cdsid.
	    #
	    my $cdsid = shift(@cols);
	    
	    push(@{$exons->{$cdsid}}, \@cols);
	
	}
    }
    
    if (defined($assembly_id)){
	
	my $ret = $prism->exon_data_for_splice_site_derivation($assembly_id);

	my $count = scalar(@{$ret});

	for (my $i=0; $i<$count; $i++){
	    
	    my @array = ($ret->[$i][1], ## featureloc.fmin
			 $ret->[$i][2], ## featureloc.fmax
			 $ret->[$i][3], ## feature.uniquename (exon)
			 $ret->[$i][4]  ## featureloc.strand
			 );
	    ##                feature.uniquename (CDS)
	    push ( @{$exons->{$ret->[$i][0]}}, \@array);

	}
    }
    
    return $exons;
}




#--------------------------------------------------------------
# get_cds_lookup()
#
#--------------------------------------------------------------
sub get_cds_lookup {

    my ($assembly_id, $cdsfile, $prism) = @_;

    my $cdslookup;

    if (defined($cdsfile)){
	
	open (INFILE, "<$cdsfile") or $logger->logdie("Could not open file '$cdsfile' for input: $!");

	while (my $line = <INFILE>){
	    
	    chomp $line;
	    
	    my @array = split(/\s+/, $line);

	    push(@{$cdslookup}, \@array);
	}

    }
    
    if (defined($assembly_id)){

	$cdslookup = $prism->cds_and_polypeptide_data_for_splice_site_derivation($assembly_id);

    }

    return $cdslookup;

}

#--------------------------------------------------------------
# create_splice_records()
#
#--------------------------------------------------------------
sub create_splice_records {

    my ($exons, $prism, $assembly_id, $sybase_time, $splice_site_cvterm_id, $cdslookup) = @_;
    
    # $cols (for cdslookup):
    # 0 cds.uniquename
    # 1 cds.fmin
    # 2 cds.fmax
    # 3 polypeptide.uniquename
    # 4 polypeptide.seqlen
    # 5 polypeptide.feature_id
    # 6 polypeptide.organism_id
    # 7 cds.strand
    # 8 polypeptide.strand
    # 9 polypeptide.fmin
    # 10 polypeptide.fmax

    
    # $exon:
    # 0 fmin
    # 1 fmax
    # 2 exon.uniquename
    # 3 strand

    foreach my $cols ( @{$cdslookup} ){

	## Use the CDS uniquename to lookup all of the associated exons.
	## Sort the exons based on the fmin coordinates.
	my @sortedexons = ( sort { $a->[1] <=> $b->[1] } @{$exons->{$cols->[0]}} );

	## The CDS coordinate counter
	## cols->[1]  == cds.fmin
	my $pointer = $cols->[1];

	## The CDS coordinate counter
	my $cds_counter = 0;
                                    
	## The polypeptide coordinate counter
	my $poly_counter = 0;

	# Don't need to process the last exon as does not have a 3' splice site!
	my $exoncount = scalar(@sortedexons) - 1;

	for (my $exonindex = 0; $exonindex < $exoncount; $exonindex++ ){

	    my $exon = $sortedexons[$exonindex];

	    if ($exon->[1] < $cols->[1]){
		## if exon->[1] == exon.fmax < cols->[1] == cds.fmin
		## then this exon is UTR
		next;
	    }

	    if ($pointer < $exon->[0]){
		## if pointer < exon->[0] == exon.fmin
		## then set the pointer = exon.fmin
		$pointer = $exon->[0];
	    }

	    while (( $pointer <= $exon->[1]) &&  ## pointer <= exon->[1] == exon.fmax
		   ( $pointer <= $cols->[2]) &&  ## pointer <= cols->[2]  == cds.fmax  (We are not interested in splice sites beyond the 3' end of the CDS)
		   ( $pointer <= $cols->[10])) { ## pointer <= cols->[10] == polypeptide.fmax (We are not interested in splice sites beyond the 3' end of the polypeptide)

		$pointer++; ## We want to walk to the end of the current exon- there we'll find a splice site.

		$cds_counter++;	## Increment the CDS coordinate counter
		
		if ($cds_counter % 3 == 0){
		    ## if we've counted three bases (one codon)
		    ## then increment the polypeptide coordinate counter
		    $poly_counter++;
		}
	    
		if (($pointer == $exon->[1]) &&   ## end of the exon, splice site!
		    ($pointer <= $cols->[2]) &&   ## pointer <= cols->[2]  == cds.fmax  (We are not interested in splice sites beyond the 3' end of the CDS)
		    ($poly_counter < $cols->[4] )) { ## the splice site must fall within the boundary of the polypeptide
		    
		    
		    if ($pointer >= $cols->[9]){
			
			# We are only interested in splice sites which fall within the
			# polypeptide's boundaries. That is, between
			# pointer >= cols->[9]  == polypeptide.fmin AND
			# pointer <= cols->[10] == polypeptide.fmax
			
			&create_bcp_records($cols, $poly_counter, $splice_site_cvterm_id, $sybase_time, $pointer, $exon, $cds_counter);
		    }
		    else {
			$logger->warn("Will not generate a splice site feature for exon '$exon->[2]' since fmax is not within the polypeptide boundary");
		    }

		    ## Done with this exon, process the next one.
		    last;
		}
	    }
	}
    }
}


#-----------------------------------------------------------------------------------
# create_bcp_records()
#
#-----------------------------------------------------------------------------------
sub create_bcp_records {
	
    my ($cols, $poly_counter, $splice_site_cvterm_id, $sybase_time, $pointer, $exon, $cds_counter) = @_;

    my $uniquename = $cols->[3] . '_' .  $poly_counter . '_splice_site';
		
    my $feature_id = $prism->{_backend}->do_store_new_feature( dbxref_id        => undef,
							       organism_id      => $cols->[6],
							       name             => undef,
							       uniquename       => $uniquename,
							       residues         => undef,
							       seqlen           => undef,
							       md5checksum      => undef,
							       type_id          => $splice_site_cvterm_id,
							       is_analysis      => 0,
							       is_obsolete      => 0,
							       timeaccessioned  => $sybase_time,
							       timelastmodified => $sybase_time
							       );
		
    if (!defined($feature_id)){
	$logger->logdie("feature_id was not defined for uniquename '$uniquename'");
    }
    else {
	

	my $fmin;
	my $fmax;

	if ($cols->[7] == -1){

	    my $temp = $cols->[4] - $poly_counter ;

	    $poly_counter = $temp;

	    $fmin = $poly_counter;
	    $fmax = $poly_counter;
	    
	    if ($cds_counter % 3 != 0){
		$fmin--;
	    }
	}
	else {
	    $fmin = $poly_counter;
	    $fmax = $poly_counter;
	    
	    if ($cds_counter % 3 != 0){
		$fmax++;
	    }
	}
	
	my $featureloc_id = $prism->{_backend}->do_store_new_featureloc( feature_id      => $feature_id,
									 srcfeature_id   => $cols->[5],
									 fmin            => $fmin,
									 is_fmin_partial => 0,
									 fmax            => $fmax,
									 is_fmax_partial => 0,
									 strand          => $exon->[3],
									 residue_info    => undef,
									 locgroup        => 0,
									 rank            => 0#$exonindex
									 );
	if (!defined($featureloc_id)){
	    $logger->logdie("featureloc_id was not defined for feature_id '$feature_id' uniquename '$uniquename'");
	}
    }
}

#-----------------------------------------------------------------------------------
# set_logger()
#
#-----------------------------------------------------------------------------------
sub set_logger {

    my ($log4perl, $debug_level) = @_;

    $log4perl = "/tmp/create_splice_site_records.pl.log" if (!defined($log4perl));

    my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				     'LOG_LEVEL'=>$debug_level);
    

    my $logger = Coati::Logger::get_logger(__PACKAGE__);
    
    return $logger;
}

#------------------------------------------------------
# print_usage()
#
#------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -D database --database_type --server -P password -U username [--abbreviation] [--assembly_id] [--cdsfile] [-d debug_level] [--exonfile] [-h] [-l log4perl] [-m] [-o outdir]\n".
    "  -D|--database              = Target chado database\n".
    "  --database_type            = Relational database management system type e.g. sybase or postgresql\n".
    "  --server                   = Name of server on which the database resides\n".
    "  -P|--password              = Password\n".
    "  -U|--username              = Username\n".
    "  --abbreviation             = Optional - organism.abbreviation\n".
    "  --assembly_id              = Optional - uniquename identifier of the assembly\n".
    "  --cdsfile                  = Optional - cdsfile (Must be defined if assembly_id is not defined)\n".
    "  -d|--debug_level           = Optional - Coati::Logger log4perl logging level.  Default is 0\n".
    "  --exonfile                 = Optional - exonfile (Must be defined if assembly_id is not defined)\n".
    "  -h|--help                  = Optional - Display pod2usage help screen\n".
    "  -l|--log4perl              = Optional - Log4perl log file (default: /tmp/bsml2chado.pl.log)\n".
    "  -m|--man                   = Optional - Display pod2usage pages for this utility\n".
    "  -o|--outdir                = Optional - output directory for tab delimited BCP files (Default is current working directory)\n";
    exit 1;

}

#----------------------------------------------------------------
# retrieve_prism_object()
#
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database) = @_;

     my $prism = new Prism(
			   user              => $username,
			   password          => $password,
			   db                => $database,
			   );


    $logger->logdie("prism was not defined") if (!defined($prism));

    return $prism;

}#end sub retrieve_prism_object()


#--------------------------------------------------------
# verify_and_set_outdir()
#
#
#--------------------------------------------------------
sub verify_and_set_outdir {

    my ( $outdir) = @_;

    $logger->debug("Verifying and setting output directory") if ($logger->is_debug());

    #
    # strip trailing forward slashes
    #
    $outdir =~ s/\/+$//;
    
    #
    # set to current directory if not defined
    #
    if (!defined($outdir)){
	if (!defined($ENV{'OUTPUT_DIR'})){
	    $outdir = "." 
	}
	else{
	    $outdir = $ENV{'OUTPUT_DIR'};
	}
    }

    $outdir .= '/';

    #
    # verify whether outdir is in fact a directory
    #
    $logger->logdie("$outdir is not a directory") if (!-d $outdir);

    #
    # verify whether outdir has write permissions
    #
    $logger->logdie("$outdir does not have write permissions") if ((-e $outdir) and (!-w $outdir));


    $logger->debug("outdir is set to:$outdir") if ($logger->is_debug());

    #
    # store the outdir in the environment variable
    #
    $ENV{OUTPUT_DIR} = $outdir;
    
    return $outdir;

}#end sub verify_and_set_outdir()

sub checkParameter { 
    my ($paramName, $value) = @_;
    if (!defined($value)){
	print STDERR "$paramName was not defined\n";
	return 1;
    }
    return 0;
}

#--------------------------------------------------
# setPrismEnv()
#
#--------------------------------------------------
sub setPrismEnv {

    my ($server, $vendor) = @_;

    if (!defined($server)){
	$logger->logdie("server was not defined");
    }
    if (!defined($vendor)){
	$logger->logdie("vendor was not defined");
    }
    
    if ($vendor eq 'postgresql'){
	$vendor = 'postgres';
    }

    $vendor = "Bulk" . ucfirst($vendor);
    ## We're overriding the env stored in conf/Prism.conf
    my $prismenv = "Chado:$vendor:$server";


    $ENV{PRISM} = $prismenv;
}
