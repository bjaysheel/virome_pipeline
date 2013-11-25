#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#-----------------------------------------------------------------------------------------------------
# program name: chado_admin.pl
# author:       Jay Sundaram
# date:         2005-11-20
#
# purpose:      
#
#-----------------------------------------------------------------------------------------------------


=head1 NAME

chado_admin.pl - 

=head1 SYNOPSIS

USAGE:  chado_admin.pl -D database [-M message] -P password [-S server] -U username [-c component] [-d debug_level] [-h] [-l logfile] [-m] [-p pipeline]

=head1 OPTIONS

=over 8

=item B<--database,-D>
    
    Target database name

=item B<--message,-M>
    
    Message to be sent to users

=item B<--password,-P>
    
    Database password

=item B<--server,-S>
    
    Optional - server name e.g. "SYBTIGR" or "SYBIL".  (default is "SYBTIGR")

=item B<--username,-U>
    
    Database username

=item B<--debug_level,-d>
    
    Optional - Coati::Logger log4perl logging level (default is 0)

=item B<--component,-c>
    
    Optional - Workflow component name

=item B<--help,-h>

    Print this help

=item B<--logfile,-l>
    
    Optional - Log4perl log file.  (default is /tmp/chado_admin.pl.log)

=item B<--man,-m>

    Display pod2usage man page for this utility

=item B<--pipeline,-p>

    Optional - Workflow pipeline URL


=back

=head1 DESCRIPTION

    chado_admin.pl - Drops all foreign key constraints and then all drops all tables
    e.g.
    1) ./chado_admin.pl -U username -P password -D chado_test -S SYBIL
    2) ./chado_admin.pl -U username -P password -D chado_test -S SYBIL -l chado_admin.log

=cut


use Prism;
use Pod::Usage;
use Data::Dumper;
use strict;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use Coati::Logger;
use Prism;
use Mail::Mailer;

$|=1;

my ($username, $password, $database, $server, $log4perl, $help, $man, $debug_level, $message, $component, $pipeline);


#---------------------------------------------------------------------------------
# Process the command-line arguments
#
my $results = GetOptions (
			  'database|D=s'        => \$database,
			  'message|M=s'         => \$message,
			  'password|P=s'        => \$password,
			  'server|S=s'          => \$server,
			  'username|U=s'        => \$username,
			  'debug_level|d=s'     => \$debug_level,
			  'help|h'              => \$help, 
			  'logfile|l=s'         => \$log4perl,
			  'man|m'               => \$man,
			  'component|c=s'       => \$component,
			  'pipeline|p=s'        => \$pipeline
			  );


&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT}) if ($man);
&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT}) if ($help);
  
print STDERR ("username not specified\n")  if (!$username);
print STDERR ("password not specified\n")  if (!$password);
print STDERR ("database not specified\n")  if (!$database);

&print_usage if(!$username or !$password or !$database);
#
#---------------------------------------------------------------------------------






#---------------------------------------------------------------------------------
# Initialize the logger
#
if (!defined($log4perl)){
    $log4perl = '/tmp/chado_admin.pl.log';
    print STDERR "log_file was set to '$log4perl'\n";
}

my $mylogger = new Coati::Logger('LOG_FILE'=>$log4perl,
				 'LOG_LEVEL'=>$debug_level);

my $logger = Coati::Logger::get_logger(__PACKAGE__);

#
#
#---------------------------------------------------------------------------------




#---------------------------------------------------------------------------------
# Valid servers are SYBIL or SYBTIGR
#
$server = &verify_and_set_server($server);
#
#---------------------------------------------------------------------------------




#
# Instantiate Prism object
#
my $prism = &retrieve_prism_object($username, $password, $database);


my $date = `date`;
chomp $date;


#
# comment:  Get list of users logged into this chado database.
#
my $userlist = $prism->chado_database_user_list($database);


#die Dumper $userlist;

