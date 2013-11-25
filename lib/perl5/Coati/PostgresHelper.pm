package Coati::PostgresHelper;


# $Id: PostgresHelper.pm,v 1.14 2007-11-09 04:31:18 aganapat Exp $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME

PostgresHelper.pm - One line summary of purpose of class (or file).

=head1 VERSION

This document refers to version N.NN of PostgresHelper.pm, released MMMM, DD, YYYY.

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
use DBI;


=item $obj->connect()

B<Description:> This method establishes connections to Postgres databases
by formulating a DBI connect string according to a given hostname and
object containing attributes user, password and db.

B<Parameters:> All parameters are stored in $obj

B<Returns:> Database handle, $dbh.

=cut

sub connect {
    my ($self, @args) = @_;
    my $logger = $self->{_logger};

    $logger->debug("Running postgresql connect") if($logger->is_debug);

    my(@vendors) = DBI->available_drivers(1);

    if(join('', @vendors) !~ /Pg/) {
	$logger->logdie ("Drivers for Postgres not found%%Perl Configuration%%DBD::Pg ".
			 "is not installed.  Check the conf/<Project>.conf file to set ".
			 "the correct database vendor type%%%%Available drivers  ".
			 join(',',@vendors));
    } 

    my $user = $self->{_user};
    my $password = $self->{_password};
    my $db = $self->{_db};
    my $hostname = $self->{_server};

    my $connect_string = "DBI:Pg:dbname=$db;host=$hostname;";
    $logger->warn( __PACKAGE__ . ":\n\t\t" . join("\n\t\t", "USER - $user", "PASSWORD - $password", "DB - $db"));

    my $dbh = DBI->connect($connect_string, $user, $password,
                                 { PrintError => 0,
                                   RaiseError => 0
                                 }
			   );
#    print ("dbh:$dbh\nconnect_string:$connect_string\nuser:$user\npassword:$password\n");
    if(! $dbh){
	$logger->logdie("Invalid username/password/db access %%Database login%%The ".
			"database server [$hostname] denied access to the username ".
			"[$user].  Please check the username/password and confirm ".
			"you have permissions to access the [$db] database%%$DBI::errstr%%$db\n");
    }
    return $dbh;
}

=item $obj->modify_query_for_db() 

B<Description:> This function attempts to convert Sybase SQL to use
Postgres conventions and database commands.

B<Parameters:> SQL statement

B<Returns:> Modified SQL statement

=cut

sub modify_query_for_db {
  my ($self, $query) = @_;

  $query =~ s/\.\./\./g;
  $query =~ s/convert\s*\(\s*\w+,/\(/ig;
  #####
  # below is an example of a convert that will be substituted out 
  # with the next statement:
  # e.g for below: convert(numeric(9,0),e.accession) = a.align_id
  #####
  $query =~ s/convert\s*\(\s*\w+\(\d,\d\),/\(/ig;
  $query =~ s/datalength/LENGTH/ig;
  $query =~ s/\#/_/g;
  $query =~ s/getdate\(\)/now\(\)/g;
  $query =~ s/\+/\|\|/g;
   #####
  # HACK replace LIKE with SIMILAR TO to allow for regex matching
  $query =~ s/ like / similar to /ig;

  $query =~ s/!=\s*null/ notnull/ig;
  $query =~ s/=\s*null/ isnull/ig;

  # HACK to replace is_analysis=num with bool
  $query =~ s/is_analysis\s?=\s?0/is_analysis = false/ig;
  $query =~ s/is_analysis\s?=\s?1/is_analysis = true/ig;
  # DOUBLE HACK - cvterm table defines is_obsolete as INT (all others are boolean or bit)
  $query =~ s/is_obsolete\s?=\s?0/is_obsolete = false/ig unless ($query =~ /from\s+cvterm/i);
  $query =~ s/is_obsolete\s?=\s?1/is_obsolete = true/ig unless ($query =~ /from\s+cvterm/i);

  return $query;
}

=item $obj->commit()

B<Description:> 

    This is a dummy function in this module doing absolutely nothing. It is here 
    so that if the middle layer makes an call to this function from nonbulk object
    it will still work (i.e. script will not crash).  The real function exists in 
    BulkSybaseHelper.pm

B<Parameters:>

    None

B<Returns:>

    None

=cut

sub commit {
    my $self = shift;
}

1;

__END__

=back

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

