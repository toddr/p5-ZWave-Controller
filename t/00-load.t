#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'ZWave::Controller' );
}

diag( "Testing ZWave::Controller $ZWave::Controller::VERSION, Perl $], $^X" );
