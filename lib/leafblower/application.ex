defmodule Leafblower.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies) || []

    children = [
      # Start the Telemetry supervisor
      LeafblowerWeb.Telemetry,
      # {Horde.Registry, [name: Leafblower.GameRegistry, keys: :unique, members: :auto]},
      {Cluster.Supervisor, [topologies, [name: Leafblower.ClusterSupervisor]]},
      Leafblower.GameSupervisor,
      Leafblower.ProcessRegistry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Leafblower.PubSub},
      # Start the Endpoint (http/https)
      LeafblowerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Leafblower.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LeafblowerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
