defmodule LeafblowerWeb.GameSplashLive do
  use LeafblowerWeb, :live_view

  @impl true
  def mount(_param, %{"current_user_id" => user_id}, socket) do
    {:ok,
     assign(socket,
       user_id: user_id,
       page: :index
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :start_game = action, _params) do
    socket
    |> assign(:page, action)
    |> assign(:changeset, cast_user())
  end

  defp apply_action(socket, :join_by_code = action, _params) do
    socket
    |> assign(:page, action)
    |> assign(:changeset, cast_game_code())
  end

  defp apply_action(socket, _action, _params) do
    socket
  end

  @impl true
  def handle_event("validate_user", %{"user" => params}, socket) do
    changeset =
      cast_user(params)
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("validate_code", %{"code" => params}, socket) do
    changeset =
      cast_game_code(params)
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("new_game", %{"user" => params}, socket) do
    {:ok, code} = Leafblower.GameStatem.generate_game_code()

    data =
      cast_user(params)
      |> Ecto.Changeset.apply_changes()

    {:ok, game} =
      Leafblower.GameSupervisor.new_game(id: code, countdown_duration: 120, min_player_count: 2)

    Leafblower.GameStatem.join_player(game, socket.assigns.user_id, data.name)

    {:noreply,
     socket
     |> push_redirect(to: Routes.live_path(socket, LeafblowerWeb.GameLive, code), replace: true)}
  end

  @impl true
  def render(%{page: :start_game} = assigns) do
    ~H"""
      <.form let={f} for={@changeset} phx-change="validate_user" phx-submit="new_game" as="user">
        <%= text_input f, :name, placeholder: "Enter your name!" %>
        <%= error_tag f, :name %>

        <%= submit "Start a new game", [disabled: length(@changeset.errors) > 0] %>
      </.form>
    """
  end

  @impl true
  def render(%{page: :join_by_code} = assigns) do
    ~H"""
      <.form let={f} for={@changeset} phx-change="validate_code" phx-submit="join_by_code" as="code">
        <%= text_input f, :code, placeholder: "Enter game code!" %>
        <%= error_tag f, :code %>

        <%= submit "Join game", [disabled: length(@changeset.errors) > 0] %>
      </.form>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""

    <div class="row">
      <div>
        <h2>Welcome to <b>Leafblower</b>!</h2>
        <p>Play Cards Against Humanity online</p>
      </div>
    </div>

    <div class="row">
      <%= live_patch to: Routes.game_splash_path(@socket, :start_game) do%>
        <button>Start a game</button>
      <% end %>
    </div>

    <div class="row" style="padding: 1em;">
      <b>Or</b>
    </div>

    <div class="row">
      <%= live_patch to: Routes.game_splash_path(@socket, :join_by_code) do%>
        <button>Join game</button>
      <% end %>
    </div>
    """
  end

  defp cast_user(params \\ %{}) do
    {%{}, %{name: :string}}
    |> Ecto.Changeset.cast(params, [:name])
    |> Ecto.Changeset.validate_required([:name])
    |> Ecto.Changeset.validate_length(:name, max: 15)
  end

  defp cast_game_code(params \\ %{}) do
    {%{}, %{code: :string}}
    |> Ecto.Changeset.cast(params, [:code])
    |> Ecto.Changeset.validate_required([:code])
    |> Ecto.Changeset.validate_length(:code, max: 5)
  end
end
