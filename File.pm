package PostScript::File;
use strict;
use warnings;
use File::Spec;
use Sys::Hostname;
require Exporter;
our @ISA = qw(Exporter);

our $VERSION = 0.09;
our @EXPORT_OK = qw(check_tilde check_file incpage_label incpage_roman array_as_string str);

# Prototypes for functions only
 sub incpage_label ($);
 sub incpage_roman ($);
 sub print_file ($$);
 sub check_tilde ($); 
 sub check_file ($;$$);

# global constants
my $rmspace = qr(^\s+);		    # remove leading spaces
my $rmcomment = qr(^\s+\(% .*\)?);  # remove single line comments

=head1 NAME

PostScript::File - Base class for creating Adobe PostScript files

=head1 SYNOPSIS

    use PostScript::File qw(check_tilde check_file
		    incpage_label incpage_roman);

=head2 Simplest
		    
An 'hello world' program:

    use PostScript::File;

    my $ps = new PostScript::File();
    
    $ps->add_to_page( <<END_PAGE );
	/Helvetica findfont 
	12 scalefont 
	setfont
	72 300 moveto
	(hello world) show
    END_PAGE
    
    $ps->output( "~/test" );

=head2 All options

    my $ps = new PostScript::File(
	paper => 'Letter',
	height => 500,
	width => 400,
	bottom => 30,
	top => 30,
	left => 30,
	right => 30,
	clip_command => 'stroke',
	clipping => 1,
	eps => 1,
	dir => '~/foo',
	file => "bar",
	landscape => 0,

	headings => 1,
	reencode => 'ISOLatin1Encoding',
	font_suffix => '-iso',

	errors => 1,
	errmsg => 'Failed:',
	errfont => 'Helvetica',
	errsize => 12,
	errx => 72,
	erry => 300,
	
	debug => 2,
	db_active => 1,
	db_xgap => 120,
	db_xtab => 8,
	db_base => 300,
	db_ytop => 500,
	db_color => '1 0 0 setrgbcolor',
	db_font => 'Times-Roman',
	db_fontsize => 11,
	db_bufsize => 256,
    );

=head1 DESCRIPTION

This module is designed as a supporting part of the PostScript::Graph suite.  For top level modules that output
something useful, see

    PostScript::Graph::Bar
    PostScript::Graph::Stock
    PostScript::Graph::XY

An outline Adobe PostScript file is constructed.  Functions allow access to each of Adobe's Document
Structuring Convention (DSC) sections and control how the pages are constructed.  It is possible to
construct and output files in either normal PostScript (*.ps files) or as Encapsulated Postscript (*.epsf or
*.epsi files).  By default a minimal file is output, but support for font encoding, postscript error reporting and
debugging can be built in if required. 

Documents can typically be built using only these functions:

    new		  The constructor, with many options
    add_function  Add postscript functions to the prolog
    add_to_page	  Add postscript to construct each page 
    newpage	  Begins a new page in the document
    output	  Construct the file and saves it

The rest of the module involves fine-tuning this.  Some settings only really make sense when given once, while
others can control each page independently.  See B<new> for the functions that duplicate option settings, they all
have B<get_> counterparts.  The following provide additional support.

    get/set_bounding_box
    get/set_page_bounding_box
    get/set_page_clipping
    get/set_page_landscape
    set_page_margins
    get_ordinal
    get_pagecount
    draw_bounding_box
    clip_bounding_box

The functions which insert entries into each of the DSC sections all begin with 'add_'.  They also have B<get_>
counterparts.
    
    add_comment
    add_preview
    add_default
    add_resource
    add_function
    add_setup
    add_page_setup
    add_to_page
    add_page_trailer
    add_trailer

Finally, there are a few stand-alone functions.  These are not methods and are available for export if requested.
    
    check_tilde 
    check_file 
    incpage_label 
    incpage_roman

=cut

# define page sizes here (a4, letter, etc)
# should be Properly Cased
our %size = (
    A0                    => '2384 3370',
    A1                    => '1684 2384',
    A2                    => '1191 1684',
    A3                    => "841.88976 1190.5512",
    A4                    => "595.27559 841.88976",
    A5                    => "420.94488 595.27559",
    A6                    => '297 420',
    A7                    => '210 297',
    A8                    => '148 210',
    A9                    => '105 148',

    B0                    => '2920 4127',
    B1                    => '2064 2920',
    B2                    => '1460 2064',
    B3                    => '1032 1460',
    B4                    => '729 1032',
    B5                    => '516 729',
    B6                    => '363 516',
    B7                    => '258 363',
    B8                    => '181 258',
    B9                    => '127 181 ',
    B10                   => '91 127',

    Executive             => '522 756',
    Folio                 => '595 935',
    'Half-Letter'         => '612 397',
    Letter                => "612 792",
    'US-Letter'           => '612 792',
    Legal                 => '612 1008',
    'US-Legal'            => '612 1008',
    Tabloid               => '792 1224',
    'SuperB'              => '843 1227',
    Ledger                => '1224 792',

    'Comm #10 Envelope'   => '297 684',
    'Envelope-Monarch'    => '280 542',
    'Envelope-DL'         => '312 624',
    'Envelope-C5'         => '461 648',

    'EuroPostcard'        => '298 420',
);


# The 13 standard fonts that are available on all PS 1 implementations:
our @fonts = qw(
    Courier
    Courier-Bold
    Courier-BoldOblique
    Courier-Oblique
    Helvetica
    Helvetica-Bold
    Helvetica-BoldOblique
    Helvetica-Oblique
    Times-Roman
    Times-Bold
    Times-BoldItalic
    Times-Italic
    Symbol
);

=head1 CONSTRUCTOR

=cut

sub new
{
    my ($class, @options) = @_;
    my $opt = {};
    if (@options == 1) {
	$opt = $options[0];
    } else {
	%$opt = @options;
    }
    
    my $o = {
	# postscript DSC sections
	Comments    => "",  # must include leading '%%' and end with '\n'
	DocSupplied => "",
	Preview	    => "",
	Defaults    => "",
	Resources   => "",
	Functions   => "",
	Setup	    => "",
	PageSetup   => "",
	Pages	    => [],  # indexed by $o->{p}, 0 based
	PageTrailer => "",
	Trailer     => "",
	
	# internal
	p	    => 0,   # current page (0 based)
	pagecount   => 0,   # number of pages
	page	    => [],  # array of labels, indexed by $o->{p}
	pagelandsc  => [],  # orientation of each page individually
	pageclip    => [],  # clip to pagebbox
	pagebbox    => [],  # array of bbox, indexed by $o->{p}
	bbox	    => [],  # [ x0, y0, x1, y1 ]
    };
    bless $o, $class;

    $o->{eps}	     = defined($opt->{eps})	  ? $opt->{eps}	     : 0;
    $o->{file}	     = defined($opt->{file})	  ? $opt->{file}	     : "";
    $o->{dir}	     = defined($opt->{dir})	  ? $opt->{dir}	     : "";
    $o->set_paper( $opt->{paper} );
    $o->set_width( $opt->{width} );
    $o->set_height( $opt->{height} );
    $o->set_landscape( $opt->{landscape} );
    
    $o->{debug} = $opt->{debug};	# undefined is an option
    if ($o->{debug}) {
	$o->{db_active}   = $opt->{db_active}   || 1;
	$o->{db_bufsize}  = $opt->{db_bufsize}  || 256;
	$o->{db_font}     = $opt->{db_font}     || "Courier";
	$o->{db_fontsize} = $opt->{db_fontsize} || 10;
	$o->{db_ytop}     = $opt->{db_ytop}     || ($o->{bbox}[3] - $o->{db_fontsize} - 6);
	$o->{db_ybase}    = $opt->{db_ybase}    || 6;
	$o->{db_xpos}     = $opt->{db_xpos}     || 6;
	$o->{db_xtab}     = $opt->{db_xtab}     || 10;
	$o->{db_xgap}     = $opt->{db_xgap}     || ($o->{bbox}[2] - $o->{bbox}[0] - $o->{db_xpos})/4;
	$o->{db_color}    = $opt->{db_color}    || "0 setgray";
    }
   
    my $x0 = $o->{bbox}[0] + ($opt->{left} || 0); 
    my $y0 = $o->{bbox}[1] + ($opt->{bottom} || 0); 
    my $x1 = $o->{bbox}[2] - ($opt->{right} || 0);
    my $y1 = $o->{bbox}[3] - ($opt->{top} || 0);
    $o->set_bounding_box( $x0, $y0, $x1, $y1 );
    $o->set_clipping( $opt->{clipping} || 0 );
    
    $o->{title}	     = defined($opt->{title})	     ? $opt->{title}	    : undef;
    $o->{version}    = defined($opt->{version})	     ? $opt->{version}      : undef;
    $o->{langlevel}  = defined($opt->{langlevel})    ? $opt->{langlevel}    : undef;
    $o->{extensions} = defined($opt->{extensions})   ? $opt->{extensions}   : undef;
    $o->{order}	     = defined($opt->{order})	     ? $opt->{order}	    : undef;
    $o->set_page_label( $opt->{page} );
    $o->set_incpage_handler( $opt->{incpage_handler} );
   
    $o->{errx}	     = defined($opt->{errx})	     ? $opt->{erry}	    : 72;
    $o->{erry}	     = defined($opt->{erry})	     ? $opt->{erry}	    : 72;
    $o->{errmsg}     = defined($opt->{errmsg})	     ? $opt->{errmsg}       : "ERROR:";
    $o->{errfont}    = defined($opt->{errfont})	     ? $opt->{errfont}      : "Courier-Bold";
    $o->{errsize}    = defined($opt->{errsize})	     ? $opt->{errsize}      : 12;
    
    $o->{reencode}   = defined($opt->{reencode})     ? $opt->{reencode}     : "";
    $o->{font_suffix} = defined($opt->{font_suffix})  ? $opt->{font_suffix}  : "-iso";
    $o->{clipcmd}    = defined($opt->{clip_command}) ? $opt->{clip_command} : "clip";
    $o->{errors}     = defined($opt->{errors})	     ? $opt->{errors}       : "";
    $o->{headings}   = defined($opt->{headings})     ? $opt->{headings}     : 0;
    $o->set_strip( $opt->{strip} );
   
    $o->newpage( $o->get_page_label() );
    
    return $o;
}

