#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#reads ddl containing create statements from STDIN and writes ergatis compatible iterator file to STDERR
print "\$;I_TABLE_NAME\$;\n";
while(my $line=<STDIN>){
    if($line=~/CREATE TABLE/){
	($table_name) = ($line=~/CREATE TABLE (\w+)/i);
	print "$table_name\n";
    }
}
