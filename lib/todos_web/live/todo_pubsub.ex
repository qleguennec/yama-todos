defmodule TodosWeb.TodoPubSub do
  @moduledoc """
  PubSub helper for broadcasting todo changes across LiveViews.
  """

  @topic "todos:changes"

  def subscribe do
    Phoenix.PubSub.subscribe(Todos.PubSub, @topic)
  end

  def broadcast_change do
    Phoenix.PubSub.broadcast(Todos.PubSub, @topic, :todos_changed)
  end
end
