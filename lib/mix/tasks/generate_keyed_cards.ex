defmodule Mix.Tasks.GenerateKeyedCards do
  use Mix.Task

  def run(_) do
    Leafblower.Deck.card_packs() |> IO.inspect()
  end

end
