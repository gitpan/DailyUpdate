# use perl                                  -*- mode: Perl; -*-
eval 'exec perl -S $0 "$@"'
  if $running_under_some_shell;

# Get some basic info

print "Name: ";
$author = <STDIN>;

print "Email: ";
$email = <STDIN>;

print "One line description of handler: ";
$description = <STDIN>;

print "URL from which to grab data: ";
$url = <STDIN>;

print "Syntax (CTRL-D on blank line to end):\n<dailyupdate name=";
$syntax = join '',<STDIN>;

$syntax = "<dailyupdate name=$syntax";

chomp ($author,$email,$description,$syntax,$url);

$syntax =~ s/\n/\n#   /gs;

($tag) = $syntax =~ /name=(\w+)/;


# Now the tough part. We have to construct the Get, Filter, and Output
# functions.

print <<EOF;
Choose an acquisition function:
(1) GetUrl -- Gets raw data from a URL.
(2) GetText -- Extracts text from HTML.
(3) GetHtml -- Extracts HTML, fixing relative links.
(4) GetImages -- Extracts images, fixing relative links.
(5) GetLinks -- Extracts hyperlinks, fixing relative links and removing
    formatting.
EOF

$input = <STDIN>;
chomp $input;

$getFunction = '&GetUrl' if $input eq '1';
$getFunction = '&GetText' if $input eq '2';
$getFunction = '&GetHtml' if $input eq '3';
$getFunction = '&GetImages' if $input eq '4';
$getFunction = '&GetLinks' if $input eq '5';

if ($input eq '1')
{
  $getCode = '$data = GetUrl($url);\n';
}
else
{
  print <<EOF;
To limit the extraction, you'll need to enter two regular expressions. Just
pick some unique text before and after the stuff you want to grab, in case you
don't know what a regular expression is.

You can use ^ and \$ to indicate the beginning and end of the content,
respectively. Use \\n for newlines. Use a prefix of (?i) to make the pattern
case insensitive. For example, a URL whose content looks like:

<html>
<head><title>A test page</title></head>
<body>
Here is the <a href="alink.html">first link</a> on the page. Here is the
<a href="blink.html">second link</a> on the page.
</body>
</html>

Might use "Here is the\\n" for the starting pattern, and "\$" for the end
pattern in order to grab the second link. Try to choose patterns that are
robust with respect to changes in the format of a webpage.

EOF

  print "Start pattern: ";
  $startPattern = <STDIN>;
  chomp $startPattern;
  $startPattern =~ s/'/\\'/;

  print "End pattern: ";
  $endPattern = <STDIN>;
  chomp $endPattern;
  $endPattern =~ s/'/\\'/;

  $getCode = "my \$data = $getFunction(\$url,'$startPattern','$endPattern');";
}

if ($input =~ /(4|5)/)
{
  $printFunction = '&OutputListOrColumns';
  $outputCode = '&OutputListOrColumns($attributes,$grabbedData);';
}
else
{
  $printFunction = '';
  $outputCode = 'print $$grabbedData;';
}

open OLDOUT, ">&STDOUT";
open STDOUT, ">$tag.pm";

print <<EOF;
# -*- mode: Perl; -*-

# AUTHOR: $author
# EMAIL: $email
# ONE LINE DESCRIPTION: $description
# URL: $url
# TAG SYNTAX:
# $syntax

package DailyUpdate::Handler::$tag;

use strict;
use DailyUpdate::Handler;
use vars qw( \@ISA \$VERSION );
\@ISA = qw(DailyUpdate::Handler);

# DEBUG for this package is the same as the main.
use constant DEBUG => main::DEBUG;

use DailyUpdate::AcquisitionFunctions qw( $getFunction );
use DailyUpdate::OutputFunctions qw( $printFunction );

\$VERSION = 0.1;

# ------------------------------------------------------------------------------

# This function is used to get the raw data from the URL.
sub Get
{
  my \$self = shift;
  my \$attributes = shift;

  my \$url = "$url";
  $getCode

  return \$data;
}

# ------------------------------------------------------------------------------

# This function is used to filter out some of the data acquired using Get.
# You can delete this function entirely if you don't want to do any filtering.
sub Filter
{
  my \$self = shift;
  my \$attributes = shift;
  my \$grabbedData = shift;

  # Insert filter code here

  # Return a reference to the data.
  return \$grabbedData;
}

# ------------------------------------------------------------------------------

sub Output
{
  my \$self = shift;
  my \$attributes = shift;
  my \$grabbedData = shift;

  $outputCode
}

1;
EOF

open STDOUT, ">&OLDOUT";
print <<EOF;
A basic handler called $tag.pm has been created for you. You may want to
edit the Filter function to filter out some of the data you grabbed in the Get
function. Also, you might want to change the print function to modify the look
of the output.

To try it out, put it in your handlers directory (typically
DailyUpdate/Handler/) and put <dailyupdate name=$tag>
in your input file.

Have fun!
EOF
