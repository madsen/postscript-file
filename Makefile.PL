use ExtUtils::MakeMaker;

WriteMakefile(
    NAME		=> 'PostScript::File',
    ABSTRACT_FROM	=> 'File.pm',
    AUTHOR		=> 'Christopher Willmot <chris@willmot.co.uk>',
    VERSION_FROM	=> 'File.pm',
    PREREQ_PM		=> { File::Spec => 0,
			     Sys::Hostname => 0 },
);
