package Coati::Web::Template;

=head1 NAME

Coati::Web::Template - Web extension to the Coati package to transform
HTML templates.

=head1 VERSION

This document refers to Coati::Web::Template revision $\Revision$
($\Date$), released under the package $Name$.

=head1 SYNOPSIS

 my $template = new Manatee::GetManateeTemplate('FILE'=>"phone_numbers.tt",
                        'TEMPLATE_EXT'=>"tigr",
                        'URL_HANDLER'=>new Manatee::GetManateeURLs(),
                                               'USE_CACHE'=>1,
                        'CACHE_DEPS'=>$Manatee->getProjectDeps(),
                        'CACHE_EXPIRE'=>(1*(24*(60*60))), #1 day
                        'TESTING'=>$testing,
                        'PAGINATE'=>100,
                        'PAGE'=>1
                        );
  $template->addText('NAME'=>$name,
                    'PHONE_NUMBERS'=>\@numbers
                    );
 $template->printPage();

=head1 DESCRIPTION

=head2 Overview

This module wraps around the CPAN module HTML::Template.  The module
provides a consistent set of template transformations for all Coati
projects.  The set of template transformations include 1)support for
$;NAME$; keys, 2)support for TMPL_URL tags, 3)support for customized
template files specified at runtime.  This module also supports file
based caching of the entire template key/value map, which enables
Coati scripts to bypass data retrieval for cached data sets.

=head2 Class and object methods

=over 4

=cut

use vars qw(@ISA);

use strict;
use Exporter;
use Coati::Web::MyDataDumper; #Inherits from Data::Dumper overrides output func to sort hash
#use Data::Dumper;
use HTML::Template;
use Coati::Cache::Data;

=item new

B<Description:>

Class constructor.  See project specific modules
(eg. GetManateeTemplate in Manatee) for more constructor and
initialization examples.  The Template object should only be
instantiated through a base class.


B<Syntax:>

 my $template = new Manatee::GetManateeTemplate('FILE'=>"bacannotationpage.tt",
                        'TEMPLATE_EXT'=>[$db],
                        'URL_HANDLER'=>new Manatee::GetManateeURLs(),
                                               'USE_CACHE'=>1,
                        'CACHE_DEPS'=>$Manatee->getProjectDeps(),
                        'CACHE_EXPIRE'=>(1*(24*(60*60))), #1 day
                        'TESTING'=>$testing,
                        'PAGINATE'=>$page_size,
                        'PAGE'=>$page
                        );

B<Parameters:>

FILE - default template file name.  Only the basename is required.
This file should be in the template search path. The default template
search path is templates/:shared/templates relative to all directories
in @INC. See Manatee::GetManateeTemplate module for information about
setting alternative template search paths.

TEMPLATE_EXT - preferred filename extension for template file.  This
feature allows for database specific template files.  In this example
if TEMPLATE_EXT is set to "tba1", the Template module will search for
a template file named bacannotationpage.tba1 before using the default
template file.  The TEMPLATE_EXT parameter applies to the top level
template file and all files included by TMPL_INCLUDE statements.

URL_HANDLER - Reference to object to lookup URLs specified in TMPL_URL
tags.  See Coati::Web::URL for more information.

TESTING - boolean value.  Forces output of template key/value map
instead of translated template for testing purposes.

USE_CACHE - boolean value to activate caching.  The cache lookup is
based on parameters in the CGI namespace and the string specified by
CACHE_DEPS.  See the Coati::Cache::Data module for more information.
On a cache hit, the constructor translates the template file from the
cache, outputs the page, and exits bypassing further execution of the
script.

CACHE_EXPIRE - number of seconds before caches are marked stale and
regenerated.  If this parameter is not defined, caches will persist
indefinately.

PAGINATE - maximum number of elements per page in the document.  See
paginate() and checkCurrentPage() for usage of pagination.

PAGE - number of the current page. See paginate() and
checkCurrentPage() for usage of pagination.

=cut