=head2 new( options )

Create a new PostScript::File object, either a set of pages or an Encapsulated PostScript (EPS) file. Options are
hash keys and values.  All values should be in the native postscript units of 1/72 inch.

Example

    $ref = new PostScript::File ( 
		eps => 1,
		landscape => 1,
                width => 216,
                height => 288,
		left => 36,
		right => 44,
		clipping => 1 );

This creates an encapsulated postscript document, 4 by 3 inch pages printing landscape with left and right margins of
around half an inch.  The width is always the shortest side, even in landscape mode.  3*72=216 and 4*72=288.
Being in landscape mode, these would be swapped.  The bounding box used for clipping would then be from
(50,0) to (244,216).

C<options> may be a single hash reference instead of an options list, but the hash must have the same structure.
This is more convenient when used as a base class.

In addition, the following keys are recognized.  

=head2 File size

There are four options which control how much gets put into the resulting file.

=over 4

=head3 debug

=over 6

=item undef

No debug code is added to the file.  Of course there must be no calls to debug functions in the postscript code.

=item 0

B<db_> functions are replaced by dummy functions which do nothing.

=item 1

A range of functions are added to the file to support debugging postscript.  This switch is similar to the 'C'
C<NDEBUG> macro in that debugging statements may be left in the postscript code but their effect is removed.

Of course, being an interpreted language, it is not quite the same as the calls still takes up space - they just
do nothing.  See L</"POSTSCRIPT DEBUGGING SUPPORT"> for details of the functions.

=item 2

Loads the debug functions and gives some reassuring output at the start and a stack dump at the end of each page.

A mark is placed on the stack at the beginning of each page and 'cleartomark' is given at the end, avoiding
potential C<invalidrestore> errors.  Note, however, that if the page does not end with a clean stack, it will fail
when debugging is turned off.

=back

=head3 errors

By default postscript fails silently. Setting this to 1 prints fatal error messages on the bottom left of
the paper.  For user functions, a postscript function B<report_error> is defined.  This expects a message string
on the stack, which it prints before stopping.

=head3 headings

Enable PostScript comments such as the date of creation and user's name.

=head3 reencode

Requests that a font re-encode function be added and that the 13 standard PostScript fonts get re-encoded in the
specified encoding. The only recognized value so far is 'ISOLatin1Encoding' which selects the iso8859-1 encoding and fits most of
western Europe, including the Scandinavia.

=back

=head2 Initialization

There are a few initialization settings that are only relevant when the file object is constructed.

=over 4

=head3 bottom

The margin in from the paper's bottom edge, specifying the non-printable area.
Remember to specify C<clipping> if that is what is wanted.

=head3 clip_command

The bounding box is used for clipping if this is set to "clip" or is drawn with "stroke".  This also makes the
whole page area available for debugging output.  (Default: "clip").

=head3 clipping

Set whether printing will be clipped to the file's bounding box. (Default: 0)

=head3 dir

An optional directory for the output file.  See </set_filename>.

=head3 eps

Set to 1 to produce Encapsulated PostScript.  B<get_eps> returns the value set here.  (Default: 0)

=head3 file

The name of the output file.  See </set_filename>.

=head3 font_suffix

This string is appended to each font name as it is reencoded.  (Default: "-iso")

The standard fonts are named Courier, Courier-Bold, Courier-BoldOblique, Courier-Oblique, Helvetica,
Helvetica-Bold, Helvetica-BoldOblique, Helvetica-Oblique, Times-Roman, Times-Bold, Times-BoldItalic, Times-Italic,
and Symbol.  The string value is appended to these to make the new names.

Example

    $ps = new PostScript::File( 
		font_suffix => "-iso",
		reencode => "ISOLatin1Encoding"
	    );
	    
"Courier" still has the standard mapping while "Courier-iso" includes the additional European characters.

=head3 height

Set the page height, the longest edge of the paper.  (Default taken from C<paper>)

The paper size is set to "Custom".  B<get_width> and B<get_height> return the values set here.

=head3 landscape

Set whether the page is oriented horizontally (C<1>) or vertically (C<0>).  (Default: 0)

In landscape mode the coordinates are rotated 90 degrees and the origin moved to the bottom left corner.  Thus the
coordinate system appears the same to the user, with the origin at the bottom left.

=head3 left

The margin in from the paper's left edge, specifying the non-printable area.
Remember to specify C<clipping> if that is what is wanted.

=head3 paper

Set the paper size of each page.  A document can be created using a standard paper size without
having to remember the size of paper using PostScript points. Valid choices are currently A0, A1, A2, A3, A4, A5,
A6, A7, A8, A9, B0, B1, B2, B3, B4, B5, B6, B7, B8, B9, B10, Executive, Folio, 'Half-Letter', Letter, 'US-Letter',
Legal, 'US-Legal', Tabloid, 'SuperB', Ledger, 'Comm #10 Envelope', 'Envelope-Monarch', 'Envelope-DL',
'Envelope-C5', 'EuroPostcard'.  (Default: "A4")

This also sets C<width> and C<height>.  B<get_paper> returns the value set here.

=head3 right

The margin in from the paper's right edge.  It is a positive offset, so C<right=36> will leave a half inch no-go
margin on the right hand side of the page.  Remember to specify C<clipping> if that is what is wanted.

=head3 top

The margin in from the paper's top edge.  It is a positive offset, so C<top=36> will leave a half inch no-go
margin at the top of the page.  Remember to specify C<clipping> if that is what is wanted.

=head3 width

Set the page width, the shortest edge of the paper.  (Default taken from C<paper>)

=back

=head2 Debugging support 

This makes most sense in the postscript code rather than perl.  However, it is convenient to be able to set
defaults for the output position and so on.  See L</"POSTSCRIPT DEBUGGING SUPPORT"> for further details.

=over 4

=head3 db_active

Set to 0 to temporarily suppress the debug output.  (Default: 1)

=head3 db_base

Debug printing will not occur below this point.  (Default: 6)

=head3 db_bufsize

The size of string buffers used.  Output must be no longer than this.  (Default: 256)

=head3 db_color

This is the whole postscript command (with any parameters) to specify the colour of the text printed by the debug
routines.  (Default: "0 setgray")

=head3 db_font

The name of the font to use.  (Default: "Courier")

=head3 db_fontsize

