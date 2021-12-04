defmodule LeafblowerWeb.Plugs.Currentuser do
  @moduledoc """
  Sets a current_user_id to the session to uniquely identify players
  """

  import Plug.Conn

  def init(default), do: default

  def call(%Plug.Conn{} = conn, _default) do
    if current_user_id = get_session(conn, :current_user_id) do
      conn
      |> assign(:current_user_id, current_user_id)
    else
      current_user_id = Ecto.UUID.generate()

      conn
      |> put_session(:current_user_id, current_user_id)
      |> assign(:current_user_id, current_user_id)
    end
  end
end