sub new {
    my $classname = shift;
    my $self = {};
    bless($self,$classname);
    #
    #User configurable
    $self->{KEY_DELIMETER} =  '$;'; #keys restricted to [A-Za-z0-9_] for now
    $self->{CUSTOM_URL_TAG} = "TMPL_URL";
    $self->{TESTING} = 0;
    $self->{NO_HEADER} = 0;  #turn off cgi header in printPage if set to 1
    #
    # Error strings
    $self->{PARSE_ERROR_STRING}  = "Can't parse file";
    $self->{DUPLICATE_KEY_ERROR_STRING} = "Can't replace key more than once";
    $self->{KEY_REPLACEMENT_ERROR_STRING} = "Error while regex replace of key";
    $self->{BAD_KEY_ERROR_STRING} = "Bad key";
    $self->{MISSED_KEY_ERROR_STRING} = "Keys not replaced";
    $self->{NULL_TEXT_ERROR_STRING} = "Replacement text undefined";
    $self->{URL_HANDLER_ERROR_STRING} = "Null URL handler. URL_HANDLER must be set to parse $self->{CUSTOM_URL_TAG} tags";
    #
    # Error actions
    $self->{ERROR_ACTION} = 'mail -s \'Error::GetTemplate from $1\' angiuoli\@tigr.org';
    $self->{REPORT_ERROR} = 0;
    #
    # Actions
    $self->{SKIP_REPLACE} = 0;
    $self->{NO_AUTO_LOAD} = 0;
    #
    # Template areas
    $self->{TEMPLATE_SEARCH_PATH} = ['templates',
                    'shared',
                    '../shared/templates',
                    'shared/templates']; #where to look for template files by default
    #
    # Cache settings
    $self->{USE_CACHE} = 0;
    $self->{CACHE_PARAMS} = undef;
    $self->{CACHE_DEPS} = ""; #used in calculating unique cache keys
    $self->{CACHE_IGNORE_KEYS} = ['user','password'];
    $self->{REDIRECT_WAIT} = 0;
    $self->{CACHE_EXPIRE} = -1; #default to never expire, -1
    $self->{CACHE_LOCK_EXPIRE} = 60*60*2; #Changed to 2 hrs seems a good upper limit for the lock file
    #
    #Should leave these alone
    $self->{_TEMPLATE_FILE_KEYS} = {};
    $self->{_PARAM_MAP} = {};
    $self->{_ERROR_BUFFER} = "";

    $self->{_logger} = Coati::Logger::get_logger(__PACKAGE__);

    $self->{_logger}->debug("Init $classname") if $self->{_logger}->is_debug;
    $self->_init(@_);

#This feature of HTML::Template is not functioning properly
#    if($self->{USE_CACHE} && $ENV{WEBSERVER_TMP}){
#	$self->{_FILE_CACHE} = 1;
#	$self->{_FILE_CACHE_DIR} = $ENV{WEBSERVER_TMP};
#    }
#    else{
#	$self->{_FILE_CACHE} = 0;
#	$self->{_FILE_CACHE_DIR} = "";
#    }

    #Set filename extension
    #if explicitly forced with environment variable
    ($self->{'FILEBASE'}) = ($self->{'FILE'} =~ /(\w+)\.[^.]+/);

    my($search_ext,$templ);
    if(defined($self->{TEMPLATE_EXT}) && ($self->{TEMPLATE_EXT} ne "") && $self->{'FILE'}){
    foreach my $ext (@{$self->{TEMPLATE_EXT}}){
        my($file) = "$self->{'FILEBASE'}"."."."$ext";
        $templ = $self->_find_template($file,$self->{TEMPLATE_SEARCH_PATH});
        if($templ ne '-1') {
        $search_ext = $ext;
        last;
        }
    }

    }
    if($search_ext){
    $self->{'FILE'} = $templ;
    $self->loadFile($templ);
    }
    else{
    $self->load_template($self->{'FILE'}) if($self->{'FILE'} &&  $self->{NO_AUTO_LOAD}!=1);
    }

    $self->{_logger}->debug("Cache is set to  $self->{USE_CACHE}") if($self->{_logger}->is_debug);
    if($self->{USE_CACHE} == 1){
    $self->_set_cache_params();
    $self->_handlecache();
    }
    #
    #Add shared and ../shared to search paths
    my(@check_paths) = @{$self->{TEMPLATE_SEARCH_PATH}};
    foreach my $t (@check_paths){
    push @{$self->{TEMPLATE_SEARCH_PATH}},"shared/$t";
    push @{$self->{TEMPLATE_SEARCH_PATH}},"../shared/$t";
    }

    if($self->{CACHE_DEPS} eq ""){
#	$self->{_logger}->warn("No cache dependency string set via CACHE_DEPS.  Cache files will be shared across all servers and all projects");
    }

    return $self;
}

