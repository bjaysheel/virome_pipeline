package IGS::UIDGenerator;

=head1 NAME

IGS::UIDGenerator -- IGS UID generator module

=head1 SYNOPSIS

    use IGS::UIDGenerator;
    my $uid_obj = IGS::UIDGenerator($db_type, $batch_size)->new();
    my $new_id = $uid_obj->get_next_id();

=head1 DESCRIPTION

This module provides a unique numeric identifier at IGS. The IDs are sequential.

=head1 METHODS

=over

=cut

use strict;
use warnings;
use Log::Log4perl;
use Carp;

=item $uid_obj = new IGS::UIDGenerator($db_type, $batch_size);

This method is used for instantiation of a new UIDGenerator. It returns 
an object handle. It takes an optional parameter batch_size. 

=cut

sub new($$$) {
    my $class = shift;
    my $db_type = shift;
    my $batch_size = shift;
    my $log = Log::Log4perl->get_logger($class);
    
    if (defined $db_type){
	if ( lc($db_type) eq "mysql"){
	    $db_type = "Mysql";
	} elsif ( lc($db_type) eq "oracle"){
	    $db_type = "Oracle";
	} else {
	    $log->error("DB type is not a valid type: $db_type. Please specify either 'Mysql' or 'Oracle' as db_type");
	}
    } else {
	croak("No db_type provided.");
    }

    $class = "IGS::".$db_type."UIDGenerator" ;
    $batch_size = 1 unless defined $batch_size;
    my $module = "IGS/".$db_type."UIDGenerator.pm";
    require $module;

    return $class->new(@_);
}

1;


__END__

=back

=head1 USAGE

The following example demonstrates how to use IGS::UIDGenerator

#!/usr/bin/perl

use IGS::UIDGenerator;

# Instantiate the object and set a batch_size of 2
my $uid_obj = new IGS::UIDGenerator("mysql",2); 
my @list = ("apple", "orange");
foreach my $item (@list){
    my $uid = $uid_obj->get_next_id();
    print "Item \'$item\' gets ID \'$uid\'. \n";
}
exit 0;

=head1 AUTHOR(S)

Yongmei Zhao

=cut
