use Test;
BEGIN { plan tests => 7 };
use PostScript::File qw(check_file);
ok(1); # module found

my $ps = new PostScript::File(
    eps => 1,
    headings => 1,
    width => 160,
    height => 112,
    );
ok($ps); # object created

$ps->add_to_page( <<END_PAGE );
    /Helvetica findfont 
    12 scalefont 
    setfont
    50 50 moveto
    (hello world) show
END_PAGE
my $page = $ps->get_page_label();
ok($page, "1");
ok($ps->get_page());

my $name = "fi02eps";
$ps->output( $name, "test-results" );
ok(1); # survived so far
my $file = check_file( "$name.epsf", "test-results" );
ok($file);
ok(-e $file);

