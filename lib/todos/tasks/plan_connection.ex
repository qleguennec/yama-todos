defmodule Todos.Tasks.PlanConnection do
  @moduledoc """
  Embedded resource representing a connection (arrow) between two cards on a plan board.
  Stored as JSON in the PlanBoard.connections array.
  """
  use Ash.Resource, data_layer: :embedded

  validations do
    validate {Todos.Tasks.PlanConnection.Validations.NoSelfConnection, []}
  end

  attributes do
    uuid_primary_key :id

    attribute :from_card_id, :uuid do
      allow_nil? false
      public? true
      description "The card this connection starts from"
    end

    attribute :to_card_id, :uuid do
      allow_nil? false
      public? true
      description "The card this connection points to"
    end

    attribute :label, :string do
      allow_nil? true
      public? true
      description "Optional label for the connection (e.g., 'depends on', 'before')"
    end
  end

  identities do
    # Can't have duplicate connections between the same cards
    identity :unique_connection, [:from_card_id, :to_card_id]
  end
end

defmodule Todos.Tasks.PlanConnection.Validations.NoSelfConnection do
  @moduledoc """
  Validates that a connection doesn't point to itself.
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    from_id = Ash.Changeset.get_attribute(changeset, :from_card_id)
    to_id = Ash.Changeset.get_attribute(changeset, :to_card_id)

    if from_id == to_id do
      {:error, field: :to_card_id, message: "cannot connect a card to itself"}
    else
      :ok
    end
  end
end
