defmodule Whistle.Application.Plug do
  def init(opts) do
    Map.new(opts)
  end

  def call(conn, %{router: router, program: program, params: params}) do
    path = conn.path_info
    new_params = Map.merge(params, conn.params)

    conn
    |> Whistle.Program.fullscreen(
      router,
      program,
      new_params
    )
  end
end
