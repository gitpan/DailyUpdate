# -*- mode: Perl; -*-
package DailyUpdate::Cache;

use strict;
# For mkpath
use File::Path;
# To parse dates
use Date::Manip;

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

# Removes data from the cache, if there is any
sub _RemoveFromCache
{
  my $url = shift;

  my $newRegistry = '';
  my $found = 0;

  open REGISTRY,"$main::config{cachelocation}/registry.txt" or return;
  while (defined(my $line = <REGISTRY>))
  {
    chomp $line;
    my ($cacheUrl,$filename,$size,$time) = split / /,$line;

    if ($cacheUrl eq $url)
    {
      print "<!--DEBUG: Removing cached data for URL:\n  $url -->\n"
        if DEBUG;

      unlink "$main::config{cachelocation}/$filename";
      $found = 1;
    }
    else
    {
      $newRegistry .= $line."\n";
    }
  }
  close REGISTRY;

  if ($found)
  {
    open REGISTRY,">$main::config{cachelocation}/registry.txt"
      or die "Can't open cache registry file: $!";
    print REGISTRY $newRegistry;
    close REGISTRY;
  }
}

# ------------------------------------------------------------------------------

sub _Outdated
{
  # Get the times that the user has specified, or the default times.
  my @relativeUpdateTimes = @{shift @_};
  my $lastUpdated = shift;

  # Make sure Date::Manip doesn't use colons in the dates
  Date_Init("Internal=1");

  # Change the given times into a list of days and hours
  my $mostRecentUpdateTime = 0;
  foreach my $timeSpec (@relativeUpdateTimes)
  {
    my ($day,$timezone);
    ($day,$timeSpec,$timezone) =
      $timeSpec =~ /^([a-z]*)\D*([\d ,]*)\s*([a-z]*)/i;

    my @hours = split /\D+/,$timeSpec;

    # chop off extra characters on the days, just in case.
    $day =~ s/^(...).*/$1/;

    # If they didn't specify a day, it's today
    $day = 'today'
      if $day eq '' || lc(UnixDate("today","%a")) eq lc($day);

    # If they didn't specify a timezone, it's pacific (in recognition of the
    # multitude of internet companies in California
    $timezone = 'PST' if $timezone eq '';

    $day = "last $day" if $day ne 'today';

    foreach my $hour (@hours)
    {
      my $tempDate = ParseDate("$day at $hour:00");
      $tempDate = Date_ConvTZ($tempDate,$timezone);

      # Correct apparently future times
      if ($tempDate > ParseDate('now'))
      {
        if ($day eq 'today')
        {
          $day = 'yesterday';
        }
        else
        {
          $day = "last $day";
        }
      }

      my $parsedDate = ParseDate("$day at $hour:00");
      $parsedDate = Date_ConvTZ($parsedDate,$timezone);

      $mostRecentUpdateTime = $parsedDate
        if $parsedDate > $mostRecentUpdateTime;
    }
  }

  if ($lastUpdated < UnixDate($mostRecentUpdateTime,'%s'))
  {
    print "<!--DEBUG: Update is needed -->\n" if DEBUG;
    return 1;
  }
  else
  {
    print "<!--DEBUG: Update is not needed -->\n" if DEBUG;
    return 0;
  }
}

# ------------------------------------------------------------------------------

# Checks the cache for the url's data.  If the data exists and isn't old, the
# function returns 1.  Otherwise, it returns 0.
sub _IsStillValid
{
  my $url = shift;
  my @updateTimes = @_;

  print "<!--DEBUG: Checking cache for data for URL:\n  $url -->\n"
    if DEBUG;

  my ($cacheUrl,$filename,$size,$lastUpdated) = (undef,undef,undef,undef);

  open REGISTRY,"$main::config{cachelocation}/registry.txt"
    or print "<!--DEBUG: No registry file found. -->\n" and return 0;
  while (defined(my $line = <REGISTRY>))
  {
    chomp $line;
    ($cacheUrl,$filename,$size,$lastUpdated) = split / /,$line;

    last if $cacheUrl eq $url;
  }
  close REGISTRY;

  # Return 0 if we couldn't find it in the cache.
  print "<!--DEBUG: Couldn't find cached data -->\n"
    if DEBUG && $cacheUrl ne $url;
  return 0 unless $cacheUrl eq $url;


  if (_Outdated(\@updateTimes,$lastUpdated))
  {
    print "<!--DEBUG: Data is stale -->\n" if DEBUG;
    return 0;
  }
  else
  {
    print "<!--DEBUG: Reusing cached data -->\n" if DEBUG;
    return 1;
  }
}

