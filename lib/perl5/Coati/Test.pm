package Coati::Test;

=head1 NAME

Test.pm - Provides tools to aid in the automated testing of Coati Projects.

=head1 VERSION

This document refers to version 1.00 of Coati::Test.

=head1 SYNOPSIS

A short example of the usage of this module is:

  use Coati::Test;
  my $tester = Coati::Test->new( debug      => $debug,
                            testuser   => $testuser,
                            testpasswd => $testpasswd,
                            project    => $project,
                            url        => $url,
                            testlist   => $testlist,
                            modulelist => $modulelist,
			    notifyuser => 0,
                            backends   => { %backends },
                            paths      => { %paths },
                            rowcolors  => [ @rowcolors ],
                            schemas    => [ @schemas ],
                            profile = > 0|1
                          );
  @files = $tester->parse_list;
  my $script = $files[0];
  $tester->test_syntax($script);
  $tester->test_pod($script);
  $tester->test_function($script);

=head1 DESCRIPTION

This module is to aid in the automated and manual testing of
front-end scripts and other modules of Coati based applications.
It provides methods for testing syntax, POD formatting and
validity, as well as script/module output.

=head2 Overview

Overview here.

=head2 Class and object methods

=over 4

=cut

use strict;
use base;
use base qw(Coati::Logger);
use Carp;
use Coati::Test::Sybase;
use Coati::Test::Mysql;
use Cwd;
use Data::Dumper;
use File::Basename;      # For path parsing.
use File::Compare;       # For file comparison.
use IO::Scalar;          # Used here to capture STDOUT into a variable.
use MIME::Lite;          # For sending out mail.
use Pod::Checker;        # For POD validation.
use Pod::Select;         # To extract pod sections.

use vars qw($VERSION);
$VERSION = (qw$Revision: 1.15 $)[-1];


=item new

B<Description:> The module constructor.

B<Parameters:> %arg, a hash containing attribute-value pairs to
initialize the object with. Initialization actually occurs in the
private _init method.

B<Returns:> $self (A Coati::Test object).

=cut

sub new {
    my ($class, %arg) = @_;
    warn __PACKAGE__ . ": Running ", (split(/:/, (caller(0))[3]))[-1], ".\n" if $arg{debug};
    my $self = bless {}, ref($class) || $class;
    $self->_init(%arg);
    if ($self->debug) {
        $Data::Dumper::Purity = 1;
        warn Data::Dumper->Dump([\$self], ['*self']);
    }
    return $self;
}


=item $obj->_init([%arg])

B<Description:> Tests the Perl syntax of script names passed to it. When
testing the syntax of the script, the correct directories are included in
in the search path by the use of Perl "-I" command line flag.

B<Parameters:> %arg, a hash containing attributes to initialize the testing
object with. Keys in %arg will create object attributes with the same name,
but with a prepended underscore.

B<Returns:> None.

=cut

sub _init {
    my ($self, %arg) = @_;
    $self->_trace if $arg{debug};
    foreach my $key (keys %arg) {
        $self->{"_$key"} = $arg{$key}
    }
    $self->{_testcount} = 0;
    $self->{_sybase} = Coati::Test::Sybase->new($self);
    $self->{_mysql} = Coati::Test::Mysql->new($self);
}

#######    ACCESSORS   #########

=item $obj->debug()

B<Description:> An accessor to get the debug level of the Test object.

B<Parameters:> None. 

B<Returns:> $debug, the debug level.

=cut

sub debug { return $_[0]->{_debug} }


=item $obj->project()

B<Description:> An accessor to get the name of the project being tested.

B<Parameters:> None. 

B<Returns:> $project, the project name.

=cut

sub project { return $_[0]->{_project} }


=item $obj->testcount()

B<Description:> An accessor to get the number of tests performed.

B<Parameters:> None. 

B<Returns:> $testcount, the sequential number of the current test.

=cut

sub testcount { return $_[0]->{_testcount} }


=item $obj->notifyuser()

B<Description:> An accessor to check whether the notify flag was
set when the testmaster script was invoked. The flag enables email
notifications of errors in testing to the last user that checked in
the file being tested.

B<Parameters:> None.

B<Returns:> 1 if the flag was set, or 0 if not.

=cut

sub notifyuser { return $_[0]->{_notifyuser} }


=item $obj->url()

B<Description:> An accessor to obtain the URL to the general testing
directory on the webserver. 

B<Parameters:> None.

B<Returns:> $url, with leading "http://" included.

=cut

sub url { return $_[0]->{_url} }


=item $obj->testlist()

B<Description:> An accessor to get the name of the testlist containing
the scripts to be tested.

