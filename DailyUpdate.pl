#!/usr/cs/bin/perl
# use perl                                  -*- mode: Perl; -*-
eval 'exec perl -S $0 "$@"'
  if $running_under_some_shell;

use vars qw($running_under_some_shell);         # no whining!

# For documentation, do "perldoc DailyUpdate.pl". Also visit
#   http://www.cs.virginia.edu/~dwc3q/code/DailyUpdate/index.html.
# To subscribe to the Daily Update mailing list, send email to
#   majordomo@everett.com with "subscribe dailyupdate" in the body of the
#   message.

# I suggest using wwwis by Alex Knowles if your html file contains a lot of
# images, which can slow down viewing time on browsers. His script, at
# http://www.tardis.ed.ac.uk/~ark/wwwis/, will determine image sizes and
# insert them into the HTML.

#------------------------------------------------------------------------------

# If you would like to be notified of updates, send email to me at
# coppit@cs.virginia.edu. The latest version is always at
# http://www.cs.virginia.edu/~dwc3q/code/DailyUpdate/index.html.

# Written by: David Coppit  http://www.cs.virginia.edu/~dwc3q/index.html
#                          <coppit@cs.virginia.edu>

# Please send me any modifications you make. Keep in mind that I'm likely to
# turn down obscure features to avoid including everything but the kitchen
# sink.

# This code is distributed under the GNU General Public License (GPL). See
# http://www.opensource.org/gpl-license.html and http://www.opensource.org/.

#------------------------------------------------------------------------------

require 5.004;
use strict;

# Debug mode: doesn't put a time limit on the script, outputs some
# <!--DEBUG:...--> commentary, and doesn't write to the output file (instead
# it dumps to screen).
use constant DEBUG => 0;

# SYSCONFIGDIR is where system-wide configuration is stored. It is set
# during installation. If no user-specific configuration is found, this
# configuration information is used.
use constant SYSCONFIGDIR => '/users/dwc3q/scripts/DailyUpdate/development';

use Getopt::Std;

# $home is used in the config file sometimes
use vars qw( $VERSION $home );

