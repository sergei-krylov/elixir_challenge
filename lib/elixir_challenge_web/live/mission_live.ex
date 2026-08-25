defmodule ElixirChallengeWeb.MissionLive do
  use ElixirChallengeWeb, :live_view

  alias ElixirChallenge.Missions
  alias ElixirChallenge.Missions.Calculation
  alias ElixirChallenge.Missions.Mission
  alias ElixirChallenge.Missions.PathAdvisor
  alias ElixirChallenge.Missions.Step

  @impl true
  def mount(_params, _session, socket) do
    {:ok, mission} = Missions.fetch_preset(:apollo_11)

    {:ok, assign_mission(socket, mission)}
  end

  @impl true
  def handle_event("validate", %{"mission" => params}, socket) do
    {mission, changeset} = Missions.apply_params(socket.assigns.mission, params)

    {:noreply, assign_mission(socket, mission, changeset)}
  end

  def handle_event("add_step", _params, socket) do
    {:noreply, update_mission(socket, &Missions.add_step/1)}
  end

  def handle_event("remove_step", %{"index" => index}, socket) do
    {:noreply, update_mission(socket, &Missions.remove_step(&1, String.to_integer(index)))}
  end

  def handle_event("move_step", %{"index" => index, "direction" => direction}, socket)
      when direction in ~w(up down) do
    index = String.to_integer(index)
    direction = String.to_existing_atom(direction)

    {:noreply, update_mission(socket, &Missions.move_step(&1, index, direction))}
  end

  def handle_event("load_preset", %{"id" => id}, socket) do
    case Missions.fetch_preset(id) do
      {:ok, mission} -> {:noreply, assign_mission(socket, mission)}
      :error -> {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <header class="space-y-1">
          <h1 class="text-2xl font-semibold">Interplanetary Fuel Calculator</h1>
          <p class="text-sm text-base-content/70">
            Build a flight path and see the fuel it needs, updated as you type.
          </p>
        </header>

        <.preset_picker presets={Missions.presets()} />

        <div class="grid gap-6 lg:grid-cols-12 lg:items-start">
          <.form
            for={@form}
            id="mission-form"
            phx-change="validate"
            phx-submit="validate"
            class="lg:col-span-5 space-y-6"
          >
            <.card>
              <.mass_field form={@form} />
            </.card>

            <.card>
              <.flight_path form={@form} mission={@mission} warnings={@warnings} />
            </.card>
          </.form>

          <aside class="space-y-4 lg:col-span-7">
            <.card>
              <.fuel_total calculation={@calculation} />
            </.card>

            <.card :if={@calculation.steps != []}>
              <.fuel_breakdown calculation={@calculation} />
            </.card>
          </aside>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :presets, :list, required: true

  defp preset_picker(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-2">
      <span class="text-sm text-base-content/70">Example missions:</span>
      <.button
        :for={preset <- @presets}
        type="button"
        class="btn btn-sm btn-outline"
        phx-click="load_preset"
        phx-value-id={preset.id}
        title={preset.description}
      >
        {preset.name}
      </.button>
    </div>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true

  defp mass_field(assigns) do
    ~H"""
    <.input
      field={@form[:mass]}
      type="number"
      label="Spacecraft mass (kg)"
      min="1"
      phx-debounce="300"
    />
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :mission, Mission, required: true
  attr :warnings, :map, required: true

  defp flight_path(assigns) do
    ~H"""
    <div class="space-y-3">
      <h2 class="card-title text-base">Flight path</h2>

      <p :if={@mission.steps == []} class="text-sm text-base-content/60">
        No steps yet. Add one to start planning.
      </p>

      <.inputs_for :let={step_form} field={@form[:steps]}>
        <.step_row
          step_form={step_form}
          warning={@warnings[step_form.index]}
          step_count={length(@mission.steps)}
        />
      </.inputs_for>

      <div>
        <.button type="button" phx-click="add_step" disabled={not Missions.can_add_step?(@mission)}>
          <.icon name="hero-plus" class="size-4" /> Add step
        </.button>
      </div>
    </div>
    """
  end

  attr :step_form, Phoenix.HTML.Form, required: true
  attr :warning, :string, default: nil
  attr :step_count, :integer, required: true

  defp step_row(assigns) do
    ~H"""
    <div class="space-y-1">
      <div class="grid grid-cols-[1.25rem_6rem_1fr_auto] items-center gap-2 [&_.fieldset]:mb-0">
        <span class="text-sm text-base-content/50 tabular-nums">
          {@step_form.index + 1}
        </span>

        <.input
          field={@step_form[:action]}
          type="select"
          options={Missions.action_options()}
          class="select select-sm w-full"
        />

        <.input
          field={@step_form[:planet]}
          type="select"
          options={Missions.planet_options()}
          prompt="Select a planet"
          class="select select-sm w-full"
        />

        <div class="flex gap-1">
          <.button
            type="button"
            class="btn btn-sm btn-square btn-ghost"
            phx-click="move_step"
            phx-value-index={@step_form.index}
            phx-value-direction="up"
            disabled={@step_form.index == 0}
            aria-label="Move step up"
          >
            <.icon name="hero-chevron-up" class="size-4" />
          </.button>

          <.button
            type="button"
            class="btn btn-sm btn-square btn-ghost"
            phx-click="move_step"
            phx-value-index={@step_form.index}
            phx-value-direction="down"
            disabled={@step_form.index == @step_count - 1}
            aria-label="Move step down"
          >
            <.icon name="hero-chevron-down" class="size-4" />
          </.button>

          <.button
            type="button"
            class="btn btn-sm btn-square btn-ghost text-error"
            phx-click="remove_step"
            phx-value-index={@step_form.index}
            aria-label="Remove step"
          >
            <.icon name="hero-trash" class="size-4" />
          </.button>
        </div>
      </div>

      <p :if={@warning} class="flex items-center gap-1 pl-7 text-xs text-warning">
        <.icon name="hero-exclamation-triangle" class="size-3.5" />
        {@warning}
      </p>
    </div>
    """
  end

  attr :calculation, Calculation, required: true

  defp fuel_total(assigns) do
    ~H"""
    <div>
      <h2 class="text-xs uppercase tracking-wide text-base-content/60">
        Total fuel required
      </h2>
      <p id="total-fuel" class="text-4xl font-bold tabular-nums">
        {kg(@calculation.total)}
        <span class="text-base font-normal text-base-content/60">kg</span>
      </p>

      <p :if={@calculation.ignored_steps > 0} class="text-sm text-warning">
        {@calculation.ignored_steps} step(s) not counted yet.
      </p>
    </div>
    """
  end

  attr :calculation, Calculation, required: true

  defp fuel_breakdown(assigns) do
    ~H"""
    <div>
      <h2 class="card-title text-base">Breakdown</h2>
      <p class="text-xs text-base-content/60">
        The path is costed from the last step backwards, because each step also has to move the
        fuel that later steps will burn. Total mass is the spacecraft plus all the fuel still
        aboard: what this step burns, plus what it carries for the rest of the path.
      </p>

      <div class="overflow-x-auto">
        <table class="table table-sm">
          <thead>
            <tr>
              <th>Step</th>
              <th class="text-right">Total mass</th>
              <th class="text-right">Fuel needed</th>
              <th class="text-right">Carried fuel</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @calculation.steps}>
              <td class="whitespace-nowrap">{Step.describe(row.step)}</td>
              <td class="text-right tabular-nums">{kg(row.total_mass)}</td>
              <td class="text-right tabular-nums">{kg(row.fuel)}</td>
              <td class="text-right tabular-nums">{kg(row.carried_fuel)}</td>
            </tr>
          </tbody>
          <tfoot>
            <tr>
              <th>Total fuel needed</th>
              <th></th>
              <th></th>
              <th class="text-right tabular-nums">{kg(@calculation.total)}</th>
            </tr>
          </tfoot>
        </table>
      </div>
    </div>
    """
  end

  defp update_mission(socket, fun) do
    assign_mission(socket, fun.(socket.assigns.mission))
  end

  defp assign_mission(socket, mission, changeset \\ nil) do
    changeset = changeset || Missions.change_mission(mission)

    socket
    |> assign(:mission, mission)
    |> assign(:form, to_form(changeset, as: :mission, action: :validate))
    |> assign(:calculation, Missions.calculate(mission))
    |> assign(:warnings, PathAdvisor.warnings(mission))
  end

  defp kg(value) do
    value
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end
end
