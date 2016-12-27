package App::lcpan::Cmd::deps_all;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

require App::lcpan;

our %SPEC;

$SPEC{handle_cmd} = {
    v => 1.1,
    summary => 'List all dependencies',
    description => <<'_',

This subcommand lists dependencies. It does not require you to specify a
distribution name, so you can view all dependencies in the `dep` table.

_
    args => {
        %App::lcpan::deps_phase_args,
        %App::lcpan::deps_rel_args,
        module => {
            schema => 'perl::modname*',
            tags => ['category:filtering'],
        },
        dist => {
            schema => 'perl::distname*',
            tags => ['category:filtering'],
        },
        module_author => {
            schema => 'str*',
            completion => \&App::lcpan::_complete_cpanid,
            tags => ['category:filtering'],
        },
        dist_author => {
            schema => 'str*',
            completion => \&App::lcpan::_complete_cpanid,
            tags => ['category:filtering'],
        },
    },
};
sub handle_cmd {
    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my @wheres = ();
    my @binds  = ();

    if ($args{module}) {
        push @wheres, "m.name=?";
        push @binds, $args{module};
    }
    if ($args{module_author}) {
        push @wheres, "m.cpanid=?";
        push @binds, uc $args{module_author};
    }
    if ($args{dist}) {
        push @wheres, "dist=?";
        push @binds, $args{dist};
    }
    if ($args{dist_author}) {
        push @wheres, "d.cpanid=?";
        push @binds, uc $args{dist_author};
    }
    if ($args{phase} && $args{phase} ne 'ALL') {
        push @wheres, "phase=?";
        push @binds, $args{phase};
    }
    if ($args{rel} && $args{rel} ne 'ALL') {
        push @wheres, "rel=?";
        push @binds, $args{rel};
    }

    my @columns = qw(module module_author dist dist_author phase rel);
    my $sth = $dbh->prepare("SELECT
  m.name module,
  m.cpanid module_author,
  d.name dist,
  d.cpanid dist_author,
  phase,
  rel
FROM dep
LEFT JOIN module m ON module_id=m.id
LEFT JOIN dist d ON dist_id=d.id
".
    (@wheres ? "WHERE ".join(" AND ", @wheres) : ""),
                        );
    $sth->execute(@binds);

    my @res;
    while (my $row = $sth->fetchrow_hashref) {
        push @res, $row;
    }

    [200, "OK", \@res, {'table.fields'=>\@columns}];
}

1;
# ABSTRACT:
