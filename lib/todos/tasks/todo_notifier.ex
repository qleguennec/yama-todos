defmodule Todos.Tasks.TodoNotifier do
  @moduledoc """
  Ash Notifier that broadcasts todo/tag changes via PubSub.
  """
  use Ash.Notifier

  @impl true
  def notify(%Ash.Notifier.Notification{resource: Todos.Tasks.Todo}) do
    TodosWeb.TodoPubSub.broadcast_change()
    :ok
  end

  def notify(%Ash.Notifier.Notification{resource: Todos.Tasks.Tag}) do
    TodosWeb.TodoPubSub.broadcast_change()
    :ok
  end

  def notify(_notification), do: :ok
end
