defmodule ProgramTest do
  use ExUnit.Case
  doctest Whistle

  require Whistle.Html
  alias Whistle.{Html, Router, ProgramInstance, ProgramRegistry}

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

    def view(state, _session) do
      ~H"""
      <div>
        <button on-click=<%= {:change, 1} %>>+</button>
        <span>The current number is: <%= state %></span>
        <button on-click=<%= {:change, -1} %>>-</button>
      </div>
      """
    end
  end

  @router ExampleRouter
  @program ExampleProgram
  @program_name "example"

  test "programs" do
    {:ok, _router_pid} = Router.start_link({@router, []})
    {:ok, pid} = ProgramRegistry.ensure_started(@router, @program_name, @program, %{})

    assert pid == ProgramRegistry.pid(@router, @program_name)

    assert ProgramInstance.view(@router, @program_name, %{}) ==
             {0,
              Html.div([], [
                Html.button([on: [click: {:change, 1}]], "+"),
                Html.span([], ["The current number is: ", "0"]),
                Html.button([on: [click: {:change, -1}]], "-")
              ])}

    socket = %Whistle.Socket{}

    assert ProgramInstance.authorize(@router, @program_name, socket, %{}) == {:ok, socket, nil}
    assert ProgramInstance.update(@router, @program_name, {:change, 2}, %{}) == {:ok, %{}, []}
    assert ProgramInstance.send_info(@router, @program_name, :message) == :ok

    assert ProgramInstance.view(@router, @program_name, %{}) ==
             {0,
              Html.div([], [
                Html.button([on: [click: {:change, 1}]], "+"),
                Html.span([], ["The current number is: ", "2"]),
                Html.button([on: [click: {:change, -1}]], "-")
              ])}
  end
end