The size of the font.  Postscript uses its own units, but they are almost points.  (Default: 10)

=head3 db_xgap

Typically, the output comprises single values such as a column showing the stack contents.  C<db_xgap> specifies
the width of each column.  By default, this is calculated to allow 4 columns across the page.

=head3 db_xpos

The left edge, where debug output starts.  (Default: 6)

=head3 db_xtab

The amount indented by C<db_indent>.  (Default: 10)

=head3 db_ytop

The top line of debugging output.  Defaults to 6 below the top of the page.

=back

=head2 Error handling

If C<errors> is set, the position of any fatal error message can be controlled with the following options.  Each
value is placed into a postscript variable of the same name, so they can be overridden from within the code if
necessary.

=over 4

=head3 errfont

The name of the font used to show the error message.  (Default: "Courier-Bold")

=head3 errmsg

The error message comprises two lines.  The second is the name of the postscript error.  This sets the first line.
(Default: "ERROR:")

=head3 errsize

Size of the error message font.  (Default: 12)

=head3 errx

X position of the error message on the page.  (Default: (72))

=head3 erry

Y position of the error message on the page.  (Default: (72))

=back

=head2 Document structure

There are options which only affect the DSC comments.  They all have B<get_> functions which return the
values set here, e.g. B<get_title> returns the value given to the title option.

=over 4

=head3 extensions

Declare and PostScript language extensions that need to be available.  (No default)

=head3 langlevel

Set the PostScript language level.  (No default)

=head3 order

Set the order the pages have been defined.  It should one of "ascend", "descend" or "special" if a document
manager must not reorder the pages.  (No default)

=head3 title

Set the document's title as recorded in PostScript's Document Structuring Conventions.  (No default)

=head3 version

Set the document's version as recorded in PostScript's Document Structuring Conventions.  This should be a string
with a major, minor and revision numbers.  For example "1.5 8" signifies revision 8 of version 1.5.  (No default)

=back

=head2 Miscellaneous

A few options that may be changed between pages or set here for the first page.

=over 4

=head3 incpage_handler

Set the initial value for the function which increments page labels.  See L</set_incpage_handler>.

=head3 page

Set the label (text or number) for the initial page.  See L</set_page_label>.  (Default: "1")

=head3 strip

Set whether the postscript code is filtered.  C<space> strips leading spaces so the user can indent freely
without increasing the file size.  C<comments> remove lines beginning with '%' as well.  (Default: "space")

=back

=cut

=head1 MAIN METHODS

=cut

sub newpage {
    my ($o, $page) = @_;
    my $oldpage = $o->{page}[$o->{p}];
    my $newpage = defined($page) ? $page : &{$o->{incpage}}($oldpage);
    my $p = $o->{p} = $o->{pagecount}++;
    $o->{page}[$p] = $newpage;
    $o->{pagebbox}[$p] = [ @{$o->{bbox}} ];
    $o->{pageclip}[$p] = $o->{clipping};
    $o->{pagelandsc}[$p] = $o->{landscape};
    $o->{Pages}->[$p] = "";
}

=head2 newpage( [page] )

Generate a new PostScript page, unless in a EPS file when it is ignored.  

If C<page> is not specified the page number is increased each time a new page is requested.

C<page> can be a string or a number.  If anything other than a simple integer, you probably should register
your own counting function with B<set_incpage_handler>.  Of course there is no need to do this if a page string is
given to every B<newpage> call.

=cut

sub pre_pages {
    my ($o, $landscape, $clipping, $filename) = @_;
    # Thanks to Johan Vromans for the ISOLatin1Encoding.
    my $fonts = "";
    if ($o->{reencode}) {
	$o->{DocSupplied} .= "\%\%+ Encoded_Fonts\n";
	my $encoding = $o->{reencode};
	my $ext = $o->{font_suffix};
	($fonts .= <<END_FONTS) =~ s/$o->{strip}//gm; 
	\%\%BeginResource: Encoded_Fonts
	    /STARTDIFFENC { mark } bind def
	    /ENDDIFFENC { 

	    % /NewEnc BaseEnc STARTDIFFENC number or glyphname ... ENDDIFFENC -
		counttomark 2 add -1 roll 256 array copy
		/TempEncode exch def
		
		% pointer for sequential encodings
		/EncodePointer 0 def
		{
		    % Get the bottom object
		    counttomark -1 roll
		    % Is it a mark?
		    dup type dup /marktype eq {
			% End of encoding
			pop pop exit
		    } {
			/nametype eq {
			% Insert the name at EncodePointer 

			% and increment the pointer.
			TempEncode EncodePointer 3 -1 roll put
			/EncodePointer EncodePointer 1 add def
			} {
			% Set the EncodePointer to the number
			/EncodePointer exch def
			} ifelse
		    } ifelse
		} loop	

		TempEncode def
	    } bind def

	    % Define ISO Latin1 encoding if it doesnt exist
	    /ISOLatin1Encoding where {
	    %	(ISOLatin1 exists!) =
		pop
	    } {
		(ISOLatin1 does not exist, creating...) =
		/ISOLatin1Encoding StandardEncoding STARTDIFFENC
		    144 /dotlessi /grave /acute /circumflex /tilde 
		    /macron /breve /dotaccent /dieresis /.notdef /ring 
		    /cedilla /.notdef /hungarumlaut /ogonek /caron /space 
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
	    } ifelse

	    % Name: Re-encode Font
	    % Description: Creates a new font using the named encoding. 

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
		    % defs for DPS
		    /BitmapWidths false def
		    /ExactSize 0 def
		    /InBetweenSize 0 def
		    /TransformedChar 0 def
		    currentdict
		end
		definefont pop
	    } bind def

	    % Reencode the std fonts: 
END_FONTS
	for my $font (@fonts) {
	    $fonts .= "/${font}$ext $encoding /$font REENCODEFONT\n";
	}
	$fonts .= "\%\%EndResource";
    }
 
    # Prepare the postscript file
    my $user = getlogin() || (getpwuid($<))[0] || "Unknown";
    my $hostname = hostname();
    my $postscript = $o->{eps} ? "\%!PS-Adobe-3.0 EPSF-3.0\n" : "\%!PS-Adobe-3.0\n";
    if ($o->{eps}) {
	($postscript .= <<END_EPS) =~ s/$o->{strip}//gm;
	\%\%BoundingBox: $o->{bbox}[0] $o->{bbox}[1] $o->{bbox}[2] $o->{bbox}[3] 
END_EPS
    }
    if ($o->{headings}) {
	($postscript .= <<END_TITLES) =~ s/$o->{strip}//gm;
	\%\%For: $user\@$hostname
	\%\%Creator: Perl module ${\( ref $o )} v$PostScript::File::VERSION
	\%\%CreationDate: ${\( scalar localtime )}
END_TITLES
	($postscript .= <<END_PS_ONLY) =~ s/$o->{strip}//gm if (not $o->{eps});
	\%\%DocumentMedia: $o->{paper} $o->{width} $o->{height} 80 ( ) ( )
END_PS_ONLY
    }

    $o->{title} = "($filename)" unless $o->{title};
    $postscript .= $o->{Comments} if ($o->{Comments});
    $postscript .= "\%\%Orientation: ${\( $o->{landscape} ? 'Landscape' : 'Portrait' )}\n";
    $postscript .= "\%\%DocumentSuppliedResources:\n$o->{DocSupplied}" if ($o->{DocSupplied});
    $postscript .= "\%\%Title: $o->{title}\n";
    $postscript .= "\%\%Version: $o->{version}\n" if ($o->{version});
    $postscript .= "\%\%Pages: $o->{pagecount}\n" if ((not $o->{eps}) and ($o->{pagecount} > 1));
    $postscript .= "\%\%Order: $o->{order}\n" if ((not $o->{eps}) and ($o->{order}));
    $postscript .= "\%\%Extensions: $o->{extensions}\n" if ($o->{extensions});
    $postscript .= "\%\%LanguageLevel: $o->{langlevel}\n" if ($o->{langlevel});
    $postscript .= "\%\%EndComments\n";

    $postscript .= $o->{Preview} if ($o->{Preview});
    
    ($postscript .= <<END_DEFAULTS) =~ s/$o->{strip}//gm if ($o->{Defaults});
	\%\%BeginDefaults
	    $o->{Defaults}
	\%\%EndDefaults
