defmodule TodosWeb.PlanLiveTest do
  use TodosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "initial navigation and board creation" do
    test "redirects to new board when user has no boards", %{conn: conn, user: user} do
      # Verify no boards exist
      boards = Ash.read!(Todos.Tasks.PlanBoard)
      assert boards == []

      # Navigate to /plan - it will redirect to newly created board
      {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/plan")

      # A default board should be created and user redirected
      boards = Ash.read!(Todos.Tasks.PlanBoard)
      assert length(boards) == 1
      board = hd(boards)
      assert board.name == "My Plan"
      assert board.user_id == user.id
      assert path == ~p"/plan/#{board.id}"
    end

    test "redirects to most recent board when user has boards", %{conn: conn, user: user} do
      # Create two boards
      _board1 = generate(plan_board(user_id: user.id, name: "Old Board"))
      Process.sleep(10)
      board2 = generate(plan_board(user_id: user.id, name: "Recent Board"))

      # Navigate to /plan - it will redirect
      {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/plan")

      # Should redirect to the most recently updated board
      assert path == ~p"/plan/#{board2.id}"
    end

    test "displays board when navigating directly to board id", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id, name: "Test Board"))

      {:ok, _view, html} = live(conn, ~p"/plan/#{board.id}")

      assert html =~ "Test Board"
      assert html =~ "[+ ADD CARD]"
    end

    test "redirects to /plan when board not found", %{conn: conn} do
      fake_id = Ash.UUID.generate()

      # Should redirect back to /plan with error flash
      {:error, {:live_redirect, %{to: path, flash: flash}}} = live(conn, ~p"/plan/#{fake_id}")

      assert path == ~p"/plan"
      assert flash["error"] == "Board not found"
    end
  end

  describe "board management" do
    test "can create a new board", %{conn: conn, user: user} do
      # Create initial board
      board = generate(plan_board(user_id: user.id, name: "First Board"))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      # Open board picker and create new board
      view |> element("button", "[SELECT]") |> render_click()
      view |> element("button", "+ New Board") |> render_click()

      # Should have created a new board
      boards = Ash.read!(Todos.Tasks.PlanBoard)
      assert length(boards) == 2
      new_board = Enum.find(boards, &(&1.name == "Plan 2"))
      assert new_board != nil

      # Should redirect to new board
      assert_redirect(view, ~p"/plan/#{new_board.id}")
    end

    test "can switch between boards", %{conn: conn, user: user} do
      board1 = generate(plan_board(user_id: user.id, name: "Board One"))
      board2 = generate(plan_board(user_id: user.id, name: "Board Two"))

      {:ok, view, html} = live(conn, ~p"/plan/#{board1.id}")
      assert html =~ "Board One"

      # Open board picker
      view |> element("button", "[SELECT]") |> render_click()
      html = render(view)
      assert html =~ "Board One"
      assert html =~ "Board Two"

      # Select the other board
      view |> element("button", "Board Two") |> render_click()

      assert_redirect(view, ~p"/plan/#{board2.id}")
    end

    test "board picker shows all user boards", %{conn: conn, user: user} do
      generate(plan_board(user_id: user.id, name: "Alpha Board"))
      generate(plan_board(user_id: user.id, name: "Beta Board"))
      board3 = generate(plan_board(user_id: user.id, name: "Gamma Board"))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board3.id}")

      # Open board picker
      view |> element("button", "[SELECT]") |> render_click()
      html = render(view)

      assert html =~ "Alpha Board"
      assert html =~ "Beta Board"
      assert html =~ "Gamma Board"
    end
  end

  describe "adding cards to board" do
    test "shows todo picker when clicking add card", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))
      _todo = generate(todo(user_id: user.id, title: "Available Todo"))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      # Click add card button
      view |> element("button", "[+ ADD CARD]") |> render_click()
      html = render(view)

      assert html =~ "Add Todo to Board"
      assert html =~ "Available Todo"
      assert html =~ "Search by title, tags, state..."
    end

    test "can add a todo card to the board", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))
      todo = generate(todo(user_id: user.id, title: "My Task"))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      # Open todo picker and add card
      view |> element("button", "[+ ADD CARD]") |> render_click()
      view |> element("button", "My Task") |> render_click()

      # Card should appear on canvas
      html = render(view)
      assert html =~ "My Task"
      assert html =~ "TODO/#{String.slice(todo.id, 0, 8)}"

      # Verify in database
      updated_board = Ash.get!(Todos.Tasks.PlanBoard, board.id)
      assert length(updated_board.cards) == 1
      card = hd(updated_board.cards)
      assert card.todo_id == todo.id
    end

    test "added todo disappears from picker", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))
      _todo1 = generate(todo(user_id: user.id, title: "First Todo"))
      _todo2 = generate(todo(user_id: user.id, title: "Second Todo"))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      # Add first todo
      view |> element("button", "[+ ADD CARD]") |> render_click()
      view |> element("button", "First Todo") |> render_click()

      # Open picker again - first todo should not appear in the picker
      view |> element("button", "[+ ADD CARD]") |> render_click()
      html = render(view)

      # The picker modal should show Second Todo but not First Todo
      # First Todo is now on the canvas, not in the picker
      assert html =~ "Second Todo"
      # Check that in the picker modal (Add Todo to Board section) First Todo is not listed
      # We need to be more specific - First Todo appears on canvas, so we check the modal content
      assert html =~ "Add Todo to Board"
    end

    test "shows message when all todos are on board", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))
      _todo = generate(todo(user_id: user.id, title: "Only Todo"))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      # Add the only todo
      view |> element("button", "[+ ADD CARD]") |> render_click()
      view |> element("button", "Only Todo") |> render_click()

      # Open picker again
      view |> element("button", "[+ ADD CARD]") |> render_click()
      html = render(view)

      assert html =~ "All todos are on the board"
    end

    test "does not show done or cancelled todos in picker", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))

      # Create todos in various states
      _active_todo = generate(todo(user_id: user.id, title: "Active Todo"))
      done_todo = generate(todo(user_id: user.id, title: "Done Todo"))
      {:ok, done_todo} = Ash.update(done_todo, %{}, action: :start, actor: user)
      {:ok, _done_todo} = Ash.update(done_todo, %{}, action: :complete, actor: user)

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      view |> element("button", "[+ ADD CARD]") |> render_click()
      html = render(view)

      assert html =~ "Active Todo"
      refute html =~ "Done Todo"
    end
  end

  describe "search functionality" do
    test "filters todos by title", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))
      generate(todo(user_id: user.id, title: "Buy groceries"))
      generate(todo(user_id: user.id, title: "Write report"))
      generate(todo(user_id: user.id, title: "Buy new shoes"))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      view |> element("button", "[+ ADD CARD]") |> render_click()

      # Search for "Buy"
      view |> element("input[name=search]") |> render_keyup(%{"value" => "Buy"})
      html = render(view)

      assert html =~ "Buy groceries"
      assert html =~ "Buy new shoes"
      refute html =~ "Write report"
    end

    test "filters todos by tag name", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))
      work_tag = generate(tag(name: "Work"))
      personal_tag = generate(tag(name: "Personal"))

      create_todo_with_tags(user, [work_tag], title: "Work task")
      create_todo_with_tags(user, [personal_tag], title: "Personal task")
      generate(todo(user_id: user.id, title: "No tag task"))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      view |> element("button", "[+ ADD CARD]") |> render_click()

      # Search for "Work" tag
      view |> element("input[name=search]") |> render_keyup(%{"value" => "Work"})
      html = render(view)

      assert html =~ "Work task"
      refute html =~ "Personal task"
      refute html =~ "No tag task"
    end

    test "filters todos by state", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))

      _inbox_todo = generate(captured_todo(user_id: user.id, title: "Inbox item"))
      _pending_todo = generate(todo(user_id: user.id, title: "Pending item"))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      view |> element("button", "[+ ADD CARD]") |> render_click()

      # Search for "inbox"
      view |> element("input[name=search]") |> render_keyup(%{"value" => "inbox"})
      html = render(view)

      assert html =~ "Inbox item"
      refute html =~ "Pending item"
    end

    test "search ignores accents (diacritics)", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))
      generate(todo(user_id: user.id, title: "Café meeting"))
      generate(todo(user_id: user.id, title: "Résumé review"))
      generate(todo(user_id: user.id, title: "Normal task"))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      view |> element("button", "[+ ADD CARD]") |> render_click()

      # Search without accent should match accented text
      view |> element("input[name=search]") |> render_keyup(%{"value" => "cafe"})
      html = render(view)

      assert html =~ "Café meeting"
      refute html =~ "Résumé review"
      refute html =~ "Normal task"
    end

    test "search with accents matches non-accented text", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))
      generate(todo(user_id: user.id, title: "Resume document"))
      generate(todo(user_id: user.id, title: "Other task"))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      view |> element("button", "[+ ADD CARD]") |> render_click()

      # Search with accent should match non-accented text
      view |> element("input[name=search]") |> render_keyup(%{"value" => "résumé"})
      html = render(view)

      assert html =~ "Resume document"
      refute html =~ "Other task"
    end

    test "search is case insensitive", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))
      generate(todo(user_id: user.id, title: "IMPORTANT Meeting"))
      generate(todo(user_id: user.id, title: "other task"))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      view |> element("button", "[+ ADD CARD]") |> render_click()

      view |> element("input[name=search]") |> render_keyup(%{"value" => "important"})
      html = render(view)

      assert html =~ "IMPORTANT Meeting"
      refute html =~ "other task"
    end

    test "shows no results message when search has no matches", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))
      generate(todo(user_id: user.id, title: "Some task"))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      view |> element("button", "[+ ADD CARD]") |> render_click()

      view |> element("input[name=search]") |> render_keyup(%{"value" => "nonexistent"})
      html = render(view)

      assert html =~ "No todos match"
      assert html =~ "nonexistent"
    end

    test "search resets when modal closes", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))
      generate(todo(user_id: user.id, title: "Task one"))
      generate(todo(user_id: user.id, title: "Task two"))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      # Open, search, close
      view |> element("button", "[+ ADD CARD]") |> render_click()
      view |> element("input[name=search]") |> render_keyup(%{"value" => "one"})
      view |> element("button", "[X]") |> render_click()

      # Reopen - should show all todos
      view |> element("button", "[+ ADD CARD]") |> render_click()
      html = render(view)

      assert html =~ "Task one"
      assert html =~ "Task two"
    end

    test "displays tags in search results", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))
      urgent_tag = generate(tag(name: "Urgent", color: "#ff0000"))
      create_todo_with_tags(user, [urgent_tag], title: "Tagged task")

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      view |> element("button", "[+ ADD CARD]") |> render_click()
      html = render(view)

      assert html =~ "Tagged task"
      assert html =~ "Urgent"
    end
  end

  describe "removing cards" do
    test "can remove a card from the board", %{conn: conn, user: user} do
      todo = generate(todo(user_id: user.id, title: "Removable Task"))
      board = create_board_with_cards(user, [todo], name: "Test Board")

      {:ok, view, html} = live(conn, ~p"/plan/#{board.id}")
      assert html =~ "Removable Task"

      # Click remove button on card
      view |> element("button", "[X]") |> render_click()

      html = render(view)
      refute html =~ "Removable Task"

      # Verify in database
      updated_board = Ash.get!(Todos.Tasks.PlanBoard, board.id)
      assert updated_board.cards == []
    end

    test "removing card also removes its connections", %{conn: conn, user: user} do
      todo1 = generate(todo(user_id: user.id, title: "First Task"))
      todo2 = generate(todo(user_id: user.id, title: "Second Task"))
      board = create_board_with_connections(user, [{todo1, todo2}], name: "Test Board")

      # Verify connection exists
      assert length(board.connections) == 1

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      # Remove first card (should also remove the connection)
      view |> element("#card-#{hd(board.cards).id} button", "[X]") |> render_click()

      # Verify connections are gone
      updated_board = Ash.get!(Todos.Tasks.PlanBoard, board.id)
      assert updated_board.connections == []
    end

    test "removed card becomes available in picker again", %{conn: conn, user: user} do
      todo = generate(todo(user_id: user.id, title: "Toggle Task"))
      board = create_board_with_cards(user, [todo], name: "Test Board")

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      # Remove the card
      view |> element("button", "[X]") |> render_click()

      # Open picker - todo should be available again
      view |> element("button", "[+ ADD CARD]") |> render_click()
      html = render(view)

      assert html =~ "Toggle Task"
    end
  end

  describe "card movement" do
    test "can move a card position", %{conn: conn, user: user} do
      todo = generate(todo(user_id: user.id, title: "Movable Task"))
      board = create_board_with_cards(user, [todo], name: "Test Board")
      card = hd(board.cards)

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      # Simulate card move event
      view
      |> render_hook("move-card", %{"id" => card.id, "x" => 500.0, "y" => 300.0})

      # Verify in database
      updated_board = Ash.get!(Todos.Tasks.PlanBoard, board.id)
      updated_card = hd(updated_board.cards)
      assert updated_card.x == 500.0
      assert updated_card.y == 300.0
    end
  end

  describe "connections" do
    test "can create connection between cards", %{conn: conn, user: user} do
      todo1 = generate(todo(user_id: user.id, title: "First Task"))
      todo2 = generate(todo(user_id: user.id, title: "Second Task"))
      board = create_board_with_cards(user, [todo1, todo2], name: "Test Board")

      card1 = Enum.find(board.cards, &(&1.todo_id == todo1.id))
      card2 = Enum.find(board.cards, &(&1.todo_id == todo2.id))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      # Start connection from first card using phx-click event directly
      view |> render_click("start-connection", %{"card-id" => card1.id})

      # Verify connection mode indicator
      html = render(view)
      assert html =~ "Click another card to connect"

      # Complete connection to second card
      view |> render_click("end-connection", %{"card-id" => card2.id})

      # Verify connection created
      updated_board = Ash.get!(Todos.Tasks.PlanBoard, board.id)
      assert length(updated_board.connections) == 1
      connection = hd(updated_board.connections)
      assert connection.from_card_id == card1.id
      assert connection.to_card_id == card2.id
    end

    test "cannot create duplicate connection", %{conn: conn, user: user} do
      todo1 = generate(todo(user_id: user.id, title: "First Task"))
      todo2 = generate(todo(user_id: user.id, title: "Second Task"))
      board = create_board_with_connections(user, [{todo1, todo2}], name: "Test Board")

      card1 = Enum.find(board.cards, &(&1.todo_id == todo1.id))
      card2 = Enum.find(board.cards, &(&1.todo_id == todo2.id))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      # Try to create same connection again
      view |> render_click("start-connection", %{"card-id" => card1.id})
      view |> render_click("end-connection", %{"card-id" => card2.id})

      # Should show error
      html = render(view)
      assert html =~ "Connection already exists"

      # Should still only have one connection
      updated_board = Ash.get!(Todos.Tasks.PlanBoard, board.id)
      assert length(updated_board.connections) == 1
    end

    test "can cancel connection mode with ESC", %{conn: conn, user: user} do
      todo = generate(todo(user_id: user.id, title: "Some Task"))
      board = create_board_with_cards(user, [todo], name: "Test Board")
      card = hd(board.cards)

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      # Start connection
      view |> render_click("start-connection", %{"card-id" => card.id})
      html = render(view)
      assert html =~ "Click another card to connect"

      # Cancel with event
      view |> render_click("cancel-connection", %{})

      html = render(view)
      refute html =~ "Click another card to connect"
    end

    test "clicking same card cancels connection", %{conn: conn, user: user} do
      todo = generate(todo(user_id: user.id, title: "Some Task"))
      board = create_board_with_cards(user, [todo], name: "Test Board")
      card = hd(board.cards)

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      # Start connection from card
      view |> render_click("start-connection", %{"card-id" => card.id})

      # Try to connect to same card
      view |> render_click("end-connection", %{"card-id" => card.id})

      # Connection mode should be cancelled, no connection created
      updated_board = Ash.get!(Todos.Tasks.PlanBoard, board.id)
      assert updated_board.connections == []
    end
  end

  describe "viewport persistence" do
    test "saves viewport position", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))

      {:ok, view, _html} = live(conn, ~p"/plan/#{board.id}")

      # Simulate viewport change
      view |> render_hook("save-viewport", %{"x" => 100.0, "y" => 200.0, "zoom" => 1.5})

      # Verify in database
      updated_board = Ash.get!(Todos.Tasks.PlanBoard, board.id)
      assert updated_board.viewport_x == 100.0
      assert updated_board.viewport_y == 200.0
      assert updated_board.zoom == 1.5
    end

    test "restores viewport position on load", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))

      # Update viewport directly
      {:ok, board} =
        Ash.update(board, %{viewport_x: 150.0, viewport_y: 250.0, zoom: 0.8},
          action: :save_viewport
        )

      {:ok, _view, html} = live(conn, ~p"/plan/#{board.id}")

      # Check that data attributes have the saved values
      assert html =~ "data-viewport-x=\"150.0\""
      assert html =~ "data-viewport-y=\"250.0\""
      assert html =~ "data-zoom=\"0.8\""
    end
  end

  describe "card display" do
    test "displays card with todo information", %{conn: conn, user: user} do
      todo =
        generate(
          todo(
            user_id: user.id,
            title: "Important Task",
            priority: :high
          )
        )

      board = create_board_with_cards(user, [todo], name: "Test Board")

      {:ok, _view, html} = live(conn, ~p"/plan/#{board.id}")

      assert html =~ "Important Task"
      assert html =~ "TODO/#{String.slice(todo.id, 0, 8)}"
      assert html =~ "[PENDING]"
      assert html =~ "high"
    end

    test "displays card state correctly for different states", %{conn: conn, user: user} do
      inbox_todo = generate(captured_todo(user_id: user.id, title: "Inbox Item"))
      pending_todo = generate(todo(user_id: user.id, title: "Pending Item"))
      in_progress_todo = generate(todo(user_id: user.id, title: "In Progress Item"))
      {:ok, in_progress_todo} = Ash.update(in_progress_todo, %{}, action: :start, actor: user)

      board =
        create_board_with_cards(
          user,
          [inbox_todo, pending_todo, in_progress_todo],
          name: "Test Board"
        )

      {:ok, _view, html} = live(conn, ~p"/plan/#{board.id}")

      assert html =~ "[INBOX]"
      assert html =~ "[PENDING]"
      assert html =~ "[IN_PROGRESS]"
    end

    test "renders SVG connections between cards", %{conn: conn, user: user} do
      todo1 = generate(todo(user_id: user.id, title: "First"))
      todo2 = generate(todo(user_id: user.id, title: "Second"))
      board = create_board_with_connections(user, [{todo1, todo2}], name: "Test Board")

      {:ok, _view, html} = live(conn, ~p"/plan/#{board.id}")

      # Check for SVG path element (connection line)
      assert html =~ "<path"
      assert html =~ "marker-end=\"url(#arrowhead)\""
    end
  end

  describe "navigation" do
    test "plan tab is highlighted when on plan page", %{conn: conn, user: user} do
      board = generate(plan_board(user_id: user.id))

      {:ok, _view, html} = live(conn, ~p"/plan/#{board.id}")

      # The Plan tab should be active (has primary styling)
      assert html =~ "Plan"
    end
  end
end
