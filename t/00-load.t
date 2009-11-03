#! /usr/bin/perl
#---------------------------------------------------------------------

use Test::More tests => 3;

BEGIN {
    use_ok('PostScript::File');
    use_ok('PostScript::File::Metrics');
    use_ok('PostScript::File::Metrics::Loader');
}

diag("Testing PostScript::File $PostScript::File::VERSION");
