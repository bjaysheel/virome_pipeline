package Coati::Cache::Data;

# $Id: Data.pm,v 1.26 2007-05-18 13:11:51 agussman Exp $

# Copyright (c) 2002, The Institute for Genomic Research. All rights reserved.

=head1 NAME
    
Data.pm - A module to cache perl data structures
    
=head1 VERSION
    
This document refers to version 1.00 of Cache.pm, released MMMM, DD, YYYY.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head2 Overview

=over 4

=cut

use strict;
use Storable qw(lock_store lock_retrieve store retrieve);
use Digest::MD5  qw(md5 md5_hex md5_base64);
use Coati::Logger;

=item new

B<Description:> The module constructor.

B<Parameters:> %arg, a hash containing attribute-value pairs to
initialize the object with. Initialization actually occurs in the
private _init method.

B<Returns:> $self (A Coati::Cache::Data object).

=cut


sub new {
    my $class = shift;
    my $self = bless {}, ref($class) || $class;
    $self->{_logger} = Coati::Logger::get_logger(__PACKAGE__);
    #Cache to memory only by default
    #If both are enabled, 
    #cache search order order is MEMORY, FILE with the first cache hit returned.
    #Note: In order for the cache to be persistent across instances, FILE caching must be enabled.
    $self->{_MEMORY} = 1; #Turn on/off memory based cache
    $self->{_FILE} = 0; #Turn on/off file based cache
    $self->{_EXPIRE} = -1; #Time in secs before cache is stale. NOTE: EXPIRE only applies to FILE caching. MEMORY caches are valid until the instance dies.
    $self->{_RECACHE_FILEHITS} = 1; #Hits to file caches are recached to memory.  This avoids repeated file I/O for repeated hits to file caches at the cost of memory footprint
    $self->{_cachedir} = "/tmp/";
    $self->{_fileext} = "cch";
    $self->{_delimeter} = "::";
    $self->{_CACHE_OBJS} = {};
    $self->{_CACHE_FILE_ACCESS} = undef;   # Set to O_RDONLY if the tied MLDBM cached lookup files should be accessed in read-only mode
    $self->{_logger}->debug("Init $class") if $self->{_logger}->is_debug;
    $self->_init(@_);
    #check for NFS mounted cache dir and turn off locks
    if($self->{_cachedir} =~ /\/usr\/local\//){
	$self->{_nolocks} = 1;
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
    my $self = shift;
    my %arg = @_;
    foreach my $key (keys %arg) {
        $self->{_logger}->debug("Storing member variable $key as _$key=$arg{$key}") if $self->{_logger}->is_debug;
	$self->{"_$key"} = $arg{$key}
    }
}

#######    ACCESSORS   #########

sub set_file_cache{
    my($self,$value) = @_;
    if(!defined $value){
	return $self->{_FILE};
    }
    else{
	my $prevvalue = $self->{_FILE};
	$self->{_FILE} = $value;
	return $prevvalue;
    }
}

sub set_memory_cache{
    my($self,$value) = @_;
    if(!defined $value){
	return $self->{_MEMORY};
    }
    else{
	my $prevvalue = $self->{_MEMORY};
	$self->{_MEMORY} = $value;
	return $prevvalue;
    }
}

sub seedCache{
    my($self,$ref,@args) = @_;
    $self->{_logger}->debug("Seeding cache ",join(',',@args)) if($self->{_logger}->is_debug());
    my $cachename = $self->_buildCacheName(@args);
    if($self->{"_MEMORY"}){
	$self->_seedCacheMem($cachename,$ref);
    }
    if($self->{"_FILE"}){
	$self->_seedCacheFile($cachename,$ref,\@args);
    }
}

sub clearCache{
    my($self) = @_;
    $self->{_logger}->debug("Clearing cache") if($self->{_logger}->is_debug());
    $self->{_CACHE_OBJS} = {};
}

sub _seedCacheFile{
    my($self,$cachename,$ref,$args) = @_;
    #use md5 of cachename as filename
    my $filename = "$self->{_cachedir}/$cachename.$self->{_fileext}";
    if(! -r $self->{_cachedir}){
	$self->{_logger}->logdie("Can't write to cache directory $self->{_cachedir}");
    }
    else{
	$self->{_logger}->debug("Writing file cache $filename ($cachename)") if($self->{_logger}->is_debug());
	$self->_writeDescFile("$filename.info",$args) if($args);
	$self->_writeCacheFile($filename,$ref);
    }
}
	
sub _seedCacheMem{
    my($self,$cachename,$ref) = @_;
    $self->{_logger}->debug("Writing memory cache $cachename") if($self->{_logger}->is_debug());
    $self->{_CACHE_OBJS}->{$cachename} = $ref;
}

sub queryCache{
    my $self = shift;
    $self->{_logger}->debug("Querying cache ",join(',',@_)) if($self->{_logger}->is_debug());
    my $cachename = $self->_buildCacheName(@_);
    $self->{_curr_cache_name} = $cachename;
    if($self->{"_MEMORY"} && $self->{"_FILE"}){
	return $self->_queryCacheMem($cachename) || $self->_queryCacheFile($cachename);
    }
    elsif($self->{"_MEMORY"}){
	return $self->_queryCacheMem($cachename);
    }
    elsif($self->{"_FILE"}){
	return $self->_queryCacheFile($cachename);
    }
}

sub _queryCacheFile{
    my $self = shift;
    my $cachename = shift;
    my $filename = "$self->{_cachedir}/$cachename.$self->{_fileext}"; 
    my($filedate) = _check_cache_file($filename);
    my($cachehit) = 0;
    if(defined $filedate){
	if(defined $self->{'_EXPIRE'} && $self->{'_EXPIRE'} != -1){
	    $cachehit = _check_cache_current($filedate,$self->{'_EXPIRE'});
	}
	else{
	    $cachehit = 1;
	}
    }
    $self->{_logger}->debug("Querying file cache $filename ($cachename)...",($cachehit ? "HIT" : "MISS")) if($self->{_logger}->is_debug());
    $self->{_FILECACHEHIT} = $cachehit;
    return $self->{_FILECACHEHIT};
}

sub _queryCacheMem{
    my $self = shift;
    my $cachename = shift;
    $self->{_MEMCACHEHIT} = exists $self->{_CACHE_OBJS}->{$cachename};
    $self->{_logger}->debug("Querying memory cache $cachename...",($self->{_MEMCACHEHIT} ? "HIT" : "MISS")) if($self->{_logger}->is_debug());
    return $self->{_MEMCACHEHIT};
}

sub dumpCache{
    my($self) = shift;
    my $cachename = $self->{_curr_cache_name};
    if($cachename ne ""){
	if($self->{_MEMCACHEHIT}){
	    $self->{_logger}->debug("Dumping memory cache $cachename") if($self->{_logger}->is_debug());
	    return $self->{_CACHE_OBJS}->{$cachename};
	}
	elsif($self->{_FILECACHEHIT}){
	    my $filename = "$self->{_cachedir}/$cachename.$self->{_fileext}"; 
	    $self->{_logger}->debug("Dumping file cache $cachename") if($self->{_logger}->is_debug());
	    my $ref = $self->_readCacheFile($filename); 
	    if($self->{'_RECACHE_FILEHITS'}){
		$self->{_CACHE_OBJS}->{$cachename} = $ref;
	    }
	return $ref;
	}
    }
    return undef;
}

sub getCacheInfo{
    my($self) = @_;

    if($self->{_FILECACHEHIT}){
	my $filename = "$self->{_cachedir}/$self->{_curr_cache_name}.$self->{_fileext}"; 
	my($filedate) = _check_cache_file($filename);

	return ($filename,$filedate);
    }
    elsif($self->{_MEMCACHEHIT}){

	return ($self->{_curr_cache_name},"memory");
    }

    return $self->{_cachedir}."/$self->{_curr_cache_name}.$self->{_fileext}";
}


sub _buildCacheName{
    my($self) = shift;
    my($str) = join($self->{_delimeter},@_);
    $str =~ s/\///g;
    return md5_hex($str);
}

sub _readCacheFile{
    my($self,$file) = @_;
    my $val;
    if($self->{_nolocks}){
	$val = retrieve($file);
    }
    else{
      eval {
	$val = lock_retrieve($file);
      };
      if ($@) {
	die "$! in $file";
      }
      
    }
    if(!defined $val){
	$self->{_logger}->logdie("Unable to read cache file $file");
    }
    return $val;
}
sub _writeDescFile{
    my($self,$file,$args) = @_;
    open FILE, "+>$file" or $self->{_logger}->logdie("Can't open cache description file $file");
    print FILE join("\n",@$args);
    close FILE;
    chmod 0666,$file;
}
sub _writeCacheFile{
    my($self,$file,$ref) = @_;
    my $val;
    if($self->{_nolocks}){
	$val = store($ref,$file);
    }
    else{
	$val = lock_store($ref,$file);
    }
    if(!defined $val){
	$self->{_logger}->logdie("Unable to write cache file $file");
    }
    if ((exists $self->{_SET_READONLY_CACHE}) &&
	( defined $self->{_SET_READONLY_CACHE}) &&
	( $self->{_SET_READONLY_CACHE} == 1 )) {
	chmod 0444,$file;
    }
    else {
	chmod 0666,$file;
    }
    return $val;
}
sub _check_cache_file{
    my($filename) = @_;
    my($filedate);
    if( -r $filename){
	$filedate = (stat($filename))[9];
        return $filedate;
    }
    return undef;
}
sub _check_cache_current{
    my($filedate,$expiretime) = @_;
    my($currtime) = time();
    my($cacheage) = $currtime - $filedate;
    if($cacheage >= $expiretime){
	return 0;
    }
    return 1;
}

1;
