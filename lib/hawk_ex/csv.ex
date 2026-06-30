defmodule HawkEx.CSV do
  @moduledoc """
  CSV export and import tools for Phoenix SaaS applications.

  ## Synchronous export

  Returns a CSV string directly. Suitable for small datasets.

      case HawkEx.CSV.export(account, :subscriptions) do
        {:ok, csv, row_count} ->
          conn
          |> put_resp_content_type("text/csv")
          |> put_resp_header("content-disposition", ~s(attachment; filename="subscriptions.csv"))
          |> send_resp(200, csv)

        {:error, reason} ->
          # handle error
      end

  ## Async export (requires Oban)

  Creates an export job. The CSV is generated in the background.

      {:ok, export} = HawkEx.CSV.export_async(account, :subscriptions)
      # export.status == "pending"

      # Listen for completion:
      # HawkEx.Events will emit "csv.export.completed" when done

  ## Built-in export types

    * `:subscriptions` — all account subscriptions
    * `:audit_logs` — all audit log entries for the account

  ## Custom formatters

      HawkEx.CSV.export(account, MyApp.CSV.Formatters.Users)
  """

  import Ecto.Query
  alias HawkEx.Config
  alias HawkEx.CSV.{Export, Exporter}

  # ----Public API------------------------------------------------------------

  @doc """
  Generates a CSV synchronously and returns the content.

  Returns {:ok, csv_string, row_count} or {:error, reason}.
  """
  def export(account, formatter) do
    account_id = extract_account_id(account)
    Exporter.generate(account_id, formatter)
  end

  @doc """
  Creates an export record and enqueues an Oban job.

  Returns {:ok, export} immediately — the CSV is generated
  in the background.

  Requires Oban to be installed and configured:

      config :my_app, Oban,
        repo: MyApp.Repo,
        queues: [hawk_ex_exports: 2]

  Returns {:error, :oban_not_available} if Oban is not installed.
  """
  def export_async(account, formatter) do
    if Code.ensure_loaded?(Oban) do
      account_id = extract_account_id(account)
      formatter_key = formatter_to_key(formatter)

      with {:ok, export} <- create_export_record(account_id, formatter_key),
           {:ok, job} <- enqueue_job(export, formatter_key) do
        export
        |> Export.changeset(%{oban_job_id: job.id})
        |> Config.repo().update()
      end
    else
      {:error, :oban_not_available}
    end
  end

  @doc """
  Returns a page of CSV exports across all accounts, newest first.

  ## Options
    * `:page` — 1-indexed page number (default: 1)
    * `:per_page` — rows per page (default: 50)
    * `:search` — optional search term, matches `export_type` (default: nil)

  Returns `%{entries:, page:, per_page:, total_count:, total_pages:}`.

  ## Example

      HawkEx.CSV.recent_exports(page: 1, per_page: 50)
      # => %{entries: [...], page: 1, per_page: 50, total_count: 45, total_pages: 1}

      HawkEx.CSV.recent_exports(search: "subscriptions")
      # => only exports where export_type matches "subscriptions"
  """
  def recent_exports(opts \\ []) do
    HawkEx.Pagination.paginate(
      Ecto.Query.from(e in Export),
      Keyword.put(opts, :search_fun, fn query, search ->
        pattern = "%#{search}%"
        Ecto.Query.from(e in query, where: ilike(e.export_type, ^pattern))
      end)
    )
  end

  @doc "Returns all exports for an account, newest first."
  def list_exports(account) do
    import Ecto.Query

    account_id = extract_account_id(account)

    Config.repo().all(
      from(e in Export,
        where: e.account_id == ^account_id,
        order_by: [desc: e.inserted_at]
      )
    )
  end

  @doc "Returns a single export by id."
  def get_export(id) do
    case Config.repo().get(Export, id) do
      nil -> {:error, :not_found}
      export -> {:ok, export}
    end
  end

  def read_export(%Export{status: "completed", file_path: path}) when is_binary(path) do
    HawkEx.CSV.Storage.read(path)
  end

  def read_export(%Export{status: status}) do
    {:error, {:export_not_ready, status}}
  end

  # ----Private------------------------------------------------------------

  defp create_export_record(account_id, formatter_key) do
    %Export{}
    |> Export.changeset(%{
      account_id: account_id,
      export_type: formatter_key,
      status: "pending"
    })
    |> Config.repo().insert()
  end

  defp enqueue_job(export, formatter_key) do
    args = %{"export_id" => export.id, "formatter" => formatter_key}

    job = apply(HawkEx.CSV.ExportWorker, :new, [args])
    apply(Oban, :insert, [Config.oban(), job])
  end

  defp formatter_to_key(formatter) when is_atom(formatter) do
    built_in = %{
      HawkEx.CSV.Formatters.Subscriptions => "subscriptions",
      HawkEx.CSV.Formatters.AuditLogs => "audit_logs"
    }

    case Map.get(built_in, formatter) do
      nil ->
        formatter |> to_string() |> String.replace("Elixir.", "")

      key ->
        key
    end
  end

  defp extract_account_id(%{id: id}), do: id
  defp extract_account_id(id) when is_binary(id), do: id
end
