#!/usr/bin/perl -lw

BEGIN { push @INC, "lib" }

use strict;
no indirect;

use Analyze::Elo;
use File::Slurp;
use Getopt::Long;
use JSON;
use List::Util qw(min max sum);

my $iters = 3;
my $separate_maps = 0;
my $fw = 1;
my $pw = 1;
my $ps = 16;
my $batch_submatches = 0;
my $min_games = 5;
my $ignore_dropped = 0;
my $hack = 400;

if (!GetOptions("iters=s" => \$iters,
                "pot-size=s" => \$ps,
                "min-games=s" => \$min_games,
                "fw=s" => \$fw,
                "pw=s" => \$pw,
                "hack=s" => \$hack,
                "ignore-dropped" => \$ignore_dropped,
                "batch-submatches" => \$batch_submatches,
                "separate-maps" => \$separate_maps)) {
    exit 1;
}

my $elo_settings = {
    iters => $iters,
    faction_weigth => $fw,
    player_weigth => $pw,
    pot_size => $ps,
    min_games => $min_games,
    min_output_games => 1,
    ignore_dropped => $ignore_dropped,
    batch_submatches => $batch_submatches,
};

sub rewrite {
    my ($rating_data) = @_;

    # If --separate-maps is passed, maintain per-map ratings for each
    # faction.
    if (!$separate_maps) {
        return $rating_data;
    }

    $rating_data->{factions} = {};

    for (@{$rating_data->{results}}) {
        my $bm = $_->{base_map} // '126fe960806d587c78546b30f1a90853b1ada468';
        $_->{a}{faction} .= "/$bm";
        $_->{b}{faction} .= "/$bm";
        for ($_->{a}{faction}, $_->{b}{faction}) {
            $rating_data->{factions}{$_}{games}++;
        }
    }

    $rating_data;
}    

sub get_results {
    my ($tag) = @_;
    my $f = "data/rating-data-$tag.json";
    decode_json read_file $f;
}

sub get_ratings {
    my $training_data = get_results 'train';
    my $matchups_train = rewrite $training_data;
    my $ratings = compute_elo $matchups_train, $elo_settings;
}

sub print_win_probabilities {
    my ($ratings, $matchups) = @_;
    my $players = $ratings->{players};
    my $factions = $ratings->{factions};

    for my $matchup (@{$matchups->{results}}) {
        my $u1 = $matchup->{a}{username};
        my $u2 = $matchup->{b}{username};

        my $f1 = $matchup->{a}{faction};
        my $f2 = $matchup->{b}{faction};

        my $r1 = $players->{$u1}{score};
        my $r2 = $players->{$u2}{score};
        if (!$r1 or !$r2) {
            next;
        }
        next if $matchup->{a}{dropped} or $matchup->{b}{dropped};

        $r1 *= $pw;
        $r2 *= $pw;
        
        next if !$factions->{$f1}{score};
        next if !$factions->{$f2}{score};

        $r1 += $factions->{$f1}{score} * $fw;
        $r2 += $factions->{$f2}{score} * $fw;

        my $rdiff = $r1 - $r2;

        my $expect = 1 / (1 + 10 ** ( -$rdiff / $hack));
        my $res;
        
        if ($matchup->{a}{vp} == $matchup->{b}{vp}) {
            $res = 0.5;
        } else {
            $res = 1;
        }

        print "$matchup->{id},$u1,$u2,$f1,$f2,$expect,$res";
    }
}

print_win_probabilities get_ratings, rewrite get_results 'eval';
