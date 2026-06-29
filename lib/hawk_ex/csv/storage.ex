defmodule HawkEx.CSV.Storage do
  @moduledoc """
  Behaviour for CSV export storage adapters.

  HAWK_EX ships two adapters:

    * `HawkEx.CSV.Storage.Local` — writes to local disk (default)
    * `HawkEx.CSV.Storage.S3`   — writes to S3 (requires ex_aws)

  ## Configuration

      # Local disk (default)
      config :hawk_ex,
        csv_storage: {HawkEx.CSV.Storage.Local, path: "priv/exports"}

      # S3
      config :hawk_ex,
        csv_storage: {HawkEx.CSV.Storage.S3,
          bucket: "my-bucket",
          prefix: "exports/"}

  ## Custom adapters

  Implement this behaviour to support other storage backends:

      defmodule MyApp.CSV.GCSStorage do
        @behaviour HawkEx.CSV.Storage

        @impl true
        def write(filename, content, opts) do
          bucket = Keyword.fetch!(opts, :bucket)
          # write to GCS
          {:ok, "gs://\#{bucket}/\#{filename}"}
        end

        @impl true
        def read(path, opts) do
          # read from GCS
          {:ok, content}
        end

        @impl true
        def delete(path, opts) do
          # delete from GCS
          :ok
        end
      end

  Then configure it:

      config :hawk_ex,
        csv_storage: {MyApp.CSV.GCSStorage, bucket: "my-bucket"}
  """

  @doc """
  Writes CSV content to storage.
  Returns {:ok, path} where path is the identifier used to read it later.
  """
  @callback write(filename :: String.t(), content :: String.t(), opts :: keyword()) ::
              {:ok, path :: String.t()} | {:error, reason :: term()}

  @doc """
  Reads CSV content from storage.
  Returns {:ok, content} or {:error, reason}.
  """
  @callback read(path :: String.t(), opts :: keyword()) ::
              {:ok, content :: String.t()} | {:error, reason :: term()}

  @doc """
  Deletes a stored export.
  Returns :ok or {:error, reason}.
  """
  @callback delete(path :: String.t(), opts :: keyword()) ::
              :ok | {:error, reason :: term()}

  # ---Dispatch helpers-------------------------------------------------------------

  @doc "Writes using the configured adapter."
  def write(filename, content) do
    {adapter, opts} = HawkEx.Config.csv_storage()
    adapter.write(filename, content, opts)
  end

  @doc "Reads using the configured adapter."
  def read(path) do
    {adapter, opts} = HawkEx.Config.csv_storage()
    adapter.read(path, opts)
  end

  @doc "Deletes using the configured adapter."
  def delete(path) do
    {adapter, opts} = HawkEx.Config.csv_storage()
    adapter.delete(path, opts)
  end
end
