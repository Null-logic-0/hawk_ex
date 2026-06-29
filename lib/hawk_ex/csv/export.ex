defmodule HawkEx.CSV.Export do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Represents a CSV export job and its result.

  Exports are created before generation begins (status: pending)
  and updated when complete (status: completed) or failed.

  The `file_path` column stores the path to the CSV file on the storage backend.
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ~w(pending completed failed)

  schema "hawk_ex_csv_exports" do
    field(:account_id, :binary_id)
    field(:export_type, :string)
    field(:status, :string, default: "pending")
    field(:row_count, :integer)
    field(:error_message, :string)

    # Stores the path to the CSV file on the storage backend.
    field(:file_path, :string)

    # Links to oban_jobs row when exported asynchronously. Nullable.
    field(:oban_job_id, :integer)

    timestamps(type: :utc_datetime)
  end

  def changeset(export, attrs) do
    export
    |> cast(attrs, [
      :account_id,
      :export_type,
      :status,
      :row_count,
      :error_message,
      :file_path,
      :oban_job_id
    ])
    |> validate_required([:account_id, :export_type])
    |> validate_inclusion(:status, @valid_statuses)
  end

  def valid_statuses, do: @valid_statuses
end
