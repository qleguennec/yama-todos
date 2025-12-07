defmodule Todos.Tasks.UserTagOrder do
  use Ash.Resource,
    otp_app: :todos,
    domain: Todos.Tasks,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "user_tag_orders"
    repo Todos.Repo

    references do
      reference :tag, on_delete: :delete
    end

    custom_indexes do
      index [:user_id]
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:position]
      argument :user_id, :uuid, allow_nil?: false
      argument :tag_id, :uuid, allow_nil?: false

      change manage_relationship(:user_id, :user, type: :append)
      change manage_relationship(:tag_id, :tag, type: :append)
    end

    update :update do
      accept [:position]
    end

    create :upsert do
      accept [:position]
      argument :user_id, :uuid, allow_nil?: false
      argument :tag_id, :uuid, allow_nil?: false

      change manage_relationship(:user_id, :user, type: :append)
      change manage_relationship(:tag_id, :tag, type: :append)

      upsert? true
      upsert_identity :unique_user_tag
    end

    read :for_user do
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
      prepare build(sort: [position: :asc])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :position, :integer do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Todos.Accounts.User do
      allow_nil? false
    end

    belongs_to :tag, Todos.Tasks.Tag do
      allow_nil? false
    end
  end

  identities do
    identity :unique_user_tag, [:user_id, :tag_id]
  end
end
