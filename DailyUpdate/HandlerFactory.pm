# -*- mode: Perl; -*-
package DailyUpdate::HandlerFactory;

use strict;
use Carp;
# For UserAgent
use LWP::UserAgent;
# For mkpath
use File::Path;
# For GetUrl
use DailyUpdate::AcquisitionFunctions qw( GetUrl );

use vars qw( $VERSION );

$VERSION = 0.3;

# DEBUG for this package is the same as the main.
use constant DEBUG => main::DEBUG;

# ------------------------------------------------------------------------------

sub new
{
  my $proto = shift;

  # We take the ref if "new" was called on an object, and the class ref
  # otherwise.
  my $class = ref($proto) || $proto;

  # Create an "object"
  my $self = {};

  # Make the object a member of the class
  bless ($self, $class);

  return $self;
}

# ------------------------------------------------------------------------------

sub _GetHandlerCode
{
  my $handlerName = shift;

  my $url = "http://www.cs.virginia.edu/cgi-bin/cgiwrap?user=dwc3q&script=GetHandler&tag=$handlerName";

  print "<!-- DEBUG: Downloading handler code. -->\n" if DEBUG;
  my $data = &GetUrl($url);

  if (!defined $data)
  {
    print STDERR "Couldn't download handler.\n";
    return 'Tag Not found';
  }

  if ($$data =~ /^Tag not found/)
  {
    print STDERR "Server reports that there is no such handler.\n";
  }

  return $$data;
}

# ------------------------------------------------------------------------------

# Replaces handler, if it is in the search path.
sub _DownloadHandler
{
  my $handlerName = shift;

  my $directory;
  $directory = $INC{"DailyUpdate/Handler/$handlerName.pm"} ||
    "$main::config{handlerlocations}[0]/DailyUpdate/Handler";

  mkpath $directory unless -e $directory;
  unlink "$directory/$handlerName.pm" if -e "$directory/handlerName.pm";

  print "<!-- DEBUG: Downloading handler $handlerName -->\n" if DEBUG;

  my $code = &_GetHandlerCode($handlerName);

  return if $code =~ /^Tag not found/;

  open HANDLER,">$directory/$handlerName.pm";
  print HANDLER $code;
  close HANDLER;

  print STDERR "The $handlerName handler has been downloaded and saved as\n";
  print STDERR "$directory/$handlerName.pm\n";

  my @uses = $code =~ /\nuse (.*?);/g;

  @uses = grep {!/(vars|constant|DailyUpdate|strict)/} @uses;

  if ($#uses != -1)
  {
    print STDERR "The handler uses the following modules:\n";
    $" = '\n';
    print STDERR "@uses\n";
    print STDERR "Make sure you have them installed.\n";
  }
}

# ------------------------------------------------------------------------------

# Replaces handler, if it is in the search path.
sub _HandlerOutdated
{
  my $handlerName = shift;
  print "<!-- DEBUG: Checking version of handler $handlerName -->\n" if DEBUG;

  my $code = &_GetHandlerCode($handlerName);
  my ($remoteVersion) = $code =~ /\$VERSION *= *(.*?);/s;

  my $foundDirectory = undef;
  foreach my $directory (@INC)
  {
    if (-e "$directory/DailyUpdate/Handler/$handlerName.pm")
    {
      $foundDirectory = "$directory/DailyUpdate/Handler";
      last;
    }
  }

  unless (defined $foundDirectory)
  {
    print "<!-- DEBUG: Handler $handlerName not found locally. -->\n" if DEBUG;
    return 1;
  }

  print "<!-- DEBUG: Found local copy of handler in: $foundDirectory -->\n"
    if DEBUG;

  open LOCALHANDLER, "$foundDirectory/$handlerName.pm";
  my $localHandler = join '',<LOCALHANDLER>;
  close LOCALHANDLER;
  my ($localVersion) = $localHandler =~ /\$VERSION *= *(.*?);/s;

  if (DEBUG)
  {
    print "<!-- DEBUG: Comparing local version ($localVersion) to";
    print " remote version ($remoteVersion). -->\n";
  }

  if (($localVersion cmp $remoteVersion) == -1)
  {
    # Remote is newer. Need to download handler.
    print "<!-- DEBUG: Remote version is newer. -->\n" if DEBUG;
    return 1;
  }
  else
  {
    # Local is newer. No need to download handler.
    print "<!-- DEBUG: Local version is newer. -->\n" if DEBUG;
    return 0;
  }
}

# ------------------------------------------------------------------------------

# Basically pass everything through except the special tags.
sub Create
{
  my $self = shift;
  my $handlerName = shift;

  croak "You must supply a handler name to HandlerFactory\n"
    if !defined $handlerName;

  $handlerName =~ lc($handlerName);

  # Figure out if we need to download the handler, either because ours is out
  # of date, or because we don't have it installed.
  my $needDownload = 0;
  if (exists $main::opts{n})
  {
    if (&_HandlerOutdated($handlerName))
    {
      print STDERR "\nThere is a newer version of handler '$handlerName',";
      print STDERR " or it is not installed locally.\n";
      $needDownload = 1;
    }
    else
    {
      eval "require DailyUpdate::Handler::$handlerName";
      $needDownload = 0;
    }
  }
  else
  {
    eval "require DailyUpdate::Handler::$handlerName";
    if ($@ =~ /Can't locate DailyUpdate.Handler.$handlerName/)
    {
      print STDERR "\nCan not find handler '$handlerName'\n";
      $needDownload = 1;
    }
    else
    {
      $needDownload = 0;
    }
  }

  if ($needDownload == 1)
  {
    print "<!-- DEBUG: Download of new handler needed. -->\n" if DEBUG;
  
    if (exists $main::opts{a})
    {
      print STDERR "Doing automatic download.\n";
      &_DownloadHandler($handlerName);
    }
    else
    {
      print STDERR "Would you like Daily Update to attempt to download it?\n";
      my $response = <STDIN>;

      if ($response =~ /^y/i)
      {
        &_DownloadHandler($handlerName);
      }
      else
      {
        print STDERR "Okay, then remove the tag from your input file.\n";
        return undef;
      }
    }

    # Clear out the cached require information
    delete $INC{"DailyUpdate/Handler/$handlerName.pm"};

    eval "require DailyUpdate::Handler::$handlerName";
  }

  if ($@ =~ /Can't locate DailyUpdate.Handler.$handlerName/)
  {
    print STDERR "Handler could not be loaded.\n";
    return undef;
  }
  elsif ($@)
  {
    print STDERR $@;
    return undef;
  }
  else
  {
    return "DailyUpdate::Handler::$handlerName"->new;
  }
}

1;