my $subject = "[$database] ";
$subject .= "[$component] " if (defined($component));
$subject .= "access revoked";



my $body = "The script chado_admin.pl detected your login session in chado database [$database] at [$date].\n";

if (!defined($component)){
	$body .= "Please note that access to this database will be revoked.";
}
else {
	$body .= "Please note that access to this database will be revoked while workflow component [$component] operates on the database.\n";
}
$body .= "\nThis workflow can be viewed at http://sundaram-lx:8080/cgi-bin/ergatis/view_workflow_pipeline.cgi?instance=$pipeline\n" if (defined($pipeline));

$body .= $message if (defined($message));

$body .= "\nContact sundaram\@tigr.org if you have any questions regarding this automated email notice.";

&send_notification($userlist, $subject, $body);


print ("'$0': Program execution complete\n");
print ("Please review logfile: $log4perl\n");








#------------------------------------------------------------------------------------------------------------
#
#                                   END MAIN -- SUBROUTINES FOLLOW
#
#------------------------------------------------------------------------------------------------------------

#------------------------------------------------------
# send_notification()
#
#------------------------------------------------------
sub send_notification {

    my ($emaillist, $subject, $body) = @_;


	foreach my $username (sort @{$emaillist} ) { 

		my $mailer = Mail::Mailer->new ('sendmail');
		$mailer->open({
			To      => $username,
			Subject => $subject
		}) or $logger->logdie("Could not create and send message");
		
		print $mailer $body;
    
		$mailer->close;

		$logger->debug("Notification sent to $username") if $logger->is_debug;

	}

}


#----------------------------------------------------------------
# retrieve_prism_object()
#
#
#----------------------------------------------------------------
sub retrieve_prism_object {

    my ( $username, $password, $database, $pparse) = @_;

    $logger->debug("Instantiating Prism object") if ($logger->is_debug());
    
    if (defined($pparse)){
	$pparse = 0;
    }
    else{
	$pparse = 1;
    }
    

    my $prism = new Prism( 
			   user             => $username,
			   password         => $password,
			   db               => $database,
			   use_placeholders => $pparse,
			   );
    
    $logger->logdie("prism was not defined") if (!defined($prism));
    
    $logger->debug("prism:" . Dumper($prism)) if ($logger->is_debug());
    

    return $prism;


}#end sub retrieve_prism_object()


#--------------------------------------------------------------------
# verify_and_set_server()
#
#--------------------------------------------------------------------
sub verify_and_set_server {

    my $server = shift;

    if (!defined($server)){
	$server = 'SYBTIGR';
	$logger->info("server was set to '$server'");
    }
    else{
	if (($server eq 'SYBIL') or ($server eq 'SYBTIGR')){
	    $logger->debug("server is '$server'") if $logger->is_debug;
	}
	else {
	    $logger->logdie("server must be either SYBIL or SYBTIGR") ;
	}
    }

    return $server;
}




#--------------------------------------------------------------------
# print_usage()
#
#--------------------------------------------------------------------
sub print_usage {

    print STDERR "SAMPLE USAGE:  $0 -D database -P password [-S server] -U username [-c component] [-d debug_level] [-h] [-l logfile] [-m] [-p pipeline]\n".
    "  -D|--database           = target Chado database\n".
    "  -P|--password           = password\n".
    "  -S|--server             = Optional - server (default is SYBTIGR)\n".
    "  -U|--username           = username\n".
    "  -c|--component l        = Optional - Workflow component name\n".
    "  -d|--debug_level        = Optional - Coati::Logger log4perl logging level (default is 0)\n".
    "  -h|--help               = This help message\n".
    "  -l|--logfile            = Optional - log4perl log file (default is /tmp/chado_admin.pl.log)\n".
    "  -m|--man                = Display the pod2usage man page for this utility\n".
    "  -p|--pipeline           = Optional - Workflow pipeline URL\n";
    exit 1;

}

