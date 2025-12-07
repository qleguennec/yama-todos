defmodule TodosWeb.CoreComponents do
  @moduledoc """
  Provides core UI components for the Todos app.
  """
  use Phoenix.Component
  use Gettext, backend: TodosWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      phx-mounted={JS.transition({"ease-out duration-200", "opacity-0 -translate-y-2", "opacity-100 translate-y-0"})}
      role="alert"
      class={[
        "font-mono text-xs flex items-center justify-between px-3 py-2 cursor-pointer",
        @kind == :info && "bg-success text-success-content",
        @kind == :error && "bg-error text-error-content"
      ]}
      {@rest}
    >
      <div class="flex items-center gap-2 uppercase tracking-wider">
        <span :if={@kind == :info}>[OK]</span>
        <span :if={@kind == :error}>[ERR]</span>
        <span>{msg}</span>
      </div>
      <span class="opacity-70 hover:opacity-100">[×]</span>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any
  attr :variant, :string, values: ~w(primary secondary ghost)
  slot :inner_block, required: true

  @brutalist_base "btn border-2 border-black rounded-none shadow-[3px_3px_0_0_black] font-bold uppercase hover:shadow-none hover:translate-x-0.5 hover:translate-y-0.5 transition-all"

  def button(%{rest: rest} = assigns) do
    variants = %{
      "primary" => "btn-primary",
      "secondary" => "btn-secondary",
      "ghost" => "btn-ghost shadow-none border-0",
      nil => "btn-primary"
    }

    assigns =
      assign_new(assigns, :class, fn ->
        [@brutalist_base, Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset mb-2">
      <label>
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <span class="label font-bold">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm border-2 border-black rounded-none"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1 font-bold uppercase text-sm">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[
            @class || "w-full select border-2 border-black rounded-none",
            @errors != [] && (@error_class || "select-error border-error")
          ]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1 font-bold uppercase text-sm">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea border-2 border-black rounded-none",
            @errors != [] && (@error_class || "textarea-error border-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1 font-bold uppercase text-sm">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "w-full input border-2 border-black rounded-none",
            @errors != [] && (@error_class || "input-error border-error")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[
      @actions != [] && "flex items-center justify-between gap-6",
      "pb-4 border-b-2 border-black mb-4"
    ]}>
      <div>
        <h1 class="text-xl font-black uppercase tracking-wide">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70 font-medium">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Renders a badge for todo priority.
  """
  attr :priority, :atom, required: true

  def priority_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm border-2 border-black rounded-none font-bold uppercase",
      @priority == :urgent && "badge-error",
      @priority == :high && "badge-warning",
      @priority == :medium && "badge-info",
      @priority == :low && "bg-base-200"
    ]}>
      {Phoenix.Naming.humanize(@priority)}
    </span>
    """
  end

  @doc """
  Renders a badge for todo state.
  """
  attr :state, :atom, required: true

  def state_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm border-2 border-black rounded-none font-bold uppercase",
      @state == :inbox && "badge-neutral",
      @state == :pending && "badge-primary badge-outline",
      @state == :in_progress && "badge-primary",
      @state == :waiting && "badge-warning",
      @state == :done && "badge-success",
      @state == :cancelled && "bg-base-200"
    ]}>
      {state_label(@state)}
    </span>
    """
  end

  defp state_label(:inbox), do: "Inbox"
  defp state_label(:pending), do: "Pending"
  defp state_label(:in_progress), do: "In Progress"
  defp state_label(:waiting), do: "Waiting"
  defp state_label(:done), do: "Done"
  defp state_label(:cancelled), do: "Cancelled"

  @doc """
  Renders a tag in IBM Carbon Design style.
  """
  attr :name, :string, required: true
  attr :color, :string, default: "#6366f1"
  attr :class, :string, default: nil

  def tag_pill(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1.5 px-2 py-0.5",
      "bg-base-200 border border-base-300",
      "font-mono text-[11px] uppercase tracking-wide text-base-content",
      @class
    ]}>
      <span class="w-2 h-2 flex-shrink-0" style={"background-color: #{@color}"} />
      {@name}
    </span>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(TodosWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(TodosWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
