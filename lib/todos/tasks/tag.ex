defmodule Todos.Tasks.Tag do
  use Ash.Resource,
    otp_app: :todos,
    domain: Todos.Tasks,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Todos.Tasks.TodoNotifier]

  postgres do
    table "tags"
    repo Todos.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :color]
    end

    update :update do
      accept [:name, :color]
    end

    read :list_all do
      prepare build(sort: [name: :asc])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :color, :string do
      allow_nil? true
      default "#6366f1"
      public? true
      description "Hex color code for the tag"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    many_to_many :todos, Todos.Tasks.Todo do
      through Todos.Tasks.TodoTag
      source_attribute_on_join_resource :tag_id
      destination_attribute_on_join_resource :todo_id
    end
  end

  identities do
    identity :unique_name, [:name]
  end
end
