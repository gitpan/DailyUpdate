# -*- mode: Perl; -*-

# AUTHOR: David Coppit
# EMAIL: coppit@cs.virginia.edu
# ONE LINE DESCRIPTION: Filter to apply another filter to the contents of an
#   array or hash
# URL:
# TAG SYNTAX:
# <filter name=map depth=X filter=Y [...]>
#   Accepts an array or hash of other data structures, and returns the same.
#   X: The number of times to recursively unfold the data structure before
#      applying filter Y. For example, to apply the highlight filter to an
#      array of arrays of strings, this value would be 2. (default is 1)
#   Y: The non-map filter to apply to each of the array members. Any
#      additional arguments are passed on to the Y filter
# LICENSE: GPL
# NOTES:

package DailyUpdate::Handler::Filter::map;

use strict;
use DailyUpdate::Handler;
use DailyUpdate::HandlerFactory;
use vars qw( @ISA $VERSION );
@ISA = qw(DailyUpdate::Handler);

# DEBUG for this package is the same as the main.
use constant DEBUG => main::DEBUG;

$VERSION = 0.2;

sub Filter
{
  # Gotta be careful to make copies here, since recursion and looping causes
  # problems.
  my $self = shift;
  my $attributes = {%{shift @_}};
  my $grabbedData = shift;

  if (!defined $attributes->{filter} ||
      defined $attributes->{depth} && $attributes->{depth} < 0)
  {
    print "<!--Daily Update message:\n",
          "Bad arguments for handler 'map'\n",
          "-->\n" and return undef;
  }

  $attributes->{depth} = 1 unless defined $attributes->{depth};

  if ($attributes->{depth} == 0)
  {
    print "<!--DEBUG: Applying map at this level. -->\n" if DEBUG;

    my $handlerFactory = new DailyUpdate::HandlerFactory;

    # Ask the HandlerFactory to create a handler for us, based on the name.
    my $handler = $handlerFactory->Create($attributes->{filter});

    # Get the attributes ready to pass on to the next filter
    delete $attributes->{filter};
    $grabbedData = $handler->Filter($attributes,$grabbedData);
    return $grabbedData;
  }

  print "<!--DEBUG: Recursively applying map. -->\n" if DEBUG;

  $attributes->{depth}--;

  my $handlerFactory = new DailyUpdate::HandlerFactory;

  # Ask the HandlerFactory to create a handler for us, based on the name.
  my $handler = $handlerFactory->Create('map');

  if (ref($grabbedData) eq 'ARRAY')
  {
    my @temp;
    for (my $i=0;$i <= $#{$grabbedData};$i++)
    {
      if (ref($grabbedData->[$i]))
      {
        my $tempData = $handler->Filter($attributes,$grabbedData->[$i]);
        push @temp,$tempData if defined $tempData;
      }
      else
      {
        my $tempData = $handler->Filter($attributes,\$grabbedData->[$i]);
        push @temp,${$tempData} if defined $tempData;
      }
    }
    $grabbedData = \@temp;
  }
  elsif (ref($grabbedData) eq 'HASH')
  {
    my %temp;
    foreach my $i (keys %$grabbedData)
    {
      $temp{$i} = ${$handler->Filter($attributes,\$grabbedData->{$i})}
        if !ref($grabbedData->{$i});
      $temp{$i} = $handler->Filter($attributes,$grabbedData->{$i})
        if ref($grabbedData->{$i});
    }
    $grabbedData = \%temp;
  }

  return $grabbedData;
}

1;
