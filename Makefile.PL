# use perl                                  -*- mode: Perl; -*-

use strict;

my $home;
if (($^O eq 'dos') || ($^O eq 'MSWin32'))
{
  print "Hey, you're on a DOS or Windows system. You'll need to specify a path where\n";
  print "Daily Update can look for configuration information. (This would normally\n";
  print "be ~ on Unix-like systems, but you don't have $ENV{HOME} defined.)\n";
  print "Be sure to use /, not \\.\n";
  print "=> [C:/DailyUpdate] ";
  $home = <STDIN>;
  $home = "C:/DailyUpdate\n" if $home eq "\n";
  chomp $home;
}

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
    'DailyUpdate/Handler.pm', =>
        '$(INST_LIBDIR)/DailyUpdate/Handler.pm',
    'DailyUpdate/HTMLTools.pm', =>
        '$(INST_LIBDIR)/DailyUpdate/HTMLTools.pm',
    'DailyUpdate/HandlerFactory.pm', =>
        '$(INST_LIBDIR)/DailyUpdate/HandlerFactory.pm',
    'DailyUpdate/OutputFunctions.pm', =>
        '$(INST_LIBDIR)/DailyUpdate/OutputFunctions.pm',
    'DailyUpdate/Parser.pm', =>
        '$(INST_LIBDIR)/DailyUpdate/Parser.pm',
  },
  'EXE_FILES' => [ 'DailyUpdate.pl', 'MakeHandler.pl', ],
  'PREREQ_PM' => { 'HTML::Parser' => 2.06, 'HTML::FormatText' => 0,
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

if (($^O eq 'dos') || ($^O eq 'MSWin32'))
{
  $returnText .=<<EOT
	\@echo '  Setting \$\$ENV{HOME} in DailyUpdate.pl...'
	\@perl -ibak -pe "s|^  # \\\$\$ENV.HOME.*;|  \\\$\$ENV\\173HOME\\175 = '$home';|" \$(INSTALLSCRIPT)/DailyUpdate.pl
EOT
;
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
