# -*- mode: Perl; -*-

# AUTHOR: David Coppit
# EMAIL: coppit@cs.virginia.edu
# ONE LINE DESCRIPTION: Outputs a table
# URL:
# TAG SYNTAX:
# <output name=table header=X border=Y>
#   Accepts a two-dimensional array
#   X="top","left", or "top,left": makes the specified row or column a header
#   Y: size of table border (defaults to 1)
# LICENSE: GPL
# NOTES:

package DailyUpdate::Handler::Output::table;

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
        "Unrecognized data type for handler 'table'\n",
        "-->\n" and return
    if ref($grabbedData) ne "ARRAY" || ref($grabbedData->[0]) ne "ARRAY";

  $attributes->{border} = 1 unless defined $attributes->{border};

  # $maxWidth is zero-based
  my $maxWidth = 0;
  foreach my $row (@$grabbedData)
  {
    $maxWidth = $#{$row} if $#{$row} > $maxWidth;
  }

  print "<table border=\"$attributes->{border}\">\n";
  foreach my $row (@$grabbedData)
  {
    print "<tr>\n";
    for (my $column=0;$column <= $maxWidth;$column++)
    {
      # Pad the table with blank cells if there is not enough data in the row
      print "<td>&nbsp;</td>\n" and next if $column > $#{$row};

      # Print &nbsp; instead of whitespace
      print "<td>&nbsp;</td>\n" and next if $row->[$column] =~ /^\s*$/s;

      # Print a <th> instead of <td> if needed
      print "<th>$row->[$column] </th>\n" and next
        if (($attributes->{header} =~ /top/i) && ($row == $grabbedData->[0])) ||
           (($attributes->{header} =~ /left/i) && ($column == 0));

      print "<td>$row->[$column]</td>\n";
    }
    print "</tr>\n";
  }
  print "</table>\n";
}

1;
