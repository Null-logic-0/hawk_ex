if Code.ensure_loaded?(Oban.Worker) do
  defmodule HawkEx.CSV.ExportWorker do
    use Oban.Worker,
      queue: :hawk_ex_exports,
      max_attempts: 3

    alias HawkEx.{Config, Events}
    alias HawkEx.CSV.{Export, Exporter}

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"export_id" => export_id, "formatter" => formatter_key}}) do
      export = Config.repo().get!(Export, export_id)
      formatter = resolve_formatter(formatter_key)

      with {:ok, csv, row_count} <- Exporter.generate(export.account_id, formatter),
           {:ok, file_path} <- write_export_file(export, csv) do
        export
        |> Export.changeset(%{
          status: "completed",
          file_path: file_path,
          row_count: row_count
        })
        |> Config.repo().update!()

        Events.emit("csv.export.completed", %{
          account_id: export.account_id,
          export_id: export.id,
          export_type: export.export_type,
          row_count: row_count,
          file_path: file_path
        })

        :ok
      else
        {:error, reason} ->
          export
          |> Export.changeset(%{
            status: "failed",
            error_message: inspect(reason)
          })
          |> Config.repo().update!()

          Events.emit("csv.export.failed", %{
            account_id: export.account_id,
            export_id: export.id,
            export_type: export.export_type,
            error: inspect(reason)
          })

          {:error, reason}
      end
    end

    defp write_export_file(export, csv) do
      filename = "#{export.export_type}_#{export.id}.csv"

      case HawkEx.CSV.Storage.write(filename, csv) do
        {:ok, path} -> {:ok, path}
        {:error, reason} -> {:error, reason}
      end
    end

    defp resolve_formatter(key) do
      built_in = %{
        "subscriptions" => HawkEx.CSV.Formatters.Subscriptions,
        "audit_logs" => HawkEx.CSV.Formatters.AuditLogs
      }

      case Map.get(built_in, key) do
        nil -> String.to_existing_atom("Elixir.#{key}")
        formatter -> formatter
      end
    end
  end
end
