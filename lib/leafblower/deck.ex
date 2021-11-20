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
      id = :crypto.hash(:sha256, text) |> Base.encode16()
      {id, Map.put(item, "id", id)}
    end
  end
end

defmodule Leafblower.Deck do
  @cards Leafblower.Deck.Helpers.load_cards()

  @spec deal_card(MapSet.t(binary), %{binary() => MapSet.t(binary())}) ::
          {MapSet.t(binary), %{binary() => MapSet.t(binary())}}
  def deal_card(deck, player_cards) do
    player_size = map_size(player_cards)
    new_cards = Enum.take_random(deck, player_size) |> MapSet.new()

    {
      MapSet.difference(deck, new_cards),
      Map.keys(player_cards)
      |> Enum.zip(new_cards)
      |> Enum.reduce(player_cards, fn {key, val}, acc ->
        Map.update!(acc, key, &MapSet.put(&1, val))
      end)
    }
  end

  def cards do
    @cards
  end
end
