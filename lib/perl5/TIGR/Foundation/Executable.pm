# $Id: Executable.pm,v 1.13 2001/04/10 17:42:11 dkosack Exp $

# (c) Copyright 2001 The Institute for Genomic Research

package TIGR::Foundation::Executable;
{
 
=head1 NAME

TIGR::Foundation::Executable - TIGR foundations module for executable scripts

=head1 SYNOPSIS

  use TIGR::Foundation::Executable;

=head1 DESCRIPTION

This module defines a structure for Perl programs to utilize
logging, versioning, and dependency checking in a simple way.

=cut

   BEGIN {
      require 5.006_00;                       # error if using Perl < v5.6.0  
   }

   use strict;
   use Cwd;
   use Cwd 'chdir';
   use Cwd 'abs_path';
   use File::Basename;
   use FindBin qw($RealBin $RealScript);
   use Getopt::Long;
   use IO::Handle;
   use POSIX qw(strftime);

   require Exporter;

   our (@ISA, @EXPORT);
   @ISA = ('Exporter');
   @EXPORT = qw(
                getProgramInfo
                runCommand

                printDependInfo
                printDependInfoAndExit
                addDependInfo

                getVersionInfo
                printVersionInfo
                printVersionInfoAndExit
                setVersionInfo

                printHelpInfo
                printHelpInfoAndExit
                setHelpInfo

                printUsageInfo
                printUsageInfoAndExit
                setUsageInfo

                isReadableFile
                isExecutableFile
                isWritableFile
                isCreatableFile
                isReadableDir
                isWritableDir
                isCreatableDir
                isCreatablePath

                setDebugLevel
                getDebugLevel
                setLogFile
                getLogFile
                getErrorFile
                printDependInfo
                logAppend
                logLocal
                logError
                bail

                chdir

                TIGR_GetOptions
               );                             # EXPORT these methods to host

   ## internal variables and identifiers
   our $REVISION = (qw$Revision: 1.13 $)[-1];
   our $VERSION = '1.0'; 
   our $VERSION_STRING = "$VERSION (Build $REVISION)";
   our @DEPEND = ();                          # there are no dependencies


   ## Instance variables and identifiers, by functional class

   # Functional Class : general
   my $PROGRAM_NAME = basename($0, ());       # extract the script name
   if ($PROGRAM_NAME =~ /^-$/) {              # check if '-' is the input
      $PROGRAM_NAME = "STDIN";
   }
   my $INVOCATION = join (' ', @ARGV);        # strip invocation info

   # Functional Class : depend
   my @__DEPEND_INFO = ();                    # take this from host program

   # Functional Class : version
   my $__VERSION_INFO = undef;                # take version from host program

   # Functional Class : help
   my $__HELP_INFO = undef;                   # take help from host program

   # Functional Class : usage
   my $__USAGE_INFO = undef;                  # take usage from host program

   # Functional Class : logging
   my $DEBUG_LEVEL = undef;                   # the default debug level is undef
                                              # log invocation and exit
   my @DEBUG_STORE = ();                      # the backup debug level stack
   my @DEBUG_QUEUE = ();                      # queue used by debugging routine
   my @ERROR_QUEUE = ();                      # queue used by logError routine
   my $MAX_DEBUG_QUEUE_SIZE = 100;            # maximum size for queue before
                                              # log entries are expired
   my @LOG_FILES =                            # these log files are consulted
      ("$PROGRAM_NAME.log",                   # on log file write error and are
       "/tmp/$PROGRAM_NAME.$$.log");          # modified on calling setLogFile
   my $MSG_FILE_OPEN_FLAG = 0;                # flag to check logLocal file
   my $ERROR_FILE_OPEN_FLAG = 0;              # flag to check logError file
   my $MSG_FILE_USED = 0;                     # flag to indicate if log file
   my $ERROR_FILE_USED = 0;                   #   has been written to
   my $MSG_APPEND_FLAG = 0;                   # by default logs are truncated
   my $ERROR_APPEND_FLAG = 0;                 # by default logs are truncated
   my $LOG_APPEND_SETTING = 0;                # (truncate == 0)
   my $STATIC_LOG_FILE = undef;               # user defined log file
   my $START_TIME = undef;                    # program start time
   my $FINISH_TIME = undef;                   # program stop time


   ## prototypes

   # Functional Class : general
   sub getProgramInfo($);
   sub runCommand($);

   # Functional Class : depend
   sub printDependInfo();
   sub printDependInfoAndExit();
   sub addDependInfo(@);

   # Functional Class : version
   sub getVersionInfo();
   sub printVersionInfo();
   sub printVersionInfoAndExit();
   sub setVersionInfo($);

   # Functional Class : help
   sub printHelpInfo();
   sub printHelpInfoAndExit();
   sub setHelpInfo($);

   # Functional Class : usage
   sub printUsageInfo();
   sub printUsageInfoAndExit();
   sub setUsageInfo($);

   # Functional Class : files
   sub isReadableFile($);
   sub isExecutableFile($);
   sub isWritableFile($);
   sub isCreatableFile($);
   sub isReadableDir($);
   sub isWritableDir($);
   sub isCreatableDir($);
   sub isCreatablePath($);

   # Functional Class : logging
   sub setDebugLevel($;$);
   sub getDebugLevel();
   sub setLogFile($;$);
   sub getLogFile();
   sub getErrorFile();
   sub printDependInfo();
   sub invalidateLogFILES();
   sub cleanLogFILES();
   sub closeLogERROR();
   sub closeLogMSG();
   sub openLogERROR();
   sub openLogMSG();
   sub logAppend($;$);
   sub debugPush();
   sub debugPop();
   sub logLocal($$);
   sub logError($);
   sub bail($;$);

   # Functional Class : modified methods
   sub TIGR_GetOptions(@);

   ## Implementation


# Functional Class : general

=over

=item $value = getProgramInfo($field_type);

This function returns field values for specified field types describing
attributes of the program.  The C<$field_type> parameter must be a listed
attribute: C<name>, C<invocation>, C<env_path>, C<abs_path>, C<exec_path>.
The C<name> field specifies the bare name of the executable.  The
C<invocation> field specifies the command line arguments passed to the
executable.   The C<env_path> value returns the environment path to the
working directory.  The C<abs_path> value specifies the absolute path to the
working directory.  If C<env_path> is found to be inconsistant, then that
value will return the C<abs_path> value.  The C<exec_path> value specifies
the absolute path to the executable.  If an invalid C<$field_type> is passed,
the function returns undefined.  

=cut


   sub getProgramInfo($) {
      my $field_type = shift;
      my $return_value = undef;
      if (defined $field_type) {
         $field_type =~ /^name$/ && do {
            $return_value = $PROGRAM_NAME;
         };
         $field_type =~ /^invocation$/ && do {
            $return_value = $INVOCATION;
         };
         $field_type =~ /^env_path$/ && do {
            my $return_value = "";
            if (
                (defined $ENV{'PWD'}) &&
                (abs_path($ENV{'PWD'}) eq abs_path("."))
               ) {
               $return_value = $ENV{'PWD'};
            }
            else {
               $return_value = abs_path(".");
            }
            return $return_value;
         };
         $field_type =~ /^abs_path$/ && do {
            $return_value = abs_path(".");
         };
         $field_type =~ /^exec_path$/ && do {
            $return_value = "$RealBin/$RealScript";
         };
      }
      return $return_value;
   }


=item $exit_code = runCommand($command_str);

This function passes the argument C<$command_str> to /bin/sh
for processing.  The return value is the exit code of the 
C<$command_str>.  If the exit code is not defined, then either the signal or
core dump value of the execution is returned, whichever is applicable.  Perl
variables C<$?> and C<$!> are set accordingly.  If C<$command_str> is not 
defined, this function returns undefined.  Log messages are recorded at log
level 4 to indicate the type of exit status and the corresponding code.
Invalid commands return -1.

=cut


   sub runCommand($) {
       my $command_str = shift;
       my $exit_code = undef; 
       my $signal_num = undef;
       my $dumped_core = undef;
       my $invalid_command = undef;
       my $return_value = undef;
       
       if (defined $command_str) {
          system($command_str);
          $exit_code = $? >> 8;
          $signal_num = $? & 127;
          $dumped_core = $? & 128;
          if ($? == -1) {
             $invalid_command = -1;
          }
          if ( 
              (!defined $invalid_command) &&
              ($exit_code == 0) &&
              ($signal_num == 0) &&
              ($dumped_core != 0)
             ) {
             logLocal("Command '" . $command_str . "' core dumped", 4);
             $return_value = $dumped_core;
          }
          elsif (
              (!defined $invalid_command) &&
              ($exit_code == 0) &&
              ($signal_num != 0)
             ) {
             logLocal("Command '" . $command_str .
                      "' exited on signal " . $signal_num, 4);
             $return_value = $signal_num;
          }
          elsif (
              (!defined $invalid_command)
             ) {
             logLocal("Command '" . $command_str .
                      "' exited with exit code " . $exit_code, 4);
             $return_value = $exit_code;
          }
          else {
             logLocal("Command '" . $command_str .
                      "' exited with invalid code " . $?, 4);
             $return_value = $?;
          }
       }
       return $return_value;
   }
   

# Functional Class : depend

=item printDependInfo();

The C<printDependInfo()> function prints the dependency list created by
C<addDependInfo()>.  One item is printed per line.

=cut


   sub printDependInfo() {
      foreach my $dependent (@__DEPEND_INFO) {
         print STDERR $dependent, "\n";
      }
   }


=item printDependInfoAndExit();

The C<printDependInfoAndExit()> function prints the dependency list created by
C<addDependInfo()>.  One item is printed per line.  The function exits with
exit code 0. 

=cut


   sub printDependInfoAndExit() {
      printDependInfo();
      exit 0;
   }


=item addDependInfo(@depend_list);

The C<addDependInfo()> function adds C<@depend_list> information
to the dependency list.  If C<@depend_list> is empty, the internal
dependency list is emptied.  Contents of C<@depend_list> are not checked
for validity (eg. they can be composed entirely of white space or
multiple files per record).  The first undefined record in C<@depend_list>
halts reading in of dependency information.

=cut


   sub addDependInfo(@) {
      my $num_elts = 0;
      while (my $data_elt = shift @_) {
         push (@__DEPEND_INFO, $data_elt);
         $num_elts++;
      }
      if ($num_elts == 0) {
         @__DEPEND_INFO = ();
      }
   }


# Functional Class : version

=item $version_string = getVersionInfo();

The C<getVersionInfo()> function returns the version information set by the
C<setVersionInfo()> function.

=cut


   sub getVersionInfo() {
      return $__VERSION_INFO;
   }


=item printVersionInfo();

The C<printVersionInfo()> function prints the version information set by the
C<setVersionInfo()> function.  If there is no defined version information,
a message is returned notifying the user.

=cut


   sub printVersionInfo() {
      if (defined $__VERSION_INFO) {
         print STDERR getProgramInfo('name'), " ", $__VERSION_INFO, "\n";
      }
      else {
         print STDERR getProgramInfo('name'),
            " has no defined version information\n";
      }
   }


=item printVersionInfoAndExit();

The C<printVersionInfoAndExit()> function prints version info set by the
C<setVersionInfo()> function.  If there is no defined version information,
a message is printed notifying the user.  This function calls exit with
exit code 0. 

=cut


   sub printVersionInfoAndExit() {
      printVersionInfo();
      exit 0;
   }


=item setVersionInfo($version_string);

The C<setVersionInfo()> function sets the version information to be reported
by C<getVersionInfo()>.  If C<$version_string> is empty, invalid, or
undefined, the stored version information will be undefined.

=cut


   sub setVersionInfo($) {
      my $v_info = shift;
      if (
          (defined $v_info) &&
          ($v_info =~ /\S/) &&
          ((ref $v_info) eq "")
         ) {
         $__VERSION_INFO = $v_info;
      }
      else {
         $__VERSION_INFO = undef;
      }
   }


# Functional Class : help

=item printHelpInfo();

The C<printHelpInfo()> function prints the help information passed by the
C<setHelpInfo()> function.

=cut


   sub printHelpInfo() {
      if (defined $__HELP_INFO) {
         print STDERR $__HELP_INFO;
      }
      else {
         print STDERR "No help information defined.\n";
      }
   }


=item printHelpInfoAndExit();

The C<printHelpInfoAndExit()> function prints the help info passed by the
C<setHelpInfo()> function.  This function exits with exit code 0.

=cut


   sub printHelpInfoAndExit() {
      printHelpInfo();
      exit 0;
   }


=item setHelpInfo($help_string);

The C<setHelpInfo()> function sets the help information via C<$help_string>.
If C<$help_string> is undefined, invalid, or empty, the help information 
is undefined.

=cut


   sub setHelpInfo($) {
      my $help_string = shift;
      if (
          (defined $help_string) &&
          ($help_string =~ /\S/) &&
          ((ref $help_string) eq "")
         ) {
         $__HELP_INFO = $help_string;
      }
      else {
         $__HELP_INFO = undef;
      }
   }


# Functional Class : usage

=item printUsageInfo();

The C<printUsageInfo()> function prints the usage information reported by the
C<setUsageInfo()> function.  If no usage information is defined, but help
information is defined, help information will be printed.

=cut


   sub printUsageInfo() {
      if (defined $__USAGE_INFO) {
         print STDERR $__USAGE_INFO;
      }
      elsif (defined $__HELP_INFO) {
         print STDERR $__HELP_INFO;
      }
      else {
         print STDERR "No usage information defined.\n";
      }
   }


=item printUsageInfoAndExit();

The C<printUsageInfoAndExit()> function prints the usage information the
reported by the C<setUsageInfo()> function and exits with status 0.

=cut


   sub printUsageInfoAndExit() {
      printUsageInfo();
      exit 0;
   }


=item setUsageInfo($usage_string);

The C<setUsageInfo()> function sets the usage information via C<$usage_string>.
If C<$usage_string> is undefined, invalid, or empty, the usage information 
is undefined.

=cut


   sub setUsageInfo($) {
      my $usage_string = shift;
      if (
          (defined $usage_string) &&
          ($usage_string =~ /\S/) &&
          ((ref $usage_string) eq "")
         ) {
         $__USAGE_INFO = $usage_string;
      }
      else {
         $__USAGE_INFO = undef;
      }
   }


# Functional Class : files

=item $valid = isReadableFile($file_name);

This function accepts a single scalar parameter containing a file name.
If the file corresponding to the file name is a readable plain file or symbolic
link, this function returns 1.  Otherwise, the function returns 0.  If the file
name passed is undefined, this function returns 0 as well.

=cut


   sub isReadableFile($) {
      my $file = shift;
 
      if (defined ($file) &&             # was a file name passed?
          ((-f $file) || (-l $file)) &&  # is the file a file or sym. link?
          (-r $file)                     # is the file readable?
         ) {
         return 1;
      }
      else {
         return 0;
      }
   }


=item $valid = isExecutableFile($file_name);

This function accepts a single scalar parameter containing a file name.
If the file corresponding to the file name is an executable plain file
or symbolic link, this function returns 1.  Otherwise, the function returns 0.
If the file name passed is undefined, this function returns 0 as well.

=cut


   sub isExecutableFile($) {
      my $file = shift;
 
      if (defined ($file) &&             # was a file name passed?
          ((-f $file) || (-l $file)) &&  # is the file a file or sym. link?
          (-x $file)                     # is the file executable?
         ) {
         return 1;
      }
      else {
         return 0;
      }
   }


=item $valid = isWritableFile($file_name);

This function accepts a single scalar parameter containing a file name.
If the file corresponding to the file name is a writable plain file
or symbolic link, this function returns 1.  Otherwise, the function returns 0.
If the file name passed is undefined, this function returns 0 as well.

=cut


   sub isWritableFile($) {
      my $file = shift;
 
      if (defined ($file) &&             # was a file name passed?
          ((-f $file) || (-l $file)) &&  # is the file a file or sym. link?
          (-w $file)                     # is the file writable?
         ) {
         return 1;
      }
      else {
         return 0;
      }
   }


=item $valid = isCreatableFile($file_name);

This function accepts a single scalar parameter containing a file name.  If
the file corresponding to the file name is creatable this function returns 1.
The function checks if the location of the file is writable by the effective
user id (EUID).  If the file location does not exist or the location is not
writable, the function returns 0.  If the file name passed is undefined,
this function returns 0 as well.  Note that files with suffix F</> are not
supported under UNIX platforms, and will return 0.

=cut


   sub isCreatableFile($) {
      my $file = shift;
      my $return_code = 0;

      if (
          (defined ($file)) &&
          (! -e $file) &&
          ($file !~ /\/$/) 
         ) {
         my $dirname = dirname($file);
         # check the writability of the directory
         $return_code = isWritableDir($dirname);
      }
      else {
         # the file exists, it's not creatable
         $return_code = 0;
      }
      return $return_code;
   }


=item $valid = isReadableDir($directory_name);

This function accepts a single scalar parameter containing a directory name.
If the name corresponding to the directory is a readable, searchable directory 
entry, this function returns 1.  Otherwise, the function returns 0.  If the
name passed is undefined, this function returns 0 as well.

=cut


   sub isReadableDir($) {
      my $file = shift;
 
      if (defined ($file) &&             # was a name passed?
          (-d $file) &&                  # is the name a directory?
          (-r $file) &&                  # is the directory readable?
          (-x $file)                     # is the directory searchable?
         ) {
         return 1;
      }
      else {
         return 0;
      }
   }


=item $valid = isWritableDir($directory_name);

This function accepts a single scalar parameter containing a directory name.
If the name corresponding to the directory is a writable, searchable directory 
entry, this function returns 1.  Otherwise, the function returns 0.  If the
name passed is undefined, this function returns 0 as well.

=cut


   sub isWritableDir($) {
      my $file = shift;
 
      if (defined ($file) &&             # was a name passed?
          (-d $file) &&                  # is the name a directory?
          (-w $file) &&                  # is the directory writable?
          (-x $file)                     # is the directory searchable?
         ) {
         return 1;
      }
      else {
         return 0;
      }
   }


=item $valid = isCreatableDir($directory_name);

This function accepts a single scalar parameter containing a directory name.  If
the name corresponding to the directory is creatable this function returns 1.
The function checks if the immediate parent of the directory is writable by the
effective user id (EUID).  If the parent directory does not exist or the tree
is not writable, the function returns 0.  If the directory name passed is
undefined, this function returns 0 as well.

=cut


   sub isCreatableDir($) {
      my $dir = shift;
      my $return_code = 0;

      if (defined ($dir)) {
         $dir =~ s/\/$//g;
         $return_code = isCreatableFile($dir);
      }
      return $return_code;
   }


=item $valid = isCreatablePath($path_name);

This function accepts a single scalar parameter containing a path name.  If
the C<$path_name> is creatable this function returns 1. The function checks 
if the directory hierarchy of the path is creatable or writable by the
effective user id (EUID).  This function calls itself recursively until
an existing directory node is found.  If that node is writable, ie. the path
can be created in it, then this function returns 1.  Otherwise, the function
returns 0.  This function also returns zero if the C<$path_name> supplied
is disconnected from a reachable directory tree on the file system.
If the path already exists, this function returns 0.  The C<$path_name> may
imply either a path to a file or a directory.  Path names may be relative or
absolute paths.  Any unresolvable relative paths will return 0 as well.  This
includes paths with F<..> back references to nonexistent directories.
Note, this function is recursive whereas C<isCreatableFile()> and 
C<isCreatableDir()> are not.

=cut


   sub isCreatablePath($) {
      my $pathname = shift;
      my $return_code = 0;

      if (defined $pathname) {
         # strip trailing '/'
         $pathname =~ s/(.+)\/$/$1/g;
         my $filename = basename($pathname);
         my $dirname = dirname($pathname);
         if (
             (! -e $pathname) &&
             ($dirname ne $pathname) &&
             ($filename ne "..")
            ) {
            if (-e $dirname) {
               $return_code = isWritableDir($dirname);
            }
            else {
               $return_code = isCreatablePath($dirname);
            }
         }
         else {
            $return_code = 0;
         }
      }
      return $return_code;
   }
         

# Functional Class : logging

=item setDebugLevel($new_level);

This function sets the level of debug reporting according to C<$new_level>.
If the debug level is less than 0, all debug reporting is turned off.
It is impossible to turn off error reporting from C<bail()>.  If C<$new_level>
is undefined, the debug level is set to 0.  This function maintains 
compatibility with C<GetOptions()>, and will accept a second parameter
the debug level, provided it is an integer.  In such cases, the first parameter
is checked only if the second parameter is invalid.  By default, the default
level is undefined.  To turn on debugging, you must invoke this function.

=cut


   sub setDebugLevel($;$) {
      my $new_level = shift;
      my $getopts_new_level = shift;

      if (
          (defined $getopts_new_level) &&
          ($getopts_new_level =~ /^-?\d+$/)
         ) {
         $new_level = $getopts_new_level;
      }
      elsif (
          (!defined $new_level) ||
          ($new_level !~ /^-?\d+$/)
         ) {
         $new_level = 0;
         logLocal("No or invalid parameter to setDebugLevel(), setting " .
                  "debug level to 0", 3);
      }

      if ($new_level < 0) {
         $new_level = -1;
      }

      $DEBUG_LEVEL = $new_level;
      logLocal("Set debug level to " . getDebugLevel(), 2);
   }


=item $level = getDebugLevel();

This function returns the current debug level.  If the current debug
level is not defined, this function returns undefined.

=cut


   sub getDebugLevel() {
      return $DEBUG_LEVEL;
   }


=item setLogFile($log_file);

This function sets the log file name for the C<logLocal()> function.
B<The programmer should call this function before invoking C<setDebugLevel()>>
if the default log file is not to be used.  The function takes one parameter,
C<$log_file>, which defines the new log file name.  If a log file is already
open, it is closed.  The old log file is not truncated or deleted.
Future calls to C<logLocal()> or C<bail()> will log to C<$log_file> if it
is successfully opened.  If the new log file is not successfully opened, 
the function will try to open the default log file, F<program_name.log>.
If that file cannot be opened, F</tmp/program_name.$process_id.log> will
be used.  If no log file argument is passed, the function will try to open
the default log file.  This function is C<GetOptions()> aware; it will accept
two parameters, using the second one as the log file and ignoring the first if
and only if two parameters are passed.  Any other usage specifies the first
parameter as the log file name.

=cut


   sub setLogFile($;$) {
      my $old_log_file = defined $STATIC_LOG_FILE ? $STATIC_LOG_FILE : undef;
      $STATIC_LOG_FILE = shift;
      if (scalar(@_) == 1) {
         $STATIC_LOG_FILE = shift;
      }

      # only consider a new log file that is definable as a file
      if ((defined ($STATIC_LOG_FILE)) &&
          ($STATIC_LOG_FILE !~ /^\s*$/)) {
         # delete an old log file entry added by "setLogFile"
         for (my $idx = 0;
              ($idx <= $#LOG_FILES) && defined($old_log_file);
              $idx++) {
            if ($LOG_FILES[$idx] eq $old_log_file) {
               splice @LOG_FILES, $idx, 1;
               $old_log_file = undef;
            }
         }
         unshift @LOG_FILES, $STATIC_LOG_FILE;

         # initialize the log file variables and file spaces
         $MSG_FILE_USED = 0;
         $ERROR_FILE_USED = 0;
         cleanLogFILES();
      }
   }


=item $log_file_name = getLogFile();

This function returns the name of the log file to be used for printing
log messages.  If no log file is available, this function returns undefined.

=cut


   sub getLogFile() {
      my $return_val = undef;
      if (
          (scalar(@LOG_FILES) != 0) &&
          (defined($LOG_FILES[0]))
         ) {
         $return_val = $LOG_FILES[0];
      }
      return $return_val;
   }


=item $error_file_name = getErrorFile();

This function returns the name of the error file to be used for printing
error messages.  The error file is derived from the log file; a F<.log>
extension is replaced by a F<.error> extension.  If there is no F<.log>
extension, then F<.error> is appended to the log file name.  If no
log files are defined, this function returns undefined.

=cut


   sub getErrorFile() {
      my $return_val = getLogFile();
      if (defined $return_val) {
         $return_val =~ s/\.log$//g;
         $return_val .= '.error';
      }
      return $return_val;
   }


   # the following private functions are used for logging


   # push items onto the debug level stack
   sub debugPush() {
      if (defined ($DEBUG_LEVEL)) {
         push @DEBUG_STORE, $DEBUG_LEVEL;
      }
      else {
         push @DEBUG_STORE, "undef";
      }
      $DEBUG_LEVEL = undef;
   } 


   # pop items from the debug level stack
   sub debugPop() {
      $DEBUG_LEVEL = pop @DEBUG_STORE;
      if (
          (!defined ($DEBUG_LEVEL)) || 
          ($DEBUG_LEVEL eq "undef")
         ) {
         $DEBUG_LEVEL = undef;
      }
   }


   # remove log files
   sub removeLogERROR() {
      debugPush();
      if (
          (defined getErrorFile()) &&
          (isWritableFile(getErrorFile()))
         ) {
         unlink getErrorFile() or
            logLocal("Unable to remove error file " . getErrorFile(), 3);
      }
      debugPop();
   }

   sub removeLogMSG() {
      debugPush();
      if (
          (defined getLogFile()) &&
          (isWritableFile(getLogFile()))
         ) {
         unlink getLogFile() or 
            logLocal("Unable to remove error file " . getLogFile(), 3);
      }
      debugPop();
   }


   # invalidate log files
   sub invalidateLogFILES() {
      debugPush();
      if (defined getLogFile()) {
         logLocal("Invalidating " . getLogFile(), 2); 
         shift @LOG_FILES;
         $MSG_APPEND_FLAG = $ERROR_APPEND_FLAG = $LOG_APPEND_SETTING;
         $MSG_FILE_USED = $ERROR_FILE_USED = 0;
         cleanLogFILES();
      }
      debugPop();
   }


   # clean previous log files
   sub cleanLogFILES() {
      if ($LOG_APPEND_SETTING == 0) {
         if ($MSG_FILE_USED == 0) {
            removeLogMSG();
         }
         if ($ERROR_FILE_USED == 0) {
            removeLogERROR();
         }
      }
   }


   # close log files
   sub closeLogERROR() {
      my $return_code = 1; # need to return true for success, false for fail

      debugPush();
      if (!close(ERRLOG) && (defined getErrorFile())) {
         logLocal("Cannot close " . getErrorFile(), 3);
         $return_code = 0;
      }
      else {
         $return_code = 1;
      }
      $ERROR_FILE_OPEN_FLAG = 0;
      debugPop();
      return $return_code;
   }   


   sub closeLogMSG() {
      my $return_code = 1; # need to return true for success, false for fail

      debugPush();
      if (!close(MSGLOG) && (defined getLogFile())) {
         logLocal("Cannot close " . getLogFile(), 3);
         $return_code = 0;
      }
      else {
         $return_code = 1;
      }
      $MSG_FILE_OPEN_FLAG = 0;
      debugPop();
      return $return_code;
   }   


   # open log files
   sub openLogERROR() {
      my $return_code = 1; # need to return true for success, false for fail

      debugPush();
      if ((defined getErrorFile()) && ($ERROR_FILE_OPEN_FLAG == 0)) {
         my $fileop;
         $ERROR_FILE_OPEN_FLAG = 1;
         if ($ERROR_APPEND_FLAG == 0) {
            $fileop = '>';
            $ERROR_APPEND_FLAG = 1;
         }
         else {
            $fileop = '>>';
         }
         if (open(ERRLOG, $fileop . getErrorFile())) {
            autoflush ERRLOG 1;
         }
         else {
            logLocal("Cannot open " . getErrorFile() . " for logging", 4);
            $ERROR_FILE_OPEN_FLAG = 0;
         }
      }
      $return_code = $ERROR_FILE_OPEN_FLAG;
      debugPop();

      # this is 1 if the file stream is open, 0 if not
      return $return_code;
   }


   sub openLogMSG() {
      my $return_code = 1; # need to return true for success, false for fail

      debugPush();
      if ((defined getLogFile()) && ($MSG_FILE_OPEN_FLAG == 0)) {
         my $fileop;
         $MSG_FILE_OPEN_FLAG = 1;
         if ($MSG_APPEND_FLAG == 0) {
            $fileop = '>';
            $MSG_APPEND_FLAG = 1;
         }
         else {
            $fileop = '>>';
         }

         if (open(MSGLOG, $fileop . getLogFile())) {
            autoflush MSGLOG 1;
         }
         else {
            logLocal("Cannot open " . getLogFile() . " for logging", 4);
            $MSG_FILE_OPEN_FLAG = 0;
         }
      }
      $return_code = $MSG_FILE_OPEN_FLAG;
      debugPop();

      # this is 1 if the file stream is open, 0 if not
      return $return_code;
   }


=item logAppend($log_append_flag);

The C<logAppend()> function takes either C<0> or C<1> as a flag to 
disable or enable log file appending.  By default, log files are 
truncated at the start of program execution or logging.  Error files are
controlled by this variable as well.  Invalid or undefined calls are ignored.
Calling this function with a C<0> argument after the log files have started
to be written may cause them to be truncated undesirably.  This function is
C<GetOptions()> compliant; if 2 and only 2 variables are passed, the second
option is treated as C<$log_append_flag>.

=cut


   sub logAppend($;$) {
      my $log_append_flag = shift;
      if (defined $_[0]) {
         $log_append_flag = shift;
      }
      if (
          (defined ($log_append_flag)) &&
          (($log_append_flag eq "0") ||
           ($log_append_flag eq "1"))
         ) {
         $LOG_APPEND_SETTING = $MSG_APPEND_FLAG = 
            $ERROR_APPEND_FLAG = $log_append_flag;
      }
   } 


=item logLocal($log_message, $log_level);

The C<logLocal()> function takes two arguments.  The C<$log_message>
argument specifies the message to be written to the log file.  The
C<$log_level> argument specifies the level at which C<$log_message> is printed.
The active level of logging is set via the C<setDebugLevel()> function.
Only messages at C<$log_level> less than or equal to the active debug
level are logged.  The default debug level is undefined.  Note, a trailing
new line, if it exists, is stripped from the log message.

=cut


   sub logLocal($$) {
      my $log_message = shift;
      my $log_level = shift;

      if ((!defined $log_level) || ($log_level =~ /\D/)) {
         $log_level = 1;
      }

      if (defined $log_message) {
         chomp $log_message; # strip end new line, if it exists

         my $time_val = strftime "[ %Y %b %e %H:%M:%S ]", localtime;
         $log_message = $time_val . " ($$) " . $log_message;
         push @DEBUG_QUEUE, [ $log_message, $log_level ];

         if ((defined (getDebugLevel())) && (getDebugLevel() > -1)) {
            while (
                   (defined(my $log_record = $DEBUG_QUEUE[0])) &&
                   (defined(getLogFile()))
                  ) {
               ($log_message, $log_level) = @{$log_record};
               if (
                   (
                    ($log_level <= getDebugLevel()) &&  # debug level suits
                    (openLogMSG())                  &&  # check for a log file
                    (print MSGLOG "$log_message\n") &&  # print the message
                    (closeLogMSG())                 &&  # close log file
                    ($MSG_FILE_USED = 1)                # log file used, '='
                   ) ||
                   (
                    ($log_level > getDebugLevel())      # debug level is not ok
                   ) 
                  ) {
                  # log message is successfully processed, so shift it off
                  shift @DEBUG_QUEUE;
               }
               else {
                  debugPush();
                  logLocal("Cannot log message \'$log_message\' to " .
                     getLogFile() . " = " .  $!, 9);
                  invalidateLogFILES(); 
                  debugPop();
               }
            }
         }
      }
      else {
         logLocal("logLocal() called without any parameters!",3);
      }

      while ($#DEBUG_QUEUE >= $MAX_DEBUG_QUEUE_SIZE) {
         # expire old entries; this needs to happen if $DEBUG_LEVEL
         # is undefined or there is no writable log file, otherwise the
         # queue could exhaust RAM.
         shift @DEBUG_QUEUE;
      }
   }
   

=item logError($log_message);

The C<logError()> function takes one argument.  The C<$log_message>
argument specifies the message to be written to the error file.  The 
C<$log_message> is also passed to C<logLocal>.  A message passed via
logError() will always get logged to the log file regardless of the
debug level.  Note, a trailing new line, if it exists, is stripped from the
the log message.

=cut


   sub logError($) {
      my $log_message = shift;

      if (defined $log_message) {
         chomp $log_message;  # strip end new line, if it exists
         logLocal($log_message, 0);

         my $time_val = strftime "[ %Y %b %e %H:%M:%S ]", localtime;
         $log_message = $time_val . " ($$) " . $log_message;
         push(@ERROR_QUEUE, $log_message);

         while (
                (defined(my $log_message = $ERROR_QUEUE[0])) &&
                (defined(getErrorFile()))
               ) {
            if (
                (openLogERROR()) &&     
                (print ERRLOG "$log_message\n") &&
                (closeLogERROR()) &&
                ($ERROR_FILE_USED = 1) # that is an '='
               ) {
               shift @ERROR_QUEUE;
            }
            else {
               debugPush();
               logLocal("Cannot log message \'$log_message\' to " .
                  getErrorFile() . " = $!", 6);
               invalidateLogFILES(); 
               debugPop();
            }
         }
      }
      else {
         logLocal("logError() called without any parameters!",3);
      }

      while ($#ERROR_QUEUE >= $MAX_DEBUG_QUEUE_SIZE) {
         # expire old entries; this needs to happen if $DEBUG_LEVEL
         # is undefined or there is no writable log file, otherwise the
         # queue could exhaust RAM.
         shift @ERROR_QUEUE;
      }
   }
 

=item bail($log_message);

The C<bail()> function takes a single required argument.  The C<$log_message>
argument specifies the message to be passed to C<logLocal()> and displayed
to the screen in using the C<warn> function.  All messages passed to C<bail()>
are logged regardless of the debug level.  The C<bail()> function
calls C<exit(1)> to terminate the program.  Optionally, a second positive
integer argument can be passed as the exit code to use.  Note, a trailing
new line, if it exists, is stripped from the end of the line.

=cut


   sub bail($;$) {
      my $log_message = shift;
      my $exit_code = shift;

      if (
          (!defined $exit_code) ||
          ($exit_code !~ /^\d+$/)
         ) {
         $exit_code = 1;
      }
      if (defined $log_message) {
         chomp $log_message;  # strip end new line, if it exists

         logError($log_message);
         print STDERR $log_message, "\n";
      }

      exit $exit_code;
   }


# Functional Class : modified methods

=item $getopts_error_code = TIGR_GetOptions(@getopts_arguments);

This function extends C<Getopt::Long::GetOptions()>.  It may be used
as C<GetOptions()> is used.  Extended functionality eliminates the need
to C<eval {}> the block of code containing the function.  Further, TIGR
standard options, such as C<-help>, are defined implicitly.  Using this
function promotes proper module behaviour.  Log and error files from 
previous runs are removed if the log file append option, C<-append>,
is not set.

The following options are defined by this function:

=over

=item -append

Turn on log file appending

=item -debug DEBUG_LEVEL

Set debugging to DEBUG_LEVEL

=item -logfile LOG_FILE_NAME

Set the default TIGR Foundation log file to LOG_FILE_NAME

=item -version, -V

Print version information and exit

=item -help, -H

Print help information and exit

=item -depend

Print dependency information and exit

=back

Regular C<GetOptions()> may still be used, however the C<TIGR_GetOptions()>
function eliminates some of the confusing issues with setting log files
and debug levels.  B<The options defined by C<TIGR_GetOptions()> cannot be
overridden or recorded>.  To get the log file and debug level after parsing
the command line, use C<getLogFile()> and C<getDebugLevel()>.  C<GetOptions()>
default variables, ie. those of the form C<$opt_I<optionname>>, are not
supported.  This function will return 1 on success.

=cut


   sub TIGR_GetOptions(@) {
      my @user_options = @_;

      my $append_var = undef;
      my $logfile_var = undef;
      my $debug_var = undef;

      # these foundation options support the defaults
      my @foundation_options = (
         "append=i" => \$append_var,
         "logfile=s" => \$logfile_var,
         "debug=i" => \$debug_var,
         "version|V" => \&printVersionInfoAndExit,
         "help|H" => \&printHelpInfoAndExit,
         "depend" => \&printDependInfoAndExit
      );

      Getopt::Long::Configure('no_ignore_case');
      my $getopt_code = eval 'GetOptions (@user_options, @foundation_options)';

      if (defined $append_var) {
         logAppend($append_var);
      }
      if (defined $logfile_var) {
         setLogFile($logfile_var);
      }
      if (defined $debug_var) {
         setDebugLevel($debug_var);
      }

      # remove old log files, if necessary
      for (
           my $file_control_var = 0;
           $file_control_var <= $#LOG_FILES;
           $file_control_var++
          ) {
          cleanLogFILES();
          push(@LOG_FILES, shift @LOG_FILES);
      }
      return $getopt_code;
   }


   # Log program invocation
   logLocal("START: " . getProgramInfo('name') . " " .
                        getProgramInfo('invocation'), 0);
   $START_TIME = time;

   END {
      $FINISH_TIME = time;
      my $time_difference = $FINISH_TIME - $START_TIME;
      my $num_days = int($time_difference / 86400); # there are 86400 sec/day
      $time_difference -= $num_days * 86400;
      my $num_hours = int($time_difference / 3600); # there are 3600 sec/hour
      $time_difference -= $num_hours * 3600;
      my $num_min = int($time_difference / 60); # there are 60 sec/hour
      $time_difference -= $num_min * 60;
      my $num_sec = $time_difference; # the left overs are seconds
      my $time_str = sprintf "%03d-%02d:%02d:%02d", $num_days, $num_hours,
         $num_min, $num_sec;
      logLocal("FINISH: ".getProgramInfo('name').", elapsed ".$time_str ,0);
   }
}

=back

=head1 USAGE

The basic operation of this module involves simply C<use>ing it.

A sample case follows:

   use strict;
   use TIGR::Foundation::Executable;

   MAIN: 
   {
      my @DEPEND = ("/usr/bin/perl", "/sbin/stty");
      my $VERSION = 1.0;
      my $HELP_INFO = "This is my help\n";

      addDependInfo(@DEPEND);
      setVersionInfo($VERSION);
      setHelpInfo($HELP_INFO);

      my $input_file;
      my $output_file;

      TIGR_GetOptions("input=s" => \$input_file,
                      "output=s" => \$output_file);

      logLocal("My input file is $input_file", 1);
      print "Hello world", "\n";
      logLocal("My output file is $output_file.", 1);
   }

=cut

1; 
