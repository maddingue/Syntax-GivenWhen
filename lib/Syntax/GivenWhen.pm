package Syntax::GivenWhen;

use 5.008;
use strict;
use warnings;


our $VERSION = "0.01";

use constant DEBUG => 1;


BEGIN {
    if ($] < 5.010) {
        print STDERR "debug: detected Perl 5.8\n" if DEBUG;

        require B::Hooks::EndOfScope;
        B::Hooks::EndOfScope->import;

        require Devel::Declare;
        Devel::Declare->import;

        require Carp;
        Carp->import;

        require Exporter;
        require overload;

        if (DEBUG) {
            require Term::ANSIColor;
            Term::ANSIColor->import(":constants");
        }
    }
    else {
        print STDERR "debug: detected Perl 5.10+\n" if DEBUG;
        require feature;
    }
}


our ($Declarator, $Offset);


sub import {
    my ($class, %args) = @_;
    my $caller  = $args{for} || caller();

    if ($] < 5.010) {
        print STDERR "debug: installing Devel::Declare hooks\n" if DEBUG;

        Devel::Declare->setup_for($caller, {
            given   => { const => \&setup_given   },
            when    => { const => \&setup_when    },
            default => { const => \&setup_default },
            break   => { const => \&setup_break   },
        });

        no strict "vars";
        @ISA    = qw< Exporter >;
        @EXPORT = qw< given when default break >;
        $class->export_to_level(1, @_);
    }
    else {
        print STDERR "debug: loading feature 'switch'\n" if DEBUG;
        feature->import("switch");
    }
}


######################################################################
# Compilation phase
# -----------------
# The following functions are called during compilation, to modify
# the source code and setup the magic.
#

sub setup_given {
    local ($Declarator, $Offset) = @_;

    skip_token();                   # step past the "given" keyword
    my $parens = strip_parens();    # strip out the expr in parens

    my $inject = scope_injector_call()
        . qq| local (\$_) = ($parens); my \$__found__ = 0;|;
    inject_if_block($inject);

    print STDERR "debug: ", CYAN, Devel::Declare::get_linestr(), RESET
        if DEBUG;
}


sub setup_when {
    local ($Declarator, $Offset) = @_;

    skip_token();                   # step past the "when" keyword
    my $parens = strip_parens();    # strip out the expr in parens

    # smart match
    print STDERR "debug: parens=(", YELLOW, $parens, RESET, ")\n" if DEBUG;
    if ($parens eq "undef") {
        $parens = "!defined";
    }
    elsif ($parens =~ /^[+-]?[\d._]+$/) {
        $parens = "\$_ == $parens";
    }
    elsif ($parens =~ /^".*"$/ or $parens =~ /^'.*'$/ or $parens =~ /^q\W/) {
        $parens = "\$_ eq $parens";
    }
    else {
        $parens = __PACKAGE__."::smart_match($parens)";
    }

    my $inject = when_scope_injector_call($parens) . q|eval { $__found__ = 1 }; |
        . q|die "Can't use when() outside a topicalizer" if $@;|;
    inject_if_block($inject);

    print STDERR "debug: ", CYAN, Devel::Declare::get_linestr(), RESET
        if DEBUG;
}


sub setup_default {
    local ($Declarator, $Offset) = @_;

    skip_token();                   # step past the "default" keyword
    inject_if_block(when_scope_injector_call());

    print STDERR "debug: ", CYAN, Devel::Declare::get_linestr(), RESET
        if DEBUG;
}


sub setup_break {
    local ($Declarator, $Offset) = @_;

    skip_token();                   # step past the "break" keyword

    print STDERR "debug: ", CYAN, Devel::Declare::get_linestr(), RESET
        if DEBUG;
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
    return " BEGIN { ".__PACKAGE__."::inject_scope() }; ";
}


sub inject_scope {
    on_scope_end {
        my $linestr = Devel::Declare::get_linestr();
        my $offset = Devel::Declare::get_linestr_offset();
        substr($linestr, $offset, 0) = ";";
        Devel::Declare::set_linestr($linestr);
    };
}