$VERSION = do { my @r = (q$Revision: 7.0 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

# ------------------------------------------------------------------------------

sub usage
{
<<EOF;
usage: DailyUpdate.pl [-anrv] [-i inputfile] [-o outputfile] [-c configfile]

-i The template file to use as input (overrides value in configuration file)
-o The output file (overrides value in configuration file)
-c The configuration file to use
-a Automatically download handlers as needed
-n Check for new versions of the handlers
-r Forces caching proxies to reload data
-v Output to STDOUT in addition to the file
EOF
}

use vars qw( *OLDOUT %config %opts );

# ------------------------------------------------------------------------------

sub LoadConfig
{
  # Make sure the system-wide configuration directory and the user's directory
  # are on INC
  unshift @INC,SYSCONFIGDIR;
  unshift @INC,"$home/.DailyUpdate";

  if (defined $opts{c})
  {
    open CONFIG,$opts{c} or die "Can't open configuration file $opts{c}: $!";
    my $config = join '',<CONFIG>;
    close CONFIG;
    eval $config;
  }
  else
  {
    require 'DailyUpdate.cfg';
  }

  print "<!--DEBUG: DailyUpdate.cfg found in $INC{'DailyUpdate.cfg'}.-->\n"
    if DEBUG;

  # Take off the system directory now that configuration is loaded
  shift @INC;
  shift @INC;

  die "\"handlerlocations\" in DailyUpdate.cfg must be non-empty.\n"
    if $#{$config{handlerlocations}} == -1;

  # Put the handler locations on the include search path
  unshift @INC,@{$config{handlerlocations}};

  # Put the Daily Update module file location, if it is specified
  push @INC,$config{modulepath};

  # Override the config values if the user specified -i or -o
  $config{inputFiles} = ["$opts{i}"] if defined $opts{i};
  $config{outputFiles} = ["$opts{o}"] if defined $opts{o};

  # Check that the input files and output files match
  if ($#{$config{inputFiles}} != $#{$config{outputFiles}})
  {
    print "Your input and output files are not correctly specified.\n";
    die "Check your configuration.\n";
  }

  die "No input files specified.\n" if $#{$config{inputFiles}} == -1;

  # Check that they specified cachelocation and maxcachesize
  die "cachelocation not specified in DailyUpdate.cfg"
    unless defined $main::config{cachelocation} &&
           $main::config{cachelocation} ne '';
  die "maxcachesize not specified in DailyUpdate.cfg"
    unless defined $main::config{maxcachesize} &&
           $main::config{maxcachesize} != 0;
}

# ------------------------------------------------------------------------------

sub HandleProxyPassword
{
  # Handle the proxy password, if a username was given but not a password, and
  # a tty is available.
  if (($config{proxy_username} ne '') &&
      (($config{proxy_password} eq '') && (-t)))
  {
    unless (eval "require Term::ReadKey")
    {
      print "You need Term::ReadKey for password authorization. ";
      print "Get it from CPAN.\n";
      exit(1);
    }
    require FileHandle;

    # Make unbuffered
    my $oldBuffer = $|;
    $|=1;

    print "Please enter your proxy password: ";
    my $DEV_TTY = new FileHandle;
    open($DEV_TTY,"</dev/tty") || die "Unable to open /dev/tty: $!\n";

    # Temporarily disable strict subs so this will compile even though we
    # haven't require'd Term::ReadKey yet.
    no strict "subs";

    # Turn off echo to read in password
    Term::ReadKey::ReadMode (2, $DEV_TTY);
    $config{proxy_password} = Term::ReadKey::ReadLine (0, $DEV_TTY);

    # Turn echo back on
    Term::ReadKey::ReadMode (0, $DEV_TTY);

    # Restore strict subs
    use strict "subs";

    # Give the user a visual cue that their password has been entered
    print "\n";

    chomp($config{proxy_password});
    close($DEV_TTY) || warn "Unable to close /dev/tty: $!\n";
    $| = $oldBuffer;
  }
}

# ------------------------------------------------------------------------------

BEGIN
{
  if (DEBUG)
  {
    print "<!--DEBUG: Command line was:-->\n";
    print "<!--DEBUG:   $0 @ARGV-->\n";
  }

  # See if the user specified the input and output files on the command line.
  getopt('ioc',\%opts);

  print usage and exit(0) if $opts{h};

  # Get the user's home directory.
  $home = eval { (getpwuid($>))[7] } || $ENV{HOME};

  LoadConfig();

  HandleProxyPassword();

  if (DEBUG)
  {
    print "<!--DEBUG: Options are:-->\n";
    foreach my $i (keys %opts)
    {
      print "<!--DEBUG:   $i: $opts{$i}-->\n";
    }

    print "<!--DEBUG: INC is:-->\n";
    foreach my $i (@INC)
    {
      print "<!--DEBUG:   $i-->\n";
    }
  }
}

#------------------------------------------------------------------------------

# Disable the timers if in debug mode or on the (broken) Windows platform
if ((!DEBUG) && ($^O ne 'MSWin32') && ($^O ne 'dos'))
{
  if ((my $scriptpid = fork) != 0) 
  {
    if ((my $sleeppid = fork) != 0)   # Fork off the timer
    {
      # If Daily Update finishes before the timer goes off, kill the timer and
      # exit.
      waitpid ($scriptpid,0);
      kill 9,$sleeppid;
    }
    else 
    {
      # If the timer goes off before Daily Update finishes, kill Daily Update
      # (which will also kill the "Waiter" process) and exit.
      sleep $config{scriptTimeout};
      print "Daily Update script timeout has expired. Daily Update killed.\n";
      kill 9,$scriptpid;
    }
    exit(1);
  }
}

# Make unbuffered for easier debugging.
$| = 1 if (DEBUG);

for (my $i=0;$i <= $#{$config{inputFiles}};$i++)
{
  print "<!--DEBUG: Now processing $config{inputFiles}[$i] => $config{outputFiles}[$i]. -->\n" if DEBUG;

  # Figure out if we were called as a CGI program
  my $calledAsCgi = 0;
  $calledAsCgi = 1 if defined $ENV{'SCRIPT_NAME'};

  # We'll write to the file unless we were run as a CGI or if we're in DEBUG
  # mode.
  my $writeToFile = 1;
  $writeToFile = 0 if DEBUG || $calledAsCgi;


  # Print the content type if we're running as a CGI.
  print "Content-type: text/html\n\n" if $calledAsCgi;

  # Redirect STDOUT to a temp file.
  if ($writeToFile)
  {
    # Store the old STDOUT so we can replace it later.
    open (OLDOUT, ">&STDOUT");

    # If the user wants to see a copy of the output...
    if ($opts{v})
    {
      # Make unbuffered
      $| = 1;
      open (STDOUT,"| tee $config{outputFiles}[$i].temp");
    }
    else
    {
      open (STDOUT,">$config{outputFiles}[$i].temp");
    }
  }

  require DailyUpdate::Parser;

  # Okay, now do the magic. Parse the input file, calling the handlers whenever
  # a special tag is seen.

  my $p = new DailyUpdate::Parser;
  $p->parse_file($config{inputFiles}[$i]);

  # Restore STDOUT to the way it was
  if ($writeToFile)
  {
    close (STDOUT);
    open(STDOUT, ">&OLDOUT") or die "Can't restore STDOUT.\n";

    # Replace the output file with the temp file. Move it to .del for OSes
    # that have delayed deletes.
    rename ($config{outputFiles}[$i], "$config{outputFiles}[$i].del");
    unlink ("$config{outputFiles}[$i].del");
    rename ("$config{outputFiles}[$i].temp",$config{outputFiles}[$i]);
    chmod 0755, $config{outputFiles}[$i];
  }

  # Stop after the first file if we're being run as a CGI. (I guess...)
  last if $calledAsCgi;
}

exit(0);

#-------------------------------------------------------------------------------

=head1 NAME

Daily Update - downloads and integrates dynamic information into your webpage

=head1 SYNOPSIS

DailyUpdate.pl [B<-anrv>] [B<-i> inputfile] [B<-o> outputfile]
  [B<-c> configfile]

=head1 DESCRIPTION

I<Daily Update> grabs dynamic information from the internet and integrates it
into your webpage. Features include modular extensibility, timeouts to handle
dead servers without hanging the script, user-defined update times, automatic
installation of modules, and compatibility with cgi-wrap. 

Daily Update takes an input HTML file, which includes special tags of the
form:

  <!--dailyupdate
    <input name=X>
    <filter name=Y>
    <output name=Z>
  -->

where I<X> represents a data source, such as "apnews", "slashdot", etc. When
such a tag is encountered, Daily Update attempts to load and execute the
handler to acquire the data. Then the data is sent to the filter named by
I<Y>, and then on to the output handler named by I<Z>.  If the handler can not
be found, the script asks for permission to attempt to download it from the
central repository at
http://www.cs.virginia.edu/~dwc3q/code/DailyUpdate/handlers.html.

=head1 HANDLERS

Daily Update has a modular architecture, in which I<handlers> implement the
acquisition and output of data gathered from the internet. To use new data
sources, first locate an interesting one at
http://www.cs.virginia.edu/~dwc3q/code/DailyUpdate/handlers.html, then place
the Daily Update tag in your input file. Then run Daily Update once manually,
and it will prompt you for permission to download and install the handler.

You can control, at a high level, the format of the output data by using the
built-in filters and handlers described on the handlers web page. For more
control over the style of output data, you can write your own handlers in
Perl. For more information, see the on-line user's manual at
http://www.cs.virginia.edu/~dwc3q/code/DailyUpdate/manual.html.

To help handler developers, a utility called I<MakeHandler.pl> is included with
the Daily Update distribution. It is a generator that asks several questions,
and then creates a basic handler.  Handler development is supported by two
APIs, I<AcquisitionFunctions> and I<HTMLTools>. For a complete description of
these APIs, as well as suggestions on how to write handlers, visit
http://www.cs.virginia.edu/~dwc3q/code/DailyUpdate/handlers.html.


=head1 OPTIONS AND ARGUMENTS

=over 4

=item B<-i>

Override the input file specified in the configuration file.

=item B<-o>

Override the output file specified in the configuration file.

=item B<-c>

Use the specified file as the configuration file, instead of DailyUpdate.cfg.

=item B<-a>

Automatically download all handlers that are not installed locally.

=item B<-n>

Check for new versions of handlers while processing input file.

=item B<-r>

Reload the content from the proxy server even on a cache hit. This prevents
Daily Update from using stale data when constructing the output file.

=item B<-v>

Verbose output. Output a copy of the information sent to the output file to
standard output.

=back

=head1 Configuration

The file DailyUpdate.cfg contains the configuration. Daily Update will first
look for this file in ~/.DailyUpdate, and then in the system-wide location
specified during installation. If both of these fail, it will search the
standard Perl library path. In this file you can specify the following:

=over 2

=item *

Multiple input and output files.

=item *

The timeout value for the script. This puts a limit on the total time the
script can execute, which prevents it from hanging.

=item *

The timeout value for socket connections. This allows the script to recover
from unresponsive servers.

=item *

Your proxy host. For example, "http://proxy.host.com:8080/"

=item *

The locations of handlers. For example, ['dir1','dir2'] would look for handlers
in dir1/DailyUpdate/Handler/ and dir2/DailyUpdate/Handler/. Note that while
installing handlers, the first directory is used.

=item *

The size and location of the HTML cache Daily Update uses to store data in
between the update times specified by the handlers.

=item *

The location of Daily Update's modules, in case the aren't in the standard
Perl module path. (Set during installation.)

=item *

The maximum age and location of images stored locally by the I<cacheimages>
filter.

=item *

DOS/Windows users can specify their time zone. (Set during installation.)

=back

See the file DailyUpdate.cfg for examples.


=head1 RUNNING

You can run DailyUpdate.pl from the command line, but a better
way is to run the script as a cron job. To do this, create a .crontab file
with something similar to the following:

=over 4

0 7,10,13,16,19,22 * * * /users/dwc3q/public_html/cgi-bin/DailyUpdate.pl

=back

You can also have cgiwrap call your startup page, but this would mean having to
wait for the script to execute (2 to 30 seconds, depending on the staleness of
the information). To do this, place DailyUpdate.pl and DailyUpdate.cfg in your
public_html/cgi-bin directory, and use a URL similar to the following:

=over 4

http://www.cs.virginia.edu/cgi-bin/cgiwrap?user=dwc3q&script=DailyUpdate.pl

=back

=head1 PREREQUISITES

This script requires the C<Date::Manip>, C<LWP::UserAgent> (part of libwww),
C<URI>, C<HTML-Tree>, and C<HTML::Parser> modules, in addition to others that
are included in the standard Perl distribution.  Download them all from CPAN
at http://www.perl.com/CPAN/modules/by-module/.

Handlers that you download may require additional modules.

=head1 AUTHOR

David Coppit, <coppit@cs.virginia.edu>,
http://www.cs.virginia.edu/~dwc3q/index.html

=begin CPAN

=pod COREQUISITES

none

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

HTML/Preprocessors

=end CPAN

=cut
