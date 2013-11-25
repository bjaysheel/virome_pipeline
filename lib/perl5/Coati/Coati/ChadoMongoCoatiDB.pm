package Coati::Coati::ChadoMongoCoatiDB;

=head1 NAME

ChadoMongoCoatiDB

=head1 SYNOPSIS

Overrides long-running API calls and takes advantage of denormalized tables

=head1 DESCRIPTION

This package can be used to override database-access methods in
Sybil::ChadoCoatiDB with methods that take advantage of tables not standard to
the Chado schema.

=cut

use strict;
use base qw(Coati::Coati::ChadoCoatiDB);

# Override long running queries here


1;

__END__

=head1 BUGS

Please e-mail any bug reports to sybil-devel@lists.sourceforge.net

=head1 SEE ALSO

=over 4

=item o
http://sybil.sourceforge.net

=item o
L<Sybil>

=back

=head1 AUTHOR(S)

 The Institute for Genomic Research
 9712 Medical Center Drive
 Rockville, MD 20850

=head1 COPYRIGHT

Copyright (c) 2005, The Institute for Genomic Research. 
All Rights Reserved.

=cut
