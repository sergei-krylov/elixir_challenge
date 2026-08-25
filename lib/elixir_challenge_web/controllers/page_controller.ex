defmodule ElixirChallengeWeb.PageController do
  use ElixirChallengeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
