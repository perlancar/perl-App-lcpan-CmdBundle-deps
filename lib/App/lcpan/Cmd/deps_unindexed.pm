package App::lcpan::Cmd::deps_unindexed;

# AUTHORITY
# DATE
# DIST
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
    summary => 'List all unindexed dependencies',
    description => <<'_',

This subcommand lists unindexed dependencies. It does not require you to specify
a distribution name, so you can view all unindexed dependencies in the `dep`
table. Only "unindexed dependencies" are listed though, meaning modules that are
not currently indexed by `02packages.details.txt.gz` and are not listed in the
`module` table. Obviously, distributions normallyd specify dependencies to
indexed modules so they can be found and installed. To list those, use the
`deps-all` subcommand.

_
    args => {
        %{( modclone {
            delete $_->{phase}{schema}[1]{match};
            $_->{phase}{summary} = 'Phase (can contain % for SQL LIKE query)';
        } \%App::lcpan::rdeps_phase_args )},
        %{( modclone {
            delete $_->{rel}{schema}[1]{match};
            $_->{rel}{summary} = 'Relationship (can contain % for SQL LIKE query)';
        } \%App::lcpan::rdeps_rel_args )},
        module => {
            summary => 'Module name that is depended upon (can contain % for SQL LIKE query)',
            schema => 'str*',
            tags => ['category:filtering'],
        },
        dist => {
            summary => 'Distribution name that specifies the dependency (can contain % for SQL LIKE query)',
            schema => 'str*',
            tags => ['category:filtering'],
        },
        dist_author => {
            summary => 'The ID of author that releases the distribution that specifies the distribution',
            schema => 'str*',
            completion => \&App::lcpan::_complete_cpanid,
            tags => ['category:filtering'],
        },
        perl => {
            summary => "Whether to show dependency to 'perl'",
            description => <<'_',

If set to true, will only show dependencies to 'perl'. If set to false, will
exclude dependencies to 'perl'. Otherwise, will show all unindexed dependencies
including ones to 'perl'.

_
            schema => 'bool*',
            cmdline_aliases => {
                exclude_perl => {is_flag=>1, summary=>"Equivalent to --perl", code=>sub {$_[0]{perl}=1}},
                include_perl => {is_flag=>1, summary=>"Equivalent to --no-perl", code=>sub {$_[0]{perl}=0}},
            },
        },
    },
};
sub handle_cmd {
    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my @wheres = ();
    my @binds  = ();

    push @wheres, "dep.module_id IS NULL";

    if (defined $args{perl}) {
        if ($args{perl}) { push @wheres, "dep.module_name='perl'" }
        else             { push @wheres, "dep.module_name!='perl'" }
    }
    if ($args{module}) {
        if ($args{module} =~ /%/) {
            push @wheres, "dep.module_name LIKE ?";
        } else {
            push @wheres, "dep.module_name=?";
        }
        push @binds, $args{module};
    }
    if ($args{dist}) {
        if ($args{dist} =~ /%/) {
            push @wheres, "df.dist_name LIKE ?";
        } else {
            push @wheres, "df.dist_name=?";
        }
        push @binds, $args{dist};
    }
    if ($args{dist_author}) {
        push @wheres, "df.cpanid=?";
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

    my @columns = qw(module dist dist_author phase rel);
    my $sth = $dbh->prepare("SELECT
  dep.module_name module,
  df.dist_name dist,
  df.cpanid dist_author,
  phase,
  rel
FROM dep
LEFT JOIN file df ON dep.file_id=df.id
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
