#!/bin/bash

set -e

OUTDIR=out/
mkdir -p $OUTDIR

function elo {
    id=$1;
    flags=$2;
    echo "elo $id"

    F=$OUTDIR/elo-$id.csv
    
    if [ ! -f $F ]; then
        rm -f $F
        perl elo-win-probabilities.pl $flags > $F.tmp
        mv $F.tmp $F
    else
        echo "  already done"
    fi
}

function trueskill {
    id=$1;
    flags=$2;
    echo "trueskill $id"

    F=$OUTDIR/trueskill-$id.csv
    
    if [ ! -f $F ]; then   
        rm -f $F
        PYTHONPATH=trueskill/ python trueskill-win-probabilities.py --output-win-probabilities $flags > $F.tmp
        mv $F.tmp $F
    else
        echo "  already done"
    fi
}

function whr {
    id=$1;
    flags=$2;
    echo "whr $id"

    F=$OUTDIR/whr-$id.csv
    
    if [ ! -f $F ]; then   
        rm -f $F
        ruby -Iwhole_history_rating/lib whr-win-probabilities.rb $flags > $F.tmp
        mv $F.tmp $F
    else
        echo "  already done"
    fi
}

elo "none" "--iter=1 --fw=0 --pot-size=0 --min-games=1";
elo "original-k8" "--iter=1 --fw=0 --pot-size=8 --min-games=1";
elo "original-k16" "--iter=1 --fw=0 --pot-size=16 --min-games=1";
elo "original-k24" "--iter=1 --fw=0 --pot-size=24 --min-games=1";
elo "original-k32" "--iter=1 --fw=0 --pot-size=32 --min-games=1";

elo "original-k8-min5" "--iter=1 --fw=0 --pot-size=8 --min-games=5";
elo "original-k16-min5" "--iter=1 --fw=0 --pot-size=16 --min-games=5";
elo "original-k24-min5" "--iter=1 --fw=0 --pot-size=24 --min-games=5";
elo "original-k32-min5" "--iter=1 --fw=0 --pot-size=32 --min-games=5";

elo "iter-k4-min5" "--iter=3 --fw=0 --pot-size=4 --min-games=5";
elo "iter-k8-min5" "--iter=3 --fw=0 --pot-size=8 --min-games=5";
elo "iter-k16-min5" "--iter=3 --fw=0 --pot-size=16 --min-games=5";
elo "iter-k24-min5" "--iter=3 --fw=0 --pot-size=24 --min-games=5";

elo "current-k8" "--pot-size=8";
elo "current-k16" "";
elo "current-k24" "--pot-size=24";

elo "current-k16-min1" "--min-games=1";

elo "separate-maps-k8" "--separate-maps --pot-size=8";
elo "separate-maps-k16" "--separate-maps --pot-size=16";

elo "separate-maps-k8-nd" "--separate-maps --pot-size=8 --ignore-dropped";
elo "separate-maps-k16-nd" "--separate-maps --pot-size=16 --ignore-dropped";

elo "separate-maps-k16-fw-0.1" "--separate-maps --pot-size=16 --fw=0.1";
elo "separate-maps-k16-fw-0.2" "--separate-maps --pot-size=16 --fw=0.2";
elo "separate-maps-k16-fw-0.5" "--separate-maps --pot-size=16 --fw=0.5";
elo "separate-maps-k16-fw-2" "--separate-maps --pot-size=16 --fw=2";

elo "separate-maps-k16-batch" "--separate-maps --pot-size=16 --batch-submatches";

elo "separate-maps-k16-pfw0" "--separate-maps --pot-size=16 --pfw=0";
elo "separate-maps-k16-pfw1" "--separate-maps --pot-size=16 --pfw=1";
elo "separate-maps-k16-pfw0.5" "--separate-maps --pot-size=16 --pfw=0.5";

trueskill "default" ""
trueskill "no-factions" "--faction-weight=0"
trueskill "nd" "--ignore-dropped"

trueskill "separate-maps" "--separate-maps"
trueskill "separate-maps-nd" "--separate-maps --ignore-dropped"

trueskill "separate-maps-fw-0.2" "--separate-maps --faction-weight=0.2"
trueskill "separate-maps-fw-0.5" "--separate-maps --faction-weight=0.5"
trueskill "separate-maps-fw-1.5" "--separate-maps --faction-weight=1.5"


whr "iters-1" "1"
whr "iters-2" "2"
whr "iters-5" "5"
whr "iters-10" "10"
whr "iters-20" "20"
whr "iters-50" "50"
# whr "iters-100" "100"
# whr "iters-200" "200"
