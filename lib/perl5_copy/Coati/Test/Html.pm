package Coati::Test::Html;

# $Id: Html.pm,v 1.7 2003-12-01 23:16:37 angiuoli Exp $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME

Html.pm - A module for providing HTML output methods to Coati::Test.

=head1 VERSION

This document refers to version 1.00 of Html.pm, released MMMM, DD, YYYY.

=head1 SYNOPSIS

use Coati::Test::Html;
$obj = Coati::Test::Html->new();

(constructor located in Coati::Test.)

$obj->top;
$obj->heading($script);
$obj->bottom;

=head1 DESCRIPTION

=head2 Overview

This module inherits from Coati::Test and overrides some of its methods for
how testing output is generated. This module formats output from Coati::Test
in HTML.

=over 4

=cut

use vars qw($VERSION);
$VERSION = (qw$Revision: 1.7 $)[-1];

use strict;
use Date::Format;     # For easy formatting of date and time.
use base qw(Coati::Test);

=item $obj->get_rowcolors()

B<Description:> An accessor to get the list of colors to use in
for row backgrounds in the test results page. If no colors are
configured when the Test object was created, then the accessor
will return a default list of values corresponding to "white"
backgrounds, ie ( "#FFFFFF", "#FFFFFF").

B<Parameters:> None. Any parameters passed will be silently ignored.

B<Returns:> A list containing the configured colors to alternate
between when generating HTML output summarizing the test results.

=cut

sub get_rowcolors {
    # We need to check if the _rowcolors attribute has been set
    # and if we have the correct number of elements (2). If not,
    # then return "white" values as defaults.
    if (exists ($_[0]->{_rowcolors})
        && ( @{$_[0]->{_rowcolors}} == 2 ) ) {
        return @{ $_[0]->{_rowcolors} };
    } else {
        return ("#FFFFFF", "#FFFFFF");
    }
}


=item $obj->get_url()

B<Description:> An accessor to get the list of colors to use in
for row backgrounds in the test results page. If no colors are
configured when the Test object was created, then the accessor
will return a default list of values corresponding to "white"
backgrounds, ie ( "#FFFFFF", "#FFFFFF").

B<Parameters:> None. Any parameters passed will be silently ignored.

B<Returns:> A list containing the configured colors to alternate
between when generating HTML output summarizing the test results.

=cut

sub get_url { return $_[0]->{_url} }


=item $obj->top()

B<Description:> Prints the beginning of the HTML for the page
summarizing the testing results. This method overrides I<top>
in Test.pm.

B<Parameters:> None.

B<Returns:> None.

=cut

sub top {
    my ($self, @args) = @_;
    $self->_trace if $self->debug;

    my $datetime = $self->get_date;
    my $name = $self->project;

    my $top = <<"    _TOP";
    <html>
    <head>
    <title>$name Testing Results</title>
    </head>
    <body>
    <center><h1>$name Testing Results</h1>
    <h3>Generated: $datetime</h3>
    <hr>
    <p>
    <table width="600" border="1" cellpadding="0" cellspacing="0">
    _TOP

    # Delete the indents.
    $top =~ s/^[^\S\n]+//gm;
    print "$top";
}


=item $obj->heading($script)

B<Description:> Prints a table row with the name of the script being tested.
This row is used to headline the test results for that script. This method overrides
I<heading> in Test.pm.

B<Parameters:> $script, the name of the script being tested.

B<Returns:> None.

=cut

sub heading {
    my ($self, $script, @args) = @_;
    $self->_trace if $self->debug;
    print qq|<tr><td align="center" colspan="7"><b>$script</b></td><tr>\n|;
}


=item $obj->bottom()

B<Description:> Completes the html page generated for the test results, by
closing all the introductory html tags.

B<Parameters:> None.

B<Returns:> None.

=cut

sub bottom {
    my $bottom = <<"    _BOTTOM";
    </table>
    </center>
    </body>
    </html>
    _BOTTOM
    $bottom =~ s/^[^\S\n]+//gm;
    print "$bottom";
}


=item $obj->output($script, $test_name, $result, $db, $elapsed_time [, $failure])

B<Description:> Outputs testresults in HTML format. This method overrides
I<output> in Coati::Test.

