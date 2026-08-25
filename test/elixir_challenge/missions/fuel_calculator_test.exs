defmodule ElixirChallenge.Missions.FuelCalculatorTest do
  use ExUnit.Case, async: true

  alias ElixirChallenge.Missions
  alias ElixirChallenge.Missions.Calculation
  alias ElixirChallenge.Missions.FuelCalculator
  alias ElixirChallenge.Missions.Mission
  alias ElixirChallenge.Missions.Step

  doctest FuelCalculator

  describe "increment/3" do
    test "applies the landing formula from the brief" do
      assert FuelCalculator.increment(28_801, :land, :earth) == 9278
    end

    test "applies the launch formula from the brief" do
      assert FuelCalculator.increment(28_801, :launch, :earth) == 11_829
    end

    test "rounds down rather than to nearest" do
      raw = 28_801 * 9.807 * 0.033 - 42

      assert raw > 9278.5
      assert FuelCalculator.increment(28_801, :land, :earth) == 9278
    end

    test "goes negative for craft too light to need fuel" do
      assert FuelCalculator.increment(100, :launch, :moon) < 0
    end
  end

  describe "step_fuel/3" do
    # 9278 -> 2960 -> 915 -> 254 -> 40, summing to 13_447.
    test "adds fuel for the fuel until the increment runs out" do
      assert FuelCalculator.step_fuel(28_801, :land, :earth) == 13_447
    end

    test "the increments follow the chain in the brief" do
      chain =
        Stream.iterate(28_801, &FuelCalculator.increment(&1, :land, :earth))
        |> Stream.drop(1)
        |> Enum.take_while(&(&1 > 0))

      assert chain == [9278, 2960, 915, 254, 40]
      assert Enum.sum(chain) == 13_447
    end

    test "clamps to zero when the first increment is not positive" do
      assert FuelCalculator.step_fuel(400, :launch, :moon) == 0
      assert FuelCalculator.step_fuel(700, :land, :moon) == 0
    end
  end

  describe "calculate/1 against the example scenarios" do
    test "Apollo 11" do
      mission =
        Missions.build(28_801, launch: :earth, land: :moon, launch: :moon, land: :earth)

      assert FuelCalculator.calculate(mission).total == 51_898
    end

    test "Mars mission" do
      mission =
        Missions.build(14_606, launch: :earth, land: :mars, launch: :mars, land: :earth)

      assert FuelCalculator.calculate(mission).total == 33_388
    end

    test "passenger ship" do
      mission =
        Missions.build(75_432,
          launch: :earth,
          land: :moon,
          launch: :moon,
          land: :mars,
          launch: :mars,
          land: :earth
        )

      assert FuelCalculator.calculate(mission).total == 212_161
    end

    test "every preset matches its documented total" do
      totals = %{apollo_11: 51_898, mars_mission: 33_388, passenger_ship: 212_161}

      for %{id: id} <- Missions.presets() do
        assert {:ok, mission} = Missions.fetch_preset(id)
        assert FuelCalculator.calculate(mission).total == totals[id]
      end
    end
  end

  describe "calculate/1 ordering" do
    # The fuel for later steps is payload for the earlier ones, so costing a
    # path forwards under-counts. This pins the direction.
    test "a reversed path gives a different total" do
      forwards = Missions.build(28_801, launch: :earth, land: :moon)
      backwards = Missions.build(28_801, land: :moon, launch: :earth)

      refute FuelCalculator.calculate(forwards).total ==
               FuelCalculator.calculate(backwards).total
    end

    test "each step is costed against the equipment plus the fuel after it" do
      mission = Missions.build(28_801, launch: :earth, land: :earth)
      %Calculation{steps: [first, second], total: total} = FuelCalculator.calculate(mission)

      assert second.carried_fuel == 0
      assert second.payload == 28_801
      assert second.fuel == FuelCalculator.step_fuel(28_801, :land, :earth)

      assert first.carried_fuel == second.fuel
      assert first.payload == 28_801 + second.fuel
      assert first.fuel == FuelCalculator.step_fuel(first.payload, :launch, :earth)

      assert total == first.fuel + second.fuel
    end

    test "total mass is everything the step moves, including its own fuel" do
      %Calculation{steps: [row]} =
        FuelCalculator.calculate(Missions.build(10_000, launch: :earth))

      assert row.carried_fuel == 0
      assert row.payload == 10_000
      assert row.fuel == 6675
      assert row.total_mass == 16_675
    end

    test "a step's total mass is the payload of the step before it" do
      mission = Missions.build(10_000, launch: :earth, land: :earth)
      %Calculation{steps: [launch, land]} = FuelCalculator.calculate(mission)

      assert land.total_mass == launch.payload
      assert launch.total_mass == 10_000 + launch.fuel + land.fuel
    end

    test "carried fuel is always the payload minus the spacecraft mass" do
      mission =
        Missions.build(75_432,
          launch: :earth,
          land: :moon,
          launch: :moon,
          land: :mars,
          launch: :mars,
          land: :earth
        )

      %Calculation{steps: [first | _] = steps, total: total} = FuelCalculator.calculate(mission)

      for row <- steps do
        assert row.carried_fuel == row.payload - 75_432
      end

      assert first.carried_fuel + first.fuel == total
    end

    test "the breakdown stays in flight path order" do
      mission = Missions.build(28_801, launch: :earth, land: :moon, launch: :moon)

      assert ["Launch - Earth", "Land - Moon", "Launch - Moon"] =
               mission
               |> FuelCalculator.calculate()
               |> Map.fetch!(:steps)
               |> Enum.map(&Step.describe(&1.step))
    end
  end

  describe "calculate/1 with paths that are not ready" do
    test "an empty path costs nothing" do
      assert %Calculation{total: 0, steps: [], ignored_steps: 0} =
               FuelCalculator.calculate(Missions.build(28_801))
    end

    test "skips unfinished steps and counts them" do
      mission = %Mission{
        mass: 28_801,
        steps: [
          %Step{action: :land, planet: :earth},
          %Step{action: :launch, planet: nil}
        ]
      }

      calculation = FuelCalculator.calculate(mission)

      assert calculation.total == 13_447
      assert calculation.ignored_steps == 1
      assert length(calculation.steps) == 1
    end

    test "costs nothing without a usable mass" do
      for mass <- [nil, 0, -100] do
        calculation = FuelCalculator.calculate(%Mission{mass: mass, steps: []})

        assert %Calculation{total: 0, steps: []} = calculation
      end
    end

    test "a missing mass still reports the steps it could not cost" do
      mission = Missions.build(nil, launch: :earth, land: :moon)

      assert %Calculation{total: 0, ignored_steps: 2} = FuelCalculator.calculate(mission)
    end
  end
end
