defmodule HawkEx.CSV.Storage.Local do
  @behaviour HawkEx.CSV.Storage

  @moduledoc """
  Local disk storage adapter for CSV exports.

  ## Options

    * `:path` — directory to write files into. Defaults to `"priv/exports"`.

  ## Configuration

      config :hawk_ex,
        csv_storage: {HawkEx.CSV.Storage.Local, path: "priv/exports"}
  """

  @default_path "priv/exports"

  @impl true
  def write(filename, content, opts) do
    base_path = Keyword.get(opts, :path, @default_path)
    full_path = Path.join(base_path, filename)

    with :ok <- File.mkdir_p(base_path),
         :ok <- File.write(full_path, content) do
      {:ok, full_path}
    else
      {:error, reason} ->
        {:error, {:local_write_failed, reason, full_path}}
    end
  end

  @impl true
  def read(path, _opts) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, {:local_read_failed, reason, path}}
    end
  end

  @impl true
  def delete(path, _opts) do
    case File.rm(path) do
      :ok -> :ok
      {:error, reason} -> {:error, {:local_delete_failed, reason, path}}
    end
  end
end
