use Test;
BEGIN { plan tests => 7 };
use PostScript::File qw(check_file);
ok(1); # module found

my $ps = new PostScript::File();
ok($ps); # object created

$ps->add_to_page( <<END_PAGE );
    /Helvetica findfont 
    12 scalefont 
    setfont
    72 300 moveto
    (hello world) show
END_PAGE
my $page = $ps->get_page_number();
ok($page, "1");
ok($ps->get_page());

my $name = "hello";
$ps->output( $name );
ok(1); # survived so far
my $file = check_file( "$name.ps" );
ok($file);
ok(-e $file);

