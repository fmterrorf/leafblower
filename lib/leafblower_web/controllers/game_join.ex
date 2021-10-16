defmodule LeafblowerWeb.GameNewLive do
  use LeafblowerWeb, :live_view
  alias Leafblower.{GameStatem}

  @impl true
  def mount(params, _session, socket) do
    id = params["id"]

    {state, data} =
      id
      |> GameStatem.via_tuple()
      |> GameStatem.get_state()

    if connected?(socket), do: GameStatem.subscribe(id)

    {:ok, assign(socket, game_state: state, game_data: data)}
  end

  @impl true
  def handle_info({:game_state_changed, state, data}, socket) do
    {:noreply, assign(socket, game_state: state, game_data: data)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    Loading
    """
  end
end
