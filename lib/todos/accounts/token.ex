defmodule Todos.Accounts.Token do
  use Ash.Resource,
    otp_app: :todos,
    domain: Todos.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table "tokens"
    repo Todos.Repo
  end

  actions do
    defaults [:read, :destroy]
  end
end
