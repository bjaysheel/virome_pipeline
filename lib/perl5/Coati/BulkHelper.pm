package Coati::BulkHelper;

# $Id: BulkHelper.pm,v 1.41 2007-09-18 13:52:28 jcrabtree Exp $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME

BulkHelper.pm - One line summary of purpose of class (or file).

=head1 VERSION

This document refers to version 1.00 of BulkHelper.pm, released MMMM, DD, YYYY.

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
use IO::File;
use Coati::Logger;

our $FIELD_DELIMITER = "\0\t";
our $ROW_DELIMITER = "\0\n";
my $RUN_STREAM=1;
my $LOGGER=undef;

sub set_row{
    my($self) = shift;
    my($table) = shift;
    if($RUN_STREAM){
	$self->_set_row_stream($table,@_);
    }
    else{
	$self->_set_row_buffered($table,@_);
    }

    $self->{_table_record_counter}->{$table}++;

}

sub output_tables{
    my($self, $filename_prefix) = @_;
    if($RUN_STREAM){
	$self->_output_tables_stream($filename_prefix);
    }
    else{
	$self->_output_tables_buffered($filename_prefix);
    }
}

sub commit{
    my($self) = shift;
}

sub handle_nulls{
    my($self) = shift;
}

sub delete_tables{
    my ($self) = shift;
}

sub _set_row_stream{
    my($self) = shift;
    my($table) = shift;
    my(@data) = @_;
    my $logger = _getLogger();

    if(!(exists $self->{_dbtables}->{$table})){

	$logger->info("Creating $table"); 
	my $file;
	$file = "$table.out";
		
	my $outputdir = "/tmp";

	my $fh;
	
	if (  (exists $self->{_gzip_bcp}) && (defined($self->{_gzip_bcp})) && ($self->{_gzip_bcp} == 1)){

	    $file .= ".gz";

	    open ($fh, ">:gzip", "$outputdir/$file$$") or die "Can't open $file for writing due to $!\n";
	}
	else {
	    $fh = IO::File->new("+>$outputdir/$file$$") or die "Can't open $file for writing due to $!\n";
	}

    	$self->{_dbtables}->{$table} = $fh;
	$logger->debug("Opening output file for $table as $outputdir/$file$$ for streaming");
    }

    _dump_table($self->{_dbtables}->{$table},[\@data],$FIELD_DELIMITER,$ROW_DELIMITER);
}

sub _set_row_buffered{
    my($self) = shift;
    my($table) = shift;
    my(@data) = @_;
    if(!(exists $self->{_dbtables}->{$table})){
	$self->{_dbtables}->{$table} = [];
    }
    my($rowcount) = scalar(@{$self->{_dbtables}->{$table}});
    push @{$self->{_dbtables}->{$table}},\@data;
}
sub _output_tables_stream{
    my ($self,$filename_prefix) = @_;
    my $logger = _getLogger();
    my $tablelist = $self->{_dbtables};

    foreach my $table (keys %$tablelist){
	close $tablelist->{$table};
	$logger->debug("Output $table");
	if($filename_prefix ne ""){
	    my $file;
	    $file = "$table.out";

	    if (  (exists $self->{_gzip_bcp}) && (defined($self->{_gzip_bcp})) && ($self->{_gzip_bcp} == 1)){

		$file .= ".gz";
	    }

	    $logger->debug("Outputing $filename_prefix$file from tmp files /tmp/$file$$") if($logger->is_debug);
	    if(! -e "/tmp/$file$$"){
		$logger->logdie("Can't find tmp output file /tmp/$file$$");
	    }

	    my $prefixfile = $filename_prefix . $file;

	    if ( (-e $prefixfile) && ( exists $self->{_id_manager}->{_append_bcp}) && (defined($self->{_id_manager}->{_append_bcp})) && ($self->{_id_manager}->{_append_bcp} == 1)){


		my $appendfile = $filename_prefix . $file . ".append";

		`mv /tmp/$file$$ $appendfile`;
		
		if(! -e "$appendfile"){
		    $logger->logdie("Can't move file /tmp/$file$$ to $appendfile");
		}
		
	    }
	    else {

		`mv /tmp/$file$$ $prefixfile`;
		if(! -e "$prefixfile"){
		    $logger->logdie("Can't move file /tmp/$file$$ to $prefixfile");
		}
	    }
	}
    }
}

sub _output_tables_buffered{

    my $logger = _getLogger();

    $logger->debug("Entered output_tables") if $logger->is_debug();

    my($self, $filename_prefix) = @_;

    my(@tablelist) = keys %{$self->{_dbtables}};
    $logger->debug("Outputing ",join(',',@tablelist),"\n");
    foreach my $table (sort @tablelist){

	my $row_count = scalar(@{$self->{_dbtables}->{$table}});
	$logger->debug("Outputting table $table with $row_count rows");
	$self->_write_table($table, $filename_prefix, $FIELD_DELIMITER, $ROW_DELIMITER);
    }
}

sub _write_table{
    my($self,$table, $file_prefix, $field_delimiter, $row_delimiter) = @_;
    
    my $file;
    if($file_prefix ne ""){
	$file = $file_prefix."$table.out";
    }
    else{
	$file = "$table.out";
    }


    if ( (-e $file) && ( exists $self->{_append_bcp}) && ($self->{_append_bcp}) && ($self->{_append_bcp} == 1)){

	$file .= ".append";
    }

    if (  (exists $self->{_gzip_bcp}) && (defined($self->{_gzip_bcp})) && ($self->{_gzip_bcp} == 1)){

	$file .= ".gz";

	open (FILE, ">:gzip", "$file") or die __PACKAGE__ . ": Can't open $file for writing due to $!\n";
    }
    else {
	open FILE, "+>$file" or die __PACKAGE__ . ": Can't open $file for writing due to $!\n";
    }

    _dump_table(*FILE,$self->{_dbtables}->{$table}, $field_delimiter, $row_delimiter);

    close FILE;

    return $file;
}

sub _dump_table{
    my($fh,$tabledata, $field_delimiter, $row_delimiter) = @_;

    foreach my $row (@$tabledata){
	for(my $i=0;$i<@$row;$i++){
	    print $fh @$row[$i];
	    if($i != (@$row - 1)){
		print $fh "$field_delimiter";
	    }
	}
	print $fh "$row_delimiter";
    }
}

sub write_table_record_counts_file {

    my $self = shift;
    my ($outfile) = @_;

    if (! exists $self->{_table_record_counter}){
	print "The table record counter does not exist\n";
	return undef;
    }

    if (!defined($outfile)){
	$outfile = '/tmp/table_record_counts.txt';
    }

    open (OUTFILE, ">$outfile") || die "Could not open file '$outfile' in write mode:$!";

    foreach my $table (sort keys %{$self->{_table_record_counter}}){
	my $count = $self->{_table_record_counter}->{$table};
	print OUTFILE "$table:$count\n";
    }

    print "The number of records created was written to '$outfile'\n";
}


# ------------------------------------------------------------------
# BulkHelper - private package methods
# ------------------------------------------------------------------

sub _getLogger {
    if (!defined($LOGGER)) {
	$LOGGER = Coati::Logger::get_logger(__PACKAGE__);
    }
    return $LOGGER;
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

