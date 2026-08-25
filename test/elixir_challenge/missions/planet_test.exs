defmodule ElixirChallenge.Missions.PlanetTest do
  use ExUnit.Case, async: true

  alias ElixirChallenge.Missions.Planet

  doctest Planet

  describe "all/0" do
    test "returns every supported body as a struct" do
      assert [
               %Planet{id: :earth, name: "Earth", gravity: 9.807},
               %Planet{id: :moon, name: "Moon", gravity: 1.62},
               %Planet{id: :mars, name: "Mars", gravity: 3.711}
             ] = Planet.all()
    end
  end

  describe "ids/0 and options/0" do
    test "stay in sync with all/0" do
      assert Planet.ids() == Enum.map(Planet.all(), & &1.id)
      assert Planet.options() == Enum.map(Planet.all(), &{&1.name, &1.id})
    end
  end

  describe "gravity/1" do
    test "returns the gravity constants given in the brief" do
      assert Planet.gravity(:earth) == 9.807
      assert Planet.gravity(:moon) == 1.62
      assert Planet.gravity(:mars) == 3.711
    end

    # apply/3 avoids a compiler type warning on the out-of-range call.
    test "raises for an unknown body rather than guessing" do
      assert_raise FunctionClauseError, fn -> apply(Planet, :gravity, [:pluto]) end
    end
  end

  describe "name/1" do
    test "returns display names" do
      assert Planet.name(:earth) == "Earth"
      assert Planet.name(:moon) == "Moon"
      assert Planet.name(:mars) == "Mars"
    end
  end

  describe "fetch/1" do
    test "finds a known body" do
      assert {:ok, %Planet{id: :mars, gravity: 3.711}} = Planet.fetch(:mars)
    end

    test "returns :error for an unknown body" do
      assert Planet.fetch(:pluto) == :error
    end
  end
end
