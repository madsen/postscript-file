#---------------------------------------------------------------------
package PostScript::File::Metrics::Loader;
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
# ABSTRACT: Load metrics for PostScript fonts using Font::AFM
#---------------------------------------------------------------------

use 5.008;
our $VERSION = '1.06';

use strict;
use warnings;
use Carp 'croak';
use Font::AFM;
use PostScript::File 1.06 ();

our %attribute = qw(
  FullName           full_name
  FamilyName         family
  Weight             weight
  IsFixedPitch       fixed_pitch
  ItalicAngle        italic_angle
  FontBBox           font_bbox
  UnderlinePosition  underline_position
  UnderlineThickness underline_thickness
  Version            version
  CapHeight          cap_height
  XHeight            x_height
  Ascender           ascender
  Descender          descender
);

our @numeric_attributes = qw(
  ascender
  cap_height
  descender
  italic_angle
  underline_position
  underline_thickness
  x_height
);

our @StandardEncoding = qw(
    .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
    .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
    .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
    .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
    space exclam quotedbl numbersign
	dollar percent ampersand quoteright
    parenleft parenright asterisk plus
	comma hyphen period slash
    zero one two three
	four five six seven
    eight nine colon semicolon
	less equal greater question
    at A B C D E F G
    H I J K L M N O
    P Q R S T U V W
    X Y Z bracketleft backslash bracketright asciicircum underscore
    quoteleft a b c d e f g
    h i j k l m n o
    p q r s t u v w
    x y z braceleft bar braceright asciitilde .notdef
    .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
    .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
    .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
    .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
    .notdef exclamdown cent sterling
	fraction yen florin section
    currency quotesingle quotedblleft guillemotleft
	guilsinglleft guilsinglright fi fl
    .notdef endash dagger daggerdbl
	periodcentered .notdef paragraph bullet
    quotesinglbase quotedblbase quotedblright guillemotright
	ellipsis perthousand .notdef questiondown
    .notdef grave acute circumflex tilde macron breve dotaccent
    dieresis .notdef ring cedilla .notdef hungarumlaut ogonek caron
    emdash .notdef .notdef .notdef .notdef .notdef .notdef .notdef
    .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
    .notdef AE .notdef ordfeminine .notdef .notdef .notdef .notdef
    Lslash Oslash OE ordmasculine .notdef .notdef .notdef .notdef
    .notdef ae .notdef .notdef .notdef dotlessi .notdef .notdef
    lslash oslash oe germandbls .notdef .notdef .notdef .notdef
);

our @SymbolEncoding = (
  ('.notdef') x 32,
# \040
  qw(space exclam universal numbersign
	existential percent ampersand suchthat
    parenleft parenright asteriskmath plus
	comma minus period slash
    zero one two three
	four five six seven
    eight nine colon semicolon
	less equal greater question),
# \100
  qw(congruent Alpha Beta Chi
	Delta Epsilon Phi Gamma
    Eta Iota theta1 Kappa
	Lambda Mu Nu Omicron
    Pi Theta Rho Sigma
	Tau Upsilon sigma1 Omega
    Xi Psi Zeta bracketleft
	therefore bracketright perpendicular underscore),
# \140
  qw(radicalex alpha beta chi
	delta epsilon phi gamma
    eta iota phi1 kappa
	lambda mu nu omicron
    pi theta rho sigma
	tau upsilon omega1 omega
    xi psi zeta braceleft
	bar braceright similar .notdef),
# \200
  ('.notdef') x 32,
# \240
  qw(Euro Upsilon1 minute lessequal
	fraction infinity florin club
    diamond heart spade arrowboth
	arrowleft arrowup arrowright arrowdown
    degree plusminus second greaterequal
	multiply proportional partialdiff bullet
    divide notequal equivalence approxequal
	ellipsis arrowvertex arrowhorizex carriagereturn),
# \300
  qw(aleph Ifraktur Rfraktur weierstrass
	circlemultiply circleplus emptyset intersection
    union propersuperset reflexsuperset notsubset
	propersubset reflexsubset element notelement
    angle gradient registerserif copyrightserif
	trademarkserif product radical dotmath
    logicalnot logicaland logicalor arrowdblboth
	arrowdblleft arrowdblup arrowdblright arrowdbldown),
# \340
  qw(lozenge angleleft registersans copyrightsans
	trademarksans summation parenlefttp parenleftex
    parenleftbt bracketlefttp bracketleftex bracketleftbt
	bracelefttp braceleftmid braceleftbt braceex
    .notdef angleright integral integraltp
	integralex integralbt parenrighttp parenrightex
    parenrightbt bracketrighttp bracketrightex bracketrightbt
	bracerighttp bracerightmid bracerightbt .notdef),
);

#=====================================================================
sub load
{
  my ($font, $encodings) = @_;

  my $afm = Font::AFM->new($font) or die "Unable to load metrics for $font";

  unless ($PostScript::File::Metrics::Info{$font}) {
    my %info;
    while (my ($method, $key) = each %attribute) {
      $info{$key} = eval { $afm->$method };
    }

    for (@numeric_attributes) {
      $info{$_} += 0 if defined $info{$_};
    }

    $info{fixed_pitch} = ($info{fixed_pitch} eq 'true' ? 1 : 0);
    $info{font_bbox} = [ map { $_ + 0 } split ' ', $info{font_bbox} ];

    $PostScript::File::Metrics::Info{$font} = \%info;
  } # end unless info has been loaded

  my $wxHash = $afm->Wx;

  foreach my $encoding (@$encodings) {
    my $vector = get_encoding_vector($encoding);

    next if $PostScript::File::Metrics::Metrics{$font}{$encoding};

    my @wx;
    for (0..255) {
      my $name = $vector->[$_];
      if (exists $wxHash->{$name}) {
        push @wx, $wxHash->{$name} + 0;
      } else {
        push @wx, $wxHash->{'.notdef'} + 0;
      }
    } # end for 0..255

    $PostScript::File::Metrics::Metrics{$font}{$encoding} = \@wx;
  } # end foreach $encoding
} # end load

#---------------------------------------------------------------------
sub get_encoding_vector
{
  my ($encoding) = @_;

  return \@StandardEncoding if $encoding eq 'std';
  return \@SymbolEncoding   if $encoding eq 'sym';

  my $name = $PostScript::File::encoding_name{$encoding}
      or die "Unknown encoding $encoding";

  $PostScript::File::encoding_def{$name}
      =~ /\bSTARTDIFFENC\b(.+)\bENDDIFFENC\b/s
          or die "Can't find definition for $encoding";

  my $def = $1;
  $def =~ s/%.*//g;             # Strip comments

  my @vec = @StandardEncoding;

  my $i = 0;
  while ($def =~ /(\S+)/g) {
    my $term = $1;
    if ($term =~ m!^/(.+)!) {
      $vec[$i++] = $1;
    } else {
      $i = $term;
    }
  }

  return \@vec;
} # end get_encoding_vector

#=====================================================================
# Package Return Value:

1;

__END__
