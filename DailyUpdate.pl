#!/usr/bin/perl
# use perl                                  -*- mode: Perl; -*-
eval 'exec perl -S $0 "$@"'
  if $running_under_some_shell;

use vars qw($running_under_some_shell);         # no whining!

# Daily Update, Version 5.0.1

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

# This code uses LWP::UserAgent from the libwww library, URI, and
# HTML::Parser, all of which are available on CPAN at
# %CPAN%/modules/by-module/LWP/. (Go to http://www.perl.com/ if you don't know
# how to get to CPAN.)

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

# 5.0 This version is based on DailyUpdate 4.5. The reasons for the name
#     change are:
#     - the script was growing in its range of uses
#     - I made the architecture object-oriented. (As Fred Brooks says, plan
#       to build it twice, because you will end up doing it anyway.)
#     Daily Update now sports a nifty plugin architecture for handlers that
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
$VERSION = '5.0.1';

# ------------------------------------------------------------------------------

sub usage
{
<<EOF;
usage: DailyUpdate.pl [-i inputfile] [-o outputfile] [-c configfile]

-i The template file to use as input (overrides value in configuration file)
-o The output file (overrides value in configuration file)
-c The configuration file to use
EOF
}

# ------------------------------------------------------------------------------

use vars qw( *OLDOUT %config );

BEGIN
{
  if (DEBUG)
  {
    print "<!--DEBUG: Command line was:-->\n";
    print "<!--DEBUG:   $0 @ARGV-->\n";
  }

  # See if the user specified the input and output files on the command line.
  my %opts;
  getopt('ioc',\%opts);

  print usage and exit if $opts{h};

  if (defined $opts{c})
  {
    require "$opts{c}";
  }
  else
  {
    require 'DailyUpdate.cfg';
  }

  # Put the directory of the script on the include search path;
  unshift (@{$config{handlerlocations}},$FindBin::Bin);

  unshift @INC,@{$config{handlerlocations}};

  # Override outHtml in the config file if we're in debug mode
  $config{outHtml} = '' if (DEBUG);

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
