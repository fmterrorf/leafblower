defmodule Leafblower.Name do
  @moduledoc """
  Taken from this [gist](https://gist.github.com/coryodaniel/d5e8fa15b3d1fe566b3c3f821225936e)
  """
  @adjectives ~w(
    autumn hidden bitter misty silent empty dry dark summer
    icy delicate quiet white cool spring winter patient
    twilight dawn crimson wispy weathered blue billowing
    broken cold damp falling frosty green long late lingering
    bold little morning muddy old red rough still small
    sparkling throbbing shy wandering withered wild black
    young holy solitary fragrant aged snowy proud floral
    restless divine polished ancient purple lively nameless
  )

  @nouns ~w(
    waterfall river breeze moon rain wind sea morning
    snow lake sunset pine shadow leaf dawn glitter forest
    hill cloud meadow sun glade bird brook butterfly
    bush dew dust field fire flower firefly feather grass
    haze mountain night pond darkness snowflake silence
    sound sky shape surf thunder violet water wildflower
    wave water resonance sun wood dream cherry tree fog
    frost voice paper frog smoke star hamster
  )

  def generate() do
    adjective = @adjectives |> Enum.random()
    noun = @nouns |> Enum.random()
    [adjective, noun] |> Enum.join("-")
  end
end

defmodule Leafblower.UserServer do
  use GenServer

  def child_spec(init_arg) do
    %{
      id: "#{__MODULE__}-#{Keyword.fetch!(init_arg, :id)}",
      start: {__MODULE__, :start_link, [init_arg]},
      restart: :transient,
      shutdown: 10_000
    }
  end

  def get_state(server) do
    GenServer.call(server, :get_state)
  end

  def start_link(init_arg) do
    case GenServer.start_link(__MODULE__, init_arg, name: via_tuple(Keyword.fetch!(init_arg, :id))) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, _pid}} -> :ignore
    end
  end

  def via_tuple(id), do: Leafblower.ProcessRegistry.via_tuple({__MODULE__, id})

  @impl true
  def init(init_arg) do
    id = Keyword.fetch!(init_arg, :id)
    name = Keyword.fetch!(init_arg, :name)
    {:ok, %{id: id, name: name}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
