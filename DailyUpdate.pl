#!/usr/bin/perl
# use perl                                  -*- mode: Perl; -*-
eval 'exec perl -S $0 "$@"'
  if $running_under_some_shell;

use vars qw($running_under_some_shell);         # no whining!

# Daily Update, Version 5.1

# Daily Update grabs dynamic information from the internet and integrates it
# into your webpage. Features:
# - Timeouts to handle dead servers without hanging the script (Script timer
#   doesn't work on Windows platforms since they don't have fork().)
# - User-defined update times to prevent hammering of sites
# - Plugin architecture for handlers allows easy extension (I've gone OO)
# - Compatible with cgi-wrap (if you want to call it on-the-fly)
# - Automatic download of missing handlers from the Daily Update homepage

# For documentation, go to
#   http://www.cs.virginia.edu/~dwc3q/code/DailyUpdate/index.html.
# For documentation on how to write handlers, go to
#   http://www.cs.virginia.edu/~dwc3q/code/DailyUpdate/handlers.html

# This code uses the libwww library (LWP), URI, HTML-Tree, and HTML::Parser,
# all of which are available on CPAN at
# http://www.perl.com/CPAN/modules/by-module/.

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

# Need to use this to get the current directory so DailyUpdate.cfg will be
# found when run as a cron job.
use Getopt::Std;
# Used to get the directory of the script, so we can find the configuration
# file.
use FindBin;

use vars qw( $VERSION );
$VERSION = '5.1';

# ------------------------------------------------------------------------------

sub usage
{
<<EOF;
usage: DailyUpdate.pl [-an] [-i inputfile] [-o outputfile] [-c configfile]

-i The template file to use as input (overrides value in configuration file)
-o The output file (overrides value in configuration file)
-c The configuration file to use
-a Automatically download handlers as needed
-n Check for new versions of the handlers
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

  # See if the user specified the input and output files on the command line.
  getopt('ioc',\%opts);

  print usage and exit if $opts{h};

  # Make sure the directory of the script is on INC
  unshift @INC,$FindBin::Bin;

  if (defined $opts{c})
  {
    require "$opts{c}";
  }
  else
  {
    require 'DailyUpdate.cfg';
  }

  # Take off script directory, because we want to put the handlerlocations
  # after it.
  shift @INC;

  # Put the directory of the script on the include search path
  unshift (@{$config{handlerlocations}},$FindBin::Bin);

  unshift @INC,@{$config{handlerlocations}};

  # Override both the config and the debug values if the user specified inHtml
  # or outHtml
  $config{inHtml} = $opts{i} if defined $opts{i};
  $config{outHtml} = $opts{o} if defined $opts{o};

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
if ((!DEBUG) && ($^O ne 'MSWin32'))
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
    exit (1);
  }
}

# Make unbuffered for easier debugging.
$| = 1 if (DEBUG);

# Store the old STDOUT so we can replace it later.
open (OLDOUT, ">&STDOUT") unless (DEBUG);

# Redirect STDOUT to a temp file.
open (STDOUT,">$config{outHtml}.temp") unless (DEBUG);

require DailyUpdate::Parser;

# Okay, now do the magic. Parse the input file, calling the handlers whenever
# a special tag is seen.
my $p = new DailyUpdate::Parser;
$p->parse_file($config{inHtml});

# Restore STDOUT to the way it was
if (!DEBUG)
{
  close (STDOUT);
  open(STDOUT, ">&OLDOUT") or die "Can't restore STDOUT.\n";

  # Replace the output file with the temp file.
  unlink $config{outHtml};
  rename ("$config{outHtml}.temp",$config{outHtml});
  chmod 0755, $config{outHtml};

  # Check to see if we were invoked as a cgi script
  my $scriptname;
  $scriptname = $ENV{'SCRIPT_NAME'} or $scriptname = '';
  if ($scriptname)
  {
    # Now print the results because Daily Update was invoked as some sort of
    # cgi.
    print "Content-type: text/html\n\n";

    open (INFILE, $config{outHtml});
    while (defined(my $line = <INFILE>)) {
      print $line;
    }
    close INFILE;
  }
}

#-------------------------------------------------------------------------------

=head1 NAME

Daily Update - downloads and integrates dynamic information into your webpage

=head1 SYNOPSIS

DailyUpdate.pl [-i inputfile] [-o outputfile] [-c configfile]

=head1 DESCRIPTION

I<Daily Update> grabs dynamic information from the internet and integrates it
into your webpage. Features include modular extensibility, timeouts to handle
dead servers without hanging the script, user-defined update times, automatic
installation of modules, and compatibility with cgi-wrap. 

Daily Update takes an input HTML file, which includes special tags of the
form \<dailyupdate name=X\>. I<X> represents a data source, such as "apnews",
"weather", etc. When such a tag is encountered, Daily Update attempts to
load and execute the handler to acquire the data, replacing the tag with the
data. If the handler can not be found, the script asks for permission to
attempt to download it from the central repository at
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
the tag \<dailyupdate name=NAME\> in your input file. Then run Daily Update
once manually, and it will prompt you for permission to download and install
the handler.

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

=back

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
http://www.cs.virginia.edu/~dwc3q/index.thml

=begin CPAN

=pod COREQUISITES

none

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

HTML/Preprocessors

=end CPAN

=cut
