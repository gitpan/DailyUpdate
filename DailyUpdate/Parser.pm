# -*- mode: Perl; -*-

# This is a small parser for the dailyupdate tags. The main parser is below.

package DailyUpdate::Parser::_TagParser;

use strict;
use HTML::Parser;

use vars qw( @ISA $VERSION );
@ISA = qw(HTML::Parser);

# DEBUG for this package is the same as the main.
use constant DEBUG => main::DEBUG;

# ------------------------------------------------------------------------------

sub new
{
  my $proto = shift;

  # We take the ref if "new" was called on an object, and the class ref
  # otherwise.
  my $class = ref($proto) || $proto;

  # Create an "object"
  my $self = {};

  # Make the object a member of the class
  bless ($self, $class);

  return $self;
}

# ------------------------------------------------------------------------------

sub start
{
  my $self = shift @_;
  my $originalText = pop @_;

  my ($tag, $attributeList) = @_;

  # Make sure all the attributes are lower case
  foreach my $attribute (keys %$attributeList)
  {
    if (lc($attribute) ne $attribute)
    {
      $attributeList->{lc($attribute)} = $attributeList->{$attribute};
      delete $attributeList->{$attribute};
    }
  }

  print "<!--Daily Update message:\n",
        "A Daily Update command must have a \"name\" attribute.\n",
        "-->\n" and return
    unless defined $attributeList->{name};

  if ($tag =~ /(input|filter|output)/)
  {
    push @DailyUpdate::Parser::_commandList,[$tag,$attributeList];
  }
  else
  {
    print "<!--Daily Update message:\n",
          "Invalid Daily Update command '$tag' seen in input file.\n",
          "-->\n";
  }
}

################################################################################

package DailyUpdate::Parser;

# This package contains a parser for Daily Update "enabled" HTML files. It
# basically passes all tags except ones like <!--dailyupdate ...-->, which are
# parsed for commands which are then executed.

use strict;
use HTML::Parser;

use vars qw( @ISA $VERSION $_commandList );
@ISA = qw(HTML::Parser);

# The little parser above fills this with parsed commands.
my @_commandList;

$VERSION = 0.4;

# DEBUG for this package is the same as the main.
use constant DEBUG => main::DEBUG;

# ------------------------------------------------------------------------------

sub new
{
  my $proto = shift;

  # We take the ref if "new" was called on an object, and the class ref
  # otherwise.
  my $class = ref($proto) || $proto;

  # Create an "object"
  my $self = {};

  # Make the object a member of the class
  bless ($self, $class);

  return $self;
}

# ------------------------------------------------------------------------------

# Basically pass everything through except the special tags.
sub text { print "$_[1]"; }
sub declaration { print "<!$_[1]>"; }
sub start { print pop @_; }
sub end { print "</$_[1]>"; }

# ------------------------------------------------------------------------------

sub comment
{
  my $self = shift @_;
  my $originalText = pop @_;

  if ($originalText =~ /^\s*dailyupdate\b/is)
  {
    print "<!--DEBUG: Found dailyupdate tag -->\n" if DEBUG;

    # Take off the dailyupdate stuff
    my ($commandText) = $originalText =~ /^\s*dailyupdate\s*(.*)\s*$/is;


    # Clear out the old commands, if there are any
    undef @DailyUpdate::Parser::_commandList;

    # Get the commands
    my $parser = new DailyUpdate::Parser::_TagParser;
    $parser->parse($commandText);


    # Now execute the commands
    require DailyUpdate::Interpreter;
    my $interpreter = new DailyUpdate::Interpreter;

    $interpreter->Execute(@DailyUpdate::Parser::_commandList);
  }
  # If it's not a special tag, just print it out.
  else
  {
    print "<!--$originalText-->";
  }

}

1;
