#!/usr/bin/perl -w

use strict;

use File::Slurp;
use JSON;

sub process {
    my $file = shift;
    my @rows = read_file $file;
    my %rows;

    for (@rows) {
        chomp;
        my ($game, $u1, $u2, $f1, $f2, $expect, $res) =
            split /,/;
        next if !$f2;
        if ($res == 0.5 and $u1 lt $u2) {
            ($u2, $u1) = ($u1, $u2);
        }
        $rows{"$game,$u1,$u2"} = [ $expect, $res ];
    }

    \%rows;
}

sub stats {
    my ($baseline_records, $records) = @_;
    my %counters = ();

    for (keys %{$baseline_records}) {
        my $r1 = $baseline_records->{$_};
        my $r2 = $records->{$_};
        if (!defined $r2->[1] or !defined $r1->[1]) {
            next;
        } elsif ($r2->[1] != $r1->[1]) {
            next;
        }
        my ($expected, $res) = ($r2->[0], $r2->[1]);

        $counters{"error^2"} += ($expected - $res) ** 2;
        $counters{"games"}++;
    }

    \%counters;
}

sub compare {
    my ($baseline_records, $records) = @_;
    my %counters = ();
    my $i = 0;
    
    for (keys %{$baseline_records}) {
        my $r1 = $baseline_records->{$_};
        my $r2 = $records->{$_};
        if (!defined $r2->[1] or !defined $r1->[1]) {
            # die "Inconsistent game: $_\n";
            next;
        } elsif ($r2->[1] != $r1->[1]) {
            die "Odd game: $_ ($r2->[1] != $r1->[1])\n";
            next;
        }

        my ($e1, $e2, $res) = ($r1->[0], $r2->[0], $r1->[1]);
        
        my $em = ($e1 + $e2) / 2;        
        my $ed = abs($e2 - $e1);
        my ($k1, $k2) = qw(base this);
        if ($e1 == $e2) {
            # No bet
            next;
        } elsif ($e1 < $e2) {
            ($k1, $k2) = ($k2, $k1);
            ($e2, $e1) = ($e1, $e2);
        }

        $counters{"count"}{$k1} += $res;
        $counters{"count"}{$k2} += 1 - $res;
        $counters{"bet"}{$k1} += ($res - $em);
        $counters{"bet"}{$k2} += ($em - $res);
        next if $res == 0.5 or $e1 == 0.5 or $e2 == 0.5;

        if ($e1 < 0.5 != $e2 < 0.5) {
            if ($res == 0) {
                $counters{"split-count"}{"$k2"} += 1;
            } else {
                $counters{"split-count"}{"$k1"} += 1;
            }
        }
    }

    \%counters;
}     

sub compare_all {
    my ($records) = @_;
    my %stats = ();
    my $baseline_records = $records->{$ARGV[0]};

    for my $f (@ARGV) {
        $stats{$f}{stats} = stats $baseline_records, $records->{$f};
    }
    for my $f2 (@ARGV[1..$#ARGV]) {
        $stats{$f2}{compare} = compare $baseline_records, $records->{$f2};
    }
    print encode_json \%stats;
}

sub main {
    my %records;

    for (@ARGV) {
        $records{$_} = process $_;
    }

    compare_all \%records;
}

main;