#This destructor cleans up cache files and reports errors

sub DESTROY{
    my $self = shift;



    if($self->{USE_CACHE} && $self->{_create_cache}){


    my($cache_name,$cache_date) = $self->{_page_cache_handler}->getCacheInfo();
    my($cache_lock) = $cache_name . ".lock";

    if(-e $cache_lock){
        $self->_unlinklockfile($cache_lock);
    }else{

    }
    }


    my($keysleft) = $self->dumpRemainingKeys();
    $self->reportError($self->{MISSED_KEY_ERROR_STRING},$self->dumpRemainingKeys()) if($keysleft);
    if($self->{REPORT_ERROR} && $self->{_ERROR_BUFFER} ne "" && $self->{SKIP_REPLACE}==0){
    my(@ids) = caller();
    $self->{PROGNAME} = $ids[1];
    my($action) = $self->{ERROR_ACTION};
    $action =~ s/\$1/$self->{'PROGNAME'}/g;
    open ERRORPROG, "|$action";
    print ERRORPROG $self->{_ERROR_BUFFER};
    close ERRORPROG;
    }
    $self->{_ERROR_BUFFER} = "";

}

sub _init {

    my $self = shift;
    if(@_){
    my %arg = @_;
    foreach my $key (keys %arg) {
        $self->{_logger}->debug("Storing member variable $key as $key=$arg{$key}") if $self->{_logger}->is_debug;
        $self->{$key} = $arg{$key}
    }
    }
}

sub _check_exists_cache_lock {
    my($self,$lock_file) =  @_;

    if(-e $lock_file){
    my @pidfiles = <$lock_file.*>;

    if(scalar(@pidfiles) > 1){
        die "Multiple process attached to cache lock file $lock_file\n";
    }
    my($cache_pid) = ($pidfiles[0] =~ /.*\.lock\.(\d+)/);
    my($lock_time) = (stat($lock_file))[9];
    my($currtime) = time();
    my($cachelockage) = $currtime - $lock_time;
    my $isaliveparent=kill(0, $cache_pid);
    if($cachelockage > $self->{CACHE_LOCK_EXPIRE} || (!$isaliveparent)){
        #there is a stale cache lock file. this is bad
        $self->_unlinklockfile($lock_file);
        return 0;
    }

    return $cache_pid;
    }

    return 0;
}

sub _unlinklockfile {
    my($self,$lock_file) = @_;

    if(-e $lock_file){

    my @pidfiles = <$lock_file.*>;

    if(scalar(@pidfiles) > 1){
        die "Multiple process attached to cache lock file $lock_file\n";
    }
    unlink $lock_file;
    unlink $pidfiles[0];
    }


}

sub _handlecache {
    my $self = shift;
    $self->{_logger}->debug("Checking for cache") if($self->{_logger}->is_debug);

    $self->{_page_cache_handler} = new Coati::Cache::Data('EXPIRE'=>$self->{CACHE_EXPIRE},
                            'FILE'=>1,
                            'cachedir'=> $ENV{DBCACHE_DIR} || '/tmp');


    if($self->{_page_cache_handler}->queryCache($self->{'FILEBASE'},$self->{CACHE_DEPS},@{$self->{'CACHE_PARAMS'}})){
    $self->_load_cache();
    $self->_print_from_cache();
    exit(0);
    }
    else{

    my($cache_name) = $self->{_page_cache_handler}->getCacheInfo();

    my($cache_lock) = $cache_name . ".lock";

    my $parent_id = $self->_check_exists_cache_lock($cache_lock);

    if($parent_id != 0){

        #wait for cache to build before continue.
        #either redirect or sleep
        $self->{_logger}->debug("Waiting for cache to build. Redirect wait set to = $self->{REDIRECT_WAIT}") if($self->{_logger}->is_debug);

        if($self->{REDIRECT_WAIT}){
        $self->_redirectwait(5000,$parent_id);
        exit;
        }
        else{
        while(-e $cache_lock){
            sleep 2; #spin here, but prevent tight looping
        }
        }
    }
    else{
        my $parent_id = $$;
        open CACHE_LOCK,"+>$cache_lock" or die "can't open cache lock file $cache_lock $!\n";
        flock CACHE_LOCK,2;
        flock CACHE_LOCK,8;
        close CACHE_LOCK;
        #fork to create cache is optional
        $self->{_logger}->debug("Redirect wait $self->{REDIRECT_WAIT}") if($self->{_logger}->is_debug);
        if($self->{REDIRECT_WAIT}){
        $self->{_logger}->debug("Forking child for redirect wait") if($self->{_logger}->is_debug);
        defined(my $childpid = fork) or die "Can't fork: $!\n";
        if ($childpid) {
            open CACHE_LOCK,"+>$cache_lock.$childpid" or die "can't open cache lock file $cache_lock.$childpid $!\n";
            flock CACHE_LOCK,2;
            flock CACHE_LOCK,8;
            close CACHE_LOCK;
            $self->_redirectwait(5000,$childpid);
            exit;
        }
        else{
            $self->{_logger}->debug("Parent continuing on in background") if($self->{_logger}->is_debug);
            close STDOUT;
            close STDERR;
            close STDIN;
            $self->{CACHE_KEYS} = {};
        }
        }
        else{
        $self->{_logger}->debug("Building page in foreground") if($self->{_logger}->is_debug);
        open CACHE_LOCK,"+>$cache_lock.$parent_id" or die "can't open cache lock file $cache_lock.$parent_id $!\n";
        flock CACHE_LOCK,2;
        flock CACHE_LOCK,8;
        close CACHE_LOCK;
        $self->{CACHE_KEYS} = {};
        }
        #mark parent only as cache creator with {_create_cache}.
        #this lock file is meant to ensure 1AO1 cache creator
        #the cache lock will be removed in DESTROY if things go badly
        #otherwise its removed upon completion of cache generation
        $self->{_create_cache} = 1;
    }
    }

}

