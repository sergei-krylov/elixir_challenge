defmodule ElixirChallenge.Missions.Mission do
  @moduledoc """
  A spacecraft mass plus the flight path it should fly.

  An embedded schema with no repo behind it: missions are built from form
  params and kept in the LiveView socket.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias ElixirChallenge.Missions.Planet
  alias ElixirChallenge.Missions.Step

  # Bounded because the fuel formulas convert mass to a float, and an integer
  # large enough to overflow raises ArithmeticError.
  @max_mass 1_000_000_000

  @max_steps 20

  @type t :: %__MODULE__{mass: pos_integer() | nil, steps: [Step.t()]}

  @primary_key false
  embedded_schema do
    field :mass, :integer
    embeds_many :steps, Step, on_replace: :delete
  end

  @doc """
  The largest accepted spacecraft mass, in kilograms.
  """
  @spec max_mass() :: pos_integer()
  def max_mass, do: @max_mass

  @doc """
  The largest accepted number of steps in a flight path.
  """
  @spec max_steps() :: pos_integer()
  def max_steps, do: @max_steps

  @doc """
  Builds a changeset for a mission.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(mission, attrs \\ %{}) do
    mission
    |> cast(attrs, [:mass], message: &cast_message/2)
    |> validate_required([:mass], message: "is required")
    |> validate_number(:mass, greater_than: 0, message: "must be greater than 0 kg")
    |> validate_number(:mass,
      less_than_or_equal_to: @max_mass,
      message: "must be at most #{@max_mass} kg"
    )
    |> cast_embed(:steps)
    |> validate_length(:steps, max: @max_steps)
  end

  defp cast_message(:mass, _meta), do: "must be a whole number of kilograms"

  @doc """
  Appends a step to the flight path.

  Defaults to the leg that plausibly comes next: launching from the body the
  ship is parked on, or landing if it is already in flight.
  """
  @spec add_step(t(), Step.t() | nil) :: t()
  def add_step(mission, step \\ nil)

  def add_step(%__MODULE__{} = mission, nil) do
    next_step =
      case current_body(mission) do
        nil -> %Step{action: :land, planet: nil}
        body -> %Step{action: :launch, planet: body}
      end

    add_step(mission, next_step)
  end

  def add_step(%__MODULE__{} = mission, %Step{} = step) do
    if can_add_step?(mission) do
      %{mission | steps: mission.steps ++ [step]}
    else
      mission
    end
  end

  @doc """
  Whether the flight path has room for another step.

  `validate_length/3` only fires when steps arrive as params, so this is what
  guards the add-step event.
  """
  @spec can_add_step?(t()) :: boolean()
  def can_add_step?(%__MODULE__{steps: steps}), do: length(steps) < @max_steps

  @doc """
  Removes the step at `index`. Out of range indexes leave the path untouched.
  """
  @spec remove_step(t(), integer()) :: t()
  def remove_step(%__MODULE__{} = mission, index) do
    if in_range?(mission, index) do
      %{mission | steps: List.delete_at(mission.steps, index)}
    else
      mission
    end
  end

  @doc """
  Swaps the step at `index` with its neighbour.

  Moving the first step up or the last step down is a no-op.
  """
  @spec move_step(t(), integer(), :up | :down) :: t()
  def move_step(%__MODULE__{} = mission, index, direction)
      when direction in [:up, :down] do
    target = if direction == :up, do: index - 1, else: index + 1

    if in_range?(mission, index) and in_range?(mission, target) do
      steps = mission.steps
      at_index = Enum.at(steps, index)
      at_target = Enum.at(steps, target)

      swapped =
        steps
        |> List.replace_at(index, at_target)
        |> List.replace_at(target, at_index)

      %{mission | steps: swapped}
    else
      mission
    end
  end

  @doc """
  The body the ship sits on after flying the path so far.

  Returns `nil` when the last completed step was a launch and the ship is
  still in flight.
  """
  @spec current_body(t()) :: Planet.id() | nil
  def current_body(%__MODULE__{steps: steps}) do
    steps
    |> Enum.filter(&Step.complete?/1)
    |> List.last()
    |> case do
      %Step{action: :land, planet: planet} -> planet
      %Step{action: :launch} -> nil
      nil -> :earth
    end
  end

  defp in_range?(%__MODULE__{steps: steps}, index) when is_integer(index) do
    index >= 0 and index < length(steps)
  end
end
