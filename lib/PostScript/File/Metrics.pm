#---------------------------------------------------------------------
package PostScript::File::Metrics;
#
# Copyright 2009 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 29 Oct 2009
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Metrics for PostScript fonts
#---------------------------------------------------------------------

use 5.008;
our $VERSION = '1.06';

use strict;
use warnings;
use Carp 'croak';
use Encode qw(encode is_utf8);

use PostScript::File 'encode_text'; # Get our encode_text method

our (%Info, %Metrics);

#=====================================================================
# Generate accessor methods:

BEGIN {
  foreach my $attribute (qw(
    full_name
    family
    weight
    fixed_pitch
    italic_angle
    version
  )) {
    eval "sub $attribute { shift->{info}{$attribute} };";
    die $@ if $@;
  }

  foreach my $attribute (qw(
    underline_position
    underline_thickness
    cap_height
    x_height
    ascender
    descender
  )) {
    eval <<"END SUB";
      sub $attribute {
        my \$self = shift;
        my \$v = \$self->{info}{$attribute};
        defined \$v ? \$v * \$self->{factor} : \$v;
      }
END SUB
    die $@ if $@;
  }
} # end BEGIN

#---------------------------------------------------------------------
sub font_bbox
{
  my $self = shift;

  my $bbox = $self->{info}{font_bbox};

  if (1 != (my $f = $self->{factor})) {
    [ map { $_ * $f } @$bbox ];
  } else {
    $bbox;
  }
} # end font_bbox

#---------------------------------------------------------------------
sub size { shift->{size} }
#=====================================================================

=method new

  $metrics = PostScript::File::Metrics->new($font, [$size, [$encoding]])

You would normally use L<PostScript::File/get_metrics> to construct a
Metrics object (because it can get the C<$encoding> from the
document), but it is possible to construct one directly.

C<$size> is the font size in points, and defaults to 1000.

C<$encoding> is the character encoding used by L</width> and L</wrap>.
Valid choices are C<std>, C<sym>, C<cp1252>, and C<iso-8859-1>.  The
default is C<std>, meaning PostScript's StandardEncoding (unless the
C<$font> is Symbol, which uses C<sym>, meaning PostScript's
SymbolEncoding).  Neither C<std> nor C<sym> does any character set
translation.

=cut

sub new
{
  my ($class, $font, $size, $encoding) = @_;

  $encoding ||= ($font eq 'Symbol' ? 'sym' : 'std');

  # Load the metrics if necessary:
  unless ($Metrics{$font}{$encoding}) {
    # First, try to load a pre-compiled package:
    my $package = _get_package_name($font, $encoding);

    unless (do { local $@; eval "require $package; 1" }) {
      # No pre-compiled package, we'll have to read the AFM file:
      require PostScript::File::Metrics::Loader;

      PostScript::File::Metrics::Loader::load($font, [$encoding]);
    } # end unless metrics have been pre-generated
  } # end unless the metrics are loaded

  # Create the Metrics object:
  my $self = bless {
    info     => $Info{$font},
    metrics  => $Metrics{$font}{$encoding},
  }, $class;

  $self->{encoding} = $encoding unless $encoding =~ /^(?:std|sym)$/;
  $self->set_size($size);
} # end new
#---------------------------------------------------------------------

=method set_size

  $metrics->set_size($new_size)

This method sets the font size (in points).  This influences the
attributes that concern dimensions and the string width calculations.
It returns the Metrics object, so you can chain to the next method.

=cut

sub set_size
{
  my ($self, $size) = @_;

  $self->{size} = $size || 1000;

  $self->{factor} = ($size ? $size/1000.0 : 1);

  $self;
} # end set_size
#---------------------------------------------------------------------

=method width

  $width = $metrics->width($string)

This calculates the width of C<$string> (in points) when displayed in
this font at the current size.  If C<$string> has the UTF8 flag set,
it is translated into the font's encoding.  Otherwise, the C<$string>
is expected to be in the correct character set already.  C<$string>
should not contain newlines.

=cut

sub width
{
  my $self = shift; # $string

  return 0.0 unless defined $_[0] and length $_[0];

  my $wx = $self->{metrics};

  my $string = $self->encode_text($_[0]);

  my $width = 0;
  $width += $wx->[$_] for unpack("C*", $string);

  $width * $self->{factor};
} # end width
#---------------------------------------------------------------------

=method wrap

  @lines = $metrics->wrap($width, $text)

This wraps C<$text> into lines of no more than C<$width> points.  If
C<$text> contains newlines, they will also cause line breaks.  If
C<$text> has the UTF8 flag set, it is translated into the font's
encoding.  Otherwise, the C<$text> is expected to be in the correct
character set already.

