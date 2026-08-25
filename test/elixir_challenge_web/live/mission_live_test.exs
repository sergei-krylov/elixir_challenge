defmodule ElixirChallengeWeb.MissionLiveTest do
  use ElixirChallengeWeb.ConnCase, async: true

  # Mirrors the params LiveView sends for the nested `inputs_for` list.
  defp mission_params(mass, path) do
    steps =
      path
      |> Enum.with_index()
      |> Map.new(fn {{action, planet}, index} ->
        {to_string(index), %{"action" => to_string(action), "planet" => to_string(planet)}}
      end)

    %{"mass" => to_string(mass), "steps" => steps}
  end

  defp change(lv, params) do
    lv |> form("#mission-form", mission: params) |> render_change()
  end

  describe "mount" do
    test "starts on the Apollo 11 mission with its total", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "Interplanetary Fuel Calculator"
      assert html =~ "28801"
      assert html =~ "51,898"
    end

    test "renders the flight path as selects", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      assert lv |> element(~s{select[name="mission[steps][0][action]"]}) |> has_element?()
      assert lv |> element(~s{select[name="mission[steps][3][planet]"]}) |> has_element?()
    end
  end

  describe "live recalculation" do
    test "a new mass updates the total immediately", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      html =
        change(
          lv,
          mission_params(14_606, launch: :earth, land: :mars, launch: :mars, land: :earth)
        )

      assert html =~ "33,388"
    end

    test "changing a planet updates the total", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      apollo = change(lv, mission_params(28_801, launch: :earth, land: :moon))
      to_mars = change(lv, mission_params(28_801, launch: :earth, land: :mars))

      refute apollo == to_mars
    end
  end

  describe "building the flight path" do
    test "adds a step", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      refute lv |> element(~s{select[name="mission[steps][4][action]"]}) |> has_element?()

      lv |> element(~s{button[phx-click="add_step"]}) |> render_click()

      assert lv |> element(~s{select[name="mission[steps][4][action]"]}) |> has_element?()
    end

    test "removes a step", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      lv
      |> element(~s{button[phx-click="remove_step"][phx-value-index="0"]})
      |> render_click()

      refute lv |> element(~s{select[name="mission[steps][3][action]"]}) |> has_element?()
    end

    test "reordering changes the total, because order matters", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/")

      assert html =~ "51,898"

      moved =
        lv
        |> element(
          ~s{button[phx-click="move_step"][phx-value-index="1"][phx-value-direction="up"]}
        )
        |> render_click()

      refute moved =~ "51,898"
    end

    test "the first step cannot move up and the last cannot move down", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      assert lv
             |> element(
               ~s{button[phx-click="move_step"][phx-value-index="0"][phx-value-direction="up"][disabled]}
             )
             |> has_element?()

      assert lv
             |> element(
               ~s{button[phx-click="move_step"][phx-value-index="3"][phx-value-direction="down"][disabled]}
             )
             |> has_element?()
    end
  end

  describe "presets" do
    test "load their mission and total", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      html =
        lv |> element(~s{button[phx-value-id="passenger_ship"]}) |> render_click()

      assert html =~ "75432"
      assert html =~ "212,161"
    end
  end

  describe "validation" do
    test "shows an error for a non-positive mass", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      assert change(lv, mission_params(0, launch: :earth)) =~ "must be greater than 0 kg"
    end

    test "shows an error for a mass that is not a whole number", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      assert change(lv, %{"mass" => "12.5"}) =~ "must be a whole number of kilograms"
    end

    test "an unselected planet is reported and left out of the total", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      html = change(lv, mission_params(28_801, [{:land, :earth}]) |> put_blank_planet())

      assert html =~ "must be selected"
      assert html =~ "step(s) not counted yet"
    end

    test "keeps the flight path when the mass is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      change(lv, %{"mass" => "nonsense"})

      assert lv |> element(~s{select[name="mission[steps][3][planet]"]}) |> has_element?()
    end
  end

  describe "path warnings" do
    test "flags a step the ship cannot fly, but still totals the path", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      html = change(lv, mission_params(28_801, launch: :earth, land: :moon, launch: :mars))

      assert html =~ "the ship is on Moon, not Mars"
      refute html =~ "step(s) not counted yet"
    end

    test "a coherent path shows no warning", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      refute html =~ "the ship is on"
    end
  end

  defp put_blank_planet(params) do
    put_in(params, ["steps", "0", "planet"], "")
  end
end
