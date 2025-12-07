defmodule TodosWeb.Router do
  use TodosWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TodosWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug TodosWeb.Plugs.TailscaleAuth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TodosWeb do
    pipe_through :browser

    live_session :default, on_mount: [{TodosWeb.LiveUserAuth, :live_user_optional}] do
      # Main views
      live "/", GlobalLive
      live "/today", TodayLive
      live "/plan", PlanLive
      live "/plan/:id", PlanLive
      live "/todos", TodosLive
      live "/todos/:id", TodoLive
      live "/waiting", WaitingLive
      live "/tags", TagsLive

      # Quick capture
      live "/capture", CaptureLive
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:todos, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TodosWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
