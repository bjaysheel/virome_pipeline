#!/usr/local/bin/perl
use strict;
use Euk::Prism::ORFAttribute::PartialSequenceUtil;


$ENV{PRISM} = 'Euk:Sybase:SYBTIGR';

my $username = 'access';
my $password = 'access';
my $database = 'phytoplankton';
my $server   = 'SYBTIGR';
my $vendor   = 'Sybase';


my $util = new Euk::Prism::ORFAttribute::PartialSequenceUtil(username=>$username,
							     password=>$password,
							     database=>$database,
							     server=>$server,
							     vendor=>$vendor);

if (!defined($util)){
    die "Could not instantiate Euk::Prism::ORFAttribute::PartialSequenceUtil";
}

my $feat_name1 = '1.m000597';

my $feat_name2 = '1.m000600';

my $feat_name3 = '1.m000591';

&runChecks($feat_name1);
&runChecks($feat_name2);
&runChecks($feat_name3);


print "$0 execution completed";
exit(0);

##------------------------------------------------------------------
##
##            END OF MAIN -- SUBROUTINES FOLLOW
##
##------------------------------------------------------------------

sub runChecks {

    my $feat_name = shift;

    if ($util->isFivePrimePartial($feat_name)){
	print "feat_name '$feat_name' is 5'-partial\n";
    } else {
	print "feat_name '$feat_name' is not 5'-partial\n";
    }

    if ($util->isThreePrimePartial($feat_name)){
	print "feat_name '$feat_name' is 3'-partial\n";
    } else {
	print "feat_name '$feat_name is not 3'-partial\n";
    }

    if ($util->isFiveAndThreePrimePartial($feat_name)){
	print "feat_name '$feat_name' is 5'-partial and 3'-partial\n";
    } else {
	print "feat_name '$feat_name' is not 5'-partial and 3'-partial\n";
    }
}
