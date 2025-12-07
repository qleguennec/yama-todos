defmodule TodosWeb.TodosLive do
  use TodosWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    todos = load_todos_by_filter(:active, socket.assigns.current_user)

    {:ok,
     socket
     |> assign(:page_title, "All Todos")
     |> assign(:filter, :active)
     |> assign(:todos_empty?, todos == [])
     |> assign(:courses_todo, TodosWeb.CoursesHelper.find_courses_todo())
     |> stream(:todos, todos)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} active_tab={:todos} courses_todo={@courses_todo}>
      <%!-- Header --%>
      <div class="flex items-center justify-between mb-4">
        <span class="font-mono text-xs uppercase tracking-wider">All Todos</span>
        <div class="flex font-mono text-xs">
          <button
            class={[
              "px-2 py-1 border-2 border-black transition-all uppercase tracking-wide",
              if(@filter == :active,
                do: "bg-black text-white",
                else: "bg-base-100 hover:bg-base-200"
              )
            ]}
            phx-click="filter"
            phx-value-filter="active"
          >
            Active
          </button>
          <button
            class={[
              "px-2 py-1 border-2 border-l-0 border-black transition-all uppercase tracking-wide",
              if(@filter == :done, do: "bg-black text-white", else: "bg-base-100 hover:bg-base-200")
            ]}
            phx-click="filter"
            phx-value-filter="done"
          >
            Done
          </button>
          <button
            class={[
              "px-2 py-1 border-2 border-l-0 border-black transition-all uppercase tracking-wide",
              if(@filter == :all, do: "bg-black text-white", else: "bg-base-100 hover:bg-base-200")
            ]}
            phx-click="filter"
            phx-value-filter="all"
          >
            All
          </button>
        </div>
      </div>

      <div id="all-todos" phx-update="stream" class="space-y-3">
        <div id="todos-empty" class="hidden only:block text-center py-12 text-base-content/50">
          <div class="w-16 h-16 mx-auto mb-4 border-2 border-black bg-base-200 flex items-center justify-center">
            <.icon name="hero-clipboard-document-list" class="size-8" />
          </div>
          <p class="text-lg font-black uppercase">No todos yet</p>
          <p class="text-sm font-medium">Press + to create your first todo</p>
        </div>

        <div
          :for={{id, todo} <- @streams.todos}
          id={id}
          class="bg-base-200 border-2 border-black shadow-[4px_4px_0_0_black] cursor-pointer hover:shadow-none hover:translate-x-1 hover:translate-y-1 transition-all"
          phx-click={JS.navigate(~p"/todos/#{todo.id}")}
        >
          <%!-- Terminal-style header bar --%>
          <div class="bg-black text-white px-3 py-1.5 flex items-center justify-between font-mono text-xs">
            <span class="uppercase tracking-wider">
              TODO/{String.slice(todo.id, 0, 8)}
            </span>
            <div class="flex items-center gap-3">
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
                class="hover:text-primary transition-colors"
                phx-click="toggle-state"
                phx-value-id={todo.id}
              >
                <%= if todo.state == :done do %>
                  [REOPEN]
                <% else %>
                  [RUN]
                <% end %>
              </button>
            </div>
          </div>

          <%!-- Main content --%>
          <div class="px-4 pb-4 pt-6">
            <h3 class={[
              "font-sans font-bold text-lg mb-3",
              todo.state == :done && "line-through opacity-50"
            ]}>
              {todo.title}
            </h3>

            <%!-- Metadata grid --%>
            <div class="font-mono text-xs grid grid-cols-2 gap-x-4 gap-y-1 text-base-content/80">
              <div class="flex items-center gap-1">
                <span class="text-base-content/50 uppercase">Assigned:</span>
                <%= if todo.assignees == [] do %>
                  <span class="ml-1">—</span>
                <% else %>
                  <%= for assignee <- todo.assignees do %>
                    <span class={[
                      "ml-1 w-5 h-5 flex items-center justify-center border border-current font-bold text-[10px]",
                      assignee_color(assignee)
                    ]}>
                      {String.first(first_name(assignee))}
                    </span>
                  <% end %>
                <% end %>
              </div>
              <div>
                <span class="text-base-content/50 uppercase">Priority:</span>
                <span class={[
                  "ml-1 uppercase",
                  todo.priority == :urgent && "text-error font-bold",
                  todo.priority == :high && "text-warning",
                  todo.priority == :medium && "text-info",
                  todo.priority == :low && "text-base-content/50"
                ]}>
                  {todo.priority || "—"}
                </span>
              </div>
              <div>
                <span class="text-base-content/50 uppercase">Due:</span>
                <span class={[
                  "ml-1",
                  todo.due_date && Date.compare(todo.due_date, Date.utc_today()) == :lt && "text-error font-bold"
                ]}>
                  {todo.due_date && Calendar.strftime(todo.due_date, "%Y-%m-%d") || "—"}
                </span>
              </div>
              <div>
                <span class="text-base-content/50 uppercase">Creator:</span>
                <span class="ml-1">{todo.user && first_name(todo.user) || "—"}</span>
              </div>
            </div>

            <%!-- Tags row --%>
            <div :if={todo.tags != []} class="mt-3 pt-3 border-t border-black/20">
              <div class="flex items-center gap-2 flex-wrap">
                <span class="font-mono text-xs text-base-content/50 uppercase">Tags:</span>
                <%= for tag <- todo.tags || [] do %>
                  <.tag_pill name={tag.name} color={tag.color} />
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    filter = String.to_existing_atom(filter)
    todos = load_todos_by_filter(filter, socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign(:todos_empty?, todos == [])
     |> stream(:todos, todos, reset: true)}
  end

  def handle_event("toggle-state", %{"id" => id}, socket) do
    todo = Ash.get!(Todos.Tasks.Todo, id, load: [:tags, :user, :assignees])

    action =
      case todo.state do
        :pending -> :start
        :in_progress -> :complete
        :done -> :reopen
        :inbox -> :start
        _ -> :start
      end

    case Ash.update(todo, %{}, action: action, actor: socket.assigns.current_user) do
      {:ok, updated} ->
        updated = Ash.load!(updated, [:tags, :user, :assignees])

        socket =
          if should_show?(updated, socket.assigns.filter) do
            stream_insert(socket, :todos, updated)
          else
            stream_delete(socket, :todos, updated)
          end

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update todo")}
    end
  end

  def handle_event("add-courses-subtask", %{"title" => title}, socket) do
    case socket.assigns.courses_todo do
      nil ->
        {:noreply, put_flash(socket, :error, "No courses todo found")}

      todo ->
        case Ash.update(todo, %{subtask_title: title}, action: :add_subtask) do
          {:ok, updated_todo} ->
            {:noreply,
             socket
             |> put_flash(:info, "Added: #{title}")
             |> push_navigate(to: ~p"/todos/#{updated_todo.id}")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not add to courses")}
        end
    end
  end

  defp load_todos_by_filter(:active, current_user) do
    Todos.Tasks.Todo
    |> Ash.Query.filter(state not in [:done, :cancelled])
    |> Ash.Query.load([:tags, :user, :assignees])
    |> Ash.read!()
    |> sort_todos(current_user)
  end

  defp load_todos_by_filter(:done, current_user) do
    Todos.Tasks.Todo
    |> Ash.Query.filter(state == :done)
    |> Ash.Query.load([:tags, :user, :assignees])
    |> Ash.read!()
    |> sort_todos(current_user)
  end

  defp load_todos_by_filter(:all, current_user) do
    Todos.Tasks.Todo
    |> Ash.Query.filter(state != :cancelled)
    |> Ash.Query.load([:tags, :user, :assignees])
    |> Ash.read!()
    |> sort_todos(current_user)
  end

  defp sort_todos(todos, nil), do: todos

  defp sort_todos(todos, current_user) do
    Enum.sort_by(todos, fn todo ->
      assigned_to_me? = Enum.any?(todo.assignees || [], &(&1.id == current_user.id))
      priority_order = priority_to_int(todo.priority)

      # Tuple sorting: assigned_to_me first (0 before 1), then priority (lower int = higher priority), then date asc
      {if(assigned_to_me?, do: 0, else: 1), priority_order, todo.inserted_at}
    end)
  end

  defp priority_to_int(:urgent), do: 0
  defp priority_to_int(:high), do: 1
  defp priority_to_int(:medium), do: 2
  defp priority_to_int(:low), do: 3
  defp priority_to_int(_), do: 4

  defp should_show?(todo, :active), do: todo.state not in [:done, :cancelled]
  defp should_show?(todo, :done), do: todo.state == :done
  defp should_show?(todo, :all), do: todo.state != :cancelled

  defp state_label(:inbox), do: "INBOX"
  defp state_label(:pending), do: "PENDING"
  defp state_label(:in_progress), do: "IN_PROGRESS"
  defp state_label(:waiting), do: "WAITING"
  defp state_label(:done), do: "DONE"
  defp state_label(:cancelled), do: "CANCELLED"

  defp first_name(user) do
    name = user.tailscale_name || user.email || ""
    name |> String.split() |> List.first() || name
  end

  defp assignee_color(user) do
    case String.downcase(first_name(user)) do
      "quentin" -> "text-info"
      "victoria" -> "text-secondary"
      _ -> "text-base-content"
    end
  end
end
