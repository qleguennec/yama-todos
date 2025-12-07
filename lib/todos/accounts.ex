defmodule Todos.Accounts do
  use Ash.Domain,
    otp_app: :todos

  resources do
    resource Todos.Accounts.User
    resource Todos.Accounts.Token
  end
end
