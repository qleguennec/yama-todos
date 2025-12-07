defmodule TodosWeb.CoursesHelper do
  @moduledoc """
  Helper module for the courses quick action feature.
  """

  require Ash.Query

  @doc """
  Finds a todo with "courses" in the title (case-insensitive).
  Returns the first matching non-cancelled todo, or nil if none found.
  """
  def find_courses_todo do
    Todos.Tasks.Todo
    |> Ash.Query.filter(fragment("LOWER(title) LIKE ?", "%courses%"))
    |> Ash.Query.filter(state != :cancelled)
    |> Ash.Query.load(:subtasks)
    |> Ash.Query.limit(1)
    |> Ash.read!()
    |> List.first()
  end
end
