defmodule TodosWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint TodosWeb.Endpoint

      use TodosWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import TodosWeb.ConnCase

      # Import test fixtures
      use Ash.Generator
      import Todos.AccountsFixtures, except: [generate: 1, generate_many: 2]
      import Todos.TasksFixtures, except: [generate: 1, generate_many: 2]
    end
  end

  setup tags do
    Todos.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in users via Tailscale mock.

  Returns the connection with the user authenticated and the user struct.

      setup :register_and_log_in_user

      test "can access protected route", %{conn: conn, user: user} do
        # ...
      end
  """
  def register_and_log_in_user(%{conn: conn}) do
    import Todos.AccountsFixtures
    user = generate(user())
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Logs in a user by setting session and assigns to simulate Tailscale auth.

      conn = log_in_user(conn, user)
  """
  def log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user_id, user.id)
    |> Plug.Conn.assign(:current_user, user)
  end
end
