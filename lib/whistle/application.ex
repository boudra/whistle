defmodule Whistle.Application do
  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: Whistle.Router,
        options: [
          dispatch: dispatch(),
          port: 4000
        ]
      )
    ]

    opts = [strategy: :one_for_one, name: Whistle.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_,
       [
         {"/ws/[...]", Whistle.SocketHandler, []},
         {:_, Plug.Cowboy.Handler, {Whistle.Router, []}}
       ]}
    ]
  end
end
