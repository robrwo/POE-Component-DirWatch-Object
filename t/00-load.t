#!perl 

use Test::More tests => 1;

BEGIN {
	use_ok( 'POE::Component::DirWatch::Object' );
}

diag( "Testing POE::Component::DirWatch::Object $POE::Component::DirWatch::Object::VERSION, Perl $], $^X" );
