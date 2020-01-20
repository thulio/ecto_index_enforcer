use Mix.Config

config :example, :ecto_repos, [Example.Repo]

config :example, Example.Repo,
  database: "ecto_example_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"
