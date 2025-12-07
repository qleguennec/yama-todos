defmodule Todos.Tasks.TodoTagsTest do
  use Todos.DataCase, async: true

  require Ash.Query

  describe "create todo with tags" do
    test "creates todo with multiple tags" do
      user = generate(user())
      tag1 = generate(tag(name: "Work"))
      tag2 = generate(tag(name: "Urgent"))

      todo = create_todo_with_tags(user, [tag1, tag2], title: "Important task")

      assert todo.title == "Important task"
      assert length(todo.tags) == 2
      tag_names = Enum.map(todo.tags, & &1.name) |> Enum.sort()
      assert tag_names == ["Urgent", "Work"]
    end

    test "creates todo with no tags" do
      user = generate(user())

      todo =
        Todos.Tasks.Todo
        |> Ash.Changeset.for_create(:create, %{title: "No tags", user_id: user.id, tag_ids: []})
        |> Ash.create!()
        |> Ash.load!(:tags)

      assert todo.tags == []
    end
  end

  describe "update todo tags" do
    test "adds tags to existing todo" do
      user = generate(user())
      tag1 = generate(tag(name: "Work"))
      tag2 = generate(tag(name: "Later"))

      todo =
        Todos.Tasks.Todo
        |> Ash.Changeset.for_create(:create, %{title: "Task", user_id: user.id, tag_ids: []})
        |> Ash.create!()

      {:ok, updated} =
        todo
        |> Ash.Changeset.for_update(:update, %{tag_ids: [tag1.id, tag2.id]})
        |> Ash.update()

      updated = Ash.load!(updated, :tags)
      assert length(updated.tags) == 2
    end

    test "removes tags from todo" do
      user = generate(user())
      tag1 = generate(tag(name: "Remove Me"))
      tag2 = generate(tag(name: "Keep Me"))

      todo = create_todo_with_tags(user, [tag1, tag2])
      assert length(todo.tags) == 2

      {:ok, updated} =
        todo
        |> Ash.Changeset.for_update(:update, %{tag_ids: [tag2.id]})
        |> Ash.update()

      updated = Ash.load!(updated, :tags)
      assert length(updated.tags) == 1
      assert hd(updated.tags).name == "Keep Me"
    end

    test "replaces all tags" do
      user = generate(user())
      old_tag = generate(tag(name: "Old"))
      new_tag = generate(tag(name: "New"))

      todo = create_todo_with_tags(user, [old_tag])

      {:ok, updated} =
        todo
        |> Ash.Changeset.for_update(:update, %{tag_ids: [new_tag.id]})
        |> Ash.update()

      updated = Ash.load!(updated, :tags)
      assert length(updated.tags) == 1
      assert hd(updated.tags).name == "New"
    end

    test "clears all tags" do
      user = generate(user())
      tag = generate(tag(name: "To Clear"))

      todo = create_todo_with_tags(user, [tag])

      {:ok, updated} =
        todo
        |> Ash.Changeset.for_update(:update, %{tag_ids: []})
        |> Ash.update()

      updated = Ash.load!(updated, :tags)
      assert updated.tags == []
    end
  end

  describe "filter todos by tag" do
    test "filters todos by tag name" do
      user = generate(user())
      work_tag = generate(tag(name: "Work"))
      personal_tag = generate(tag(name: "Personal"))

      _work_todo = create_todo_with_tags(user, [work_tag], title: "Work task")
      _personal_todo = create_todo_with_tags(user, [personal_tag], title: "Personal task")
      _both_todo = create_todo_with_tags(user, [work_tag, personal_tag], title: "Both tags")

      require Ash.Query

      work_todos =
        Todos.Tasks.Todo
        |> Ash.Query.filter(tags.name == "Work")
        |> Ash.read!()

      assert length(work_todos) == 2
      titles = Enum.map(work_todos, & &1.title) |> Enum.sort()
      assert titles == ["Both tags", "Work task"]
    end
  end

  describe "cascade delete" do
    test "archiving todo keeps todo_tags (soft delete)" do
      user = generate(user())
      tag = generate(tag(name: "Test"))
      todo = create_todo_with_tags(user, [tag])

      # Verify todo_tag exists
      todo_tags =
        Todos.Tasks.TodoTag
        |> Ash.Query.filter(todo_id == ^todo.id)
        |> Ash.read!()

      assert length(todo_tags) == 1

      # Archive the todo (uses AshArchival - soft delete)
      {:ok, _archived} = Ash.destroy(todo)

      # With AshArchival, todo_tags remain (todo is just archived, not deleted)
      # The cascade delete only triggers on hard delete at the database level
      todo_tags_after =
        Todos.Tasks.TodoTag
        |> Ash.Query.filter(todo_id == ^todo.id)
        |> Ash.read!()

      # Tags stay because the todo is soft-deleted, not hard-deleted
      assert length(todo_tags_after) == 1
    end
  end
end
