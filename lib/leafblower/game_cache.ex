defmodule Leafblower.GameSupervisor do
  use Horde.DynamicSupervisor
  alias Leafblower.{GameStatem, GameTicker}

  def start_link(_) do
    Horde.DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def new_game(arg) do
    {:ok, _} =
      Horde.DynamicSupervisor.start_child(
        __MODULE__,
        {GameTicker, Keyword.take(arg, [:id])}
      )

    Horde.DynamicSupervisor.start_child(
      __MODULE__,
      {GameStatem, arg}
    )
  end

  def find_game(id) do
    case Leafblower.ProcessRegistry.lookup({GameStatem, id}) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  @impl true
  def init(_) do
    Horde.DynamicSupervisor.init(strategy: :one_for_one, members: :auto)
  end
end
