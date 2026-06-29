defmodule HawkEx.Billing.PlanFeature do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
    The join between a Plan and a Feature, with the specific value
    granted to subscribers of that plan.

    Examples:
      Plan: Pro  | Feature: api_calls   | Value: "1000"
      Plan: Free | Feature: api_calls   | Value: "100"
      Plan: Pro  | Feature: export_csv  | Value: "true"
      Plan: Free | Feature: export_csv  | Value: "false"

    ## Future: value_type
    A `value_type` column will be added in a future migration to make
    each row self-describing ("limit", "boolean", "unlimited").
    Until then, feature_type on the Feature record drives interpretation.
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "hawk_ex_plan_features" do
    belongs_to(:plan, HawkEx.Billing.Plan)
    belongs_to(:feature, HawkEx.Billing.Feature)
    field(:value, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(plan_feature, attrs) do
    plan_feature
    |> cast(attrs, [:plan_id, :feature_id, :value])
    |> validate_required([:plan_id, :feature_id, :value])
    |> unique_constraint([:plan_id, :feature_id],
      message: "feature already defined for this plan"
    )
  end
end
