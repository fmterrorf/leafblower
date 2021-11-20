defmodule Mix.Tasks.GenerateKeyedCards do
  use Mix.Task

  def run(_) do
    Leafblower.Deck.cards() |> IO.inspect()
  end

end
