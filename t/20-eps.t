#!/usr/bin/perl
use strict;
use warnings;

use Test::More;

BEGIN {
  eval "use File::Temp 0.14;";
  plan skip_all => "File::Temp 0.14 required for testing" if $@;

  plan tests => 7;
}

use PostScript::File qw(check_file);
ok(1); # module found

my $ps = new PostScript::File(
    eps => 1,
    headings => 1,
    width => 160,
    height => 112,
    );
isa_ok($ps, 'PostScript::File'); # object created

$ps->add_to_page( <<END_PAGE );
    /Helvetica findfont
    12 scalefont
    setfont
    50 50 moveto
    (hello world) show
END_PAGE
my $page = $ps->get_page_label();
is($page, '1', "page 1");
ok($ps->get_page());

my $dir  = $ARGV[0] || File::Temp->newdir;
my $name = "fi02eps";
$ps->output( $name, $dir );
ok(1); # survived so far
my $file = check_file( "$name.epsf", $dir );
ok($file);
ok(-e $file);
