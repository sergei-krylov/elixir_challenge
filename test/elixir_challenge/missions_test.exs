defmodule ElixirChallenge.MissionsTest do
  use ExUnit.Case, async: true

  alias ElixirChallenge.Missions
  alias ElixirChallenge.Missions.Mission
  alias ElixirChallenge.Missions.Planet
  alias ElixirChallenge.Missions.Step

  doctest Missions

  describe "build/2" do
    test "turns a keyword path into steps" do
      assert %Mission{
               mass: 28_801,
               steps: [
                 %Step{action: :launch, planet: :earth},
                 %Step{action: :land, planet: :moon}
               ]
             } = Missions.build(28_801, launch: :earth, land: :moon)
    end

    test "defaults to an empty mission" do
      assert %Mission{mass: nil, steps: []} = Missions.build()
    end
  end

  describe "new_mission/0" do
    test "has no mass and no steps" do
      assert %Mission{mass: nil, steps: []} = Missions.new_mission()
    end
  end

  describe "change_mission/2" do
    test "returns a changeset ready for a form" do
      changeset = Missions.change_mission(Missions.new_mission())

      assert %Ecto.Changeset{data: %Mission{}} = changeset
    end
  end

  describe "apply_params/2" do
    test "returns the applied mission and its changeset" do
      params = %{
        "mass" => "28801",
        "steps" => %{"0" => %{"action" => "launch", "planet" => "earth"}}
      }

      {mission, changeset} = Missions.apply_params(Missions.new_mission(), params)

      assert changeset.valid?
      assert %Mission{mass: 28_801, steps: [%Step{action: :launch, planet: :earth}]} = mission
    end

    test "keeps the flight path when the mass is invalid" do
      params = %{
        "mass" => "not a number",
        "steps" => %{"0" => %{"action" => "land", "planet" => "mars"}}
      }

      {mission, changeset} = Missions.apply_params(Missions.new_mission(), params)

      refute changeset.valid?
      assert mission.mass == nil
      assert [%Step{action: :land, planet: :mars}] = mission.steps
    end
  end

  describe "select options" do
    test "delegate to the schemas so the UI has one source of truth" do
      assert Missions.planet_options() == Planet.options()
      assert Missions.action_options() == Step.action_options()
      assert Missions.planets() == Planet.all()
    end
  end

  describe "presets" do
    # Pins the inputs from the brief; FuelCalculatorTest pins their totals.
    test "match the example missions" do
      assert [apollo, mars, passenger] = Missions.presets()

      assert %{id: :apollo_11, mass: 28_801} = apollo
      assert apollo.path == [launch: :earth, land: :moon, launch: :moon, land: :earth]

      assert %{id: :mars_mission, mass: 14_606} = mars
      assert mars.path == [launch: :earth, land: :mars, launch: :mars, land: :earth]

      assert %{id: :passenger_ship, mass: 75_432} = passenger

      assert passenger.path == [
               launch: :earth,
               land: :moon,
               launch: :moon,
               land: :mars,
               launch: :mars,
               land: :earth
             ]
    end

    test "every preset builds a valid mission" do
      for %{id: id} <- Missions.presets() do
        assert {:ok, mission} = Missions.fetch_preset(id)
        assert Missions.change_mission(mission, %{"mass" => to_string(mission.mass)}).valid?
      end
    end

    test "fetch_preset/1 accepts the string ids that arrive from the UI" do
      assert {:ok, mission} = Missions.fetch_preset("apollo_11")
      assert mission.mass == 28_801
    end

    test "fetch_preset/1 returns :error for unknown ids" do
      assert Missions.fetch_preset(:voyager) == :error
      assert Missions.fetch_preset("voyager") == :error
    end

    # Guards against reaching for String.to_existing_atom, which would raise.
    test "fetch_preset/1 does not blow up on arbitrary strings" do
      assert Missions.fetch_preset("../../etc/passwd") == :error
    end
  end
end
