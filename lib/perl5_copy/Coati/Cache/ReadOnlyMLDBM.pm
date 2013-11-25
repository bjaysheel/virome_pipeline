package Coati::Cache::ReadOnlyMLDBM;

use strict;
use base qw(MLDBM);
use Coati::Logger;


#require DB_File;

#$DB_File::ReadOnly::ISA = qw(DB_File);


sub STORE  {  }
sub DELETE {  }
sub CLEAR  {  }

1;
