# use perl                                  -*- mode: Perl; -*-
eval 'exec perl -S $0 "$@"'
  if $running_under_some_shell;

use strict;

my $VERSION = 0.2;

# Get some basic info
my ($author,$email,$description,$url,$syntax);

print "Your Name: ";
$author = <STDIN>;

print "Email: ";
$email = <STDIN>;

print "One line description of handler: ";
$description = <STDIN>;

print "URL from which to grab data: ";
$url = <STDIN>;

print "Syntax (CTRL-D on blank line to end):\n<!--dailyupdate name=";
$syntax = join '',<STDIN>;

$syntax = "<!--dailyupdate name=$syntax";

chomp ($author,$email,$description,$syntax,$url);

$syntax =~ s/\n/\n#   /gs;

my ($tag) = $syntax =~ /name=(\w+)/;


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

my $input = <STDIN>;
chomp $input;

my $getFunction;
$getFunction = '&GetUrl' if $input eq '1';
$getFunction = '&GetText' if $input eq '2';
$getFunction = '&GetHtml' if $input eq '3';
$getFunction = '&GetImages' if $input eq '4';
$getFunction = '&GetLinks' if $input eq '5';

my $getCode;
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
  my $startPattern = <STDIN>;
  chomp $startPattern;
  $startPattern =~ s/'/\\'/;

  print "End pattern: ";
  my $endPattern = <STDIN>;
  chomp $endPattern;
  $endPattern =~ s/'/\\'/;

  $getCode = "my \$data = $getFunction(\$url,'$startPattern','$endPattern');";
}

my ($printFunction,$outputCode);
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

print <<EOF;
The default times at which to update the data are 2,5,8,11,14,17,20,23. This
means that at 2 am, 5 am, etc., the cached data will be discarded and
refreshed from the server. Please enter the update times, or just hit enter if
you want to accept the default times.

For example, if you are making a handler for a daily comic, you might want to
just use 7, since the comic changes at 6 am every day. Note that the user can
override this value in the configuration file.
EOF

my $updateTimes = <STDIN>;
chomp $updateTimes;

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

EOF

if ($updateTimes ne '')
{
print <<EOF;
# ------------------------------------------------------------------------------

sub GetUpdateTimes
{
  return [$updateTimes];
}
EOF
}

print "1;\n";

open STDOUT, ">&OLDOUT";
print <<EOF;
A basic handler called $tag.pm has been created for you. You may want to
edit the Filter function to filter out some of the data you grabbed in the Get
function. Also, you might want to change the print function to modify the look
of the output.

To try it out, put it in your handlers directory (typically
DailyUpdate/Handler/) and put <!--dailyupdate name=$tag-->
in your input file.

Have fun!
EOF

#-------------------------------------------------------------------------------

=head1 NAME

MakeHandler.pl - A generator for handlers suitable for use by Daily Update.

=head1 DESCRIPTION

I<MakeHandler.pl> is a handler generator. It asks the user a few questions,
and then creates a handler.pm file, which can then be edited further. It
jump-starts the handler writing process.

Handlers are the extensible mechanism by which I<Daily Update> can be
customized to acquire and display information from new data sources. Daily
Update provides an API of useful functions that can be used by the handler
writer.

For more information and hints about writing handlers, see
http://www.cs.virginia.edu/~dwc3q/code/DailyUpdate/writehandlers.html. Also
see the API description in the documentation for DailyUpdate.pl.

=head1 OPTIONS AND ARGUMENTS

None.

=head1 PREREQUISITES

No additional Perl modules are needed.

=head1 AUTHOR

David Coppit, <coppit@cs.virginia.edu>,
http://www.cs.virginia.edu/~dwc3q/index.html

=begin CPAN

=pod COREQUISITES

none

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

HTML/Preprocessors

=end CPAN

=cut
