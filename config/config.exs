# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :twecast, TwecastWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "kPhxPlkyhwsXzP04Yw6TgqK7a+SVp23KnenhOYSDiggJKu3a7veVY1C9C+iO9xcj",
  render_errors: [view: TwecastWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: Twecast.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [signing_salt: "kpIknFaW"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :extwitter, :oauth, [
  consumer_key: System.get_env("TWITTER_API_KEY"),
  consumer_secret: System.get_env("TWITTER_API_SECRET_KEY"),
  access_token: System.get_env("TWITTER_ACCESS_TOKEN"),
  access_token_secret: System.get_env("TWITTER_ACCESS_SECRET_TOKEN")
]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
