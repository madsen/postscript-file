#---------------------------------------------------------------------
package PostScript::File::Functions;
#
# Copyright 2012 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created:  2 Feb 2012
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Collection of useful PostScript functions
#---------------------------------------------------------------------

use 5.008;
use strict;
use warnings;

our $VERSION = '2.20';
# This file is part of {{$dist}} {{$dist_version}} ({{$date}})

use Carp qw(croak);
use PostScript::File 2.12 (); # strip method

sub _id_       () { 0 } ## no critic
sub _code_     () { 1 } ## no critic
sub _requires_ () { 2 } ## no critic

#=====================================================================
# Initialization:

sub _init_module
{
  my ($class, $fh) = @_;

  my $function = $class->_functions;
  my @keys;
  my $routine;

  while (<$fh>) {
    if (/^%-+$/) {
      PostScript::File::->strip(all_comments => $routine);
      next unless $routine;
      $routine =~ m!^/(\w+)! or die "Can't find name in $routine";
      push @keys, $1;
      $function->{$1} = [ undef, $routine ];
      $routine = '';
    }

    $routine .= $_;
  } # end while <DATA>

  my $id = 'A' x int(1 + log(@keys) / log(26));

  my $re = join('|', @keys);
  $re = qr/\b($re)\b/;

  for my $name (@keys) {
    my $f = $function->{$name};
    $$f[_id_] = $id++;

    my %req;

    $req{$_} = 1 for $$f[_code_] =~ m/$re/g;
    delete $req{$name};

    $$f[_requires_] = [ keys %req ] if %req;
  } # end for each $f in @keys

  close $fh;

  1;
} # end _init_module

#=====================================================================
sub new
{
  my ($class) = @_;

  # Create the object:
  bless {}, $class;
} # end new

#---------------------------------------------------------------------
{
my %functions;
sub _functions { \%functions }
}

#---------------------------------------------------------------------
sub add
{
  my ($self, @names) = @_;

  my $available = $self->_functions;

  while (@names) {
    my $name = shift @names;

    croak "$name is not an available function" unless $available->{$name};
    $self->{$name} = 1;

    next unless my $need = $available->{$name}[_requires_];
    push @names, grep { not $self->{$_} } @$need;
  } # end while @names to add

  return;
} # end add

#---------------------------------------------------------------------
sub add_to_file
{
  my ($self, $ps, $name) = @_;

  my @list = sort { $a->[_id_] cmp $b->[_id_] }
                  @{ $self->_functions }{ keys %$self };

  my $code = join('', map { $_->[_code_] } @list);

  my $blkid = join('', map { $_->[_id_] } @list);

  unless (defined $name) {
    $name = ref $self;
    $name =~ s/::/_/g;
  }

  #print("$name-$blkid\n\n$code");
  $ps->add_function("$name-$blkid", $code, $self->VERSION);
} # end add_to_file

#=====================================================================
# Package Return Value:

__PACKAGE__->_init_module(\*DATA);

#use YAML::Tiny; print Dump(\%function);

__DATA__

%---------------------------------------------------------------------
% Set the color:  RGBarray|BWnumber setColor

/setColor
{
  dup type (arraytype) eq {
    % We have an array, so it's RGB:
    aload pop
    setrgbcolor
  }{
    % Otherwise, it must be a gray level:
    setgray
  } ifelse
} bind def

%---------------------------------------------------------------------
% Create a rectangular path:  Left Top Right Bottom boxpath

/boxpath
{
  % stack L T R B
  newpath
  2 copy moveto                 % move to BR
  3 index exch lineto	        % line to BL
  % stack L T R
  1 index
  % stack L T R T
  4 2 roll
  % stack R T L T
  lineto                        % line to TL
  lineto                        % line to TR
  closepath
} bind def

%---------------------------------------------------------------------
% Clip to a rectangle:   Left Top Right Bottom clipbox

/clipbox { boxpath clip } bind def

%---------------------------------------------------------------------
% Draw a rectangle:   Left Top Right Bottom drawbox

/drawbox { boxpath stroke } bind def

%---------------------------------------------------------------------
% Fill a box with color:  Left Top Right Bottom Color fillbox

/fillbox
{
  gsave
  setColor
  boxpath
  fill
  grestore
} bind def

%---------------------------------------------------------------------
% Print text centered at a point:  X Y STRING showcenter
%
% Centers text horizontally.  Does not adjust vertical placement.

/showcenter
{
  newpath
  0 0 moveto
  % stack X Y STRING
  dup 4 1 roll                          % Put a copy of STRING on bottom
  % stack STRING X Y STRING
  false charpath flattenpath pathbbox   % Compute bounding box of STRING
  % stack STRING X Y Lx Ly Ux Uy
  pop exch pop                          % Discard Y values (... Lx Ux)
  add 2 div neg                         % Compute X offset
  % stack STRING X Y Ox
  0                                     % Use 0 for y offset
  newpath
  moveto
  rmoveto
  show
} bind def

%---------------------------------------------------------------------
% Print left justified text:  X Y STRING showleft
%
% Does not adjust vertical placement.

/showleft
{
  newpath
  3 1 roll  % STRING X Y
  moveto
  show
} bind def

%---------------------------------------------------------------------
% Print right justified text:  X Y STRING showright
%
% Does not adjust vertical placement.

/showright
{
  newpath
  0 0 moveto
  % stack X Y STRING
  dup 4 1 roll                          % Put a copy of STRING on bottom
  % stack STRING X Y STRING
  false charpath flattenpath pathbbox   % Compute bounding box of STRING
  % stack STRING X Y Lx Ly Ux Uy
  pop exch pop                          % Discard Y values (... Lx Ux)
  add neg                               % Compute X offset
  % stack STRING X Y Ox
  0                                     % Use 0 for y offset
  newpath
  moveto
  rmoveto
  show
} bind def

%---------------------------------------------------------------------
%EOF
