defmodule Leafblower.Deck.Helpers do
  def load_cards() do
    for item <-
          Application.app_dir(:leafblower, "priv")
          |> Path.join("cards_against.json")
          |> File.read!()
          |> Jason.decode!(),
        into: %{} do
      {item["name"],
       %{white: key_with_text_hash(item["white"]), black: key_with_text_hash(item["black"])}}
    end
  end

  defp key_with_text_hash(items) do
    for %{"text" => text} = item <- items, into: %{} do
      id = :crypto.hash(:sha256, text) |> Base.encode16() |> String.downcase()
      {id, Map.put(item, "id", id)}
    end
  end

  def card_ids_by_card_pack(cards) do
    for {name, %{white: white, black: black}} <- cards, into: %{} do
      {name, %{white: Map.keys(white) |> MapSet.new(), black: Map.keys(black) |> MapSet.new()}}
    end
  end

  def flatten_cards(cards, :white) do
    Enum.flat_map(cards, fn {_key, %{white: white}} -> white end)
    |> Enum.into(%{})
  end

  def flatten_cards(cards, :black) do
    Enum.flat_map(cards, fn {_key, %{black: black}} -> black end)
    |> Enum.into(%{})
  end
end

defmodule Leafblower.Deck do
  @cards Leafblower.Deck.Helpers.load_cards()
  @all_black_cards Leafblower.Deck.Helpers.flatten_cards(@cards, :black)
  @all_white_cards Leafblower.Deck.Helpers.flatten_cards(@cards, :white)
  @card_ids_by_card_pack Leafblower.Deck.Helpers.card_ids_by_card_pack(@cards)
  @type t :: %{white: MapSet.t(binary()), black: MapSet.t(binary())}

  @doc """
  Deals black card to players
  """
  def deal_white_card(deck, player_ids, player_cards, cards_per_player) do
    player_count = MapSet.size(player_ids)
    new_cards = Enum.take_random(deck.white, player_count * cards_per_player)

    player_cards =
      player_ids
      |> Enum.zip(Enum.chunk_every(new_cards, cards_per_player))
      |> Enum.reduce(player_cards, fn {key, val}, acc ->
        Map.update!(acc, key, &MapSet.union(&1, MapSet.new(val)))
      end)

    {
      player_cards,
      %{deck | white: MapSet.difference(deck.white, MapSet.new(new_cards))}
    }
  end

  def take_black_card(deck) do
    [taken_card] = Enum.take(deck.black, 1)
    black = MapSet.delete(deck.black, taken_card)
    {taken_card, %{deck | black: black}}
  end

  def card(id, :black) do
    @all_black_cards[id]
  end

  def card(id, :white) do
    @all_white_cards[id]
  end

  def card_packs do
    Map.keys(@card_ids_by_card_pack)
  end

  def get_cards(packs) when is_list(packs) do
    cards =
      Map.take(@card_ids_by_card_pack, packs)
      |> Map.values()

    black = Enum.flat_map(cards, & &1.black) |> MapSet.new()
    white = Enum.flat_map(cards, & &1.white) |> MapSet.new()
    %{black: black, white: white}
  end

  def get_cards(pack), do: get_cards([pack])
  def get_cards, do: get_cards("CAH Base Set")
end
