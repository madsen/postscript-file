#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use File::Spec ();

BEGIN {
  eval "use File::Temp 0.15 'tempdir';";
  plan skip_all => "File::Temp 0.15 required for testing" if $@;

  plan tests => 8;
}

use PostScript::File qw(check_file);
ok(1); # module found

my $ps = new PostScript::File(
    headings => 1,
    paper => "A5",
    landscape => 1,
    left => 36,
    right => 36,
    top => 72,
    bottom => 72,
    clipping => 1,
    clipcmd => "stroke",
    errors => 1,
    debug => 2,
    );
isa_ok($ps, 'PostScript::File'); # object created

$ps->add_to_page( <<END_PAGE );
    /Helvetica findfont
    12 scalefont
    setfont
    100 150 moveto
    (hello world) show
    111
    222
    (some text)
    [ 33 (in an array) 55 ]
    666
END_PAGE
my $page = $ps->get_page_label();
is($page, '1', "page 1");
ok($ps->get_page());

my $dir  = $ARGV[0] || tempdir(CLEANUP => 1);
my $name = "fi03debug";
my $out  = $ps->output( $name, $dir );
ok(1); # survived so far

is($out, File::Spec->catfile( $dir, "$name.ps" ), 'expected output filename');

my $file = check_file( "$name.ps", $dir );
ok($file);
ok(-e $file);
