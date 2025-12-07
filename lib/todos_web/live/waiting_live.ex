defmodule TodosWeb.WaitingLive do
  use TodosWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    todos = load_waiting_todos()

    {:ok,
     socket
     |> assign(:page_title, "Waiting")
     |> assign(:todos_empty?, todos == [])
     |> assign(:courses_todo, TodosWeb.CoursesHelper.find_courses_todo())
     |> stream(:todos, todos)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} active_tab={:waiting} courses_todo={@courses_todo}>
      <%!-- Header --%>
      <div class="flex items-center justify-between mb-4">
        <span class="font-mono text-xs uppercase tracking-wider">Waiting</span>
        <span class="font-mono text-xs text-base-content/50">Blocked on someone/something</span>
      </div>

      <%!-- Empty state --%>
      <div :if={@todos_empty?} class="text-center py-12 font-mono">
        <div class="text-4xl mb-2">⏳</div>
        <p class="text-sm uppercase tracking-wider text-base-content/50">Nothing waiting</p>
        <p class="text-xs text-base-content/30 mt-1">When you're blocked, mark todos as waiting</p>
      </div>

      <%!-- Waiting todos panel --%>
      <div :if={!@todos_empty?} class="border-2 border-black bg-base-200">
        <div class="bg-warning text-warning-content px-3 py-1.5 font-mono text-xs uppercase tracking-wider">
          Blocked Items
        </div>
        <div id="waiting-todos" phx-update="stream" class="divide-y-2 divide-black">
          <div
            :for={{id, todo} <- @streams.todos}
            id={id}
            class="bg-warning/10 cursor-pointer hover:bg-warning/20 transition-all"
            phx-click={JS.navigate(~p"/todos/#{todo.id}")}
          >
            <%!-- Terminal-style header bar --%>
            <div class="bg-black text-white px-3 py-1.5 flex items-center justify-between font-mono text-xs">
              <span class="uppercase tracking-wider">
                TODO/{String.slice(todo.id, 0, 8)}
              </span>
              <div class="flex items-center gap-3">
                <span class="uppercase text-warning">[WAITING]</span>
                <button
                  type="button"
                  class="hover:text-success transition-colors"
                  phx-click="resume"
                  phx-value-id={todo.id}
                >
                  [RESUME]
                </button>
              </div>
            </div>

            <%!-- Content --%>
            <div class="px-4 pb-4 pt-6">
              <h3 class="font-sans font-bold text-lg mb-2">
                {todo.title}
              </h3>
              <div class="font-mono text-xs">
                <span class="text-base-content/50 uppercase">Waiting on:</span>
                <span :if={todo.waiting_on} class="ml-1 text-warning font-bold">
                  {todo.waiting_on}
                </span>
                <span :if={!todo.waiting_on} class="ml-1 text-base-content/30">
                  Not specified
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("resume", %{"id" => id}, socket) do
    todo = Ash.get!(Todos.Tasks.Todo, id)

    case Ash.update(todo, %{}, action: :resume, actor: socket.assigns.current_user) do
      {:ok, _} ->
        todos_empty? = load_waiting_todos() == []

        {:noreply,
         socket
         |> stream_delete(:todos, todo)
         |> assign(:todos_empty?, todos_empty?)
         |> put_flash(:info, "Todo resumed!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not resume todo")}
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

  defp load_waiting_todos do
    Todos.Tasks.Todo
    |> Ash.Query.for_read(:waiting)
    |> Ash.read!()
  end
end
