package Coati::BulkMysqlHelper;

use strict;
use base qw(Coati::BulkHelper Coati::MysqlHelper);

our $FIELD_DELIMITER = "\t";
our $ROW_DELIMITER = "\n";
my $RUN_STREAM=1;

sub handle_nulls{
    my($self) = shift;
    my($data) = shift;
    for(my $i=0;$i<scalar(@$data);$i++){
	    if(@$data[$i] eq ""){
	        @$data[$i] = "\\N";
	    }
    }
}
 
sub commit{
    my($self) = shift;
    my @tablelist;
    
    $self->{_logger}->logdie("This subroutine has not been implemented for MySQL yet.  Seeing this message makes it your job to write it.");

    if(exists $ENV{COMMIT_ORDER}){
	    @tablelist = split(',',$ENV{COMMIT_ORDER});
    } else {
	    @tablelist = keys %{$self->{_dbtables}};
    }
    
    foreach my $table (@tablelist){
	    if(exists $self->{_dbtables}->{$table}){
	        my($file)  = $self->_write_table($table);
	        my($tableid) = "$table";
	        my $string = "cat $file | $ENV{PSQL} -U$self->{_user} -d$self->{_db} -c 'COPY $tableid from STDIN'";
	        print ("$string\n");
	        print `$string`;
	    }
    }
}

sub delete_all_tables {
    my($self) = shift;
    my @tablelist;

    $self->{_logger}->logdie("This subroutine has not been implemented for MySQL yet.  Seeing this message makes it your job to write it.");

    if (exists $ENV{COMMIT_ORDER}){
	@tablelist = split(',', $ENV{COMMIT_ORDER});
    }
    else{
	@tablelist = keys %{$self->{_dbtables}};
    }
    my @table_delete_list = reverse @tablelist;

    foreach my $table (@table_delete_list){
	    my($tableid) = "$table";
	    print ("Deleting all records in table:$table\n");
	    print `$ENV{PSQL} -U $self->{_user} -d $self->{_db} -h $self->{_db_hostname}  -c 'DELETE FROM $tableid'`;
#	    print STDERR ("$ENV{PSQL} -U $self->{_user} -d $self->{_db} -h $self->{_db_hostname} -c 'DELETE FROM $tableid'\n");
	}
}
sub set_row{
    my($self) = shift;
    my($table) = shift;
    if($RUN_STREAM){
	$self->_set_row_stream($table,@_);
    }
    else{
	$self->_set_row_buffered($table,@_);
    }
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


sub delete_tables{
    my ($self) = shift;
}

sub _set_row_stream{
    my($self) = shift;
    my($table) = shift;
    my(@data) = @_;
    my $logger = Coati::Logger::get_logger("BulkHelper");
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

    _dump_table($self->{_dbtables}->{$table},[\@data],"$FIELD_DELIMITER","$ROW_DELIMITER");
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
    my $logger = Coati::Logger::get_logger("BulkHelper");
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

    my $logger = Coati::Logger::get_logger("Coati");

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
	    if (defined(@$row[$i])){
		print $fh @$row[$i];
	    }
	    else {
		print $fh '\N';
	    }
	    if($i != (@$row - 1)){
		print $fh "$field_delimiter";
	    }
	}
	print $fh "$row_delimiter";
    }
}

1;

__END__
