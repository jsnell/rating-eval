#!/usr/bin/perl -lw

BEGIN { push @INC, "lib"; }

use strict;
no indirect;

use Analyze::RatingData;
use DB::Connection;
use File::Slurp;
use Getopt::Long;
use JSON;
use List::Util qw(min max sum);

my $cutoff = '2015-06-01';

if (!GetOptions("cutoff=s" => \$cutoff)) {
    exit 1;
}

sub update_rating_data {
    my ($dbh, $tag, $part) = @_;
    my $f = "data/rating-data-$tag.json";
    my $data = read_rating_data $dbh, $part;
    open my $fh, ">", "$f";
    print $fh encode_json $data;
}

sub get_partitioner {
    my ($mode) = @_;

    sub {
        my ($record) = @_;
        my $match = $record->{last_update} lt $cutoff; 
        return ($match == ($mode eq 'train'));
    }
}

my $dbh = get_db_connection;
my $training_data = update_rating_data $dbh, 'train', get_partitioner 'train';
my $eval_data = update_rating_data $dbh, 'eval', get_partitioner 'evaluate';

