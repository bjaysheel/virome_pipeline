#!/usr/local/bin/perl
use strict;
use BSML2CHADO::Validator;
use Annotation::Util2;

my $username = 'sundaram';
my $password = 'sundaram7';
my $database = 'phytax';
my $server = 'SYBPROD';
my $database_type = 'sybase';
#my $bsmlfilelist = '/usr/local/scratch/sundaram/db2bsml.bsml.list';
#my $bsmlfilelist = '/usr/local/annotation/PHYTAX/output_repository/db2bsml/14790_default/db2bsml.bsml.list.1';
#my $bsmlfilelist = '/usr/local/scratch/sundaram/5466.bsml.list';

my $bsmlfilelist = $ARGV[0];
if (!defined($bsmlfilelist)){
    die "Usage: $0 bsmlfilelist"
}

if (!Annotation::Util2::checkInputFileStatus($bsmlfilelist)){
    die "Detected some problem with BSML file list '$bsmlfilelist'";
}

my $validator = new BSML2CHADO::Validator(username=>$username,
					  password=>$password,
					  database=>$database,
					  server=>$server,
					  database_type=>$database_type,
					  filelist=>$bsmlfilelist);
if (!defined($validator)){
    die "Could not instantiate BSML2CHADO::Validator";
}

$validator->validate();


print "$0 execution completed\n";
exit(0);

##--------------------------------------------------------
##
##    END OF MAIN -- SUBROUTINES FOLLOW
##
##--------------------------------------------------------
