# -*- mode: Perl; -*-

# AUTHOR: David Coppit
# EMAIL: coppit@cs.virginia.edu
# ONE LINE DESCRIPTION: Filter that redirects img tags in a string to point to
#   cached images
# URL:
# TAG SYNTAX:
# <filter name=cacheimages maxage=X dir=Y url=Z>
#   Accepts a string and returns a string.
#   X: maximum age of the images in the image cache. This handler deletes old
#     images every time it is run. Since this could result in broken links,
#     you should set this value to the maximum age of any web page that
#     references images in the cache. (defaults to the value of maximgcacheage
#     in DailyUpdate.cfg)
#   Y: the file system location of the image cache. (defaults to the value of
#     imgcachedir in DailyUpdate.cfg)
#   Z: the url that corresponds to the value of "dir". (defaults to the value
#     of imgcacheurl in DailyUpdate.cfg)
# LICENSE: GPL
# NOTES:

package DailyUpdate::Handler::Filter::cacheimages;

use strict;
use DailyUpdate::Handler;
use URI;
# For mkpath
use File::Path;

use vars qw( @ISA $VERSION );
@ISA = qw(DailyUpdate::Handler);

# DEBUG for this package is the same as the main.
use constant DEBUG => main::DEBUG;

$VERSION = 0.2;

# ------------------------------------------------------------------------------

sub _ClearCache
{
  my $dir = shift;
  my $maxage = shift;

  return if !-e $dir;

  print "<!--DEBUG: Clearing out old images in image cache $dir -->\n"
    if DEBUG;

  opendir DIR, $dir or die "Couldn't open dir: $!";
  my @files = readdir DIR;
  closedir DIR;

  foreach my $file (@files)
  {
    next unless -f "$dir/$file";
    my $lastmodified = (stat "$dir/$file")[9];
    my $currenttime = time;
    my $timediff = $currenttime - $lastmodified;

    print "<!--DEBUG: Deleted $dir/$file -->\n"
      if DEBUG && $timediff > $maxage;
    unlink "$dir/$file" if $timediff > $maxage;
  }
}

# ------------------------------------------------------------------------------

# This function overwrites any file that has the same name. i.e.
# the file.gif from http://www.somewhere.com/file.gif will be overwritten by
# the file.gif from http://www.somewhereelse.com/file.gif.
# I'll fix this (somehow) later if it becomes a problem.
sub _CacheImage
{
  my $url = shift;
  my $dir = shift;

  print "<!--DEBUG: Caching image from URL:\n  $url -->\n" if DEBUG;

  # Get the file name from the url
  my ($filename) = $url =~ /(?:.*\/)?(.*)/;


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
    print "<!--Daily Update message:\n",
          "Couldn't cache image. Error on HTTP request: ".$result->message.".\n",
          "-->\n"
      if defined $result;

    return;
  }

  mkpath $dir unless -e $dir;

  # Write it to the file
  open OUTPUT, ">$dir/$filename";
  print OUTPUT $result->content;
  close OUTPUT;
}

# ------------------------------------------------------------------------------

sub Filter
{
  my $self = shift;
  my $attributes = shift;
  my $grabbedData = shift;

  # Get the defaults if needed
  $attributes->{maxage} = $main::config{maximgcacheage}
    unless defined $attributes->{maxage};
  $attributes->{dir} = $main::config{imgcachedir}
    unless defined $attributes->{dir};
  $attributes->{url} = $main::config{imgcacheurl}
    unless defined $attributes->{url};

  $attributes->{url} .= "/" if $attributes->{url} !~ /\/$/;

  return undef
    unless defined $attributes->{maxage} && $attributes->{maxage} ne '' &&
           defined $attributes->{dir} && $attributes->{dir} ne '' &&
           defined $attributes->{url} && $attributes->{url} ne '';

  print "<!--Daily Update message:\n",
        "  \"$attributes->{dir}\" exists, but isn't a directory.\n",
        "-->\n" and return
    if -e $attributes->{dir} && !-d $attributes->{dir};


  _ClearCache($attributes->{dir},$attributes->{maxage});


  print "<!--DEBUG: Caching images-->\n" if DEBUG;

  # Download all the images and store them in the cache. This assumes all
  # image links are fully qualified, which is what they'd be for any Daily
  # Update acquisition function used.
  $$grabbedData =~ s/
       # First look for the image tag
       (<\s*img\b[^>]*src\s*=\s*")
       # Look for the url
       ([^"]+)
       # Look for the closing part of the tag
       ("[^>]*>)
       # Call CacheImage, and replace the match with itself so we don't change
       # anything
       /_CacheImage($2,$attributes->{dir}),$1.$2.$3/segix;

  print "<!--DEBUG: Modifying links -->\n" if DEBUG;

  # Here we replace all the links to external sites to the cached images.
  # This assumes that all img src attributes are quoted, which is what all the
  # Daily Update acquisition functions do anyway.
  $$grabbedData =~ s/
       # First look for the image tag
       (<\s*img\b[^>]*src\s*=\s*")
       # Strip any fully qualified URL info, if it exists
       (?:http:[^"]*\/)?
       # Look for the filename
       ([^"]+)
       # Look for the closing part of the tag
       ("[^>]*>)
       # Replace the tag with the new one
       /$1.sprintf("%s",URI->new($2)->abs($attributes->{url})).$3/segix;

  return $grabbedData
}

1;
