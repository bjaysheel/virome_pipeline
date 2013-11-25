#!/usr/local/bin/perl
=head1 NAME

sql2DB.pl - Migrates BSML search/compute documents to the chado companalysis module

=head1 SYNOPSIS

USAGE:  sql2DB.pl -U username -P password -D database --database_type --server [-f file] [--force] [-l log] [-d debug] [-m man] [--exec] [--no_partition] [--query]

=head1 OPTIONS

=over 8

=item B<--username,-U>
    
    Database username

=item B<--password,-P>
    
    Database password

=item B<--database,-D>
    
    Database to be affected


=item B<--database_type>
    
    Relational database management system type e.g. sybase or postgresql

=item B<--server,-S>
    
    Name of server on which the database resides

=item B<--file,-f>
    
    instruction file containing SQL instructions to be executed in the specified database

=item B<--debug,-d>

    Optional: Coati::Logger log4perl logging level.  Default is 0

=item B<--man,-m>

    Display the pod2usage page for this utility

=item B<--help,-h>

    Print this help

=item B<--exec>

    Optional - only if either not specified or --exec=1, sql will be sent to the database (support for REFRESH_INDEXES bsml2chado workflow component toggle)

=item B<--no_partition>

    Optional - User can override table partitioning.  At this time tables on SYBIL should not be partitioned.

=item B<--query>

    Optional - If --query=1, then the result of the sent query will be print to STDOUT

=back

=head1 DESCRIPTION

=cut

use strict;
use Prism;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Pod::Usage;
use Data::Dumper;
use Coati::Logger;

$|=1;

#-------------------------------------------------------------
# Parse command line options
#-------------------------------------------------------------

my %options;
my $results = GetOptions (\%options, 
			  'username|U=s',
			  'password|P=s',
			  'database|D=s',
			  'database_type=s',
			  'file|f=s',     
			  'sql|f=s',
			  'force|f=s',
			  'log|l=s',
			  'debug|d=s',
			  'help|h',       
			  'server|S=s',
			  'exec=s',
			  'no_partition=s',
			  'query=s'
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($options{'man'});
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($options{'help'});

&print_usage if(!$options{'username'} or !$options{'password'} or !$options{'database'});

## initialize the logger
$options{'log'} = "/tmp/sql2DB.pl.log" if (!defined($options{'log'}));

my $mylogger = new Coati::Logger('LOG_FILE'=>$options{'log'},
				 'LOG_LEVEL'=>$options{'debug'});

my $logger = Coati::Logger::get_logger(__PACKAGE__);

if (( exists $options{'no_partition'}) || ($options{'no_partition'} == 1)){
    ## Yet another hook to override execution of this script.
    ## The user has specified that this script should not execute the instructions
    ## for partitioning the chado tables.
    exit(0);
}

if ((! exists $options{'exec'}) || ($options{'exec'} == 1)){
    ## if the exec option is not specified or
    ## if the exec option == 1
    ## then execute this code

    ## Use class method to verify the database vendor type
    if (! Prism::verifyDatabaseType($options{'database_type'})){
	$logger->logdie("Unsupported database type '$options{'database_type'}'");
    }


    ## Set PRISM environment variable
    &setPrismEnv($options{'server'}, $options{'database_type'});

    ## Instantiate Prism object
    my $prism = &retrieve_prism_object($options{'username'}, $options{'password'}, $options{'database'}, $options{'server'});

    if($options{'file'}){
	open (INFILE, "<$options{'file'}") or $logger->logdie("Could not open instruction file ".
							      "'$options{'file'} in read mode: $!");
	
	## since the statements go beyond a single line.
	my $instr;
	my $semicolonCounter = 0;
	my $instructions = [];

	while (my $line = <INFILE>){
	    
	    chomp $line;
	    ## Skip all blank lines
	    next if ($line =~ /^\s*$/);
	    ##  Skip SQL commented lines i.e. "--"
	    next if ($line =~ /^\-\-/);
	    
	    ## Strip leading and trailing whitespaces
	    $line =~ s/^\s+//;
	    $line =~ s/\s+$//;
	    ## Replace tabs
	    $line =~ s/\t/ /g;
	    
	    ## Strip the trailing semicolon from the statement
	    if ($line =~ /;/){
		$line =~ s/;//;
		$semicolonCounter++;
	    }
	    
	    ## Build the statement
	    $instr .= $line . " ";
	    
	    ## The statement has been completely assembled.  Store the assembled
	    ## statement on the instructions list.
	    if ($semicolonCounter > 0) {
		push (@$instructions, $instr);
		$semicolonCounter = 0;
		undef $instr;
	    }
	}
	close INFILE;
	foreach my $sql (@$instructions){
	    $sql =~ s/;\s*$//;
	    if ($options{'query'}){
		my $result = $prism->{_backend}->_get_results_ref($sql);
		if (!defined($results)){
		    $logger->logdie("results was not defined for query '$options{'sql'}'");
		}
		print "$results->[0][0]\n";
	    }
	    elsif($options{'force'}){
		$prism->{_backend}->_force_do_sql($sql);
	    }
	    else{
		$prism->{_backend}->_do_sql($sql);
	    }
	}
    }
    elsif($options{'sql'}){
	$options{'sql'} =~ s/;\s*$//;
	if ($options{'query'}){
	    my $result = $prism->{_backend}->_get_results_ref($options{'sql'});
	    if (!defined($results)){
		$logger->logdie("results was not defined for query '$options{'sql'}'");
	    }
	    print "$results->[0][0]\n";
	}
	elsif($options{'force'}){
	    $prism->{_backend}->_force_do_sql($options{'sql'});
	}
	else{
	    $prism->{_backend}->_do_sql($options{'sql'});
	}
    }
    else{
	$logger->logdie("No input file or sql specified");
    }
}
else {
    ## do not send sql to the DB
    exit(0);
}


#---------------------------------------------------------------------------------------------------------------------
#
#                                  END OF MAIN  -- SUBROUTINES FOLLOW
#
#---------------------------------------------------------------------------------------------------------------------

sub retrieve_prism_object {

    my ( $username, $password, $database, $server) = @_;

    my $prism = new Prism( 
			   user             => $username,
			   password         => $password,
			   db               => $database,
			   use_placeholders => 0,
			   );
    

    if (!defined($prism)){
	$logger->fatal("Could not create Prism object");
    }

    return $prism;

}#end sub retrieve_prism_object()


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

sub print_usage {
    die "Some error occured.";
}


