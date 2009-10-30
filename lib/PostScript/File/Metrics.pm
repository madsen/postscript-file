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
    font_bbox
    underline_position
    underline_thickness
    version
    cap_height
    x_height
    ascender
    descender
  )) {
    eval "sub $attribute { shift->{info}{$attribute} };";
    die $@ if $@;
  }
} # end BEGIN

#=====================================================================
sub new
{
  my ($class, $font, $encoding) = @_;

  $encoding ||= 'std';

  unless ($Metrics{$font}{$encoding}) {
    my $package = _get_package_name($font, $encoding);

    unless (do { local $@; eval "require $package; 1" }) {
      require PostScript::File::Metrics::Loader;

      PostScript::File::Metrics::Loader::load($font, [$encoding]);
    } # end unless metrics have been pre-generated
  } # end unless the metrics are loaded

  my %self = (
    info     => $Info{$font},
    metrics  => $Metrics{$font}{$encoding},
  );

  $self{encoding} = $encoding unless $encoding =~ /^(?:std|sym)$/;

  bless \%self, $class;
} # end new

#---------------------------------------------------------------------
sub stringwidth
{
  my $self = shift; # $string, $pointsize

  return 0.0 unless defined $_[0] and length $_[0];

  my $wx = $self->{metrics};

  my $string;
  if ($self->{encoding} and is_utf8( $_[0] )) {
    $string = encode($self->{encoding}, $_[0], 0);
  } else {
    $string = $_[0];
  }

  my $width = 0.0;
  $width += $wx->[$_] for unpack("C*", $string);

  if ($_[1]) {
    $width *= $_[1] / 1000;
  }

  $width;
} # end stringwidth

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

