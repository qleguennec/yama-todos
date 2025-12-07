defmodule Todos.Accounts.User do
  use Ash.Resource,
    otp_app: :todos,
    domain: Todos.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  authentication do
    tokens do
      enabled? true
      token_resource Todos.Accounts.Token

      signing_secret fn _, _ ->
        Application.fetch_env(:todos, :token_signing_secret)
      end
    end

    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
        confirmation_required? false

        resettable do
          sender fn _user, _token, _opts -> :ok end
        end
      end
    end
  end

  postgres do
    table "users"
    repo Todos.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:email]

      argument :password, :string, allow_nil?: false, sensitive?: true
      argument :password_confirmation, :string, allow_nil?: false, sensitive?: true

      validate confirm(:password, :password_confirmation)

      change AshAuthentication.Strategy.Password.HashPasswordChange
      change AshAuthentication.GenerateTokenChange
    end

    read :get_by_tailscale_login do
      get_by :tailscale_login
    end

    create :create_from_tailscale do
      accept [:tailscale_login, :tailscale_name, :tailscale_user]

      change set_attribute(:email, arg(:tailscale_user))
    end

    update :update_from_tailscale do
      accept [:tailscale_name, :tailscale_user]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? true
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? true
      sensitive? true
    end

    attribute :tailscale_login, :string do
      allow_nil? true
      public? true
    end

    attribute :tailscale_name, :string do
      allow_nil? true
      public? true
    end

    attribute :tailscale_user, :string do
      allow_nil? true
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :todos, Todos.Tasks.Todo
  end

  identities do
    identity :unique_email, [:email], nils_distinct?: false
    identity :unique_tailscale_login, [:tailscale_login], nils_distinct?: false
  end
end
