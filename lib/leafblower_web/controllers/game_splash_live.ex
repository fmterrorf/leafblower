defmodule LeafblowerWeb.GameSplashLive do
  use LeafblowerWeb, :live_view

  def handle_event("new_game", _value, socket) do
    id = Ecto.UUID.generate()
    Leafblower.GameCache.new_game(id: id)

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
