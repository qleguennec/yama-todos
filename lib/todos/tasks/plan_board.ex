defmodule Todos.Tasks.PlanBoard do
  @moduledoc """
  A visual planning board where users can arrange todo cards and create
  connections between them to plan workflows and dependencies.

  Each board stores:
  - Cards: Todo items placed on the canvas with x/y positions
  - Connections: Arrows between cards showing relationships
  - Viewport: Current pan/zoom state for persistence
  """
  use Ash.Resource,
    otp_app: :todos,
    domain: Todos.Tasks,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "plan_boards"
    repo Todos.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name]

      argument :user_id, :uuid, allow_nil?: false

      change set_attribute(:user_id, arg(:user_id))
    end

    update :update do
      require_atomic? false
      accept [:name, :cards, :connections, :viewport_x, :viewport_y, :zoom]
    end

    # Update just the viewport (pan/zoom state)
    update :save_viewport do
      accept [:viewport_x, :viewport_y, :zoom]
    end

    # Update cards array (for moving, adding, removing cards)
    update :update_cards do
      require_atomic? false
      accept [:cards]
    end

    # Update connections array
    update :update_connections do
      require_atomic? false
      accept [:connections]
    end

    read :list_for_user do
      argument :user_id, :uuid, allow_nil?: false

      filter expr(user_id == ^arg(:user_id))
      prepare build(sort: [updated_at: :desc])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      description "Name of the plan board"
    end

    attribute :cards, {:array, Todos.Tasks.PlanCard} do
      allow_nil? false
      default []
      public? true
      description "Todo cards placed on this board"
    end

    attribute :connections, {:array, Todos.Tasks.PlanConnection} do
      allow_nil? false
      default []
      public? true
      description "Connections between cards"
    end

    attribute :viewport_x, :float do
      allow_nil? false
      default 0.0
      public? true
      description "Current viewport pan X position"
    end

    attribute :viewport_y, :float do
      allow_nil? false
      default 0.0
      public? true
      description "Current viewport pan Y position"
    end

    attribute :zoom, :float do
      allow_nil? false
      default 1.0
      public? true
      description "Current zoom level (0.25 to 2.0)"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Todos.Accounts.User do
      allow_nil? false
    end
  end
end
