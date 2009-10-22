#! /usr/bin/perl
#---------------------------------------------------------------------
# Copyright 2009 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@pobox.com>
# Created: 21 Oct 2009
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# Test the content of generated PostScript
#---------------------------------------------------------------------

use strict;
use warnings;

use Test::More;

my $diff;
BEGIN { $diff = eval "use Test::Differences; 1" }

use PostScript::File ();

my $generateResults;

if (@ARGV and $ARGV[0] eq 'gen') {
  # Just output the actual results, so they can be diffed against this file
  $generateResults = 1;
  printf "#%s\n\n__DATA__\n", '=' x 69;
} else {
  plan tests => 5;
}

my ($name, %param, @methods);

while (<DATA>) {

  print $_ if $generateResults;

  if (/^(\w+):(.+)/) {
    $param{$1} = eval $2;
    die $@ if $@;
  } # end if constructor parameter (key: value)
  elsif (/^(->.+)/) {
    push @methods, $1;
  } # end if method to call (->method(param))
  elsif ($_ eq "===\n") {
    # Read the expected results:
    my $expected = '';
    while (<DATA>) {
      last if $_ eq "---\n";
      $expected .= $_;
    }

    # Run the test:
    my $ps = PostScript::File->new(%param);

    foreach my $call (@methods) {
      eval '$ps' . $call;
      die $@ if $@;
    } # end foreach $call in @methods

    if ($generateResults) {
      printf "%s---\n", $ps->output;
    } elsif ($diff) {
      eq_or_diff($ps->output, $expected, $name); # if Test::Differences
    } else {
      is($ps->output, $expected, $name); # fall back to Test::More
    }

    # Clean up:
    @methods = ();
    %param = ();
    undef $name;
  } # end elsif expected contents (=== ... ---)
  elsif (/^::\s*(.+)/) {
    $name = $1;
  } # end elsif test name (:: name)
  else {
    die "Unrecognized line $_" if /\S/;
  }
} # end while <DATA>

#=====================================================================

__DATA__

:: no parameters
===
%!PS-Adobe-3.0
%%Orientation: Portrait
%%DocumentSuppliedResources:
%%+ procset PostScript_File
%%Title: ()
%%EndComments
%%BeginProlog
%%BeginProcSet: PostScript_File
/errx 72 def
/erry 72 def
/errmsg (ERROR:) def
/errfont /Courier-Bold def
/errsize 12 def
% Report fatal error on page
% _ str => _
/report_error {
0 setgray
errfont findfont errsize scalefont setfont
errmsg errx erry moveto show
80 string cvs errx erry errsize sub moveto show
stop
} bind def
% postscript errors printed on page
% not called directly
errordict begin
/handleerror {
$error begin
false binary
0 setgray
errfont findfont errsize scalefont setfont
errx erry moveto
errmsg show
errx erry errsize sub moveto
errorname 80 string cvs show
stop
} def
end
%%EndProcSet
%%EndProlog
%%Page: 1 1
%%PageBoundingBox: 28 28 567.27559 813.88976
%%BeginPageSetup
/pagelevel save def
userdict begin
%%EndPageSetup
%%PageTrailer
end
pagelevel restore
showpage
%%EOF
---


:: strip none
strip: 'none'
===
%!PS-Adobe-3.0
%%Orientation: Portrait
%%DocumentSuppliedResources:
%%+ procset PostScript_File
%%Title: ()
%%EndComments
%%BeginProlog
%%BeginProcSet: PostScript_File


/errx 72 def
/erry 72 def
/errmsg (ERROR:) def
/errfont /Courier-Bold def
/errsize 12 def
% Report fatal error on page
% _ str => _
/report_error {
    0 setgray
    errfont findfont errsize scalefont setfont
    errmsg errx erry moveto show
    80 string cvs errx erry errsize sub moveto show
    stop
} bind def

% postscript errors printed on page
% not called directly
errordict begin
    /handleerror {
$error begin
false binary
0 setgray
errfont findfont errsize scalefont setfont
errx erry moveto
errmsg show
errx erry errsize sub moveto
errorname 80 string cvs show
stop
    } def
end


%%EndProcSet




%%EndProlog
%%Page: 1 1
%%PageBoundingBox: 28 28 567.27559 813.88976
%%BeginPageSetup
    /pagelevel save def


    userdict begin