B<Parameters:> $script, $test_name, $result, $db, $elapsed_time, $failure.

  $script       - The path of the script from the relative to the Project directory
                  as found in the testlist.
  $test_name    - The name of the test performed from the script's POD diagnostic section.
  $result       - The test's result ( "ok" or "not ok" ).
  $db           - The backend RDBMS the script was tested against. Currently Sybase and Mysql
                  are supported.
  $elapsed_time - The number of seconds the test took to complete.
  $failure      - The reason for script failure. This is an optional parameter that is only
                  used when performing tests that modify the test database.

B<Returns:> None.

=cut

sub output {
    my ($self, $script, $test_name, $result, $db, $elapsed_time, $failure) = @_;
    $self->_trace if $self->debug;
    my @rowcolors = $self->get_rowcolors;
    my $testcount = $self->testcount;

    my $bgcolor = ( $testcount % 2 == 0 ) ? $rowcolors[0] : $rowcolors[1];
    my $icon = ( $result eq "ok" ) ? "green.png" : "red.png";

    if ($failure eq "db" ) { $icon = "db.png" };  # This only happens on dbmod tests. 

    my $row;



    if ( $elapsed_time !~ m/\D/ ) {
	my($context);
	if($script =~ /shared/){ 
	    $context = (lc($test_name) =~ /euk/) ? 'euk' : 'prok';
	}
	else{
	    $context = (lc($script) =~ /euk/) ? 'euk' : 'prok';
	}
	my($scriptbase) = $self->_get_filebase($script); 
	my $templatename = lc("$scriptbase".".tt");
	my($testfile) = $scriptbase."_".$test_name.".html";
        # If $elapsed time does not contain non-digits.
        $row = qq|
            <tr bgcolor="$bgcolor">
              <td>$test_name</td>
              <td>$db</td>
              <td align="center">$elapsed_time</td>
              <td width="16" align="center" nowrap="1">
                  <a href="devel/$db/$testfile" target="_blank"><img src="/images/menu-images/d.png" width="16" height="16" border="0" alt="Devel"></a>&nbsp;&nbsp;<a href="/tigr-scripts/${context}_manatee/shared/rendertemplate.cgi?template=$templatename&keysfile=/ifx/devel/manatee/devel/Manatee/testing/devel/$db/$testfile" target="_blank">html</a>
              </td>
              <td width="16" align="center" nowrap="1">
                  <a href="standard/$db/$testfile" target="_blank"><img src="/images/menu-images/s.png" width="16" height="16" border="0" alt="Standard">&nbsp;&nbsp;<a href="/tigr-scripts/${context}_manatee/shared/rendertemplate.cgi?template=$templatename&keysfile=/ifx/devel/manatee/devel/Manatee/testing/standard/$db/$testfile" target="_blank">html</a></a>
		      </td>|;
	if ($result ne "ok") {
	    $row .= qq|
              <td width="16" align="center">
                  <a href="diff/$db/$testfile" target="_blank"><img src="/images/menu-images/diff.png" width="32" height="16" border="0" alt="Diff"></a>
		      </td>|;
	} else {
	    $row .= "<td>&nbsp;</td>";
	}
	$row .= qq|
              <td width="16" align="center">
                  <img src="/images/menu-images/$icon" width="16" height="16" alt="$result">
              </td>
            </tr>\n|;
    } else {
        # If we are here then the test was for POD or Syntax as elapsed time is "N/A".
        $row = qq|
            <tr bgcolor="$bgcolor">
              <td>$test_name</td>
              <td colspan="5">$db</td>
              <td width="16" align="center"><img src="/images/menu-images/$icon" width="16" height="16" alt="$result">
              </td>
            </tr>\n|;
    }
    print "$row";
}


=item $obj->get_date()

B<Description:> Uses a template to format the system time in a human readable way.

B<Parameters:> None.

B<Returns:> $date (formatted).

=cut

sub get_date {
    my ($self, @args) = @_;
    # Here we use Date::Format.
    my $template = '%X, %Y-%m-%d';
    my $date = time2str($template, time);
    return $date;
}

1;

__END__

=back

=head1 ENVIRONMENT

This module does not use or set any environment variables.

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

  Date::Format
  Coati::Logger
  Coati::Test
  Coati::Test::Mysql
  Coati::Test::Sybase

=head1 AUTHOR(S)

 The Institute for Genomic Research
 9712 Medical Center Drive
 Rockville, MD 20850

=head1 COPYRIGHT

Copyright (c) 2002, The Institute for Genomic Research. All Rights Reserved.

