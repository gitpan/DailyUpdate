# -*- mode: Perl; -*-

# AUTHOR: David Coppit
# EMAIL: coppit@cs.virginia.edu
# ONE LINE DESCRIPTION: Filter to highlight selected words
# URL:
# TAG SYNTAX:
# <filter name=highlight style=X words=Y>
#   Accepts a string and returns a string
#   X: Style to use, like ul, ol, strong, or em (default is strong)
#   Y: (mandatory) A comma separated list of words to match without regard to
#      case. (Actually these can be patterns that match on word boundaries)
# LICENSE: GPL
# NOTES:

package DailyUpdate::Handler::Filter::highlight;

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
        "Bad arguments for handler 'highlight'\n",
        "-->\n" and return undef
    unless defined $attributes->{words} && ref($grabbedData) eq 'SCALAR';

  $attributes->{style} = 'strong' unless defined $attributes->{style};

  my $pattern = join '|',split /\s*,\s*/,$attributes->{words};

  $$grabbedData =~ s/\b($pattern)\b/<$attributes->{style}>$1<\/$attributes->{style}>/ig;

  return $grabbedData
}

1;
