package Sub::Spec::To::Org;
{
  $Sub::Spec::To::Org::VERSION = '0.003';
}

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

use Data::Sah;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(spec_to_org);

# VERSION

our %SPEC;

sub _parse_schema {
    Data::Sah::normalize_schema($_[0]);
}

$SPEC{spec_to_org} = {
    summary => 'Generate Org documentation from sub spec',
    args => {
        spec => ['hash*' => {}],
    },
    result_naked => 1,
};
sub spec_to_org($;$) {
    # to minimize startup overhead
    require Org::Parser;
    require Data::Dump::Partial;
    require List::MoreUtils;

    my %args = @_;
    my $sub_spec = $args{spec} or return [400, "Please specify spec"];
    $log->trace("-> spec_to_org($sub_spec->{_package}::$sub_spec->{name})");

    my $org = "";

    die "No name in spec" unless $sub_spec->{name};
    $log->trace("Generating Org for $sub_spec->{name} ...");

    my $naked = $sub_spec->{result_naked};


    $log->trace("<- spec_to_org()");
    $org;
}

1;
# ABSTRACT: Generate Org documentation from sub spec


=pod

=head1 NAME

Sub::Spec::To::Org - Generate Org documentation from sub spec

=head1 VERSION

version 0.003

=head1 SYNOPSIS

 use Sub::Spec::To::Org qw(spec_to_org);
 my $org = spec_to_org(spec => $spec,
                       # other options
                      );

=head1 DESCRIPTION

B<NOTICE>: This module and the L<Sub::Spec> standard is deprecated as of Jan
2012. L<Rinci> is the new specification to replace Sub::Spec, it is about 95%
compatible with Sub::Spec, but corrects a few issues and is more generic.
C<Perinci::*> is the Perl implementation for Rinci and many of its modules can
handle existing Sub::Spec sub specs.

EARLY RELEASE. NO IMPLEMENTATION YET!

This module can generate Org document from sub spec.

This module uses L<Log::Any> logging framework.

=begin comment




=end comment

    $pod .= "=head2 $sub_spec->{name}(\%args) -> ".
        ($naked ? "RESULT" : "[STATUS_CODE, ERR_MSG, RESULT]")."\n\n";

    if ($sub_spec->{summary}) {
        $pod .= "$sub_spec->{summary}.\n\n";
    }

    my $desc = $sub_spec->{description};
    if ($desc) {
        $desc =~ s/^\n+//; $desc =~ s/\n+$//;
        $pod .= "$desc\n\n";
    }

    if ($naked) {

    } else {
        $pod .= <<'_';
Returns a 3-element arrayref. STATUS_CODE is 200 on success, or an error code
between 3xx-5xx (just like in HTTP). ERR_MSG is a string containing error
message, RESULT is the actual result.

_
    }

    my $features = $sub_spec->{features} // {};
    if ($features->{reverse}) {
        $pod .= <<'_';
This function supports reverse operation. To reverse, add argument C<-reverse>
=> 1.

_
    }
    if ($features->{undo}) {
        $pod .= <<'_';
This function supports undo operation. See L<Sub::Spec::Clause::features> for
details on how to perform do/undo/redo.

_
    }
    if ($features->{dry_run}) {
        $pod .= <<'_';
This function supports dry-run (simulation) mode. To run in dry-run mode, add
argument C<-dry_run> => 1.

_
    }
    if ($features->{pure}) {
        $pod .= <<'_';
This function is declared as pure, meaning it does not change any external state
or have any side effects.

_
    }

    my $args  = $sub_spec->{args} // {};
    $args = { map {$_ => _parse_schema($args->{$_})} keys %$args };
    my $has_cat = grep { $_->{clause_sets}[0]{arg_category} }
        values %$args;

    if (scalar keys %$args) {
        my $noted_star_req;
        my $prev_cat;
        for my $name (sort {
            (($args->{$a}{clause_sets}[0]{arg_category} // "") cmp
                 ($args->{$b}{clause_sets}[0]{arg_category} // "")) ||
                     (($args->{$a}{clause_sets}[0]{arg_pos} // 9999) <=>
                          ($args->{$b}{clause_sets}[0]{arg_pos} // 9999)) ||
                              ($a cmp $b) } keys %$args) {
            my $arg = $args->{$name};
            my $ah0 = $arg->{clause_sets}[0];

            my $cat = $ah0->{arg_category} // "";
            if (!defined($prev_cat) || $prev_cat ne $cat) {
                $pod .= "=back\n\n" if defined($prev_cat);
                $pod .= ($cat ? ucfirst("$cat arguments") :
                             ($has_cat ? "General arguments":"Arguments"));
                $pod .= " (C<*> denotes required arguments)"
                    unless $noted_star_req++;
                $pod .= ":\n\n=over 4\n\n";
                $prev_cat = $cat;
            }

            $pod .= "=item * B<$name>".($ah0->{req} ? "*" : "")." => ";
            my $type;
            if ($arg->{type} eq 'any') {
                my @schemas = map {_parse_schema($_)} @{$ah0->{of}};
                my @types   = map {$_->{type}} @schemas;
                @types      = sort List::MoreUtils::uniq(@types);
                $type       = join("|", @types);
            } else {
                $type       = $arg->{type};
            }
            $pod .= "I<$type>";
            $pod .= " (default ".
                (defined($ah0->{default}) ?
                     "C<".Data::Dump::Partial::dumpp($ah0->{default}).">"
                         : "none").
                             ")"
                               if defined($ah0->{default});
            $pod .= "\n\n";

            my $aliases = $ah0->{arg_aliases};
            if ($aliases && keys %$aliases) {
                $pod .= "Aliases: ";
                my $i = 0;
                for my $al (sort keys %$aliases) {
                    $pod .= ", " if $i++;
                    my $alinfo = $aliases->{$al};
                    $pod .= "B<$al>".
                        ($alinfo->{summary} ? " ($alinfo->{summary})" : "");
                }
                $pod .= "\n\n";
            }

            $pod .= "Value must be one of:\n\n".
                join("", map {" $_\n"} split /\n/,
                     Data::Dump::dump($ah0->{in}))."\n\n"
                           if defined($ah0->{in});

            #my $o = $ah0->{arg_pos};
            #my $g = $ah0->{arg_greedy};

            $pod .= "$ah0->{summary}.\n\n" if $ah0->{summary};

            my $desc = $ah0->{description};
            if ($desc) {
                $desc =~ s/^\n+//; $desc =~ s/\n+$//;
                # XXX format/rewrap
                $pod .= "$desc\n\n";
            }
        }
        $pod .= "=back\n\n";

    } else {

        $pod .= "No known arguments at this time.\n\n";

    }

=head1 FUNCTIONS

None of the functions are exported by default, but they are exportable.

=head2 spec_to_org(%args) -> RESULT


Generate Org documentation from sub spec.

Arguments (C<*> denotes required arguments):

=over 4

=item * B<spec>* => I<hash>

=back

=head1 SEE ALSO

L<Sub::Spec>

Other Sub::Spec::To::* modules.

=head1 AUTHOR

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


__END__