B<Parameters:> None.

B<Returns:> $testlist, the filename of the testlist being used.

=cut

sub testlist { return $_[0]->{_testlist} }


=item $obj->backends()

B<Description:> An accessor to get a list of the supported RDBMS
backends, such as Sybase or MySQL.

B<Parameters:> None. 

B<Returns:> @backends, a sorted list of supported database
backends.

=cut

sub backends { return sort keys %{ $_[0]->{_backends} } }


=item $obj->schemas()

B<Description:> An accessor to get a list of the biological
database schema types that the project is intended to support.
For example, the Manatee project supports both Euk and
Prok type database schemas.

B<Parameters:> None. 

B<Returns:> @backends, a sorted list of the supported schemas.

=cut

sub schemas { return sort @{ $_[0]->{_schemas} } }


=item $obj->incr_testcount()

B<Description:> An method to increment the count of tests
that have been performed. This method is called just prior
to beginning a new test, such as the test for syntax, etc...

B<Parameters:> None. 

B<Returns:> None.

=cut

sub incr_testcount { ++$_[0]->{_testcount} }


=item $obj->top()

B<Description:> Prints the beginning of the output for
summarizing the testing results. This method is overridden
in Html.pm.

B<Parameters:> None.

B<Returns:> None.

=cut

sub top {
    my ($self, @args) = @_;
    $self->_trace if $self->debug;
    print "=================== " . $self->project . " Testing Results ================\n";
}


=item $obj->heading($script)

B<Description:> Prints a row with the name of the script being tested.
This row is used to headline the test results for that script. This method
is overridden in Html.pm.

B<Parameters:> $script, the name of the script being tested.

B<Returns:> None.

=cut

sub heading {
    my ($self, $script, @args) = @_;
    $self->_trace if $self->debug;

    print "\n$script\n";
    my $separator = "-" x (length($script));
    print "$separator\n";
}


=item $obj->bottom()

B<Description:> This method is mainly empty, as in normal operation nothing
special needs to be done to format the ending of the test results summary. However,
when outputting HTML, the end of the page needs to be printed, so this method is
overridden in Html.pm.

B<Parameters:> None.

B<Returns:> None.

=cut

sub bottom {
    my ($self, @args) = @_;
    $self->_trace if $self->debug;
    # Intentionally left blank.
}


=item $obj->output($script, $test_name, $result, $DB, [$elapsed_time])

B<Description:> Runs a frontend script and processes the output
that will be used to compare future test output against.

B<Parameters:> $test_name (test name), $result, $DB and $elapsed_time (seconds).

B<Returns:> None.

=cut

sub output {
    my ($self, $script, $test_name, $result, $DB, $elapsed_time, $failure) = @_;
    $self->_trace if $self->debug;
    printf "%-35s   %-6s   %4d   %6s\n", $test_name, $DB, $elapsed_time, $result;
}


=item $obj->test_syntax($script)

B<Description:> Tests the Perl syntax of script names passed to it. When
testing the syntax of the script, the correct directories are included in
in the search path by the use of Perl "-I" command line flag.

B<Parameters:> $script.

B<Returns:> $result ( "ok" | "not ok" ).

=cut

sub test_syntax {
    my ($self, $script) = @_;
    $self->_trace if $self->debug;
    $self->incr_testcount;
    $self->_trace("This is test #" . $self->testcount . ".") if ($self->debug > 1);

    my ($command, $schema, $syntax, $synresult);
    my $context = $self->_get_toplevel($script);
    if ($context eq "shared") {
        foreach $schema ( $self->schemas ) {
            $self->_trace("Testing shared script $script under $schema conditions.")
                if ($self->debug > 2);
            # If one of the schemas to be tested does not exist, then don't
            # bother testing that one, but go to the next.
            next unless (-d $schema);

            # The .. is to reach Coati, which should be one directory back
            # in the "development" environment.
            $command = "$self->{_paths}->{perl} -I .. -I $schema -I shared -c $script 2>&1";
            $self->_trace("$command") if ($self->debug > 1);
            $syntax = qx|$command|;
            $synresult = ( $syntax =~ m/OK/ ) ? "ok" : "not ok";

            # Fall through to the return.
            last if $synresult eq "not ok";
        }
    } else {
        $command = "$self->{_paths}->{perl} -I .. -I $context -I shared -c $script 2>&1";
        $self->_trace("$command") if ($self->debug > 1);
        $syntax = qx|$command|;
        $synresult = ( $syntax =~ m/OK/ ) ? "ok" : "not ok";
    }
         
    $self->output($script, "syntax", $synresult, "N/A", "N/A");
    return $synresult; 
} 


