#! /usr/bin/perl
#---------------------------------------------------------------------
# Copyright 2009 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@pobox.com>
# Created: 12 Oct 2009
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# Test the pstr function/method
#---------------------------------------------------------------------

use strict;
use warnings;

use Test::More;

use PostScript::File 'pstr';

#=====================================================================
#  Run the tests.

my @realTests  = (
  'Hello, world'  => '(Hello, world)',
  'is ('          => '(is \()',
  "has\n newline" => '(has\n newline)',
  'xxxx ' x 100   => '(' . ('xxxx ' x 48) . "\\\n" .
                           ('xxxx ' x 48) . "x\\\nxxx " .
                           ('xxxx ' x 3) . ')',
  'a         ' x 50 => '(' . ('a         ' x 24) . "\\\n" .
                             ('a         ' x 24) . "a\\\n\\         " .
                             ('a         ' x 1) . ')',
  (grep { $_ } split /\s+/, <<'END BACKSLASHES'),
     has\backslash      (has\\backslash)
     double\\backslash  (double\\\\backslash)
END BACKSLASHES
  "have\n newline"   => '(have\n newline)',
  "have\r\n CRLF"    => '(have\r\n CRLF)',
  "have\t tab"       => '(have\t tab)',
  "have\b backspace" => '(have\b backspace)',
  "have\f form feed" => '(have\f form feed)',
  "have () parens"   => '(have \(\) parens)',
);

plan tests => scalar @realTests;

my @tests = @realTests;

while (@tests) {
  my $in = shift @tests;

  (my $name = $in) =~ s/[\b\s]+/ /g;
  $name = substr($name, 0, 50);

  is(pstr($in), shift @tests, $name);
} # end while @tests

#---------------------------------------------------------------------
@tests = @realTests;

while (@tests) {
  my $in = shift @tests;

  (my $name = $in) =~ s/[\b\s]+/ /g;
  $name = substr($name, 0, 50);

  is(PostScript::File->pstr($in), shift @tests, "class method $name");
} # end while @tests
