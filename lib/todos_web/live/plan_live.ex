defmodule TodosWeb.PlanLive do
  use TodosWeb, :live_view

  require Ash.Query

  @impl true
  def mount(%{"id" => board_id}, _session, socket) do
    board = load_board(board_id)

    if board do
      todos_map = load_todos_for_board(board)
      available_todos = load_available_todos(board)

      {:ok,
       socket
       |> assign(:page_title, board.name)
       |> assign(:board, board)
       |> assign(:todos_map, todos_map)
       |> assign(:available_todos, available_todos)
       |> assign(:filtered_todos, available_todos)
       |> assign(:todo_search, "")
       |> assign(:show_todo_picker, false)
       |> assign(:show_board_picker, false)
       |> assign(:boards, load_user_boards(socket.assigns.current_user))
       |> assign(:connecting_from, nil)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Board not found")
       |> push_navigate(to: ~p"/plan")}
    end
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    boards = load_user_boards(user)

    # If user has boards, redirect to the most recently updated one
    # Otherwise, create a default board
    case boards do
      [board | _] ->
        {:ok, push_navigate(socket, to: ~p"/plan/#{board.id}")}

      [] ->
        case create_default_board(user) do
          {:ok, board} ->
            {:ok, push_navigate(socket, to: ~p"/plan/#{board.id}")}

          {:error, _} ->
            {:ok,
             socket
             |> assign(:page_title, "Plan")
             |> assign(:board, nil)
             |> assign(:todos_map, %{})
             |> assign(:available_todos, [])
             |> assign(:filtered_todos, [])
             |> assign(:todo_search, "")
             |> assign(:show_todo_picker, false)
             |> assign(:show_board_picker, false)
             |> assign(:boards, [])
             |> assign(:connecting_from, nil)}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} active_tab={:plan} fullscreen={true}>
      <div class="flex flex-col h-full">
        <%!-- Toolbar --%>
        <div class="flex-none bg-base-200 border-b-2 border-black px-3 py-2 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <%!-- Board selector --%>
            <div class="relative">
              <button
                type="button"
                class="flex items-center gap-2 font-mono text-xs uppercase tracking-wider hover:text-primary transition-colors"
                phx-click="toggle-board-picker"
              >
                <span class="font-bold">{(@board && @board.name) || "No Board"}</span>
                <span class="text-base-content/50">[SELECT]</span>
              </button>

              <div
                :if={@show_board_picker}
                class="absolute top-full left-0 mt-1 z-50 bg-base-100 border-2 border-black shadow-[4px_4px_0_0_black] min-w-48"
                phx-click-away="close-board-picker"
              >
                <div class="bg-black text-white px-3 py-1.5 font-mono text-xs uppercase tracking-wider">
                  Select Board
                </div>
                <div class="divide-y divide-black/20">
                  <%= for board <- @boards do %>
                    <button
                      type="button"
                      class={[
                        "w-full text-left px-3 py-2 font-mono text-sm hover:bg-base-200 transition-colors",
                        @board && @board.id == board.id && "bg-primary/10"
                      ]}
                      phx-click="select-board"
                      phx-value-id={board.id}
                    >
                      {board.name}
                    </button>
                  <% end %>
                  <button
                    type="button"
                    class="w-full text-left px-3 py-2 font-mono text-sm hover:bg-base-200 transition-colors text-primary"
                    phx-click="new-board"
                  >
                    + New Board
                  </button>
                </div>
              </div>
            </div>
          </div>

          <div class="flex items-center gap-2">
            <%!-- Zoom indicator --%>
            <span class="font-mono text-xs text-base-content/50">
              {round(((@board && @board.zoom) || 1.0) * 100)}%
            </span>

            <%!-- Add card button --%>
            <button
              type="button"
              class="px-2 py-1 border-2 border-black bg-base-100 hover:bg-black hover:text-white transition-all font-mono text-xs uppercase tracking-wider"
              phx-click="toggle-todo-picker"
            >
              [+ ADD CARD]
            </button>
          </div>
        </div>

        <%!-- Canvas container --%>
        <div
          id="plan-canvas"
          class="flex-1 relative overflow-hidden bg-base-300 cursor-grab active:cursor-grabbing"
          phx-hook="PlanCanvas"
          data-viewport-x={(@board && @board.viewport_x) || 0}
          data-viewport-y={(@board && @board.viewport_y) || 0}
          data-zoom={(@board && @board.zoom) || 1}
        >
          <%!-- Infinite dot pattern overlay --%>
          <div
            id="canvas-grid"
            class="absolute inset-0 pointer-events-none opacity-20"
            style={"background-image: radial-gradient(circle, currentColor 1px, transparent 1px); background-size: #{40 * ((@board && @board.zoom) || 1)}px #{40 * ((@board && @board.zoom) || 1)}px; background-position: #{(@board && @board.viewport_x) || 0}px #{(@board && @board.viewport_y) || 0}px;"}
          >
          </div>

          <%!-- Canvas controller (transforms for pan/zoom) --%>
          <div
            id="canvas-controller"
            data-canvas-controller
            class="absolute origin-top-left"
            style={"transform: translate(#{@board && @board.viewport_x || 0}px, #{@board && @board.viewport_y || 0}px) scale(#{@board && @board.zoom || 1})"}
          >
            <%!-- SVG layer for connections --%>
            <svg class="absolute pointer-events-none overflow-visible">
              <defs>
                <marker
                  id="arrowhead"
                  markerWidth="10"
                  markerHeight="7"
                  refX="9"
                  refY="3.5"
                  orient="auto"
                  markerUnits="strokeWidth"
                >
                  <polygon points="0 0, 10 3.5, 0 7" fill="currentColor" />
                </marker>
              </defs>

              <%= if @board do %>
                <%= for conn <- @board.connections do %>
                  <% from_card = Enum.find(@board.cards, &(&1.id == conn.from_card_id)) %>
                  <% to_card = Enum.find(@board.cards, &(&1.id == conn.to_card_id)) %>
                  <%= if from_card && to_card do %>
                    <g class="connection" data-connection-id={conn.id}>
                      <path
                        d={bezier_path(from_card, to_card)}
                        stroke="currentColor"
                        stroke-width="2"
                        fill="none"
                        marker-end="url(#arrowhead)"
                        class="text-base-content"
                      />
                      <%= if conn.label do %>
                        <text
                          x={(from_card.x + from_card.width / 2 + to_card.x + to_card.width / 2) / 2}
                          y={
                            (from_card.y + from_card.height / 2 + to_card.y + to_card.height / 2) /
                              2 - 10
                          }
                          text-anchor="middle"
                          class="fill-base-content/70 text-xs font-mono"
                        >
                          {conn.label}
                        </text>
                      <% end %>
                    </g>
                  <% end %>
                <% end %>
              <% end %>
            </svg>

            <%!-- Cards layer --%>
            <%= if @board do %>
              <%= for card <- @board.cards do %>
                <% todo = Map.get(@todos_map, card.todo_id) %>
                <%= if todo do %>
                  <div
                    id={"card-#{card.id}"}
                    class="absolute select-none"
                    style={"left: #{card.x}px; top: #{card.y}px; width: #{card.width}px; height: #{card.height}px;"}
                    data-card-id={card.id}
                    phx-hook="PlanCard"
                  >
                    <div class="bg-base-200 border-2 border-black shadow-[4px_4px_0_0_black] cursor-move hover:shadow-[2px_2px_0_0_black] hover:translate-x-0.5 hover:translate-y-0.5 transition-all h-full">
                      <%!-- Terminal-style header --%>
                      <div class="bg-black text-white px-3 py-1.5 flex items-center justify-between font-mono text-[10px]">
                        <span class="uppercase tracking-wider">
                          TODO/{String.slice(todo.id, 0, 8)}
                        </span>
                        <div class="flex items-center gap-2">
                          <span class={[
                            "uppercase",
                            todo.state == :done && "text-success",
                            todo.state == :in_progress && "text-primary",
                            todo.state == :waiting && "text-warning",
                            todo.state in [:inbox, :pending] && "text-white/70"
                          ]}>
                            [{state_label(todo.state)}]
                          </span>
                          <button
                            type="button"
                            class="hover:text-error transition-colors"
                            phx-click="remove-card"
                            phx-value-id={card.id}
                          >
                            [X]
                          </button>
                        </div>
                      </div>

                      <%!-- Card content --%>
                      <div class="p-3">
                        <h3 class={[
                          "font-sans font-bold text-sm mb-2 line-clamp-2",
                          todo.state == :done && "line-through opacity-50"
                        ]}>
                          {todo.title}
                        </h3>

                        <%= if todo.priority do %>
                          <div class="font-mono text-[10px] uppercase text-base-content/60">
                            Priority:
                            <span class={[
                              todo.priority == :urgent && "text-error",
                              todo.priority == :high && "text-warning",
                              todo.priority == :medium && "text-info"
                            ]}>
                              {todo.priority}
                            </span>
                          </div>
                        <% end %>
                      </div>

                      <%!-- Connection dots --%>
                      <div
                        class="absolute -right-2 top-1/2 -translate-y-1/2 w-4 h-4 rounded-full border-2 border-black bg-white cursor-crosshair hover:bg-primary hover:border-primary transition-colors"
                        data-connection-source={card.id}
                        phx-click="start-connection"
                        phx-value-card-id={card.id}
                      />
                      <div
                        class="absolute -left-2 top-1/2 -translate-y-1/2 w-4 h-4 rounded-full border-2 border-black bg-white cursor-crosshair hover:bg-primary hover:border-primary transition-colors"
                        data-connection-target={card.id}
                        phx-click="end-connection"
                        phx-value-card-id={card.id}
                      />
                    </div>
                  </div>
                <% end %>
              <% end %>
            <% end %>
          </div>

          <%!-- Connection mode indicator --%>
          <div
            :if={@connecting_from}
            class="absolute top-4 left-1/2 -translate-x-1/2 bg-primary text-primary-content px-4 py-2 font-mono text-xs uppercase tracking-wider border-2 border-black shadow-[4px_4px_0_0_black]"
          >
            Click another card to connect, or press ESC to cancel
          </div>
        </div>

        <%!-- Todo picker modal --%>
        <div
          :if={@show_todo_picker}
          class="absolute inset-0 z-50 flex items-center justify-center bg-black/50"
        >
          <div
            class="bg-base-100 border-2 border-black shadow-[8px_8px_0_0_black] w-full max-w-md flex flex-col"
            phx-click-away="close-todo-picker"
          >
            <div class="bg-black text-white px-4 py-2 font-mono text-sm uppercase tracking-wider flex items-center justify-between">
              <span>Add Todo to Board</span>
              <button type="button" phx-click="close-todo-picker" class="hover:text-error">
                [X]
              </button>
            </div>

            <%!-- Search bar --%>
            <div class="p-3 border-b-2 border-black">
              <input
                type="text"
                name="search"
                value={@todo_search}
                placeholder="Search by title, tags, state..."
                phx-keyup="search-todos"
                phx-debounce="150"
                class="w-full input input-sm border-2 border-black rounded-none font-mono text-sm placeholder:text-base-content/40"
                autofocus
              />
            </div>

            <div class="overflow-y-auto divide-y divide-black/20 max-h-80">
              <%= if @filtered_todos == [] do %>
                <div class="p-8 text-center text-base-content/50">
                  <p class="font-mono text-sm uppercase">
                    <%= if @todo_search != "" do %>
                      No todos match "{@todo_search}"
                    <% else %>
                      All todos are on the board
                    <% end %>
                  </p>
                </div>
              <% else %>
                <%= for todo <- @filtered_todos do %>
                  <button
                    type="button"
                    class="w-full text-left p-3 hover:bg-base-200 transition-colors"
                    phx-click="add-card"
                    phx-value-todo-id={todo.id}
                  >
                    <div class="font-bold text-sm">{todo.title}</div>
                    <div class="font-mono text-xs text-base-content/60 mt-1 flex items-center gap-2">
                      <span class="uppercase">[{state_label(todo.state)}]</span>
                      <%= if todo.priority do %>
                        <span class="uppercase">Priority: {todo.priority}</span>
                      <% end %>
                    </div>
                    <%= if todo.tags != [] do %>
                      <div class="flex items-center gap-1 mt-2 flex-wrap">
                        <%= for tag <- todo.tags do %>
                          <span class="inline-flex items-center gap-1 px-1.5 py-0.5 bg-base-200 border border-base-300 font-mono text-[10px] uppercase">
                            <span class="w-1.5 h-1.5" style={"background-color: #{tag.color}"} />
                            {tag.name}
                          </span>
                        <% end %>
                      </div>
                    <% end %>
                  </button>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Event handlers

  @impl true
  def handle_event("toggle-todo-picker", _params, socket) do
    show = !socket.assigns.show_todo_picker

    socket =
      if show do
        # Reset search when opening
        socket
        |> assign(:todo_search, "")
        |> assign(:filtered_todos, socket.assigns.available_todos)
      else
        socket
      end

    {:noreply, assign(socket, :show_todo_picker, show)}
  end

  def handle_event("close-todo-picker", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_todo_picker, false)
     |> assign(:todo_search, "")
     |> assign(:filtered_todos, socket.assigns.available_todos)}
  end

  def handle_event("search-todos", %{"value" => search}, socket) do
    search = String.trim(search)
    available = socket.assigns.available_todos

    filtered =
      if search == "" do
        available
      else
        search_normalized = normalize_text(search)

        Enum.filter(available, fn todo ->
          matches_search?(todo, search_normalized)
        end)
      end

    {:noreply,
     socket
     |> assign(:todo_search, search)
     |> assign(:filtered_todos, filtered)}
  end

  # Normalize text: lowercase and remove diacritics (accents)
  # "éàü" -> "eau", "Café" -> "cafe"
  defp normalize_text(text) do
    text
    |> String.downcase()
    |> String.normalize(:nfd)
    |> String.replace(~r/[\x{0300}-\x{036f}]/u, "")
  end

  # Full-text search across title, description, tags, and state
  defp matches_search?(todo, search_normalized) do
    # Search in title
    title_match = String.contains?(normalize_text(todo.title || ""), search_normalized)

    # Search in description
    description_match =
      String.contains?(normalize_text(todo.description || ""), search_normalized)

    # Search in state
    state_match = String.contains?(normalize_text(to_string(todo.state)), search_normalized)

    # Search in priority
    priority_match =
      String.contains?(normalize_text(to_string(todo.priority || "")), search_normalized)

    # Search in tags
    tags_match =
      Enum.any?(todo.tags || [], fn tag ->
        String.contains?(normalize_text(tag.name), search_normalized)
      end)

    title_match || description_match || state_match || priority_match || tags_match
  end

  def handle_event("toggle-board-picker", _params, socket) do
    {:noreply, assign(socket, :show_board_picker, !socket.assigns.show_board_picker)}
  end

  def handle_event("close-board-picker", _params, socket) do
    {:noreply, assign(socket, :show_board_picker, false)}
  end

  def handle_event("select-board", %{"id" => board_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_board_picker, false)
     |> push_navigate(to: ~p"/plan/#{board_id}")}
  end

  def handle_event("new-board", _params, socket) do
    name = "Plan #{length(socket.assigns.boards) + 1}"

    case Ash.create(Todos.Tasks.PlanBoard, %{name: name, user_id: socket.assigns.current_user.id}) do
      {:ok, board} ->
        {:noreply,
         socket
         |> assign(:show_board_picker, false)
         |> push_navigate(to: ~p"/plan/#{board.id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not create board")}
    end
  end

  def handle_event("add-card", %{"todo-id" => todo_id}, socket) do
    board = socket.assigns.board

    # Place new card near center of visible area
    # (offset by viewport position to appear in view)
    x = -board.viewport_x + 200 + :rand.uniform(100)
    y = -board.viewport_y + 200 + :rand.uniform(100)

    new_card = %{
      id: Ash.UUID.generate(),
      todo_id: todo_id,
      x: x,
      y: y,
      width: 220,
      height: 140
    }

    updated_cards = board.cards ++ [struct(Todos.Tasks.PlanCard, new_card)]

    case Ash.update(board, %{cards: updated_cards}, action: :update_cards) do
      {:ok, updated_board} ->
        todos_map = load_todos_for_board(updated_board)
        available_todos = load_available_todos(updated_board)

        {:noreply,
         socket
         |> assign(:board, updated_board)
         |> assign(:todos_map, todos_map)
         |> assign(:available_todos, available_todos)
         |> assign(:filtered_todos, available_todos)
         |> assign(:todo_search, "")
         |> assign(:show_todo_picker, false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not add card")}
    end
  end

  def handle_event("remove-card", %{"id" => card_id}, socket) do
    board = socket.assigns.board

    updated_cards = Enum.reject(board.cards, &(&1.id == card_id))

    # Also remove any connections involving this card
    updated_connections =
      Enum.reject(board.connections, fn conn ->
        conn.from_card_id == card_id || conn.to_card_id == card_id
      end)

    case Ash.update(board, %{cards: updated_cards, connections: updated_connections},
           action: :update
         ) do
      {:ok, updated_board} ->
        available_todos = load_available_todos(updated_board)

        {:noreply,
         socket
         |> assign(:board, updated_board)
         |> assign(:available_todos, available_todos)
         |> assign(:filtered_todos, available_todos)
         |> assign(:todo_search, "")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not remove card")}
    end
  end

  def handle_event("move-card", %{"id" => card_id, "x" => x, "y" => y}, socket) do
    board = socket.assigns.board

    updated_cards =
      Enum.map(board.cards, fn card ->
        if card.id == card_id do
          %{card | x: x, y: y}
        else
          card
        end
      end)

    case Ash.update(board, %{cards: updated_cards}, action: :update_cards) do
      {:ok, updated_board} ->
        {:noreply, assign(socket, :board, updated_board)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("save-viewport", %{"x" => x, "y" => y, "zoom" => zoom}, socket) do
    board = socket.assigns.board

    case Ash.update(board, %{viewport_x: x, viewport_y: y, zoom: zoom}, action: :save_viewport) do
      {:ok, updated_board} ->
        {:noreply, assign(socket, :board, updated_board)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("start-connection", %{"card-id" => card_id}, socket) do
    # If we're already in connection mode, treat this as end-connection
    if socket.assigns.connecting_from do
      handle_event("end-connection", %{"card-id" => card_id}, socket)
    else
      {:noreply, assign(socket, :connecting_from, card_id)}
    end
  end

  def handle_event("end-connection", %{"card-id" => to_card_id}, socket) do
    from_card_id = socket.assigns.connecting_from

    if from_card_id && from_card_id != to_card_id do
      board = socket.assigns.board

      # Check if connection already exists
      exists? =
        Enum.any?(board.connections, fn conn ->
          conn.from_card_id == from_card_id && conn.to_card_id == to_card_id
        end)

      if exists? do
        {:noreply,
         socket
         |> assign(:connecting_from, nil)
         |> put_flash(:error, "Connection already exists")}
      else
        new_connection = %{
          id: Ash.UUID.generate(),
          from_card_id: from_card_id,
          to_card_id: to_card_id,
          label: nil
        }

        updated_connections =
          board.connections ++ [struct(Todos.Tasks.PlanConnection, new_connection)]

        case Ash.update(board, %{connections: updated_connections}, action: :update_connections) do
          {:ok, updated_board} ->
            {:noreply,
             socket
             |> assign(:board, updated_board)
             |> assign(:connecting_from, nil)}

          {:error, _} ->
            {:noreply,
             socket
             |> assign(:connecting_from, nil)
             |> put_flash(:error, "Could not create connection")}
        end
      end
    else
      {:noreply, assign(socket, :connecting_from, nil)}
    end
  end

  def handle_event("cancel-connection", _params, socket) do
    {:noreply, assign(socket, :connecting_from, nil)}
  end

  def handle_event("delete-connection", %{"id" => connection_id}, socket) do
    board = socket.assigns.board

    updated_connections = Enum.reject(board.connections, &(&1.id == connection_id))

    case Ash.update(board, %{connections: updated_connections}, action: :update_connections) do
      {:ok, updated_board} ->
        {:noreply, assign(socket, :board, updated_board)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete connection")}
    end
  end

  # Helper functions

  defp load_board(id) do
    case Ash.get(Todos.Tasks.PlanBoard, id) do
      {:ok, board} -> board
      _ -> nil
    end
  end

  defp load_user_boards(nil), do: []

  defp load_user_boards(user) do
    Todos.Tasks.PlanBoard
    |> Ash.Query.for_read(:list_for_user, %{user_id: user.id})
    |> Ash.read!()
  end

  defp create_default_board(nil), do: {:error, :no_user}

  defp create_default_board(user) do
    Ash.create(Todos.Tasks.PlanBoard, %{name: "My Plan", user_id: user.id})
  end

  defp load_todos_for_board(nil), do: %{}

  defp load_todos_for_board(board) do
    todo_ids = Enum.map(board.cards, & &1.todo_id)

    if todo_ids == [] do
      %{}
    else
      Todos.Tasks.Todo
      |> Ash.Query.filter(id in ^todo_ids)
      |> Ash.read!()
      |> Map.new(&{&1.id, &1})
    end
  end

  defp load_available_todos(nil), do: []

  defp load_available_todos(board) do
    existing_todo_ids = Enum.map(board.cards, & &1.todo_id)

    Todos.Tasks.Todo
    |> Ash.Query.filter(state not in [:done, :cancelled])
    |> Ash.Query.load([:tags])
    |> Ash.read!()
    |> Enum.reject(&(&1.id in existing_todo_ids))
  end

  defp state_label(:inbox), do: "INBOX"
  defp state_label(:pending), do: "PENDING"
  defp state_label(:in_progress), do: "IN_PROGRESS"
  defp state_label(:waiting), do: "WAITING"
  defp state_label(:done), do: "DONE"
  defp state_label(:cancelled), do: "CANCELLED"

  # Generate an IBM-style orthogonal path between two cards (right-angle connectors)
  defp bezier_path(from_card, to_card) do
    # Start from right edge of from_card
    x1 = from_card.x + from_card.width
    y1 = from_card.y + from_card.height / 2

    # End at left edge of to_card
    x2 = to_card.x
    y2 = to_card.y + to_card.height / 2

    # Midpoint for the vertical segment
    mid_x = (x1 + x2) / 2

    # IBM-style: horizontal out -> vertical -> horizontal in
    "M #{x1} #{y1} L #{mid_x} #{y1} L #{mid_x} #{y2} L #{x2} #{y2}"
  end
end
