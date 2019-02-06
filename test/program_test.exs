defmodule ProgramTest do
  use ExUnit.Case
  use Plug.Test

  require Whistle.Html
  alias Whistle.{Program, Html}

  doctest Whistle
  doctest Whistle.Program.Connection

  defmodule ExampleProgram do
    use Whistle.Program

    def init(_params) do
      {:ok, 0}
    end

    def authorize(_state, socket, _params) do
      {:ok, socket, nil}
    end

    def update({:change, n}, state, session) do
      {:ok, state + n, session}
    end

    def update({:set_session, session}, state, _) do
      {:ok, state, session}
    end

    def view(state, _session) do
      ~H"""
      <div>
        <button on-click={{ {:change, 1} }}>+</button>
        <span>The current number is: {{ to_string(state) }}</span>
        <button on-click={{ {:change, -1} }}>-</button>
      </div>
      """
    end
  end

  defmodule ExampleFullProgram do
    use Whistle.Program

    def init(_params) do
      {:ok, 0}
    end

    def authorize(_state, socket, _params) do
      {:ok, socket, nil}
    end

    def update({:change, n}, state, session) do
      {:ok, state + n, session}
    end

    def view(_state, _session) do
      params = %{"hello" => true}

      ~H"""
      <html>
        <program name="counter" params={{ params }} />
      </html>
      """
    end
  end

  defmodule ExampleRouter do
    use Whistle.Router, path: "/ws"

    match("counter", ExampleProgram, %{})
    match("full", ExampleFullProgram, %{})
  end

  @router ExampleRouter
  @program ExampleProgram
  @program_name "counter"

  setup do
    [conn: conn(:get, "/")]
  end

  test "programs" do
    start_supervised(@router)

    assert {:ok, pid} = Program.Registry.ensure_started(@router, @program_name, @program, %{})

    assert pid == Program.Registry.pid(@router, @program_name)

    assert Program.Instance.view(@router, @program_name, %{}) ==
             {0,
              Html.div([], [
                Html.button([on: [click: {:change, 1}]], "+"),
                Html.span([], ["The current number is: ", "0"]),
                Html.button([on: [click: {:change, -1}]], "-")
              ])}

    socket = %Whistle.Socket{}

    assert Program.Instance.authorize(@router, @program_name, socket, %{}) == {:ok, socket, nil}
    assert Program.Instance.update(@router, @program_name, {:change, 2}, %{}) == {:ok, %{}, []}
    assert Program.Instance.send_info(@router, @program_name, :message) == :ok

    assert Program.Instance.view(@router, @program_name, %{}) ==
             {0,
              Html.div([], [
                Html.button([on: [click: {:change, 1}]], "+"),
                Html.span([], ["The current number is: ", "2"]),
                Html.button([on: [click: {:change, -1}]], "-")
              ])}
  end

  test "embed/4" do
    start_supervised(@router)

    assert Program.embed(%Plug.Conn{}, @router, @program_name) =~ "The current number is: 0"
    assert Program.Instance.update(@router, @program_name, {:change, 2}, %{}) == {:ok, %{}, []}
    assert Program.embed(%Plug.Conn{}, @router, @program_name) =~ "The current number is: 2"
  end

  test "fullscreen/4", %{conn: conn} do
    start_supervised(@router)

    assert_raise RuntimeError, ~r/.*/, fn ->
      Program.fullscreen(conn, @router, @program_name)
    end

    assert %{resp_body: resp} = Program.fullscreen(conn, @router, "full")
    assert resp =~ "The current number is: 0"
  end

  test "program connection" do
    start_supervised(@router)

    Program.Registry.ensure_started(@router, @program_name, @program, %{})

    conn = Program.Connection.new(@router, @program_name, nil, %{})

    {:ok, %{vdom: {0, nil}, session: :something}, []} =
             Program.Connection.update(conn, {:set_session, :something})

    {%{vdom: {0, {"div", _}}}, _} =
             Program.Connection.update_view(conn)

    assert {0,
            Html.div([], [
              Html.button([on: [click: {:change, 1}]], "+"),
              Html.span([], ["The current number is: ", "0"]),
              Html.button([on: [click: {:change, -1}]], "-")
            ])} == Program.Connection.view(conn)
  end

end
