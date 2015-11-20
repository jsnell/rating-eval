#!/usr/bin/ruby

require 'date'
require 'json'
require 'whole_history_rating'

@iters = Integer(ARGV[0])

File.open('data/rating-data-train.json') do |stream|
  @training = JSON.load(stream)
end

File.open('data/rating-data-eval.json') do |stream|
  @eval = JSON.load(stream)
end

@whr = WholeHistoryRating::Base.new
@results = @training['results']
@results.sort_by! do |elem|
  elem['last_update']
end

players_ranked = {}
@results.each do |elem|
  if elem['a']['vp'] < elem['b']['vp'] then
    res = 'W'
  elsif elem['a']['vp'] > elem['b']['vp']
    res = 'B'
  else
    next
  end
  
  players_ranked[elem['a']['username']] = true
  players_ranked[elem['b']['username']] = true
  date = Date.parse(elem['last_update'])
  
  @whr.create_game(elem['a']['username'],
                   elem['b']['username'],
                   res,
                   date.jd,
                   0)
end

@whr.iterate(@iters)

@user_rating = {}
players_ranked.keys.each do |username|
  @user_rating[username] = @whr.ratings_for_player(username)[-1][1]
end

@eval['results'].each do |elem|
  next if elem['a']['dropped'] == 1
  next if elem['b']['dropped'] == 1

  a_player = elem['a']['username']
  b_player = elem['b']['username']
  a_faction = elem['a']['faction']
  b_faction = elem['b']['faction']
  
  if elem['a']['vp'] == elem['b']['vp'] then
    res = 0.5
  else
    res = 1
  end

  a_elo = @user_rating[a_player] || 0
  b_elo = @user_rating[b_player] || 0
  diff = a_elo - b_elo
  expect = 1.0 / (1 + 10 ** ( -diff / 400.0))
  print "#{elem['id']},#{a_player},#{b_player},#{a_faction},#{b_faction},#{expect},#{res},#{a_elo},#{b_elo}\n";
end
