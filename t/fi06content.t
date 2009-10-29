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
  open(OUT, '>', '/tmp/fi06content.t') or die $!;
  printf OUT "#%s\n\n__DATA__\n", '=' x 69;
} else {
  plan tests => 6;
}

my ($name, %param, @methods);

while (<DATA>) {

  print OUT $_ if $generateResults;

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
      printf OUT "%s---\n", $ps->output;
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
%%PageBoundingBox: 28 28 568 814
%%PageHiResBoundingBox: 28 28 567.27559 813.88976
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
%%PageBoundingBox: 28 28 568 814
%%PageHiResBoundingBox: 28 28 567.27559 813.88976
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
order: 'ascend'
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
%%PageOrder: Ascend
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


:: cp1252
strip: 'comments'
paper: 'US-Letter'
reencode: 'cp1252'
->add_to_page("(\x{201C}Hello, world.\x{201D}) show\n");
===
%!PS-Adobe-3.0
%%Orientation: Portrait
%%DocumentSuppliedResources:
%%+ Win1252_Encoded_Fonts
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
%%BeginResource: Win1252_Encoded_Fonts
/STARTDIFFENC { mark } bind def
/ENDDIFFENC {
counttomark 2 add -1 roll 256 array copy
/TempEncode exch def
/EncodePointer 0 def
{
counttomark -1 roll
dup type dup /marktype eq {
pop pop exit
} {
/nametype eq {
TempEncode EncodePointer 3 -1 roll put
/EncodePointer EncodePointer 1 add def
} {
/EncodePointer exch def
} ifelse
} ifelse
} loop
TempEncode def
} bind def
/Win1252Encoding StandardEncoding STARTDIFFENC
96 /grave
128 /Euro /.notdef /quotesinglbase /florin /quotedblbase
/ellipsis /dagger /daggerdbl /circumflex /perthousand
/Scaron /guilsinglleft /OE /.notdef /Zcaron /.notdef
/.notdef /quoteleft /quoteright /quotedblleft /quotedblright
/bullet /endash /emdash /tilde /trademark /scaron
/guilsinglright /oe /.notdef /zcaron /Ydieresis
/space
/exclamdown /cent /sterling /currency /yen /brokenbar
/section /dieresis /copyright /ordfeminine
/guillemotleft /logicalnot /hyphen /registered
/macron /degree /plusminus /twosuperior
/threesuperior /acute /mu /paragraph /periodcentered
/cedilla /onesuperior /ordmasculine /guillemotright
/onequarter /onehalf /threequarters /questiondown
/Agrave /Aacute /Acircumflex /Atilde /Adieresis
/Aring /AE /Ccedilla /Egrave /Eacute /Ecircumflex
/Edieresis /Igrave /Iacute /Icircumflex /Idieresis
/Eth /Ntilde /Ograve /Oacute /Ocircumflex /Otilde
/Odieresis /multiply /Oslash /Ugrave /Uacute
/Ucircumflex /Udieresis /Yacute /Thorn /germandbls
/agrave /aacute /acircumflex /atilde /adieresis
/aring /ae /ccedilla /egrave /eacute /ecircumflex
/edieresis /igrave /iacute /icircumflex /idieresis
/eth /ntilde /ograve /oacute /ocircumflex /otilde
/odieresis /divide /oslash /ugrave /uacute
/ucircumflex /udieresis /yacute /thorn /ydieresis
ENDDIFFENC
/REENCODEFONT { % /Newfont NewEncoding /Oldfont
findfont dup length 4 add dict
begin
{ % forall
1 index /FID ne
2 index /UniqueID ne and
2 index /XUID ne and
{ def } { pop pop } ifelse
} forall
/Encoding exch def
/BitmapWidths false def
/ExactSize 0 def
/InBetweenSize 0 def
/TransformedChar 0 def
currentdict
end
definefont pop
} bind def
/Courier-iso Win1252Encoding /Courier REENCODEFONT
/Courier-Bold-iso Win1252Encoding /Courier-Bold REENCODEFONT
/Courier-BoldOblique-iso Win1252Encoding /Courier-BoldOblique REENCODEFONT
/Courier-Oblique-iso Win1252Encoding /Courier-Oblique REENCODEFONT
/Helvetica-iso Win1252Encoding /Helvetica REENCODEFONT
/Helvetica-Bold-iso Win1252Encoding /Helvetica-Bold REENCODEFONT
/Helvetica-BoldOblique-iso Win1252Encoding /Helvetica-BoldOblique REENCODEFONT
/Helvetica-Oblique-iso Win1252Encoding /Helvetica-Oblique REENCODEFONT
/Times-Roman-iso Win1252Encoding /Times-Roman REENCODEFONT
/Times-Bold-iso Win1252Encoding /Times-Bold REENCODEFONT
/Times-BoldItalic-iso Win1252Encoding /Times-BoldItalic REENCODEFONT
/Times-Italic-iso Win1252Encoding /Times-Italic REENCODEFONT
/Symbol-iso Win1252Encoding /Symbol REENCODEFONT
%%EndResource
%%EndProlog
%%Page: 1 1
%%PageBoundingBox: 28 28 584 764
%%BeginPageSetup
/pagelevel save def
userdict begin
%%EndPageSetup
(“Hello, world.”) show
%%PageTrailer
end
pagelevel restore
showpage
%%EOF
---
