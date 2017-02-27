defmodule Vaultex do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      worker(Vaultex.Client, [])
    ]

    Logger.debug("Creating ETS tables for #{__MODULE__}")
    case :ets.info(__MODULE__) do
      :undefined ->
        :ets.new(__MODULE__, [:set, :named_table, :public])
      _ ->
        :ets.delete(__MODULE__)
        :ets.new(__MODULE__, [:set, :named_table, :public])
    end

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Vaultex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
