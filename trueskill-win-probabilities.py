#!/usr/bin/python

import argparse
import math
import json
import os
import sys

import trueskill

parser = argparse.ArgumentParser()
parser.add_argument("--faction-weight", default=1.0, type=float)
parser.add_argument("--beta", default=200, type=int)
# It's quite amazing that a library as baroque as argparse doesn't
# have any support for normal boolean flags. Instead you get this
# verbose gibberish where you get to repeat the name of the flag four
# times.
parser.add_argument("--output-win-probabilities",
                    dest='output_win_probabilities',
                    action='store_true')
parser.add_argument("--no-output-win-probabilities",
                    dest='output_win_probabilities',
                    action='store_false')
parser.add_argument("--output-ratings", dest='output_ratings',
                    action='store_true')
parser.add_argument("--no-output-ratings", dest='output_ratings',
                    action='store_false')
parser.add_argument("--separate-maps", default=False,
                    action='store_true')
parser.add_argument("--ignore-dropped", default=False,
                    action='store_true')
options = parser.parse_args()

# Rebuild the game as a unit from the pairwise matchups.
class Game:
    def __init__(self, r):
        self.id = r['id']
        self.last_update = r['last_update']
        self.results = {}

    def add(self, result, players, factions):
        key = result['faction']
        if result['dropped'] and options.ignore_dropped:
            return
        if not self.results.get(key):
            self.results[key] = result
            result['player_ref'] = players[result['username']]
            result['faction_ref'] = factions[result['faction']]

class Ratings:
    def __init__(self, data):
        self.results = data['results']
        self.factions = data['factions']
        self.players = data['players']
        self.games = {}
        for f in self.factions.values():
            f['rating'] = trueskill.Rating()
        for p in self.players.values():
            p['rating'] = trueskill.Rating()
        for r in self.results:
            game = self.games.get(r['id'])
            if not game:
                game = self.games[r['id']] = Game(r)
            game.add(r['a'], self.players, self.factions)
            game.add(r['b'], self.players, self.factions)

    def compute(self):
        games = sorted(self.games.values(),
                       key=lambda g: g.last_update)
        for g in games:
            results = sorted(g.results.values(),
                             key=lambda res: -res['vp'])
            if len(results) < 2:
                continue
            teams = []
            ranks = []
            weights = []
            rank = 0
            prev = None
            for res in results:
                vp = res['vp']
                if prev and vp < prev:
                    rank += 1
                prev = vp
                ranks.append(rank)
                weights.append((1, options.faction_weight))
                teams.append((res['player_ref']['rating'],
                              res['faction_ref']['rating']))
            new = trueskill.rate(teams, ranks, weights)
            i = 0
            for res in results:
                (res['player_ref']['rating'],
                 res['faction_ref']['rating']) = new[i]
                i += 1

    def print_ratings(self):
        factions = {}
        players = {}
        result = { 'factions': factions, 'players': players }
        for name in self.factions:
            f = self.factions[name]
            rating = f['rating']
            factions[name] = {
                'rating': rating.mu,
                'range': rating.sigma
            }
        for p in self.players.values():
            rating = p['rating']
            players[p['username']] = {
                'rating': rating.mu,
                'range': rating.sigma
            }
        print json.dumps(result)

def rewrite(json):
    if not options.separate_maps:
        return json

    for res in json['results']:
        m = (res['base_map'] or "126fe960806d587c78546b30f1a90853b1ada468")
        res['a']['faction'] += "/" + m
        res['b']['faction'] += "/" + m
        json['factions'][res['a']['faction']] = {}
        json['factions'][res['b']['faction']] = {}
    return json

backend = None
env = trueskill.TrueSkill(mu=1000, sigma=350, beta=options.beta, draw_probability=0.0, backend=backend)
env.make_as_global()

def get_ratings():
    training_data = rewrite(
        json.load(open("data/rating-data-train.json", "r")))
    ratings = Ratings(training_data)
    ratings.compute()
    return ratings

def print_win_probabilities(ratings, matchups):
    (cdf, pdf, ppf) = trueskill.backends.choose_backend(backend)

    # Given the ratings for player/faction combinations A and B, what's
    # the probability that A wins?
    def win_probability(a, b):
        deltaMu = sum([x.mu * x.weight for x in a]) - sum([x.mu * x.weight for x in b])
        # Should we do something with faction weights here? I think in
        # thery we might want to use it to adjust the result after squaring,
        # and likewise adjust playercount to use fractional players if
        # necessary. In practice it shouldn't really matter, since the
        # faction variances are tiny.
        sumSigma = sum([x.sigma ** 2 for x in a]) + sum([x.sigma ** 2 for x in b])
        playerCount = len(filter(lambda x: x.weight != 0, a)) + len(filter(lambda x: x.weight != 0, b))
        denominator = math.sqrt(playerCount * (options.beta ** 2) + sumSigma)
        return cdf(deltaMu / denominator)

    for f in ratings.factions.values():
        f['rating'].weight = options.faction_weight
    for p in ratings.players.values():
        p['rating'].weight = 1.0
    
    for res in matchups['results']:
        a = res['a']
        b = res['b']

        # We don't try to predict players dropping out...
        if a['dropped'] or b['dropped']:
            continue

        # No data at all on one of the players
        pa = ratings.players.get(a['username'], None)
        pb = ratings.players.get(b['username'], None)
        if not pa or not pb:
            continue
        # No data at all on one of the factions.
        fa = ratings.factions.get(a['faction'], None)
        fb = ratings.factions.get(b['faction'], None)
        if not fa or not fb:
            continue

        expect = win_probability([pa['rating'], fa['rating']],
                                 [pb['rating'], fb['rating']])
        
        # A/B are ordered by VP, so A either won or it was a tie
        actual = 1
        if a['vp'] == b['vp']:
            actual = 0.5
            
        fields = [res['id'], a['username'], b['username'],
                  a['faction'], b['faction'],
                  str(expect),str(actual)]
        print ",".join(fields)

def main():
    ratings = get_ratings()
    if options.output_ratings:
        ratings.print_ratings()
    if options.output_win_probabilities:
        eval_data = rewrite(json.load(open("data/rating-data-eval.json", "r")))
        print_win_probabilities(ratings, eval_data)

if __name__ == '__main__':
    main()
