# -*- mode: Perl; -*-
package DailyUpdate::Handler;

# This package contains the Handler class, from which all handlers derive. It
# contains a copy of the old output file in a class variable, accessed by
# $self->{'_OLDHTML'}. It also contains the CachedDataUsable member function,
# which is used by handlers to determine if the old data should be refreshed.
# Finally, it has a PrintCachedData function that dumps the old data from the
# last run. (Useful if a connect to a website fails.)

# To use it, subclass it and redefine the Get, Filter, and Output methods. 

use strict;
use Carp;

use vars qw( $VERSION );

$VERSION = 0.1;

my $oldHtml = undef;

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

  # Store a reference to the class data;
  $self->{"_OLDHTML"} = \$oldHtml;

  # Make the object a member of the class
  bless ($self, $class);

  return $self;
}

# ------------------------------------------------------------------------------

# Checks the old html file to see if we need to change the information.  If
# the file doesn't exist, the time tag can't be found, the information is old,
# or the information couldn't be gotten on the last attempt, the function
# returns 1.  Otherwise, it outputs the old information and returns 0.
# Parameters: (Comment string, update times)
sub CachedDataUsable
{
  my ($self) = @_;

  my $tagName = ref($self);
  $tagName =~ s/.*:://;

  # Get the times that the user has specified, or the default times.
  my @updateTimes =
   @{$main::config{updatetimes}->{$tagName} ||
     $main::config{defaultupdatetimes} };

  print "<!--DEBUG: CachedDataUsable: checking $tagName-->\n" if DEBUG;

  # If the user specified "always", there's no need to check the time.
  print "<!--DEBUG:  \"Always\" specified. Skipping cache check.-->\n"
    if (DEBUG && lc($updateTimes[0]) eq 'always');
  return 0 if lc($updateTimes[0]) eq 'always';

  my $currentTime = time;
  my ($hour,$day,$month,$year,$wday) = (localtime($currentTime))[2..6];

  # If there's no old data file, we have to generate the data.
  print "<!--DEBUG:  Old output file doesn't exist.-->\n"
    if (DEBUG && !-e $main::config{outHtml});
  return 0 unless -e $main::config{outHtml};

  if (!defined $self->{"_OLDHTML"})
  {
    open (OLDHTML,$main::config{outHtml}) or die "Can't open output file!\n";
    $self->{"_OLDHTML"} = join "",<OLDHTML>;
    close (OLDHTML);
  }

  # Make a local copy of the old html
  my $oldHtml = $self->{"_OLDHTML"};

  my $lastUpdated;

  # Need to get data if we can't find the embedded timestamp
  if ($oldHtml !~ /<!-- $tagName (\d+) -->/)
  {
    print "<!--DEBUG:  Can't find embedded timestamp for $tagName.-->\n" if DEBUG;
    return 0;
  }
  else
  {
    $lastUpdated = $1;
  }

  # Need to get the data if we were unsuccessful last time
  if ($oldHtml =~ /<!-- $tagName (\d+) -->\nCouldn't get/)
  {
    print "<!--DEBUG:  Data was not grabbed successfully last time.-->\n"
      if DEBUG;
    return 0;
  }

  print "<!--DEBUG:  Last updated:$lastUpdated Current time:$currentTime.-->\n"
    if DEBUG;

  # Need to get the data if the old data is stale
  my $needToUpdate = 0;
  foreach my $updateHour (@updateTimes)
  {
    my $updateTime = timelocal(0,0,$updateHour,$day,$month,$year);
    if (($lastUpdated < $updateTime) && ($updateTime < $currentTime))
    {
      print "<!--DEBUG:  Data is stale for time: $updateTime.-->\n" if DEBUG;
      return 0;
      last;
    }
  }

  # Otherwise, just print out the old data
  print "<!--DEBUG: Re-using current data.-->\n" if DEBUG;
  my ($oldData) =
    $oldHtml =~ /(<!-- $tagName \d+ -->\n.*?<!-- $tagName \d+ -->)/s;
  print "$oldData\n";

  return 1;
}

# ------------------------------------------------------------------------------

sub PrintCachedData
{
  my ($self) = @_;

  my $tagName = ref($self);
  $tagName =~ s/.*:://;

  # Otherwise, just print out the old data
  print "<!--DEBUG: Printing cached data.-->\n" if DEBUG;
  my ($oldData) =
    $oldHtml =~ /(<!-- $tagName \d+ -->\n.*?<!-- $tagName \d+ -->)/s;
  if (defined $oldData)
  {
    print "Reusing cached data.\n";
    print "$oldData\n";
  }
}

# ------------------------------------------------------------------------------

sub Handle
{
  my $self = shift;
  my $attributes = shift;

  my $tagName = ref($self);
  $tagName =~ s/.*:://;

  return if $self->CachedDataUsable();

  my $time = time;
  print "<!-- $tagName $time -->\n";

  print "<!--DEBUG: Handler is acquiring data.-->\n" if DEBUG;

  # Get the data
  my $grabbedData = $self->Get($attributes);

  if (!defined $grabbedData)
  {
    $self->PrintCachedData();
    print "<!-- $tagName $time -->\n";
    return;
  }

  print "<!--DEBUG: Handler is filtering data.-->\n" if DEBUG;

  # Filter the data
  $grabbedData = $self->Filter($attributes,$grabbedData);

  if (!defined $grabbedData)
  {
    # Don't change "Couldn't get". It's used by CachedDataUsable
    print "Couldn't update information (filter removed everything).\n";
    $self->PrintCachedData();
    print "<!-- $tagName $time -->\n";
    return;
  }

  print "<!--DEBUG: Handler is outputting data.-->\n" if DEBUG;

  # Output the data
  $self->Output($attributes,$grabbedData);

  print "<!-- $tagName $time -->\n";
  return;
}

# ------------------------------------------------------------------------------

# This is a pure virtual
sub Get
{
  my $self = shift;
  my $attributes = shift;

  my $type = ref($self);
  croak "$type must override Get.\n";
}

# ------------------------------------------------------------------------------

# This function is used to filter out some of the data acquired using Get.
# Currently it does nothing, but subclasses can override this behavior.
sub Filter
{
  my $self = shift;
  my $attributes = shift;
  my $grabbedData = shift;

  # Return a reference to the data.
  return $grabbedData;
}

# ------------------------------------------------------------------------------

# This is a pure virtual
sub Output
{
  my $self = shift;
  my $attributes = shift;
  my $grabbedData = shift;

  my $type = ref($self);
  croak "$type must override Output.\n";
}

# ------------------------------------------------------------------------------

1;
