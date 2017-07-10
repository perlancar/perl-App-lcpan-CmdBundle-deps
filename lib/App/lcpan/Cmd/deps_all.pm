package App::lcpan::Cmd::deps_all;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Clone::Util qw(modclone);

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
        %{( modclone {
            # can contain %, so anything
            delete $_->{phase}{schema}[1]{match};
        } \%App::lcpan::rdeps_phase_args )},
        %{( modclone {
            # can contain %, so anything
            delete $_->{rel}{schema}[1]{match};
        } \%App::lcpan::rdeps_rel_args )},
        module => {
            summary => 'Module name (can contain % for SQL LIKE query)',
            schema => 'str*',
            tags => ['category:filtering'],
        },
        dist => {
            summary => 'Distribution name (can contain % for SQL LIKE query)',
            schema => 'str*',
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
        if ($args{module} =~ /%/) {
            push @wheres, "m.name LIKE ?";
        } else {
            push @wheres, "m.name=?";
        }
        push @binds, $args{module};
    }
    if ($args{module_author}) {
        push @wheres, "m.cpanid=?";
        push @binds, uc $args{module_author};
    }
    if ($args{dist}) {
        if ($args{dist} =~ /%/) {
            push @wheres, "d.name LIKE ?";
        } else {
            push @wheres, "d.name=?";
        }
        push @binds, $args{dist};
    }
    if ($args{dist_author}) {
        push @wheres, "d.cpanid=?";
        push @binds, uc $args{dist_author};
    }
    if ($args{phase} && $args{phase} ne 'ALL') {
        if ($args{phase} =~ /%/) {
            push @wheres, "phase LIKE ?";
        } else {
            push @wheres, "phase=?";
        }
        push @binds, $args{phase};
    }
    if ($args{rel} && $args{rel} ne 'ALL') {
        if ($args{rel} =~ /%/) {
            push @wheres, "rel LIKE ?";
        } else {
            push @wheres, "rel=?";
        }
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
