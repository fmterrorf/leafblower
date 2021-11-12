defmodule LeafblowerWeb.Plugs.Currentuser do
  import Plug.Conn

  def init(default), do: default

  def call(%Plug.Conn{} = conn, _default) do
    if current_user = get_user(conn) do
      conn
      |> assign(:current_user_id, current_user.id)
      |> assign(:current_user, current_user)
    else
      {:ok, server} = Leafblower.UserSupervisor.new_user(Ecto.UUID.generate())
      user = Leafblower.UserServer.get_state(server)

      conn
      |> put_session(:current_user_id, user.id)
      |> assign(:current_user_id, user.id)
      |> assign(:current_user, user)
    end
  end

  defp get_user(conn) do
    case get_session(conn, :current_user_id) do
      nil ->
        nil

      current_user_id ->
        if user_server = Leafblower.UserSupervisor.find_user(current_user_id) do
          Leafblower.UserServer.get_state(user_server)
        else
          nil
        end
    end
  end
end
