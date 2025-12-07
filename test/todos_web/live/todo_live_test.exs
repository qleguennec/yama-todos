defmodule TodosWeb.TodoLiveTest do
  use TodosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  # Helper to trigger auto-save by sending the timer message directly
  defp trigger_auto_save(view, params) do
    send(view.pid, {:auto_save, params})
    render(view)
  end

  describe "new todo page" do
    test "renders create form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/todos/new")

      assert html =~ "New Todo"
      assert html =~ "Title"
      assert html =~ "Create Todo"
    end

    test "pre-fills title from query param", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/todos/new?title=My+pre-filled+title")

      assert html =~ "My pre-filled title"
    end

    test "creates todo with valid data", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/todos/new")

      params = %{"title" => "My new todo"}

      view
      |> form("#todo-form", todo: params)
      |> render_change()

      trigger_auto_save(view, params)

      # Should patch URL to the new todo
      assert render(view) =~ "My new todo"

      todos = Ash.read!(Todos.Tasks.Todo)
      assert length(todos) == 1
      assert hd(todos).title == "My new todo"
      assert hd(todos).user_id == user.id
    end

    test "creates todo with all fields", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/todos/new")

      params = %{
        "title" => "Complete todo",
        "description" => "A detailed description",
        "priority" => "high",
        "due_date" => to_string(Date.utc_today()),
        "pinned_to_today" => "true"
      }

      view
      |> form("#todo-form", todo: params)
      |> render_change()

      trigger_auto_save(view, params)

      todos = Ash.read!(Todos.Tasks.Todo)
      todo = hd(todos)
      assert todo.title == "Complete todo"
      assert todo.description == "A detailed description"
      assert todo.priority == :high
      assert todo.due_date == Date.utc_today()
      assert todo.pinned_to_today == true
      assert todo.user_id == user.id
    end

    test "validates form on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/todos/new")

      html =
        view
        |> form("#todo-form", todo: %{title: ""})
        |> render_change()

      assert html =~ "Create Todo"
    end

    test "does not auto-save when title is empty", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/todos/new")

      view
      |> form("#todo-form", todo: %{title: ""})
      |> render_change()

      # No auto-save should be triggered for empty title
      todos = Ash.read!(Todos.Tasks.Todo)
      assert length(todos) == 0
    end
  end

  describe "edit todo page" do
    setup %{user: user} do
      todo =
        Todos.Tasks.Todo
        |> Ash.Changeset.for_create(:create, %{
          title: "Existing todo",
          user_id: user.id
        })
        |> Ash.create!()

      {:ok, todo: todo}
    end

    test "renders edit form with existing data", %{conn: conn, todo: todo} do
      {:ok, _view, html} = live(conn, ~p"/todos/#{todo.id}")

      assert html =~ "Existing todo"
      # Auto-save, no save button
      assert html =~ "Edit Todo"
    end

    test "shows status dropdown with current state selected", %{conn: conn, todo: todo} do
      {:ok, _view, html} = live(conn, ~p"/todos/#{todo.id}")

      # Should have a status dropdown
      assert html =~ "Status"
      assert html =~ ~s(name="todo[state]")
      # Pending should be selected (default state after create)
      assert html =~ ~r/<option[^>]*value="pending"[^>]*selected/
    end

    test "changing status dropdown updates todo state", %{conn: conn, todo: todo} do
      {:ok, view, _html} = live(conn, ~p"/todos/#{todo.id}")

      # Change status to in_progress
      view
      |> form("#todo-form", todo: %{state: "in_progress"})
      |> render_change()

      # Wait for auto-save
      Process.sleep(600)
      render(view)

      # Verify the state was updated
      updated = Ash.get!(Todos.Tasks.Todo, todo.id)
      assert updated.state == :in_progress
      # Previous state should be saved for undo
      assert updated.previous_state == :pending
    end

    test "updates todo via auto-save", %{conn: conn, todo: todo} do
      {:ok, view, _html} = live(conn, ~p"/todos/#{todo.id}")

      params = %{"title" => "Updated title"}

      view
      |> form("#todo-form", todo: params)
      |> render_change()

      trigger_auto_save(view, params)

      updated = Ash.get!(Todos.Tasks.Todo, todo.id)
      assert updated.title == "Updated title"
    end

    test "auto-saves when tag is toggled", %{conn: conn, todo: todo} do
      _tag = generate(tag(name: "AutoSaveTag"))

      {:ok, view, _html} = live(conn, ~p"/todos/#{todo.id}")

      # Toggle the tag - this should trigger auto-save
      view |> element("button", "AutoSaveTag") |> render_click()

      # Wait briefly for the debounced auto-save (in real app it's 500ms)
      # In tests, we need to let the timer fire
      Process.sleep(600)

      # Re-render to process any pending messages
      render(view)

      # Verify the tag was saved to the database
      updated = Ash.get!(Todos.Tasks.Todo, todo.id, load: [:tags])
      assert length(updated.tags) == 1
      assert hd(updated.tags).name == "AutoSaveTag"
    end

    test "shows state transition buttons", %{conn: conn, todo: todo} do
      {:ok, _view, html} = live(conn, ~p"/todos/#{todo.id}")

      assert html =~ "[START]"
      assert html =~ "[COMPLETE]"
    end

    test "toggles subtask completion", %{conn: conn, todo: todo} do
      # Create a subtask
      subtask =
        Todos.Tasks.Subtask
        |> Ash.Changeset.for_create(:create, %{title: "My subtask", todo_id: todo.id})
        |> Ash.create!()

      {:ok, view, html} = live(conn, ~p"/todos/#{todo.id}")

      # Subtask should be shown
      assert html =~ "My subtask"

      # Toggle the subtask (stream uses "subtasks-" prefix)
      view |> element("#subtasks-#{subtask.id} button[phx-click=toggle-subtask]") |> render_click()

      # Verify subtask is now completed in the database
      updated = Ash.get!(Todos.Tasks.Subtask, subtask.id)
      assert updated.completed == true
    end
  end

  describe "tags on new todo" do
    test "displays available tags", %{conn: conn} do
      generate(tag(name: "Work"))
      generate(tag(name: "Personal"))

      {:ok, _view, html} = live(conn, ~p"/todos/new")

      assert html =~ "Work"
      assert html =~ "Personal"
    end

    test "creates todo with selected tags", %{conn: conn} do
      tag1 = generate(tag(name: "Urgent"))
      tag2 = generate(tag(name: "Home"))

      {:ok, view, _html} = live(conn, ~p"/todos/new")

      # Select tags by clicking toggle buttons
      view |> element("button", "Urgent") |> render_click()
      view |> element("button", "Home") |> render_click()

      params = %{"title" => "New task with tags", "tag_ids" => [tag1.id, tag2.id]}

      view
      |> form("#todo-form", todo: %{title: "New task with tags"})
      |> render_change()

      trigger_auto_save(view, params)

      # Should create the todo
      todos = Ash.read!(Todos.Tasks.Todo, load: [:tags])
      assert length(todos) == 1
    end

    test "creates todo without tags", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/todos/new")

      params = %{"title" => "Task without tags"}

      view
      |> form("#todo-form", todo: params)
      |> render_change()

      trigger_auto_save(view, params)

      todos = Ash.read!(Todos.Tasks.Todo)
      assert length(todos) == 1
    end
  end

  describe "inline tag creation" do
    test "clicking +TAG button shows the create tag modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/todos/new")

      # Click the +TAG button
      html = view |> element("button", "+ Tag") |> render_click()

      # Modal should appear
      assert html =~ "Create Tag"
      assert html =~ "[CREATE]"
      assert html =~ "[CANCEL]"
    end

    test "can create a new tag from the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/todos/new")

      # Open the modal
      view |> element("button", "+ Tag") |> render_click()

      # Fill in the tag form and submit
      html =
        view
        |> form("#new-tag-form", %{"tag" => %{"name" => "NewInlineTag", "color" => "#ef4444"}})
        |> render_submit()

      # Modal should close and new tag should appear selected
      refute html =~ "Create Tag"
      assert html =~ "NewInlineTag"

      # Verify tag was created in database
      tags = Ash.read!(Todos.Tasks.Tag)
      assert Enum.any?(tags, fn t -> t.name == "NewInlineTag" end)
    end

    test "newly created tag is auto-selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/todos/new")

      # Open modal and create tag
      view |> element("button", "+ Tag") |> render_click()

      view
      |> form("#new-tag-form", %{"tag" => %{"name" => "AutoSelected", "color" => "#22c55e"}})
      |> render_submit()

      # Get the newly created tag
      tags = Ash.read!(Todos.Tasks.Tag)
      new_tag = Enum.find(tags, fn t -> t.name == "AutoSelected" end)

      # Submit the todo form via auto-save
      params = %{"title" => "Todo with new tag", "tag_ids" => [new_tag.id]}

      view
      |> form("#todo-form", todo: %{title: "Todo with new tag"})
      |> render_change()

      trigger_auto_save(view, params)

      # Verify the todo was created with the new tag
      todos = Ash.read!(Todos.Tasks.Todo, load: [:tags])
      todo = hd(todos)
      assert length(todo.tags) == 1
      assert hd(todo.tags).name == "AutoSelected"
    end

    test "can close the modal with cancel button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/todos/new")

      # Open the modal
      view |> element("button", "+ Tag") |> render_click()

      # Click cancel
      html = view |> element("button", "[CANCEL]") |> render_click()

      # Modal should be closed
      refute html =~ "Create Tag"
    end

    test "inline tag creation works on edit page too", %{conn: conn, user: user} do
      todo =
        Todos.Tasks.Todo
        |> Ash.Changeset.for_create(:create, %{title: "Existing", user_id: user.id})
        |> Ash.create!()

      {:ok, view, _html} = live(conn, ~p"/todos/#{todo.id}")

      # Open modal and create tag
      view |> element("button", "+ Tag") |> render_click()

      view
      |> form("#new-tag-form", %{"tag" => %{"name" => "EditPageTag", "color" => "#3b82f6"}})
      |> render_submit()

      # Get the newly created tag
      tags = Ash.read!(Todos.Tasks.Tag)
      new_tag = Enum.find(tags, fn t -> t.name == "EditPageTag" end)

      # Save the todo via auto-save
      params = %{"title" => "Existing", "tag_ids" => [new_tag.id]}

      view
      |> form("#todo-form", todo: %{title: "Existing"})
      |> render_change()

      trigger_auto_save(view, params)

      # Verify the tag was added
      updated = Ash.get!(Todos.Tasks.Todo, todo.id, load: [:tags])
      assert length(updated.tags) == 1
      assert hd(updated.tags).name == "EditPageTag"
    end
  end

  describe "tags on edit todo" do
    test "shows existing tags as selected", %{conn: conn, user: user} do
      tag1 = generate(tag(name: "Selected"))
      _tag2 = generate(tag(name: "Not Selected"))
      todo = create_todo_with_tags(user, [tag1], title: "My todo")

      {:ok, _view, html} = live(conn, ~p"/todos/#{todo.id}")

      # Both tags should be displayed
      assert html =~ "Selected"
      assert html =~ "Not Selected"
      # Selected tag should have hidden input with its value
      assert html =~ ~s(value="#{tag1.id}")
    end

    test "adds new tag to existing todo", %{conn: conn, user: user} do
      existing_tag = generate(tag(name: "Existing"))
      new_tag = generate(tag(name: "New Tag"))
      todo = create_todo_with_tags(user, [existing_tag])

      {:ok, view, _html} = live(conn, ~p"/todos/#{todo.id}")

      # Click to add the new tag
      view |> element("button", "New Tag") |> render_click()

      params = %{"title" => todo.title, "tag_ids" => [existing_tag.id, new_tag.id]}

      view
      |> form("#todo-form", todo: %{title: todo.title})
      |> render_change()

      trigger_auto_save(view, params)

      # Reload todo and verify both tags
      updated = Ash.get!(Todos.Tasks.Todo, todo.id, load: [:tags])
      tag_names = Enum.map(updated.tags, & &1.name) |> Enum.sort()
      assert tag_names == ["Existing", "New Tag"]
    end

    test "removes tag from todo", %{conn: conn, user: user} do
      tag1 = generate(tag(name: "Keep"))
      tag2 = generate(tag(name: "Remove"))
      todo = create_todo_with_tags(user, [tag1, tag2])

      {:ok, view, _html} = live(conn, ~p"/todos/#{todo.id}")

      # Click to deselect the "Remove" tag
      view |> element("button", "Remove") |> render_click()

      params = %{"title" => todo.title, "tag_ids" => [tag1.id]}

      view
      |> form("#todo-form", todo: %{title: todo.title})
      |> render_change()

      trigger_auto_save(view, params)

      updated = Ash.get!(Todos.Tasks.Todo, todo.id, load: [:tags])
      assert length(updated.tags) == 1
      assert hd(updated.tags).name == "Keep"
    end

    test "clears all tags from todo", %{conn: conn, user: user} do
      tag = generate(tag(name: "To Clear"))
      todo = create_todo_with_tags(user, [tag])

      {:ok, view, _html} = live(conn, ~p"/todos/#{todo.id}")

      # Click to deselect the tag
      view |> element("button", "To Clear") |> render_click()

      params = %{"title" => todo.title, "tag_ids" => []}

      view
      |> form("#todo-form", todo: %{title: todo.title})
      |> render_change()

      trigger_auto_save(view, params)

      updated = Ash.get!(Todos.Tasks.Todo, todo.id, load: [:tags])
      assert updated.tags == []
    end

    test "can select, unselect, and reselect a tag", %{conn: conn, user: user} do
      tag = generate(tag(name: "Toggle Tag"))
      todo = create_todo_with_tags(user, [], title: "Toggle test")

      {:ok, view, _html} = live(conn, ~p"/todos/#{todo.id}")

      # Select the tag by clicking
      view |> element("button", "Toggle Tag") |> render_click()

      params = %{"title" => todo.title, "tag_ids" => [tag.id]}

      view
      |> form("#todo-form", todo: %{title: todo.title})
      |> render_change()

      trigger_auto_save(view, params)

      updated = Ash.get!(Todos.Tasks.Todo, todo.id, load: [:tags])
      assert length(updated.tags) == 1
      assert hd(updated.tags).name == "Toggle Tag"

      # Reload the page and unselect the tag
      {:ok, view, _html} = live(conn, ~p"/todos/#{todo.id}")

      # Click to deselect
      view |> element("button", "Toggle Tag") |> render_click()

      params = %{"title" => todo.title, "tag_ids" => []}

      view
      |> form("#todo-form", todo: %{title: todo.title})
      |> render_change()

      trigger_auto_save(view, params)

      updated = Ash.get!(Todos.Tasks.Todo, todo.id, load: [:tags])
      assert updated.tags == []

      # Reload the page and reselect the tag
      {:ok, view, _html} = live(conn, ~p"/todos/#{todo.id}")

      # Click to select again
      view |> element("button", "Toggle Tag") |> render_click()

      params = %{"title" => todo.title, "tag_ids" => [tag.id]}

      view
      |> form("#todo-form", todo: %{title: todo.title})
      |> render_change()

      trigger_auto_save(view, params)

      updated = Ash.get!(Todos.Tasks.Todo, todo.id, load: [:tags])
      assert length(updated.tags) == 1
      assert hd(updated.tags).name == "Toggle Tag"
    end
  end
end