END_DEFAULTS
   
    my $landscapefn = "";
    ($landscapefn .= <<END_LANDSCAPE) =~ s/$o->{strip}//gm if ($landscape);
    		% Rotate page 90 degrees
		% _ => _
		/landscape {
		    $o->{width} 0 translate
		    90 rotate
		} bind def
END_LANDSCAPE

    my $clipfn = "";
    ($clipfn .= <<END_CLIPPING) =~ s/$o->{strip}//gm if ($clipping);
    		% Draw box as clipping path
		% x0 y0 x1 y1 => _
		/cliptobox {
		    4 dict begin
		    gsave
		    0 setgray
		    0.5 setlinewidth
		    /y1 exch def /x1 exch def /y0 exch def /x0 exch def
		    newpath
		    x0 y0 moveto x0 y1 lineto x1 y1 lineto x1 y0 lineto
		    closepath $o->{clipcmd}
		    grestore
		    end
		} bind def
END_CLIPPING
	
    my $errorfn = "";
    ($errorfn .= <<END_ERRORS) =~ s/$o->{strip}//gm if ($o->{errors});
	/errx $o->{errx} def
	/erry $o->{erry} def
	/errmsg ($o->{errmsg}) def
	/errfont /$o->{errfont} def
	/errsize $o->{errsize} def
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
		\$error begin
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
END_ERRORS

    my $debugfn = "";
    ($debugfn .= <<END_DEBUG_ON) =~ s/$o->{strip}//gm if ($o->{debug});
	/debugdict 25 dict def
	debugdict begin
	
	% _ db_newcol => _
	/db_newcol {
	    debugdict begin
		/db_ypos db_ytop def 
		/db_xpos db_xpos db_xgap add def 
	    end
	} bind def

	% _ db_down => _
	/db_down {
	    debugdict begin
		db_ypos db_ybase gt {
		    /db_ypos db_ypos db_ygap sub def 
		}{ 
		    db_newcol
		} ifelse
	    end
	} bind def

	% _ db_indent => _
	/db_indent {
	    debug_dict begin
		/db_xpos db_xpos db_xtab add def
	    end
	} bind def

	% _ db_unindent => _
	/db_unindent {
	    debugdict begin
		/db_xpos db_xpos db_xtab sub def
	    end
	} bind def

	% _ (msg) db_show => _
	/db_show {
	    debugdict begin
		db_active 0 ne {
		    gsave
		    newpath
		    $o->{db_color}
		    /$o->{db_font} findfont $o->{db_fontsize} scalefont setfont
		    db_xpos db_ypos moveto
		    dup type 
		    dup (arraytype) eq {
			pop db_array
		    }{
			dup (marktype) eq {
			    pop pop (--mark--) $o->{db_bufsize} string cvs show 
			}{
			    pop $o->{db_bufsize} string cvs show 
			} ifelse
			db_down
		    } ifelse
		    stroke
		    grestore
		}{ pop } ifelse
	    end
	} bind def
	
	% _ n (str) db_nshow => _
	/db_nshow {
	    debugdict begin
		db_show
		/db_num exch def
		db_num count gt {
		    (Not enough on stack) db_show
		}{
		    db_num { 
			dup db_show
			db_num 1 roll    
		    } repeat
		    (----------) db_show
		} ifelse
	    end
	} bind def

	% _ db_stack => _
	/db_stack {
	    count 0 gt {
		count
		$o->{debug} 2 ge {
		    1 sub
		} if
		(The stack holds...) db_nshow
	    } {
		(Empty stack) db_show
	    } ifelse
	} bind def
      
	% _ any db_one => _
	/db_one {
	    debugdict begin
		db_temp cvs
		dup length exch
		db_buf exch db_bpos exch putinterval
		/db_bpos exch db_bpos add def
	    end
	} bind def
	
	% _ [array] db_print => _
	/db_print {
	    debugdict begin
		/db_temp $o->{db_bufsize} string def
		/db_buf $o->{db_bufsize} string def
		0 1 $o->{db_bufsize} sub 1 { db_buf exch 32 put } for
		/db_bpos 0 def
		{   
		    db_one
		    ( ) db_one
		} forall
		db_buf db_show
	    end
	} bind def

	% _ [array] db_array => _
	/db_array {
	    mark ([) 2 index aload pop (]) ] db_print pop
	} bind def
	
	% _ x y (str) db_point => _ x y
	/db_point {
	    [ 1 index (\\() 5 index (,) 6 index (\\)) ] db_print
	    pop
	} bind def
	
	/db_active $o->{db_active} def
	/db_ytop  $o->{db_ytop} def
	/db_ybase $o->{db_ybase} def
	/db_xpos  $o->{db_xpos} def
	/db_xtab  $o->{db_xtab} def
	/db_xgap  $o->{db_xgap} def
	/db_ygap  $o->{db_fontsize} def
	/db_ypos  $o->{db_ytop} def
	end
END_DEBUG_ON

    ($debugfn .= <<END_DEBUG_OFF) =~ s/$o->{strip}//gm if (defined($o->{debug}) and not $o->{debug});
	% Define out the db_ functions
	/debugdict 25 dict def
	debugdict begin
	/db_newcol { } bind def
	/db_down { } bind def
	/db_indent { } bind def
	/db_unindent { } bind def
	/db_show { pop } bind def
	/db_nshow { pop pop } bind def
	/db_stack { } bind def
	/db_print { pop } bind def
	/db_array { pop } bind def
	/db_point { pop pop pop } bind def
	end
END_DEBUG_OFF

    my $supplied = "";
    if ($landscapefn or $clipfn or $errorfn or $debugfn) {
	$o->{DocSupplied} .= "\%\%+ PostScript_File\n";
	($supplied .= <<END_DOC_SUPPLIED) =~ s/$o->{strip}//gm;
	    \%\%BeginProcSet: PostScript_File
		$landscapefn
		$clipfn
		$errorfn
		$debugfn
	    \%\%EndProcSet
END_DOC_SUPPLIED
    }

    ($postscript .= <<END_PROLOG) =~ s/$o->{strip}//gm;
	\%\%BeginProlog
	    $supplied
	    $fonts
	    $o->{Resources}
	    $o->{Functions}
	\%\%EndProlog
END_PROLOG

    ($postscript .= <<END_SETUP) =~ s/$o->{strip}//gm if ($o->{Setup});
	\%\%BeginSetup
	    $o->{Setup}
	\%\%EndSetup
END_SETUP
    return $postscript;
}
# Internal method, used by output()

sub post_pages {
    my $o = shift;
    my $postscript = "";
    
    ($postscript .= <<END_TRAILER) =~ s/$o->{strip}//gm if ($o->{Trailer});
	\%\%Trailer
	$o->{Trailer}
END_TRAILER

    $postscript .= "\%\%EOF\n";

    return $postscript;
}
# Internal method, used by output()

sub print_file ($$) {
    my($filename, $contents) = @_;
    if ($filename) {
	open(OUTFILE, ">", $filename) or die "Unable to write to \'$filename\' : $!\nStopped";
	print OUTFILE $contents;
	close OUTFILE;
    } else {
	print $contents, "\n";
    }
}
# Internal function, used by output()
# Expects file name and contents

