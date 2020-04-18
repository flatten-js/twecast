defmodule TwecastWeb.Router do
  use TwecastWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", TwecastWeb do
    pipe_through :api
  end

  scope "/", TwecastWeb do
    post "/callback", BotController, :line_callback
  end
end
