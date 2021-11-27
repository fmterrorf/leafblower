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
        MapSet.new(["player_id1", "player_id2"]),
        %{"player_id1" => MapSet.new(), "player_id2" => MapSet.new()},
        2
      )

    assert MapSet.size(player_cards["player_id1"]) == 2
    assert MapSet.size(player_cards["player_id2"]) == 2
    assert MapSet.size(deck.white) == 2
  end
end
