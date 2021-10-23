defmodule Leafblower.GameCache do
  use DynamicSupervisor
  alias Leafblower.{GameStatem, GameTicker}

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def new_game(arg) do
    # Maybe consider storing the pids into ETS so that we can look it up later
    ticker =
      DynamicSupervisor.start_child(
        __MODULE__,
        {GameTicker, [id: Keyword.fetch!(arg, :id)]}
      )
      |> get_pid()

    DynamicSupervisor.start_child(
      __MODULE__,
      {GameStatem, arg ++ [ticker: ticker]}
    )
    |> get_pid()
  end

  def find_game(id) do
    case Leafblower.ProcessRegistry.lookup({GameStatem, id}) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  defp get_pid(start_child_result) do
    case start_child_result do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
