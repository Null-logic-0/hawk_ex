defmodule HawkEx.CSV.Exporter do
  @moduledoc false

  alias HawkEx.Config

  @built_in %{
    "subscriptions" => HawkEx.CSV.Formatters.Subscriptions,
    "audit_logs" => HawkEx.CSV.Formatters.AuditLogs
  }

  @doc """
  Generates a CSV string for the given account and formatter.

  Accepts a built-in atom (:subscriptions, :audit_logs) or any
  module implementing HawkEx.CSV.Formatter.

  Returns {:ok, csv_string, row_count} or {:error, reason}.
  """
  def generate(account_id, export_type) when is_atom(export_type) do
    key = to_string(export_type)

    case Map.get(@built_in, key) do
      nil ->
        run(account_id, export_type)

      formatter ->
        run(account_id, formatter)
    end
  end

  def generate(account_id, formatter) when is_atom(formatter) do
    run(account_id, formatter)
  end

  # ---Private-------------------------------------------------------------

  defp run(account_id, formatter) do
    rows = Config.repo().all(formatter.query(account_id))
    headers = formatter.headers()

    csv =
      [headers | Enum.map(rows, &formatter.to_row/1)]
      |> Enum.map(&encode_row/1)
      |> Enum.join("\n")

    {:ok, csv, length(rows)}
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp encode_row(values) do
    values
    |> Enum.map(&escape/1)
    |> Enum.join(",")
  end

  defp escape(nil), do: ""

  defp escape(value) when is_binary(value) do
    if String.contains?(value, [",", "\n", "\r", "\""]) do
      "\"#{String.replace(value, "\"", "\"\"")}\""
    else
      value
    end
  end

  defp escape(value), do: to_string(value)
end
