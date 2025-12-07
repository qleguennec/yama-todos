defmodule TodosWeb.Plugs.TailscaleAuth do
  @moduledoc """
  Plug that authenticates users via Tailscale headers set by the ForwardAuth middleware.

  Headers expected from Caddy ForwardAuth:
  - Tailscale-Login: username (e.g., "quentin.leguennec1")
  - Tailscale-Name: display name (e.g., "Quentin Le Guennec")
  - Tailscale-User: email (e.g., "quentin.leguennec1@gmail.com")
  """

  import Plug.Conn
  require Ash.Query

  @tailscale_login_header "tailscale-login"
  @tailscale_name_header "tailscale-name"
  @tailscale_user_header "tailscale-user"

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_tailscale_headers(conn) do
      {:ok, tailscale_info} ->
        case get_or_create_user(tailscale_info) do
          {:ok, user} ->
            conn
            |> put_session(:current_user_id, user.id)
            |> assign(:current_user, user)
            |> assign(:tailscale_info, tailscale_info)

          {:error, reason} ->
            conn
            |> assign(:current_user, nil)
            |> assign(:tailscale_auth_error, reason)
        end

      :no_tailscale ->
        assign(conn, :current_user, nil)
    end
  end

  defp get_tailscale_headers(conn) do
    login = get_header(conn, @tailscale_login_header)
    name = get_header(conn, @tailscale_name_header)
    user = get_header(conn, @tailscale_user_header)

    if login do
      {:ok,
       %{
         login: login,
         name: name || login,
         user: user || login
       }}
    else
      :no_tailscale
    end
  end

  defp get_header(conn, header) do
    case get_req_header(conn, header) do
      [value | _] -> value
      [] -> nil
    end
  end

  defp get_or_create_user(%{login: login, name: name, user: user}) do
    case Todos.Accounts.User
         |> Ash.Query.for_read(:get_by_tailscale_login, %{tailscale_login: login})
         |> Ash.read_one() do
      {:ok, nil} ->
        Todos.Accounts.User
        |> Ash.Changeset.for_create(:create_from_tailscale, %{
          tailscale_login: login,
          tailscale_name: name,
          tailscale_user: user
        })
        |> Ash.create()

      {:ok, user} ->
        {:ok, user}

      {:error, error} ->
        {:error, error}
    end
  end
end
