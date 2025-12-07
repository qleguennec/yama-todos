defmodule TodosWeb.TagsLive do
  use TodosWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    tags = load_tags_for_user(user)

    {:ok,
     socket
     |> assign(:page_title, "Tags")
     |> assign(:tags_empty?, tags == [])
     |> assign(:editing_tag, nil)
     |> assign(:form, nil)
     |> assign(:save_timer, nil)
     |> assign(:courses_todo, TodosWeb.CoursesHelper.find_courses_todo())
     |> stream(:tags, tags)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} active_tab={:tags} courses_todo={@courses_todo}>
      <%!-- Header --%>
      <div class="flex items-center justify-between mb-4">
        <span class="font-mono text-xs uppercase tracking-wider">Tags</span>
        <button
          type="button"
          phx-click="new-tag"
          class="font-mono text-xs px-2 py-1 border-2 border-black bg-black text-white hover:bg-base-content transition-all"
        >
          [+NEW]
        </button>
      </div>

      <%!-- Create/Edit form panel --%>
      <%= if @form do %>
        <div class="border-2 border-black bg-base-200 mb-4">
          <div class="bg-black text-white px-3 py-1.5 font-mono text-xs uppercase tracking-wider">
            {if @editing_tag, do: "Edit Tag", else: "Create Tag"}
          </div>
          <.form for={@form} phx-change="validate-tag" id="tag-form" class="p-4 space-y-4">
            <div>
              <label class="font-mono text-xs text-base-content/50 uppercase block mb-1">Name</label>
              <input
                type="text"
                name="tag[name]"
                value={Phoenix.HTML.Form.input_value(@form, :name)}
                placeholder="Tag name"
                class="w-full px-3 py-2 border-2 border-black bg-base-100 font-mono text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                autofocus
              />
            </div>

            <div>
              <label class="font-mono text-xs text-base-content/50 uppercase block mb-2">Color</label>
              <div class="flex gap-2 flex-wrap">
                <%= for color <- tag_colors() do %>
                  <label class="cursor-pointer">
                    <input
                      type="radio"
                      name="tag[color]"
                      value={color}
                      checked={Phoenix.HTML.Form.input_value(@form, :color) == color}
                      class="hidden peer"
                    />
                    <div
                      class="w-6 h-6 border-2 border-black peer-checked:ring-2 peer-checked:ring-offset-1 peer-checked:ring-black"
                      style={"background-color: #{color}"}
                    />
                  </label>
                <% end %>
              </div>
            </div>

            <div class="flex gap-2">
              <p class="flex-1 font-mono text-xs text-base-content/50 self-center">
                Auto-saves after changes
              </p>
              <button
                type="button"
                phx-click="cancel-edit"
                class="font-mono text-xs px-3 py-2 border-2 border-black bg-base-100 hover:bg-base-300 transition-all uppercase tracking-wide"
              >
                [CLOSE]
              </button>
            </div>
          </.form>
        </div>
      <% end %>

      <%!-- Empty state --%>
      <div :if={@tags_empty?} class="text-center py-12 font-mono">
        <div class="text-4xl mb-2">⌘</div>
        <p class="text-sm uppercase tracking-wider text-base-content/50">No tags defined</p>
        <p class="text-xs text-base-content/30 mt-1">Click [+NEW] to create one</p>
      </div>

      <%!-- Tags list panel --%>
      <div :if={!@tags_empty?} class="border-2 border-black bg-base-200">
        <div class="bg-black text-white px-3 py-1.5 font-mono text-xs uppercase tracking-wider flex items-center justify-between">
          <span>All Tags</span>
          <span class="text-white/50 text-[10px]">Drag to reorder</span>
        </div>
        <div id="tags-list" phx-update="stream" phx-hook="SortableTags" class="divide-y-2 divide-black">
          <div
            :for={{id, tag} <- @streams.tags}
            id={id}
            data-tag-id={tag.id}
            class="flex items-center gap-3 px-3 py-2 bg-base-100 hover:bg-base-200 transition-colors"
          >
            <span data-drag-handle class="cursor-grab text-base-content/30 hover:text-base-content/60">⠿</span>
            <div class="w-3 h-3 border border-black" style={"background-color: #{tag.color}"} />
            <span class="flex-1 font-mono text-sm">{tag.name}</span>
            <button
              type="button"
              phx-click="edit-tag"
              phx-value-id={tag.id}
              class="font-mono text-xs text-base-content/50 hover:text-base-content transition-all"
            >
              [EDIT]
            </button>
            <button
              type="button"
              phx-click="delete-tag"
              phx-value-id={tag.id}
              data-confirm="Are you sure you want to delete this tag?"
              class="font-mono text-xs text-error hover:underline transition-all"
            >
              [DEL]
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("new-tag", _, socket) do
    form =
      Todos.Tasks.Tag
      |> AshPhoenix.Form.for_create(:create, domain: Todos.Tasks, as: "tag")
      |> to_form()

    {:noreply,
     socket
     |> assign(:editing_tag, nil)
     |> assign(:form, form)}
  end

  def handle_event("edit-tag", %{"id" => id}, socket) do
    tag = Ash.get!(Todos.Tasks.Tag, id)

    form =
      tag
      |> AshPhoenix.Form.for_update(:update, domain: Todos.Tasks, as: "tag")
      |> to_form()

    {:noreply,
     socket
     |> assign(:editing_tag, tag)
     |> assign(:form, form)}
  end

  def handle_event("cancel-edit", _, socket) do
    {:noreply,
     socket
     |> assign(:editing_tag, nil)
     |> assign(:form, nil)
     |> assign(:save_timer, nil)}
  end

  def handle_event("validate-tag", %{"tag" => params}, socket) do
    # Cancel any pending save
    if socket.assigns.save_timer, do: Process.cancel_timer(socket.assigns.save_timer)

    form =
      if socket.assigns.editing_tag do
        socket.assigns.editing_tag
        |> AshPhoenix.Form.for_update(:update, domain: Todos.Tasks, as: "tag")
      else
        AshPhoenix.Form.for_create(Todos.Tasks.Tag, :create, domain: Todos.Tasks, as: "tag")
      end
      |> AshPhoenix.Form.validate(params)

    # Schedule auto-save if name is present
    should_save = form.source.valid? and (params["name"] || "") != ""

    timer =
      if should_save do
        Process.send_after(self(), {:auto_save_tag, params}, 500)
      end

    {:noreply,
     socket
     |> assign(:form, to_form(form))
     |> assign(:save_timer, timer)}
  end

  def handle_event("delete-tag", %{"id" => id}, socket) do
    tag = Ash.get!(Todos.Tasks.Tag, id)

    case Ash.destroy(tag) do
      :ok ->
        tags_empty? = load_tags() == []

        {:noreply,
         socket
         |> stream_delete(:tags, tag)
         |> assign(:tags_empty?, tags_empty?)
         |> put_flash(:info, "Tag deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete tag")}
    end
  end

  def handle_event("reorder-tags", %{"tag_ids" => tag_ids}, socket) do
    user = socket.assigns.current_user

    # Bulk upsert tag orders for this user
    tag_ids
    |> Enum.with_index()
    |> Enum.each(fn {tag_id, position} ->
      Ash.create!(
        Todos.Tasks.UserTagOrder,
        %{user_id: user.id, tag_id: tag_id, position: position},
        action: :upsert
      )
    end)

    # Broadcast change so global view updates
    TodosWeb.TodoPubSub.broadcast_change()

    {:noreply, socket}
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
  def handle_info({:auto_save_tag, params}, socket) do
    socket = push_event(socket, "saving", %{})

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, tag} ->
        # If we were editing, close the form. If creating, switch to edit mode.
        {:noreply,
         socket
         |> stream_insert(:tags, tag)
         |> assign(:tags_empty?, false)
         |> assign(:editing_tag, tag)
         |> assign(:form, build_edit_form(tag))
         |> push_event("saved", %{})}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, to_form(form))
         |> push_event("save-error", %{})}
    end
  end

  defp load_tags do
    Todos.Tasks.Tag
    |> Ash.Query.for_read(:list_all)
    |> Ash.read!()
  end

  defp load_tags_for_user(user) do
    tags = load_tags()

    # Get user's tag order preferences
    user_orders =
      Todos.Tasks.UserTagOrder
      |> Ash.Query.for_read(:for_user, %{user_id: user.id})
      |> Ash.read!()
      |> Map.new(&{&1.tag_id, &1.position})

    # Sort: ordered tags first (by position), then unordered (alphabetically)
    Enum.sort_by(tags, fn tag ->
      case Map.get(user_orders, tag.id) do
        nil -> {1, tag.name}
        pos -> {0, pos}
      end
    end)
  end

  defp build_edit_form(tag) do
    tag
    |> AshPhoenix.Form.for_update(:update, domain: Todos.Tasks, as: "tag")
    |> to_form()
  end

  defp tag_colors do
    [
      "#ef4444",  # red
      "#f97316",  # orange
      "#f59e0b",  # amber
      "#eab308",  # yellow
      "#84cc16",  # lime
      "#22c55e",  # green
      "#10b981",  # emerald
      "#14b8a6",  # teal
      "#06b6d4",  # cyan
      "#0ea5e9",  # sky
      "#3b82f6",  # blue
      "#6366f1",  # indigo
      "#8b5cf6",  # violet
      "#a855f7",  # purple
      "#d946ef",  # fuchsia
      "#ec4899",  # pink
      "#f43f5e",  # rose
      "#78716c",  # stone
      "#71717a",  # zinc
      "#64748b"   # slate
    ]
  end
end
