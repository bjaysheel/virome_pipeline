package Coati::BulkSybaseHelper;

# $Id: BulkSybaseHelper.pm,v 1.18 2003-12-01 23:16:33 angiuoli Exp $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME

BulkSybaseHelper.pm - One line summary of purpose of class (or file).

=head1 VERSION

This document refers to version 1.00 of BulkSybaseHelper.pm, released MMMM, DD, YYYY.

=head1 SYNOPSIS

Short examples of code that illustrate the use of the class (if this file is a class).

=head1 DESCRIPTION

=head2 Overview

An overview of the purpose of the file.

=head2 Constructor and initialization.

if applicable, otherwise delete this and parent head2 line.

=head2 Class and object methods

if applicable, otherwise delete this and parent head2 line.

=over 4

=cut


use strict;
use base qw(Coati::BulkHelper Coati::SybaseHelper);
 

=item $obj->commit()

B<Description:>

    This method excutes BCP and loads the information into the database

B<Parameters:>

    NONE

B<Returns:>

    none

=cut
 
#--------------------------------------------------------------------
# commit()
#
# Loads the data out files into the Sybase server via the
# bulk copy method
#
#--------------------------------------------------------------------
sub commit{

    my($self) = shift;
    my(@tablelist) = keys %{$self->{_dbtables}};

    foreach my $table (@tablelist){
	my($file)         = $self->_write_table($table);
	my($tableid)      = $self->{_db}."$table";
	my $database      = $self->{'_db'};
        my $server        = $self->{'_db_hostname'};
	my $user          = $self->{'_user'};
        my $password      = $self->{'_password'};
	my $bcp_error_log = "bcp_error_log";

	my $status_line = "Loading $self->{_db}.$table on server $self->{_db_hostname} from out file\n";
	print ($status_line);

	# BCP switches:
	# -b  batch size
	# -c bulk copy operation is performed using the CHARACTER datatype for all fields.  Tabs (\t) are used to delimit
	#    fields and new lines (\n) are used to delimit rows

	my $cmd = "$ENV{'BCP'} $database..$table in ${table}.out -S $server -U $user -P $password -b 500 -c -e $bcp_error_log "."-t ". "\"$BulkHelper::FIELD_DELIMITER\""."-r "."\"$BulkHelper::ROW_DELIMITER\"";
	print ("Executing the following command:\n$cmd\n");
	my $execute_status = system($cmd);
	print ("execution status: $execute_status\n");
	#unlink "${table}.out";
    }
}

#---------------------------------------------------------------------
# delete_chado_table()
#
# Delete all of the working tables in the Sybase Chado schema
#
#---------------------------------------------------------------------
sub delete_table {
    my($self, $table) = shift;
    my @tablelist;
    
    #---------------------------------
    # verify that passed table name 
    # is in list of valid tables
    #---------------------------------
    my $valid_table;
    my $valid_flag = 0;
    foreach $valid_table (@tablelist){
	if ($table eq $valid_table){
	    $valid_flag = 1;
	    next;
	}
    }
    if ($valid_flag){
	
	#-----------------------------------------
	# table belongs to list of valid tables, 
	# therefore proceed with deletions
	#-----------------------------------------
	print ("Deleting all records from: $table\n");
	
	

	my $record_count=1;
	my $row_count = 1000;

	while ($record_count != 0){
		
              
	    #----------------------------------------------
	    # Need to set row count to finite
	    # so as to not overflow the transaction log
	    #
	    #----------------------------------------------
	    $self->{PrismDB}->set_row_count($row_count);
	    $self->{PrismDB}->delete_records($table);

	    # alternative method:
	    #my $execution_string = "sqsh -U $self->{_user} -P $self->{_password} -S $self->{_db_hostname} -D $self->{_db} -H $self->{_db_hostname} -C \"DELETE table $table\"";
	    #print ("$execution_string\n");
	    #print `$execution_string`;

	    #----------------------------------------------
	    # Get the current number of rows in table
	    #----------------------------------------------
	    $record_count = $self->{_PrismDB}->chado_table_record_count($table);


	}


    }
    else{
	#----------------------------------------
	# table does not belong to list of
	# valid chado tables, therefore
	# do not proceed
	#----------------------------------------
	die "'delete_chado_table': $table does not appear to belong to list of valid chado tables";
    }
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

