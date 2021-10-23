defmodule LeafblowerWeb.GameLive do
  use LeafblowerWeb, :live_view
  alias Leafblower.{GameStatem, GameCache, GameTicker}

  @type assigns :: %{
          game: pid(),
          game_state: GameStatem.state() | nil,
          game_data: GameStatem.data() | nil,
          user_id: binary(),
          joined_in_game?: boolean(),
          countdown_left: non_neg_integer() | nil
        }

  @impl true
  def mount(params, session, socket) do
    GameCache.find_game(params["id"])
    |> do_mount(params, session, socket)
  end

  def do_mount(game, _params, %{"current_user_id" => user_id}, socket) when game != nil do
    {state, data} = GameStatem.get_state(game)

    if connected?(socket) do
      GameStatem.subscribe(data.id)
      GameTicker.subscribe(data.id)
    end

    {:ok,
     assign(socket,
       game: game,
       game_state: state,
       game_data: data,
       user_id: user_id,
       countdown_left: nil,
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

  def handle_info({:ticker_ticked, countdown_left}, socket) do
    {:noreply, assign(socket, countdown_left: countdown_left)}
  end

  @impl true
  def handle_event("join_game", _value, socket) do
    %{game: game, user_id: user_id} = socket.assigns
    :ok = GameStatem.join_player(game, user_id)
    {:noreply, assign(socket, joined_in_game?: true)}
  end

  @impl true
  def handle_event("start_game", _value, socket) do
    %{game: game, user_id: user_id} = socket.assigns
    :ok = GameStatem.start_round(game, user_id)
    {:noreply, socket}
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
    <%= if @game_data.leader_player_id == @user_id and @game_state in [:waiting_for_players, :round_ended] do %>
      <button {[disabled: map_size(@game_data.players) < @game_data.min_player_count]} phx-click="start_game">
        Start Game
      </button>
    <% end %>

    <div><%= Atom.to_string(@game_state) %></div>

    <%= if @countdown_left != nil and @game_state == :round_started_waiting_for_response do %>
      <div>Countdown: <%= @countdown_left %></div>
    <% end %>

    <ul>
      <%= for {id, player} <- @game_data.players do %>
        <li id={id}><%= player.name %></li>
      <% end %>
    </ul>
    """
  end
end
