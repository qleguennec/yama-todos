defmodule TodosWeb.TodoLive do
  use TodosWeb, :live_view

  @impl true
  def mount(%{"id" => "new"}, _session, socket) do
    tags = load_all_tags()
    users = load_all_users()
    todo = %Todos.Tasks.Todo{user_id: socket.assigns.current_user.id, tags: [], assignees: []}
    form = build_create_form(socket.assigns.current_user)
    # Default to current user as assignee
    default_assignee_ids = [socket.assigns.current_user.id]

    {:ok,
     socket
     |> assign(:page_title, "New Todo")
     |> assign(:todo, todo)
     |> assign(:editing?, false)
     |> assign(:all_tags, tags)
     |> assign(:all_users, users)
     |> assign(:selected_tag_ids, [])
     |> assign(:selected_assignee_ids, default_assignee_ids)
     |> assign(:form, form)
     |> assign(:show_tag_modal, false)
     |> assign(:tag_form, nil)
     |> assign(:save_timer, nil)
     |> assign(:courses_todo, TodosWeb.CoursesHelper.find_courses_todo())
     |> stream(:subtasks, [])}
  end

  def mount(%{"id" => id}, _session, socket) do
    todo = load_todo(id)
    tags = load_all_tags()
    users = load_all_users()
    form = build_form(todo)
    selected_tag_ids = Enum.map(todo.tags || [], & &1.id)
    selected_assignee_ids = Enum.map(todo.assignees || [], & &1.id)

    {:ok,
     socket
     |> assign(:page_title, todo.title)
     |> assign(:todo, todo)
     |> assign(:editing?, true)
     |> assign(:all_tags, tags)
     |> assign(:all_users, users)
     |> assign(:selected_tag_ids, selected_tag_ids)
     |> assign(:selected_assignee_ids, selected_assignee_ids)
     |> assign(:form, form)
     |> assign(:show_tag_modal, false)
     |> assign(:tag_form, nil)
     |> assign(:save_timer, nil)
     |> assign(:courses_todo, TodosWeb.CoursesHelper.find_courses_todo())
     |> stream(:subtasks, todo.subtasks || [])}
  end

  @impl true
  def handle_params(%{"title" => title}, _uri, socket) when not socket.assigns.editing? do
    form =
      AshPhoenix.Form.for_create(Todos.Tasks.Todo, :create,
        domain: Todos.Tasks,
        as: "todo",
        actor: socket.assigns.current_user
      )
      |> AshPhoenix.Form.validate(%{"title" => title})
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} active_tab={:todos} courses_todo={@courses_todo}>
      <%!-- Terminal-style header bar --%>
      <div class="flex items-center gap-3 mb-4">
        <.link
          navigate={~p"/todos"}
          class="font-mono text-xs px-2 py-1 border-2 border-black bg-base-100 hover:bg-base-200 transition-all"
        >
          [BACK]
        </.link>
        <%= if @editing? do %>
          <div class="font-mono text-xs flex items-center gap-2">
            <span class="text-base-content/50">ID:</span>
            <span>{String.slice(@todo.id, 0, 8)}</span>
            <span class="text-base-content/50 ml-2">STATUS:</span>
            <span class={[
              @todo.state == :done && "text-success",
              @todo.state == :in_progress && "text-primary",
              @todo.state == :waiting && "text-warning"
            ]}>
              {String.upcase(to_string(@todo.state))}
            </span>
          </div>
        <% else %>
          <span class="font-mono text-xs uppercase">New Entry</span>
        <% end %>
      </div>

      <%!-- Main form panel --%>
      <div class="border-2 border-black bg-base-200 mb-4">
        <div class="bg-black text-white px-3 py-1.5 font-mono text-xs uppercase tracking-wider flex items-center justify-between">
          <span>{if @editing?, do: "Edit Todo", else: "Create Todo"}</span>
          <%= if @editing? do %>
            <span class="text-white/50">
              by {display_name(@todo.user)} · {Calendar.strftime(@todo.inserted_at, "%Y-%m-%d")}
            </span>
          <% end %>
        </div>

        <.form for={@form} phx-change="validate" id="todo-form" class="p-4 space-y-4">
          <%!-- Title field --%>
          <div>
            <label class="font-mono text-xs text-base-content/50 uppercase block mb-1">Title</label>
            <input
              type="text"
              name={@form[:title].name}
              value={@form[:title].value}
              placeholder="What needs to be done?"
              class="w-full px-3 py-2 border-2 border-black bg-base-100 font-sans text-sm focus:outline-none focus:ring-2 focus:ring-primary"
            />
            <.field_errors field={@form[:title]} />
          </div>

          <%!-- Description field --%>
          <div>
            <label class="font-mono text-xs text-base-content/50 uppercase block mb-1">Description</label>
            <textarea
              name={@form[:description].name}
              placeholder="Add details..."
              rows={3}
              class="w-full px-3 py-2 border-2 border-black bg-base-100 font-sans text-sm focus:outline-none focus:ring-2 focus:ring-primary"
            >{@form[:description].value}</textarea>
          </div>

          <%!-- Status, Priority and Due Date grid --%>
          <div class={["grid gap-4", @editing? && "grid-cols-3", !@editing? && "grid-cols-2"]}>
            <div :if={@editing?}>
              <label class="font-mono text-xs text-base-content/50 uppercase block mb-1">Status</label>
              <select
                name="todo[state]"
                class="w-full px-3 py-2 border-2 border-black bg-base-100 font-mono text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              >
                <option value="inbox" selected={@todo.state == :inbox}>INBOX</option>
                <option value="pending" selected={@todo.state == :pending}>PENDING</option>
                <option value="in_progress" selected={@todo.state == :in_progress}>IN PROGRESS</option>
                <option value="waiting" selected={@todo.state == :waiting}>WAITING</option>
                <option value="done" selected={@todo.state == :done}>DONE</option>
                <option value="cancelled" selected={@todo.state == :cancelled}>CANCELLED</option>
              </select>
            </div>
            <div>
              <label class="font-mono text-xs text-base-content/50 uppercase block mb-1">Priority</label>
              <select
                name={@form[:priority].name}
                class="w-full px-3 py-2 border-2 border-black bg-base-100 font-mono text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              >
                <option value="low" selected={@form[:priority].value == :low}>LOW</option>
                <option value="medium" selected={@form[:priority].value == :medium}>MEDIUM</option>
                <option value="high" selected={@form[:priority].value == :high}>HIGH</option>
                <option value="urgent" selected={@form[:priority].value == :urgent}>URGENT</option>
              </select>
            </div>
            <div>
              <label class="font-mono text-xs text-base-content/50 uppercase block mb-1">Due Date</label>
              <input
                type="date"
                name={@form[:due_date].name}
                value={@form[:due_date].value}
                class="w-full px-3 py-2 border-2 border-black bg-base-100 font-mono text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              />
            </div>
          </div>

          <%!-- Waiting On field --%>
          <div>
            <label class="font-mono text-xs text-base-content/50 uppercase block mb-1">Waiting On</label>
            <input
              type="text"
              name={@form[:waiting_on].name}
              value={@form[:waiting_on].value}
              placeholder="Who or what are you waiting on?"
              class="w-full px-3 py-2 border-2 border-black bg-base-100 font-mono text-sm focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>

          <%!-- Assignees --%>
          <div>
            <label class="font-mono text-xs text-base-content/50 uppercase block mb-2">Assigned To</label>
            <div class="flex flex-wrap gap-2">
              <input type="hidden" name="todo[assignee_ids][]" value="" />
              <%= for user <- @all_users do %>
                <% selected = user.id in @selected_assignee_ids %>
                <button
                  type="button"
                  phx-click="toggle-assignee"
                  phx-value-id={user.id}
                  class={[
                    "font-mono text-xs px-2 py-1 border-2 border-black transition-all",
                    selected && "bg-black text-white",
                    !selected && "bg-base-100 hover:bg-base-300"
                  ]}
                >
                  {user_first_name(user)}
                  <span :if={selected} class="ml-1">×</span>
                </button>
                <input :if={selected} type="hidden" name="todo[assignee_ids][]" value={user.id} />
              <% end %>
            </div>
          </div>

          <%!-- Tags --%>
          <div>
            <label class="font-mono text-xs text-base-content/50 uppercase block mb-2">Tags</label>
            <div class="flex flex-wrap gap-1.5">
              <input type="hidden" name="todo[tag_ids][]" value="" />
              <%= for tag <- @all_tags do %>
                <% selected = tag.id in @selected_tag_ids %>
                <button
                  type="button"
                  phx-click="toggle-tag"
                  phx-value-id={tag.id}
                  class={[
                    "inline-flex items-center gap-1.5 px-2 py-0.5 transition-all",
                    "font-mono text-[11px] uppercase tracking-wide",
                    "border",
                    selected && "bg-base-content text-base-100 border-base-content",
                    !selected && "bg-base-200 text-base-content border-base-300 hover:border-base-content"
                  ]}
                >
                  <span class="w-2 h-2 flex-shrink-0" style={"background-color: #{tag.color}"} />
                  {tag.name}
                  <span :if={selected} class="text-[10px]">×</span>
                </button>
                <input :if={selected} type="hidden" name="todo[tag_ids][]" value={tag.id} />
              <% end %>
              <%!-- Add tag button --%>
              <button
                type="button"
                phx-click="show-create-tag"
                class="inline-flex items-center gap-1 px-2 py-0.5 font-mono text-[11px] uppercase tracking-wide border border-dashed border-base-300 bg-base-100 hover:border-base-content transition-all"
              >
                + Tag
              </button>
            </div>
          </div>

          <%!-- Pin to today --%>
          <div class="flex items-center gap-2">
            <input type="hidden" name={@form[:pinned_to_today].name} value="false" />
            <input
              type="checkbox"
              name={@form[:pinned_to_today].name}
              value="true"
              checked={@form[:pinned_to_today].value == true}
              class="w-4 h-4 border-2 border-black bg-base-100"
            />
            <label class="font-mono text-xs uppercase">Pin to Today</label>
          </div>
        </.form>
      </div>

      <%!-- Subtasks panel --%>
      <div :if={@editing?} class="border-2 border-black bg-base-200 mb-4">
        <div class="bg-black text-white px-3 py-1.5 font-mono text-xs uppercase tracking-wider">
          Subtasks
        </div>
        <div class="p-4">
          <div id="subtasks" phx-update="stream" class="space-y-2 mb-3">
            <div
              :for={{id, subtask} <- @streams.subtasks}
              id={id}
              class="flex items-center gap-3 px-3 py-2 border-2 border-black bg-base-100"
            >
              <button
                type="button"
                phx-click="toggle-subtask"
                phx-value-id={subtask.id}
                class={[
                  "font-mono text-xs",
                  subtask.completed && "text-success",
                  !subtask.completed && "text-base-content/50"
                ]}
              >
                [{if subtask.completed, do: "×", else: " "}]
              </button>
              <span class={[
                "flex-1 font-mono text-sm",
                subtask.completed && "line-through text-base-content/50"
              ]}>
                {subtask.title}
              </span>
              <button
                type="button"
                phx-click="delete-subtask"
                phx-value-id={subtask.id}
                class="font-mono text-xs text-error hover:underline"
              >
                [DEL]
              </button>
            </div>
          </div>

          <form phx-submit="add-subtask" class="flex gap-2">
            <input
              type="text"
              name="title"
              placeholder="Add subtask..."
              class="flex-1 px-3 py-2 border-2 border-black bg-base-100 font-mono text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              required
            />
            <button
              type="submit"
              class="font-mono text-xs px-3 py-2 border-2 border-black bg-base-100 hover:bg-base-300 transition-all"
            >
              [ADD]
            </button>
          </form>
        </div>
      </div>

      <%!-- Terminal-style actions panel --%>
      <div :if={@editing?} class="mt-6 border-2 border-black bg-base-200">
        <div class="bg-black text-white px-3 py-1.5 font-mono text-xs uppercase tracking-wider">
          Actions
        </div>
        <div class="p-4 space-y-4">
          <%!-- State transitions --%>
          <div class="flex flex-wrap gap-2">
            <%= case @todo.state do %>
              <% :inbox -> %>
                <.action_button action="organize" label="ORGANIZE" primary />
                <.action_button action="start" label="START" />
              <% :pending -> %>
                <.action_button action="start" label="START" primary />
                <.action_button action="complete" label="COMPLETE" />
              <% :in_progress -> %>
                <.action_button action="complete" label="COMPLETE" primary />
                <.action_button action="pause" label="PAUSE" />
                <.action_button action="wait" label="WAIT" />
              <% :waiting -> %>
                <.action_button action="resume" label="RESUME" primary />
                <.action_button action="unblock" label="UNBLOCK" />
              <% :done -> %>
                <.action_button action="reopen" label="REOPEN" />
              <% :cancelled -> %>
                <.action_button action="reopen" label="RESTORE" />
              <% _ -> %>
            <% end %>
          </div>

          <%!-- Destructive actions on separate row --%>
          <div class="flex flex-wrap gap-2 pt-3 border-t border-black/20">
            <button
              :if={@todo.state not in [:done, :cancelled]}
              type="button"
              phx-click="transition"
              phx-value-action="cancel"
              class="font-mono text-xs px-3 py-2 border-2 border-black bg-base-100 hover:bg-base-300 transition-all uppercase tracking-wide"
            >
              [CANCEL]
            </button>
            <button
              type="button"
              phx-click="archive"
              data-confirm="Are you sure you want to archive this todo?"
              class="font-mono text-xs px-3 py-2 border-2 border-error text-error bg-base-100 hover:bg-error/10 transition-all uppercase tracking-wide"
            >
              [ARCHIVE]
            </button>
          </div>
        </div>
      </div>

      <%!-- Tag creation modal --%>
      <div :if={@show_tag_modal} class="fixed inset-0 z-50">
        <%!-- Backdrop - clicking this closes the modal --%>
        <div class="absolute inset-0 bg-black/50" phx-click="close-tag-modal"></div>
        <%!-- Modal content --%>
        <div class="relative flex items-center justify-center h-full pointer-events-none">
          <div class="pointer-events-auto bg-base-200 border-2 border-black shadow-[6px_6px_0_0_black] w-full max-w-sm mx-4">
          <div class="bg-black text-white px-3 py-1.5 font-mono text-xs uppercase tracking-wider flex items-center justify-between">
            <span>Create Tag</span>
            <button type="button" phx-click="close-tag-modal" class="hover:text-error">×</button>
          </div>
          <div class="p-4">
            <.form :if={@tag_form} for={@tag_form} phx-submit="save-new-tag" id="new-tag-form" class="space-y-4">
              <div>
                <label class="font-mono text-xs text-base-content/50 uppercase block mb-1">Name</label>
                <input
                  type="text"
                  name="tag[name]"
                  value={@tag_form[:name].value}
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
                        checked={@tag_form[:color].value == color}
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
                <button
                  type="submit"
                  class="flex-1 font-mono text-xs px-3 py-2 border-2 border-black bg-black text-white uppercase tracking-wide shadow-[2px_2px_0_0_black] hover:shadow-none hover:translate-x-0.5 hover:translate-y-0.5 transition-all"
                >
                  [CREATE]
                </button>
                <button
                  type="button"
                  phx-click="close-tag-modal"
                  class="font-mono text-xs px-3 py-2 border-2 border-black bg-base-100 hover:bg-base-300 transition-all uppercase tracking-wide"
                >
                  [CANCEL]
                </button>
              </div>
            </.form>
          </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp tag_colors do
    [
      "#ef4444", "#f97316", "#eab308", "#22c55e", "#14b8a6", "#06b6d4",
      "#3b82f6", "#6366f1", "#8b5cf6", "#a855f7", "#ec4899", "#f43f5e"
    ]
  end

  @impl true
  def handle_event("validate", %{"todo" => params}, socket) do
    # Cancel any pending save
    if socket.assigns.save_timer, do: Process.cancel_timer(socket.assigns.save_timer)

    # Clean up tag_ids and assignee_ids - filter out empty strings from hidden input
    params = clean_array_params(params, "tag_ids")
    params = clean_array_params(params, "assignee_ids")

    form =
      if socket.assigns.editing? do
        socket.assigns.todo
        |> AshPhoenix.Form.for_update(:update, domain: Todos.Tasks, as: "todo")
      else
        AshPhoenix.Form.for_create(Todos.Tasks.Todo, :create,
          domain: Todos.Tasks,
          as: "todo",
          actor: socket.assigns.current_user
        )
      end
      |> AshPhoenix.Form.validate(params)

    # Schedule auto-save after 500ms if form is valid
    # For new todos, only save if title is present
    should_save =
      form.source.valid? and
        (socket.assigns.editing? or (params["title"] || "") != "")

    timer =
      if should_save do
        Process.send_after(self(), {:auto_save, params}, 500)
      end

    {:noreply,
     socket
     |> assign(:form, to_form(form))
     |> assign(:save_timer, timer)}
  end

  def handle_event("transition", %{"action" => action}, socket) do
    action = String.to_existing_atom(action)

    case Ash.update(socket.assigns.todo, action, actor: socket.assigns.current_user) do
      {:ok, todo} ->
        todo = load_todo(todo.id)

        {:noreply,
         socket
         |> assign(:todo, todo)
         |> assign(:form, build_form(todo))
         |> put_flash(:info, "Todo updated!")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Could not update: #{inspect(error)}")}
    end
  end

  def handle_event("add-subtask", %{"title" => title}, socket) do
    case Todos.Tasks.Subtask
         |> Ash.Changeset.for_create(:create, %{
           title: title,
           todo_id: socket.assigns.todo.id,
           position: length(socket.assigns.todo.subtasks || [])
         })
         |> Ash.create() do
      {:ok, subtask} ->
        {:noreply, stream_insert(socket, :subtasks, subtask)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not add subtask")}
    end
  end

  def handle_event("toggle-subtask", %{"id" => id}, socket) do
    subtask = Ash.get!(Todos.Tasks.Subtask, id)

    case Ash.update(subtask, %{}, action: :toggle) do
      {:ok, updated} ->
        {:noreply, stream_insert(socket, :subtasks, updated)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not toggle subtask")}
    end
  end

  def handle_event("delete-subtask", %{"id" => id}, socket) do
    subtask = Ash.get!(Todos.Tasks.Subtask, id)

    case Ash.destroy(subtask) do
      {:ok, _} ->
        {:noreply, stream_delete(socket, :subtasks, subtask)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete subtask")}
    end
  end

  def handle_event("toggle-tag", %{"id" => tag_id}, socket) do
    # Cancel any pending save
    if socket.assigns.save_timer, do: Process.cancel_timer(socket.assigns.save_timer)

    selected = socket.assigns.selected_tag_ids

    updated =
      if tag_id in selected do
        List.delete(selected, tag_id)
      else
        [tag_id | selected]
      end

    # Schedule auto-save with updated tags
    params = %{
      "title" => socket.assigns.form[:title].value || socket.assigns.todo.title,
      "tag_ids" => updated,
      "assignee_ids" => socket.assigns.selected_assignee_ids
    }

    timer = Process.send_after(self(), {:auto_save, params}, 500)

    {:noreply,
     socket
     |> assign(:selected_tag_ids, updated)
     |> assign(:save_timer, timer)}
  end

  def handle_event("toggle-assignee", %{"id" => user_id}, socket) do
    # Cancel any pending save
    if socket.assigns.save_timer, do: Process.cancel_timer(socket.assigns.save_timer)

    selected = socket.assigns.selected_assignee_ids

    updated =
      if user_id in selected do
        List.delete(selected, user_id)
      else
        [user_id | selected]
      end

    # Schedule auto-save with updated assignees
    params = %{
      "title" => socket.assigns.form[:title].value || socket.assigns.todo.title,
      "tag_ids" => socket.assigns.selected_tag_ids,
      "assignee_ids" => updated
    }

    timer = Process.send_after(self(), {:auto_save, params}, 500)

    {:noreply,
     socket
     |> assign(:selected_assignee_ids, updated)
     |> assign(:save_timer, timer)}
  end

  def handle_event("show-create-tag", _, socket) do
    tag_form =
      Todos.Tasks.Tag
      |> AshPhoenix.Form.for_create(:create, domain: Todos.Tasks, as: "tag")
      |> to_form()

    {:noreply,
     socket
     |> assign(:show_tag_modal, true)
     |> assign(:tag_form, tag_form)}
  end

  def handle_event("close-tag-modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_tag_modal, false)
     |> assign(:tag_form, nil)}
  end

  def handle_event("save-new-tag", %{"tag" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.tag_form, params: params) do
      {:ok, tag} ->
        # Add to all_tags and auto-select the new tag
        {:noreply,
         socket
         |> assign(:all_tags, [tag | socket.assigns.all_tags])
         |> assign(:selected_tag_ids, [tag.id | socket.assigns.selected_tag_ids])
         |> assign(:show_tag_modal, false)
         |> assign(:tag_form, nil)
         |> put_flash(:info, "Tag created!")}

      {:error, form} ->
        {:noreply, assign(socket, :tag_form, to_form(form))}
    end
  end

  def handle_event("archive", _, socket) do
    case Ash.destroy(socket.assigns.todo) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Todo archived")
         |> push_navigate(to: ~p"/todos")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not archive todo")}
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

  @impl true
  def handle_info({:auto_save, params}, socket) do
    was_editing = socket.assigns.editing?

    # Clean up params
    params = clean_array_params(params, "tag_ids")
    params = clean_array_params(params, "assignee_ids")

    # Check if state is being changed
    new_state = params["state"]
    state_changed = was_editing && new_state && String.to_existing_atom(new_state) != socket.assigns.todo.state

    params =
      if was_editing do
        # Remove state from params - we'll handle it separately
        Map.delete(params, "state")
      else
        Map.put(params, "user_id", socket.assigns.current_user.id)
      end

    socket = push_event(socket, "saving", %{})

    # First, submit the regular form (without state)
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, todo} ->
        # If state changed, apply it using set_state action
        todo =
          if state_changed do
            {:ok, updated} = Ash.update(todo, %{state: String.to_existing_atom(new_state)}, action: :set_state)
            updated
          else
            todo
          end

        todo = load_todo(todo.id)

        socket =
          socket
          |> assign(:todo, todo)
          |> assign(:editing?, true)
          |> assign(:page_title, todo.title)
          |> assign(:form, build_form(todo))
          |> assign(:selected_tag_ids, Enum.map(todo.tags || [], & &1.id))
          |> assign(:selected_assignee_ids, Enum.map(todo.assignees || [], & &1.id))
          |> push_event("saved", %{})
          |> stream(:subtasks, todo.subtasks || [], reset: true)

        # For newly created todos, update the URL without full navigation
        socket =
          if not was_editing do
            push_patch(socket, to: ~p"/todos/#{todo.id}", replace: true)
          else
            socket
          end

        {:noreply, socket}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, to_form(form))
         |> push_event("save-error", %{})}
    end
  end

  defp load_todo(id) do
    Ash.get!(Todos.Tasks.Todo, id, load: [:tags, :subtasks, :user, :completed_by, :assignees])
  end

  defp load_all_tags do
    Todos.Tasks.Tag
    |> Ash.Query.for_read(:list_all)
    |> Ash.read!()
  end

  defp load_all_users do
    Todos.Accounts.User
    |> Ash.read!()
  end

  defp clean_array_params(params, key) do
    case params[key] do
      list when is_list(list) ->
        Map.put(params, key, Enum.filter(list, &(&1 != "")))

      _ ->
        params
    end
  end

  defp build_form(todo) do
    todo
    |> AshPhoenix.Form.for_update(:update, domain: Todos.Tasks, as: "todo")
    |> to_form()
  end

  defp build_create_form(current_user) do
    AshPhoenix.Form.for_create(Todos.Tasks.Todo, :create,
      domain: Todos.Tasks,
      as: "todo",
      actor: current_user
    )
    |> to_form()
  end

  defp display_name(nil), do: "Unknown"
  defp display_name(%{tailscale_name: name}) when is_binary(name) and name != "", do: name
  defp display_name(%{email: email}) when not is_nil(email), do: email
  defp display_name(_), do: "Unknown"

  defp user_first_name(user) do
    name = user.tailscale_name || user.email || "?"
    name |> String.split() |> List.first() || name
  end

  attr :field, :any, required: true

  defp field_errors(assigns) do
    ~H"""
    <%= for error <- @field.errors do %>
      <p class="font-mono text-xs text-error mt-1">
        ! {format_error(error)}
      </p>
    <% end %>
    """
  end

  defp format_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  attr :action, :string, required: true
  attr :label, :string, required: true
  attr :primary, :boolean, default: false

  defp action_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="transition"
      phx-value-action={@action}
      class={[
        "font-mono text-xs px-3 py-2 border-2 border-black transition-all uppercase tracking-wide",
        "shadow-[2px_2px_0_0_black] hover:shadow-none hover:translate-x-0.5 hover:translate-y-0.5",
        @primary && "bg-black text-white",
        !@primary && "bg-base-100 hover:bg-base-200"
      ]}
    >
      [{@label}]
    </button>
    """
  end
end
