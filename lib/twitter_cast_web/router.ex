defmodule TwitterCastWeb.Router do
  use TwitterCastWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", TwitterCastWeb do
    pipe_through :api
  end

  scope "/", TwitterCastWeb do
    post "/callback", BotController, :line_callback
  end
end
