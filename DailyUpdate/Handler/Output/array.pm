# -*- mode: Perl; -*-

# AUTHOR: David Coppit
# EMAIL: coppit@cs.virginia.edu
# ONE LINE DESCRIPTION: Outputs an array of data. Supports columns
# URL:
# TAG SYNTAX:
# <output name=array numcols=W prefix=X suffix=Y separator=Z>
#   Accepts an array.
#   W: numcols of columns. Defaults to 2.
#   X: ul for unordered list, ol for ordered list, or any string to place
#     before the items. Defaults to ul.
#   Y: a string to place at the end of each item. Defaults to nothing for
#     ol and ul prefixes, and "<br>" for strings.
#   Z: a separator to print between items. Defaults to nothing. (Useful when
#     printing out a single column)
# LICENSE: GPL
# NOTES:

package DailyUpdate::Handler::Output::array;

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

  my @data;
  if (ref($grabbedData) eq "ARRAY")
  {
    @data = @$grabbedData;
  }
  elsif (ref($grabbedData) eq "SCALAR")
  {
    @data = split "\n",$$grabbedData;
  }
  elsif (ref($grabbedData) eq "HASH")
  {
    @data = grep { $grabbedData->{$_} } keys %$grabbedData;
  }
  else
  {
    print "<!--Daily Update message:\n",
          "Unrecognized data type for handler 'array'\n",
          "-->\n";
    return;
  }

  my $style = 'ul';
  my $numberColumns = 2;
  my $separator = '';

  $style = $attributes->{prefix} if defined $attributes->{prefix};
  $numberColumns = $attributes->{numcols} if defined $attributes->{numcols};
  $separator = $attributes->{separator} if defined $attributes->{separator};

  # Figure out what to print in before and after the items;
  my $prePrint = '';
  $prePrint = '  <li> ' if $style eq 'ul' || $style eq 'ol';
  $prePrint = $attributes->{prefix} if defined $attributes->{prefix};

  my $postPrint = '';
  $postPrint = '<br>' if $style ne 'ul' && $style ne 'ol';
  $postPrint = $attributes->{suffix} if defined $attributes->{suffix};

  # Figure out how many items per column. (Divide and find the ceiling.)
  my $itemsPerColumn = int(($#data+1)/$numberColumns);
  $itemsPerColumn++ if ($#data+1)/$numberColumns != $itemsPerColumn;

  my $offset = '';
  $offset = '      ' if $numberColumns > 1;

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

    my $firstItem = 1;

    for (my $row=1;$row <= $itemsPerColumn;$row++)
    {
      print $separator if !$firstItem;
      $firstItem = 0 if $firstItem == 1;

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

1;