sub output {
    my ($o, $filename, $dir) = @_;
    $o->set_filename($filename, $dir) if (defined $filename);

    my ($debugbegin, $debugend) = ("", "");
    if (defined $o->{debug}) {
	$debugbegin = "debugdict begin\nuserdict begin";
	$debugend   = "end\nend";
	if ($o->{debug} >= 2) {
	    $debugbegin = <<END_DEBUG_BEGIN;
		debugdict begin 
		    userdict begin
			mark 
			(Start of page) db_show
END_DEBUG_BEGIN
	    $debugend = <<END_DEBUG_END;
			(End of page) db_show 
			db_stack 
			cleartomark
		    end
		end
END_DEBUG_END
	}	
    } else {
	$debugbegin = "userdict begin";
	$debugend   = "end";
    }
    
    if ($o->{eps}) {
	my $p = 0;
	do {
	    my $epsfile = "";
	    if ($o->{filename}) {
		$epsfile = ($o->{pagecount} > 1) ? "$o->{filename}-$o->{page}[$p]"
					   : "$o->{filename}";
		$epsfile .= $o->{Preview} ? ".epsi" : ".epsf";
	    }
	    my $postscript = "";
	    my $page = $o->{page}->[$p];
	    my @pbox = $o->get_page_bounding_box($page);
	    $o->set_bounding_box(@pbox);
	    $postscript .= $o->pre_pages($o->{pagelandsc}[$p], $o->{pageclip}[$p], $epsfile);
	    $postscript .= "landscape\n" if ($o->{pagelandsc}[$p]);
	    $postscript .= "$pbox[0] $pbox[1] $pbox[2] $pbox[3] cliptobox\n" if ($o->{pageclip}[$p]);
	    $postscript .= "$debugbegin\n";
	    $postscript .= $o->{Pages}->[$p];
	    $postscript .= "$debugend\n";
	    $postscript .= $o->post_pages(); 

	    print_file( $epsfile, $postscript );
	    
	    $p++;
	} while ($p < $o->{pagecount});
    } else {
	my $landscape = $o->{landscape};
	foreach my $pl (@{$o->{pagelandsc}}) {
	    $landscape |= $pl;
	}
	my $clipping = $o->{clipping};
	foreach my $cl (@{$o->{pageclip}}) {
	    $clipping |= $cl;
	}
	my $psfile = $o->{filename} ? "$o->{filename}.ps" : "";
	my $postscript = $o->pre_pages($landscape, $clipping, $psfile);
	for (my $p = 0; $p < $o->{pagecount}; $p++) {
	    my $page = $o->{page}->[$p];
	    my @pbox = $o->get_page_bounding_box($page);
	    my ($landscape, $pagebb);
	    if ($o->{pagelandsc}[$p]) {
		$landscape = "landscape";
		$pagebb = "\%\%PageBoundingBox: $pbox[1] $pbox[0] $pbox[3] $pbox[2]";
	    } else {
		$landscape = "";
		$pagebb = "\%\%PageBoundingBox: $pbox[0] $pbox[1] $pbox[2] $pbox[3]";
	    }
	    my $cliptobox = $o->{pageclip}[$p] ? "$pbox[0] $pbox[1] $pbox[2] $pbox[3] cliptobox" : "";
	    ($postscript .= <<END_PAGE_SETUP) =~ s/$o->{strip}//gm;
		\%\%Page: $o->{page}->[$p] ${\($p+1)}
		$pagebb
		\%\%BeginPageSetup
		    /pagelevel save def
		    $landscape
		    $cliptobox
		    $debugbegin
		    $o->{PageSetup}
		\%\%EndPageSetup
END_PAGE_SETUP
	    $postscript .= $o->{Pages}->[$p];
	    ($postscript .= <<END_PAGE_TRAILER) =~ s/$o->{strip}//gm;
		\%\%PageTrailer
		    $o->{PageTrailer}
		    $debugend
		    pagelevel restore
		    showpage
END_PAGE_TRAILER
	}
	$postscript .= $o->post_pages();
	print_file( $psfile, $postscript );
    }
}

=head2 output( [filename [, dir]] )

Writes the current PostScript out to file.  It is printed to STDOUT if no filename has been given either here, to
B<new> or B<set_filename>.

Use this option whenever output is required to disk. The current PostScript document in memory is not cleared, and
can still be extended.

=cut

=head1 ACCESS METHODS

Use these B<get_> and B<set_> methods to access a PostScript::File object's data. 

=cut

sub get_filename { 
    my $o = shift; 
    return $o->{filename}; 
}

sub set_filename { 
    my ($o, $filename, $dir) = @_;
    $o->{filename} = $filename ? check_file($filename, $dir) : "";
}

=head2 get_filename()

=head2 set_filename( file, [dir] )

=over 4

=item C<file>

An optional fully qualified path-and-file, a simple file name, or "" which stands for the special file
File::Spec->devnull().

=item C<dir>

An optional directory C<dir>.  If present (and C<file> is not already an absolute path), it is prepended to
C<file>.

=back

Specify the root file name for the output file(s) and ensure the resulting absolute path exists.  This should not
include any extension. C<.ps> will be added for ordinary postscript files.  EPS files have an extension of
C<.epsf> without or C<.epsi> with a preview image.

If C<eps> has been set, multiple pages will have the page label appendend to the file name.

Example

    $ps->new PostScript::File( eps => 1 );
    $ps->set_filename( "pics", "~/book" );
    $ps->newpage("vi");
	... draw page
    $ps->newpage("7");
	... draw page
    $ps->newpage();
	... draw page
    $ps->output();

The three pages for user 'chris' on a unix system would be:
    
    /home/chris/book/pics-vi.epsf
    /home/chris/book/pics-7.epsf
    /home/chris/book/pics-8.epsf

It would be wise to use B<set_page_bounding_box> explicitly for each page if using multiple pages in EPS files.

=cut

sub get_eps { my $o = shift; return $o->{eps}; }

sub get_paper { 
    my $o = shift; 
    return $o->{paper}; 
}

sub set_paper { 
    my $o = shift;
    my $paper = shift || "A4"; 
    my ($width, $height) = split(/\s+/, $size{ucfirst(lc $paper)});
    if ($height) {
	$o->{paper} = $paper;
	$o->{width} = $width;
	$o->{height} = $height;
	if ($o->{landscape}) {
	    $o->{bbox}[0] = 0;
	    $o->{bbox}[1] = 0;
	    $o->{bbox}[2] = $height;
	    $o->{bbox}[3] = $width;
	} else {
	    $o->{bbox}[0] = 0;
	    $o->{bbox}[1] = 0;
	    $o->{bbox}[2] = $width;
	    $o->{bbox}[3] = $height;
	}
    }
}

sub get_width { 
    my $o = shift; 
    return $o->{width}; 
}

sub set_width { 
    my ($o, $width) = @_;
    if (defined($width) and ($width+0)) {
	$o->{width} = $width; 
	$o->{paper} = "Custom";
	if ($o->{landscape}) {
	    $o->{bbox}[1] = 0;
	    $o->{bbox}[3] = $width;
	} else {
	    $o->{bbox}[0] = 0;
	    $o->{bbox}[2] = $width;
	}
    }
}

sub get_height { 
    my $o = shift; 
    return $o->{height}; 
}
sub set_height { 
    my ($o, $height) = @_; 
    if (defined($height) and ($height+0)) {
	$o->{height} = $height; 
	$o->{paper} = "Custom";
	if ($o->{landscape}) {
	    $o->{bbox}[0] = 0;
	    $o->{bbox}[2] = $height;
	} else {
	    $o->{bbox}[1] = 0;
	    $o->{bbox}[3] = $height;
	}
    }
}

sub get_landscape { 
    my $o = shift; 
    return $o->{landscape}; 
}

sub set_landscape {
    my $o = shift;
    my $landscape = shift || 0;
    $o->{landscape} = 0 unless (defined $o->{landscape}); 
    if ($o->{landscape} != $landscape) {
	$o->{landscape} = $landscape;
	($o->{bbox}[0], $o->{bbox}[1]) = ($o->{bbox}[1], $o->{bbox}[0]);
	($o->{bbox}[2], $o->{bbox}[3]) = ($o->{bbox}[3], $o->{bbox}[2]);
    }
}

sub get_clipping { 
    my $o = shift; 
    return $o->{clipping}; 
}

sub set_clipping {
    my $o = shift;
    $o->{clipping} = shift || 0;
}

sub get_strip { 
    my $o = shift; 
    return $o->{strip}; 
}

sub set_strip {
    my ($o, $strip) = @_;
    $o->{strip} = $rmspace unless (defined $o->{strip});
    $o->{strip} = "" if (lc($strip) eq "none");
    $o->{strip} = $rmspace if (lc($strip) eq "space");
    $o->{strip} = $rmcomment if (lc($strip) eq "comments");
}

=head2 get_strip

=head2 set_strip( "none" | "space" | "comments" )

Determine whether the postscript code is filtered.  C<space> strips leading spaces so the user can indent freely
without increasing the file size.  C<comments> remove lines beginning with '%' as well.

=cut

sub get_page_landscape { 
    my $o = shift;
    my $p = $o->get_ordinal( shift );
    return $o->{pagelandsc}[$p]; 
}

