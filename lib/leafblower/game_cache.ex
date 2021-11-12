defmodule Leafblower.GameCache do
  use Horde.DynamicSupervisor
  alias Leafblower.{GameStatem, GameTicker}

  def start_link(init_arg, options \\ []) do
    init_arg = Keyword.merge(init_arg, strategy: :one_for_one, members: :auto)
    options = Keyword.merge(options, name: __MODULE__)
    Horde.DynamicSupervisor.start_link(__MODULE__, init_arg, options)
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
  def init(init_arg) do
    Horde.DynamicSupervisor.init(init_arg)
  end
end
