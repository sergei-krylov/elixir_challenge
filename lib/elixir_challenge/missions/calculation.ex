defmodule ElixirChallenge.Missions.Calculation do
  @moduledoc """
  The result of costing a flight path: the total fuel and the per-step
  breakdown behind it.
  """

  alias ElixirChallenge.Missions.Step

  @typedoc """
  One row of the breakdown.

    * `carried_fuel` - fuel committed to every step that follows this one
    * `payload` - the mass the formula was applied to: spacecraft + carried fuel
    * `fuel` - fuel this step burns, including the fuel needed to lift that fuel
    * `total_mass` - everything the step actually moves: payload + its own fuel
  """
  @type step_result :: %{
          step: Step.t(),
          fuel: non_neg_integer(),
          carried_fuel: non_neg_integer(),
          payload: pos_integer(),
          total_mass: pos_integer()
        }

  @type t :: %__MODULE__{
          total: non_neg_integer(),
          steps: [step_result()],
          ignored_steps: non_neg_integer()
        }

  defstruct total: 0, steps: [], ignored_steps: 0
end
