defmodule LeafblowerWeb.GameLive do
  use LeafblowerWeb, :live_view
  alias Leafblower.{GameStatem, GameCache, ETSKv}

  @type assigns :: %{
          game: pid(),
          game_state: GameStatem.state() | nil,
          game_data: GameStatem.data() | nil,
          user_id: binary(),
          joined_in_game?: boolean()
        }

  @impl true
  def mount(params, session, socket) do
    GameCache.find_game(params["id"])
    |> do_mount(params, session, socket)
  end

  def do_mount(game, _params, %{"current_user_id" => user_id}, socket) when game != nil do
    {state, data} = GameStatem.get_state(game)
    if connected?(socket), do: GameStatem.subscribe(data.id)

    {:ok,
     assign(socket,
       game: game,
       game_state: state,
       game_data: data,
       user_id: user_id,
       joined_in_game?: Map.has_key?(data.players, user_id)
     )}
  end

  def do_mount(nil, _params, _session, socket) do
    {:ok,
     socket
     |> put_flash(:info, "Game not found")
     |> redirect(to: Routes.live_path(socket, LeafblowerWeb.GameSplashLive))}
  end

  @impl true
  def handle_info({:game_state_changed, state, data}, socket) do
    {:noreply, assign(socket, game_state: state, game_data: data)}
  end

  @impl true
  def handle_event("join_game", _value, socket) do
    %{game: game, user_id: user_id} = socket.assigns
    :ok = GameStatem.join_player(game, user_id)
    {:noreply, assign(socket, joined_in_game?: true)}
  end

  @impl true
  @spec render(assigns()) :: Phoenix.LiveView.Rendered.t()

  def render(%{joined_in_game?: false} = assigns) do
    ~H"""
    <button phx-click="join_game">Join Game</button>
    """
  end

  def render(assigns) do
    ~H"""
    <ul>
    <%= for {_id, player} <- @game_data.players do %>
      <li><%= player.name %></li>
    <% end %>
    </ul>
    """
  end
end
