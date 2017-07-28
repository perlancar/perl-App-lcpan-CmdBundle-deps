package App::lcpan::Cmd::deps_rels;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

require App::lcpan;

our %SPEC;

$SPEC{handle_cmd} = {
    v => 1.1,
    summary => 'List all known prereq relationships',
    description => <<'_',

_
    args => {
        %App::lcpan::common_args,
    },
};
sub handle_cmd {
    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my $sth = $dbh->prepare("SELECT DISTINCT rel FROM dep ORDER BY rel");
    $sth->execute;

    my @res;
    while (my @row = $sth->fetchrow_array) {
        push @res, $row[0];
    }

    [200, "OK", \@res];
}

1;
# ABSTRACT:
