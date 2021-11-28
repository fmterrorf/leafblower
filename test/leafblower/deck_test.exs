defmodule Leafblower.DeckTest do
  use ExUnit.Case
  alias Leafblower.Deck

  test "deal_white_card/4 deals whitecard properly" do
    deck =
      Deck.new(
        MapSet.new(),
        MapSet.new(["a", "b", "c", "d", "e", "f"])
      )

    {player_cards, deck} =
      Deck.deal_white_card(
        deck,
        %{"player_id1" => MapSet.new(["z"]), "player_id2" => MapSet.new()},
        1
      )

    assert MapSet.size(player_cards["player_id1"]) == 1
    assert MapSet.size(player_cards["player_id2"]) == 1
    assert MapSet.size(deck.white) == 5
  end
end
