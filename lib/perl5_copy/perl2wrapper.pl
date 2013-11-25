=head1 NAME

perl2wrapper.pl 

=head1 SYNOPSIS

This project provides a library of functions used by Makefile.PL for
installation of Coati client projects.

=cut

use File::Basename;
use File::Find;

sub get_bins{
    my($instdir);
    my(@binfiles);
    my($wrapper_str);
    my $perl_path = $^X;  ## can be overwritten below
    
    foreach my $arg (@ARGV){
	if($arg =~ /PREFIX/){
	    
            print STDERR "\nPlease use INSTALL_BASE instead of PREFIX (requires ExtUtils::MakeMaker 6.31 or higher)\n\n";
            
	} elsif ($arg =~ /INSTALL_BASE/) {
            ($instdir) = ($arg =~ /INSTALL_BASE=(.*)/);
        }
        
        if($arg =~ /PERL_PATH/){
            ($perl_path) = ($arg =~ /PERL_PATH=(.*)/);
        }
    }

    open FILE, 'MANIFEST' or die "MANIFEST is missing!\n";
    open SYMS, "+>README.binaries" or die "Can't save symlinks for silly sadmins";
    print SYMS "#Copy or symlink the following shell scripts into a standard area\n";

    my $addedcode = "";

    if($ENV{SHELLCODE} ne ""){
	$addedcode = $ENV{SHELLCODE};
    }

    my $env_hash = &parse_config();

    my $envbuffer;

    foreach my $key (keys %$env_hash){
	$envbuffer .= "if [ -z \"\$$key\" ]\nthen\n    $key=$env_hash->{$key}\nexport $key\nfi\n";
    }

    while(my $line = <FILE>){
	chomp $line;
	if($line =~ m|bin/\w+\.pl|){
	    my($fname) = basename($line);
	    my($strip_fname) = ($fname =~ /(.*)\.pl$/);
	    open WRAPPER, "+>bin/$strip_fname" or die "Can't open file bin/$strip_fname\n";
	    my($shell_args)  = q/"$@"/;
            print WRAPPER <<_END_WRAPPER_;
#!/bin/sh
$addedcode
$envbuffer

exec $perl_path -I $instdir/lib/perl5 $instdir/bin/$fname $shell_args    

_END_WRAPPER_
   ;
	    close WRAPPER;
	    
	    print SYMS "$instdir/bin/$strip_fname\n";
	    
	    push @binfiles,"bin/$fname";
	    push @binfiles,"bin/$strip_fname";
	    $wrapper_str .= "bin/$strip_fname ";
	}
    }
    close SYMS;
    close FILE;
    return (\@binfiles,$wrapper_str);
}

my($project_name);

sub find_config{
    my($file) = $File::Find::name;
    if($file =~ m|conf/\w+\.conf|){
	($project_name) = ($file =~ m|conf/(\w+)\.conf|);
    }
}
       

sub get_project{
    find(\&find_config,".");
    return $project_name;
}


sub parse_config{
    my ($backend, $configpath, $schema, $server);

    if(!$project_name){
	$project_name = &get_project();
    }

    my $uc_project_name = uc($project_name);

    my $supported_dbregex = '^\s*\w+:(BulkSybase:\w+|Sybase:\w+|Mysql:\w+|Postgres:\w+)';
    my $supported_envregex = '\w+=';

    my($file) = $File::Find::name;
    my $configfile;
    find(sub {
	my($file) = $File::Find::name;
	if($file =~ m|conf/\w+\.conf$|){
	    $configpath = $file;
	}
	},".");

    my %envhash = ();
    
    if(-e $configpath){
      
      open CONFIG, "<", "$configpath"
        or die qq|Could not open "$CONFIG" at $configpath, stopped|;
      
    my $line;
      while (<CONFIG>) {
        chomp ($line = $_);             # First, remove the trailing newline.
        next unless $line =~ m/\w/;     # Skip lines that have just white space.
        $line =~ s/^\s+//g;             # Remove any leading white space
        next if $line =~ m/^\#/;        # Skip the line if it's commented.
        $line =~ s/\s+\#.*$//g;         # Remove any trailing white space / comments.
	$line =~ s/\s+$//;
        if ($line =~ m/$supported_dbregex/i){
            if ($envhash{$uc_project_name}) {
                ($schema, $backend, $server) = split (':', $envhash{$uc_project_name});
            } else {
                ($schema, $backend, $server) = split (':', $line);
                $envhash{$uc_project_name} = $line;
            }
        } elsif ($line =~ m/$supported_envregex/i){
            my ($key, $value) = ($line =~ /([^=]+)=(.+)/);
	    if($key ne "" && $value ne ""){
		$envhash{$key} = $value;
	    }
            #$self->_trace(qq|Received environment variable "$key" with value "$value".|)
                #if ($self->{_debug} > 1);
        }

    }
 
    close CONFIG or die "$MODNAME: Could not close the configuration file, stopped";
    #$self->_trace(qq|Returning configuration "$schema, $backend, $server".|) if ($self->{_debug});
    }
    
    return \%envhash;
};


return 1;
