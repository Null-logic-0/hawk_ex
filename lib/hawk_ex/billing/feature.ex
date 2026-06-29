defmodule HawkEx.Billing.Feature do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  	A capability that a Plan can offer, at a specific value or limit.

    Features are defined once and reused across plans. The same
    feature key (e.g. "api_calls") appears in multiple plans with
    different values ("100", "1000", "unlimited").
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "hawk_ex_features" do
    # "export_csv", "api_calls", "team_members"
    field(:key, :string)

    field(:description, :string)

    # "boolean" | "limit"
    field(:feature_type, :string)

    has_many(:plan_features, HawkEx.Billing.PlanFeature)

    timestamps(type: :utc_datetime)
  end

  @valid_types ~w(boolean limit)

  def changeset(feature, attrs) do
    feature
    |> cast(attrs, [:key, :description, :feature_type])
    |> validate_required([:key, :feature_type])
    |> validate_inclusion(:feature_type, @valid_types, message: "must be 'boolean' or 'limit'")
    |> validate_format(:key, ~r/^[a-z0-9_]+$/,
      message: "must be lowercase letters, numbers and underscores only"
    )
    |> unique_constraint(:key)
  end
end