=cut

sub wrap
{
  my $self  = shift;
  my $width = shift;
  my $text  = $self->encode_text(shift);

  my @lines = '';

  for ($text) {
    if (m/\G[ \t]*\n/gc) {
      push @lines, '';
    } else {
      m/\G(\s*(?:[^-\s]+-*|\S+))/g or last;
      my $word = $1;
    check_word:
      if ($self->width($lines[-1] . $word) <= $width) {
        $lines[-1] .= $word;
      } elsif ($lines[-1] eq '') {
        $lines[-1] = $word;
        warn "$word is too wide for field width $width";
      } else {
        push @lines, '';
        $word =~ s/^\s+//;
        goto check_word;
      }
    } # end else not at LF

    redo;                   # Only the "last" statement above can exit
  } # end for $text

  @lines;
} # end wrap

#---------------------------------------------------------------------
# Return the package in which the font's metrics are stored:

sub _get_package_name
{
  my ($font, $encoding) = @_;

  my $package = $encoding;
  $package =~ s/-/_/g;
  $package .= " $font";
  $package =~ s/\W+/::/g;

  "PostScript::File::Metrics::$package";
} # end _get_package_name

#=====================================================================
# Package Return Value:

1;

__END__

=head1 SYNOPSIS

  use PostScript::File;

  my $ps = PostScript::File->new(reencode => 'cp1252');

  my $metrics = $ps->get_metrics('Helvetica-iso', 9);

  my $width = $metrics->width('Hello, World!');

  my @lines = $metrics->wrap( 72, # wrap it into 1 inch lines
    'This is a long string that will not fit on just one line of text.'
  );

=head1 DESCRIPTION

PostScript::File::Metrics provides a subset of the metrics available
from L<Font::AFM>.  Its reason for existence is that it allows you to
pre-compile the AFM files into Perl modules.  This makes loading them
more efficient, but more importantly, it means you don't have to
install (or configure) Font::AFM.  That's important because the
locations and filenames of AFM files are not very standardized, which
makes configuring Font::AFM quite difficult.

PostScript::File::Metrics includes pre-compiled metrics for the 13
standard PostScript fonts:

  Courier              Helvetica              Times-Roman
  Courier-Bold         Helvetica-Bold         Times-Bold
  Courier-BoldOblique  Helvetica-BoldOblique  Times-BoldItalic
  Courier-Oblique      Helvetica-Oblique      Times-Italic
                                              Symbol

If you need metrics for a font not in that list, you'll need to have
Font::AFM installed and configured.  (You can modify
F<examples/generate_metrics.pl> to create additional pre-compiled
modules, but you'll still have to get Font::AFM working on one
system.)

=head1 ATTRIBUTES

All attributes are read-only, except for C<size>, which can be set
using the C<set_size> method.

=for Pod::Loom-no_sort_attr

=attr size

The current font size in points.  This is not an attribute of the
font, but of this Metrics object.  The attributes that describe the
font's dimensions are adjusted according to this value.

=attr full_name

Unique, human-readable name for an individual font, for instance
"Times Roman".

=attr family

Human-readable name for a group of fonts that are stylistic variants
of a single design. All fonts that are members of such a group should
have exactly the same C<family>. Example of a family name is
"Times".

=attr weight

Human-readable name for the weight, or "boldness", attribute of a font.
Examples are C<Roman>, C<Bold>, C<Medium>.

=attr italic_angle

Angle in degrees counterclockwise from the vertical of the dominant
vertical strokes of the font.  (This is normally <= 0.)

=attr fixed_pitch

1 if the font is a fixed-pitch (monospaced) font.  0 otherwise.

=attr font_bbox

An arrayref of four numbers giving the lower-left x, lower-left y,
upper-right x, and upper-right y of the font bounding box. The font
bounding box is the smallest rectangle enclosing the shape that would
result if all the characters of the font were placed with their
origins coincident at (0,0), and then painted.

=attr cap_height

Usually the y-value of the top of the capital H.
Some fonts, like Symbol, may not define this attribute.

=attr x_height

Typically the y-value of the top of the lowercase x.
Some fonts, like Symbol, may not define this attribute.

=attr ascender

Typically the y-value of the top of the lowercase d.
Some fonts, like Symbol, may not define this attribute.

=attr descender

Typically the y-value of the bottom of the lowercase p.
Some fonts, like Symbol, may not define this attribute.

=attr underline_position

Recommended distance from the baseline for positioning underline
strokes. This number is the y coordinate of the center of the stroke.

=attr underline_thickness

Recommended stroke width for underlining.

=attr version

Version number of the font.

