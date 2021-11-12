defmodule LeafblowerWeb.GameSplashLive do
  use LeafblowerWeb, :live_view

  def mount(_param, %{"current_user_id" => user_id}, socket) do
    {:ok, assign(socket, user_id: user_id)}
  end

  def handle_event("new_game", _value, socket) do
    id = Ecto.UUID.generate()

    {:ok, game} =
      Leafblower.GameCache.new_game(id: id, countdown_duration: 5, min_player_count: 1)

    Leafblower.GameStatem.join_player(game, socket.assigns.user_id)

    {:noreply,
     socket
     |> push_redirect(to: Routes.live_path(socket, LeafblowerWeb.GameLive, id))}
  end

  def render(assigns) do
    ~H"""
    <button phx-click="new_game">New Game</button>
    """
  end
end
