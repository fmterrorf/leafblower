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
     )
     |> maybe_assign_changeset()}
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
        :round_ended ->
          assign(socket, countdown_left: nil)

        _ ->
          socket
      end

    {:noreply,
     assign(socket,
       game_status: state,
       game_data: data,
       is_leader?: data.leader_player_id == socket.assigns.user_id
     )}
  end

  def handle_info({:ticker_ticked, countdown_left}, socket) do
    {:noreply, assign(socket, countdown_left: countdown_left)}
  end

  defp maybe_assign_changeset(%{assigns: %{joined_in_game?: false}} = socket) do
    assign(socket, changeset: cast_user())
  end

  defp maybe_assign_changeset(socket), do: assign(socket, changeset: nil)

  defp cast_user(params \\ %{}) do
    {%{}, %{name: :string}}
    |> Ecto.Changeset.cast(params, [:name])
    |> Ecto.Changeset.validate_required([:name])
    |> Ecto.Changeset.validate_length(:name, max: 15)
  end

  @impl true
  def handle_event("join_game", %{"user" => user}, socket) do
    %{game: game, user_id: user_id} = socket.assigns
    :ok = GameStatem.join_player(game, user_id, user["name"])
    {:noreply, assign(socket, joined_in_game?: true)}
  end

  def handle_event("validate_join_game", %{"user" => params}, socket) do
    {:noreply,
     assign(socket,
       changeset:
         params
         |> cast_user
         |> Map.put(:action, :insert)
     )}
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

  def handle_event("pick_winner", %{"id" => id}, socket) do
    %{game: game} = socket.assigns
    :ok = GameStatem.pick_winner(game, id)
    {:noreply, socket}
  end

  @impl true
  @spec render(assigns()) :: Phoenix.LiveView.Rendered.t()

  def render(%{joined_in_game?: false} = assigns) do
    ~H"""
    <%= if @game_status == :waiting_for_players do %>
      <.form let={f} for={@changeset} phx-change="validate_join_game" phx-submit="join_game" as="user">
        <%= label f, :name %>
        <%= text_input f, :name %>
        <%= error_tag f, :name %>

        <%= submit "New Game", [disabled: length(@changeset.errors) > 0] %>
      </.form>
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
        @game_data.player_info,
        @is_leader?)
      :round_started_waiting_for_response -> render_round_started_waiting_for_response(
        @user_id,
        @game_data.active_players,
        @game_data.round_player_answers,
        @countdown_left)
      :round_ended -> render_round_ended(
        @game_data.active_players,
        @game_data.round_player_answers,
        @game_data.player_info,
        @is_leader?)
      :show_winner -> render_winner(
        @game_data.player_info[@game_data.winner_player_id],
        @is_leader?
      )
      _ -> ""
    end %>
    """
  end

  defp render_waiting_for_players(active_players, min_player_count, player_info, is_leader?) do
    assigns = %{
      disabled: map_size(active_players) < min_player_count,
      is_leader?: is_leader?,
      active_players: active_players,
      player_info: player_info
    }

    ~H"""
    <%= if @is_leader? do%>
      <button phx-click="start_round" {[disabled: @disabled]}>Start Game</button>
    <% end %>

    <ul>
      <%= for player <- Enum.map(@active_players, fn id -> @player_info[id] end) do %>
        <li id={player.id}><%= player.name %></li>
      <% end %>
    </ul>
    """
  end

  defp render_round_started_waiting_for_response(
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

  defp render_round_ended(active_players, round_player_answers, player_info, is_leader?) do
    assigns = %{
      active_players: active_players,
      round_player_answers: round_player_answers,
      player_info: player_info,
      is_leader?: is_leader?
    }

    ~H"""
    <%= if @is_leader? do%>
    <ul>
      <h3>Pick a winner</h3>
      <%= for player <- Enum.map(@active_players, fn id -> @player_info[id] end) do %>
        <%= if Map.has_key?(@round_player_answers, player.id) do %>
          <li><button phx-click="pick_winner" phx-value-id={player.id} id={player.id}><%= "#{player.name} #{@round_player_answers[player.id]}" %></button></li>
        <% else %>
          <li><button phx-click="pick_winner" phx-value-id={player.id}><%= player.name %> No answer</button></li>
        <% end %>
      <% end %>
    </ul>
    <% else %>
    <ul>
      <%= for player <- Enum.map(@active_players, fn id -> @player_info[id] end) do %>
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

  defp render_winner(winner_player, is_leader?) do
    assigns = %{
      is_leader?: is_leader?,
      winner_player: winner_player
    }

    ~H"""
    <p>And the winner for this round is <b> <%= @winner_player.name %> </b> 🎉🎉🎉 </p>
    <%= if @is_leader? do%>
      <button phx-click="start_round" >Start Next Round</button>
    <% end %>
    """
  end
end
