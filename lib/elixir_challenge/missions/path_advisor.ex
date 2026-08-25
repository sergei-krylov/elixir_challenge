defmodule ElixirChallenge.Missions.PathAdvisor do
  @moduledoc """
  Flags flight path steps that cannot physically follow the ones before them,
  such as launching from a body the ship never landed on.

  A path is only ever checked against itself, never against an assumed starting
  point. Advisory only: the fuel for such a path is still well defined, and
  still calculated.
  """

  alias ElixirChallenge.Missions.Mission
  alias ElixirChallenge.Missions.Planet
  alias ElixirChallenge.Missions.Step

  @doc """
  Returns a map of step index to warning message.

  The first complete step decides where the mission starts, so no path is wrong
  for beginning where it does. Unfinished steps neither warn nor move the ship.
  """
  @spec warnings(Mission.t()) :: %{non_neg_integer() => String.t()}
  def warnings(%Mission{steps: steps}) do
    {_location, warnings} =
      steps
      |> Enum.with_index()
      |> Enum.reduce({:start, %{}}, fn {step, index}, {location, warnings} ->
        if Step.complete?(step) do
          {next_location, message} = advise(step, location)

          {next_location, put_warning(warnings, index, message)}
        else
          {location, warnings}
        end
      end)

    warnings
  end

  defp advise(%Step{action: :launch}, :start), do: {:in_flight, nil}

  defp advise(%Step{action: :land, planet: planet}, :start), do: {planet, nil}

  defp advise(%Step{action: :launch}, :in_flight) do
    {:in_flight, "the ship is already in flight"}
  end

  defp advise(%Step{action: :launch, planet: planet}, location) when location != planet do
    {:in_flight, "the ship is on #{Planet.name(location)}, not #{Planet.name(planet)}"}
  end

  defp advise(%Step{action: :launch}, _location), do: {:in_flight, nil}

  defp advise(%Step{action: :land, planet: planet}, :in_flight), do: {planet, nil}

  defp advise(%Step{action: :land, planet: planet}, location) do
    {planet, "the ship is already on the ground on #{Planet.name(location)}"}
  end

  defp put_warning(warnings, _index, nil), do: warnings
  defp put_warning(warnings, index, message), do: Map.put(warnings, index, message)
end
