defmodule AuvalOffice.MixProject do
  use Mix.Project

  def project do
    [
      app: :auval_office,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Code quality
      {:credo, "~> 1.5.0", runtime: false, only: :dev},

      # Docs
      {:ex_doc, "~> 0.23.0", runtime: false, only: :dev}
    ]
  end
end
