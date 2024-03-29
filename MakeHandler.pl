# use perl                                  -*- mode: Perl; -*-
eval 'exec perl -S $0 "$@"'
  if $running_under_some_shell;

use strict;

my $VERSION = 0.3;

my %info;
# author
# email
# name
# description
# url: url for the web page
# urlcode: code that sets "my $url"
# defaults: code to set defaults
# attributes: an array of all the attributes and their possible values, as
#   "attribute:(value1|value2|value3)".
# patterncode: code to set the start and end patterns
# getfunction: the name of the Get function (GetHtml, e.g.)
# getcode: the Get code.
# date: code for the GetUpdateTimes function
# defaulthandlers: code that contains the GetDefaultHandlers function

sub Prompt;
my ($editor,@prompt);

print <<EOT;
Greetings! This is Daily Update's MakeHandler.pl program, which is designed to
help you write handlers. Well, actually, it will help you write *Acquisition*
handlers. General filter and output handlers are a bit more involved, and it's
not likely that you'll need to write them.

In order to make your life easier, you can now use your favorite text editor
to enter information. The main control will happen here at the script, but
most of the data entry will be done in the editor.  Just enter the requested
information in the space immediately following the questions. You can can
create more space between questions if you need it.

Please read the hints for handler writers, at
http://www.cs.virginia.edu/~dwc3q/code/DailyUpdate/writehandlers.html

EOT

print "Enter the name of your favorite editor: ";
$editor = <STDIN>;
chomp $editor;

#-------------------------------------------------------------------------------

print "First, we need a few details...\n\n";

push @prompt,<<EOT;
What's your name?
EOT

push @prompt,<<EOT;
Where can people reach you by email, in case they have problems with your
handler, or want to make modifications to it?
EOT

push @prompt,<<EOT;
Enter the handler's name, in all lower case.
EOT

push @prompt,<<EOT;
Gimme a one line description of the handler, so people can grok what it does
when it is listed on the handler webpage.
EOT

push @prompt,<<EOT;
Enter a URL where people can surf to in order to get an idea of where the data
comes from.
EOT

push @prompt,<<EOT;
Sometimes people like to slap a license on their code that gives other people
limited rights to modify, copy, sell, etc. it. The GPL is pretty popular, as
is the Artistic license.

Enter the license type, if you want to license your code:
EOT

($info{author},$info{email},$info{name},$info{description},$info{url},$info{license}) =
  Prompt(@prompt);

#-------------------------------------------------------------------------------

print <<EOT;
Some URLs depend on what parameters the user enters. For example, the
yahootopstories handler can grab data from several different URLs that all
share a common format.

Will your URL depend on a parameter?
EOT

