require 'rubygems'
require 'sinatra'


set :sessions, true

BLACKJACK_AMOUNT = 21
DEALER_MIN_HIT = 17
INITIAL_POT_AMOUNT = 500

helpers do
  def calculate_total(cards) # cards is [["H", "3"], ["D", "J"], ... ]
    arr = cards.map{|element| element[1]}

    total = 0
    arr.each do |a|
      if a == "A"
        total += 11
      else
        total += a.to_i == 0 ? 10 : a.to_i
      end
    end

    #correct for Aces
    arr.select{|element| element == "A"}.count.times do
      break if total <= BLACKJACK_AMOUNT
      total -= 10
    end

    total
  end

  def card_image(card) # ['H', '4']
    suit = case card[0]
      when 'H' then 'hearts'
      when 'D' then 'diamonds'
      when 'C' then 'clubs'
      when 'S' then 'spades'
    end

    value = card[1]
    if ['J', 'Q', 'K', 'A'].include?(value)
      value = case card[1]
        when 'J' then 'jack'
        when 'Q' then 'queen'
        when 'K' then 'king'
        when 'A' then 'ace'
      end
    end

    "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end

  def winner!(msg)
    @play_again = true
    @show_hit_or_stay_buttons = false
    session[:player_pot] = session[:player_pot] + session[:player_bet]
    @winner = "<h4>#{session[:player_name]} ganaste!!</h4> #{msg}"
  end

  def condition21!(msg)
    @show_hit_or_stay_buttons = false
    @condition21 = "<h4>Atinaste 21!! Pero no te acontentes tanto.</h4> #{msg}"
  end

  def loser!(msg)
    @play_again = true
    @show_hit_or_stay_buttons = false
    session[:player_pot] = session[:player_pot] - session[:player_bet]
    @loser = "<h4>#{session[:player_name]}, perdiste!</h4> #{msg}"
  end

  def tie!(msg)
    @play_again = true
    @show_hit_or_stay_buttons = false
    @winner = "<h4>Es un empate!</h4> #{msg}"
  end
end

before do
  @show_hit_or_stay_buttons = true
end

get '/' do
  if session[:player_name]
    redirect '/game'
  else
    redirect '/new_player'
  end
end

get '/new_player' do
  session[:player_pot] = INITIAL_POT_AMOUNT
  erb :new_player
end

post '/new_player' do

  if params[:player_name].empty?
    @error = "No manches, tienes que meter un nombre!"
    halt erb(:new_player)
  end

  session[:player_name] = params[:player_name]
  redirect '/bet'
end

get '/bet' do
  session[:player_bet] = nil
  erb :bet
end

post '/bet' do
  if params[:bet_amount].nil? || params[:bet_amount].to_i == 0
    @error = "Andale, mete una apuesta! No me dejes vestido y alborotado."
    halt erb(:bet)
  elsif params[:bet_amount].to_i > session[:player_pot]
    @error = "No manches! No puedes apostar mas de los ($#{session[:player_pot]}) que tienes."
    halt erb(:bet)
  else #happy path
    session[:player_bet] = params[:bet_amount].to_i
    redirect '/game'
  end
end

get '/game' do
  session[:turn] = session[:player_name]

  # create a deck and put it in session
  suits = ['H', 'D', 'C', 'S']
  values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
  session[:deck] = suits.product(values).shuffle! # [ ['H', '9'], ['C', 'K'] ... ]

  # deal cards
  session[:dealer_cards] = []
  session[:player_cards] = []
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop

  erb :game
end

post '/game/player/hit' do
  session[:player_cards] << session[:deck].pop

  player_total = calculate_total(session[:player_cards])

  if player_total == BLACKJACK_AMOUNT
    condition21!("Aun le toca su turno al crupier.")
    @show_dealer_hit_button = true
  elsif player_total > BLACKJACK_AMOUNT
    loser!("Desculpa #{session[:player_name]}, pero te pasaste con un total de #{player_total}.")
  end

  erb :game, layout: false
end

post '/game/player/stay' do
  @success = "#{session[:player_name]}, decidiste plantarte."
  @show_hit_or_stay_buttons = false
  redirect '/game/dealer'
end

get '/game/dealer' do
  session[:turn] = "dealer"
  @show_hit_or_stay_buttons = false

  # decision tree
  dealer_total = calculate_total(session[:dealer_cards])
  player_total = calculate_total(session[:player_cards])

  if dealer_total == BLACKJACK_AMOUNT && player_total == BLACKJACK_AMOUNT
    redirect '/game/compare'
  elsif dealer_total == BLACKJACK_AMOUNT
    loser!("El crupier saco un Blackjack.")
  elsif dealer_total > BLACKJACK_AMOUNT
    winner!("El crupier se paso con un total de #{dealer_total}.")
  elsif dealer_total >= DEALER_MIN_HIT #17, 18, 19, 20
    # dealer stays
    redirect '/game/compare'
  else
    # dealer hits
    @show_dealer_hit_button = true
  end

  erb :game, layout: false
end

post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer'
end

get '/game/compare' do
  @show_hit_or_stay_buttons = false

  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])

  if player_total == BLACKJACK_AMOUNT && dealer_total == BLACKJACK_AMOUNT
    tie!("#{session[:player_name]}, tu y el crupier sacaron un total de #{player_total}, osea, Blackjack!")    
  elsif player_total < dealer_total
    loser!("#{session[:player_name]} te plantaste con #{player_total}, y el crupier se planto con #{dealer_total}.")
  elsif player_total > dealer_total
    winner!("#{session[:player_name]} te plantaste con #{player_total}, y el crupier se planto con #{dealer_total}.")
  elsif player_total == BLACKJACK_AMOUNT
    winner!("Felicidades #{session[:player_name]}, sacaste un Blackjack!!") 
  else
    tie!("#{session[:player_name]}, tu y el crupier sacaron un total de #{player_total}.") 
  end

  erb :game, layout: false
end

get '/game_over' do
  erb :game_over
end



