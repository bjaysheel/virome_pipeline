package Sybase::Systables::Reporter;

=head1 NAME

Sybase::Systables::Reporter.pm

=head1 VERSION

1.0

=head1 SYNOPSIS

use Sybase::Systables::Reporter;


=head1 AUTHOR

Jay Sundaram
sundaram@jcvi.org

=head1 METHODS


=over 4

=cut

use strict;
use Carp;
use Data::Dumper;
use Sybase::Systables::DBUtil;


use constant TRUE  => 1;
use constant FALSE => 0;

use constant INDEX_LIST => 0;
use constant CONSTRAINT_LIST => 1;


=item new()

B<Description:> Instantiate Sybase::Systables::Reporter object

B<Parameters:> None

B<Returns:> reference to the Sybase::Systables::Reporter object

=cut

sub new  {

    my $class = shift;

    my $self = {};

    bless $self, $class;

    return $self->_init(@_);

}

=item $self->_init(%args)

B<Description:> Typical Perl init() method

B<Parameters:> %args

B<Returns:> None

=cut

sub _init {

    my $self = shift;
    my (%args) = @_;

    foreach my $key (keys %args){
	$self->{"_$key"} = $args{$key};
    }

    if ((exists $self->{_dbutil}) && (defined($self->{_dbutil}))){

	## okay

    } else {
	my $dbutil = new Sybase::Systables::DBUtil(username => $self->{_username},
						   password => $self->{_password},
						   server   => $self->{_server},
						   database => $self->{_database},
						   vendor   => $self->{_vendor});

	if (!defined($dbutil)){
	    confess "Could not instantiate Sybase::Systables::DBUtil";
	}

	$self->{_dbutil} = $dbutil;
    }



    my $outfile = $self->_getOutFile(@_);

    open (OUTFILE, ">$outfile") || confess "Could not open output file '$outfile' in write mode: $!";

    return $self;
}


=item DESTROY

B<Description:> BSML::Validation::Factory class destructor

B<Parameters:> None

B<Returns:> None

=cut

sub DESTROY  { 

    my $self = shift;

}

sub generateReport {

    my $self = shift;
    my (%args) = @_;


    if ($self->_dataNotRetrieved()){
	$self->_retrieveData(@_);
    }

    if ($self->{_tables_processed_ctr} > 0 ){
	$self->_writeResults();
    }
}

sub _retrieveData {

    my $self = shift;
    my (%args) = @_;

    my $tableList = $self->_getTableList(@_);

    my $ctr=0;

    foreach my $table (@{$tableList}){

	print "Processing table '$table'\n";

	$ctr++;

	my $indexList = $self->{_dbutil}->getIndexList(table=>$table);
	if (!defined($indexList)){
	    confess "Could not retrieve index list for table '$table'";
	}

	my $constraintList = $self->{_dbutil}->getConstraintList(table=>$table);
	if (!defined($constraintList)){
	    confess "Could not retrieve constraint list for table '$table'";
	}

	$self->_formatResults($table, $indexList, $constraintList);
    }

    print "Processed '$ctr' tables\n";

    $self->{_tables_processed_ctr} = $ctr;

    $self->{_data_retrieved} = TRUE;

}

sub _dataNotRetrieved {

    my $self = shift;

    if (( exists $self->{_data_retrieved}) && 
	( defined($self->{_data_retrieved})) &&
	( $self->{_data_retrieved} == TRUE )){

	return FALSE;
    } 

    return TRUE;
}


sub _formatResults {

    my $self = shift;
    my ($table, $indexList, $constraintList) = @_;

    $self->{_lookup}->{$table} = [$indexList, $constraintList];

}


sub getIndexCountByTable {

    my $self = shift;
    my ($table) = @_;

    if ($self->_dataNotRetrieved()){
	$self->_retrieveData(@_);
    }

    if (( exists $self->{_index_count_lookup}->{$table}) && 
	( defined($self->{_index_count_lookup}->{$table}))){
	return $self->{_index_count_lookup}->{$table};
    }

    if (( exists $self->{_lookup}->{$table}) && 
	( defined($self->{_lookup}->{$table}->[INDEX_LIST]))){
	
	my $count = scalar($self->{_lookup}->{$table}->[INDEX_LIST]);
	$self->{_index_count_lookup}->{$table} = $count;
	return $self->{_index_count_lookup}->{$table};
    }

    warn "index count for table '$table' was not defined\n";

    return undef;
}

sub printIndexesByTable {

    my $self = shift;
    my ($table) = @_;

    if ($self->_dataNotRetrieved()){
	$self->_retrieveData(@_);
    }

    if (( exists $self->{_lookup}->{$table}) && 
	( defined($self->{_lookup}->{$table}->[INDEX_LIST]))){
	
	foreach my $index (@{$self->{_lookup}->{$table}->[INDEX_LIST]}){
	    print $index . "\n";
	}
    } else {

	warn "There are no indexes for table '$table'\n";
	print Dumper $self->{_lookup}->{$table};die;
    }
}

sub getConstraintCountByTable {

    my $self = shift;
    my ($table) = @_;

    if ($self->_dataNotRetrieved()){
	$self->_retrieveData(@_);
    }

    if (( exists $self->{_constraint_count_lookup}->{$table}) && 
	( defined($self->{_constraint_count_lookup}->{$table}))){
	return $self->{_constraint_count_lookup}->{$table};
    }

    if (( exists $self->{_lookup}->{$table}) && 
	( defined($self->{_lookup}->{$table}->[CONSTRAINT_LIST]))){
	
	my $count = scalar($self->{_lookup}->{$table}->[CONSTRAINT_LIST]);
	$self->{_constraint_count_lookup}->{$table} = $count;
	return $self->{_constraint_count_lookup}->{$table};
    }

    warn "constraint count for table '$table' was not defined\n";

    return undef;
}

