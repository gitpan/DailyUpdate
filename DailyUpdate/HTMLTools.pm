# -*- mode: Perl; -*-
package DailyUpdate::HTMLTools;

# This package contains a set of useful functions for manipulating HTML.

use strict;
# Used to make relative URLs absolute
use URI;
# For exporting of functions
use Exporter;

use vars qw( @ISA @EXPORT $VERSION );

@ISA = qw( Exporter );
@EXPORT = qw( ExtractText MakeLinksAbsolute StripTags );

$VERSION = 0.2;

# DEBUG for this package is the same as the main.
use constant DEBUG => main::DEBUG;

# ------------------------------------------------------------------------------

# Takes a bunch of html in the first argument (as one long string). Uses the
# remaining arguments to strip out tags. By default, these are taken to be
# strong,h1,h2,h3,h4,h5,h6,b,i,u,tt,font,big,small,strike,
# which (hopefully) strips out the formatting.
sub StripTags
{
  my $html = shift @_;

  my @tags;
  if ($#_ == -1)
  {
    @tags = qw(strong h1 h2 h3 h4 h5 h6 b i u tt font big small strike);
  }
  else
  {
    @tags = @_;
  }

  my $temp = $";
  $" = '|';
  my $pattern = "@tags";
  $" = $temp;

  $html =~ s#<\s*/?\b($pattern)\b[^>]*>##sig;

  return $html;
}

# ------------------------------------------------------------------------------

# Extracts all text between the starting and ending patterns. '^' and '$' can
# be used for the starting and ending patterns to signify start of text and
# end of text.
sub ExtractText
{
  my $html = shift;
  my $startPattern = shift;
  my $endPattern = shift;

  if (($startPattern ne '^') && ($endPattern ne '$'))
  {
    $html =~ s/.*?$startPattern(.*?)$endPattern.*/$1/s;
    $html = '' unless defined $1;
  }
  if (($startPattern ne '^') && ($endPattern eq '$'))
  {
    $html =~ s/.*?$startPattern(.*)/$1/s;
    $html = '' unless defined $1;
  }
  if (($startPattern eq '^') && ($endPattern ne '$'))
  {
    $html =~ s/(.*?)$endPattern.*/$1/s;
    $html = '' unless defined $1;
  }

  return $html;
}

# ------------------------------------------------------------------------------

# Searches text for "a href" or "img src" tags and makes them absolute
sub MakeLinksAbsolute
{
  my $url = shift;
  my $text = shift;

  # First do the ones with quotes, like <a href="X">.
  # It has to start with either <a or <img, then there has to be an href or src
  # followed by whitespace, then an =, some whitespace, and then a ".
  $text =~ s/(<(?:a|img) [^>]*(?:href|src)\s*=\s*\")([^\">]+)(\"[^>]*>)/$1.sprintf("%s",URI->new($2)->abs($url)).$3/egi;

  # Now do the ones with quotes, like <a href='X'>.
  # It has to start with either <a or <img, then there has to be an href or src
  # followed by whitespace, then an =, some whitespace, and then a '.
  $text =~ s/(<(?:a|img) [^>]*(?:href|src)\s*=\s*\')([^\'>]+)(\'[^>]*>)/$1.sprintf("%s",URI->new($2)->abs($url)).$3/egi;

  # Now do the ones without quotes, like <a href=X>.
  # It has to start with either <a or <img, then there has to be an href or src
  # followed by whitespace, then an =, some whitespace, the value, and then a
  # space.
  $text =~ s/(<(?:a|img) [^>]*(?:href|src)\s*=\s*)([^\" ][^ >]+)((?:\s*[^>]*)?>)/$1.sprintf("%s",URI->new($2)->abs($url)).$3/egi;

  return $text;
}

1;
