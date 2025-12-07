import Config

# Note we also include the path to a cache manifest
# containing the digested version of static files.
config :todos, TodosWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

# Force using SSL in production
config :todos, TodosWeb.Endpoint, force_ssl: [rewrite_on: [:x_forwarded_proto]]

# Configure Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Req

# Disable Swoosh Local Memory Storage
config :swoosh, local: false

# Do not print debug messages in production
config :logger, level: :info
