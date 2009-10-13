#! /usr/bin/perl
#---------------------------------------------------------------------
# Copyright 2009 Christopher J. Madsen
#
# Author: Christopher J. Madsen <cjm@pobox.com>
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

use Test::More tests => 6;

use PostScript::File 'pstr';

#=====================================================================
#  Run the tests.

my @realTests  = (
  'Hello, world'  => '(Hello, world)',
  'is ('          => '(is \()',
  "has\n newline" => '(has\n newline)',
);

my @tests = @realTests;

while (@tests) {
  my $in = shift @tests;

  (my $name = $in) =~ s/\s+/ /g;

  is(pstr($in), shift @tests, $name);
} # end while @tests

#---------------------------------------------------------------------
@tests = @realTests;

while (@tests) {
  my $in = shift @tests;

  (my $name = $in) =~ s/\s+/ /g;

  is(PostScript::File->pstr($in), shift @tests, "class method $name");
} # end while @tests
