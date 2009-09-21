use ExtUtils::MakeMaker;

WriteMakefile(
    NAME		=> 'PostScript::File',
    ABSTRACT_FROM	=> 'File.pm',
#   AUTHOR		=> 'Christopher Willmot <chris@willmot.co.uk>',
    AUTHOR		=> 'Christopher J. Madsen <perl@cjmweb.net>',
    VERSION_FROM	=> 'File.pm',
    LICENSE		=> 'perl',
    PREREQ_PM		=> { File::Spec => 0,
			     Sys::Hostname => 0 },
);
