defmodule Leafblower.Repo do
  use Ecto.Repo,
    otp_app: :leafblower,
    adapter: Ecto.Adapters.Postgres
end
