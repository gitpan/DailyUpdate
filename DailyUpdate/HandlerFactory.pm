# -*- mode: Perl; -*-
package DailyUpdate::HandlerFactory;

use strict;
use Carp;
# For UserAgent
use LWP::UserAgent;
# For mkpath
use File::Path;

use vars qw( $VERSION );

$VERSION = 0.4;

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

# Gets the entire content from a URL. file:// supported
sub _DownloadURL
{
  my $url = shift;

  my $userAgent = new LWP::UserAgent;

  $userAgent->timeout($main::config{socketTimeout});
  $userAgent->proxy(['http', 'ftp'], $main::config{proxy})
    if $main::config{proxy} ne '';
  my $request = new HTTP::Request GET => "$url";

  if ($main::config{proxy_username} ne '')
  {
    $request->proxy_authorization_basic($main::config{proxy_username},
                     $main::config{proxy_password});
  }

  my $result = $userAgent->request($request);

  return undef unless $result->is_success;

  my $content = $result->content;

  # Strip linefeeds off the lines
  $content =~ s/\r//gs;

  return \$content;
}

# ------------------------------------------------------------------------------

sub _LoadHandler
{
  my $handlerName = shift;

  my @dirs = qw(Acquisition Filter Output);

  foreach my $dir (@dirs)
  {
    # Try to load it in $dir
    print "<!--DEBUG: Looking for handler as",
          " DailyUpdate::Handler::$dir\::$handlerName -->\n"
      if DEBUG;
    eval "require DailyUpdate::Handler::$dir\::$handlerName";

    if (DEBUG and !$@)
    {
      print "<!--DEBUG: Found handler in: -->\n";
      print "<!--DEBUG: ",
            $INC{"DailyUpdate/Handler/$dir/$handlerName.pm"}," -->\n";
    }

    # No error message means we found it
    return "Found as DailyUpdate::Handler::$dir\::$handlerName"
      if !$@;

    # We'll skip can't locate messages, but stop on everything else
    if ($@ !~ /^Can't locate DailyUpdate.Handler.$dir.$handlerName/)
    {
      warn "Handler $handlerName was found in:\n";
      warn "  ",$INC{"DailyUpdate/Handler/$dir/$handlerName.pm"},"\n";
      die "  but could not be loaded because of the following error:\n\n$@";
    }
  }

  # Darn. Couldn't find it anywhere!
  print "<!--DEBUG: Couldn't find handler -->\n" if DEBUG;
  return "Not found";
}

# ------------------------------------------------------------------------------

sub _GetHandlerCode
{
  my $handlerName = shift;

  my $url = "http://www.cs.virginia.edu/cgi-bin/cgiwrap?user=dwc3q&script=database&action=%22Get%20Handler%22&tag=$handlerName";

  print "<!--DEBUG: Downloading code for handler \"$handlerName\". -->\n"
    if DEBUG;
  my $data = _DownloadURL($url);

  if (!defined $data)
  {
    warn "Couldn't download handler \"$handlerName\" maybe the server is down.\n";
    return 'Download failed';
  }

  if ($$data =~ /^Handler not found/)
  {
    warn "Server reports that handler \"$handlerName\" doesn't exist.\n";
  }

  return $$data;
}

# ------------------------------------------------------------------------------

# Precondition: you have to load the handler if it's already on the system, so
# that this routine will know where to put the replacement.
sub _DownloadHandler
{
  my $handlerName = shift;

  # See if it already exists on our system by checking where we already loaded
  # it from.
  my $foundDirectory =
    $INC{"DailyUpdate/Handler/Acquisition/$handlerName.pm"} ||
    $INC{"DailyUpdate/Handler/Filter/$handlerName.pm"} ||
    $INC{"DailyUpdate/Handler/Output/$handlerName.pm"} || undef;

  # Remove the outdated one.
  unlink "$foundDirectory/$handlerName.pm" if defined $foundDirectory;

  print "<!--DEBUG: Downloading handler $handlerName -->\n" if DEBUG;

  my $code = _GetHandlerCode($handlerName);

  return if $code =~ /^(Handler not found|Download failed)/;

  # Use the old directory, or create a new one based on what the handler calls
  # itself.
  my $destDirectory;
  if (defined $foundDirectory)
  {
    print "<!--DEBUG: Replacing handler located in $foundDirectory -->\n"
      if DEBUG;
    $destDirectory = $foundDirectory;
  }
  else
  {
    my ($subDir) = $code =~ /package DailyUpdate::Handler::([^:]*)::/;
    $destDirectory =
      "$main::config{handlerlocations}[0]/DailyUpdate/Handler/$subDir";
    mkpath $destDirectory unless -e $destDirectory;
  }

  # Write the handler.
  open HANDLER,">$destDirectory/$handlerName.pm";
  print HANDLER $code;
  close HANDLER;

  warn "The $handlerName handler has been downloaded and saved as\n";
  warn "  $destDirectory/$handlerName.pm\n";

  # Figure out if the handler needs any other modules.
  my @uses = $code =~ /\nuse (.*?);/g;

  @uses = grep {!/(vars|constant|DailyUpdate|strict)/} @uses;

  if ($#uses != -1)
  {
    warn "The handler uses the following modules:\n";
    $" = "\n  ";
    warn "  @uses\n";
    warn "Make sure you have them installed.\n";
  }
}

# ------------------------------------------------------------------------------

# Precondition: you have to load the handler if it's already on the system, so
# that this routine will know where to put the replacement.
sub _HandlerOutdated
{
  my $handlerName = shift;

  print "<!--DEBUG: Checking version of handler $handlerName -->\n" if DEBUG;

  # See if it already exists on our system by checking where we already loaded
  # it from.
  my $foundDirectory =
    $INC{"DailyUpdate/Handler/Acquisition/$handlerName.pm"} ||
    $INC{"DailyUpdate/Handler/Filter/$handlerName.pm"} ||
    $INC{"DailyUpdate/Handler/Output/$handlerName.pm"} || undef;

  unless (defined $foundDirectory)
  {
    print "<!--DEBUG: Handler $handlerName not found locally. -->\n" if DEBUG;
    return 1;
  }

  my $code = _GetHandlerCode($handlerName);
  my ($remoteVersion) = $code =~ /\$VERSION *= *(.*?);/s;

  print "<!--DEBUG: Found local copy of handler in: $foundDirectory -->\n"
    if DEBUG;

  open LOCALHANDLER, "$foundDirectory/$handlerName.pm";
  my $localHandler = join '',<LOCALHANDLER>;
  close LOCALHANDLER;
  my ($localVersion) = $localHandler =~ /\$VERSION *= *(.*?);/s;

  if (DEBUG)
  {
    print "<!--DEBUG: Comparing local version ($localVersion) to";
    print " remote version ($remoteVersion). -->\n";
  }

  if (($localVersion cmp $remoteVersion) == -1)
  {
    # Remote is newer. Need to download handler.
    print "<!--DEBUG: Remote version is newer. -->\n" if DEBUG;
    return 1;
  }
  else
  {
    # Local is newer. No need to download handler.
    print "<!--DEBUG: Local version is newer. -->\n" if DEBUG;
    return 0;
  }
}

# ------------------------------------------------------------------------------

sub Create
{
  my $self = shift;
  my $handlerName = shift;

  croak "You must supply a handler name to HandlerFactory\n"
    unless defined $handlerName;

  $handlerName = lc($handlerName);

  # Try to load the handler
  my $loadResult = _LoadHandler($handlerName);

  # Figure out if we need to download the handler, either because ours is out
  # of date, or because we don't have it installed.
  if ($loadResult =~ /^Found/)
  {
    # Do a version check if the user wants it.
    if (exists $main::opts{n} and _HandlerOutdated($handlerName))
    {
      warn "There is a newer version of handler '$handlerName'.\n",
    }
    # Otherwise, we're done!
    else
    {
      my ($fullHandler) = $loadResult =~ /Found as (.*)/;
      return "$fullHandler"->new
    }
  }
  elsif ($loadResult eq 'Not found')
  {
    warn "Can not find handler '$handlerName'\n";
  }

  my $downloadedHandler = 0;

  # If we've made it this far, we must need to do a download.
  print "<!--DEBUG: Download of new handler needed. -->\n" if DEBUG;

  if (exists $main::opts{a})
  {
    warn "Doing automatic download.\n";
    _DownloadHandler($handlerName);
  }
  else
  {
    warn "Would you like Daily Update to attempt to download it?\n";
    my $response = <STDIN>;

    if ($response =~ /^y/i)
    {
      _DownloadHandler($handlerName);
    }
    # If they don't want a download, but we have a local version, use it.
    elsif ($loadResult =~ /^Found/)
    {
      my ($fullHandler) = $loadResult =~ /Found as (.*)/;
      return "$fullHandler"->new
    }
  }

  # If we made it this far, we have just downloaded a new handler.

  # Delete any cached information from a previous load.
  if ($loadResult =~ /^Found/)
  {
    # Clear out the cached require information
    delete $INC{"DailyUpdate/Handler/Acquisition/$handlerName.pm"};
    delete $INC{"DailyUpdate/Handler/Filter/$handlerName.pm"};
    delete $INC{"DailyUpdate/Handler/Output/$handlerName.pm"};
  }

  # Reload the handler
  $loadResult = _LoadHandler($handlerName);

  if ($loadResult =~ /^Found/)
  {
    my ($fullHandler) = $loadResult =~ /Found as (.*)/;
    return "$fullHandler"->new
  }

  # If we got this far, we must not have been able to load the handler.
  return undef;
}

1;
