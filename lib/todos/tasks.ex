defmodule Todos.Tasks do
  use Ash.Domain,
    otp_app: :todos

  resources do
    resource Todos.Tasks.Todo
    resource Todos.Tasks.Tag
    resource Todos.Tasks.TodoTag
    resource Todos.Tasks.TodoAssignee
    resource Todos.Tasks.Subtask
    resource Todos.Tasks.RecurringPattern
    resource Todos.Tasks.UserTagOrder
  end
end
