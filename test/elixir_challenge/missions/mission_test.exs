defmodule ElixirChallenge.Missions.MissionTest do
  use ExUnit.Case, async: true

  import ElixirChallenge.ChangesetHelpers

  alias ElixirChallenge.Missions
  alias ElixirChallenge.Missions.Mission
  alias ElixirChallenge.Missions.Step

  # The shape LiveView sends for a nested `inputs_for` list.
  defp step_params(path) do
    path
    |> Enum.with_index()
    |> Map.new(fn {{action, planet}, index} ->
      {to_string(index), %{"action" => to_string(action), "planet" => to_string(planet)}}
    end)
  end

  describe "changeset/2 mass validation" do
    test "accepts a positive whole number" do
      changeset = Mission.changeset(%Mission{}, %{"mass" => "28801"})

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :mass) == 28_801
    end

    test "requires a mass" do
      assert %{mass: ["is required"]} = errors_on(Mission.changeset(%Mission{}, %{"mass" => ""}))
    end

    test "rejects zero and negative masses" do
      assert %{mass: ["must be greater than 0 kg"]} =
               errors_on(Mission.changeset(%Mission{}, %{"mass" => "0"}))

      assert %{mass: ["must be greater than 0 kg"]} =
               errors_on(Mission.changeset(%Mission{}, %{"mass" => "-5"}))
    end

    test "rejects decimals and other non-integers" do
      for value <- ["28801.5", "abc", "1e5"] do
        assert %{mass: ["must be a whole number of kilograms"]} =
                 errors_on(Mission.changeset(%Mission{}, %{"mass" => value})),
               "expected #{inspect(value)} to be rejected"
      end
    end

    # A mass past the bound would overflow float conversion in the formulas.
    test "rejects a mass beyond the supported bound" do
      over = Integer.to_string(Mission.max_mass() + 1)

      assert %{mass: [message]} = errors_on(Mission.changeset(%Mission{}, %{"mass" => over}))
      assert message =~ "at most"
    end

    test "accepts a mass exactly at the bound" do
      at = Integer.to_string(Mission.max_mass())

      assert Mission.changeset(%Mission{}, %{"mass" => at}).valid?
    end
  end

  describe "changeset/2 flight path validation" do
    test "casts an indexed map of steps, preserving order" do
      params = %{
        "mass" => "28801",
        "steps" => step_params(launch: :earth, land: :moon, launch: :moon, land: :earth)
      }

      changeset = Mission.changeset(%Mission{}, params)
      assert changeset.valid?

      assert ["Launch - Earth", "Land - Moon", "Launch - Moon", "Land - Earth"] =
               changeset
               |> Ecto.Changeset.apply_changes()
               |> Map.fetch!(:steps)
               |> Enum.map(&Step.describe/1)
    end

    test "an empty flight path is valid" do
      assert Mission.changeset(%Mission{}, %{"mass" => "100", "steps" => %{}}).valid?
    end

    test "surfaces errors from an unfinished step, positioned in the list" do
      params = %{
        "mass" => "100",
        "steps" => %{
          "0" => %{"action" => "launch", "planet" => "earth"},
          "1" => %{"action" => "land", "planet" => ""}
        }
      }

      changeset = Mission.changeset(%Mission{}, params)

      refute changeset.valid?
      assert %{steps: [%{}, %{planet: ["must be selected"]}]} = errors_on(changeset)
    end

    test "rejects a path longer than the supported maximum" do
      path = List.duplicate({:launch, :earth}, Mission.max_steps() + 1)
      changeset = Mission.changeset(%Mission{}, %{"mass" => "100", "steps" => step_params(path)})

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :steps)
    end

    test "replaces the existing path rather than merging into it" do
      existing = Missions.build(28_801, launch: :earth, land: :moon)
      params = %{"mass" => "500", "steps" => step_params(land: :mars)}

      assert ["Land - Mars"] =
               existing
               |> Mission.changeset(params)
               |> Ecto.Changeset.apply_changes()
               |> Map.fetch!(:steps)
               |> Enum.map(&Step.describe/1)
    end
  end

  describe "add_step/2" do
    test "launches from the body the ship is parked on" do
      mission = Missions.build(100, launch: :earth, land: :moon)

      assert ["Launch - Earth", "Land - Moon", "Launch - Moon"] =
               mission |> Mission.add_step() |> describe_steps()
    end

    test "starts an empty path on Earth" do
      assert ["Launch - Earth"] = %Mission{} |> Mission.add_step() |> describe_steps()
    end

    test "proposes a landing when the ship is already in flight" do
      mission = Missions.build(100, launch: :earth)

      assert ["Launch - Earth", "Land - ?"] = mission |> Mission.add_step() |> describe_steps()
    end

    test "appends an explicitly given step" do
      assert ["Land - Mars"] =
               %Mission{}
               |> Mission.add_step(%Step{action: :land, planet: :mars})
               |> describe_steps()
    end

    test "refuses to grow the path beyond the maximum" do
      full = Missions.build(100, List.duplicate({:launch, :earth}, Mission.max_steps()))

      refute Mission.can_add_step?(full)
      assert length(Mission.add_step(full).steps) == Mission.max_steps()
    end
  end

  describe "remove_step/2" do
    test "removes the step at the given index" do
      mission = Missions.build(100, launch: :earth, land: :moon, launch: :moon)

      assert ["Launch - Earth", "Launch - Moon"] =
               mission |> Mission.remove_step(1) |> describe_steps()
    end

    test "ignores an out of range index" do
      mission = Missions.build(100, launch: :earth)

      assert ["Launch - Earth"] = mission |> Mission.remove_step(9) |> describe_steps()
      assert ["Launch - Earth"] = mission |> Mission.remove_step(-1) |> describe_steps()
    end
  end

  describe "move_step/3" do
    setup do
      %{mission: Missions.build(100, launch: :earth, land: :moon, launch: :moon)}
    end

    test "swaps with the step above", %{mission: mission} do
      assert ["Land - Moon", "Launch - Earth", "Launch - Moon"] =
               mission |> Mission.move_step(1, :up) |> describe_steps()
    end

    test "swaps with the step below", %{mission: mission} do
      assert ["Launch - Earth", "Launch - Moon", "Land - Moon"] =
               mission |> Mission.move_step(1, :down) |> describe_steps()
    end

    test "moving the first step up is a no-op", %{mission: mission} do
      assert describe_steps(Mission.move_step(mission, 0, :up)) == describe_steps(mission)
    end

    test "moving the last step down is a no-op", %{mission: mission} do
      assert describe_steps(Mission.move_step(mission, 2, :down)) == describe_steps(mission)
    end
  end

  describe "current_body/1" do
    test "an empty path starts on Earth" do
      assert Mission.current_body(%Mission{}) == :earth
    end

    test "after landing, the ship is on that body" do
      assert Mission.current_body(Missions.build(100, launch: :earth, land: :moon)) == :moon
    end

    test "after launching, the ship is in flight and on no body" do
      assert Mission.current_body(Missions.build(100, launch: :earth)) == nil
    end

    test "unfinished steps are ignored" do
      mission = %Mission{steps: [%Step{action: :land, planet: :mars}, %Step{action: :land}]}

      assert Mission.current_body(mission) == :mars
    end
  end

  defp describe_steps(%Mission{steps: steps}), do: Enum.map(steps, &Step.describe/1)
end
