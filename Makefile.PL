use ExtUtils::MakeMaker;

WriteMakefile(
    NAME		=> 'PostScript::File',
    ABSTRACT_FROM	=> 'lib/PostScript/File.pm',
    AUTHOR		=> 'Christopher Willmot <chris@willmot.org.uk>',
    VERSION_FROM	=> 'lib/PostScript/File.pm',
    PREREQ_PM		=> { File::Spec => 0,
			     Sys::Hostname => 0 },
    MAN3PODS		=> 'lib/PostScript/File.pm',
);
