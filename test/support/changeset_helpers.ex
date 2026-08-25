defmodule ElixirChallenge.ChangesetHelpers do
  @moduledoc """
  Helpers for asserting on changesets.

  Phoenix normally puts `errors_on/1` in `DataCase`, which this app has no
  repo for.
  """

  @doc """
  Renders a changeset's errors as a map of field to interpolated messages.

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
