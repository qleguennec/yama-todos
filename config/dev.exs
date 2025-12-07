import Config
config :ash, policies: [show_policy_breakdowns?: true]

# Configure your database
config :todos, Todos.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "todos_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
config :todos, TodosWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "a3Kx9L2mP4nQ7rT0wZ5vB8yC1fG6hJ3kM9oS2uW8xE4zR7tY0iU6pL5nD2gH1jK3",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:todos, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:todos, ~w(--watch)]}
  ]

# Reload browser tabs when matching files change.
config :todos, TodosWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*\.po$",
      ~r"lib/todos_web/router\.ex$",
      ~r"lib/todos_web/(controllers|live|components)/.*\.(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :todos, dev_routes: true, token_signing_secret: "dev-token-signing-secret-todos"

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false
