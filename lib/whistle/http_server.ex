defmodule Whistle.HttpServer do
  def child_spec(opts) do
    Plug.Cowboy.child_spec(
      scheme: Keyword.get(opts, :scheme, :http),
      plug: nil,
      options: [
        dispatch: dispatch(Keyword.get(opts, :socket_handlers, %{}), Keyword.get(opts, :plug, nil)),
        port: Keyword.get(opts, :port, 4000)
      ]
    )
  end

  defp dispatch(handlers, plug) do
    socket_handlers =
      Enum.map(handlers, fn {path, router} ->
        {path, Whistle.SocketHandler, {router, []}}
      end)

    plug_handler =
      if is_nil(plug) do
        []
      else
        [{:_, Plug.Cowboy.Handler, {plug, []}}]
      end

    [
      {:_, socket_handlers ++ plug_handler}
    ]
  end
end
