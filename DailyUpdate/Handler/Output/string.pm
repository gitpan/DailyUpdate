# -*- mode: Perl; -*-

# AUTHOR: David Coppit
# EMAIL: coppit@cs.virginia.edu
# ONE LINE DESCRIPTION: Outputs a string of data
# URL:
# TAG SYNTAX:
# <output name=string>
#   Accepts a string
# LICENSE: GPL
# NOTES:

package DailyUpdate::Handler::Output::string;

use strict;
use DailyUpdate::Handler;
use vars qw( @ISA $VERSION );
@ISA = qw(DailyUpdate::Handler);

# DEBUG for this package is the same as the main.
use constant DEBUG => main::DEBUG;

$VERSION = 0.2;

# ------------------------------------------------------------------------------

sub Output
{
  my $self = shift;
  my $attributes = shift;
  my $grabbedData = shift;

  print "<!--Daily Update message:\n",
        "Unrecognized data type for handler 'string'\n",
        "-->\n" and return
    if ref($grabbedData) ne "SCALAR";

  print $$grabbedData;
}

1;
