#!/usr/cs/bin/perl
# use perl                                  -*- mode: Perl; -*-
eval 'exec perl -S $0 "$@"'
  if $running_under_some_shell;

use vars qw($running_under_some_shell);         # no whining!

# For documentation, do "perldoc DailyUpdate.pl". Also visit
#   http://www.cs.virginia.edu/~dwc3q/code/DailyUpdate/index.html.
# For documentation on how to write handlers, go to
#   http://www.cs.virginia.edu/~dwc3q/code/DailyUpdate/handlers.html

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

# Version History (major changes only)

# 6.02 Added support for proxies requiring passwords. (Thanks to Kevin D.
#      Clark <kclark@cabletron.com>.) Fixed a bug in HTMLTools.pm. (Thanks to
#      Mark Harburn <Mark.Harburn@durham.ac.uk>). Improved site-wide
#      installation. (Thanks to John Goerzen <jgoerzen@complete.org>.) Fixed a
#      bug in output columns (Thanks to Craig Brockmeier
#      <craig@seurat.ppco.com> for finding it.)
# 6.01 Added -r switch to force proxies to reload cached data (thanks to
#      Gerhard Wiesinger <e9125884@student.tuwien.ac.at>). Improved
#      installation. Fixed a couple of minor bugs. Config file can now be
#      left in installation directory, and the handlers are installed in the
#      installation directory.
# 6.00 Now the installation mimicks the usual "perl Makefile.PL;make;make
#       install" of perl modules.
#      The script now supports multiple input and output files in the
#       configuration file.
#      Changed the syntax from <dailyupdate...> to <!--dailyupdate...--> so 
#       that WYSIWYG editors won't croak on the 'unknown' tag.
#      Moved HTML-related functionality from AcquisitionFunctions.pm to
#       HTMLTools.pm, and added function StripTags.
#      Fixed 2 bugs in MakeLinksAbsolute. (Thanks to Kazuo Moriwaka
#       <kankun@osa.att.ne.jp> and Phillip Gersekowski
#       <philg@toonews.c-link.com.au>)
#      Enhanced Handler to work better in the face of bad data acquisition and
#       filtering.
#      Added OutputList to OutputFunctions.pm, which allows you to set the
#       format and number of columns when printing out lists.
# 5.1 Update times are now set by the handlers by overriding GetUpdateTimes.
#     (The default is 2,5,8,11,14,17,20,23.) Users can still customize the
#     update times in the configuration file. Modified MakeHandler.pl to
#     support this.
#       Fixed a caching bug that would cause (a) multiple copies of some data
#     when a tag is used more than once on the same page, and (b) reuse of
#     cached data even when the style has been changed.
#       Added -a and -n flags.
#     Removed use of the deprecated HTML::Parse in AcquisitionFunctions.pm
# 5.0 This is a major rewrite -- I made the architecture object-oriented.
#     (As Fred Brooks says, plan to build it twice, because you will end up
#     doing it anyway.)
#       Daily Update now sports a nifty plugin architecture for handlers that
#     allows quite a bit more freedom for end users, compared to the kludgy
#     schema interface DailyUpdate had before. Also, there is support for
#     automatic downloading of missing handlers.

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
use constant SYSCONFIGDIR => "/usr/cs/etc";

# Need to use this to get the current directory so DailyUpdate.cfg will be
# found when run as a cron job.
use Getopt::Std;

use vars qw( $VERSION );

$VERSION = do { my @r = (q$Revision: 6.2 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

# ------------------------------------------------------------------------------

sub usage
{
<<EOF;
usage: DailyUpdate.pl [-anr] [-i inputfile] [-o outputfile] [-c configfile]

-i The template file to use as input (overrides value in configuration file)
-o The output file (overrides value in configuration file)
-c The configuration file to use
-a Automatically download handlers as needed
-n Check for new versions of the handlers
-r Forces caching proxies to reload data
EOF
}

# ------------------------------------------------------------------------------

use vars qw( *OLDOUT %config %opts );

BEGIN
{
  if (DEBUG)
  {
    print "<!--DEBUG: Command line was:-->\n";
    print "<!--DEBUG:   $0 @ARGV-->\n";
  }

  # Here $ENV{HOME} is set during installation on DOS/Windows systems.
  # $ENV{HOME} = '';

  # See if the user specified the input and output files on the command line.
  getopt('ioc',\%opts);

  print usage and exit(0) if $opts{h};

  # Make sure the system-wide configuration directory and the user's directory
  # are on INC
  unshift @INC,SYSCONFIGDIR;
  unshift @INC,"$ENV{HOME}/.DailyUpdate";

  if (defined $opts{c})
  {
    require "$opts{c}";
  }
  else
  {
    require 'DailyUpdate.cfg';
  }

  # Take off the system directory now that configuration is loaded
  shift @INC;
  shift @INC;

  die "\"handlerlocations\" in DailyUpdate.cfg must be non-empty.\n"
    if $#{$config{handlerlocations}} == -1;

  # Put the handler locations on the include search path
  unshift @INC,@{$config{handlerlocations}};

  # Override the config values if the user specified -i or -o
  $config{inputFiles} = ["$opts{i}"] if defined $opts{i};
  $config{outputFiles} = ["$opts{o}"] if defined $opts{o};

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
      kill 9,$scriptpid;
    }
    exit(1);
  }
}

