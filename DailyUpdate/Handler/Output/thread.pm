# -*- mode: Perl; -*-

# AUTHOR: David Coppit
# EMAIL: coppit@cs.virginia.edu
# ONE LINE DESCRIPTION: Outputs a threaded list of data
# URL:
# TAG SYNTAX:
# <output name=thread style=X>
#   Accepts a thread
#   X=(ol|ul)
# LICENSE: GPL
# NOTES: This function outputs a thread, as you would find in discussion
# groups. The data should be in the form of a list, where the elements are
# references to 2-element arrays containing the data and a reference to
# another such list.  For example:
#
# A
#  - A1
#  - A2
# B
#  - B1
#  - B2
# C
#
# Would look like:
#
# [[A,REF 1],[B,REF 2],[C,undef]]
#
# REF 1:
# [[A1,undef],[A2,undef]]
#
# REF 2:
# [[B1,undef],[B2,undef]]
#
# Or, in real perl:
# [['a',[['a1',undef],['a2',undef]]],['b',[['b1',undef],['b2',undef]]],['c',undef]]

package DailyUpdate::Handler::Output::thread;

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
  my $offset = shift;

  print "<!--Daily Update message:\n",
        "Unrecognized data type for handler 'thread'\n",
        "-->\n" and return
    if ref($grabbedData) ne "ARRAY";

  $offset = '' unless defined $offset;

  my $style = $attributes->{style};
  $style = 'ul' unless defined $style;

  # Figure out what to print in before and after the items;
  my $prePrint = '';

  if ($style =~ /^ul$/i || $style =~ /^ol$/i)
  {
    $prePrint = ' <li> '
  }

  print "$offset<ul>\n" if $style =~ /^ul$/i;
  print "$offset<ol>\n" if $style =~ /^ol$/i;

  for (my $i=0;$i <= $#{$grabbedData};$i++)
  {
    print "$offset$prePrint",$grabbedData->[$i][0],"\n";
    if (defined $grabbedData->[$i][1])
    {
      print "\n";
      $self->Output($attributes,$grabbedData->[$i][1],'  ');
      print "\n";
    }
  }

  print "$offset</ul>\n" if $style =~ /^ul$/i;
  print "$offset</ol>\n" if $style =~ /^ol$/i;
}

1;
