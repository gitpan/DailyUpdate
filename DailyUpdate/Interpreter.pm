# -*- mode: Perl; -*-

package DailyUpdate::Interpreter;

use strict;

use vars qw( $VERSION );

$VERSION = 0.1;

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

sub _GetInput
{
  my $handlerName = shift;
  my $handler = shift;
  my $attributeList = shift;

  print "<!--DEBUG: Calling Get function for handler $handlerName.-->\n"
    if DEBUG;

  # Get the data
  my $data = $handler->Get($attributeList);

  if ((!defined $data)||
      ((ref($data) eq "ARRAY") && (!defined @$data)) ||
      ((ref($data) eq "SCALAR") && (!defined $$data)))
  {
    print "<!--Daily Update message:\n",
          "Couldn't get data. Handler's Get function returned nothing.\n",
          "-->\n";
    return undef;
  }

  print "<!--DEBUG: ",$#{$data}+1," lines acquired. -->\n"
    if DEBUG && ref($data) eq "ARRAY";
  print "<!--DEBUG: ",length $$data," characters acquired. -->\n"
    if DEBUG && ref($data) eq "SCALAR";

  return $data;
}

# ------------------------------------------------------------------------------

sub _FilterData
{
  my $handlerName = shift;
  my $handler = shift;
  my $attributeList = shift;
  my $data = shift;

  print "<!--DEBUG: Calling Filter function for handler $handlerName.-->\n"
    if DEBUG;

  # Filter the data
  $data = $handler->Filter($attributeList,$data);

  if ((!defined $data)||
      ((ref($data) eq "ARRAY") && (!defined @$data)) ||
      ((ref($data) eq "SCALAR") && (!defined $$data)))
  {
    print "<!--Daily Update message:\n",
          "Couldn't get data. Handler's Filter function returned nothing.\n",
          "-->\n";
    return undef;
  }

  print "<!--DEBUG: ",$#{$data}+1," lines filtered. -->\n"
    if DEBUG && ref($data) eq "ARRAY";
  print "<!--DEBUG: ",length $$data," characters filtered. -->\n"
    if DEBUG && ref($data) eq "SCALAR";

  return $data;
}

# ------------------------------------------------------------------------------

sub _OutputData
{
  my $handlerName = shift;
  my $handler = shift;
  my $attributeList = shift;
  my $data = shift;

  print "<!--DEBUG: Calling Output function for handler $handlerName.-->\n"
    if DEBUG;

  $handler->Output($attributeList,$data);
}

# ------------------------------------------------------------------------------

sub _GetDefaultCommands
{
  my @commands = @_;

  # We only try to fill in defaults if the user only specified an input
  # command.
  return @commands if $#commands > 0 || $commands[0][0] ne 'input';

  my ($type,$attributeList) = @{$commands[0]};

  my $handlerName = $attributeList->{name};

  # Create a handler factory to give us a suitable handler
  require DailyUpdate::HandlerFactory;
  my $handlerFactory = new DailyUpdate::HandlerFactory;

  # Ask the HandlerFactory to create a handler for us, based on the name.
  my $handler = $handlerFactory->Create($handlerName);

  if (defined $handler)
  {
    my @temp = $handler->GetDefaultHandlers($attributeList);

    print "<!--DEBUG: Adding default filter and output handlers -->\n"
      if DEBUG && $#temp != -1;

    for(my $i=0;$i <= $#temp;$i++)
    {
      if ($i != $#temp)
      {
        push @commands,['filter',$temp[$i]];
      }
      else
      {
        push @commands,['output',$temp[$i]];
      }
    }
  }

  return @commands;
}

# ------------------------------------------------------------------------------

sub Execute
{
my $self = shift;
my @commands = @_;

print "<!--DEBUG: Executing ",$#commands+1," commands.-->\n" if DEBUG;

# Fill in any defaults
@commands = _GetDefaultCommands(@commands);

my $data = undef;

foreach my $command (@commands)
{
  my ($type,$attributeList) = @$command;
  my $handlerName = $attributeList->{name};

  delete $attributeList->{name};

  # Create a handler factory to give us a suitable handler
  require DailyUpdate::HandlerFactory;
  my $handlerFactory = new DailyUpdate::HandlerFactory;

  # Ask the HandlerFactory to create a handler for us, based on the name.
  my $handler = $handlerFactory->Create($handlerName);

  if (defined $handler)
  {
    # Now have the handler handle it!
    $data = _GetInput($handlerName,$handler,$attributeList)
      if $type eq 'input';

    $data = _FilterData($handlerName,$handler,$attributeList,$data)
      if $type eq 'filter' and defined $data;

    _OutputData($handlerName,$handler,$attributeList,$data)
      if $type eq 'output' and defined $data;
  }

  # If the get function failed, or everything was filtered out, quit
  print "<!--Daily Update message:\n",
        "Aborting execution for this Daily Update tag.\n",
        "-->\n" and last
    if !defined $data || $data eq '';
}

}

1;
