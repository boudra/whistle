defmodule Whistle.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Phoenix.PubSub.PG2, [Whistle.PubSub, []]),
      worker(Whistle.ProgramRegistry, [Whistle.ProgramRegistry])
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
