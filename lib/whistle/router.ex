defmodule Whistle.Router do
  use Plug.Builder

  import Plug.Conn

  plug(Plug.Static,
    at: "/",
    from: "static",
    only: ~w(index.html app.js)
  )

  plug(:render_index)

  def render_index(conn, _) do
    send_file(conn, 200, "static/index.html")
  end

  def not_found(conn, _) do
    send_resp(conn, 404, "not found")
  end
end
