defmodule Whistle.Program.Plug do
  def init(opts) do
    Map.new(opts)
  end

  def call(conn, %{router: router, program: program}) do
    Whistle.Program.fullscreen(conn, router, program)
  end
end