=item $obj->test_pod($db, $script, $test_name, $params_ref)

B<Description:> Tests the validity of POD documentation of script names
passed to it. The I<podchecker> function of Pod::Checker is used.

B<Parameters:> $script.

B<Returns:> $podresult ( "ok" | "not ok" ).

=cut

sub test_pod {
    my ($self, $script) = @_;
    $self->_trace if $self->debug;
    $self->incr_testcount;
    $self->_trace("This is test #" . $self->testcount . ".") if ($self->debug > 1);

    my $pod = podchecker("$script", "/dev/null");
    my $podresult = ( $pod == 0 ) ? "ok" : "not ok";
    $self->output($script, "pod", $podresult, "N/A", "N/A");
    return $podresult;
}


=item $obj->test_function($script)

B<Description:> Tests the actual output of scripts against
known standard files.

B<Parameters:> $script.

B<Returns:> None.

=cut

sub test_function {
    my ($self, $script) = @_;
    $self->_trace if $self->debug;
    $self->_trace("Processing $script.") if $self->debug;
    my @tests = $self->_get_tests($script);
    my (@params, $testline, $test_name);
    foreach $testline (@tests) {
        $self->_trace("$script: $testline") if $self->debug;
        my ($test_name, $test) = $self->_split_testlines($testline);
        my (%dbmodstruct);
        @params = split(/\&/, $test);

        my $dbmod_testfile = "";

        # Are we a dbmod test?
        if ( $params[0] =~ m/moddb/ ) {
            # In a dbmod test the first parameter has nothing to do with CGI parameters that
            # are passed to the script. It is only used to flag a db modifying test and name the 
            # file where further information is held.
            $dbmod_testfile = ( split(/=/, shift @params) )[1];
            # Parse the file containing the parameters
            $self->_trace("Encountered a dbmod test. Parsing $dbmod_testfile.") if $self->debug;
            %dbmodstruct = $self->_parse_dbmod_testfile($dbmod_testfile);

            if ($self->debug) {
                $Data::Dumper::Purity = 1;
                warn Data::Dumper->Dump([\%dbmodstruct], ['*dbmodstruct']);
            }
        }

        # Perform the tests on Sybase and Mysql according to what kind of test it is:
        # If we are a dbmodifier, then we have to go through the loading/unloading procedure
        # using the information from the parsed testfile ($dbmod_testfile) in the $dbmodstruct hash.
        foreach my $db ( $self->backends ) {
            $self->incr_testcount;
            $self->_trace("This is test #" . $self->testcount . ".") if ($self->debug > 1);
            my ($elapsed_time, $failure, $output_result, $result);
            if ( $dbmod_testfile ) {   # Here we modify the database (Insert, Update or Delete).

                my $dbobjname = "_" . lc($db);
                $self->_trace("Using the $dbobjname object.") if $self->debug;
                # 1. Clear the databases and load repository data in.
                $self->_clear_db_tables($db, \%dbmodstruct);

                $self->{$dbobjname}->_load_table(\%dbmodstruct);

                # 2. Run the script test (Perform the db operation).
                ($output_result, $elapsed_time) = $self->check_output($db, $script, $test_name, \@params);

                # 3. Dump the db to a devel area 
                $self->{$dbobjname}->_extract_table(\%dbmodstruct);
                
                # 4. Compare dumped db file to standard db file.
                my $db_comparison_errors = $self->compare_db_flatfiles($db, \%dbmodstruct);

                if ($db_comparison_errors == 0 && $output_result eq "ok") {
                    $result = "ok";
                    $failure = undef;
                } else {
                    $result = "not ok";
                    $failure = ( $db_comparison_errors ) ? "db" : "script";
                }
                $self->output($script, $test_name, $result, $db, $elapsed_time, $failure);
            } else {
                # Here we have a normal testing procedure.
                ($result, $elapsed_time) = $self->check_output($db, $script, $test_name, \@params);
                $self->output($script, $test_name, $result, $db, $elapsed_time);
            }
        }
    }
}


=item $obj->script_output($script, $context, $params_ref)

B<Description:> Generates the output of front-end scripts
by supplying them with given CGI parameters.

B<Parameters:> $script, $context, $params_ref

B<Returns:> $result ( "ok" | "not ok" ), $elapsed_time (seconds).

=cut

