defmodule LeafblowerWeb.GameLive do
  use LeafblowerWeb, :live_view
  alias Leafblower.{GameStatem, GameCache, GameTicker}

  @type assigns :: %{
          game: pid(),
          game_status: GameStatem.state() | nil,
          game_data: GameStatem.data() | nil,
          user_id: binary(),
          joined_in_game?: boolean(),
          countdown_left: non_neg_integer() | nil,
          is_leader?: boolean()
        }

  @impl true
  def mount(params, session, socket) do
    GameCache.find_game(params["id"])
    |> do_mount(params, session, socket)
  end

  def do_mount(game, _params, %{"current_user_id" => user_id}, socket) when game != nil do
    {status, data} = GameStatem.get_state(game)

    if connected?(socket) do
      GameStatem.subscribe(data.id)
      GameTicker.subscribe(data.id)
    end

    {:ok,
     assign(socket,
       game: game,
       game_status: status,
       game_data: data,
       user_id: user_id,
       countdown_left: nil,
       joined_in_game?: MapSet.member?(data.active_players, user_id),
       is_leader?: data.leader_player_id == user_id
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
    socket =
      case state do
        :round_ended -> assign(socket, countdown_left: nil)
        _ -> socket
      end

    {:noreply, assign(socket, game_status: state, game_data: data)}
  end

  def handle_info({:ticker_ticked, countdown_left}, socket) do
    {:noreply, assign(socket, countdown_left: countdown_left)}
  end

  @impl true
  def handle_event("join_game", %{"join_game" => value}, socket) do
    %{game: game, user_id: user_id} = socket.assigns
    # TODO: Make use of `player_name` in the form
    :ok = GameStatem.join_player(game, user_id, value["player_name"])
    {:noreply, assign(socket, joined_in_game?: true)}
  end

  def handle_event("start_round", _value, socket) do
    %{game: game, user_id: user_id} = socket.assigns
    :ok = GameStatem.start_round(game, user_id)
    {:noreply, socket}
  end

  def handle_event("submit_answer", %{"id" => id}, socket) do
    %{game: game, user_id: user_id} = socket.assigns
    GameStatem.submit_answer(game, user_id, id)
    {:noreply, socket}
  end

  def render_waiting_for_players(active_players, min_player_count, is_leader?) do
    assigns = %{
      disabled: map_size(active_players) < min_player_count,
      is_leader?: is_leader?,
      active_players: active_players
    }

    ~H"""
    <%= if @is_leader? do%>
      <button phx-click="start_round" {[disabled: @disabled]}>Start Game</button>
    <% end %>

    <ul>
      <%= for player <- Enum.map(@active_players, &Leafblower.UserSupervisor.get_user!/1) do %>
        <li id={player.id}><%= player.name %></li>
      <% end %>
    </ul>
    """
  end

  def render_round_started_waiting_for_response(
        player_id,
        active_players,
        round_player_answers,
        countdown_left
      ) do
    assigns = %{
      active_players: active_players,
      round_player_answers: round_player_answers,
      countdown_left: countdown_left,
      disabled: Map.has_key?(round_player_answers, player_id)
    }

    ~H"""
    <%= if @countdown_left != nil do %>
      <pre>Countdown: <%= @countdown_left %></pre>
    <% end %>

    <ul>
      <li id="answer-a"><button {[disabled: @disabled]} phx-click="submit_answer" phx-value-id="a">a</button></li>
      <li id="answer-b"><button {[disabled: @disabled]} phx-click="submit_answer" phx-value-id="b">b</button></li>
      <li id="answer-c"><button {[disabled: @disabled]} phx-click="submit_answer" phx-value-id="c">c</button></li>
      <li id="answer-d"><button {[disabled: @disabled]} phx-click="submit_answer" phx-value-id="d">d</button></li>
    </ul>
    <hr />
    <ul>
      <%= for player <- Enum.map(@active_players, &Leafblower.UserSupervisor.get_user!/1) do %>
        <li id={player.id}><%= player.name %> - <%= if Map.has_key?(@round_player_answers, player.id), do: "✅", else: "⌛"%></li>
      <% end %>
    </ul>
    """
  end

  def render_round_ended(active_players, round_player_answers, is_leader?) do
    assigns = %{
      active_players: active_players,
      round_player_answers: round_player_answers,
      is_leader?: is_leader?
    }

    ~H"""
    <%= if @is_leader? do%>
    <ul>
      <h3>Pick a winner</h3>
      <%= for player <- Enum.map(@active_players, &Leafblower.UserSupervisor.get_user!/1) do %>
        <%= if Map.has_key?(@round_player_answers, player.id) do %>
          <li><button phx-click="start_round" id={player.id}><%= "#{player.name} #{@round_player_answers[player.id]}" %></button></li>
        <% else %>
          <li><button phx-click="start_round" id={player.id}><%= player.name %> No answer</button></li>
        <% end %>
      <% end %>
    </ul>
    <% else %>
    <ul>
      <%= for player <- Enum.map(@active_players, &Leafblower.UserSupervisor.get_user!/1) do %>
        <%= if Map.has_key?(@round_player_answers, player.id) do %>
          <li id={player.id}><%= "#{player.name} #{@round_player_answers[player.id]}" %></li>
        <% else %>
          <li id={player.id}><%= player.name %> No answer </li>
        <% end %>
      <% end %>
    </ul>
    <% end %>

    """
  end

  @impl true
  @spec render(assigns()) :: Phoenix.LiveView.Rendered.t()

  def render(%{joined_in_game?: false} = assigns) do
    ~H"""
    <%= if @game_status == :waiting_for_players do %>
      <button phx-click="join_game">Join Game</button>
    <% else %>
      <h3>Game has started<h3>
    <% end %>
    """
  end

  def render(assigns) do
    ~H"""
    <pre><%= Atom.to_string(@game_status) %></pre>

    <%= case @game_status do
      :waiting_for_players -> render_waiting_for_players(
        @game_data.active_players,
        @game_data.min_player_count,
        @is_leader?)
      :round_started_waiting_for_response -> render_round_started_waiting_for_response(
        @user_id,
        @game_data.active_players,
        @game_data.round_player_answers,
        @countdown_left)
      :round_ended -> render_round_ended(
        @game_data.active_players,
        @game_data.round_player_answers,
        @is_leader?)
      _ -> ""
    end %>
    """
  end
end