%%EndPageSetup
%%PageTrailer

    end
    pagelevel restore
    showpage
%%EOF
---


:: strip comments
strip: 'comments'
paper: 'US-Letter'
->add_to_page("% strip this\n");
->add_to_page("%%%%%%%%%%%%%\n");
->add_to_page("%------------\n");
===
%!PS-Adobe-3.0
%%Orientation: Portrait
%%DocumentSuppliedResources:
%%+ procset PostScript_File
%%Title: ()
%%EndComments
%%BeginProlog
%%BeginProcSet: PostScript_File
/errx 72 def
/erry 72 def
/errmsg (ERROR:) def
/errfont /Courier-Bold def
/errsize 12 def
/report_error {
0 setgray
errfont findfont errsize scalefont setfont
errmsg errx erry moveto show
80 string cvs errx erry errsize sub moveto show
stop
} bind def
errordict begin
/handleerror {
$error begin
false binary
0 setgray
errfont findfont errsize scalefont setfont
errx erry moveto
errmsg show
errx erry errsize sub moveto
errorname 80 string cvs show
stop
} def
end
%%EndProcSet
%%EndProlog
%%Page: 1 1
%%PageBoundingBox: 28 28 584 764
%%BeginPageSetup
/pagelevel save def
userdict begin
%%EndPageSetup
%%%%%%%%%%%%%
%%PageTrailer
end
pagelevel restore
showpage
%%EOF
---


:: custom paper
paper: '123x456'
===
%!PS-Adobe-3.0
%%Orientation: Portrait
%%DocumentSuppliedResources:
%%+ procset PostScript_File
%%Title: ()
%%EndComments
%%BeginProlog
%%BeginProcSet: PostScript_File
/errx 72 def
/erry 72 def
/errmsg (ERROR:) def
/errfont /Courier-Bold def
/errsize 12 def
% Report fatal error on page
% _ str => _
/report_error {
0 setgray
errfont findfont errsize scalefont setfont
errmsg errx erry moveto show
80 string cvs errx erry errsize sub moveto show
stop
} bind def
% postscript errors printed on page
% not called directly
errordict begin
/handleerror {
$error begin
false binary
0 setgray
errfont findfont errsize scalefont setfont
errx erry moveto
errmsg show
errx erry errsize sub moveto
errorname 80 string cvs show
stop
} def
end
%%EndProcSet
%%EndProlog
%%Page: 1 1
%%PageBoundingBox: 28 28 95 428
%%BeginPageSetup
/pagelevel save def
userdict begin
%%EndPageSetup
%%PageTrailer
end
pagelevel restore
showpage
%%EOF
---


:: multiple comments
paper: 'Letter'
->add_comment("ProofMode: NotifyMe");
->add_comment("Requirements: manualfeed");
->add_comment("DocumentNeededResources:");
->add_comment("+ Paladin");
->add_comment("+ Paladin-Bold");
===
%!PS-Adobe-3.0
%%ProofMode: NotifyMe
%%Requirements: manualfeed
%%DocumentNeededResources:
%%+ Paladin
%%+ Paladin-Bold
%%Orientation: Portrait
%%DocumentSuppliedResources:
%%+ procset PostScript_File
%%Title: ()
%%EndComments
%%BeginProlog
%%BeginProcSet: PostScript_File
/errx 72 def
/erry 72 def
/errmsg (ERROR:) def
/errfont /Courier-Bold def
/errsize 12 def
% Report fatal error on page
% _ str => _
/report_error {
0 setgray
errfont findfont errsize scalefont setfont
errmsg errx erry moveto show
80 string cvs errx erry errsize sub moveto show
stop
} bind def
% postscript errors printed on page
% not called directly
errordict begin
/handleerror {
$error begin
false binary
0 setgray
errfont findfont errsize scalefont setfont
errx erry moveto
errmsg show
errx erry errsize sub moveto
errorname 80 string cvs show
stop
} def
end
%%EndProcSet
%%EndProlog
%%Page: 1 1
%%PageBoundingBox: 28 28 584 764
%%BeginPageSetup
/pagelevel save def
userdict begin
%%EndPageSetup
%%PageTrailer
end
pagelevel restore
showpage
%%EOF
---
