# -*- mode: Perl; -*-

# AUTHOR: David Coppit
# EMAIL: coppit@cs.virginia.edu
# ONE LINE DESCRIPTION: Filter to select one or more elements from a hash or
#   an array of hashes
# URL:
# TAG SYNTAX:
# <filter name=selectkeys keys=X invert>
#   Accepts a hash and returns a hash.
#   X: The desired keys, like "a,b,c". The result of this filter is a
#      (trimmed) hash, unless only one key was specified, in which case that
#      key's value is returned.
#   invert: Return the data that *does not* match the given keys.
# LICENSE: GPL
# NOTES:


package DailyUpdate::Handler::Filter::selectkeys;

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
        "Unrecognized data type for handler 'selectkeys'\n",
        "-->\n" and return undef
    if ref($grabbedData) ne "HASH";

  # Make a local copy to play with
  my %hash = %{$grabbedData};

  # Create a hash of the desired keys for easy lookup
  my %keys;
  @keys{split /\s*,\s*/, $attributes->{'keys'}} = ();

  # Delete anything that doesn't belong.
  foreach my $key (keys %hash)
  {
    delete $hash{$key}
      if (((!exists $attributes->{invert}) && (!exists $keys{$key})) ||
          ((exists $attributes->{invert}) && (exists $keys{$key})));
  }

  if ($#{[keys %hash]} == 0)
  {
    my @tempkey = keys %hash;
    my $returnVal = $hash{$tempkey[0]};

    return \$returnVal;
  }
  elsif ($#{[keys %hash]} > 0)
  {
    return \%hash;
  }
  else
  {
    return undef;
  }
}

1;
