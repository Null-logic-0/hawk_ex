if Code.ensure_loaded?(ExAws) do
  defmodule HawkEx.CSV.Storage.S3 do
    @behaviour HawkEx.CSV.Storage

    @moduledoc """
    S3 storage adapter for CSV exports.

    Requires `ex_aws` and `ex_aws_s3` in your dependencies:

        {:ex_aws, "~> 2.5"},
        {:ex_aws_s3, "~> 2.5"},

    ## Options

      * `:bucket` — S3 bucket name (required)
      * `:prefix` — key prefix inside the bucket (default: `"exports/"`)

    ## Configuration

        config :hawk_ex,
          csv_storage: {HawkEx.CSV.Storage.S3,
            bucket: "my-app-exports",
            prefix: "exports/"}

    ## AWS credentials

    Credentials are read from the standard AWS credential chain —
    environment variables, IAM roles, or `~/.aws/credentials`.
    Configure them via `ex_aws` directly, not through HAWK_EX.
    """

    @default_prefix "exports/"

    @impl true
    def write(filename, content, opts) do
      bucket = Keyword.fetch!(opts, :bucket)
      prefix = Keyword.get(opts, :prefix, @default_prefix)
      key = prefix <> filename

      case ExAws.S3.put_object(bucket, key, content)
           |> ExAws.request() do
        {:ok, _} ->
          {:ok, "s3://#{bucket}/#{key}"}

        {:error, reason} ->
          {:error, {:s3_write_failed, reason, key}}
      end
    end

    @impl true
    def read(path, opts) do
      bucket = Keyword.fetch!(opts, :bucket)
      prefix = Keyword.get(opts, :prefix, @default_prefix)

      key = extract_key(path, bucket, prefix)

      case ExAws.S3.get_object(bucket, key)
           |> ExAws.request() do
        {:ok, %{body: content}} ->
          {:ok, content}

        {:error, reason} ->
          {:error, {:s3_read_failed, reason, key}}
      end
    end

    @impl true
    def delete(path, opts) do
      bucket = Keyword.fetch!(opts, :bucket)
      prefix = Keyword.get(opts, :prefix, @default_prefix)
      key = extract_key(path, bucket, prefix)

      case ExAws.S3.delete_object(bucket, key)
           |> ExAws.request() do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, {:s3_delete_failed, reason, key}}
      end
    end

    # ----Private------------------------------------------------------------

    # Extracts the S3 key from a stored path like "s3://bucket/exports/file.csv"
    defp extract_key("s3://" <> rest, _bucket, _prefix) do
      rest
      |> String.split("/", parts: 2)
      |> List.last()
    end

    # Fallback: treat path as key directly
    defp extract_key(path, _bucket, _prefix), do: path
  end
end
