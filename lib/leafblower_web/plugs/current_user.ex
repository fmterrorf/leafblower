defmodule LeafblowerWeb.Plugs.Currentuser do
  import Plug.Conn

  def init(default), do: default

  def call(%Plug.Conn{} = conn, _default) do
    if current_user_id = get_user_id(conn) do
      assign(conn, :current_user_id, current_user_id)
    else
      user = Leafblower.User.new()

      conn
      |> put_session(:current_user_id, user.id)
      |> assign(:current_user_id, user.id)
    end
  end

  defp get_user_id(conn) do
    case get_session(conn, :current_user_id) do
      nil ->
        nil

      current_user_id ->
        if Leafblower.ETSKv.get(current_user_id) do
          current_user_id
        else
          nil
        end
    end
  end
end
