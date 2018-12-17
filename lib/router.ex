defmodule Whistle.Router do
  use Plug.Builder

  import Plug.Conn

  plug(Plug.Static,
    at: "/",
    from: "static",
    only: ~w(index.html app.js)
  )

  @payload """
  """

  plug(:not_found)

  def not_found(conn, _) do
    send_resp(conn, 404, "not found")
  end
end
