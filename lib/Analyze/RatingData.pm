#!/usr/bin/perl -wl

package Analyze::RatingData;
use Exporter::Easy (EXPORT => ['read_rating_data']);

use strict;

sub get_finished_game_results {
    my ($dbh, $secret, %params) = @_;

    my %res = ( error => '', results => [] );

    $params{id_pattern} ||= '%';
    if ($params{year} and $params{month}) {
        if ($params{day}) {
            $params{range_end} = '1 day';
        } else {
            $params{day} = '01';
            $params{range_end} = '1 month';
        }
        $params{range_start} = "$params{year}-$params{month}-$params{day}";
    } else {
        $params{range_start} = "1970-01-01";
        $params{range_end} = "100 years";
    }

    my $rows = $dbh->selectall_arrayref(
        "select game, faction_full as faction, vp, rank, start_order, faction_player as username, game.player_count, game.last_update, game.non_standard, game.base_map, game_role.dropped, game.game_options as options from game_role left join game on game=game.id where game.finished and game.round=6 and not game.aborted and not game.exclude_from_stats and game.id like ? and game.last_update between ? and date(?) + ?::interval",
        { Slice => {} },
        $params{id_pattern},
        $params{range_start},
        $params{range_start},
        $params{range_end});

    if (!$rows) {
        $res{error} = "db error";
    } else {
        for my $row (@{$rows}) {
            push @{$res{results}}, $row;
        }
    }

    %res;
}

sub handle_game {
    my ($res, $output, $players, $factions) = @_;

    my $faction_count = keys %{$res->{factions}};
    return if $faction_count < 3;

    my %player_ids = (); 
    for (values %{$res->{factions}}) {
        # Require usernames (some legacy data in DB will just have an email
        # address).
        return if !$_->{username};

        # Reject games where same player controls multiple factions.
        if ($player_ids{$_->{username}}++) {
            return;
        }
    }

    # Sort by vp, so that we can always assume the "a" record was at least
    # as good as "b".
    my @f = sort { $b->{vp} <=> $a->{vp} } values %{$res->{factions}};

    my @factions = values %{$res->{factions}};
    for my $f (@factions) {
        $factions->{$f->{faction}}{games}++;
        $players->{$f->{username}}{games}++;
    }

    for my $i (0..$#f) {
        my $f1 = $f[$i];

        for my $j (($i+1)..$#factions) {
            my $f2 = $f[$j];
            my $record = {
                a => { username => $f1->{username}, faction => $f1->{faction}, vp => $f1->{vp}, dropped => $f1->{dropped} },
                b => { username => $f2->{username}, faction => $f2->{faction}, vp => $f2->{vp}, dropped => $f2->{dropped}},
                last_update => $res->{last_update},
                base_map => $f1->{base_map},
                id => $res->{id},
            };
            push @{$output}, $record;
        }
    }
}

sub read_rating_data {
    my ($dbh, $filter) = @_;
    my @output = ();
    my %players = ();
    my %factions = ();

    my %results = get_finished_game_results $dbh, '';
    my %games = ();
    my %faction_count = ();

    for (@{$results{results}}) {
        next if $filter and !$filter->($_);

        next if $_->{faction} =~ /^(nofaction|player)/;

        $games{$_->{game}}{factions}{$_->{faction}} = $_;
        $games{$_->{game}}{id} = $_->{game};
        $games{$_->{game}}{last_update} = $_->{last_update};
        $faction_count{$_->{faction}}++;
    }

    for (values %games) {
        my $ok = 1;

        if ($ok) {
            handle_game $_, \@output, \%players, \%factions;
        }
    }

    for (keys %players) {
        $players{$_}{username} = $_;
    }
    
    return {
        players => \%players,
        factions => \%factions,
        results => \@output 
    };
}

1;

