# -*- mode: Perl; -*-

# AUTHOR: David Coppit
# EMAIL: coppit@cs.virginia.edu
# ONE LINE DESCRIPTION: Filter to convert a hash to an array
# URL:
# TAG SYNTAX:
# <filter name=hash2array order=X>
#   Accepts a hash and returns an array
#   X: An order for the keys, like "a,b,c". The order is undefined if this
#      value is not specified.
# LICENSE: GPL
# NOTES:

package DailyUpdate::Handler::Filter::hash2array;

use strict;
use DailyUpdate::Handler;
use vars qw( @ISA $VERSION );
@ISA = qw(DailyUpdate::Handler);

# DEBUG for this package is the same as the main.
use constant DEBUG => main::DEBUG;

$VERSION = 0.2;

sub Filter
{
  my $self = shift;
  my $attributes = shift;
  my $grabbedData = shift;

  print "<!--Daily Update message:\n",
        "Unrecognized data type for handler 'hash2array'\n",
        "-->\n" and return undef
    if ref($grabbedData) ne "HASH";

  # Make a local copy to play with
  my %hash = %{$grabbedData};

  my @order = ();
  @order = split /\s*,\s*/, $attributes->{order}
    if defined $attributes->{order};

  my @data= ();

  foreach my $key (@order)
  {
    if (exists $hash{$key})
    {
      push @data,$hash{$key};
      delete $hash{$key};
    }
  }

  foreach my $key (keys %hash)
  {
    push @data,$hash{$key};
  }

  return \@data;
}

1;
