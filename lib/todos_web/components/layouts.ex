defmodule TodosWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality.
  """
  use TodosWeb, :html

  embed_templates "layouts/*"

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end

  @doc """
  Renders a subtle disconnect indicator that shows in the header when connection is lost.
  """
  def disconnect_indicator(assigns) do
    ~H"""
    <div
      id="disconnect-indicator"
      class="hidden items-center gap-1 font-mono text-xs text-warning uppercase"
      phx-disconnected={JS.remove_class("hidden") |> JS.add_class("flex")}
      phx-connected={JS.remove_class("flex") |> JS.add_class("hidden")}
    >
      <span class="animate-pulse">[RECONNECTING...]</span>
    </div>
    """
  end

  @doc """
  Renders a save status indicator that shows saving/saved state.
  """
  def save_indicator(assigns) do
    ~H"""
    <div
      id="save-indicator"
      class="flex items-center font-mono text-xs uppercase"
      phx-hook="SaveIndicator"
    >
      <span id="save-status"></span>
    </div>
    """
  end

  defp user_initial(nil), do: nil

  defp user_initial(user) do
    name = user.tailscale_name || user.email || "?"

    name
    |> to_string()
    |> String.first()
    |> String.upcase()
  end

  @doc """
  Renders your app layout with bottom navigation dock.

  ## Examples

      <Layouts.app flash={@flash} active_tab={:inbox}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current scope"

  attr :current_user, :map,
    default: nil,
    doc: "the currently logged in user"

  attr :active_tab, :atom,
    default: :global,
    doc: "the currently active navigation tab (:global, :today, :plan, :todos, :waiting, :tags)"

  attr :fullscreen, :boolean,
    default: false,
    doc: "when true, content fills the entire main area without padding"

  attr :courses_todo, :map,
    default: nil,
    doc: "the courses todo for the quick action button"

  slot :inner_block, required: true

  def app(assigns) do
    assigns = assign(assigns, :initial, user_initial(assigns.current_user))

    ~H"""
    <div class="flex flex-col h-full h-[100dvh]">
      <%!-- Terminal-style header --%>
      <header class="flex-none bg-black text-white safe-top">
        <div class="h-12 flex items-center justify-between px-3 font-mono text-xs">
          <.link navigate={~p"/"} class="flex items-center gap-2 hover:text-primary transition-colors">
            <div class="w-6 h-6 border border-white flex items-center justify-center">
              <span class="text-[10px] font-bold">///</span>
            </div>
            <span class="uppercase tracking-wider">TODO.SYS</span>
          </.link>

          <div class="flex items-center gap-3">
            <.save_indicator />
            <.disconnect_indicator />
            <%= if @courses_todo do %>
              <button
                id="courses-quick-action"
                phx-hook="CoursesPrompt"
                data-todo-id={@courses_todo.id}
                class="px-2 py-1 border border-white hover:bg-white hover:text-black transition-all uppercase tracking-wide"
              >
                [COURSES]
              </button>
            <% else %>
              <button
                disabled
                class="px-2 py-1 border border-white/30 text-white/30 uppercase tracking-wide cursor-not-allowed"
              >
                [COURSES]
              </button>
            <% end %>
            <.link
              navigate={~p"/capture"}
              class="w-7 h-7 border border-white hover:bg-white hover:text-black transition-all flex items-center justify-center"
            >
              +
            </.link>
            <%= if @current_user do %>
              <div
                class="px-2 py-1 border border-white/50 text-white/70 uppercase"
                title={@current_user.tailscale_name || @current_user.email}
              >
                USR:{@initial}
              </div>
            <% end %>
          </div>
        </div>
      </header>

      <.flash_group flash={@flash} />

      <main class={[
        "flex-1 bg-base-100 min-h-0",
        if(@fullscreen, do: "flex flex-col", else: "overflow-y-auto overscroll-contain")
      ]}>
        <%= if @fullscreen do %>
          {render_slot(@inner_block)}
        <% else %>
          <div class="px-4 py-4">
            {render_slot(@inner_block)}
          </div>
        <% end %>
      </main>

      <%!-- Terminal-style bottom navigation --%>
      <nav class="flex-none bg-black text-white safe-bottom">
        <div class="flex justify-around items-stretch font-mono text-[10px] uppercase tracking-wider">
          <.link
            navigate={~p"/"}
            class={[
              "flex-1 py-3 flex items-center justify-center border-t-2 transition-all",
              if(@active_tab == :global,
                do: "border-primary text-primary bg-primary/10",
                else: "border-transparent text-white/50 hover:text-white hover:bg-white/5"
              )
            ]}
          >
            Glbl
          </.link>
          <.link
            navigate={~p"/today"}
            class={[
              "flex-1 py-3 flex items-center justify-center border-t-2 transition-all",
              if(@active_tab == :today,
                do: "border-primary text-primary bg-primary/10",
                else: "border-transparent text-white/50 hover:text-white hover:bg-white/5"
              )
            ]}
          >
            Today
          </.link>
          <.link
            navigate={~p"/plan"}
            class={[
              "flex-1 py-3 flex items-center justify-center border-t-2 transition-all",
              if(@active_tab == :plan,
                do: "border-primary text-primary bg-primary/10",
                else: "border-transparent text-white/50 hover:text-white hover:bg-white/5"
              )
            ]}
          >
            Plan
          </.link>
          <.link
            navigate={~p"/todos"}
            class={[
              "flex-1 py-3 flex items-center justify-center border-t-2 transition-all",
              if(@active_tab == :todos,
                do: "border-primary text-primary bg-primary/10",
                else: "border-transparent text-white/50 hover:text-white hover:bg-white/5"
              )
            ]}
          >
            All
          </.link>
          <.link
            navigate={~p"/waiting"}
            class={[
              "flex-1 py-3 flex items-center justify-center border-t-2 transition-all",
              if(@active_tab == :waiting,
                do: "border-primary text-primary bg-primary/10",
                else: "border-transparent text-white/50 hover:text-white hover:bg-white/5"
              )
            ]}
          >
            Wait
          </.link>
          <.link
            navigate={~p"/tags"}
            class={[
              "flex-1 py-3 flex items-center justify-center border-t-2 transition-all",
              if(@active_tab == :tags,
                do: "border-primary text-primary bg-primary/10",
                else: "border-transparent text-white/50 hover:text-white hover:bg-white/5"
              )
            ]}
          >
            Tags
          </.link>
        </div>
      </nav>
    </div>
    """
  end
end
