#!/usr/bin/perl
use strict;
use warnings;

use Test;
use charnames qw(:full);
BEGIN { plan tests => 4 };
use PostScript::File qw(check_file incpage_label incpage_roman);

my $hash = { headings => 1,
	     paper => 'US-Letter',
	     errors => 1,
	     debug => 2,
	     page => "viii",
	     incpage_handler => \&incpage_roman,
	     reencode => "ISOLatin1Encoding",
	     fontsuffix => "-latin1",
	     };
my $ps = new PostScript::File( $hash );
ok($ps); # object created

my $label = $ps->get_page_label();
ok($label, "viii");
$ps->add_to_page( <<END_PAGE1 );
    [ (This is page $label) ] db_print
    /Helvetica-latin1 findfont 
    12 scalefont 
    setfont
    172 400 moveto
    (First page) show
END_PAGE1

$ps->newpage();
$label = $ps->get_page_label();
ok($label, "ix");
my $msg = "Second Page: \N{LATIN SMALL LETTER E WITH CIRCUMFLEX} £";
$ps->add_to_page( <<END_PAGE2 );
    [ (This is page $label) ] db_print
    /Times-BoldItalic-latin1 findfont 
    12 scalefont 
    setfont
    172 400 moveto
    ($msg) show
END_PAGE2

my $name = "fi04pages";
$ps->output( $name, "test-results" );
my $file = check_file( "$name.ps", "test-results" );
ok(-e $file);

__END__