sub script_output {
    my ($self, $script, $context, $params_ref) = @_;
    $self->_trace if $self->debug;
    my @params = @$params_ref;
    my $dprof;
    $dprof = $self->{profile} ? "-d:DProf" : "";
    my $command = qq|$self->{_paths}->{perl} $dprof -I .. -I $context -I shared $script @params $self->{_extraparams} 2>&1|;
    my $output = qx|$command|;
    if($? != 0){
	print STDERR "$command failed with exit code $?\n";
	#DProf is buggy and will segfault on linux (ecode: 139) but not consistently. No problems on solaris though.
	#I'm a glutton for punishment so...
	#"Thank you sir, may I have another!"
	if($? == 139){
	    unlink "core.$$";
	    return $self->script_output($script,$context,$params_ref);
	}
    }
    return $output;
}


=item $obj->check_output($db, $script, $test_name, $params_ref)

B<Description:> Checks the output of front-end scripts
by running them with CGI parameters and checking the output
against a saved /repository of expected output.

B<Parameters:> $db, $script, $test_name, $params_ref

B<Returns:> $result ( "ok" | "not ok" ), $elapsed_time (seconds).

=cut

sub check_output {
    my ($self, $db, $script, $test_name, $params_ref) = @_;
    $self->_trace if $self->debug;
    my @params = @$params_ref;
    my $context = $self->_get_toplevel($script);
    if ($context eq "shared") {
        # Then the first parameter needs to be stripped off because THAT's
        # How we know what the context is and does NOT form part of the test parameters.
        # We also need to ensure that the context is captilized because that is how
        # the schema directories are named.
        $context = ucfirst( lc( (split('=', shift(@params)))[1] ) );
        $self->_trace("Running shared script \"$script\" under $context context.") if $self->debug;
    }

    $self->_set_environment($context, $db);

    my ($elapsed_time, $output, $result, $scriptbase, $time_start, $time_stop);
    
    $scriptbase = $self->_get_filebase($script);
    
    $self->_set_DBI_profile($db, "devel", $scriptbase, $test_name) if($self->{dbi_profile});

    $time_start = time;
    $output = $self->script_output($script, $context, \@params);
    $time_stop = time;
    $elapsed_time = $time_stop - $time_start;

    $result = $self->_write_and_compare($db, $output, $scriptbase, $test_name);
    if ($result ne 'ok' && $self->notifyuser) {
	my ($author,$rev,$log) = $self->_find_last_cvs_modification("../$context/", $script);
	$self->_notify_user($author, $script, $test_name, $db, $context, $rev, $log);
    }

    return ($result, $elapsed_time);
}


=item $obj->_find_last_cvs_modification($script)

B<Description:> Checks the CVS revision history to find information about the last modification.

B<Parameters:> $script

B<Returns:> $author, $rev, $date, $lines, $log.

=cut

sub _find_last_cvs_modification {
    my ($self, $dir, $script) = @_;
    my ($author, $log, $rev);
    my ($currdir) = getcwd;
    chdir $dir;
    open (STATUS_CMD, "cvs status $script|");
    while (my $status_line = <STATUS_CMD>) {
	if ( $status_line =~ /Working revision/) {
	    ($rev) = ($status_line =~ /Working revision:\s+([\d.]+)/);
	}
    }
    open (LOG_CMD, "cvs log -r$rev -N $script|");
    while ( my $log_line = <LOG_CMD> ) {
	if ($log_line =~ /^date/){
	    ($author) = ($log_line =~ /author\:\s+(\w+)\;/);
	    $log .= $log_line;
	} elsif ($log ne "") {
	    $log .= $log_line;
	}
    }
    chdir $currdir;
    return $author, $rev, $log;
}	


=item $obj->_notify_user($user, $script, $testname, $db, $context, $rev, $log)

B<Description:> Notify user of a failed test.

B<Parameters:> $user, $script, $testname, $db, $context, $rev, $log

B<Returns:> None.

=cut

sub _notify_user {
    my ($self, $user, $script, $testname, $db, $context, $rev, $log) = @_;
    my $scriptbase = $self->_get_filebase($script); 
    my $testfile = $scriptbase."_".$testname.".html";

    my $project = $self->project;
    my $projectlc = lc($project);
    my $url = $self->url;

    my $message = <<"    _END_MAIL";
    You are being notified of a build error because $user perfomed the last modification of $script
        PROJECT:$project
        SCRIPT:$script
        REVISION:$rev
        TEST:$testname
        DB:$db
        CONTEXT:$context
    Most recent CVS log for $script:

    _END_MAIL

    # Strip leading white space.
    $message =~ s/^\w{4}//ms;
    $message .= ">>>\n" .
                "$log\n" .
                ">>>\n\n" .
                "The diff output for the test is available at " .
                "$url/$project/testing/diff/$db/$testfile \n" .
		    "Complete test results are available at $url/$project/testing/testresults.html";

    my $email = MIME::Lite->new(
                 From    =>"${projectlc}_testing\@tigr.org",
                 To      =>"$user\@tigr.org",
                 Subject =>"BUILD ERROR :: $project :: $script $rev :: $testname",
                 Type    =>'TEXT',
                 Data    =>"$message"
                 );  
    $email->send();
}				


