use ExtUtils::MakeMaker;

my %parms = (
    NAME		=> 'PostScript::File',
    ABSTRACT_FROM	=> 'File.pm',
#   AUTHOR		=> 'Christopher Willmot <chris@willmot.co.uk>',
    AUTHOR		=> 'Christopher J. Madsen <perl@cjmweb.net>',
    VERSION_FROM	=> 'File.pm',
    PREREQ_PM		=> { File::Spec => 0,
			     Sys::Hostname => 0 },
);

if ($ExtUtils::MakeMaker::VERSION ge '6.30') {
  $parms{LICENSE} = 'perl';
}

if ($ExtUtils::MakeMaker::VERSION ge '6.46') {
  $parms{META_MERGE} = {
    resources => {
      bugtracker  =>
        'http://rt.cpan.org/Public/Dist/Display.html?Name=PostScript-File',
      license     => 'http://dev.perl.org/licenses/',
      repository  => 'git://github.com/madsen/postscript-file.git',
    }
  };
} # end if MakeMaker 6.46

WriteMakefile(%parms);
