defmodule ElixirChallenge.ChangesetHelpers do
  @moduledoc """
  Helpers for asserting on changesets.

  Phoenix normally puts `errors_on/1` in `DataCase`, but this app has no repo
  and no `DataCase`, so it lives here and is imported where it is needed.
  """

  @doc """
  Renders a changeset's errors as a map of field to interpolated messages.

      iex> errors_on(changeset)
      %{mass: ["must be greater than 0 kg"]}

  Embedded schemas nest, with one entry per embedded item:

      %{steps: [%{planet: ["must be selected"]}, %{}]}
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
