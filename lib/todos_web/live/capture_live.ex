defmodule TodosWeb.CaptureLive do
  use TodosWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    form =
      Todos.Tasks.Todo
      |> AshPhoenix.Form.for_create(:capture, domain: Todos.Tasks, as: "todo")
      |> to_form()

    {:ok,
     socket
     |> assign(:page_title, "Quick Capture")
     |> assign(:form, form)
     |> assign(:title, "")
     |> assign(:save_timer, nil)
     |> assign(:courses_todo, TodosWeb.CoursesHelper.find_courses_todo())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} active_tab={nil} courses_todo={@courses_todo}>
      <%!-- Header --%>
      <div class="flex items-center gap-3 mb-6">
        <.link
          navigate={~p"/"}
          class="w-10 h-10 border-2 border-black bg-base-100 flex items-center justify-center hover:bg-base-200 transition-all"
        >
          <.icon name="hero-x-mark" class="size-5" />
        </.link>
        <span class="font-mono text-xs uppercase tracking-wider">Quick Capture</span>
      </div>

      <%!-- Capture form panel --%>
      <div class="border-2 border-black bg-base-200">
        <div class="bg-black text-white px-3 py-1.5 font-mono text-xs uppercase tracking-wider">
          New Entry
        </div>
        <.form for={@form} phx-change="change" id="capture-form" class="p-4 space-y-4">
          <div>
            <label class="font-mono text-xs text-base-content/50 uppercase block mb-1">Title</label>
            <input
              type="text"
              name="todo[title]"
              value={Phoenix.HTML.Form.input_value(@form, :title)}
              placeholder="What's on your mind?"
              class="w-full px-3 py-2 border-2 border-black bg-base-100 font-mono text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              autofocus
            />
          </div>

          <p class="font-mono text-xs text-base-content/50 text-center">
            Auto-saves after you stop typing
          </p>
        </.form>
      </div>

      <%!-- Divider --%>
      <div class="flex items-center gap-4 my-6">
        <div class="flex-1 border-t-2 border-black"></div>
        <span class="font-mono text-xs uppercase tracking-wider text-base-content/50">
          or create with details
        </span>
        <div class="flex-1 border-t-2 border-black"></div>
      </div>

      <%!-- Full todo link --%>
      <.link
        navigate={if @title != "", do: ~p"/todos/new?title=#{@title}", else: ~p"/todos/new"}
        class="block w-full font-mono text-xs px-3 py-2 border-2 border-black bg-base-100 text-center uppercase tracking-wide hover:bg-base-200 transition-all"
      >
        [CREATE FULL TODO]
      </.link>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("change", %{"todo" => %{"title" => title}}, socket) do
    # Cancel any pending save
    if socket.assigns.save_timer, do: Process.cancel_timer(socket.assigns.save_timer)

    # Schedule auto-save if title is not empty
    timer =
      if String.trim(title) != "" do
        Process.send_after(self(), {:auto_save, title}, 500)
      end

    {:noreply,
     socket
     |> assign(:title, title)
     |> assign(:save_timer, timer)}
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

  @impl true
  def handle_info({:auto_save, title}, socket) do
    user_id =
      if socket.assigns.current_user do
        socket.assigns.current_user.id
      else
        nil
      end

    params = %{"title" => title, "user_id" => user_id}

    socket = push_event(socket, "saving", %{})

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, todo} ->
        {:noreply,
         socket
         |> push_event("saved", %{})
         |> push_navigate(to: ~p"/todos/#{todo.id}")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, to_form(form))
         |> push_event("save-error", %{})}
    end
  end
end
