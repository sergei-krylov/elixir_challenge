defmodule ElixirChallenge.Missions.StepTest do
  use ExUnit.Case, async: true

  import ElixirChallenge.ChangesetHelpers

  alias ElixirChallenge.Missions.Step

  doctest Step

  describe "actions/0 and action_options/0" do
    test "supports exactly launch and land" do
      assert Step.actions() == [:launch, :land]
      assert Step.action_options() == [{"Launch", :launch}, {"Land", :land}]
    end
  end

  describe "describe/1" do
    test "renders the 'Launch - Earth' form used by the flight path UI" do
      assert Step.describe(%Step{action: :launch, planet: :earth}) == "Launch - Earth"
      assert Step.describe(%Step{action: :land, planet: :mars}) == "Land - Mars"
    end

    test "falls back to a placeholder for an unfinished step" do
      assert Step.describe(%Step{action: :launch, planet: nil}) == "Launch - ?"
      assert Step.describe(%Step{action: nil, planet: nil}) == "? - ?"
    end
  end

  describe "complete?/1" do
    test "requires both an action and a body" do
      assert Step.complete?(%Step{action: :land, planet: :moon})
      refute Step.complete?(%Step{action: :land, planet: nil})
      refute Step.complete?(%Step{action: nil, planet: :moon})
    end
  end

  describe "changeset/2" do
    test "accepts a complete step" do
      changeset = Step.changeset(%Step{}, %{"action" => "land", "planet" => "moon"})

      assert changeset.valid?
      assert %Step{action: :land, planet: :moon} = Ecto.Changeset.apply_changes(changeset)
    end

    test "requires a body to be selected" do
      changeset = Step.changeset(%Step{}, %{"action" => "launch", "planet" => ""})

      refute changeset.valid?
      assert %{planet: ["must be selected"]} = errors_on(changeset)
    end

    test "rejects a body outside the supported list" do
      changeset = Step.changeset(%Step{}, %{"action" => "launch", "planet" => "pluto"})

      refute changeset.valid?
      assert %{planet: ["is invalid"]} = errors_on(changeset)
    end

    test "rejects an action outside launch and land" do
      changeset = Step.changeset(%Step{}, %{"action" => "orbit", "planet" => "earth"})

      refute changeset.valid?
      assert %{action: ["is invalid"]} = errors_on(changeset)
    end
  end
end
