defmodule TodosWeb.InboxLive do
  use TodosWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    todos = load_inbox_todos()

    {:ok,
     socket
     |> assign(:page_title, "Inbox")
     |> assign(:todos_empty?, todos == [])
     |> assign(:courses_todo, TodosWeb.CoursesHelper.find_courses_todo())
     |> stream(:todos, todos)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} active_tab={:inbox} courses_todo={@courses_todo}>
      <%!-- Header --%>
      <div class="flex items-center justify-between mb-4">
        <span class="font-mono text-xs uppercase tracking-wider">Inbox</span>
        <span class="font-mono text-xs text-base-content/50">Quick captured todos</span>
      </div>

      <%!-- Empty state --%>
      <div :if={@todos_empty?} class="text-center py-12 font-mono">
        <div class="text-4xl mb-2">📥</div>
        <p class="text-sm uppercase tracking-wider text-base-content/50">Inbox is empty</p>
        <p class="text-xs text-base-content/30 mt-1">Press + to quickly capture a todo</p>
      </div>

      <%!-- Inbox todos panel --%>
      <div :if={!@todos_empty?} class="border-2 border-black bg-base-200">
        <div class="bg-black text-white px-3 py-1.5 font-mono text-xs uppercase tracking-wider">
          Needs Organizing
        </div>
        <div id="inbox-todos" phx-update="stream" class="divide-y-2 divide-black">
          <div
            :for={{id, todo} <- @streams.todos}
            id={id}
            class="bg-base-100 cursor-pointer hover:bg-base-300 transition-all"
            phx-click="organize"
            phx-value-id={todo.id}
          >
            <%!-- Terminal-style header bar --%>
            <div class="bg-black text-white px-3 py-1.5 flex items-center justify-between font-mono text-xs">
              <span class="uppercase tracking-wider">
                TODO/{String.slice(todo.id, 0, 8)}
              </span>
              <div class="flex items-center gap-3">
                <span class="uppercase text-white/70">[INBOX]</span>
                <button
                  type="button"
                  class="hover:text-success transition-colors"
                  phx-click="quick-complete"
                  phx-value-id={todo.id}
                >
                  [DONE]
                </button>
                <span class="text-white/50">→</span>
              </div>
            </div>

            <%!-- Content --%>
            <div class="px-4 pb-4 pt-6">
              <h3 class="font-sans font-bold text-lg mb-1">
                {todo.title}
              </h3>
              <p :if={todo.description} class="font-sans text-sm text-base-content/70 line-clamp-2">
                {todo.description}
              </p>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("organize", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/todos/#{id}")}
  end

  def handle_event("quick-complete", %{"id" => id}, socket) do
    todo = Ash.get!(Todos.Tasks.Todo, id)

    case Ash.update(todo, %{}, action: :complete, actor: socket.assigns.current_user) do
      {:ok, _} ->
        todos_empty? = load_inbox_todos() == []

        {:noreply,
         socket
         |> stream_delete(:todos, todo)
         |> assign(:todos_empty?, todos_empty?)
         |> put_flash(:info, "Todo completed!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not complete todo")}
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

  defp load_inbox_todos do
    Todos.Tasks.Todo
    |> Ash.Query.for_read(:inbox)
    |> Ash.read!()
  end
end
