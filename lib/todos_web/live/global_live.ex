defmodule TodosWeb.GlobalLive do
  use TodosWeb, :live_view

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: TodosWeb.TodoPubSub.subscribe()

    user = socket.assigns.current_user
    tags_with_todos = load_tags_with_todos(user)
    untagged_todos = load_untagged_todos()

    {:ok,
     socket
     |> assign(:page_title, "Global")
     |> assign(:tags_with_todos, tags_with_todos)
     |> assign(:untagged_todos, untagged_todos)
     |> assign(:courses_todo, TodosWeb.CoursesHelper.find_courses_todo())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} active_tab={:global} courses_todo={@courses_todo}>
      <%!-- Header --%>
      <div class="flex items-center justify-between mb-4">
        <span class="font-mono text-xs uppercase tracking-wider">Global View</span>
      </div>

      <%!-- Tag sections --%>
      <div class="space-y-6">
        <%= for {tag, todos, stats} <- @tags_with_todos do %>
          <.tag_section tag={tag} todos={todos} stats={stats} />
        <% end %>

        <%!-- Untagged section --%>
        <%= if @untagged_todos != [] do %>
          <div>
            <div class="flex items-center gap-2 mb-2">
              <span class="badge badge-sm border-2 border-black rounded-none font-bold bg-base-200">
                No Tag
              </span>
              <span class="font-mono text-xs text-base-content/50">
                ({length(@untagged_todos)})
              </span>
            </div>
            <.todo_table todos={@untagged_todos} />
          </div>
        <% end %>

        <%!-- Empty state --%>
        <%= if @tags_with_todos == [] and @untagged_todos == [] do %>
          <div class="text-center py-12 text-base-content/50">
            <div class="w-16 h-16 mx-auto mb-4 border-2 border-black bg-base-200 flex items-center justify-center">
              <.icon name="hero-table-cells" class="size-8" />
            </div>
            <p class="text-lg font-black uppercase">No active todos</p>
            <p class="text-sm font-medium">Create a todo to see it here</p>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :tag, :map, required: true
  attr :todos, :list, required: true
  attr :stats, :map, required: true

  defp tag_section(assigns) do
    ~H"""
    <div>
      <div class="flex items-center gap-2 mb-2">
        <.tag_pill name={@tag.name} color={@tag.color} />
        <div class="w-10 h-2 bg-base-300 border border-base-content/20">
          <div
            class="h-full"
            style={"width: #{@stats.percent}%; background-color: #{@tag.color}"}
          />
        </div>
        <span class="font-mono text-xs text-base-content/50">
          ({length(@todos)})
        </span>
      </div>
      <.todo_table todos={@todos} />
    </div>
    """
  end

  attr :todos, :list, required: true

  defp todo_table(assigns) do
    ~H"""
    <div class="border-2 border-black overflow-x-auto">
      <table class="table table-xs w-full">
        <thead>
          <tr class="bg-black text-white font-mono text-[10px] uppercase">
            <th class="py-2">Title</th>
            <th class="py-2 w-14">Who</th>
            <th class="py-2 w-20">State</th>
            <th class="py-2 w-16">Pri</th>
            <th class="py-2 w-20">Due</th>
            <th class="py-2 w-8">Act</th>
            <th class="py-2 w-8"></th>
          </tr>
        </thead>
        <tbody>
          <tr
            :for={todo <- @todos}
            class="hover:bg-base-200 cursor-pointer transition-colors"
            phx-click={JS.navigate(~p"/todos/#{todo.id}")}
          >
            <td class="truncate max-w-[200px] py-2 font-medium font-sans text-sm">{todo.title}</td>
            <td class="py-2">{assignee_initials(todo.assignees)}</td>
            <td class="py-2"><.compact_state state={todo.state} /></td>
            <td class="py-2"><.compact_priority priority={todo.priority} /></td>
            <td class="py-2 font-mono text-xs">{format_date(todo.due_date)}</td>
            <td class="py-2">
              <button
                :if={todo.state in [:inbox, :pending]}
                phx-click="start-todo"
                phx-value-id={todo.id}
                class="font-mono text-[10px] hover:text-primary"
                title="Start"
              >
                [▶]
              </button>
              <button
                :if={todo.state == :in_progress}
                phx-click="complete-todo"
                phx-value-id={todo.id}
                class="font-mono text-[10px] hover:text-success"
                title="Complete"
              >
                [✓]
              </button>
            </td>
            <td class="py-2">
              <button
                :if={todo.previous_state != nil}
                phx-click="undo-todo"
                phx-value-id={todo.id}
                class="font-mono text-[10px] hover:text-warning"
                title="Undo"
              >
                [↩]
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :state, :atom, required: true

  defp compact_state(assigns) do
    ~H"""
    <span class={[
      "font-mono text-[10px] uppercase font-bold",
      @state == :inbox && "text-base-content/50",
      @state == :pending && "text-primary",
      @state == :in_progress && "text-primary",
      @state == :waiting && "text-warning",
      @state == :done && "text-success"
    ]}>
      {state_abbrev(@state)}
    </span>
    """
  end

  attr :priority, :atom, required: true

  defp compact_priority(assigns) do
    ~H"""
    <span class={[
      "font-mono text-[10px] uppercase font-bold",
      @priority == :urgent && "text-error",
      @priority == :high && "text-warning",
      @priority == :medium && "text-info",
      @priority == :low && "text-base-content/50"
    ]}>
      {priority_abbrev(@priority)}
    </span>
    """
  end

  defp state_abbrev(:inbox), do: "INB"
  defp state_abbrev(:pending), do: "PND"
  defp state_abbrev(:in_progress), do: "WIP"
  defp state_abbrev(:waiting), do: "WAI"
  defp state_abbrev(:done), do: "DON"
  defp state_abbrev(_), do: "—"

  defp priority_abbrev(:urgent), do: "URG"
  defp priority_abbrev(:high), do: "HI"
  defp priority_abbrev(:medium), do: "MED"
  defp priority_abbrev(:low), do: "LO"
  defp priority_abbrev(_), do: "—"

  defp format_date(nil), do: "—"
  defp format_date(date), do: Calendar.strftime(date, "%m/%d")

  defp assignee_initials([]), do: "—"

  defp assignee_initials(assignees) do
    assignees
    |> Enum.map(fn user ->
      name = user.tailscale_name || user.email || ""
      name |> String.split() |> List.first() |> String.first() || "?"
    end)
    |> Enum.join("")
  end

  defp load_tags_with_todos(user) do
    tags = Ash.read!(Todos.Tasks.Tag, action: :list_all)

    # Get user's tag order preferences
    user_orders =
      Todos.Tasks.UserTagOrder
      |> Ash.Query.for_read(:for_user, %{user_id: user.id})
      |> Ash.read!()
      |> Map.new(&{&1.tag_id, &1.position})

    # Sort tags: ordered first (by position), then unordered (alphabetically)
    sorted_tags =
      Enum.sort_by(tags, fn tag ->
        case Map.get(user_orders, tag.id) do
          nil -> {1, tag.name}
          pos -> {0, pos}
        end
      end)

    # Load active todos (not done/cancelled)
    active_todos =
      Todos.Tasks.Todo
      |> Ash.Query.filter(state not in [:done, :cancelled])
      |> Ash.Query.load([:tags, :user, :assignees])
      |> Ash.read!()

    # Load done todos (for completion percentage)
    done_todos =
      Todos.Tasks.Todo
      |> Ash.Query.filter(state == :done)
      |> Ash.Query.load([:tags])
      |> Ash.read!()

    Enum.map(sorted_tags, fn tag ->
      active =
        active_todos
        |> Enum.filter(fn todo ->
          Enum.any?(todo.tags, &(&1.id == tag.id))
        end)
        |> sort_todos()
        |> Enum.take(5)

      done_count =
        done_todos
        |> Enum.count(fn todo ->
          Enum.any?(todo.tags, &(&1.id == tag.id))
        end)

      total_count = length(active) + done_count
      completion_percent = if total_count > 0, do: round(done_count / total_count * 100), else: 0

      {tag, active, %{done_count: done_count, total_count: total_count, percent: completion_percent}}
    end)
    |> Enum.reject(fn {_tag, todos, _stats} -> todos == [] end)
  end

  defp load_untagged_todos do
    Todos.Tasks.Todo
    |> Ash.Query.filter(state not in [:done, :cancelled])
    |> Ash.Query.load([:tags, :user, :assignees])
    |> Ash.read!()
    |> Enum.filter(fn todo -> todo.tags == [] end)
    |> sort_todos()
    |> Enum.take(5)
  end

  defp sort_todos(todos) do
    Enum.sort_by(todos, fn todo ->
      {assignee_sort_key(todo.assignees), state_sort_key(todo.state), priority_sort_key(todo.priority)}
    end)
  end

  defp assignee_sort_key([]), do: "zzz"

  defp assignee_sort_key(assignees) do
    assignees
    |> List.first()
    |> then(fn user -> user.tailscale_name || user.email || "zzz" end)
    |> String.downcase()
  end

  defp state_sort_key(:in_progress), do: 0
  defp state_sort_key(:pending), do: 1
  defp state_sort_key(:inbox), do: 2
  defp state_sort_key(:waiting), do: 3
  defp state_sort_key(_), do: 4

  defp priority_sort_key(:urgent), do: 0
  defp priority_sort_key(:high), do: 1
  defp priority_sort_key(:medium), do: 2
  defp priority_sort_key(:low), do: 3
  defp priority_sort_key(_), do: 4

  @impl true
  def handle_info(:todos_changed, socket) do
    user = socket.assigns.current_user
    tags_with_todos = load_tags_with_todos(user)
    untagged_todos = load_untagged_todos()

    {:noreply,
     socket
     |> assign(:tags_with_todos, tags_with_todos)
     |> assign(:untagged_todos, untagged_todos)}
  end

  @impl true
  def handle_event("start-todo", %{"id" => id}, socket) do
    todo = Ash.get!(Todos.Tasks.Todo, id)
    user = socket.assigns.current_user

    case Ash.update(todo, %{}, action: :start) do
      {:ok, _updated} ->
        # Reload data to reflect the change
        tags_with_todos = load_tags_with_todos(user)
        untagged_todos = load_untagged_todos()

        {:noreply,
         socket
         |> assign(:tags_with_todos, tags_with_todos)
         |> assign(:untagged_todos, untagged_todos)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not start todo")}
    end
  end

  def handle_event("complete-todo", %{"id" => id}, socket) do
    todo = Ash.get!(Todos.Tasks.Todo, id)
    user = socket.assigns.current_user

    case Ash.update(todo, %{}, action: :complete, actor: user) do
      {:ok, _updated} ->
        # Reload data to reflect the change
        tags_with_todos = load_tags_with_todos(user)
        untagged_todos = load_untagged_todos()

        {:noreply,
         socket
         |> assign(:tags_with_todos, tags_with_todos)
         |> assign(:untagged_todos, untagged_todos)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not complete todo")}
    end
  end

  def handle_event("undo-todo", %{"id" => id}, socket) do
    todo = Ash.get!(Todos.Tasks.Todo, id)
    user = socket.assigns.current_user

    case Ash.update(todo, %{}, action: :undo) do
      {:ok, _updated} ->
        # Reload data to reflect the change
        tags_with_todos = load_tags_with_todos(user)
        untagged_todos = load_untagged_todos()

        {:noreply,
         socket
         |> assign(:tags_with_todos, tags_with_todos)
         |> assign(:untagged_todos, untagged_todos)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not undo")}
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
end
