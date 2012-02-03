#! /usr/bin/perl
#---------------------------------------------------------------------

use Test::More;

eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage"
    if $@;

plan tests => 4;

TODO: {
  local $TODO = "documentation unfinished";

  pod_coverage_ok('PostScript::File');
}

pod_coverage_ok('PostScript::File::Functions');
pod_coverage_ok('PostScript::File::Metrics');
pod_coverage_ok('PostScript::File::Metrics::Loader');