sub printConstraintsByTable {

    my $self = shift;
    my ($table) = @_;

    if ($self->_dataNotRetrieved()){
	$self->_retrieveData(@_);
    }

    if (( exists $self->{_lookup}->{$table}) && 
	( defined($self->{_lookup}->{$table}->[CONSTRAINT_LIST]))){
	
	foreach my $constraint (@{$self->{_lookup}->{$table}->[CONSTRAINT_LIST]}){
	    print $constraint . "\n";
	}
    } else {

	warn "There are no constraints for table '$table'\n";
    }
}

sub _writeResults {

    my $self = shift;

    my $indexCtr=0;
    my $constraintCtr=0;
    my $tableCtr=0;

    foreach my $table (keys %{$self->{_lookup}}){
	
	$tableCtr++;

	print OUTFILE "table: $table\n";

#	my $indexCtr=0;
	if ((defined($self->{_lookup}->{$table}->[INDEX_LIST])) && 
	    ( scalar($self->{_lookup}->{$table}->[INDEX_LIST]) > 0)){

	    my $indexList = $self->{_lookup}->{$table}->[INDEX_LIST];

	    print OUTFILE "index list:\n";

	    foreach my $index (@{$indexList}){
		print OUTFILE "\t$index\n";
		$indexCtr++;
	    }

	}

	if ($indexCtr == 0 ){
	    print OUTFILE "No indexes\n";
	}


#	my $constraintCtr=0;

	if ((defined($self->{_lookup}->{$table}->[CONSTRAINT_LIST])) &&
	    ( scalar($self->{_lookup}->{$table}->[CONSTRAINT_LIST]) > 0)){

	    my $constraintList = $self->{_lookup}->{$table}->[CONSTRAINT_LIST];

	    print OUTFILE "constraint list:\n";

	    foreach my $constraint (@{$constraintList}){
		print OUTFILE "\t$constraint\n";
		$constraintCtr++;
	    }

	} 

	if ($constraintCtr == 0){
	    print OUTFILE "No constraints\n";
	}

	print OUTFILE "\n";
    }


    $self->{_table_ctr} = $tableCtr;
    $self->{_index_ctr} = $indexCtr;
    $self->{_constraint_ctr} = $constraintCtr;

    print OUTFILE "Number of tables: '$tableCtr'\n";
    print OUTFILE "Number of indexes: '$indexCtr'\n";
    print OUTFILE "Number of constraints: '$constraintCtr'\n";

}

sub getTableCount {

    my $self = shift;
    if (( exists $self->{_table_ctr}) && (defined($self->{_table_ctr}))){
	return $self->{_table_ctr};
    } else {
	warn "table count was not defined";
	return undef;
    }
}

sub getIndexCount {

    my $self = shift;
    if (( exists $self->{_index_ctr}) && (defined($self->{_index_ctr}))){
	return $self->{_index_ctr};
    } else {
	warn "index count was not defined";
	return undef;
    }
}

sub getConstraintCount {

    my $self = shift;
    if (( exists $self->{_constraint_ctr}) && (defined($self->{_constraint_ctr}))){
	return $self->{_constraint_ctr};
    } else {
	warn "constraint count was not defined";
	return undef;
    }
}

sub setTableList {

    my $self = shift;
    my ($tableList) = @_;

    if (!defined($tableList)){
	confess "table list was not defined";
    }

    $tableList =~ s/\s+//g; ## remove all white space

    my $ctr=0;

    my @tables = split(/,/,$tableList);
    
    foreach my $table (@tables){
	push(@{$self->{_table_list}}, $table);
	$ctr++;
    }	

    print "Added '$ctr' tables to the table list\n";
}

sub getTableList {

    my $self = shift;

    if (( exists $self->{_table_list}) && (defined($self->{_table_list}))){
	return $self->{_table_list};
    } else {
	print "table list was not defined\n";
	return undef;
    }
}

sub _getTableList {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{table_list}) && (defined($args{table_list}))){

	$self->{_table_list} = $args{table_list};

    } elsif (( exists $self->{_table_list}) && (defined($self->{_table_list}))){
	## okay

    } else {

	print "Will retrieve the table list from the database ".
	"'$self->{_database}' on server '$self->{_server}'\n";

	my $tableList = $self->{_dbutil}->getTableList();

	$self->{_table_list} = $tableList;

    }

    return $self->{_table_list};
}

sub _getOutFile {

    my $self = shift;
    my (%args) = @_;

    if (( exists $args{outfile}) && (defined($args{outfile}))){

	$self->{_outfile} = $args{outfile};
	return $self->{_outfile};

    } elsif (( exists $self->{_outfile}) && (defined($self->{_outfile}))){
	return $self->{_outfile};
    } else {
	confess "outfile was not defined\n";
    }
}

sub getOutFile {

    my $self = shift;

    if (( exists $self->{_outfile}) && (defined($self->{_outfile}))){
	return $self->{_outfile};
    } else {
	warn "outfile was not defined";
	return undef;
    }

}



sub getTablesProcessedCount {

    my $self = shift;

    if (( exists $self->{_tables_processed_ctr}) && 
	( defined($self->{_tables_processed_ctr}))){
	return $self->{_tables_processed_ctr};
    } else {
	return undef;
    }
}



1==1; ## End of module
