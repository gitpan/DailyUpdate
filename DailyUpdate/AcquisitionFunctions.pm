# -*- mode: Perl; -*-
package DailyUpdate::AcquisitionFunctions;

# This package contains a set of useful functions for grabbing data from the
# internet. It is used by the handlers' Get functions.

use strict;
# Used to make relative URLs absolute
use URI;
# For UserAgent
use LWP::UserAgent;
# For exporting of functions
use Exporter;

use vars qw( @ISA @EXPORT_OK $VERSION );

@ISA = qw( Exporter );
@EXPORT_OK = qw( MakeLinksAbsolute GetUrl GetHtml GetImages GetLinks GetText );

$VERSION = 0.1;

# DEBUG for this package is the same as the main.
use constant DEBUG => main::DEBUG;

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
    $html = '' if $1 eq '';
  }
  if (($startPattern ne '^') && ($endPattern eq '$'))
  {
    $html =~ s/.*?$startPattern(.*)/$1/s;
    $html = '' if $1 eq '';
  }
  if (($startPattern eq '^') && ($endPattern ne '$'))
  {
    $html =~ s/(.*?)$endPattern.*/$1/s;
    $html = '' if $1 eq '';
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
  $text =~ s/(<(?:a|img) [^>]*(?:href|src)\s*=\s*")([^">]+)("[^>]*>)/sprintf("$1%s$3",URI->new($2)->abs($url))/egi;

  # Now do the ones with quotes, like <a href='X'>.
  # It has to start with either <a or <img, then there has to be an href or src
  # followed by whitespace, then an =, some whitespace, and then a '.
  $text =~ s/(<(?:a|img) [^>]*(?:href|src)\s*=\s*')([^'>]+)('[^>]*>)/sprintf("$1%s$3",URI->new($2)->abs($url))/egi;

  # Now do the ones without quotes, like <a href=X>.
  # It has to start with either <a or <img, then there has to be an href or src
  # followed by whitespace, then an =, some whitespace, the value, and then a
  # space.
  $text =~ s/(<(?:a|img) [^>]*(?:href|src)\s*=\s*)([^"][^ >]+)( [^>]*>)/sprintf("$1%s$3",URI->new($2)->abs($url))/egi;

  return $text;
}

# ------------------------------------------------------------------------------

# Gets the entire content from a URL. file:// supported
sub GetUrl
{
  my $url = shift;

  print "<!-- DEBUG: GetUrl is getting URL: $url -->\n" if (DEBUG);

  if ($url =~ /^file:\/\/(.*)/i)
  {
    open INFILE, $1;
    my $content = join '',<INFILE>;
    close INFILE;
    return \$content;
  }
  else
  {
    my $userAgent = new LWP::UserAgent;
    $userAgent->timeout($main::config{socketTimeout});
    $userAgent->proxy(['http', 'ftp'], $main::config{proxy})
      if $main::config{proxy} ne '';
    my $request = new HTTP::Request GET => "$url";
    my $result = $userAgent->request($request);

    if (!$result->is_success)
    {
      # Don't change "Couldn't get". It's used by CachedDataUsable
      print "Couldn't get data. Error on HTTP request: ".$result->message.".\n"
        if (defined $result);
      return;
    }

    my $content = $result->content;
    return \$content;
  }
}

# ------------------------------------------------------------------------------

# Gets all the text from a URL, stripping out all HTML tags between the
# starting pattern and the ending pattern.
sub GetText
{
  my ($url,$startPattern,$endPattern) = @_;

  my $html = &GetUrl($url);

  return if !defined $html;

  $html = $$html;

  # Strip off all the stuff before and after the start and end patterns
  $html = &ExtractText($html,$startPattern,$endPattern);

  # Remove pieces of tags at the ends
  $html =~ s/^[^<]*>//s;
  $html =~ s/<[^>]*$//s;

  require HTML::FormatText;
  use HTML::Parse;
  my $f = HTML::FormatText->new(leftmargin=>0);
  $html = $f->format(parse_html($html));
  $html =~ s/\n*$//sg;

  return \$html;
}

# ------------------------------------------------------------------------------

# Extracts HTML between startPattern and endPattern. 

# startPattern and endPattern can be '^' or '$' to match the beginning of the
# file or the end of the file.
sub GetHtml
{
  my ($url,$startPattern,$endPattern) = @_;

  my $html = &GetUrl($url);

  return if !defined $html;

  $html = $$html;

  # Strip off all the stuff before and after the start and end patterns
  $html = &ExtractText($html,$startPattern,$endPattern);

  $html = &MakeLinksAbsolute($url,$html);

  return \$html;
}

#-------------------------------------------------------------------------------

# Extracts all <img...> tags at a given url between startPattern
# and endPattern.
# Handles '^' and '$' to signify start and end of file.
# Thanks to Tanner Lovelace <lovelace@cs.unc.edu> for writing this
sub GetImages
{
  my ($url,$startPattern,$endPattern) = @_;

  my $html = &GetUrl($url);

  return if !defined $html;

  $html = $$html;

  # Strip off all the stuff before and after the start and end patterns
  $html = &ExtractText($html,$startPattern,$endPattern);

  my @imgTags;

  # See if there's a <img...> on this line
  while ($html =~ /(<img .*?>)/sgci)
  {
    my $imgTag = $1;

    # change relative tags to absolute
    $imgTag = &MakeLinksAbsolute($url,$imgTag);
    push @imgTags,$imgTag;
  }

  return \@imgTags;
}

# ------------------------------------------------------------------------------

# Extracts all <a href...>...</a> links at a given url between startPattern
# and endPattern. Removes all text formatting, and makes relative links
# absolute. Puts quotes around attribute values in stuff like <a href=blah> and
# <img src=blah>.

# Now handles '^' and '$' to signify start and end of file.
sub GetLinks
{
  my ($url,$startPattern,$endPattern) = @_;

  my $html = &GetUrl($url);

  return if !defined $html;

  $html = $$html;

  # Strip off all the stuff before and after the start and end patterns
  $html = &ExtractText($html,$startPattern,$endPattern);

  my @links;

  # See if there's a link on this line
  while ($html =~ /(<a href.*?>.*?<\/a>)/sgci)
  {
    my $link = $1;

    # Remove any formatting
    $link =~ s/< *\/?(font|li|b|h[1-9]).*?>//sig;

    # change relative tags to absolute
    $link = &MakeLinksAbsolute($url,$link);

    push @links,$link;
  }

  return \@links;
}

1;
