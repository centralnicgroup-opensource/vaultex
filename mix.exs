defmodule Vaultex.Mixfile do
  use Mix.Project

  def project do
    [app: :vaultex,
     version: "0.0.1",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :hackney, :poison],
     mod: {Vaultex, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:hackney, ">= 1.3.0"},
      {:poison, ">= 1.5.0"},
      {:credo, ">= 0.4.11", only: [:dev, :test]}
    ]
  end
end
