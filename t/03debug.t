use Test;
BEGIN { plan tests => 7 };
use PostScript::File qw(check_file);
ok(1); # module found

my $ps = new PostScript::File(
    headings => 1,
    paper => "A5",
    landscape => 1,
    left => 36,
    right => 36,
    top => 72,
    bottom => 72,
    clipping => 1,
    clipcmd => "stroke",
    errors => 1,
    debug => 2,
    );
ok($ps); # object created

$ps->add_to_page( <<END_PAGE );
    /Helvetica findfont 
    12 scalefont 
    setfont
    100 150 moveto
    (hello world) show
    111
    222
    (some text)
    [ 33 (in an array) 55 ]
    666
END_PAGE
my $page = $ps->get_page_label();
ok($page, "1");
ok($ps->get_page());

my $name = "03debug";
$ps->output( $name, "test-results" );
ok(1); # survived so far
my $file = check_file( "$name.ps", "test-results" );
ok($file);
ok(-e $file);

