defmodule ElixirChallenge.Missions do
  @moduledoc """
  Mission planning: spacecraft mass, flight paths, and the bodies they visit.

  There is no database — a mission is an embedded schema held in the LiveView
  socket, so this context is pure functions over `Mission` structs and
  changesets. The web layer talks only to this module.
  """

  alias ElixirChallenge.Missions.Calculation
  alias ElixirChallenge.Missions.FuelCalculator
  alias ElixirChallenge.Missions.Mission
  alias ElixirChallenge.Missions.Planet
  alias ElixirChallenge.Missions.Step

  @presets [
    %{
      id: :apollo_11,
      name: "Apollo 11",
      description: "Command and Service Module, Earth to the Moon and back",
      mass: 28_801,
      path: [launch: :earth, land: :moon, launch: :moon, land: :earth]
    },
    %{
      id: :mars_mission,
      name: "Mars Mission",
      description: "A round trip to the surface of Mars",
      mass: 14_606,
      path: [launch: :earth, land: :mars, launch: :mars, land: :earth]
    },
    %{
      id: :passenger_ship,
      name: "Passenger Ship",
      description: "Earth to the Moon, on to Mars, then home",
      mass: 75_432,
      path: [
        launch: :earth,
        land: :moon,
        launch: :moon,
        land: :mars,
        launch: :mars,
        land: :earth
      ]
    }
  ]

  @preset_ids Enum.map(@presets, & &1.id)

  @type preset_id :: :apollo_11 | :mars_mission | :passenger_ship

  @doc """
  Builds a mission from a mass and a keyword list of `{action, body}` legs.

      Missions.build(28_801, launch: :earth, land: :moon)

  """
  @spec build(pos_integer() | nil, keyword(Planet.id())) :: Mission.t()
  def build(mass \\ nil, path \\ []) do
    steps = Enum.map(path, fn {action, planet} -> %Step{action: action, planet: planet} end)

    %Mission{mass: mass, steps: steps}
  end

  @doc """
  An empty mission: no mass, no steps.
  """
  @spec new_mission() :: Mission.t()
  def new_mission, do: %Mission{}

  @doc """
  Builds a changeset for tracking mission changes in a form.
  """
  @spec change_mission(Mission.t(), map()) :: Ecto.Changeset.t()
  def change_mission(%Mission{} = mission, params \\ %{}) do
    Mission.changeset(mission, params)
  end

  @doc """
  Applies form params to a mission and returns `{mission, changeset}`.

  Changes are applied even when invalid, so a half-typed mass never discards
  the flight path.
  """
  @spec apply_params(Mission.t(), map()) :: {Mission.t(), Ecto.Changeset.t()}
  def apply_params(%Mission{} = mission, params) do
    changeset = change_mission(mission, params)

    {Ecto.Changeset.apply_changes(changeset), changeset}
  end

  @doc """
  Costs a mission's flight path, returning the total fuel and the breakdown.
  """
  @spec calculate(Mission.t()) :: Calculation.t()
  defdelegate calculate(mission), to: FuelCalculator

  @doc """
  Appends a step to the flight path.
  """
  @spec add_step(Mission.t(), Step.t() | nil) :: Mission.t()
  defdelegate add_step(mission, step \\ nil), to: Mission

  @doc """
  Whether the flight path has room for another step.
  """
  @spec can_add_step?(Mission.t()) :: boolean()
  defdelegate can_add_step?(mission), to: Mission

  @doc """
  Removes the step at `index`.
  """
  @spec remove_step(Mission.t(), integer()) :: Mission.t()
  defdelegate remove_step(mission, index), to: Mission

  @doc """
  Swaps the step at `index` with its neighbour above or below.
  """
  @spec move_step(Mission.t(), integer(), :up | :down) :: Mission.t()
  defdelegate move_step(mission, index, direction), to: Mission

  @doc """
  The bodies a mission can visit.
  """
  @spec planets() :: [Planet.t()]
  defdelegate planets, to: Planet, as: :all

  @doc """
  Body options for a select input.
  """
  @spec planet_options() :: [{String.t(), Planet.id()}]
  defdelegate planet_options, to: Planet, as: :options

  @doc """
  Action options for a select input.
  """
  @spec action_options() :: [{String.t(), Step.action()}]
  defdelegate action_options, to: Step

  @doc """
  The example missions from the brief, ready to load into the UI.
  """
  @spec presets() :: [map()]
  def presets, do: @presets

  @doc """
  Looks up a preset by id and returns it as a mission.

  Accepts the string ids that arrive from the UI.
  """
  @spec fetch_preset(preset_id() | String.t()) :: {:ok, Mission.t()} | :error
  def fetch_preset(id) when is_binary(id) do
    case Enum.find(@preset_ids, &(Atom.to_string(&1) == id)) do
      nil -> :error
      preset_id -> fetch_preset(preset_id)
    end
  end

  def fetch_preset(id) when is_atom(id) do
    case Enum.find(@presets, &(&1.id == id)) do
      nil -> :error
      preset -> {:ok, build(preset.mass, preset.path)}
    end
  end
end
