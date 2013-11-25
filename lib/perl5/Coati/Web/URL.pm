package Coati::Web::URL;

=head1 NAME

Coati::Coati::URL - 

=head1 VERSION

    This document refers to version 1.0 of URL.pm, released MMMM, DD, YYYY.

=head1 SYNOPSIS

Short examples of code that illustrate the use of the class (if this file is a class).

=head1 DESCRIPTION

=head2 Overview

    Overview of the purpose of the file.

=head2 Constructor and initialization.

    if applicable, otherwise delete this and parent head2 line.

=head2 Class and object methods

    if applicable, otherwise delete this and parent head2 line.

=over 4

=cut

use strict;
use XML::Simple;
use Data::Dumper;
use Coati::Logger;

require Exporter;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw(
&new 
&loadFile
&getURL	
);

use vars qw(@ISA);

sub new {
    my $classname = shift;
    my $self = {};
    bless($self,$classname); 
    #
    #User configurable
    #
    # Error strings
    $self->{MISSING_ERROR_STRING} = "URL tag not found";
    $self->{DUPLICATE_LOCATION_ERROR_STRING} = "Duplicate location tag found in XML file";
    $self->{DUPLICATE_SOURCE_ERROR_STRING} = "Duplicate script names found";
    $self->{PARAM_ERROR_STRING} = "Required parameter missing";
    $self->{PARSE_ERROR_STRING}  = "Can't parse file";
    $self->{MISSING_ERROR_LINK} = "javascript: alert('Sorry. Unfortunately this link is currently unavailable to external users and is used internally at TIGR ONLY.');";
    #
    # Error actions
    $self->{ERROR_ACTION} = 'mail -s \'Error::URL from $1\' tcreasy\@tigr.org';
    $self->{MISSING_LINK_TAG} = "missing_link"; #this url will be used in place of bad links
    $self->{REPORT_ERROR} = 0;
    #
    # URL file locations
    $self->{COMMON_URL_FILE} = ["urls_shared.xml","urls_shared_internal.xml","urls_external.xml"]; #default xml file
    $self->{URL_FILE_DIR} = "urls"; #where to look for xml file
    #
    # Cookie parameters should be excluded from URLs
    # This should be a hash ref to lookup keys to ignore
    $self->{IGNORE_PARAMS} = undef;
    #
    # Should leave these alone
    $self->{LOCATION_LOOKUP} = {}; #gives location name for any url key name
    $self->{SOURCE_LOOKUP} = {}; #gives url key name for any url source
    $self->{INIT} = 0;
    $self->{XML} = {};
    $self->{XML}->{'location'} = {};
    $self->{ERROR_BUFFER} = "";
    $self->{XMLFILE} = "";
    $self->{VIRTUAL_PATHS} = {};
    #
    # Whether to urlencode ampersands in the generated URLs.  This option is left
    # turned off for backwards compatibility, but it IS REQUIRED for strict HTML 4.x 
    # compatibility.
    $self->{ENCODE_AMPERSANDS} = 0;

    $self->{_logger} = Coati::Logger::get_logger(__PACKAGE__);
    $self->{VALIDITY_CHECKING} = 0; #this will check all parsed data but is slow

    $self->{_logger}->debug("Init $classname") if $self->{_logger}->is_debug;
    $self->_init(@_);
    return $self;
}

