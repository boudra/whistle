defmodule Whistle.Application do
  use Application

  @http_server Application.get_env(:whistle, :server)

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = http_server(@http_server)

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp http_server(nil) do
    []
  end

  defp http_server(opts) do
    [
      Plug.Cowboy.child_spec(
        scheme: Keyword.get(opts, :scheme, :http),
        plug: nil,
        options: [
          dispatch:
            dispatch(Keyword.get(opts, :socket_handlers, %{}), Keyword.get(opts, :plug, nil)),
          port: Keyword.get(opts, :port, 4000)
        ]
      )
    ]
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
