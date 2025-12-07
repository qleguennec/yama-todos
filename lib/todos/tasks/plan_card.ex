defmodule Todos.Tasks.PlanCard do
  @moduledoc """
  Embedded resource representing a todo card placed on a plan board.
  Stored as JSON in the PlanBoard.cards array.
  """
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id

    attribute :todo_id, :uuid do
      allow_nil? false
      public? true
      description "Reference to the Todo this card represents"
    end

    attribute :x, :float do
      allow_nil? false
      default 0.0
      public? true
      description "X position on the canvas"
    end

    attribute :y, :float do
      allow_nil? false
      default 0.0
      public? true
      description "Y position on the canvas"
    end

    attribute :width, :integer do
      allow_nil? false
      default 220
      public? true
    end

    attribute :height, :integer do
      allow_nil? false
      default 140
      public? true
    end
  end

  identities do
    # Can't add the same todo twice to a board
    identity :unique_todo, [:todo_id]
  end
end
