use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Syntax::GivenWhen',
    LICENSE             => 'perl',
    AUTHOR              => 'Sebastien Aperghis-Tramoni <saper@cpan.org>',
    VERSION_FROM        => 'lib/Syntax/GivenWhen.pm',
    ABSTRACT_FROM       => 'lib/Syntax/GivenWhen.pm',
    META_MERGE          => {
        resources       => {
            homepage    => 'https://www.ohloh.net/p/Syntax-GivenWhen',
            repository  => 'git://github.com/maddingue/Syntax-GivenWhen.git',
        },
    },
    PREREQ_PM           => {
        # prereqs
        'DBI'           => '1.40',
    
        # build/test prereqs
        'Test::More'    => 0,
    },
    PL_FILES            => {},
    clean               => { FILES => 'Syntax-GivenWhen-*' },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);

