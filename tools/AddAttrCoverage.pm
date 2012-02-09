#---------------------------------------------------------------------
package tools::AddAttrCoverage;
#
# Copyright 2012 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created:  8 Feb 2012
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Prepare docs for PostScript::File
#---------------------------------------------------------------------

our $VERSION = '2.20';

use 5.008;
use Moose 0.65; # attr fulfills requires
use Moose::Autobox;

with(qw(Dist::Zilla::Role::FileMunger));

#=====================================================================
# Pod::Coverage doesn't recognize the way I've documented attribute
# accessors.  Build a Pod::Coverage section that lists them.

sub munge_files
{
  my ($self) = @_;

  # Find lib/PostScript/File.pm:
  my ($file) = $self->zilla->files
                ->grep(sub{ $_->name eq 'lib/PostScript/File.pm' })
                ->flatten;

  $self->log_fatal("Can't find PostScript::File") unless $file;

  # Find the attribute accessor methods:
  my $content = $file->content;

  my %function;

  while ($content =~ m!^=attr(?:-\S+)? (\w+)\n((?:\n| .+\n)+)!mg) {
    my $name = $1;
    my $example = $2;

    $function{$1} = 1 while $example =~ /\b([gs]et_$name)/g;
  } # end while found an attribute

  # Append the list of documented functions:
  my $pod = join("\n", sort keys %function );

  $content .= "\n=for Pod::Coverage\n$pod\n";

  $file->content( $content );
} # end munge_files

#=====================================================================
# Package Return Value:

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__
