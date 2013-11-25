package Coati::LogTimingAspect;

=head1 NAME

Coati::LogTimingAspect.pm

=head1 SYNOPSIS

A utility class used to log how long it takes to execute method calls in a given 
set of packages.

=head1 DESCRIPTION

This class is an Aspect that can be used to capture timing and other profiling 
data for all subroutine calls in a set of packages.  Certain types of subroutines 
must be excluded from profiling because they are not compatible with the current 
(0.11) version of Aspect.pm, on which this class depends.  The problem lies with 
the Hook::LexWrap package used by Aspect.pm; this package functions by redefining 
each of the subroutines in the pointcut, causing problems with some.  Subroutines 
known to cause problems with the current Hook::LexWrap include:

o all constant subroutines
o AUTOLOAD 

AUTLOAD causes problems because Hook::LexWrap changes the effective package of the 
$AUTOLOAD magic variable when it redefines the subroutine.  If the code to be 
profiled contains AUTOLOAD subroutines--and these subroutines must be profiled--
then a workaround is to rewrite them so that the bulk of the AUTOLOAD code is moved 
into a helper subroutine (e.g., _autoload_helper)  The helper subroutine should then 
be called from the original AUTOLOAD subroutine, passing the correct value for 
$AUTOLOAD to it.  The helper method *will* be included among the profiled methods 
since the value of $AUTOLOAD is passed as a regular subroutine argument.

This package has been tested with the core Coati and Sybil packages but care 
should be taken when using it with other packages, particularly those that may 
contain constant subroutines or "special" subroutines like AUTOLOAD that may be 
sensitive to the changes introduced by Hook::LexWrap.  Any such "problem" subroutines
must be explicitly excluded from the pointcut used for profiling by modifying the
source code of the package.

=cut

# TODO:
#  1. Make 'excluded packages' a configurable option?
#  2. Make the path to the timing directory configurable; currently it's
#     relative to the cwd, which isn't ideal.
#  3. Investigate what happens if 2 instance of LogTimingAspect are used on 
#     overlapping pointcuts.  Will this work correctly?  Should a (modified)
#     singleton pattern be used to prevent this?
#  4. Add an option to record the subroutine call result sizes, instead of the
#     full value (e.g., just the number of rows returned by a database access
#     method, not all the data.)  Similar options should be available to handle
#     large parameter values in a more flexible fashion; the current code uses
#     Data::Dumper with an arbitrary depth setting.
#  5. Figure out whether we really need to be using BenchMark::Timer, as we're
#     not making use of any of its statistical capabilities.  The goal of 
#     this class is simply to output logging information that can be processed
#     later to generate summary data.
#  6. Figure out how to handle issue of dynamically-loaded packages.

use strict;
no strict 'refs';

use Data::Dumper;
use Aspect;
use Benchmark::Timer;
use File::Find;
# ------------------------------------------------------------------
# Use all available related Modules
# ------------------------------------------------------------------
BEGIN {
my $include_modules = sub {
	if( $_ =~ /(Coati|Sybil|CMR).*\.pm$/ ) {
	       $INC{$_} = $File::Find::name;
		   #require $_;
		
	}


    };
find($include_modules, @INC);
}
# ------------------------------------------------------------------
# Globals
# ------------------------------------------------------------------

my $DEFAULT_STRINGIFIER = sub {
    my($data) = @_;
    my $dd = Data::Dumper->new([ $data ]);
    $dd->Indent(0)->Terse(1)->Maxdepth(1);
    return $dd->Dump();
};

# ------------------------------------------------------------------
# Constructor
# ------------------------------------------------------------------

