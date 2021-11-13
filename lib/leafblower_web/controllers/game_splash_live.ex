defmodule LeafblowerWeb.GameSplashLive do
  use LeafblowerWeb, :live_view

  def mount(_param, %{"current_user_id" => user_id}, socket) do
    {:ok,
     assign(socket,
       user_id: user_id,
       changeset: cast_user(%{name: ""}, %{})
     )}
  end

  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      cast_user(%{}, params)
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("new_game", %{"user" => params}, socket) do
    id = Ecto.UUID.generate()

    {:ok, game} =
      Leafblower.GameCache.new_game(id: id, countdown_duration: 5, min_player_count: 1)

    Leafblower.GameStatem.join_player(game, socket.assigns.user_id, params["name"])

    {:noreply,
     socket
     |> push_redirect(to: Routes.live_path(socket, LeafblowerWeb.GameLive, id))}
  end

  def render(assigns) do
    ~H"""
    <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" as="user">
      <%= label f, :name %>
      <%= text_input f, :name %>
      <%= error_tag f, :name %>

      <%= submit "New Game", [disabled: length(@changeset.errors) > 0] %>
    </.form>
    """
  end

  defp cast_user(data, params) do
    {data, %{name: :string}}
    |> Ecto.Changeset.cast(params, [:name])
    |> Ecto.Changeset.validate_required([:name])
  end
end