sub set_page_landscape {
    my $o = shift;
    my $p = (@_ == 2) ? $o->get_ordinal(shift) : $o->{p};
    my $landscape = shift || 0;
    $o->{pagelandsc}[$p] = 0 unless (defined $o->{pagelandsc}[$p]); 
    if ($o->{pagelandsc}[$p] != $landscape) {
	($o->{pagebbox}[$p][0], $o->{pagebbox}[$p][1]) = ($o->{pagebbox}[$p][1], $o->{pagebbox}[$p][0]);
	($o->{pagebbox}[$p][2], $o->{pagebbox}[$p][3]) = ($o->{pagebbox}[$p][3], $o->{pagebbox}[$p][2]);
    }
    $o->{pagelandsc}[$p] = $landscape;
}

=head2 get_page_landscape( [page] )

=head2 set_page_landscape( [[page,] landscape] )

Inspect and change whether the page specified is oriented horizontally (C<1>) or vertically (C<0>).  The default
is the global setting as returned by B<get_landscape>.  If C<page> is omitted, the current page is assumed.

=cut

sub get_page_clipping { 
    my $o = shift;
    my $p = $o->get_ordinal( shift );
    return $o->{pageclip}[$p]; 
}

sub set_page_clipping {
    my $o = shift;
    my $p = (@_ == 2) ? $o->get_ordinal(shift) : $o->{p};
    $o->{pageclip}[$p] = shift || 0;
}

=head2 get_page_clipping( [page] )

=head2 set_page_clipping( [[page,] clipping] )

Inspect and change whether printing will be clipped to the page's bounding box. (Default: 0)

=cut

sub get_page_label { 
    my $o = shift;
    return $o->{page}[$o->{p}]; 
}

sub set_page_label { 
    my $o = shift;
    my $page = shift || 1;
    $o->{page}[$o->{p}] = $page;
}

=head2 get_page_label()

=head2 set_page_label( [page] )

Inspect and change the number or label for the current page.  (Default: "1")

This will be automatically incremented using the function set by B<set_incpage_hander>.

=cut

sub get_incpage_handler { 
    my $o = shift; 
    return $o->{incpage}; 
}

sub set_incpage_handler { 
    my $o = shift;
    $o->{incpage} = shift || \&incpage_label;
}

=head2 get_incpage_handler()

=head2 set_incpage_handler( [handler] )

Inspect and change the function used to increment the page number or label.  The following suitable values for
C<handler> refer to functions defined in the module:

    \&PostScript::File::incpage_label
    \&PostScript::File::incpage_roman

The default (B<incpage_label>) increments numbers and letters, the other one handles roman numerals up to
39.  C<handler> should be a reference to a subroutine that takes the current page label as its only argument and
returns the new one.  Use this to increment pages using roman numerals or custom orderings.  

=cut

sub get_order { 
    my $o = shift; 
    return $o->{order}; 
}

sub get_title { 
    my $o = shift; 
    return $o->{title}; 
}

sub get_version { 
    my $o = shift; 
    return $o->{version}; 
}

sub get_langlevel { 
    my $o = shift; 
    return $o->{langlevel}; 
}

sub get_extensions { 
    my $o = shift; 
    return $o->{extensions}; 
}

sub get_bounding_box { 
    my $o = shift; 
    return @{$o->{bbox}}; 
}

sub set_bounding_box {
    my ($o, $x0, $y0, $x1, $y1) = @_;
    $o->{bbox} = [ $x0, $y0, $x1, $y1 ] if (defined $y1);
    $o->set_clipping(1);
}

=head2 get_bounding_box()

=head2 set_bounding_box( x0, y0, x1, y1 )

Inspect or change the bounding box for the whole document, showing only the area inside.

Clipping is enabled.  Call with B<set_clipping> with 0 to stop clipping.

=cut

sub get_page_bounding_box { 
    my $o = shift;
    my $p = $o->get_ordinal( shift );
    return @{$o->{pagebbox}[$p]}; 
}

sub set_page_bounding_box {
    my $o = shift;
    my $page = (@_ == 5) ? shift : "";
    if (@_ == 4) {
	my $p = $o->get_ordinal($page);
	$o->{pagebbox}[$p] = [ @_ ];
	$o->set_page_clipping($page, 1);
    }
}

=head2 get_page_bounding_box( [page] )

=head2 set_page_bounding_box( [page], x0, y0, x1, y1 )

Inspect or change the bounding box for a specified page.  If C<page> is not specified, the current page is
assumed, otherwise it should be a page label already given to B<newpage> or B<set_page_label>.  The page bounding
box defaults to the paper area.

Note that this automatically enables clipping for the page.  If this isn't what you want, call
B<set_page_clipping> with 0.

=cut

sub set_page_margins {
    my $o = shift;
    my $page = (@_ == 5) ? shift : "";
    if (@_ == 4) {
	my ($left, $bottom, $right, $top) = @_;
	my $p = $o->get_ordinal($page);
	if ($o->{pagelandsc}[$p]) {
	    $o->{pagebbox}[$p] = [ $left, $bottom, $o->{height}-$right, $o->{width}-$top ];
	} else {
	    $o->{pagebbox}[$p] = [ $left, $bottom, $o->{width}-$right, $o->{height}-$top ];
	}
	$o->set_page_clipping($page, 1);
    }
}

=head2 set_page_margins( [page], left, bottom, right, top )

An alternative way of changing a single page's bounding box.  Unlike the options given to B<new>, the parameters here
are the gaps around the image, not the paper.  So C<left=36> will set the left side in by half an inch, this might
be a short side if C<landscape> is set.

Note that this automatically enables clipping for the page.  If this isn't what you want, call
B<set_page_clipping> with 0.

=cut

sub get_ordinal {
    my ($o, $page) = @_;
    if ($page) {
	for (my $i = 0; $i <= $o->{pagecount}; $i++) {
	    my $here = $o->{page}->[$i] || "";
	    return $i if ($here eq $page);
	}
    }
    return $o->{p};
}
    
=head2 get_ordinal( [page] )

Return the internal number for the page label specified.  (Default: current page)

Example

Say pages are numbered "i", "ii", "iii, "iv", "1", "2", "3".

    get_ordinal("i") == 0
    get_ordinal("iv") == 3
    get_ordinal("1") == 4

=cut

sub get_pagecount { 
    my $o = shift; 
    return $o->{pagecount}; 
}

=head2 get_pagecount()

Return the number of pages currently known.

=head1 CONTENT METHODS

=cut

sub get_comments { 
    my $o = shift; 
    return $o->{Comments}; 
}

sub add_comment { 
    my ($o, $entry) = @_; 
    $o->{Comments} = "\%\%$entry\n" if defined($entry); 
}

=head2 get_comments()

=head2 add_comment( comment )

Most of the required and recommended comments are set directly, so this function should rarely be needed.  It is
provided for completeness so that comments such as C<DocumentNeededResources:> can be added.  The comment should
be the bare PostScript DSC name and value, with additional lines merely prefixed by C<+>.

Example

    $ps->add_comment("ProofMode: NotifyMe");
    $ps->add_comment("Requirements: manualfeed");
    $ps->add_comment("DocumentNeededResources:");
    $ps->add_comment("+ Paladin");
    $ps->add_comment("+ Paladin-Bold");

=cut

sub get_preview { 
    my $o = shift; 
    return $o->{Preview}; 
}

sub add_preview { 
    my ($o, $width, $height, $depth, $lines, $entry) = @_; 
    if (defined $entry) { 
	$entry =~ s/$o->{strip}//gm;  
	($o->{Preview} = <<END_PREVIEW) =~ s/$o->{strip}//gm;
	    \%\%BeginPreview: $width $height $depth $lines
		$entry
	    \%\%EndPreview
END_PREVIEW
    }
}

=head2 get_preview()

=head2 add_preview( width, height, depth, lines, preview )

Use this to add a Preview in EPSI format - an ASCII representation of a bitmap.  If an EPS file has a preview it
becomes an EPSI file rather than EPSF.

=cut

sub get_defaults { 
    my $o = shift; 
    return $o->{Defaults}; 
}

sub add_default { 
    my ($o, $entry) = @_; 
    $o->{Defaults} = "\%\%$entry\n" if defined($entry); 
}

=head2 get_defaults()

=head2 add_default( default )

Use this to add any PostScript DSC comments to the Defaults section.  These would be typically values like
PageCustomColors: or PageRequirements:.

=cut

sub get_resources { 
    my $o = shift; 
    return $o->{Resources}; 
}

