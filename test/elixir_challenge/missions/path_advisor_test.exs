defmodule ElixirChallenge.Missions.PathAdvisorTest do
  use ExUnit.Case, async: true

  alias ElixirChallenge.Missions
  alias ElixirChallenge.Missions.Mission
  alias ElixirChallenge.Missions.PathAdvisor
  alias ElixirChallenge.Missions.Step

  describe "warnings/1" do
    test "a coherent round trip warns about nothing" do
      mission = Missions.build(100, launch: :earth, land: :moon, launch: :moon, land: :earth)

      assert PathAdvisor.warnings(mission) == %{}
    end

    test "an empty path warns about nothing" do
      assert PathAdvisor.warnings(%Mission{}) == %{}
    end

    test "flags launching from a body the ship is not on" do
      mission = Missions.build(100, launch: :earth, land: :moon, launch: :mars)

      assert %{2 => message} = PathAdvisor.warnings(mission)
      assert message == "the ship is on Moon, not Mars"
    end

    test "flags launching twice in a row" do
      mission = Missions.build(100, launch: :earth, launch: :earth)

      assert %{1 => "the ship is already in flight"} = PathAdvisor.warnings(mission)
    end

    test "flags landing while already on the ground" do
      mission = Missions.build(100, launch: :earth, land: :moon, land: :mars)

      assert %{2 => "the ship is already on the ground on Moon"} = PathAdvisor.warnings(mission)
    end

    test "a single step is a complete path wherever it happens" do
      for path <- [[launch: :earth], [launch: :mars], [land: :moon], [land: :earth]] do
        assert PathAdvisor.warnings(Missions.build(100, path)) == %{},
               "expected #{inspect(path)} on its own to warn about nothing"
      end
    end

    test "the first step decides where the mission starts" do
      mission = Missions.build(100, launch: :moon, land: :earth, launch: :mars)

      assert PathAdvisor.warnings(mission) == %{2 => "the ship is on Earth, not Mars"}
    end

    test "an unfinished first step does not consume the starting position" do
      mission = %Mission{
        steps: [%Step{action: :launch, planet: nil}, %Step{action: :launch, planet: :mars}]
      }

      assert PathAdvisor.warnings(mission) == %{}
    end

    test "unfinished steps neither warn nor move the ship" do
      mission = %Mission{
        steps: [
          %Step{action: :launch, planet: :earth},
          %Step{action: :land, planet: nil},
          %Step{action: :land, planet: :moon}
        ]
      }

      assert PathAdvisor.warnings(mission) == %{}
    end
  end
end