# $invocant       - The class or object on whose behalf the constructor was invoked.
# $packageNames   - A listref of package names whose subroutine calls will be logged
# $paramStringFn  - (optional) function used to stringify subroutine parameters,
#                   which are passed as a listref
# $retvalStringFn - (optional) function used to stringify subroutine return values,
#                   which are passed as either a scalar or a listref
#
sub new {
    my($invocant, $packageNames, $paramStringFn, $retvalStringFn) = @_;

    $paramStringFn = $DEFAULT_STRINGIFIER if (!defined($paramStringFn));
    $retvalStringFn = $DEFAULT_STRINGIFIER if (!defined($retvalStringFn));

    my $class = ref($invocant) || $invocant;
    my $self = { 'param_string_fn' => $paramStringFn, 'retval_string_fn' => $retvalStringFn };

    my $packageRegex = '(' . join("|", @$packageNames) . ')';

    # lists (stacks) of "started" calls, indexed by subroutine name
    # an "open" call is one for which we've seen the "before" but not the "after"

    # hashref that maps a subroutine name to a listref of "started" calls for that subroutine
    # a "started" call is one that has hit the "before" advice but not the "after" advice
    # when the program has completed these listrefs should all be empty
    $self->{'started_calls'} = {};
	$self->{'started_calls_list'} = [];

    # hashref that maps a subroutine name to a listref of "finished" calls for that subroutine
    # listref of all "finished" calls; a "finished" call is one that has hit both the "before" 
    # and "after" advice as calls are completed (i.e., the subroutine returns) their info. is 
    # moved from the started_calls array to the finished_calls array
    $self->{'finished_calls'} = [];

    # a counter used to track the total number of subroutine call and return events; it
    # is incremented every time a subroutine in the pointcut is called or returns.  It
    # is also used as a unique id for the Benchmark::timer::start and stop calls (to
    # prevent interference between different concurrent invocations of the same method)
    $self->{'counter'} = 0;

    $self->{'timer'} = Benchmark::Timer->new();
    $self->{'log_file_path'} = "Coati/Timing";
    bless($self, $class);
    
    # The pointcut for this aspect will be all the subroutines under the
    # packages in @packageNames (i.e., all subroutines defined in the named
    # packages, plus those in any subpackages.)
    my $pointcut = call sub {
        my $subName = shift;
	return ($subName =~ /^$packageRegex\:\:/)
	    # these subroutines must be excluded, as Hook::LexWrap does not handle them correctly:
	    && ($subName !~ /\:\:_IO[NFL]BF$/) # filehandle-related constant subroutines
	    && ($subName !~ /\:\:AUTOLOAD$/)
	    # other excluded subroutines:
	    && ($subName !~ /Coati\:\:LogTiming/) # don't include this package or its subpackages
	    && ($subName !~ /\:\:DESTROY$/)

		;

    };
   
    # We'll keep track of the number of times we see a given call,
    # and how long we have spent processing it.
    before {
	my $context  = shift;
	my $sub = $context->{'sub_name'};
	my $startedCalls = $self->{'started_calls'}->{$sub};
	$startedCalls = $self->{'started_calls'}->{$sub} = [] if (!defined($startedCalls));
	my $callNum = ++$self->{'counter'};
	my $paramString = &{$self->{'param_string_fn'}}(\@{$context->{'params'}});
	# HACK - pull out the raw sql
	if( $sub =~ /_get_results/ || $sub =~ /_do_sql/ || $sub =~ /_get_lookup_db/ ) {
		my $parent = $self->{'started_calls_list'}->
			[@{$self->{'started_calls_list'}}-1]->{'sub_name'};
		
	 $self->{'started_calls'}->{$parent}->[@{$self->{'started_calls'}->{$parent}}-1]->{'SQL'} = $context->{'params'}->[1];
	}
	else {
		my $callInfo = { 'sub_name' => $sub, 'call_num' => $callNum, 'params' => $paramString };

	# push call info onto stack of called methods
	push(@$startedCalls, $callInfo);
	push(@{$self->{'started_calls_list'}},$callInfo);
	$self->{'timer'}->start($callNum);
	}
    } $pointcut;

    # Record the pertinent information following the call
    after {
		my $context = shift;
		my $sub = $context->{'sub_name'};

		# Retrieve SQL from calls to _get_results_ref and place this information in the
		# parent call so an elapsed time for the query can be determined and the SQL
		# for the query can be parsed from the log

		if($sub !~ /_get_results/ && $sub !~ /_do_sql/  && $sub !~ /_get_lookup_db/ ) {
			
		pop @{$self->{'started_calls_list'}};
	my $startedCalls = $self->{'started_calls'}->{$sub};
	my $lastCall = pop @$startedCalls;
	
	if (!defined($lastCall)) {
	    # internal error
	    die "LogTimingAspect internal error - no record of a call to subroutine '$sub'\n";
	} else {
	    # record elapsed time
	    $lastCall->{'return_num'} = ++$self->{'counter'};

	    ###
	    ### Notice here how the time for this subroutine will be
	    ### subtracted from any parents it might have.
	    ###
	    $lastCall->{'elapsed_time'} += $self->{'timer'}->stop($lastCall->{'call_num'});
	    foreach my $parentSub (keys %{$self->{'started_calls'}}) {
		foreach my $call (@{$self->{'started_calls'}->{$parentSub}}) {
		    $call->{'elapsed_time'} -=$lastCall->{'elapsed_time'};
		}
	    }
	    # record return value (Aspect::Advice should pass along the context to the advice method):

	    ###############################################
	    # For now, to save log file space, we are NOT #
	    # recording return values                     #
	    ###############################################

	    # case 1: list context
	    if (wantarray) {
		$lastCall->{'context'} = 'list';
		#$lastCall->{'retval'} = &{$self->{'retval_string_fn'}}(\@{$context->{'return_value'}});
	    }
	    # case 2: scalar context (i.e., wantarray is defined but false)
	    elsif (defined wantarray) {
		$lastCall->{'context'} = 'scalar';
		#$lastCall->{'retval'} = &{$self->{'retval_string_fn'}}($context->{'return_value'});
	    }
	    # case 3: void context - no return value computed
	    else {
		$lastCall->{'context'} = 'void';
	    }

	    my $finishedCalls = $self->{'finished_calls'};
	    $finishedCalls = $self->{'finished_calls'} = [] if (!defined($finishedCalls));
	    push(@$finishedCalls, $lastCall);
	}}
    } $pointcut;
    
   return $self;
}

