defmodule ExDir.MixProject do
  use Mix.Project

  def project do
    [
      app: :exdir,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "ExDir",
      source_url: "https://github.com/team-telnyx/exdir",
      description: description()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:dirent, "~> 1.0.2"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    An iterative directory listing for Elixir.
    """
  end

  defp package do
    [
      maintainers: ["Guilherme Balena Versiani"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/team-telnyx/exdir"},
      files: ~w"lib mix.exs README.md LICENSE"
    ]
  end
end
