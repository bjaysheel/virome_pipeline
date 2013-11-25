package Coati::TableIDManager;

use strict;
use Data::Dumper;
use Digest::MD5 qw(md5);

=head1 NAME

TableIDManager.pm - Manage incrementing ids for database tables

=head1 VERSION

This document refers to version 1.00 of Logger.pm, released MMMM, DD, YYYY.

=head1 SYNOPSIS

The required parameter 'max_func' must be a reference to a subroutine.
This subroutine will be called with two paramters $table and $field.

sub mymaxfunc{
        my($table,$field) = @_;
        #return max id of field for $table
	return $maxid;
}


    use Coati::TableIDManager

    $id_manager = new Coati::TableIDManager('max_func'=>\&mymaxfunc);

    $id_manager = new Coati::TableIDManager('max_func'=>sub {
                                                        my ($table,$field) = @_;
                                                        return $self->getMaxId($table,$field);
                                                        });

    $id_manager = new Coati::TableIDManager('max_func'=>sub {
                                                        my ($table,$field) = @_;
                                                        my $query = "SELECT max($key) " .
                                                                    "FROM $table ";
                                                        my @res = $self->{_backend}->_get_results($query);
							return $res[0][0];
                                                        });
=head1 DESCRIPTION

=head2 Overview

This module allows for the management of database ids outside of the
database.  The module requires a function 'max_func' that will be used
to obtain the current maximum id for any field.

=over 4

=cut

sub new {
    my $classname = shift;
    my $self = {};
    bless($self,$classname); 


    $self->{_logger} = Coati::Logger::get_logger(__PACKAGE__);

    $self->{_max_func} = \&testgetMaxIDs;
    $self->{_placeholders} = 0;
    $self->{_logger}->debug("Init $classname") if $self->{_logger}->is_debug;
    $self->_init(@_);
 
    $self->{_TABLEIDS} = {};
    $self->{_IDLOOKUP} = {};
    if($self->{_placeholders}){
	#placeholder ids start at 0.
	#take form: $table_$id
	$self->{_max_func} = \&testgetMaxIDs; 
	$self->{_logger}->debug("Using placeholders") if $self->{_logger}->is_debug;
    }
    else{
        if(! exists $self->{_max_func}){
	    $self->{_logger}->error("No function specified to obtain max ids. See POD for more information");
	}
    }

    return $self;
}

sub DESTROY{
    my $self = shift;
}

sub _init {
    my $self = shift;
    my %arg = @_;
    foreach my $key (keys %arg) {
	$self->{_logger}->debug("Storing member variable $key as $key=$arg{$key}") if $self->{_logger}->is_debug;
        $self->{"_$key"} = $arg{$key}
    }

}

sub nextId { 
    my($self,$table,$uniqstr) = @_;
    my $idname = "$table"."_id";
    if(! (exists $self->{_TABLEIDS}->{$table})){
	$self->_new_table($table, $idname);
    }
    my($id) =  $self->_increment_id($table);
    
    if ($self->{_placeholders}) {
	$id = ";;$table;;"."_$id";
    }
    elsif ( $self->{_checksum_placeholders} ) {
	$id = Digest::MD5::md5_hex($uniqstr);
    }

    $self->{_logger}->debug("Using id $id for $table with uniquestr $uniqstr") if($self->{_logger}->is_debug());
    $self->{_IDLOOKUP}->{$table}->{$uniqstr} = $id;

    return $id;
}

sub lookupId {
    my($self,$table,$uniqstr) = @_;

    $self->{_logger}->debug("table:$table\tuniqstr:$uniqstr") if $self->{_logger}->is_debug;


    return $self->{_IDLOOKUP}->{$table}->{$uniqstr};
}

sub _new_table{
    my($self,$table, $idname) = @_;
    $self->{_logger}->debug("Creating new entry for table $table field $idname") if($self->{_logger}->is_debug());
    my($maxid) = $self->{_max_func}($table,$idname);
    $self->{_logger}->debug("Returned maxid $maxid") if($self->{_logger}->is_debug());
    $self->{_TABLEIDS}->{$table} = ++$maxid;
    $self->{_logger}->debug("maxid $maxid incremented before storing") if($self->{_logger}->is_debug());
}

sub _increment_id{

    my($self,$table) = @_;

    $self->{_logger}->debug("Will increment id $self->{_TABLEIDS}->{$table}") if($self->{_logger}->is_debug());

    if ((exists $self->{_append_bcp}) && (defined($self->{_append_bcp})) && ($self->{_append_bcp} == 1)){


	$self->{_TABLEIDS}->{$table} = ++$self->{_next_bcp_values}->{$table};

	return $self->{_TABLEIDS}->{$table};
	
    }
    else {
	return $self->{_TABLEIDS}->{$table}++;
    }
}

sub testgetMaxIDs{
    my($table,$field) = @_;
    #this is a dummy function and should only be used for testing
    return 0;
}

1;
