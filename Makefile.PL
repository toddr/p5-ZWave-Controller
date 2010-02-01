use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'ZWave::Controller',
    AUTHOR              => q{Todd Rinaldo <toddr@cpan.org>},
    VERSION_FROM        => 'lib/ZWave/Controller.pm',
    ABSTRACT_FROM       => 'lib/ZWave/Controller.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
	'Moose' => 0.94,
	'Device::SerialPort' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'ZWave-Controller-*' },
    META_MERGE  => {
        recommends => {
            'Test::Pod::Coverage' => 1.04,
            'Test::Pod' => 1.14,
        },
        build_requires => {
            'Test::More' => 0,  # For testing
            'Test::NoWarnings' => 0,  # For testing
        },
        resources => {
            license => 'http://dev.perl.org/licenses/',
            homepage => 'http://wiki.github.com/toddr/p5-ZWave-Controller',
            bugtracker => 'http://code.google.com/p/p5-ZWave-Controller/issues/list',
            repository => 'http://github.com/toddr/p5-ZWave-Controller/tree/master',
#            MailingList => 'http://groups.google.com/group/perl-net-jabber-bot',
        },
    },);
