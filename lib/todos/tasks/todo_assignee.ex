defmodule Todos.Tasks.TodoAssignee do
  use Ash.Resource,
    otp_app: :todos,
    domain: Todos.Tasks,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "todo_assignees"
    repo Todos.Repo

    references do
      reference :todo, on_delete: :delete
      reference :user, on_delete: :delete
    end

    custom_indexes do
      index [:todo_id]
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :todo, Todos.Tasks.Todo do
      allow_nil? false
      primary_key? true
    end

    belongs_to :user, Todos.Accounts.User do
      allow_nil? false
      primary_key? true
    end
  end
end
