defmodule LeafblowerWeb.GameSplashLive do
  use LeafblowerWeb, :live_view

  def mount(_param, %{"current_user_id" => user_id}, socket) do
    {:ok,
     assign(socket,
       user_id: user_id,
       changeset: cast_user()
     )}
  end

  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      cast_user(params)
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

  def render(assigns) do
    ~H"""
    <.form let={f} for={@changeset} phx-change="validate" phx-submit="new_game" as="user">
      <%= label f, :name %>
      <%= text_input f, :name, placeholder: "Enter name you want to show in the game" %>
      <%= error_tag f, :name %>

      <%= submit "Start a new game", [disabled: length(@changeset.errors) > 0] %>
    </.form>
    """
  end

  defp cast_user(params \\ %{}) do
    {%{}, %{name: :string}}
    |> Ecto.Changeset.cast(params, [:name])
    |> Ecto.Changeset.validate_required([:name])
    |> Ecto.Changeset.validate_length(:name, max: 15)
  end
end
