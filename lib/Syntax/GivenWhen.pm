package GivenWhen;

use 5.008;
use strict;
use warnings;


our $VERSION = "0.01";

BEGIN {
    if ($] < 5.010) {
        require B::Hooks::EndOfScope;
        B::Hooks::EndOfScope->import;

        require Devel::Declare;
        Devel::Declare->import;

        require Exporter;
    }
    else {
        require feature;
    }
}


our ($Declarator, $Offset);


sub import {
    my ($class, %args) = @_;
    my $caller  = $args{for} || caller();

    if ($] < 5.010) {
        Devel::Declare->setup_for($caller, {
            given   => { const => \&setup_given   },
            when    => { const => \&setup_when    },
            default => { const => \&setup_default },
        });

        no strict "vars";
        @ISA    = qw< Exporter >;
        @EXPORT = qw< given when default >;
        $class->export_to_level(1, @_);
    }
    else {
        feature->import("switch");
    }
}


sub given   (&) { $_[0]->() }
sub when    (&) { $_[0]->() }
sub default (&) { $_[0]->() }


sub setup_given {
    local ($Declarator, $Offset) = @_;

    skip_token();                   # step past the "given" keyword
    my $parens = strip_parens();    # strip out the expr in parens
    inject_if_block("local (\$_) = ($parens); my \$__found__ = 0;");
}


sub setup_when {
    local ($Declarator, $Offset) = @_;

    skip_token();                   # step past the "when" keyword
    my $parens = strip_parens();    # strip out the expr in parens
    my $inject = scope_injector_call($parens) . "\$__found__ = 1;";
    inject_if_block($inject);
}


sub setup_default {
    local ($Declarator, $Offset) = @_;

    skip_token();                   # step past the "default" keyword
    inject_if_block(scope_injector_call());
}


sub skip_space {
    $Offset += Devel::Declare::toke_skipspace($Offset);
}


sub skip_token {
    $Offset += Devel::Declare::toke_move_past_token($Offset);
}


sub strip_token {
    skip_space();

    if (my $len = Devel::Declare::toke_scan_word($Offset, 1)) {
        my $linestr = Devel::Declare::get_linestr();
        my $name = substr($linestr, $Offset, $len);
        substr($linestr, $Offset, $len) = "";
        Devel::Declare::set_linestr($linestr);
        return $name;
    }

    return;
}


sub strip_parens {
    skip_space();
    my $linestr = Devel::Declare::get_linestr();

    if (substr($linestr, $Offset, 1) eq "(") {
        my $length  = Devel::Declare::toke_scan_str($Offset);
        my $parens  = Devel::Declare::get_lex_stuff();
        Devel::Declare::clear_lex_stuff();
        $linestr = Devel::Declare::get_linestr();
        substr($linestr, $Offset, $length) = "";
        Devel::Declare::set_linestr($linestr);
        return $parens;
    }

    return
}


sub inject_if_block {
    my ($inject) = @_;

    skip_space();
    my $linestr = Devel::Declare::get_linestr();

    if (substr($linestr, $Offset, 1) eq "{") {
        substr($linestr, $Offset+1, 0) = $inject;
        Devel::Declare::set_linestr($linestr);
    }
}


sub scope_injector_call {
    my ($cond) = @_;
    $cond ||= "";
    return " BEGIN { ".__PACKAGE__."::inject_scope(q{$cond}) }; ";
}


sub inject_scope {
    my ($cond) = @_;
    my $more = $cond ? " and $cond" : "";

    on_scope_end {
        my $linestr = Devel::Declare::get_linestr();
        my $offset = Devel::Declare::get_linestr_offset();
        substr($linestr, $offset, 0) = " if not \$__found__ $more;";
        Devel::Declare::set_linestr($linestr);
    };
}


__PACKAGE__

__END__

=head1 NAME

Syntax::GivenWhen - Add support for the given/when keywords to Perl 5.8


=head1 VERSION

Version 0.01


=head1 SYNOPSIS

    use Syntax::GivenWhen;


=head1 DESCRIPTION

...


=head1 SEE ALSO

L<perlsyn/"Switch statements"> of Perl 5.10 and later.
See L<http://perldoc.perl.org/perlsyn.html#Switch-statements>

=head1 AUTHOR

SE<eacute>bastien Aperghis-Tramoni C<< <sebastien at aperghis.net> >>


=head1 BUGS

Please report any bugs or feature requests to
C<bug-syntax-givenwhen at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/Public/Dist/Display.html?Dist=Syntax-GivenWhen>.
I will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Syntax::GivenWhen

You can also look for information at:

=over

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/Public/Dist/Display.html?Dist=Syntax-GivenWhen>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Syntax-GivenWhen>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Syntax-GivenWhen>

=item * Search CPAN

L<http://search.cpan.org/dist/Syntax-GivenWhen>

=back


=head1 COPYRIGHT & LICENSE

Copyright 2010 SE<eacute>bastien Aperghis-Tramoni, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

