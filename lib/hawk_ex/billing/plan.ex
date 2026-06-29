defmodule HawkEx.Billing.Plan do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Represents a billing plan (e.g. Free,Pro,Enterprise)

  Plans are the top-level unit of billing in hawk_ex.
  They define what features are available and at what limits.
  Plans do not contain pricing - pricing is the payment provider's concern.
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "hawk_ex_plans" do
    # slug: "free", "pro", "enterprise"
    field(:name, :string)

    # "Free", "Pro", "Enterprise"
    field(:display_name, :string)

    field(:trial_days, :integer, default: 0)
    field(:status, :string, default: "active")

    has_many(:plan_features, HawkEx.Billing.PlanFeature)
    has_many(:features, through: [:plan_features, :features])

    timestamps(type: :utc_datetime)
  end

  @requried_fields ~w(name display_name)a
  @optional_fields ~w(trial_days status)a
  @valid_statuses ~w(active archived)

  def changeset(plan, attrs) do
    plan
    |> cast(attrs, @requried_fields ++ @optional_fields)
    |> validate_required(@requried_fields)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_format(:name, ~r/^[a-z0-9_]+$/,
      message: "must be lowercase letters, numbers, and underscores only"
    )
    |> unique_constraint(:name)
  end
end
