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

  @doc """
  Generator for creating a plan board.

  ## Examples

      board = generate(plan_board(user_id: user.id))
      board = generate(plan_board(user_id: user.id, name: "Sprint Planning"))
  """
  def plan_board(opts \\ []) do
    changeset_generator(
      Todos.Tasks.PlanBoard,
      :create,
      defaults: [
        name: sequence(:plan_board_name, &"Plan Board #{&1}")
      ],
      overrides: opts
    )
  end

  @doc """
  Create a plan board with cards.

  This is a convenience function for setting up test data with cards already on the board.

  ## Examples

      user = generate(user())
      todo1 = generate(todo(user_id: user.id))
      todo2 = generate(todo(user_id: user.id))
      board = create_board_with_cards(user, [todo1, todo2], name: "My Plan")
  """
  def create_board_with_cards(user, todos, opts \\ []) do
    cards =
      todos
      |> Enum.with_index()
      |> Enum.map(fn {todo, index} ->
        %Todos.Tasks.PlanCard{
          id: Ash.UUID.generate(),
          todo_id: todo.id,
          x: 100.0 + index * 250,
          y: 100.0,
          width: 220,
          height: 140
        }
      end)

    attrs =
      Keyword.merge(
        [name: "Test Board", user_id: user.id],
        opts
      )

    Todos.Tasks.PlanBoard
    |> Ash.Changeset.for_create(:create, Map.new(attrs))
    |> Ash.create!()
    |> Ash.Changeset.for_update(:update_cards, %{cards: cards})
    |> Ash.update!()
  end

  @doc """
  Create a plan board with cards and connections.

  ## Examples

      user = generate(user())
      todo1 = generate(todo(user_id: user.id))
      todo2 = generate(todo(user_id: user.id))
      board = create_board_with_connections(user, [{todo1, todo2}], name: "My Plan")
  """
  def create_board_with_connections(user, todo_pairs, opts \\ []) do
    # Collect all unique todos
    all_todos =
      todo_pairs
      |> Enum.flat_map(fn {from, to} -> [from, to] end)
      |> Enum.uniq_by(& &1.id)

    # Create cards for all todos
    cards =
      all_todos
      |> Enum.with_index()
      |> Enum.map(fn {todo, index} ->
        %Todos.Tasks.PlanCard{
          id: Ash.UUID.generate(),
          todo_id: todo.id,
          x: 100.0 + index * 250,
          y: 100.0,
          width: 220,
          height: 140
        }
      end)

    # Create a lookup map from todo_id to card_id
    todo_to_card = Map.new(cards, fn card -> {card.todo_id, card.id} end)

    # Create connections
    connections =
      Enum.map(todo_pairs, fn {from_todo, to_todo} ->
        %Todos.Tasks.PlanConnection{
          id: Ash.UUID.generate(),
          from_card_id: Map.fetch!(todo_to_card, from_todo.id),
          to_card_id: Map.fetch!(todo_to_card, to_todo.id),
          label: nil
        }
      end)

    attrs =
      Keyword.merge(
        [name: "Test Board", user_id: user.id],
        opts
      )

    Todos.Tasks.PlanBoard
    |> Ash.Changeset.for_create(:create, Map.new(attrs))
    |> Ash.create!()
    |> Ash.Changeset.for_update(:update, %{cards: cards, connections: connections})
    |> Ash.update!()
  end
end
