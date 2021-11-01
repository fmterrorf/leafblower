defmodule Leafblower.User do
  defstruct [:id, :name]

  @type t :: %__MODULE__{
          id: binary(),
          name: binary()
        }

  defmodule Name do
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

  @spec new :: t
  def new() do
    user = %__MODULE__{
      name: Name.generate(),
      id: "user:" <> Ecto.UUID.generate()
    }

    Leafblower.ETSKv.put(user.id, user)
    user
  end

  def get(id) do
    Leafblower.ETSKv.get(id)
  end
end