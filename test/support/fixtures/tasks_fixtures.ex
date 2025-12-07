defmodule Todos.TasksFixtures do
  @moduledoc """
  Test fixtures for creating task-related resources using Ash.Generator.
  """

  use Ash.Generator

  @doc """
  Generator for creating a tag.

  ## Examples

      tag = generate(tag())
      tag = generate(tag(name: "Work", color: "#ff0000"))
  """
  def tag(opts \\ []) do
    changeset_generator(
      Todos.Tasks.Tag,
      :create,
      defaults: [
        name: sequence(:tag_name, &"Tag #{&1}"),
        color: "#6366f1"
      ],
      overrides: opts
    )
  end

  @doc """
  Generator for creating a todo via quick capture (inbox state).

  ## Examples

      todo = generate(captured_todo(user_id: user.id))
  """
  def captured_todo(opts \\ []) do
    changeset_generator(
      Todos.Tasks.Todo,
      :capture,
      defaults: [
        title: sequence(:todo_title, &"Todo #{&1}")
      ],
      overrides: opts
    )
  end

  @doc """
  Generator for creating a todo with full details.

  ## Examples

      todo = generate(todo(user_id: user.id))
      todo = generate(todo(user_id: user.id, title: "Important task", priority: :high))
  """
  def todo(opts \\ []) do
    changeset_generator(
      Todos.Tasks.Todo,
      :create,
      defaults: [
        title: sequence(:todo_title, &"Todo #{&1}"),
        priority: :medium,
        initial_state: :pending
      ],
      overrides: opts
    )
  end

  @doc """
  Create a todo with tags.

  This is a convenience function (not a generator) for setting up test data.

  ## Examples

      user = generate(user())
      tag1 = generate(tag(name: "Work"))
      tag2 = generate(tag(name: "Urgent"))
      todo = create_todo_with_tags(user, [tag1, tag2], title: "Important task")
  """
  def create_todo_with_tags(user, tags, opts \\ []) do
    tag_ids = Enum.map(tags, & &1.id)

    attrs =
      Keyword.merge(
        [title: "Todo with tags", user_id: user.id, tag_ids: tag_ids],
        opts
      )

    Todos.Tasks.Todo
    |> Ash.Changeset.for_create(:create, Map.new(attrs))
    |> Ash.create!()
    |> Ash.load!(:tags)
  end

  @doc """
  Generator for creating a subtask.

  ## Examples

      subtask = generate(subtask(todo_id: todo.id))
  """
  def subtask(opts \\ []) do
    changeset_generator(
      Todos.Tasks.Subtask,
      :create,
      defaults: [
        title: sequence(:subtask_title, &"Subtask #{&1}"),
        position: 0
      ],
      overrides: opts
    )
  end
end
