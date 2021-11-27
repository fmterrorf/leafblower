defmodule Leafblower.ProcessRegistry do
  use Horde.Registry

  def start_link(_) do
    Horde.Registry.start_link(__MODULE__, [keys: :unique], name: __MODULE__)
  end

  def via_tuple(key) do
    {:via, Horde.Registry, {__MODULE__, key}}
  end

  def lookup(key) do
    Horde.Registry.lookup(__MODULE__, key)
  end

  def init(options) do
    Horde.Registry.init(options)
  end
end
