defmodule Todos.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TodosWeb.Telemetry,
      Todos.Repo,
      {DNSCluster, query: Application.get_env(:todos, :dns_cluster_query) || :ignore},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:todos, :ash_domains),
         Application.fetch_env!(:todos, Oban)
       )},
      {Phoenix.PubSub, name: Todos.PubSub},
      TodosWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :todos]}
    ]

    opts = [strategy: :one_for_one, name: Todos.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    TodosWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
