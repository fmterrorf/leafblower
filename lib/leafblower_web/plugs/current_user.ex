defmodule LeafblowerWeb.Plugs.Currentuser do
  import Plug.Conn

  def init(default), do: default

  def call(%Plug.Conn{} = conn, _default) do
    if current_user_id = get_session(conn, :current_user_id) do
      assign(conn, :current_user_id, current_user_id)
    else
      id = Ecto.UUID.generate()

      conn
      |> put_session(:current_user_id, id)
      |> assign(:current_user_id, id)
    end
  end
end
