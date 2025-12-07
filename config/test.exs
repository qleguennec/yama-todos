import Config
config :todos, Oban, testing: :manual
config :todos, token_signing_secret: "test-token-signing-secret"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Configure your database
config :todos, Todos.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "todos_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test
config :todos, TodosWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test-secret-key-base-that-is-at-least-64-bytes-long-for-testing-purposes-only-please-do-not-use-in-prod",
  server: false

# In test we don't send emails
config :todos, Todos.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
