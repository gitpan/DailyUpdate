# use perl                                  -*- mode: Perl; -*-

use strict;

my ($home,$timezone);

if (($^O eq 'dos') || ($^O eq 'MSWin32'))
{
  print<<EOT;
Hey, you're on a DOS or Windows system. You'll need to specify a path where
Daily Update can look for configuration information, if it can't find your
HOME environment variable. 
Be sure to use /, not \\.
EOT

  print "=> [C:/DailyUpdate] ";
  $home = <STDIN>;
  $home = "C:/DailyUpdate\n" if $home eq "\n";
  chomp $home;

  print<<EOT;

Also, you need to tell me what time zone you are in, because Date::Manip won't
be able to figure it out from your OS.  In the US, they are of the form PST,
CST, EST. See "perldoc Date::Manip" for a complete list.
EOT

  print "=> [PST] ";
  $timezone = <STDIN>;
  $timezone = "PST\n" if $timezone eq "\n";
  chomp $timezone;
}

# ------------------------------------------------------------------------------

my $prefix = undef;

if (grep {/INSTALLDIRS=perl/} @ARGV)
{
  $prefix = (grep {/PREFIX/} @ARGV)[0];

  $prefix =~ s/PREFIX=//;

  print<<EOT;

It looks like you're doing a single-user installation, as opposed to a
system-wide installation. I'm going to set modulepath in DailyUpdate.cfg to
point to \$INSTALLPRIVLIB. This is so that you don't have to change your
PERL5LIB variable, or run Daily Update using "perl -I".

EOT
}

# ------------------------------------------------------------------------------

my $sysconfigdir;
print "Where would you like to install the system-wide configuration file\n";
print "DailyUpdate.cfg?\n";
if (($^O eq 'dos') || ($^O eq 'MSWin32'))
{
  $sysconfigdir = "$home/etc";
}
else
{
  $sysconfigdir = '$(PREFIX)/etc';
}
print "=> [$sysconfigdir] ";
my $input = <STDIN>;
chomp $input;
$sysconfigdir = $input if $input ne '';

# ------------------------------------------------------------------------------

use ExtUtils::MakeMaker;

require 5.004;

WriteMakefile(
  # For debugging
  #'NOECHO' => '',
  'NAME'  => 'DailyUpdate',
  # finds $VERSION
  'VERSION_FROM' => 'DailyUpdate.pl',

  'dist'  => { COMPRESS => 'gzip -9', SUFFIX => 'gz' },
  # Gotta do this to prevent MakeMaker from thinking the .pl files are library
  # modules
  'PM' => {
    'DailyUpdate/AcquisitionFunctions.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/AcquisitionFunctions.pm',
    'DailyUpdate/Handler.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/Handler.pm',
    'DailyUpdate/HTMLTools.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/HTMLTools.pm',
    'DailyUpdate/HandlerFactory.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/HandlerFactory.pm',
    'DailyUpdate/Interpreter.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/Interpreter.pm',
    'DailyUpdate/Cache.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/Cache.pm',
    'DailyUpdate/Parser.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/Parser.pm',

    'DailyUpdate/Handler/Filter/cacheimages.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/Handler/Filter/cacheimages.pm',
    'DailyUpdate/Handler/Filter/grep.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/Handler/Filter/grep.pm',
    'DailyUpdate/Handler/Filter/hash2array.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/Handler/Filter/hash2array.pm',
    'DailyUpdate/Handler/Filter/highlight.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/Handler/Filter/highlight.pm',
    'DailyUpdate/Handler/Filter/limit.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/Handler/Filter/limit.pm',
    'DailyUpdate/Handler/Filter/map.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/Handler/Filter/map.pm',
    'DailyUpdate/Handler/Filter/selectkeys.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/Handler/Filter/selectkeys.pm',

    'DailyUpdate/Handler/Output/array.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/Handler/Output/array.pm',
    'DailyUpdate/Handler/Output/string.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/Handler/Output/string.pm',
    'DailyUpdate/Handler/Output/table.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/Handler/Output/table.pm',
    'DailyUpdate/Handler/Output/thread.pm' =>
        '$(INST_LIBDIR)/DailyUpdate/Handler/Output/thread.pm',
  },
  'EXE_FILES' => [ 'DailyUpdate.pl', 'MakeHandler.pl', ],
  'PREREQ_PM' => { 'HTML::Parser' => 2.06, 'HTML::FormatText' => 0,
                   'Date::Manip' => 0,
                   'HTML::TreeBuilder' => 0, 'URI' => 1.0, 'LWP' => 5.15},
);

