# -*- mode: Perl; -*-
package DailyUpdate::AcquisitionFunctions;

# This package contains a set of useful functions for grabbing data from the
# internet. It is used by the handlers' Get functions.

use strict;
# For some HTML manipulation functions
use DailyUpdate::HTMLTools;
# For UserAgent
use LWP::UserAgent;
# For exporting of functions
use Exporter;

use vars qw( @ISA @EXPORT_OK $VERSION );

@ISA = qw( Exporter );
@EXPORT_OK = qw( GetUrl GetHtml GetImages GetLinks GetText);

$VERSION = 0.4;

# DEBUG for this package is the same as the main.
use constant DEBUG => main::DEBUG;

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
    # Reload content if the user wants it
    $request->push_header("Pragma" => "no-cache") if exists $main::opts{r};

    if ($main::config{proxy_username} ne '')
    {
      $request->proxy_authorization_basic($main::config{proxy_username},
                       $main::config{proxy_password});
    }

    my $result = $userAgent->request($request);

    if (!$result->is_success)
    {
      # Don't change "Couldn't". It's used by CachedDataUsable
      print "Couldn't get data. Error on HTTP request: ".$result->message.".\n"
        if (defined $result);
      return;
    }

    my $content = $result->content;

    # Strip linefeeds off the lines
    $content =~ s/\r//gs;

    return \$content;
  }
}

# ------------------------------------------------------------------------------

# Gets all the text from a URL, stripping out all HTML tags between the
# starting pattern and the ending pattern. This function escapes & < >.
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
  require HTML::TreeBuilder;

  my $f = HTML::FormatText->new(leftmargin=>0);
  $html = $f->format(HTML::TreeBuilder->new->parse($html));
  $html =~ s/\n*$//sg;

  # Escape HTML characters
  $html =~ s/&/&amp;/sg;
  $html =~ s/</&lt;/sg;
  $html =~ s/>/&gt;/sg;

  if ($html ne '')
  {
    return \$html;
  }
  else
  {
    return undef;
  }
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

  if ($html ne '')
  {
    return \$html;
  }
  else
  {
    return undef;
  }
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

  if ($#imgTags != -1)
  {
    return \@imgTags;
  }
  else
  {
    return undef;
  }
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
  while ($html =~ /(< *a[^>]*\bhref\b[^>]*>.*?<\/a>)/sgci)
  {
    my $link = $1;

    # Remove any formatting
    $link = StripTags($link);

    # change relative tags to absolute
    $link = &MakeLinksAbsolute($url,$link);

    push @links,$link;
  }

  if ($#links != -1)
  {
    return \@links;
  }
  else
  {
    return undef;
  }
}

1;