#this sub provides a default and should be overridden in the child
#besides this sub doesn't support POST-ed pages.
sub _redirectwait {
    my($self,$refresh_rate,$pid) = @_;
    my $isalive=0;
    if($pid){
    $isalive=kill(0, $pid);
    }
    if(!$isalive){
    die "Parent process $pid died prematurely. Try reloading page\n";
    }
    print CGI::header();
    print <<_HTML_

<HEAD>
<TITLE>Please wait</TITLE>
</HEAD>
<BODY BGCOLOR = "#FFFFFF">
Page is loading...please wait<BR>
PID: $pid
<script>
    setTimeout("document.location.reload();",$refresh_rate);
</SCRIPT>

</BODY>
</HTML>
_HTML_
    ;

}

sub _set_cache_params {
    my($self) = @_;
    use CGI;
    if(!$self->{CACHE_PARAMS}){
    my(@parray);
    my(@cgi_params) = CGI::param;
    my($ignorestr) = join('|',@{$self->{CACHE_IGNORE_KEYS}});
    foreach my $key (@cgi_params){
        if(! ($key =~ /$ignorestr/)){
        push @parray,"$key=".CGI::param($key);
        }
    }
    my(@sparray) = sort (@parray);
    $self->{CACHE_PARAMS} = \@sparray;
    }
}


sub _load_cache {
    my($self) = @_;

    my($keyref) = $self->{_page_cache_handler}->dumpCache();
    my($ignorestr) = join('|',@{$self->{CACHE_IGNORE_KEYS}});
    foreach my $key (keys %$keyref){
    if(! ($key =~ /$ignorestr/)){
        $self->addText($key,$keyref->{$key});
    }
    }
    # make sure ignore keys are updated
    use CGI;
    foreach my $ignorekey (@{$self->{CACHE_IGNORE_KEYS}}){
    $self->addText(uc($ignorekey),CGI::param($ignorekey));
    }

}

sub _print_from_cache{
    my($self) = @_;
    $self->{_SKIP_STORE_CACHE} = 1;

    my($cache_name,$cache_date) = $self->{_page_cache_handler}->getCacheInfo();
    #NOTE!! shouldn't the DESTROY block take care of unlinking the cache lock
    #unless the DESTROY unlink a safety net....

    my($cache_lock) = $cache_name . ".lock";
    if(-e $cache_lock){
    $self->_unlinklockfile($cache_lock);
    }
    $self->addText("CACHE_FILE",$cache_name);
    $self->addText("CACHE_DATE"," ".localtime($cache_date)." ");
    $self->addText("USE_CACHE",1);
    $self->printPage();

}

