defmodule Todos.Tasks.TagTest do
  use Todos.DataCase, async: true

  require Ash.Query

  describe "create" do
    test "creates a tag with valid attributes" do
      tag = generate(tag(name: "Work", color: "#ff0000"))

      assert tag.name == "Work"
      assert tag.color == "#ff0000"
    end

    test "creates a tag with default color" do
      tag = generate(tag(name: "Home"))

      assert tag.name == "Home"
      assert tag.color == "#6366f1"
    end

    test "enforces unique name" do
      generate(tag(name: "Unique"))

      assert_raise Ash.Error.Invalid, fn ->
        generate(tag(name: "Unique"))
      end
    end
  end

  describe "update" do
    test "updates tag name and color" do
      tag = generate(tag(name: "Old Name", color: "#000000"))

      {:ok, updated} =
        tag
        |> Ash.Changeset.for_update(:update, %{name: "New Name", color: "#ffffff"})
        |> Ash.update()

      assert updated.name == "New Name"
      assert updated.color == "#ffffff"
    end
  end

  describe "destroy" do
    test "deletes a tag" do
      tag = generate(tag())

      assert :ok = Ash.destroy(tag)
      assert {:error, _} = Ash.get(Todos.Tasks.Tag, tag.id)
    end

    test "deletes associated todo_tags (cascade)" do
      user = generate(user())
      tag = generate(tag(name: "To Delete"))
      _todo = create_todo_with_tags(user, [tag])

      # Verify the todo_tag association exists
      todo_tags =
        Todos.Tasks.TodoTag
        |> Ash.Query.filter(tag_id == ^tag.id)
        |> Ash.read!()

      assert length(todo_tags) == 1

      # Delete the tag
      assert :ok = Ash.destroy(tag)

      # Verify todo_tags were cascade deleted
      todo_tags_after =
        Todos.Tasks.TodoTag
        |> Ash.Query.filter(tag_id == ^tag.id)
        |> Ash.read!()

      assert todo_tags_after == []
    end
  end

  describe "list_all" do
    test "returns tags sorted by name" do
      generate(tag(name: "Zebra"))
      generate(tag(name: "Alpha"))
      generate(tag(name: "Middle"))

      tags =
        Todos.Tasks.Tag
        |> Ash.Query.for_read(:list_all)
        |> Ash.read!()

      names = Enum.map(tags, & &1.name)
      assert names == ["Alpha", "Middle", "Zebra"]
    end
  end
end
