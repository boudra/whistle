defmodule Program.PlugTest do
  use ExUnit.Case
  use Plug.Test

  defmodule TestProgram do
    def init(_), do: {:ok, "some state"}
    def view(_state, _session), do: {"html", {[], []}}
  end

  defmodule TestRouter do
    def __match(["root"]), do: {:ok, TestProgram, %{}}
    def __config, do: [url: [port: 1234]]
    def __path, do: "/test_router/path"
  end

  defmodule TestRouter.Supervisor do
    use DynamicSupervisor

    def start_link() do
      DynamicSupervisor.start_link(__MODULE__, :not_used, name: __MODULE__)
    end

    def init(:not_used) do
      DynamicSupervisor.init(strategy: :one_for_one)
    end
  end

  defmodule TestPlug do
    use Plug.Builder

    plug(Whistle.Program.Plug,
      router: TestRouter,
      program: "root"
    )
  end

  test "GET request will create a program process which will return HTML" do
    # GIVEN a Plug with one router and a program
    # And a dynamic supervisor has been started manging the Router's programs
    TestRouter.Supervisor.start_link()
    # And a registry has been started for the router
    {:ok, _pid} = Registry.start_link(keys: :unique, name: TestRouter.Registry)

    # WHEN a GET request
    opts = TestPlug.init([])
    conn = conn(:get, "http://some.url")
    conn = TestPlug.call(conn, opts)

    # THEN it has created a Program process with correct state
    [{program_pid, nil}] = Registry.lookup(TestRouter.Registry, "root")
    # (or can be also be looked up like this
    # program_pid = Whistle.Program.Registry.pid(TestRouter, "root"))

    assert :sys.get_state(program_pid) == %Whistle.Program.Instance{
             name: "root",
             params: %{},
             program: TestProgram,
             router: TestRouter,
             state: "some state"
           }

    assert conn.resp_body ==
             "<!DOCTYPE html><html data-whistle-params=\"{}\" data-whistle-program=\"root\" data-whistle-socket=\"ws://some.url:1234/test_router/path\"></html>"
  end
end
