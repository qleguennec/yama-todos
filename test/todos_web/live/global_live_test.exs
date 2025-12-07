defmodule TodosWeb.GlobalLiveTest do
  use TodosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "tag completion progress bar" do
    test "shows progress bar with completion percentage for each tag", %{conn: conn, user: user} do
      # Create a tag
      tag = generate(tag(name: "ProgressTag"))

      # Create 4 todos: 1 done, 3 active (25% complete)
      # Must use the :complete action to transition state (state machine)
      done_todo = generate(todo(user_id: user.id, title: "Done task", tag_ids: [tag.id]))
      Ash.update!(done_todo, %{}, action: :complete, actor: user)

      _active1 = generate(todo(user_id: user.id, title: "Active 1", tag_ids: [tag.id]))
      _active2 = generate(todo(user_id: user.id, title: "Active 2", tag_ids: [tag.id]))
      _active3 = generate(todo(user_id: user.id, title: "Active 3", tag_ids: [tag.id]))

      {:ok, _view, html} = live(conn, ~p"/")

      # Should show the tag
      assert html =~ "ProgressTag"

      # Should have a progress bar with 25% width (1 done out of 4 total)
      assert html =~ "width: 25%"
    end

    test "shows 0% progress when no todos are done", %{conn: conn, user: user} do
      tag = generate(tag(name: "ZeroProgress"))
      _active = generate(todo(user_id: user.id, title: "Not done", tag_ids: [tag.id]))

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "ZeroProgress"
      # Progress bar should show 0%
      assert html =~ "width: 0%"
    end

    test "shows 50% progress for half done", %{conn: conn, user: user} do
      tag = generate(tag(name: "HalfDone"))
      done_todo = generate(todo(user_id: user.id, title: "Completed", tag_ids: [tag.id]))
      Ash.update!(done_todo, %{}, action: :complete, actor: user)

      _active = generate(todo(user_id: user.id, title: "In progress", tag_ids: [tag.id]))

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "HalfDone"
      # 50% complete (1 done, 1 active)
      assert html =~ "width: 50%"
    end
  end

  describe "actions column" do
    test "shows run button for pending todos", %{conn: conn, user: user} do
      tag = generate(tag(name: "ActionTest"))
      _todo = generate(todo(user_id: user.id, title: "Pending task", tag_ids: [tag.id]))

      {:ok, _view, html} = live(conn, ~p"/")

      # Should have Actions column header
      assert html =~ "Act"
      # Should have a run button for pending todo
      assert html =~ "[▶]"
    end

    test "clicking run button starts the todo and shows complete button", %{conn: conn, user: user} do
      tag = generate(tag(name: "StartTest"))
      todo = generate(todo(user_id: user.id, title: "To start", tag_ids: [tag.id]))

      {:ok, view, _html} = live(conn, ~p"/")

      # Click the run button
      html = view |> element("button", "[▶]") |> render_click()

      # Verify the todo is now in_progress
      updated = Ash.get!(Todos.Tasks.Todo, todo.id)
      assert updated.state == :in_progress

      # Should now show complete button instead of run
      assert html =~ "[✓]"
      refute html =~ "[▶]"
    end

    test "shows complete button for in_progress todos", %{conn: conn, user: user} do
      tag = generate(tag(name: "InProgressTest"))
      todo = generate(todo(user_id: user.id, title: "Already running", tag_ids: [tag.id]))
      Ash.update!(todo, %{}, action: :start)

      {:ok, _view, html} = live(conn, ~p"/")

      # Should show the todo with WIP state
      assert html =~ "Already running"
      assert html =~ "WIP"
      # Should have complete button
      assert html =~ "[✓]"
    end

    test "clicking complete button completes the todo", %{conn: conn, user: user} do
      tag = generate(tag(name: "CompleteTest"))
      todo = generate(todo(user_id: user.id, title: "To complete", tag_ids: [tag.id]))
      Ash.update!(todo, %{}, action: :start)

      {:ok, view, _html} = live(conn, ~p"/")

      # Click the complete button
      view |> element("button", "[✓]") |> render_click()

      # Verify the todo is now done
      updated = Ash.get!(Todos.Tasks.Todo, todo.id)
      assert updated.state == :done
    end

    test "shows undo button after starting a todo", %{conn: conn, user: user} do
      tag = generate(tag(name: "UndoTest"))
      todo = generate(todo(user_id: user.id, title: "Started task", tag_ids: [tag.id]))

      {:ok, view, html} = live(conn, ~p"/")

      # Initially shows run button, no undo
      assert html =~ "[▶]"
      refute html =~ "[↩]"

      # Start the todo
      html = view |> element("button", "[▶]") |> render_click()

      # Should now show undo button (and complete button)
      assert html =~ "[↩]"
      assert html =~ "[✓]"

      # Verify previous_state was saved
      updated = Ash.get!(Todos.Tasks.Todo, todo.id)
      assert updated.previous_state == :pending
    end

    test "clicking undo button returns to previous state", %{conn: conn, user: user} do
      tag = generate(tag(name: "UndoClickTest"))
      todo = generate(todo(user_id: user.id, title: "To undo", tag_ids: [tag.id]))
      Ash.update!(todo, %{}, action: :start)

      {:ok, view, _html} = live(conn, ~p"/")

      # Click the undo button
      html = view |> element("button", "[↩]") |> render_click()

      # Should return to pending and show run button again
      assert html =~ "[▶]"
      refute html =~ "[↩]"

      # Verify state was reverted
      updated = Ash.get!(Todos.Tasks.Todo, todo.id)
      assert updated.state == :pending
      assert updated.previous_state == nil
    end

    test "undo from in_progress returns to inbox if started from inbox", %{conn: conn, user: user} do
      tag = generate(tag(name: "InboxUndoTest"))
      # Create todo in inbox state
      todo = generate(todo(user_id: user.id, title: "Inbox task", tag_ids: [tag.id], initial_state: :inbox))
      Ash.update!(todo, %{}, action: :start)

      {:ok, view, _html} = live(conn, ~p"/")

      # Click undo
      view |> element("button", "[↩]") |> render_click()

      # Should return to inbox
      updated = Ash.get!(Todos.Tasks.Todo, todo.id)
      assert updated.state == :inbox
    end
  end

  describe "tag ordering" do
    test "global view reflects user's tag order after reordering in tags tab", %{conn: conn, user: user} do
      # Create two tags alphabetically: AAA before ZZZ
      tag_a = generate(tag(name: "AAA-First"))
      tag_z = generate(tag(name: "ZZZ-Last"))

      # Create todos for each tag
      _todo_a = generate(todo(user_id: user.id, title: "Task A", tag_ids: [tag_a.id]))
      _todo_z = generate(todo(user_id: user.id, title: "Task Z", tag_ids: [tag_z.id]))

      # Load global view - tags should be alphabetical (AAA before ZZZ)
      {:ok, global_view, html} = live(conn, ~p"/")
      assert html =~ "AAA-First"
      assert html =~ "ZZZ-Last"

      # Verify AAA comes before ZZZ in the HTML
      aaa_pos = :binary.match(html, "AAA-First") |> elem(0)
      zzz_pos = :binary.match(html, "ZZZ-Last") |> elem(0)
      assert aaa_pos < zzz_pos, "AAA should appear before ZZZ initially"

      # Now open tags view and reorder: put ZZZ first
      {:ok, tags_view, _html} = live(conn, ~p"/tags")

      # Simulate reorder-tags event (ZZZ first, then AAA)
      tags_view |> render_hook("reorder-tags", %{"tag_ids" => [tag_z.id, tag_a.id]})

      # Wait for PubSub message to propagate
      Process.sleep(100)
      html = render(global_view)

      # Now ZZZ should appear before AAA
      zzz_pos_after = :binary.match(html, "ZZZ-Last") |> elem(0)
      aaa_pos_after = :binary.match(html, "AAA-First") |> elem(0)
      assert zzz_pos_after < aaa_pos_after, "ZZZ should appear before AAA after reordering"
    end
  end

  describe "real-time updates" do
    test "refreshes when a todo with a new tag is created", %{conn: conn, user: user} do
      # Create a tag first
      tag =
        Todos.Tasks.Tag
        |> Ash.Changeset.for_create(:create, %{name: "NewTagName", color: "#ff0000"})
        |> Ash.create!()

      # Load the global view - tag exists but has no todos, so not shown
      {:ok, view, html} = live(conn, ~p"/")
      refute html =~ "NewTagName"

      # Create a todo with the tag (simulating what happens in another tab/session)
      _todo =
        Todos.Tasks.Todo
        |> Ash.Changeset.for_create(:create, %{title: "Tagged todo", user_id: user.id})
        |> Ash.Changeset.manage_relationship(:tags, [tag], type: :append)
        |> Ash.create!()

      # Wait for PubSub message to arrive and trigger reload
      Process.sleep(100)
      html = render(view)

      # The view should now show the tag with the todo
      assert html =~ "NewTagName"
      assert html =~ "Tagged todo"
    end

    test "refreshes when a tag is deleted", %{conn: conn, user: user} do
      # Create a tag and a todo with it
      tag = generate(tag(name: "ToBeDeleted"))
      _todo = generate(todo(user_id: user.id, title: "Will lose tag", tag_ids: [tag.id]))

      # Load the global view - should show the tag
      {:ok, view, html} = live(conn, ~p"/")
      assert html =~ "ToBeDeleted"

      # Delete the tag (cascades to remove todo_tags)
      Ash.destroy!(tag)

      # Wait for PubSub message
      Process.sleep(100)
      html = render(view)

      # The tag should no longer appear
      refute html =~ "ToBeDeleted"
    end
  end
end
