import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :leafblower, LeafblowerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "6mYC9CTdkKnBJ5hDAY+2QoTO6grgwBdf3r+KwkLTOlLAxRq5mVTZPVbH225y4kqc",
  server: false

# In test we don't send emails.
config :leafblower, Leafblower.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