# Create new targets to do the permissions and cleanup installation
sub MY::postamble
{
my $returnText =<<EOT
DailyUpdate_Cleanup:
	\@echo 'Finishing up:'
	\@echo '  Updating #! line in DailyUpdate.pl and MakeHandler.pl...'
	\@perl -MExtUtils::Command -e "chmod(0755,'\$(INSTALLSCRIPT)/DailyUpdate.pl')"
	\@perl -MExtUtils::Command -e "chmod(0755,'\$(INSTALLSCRIPT)/MakeHandler.pl')"
EOT
;

# I don't know why the backslash matters on Windows, but it does...
if (($^O eq 'dos') || ($^O eq 'MSWin32'))
{
  $returnText .=<<EOT
	\@perl -ibak -pe "BEGIN { (\$\$FP = '\$(FULLPERL)') =~ tr|\\\\\\\\|/| } s|^#!\\S*perl|#!\$\$FP|" \$(INSTALLSCRIPT)/DailyUpdate.pl
	\@perl -ibak -pe "BEGIN { (\$\$FP = '\$(FULLPERL)') =~ tr|\\\\\\\\|/| } s|^#!\\S*perl|#!\$\$FP|" \$(INSTALLSCRIPT)/MakeHandler.pl
EOT
;
}
else
{
  $returnText .=<<EOT
	\@perl -ibak -pe "BEGIN { (\\\$\$FP = '\$(FULLPERL)') =~ tr|\\\\\\\\|/| } s|^#!\\S*perl|#!\\\$\$FP|" \$(INSTALLSCRIPT)/DailyUpdate.pl
	\@perl -ibak -pe "BEGIN { (\\\$\$FP = '\$(FULLPERL)') =~ tr|\\\\\\\\|/| } s|^#!\\S*perl|#!\\\$\$FP|" \$(INSTALLSCRIPT)/MakeHandler.pl
EOT
;
}

$returnText .=<<EOT
	\@echo '  Setting system-wide DailyUpdate.cfg location in DailyUpdate.pl...'
	\@perl -ibak -pe "s|^use constant SYSCONFIGDIR.*;|use constant SYSCONFIGDIR => \\"$sysconfigdir\\";|" \$(INSTALLSCRIPT)/DailyUpdate.pl
EOT
;

if ($sysconfigdir ne '')
{
  $returnText .=<<EOT
	\@echo '  Copying DailyUpdate.cfg to $sysconfigdir...'
	\@perl -MExtUtils::Command -e mkpath $sysconfigdir
	\@perl -MExtUtils::Command -e cp DailyUpdate.cfg $sysconfigdir
EOT
;
}

if (defined $prefix)
{
  $returnText .=<<EOT;
	\@echo '  Setting modulepath in DailyUpdate.cfg...'
	\@perl -ibak -pe "s|'modulepath' => '.*'|'modulepath' => '\$(INSTALLPRIVLIB)'|" $sysconfigdir/DailyUpdate.cfg
EOT
}

if (($^O eq 'dos') || ($^O eq 'MSWin32'))
{
  $returnText .=<<EOT;
	\@echo '  Setting \$\$ENV{HOME} in DailyUpdate.pl...'
	\@perl -ibak -pe "s|^  \\\$\$home = '.*'|  \\\$\$home = '$home'|" \$(INSTALLSCRIPT)/DailyUpdate.pl
	\@echo '  Setting \$\$ENV{TZ} in DailyUpdate.cfg...'
	\@perl -ibak -pe "s|^\\\$\$ENV.TZ.*if |\\\$\$ENV\\173TZ\\175 = '$timezone' if |" \$(INSTALLSCRIPT)/DailyUpdate.cfg
EOT
}

return $returnText;
}

sub MY::install
{
  package MY;
  my $text = shift->SUPER::install(@_);

  # Write perllocal.pod info in this directory.
#  $text =~ s/\$\(INSTALLARCHLIB\)\/perllocal.pod/\.\/perllocal.pod/sg;

  # Make sure all the install rules depend on DailyUpdate_Cleanup
  $text =~ s/(\binstall[^\n]*::[^\n]*)/$1 DailyUpdate_Cleanup/sg;

  return $text;
}
