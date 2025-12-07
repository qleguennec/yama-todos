defmodule Todos.AccountsFixtures do
  @moduledoc """
  Test fixtures for creating account-related resources using Ash.Generator.
  """

  use Ash.Generator

  @doc """
  Generator for creating a user via Tailscale auth.

  ## Examples

      user = generate(user())
      user = generate(user(tailscale_name: "Alice"))
  """
  def user(opts \\ []) do
    changeset_generator(
      Todos.Accounts.User,
      :create_from_tailscale,
      defaults: [
        tailscale_login: sequence(:tailscale_login, &"user#{&1}@example.com"),
        tailscale_user: sequence(:tailscale_user, &"user#{&1}@example.com"),
        tailscale_name: sequence(:tailscale_name, &"Test User #{&1}")
      ],
      overrides: opts
    )
  end
end
