defmodule Leafblower.UserSupervisor do
  use Horde.DynamicSupervisor
  alias Leafblower.UserServer
  alias Leafblower.Name

  def start_link(_) do
    Horde.DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def new_user(id) do
    Horde.DynamicSupervisor.start_child(
      __MODULE__,
      {UserServer, [id: id, name: Name.generate()]}
    )
  end

  def find_user(id) do
    case Leafblower.ProcessRegistry.lookup({UserServer, id}) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  def get_user!(id) do
    if server = find_user(id) do
      UserServer.get_state(server)
    else
      raise "User not found"
    end
  end

  @impl true
  def init(_) do
    Horde.DynamicSupervisor.init(strategy: :one_for_one, members: :auto)
  end
end
