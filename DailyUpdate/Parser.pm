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

  if (lc($tag) eq 'dailyupdate')
  {
    print "<!--DEBUG: Found Daily Update tag -->\n" if DEBUG;
    $DailyUpdate::Parser::_attributeList = $attributeList;
  }

}

################################################################################

package DailyUpdate::Parser;

# This package contains a parser for Daily Update "enabled" HTML files. It
# basically passes all tags except ones like <!--dailyupdate name=...-->,
# which are converted to information gathered from the net.

use strict;
use HTML::Parser;
use DailyUpdate::HandlerFactory;

use vars qw( @ISA $VERSION $_attributeList );
@ISA = qw(HTML::Parser);

# The latter two are used to allow the callback to communicate to the comment
# handler.
my $_attributeList;

$VERSION = 0.3;

# DEBUG for this package is the same as the main.
use constant DEBUG => main::DEBUG;

# ------------------------------------------------------------------------------

my $handlerFactory = DailyUpdate::HandlerFactory->new;

sub new
{
  my $proto = shift;

  # We take the ref if "new" was called on an object, and the class ref
  # otherwise.
  my $class = ref($proto) || $proto;

  # Create an "object"
  my $self = {};

  # Store a reference to the "private" class-wide data
  $self->{_handlerFactory} = \$handlerFactory;

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

  # Parse the comment as a tag.
  $DailyUpdate::Parser::_attributeList = undef;
  my $p = new DailyUpdate::Parser::_TagParser;
  $p->parse("<$originalText>");
  
  # Make local copy of _attributeList
  my $attributeList = $DailyUpdate::Parser::_attributeList;

  if (defined $attributeList)
  {
    warn "A dailyupdate tag must have a \"name\" attribute\n"
      unless exists $attributeList->{name};

    # Ask the HandlerFactory to create a handler for us, based on the name.
    my $handler = ${$self->{_handlerFactory}}->Create($attributeList->{name});

    if (defined $handler)
    {
      delete $attributeList->{name};

      # Now have the handler handle it!
      $handler->Handle($attributeList);
    }
    else
    {
      print $originalText;
    }
  }
  # If it's not a special tag, just print it out.
  else
  {
    print "<!--$originalText-->";
  }

}

1;
