use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Syntax::GivenWhen',
    license             => 'perl',
    dist_author         => 'Sebastien Aperghis-Tramoni <saper@cpan.org>',
    dist_version_from   => 'lib/Syntax/GivenWhen.pm',

    meta_merge          => {
        resources       => {
            homepage    => 'https://www.ohloh.net/p/Syntax-GivenWhen',
            repository  => 'git://github.com/maddingue/Syntax-GivenWhen.git',
        },
    },

    build_requires => {
        'Exporter'      => 0,
        'Perl6::Say'    => 0,
    },
    build_requires => {
        'Test::More'    => 0,
    },

    add_to_cleanup      => [ 'Syntax-GivenWhen-*' ],
);

$builder->create_build_script();
