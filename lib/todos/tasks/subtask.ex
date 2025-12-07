defmodule Todos.Tasks.Subtask do
  use Ash.Resource,
    otp_app: :todos,
    domain: Todos.Tasks,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshArchival.Resource]

  postgres do
    table "subtasks"
    repo Todos.Repo

    custom_indexes do
      index [:todo_id]
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:title, :position]

      argument :todo_id, :uuid, allow_nil?: false

      change set_attribute(:todo_id, arg(:todo_id))
    end

    update :update do
      accept [:title, :position]
    end

    update :toggle do
      require_atomic? false

      change fn changeset, _ ->
        current = Ash.Changeset.get_attribute(changeset, :completed)
        Ash.Changeset.change_attribute(changeset, :completed, !current)
      end
    end

    update :complete do
      change set_attribute(:completed, true)
    end

    update :uncomplete do
      change set_attribute(:completed, false)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :completed, :boolean do
      allow_nil? false
      default false
      public? true
    end

    attribute :position, :integer do
      allow_nil? false
      default 0
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :todo, Todos.Tasks.Todo do
      allow_nil? false
    end
  end
end
