use Test;
BEGIN { plan tests => 5 };
use PostScript::File qw(check_file);
ok(1); # module found

my $ps = new PostScript::File();
ok($ps); # object created

my $name = "fi01simple";
$ps->output( $name, "test-results" );
ok(1); # survived so far
my $file = check_file( "$name.ps", "test-results" );
ok($file);
ok(-e $file);