sub DESTROY {
    my $self = shift;
    $self->printLogFile();
}


####################
### Helper Functions
####################

# Print all the captured call information to a filehandle.
sub printLoggedCalls {
    my ($self, $fh) = @_;

    # TODO - print a preamble to the log file with a bunch of handy info

    # check that no unfinished calls remain; print some warnings if they do
    my $startedCalls = $self->{'started_calls'};
    foreach my $sub (keys %$startedCalls) {
	my $calls = $startedCalls->{$sub};
	my $nc = scalar(@$calls);
	if ($nc > 0) {
	    $fh->print("WARNING - $nc unfinished calls for subroutine $sub\n");
	}
    }
    
    # print all calls in chronological order of call (not return)
    my $finishedCalls = $self->{'finished_calls'};
    my @sortedCalls = sort { $a->{'call_num'} <=> $b->{'call_num'} } @$finishedCalls;

    foreach my $call (@sortedCalls) {
#		if( $call->{'SQL'} ) {
			foreach my $key ('call_num', 'return_num', 'sub_name', 'params', 'elapsed_time', 'context', 'retval', 'SQL') {
				my $val = $call->{$key};
				if( $val ) {
					$fh->print("$key: $val\n");
				}
			}
		
			$fh->print("\n");
	#	}
    }
}

# Print the timing report to a file
sub printLogFile {
    my $self = shift;
    my $pid = $$;
    my $cgi = $0;
    $cgi =~ s/\..*//;
    $cgi =~ s/.*\///;



    while( -e ($self->{'log_file_path'}."/$pid\_$cgi\_timing.txt") ) {
	$pid++;
    }
    open OUT, ">".$self->{'log_file_path'}."/$pid\_$cgi\_timing.txt" 
	or die "Unable to open ".$self->{'log_file_path'}.
	"/$pid\_$cgi\_timing.txt";

    $self->printLoggedCalls(\*OUT);
    close OUT;
}

1;

__END__

=head1 BUGS

Please e-mail any bug reports to sybil-devel@lists.sourceforge.net

=head1 SEE ALSO

=over 4

=item o
Aspect-Oriented Programming (AOP)

=item o
L<Aspect>

=item o
http://sybil.sourceforge.net

=back

=head1 AUTHOR(S)

 The Institute for Genomic Research
 9712 Medical Center Drive
 Rockville, MD 20850

=head1 COPYRIGHT

Copyright (c) 2006, The Institute for Genomic Research. 
All Rights Reserved.

=cut
