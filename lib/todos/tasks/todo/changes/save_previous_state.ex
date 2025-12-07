defmodule Todos.Tasks.Todo.Changes.SavePreviousState do
  @moduledoc """
  Saves the current state to previous_state before a state transition.
  This enables undo functionality.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    current_state = Ash.Changeset.get_data(changeset, :state)
    Ash.Changeset.force_change_attribute(changeset, :previous_state, current_state)
  end
end
