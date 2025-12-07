defmodule TodosWeb.TodosLiveTest do
  use TodosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  # Helper to trigger auto-save by sending the timer message directly
  defp trigger_auto_save(view, params) do
    send(view.pid, {:auto_save, params})
    render(view)
  end

  describe "create todo with tag and view in list" do
    test "created todo with tag appears in todos list with the tag visible", %{conn: conn} do
      # Create a tag with a unique name
      tag = generate(tag(name: "MyUniqueTagName", color: "#ff0000"))

      # Navigate to new todo form
      {:ok, view, _html} = live(conn, ~p"/todos/new")

      # Select the tag by clicking the toggle button
      view |> element("button", "MyUniqueTagName") |> render_click()

      # Fill in the title and trigger auto-save
      params = %{"title" => "My tagged task", "tag_ids" => [tag.id]}

      view
      |> form("#todo-form", todo: %{title: "My tagged task"})
      |> render_change()

      trigger_auto_save(view, params)

      # Verify the todo was created with the tag in the database
      todos = Ash.read!(Todos.Tasks.Todo, load: [:tags])
      assert length(todos) == 1
      todo = hd(todos)
      assert todo.title == "My tagged task"
      assert length(todo.tags) == 1, "Expected todo to have 1 tag, got #{length(todo.tags)}"
      assert hd(todo.tags).name == "MyUniqueTagName"

      # Now navigate to the todos list
      {:ok, _view, html} = live(conn, ~p"/todos")

      # Verify the todo appears with its tag
      assert html =~ "My tagged task"
      assert html =~ "MyUniqueTagName"
    end
  end

  describe "toggle-state (RUN button)" do
    test "clicking RUN on pending todo starts it", %{conn: conn, user: user} do
      # Create a todo in pending state
      todo = generate(todo(user_id: user.id, title: "Pending task"))
      assert todo.state == :pending

      {:ok, view, html} = live(conn, ~p"/todos")
      assert html =~ "Pending task"
      assert html =~ "[PENDING]"

      # Click the RUN button
      view |> element("button", "[RUN]") |> render_click()

      # Verify state changed to in_progress
      html = render(view)
      assert html =~ "[IN_PROGRESS]"

      # Verify in database
      updated_todo = Ash.get!(Todos.Tasks.Todo, todo.id)
      assert updated_todo.state == :in_progress
    end

    test "clicking RUN on in_progress todo completes it", %{conn: conn, user: user} do
      # Create a todo and start it
      todo = generate(todo(user_id: user.id, title: "In progress task"))
      {:ok, todo} = Ash.update(todo, %{}, action: :start, actor: user)
      assert todo.state == :in_progress

      {:ok, view, html} = live(conn, ~p"/todos")
      assert html =~ "In progress task"
      assert html =~ "[IN_PROGRESS]"

      # Click RUN to complete
      view |> element("button", "[RUN]") |> render_click()

      # Todo should disappear from active filter (default)
      html = render(view)
      refute html =~ "In progress task"

      # Verify in database
      updated_todo = Ash.get!(Todos.Tasks.Todo, todo.id)
      assert updated_todo.state == :done
    end

    test "clicking REOPEN on done todo reopens it", %{conn: conn, user: user} do
      # Create a todo and complete it
      todo = generate(todo(user_id: user.id, title: "Done task"))
      {:ok, todo} = Ash.update(todo, %{}, action: :start, actor: user)
      {:ok, todo} = Ash.update(todo, %{}, action: :complete, actor: user)
      assert todo.state == :done

      # View done todos
      {:ok, view, _html} = live(conn, ~p"/todos")
      view |> element("button", "Done") |> render_click()

      html = render(view)
      assert html =~ "Done task"
      assert html =~ "[DONE]"
      assert html =~ "[REOPEN]"

      # Click REOPEN
      view |> element("button", "[REOPEN]") |> render_click()

      # Todo should disappear from done filter
      html = render(view)
      refute html =~ "Done task"

      # Verify in database
      updated_todo = Ash.get!(Todos.Tasks.Todo, todo.id)
      assert updated_todo.state == :pending
    end

    test "clicking RUN on inbox todo starts it", %{conn: conn, user: user} do
      # Create a todo via capture (inbox state)
      todo = generate(captured_todo(user_id: user.id, title: "Inbox task"))
      assert todo.state == :inbox

      {:ok, view, html} = live(conn, ~p"/todos")
      assert html =~ "Inbox task"
      assert html =~ "[INBOX]"

      # Click RUN
      view |> element("button", "[RUN]") |> render_click()

      # Verify state changed to in_progress
      html = render(view)
      assert html =~ "[IN_PROGRESS]"

      # Verify in database
      updated_todo = Ash.get!(Todos.Tasks.Todo, todo.id)
      assert updated_todo.state == :in_progress
    end
  end
end
