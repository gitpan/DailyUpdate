# -*- mode: Perl; -*-
package DailyUpdate::OutputFunctions;

# This package encapsulates several useful functions for formatting data as
# HTML.

require 5.004;

use strict;
# For exporting of functions
use Exporter;

use vars qw( @ISA @EXPORT_OK $VERSION );
@ISA = qw ( Exporter );
@EXPORT_OK = qw( OutputUnorderedList OutputOrderedList OutputTwoColumns
                 OutputListOrColumns );

$VERSION = 0.2;

# DEBUG for this package is the same as the main.
use constant DEBUG => main::DEBUG;

# ------------------------------------------------------------------------------

# Formats the items in the argument array as an unordered list
sub OutputUnorderedList
{
  my @data = @{ shift @_ };

  print "<ul>\n";
  while (my $item = shift @data)
  {
    print "  <li> $item\n";
  }
  print "</ul>\n";
}

#-------------------------------------------------------------------------------

# Formats the items in the argument array as a numbered list
sub OutputOrderedList
{
  my @data = @{ shift @_ };

  print "<ol>\n";
  while (my $item = shift @data)
  {
    print "  <li> $item\n";
  }
  print "</ol>\n";
}

#-------------------------------------------------------------------------------

# Formats the items in the argument array as two columns
sub OutputTwoColumns
{
  my @items = @{ shift @_ };

  print "<table width=100%>\n";

  my $secondColumn = $#items;

  print ("<tr>\n  <td width=50% valign=top>\n  <ul>\n");

  for (my $index=0;$index < int($#items/2)+1;$index++)
  {
    print ("    <li> $items[$index]<br>\n");
  }

  print "  </ul>\n  </td>\n  <td valign=top>\n  <ul>";

  for (my $index=int($#items/2)+1;$index <= $#items;$index++)
  {
    print ("    <li> $items[$index]<br>\n");
  }

  print ("  </ul>\n  </td>\n</tr>\n");
  print "</table>\n";
}

#-------------------------------------------------------------------------------

# Prints the data as an unordered list or two equal length columns, depending
# on $attributes->{style}
sub OutputListOrColumns
{
  my $attributes = shift;
  my @data = @{ shift @_ };

  # Unordered list is the default
  if ((!defined $attributes->{style})
      || ($attributes->{style} =~ /^unorderedlist$/i))
  {
    &OutputUnorderedList(\@data);
  }
  elsif ($attributes->{style} =~ /^twocolumn$/i)
  {
    &OutputTwoColumns(\@data);
  }
  else
  {
    print "Warning: Unknown style.\n";
  }
}

1;
