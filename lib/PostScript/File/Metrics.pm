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
sub new
{
  my ($class, $font, $size, $encoding) = @_;

  $encoding ||= 'std';

  unless ($Metrics{$font}{$encoding}) {
    my $package = _get_package_name($font, $encoding);

    unless (do { local $@; eval "require $package; 1" }) {
      require PostScript::File::Metrics::Loader;

      PostScript::File::Metrics::Loader::load($font, [$encoding]);
    } # end unless metrics have been pre-generated
  } # end unless the metrics are loaded

  my $self = bless {
    info     => $Info{$font},
    metrics  => $Metrics{$font}{$encoding},
  }, $class;

  $self->{encoding} = $encoding unless $encoding =~ /^(?:std|sym)$/;
  $self->set_size($size);
} # end new

#---------------------------------------------------------------------
sub set_size
{
  my ($self, $size) = @_;

  $self->{size} = $size || 1000;

  $self->{factor} = ($size ? $size/1000.0 : 1);

  $self;
} # end set_size

#---------------------------------------------------------------------
sub width
{
  my $self = shift; # $string

  return 0.0 unless defined $_[0] and length $_[0];

  my $wx = $self->{metrics};

  my $string;
  if ($self->{encoding} and is_utf8( $_[0] )) {
    $string = encode($self->{encoding}, $_[0], 0);
  } else {
    $string = $_[0];
  }

  my $width = 0;
  $width += $wx->[$_] for unpack("C*", $string);

  $width * $self->{factor};
} # end width

#---------------------------------------------------------------------
sub wrap
{
  my ($self, $width) = @_; # , $text

  my @lines = '';

  pos($_[2]) = 0;               # Make sure we start at the beginning
  for ($_[2]) {
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
  } # end for $_[2] (the text to wrap)

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

