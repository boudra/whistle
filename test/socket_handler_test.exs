defmodule SocketHandlerTest do
  use ExUnit.Case
  use Plug.Test

  alias Whistle.SocketHandler

  defmodule DummyProgram do
    def init(state), do: {:ok, state}
    def view(_state, _session), do: {"html", {[], []}}

    def handle_info(message, state = %{test_process_pid: test_process_pid}) do
      send(test_process_pid, message)
      {:ok, state}
    end
  end

  defmodule DummyRouter do
    def __match(["program_name"]), do: {:ok, DummyProgram, %{}}
  end

  defmodule DummyRouter.Supervisor do
    use DynamicSupervisor

    def start_link() do
      DynamicSupervisor.start_link(__MODULE__, :not_used, name: __MODULE__)
    end

    def init(:not_used) do
      DynamicSupervisor.init(strategy: :one_for_one)
    end
  end

  test "handle_event handle_join" do
    # GIVEN we have started a supervisor and a register for the router
    {:ok, _pid} = Registry.start_link(keys: :unique, name: DummyRouter.Registry)
    {:ok, _pid} = DummyRouter.Supervisor.start_link()

    # AND the program process for the router has been started
    {:ok, _pid} =
      Whistle.Program.Registry.ensure_started(DummyRouter, "program_name", DummyProgram, %{
        test_process_pid: self()
      })

    # AND socket has been initialized by cowboy from a client request
    {:cowboy_websocket, _req, {conn, DummyRouter}} =
      SocketHandler.init(TestHelper.request(), {DummyRouter, []})

    {:ok, %Whistle.SocketHandler.State{} = state} =
      SocketHandler.websocket_init({conn, DummyRouter})

    # WHEN calling handle_event join
    next_state =
      SocketHandler.handle_event("join", state, %{
        "ref" => "request_id",
        "program" => "program_name",
        "params" => %{},
        "dom" => "dom",
        "uri" => "uri"
      })

    # THEN it returns the socket state
    {:ok, %SocketHandler.State{conns: next_conns}} = next_state

    # AND the program process receives a connected message
    assert_receive({:connected, %Whistle.Socket{}, %{}})

    # AND it should have registered the calling process in a process group
    group_name = Whistle.Program.Registry.build_group_name(DummyRouter, "program_name")
    assert :pg2.get_members(group_name) == [self()]

    # AND make sure it returns a socket reply
    connection_id = next_conns |> Map.keys() |> List.first()

    receive do
      {:reply, {:text, reply}} ->
        assert {:ok, [%{"conn" => connection_id, "ref" => "request_id", "type" => "joined"}]} ==
                 Jason.decode(reply)
    after
      100 -> throw("Never received a socket reply")
    end
  end
end