my $yesno;
$yesno = <STDIN>;
if ($yesno =~ /^y/i)
{
push @prompt,<<EOT;
What is the name of the attribute that you would like the URL to depend on?
("source", for example.)
EOT

push @prompt,<<EOT;
Enter the values (in lower case) and corresponding URLs, like so:
'headlines' => 'http://some.server.com/headlines'
'technews' => 'http://some.server.com/technews'
'humor' => 'http://some.server.com/humor'
EOT

push @prompt,<<EOT;
What is the default value for the attribute?
EOT

my ($attr,$values,$default) = Prompt(@prompt);

$values =~ s/\n/,\n    /gs;

$info{urlcode} = "  \%urlMap = (\n    $values,\n  );\n\n";
$info{urlcode} .= "  my \$url = \$urlMap{\$attributes->{'$attr'}};\n";

$info{defaults} .= "  \$attributes->{'$attr'} = '$default'\n    unless defined ".
                   "\$attributes->{'$attr'};\n";

$values =~ s/'\s*=>\s*'[^']+'/|/gs;
$values =~ s/['\n ,]//g;
$values =~ s/\|$//gs;

push @{$info{attributes}}, "$attr:($values)";
}
else
{
push @prompt,<<EOT;
What is the URL from which Daily Update should grab the data?
EOT

($info{urlcode}) = Prompt(@prompt);
$info{urlcode} = "  my \$url = '$info{urlcode}';\n";
}

#-------------------------------------------------------------------------------

RETRY1:

print <<EOT;
Choose an acquisition function:
(1) GetUrl -- Gets raw data from a URL, without making links absolute. Use
              this for text and such. Grabs all the data from the URL.
(2) GetText -- Extracts text from HTML, fixing < to &lt;, etc.
(3) GetHtml -- Extracts HTML, fixing relative links.
(4) GetImages -- Extracts images, fixing relative links.
(5) GetLinks -- Extracts hyperlinks, fixing relative links and removing
    formatting.
EOT

my $input = <STDIN>;
chomp $input;
goto RETRY1 if $input !~ /^[12345]$/;

$info{getcode} = '  my $data = ';

my $acqFunction;
$info{getfunction} = 'GetUrl' if $input eq '1';
$info{getfunction} = 'GetText' if $input eq '2';
$info{getfunction} = 'GetHtml' if $input eq '3';
$info{getfunction} = 'GetImages' if $input eq '4';
$info{getfunction} = 'GetLinks' if $input eq '5';

$info{getcode} .= 'GetUrl' if $input eq '1';
$info{getcode} .= 'GetText' if $input eq '2';
$info{getcode} .= 'GetHtml' if $input eq '3';
$info{getcode} .= 'GetImages' if $input eq '4';
$info{getcode} .= 'GetLinks' if $input eq '5';

$info{getcode} .= "(\$url,\$startPattern,\$endPattern);\n"
  if $info{getfunction} ne 'GetUrl';
$info{getcode} .= "(\$url);\n"
  if $info{getfunction} eq 'GetUrl';

$info{getcode} .= "  return undef unless defined \$data;\n";

#-------------------------------------------------------------------------------

if ($info{getfunction} ne 'GetUrl')
{
print <<EOT;
Sometimes there are several sections on a web page, and you want to allow the
user to choose only one. For example, a site might put headlines and tech
articles on the same web page. Answer "no" to this question if there are
several pieces of data, and it's likely that the user will want them all.

Do you want the grabbed data to depend on a parameter?
EOT

$yesno;
$yesno = <STDIN>;
if ($yesno =~ /^y/i)
{
push @prompt,<<EOT;
First, a word about patterns. You should prefix the pattern with (?i) if you
want it to be case insensitive. ^ matches the beginning of the web page, and \$
matches the end. You can use \\n to match the end of a line.

Try to choose something that is unlikely to change when the web site gets
redesigned. For example, if you're grabbing a comic, and you know that the
comic is the only image that has a filename like "blah29385829.gif", don't try
to precisely grab the <img src="blah29385829.gif"> tag using GetHtml. Instead,
grab all the images using GetImages, then weed out everything but the one you
want. (When using GetLinks and GetImages, you can afford to have a "loose"
match if it allows you to pick a better pattern.)

You should return "clean" HTML, without any unclosed <em>s and such. In fact,
you should strip out <font> tags, since that restricts the web designer. Later
you can manually edit the handler and clean up the HTML using the TrimTags and
StripTags functions.

What is the name of the attribute that you would like the grabbed data to
depend on? ("source", for example.)
EOT

push @prompt,<<EOT;
Enter the values (in lower case) and corresponding starting and ending
patterns that Daily Update can use to grab the information, like so:
'headlines' => ['<!-- Start Headlines -->','<!-- End Headlines -->'],
'technews' => ['<!-- Start Technews -->','<!-- End Technews -->'],
'humor' => ['<!-- Start Humor -->','<!-- End Humor -->'],
EOT

push @prompt,<<EOT;
What is the default value for the attribute?
EOT

my ($attr,$values,$default) = Prompt(@prompt);

$values =~ s/\n/\n    /gs;

$info{patterncode} = "  \%patternMap = (\n    $values,\n  );\n\n";
$info{patterncode} .= "  my \$startPattern = \$urlMap{\$attributes->{'$attr'}}[0];\n";
$info{patterncode} .= "  my \$endPattern = \$urlMap{\$attributes->{'$attr'}}[1];\n";

$info{defaults} .= "  \$attributes->{'$attr'} = '$default'\n    unless defined ".
                   "\$attributes->{'$attr'};\n";

$values =~ s/'\s*=>\s*\[[^\]]+\]/|/gs;
$values =~ s/['\n ,]//g;
$values =~ s/\|$//gs;

push @{$info{attributes}}, "$attr:($values)";
}
else
{
push @prompt,<<EOT;
First, a word about patterns. You should prefix the pattern with (?i) if you
want it to be case insensitive. ^ matches the beginning of the web page, and \$
matches the end. You can use \\n to match the end of a line.

Try to choose something that is unlikely to change when the web site gets
redesigned. For example, if you're grabbing a comic, and you know that the
comic is the only image that has a filename like "blah29385829.gif", don't try
to precisely grab the <img src="blah29385829.gif"> tag using GetHtml. Instead,
grab all the images using GetImages, then weed out everything but the one you
want. (When using GetLinks and GetImages, you can afford to have a "loose"
match if it allows you to pick a better pattern.)

You should return "clean" HTML, without any unclosed <em>s and such. In fact,
you should strip out <font> tags, since that restricts the web designer. Later
you can manually edit the handler and clean up the HTML using the TrimTags and
StripTags functions.

What is the starting pattern Daily Update can use to grab the data?
EOT

push @prompt,<<EOT;
What is the ending pattern Daily Update can use to grab the data?
EOT

my ($start,$end) = Prompt(@prompt);

$info{patterncode} = "  my \$startPattern = '$start';\n";
$info{patterncode} .= "  my \$endPattern = '$end';\n";
}
}

#-------------------------------------------------------------------------------

if ($info{getfunction} =~ /(Url|Text|Html)/)
{
  $info{defaulthandlers} =<<EOT;
sub GetDefaultHandlers
{
  my \$self = shift;
  my \$inputAttributes = shift;

  my \@returnVal = (
    {'name' => 'string'},
  );

  return \@returnVal;
}
EOT
}
else
{
  $info{defaulthandlers} =<<EOT;
sub GetDefaultHandlers
{
  my \$self = shift;
  my \$inputAttributes = shift;

  my \@returnVal = (
    {'name' => 'limit', 'number' => 10},
    {'name' => 'array'}
  );

  return \@returnVal;
}
EOT
}

#-------------------------------------------------------------------------------

push @prompt,<<EOT;
Now specify the times at which you know the remote server updates its data,
and that Daily Update should refresh its cached data.  Please be a little
conservative here -- If you specify every hour of the day, lots of people will
be hitting their server when they probably aren't even looking at their Daily
Update webpage.

Date specifications are of the form "[day] hour,hour,hour [time zone]". If you
leave out the day, every day is assumed. If you leave out the time zone,
Pacific Standard Time is assumed. If you leave out everything, the default of
"2,5,8,11,14,17,20,23 PST" is used.  For example, if you are making a handler
for a daily comic, you might want to just use '7', since the comic changes at
6 am PST every day.

The days are: sun,mon,tue,wed,thu,fri,sat. You can specify multiple times, for
example:

mon 6,8 EST
tues 16 CST
20

would update Mondays at 6am and 8am EST, Tuesdays at 4pm CST, and every day
at 8pm PST.

Enter your date specification:
EOT

my ($datespec) = Prompt(@prompt);

if ($datespec eq '')
{
  $info{date} = '';
}
else
{
  $datespec =~ s/\n/',\n    ,'/gs;

  $info{date} =<<EOT;
sub GetUpdateTimes
{
  return ['$datespec'];
}
EOT
}

#-------------------------------------------------------------------------------

my $attributes;
$attributes = join ' ',@{$info{attributes}} if defined $info{attributes};
print "#####$attributes###\n";
$attributes = '' unless defined $info{attributes};

$attributes =~ s/:([^)]+)\)/=X/g;
$attributes = " $attributes" if $attributes ne '';

my $att2;
$att2 = join "\n#   ",@{$info{attributes}} if defined $info{attributes};
$att2 = '' unless defined $info{attributes};
$att2 = "\n#   $att2" if $att2 ne '';

my $code =<<EOT;
--------> THESE LINES WILL BE REMOVED BY MAKEHANDLER               <--------
--------> EDIT THIS VERSION OF THE HANDLER IF YOU NEED TO.         <--------
--------> FOR EXAMPLE, IF YOU WERE DOING THE "ASTROPIC" HANDLER,   <--------
--------> YOU WOULD WANT TO RETURN A HASH CONTAINING SEVERAL DATA  <--------
--------> ITEMS, SO YOU'D HAVE TO EDIT THE "GET" FUNCTION, AS WELL <--------
--------> AS THE "GETDEFAULTHANDLERS" FUNCTION.                    <--------
# -*- mode: Perl; -*-

--------> FIX THESE COMMENTS. ADD ANY ADDITIONAL ATTRIBUTES YOU    <--------
--------> NEED, AND EXPLAIN WHAT THE ATTRIBUTES MEAN. THIS IS THE  <--------
--------> DOCUMENTATION THAT THE USER WILL REFER TO IN ORDER TO    <--------
--------> USE YOUR HANDLER.                                        <--------
# AUTHOR: $info{author}
# EMAIL: $info{email}
# ONE LINE DESCRIPTION: $info{description}
# URL: $info{url}
# TAG SYNTAX:
# <input name=$info{name}$attributes>$att2
# LICENSE: $info{license}
# NOTES:

package DailyUpdate::Handler::Acquisition::$info{name};

use strict;
use DailyUpdate::Handler;
use vars qw( \@ISA \$VERSION );
\@ISA = qw(DailyUpdate::Handler);

# DEBUG for this package is the same as the main.
use constant DEBUG => main::DEBUG;

use DailyUpdate::AcquisitionFunctions qw( $info{getfunction} );

\$VERSION = 0.1;

# ------------------------------------------------------------------------------

# This function is used to get the raw data from the URL.
sub Get
{
  my \$self = shift;
  my \$attributes = shift;

$info{defaults}
$info{urlcode}
$info{patterncode}
$info{getcode}
--------> IF YOU NEED TO DO ADDITIONAL PROCESSING, LIKE A          <--------
--------> \@\$data = grep {/\d{5}.gif/} \@\$data;                      <--------
--------> TO FILTER OUT IMAGES THAT DON'T HAVE 5 DIGITS, OR IF     <--------
--------> YOU NEED TO SPLIT THE DATA UP FURTHER, DO IT HERE.       <--------
  return \$data;
}

# ------------------------------------------------------------------------------

--------> MAKEHANDLER TRIED TO MAKE A GOOD GUESS HERE. YOU MIGHT   <--------
--------> NEED TO CHANGE THIS.                                     <--------
$info{defaulthandlers}

# ------------------------------------------------------------------------------

$info{date}

1;

EOT

open FILE,">MakeHandler.inp";
print FILE $code;
close FILE;

system ("$editor MakeHandler.inp");

open FILE,"<MakeHandler.inp";
my $finishedcode = join '',<FILE>;
close FILE;

$finishedcode =~ s/-------->[^<]+<--------//gs;
$finishedcode =~ s/\n\n\n+/\n\n/gs;

open FILE, ">$info{name}.pm";
print FILE $finishedcode;
close FILE;

print <<EOT;
A basic handler called $info{name}.pm has been created for you.

To try it out, put it in your handlers directory (typically
DailyUpdate/Handler/) and put
<!--dailyupdate
  <input name=$info{name}>
-->
in your input file.

Have fun!
EOT

#-------------------------------------------------------------------------------

sub Prompt
{
open FILE,">MakeHandler.inp";
foreach my $data (@prompt)
{
  print FILE $data,"\n","-"x78,"\n";
}
close FILE;

RETRY2:

system ("$editor MakeHandler.inp");

open FILE,"<MakeHandler.inp";
my $returnString = join '',<FILE>;
close FILE;

my @returnvals = ();

foreach my $data (@prompt)
{
  my $response = undef;
  my $pattern = $data;

  # Escape special symbols
  $pattern =~ s/\\/\\\\/gs;
  $pattern =~ s/([\{\}\(\)\^\[\]\+\*\.\$\?])/\\$1/gs;

  ($response) = $returnString =~ /$pattern\s*(.*?)\s*------------/s;

  unless (defined $response)
  {
    print "Sorry, I couldn't figure out what you answered for the ",
          "question:\n\n$data\nTry again.\n";
    goto RETRY2;
  }

  push @returnvals, $response;
}

@prompt = ();

return @returnvals;
}

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