sub when_scope_injector_call {
    my ($cond) = @_;
    $cond ||= "";
    return " BEGIN { ".__PACKAGE__."::inject_when_scope(q{$cond}) }; ";
}


sub inject_when_scope {
    my ($cond) = @_;
    my $more = $cond ? " and $cond" : "";

    on_scope_end {
        my $linestr = Devel::Declare::get_linestr();
        my $offset = Devel::Declare::get_linestr_offset();
        substr($linestr, $offset, 0) = " if not \$__found__ $more;";
        Devel::Declare::set_linestr($linestr);
    };
}


######################################################################
# Runtime phase
# -------------
# The following functions are called during runtime.
#

# keywords
sub given   (&) { $_[0]->() }
sub when    (&) { $_[0]->() }
sub default (&) { $_[0]->() }
sub break   ()  { }

sub smart_match {
    my ($A, $B) = ($_, $_[0]);
    my $type_of_A = ucfirst(lc ref $A) || "Any";
    my $type_of_B = ucfirst(lc ref $B) || "Any";
    print STDERR "debug: smart match: A = $type_of_A($A), B = $type_of_B($B)\n"
        if DEBUG;

    # detect if one of the operands is an object
    if ($type_of_B !~ /^(?:Any|Array|Code|Hash|Regexp)$/) {
        if (overload::Overloaded($B) and my $method = overload::Method($B, "~~")) {
            return $B->$method($A);
        }
        else {
            croak "Smart matching a non-overloaded object breaks encapsulation"
        }
    }
    elsif ($type_of_A !~ /^(?:Any|Array|Code|Hash|Regexp)$/) {
        if (overload::Overloaded($A) and my $method = overload::Method($A, "~~")) {
            return $A->$method($B);
        }
        else {
            croak "Smart matching a non-overloaded object breaks encapsulation"
        }
    }

    elsif ($type_of_B ne "Any") {
        if ($type_of_B eq "Array") {
            if ($type_of_A eq "Hash") {
                # hash keys intersection
                return grep { exists $A->{$_} } @$B
            }
            elsif ($type_of_A eq "Array") {
                # arrays are comparable
                die "unimplemented" #XXX#
            }
            elsif ($type_of_A eq "Regexp") {
                # array grep
                return grep { /$A/ } @$B
            }
            elsif (not defined $A) {
                # array contains undef
                return grep { not defined } @$B
            }
            else { # type Any
                # match against an array element
                #   grep { $a ~~ $_ } @$b
                die "unimplemented" #XXX#
            }
        }

        elsif ($type_of_B eq "Hash") {
            if ($type_of_A eq "Hash") {
                # hash keys identical (every key is found in both hashes)
                die "unimplemented" #XXX#
            }
            elsif ($type_of_A eq "Array") {
                # hash keys intersection
                return grep { exists $B->{$_} } @$A
            }
            elsif ($type_of_A eq "Regexp") {
                # hash key grep
                return grep { /$A/ } keys %$B
            }
            elsif (not defined $A) {
                # always false (undef can't be a key)
                return
            }
            else { # type Any
                # hash entry existence
                return exists $B->{$A}
            }
        }

        elsif ($type_of_B eq "Regexp") {
            if ($type_of_A eq "Hash") {
                # hash key grep
                return grep { /$B/ } keys %$A
            }
            elsif ($type_of_A eq "Array") {
                # array grep
                return grep { /$B/ } @$A
            }
            else { # type Any
                # pattern match
                return $A =~ $B
            }
        }

        elsif ($type_of_B eq "Code") {
            if ($type_of_A eq "Hash") {
                # sub truth for each key
                return !grep { !$B->($_) } keys %$A
            }
            elsif ($type_of_A eq "Array") {
                # sub truth for each element
                return !grep { !$B->($_) } @$A
            }
            else { # type Any
                # scalar sub truth
                return $B->($A)
            }
        }

    }
    else {
        return $_[0]
    }
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

