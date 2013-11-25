package IGS::PostgresUIDGenerator;

=head1 NAME

IGS::PostgresUIDGenerator -- IGS UID generator module query against Postgresdatabase.

=head1 SYNOPSIS

    use IGS::PostgresUIDGenerator;
    my $uid_obj = new IGS::PostgresUIDGenerator();
    my $new_id = $uid_obj->getNextID();

=head1 DESCRIPTION

This module provides a unique numeric identifier at IGS. The IDs are sequential.

=head1 METHODS

=over

=cut


use strict;
use warnings;
use DBI;
use Log::Log4perl;
use fields qw(
    batchSize
    currentID
    topID );

# Define version variables.
our $REVISION = (qw$Revision:1.0 $)[-1];
our $VERSION = '1.0';
our $VERSION_STRING = "$VERSION (Build $REVISION)";

my $db_host = "hannibal.igs.umaryland.edu";
my $log;


=item $uid_obj = new IGS::PostgresUIDGenerator($batch_size);

This method is used for instantiation of a new PostgresUIDGenerator. It returns 
an object handle. It takes an optional parameter batch_size. 

=cut

sub new($$) {
    my $class = shift;
    my $batch_size = shift;
    $log = Log::Log4perl->get_logger($class) unless defined $log;

    $batch_size = 1 unless defined $batch_size;
    $log->error("UID batch size must be a positive number.The provided '$batch_size' is invalid.")
	unless $batch_size =~ /^\d+$/;

    my $self = {};
    $self->{batchSize} = $batch_size;
    $self->{currentID} = undef;
    $self->{topID}= undef;
    $self->{dbh}= DBI->connect("dbi:Pg:database=idgen;host=$db_host",
			       'driley', 'driley9',
			       { RaiseError => 1}
			      );
    
    bless $self, $class;
}


=item $uid = $uid_obj->getNextID()

Return a new UID. The method will connect to the database and retrieve UIDs
Each call to this method, returns a new UID. Note that batches are not used
in this method.

=cut

    sub getNextID() {
        my $self = shift;
        $log = Log::Log4perl->get_logger($self) unless defined $log;
        
        my $old_id = $self->{currentID};
  
            my $dbh = $self->getDbh();
            if (defined $dbh){
                my $sqlq = "SELECT nextval('serial')";

                my $sth;
                eval {
                    $sth = $dbh->prepare($sqlq);
                    $sth->execute();
                };
                if( $@ ) {
                    die("Failed on execute: $@" );
                }
                
                my $rows = $sth->fetchall_arrayref();                
                $sth->finish() if defined $sth;

                if( @$rows != 1 ) {
                    use Data::Dumper;
                    die("Query returned ".scalar(@$rows)." rows.  There should only be one. ".Dumper( $rows ) );
                }
                
                $self->{topID} = $rows->[0]->[0];
                $self->{currentID} = $rows->[0]->[0];

            } else {
                $log->error("Problem to get db connection: $DBI::errstr");
                die "Database connection problem: $DBI::errstr" ;
            }
    
        
        if( defined( $old_id ) && $self->{currentID} == $old_id ) {
            die("CurrrentID is the same as old_id [$old_id\t$self->{currentID}]");
        }

        return $self->{currentID};
    }



=item $uid = $uid_obj->getCurrentID();

Return the current UID. This method returns undef if no current UID available

=cut

sub getCurrentID() {
    my $self = shift;
    return $self->{currentID};
}

=item $uid = $uid_obj->getDbh();

Return the database handle.

=cut

sub getDbh() {
    my $self = shift;
    return $self->{dbh};
}

=item $uid = $uid_obj->getBatchSize()

Get the batch size for this UID Genrator object

=cut

sub getBatchSize() {
    my $self = shift;
    return $self->{batchSize};
}



=item $uid = $uid_obj->setBatchSize($);

Set the batch size as the specified value

=cut

sub setBatchSize($) {
    my $self = shift;
    my $size = shift;
    $self->{batchSize} = $size;
}

1;

__END__

=back

=head1 USAGE

The following example demonstrates how to use IGS::PostgresUIDGenerator

#!/usr/bin/perl

use IGS::PostgresUIDGenerator;

# Instantiate the object and set a batch_size of 2
my $uid_obj = new IGS::PostgresUIDGenerator(2); 
my @list = ("apple", "orange");
foreach my $item (@list){
    my $uid = $uid_obj->getNextID();
    print "Item \'$item\' gets ID \'$uid\'. \n";
}
exit 0;

=head1 AUTHOR(S)

Yongmei Zhao

=cut
