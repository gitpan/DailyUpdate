# -*- mode: Perl; -*-
package DailyUpdate::Parser;

# This package contains a parser for Daily Update "enabled" HTML files. It
# basically passes all tags except ones like <dailyupdate name=...>, which are
# converted to information gathered from the net.

use strict;
use HTML::Parser;
use DailyUpdate::HandlerFactory;

use vars qw( @ISA $VERSION );
@ISA = qw(HTML::Parser);

$VERSION = 0.1;

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
sub comment { print "<!--$_[1]-->"; }
sub end { print "</$_[1]>"; }

# ------------------------------------------------------------------------------

sub start
{
  my $self = shift @_;
  my $originalText = pop @_;
  my ($tag, $attributeList) = @_;

  if (lc($tag) eq 'dailyupdate')
  {
    die "A dailyupdate tag must have a \"name\" attribute\n"
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
    print $originalText;
  }
}

1;
