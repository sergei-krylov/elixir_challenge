defmodule ElixirChallenge.Missions.Step do
  @moduledoc """
  A single leg of a flight path: an action performed at a celestial body,
  such as "launch from Earth".

  Steps are identified by their position in the path, so they carry no
  primary key and the mission embeds them with `on_replace: :delete`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias ElixirChallenge.Missions.Planet

  @actions [:launch, :land]

  @type action :: :launch | :land
  @type t :: %__MODULE__{action: action() | nil, planet: Planet.id() | nil}

  @primary_key false
  embedded_schema do
    field :action, Ecto.Enum, values: @actions, default: :launch
    field :planet, Ecto.Enum, values: Planet.ids()
  end

  @doc """
  Every supported action.
  """
  @spec actions() :: [action()]
  def actions, do: @actions

  @doc """
  Options for a `<.input type="select">`, as `{label, value}` pairs.

      iex> ElixirChallenge.Missions.Step.action_options()
      [{"Launch", :launch}, {"Land", :land}]
  """
  @spec action_options() :: [{String.t(), action()}]
  def action_options, do: Enum.map(@actions, &{label(&1), &1})

  @doc """
  Human readable label for an action.
  """
  @spec label(action()) :: String.t()
  def label(:launch), do: "Launch"
  def label(:land), do: "Land"

  @doc """
  Describes a step as `"Launch - Earth"`, using `"?"` for parts not yet chosen.

      iex> ElixirChallenge.Missions.Step.describe(%ElixirChallenge.Missions.Step{action: :land, planet: :moon})
      "Land - Moon"
  """
  @spec describe(t()) :: String.t()
  def describe(%__MODULE__{action: action, planet: planet}) do
    action_label = if action, do: label(action), else: "?"
    planet_label = if planet, do: Planet.name(planet), else: "?"

    "#{action_label} - #{planet_label}"
  end

  @doc """
  Whether both the action and the body have been chosen.
  """
  @spec complete?(t()) :: boolean()
  def complete?(%__MODULE__{action: action, planet: planet}) do
    not is_nil(action) and not is_nil(planet)
  end

  @doc """
  Builds a changeset for a flight path step.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(step, attrs \\ %{}) do
    step
    |> cast(attrs, [:action, :planet])
    |> validate_required([:action, :planet], message: "must be selected")
  end
end
