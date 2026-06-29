defmodule HawkEx.CSV.Formatter do
  @moduledoc """
  	Behaviour for CSV formatters.

    Implement this to export any resource through HAWK_EX's CSV pipeline.

    ## Example

        defmodule MyApp.CSV.Formatters.Users do
          @behaviour HawkEx.CSV.Formatter

          import Ecto.Query
          alias MyApp.Accounts.User

          @impl true
          def headers, do: ["id", "email", "name", "inserted_at"]

          @impl true
          def to_row(%User{} = user) do
            [user.id, user.email, user.name, to_string(user.inserted_at)]
          end

          @impl true
          def query(account_id) do
            from u in User, where: u.organization_id == ^account_id
          end
        end

    Then use it:

        HawkEx.CSV.export(account, MyApp.CSV.Formatters.Users)
  """

  @doc "Column headers for the CSV file."
  @callback headers() :: [String.t()]

  @doc "Converts a single struct into a list of string values."
  @callback to_row(struct()) :: [String.t()]

  @doc """
  Returns an Ecto query scoped to the given account_id.
  The query result is passed row by row to `to_row/1`.
  """
  @callback query(account_id :: binary()) :: Ecto.Query.t()
end
