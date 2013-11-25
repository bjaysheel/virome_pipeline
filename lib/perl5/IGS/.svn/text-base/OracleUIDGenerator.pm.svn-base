package IGS::OracleUIDGenerator;

=head1 NAME

IGS::OracleUIDGenerator -- IGS Oracle UID generator module

=head1 SYNOPSIS

    use IGS::OracleUIDGenerator;
    my $uid_obj = new IGS::OracleUIDGenerator();
    my $new_id = $uid_obj->getNextID();

=head1 DESCRIPTION

This module provides a unique numeric identifier at IGS. The IDs are sequential.

=head1 METHODS

=over

=cut

BEGIN {
    $ENV{ORACLE_HOME} ||= '/usr/local/packages/oracle-11r1/product/11.1.0/client_1';
}


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


=item $uid_obj = new IGS::OracleUIDGenerator($batch_size);

This method is used for instantiation of a new OracleUIDGenerator. It returns 
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
    
    bless $self, $class;
}


=item $uid = $uid_obj->getNextID()

Return a new UID. The method will connect to the database and retrieve a batch of UIDs. 
Each call to this method, returns a new UID from the batch.

=cut

sub getNextID() {
    my $self = shift;
    $log = Log::Log4perl->get_logger($self) unless defined $log;
  
    if (defined $self->{currentID} && $self->{currentID} != $self->{topID}){
	$self->{currentID}++;
	
    } else {
	my $dbh = DBI->connect("dbi:Oracle:host=$db_host;sid=annot;port=1521",
                               'READ_APP', 'appread',
			       { RaiseError => 1}
			      );
	
	if (defined $dbh){
	    my $sql = "select util.euid.NEXTVAL from DUAL";
	    my $count = 0;
	    while ($count < $self->{batchSize}){
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while (my @rows = $sth->fetchrow_array()){
		    $self->{currentID} = $rows[0] if $count == 0;
		    $count++;
		}
		$sth->finish() if defined $sth;
		$self->{topID} = $self->{currentID} + $count - 1;
	    }
	    $dbh->disconnect();
	} else {
	    $log->error("Problem to get db connection: $DBI::errstr");
	    die "Database connection problem: $DBI::errstr" ;
	}
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

The following example demonstrates how to use IGS::OracleUIDGenerator

#!/usr/bin/perl

use IGS::OracleUIDGenerator;

# Instantiate the object and set a batch_size of 2
my $uid_obj = new IGS::OracleUIDGenerator(2); 
my @list = ("apple", "orange");
foreach my $item (@list){
    my $uid = $uid_obj->getNextID();
    print "Item \'$item\' gets ID \'$uid\'. \n";
}
exit 0;

=head1 AUTHOR(S)

Yongmei Zhao

=cut
