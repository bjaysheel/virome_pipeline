#!/usr/local/bin/perl
#reads ddl containing create statements from STDIN and writes ergatis compatible iterator file to STDERR

use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);

$|=1;

my ($foreign_keys_only, $exclude_primary_keys, $indices_only, $primary_key_indices_only, $database_type, $logfile, $outfile, $infile);

my $results = GetOptions (
			  'foreign_keys_only=s' => \$foreign_keys_only,
			  'indices_only=s' => \$indices_only,
			  'primary_key_indices_only=s' => \$primary_key_indices_only,
			  'exclude_primary_keys=s' => \$exclude_primary_keys,
			  'database_type=s' => \$database_type,
			  'logfile=s' => \$logfile,
			  'outfile=s' => \$outfile,
			  'infile=s' => \$infile
			  );

if (!defined($outfile)){
    die "outfile was not defined";
}
if (!defined($infile)){
    die "infile was not defined";
}
if (!defined($logfile)){
    $logfile = '/tmp/ddl2iterator.pl.log';
}

open (LOGFILE, ">$logfile") || die "Could not open log file '$logfile' for output: $!";
open (INFILE, "<$infile") || die "Could not open in file '$infile' in read mode: $!";

my $semicolonCounter=0;
my $instr;
my $instructions;

while(my $line=<INFILE>){
    chomp $line;
    ## Skip all blank lines
    next if ($line =~ /^\s*$/);
    ##  Skip SQL commented lines i.e. "--"
    next if ($line =~ /^\-\-/);

    ## Strip leading and trailing whitespaces
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    ## Replace tabs
    $line =~ s/\t/ /g;

    ## Strip the trailing semicolon from the statement
    if ($line =~ /;/){
	$line =~ s/;//;
	$semicolonCounter++;
    }

    ## Build the statement
    $instr .= $line . " ";

    ## The statement has been completely assembled.  Store the assembled
    ## statement on the instructions list.
    if ($semicolonCounter > 0) {

	if ($foreign_keys_only){ ## user specified that only foreign key constraints should be manipulated
	    if ($instr !~ /FOREIGN KEY/){ 
		## this sql instruction has nothing to do with foreign key constraints, so skip it
		$semicolonCounter = 0;
		undef $instr;
		next;
	    }
	}
	
	if ($indices_only){ ## user specified that only indices should not be manipulated
	    if (($instr =~ /INDEX pk_/) || ($instr =~ /FOREIGN KEY/)){
		## this sql instruction has something to do with primary keys or foreign keys, so skip it
		$semicolonCounter = 0;
		undef $instr;
		next;
	    }
	}
	
	if ($primary_key_indices_only){ ## user specified that only primary key indices should be manipulated
	    if ($instr  !~ /INDEX pk_/){
		## this sql instruction has nothing to primary key indices, so skip it
		$semicolonCounter = 0;
		undef $instr;
		next; 
	    }
	}

	push (@{$instructions}, $instr);
	$semicolonCounter = 0;
	undef $instr;
    }
}

close INFILE;

my $finalInstructions = [];
my $instructionCtr=0;
my $pkInstrCtr=0;
my $fkInstrCtr=0;
my $otherInstrCtr=0;
my $excludedPkCtr=0;

foreach my $sqlStmt ( @{$instructions}){
    if ($sqlStmt =~ /FOREIGN KEY/){
	$fkInstrCtr++;
    }
    elsif ($sqlStmt =~ /pk_/){
	$pkInstrCtr++;
	if ((defined($exclude_primary_keys)) && ($exclude_primary_keys == 1)){
	    print LOGFILE "Excluding '$sqlStmt'\n";
	    $excludedPkCtr++;
	    next;
	}
    }
    else {
	$otherInstrCtr++;
    }

    push(@{$finalInstructions}, $sqlStmt);
}

open (OUTFILE, ">$outfile") || die "Could not open out file '$outfile' in write mode: $!";

print OUTFILE "\$;I_SQLNUM\$;\t\$;I_TABLE_NAME\$;\t\$;I_SQL\$;\n";
for(my $i=0;$i<@$finalInstructions;$i++){
    my $sql = $finalInstructions->[$i];

    print OUTFILE "SQL_$i\t";
    my $table_name;
    if($sql=~/TABLE (\w+)/i){
	($table_name) = ($sql=~/TABLE (\w+)/i);
    }
    elsif($sql=~/VIEW (\w+)/i){
	($table_name) = ($sql=~/VIEW (\w+)/i);
    }
    elsif($sql=~/ON (\w+)/i){
	($table_name) = ($sql=~/ON (\w+)/i);
    }


    if (!defined($table_name)){
	if (!defined($database_type)){
	    die "table name and database type were not defined while processing instruction '$sql'";
	}
	else {
	    ## database_type is defined
	    if (lc($database_type) eq 'postgresql'){
		print OUTFILE "NotAvailable\t";
	    }
	    else {
		if ($sql =~ /DROP/){
		    if ($sql =~ /(\S+)\.\S+/){
			$table_name = $1;
			print OUTFILE "$table_name\t";
		    }
		    else {
			die "Could not extract table name from instruction '$sql'";
		    }
		}
		else {
		    die "table name was not defined in instruction '$sql' with database_type '$database_type'";
		}
	    }
	}
    }
    else {
	## table_name was defined
	print OUTFILE "$table_name\t";
    }

    print OUTFILE " $sql\n";
}


close OUTFILE;

print LOGFILE "Counted '$pkInstrCtr' primary key instructions\n";
print LOGFILE "Excluded '$excludedPkCtr' primary key instructions\n";
print LOGFILE "Counted '$fkInstrCtr' foreign key instructions\n";
print LOGFILE "Counted '$otherInstrCtr' other index instructions\n";

close LOGFILE;


exit(0);
