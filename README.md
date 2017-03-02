# Vaultex

I very simple elixir interface to the vault secret store
(https://www.vaultproject.io/). It defaults to appauth authentication and is
still pretty early days.

## Installation

This is currently not published to Hex so pull it from git by adding
this to your dependencies:

```elixir
def deps do
  [{:vaultex, github: "ideegeo/vaultex"}]
end
```

Then add it to your applications like so:

```elixir
def application do
  # Specify extra applications you'll use from Erlang/Elixir
  [extra_applications: [:logger, :vaultex],
   mod: {DynamicConfig.Application, []}]
end
```

## Usage

`vaultex` expects two configuration values to be present in either your
Application environment or your system environment. If you use the local vault
development server you can start vault with `./vault_dev_server.sh` - that
starts vault and creates two files:
- .role_id
- .secret_id

These two files hold the `role_id` and `secret_id` needed for the appauth vault
authentication backend. If you use this in production you should bundle one ID
with your app and the other one out of band, via a configuation system for
example.

To pull data our of vault use the `read` function like so:

```elixir
case Vaultex.Client.read(key) do
  {:ok, res} ->
	Logger.debug("Got some data: #{inspect res}")
	{:ok, res}
  error -> error
end
```

Please see the `test/vaultex_test.exs` file for a few more examples on how to
use `vaultex`



