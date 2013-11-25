package Prism::BulkSybaseChadoPrismDB;

use strict;
use base qw(Prism::SybaseChadoPrismDB Prism::BulkChadoPrismDB Coati::Coati::BulkSybaseChadoCoatiDB);
use Data::Dumper;

sub test_BulkSybaseChadoPrismDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_SybaseChadoPrismDB();
}

sub testProjDB {
    my ($self, @args) = @_;
    $self->{_logger}->info("Hello from :",__PACKAGE__,"!!!\n");
    return $self->test_BulkSybaseChadoPrismDB();

}

our $RECORD_DELIMITER = '\0\n'; 
our $FIELD_DELIMITER = '\0\t'; 
use constant TEXTSIZE => 100000000;

#------------------------------------------------------------------
# doBulkLoadTable()
#
#------------------------------------------------------------------
sub doBulkLoadTable {

    my ($self, %args) = @_;

    my $infile          = $args{'infile'};
    my $table           = $args{'table'};
    my $server          = $args{'server'};
    my $database        = $args{'database'};
    my $username        = $args{'username'};
    my $password        = $args{'password'};
    my $rowdelimiter    = $args{'rowdelimiter'};
    my $fielddelimiter  = $args{'fielddelimiter'};
    my $batchsize       = $args{'batchsize'};
    my $bcperrorfile    = $args{'bcperrorfile'};
    my $featuretextsize = $args{'textsize'};
    my $testmode        = $args{'testmode'};
    my $printCommandsOnly = $args{'print_commands_only'};

    my $bcp;

    if ((defined($ENV{'BCP'})) and (exists ($ENV{'BCP'}))){
	$bcp = $ENV{'BCP'};
    }
    else {
	$self->{_logger}->logdie("BCP environment variable was not set");
    }


    my $execstring = "$bcp $database..$table in $infile -S $server -U $username ".
    "-P $password -c -b $batchsize -e $bcperrorfile -r '$RECORD_DELIMITER' -m 1 -t '$FIELD_DELIMITER' -T " . TEXTSIZE;

    if ($printCommandsOnly){
	print $execstring . "\n";
	return 0;
    }
    $self->{_logger}->warn("execstring for bcp: $execstring");
    if ($testmode){

	$self->{_logger}->info("testmode was set to '$testmode' therefore no records ".
			       "were inserted into the database");

	## Not loading any tables therefore number of rows copied = 0
	return 0;
    }
	
    my $stat = qx($execstring);
    
    ## Get the total number of rows copied to the Sybase server
    ## as reported by the BCP utility
    my $rowcount;
    
    if ($stat =~ /(\d+)\s+rows copied\./){
	    
	$rowcount = $1;
	
	if (!defined($rowcount)){
	    $self->{_logger}->logdie("row count was not defined while processing ".
				     "table '$table' - execstring was '$execstring'");
	}	
    }

    if (&bcpError($?)){
	$self->{_logger}->logdie("Error: $stat during execution of '$execstring'");
    }
    
    return $rowcount;
    
}

##------------------------------------------------------------
## bcpError()
##
##------------------------------------------------------------
sub bcpError {

    my ($error) = @_;

    $error = $error >> 8;
    
    my $retVal = ($error != 0) ? 1 : 0;

    return $retVal;	
}

#--------------------------------------------------------------
# doBulkDumpTable()
#
#--------------------------------------------------------------
sub doBulkDumpTable {

    my ($self, %args) = @_;

    my $outfile         = $args{'outfile'};
    my $table           = $args{'table'};
    my $server          = $args{'server'};
    my $database        = $args{'database'};
    my $username        = $args{'username'};
    my $password        = $args{'password'};
    my $rowdelimiter    = $args{'rowdelimiter'};
    my $fielddelimiter  = $args{'fielddelimiter'};
    my $batchsize       = $args{'batchsize'};
    my $bcperrorfile    = $args{'bcperrorfile'};
    my $featuretextsize = $args{'textsize'};

    my $bcp;
    if ((defined($ENV{'BCP'})) and (exists ($ENV{'BCP'}))){
	$bcp = $ENV{'BCP'};
    }

    my $execstring = "$bcp $database..$table out $outfile -S $server -U $username ".
    "-P $password -c -b $batchsize -e $bcperrorfile -r '$RECORD_DELIMITER' -t '$FIELD_DELIMITER' -T " . TEXTSIZE;


    $self->{_logger}->info("execstring : $execstring");
    my $stat = qx($execstring);

    #
    # Get the total number of rows copied to the Sybase server as reported by the BCP utility
    #
    my $rowcount;
    if ($stat =~ /(\d+)\s+rows copied\./){
	$rowcount = $1;
	if (!defined($rowcount)){
	    $self->{_logger}->logdie("row count was not defined while processing table '$table'");
	}	
    }
    else{
	$self->{_logger}->logdie("Could not parse stat '$stat' to retrieve the number of rows that were copied");
    }

    my $error = $?;
    $error = $error >> 8;
    $self->{_logger}->logdie("BCP reported an error value of $error, stat was: $stat") if ($error != 0);
		
    return $rowcount;
    
}







1;





__END__

=head1 ENVIRONMENT

List of environment variables and other O/S related information
on which this file relies.

=head1 DIAGNOSTICS

=over 4

=item "Error message that may appear."

Explanation of error message.

=item "Another message that may appear."

Explanation of another error message.

=back

=head1 BUGS

Description of known bugs (and any workarounds). Usually also includes an
invitation to send the author bug reports.

=head1 SEE ALSO

List of any files or other Perl modules needed by the file or class and a
brief description why.

=head1 AUTHOR(S)

 The Institute for Genomic Research
 9712 Medical Center Drive
 Rockville, MD 20850

=head1 COPYRIGHT

Copyright (c) 2002, The Institute for Genomic Research. All Rights Reserved.


