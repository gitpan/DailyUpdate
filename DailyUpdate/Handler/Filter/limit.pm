# -*- mode: Perl; -*-

# AUTHOR: David Coppit
# EMAIL: coppit@cs.virginia.edu
# ONE LINE DESCRIPTION: Filter to limit the input
# URL:
# TAG SYNTAX:
# <filter name=limit number=X chars>
#   Accepts a string, array, or hash, and returns the same.
#   X: number of lines, if the input is a scalar; number of elements, if the
#      input is an array or hash. (In the case of a hash, random values are
#      deleted.)
#   Y: If the filter is given a string, and chars is specified, the filter
#      removes newlines, keeps the first Y characters, and replaces the rest
#      with ellipses.
# LICENSE: GPL
# NOTES:

package DailyUpdate::Handler::Filter::limit;

use strict;
use DailyUpdate::Handler;
use DailyUpdate::HTMLTools qw( HTMLsubstr );
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
        "Bad arguments for handler 'limit'\n",
        "-->\n" and return undef
    if !defined $attributes->{number} || $attributes->{number} < 0;

  if ((ref $grabbedData eq "SCALAR") && (defined $attributes->{chars}))
  {
    # If it looks like HTML
    if ($$grabbedData =~ m#<[^>]*>.*</[^>]*>#s)
    {
      $$grabbedData = HTMLsubstr($$grabbedData,0,$attributes->{number}).'...';
    }
    else
    {
      $$grabbedData =~ tr/\n//;
      $$grabbedData = substr($$grabbedData,0,$attributes->{number});
      $$grabbedData .= '...';
    }
  }
  elsif ((ref $grabbedData eq "SCALAR") &&
        ($$grabbedData =~ tr/\n/\n/) > $attributes->{number} - 1)
  {
    $$grabbedData =~ s/^(([^\n]*\n){3}).*/$1/s;
  }
  elsif ((ref $grabbedData eq "ARRAY") &&
         ($#{$grabbedData} > $attributes->{number} - 1))
  {
    $#{$grabbedData} = $attributes->{number} - 1;
  }
  elsif ((ref $grabbedData eq "HASH") &&
         ($#{[keys %$grabbedData]} > $attributes->{number} - 1))
  {
    delete $grabbedData->{${[keys %$grabbedData]}[0]}
      while $#{[keys %$grabbedData]} > $attributes->{number} - 1;
  }

  return $grabbedData
}

1;
