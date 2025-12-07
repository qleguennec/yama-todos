defmodule Todos.Tasks.Todo.Changes.AddSubtask do
  @moduledoc """
  Ash change that adds a subtask to the todo being updated.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, todo ->
      title = Ash.Changeset.get_argument(changeset, :subtask_title)

      # Load subtasks to get accurate position
      todo = Ash.load!(todo, :subtasks)
      subtasks = todo.subtasks || []

      case Todos.Tasks.Subtask
           |> Ash.Changeset.for_create(:create, %{
             title: title,
             todo_id: todo.id,
             position: length(subtasks)
           })
           |> Ash.create() do
        {:ok, _subtask} -> {:ok, todo}
        {:error, error} -> {:error, error}
      end
    end)
  end
end
