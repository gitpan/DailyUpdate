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
                 OutputListOrColumns OutputList );

$VERSION = 0.5;

# DEBUG for this package is the same as the main.
use constant DEBUG => main::DEBUG;

# ------------------------------------------------------------------------------

# Outputs an array of data in one or more columns, in the given style.
# Arg 1: a reference to the array.
# Arg 2: the style -- either ol for numbered list, ul for bulletted list, or
#        an arbitrary HTML string to place in front of each item. (defaults to
#        bulletted list)
# Arg 3: the number of columns (defaults to 1)
# Arguments of the form (@array,'2') assume the 2 refers to the number of
# columns.
sub OutputList
{
  my @data = @{ shift @_ };

  my $style;
  if (($#_ > 0) || (($#_ == 0) && ($_[0] !~ /^\d+$/)))
  {
    $style = shift @_;
  }
  else
  {
    $style = 'ul';
  }

  my $numberColumns;
  if ($#_ != -1)
  {
    $numberColumns = shift @_;
  }
  else
  {
    $numberColumns = 1;
  }

  # Figure out how many items per column. (Divide and find the ceiling.)
  my $itemsPerColumn = int(($#data+1)/$numberColumns);
  $itemsPerColumn++ if ($#data+1)/$numberColumns != $itemsPerColumn;

  my $offset = '';
  $offset = '      ' if $numberColumns > 1;

  # Figure out what to print in before and after the items;
  my $prePrint = '';
  my $postPrint = '';
  $prePrint = '  <li> ' if $style eq 'ul' || $style eq 'ol';
  $prePrint = $style if $style ne 'ul' && $style ne 'ol';
  $postPrint = '<br>' if $style ne 'ul' && $style ne 'ol';

  # Print the table header if necessary
  print "<table width=100%>\n  <tr>\n" if $numberColumns > 1;

  for (my $column=1;$column <= $numberColumns;$column++)
  {
    if ($numberColumns > 1)
    {
      print "    <td width=";
      printf "%.0f",100/$numberColumns;
      print "% valign=top>\n";
    }
    print "$offset<ul>\n" if $style eq 'ul';
    print "$offset<ol>\n" if $style eq 'ol';
    for (my $row=1;$row <= $itemsPerColumn;$row++)
    {
      print $offset,$prePrint,$data[($column-1)*$itemsPerColumn+$row-1],
            $postPrint,"\n";
      last if ($column-1)*$itemsPerColumn+$row-1 == $#data;
    }
    print "$offset</ul>\n" if $style eq 'ul';
    print "$offset</ol>\n" if $style eq 'ol';
    print "    </td>\n" if $numberColumns > 1;
  }

  print "  </tr>\n</table>\n" if $numberColumns > 1;
}

#-------------------------------------------------------------------------------

# Formats the items in the argument array as a numbered list
sub OutputOrderedList
{
  OutputList($_[0],'ol');
}

#-------------------------------------------------------------------------------

# Formats the items in the argument array as two columns
sub OutputTwoColumns
{
  OutputList ($_[0],2);
}

#-------------------------------------------------------------------------------

# Formats the items in the argument array as an unordered list
sub OutputUnorderedList
{
  OutputList($_[0]);
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
}

1;