sub add_resource { 
    my ($o, $type, $name, $params, $resource) = @_;
    if (defined($resource)) {
	$resource =~ s/$o->{strip}//gm;  
	$o->{DocSupplied} .= "\%\%+ $name\n";
	($o->{Resources} = <<END_USER_RESOURCE) =~ s/$o->{strip}//gm;
	    \%\%Begin${type}: $name $params
	    $resource
	    \%\%End$type
END_USER_RESOURCE
    }
}

=head2 get_resources()

=head2 add_resource( type, name, params, resource )

=over 4

=item C<type>

A string indicating the DSC type of the resource.  It should be one of Document, Resource, File, Font, ProcSet or
Feature (case sensitive).

=item C<name>

An arbitrary identifier of this resource.

=item C<params> 

Some resource types require parameters.  See the Adobe documentation for details.

=item C<resource>

A string containing the postscript code. Probably best provided a 'here' document.

=back

Use this to add fonts or images.  B<add_function> is provided for functions.

Example

    $ps->add_resource( "File", "My_File1", 
		       "", <<END_FILE1 );
	...postscript resource definition
    END_FILE1

Note that B<get_resources> returns I<all> resources added, including those added by any inheriting modules.

=cut

sub get_functions { 
    my $o = shift; 
    return $o->{Functions}; 
}

sub add_function { 
    my ($o, $name, $entry) = @_; 
    if (defined($name) and defined($entry)) {
	$entry =~ s/$o->{strip}//gm;
	$o->{DocSupplied} .= "\%\%+ $name\n";
	($o->{Functions} .= <<END_USER_FUNCTIONS) =~ s/$o->{strip}//gm;
	    \%\%BeginProcSet: $name
	    $entry
	    \%\%EndProcSet
END_USER_FUNCTIONS
    }
}

=head2 get_functions()

=head2 add_function( name, code )

Add user defined functions to the PostScript prolog.  Despite the name, it is better to add related functions in
the same code section. C<name> is an arbitrary identifier of this resource.  Best used with a 'here' document.

Example

    $ps->add_function( "My_Functions", <<END_FUNCTIONS );
	% postscript code can be freely indented
	% as leading spaces and blank lines 
	% (and comments, if desired) are stripped
	
	% foo does this...
	/foo {
	    ... definition of foo
	} bind def

	% bar does that...
	/bar {
	    ... definition of bar
	} bind def
    END_FUNCTIONS

Note that B<get_functions> (in common with the others) will return I<all> user defined functions possibly
including those added by other classes.
    
=cut

sub has_function {
    my ($o, $name) = @_;
    return ($o->{DocSupplied} =~ /$name/);
}

=head2 has_function( name )

This returns true if C<name> has already been included in the file.  The name
should identical to that given to L</"add_function">.

=cut

sub get_setup { 
    my $o = shift; 
    return $o->{Setup}; 
}

sub add_setup { 
    my ($o, $entry) = @_; 
    $entry =~ s/$o->{strip}//gm;
    $o->{Setup} = $entry if (defined $entry); 
}

=head2 get_setup()

=head2 set_setup( code )

Direct access to the C<%%Begin(End)Setup> section.  Use this for C<setpagedevice>, C<statusdict> or other settings
that initialize the device or document.

=cut

sub get_page_setup { 
    my $o = shift; 
    return $o->{PageSetup}; 
}

sub add_page_setup { 
    my ($o, $entry) = @_; 
    $entry =~ s/$o->{strip}//gm;
    $o->{PageSetup} = $entry if (defined $entry);
}

=head2 get_page_setup()

=head2 set_page_setup( code )

Code added here is output before each page.  As there is no special provision for %%Page... DSC comments, they
should be included here.

Note that any settings defined here will be active for each page seperately.  Use B<add_setup> if you want to
carry settings from one page to another.

=cut

sub get_page { 
    my $o = shift;
    my $page = shift || $o->get_page_label();
    my $ord = $o->get_ordinal($page);
    return $o->{Pages}->[$ord]; 
}

sub add_to_page { 
    my $o = shift;
    my $page = (@_ == 2) ? shift : "";
    my $entry = shift || "";
    if ($page) {
	my $ord = $o->get_ordinal($page);
	if (($ord == $o->{p}) and ($page ne $o->{page}[$ord])) {
	    $o->newpage($page);
	} else {
	    $o->{p} = $ord;
	}
    }
    $entry =~ s/$o->{strip}//gm;
    $o->{Pages}[$o->{p}] .= $entry || "";
}

=head2 get_page( [page] )

=head2 add_to_page( [page], code )

The main function for building the postscript output.  C<page> can be any label, typically one given to
B<set_page_label>.  (Default: current page)

If C<page> is not recognized, a new page is added with that label.  Note that this is added on the end, not in the
order you might expect.  So adding "vi" to page set "iii, iv, v, 6, 7, 8" would create a new page after "8" not
after "v".

Examples

    $ps->add_to_page( <<END_PAGE );
	...postscript building this page
    END_PAGE
    
    $ps->add_to_page( "3", <<END_PAGE );
	...postscript building page 3
    END_PAGE
    
The first example adds code onto the end of the current page.  The second one either adds additional code to page
3 if it exists, or starts a new one.
    
=cut

sub get_page_trailer { 
    my $o = shift; 
    return $o->{PageTrailer}; 
}

sub add_page_trailer { 
    my ($o, $entry) = @_; 
    $entry =~ s/$o->{strip}//gm;
    $o->{PageTrailer} = $entry if (defined $entry);
}

=head2 get_page_trailer()

=head2 set_page_trailer( code )

Code added here is output after each page.  It may refer to settings made during B<set_page_setup> or
B<add_to_page>.

=cut

sub get_trailer { 
    my $o = shift; 
    return $o->{Trailer}; 
}

sub add_trailer { 
    my ($o, $entry) = @_; 
    $entry =~ s/$o->{strip}//gm;
    $o->{Trailer} = $entry if (defined $entry); 
}

=head2 get_trailer()

=head2 set_trailer( code )

Add code to the PostScript C<%%Trailer> section.  Use this for any tidying up after all the pages are output.

=cut

#=============================================================================

=head1 POSTSCRIPT DEBUGGING SUPPORT

This section documents the postscript functions which provide debugging output.  Please note that any clipping or
bounding boxes will also hide the debugging output which by default starts at the top left of the page.  Typical
B<new> options required for debugging would include the following.

    $ps = PostScript::File->new ( 
	    errors => "page",
	    debug => 2,
	    clipcmd => "stroke" );

The debugging output is printed on the page being drawn.  In practice this works fine, especially as it is
possible to move the output around.  Where the text appears is controlled by a number of postscript variables,
most of which may also be given as options to B<new>.

The main controller is C<db_active> which needs to be non-zero for any output to be seen.  It might be useful to
set this to 0 in B<new>, then at some point in your code enable it.

    /db_active 1 def
    (this will now show) db_show

At any time, the next output will appear at C<db_xpos> and C<db_ypos>.  These can of course be set directly.
However, after most prints, the equivalent of a 'newline' is executed.  It moves down C<db_fontsize> and left to
C<db_xpos>.  If, however, that would take it below C<db_ybase>, C<db_ypos> is reset to C<db_ytop> and the
x coordinate will have C<db_xgap> added to it, starting a new column.

The positioning of the debug output is changed by setting C<db_xpos> and C<db_ytop> to the top left starting
position, with C<db_ybase> guarding the bottom.  Extending to the right is controlled by not printing too much!
Judicious use of C<db_active> can help there.

=head2 Postscript functions

=head3 x0 y0 x1 y1 B<cliptobox>

=over 4

This function is only available if 'clipping' is set.  By calling the perl method B<draw_bounding_box> (and
resetting with B<clip_bounding_box>) it is possible to use this to identify areas on the page.

    $ps->draw_bounding_box();
    $ps->add_to_page( <<END_CODE );
	...
	my_l my_b my_r my_t cliptobox
	...
    END_CODE
    $ps->clip_bounding_box();

=head3 msg B<report_error>

If 'errors' is enabled, this call allows you to report a fatal error from within your postscript code.  It expects
a string on the stack and it does not return.

=back

All the C<db_> variables (including function names) are defined within their own dictionary (C<debugdict>).  But
this can be ignored by all calls originating from within code passed to B<add_to_page> (usually including
B<add_function> code) as the dictionary is automatically put on the stack before each page and taken off as each
finishes.

