defmodule ElixirChallenge.Missions.FuelCalculator do
  @moduledoc """
  Fuel required to fly a flight path.

  A step costs `mass * gravity * coefficient - constant`, rounded down, and
  that fuel is itself mass that needs fuel, until the increment reaches zero.

  Steps are costed from the last to the first. The ship has to carry the fuel
  for every later step, so that fuel counts as payload for the earlier ones —
  costing a path forwards gives a different, wrong total.
  """

  alias ElixirChallenge.Missions.Calculation
  alias ElixirChallenge.Missions.Mission
  alias ElixirChallenge.Missions.Planet
  alias ElixirChallenge.Missions.Step

  @formulas %{launch: {0.042, 33}, land: {0.033, 42}}

  @doc """
  Costs a mission's flight path.

  Steps that are not yet fully specified are skipped and counted in
  `:ignored_steps`, so the total stays live while a path is being edited. A
  mission without a usable mass costs nothing.

      iex> alias ElixirChallenge.Missions
      iex> mission = Missions.build(28_801, launch: :earth, land: :moon, launch: :moon, land: :earth)
      iex> ElixirChallenge.Missions.FuelCalculator.calculate(mission).total
      51_898
  """
  @spec calculate(Mission.t()) :: Calculation.t()
  def calculate(%Mission{mass: mass, steps: steps})
      when is_integer(mass) and mass > 0 do
    flyable = Enum.filter(steps, &Step.complete?/1)

    {results, total} =
      flyable
      |> Enum.reverse()
      |> Enum.map_reduce(0, fn step, carried ->
        payload = mass + carried
        fuel = step_fuel(payload, step.action, step.planet)

        row = %{
          step: step,
          fuel: fuel,
          carried_fuel: carried,
          payload: payload,
          total_mass: payload + fuel
        }

        {row, carried + fuel}
      end)

    %Calculation{
      total: total,
      steps: Enum.reverse(results),
      ignored_steps: length(steps) - length(flyable)
    }
  end

  def calculate(%Mission{steps: steps}) do
    %Calculation{ignored_steps: length(steps)}
  end

  @doc """
  Fuel for a single step, including the fuel needed to carry that fuel.

  Returns 0 when the formula yields nothing positive, which happens for light
  craft on low gravity bodies.

      iex> ElixirChallenge.Missions.FuelCalculator.step_fuel(28_801, :land, :earth)
      13_447
  """
  @spec step_fuel(pos_integer(), Step.action(), Planet.id()) :: non_neg_integer()
  def step_fuel(mass, action, planet) do
    {coefficient, constant} = Map.fetch!(@formulas, action)

    accumulate(mass, Planet.gravity(planet), coefficient, constant, 0)
  end

  @doc """
  A single application of the formula, without the fuel-for-fuel loop.

      iex> ElixirChallenge.Missions.FuelCalculator.increment(28_801, :land, :earth)
      9278
  """
  @spec increment(pos_integer(), Step.action(), Planet.id()) :: integer()
  def increment(mass, action, planet) do
    {coefficient, constant} = Map.fetch!(@formulas, action)

    floor(mass * Planet.gravity(planet) * coefficient - constant)
  end

  defp accumulate(mass, gravity, coefficient, constant, total) do
    case floor(mass * gravity * coefficient - constant) do
      increment when increment <= 0 -> total
      increment -> accumulate(increment, gravity, coefficient, constant, total + increment)
    end
  end
end
