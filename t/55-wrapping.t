#! /usr/bin/perl
#---------------------------------------------------------------------
# Copyright 2011 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 6 Oct 2011
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# Test word wrapping in PostScript::File::Metrics
#---------------------------------------------------------------------

use 5.008;
use strict;
use warnings;

use Test::More 0.88;            # want done_testing

use PostScript::File::Metrics ();

#=====================================================================
sub iName     () { 0 }
sub iText     () { 1 }
sub iExpected () { 2 }

my @tests = (
  [
    "basic",
    "Basic test",
    [
      "Basic test"
    ]
  ],
  [
    "long",
    "This is a long text to be wrapped on four lines",
    [
      "This is a long",
      "text to be",
      "wrapped on",
      "four lines"
    ]
  ],
  [
    "long hyphens",
    "This is-a long-text to be-wrapped with-hyphens",
    [
      "This is\x{ad}a long\x{ad}",
      "text to be\x{ad}",
      "wrapped with\x{ad}",
      "hyphens"
    ]
  ],
  [
    "long dashes",
    "This is\x{2013}a long\x{2014}text to be\x{2013}wrapped with\x{2014}dashes",
    [
      "This is\x{2013}a long\x{2014}",
      "text to be\x{2013}",
      "wrapped with\x{2014}",
      "dashes"
    ]
  ],
  [
    "long slashes",
    "This is/a long/text to be/wrapped with/slashes",
    [
      "This is/a long/",
      "text to be/",
      "wrapped with/",
      "slashes"
    ]
  ],
  [
    "newlines",
    "This is\na long text\nwith\nnewlines to mark most of the places\n\nit should be wrapped.",
    [
      "This is",
      "a long text",
      "with",
      "newlines to",
      "mark most of",
      "the places",
      "",
      "it should be",
      "wrapped."
    ]
  ],
  [
    "non-breaking spaces",
    "This is\240a long\240text to be\240wrapped with non-breaking spaces",
    [
      "This is\x{a0}a",
      "long\x{a0}text to",
      "be\x{a0}wrapped",
      "with non\x{ad}",
      "breaking",
      "spaces"
    ]
  ],
  [
    "negative numbers",
    "This is -123456789 -987654321 -12\x{2212} -34\x{2212} -56\x{2212} -78\x{2212} -90\x{2212} -1234567890",
    [
      "This is",
      "\x{2212}123456789",
      "\x{2212}987654321",
      "\x{2212}12\x{2212} \x{2212}34\x{2212}",
      "\x{2212}56\x{2212} \x{2212}78\x{2212}",
      "\x{2212}90\x{2212}",
      "\x{2212}1234567890"
    ]
  ],
  [
    "zero-width space",
    "This\x{200b}is\x{200b}a\x{200b}long\x{200b}text\x{200b}containing\x{200b}only\x{200b}zero\x{200b}width\x{200b}spaces",
    [
      "Thisisalongtext",
      "containingonly",
      "zerowidth",
      "spaces"
    ]
  ],
  [
    "maxlines 1",
    [
      "This is a long text to be wrapped on only one line",
      {
        maxlines => 1,
        quiet => 1
      }
    ],
    [
      "This is a long text to be wrapped on only one line"
    ]
  ],
  [
    "maxlines 3",
    [
      "This is a long text to be wrapped on only three lines",
      {
        maxlines => 3,
        quiet => 1
      }
    ],
    [
      "This is a long",
      "text to be",
      "wrapped on only three lines"
    ]
  ],
  [
    "ends with newline",
    "newline after\n",
    [
      "newline after"
    ]
  ],
  [
    "only at whitespace",
    [
      "This is-a long-text to be-wrapped with-hyphens",
      {
        chars => ""
      }
    ],
    [
      "This is\x{ad}a",
      "long\x{ad}text to",
      "be\x{ad}wrapped",
      "with\x{ad}hyphens"
    ]
  ],
); # end @tests

#---------------------------------------------------------------------
my $generateResults;

if (@ARGV and $ARGV[0] eq 'gen') {
  # Just output the actual results, so they can be diffed against this file
  $generateResults = 1;
} else {
  plan tests => scalar @tests;
}

my $metrics = PostScript::File::Metrics->new(qw(Helvetica 10 cp1252));

for my $test (@tests) {
  my @got = (ref $test->[iText]
             ? $metrics->wrap(72, @{ $test->[iText] })
             : $metrics->wrap(72,    $test->[iText] ));

  if ($generateResults) {
    $test->[iExpected] = \@got;
  } else {
    is_deeply(\@got, @$test[iExpected, iName]);
  }
} # end for each $test in @tests

#---------------------------------------------------------------------
if ($generateResults) {
  require Data::Dumper;

  my $d = Data::Dumper->new([ \@tests ], ['*tests'])
            ->Indent(1)->Useqq(1)->Quotekeys(0)->Sortkeys(1)->Dump;
  $d =~ s/\]\n\);\n\z/],\n); # end \@tests\n/;

  open(my $out, '>:utf8', '/tmp/55-wrapping.t') or die $!;
  print $out "my $d";
} else {
  done_testing;
}

# Local Variables:
# compile-command: "perl 55-wrapping.t gen"
# End:
