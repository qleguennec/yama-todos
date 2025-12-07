defmodule TodosWeb.LiveUserAuth do
  @moduledoc """
  LiveView authentication helpers for Tailscale auth.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:live_user_optional, _params, session, socket) do
    socket = assign_current_user(socket, session)
    {:cont, socket}
  end

  def on_mount(:live_user_required, _params, session, socket) do
    socket = assign_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must be logged in via Tailscale to access this page.")
       |> redirect(to: "/")}
    end
  end

  defp assign_current_user(socket, session) do
    case session["current_user_id"] do
      nil ->
        assign(socket, :current_user, nil)

      user_id ->
        case Ash.get(Todos.Accounts.User, user_id) do
          {:ok, user} -> assign(socket, :current_user, user)
          _ -> assign(socket, :current_user, nil)
        end
    end
  end
end