sub DESTROY{
    my $self = shift;
    if($self->{REPORT_ERROR} && $self->{ERROR_BUFFER} ne ""){
	my(@ids) = caller();
	$self->{PROGNAME} = $ids[1];
	my($action) = $self->{ERROR_ACTION};
	$action =~ s/\$1/$self->{'PROGNAME'}/g;
	open ERRORPROG, "|$action";
	print ERRORPROG $self->{ERROR_BUFFER};
	close ERRORPROG;
    }
    $self->{ERROR_BUFFER} = "";
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
sub load_common_urls {
    my($self) = @_;
    my($status) = 0;
    foreach my $file (@{$self->{COMMON_URL_FILE}}){
	$status += $self->load_url_file($file);
    }
    return $status;
}
sub load_url_file {
    my($self,$file) = @_;
    # We need to look for the xml file.
    foreach my $inc (@INC) {
	$self->{_logger}->debug("Checking $inc\/$self->{URL_FILE_DIR}\/$file<br>") if($self->{_logger}->is_debug);
	if (-e "$inc\/$self->{URL_FILE_DIR}\/$file") {
	    $file = "$inc\/$self->{URL_FILE_DIR}\/$file";
	    $self->{_logger}->debug("Found XML file at $file<br>") if($self->{_logger}->is_debug);
	    last;
	}
    }
    return $self->loadFile($file);
}   
sub loadFile{
    my($self) = shift;
    my($totalstatus)=0;
    while(my $filename = shift){

	my($newxml) = XMLin("$filename", forcearray=>1, forcecontent=>1);
	#
	# Check data for wellformedness
	my($status,$errstr) = $self->dataCheck($newxml);
	if($status==0){
	    $self->{XMLFILE} .= "$filename,";
	    $self->mergeLocations($newxml);
	    $self->buildLookups($newxml);
	}
	else{
	    $self->reportError($self->{PARSE_ERROR_STRING},"$errstr");
	}
	$totalstatus += $status;
    }
    return $totalstatus;
}
sub mergeLocations{
    my($self,$newxml) = @_;
    #
    # Merge location hashes so you don't stomp a previous load
    # Attempt to report duplicate entries
    my($xref) = $newxml->{'location'};
    my($nxml) = $self->{XML}->{'location'}; 
    foreach my $key (keys %$xref){
	if(exists $nxml->{$key}){
	    $self->reportError($self->{DUPLICATE_LOCATION_ERROR_STRING},"$key");
	}
	else{
	    $nxml->{$key} = $xref->{$key};
	}
    }
}
#
# Build a name->location lookup
# Build a source->name lookup
sub buildLookups{
    my($self,$newxml) = @_;
    my($xref) = $newxml->{'location'};
    #
    # Create easy lookup for url locations from url name
    foreach my $key (keys %$xref){
	$self->loadVirtualPath($xref->{$key},$key);
	my ($uref) = $xref->{$key}->{'url'};
	foreach my $url (keys %$uref){
	    my $content = $uref->{$url}->{'source'}[0]->{'content'};
	    if ($content) {
		my($sname) = ($content =~ /\/*([^\/]+)\.\w+$/);
		if($sname){
		    if(exists $self->{SOURCE_LOOKUP}->{$sname}){
			my($error) = "Duplicate source name $sname found for URL key $url parsed from $uref->{$url}->{'source'}[0]->{'content'}";
			$self->reportError($self->{DUPLICATE_SOURCE_ERROR_STRING},$error);
		    }
		    else{
			$self->{SOURCE_LOOKUP}->{$sname} = $url;
		    }
		}
	    }
	    $self->{LOCATION_LOOKUP}->{$url}  = $xref->{$key};
	}
    }
}
#
# Virtual paths can be specified in any <location> block like so: <virtual>shared</virtual>
# This states all URLs in the shared location will reside under the path for the current context.
# This only works if the <location name='shared'> has already been loaded
sub loadVirtualPath{
    my($self,$locationref,$key) = @_;
    if(exists $locationref->{'virtual'}){
	my($vref) = $locationref->{'virtual'};
	#
	#Set the path information for the tag name to the current context
	foreach my $v (@$vref){
	    $self->{VIRTUAL_PATHS}->{$v->{'content'}} = $locationref->{'path'}[0]->{'content'};
	}
    }
    #
    #Prefix the path information for the tag name to the current context
    if(exists $self->{VIRTUAL_PATHS}->{$key}){
	$locationref->{'path'}[0]->{'content'} = $self->{VIRTUAL_PATHS}->{$key}.$locationref->{'path'}[0]->{'content'};
    }
}
sub getURLKeyFromSource {
    my($self,$source) = @_;
    my($name) = ($source =~ /\/*[^\/+]\.\w+/);
    return $self->{SOURCE_LOOKUP}->{$source};
}

sub checkURL{
    my($self,$name) = @_;
    return exists $self->{LOCATION_LOOKUP}->{$name};
}

sub getURL{
    my($self,$name,$pref) = @_;
    my($defaultstr) = "?";
    my($querystr) = \$defaultstr;
    #
    # Lookup tag name and build the URL
    if(exists $self->{LOCATION_LOOKUP}->{$name}){
	return $self->buildURL($self->{LOCATION_LOOKUP}->{$name},$name,$pref);
    }
    else{
	#
	# Attempt to report an error and return the error page if available
	$self->reportError($self->{MISSING_ERROR_STRING},"'$name'");
	if($self->{URLS}->{$self->{MISSING_LINK_TAG}}){
	    return $self->buildURL($self->{LOCATION_LOOKUP}->{$self->{MISSING_LINK_TAG}},$name,$pref);
	}
	else{
	    my($error) = $self->{MISSING_ERROR_LINK};
	    $error =~ s/\$1/$name/g;
	    return $error;
	}
    }
}

sub buildURL{
    my($self,$location,$name,$pref) = @_;
    my($querystr,$path,$source);
    #
    # Build the query string if there are query parameters
    if($pref){
	$querystr = $self->buildQueryString($location->{'url'}->{$name}->{'parameter'},$pref,$name);
    }
    #
    # Pull path
    if(exists $location->{'path'}){
	$path = $location->{'path'}[0]->{'content'};
    }
    else{
	$path = "";
    }
    #
    # Pull file name ie source
    $source = $location->{'url'}->{$name}->{'source'}[0]->{'content'};
    #
    # Return fully formed URL
    if(ref $querystr){
	return "$path$source$$querystr";
    }
    else{
	$path = '' if (!defined($path));
	$source = '' if (!defined($source));
	return "$path$source";
    }
}

sub buildQueryString{
    my($self,$paramref,$pref,$urlname) = @_;
    my($buff)="";
    if(ref $paramref && scalar(@$paramref)>0){
	my $keyValPairs = [];
	foreach my $param (@$paramref){
	    if($self->{IGNORE_PARAMS} && $self->{IGNORE_PARAMS}->{$param->{'content'}}){
	    }
	    else{
		my($name) = $param->{'content'};
		#
		# Set &key=value or use default if available
		# Skip optional parameters, report missing parameters
		if(exists $pref->{$name} && defined $pref->{$name}){
		    $pref->{$name} =~ s/\s/\%20/g; #do some escape codes
		    push(@$keyValPairs, $name . '=' . $pref->{$name});
		}
		elsif(exists $param->{'default'}) {
		    push(@$keyValPairs, $name . '=' . $param->{'default'});
		}
		elsif(exists $param->{'optional'} && $param->{'optional'}==1){
		}
		else{
		    my($pastr) = Dumper($paramref);
		    my($pstr) = Dumper($pref);
		    my($error) = "'$name' parameter missing for $urlname.\nValid keys: $pastr\nUser input: $pstr\n";
		    $self->reportError($self->{'PARAM_ERROR_STRING'},$error);
		}
	    }
	}

	my $sep = $self->{ENCODE_AMPERSANDS} ? '&amp;' : '&';
	$buff = '?' . join($sep, @$keyValPairs);
    }

    return ($buff ne "") ? \$buff : -1;
}
#
# All error reporting should be done through this func
sub reportError{
    my($self,$error_str,$name) = @_;    
    $self->{ERROR_BUFFER} .= "Error reported using url file $self->{XMLFILE}\nERROR_TYPE: $error_str\nERROR_TEXT: $name\n";
}

#
# If VALIDITY_CHECKING is turned on, this will walk through hash and look for expected data
# With a correct DTD and XML validator doing this is not neccessary.
# VALIDITY_CHECKING is turned off by default
sub dataCheck{
    my ($self,$xmlref) = @_;
    my($status)=0;
    my($errstr);
    #do exhaustive check
    if($self->{VALIDITY_CHECKING}){
	$self->{_logger}->debug("Doing validity check on xml".Dumper($xmlref)) if($self->{_logger}->is_debug);
	if(!ref $xmlref){
	    $status -= 1;
	    $errstr .=  "XML file not read properly. XML ref: $xmlref\n";
	}
	else{
	    my($location) = $xmlref->{'location'};
	    if(!ref $location){
		$status -= 1;
		$errstr .=  "XML file not read properly. location tag not found: \n";
	    }
	    else{
		if(scalar(keys %$location) == 0){
		    $status -= 1;
		    $errstr .=  "XML file not read properly. No locations found under 'location' tag : $location\n";
		}
		else{
		    foreach my $key (keys %$location){
			my ($uref) = $location->{$key}->{'url'};
			if(!ref $uref){
			    $status -=1;
			    $errstr .=  "XML file not read properly. URLs not found for location $key: $uref\n";
			}
			else{
			   foreach my $url (keys %$uref){
			       my($aref) = $uref->{$url};
			       if(!ref $aref){
				   $status -=1;
				   $errstr .=  "XML file not read properly. URLs is not ref for url $url: $aref\n";
			       }
			       else{
				   if(!(defined $aref->{'source'})){
				       $status -= 1;
				       $errstr .=  "XML file not read properly. Missing 'source' tag for url $url: $aref\n";
				   }
				   elsif(!ref($aref->{'source'})){
				       $status -= 1;
				       $errstr .=  "XML file not read properly. 'source' tag is not array for url $url. make sure forcearray=>1: $aref->{'source'}\n";
				   }
				   elsif(!(defined $aref->{'source'}[0]->{'content'})){
				       $status -= 1;
				       $errstr .=  "XML file not read properly. 'source' found with no content for url $url. make sure forcecontent=>1: $aref->{'source'}[0]\n";
				   }
				   if(!ref($aref->{'paramter'})){
				       #allowing empty parameter lists
				   }
				   else{
				       my($paramref) = $aref->{'paramter'};
				       foreach my $param (@$paramref){
					   if(!(defined $param->{'content'})){
					      $status -= 1;
					      $errstr .=  "XML file not read properly. 'parameter' found with no content for url $url. make sure forcecontent=>1: $aref->{'source'}[0]\n";
					  } 
				       }
				   }
			       }
			   }
		       }
			my($pref) = $location->{$key}->{'path'};
			if(!ref $pref){
                            #path info is optional for now
			    #$status -= 1;
			    #$errstr .=  "XML file not read properly. 'path' info for $key incorrect. $pref\n";
			}
			elsif(scalar(@$pref)!=1){
			    $status -= 1;
			    $errstr .=  "XML file not read properly. 'path' info for $location incorrect. make sure forcearray=>1. $pref\n";
			}
			elsif(!(defined @$pref[0]->{'content'})){
			    $status -= 1;
			    $errstr .=  "XML file not read properly. 'path' info found with no content. make sure forcecontent=>1. $pref\n";
			}
		    }
		}
	    }
	}
    }
    # do simple check
    else{
	if(!ref $xmlref){
	    $status -= 1;
	}
    }
    return $status,$errstr;
}

sub dumpURLsText{
    my($self) = @_;
    my($buff);
    my($xref) = $self->{XML}->{'location'};
    print "KEYS: ",join(',',keys %$xref),"\n";
    foreach my $key (keys %$xref){
	my($location) = $xref->{$key};
	$buff .= "Location: $key\n";
	$buff .= "Path: $location->{'path'}[0]->{'content'}\n" if($location->{'path'});
	my ($uref) = $xref->{$key}->{'url'};
	foreach my $url (keys %$uref){  
	    $buff .= "\tURL NAME: $url\n\tURL SOURCE:$uref->{$url}->{'source'}[0]->{'content'}\n";
	    my($params) = $location->{'url'}->{$url}->{'parameter'};
	    foreach my $param (@$params){
		$buff .= "\t\tParameter: $param->{'content'}";
		$buff .= " (default: $param->{'default'})" if($param->{'default'});
		$buff .= " (optional)" if($param->{'optional'});
		$buff .= "\n";
	    }
	}
    }
    return $buff;
}
sub dumpURLsHTML{
    my($self) = @_;
    my($buff);
    my($xref) = $self->{XML}->{'location'};
    $buff .= "";
    foreach my $key (sort {$a cmp $b} (keys %$xref)){
	my($location) = $xref->{$key};
	$buff .= "<h1>Location: $key</h1>";
	$buff .= "<h2>Path: $location->{'path'}[0]->{'content'}</h2>" if($location->{'path'});
	my ($uref) = $xref->{$key}->{'url'}; 
	$buff .= "<table border=1>";
	$buff .= "<tr><th bgcolor='silver'>URL NAME:</th><th bgcolor='silver'>URL SOURCE:</th></tr>";
	foreach my $url (sort {$a cmp $b} (keys %$uref)){  
	    $buff .= "<tr><td bgcolor='silver'>$url</td><td bgcolor='silver'><a href='$location->{'path'}[0]->{'content'}/$uref->{$url}->{'source'}[0]->{'content'}'>$uref->{$url}->{'source'}[0]->{'content'}</a></td></tr>";
	    my($params) = $location->{'url'}->{$url}->{'parameter'};
	    foreach my $param (@$params){
		$buff .= "<tr><td>$param->{'content'}</td>";
		$buff .= "<td>";
		$buff .= "(default: $param->{'default'})" if($param->{'default'});
		$buff .= " (optional)" if($param->{'optional'});
		$buff .= "</td></tr>";
	    }
	}
	$buff .= "</table>";
    }
    return $buff;
}
sub dumpURLsHTMLWithForms{
    my($self) = @_;
    my($buff);
    my($xref) = $self->{XML}->{'location'};
    $buff .= "";
    foreach my $key (sort {$a cmp $b} (keys %$xref)){
	my($location) = $xref->{$key};
	$buff .= "<h1>Location: $key</h1>\n";
	$buff .= "<h2>Path: $location->{'path'}[0]->{'content'}</h2>\n" if($location->{'path'});
	my ($uref) = $xref->{$key}->{'url'}; 
	$buff .= "<table border=1>\n";
	$buff .= "<tr><th bgcolor='silver'>URL NAME:</th><th bgcolor='silver'>URL SOURCE:</th></tr>\n";
	foreach my $url (sort {$a cmp $b} (keys %$uref)){  
	    my $path = $location->{'path'}[0] ? $location->{'path'}[0]->{'content'} : "";
	    my $source =  $uref->{$url}->{'source'}[0] ? $uref->{$url}->{'source'}[0]->{'content'} : "";
	    $buff .= "<tr><form action='$path$source'><td bgcolor='silver'>$url</td><td bgcolor='silver'><a href='$path$source'>$source</a>\n";
	    $buff .= "&nbsp<input type=submit value='Test'>\n" if($location->{'url'}->{$url}->{'parameter'});
	    $buff .= "</td></tr>\n";
	    my($params) = $location->{'url'}->{$url}->{'parameter'};
	    foreach my $param (@$params){
		$buff .= "<tr><td>$param->{'content'}</td>\n";
		$buff .= "<td>";
		$buff .= "<input name = '$param->{'content'}' value='$param->{'default'}'>" if($param->{'default'});
		$buff .= "<input name = '$param->{'content'}' value=''> (optional)" if($param->{'optional'});
		$buff .= "<input name = '$param->{'content'}' value=''>" if(!$param->{'optional'} && !$param->{'default'});
		$buff .= "</td></tr>\n";
	    }
	    $buff .= "</form>\n";
	} 
	$buff .= "</table>\n";
    }
    return $buff;
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