sub load_template {
    my($self,$file) = @_;
    my($tdirs) = $self->{TEMPLATE_SEARCH_PATH};
    # We need to look for the template file.
    my($found) = $self->_find_template($file,$tdirs);

    if($found ne '-1'){
    $self->{'FILE'} = $found;
    my $status = $self->loadFile($found);
    return 1;
    }
    else{
    return -1;
    }
}

sub _find_template{
    my($self,$file,$tdirs) = @_;
    my $found=undef;
    foreach my $inc (@INC) {
    if(!($inc =~ /^\//)){ #only search RELATIVE PATHS
        foreach my $dir (@$tdirs){
        $self->{_logger}->debug("Checking $inc\/$dir\/$file<br>") if($self->{_logger}->is_debug);
        if (-e "$inc\/$dir\/$file") {
            $found = "$inc\/$dir\/$file";
            $self->{_logger}->debug("Found template file at $found<br>") if($self->{_logger}->is_debug);
            last;
        }
        }
    }
    last if(defined($found));

    }
    return defined($found) ? $found : -1;
}

sub loadFile{
    my($self) = shift;
    my($filename) = shift;

    my $searchPathOnInclude = $self->{'SEARCH_PATH_ON_INCLUDE'};
    $searchPathOnInclude = 0 if (!defined($searchPathOnInclude));

    $self->{TEMPLATE} = HTML::Template->new(filename => $filename,
                        #built-in HTMLTemplate caching (next 2 keys) is problematic in development environment
                        #needs production testing
                        #
                        #file_cache => $self->{_FILE_CACHE},
                        #file_cache_dir => $self->{_FILE_CACHE_DIR},
                        loop_context_vars => 1, # to allow us to see the first, last and inner entries in a loop
                        die_on_bad_params => 0, #to allow incomplete template files, template files need not fully implement all keys
                        global_vars => 1, #to give access to root keys in loops, this is unavoidable
                        path => $self->{TEMPLATE_SEARCH_PATH},
                        search_path_on_include => $searchPathOnInclude,
                        strict => 0, #to allow <TMPL_URL> tag
                        filter => [
                            # search for help text which can be placed in the header
                            sub {
                            my($text_ref) = shift;
                            my($docfile) = $self->{'FILE'};
                            $docfile =~ s/.*\/([^\/]+)\.\w+$/$1.txt/;
                            $$text_ref =~ s/\<TMPL_INCLUDE NAME=SCRIPTNAME/<TMPL_INCLUDE NAME='docs\/$docfile'/g;
                            },
                            # rewrite orf_infopage.js URL in testing mode
                            # JC: Why is this sub/hack necessary?  Can't JS_INCLUDE be placed in the URLs file?
                            sub {
                            my($text_ref) = shift;
                            my($testing) = $self->{'TESTING'};
                            if($testing) {
                                $$text_ref =~ s/\<TMPL_INCLUDE NAME=JS_INCLUDE/<TMPL_INCLUDE NAME='..\/..\/shared\/js\/orf_infopage.js'/g;
                            } else {
                                $$text_ref =~ s/\<TMPL_INCLUDE NAME=JS_INCLUDE/<TMPL_INCLUDE NAME='..\/shared\/js\/orf_infopage.js'/g;
                            }
                            },
                            # resolve TMPL_INCLUDEs that make use of the template extension search path
                            sub {
                            my($text_ref) = shift;
                            # JC: note that this regex *requires* that single quotes be used, whereas the
                            # perldoc for HTML::Template shows double quotes being used in TMPL_INCLUDEs
                            my($file_regex) = qw|\<TMPL_INCLUDE\s+NAME='(\w+)\.EXT'\s*\>|;
                            study $file_regex;
                            while($$text_ref =~ /$file_regex/g){
                                my($file) = ($$text_ref =~ /$file_regex/);
                                my($search_ext);

                                foreach my $ext (@{$self->{TEMPLATE_EXT}}){
                                # avoid a possible (but very unlikely) infinite loop:
                                next if ($ext eq 'EXT');
                                my($templ) = $self->_find_template("$file"."."."$ext",$self->{TEMPLATE_SEARCH_PATH});
                                if($templ ne '-1'){
                                    $search_ext = $ext;
                                    last;
                                }
                                }
                                if($search_ext ne ""){
                                $$text_ref =~  s/$file_regex/<TMPL_INCLUDE NAME='$1.$search_ext'>/g;
                                }
                                else{
                                $$text_ref =~  s/$file_regex/<font color='red'>Template with prefix $1 not found<\/font>/g;
                                }
                            }
                            },
                            # replace TMPL_URL tags
                            sub {
                            my($text_ref) = shift;
                            my($pattern) = '\<'.$self->{CUSTOM_URL_TAG}.' NAME=(\w+)\s*((\w+\s*=\s*[\$;\w]+\s*)*)\>';
                            study $pattern;
                            my($name,$paramstr);
                            while(($name,$paramstr) = ($$text_ref =~ /$pattern/)){
                                my($href);

                                my(@params) = split(/\s+/,$paramstr);
                                foreach my $p (@params){
                                my($key,$value) = ($p =~ /(\w+)=([\$;\w]+)/);
                                if(exists $href->{$key}){
                                    $href->{$key} .= "&$key=$value";
                                }
                                else{
                                    $href->{$key} = $value;
                                }
                                }
                                if($self->{'URL_HANDLER'}) {
                                my($url) = $self->{'URL_HANDLER'}->getURL(lc($name),$href);
                                $$text_ref =~ s/$pattern/$url/;
                                }
                                else{
                                    $self->reportError($self->{URL_HANDLER_ERROR_STRING},"URL handler not found. Unable to find URL for '$name'");
                                    # Avoid infinite loop by using a dummy value for $url.  If we had the
                                    # URL of an error page we could use that instead, but it's a catch 22,
                                    # since this only happens when the URL_HANDLER is missing
                                    my $url = '#error:no URL_HANDLER found';
                                    $$text_ref =~ s/$pattern/$url/;
                                }
                            }
                            },
                            # replace HELP_NAME and HELP_FILE
                            sub{
                            my($text_ref) = shift;
                            my($helpfile) = $self->{'FILE'};
                            $helpfile =~ s/.*\/([^\/]+)\.\w+$/$1/;
                            $$text_ref =~ s/HELP_NAME/$helpfile/g;
                            $$text_ref =~ s/HELP_FILE/docs\/$helpfile\.html/g;
                            },
                            # replace $;x$; with <TMPL_VAR NAME="x">
                            # JC: not sure why only the shortest filter (2 lines) is named -
                            \&TIGRtags2Std
                            ]

                        );
    $self->{NUMKEYS} = $self->makeKeyLookup();
    return 1;
}

sub makeKeyLookup{
    my($self) = @_;
    my @parameter_names = $self->{TEMPLATE}->param();
    my($count);
    foreach my $p (@parameter_names){
    $self->addKey($p);
    $count++;
    }
    return $count;
}
sub addKey{
    my($self,$key) = @_;
    $self->{_TEMPLATE_FILE_KEYS}->{lc($key)}++;
    return "$self->{KEY_DELIMETER}$key$self->{KEY_DELIMETER}";
}

=item printPage

B<Description:>

Transforms template and prints page to STDOUT.  An optional filehandle
 may be specified.

B<Syntax:>

     $template->printPage();

B<Parameters:>

An optional filehandle reference may be specified.

=cut

sub printPage{
    my($self,$fhandle,$cookie) = @_;
    if(!$self->{TEMPLATE}){
    die "Cannot find HTML template file%%Missing template file%%The file $self->{'FILE'} was not found using the search path [",join(':',@{$self->{TEMPLATE_SEARCH_PATH}}),"].  Please check the conf/Manatee.conf to set the correct search paths and extensions for the templates files\n";
    }
    if($self->{TESTING}){
    print $self->dumpKeysText();
    return;
    }
    elsif($self->{USE_CACHE} && !$self->{_SKIP_STORE_CACHE}){
    $self->{_page_cache_handler}->seedCache($self->{CACHE_KEYS},$self->{'FILEBASE'},$self->{CACHE_DEPS},@{$self->{'CACHE_PARAMS'}});
    }

    if(!$fhandle){
    $fhandle = *STDOUT if(!$fhandle);
	
	# do not print header if NO_HEADER = 1
	unless( $self->{'NO_HEADER'} ) {
		if( $cookie ) {
			# if cookie is passed in, print header with cookie
			print CGI::header(-cookie => $cookie);			
		} else {
			# else, print empty header with no cookie
			print CGI::header();
		}
	}

    # If STDOUT is tied then passing $fhandle as the print_to argument of HTML::Template::output will not work.
    # This can happen when running under mod_perl, for example, since STDOUT gets tied to Apache::print.
    if (tied $fhandle) {
        print $self->{TEMPLATE}->output();
    }
    }
    return $self->{TEMPLATE}->output(print_to => $fhandle);
}

=item checkKey

B<Description:>

Check the presence of a key in the template file

B<Syntax:>

     $num_occs = checkKey('KEY');

B<Parameters:>

An optional filehandle reference may be specified.

B<Return values:>

Returns the number of occurences of KEY in the template file in the
variable $num_occs.  Returns 0 if the key is not present in the
template file.

=cut

sub checkKey{
    my($self,$key) = @_;
    if ($self->{TEMPLATE}->query(name => lc($key))) {
            # do something if $key exists and is a TMPL_VAR
    return 1;
    }

    return undef;
}

=item addText

B<Description:>

Wraps around HTMLTemplate param() key for specifying tag values.
The value may be a array reference for specifying loops.  See
HTMLTemplate documentation for additional syntax and information
about specifying loops.

B<Syntax:>

    addText($key,$value);
    addText('$key'=>$value);

B<Parameters:>

$key must be a scalar. $value can be scalar or an array reference
for specifying loops.  See HTMLTemplate documentation for additional
syntax and information about specifying loops.

=cut

sub addText{
    #support input as
    #addText(key,text);
    #addText({'key'=>'text'});
    my($self) = shift;
    my($status) = 0;
    if(scalar(@_) == 3){
    my($key,$text) = @_;
    $status += $self->replaceText($text,$key);
    }
    else{
    my(%pairs) = @_;
        foreach my $key (keys %pairs){
            $status += $self->replaceText($pairs{$key},$key);
        }
    }
}

sub replaceText{
    my($self,$text,$key) = @_;
    $key = lc($key);
    $self->{_PARAM_MAP}->{$key} = $text;
    if($self->{USE_CACHE}){
    $self->{CACHE_KEYS}->{$key} = $text;
    }
    my($status)=0;
    if(exists $self->{_TEMPLATE_FILE_KEYS}->{$key}){
        if($self->{_TEMPLATE_FILE_KEYS}->{$key} eq "DONE"){
            $status--;
            $self->reportError($self->{DUPLICATE_KEY_ERROR_STRING},"Attempted duplicate replacement of $key in template file");
        }
        else{
            if(!(defined $text)){
                $self->reportError($self->{NULL_TEXT_ERROR_STRING},"No replacement text for $key\n");
                $status--;
            }
            else{
        $self->{TEMPLATE}->param($key=>$text);
                #mark key as DONE
        $self->{_TEMPLATE_FILE_KEYS}->{$key}  = "DONE";
        }
        }
    }
    else{
        $status--;
        $self->reportError($self->{BAD_KEY_ERROR_STRING},"Key $key not found in template file");
    }
    return $status;
}

sub reportError{
    my($self,$error_str,$name) = @_;
    $self->{_ERROR_BUFFER} .= "Error reported using template file $self->{FILE}\nERROR_TYPE: $error_str\nERROR_TEXT: $name\n";
}

sub dumpRemainingKeys{
    my($self) = @_;
    my($buff);
    my($kref) = $self->{_TEMPLATE_FILE_KEYS};
    foreach my $key (keys %$kref){
    if($kref->{$key} ne "DONE"){
        $buff .= "$key has $kref->{$key} occurences\n";
    }
    }
    return $buff;
}

sub dumpKeysText{
    my($self) = @_;
    my $pref = $self->{_PARAM_MAP};
    my(@tkeys) = (keys %$pref);
    my(@dumplist);
    foreach my $key (sort {$a cmp $b} @tkeys){
    push @dumplist,{$key=>$self->{_PARAM_MAP}->{$key}};
    }

    #use MyDataDumper instead of Data::Dumper to get sorted hashes
    my $strobj = Coati::Web::MyDataDumper->new([\@dumplist]);
    $Data::Dumper::Purity = 1;
    my ($buff) = $strobj->Dump;

    #Explanation of need for following regex:
    #This regex replaces quoted integer values as a workaround for a DBD::mysql int casting bug.
    #By default, it appears the mysql drivers interpolate int types as strings.
    #While Perl does not require variables are typed correctly (perl code rarely notices the difference between types),
    #the incorrect type causes ints to be quoted in Data::Dumps.
    #The mysql newsgroup recommends a workaround of casting ints explicitly using int($variable).  This is not an option here.
    #Note: int types are correctly cast in DBD::sybase.
    $buff =~ s/\'(\d+)\'/$1/g;

    return $buff;
}

sub dumpKeysHTML{
    my($self) = @_;
    my($buff);
    my($kref) = $self->{_TEMPLATE_FILE_KEYS};
    $buff .=  "<table border=1><tr><th>$self->{FILE}</th></tr><tr><th>Key</th><th>Occurrences</th></tr>";
    foreach my $key (sort {$kref->{$b} <=>$kref->{$a}} (keys %$kref)){
    $buff .= "<tr><td>$key</td><td>$kref->{$key}</td></tr>";
    }
    $buff .= "</table>";
    return $buff;
}
sub TIGRtags2Std{
    my $text_ref = shift;
    my($count) = ($$text_ref =~ s/\$;([A-Za-z0-9_]+)\$;/<TMPL_VAR NAME="$1">/g);
}

=item paginate

B<Description:>

Returns an array of keys that can be used to build a pager; a list of
pages (eg. 1,2,3). The current page is marked with SELECTED_PAGE=1.
The PAGINATE option in the constructor specifies the number of
elements per page.

B<Syntax:>

    @page_keys = paginate($num_elements);

Example of proper usage of pagination fuctions

    @page_list = $template->paginate(scalar(@allelts));
    foreach my $elt (@allelts){
    if(template->isCurrentPage(++$count)){
        $template->addText(...);
    }
    }
    $template->addText('PAGE_LIST'=>\@page_list);


B<Parameters:>

$num_elements - total number of elements to process

B<Returns:>

    @page_keys = ({'PAGE_NUM'=>1,
        'SELECTED_PAGE'=>1,
        },{'PAGE_NUM'=>2,
        'SELECTED_PAGE'=>0,
        },...)

=cut

sub paginate{
    my($self,$num) = @_;
    my($num_pages);
    my(@page_text);
    if($self->{PAGINATE}){
    if ($num <= ($self->{PAGINATE})) {
        $num_pages++;
    } else {
        $num_pages = int($num/($self->{PAGINATE}));
        if ($num % ($self->{PAGINATE}) > 0) {
        $num_pages++;
        }
    }
    }
    else{
    $num_pages=1;
    }
    for(my $i=0; $i<$num_pages; $i++) {
    my $page = $i + 1;
    my $selected_page = 0;
    if($page == $self->{PAGE}) {
        $selected_page = 1;
    }

    push(@page_text, {'PAGE_NUM'=>$page,
            'SELECTED_PAGE'=>$selected_page
            });
    }
    return(@page_text);
}

=item isCurrentPage

B<Description:>

Checks if an element is displayed on the current page.  Returns true in variable $is_page if $element_number is an element
displayed on the current page.

B<Syntax:>

    $is_page =  isCurrentPage($element_number);

B<Parameters:>

$element_number - element number

B<Return values:>

Returns true in variable if $element_number is an element
displayed on the current page.

=cut

sub isCurrentPage {

    my ($self, $count) = @_;

    my $page_num  = $self->{PAGE};
    my $page_size = $self->{PAGINATE};

    my $page_to_display = (int( ($count - 1) / $page_size) ) + 1;

    if($page_to_display == $page_num) {
    return 1;
    } else {
    return 0;
    }

}

=item indexesInPage

B<Description:>

Returns a list of array indexes that are on the current page.
Can be used to get an array slice.

B<Syntax:>

    @page_rows = @all_rows[ $template->indexesInPage() ];

=cut

sub indexesInPage {
    my $self = shift;
    my $start = ($self->{PAGE} -1) * $self->{PAGINATE};
    my $end = ($self->{PAGE} * $self->{PAGINATE}) -1;
    return $start .. $end;
}

1;


__END__
# Below is stub documentation for your module. You better edit it!
=over 4

=item "Error message that may appear."

Explanation of error message.

=item "Another message that may appear."

Explanation of another error message.

=back

=head1 BUGS

TEMPLATE_EXT setting is not being applied to TMPL_INCLUDE correctly

=head1 SEE ALSO

Manatee::GetManateeTemplate.pm
Coati::Web::URL.pm
Manatee::GetManateeURL.pm
Coati::Cache::Data.pm

=head1 AUTHOR(S)

 The Institute for Genomic Research
 9712 Medical Center Drive
 Rockville, MD 20850

=head1 COPYRIGHT

Copyright (c) 2002, The Institute for Genomic Research. All Rights Reserved.
