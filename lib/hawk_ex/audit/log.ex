defmodule HawkEx.Audit.Log do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  A single audit log entry recording a business action.

  Audit logs are append-only. Never update or delete them.
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "hawk_ex_audit_logs" do
    field(:actor_id, :binary_id)
    field(:actor_type, :string)

    field(:action, :string)

    field(:resource_id, :binary_id)
    field(:resource_type, :string)

    field(:metadata, :map, default: %{})

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :actor_id,
      :actor_type,
      :action,
      :resource_id,
      :resource_type,
      :metadata
    ])
    |> validate_required([:action])
  end
end