=item $obj->module_output($db, $script, $testcount, @structs)

B<Description:> Formats data structures passed to it for comparison with
standard files. Uses Data::Dumper to output the data structures.

B<Parameters:> $db, $script, $testcount, @structs

B<Returns:> $result ("ok" | "not ok").

=cut

sub module_output {
    my ($self, $db, $script, $testcount, @structs) = @_;
    $self->_trace if $self->debug;
    my ($output, $result, $struct, $scriptbase);
    $scriptbase = $self->_get_filebase($script);

    foreach $struct (@structs) {
        $output .= Dumper($struct) . "\n";
    }
    $result = $self->_write_and_compare($db, $output, $scriptbase, "METHODTEST$testcount");
    return $result;
}


=item $obj->make_standards($db, $script)

B<Description:> Runs a I<project> script and saves the generated output as the standard file
that will be used to compare future test output against.

B<Parameters:> $db, $script.

B<Returns:> None.

=cut

sub make_standards {
    my ($self, $db, $script) = @_;
    $self->_trace if $self->debug;
    my $top = $self->_get_toplevel($script);
    my @tests = $self->_get_tests($script);
    my (@params, $result, $testline, $test_name, $output);
    foreach $testline (@tests) {
        my ($test_name, $test) = $self->_split_testlines($testline);
        @params = split(/\&/, $test);
        $self->_trace("$script: @params") if ($self->debug > 1);
        my $context = $top;
        if ($top eq "shared") {
            $context = (split('=', shift(@params)))[1];
        }

        $self->_set_environment($context, $db);
	my $scriptbase = $self->_get_filebase($script);
	$self->_set_DBI_profile($db, "standard", $scriptbase, $test_name) if($self->{dbi_profile});;

        $output = $self->script_output($script, $context, \@params);

        $self->_write_standard($db, $output, $scriptbase, $test_name);
	$self->output($script, $test_name, "created standard", $db, "N/A", "N/A");
    }
}

=item $obj->make_consensus_standard($script)

B<Description:> Compares standards across db vendors and creates consensus file.

B<Parameters:> $script,@dbs.

B<Returns:> None.

=cut

sub make_consensus_standard {
    my ($self, $script, @dbs) = @_;
    $self->_trace if $self->debug;
    my $top = $self->_get_toplevel($script);
    my @tests = $self->_get_tests($script);
    my (@params, $result, $testline, $test_name, $output);
    foreach $testline (@tests) {
        my ($test_name, $test) = $self->_split_testlines($testline);
        @params = split(/\&/, $test);
        $self->_trace("$script: @params") if ($self->debug > 1);
	my $scriptbase = $self->_get_filebase($script);
	my $directory = ($test_name =~ m/METHODTEST/) ? "../" : "";

	my $refdb = $dbs[0];
	
	my $refstandardfile = "${directory}testing/standard/${refdb}/${scriptbase}_${test_name}";
	my $constandardfile = "${directory}testing/standard/${scriptbase}_${test_name}";
	`cp $refstandardfile $constandardfile`;
	my($status) = "ok";
	my ($diffs);
	foreach my $db (@dbs){
	    my($dbstandardfile) = "${directory}testing/standard/${db}/${scriptbase}_${test_name}";
	    my($diffcommand) = "diff $constandardfile $dbstandardfile";
	    my($dbdiff) = `$diffcommand`;
	    if($dbdiff ne ""){
		$status = "not ok";
		$diffs .= "$db ";
		`$diffcommand > $dbstandardfile.diff`;
	    }
	    else{
		unlink "$dbstandardfile.diff";
	    }
	}
	if($status eq "not ok"){
	    $self->output($script, $test_name, "$status :: Error comparing standard file for $diffs", "CONSENSUS", "N/A");
	}
	else{
	    $self->output($script, $test_name, $status, "CONSENSUS","N/A", "N/A");
	}
    }
}


=item $obj->_get_toplevel($script)

B<Description:> Given the relative path from the I<project> root to a script,
return the parent directory of the script. Typically, this will be either
"euk", "prok" or "shared", if working in the I<project> development environment.

B<Parameters:> $script.

B<Returns:> $toplevel.

=cut