# ------------------------------------------------------------------------------

sub _ReduceCacheSize
{
  my $amountToReduce = shift;

  print "<!--DEBUG: Reducing cache size by $amountToReduce -->\n" if DEBUG;

  my @cacheInfo = ();

  open REGISTRY,"$main::config{cachelocation}/registry.txt" or return;
  while (defined(my $line = <REGISTRY>))
  {
    chomp $line;
    my ($cacheUrl,$filename,$size,$time) = split / /,$line;

    push @cacheInfo,[$cacheUrl,$filename,$size,$time];
  }
  close REGISTRY;

  # Sort by timestamp
  @cacheInfo = sort { $a->[3] <=> $b->[3] } @cacheInfo;

  while (($#cacheInfo > -1) && ($amountToReduce > 0))
  {
    my ($cacheUrl,$filename,$size,$time) = @{shift @cacheInfo};

    $amountToReduce -= $size;
    _RemoveFromCache($cacheUrl);
  }
}

# ------------------------------------------------------------------------------

# Precondition: the data must not be in the cache.
sub _PutInCache
{
  my $url = shift;
  my $data = shift;

  print "<!--DEBUG: Storing data in cache for URL:\n  $url -->\n" if DEBUG;

  # Generate a new filename
  my $filename;
  do
  {
    $filename = sprintf('%d.html',rand()*100000);
  } while -e "$main::config{cachelocation}/$filename";

  mkpath ($main::config{cachelocation})
    unless -e "$main::config{cachelocation}";

  open REGISTRY,">>$main::config{cachelocation}/registry.txt"
    or die "Can't open cache registry file: $!";
  print REGISTRY "$url $filename ",length($data)," ",time,"\n";
  close REGISTRY;

  open CACHEFILE,">$main::config{cachelocation}/$filename"
    or die "Can't write to cache file ($main::config{cachelocation}/$filename): $!";
  print CACHEFILE $data;
  close CACHEFILE;

  return;
}

# ------------------------------------------------------------------------------

sub _GetFromCache
{
  my $url = shift;

  my ($cacheUrl,$filename,$size,$time) = (undef,undef,undef,undef);

  open REGISTRY,"$main::config{cachelocation}/registry.txt" or return undef;
  while (defined(my $line = <REGISTRY>))
  {
    chomp $line;
    ($cacheUrl,$filename,$size,$time) = split / /,$line;

    last if $cacheUrl eq $url;
  }
  close REGISTRY;

  return undef unless $cacheUrl eq $url;

  open CACHEDDATA,"$main::config{cachelocation}/$filename"
    or die "Can't locate file $filename in the cache, even though it's".
           " listed\n  in the registry.\n";
  my $data = join '',<CACHEDDATA>;
  close CACHEDDATA;

  return $data;
}

# ------------------------------------------------------------------------------

sub GetData
{
  my $self = shift;
  my $url = shift;
  my @updateTimes = @_;

  if (_IsStillValid($url,@updateTimes))
  {
    return _GetFromCache($url);
  }
  else
  {
    return undef;
  }
}

# ------------------------------------------------------------------------------

sub CacheData
{
  my $self = shift;
  my $url = shift;
  my $data = shift;

  _RemoveFromCache($url);

  if (-e "$main::config{cachelocation}/registry.txt")
  {
    # Get the current cache size.
    my $cacheSize = 0;

    open REGISTRY,"$main::config{cachelocation}/registry.txt"
      or die "Can't open cache registry file: $!";

    while (defined(my $line = <REGISTRY>))
    {
      chomp $line;
      my ($cacheUrl,$filename,$size,$time) = split / /,$line;

      $cacheSize += $size;
    }
    close REGISTRY;

    # Reduce the cache size if necessary
    _ReduceCacheSize(length $data)
      if $cacheSize + length $data > $main::config{maxcachesize};
  }


  # Cache it!
  _PutInCache($url,$data);
}

1;
