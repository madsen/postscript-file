#!/usr/bin/perl
use strict;
use warnings;

use Test::More;

BEGIN {
  eval "use File::Temp 0.14;";
  plan skip_all => "File::Temp 0.14 required for testing" if $@;

  plan tests => 5;
}

use PostScript::File 0.08 qw(check_file);
ok(1); # module found

my $ps = new PostScript::File();
isa_ok($ps, 'PostScript::File'); # object created

my $dir  = $ARGV[0] || File::Temp->newdir;
my $name = "fi01simple";
$ps->output( $name, $dir );
ok(1); # survived so far
my $file = check_file( "$name.ps", $dir );
ok($file);
ok(-e $file);
