# -*- mode: Perl; -*-

# AUTHOR: David Coppit
# EMAIL: coppit@cs.virginia.edu
# ONE LINE DESCRIPTION: Filter to extract data that matches the given keywords
# URL:
# TAG SYNTAX:
# <filter name=grep words=X invert>
#   Accepts a string, array, or hash, and returns the same.
#   X: The keywords, like "a,b,c". (These can be regular expressions, and are
#     always case insensitive.)
#   invert: Return data that *does not* contain the keywords
#   Data is split into chunks according to the data type: lines for scalar,
#     elements for array, hash values for hashes.
# LICENSE: GPL
# NOTES:

package DailyUpdate::Handler::Filter::grep;

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

  if (defined $attributes->{words})
  {
    # Create an array of the words for easy lookup
    my @words = split /\s*,\s*/,$attributes->{words};

    if (ref $grabbedData eq "SCALAR")
    {
      my $returnVal = '';
      foreach my $sentence (split /\n/,$$grabbedData)
      {
        my $match = (((grep {$sentence =~ /$_/i} @words) &&
                      (!defined $attributes->{invert})) ||
                     ((!grep {$sentence =~ /$_/i} @words) &&
                      (defined $attributes->{invert})));

        $returnVal .= "\n" if $returnVal ne '';
        $returnVal = $sentence if $match;
      }
      return \$returnVal;
    }
    elsif (ref $grabbedData eq "ARRAY")
    {
      my @returnVal = ();
      foreach my $data (@$grabbedData)
      {
        my $match = (((grep {$data =~ /$_/i} @words) &&
                      (!defined $attributes->{invert})) ||
                     ((!grep {$data =~ /$_/i} @words) &&
                      (defined $attributes->{invert})));

        push @returnVal,$data if $match;
      }
      return \@returnVal;
    }
    elsif (ref $grabbedData eq "HASH")
    {
      my %returnVal = ();
      foreach my $key (keys %$grabbedData)
      {
        my $match = (((grep {$grabbedData->{$key} =~ /$_/i} @words) &&
                      (!defined $attributes->{invert})) ||
                     ((!grep {$grabbedData->{$key} =~ /$_/i} @words) &&
                      (defined $attributes->{invert})));

        $returnVal{$key} = $grabbedData->{$key} if $match;
      }
      return \%returnVal;
    }
    else
    {
      print "<!--Daily Update message:\n",
            "Unrecognized data type for handler 'grep'\n",
            "-->\n";
    }
  }

  return $grabbedData
}

1;
