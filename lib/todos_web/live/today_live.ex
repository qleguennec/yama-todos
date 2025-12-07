defmodule TodosWeb.TodayLive do
  use TodosWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    todos = load_today_todos()

    {:ok,
     socket
     |> assign(:page_title, "Today")
     |> assign(:todos_empty?, todos == [])
     |> assign(:courses_todo, TodosWeb.CoursesHelper.find_courses_todo())
     |> stream(:todos, todos)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} active_tab={:today} courses_todo={@courses_todo}>
      <%!-- Header --%>
      <div class="flex items-center justify-between mb-4">
        <span class="font-mono text-xs uppercase tracking-wider">Today</span>
        <span class="font-mono text-xs text-base-content/50">{format_date(Date.utc_today())}</span>
      </div>

      <%!-- Empty state --%>
      <div :if={@todos_empty?} class="text-center py-12 font-mono">
        <div class="text-4xl mb-2">☀</div>
        <p class="text-sm uppercase tracking-wider text-base-content/50">Nothing for today</p>
        <p class="text-xs text-base-content/30 mt-1">Add todos with due dates or pin them to today</p>
      </div>

      <%!-- Today todos panel --%>
      <div :if={!@todos_empty?} class="border-2 border-black bg-base-200">
        <div class="bg-black text-white px-3 py-1.5 font-mono text-xs uppercase tracking-wider">
          Due Today
        </div>
        <div id="today-todos" phx-update="stream" class="divide-y-2 divide-black">
          <div
            :for={{id, todo} <- @streams.todos}
            id={id}
            class={[
              "cursor-pointer hover:bg-base-300 transition-all",
              if(todo.overdue?, do: "bg-error/10", else: "bg-base-100")
            ]}
            phx-click={JS.navigate(~p"/todos/#{todo.id}")}
          >
            <%!-- Terminal-style header bar --%>
            <div class={[
              "px-3 py-1.5 flex items-center justify-between font-mono text-xs",
              if(todo.overdue?, do: "bg-error text-error-content", else: "bg-black text-white")
            ]}>
              <span class="uppercase tracking-wider">
                TODO/{String.slice(todo.id, 0, 8)}
              </span>
              <div class="flex items-center gap-3">
                <span :if={todo.overdue?} class="uppercase font-bold">
                  [OVERDUE]
                </span>
                <span class={[
                  "uppercase",
                  todo.state == :done && "text-success",
                  todo.state == :in_progress && "text-primary",
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

            <%!-- Content --%>
            <div class="px-4 pb-4 pt-6">
              <h3 class={[
                "font-sans font-bold text-lg mb-3",
                todo.state == :done && "line-through opacity-50"
              ]}>
                {todo.title}
              </h3>

              <div class="font-mono text-xs grid grid-cols-2 gap-x-4 gap-y-1 text-base-content/80">
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
                    todo.overdue? && "text-error font-bold"
                  ]}>
                    {todo.due_date && Calendar.strftime(todo.due_date, "%Y-%m-%d") || "—"}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("toggle-state", %{"id" => id}, socket) do
    todo = Ash.get!(Todos.Tasks.Todo, id)

    action =
      case todo.state do
        :pending -> :start
        :in_progress -> :complete
        :done -> :reopen
        _ -> :start
      end

    case Ash.update(todo, %{}, action: action, actor: socket.assigns.current_user) do
      {:ok, updated} ->
        {:noreply, stream_insert(socket, :todos, Ash.load!(updated, [:overdue?, :user, :completed_by]))}

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

  defp load_today_todos do
    Todos.Tasks.Todo
    |> Ash.Query.for_read(:today)
    |> Ash.Query.load([:overdue?])
    |> Ash.read!()
  end

  defp format_date(date) do
    Calendar.strftime(date, "%A, %B %d")
  end

  defp state_label(:inbox), do: "INBOX"
  defp state_label(:pending), do: "PENDING"
  defp state_label(:in_progress), do: "IN_PROGRESS"
  defp state_label(:waiting), do: "WAITING"
  defp state_label(:done), do: "DONE"
  defp state_label(:cancelled), do: "CANCELLED"
end
