# -*- mode: Perl; -*-
package DailyUpdate::HandlerFactory;

use strict;
use Carp;
# For UserAgent
use LWP::UserAgent;

use vars qw( $VERSION );

$VERSION = 0.1;

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

sub _DownloadHandler
{
  my $handlerName = shift;
  print "<!-- DEBUG: Downloading handler $handlerName -->\n" if DEBUG;

  my $url = "http://www.cs.virginia.edu/cgi-bin/cgiwrap?user=dwc3q&script=GetHandler&tag=$handlerName";

  my $userAgent = new LWP::UserAgent;
  $userAgent->timeout($main::config{socketTimeout});
  $userAgent->proxy(['http', 'ftp'], $main::config{proxy})
    if $main::config{proxy} ne '';
  my $request = new HTTP::Request GET => "$url";
  my $result = $userAgent->request($request);

  if (!$result->is_success)
  {
    print STDERR "Couldn't get handler. Error on HTTP request: ".$result->message.".\n";
    return;
  }

  if ($result->content =~ /^Tag not found/)
  {
    print STDERR "Server reports that there is no such handler.\n";
    return;
  }

  # Now save it somewhere
  mkdir "$main::config{handlerlocations}->[0]/DailyUpdate",0755;
  mkdir "$main::config{handlerlocations}->[0]/DailyUpdate/Handler",0755;
  open HANDLER,">$main::config{handlerlocations}->[0]/DailyUpdate/Handler/$handlerName.pm";
  print HANDLER $result->content;
  close HANDLER;

  print STDERR "The $handlerName handler has been downloaded and saved as\n";
  print STDERR "$main::config{handlerlocations}->[0]/$handlerName.pm\n";

  my @uses = $result->content =~ /\nuse (.*?);/g;

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

# Basically pass everything through except the special tags.
sub Create
{
  my $self = shift;
  my $handlerName = shift;

  croak "You must supply a handler name to HandlerFactory\n"
    if !defined $handlerName;

  $handlerName =~ lc($handlerName);

  eval "require DailyUpdate::Handler::$handlerName";
  
  if ($@ =~ /Can't locate DailyUpdate.Handler.$handlerName/)
  {
    # Clear out the cached require information
    delete $INC{"DailyUpdate/Handler/$handlerName.pm"};

    print STDERR "\n\nCan not find handler '$handlerName'\n";
    print STDERR "Would you like Daily Update to attempt to download it?\n";
    my $response = <STDIN>;
    if ($response =~ /^y/i)
    {
      &_DownloadHandler($handlerName);
      eval "require DailyUpdate::Handler::$handlerName";

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
    else
    {
      print STDERR "Okay, then remove the tag from your input file.\n";
      return undef;
    }
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