# Make unbuffered for easier debugging.
$| = 1 if (DEBUG);

# Check that the input files and output files match
if ($#{$config{inputFiles}} != $#{$config{outputFiles}})
{
  print "Your input and output files are not correctly specified.\n";
  die "Check your configuration.\n";
}

die "No input and output files\n" if $#{$config{inputFiles}} == -1;

for (my $i=0;$i <= $#{$config{inputFiles}};$i++)
{
  print "<!--DEBUG: Now processing $config{inputFiles}[$i] => $config{outputFiles}[$i]. -->\n" if DEBUG;

  # Store the old STDOUT so we can replace it later.
  open (OLDOUT, ">&STDOUT") unless (DEBUG);

  # Redirect STDOUT to a temp file.
  open (STDOUT,">$config{outputFiles}[$i].temp") unless (DEBUG);

  # Tell the Handler class that there's a new output file.
  require DailyUpdate::Handler;
  &DailyUpdate::Handler::_SetOutputFile($config{outputFiles}[$i]);

  require DailyUpdate::Parser;

  # Okay, now do the magic. Parse the input file, calling the handlers whenever
  # a special tag is seen.

  my $p = new DailyUpdate::Parser;
  $p->parse_file($config{inputFiles}[$i]);

  # Restore STDOUT to the way it was
  if (!DEBUG)
  {
    close (STDOUT);
    open(STDOUT, ">&OLDOUT") or die "Can't restore STDOUT.\n";

    # Replace the output file with the temp file.
    unlink $config{outputFiles};
    rename ("$config{outputFiles}[$i].temp",$config{outputFiles}[$i]);
    chmod 0755, $config{outputFiles};

    # Check to see if we were invoked as a cgi script
    my $scriptname;
    $scriptname = $ENV{'SCRIPT_NAME'} or $scriptname = '';
    if ($scriptname)
    {
      # Now print the results because Daily Update was invoked as some sort of
      # cgi.
      print "Content-type: text/html\n\n";

      open (INFILE, $config{outputFiles}[$i]);
      while (defined(my $line = <INFILE>)) {
        print $line;
      }
      close INFILE;

      # If we're invoked as a CGI script, we just do the first file in the
      # configuration. (I guess...)
      last;
    }
  }
}

exit(0);

#-------------------------------------------------------------------------------

=head1 NAME

Daily Update - downloads and integrates dynamic information into your webpage

=head1 SYNOPSIS

DailyUpdate.pl [B<-anr>] [B<-i> inputfile] [B<-o> outputfile] [B<-c> configfile]

=head1 DESCRIPTION

I<Daily Update> grabs dynamic information from the internet and integrates it
into your webpage. Features include modular extensibility, timeouts to handle
dead servers without hanging the script, user-defined update times, automatic
installation of modules, and compatibility with cgi-wrap. 

Daily Update takes an input HTML file, which includes special tags of the form
<!--dailyupdate name=X-->. I<X> represents a data source, such as "apnews",
"weather", etc. When such a tag is encountered, Daily Update attempts to load
and execute the handler to acquire the data, replacing the tag with the data.
If the handler can not be found, the script asks for permission to attempt to
download it from the central repository at
http://www.cs.virginia.edu/~dwc3q/code/DailyUpdate/handlers.html.

The output contains comment tags with timestamps, which are used by the script
to determine when the data needs to be refreshed. Update times are specified
in the configuration file, which also allows one to specify the input and
output files, and proxy settings.

=head1 HANDLERS

Daily Update has a modular architecture, in which I<handlers> implement the
acquisition and output of data gathered from the internet. To use new data
sources, first locate an interesting one at
http://www.cs.virginia.edu/~dwc3q/code/DailyUpdate/handlers.html, then place
the tag <!--dailyupdate name=NAME--> in your input file. Then run Daily
Update once manually, and it will prompt you for permission to download and
install the handler.

To help handler developers, a utility called I<MakeHandler.pl> is included with
the Daily Update distribution. It is a generator that asks several questions,
and then creates a basic handler.  Handler development is supported by two
APIs, I<AcquisitionFunctions> and I<OutputFunctions>.

AcquisitionFunctions consists of:

=over 2

=item *

GetUrl: Grabs all the content from a URL 

=item *

GetText: Grabs text data from a block of HTML, without formatting 

=item *

GetHtml: Grabs a block of HTML from a URL's content 

=item *

GetImages: Grabs images from a block of HTML 

=item *

GetLinks: Grabs hyperlinks from a block of HTML 

=back


OutputFunctions consists of:

=over 2

=item *

OutputList: takes a reference to an array, a style (ul, ol, free text), and an
integer representing the number of columns.

=item *

OutputUnorderedList: takes a reference to an array. 

=item *

OutputOrderedList: takes a reference to an array. 

=item *

OutputTwoColumns: takes a reference to an array. 

=item *

OutputListOrColumns: Outputs either an unordered list or a two column table,
depending on the value of the "style" attribute to the tag. Takes a reference
to an array. 

=back

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

Custom times at which to update the data for each handler. Handlers typically
update their data at set times, but this can be customized in the
configuration.

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

This script requires the C<LWP::UserAgent> (part of libwww), C<URI>,
C<HTML-Tree>, and C<HTML::Parser> modules, in addition to others that are
included in the standard Perl distribution.  Download them all from CPAN at
http://www.perl.com/CPAN/modules/by-module/.

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
