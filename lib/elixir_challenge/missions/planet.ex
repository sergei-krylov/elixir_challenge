defmodule ElixirChallenge.Missions.Planet do
  @moduledoc """
  The celestial bodies a spacecraft can launch from or land on.

  Surface gravity (m/s²) is the only property the fuel formulas care about, so
  a body is just an id, a display name and a gravity constant.
  """

  @enforce_keys [:id, :name, :gravity]
  defstruct [:id, :name, :gravity]

  @type id :: :earth | :moon | :mars
  @type t :: %__MODULE__{id: id(), name: String.t(), gravity: float()}

  @bodies [
    %{id: :earth, name: "Earth", gravity: 9.807},
    %{id: :moon, name: "Moon", gravity: 1.62},
    %{id: :mars, name: "Mars", gravity: 3.711}
  ]

  @ids Enum.map(@bodies, & &1.id)
  @options Enum.map(@bodies, &{&1.name, &1.id})

  @doc """
  Every supported body, in display order.
  """
  @spec all() :: [t()]
  def all, do: Enum.map(@bodies, &struct!(__MODULE__, &1))

  @doc """
  The ids of every supported body. Used to build the `Ecto.Enum` field.

      iex> ElixirChallenge.Missions.Planet.ids()
      [:earth, :moon, :mars]
  """
  @spec ids() :: [id()]
  def ids, do: @ids

  @doc """
  Options for a `<.input type="select">`, as `{label, value}` pairs.

      iex> ElixirChallenge.Missions.Planet.options()
      [{"Earth", :earth}, {"Moon", :moon}, {"Mars", :mars}]
  """
  @spec options() :: [{String.t(), id()}]
  def options, do: @options

  @doc """
  Looks a body up by id.
  """
  @spec fetch(id()) :: {:ok, t()} | :error
  def fetch(id) do
    case Enum.find(all(), &(&1.id == id)) do
      nil -> :error
      body -> {:ok, body}
    end
  end

  @doc """
  Surface gravity of `body` in m/s².

      iex> ElixirChallenge.Missions.Planet.gravity(:earth)
      9.807
  """
  @spec gravity(id()) :: float()
  def gravity(body)

  @doc """
  Human readable name of `body`.

      iex> ElixirChallenge.Missions.Planet.name(:moon)
      "Moon"
  """
  @spec name(id()) :: String.t()
  def name(body)

  for %{id: id, name: name, gravity: gravity} <- @bodies do
    def gravity(unquote(id)), do: unquote(gravity)
    def name(unquote(id)), do: unquote(name)
  end
end
