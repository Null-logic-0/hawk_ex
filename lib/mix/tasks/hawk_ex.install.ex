defmodule Mix.Tasks.HawkEx.Install do
  use Mix.Task

  @shortdoc "Installs HAWK_EX migrations and prints configuration instructions"

  @moduledoc """
  Installs HAWK_EX into a Phoenix application.

      mix hawk_ex.install

  This task:

    1. Copies migration files into priv/repo/migrations/
    2. Prints the configuration block to add to config/config.exs

  ## Options

    --repo   The repo module to use in the migration filename.
             Defaults to the first repo found in the application config,
             or MyApp.Repo if none is configured.

  ## Example

      mix hawk_ex.install

  """

  @template_dir Path.join(:code.priv_dir(:hawk_ex), "templates/migrations")
  @migrations_dir "priv/repo/migrations"

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [repo: :string])
    repo_module = Keyword.get(opts, :repo, detect_repo())

    Mix.shell().info("""

    Installing HAWK_EX...
    """)

    copy_migrations(repo_module)
    print_config_instructions(repo_module)
    print_next_steps()
  end

  # ---Private-------------------------------------------------------------

  defp copy_migrations(repo_module) do
    File.mkdir_p!(@migrations_dir)

    templates()
    |> Enum.each(fn template_path ->
      filename = build_filename(template_path)
      destination = Path.join(@migrations_dir, filename)

      if File.exists?(destination) do
        Mix.shell().info("  [skip] #{destination} already exists")
      else
        migration_module = build_migration_module(repo_module, filename)
        content = EEx.eval_file(template_path, migration_module: migration_module)

        File.write!(destination, content)
        Mix.shell().info("  [ok]   #{destination}")
      end
    end)
  end

  defp templates do
    Path.wildcard(Path.join(@template_dir, "*.exs.eex"))
  end

  defp build_filename(template_path) do
    timestamp = timestamp()

    base =
      template_path
      # strips .eex → create_hawk_ex_billing_tables.exs
      |> Path.basename(".eex")
      # strips .exs → create_hawk_ex_billing_tables
      |> Path.rootname()

    "#{timestamp}_#{base}.exs"
  end

  defp build_migration_module(repo_module, filename) do
    # "20240101000001_create_hawk_ex_billing_tables.exs"
    # → "CreateHawkExBillingTables"
    migration_suffix =
      filename
      # drop .exs
      |> Path.rootname()
      # drop timestamp prefix
      |> String.replace(~r/^\d+_/, "")
      |> Macro.camelize()

    "#{repo_module}.Migrations.#{migration_suffix}"
  end

  defp print_config_instructions(repo_module) do
    Mix.shell().info("""

    Add this to your config/config.exs:

        config :hawk_ex,
          repo: #{repo_module},
          account_schema: MyApp.Accounts.Organization

    Replace MyApp.Accounts.Organization with your actual account schema.
    """)
  end

  defp print_next_steps do
    Mix.shell().info("""
    Next steps:

      [ ] Update account_schema in config/config.exs
      [ ] Run mix ecto.migrate
      [ ] Call HawkEx.Billing.subscribe(account, :free) on user signup

    Documentation: https://hexdocs.pm/hawk_ex
    """)
  end

  defp detect_repo do
    Mix.Project.config()
    |> Keyword.get(:app)
    |> case do
      nil ->
        "MyApp.Repo"

      app ->
        app
        |> to_string()
        |> Macro.camelize()
        |> then(&"#{&1}.Repo")
    end
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(n), do: String.pad_leading(to_string(n), 2, "0")
end
