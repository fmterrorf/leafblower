defmodule LeafblowerWeb.GameLive do
  use LeafblowerWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    Loading
    """
  end
end