sub _get_toplevel {
    # We need to know what level we are in, whether Euk, Prok, or shared
    # so that we know where to find the necessary modules.
    my ($self, $script, @args) = @_;
    $self->_trace if $self->debug;
    my $toplevel = (split(/\//, $script))[0];
    return $toplevel;
}


=item $obj->_get_tests($script)

B<Description:> A function to extract the DIAGNOSTICS section of script,
parse out and return the contained test lines.

B<Parameters:> $script.

B<Returns:> @tests.

=cut

sub _get_tests {
    my ($self, $script) = @_;
    $self->_trace if $self->debug;
    $self->_trace("Extracting tests for $script.") if $self->debug;
    my $parser = new Pod::Select();
    my $diagnostic_pod;

    # We need to do some wrangling to STDOUT
    # because Pod::Select outputs there. We use
    # IO::Scalar to capture the output into a variable.
    tie *STDOUT, "IO::Scalar", \$diagnostic_pod;
    $parser->select("DIAGNOSTICS");
    $parser->parse_from_file($script);
    untie *STDOUT;

    my @diagnostic_lines = split(/\n/, $diagnostic_pod);
    my @tests = grep(/^\s*\w+:/, @diagnostic_lines);
    return @tests;
}

=item $obj->get_individual_test($script, $test_name)

B<Description:> Given a I<project> script and the name of a test,
extract the string containing the test parameters. If there
is no test matching the name provided, then return undef.

B<Parameters:> $testline.

B<Returns:> $test (or undef).

=cut

sub get_individual_test {
    my ($self, $script, $test_name) = @_;
    $self->_trace if $self->debug;
    my @tests = $self->_get_tests($script);

    my $testline;
    foreach $testline (@tests) {
        my ($candidate_name, $candidate_test) = $self->_split_testlines($testline);
        return $candidate_test if ( $test_name eq $candidate_name );
    }
    return undef;
}


=item $obj->_split_testlines($testline)

B<Description:> Given a testline from a DIAGNOSTICS section in POD,
extract and return the name of the test and the the string containing
the test parameters.

B<Parameters:> $testline.

B<Returns:> $test_name, $test.

=cut

sub _split_testlines {
    my ($self, $testline) = @_;
    $self->_trace if $self->debug;
    my ($test, $test_name);
    ($test_name = $testline) =~ s/^\s*(\w+):.*$/$1/;
    ($test = $testline) =~ s/^\s*$test_name:\s*//;
    return ($test_name, $test);
}

=item $obj->compare_db_flatfiles($db, $dbmodstruct_ref)

B<Description:> Creates development files and compares them to known standards. Not exported.

B<Parameters:> $db, $output, $scriptbase, $testname.

B<Returns:> $return ( "ok" | "not ok" ).

=cut

sub compare_db_flatfiles {
    my ($self, $db, $dbmodstruct_ref) = @_;
    $self->_trace if $self->debug;
    my @tables = keys %{ $dbmodstruct_ref->{$db}->{tables} };
    my ($devel_db_file, $standard_db_file);
    my $error_count = 0;
    foreach my $table (@tables ) {
        my $flatfile = $dbmodstruct_ref->{$db}->{tables}->{$table}->[0];
        my $devel_db_file = "$self->{_paths}->{devel}/$db/$flatfile";  
        my $stand_db_file = "$self->{_paths}->{stand}/$flatfile";  
        my $comparison_result = (compare("$stand_db_file", "$devel_db_file") == 0) ? 0 : 1;
        $error_count = $error_count + $comparison_result; 
    }
    return $error_count;
}

=item $obj->_set_DBI_profile

B<Description:> Activates DBI profiling and sets appropriate output directory

B<Parameters:> $db, $type, $scriptbase, $testname

B<Returns:> 

=cut

sub _set_DBI_profile {
    my ($self, $db, $type, $scriptbase, $testname) = @_;
    $self->_trace if $self->debug;
    my $directory = ($testname =~ m/METHODTEST/) ? "../" : "";

    my $dbilogfile;
    if($type eq "devel"){
	$dbilogfile = "${directory}testing/$type/${db}/${scriptbase}_${testname}.dbi.log";
    }
    elsif($type eq "standard"){
	$dbilogfile = "${directory}testing/$type/${db}/${scriptbase}_${testname}.dbi.log";
    }
    
    $ENV{PERL5LIB} = "$self->{_paths}->{dbi}";
    $ENV{DBI_PROFILE} = 10;
    $ENV{DBI_TRACE} = "0=$dbilogfile";
}
    

=item $obj->_write_and_compare($db, $output, $scriptbase, $testname)

B<Description:> Creates development files and compares them to known standards. Not exported.

B<Parameters:> $db, $output, $scriptbase, $testname.

B<Returns:> $return ( "ok" | "not ok" ).

=cut

sub _write_and_compare {
    my ($self, $db, $output, $scriptbase, $testname) = @_;
    $self->_trace if $self->debug;
    # The method level test scripts also make use of this subroutine
    # but they do so from within the prok or euk directories. We need to
    # be able to tell if we are testing a front-end script or a module, and
    # use the appropriate pathway to the testing output repositories.
    my $directory = ($testname =~ m/METHODTEST/) ? "../" : "";

    my $develfile = "${directory}testing/devel/${db}/${scriptbase}_${testname}";
    my $standardfile = "${directory}testing/standard/${scriptbase}_${testname}";
    
    if($self->{profile}){
	my $proffile = "${directory}testing/devel/${db}/${scriptbase}_${testname}.prof";
	`$self->{_paths}->{dprofpp} -r > $proffile`;
	unlink "tmon.out";
    }
    
    open (DEVEL, ">", "$develfile")
        or croak "Could not open testing $develfile file for write, stopped";
    print DEVEL "$output";
    close (DEVEL)
        or croak "Could not close filehandle, stopped";

    # Here we use a File::Compare function.
    my $result;
    my $difffile = "${directory}testing/diff/${db}/${scriptbase}_${testname}";
    if (-f $standardfile) {
	$result = (compare("$standardfile", "$develfile") == 0) ? "ok" : "not ok";
	if ($result ne "ok") {
	    `diff $develfile $standardfile > $difffile`;
	}
    } else {
	$result = "missing standard";
	open DIFF_FILE,"+>$difffile";
	print DIFF_FILE "CREATE STANDARD FILE USING ./testmaster --makestandards script_name\n";
	close DIFF_FILE;
    }
    return $result;
}


=item $obj->_write_standard($db, $output, $scriptbase, $testname)

B<Description:> A function to save the standard files for testing (not exported).
The method level test scripts also make use of this subroutine
but they do so from within the prok or euk directories. It is necessary
to distinguish when we are testing a front-end script or a module, and
use the appropriate path to the output repositories.

B<Parameters:> ($db, $output, $scriptbase, $testname)

B<Returns:> None.

=cut

sub _write_standard {
    my ($self, $db, $output, $scriptbase, $testname) = @_;
    $self->_trace if $self->debug;
    my $directory = ($testname =~ m/METHODTEST/) ? "../" : "";

    my $standardfile = "${directory}testing/standard/${db}/${scriptbase}_${testname}";

    if($self->{profile}){
	my $proffile = "${directory}testing/standard/${db}/${scriptbase}_${testname}.prof";
	`$self->{_paths}->{dprofpp} -r > $proffile`;
	unlink "tmon.out";
    }

    open (STANDARD, ">$standardfile")
        or croak "Could not open ${scriptbase}_${testname} for write, stopped";
    print STANDARD "$output";
    close (STANDARD)
        or croak "Could not close filehandle, stopped";
}


=item $obj->_parse_dbmod_testfile($dbmod_testfile)

B<Description:> This method takes a filename of a file in the I<project> testing/dbmod
directory that contains information used for tests that perform changes to the database.
In other words, for tests that perform updates, inserts, or deletes on the database, a
file is required in the dbmod directory that details which database/tables must be reloaded
at the conclusion of the test. This method parses those files and returns a hash data structure
with the data called %dbmodstruct.

B<Parameters:> $dbmod_testfile.

B<Returns:> %dbmodstruct.

=cut

sub _parse_dbmod_testfile {
    my ($self, $dbmod_testfile, @args) = shift;
    $self->_trace if $self->debug;
    my %dbmodstruct;
    open (MOD, "testing/dbmod/$dbmod_testfile")
         or croak "Could not open $dbmod_testfile, stopped";

    my $flag = 0;
    my $backend;
    my $backend_regx = qr{[(Sybase|Mysql|Postgres)]};
    while (<MOD>) {
        chomp;
        my $line = $_;
        next if ( $line =~ m/^\s*\#/ );  # Skip comment lines.
        if ( $line =~ m/$backend_regx/i ) {
            $flag = 1;
            $backend = $1;
        }
        $flag or next;
        if ( $line =~ m/=/ ) {
            # We split on white-space.
            my ($setting, $value) = split ('\s*=\s*', $line); 
            if ( $setting eq "table" ) {
                my @table_data = split (':', $value);
                my $table_name = shift @table_data;
                $dbmodstruct{$backend}->{tables}->{$table_name} = [ @table_data ];
            } else {
                $dbmodstruct{$backend}->{$setting} = $value;
            }
        }
    }
    close MOD or croak "Could not close $dbmod_testfile, stopped";
    return %dbmodstruct;
}


=item _clear_db_tables($db, $dbmodstruct_ref)

B<Description:> Given a database type, or backend (such as "Sybase"),
and $dbmodstruct_ref, which holds the results of parsing the "dbmod" configuration file,
clear the configured tables of all data by issuing "truncate" SQL commands.

B<Parameters:> $db, $dbmodstruct_ref.

B<Returns:> None.

=cut

sub _clear_db_tables {
    my ($self, $db, $dbmodstruct_ref) = @_;
    $self->_trace if $self->debug;
    my $database = $dbmodstruct_ref->{$db}->{database};

    my $dbobjname = "_" . lc($db);
    my $dbh = $self->{$dbobjname}->_connect($database);

    $dbh->do("use $database");

    my @tables = keys %{ $dbmodstruct_ref->{$db}->{tables} };
    my $sth;
    foreach my $table (@tables) {
        my $query = "TRUNCATE TABLE $table";
        $self->_trace("Query: $query.") if ($self->debug > 1);
        $sth = $dbh->prepare($query) or warn '*** Warning: Could not prepare "$query."';
        $sth->execute() or warn '*** Warning: Could not execute "$query."';
    }
}


=item _get_filebase($file)

B<Description:> A method to strip off the suffix of filenames passed to it.

B<Parameters:> $file.

B<Returns:> $filebase.

=cut

sub _get_filebase {
    my ($self, $file) = @_;
    $self->_trace if $self->debug;
    # fileparse is a File::Basename function.
    my $filebase = (fileparse($file, '\..*'))[0];
    return $filebase;
}

=item _set_environment($context, $db)

B<Description:> A method to set the project environment variable that controls
which RDBMS backend and server to use.

B<Parameters:> $context, $db.

B<Returns:> None.

=cut

sub _set_environment {
    my ($self, $context, $db, @args) = @_;
    $self->_trace if $self->debug;
    my $project = uc($self->project);
    $ENV{$project} = "$context:$db:$self->{_backends}->{$db}";
    $self->_trace("Setting $project environment variable to $ENV{$project}.") if $self->debug;
}


=item parse_list()

B<Description:> From a given configuration file containing a list of file paths,
parse the file, ignoring blank lines and comments, and return an array of files
to be tested.

B<Parameters:> None.

B<Returns:> @files.

=cut

sub parse_list {
    my ($self, @args) = @_;
    $self->_trace if $self->debug;
    my @files;
    open (LIST, "<", $self->testlist)
        or croak "Could not open " . $self->testlist . " for read, stopped";

    while (<LIST>) {
        my $file = $_;
        # Ignore lines that start with a hash or whitespace
        # followed by hash. Also ignore blanks lines.
        next if ($file =~ m/^\s*\#/ or $file !~ m/\w/ );
        chomp $file;
        if (-f "../$file") {
            push (@files, $file);
        } else {
            warn qq|*** Warning: "$file" in $self->{_testlist} does not exist.\n|;
        }
    }
    close LIST;
    return @files;
}

1;            # For the "use" or "require" to succeed.

__END__

=back

=head1 ENVIRONMENT

This module sets a PROJECT environment variable where PROJECT is the
name of the Coati based project being tested. This environment variable
controls the operation of the scripts, including which RDBMS to use, what
server to connect to for the RDBMS, and what context (database schema,
e.g. Euk, Prok, Synteny) to run under.

=head1 DIAGNOSTICS

=over 4

=item "*** Warning: Could not prepare <query>.

A SQL query could not be prepared. Please check the query for
syntax, or consult the RDBMS documentation.

=item "*** Warning: Could not execute <query>.

A SQL query could not be executed. Please check the query for
syntax, or consult the RDBMS documentation.

=item "*** WARNING: <file> in <testlist> does not exist."

A file in the specified testlist (default of "testlist") did not
exist. Testing could not proceed and the test series for that file
was skipped.

=back

=head1 BUGS

No known bugs. Please contact Authors to report bugs.

=head1 SEE ALSO

The following other modules are required for this module to work correctly.

  Carp
  Coati::Test::Html
  Coati::Test::Sybase
  Coati::Test::Mysql
  Cwp
  Data::Dumper
  File::Basename
  File::Compare
  IO::Scalar
  MIME::Lite
  Pod::Checker
  Pod::Select

=head1 AUTHOR(S)

 The Institute for Genomic Research
 9712 Medical Center Drive
 Rockville, MD 20850

=head1 COPYRIGHT

Copyright (c) 2002, The Institute for Genomic Research. All Rights Reserved.