=over 4

=head3 any B<db_show>

The workhorse of the system.  This takes the item off the top of the stack and outputs a string representation of
it.  So you can call it on numbers or strings and it will show them.  Arrays are printed using C<db_array> and
marks are shown as '--mark--'. 

=head3 n msg B<db_nshow>

This shows top C<n> items on the stack.  It requires a number and a string on the stack, which it removes.  It
prints out C<msg> then the top C<n> items on the stack, assuming there are that many.  It can be used to do
a labelled stack dump.  Note that if B<new> was given the option C<debug => 2>, There will always be a '--mark--'
entry at the base of the stack.  See L</debug>.

    count (at this point) db_nshow

=head3 B<db_stack>

Prints out the contents of the stack.  No stack requirements.

The stack contents is printed top first, the last item printed is the lowest one inspected.

=head3 array B<db_print>

The closest this module has to a print statement.  It takes an array of strings and/or numbers off the top of the
stack and prints them with a space in between each item.

    [ (myvar1=) myvar1 (str2=) str2 ] db_print

will print something like the following.

    myvar= 23.4 str2= abc

When printing something from the stack you need to take into account the array-building items, too.  In the next
example, at the point '2 index' is given, the stack holds '222 111 [ (top=)' but '5 index' is required to get at
222 because the stack now holds '222 111 [ (top=) 111 (next=)'.

    222 111
    [ (top=) 2 index (next=) 5 index ] db_print

willl output this.

    top= 111 next= 222
    
It is important that the output does not exceed the string buffer size.  The default is 256, but it can be changed
by giving B<new> the option C<bufsize>.

=head3 x y msg B<db_point>

It is common to have coordinates as the top two items on the stack.  This call inspects them.  It pops the message
off the stack, leaving x and y in place, then prints all three.

    450 666
    (starting point=) db_print
    moveto

would produce:

    starting point= ( 450 , 666 )

=head3 array B<db_array>

Like L</db_print> but the array is printed enclosed within square brackets.

=head3 B<db_newcol>

Starts the next debugging column.  No stack requirements.

=head3 B<db_down>

Does a 'carriage-return, line-feed'.  No stack requirements.

=head3 B<db_indent>

Moves output right by C<db_xtab>.  No stack requirements.  Useful for indenting output within loops.

=head3 B<db_unindent>

Moves output left by C<db_xtab>.  No stack requirements.

=back

=cut

sub draw_bounding_box { 
    my $o = shift; 
    $o->{clipcmd} = "stroke"; 
}

sub clip_bounding_box { 
    my $o = shift; 
    $o->{clipcmd} = "clip"; 
}

=head1 EXPORTED FUNCTIONS

No functions are exported by default, they must be named as required.

    use PostScript::File qw(
	    check_tilde check_file 
	    incpage_label incpage_roman 
	    array_as_string str
	);

=cut

sub incpage_label ($) {
    my $page = shift;
    return ++$page;
}

=head2 incpage_label( label )

The default function for B<set_incpage_handler> which just increases the number passed to it.  A useful side
effect is that letters are also incremented.

=cut

our $roman_max = 40;
our @roman = qw(0 i ii iii iv v vi vii viii ix x xi xii xiii xiv xv xvi xvii xviii xix 
		xx xi xxii xxii xxiii xxiv xxv xxvi xxvii xxviii xxix
		xxx xxi xxxii xxxii xxxiii xxxiv xxxv xxxvi xxxvii xxxviii xxxix );
our %roman = ();
for (my $i = 1; $i <= $roman_max; $i++) {
    $roman{$roman[$i]} = $i;
}

sub incpage_roman ($) {
    my $page = shift;
    my $pos = $roman{$page};
    return $roman[++$pos];
}

=head2 incpage_roman( label )

An alternative function for B<set_incpage_handler> which increments lower case roman numerals.  It only handles
values from "i" to "xxxix", but that should be quite enough for numbering the odd preface.

=cut

sub check_file ($;$$) {
    my ($filename, $dir, $create) = @_;
    $create = 0 unless (defined $create);
    
    if (not $filename) {
	$filename = File::Spec->devnull();
    } else {
	$filename = check_tilde($filename);
	$filename = File::Spec->canonpath($filename);
	unless (File::Spec->file_name_is_absolute($filename)) {
	    if (defined($dir)) {
		$dir = check_tilde($dir);
		$dir = File::Spec->canonpath($dir);
		$dir = File::Spec->rel2abs($dir) unless (File::Spec->file_name_is_absolute($dir));
		$filename = File::Spec->catfile($dir, $filename);
	    } else {
		$filename = File::Spec->rel2abs($filename);
	    }
	}

	my @subdirs = ();
	my ($volume, $directories, $file) = File::Spec->splitpath($filename);
	@subdirs = File::Spec->splitdir( $directories );

	my $path = $volume;
	foreach my $dir (@subdirs) {
	    $path = File::Spec->catdir( $path, $dir );
	    mkdir $path unless (-d $path);
	}
	
	$filename = File::Spec->catfile($path, $file);
	if ($create) {
	    unless (-e $filename) {
		open(FILE, ">", $filename) 
		    or die "Unable to open \'$filename\' for writing : $!\nStopped";
		close FILE;
	    }
	}
    }

    return $filename;
}

=head2 check_file( file, [dir, [create]] )

=over 4

=item C<file>

An optional fully qualified path-and-file or a simple file name. If omitted, the special file
File::Spec->devnull() is returned.

=item C<dir>

An optional directory C<dir>.  If present (and C<file> is not already an absolute path), it is prepended to
C<file>.

=item C<create>

If non-zero, ensure the file exists.  It may be necessary to set C<dir> to "" or undef.

=back

This ensures the filename returned is valid and in a directory tree which is created if it doesn't exist.

Any leading '~' is expanded to the users home directory.  If no absolute directory is given either as part of
C<file>, it is placed within the current directory.  Intervening directories are always created.  If C<create> is
set, C<file> is created as an empty file, possible erasing any previous file of the same name. 

B<File::Spec|File::Spec> is used throughout so file access should be portable.  

=cut

sub check_tilde ($) {
    my ($dir) = @_;
    $dir = "" unless $dir;
    $dir =~ s{^~([^/]*)}{$1 ? (getpwnam($1))[7] : ($ENV{HOME} || $ENV{LOGDIR} || (getpwuid($>))[7]) }ex;
    return $dir;
}

=head2 check_tilde( dir )

Expands any leading '~' to the home directory.

=cut

sub array_as_string (@) {
    my $array = "[ ";
    foreach my $f (@_) { $array .= "$f "; }
    $array .= "]";
    return $array;
}

=head2 array_as_string( array )

Converts a perl array to its postscript representation.

=cut

sub str ($) {
    my $arg = shift;
    if (ref($arg) eq "ARRAY") {
	return array_as_string( @$arg );
    } else {
	return $arg;
    }
}

=head2 str( arrayref )

Converts the referenced array to a string representation suitable for postscript code.  If C<arrayref> is not an
array reference, it is passed through unchanged.  This function was designed to simplify passing colours for the
postscript function b<gpapercolor> which expects either an RGB array or a greyscale decimal.  See
L<PostScript::Graph::Paper/gpapercolor>.

=cut

#=============================================================================
		    
=head1 BUGS

When making EPS files, the landscape transformation throws the coordinates off.  To work around this, avoid the
landscape flag and set width and height differently.

Most of these functions have only had a couple of tests, so please feel free to report all you find.

=head1 AUTHOR

Chris Willmot, chris@willmot.org.uk

Thanks to Johan Vromans for the ISOLatin1Encoding.

=head1 SEE ALSO

L<PostScript Language Document Structuring Conventions Specification Version
3.0|http://partners.adobe.com/asn/developer/technotes/postscript.html> published by Adobe, 1992.

L<Encapsulated PostScript File Format Specification Version
3.0|http://partners.adobe.com/asn/developer/technotes/postscript.html> published by Adobe, 1992.

L<PostScript::Graph::Paper>,
L<PostScript::Graph::Style>,
L<PostScript::Graph::Key>,
L<PostScript::Graph::XY>,
L<PostScript::Graph::Bar>.
L<PostScript::Graph::Stock>.

=cut

#=============================================================================
1;
