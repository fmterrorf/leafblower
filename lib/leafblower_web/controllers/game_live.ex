defmodule LeafblowerWeb.GameLive do
  use LeafblowerWeb, :live_view
  alias Leafblower.{GameStatem, GameSupervisor, GameTicker}

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
    GameSupervisor.find_game(params["id"])
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
     |> clear_flash()
     |> maybe_assign_changeset()}
  end

  def do_mount(nil, _params, _session, socket) do
    {:ok,
     socket
     |> put_flash(:info, "Game not found")
     |> redirect(to: Routes.game_splash_path(socket, :index))}
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

  def handle_info({:ticker_ticked, countdown_left}, socket) when countdown_left > 1 do
    {:noreply, assign(socket, countdown_left: countdown_left)}
  end

  def handle_info({:ticker_ticked, _countdown_left}, socket) do
    {:noreply, assign(socket, countdown_left: nil)}
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

    {:noreply,
     socket
     |> clear_flash()
     |> assign(joined_in_game?: true)}
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
        <%= text_input f, :name, placeholder: "Enter your name! " %>
        <%= error_tag f, :name %>

        <%= submit "Join game", [disabled: length(@changeset.errors) > 0] %>
      </.form>
    <% else %>
      <h3>Game has started<h3>
    <% end %>
    """
  end

  def render(assigns) do
    ~H"""
    <pre><%= Atom.to_string(@game_status) %></pre>
    <%= if @countdown_left != nil do %>
      <pre id="countdown">Countdown: <%= @countdown_left %></pre>
    <% end %>

    <%= case @game_status do
      :waiting_for_players -> render_waiting_for_players(
        @game_data.id,
        @game_data.active_players,
        @game_data.min_player_count,
        @game_data.player_info,
        @is_leader?)
      :round_started_waiting_for_response -> render_round_started_waiting_for_response(
        @user_id,
        @game_data.active_players,
        @game_data.round_player_answers,
        @game_data.leader_player_id,
        @game_data.player_cards[@user_id],
        @game_data.black_card,
        @game_data.player_info,
        @is_leader?)
      :round_ended -> render_round_ended(
        @game_data.active_players,
        @game_data.round_player_answers,
        @game_data.player_info,
        @game_data.black_card,
        @is_leader?)
      :show_winner -> render_winner(
        @game_data.player_info[@game_data.winner_player_id],
        @game_data.player_score,
        @game_data.player_info,
        @is_leader?
      )
      _ -> ""
    end %>
    """
  end

  defp render_waiting_for_players(
         game_id,
         active_players,
         min_player_count,
         player_info,
         is_leader?
       ) do
    active_players_size = MapSet.size(active_players)

    assigns = %{
      game_id: game_id,
      disabled: active_players_size < min_player_count,
      is_leader?: is_leader?,
      active_players: active_players,
      player_info: player_info
    }

    ~H"""
    <pre>
      Game code: <b><%= @game_id %></b>
      Share it with your fiends to play!
    </pre>
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
         leader_player_id,
         cards,
         black_card_id,
         player_info,
         is_leader?
       ) do
    assigns = %{
      active_players: active_players,
      leader_player_id: leader_player_id,
      round_player_answers: round_player_answers,
      disabled: Map.has_key?(round_player_answers, player_id),
      cards: cards,
      black_card: Leafblower.Deck.card(black_card_id, :black),
      player_info: player_info,
      is_leader?: is_leader?,
      player_id: player_id,
      has_answered?: round_player_answers[player_id] != nil
    }

    ~H"""
    <div class="container">
      <div class="row" style="justify-content:center;">
        <div class="card-container">
          <div class="card dark">
            <span class="text"><%= @black_card["text"] %></span>
          </div>
        </div>
      </div>
      <div class="row">
        <%= if !@is_leader? do%>
          <%= if @has_answered? do %>
            <p>You picked </p>
            <br />
          <div class="card-container">
            <div class="card light">
              <span class="text"><%= Leafblower.Deck.card(@round_player_answers[@player_id], :white)["text"] %></span>
            </div>
          </div>
          <% else %>
            <ul class="card-container">
            <%= for id <- @cards, card = Leafblower.Deck.card(id, :white) do %>
              <li id={card["id"]} class="card light pointer" phx-click="submit_answer" phx-value-id={card["id"]}>
                <span class="text"><%= card["text"] %></span>
              </li>
            <% end %>
            </ul>
          <% end %>
        <% else %>
          <div>
            <hr/>
            <p>Players are picking their answers. Please wait</p>
          </div>
        <% end %>
      </div>
      <div class="row">
        <ul>
          <%= for player <- Enum.map(@active_players, fn id -> @player_info[id] end) do %>
            <%= if player.id == @leader_player_id do %>
              <li id={player.id}><%= player.name %> - 👑</li>
            <% else %>
              <li id={player.id}><%= player.name %> - <%= if Map.has_key?(@round_player_answers, player.id), do: "✅", else: "⌛"%></li>
            <% end %>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end

  defp render_round_ended(
         active_players,
         round_player_answers,
         player_info,
         black_card_id,
         is_leader?
       ) do
    assigns = %{
      active_players: active_players,
      round_player_answers: round_player_answers,
      has_answers?: Map.values(round_player_answers) |> Enum.any?(),
      player_info: player_info,
      black_card: Leafblower.Deck.card(black_card_id, :black),
      is_leader?: is_leader?
    }

    ~H"""
    <div class="container">
      <%= if @is_leader? do%>
      <div class="row" style="justify-content:center;">
        <div class="card-container">
          <div class="card dark">
            <span class="text"><%= @black_card["text"] %></span>
          </div>
        </div>
      </div>
      <%= if @has_answers? do %>
        <hr/>
        <b>Pick a winner</b>
        <ul class="card-container">
          <%= for player <- Enum.map(@active_players, fn id -> @player_info[id] end),
                  card = Leafblower.Deck.card(@round_player_answers[player.id], :white) do %>
            <%= if Map.has_key?(@round_player_answers, player.id) do %>
              <li class="card light" phx-click="pick_winner" phx-value-id={player.id} id={player.id}>
                <span class="text">
                  <%= card["text"] %>
                </span>
              </li>
            <% end %>
          <% end %>
        </ul>
        <% else %>
          <button phx-click="start_round" >Start Next Round</button>
        <% end %>
      <% else %>
      <ul class="card-container">
          <%= for player <- Enum.map(@active_players, fn id -> @player_info[id] end),
                  card = Leafblower.Deck.card(@round_player_answers[player.id], :white) do %>
            <%= if Map.has_key?(@round_player_answers, player.id) do %>
              <li class="card light" id={player.id}>
                <span class="text">
                  <%= card["text"] %>
                </span>
              </li>
            <% end %>
          <% end %>
        </ul>
      <% end %>
    </div>
    """
  end

  defp render_winner(winner_player, player_score, player_info, is_leader?) do
    assigns = %{
      is_leader?: is_leader?,
      winner_player: winner_player,
      player_score: player_score,
      player_info: player_info
    }

    ~H"""
    <p>And the winner for this round is <b> <%= @winner_player.name %> </b> 🎉🎉🎉 </p>
    <%= if @is_leader? do%>
      <button phx-click="start_round" >Start Next Round</button>
    <% end %>

    <%= render_leader_board(player_info, player_score) %>
    """
  end

  defp render_leader_board(player_info, player_score) do
    assigns = %{
      sorted_score: Enum.sort(player_score, fn {_, left}, {_, right} -> left > right end),
      player_info: player_info
    }

    ~H"""
    <div class="row">
      <ul>
        <%= for {player_id, score} <- @sorted_score do %>
            <li id={player_id}><%=  player_info[player_id].name %> - <%= score %></li>
        <% end %>
      </ul>
    </div>
    """
  end
end
