defmodule TodosWeb.CaptureLiveTest do
  use TodosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "capture page" do
    test "create full todo link passes entered title", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/capture")

      # Type a title in the capture form - trigger change event
      html =
        view
        |> element("#capture-form")
        |> render_change(%{"todo" => %{"title" => "My captured title"}})

      # The CREATE FULL TODO link should contain the title as query param
      assert html =~ ~r{/todos/new\?title=My\+captured\+title|/todos/new\?title=My%20captured%20title}
    end

    test "create full todo link is empty when no title entered", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/capture")

      # Link should just go to /todos/new without title param
      assert html =~ ~s(href="/todos/new")
      refute html =~ "/todos/new?title="
    end
  end
end
