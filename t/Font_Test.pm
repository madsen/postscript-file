#---------------------------------------------------------------------
package Font_Test;
#
# Copyright 2009 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 31 Oct 2009
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# Compare our font metrics against Font::AFM
#---------------------------------------------------------------------

use 5.008;
our $VERSION = '1.06';

use strict;
use warnings;
use Exporter 'import';
use Test::More tests => 270;

use PostScript::File::Metrics;

our @EXPORT = qw(test_font);

our %attribute = qw(
  FullName           full_name
  FamilyName         family
  Weight             weight
  IsFixedPitch       fixed_pitch
  ItalicAngle        italic_angle
  FontBBox           font_bbox
  UnderlinePosition  underline_position
  UnderlineThickness underline_thickness
  CapHeight          cap_height
  XHeight            x_height
  Ascender           ascender
  Descender          descender
);
# We don't test this:
#  Version            version

#=====================================================================

sub test_font
{
  my ($font) = @_;

  my $metrics = PostScript::File::Metrics->new($font, undef, 'iso-8859-1');

  isa_ok($metrics, 'PostScript::File::Metrics');

  ok(!$INC{'PostScript/File/Metrics/Loader.pm'},
     'used pre-compiled metrics');

  SKIP: {
    my $testsInBlock = 256 + keys %attribute;

    # Construct the Font::AFM object, or skip the remaining tests:
    eval { require Font::AFM };

    skip "Font::AFM not installed", $testsInBlock if $@;

    my $afm = eval { Font::AFM->new($font) };

    skip "Font::AFM can't find $font.afm", $testsInBlock if $@;

    # Compare the font attributes:
    foreach my $afm_method (sort keys %attribute) {
      my $metrics_method = $attribute{$afm_method};
      my $got = $metrics->$metrics_method;
      $got = "@$got" if $afm_method eq 'FontBBox';
      $got = $got ? 'true' : 'false' if $afm_method eq 'IsFixedPitch';
      is($got, $afm->$afm_method, $afm_method);
    }

    # Compare the character widths:
    my $wx = $afm->latin1_wx_table;

    for my $char (0 .. 255) {
      my $name = sprintf 'width of char \%03o, \x%02X', $char, $char;
      $name = sprintf '%s (%c)', $name, $char
          if $char >= 0x20 and $char < 0x7F;
      is( $metrics->width(pack 'C', $char), $wx->[$char], $name);
    } # end for $char
  } # end SKIP
} # end test_font

#=====================================================================
# Package Return Value:

1;